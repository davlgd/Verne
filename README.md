# Verne

A minimal static site generator written in [V](https://github.com/vlang/v), with a
Tera-inspired template syntax and a dual V/HTML shortcode system. Verne defines its own small, explicit DSL:

- `{{ value | filter }}` for output, `{% statement %}` for control flow,
- 21 display-only filters (no arithmetic, no set, no macro, no extends),
- a **dual shortcode model**: register a function in V *or* drop an
  `templates/shortcodes/<name>.html` partial — V wins when both exist,
- all aggregation, sorting, and remote fetching happens at build time in V,
  exposed on `site.*` and `page.*`. Templates stay strictly display-only.

The full documentation is published at
[www.verne-ssg.org](https://www.verne-ssg.org/); the source lives under
`docs/` in this repo (build it locally with `mise run build-doc`).

I've developed it to build my personal technical blog ([labs.davlgd.com](https://labs.davlgd.com)) with the
`terminal-garden` theme. It's now available as an independent project.

## Why

Verne exists to:

- ship a single self-contained binary under 2 MB (no Go, no node, no asset pipeline),
- make the template language small enough to read in one sitting
  ([www.verne-ssg.org/reference/templates/](https://www.verne-ssg.org/reference/templates/)),
- let other projects embed the engine as a Tera-style template library,
- stay readable in an afternoon.

## Install

```bash
git clone https://github.com/davlgd/Verne
cd Verne
mise run prod    # or: v -prod -o verne src/
./verne version
```

The resulting `verne` binary is fully self-contained and weighs under 2 MB.

### Runtime dependency: `chroma`

Code-fence highlighting is delegated to the
[`chroma`](https://github.com/alecthomas/chroma) command-line binary
(see [installation instructions](https://github.com/alecthomas/chroma#using-the-chroma-command)).
`verne build` (and `verne server` when it triggers an implicit build) checks at
launch that `chroma` is runnable; otherwise the command exits with a pointer
to the install docs. Compiling Verne itself does not need it.

By default, Verne looks for `chroma` on `$PATH`. The `$VERNE_CHROMA_PATH` environment
variable overrides that lookup with a directory; use `VERNE_CHROMA_PATH=.` when
`chroma` sits next to the `verne` binary:

```bash
VERNE_CHROMA_PATH=/opt/tools/bin verne build
VERNE_CHROMA_PATH=.              verne build   # chroma alongside ./verne
```

## Usage

From a Verne site root (`verne.yaml`, `content/`, `themes/`, `static/`):

```bash
verne build             # render the site to ./public/
verne server            # build, watch, and serve on http://localhost:1313
verne server -p 8080    # custom port
verne server --no-watch # serve the build as-is, no rebuild on change
```

`verne server` watches `content/`, `themes/`, `static/` and `verne.yaml`:
save a file and the site rebuilds, then the open page reloads itself. The
reload script lives only in the dev server's responses — `verne build`
output never contains it.

## Template syntax (mini-Tera)

```
{{ page.title | upper }}
{% if site.posts %}…{% endif %}
{% for p in site.posts %}{{ p.title }}{% endfor %}
{% with shareurl = page.permalink | urlencode %}…{% endwith %}
{% include "partials/head.html" %}
{% shortcode note level="warn" %}body…{% endshortcode %}
```

Whitespace control: `{%-` / `-%}` trims surrounding whitespace.
`trim_blocks` and `lstrip_blocks` are on by default — a statement that
sits on its own line leaves the surrounding lines clean.

Full reference: [www.verne-ssg.org/reference/templates/](https://www.verne-ssg.org/reference/templates/).

## Shortcodes

Two ways to define a shortcode `<name>`:

1. **V** — call `engine.register_shortcode("name", fn (ctx, args) !string { … })`.
2. **HTML** — drop `templates/shortcodes/<name>.html`. Inside, `args` and `body`
   (always `SafeString`) are pre-bound.

V wins when both exist. Full reference: [www.verne-ssg.org/reference/shortcodes/](https://www.verne-ssg.org/reference/shortcodes/).

## Layout

```
Verne/
├── src/
│   ├── main.v              # CLI entrypoint
│   └── modules/
│       ├── template/       # mini-Tera engine (lex / parse / eval / filters)
│       ├── render/         # asset bundling + page render + sitemap/RSS
│       ├── content/        # YAML frontmatter + Markdown + page graph
│       ├── mdrender/       # CommonMark renderer + chroma highlighter
│       ├── assets/         # SHA-256 fingerprint + SRI integrity bundler
│       └── …               # config, frontmatter, remote, yaml, meta
├── docs/                   # the www.verne-ssg.org documentation site (Verne content + theme)
└── examples/
    ├── _shared/            # shared front-end utilities (kbar, theme toggle, scroll-spy)
    ├── verneblog/          # editorial blog example with the verneblog theme
    ├── vernebook/          # long-form book example with the vernebook theme
    └── vernestart/         # bare-bones starter built around the default theme
```

## Examples

Three full sites live under [`examples/`](https://github.com/davlgd/Verne/tree/main/examples)
and double as theme references:

- [`verneblog/`](https://github.com/davlgd/Verne/tree/main/examples/verneblog)
  — editorial blog with the `verneblog` theme.
- [`vernebook/`](https://github.com/davlgd/Verne/tree/main/examples/vernebook)
  — long-form book with chaptered navigation and the `vernebook` theme.
- [`vernestart/`](https://github.com/davlgd/Verne/tree/main/examples/vernestart)
  — minimal starter scaffolded by `verne init`, on the bundled `default` theme.

Build any of them with `verne build examples/<name>`, or run the four
sites (docs + the three above) on ports 1313–1316 simultaneously with
`mise run serve-all`.

## Tests

```bash
mise run test
```

Each module ships with `*_test.v` next to it. The template engine has
31 tests covering parsing, evaluation, filters, shortcodes, and whitespace
control.

## License

[Apache-2.0](LICENSE) — Copyright 2026 David Legrand (davlgd).

---

*Looking for another Jules V. to read? Have a look at*
[Jules Vallès](https://fr.wikipedia.org/wiki/Jules_Vall%C3%A8s).
