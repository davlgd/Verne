// Adapters that expose Site/Page struct fields to the new template engine
// (template). Each `as_template_object` returns a lazy Object that the engine
// queries on demand via `obj.get(field)`. No upfront map clone.
module content

import time
import meta
import template
import yaml
import config

fn rfc3339_no_ms(t time.Time) string {
	return '${t.year:04d}-${t.month:02d}-${t.day:02d}T${t.hour:02d}:${t.minute:02d}:${t.second:02d}Z'
}

// as_template_object exposes the site to templates as a lazy `Object`,
// resolving fields like `site.title` or `site.posts` on access.
pub fn (s &Site) as_template_object() template.Object {
	captured := s
	getter := fn [captured] (field string) ?template.Value {
		match field {
			'title' {
				return template.Value(captured.cfg.title)
			}
			'base_url' {
				return template.Value(captured.cfg.base_url)
			}
			'language' {
				loc := captured.cfg.locale
				short := if loc.contains('-') { loc.split('-')[0] } else { loc }
				return template.Value(short)
			}
			'language_code' {
				return template.Value(captured.cfg.locale)
			}
			'generator' {
				return template.Value('${meta.name} ${meta.version}')
			}
			'posts' {
				mut list := []template.Value{cap: captured.regular_pages.len}
				mut posts := captured.regular_pages.filter(it.section == 'posts')
				posts.sort_with_compare(fn (a &&Page, b &&Page) int {
					au := a.date.unix()
					bu := b.date.unix()
					return if au > bu {
						-1
					} else if au < bu {
						1
					} else {
						0
					}
				})
				for p in posts {
					list << template.Value(p.as_template_object())
				}
				return template.Value(list)
			}
			'pages' {
				mut list := []template.Value{cap: captured.regular_pages.len}
				for p in captured.regular_pages {
					list << template.Value(p.as_template_object())
				}
				return template.Value(list)
			}
			'recent_posts' {
				mut list := []template.Value{cap: captured.recent_posts.len}
				for p in captured.recent_posts {
					list << template.Value(p.as_template_object())
				}
				return template.Value(list)
			}
			'has_more_posts' {
				return template.Value(captured.has_more_posts)
			}
			'popular_tags' {
				return template.Value(tag_buckets_to_value(captured.popular_tags))
			}
			'popular_tags_overflow' {
				return template.Value(i64(captured.popular_tags_overflow))
			}
			'tags_by_name' {
				return template.Value(tag_buckets_to_value(captured.tags_by_name))
			}
			'stats' {
				return template.Value(stats_to_object(captured.posts_stats))
			}
			'heatmap' {
				return template.Value(heatmap_to_value(captured.heatmap_months))
			}
			'heatmap_years' {
				return template.Value(heatmap_to_year_rows(captured.heatmap_months))
			}
			'footer_socials' {
				return template.Value(socials_to_value(captured.footer_socials))
			}
			'projects' {
				return template.Value(projects_to_value(captured.projects))
			}
			'projects_error' {
				return template.Value(captured.projects_error)
			}
			'params' {
				return template.Value(yaml_to_template_map(captured.cfg.params))
			}
			'summary' {
				return template.Value(summary_to_value(captured.cfg.summary))
			}
			else {
				return none
			}
		}
	}
	return template.Object{
		name: 'site'
		getter: getter
	}
}

fn summary_to_value(entries []config.SummaryEntry) []template.Value {
	mut out := []template.Value{cap: entries.len}
	for entry in entries {
		mut m := map[string]template.Value{}
		m['title'] = template.Value(entry.title)
		m['url'] = template.Value(entry.url)
		m['is_header'] = template.Value(entry.is_header)
		m['chapter_no'] = template.Value(entry.chapter_no)
		m['children'] = template.Value(summary_to_value(entry.children))
		out << template.Value(m)
	}
	return out
}

