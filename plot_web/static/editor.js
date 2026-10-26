const $ = (id) => document.getElementById(id);

const urlParams = new URLSearchParams(window.location.search);
const PLUGIN_ID = urlParams.get("plugin") || "group_heatmap";
const SAVED_JOB = urlParams.get("job") || "";
const STUDIO_VARIANT = urlParams.get("variant") || "";
const STUDIO_EXAMPLE = urlParams.get("example") || "";
const SOURCE_CONTEXT = urlParams.get("source_context") || "";
const SOURCE_TASK = urlParams.get("source_task") || "";

const state = {
  pluginId: PLUGIN_ID,
  detail: null,
  demo: null,
  examples: [],
  selectedExampleId: null,
  params: {},
  schemaSections: [],
  selectedColumns: new Set(),
  selectedRows: new Set(),
  pointPickMode: "highlight",
  rowMode: "include",
  inputPreview: null,
  activeSection: "basic",
  zoom: 1,
  autoUpdateEnabled: true,
  autoUpdateTimer: null,
  isUpdating: false,
  lastOutputs: {},
  preferHtmlPreview: false,
  userTouchedParams: false,
  previewSearch: "",
  previewPage: 0,
  customFiles: {},
  uploadVersion: 0,
  isUploading: false,
  isLoadingPreset: false,
  revision: 0,
  renderedRevision: -1,
  pendingRender: false,
  invalidFields: new Map(),
  parameterSearch: "",
  previewRevision: -1,
  renderChannel: `editor-${Date.now()}-${Math.random().toString(36).slice(2)}`,
};

const SCIENTIFIC_PALETTES = {
  npg: ["#E64B35", "#4DBBD5", "#00A087", "#3C5488", "#F39B7F", "#8491B4", "#91D1C2", "#DC0000"],
  aaas: ["#3B4992", "#EE0000", "#008B45", "#631879", "#008280", "#BB0021", "#5F559B", "#A20056"],
  nejm: ["#BC3C29", "#0072B5", "#E18727", "#20854E", "#7876B1", "#6F99AD", "#FFDC91", "#EE4C97"],
  lancet: ["#00468B", "#ED0000", "#42B540", "#0099B4", "#925E9F", "#FDAF91", "#AD002A", "#ADB6B6"],
  jama: ["#374E55", "#DF8F44", "#00A1D5", "#B24745", "#79AF97", "#6A6599", "#80796B"],
  jco: ["#0073C2", "#EFC000", "#868686", "#CD534C", "#7AA6DC", "#003C67", "#8F7700", "#3B3B3B"],
  viridis: ["#440154", "#482677", "#3E4989", "#31688E", "#26828E", "#1F9E89", "#35B779", "#6ECE58"],
  plasma: ["#0D0887", "#46039F", "#7201A8", "#9C179E", "#BD3786", "#D8576B", "#ED7953", "#FB9F3A"],
  coolwarm: ["#3B4CC0", "#6788EE", "#9ABBFF", "#C9D7F0", "#EDD1C2", "#F7A789", "#E26952", "#B40426"],
  spectral: ["#9E0142", "#D53E4F", "#F46D43", "#FDAE61", "#FEE08B", "#E6F598", "#ABDDA4", "#66C2A5"]
};

/** Theme panel state (loaded from /api/palettes) */
const themeState = {
  loaded: false,
  meta: null,
  journals: [],
  palettes: [],
  filterCatalog: "all",
  filterFamily: "all",
  search: "",
  journalQuery: "",
  recommendations: [],
  activeId: null,
  status: "",
};

async function api(path, options = {}) {
  const response = await fetch(path, options);
  if (!response.ok) {
    const errorText = await response.text();
    let message = errorText;
    try {
      const errJson = JSON.parse(errorText);
      message = errJson.detail || errJson.error || errorText;
    } catch (e) {}
    throw new Error(message);
  }
  return response.json();
}

function triggerAutoUpdate(delayMs = 300) {
  state.userTouchedParams = true;
  markFigureDirty();
  if (!state.autoUpdateEnabled) return;
  if (state.autoUpdateTimer) clearTimeout(state.autoUpdateTimer);
  state.autoUpdateTimer = setTimeout(() => {
    runDemoSilent();
  }, delayMs);
}

function setEditorStatus(message) {
  if ($("editorStateText")) $("editorStateText").textContent = message;
  if ($("readyDot")) $("readyDot").classList.toggle("is-pending", message !== "Synced");
}

function markFigureDirty() {
  state.revision += 1;
  setEditorStatus("Unapplied changes");
  if ($("validationPanel")) $("validationPanel").hidden = true;
  // Keep the last successful image visible, but never export it as the current version.
  renderDownloads(state.lastOutputs);
}

function inputDefinitions() {
  const inputs = (state.detail?.inputs || []).filter((item) => item.id);
  return inputs.length ? inputs : [{ id: "input", required: true, type: "table" }];
}

function missingUserInputs() {
  return inputDefinitions().filter((item) => item.required && !state.customFiles[item.id]);
}

function renderDataSource() {
  const box = $("dataSource");
  if (!box) return;
  const names = Object.values(state.customFiles).map((file) => file.name);
  const files = state.inputPreview?.files || {};
  const first = files.file || files.input || Object.values(files)[0];
  box.textContent = state.isUploading ? "Checking selected files…"
    : names.length ? `Your data: ${names.join(" · ")}`
    : `Example data${state.selectedExampleId ? `: ${state.selectedExampleId}` : ""}${first?.filename ? ` · ${first.filename}` : ""}`;
  if (first?.row_count_estimate !== undefined) box.textContent += ` · ${first.row_count_estimate} rows × ${first.columns?.length || 0} columns`;
  box.dataset.source = names.length ? "user" : "example";
}

async function loadUserFile(field, file) {
  if (!file) return;
  const version = ++state.uploadVersion;
  state.isUploading = true;
  markFigureDirty();
  renderDataSource();
  document.querySelectorAll('.dataset-input input[type="file"]').forEach((input) => { input.disabled = true; });
  const candidate = { ...state.customFiles, [field]: file };
  const form = new FormData();
  Object.entries(candidate).forEach(([key, value]) => form.append(key, value));
  try {
    const preview = await api(`/api/plugins/${state.pluginId}/preview-input`, { method: "POST", body: form });
    if (version !== state.uploadVersion) return;
    const errors = Object.entries(preview.files || {}).flatMap(([key, item]) => {
      const definition = inputDefinitions().find((input) => input.id === key);
      if (definition?.type === "file") return [];
      if (item.error) return [item];
      return !item.columns?.length || !item.row_count_estimate
        ? [{ filename: item.filename, error: "The table needs column headers and at least one data row." }] : [];
    });
    if (errors.length || !Object.keys(preview.files || {}).length) {
      throw new Error(errors.map((item) => `${item.filename}: ${item.error}`).join("; ") || "No readable input files.");
    }
    state.customFiles = candidate;
    state.userTouchedParams = true;
    state.inputPreview = preview;
    state.selectedRows = new Set();
    state.selectedColumns = new Set();
    ["rows_include", "rows_exclude", "selected_ids", "groups_include", "groups_exclude"].forEach((key) => delete state.params[key]);
    if (typeof reconcileMappingsWithDataset === "function") reconcileMappingsWithDataset();
    if (typeof applySuggestionsIfEmpty === "function") applySuggestionsIfEmpty();
    syncJsonFromParams();
    $("jobStatus").textContent = "Your data loaded. Check column mappings before plotting.";
  } catch (err) {
    if (version !== state.uploadVersion) return;
    $("jobStatus").textContent = `File was not loaded: ${err.message}. Previous data is still selected.`;
    setEditorStatus("Upload failed");
  } finally {
    if (version === state.uploadVersion) {
      state.isUploading = false;
      renderDataSource();
      renderParamContentArea();
      renderStageDataDrawer();
    }
  }
}

async function requestFigure() {
  const params = sanitizeParamsForRun(state.params);
  if (Object.keys(state.customFiles).length) {
    const missing = missingUserInputs();
    if (missing.length) throw new Error(`Upload required data: ${missing.map((item) => item.id).join(", ")}.`);
    const form = new FormData();
    Object.entries(state.customFiles).forEach(([field, file]) => form.append(field, file));
    form.append("params", JSON.stringify(params));
    form.append("background", "1");
    form.append("render_channel", state.renderChannel);
    return api(`/api/plugins/${state.pluginId}/run`, { method: "POST", body: form });
  }
  const payload = { params, background: true, render_channel: state.renderChannel };
  if (state.selectedExampleId) payload.example_id = state.selectedExampleId;
  return api(`/api/plugins/${state.pluginId}/run-demo`, {
    method: "POST", body: JSON.stringify(payload), headers: { "Content-Type": "application/json" },
  });
}

async function waitForRender(result, revision) {
  let preview = "";
  const deadline = Date.now() + 20 * 60 * 1000;
  while (["queued", "running"].includes(result.status) && result.poll_url) {
    if (revision !== state.revision) return result;
    if (Date.now() > deadline) throw new Error("Rendering is taking too long. Check Runs for the job status.");
    const pollUrl = result.poll_url;
    const next = await api(pollUrl);
    result = { ...next, poll_url: pollUrl };
    if (revision !== state.revision) return result;
    if (result.live_preview && result.live_preview !== preview) {
      preview = result.live_preview;
      updatePreviewImage(preview);
      state.previewRevision = revision;
      renderDownloads(state.lastOutputs);
      // Keep the render lock until exports finish; only hide the visual overlay.
      $("stageOverlay")?.classList.add("hidden");
      setEditorStatus("Preview ready");
      $("jobStatus").textContent = "Preview ready. Preparing export files in the background…";
    } else if (!preview && result.status === "queued") {
      $("jobStatus").textContent = "Waiting for a render worker…";
    }
    if (["queued", "running"].includes(result.status)) await new Promise((resolve) => setTimeout(resolve, 250));
  }
  return result;
}

function numericValidationErrors() {
  const controls = new Map();
  ["theme", "axes", "title", "legend", "canvas"].forEach((tab) =>
    mergeCommonWithSchema(tab).forEach((control) => controls.set(control.key, control)));
  allSchemaControls().forEach((control) => controls.set(control.key, control));
  const errors = [];
  controls.forEach((control) => {
    if (!["number", "integer"].includes(control.type)) return;
    const raw = state.params[control.key];
    if (raw === undefined || raw === null || raw === "") return;
    const value = typeof raw === "number" || typeof raw === "string" ? Number(raw) : NaN;
    const bounds = numberFieldMeta(control.key.toLowerCase(), control);
    if (!Number.isFinite(value) || (control.type === "integer" && !Number.isInteger(value))
      || (bounds.min !== undefined && value < bounds.min) || (bounds.max !== undefined && value > bounds.max)) {
      errors.push(`${control.label}: use ${control.type === "integer" ? "a whole number" : "a number"}${bounds.min !== undefined ? ` ≥ ${bounds.min}` : ""}${bounds.max !== undefined ? ` and ≤ ${bounds.max}` : ""}`);
    }
  });
  return errors;
}

function setStageOverlay(loading) {
  const overlay = $("stageOverlay");
  if (!overlay) return;
  if (loading) {
    overlay.classList.remove("hidden");
    state.isUpdating = true;
  } else {
    overlay.classList.add("hidden");
    state.isUpdating = false;
  }
}

async function runDemoSilent() {
  if (!state.pluginId) return;
  if (state.isUpdating) {
    state.pendingRender = true;
    return;
  }
  if (state.isUploading || state.isLoadingPreset) return;
  const numericErrors = numericValidationErrors();
  if (state.invalidFields.size || numericErrors.length) {
    setEditorStatus("Check settings");
    $("jobStatus").textContent = `Fix invalid settings: ${[...state.invalidFields.values()].map((item) => item.message).concat(numericErrors).join("; ")}`;
    return;
  }
  clearTimeout(state.autoUpdateTimer);
  state.pendingRender = false;
  const revision = state.revision;
  setStageOverlay(true);
  if (state.previewRevision === revision) $("stageOverlay")?.classList.add("hidden");
  setEditorStatus(state.previewRevision === revision ? "Preparing exports…" : "Updating…");
  renderDownloads(state.lastOutputs);
  try {
    let result = await requestFigure();
    result = await waitForRender(result, revision);
    if (revision !== state.revision) return;
    renderValidation(result.vnext);
    if (result.status === "completed" && result.outputs) {
      state.renderedRevision = revision;
      state.previewRevision = revision;
      renderDownloads(result.outputs);
      if (result.outputs.preview) {
        await updateInstantPreview(result.outputs);
      }
      if (revision !== state.revision) return;
      $("jobStatus").textContent = result.cache?.hit ? "Figure ready — reused identical data and settings." : `Updated figure (${new Date().toLocaleTimeString()})`;
      setEditorStatus("Synced");
    } else {
      const errObj = result.error && typeof result.error === "object" ? result.error : null;
      const detail =
        (errObj && (errObj.detail || errObj.error)) ||
        result.detail ||
        (typeof result.error === "string" ? result.error : null) ||
        result.message ||
        result.status ||
        "unknown error";
      $("jobStatus").textContent = `Could not render: ${errObj?.error || detail}${errObj?.suggestion ? ` ${errObj.suggestion}` : ""}`;
      setEditorStatus("Render failed");
    }
  } catch (err) {
    if (revision === state.revision) {
      $("jobStatus").textContent = `Could not render: ${err.message}`;
      setEditorStatus("Render failed");
    }
  } finally {
    setStageOverlay(false);
    if (revision !== state.revision && !state.pendingRender && !state.invalidFields.size) setEditorStatus("Unapplied changes");
    renderDownloads(state.lastOutputs);
    if (state.pendingRender) {
      state.pendingRender = false;
      await runDemoSilent();
    }
  }
}

