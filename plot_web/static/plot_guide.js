/* Registry-driven Plot Guide panel for Plot Studio. */
const GUIDE_OPEN_KEY = "omicscanvas.plotGuideOpen";

const PlotGuide = {
  tab: "about",
  payload: null,
  open: true,
};

function guideFamilyId() {
  return state.detail?.registry?.family_id || urlParams.get("plot") || state.pluginId;
}

function guideExampleId() {
  return state.selectedExampleId || STUDIO_EXAMPLE || "";
}

function guideEscape(value) {
  return String(value || "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/"/g, "&quot;");
}

function statementClass(type) {
  if (type === "direct") return "guide-item is-direct";
  if (type === "caution") return "guide-item is-caution";
  return "guide-item is-interpretation";
}

function statementMark(type) {
  if (type === "direct") return "Direct";
  if (type === "caution") return "Be careful";
  return "Interpretation";
}

function renderGuideList(title, items, kind) {
  if (!items || !items.length) return "";
  const rows = items.map((item) => {
    if (typeof item === "string") return `<li>${guideEscape(item)}</li>`;
    const type = item.type || kind;
    return `
      <li class="${statementClass(type)}">
        <span class="guide-flag">${statementMark(type)}</span>
        <strong>${guideEscape(item.title || "")}</strong>
        <p>${guideEscape(item.text || "")}</p>
      </li>`;
  }).join("");
  return `<section class="guide-block"><h4>${guideEscape(title)}</h4><ul class="guide-list">${rows}</ul></section>`;
}

function renderAboutGuide(payload) {
  const family = payload.family_guide || {};
  const variant = payload.variant?.guide;
  const more = family.learn_more ? `
    <details class="guide-learn-more">
      <summary>Learn more</summary>
      <p>${guideEscape(family.learn_more)}</p>
    </details>` : "";
  const variantBlock = variant ? `
    <section class="guide-block">
      <h4>Current view · ${guideEscape(payload.variant.name)}</h4>
      <p>${guideEscape(variant.summary || "")}</p>
      ${renderGuideList("Best for this view", variant.best_for || [], "interpretation")}
    </section>` : "";
  if (!payload.available) {
    return `<p class="guide-empty">${guideEscape(payload.empty_message || "Guide content is not available for this plot yet.")}</p>`;
  }
  return `
    <section class="guide-block">
      <h4>${guideEscape(payload.name)}</h4>
      <p>${guideEscape(family.summary || "")}</p>
    </section>
    ${renderGuideList("Best for", family.best_for || [])}
    ${renderGuideList("Common uses", family.common_uses || [])}
    ${renderGuideList("Be careful", family.cautions || [], "caution")}
    ${more}
    ${variantBlock}
  `;
}

function renderExamplesGuide(payload) {
  const examples = payload.examples || [];
  if (!examples.length) {
    return `<p class="guide-empty">No interactive examples are documented for this plot yet.</p>`;
  }
  return `<section class="guide-block"><h4>Examples</h4>
    <div class="guide-example-grid">${examples.map((ex) => `
      <article class="guide-example-card">
        <div class="guide-example-thumb">
          ${ex.preview_url ? `<img src="${guideEscape(ex.preview_url)}" alt="">` : `<div class="card-fallback-icon">▣</div>`}
        </div>
        <h5>${guideEscape(ex.title || ex.id)}</h5>
        <p>${guideEscape(ex.description || "")}</p>
        <button type="button" class="card-btn primary" data-try-example="${guideEscape(ex.demo_id || ex.id)}" data-try-variant="${guideEscape(ex.variant_id || "")}">Try Example</button>
      </article>
    `).join("")}</div>
    <p class="guide-hint">Try Example loads demo data and configuration for this visualization.</p>
  </section>`;
}

function renderLiteratureGuide(payload) {
  const items = payload.literature || [];
  if (!items.length) {
    return `<p class="guide-empty">No curated literature examples are recorded for this plot yet.</p>`;
  }
  return `<section class="guide-block"><h4>Published examples</h4>
    ${items.map((item) => `
      <article class="guide-lit-card">
        ${item.thumbnail_reuse_allowed && item.thumbnail_asset ? `<img class="guide-lit-thumb" src="${guideEscape(item.thumbnail_asset)}" alt="">` : ""}
        <strong>${guideEscape(item.citation || item.title)}</strong>
        <p>${guideEscape(item.description || "")}</p>
        ${item.relevance ? `<p class="guide-why"><span>Why this example?</span> ${guideEscape(item.relevance)}</p>` : ""}
        <p class="guide-meta">${[item.figure, item.license].filter(Boolean).map(guideEscape).join(" · ")}</p>
        ${item.url ? `<a class="card-btn secondary" href="${guideEscape(item.url)}" target="_blank" rel="noopener noreferrer">View paper</a>` : ""}
      </article>
    `).join("")}
  </section>`;
}

