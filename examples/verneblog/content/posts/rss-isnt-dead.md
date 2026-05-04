---
title: "RSS isn't dead. Your generator is just lazy."
description: "A plea for first-class feeds, and a 40-line plugin that adds Atom 1.0 to any Brisk project."
date: 2026-01-22
author: "lea"
tags:
  - "web"
  - "guide"
read_time: 5
cover_hue: 18
cover_label: "note · 01.22"
---

The number of times I've heard "nobody uses RSS anymore" from a developer
who has never published a feed is approaching three digits. RSS is fine. RSS
readers have a small but loyal user base, and that user base reads.

The reason every static blog should ship a feed is the same reason every
blog should ship a sitemap: it's three lines of XML and it costs nothing.

```xml
<feed xmlns="http://www.w3.org/2005/Atom">
  <title>{site.title}</title>
  <id>{site.baseURL}</id>
  <updated>{posts[0].date}</updated>
  {for p in posts.slice(0, 20)}
    <entry>
      <title>{p.title}</title>
      <link href="{p.permalink}"/>
      <id>{p.permalink}</id>
      <updated>{p.date}</updated>
      <summary>{p.description}</summary>
    </entry>
  {endfor}
</feed>
```

That's the whole thing. Brisk ships this template by default; if your SSG
doesn't, here is the 40-line plugin you can drop in.
