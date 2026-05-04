---
title: "Shortcodes"
description: "V-registered helpers callable from templates as block-level statements."
---


A shortcode is a V-side function wired into the template engine, invoked
from a template like:

```jinja
{% shortcode callout type="warn" %}
This is **important**.
{% endshortcode %}
```

There are two flavours:

- **Self-closing**: `{% shortcode youtube id="abc123" %}` — no body.
- **Paired**: `{% shortcode foo arg=val %}…{% endshortcode %}` — a body that
  the shortcode receives as a string.

## Why use a shortcode and not a filter?

A filter takes a value and returns a value, so it sits inside an
expression. A shortcode is a *statement* — it can do I/O, render Markdown,
call into V's standard library, and return a multi-line block of HTML. Use
filters for transformations of the value at hand; use shortcodes when you
want a high-level rendering primitive ("YouTube embed", "callout box",
"Markdown nested inside HTML").

## Registering one

```v
import template

mut e := template.new()
e.register_shortcode('youtube', fn (ctx template.ShortcodeContext, args map[string]template.Value) !string {
    id := template.to_string(args['id'] or { template.Value('') })
    return '<iframe src="https://www.youtube-nocookie.com/embed/${id}"></iframe>'
})
```

## A note on safety

Shortcodes return raw HTML — they bypass the engine's HTML escaping. That
means: validate inputs, escape what you don't trust, and never interpolate
user input into HTML attributes without going through `escape_attr`.
