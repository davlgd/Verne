---
title: "Introduction"
description: "What Verne is, what it isn't, and the choices behind its small surface."
---

Verne is a static site generator written in [V](https://github.com/vlang/v).
It compiles to a single self-contained binary — under 2 MB on disk —
that takes a folder of Markdown content, a YAML config, and a theme,
and writes a finished website to `./public/`. No Node toolchain, no
framework runtime, no live database.

It is **opinionated and small**. The whole CLI is four subcommands;
the template DSL fits on a printable page; the Markdown renderer and
the YAML parser are hand-rolled to keep the dependency surface flat.
You should be able to read the source in an afternoon.

## What Verne does

- Reads Markdown content (with YAML frontmatter) under `content/`,
  organised by sections (`content/posts/`, `content/chapter/`, etc.).
- Renders each page through a theme: a folder of templates plus
  asset bundles (CSS, JS, fonts), bundled and fingerprinted with
  Subresource Integrity hashes.
- Computes everything else *at build time, in V*: sitemap, RSS feeds,
  taxonomy term pages, page graph (`prev_in_section`, `next_in_section`),
  popular tags, year-grouped contribution heatmaps, footer socials,
  JSON-LD payloads.
- Exposes a tiny **Tera-flavoured** template DSL that does **display only**
  — no inline arithmetic, no algorithmic filter pipelines, no template
  inheritance. If a template needs more than substitution and a few
  `if`/`for`, the answer is a *shortcode* (V code or an HTML partial).
- Highlights code fences via the external [`chroma`](https://github.com/alecthomas/chroma)
  binary — the only runtime dependency.
- Serves the result with `verne server`, watching `content/`, `themes/`,
  `static/` and `verne.yaml` and rebuilding on save; open pages reload
  themselves once the rebuild lands. No websocket, no bundler — a polled
  counter and a `<script>` the dev server injects into its own responses.

## What Verne does not do

- **Multilingual sites** (`languages`, `i18n`).
- **Image processing** (resize, crop, format conversion).
- **PostCSS / JS bundling** beyond plain concatenation and SHA-256
  fingerprinting (no minification, no source maps).
- **Full-text search index** — plug a third-party tool like
  [Pagefind](https://pagefind.app/) into the static output if you need it.
- **Pagination** — the page graph and the precomputed lists are
  enough for most sites; pagination would be a heavier abstraction.

## When to choose Verne

You will probably enjoy Verne if you want:

- a static site generator that ships *one binary* under 2 MB and zero npm packages;
- a template language you can fully internalise on day one;
- precomputed shortcuts (`site.posts`, `site.popular_tags`,
  `page.prev_in_section`, …) instead of doing list operations in the
  template;
- a small enough codebase that you can fork it and extend it without
  feeling lost.

You will probably *not* enjoy Verne if you need a many-language site,
runtime image processing, JSX-style component composition, or any of
the features listed above as out of scope.

## What this site demonstrates

This documentation site is built with Verne, using the bundled
`vernedocs` theme: a two-pane layout with a sidebar driven by the
`summary:` block in `verne.yaml`, an on-this-page TOC generated
server-side from each Markdown page's headings, prev/next chained
through the same `summary:`, light/dark theme toggle, and an
"Edit this page" link template — all using Verne's built-in DSL,
no JavaScript framework.

Three more reference sites live in the repo under
[`examples/`](https://github.com/davlgd/Verne/tree/main/examples) and
each ship their own theme:
[`verneblog`](https://github.com/davlgd/Verne/tree/main/examples/verneblog)
(editorial blog),
[`vernebook`](https://github.com/davlgd/Verne/tree/main/examples/vernebook)
(long-form book with chapter navigation), and
[`vernestart`](https://github.com/davlgd/Verne/tree/main/examples/vernestart)
(minimal `verne init` starter on the bundled `default` theme). Read
their `verne.yaml` and `themes/<name>/templates/` for working layouts
you can adapt.

## Next steps

Continue with [Installation](../installation/) to get a working
binary, then [Quick start](../quick-start/) for the smallest possible
site.
