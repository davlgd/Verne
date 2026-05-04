---
title: "Welcome"
description: "What this book is, and why it exists."
---


This book is a small sample site built with **Verne**, set up to render
chaptered, long-form content with a familiar book-style layout — sidebar
table of contents, prev/next at the foot of every page, light/dark theme.

It exists to answer one question:

> *Without changing Verne's engine, can a maintainer assemble a credible
> book-shaped docs site using only templates, CSS, and a YAML config?*

The short answer is yes — provided you accept three constraints:

1. The chapter list is declared once in `verne.yaml` under `summary:`, not
   auto-discovered from the filesystem.
2. Cross-page search and per-chapter sub-TOCs are out of scope here.
3. Visual fidelity to any specific reference design stops at "looks like
   the same family"; pixel-perfect would need more work.

Use the sidebar (or the right arrow at the bottom of the page) to start
with *Introduction* in Part I.
