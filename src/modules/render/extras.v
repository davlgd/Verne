// Standard outputs that the theme rarely overrides: sitemap.xml,
// robots.txt, RSS feeds (home, posts, per-tag, tags root), taxonomy term
// pages. Hard-wired mini-Tera templates for XML/text outputs; theme
// templates (_default/term.html, _default/terms.html) for taxonomy HTML.
module render

import os
import strings
import time
import content
import template
import yaml

const sitemap_template = '<?xml version="1.0" encoding="utf-8" standalone="yes"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
{% for u in urls %}<url>
  <loc>{{ u.loc }}</loc>
{% if u.has_lastmod %}  <lastmod>{{ u.lastmod }}</lastmod>
{% endif %}</url>
{% endfor %}</urlset>
'

const robots_template = 'User-agent: *
Allow: /

Sitemap: {{ sitemap }}
'

const rss_template = '<?xml version="1.0" encoding="utf-8" standalone="yes"?>
<rss version="2.0" xmlns:atom="http://www.w3.org/2005/Atom">
  <channel>
    <title>{{ title }}</title>
    <link>{{ link }}</link>
    <description>{{ description }}</description>
    <generator>Verne</generator>
    <language>{{ lang }}</language>
    <lastBuildDate>{{ build_date }}</lastBuildDate>
    <atom:link href="{{ feed }}" rel="self" type="application/rss+xml" />
{% for it in items %}    <item>
      <title>{{ it.title }}</title>
      <link>{{ it.link }}</link>
      <pubDate>{{ it.pubdate }}</pubDate>
      <guid>{{ it.link }}</guid>
      <description>{{ it.description }}</description>
    </item>
{% endfor %}  </channel>
</rss>
'

// render_extras emits sitemap.xml, robots.txt, RSS feeds and taxonomy
// listing pages into the output directory.
pub fn (mut r Renderer) render_extras(site_obj template.Object) ! {
	r.write_sitemap()!
	r.write_robots()!
	r.write_rss_all()!
	r.write_taxonomy_pages(site_obj)!
}

fn (mut r Renderer) write_sitemap() ! {
	mut urls := []template.Value{}
	for p in r.site.pages {
		mut m := map[string]template.Value{}
		m['loc'] = template.Value(p.permalink)
		has_lm := p.date.unix() > 0
		m['has_lastmod'] = template.Value(has_lm)
		if has_lm {
			m['lastmod'] = template.Value(rfc3339_secs(p.last_mod))
		} else {
			m['lastmod'] = template.Value('')
		}
		urls << template.Value(m)
	}
	for tax_name, buckets in r.site.taxonomies {
		if buckets.len == 0 {
			continue
		}
		mut by_slug := map[string][]&content.Page{}
		for term, term_pages in buckets {
			slug := slugify(term)
			mut merged := by_slug[slug] or { []&content.Page{} }
			for tp in term_pages {
				merged << tp
			}
			by_slug[slug] = merged
			_ = term
		}
		mut all_latest := i64(0)
		for slug, term_pages in by_slug {
			mut latest := i64(0)
			for tp in term_pages {
				d := tp.date.unix()
				if d > latest {
					latest = d
				}
			}
			if latest > all_latest {
				all_latest = latest
			}
			mut m := map[string]template.Value{}
			m['loc'] = template.Value(r.cfg.base_url.trim_right('/') + '/${tax_name}/${slug}/')
			m['has_lastmod'] = template.Value(latest > 0)
			m['lastmod'] = template.Value(rfc3339_secs(time.unix(latest)))
			urls << template.Value(m)
		}
		mut m := map[string]template.Value{}
		m['loc'] = template.Value(r.cfg.base_url.trim_right('/') + '/${tax_name}/')
		m['has_lastmod'] = template.Value(all_latest > 0)
		m['lastmod'] = template.Value(rfc3339_secs(time.unix(all_latest)))
		urls << template.Value(m)
	}
	mut ctx := map[string]template.Value{}
	ctx['urls'] = template.Value(urls)
	body := r.engine.render(sitemap_template, ctx)!
	os.write_file(os.join_path(r.output_dir, 'sitemap.xml'), body)!
}

fn (mut r Renderer) write_robots() ! {
	if !r.cfg.enable_robots {
		return
	}
	mut ctx := map[string]template.Value{}
	ctx['sitemap'] = template.Value(r.cfg.base_url + 'sitemap.xml')
	body := r.engine.render(robots_template, ctx)!
	os.write_file(os.join_path(r.output_dir, 'robots.txt'), body)!
}

