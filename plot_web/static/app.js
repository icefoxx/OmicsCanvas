const state = {
  tree: [],
  plugins: [],
  selected: null,
  detail: null,
  schemaSections: [],
  activeSection: "basic",
  params: {},
  inputPreview: null,
  demo: null,
  selectedColumns: new Set(),
  selectedRows: new Set(),
  pointPickMode: "highlight",
  rowMode: "include",
  mode: "plotLibrary",
  serverState: null,
  datasets: [],
  results: [],
  reports: [],
  category: "All plots",
  previewScale: 1,
  examples: [],
  selectedExample: null,
};

const SCIENTIFIC_PALETTES = [
  { name: "NPG", colors: ["#E64B35", "#4DBBD5", "#00A087", "#3C5488", "#F39B7F", "#8491B4", "#91D1C2", "#DC0000"] },
  { name: "AAAS", colors: ["#3B4992", "#EE0000", "#008B45", "#631879", "#008280", "#BB0021", "#5F559B", "#A20056"] },
  { name: "NEJM", colors: ["#BC3C29", "#0072B5", "#E18727", "#20854E", "#7876B1", "#6F99AD", "#FFDC91", "#EE4C97"] },
  { name: "Lancet", colors: ["#00468B", "#ED0000", "#42B540", "#0099B4", "#925E9F", "#FDAF91", "#AD002A", "#ADB6B6"] },
  { name: "Viridis", colors: ["#440154", "#482677", "#3E4989", "#31688E", "#26828E", "#1F9E89", "#35B779", "#6ECE58", "#B5DE2B", "#FDE725"] },
  { name: "Plasma", colors: ["#0D0887", "#46039F", "#7201A8", "#9C179E", "#BD3786", "#D8576B", "#ED7953", "#FB9F3A", "#FDCA26", "#F0F921"] },
  { name: "Coolwarm", colors: ["#3B4CC0", "#6788EE", "#9ABBFF", "#C9D7F0", "#EDD1C2", "#F7A789", "#E26952", "#B40426"] },
  { name: "Spectral", colors: ["#9E0142", "#D53E4F", "#F46D43", "#FDAE61", "#FEE08B", "#E6F598", "#ABDDA4", "#66C2A5", "#3288BD", "#5E4FA2"] },
];

const $ = (id) => document.getElementById(id);

let autoUpdateTimer = null;

function isAutoUpdateEnabled() {
  const toggle = $("autoUpdateToggle");
  return toggle ? toggle.checked : true;
}

function triggerAutoUpdate(delay = 350) {
  if (!isAutoUpdateEnabled() || !state.selected) return;
  if (!state.inputPreview?.files && !state.demo) return;

  if (autoUpdateTimer) clearTimeout(autoUpdateTimer);

  autoUpdateTimer = setTimeout(async () => {
    const overlay = $("stageOverlay");
    if (overlay) overlay.classList.remove("hidden");
    try {
      if (hasAnyFile()) {
        await runPlotSilent();
      } else if (state.demo) {
        await runDemoSilent();
      }
    } catch (err) {
      console.warn("Auto update error:", err);
    } finally {
      if (overlay) overlay.classList.add("hidden");
    }
  }, delay);
}

async function runDemoSilent() {
  if (!state.selected) return;
  try {
    const payload = { params: sanitizeParamsForRun(state.params) };
    if (state.selectedExample?.id) payload.example_id = state.selectedExample.id;
    const result = await api(`/api/plugins/${state.selected}/run-demo`, {
      method: "POST",
      body: JSON.stringify(payload),
      headers: { "Content-Type": "application/json" }
    });
    if (result.status === "completed" && result.outputs?.preview) {
      await updateInstantPreview(result.outputs);
      renderDownloads(result.outputs);
      $("jobStatus").textContent = `⚡ Live Updated (${new Date().toLocaleTimeString()})`;
    } else if (result.status && result.status !== "completed") {
      $("jobStatus").textContent = `Auto update paused: ${result.detail || result.error || result.message || result.status}`;
    }
  } catch (err) {
    console.warn("Silent demo update failed:", err);
  }
}

async function runPlotSilent() {
  if (!state.selected) return;
  try {
    const form = collectFileFormData();
    form.append("params", prettify(state.params));
    const result = await api(`/api/plugins/${state.selected}/run`, {
      method: "POST",
      body: form
    });
    if (result.status === "completed" && result.outputs?.preview) {
      await updateInstantPreview(result.outputs);
      renderDownloads(result.outputs);
      $("jobStatus").textContent = `⚡ Live Updated (${new Date().toLocaleTimeString()})`;
    }
  } catch (err) {
    console.warn("Silent plot update failed:", err);
  }
}

function updatePreviewImage(url) {
  const img = $("preview");
  const plotlyBox = $("plotlyPreview");
  if (!img || !url) return;
  if (plotlyBox) {
    plotlyBox.classList.add("hidden");
    try { if (window.Plotly) Plotly.purge(plotlyBox); } catch {}
  }
  const sep = url.includes("?") ? "&" : "?";
  img.src = `${url}${sep}t=${Date.now()}`;
  setPreviewVisible(true);
}

async function updateInstantPreview(outputs = {}) {
  const rendered = await renderPlotlyPreview(outputs);
  if (!rendered && outputs.preview) updatePreviewImage(outputs.preview);
}

async function renderPlotlyPreview(outputs = {}) {
  const plotlyBox = $("plotlyPreview");
  const img = $("preview");
  if (!plotlyBox || !outputs.json) return false;
  try {
    const sep = outputs.json.includes("?") ? "&" : "?";
    const figure = await api(`${outputs.json}${sep}t=${Date.now()}`);
    const spec = figure?.plotly;
    if (!spec?.data?.length) return false;
    if (typeof ensurePlotly === "function" && !(await ensurePlotly())) return false;
    if (img) img.style.display = "none";
    plotlyBox.classList.remove("hidden");
    const config = {
      responsive: true,
      displaylogo: false,
      modeBarButtonsToAdd: ["select2d", "lasso2d"],
      scrollZoom: true,
    };
    await Plotly.react(plotlyBox, spec.data, spec.layout || {}, config);
    wirePlotlyPointSelection(plotlyBox);
    setPreviewVisible(true, "plotly");
    return true;
  } catch (err) {
    console.warn("Plotly preview unavailable:", err);
    return false;
  }
}

function pointIdFromPlotlyPoint(point) {
  if (!point) return "";
  const custom = Array.isArray(point.customdata) ? point.customdata[0] : point.customdata;
  return String(custom ?? point.text ?? "").trim();
}

function selectedIdsFromPlotlyEvent(event) {
  return Array.from(new Set((event?.points || []).map(pointIdFromPlotlyPoint).filter(Boolean)));
}

function applyPointSelection(ids, replace = false) {
  if (!ids.length) return;
  if (replace) state.selectedRows.clear();
  ids.forEach((id) => state.selectedRows.add(id));
  const selected = Array.from(state.selectedRows);
  state.params.selected_ids = selected;
  state.params.selected_genes = selected;
  if (state.pointPickMode === "label") {
    state.params.label_ids = selected;
    state.params.label_show = true;
    state.params.show_labels = true;
  }
  syncJsonFromParams();
  renderRowSelector();
  renderStageDataDrawer();
  triggerAutoUpdate(80);
}

function wirePlotlyPointSelection(plotlyBox) {
  plotlyBox.removeAllListeners?.("plotly_click");
  plotlyBox.removeAllListeners?.("plotly_selected");
  plotlyBox.on?.("plotly_click", (event) => applyPointSelection(selectedIdsFromPlotlyEvent(event), false));
  plotlyBox.on?.("plotly_selected", (event) => applyPointSelection(selectedIdsFromPlotlyEvent(event), true));
}

async function api(path, options) {
  const res = await fetch(path, options);
  const text = await res.text();
  let data;
  try {
    data = text ? JSON.parse(text) : {};
  } catch {
    data = { raw: text };
  }
  if (!res.ok) {
    const message = data?.detail || data?.error?.detail || data?.error || `HTTP ${res.status}`;
    throw new Error(typeof message === "string" ? message : JSON.stringify(message));
  }
  return data;
}

function prettify(value) {
  return JSON.stringify(value || {}, null, 2);
}

function labelize(key) {
  return String(key)
    .replace(/_/g, " ")
    .replace(/\b\w/g, (m) => m.toUpperCase());
}

function labelForInput(input) {
  return input.name || input.id || "input";
}

function fieldForInput(input, index) {
  const name = labelForInput(input);
  return name === "input" && index === 0 ? "file" : name;
}

function inputDescription(input) {
  const required = input.required === false ? "optional" : "required";
  const formats = Array.isArray(input.formats) ? ` · ${input.formats.join("/")}` : "";
  return `${input.type || "file"} · ${required}${formats}${input.description ? ` · ${input.description}` : ""}`;
}

function pluginText(plugin) {
  return `${plugin.name} ${plugin.id} ${plugin.category} ${plugin.subcategory} ${plugin.description}`.toLowerCase();
}

function renderPluginTree() {
  if (!$("pluginTree")) return;
  const query = $("pluginSearch").value.trim().toLowerCase();
  const tree = $("pluginTree");
  tree.innerHTML = "";

  state.tree.forEach((category) => {
    if (state.category !== "All plots" && category.name !== state.category) return;
    const categoryMatches = category.name.toLowerCase().includes(query);
    const visibleSubs = (category.subcategories || [])
      .map((sub) => {
        const plugins = (sub.plugins || []).filter((plugin) => {
          return !query || categoryMatches || sub.name.toLowerCase().includes(query) || pluginText(plugin).includes(query);
        });
        return { ...sub, plugins };
      })
      .filter((sub) => sub.plugins.length);
    if (!visibleSubs.length) return;

    const details = document.createElement("details");
    details.className = "tree-category";
    details.open = true;
    details.innerHTML = `<summary>${escapeHtml(category.name)}</summary>`;

    visibleSubs.forEach((sub) => {
      const subDetails = document.createElement("details");
      subDetails.className = "tree-subcategory";
      subDetails.open = true;
      subDetails.innerHTML = `<summary>${escapeHtml(sub.name)}</summary>`;
      sub.plugins.forEach((plugin) => {
        const button = document.createElement("button");
        button.className = `plugin-item ${state.selected === plugin.id ? "active" : ""}`;
        button.innerHTML = `
          <strong>${escapeHtml(plugin.name)}</strong>
          <span>${escapeHtml(plugin.id)}</span>
        `;
        button.onclick = () => selectPlugin(plugin.id);
        subDetails.appendChild(button);
      });
      details.appendChild(subDetails);
    });
    tree.appendChild(details);
  });
}

function renderCategoryChips() {
  const box = $("categoryChips");
  if (!box) return;
  const names = ["All plots", ...new Set(state.plugins.map((plugin) => plugin.category).filter(Boolean))];
  box.innerHTML = "";
  names.forEach((name) => {
    const chip = document.createElement("button");
    chip.className = `category-chip ${state.category === name ? "active" : ""}`;
    chip.textContent = name;
    chip.onclick = () => { state.category = name; renderCategoryChips(); renderPluginTree(); renderPlotCards(); };
    box.appendChild(chip);
  });
}

function setMode(mode) {
  state.mode = mode;
  document.querySelectorAll(".nav-item").forEach((button) => {
    button.classList.toggle("active", button.dataset.mode === mode);
  });
  document.querySelectorAll(".top-link[data-mode]").forEach((button) => {
    button.classList.toggle("active", button.dataset.mode === mode);
  });
  const panels = {
    workspace: "workspaceHome",
    dataMap: "dataMapPanel",
    dataUpload: "dataUploadPanel",
    plotLibrary: "plotLibraryPanel",
    aiStudio: "aiStudioPanel",
    results: "resultsPanel",
    reports: "reportsPanel",
    module: "modulePanel",
  };
  Object.entries(panels).forEach(([key, id]) => {
    const panel = $(id);
    if (panel) panel.classList.toggle("hidden", key !== mode);
  });
  if (mode === "dataMap") refreshState();
  if (mode === "dataUpload") refreshDatasets();
  if (mode === "results") refreshResults();
  if (mode === "reports") refreshReports();
  if (mode === "plotLibrary") renderPlotCards();
  if (mode === "aiStudio") refreshAiStatus();
}

function renderHome() {
  const quick = $("quickStartList");
  if (!quick) return;
  quick.innerHTML = "";
  state.plugins.slice(0, 6).forEach((plugin) => {
    const item = document.createElement("button");
    item.className = "quick-item";
    item.innerHTML = `<strong>${escapeHtml(plugin.name)}</strong><small>${escapeHtml(plugin.category)} / ${escapeHtml(plugin.subcategory)}</small>`;
    item.onclick = () => selectPlugin(plugin.id);
    quick.appendChild(item);
  });
  renderHomeRecent();
}

function renderHomeRecent() {
  const box = $("homeRecentResults");
  if (!box) return;
  const recent = (state.results || []).slice(0, 6);
  box.innerHTML = recent.length ? "" : "No recent results yet.";
  recent.forEach((job) => {
    const div = document.createElement("button");
    div.className = "compact-item";
    div.innerHTML = `<strong>${escapeHtml(job.plugin_id)}</strong><small>${escapeHtml(job.status)} · ${escapeHtml(job.job_id)}</small>`;
    div.onclick = () => openResult(job);
    box.appendChild(div);
  });
}

function renderPlotCards() {
  const box = $("plotCards");
  if (!box) return;
  box.innerHTML = "";
  const query = $("pluginSearch").value.trim().toLowerCase();
  const visible = state.plugins.filter((plugin) => (state.category === "All plots" || plugin.category === state.category) && (!query || pluginText(plugin).includes(query)));
  $("toolCount").textContent = `${visible.length} plots`;
  const countBadge = $("sidebarPlotCount");
  if (countBadge) countBadge.textContent = visible.length;

  if (!visible.length) {
    box.innerHTML = `<div class="empty card"><strong>No plots found</strong><p>Try another search query or category.</p></div>`;
    return;
  }
  visible.forEach((plugin) => {
    const card = document.createElement("article");
    card.className = "plot-card";
    card.innerHTML = `
      <div class="plot-thumb">
        ${plugin.preview ? `<img src="${escapeHtml(plugin.preview)}" alt="${escapeHtml(plugin.name)} preview" />` : `<span>${escapeHtml(plugin.name.slice(0, 1))}</span>`}
      </div>
      <div class="plot-body">
        <strong>${escapeHtml(plugin.name)}</strong>
        <span class="plot-cat-tag">${escapeHtml(plugin.category || "General")} · ${escapeHtml(plugin.subcategory || "Visualization")}</span>
        <p>${escapeHtml(plugin.description || "")}</p>
      </div>
      <div class="plot-actions">
        <button class="primaryBtn primary">🛠️ Open Editor</button>
        <button class="secondaryBtn secondary">⚡ Try Demo</button>
      </div>
    `;
    card.onclick = () => selectPlugin(plugin.id);
    card.querySelector(".primaryBtn").onclick = (event) => { event.stopPropagation(); selectPlugin(plugin.id); };
    card.querySelector(".secondaryBtn").onclick = async (event) => { event.stopPropagation(); await selectPlugin(plugin.id); await runDemo(); };
    box.appendChild(card);
  });
}

