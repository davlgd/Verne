/* Shared — on-this-page scroll-spy. Looks for `[data-toc-rail]` whose
   contents are the chroma-style `<nav id="TableOfContents">…</nav>`.
   Marks the active rail link with `.active` based on the heading nearest
   to the top of the viewport. */
(() => {
  "use strict";
  const rail = document.querySelector("[data-toc-rail]");
  if (!rail) return;
  const links = rail.querySelectorAll('nav#TableOfContents a[href^="#"]');
  if (!links.length) return;
  const linkByHash = new Map();
  links.forEach((a) => linkByHash.set(decodeURIComponent(a.getAttribute("href")), a));
  const headings = Array.from(linkByHash.keys())
    .map((h) => document.getElementById(h.slice(1)))
    .filter(Boolean);
  if (!headings.length) return;

  let active = null;
  const setActive = (h) => {
    if (active === h) return;
    active = h;
    links.forEach((a) => a.classList.toggle("active", a.getAttribute("href") === "#" + h.id));
  };
  const closestAbove = () => {
    const top = window.scrollY + 100;
    let best = headings[0];
    for (const h of headings) if (h.offsetTop <= top) best = h; else break;
    return best;
  };
  const io = new IntersectionObserver((entries) => {
    const visible = entries.filter((e) => e.isIntersecting).map((e) => e.target);
    if (visible.length) {
      visible.sort((a, b) => a.offsetTop - b.offsetTop);
      setActive(visible[0]);
    } else {
      setActive(closestAbove());
    }
  }, { rootMargin: "-80px 0px -65% 0px", threshold: [0, 1] });
  headings.forEach((h) => io.observe(h));
  setActive(headings[0]);
})();
