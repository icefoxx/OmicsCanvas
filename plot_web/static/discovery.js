/* Plot discovery UI — registry-driven Explore / Browse (phase 2). */
const Discovery = {
  taxonomy: { contexts: [] },
  browse: { categories: [], all_plots: [] },
  chartCategories: { groups: [] },
  pluginsById: {},
  view: "home", // home | browse | analysis | category | search | family
  browseCategory: "all",
  analysisContext: null,
  analysisTask: null,
  chartId: null,
  chartGroup: null,
  searchQuery: "",
  searchResults: [],
  recent: [],
  favorites: new Set(),
  dataSchema: { roles: [] },
  recommendations: [],
  familyPlot: null,
  familyStyles: [],
  familyStylesCache: {},
  styleLimit: 10,
};

const STYLE_PAGE = 10;

const ENTRY_MODES = [
  { id: "scenario", label: "Explore by Scenario", path: "/scenario" },
  { id: "category", label: "Browse by Chart Type", path: "/category" },
  { id: "browse", label: "All Plots", path: "/plots" },
];

function chartIcon(id) {
  const stroke = 'fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"';
  const icons = {
    violin: `<path d="M24 8c4 8 6 14 6 20a6 6 0 0 1-12 0c0-6 2-12 6-20z" ${stroke}/><path d="M18 26h12" ${stroke}/>`,
    density: `<path d="M6 36c6-2 8-18 12-18s5 10 9 10 5-16 9-16 4 16 6 20" ${stroke}/>`,
    histogram: `<path d="M8 36V22h6v14M18 36V12h6v24M28 36V18h6v18M38 36v-8h6v8" ${stroke}/>`,
    boxplot: `<path d="M24 8v8M24 32v8M16 16h16v16H16zM12 24h4M32 24h4" ${stroke}/>`,
    ridgeline: `<path d="M6 34c4-8 8-8 12 0 4-10 8-10 12 0 4-8 8-8 12 0M6 24c4-8 8-8 12 0 4-10 8-10 12 0 4-8 8-8 12 0" ${stroke}/>`,
    beeswarm: `<circle cx="18" cy="22" r="2.2" fill="currentColor"/><circle cx="24" cy="16" r="2.2" fill="currentColor"/><circle cx="30" cy="22" r="2.2" fill="currentColor"/><circle cx="22" cy="28" r="2.2" fill="currentColor"/><circle cx="28" cy="30" r="2.2" fill="currentColor"/><circle cx="16" cy="30" r="2.2" fill="currentColor"/>`,
    scatter: `<circle cx="14" cy="30" r="2.4" fill="currentColor"/><circle cx="22" cy="18" r="2.4" fill="currentColor"/><circle cx="30" cy="24" r="2.4" fill="currentColor"/><circle cx="36" cy="14" r="2.4" fill="currentColor"/>`,
    heatmap: `<rect x="8" y="8" width="10" height="10" rx="1" fill="currentColor" opacity=".9"/><rect x="20" y="8" width="10" height="10" rx="1" fill="currentColor" opacity=".45"/><rect x="32" y="8" width="10" height="10" rx="1" fill="currentColor" opacity=".7"/><rect x="8" y="20" width="10" height="10" rx="1" fill="currentColor" opacity=".35"/><rect x="20" y="20" width="10" height="10" rx="1" fill="currentColor" opacity=".8"/><rect x="32" y="20" width="10" height="10" rx="1" fill="currentColor" opacity=".25"/><rect x="8" y="32" width="10" height="10" rx="1" fill="currentColor" opacity=".55"/><rect x="20" y="32" width="10" height="10" rx="1" fill="currentColor" opacity=".3"/><rect x="32" y="32" width="10" height="10" rx="1" fill="currentColor" opacity=".95"/>`,
    correlogram: `<path d="M10 10h28v28H10z" ${stroke}/><path d="M10 24h28M24 10v28" ${stroke}/>`,
    bubble: `<circle cx="18" cy="28" r="7" ${stroke}/><circle cx="30" cy="18" r="10" ${stroke}/><circle cx="34" cy="32" r="4" ${stroke}/>`,
    connected_scatter: `<path d="M10 34l8-12 8 4 10-16" ${stroke}/><circle cx="10" cy="34" r="2.4" fill="currentColor"/><circle cx="18" cy="22" r="2.4" fill="currentColor"/><circle cx="26" cy="26" r="2.4" fill="currentColor"/><circle cx="36" cy="10" r="2.4" fill="currentColor"/>`,
    density_2d: `<ellipse cx="24" cy="24" rx="14" ry="10" ${stroke}/><ellipse cx="24" cy="24" rx="8" ry="5" ${stroke}/><ellipse cx="24" cy="24" rx="3" ry="2" ${stroke}/>`,
    barplot: `<path d="M10 36V18h6v18M20 36V10h6v26M30 36V22h6v14" ${stroke}/>`,
    radar: `<path d="M24 8l12 9-4.5 14h-15L12 17z" ${stroke}/><path d="M24 16l6 4.5-2.2 7h-7.6L18 20.5z" ${stroke}/>`,
    wordcloud: `<text x="8" y="22" font-size="12" fill="currentColor" font-weight="800">Aa</text><text x="26" y="18" font-size="8" fill="currentColor">bb</text><text x="16" y="36" font-size="10" fill="currentColor">Cc</text>`,
    parallel: `<path d="M12 8v32M24 8v32M36 8v32M12 16l12 8 12-12M12 30l12-6 12 10" ${stroke}/>`,
    lollipop: `<path d="M14 36V18M24 36V12M34 36V22" ${stroke}/><circle cx="14" cy="18" r="3.5" fill="currentColor"/><circle cx="24" cy="12" r="3.5" fill="currentColor"/><circle cx="34" cy="22" r="3.5" fill="currentColor"/>`,
    circular_barplot: `<path d="M24 24l10-8M24 24l2 12M24 24l-12 2" ${stroke}/><circle cx="24" cy="24" r="14" ${stroke}/>`,
    table: `<rect x="8" y="10" width="32" height="28" rx="2" ${stroke}/><path d="M8 18h32M8 26h32M8 34h32M18 10v28M30 10v28" ${stroke}/>`,
    stacked_bar: `<path d="M12 36v-8h8v8h-8zm0-8v-8h8v8h-8zm0-8V12h8v8h-8zM28 36v-6h8v6h-8zm0-6v-10h8v10h-8zm0-10V14h8v6h-8z" fill="currentColor"/>`,
    treemap: `<rect x="8" y="8" width="20" height="32" ${stroke}/><rect x="28" y="8" width="12" height="18" ${stroke}/><rect x="28" y="26" width="12" height="14" ${stroke}/>`,
    doughnut: `<circle cx="24" cy="24" r="14" ${stroke}/><circle cx="24" cy="24" r="6" ${stroke}/>`,
    pie: `<path d="M24 24L24 8A16 16 0 0 1 38 32z" fill="currentColor"/><circle cx="24" cy="24" r="16" ${stroke}/>`,
    dendrogram: `<path d="M8 36v-8h12v8M28 36v-8h12v8M14 28V20h20v8M24 20V12" ${stroke}/>`,
    circular_packing: `<circle cx="24" cy="24" r="14" ${stroke}/><circle cx="18" cy="22" r="6" ${stroke}/><circle cx="30" cy="26" r="5" ${stroke}/>`,
    waffle: `<rect x="8" y="8" width="8" height="8" fill="currentColor"/><rect x="20" y="8" width="8" height="8" fill="currentColor" opacity=".4"/><rect x="32" y="8" width="8" height="8" fill="currentColor"/><rect x="8" y="20" width="8" height="8" fill="currentColor" opacity=".4"/><rect x="20" y="20" width="8" height="8" fill="currentColor"/><rect x="32" y="20" width="8" height="8" fill="currentColor" opacity=".4"/><rect x="8" y="32" width="8" height="8" fill="currentColor"/><rect x="20" y="32" width="8" height="8" fill="currentColor"/><rect x="32" y="32" width="8" height="8" fill="currentColor" opacity=".4"/>`,
    line: `<path d="M8 32l8-10 8 6 8-16 8 8" ${stroke}/>`,
    area: `<path d="M8 34l8-12 8 6 8-16 8 8v14z" ${stroke} fill="currentColor" opacity=".2"/>`,
    stacked_area: `<path d="M8 36l10-8 10 4 12-10v14z" fill="currentColor" opacity=".35"/><path d="M8 28l10-10 10 6 12-12v12L28 24 18 18 8 28z" fill="currentColor" opacity=".55"/>`,
    streamchart: `<path d="M6 24c6-8 10-8 16 0s10 8 16 0M6 30c6-6 10-6 16 0s10 6 16 0" ${stroke}/>`,
    time_series: `<path d="M8 36V12M8 36h32" ${stroke}/><path d="M12 28l8-8 6 4 10-12" ${stroke}/>`,
    chord: `<path d="M24 8a16 16 0 1 1 0 32 16 16 0 0 1 0-32z" ${stroke}/><path d="M24 8c8 8 8 24 0 32M16 14c10 6 16 10 16 20" ${stroke}/>`,
    network: `<circle cx="14" cy="16" r="4" ${stroke}/><circle cx="34" cy="14" r="4" ${stroke}/><circle cx="24" cy="34" r="4" ${stroke}/><circle cx="24" cy="22" r="3" ${stroke}/><path d="M17 18l5 3M31 16l-5 5M24 25v5" ${stroke}/>`,
    sankey: `<path d="M8 12h8c8 0 8 10 16 10h8M8 36h8c8 0 8-10 16-10h8M8 24h8" ${stroke}/>`,
    arc: `<path d="M8 36h32M12 36c4-16 20-16 24 0M18 36c2-8 10-8 12 0" ${stroke}/>`,
    edge_bundling: `<path d="M10 12c16 4 12 20 28 24M10 36c16-4 12-20 28-24M10 24h28" ${stroke}/>`,
    umap: `<circle cx="16" cy="18" r="2" fill="currentColor"/><circle cx="22" cy="14" r="2" fill="currentColor"/><circle cx="20" cy="22" r="2" fill="currentColor"/><circle cx="32" cy="28" r="2" fill="currentColor"/><circle cx="36" cy="22" r="2" fill="currentColor"/><circle cx="28" cy="32" r="2" fill="currentColor"/>`,
    volcano: `<path d="M8 36l10-20 4 8 6-12 12 24z" ${stroke}/><circle cx="28" cy="14" r="2" fill="currentColor"/>`,
    enrichment: `<path d="M8 36c8-2 12-20 20-20 6 0 8 8 12 8" ${stroke}/>`,
    genomic_track: `<path d="M8 24h32M12 18v12M20 14v20M28 20v8M36 16v16" ${stroke}/>`,
    venn: `<circle cx="19" cy="24" r="10" ${stroke}/><circle cx="29" cy="24" r="10" ${stroke}/>`,
    upset: `<path d="M10 28V16h4v12M18 28V10h4v18M26 28v-8h4v8" ${stroke}/><circle cx="12" cy="34" r="2" fill="currentColor"/><circle cx="20" cy="34" r="2" fill="currentColor"/><circle cx="28" cy="34" r="2" fill="currentColor" opacity=".3"/>`,
  };
  const inner = icons[id] || `<circle cx="24" cy="24" r="10" ${stroke}/>`;
  return `<svg class="chart-icon-svg" viewBox="0 0 48 48" aria-hidden="true">${inner}</svg>`;
}