function renderDataMap() {
  const canvas = $("dataMapCanvas");
  const hint = $("dataMapHint");
  if (!canvas && !hint) return;
  const stateData = state.serverState || { data_map: { nodes: [], edges: [] } };
  const nodes = stateData.data_map?.nodes || [];
  const edges = stateData.data_map?.edges || [];
  if (hint) hint.textContent = `${nodes.length} nodes · ${edges.length} edges`;
  if (!canvas) return;
  canvas.innerHTML = "";
  if (!nodes.length) {
    canvas.innerHTML = `<div class="empty">No provenance yet. Run a demo or upload a dataset.</div>`;
    return;
  }
  nodes.forEach((node) => {
    const div = document.createElement("button");
    div.className = `map-node ${node.type || "node"}`;
    div.innerHTML = `<strong>${escapeHtml(node.label || node.id)}</strong><small>${escapeHtml(node.type || "node")}</small>`;
    div.onclick = () => {
      if (node.type === "result" && node.job_id) {
        const job = state.results.find((item) => item.job_id === node.job_id);
        if (job) openResult(job);
      }
    };
    canvas.appendChild(div);
  });
}

async function refreshState() {
  state.serverState = await api("/api/state");
  renderDataMap();
  const active = state.serverState.active_dataset_id || "No active dataset loaded.";
  if ($("activeDatasetSummary")) $("activeDatasetSummary").textContent = active;
}

async function refreshDatasets() {
  const data = await api("/api/datasets");
  state.datasets = data.datasets || [];
  const box = $("datasetList");
  if (!state.datasets.length) {
    box.innerHTML = `<div class="empty">No datasets uploaded yet.</div>`;
    return;
  }
  box.innerHTML = `<table><thead><tr><th>Name</th><th>ID</th><th>Roles</th><th>Created</th></tr></thead><tbody>${state.datasets.map((d) => `<tr><td>${escapeHtml(d.name)}</td><td>${escapeHtml(d.dataset_id)}</td><td>${escapeHtml(Object.keys(d.roles || {}).join(", "))}</td><td>${escapeHtml(d.created_at || "")}</td></tr>`).join("")}</tbody></table>`;
}

async function uploadDataset() {
  const file = $("datasetFile").files?.[0];
  if (!file) {
    $("statusText").textContent = "Choose a dataset file first.";
    return;
  }
  const form = new FormData();
  form.append("dataset_name", $("datasetName").value || file.name);
  form.append("role", $("datasetRole").value);
  form.append("notes", $("datasetNotes").value || "");
  form.append("file", file);
  $("statusText").textContent = "Uploading dataset...";
  const dataset = await api("/api/datasets/upload", { method: "POST", body: form });
  $("statusText").textContent = `Dataset uploaded: ${dataset.name}`;
  await refreshDatasets();
  await refreshState();
}

async function refreshResults() {
  const data = await api("/api/results");
  state.results = data.results || [];
  renderHomeRecent();
  const box = $("resultsTable");
  if (!box) return;
  if (!state.results.length) {
    box.innerHTML = `<div class="empty">No runs yet.</div>`;
    return;
  }
  box.innerHTML = `<table><thead><tr><th>Run ID</th><th>Plot</th><th>Status</th><th>Created</th><th>Actions</th></tr></thead><tbody>${state.results.slice(0, 80).map((job) => `<tr><td>${escapeHtml(job.job_id)}</td><td>${escapeHtml(job.plugin_id)}</td><td>${escapeHtml(job.status)}</td><td>${escapeHtml(job.created_at || "")}</td><td><button data-job="${escapeHtml(job.job_id)}" class="table-action">Open</button></td></tr>`).join("")}</tbody></table>`;
  box.querySelectorAll("button[data-job]").forEach((button) => {
    button.onclick = () => {
      const job = state.results.find((item) => item.job_id === button.dataset.job);
      if (job) openResult(job);
    };
  });
}

function openResult(job) {
  setMode("module");
  $("pluginName").textContent = job.plugin_id || "Result";
  $("pluginDescription").textContent = job.job_id || "";
  $("jobStatus").textContent = `${job.status}: ${job.message || ""}`;
  $("outputPathText").textContent = job.output_dir || "";
  renderDownloads(job.outputs || {});
  if (job.outputs?.preview) {
    updateInstantPreview(job.outputs);
  }
}

async function refreshReports() {
  const data = await api("/api/reports");
  state.reports = data.reports || [];
  const box = $("reportsList");
  if (!state.reports.length) {
    box.innerHTML = "No reports generated yet.";
    return;
  }
  box.innerHTML = "";
  state.reports.forEach((report) => {
    const a = document.createElement("a");
    a.className = "compact-item";
    a.href = `/api/reports/${report.report_id}/download`;
    a.target = "_blank";
    a.innerHTML = `<strong>${escapeHtml(report.filename)}</strong><small>${escapeHtml(report.created_at)}</small>`;
    box.appendChild(a);
  });
}

async function createReport() {
  $("statusText").textContent = "Creating markdown report...";
  const report = await api("/api/reports/create", { method: "POST", body: JSON.stringify({ job_ids: state.results.slice(0, 5).map((job) => job.job_id) }), headers: { "Content-Type": "application/json" } });
  $("statusText").textContent = `Report created: ${report.report_id}`;
  await refreshReports();
}

function getPrimaryPreview() {
  if (!state.inputPreview?.files) return null;
  return state.inputPreview.files.file || state.inputPreview.files.input || Object.values(state.inputPreview.files)[0];
}

function columnOptions() {
  const preview = getPrimaryPreview();
  return preview?.columns || [];
}

function numericColumnOptions() {
  const preview = getPrimaryPreview();
  return preview?.numeric_columns?.length ? preview.numeric_columns : columnOptions().slice(1);
}

function inferType(key, raw) {
  if (raw && typeof raw === "object" && !Array.isArray(raw) && raw.type) return raw.type;
  const name = key.toLowerCase();
  // Column selectors first — never treat as boolean (cluster_column, log2fc_column, …)
  if (name.endsWith("_column") || ["x_column", "y_column", "label_column", "group_column", "term_col", "nes_col", "fdr_col", "pvalue_col"].includes(name)) return "column";
  if (name.endsWith("_columns") || name.includes("features") || name.includes("groups_include") || name.includes("columns_include") || name.includes("value_columns")) return "columns";
  if (
    name.startsWith("show_") ||
    name.startsWith("add_") ||
    name.startsWith("use_") ||
    name.endsWith("_show") ||
    name.includes("border") ||
    name.includes("merge") ||
    name.includes("raster") ||
    name.includes("transpose")
  ) return "boolean";
  if (name.includes("font_family") || name.includes("font") || name.includes("family")) return "font";
  if (name.includes("face") || name.includes("bold")) return "font_face";
  if (name.includes("color") && !name.includes("colors")) return "color";
  if (name.includes("palette") || name.includes("colors")) return "palette";
  if (name.includes("rules") || name.includes("settings")) return "textarea";
  if (name.includes("size") || name.includes("width") || name.includes("height") || name.includes("dpi") || name.includes("angle") || name.includes("alpha") || name.includes("threshold") || name.includes("cutoff") || name.includes("limit") || name.includes("top_n")) return "number";
  if (name.includes("include") || name.includes("exclude") || name.includes("selected") || name.includes("order")) return "string_array";
  if (name.includes("type") || name.includes("mode") || name.includes("method") || name.includes("position") || name.includes("shape") || name.includes("orientation") || name.includes("style") || name.includes("side")) return "select";
  return "string";
}

function controlGroup(control) {
  const name = control.key.toLowerCase();
  if (name.includes("selected") || name.includes("highlight") || name.includes("include") || name.includes("exclude")) return "Selected / Highlight";
  if (name.includes("title") || name.includes("font") || name.includes("label") || name.includes("text") || name.includes("name")) return "Text & Typography";
  if (name.startsWith("x") || name.startsWith("y") || name.includes("axis") || name.includes("lim") || name.includes("grid")) return "X/Y Axes";
  if (name.includes("legend")) return "Legend";
  if (name.includes("color") || name.includes("palette")) return "Graphic Color & Palettes";
  if (name.includes("size") || name.includes("shape") || name.includes("width") || name.includes("height") || name.includes("alpha") || name.includes("dot") || name.includes("point") || name.includes("cell")) return "Graphic Parameters";
  if (control.type === "column" || control.type === "columns" || name.includes("group") || name.includes("feature") || name.includes("row")) return "Data Selection";
  return labelize(control.section || "Basic Settings");
}

function controlTier(control) {
  const name = control.key.toLowerCase();
  const section = String(control.section || "").toLowerCase();
  // Section-aware defaults first (matches control-panel sections)
  if (section.includes("legend")) return "graphic";
  if (section.includes("axis") || section.includes("title") || section.includes("label") || section === "labels") return "typography";
  if (section.includes("export") || section.includes("theme_export") || section.includes("output") || section.includes("canvas")) return "export";
  if (section.includes("color") || section.includes("style") || section.includes("point") || section.includes("mark")) return "graphic";

  if (name.includes("title") || name.includes("font") || name.includes("label") || name.includes("text") || name.startsWith("x") || name.startsWith("y") || name.includes("axis") || name.includes("angle") || name.includes("grid") || name.includes("xlab") || name.includes("ylab")) {
    return "typography";
  }
  if (name.includes("width") || name.includes("height") || name.includes("dpi") || name.includes("res") || name.includes("unit") || name.includes("format") || name.includes("margin")) {
    return "export";
  }
  if (name.includes("legend") || name.includes("color") || name.includes("palette") || name.includes("size") || name.includes("shape") || name.includes("alpha") || name.includes("dot") || name.includes("point") || name.includes("cell") || name.includes("border") || name.includes("stroke") || name.includes("fill")) {
    return "graphic";
  }
  return "basic";
}

function inferOptions(key, raw) {
  if (raw && typeof raw === "object" && Array.isArray(raw.options)) return raw.options;
  const name = key.toLowerCase();
  const map = {
    analysis_type: ["pearson", "spearman", "kendall", "jaccard", "cosine", "raw_value"],
    input_mode: ["auto", "single_matrix", "two_matrix", "precomputed", "compute"],
    plot_type: ["heatmap", "dotplot", "violin", "clustered_dotplot", "summary", "running", "combined"],
    cell_shape: ["tile", "circle", "diamond", "triangle"],
    quadrant_mode: ["nine", "four", "custom"],
    running_curve_style: ["classic", "gradient_curve"],
    legend_position: ["right", "left", "top", "bottom", "none"],
    orientation: ["vertical", "horizontal", "horizontal_blocks"],
    summary: ["mean", "zscore", "log1p"],
  };
  if (map[name]) return map[name];
  if (name.includes("side")) return ["left", "right", "top", "bottom"];
  if (name.includes("method")) return ["pearson", "spearman", "kendall"];
  if (name.includes("shape")) return ["tile", "circle", "point", "diamond", "triangle"];
  if (name.includes("position")) return ["right", "left", "top", "bottom", "none"];
  return [];
}

function defaultValue(key, spec) {
  // Only explicit schema defaults — inferred false/[] used to poison demo runs
  if (spec && typeof spec === "object" && Object.prototype.hasOwnProperty.call(spec, "default")) return spec.default;
  return undefined;
}

function sanitizeParamsForRun(params = {}) {
  const out = {};
  Object.entries(params || {}).forEach(([key, value]) => {
    if (value === undefined || value === null || value === "") return;
    const k = key.toLowerCase();
    if (Array.isArray(value) && value.length === 0) {
      if (/(include|exclude|highlight|selected|rows_|columns_|groups_|features|markers|genes)/.test(k)) return;
      return;
    }
    if (
      value === false &&
      (k.endsWith("_column") || k.endsWith("_columns") || k.endsWith("_col") || k.includes("column") || k === "markers" || k.endsWith("_field") || k.endsWith("_order"))
    ) {
      return;
    }
    out[key] = value;
  });
  return out;
}

function parseLooseTypeSpec(raw, key) {
  if (raw && typeof raw === "object" && !Array.isArray(raw)) {
    return {
      ...raw,
      options: raw.options || raw.enum || undefined,
      help: raw.help || raw.description || "",
    };
  }
  const text = String(raw || "");
  const selectMatch = text.match(/^select\((.*)\)$/i);
  if (selectMatch) {
    const options = selectMatch[1].split(",").map((s) => s.trim()).filter(Boolean);
    return { type: "select", options, help: labelize(key) };
  }
  const typeMap = {
    column: "column",
    columns: "columns",
    string: "string",
    number: "number",
    integer: "integer",
    boolean: "boolean",
    color: "color",
    object: "object",
    array: "string_array",
    json: "json",
    textarea: "textarea",
  };
  const t = typeMap[text.toLowerCase()];
  if (t) return { type: t, help: labelize(key) };
  return { help: text || labelize(key) };
}

function expandSchemaSource(schema) {
  const source = schema || {};
  // Interactive plugins:
  //  A) { groups: { data: [keys...], ... }, properties: { key: {type...} } }
  //  B) { groups: { data: { key: "column"| "select(a,b)" | {...} } } }
  if (source.groups && typeof source.groups === "object" && !Array.isArray(source.groups)) {
    const props = source.properties && typeof source.properties === "object" ? source.properties : {};
    const expanded = {};
    Object.entries(source.groups).forEach(([sectionName, keys]) => {
      expanded[sectionName] = {};
      if (Array.isArray(keys)) {
        keys.forEach((key) => {
          const prop = props[key];
          expanded[sectionName][key] = parseLooseTypeSpec(prop || key, key);
        });
      } else if (keys && typeof keys === "object") {
        Object.entries(keys).forEach(([key, raw]) => {
          const prop = props[key] !== undefined ? props[key] : raw;
          expanded[sectionName][key] = parseLooseTypeSpec(prop, key);
        });
      }
    });
    if (Object.keys(expanded).length) return expanded;
  }
  // Nested JSON-Schema style used by binary plot:
  // { type:"object", properties:{ data:{ type:"object", properties:{...} }, axes:{...} } }
  if (source.properties && typeof source.properties === "object") {
    const values = Object.values(source.properties);
    const nested = values.some((v) => v && typeof v === "object" && v.properties && typeof v.properties === "object");
    if (nested) {
      const expanded = {};
      Object.entries(source.properties).forEach(([sectionName, def]) => {
        if (def && typeof def === "object" && def.properties) {
          expanded[sectionName] = def.properties;
        } else {
          expanded[sectionName] = { [sectionName]: def };
        }
      });
      return expanded;
    }
    if (source.type === "object" || source.$schema) {
      return { Parameters: source.properties };
    }
  }
  // Already sectioned (data/axes/legend/...) or config.parameters flat map
  return source;
}