// as_template_object exposes the page to templates as a lazy `Object`,
// resolving fields like `page.title`, `page.body`, `page.summary` on access.
pub fn (p &Page) as_template_object() template.Object {
	captured := p
	getter := fn [captured] (field string) ?template.Value {
		match field {
			'title' {
				return template.Value(captured.title)
			}
			'display_title' {
				return template.Value(page_display_title(captured))
			}
			'meta_description' {
				return template.Value(page_meta_description(captured))
			}
			'og_image' {
				return template.Value(page_og_image(captured))
			}
			'og_type' {
				return template.Value(page_og_type(captured))
			}
			'jsonld' {
				return template.Value(template.SafeString{
					value: captured.jsonld_html
				})
			}
			'breadcrumb_path' {
				return template.Value(page_breadcrumb_path(captured))
			}
			'layout' {
				return template.Value(captured.layout)
			}
			'has_rss' {
				return template.Value(page_has_rss(captured))
			}
			'rss_url' {
				return template.Value(page_rss_url(captured))
			}
			'term' {
				if v := captured.params['term'] {
					return template.Value(v.str_or(''))
				}
				return template.Value('')
			}
			'description' {
				return template.Value(captured.description)
			}
			'section' {
				return template.Value(captured.section)
			}
			'permalink' {
				return template.Value(captured.permalink)
			}
			'relpermalink' {
				return template.Value(captured.rel_permalink)
			}
			'edit_url' {
				return template.Value(captured.edit_url)
			}
			'chapter_no' {
				return template.Value(captured.chapter_no)
			}
			'is_home' {
				return template.Value(captured.is_home)
			}
			'is_section' {
				return template.Value(captured.is_section)
			}
			'is_page' {
				return template.Value(!captured.is_section && !captured.is_home)
			}
			'word_count' {
				return template.Value(i64(captured.word_count))
			}
			'reading_time' {
				return template.Value(i64(captured.reading_time))
			}
			'plain' {
				return template.Value(captured.plain)
			}
			'content' {
				return template.Value(template.SafeString{
					value: captured.body_html
				})
			}
			'toc' {
				if captured.toc.len == 0 {
					return template.Value('')
				}
				return template.Value(template.SafeString{
					value: captured.toc
				})
			}
			'tags' {
				mut list := []template.Value{cap: captured.tags.len}
				for t in captured.tags {
					list << template.Value(t)
				}
				return template.Value(list)
			}
			'pages' {
				mut list := []template.Value{cap: captured.pages_in.len}
				for inner in captured.pages_in {
					list << template.Value(inner.as_template_object())
				}
				return template.Value(list)
			}
			'date' {
				return template.Value(template.DateValue{
					t: captured.date
				})
			}
			'lastmod' {
				return template.Value(template.DateValue{
					t: captured.last_mod
				})
			}
			'file' {
				return template.Value(file_to_template_object(captured))
			}
			'params' {
				return template.Value(yaml_to_template_map(captured.params))
			}
			'prev_in_section' {
				if isnil(captured.prev_in_section) {
					return template.none_value
				}
				return template.Value(captured.prev_in_section.as_template_object())
			}
			'next_in_section' {
				if isnil(captured.next_in_section) {
					return template.none_value
				}
				return template.Value(captured.next_in_section.as_template_object())
			}
			else {
				return none
			}
		}
	}
	return template.Object{
		name: 'page'
		getter: getter
	}
}

fn file_to_template_object(p &Page) template.Object {
	captured := p
	getter := fn [captured] (field string) ?template.Value {
		match field {
			'basename' {
				return template.Value(captured.base_filename)
			}
			'path' {
				return template.Value(captured.rel_url)
			}
			else {
				return none
			}
		}
	}
	return template.Object{
		name: 'file'
		getter: getter
	}
}

fn tag_buckets_to_value(buckets []TagBucket) []template.Value {
	mut out := []template.Value{cap: buckets.len}
	for b in buckets {
		mut m := map[string]template.Value{}
		m['name'] = template.Value(b.name)
		m['count'] = template.Value(i64(b.count))
		out << template.Value(m)
	}
	return out
}