const FAVORITES_KEY = "omicscanvas.favoritePlots";
const RECENT_KEY = "omicscanvas.recentPlots";

function loadDiscoveryPrefs() {
  try {
    Discovery.favorites = new Set(JSON.parse(localStorage.getItem(FAVORITES_KEY) || "[]"));
    Discovery.recent = JSON.parse(localStorage.getItem(RECENT_KEY) || "[]");
  } catch {
    Discovery.favorites = new Set();
    Discovery.recent = [];
  }
}

function saveFavorites() {
  localStorage.setItem(FAVORITES_KEY, JSON.stringify([...Discovery.favorites]));
}

function pushRecent(plot) {
  if (!plot?.id) return;
  Discovery.recent = [
    { id: plot.id, name: plot.name, engine_plugin_id: plot.engine_plugin_id, preview_asset: plot.preview_asset },
    ...Discovery.recent.filter((item) => item.id !== plot.id),
  ].slice(0, 8);
  localStorage.setItem(RECENT_KEY, JSON.stringify(Discovery.recent));
}

function previewUrl(plot) {
  if (!plot) return "";
  const asset = plot.preview_asset;
  if (asset) {
    if (String(asset).startsWith("/")) return asset;
    if (String(asset).startsWith("plugins/")) {
      const parts = String(asset).split("/");
      const pluginId = parts[1];
      const file = parts.slice(3).join("/") || parts.at(-1);
      return `/api/plugins/${pluginId}/gallery/${file}`;
    }
  }
  const plugin = Discovery.pluginsById[plot.engine_plugin_id];
  return plugin?.preview || "";
}

