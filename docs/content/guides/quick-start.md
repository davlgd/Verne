---
title: "Quick start"
description: "Scaffold a docs site, add a page, ship it. Five minutes end-to-end."
---

This walks you through the smallest useful docs site: scaffold, add one
page, build, serve. Five minutes.

## 1. Scaffold

```bash
verne init my-docs --yes
cd my-docs
```

`--yes` skips the interactive prompts and uses sensible defaults. Pass
`--title`, `--base-url`, `--locale`, `--tagline` if you want to set them
up-front; everything else is editable in `verne.yaml` afterwards.

> [!TIP]
> Run `verne init --help` to see every flag. The CLI is the source of
> truth — what's documented here may have grown by the time you read it.

## 2. Switch to this theme

The default `verne init` ships an editorial / blog theme. To use this one:

```bash
mkdir -p themes
cp -R /path/to/Verne/docs/themes/vernedocs themes/
```

Then point `verne.yaml`'s `theme:` key at it:

```yaml
theme: "vernedocs"
```

## 3. Add a page

```bash
mkdir -p content/guides
cat > content/guides/hello.md <<'EOF'
---
title: "Hello"
description: "A first page in the docs."
---

This is the page body. Markdown works here — headings, lists, code,
blockquotes, tables.

## A subhead

Paragraph under a subhead. The right-rail "On this page" lists every
`##` and `###` heading automatically.
EOF
```

## 4. Wire it into the sidebar

Open `verne.yaml` and add an entry under `summary:`:

```yaml
summary:
  - header: "Guides"
  - title: "Hello"
    url: "/guides/hello/"
```

## 5. Build and preview

```bash
verne server --open
```

`verne server` rebuilds, binds `127.0.0.1:1313`, and `--open` launches
your default browser at the index page. It then keeps watching
`content/`, `themes/`, `static/` and `verne.yaml`: save a file and the
site rebuilds and the open page reloads itself. Pass `--no-watch` to
serve the build as-is instead.

That's it. Add more `.md` files, drop entries into `summary:`, and the
sidebar stays in sync. When you're ready to ship, run `verne build` and
deploy `public/` to any static host — see [Deploying](../deploying/).

> [!NOTE]
> The `summary:` block in `verne.yaml` is the **only** thing that
> drives the sidebar — there is no auto-discovery. New pages become visible
> only after you add an entry pointing at them.
