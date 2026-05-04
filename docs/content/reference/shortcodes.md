---
title: "Shortcodes"
description: "HTML and V shortcodes — registration, resolution, distribution."
---

Shortcodes are reusable, parameterised fragments. They are the **only**
mechanism in Verne for putting computation alongside content. If a template
needs more than substitution + a few `if`/`for`, the answer is a shortcode.

There are two kinds:

1. **HTML shortcodes** — a small template under `templates/shortcodes/`
   that produces HTML. No recompilation needed; users edit them as files.
2. **V shortcodes** — V code, compiled into the binary, registered via the
   shortcodes API. For features that need real logic, external calls, or
   reusability across projects.

Both kinds are invoked the same way and a V shortcode takes priority over
a same-named HTML one.

## Invocation

Inside a template file. The `youtube` and `callout` names below are
**illustrative** — Verne ships zero built-in shortcodes; you provide
either a V handler or an HTML file under `templates/shortcodes/`
before either call site below resolves.

Self-closing (no body):

```jinja
{% shortcode youtube id="aBc123" %}
```

Paired (with body):

```jinja
{% shortcode callout type="warn" %}
The deployment will cut access for **5 minutes**.
{% endshortcode %}
```

Shortcodes are a **template-only** feature in this release: you call
them from a layout (`single.html`, `list.html`, a partial), not from
inside a Markdown file. For inline page-body annotations, use
GitHub-style alert blockquotes (`> [!NOTE]`, `> [!WARNING]`, …) —
those are parsed natively by Verne's CommonMark renderer. See
[Writing content → Callouts](../../guides/writing-content/#callouts-github-style-alerts).

Arguments are `name=value` pairs after the shortcode name. Values may be:

- string literal: `type="warn"` or `type='warn'`
- integer: `width=400`
- boolean: `loop=true`
- a reference to a context variable: `tag=current_tag`

Shortcode names are template identifiers — `[A-Za-z_][A-Za-z0-9_]*`.
Hyphens are **not** valid; use `snake_case` for multi-word names:
`youtube`, `tweet_quote`, `gallery`.

## HTML shortcodes

Drop a file at `templates/shortcodes/<name>.html`. It runs through the
same template engine as any layout, with two extra context variables:

- `args` — a map of the named arguments passed at the call site.
- `body` — the inner content as a `SafeString` (already-evaluated
  template body). Empty string for self-closing shortcodes. `{{ body }}`
  and `{{ body | safe }}` produce the same output.

`page`, `site`, and `config` are inherited from the surrounding scope,
same as any included partial.

Example: `templates/shortcodes/callout.html`:

```html
<div class="callout callout-{{ args.type | default('info') }}">
  {% if args.title %}
    <div class="callout-title">{{ args.title }}</div>
  {% endif %}
  <div class="callout-body">{{ body | safe }}</div>
</div>
```

Used in a template:

```jinja
{% shortcode callout type="warn" title="Heads up" %}
Don't deploy on Friday.
{% endshortcode %}
```

Renders to:

```html
<div class="callout callout-warn">
  <div class="callout-title">Heads up</div>
  <div class="callout-body"><p>Don't deploy on Friday.</p></div>
</div>
```

### Argument access patterns

```jinja
{{ args.name }}                    -- direct
{{ args.name | default('foo') }}   -- with fallback
{% if args.name is defined %}…{% endif %}
{% for key, value in args %}…{% endfor %}
```

There is **no** way to define default values declaratively — use
`| default(x)` at every reference. Explicit beats implicit.

## V shortcodes

For functionality that needs computation (HTTP fetches, file reads,
complex data shaping), write a V shortcode. Register it on the engine:

```v
import template

fn youtube(ctx template.ShortcodeContext, args map[string]template.Value) !string {
    id_v := args['id'] or { return error('youtube: missing id') }
    id := template.to_string(id_v)
    return '<iframe src="https://www.youtube-nocookie.com/embed/${id}" loading="lazy" allowfullscreen></iframe>'
}

fn main() {
    mut e := template.new()
    e.register_shortcode('youtube', youtube)
    // … then use e.render_template(...) as usual
}
```

Signature:

```v
pub type ShortcodeFn = fn (ctx ShortcodeContext, args map[string]Value) !string

pub struct ShortcodeContext {
pub:
    body string  // evaluated body (empty for self-closing)
    page Value   // current `page` from scope (or `none_value`)
    site Value   // current `site` from scope (or `none_value`)
}
```

- `args[name]` returns a `Value` (sum type: string, i64, bool, list, map,
  Object, Date, SafeString). Use `template.to_string(v)` for a string
  view, or pattern-match on the sum type for typed access.
- Return a `string` of HTML; the engine writes it verbatim (not
  re-escaped).
- Return `error(...)` to fail the build with a clear message — the
  engine prepends the shortcode name and source location.

### Distributing V shortcodes

V shortcodes are normal V code, so they can be packaged as a V module
and imported into someone else's Verne build. Convention:

- Module name: `verne-shortcodes-<topic>` (e.g.
  `verne-shortcodes-mermaid`).
- Each module exposes a `register(mut e &template.Engine)` function that
  registers all its shortcodes in one call.
- Shortcodes from different packages must not collide on names — call
  sites registering the second one will overwrite the first.

```v
// in your custom Verne main.v
mermaid.register(mut engine)
mathjax.register(mut engine)
```

Adding or removing a V shortcode is the only thing that requires
recompiling your Verne binary. HTML shortcodes are loaded from disk at
build time and can be edited without recompiling.

## Resolution order

When the engine encounters `{% shortcode foo %}`:

1. Look up `foo` in the V shortcode registry. If found, invoke it.
2. Otherwise, look for `templates/shortcodes/foo.html`. If found, render it.
3. Otherwise, error: `unknown shortcode 'foo'`.

V shortcodes win because they are typically distributed and tested; HTML
shortcodes are project-local. A user can override a packaged V
shortcode by not registering it in their `main.v`.

## Built-in shortcodes

Verne ships **zero** built-in shortcodes. Names like `callout`, `note`,
`youtube`, `tweet_quote` that appear in this guide are conventions
borrowed from the wider SSG ecosystem — when you see them used here,
treat them as the names *you* would pick if you wrote the matching
handler. Themes are free to ship their own; today none of the bundled
themes register any either.

## Best practices

- **Validate args early**. If a required arg is missing, return an
  error; do not silently render a broken HTML fragment.
- **Escape user input**. The `body` is already-rendered HTML; arg values
  are raw strings — pass them through `escape` (or use `{{ args.foo }}`
  which escapes by default) unless you mean to inject HTML.
- **Keep V shortcodes pure**. No global state, no caching at the
  shortcode level — that's the engine's job.
- **One file per HTML shortcode**. Even if it's three lines.
- **Document arguments at the top of the file** as a `{# … #}` comment
  block.
