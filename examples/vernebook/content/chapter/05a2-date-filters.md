---
title: "Date filters"
description: "format_date, format_number, printf, jsonify."
---


The remaining four general-purpose filters: dates, numbers, format strings,
and JSON.

## Dates

`page.date` is a `Date` value. Use Go-style layouts (the same as Go's
`time.Format`):

```jinja
{{ page.date | format_date("Jan 2, 2006") }}    {# May 4, 2026          #}
{{ page.date | format_date("2006-01-02") }}     {# 2026-05-04           #}
{{ page.date | format_date("Mon, 02 Jan") }}    {# Mon, 04 May          #}
```

## Numbers

```jinja
{{ 1234567 | format_number }}                   {# 1,234,567            #}
```

## printf

```jinja
{{ 7 | printf("%03d") }}                        {# 007                  #}
```

## JSON

`jsonify` outputs compact JSON; useful for embedding data into the HTML for
client-side scripts.

```jinja
<script id="page-meta" type="application/json">{{ page.params | jsonify | safe }}</script>
```

Note the `| safe` at the end — JSON contains characters that would otherwise
be HTML-escaped, so you opt out explicitly when you know what you're doing.
