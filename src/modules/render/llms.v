// llms generates the llmstxt.org outputs alongside the HTML build:
//   - a per-page markdown twin written next to each `index.html` as
//     `index.html.md` (header H1 + emphasised description + body markdown),
//   - `/llms.txt` at the output root, a curated index following the
//     llmstxt.org standard (H1 site, blockquote summary, H2 per section,
//     bullet list of `[title](url): description` per page),
//   - `/llms-full.txt` at the output root, every included page's markdown
//     twin concatenated with `---` horizontal-rule separators.
//
// The whole feature can be disabled site-wide with `llms: { enabled: false }`
// in `verne.yaml`. Individual pages opt out with `llms: false` in their
// frontmatter — they then receive no `.html.md`, are absent from
// `llms-full.txt`, and are not listed in `llms.txt`.
module render

import os
import content

// write_page_md writes the page's markdown twin alongside its HTML output.
// Called from the per-page build loop just before the HTML is emitted, so
// the markdown reflects the same source that produced the HTML.
fn (r &Renderer) write_page_md(p &content.Page, html_path string) ! {
	if !r.cfg.llms_enabled || p.llms_excluded {
		return
	}
	md_path := html_path + '.md'
	os.write_file(md_path, page_md(p))!
}

// write_llms_index emits `/llms.txt` and `/llms-full.txt` at the output
// root, covering every page that did not opt out. Skipped wholesale when
// `cfg.llms_enabled` is false.
fn (mut r Renderer) write_llms_index() ! {
	if !r.cfg.llms_enabled {
		return
	}
	included := llms_included_pages(r.site.pages)
	os.write_file(os.join_path(r.output_dir, 'llms.txt'), r.build_llms_txt(included))!
	os.write_file(os.join_path(r.output_dir, 'llms-full.txt'), build_llms_full(included))!
}

// llms_included_pages filters out pages flagged `llms: false`. Synthesized
// taxonomy term/list pages never reach this filter — they live outside
// `site.pages` and are produced ad hoc by `extras.v`.
fn llms_included_pages(pages []&content.Page) []&content.Page {
	mut out := []&content.Page{cap: pages.len}
	for p in pages {
		if p.llms_excluded {
			continue
		}
		out << p
	}
	return out
}

// page_md formats a page as a self-contained markdown document: H1 with the
// title, an italicised description line, then the page's body markdown.
// Title and description are omitted when empty so a body-only page does not
// pick up stray blank header lines.
fn page_md(p &content.Page) string {
	mut parts := []string{cap: 5}
	if p.title.len > 0 {
		parts << '# ${p.title}'
	}
	if p.description.len > 0 {
		parts << '_${p.description}_'
	}
	body := p.body_md.trim_space()
	if body.len > 0 {
		parts << body
	}
	if parts.len == 0 {
		return ''
	}
	return parts.join('\n\n') + '\n'
}

// build_llms_full concatenates every included page's markdown twin into a
// single document, separated by horizontal rules so an LLM can chunk on the
// boundary without confusing sibling pages.
fn build_llms_full(pages []&content.Page) string {
	mut out := []string{cap: pages.len}
	for p in pages {
		md := page_md(p)
		if md.len == 0 {
			continue
		}
		out << md.trim_right('\n')
	}
	return out.join('\n\n---\n\n') + '\n'
}

// build_llms_txt renders the curated index: H1 site title, blockquote
// summary (cfg.params.description or .tagline), then one H2 group per
// section listing each page as a bullet.
fn (r &Renderer) build_llms_txt(pages []&content.Page) string {
	mut sb := []string{cap: 32}
	sb << '# ${r.llms_site_title()}'
	desc := r.llms_site_description()
	if desc.len > 0 {
		sb << ''
		sb << '> ${desc}'
	}
	mut groups := map[string][]&content.Page{}
	for p in pages {
		// The home page is already represented by the H1 + blockquote;
		// listing it under its own group would just duplicate the site
		// title.
		if p.is_home {
			continue
		}
		key := p.section
		mut bucket := groups[key] or { []&content.Page{} }
		bucket << p
		groups[key] = bucket
	}
	mut keys := groups.keys()
	keys.sort()
	for key in keys {
		bucket := groups[key] or { continue }
		title := llms_section_title(key, bucket)
		sb << ''
		sb << '## ${title}'
		sb << ''
		for p in sort_section_pages(bucket) {
			sb << bullet_for(p)
		}
	}
	return sb.join('\n') + '\n'
}

// sort_section_pages returns a bucket's pages with the section index first
// (so the H2's first bullet is the section's own landing page), then by
// date descending, falling back to title ascending for stable ordering of
// undated pages.
fn sort_section_pages(bucket []&content.Page) []&content.Page {
	mut sorted := bucket.clone()
	sorted.sort_with_compare(fn (a &&content.Page, b &&content.Page) int {
		if a.is_section != b.is_section {
			return if a.is_section { -1 } else { 1 }
		}
		au := a.date.unix()
		bu := b.date.unix()
		if au != bu {
			return if au > bu { -1 } else { 1 }
		}
		return if a.title < b.title {
			-1
		} else if a.title > b.title {
			1
		} else {
			0
		}
	})
	return sorted
}

fn bullet_for(p &content.Page) string {
	url := if p.permalink.len > 0 { p.permalink } else { p.rel_permalink }
	if p.description.len > 0 {
		return '- [${p.title}](${url}): ${p.description}'
	}
	return '- [${p.title}](${url})'
}

fn (r &Renderer) llms_site_title() string {
	if r.cfg.title.len > 0 {
		return r.cfg.title
	}
	return 'Site'
}

fn (r &Renderer) llms_site_description() string {
	for key in ['description', 'tagline'] {
		if v := r.cfg.params[key] {
			s := v.str_or('')
			if s.len > 0 {
				return s
			}
		}
	}
	return ''
}

// llms_section_title resolves a section key to a human-readable H2 label.
// Prefers the section's `_index.md` title when authored, falls back to the
// slug with dashes/slashes turned into spaces and each word capitalised.
// The empty key (home-anchored pages with no section) becomes "Home".
fn llms_section_title(key string, bucket []&content.Page) string {
	for p in bucket {
		if p.is_section && p.title.len > 0 {
			return p.title
		}
	}
	if key == '' {
		return 'Home'
	}
	return humanise_section_key(key)
}

fn humanise_section_key(key string) string {
	mut buf := []u8{cap: key.len}
	mut capitalise_next := true
	for c in key {
		if c == `-` || c == `_` || c == `/` {
			buf << ` `
			capitalise_next = true
			continue
		}
		if capitalise_next && c >= `a` && c <= `z` {
			buf << c - 32
		} else {
			buf << c
		}
		capitalise_next = false
	}
	return buf.bytestr()
}
