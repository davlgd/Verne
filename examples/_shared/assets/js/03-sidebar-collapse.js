/* Shared — desktop sidebar collapse. Triggers:
     [data-toggle="sidebar"]         → collapse
     [data-toggle="sidebar-expand"]  → expand
   Persisted as `data-sidebar="collapsed"` on <html>. Each trigger's
   `aria-expanded` is kept in sync (true means expanded). When
   collapsed, the sidebar is also `inert` so its links don't receive
   keyboard focus (the element stays in the DOM but is removed from
   the accessibility tree). */
(() => {
  "use strict";
  const KEY = "verne:sidebar";
  const root = document.documentElement;
  const sidebar = document.querySelector("[data-mobile-sidebar]");
  const sync = () => {
    const collapsed = root.dataset.sidebar === "collapsed";
    document
      .querySelectorAll('[data-toggle="sidebar"], [data-toggle="sidebar-expand"]')
      .forEach((t) => t.setAttribute("aria-expanded", String(!collapsed)));
    if (sidebar) {
      if (collapsed) sidebar.setAttribute("inert", "");
      else sidebar.removeAttribute("inert");
    }
  };
  const set = (state) => {
    if (state === "collapsed") root.dataset.sidebar = "collapsed";
    else delete root.dataset.sidebar;
    try { localStorage.setItem(KEY, state); } catch {}
    sync();
  };
  sync();
  document.addEventListener("click", (e) => {
    if (e.target.closest('[data-toggle="sidebar"]')) { set("collapsed"); return; }
    if (e.target.closest('[data-toggle="sidebar-expand"]')) { set("expanded"); return; }
  });
})();
