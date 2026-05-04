---
title: "The case against hydration"
description: "We spent a decade re-running templates in the browser. Most pages didn't need any of it."
date: 2026-02-27
author: "lea"
tags:
  - "essays"
  - "web"
read_time: 11
cover_hue: 140
cover_label: "essay · 02.27"
---

Hydration was a clever solution to a self-inflicted problem. We rendered
HTML on the server. Then, to make it interactive, we re-rendered the same
HTML on the client and "attached" event handlers. The result: download the
page twice, parse it twice, execute the framework twice.

Looking at it from 2026, the strange thing isn't that we did this — frontend
problems are hard, and hydration was a real answer to a real problem. The
strange thing is that we did it for *every page*, even the ones that had
no interactive flair to speak of.

## The fix nobody wanted to admit

You can ship a 12-line `<script>` that adds the one button click handler the
page needs. You don't have to "hydrate" anything. The HTML is already there.
The browser already parsed it. The button already exists.

The frameworks that figured this out first — Astro, Eleventy with islands —
won the past five years not because their primitives were better, but
because they let you opt *into* JavaScript instead of opting out.