function studioUrl(plot, extra = {}) {
  const params = new URLSearchParams();
  const family = extra.plot || plot.id;
  const engine = plot.engine_plugin_id || extra.plugin;
  params.set("plugin", engine);
  params.set("plot", family);
  if (extra.variant) params.set("variant", extra.variant);
  if (extra.example) params.set("example", extra.example);
  if (extra.source_context) params.set("source_context", extra.source_context);
  if (extra.source_task) params.set("source_task", extra.source_task);
  return `/plot/${encodeURIComponent(family)}${extra.variant ? "/" + encodeURIComponent(extra.variant) : ""}?${params.toString()}`;
}

function openStudio(plot, extra = {}) {
  pushRecent(plot);
  window.location.href = studioUrl(plot, extra);
}

function toggleFavorite(plotId, event) {
  if (event) event.stopPropagation();
  if (Discovery.favorites.has(plotId)) Discovery.favorites.delete(plotId);
  else Discovery.favorites.add(plotId);
  saveFavorites();
  renderDiscovery();
}

function familyCard(plot, options = {}) {
  const rec = options.recommended;
  const variant = options.recommended_variant;
  const fav = Discovery.favorites.has(plot.id);
  const thumb = previewUrl(plot);
  const extra = {
    variant,
    source_context: options.source_context || Discovery.analysisContext || "browse",
    source_task: options.source_task || Discovery.analysisTask || "",
  };
  return `
    <article class="family-card" data-plot-id="${plot.id}">
      <div class="family-thumb">
        ${rec ? `<span class="card-badge rec-badge">Recommended</span>` : ""}
        <button type="button" class="fav-btn ${fav ? "is-fav" : ""}" data-fav="${plot.id}" aria-label="Favorite">★</button>
        ${thumb ? `<img src="${thumb}" alt="${plot.name} preview">` : `<div class="card-fallback-icon">▣</div>`}
      </div>
      <div class="family-body">
        <h4>${plot.name}</h4>
        <p>${plot.description || "Open this visualization family in Plot Studio."}</p>
        <div class="family-meta">
          <span>${plot.variant_count || 0} variants</span>
          ${options.compat ? `<span class="compat-ok">Compatible</span>` : ""}
        </div>
        ${options.why ? `<p class="family-why">${escapeHtml(options.why)}</p>` : ""}
        <div class="card-btn-row">
          <button type="button" class="card-btn primary" data-open="${plot.id}">Explore styles</button>
          <button type="button" class="card-btn secondary" data-demo="${plot.id}" data-variant="${variant || ""}">Quick Demo</button>
        </div>
      </div>
    </article>
  `;
}

function bindFamilyCards(root) {
  root.querySelectorAll("[data-open]").forEach((btn) => {
    btn.onclick = (event) => {
      event.stopPropagation();
      const plot = findPlot(btn.dataset.open);
      if (plot) openFamily(plot);
    };
  });
  root.querySelectorAll("[data-demo]").forEach((btn) => {
    btn.onclick = (event) => {
      event.stopPropagation();
      const plot = findPlot(btn.dataset.demo);
      if (plot) openStudio(plot, { variant: btn.dataset.variant, source_context: Discovery.analysisContext || "browse", source_task: Discovery.analysisTask });
    };
  });
  root.querySelectorAll("[data-fav]").forEach((btn) => {
    btn.onclick = (event) => toggleFavorite(btn.dataset.fav, event);
  });
  root.querySelectorAll(".family-card").forEach((card) => {
    card.onclick = () => {
      const plot = findPlot(card.dataset.plotId);
      if (plot) openFamily(plot);
    };
  });
}

function findPlot(id) {
  return (Discovery.browse.all_plots || []).find((p) => p.id === id)
    || Discovery.browse.all_plots.find((p) => p.engine_plugin_id === id);
}

function setDiscoveryView(view) {
  Discovery.view = view;
  document.querySelectorAll(".entry-toggle [data-entry]").forEach((btn) => {
    btn.classList.toggle("active", btn.dataset.entry === view);
  });
  document.querySelectorAll(".cat-nav-item").forEach((btn) => {
    const match = (view === "browse" && btn.dataset.browse === Discovery.browseCategory)
      || (view === "analysis" && btn.dataset.analysis === (Discovery.analysisContext || "root"))
      || (view === "home" && btn.dataset.nav === "home")
      || (view === "browse" && btn.dataset.nav === "browse" && Discovery.browseCategory === "all");
    btn.classList.toggle("active", Boolean(match));
  });
}