function hideHtmlPreview() {
  const frame = $("htmlPreview");
  if (frame) {
    frame.classList.add("hidden");
    frame.removeAttribute("src");
  }
}

function syncInteractiveToggle(hasHtml, showingHtml) {
  const btn = $("toggleInteractiveBtn");
  if (!btn) return;
  btn.classList.toggle("hidden", !hasHtml);
  if (!hasHtml) return;
  btn.textContent = showingHtml ? "PNG" : "Live";
  btn.title = showingHtml ? "Show static figure" : "Interactive view: drag nodes";
}

function updateHtmlPreview(path) {
  const frame = $("htmlPreview");
  const img = $("preview");
  const plotlyBox = $("plotlyPreview");
  const empty = $("emptyCanvas");
  if (!frame || !path) return false;
  if (plotlyBox) {
    plotlyBox.classList.add("hidden");
    try { if (window.Plotly) Plotly.purge(plotlyBox); } catch {}
  }
  if (img) img.style.display = "none";
  const sep = path.includes("?") ? "&" : "?";
  frame.src = path.startsWith("/") ? `${path}${sep}t=${Date.now()}` : path;
  frame.classList.remove("hidden");
  if (empty) empty.style.display = "none";
  return true;
}

function updatePreviewImage(path) {
  const img = $("preview");
  const plotlyBox = $("plotlyPreview");
  const empty = $("emptyCanvas");
  hideHtmlPreview();
  if (!img || !path) return;
  if (plotlyBox) {
    plotlyBox.classList.add("hidden");
    try { if (window.Plotly) Plotly.purge(plotlyBox); } catch {}
  }
  const sep = path.includes("?") ? "&" : "?";
  if (path.startsWith("/")) {
    img.src = `${path}${sep}t=${Date.now()}`;
  } else {
    img.src = `/api/results/file?path=${encodeURIComponent(path)}&t=${Date.now()}`;
  }
  img.style.display = "block";
  if (empty) empty.style.display = "none";
}

async function updateInstantPreview(outputs = {}, revision = state.revision) {
  const hasHtml = Boolean(outputs.html);
  const showHtml = hasHtml && state.preferHtmlPreview;
  syncInteractiveToggle(hasHtml, showHtml);
  if (showHtml) {
    updateHtmlPreview(outputs.html);
    return;
  }
  hideHtmlPreview();
  const rendered = await renderPlotlyPreview(outputs, revision);
  if (revision !== state.revision) return;
  if (!rendered && outputs.preview) updatePreviewImage(outputs.preview);
}

async function renderPlotlyPreview(outputs = {}, revision = state.revision) {
  const plotlyBox = $("plotlyPreview");
  const img = $("preview");
  const empty = $("emptyCanvas");
  if (!plotlyBox || !outputs.json) return false;
  try {
    const sep = outputs.json.includes("?") ? "&" : "?";
    const figure = await api(`${outputs.json}${sep}t=${Date.now()}`);
    const spec = figure?.plotly;
    if (!spec?.data?.length) return false;
    if (typeof ensurePlotly === "function" && !(await ensurePlotly())) return false;
    if (revision !== state.revision) return false;
    if (img) img.style.display = "none";
    plotlyBox.classList.remove("hidden");
    await Plotly.react(plotlyBox, spec.data, spec.layout || {}, {
      responsive: true,
      displaylogo: false,
      modeBarButtonsToAdd: ["select2d", "lasso2d"],
      scrollZoom: true,
    });
    wirePlotlyPointSelection(plotlyBox);
    if (empty) empty.style.display = "none";
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
  renderStageDataDrawer();
  triggerAutoUpdate(80);
}

function wirePlotlyPointSelection(plotlyBox) {
  plotlyBox.removeAllListeners?.("plotly_click");
  plotlyBox.removeAllListeners?.("plotly_selected");
  plotlyBox.on?.("plotly_click", (event) => applyPointSelection(selectedIdsFromPlotlyEvent(event), false));
  plotlyBox.on?.("plotly_selected", (event) => applyPointSelection(selectedIdsFromPlotlyEvent(event), true));
}

function setPreviewVisible(visible, mode = "image") {
  const img = $("preview");
  const plotlyBox = $("plotlyPreview");
  const empty = $("emptyCanvas");
  const frame = $("htmlPreview");
  if (visible) {
    img.style.display = mode === "plotly" || mode === "html" ? "none" : "block";
    if (plotlyBox) plotlyBox.classList.toggle("hidden", mode !== "plotly");
    if (frame) frame.classList.toggle("hidden", mode !== "html");
    if (empty) empty.style.display = "none";
  } else {
    img.style.display = "none";
    if (plotlyBox) plotlyBox.classList.add("hidden");
    if (frame) frame.classList.add("hidden");
    if (empty) empty.style.display = "flex";
  }
}

/** Normalize job.outputs into { svg, pdf, png, tiff, ... } absolute paths. */
function normalizeOutputMap(outputs = {}) {
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
    // Prefer known format keys from API (svg/pdf/png)
    const fmt = ["svg", "pdf", "png", "tiff", "tif", "json", "log"].includes(keyLower)
      ? keyLower
      : ext;
    map[fmt] = { url, key: keyLower, filename: tail.includes(".") ? tail : `figure.${fmt === "tif" ? "tiff" : fmt}` };
    if (fmt === "tif") map.tiff = map[fmt];
    if (fmt === "tiff") map.tif = map[fmt];
  });
  return map;
}

const EXPORT_LABELS = { plotspec: "PlotSpec (JSON)", bundle: "Reproduction bundle (ZIP)" };
const EXPORT_FILENAMES = { plotspec: "plotspec.json", bundle: "reproduction_bundle.zip" };
const IMPORT_STORAGE_KEY = "omicscanvas.importedPlotSpec";

/** Scientific validation result returned with every run (PlotSpec layer). */
function renderValidation(vnext) {
  renderValidationPanel($("validationPanel"), vnext);
}

/** Load a PlotSpec file: convert to params, then apply here or open the right plot's Studio. */
async function importPlotSpecFile(file) {
  let spec;
  try {
    spec = JSON.parse(await file.text());
  } catch (err) {
    $("jobStatus").textContent = `Import failed: ${file.name} is not JSON.`;
    return;
  }
  try {
    const result = await api("/api/vnext/plotspec/to-params", {
      method: "POST",
      body: JSON.stringify({ plotspec: spec }),
      headers: { "Content-Type": "application/json" },
    });
    if (result.plugin_id !== state.pluginId) {
      sessionStorage.setItem(IMPORT_STORAGE_KEY, JSON.stringify({ plugin_id: result.plugin_id, params: result.params }));
      window.location.href = `/static/editor.html?plugin=${encodeURIComponent(result.plugin_id)}`;
      return;
    }
    applyImportedParams(result.params, result.unsupported_roles);
    await runDemo({ reloadDemo: false });
  } catch (err) {
    $("jobStatus").textContent = `Import failed: ${err.message}`;
  }
}

function applyImportedParams(params, unsupported = []) {
  state.invalidFields.clear();
  state.params = { ...params };
  state.userTouchedParams = true;
  markFigureDirty();
  syncJsonFromParams();
  renderParamContentArea();
  const extra = unsupported && unsupported.length ? ` Ignored roles: ${unsupported.join(", ")}.` : "";
  $("jobStatus").textContent = `Settings restored from PlotSpec. Load the matching dataset if it was not the demo data.${extra}`;
}

function wirePlotSpecImport() {
  const btn = $("importPlotSpecBtn");
  const input = $("importPlotSpecInput");
  if (!btn || !input) return;
  btn.onclick = () => input.click();
  input.onchange = () => {
    const file = input.files && input.files[0];
    input.value = "";
    if (file) importPlotSpecFile(file);
  };
}

/** PlotSpec imported on another plot's page, waiting to be applied here. */
function takePendingImport() {
  try {
    const raw = sessionStorage.getItem(IMPORT_STORAGE_KEY);
    if (!raw) return null;
    const pending = JSON.parse(raw);
    if (pending.plugin_id !== state.pluginId) return null;
    sessionStorage.removeItem(IMPORT_STORAGE_KEY);
    return pending.params || null;
  } catch (_) {
    return null;
  }
}

function ensureExportItems(container) {
  if (!container) return [];
  const primaryOrder = [
    { fmt: "svg", label: "SVG" },
    { fmt: "pdf", label: "PDF" },
    { fmt: "png", label: "PNG" },
    { fmt: "html", label: "Interactive HTML" },
    { fmt: "tiff", label: "TIFF" },
    { fmt: "plotspec", label: "PlotSpec (JSON)" },
    { fmt: "bundle", label: "Reproduction bundle (ZIP)" },
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

function renderDownloads(outputs) {
  const container = $("downloadLinks");
  const quickContainer = $("quickDownloads");
  const headerBox = $("headerExportLinks");
  const empty = $("exportMenuEmpty");
  const synced = state.renderedRevision === state.revision && !state.isUpdating && !state.isUploading && !state.isLoadingPreset && !state.invalidFields.size;
  const map = normalizeOutputMap(synced ? (outputs || {}) : {});
  state.lastOutputs = outputs || {};
  const notice = $("figureSyncNotice");
  if (notice) {
    notice.hidden = synced || state.previewRevision < 0 || (state.previewRevision === state.revision && !state.isUpdating);
    notice.textContent = state.previewRevision === state.revision
      ? "Preview ready. Export files are being prepared in the background."
      : "Preview has not applied the latest data and settings. Run Plot to update it.";
  }
  if ($("prepareExportButton")) {
    $("prepareExportButton").hidden = synced;
    $("prepareExportButton").disabled = state.isUpdating || state.isUploading || state.isLoadingPreset;
  }

  // Primary formats live ONLY in the top Export dropdown (+ export tab clone)
  const rows = ensureExportItems(quickContainer);
  let enabledCount = 0;

  rows.forEach((row) => {
    const fmt = (row.dataset.fmt || "").toLowerCase();
    const item = map[fmt] || map[fmt === "tiff" ? "tif" : fmt];
    const label = EXPORT_LABELS[fmt] || (fmt === "tiff" ? "TIFF" : fmt.toUpperCase());
    row.textContent = label;
    if (item && item.url) {
      enabledCount += 1;
      row.className = "export-item is-ready";
      row.href = item.url;
      row.target = "_blank";
      row.rel = "noopener noreferrer";
      if (fmt === "html") {
        row.removeAttribute("download");
        row.title = "Open interactive view";
      } else {
        row.download = EXPORT_FILENAMES[fmt] || item.filename || `figure.${fmt === "tiff" ? "tiff" : fmt}`;
        row.title = `Download ${label}`;
      }
      row.removeAttribute("aria-disabled");
      row.tabIndex = 0;
    } else {
      row.className = "export-item is-disabled";
      row.href = "#";
      row.removeAttribute("download");
      row.removeAttribute("target");
      row.title = "Generate export files or run the plot to enable this download";
      row.setAttribute("aria-disabled", "true");
      row.tabIndex = -1;
    }
  });

  // Mirror ready links into the right-side export tab panel
  if (headerBox) {
    headerBox.innerHTML = "";
    rows.forEach((row) => {
      if (!row.classList.contains("is-ready")) return;
      const clone = row.cloneNode(true);
      clone.classList.remove("export-item");
      headerBox.appendChild(clone);
    });
  }

  // Secondary outputs (json/log/csv) stay under the canvas foot — not figure pics
  if (container) {
    container.innerHTML = "";
    container.hidden = true;
    const secondaryKeys = Object.keys(map).filter(
      (k) => !["svg", "pdf", "png", "tiff", "tif", "plotspec", "bundle"].includes(k)
    );
    if (secondaryKeys.length) {
      container.hidden = false;
      secondaryKeys.forEach((k) => {
        const item = map[k];
        const a = document.createElement("a");
        a.href = item.url;
        a.target = "_blank";
        a.rel = "noopener noreferrer";
        a.textContent = k.replace(/_/g, " ").toUpperCase();
        container.appendChild(a);
      });
    }
  }

  if (empty) {
    const ready = enabledCount > 0;
    empty.classList.toggle("is-hidden", ready);
    empty.hidden = ready;
    empty.textContent = ready
      ? ""
      : state.isUpdating ? "Preparing export files…"
      : state.previewRevision === state.revision ? "Generate export files for this example."
      : state.renderedRevision >= 0 ? "Apply your changes with Run Plot before exporting." : "Run a plot to enable downloads.";
  }
}

function wireExportMenu() {
  const menu = $("exportMenu");
  const btn = $("exportMenuBtn");
  const panel = $("exportMenuPanel");
  if (!btn || !panel || !menu) {
    console.warn("[export] menu elements missing", { menu, btn, panel });
    return;
  }

  // Never use the HTML hidden attribute — it fights CSS and left the panel blank.
  panel.removeAttribute("hidden");

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
      renderDownloads(state.lastOutputs || {});
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
    if (link) {
      // allow navigation, then close
      setTimeout(() => setOpen(false), 80);
    } else if (e.target.closest("a.export-item.is-disabled")) {
      e.preventDefault();
    }
  });

  document.addEventListener("click", (e) => {
    if (!menu.contains(e.target) && !panel.contains(e.target)) setOpen(false);
  });
  window.addEventListener("resize", () => {
    if (menu.classList.contains("is-open")) positionPanel();
  });
  document.addEventListener("keydown", (e) => {
    if (e.key === "Escape") setOpen(false);
  });

  // Seed SVG/PDF/PNG/TIFF rows immediately so the panel is never empty
  renderDownloads(state.lastOutputs || {});
}