function normalizeSchema(schema) {
  const source = expandSchemaSource(schema);
  const sections = [];
  Object.entries(source).forEach(([sectionName, entries]) => {
    if (!entries || typeof entries !== "object" || Array.isArray(entries)) return;
    // Skip leftover metadata keys from mixed formats
    if (["plugin", "title", "type", "$schema", "groups", "properties"].includes(sectionName) && !Object.values(entries).some((v) => v && typeof v === "object")) {
      return;
    }
    const controls = Object.entries(entries).map(([key, raw], index) => {
      const spec = raw && typeof raw === "object" && !Array.isArray(raw) ? raw : { help: String(raw || "") };
      return {
        key,
        section: sectionName,
        type: inferType(key, spec),
        label: spec.label || labelize(key),
        help: spec.help || spec.description || (typeof raw === "string" ? raw : ""),
        required: Boolean(spec.required),
        default: defaultValue(key, spec),
        options: inferOptions(key, spec),
        group: spec.ui?.group || controlGroup({ key, section: sectionName, type: inferType(key, spec) }),
        tier: spec.ui?.tier || controlTier({ key, section: sectionName, type: inferType(key, spec) }),
        order: spec.ui?.order ?? index,
      };
    });
    if (!controls.length) return;
    sections.push({ name: sectionName, controls: controls.sort((a, b) => a.order - b.order) });
  });
  return sections;
}

function applyDefaults() {
  state.params = {};
  state.schemaSections.forEach((section) => {
    section.controls.forEach((control) => {
      const d = control.default;
      if (d === undefined || d === null || d === "") return;
      if (Array.isArray(d) && d.length === 0) return;
      const k = control.key.toLowerCase();
      if (/(^|_)(include|exclude|highlight|selected)(_|$)/.test(k)) return;
      state.params[control.key] = d;
    });
  });
  syncJsonFromParams();
}

function syncJsonFromParams() {
  $("paramsText").value = prettify(state.params);
}

function mergeParams(params) {
  state.params = { ...state.params, ...(params || {}) };
  syncJsonFromParams();
}

function parseArrayInput(value, numeric = false) {
  return String(value || "")
    .split(/[,;\n]/)
    .map((item) => item.trim())
    .filter(Boolean)
    .map((item) => (numeric ? Number(item) : item))
    .filter((item) => !numeric || Number.isFinite(item));
}

function controlValueFromDom(control, element) {
  if (control.type === "boolean") return element.checked;
  if (control.type === "number" || control.type === "integer") return element.value === "" ? "" : Number(element.value);
  if (control.type === "columns" || control.type === "multi_select") {
    return Array.from(element.selectedOptions).map((option) => option.value);
  }
  if (control.type === "string_array") return parseArrayInput(element.value);
  if (control.type === "number_array") return parseArrayInput(element.value, true);
  if (control.type === "object" || control.type === "json") {
    try {
      return element.value.trim() ? JSON.parse(element.value) : {};
    } catch {
      return element.value;
    }
  }
  return element.value;
}

function domValueForControl(control) {
  const value = state.params[control.key] ?? control.default;
  if (Array.isArray(value)) return value.join(", ");
  if (value && typeof value === "object") return prettify(value);
  return value ?? "";
}

function updateParam(control, element, delay = 350) {
  state.params[control.key] = controlValueFromDom(control, element);
  syncJsonFromParams();
  triggerAutoUpdate(delay);
}

function renderInputForControl(control) {
  const id = `param_${control.key}`;
  const value = domValueForControl(control);
  const columns = columnOptions();
  const numeric = numericColumnOptions();
  const rows = rowLabels();
  let element;

  if (control.type === "boolean") {
    const wrapper = document.createElement("span");
    wrapper.className = "switch";
    element = document.createElement("input");
    element.type = "checkbox";
    element.checked = Boolean(state.params[control.key] ?? control.default);
    wrapper.appendChild(element);
    wrapper.appendChild(document.createElement("i"));
    element.addEventListener("change", () => updateParam(control, element, 50));
    return wrapper;
  } else if (control.type === "select") {
    element = document.createElement("select");
    const opts = control.options.length ? control.options : ["", "yes", "no"];
    opts.forEach((opt) => element.add(new Option(opt || "Default", opt)));
    element.value = value;
    element.addEventListener("change", () => updateParam(control, element, 50));
  } else if (control.type === "column") {
    element = document.createElement("select");
    element.add(new Option("Auto", ""));
    columns.forEach((col) => element.add(new Option(col, col)));
    element.value = columns.includes(value) ? value : "";
    element.addEventListener("change", () => updateParam(control, element, 50));
  } else if (control.type === "columns" || control.type === "multi_select") {
    return renderPickerControl(control, columns.length ? columns : numeric, "Click columns to include");
  } else if (control.type === "color") {
    return renderColorControl(control, value);
  } else if (control.type === "palette") {
    return renderPaletteControl(control, value);
  } else if (control.type === "font") {
    element = document.createElement("select");
    ["Arial", "Helvetica", "Times New Roman", "Georgia", "Courier New", "Verdana"].forEach((font) => element.add(new Option(font, font)));
    element.value = value || "Arial";
    element.addEventListener("change", () => updateParam(control, element, 50));
  } else if (control.type === "font_face") {
    return renderFontFaceControl(control, value);
  } else if (control.type === "number" || control.type === "integer") {
    return renderNumberControl(control, value);
  } else if (["textarea", "object", "json", "string_array", "number_array"].includes(control.type)) {
    if (control.type === "string_array" && (control.key.toLowerCase().includes("row") || control.key.toLowerCase().includes("selected") || control.key.toLowerCase().includes("highlight"))) {
      return renderPickerControl(control, rows.length ? rows : columns, "Click rows/items to select");
    }
    element = document.createElement("textarea");
    element.rows = control.type === "textarea" ? 3 : 2;
    element.value = value;
    element.addEventListener("input", () => updateParam(control, element, 400));
  } else {
    element = document.createElement("input");
    element.type = "text";
    element.value = value;
    element.addEventListener("input", () => updateParam(control, element, 400));
  }

  element.id = id;
  element.dataset.param = control.key;
  return element;
}

function renderNumberControl(control, value) {
  const wrapper = document.createElement("div");
  wrapper.className = "slider-row number-control";
  const range = document.createElement("input");
  range.type = "range";
  const lower = control.key.toLowerCase();
  const isAngle = lower.includes("angle");
  const isAlpha = lower.includes("alpha") || lower.includes("opacity");
  const isSize = lower.includes("size") || lower.includes("width") || lower.includes("height") || lower.includes("dpi");
  range.min = isAlpha ? "0" : isAngle ? "0" : "0";
  range.max = isAlpha ? "1" : isAngle ? "180" : isSize ? "600" : "100";
  range.step = control.type === "integer" ? "1" : isAlpha ? "0.01" : "0.5";
  const numericValue = Number(value);
  range.value = Number.isFinite(numericValue) ? String(numericValue) : (isAlpha ? "1" : "12");
  // Ensure range can show current value if outside defaults
  if (Number.isFinite(numericValue)) {
    if (numericValue > Number(range.max)) range.max = String(Math.ceil(numericValue));
    if (numericValue < Number(range.min)) range.min = String(Math.floor(numericValue));
  }
  const input = document.createElement("input");
  input.type = "number";
  input.step = range.step;
  input.value = range.value;
  input.title = isAngle ? "degrees" : "";
  const update = (source) => {
    const v = source.value;
    range.value = v;
    input.value = v;
    state.params[control.key] = Number(v);
    syncJsonFromParams();
    triggerAutoUpdate(250);
  };
  range.oninput = () => update(range);
  input.oninput = () => update(input);
  wrapper.appendChild(range);
  wrapper.appendChild(input);
  return wrapper;
}

function renderColorControl(control, value) {
  const wrapper = document.createElement("div");
  wrapper.className = "color-control";
  const picker = document.createElement("input");
  picker.type = "color";
  picker.value = /^#[0-9a-f]{6}$/i.test(value) ? value : "#3b82f6";
  const text = document.createElement("input");
  text.type = "text";
  text.value = picker.value;
  const update = (v) => {
    picker.value = /^#[0-9a-f]{6}$/i.test(v) ? v : picker.value;
    text.value = v;
    state.params[control.key] = v;
    syncJsonFromParams();
    triggerAutoUpdate(100);
  };
  picker.oninput = () => update(picker.value);
  text.oninput = () => update(text.value);
  wrapper.appendChild(picker);
  wrapper.appendChild(text);
  return wrapper;
}

function renderFontFaceControl(control, value) {
  const wrapper = document.createElement("div");
  wrapper.className = "font-face-control";
  const select = document.createElement("select");
  ["plain", "bold", "italic", "bold.italic"].forEach((face) => select.add(new Option(face, face)));
  select.value = value || "plain";
  const bold = document.createElement("button");
  bold.type = "button";
  bold.textContent = "B";
  bold.className = select.value.includes("bold") ? "active" : "";
  select.onchange = () => {
    state.params[control.key] = select.value;
    bold.classList.toggle("active", select.value.includes("bold"));
    syncJsonFromParams();
    triggerAutoUpdate(50);
  };
  bold.onclick = () => {
    select.value = select.value.includes("bold") ? "plain" : "bold";
    select.onchange();
  };
  wrapper.appendChild(select);
  wrapper.appendChild(bold);
  return wrapper;
}

function renderPaletteControl(control, value) {
  const wrapper = document.createElement("div");
  wrapper.className = "palette-control";

  const paletteGrid = document.createElement("div");
  paletteGrid.className = "scientific-palettes";

  const currentValStr = JSON.stringify(state.params[control.key] || []);

  SCIENTIFIC_PALETTES.forEach((p) => {
    const btn = document.createElement("button");
    btn.type = "button";
    btn.className = `scientific-palette-btn ${currentValStr === JSON.stringify(p.colors) ? "active" : ""}`;
    btn.innerHTML = `
      <span class="palette-label">${escapeHtml(p.name)}</span>
      <div class="palette-preview-bar" style="background: linear-gradient(90deg, ${escapeHtml(p.colors.join(","))})"></div>
    `;
    btn.onclick = () => {
      state.params[control.key] = p.colors;
      syncJsonFromParams();
      renderActiveControls();
      triggerAutoUpdate(50);
    };
    paletteGrid.appendChild(btn);
  });
  wrapper.appendChild(paletteGrid);

  const custom = document.createElement("textarea");
  custom.rows = 2;
  custom.placeholder = "Custom hex colors: #3B82F6,#FFFFFF,#EF4444";
  custom.value = Array.isArray(value) ? value.join(",") : (typeof value === "string" ? value : "");
  custom.oninput = () => {
    state.params[control.key] = parseArrayInput(custom.value);
    syncJsonFromParams();
    triggerAutoUpdate(350);
  };
  wrapper.appendChild(custom);
  return wrapper;
}

function renderPickerControl(control, options, placeholder) {
  const wrapper = document.createElement("div");
  wrapper.className = "picker-control";
  const search = document.createElement("input");
  search.type = "text";
  search.placeholder = placeholder;
  const chips = document.createElement("div");
  chips.className = "picker-chips";
  const selected = new Set(Array.isArray(state.params[control.key]) ? state.params[control.key] : []);
  const draw = () => {
    const q = search.value.toLowerCase();
    chips.innerHTML = "";
    options.filter((opt) => !q || String(opt).toLowerCase().includes(q)).slice(0, 80).forEach((opt) => {
      const chip = document.createElement("button");
      chip.type = "button";
      chip.className = selected.has(opt) ? "chip selected" : "chip";
      chip.textContent = opt;
      chip.onclick = () => {
        if (selected.has(opt)) selected.delete(opt);
        else selected.add(opt);
        state.params[control.key] = Array.from(selected);
        syncJsonFromParams();
        draw();
        triggerAutoUpdate(100);
      };
      chips.appendChild(chip);
    });
  };
  search.oninput = draw;
  wrapper.appendChild(search);
  wrapper.appendChild(chips);
  draw();
  return wrapper;
}

function setupControlTabEvents() {
  const tabs = document.querySelectorAll("#controlTabs .tab");
  tabs.forEach((tab) => {
    tab.onclick = () => {
      tabs.forEach((t) => t.classList.remove("active"));
      tab.classList.add("active");
      const section = tab.dataset.section;
      state.activeSection = section;

      document.querySelectorAll(".tab-content").forEach((content) => {
        if (content.dataset.tab === section) {
          content.classList.add("active");
        } else if (section !== "data" && section !== "export" && content.id === "controlPanelSection") {
          content.classList.add("active");
        } else {
          content.classList.remove("active");
        }
      });
      renderActiveControls();
    };
  });
}

function renderActiveControls() {
  const panel = $("controlPanel");
  panel.innerHTML = "";

  if (state.activeSection === "data" || state.activeSection === "export") return;

  const controls = state.schemaSections.flatMap((item) => item.controls).filter((control) => (control.tier || "basic") === state.activeSection);
  if (!controls.length) {
    const total = state.schemaSections.reduce((n, s) => n + (s.controls?.length || 0), 0);
    if (!total) {
      panel.innerHTML = `<div class="empty">No parameter schema for this plot yet. Use <b>Advanced JSON</b>, or open a demo example.</div>`;
    } else {
      panel.innerHTML = `<div class="empty">No controls in this tab. Try <b>Basic Config</b>, <b>Color &amp; Aesthetics</b>, or <b>Labels &amp; Axes</b>.</div>`;
    }
    return;
  }
  const grouped = new Map();
  controls.forEach((control) => {
    const group = control.group || "Settings";
    if (!grouped.has(group)) grouped.set(group, []);
    grouped.get(group).push(control);
  });
  grouped.forEach((groupControls, groupName) => {
    const details = document.createElement("details");
    details.className = "control-group";
    details.open = true;
    details.innerHTML = `<summary>${escapeHtml(groupName)}</summary>`;
    groupControls.forEach((control) => {
      const row = document.createElement("label");
      row.className = `control-row control-${control.type}`;
      const required = control.required ? `<span class="required">*</span>` : "";
      const label = document.createElement("span");
      label.className = "control-label";
      label.innerHTML = `${escapeHtml(control.label)}${required}`;
      row.appendChild(label);
      row.appendChild(renderInputForControl(control));
      if (control.help) {
        const help = document.createElement("small");
        help.textContent = control.help;
        row.appendChild(help);
      }
      details.appendChild(row);
    });
    panel.appendChild(details);
  });
}

function renderSchema(schema) {
  state.schemaSections = normalizeSchema(schema);
  state.activeSection = "basic";
  applyDefaults();
  renderActiveControls();
}

function renderFileInputs(detail) {
  const box = $("fileInputs");
  box.innerHTML = "";
  const inputs = Array.isArray(detail.inputs) && detail.inputs.length
    ? detail.inputs
    : [{ name: "input", type: "table", required: true }];

  inputs.forEach((input, index) => {
    const name = labelForInput(input);
    const fieldName = fieldForInput(input, index);
    const row = document.createElement("div");
    row.className = "file-row";
    row.innerHTML = `
      <label for="file_${escapeHtml(fieldName)}">${escapeHtml(name)}${input.required === false ? "" : " *"}</label>
      <input id="file_${escapeHtml(fieldName)}" data-field="${escapeHtml(fieldName)}" type="file" accept=".csv,.tsv,.txt,.xlsx,.xlsm,application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" ${input.required === false ? "" : "required"} />
      <small>${inputDescription(input)} (CSV / TSV / XLSX)</small>
    `;
    box.appendChild(row);
  });
  $("inputHint").textContent = `${inputs.length} upload field${inputs.length > 1 ? "s" : ""}`;
  document.querySelectorAll("input[type=file][data-field]").forEach((input) => {
    input.onchange = () => {
      $("previewInputButton").disabled = !hasAnyFile();
    };
  });
}

