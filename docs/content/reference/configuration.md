---
title: "Configuration"
description: "Every key that `verne.yaml` understands."
---

Verne loads `verne.yaml` (or `verne.yml`) from the project root. The
schema is small and validated at load time — unknown keys are tolerated,
each documented key has a fixed type and meaning.

## Top-level keys

- **`title`** — *string.* Site title. Drives `<title>`, the header brand,
  and the RSS `<title>`.
- **`baseURL`** — *string.* Canonical site URL with scheme and trailing
  slash. Validated at load time; must be `http://` or `https://`.
- **`locale`** — *string, default `en`.* BCP 47 short or full form
  (`en`, `en-us`, `fr`). Drives the `<html lang>` and OG locale.
- **`theme`** — *string.* Theme directory name under `themes/`.
- **`enableRobotsTXT`** — *bool, default `true`.* Emit a `robots.txt`
  with `User-agent: *` / `Allow: /` and a `Sitemap:` line pointing at
  `<baseURL>sitemap.xml`. Set to `false` to skip the file (e.g. for a
  staging environment you want crawlers to ignore by other means).
- **`enableEmoji`** — *bool, default `false`.* Convert emoji shortcodes
  (`:rocket:`) in Markdown into Unicode glyphs.
- **`frontmatter`** — *map, default `{}`.* Aliases for frontmatter keys.
  Today only `date` is honoured: `date: ["pubDatetime", "publishDate"]`
  lets a site store the publish date under one of the listed keys instead
  of the default `date`.
- **`edit_url`** — *string, default empty.* URL template with a `{path}`
  placeholder, substituted per page with its source path under
  `content/`. Powers the "Edit this page" link.
- **`permalinks`** — *map, default `{}`.* Per-section URL templates.
- **`taxonomies`** — *map, default `{}`.* Singular → plural map (e.g.
  `{tag: tags}`). When `tags` is among the plural values, auto-creates
  `/tags/<slug>/` index pages and per-term RSS feeds.
- **`summary`** — *list, default empty.* Explicit table of contents that
  drives the sidebar and the in-section `prev/next` chain.
- **`params`** — *map, default `{}`.* Free-form values exposed as
  `site.params.*`. Theme-specific extras (tagline, socials, UI strings,
  etc.) live here.
- **`markup`**, **`outputs`**, **`security`** — *maps, default `{}`.*
  Reserved keys: parsed if present so a future Verne release can pick
  them up, but currently unused. Setting them today has no effect.

## `permalinks`

```yaml
permalinks:
  posts: "/posts/:slug/"
  guides: "/guides/:slug/"
```

Tokens: `:slug`, `:year`, `:month`, `:day`, `:section`, `:filename`. A
section without an explicit permalink defaults to `/<section>/<slug>/`.

## `summary`

The table of contents. Each entry is one of:

- `{title, url}` — a leaf link
- `{title, url, children: [...]}` — a parent link with nested entries
- `{header: "..."}` — a visual divider with no link

Nesting is bounded at 16 levels. URLs must be site-relative (`/foo/`),
in-page anchors (`#bar`), or explicit `http(s)://`. `javascript:` and
`data:` schemes are rejected at load time.

## `params`

Anything you put under `params:` is available to templates as
`site.params.*`. Common patterns:

```yaml
params:
  tagline: "A small place on the web."
  description: "Site-wide description for meta tags."
  recent_posts_limit: 5     # how many posts on the home (default 5)
  socials:
    github: "https://github.com/davlgd/Verne"
    mastodon: "https://hachyderm.io/@davlgd"
```

The theme decides what to display. Verne itself does no automatic
rendering of `params` — they're just typed values exposed to your
templates.

## `edit_url`

```yaml
edit_url: "https://github.com/me/repo/edit/main/content/{path}"
```

`{path}` is substituted with the page's source path under `content/`.
Compatible with GitHub, GitLab, Codeberg, Forgejo, sourcehut. The
template must contain the `{path}` placeholder; otherwise loading fails
loudly to prevent silently producing identical edit links on every page.

## Loading rules

1. Verne looks for `verne.yaml` first, falls back to `verne.yml`.
2. Errors include the file path and a useful message — no stack traces.
3. You can pass `-c FILE` to load any config file from anywhere; that
   file's parent directory becomes the project root.
