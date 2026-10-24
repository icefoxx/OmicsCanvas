"""AI Studio: recommend plots, build demos, explain figures, chat."""
from __future__ import annotations

import json
import shutil
import uuid
from datetime import datetime
from pathlib import Path
from typing import Any

from fastapi import APIRouter, HTTPException, Request
from fastapi.concurrency import run_in_threadpool
from fastapi.responses import JSONResponse

from plot_web import ai_assistant
from plot_web import palettes as palette_catalog
from plot_web.server.plugins import (
    demo_payload,
    plugin_config_path,
    plugin_path,
    read_yaml,
)
from plot_web.server.runner import build_command, run_local_job
from plot_web.server.settings import (
    DEFAULT_DISPATCH_MODE,
    JOBS_DIR,
    PLUGIN_DIR,
    RESULTS_DIR,
    ROOT_DIR,
    UPLOADS_DIR,
)
from plot_web.server.storage import ensure_storage, safe_id, save_job, utc_now

router = APIRouter()


# AI assistant: recommend plots + build/run small demos


@router.get("/api/ai/status")
def ai_assistant_status() -> dict[str, Any]:
    return ai_assistant.ai_status()


@router.post("/api/ai/recommend")
async def ai_recommend(request: Request) -> JSONResponse:
    """Upload a table + optional goal text → ranked plugin recommendations."""
    ensure_storage()
    form = await request.form()
    goal = str(form.get("goal") or form.get("question") or "").strip()
    top_k = int(form.get("top_k") or 3)
    top_k = max(1, min(6, top_k))

    upload = form.get("file") or form.get("input")
    filename = getattr(upload, "filename", None)
    if not filename:
        raise HTTPException(status_code=400, detail="Upload a CSV/TSV/XLSX table as field 'file'.")

    session_id = "ai_" + datetime.now().strftime("%Y%m%d_%H%M%S_") + uuid.uuid4().hex[:8]
    session_dir = UPLOADS_DIR / session_id
    session_dir.mkdir(parents=True, exist_ok=True)
    safe_name = Path(filename).name
    target = session_dir / safe_name
    with target.open("wb") as handle:
        shutil.copyfileobj(upload.file, handle)

    try:
        from plot_web.table_io import sanitize_sheet_name

        sheet = sanitize_sheet_name(str(form.get("sheet") or "") or None)
        profile = ai_assistant.profile_table(target, sheet=sheet)
    except Exception as exc:
        raise HTTPException(status_code=400, detail=f"Failed to read table: {exc}") from exc
    profile["session_id"] = session_id
    # Prefer converted CSV path for downstream demos/plugins
    session_file = Path(profile.get("path") or target)
    profile["path"] = str(session_file)

    candidates = ai_assistant.recommend_plugins(profile, PLUGIN_DIR, goal=goal, top_k=max(top_k, 5))
    engine = "rules"
    refined = await run_in_threadpool(ai_assistant.refine_with_spacexai, profile, candidates, goal=goal)
    if refined:
        recommendations = refined[:top_k]
        engine = "llm+rules"
    else:
        recommendations = candidates[:top_k]
        for rec in recommendations:
            rec.setdefault("source", "rules")

    intent = ai_assistant.summarize_intent(profile, goal=goal, recommendations=recommendations)
    skills = ai_assistant.match_skills(profile, recommendations, ROOT_DIR / "skills", goal=goal)

    meta = {
        "session_id": session_id,
        "goal": goal,
        "profile": {k: v for k, v in profile.items() if k != "preview_rows"},
        "preview_rows": profile.get("preview_rows"),
        "file": str(session_file),
        "original_file": str(target) if session_file.resolve() != target.resolve() else None,
        "recommendations": recommendations,
        "intent": intent,
        "skills": skills,
        "created_at": utc_now(),
    }
    (session_dir / "session.json").write_text(json.dumps(meta, indent=2, ensure_ascii=False), encoding="utf-8")

    # Also recommend scientific palettes for the same research goal
    n_cat = len(profile.get("categorical_columns") or [])
    n_groups_guess = None
    if profile.get("categorical_cardinality"):
        try:
            n_groups_guess = max(profile["categorical_cardinality"].values())
        except Exception:
            n_groups_guess = n_cat or None
    palette_recs = palette_catalog.recommend_palettes(
        research_goal=goal or " ".join(profile.get("tags") or []),
        n_groups=n_groups_guess,
        limit=4,
    )

    return JSONResponse(
        {
            "session_id": session_id,
            "engine": engine,
            "goal": goal,
            "intent": intent,
            "skills": skills,
            "profile": {
                "filename": profile.get("filename"),
                "columns": profile.get("columns"),
                "numeric_columns": profile.get("numeric_columns"),
                "categorical_columns": profile.get("categorical_columns"),
                "row_count_estimate": profile.get("row_count_estimate"),
                "column_count": profile.get("column_count"),
                "tags": profile.get("tags"),
                "preview_rows": profile.get("preview_rows"),
                "format": profile.get("format"),
                "excel": profile.get("excel"),
            },
            "recommendations": recommendations,
            "palette_recommendations": palette_recs,
            "message": (
                "Intent summarized and plots ranked. Use “Run top 3 & explain” for demos + AI explanations, "
                "or generate a single demo from a card."
                + (" Excel sheet converted to CSV for plotting." if profile.get("excel") else "")
            ),
        }
    )


