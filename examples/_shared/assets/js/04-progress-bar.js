/* Shared — reading-progress bar. Themes opt in by rendering an empty
   element with `data-reading-progress`; the script updates its width. */
(() => {
  "use strict";
  const bar = document.querySelector("[data-reading-progress]");
  if (!bar) return;
  const update = () => {
    const h = document.documentElement;
    const total = h.scrollHeight - h.clientHeight;
    bar.style.width = total > 0 ? (h.scrollTop / total) * 100 + "%" : "0%";
  };
  update();
  document.addEventListener("scroll", update, { passive: true });
  window.addEventListener("resize", update, { passive: true });
})();
