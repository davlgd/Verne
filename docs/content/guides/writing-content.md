---
title: "Writing content"
description: "Frontmatter, body Markdown, code fences, callouts."
---

A Verne page is a Markdown file with a YAML frontmatter block at the top.
The frontmatter sets metadata; everything below the closing `---` is the
page body, rendered with a CommonMark parser plus a small set of
extensions.

## Frontmatter

```yaml
---
title: "How sessions work"
description: "Lifecycle, storage, and invalidation rules."
date: 2026-04-12
tags:
  - sessions
  - security
---
```

Recognised top-level keys:

- **`title`** — *string, required.* Drives `<title>`, `<h1>`, sidebar match.
- **`description`** — *string.* Used in `<meta name="description">` and
  Open Graph.
- **`date`** — *date.* Drives sort order in date-based sections. Custom
  alias keys can be declared via the top-level `frontmatter:` map in
  `verne.yaml` (e.g. mapping `pubDatetime` to `date` for migrating sites).
- **`tags`** — *string array.* Generates `/tags/<slug>/` index pages and
  per-tag RSS feeds when `taxonomies:` includes a `tags` plural in
  `verne.yaml` (off by default).
- **`lastmod`** — *date.* Optional last-modified timestamp.
- **`llms`** — *bool or `"optional"`, default `true`.* Controls how the
  page appears in the [llmstxt.org](https://llmstxt.org/) outputs.
  - `false` skips the page entirely (no `.html.md` twin, absent from
    both `llms.txt` and `llms-full.txt`).
  - `"optional"` files the page under the spec-reserved `## Optional`
    H2 in `llms.txt` (URLs an LLM may skip for a shorter context) and
    moves it to the tail of `llms-full.txt`.
  - `true` (or omitted) leaves the page in its natural section.

Anything else lands in `page.params.*` and is available to templates
unchanged. Use this for theme-specific extras (hero blocks, custom
metadata, whatever the layout needs).

## Body Markdown

Verne ships its own CommonMark renderer covering the common 90 %:

- **emphasis** and *italics*
- `inline code` and fenced code blocks (` ``` `)
- block quotes (with the GitHub-alert callout extension below)
- numbered and bulleted lists, including nested
- inline links (`[text](url)`) and autolinks (`<http://…>`)
- horizontal rules (`---` / `***` / `___`)
- pipe tables (GFM syntax: header, separator, body)
- raw HTML pass-through

Not implemented: setext headings (`===` / `---` underlines) and
reference-style links (`[text][ref]` + `[ref]: url`).

## Code fences

Triple-backtick fences with a language tag get server-side syntax
highlighting (when `chroma` is installed):

````markdown
```python
def greet(name):
    return f"Hello, {name}"
```
````

Renders to coloured tokens. The language tag is also written to a
`data-lang` attribute on the wrapping `<div class="code-wrap">` element,
which the theme's CSS uses to display a subtle label in the corner.
Add a filename with `lang filename="app.js"` (or `title=` / `name=`) to
get a header strip with the file path.

## Callouts (GitHub-style alerts)

A blockquote whose first line is one of `[!NOTE]`, `[!TIP]`,
`[!IMPORTANT]`, `[!WARNING]`, or `[!CAUTION]` becomes a typed callout.
Source:

```markdown
> [!NOTE]
> Useful information that users should know, even when skimming content.

> [!WARNING] Plan your migration window
> Indexes are rebuilt; expect a few seconds of read latency.
```

Renders as:

> [!NOTE]
> Useful information that users should know, even when skimming content.

> [!WARNING] Plan your migration window
> Indexes are rebuilt; expect a few seconds of read latency.

The full set of recognised markers — try each one to see how the theme
styles it:

> [!TIP]
> Optional advice that helps the reader get more out of the feature.

> [!IMPORTANT]
> Information the reader needs to know before going further.

> [!CAUTION]
> Negative consequences if the advice in the body is not followed.

Notes:

- `[!WARNING]` and `[!CAUTION]` carry `role="alert"`; the others carry
  `role="note"` for assistive tech.
- The renderer always emits a `<p class="callout-badge">` with the kind
  name (`Note`, `Tip`, …) and, when an inline title is given, a separate
  `<p class="callout-title">`. When the title is omitted, only the badge
  is emitted and the blockquote gains a `data-callout-untitled`
  attribute so themes can inline the badge next to the body.
- The marker is only recognised on the **first** line of the blockquote.
  A `[!NOTE]` further down renders as plain text.
- Style each kind from CSS via the `[data-callout="..."]` attribute.

## Headings and the on-this-page TOC

Every `##` heading in the body becomes an entry in the right-rail
"On this page" list (`###` and deeper levels are skipped to keep the
TOC flat). Slugs are generated automatically from the heading text.
Headings render with a small `#` anchor link on the right so readers
can grab a deep link without having to inspect the page source.

## Tables of contents inside a page

Use a regular Markdown bulleted list with manual links — this list is also
nice as a "What's in this guide?" lead-in:

```markdown
- [Frontmatter](#frontmatter)
- [Body Markdown](#body-markdown)
- [Code fences](#code-fences)
```

The auto-generated right-rail TOC is independent of any in-body list you
write, so both can coexist.