function hasAnyFile() {
  return Array.from(document.querySelectorAll("input[type=file][data-field]")).some((input) => input.files?.length);
}

function collectFileFormData() {
  const form = new FormData();
  document.querySelectorAll("input[type=file][data-field]").forEach((input) => {
    if (input.files && input.files[0]) {
      form.append(input.dataset.field, input.files[0]);
    }
  });
  return form;
}

function exampleLabel(example, index) {
  return example?.label || example?.name || example?.plot_type || example?.mode || `Example ${index + 1}`;
}

function exampleType(example) {
  return example?.plot_type || example?.mode || "Default mode";
}

function exampleImageUrl(image) {
  if (!image) return "";
  if (/^(https?:|data:|blob:|\/)/i.test(image)) return image;
  const filename = String(image).split("/").pop();
  return state.selected ? `/api/plugins/${encodeURIComponent(state.selected)}/gallery/${encodeURIComponent(filename)}` : image;
}

function selectedExampleRecord() {
  return state.selectedExample || null;
}

function exampleBundle(example = selectedExampleRecord()) {
  return example?.bundle && typeof example.bundle === "object" ? example.bundle : {};
}

function exampleInputPreview(example = selectedExampleRecord()) {
  const bundle = exampleBundle(example);
  const inputs = bundle.inputs || bundle.input_preview || bundle.inputPreview || example?.inputs;
  if (!inputs) return null;
  if (inputs.files && typeof inputs.files === "object") return { files: inputs.files };
  if (typeof inputs === "object" && !Array.isArray(inputs)) return { files: inputs };
  if (!Array.isArray(inputs)) return null;
  return { files: Object.fromEntries(inputs.map((item, index) => [item.name || item.field || `input${index + 1}`, item.preview || item])) };
}

function exampleJsonUrl(example = selectedExampleRecord()) {
  if (!example) return "";
  const bundle = exampleBundle(example);
  return bundle.params_url || bundle.paramsUrl || bundle.manifest_url || bundle.manifestUrl || bundle.download_url || bundle.downloadUrl || example.params_url || example.manifest_url || "";
}

function renderExampleJsonAction() {
  const button = $("downloadExampleButton");
  if (!button) return;
  const example = selectedExampleRecord();
  const url = exampleJsonUrl(example);
  button.disabled = !example || (!url && !example.params);
  button.textContent = url ? "↓ Load JSON" : "↓ Download JSON";
  button.onclick = () => {
    if (!example) return;
    if (url) {
      const link = document.createElement("a");
      link.href = url;
      link.download = `${example.id || "example"}-params.json`;
      link.target = "_blank";
      link.click();
      return;
    }
    const link = document.createElement("a");
    link.href = URL.createObjectURL(new Blob([prettify(example.params || {})], { type: "application/json" }));
    link.download = `${example.id || "example"}-params.json`;
    link.click();
    URL.revokeObjectURL(link.href);
  };
}

function selectExample(index, { updateControls = true } = {}) {
  const example = state.examples[index];
  if (!example) return;
  state.selectedExample = example;
  applyDefaults();
  mergeParams(example.params || {});
  const select = $("exampleSelect");
  if (select) select.value = String(example.id);
  renderExampleGallery();
  renderExampleJsonAction();
  if (updateControls) {
    loadDemoIntoUi();
    renderActiveControls();
    renderRowSelector();
    renderStageDataDrawer();
    triggerAutoUpdate(50);
  }
}

function exampleBlurb(example) {
  return example?.blurb || example?.description || example?.manifest?.blurb || "";
}

function exampleHowto(example) {
  return example?.howto || example?.manifest?.howto || "";
}

function exampleCardGroup(example) {
  const g = example?.card_group || example?.manifest?.card_group;
  if (g) return g;
  const id = String(example?.id || "");
  if (id.startsWith("pdf_repro_")) return "pdf_styles";
  return "more";
}

function appendExampleCard(grid, example, index) {
  const card = document.createElement("button");
  card.type = "button";
  const isSelected = state.selectedExample && String(state.selectedExample.id) === String(example.id);
  card.className = `example-card demo-frame ${isSelected ? "selected" : ""}`;
  card.setAttribute("aria-pressed", isSelected ? "true" : "false");
  const image = exampleImageUrl(example.image || example.expected);
  const cat = example.mode || example.plot_type || "demo";
  const blurb = exampleBlurb(example);
  const howto = exampleHowto(example);
  card.innerHTML = `
    <span class="demo-frame-chrome">
      <span class="demo-frame-dots" aria-hidden="true"><i></i><i></i><i></i></span>
      <span class="demo-frame-title"></span>
    </span>
    <span class="example-card-image">${image ? `<img src="${escapeHtml(image)}" alt="">` : `<span class="example-placeholder">📊</span>`}</span>
    <span class="example-card-copy">
      <span class="example-card-label"></span>
      <span class="example-card-blurb"></span>
      <span class="example-card-howto"></span>
      <span class="example-card-type"></span>
    </span>`;
  card.querySelector(".demo-frame-title").textContent = exampleLabel(example, index);
  card.querySelector(".example-card-label").textContent = exampleLabel(example, index);
  const blurbEl = card.querySelector(".example-card-blurb");
  const howtoEl = card.querySelector(".example-card-howto");
  if (blurb) blurbEl.textContent = blurb;
  else blurbEl.remove();
  if (howto) howtoEl.textContent = howto;
  else howtoEl.remove();
  card.querySelector(".example-card-type").textContent = `mode · ${cat}`;
  card.title = [blurb, howto].filter(Boolean).join("\n");
  card.onclick = () => selectExample(index);
  grid.appendChild(card);
}

function renderExampleGallery() {
  const gallery = $("exampleGallery");
  if (!gallery) return;
  gallery.innerHTML = "";
  if (!state.examples.length) return;

  const head = document.createElement("div");
  head.className = "example-gallery-head";
  head.innerHTML = `<strong>${escapeHtml(state.examples.length)} demo cards</strong><small>Each card = one default plot setting</small>`;
  gallery.appendChild(head);

  // How-to notice for switching plot types / styles
  const notice = document.createElement("div");
  notice.className = "demo-howto-notice";
  notice.innerHTML = `
    <strong>How to switch plot types</strong>
    <ol>
      <li><b>Click a demo card</b> below to load that style’s default parameters + matching input.</li>
      <li>Or open <b>Presets</b> (top-right) and pick another example.</li>
      <li>To customize further, change keys in <b>Mapping / Color &amp; Legend / Axes</b>:
        <code>plot_mode</code>, <code>group_column</code>, <code>show_mark</code>,
        <code>split_column</code>, <code>show_stat_embedded</code>,
        <code>highlight_rows</code>, <code>background_column</code> / <code>background_cutoff</code>.</li>
      <li>Click <b>Demo</b> or <b>Run Plot</b> to re-render after edits.</li>
    </ol>
    <p class="demo-howto-tip">Tip: for <b>Advanced Dimension Plot</b>, the first 7 cards are PDF-matched UMAP styles (basic → ellipse → split → rings → highlight → mito background → sample background). For <b>Advanced Feature Plot</b>, the first 7 cards are PDF-matched feature styles (basic genes → multi scaled → split → composite → highlight → shared-split → hexbin).</p>
  `;
  gallery.appendChild(notice);

  const styleIdx = [];
  const moreIdx = [];
  state.examples.forEach((example, index) => {
    if (exampleCardGroup(example) === "pdf_styles") styleIdx.push(index);
    else moreIdx.push(index);
  });

  if (styleIdx.length) {
    const section = document.createElement("div");
    section.className = "demo-card-section";
    section.innerHTML = `<div class="demo-card-section-title"><span>Style presets</span><small>${escapeHtml(styleIdx.length)} cards · click to compare defaults</small></div>`;
    const grid = document.createElement("div");
    grid.className = "example-gallery-grid demo-frame-grid demo-frame-grid-styles";
    styleIdx.forEach((index) => appendExampleCard(grid, state.examples[index], index));
    section.appendChild(grid);
    gallery.appendChild(section);
  }

  if (moreIdx.length) {
    const section = document.createElement("div");
    section.className = "demo-card-section";
    section.innerHTML = `<div class="demo-card-section-title"><span>More examples</span><small>${escapeHtml(moreIdx.length)} cards</small></div>`;
    const grid = document.createElement("div");
    grid.className = "example-gallery-grid demo-frame-grid";
    moreIdx.forEach((index) => appendExampleCard(grid, state.examples[index], index));
    section.appendChild(grid);
    gallery.appendChild(section);
  }

  if (state.selectedExample !== null) {
    const note = document.createElement("div");
    note.className = "example-selected-note";
    const selected = selectedExampleRecord();
    const howto = exampleHowto(selected);
    note.innerHTML = `<div><strong>Selected:</strong> ${escapeHtml(exampleLabel(selected, 0))} · ${escapeHtml(exampleType(selected))}</div>`;
    if (howto) {
      const h = document.createElement("div");
      h.className = "example-selected-howto";
      h.textContent = `Settings: ${howto}`;
      note.appendChild(h);
    }
    const action = document.createElement("span");
    action.className = "example-reproduce-label";
    action.textContent = "Run Demo to apply this card";
    note.appendChild(action);
    gallery.appendChild(note);
  }
  renderExampleJsonAction();
}

function renderExamples(detail) {
  const select = $("exampleSelect");
  state.examples = Array.isArray(detail.examples) && detail.examples.length
    ? detail.examples
    : (Array.isArray(detail.demo?.examples) ? detail.demo.examples : []);
  state.selectedExample = null;
  if (!select) return renderExampleGallery();
  select.innerHTML = "";
  select.add(new Option("Defaults", ""));
  state.examples.forEach((example, index) => select.add(new Option(exampleLabel(example, index), String(example.id))));
  select.onchange = () => {
    if (select.value === "") {
      state.selectedExample = null;
      applyDefaults();
      renderExampleGallery();
      renderActiveControls();
    } else {
      const index = state.examples.findIndex((example) => String(example.id) === String(select.value));
      if (index >= 0) selectExample(index);
    }
    triggerAutoUpdate(50);
  };
  renderExampleGallery();
  renderExampleJsonAction();
}

function renderInputSummary() {
  const summary = $("inputSummary");
  summary.innerHTML = "";
  if (!state.inputPreview?.files) return;
  Object.entries(state.inputPreview.files).forEach(([field, info]) => {
    const div = document.createElement("div");
    div.className = "input-file-summary";
    div.innerHTML = `<strong>${escapeHtml(field)}</strong><span>${escapeHtml(info.filename || "")}</span><small>${escapeHtml(info.row_count_estimate || 0)} rows · ${escapeHtml(info.column_count || 0)} columns · delimiter ${escapeHtml(info.delimiter || ",")}</small>`;
    summary.appendChild(div);
  });
}

function renderDemoGallery() {
  const gallery = $("demoGallery");
  gallery.innerHTML = "";
  const images = state.demo?.galleries || [];
  if (!images.length) return;
  const title = document.createElement("div");
  title.className = "selector-head";
  title.innerHTML = `<strong>Demo Gallery</strong><small>Previously generated example figures for this plot.</small>`;
  gallery.appendChild(title);
  const grid = document.createElement("div");
  grid.className = "gallery-grid";
  images.slice(0, 8).forEach((path) => {
    const img = document.createElement("img");
    const filename = path.split("/").pop();
    img.src = `/api/plugins/${state.selected}/gallery/${encodeURIComponent(filename)}`;
    img.alt = filename;
    grid.appendChild(img);
  });
  gallery.appendChild(grid);
}

function loadDemoIntoUi() {
  if (!state.demo && !selectedExampleRecord()) return;
  const selectedPreview = exampleInputPreview();
  const files = {};
  Object.entries(selectedPreview?.files || state.demo?.files || {}).forEach(([field, info]) => {
    if (info.preview) {
      files[field] = info.preview;
    }
  });
  state.inputPreview = { plugin_id: state.selected, files };
  state.selectedColumns = new Set();
  state.selectedRows = new Set();
  // Replace params entirely so schema defaults cannot poison the demo
  let params = {};
  const demoParams = state.demo?.params?.params || state.demo?.params || {};
  if (demoParams && typeof demoParams === "object") params = { ...demoParams };
  if (state.selectedExample !== null) {
    const ex = selectedExampleRecord()?.params || {};
    params = { ...params, ...ex };
  }
  delete params.rows_include;
  delete params.rows_exclude;
  state.params = params;
  syncJsonFromParams();
  renderInputSummary();
  renderColumnSelector();
  renderRowSelector();
  renderTablePreview();
  renderActiveControls();
  renderDemoGallery();
  renderExampleGallery();
  renderStageDataDrawer();
  $("jobStatus").textContent = state.selectedExample ? "Example loaded. Exact bundled inputs will be used for Run demo." : "Demo data loaded. Adjust controls to update live.";
}

async function runDemo() {
  if (!state.selected) return;
  $("runDemoButton").disabled = true;
  $("runButton").disabled = true;
  $("jobStatus").textContent = "Running demo locally...";
  $("downloadLinks").innerHTML = "";
  setPreviewVisible(false);
  $("logs").style.display = "none";
  $("selectedOutput").innerHTML = "";
  try {
    loadDemoIntoUi();
    const payload = { params: sanitizeParamsForRun(state.params) };
    if (state.selectedExample?.id) payload.example_id = state.selectedExample.id;
    const result = await api(`/api/plugins/${state.selected}/run-demo`, {
      method: "POST",
      body: JSON.stringify(payload),
      headers: { "Content-Type": "application/json" }
    });
    $("jobStatus").textContent = `${result.status}: ${result.message || result.job_id || ""}`;
    if (result.status === "completed") {
      renderDownloads(result.outputs);
      if (result.outputs.preview) {
        await updateInstantPreview(result.outputs);
      }
      await renderSelectedOutputs(result.outputs);
      $("outputPathText").textContent = result.output_dir || "";
    } else if (result.error) {
      $("jobStatus").textContent = `failed: ${result.error.error || result.error.detail || "Plugin failed"}`;
    }
    await loadLogs(result.job_id);
    await refreshResults();
    await refreshState();
  } catch (error) {
    $("jobStatus").textContent = `Demo failed: ${error.message}`;
  } finally {
    $("runDemoButton").disabled = !((state.demo && Object.keys(state.demo.files || {}).length) || state.examples.length);
    $("runButton").disabled = false;
  }
}

