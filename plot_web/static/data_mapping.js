/* Dataset-aware column mapping and filtering for Plot Studio. */
const LEVEL_CAP = 80;
const PREVIEW_PAGE = 50;

const MAPPING_LABELS = {
  plot_mode: "Plot mode",
  x_column: "X-axis column",
  y_column: "Y-axis column",
  id_column: "Row / cell ID column",
  group_column: "Group / cluster column",
  split_column: "Split / facet column",
  feature_columns: "Feature column(s)",
  feature: "Feature column(s)",
  stat_plot_column: "Composition column",
  composition_column: "Composition column",
};

const MAPPING_HELP = {
  x_column: "Usually an embedding or numeric axis such as dim1 or UMAP_1.",
  y_column: "Usually an embedding or numeric axis such as dim2 or UMAP_2.",
  id_column: "Unique row identifier used for selection and highlights.",
  group_column: "Categorical annotation used to color or group observations.",
  split_column: "Optional facet variable such as sample or condition.",
  feature_columns: "Numeric feature columns to map as expression or color.",
  feature: "Numeric feature columns to map as expression or color.",
};

const HIDDEN_DATA_KEYS = new Set([
  "rows_include",
  "rows_exclude",
  "groups_include",
  "groups_exclude",
  "filter_column",
  "selected_ids",
  "cells_include",
  "cells_exclude",
]);

function primaryDataset() {
  const files = state.inputPreview?.files || {};
  const preferred = files.file || files.input || files.upper || Object.values(files)[0];
  return preferred || null;
}

function datasetColumns() {
  const ds = primaryDataset();
  return (ds?.columns || []).filter(Boolean);
}

function columnMetaMap() {
  const ds = primaryDataset() || {};
  const map = {};
  (ds.column_meta || []).forEach((item) => {
    if (item?.name) map[item.name] = item;
  });
  (ds.columns || []).forEach((name) => {
    if (!map[name]) map[name] = { name, kind: "text", high_cardinality: false, levels: null };
  });
  (ds.numeric_columns || []).forEach((name) => {
    if (map[name] && map[name].kind === "text") map[name].kind = "numeric";
  });
  (ds.categorical_columns || []).forEach((name) => {
    if (map[name] && map[name].kind === "text") map[name].kind = "categorical";
  });
  return map;
}

function columnKind(name) {
  return columnMetaMap()[name]?.kind || "text";
}

function preferColumns(role) {
  const cols = datasetColumns();
  const meta = columnMetaMap();
  const kindOf = (name) => meta[name]?.kind || "text";
  if (role === "numeric") {
    return [...cols].sort((a, b) => Number(kindOf(a) !== "numeric") - Number(kindOf(b) !== "numeric"));
  }
  if (role === "categorical") {
    return [...cols].sort((a, b) => {
      const score = (n) => (kindOf(n) === "categorical" ? 0 : kindOf(n) === "id" ? 2 : 1);
      return score(a) - score(b);
    });
  }
  if (role === "id") {
    return [...cols].sort((a, b) => Number(kindOf(a) !== "id") - Number(kindOf(b) !== "id"));
  }
  return cols;
}

function mappingRole(key) {
  const k = String(key || "").toLowerCase();
  if (k === "x_column" || k === "y_column") return "numeric";
  if (k === "id_column") return "id";
  if (k.includes("feature")) return "numeric";
  if (k.includes("group") || k.includes("split") || k.includes("cluster") || k.includes("composition") || k === "stat_plot_column") return "categorical";
  return "all";
}

function isMultiColumn(control) {
  const k = String(control.key || "").toLowerCase();
  return control.type === "columns" || k.endsWith("_columns") || k === "features" || k === "markers" || k === "genes";
}

function currentPlotMode() {
  return String(state.params.plot_mode || state.params.plot_kind || "").toLowerCase();
}

function mappingVisible(key) {
  const mode = currentPlotMode();
  const k = String(key || "").toLowerCase();
  if (!mode) return true;
  const featureMode = /feature|expression|gradient|coexpression|blend/.test(mode);
  const groupMode = /group|^$/.test(mode) || mode === "group";
  if (k.includes("feature")) return featureMode || /coexpression|blend/.test(mode);
  if (k === "group_column") return !featureMode || groupMode || /coexpression/.test(mode);
  if (k === "stat_plot_column" || k === "composition_column") return /group|stat|pie|composition/.test(mode) || !featureMode;
  return true;
}