function renderInterpretGuide(payload) {
  const family = payload.family_guide || {};
  const variant = payload.variant?.guide || {};
  const current = payload.current || {};
  if (!payload.available) {
    return `<p class="guide-empty">${guideEscape(payload.empty_message || "Guide content is not available for this plot yet.")}</p>`;
  }
  return `
    <section class="guide-block">
      <h4>Current view</h4>
      <p><strong>${guideEscape(current.variant_name || payload.name)}</strong></p>
      <p>${guideEscape(current.summary || "")}</p>
      ${current.statements?.length ? `<ul class="guide-list">${current.statements.map((s) => `
        <li class="${statementClass(s.type)}">
          <span class="guide-flag">${statementMark(s.type)}</span>
          <strong>${guideEscape(s.title)}</strong>
          <p>${guideEscape(s.text)}</p>
        </li>`).join("")}</ul>` : ""}
    </section>
    ${renderGuideList("How to interpret", [...(family.interpretation || []), ...(variant.interpretation || [])], "interpretation")}
    ${renderGuideList("Limitations", [...(family.cautions || []), ...(variant.cautions || [])], "caution")}
    <section class="guide-block">
      <h4>How to report</h4>
      <p class="guide-caption" id="guideCaption">${guideEscape(payload.caption || "Caption is not available until mappings are set.")}</p>
      <button type="button" class="card-btn secondary" id="copyCaptionBtn">Copy caption</button>
    </section>
  `;
}

function renderPlotGuide() {
  const host = $("plotGuideContent");
  if (!host) return;
  const payload = PlotGuide.payload;
  if (!payload) {
    host.innerHTML = `<p class="guide-empty">Loading guide…</p>`;
    return;
  }
  let html = "";
  if (PlotGuide.tab === "examples") html = renderExamplesGuide(payload);
  else if (PlotGuide.tab === "literature") html = renderLiteratureGuide(payload);
  else if (PlotGuide.tab === "interpret") html = renderInterpretGuide(payload);
  else html = renderAboutGuide(payload);
  host.innerHTML = html;
  host.querySelectorAll("[data-try-example]").forEach((btn) => {
    btn.onclick = () => tryGuideExample(btn.dataset.tryExample, btn.dataset.tryVariant);
  });
  const copy = $("copyCaptionBtn");
  if (copy) {
    copy.onclick = async () => {
      const text = PlotGuide.payload?.caption || "";
      if (!text) return;
      try {
        await navigator.clipboard.writeText(text);
        copy.textContent = "Copied";
        setTimeout(() => { copy.textContent = "Copy caption"; }, 1200);
      } catch {
        copy.textContent = "Copy failed";
      }
    };
  }
}

async function refreshPlotGuide() {
  const family = guideFamilyId();
  if (!family) return;
  const params = new URLSearchParams();
  if (guideExampleId()) params.set("example", guideExampleId());
  if (STUDIO_VARIANT && !guideExampleId()) params.set("variant", STUDIO_VARIANT);
  const qs = params.toString() ? `?${params.toString()}` : "";
  try {
    const payload = await api(`/api/registry/plots/${encodeURIComponent(family)}/guide${qs}`);
    if (state.params && Object.keys(state.params).length) {
      const caption = await api(`/api/registry/plots/${encodeURIComponent(family)}/caption`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          example: guideExampleId() || null,
          variant: STUDIO_VARIANT || payload.variant?.id || null,
          params: state.params,
        }),
      });
      payload.caption = caption.caption || payload.caption;
      if (caption.current) payload.current = caption.current;
    }
    PlotGuide.payload = payload;
  } catch {
    PlotGuide.payload = {
      available: false,
      empty_message: "Guide content is not available for this plot yet.",
      examples: [],
      literature: [],
    };
  }
  renderPlotGuide();
}

function setPlotGuideOpen(open) {
  PlotGuide.open = open;
  sessionStorage.setItem(GUIDE_OPEN_KEY, open ? "1" : "0");
  document.body.classList.toggle("guide-collapsed", !open);
  const btn = $("plotGuideToggle");
  if (btn) {
    btn.textContent = open ? "‹" : "›";
    btn.setAttribute("aria-expanded", open ? "true" : "false");
  }
}

async function tryGuideExample(demoId, variantId) {
  if (!demoId) return;
  if (state.userTouchedParams) {
    const ok = window.confirm("Load this example’s demo data and configuration? Your current settings will be replaced.");
    if (!ok) return;
  }
  state.selectedExampleId = demoId;
  const sel = $("exampleSelect");
  if (sel) sel.value = demoId;
  $("jobStatus").textContent = `Loading example “${demoId}”…`;
  try {
    const rec = await api(`/api/plugins/${state.pluginId}/examples/${encodeURIComponent(demoId)}`);
    if (rec?.params) {
      let raw = rec.params;
      if (raw.params && typeof raw.params === "object") raw = raw.params;
      state.params = { ...raw };
      if (typeof syncJsonFromParams === "function") syncJsonFromParams();
    }
    if (typeof renderParamContentArea === "function") renderParamContentArea();
    if (typeof runDemoSilent === "function") await runDemoSilent();
    else if (typeof runDemo === "function") await runDemo();
    await refreshPlotGuide();
  } catch (err) {
    $("jobStatus").textContent = `Example failed: ${err.message}`;
  }
}

function initPlotGuide() {
  const stored = sessionStorage.getItem(GUIDE_OPEN_KEY);
  setPlotGuideOpen(stored === null ? true : stored === "1");
  $("plotGuideToggle")?.addEventListener("click", () => setPlotGuideOpen(!PlotGuide.open));
  document.querySelectorAll("[data-guide-tab]").forEach((btn) => {
    btn.onclick = () => {
      PlotGuide.tab = btn.dataset.guideTab;
      document.querySelectorAll("[data-guide-tab]").forEach((item) => {
        item.classList.toggle("active", item.dataset.guideTab === PlotGuide.tab);
      });
      renderPlotGuide();
    };
  });
  const media = window.matchMedia("(max-width: 1100px)");
  if (media.matches && stored === null) setPlotGuideOpen(false);
}