function renderColumnSelector() {
  const box = $("columnSelector");
  const preview = getPrimaryPreview();
  box.innerHTML = "";
  if (!preview?.columns?.length) return;
  if (!state.selectedColumns.size) {
    numericColumnOptions().forEach((col) => state.selectedColumns.add(col));
  }
  const head = document.createElement("div");
  head.className = "selector-head";
  head.innerHTML = `<strong>Column selector</strong><small>Defaults to numeric columns except the first column.</small>`;
  box.appendChild(head);
  const actions = document.createElement("div");
  actions.className = "selector-actions";
  actions.innerHTML = `<button type="button">All numeric</button><button type="button">Clear</button>`;
  actions.children[0].onclick = () => {
    state.selectedColumns = new Set(numericColumnOptions());
    state.params.value_columns = Array.from(state.selectedColumns);
    syncJsonFromParams();
    renderColumnSelector();
    triggerAutoUpdate(100);
  };
  actions.children[1].onclick = () => {
    state.selectedColumns.clear();
    state.params.value_columns = [];
    syncJsonFromParams();
    renderColumnSelector();
    triggerAutoUpdate(100);
  };
  box.appendChild(actions);
  const grid = document.createElement("div");
  grid.className = "check-grid";
  preview.columns.forEach((col) => {
    const label = document.createElement("label");
    label.innerHTML = `<input type="checkbox" ${state.selectedColumns.has(col) ? "checked" : ""} /> <span>${escapeHtml(col)}</span>`;
    const input = label.querySelector("input");
    input.onchange = () => {
      if (input.checked) state.selectedColumns.add(col);
      else state.selectedColumns.delete(col);
      state.params.value_columns = Array.from(state.selectedColumns);
      syncJsonFromParams();
      triggerAutoUpdate(100);
    };
    grid.appendChild(label);
  });
  box.appendChild(grid);
  state.params.value_columns = Array.from(state.selectedColumns);
  syncJsonFromParams();
}

function rowLabels() {
  const preview = getPrimaryPreview();
  if (!preview?.preview_rows?.length) return [];
  const columns = preview.columns || [];
  const labelColumn = state.params.row_label_column || state.params.label_column || columns[0];
  return preview.preview_rows.map((row) => String(row[labelColumn] ?? "")).filter(Boolean);
}

function renderRowSelector() {
  const box = $("rowSelector");
  const labels = rowLabels();
  box.innerHTML = "";
  if (!labels.length) return;
  const head = document.createElement("div");
  head.className = "selector-head";
  head.innerHTML = `<strong>Row selector</strong><small>Select specific rows to include or exclude.</small>`;
  box.appendChild(head);
  const actions = document.createElement("div");
  actions.className = "selector-actions";
  actions.innerHTML = `
    <select id="rowMode"><option value="include">Include selected</option><option value="exclude">Exclude selected</option></select>
    <button type="button">Clear</button>
  `;
  actions.querySelector("select").value = state.rowMode;
  actions.querySelector("select").onchange = (event) => {
    state.rowMode = event.target.value;
    commitRowSelection();
    triggerAutoUpdate(100);
    renderStageDataDrawer();
  };
  actions.querySelector("button").onclick = () => {
    state.selectedRows.clear();
    commitRowSelection();
    renderRowSelector();
    triggerAutoUpdate(100);
    renderStageDataDrawer();
  };
  box.appendChild(actions);
  const grid = document.createElement("div");
  grid.className = "check-grid rows";
  labels.slice(0, 80).forEach((id) => {
    const label = document.createElement("label");
    label.innerHTML = `<input type="checkbox" ${state.selectedRows.has(id) ? "checked" : ""} /> <span>${escapeHtml(id)}</span>`;
    const input = label.querySelector("input");
    input.onchange = () => {
      if (input.checked) state.selectedRows.add(id);
      else state.selectedRows.delete(id);
      commitRowSelection();
      triggerAutoUpdate(100);
      renderStageDataDrawer();
    };
    grid.appendChild(label);
  });
  box.appendChild(grid);
}

function commitRowSelection() {
  if (state.rowMode === "exclude") {
    state.params.rows_exclude = Array.from(state.selectedRows);
    delete state.params.rows_include;
  } else {
    state.params.rows_include = Array.from(state.selectedRows);
    delete state.params.rows_exclude;
  }
  syncJsonFromParams();
}

function renderStageDataDrawer() {
  renderStageRowSelector();
  renderStageTablePreview();
}

function renderStageRowSelector() {
  const box = $("stageRowSelector");
  if (!box) return;
  const labels = rowLabels();
  box.innerHTML = "";
  if (!labels.length) {
    box.innerHTML = `<div class="empty muted">No row labels parsed from dataset yet. Click "⚡ Load Demo Data" or upload a dataset.</div>`;
    return;
  }

  const head = document.createElement("div");
  head.className = "stage-row-head";
  head.innerHTML = `
    <select id="stageRowMode">
      <option value="include">Include selected rows</option>
      <option value="exclude">Exclude selected rows</option>
    </select>
    <input type="text" id="stageRowSearch" placeholder="🔍 Search/filter row names..." />
    <div class="stage-row-actions">
      <button type="button" id="stageRowAll">Select All</button>
      <button type="button" id="stageRowClear">Clear All</button>
    </div>
  `;

  const modeSelect = head.querySelector("#stageRowMode");
  modeSelect.value = state.rowMode;
  modeSelect.onchange = (e) => {
    state.rowMode = e.target.value;
    commitRowSelection();
    triggerAutoUpdate(50);
    renderStageDataDrawer();
  };

  const searchInput = head.querySelector("#stageRowSearch");
  const chipsContainer = document.createElement("div");
  chipsContainer.className = "stage-row-chips";

  const drawChips = () => {
    chipsContainer.innerHTML = "";
    const q = searchInput.value.trim().toLowerCase();
    labels.filter((id) => !q || id.toLowerCase().includes(q)).slice(0, 100).forEach((id) => {
      const chip = document.createElement("button");
      chip.type = "button";
      chip.className = `stage-row-chip ${state.selectedRows.has(id) ? "selected" : ""}`;
      chip.textContent = id;
      chip.onclick = () => {
        if (state.selectedRows.has(id)) state.selectedRows.delete(id);
        else state.selectedRows.add(id);
        commitRowSelection();
        triggerAutoUpdate(50);
        renderStageDataDrawer();
      };
      chipsContainer.appendChild(chip);
    });
  };

  searchInput.oninput = drawChips;

  head.querySelector("#stageRowAll").onclick = () => {
    labels.forEach((id) => state.selectedRows.add(id));
    commitRowSelection();
    triggerAutoUpdate(50);
    renderStageDataDrawer();
  };

  head.querySelector("#stageRowClear").onclick = () => {
    state.selectedRows.clear();
    commitRowSelection();
    triggerAutoUpdate(50);
    renderStageDataDrawer();
  };

  box.appendChild(head);
  box.appendChild(chipsContainer);
  drawChips();
}

function renderStageTablePreview() {
  const box = $("stageTablePreview");
  if (!box) return;
  const preview = getPrimaryPreview();
  box.innerHTML = "";
  if (!preview?.preview_rows?.length) {
    box.innerHTML = `<div class="empty muted">No dataset loaded for preview. Click "⚡ Load Demo Data" or upload a dataset.</div>`;
    return;
  }
  const columns = preview.columns.slice(0, 20);
  const labelColumn = state.params.row_label_column || state.params.label_column || columns[0];

  const table = document.createElement("table");
  table.innerHTML = `
    <thead>
      <tr>
        <th>Filter</th>
        ${columns.map((col) => `<th>${escapeHtml(col)}</th>`).join("")}
      </tr>
    </thead>
    <tbody>
      ${preview.preview_rows.slice(0, 50).map((row, idx) => {
        const rowId = String(row[labelColumn] ?? "");
        const isSelected = state.selectedRows.has(rowId);
        return `
          <tr class="${isSelected ? "row-selected" : ""}">
            <td><input type="checkbox" ${isSelected ? "checked" : ""} class="stage-row-check" data-id="${escapeHtml(rowId)}" /></td>
            ${columns.map((col) => `<td>${escapeHtml(row[col] ?? "")}</td>`).join("")}
          </tr>
        `;
      }).join("")}
    </tbody>
  `;

  table.querySelectorAll(".stage-row-check").forEach((chk) => {
    chk.onchange = (e) => {
      e.stopPropagation();
      const id = chk.dataset.id;
      if (chk.checked) state.selectedRows.add(id);
      else state.selectedRows.delete(id);
      commitRowSelection();
      triggerAutoUpdate(50);
      renderStageDataDrawer();
    };
  });

  box.appendChild(table);
}

function renderTablePreview() {
  const box = $("tablePreview");
  const preview = getPrimaryPreview();
  box.innerHTML = "";
  if (!preview?.preview_rows?.length) {
    box.innerHTML = `<div class="empty">No preview rows available.</div>`;
    return;
  }
  const columns = preview.columns.slice(0, 16);
  const table = document.createElement("table");
  table.innerHTML = `
    <thead><tr>${columns.map((col) => `<th>${escapeHtml(col)}</th>`).join("")}</tr></thead>
    <tbody>
      ${preview.preview_rows.slice(0, 20).map((row) => `<tr>${columns.map((col) => `<td>${escapeHtml(row[col] ?? "")}</td>`).join("")}</tr>`).join("")}
    </tbody>
  `;
  box.appendChild(table);
  $("tableHint").textContent = `${preview.row_count_estimate || 0} rows · ${preview.column_count || 0} columns`;
}

const OMICS_PLOT_MAP = {
  group_heatmap: {
    name: "Clustered Heatmap",
    cat: "Heatmap",
    icon: "🔥",
    badge: "TRANSCRIPTOMICS",
    desc: "Hierarchical clustering heatmap for expression and pairwise correlation matrices."
  },
  threshold_matrix_heatmap: {
    name: "Threshold Matrix Heatmap",
    cat: "Heatmap",
    icon: "🔳",
    badge: "GENOMICS",
    desc: "Binary response matrix and cutoff-filtered expression heatmaps."
  },
  cluster_dendrogram_plot: {
    name: "Cluster Dendrogram",
    cat: "Heatmap",
    icon: "🌳",
    badge: "CLUSTERING",
    desc: "Sample similarity tree and hierarchical clustering dendrogram."
  },

  sca_volcano_plot: {
    name: "Volcano Plot",
    cat: "Scatter",
    icon: "🌋",
    badge: "DIFFERENTIAL",
    desc: "Differential gene expression significance (-log10 P-val) vs Fold Change."
  },
  quadrant_correlation_scatter: {
    name: "Quadrant Correlation Scatter",
    cat: "Scatter",
    icon: "📐",
    badge: "CORRELATION",
    desc: "Four-quadrant scatter plot for multi-omics correlation & significance thresholds."
  },
  den_plot: {
    name: "Density Scatter Plot",
    cat: "Scatter",
    icon: "🌊",
    badge: "DENSITY",
    desc: "2D kernel density estimation scatter plot with distribution contours."
  },

  stat_plot: {
    name: "Group Boxplot & Violin",
    cat: "Expression",
    icon: "📊",
    badge: "STATISTICS",
    desc: "Boxplots, violins, and bar plots with ANOVA / Wilcoxon statistical testing."
  },
  violin_plot: {
    name: "Split Violin Plot",
    cat: "Expression",
    icon: "🎻",
    badge: "SINGLE-CELL",
    desc: "Grouped and split violin plot for gene expression across cell types."
  },
  exp_stat_plot: {
    name: "Expression Distribution Plot",
    cat: "Expression",
    icon: "📈",
    badge: "EXPRESSION",
    desc: "Expression distribution fitting, boxplots, and significance testing."
  },
  dot_plot: {
    name: "Gene Expression DotPlot",
    cat: "Expression",
    icon: "🔵",
    badge: "SINGLE-CELL",
    desc: "Dot plot displaying percent expressed and mean expression level."
  },
  balloon_plot: {
    name: "Balloon Grid Plot",
    cat: "Expression",
    icon: "🎈",
    badge: "MATRIX",
    desc: "Balloon dot matrix grid displaying multi-variable magnitudes."
  },

  advanced_dim_plot: {
    name: "UMAP / t-SNE Clustering",
    cat: "Dimension",
    icon: "🧩",
    badge: "UMAP / t-SNE",
    desc: "Dimensionality reduction plots for cell clusters and embeddings."
  },
  advanced_feature_plot: {
    name: "Feature Expression Plot",
    cat: "Dimension",
    icon: "✨",
    badge: "FEATURE",
    desc: "Feature gene expression intensity mapped on UMAP/t-SNE coordinates."
  },
  feature_density_plot: {
    name: "Feature Density Scatter",
    cat: "Dimension",
    icon: "🌌",
    badge: "SINGLE-CELL",
    desc: "Quantitative expression density and highlighted scatter in 2D space."
  },

  lineage_plot: {
    name: "Pseudotime Lineage Curve",
    cat: "Trajectory",
    icon: "🌱",
    badge: "PSEUDOTIME",
    desc: "Single-cell developmental trajectory fitting and branching curves."
  },

  dynamic_venn_diagram: {
    name: "Venn & UpSet Diagram",
    cat: "Venn",
    icon: "⭕",
    badge: "SETS / VENN",
    desc: "Interactive Venn diagram and UpSet plot for overlapping gene sets."
  }
};

function renderPlotCards() {
  if ($("discoveryRoot") && typeof renderDiscovery === "function") {
    renderDiscovery();
    return;
  }
  const box = $("plotCards");
  if (!box) return;
  box.innerHTML = "";
  const query = ($("pluginSearch") && $("pluginSearch").value || "").trim().toLowerCase();
  const activeCat = state.category || "All";

  const visible = state.plugins.filter((plugin) => {
    const meta = OMICS_PLOT_MAP[plugin.id] || { name: plugin.name, cat: "All", icon: "📊", badge: "PLOT", desc: plugin.description || "" };
    const catMatch = activeCat === "All" || activeCat === "Favorites" || meta.cat === activeCat || (plugin.category || "").includes(activeCat);
    const textMatch = !query || pluginText(plugin).includes(query) || meta.name.toLowerCase().includes(query) || meta.desc.toLowerCase().includes(query);
    return catMatch && textMatch;
  });

  const toolCount = $("toolCount");
  if (toolCount) toolCount.textContent = visible.length;

  if (!visible.length) {
    box.innerHTML = `<div class="empty card" style="grid-column: 1 / -1; padding: 40px; text-align: center;"><strong>No matching plots found</strong><p>Try selecting another category from the sidebar or clearing your search.</p></div>`;
    return;
  }

  visible.forEach((plugin, index) => {
    const card = document.createElement("article");
    card.className = "plot-card";
    const meta = OMICS_PLOT_MAP[plugin.id] || { name: plugin.display_name || plugin.name, cat: "General", icon: "📊", badge: "PLOT", desc: plugin.description || "" };
    const likeCount = Math.floor(120 + (index * 193) % 1800);

    const openEditorPage = (event) => {
      if (event) event.stopPropagation();
      window.open(`/static/editor.html?plugin=${encodeURIComponent(plugin.id)}`, "_blank");
    };

    card.innerHTML = `
      <div class="card-thumb-box">
        <span class="card-badge">${escapeHtml(meta.badge)}</span>
        <span class="card-like-count">♡ ${escapeHtml(likeCount)}</span>
        ${plugin.preview ? `<img src="${escapeHtml(plugin.preview)}" alt="${escapeHtml(meta.name)} preview" />` : `<div class="card-fallback-icon">${escapeHtml(meta.icon)}</div>`}
      </div>
      <div class="card-content-body">
        <h4>${escapeHtml(meta.name)}</h4>
        <p>${escapeHtml(meta.desc)}</p>
        <div class="card-btn-row">
          <button type="button" class="card-btn primary">🛠️ Open Studio</button>
          <button type="button" class="card-btn secondary">⚡ Try Demo</button>
        </div>
      </div>
    `;

    card.onclick = openEditorPage;
    card.querySelector(".card-btn.primary").onclick = openEditorPage;
    card.querySelector(".card-btn.secondary").onclick = openEditorPage;

    box.appendChild(card);
  });
}
async function previewInputs() {
  if (!state.selected) return;
  $("tableHint").textContent = "Parsing input...";
  const result = await api(`/api/plugins/${state.selected}/preview-input`, { method: "POST", body: collectFileFormData() });
  state.inputPreview = result;
  state.selectedColumns = new Set();
  state.selectedRows = new Set();
  renderInputSummary();
  renderColumnSelector();
  renderRowSelector();
  renderTablePreview();
  renderActiveControls();
  renderStageDataDrawer();
  triggerAutoUpdate(100);
}

