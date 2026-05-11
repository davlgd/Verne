module render

import content
import time

struct PageMdCase {
	page     content.Page
	expected string
}

struct StringCase {
	input    string
	expected string
}

fn test_page_md_includes_title_description_and_body() {
	p := &content.Page{
		title:       'Quick start'
		description: 'Your first Verne site in 60 seconds.'
		body_md:     'Install the binary.\n\nDrop a Markdown file in `content/`.\n'
	}
	got := page_md(p)
	expected := '# Quick start\n\n_Your first Verne site in 60 seconds._\n\nInstall the binary.\n\nDrop a Markdown file in `content/`.\n'
	assert got == expected
}

fn test_page_md_omits_missing_fields() {
	cases := [
		PageMdCase{
			page:     content.Page{
				title:   'Body only'
				body_md: 'hello'
			}
			expected: '# Body only\n\nhello\n'
		},
		PageMdCase{
			page:     content.Page{
				title: 'Title only'
			}
			expected: '# Title only\n'
		},
		PageMdCase{
			page:     content.Page{
				description: 'desc only'
				body_md:     'hi'
			}
			expected: '_desc only_\n\nhi\n'
		},
		PageMdCase{
			page:     content.Page{}
			expected: ''
		},
	]
	for c in cases {
		p := &content.Page{
			...c.page
		}
		assert page_md(p) == c.expected
	}
}

fn test_build_llms_full_separates_pages_with_hr() {
	pages := [
		&content.Page{
			title:   'A'
			body_md: 'first'
		},
		&content.Page{
			title:   'B'
			body_md: 'second'
		},
	]
	got := build_llms_full(pages)
	expected := '# A\n\nfirst\n\n---\n\n# B\n\nsecond\n'
	assert got == expected
}

fn test_build_llms_full_skips_empty_pages() {
	pages := [
		&content.Page{
			title:   'A'
			body_md: 'first'
		},
		&content.Page{},
		&content.Page{
			title:   'C'
			body_md: 'third'
		},
	]
	got := build_llms_full(pages)
	expected := '# A\n\nfirst\n\n---\n\n# C\n\nthird\n'
	assert got == expected
}

fn test_llms_included_pages_drops_excluded() {
	in_pages := [
		&content.Page{
			title: 'kept'
		},
		&content.Page{
			title:         'gone'
			llms_excluded: true
		},
		&content.Page{
			title: 'kept too'
		},
	]
	out := llms_included_pages(in_pages)
	assert out.len == 2
	assert out[0].title == 'kept'
	assert out[1].title == 'kept too'
}

fn test_humanise_section_key_titlecases_and_separates() {
	cases := [
		StringCase{
			input:    'guides'
			expected: 'Guides'
		},
		StringCase{
			input:    'release-notes'
			expected: 'Release Notes'
		},
		StringCase{
			input:    'guides/sub'
			expected: 'Guides Sub'
		},
		StringCase{
			input:    'a_b_c'
			expected: 'A B C'
		},
	]
	for c in cases {
		assert humanise_section_key(c.input) == c.expected
	}
}

fn test_llms_section_title_prefers_index_page_title() {
	bucket := [
		&content.Page{
			title:      'The Guides'
			is_section: true
		},
		&content.Page{
			title: 'A page'
		},
	]
	assert llms_section_title('guides', bucket) == 'The Guides'
}

fn test_llms_section_title_falls_back_to_humanised_key() {
	bucket := [
		&content.Page{
			title: 'A page'
		},
	]
	assert llms_section_title('release-notes', bucket) == 'Release Notes'
}

fn test_llms_section_title_empty_key_is_home() {
	assert llms_section_title('', []&content.Page{}) == 'Home'
}

fn test_bullet_for_includes_description_when_set() {
	p := &content.Page{
		title:       'Quick start'
		description: 'Your first site.'
		permalink:   'https://example.com/quick-start/'
	}
	assert bullet_for(p) == '- [Quick start](https://example.com/quick-start/): Your first site.'
}

fn test_bullet_for_falls_back_to_relpermalink() {
	p := &content.Page{
		title:         'Quick start'
		rel_permalink: '/quick-start/'
	}
	assert bullet_for(p) == '- [Quick start](/quick-start/)'
}

fn test_sort_section_pages_puts_index_first_then_date_desc() {
	older := &content.Page{
		title: 'Older'
		date:  time.parse_iso8601('2024-01-01T00:00:00Z') or { time.Time{} }
	}
	newer := &content.Page{
		title: 'Newer'
		date:  time.parse_iso8601('2025-06-01T00:00:00Z') or { time.Time{} }
	}
	section := &content.Page{
		title:      'Section'
		is_section: true
	}
	bucket := [older, newer, section]
	sorted := sort_section_pages(bucket)
	assert sorted.len == 3
	assert sorted[0].is_section
	assert sorted[1].title == 'Newer'
	assert sorted[2].title == 'Older'
}