def _execute_ai_demo(
    *,
    session_id: str,
    plugin_id: str,
    session: dict[str, Any],
    prefer_builtin: bool = False,
    custom_params: dict[str, Any] | None = None,
) -> dict[str, Any]:
    """Shared runner used by /build-demo and /pipeline."""
    source = Path(session.get("file") or "")
    if not source.exists():
        raise HTTPException(status_code=404, detail="Uploaded file for this session is missing")

    config = read_yaml(plugin_config_path(plugin_id))
    profile = ai_assistant.profile_table(source)

    job_id = "job_ai_" + datetime.now().strftime("%Y%m%d_%H%M%S_") + uuid.uuid4().hex[:8]
    figure_id = "fig_" + uuid.uuid4().hex[:12]
    work_dir = UPLOADS_DIR / job_id
    output_dir = RESULTS_DIR / job_id
    job_dir = JOBS_DIR / job_id
    work_dir.mkdir(parents=True, exist_ok=True)
    output_dir.mkdir(parents=True, exist_ok=True)
    job_dir.mkdir(parents=True, exist_ok=True)

    mode_used = "adapted_user_data"
    note = ""
    saved_files: dict[str, Path] = {}
    params: dict[str, Any] = {}
    use_builtin = prefer_builtin

    if not use_builtin:
        try:
            saved_files, params, note = ai_assistant.prepare_demo_files(
                plugin_id, source, profile, work_dir
            )
        except Exception as exc:
            use_builtin = True
            note = f"Adapt failed ({exc}); falling back to plugin built-in demo."

    if use_builtin or not saved_files:
        demo = demo_payload(plugin_id, config)
        saved_files = demo.pop("_file_paths", {}) or {}
        demo_params = demo.get("params") or {}
        if isinstance(demo_params, dict) and isinstance(demo_params.get("params"), dict):
            params = dict(demo_params["params"])
        elif isinstance(demo_params, dict):
            params = dict(demo_params.get("params") or demo_params)
        else:
            params = {}
        for k in ("name", "path"):
            params.pop(k, None)
        mode_used = "builtin_demo"
        if not note:
            note = "Used plugin built-in demo data (safest path). Your upload informed the plugin choice."
        if not saved_files:
            return {
                "plugin_id": plugin_id,
                "status": "failed",
                "error": {"error": "No demo input", "detail": f"No demo files for {plugin_id}"},
                "ai": {"session_id": session_id, "mode": mode_used, "note": note, "goal": session.get("goal")},
                "editor_url": f"/static/editor.html?plugin={plugin_id}",
            }

    if isinstance(custom_params, dict):
        params.update(custom_params)
    params["plugin_id"] = plugin_id
    params.setdefault("dispatch_mode", DEFAULT_DISPATCH_MODE)

    params_path = job_dir / "params.json"
    params_path.write_text(json.dumps(params, indent=2, ensure_ascii=False), encoding="utf-8")

    job = {
        "job_id": job_id,
        "figure_id": figure_id,
        "plugin_id": plugin_id,
        "dataset_id": session_id,
        "status": "queued",
        "message": "AI demo job accepted.",
        "created_at": utc_now(),
        "dispatch_mode": params.get("dispatch_mode", DEFAULT_DISPATCH_MODE),
        "upload_dir": str(work_dir),
        "output_dir": str(output_dir),
        "params_path": str(params_path),
        "uploaded_files": {k: str(v) for k, v in saved_files.items()},
        "ai": {
            "session_id": session_id,
            "mode": mode_used,
            "note": note,
            "goal": session.get("goal"),
        },
    }
    save_job(job)

    if job["dispatch_mode"] != "local":
        job.update({"status": "queued", "message": "Non-local dispatch not configured."})
        save_job(job)
        return job

    cmd = build_command(plugin_id, config, saved_files, params_path, output_dir)
    completed = run_local_job(job, cmd, plugin_path(plugin_id), output_dir)

    if completed.get("status") != "completed" and mode_used == "adapted_user_data":
        demo = demo_payload(plugin_id, config)
        fb_files = demo.pop("_file_paths", {}) or {}
        demo_params = demo.get("params") or {}
        if isinstance(demo_params, dict) and isinstance(demo_params.get("params"), dict):
            fb_params = dict(demo_params["params"])
        elif isinstance(demo_params, dict):
            fb_params = dict(demo_params.get("params") or demo_params)
        else:
            fb_params = {}
        for k in ("name", "path"):
            fb_params.pop(k, None)
        if fb_files:
            fb_params["plugin_id"] = plugin_id
            fb_params.setdefault("dispatch_mode", DEFAULT_DISPATCH_MODE)
            params_path.write_text(json.dumps(fb_params, indent=2, ensure_ascii=False), encoding="utf-8")
            job["ai"] = {
                "session_id": session_id,
                "mode": "builtin_demo_fallback",
                "note": (
                    f"Adapted data failed ({(completed.get('error') or {}).get('detail') or completed.get('status')}); "
                    "retried with plugin built-in demo."
                ),
                "goal": session.get("goal"),
            }
            job["uploaded_files"] = {k: str(v) for k, v in fb_files.items()}
            job["status"] = "queued"
            save_job(job)
            cmd2 = build_command(plugin_id, config, fb_files, params_path, output_dir)
            completed = run_local_job(job, cmd2, plugin_path(plugin_id), output_dir)
            completed["ai"] = job["ai"]
            params = fb_params

    completed["ai"] = completed.get("ai") or job.get("ai")
    completed["editor_url"] = f"/static/editor.html?plugin={plugin_id}"
    completed["params_used"] = params
    completed["plugin_id"] = plugin_id
    # attach figure.json meta if present
    try:
        fj = Path(completed.get("output_dir") or output_dir) / "figure.json"
        if fj.exists():
            completed["figure_meta"] = json.loads(fj.read_text(encoding="utf-8"))
    except Exception:
        pass
    save_job(completed)
    return completed


