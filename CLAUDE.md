# Verne — Claude working notes

This file is for Claude (and any other AI agent) working in this repository.
It documents project-specific conventions that are not derivable from `git log`
or by reading the code.

## Project intent

Verne is a single-binary, V-language static site generator with its own small
template DSL (Tera-flavoured) and a dual V/HTML shortcode system. It exists
to render `labs.davlgd.com` and to be reusable as a standalone SSG by other
projects.

When in doubt about a feature: if the labs site does not need it and the
DSL spec does not require it, do not implement it. Add a TODO instead.

## Code conventions

- **V style**: `v fmt -w` everything. No exceptions.
- **No external V dependencies**. Standard library only (`os`, `time`,
  `strings`, `regex`, `json2`, `crypto.sha256`, `net.http` for the dev
  server).
- **Modules are flat** under `src/modules/<name>/`, siblings of `src/main.v`,
  so V resolves them as local imports without `VMODULES`. Each module has a
  `*_test.v` next to its source files. Tests are run with `mise run test`
  (i.e. `v test src/`) from the repo root.
- **Public API**: only export what is needed. V's lowercase = private.
- **Errors**: return `!Type` and propagate with `?`/`!`. No panics in
  libraries. The CLI in `src/` is the only place that may `eprintln` and
  `exit(1)`.
- **Comments**: prose comments inside function bodies are reserved for the
  *why* (a hidden constraint, an invariant, a workaround) — names carry the
  *what*. The exception is **`pub fn` docstrings**: `v vet` requires every
  public function to be preceded by a `// name …` doc line, the same role as
  jsdoc/godoc. Keep them to a single sentence describing the contract.
- **One responsibility per module**. Cross-module imports go one way:
  `cli → render → {content, template, assets, mdrender, config, remote,
  highlight}`.
- **Module names describe roles, not versions**. No `v2`, `v3` suffixes.

## Module map

```
src/modules/
├── template/      # mini-Tera engine (lex / parse / eval / filters / shortcodes)
├── render/        # asset bundling, page render loop, sitemap/RSS/robots
├── content/       # YAML frontmatter + Markdown + page graph + template adapter
├── mdrender/      # CommonMark renderer + chroma highlighter wrapper
├── assets/        # SHA-256 fingerprint + SRI integrity bundler
├── config/        # verne.yaml loader
├── frontmatter/   # YAML frontmatter splitter
├── remote/        # disk-cached HTTP fetch (used by Site.fetch_projects)
├── yaml/          # tiny YAML subset parser
├── highlight/     # external `chroma` invocation
└── meta/          # name + version constants
```

The `content/template_adapter.v` file is the bridge between the page graph
and the template engine: it exposes `Site` and `Page` as lazy
`template.Object`s (`as_template_object()`).

## Testing rules

- Every module ships with tests **before** it is declared functional.
- Prefer table-driven tests (V supports them via `[]struct{}` arrays).
- A user-facing PR is not done until `mise run test` is green and the labs
  site at `/Users/davlgd/Documents/GitHub/labs` still builds end-to-end via
  `verne build`.

## DSL — the hard constraints

The labs `terminal-garden` theme drives the spec. The engine MUST support:

- `{{ expr }}` (HTML-escaped by default) and `{% statement %}` delimiters
- `{%- ... -%}` whitespace control + `trim_blocks` + `lstrip_blocks` defaults
- `{% if/elif/else/endif %}`, `{% for x in xs %}…{% endfor %}` (with `loop`
  object: `index`, `index0`, `reverse_index`, `first`, `last`, `length`),
  `{% with binding = expr %}…{% endwith %}`
- `{% include "path/to/partial.html" %}` (resolved against engine `roots`)
- `{% shortcode name arg=val %}` self-closing and `{% endshortcode %}` paired
- comparison (`==`, `!=`, `<`, `<=`, `>`, `>=`), boolean (`and`, `or`, `not`),
  membership (`in`), tests (`is defined`, `is none`, `is empty`, `is string`,
  `is number`, `is list`, `is map`)
- 21 display filters (see `docs/content/reference/templates.md`); pipe form only (`x | f(args)`)

## What we explicitly do NOT support

- Go-template-style directives (`{{ define }}`, `{{ partial }}`, `{{ range }}`,
  `{{ block }}`, `{{ index . "x" }}`, `add`/`sub`/`mul` arithmetic, etc.)
