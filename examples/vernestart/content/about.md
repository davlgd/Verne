---
title: About
description: A short note about this site and the person behind it.
---

This is the placeholder About page that ships with `verne init`. It
renders through the same `_default/single.html` template as a post,
just without the date stamp and the prev/next navigation.

In a real site you would replace this body with whatever you want
readers to know — your story in three paragraphs, a photo, the way to
reach you. The frontmatter sets the title and the description; the
markdown handles the rest.

## A few notes about the demo

This site is `examples/vernestart/` in the Verne repository, built to
showcase the bundled default theme. It pairs the system sans-serif
stack for the chrome with a serif body for the prose, has full
light/dark support, and ships zero runtime JavaScript.

## Reach me

The default theme leaves the footer minimal — copyright and an RSS
link. Add socials by extending `verne.yaml`'s `params:` block and
referencing `site.params.socials` from the footer template.
