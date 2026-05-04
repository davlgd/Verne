---
title: "The Verne Book"
description: "A book-shaped example showcasing Verne's template engine."
---

# The Verne Book

Welcome to the **Verne Book** — a self-contained example demonstrating how
[Verne](https://github.com/davlgd/Verne) renders long-form, chaptered
content. The whole site is driven by Verne's built-in template engine and a
hand-written theme; there is no JavaScript framework, no client-side
runtime, and no external build step.

## What this example shows

- A two-column **book-style layout** — sidebar table of contents on the
  left, reading column on the right.
- A **light/dark theme toggle** with `prefers-color-scheme` as the
  fallback for users who haven't expressed a preference.
- **Server-side syntax highlighting** for code fences (via `chroma`).
- **Previous/next chapter navigation** using Verne's `prev_in_section`
  and `next_in_section` page links.
- An **explicit, ordered table of contents** declared once in
  `verne.yaml` under the top-level `summary:` key. The same list drives
  both the sidebar **and** the in-section prev/next chain.

## What it does *not* try to do

- Live reload (Verne's `verne server` is plain static HTTP — refresh in
  the browser to see edits).
- Client-side full-text search (no built-in index generator yet).
- An embedded code playground.
- Multilingual books.

Use the sidebar — or the arrows below — to start with the
[Welcome](./chapter/01-welcome/) chapter.