function numberFieldMeta(key, control) {
  const fallback = inferredNumberFieldMeta(key, control);
  return { ...fallback, min: control?.min ?? fallback.min, max: control?.max ?? fallback.max,
    step: control?.step ?? fallback.step };
}

function inferredNumberFieldMeta(key, control) {
  const def = control?.default;
  if (key.includes("alpha")) return { min: 0, max: 1, step: 0.05 };
  if (key === "legend_x" || key === "legend_y" || key.includes("legend_just") || key.includes("hjust") || key.includes("vjust")) {
    return { min: 0, max: 1, step: 0.01 };
  }
  if (key === "legend_nrow" || key === "legend_ncol") return { min: 0, max: 40, step: 1 };
  if (key.includes("dpi")) return { min: 72, max: 600, step: 1 };
  if (key === "width" || key === "height") return { min: 0.5, max: 40, step: 0.1 };
  if (key === "mark_expand_mm" || key === "mark_size") return { min: 0, max: 20, step: 0.5 };
  if (/(point_size|dot_size|label_size|mark_.*size|pie_.*size|stat_embedded_size)/.test(key)) {
    return { min: 0, max: 20, step: 0.05 };
  }
  if (key.includes("angle")) return { min: -360, max: 360, step: 1 };
  if (/(line_width|linewidth|border_width|tick_width|grid_width|minor_width)/.test(key)) {
    return { min: 0, max: 8, step: 0.05 };
  }
  if (key.includes("size")) return { min: 0, max: 48, step: 0.5 };
  if (control?.type === "integer") return { min: 0, max: 10000, step: 1 };
  return { min: undefined, max: undefined, step: "any", default: def };
}

function labelize(name) {
  return String(name || "")
    .replace(/_/g, " ")
    .replace(/\b\w/g, (c) => c.toUpperCase());
}

function inferType(key, spec) {
  if (spec && typeof spec === "object" && spec.type) return spec.type;
  const name = key.toLowerCase();
  // Column / field selectors are always strings or multi-select — never booleans
  if (
    name.endsWith("_column") ||
    name.endsWith("_columns") ||
    name.endsWith("_col") ||
    name.includes("column") ||
    name.endsWith("_field") ||
    name === "markers" ||
    name === "features" ||
    name === "genes"
  ) {
    if (name.includes("columns") || name.endsWith("s") && (name.includes("feature") || name.includes("marker") || name.includes("gene"))) {
      return "string_array";
    }
    return "string";
  }
  if (name.includes("color") || name.includes("palette")) return "color";
  // Only treat clear flag-like keys as boolean (avoid matching log2fc, cluster_column, etc.)
  if (
    /(^|_)(show|hide|enable|disable|use|add|draw|fill|scale|log_scale|transpose|check|raster|legend_show|title_show|border)(_|$)/.test(name) ||
    name.startsWith("show_") ||
    name.startsWith("add_") ||
    name.startsWith("use_") ||
    name.endsWith("_show") ||
    name.endsWith("_log")
  ) {
    return "boolean";
  }
  if (name.includes("size") || name.includes("width") || name.includes("height") || name.includes("dpi") || name.includes("angle") || name.includes("alpha") || name.includes("margin") || name.includes("font_size") || name.includes("pad") || name.includes("num") || name.includes("count") || name.includes("level")) return "number";
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
  return labelize(control.section || "Basic Settings");
}

function controlTier(control) {
  const name = control.key.toLowerCase();
  const section = String(control.section || "").toLowerCase();
  if (section.includes("legend")) return "graphic";
  if (section.includes("axis") || section.includes("title") || section.includes("label")) return "typography";
  if (section.includes("export") || section.includes("output") || section.includes("canvas")) return "export";
  if (name.includes("title") || name.includes("font") || name.includes("label") || name.includes("text") || name.startsWith("x") || name.startsWith("y") || name.includes("axis") || name.includes("angle") || name.includes("grid")) return "typography";
  if (name.includes("legend") || name.includes("width") || name.includes("height") || name.includes("dpi") || name.includes("res") || name.includes("unit") || name.includes("format")) return "export";
  if (name.includes("color") || name.includes("palette") || name.includes("size") || name.includes("shape") || name.includes("alpha") || name.includes("dot") || name.includes("point") || name.includes("cell") || name.includes("border")) return "graphic";
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
    legend_position: ["right", "left", "top", "bottom", "none"],
    orientation: ["vertical", "horizontal", "horizontal_blocks"]
  };
  if (map[name]) return map[name];
  if (name.includes("side")) return ["left", "right", "top", "bottom"];
  if (name.includes("method")) return ["pearson", "spearman", "kendall"];
  if (name.includes("shape")) return ["tile", "circle", "point", "diamond", "triangle"];
  if (name.includes("position")) return ["right", "left", "top", "bottom", "none"];
  return [];
}

function defaultValue(key, spec) {
  // Only trust explicit schema defaults. Inferred placeholders (false, [], "")
  // used to override demo params and break runs (e.g. log2fc_column: false).
  if (spec && typeof spec === "object" && Object.prototype.hasOwnProperty.call(spec, "default")) {
    return spec.default;
  }
  return undefined;
}

