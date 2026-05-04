/* vernedocs — docs-specific behaviour. The shared JS modules in
   `themes/_shared/js/` already cover: theme toggle, mobile drawer,
   reading-progress bar, scroll-spy, copy buttons, kbar palette. This
   file adds the bits that are unique to vernedocs:
     - collapsible sidebar groups (per-group accordion, persisted) */

(() => {
  "use strict";

  const KEY = (label) => `vernedocs:nav:${label}`;

  document.querySelectorAll(".vd-sidebar-group").forEach((group) => {
    const title = group.querySelector(".vd-sidebar-title");
    if (!title) return;
    const label = title.textContent.trim();
    const hasActive = !!group.querySelector('a[aria-current="page"]');
    let stored = null;
    try { stored = localStorage.getItem(KEY(label)); } catch {}
    let collapsed = false;
    if (hasActive) collapsed = false;
    else if (stored === "true" || stored === "false") collapsed = stored === "true";
    const apply = (c) => {
      group.dataset.collapsed = String(c);
      title.setAttribute("aria-expanded", String(!c));
    };
    apply(collapsed);
    title.addEventListener("click", () => {
      collapsed = !collapsed;
      apply(collapsed);
      try { localStorage.setItem(KEY(label), String(collapsed)); } catch {}
    });
  });
})();
