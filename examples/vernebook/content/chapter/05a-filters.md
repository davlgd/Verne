---
title: "Filters"
description: "Pipe-style transformations applied to expressions."
---


A filter is a pure function applied with `|`:

```jinja
{{ value | upper | truncate(20) }}
```

Filters never mutate. They take the piped value as their first argument, and
zero or more positional arguments after.

Verne ships with 22 built-in filters, grouped under two categories:

- [String filters](/chapter/05a1-string-filters/) — case, length, trim,
  truncate, slugify, urlencode, default, plainify, replace, split, join.
- [Date / number filters](/chapter/05a2-date-filters/) — format_date,
  format_number, printf, jsonify.

You can register your own filters at the V level (`engine.register_filter`),
but the bar should be high — most cases collapse into pre-computing a field
on `site` or `page`.
