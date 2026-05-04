---
title: "Introduction"
description: "What 'book-shaped' content looks like in Verne."
---


Verne is a single-binary static site generator written in V. It is not
designed *only* to produce books — it ships a generic Tera-flavoured
template engine, a CommonMark renderer, and an asset pipeline. But
because the template engine is generic, you can produce a book-shaped
site by writing templates that consume an explicit table of contents.

This book is exactly that: a theme that reads `summary:` from
`verne.yaml`, walks the entries in order, and renders each chapter inside
a familiar two-pane layout.

## What Verne brings to the table

- **Source language.** V — a single binary, no runtime to install.
- **Theme model.** Folder of partials + a small Tera-flavoured DSL.
- **Code highlighting.** `chroma` — server-side, classed HTML.
- **Search.** None built-in — drop in Pagefind / Algolia post-build.
- **Live reload.** None — refresh the browser to see edits.
- **Multi-output (PDF, EPUB).** None — content is HTML; convert externally.

The trade-offs are visible: nothing in here surprises a Unix sysadmin,
nothing requires a Node toolchain, nothing ships a 200 MB framework.

## What "book-shaped" means here

A book, in the sense this theme cares about, is a sequence of chapters
with:

- A linear reading order (Chapter 1 → 2 → 3 …)
- A persistent sidebar showing where you are in the sequence
- Forward / back chapter links that match the sidebar
- Code samples and Markdown niceties (tables, blockquotes, anchors)

Everything from this list is demonstrated in the next chapters.
