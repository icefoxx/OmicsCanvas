"""AI plot recommender + demo builder for OmicsCanvas plot_web.

Works offline with a deterministic rule engine. When an API key is set
(XAI_API_KEY / OPENCODE_API_KEY / OPENAI_API_KEY), optionally refines
recommendations via an OpenAI-compatible chat API (SpaceXAI or OpenCode Go).
"""
from __future__ import annotations

import csv
import json
import os
import re
from pathlib import Path
from typing import Any
from urllib import error as urlerror
from urllib import request as urlrequest


def _load_dotenv() -> None:
    """Load plot_web/.env into os.environ if present (does not override existing)."""
    env_path = Path(__file__).resolve().parent / ".env"
    if not env_path.is_file():
        return
    try:
        for line in env_path.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, _, val = line.partition("=")
            key = key.strip()
            val = val.strip().strip('"').strip("'")
            if key and key not in os.environ:
                os.environ[key] = val
    except Exception:
        pass


_load_dotenv()


def _llm_config() -> dict[str, str | None]:
    """Resolve API key + OpenAI-compatible base URL + model."""
    key = (
        os.environ.get("OPENCODE_API_KEY")
        or os.environ.get("XAI_API_KEY")
        or os.environ.get("SPACEXAI_API_KEY")
        or os.environ.get("OPENAI_API_KEY")
    )
    base = (
        os.environ.get("OPENAI_BASE_URL")
        or os.environ.get("XAI_BASE_URL")
        or os.environ.get("OPENCODE_BASE_URL")
    )
    if not base:
        # Default: OpenCode Go if using that key family, else xAI
        if os.environ.get("OPENCODE_API_KEY") or (key and key.startswith("sk-") and "x.ai" not in (os.environ.get("XAI_BASE_URL") or "")):
            # Prefer OpenCode Go when OPENCODE_API_KEY is set; also when only XAI_* aliases point at opencode
            if os.environ.get("OPENCODE_API_KEY") or (os.environ.get("XAI_BASE_URL") or "").find("opencode") >= 0:
                base = "https://opencode.ai/zen/go/v1"
            else:
                base = "https://api.x.ai/v1"
        else:
            base = "https://api.x.ai/v1"
    base = base.rstrip("/")
    model = (
        os.environ.get("OPENAI_MODEL")
        or os.environ.get("XAI_MODEL")
        or os.environ.get("OPENCODE_MODEL")
        or "minimax-m3"
    )
    return {"api_key": key, "base_url": base, "model": model}


def chat_completion(messages: list[dict[str, str]], temperature: float = 0.2, timeout: int = 60) -> str | None:
    """Call OpenAI-compatible chat/completions. Returns assistant text or None."""
    cfg = _llm_config()
    if not cfg["api_key"]:
        return None
    body = {
        "model": cfg["model"],
        "messages": messages,
        "temperature": temperature,
    }
    url = f"{cfg['base_url']}/chat/completions"
    req = urlrequest.Request(
        url,
        data=json.dumps(body).encode("utf-8"),
        headers={
            "Authorization": f"Bearer {cfg['api_key']}",
            "Content-Type": "application/json",
            # Cloudflare / OpenCode Go rejects bare Python-urllib UA with 1010
            "User-Agent": "OmicsCanvas-PlotWeb/1.0 (Mozilla/5.0 compatible)",
            "Accept": "application/json",
        },
        method="POST",
    )
    try:
        with urlrequest.urlopen(req, timeout=timeout) as resp:
            payload = json.loads(resp.read().decode("utf-8"))
        content = payload["choices"][0]["message"]["content"]
        # some models wrap thinking tags
        if isinstance(content, str) and "<think>" in content:
            content = re.sub(r"<think>[\s\S]*?</think>", "", content).strip()
        return content
    except urlerror.HTTPError as exc:
        try:
            detail = exc.read().decode("utf-8", errors="replace")[:300]
        except Exception:
            detail = str(exc)
        # surface last error for status debugging via env (optional)
        os.environ["AI_LAST_LLM_ERROR"] = f"HTTP {exc.code}: {detail}"
        return None
    except (urlerror.URLError, TimeoutError, KeyError, IndexError, TypeError, json.JSONDecodeError) as exc:
        os.environ["AI_LAST_LLM_ERROR"] = f"{type(exc).__name__}: {exc}"
        return None


# ---------------------------------------------------------------------------
# Table profiling
# ---------------------------------------------------------------------------

