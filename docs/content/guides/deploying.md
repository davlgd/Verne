---
title: "Deploying"
description: "Push the public/ directory to a static host — and the one config detail nobody warns you about."
---

Verne writes a self-contained `public/` directory. Any static host can
serve it: there is no server-side runtime, no API routes, no database.
What follows is one fully-worked path (Clever Cloud) plus the single
detail you must get right whatever the host.

## The one config detail

Set `baseURL:` in `verne.yaml` to the **canonical, public URL** of the
site, including the scheme and trailing slash:

```yaml
baseURL: "https://docs.example.com/"
```

`baseURL` is concatenated into the sitemap, RSS feeds, JSON-LD
payloads, canonical `<link>` tags, and Open Graph URLs. A wrong value
here means search engines index the wrong host. Verne validates the
format at build time and refuses non-`http(s)://` schemes.

## Clever Cloud (static application)

Create a [static](https://www.clever.cloud/developers/doc/applications/static/)
application and set two environment variables in the dashboard
(*Information* → *Environment variables*):

| Variable           | Value         | Role                                        |
| ------------------ | ------------- | ------------------------------------------- |
| `CC_WEBROOT`       | `/public`     | Served and kept in the build cache          |
| `CC_BUILD_COMMAND` | `verne build` | Runs on new deploys, restarts use the cache |

Drop a `mise.toml` at the root of your site declaring the two tools
the build needs:

```toml
[tools]
"github:alecthomas/chroma" = "latest"
"github:davlgd/verne"      = "latest"
```

Clever Cloud picks `mise.toml` up automatically, fetches `chroma` and
`verne` for the host architecture, then executes `CC_BUILD_COMMAND`. Pin specific versions by replacing `"latest"` with
any upstream tag (e.g. `"v2.14.0"`, `"0.1.0"`).

A working reference lives in the labs repository:

> [https://github.com/davlgd/labs/blob/main/mise.toml](https://github.com/davlgd/labs/blob/main/mise.toml)

That's the whole deploy story: push to the application's git remote and
the site rebuilds.

## Sanity checks

After deploying, hit:

- `/sitemap.xml` — should list every page
- `/robots.txt` — should reference the sitemap
- A nested page like `/guides/quick-start/` — should load with no 404s
- The on-this-page TOC links — should jump to anchors, not 404 fragments

If anything's off, run `verne build` locally and `diff` your `public/`
against what the host serves.
