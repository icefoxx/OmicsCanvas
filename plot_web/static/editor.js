const $ = (id) => document.getElementById(id);

const urlParams = new URLSearchParams(window.location.search);
const PLUGIN_ID = urlParams.get("plugin") || "group_heatmap";

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
  if (!state.autoUpdateEnabled) return;
  if (state.autoUpdateTimer) clearTimeout(state.autoUpdateTimer);
  state.autoUpdateTimer = setTimeout(() => {
    runDemoSilent();
  }, delayMs);
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
  if (!state.pluginId || state.isUpdating) return;
  setStageOverlay(true);
  try {
    const payload = { params: sanitizeParamsForRun(state.params) };
    if (state.selectedExampleId) payload.example_id = state.selectedExampleId;
    const result = await api(`/api/plugins/${state.pluginId}/run-demo`, {
      method: "POST",
      body: JSON.stringify(payload),
      headers: { "Content-Type": "application/json" }
    });
    if (result.status === "completed" && result.outputs) {
      renderDownloads(result.outputs);
      if (result.outputs.preview) {
        await updateInstantPreview(result.outputs);
      }
      $("jobStatus").textContent = `Updated figure (${new Date().toLocaleTimeString()})`;
    } else {
      const errObj = result.error && typeof result.error === "object" ? result.error : null;
      const detail =
        (errObj && (errObj.detail || errObj.error)) ||
        result.detail ||
        (typeof result.error === "string" ? result.error : null) ||
        result.message ||
        result.status ||
        "unknown error";
      $("jobStatus").textContent = `Auto update paused: ${detail}`;
    }
  } catch (err) {
    $("jobStatus").textContent = `Auto update paused: ${err.message}`;
  } finally {
    setStageOverlay(false);
  }
}