def _is_number(value: Any) -> bool:
    if value is None:
        return False
    text = str(value).strip()
    if not text or text.lower() in {"na", "nan", "null", "none"}:
        return False
    try:
        float(text)
        return True
    except ValueError:
        return False


def profile_table(path: Path, max_rows: int = 80, sheet: str | int | None = 0) -> dict[str, Any]:
    """Profile CSV/TSV/TXT or Excel (.xlsx) tables for AI Studio / recommenders."""
    from plot_web.table_io import ensure_tabular_csv, is_excel_file, read_table_as_dicts

    source_path = Path(path)
    working = source_path
    converted_from = None
    was_excel = is_excel_file(source_path)
    if was_excel:
        # Prefer a sibling CSV so later demo adapters can open as text
        working = ensure_tabular_csv(source_path, sheet=sheet)
        converted_from = str(source_path)

    columns, rows, meta = read_table_as_dicts(working, max_rows=max_rows, sheet=sheet)

    numeric_columns: list[str] = []
    categorical_columns: list[str] = []
    for col in columns:
        values = [r.get(col, "") for r in rows]
        n_num = sum(1 for v in values if _is_number(v))
        n_nonempty = sum(1 for v in values if str(v).strip())
        if n_nonempty and n_num >= max(1, int(n_nonempty * 0.7)):
            numeric_columns.append(col)
        elif n_nonempty:
            categorical_columns.append(col)

    cat_card: dict[str, int] = {}
    for col in categorical_columns:
        cat_card[col] = len({str(r.get(col, "")).strip() for r in rows if str(r.get(col, "")).strip()})

    n_rows_est = int(meta.get("row_count_estimate") or len(rows))
    n_num = len(numeric_columns)
    n_cat = len(categorical_columns)
    n_col = len(columns)

    tags: list[str] = []
    if converted_from:
        tags.append("excel_upload")
    if n_num >= 5 and n_cat <= 2:
        tags.append("numeric_matrix")
    if n_cat >= 2 and n_num >= 1:
        tags.append("tidy_mixed")
    if n_cat >= 1 and n_num == 0:
        tags.append("categorical_only")
    if n_col == 2 and n_cat >= 1:
        tags.append("pair_or_set")
    if any(re.search(r"source|target|from|to", c, re.I) for c in columns):
        tags.append("edge_list")
    if any(re.search(r"dim|umap|tsne|pc\d|embedding", c, re.I) for c in columns):
        tags.append("embedding")
    if any(re.search(r"p_?val|padj|fdr|log2?fc|avg_log", c, re.I) for c in columns):
        tags.append("de_stats")
    if any(re.search(r"nes|pathway|term|enrich", c, re.I) for c in columns):
        tags.append("enrichment")
    if any(re.search(r"stage|time|visit|t\d", c, re.I) for c in columns):
        tags.append("stages")
    if n_num >= 3 and n_cat >= 1 and n_col <= 20:
        tags.append("multi_metric")
    if not tags or tags == ["excel_upload"]:
        tags.append("generic_table")

    delimiter = meta.get("delimiter") or ","
    return {
        "filename": source_path.name,
        "path": str(working),
        "original_path": converted_from or str(source_path),
        "converted_csv": str(working) if converted_from else None,
        "delimiter": delimiter,
        "columns": columns,
        "numeric_columns": numeric_columns,
        "categorical_columns": categorical_columns,
        "categorical_cardinality": cat_card,
        "preview_rows": rows[:12],
        "row_count_estimate": n_rows_est,
        "column_count": n_col,
        "tags": tags,
        "format": "xlsx" if was_excel else meta.get("format"),
        "excel": bool(was_excel or meta.get("excel")),
        "sheet": sheet if was_excel else None,
    }


# ---------------------------------------------------------------------------
# Rule-based recommendations
# ---------------------------------------------------------------------------

