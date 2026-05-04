/* Shared — kbar command palette. Wires the `#kbarOverlay` partial.
   Open via ⌘K / Ctrl+K, "/" (when not typing), or any `.kbar-trigger` /
   `[data-toggle="search"]` element. ↑↓ navigates, Enter opens, Esc
   closes. Focus is trapped inside while open and restored to the
   trigger on close. The active option is announced via
   `aria-activedescendant` on the input (combobox pattern). */
(() => {
  "use strict";
  const overlay = document.getElementById("kbarOverlay");
  const input = document.getElementById("kbarInput");
  const empty = document.getElementById("kbarEmpty");
  if (!overlay || !input) return;

  const items = Array.from(overlay.querySelectorAll(".kbar-item"));
  const sectionHeaders = Array.from(overlay.querySelectorAll(".kbar-section-h"));
  items.forEach((it, i) => { if (!it.id) it.id = "kbar-i-" + i; });

  let active = -1;
  let opener = null;

  const visibleItems = () => items.filter((it) => !it.hidden);
  const clearActive = () => {
    items.forEach((it) => {
      it.classList.remove("is-active");
      it.setAttribute("aria-selected", "false");
    });
    input.removeAttribute("aria-activedescendant");
    active = -1;
  };
  const setActive = (i) => {
    const vis = visibleItems();
    items.forEach((it) => {
      it.classList.remove("is-active");
      it.setAttribute("aria-selected", "false");
    });
    if (!vis.length) { input.removeAttribute("aria-activedescendant"); active = -1; return; }
    active = ((i % vis.length) + vis.length) % vis.length;
    const cur = vis[active];
    cur.classList.add("is-active");
    cur.setAttribute("aria-selected", "true");
    input.setAttribute("aria-activedescendant", cur.id);
    cur.scrollIntoView({ block: "nearest" });
  };
  const filter = (q) => {
    const needle = q.trim().toLowerCase();
    let any = false;
    items.forEach((it) => {
      const hay = (it.dataset.search || "").toLowerCase();
      const ok = !needle || hay.includes(needle);
      it.hidden = !ok;
      if (ok) any = true;
    });
    sectionHeaders.forEach((h) => { h.hidden = needle !== ""; });
    if (empty) empty.hidden = any;
  };
  const open = (trigger) => {
    opener = trigger || document.activeElement;
    overlay.hidden = false;
    input.setAttribute("aria-expanded", "true");
    input.value = "";
    filter("");
    clearActive();
    requestAnimationFrame(() => input.focus());
  };
  const close = () => {
    overlay.hidden = true;
    input.setAttribute("aria-expanded", "false");
    if (opener && typeof opener.focus === "function") opener.focus();
    opener = null;
  };

  const focusables = () =>
    Array.from(overlay.querySelectorAll('input, button, [href], [tabindex]:not([tabindex="-1"])'))
      .filter((el) => !el.hidden && !el.disabled);

  document.addEventListener("keydown", (e) => {
    const k = e.key?.toLowerCase();
    if ((e.metaKey || e.ctrlKey) && k === "k") { e.preventDefault(); open(); return; }
    if (k === "/" && !overlay.hidden) return;
    if (k === "/" && !["INPUT","TEXTAREA"].includes(document.activeElement?.tagName) && !document.activeElement?.isContentEditable) {
      e.preventDefault(); open(); return;
    }
    if (overlay.hidden) return;
    if (k === "escape") { e.preventDefault(); close(); }
    else if (k === "arrowdown") { e.preventDefault(); setActive(active < 0 ? 0 : active + 1); }
    else if (k === "arrowup")   { e.preventDefault(); setActive(active < 0 ? -1 : active - 1); }
    else if (k === "enter") {
      const vis = visibleItems();
      const it = active >= 0 ? vis[active] : vis[0];
      if (it?.dataset.url) { window.location.href = it.dataset.url; close(); }
    } else if (k === "tab") {
      const f = focusables();
      if (!f.length) return;
      // With only one focusable (the input), Tab/Shift-Tab would otherwise
      // escape to the page behind the modal — keep focus inside.
      if (f.length === 1) { e.preventDefault(); f[0].focus(); return; }
      const first = f[0], last = f[f.length - 1];
      if (e.shiftKey && document.activeElement === first) { e.preventDefault(); last.focus(); }
      else if (!e.shiftKey && document.activeElement === last) { e.preventDefault(); first.focus(); }
    }
  });

  document.querySelectorAll('[data-toggle="search"], .kbar-trigger').forEach((btn) => {
    btn.addEventListener("click", (e) => { e.preventDefault(); open(btn); });
  });

  overlay.addEventListener("click", (e) => {
    if (e.target === overlay) { close(); return; }
    const it = e.target.closest(".kbar-item");
    if (it?.dataset.url) { window.location.href = it.dataset.url; close(); }
  });

  input.addEventListener("input", () => { filter(input.value); clearActive(); });
})();