function applySuggestionsIfEmpty() {
  const ds = primaryDataset();
  const suggested = ds?.suggested_mappings || {};
  Object.entries(suggested).forEach(([key, value]) => {
    if (!value) return;
    if (state.params[key] === undefined || state.params[key] === null || state.params[key] === "") {
      state.params[key] = value;
    }
  });
  if (!state.params.filter_column) {
    const cats = ds?.categorical_columns || [];
    const preferred = ["sample", "orig.ident", "condition", "group"].find((name) => (ds?.columns || []).includes(name));
    state.params.filter_column = preferred || cats[0] || "";
  }
}

function reconcileMappingsWithDataset() {
  const cols = new Set(datasetColumns());
  if (!cols.size) return;
  ["x_column", "y_column", "id_column", "group_column", "split_column", "stat_plot_column", "composition_column", "filter_column", "feature"].forEach((key) => {
    const value = state.params[key];
    if (typeof value === "string" && value && !cols.has(value)) state.params[key] = "";
  });
  if (Array.isArray(state.params.feature_columns)) {
    state.params.feature_columns = state.params.feature_columns.filter((name) => cols.has(String(name)));
  }
  const filterCol = state.params.filter_column || state.params.group_column;
  const levels = new Set(columnMetaMap()[filterCol]?.levels || []);
  const keep = (list) => (Array.isArray(list) ? list.filter((v) => !levels.size || levels.has(String(v))) : []);
  if (Array.isArray(state.params.groups_include)) state.params.groups_include = keep(state.params.groups_include);
  if (Array.isArray(state.params.groups_exclude)) state.params.groups_exclude = keep(state.params.groups_exclude);
}

function asArray(value) {
  if (Array.isArray(value)) return value.map(String).filter(Boolean);
  if (value === undefined || value === null || value === "") return [];
  return String(value).split(/[,\s]+/).filter(Boolean);
}

function createSearchSelect({ value, options, groups, allowEmpty, multiple, placeholder, onChange }) {
  const wrap = document.createElement("div");
  wrap.className = "col-select";
  const selected = multiple ? asArray(value) : (value || "");
  const chips = document.createElement("div");
  chips.className = "col-select-chips";
  const input = document.createElement("input");
  input.type = "search";
  input.className = "col-select-input";
  input.placeholder = placeholder || "Search…";
  if (!multiple && selected) input.value = selected;
  const menu = document.createElement("div");
  menu.className = "col-select-menu hidden";

  const grouped = groups || { All: options || [] };

  const commitSingle = (next) => {
    input.value = next || "";
    menu.classList.add("hidden");
    onChange(next || "");
  };

  const commitMulti = (next) => {
    onChange(next);
    draw();
  };

  const draw = () => {
    chips.innerHTML = "";
    if (multiple) {
      asArray(stateValue()).forEach((item) => {
        const chip = document.createElement("button");
        chip.type = "button";
        chip.className = "level-chip";
        chip.textContent = `${item} ×`;
        chip.onclick = (event) => {
          event.preventDefault();
          commitMulti(asArray(stateValue()).filter((v) => v !== item));
        };
        chips.appendChild(chip);
      });
    }
  };

  const stateValue = () => (multiple ? asArray(valueRef()) : valueRef());
  const valueRef = () => (multiple ? wrap._value : wrap._value);
  wrap._value = selected;

  const renderMenu = () => {
    const q = input.value.trim().toLowerCase();
    menu.innerHTML = "";
    if (allowEmpty && !multiple) {
      const none = document.createElement("button");
      none.type = "button";
      none.className = "col-select-option";
      none.textContent = "None";
      none.onclick = () => {
        wrap._value = "";
        commitSingle("");
      };
      menu.appendChild(none);
    }
    Object.entries(grouped).forEach(([label, items]) => {
      const filtered = (items || []).filter((item) => !q || String(item).toLowerCase().includes(q));
      if (!filtered.length) return;
      const head = document.createElement("div");
      head.className = "col-select-group";
      head.textContent = label;
      menu.appendChild(head);
      filtered.slice(0, 200).forEach((item) => {
        const opt = document.createElement("button");
        opt.type = "button";
        opt.className = "col-select-option";
        opt.textContent = item;
        if (multiple && asArray(wrap._value).includes(item)) opt.classList.add("is-active");
        opt.onclick = () => {
          if (multiple) {
            const cur = asArray(wrap._value);
            wrap._value = cur.includes(item) ? cur.filter((v) => v !== item) : [...cur, item];
            commitMulti(wrap._value);
          } else {
            wrap._value = item;
            commitSingle(item);
          }
        };
        menu.appendChild(opt);
      });
    });
    if (!menu.childElementCount) {
      menu.innerHTML = `<div class="col-select-empty">No matches</div>`;
    }
  };

  input.onfocus = () => {
    if (!multiple) input.value = "";
    menu.classList.remove("hidden");
    renderMenu();
  };
  input.oninput = renderMenu;
  input.onblur = () => {
    setTimeout(() => {
      menu.classList.add("hidden");
      if (!multiple) input.value = wrap._value || "";
    }, 150);
  };

  wrap.appendChild(chips);
  wrap.appendChild(input);
  wrap.appendChild(menu);
  draw();
  wrap.setValue = (next) => {
    wrap._value = multiple ? asArray(next) : next || "";
    if (!multiple) input.value = wrap._value;
    draw();
  };
  return wrap;
}