# plugin_id -> (priority keywords/tags, reason template, default param hints)
RULES: list[dict[str, Any]] = [
    {
        "plugin_id": "sca_volcano_plot",
        "score_tags": {"de_stats": 8},
        "score_cols": [r"p_?val|padj|fdr", r"log2?fc|avg_log"],
        "reason": "Table looks like differential expression (p-value + logFC) → volcano plot.",
        "goal_keywords": ["de", "differential", "volcano", "差异", "火山"],
    },
    {
        "plugin_id": "fgsea_enrichment_plot",
        "score_tags": {"enrichment": 8},
        "score_cols": [r"nes|pathway|term|enrich|leading"],
        "reason": "Enrichment-style columns detected → FGSEA / enrichment curve panel.",
        "goal_keywords": ["enrich", "gsea", "pathway", "富集", "通路"],
    },
    {
        "plugin_id": "advanced_dim_plot",
        "score_tags": {"embedding": 9},
        "score_cols": [r"umap|tsne|dim[12]|pc[12]"],
        "reason": "Embedding coordinates found → dimension / UMAP-style group plot.",
        "goal_keywords": ["umap", "tsne", "embedding", "降维", "聚类可视化"],
    },
    {
        "plugin_id": "alluvial_plot",
        "score_tags": {"stages": 7},
        "score_cols": [r"stage|time|visit"],
        "reason": "Sequential stage/time columns → multi-stage alluvial flow.",
        "goal_keywords": ["alluvial", "flow", "trajectory", "阶段", "流转", "克隆"],
    },
    {
        "plugin_id": "interactive_sankey_plot",
        "score_tags": {"edge_list": 8},
        "score_cols": [r"source|target|from|to"],
        "reason": "Source/target edge list → Sankey / flow network.",
        "goal_keywords": ["sankey", "flow", "edge", "桑基"],
    },
    {
        "plugin_id": "interactive_network_plot",
        "score_tags": {"edge_list": 6},
        "score_cols": [r"source|target|weight"],
        "reason": "Network edge structure → interactive network plot.",
        "goal_keywords": ["network", "graph", "网络", "互作"],
    },
    {
        "plugin_id": "interactive_correlation_matrix",
        "score_tags": {"numeric_matrix": 6},
        "score_cols": [],
        "min_numeric": 4,
        "reason": "Many numeric columns → correlation heatmap matrix.",
        "goal_keywords": ["correlation", "相关", "corr"],
    },
    {
        "plugin_id": "group_heatmap",
        "score_tags": {"numeric_matrix": 7},
        "score_cols": [],
        "min_numeric": 5,
        "reason": "Numeric matrix shape → group heatmap / clustered expression map.",
        "goal_keywords": ["heatmap", "热图", "expression matrix", "表达矩阵"],
    },
    {
        "plugin_id": "pie_dot_matrix",
        "score_tags": {"numeric_matrix": 5, "multi_metric": 4},
        "score_cols": [r"K\d+|ko|gene|feature"],
        "reason": "Category × feature numeric grid → pie-dot ratio matrix.",
        "goal_keywords": ["presence", "ratio", "binary matrix", "有无", "比例圆"],
    },
    {
        "plugin_id": "combo_bar_dot_matrix",
        "score_tags": {"multi_metric": 5},
        "score_cols": [r"auprc|auroc|score|metric"],
        "reason": "Metric scores + possible feature flags → bar + bottom dot matrix.",
        "goal_keywords": ["benchmark", "auprc", "对比柱状", "特征组合"],
    },
    {
        "plugin_id": "highlight_effect_plot",
        "score_tags": {"tidy_mixed": 5},
        "score_cols": [r"category|group|cell|type|term"],
        "min_numeric": 1,
        "reason": "Category + value observations → highlight effect (focus vs other cloud).",
        "goal_keywords": ["highlight", "effect", "ci", "重点", "误差棒"],
    },
    {
        "plugin_id": "stacked_bar_plot",
        "score_tags": {"tidy_mixed": 5, "numeric_matrix": 4},
        "score_cols": [r"sample|group|abundance|percent"],
        "reason": "Composition-style table → stacked bar composition chart.",
        "goal_keywords": ["composition", "stack", "组成", "堆积", "相对丰度"],
    },
    {
        "plugin_id": "classified_bar_plot",
        "score_tags": {"tidy_mixed": 4, "categorical_only": 2},
        "score_cols": [r"type|class|category"],
        "min_numeric": 1,
        "reason": "Labeled categories with values → classified bar chart.",
        "goal_keywords": ["bar", "柱状", "分类"],
    },
    {
        "plugin_id": "interactive_violin_plot",
        "score_tags": {"tidy_mixed": 5},
        "score_cols": [r"group|cluster|condition"],
        "min_numeric": 1,
        "reason": "Grouped continuous values → violin / box distribution.",
        "goal_keywords": ["violin", "distribution", "分布", "箱线"],
    },
    {
        "plugin_id": "interactive_ridgeline_plot",
        "score_tags": {"tidy_mixed": 4},
        "score_cols": [r"group|cluster"],
        "min_numeric": 1,
        "reason": "Multiple groups of continuous values → ridgeline densities.",
        "goal_keywords": ["ridge", "density", "密度", "山脊"],
    },
    {
        "plugin_id": "regression_scatter_plot",
        "score_tags": {"generic_table": 2},
        "score_cols": [],
        "min_numeric": 2,
        "reason": "At least two numeric columns → regression / scatter relationship.",
        "goal_keywords": ["scatter", "regression", "相关散点", "回归"],
    },
    {
        "plugin_id": "quadrant_correlation_scatter",
        "score_tags": {},
        "score_cols": [],
        "min_numeric": 2,
        "reason": "Two metrics → quadrant correlation scatter.",
        "goal_keywords": ["quadrant", "象限"],
    },
    {
        "plugin_id": "dynamic_venn_diagram",
        "score_tags": {"pair_or_set": 5, "categorical_only": 3},
        "score_cols": [r"set|group|element|gene"],
        "reason": "Set membership style data → Venn / flower diagram.",
        "goal_keywords": ["venn", "overlap", "韦恩", "交集"],
    },
    {
        "plugin_id": "interactive_pie_plot",
        "score_tags": {"categorical_only": 3, "tidy_mixed": 2},
        "score_cols": [r"category|label|type"],
        "reason": "Category proportions → pie / donut chart.",
        "goal_keywords": ["pie", "donut", "饼图", "占比"],
    },
    {
        "plugin_id": "stat_plot",
        "score_tags": {"tidy_mixed": 3, "categorical_only": 3},
        "score_cols": [r"cluster|sample|condition|group"],
        "reason": "Metadata levels → multi-type stat plot (bar/pie/sankey/…).",
        "goal_keywords": ["stat", "metadata", "组成统计"],
    },
    {
        "plugin_id": "balloon_plot",
        "score_tags": {"numeric_matrix": 5},
        "score_cols": [],
        "min_numeric": 4,
        "reason": "Numeric matrix → balloon / sized-tile matrix.",
        "goal_keywords": ["balloon", "dot matrix"],
    },
    {
        "plugin_id": "interactive_binary_plot",
        "score_tags": {"numeric_matrix": 3},
        "score_cols": [],
        "reason": "0/1-like matrix → binary presence/absence dots.",
        "goal_keywords": ["binary", "presence", "有无"],
    },
]