fn stats_to_object(s PostsStats) template.Object {
	captured := s
	getter := fn [captured] (field string) ?template.Value {
		match field {
			'total_posts' {
				return template.Value(i64(captured.total_posts))
			}
			'total_words' {
				return template.Value(i64(captured.total_words))
			}
			'avg_words' {
				return template.Value(i64(captured.avg_words))
			}
			'total_read' {
				return template.Value(i64(captured.total_read))
			}
			'avg_read' {
				return template.Value(i64(captured.avg_read))
			}
			'since_year' {
				return template.Value(i64(captured.since_year))
			}
			'uptime_years' {
				return template.Value(i64(captured.uptime_years))
			}
			'last_post_date' {
				return template.Value(template.DateValue{
					t: captured.last_post_date
				})
			}
			else {
				return none
			}
		}
	}
	return template.Object{
		name: 'stats'
		getter: getter
	}
}

fn projects_to_value(items []Project) []template.Value {
	mut out := []template.Value{cap: items.len}
	for p in items {
		mut m := map[string]template.Value{}
		m['name'] = template.Value(p.name)
		m['desc'] = template.Value(p.desc)
		m['tag'] = template.Value(p.tag)
		m['stars'] = template.Value(i64(p.stars))
		m['status'] = template.Value(p.status)
		m['year'] = template.Value(i64(p.year))
		m['url'] = template.Value(p.url)
		out << template.Value(m)
	}
	return out
}

fn socials_to_value(links []SocialLink) []template.Value {
	mut out := []template.Value{cap: links.len}
	for l in links {
		mut m := map[string]template.Value{}
		m['label'] = template.Value(l.label)
		m['url'] = template.Value(l.url)
		out << template.Value(m)
	}
	return out
}

// heatmap_to_year_rows groups cells by year. Each row exposes:
//   year     i64
//   cells    list of 12 cells (Jan..Dec) — cells outside the active range
//            are flagged empty=true, others carry level/count/key.
fn heatmap_to_year_rows(cells []HeatmapCell) []template.Value {
	if cells.len == 0 {
		return []template.Value{}
	}
	mut max_count := 0
	for c in cells {
		if c.count > max_count {
			max_count = c.count
		}
	}
	mut by_key := map[string]HeatmapCell{}
	mut start_year := cells[0].year
	mut end_year := cells[0].year
	mut start_month := cells[0].month
	mut end_month := cells[cells.len - 1].month
	for c in cells {
		key := '${c.year:04d}-${c.month:02d}'
		by_key[key] = c
		if c.year < start_year || (c.year == start_year && c.month < start_month) {
			start_year = c.year
			start_month = c.month
		}
		if c.year > end_year || (c.year == end_year && c.month > end_month) {
			end_year = c.year
			end_month = c.month
		}
	}
	mut rows := []template.Value{cap: end_year - start_year + 1}
	for y := start_year; y <= end_year; y++ {
		mut row_cells := []template.Value{cap: 12}
		for m := 1; m <= 12; m++ {
			before := y == start_year && m < start_month
			after := y == end_year && m > end_month
			mut cell := map[string]template.Value{}
			cell['year'] = template.Value(i64(y))
			cell['month'] = template.Value(i64(m))
			cell['key'] = template.Value('${y:04d}-${m:02d}')
			if before || after {
				cell['empty'] = template.Value(true)
				cell['count'] = template.Value(i64(0))
				cell['level'] = template.Value(i64(0))
			} else {
				cell['empty'] = template.Value(false)
				key := '${y:04d}-${m:02d}'
				c := by_key[key] or {
					HeatmapCell{
						year: y
						month: m
						count: 0
						intensity: 0.0
					}
				}
				cell['count'] = template.Value(i64(c.count))
				level := if c.count == 0 {
					i64(0)
				} else if c.intensity < 0.4 {
					i64(1)
				} else if c.intensity < 0.75 {
					i64(2)
				} else {
					i64(3)
				}
				cell['level'] = template.Value(level)
			}
			row_cells << template.Value(cell)
		}
		mut row := map[string]template.Value{}
		row['year'] = template.Value(i64(y))
		row['cells'] = template.Value(row_cells)
		rows << template.Value(row)
	}
	return rows
}