fn (mut r Renderer) write_rss_all() ! {
	site_title := r.cfg.title
	r.write_one_rss(r.site.regular_pages, false, site_title, 'Recent content on ' + site_title, os.join_path(r.output_dir,
		'index.xml'), r.cfg.base_url, r.cfg.base_url + 'index.xml')!
	mut posts := []&content.Page{}
	for p in r.site.regular_pages {
		if p.section == 'posts' {
			posts << p
		}
	}
	if posts.len > 0 {
		section_dir := os.join_path(r.output_dir, 'posts')
		os.mkdir_all(section_dir)!
		section_title := 'Posts on ' + site_title
		r.write_one_rss(posts, false, section_title, 'Recent content in ' + section_title, os.join_path(section_dir,
			'index.xml'), r.cfg.base_url + 'posts/', r.cfg.base_url + 'posts/index.xml')!
	}
	r.write_taxonomy_rss()!
}

fn (mut r Renderer) write_taxonomy_rss() ! {
	tax_buckets := unsafe { r.site.taxonomies['tags'] }
	if tax_buckets.len == 0 {
		return
	}
	tags_dir := os.join_path(r.output_dir, 'tags')
	os.mkdir_all(tags_dir)!
	mut keys := tax_buckets.keys()
	keys.sort()

	for term in keys {
		term_pages := unsafe { tax_buckets[term] }
		slug := slugify(term)
		term_dir := os.join_path(tags_dir, slug)
		os.mkdir_all(term_dir)!
		title_term := term_title(term) + ' on ' + r.cfg.title
		feed_url := r.cfg.base_url + 'tags/' + slug + '/index.xml'
		link := r.cfg.base_url + 'tags/' + slug + '/'
		r.write_one_rss(term_pages, false, title_term, 'Recent content in ' + title_term, os.join_path(term_dir,
			'index.xml'), link, feed_url)!
	}

	mut tag_pages := []&content.Page{}
	for term in keys {
		term_pages := unsafe { tax_buckets[term] }
		mut latest := i64(0)
		for tp in term_pages {
			d := tp.date.unix()
			if d > latest {
				latest = d
			}
		}
		mut page := r.synth_term_page(term, term_pages)
		page.date = time.unix(latest)
		page.last_mod = page.date
		tag_pages << page
	}
	tag_pages.sort_with_compare(fn (a &&content.Page, b &&content.Page) int {
		ad := a.date.unix()
		bd := b.date.unix()
		return if ad < bd {
			1
		} else if ad > bd {
			-1
		} else {
			0
		}
	})
	tags_title := 'Tags on ' + r.cfg.title
	r.write_one_rss(tag_pages, true, tags_title, 'Recent content in ' + tags_title, os.join_path(tags_dir,
		'index.xml'), r.cfg.base_url + 'tags/', r.cfg.base_url + 'tags/index.xml')!
}

fn (mut r Renderer) write_one_rss(pages []&content.Page, suppress_desc bool, channel_title string, channel_desc string, out_path string, link string, feed_url string) ! {
	mut sorted := pages.clone()
	sorted.sort_with_compare(fn (a &&content.Page, b &&content.Page) int {
		ad := a.date.unix()
		bd := b.date.unix()
		return if ad < bd {
			1
		} else if ad > bd {
			-1
		} else {
			0
		}
	})
	mut items := []template.Value{cap: sorted.len}
	for p in sorted {
		if items.len >= 20 {
			break
		}
		mut m := map[string]template.Value{}
		m['title'] = template.Value(p.title)
		m['link'] = template.Value(p.permalink)
		m['pubdate'] = template.Value(format_rfc1123(p.date))
		desc := if suppress_desc { '' } else { rss_summary(p) }
		m['description'] = template.Value(desc)
		items << template.Value(m)
	}
	mut latest := time.now()
	if sorted.len > 0 {
		latest = sorted[0].date
	}
	build_date := format_rfc1123(latest)
	mut data := map[string]template.Value{}
	data['title'] = template.Value(channel_title)
	data['link'] = template.Value(link)
	data['description'] = template.Value(channel_desc)
	data['feed'] = template.Value(feed_url)
	data['lang'] = template.Value(r.cfg.locale)
	data['build_date'] = template.Value(build_date)
	data['items'] = template.Value(items)
	body := r.engine.render(rss_template, data)!
	os.write_file(out_path, body)!
}