async function selectPlugin(pluginId) {
  setMode("module");
  state.selected = pluginId;
  state.inputPreview = null;
  state.demo = null;
  state.selectedColumns = new Set();
  state.selectedRows = new Set();
  renderPluginTree();
  const detail = await api(`/api/plugins/${pluginId}`);
  state.detail = detail;
  state.demo = detail.demo || null;
  $("pluginName").textContent = detail.display_name || detail.name || pluginId;
  $("pluginDescription").textContent = detail.description || "";
  renderFileInputs(detail);
  renderExamples(detail);
  renderSchema(detail.params_schema || detail.parameters);
  $("previewInputButton").disabled = true;
  $("previewInputButton").onclick = previewInputs;
  const hasDemo = Boolean((state.demo && Object.keys(state.demo.files || {}).length) || state.examples.length);
  $("loadDemoButton").disabled = !hasDemo;
  $("runDemoButton").disabled = !hasDemo;
  $("loadDemoButton").onclick = loadDemoIntoUi;
  $("runDemoButton").onclick = runDemo;
  $("runButton").disabled = false;
  $("jobStatus").textContent = "Ready.";
  $("downloadLinks").innerHTML = "";
  $("quickDownloads").innerHTML = "";
  $("logs").style.display = "none";
  $("logs").textContent = "";
  setPreviewVisible(false);
  $("inputSummary").innerHTML = "";
  $("columnSelector").innerHTML = "";
  $("rowSelector").innerHTML = "";
  $("tablePreview").innerHTML = "";
  $("selectedOutput").innerHTML = "";
  renderDemoGallery();
  $("statusText").textContent = `Active module: ${detail.display_name || detail.name || pluginId}`;

  if (hasDemo) {
    await runDemo();
  }
}

function validateRequiredFiles() {
  const missing = [];
  document.querySelectorAll("input[type=file][data-field][required]").forEach((input) => {
    if (!input.files || !input.files[0]) missing.push(input.dataset.field);
  });
  if (missing.length) throw new Error(`Missing required file: ${missing.join(", ")}`);
}

function validateRequiredParams() {
  const missing = [];
  state.schemaSections.forEach((section) => {
    section.controls.forEach((control) => {
      const value = state.params[control.key];
      if (control.required && (value === undefined || value === "" || (Array.isArray(value) && !value.length))) {
        missing.push(control.label);
      }
    });
  });
  if (missing.length) throw new Error(`Missing required parameter: ${missing.join(", ")}`);
}

function collectFormData() {
  if (!state.selected) throw new Error("Select a plot plugin first.");
  validateRequiredFiles();
  validateRequiredParams();
  const form = collectFileFormData();
  const paramsText = $("paramsText").value.trim() || "{}";
  const params = JSON.parse(paramsText);
  form.append("params", prettify(params));
  return form;
}

async function runSelectedPlugin() {
  $("runButton").disabled = true;
  $("jobStatus").textContent = "Running plot locally...";
  $("downloadLinks").innerHTML = "";
  $("quickDownloads").innerHTML = "";
  setPreviewVisible(false);
  $("logs").style.display = "none";
  $("selectedOutput").innerHTML = "";
  try {
    const form = collectFormData();
    const result = await api(`/api/plugins/${state.selected}/run`, { method: "POST", body: form });
    $("jobStatus").textContent = `${result.status}: ${result.message || result.job_id}`;
    renderValidationPanel($("validationPanel"), result.vnext);
    if (result.status === "completed") {
      renderDownloads(result.outputs);
      if (result.outputs.preview) {
        await updateInstantPreview(result.outputs);
      }
      await renderSelectedOutputs(result.outputs);
      $("outputPathText").textContent = result.output_dir || "";
    } else if (result.error) {
      $("jobStatus").textContent = `failed: ${result.error.error || result.error.detail || "Plugin failed"}`;
    }
    await loadLogs(result.job_id);
    await refreshResults();
    await refreshState();
  } catch (error) {
    $("jobStatus").textContent = `Failed: ${error.message}`;
  } finally {
    $("runButton").disabled = false;
  }
}

function normalizeOutputMapApp(outputs = {}) {
  const map = {};
  Object.entries(outputs || {}).forEach(([key, path]) => {
    if (!path || key === "preview") return;
    const raw = String(path);
    const url = raw.startsWith("http") || raw.startsWith("/")
      ? raw
      : `/api/results/file?path=${encodeURIComponent(raw)}`;
    const keyLower = key.toLowerCase();
    const tail = raw.split("/").pop() || keyLower;
    const ext = (tail.includes(".") ? tail.split(".").pop() : keyLower).toLowerCase();
    const fmt = ["svg", "pdf", "png", "tiff", "tif", "json", "log"].includes(keyLower)
      ? keyLower
      : ext;
    map[fmt] = { url, filename: tail.includes(".") ? tail : `figure.${fmt === "tif" ? "tiff" : fmt}` };
    if (fmt === "tif") map.tiff = map[fmt];
    if (fmt === "tiff") map.tif = map[fmt];
  });
  return map;
}

function ensureExportItemsApp(container) {
  if (!container) return [];
  const primaryOrder = [
    { fmt: "svg", label: "SVG" },
    { fmt: "pdf", label: "PDF" },
    { fmt: "png", label: "PNG" },
    { fmt: "tiff", label: "TIFF" },
  ];
  let items = Array.from(container.querySelectorAll(".export-item[data-fmt]"));
  if (items.length < primaryOrder.length) {
    container.innerHTML = "";
    primaryOrder.forEach(({ fmt, label }) => {
      const a = document.createElement("a");
      a.className = "export-item is-disabled";
      a.dataset.fmt = fmt;
      a.setAttribute("role", "menuitem");
      a.href = "#";
      a.tabIndex = -1;
      a.textContent = label;
      container.appendChild(a);
    });
    items = Array.from(container.querySelectorAll(".export-item[data-fmt]"));
  }
  return items;
}

function renderDownloads(outputs = {}) {
  const links = $("downloadLinks");
  const quickBox = $("quickDownloads");
  const headerBox = $("headerExportLinks");
  const empty = $("exportMenuEmpty");
  const map = normalizeOutputMapApp(outputs);
  if (window.__lastPlotOutputs !== undefined) window.__lastPlotOutputs = outputs || {};
  window.__lastPlotOutputs = outputs || {};

  const rows = ensureExportItemsApp(quickBox);
  let enabledCount = 0;
  rows.forEach((row) => {
    const fmt = (row.dataset.fmt || "").toLowerCase();
    const item = map[fmt] || map[fmt === "tiff" ? "tif" : fmt];
    const label = fmt === "tiff" ? "TIFF" : fmt.toUpperCase();
    row.textContent = label;
    if (item && item.url) {
      enabledCount += 1;
      row.className = "export-item is-ready";
      row.href = item.url;
      row.target = "_blank";
      row.rel = "noopener noreferrer";
      row.download = item.filename || `figure.${fmt === "tiff" ? "tiff" : fmt}`;
      row.title = `Download ${label}`;
      row.tabIndex = 0;
    } else {
      row.className = "export-item is-disabled";
      row.href = "#";
      row.removeAttribute("download");
      row.removeAttribute("target");
      row.title = "Not available yet — run a plot first";
      row.tabIndex = -1;
    }
  });

  if (headerBox) {
    headerBox.innerHTML = "";
    rows.forEach((row) => {
      if (!row.classList.contains("is-ready")) return;
      headerBox.appendChild(row.cloneNode(true));
    });
  }

  if (links) {
    links.innerHTML = "";
    links.hidden = true;
    const secondary = Object.keys(map).filter((k) => !["svg", "pdf", "png", "tiff", "tif"].includes(k));
    if (secondary.length) {
      links.hidden = false;
      secondary.forEach((key) => {
        const a = document.createElement("a");
        a.href = map[key].url;
        a.target = "_blank";
        a.rel = "noopener noreferrer";
        a.textContent = key.replace(/_/g, " ").toUpperCase();
        links.appendChild(a);
      });
    }
  }
  if (empty) {
    empty.hidden = enabledCount > 0;
    empty.classList.toggle("is-hidden", enabledCount > 0);
    empty.textContent = enabledCount > 0 ? "" : "Run a plot to enable SVG / PDF / PNG downloads.";
  }
}

const JOURNAL_PRESETS = {
  single: { width: 3.35, height: 3.35, dpi: 300 },   // ~8.5 cm
  double: { width: 6.89, height: 5.0, dpi: 300 },    // ~17.5 cm
  nature: { width: 7.0, height: 5.5, dpi: 600 },
  square: { width: 4.72, height: 4.72, dpi: 300 },   // ~120 mm
};

function applyJournalPreset(name) {
  const preset = JOURNAL_PRESETS[name];
  if (!preset) return;
  mergeParams(preset);
  const status = $("jobStatus");
  if (status) {
    status.textContent = `Journal preset “${name}”: width=${preset.width}in, height=${preset.height}in, dpi=${preset.dpi}. Click Run Plot to apply.`;
  }
  if ($("autoUpdateToggle")?.checked) triggerAutoUpdate(100);
}

function wireExportMenu() {
  const menu = $("exportMenu");
  const btn = $("exportMenuBtn");
  const panel = $("exportMenuPanel");
  if (!btn || !panel || !menu) return;

  panel.removeAttribute("hidden");
  window.__lastPlotOutputs = window.__lastPlotOutputs || {};

  const positionPanel = () => {
    const rect = btn.getBoundingClientRect();
    panel.style.position = "fixed";
    panel.style.top = `${Math.round(rect.bottom + 6)}px`;
    panel.style.right = `${Math.round(window.innerWidth - rect.right)}px`;
    panel.style.left = "auto";
    panel.style.zIndex = "99999";
  };

  const setOpen = (isOpen) => {
    menu.classList.toggle("is-open", isOpen);
    menu.classList.toggle("open", isOpen);
    btn.setAttribute("aria-expanded", isOpen ? "true" : "false");
    if (isOpen) {
      positionPanel();
      renderDownloads(window.__lastPlotOutputs || {});
    }
  };

  btn.addEventListener("click", (e) => {
    e.preventDefault();
    e.stopPropagation();
    setOpen(!menu.classList.contains("is-open"));
  });
  panel.addEventListener("click", (e) => {
    e.stopPropagation();
    const link = e.target.closest("a.export-item.is-ready");
    if (link) setTimeout(() => setOpen(false), 80);
    else if (e.target.closest("a.export-item.is-disabled")) e.preventDefault();
  });
  document.addEventListener("click", (e) => {
    if (!menu.contains(e.target)) setOpen(false);
  });
  window.addEventListener("resize", () => {
    if (menu.classList.contains("is-open")) positionPanel();
  });
  document.addEventListener("keydown", (e) => {
    if (e.key === "Escape") setOpen(false);
  });
  renderDownloads(window.__lastPlotOutputs || {});
}

function wireJournalPresets() {
  document.querySelectorAll(".journal-preset").forEach((button) => {
    button.onclick = () => applyJournalPreset(button.dataset.preset);
  });
}

function setPreviewVisible(visible, mode = "image") {
  const image = $("preview");
  const plotlyBox = $("plotlyPreview");
  const empty = $("emptyCanvas");
  if (image) image.style.display = visible && mode !== "plotly" ? "block" : "none";
  if (plotlyBox) plotlyBox.classList.toggle("hidden", !(visible && mode === "plotly"));
  if (empty) empty.classList.toggle("hidden", visible);
}

function wireFloatToolsDrag() {
  const bar = $("canvasControlBar");
  const handle = $("floatDragHandle") || bar;
  const stage = document.querySelector(".plot-stage");
  if (!bar || !stage) return;

  const storageKey = "omicscanvas.floatTools.pos";
  const clampToStage = (left, top) => {
    const s = stage.getBoundingClientRect();
    const b = bar.getBoundingClientRect();
    const maxL = Math.max(0, s.width - b.width - 4);
    const maxT = Math.max(0, s.height - b.height - 4);
    return {
      left: Math.min(maxL, Math.max(0, left)),
      top: Math.min(maxT, Math.max(0, top)),
    };
  };
  const place = (left, top) => {
    const p = clampToStage(left, top);
    bar.style.left = `${p.left}px`;
    bar.style.top = `${p.top}px`;
    bar.style.right = "auto";
    bar.style.bottom = "auto";
  };

  try {
    const saved = JSON.parse(localStorage.getItem(storageKey) || "null");
    if (saved && typeof saved.left === "number" && typeof saved.top === "number") {
      place(saved.left, saved.top);
    }
  } catch (_) {}

  let dragging = false;
  let startX = 0;
  let startY = 0;
  let originLeft = 0;
  let originTop = 0;
  let moved = false;

  handle.addEventListener("pointerdown", (e) => {
    if (e.target.closest("[data-stage-action]")) return;
    if (e.button != null && e.button !== 0) return;
    dragging = true;
    moved = false;
    bar.classList.add("is-dragging");
    const s = stage.getBoundingClientRect();
    const b = bar.getBoundingClientRect();
    startX = e.clientX;
    startY = e.clientY;
    originLeft = b.left - s.left;
    originTop = b.top - s.top;
    place(originLeft, originTop);
    handle.setPointerCapture?.(e.pointerId);
    e.preventDefault();
  });
  window.addEventListener("pointermove", (e) => {
    if (!dragging) return;
    const dx = e.clientX - startX;
    const dy = e.clientY - startY;
    if (Math.abs(dx) + Math.abs(dy) > 2) moved = true;
    place(originLeft + dx, originTop + dy);
  });
  const endDrag = (e) => {
    if (!dragging) return;
    dragging = false;
    bar.classList.remove("is-dragging");
    try { handle.releasePointerCapture?.(e.pointerId); } catch (_) {}
    try {
      localStorage.setItem(storageKey, JSON.stringify({
        left: parseFloat(bar.style.left) || 0,
        top: parseFloat(bar.style.top) || 0,
      }));
    } catch (_) {}
  };
  window.addEventListener("pointerup", endDrag);
  window.addEventListener("pointercancel", endDrag);
  window.addEventListener("resize", () => {
    if (!bar.style.left) return;
    place(parseFloat(bar.style.left) || 0, parseFloat(bar.style.top) || 0);
  });
  handle.addEventListener("click", (e) => {
    if (moved) {
      e.preventDefault();
      e.stopPropagation();
    }
  });
}

