module config

import os

fn test_load_labs_config() {
	root := os.dir(os.dir(os.dir(@FILE))) + '/..'
	cfg := load(root) or {
		eprintln('skipping: ${err}')
		return
	}
	assert cfg.base_url == 'https://labs.davlgd.com/'
	assert cfg.theme == 'terminal-garden'
	assert cfg.title == 'davlgd tech blog'
	assert cfg.locale == 'en-us'
	assert 'pubDatetime' in cfg.frontmatter_map['date']
	assert cfg.permalinks['posts'] == '/posts/:contentbasename/'
	assert cfg.taxonomies['tag'] == 'tags'
}

fn test_summary_parsing() {
	dir := os.join_path(os.temp_dir(), 'verne-config-summary-test')
	os.mkdir_all(dir)!
	defer { os.rmdir_all(dir) or {} }
	path := os.join_path(dir, 'verne.yaml')
	os.write_file(path, '
title: "Book"
theme: "any"
summary:
  - title: "First"
    url: "/c/first/"
  - title: "Second"
    url: "/c/second/"
  - title: "No URL — should be skipped"
')!
	cfg := load_file(path)!
	assert cfg.summary.len == 2
	assert cfg.summary[0].title == 'First'
	assert cfg.summary[0].url == '/c/first/'
	assert cfg.summary[1].title == 'Second'
	assert cfg.summary[1].url == '/c/second/'
}

fn test_summary_absent_yields_empty_list() {
	dir := os.join_path(os.temp_dir(), 'verne-config-no-summary-test')
	os.mkdir_all(dir)!
	defer { os.rmdir_all(dir) or {} }
	path := os.join_path(dir, 'verne.yaml')
	os.write_file(path, 'title: "Plain"\ntheme: "any"\n')!
	cfg := load_file(path)!
	assert cfg.summary.len == 0
}

fn test_edit_url_parsing() {
	dir := os.join_path(os.temp_dir(), 'verne-config-edit-url-test')
	os.mkdir_all(dir)!
	defer { os.rmdir_all(dir) or {} }
	path := os.join_path(dir, 'verne.yaml')
	os.write_file(path, '
title: "Book"
theme: "any"
edit_url: "https://github.com/me/repo/edit/main/content/{path}"
')!
	cfg := load_file(path)!
	assert cfg.edit_url == 'https://github.com/me/repo/edit/main/content/{path}'
}

fn test_summary_with_headers_and_nested_children() {
	dir := os.join_path(os.temp_dir(), 'verne-config-nested-summary-test')
	os.mkdir_all(dir)!
	defer { os.rmdir_all(dir) or {} }
	path := os.join_path(dir, 'verne.yaml')
	os.write_file(path, '
title: "Book"
theme: "any"
summary:
  - title: "Welcome"
    url: "/welcome/"
  - header: "Part I"
  - title: "Installation"
    url: "/install/"
    children:
      - title: "macOS"
        url: "/install/macos/"
      - title: "Linux"
        url: "/install/linux/"
  - title: "Templates"
    url: "/templates/"
    children:
      - title: "Filters"
        url: "/templates/filters/"
        children:
          - title: "String"
            url: "/templates/filters/string/"
')!
	cfg := load_file(path)!
	assert cfg.summary.len == 4
	// Welcome — leaf
	assert cfg.summary[0].title == 'Welcome'
	assert cfg.summary[0].url == '/welcome/'
	assert !cfg.summary[0].is_header
	assert cfg.summary[0].children.len == 0
	// Part I — header (no URL, no children)
	assert cfg.summary[1].is_header
	assert cfg.summary[1].title == 'Part I'
	assert cfg.summary[1].url == ''
	// Installation with two children
	assert cfg.summary[2].title == 'Installation'
	assert cfg.summary[2].children.len == 2
	assert cfg.summary[2].children[0].title == 'macOS'
	assert cfg.summary[2].children[1].url == '/install/linux/'
	// Templates → Filters → String (3 levels)
	assert cfg.summary[3].title == 'Templates'
	assert cfg.summary[3].children.len == 1
	assert cfg.summary[3].children[0].title == 'Filters'
	// chapter_no auto-numbering: top-level leaves before the first header
	// are treated as front-matter (Welcome) and get no number; numbering
	// starts at the first chapter inside the first Part. Children are
	// scoped to parent.
	assert cfg.summary[0].chapter_no == '' // Welcome (front-matter)
	assert cfg.summary[1].chapter_no == '' // header
	assert cfg.summary[2].chapter_no == '1' // Installation
	assert cfg.summary[2].children[0].chapter_no == '1.1' // macOS
	assert cfg.summary[2].children[1].chapter_no == '1.2' // Linux
	assert cfg.summary[3].chapter_no == '2' // Templates
	assert cfg.summary[3].children[0].chapter_no == '2.1' // Filters
	assert cfg.summary[3].children[0].children[0].chapter_no == '2.1.1' // String
	assert cfg.summary[3].children[0].children.len == 1
	assert cfg.summary[3].children[0].children[0].title == 'String'
	assert cfg.summary[3].children[0].children[0].url == '/templates/filters/string/'
}

fn write_config(name string, body string) !string {
	dir := os.join_path(os.temp_dir(), 'verne-config-${name}')
	os.mkdir_all(dir)!
	path := os.join_path(dir, 'verne.yaml')
	os.write_file(path, body)!
	return path
}

fn test_summary_rejects_javascript_scheme() {
	path := write_config('xss-summary', '
title: "Book"
theme: "any"
summary:
  - title: "Pwn"
    url: "javascript:alert(1)"
')!
	defer { os.rmdir_all(os.dir(path)) or {} }
	if _ := load_file(path) {
		assert false, 'expected javascript: URL to be rejected'
	} else {
		assert err.msg().contains('unsupported scheme')
	}
}

fn test_edit_url_requires_path_placeholder() {
	path := write_config('edit-url-no-placeholder', '
title: "Book"
theme: "any"
edit_url: "https://github.com/me/repo/edit/main/content/"
')!
	defer { os.rmdir_all(os.dir(path)) or {} }
	if _ := load_file(path) {
		assert false, 'expected missing {path} placeholder to be rejected'
	} else {
		assert err.msg().contains('{path}')
	}
}

fn test_edit_url_rejects_javascript_scheme() {
	path := write_config('edit-url-xss', '
title: "Book"
theme: "any"
edit_url: "javascript:alert({path})"
')!
	defer { os.rmdir_all(os.dir(path)) or {} }
	if _ := load_file(path) {
		assert false, 'expected javascript: edit_url to be rejected'
	} else {
		assert err.msg().contains('unsupported scheme')
	}
}

fn test_summary_must_be_a_list() {
	path := write_config('summary-not-a-list', '
title: "Book"
theme: "any"
summary: "this should be a list"
')!
	defer { os.rmdir_all(os.dir(path)) or {} }
	if _ := load_file(path) {
		assert false, 'expected scalar summary to be rejected'
	} else {
		assert err.msg().contains('must be a list')
	}
}

fn test_summary_rejects_excessive_nesting() {
	mut body := 'title: "Book"\ntheme: "any"\nsummary:\n'
	mut indent := '  '
	// Build (max_summary_depth + 2) nested levels: deeper than the bound.
	for i := 0; i < max_summary_depth + 2; i++ {
		body += '${indent}- title: "L${i}"\n'
		body += '${indent}  url: "/l${i}/"\n'
		body += '${indent}  children:\n'
		indent += '    '
	}
	path := write_config('summary-too-deep', body)!
	defer { os.rmdir_all(os.dir(path)) or {} }
	if _ := load_file(path) {
		assert false, 'expected deep nesting to be rejected'
	} else {
		assert err.msg().contains('nesting too deep')
	}
}