@router.post("/api/ai/build-demo")
async def ai_build_demo(request: Request) -> JSONResponse:
    """Build a small demo from an AI session + plugin_id, run the plugin, return outputs."""
    ensure_storage()
    try:
        body = await request.json()
    except Exception:
        body = {}
    if not isinstance(body, dict):
        body = {}

    session_id = str(body.get("session_id") or "").strip()
    plugin_id = str(body.get("plugin_id") or "").strip()
    prefer_builtin = bool(body.get("prefer_builtin_demo") or False)
    if not session_id or not plugin_id:
        raise HTTPException(status_code=400, detail="session_id and plugin_id are required")

    session_dir = UPLOADS_DIR / safe_id(session_id)
    session_meta_path = session_dir / "session.json"
    if not session_meta_path.exists():
        raise HTTPException(status_code=404, detail="AI session not found — re-upload and recommend first")
    try:
        session = json.loads(session_meta_path.read_text(encoding="utf-8"))
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Corrupt session: {exc}") from exc

    custom = body.get("params") if isinstance(body.get("params"), dict) else None
    completed = await run_in_threadpool(_execute_ai_demo,
        session_id=session_id,
        plugin_id=plugin_id,
        session=session,
        prefer_builtin=prefer_builtin,
        custom_params=custom,
    )
    return JSONResponse(completed)


