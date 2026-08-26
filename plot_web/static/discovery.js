/* Plot discovery UI — registry-driven Explore / Browse (phase 2). */
const Discovery = {
  taxonomy: { contexts: [] },
  browse: { categories: [], all_plots: [] },
  pluginsById: {},
  view: "home", // home | browse | analysis | search | family
  browseCategory: "all",
  analysisContext: null,
  analysisTask: null,
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
          <span>Preset cards</span>
          ${options.compat ? `<span class="compat-ok">Compatible</span>` : ""}
        </div>
        <div class="card-btn-row">
          <button type="button" class="card-btn primary" data-open="${plot.id}">View styles</button>
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
  const contextTiles = Discovery.taxonomy.contexts.map((ctx) => `
    <button type="button" class="analysis-tile" data-go-analysis="${ctx.id}">
      <strong>${ctx.name}</strong>
      <span>${ctx.tasks.length} tasks</span>
    </button>
  `).join("");
  return `
    <section class="discover-hero">
      <p class="eyebrow">Scientific Plot Studio</p>
      <h2>Find the right plot for your question</h2>
      <p>Search by name, or start from your analysis context. Both paths open the same Studio.</p>
      <label class="hero-search">
        <input id="pluginSearch" class="hero-search-input" placeholder="Search plots or describe what you need…" value="${escapeHtml(Discovery.searchQuery)}">
      </label>
      <div class="entry-toggle">
        <button type="button" data-entry="analysis">Explore by Analysis</button>
        <button type="button" data-entry="browse">Browse All Plots</button>
      </div>
    </section>
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
    <section class="discover-section">
      <h3>Explore by analysis</h3>
      <div class="analysis-grid">${contextTiles}</div>
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
      <p>One card per visualization family. Click a family to browse its preset style cards.</p>
      <label class="hero-search">
        <input id="pluginSearch" class="hero-search-input" placeholder="Search plots…" value="${escapeHtml(Discovery.searchQuery)}">
      </label>
      <div class="entry-toggle">
        <button type="button" data-entry="analysis">Explore by Analysis</button>
        <button type="button" class="active" data-entry="browse">Browse All Plots</button>
      </div>
    </section>
    <div class="browse-toolbar">
      <div class="filter-pills">${pills}</div>
      <div class="tool-count-info">Showing <strong id="toolCount">${list.length}</strong> families</div>
    </div>
    <div class="family-grid" id="plotCards">${list.map((p) => familyCard(p, { source_context: "browse" })).join("") || `<div class="empty card">No plots in this category.</div>`}</div>
  `;
}