fn heatmap_to_value(cells []HeatmapCell) []template.Value {
	mut out := []template.Value{cap: cells.len}
	for c in cells {
		mut m := map[string]template.Value{}
		m['year'] = template.Value(i64(c.year))
		m['month'] = template.Value(i64(c.month))
		m['count'] = template.Value(i64(c.count))
		m['key'] = template.Value('${c.year:04d}-${c.month:02d}')
		// intensity is f64; engine's i64-only Value can't carry it directly,
		// so expose a discrete "level" 0..3 (none/lo/md/hi) that maps to CSS.
		level := if c.count == 0 {
			i64(0)
		} else if c.intensity < 0.4 {
			i64(1)
		} else if c.intensity < 0.75 {
			i64(2)
		} else {
			i64(3)
		}
		m['level'] = template.Value(level)
		out << template.Value(m)
	}
	return out
}

// yaml_to_template_value bridges a YAML scalar/list/map into the engine's
// own Value type. Floats are coerced to i64 since the engine has no float
// variant.
pub fn yaml_to_template_value(v yaml.Value) template.Value {
	return match v {
		string {
			template.Value(v)
		}
		bool {
			template.Value(v)
		}
		i64 {
			template.Value(v)
		}
		f64 {
			template.Value(i64(v))
		}

		// engine has no float; coerce
		[]yaml.Value {
			mut list := []template.Value{cap: v.len}
			for el in v {
				list << yaml_to_template_value(el)
			}
			template.Value(list)
		}
		map[string]yaml.Value {
			template.Value(yaml_to_template_map(v))
		}
	}
}

// yaml_to_template_map converts every entry of a YAML map through
// yaml_to_template_value.
pub fn yaml_to_template_map(m map[string]yaml.Value) map[string]template.Value {
	mut out := map[string]template.Value{}
	for k, v in m {
		out[k] = yaml_to_template_value(v)
	}
	return out
}

// Derived fields for templating. Computed on access, cheap; centralised
// here so templates stay strictly display-only.
fn page_display_title(p &Page) string {
	if p.is_home {
		return ''
	}
	return p.title
}

fn page_meta_description(p &Page) string {
	if p.description.len > 0 {
		return p.description
	}
	return ''
}

fn page_og_image(p &Page) string {
	if v := p.params['ogImage'] {
		s := v.str_or('')
		if s.len > 0 {
			return s
		}
	}
	if v := p.params['images'] {
		if list := v.as_list() {
			if list.len > 0 {
				return list[0].str_or('')
			}
		}
	}
	return ''
}

fn page_og_type(p &Page) string {
	return if p.section == 'posts' && !p.is_section { 'article' } else { 'website' }
}

fn page_has_rss(p &Page) bool {
	return p.is_home || (p.is_section && p.section.len > 0)
}

fn page_rss_url(p &Page) string {
	if p.is_home {
		return '/index.xml'
	}
	if p.is_section {
		return '/${p.section}/index.xml'
	}
	return ''
}

fn page_breadcrumb_path(p &Page) string {
	if p.is_home {
		return 'home'
	}
	if p.section == 'posts' {
		if p.is_section {
			return 'posts.md'
		}
		return 'posts/${p.base_filename}.md'
	}
	if p.is_section {
		return '${p.section}.md'
	}
	return '${p.base_filename}.md'
}