@router.post("/api/ai/explain")
async def ai_explain_figure(request: Request) -> JSONResponse:
    """Explain one generated (or recommended) figure in English."""
    try:
        body = await request.json()
    except Exception:
        body = {}
    if not isinstance(body, dict):
        body = {}
    session_id = str(body.get("session_id") or "").strip()
    plugin_id = str(body.get("plugin_id") or "").strip()
    if not plugin_id:
        raise HTTPException(status_code=400, detail="plugin_id is required")

    session: dict[str, Any] = {}
    if session_id:
        meta_path = UPLOADS_DIR / safe_id(session_id) / "session.json"
        if meta_path.exists():
            try:
                session = json.loads(meta_path.read_text(encoding="utf-8"))
            except Exception:
                session = {}

    recs = session.get("recommendations") or []
    reason = str(body.get("reason") or "")
    name = str(body.get("plugin_name") or plugin_id)
    for r in recs:
        if r.get("plugin_id") == plugin_id:
            reason = reason or str(r.get("reason") or "")
            name = str(r.get("name") or name)
            break

    profile = session.get("profile") or {}
    exp = await run_in_threadpool(ai_assistant.explain_figure,
        plugin_id=plugin_id,
        plugin_name=name,
        reason=reason,
        goal=str(session.get("goal") or body.get("goal") or ""),
        profile=profile,
        figure_meta=body.get("figure_meta") if isinstance(body.get("figure_meta"), dict) else {},
        run_status=str(body.get("status") or "recommended"),
        mode=str(body.get("mode") or ""),
    )
    return JSONResponse({"plugin_id": plugin_id, **exp})