function wireStudioActions() {
  setupControlTabEvents();
  wireExportMenu();
  wireJournalPresets();
  wireFloatToolsDrag();

  document.querySelectorAll("[data-stage-action]").forEach((button) => {
    button.onclick = () => {
      const action = button.dataset.stageAction;
      const image = $("preview");
      const plotlyBox = $("plotlyPreview");
      if (action === "run") return runSelectedPlugin();
      if (action === "preview") return image?.scrollIntoView({ behavior: "smooth", block: "center" });
      if (action === "download") return $("downloadLinks")?.querySelector("a")?.click();
      if (action === "zoom-in" || action === "zoom-out") {
        state.previewScale = Math.max(0.4, Math.min(2.5, (state.previewScale || 1) + (action === "zoom-in" ? 0.15 : -0.15)));
        if (image) image.style.transform = `scale(${state.previewScale})`;
        if (plotlyBox) plotlyBox.style.transform = `scale(${state.previewScale})`;
      }
      if (action === "fullscreen") {
        const target = $("previewWrap") || $("stageCanvas");
        if (!document.fullscreenElement) target?.requestFullscreen?.();
        else document.exitFullscreen?.();
      }
    };
  });
}

function parseDelimited(text) {
  const lines = text.trim().split(/\r?\n/).filter(Boolean);
  if (!lines.length) return { columns: [], rows: [] };
  const delimiter = lines[0].includes("\t") ? "\t" : ",";
  const columns = lines[0].split(delimiter);
  const rows = lines.slice(1, 31).map((line) => {
    const values = line.split(delimiter);
    return Object.fromEntries(columns.map((col, index) => [col, values[index] ?? ""]));
  });
  return { columns, rows };
}

async function renderSelectedOutputs(outputs = {}) {
  const keys = ["selected_rows", "selected_points", "selected_features", "subset_elements", "subsets", "enrichment_results"];
  const found = keys.find((key) => outputs[key]);
  const box = $("selectedOutput");
  if (!found) return;
  const text = await fetch(outputs[found]).then((res) => res.ok ? res.text() : "");
  const tableData = parseDelimited(text);
  if (!tableData.columns.length) return;
  box.innerHTML = `<div class="card-head"><h3>${escapeHtml(found.replace(/_/g, " "))}</h3><a href="${escapeHtml(outputs[found])}" target="_blank">Download CSV</a></div>`;
  const table = document.createElement("table");
  table.innerHTML = `
    <thead><tr>${tableData.columns.map((col) => `<th>${escapeHtml(col)}</th>`).join("")}</tr></thead>
    <tbody>${tableData.rows.map((row) => `<tr>${tableData.columns.map((col) => `<td>${escapeHtml(row[col] ?? "")}</td>`).join("")}</tr>`).join("")}</tbody>
  `;
  box.appendChild(table);
}

async function loadLogs(jobId) {
  if (!jobId) return;
  const data = await api(`/api/jobs/${jobId}/logs`);
  if (data.logs && data.logs.length) {
    $("logs").textContent = data.logs.join("\n");
    $("logs").style.display = "block";
  }
}

// ---------------------------------------------------------------------------
// AI Studio
// ---------------------------------------------------------------------------
const aiState = {
  sessionId: null,
  revision: 0,
  file: null,
  recommendations: [],
  figures: [],
  intent: null,
  skills: [],
  lastJob: null,
};

function invalidateAiSession() {
  aiState.revision += 1;
  aiState.sessionId = null;
  aiState.lastJob = null;
  renderAiIntent(null);
  if ($("aiProfileBox")) { $("aiProfileBox").innerHTML = ""; $("aiProfileBox").classList.add("hidden"); }
  renderAiSkills([]);
  renderAiRecommendations([]);
  renderAiFigures([]);
  renderAiPalettes([]);
  if ($("aiDemoStatus")) $("aiDemoStatus").textContent = "Inputs changed. Recommend again before generating a figure.";
}

function setAiBusy(busy) {
  document.querySelectorAll('#aiRecommendBtn, #aiPipelineBtn, [data-ai-demo], [data-ai-demo-builtin]').forEach((button) => { button.disabled = busy || button.dataset.invalidDraft === "true"; });
}

function aiAppendChat(text, who = "bot") {
  const log = $("aiChatLog");
  if (!log) return;
  const bubble = document.createElement("div");
  bubble.className = `ai-chat-bubble ${who}`;
  bubble.textContent = text;
  log.appendChild(bubble);
  log.scrollTop = log.scrollHeight;
}

async function refreshAiStatus() {
  const pill = $("aiEnginePill");
  if (!pill) return;
  try {
    const st = await api("/api/ai/status");
    pill.textContent = st.spacexai ? "Rules + SpaceXAI" : "Rules engine";
    pill.classList.toggle("is-llm", Boolean(st.spacexai));
    pill.title = st.message || "";
  } catch {
    pill.textContent = "offline";
  }
}

function renderAiIntent(intent) {
  const box = $("aiIntentBox");
  if (!box) return;
  aiState.intent = intent || null;
  if (!intent || (!intent.summary && !intent.goal)) {
    box.classList.add("hidden");
    box.innerHTML = "";
    return;
  }
  box.classList.remove("hidden");
  const bits = [];
  if (intent.analysis_goal) bits.push(`<div><strong>Analysis goal</strong> ${escapeHtml(intent.analysis_goal)}</div>`);
  if (intent.data_type) bits.push(`<div><strong>Data type</strong> ${escapeHtml(intent.data_type)}</div>`);
  if (intent.recommended_focus) bits.push(`<div><strong>Focus</strong> ${escapeHtml(intent.recommended_focus)}</div>`);
  box.innerHTML = `
    <div class="ai-intent-head">
      <strong>Intent summary</strong>
      <span class="ai-score">${escapeHtml(intent.source || "rules")}</span>
    </div>
    <p class="ai-intent-summary">${escapeHtml(intent.summary || "")}</p>
    ${bits.join("")}
  `;
}

function renderAiSkills(skills) {
  const box = $("aiSkillsBox");
  if (!box) return;
  aiState.skills = skills || [];
  if (!skills?.length) {
    box.classList.add("hidden");
    box.innerHTML = "";
    return;
  }
  box.classList.remove("hidden");
  const cards = skills
    .map(
      (s) => `
    <div class="ai-skill-card">
      <div class="ai-skill-title">
        <strong>${escapeHtml(s.name || s.skill_id)}</strong>
        <code>${escapeHtml(s.skill_id)}</code>
        <span class="ai-score">${escapeHtml(s.score ?? "")}</span>
      </div>
      <p class="ai-rec-reason">${escapeHtml(s.reason || s.description || "")}</p>
      <div class="ai-cols muted">${escapeHtml(s.note || "Plot workflow guide.")}</div>
      <div class="ai-cols muted">${s.role === "plot_workflow" ? "Plotting workflow" : "Plugin authoring guide"}${s.workflow_url ? ` · <a href="${escapeHtml(s.workflow_url)}" target="_blank" rel="noopener noreferrer">View workflow</a>` : ""}</div>
      ${(s.related_plugins || []).length
        ? `<div class="ai-tag-row">${(s.matched_plugins?.length ? s.matched_plugins : s.related_plugins || [])
            .slice(0, 6)
            .map((p) => `<span class="ai-tag">${escapeHtml(p)}</span>`)
            .join("")}</div>`
        : ""}
    </div>`
    )
    .join("");
  box.innerHTML = `
    <div class="ai-intent-head"><strong>Matched skills</strong><span class="ai-score">guides</span></div>
    <div class="ai-skills-list">${cards}</div>
  `;
}

function renderAiProfile(profile) {
  const box = $("aiProfileBox");
  if (!box || !profile) return;
  box.classList.remove("hidden");
  const tags = (profile.tags || []).map((t) => `<span class="ai-tag">${escapeHtml(t)}</span>`).join(" ");
  box.innerHTML = `
    <div><strong>${escapeHtml(profile.filename || "table")}</strong>
      · ${escapeHtml(profile.row_count_estimate ?? "?")} rows × ${escapeHtml(profile.column_count ?? "?")} cols</div>
    <div class="ai-tag-row">${tags}</div>
    <div class="ai-cols muted">numeric: ${escapeHtml((profile.numeric_columns || []).slice(0, 8).join(", ") || "—")}</div>
    <div class="ai-cols muted">categorical: ${escapeHtml((profile.categorical_columns || []).slice(0, 8).join(", ") || "—")}</div>
  `;
}

function renderAiRecommendations(recs) {
  const list = $("aiRecommendList");
  if (!list) return;
  aiState.recommendations = recs || [];
  if (!recs?.length) {
    list.innerHTML = `<div class="ai-empty">No recommendations. Try another table or add a goal description.</div>`;
    return;
  }
  list.innerHTML = "";
  recs.forEach((rec, idx) => {
    const card = document.createElement("div");
    card.className = "ai-rec-card";
    card.innerHTML = `
      <div class="ai-rec-rank">#${idx + 1}</div>
      <div class="ai-rec-body">
        <div class="ai-rec-title">
          <strong>${escapeHtml(rec.name || rec.plugin_id)}</strong>
          <code>${escapeHtml(rec.plugin_id)}</code>
          <span class="ai-score">score ${escapeHtml(rec.score ?? "—")}</span>
        </div>
        <p class="ai-rec-reason">${escapeHtml(rec.reason || "")}</p>
        ${rec.draft ? `<div class="ai-draft-summary"><strong>Render plan</strong><p>${rec.draft.error ? escapeHtml(rec.draft.error) : `${escapeHtml(rec.draft.mode)} · All ${escapeHtml(rec.draft.rows ?? "uploaded")} observations`}</p><p class="ai-cols muted">${Object.entries(rec.draft.mappings || {}).map(([key, value]) => `${escapeHtml(key.replace(/_column$/, ""))}: ${escapeHtml(Array.isArray(value) ? value.join(", ") : value)}`).join(" · ")}</p></div>` : ""}
        <div class="ai-rec-actions">
          <button type="button" class="primary compact-action" ${rec.draft?.error ? 'disabled data-invalid-draft="true"' : ''} data-ai-demo="${escapeHtml(rec.plugin_id)}">Generate demo</button>
          <button type="button" class="secondary compact-action" data-ai-demo-builtin="${escapeHtml(rec.plugin_id)}">Built-in demo</button>
          <a class="secondary compact-action" href="${rec.editor_url || `/static/editor.html?plugin=${escapeHtml(rec.plugin_id)}`}" target="_blank" rel="noopener noreferrer">Open example</a>
        </div>
      </div>
    `;
    list.appendChild(card);
  });
  list.querySelectorAll("[data-ai-demo]").forEach((btn) => {
    btn.onclick = () => runAiBuildDemo(btn.dataset.aiDemo, false);
  });
  list.querySelectorAll("[data-ai-demo-builtin]").forEach((btn) => {
    btn.onclick = () => runAiBuildDemo(btn.dataset.aiDemoBuiltin, true);
  });
}

function renderAiFigures(figures) {
  const grid = $("aiFiguresGrid");
  if (!grid) return;
  aiState.figures = figures || [];
  if (!figures?.length) {
    grid.innerHTML = `<div class="ai-empty">Rendered demos and explanations will show here.</div>`;
    return;
  }
  grid.innerHTML = "";
  figures.forEach((fig) => {
    const ok = fig.status === "completed";
    const preview = fig.preview || fig.outputs?.preview || "";
    const cacheBust = preview
      ? `${preview}${preview.includes("?") ? "&" : "?"}t=${Date.now()}`
      : "";
    const dl = fig.outputs
      ? Object.entries(fig.outputs)
          .filter(([k]) => ["svg", "pdf", "png", "tiff"].includes(k))
          .map(([k, href]) => `<a href="${escapeHtml(href)}" target="_blank" rel="noopener">${escapeHtml(k.toUpperCase())}</a>`)
          .join(" ")
      : "";
    const err =
      !ok && fig.error
        ? (fig.error.detail || fig.error.error || JSON.stringify(fig.error))
        : "";
    const card = document.createElement("div");
    card.className = `ai-figure-card ${ok ? "is-ok" : "is-fail"}`;
    card.innerHTML = `
      <div class="ai-figure-head">
        <span class="ai-rec-rank">#${escapeHtml(fig.rank ?? "?")}</span>
        <div class="ai-rec-title">
          <strong>${escapeHtml(fig.name || fig.plugin_id)}</strong>
          <code>${escapeHtml(fig.plugin_id)}</code>
          <span class="ai-score">${escapeHtml(ok ? "ok" : fig.status || "failed")}</span>
        </div>
      </div>
      <div class="ai-figure-preview">
        ${
          ok && cacheBust
            ? `<img src="${escapeHtml(cacheBust)}" alt="${escapeHtml(fig.plugin_id)}" class="ai-preview-img">`
            : `<div class="ai-preview-empty">${escapeHtml(err || "No preview")}</div>`
        }
      </div>
      <div class="ai-figure-explain">
        <div class="ai-intent-head">
          <strong>AI explanation</strong>
          <span class="ai-score">${escapeHtml(fig.explanation_source || "rules")}</span>
        </div>
        <p class="ai-explain-text">${escapeHtml(fig.explanation || fig.reason || "—")}</p>
      </div>
      <div class="ai-rec-actions">
        <a class="secondary compact-action" href="${fig.editor_url || `/static/editor.html?plugin=${escapeHtml(fig.plugin_id)}`}" target="_blank" rel="noopener noreferrer">${fig.job_id ? "Open Editor" : "Open example"}</a>
        ${dl ? `<span class="ai-dl-row">${dl}</span>` : ""}
      </div>
      ${fig.ai?.note ? `<div class="ai-cols muted">${escapeHtml(fig.ai.note)}</div>` : ""}
    `;
    grid.appendChild(card);
  });
}