function renderHomeDiscovery() {
  const recCards = Discovery.recommendations.map((item) => {
    const plot = findPlot(item.plot_id);
    if (!plot) return "";
    return familyCard(plot, { recommended: true, recommended_variant: item.variant, source_context: "data" });
  }).join("");
  const recentCards = Discovery.recent.map((item) => {
    const plot = findPlot(item.id) || item;
    return familyCard(plot, { source_context: "recent" });
  }).join("");
  const launchTiles = `
    <div class="analysis-grid">
      <button type="button" class="analysis-tile" data-entry="scenario">
        <strong>Explore by Scenario</strong>
        <span>Start from your scientific question.</span>
      </button>
      <button type="button" class="analysis-tile" data-entry="category">
        <strong>Browse by Chart Type</strong>
        <span>Start from the visual form you want.</span>
      </button>
      <button type="button" class="analysis-tile" data-entry="browse">
        <strong>All Plots</strong>
        <span>Search every visualization family.</span>
      </button>
    </div>
  `;
  return `
    <section class="discover-hero">
      <p class="eyebrow">Scientific Plot Studio</p>
      <h2>Find the right plot for your question</h2>
      <p>Search by name, start from a scientific scenario, or pick a chart type. Every path opens the same Studio.</p>
      <label class="hero-search">
        <input id="pluginSearch" class="hero-search-input" placeholder="Search plots or describe what you need…" value="${escapeHtml(Discovery.searchQuery)}">
      </label>
    </section>
    <section class="discover-section">${launchTiles}</section>
    ${Discovery.recommendations.length ? `
      <section class="discover-section">
        <h3>Recommended for your data</h3>
        <div class="family-grid">${recCards}</div>
      </section>` : `
      <section class="discover-section muted-panel">
        <h3>Recommended for your data</h3>
        <p>Upload a dataset (Datasets tab) to see registry-based suggestions such as UMAP by cluster or split-by-sample.</p>
      </section>`}
    <section class="discover-section">
      <h3>Recently used</h3>
      ${recentCards ? `<div class="family-grid">${recentCards}</div>` : `<p class="empty-inline">No recent plots yet.</p>`}
    </section>
  `;
}

function renderBrowseDiscovery() {
  const cats = Discovery.browse.categories || [];
  const active = Discovery.browseCategory;
  const list = active === "all"
    ? Discovery.browse.all_plots
    : active === "favorites"
      ? Discovery.browse.all_plots.filter((p) => Discovery.favorites.has(p.id))
      : (cats.find((c) => c.id === active)?.plots || []);
  const pills = [`<button type="button" class="filter-pill ${active === "all" ? "active" : ""}" data-browse="all">All</button>`]
    .concat(cats.map((c) => `<button type="button" class="filter-pill ${active === c.id ? "active" : ""}" data-browse="${c.id}">${c.name}</button>`))
    .join("");
  return `
    <section class="discover-hero compact">
      <h2>Browse all plots</h2>
      <p>Search visualization families directly.</p>
      <label class="hero-search">
        <input id="pluginSearch" class="hero-search-input" placeholder="Search plots…" value="${escapeHtml(Discovery.searchQuery)}">
      </label>
    </section>
    <div class="browse-toolbar">
      <div class="filter-pills"><span class="filter-label">Filter:</span>${pills}</div>
      <div class="tool-count-info">Showing <strong id="toolCount">${list.length}</strong> families</div>
    </div>
    <div class="family-grid" id="plotCards">${list.map((p) => familyCard(p, { source_context: "browse" })).join("") || `<div class="empty card">No plots in this filter.</div>`}</div>
  `;
}

function scenarioCard(ctx) {
  const nTasks = ctx.task_count || (ctx.tasks || []).length;
  const nPlots = ctx.plot_count ?? (ctx.tasks || []).reduce((n, t) => n + (t.plot_count || 0), 0);
  return `
    <button type="button" class="analysis-tile scenario-card" data-go-analysis="${ctx.id}">
      <strong>${escapeHtml(ctx.name)}</strong>
      <p>${escapeHtml(ctx.blurb || "Choose a scientific task to see recommended plot families.")}</p>
      <span>${nTasks} analysis tasks · ${nPlots} plots</span>
    </button>
  `;
}