function groupedColumnOptions(role) {
  const cols = preferColumns(role);
  const meta = columnMetaMap();
  const suggested = [];
  const numeric = [];
  const categorical = [];
  const rest = [];
  cols.forEach((name) => {
    const kind = meta[name]?.kind || "text";
    if (role === "numeric" && kind === "numeric") suggested.push(name);
    else if (role === "categorical" && kind === "categorical") suggested.push(name);
    else if (role === "id" && kind === "id") suggested.push(name);
    if (kind === "numeric") numeric.push(name);
    else if (kind === "categorical") categorical.push(name);
    else rest.push(name);
  });
  const groups = {};
  if (suggested.length) groups.Suggested = suggested;
  if (numeric.length) groups.Numeric = numeric;
  if (categorical.length) groups.Categorical = categorical;
  groups["All columns"] = datasetColumns();
  return groups;
}

function setParamValue(key, value) {
  if (value === "" || value === null || (Array.isArray(value) && !value.length)) {
    delete state.params[key];
  } else {
    state.params[key] = value;
  }
  syncJsonFromParams();
  triggerAutoUpdate(250);
}

function renderMappingRow(parent, control) {
  const key = control.key;
  if (!mappingVisible(key)) return;
  const row = document.createElement("label");
  row.className = "control-row";
  const required = control.required ? `<span class="required">*</span>` : "";
  const label = MAPPING_LABELS[key] || control.label || labelize(key);
  row.innerHTML = `<span>${escapeHtml(label)}${required}</span>`;
  const role = mappingRole(key);
  const multiple = isMultiColumn(control);
  const groups = groupedColumnOptions(role);
  const select = createSearchSelect({
    value: state.params[key],
    groups,
    allowEmpty: !control.required,
    multiple,
    placeholder: multiple ? "Select columns…" : "Search columns…",
    onChange: (next) => {
      setParamValue(key, next);
      if (control.required && !next) showMappingError(row, `Select a ${label.replace(" *", "")}.`);
      else clearMappingError(row);
      if (typeof refreshPlotGuide === "function") refreshPlotGuide();
    },
  });
  row.appendChild(select);
  const help = MAPPING_HELP[key] || control.help;
  if (help) {
    const small = document.createElement("small");
    small.textContent = help;
    row.appendChild(small);
  }
  if (control.required && !state.params[key]) showMappingError(row, `Select a ${label.replace("*", "").trim()}.`);
  parent.appendChild(row);
}

function showMappingError(row, text) {
  clearMappingError(row);
  const err = document.createElement("small");
  err.className = "mapping-error";
  err.textContent = text;
  row.appendChild(err);
}

