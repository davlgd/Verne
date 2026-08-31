module frontmatter

import yaml

fn must_get(m map[string]yaml.Value, k string) yaml.Value {
	return m[k] or { panic('missing key: ${k}') }
}

fn test_basic() {
	src := '---
title: Hello
tags:
  - foo
  - bar
---
Body content.
'
	d := parse(src) or { panic(err) }
	assert must_get(d.meta, 'title') == yaml.Value('Hello')
	tags := must_get(d.meta, 'tags').as_list() or { panic('not list') }
	assert tags.len == 2
	assert d.body == 'Body content.\n'
}

fn test_no_frontmatter() {
	src := 'Just body.\n'
	d := parse(src) or { panic(err) }
	assert d.meta.len == 0
	assert d.body == 'Just body.\n'
}

fn test_missing_closing() {
	src := '---\ntitle: Hello\nBody never closes.\n'
	parse(src) or {
		assert err.msg().contains('missing closing')
		return
	}
	assert false, 'expected error'
}

fn test_crlf() {
	src := '---\r\ntitle: Hello\r\n---\r\nBody.\r\n'
	d := parse(src) or { panic(err) }
	assert must_get(d.meta, 'title') == yaml.Value('Hello')
	assert d.body == 'Body.\r\n'
}

fn test_bom() {
	src := '﻿---\ntitle: Hello\n---\nBody.\n'
	d := parse(src) or { panic(err) }
	assert must_get(d.meta, 'title') == yaml.Value('Hello')
	assert d.body == 'Body.\n'
}

fn test_labs_post_shape() {
	src := '---
author: davlgd
pubDatetime: 2024-01-17T13:37:00Z
title: "asitop: monitor your Apple Silicon SoC"
description: How low is it?
tags:
  - Apple
  - macOS
ogImage: /images/cover.webp
---

For more than 10 years...
'
	d := parse(src) or { panic(err) }
	assert must_get(d.meta, 'author') == yaml.Value('davlgd')
	assert must_get(d.meta, 'title') == yaml.Value('asitop: monitor your Apple Silicon SoC')
	assert d.body.starts_with('\nFor more than 10 years')
}