function renderAnalysisDiscovery() {
  const ctx = Discovery.taxonomy.contexts.find((c) => c.id === Discovery.analysisContext);
  if (!ctx) {
    return `
      <section class="discover-hero compact">
        <h2>Explore by Scenario</h2>
        <p>Start from your scientific question and find suitable visualizations.</p>
      </section>
      <div class="analysis-grid">${(Discovery.taxonomy.contexts || []).map(scenarioCard).join("")}</div>
    `;
  }
  const task = ctx.tasks.find((t) => t.id === Discovery.analysisTask);
  if (!task) {
    return `
      <nav class="crumbs"><a href="/scenario">Explore by Scenario</a> / ${escapeHtml(ctx.name)}</nav>
      <section class="discover-hero compact">
        <h2>${escapeHtml(ctx.name)}</h2>
        <p>${escapeHtml(ctx.blurb || "Choose a scientific task to see recommended plot families.")}</p>
      </section>
      <div class="task-list">
        ${ctx.tasks.map((t) => `
          <button type="button" class="task-row" data-go-task="${ctx.id}/${t.id}">
            <span>
              <strong>${escapeHtml(t.name)}</strong>
              <em>${escapeHtml(t.blurb || "")}</em>
            </span>
            <span>${t.plot_count} plot families</span>
          </button>
        `).join("")}
      </div>
    `;
  }
  const recommended = task.plots.filter((p) => p.recommended);
  const other = task.plots.filter((p) => !p.recommended);
  const recHtml = recommended.map((p) => familyCard(p, {
    recommended: true,
    recommended_variant: p.recommended_variant,
    source_context: ctx.context,
    source_task: task.id,
    why: p.why || task.blurb,
  })).join("");
  const otherHtml = other.map((p) => familyCard(p, {
    recommended_variant: p.recommended_variant,
    source_context: ctx.context,
    source_task: task.id,
  })).join("");
  return `
    <nav class="crumbs"><a href="/scenario">Explore by Scenario</a> / <a href="/scenario/${ctx.id}">${escapeHtml(ctx.name)}</a> / ${escapeHtml(task.name)}</nav>
    <section class="discover-hero compact">
      <h2>${escapeHtml(ctx.name)} / ${escapeHtml(task.name)}</h2>
      <p>${escapeHtml(task.blurb || "Recommended plot families for this scientific task.")}</p>
    </section>
    <section class="discover-section">
      <h3>Recommended</h3>
      <div class="family-grid">${recHtml || `<p class="empty-inline">No tagged recommendations — open more compatible plots below.</p>`}</div>
    </section>
    ${other.length ? `
      <details class="more-plots">
        <summary>More compatible plots</summary>
        <div class="family-grid">${otherHtml}</div>
      </details>` : ""}
  `;
}

function chartTile(chart) {
  const n = chart.plot_count || (chart.plots || []).length;
  return `
    <button type="button" class="chart-tile ${n ? "" : "is-empty"}" data-go-chart="${chart.id}">
      <span class="chart-tile-icon">${chartIcon(chart.icon || chart.id)}</span>
      <strong>${escapeHtml(chart.name)}</strong>
      <span>${n ? `${n} plot famil${n === 1 ? "y" : "ies"}` : "Coming soon"}</span>
    </button>
  `;
}

function findChart(id) {
  for (const group of Discovery.chartCategories.groups || []) {
    const chart = (group.charts || []).find((item) => item.id === id);
    if (chart) return { group, chart };
  }
  return null;
}

function renderCategoryDiscovery() {
  const groups = Discovery.chartCategories.groups || [];
  if (Discovery.chartId) {
    const found = findChart(Discovery.chartId);
    if (!found) {
      return `
        <nav class="crumbs"><a href="/category">Browse by Chart Type</a> / Unknown</nav>
        <p class="empty-inline">That chart type was not found. <a href="/category">Back to chart types</a>.</p>
      `;
    }
    const { group, chart } = found;
    const cards = (chart.plots || []).map((p) => familyCard(p, { source_context: "category" })).join("");
    return `
      <nav class="crumbs"><a href="/category">Browse by Chart Type</a> / <a href="/category?group=${group.id}">${escapeHtml(group.name)}</a> / ${escapeHtml(chart.name)}</nav>
      <section class="discover-hero compact">
        <div class="category-hero-row">
          <span class="chart-tile-icon large">${chartIcon(chart.icon || chart.id)}</span>
          <div>
            <h2>${escapeHtml(chart.name)}</h2>
            <p>${chart.plot_count ? `Choose a plot family, then explore its visualization styles.` : `No plot family is wired to this chart type yet.`}</p>
          </div>
        </div>
      </section>
      <div class="family-grid">${cards || `<div class="empty card">Coming soon — this chart type is reserved so the gallery stays complete.</div>`}</div>
    `;
  }
  const visible = Discovery.chartGroup
    ? groups.filter((g) => g.id === Discovery.chartGroup)
    : groups;
  return `
    <section class="discover-hero compact">
      <h2>Browse by Chart Type</h2>
      <p>Start from the visual form you want to create.</p>
    </section>
    ${(visible.length ? visible : groups).map((group) => `
      <section class="discover-section chart-group" id="chart-group-${group.id}">
        <h3>${escapeHtml(group.name)}</h3>
        <div class="chart-tile-grid">${(group.charts || []).map(chartTile).join("")}</div>
      </section>
    `).join("")}
  `;
}

function renderSearchDiscovery() {
  const groups = { exact: [], recommended: [], related: [] };
  Discovery.searchResults.forEach((hit) => {
    (groups[hit.match_kind] || groups.related).push(hit);
  });
  const block = (title, items) => items.length ? `
    <section class="discover-section">
      <h3>${title}</h3>
      <div class="family-grid">${items.map((p) => familyCard(p, { source_context: "search" })).join("")}</div>
    </section>` : "";
  return `
    <section class="discover-hero compact">
      <h2>Search</h2>
      <label class="hero-search">
        <input id="pluginSearch" class="hero-search-input" placeholder="Search plots or describe what you need…" value="${escapeHtml(Discovery.searchQuery)}">
      </label>
    </section>
    ${Discovery.searchResults.length ? block("Exact matches", groups.exact) + block("Recommended matches", groups.recommended) + block("Related matches", groups.related) : `<p class="empty-inline">No plots matched “${escapeHtml(Discovery.searchQuery)}”.</p>`}
  `;
}

function escapeHtml(value) {
  return String(value || "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/"/g, "&quot;");
}

function styleBadge(style) {
  if (style.card_group === "pdf_styles") return "RECOMMENDED";
  return "VARIANT";
}