function updatePreviewImage(path) {
  const img = $("preview");
  const plotlyBox = $("plotlyPreview");
  const empty = $("emptyCanvas");
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

async function updateInstantPreview(outputs = {}) {
  const rendered = await renderPlotlyPreview(outputs);
  if (!rendered && outputs.preview) updatePreviewImage(outputs.preview);
}

async function renderPlotlyPreview(outputs = {}) {
  const plotlyBox = $("plotlyPreview");
  const img = $("preview");
  const empty = $("emptyCanvas");
  if (!plotlyBox || !outputs.json || !window.Plotly) return false;
  try {
    const sep = outputs.json.includes("?") ? "&" : "?";
    const figure = await api(`${outputs.json}${sep}t=${Date.now()}`);
    const spec = figure?.plotly;
    if (!spec?.data?.length) return false;
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
  if (visible) {
    img.style.display = mode === "plotly" ? "none" : "block";
    if (plotlyBox) plotlyBox.classList.toggle("hidden", mode !== "plotly");
    if (empty) empty.style.display = "none";
  } else {
    img.style.display = "none";
    if (plotlyBox) plotlyBox.classList.add("hidden");
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

function ensureExportItems(container) {
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

function renderDownloads(outputs) {
  const container = $("downloadLinks");
  const quickContainer = $("quickDownloads");
  const headerBox = $("headerExportLinks");
  const empty = $("exportMenuEmpty");
  const map = normalizeOutputMap(outputs || {});
  state.lastOutputs = outputs || {};

  // Primary formats live ONLY in the top Export dropdown (+ export tab clone)
  const rows = ensureExportItems(quickContainer);
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
      row.removeAttribute("aria-disabled");
      row.tabIndex = 0;
    } else {
      row.className = "export-item is-disabled";
      row.href = "#";
      row.removeAttribute("download");
      row.removeAttribute("target");
      row.title = "Not available yet — run Demo / Run Plot first";
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
      (k) => !["svg", "pdf", "png", "tiff", "tif"].includes(k)
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
      : "Run Demo or Run Plot first — then SVG / PDF / PNG become active.";
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
    if (raw.type === "integer") out.type = "number";
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
    integer: "number",
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
  return out;
}

function syncParamsFromJson() {
  const el = $("paramsText");
  if (!el) return;
  const text = el.value.trim();
  if (!text) {
    state.params = {};
    return;
  }
  try {
    state.params = JSON.parse(text);
  } catch (err) {}
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

function renderInputForControl(control) {
  const value = state.params[control.key] !== undefined ? state.params[control.key] : control.default;

  if (control.type === "boolean") {
    const label = document.createElement("label");
    label.className = "switch-row";
    label.innerHTML = `
      <input type="checkbox" ${value ? "checked" : ""} />
      <span class="slider"></span>
      <span class="switch-label">${control.label}</span>
    `;
    const input = label.querySelector("input");
    input.onchange = () => {
      state.params[control.key] = input.checked;
      syncJsonFromParams();
      triggerAutoUpdate(50);
    };
    return label;
  }

  if (control.key.toLowerCase().includes("palette")) {
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

  if (control.type === "number") {
    const wrap = document.createElement("div");
    wrap.className = "range-control";
    const range = document.createElement("input");
    range.type = "range";
    range.min = "0";
    range.max = control.key.includes("dpi") ? "600" : "100";
    range.step = control.key.includes("alpha") ? "0.05" : "1";
    range.value = value !== "" && value !== undefined ? String(value) : "10";

    const badge = document.createElement("span");
    badge.className = "range-badge";
    badge.textContent = range.value;

    range.oninput = () => {
      badge.textContent = range.value;
      state.params[control.key] = parseFloat(range.value);
      syncJsonFromParams();
      triggerAutoUpdate(100);
    };

    wrap.appendChild(range);
    wrap.appendChild(badge);
    return wrap;
  }

  if (control.type === "color") {
    const input = document.createElement("input");
    input.type = "color";
    input.value = typeof value === "string" && value.startsWith("#") ? value : "#3B82F6";
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
 *   data | plot | theme | axes | title | legend | canvas | export
 *
 * - data / plot  → plot-specific (from schema)
 * - theme/axes/title/legend/canvas → common UI (always present) + matching schema keys
 */
const EDITOR_TABS = ["data", "plot", "theme", "axes", "title", "legend", "canvas", "export"];

/** Shared aesthetic fields always shown under common tabs (written into state.params). */
const COMMON_CONTROLS = {
  axes: [
    { key: "xlab", label: "X axis title", type: "string", help: "Label for the horizontal axis" },
    { key: "xlab_show", label: "Show X title", type: "boolean", default: true },
    { key: "x_axis_text_size", label: "X tick size", type: "number", default: 10 },
    { key: "x_axis_text_angle", label: "X tick angle", type: "number", default: 0 },
    { key: "ylab", label: "Y axis title", type: "string", help: "Label for the vertical axis" },
    { key: "ylab_show", label: "Show Y title", type: "boolean", default: true },
    { key: "y_axis_text_size", label: "Y tick size", type: "number", default: 10 },
    { key: "y_axis_text_angle", label: "Y tick angle", type: "number", default: 0 },
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
    { key: "legend_title", label: "Legend title", type: "string" },
    { key: "legend_text_size", label: "Legend text size", type: "number", default: 10 },
    { key: "legend_title_size", label: "Legend title size", type: "number", default: 11 },
  ],
  canvas: [
    { key: "width", label: "Width", type: "number", default: 8, help: "Figure width (inches unless plugin uses px)" },
    { key: "height", label: "Height", type: "number", default: 6 },
    { key: "dpi", label: "DPI", type: "number", default: 300 },
    { key: "font_family", label: "Font family", type: "string", default: "sans" },
    { key: "base_size", label: "Base font size", type: "number", default: 11 },
    { key: "panel_background", label: "Panel background", type: "color", default: "#FFFFFF" },
    { key: "plot_background", label: "Plot background", type: "color", default: "#FFFFFF" },
    { key: "grid_show", label: "Show grid", type: "boolean", default: true },
    { key: "grid_color", label: "Grid color", type: "color", default: "#E5E7EB" },
  ],
};

/**
 * Bucket schema controls into editor tabs.
 * Common buckets: axes | title | legend | canvas | theme
 * Plot-specific: data | plot
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

  // --- Axes (common) ---
  if (
    /column_name|col_name|column_label|column_text|column_label_position|col_label/.test(key) ||
    /row_name|row_label_position|row_text/.test(key) ||
    /(^|_)(xlab|ylab|x_title|y_title|x_label|y_label|x_axis|y_axis|xlim|ylim|x_min|y_min|x_max|y_max|x_text|y_text|x_tick|y_tick|x_break|y_break|x_expand|y_expand|x_grid|y_grid|x_angle|y_angle)(_|$)/.test(key) ||
    /^axis_/.test(key) ||
    key.includes("axis_line") ||
    key.includes("axis_tick") ||
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
    (key.includes("margin") && !key.includes("label")) ||
    key.includes("background") ||
    key.includes("panel_background") ||
    key.includes("plot_background") ||
    key.includes("panel_border") ||
    key.includes("grid_show") ||
    key.includes("grid_color") ||
    key.includes("grid_major") ||
    key.includes("grid_minor") ||
    key === "grid" ||
    /(^|_)grid(_|$)/.test(key)
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
  counts.axes = (counts.axes || 0) + COMMON_CONTROLS.axes.length;
  counts.title = (counts.title || 0) + COMMON_CONTROLS.title.length;
  counts.legend = (counts.legend || 0) + COMMON_CONTROLS.legend.length;
  counts.canvas = (counts.canvas || 0) + COMMON_CONTROLS.canvas.length;

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
    if (tab === "plot" && !(counts.plot > 0)) btn.classList.add("is-dim");
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
  const head = (COMMON_CONTROLS[tab] || []).map((spec) => schemaByKey[spec.key] || makeVirtualControl(spec));
  const tail = orderedSchema.filter((c) => !commonFirst.includes(c.key));
  return [...head, ...tail];
}

function appendControlGroup(area, title, controls, { open = true } = {}) {
  if (!controls?.length) return;
  const group = document.createElement("details");
  group.className = "control-group";
  group.open = open;
  group.innerHTML = `<summary>${title}</summary>`;
  controls.forEach((control) => {
    const row = document.createElement("label");
    row.className = `control-row control-${control.type || "string"}`;
    if (control.virtual) row.classList.add("is-common-control");
    const required = control.required ? `<span class="required">*</span>` : "";
    const badge = control.virtual ? `<span class="common-badge" title="Standard field (all plots)">common</span>` : "";
    row.innerHTML = `<span class="control-label-line"><span>${control.label}${required}</span>${badge}</span>`;
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
      renderParamContentArea();
    };
  });
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
    .map((c) => `<span class="theme-swatch" style="background:${c}" title="${c}"></span>`)
    .join("");
  const active = themeState.activeId === p.id ? "is-active" : "";
  const badge = recommended ? `<span class="theme-badge">rec</span>` : "";
  const meta = [p.journal, p.family || p.catalog, `${p.n_colors || colors.length}c`]
    .filter(Boolean)
    .join(" · ");
  return `
    <button type="button" class="theme-palette-card ${active}" data-palette-id="${p.id}" title="Click to apply">
      <div class="theme-palette-head">
        <strong>${p.name || p.id}</strong>
        ${badge}
      </div>
      <div class="theme-swatch-row">${swatches}</div>
      <div class="theme-palette-meta">${meta}${p.reason ? ` · ${p.reason}` : ""}</div>
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
      return `<option value="${name}" ${sel}>${name} (${j.count || "?"})</option>`;
    })
    .join("");

  host.innerHTML = `
    <div class="theme-panel">
      <div class="theme-panel-intro">
        <strong>Palette catalog</strong>
        <p>Click a palette to apply. Sources: classic built-ins, AMFE, and
          <a href="https://github.com/lcpmgh/colors" target="_blank" rel="noopener">lcpmgh/colors</a> (MIT).
          Catalog: ${total} palettes.</p>
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
        ${themeState.status ? `<div class="theme-status">${themeState.status}</div>` : ""}
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
        <div class="theme-section-title">Browse palettes (${items.length}${items.length >= 80 ? "+" : ""})</div>
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

  // ---- THEME (common color catalog) ----
  if (tab === "theme") {
    const intro = document.createElement("div");
    intro.className = "param-tab-intro";
    intro.innerHTML = `<strong>Theme &amp; colors</strong><p>Shared across all plots. Click a palette to apply. Plot-specific color fields (if any) are listed below.</p>`;
    area.appendChild(intro);
    const colorControls = controlsForTab("theme").filter((c) => c.key !== "theme_palette_id");
    if (colorControls.length) {
      appendControlGroup(area, "Plot color parameters", colorControls, { open: true });
    }
    renderThemePanel(area);
    return;
  }

  // ---- DATA (plot-specific) ----
  if (tab === "data") {
    const intro = document.createElement("div");
    intro.className = "param-tab-intro";
    intro.innerHTML = `<strong>Data</strong><p>Upload and map columns for <code>${state.pluginId || "this plot"}</code>.</p>`;
    area.appendChild(intro);

    const dataCard = document.createElement("div");
    dataCard.className = "chi-card-body";
    dataCard.style.cssText =
      "padding:16px; background:#ffffff; border:1px solid #e2e8f0; border-radius:8px; display:flex; flex-direction:column; gap:12px; margin-bottom:16px;";
    const selectedFile = state.customFileName || null;
    dataCard.innerHTML = `
      <div class="chi-action-row">
        <span class="chi-action-label">select-file</span>
        <label class="chi-icon-btn chi-btn-mint" title="Select data file" style="cursor:pointer; position:relative;">
          📁
          <input type="file" id="loadDataFileInput" accept=".csv,.tsv,.txt,.xlsx,.xlsm,application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" style="position:absolute; inset:0; opacity:0; cursor:pointer;" />
        </label>
      </div>
      ${selectedFile ? `<div style="font-size:11px; font-weight:700; color:#15803d; background:#f0fdf4; border:1px solid #bbf7d0; padding:6px 10px; border-radius:4px;">📁 ${selectedFile}</div>` : ""}
      <div class="chi-action-row">
        <span class="chi-action-label">reload</span>
        <button type="button" class="chi-icon-btn chi-btn-mint" id="loadDataReloadBtn" title="Reload dataset">⚡</button>
      </div>
      <div class="chi-action-row">
        <span class="chi-action-label">view data</span>
        <button type="button" class="chi-icon-btn chi-btn-grey" id="loadDataViewBtn" title="View dataset table">👁️</button>
      </div>
    `;
    area.appendChild(dataCard);

    const fileInput = dataCard.querySelector("#loadDataFileInput");
    if (fileInput) {
      fileInput.onchange = (e) => {
        const file = e.target.files[0];
        if (file) {
          state.customFileName = file.name;
          runDemoSilent();
          renderParamContentArea();
        }
      };
    }
    const reloadBtn = dataCard.querySelector("#loadDataReloadBtn");
    if (reloadBtn) reloadBtn.onclick = () => runDemoSilent();
    const viewBtn = dataCard.querySelector("#loadDataViewBtn");
    if (viewBtn) {
      viewBtn.onclick = () => {
        const drawer = $("stageDataDrawer");
        if (drawer) drawer.open = true;
      };
    }

    const dataControls = controlsForTab("data");
    if (dataControls.length) {
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
    intro.innerHTML = `<strong>Plot options</strong><p>Parameters unique to <code>${state.pluginId || "this plot"}</code> (cells, rules, layers, clustering, interaction…).</p>`;
    area.appendChild(intro);

    const plotControls = controlsForTab("plot");
    if (!plotControls.length) {
      area.insertAdjacentHTML(
        "beforeend",
        `<div class="empty muted" style="padding:12px;font-size:12px;">This plot has no extra options beyond data + common axes/title/legend/theme/canvas.</div>`
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
    textarea.value = JSON.stringify(state.params, null, 2);
    textarea.style.cssText = "width:100%; height:220px; font-family:monospace; font-size:11px; padding:10px;";
    textarea.oninput = () => {
      syncParamsFromJson();
      triggerAutoUpdate(300);
    };
    group.appendChild(textarea);
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
        blurb: "Shared X/Y labels and ticks for every plot. Extra axis fields from this plugin appear below the common block.",
      },
      title: {
        title: "Title",
        blurb: "Figure title / subtitle — same controls across plots.",
      },
      legend: {
        title: "Legend",
        blurb: "Legend visibility and placement — consistent across plots.",
      },
      canvas: {
        title: "Canvas",
        blurb: "Size, DPI, fonts, panel/grid — consistent across plots.",
      },
    };
    const meta = labels[tab];
    const intro = document.createElement("div");
    intro.className = "param-tab-intro";
    intro.innerHTML = `<strong>${meta.title}</strong><p>${meta.blurb}</p>`;
    area.appendChild(intro);

    const merged = mergeCommonWithSchema(tab);
    const commonKeys = new Set((COMMON_CONTROLS[tab] || []).map((s) => s.key));
    const commonPart = merged.filter((c) => commonKeys.has(c.key) || c.virtual);
    const extraPart = merged.filter((c) => !commonKeys.has(c.key) && !c.virtual);

    appendControlGroup(area, "Common (all plots)", commonPart, { open: true });
    if (extraPart.length) {
      appendControlGroup(area, `Extra for ${state.pluginId || "this plot"}`, extraPart, { open: true });
    } else {
      area.insertAdjacentHTML(
        "beforeend",
        `<div class="empty muted" style="padding:8px 4px;font-size:11.5px;">No plugin-specific ${tab} fields — common controls above still apply when the plot reads them.</div>`
      );
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
        ${columns.map((col) => `<th>${col}</th>`).join("")}
      </tr>
    </thead>
    <tbody>
      ${preview.preview_rows.slice(0, 50).map((row) => {
        const rowId = String(row[labelColumn] ?? "");
        const isSelected = state.selectedRows.has(rowId);
        return `
          <tr class="${isSelected ? "row-selected" : ""}">
            <td><input type="checkbox" ${isSelected ? "checked" : ""} class="stage-row-check" data-id="${rowId}" /></td>
            ${columns.map((col) => `<td>${row[col] ?? ""}</td>`).join("")}
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

  renderParamContentArea();
  renderStageDataDrawer();
  $("jobStatus").textContent = "Demo dataset pre-loaded. Tweak any parameters on the right sidebar.";
}

async function runDemo(options = {}) {
  const reloadDemo = options.reloadDemo !== false;
  if (!state.pluginId) return;
  if ($("runDemoButton")) $("runDemoButton").disabled = true;
  if ($("runButton")) $("runButton").disabled = true;
  $("jobStatus").textContent = "Rendering figure...";
  $("downloadLinks").innerHTML = "";
  setStageOverlay(true);
  try {
    // Demo button reloads clean default params; Run Plot keeps sidebar edits
    if (reloadDemo && state.demo && !state.selectedExampleId) {
      loadDemoIntoUi();
    }
    const payload = { params: sanitizeParamsForRun(state.params) };
    if (state.selectedExampleId) payload.example_id = state.selectedExampleId;
    const result = await api(`/api/plugins/${state.pluginId}/run-demo`, {
      method: "POST",
      body: JSON.stringify(payload),
      headers: { "Content-Type": "application/json" }
    });
    if (result.status === "completed" && result.outputs) {
      $("jobStatus").textContent = `completed: Figure rendered.`;
      renderDownloads(result.outputs);
      if (result.outputs.preview) {
        await updateInstantPreview(result.outputs);
      }
    } else {
      const errObj = result.error && typeof result.error === "object" ? result.error : null;
      const detail =
        (errObj && (errObj.detail || errObj.error)) ||
        result.detail ||
        (typeof result.error === "string" ? result.error : null) ||
        result.message ||
        result.status ||
        "unknown error";
      $("jobStatus").textContent = `Render failed: ${detail}`;
      if (result.outputs) renderDownloads(result.outputs);
    }
  } catch (error) {
    $("jobStatus").textContent = `Render failed: ${error.message}`;
  } finally {
    setStageOverlay(false);
    if ($("runDemoButton")) $("runDemoButton").disabled = !(state.demo || state.examples.length);
    if ($("runButton")) $("runButton").disabled = false;
  }
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
      }
    };
  });

  wireFloatToolsDrag();

  const toggle = $("autoUpdateToggle");
  if (toggle) {
    toggle.onchange = () => {
      state.autoUpdateEnabled = toggle.checked;
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

  select.onchange = async () => {
    const eid = select.value || null;
    state.selectedExampleId = eid;
    $("jobStatus").textContent = eid ? `Loading preset “${eid}”…` : "Loading default demo…";
    try {
      if (eid) {
        // Fetch example bundle metadata when available; otherwise run-demo with example_id
        try {
          const rec = await api(`/api/plugins/${state.pluginId}/examples/${encodeURIComponent(eid)}`);
          // Prefer example params if present
          if (rec?.params) {
            let raw = rec.params;
            if (raw.params && typeof raw.params === "object") raw = raw.params;
            state.params = { ...raw };
            syncJsonFromParams();
          }
          if (rec?.inputs || rec?.files) {
            // Keep demo shell but swap params; run-demo uses example_id for files
            state.demo = state.demo || { files: {}, params: {} };
          }
        } catch (_) {
          // Example detail optional — run-demo with example_id is enough
        }
      } else if (state.demo) {
        setParamsFromDemo(state.demo);
      }
      renderParamContentArea();
      await runDemoSilent();
    } catch (err) {
      $("jobStatus").textContent = `Preset failed: ${err.message}`;
    }
  };
}

async function init() {
  setupParamNavEvents();
  setupStageTools();
  wireExportMenu();

  if ($("runDemoButton")) {
    $("runDemoButton").onclick = () => {
      state.selectedExampleId = null;
      const sel = $("exampleSelect");
      if (sel) sel.value = "";
      runDemo({ reloadDemo: true });
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

    $("pluginName").textContent = detail.display_name || detail.name || state.pluginId;
    $("pluginDescription").textContent = detail.description || "";
    document.title = `${detail.display_name || state.pluginId} | Plot Editor`;

    renderSchema(detail.params_schema || detail.parameters);
    wireExampleSelect();

    if (state.demo && Object.keys(state.demo.files || {}).length) {
      await runDemo();
    } else if (state.examples.length) {
      // No default demo files but examples exist — run first example
      state.selectedExampleId = state.examples[0].id || state.examples[0].name;
      const sel = $("exampleSelect");
      if (sel) sel.value = state.selectedExampleId || "";
      await runDemoSilent();
    } else {
      $("jobStatus").textContent = "Ready for data upload.";
    }
  } catch (err) {
    $("jobStatus").textContent = `Error loading plugin: ${err.message}`;
  }
}

document.addEventListener("DOMContentLoaded", init);
