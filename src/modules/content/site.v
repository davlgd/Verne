// Site aggregates all pages and pre-computes the data templates need
// (popular tags, posts stats, heatmap, projects, footer socials).
// Template-side exposure lives in template_adapter.v.
module content

import os
import time
import x.json2
import config
import remote

@[heap]
pub struct Site {
pub mut:
	cfg           config.Config
	pages         []&Page
	regular_pages []&Page
	sections      map[string][]&Page
	taxonomies    map[string]map[string][]&Page
	home          &Page = unsafe { nil }
	// Precomputed aggregates exposed to templates as `site.<field>`. They are
	// computed once at build time, sparing templates from doing algorithmic
	// work (counts, sorts, groupings).
	popular_tags          []TagBucket // sorted by count desc, then name asc
	popular_tags_overflow int // count of tags beyond the visible 23
	tags_by_name          []TagBucket // sorted by name asc
	posts_stats           PostsStats
	heatmap_months        []HeatmapCell // one per month between first/last post
	footer_socials        []SocialLink // ordered, only the ones configured
	projects              []Project // GitHub repos fetched at build time
	projects_error        string // empty on success
	recent_posts          []&Page // newest-first, capped at recent_posts_limit
	has_more_posts        bool // true when total posts > recent_posts_limit
}

// default_recent_posts_limit is the home-page teaser cap when the site
// config doesn't override it via `params.recent_posts_limit`.
pub const default_recent_posts_limit = 5

pub struct TagBucket {
pub:
	name  string
	count int
}

pub struct PostsStats {
pub:
	total_posts    int
	total_words    int
	avg_words      int
	total_read     int
	avg_read       int
	since_year     int
	uptime_years   int // current year - since_year
	last_post_date time.Time
}

pub struct SocialLink {
pub:
	label string
	url   string
}

pub struct Project {
pub:
	name       string
	desc       string
	tag        string // first topic, or lowercased language
	stars      int
	status     string // active | inactive | old | archived
	year       int // creation year
	updated_at string
	url        string
}

pub struct HeatmapCell {
pub:
	year      int
	month     int // 1..12
	count     int
	intensity f64 // 0.0..1.0
}

// build_site walks `cfg.root/content`, loads every Markdown page, computes
// derived fields (sections, taxonomies, summaries, JSON-LD) and returns the
// fully linked page graph.
pub fn build_site(cfg config.Config) !&Site {
	mut site := &Site{
		cfg: cfg
	}
	root := cfg.root
	content_dir := os.join_path(root, 'content')
	if !os.exists(content_dir) {
		return error('site: missing `content/` directory at ${root}')
	}
	site.walk(content_dir, '')!
	site.ensure_home()
	site.regular_pages = site.pages.filter(!it.is_section && !it.is_home)
	site.compute_permalinks()
	site.compute_edit_urls()
	site.build_sections()
	site.build_taxonomies()
	site.link_section_neighbors()
	site.compute_chapter_numbers()
	site.compute_aggregates()
	return site
}

fn (mut s Site) compute_chapter_numbers() {
	if s.cfg.summary.len == 0 {
		return
	}
	numbers := s.summary_chapter_numbers()
	for mut p in s.pages {
		if n := numbers[p.rel_permalink] {
			p.chapter_no = n
		}
	}
}

fn (mut s Site) compute_edit_urls() {
	if s.cfg.edit_url == '' {
		return
	}
	for mut p in s.pages {
		p.edit_url = s.cfg.edit_url.replace('{path}', p.rel_url)
	}
}

// compute_aggregates fills the precomputed-aggregate fields on Site. Run
// once after taxonomies are built; templates read these directly so they
// never need to count, sort or group.
fn (mut s Site) compute_aggregates() {
	posts := s.pages.filter(it.section == 'posts' && !it.is_section && !it.is_home)
	s.posts_stats = compute_posts_stats(posts)
	tags := compute_tag_buckets(posts)
	s.popular_tags = tags.clone()
	s.popular_tags.sort_with_compare(fn (a &TagBucket, b &TagBucket) int {
		if a.count != b.count {
			return if a.count > b.count { -1 } else { 1 }
		}
		return if a.name < b.name {
			-1
		} else if a.name > b.name {
			1
		} else {
			0
		}
	})
	s.tags_by_name = tags.clone()
	s.tags_by_name.sort_with_compare(fn (a &TagBucket, b &TagBucket) int {
		return if a.name < b.name {
			-1
		} else if a.name > b.name {
			1
		} else {
			0
		}
	})
	s.popular_tags_overflow = if s.popular_tags.len > 23 { s.popular_tags.len - 23 } else { 0 }
	s.heatmap_months = compute_heatmap(posts)
	s.footer_socials = compute_footer_socials(s.cfg)
	s.fetch_projects()
	s.compute_jsonld_for_pages()
	s.compute_recent_posts(posts)
}

