/* Shared — chroma copy buttons (event-delegated). Each `.code-wrap`
   carries a `<button class="code-copy">` and a `<pre>`; click copies
   pre.innerText. Falls back to <textarea>+execCommand when clipboard API
   is missing. Themes style `.is-copied`. After a successful copy both
   the visible label and aria-label switch to "copied" so assistive
   tech announces the state change. */
(() => {
  "use strict";
  document.addEventListener("click", async (e) => {
    const btn = e.target.closest(".code-copy");
    if (!btn) return;
    e.preventDefault();
    const wrap = btn.closest(".code-wrap");
    const pre = wrap?.querySelector("pre");
    if (!pre) return;
    const code = pre.querySelector("code") || pre;
    const text = code.innerText;
    const origText = btn.dataset.label || btn.textContent;
    const origAria = btn.dataset.ariaLabel || btn.getAttribute("aria-label") || origText;
    btn.dataset.label = origText;
    btn.dataset.ariaLabel = origAria;
    try {
      if (navigator.clipboard?.writeText && window.isSecureContext) {
        await navigator.clipboard.writeText(text);
      } else {
        const ta = document.createElement("textarea");
        ta.value = text;
        ta.setAttribute("readonly", "");
        ta.setAttribute("aria-hidden", "true");
        ta.style.position = "fixed";
        ta.style.left = "-9999px";
        document.body.appendChild(ta);
        ta.select();
        try { document.execCommand("copy"); } finally { ta.remove(); }
      }
      btn.classList.add("is-copied");
      btn.textContent = "copied";
      btn.setAttribute("aria-label", "Code copied");
      setTimeout(() => {
        btn.classList.remove("is-copied");
        btn.textContent = origText;
        btn.setAttribute("aria-label", origAria);
      }, 1400);
    } catch (err) { console.error("copy failed:", err); }
  });
})();
