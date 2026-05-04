---
title: "Writing Markdown"
description: "What the CommonMark renderer handles, and what it doesn't."
---


Verne's CommonMark renderer is hand-rolled — no external Markdown library —
and aims at the parts of the spec real people use day-to-day. This chapter
exists mostly to give the renderer a workout you can read.

## Inline formatting

Mix **bold**, *italic*, ~~strikethrough~~, `inline code`, and
[external links](https://github.com/davlgd/Verne) in the usual way.

## Lists, ordered and not

1. Read the *Welcome* chapter.
2. Follow the *Installation* path for your OS.
3. Skim *Templates* and *Filters* to get a feel for the engine.
4. Build something.

- Verne ships with no JS framework.
- The asset pipeline fingerprints `css/style.css` and `js/app.js`.
- Sub-resource integrity (SRI) hashes are emitted automatically.

## Blockquote

> When the only tool you have is a single-binary SSG, every project starts
> looking like a static site.

## Aside

> **Note** Verne's renderer is a moving target. If a Markdown construct does
> not render the way you expect, it is either a deliberate omission or a real
> bug worth filing — the renderer aims at the parts of the spec real people
> use day-to-day, not the long tail.

## Code blocks

```v filename="hello.v"
fn welcome(name string) string {
    return "Hello, ${name}!"
}
```

Anchors are auto-generated for headings. Right-click any heading and copy its
link to verify.

---

That's the bulk of what you'll lean on day-to-day.
