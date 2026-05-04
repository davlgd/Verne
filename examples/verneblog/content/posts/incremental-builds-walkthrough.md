---
title: "How incremental builds actually work"
description: "A walkthrough of the dependency graph that powers Brisk's sub-second rebuilds, with diagrams and one regret."
date: 2026-04-08
author: "lea"
tags:
  - "internals"
  - "performance"
  - "guide"
read_time: 14
cover_hue: 200
cover_label: "internals · 04.08"
---

The basic question every incremental build system answers is: **given a set
of changed files, what is the minimum work to bring the output back to
correctness?**

Brisk's answer is a dependency graph keyed on content paths and template
paths, walked dirty-first. This post is a tour of the implementation, with
the parts I'd do differently if I started over.

## The graph, briefly

Every node knows what it reads from. Every recompilation marks its outputs
dirty. The walker keeps going until the dirty set stops growing.

```ts
type GraphNode =
  | { kind: 'content'; path: string; reads: Set<string> }
  | { kind: 'template'; path: string; reads: Set<string> }
  | { kind: 'asset'; path: string; reads: Set<string> };
```

The `reads` set is built during compilation. When a content file references
a template, that's an edge. When a template includes a partial, that's an
edge. Asset bundles read from a manifest of fingerprinted files.

## What I'd change

If I started over, I'd merge the asset graph into the content graph instead
of keeping them separate. The two-graph design felt clean for about six
months, until we needed cache-busting URLs in templates and had to introduce
a hand-written join layer.

The lesson: separate graphs for separate things only if the things genuinely
never reference each other. They almost always do.
