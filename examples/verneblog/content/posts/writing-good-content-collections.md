---
title: "Writing good content collections"
description: "How we model posts, notes, and changelogs as separate content kinds without duplicating the templating layer."
date: 2026-02-10
author: "theo"
tags:
  - "guide"
  - "internals"
read_time: 9
cover_hue: 60
cover_label: "guide · 02.10"
---

The first version of Brisk had one content kind: the blog post. It had a
title, a date, and a body. Everything else was a hack on top.

By the second project we had four kinds — posts, notes, changelog entries,
and a "case studies" thing — and the templates had collected `if` branches
the way a coat collects pet hair.

The fix was to make the content kind explicit, and to give each kind its
own template inheritance chain.

## The shape

Each content kind has:

- A directory under `content/<kind>/`.
- A schema in `content/<kind>/.schema.yaml`.
- A list template at `templates/<kind>/list.html`.
- A single template at `templates/<kind>/single.html`.

The templates can extend a shared base, but they don't have to. The cost of
sharing structure is that you tie the layouts together; sometimes that's
right, sometimes it's a mistake.

## When to split

The rule of thumb: **when two kinds share more than 80% of their template,
keep them together. Below that, split.** It's a fuzzy line, but the right
answer is almost always obvious in retrospect.
