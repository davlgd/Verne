---
title: "Templates"
description: "Tera-flavoured templates with explicit constraints."
---


Verne's template engine is a deliberately small Tera/Jinja2 dialect. Two
delimiters, no others:

- **`{{ expr }}`** — print an expression, HTML-escaped by default.
- **`{% statement %}`** — control flow, `include`, `shortcode`.

Whitespace stripping is opt-in via `{{- ... -}}` and `{%- ... -%}`.

## What's there

- `if` / `elif` / `else` / `endif`
- `for x in xs` with a `loop` object exposing `index`, `index0`, `first`,
  `last`, `length`
- `with binding = expr` for a single-block local name
- `include "partials/x.html"` (resolved against the theme's `templates/`)
- 22 built-in display filters (see *Filters* in the sidebar)

## What's not there

- `{% set x = ... %}` — no user-defined variables. Compute in V, expose
  as a precomputed field on `site` or `page`.
- Inline arithmetic — `{{ a + b }}` does not parse. Pre-compute.
- Algorithmic filters: `sort`, `filter`, `group_by`, `slice`, `where`. Same
  reason — pre-compute.
- Macros, template inheritance (`extends` / `block`).

The next two sub-pages (*Filters* and *Shortcodes*) cover the two extension
points templates do have.
