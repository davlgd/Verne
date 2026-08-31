// Module config loads the site configuration from a single YAML file at the
// project root. The schema is a small superset of common SSG keys: `title`,
// `base_url`, `theme`, `taxonomies`, `permalinks`, `params`, plus two
// book-shaped extras — `summary` (the explicit table of contents) and
// `edit_url` (a per-page edit-on-VCS link template). Unknown keys are kept
// verbatim under `params` so templates can read them via `site.params.foo`.
module config

import os
import yaml

// Maximum nesting depth of `summary:`. Bounded to keep the recursive parser
// out of pathological stack growth on malformed input.
const max_summary_depth = 16

// SummaryEntry is one row of the optional `summary:` list — the explicit,
// ordered table of contents that drives both the sidebar and the in-section
// prev/next chain. A book-shaped site declares one; a blog-shaped site does
// not (and falls back to date-based ordering).
//
// An entry may be:
//   - a leaf link        ({title, url})
//   - a parent link      ({title, url, children: [...]})
//   - a part header      ({header: "Part I"})  — no link, just a divider
pub struct SummaryEntry {
pub mut:
	title      string
	url        string
	is_header  bool
	children   []SummaryEntry
	chapter_no string // hierarchical number ("1", "1.2", "1.2.1"); empty for headers
}

pub struct Config {
pub mut:
	base_url        string
	locale          string
	title           string
	theme           string
	enable_robots   bool = true
	enable_emoji    bool
	llms_enabled    bool = true // emit /llms.txt, /llms-full.txt and per-page .html.md twins
	frontmatter_map map[string][]string
	permalinks      map[string]string
	taxonomies      map[string]string
	markup          map[string]yaml.Value
	outputs         map[string][]string
	params          map[string]yaml.Value
	security        map[string]yaml.Value
	summary         []SummaryEntry
	edit_url        string // template URL with `{path}` placeholder, or empty
	source_path     string // resolved path to the loaded config file
	root            string // project root directory
	output_dir      string // override for ${root}/public; empty = default
}

// load reads `verne.yaml` (or `.yml`) from `root` and returns the parsed
// config. Unknown keys are kept verbatim under `params`.
pub fn load(root string) !Config {
	candidates := ['verne.yaml', 'verne.yml']
	mut path := ''
	for c in candidates {
		p := os.join_path(root, c)
		if os.exists(p) {
			path = p
			break
		}
	}
	if path == '' {
		return error('config: no verne.yaml found in `${root}`')
	}
	raw := os.read_file(path)!
	doc := yaml.parse(raw) or { return error('config: ${err} (${path})') }
	return parse_config(doc, path, root)!
}

// load_file reads the given YAML file as the site config. The project root
// is taken from `dirname(path)`.
pub fn load_file(path string) !Config {
	if !os.exists(path) {
		return error('config: file not found `${path}`')
	}
	root := os.dir(os.real_path(path))
	raw := os.read_file(path)!
	doc := yaml.parse(raw) or { return error('config: ${err} (${path})') }
	return parse_config(doc, path, root)!
}

fn parse_config(doc map[string]yaml.Value, path string, root string) !Config {
	mut cfg := Config{
		source_path: path
		root: root
	}
	if v := doc['baseURL'] {
		raw := v.str_or('')
		if raw != '' {
			validate_base_url(raw) or { return error('config: ${err} (${path})') }
		}
		cfg.base_url = raw
	}
	if v := doc['locale'] {
		cfg.locale = v.str_or('')
	}
	if v := doc['title'] {
		cfg.title = v.str_or('')
	}
	if v := doc['theme'] {
		cfg.theme = v.str_or('')
	}
	if v := doc['enableRobotsTXT'] {
		cfg.enable_robots = bool_of(v)
	}
	if v := doc['enableEmoji'] {
		cfg.enable_emoji = bool_of(v)
	}
	if v := doc['llms'] {
		if m := v.as_map() {
			if e := m['enabled'] {
				cfg.llms_enabled = bool_of(e)
			}
		}
	}
	if v := doc['frontmatter'] {
		if m := v.as_map() {
			for k, lv in m {
				if list := lv.as_list() {
					mut names := []string{cap: list.len}
					for el in list {
						names << el.str_or('')
					}
					cfg.frontmatter_map[k] = names
				}
			}
		}
	}
	if v := doc['permalinks'] {
		if m := v.as_map() {
			for k, lv in m {
				cfg.permalinks[k] = lv.str_or('')
			}
		}
	}
	if v := doc['taxonomies'] {
		if m := v.as_map() {
			for k, lv in m {
				cfg.taxonomies[k] = lv.str_or('')
			}
		}
	}
	if v := doc['markup'] {
		if m := v.as_map() {
			cfg.markup = m.clone()
		}
	}
	if v := doc['outputs'] {
		if m := v.as_map() {
			for k, lv in m {
				if list := lv.as_list() {
					mut names := []string{cap: list.len}
					for el in list {
						names << el.str_or('')
					}
					cfg.outputs[k] = names
				}
			}
		}
	}
	if v := doc['params'] {
		if m := v.as_map() {
			cfg.params = m.clone()
		}
	}
	if v := doc['security'] {
		if m := v.as_map() {
			cfg.security = m.clone()
		}
	}
	if v := doc['summary'] {
		list := v.as_list() or { return error('config: `summary` must be a list (${path})') }
		cfg.summary = parse_summary(list, 0) or { return error('config: ${err} (${path})') }
		number_summary(mut cfg.summary, '')
	}
	if v := doc['edit_url'] {
		raw := v.str_or('')
		if raw != '' {
			validate_url_scheme(raw, 'edit_url') or { return error('config: ${err} (${path})') }
			if !raw.contains('{path}') {
				return error('config: `edit_url` must contain the `{path}` placeholder (${path})')
			}
			cfg.edit_url = raw
		}
	}
	return cfg
}