@router.post("/api/ai/pipeline")
async def ai_pipeline(request: Request) -> JSONResponse:
    """Full flow: profile → intent → top-N plots + skills → render demos → explain each.

    Accepts multipart like /recommend (file + goal), or JSON with existing session_id.
    """
    ensure_storage()
    content_type = (request.headers.get("content-type") or "").lower()

    session_id = ""
    goal = ""
    top_k = 3
    prefer_builtin = False
    auto_render = True

    if "multipart/form-data" in content_type or "application/x-www-form-urlencoded" in content_type:
        form = await request.form()
        goal = str(form.get("goal") or "").strip()
        top_k = max(1, min(5, int(form.get("top_k") or 3)))
        prefer_builtin = str(form.get("prefer_builtin_demo") or "").lower() in {"1", "true", "yes"}
        auto_render = str(form.get("auto_render") or "true").lower() not in {"0", "false", "no"}
        session_id = str(form.get("session_id") or "").strip()
        upload = form.get("file") or form.get("input")
        filename = getattr(upload, "filename", None)
        if filename:
            session_id = "ai_" + datetime.now().strftime("%Y%m%d_%H%M%S_") + uuid.uuid4().hex[:8]
            session_dir = UPLOADS_DIR / session_id
            session_dir.mkdir(parents=True, exist_ok=True)
            target = session_dir / Path(filename).name
            with target.open("wb") as handle:
                shutil.copyfileobj(upload.file, handle)
            try:
                from plot_web.table_io import sanitize_sheet_name

                sheet = sanitize_sheet_name(str(form.get("sheet") or "") or None)
                profile = ai_assistant.profile_table(target, sheet=sheet)
            except Exception as exc:
                raise HTTPException(status_code=400, detail=f"Failed to read table: {exc}") from exc
            source_path = Path(profile.get("path") or target)
        elif session_id:
            session_dir = UPLOADS_DIR / safe_id(session_id)
            meta_path = session_dir / "session.json"
            if not meta_path.exists():
                raise HTTPException(status_code=404, detail="session not found")
            session = json.loads(meta_path.read_text(encoding="utf-8"))
            source_path = Path(session.get("file") or "")
            if not source_path.exists():
                raise HTTPException(status_code=404, detail="session file missing")
            profile = ai_assistant.profile_table(source_path)
            goal = goal or str(session.get("goal") or "")
        else:
            raise HTTPException(status_code=400, detail="Provide file upload or session_id")
    else:
        try:
            body = await request.json()
        except Exception:
            body = {}
        if not isinstance(body, dict):
            body = {}
        session_id = str(body.get("session_id") or "").strip()
        goal = str(body.get("goal") or "").strip()
        top_k = max(1, min(5, int(body.get("top_k") or 3)))
        prefer_builtin = bool(body.get("prefer_builtin_demo") or False)
        auto_render = body.get("auto_render", True) is not False
        if not session_id:
            raise HTTPException(status_code=400, detail="session_id required for JSON pipeline (or use multipart upload)")
        session_dir = UPLOADS_DIR / safe_id(session_id)
        meta_path = session_dir / "session.json"
        if not meta_path.exists():
            raise HTTPException(status_code=404, detail="session not found")
        session = json.loads(meta_path.read_text(encoding="utf-8"))
        source_path = Path(session.get("file") or "")
        if not source_path.exists():
            raise HTTPException(status_code=404, detail="session file missing")
        profile = ai_assistant.profile_table(source_path)
        goal = goal or str(session.get("goal") or "")

    # Recommend plots
    candidates = ai_assistant.recommend_plugins(profile, PLUGIN_DIR, goal=goal, top_k=max(top_k, 5))
    engine = "rules"
    refined = await run_in_threadpool(ai_assistant.refine_with_spacexai, profile, candidates, goal=goal)
    if refined:
        recommendations = refined[:top_k]
        engine = "llm+rules"
    else:
        recommendations = candidates[:top_k]
        for rec in recommendations:
            rec.setdefault("source", "rules")

    intent = ai_assistant.summarize_intent(profile, goal=goal, recommendations=recommendations)
    skills = ai_assistant.match_skills(
        profile,
        recommendations,
        ROOT_DIR / "skills",
        goal=goal,
    )
    n_groups_guess = None
    if profile.get("categorical_cardinality"):
        try:
            n_groups_guess = max(profile["categorical_cardinality"].values())
        except Exception:
            n_groups_guess = None
    palette_recs = palette_catalog.recommend_palettes(
        research_goal=goal or " ".join(profile.get("tags") or []),
        n_groups=n_groups_guess,
        limit=4,
    )

    # Persist session
    if not session_id:
        session_id = "ai_" + datetime.now().strftime("%Y%m%d_%H%M%S_") + uuid.uuid4().hex[:8]
    session_dir = UPLOADS_DIR / safe_id(session_id)
    session_dir.mkdir(parents=True, exist_ok=True)
    session_payload = {
        "session_id": session_id,
        "goal": goal,
        "profile": {k: v for k, v in profile.items() if k != "preview_rows"},
        "preview_rows": profile.get("preview_rows"),
        "file": str(source_path),
        "recommendations": recommendations,
        "intent": intent,
        "skills": skills,
        "created_at": utc_now(),
    }
    (session_dir / "session.json").write_text(
        json.dumps(session_payload, indent=2, ensure_ascii=False), encoding="utf-8"
    )

    figures: list[dict[str, Any]] = []
    if auto_render:
        for rec in recommendations[:top_k]:
            pid = rec.get("plugin_id")
            if not pid:
                continue
            try:
                run = await run_in_threadpool(_execute_ai_demo,
                    session_id=session_id,
                    plugin_id=pid,
                    session=session_payload,
                    prefer_builtin=prefer_builtin,
                )
            except Exception as exc:
                run = {
                    "plugin_id": pid,
                    "status": "failed",
                    "error": {"error": "pipeline_error", "detail": str(exc)},
                    "ai": {"mode": "error", "note": str(exc)},
                }
            exp = await run_in_threadpool(ai_assistant.explain_figure,
                plugin_id=pid,
                plugin_name=str(rec.get("name") or pid),
                reason=str(rec.get("reason") or ""),
                goal=goal,
                profile=profile,
                figure_meta=run.get("figure_meta") if isinstance(run.get("figure_meta"), dict) else {},
                run_status=str(run.get("status") or "unknown"),
                mode=str((run.get("ai") or {}).get("mode") or ""),
            )
            figures.append(
                {
                    "rank": len(figures) + 1,
                    "plugin_id": pid,
                    "name": rec.get("name") or pid,
                    "reason": rec.get("reason"),
                    "score": rec.get("score"),
                    "status": run.get("status"),
                    "outputs": run.get("outputs"),
                    "preview": (run.get("outputs") or {}).get("preview"),
                    "editor_url": run.get("editor_url") or f"/static/editor.html?plugin={pid}",
                    "ai": run.get("ai"),
                    "explanation": exp.get("explanation"),
                    "explanation_source": exp.get("source"),
                    "job_id": run.get("job_id"),
                    "error": run.get("error"),
                }
            )

    return JSONResponse(
        {
            "session_id": session_id,
            "engine": engine,
            "goal": goal,
            "intent": intent,
            "profile": {
                "filename": profile.get("filename"),
                "columns": profile.get("columns"),
                "numeric_columns": profile.get("numeric_columns"),
                "categorical_columns": profile.get("categorical_columns"),
                "row_count_estimate": profile.get("row_count_estimate"),
                "column_count": profile.get("column_count"),
                "tags": profile.get("tags"),
                "preview_rows": profile.get("preview_rows"),
            },
            "recommendations": recommendations,
            "skills": skills,
            "palette_recommendations": palette_recs,
            "figures": figures,
            "message": (
                "Pipeline complete: intent summarized, top plots ranked"
                + (", demos rendered and explained." if auto_render else ".")
            ),
        }
    )


