/* Shared — mobile sidebar drawer. Toggles `is-open` on whatever element
   carries `data-mobile-sidebar`, and keeps `aria-expanded` in sync on
   every `[data-toggle="mobile"]` trigger. Themes style `.is-open`. */
(() => {
  "use strict";
  const sidebar = document.querySelector("[data-mobile-sidebar]");
  if (!sidebar) return;
  const triggers = () => document.querySelectorAll('[data-toggle="mobile"]');
  const sync = () => {
    const open = sidebar.classList.contains("is-open");
    triggers().forEach((t) => t.setAttribute("aria-expanded", String(open)));
  };
  sync();
  document.addEventListener("click", (e) => {
    if (e.target.closest('[data-toggle="mobile"]')) {
      sidebar.classList.toggle("is-open");
      sync();
      return;
    }
    if (sidebar.classList.contains("is-open") && !e.target.closest("[data-mobile-sidebar]")) {
      sidebar.classList.remove("is-open");
      sync();
    }
  });
  document.addEventListener("keydown", (e) => {
    if (e.key === "Escape" && sidebar.classList.contains("is-open")) {
      sidebar.classList.remove("is-open");
      sync();
    }
  });
})();