function clearMappingError(row) {
  row.querySelectorAll(".mapping-error").forEach((el) => el.remove());
}

function filterLevels() {
  const col = state.params.filter_column || "";
  const meta = columnMetaMap()[col];
  if (!col) return { levels: [], high: false };
  if (meta?.high_cardinality) return { levels: [], high: true };
  return { levels: meta?.levels || uniquePreviewValues(col), high: false };
}

function uniquePreviewValues(column) {
  const rows = primaryDataset()?.preview_rows || [];
  const values = [];
  const seen = new Set();
  rows.forEach((row) => {
    const value = String(row[column] ?? "").trim();
    if (value && !seen.has(value)) {
      seen.add(value);
      values.push(value);
    }
  });
  return values.slice(0, LEVEL_CAP);
}

function includedCount() {
  const ds = primaryDataset();
  const rows = ds?.preview_rows || [];
  const idCol = state.params.id_column || (ds?.columns || [])[0];
  const filterCol = state.params.filter_column || "";
  const include = asArray(state.params.groups_include);
  const exclude = asArray(state.params.groups_exclude);
  const selected = Array.from(state.selectedRows || []);
  let kept = rows;
  if (filterCol) {
    kept = kept.filter((row) => {
      const value = String(row[filterCol] ?? "");
      if (include.length && !include.includes(value)) return false;
      if (exclude.includes(value)) return false;
      return true;
    });
  }
  if (selected.length) {
    if (state.rowMode === "exclude") kept = kept.filter((row) => !state.selectedRows.has(String(row[idCol] ?? "")));
    else kept = kept.filter((row) => state.selectedRows.has(String(row[idCol] ?? "")));
  }
  const previewN = rows.length;
  const total = Number(ds?.row_count_estimate || previewN);
  const approx = previewN ? Math.round((kept.length / previewN) * total) : 0;
  return { kept: kept.length, previewN, total, approx };
}