- User-defined variables: no `{% set x = ... %}`
- Macros, template inheritance (`extends`/`block`)
- Algorithmic filter pipelines (`filter`, `sort`, `group_by`, `slice`,
  `where`, `first`, `last`, `reverse`) — pre-compute these in V and expose
  on `site.*` / `page.*`
- Inline arithmetic in expressions (`{{ a + b }}`)
- Multilingual (`Languages`, `i18n`)
- Image processing (`.Resize`, `.Fit`, `.Fill`)
- PostCSS / JS bundling
- Live reload (the `verne server` is plain HTTP over `./public/`)
- Shortcodes inside Markdown content (template-level only for now)
- Pagination

## Themes share JS — never duplicate it

Verne ships several example themes under `examples/<theme>/themes/<theme>/`.
They share a canonical pile of front-end utilities under
`examples/_shared/`, symlinked into each project as `themes/_shared/`. The
engine, in `render.bundle_assets()`, alphabetically concatenates every
`.js` file from `themes/_shared/assets/js/` *before* the theme's own
`assets/js/app.js`, and `template.add_root` registers
`themes/_shared/templates/` as a fallback root so themes can
`{% include "partials/kbar.html" %}` with no per-theme copy.

What lives in `_shared/`:

- `assets/js/01-theme.js` — light/dark toggle (`data-toggle="theme"`).
- `assets/js/02-mobile-drawer.js` — mobile sidebar drawer.
- `assets/js/03-sidebar-collapse.js` — desktop sidebar collapse + persist.
- `assets/js/04-progress-bar.js` — reading-progress bar
  (`[data-reading-progress]`).
- `assets/js/05-scroll-spy.js` — on-this-page active link
  (`[data-toc-rail]`).
- `assets/js/06-copy-buttons.js` — chroma copy buttons (event-delegated).
- `assets/js/07-kbar.js` — ⌘K / `/` command palette.
- `templates/partials/kbar.html` — the palette markup.

Conventions for theme authors:

- **A theme's `app.js` only contains what's truly specific to it.** Don't
  re-implement theme toggle, copy buttons, scroll-spy, etc. — they're
  already in the shared bundle. If you find yourself adding the same
  helper to two themes, move it to `_shared/assets/js/` instead.
- **Use the neutral DOM hooks** so the shared modules find your elements:
  `data-toggle="theme|mobile|sidebar|sidebar-expand|search"`,
  `data-mobile-sidebar` on the nav element, `data-toc-rail` on the
  on-this-page wrapper, `data-reading-progress` on the progress bar,
  `.kbar-trigger` on any element that should open the palette.
- **CSS stays per-theme** — the shared modules do not impose any visual
  language; each theme paints what it wants. Only the structural class
  names that `_shared/templates/partials/kbar.html` emits
  (`.kbar-overlay`, `.kbar-item`, `.code-wrap`, `.code-copy`,
  `.code-meta`, `.callout-title`, etc.) are part of the cross-theme
  contract.
- **localStorage keys are namespaced `verne:*`** (e.g. `verne:theme`,
  `verne:sidebar`) so themes share state — never `<theme>:theme`.

When a third theme is added, audit `_shared/` first; only land theme-only
behaviour in the new theme's `app.js`.

## Reviewing your own work

Before declaring a feature done, run the relevant skills in
`.claude/skills/`. Each is a **review prompt**, not an autopilot — read
it, apply it, fix the findings before moving on.

Always-on (run on every change):

1. `senior-v-reviewer` — idiomatic V, clarity, error handling.
2. `ux-dx-reviewer` — CLI ergonomics, error messages, defaults.
3. `pentest-reviewer` — path traversal, template injection, SSRF,
   command injection in the highlight subprocess.

Scoped (run when the change touches the relevant area):

4. `docs-reviewer` — when touching `docs/content/**/*.md`, README, or any
   feature whose contract is documented (filters, config keys, CLI flags,
   page/site fields). Cross-checks every factual claim against the V
   source so the docs site does not drift.
5. `theme-reviewer` — when adding or modifying a theme under
   `docs/themes/<name>/` or `examples/<site>/themes/<name>/`. Walks the
   shared-JS contract from "Themes share JS — never duplicate it" plus
   light/dark, a11y, and the renderer's markup contract.

## Don't

- Do not introduce a YAML library; we hand-roll a small subset.
- Do not introduce a goldmark/Markdown library; same reason.
- Do not add features speculatively. Three similar lines beat a wrong abstraction.
- Do not version-suffix modules or files (`render2.v`, `template_v3.v`, …).
  Either replace the role-named file in place, or pick a new role name.
- Do not commit unless the user explicitly asks for it.
