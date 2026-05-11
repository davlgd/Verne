// llms generates the llmstxt.org outputs alongside the HTML build:
//   - a per-page markdown twin written next to each `index.html` as
//     `index.html.md` (H1 title + emphasised description + body markdown),
//     matching the companion-file proposal from the llms.txt spec,
//   - `/llms.txt` at the output root, a curated index conforming to the
//     llms.txt standard (H1 site, blockquote summary, one H2 per section,
//     bullet list of `[title](url): description` per page, optional
//     trailing `## Optional` H2 for pages marked `llms: optional`),
//   - `/llms-full.txt` at the output root, every included page's markdown
//     twin concatenated with `---` horizontal-rule separators. The name is
//     community convention (Anthropic, Stripe, …), not part of the spec.
//
// The whole feature can be disabled site-wide with `llms: { enabled: false }`
// in `verne.yaml`. Per-page knobs in frontmatter:
//   - `llms: false`    — fully excluded (no twin, absent from both indexes)
//   - `llms: optional` — listed under `## Optional`, still in llms-full.txt
//   - `llms: true`     — explicit default (same as omitting the key)
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
	os.write_file(html_path + '.md', page_md(p))!
}

// write_llms_index emits `/llms.txt` and `/llms-full.txt` at the output
// root, covering every page that did not opt out. Skipped wholesale when
// `cfg.llms_enabled` is false.
fn (mut r Renderer) write_llms_index() ! {
	if !r.cfg.llms_enabled {
		return
	}
	included := llms_included_pages(r.site.pages)
	title := r.llms_site_title()
	desc := r.llms_site_description()
	os.write_file(os.join_path(r.output_dir, 'llms.txt'), build_llms_txt(title, desc, included))!
	os.write_file(os.join_path(r.output_dir, 'llms-full.txt'), build_llms_full(included))!
}

// llms_included_pages filters out pages flagged `llms: false`. Synthesized
// taxonomy term/list pages never reach this filter — they live outside
// `site.pages` and are produced ad hoc by `extras.v`.
fn llms_included_pages(pages []&content.Page) []&content.Page {
	mut out := []&content.Page{cap: pages.len}
	for p in pages {
		if !p.llms_excluded {
			out << p
		}
	}
	return out
}

// page_md formats a page as a self-contained markdown document: H1 with the
// title, an italicised description line, then the page's body markdown.
// Title and description are omitted when empty so a body-only page does not
// pick up stray blank header lines.
fn page_md(p &content.Page) string {
	mut parts := []string{cap: 3}
	if p.title != '' {
		parts << '# ${p.title}'
	}
	if p.description != '' {
		parts << '_${p.description}_'
	}
	body := p.body_md.trim_space()
	if body != '' {
		parts << body
	}
	if parts.len == 0 {
		return ''
	}
	return parts.join('\n\n') + '\n'
}

// build_llms_full concatenates every included page's markdown twin into a
// single document separated by horizontal rules. Pages appear in the same
// order as `/llms.txt`: home first (so the file opens with the site's
// introduction), then each section alphabetically — section index first,
// then date desc, then title asc — then any `llms: optional` pages last,
// mirroring the trailing `## Optional` H2 in the curated index.
fn build_llms_full(pages []&content.Page) string {
	ordered := canonical_page_order(pages, true)
	mut out := []string{cap: ordered.len}
	for p in ordered {
		md := page_md(p)
		if md == '' {
			continue
		}
		out << md.trim_right('\n')
	}
	return out.join('\n\n---\n\n') + '\n'
}

// build_llms_txt renders the curated index per the llms.txt standard: H1
// site title, optional blockquote summary, one H2 per section listing each
// page as a bullet, then a trailing `## Optional` H2 grouping every page
// flagged `llms: optional` in frontmatter (the spec-reserved section name
// for skippable URLs).
fn build_llms_txt(site_title string, site_description string, pages []&content.Page) string {
	mut sb := []string{cap: 32}
	sb << '# ${site_title}'
	if site_description != '' {
		sb << ''
		sb << '> ${site_description}'
	}
	b := bucket_pages(pages)
	mut keys := b.groups.keys()
	keys.sort()
	for key in keys {
		bucket := b.groups[key] or { continue }
		emit_h2_bullets(mut sb, llms_section_title(key, bucket), bucket)
	}
	if b.optional.len > 0 {
		emit_h2_bullets(mut sb, 'Optional', b.optional)
	}
	return sb.join('\n') + '\n'
}

