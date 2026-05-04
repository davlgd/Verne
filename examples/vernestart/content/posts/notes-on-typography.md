---
title: "Notes on typography"
date: 2026-02-08T00:00:00Z
description: "Pairing a system sans-serif for the UI with a serif for the prose, and the reasoning behind the measure."
tags:
  - design
  - typography
---

The default theme uses two type stacks: a sans-serif for the chrome
(navigation, captions, metadata) and a serif for the article body. Both
are entirely system stacks — no web font request, no FOUT, no licensing
question to answer.

## Why the split

UI text is read in glances. Your eye scans, snaps to the next item, moves
on. The sans-serif is built for that — wide x-height, clean horizontals,
high contrast at small sizes. Article text is read in long chunks, and
that's where serifs earn their keep: the bracketed terminals give your
eye something to ride along, line after line.

## The measure

Body copy sits at `clamp(2.375rem, 4.5vw + 1rem, 3.5rem)` for headings
and `--measure: 38rem` for paragraphs — about 70 characters wide. Wider
than that and your eye loses the line return; narrower and rhythm
suffers.

## Living with system fonts

You give up the *look* of a custom font but gain everything else: weight
matching, hinting that respects the reader's OS, instant render, and
accessibility hooks (high contrast, scaling) the platform already
offers.

If you want a brand voice, change one thing — the display font on the
hero — and let the body run on the system stack.