function renderAnalysisDiscovery() {
  const ctx = Discovery.taxonomy.contexts.find((c) => c.id === Discovery.analysisContext);
  if (!ctx) {
    const tiles = Discovery.taxonomy.contexts.map((item) => `
      <button type="button" class="analysis-tile" data-go-analysis="${item.id}">
        <strong>${item.name}</strong>
        <span>${item.tasks.reduce((n, t) => n + t.plot_count, 0)} plots</span>
      </button>
    `).join("");
    return `
      <section class="discover-hero compact">
        <h2>Explore by analysis</h2>
        <p>Start from the scientific question, then pick a recommended family.</p>
        <div class="entry-toggle">
          <button type="button" class="active" data-entry="analysis">Explore by Analysis</button>
          <button type="button" data-entry="browse">Browse All Plots</button>
        </div>
      </section>
      <div class="analysis-grid">${tiles}</div>
    `;
  }
  const task = ctx.tasks.find((t) => t.id === Discovery.analysisTask);
  if (!task) {
    return `
      <nav class="crumbs"><a href="/plots">Plots</a> / ${ctx.name}</nav>
      <section class="discover-hero compact">
        <h2>${ctx.name}</h2>
        <p>Choose a task to see recommended plot families.</p>
      </section>
      <div class="task-list">
        ${ctx.tasks.map((t) => `
          <button type="button" class="task-row" data-go-task="${ctx.id}/${t.id}">
            <strong>${t.name}</strong>
            <span>${t.plot_count} families</span>
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
  })).join("");
  const otherHtml = other.map((p) => familyCard(p, {
    recommended_variant: p.recommended_variant,
    source_context: ctx.context,
    source_task: task.id,
  })).join("");
  return `
    <nav class="crumbs"><a href="/plots">Plots</a> / <a href="/analysis/${ctx.id}">${ctx.name}</a> / ${task.name}</nav>
    <section class="discover-hero compact">
      <h2>${ctx.name} → ${task.name}</h2>
      <p>Recommended families share this scientific task in the plot registry.</p>
    </section>
    <section class="discover-section">
      <h3>Recommended</h3>
      <div class="family-grid">${recHtml || `<p class="empty-inline">No tagged recommendations — showing related families below.</p>`}</div>
    </section>
    <section class="discover-section">
      <h3>Other useful views</h3>
      <div class="family-grid">${otherHtml || `<p class="empty-inline">No additional families for this task.</p>`}</div>
    </section>
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
  if (style.card_group === "pdf_styles") return "PDF STYLE";
  const mode = String(style.mode || style.plot_type || "preset").replace(/_/g, " ");
  return mode.toUpperCase().slice(0, 18);
}

function styleCard(plot, style) {
  const thumb = style.image || previewUrl(plot);
  const blurb = style.blurb || style.howto || `Preset “${style.label}” for ${plot.name}.`;
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
      <nav class="crumbs"><a href="/plots">Plots</a> / Unknown family</nav>
      <p class="empty-inline">This plot family was not found. <a href="/plots">Back to all plots</a>.</p>
    `;
  }
  const total = Discovery.familyStyles.length;
  const shown = visibleFamilyStyles();
  const remaining = Math.max(0, total - shown.length);
  const cards = shown.map((style) => styleCard(plot, style)).join("");
  const loading = total === 0 && !Discovery.familyStylesCache[plot.id];
  return `
    <nav class="crumbs"><a href="/plots">Plots</a> / ${escapeHtml(plot.name)}</nav>
    <section class="discover-hero compact">
      <h2>${escapeHtml(plot.name)}</h2>
      <p>${escapeHtml(plot.description || "Choose a preset style card, then open it in Plot Studio.")}</p>
      <div class="family-hero-actions">
        <button type="button" class="card-btn primary" data-family-studio="${plot.id}">Open Studio</button>
        <button type="button" class="card-btn secondary" data-demo="${plot.id}">Quick Demo</button>
      </div>
    </section>
    <div class="browse-toolbar">
      <div class="tool-count-info">
        ${loading ? "Loading preset cards…" : `Showing <strong>${shown.length}</strong> of <strong>${total}</strong> style cards`}
      </div>
    </div>
    <div class="plot-cards style-grid" id="styleCards">
      ${loading ? `<div class="empty card">Loading styles…</div>` : (cards || `<div class="empty card">No preset cards yet for this family. Open Studio to plot from scratch.</div>`)}
    </div>
    ${remaining ? `
      <div class="load-more-wrap" id="styleLoadMore">
        <button type="button" class="load-more-btn" data-load-more="1">Load more · ${Math.min(STYLE_PAGE, remaining)} of ${remaining} remaining</button>
        <p class="load-more-hint">Scroll down to load the next ${STYLE_PAGE} cards, or click Load more.</p>
      </div>` : (total > STYLE_PAGE ? `<p class="load-more-hint done">All ${total} style cards are shown.</p>` : "")}
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
  if (count) count.innerHTML = `Showing <strong>${shown}</strong> of <strong>${total}</strong> style cards`;
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
  else if (Discovery.view === "family") html = renderFamilyDiscovery();
  else html = renderHomeDiscovery();
  host.innerHTML = html;
  bindFamilyCards(host);
  if (Discovery.view === "family") bindStyleCards(host);
  host.querySelectorAll(".crumbs a").forEach((link) => {
    link.onclick = (event) => {
      const href = link.getAttribute("href") || "";
      if (href.startsWith("/")) {
        event.preventDefault();
        navigateDiscovery(href);
      }
    };
  });
  host.querySelectorAll("[data-entry]").forEach((btn) => {
    btn.onclick = () => navigateDiscovery(btn.dataset.entry === "analysis" ? "/analysis" : "/plots");
  });
  host.querySelectorAll("[data-go-analysis]").forEach((btn) => {
    btn.onclick = () => navigateDiscovery(`/analysis/${btn.dataset.goAnalysis}`);
  });
  host.querySelectorAll("[data-go-task]").forEach((btn) => {
    btn.onclick = () => navigateDiscovery(`/analysis/${btn.dataset.goTask}`);
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
    if (btn.dataset.nav === "browse") on = (Discovery.view === "browse" && Discovery.browseCategory === "all") || Discovery.view === "family";
    if (btn.dataset.nav === "favorites") on = Discovery.view === "browse" && Discovery.browseCategory === "favorites";
    if (btn.dataset.nav === "recent") on = Discovery.view === "home";
    if (btn.dataset.browse) on = Discovery.view === "browse" && Discovery.browseCategory === btn.dataset.browse;
    if (btn.dataset.analysis) on = Discovery.view === "analysis" && Discovery.analysisContext === btn.dataset.analysis;
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
  if (params.get("q")) {
    runDiscoverySearch(params.get("q"));
    return;
  }
  if (path === "/" || path === "") {
    Discovery.view = "home";
  } else if (path === "/plots") {
    Discovery.view = "browse";
    Discovery.browseCategory = params.get("category") || "all";
  } else if (path.startsWith("/analysis")) {
    Discovery.view = "analysis";
    const parts = path.split("/").filter(Boolean);
    Discovery.analysisContext = parts[1] || null;
    Discovery.analysisTask = parts[2] || null;
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
  const browseLinks = (Discovery.browse.categories || []).map((c) => `
    <button class="cat-nav-item" data-browse="${c.id}">
      <span class="cat-icon">·</span>
      <span class="cat-label">${c.name}</span>
    </button>
  `).join("");
  const analysisLinks = (Discovery.taxonomy.contexts || []).map((c) => `
    <button class="cat-nav-item" data-analysis="${c.id}">
      <span class="cat-icon">·</span>
      <span class="cat-label">${c.name}</span>
    </button>
  `).join("");
  nav.innerHTML = `
    <button class="cat-nav-item" data-nav="home"><span class="cat-icon">⌂</span><span class="cat-label">Home</span></button>
    <button class="cat-nav-item" data-nav="browse"><span class="cat-icon">▦</span><span class="cat-label">All Plots</span></button>
    <button class="cat-nav-item" data-analysis="root"><span class="cat-icon">◎</span><span class="cat-label">Explore by Analysis</span></button>
    <button class="cat-nav-item" data-nav="favorites"><span class="cat-icon">★</span><span class="cat-label">Favorites</span></button>
    <div class="sidebar-sep">Browse</div>
    ${browseLinks}
    <div class="sidebar-sep">Analysis</div>
    ${analysisLinks}
  `;
  nav.querySelectorAll("[data-nav]").forEach((btn) => {
    btn.onclick = () => {
      if (btn.dataset.nav === "home") navigateDiscovery("/");
      if (btn.dataset.nav === "browse") navigateDiscovery("/plots");
      if (btn.dataset.nav === "favorites") {
        Discovery.view = "browse";
        Discovery.browseCategory = "favorites";
        history.pushState({}, "", "/plots?category=favorites");
        renderDiscovery();
      }
    };
  });
  nav.querySelectorAll("[data-browse]").forEach((btn) => {
    btn.onclick = () => {
      Discovery.browseCategory = btn.dataset.browse;
      Discovery.view = "browse";
      history.pushState({}, "", `/plots?category=${btn.dataset.browse}`);
      renderDiscovery();
    };
  });
  nav.querySelectorAll("[data-analysis]").forEach((btn) => {
    btn.onclick = () => navigateDiscovery(btn.dataset.analysis === "root" ? "/analysis" : `/analysis/${btn.dataset.analysis}`);
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
