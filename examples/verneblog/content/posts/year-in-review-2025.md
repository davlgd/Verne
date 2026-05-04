---
title: "Year in review · 2025"
description: "Numbers, regrets, and what we're shipping next. The traditional end-of-year post."
date: 2025-12-30
author: "lea"
tags:
  - "essays"
read_time: 7
cover_hue: 250
cover_label: "essay · 12.30"
---

Every year we write a post like this one. The structure is fixed: numbers,
regrets, and what's next. The numbers are the easy part. Regrets and next
require more work.

## Numbers

In rough order of how often they came up in retros:

- Brisk shipped twelve releases. Eight of them were patch-level; two were
  minor; two were minor with breaking changes that we backported a deprecation
  warning for in the previous patch. We did not break anyone unannounced.
- Median rebuild time fell from 180ms to 12ms over the year. Most of the
  improvement came from the dependency-graph rewrite in 0.14.
- We added one new content kind (changelog) and removed one (newsletter,
  which never had more than three users).

## Regrets

The two big ones: we shipped the dependency-graph rewrite three weeks late,
and we underestimated how much work the changelog kind would be in templates.
Both come from the same root cause — we tried to land big changes without
breaking the milestone planning loop, and the milestone planning loop turned
out to be the load-bearing piece of the project.

## What's next

In rough order of priority:

- A first-class search primitive (no SaaS dependency).
- A real plugin API, with examples.
- A multi-language story that doesn't require duplicating content trees.

That's the year. See you in 2026.