function styleCard(plot, style) {
  const thumb = style.image || previewUrl(plot);
  const blurb = style.blurb || style.howto || `Visualization style “${style.label}” for ${plot.name}.`;
  return `
    <article class="plot-card style-card" data-style-id="${escapeHtml(style.id)}">
      <div class="card-thumb-box">
        <span class="card-badge">${escapeHtml(styleBadge(style))}</span>
        ${thumb ? `<img src="${thumb}" alt="${escapeHtml(style.label)} preview">` : `<div class="card-fallback-icon">▣</div>`}
      </div>
      <div class="card-content-body">
        <h4>${escapeHtml(style.label)}</h4>
        <p>${escapeHtml(blurb)}</p>
        <div class="card-btn-row">
          <button type="button" class="card-btn primary" data-style-open="${escapeHtml(style.id)}">Open Studio</button>
          <button type="button" class="card-btn secondary" data-style-demo="${escapeHtml(style.id)}">Try Demo</button>
        </div>
      </div>
    </article>
  `;
}

function visibleFamilyStyles() {
  return (Discovery.familyStyles || []).slice(0, Discovery.styleLimit);
}

function renderFamilyDiscovery() {
  const plot = Discovery.familyPlot;
  if (!plot) {
    return `
      <nav class="crumbs"><a href="/plots">All Plots</a> / Unknown family</nav>
      <p class="empty-inline">This plot family was not found. <a href="/plots">Back to all plots</a>.</p>
    `;
  }
  const total = Discovery.familyStyles.length;
  const shown = visibleFamilyStyles();
  const remaining = Math.max(0, total - shown.length);
  const cards = shown.map((style) => styleCard(plot, style)).join("");
  const loading = total === 0 && !Discovery.familyStylesCache[plot.id];
  return `
    <nav class="crumbs"><a href="/plots">All Plots</a> / ${escapeHtml(plot.name)}</nav>
    <section class="discover-hero compact">
      <h2>${escapeHtml(plot.name)}</h2>
      <p>${escapeHtml(plot.description || "Choose a visualization style, then open it in Plot Studio.")}</p>
      <div class="family-hero-actions">
        <button type="button" class="card-btn primary" data-family-studio="${plot.id}">Open Studio</button>
        <button type="button" class="card-btn secondary" data-demo="${plot.id}">Quick Demo</button>
      </div>
    </section>
    <div class="browse-toolbar">
      <div class="tool-count-info">
        ${loading ? "Loading visualization styles…" : `Showing <strong>${shown.length}</strong> of <strong>${total}</strong> styles`}
      </div>
    </div>
    <div class="plot-cards style-grid" id="styleCards">
      ${loading ? `<div class="empty card">Loading styles…</div>` : (cards || `<div class="empty card">No visualization styles yet for this family. Open Studio to plot from scratch.</div>`)}
    </div>
    ${remaining ? `
      <div class="load-more-wrap" id="styleLoadMore">
        <button type="button" class="load-more-btn" data-load-more="1">Load more · ${Math.min(STYLE_PAGE, remaining)} of ${remaining} remaining</button>
        <p class="load-more-hint">Scroll down to load the next ${STYLE_PAGE} cards, or click Load more.</p>
      </div>` : (total > STYLE_PAGE ? `<p class="load-more-hint done">All ${total} styles are shown.</p>` : "")}
  `;
}

async function loadFamilyStyles(plot) {
  if (!plot?.id) return;
  if (Discovery.familyStylesCache[plot.id]) {
    Discovery.familyStyles = Discovery.familyStylesCache[plot.id];
    return;
  }
  const payload = await api(`/api/registry/plots/${encodeURIComponent(plot.id)}/styles`);
  Discovery.familyStyles = payload.styles || [];
  Discovery.familyStylesCache[plot.id] = Discovery.familyStyles;
}

async function openFamily(plot) {
  if (!plot) return;
  Discovery.familyPlot = plot;
  Discovery.styleLimit = STYLE_PAGE;
  Discovery.familyStyles = Discovery.familyStylesCache[plot.id] || [];
  Discovery.view = "family";
  history.pushState({}, "", `/family/${encodeURIComponent(plot.id)}`);
  renderDiscovery();
  if (!Discovery.familyStylesCache[plot.id]) {
    try {
      await loadFamilyStyles(plot);
    } catch (err) {
      console.warn("Failed to load family styles", err);
      Discovery.familyStyles = [];
      Discovery.familyStylesCache[plot.id] = [];
    }
    if (Discovery.view === "family" && Discovery.familyPlot?.id === plot.id) renderDiscovery();
  }
}

function bindStyleCardClicks(root, plot) {
  const openStyle = (styleId) => {
    openStudio(plot, {
      example: styleId,
      source_context: Discovery.analysisContext || "browse",
      source_task: Discovery.analysisTask || "family",
    });
  };
  root.querySelectorAll("[data-style-open], [data-style-demo]").forEach((btn) => {
    btn.onclick = (event) => {
      event.stopPropagation();
      openStyle(btn.dataset.styleOpen || btn.dataset.styleDemo);
    };
  });
  root.querySelectorAll(".style-card").forEach((card) => {
    card.onclick = () => openStyle(card.dataset.styleId);
  });
}

function updateLoadMoreChrome(root) {
  const total = Discovery.familyStyles.length;
  const shown = Math.min(Discovery.styleLimit, total);
  const remaining = Math.max(0, total - shown);
  const count = root.querySelector(".browse-toolbar .tool-count-info");
  if (count) count.innerHTML = `Showing <strong>${shown}</strong> of <strong>${total}</strong> styles`;
  const wrap = root.querySelector("#styleLoadMore");
  if (!wrap) return;
  if (!remaining) {
    wrap.outerHTML = total > STYLE_PAGE ? `<p class="load-more-hint done">All ${total} style cards are shown.</p>` : "";
    if (Discovery._styleObserver) Discovery._styleObserver.disconnect();
    return;
  }
  const btn = wrap.querySelector("[data-load-more]");
  if (btn) btn.textContent = `Load more · ${Math.min(STYLE_PAGE, remaining)} of ${remaining} remaining`;
}