def _plugin_catalog(plugin_dir: Path) -> dict[str, dict[str, Any]]:
    catalog: dict[str, dict[str, Any]] = {}
    for config_path in sorted(plugin_dir.glob("*/config.yaml")):
        pid = config_path.parent.name
        try:
            import yaml

            cfg = yaml.safe_load(config_path.read_text(encoding="utf-8")) or {}
        except Exception:
            cfg = {}
        if not isinstance(cfg, dict):
            cfg = {}
        catalog[pid] = {
            "id": pid,
            "name": cfg.get("display_name") or cfg.get("name") or pid,
            "description": (cfg.get("description") or "")[:280],
            "category": cfg.get("category") or "",
            "has_demo": bool(list(config_path.parent.glob("example*.csv"))),
        }
    return catalog


def recommend_plugins(
    profile: dict[str, Any],
    plugin_dir: Path,
    goal: str = "",
    top_k: int = 3,
) -> list[dict[str, Any]]:
    catalog = _plugin_catalog(plugin_dir)
    goal_l = (goal or "").lower()
    columns = profile.get("columns") or []
    tags = set(profile.get("tags") or [])
    n_num = len(profile.get("numeric_columns") or [])
    scores: dict[str, float] = {pid: 0.0 for pid in catalog}
    reasons: dict[str, str] = {}

    for rule in RULES:
        pid = rule["plugin_id"]
        if pid not in catalog:
            continue
        score = 0.0
        for tag, w in (rule.get("score_tags") or {}).items():
            if tag in tags:
                score += float(w)
        for pattern in rule.get("score_cols") or []:
            if any(re.search(pattern, c, re.I) for c in columns):
                score += 3.0
        min_numeric = rule.get("min_numeric")
        if min_numeric and n_num >= int(min_numeric):
            score += 2.0
        for kw in rule.get("goal_keywords") or []:
            if kw.lower() in goal_l:
                score += 5.0
        if score > scores.get(pid, 0):
            # keep best reason when improving
            pass
        if score > 0:
            scores[pid] = scores.get(pid, 0) + score
            reasons[pid] = rule.get("reason") or catalog[pid]["description"]

    # mild prior for plugins with demos
    for pid, meta in catalog.items():
        if meta.get("has_demo"):
            scores[pid] = scores.get(pid, 0) + 0.2

    # ensure at least a few fallbacks
    if max(scores.values() or [0]) < 1:
        for pid in ("stacked_bar_plot", "classified_bar_plot", "regression_scatter_plot", "group_heatmap"):
            if pid in catalog:
                scores[pid] = scores.get(pid, 0) + 1.5
                reasons.setdefault(pid, "General-purpose fit for mixed tables.")

    ranked = sorted(scores.items(), key=lambda kv: (-kv[1], kv[0]))
    out: list[dict[str, Any]] = []
    for pid, sc in ranked:
        if sc <= 0 and len(out) >= top_k:
            break
        if pid not in catalog:
            continue
        meta = catalog[pid]
        out.append(
            {
                "plugin_id": pid,
                "name": meta["name"],
                "description": meta["description"],
                "category": meta["category"],
                "score": round(sc, 2),
                "reason": reasons.get(pid) or meta["description"] or "Matches table structure.",
                "has_demo": meta["has_demo"],
                "editor_url": f"/static/editor.html?plugin={pid}",
            }
        )
        if len(out) >= top_k:
            break
    return out