function renderDataMappingPanel(area, dataControls) {
  applySuggestionsIfEmpty();
  reconcileMappingsWithDataset();
  const ds = primaryDataset();
  const nRows = ds?.row_count_estimate || ds?.preview_rows?.length || 0;
  const nCols = ds?.column_count || datasetColumns().length;
  const fileLabel = state.customFileName || ds?.filename || "Demo dataset";

  const datasetCard = area.querySelector(".chi-card-body");
  if (datasetCard && nCols) {
    const stats = document.createElement("div");
    stats.className = "dataset-stats";
    stats.textContent = `${fileLabel} · ${nRows.toLocaleString()} rows × ${nCols} columns`;
    datasetCard.appendChild(stats);
  }

  const mappingKeys = new Set(Object.keys(MAPPING_LABELS));
  const mappingControls = dataControls.filter((c) => mappingKeys.has(c.key) || c.type === "column" || c.type === "columns" || String(c.key).endsWith("_column") || String(c.key).endsWith("_columns"));
  const otherControls = dataControls.filter((c) => !HIDDEN_DATA_KEYS.has(c.key) && !mappingControls.includes(c));

  const mapping = document.createElement("details");
  mapping.className = "control-group";
  mapping.open = true;
  mapping.innerHTML = `<summary>Column Mapping</summary>
    <p class="guide-hint">Map columns from the loaded dataset to the visual encodings required by this plot.</p>`;
  const plotMode = dataControls.find((c) => c.key === "plot_mode");
  if (plotMode) {
    const row = document.createElement("label");
    row.className = "control-row";
    row.innerHTML = `<span>Plot mode</span>`;
    const node = renderInputForControl({ ...plotMode, label: "Plot mode" });
    const select = node.tagName === "SELECT" ? node : node.querySelector?.("select");
    if (select) {
      const prev = select.onchange;
      select.onchange = (event) => {
        if (typeof prev === "function") prev.call(select, event);
        renderParamContentArea();
      };
    }
    row.appendChild(node);
    mapping.appendChild(row);
  }
  mappingControls
    .filter((c) => c.key !== "plot_mode")
    .forEach((control) => renderMappingRow(mapping, control));
  area.appendChild(mapping);

  const filtering = document.createElement("details");
  filtering.className = "control-group";
  filtering.open = true;
  filtering.innerHTML = `<summary>Filtering</summary>
    <p class="guide-hint">Limit the data used for plotting by group values or row selection.</p>`;

  const filterRow = document.createElement("label");
  filterRow.className = "control-row";
  filterRow.innerHTML = `<span>Group column</span>`;
  filterRow.appendChild(createSearchSelect({
    value: state.params.filter_column || "",
    groups: groupedColumnOptions("categorical"),
    allowEmpty: true,
    placeholder: "Choose a categorical column…",
    onChange: (next) => {
      state.params.filter_column = next || "";
      state.params.groups_include = [];
      state.params.groups_exclude = [];
      syncJsonFromParams();
      triggerAutoUpdate(250);
      renderParamContentArea();
    },
  }));
  const filterHelp = document.createElement("small");
  filterHelp.textContent = "Choose a categorical column to filter by its available levels.";
  filterRow.appendChild(filterHelp);
  filtering.appendChild(filterRow);

  const { levels, high } = filterLevels();
  if (high) {
    filtering.insertAdjacentHTML("beforeend", `<p class="mapping-error">This column has too many unique values for a level picker. Use row selection in the dataset preview instead.</p>`);
  } else if (state.params.filter_column) {
    ["groups_include", "groups_exclude"].forEach((key) => {
      const row = document.createElement("label");
      row.className = "control-row";
      row.innerHTML = `<span>${key === "groups_include" ? "Include levels" : "Exclude levels"}</span>`;
      row.appendChild(createSearchSelect({
        value: state.params[key] || [],
        groups: { Levels: levels },
        multiple: true,
        placeholder: "Select…",
        onChange: (next) => {
          state.params[key] = next;
          syncJsonFromParams();
          triggerAutoUpdate(250);
          updateRowCountBadge();
        },
      }));
      filtering.appendChild(row);
    });
  }

  const counts = includedCount();
  const countBox = document.createElement("div");
  countBox.className = "row-count-box";
  countBox.id = "effectiveRowCount";
  countBox.innerHTML = `
    <strong>Rows</strong>
    <span>${escapeHtml(counts.approx.toLocaleString())} / ${escapeHtml(counts.total.toLocaleString())} included</span>
    <small>Select individual rows in the dataset preview below.</small>
    <button type="button" class="card-btn secondary" id="openPreviewBtn">Select rows in dataset preview ↓</button>
  `;
  filtering.appendChild(countBox);
  area.appendChild(filtering);

  countBox.querySelector("#openPreviewBtn").onclick = () => {
    const drawer = $("stageDataDrawer");
    if (drawer) {
      drawer.open = true;
      drawer.scrollIntoView({ behavior: "smooth", block: "start" });
    }
  };

  if (otherControls.length) {
    appendControlGroup(area, "Other data options", otherControls, { open: false });
  }
}

function updateRowCountBadge() {
  const el = $("effectiveRowCount");
  if (!el) return;
  const counts = includedCount();
  const span = el.querySelector("span");
  if (span) span.textContent = `${counts.approx.toLocaleString()} / ${counts.total.toLocaleString()} included`;
}

function idColumnName() {
  const ds = primaryDataset();
  return state.params.id_column || ds?.columns?.[0] || "";
}

function filteredPreviewRows() {
  const ds = primaryDataset();
  const rows = ds?.preview_rows || [];
  const q = String(state.previewSearch || "").trim().toLowerCase();
  if (!q) return rows;
  return rows.filter((row) => Object.values(row).some((value) => String(value).toLowerCase().includes(q)));
}