function bindStyleCards(root) {
  const plot = Discovery.familyPlot;
  if (!plot) return;
  bindStyleCardClicks(root, plot);
  root.querySelectorAll("[data-family-studio]").forEach((btn) => {
    btn.onclick = (event) => {
      event.stopPropagation();
      openStudio(plot, { source_context: "family" });
    };
  });
  const revealMore = () => {
    if (Discovery._loadingMore) return;
    const prev = Discovery.styleLimit;
    if (prev >= Discovery.familyStyles.length) return;
    Discovery._loadingMore = true;
    Discovery.styleLimit += STYLE_PAGE;
    const grid = root.querySelector("#styleCards");
    if (grid) {
      const extra = Discovery.familyStyles.slice(prev, Discovery.styleLimit);
      extra.forEach((style) => grid.insertAdjacentHTML("beforeend", styleCard(plot, style)));
      bindStyleCardClicks(grid, plot);
    }
    updateLoadMoreChrome(root);
    Discovery._loadingMore = false;
  };
  const loadMore = root.querySelector("[data-load-more]");
  if (loadMore) {
    loadMore.onclick = (event) => {
      event.preventDefault();
      event.stopPropagation();
      revealMore();
    };
  }
  const sentinel = root.querySelector("#styleLoadMore");
  if (Discovery._styleObserver) Discovery._styleObserver.disconnect();
  if (sentinel && Discovery.styleLimit < Discovery.familyStyles.length) {
    Discovery._styleScrollArmed = false;
    const armScroll = () => { Discovery._styleScrollArmed = true; };
    window.addEventListener("wheel", armScroll, { once: true, passive: true });
    window.addEventListener("touchmove", armScroll, { once: true, passive: true });
    const scroller = document.querySelector(".workspace") || document;
    scroller.addEventListener("scroll", armScroll, { once: true, passive: true });
    Discovery._styleObserver = new IntersectionObserver((entries) => {
      if (!Discovery._styleScrollArmed) return;
      if (entries.some((entry) => entry.isIntersecting)) revealMore();
    }, { rootMargin: "120px" });
    Discovery._styleObserver.observe(sentinel);
  }
}

function renderDiscovery() {
  const host = $("discoveryRoot");
  if (!host) return;
  let html = "";
  if (Discovery.view === "search") html = renderSearchDiscovery();
  else if (Discovery.view === "browse") html = renderBrowseDiscovery();
  else if (Discovery.view === "analysis") html = renderAnalysisDiscovery();
  else if (Discovery.view === "category") html = renderCategoryDiscovery();
  else if (Discovery.view === "family") html = renderFamilyDiscovery();
  else html = renderHomeDiscovery();
  host.innerHTML = html;
  bindFamilyCards(host);
  if (Discovery.view === "family") bindStyleCards(host);
  host.querySelectorAll(".crumbs a, .load-more-hint a").forEach((link) => {
    link.onclick = (event) => {
      const href = link.getAttribute("href") || "";
      if (href.startsWith("/")) {
        event.preventDefault();
        navigateDiscovery(href);
      }
    };
  });
  host.querySelectorAll("[data-entry]").forEach((btn) => {
    btn.onclick = () => {
      const mode = ENTRY_MODES.find((item) => item.id === btn.dataset.entry)
        || (btn.dataset.entry === "analysis" ? { path: "/scenario" } : null);
      navigateDiscovery(mode ? mode.path : "/plots");
    };
  });
  host.querySelectorAll("[data-go-analysis]").forEach((btn) => {
    btn.onclick = () => navigateDiscovery(`/scenario/${btn.dataset.goAnalysis}`);
  });
  host.querySelectorAll("[data-go-task]").forEach((btn) => {
    btn.onclick = () => navigateDiscovery(`/scenario/${btn.dataset.goTask}`);
  });
  host.querySelectorAll("[data-go-chart]").forEach((btn) => {
    btn.onclick = () => navigateDiscovery(`/category/${btn.dataset.goChart}`);
  });
  host.querySelectorAll("[data-browse]").forEach((btn) => {
    btn.onclick = () => {
      Discovery.browseCategory = btn.dataset.browse;
      Discovery.view = "browse";
      history.pushState({}, "", `/plots?category=${encodeURIComponent(btn.dataset.browse)}`);
      renderDiscovery();
      highlightSidebar();
    };
  });
  const search = $("pluginSearch");
  if (search) {
    search.onkeydown = async (event) => {
      if (event.key === "Enter") {
        event.preventDefault();
        await runDiscoverySearch(search.value);
      }
    };
    search.oninput = () => {
      Discovery.searchQuery = search.value;
    };
  }
  const count = $("toolCount");
  if (count && Discovery.view === "browse") {
    /* already set in HTML */
  }
  highlightSidebar();
}

function highlightSidebar() {
  document.querySelectorAll(".cat-nav-item").forEach((btn) => {
    let on = false;
    if (btn.dataset.nav === "home") on = Discovery.view === "home";
    if (btn.dataset.nav === "browse") on = ((Discovery.view === "browse" && Discovery.browseCategory !== "favorites") || Discovery.view === "family" || Discovery.view === "search");
    if (btn.dataset.nav === "category") on = Discovery.view === "category";
    if (btn.dataset.nav === "favorites") on = Discovery.view === "browse" && Discovery.browseCategory === "favorites";
    if (btn.dataset.nav === "recent") on = Discovery.view === "home";
    if (btn.dataset.analysis === "root") on = Discovery.view === "analysis";
    btn.classList.toggle("active", on);
  });
}

