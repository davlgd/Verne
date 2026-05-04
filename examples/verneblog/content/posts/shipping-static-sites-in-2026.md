---
title: "Shipping static sites in 2026"
description: "Why we keep coming back to flat HTML, and what changed about the toolchain in the last three years."
date: 2026-04-22
author: "lea"
tags:
  - "essays"
  - "web"
  - "performance"
read_time: 8
cover_hue: 28
cover_label: "essay · 04.22"
---

There is a strange comfort in opening a folder full of HTML files and knowing
that, whatever else might break this week, those files will not. They were the
answer in 1996. They are, increasingly, the answer again.

I started writing this post in a hotel room in Lisbon, on a flaky connection,
while a Next.js build hung silently for the third time. By the time it failed,
I had already published a 12-page Brisk site to Netlify. The difference was
not subtle.

## The shape of a site

Most sites are not apps. They are documents with a navigation bar. Once you
internalise that, half of the modern web stack starts to look like an answer
to a question nobody asked.

A blog post is a file. A docs page is a file. A landing page is a file with
some interactive flair. The interactive flair is the hard part — but it is
also a tiny fraction of the page, and you almost never need a 4MB framework
to deliver it.

> The web platform got good while we were not looking. Native modules,
> container queries, view transitions — most of what we used to need a
> framework for, the browser now does directly.

## What actually changed

Three things, in rough order of importance:

- **Fast incremental builds.** Modern SSGs rebuild only what changed. Edits
  feel instant. This was the missing piece that made the SSG workflow tolerable
  for sites with more than 200 pages.
- **Native ES modules in the browser.** You can ship a script tag and expect
  it to work, no bundler required. For most sites, that is enough.
- **Edge functions for the rare bit that genuinely needs a server.** Comments,
  search, login. The 5% of dynamic stuff doesn't have to drag the other 95%
  down with it.

## A small build graph

Here is what an incremental build looks like for a small Brisk site, written
out as the dependency graph the runtime actually walks:

```ts
// build/graph.ts
export type Node =
  | { kind: 'content'; path: string; deps: string[] }
  | { kind: 'template'; path: string; deps: string[] }
  | { kind: 'asset'; path: string };

export function rebuild(changed: string[], graph: Map<string, Node>) {
  const dirty = new Set(changed);
  for (const id of changed) collectDependents(id, graph, dirty);
  for (const id of dirty) recompile(id, graph);
}
```

It is not glamorous. It is, however, the difference between a 12-second
rebuild and a 0.2-second one. Multiply by the number of times you save a file
in a writing session and the math gets persuasive.

## What we still get wrong

Search. Comments. Anything that is read at runtime instead of build time.
Most SSGs handle these by waving a hand toward a SaaS product, which works
until your post hits the front page of Hacker News and your indie comments
service quietly evaporates.

We are working on first-class primitives for these. Not a plugin marketplace.
Not a partner integration. The actual mechanism, in the box, with documentation.

## Where this leaves us

Static is not a step backwards. It is what we always meant when we said the
web should be fast, durable, and easy to write for. The toolchain finally
caught up with the format.

The folder of HTML files is still there. We just got better at making them.
