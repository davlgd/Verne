---
title: "Keeping static sites small"
date: 2026-04-02T00:00:00Z
description: "A budget for HTML, CSS, JS and images on a personal site, and what each line item buys you."
tags:
  - web
  - performance
---

A page on this site weighs around 14 KB compressed: 4 KB of HTML, 6 KB
of CSS, no JS on most pages, and whatever images the post happens to
need. That's a budget choice, not a happy accident.

## The line items

| Asset    | Budget        | Why                                                |
| -------- | ------------- | -------------------------------------------------- |
| HTML     | < 6 KB        | One round-trip. The page reads before the second packet. |
| CSS      | < 8 KB gzip   | Loads inline-fast on a cold visit.                  |
| JS       | 0 KB on prose | Reading doesn't need scripts.                       |
| Images   | per-post      | Inline `loading="lazy"` and intrinsic sizing.       |
| Fonts    | 0 by default  | The system stack is fine. Add a face if it earns it.|

## What you get for it

- The site loads on a 2G connection in under two seconds.
- It's resilient to flaky networks: no third-party request can break
  the layout.
- It works for screen readers, lynx, archive.org, and the next browser
  to come along.
- It is *legible* before any script has executed.

## What you give up

Mostly: things that look impressive in a tweet. Animated entry
transitions. Sticky parallax headers. The inline like button. The
"share to X" widget that adds 60 KB and one tracking domain.

If the choice is "an interaction that delights three readers, or three
seconds shaved off a load on slow internet," I pick the seconds. They
compound across thousands of visits.