async function runDiscoverySearch(query) {
  Discovery.searchQuery = (query || "").trim();
  if (!Discovery.searchQuery) {
    Discovery.view = "home";
    renderDiscovery();
    return;
  }
  const result = await api(`/api/registry/search?q=${encodeURIComponent(Discovery.searchQuery)}`);
  Discovery.searchResults = (result.results || []).map((plot) => ({
    ...plot,
    variant_count: (plot.variants || []).length,
    preview_asset: plot.preview_asset || (plot.demos || [])[0]?.preview_asset,
  }));
  Discovery.view = "search";
  history.pushState({}, "", `/plots?q=${encodeURIComponent(Discovery.searchQuery)}`);
  renderDiscovery();
}

function navigateDiscovery(path) {
  history.pushState({}, "", path);
  applyDiscoveryRoute();
}

async function applyDiscoveryRoute() {
  const path = window.location.pathname.replace(/\/+$/, "") || "/";
  const params = new URLSearchParams(window.location.search);
  Discovery.analysisContext = null;
  Discovery.analysisTask = null;
  Discovery.chartId = null;
  Discovery.chartGroup = null;
  if (params.get("q")) {
    runDiscoverySearch(params.get("q"));
    return;
  }
  if (path === "/" || path === "") {
    Discovery.view = "home";
  } else if (path === "/plots") {
    Discovery.view = "browse";
    Discovery.browseCategory = params.get("category") || "all";
  } else if (path.startsWith("/analysis") || path.startsWith("/scenario")) {
    Discovery.view = "analysis";
    const parts = path.split("/").filter(Boolean);
    Discovery.analysisContext = parts[1] || null;
    Discovery.analysisTask = parts[2] || null;
  } else if (path === "/category" || path.startsWith("/category/") || path === "/chart-type" || path.startsWith("/chart-type/")) {
    Discovery.view = "category";
    const parts = path.split("/").filter(Boolean);
    Discovery.chartId = parts[1] || null;
    Discovery.chartGroup = params.get("group") || null;
  } else if (path.startsWith("/family/")) {
    Discovery.view = "family";
    const plotId = decodeURIComponent(path.split("/").filter(Boolean)[1] || "");
    Discovery.familyPlot = findPlot(plotId);
    Discovery.styleLimit = STYLE_PAGE;
    Discovery.familyStyles = (Discovery.familyPlot && Discovery.familyStylesCache[Discovery.familyPlot.id]) || [];
    renderDiscovery();
    if (Discovery.familyPlot && !Discovery.familyStylesCache[Discovery.familyPlot.id]) {
      try {
        await loadFamilyStyles(Discovery.familyPlot);
      } catch (err) {
        console.warn("Failed to load family styles", err);
        Discovery.familyStyles = [];
        Discovery.familyStylesCache[Discovery.familyPlot.id] = [];
      }
      if (Discovery.view === "family") renderDiscovery();
    }
    return;
  } else {
    Discovery.view = "home";
  }
  renderDiscovery();
}

async function refreshRecommendationsFromData() {
  const roles = new Set(Discovery.dataSchema.roles || []);
  (state.datasets || []).forEach((ds) => {
    (ds.columns || ds.column_names || []).forEach((col) => roles.add(String(col)));
  });
  if (!roles.size) {
    Discovery.recommendations = [];
    return;
  }
  Discovery.dataSchema = { roles: [...roles] };
  try {
    const result = await api("/api/registry/recommend", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ context: "single_cell", dataSchema: Discovery.dataSchema }),
    });
    Discovery.recommendations = result.recommendations || [];
  } catch {
    Discovery.recommendations = [];
  }
}

function renderSidebarDiscovery() {
  const nav = $("sidebarCategoryList");
  if (!nav) return;
  nav.innerHTML = `
    <div class="sidebar-sep">Discover</div>
    <button class="cat-nav-item" data-nav="home"><span class="cat-icon">⌂</span><span class="cat-label">Home</span></button>
    <button class="cat-nav-item" data-nav="browse"><span class="cat-icon">▦</span><span class="cat-label">All Plots</span></button>
    <button class="cat-nav-item" data-analysis="root"><span class="cat-icon">◎</span><span class="cat-label">Explore by Scenario</span></button>
    <button class="cat-nav-item" data-nav="category"><span class="cat-icon">▣</span><span class="cat-label">Browse by Chart Type</span></button>
    <button class="cat-nav-item" data-nav="favorites"><span class="cat-icon">★</span><span class="cat-label">Favorites</span></button>
  `;
  nav.querySelectorAll("[data-nav]").forEach((btn) => {
    btn.onclick = () => {
      if (btn.dataset.nav === "home") navigateDiscovery("/");
      if (btn.dataset.nav === "browse") navigateDiscovery("/plots");
      if (btn.dataset.nav === "category") navigateDiscovery("/category");
      if (btn.dataset.nav === "favorites") {
        Discovery.view = "browse";
        Discovery.browseCategory = "favorites";
        history.pushState({}, "", "/plots?category=favorites");
        renderDiscovery();
        highlightSidebar();
      }
    };
  });
  nav.querySelectorAll("[data-analysis]").forEach((btn) => {
    btn.onclick = () => navigateDiscovery("/scenario");
  });
}

async function initDiscovery() {
  loadDiscoveryPrefs();
  (state.plugins || []).forEach((p) => {
    Discovery.pluginsById[p.id] = p;
  });
  try {
    const payload = await api("/api/registry/discovery");
    Discovery.taxonomy = payload.taxonomy || { contexts: [] };
    Discovery.browse = payload.browse || { categories: [], all_plots: [] };
    Discovery.chartCategories = payload.chart_categories || { groups: [] };
  } catch (err) {
    console.warn("Registry discovery unavailable", err);
  }
  await refreshRecommendationsFromData();
  renderSidebarDiscovery();
  await applyDiscoveryRoute();
  window.addEventListener("popstate", () => { applyDiscoveryRoute(); });
}

function renderPlotCards() {
  if ($("discoveryRoot")) {
    renderDiscovery();
    return;
  }
}
