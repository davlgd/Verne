---
title: "Frontmatter is an API. Treat it like one."
description: "Stop scattering metadata fields across templates. A short case for typed frontmatter and a schema-first workflow."
date: 2026-03-19
author: "theo"
tags:
  - "essays"
  - "guide"
read_time: 6
cover_hue: 340
cover_label: "essay · 03.19"
---

Every static site generator gives you a dictionary of arbitrary keys at the
top of every Markdown file. After three projects, you have eighteen subtle
variants of `author`, `authors`, `by`, `byline`, and `posted_by` floating
around the same content tree.

This is the same mistake we made with HTTP APIs ten years ago, and the
solution is the same: write the schema down. Validate against it. Fail the
build when something doesn't match.

## What the schema buys you

Three things you can't get any other way:

- **Editor tooling.** A schema makes typed autocomplete possible in any
  Markdown editor that speaks YAML.
- **Refactor safety.** When you rename `byline` to `author`, you find every
  file that needs updating. No silent template fallthrough.
- **Documentation.** New contributors read the schema and know exactly which
  fields are required and which are optional.

The cost is a fifty-line `frontmatter.schema.yaml` that pays for itself the
first time someone forgets a required field.
