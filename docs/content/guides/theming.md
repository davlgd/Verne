---
title: "Theming"
description: "Colour tokens, light/dark, custom partials."
---

The theme ships as a folder of CSS, JS, and HTML partials under
`themes/vernedocs/`. Everything is tunable without touching Verne itself.

## Colour tokens

Open `themes/vernedocs/assets/css/style.css`. The first block is a
`:root { ... }` declaration that lists every visual token used by the
theme — surface colours, type stack, density, layout widths. Light and
dark schemes are two sibling blocks that re-declare those tokens.

Override any of them in a sibling stylesheet (loaded after the theme),
or fork the file directly. Both work — Verne does no token-merge magic.

## Light / dark

The theme respects `prefers-color-scheme` by default and remembers a
manual override under the `verne:theme` localStorage key (namespaced
so multiple Verne themes can share state). The toggle in the page header
writes either `light` or `dark`; clearing localStorage resets to "system".

## Adding a partial

Templates live under `themes/vernedocs/templates/`. To add a banner above
the main content area:

```html
<!-- themes/vernedocs/templates/partials/banner.html -->
<aside class="banner not-content">
  <strong>Heads up:</strong> this site is in beta.
</aside>
```

Then `{% include "partials/banner.html" %}` from `_default/single.html` (or
any layout that should show it).

## Custom layouts per section

Verne resolves templates in this order for a page in section `guides/`:

1. `templates/guides/single.html`
2. `templates/_default/single.html`

Drop a section-specific layout when you need one section to look different
(landing pages, changelogs, an FAQ) without forking the default.

## Static assets

Anything inside `themes/vernedocs/static/` is copied verbatim to the build
output. Put images, fonts, downloadable assets there — they're served
under their relative path (e.g. `static/images/diagram.svg` →
`/images/diagram.svg`).
