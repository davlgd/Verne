/* verneblog — blog-specific behaviour. The shared JS modules in
   `themes/_shared/js/` already cover: theme toggle, mobile drawer,
   reading-progress bar, scroll-spy, copy buttons, kbar palette. This
   file adds the bits that are unique to the editorial blog reader:
     - cover hue: sanitized read of contributor frontmatter into a CSS var
     - archives page: sticky year groupings + search + tag filter */

(() => {
  "use strict";

  /* ───── cover hue (sanitized) ─────
     `data-cover-hue` comes from contributor frontmatter; we parse it as an
     integer here rather than interpolating into a `style="--cover-hue: …"`
     server-side, so a non-numeric value cannot break out of the CSS
     property and inject extra declarations. */
  document.querySelectorAll("[data-cover-hue]").forEach((el) => {
    const raw = el.dataset.coverHue;
    const n = Number.parseInt(raw, 10);
    const hue = Number.isFinite(n) ? Math.max(0, Math.min(360, n)) : 28;
    el.style.setProperty("--cover-hue", String(hue));
  });
})();

(() => {
  "use strict";

  /* ───── archives filter ─────
     The archives template emits flat <article data-archive-row data-tags=…
     data-q=… data-year=…> rows. Year headers are not in markup; we group
     the rows client-side after each filter pass, and we hide rows that
     don't match the current query / tag. */
  const list = document.querySelector("[data-archive-list]");
  if (!list) return;

  const rows = Array.from(list.querySelectorAll("[data-archive-row]"));
  const search = document.querySelector("[data-archive-search]");
  const clear = document.querySelector("[data-archive-clear]");
  const empty = document.querySelector("[data-archive-empty]");
  const count = document.querySelector("[data-archive-count]");
  const tagBtns = Array.from(document.querySelectorAll("[data-archive-tag]"));
  let activeTag = "";

  const grouped = new Map();
  for (const row of rows) {
    const y = row.dataset.year;
    if (!grouped.has(y)) grouped.set(y, []);
    grouped.get(y).push(row);
  }

  // Insert a year header before the first row of each year group.
  // Build with createElement / textContent so a malformed `data-year`
  // value (which originates server-side via format_date but is read back
  // here as a plain string) cannot inject markup into the page.
  const yearHeads = new Map();
  for (const [year, group] of grouped) {
    const head = document.createElement("div");
    head.className = "vbg-year-head";
    head.dataset.year = year;
    const h2 = document.createElement("h2");
    h2.textContent = year;
    const rule = document.createElement("span");
    rule.className = "vbg-year-rule";
    rule.setAttribute("aria-hidden", "true");
    const count = document.createElement("span");
    count.className = "vbg-year-count";
    head.append(h2, rule, count);
    group[0].before(head);
    yearHeads.set(year, head);
  }

  const apply = () => {
    const q = (search?.value || "").trim().toLowerCase();
    let visible = 0;
    const yearVisible = new Map();
    for (const row of rows) {
      const tags = (row.dataset.tags || "").toLowerCase().split(",");
      const hay = (row.dataset.q || "").toLowerCase();
      const matchTag = !activeTag || tags.includes(activeTag);
      const matchQ = !q || hay.includes(q);
      const ok = matchTag && matchQ;
      row.hidden = !ok;
      if (ok) {
        visible++;
        const y = row.dataset.year;
        yearVisible.set(y, (yearVisible.get(y) || 0) + 1);
      }
    }
    for (const [year, head] of yearHeads) {
      const n = yearVisible.get(year) || 0;
      head.hidden = n === 0;
      head.querySelector(".vbg-year-count").textContent = n + (n === 1 ? " post" : " posts");
    }
    if (empty) empty.hidden = visible !== 0;
    if (count) count.textContent = visible + (visible === 1 ? " post" : " posts");
    if (clear) clear.hidden = !q;
  };

  if (search) {
    search.addEventListener("input", apply);
    search.addEventListener("keydown", (e) => {
      if (e.key === "Escape" && search.value) { search.value = ""; apply(); }
    });
  }
  if (clear) {
    clear.addEventListener("click", () => { if (search) { search.value = ""; search.focus(); } apply(); });
  }
  for (const btn of tagBtns) {
    btn.addEventListener("click", () => {
      const next = btn.dataset.archiveTag || "";
      activeTag = activeTag === next ? "" : next;
      tagBtns.forEach((b) => {
        const on = (b.dataset.archiveTag || "") === activeTag;
        b.classList.toggle("is-active", on);
        b.setAttribute("aria-pressed", String(on));
      });
      apply();
    });
  }

  apply();
})();
