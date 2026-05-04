// Module content models a page: a Markdown file with optional YAML
// frontmatter, anchored to a section. The exposure as a template.Object
// lives in template_adapter.v.
module content

import os
import time
import frontmatter
import mdrender
import yaml

@[heap]
pub struct Page {
pub mut:
	title           string
	description     string
	date            time.Time
	last_mod        time.Time
	section         string
	source_path     string
	rel_url         string
	rel_permalink   string
	permalink       string
	body_md         string
	body_html       string
	plain           string
	word_count      int
	reading_time    int
	tags            []string
	is_home         bool
	is_section      bool
	params          map[string]yaml.Value
	base_filename   string
	layout          string
	prev_in_section &Page = unsafe { nil }
	next_in_section &Page = unsafe { nil }
	toc             string
	pages_in        []&Page
	base_url_abs    string
	jsonld_html     string // precomputed JSON-LD <script> body, empty when N/A
	edit_url        string // resolved cfg.edit_url with {path} substituted, empty when unset
	chapter_no      string // hierarchical number from cfg.summary, empty if not in summary
}

// load_page reads a Markdown file from disk, parses its YAML frontmatter,
// renders the body to HTML, and returns the populated Page.
pub fn load_page(root string, abs_path string, section string, frontmatter_date_keys []string, base_url string) !&Page {
	raw := os.read_file(abs_path)!
	doc := frontmatter.parse(raw) or { return error('${abs_path}: ${err}') }
	mut p := &Page{
		section:     section
		source_path: abs_path
		body_md:     doc.body
		params:      doc.meta.clone()
	}
	rel := abs_path.trim_string_left(root).trim_left('/').trim_string_left('content/')
	base := os.file_name(abs_path)
	p.base_filename = base.trim_string_right('.md')
	for k, v in doc.meta {
		match k {
			'title' {
				p.title = v.str_or('')
			}
			'description' {
				p.description = v.str_or('')
			}
			'layout' {
				p.layout = v.str_or('')
			}
			'tags' {
				if list := v.as_list() {
					for el in list {
						p.tags << el.str_or('')
					}
				}
			}
			else {}
		}
	}
	mut date_str := ''
	for key in frontmatter_date_keys {
		if v := doc.meta[key] {
			date_str = v.str_or('')
			if date_str != '' {
				break
			}
		}
	}
	if date_str == '' {
		if v := doc.meta['date'] {
			date_str = v.str_or('')
		}
	}
	if date_str != '' {
		if t := parse_iso(date_str) {
			p.date = t
			p.last_mod = t
		}
	}
	p.body_html = mdrender.render(p.body_md, mdrender.Options{})
	p.base_url_abs = base_url
	p.toc = mdrender.table_of_contents(p.body_md)
	p.plain = mdrender.plain(p.body_md)
	p.word_count = mdrender.word_count(p.body_md)
	p.reading_time = mdrender.reading_time(p.body_md)
	p.is_section = base == '_index.md'
	p.rel_url = rel
	return p
}

fn parse_iso(s string) ?time.Time {
	if t := time.parse_iso8601(s) {
		return t
	}
	if t := time.parse_format(s, 'YYYY-MM-DD') {
		return t
	}
	return none
}