// build_jsonld returns the inner JSON-LD string for a page, or '' when none
// applies (taxonomy pages, sections, etc.). Format: BlogPosting for post
// pages, WebSite for the home page.
pub fn build_jsonld(p &Page, s &Site) string {
	if p.is_home {
		return jsonld_home(s)
	}
	if p.section == 'posts' && !p.is_section {
		return jsonld_post(p, s)
	}
	return ''
}

fn site_param_str(s &Site, key string) string {
	if v := s.cfg.params[key] {
		return v.str_or('')
	}
	return ''
}

fn site_param_nested_str(s &Site, parent string, child string) string {
	if v := s.cfg.params[parent] {
		if m := v.as_map() {
			if inner := m[child] {
				return inner.str_or('')
			}
		}
	}
	return ''
}

fn jsonld_author_object(s &Site) map[string]template.Value {
	mut o := map[string]template.Value{}
	o['@type'] = template.Value('Person')
	name := site_param_nested_str(s, 'author', 'name')
	if name.len > 0 {
		o['name'] = template.Value(name)
	} else {
		handle := site_param_str(s, 'handle')
		o['name'] = template.Value(handle)
	}
	url := site_param_nested_str(s, 'author', 'url')
	if url.len > 0 {
		o['url'] = template.Value(url)
	} else {
		o['url'] = template.Value(s.cfg.base_url)
	}
	return o
}

fn jsonld_publisher_object(s &Site) map[string]template.Value {
	mut o := map[string]template.Value{}
	o['@type'] = template.Value('Organization')
	o['name'] = template.Value(s.cfg.title)
	o['url'] = template.Value(s.cfg.base_url)
	return o
}

fn absolutize(s &Site, ref string) string {
	if ref == '' {
		return ''
	}
	if ref.starts_with('http://') || ref.starts_with('https://') {
		return ref
	}
	prefix := s.cfg.base_url.trim_right('/')
	if ref.starts_with('/') {
		return prefix + ref
	}
	return prefix + '/' + ref
}

fn jsonld_post(p &Page, s &Site) string {
	mut o := map[string]template.Value{}
	o['@context'] = template.Value('https://schema.org')
	o['@type'] = template.Value('BlogPosting')
	o['headline'] = template.Value(p.title)
	o['description'] = template.Value(p.description)
	o['datePublished'] = template.Value(rfc3339_no_ms(p.date))
	o['dateModified'] = template.Value(rfc3339_no_ms(p.last_mod))
	o['author'] = template.Value(jsonld_author_object(s))
	o['publisher'] = template.Value(jsonld_publisher_object(s))
	o['url'] = template.Value(p.permalink)
	mut main := map[string]template.Value{}
	main['@type'] = template.Value('WebPage')
	main['@id'] = template.Value(p.permalink)
	o['mainEntityOfPage'] = template.Value(main)
	o['keywords'] = template.Value(p.tags.join(', '))
	o['wordCount'] = template.Value(i64(p.word_count))
	mut img := page_og_image(p)
	if img.len == 0 {
		img = site_param_str(s, 'defaultOgImage')
	}
	if img.len > 0 {
		o['image'] = template.Value(absolutize(s, img))
	}
	return template.jsonify(template.Value(o))
}

fn jsonld_home(s &Site) string {
	mut o := map[string]template.Value{}
	o['@context'] = template.Value('https://schema.org')
	o['@type'] = template.Value('WebSite')
	o['name'] = template.Value(s.cfg.title)
	o['url'] = template.Value(s.cfg.base_url)
	o['description'] = template.Value(site_param_str(s, 'tagline'))
	o['author'] = template.Value(jsonld_author_object(s))
	mut action := map[string]template.Value{}
	action['@type'] = template.Value('SearchAction')
	mut target := map[string]template.Value{}
	target['@type'] = template.Value('EntryPoint')
	target['urlTemplate'] = template.Value('${s.cfg.base_url}search/?q={search_term_string}')
	action['target'] = template.Value(target)
	action['query-input'] = template.Value('required name=search_term_string')
	o['potentialAction'] = template.Value(action)
	return template.jsonify(template.Value(o))
}
