---
title: "Conclusion"
description: "What this example proved, and what it didn't."
---


If you've reached this page through the sidebar or the *next* arrows on each
chapter, then the engine that drove this book did its job. Let's recap.

## What worked

- **A book-shaped site** without any change to Verne's content engine — the
  layout, sidebar, and prev/next chain were achievable purely with templates,
  CSS, and a `summary:` block in `verne.yaml`.
- **Multi-part navigation**. The sidebar shows three logical parts (header
  rows in the YAML), several top-level chapters, and entries nested up to
  three levels (filters → string / date sub-pages).
- **Single source of truth for ordering**. The same `summary:` list drives
  the sidebar **and** the in-section prev/next chain via a depth-first
  flattening — the two can never disagree.
- **Theme switching** between light, dark, and system, persisted in
  `localStorage`.
- **Server-side syntax highlighting** via `chroma`.
- **Asset pipeline** with fingerprinted CSS / JS and SRI integrity hashes.

## Where the limits show

- No client-side full-text search.
- No automatically generated per-page sub-TOC (i.e. `h2`/`h3` rail on the
  right). Verne does expose `page.toc` as pre-rendered HTML, so this is a
  template-only addition; it's just not done in this example.
- No live reload — the bundled server is plain static HTTP.
- No multi-language books (Verne has no i18n model yet).

## When to use Verne for documentation

For a book whose chapters fit on one finger, with a single language, and
where search is "Cmd-F or nothing", Verne is enough. For something the size
of *The Rust Programming Language*, you'd want at least a search index and
a sub-TOC per page. Both are doable as add-ons without changing the core
engine.

Thanks for reading.