# ---------------------------------------------------------------------------
# Optional SpaceXAI refinement
# ---------------------------------------------------------------------------

def refine_with_spacexai(
    profile: dict[str, Any],
    candidates: list[dict[str, Any]],
    goal: str = "",
    model: str | None = None,
) -> list[dict[str, Any]] | None:
    # Keep payload small
    slim_profile = {
        "columns": profile.get("columns"),
        "numeric_columns": profile.get("numeric_columns"),
        "categorical_columns": profile.get("categorical_columns"),
        "tags": profile.get("tags"),
        "row_count_estimate": profile.get("row_count_estimate"),
        "preview_rows": (profile.get("preview_rows") or [])[:5],
    }
    slim_cands = [
        {"plugin_id": c["plugin_id"], "name": c["name"], "reason": c["reason"], "score": c["score"]}
        for c in candidates
    ]
    system = (
        "You are a bioinformatics visualization assistant for OmicsCanvas. "
        "Given a data profile and candidate plot plugins, return JSON only: "
        '{"recommendations":[{"plugin_id":"...","reason":"...","confidence":0-1}]} '
        "Use only the provided plugin_ids. Prefer at most 3 items. "
        "Write all reason strings in English only (no Chinese characters)."
    )
    user = json.dumps({"goal": goal, "profile": slim_profile, "candidates": slim_cands}, ensure_ascii=False)
    # temporarily override model if caller passes one
    prev_model = os.environ.get("OPENAI_MODEL")
    if model:
        os.environ["OPENAI_MODEL"] = model
    try:
        text = chat_completion(
            [
                {"role": "system", "content": system},
                {"role": "user", "content": user},
            ],
            temperature=0.2,
            timeout=45,
        )
    finally:
        if model:
            if prev_model is None:
                os.environ.pop("OPENAI_MODEL", None)
            else:
                os.environ["OPENAI_MODEL"] = prev_model

    if not text:
        return None

    text = text.strip()
    if text.startswith("```"):
        text = re.sub(r"^```(?:json)?\s*", "", text)
        text = re.sub(r"\s*```$", "", text)
    try:
        parsed = json.loads(text)
    except json.JSONDecodeError:
        m = re.search(r"\{[\s\S]*\}", text)
        if not m:
            return None
        try:
            parsed = json.loads(m.group(0))
        except json.JSONDecodeError:
            return None

    recs = parsed.get("recommendations") if isinstance(parsed, dict) else None
    if not isinstance(recs, list) or not recs:
        return None

    by_id = {c["plugin_id"]: c for c in candidates}
    refined: list[dict[str, Any]] = []
    for item in recs:
        if not isinstance(item, dict):
            continue
        pid = item.get("plugin_id")
        if pid not in by_id:
            continue
        base = dict(by_id[pid])
        if item.get("reason"):
            base["reason"] = str(item["reason"])
        if item.get("confidence") is not None:
            try:
                base["confidence"] = float(item["confidence"])
            except (TypeError, ValueError):
                pass
        base["source"] = "llm"
        refined.append(base)
    return refined or None


# ---------------------------------------------------------------------------
# Demo builder from user table
# ---------------------------------------------------------------------------

