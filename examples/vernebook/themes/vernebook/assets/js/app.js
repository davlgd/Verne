/* vernebook — book-specific behaviour. The shared JS modules in
   `themes/_shared/js/` already cover: theme toggle, mobile drawer,
   sidebar collapse, reading-progress bar, scroll-spy, copy buttons, kbar
   palette. This file adds the bits that are unique to the book reader:
     - hover prev/next side-bands + ←/→ keyboard chapter nav (with home
       fallback so ArrowRight on the cover opens the first chapter)
     - "Print the whole book" button (client-side fetch + aggregate) */

(() => {
  "use strict";

  /* ───── prev/next chevrons + keyboard nav ───── */
  const prevLink = document.querySelector('[data-vb-prev]');
  const nextLink = document.querySelector('[data-vb-next]');
  let prevHref = prevLink?.href || null;
  let nextHref = nextLink?.href || null;
  if (document.body.dataset.page === "home") {
    const first = document.querySelector('.vb-toc .vb-toc-item');
    if (first?.href) nextHref = first.href;
  }
  const chevPrev = document.querySelector('.vb-chev--prev');
  const chevNext = document.querySelector('.vb-chev--next');
  if (chevPrev && prevHref) {
    chevPrev.hidden = false;
    chevPrev.addEventListener("click", () => { window.location.href = prevHref; });
  }
  if (chevNext && nextHref) {
    chevNext.hidden = false;
    chevNext.addEventListener("click", () => { window.location.href = nextHref; });
  }
  document.addEventListener("keydown", (e) => {
    if (e.altKey || e.ctrlKey || e.metaKey || e.shiftKey) return;
    const t = e.target;
    if (t && (t.tagName === "INPUT" || t.tagName === "TEXTAREA" || t.isContentEditable)) return;
    if (e.key === "ArrowLeft" && prevHref) { e.preventDefault(); window.location.href = prevHref; }
    else if (e.key === "ArrowRight" && nextHref) { e.preventDefault(); window.location.href = nextHref; }
  });

  /* ───── print whole book ─────
     Fetch every chapter URL from the sidebar TOC, extract its <article>
     content, assemble a hidden <div class="vb-print-doc"> that print CSS
     reveals, then trigger window.print(). */
  document.querySelectorAll('[data-action="print-book"]').forEach((printBtn) => {
    printBtn.addEventListener("click", async (e) => {
      e.preventDefault();
      const orig = printBtn.innerHTML;
      printBtn.disabled = true;
      printBtn.setAttribute("aria-busy", "true");
      try {
        const urls = collectChapterUrls();
        const sections = await Promise.all(urls.map(fetchChapter));
        renderPrintDoc(sections);
        document.body.classList.add("is-printing");
        await new Promise((r) => setTimeout(r, 60));
        window.print();
      } catch (err) {
        console.error("print-whole-book failed:", err);
      } finally {
        const cleanup = () => {
          document.body.classList.remove("is-printing");
          const doc = document.querySelector(".vb-print-doc");
          if (doc) doc.remove();
          printBtn.disabled = false;
          printBtn.removeAttribute("aria-busy");
          printBtn.innerHTML = orig;
          window.removeEventListener("afterprint", cleanup);
        };
        window.addEventListener("afterprint", cleanup);
        setTimeout(cleanup, 30000);
      }
    });
  });

  function collectChapterUrls() {
    const out = [];
    let part = null;
    document.querySelectorAll(".vb-toc > li").forEach((li) => {
      if (li.classList.contains("vb-toc-section")) {
        part = li.textContent.trim();
        out.push({ part });
      } else {
        const a = li.querySelector(":scope > .vb-toc-item");
        if (a?.href) {
          const num = a.querySelector(".vb-toc-num")?.textContent?.trim() || "";
          const title = a.querySelector(".vb-toc-text")?.textContent?.trim() || "";
          out.push({ url: a.href, num, title, part });
        }
        li.querySelectorAll(":scope .vb-toc-children .vb-toc-item").forEach((sa) => {
          const num = sa.querySelector(".vb-toc-num")?.textContent?.trim() || "";
          const title = sa.querySelector(".vb-toc-text")?.textContent?.trim() || "";
          if (sa.href) out.push({ url: sa.href, num, title, part });
        });
      }
    });
    return out;
  }

  async function fetchChapter(entry) {
    if (entry.part && !entry.url) return entry;
    try {
      const res = await fetch(entry.url, { credentials: "same-origin" });
      const html = await res.text();
      const doc = new DOMParser().parseFromString(html, "text/html");
      const prose = doc.querySelector(".vb-prose");
      const subtitle = doc.querySelector(".vb-ch-subtitle")?.textContent?.trim() || "";
      return { ...entry, html: prose?.innerHTML || "", subtitle };
    } catch {
      return { ...entry, html: "", subtitle: "" };
    }
  }

  function renderPrintDoc(sections) {
    const old = document.querySelector(".vb-print-doc");
    if (old) old.remove();
    const root = document.createElement("div");
    root.className = "vb-print-doc";
    const siteTitle = document.querySelector(".vb-brand-title")?.textContent || document.title;
    const description = document.querySelector('meta[name="description"]')?.content || "";

    const safeTitle = escapeHTML(siteTitle);
    let html = "";
    html += `<section class="vb-print-cover">
      <p class="pc-eyebrow">${safeTitle}</p>
      <h1 class="pc-title">${safeTitle}</h1>
      <p class="pc-tag">${escapeHTML(description)}</p>
      <p class="pc-meta">Printed ${new Date().toISOString().slice(0,10)}</p>
    </section>`;

    html += `<section class="vb-print-toc page-break"><h2>Table of contents</h2><ol>`;
    for (const s of sections) {
      if (s.part && !s.url) html += `<li class="pt-part">${escapeHTML(s.part)}</li>`;
      else html += `<li><span class="pt-num">${escapeHTML(s.num)}</span><span>${escapeHTML(s.title)}</span></li>`;
    }
    html += `</ol></section>`;

    let lastPart = null;
    for (const s of sections) {
      if (s.part && !s.url) {
        if (s.part !== lastPart) {
          html += `<section class="vb-print-part page-break">
            <p class="pp-eyebrow">Part</p>
            <h2 class="pp-title">${escapeHTML(s.part)}</h2>
          </section>`;
          lastPart = s.part;
        }
        continue;
      }
      html += `<section class="vb-print-chapter page-break">
        ${s.num ? `<p class="pc-num">Chapter ${escapeHTML(s.num)}</p>` : ""}
        <h2 class="pc-h">${escapeHTML(s.title)}</h2>
        ${s.subtitle ? `<p class="pc-sub">${escapeHTML(s.subtitle)}</p>` : ""}
        <div class="vb-prose">${s.html || ""}</div>
      </section>`;
    }
    root.innerHTML = html;
    document.body.appendChild(root);
  }

  function escapeHTML(s) {
    return String(s).replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
  }
})();
