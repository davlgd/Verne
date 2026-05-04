---
title: "Templates"
description: "Verne's mini-Tera template DSL — delimiters, control flow, filters, page and site objects."
---

A minimal Jinja2/Tera-flavoured templating language. Inspired by Zola, but
deliberately stripped down: **no logic in templates**.

If you need a calculation, a filter pipeline that transforms data, or any
control flow beyond "show this if that", do it in V (a shortcode or a
precomputed field on `site`/`page`) and have the template just display it.

## At a glance

```jinja
{{ page.title }}                    <!-- print a value -->
{{ page.title | upper }}            <!-- pipe through filters -->
{% if page.tags %}…{% endif %}      <!-- conditional -->
{% for post in site.posts %}        <!-- loop -->
  <li>{{ post.title }}</li>
{% endfor %}
{% include "partials/topbar.html" %}
{% shortcode callout type="warn" %}
This is **important**.
{% endshortcode %}
```

## Tags

Two delimiters, no others:

| Delimiter         | Purpose                                          |
| ----------------- | ------------------------------------------------ |
| `{{ expr }}`      | Print an expression (HTML-escaped by default).   |
| `{% statement %}` | Control flow, `include`, `shortcode`.            |

Whitespace control: prefix with `-` to strip whitespace before, suffix with
`-` to strip whitespace after. `{{- x -}}` strips both sides. `trim_blocks`
and `lstrip_blocks` are on by default — a statement that sits on its own
line leaves the surrounding lines clean.

Comments: `{# this is a comment #}`. Removed at lex time, never rendered.

## Expressions

```
identifier                page
property access           page.title          (also: page["title"])
indexed access            posts[0]
function/shortcode call   relurl("/")
filter pipe               value | filter | filter(arg)
literal: string           "hello"  'hello'
literal: integer          42  -3
literal: boolean          true  false
literal: nothing          none
comparison                a == b   a != b   a < b   a >= b
membership                tag in page.tags
boolean                   a and b   a or b   not a
test                      value is defined   value is none   value is empty
```

Anything outside this list is a **syntax error**. In particular:

- `{% set x = ... %}` — no user-defined variables.
- `{{ a + b }}` — no inline arithmetic. Use a precomputed field.
- `{{ posts | filter(field="x") | sort(...) }}` — no algorithmic filter
  pipelines. Compute in V, expose as `site.foo`.
- `{% macro ... %}` — use a shortcode.
- `{% extends "base.html" %}{% block ... %}` — use `include` and partials
  instead.

## Statements

```jinja
{% if cond %}…{% elif cond %}…{% else %}…{% endif %}
{% for item in collection %}…{% endfor %}
{% for key, value in mapping %}…{% endfor %}
{% with binding = expression %}…{% endwith %}
{% include "path/to/partial.html" %}
{% shortcode name arg1=val1 arg2=val2 %}body{% endshortcode %}
```

`for` exposes a `loop` object inside the body: `loop.index` (1-based),
`loop.index0` (0-based), `loop.first` (bool), `loop.last` (bool),
`loop.length` (total iterations).

`with` is sugar for binding a sub-expression to a name for one block. It is
**the only place** users can name a value — and the binding is read-only and
local to the block.

```jinja
{% with t = page.tags %}
  {% if t %}
    Tags: {{ t | join(", ") }}
  {% endif %}
{% endwith %}
```

## Filters

Filters apply a function to a value with `|`. They never mutate — they
return a new value.

| Filter                | Effect                                                       |
| --------------------- | ------------------------------------------------------------ |
| `escape`              | HTML-escape (default for `{{ }}`; explicit when needed).     |
| `safe`                | Mark string as safe HTML (skip escape).                      |
| `lower`               | Lowercase string.                                            |
| `upper`               | Uppercase string.                                            |
| `trim`                | Strip leading/trailing whitespace.                           |
| `truncate(n)`         | Cut to `n` chars, append `…` if cut.                         |
| `default(x)`          | If value is `none`/empty, return `x`.                        |
| `length`              | Length of string, list or map.                               |
| `slugify`             | Convert to URL-safe slug.                                    |
| `urlencode`           | Percent-encode for use in a URL component.                   |
| `relurl`              | Normalise to a site-root-relative path (`/foo`); leaves absolute http(s) URLs untouched. |
| `absurl`              | Prefix a path with the configured `baseURL`; leaves absolute http(s) URLs untouched.     |
| `markdownify`         | Render Markdown string to HTML.                              |
| `plainify`            | Strip HTML tags from a string.                               |
| `format_date(layout)` | Format a `Date` value (Go-style layout, e.g. `"Jan 2, 2006"`). |
| `format_number`       | Thousands-separated number.                                  |
| `printf(fmt, …)`      | Standard `printf` (single-arg form: `value | printf("%02d")`). |
| `join(sep)`           | Join a list of strings.                                      |
| `replace(old, new)`   | Replace all occurrences of `old` with `new`.                 |
| `split(sep)`          | Split a string on `sep`, returning a list.                   |
| `jsonify`             | Serialise value to JSON.                                     |

### Tests (used after `is`)

| Test       | True when                            |
| ---------- | ------------------------------------ |
| `defined`  | The variable exists in the context.  |
| `none`     | The value is `none`.                 |
| `empty`    | String "", empty list, or empty map. |
| `string`   | Value is a string.                   |
| `number`   | Value is an int or float.            |
| `list`     | Value is a list.                     |
| `map`      | Value is a map.                      |