def _write_csv(path: Path, columns: list[str], rows: list[dict[str, Any]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as fh:
        writer = csv.DictWriter(fh, fieldnames=columns, extrasaction="ignore")
        writer.writeheader()
        for row in rows:
            writer.writerow({c: row.get(c, "") for c in columns})


def _subsample_rows(rows: list[dict[str, Any]], max_n: int = 60) -> list[dict[str, Any]]:
    if len(rows) <= max_n:
        return rows
    # even stride
    step = max(1, len(rows) // max_n)
    out = rows[::step][:max_n]
    return out


def build_params_for_plugin(plugin_id: str, profile: dict[str, Any]) -> dict[str, Any]:
    """Heuristic params so adapted user data can run."""
    cols = profile.get("columns") or []
    num = profile.get("numeric_columns") or []
    cat = profile.get("categorical_columns") or []
    params: dict[str, Any] = {
        "title": f"AI demo · {plugin_id}",
        "title_show": True,
        "width": 8,
        "height": 5.5,
        "dpi": 150,
    }

    if plugin_id in {"classified_bar_plot", "stacked_bar_plot"}:
        if cat:
            params["category_column"] = cat[0]
        if len(cat) > 1:
            params["type_column"] = cat[1]
        if num:
            params["value_column"] = num[0]
    elif plugin_id in {"regression_scatter_plot", "quadrant_correlation_scatter"}:
        if len(num) >= 2:
            params["x_column"] = num[0]
            params["y_column"] = num[1]
        if cat:
            params["group_column"] = cat[0]
    elif plugin_id == "highlight_effect_plot":
        if cat:
            params["category_column"] = cat[0]
        if num:
            params["value_column"] = num[0]
        # auto highlight handled in plugin
        params["auto_highlight_n"] = 4
        params["collapse_others"] = True
    elif plugin_id == "interactive_violin_plot":
        if cat:
            params["group_column"] = cat[0]
        if num:
            params["value_column"] = num[0]
    elif plugin_id == "interactive_pie_plot":
        if cat:
            params["category_column"] = cat[0]
        if num:
            params["value_column"] = num[0]
    elif plugin_id == "sca_volcano_plot":
        for c in cols:
            if re.search(r"log2?fc|avg_log", c, re.I):
                params["log2fc_column"] = c
            if re.search(r"p_?val_adj|padj|fdr", c, re.I):
                params["pvalue_column"] = c
            elif re.search(r"p_?val|pvalue", c, re.I) and "pvalue_column" not in params:
                params["pvalue_column"] = c
    elif plugin_id in {"group_heatmap", "balloon_plot", "threshold_matrix_heatmap", "pie_dot_matrix"}:
        if cat:
            params["row_column"] = cat[0]
            params["row_label_column"] = cat[0]
        if num:
            params["value_columns"] = num[:12]
    elif plugin_id == "combo_bar_dot_matrix":
        if cat:
            params["x_column"] = cat[0]
        if num:
            params["y_column"] = num[0]
        if len(num) > 1:
            params["se_column"] = num[1]
        params["matrix_show"] = False
    elif plugin_id == "alluvial_plot":
        stage_like = [c for c in cols if re.search(r"stage|time|t\d|visit", c, re.I)]
        if len(stage_like) >= 2:
            params["input_mode"] = "wide"
            params["stage_columns"] = stage_like[:6]
        elif cat:
            params["input_mode"] = "wide"
    elif plugin_id in {"interactive_sankey_plot", "interactive_network_plot"}:
        src = next((c for c in cols if re.search(r"source|from", c, re.I)), cols[0] if cols else "source")
        tgt = next((c for c in cols if re.search(r"target|to", c, re.I)), cols[1] if len(cols) > 1 else "target")
        params["source_column"] = src
        params["target_column"] = tgt
        if num:
            params["value_column"] = num[0]
    elif plugin_id == "advanced_dim_plot":
        x = next((c for c in cols if re.search(r"umap_1|dim1|pc1|tsne_1", c, re.I)), num[0] if num else None)
        y = next((c for c in cols if re.search(r"umap_2|dim2|pc2|tsne_2", c, re.I)), num[1] if len(num) > 1 else None)
        if x:
            params["x_column"] = x
        if y:
            params["y_column"] = y
        if cat:
            params["group_column"] = cat[0]

    return params


def prepare_demo_files(
    plugin_id: str,
    source_path: Path,
    profile: dict[str, Any],
    work_dir: Path,
    max_rows: int = 60,
) -> tuple[dict[str, Path], dict[str, Any], str]:
    """Write adapted input + params into work_dir.

    Returns (saved_files, params, note).
    """
    work_dir.mkdir(parents=True, exist_ok=True)
    preview = profile.get("preview_rows") or []
    # re-read more rows for subsample (CSV/TSV or converted Excel)
    from plot_web.table_io import ensure_tabular_csv, read_table_as_dicts

    tabular = ensure_tabular_csv(Path(profile.get("converted_csv") or source_path))
    columns, all_rows, _meta = read_table_as_dicts(tabular, max_rows=None)
    if not columns:
        columns = list(profile.get("columns") or [])
    rows = _subsample_rows(all_rows or preview, max_rows)
    if not columns and rows:
        columns = list(rows[0].keys())

    out_csv = work_dir / "ai_demo_input.csv"
    _write_csv(out_csv, columns, rows)
    params = build_params_for_plugin(plugin_id, profile)
    params["plugin_id"] = plugin_id
    params_path = work_dir / "params.json"
    params_path.write_text(json.dumps(params, indent=2, ensure_ascii=False), encoding="utf-8")

    note = (
        f"Sampled {len(rows)} / ~{profile.get('row_count_estimate', '?')} rows "
        f"from {source_path.name}; mapped columns heuristically for {plugin_id}."
    )
    return {"file": out_csv, "input": out_csv}, params, note


def ai_status() -> dict[str, Any]:
    cfg = _llm_config()
    has_key = bool(cfg["api_key"])
    return {
        "rule_engine": True,
        "spacexai": has_key,  # UI pill still uses this flag for "LLM on"
        "llm": has_key,
        "model": cfg["model"] if has_key else None,
        "base_url": cfg["base_url"] if has_key else None,
        "message": (
            f"Rule engine + LLM online ({cfg['base_url']}, model={cfg['model']})."
            if has_key
            else "Rule engine online. Set OPENCODE_API_KEY or XAI_API_KEY in plot_web/.env for LLM refinement."
        ),
        "last_error": os.environ.get("AI_LAST_LLM_ERROR"),
    }


def summarize_intent(profile: dict[str, Any], goal: str = "", recommendations: list[dict[str, Any]] | None = None) -> dict[str, Any]:
    """Summarize what the user wants (rules first; LLM polish if available)."""
    tags = profile.get("tags") or []
    cols = profile.get("columns") or []
    n_num = len(profile.get("numeric_columns") or [])
    n_cat = len(profile.get("categorical_columns") or [])
    recs = recommendations or []

    base_summary = (
        f"Table “{profile.get('filename') or 'upload'}” has ~{profile.get('row_count_estimate', '?')} rows, "
        f"{profile.get('column_count', len(cols))} columns "
        f"({n_num} numeric, {n_cat} categorical). "
        f"Detected structure tags: {', '.join(tags) or 'generic'}."
    )
    if goal:
        base_summary += f" User goal: {goal}."
    if recs:
        top = ", ".join(r.get("plugin_id") or r.get("name") or "?" for r in recs[:3])
        base_summary += f" Top plot matches: {top}."

    intent = {
        "summary": base_summary,
        "goal": goal or None,
        "tags": tags,
        "suggested_analysis": [r.get("plugin_id") for r in recs[:3] if r.get("plugin_id")],
        "source": "rules",
    }

    text = chat_completion(
        [
            {
                "role": "system",
                "content": (
                    "You summarize omics plotting intent in English only. "
                    "Return JSON only: "
                    '{"summary":"2-4 sentences","analysis_goal":"...","data_type":"...","recommended_focus":"..."}'
                ),
            },
            {
                "role": "user",
                "content": json.dumps(
                    {
                        "goal": goal,
                        "profile": {
                            "filename": profile.get("filename"),
                            "columns": cols[:30],
                            "numeric_columns": profile.get("numeric_columns"),
                            "categorical_columns": profile.get("categorical_columns"),
                            "tags": tags,
                            "row_count_estimate": profile.get("row_count_estimate"),
                        },
                        "candidates": [
                            {"plugin_id": r.get("plugin_id"), "reason": r.get("reason")} for r in recs[:5]
                        ],
                    },
                    ensure_ascii=False,
                ),
            },
        ],
        temperature=0.2,
        timeout=40,
    )
    if text:
        raw = text.strip()
        if raw.startswith("```"):
            raw = re.sub(r"^```(?:json)?\s*", "", raw)
            raw = re.sub(r"\s*```$", "", raw)
        try:
            parsed = json.loads(raw)
            if isinstance(parsed, dict) and parsed.get("summary"):
                intent["summary"] = str(parsed["summary"])
                intent["analysis_goal"] = parsed.get("analysis_goal")
                intent["data_type"] = parsed.get("data_type")
                intent["recommended_focus"] = parsed.get("recommended_focus")
                intent["source"] = "llm+rules"
        except json.JSONDecodeError:
            # use free text if model returned prose
            if len(raw) > 20 and not re.search(r"[\u4e00-\u9fff]", raw):
                intent["summary"] = raw[:800]
                intent["source"] = "llm+rules"
    return intent


def match_skills(
    profile: dict[str, Any],
    recommendations: list[dict[str, Any]],
    skills_dir: Path,
    goal: str = "",
) -> list[dict[str, Any]]:
    """Match repo skills (and plugin capabilities) to the request. Skills are authoring guides, not plot engines."""
    matches: list[dict[str, Any]] = []
    goal_l = (goal or "").lower()
    rec_ids = {r.get("plugin_id") for r in recommendations if r.get("plugin_id")}
    tags = set(profile.get("tags") or [])

    if not skills_dir.is_dir():
        return matches

    for skill_path in sorted(skills_dir.glob("*/SKILL.md")):
        skill_id = skill_path.parent.name
        text = skill_path.read_text(encoding="utf-8", errors="replace")
        # crude frontmatter / body parse
        name = skill_id
        desc = ""
        m = re.search(r"^name:\s*(.+)$", text, re.M)
        if m:
            name = m.group(1).strip()
        m = re.search(r"^description:\s*(.+)$", text, re.M)
        if m:
            desc = m.group(1).strip()
        # plugins mentioned in skill
        mentioned = set(re.findall(r"plugins/([a-z0-9_]+)", text))
        score = 0.0
        reasons = []
        overlap = mentioned & rec_ids
        if overlap:
            score += 5.0 * len(overlap)
            reasons.append(f"Covers recommended plugins: {', '.join(sorted(overlap))}")
        for kw in ("heatmap", "volcano", "venn", "enrichment", "dimension", "correlation", "plot"):
            if kw in text.lower() and (kw in goal_l or any(kw in t for t in tags)):
                score += 1.5
        if score <= 0 and skill_id == "omics-plot-plugins":
            # always lightly relevant as the plot-plugin skill
            score = 1.0
            reasons.append("General OmicsCanvas plot-plugin authoring skill")
        if score > 0:
            matches.append(
                {
                    "skill_id": skill_id,
                    "name": name,
                    "description": (desc or text[:180].replace("\n", " "))[:240],
                    "path": str(skill_path.relative_to(skills_dir.parent)) if skills_dir.parent.exists() else str(skill_path),
                    "related_plugins": sorted(mentioned)[:12],
                    "score": round(score, 2),
                    "reason": "; ".join(reasons) or "Related to plotting workflow",
                    "role": "authoring_guide",
                    "note": "Skills guide how agents build/edit plugins; they do not render figures themselves.",
                }
            )
    matches.sort(key=lambda x: -x["score"])
    return matches[:5]


def explain_figure(
    *,
    plugin_id: str,
    plugin_name: str = "",
    reason: str = "",
    goal: str = "",
    profile: dict[str, Any] | None = None,
    figure_meta: dict[str, Any] | None = None,
    run_status: str = "completed",
    mode: str = "",
) -> dict[str, Any]:
    """Explain a generated figure in English (LLM if available, else template)."""
    profile = profile or {}
    figure_meta = figure_meta or {}
    template = (
        f"Plot type: {plugin_name or plugin_id}. "
        f"Why suggested: {reason or 'Matched table structure and goal'}. "
        f"Run status: {run_status}"
        + (f" (data mode: {mode})." if mode else ".")
        + " Use the figure to check whether the visual pattern supports your analysis goal; "
        "open the Editor to adjust aesthetics, axes, and highlights."
    )
    out = {"explanation": template, "source": "rules"}

    text = chat_completion(
        [
            {
                "role": "system",
                "content": (
                    "You explain scientific plots for life-science users. "
                    "English only. Be concrete and short (3-6 sentences). "
                    "Cover: what the plot shows, why it fits the data/goal, "
                    "what to look for, and one caveat. No Chinese characters."
                ),
            },
            {
                "role": "user",
                "content": json.dumps(
                    {
                        "plugin_id": plugin_id,
                        "plugin_name": plugin_name,
                        "recommendation_reason": reason,
                        "user_goal": goal,
                        "data_tags": profile.get("tags"),
                        "columns": (profile.get("columns") or [])[:25],
                        "figure_meta": figure_meta,
                        "run_status": run_status,
                        "data_mode": mode,
                    },
                    ensure_ascii=False,
                ),
            },
        ],
        temperature=0.35,
        timeout=50,
    )
    if text and text.strip():
        cleaned = re.sub(r"<think>[\s\S]*?</think>", "", text).strip()
        if cleaned and not re.search(r"[\u4e00-\u9fff]", cleaned):
            out["explanation"] = cleaned
            out["source"] = "llm"
    return out
