module content

import config
import template
import time
import yaml

fn test_template_adapter_site_exposes_basic_fields() {
	mut site := &Site{}
	site.cfg.title = 'My Blog'
	site.cfg.base_url = 'https://example.com/'
	site.cfg.locale = 'en-us'
	obj := site.as_template_object()
	title := obj.get('title') or { panic('no title') }
	assert template.to_string(title) == 'My Blog', template.to_string(title)
	lang := obj.get('language') or { panic('no language') }
	assert template.to_string(lang) == 'en', template.to_string(lang)
	code := obj.get('language_code') or { panic('no language_code') }
	assert template.to_string(code) == 'en-us', template.to_string(code)
}

fn test_link_section_neighbors_honours_summary() {
	// Build a tiny site with three pages whose dates would suggest one
	// ordering, while `summary` declares the opposite. The summary order
	// must win.
	a := &Page{
		section:       'chapter'
		base_filename: 'a'
		rel_permalink: '/chapter/a/'
		date:          time.unix(3000)
	}
	b := &Page{
		section:       'chapter'
		base_filename: 'b'
		rel_permalink: '/chapter/b/'
		date:          time.unix(2000)
	}
	c := &Page{
		section:       'chapter'
		base_filename: 'c'
		rel_permalink: '/chapter/c/'
		date:          time.unix(1000)
	}
	mut site := &Site{
		cfg: config.Config{
			summary: [
				config.SummaryEntry{
					title: 'First'
					url:   '/chapter/a/'
				},
				config.SummaryEntry{
					title: 'Second'
					url:   '/chapter/b/'
				},
				config.SummaryEntry{
					title: 'Third'
					url:   '/chapter/c/'
				},
			]
		}
	}
	site.sections['chapter'] = [a, b, c]
	site.link_section_neighbors()
	// a is first → no prev, next is b
	assert isnil(a.prev_in_section)
	assert !isnil(a.next_in_section) && a.next_in_section.rel_permalink == '/chapter/b/'
	// b is middle → prev is a, next is c
	assert !isnil(b.prev_in_section) && b.prev_in_section.rel_permalink == '/chapter/a/'
	assert !isnil(b.next_in_section) && b.next_in_section.rel_permalink == '/chapter/c/'
	// c is last → prev is b, no next
	assert !isnil(c.prev_in_section) && c.prev_in_section.rel_permalink == '/chapter/b/'
	assert isnil(c.next_in_section)
}

fn test_link_section_neighbors_honours_nested_summary_depth_first() {
	// Summary: A, [B with children B1, B2], C — flattened DFS = A, B, B1, B2, C.
	a := &Page{
		section:       'chapter'
		base_filename: 'a'
		rel_permalink: '/chapter/a/'
		date:          time.unix(1000)
	}
	b := &Page{
		section:       'chapter'
		base_filename: 'b'
		rel_permalink: '/chapter/b/'
		date:          time.unix(1000)
	}
	b1 := &Page{
		section:       'chapter'
		base_filename: 'b1'
		rel_permalink: '/chapter/b1/'
		date:          time.unix(1000)
	}
	b2 := &Page{
		section:       'chapter'
		base_filename: 'b2'
		rel_permalink: '/chapter/b2/'
		date:          time.unix(1000)
	}
	c := &Page{
		section:       'chapter'
		base_filename: 'c'
		rel_permalink: '/chapter/c/'
		date:          time.unix(1000)
	}
	mut site := &Site{
		cfg: config.Config{
			summary: [
				config.SummaryEntry{
					title:     'Header'
					is_header: true
				},
				config.SummaryEntry{
					title: 'A'
					url:   '/chapter/a/'
				},
				config.SummaryEntry{
					title:    'B'
					url:      '/chapter/b/'
					children: [
						config.SummaryEntry{
							title: 'B1'
							url:   '/chapter/b1/'
						},
						config.SummaryEntry{
							title: 'B2'
							url:   '/chapter/b2/'
						},
					]
				},
				config.SummaryEntry{
					title: 'C'
					url:   '/chapter/c/'
				},
			]
		}
	}
	site.sections['chapter'] = [c, b1, a, b2, b] // intentionally scrambled
	site.link_section_neighbors()
	assert isnil(a.prev_in_section) && a.next_in_section.rel_permalink == '/chapter/b/'
	assert b.prev_in_section.rel_permalink == '/chapter/a/'
		&& b.next_in_section.rel_permalink == '/chapter/b1/'
	assert b1.prev_in_section.rel_permalink == '/chapter/b/'
		&& b1.next_in_section.rel_permalink == '/chapter/b2/'
	assert b2.prev_in_section.rel_permalink == '/chapter/b1/'
		&& b2.next_in_section.rel_permalink == '/chapter/c/'
	assert c.prev_in_section.rel_permalink == '/chapter/b2/' && isnil(c.next_in_section)
}