### What's deliberately missing

- No `filter`, `sort`, `group_by`, `slice`, `first`, `last`, `reverse` —
  these are computed in V and exposed as already-shaped fields on `site`
  and `page`.
- No arithmetic filters (`add`, `sub`, `mul`, `div`) — pre-compute.
- No `where` for slice filtering — pre-compute.

## Context model

Every template has access to these top-level objects:

### `page`

The current page. Common fields:

```
page.title              string
page.display_title      string ("" for home, page.title otherwise)
page.description        string (raw frontmatter description)
page.meta_description   string (description with fallback rules applied)
page.date               Date
page.lastmod            Date
page.section            string
page.layout             string (frontmatter `layout:` override, "" if unset)
page.permalink          string
page.relpermalink       string
page.content            safe HTML (rendered Markdown body)
page.plain              string (Markdown stripped)
page.word_count         int
page.reading_time       int
page.tags               []string
page.params             map (custom frontmatter)
page.is_home            bool
page.is_section         bool
page.is_page            bool
page.chapter_no         string (hierarchical number "1.2.3" when listed
                                in `summary:`, else "")
page.file.basename      string (filename without extension)
page.file.path          string (path under content/)
page.prev_in_section    page or none
page.next_in_section    page or none
page.edit_url           string (built from site.edit_url; "" if unset)
page.toc                safe HTML (table of contents)
page.has_rss            bool (true for home and section pages)
page.rss_url            string (relative URL to the page's feed)
page.og_image           string (resolved Open Graph image URL)
page.og_type            string ("article" for posts, "website" otherwise)
page.jsonld             safe HTML (precomputed JSON-LD payload)
page.breadcrumb_path    string ("home", "posts.md", "posts/<slug>.md", …)
page.term               string (current term on /tags/<term>/ pages, else "")
page.pages              []page (children of a section / term page)
```

### `site`

The site as a whole. Common fields:

```
site.title                  string
site.base_url               string
site.language               string  (short form, e.g. "en")
site.language_code          string  (full locale, e.g. "en-us")
site.generator              string  ("Verne 0.1.0")
site.params                 map     (custom config params)
site.posts                  []page  (posts only, sorted desc by date)
site.pages                  []page  (all regular pages)
site.recent_posts           []page  (newest first, capped at
                                    `params.recent_posts_limit` — default 5)
site.has_more_posts         bool    (true when site.posts is longer than
                                    site.recent_posts)
site.popular_tags           []{name, count}  (sorted count desc, then name asc)
site.popular_tags_overflow  int     (count beyond the visible 23)
site.tags_by_name           []{name, count}
site.stats                  {total_posts, total_words, avg_words, avg_read,
                             total_read, since_year, uptime_years,
                             last_post_date}
site.projects               []{name, desc, tag, stars, status, year, url}
                                    (fetched from GitHub at build time)
site.projects_error         string  (build-time fetch error, "" on success)
site.heatmap                []{year, month, count, key, level}  (flat)
site.heatmap_years          []{year, cells: [{year, month, count, key,
                                              level, empty}; 12]}
site.footer_socials         []{label, url}
site.summary                []{title, url, is_header, chapter_no,
                              children: [...]}
                                    (the explicit table of contents from
                                    `summary:` — drives the sidebar AND
                                    the in-section prev/next chain;
                                    `chapter_no` is the auto-numbered
                                    "1.2" string, or "" for header rows
                                    and front-matter leaves)
```

### `assets`

Paths and SRI integrity hashes for the bundled CSS and JS, computed at the
start of `build`:

```
assets.css_url          string  (e.g. /css/bundle.<hash>.css)
assets.css_integrity    string  (sha256-…)
assets.js_url           string
assets.js_integrity     string
```

### `config`

A flattened view of `params:` from `verne.yaml`. Read-only.

### `now`

The current build time, exposed as a `Date` with `year`, `month`, `day`,
`unix` getters.

## A complete example

`templates/posts/single.html`:

```jinja
{% include "partials/head.html" %}

<article class="post">
  <h1>{{ page.title }}</h1>
  <p class="meta">
    {{ page.date | format_date("Jan 2, 2006") }} ·
    {{ page.reading_time }} min read
  </p>

  {% if page.tags %}
    <ul class="tags">
      {% for t in page.tags %}
        <li><a href="/tags/{{ t | slugify }}/">{{ t }}</a></li>
      {% endfor %}
    </ul>
  {% endif %}

  <div class="content">{{ page.content }}</div>

  {% with prev = page.prev_in_section %}
    {% if prev %}
      <a class="prev" href="{{ prev.relpermalink }}">← {{ prev.title }}</a>
    {% endif %}
  {% endwith %}
</article>

{% include "partials/footer.html" %}
```

## Errors

When a template fails, Verne reports the template name plus the
in-source location of the offending node:

```
render "_default/single.html": variable "page.taggs" is undefined (at 14:23)
```

Common error categories:

- `variable "..." is undefined` — typo in `page.foo` or `site.foo`.
- `unknown filter` — typo in `| frmt_date`.
- `unknown shortcode` — referenced shortcode is neither registered (V) nor
  found in `templates/shortcodes/`.
- `wrong argument count` — e.g. `{{ default() }}` invoked with no argument.
- parse-time rejection of `{% set %}`, `{% macro %}`, `{% extends %}`, or
  inline arithmetic.

A failed template is a build error: `verne build` exits with code 1.
