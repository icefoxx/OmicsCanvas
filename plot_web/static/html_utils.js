// Shared HTML helpers. Load before any other app script.
//
// Any value that did not originate in this codebase (uploaded column names,
// cell values, file/dataset names, server error text, LLM output) must go
// through escapeHtml() before being interpolated into innerHTML.

function escapeHtml(value) {
  return String(value ?? "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

// Static pages and example previews do not need to download a charting runtime.
let plotlyLoadPromise = null;
function ensurePlotly() {
  if (window.Plotly) return Promise.resolve(true);
  if (plotlyLoadPromise) return plotlyLoadPromise;
  plotlyLoadPromise = new Promise((resolve) => {
    const script = document.createElement("script");
    script.src = "https://cdn.plot.ly/plotly-2.35.2.min.js";
    script.async = true;
    const timer = setTimeout(() => { resolve(false); plotlyLoadPromise = null; }, 8000);
    script.onload = () => { clearTimeout(timer); resolve(Boolean(window.Plotly)); };
    script.onerror = () => { clearTimeout(timer); plotlyLoadPromise = null; resolve(false); };
    document.head.appendChild(script);
  });
  return plotlyLoadPromise;
}

/** Scientific validation result returned with every run (PlotSpec layer). */
function renderValidationPanel(box, vnext) {
  if (!box) return;
  if (!vnext || (vnext.valid === undefined && !vnext.error)) {
    box.hidden = true;
    box.innerHTML = "";
    return;
  }
  box.hidden = false;
  if (vnext.error) {
    box.className = "validation-panel is-muted";
    box.innerHTML = `<div class="validation-head">PlotSpec unavailable</div><div class="validation-note">${escapeHtml(vnext.error)}</div>`;
    return;
  }
  const errors = vnext.errors || [];
  const warnings = vnext.warnings || [];
  const infos = vnext.infos || [];
  const tone = errors.length ? "is-error" : warnings.length ? "is-warning" : "is-ok";
  const headline = errors.length
    ? `${errors.length} scientific error${errors.length > 1 ? "s" : ""}${vnext.mode === "enforce" ? " — figure not rendered" : ""}`
    : warnings.length
      ? `${warnings.length} warning${warnings.length > 1 ? "s" : ""}`
      : "Scientific checks passed";
  const item = (issue) => `<li class="validation-item sev-${escapeHtml(issue.severity || "info")}">
      <code>${escapeHtml(issue.code)}</code> ${escapeHtml(issue.message)}</li>`;
  box.className = `validation-panel ${tone}`;
  box.innerHTML = `
    <div class="validation-head">
      <span>${escapeHtml(headline)}</span>
      <span class="validation-hash" title="PlotSpec hash">spec ${escapeHtml(String(vnext.plotspec_hash || "").slice(0, 10))}</span>
    </div>
    ${errors.length || warnings.length ? `<ul class="validation-list">${[...errors, ...warnings].map(item).join("")}</ul>` : ""}
    ${infos.length ? `<details class="validation-infos"><summary>${infos.length} note${infos.length > 1 ? "s" : ""}</summary><ul class="validation-list">${infos.map(item).join("")}</ul></details>` : ""}`;
}