// emit_h2_bullets appends an `## H2` block followed by one bullet per page
// in canonical order. Shared between regular sections and the trailing
// `## Optional` block so both render identically.
fn emit_h2_bullets(mut sb []string, title string, bucket []&content.Page) {
	sb << ''
	sb << '## ${title}'
	sb << ''
	for p in sort_section_pages(bucket) {
		sb << bullet_for(p)
	}
}

// PageBuckets is the grouped view both `build_llms_txt` and
// `canonical_page_order` consume: home (if any) on its own, regular pages
// grouped by section, `llms: optional` pages collected separately. Built
// once per call via `bucket_pages`.
struct PageBuckets {
mut:
	home     &content.Page = unsafe { nil }
	groups   map[string][]&content.Page
	optional []&content.Page
}

// bucket_pages partitions a flat page list into home / per-section / optional
// buckets. Used by both /llms.txt and /llms-full.txt so the two files agree
// on which page belongs where.
fn bucket_pages(pages []&content.Page) PageBuckets {
	mut b := PageBuckets{}
	for p in pages {
		if p.is_home {
			b.home = p
			continue
		}
		if p.llms_optional {
			b.optional << p
			continue
		}
		mut bucket := b.groups[p.section] or { []&content.Page{} }
		bucket << p
		b.groups[p.section] = bucket
	}
	return b
}

// canonical_page_order flattens the bucketed view into a single ordered
// list: home (if `include_home`), then sections alphabetically, then
// optional pages. Used by `/llms-full.txt`; `/llms.txt` consumes the same
// buckets directly to emit H2 boundaries.
fn canonical_page_order(pages []&content.Page, include_home bool) []&content.Page {
	b := bucket_pages(pages)
	mut keys := b.groups.keys()
	keys.sort()
	mut out := []&content.Page{cap: pages.len}
	if include_home && !isnil(b.home) {
		out << b.home
	}
	for key in keys {
		bucket := b.groups[key] or { continue }
		for p in sort_section_pages(bucket) {
			out << p
		}
	}
	for p in sort_section_pages(b.optional) {
		out << p
	}
	return out
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
	url := md_url_for(p)
	if p.description != '' {
		return '- [${p.title}](${url}): ${p.description}'
	}
	return '- [${p.title}](${url})'
}

// md_url_for returns the URL of the page's `.html.md` twin — the file
// browsers can fetch to receive the page's body as markdown. The llms.txt
// standard expects bullets to point at markdown-ready resources, not at
// the HTML pages humans navigate to.
fn md_url_for(p &content.Page) string {
	base := if p.permalink != '' { p.permalink } else { p.rel_permalink }
	if base.ends_with('/') {
		return base + 'index.html.md'
	}
	return base + '/index.html.md'
}

fn (r &Renderer) llms_site_title() string {
	if r.cfg.title != '' {
		return r.cfg.title
	}
	return 'Site'
}

fn (r &Renderer) llms_site_description() string {
	for key in ['description', 'tagline'] {
		if v := r.cfg.params[key] {
			s := v.str_or('')
			if s != '' {
				return s
			}
		}
	}
	return ''
}

// llms_section_title resolves a section key to a human-readable H2 label.
// Prefers the section's `_index.md` title when authored, falls back to the
// slug with separators (`-`, `_`, `/`) turned into spaces and each word
// capitalised. The empty key (top-level pages outside any section)
// becomes "Home".
fn llms_section_title(key string, bucket []&content.Page) string {
	for p in bucket {
		if p.is_section && p.title != '' {
			return p.title
		}
	}
	if key == '' {
		return 'Home'
	}
	return humanise_section_key(key)
}

fn humanise_section_key(key string) string {
	return key.replace_each(['-', ' ', '_', ' ', '/', ' ']).title()
}
