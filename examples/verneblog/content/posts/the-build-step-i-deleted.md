---
title: "The build step I deleted"
description: "I removed our minifier. Bundle size went up 4%. Build time fell by 80%. Here is what I learned."
date: 2026-01-04
author: "theo"
tags:
  - "essays"
  - "performance"
read_time: 4
cover_hue: 280
cover_label: "essay · 01.04"
---

Last month I deleted the minifier from our build pipeline. Total CSS+JS
output grew by 4%. Total build time fell by 80%.

I had been adding optimizations one by one for two years. I had never gone
back and asked which of them still earned their keep. The minifier, it
turned out, was the most expensive thing in the pipeline by an order of
magnitude, and it was saving us 4% on a payload that was already smaller
than a single retina hero image.

The lesson isn't "don't minify." The lesson is **measure your build steps
as a cost, not just as a benefit.** Every step has a runtime budget. If a
step exceeds its budget more than its output is worth, kill the step.