/** Normalize loose type strings from compact schemas (e.g. "column", "select(a,b)"). */
function parseLooseTypeSpec(raw, key) {
  if (raw && typeof raw === "object" && !Array.isArray(raw)) {
    // JSON-Schema leaf: { type, enum, description, default }
    const out = {
      ...raw,
      options: raw.options || raw.enum || undefined,
      help: raw.help || raw.description || "",
    };
    if (raw.type === "array") out.type = raw.items?.type === "string" ? "string_array" : "string_array";
    if (raw.type === "integer") out.type = "integer";
    if (raw.type === "boolean") out.type = "boolean";
    if (Array.isArray(raw.enum)) {
      out.type = "select";
      out.options = raw.enum;
    }
    return out;
  }
  const text = String(raw || "");
  const selectMatch = text.match(/^select\((.*)\)$/i);
  if (selectMatch) {
    const options = selectMatch[1]
      .split(",")
      .map((s) => s.trim())
      .filter(Boolean);
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
  // free-text help / default description
  if (text.length > 0 && text.length < 120 && !text.includes("\n")) {
    return { help: text, type: inferType(key, {}) };
  }
  return { help: text || labelize(key) };
}

/**
 * Expand heterogeneous plugin schema formats into { section: { key: spec } }.
 * Handles: sectioned maps, groups wrappers, nested JSON-Schema properties.
 */
function expandSchemaSource(schema) {
  const source = schema || {};
  // A) { groups: { data: { key: "column"|spec }, ... }, properties?: {...} }
  if (source.groups && typeof source.groups === "object" && !Array.isArray(source.groups)) {
    const props = source.properties && typeof source.properties === "object" ? source.properties : {};
    const expanded = {};
    Object.entries(source.groups).forEach(([sectionName, keys]) => {
      expanded[sectionName] = {};
      if (Array.isArray(keys)) {
        keys.forEach((key) => {
          const prop = props[key];
          expanded[sectionName][key] = parseLooseTypeSpec(prop !== undefined ? prop : key, key);
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
  // B) Nested JSON-Schema: { type, properties: { data: { type, properties: {...} } } }
  if (source.properties && typeof source.properties === "object") {
    const values = Object.values(source.properties);
    const nested = values.some(
      (v) => v && typeof v === "object" && v.properties && typeof v.properties === "object"
    );
    if (nested) {
      const expanded = {};
      Object.entries(source.properties).forEach(([sectionName, def]) => {
        if (def && typeof def === "object" && def.properties) {
          const leaf = {};
          Object.entries(def.properties).forEach(([k, raw]) => {
            leaf[k] = parseLooseTypeSpec(raw, k);
          });
          expanded[sectionName] = leaf;
        } else {
          expanded[sectionName] = { [sectionName]: parseLooseTypeSpec(def, sectionName) };
        }
      });
      return expanded;
    }
    if (source.type === "object" || source.$schema) {
      const leaf = {};
      Object.entries(source.properties).forEach(([k, raw]) => {
        leaf[k] = parseLooseTypeSpec(raw, k);
      });
      return { Parameters: leaf };
    }
  }
  // C) Already sectioned — still coerce string specs
  const coerced = {};
  Object.entries(source).forEach(([sectionName, entries]) => {
    if (["plugin", "title", "type", "$schema", "groups", "properties", "description"].includes(sectionName)) {
      // skip metadata unless it looks like a real param section
      if (typeof entries !== "object" || Array.isArray(entries)) return;
      if (!Object.values(entries).some((v) => v && (typeof v === "object" || typeof v === "string"))) return;
      // if values are all primitives that aren't type hints, skip
      if (typeof entries !== "object") return;
    }
    if (!entries || typeof entries !== "object" || Array.isArray(entries)) return;
    coerced[sectionName] = {};
    Object.entries(entries).forEach(([key, raw]) => {
      coerced[sectionName][key] = parseLooseTypeSpec(raw, key);
    });
  });
  return Object.keys(coerced).length ? coerced : source;
}

function normalizeSchema(schema) {
  const source = expandSchemaSource(schema);
  const sections = [];
  Object.entries(source).forEach(([sectionName, entries]) => {
    if (!entries || typeof entries !== "object" || Array.isArray(entries)) return;
    // Skip leftover metadata keys from mixed formats
    if (
      ["plugin", "title", "type", "$schema", "groups", "properties", "description"].includes(sectionName) &&
      !Object.values(entries).some((v) => v && typeof v === "object" && (v.type || v.help || v.default !== undefined || v.label))
    ) {
      return;
    }
    const controls = Object.entries(entries).map(([key, raw]) => {
      const spec = raw && typeof raw === "object" && !Array.isArray(raw) ? raw : { help: String(raw || "") };
      return {
        key,
        section: sectionName,
        label: spec.label || labelize(key),
        type: inferType(key, spec),
        default: defaultValue(key, spec),
        help: spec.help || spec.description || "",
        required: Boolean(spec.required),
        min: spec.min ?? spec.minimum,
        max: spec.max ?? spec.maximum,
        step: spec.step,
        options: inferOptions(key, spec),
        group: controlGroup({ key, section: sectionName }),
        tier: controlTier({ key, section: sectionName }),
      };
    });
    if (controls.length) sections.push({ name: sectionName, controls });
  });
  return sections;
}

function applyDefaults() {
  // Start empty — do not inject speculative defaults that can poison demo runs.
  // Explicit schema defaults are applied only when safe (non-empty, non-filter).
  state.params = {};
  state.schemaSections.forEach((section) => {
    section.controls.forEach((control) => {
      const d = control.default;
      if (d === undefined || d === null || d === "") return;
      if (Array.isArray(d) && d.length === 0) return;
      const k = control.key.toLowerCase();
      // Never pre-seed include/exclude/highlight filters — empty means "all" server-side
      if (/(^|_)(include|exclude|highlight|selected)(_|$)/.test(k)) return;
      state.params[control.key] = d;
    });
  });
  syncJsonFromParams();
}

/** Drop unset / poison values before sending params to run-demo / run. */
function sanitizeParamsForRun(params = {}) {
  const out = {};
  Object.entries(params || {}).forEach(([key, value]) => {
    if (value === undefined || value === null) return;
    if (value === "") return;
    if (typeof value === "string" && /^(first column|first col)$/i.test(value.trim())) return;
    const k = key.toLowerCase();
    if (Array.isArray(value) && value.length === 0) {
      // Empty filter arrays mean "select nothing" and break many plugins
      if (/(include|exclude|highlight|selected|rows_|columns_|groups_|features|markers|genes)/.test(k)) return;
      return;
    }
    // Boolean false on column/field selectors is never valid
    if (
      value === false &&
      (k.endsWith("_column") ||
        k.endsWith("_columns") ||
        k.endsWith("_col") ||
        k.includes("column") ||
        k === "markers" ||
        k.endsWith("_field") ||
        k.endsWith("_order"))
    ) {
      return;
    }
    out[key] = value;
  });
  if (out.legend_title && !out.legend_name) out.legend_name = out.legend_title;
  if (out.legend_name && !out.legend_title) out.legend_title = out.legend_name;
  if (out.legend_show === false) out.legend_position = "none";
  if (out.rendering_mode === "raster") out.raster = true;
  if (out.rendering_mode === "vector") out.raster = false;
  return out;
}

function syncParamsFromJson() {
  const el = $("paramsText");
  if (!el) return;
  try {
    const value = JSON.parse(el.value.trim() || "{}");
    if (!value || Array.isArray(value) || typeof value !== "object") throw new Error("Use a JSON object containing parameter names and values.");
    state.params = value;
    state.invalidFields.clear();
    el.removeAttribute("aria-invalid");
    if ($("jsonError")) $("jsonError").textContent = "";
  } catch (err) {
    state.invalidFields.set("__json", { message: `Configuration: ${err.message}`, value: el.value });
    el.setAttribute("aria-invalid", "true");
    if ($("jsonError")) $("jsonError").textContent = err.message;
  }
}

function syncJsonFromParams() {
  const el = $("paramsText");
  if (el) el.value = JSON.stringify(state.params, null, 2);
}

function mergeParams(newParams = {}) {
  state.params = { ...state.params, ...newParams };
  syncJsonFromParams();
}

function extractDemoParams(demo) {
  let raw = demo?.params;
  if (raw && raw.params && typeof raw.params === "object") raw = raw.params;
  return raw && typeof raw === "object" ? { ...raw } : {};
}

function setParamsFromDemo(demo) {
  // Replace (not merge) so schema leftovers cannot poison the demo run
  state.params = extractDemoParams(demo);
  state.selectedColumns = new Set();
  state.selectedRows = new Set();
  delete state.params.rows_include;
  delete state.params.rows_exclude;
  delete state.params.selected_ids;
  delete state.params.selected_genes;
  syncJsonFromParams();
}

/** CSS colour (hex or name such as "white") -> #rrggbb for <input type="color">; null if not a colour. */
function toHexColor(value) {
  if (typeof value !== "string" || !value.trim()) return null;
  if (/^#[0-9a-f]{6}$/i.test(value)) return value;
  const ctx = document.createElement("canvas").getContext("2d");
  ctx.fillStyle = "#000001";
  ctx.fillStyle = value;
  const out = ctx.fillStyle;
  return out === "#000001" && value.toLowerCase() !== "#000001" ? null : /^#[0-9a-f]{6}$/i.test(out) ? out : null;
}

function renderInputForControl(control) {
  const value = state.params[control.key] !== undefined ? state.params[control.key] : control.default;

  if (control.type === "boolean") {
    const label = document.createElement("label");
    label.className = "switch-row";
    label.innerHTML = `
      <input type="checkbox" ${value ? "checked" : ""} />
      <span class="slider"></span>
    `;
    const input = label.querySelector("input");
    input.onchange = () => {
      state.params[control.key] = input.checked;
      if (control.key === "legend_show" && !input.checked) state.params.legend_position = "none";
      if (control.key === "legend_show" && input.checked && state.params.legend_position === "none") {
        state.params.legend_position = "right";
      }
      syncJsonFromParams();
      triggerAutoUpdate(50);
    };
    return label;
  }

  if (["object", "json", "textarea", "array", "string_array", "number_array", "color_array"].includes(control.type)) {
    const wrap = document.createElement("span");
    wrap.className = "structured-field";
    const input = document.createElement("textarea");
    input.rows = 3;
    const structured = control.type !== "textarea";
    input.value = state.invalidFields.get(control.key)?.value ?? (value == null ? "" : structured ? JSON.stringify(value, null, 2) : String(value));
    const error = document.createElement("small");
    error.className = "field-error";
    error.id = `error-${control.key}`;
    error.setAttribute("role", "alert");
    error.textContent = state.invalidFields.get(control.key)?.message || "";
    input.setAttribute("aria-describedby", error.id);
    if (state.invalidFields.has(control.key)) input.setAttribute("aria-invalid", "true");
    input.oninput = () => {
      try {
        let parsed = input.value;
        if (structured) {
          parsed = input.value.trim() ? JSON.parse(input.value) : undefined;
          const array = control.type === "array" || control.type.endsWith("_array");
          if (parsed !== undefined && (array ? !Array.isArray(parsed) : !parsed || Array.isArray(parsed) || typeof parsed !== "object")) {
            throw new Error(array ? "Use a JSON list, for example [1, 2]." : "Use a JSON object with names and values.");
          }
          if (parsed !== undefined && control.type === "number_array" && parsed.some((x) => typeof x !== "number" || !Number.isFinite(x))) throw new Error("Every list item must be a number.");
          if (parsed !== undefined && ["string_array", "color_array"].includes(control.type) && parsed.some((x) => typeof x !== "string")) throw new Error("Every list item must be text.");
        }
        if (parsed === undefined) delete state.params[control.key];
        else state.params[control.key] = parsed;
        state.invalidFields.delete(control.key);
        error.textContent = "";
        input.removeAttribute("aria-invalid");
        syncJsonFromParams();
        triggerAutoUpdate(350);
      } catch (err) {
        const message = `${control.label}: ${err.message}`;
        state.invalidFields.set(control.key, { message, value: input.value });
        input.setAttribute("aria-invalid", "true");
        error.textContent = message;
        markFigureDirty();
        setEditorStatus("Check settings");
      }
    };
    wrap.append(input, error);
    return wrap;
  }

  if (control.key.toLowerCase().includes("palette") && control.type !== "select" && !control.options?.length) {
    const wrap = document.createElement("div");
    wrap.className = "palette-picker-wrap";

    const select = document.createElement("select");
    select.className = "palette-select";
    select.add(new Option("Custom / Array", ""));
    Object.keys(SCIENTIFIC_PALETTES).forEach((name) => {
      select.add(new Option(name.toUpperCase(), name));
    });

    const swatchBox = document.createElement("div");
    swatchBox.className = "palette-swatches";

    const drawSwatches = (colors) => {
      swatchBox.innerHTML = "";
      (colors || []).forEach((c) => {
        const sw = document.createElement("span");
        sw.className = "swatch-color";
        sw.style.backgroundColor = c;
        swatchBox.appendChild(sw);
      });
    };

    if (Array.isArray(value)) drawSwatches(value);

    select.onchange = () => {
      const chosen = select.value;
      if (chosen && SCIENTIFIC_PALETTES[chosen]) {
        state.params[control.key] = SCIENTIFIC_PALETTES[chosen];
        drawSwatches(SCIENTIFIC_PALETTES[chosen]);
        syncJsonFromParams();
        triggerAutoUpdate(50);
      }
    };

    wrap.appendChild(select);
    wrap.appendChild(swatchBox);
    return wrap;
  }

  if (control.type === "select" || (control.options && control.options.length)) {
    const select = document.createElement("select");
    select.add(new Option("-- select --", ""));
    control.options.forEach((opt) => select.add(new Option(String(opt), String(opt))));
    select.value = value !== undefined ? String(value) : "";
    select.onchange = () => {
      state.params[control.key] = select.value;
      syncJsonFromParams();
      triggerAutoUpdate(50);
    };
    return select;
  }

  if (control.type === "number" || control.type === "integer") {
    const key = String(control.key || "").toLowerCase();
    const meta = numberFieldMeta(key, control);
    const input = document.createElement("input");
    input.type = "number";
    input.className = "number-input";
    if (meta.min !== undefined) input.min = String(meta.min);
    if (meta.max !== undefined) input.max = String(meta.max);
    input.step = String(meta.step);
    const shown = value !== undefined && value !== null && value !== "" ? value : control.default;
    input.value = shown !== undefined && shown !== null ? String(shown) : "";
    input.placeholder = control.default !== undefined && control.default !== null ? String(control.default) : "";
    input.title = control.default !== undefined ? `Default: ${control.default}` : "";
    const error = document.createElement("small");
    error.className = "field-error";
    error.id = `error-${control.key}`;
    error.setAttribute("role", "alert");
    input.setAttribute("aria-describedby", error.id);
    const commitNumber = () => {
      input.setCustomValidity("");
      const numeric = input.value === "" ? undefined : Number(input.value);
      const valid = input.validity.valid && (numeric === undefined || Number.isFinite(numeric))
        && (control.type !== "integer" || numeric === undefined || Number.isInteger(numeric));
      if (!valid) {
        const message = `${control.label}: ${control.type === "integer" ? "use a whole number" : "use a valid number"}${meta.min !== undefined ? `, minimum ${meta.min}` : ""}${meta.max !== undefined ? `, maximum ${meta.max}` : ""}.`;
        state.invalidFields.set(control.key, { message, value: input.value });
        input.setAttribute("aria-invalid", "true");
        error.textContent = message;
        markFigureDirty();
        setEditorStatus("Check settings");
        return;
      }
      state.invalidFields.delete(control.key);
      input.removeAttribute("aria-invalid");
      error.textContent = "";
      const parsed = input.value === "" ? control.default : Number(input.value);
      if (parsed === undefined || Number.isNaN(parsed)) delete state.params[control.key];
      else state.params[control.key] = control.type === "integer" ? parseInt(parsed, 10) : parsed;
      syncJsonFromParams();
      triggerAutoUpdate(200);
    };
    const invalid = state.invalidFields.get(control.key);
    if (invalid) {
      input.value = invalid.value;
      input.setAttribute("aria-invalid", "true");
      error.textContent = invalid.message;
    }
    input.onchange = commitNumber;
    input.oninput = commitNumber;
    const wrap = document.createElement("span");
    wrap.className = "number-field";
    wrap.append(input, error);
    return wrap;
  }

  if (control.type === "color") {
    const input = document.createElement("input");
    input.type = "color";
    input.value = toHexColor(value) || "#3B82F6";
    input.oninput = () => {
      state.params[control.key] = input.value;
      syncJsonFromParams();
      triggerAutoUpdate(100);
    };
    return input;
  }

  const input = document.createElement("input");
  input.type = "text";
  input.value = value !== undefined ? String(value) : "";
  input.oninput = () => {
    state.params[control.key] = input.value;
    syncJsonFromParams();
    triggerAutoUpdate(250);
  };
  return input;
}

/**
 * Editor tabs (stable for every plot):
 *   data | plot | customize | theme | axes | title | legend | canvas | export
 *
 * - data / plot / customize → plot-specific (from schema)
 * - theme/axes/title/legend/canvas → common UI (always present) + matching schema keys
 */
const EDITOR_TABS = ["data", "plot", "customize", "theme", "axes", "title", "legend", "canvas", "export"];

const CUSTOMIZE_SECTIONS = new Set([
  "marks_labels",
  "marks labels",
  "marks",
  "points",
  "density",
  "labels",
  "style",
  "graphic",
  "graphics",
]);

const CUSTOMIZE_SECTION_TITLES = {
  marks_labels: "Cluster ellipses & labels",
  "marks labels": "Cluster ellipses & labels",
  marks: "Cluster ellipses & marks",
  points: "Points",
  density: "Density",
  labels: "Labels",
  style: "Style",
  graphic: "Graphic",
  graphics: "Graphics",
};

/** Shared aesthetic fields always shown under common tabs (written into state.params). */
const COMMON_CONTROLS = {
  theme: [
    {
      key: "theme_use",
      label: "Base theme",
      type: "select",
      options: ["default", "classic", "minimal", "bw", "blank"],
      default: "default",
    },
    { key: "plot_background", label: "Plot background", type: "color", default: "#FFFFFF" },
    { key: "panel_background", label: "Panel background", type: "color", default: "#FFFFFF" },
    { key: "panel_border_show", label: "Show panel border", type: "boolean", default: true },
    { key: "panel_border_color", label: "Panel border color", type: "color", default: "#111111" },
    { key: "panel_border_width", label: "Panel border width", type: "number", default: 0.6 },
    { key: "axis_line_show", label: "Show axis lines", type: "boolean", default: false, help: "X/Y baseline. Turn off to hide." },
    { key: "axis_line_color", label: "Axis line color", type: "color", default: "#111111" },
    { key: "axis_line_width", label: "Axis line width", type: "number", default: 0.5 },
    { key: "axis_line_x_show", label: "Show X axis line", type: "boolean", default: true },
    { key: "axis_line_y_show", label: "Show Y axis line", type: "boolean", default: true },
    { key: "axis_tick_show", label: "Show axis ticks", type: "boolean", default: true },
    { key: "axis_tick_color", label: "Tick color", type: "color", default: "#111111" },
    { key: "axis_tick_width", label: "Tick width", type: "number", default: 0.35 },
    { key: "grid_show", label: "Show grid", type: "boolean", default: false },
    { key: "grid_color", label: "Grid color", type: "color", default: "#E5E7EB" },
    { key: "grid_line_width", label: "Grid width", type: "number", default: 0.3 },
    {
      key: "grid_line_type",
      label: "Grid line type",
      type: "select",
      options: ["solid", "dashed", "dotted", "dotdash", "longdash", "twodash"],
      default: "solid",
    },
    { key: "grid_x_show", label: "Show vertical grid", type: "boolean", default: true },
    { key: "grid_y_show", label: "Show horizontal grid", type: "boolean", default: true },
    { key: "grid_minor_show", label: "Show minor grid", type: "boolean", default: false },
    { key: "grid_minor_color", label: "Minor grid color", type: "color", default: "#F3F4F6" },
    { key: "grid_minor_width", label: "Minor grid width", type: "number", default: 0.2 },
  ],
  axes: [
    { key: "xlab", label: "X axis title", type: "string", help: "Label for the horizontal axis" },
    { key: "xlab_show", label: "Show X title", type: "boolean", default: true },
    { key: "ylab", label: "Y axis title", type: "string", help: "Label for the vertical axis" },
    { key: "ylab_show", label: "Show Y title", type: "boolean", default: true },
    { key: "show_x_axis", label: "Show X axis", type: "boolean", default: true },
    { key: "show_y_axis", label: "Show Y axis", type: "boolean", default: true },
    { key: "axis_title_size", label: "Axis title size", type: "number", default: 12 },
    { key: "axis_text_size", label: "Axis tick text size", type: "number", default: 10 },
    { key: "x_axis_text_size", label: "X tick size", type: "number", default: 10 },
    { key: "x_axis_text_angle", label: "X tick angle", type: "number", default: 0 },
    { key: "y_axis_text_size", label: "Y tick size", type: "number", default: 10 },
    { key: "y_axis_text_angle", label: "Y tick angle", type: "number", default: 0 },
    { key: "xlim", label: "X limits [min,max]", type: "string", help: "Optional, e.g. -5,10" },
    { key: "ylim", label: "Y limits [min,max]", type: "string", help: "Optional, e.g. -5,10" },
    { key: "axis_arrow_show", label: "Show axis arrows", type: "boolean", default: false },
    { key: "axis_arrow_x_label", label: "X arrow label", type: "string" },
    { key: "axis_arrow_y_label", label: "Y arrow label", type: "string" },
  ],
  title: [
    { key: "title_show", label: "Show title", type: "boolean", default: true },
    { key: "title", label: "Title", type: "string" },
    { key: "subtitle", label: "Subtitle", type: "string" },
    { key: "title_size", label: "Title size", type: "number", default: 14 },
    { key: "title_color", label: "Title color", type: "color", default: "#222222" },
  ],
  legend: [
    { key: "legend_show", label: "Show legend", type: "boolean", default: true },
    {
      key: "legend_position",
      label: "Legend position",
      type: "select",
      options: ["right", "left", "top", "bottom", "none"],
      default: "right",
    },
    { key: "legend_inside", label: "Place legend inside plot", type: "boolean", default: false },
    { key: "legend_x", label: "Inside X (0–1)", type: "number", default: 0.98 },
    { key: "legend_y", label: "Inside Y (0–1)", type: "number", default: 0.5 },
    {
      key: "legend_direction",
      label: "Direction",
      type: "select",
      options: ["vertical", "horizontal"],
      default: "vertical",
      help: "horizontal is the ggplot equivalent of horiz=TRUE",
    },
    { key: "legend_horizontal", label: "Horizontal (horiz)", type: "boolean", default: false },
    { key: "legend_name", label: "Legend title", type: "string" },
    { key: "legend_title_size", label: "Title size", type: "number", default: 11 },
    { key: "legend_title_color", label: "Title color", type: "color", default: "#111111" },
    {
      key: "legend_title_fontface",
      label: "Title face",
      type: "select",
      options: ["plain", "bold", "italic", "bold.italic"],
      default: "plain",
    },
    {
      key: "legend_title_position",
      label: "Title position",
      type: "select",
      options: ["top", "left", "bottom", "right"],
      default: "top",
    },
    { key: "legend_title_hjust", label: "Title hjust", type: "number", default: 0 },
    { key: "legend_text_size", label: "Text size", type: "number", default: 10 },
    { key: "legend_text_color", label: "Text color (text.col)", type: "color", default: "#111111" },
    {
      key: "legend_text_fontface",
      label: "Text face",
      type: "select",
      options: ["plain", "bold", "italic", "bold.italic"],
      default: "plain",
    },
    {
      key: "legend_label_position",
      label: "Label position",
      type: "select",
      options: ["right", "left", "top", "bottom"],
      default: "right",
    },
    { key: "legend_nrow", label: "Legend nrow", type: "integer", help: "Leave empty for automatic rows" },
    { key: "legend_ncol", label: "Legend ncol", type: "integer", help: "Leave empty for automatic columns" },
    { key: "legend_byrow", label: "Fill by row", type: "boolean", default: true },
    { key: "legend_reverse", label: "Reverse legend", type: "boolean", default: false },
    { key: "legend_key_size_pt", label: "Key size (pt)", type: "number", default: 10 },
    { key: "legend_key_width_pt", label: "Key width (pt)", type: "number", default: 10 },
    { key: "legend_key_height_pt", label: "Key height (pt)", type: "number", default: 10 },
    { key: "legend_point_size", label: "Legend point size", type: "number", default: 4 },
    { key: "legend_key_alpha", label: "Key alpha", type: "number", default: 1 },
    { key: "legend_key_fill", label: "Key fill", type: "color", default: "#FFFFFF" },
    { key: "legend_background_show", label: "Legend background", type: "boolean", default: false },
    { key: "legend_background_fill", label: "Background fill", type: "color", default: "#FFFFFF" },
    { key: "legend_background_color", label: "Background border", type: "color", default: "#FFFFFF" },
    {
      key: "legend_box",
      label: "Legend box layout",
      type: "select",
      options: ["vertical", "horizontal"],
      default: "vertical",
    },
    { key: "legend_spacing_x", label: "Spacing X (pt)", type: "number", default: 4 },
    { key: "legend_spacing_y", label: "Spacing Y (pt)", type: "number", default: 4 },
    { key: "legend_margin", label: "Legend margin (pt)", type: "number", default: 4 },
  ],
  canvas: [
    { key: "width", label: "Width", type: "number", default: 8, help: "Figure width (inches unless plugin uses px)" },
    { key: "height", label: "Height", type: "number", default: 6 },
    { key: "dpi", label: "DPI", type: "number", default: 300 },
    { key: "font_family", label: "Font family", type: "string", default: "sans" },
    { key: "base_size", label: "Base font size", type: "number", default: 11 },
    { key: "aspect_ratio", label: "Aspect ratio", type: "number", default: 1 },
    {
      key: "orientation",
      label: "Orientation",
      type: "select",
      options: ["horizontal", "vertical"],
      default: "horizontal",
    },
    {
      key: "rendering_mode",
      label: "Rendering mode",
      type: "select",
      options: ["auto", "vector", "raster"],
      default: "auto",
      help: "Auto uses rasterization for very large point clouds",
    },
  ],
};

function isCustomizeControl(control) {
  const key = String(control.key || "").toLowerCase();
  const section = String(control.section || "")
    .toLowerCase()
    .replace(/[/\-_]+/g, " ")
    .trim();
  if (CUSTOMIZE_SECTIONS.has(section) || CUSTOMIZE_SECTIONS.has(String(control.section || "").toLowerCase())) {
    return true;
  }
  if (
    key === "show_mark" ||
    key.startsWith("mark_") ||
    key.startsWith("point_") ||
    key === "show_density" ||
    key === "hex" ||
    key === "hex_bins" ||
    key === "label_show" ||
    key === "label_groups" ||
    key === "label_size" ||
    key === "label_color" ||
    key === "label_repel" ||
    key === "highlight_fill" ||
    key === "highlight_size" ||
    key === "highlight_alpha" ||
    key === "highlight_stroke" ||
    key === "highlight_border_color"
  ) {
    return true;
  }
  return false;
}

/**
 * Bucket schema controls into editor tabs.
 * Common buckets: axes | title | legend | canvas | theme
 * Plot-specific: data | plot | customize
 */
function getControlCategory(control) {
  const key = String(control.key || "").toLowerCase();
  const section = String(control.section || "")
    .toLowerCase()
    .replace(/[/\-_]+/g, " ")
    .trim();

  // --- Data (plot-specific mapping) ---
  if (
    control.type === "file" ||
    control.type === "column" ||
    control.type === "columns" ||
    key.endsWith("_column") ||
    key.endsWith("_columns") ||
    key.endsWith("_col") ||
    key.endsWith("_field") ||
    key === "features" ||
    key === "markers" ||
    key === "genes" ||
    key === "input_mode" ||
    /(^|_)(input|file|dataset)(_|$)/.test(key) ||
    /^(rows|columns|samples|nodes|groups|categories|tracks|motifs|terms)_(include|exclude|order)$/.test(key) ||
    key === "rows_include" ||
    key === "rows_exclude" ||
    key === "columns_include" ||
    key === "columns_exclude" ||
    key === "value_columns" ||
    key === "annotation_columns" ||
    key === "selected_ids" ||
    key === "selected_labels"
  ) {
    return "data";
  }

  // --- Theme / colors (common) ---
  if (
    key === "palette" ||
    key === "palcolor" ||
    key === "palette_colors" ||
    key === "custom_colors" ||
    key === "theme_palette_id" ||
    key === "group_colors" ||
    key === "category_colors" ||
    (key.includes("palette") && !key.includes("column")) ||
    (section.includes("color") && !key.endsWith("_column"))
  ) {
    // single color fields still belong with style unless clearly theme-level
    if (key.endsWith("_color") && !key.includes("palette") && !key.includes("group") && !key.includes("category")) {
      // fall through to plot or axes
    } else {
      return "theme";
    }
  }

  // --- Theme appearance: panel, border, axis lines, grid ---
  if (
    key === "theme_use" ||
    key === "theme" ||
    key.includes("panel_border") ||
    key.includes("panel_background") ||
    key.includes("plot_background") ||
    key.includes("axis_line") ||
    key.includes("axis_tick") ||
    key === "grid_show" ||
    key === "show_grid" ||
    key.includes("grid_color") ||
    key.includes("grid_line") ||
    key.includes("grid_major") ||
    key.includes("grid_minor") ||
    key === "grid_x_show" ||
    key === "grid_y_show" ||
    key === "grid" ||
    /(^|_)grid(_|$)/.test(key)
  ) {
    return "theme";
  }

  // --- Axes (common) ---
  if (
    /column_name|col_name|column_label|column_text|column_label_position|col_label/.test(key) ||
    /row_name|row_label_position|row_text/.test(key) ||
    /(^|_)(xlab|ylab|x_title|y_title|x_label|y_label|x_axis|y_axis|xlim|ylim|x_min|y_min|x_max|y_max|x_text|y_text|x_tick|y_tick|x_break|y_break|x_expand|y_expand|x_angle|y_angle)(_|$)/.test(key) ||
    /^axis_/.test(key) ||
    key.includes("axis_text") ||
    key.includes("axis_title") ||
    key.includes("axis_arrow") ||
    key === "axis_limits" ||
    (/^x[_a-z]/.test(key) && /(angle|size|color|show|title|text|lim|expand|break|lab|tick|grid|face|family)/.test(key)) ||
    (/^y[_a-z]/.test(key) && /(angle|size|color|show|title|text|lim|expand|break|lab|tick|grid|face|family)/.test(key))
  ) {
    return "axes";
  }

  // --- Title (common) ---
  if (
    (/(^|_)(title|subtitle|caption)(_|$)/.test(key) ||
      key.includes("title_show") ||
      key.includes("title_size") ||
      key.includes("title_color") ||
      key.includes("title_face")) &&
    !key.startsWith("axis_") &&
    !key.includes("legend_title")
  ) {
    return "title";
  }

  // --- Legend (common) ---
  if (key.includes("legend") || section.includes("legend")) return "legend";

  // --- Canvas (common size / panel / grid) ---
  if (
    key === "width" ||
    key === "height" ||
    key.includes("dpi") ||
    key.includes("html_width") ||
    key.includes("html_height") ||
    key === "aspect_ratio" ||
    key === "font_family" ||
    key === "base_size" ||
    key === "rendering_mode" ||
    key === "raster" ||
    key === "orientation" ||
    (key.includes("margin") && !key.includes("label") && !key.includes("legend"))
  ) {
    return "canvas";
  }

  // --- Section mapping ---
  if (section) {
    if (section === "data" || section.includes("input") || section === "order" || section.includes("filter") || section.includes("selector")) {
      return "data";
    }
    if (section === "axes" || section === "axis" || section.includes("axes") || section.includes("x axis") || section.includes("y axis")) {
      return "axes";
    }
    if (section.includes("title") || section === "titles" || section.includes("typography") && section.includes("title")) return "title";
    if (section.includes("legend")) return "legend";
    if (
      section.includes("export") ||
      section.includes("output") ||
      section === "canvas" ||
      section.includes("canvas theme") ||
      section.includes("theme output") ||
      section.includes("background")
    ) {
      return "canvas";
    }
    if (section.includes("color") || section.includes("palette") || section === "theme") return "theme";
  }

  if (key.includes("format") || key.includes("export") || key === "json") return "export";

  if (isCustomizeControl(control)) return "customize";

  // Everything else is plot-specific (cells, rules, clustering, layers, interaction…)
  return "plot";
}

function allSchemaControls() {
  return (state.schemaSections || []).flatMap((item) => item.controls || []);
}

function controlsForTab(tab) {
  return allSchemaControls().filter((c) => getControlCategory(c) === tab);
}

function refreshParamNavCounts() {
  const counts = {};
  EDITOR_TABS.forEach((t) => {
    counts[t] = 0;
  });
  allSchemaControls().forEach((c) => {
    const t = getControlCategory(c);
    counts[t] = (counts[t] || 0) + 1;
  });
  // common tabs always have baseline controls
  ["theme", "axes", "title", "legend", "canvas"].forEach((tab) => { counts[tab] = mergeCommonWithSchema(tab).length; });

  document.querySelectorAll("#paramNavCol [data-count-for]").forEach((el) => {
    const tab = el.dataset.countFor;
    const n = counts[tab] || 0;
    el.textContent = n > 0 ? String(n) : "";
    el.classList.toggle("is-empty", n === 0);
  });

  // Dim plot tab only if truly empty
  document.querySelectorAll("#paramNavCol .param-tab").forEach((btn) => {
    const tab = btn.dataset.ptab;
    if (!tab || tab === "theme" || tab === "export") {
      btn.classList.remove("is-dim");
      return;
    }
    if ((tab === "plot" || tab === "customize") && !(counts[tab] > 0)) btn.classList.add("is-dim");
    else btn.classList.remove("is-dim");
  });
}

function makeVirtualControl(spec) {
  return {
    key: spec.key,
    section: "common",
    label: spec.label || labelize(spec.key),
    type: spec.type || inferType(spec.key, spec),
    default: spec.default,
    min: spec.min ?? spec.minimum,
    max: spec.max ?? spec.maximum,
    step: spec.step,
    help: spec.help || "",
    required: false,
    options: spec.options || inferOptions(spec.key, spec),
    group: "Common",
    tier: "basic",
    virtual: true,
  };
}

/** Merge common baseline controls with schema controls; schema wins on duplicate keys. */
function mergeCommonWithSchema(tab) {
  const schemaControls = controlsForTab(tab);
  const schemaKeys = new Set(schemaControls.map((c) => c.key));
  const baseline = (COMMON_CONTROLS[tab] || [])
    .filter((spec) => !schemaKeys.has(spec.key))
    .map(makeVirtualControl);
  // Prefer schema order after baseline common fields for discoverability
  const commonFirst = (COMMON_CONTROLS[tab] || []).map((s) => s.key);
  const orderedSchema = [...schemaControls].sort((a, b) => {
    const ia = commonFirst.indexOf(a.key);
    const ib = commonFirst.indexOf(b.key);
    if (ia >= 0 && ib >= 0) return ia - ib;
    if (ia >= 0) return -1;
    if (ib >= 0) return 1;
    return 0;
  });
  // Put baseline first, then schema (including overrides that replace baseline keys)
  const schemaByKey = Object.fromEntries(schemaControls.map((c) => [c.key, c]));
  if (schemaByKey.legend_title && !schemaByKey.legend_name) {
    // Display and edit the plugin's real key; changing only an alias leaves an
    // existing legend_title in the preset taking precedence at render time.
    schemaByKey.legend_name = schemaByKey.legend_title;
  }
  const head = (COMMON_CONTROLS[tab] || []).map((spec) => schemaByKey[spec.key] || makeVirtualControl(spec));
  const tail = orderedSchema.filter((c) => !commonFirst.includes(c.key) && c.key !== "legend_title");
  return [...head, ...tail];
}

function appendControlGroup(area, title, controls, { open = true } = {}) {
  if (!controls?.length) return;
  const group = document.createElement("details");
  group.className = "control-group";
  group.open = open;
  group.innerHTML = `<summary>${escapeHtml(title)}</summary>`;
  controls.forEach((control) => {
    const row = document.createElement("label");
    row.className = `control-row control-${control.type || "string"}`;
    const required = control.required ? `<span class="required">*</span>` : "";
    row.innerHTML = `<span class="control-label-line"><span>${escapeHtml(control.label)}${required}</span></span>`;
    row.appendChild(renderInputForControl(control));
    if (control.help) {
      const help = document.createElement("small");
      help.textContent = control.help;
      row.appendChild(help);
    }
    group.appendChild(row);
  });
  area.appendChild(group);
}

function setupParamNavEvents() {
  const tabs = document.querySelectorAll("#paramNavCol .param-tab");
  tabs.forEach((tab) => {
    tab.onclick = () => {
      tabs.forEach((t) => t.classList.remove("active"));
      tab.classList.add("active");
      state.activeParamTab = tab.dataset.ptab;
      state.parameterSearch = "";
      if ($("parameterSearch")) $("parameterSearch").value = "";
      renderParamContentArea();
    };
  });
  if ($("parameterSearch")) $("parameterSearch").oninput = (event) => {
    state.parameterSearch = event.target.value;
    renderParamContentArea();
  };
}

function collectColorParamKeys() {
  const keys = new Set();
  (state.schemaSections || []).forEach((sec) => {
    (sec.controls || []).forEach((c) => {
      const k = (c.key || "").toLowerCase();
      if (
        k.includes("color") ||
        k.includes("palette") ||
        k === "palcolor" ||
        k.endsWith("_pal") ||
        k.includes("fill")
      ) {
        // skip column mappings
        if (k.includes("column") || k.endsWith("_col") || k.includes("field")) return;
        keys.add(c.key);
      }
    });
  });
  Object.keys(state.params || {}).forEach((key) => {
    const k = key.toLowerCase();
    if (k.includes("color") || k.includes("palette") || k === "palcolor") {
      if (k.includes("column") || k.endsWith("_col")) return;
      keys.add(key);
    }
  });
  return Array.from(keys);
}

function applyThemePalette(palette, { silent = false } = {}) {
  if (!palette || !(palette.colors || []).length) return;
  const colors = palette.colors.slice();
  const classic = palette.classic_key || null;
  const keys = collectColorParamKeys();

  // Always set shared helpers
  state.params.theme_palette_id = palette.id;
  state.params.palette_colors = colors;
  state.params.custom_colors = colors;
  state.params.palcolor = colors;

  keys.forEach((key) => {
    const k = key.toLowerCase();
    const cur = state.params[key];
    if (k === "palette" || k.endsWith("_palette") || k === "heatmap_palette" || k === "group_palette") {
      // Prefer named palette for RColorBrewer/ggsci when available
      if (classic && !String(classic).startsWith("#") && classic.length < 40) {
        state.params[key] = classic;
      } else if (Array.isArray(cur) || cur === undefined || cur === null || cur === "") {
        state.params[key] = colors;
      } else if (typeof cur === "string") {
        state.params[key] = classic || palette.name || colors[0];
      }
      return;
    }
    if (k === "palcolor" || k === "colors" || k === "custom_colors" || k === "palette_colors" || k.includes("colors")) {
      if (cur && typeof cur === "object" && !Array.isArray(cur)) {
        // named map e.g. de_colors — recolor values in order
        const next = { ...cur };
        Object.keys(next).forEach((nk, i) => {
          next[nk] = colors[i % colors.length];
        });
        state.params[key] = next;
      } else {
        state.params[key] = colors;
      }
      return;
    }
    if (k.includes("color") && typeof cur === "string" && cur.startsWith("#")) {
      state.params[key] = colors[0];
    }
  });

  themeState.activeId = palette.id;
  themeState.status = `Applied “${palette.name || palette.id}” (${colors.length} colors)`;
  syncJsonFromParams();
  if (!silent) {
    triggerAutoUpdate(80);
    if (state.activeParamTab === "theme") renderParamContentArea();
  }
}

async function ensureThemeCatalog() {
  if (themeState.loaded && themeState.palettes.length) return themeState;
  try {
    const [list, journals] = await Promise.all([
      api("/api/palettes?limit=300"),
      api("/api/palettes/journals").catch(() => ({ journals: [] })),
    ]);
    themeState.meta = list.meta || list.sources || null;
    themeState.palettes = list.palettes || [];
    themeState.journals = journals.journals || [];
    themeState.loaded = true;
  } catch (err) {
    themeState.status = `Failed to load palettes: ${err.message}`;
    // offline fallback from SCIENTIFIC_PALETTES
    themeState.palettes = Object.entries(SCIENTIFIC_PALETTES).map(([name, colors]) => ({
      id: `builtin-${name}`,
      name: name.toUpperCase(),
      classic_key: name,
      colors,
      n_colors: colors.length,
      catalog: "builtin",
      family: "ggsci",
      journal: name.toUpperCase(),
    }));
    themeState.loaded = true;
  }
  return themeState;
}

async function recommendThemePalettes() {
  const journal = (themeState.journalQuery || "").trim();
  const goal = journal ? `${journal} journal figure colors` : "scientific publication categorical";
  try {
    const result = await api("/api/palettes/recommend", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        journal,
        goal,
        n_groups: 6,
        limit: 10,
      }),
    });
    themeState.recommendations = result.recommendations || [];
    themeState.status = journal
      ? `Recommended for journal “${journal}” (${themeState.recommendations.length})`
      : `Top recommendations (${themeState.recommendations.length})`;
  } catch (err) {
    themeState.recommendations = [];
    themeState.status = `Recommend failed: ${err.message}`;
  }
  renderParamContentArea();
}

function paletteCardHtml(p, { recommended = false } = {}) {
  const colors = p.colors || [];
  const swatches = colors
    .slice(0, 12)
    .map((c) => `<span class="theme-swatch" style="background:${escapeHtml(c)}" title="${escapeHtml(c)}"></span>`)
    .join("");
  const active = themeState.activeId === p.id ? "is-active" : "";
  const badge = recommended ? `<span class="theme-badge">rec</span>` : "";
  const meta = [p.journal, p.family || p.catalog, `${p.n_colors || colors.length}c`]
    .filter(Boolean)
    .join(" · ");
  return `
    <button type="button" class="theme-palette-card ${active}" data-palette-id="${escapeHtml(p.id)}" title="Click to apply">
      <div class="theme-palette-head">
        <strong>${escapeHtml(p.name || p.id)}</strong>
        ${badge}
      </div>
      <div class="theme-swatch-row">${swatches}</div>
      <div class="theme-palette-meta">${escapeHtml(meta)}${p.reason ? ` · ${escapeHtml(p.reason)}` : ""}</div>
    </button>
  `;
}

function filteredThemePalettes() {
  let items = themeState.palettes || [];
  if (themeState.filterCatalog && themeState.filterCatalog !== "all") {
    items = items.filter((p) => (p.catalog || "") === themeState.filterCatalog);
  }
  if (themeState.filterFamily && themeState.filterFamily !== "all") {
    const f = themeState.filterFamily.toLowerCase();
    items = items.filter(
      (p) =>
        (p.family || "").toLowerCase() === f ||
        (p.tags || []).some((t) => String(t).toLowerCase() === f)
    );
  }
  if (themeState.search) {
    const q = themeState.search.toLowerCase();
    items = items.filter(
      (p) =>
        (p.name || "").toLowerCase().includes(q) ||
        (p.journal || "").toLowerCase().includes(q) ||
        (p.id || "").toLowerCase().includes(q) ||
        (p.classic_key || "").toLowerCase().includes(q) ||
        (p.family || "").toLowerCase().includes(q)
    );
  }
  return items;
}

function wireThemePanel(root) {
  const search = root.querySelector("#themeSearch");
  if (search) {
    search.value = themeState.search;
    search.oninput = () => {
      themeState.search = search.value || "";
      renderParamContentArea();
    };
  }
  const journal = root.querySelector("#themeJournalInput");
  if (journal) {
    journal.value = themeState.journalQuery;
    journal.oninput = () => {
      themeState.journalQuery = journal.value || "";
    };
    journal.onkeydown = (e) => {
      if (e.key === "Enter") {
        e.preventDefault();
        recommendThemePalettes();
      }
    };
  }
  const recBtn = root.querySelector("#themeRecommendBtn");
  if (recBtn) recBtn.onclick = () => recommendThemePalettes();

  root.querySelectorAll("[data-theme-catalog]").forEach((btn) => {
    btn.onclick = () => {
      themeState.filterCatalog = btn.dataset.themeCatalog;
      renderParamContentArea();
    };
  });
  root.querySelectorAll("[data-theme-family]").forEach((btn) => {
    btn.onclick = () => {
      themeState.filterFamily = btn.dataset.themeFamily;
      renderParamContentArea();
    };
  });
  root.querySelectorAll("[data-palette-id]").forEach((btn) => {
    btn.onclick = () => {
      const id = btn.dataset.paletteId;
      const all = [
        ...(themeState.recommendations || []),
        ...(themeState.palettes || []),
      ];
      const p = all.find((x) => x.id === id);
      if (p) applyThemePalette(p);
    };
  });
  const journalSelect = root.querySelector("#themeJournalSelect");
  if (journalSelect) {
    journalSelect.onchange = () => {
      const v = journalSelect.value || "";
      themeState.journalQuery = v;
      if (v) recommendThemePalettes();
      else renderParamContentArea();
    };
  }
}

async function renderThemePanel(area) {
  // Append into a host so parent intro / plot color controls are preserved
  let host = area.querySelector("#themePanelHost");
  if (!host) {
    host = document.createElement("div");
    host.id = "themePanelHost";
    area.appendChild(host);
  }
  host.innerHTML = `<div class="theme-loading">Loading color themes…</div>`;
  await ensureThemeCatalog();

  const recs = themeState.recommendations || [];
  const items = filteredThemePalettes().slice(0, 80);
  const journals = themeState.journals || [];
  const total = themeState.meta?.count || themeState.palettes.length;
  const cat = themeState.filterCatalog;
  const fam = themeState.filterFamily;

  const catalogChips = [
    ["all", "All"],
    ["builtin", "Classic"],
    ["amfe", "AMFE"],
    ["lcpmgh", "lcpmgh"],
  ]
    .map(
      ([id, label]) =>
        `<button type="button" class="theme-chip ${cat === id ? "is-active" : ""}" data-theme-catalog="${id}">${label}</button>`
    )
    .join("");

  const familyChips = [
    ["all", "Any family"],
    ["ggsci", "ggsci"],
    ["RColorBrewer", "Brewer"],
    ["journal_case", "Journal cases"],
    ["continuous", "Gradient"],
    ["accessible", "Colorblind"],
  ]
    .map(
      ([id, label]) =>
        `<button type="button" class="theme-chip ${fam === id ? "is-active" : ""}" data-theme-family="${id}">${label}</button>`
    )
    .join("");

  const journalOptions = journals
    .slice(0, 40)
    .map((j) => {
      const name = j.journal || j;
      const sel = themeState.journalQuery === name ? "selected" : "";
      return `<option value="${escapeHtml(name)}" ${sel}>${escapeHtml(name)} (${escapeHtml(j.count || "?")})</option>`;
    })
    .join("");

  host.innerHTML = `
    <div class="theme-panel">
      <div class="theme-panel-intro">
        <strong>Palette catalog</strong>
        <p>Click a palette to apply. Sources: classic built-ins, AMFE, and
          <a href="https://github.com/lcpmgh/colors" target="_blank" rel="noopener">lcpmgh/colors</a> (MIT).
          Catalog: ${escapeHtml(total)} palettes.</p>
      </div>

      <div class="theme-journal-box">
        <label class="theme-label">Target journal / magazine</label>
        <div class="theme-journal-row">
          <select id="themeJournalSelect" class="theme-select">
            <option value="">— pick journal —</option>
            ${journalOptions}
          </select>
          <input id="themeJournalInput" class="theme-input" placeholder="e.g. Nature, Lancet, NEJM, Cell" />
          <button type="button" id="themeRecommendBtn" class="primary compact-action">Recommend</button>
        </div>
        ${themeState.status ? `<div class="theme-status">${escapeHtml(themeState.status)}</div>` : ""}
      </div>

      ${
        recs.length
          ? `<div class="theme-section">
              <div class="theme-section-title">Recommended for you</div>
              <div class="theme-palette-grid">${recs.map((p) => paletteCardHtml(p, { recommended: true })).join("")}</div>
            </div>`
          : ""
      }

      <div class="theme-filters">
        <div class="theme-chip-row">${catalogChips}</div>
        <div class="theme-chip-row">${familyChips}</div>
        <input id="themeSearch" class="theme-input" placeholder="Search name / journal / id…" />
      </div>

      <div class="theme-section">
        <div class="theme-section-title">Browse palettes (${escapeHtml(items.length)}${items.length >= 80 ? "+" : ""})</div>
        <div class="theme-palette-grid">
          ${items.length ? items.map((p) => paletteCardHtml(p)).join("") : `<div class="ai-empty">No palettes match filters.</div>`}
        </div>
      </div>
    </div>
  `;
  wireThemePanel(host);
}

function renderParamContentArea() {
  const area = $("paramContentArea");
  if (!area) return;
  area.innerHTML = "";
  const tab = state.activeParamTab || "data";
  refreshParamNavCounts();
  const query = state.parameterSearch.trim().toLowerCase();
  if (query) {
    const all = new Map();
    ["theme", "axes", "title", "legend", "canvas"].forEach((tab) => mergeCommonWithSchema(tab).forEach((control) => all.set(control.key, control)));
    allSchemaControls().forEach((control) => all.set(control.key, control));
    const matches = [...all.values()].filter((control) => `${control.label} ${control.key} ${control.help}`.toLowerCase().includes(query));
    const summary = document.createElement("p");
    summary.className = "param-tab-intro";
    summary.textContent = `${matches.length} matching settings across all sections`;
    area.appendChild(summary);
    appendControlGroup(area, "Search results", matches);
    return;
  }

  // ---- THEME (common color catalog) ----
  if (tab === "theme") {
    const intro = document.createElement("div");
    intro.className = "param-tab-intro";
    intro.innerHTML = `<strong>Theme</strong><p>Panel, axis lines, grid, and colors. Uncheck a line or grid to hide it.</p>`;
    area.appendChild(intro);
    const merged = mergeCommonWithSchema("theme");
    const commonKeys = new Set((COMMON_CONTROLS.theme || []).map((s) => s.key));
    const appearance = merged.filter((c) => commonKeys.has(c.key) || c.virtual);
    const extraTheme = merged.filter((c) => !commonKeys.has(c.key) && !c.virtual && c.key !== "theme_palette_id");
    appendControlGroup(area, "Panel, lines & grid", appearance, { open: true });
    if (extraTheme.length) appendControlGroup(area, "Plot color parameters", extraTheme, { open: true });
    renderThemePanel(area);
    return;
  }

  // ---- DATA (plot-specific) ----
  if (tab === "data") {
    const intro = document.createElement("div");
    intro.className = "param-tab-intro";
    intro.innerHTML = `<strong>Data</strong><p>Upload and map columns for <code>${escapeHtml(state.pluginId || "this plot")}</code>.</p>`;
    area.appendChild(intro);

    const dataCard = document.createElement("div");
    dataCard.className = "dataset-inputs";
    inputDefinitions().forEach((definition) => {
      const label = document.createElement("label");
      label.className = "dataset-input";
      const title = document.createElement("strong");
      title.textContent = `${definition.label || labelize(definition.id)}${definition.required ? " (required)" : " (optional)"}`;
      const help = document.createElement("small");
      help.textContent = definition.description || "Choose a CSV, TSV or Excel table.";
      const input = document.createElement("input");
      input.type = "file";
      input.accept = definition.type === "file" ? "" : ".csv,.tsv,.txt,.xlsx,.xlsm";
      input.disabled = state.isUploading;
      input.setAttribute("aria-label", `Upload ${definition.id}`);
      input.onchange = () => loadUserFile(definition.id, input.files[0]);
      label.append(title, help, input);
      if (state.customFiles[definition.id]) {
        const name = document.createElement("span");
        name.className = "loaded-file-name";
        name.textContent = state.customFiles[definition.id].name;
        label.appendChild(name);
      }
      dataCard.appendChild(label);
    });
    if (Object.keys(state.customFiles).length) {
      const note = document.createElement("p");
      note.className = "dataset-note";
      const missing = missingUserInputs();
      note.textContent = missing.length
        ? `Still needed: ${missing.map((item) => item.id).join(", ")}. Example files will not be mixed with your data.`
        : "Your data is selected. Confirm column mappings, then choose Run Plot.";
      dataCard.appendChild(note);
    }
    const viewBtn = document.createElement("button");
    viewBtn.type = "button";
    viewBtn.className = "secondary";
    viewBtn.textContent = "View loaded data";
    viewBtn.onclick = () => { if ($("stageDataDrawer")) $("stageDataDrawer").open = true; };
    dataCard.appendChild(viewBtn);
    area.appendChild(dataCard);

    const dataControls = controlsForTab("data");
    if (typeof renderDataMappingPanel === "function") {
      renderDataMappingPanel(area, dataControls);
    } else if (dataControls.length) {
      appendControlGroup(area, "Column mapping & filters", dataControls, { open: true });
    } else {
      area.insertAdjacentHTML(
        "beforeend",
        `<div class="empty muted" style="padding:12px;font-size:12px;">No column-mapping fields in schema. Use a preset demo, or set keys in <strong>export</strong> JSON.</div>`
      );
    }
    return;
  }

  // ---- PLOT (plot-specific options) ----
  if (tab === "plot") {
    const intro = document.createElement("div");
    intro.className = "param-tab-intro";
    intro.innerHTML = `<strong>Plot options</strong><p>Parameters unique to <code>${escapeHtml(state.pluginId || "this plot")}</code> (cells, rules, layers, clustering, interaction…).</p>`;
    area.appendChild(intro);

    const plotControls = controlsForTab("plot");
    if (!plotControls.length) {
      area.insertAdjacentHTML(
        "beforeend",
        `<div class="empty muted" style="padding:12px;font-size:12px;">This plot has no extra options beyond data, axes, title, legend, theme, and canvas.</div>`
      );
      return;
    }
    // Group by schema section for readability
    const bySection = {};
    plotControls.forEach((c) => {
      const sec = c.section || "options";
      if (!bySection[sec]) bySection[sec] = [];
      bySection[sec].push(c);
    });
    Object.entries(bySection).forEach(([sec, list], idx) => {
      appendControlGroup(area, labelize(sec), list, { open: idx < 2 });
    });
    return;
  }

  // ---- CUSTOMIZE (plot-specific visual extras: ellipses, points, density…) ----
  if (tab === "customize") {
    const intro = document.createElement("div");
    intro.className = "param-tab-intro";
    intro.innerHTML = `<strong>Customize</strong><p>Plot-specific styling for <code>${escapeHtml(state.pluginId || "this plot")}</code> — cluster ellipses, points, labels, density, and similar extras.</p>`;
    area.appendChild(intro);

    const customizeControls = controlsForTab("customize");
    if (!customizeControls.length) {
      area.insertAdjacentHTML(
        "beforeend",
        `<div class="empty muted" style="padding:12px;font-size:12px;">This plot has no extra customize options. Use plot, theme, axes, title, legend, and canvas.</div>`
      );
      return;
    }
    const bySection = {};
    customizeControls.forEach((c) => {
      const sec = c.section || "options";
      if (!bySection[sec]) bySection[sec] = [];
      bySection[sec].push(c);
    });
    const preferred = ["marks_labels", "points", "density", "labels", "style"];
    const sectionNames = [
      ...preferred.filter((name) => bySection[name]),
      ...Object.keys(bySection).filter((name) => !preferred.includes(name)),
    ];
    sectionNames.forEach((sec, idx) => {
      const title = CUSTOMIZE_SECTION_TITLES[sec] || CUSTOMIZE_SECTION_TITLES[sec.replace(/[/\-_]+/g, " ")] || labelize(sec);
      appendControlGroup(area, title, bySection[sec], { open: idx < 2 });
    });
    return;
  }

  // ---- EXPORT ----
  if (tab === "export") {
    const intro = document.createElement("div");
    intro.className = "param-tab-intro";
    intro.innerHTML = `<strong>Export &amp; advanced JSON</strong><p>Downloads use the top-right Export menu after Run. Edit raw params below if needed.</p>`;
    area.appendChild(intro);
    const group = document.createElement("details");
    group.className = "control-group";
    group.open = true;
    group.innerHTML = `<summary>Advanced JSON Configuration</summary>`;
    const textarea = document.createElement("textarea");
    textarea.id = "paramsText";
    textarea.value = state.invalidFields.get("__json")?.value ?? JSON.stringify(state.params, null, 2);
    textarea.style.cssText = "width:100%; height:220px; font-family:monospace; font-size:11px; padding:10px;";
    textarea.oninput = () => {
      syncParamsFromJson();
      triggerAutoUpdate(300);
    };
    const jsonError = document.createElement("small");
    jsonError.id = "jsonError";
    jsonError.className = "field-error";
    jsonError.setAttribute("role", "alert");
    jsonError.textContent = state.invalidFields.get("__json")?.message || "";
    textarea.setAttribute("aria-describedby", "jsonError");
    group.append(textarea, jsonError);
    area.appendChild(group);
    const extra = controlsForTab("export");
    if (extra.length) appendControlGroup(area, "Export parameters", extra, { open: false });
    return;
  }

  // ---- COMMON TABS: axes | title | legend | canvas ----
  if (["axes", "title", "legend", "canvas"].includes(tab)) {
    const labels = {
      axes: {
        title: "Axes",
        blurb: "X/Y labels, ticks, and other axis fields for this figure.",
      },
      title: {
        title: "Title",
        blurb: "Figure title and subtitle.",
      },
      legend: {
        title: "Legend",
        blurb: "Legend visibility, placement, and styling.",
      },
      canvas: {
        title: "Canvas",
        blurb: "Figure size, DPI, fonts, and aspect ratio.",
      },
    };
    const meta = labels[tab];
    const intro = document.createElement("div");
    intro.className = "param-tab-intro";
    intro.innerHTML = `<strong>${escapeHtml(meta.title)}</strong><p>${escapeHtml(meta.blurb)}</p>`;
    area.appendChild(intro);

    const merged = mergeCommonWithSchema(tab);
    const commonKeys = new Set((COMMON_CONTROLS[tab] || []).map((s) => s.key));
    const commonPart = merged.filter((c) => commonKeys.has(c.key) || c.virtual);
    const extraPart = merged.filter((c) => !commonKeys.has(c.key) && !c.virtual);

    appendControlGroup(area, meta.title, commonPart, { open: true });
    if (extraPart.length) {
      appendControlGroup(area, `Extra for ${state.pluginId || "this plot"}`, extraPart, { open: true });
    }
    return;
  }

  // fallback
  area.innerHTML = `<div class="empty muted">Unknown tab.</div>`;
}

function renderSchema(schema) {
  state.schemaSections = normalizeSchema(schema);
  state.activeParamTab = "data";
  // Seed common defaults only when missing (do not override demo params)
  Object.values(COMMON_CONTROLS).forEach((list) => {
    list.forEach((spec) => {
      if (spec.default === undefined) return;
      if (state.params[spec.key] === undefined || state.params[spec.key] === null || state.params[spec.key] === "") {
        // leave empty until user touches, except booleans/numbers with defaults after applyDefaults
      }
    });
  });
  applyDefaults();
  // After demo defaults, ensure canvas size defaults exist for export consistency
  ["width", "height", "dpi"].forEach((k) => {
    const spec = COMMON_CONTROLS.canvas.find((s) => s.key === k);
    if (spec && (state.params[k] === undefined || state.params[k] === null || state.params[k] === "")) {
      state.params[k] = spec.default;
    }
  });
  syncJsonFromParams();
  renderParamContentArea();
}

function getPrimaryPreview() {
  if (!state.inputPreview?.files) return null;
  const entries = Object.values(state.inputPreview.files);
  return entries[0] || null;
}

function rowLabels() {
  const preview = getPrimaryPreview();
  if (!preview?.preview_rows?.length) return [];
  const columns = preview.columns || [];
  const labelColumn = state.params.row_label_column || state.params.label_column || columns[0];
  return preview.preview_rows.map((row) => String(row[labelColumn] ?? "")).filter(Boolean);
}

function commitRowSelection() {
  if (!state.selectedRows.size) {
    delete state.params.rows_include;
    delete state.params.rows_exclude;
  } else if (state.rowMode === "exclude") {
    state.params.rows_exclude = Array.from(state.selectedRows);
    delete state.params.rows_include;
  } else {
    state.params.rows_include = Array.from(state.selectedRows);
    delete state.params.rows_exclude;
  }
  syncJsonFromParams();
}

function renderStageDataDrawer() {
  if (typeof renderDatasetPreview === "function") {
    renderDatasetPreview();
    return;
  }
  renderStageRowSelector();
  renderStageTablePreview();
}

function renderStageRowSelector() {
  const box = $("stageRowSelector");
  if (!box) return;
  const labels = rowLabels();
  box.innerHTML = "";
  if (!labels.length) {
    box.innerHTML = `<div class="empty muted">No row labels parsed from dataset yet. Click "⚡ Reload Demo Data" or upload a dataset.</div>`;
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
    box.innerHTML = `<div class="empty muted">No dataset loaded for preview. Click "⚡ Reload Demo Data" or upload a dataset.</div>`;
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
      ${preview.preview_rows.slice(0, 50).map((row) => {
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

function loadDemoIntoUi() {
  if (!state.demo) return;
  const files = {};
  Object.entries(state.demo.files || {}).forEach(([field, info]) => {
    if (info.preview) {
      files[field] = info.preview;
    }
  });
  state.inputPreview = { plugin_id: state.pluginId, files };
  setParamsFromDemo(state.demo);
  if (typeof applySuggestionsIfEmpty === "function") applySuggestionsIfEmpty();
  if (typeof reconcileMappingsWithDataset === "function") reconcileMappingsWithDataset();

  renderParamContentArea();
  renderStageDataDrawer();
  renderDataSource();
  $("jobStatus").textContent = "Example data loaded. Upload your own data or customize the settings.";
}

async function runDemo(options = {}) {
  if (!state.pluginId) return;
  if (options.reloadDemo !== false) {
    if (state.selectedExampleId) return loadPreset(state.selectedExampleId, { previewOnly: options.previewOnly === true });
    if (!Object.keys(state.demo?.files || {}).length && state.examples.length) {
      return loadPreset(state.examples[0].id || state.examples[0].name, { useExampleData: true, previewOnly: options.previewOnly === true });
    }
    state.uploadVersion += 1;
    state.isUploading = false;
    state.customFiles = {};
    state.invalidFields.clear();
    loadDemoIntoUi();
  }
  markFigureDirty();
  renderDataSource();
  return runDemoSilent();
}

function applyZoomTransform() {
  const img = $("preview");
  const plotlyBox = $("plotlyPreview");
  const scale = state.zoom || 1;
  if (img) img.style.transform = `scale(${scale})`;
  if (plotlyBox) plotlyBox.style.transform = `scale(${scale})`;
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

  // Restore last position (relative to stage), else default top-right
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

  const onPointerDown = (e) => {
    // Only start drag from the handle (or bar background), not tool buttons
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
    // Switch from right-anchored default to left/top absolute coords
    place(originLeft, originTop);
    handle.setPointerCapture?.(e.pointerId);
    e.preventDefault();
  };

  const onPointerMove = (e) => {
    if (!dragging) return;
    const dx = e.clientX - startX;
    const dy = e.clientY - startY;
    if (Math.abs(dx) + Math.abs(dy) > 2) moved = true;
    place(originLeft + dx, originTop + dy);
  };

  const onPointerUp = (e) => {
    if (!dragging) return;
    dragging = false;
    bar.classList.remove("is-dragging");
    try {
      handle.releasePointerCapture?.(e.pointerId);
    } catch (_) {}
    try {
      localStorage.setItem(
        storageKey,
        JSON.stringify({
          left: parseFloat(bar.style.left) || 0,
          top: parseFloat(bar.style.top) || 0,
        })
      );
    } catch (_) {}
  };

  handle.addEventListener("pointerdown", onPointerDown);
  window.addEventListener("pointermove", onPointerMove);
  window.addEventListener("pointerup", onPointerUp);
  window.addEventListener("pointercancel", onPointerUp);
  window.addEventListener("resize", () => {
    if (!bar.style.left) return;
    place(parseFloat(bar.style.left) || 0, parseFloat(bar.style.top) || 0);
  });

  // Avoid accidental click after a drag
  handle.addEventListener("click", (e) => {
    if (moved) {
      e.preventDefault();
      e.stopPropagation();
    }
  });
}

function setupStageTools() {
  document.querySelectorAll("[data-stage-action]").forEach((btn) => {
    btn.onclick = () => {
      const action = btn.dataset.stageAction;
      const wrap = $("previewWrap") || $("stageCanvas");
      if (action === "zoom-in") {
        state.zoom = Math.min(2.5, (state.zoom || 1) + 0.15);
        applyZoomTransform();
      } else if (action === "zoom-out") {
        state.zoom = Math.max(0.4, (state.zoom || 1) - 0.15);
        applyZoomTransform();
      } else if (action === "fullscreen") {
        const target = wrap || document.documentElement;
        if (!document.fullscreenElement) {
          target.requestFullscreen?.().catch(() => {});
        } else {
          document.exitFullscreen?.().catch(() => {});
        }
      } else if (action === "toggle-interactive") {
        state.preferHtmlPreview = !state.preferHtmlPreview;
        if (state.lastOutputs) updateInstantPreview(state.lastOutputs);
      }
    };
  });

  wireFloatToolsDrag();

  const toggle = $("autoUpdateToggle");
  if (toggle) {
    toggle.onchange = () => {
      state.autoUpdateEnabled = toggle.checked;
      if (!toggle.checked) {
        clearTimeout(state.autoUpdateTimer);
        state.pendingRender = false;
      } else if (state.renderedRevision !== state.revision) runDemoSilent();
    };
  }
}

function wireExampleSelect() {
  const select = $("exampleSelect");
  if (!select) return;
  select.innerHTML = "";
  const examples = state.examples || [];
  if (!examples.length) {
    select.add(new Option("Default demo", ""));
    select.disabled = true;
    return;
  }
  select.disabled = false;
  select.add(new Option("Default demo", ""));
  examples.forEach((ex) => {
    const id = ex.id || ex.name || "";
    const label = ex.label || ex.title || ex.name || id;
    select.add(new Option(label, id));
  });
  if (state.selectedExampleId) select.value = state.selectedExampleId;

  select.onchange = () => loadPreset(select.value || null, { previewOnly: true });
}

async function loadPreset(eid, { useExampleData = false, previewOnly = false } = {}) {
  if (state.isLoadingPreset) return;
  state.isLoadingPreset = true;
  if ($("exampleSelect")) $("exampleSelect").disabled = true;
  clearTimeout(state.autoUpdateTimer);
  markFigureDirty();
  $("jobStatus").textContent = eid ? `Loading preset “${eid}”…` : "Loading default example…";
  try {
    const record = eid ? await api(`/api/plugins/${state.pluginId}/examples/${encodeURIComponent(eid)}`) : null;
    state.invalidFields.clear();
    if (useExampleData) {
      state.uploadVersion += 1;
      state.isUploading = false;
      state.customFiles = {};
    }
    state.selectedExampleId = eid;
    if (record) {
      state.params = { ...(record.params?.params || record.params || {}) };
      if (!Object.keys(state.customFiles).length && record.input_preview) state.inputPreview = record.input_preview;
    } else if (Object.keys(state.customFiles).length) {
      setParamsFromDemo(state.demo);
    } else {
      loadDemoIntoUi();
    }
    state.selectedRows = new Set();
    state.selectedColumns = new Set();
    if (typeof reconcileMappingsWithDataset === "function") reconcileMappingsWithDataset();
    if (typeof applySuggestionsIfEmpty === "function") applySuggestionsIfEmpty();
    syncJsonFromParams();
    markFigureDirty();
    renderDataSource();
    renderStageDataDrawer();
    renderParamContentArea();
    if (previewOnly && record?.expected && !Object.keys(state.customFiles).length) {
      renderValidation(null);
      updatePreviewImage(record.expected);
      state.previewRevision = state.revision;
      state.lastOutputs = {};
      renderDownloads({});
      setEditorStatus("Example preview");
      $("jobStatus").textContent = "Built-in example preview. Edit settings to update it, or generate export files when needed.";
      if (typeof refreshPlotGuide === "function") await refreshPlotGuide();
      return;
    }
  } catch (err) {
    $("jobStatus").textContent = `Preset was not loaded: ${err.message}`;
    if ($("exampleSelect")) $("exampleSelect").value = state.selectedExampleId || "";
    setEditorStatus("Preset failed");
    return;
  } finally {
    state.isLoadingPreset = false;
    renderDownloads(state.lastOutputs);
    if ($("exampleSelect")) $("exampleSelect").disabled = false;
  }
  await runDemoSilent();
  if (typeof refreshPlotGuide === "function") await refreshPlotGuide();
}

async function loadSavedJob(jobId) {
  const record = await api(`/api/jobs/${encodeURIComponent(jobId)}/editor`);
  if (record.plugin_id !== state.pluginId) throw new Error("The saved run belongs to a different plot.");
  const files = {};
  for (const [field, info] of Object.entries(record.inputs || {})) {
    const response = await fetch(info.url);
    if (!response.ok) throw new Error(`Saved input unavailable: ${info.filename}`);
    files[field] = new File([await response.blob()], info.filename);
  }
  if (!Object.keys(files).length) throw new Error("The saved run has no accessible input files.");
  state.customFiles = files;
  state.inputPreview = record.input_preview;
  state.params = { ...record.params };
  state.selectedExampleId = null;
  state.userTouchedParams = true;
  if ($("exampleSelect")) $("exampleSelect").value = "";
  syncJsonFromParams();
  renderDataSource();
  renderStageDataDrawer();
  renderParamContentArea();
  state.lastOutputs = record.outputs || {};
  renderDownloads(state.lastOutputs);
  renderValidation(record.vnext);
  if (record.status === "completed" && record.outputs?.preview) {
    updatePreviewImage(record.outputs.preview);
    state.renderedRevision = state.revision;
    state.previewRevision = state.revision;
    setEditorStatus("Synced");
  } else setEditorStatus("Check settings");
  $("jobStatus").textContent = `Loaded saved run ${jobId}. Editing its original data and settings.`;
}

async function init() {
  setupParamNavEvents();
  setupStageTools();
  wireExportMenu();
  if ($("prepareExportButton")) $("prepareExportButton").onclick = () => runDemoSilent();
  wirePlotSpecImport();
  if (typeof initPlotGuide === "function") initPlotGuide();

  if ($("runDemoButton")) {
    $("runDemoButton").onclick = () => {
      state.selectedExampleId = null;
      const sel = $("exampleSelect");
      if (sel) sel.value = "";
      const example = state.examples.find((item) => item.bundle && item.expected);
      if (example) {
        state.selectedExampleId = example.id;
        if (sel) sel.value = example.id;
        loadPreset(example.id, { useExampleData: true, previewOnly: true });
      } else runDemo({ reloadDemo: true });
    };
  }
  if ($("runButton")) {
    $("runButton").onclick = () => runDemo({ reloadDemo: false });
  }
  if ($("loadDemoButton")) {
    $("loadDemoButton").onclick = () => {
      state.selectedExampleId = null;
      const sel = $("exampleSelect");
      if (sel) sel.value = "";
      loadDemoIntoUi();
      runDemoSilent();
    };
  }

  try {
    const detail = await api(`/api/plugins/${state.pluginId}`);
    state.detail = detail;
    state.demo = detail.demo || null;
    state.examples = Array.isArray(detail.examples) ? detail.examples : [];
    if (STUDIO_EXAMPLE) {
      const match = state.examples.find((ex) => ex.id === STUDIO_EXAMPLE || ex.name === STUDIO_EXAMPLE);
      if (match) state.selectedExampleId = match.id;
      else state.selectedExampleId = STUDIO_EXAMPLE;
    } else if (STUDIO_VARIANT) {
      const match = state.examples.find((ex) => ex.id === STUDIO_VARIANT || ex.plot_type === STUDIO_VARIANT);
      if (match) state.selectedExampleId = match.id;
      else {
        try {
          const resolved = await api(`/api/registry/legacy/${encodeURIComponent(state.pluginId)}/${encodeURIComponent(STUDIO_VARIANT)}`);
          if (resolved?.example_id) {
            const ex = state.examples.find((item) => item.id === resolved.example_id);
            if (ex) state.selectedExampleId = ex.id;
          }
          if (resolved?.parameters && typeof resolved.parameters === "object") {
            state.params = { ...state.params, ...resolved.parameters };
          }
        } catch (err) {}
      }
    }

    $("pluginName").textContent = detail.display_name || detail.name || state.pluginId;
    const intent = [SOURCE_CONTEXT, SOURCE_TASK].filter(Boolean).join(" / ");
    $("pluginDescription").textContent = (detail.description || "") + (intent ? ` · from ${intent}` : "");
    document.title = `${detail.display_name || state.pluginId} | Plot Editor`;

    renderSchema(detail.params_schema || detail.parameters);
    wireExampleSelect();

    const imported = takePendingImport();
    if (SAVED_JOB) {
      await loadSavedJob(SAVED_JOB);
    } else if (imported) {
      applyImportedParams(imported);
      await runDemo({ reloadDemo: false });
    } else if (state.examples.some((example) => example.bundle && example.expected)) {
      const example = state.selectedExampleId
        ? { id: state.selectedExampleId }
        : state.examples.find((item) => item.bundle && item.expected);
      state.selectedExampleId = example.id;
      if ($("exampleSelect")) $("exampleSelect").value = example.id;
      await loadPreset(example.id, { previewOnly: true });
    } else if (state.demo && Object.keys(state.demo.files || {}).length) {
      await runDemo();
    } else if (state.examples.length) {
      // No default demo files but examples exist — run first example
      state.selectedExampleId = state.examples[0].id || state.examples[0].name;
      const sel = $("exampleSelect");
      if (sel) sel.value = state.selectedExampleId || "";
      await loadPreset(state.selectedExampleId);
    } else {
      $("jobStatus").textContent = "Ready for data upload.";
    }
    if (typeof refreshPlotGuide === "function") await refreshPlotGuide();
  } catch (err) {
    $("jobStatus").textContent = `Error loading plugin: ${err.message}`;
  }
}

document.addEventListener("DOMContentLoaded", init);