// compute_recent_posts sorts posts newest-first and stores the first N as
// `recent_posts`, where N is `params.recent_posts_limit` (default 5). Used
// by themes to render a trimmed list on the home, with `has_more_posts`
// driving the "see all" link.
fn (mut s Site) compute_recent_posts(posts []&Page) {
	mut sorted := posts.clone()
	sorted.sort_with_compare(fn (a &&Page, b &&Page) int {
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
	limit := s.recent_posts_limit()
	if sorted.len <= limit {
		s.recent_posts = sorted
		s.has_more_posts = false
		return
	}
	s.recent_posts = sorted[..limit]
	s.has_more_posts = true
}

fn (s &Site) recent_posts_limit() int {
	v := s.cfg.params['recent_posts_limit'] or { return default_recent_posts_limit }
	n := match v {
		i64 { int(v) }
		string { v.int() }
		else { default_recent_posts_limit }
	}

	return if n > 0 { n } else { default_recent_posts_limit }
}

fn (mut s Site) fetch_projects() {
	user_v := s.cfg.params['githubUser'] or { return }
	user := user_v.str_or('')
	if user.len == 0 {
		return
	}
	topic := if v := s.cfg.params['projectsTopic'] { v.str_or('') } else { '' }
	url := 'https://api.github.com/users/${user}/repos?per_page=100&type=public&sort=updated&direction=desc'
	mut headers := map[string]string{}
	headers['Accept'] = 'application/vnd.github+json'
	headers['User-Agent'] = 'verne-static-generator'
	if token := os.getenv_opt('GITHUB_TOKEN') {
		if token.len > 0 {
			headers['Authorization'] = 'Bearer ${token}'
		}
	}
	resp := remote.get(url, remote.Options{ headers: headers }) or {
		s.projects_error = err.msg()
		return
	}
	parsed := json2.decode[json2.Any](resp.body) or {
		s.projects_error = 'parse: ${err.msg()}'
		return
	}
	repos_arr := parsed.as_array()
	this_year := time.now().year
	mut out := []Project{cap: repos_arr.len}
	for r_any in repos_arr {
		r := r_any.as_map()
		fork := (r['fork'] or { json2.Any(false) }).bool()
		private := (r['private'] or { json2.Any(false) }).bool()
		desc := (r['description'] or { json2.Any('') }).str()
		if fork || private || desc.len == 0 {
			continue
		}
		topics_arr := (r['topics'] or { json2.Any([]json2.Any{}) }).as_array()
		if topic.len > 0 {
			mut found := false
			for tv in topics_arr {
				if tv.str() == topic {
					found = true
					break
				}
			}
			if !found {
				continue
			}
		}
		created := (r['created_at'] or { json2.Any('') }).str()
		updated := (r['updated_at'] or { json2.Any('') }).str()
		archived := (r['archived'] or { json2.Any(false) }).bool()
		language := (r['language'] or { json2.Any('') }).str()
		html_url := (r['html_url'] or { json2.Any('') }).str()
		stars := int((r['stargazers_count'] or { json2.Any(i64(0)) }).int())
		name := (r['name'] or { json2.Any('') }).str()
		year := if created.len >= 4 { created[..4].int() } else { 0 }
		upd_year := if updated.len >= 4 { updated[..4].int() } else { 0 }
		mut status := 'inactive'
		if archived {
			status = 'archived'
		} else if this_year - upd_year > 5 {
			status = 'old'
		} else if upd_year >= this_year - 1 {
			status = 'active'
		}
		mut tag := language.to_lower()
		if topics_arr.len > 0 {
			tag = topics_arr[0].str()
		}
		out << Project{
			name: name
			desc: desc
			tag: tag
			stars: stars
			status: status
			year: year
			updated_at: updated
			url: html_url
		}
	}
	out.sort_with_compare(fn (a &Project, b &Project) int {
		return if a.updated_at > b.updated_at {
			-1
		} else if a.updated_at < b.updated_at {
			1
		} else {
			0
		}
	})
	s.projects = out
}

fn (mut s Site) compute_jsonld_for_pages() {
	for mut p in s.pages {
		p.jsonld_html = build_jsonld(p, s)
	}
}

fn compute_posts_stats(posts []&Page) PostsStats {
	mut total_words := 0
	mut total_read := 0
	mut earliest := time.Time{}
	mut latest := time.Time{}
	for i, p in posts {
		total_words += p.word_count
		total_read += p.reading_time
		if i == 0 {
			earliest = p.date
			latest = p.date
		} else {
			if p.date.unix() < earliest.unix() {
				earliest = p.date
			}
			if p.date.unix() > latest.unix() {
				latest = p.date
			}
		}
	}
	avg_words := if posts.len > 0 { total_words / posts.len } else { 0 }
	avg_read := if posts.len > 0 { total_read / posts.len } else { 0 }
	now_year := time.now().year
	return PostsStats{
		total_posts: posts.len
		total_words: total_words
		avg_words: avg_words
		total_read: total_read
		avg_read: avg_read
		since_year: earliest.year
		uptime_years: if posts.len > 0 { now_year - earliest.year } else { 0 }
		last_post_date: latest
	}
}

fn compute_footer_socials(cfg config.Config) []SocialLink {
	mut out := []SocialLink{}
	socials_v := cfg.params['socials'] or { return out }
	socials := socials_v.as_map() or { return out }
	order := [
		['rss', 'rss'],
		['github', 'github'],
		['gitlab', 'framagit'],
		['bluesky', 'bluesky'],
		['x', 'x'],
		['linkedin', 'linkedin'],
	]
	for entry in order {
		key := entry[0]
		label := entry[1]
		if v := socials[key] {
			s := v.str_or('')
			if s.len > 0 {
				out << SocialLink{
					label: label
					url: s
				}
			}
		}
	}
	return out
}

fn compute_tag_buckets(posts []&Page) []TagBucket {
	mut counts := map[string]int{}
	for p in posts {
		for t in p.tags {
			counts[t]++
		}
	}
	mut out := []TagBucket{cap: counts.len}
	for name, count in counts {
		out << TagBucket{
			name: name
			count: count
		}
	}
	return out
}

fn compute_heatmap(posts []&Page) []HeatmapCell {
	if posts.len == 0 {
		return []HeatmapCell{}
	}
	mut by_month := map[string]int{}
	mut earliest := posts[0].date
	mut latest := posts[0].date
	for p in posts {
		key := '${p.date.year:04d}-${p.date.month:02d}'
		by_month[key]++
		if p.date.unix() < earliest.unix() {
			earliest = p.date
		}
		if p.date.unix() > latest.unix() {
			latest = p.date
		}
	}
	mut max_count := 0
	for _, c in by_month {
		if c > max_count {
			max_count = c
		}
	}
	mut cells := []HeatmapCell{cap: 64}
	mut y := earliest.year
	mut m := earliest.month
	for y < latest.year || (y == latest.year && m <= latest.month) {
		key := '${y:04d}-${m:02d}'
		count := by_month[key] or { 0 }
		intensity := if max_count > 0 { f64(count) / f64(max_count) } else { 0.0 }
		cells << HeatmapCell{
			year: y
			month: m
			count: count
			intensity: intensity
		}
		m++
		if m > 12 {
			m = 1
			y++
		}
	}
	return cells
}

// link_section_neighbors fills `prev_in_section` and `next_in_section` on
// every page. Order priority: pages whose URL appears in `cfg.summary` come
// first, ranked by their position in that list; remaining pages fall through
// to ascending date as before.
fn (mut s Site) link_section_neighbors() {
	order := s.summary_order()
	for _, bucket in s.sections {
		mut sorted := bucket.clone()
		sorted.sort_with_compare(fn [order] (a &&Page, b &&Page) int {
			pa := order[a.rel_permalink] or { -1 }
			pb := order[b.rel_permalink] or { -1 }
			if pa >= 0 && pb >= 0 {
				return pa - pb
			}
			if pa >= 0 {
				return -1
			}
			if pb >= 0 {
				return 1
			}
			ad := a.date.unix()
			bd := b.date.unix()
			return if ad < bd {
				-1
			} else if ad > bd {
				1
			} else {
				0
			}
		})
		for i, mut p in sorted {
			if i > 0 {
				p.prev_in_section = sorted[i - 1]
			}
			if i + 1 < sorted.len {
				p.next_in_section = sorted[i + 1]
			}
		}
	}
}

// summary_order returns a `rel_permalink → position` map built from a
// depth-first traversal of `cfg.summary`. Headers and entries without a URL
// occupy no slot. Empty when no summary is declared.
fn (s &Site) summary_order() map[string]int {
	mut out := map[string]int{}
	flatten_summary(s.cfg.summary, mut out, 0)
	return out
}

// summary_chapter_numbers returns a `rel_permalink → chapter_no` map built
// from `cfg.summary`. Used to imprint each Page with its book position so
// templates can show eyebrows like "Chapter 2.1".
fn (s &Site) summary_chapter_numbers() map[string]string {
	mut out := map[string]string{}
	collect_chapter_numbers(s.cfg.summary, mut out)
	return out
}

fn collect_chapter_numbers(entries []config.SummaryEntry, mut out map[string]string) {
	for entry in entries {
		if entry.url != '' && entry.chapter_no != '' {
			out[entry.url] = entry.chapter_no
		}
		if entry.children.len > 0 {
			collect_chapter_numbers(entry.children, mut out)
		}
	}
}

fn flatten_summary(entries []config.SummaryEntry, mut out map[string]int, start int) int {
	mut idx := start
	for entry in entries {
		if entry.is_header {
			idx = flatten_summary(entry.children, mut out, idx)
			continue
		}
		if entry.url != '' {
			out[entry.url] = idx
			idx++
		}
		idx = flatten_summary(entry.children, mut out, idx)
	}
	return idx
}

fn (mut s Site) walk(dir string, section string) ! {
	for entry in os.ls(dir)! {
		full := os.join_path(dir, entry)
		if os.is_dir(full) {
			next_section := if section == '' { entry } else { section + '/' + entry }
			s.walk(full, next_section)!
			continue
		}
		if !entry.ends_with('.md') {
			continue
		}
		date_keys := s.cfg.frontmatter_map['date']
		page := load_page(s.cfg.root, full, section, date_keys, s.cfg.base_url) or {
			return error('site: ${err}')
		}
		s.pages << page
	}
}

fn (mut s Site) compute_permalinks() {
	prefix := s.cfg.base_url.trim_right('/')
	for mut p in s.pages {
		rel := s.rel_permalink_for(p)
		p.rel_permalink = rel
		p.permalink = prefix + rel
	}
}

fn (s &Site) rel_permalink_for(p &Page) string {
	if p.section == '' && p.base_filename == '_index' {
		return '/'
	}
	if p.is_section {
		return '/' + p.section + '/'
	}
	if p.section != '' {
		if pattern := s.cfg.permalinks[p.section] {
			return apply_permalink_pattern(pattern, p)
		}
		return '/' + p.section + '/' + p.base_filename + '/'
	}
	return '/' + p.base_filename + '/'
}

fn apply_permalink_pattern(pattern string, p &Page) string {
	mut out := pattern
	out = out.replace(':contentbasename', p.base_filename)
	out = out.replace(':slug', p.base_filename)
	out = out.replace(':filename', p.base_filename)
	out = out.replace(':section', p.section)
	out = out.replace(':year', p.date.year.str())
	out = out.replace(':month', '${p.date.month:02d}')
	out = out.replace(':day', '${p.date.day:02d}')
	return out
}

fn (mut s Site) build_sections() {
	for p in s.pages {
		if p.section == '' || p.is_section {
			continue
		}
		mut bucket := s.sections[p.section] or { []&Page{} }
		bucket << p
		s.sections[p.section] = bucket
	}
	// Wire each section's `_index.md` page's `.Pages` to its section
	// members so `_default/list.html` can iterate them.
	for mut p in s.pages {
		if !p.is_section || p.section == '' {
			continue
		}
		if bucket := s.sections[p.section] {
			p.pages_in = bucket.clone()
		}
	}
}

fn (mut s Site) build_taxonomies() {
	for tax_singular, tax_plural in s.cfg.taxonomies {
		mut buckets := map[string][]&Page{}
		_ = tax_singular
		for p in s.pages {
			if p.is_section || p.is_home {
				continue
			}
			if tax_plural == 'tags' {
				for t in p.tags {
					mut bucket := buckets[t] or { []&Page{} }
					bucket << p
					buckets[t] = bucket
				}
			}
		}
		s.taxonomies[tax_plural] = buckets.move()
	}
}

fn (mut s Site) ensure_home() {
	for p in s.pages {
		if p.section == '' && p.base_filename == '_index' {
			s.home = unsafe { p }
			s.home.is_home = true
			return
		}
	}
	// synthesize empty home
	s.home = &Page{
		title: s.cfg.title
		section: ''
		base_filename: '_index'
		is_home: true
	}
	s.pages << s.home
}