fn test_compute_edit_urls_substitutes_path() {
	mut site := &Site{
		cfg: config.Config{
			edit_url: 'https://example.com/edit/main/content/{path}'
		}
	}
	site.pages << &Page{
		rel_url: 'chapter/01-introduction.md'
	}
	site.pages << &Page{
		rel_url: '_index.md'
	}
	site.compute_edit_urls()
	assert site.pages[0].edit_url == 'https://example.com/edit/main/content/chapter/01-introduction.md'
	assert site.pages[1].edit_url == 'https://example.com/edit/main/content/_index.md'
}

fn test_compute_edit_urls_noop_when_unset() {
	mut site := &Site{}
	site.pages << &Page{
		rel_url: 'chapter/foo.md'
	}
	site.compute_edit_urls()
	assert site.pages[0].edit_url == ''
}

fn test_recent_posts_caps_at_default_and_flags_overflow() {
	// Build 7 posts with strictly increasing dates, scrambled in `pages`.
	// `compute_recent_posts` should sort newest-first and trim to 5.
	mut posts := []&Page{}
	for i in 0 .. 7 {
		posts << &Page{
			section:       'posts'
			rel_permalink: '/posts/p${i}/'
			date:          time.unix(1000 + i64(i) * 100)
		}
	}
	mut site := &Site{}
	site.compute_recent_posts(posts)
	assert site.recent_posts.len == 5
	assert site.has_more_posts
	// Newest first: p6, p5, p4, p3, p2.
	assert site.recent_posts[0].rel_permalink == '/posts/p6/'
	assert site.recent_posts[4].rel_permalink == '/posts/p2/'
}

fn test_recent_posts_no_overflow_when_under_limit() {
	mut posts := []&Page{}
	for i in 0 .. 3 {
		posts << &Page{
			section:       'posts'
			rel_permalink: '/posts/p${i}/'
			date:          time.unix(1000 + i64(i) * 100)
		}
	}
	mut site := &Site{}
	site.compute_recent_posts(posts)
	assert site.recent_posts.len == 3
	assert !site.has_more_posts
}

fn test_recent_posts_honours_param_override() {
	mut posts := []&Page{}
	for i in 0 .. 10 {
		posts << &Page{
			section:       'posts'
			rel_permalink: '/posts/p${i}/'
			date:          time.unix(1000 + i64(i) * 100)
		}
	}
	mut site := &Site{
		cfg: config.Config{
			params: {
				'recent_posts_limit': yaml.Value(i64(3))
			}
		}
	}
	site.compute_recent_posts(posts)
	assert site.recent_posts.len == 3
	assert site.has_more_posts
	assert site.recent_posts[0].rel_permalink == '/posts/p9/'
}

fn test_link_section_neighbors_falls_back_to_date_when_summary_empty() {
	// No summary → ascending date order: c (1000), b (2000), a (3000).
	a := &Page{
		section:       'chapter'
		base_filename: 'a'
		rel_permalink: '/chapter/a/'
		date:          time.unix(3000)
	}
	b := &Page{
		section:       'chapter'
		base_filename: 'b'
		rel_permalink: '/chapter/b/'
		date:          time.unix(2000)
	}
	c := &Page{
		section:       'chapter'
		base_filename: 'c'
		rel_permalink: '/chapter/c/'
		date:          time.unix(1000)
	}
	mut site := &Site{}
	site.sections['chapter'] = [a, b, c]
	site.link_section_neighbors()
	assert isnil(c.prev_in_section)
	assert !isnil(c.next_in_section) && c.next_in_section.rel_permalink == '/chapter/b/'
	assert !isnil(a.prev_in_section) && a.prev_in_section.rel_permalink == '/chapter/b/'
	assert isnil(a.next_in_section)
}
