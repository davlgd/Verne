module yaml

fn must_get(m map[string]Value, k string) Value {
	return m[k] or { panic('missing key: ${k}') }
}

fn test_simple_scalars() {
	out := parse('a: 1\nb: hello\nc: "with: colon"\n') or { panic(err) }
	assert must_get(out, 'a') == Value(i64(1))
	assert must_get(out, 'b') == Value('hello')
	assert must_get(out, 'c') == Value('with: colon')
}

fn test_booleans() {
	out := parse('x: true\ny: NO\nz: On\n') or { panic(err) }
	assert must_get(out, 'x') == Value(true)
	assert must_get(out, 'y') == Value(false)
	assert must_get(out, 'z') == Value(true)
}

fn test_floats() {
	out := parse('a: 1.5\nb: -0.25\nc: 1e3\n') or { panic(err) }
	assert must_get(out, 'a') == Value(1.5)
	assert must_get(out, 'b') == Value(-0.25)
	assert must_get(out, 'c') == Value(1000.0)
}

fn test_block_list() {
	src := 'tags:\n  - foo\n  - bar\n  - "baz: 1"\n'
	out := parse(src) or { panic(err) }
	tags := must_get(out, 'tags').as_list() or { panic('not list') }
	assert tags.len == 3
	assert tags[0] == Value('foo')
	assert tags[1] == Value('bar')
	assert tags[2] == Value('baz: 1')
}

fn test_nested_map() {
	src := 'params:\n  handle: davlgd\n  author:\n    name: David\n    twitter: "@d"\n'
	out := parse(src) or { panic(err) }
	params := must_get(out, 'params').as_map() or { panic('not map') }
	author := must_get(params, 'author').as_map() or { panic('not map') }
	assert must_get(author, 'name') == Value('David')
	assert must_get(author, 'twitter') == Value('@d')
}

fn test_block_literal() {
	src := 'about: |\n  line one\n  line two\n'
	out := parse(src) or { panic(err) }
	assert must_get(out, 'about') == Value('line one\nline two\n')
}

fn test_block_folded() {
	src := 'about: >\n  line one\n  line two\n'
	out := parse(src) or { panic(err) }
	assert must_get(out, 'about') == Value('line one line two')
}

fn test_comments() {
	src := '# leading comment\na: 1 # inline\nb: "with # hash"\n'
	out := parse(src) or { panic(err) }
	assert must_get(out, 'a') == Value(i64(1))
	assert must_get(out, 'b') == Value('with # hash')
}

fn test_url_value_with_colon() {
	src := 'baseURL: https://example.com/\n'
	out := parse(src) or { panic(err) }
	assert must_get(out, 'baseURL') == Value('https://example.com/')
}

fn test_frontmatter_typical() {
	src := 'author: davlgd
pubDatetime: 2024-01-17T13:37:00Z
title: "asitop: monitor your Apple Silicon SoC"
description: How low is it?
tags:
  - Apple
  - macOS
ogImage: /images/cover.webp
'
	out := parse(src) or { panic(err) }
	assert must_get(out, 'author') == Value('davlgd')
	assert must_get(out, 'pubDatetime') == Value('2024-01-17T13:37:00Z')
	assert must_get(out, 'title') == Value('asitop: monitor your Apple Silicon SoC')
	assert must_get(out, 'description') == Value('How low is it?')
	assert must_get(out, 'ogImage') == Value('/images/cover.webp')
	tags := must_get(out, 'tags').as_list() or { panic('not list') }
	assert tags.len == 2
	assert tags[0] == Value('Apple')
}

fn test_empty_value() {
	out := parse('a:\nb: 1\n') or { panic(err) }
	assert must_get(out, 'a') == Value('')
	assert must_get(out, 'b') == Value(i64(1))
}

fn test_list_of_maps_inline_first_key() {
	src := 'people:\n  - name: alice\n    age: 30\n  - name: bob\n    age: 40\n'
	out := parse(src) or { panic(err) }
	people := must_get(out, 'people').as_list() or { panic('not list') }
	assert people.len == 2
	a := people[0].as_map() or { panic('not map') }
	assert must_get(a, 'name') == Value('alice')
	assert must_get(a, 'age') == Value(i64(30))
	b := people[1].as_map() or { panic('not map') }
	assert must_get(b, 'name') == Value('bob')
}

fn test_empty_input() {
	out := parse('') or { panic(err) }
	assert out.len == 0
}

fn test_only_comments() {
	out := parse('# only\n# comments\n') or { panic(err) }
	assert out.len == 0
}