fn rss_summary(p &content.Page) string {
	html := summary_html(p.body_html)
	return absolutize_urls(html, p.base_url_abs)
}

fn summary_html(html string) string {
	if html == '' {
		return ''
	}
	mut count := 0
	mut i := 0
	for i < html.len {
		idx := html.index_after('</p>', i) or { return html }
		count++
		i = idx + 4
		if count >= 2 {
			return html[..i]
		}
	}
	return html
}

fn absolutize_urls(html string, base_url string) string {
	if html == '' {
		return ''
	}
	prefix := base_url.trim_right('/')
	mut out := html.replace('href="/', 'href="${prefix}/')
	out = out.replace("href='/", "href='${prefix}/")
	out = out.replace('src="/', 'src="${prefix}/')
	out = out.replace("src='/", "src='${prefix}/")
	return out
}

fn rfc3339_secs(t time.Time) string {
	return '${t.year:04d}-${t.month:02d}-${t.day:02d}T${t.hour:02d}:${t.minute:02d}:${t.second:02d}Z'
}

fn format_rfc1123(t time.Time) string {
	day := day_short_name((t.day_of_week() - 1 + 7) % 7)
	month := month_short_name(t.month - 1)
	return '${day}, ${t.day:02d} ${month} ${t.year} ${t.hour:02d}:${t.minute:02d}:${t.second:02d} +0000'
}

fn day_short_name(i int) string {
	names := ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
	if i < 0 || i >= names.len {
		return 'Mon'
	}
	return names[i]
}

fn month_short_name(i int) string {
	names := ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']
	if i < 0 || i >= names.len {
		return 'Jan'
	}
	return names[i]
}

fn term_title(term string) string {
	if term == '' {
		return term
	}
	first := term[0]
	if first >= `a` && first <= `z` {
		return (first - 32).ascii_str() + term[1..]
	}
	return term
}

fn slugify(s string) string {
	mut out := strings.new_builder(s.len)
	for c in s.to_lower() {
		match c {
			`a`...`z`, `0`...`9` { out.write_u8(c) }
			` `, `-`, `_`, `\t` { out.write_u8(`-`) }
			else {}
		}
	}
	return out.str()
}

fn (mut r Renderer) write_taxonomy_pages(site_obj template.Object) ! {
	tax_buckets := unsafe { r.site.taxonomies['tags'] }
	if tax_buckets.len == 0 {
		return
	}
	tags_dir := os.join_path(r.output_dir, 'tags')
	os.mkdir_all(tags_dir)!
	if r.template_exists('_default/terms.html') {
		page := r.synth_page('tags', '_index')
		mut ctx := r.base_context(site_obj)
		ctx['page'] = template.Value(page.as_template_object())
		body := r.engine.render_template('_default/terms.html', ctx)!
		os.write_file(os.join_path(tags_dir, 'index.html'), body)!
	}
	if r.template_exists('_default/term.html') {
		mut keys := tax_buckets.keys()
		keys.sort()
		for term in keys {
			pages := unsafe { tax_buckets[term] }
			term_dir := os.join_path(tags_dir, slugify(term))
			os.mkdir_all(term_dir)!
			page := r.synth_term_page(term, pages)
			mut ctx := r.base_context(site_obj)
			ctx['page'] = template.Value(page.as_template_object())
			body := r.engine.render_template('_default/term.html', ctx)!
			os.write_file(os.join_path(term_dir, 'index.html'), body)!
		}
	}
}

fn (r &Renderer) synth_page(section string, name string) &content.Page {
	return &content.Page{
		title:         section
		section:       section
		base_filename: name
		is_section:    true
		rel_permalink: '/' + section + '/'
		permalink:     r.cfg.base_url.trim_right('/') + '/' + section + '/'
	}
}

fn (r &Renderer) synth_term_page(term string, pages []&content.Page) &content.Page {
	slug := slugify(term)
	mut params := map[string]yaml.Value{}
	params['term'] = yaml.Value(term)
	return &content.Page{
		title:         term_title(term)
		section:       'tags'
		base_filename: slug
		is_section:    true
		rel_permalink: '/tags/' + slug + '/'
		permalink:     r.cfg.base_url.trim_right('/') + '/tags/' + slug + '/'
		pages_in:      pages.clone()
		params:        params
	}
}