// number_summary walks a parsed summary and assigns hierarchical chapter
// numbers (`1`, `1.1`, `2`, `2.1.1`). At the top level, leaves that appear
// before the first header are treated as front-matter (Welcome / Title
// page) and get no number; numbering starts at the first chapter under the
// first Part. Children are scoped to their parent's number. Sub-levels do
// not have the front-matter exception — they always start at 1.
fn number_summary(mut entries []SummaryEntry, prefix string) {
	mut idx := 0
	mut started := prefix != '' // sub-levels start counting immediately
	for mut e in entries {
		if e.is_header {
			started = true
			continue
		}
		if !started {
			if e.children.len > 0 {
				number_summary(mut e.children, '')
			}
			continue
		}
		idx++
		e.chapter_no = if prefix == '' { '${idx}' } else { '${prefix}.${idx}' }
		if e.children.len > 0 {
			number_summary(mut e.children, e.chapter_no)
		}
	}
}

fn parse_summary(list []yaml.Value, depth int) ![]SummaryEntry {
	if depth > max_summary_depth {
		return error('summary: nesting too deep (>${max_summary_depth} levels)')
	}
	mut out := []SummaryEntry{cap: list.len}
	for item in list {
		m := item.as_map() or { continue }
		// `header: "…"` rows are visual dividers — no URL, no children.
		// An empty title is allowed and means "anonymous group": themes
		// can render the group without a visible label or toggle.
		if h := m['header'] {
			out << SummaryEntry{
				title: h.str_or('')
				is_header: true
			}
			continue
		}
		mut entry := SummaryEntry{}
		if t := m['title'] {
			entry.title = t.str_or('')
		}
		if u := m['url'] {
			entry.url = u.str_or('')
		}
		// URL scheme validation must propagate — silently skipping a
		// `javascript:` row would hide an XSS misconfiguration from the
		// author at build time.
		if entry.url != '' {
			validate_url_scheme(entry.url, 'summary url')!
		}
		if c := m['children'] {
			if children_list := c.as_list() {
				entry.children = parse_summary(children_list, depth + 1)!
			}
		}
		if entry.url == '' && entry.children.len == 0 {
			continue
		}
		out << entry
	}
	return out
}

// validate_base_url enforces that `baseURL` is an explicit http(s):// URL —
// the value ends up concatenated into RSS `<link>` elements, JSON-LD `url`
// fields, sitemap entries, and `<a href>` attributes. A `javascript:` or
// site-relative value would yield broken or hostile output. Compares the
// scheme case-insensitively and requires at least one authority byte after
// it; rejects ASCII bytes that break HTML attribute contexts.
pub fn validate_base_url(url string) ! {
	lower := url.to_lower()
	scheme_len := if lower.starts_with('https://') {
		8
	} else if lower.starts_with('http://') {
		7
	} else {
		0
	}
	if scheme_len == 0 {
		return error('baseURL: refusing `${url}` — must start with http:// or https://')
	}
	if url.len <= scheme_len || url[scheme_len] == `/` {
		return error('baseURL: refusing `${url}` — missing authority after scheme')
	}
	for i, c in url {
		if c < 0x20 || c == `"` || c == `'` || c == `<` || c == `>` || c == `\`` || c == ` ` {
			return error('baseURL: refusing `${url}` — invalid character at byte offset ${i}')
		}
	}
}

// validate_url_scheme rejects pseudo-schemes that turn an `<a href>` into a
// JavaScript or data-URL XSS vector. The allowlist matches what a static
// site reasonably needs: site-relative paths (`/foo/`), in-page anchors
// (`#bar`), and explicit http(s) URLs.
fn validate_url_scheme(url string, field string) ! {
	if url.starts_with('/') || url.starts_with('#') {
		return
	}
	if url.starts_with('http://') || url.starts_with('https://') {
		return
	}
	return error('${field}: refusing URL with unsupported scheme `${url}` (allow http(s):// or relative paths)')
}

fn bool_of(v yaml.Value) bool {
	return match v {
		bool { v }
		string { v.to_lower() == 'true' || v == '1' }
		i64 { v != 0 }
		else { false }
	}
}
