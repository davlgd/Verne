/* Shared — theme toggle (light/dark, persisted).
   Themes opt in by adding `data-toggle="theme"` on a button. The early
   bootstrap (in each theme's <head>) reads localStorage and applies
   `data-theme` on <html> before paint to avoid FOUC. */
(() => {
  "use strict";
  const root = document.documentElement;
  const KEY = "verne:theme";

  const apply = (t) => {
    if (t === "light" || t === "dark") root.dataset.theme = t;
    else delete root.dataset.theme;
    document.querySelectorAll('[data-toggle="theme"]').forEach((btn) => {
      const isDark = root.dataset.theme === "dark";
      btn.setAttribute("aria-pressed", String(isDark));
      btn.setAttribute("aria-label", isDark ? "Switch to light theme" : "Switch to dark theme");
    });
  };

  apply(root.dataset.theme || (matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light"));

  // Track OS-level theme changes when the user has not made an explicit choice.
  const osMedia = matchMedia("(prefers-color-scheme: dark)");
  osMedia.addEventListener?.("change", (e) => {
    let stored = null;
    try { stored = localStorage.getItem(KEY); } catch {}
    if (stored === "light" || stored === "dark") return;
    apply(e.matches ? "dark" : "light");
  });

  document.addEventListener("click", (e) => {
    if (!e.target.closest('[data-toggle="theme"]')) return;
    const cur = root.dataset.theme || (matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light");
    const next = cur === "dark" ? "light" : "dark";
    apply(next);
    try { localStorage.setItem(KEY, next); } catch {}
  });
})();