@router.post("/api/ai/chat")
async def ai_chat(request: Request) -> JSONResponse:
    """Lightweight Q&A about recommendations (rules always; SpaceXAI if keyed)."""
    try:
        body = await request.json()
    except Exception:
        body = {}
    if not isinstance(body, dict):
        body = {}
    message = str(body.get("message") or body.get("question") or "").strip()
    session_id = str(body.get("session_id") or "").strip()
    if not message:
        raise HTTPException(status_code=400, detail="message is required")

    context: dict[str, Any] = {}
    if session_id:
        meta_path = UPLOADS_DIR / safe_id(session_id) / "session.json"
        if meta_path.exists():
            try:
                context = json.loads(meta_path.read_text(encoding="utf-8"))
            except Exception:
                context = {}

    recs = context.get("recommendations") or []
    system = (
        "You are OmicsCanvas Plot Studio AI assistant. Help users choose bioinformatics plots. "
        "Be concise. Always reply in English only (never use Chinese characters in the reply). "
        "If recommending plugins, use only existing plugin_ids from context."
    )
    user_payload = {
        "message": message,
        "goal": context.get("goal"),
        "profile": context.get("profile"),
        "recommendations": recs,
    }
    text = await run_in_threadpool(ai_assistant.chat_completion,
        [
            {"role": "system", "content": system},
            {"role": "user", "content": json.dumps(user_payload, ensure_ascii=False)},
        ],
        temperature=0.4,
        timeout=60,
    )
    if text:
        return JSONResponse({"reply": text, "engine": "llm"})
    fallback = ""
    if not ai_assistant._llm_config().get("api_key"):
        fallback = ""
    else:
        fallback = "(LLM call failed, using rules) "

    recs = context.get("recommendations") or []
    if recs:
        lines = [
            fallback + "Based on your uploaded table, recommendations:",
            *[f"• **{r.get('name')}** (`{r.get('plugin_id')}`) — {r.get('reason')}" for r in recs[:3]],
            "",
            "Click “Generate demo” on a card to render a small subsample (or the plugin’s built-in demo).",
            "You can also open the Editor to fine-tune parameters.",
        ]
        return JSONResponse({"reply": "\n".join(lines), "engine": "rules"})

    return JSONResponse(
        {
            "reply": fallback
            + "Please upload a table and click “Analyze & Recommend”. I will suggest plot types from column types and your goal, then generate a small demo.",
            "engine": "rules",
        }
    )