function renderAiPalettes(pals) {
  const list = $("aiPaletteList");
  if (!list) return;
  if (!pals?.length) {
    list.innerHTML = `<div class="ai-empty">No palette tips yet. Try goals like “soft”, “high contrast”, “medical journal”, or “grayscale”.</div>`;
    return;
  }
  list.innerHTML = "";
  pals.forEach((p) => {
    const colors = p.colors || [];
    const swatches = colors
      .map((c) => `<span class="ai-swatch" style="background:${escapeHtml(c)}" title="${escapeHtml(c)}"></span>`)
      .join("");
    const hexLine = colors.join(" ");
    const card = document.createElement("div");
    card.className = "ai-palette-card";
    card.innerHTML = `
      <div class="ai-palette-head">
        <strong>${escapeHtml(p.name || p.id)}</strong>
        <code>${escapeHtml(p.id)}</code>
        <span class="ai-score">${escapeHtml(p.score ?? "")}</span>
      </div>
      <div class="ai-swatch-row">${swatches}</div>
      <p class="ai-rec-reason">${escapeHtml(p.reason || (p.research_uses || []).slice(0, 2).join(" · ") || "")}</p>
      <div class="ai-rec-actions">
        <button type="button" class="secondary compact-action" data-copy-hex="${escapeHtml(hexLine)}">Copy HEX</button>
        ${p.source_url ? `<a class="secondary compact-action" href="${escapeHtml(p.source_url)}" target="_blank" rel="noopener">Source</a>` : ""}
      </div>
    `;
    list.appendChild(card);
  });
  list.querySelectorAll("[data-copy-hex]").forEach((btn) => {
    btn.onclick = async () => {
      try {
        await navigator.clipboard.writeText(btn.dataset.copyHex || "");
        btn.textContent = "Copied";
        setTimeout(() => { btn.textContent = "Copy HEX"; }, 1200);
      } catch {
        btn.textContent = "Copy failed";
      }
    };
  });
}

function applyAiSessionResult(result, { withFigures = false } = {}) {
  aiState.sessionId = result.session_id || aiState.sessionId;
  renderAiIntent(result.intent);
  renderAiProfile(result.profile);
  renderAiSkills(result.skills || []);
  renderAiRecommendations(result.recommendations || []);
  renderAiPalettes(result.palette_recommendations || []);
  if (withFigures) {
    renderAiFigures(result.figures || []);
  }
}

async function runAiRecommend() {
  const revision = aiState.revision;
  const fileInput = $("aiFileInput");
  const file = fileInput?.files?.[0] || aiState.file;
  if (!file) {
    aiAppendChat("Please choose a CSV, TSV or XLSX table first.", "bot");
    return;
  }
  aiState.file = file;
  const goal = $("aiGoalInput")?.value || "";
  const btn = $("aiRecommendBtn");
  const pipeBtn = $("aiPipelineBtn");
  setAiBusy(true);
  if ($("aiDemoStatus")) $("aiDemoStatus").textContent = "Profiling table + ranking plots…";
  aiAppendChat(`Recommend only · ${file.name}${goal ? `; goal: ${goal}` : ""}`, "user");
  try {
    const form = new FormData();
    form.append("file", file);
    form.append("goal", goal);
    form.append("top_k", "3");
    const result = await api("/api/ai/recommend", { method: "POST", body: form });
    if (revision !== aiState.revision) return;
    renderAiFigures([]);
    applyAiSessionResult(result, { withFigures: false });
    const engine = result.engine || "rules";
    const intentLine = result.intent?.summary ? `\nIntent: ${result.intent.summary}` : "";
    const skillLine = (result.skills || []).length
      ? `\nSkills: ${(result.skills || []).map((s) => s.skill_id).join(", ")}`
      : "";
    const pals = (result.palette_recommendations || []).map((p) => p.name || p.id).slice(0, 3).join(", ");
    aiAppendChat(
      `Engine: ${engine}. Ranked: ${(result.recommendations || []).map((r) => r.plugin_id).join(", ") || "none"}.` +
        intentLine +
        skillLine +
        (pals ? `\nPalettes: ${pals}.` : "") +
        (result.message ? `\n${result.message}` : ""),
      "bot"
    );
    if ($("aiDemoStatus")) {
      $("aiDemoStatus").textContent =
        "Recommendations ready. Use “Run top 3 & explain” to render demos, or generate one demo from a card.";
    }
  } catch (err) {
    if (revision !== aiState.revision) return;
    aiAppendChat(`Analysis failed: ${err.message}`, "bot");
    if ($("aiDemoStatus")) $("aiDemoStatus").textContent = `Failed: ${err.message}`;
  } finally {
    setAiBusy(false);
  }
}

async function runAiPipeline() {
  const revision = aiState.revision;
  const fileInput = $("aiFileInput");
  const file = fileInput?.files?.[0] || aiState.file;
  const goal = $("aiGoalInput")?.value || "";
  const btn = $("aiPipelineBtn");
  const recBtn = $("aiRecommendBtn");

  // Prefer reusing session if we already recommended; else need a file
  const hasSession = Boolean(aiState.sessionId);
  if (!file && !hasSession) {
    aiAppendChat("Please choose a CSV, TSV or XLSX table first.", "bot");
    return;
  }

  setAiBusy(true);
  if ($("aiDemoStatus")) {
    $("aiDemoStatus").textContent =
      "Preparing full-data plot drafts and rendering compatible matches…";
  }
  if ($("aiFiguresGrid")) {
    $("aiFiguresGrid").innerHTML = `<div class="ai-empty">Rendering top 3 demos…</div>`;
  }
  aiAppendChat(
    `Run top 3 & explain${file ? ` · ${file.name}` : ""}${goal ? `; goal: ${goal}` : ""}`,
    "user"
  );

  try {
    let result;
    if (file) {
      const form = new FormData();
      form.append("file", file);
      form.append("goal", goal);
      form.append("top_k", "3");
      form.append("auto_render", "true");
      result = await api("/api/ai/pipeline", { method: "POST", body: form });
    } else {
      result = await api("/api/ai/pipeline", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          session_id: aiState.sessionId,
          goal,
          top_k: 3,
          auto_render: true,
        }),
      });
    }
    if (revision !== aiState.revision) return;
    applyAiSessionResult(result, { withFigures: true });
    const figs = result.figures || [];
    const okN = figs.filter((f) => f.status === "completed").length;
    const engine = result.engine || "rules";
    aiAppendChat(
      `Pipeline done (${engine}). Intent + skills matched. Rendered ${okN}/${figs.length} figures with explanations.` +
        (result.message ? `\n${result.message}` : ""),
      "bot"
    );
    if ($("aiDemoStatus")) {
      $("aiDemoStatus").textContent =
        `Pipeline complete · engine=${engine} · ${okN}/${figs.length} demos OK`;
    }
  } catch (err) {
    if (revision !== aiState.revision) return;
    aiAppendChat(`Pipeline failed: ${err.message}`, "bot");
    if ($("aiDemoStatus")) $("aiDemoStatus").textContent = `Failed: ${err.message}`;
    if ($("aiFiguresGrid")) {
      $("aiFiguresGrid").innerHTML = `<div class="ai-empty">Pipeline failed: ${escapeHtml(err.message)}</div>`;
    }
  } finally {
    setAiBusy(false);
  }
}

async function runAiBuildDemo(pluginId, preferBuiltin, customParams = null) {
  const revision = aiState.revision;
  if (!aiState.sessionId) {
    aiAppendChat("Please run “Recommend only” or “Run top 3 & explain” first.", "bot");
    return;
  }
  if (!pluginId) return;
  setAiBusy(true);
  if ($("aiDemoStatus")) $("aiDemoStatus").textContent = `Generating and rendering demo for ${pluginId}…`;
  aiAppendChat(
    `Generate demo: ${pluginId}${preferBuiltin ? " (built-in sample data)" : " (adapt your data)"}`,
    "user"
  );
  try {
    const result = await api("/api/ai/build-demo", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        session_id: aiState.sessionId,
        plugin_id: pluginId,
        prefer_builtin_demo: Boolean(preferBuiltin),
        params: customParams || undefined,
      }),
    });
    if (revision !== aiState.revision) return;
    aiState.lastJob = result;
    const ok = result.status === "completed";
    const note = result.ai?.note || result.message || "";

    // Explain this single figure
    let explanation = "";
    let explanationSource = "rules";
    try {
      const exp = await api("/api/ai/explain", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          session_id: aiState.sessionId,
          plugin_id: pluginId,
          status: result.status,
          mode: result.ai?.mode || "",
          figure_meta: result.figure_meta || {},
        }),
      });
      explanation = exp.explanation || "";
      explanationSource = exp.source || "rules";
    } catch (_) {
      /* optional */
    }

    if (revision !== aiState.revision) return;
    const fig = {
      rank: 1,
      plugin_id: pluginId,
      name: aiState.recommendations.find((rec) => rec.plugin_id === pluginId)?.name || pluginId,
      reason: note,
      status: result.status,
      outputs: result.outputs,
      preview: result.outputs?.preview,
      editor_url: result.editor_url,
      ai: result.ai,
      explanation,
      explanation_source: explanationSource,
      job_id: result.job_id,
      error: result.error,
    };
    renderAiFigures([fig]);

    if ($("aiDemoStatus")) {
      $("aiDemoStatus").textContent = ok
        ? `Done · ${pluginId} · mode=${result.ai?.mode || "?"}`
        : `Failed · ${result.status}: ${(result.error && (result.error.detail || result.error.error)) || result.message || ""}`;
    }
    aiAppendChat(
      ok
        ? `Demo succeeded (${result.ai?.mode || "run"}). ${note}${explanation ? `\n\nExplanation: ${explanation}` : ""}`
        : `Demo failed: ${(result.error && (result.error.detail || result.error.error)) || result.message || result.status}`,
      "bot"
    );
    if (ok && result.outputs && typeof renderDownloads === "function") {
      try {
        renderDownloads(result.outputs);
      } catch (_) {}
    }
  } catch (err) {
    if (revision !== aiState.revision) return;
    if ($("aiDemoStatus")) $("aiDemoStatus").textContent = `Failed: ${err.message}`;
    aiAppendChat(`Generation failed: ${err.message}`, "bot");
  } finally {
    setAiBusy(false);
  }
}

async function runAiChat() {
  const revision = aiState.revision;
  const input = $("aiChatInput");
  const message = (input?.value || "").trim();
  if (!message) return;
  if (input) input.value = "";
  aiAppendChat(message, "user");
  try {
    const result = await api("/api/ai/chat", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ message, session_id: aiState.sessionId, plugin_id: aiState.lastJob?.plugin_id }),
    });
    if (revision !== aiState.revision) return;
    aiAppendChat(result.reply || "(empty reply)", "bot");
    if (result.render_action) {
      const action = result.render_action;
      const button = document.createElement("button");
      button.type = "button";
      button.className = "primary compact-action";
      button.textContent = "Apply & render";
      button.onclick = () => {
        if (revision !== aiState.revision) return;
        button.disabled = true;
        runAiBuildDemo(action.plugin_id, false, { ...(aiState.lastJob?.params_used || {}), ...action.params });
      };
      $("aiChatLog")?.appendChild(button);
    }
  } catch (err) {
    if (revision !== aiState.revision) return;
    aiAppendChat(`Chat failed: ${err.message}`, "bot");
  }
}

function wireAiStudio() {
  const fileInput = $("aiFileInput");
  if (fileInput) {
    fileInput.onchange = () => {
      const f = fileInput.files?.[0];
      aiState.file = f || null;
      invalidateAiSession();
      const label = $("aiFileLabel");
      if (label) label.textContent = f ? f.name : "Choose CSV / TSV / XLSX";
    };
  }
  if ($("aiGoalInput")) $("aiGoalInput").oninput = invalidateAiSession;
  if ($("aiRecommendBtn")) $("aiRecommendBtn").onclick = runAiRecommend;
  if ($("aiPipelineBtn")) $("aiPipelineBtn").onclick = runAiPipeline;
  if ($("aiChatSend")) $("aiChatSend").onclick = runAiChat;
  if ($("aiChatInput")) {
    $("aiChatInput").addEventListener("keydown", (e) => {
      if (e.key === "Enter") {
        e.preventDefault();
        runAiChat();
      }
    });
  }
  refreshAiStatus();
}

async function init() {
  try {
    const health = await api("/api/health");
    $("health").textContent = `${health.status} · ${health.dispatch_mode}`;
  } catch {
    $("health").textContent = "Backend unavailable";
  }
  const [plugins, tree] = await Promise.all([api("/api/plugins"), api("/api/plugins/tree")]);
  state.plugins = plugins.plugins || [];
  state.tree = tree.categories || [];
  renderCategoryChips();
  renderPluginTree();
  renderHome();
  wireAiStudio();
  if (typeof initDiscovery === "function") {
    await initDiscovery();
  } else {
    renderPlotCards();
  }
  if ($("pluginSearch") && !$("discoveryRoot")) {
    $("pluginSearch").oninput = renderPluginTree;
    $("pluginSearch").addEventListener("input", renderPlotCards);
  }
  $("runButton").onclick = runSelectedPlugin;
  $("uploadDatasetButton").onclick = uploadDataset;
  $("refreshResultsButton").onclick = refreshResults;
  $("createReportButton").onclick = createReport;

  $("saveStateButton").onclick = async () => {
    await api("/api/state/save", { method: "POST", body: JSON.stringify(state.serverState || {}), headers: { "Content-Type": "application/json" } });
    $("statusText").textContent = "State saved successfully.";
  };
  $("loadStateButton").onclick = async () => {
    await refreshState();
    $("statusText").textContent = "State loaded successfully.";
  };
  const sidebar = $("mainSidebar");
  const toggleBtn = $("sidebarToggle");
  const layout = document.querySelector(".layout");

  if (toggleBtn && sidebar && layout) {
    toggleBtn.onclick = () => {
      sidebar.classList.toggle("collapsed");
      layout.classList.toggle("sidebar-collapsed");
      toggleBtn.textContent = sidebar.classList.contains("collapsed") ? "›" : "‹";
    };
  }

  document.querySelectorAll(".filter-pill").forEach((btn) => {
    btn.onclick = () => {
      document.querySelectorAll(".filter-pill").forEach((b) => b.classList.remove("active"));
      btn.classList.add("active");
      renderPlotCards();
    };
  });

  document.querySelectorAll(".nav-item").forEach((button) => {
    button.onclick = () => setMode(button.dataset.mode);
  });
  document.querySelectorAll(".top-link").forEach((button) => {
    button.onclick = () => setMode(button.dataset.mode);
  });
  document.querySelectorAll("[data-mode]").forEach((button) => {
    if (!button.classList.contains("nav-item") && !button.classList.contains("top-link")) button.onclick = () => setMode(button.dataset.mode);
  });
  $("menuToggle")?.addEventListener("click", () => $("menuToggle").closest(".topbar")?.nextElementSibling?.querySelector(".sidebar")?.classList.toggle("open"));
  wireStudioActions();
  await refreshResults();
  await refreshState();
  await refreshDatasets();
  await refreshReports();
  setMode(state.mode);
  $("paramsText").addEventListener("blur", () => {
    try {
      state.params = JSON.parse($("paramsText").value || "{}");
      renderActiveControls();
      triggerAutoUpdate(100);
    } catch (error) {
      $("jobStatus").textContent = `Advanced JSON error: ${error.message}`;
    }
  });
}

init().catch((error) => {
  $("health").textContent = error.message;
});
