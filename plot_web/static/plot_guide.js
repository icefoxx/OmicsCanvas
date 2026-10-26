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
    .replace(/>/g, "&gt;")
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
    ${family.input_requirements ? `<section class="guide-block"><h4>Input requirements</h4><p>${guideEscape(family.input_requirements)}</p></section>` : ""}
    ${family.customization?.length ? `<details class="guide-learn-more"><summary>Customization · ${family.customization.length} controls</summary>${renderGuideList("Parameters", family.customization.map((item) => `${item.label} · ${item.parameter}${item.default == null ? "" : ` · default: ${JSON.stringify(item.default)}`}${item.help ? ` · ${item.help}` : ""}`))}</details>` : ""}
    ${renderGuideList("Be careful", family.cautions || [], "caution")}
    ${renderGuideList("Coverage notes", family.coverage_notes || [])}
    ${more}
    ${variantBlock}
  `;
}

function renderExampleSource(example, payload) {
  const paper = (payload.literature || []).find((item) => item.id === example.literature_id);
  if (!paper) return "";
  const context = [paper.authors || paper.citation, paper.journal, paper.year, paper.figure].filter(Boolean).join(" · ");
  return `<p class="guide-meta">${guideEscape(context)}</p>
    <p>${guideEscape(paper.title)}</p>
    ${paper.url ? `<a class="card-btn secondary" href="${guideEscape(paper.url)}" target="_blank" rel="noopener noreferrer">View paper</a>` : ""}`;
}

function renderExamplesGuide(payload) {
  const examples = payload.examples || [];
  const published = renderPublishedFigures(payload);
  if (!examples.length) {
    return `${published}<p class="guide-empty">No local runnable demos are documented for this plot yet.</p>`;
  }
  return `${published}<section class="guide-block"><h4>Local runnable demos</h4>
    <div class="guide-example-grid">${examples.map((ex) => `
      <article class="guide-example-card">
        <div class="guide-example-thumb">
          ${ex.preview_url ? `<img src="${guideEscape(ex.preview_url)}" alt="">` : `<div class="card-fallback-icon">▣</div>`}
        </div>
        <h5>${guideEscape(ex.title || ex.id)}</h5>
        <p>${guideEscape(ex.description || "")}</p>
        ${ex.input_requirements ? `<details><summary>Input and mappings</summary><p>${guideEscape(ex.input_requirements)}</p>${Object.entries(ex.mappings || {}).map(([key, value]) => `<p><code>${guideEscape(key)}</code>: ${guideEscape(typeof value === "string" ? value : JSON.stringify(value))}</p>`).join("")}</details>` : ""}
        ${ex.data_note ? `<p class="guide-hint">${guideEscape(ex.data_note)}</p>` : ""}
        ${renderExampleSource(ex, payload)}
        <button type="button" class="card-btn primary" data-try-example="${guideEscape(ex.demo_id || ex.id)}" data-try-variant="${guideEscape(ex.variant_id || "")}">Try Example</button>
      </article>
    `).join("")}</div>
    <p class="guide-hint">Try Example loads demo data and configuration for this visualization.</p>
  </section>`;
}

function renderPublishedFigures(payload) {
  const examples = payload.published_examples || [];
  if (!examples.length) {
    return `<section class="guide-block"><h4>Published figure examples</h4><p class="guide-empty">No figure-panel match has been verified for this plot yet. Method references and local demos, when available, are listed separately.</p></section>`;
  }
  return `<section class="guide-block"><h4>Published figure examples · ${examples.length}</h4>
    <p class="guide-hint">Open the source to inspect the published figure. Local demos use independent data and do not reproduce the paper's analysis.</p>
    ${examples.map((ex) => `<article class="guide-lit-card">
      <p class="guide-meta">${guideEscape(ex.authors)} · ${guideEscape(ex.journal)} · ${guideEscape(ex.year)}${ex.publication_status === "preprint" ? " · Preprint (not peer reviewed)" : ""}</p>
      <h5>${guideEscape(ex.figure)} · ${guideEscape(ex.title)}</h5>
      <p>${guideEscape(ex.paper_title)}</p>
      <p class="guide-meta">${ex.match_type === "same_grammar" ? "Same plot grammar" : "Related layout · adaptation required"}</p>
      <p>${guideEscape(ex.description)}</p>
      <details class="guide-learn-more"><summary>Apply this example to your data</summary><p>${guideEscape(ex.adaptation)}</p></details>
      <p class="guide-meta">Caption checked: ${guideEscape(ex.verified_on)}${ex.doi ? ` · DOI: ${guideEscape(ex.doi)}` : ""}</p>
      ${ex.figure_url ? `<a class="card-btn secondary" href="${guideEscape(ex.figure_url)}" target="_blank" rel="noopener noreferrer">View figure source</a>` : ""}
      ${ex.paper_url ? `<a class="card-btn secondary" href="${guideEscape(ex.paper_url)}" target="_blank" rel="noopener noreferrer">Read paper</a>` : ""}
    </article>`).join("")}
  </section>`;
}

function renderLiteratureGuide(payload) {
  const items = payload.literature || [];
  const modules = payload.family_guide?.source_modules || [];
  const moduleCard = (item) => `<li><a href="${guideEscape(item.url)}" target="_blank" rel="noopener noreferrer">${guideEscape(item.title)}</a></li>`;
  const moduleHtml = modules.length ? `<section class="guide-block"><h4>Related source examples</h4><p class="guide-meta">Visual grammar comparisons; analysis pipelines and original data are not reproduced.</p><ul class="guide-list">${modules.slice(0, 3).map(moduleCard).join("")}</ul>${modules.length > 3 ? `<details><summary>Show ${modules.length - 3} more source examples</summary><ul class="guide-list">${modules.slice(3).map(moduleCard).join("")}</ul></details>` : ""}</section>` : "";
  if (!items.length) {
    return `${renderPublishedFigures(payload)}${moduleHtml}<p class="guide-empty">No curated references are recorded for this plot yet.</p>`;
  }
  return `${renderPublishedFigures(payload)}<section class="guide-block"><h4>References & methodology</h4>
    ${items.map((item) => `
      <article class="guide-lit-card">
        ${item.thumbnail_reuse_allowed && item.thumbnail_asset ? `<img class="guide-lit-thumb" src="${guideEscape(item.thumbnail_asset)}" alt="">` : ""}
        <strong>${guideEscape(item.citation || item.title)}</strong>
        <p class="guide-meta">${item.reference_type === "method_reference" ? "Method reference · not a reproduction of the paper’s data" : "Published use case"}</p>
        <p>${guideEscape(item.description || "")}</p>
        ${item.relevance ? `<p class="guide-why"><span>Why this example?</span> ${guideEscape(item.relevance)}</p>` : ""}
        <p class="guide-meta">${[item.figure, item.license].filter(Boolean).map(guideEscape).join(" · ")}</p>
        ${item.url ? `<a class="card-btn secondary" href="${guideEscape(item.url)}" target="_blank" rel="noopener noreferrer">View paper</a>` : ""}
      </article>
    `).join("")}
  </section>${moduleHtml}`;
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
  if (!PlotGuide.payload.available) setPlotGuideOpen(false, { persist: false });
  renderPlotGuide();
}

function setPlotGuideOpen(open, { persist = true } = {}) {
  PlotGuide.open = open;
  if (persist) sessionStorage.setItem(GUIDE_OPEN_KEY, open ? "1" : "0");
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
  const sel = $("exampleSelect");
  if (sel) sel.value = demoId;
  await loadPreset(demoId, { useExampleData: true, previewOnly: true });
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
