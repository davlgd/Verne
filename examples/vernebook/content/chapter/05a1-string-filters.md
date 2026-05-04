---
title: "String filters"
description: "lower, upper, trim, truncate, slugify, urlencode, default, plainify, replace, split, join."
---


The eleven filters that operate on strings.

## Case and trimming

```jinja
{{ "Hello, World" | lower }}                    {# hello, world           #}
{{ "Hello, World" | upper }}                    {# HELLO, WORLD           #}
{{ "  spaced  "   | trim  }}                    {# "spaced"               #}
{{ "Hello, World" | length }}                   {# 12                     #}
{{ "Hello, World" | truncate(5) }}              {# Hello…                 #}
```

## URLs and slugs

```jinja
{{ "Hello, World!" | slugify }}                 {# hello-world            #}
{{ "café & croissant" | urlencode }}            {# caf%C3%A9%20%26%20...  #}
```

## Defaults and HTML stripping

```jinja
{{ page.subtitle | default("(no subtitle)") }}
{{ "<p>Hi <b>there</b></p>" | plainify }}       {# Hi there               #}
```

## Splitting, joining, replacing

```jinja
{{ "a,b,c" | split(",") | join(" / ") }}        {# a / b / c              #}
{{ "verne is great" | replace("great","fast") }} {# verne is fast         #}
```

That's it for strings — keep templates dumb, do the rest in V.