function renderDatasetPreview() {
  const box = $("stageTablePreview");
  const tools = $("stageRowSelector");
  if (!box) return;
  const ds = primaryDataset();
  if (!ds?.preview_rows?.length) {
    if (tools) tools.innerHTML = "";
    box.innerHTML = `<div class="empty muted">No dataset loaded for preview. Use Demo or upload a table.</div>`;
    return;
  }
  const rows = filteredPreviewRows();
  const total = Number(ds.row_count_estimate || ds.preview_rows.length);
  const columns = (ds.columns || []).slice(0, 18);
  const idCol = idColumnName();
  const page = Math.max(0, state.previewPage || 0);
  const start = page * PREVIEW_PAGE;
  const slice = rows.slice(start, start + PREVIEW_PAGE);
  const pages = Math.max(1, Math.ceil(rows.length / PREVIEW_PAGE));
  const counts = includedCount();

  if (tools) {
    tools.innerHTML = `
      <div class="dataset-preview-head">
        <div>
          <strong>Loaded Dataset</strong>
          <div class="dataset-stats">${escapeHtml(ds.filename || "dataset")} · ${total.toLocaleString()} rows × ${(ds.column_count || columns.length)} columns</div>
        </div>
        <input type="search" id="previewSearch" placeholder="Search rows…" value="${escapeHtml(state.previewSearch || "")}" />
      </div>
      <div class="stage-row-actions">
        <span>Showing ${slice.length ? start + 1 : 0}–${start + slice.length} of ${rows.length} preview rows · ${counts.approx.toLocaleString()} / ${total.toLocaleString()} included</span>
        <button type="button" id="stageRowAll">Select all</button>
        <button type="button" id="stageRowClear">Clear selection</button>
        <button type="button" id="stageRowReset">Reset filters</button>
      </div>
    `;
    tools.querySelector("#previewSearch").oninput = (event) => {
      state.previewSearch = event.target.value;
      state.previewPage = 0;
      renderDatasetPreview();
    };
    tools.querySelector("#stageRowAll").onclick = () => {
      rows.forEach((row) => state.selectedRows.add(String(row[idCol] ?? "")));
      commitRowSelection();
      triggerAutoUpdate(250);
      renderDatasetPreview();
      updateRowCountBadge();
    };
    tools.querySelector("#stageRowClear").onclick = () => {
      state.selectedRows.clear();
      commitRowSelection();
      triggerAutoUpdate(250);
      renderDatasetPreview();
      updateRowCountBadge();
    };
    tools.querySelector("#stageRowReset").onclick = () => {
      state.selectedRows.clear();
      state.previewSearch = "";
      state.params.groups_include = [];
      state.params.groups_exclude = [];
      commitRowSelection();
      syncJsonFromParams();
      triggerAutoUpdate(250);
      renderParamContentArea();
      renderDatasetPreview();
    };
  }

  box.innerHTML = `
    <div class="preview-table-wrap">
      <table>
        <thead>
          <tr>
            <th>✓</th>
            ${columns.map((col) => `<th>${escapeHtml(col)}</th>`).join("")}
          </tr>
        </thead>
        <tbody>
          ${slice.map((row) => {
            const rowId = String(row[idCol] ?? "");
            const selected = state.selectedRows.has(rowId);
            return `<tr class="${selected ? "row-selected" : ""}">
              <td><input type="checkbox" class="stage-row-check" data-id="${escapeHtml(rowId)}" ${selected ? "checked" : ""}></td>
              ${columns.map((col) => `<td>${escapeHtml(row[col])}</td>`).join("")}
            </tr>`;
          }).join("")}
        </tbody>
      </table>
    </div>
    <div class="preview-pager">
      <button type="button" id="previewPrev" ${page <= 0 ? "disabled" : ""}>Prev</button>
      <span>Page ${page + 1} / ${pages}</span>
      <button type="button" id="previewNext" ${page >= pages - 1 ? "disabled" : ""}>Next</button>
    </div>
  `;
  box.querySelectorAll(".stage-row-check").forEach((chk) => {
    chk.onchange = () => {
      const id = chk.dataset.id;
      if (chk.checked) state.selectedRows.add(id);
      else state.selectedRows.delete(id);
      commitRowSelection();
      triggerAutoUpdate(250);
      updateRowCountBadge();
      chk.closest("tr").classList.toggle("row-selected", chk.checked);
    };
  });
  box.querySelector("#previewPrev").onclick = () => {
    state.previewPage = Math.max(0, page - 1);
    renderDatasetPreview();
  };
  box.querySelector("#previewNext").onclick = () => {
    state.previewPage = Math.min(pages - 1, page + 1);
    renderDatasetPreview();
  };
}
