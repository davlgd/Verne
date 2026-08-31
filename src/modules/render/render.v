// render drives the build: bundles assets, picks a template per page,
// evaluates it through the template engine, writes output. Templates have
// no access to the asset pipeline — assets are precomputed and injected
// via the context (`assets.css_url`, `assets.css_integrity`, …).
module render

import os
import time
import assets
import config
import content
import mdrender
import template

@[heap]
pub struct Renderer {
pub mut:
	cfg           config.Config
	site          &content.Site
	engine        &template.Engine
	output_dir    string
	theme_root    string
	template_root string
	pipeline      &assets.Pipeline = unsafe { nil }
	asset_ctx     map[string]template.Value
}

// new wires a renderer for the given site and config: resolves theme paths,
// boots the template engine, and runs the asset pipeline once.
pub fn new(cfg config.Config, site &content.Site) !&Renderer {
	output_dir := if cfg.output_dir != '' {
		cfg.output_dir
	} else {
		os.join_path(cfg.root, 'public')
	}
	theme_root := os.join_path(cfg.root, 'themes', cfg.theme)
	template_root := os.join_path(theme_root, 'templates')
	if !os.exists(template_root) {
		return error('render: theme templates not found at ${template_root}')
	}
	asset_root := os.join_path(theme_root, 'assets')
	mut r := &Renderer{
		cfg: cfg
		site: site
		engine: template.new()
		output_dir: output_dir
		theme_root: theme_root
		template_root: template_root
		pipeline: assets.new(asset_root, output_dir, cfg.base_url)
	}
	r.engine.add_root(template_root)
	// Themes may reuse partials from `themes/_shared/templates/`; the
	// theme's own root takes precedence (added first), the shared root is
	// the fallback.
	shared_template_root := os.join_path(cfg.root, 'themes', '_shared', 'templates')
	if os.is_dir(shared_template_root) {
		r.engine.add_root(shared_template_root)
	}
	r.register_filters()
	// Wipe before the asset pipeline writes — otherwise we'd erase the
	// freshly-fingerprinted bundles below in build().
	r.wipe_output_dir()!
	os.mkdir_all(r.output_dir)!
	r.bundle_assets()!
	return r
}

fn (mut r Renderer) register_filters() {
	base := r.cfg.base_url.trim_right('/')
	r.engine.register_filter('relurl', fn (v template.Value, args []template.Value) !template.Value {
		s := template.to_string(v)
		if s.starts_with('http://') || s.starts_with('https://') {
			return template.Value(s)
		}
		path := if s.starts_with('/') { s } else { '/' + s }
		return template.Value(path)
	})
	r.engine.register_filter('absurl', fn [base] (v template.Value, args []template.Value) !template.Value {
		s := template.to_string(v)
		if s.starts_with('http://') || s.starts_with('https://') {
			return template.Value(s)
		}
		path := if s.starts_with('/') { s } else { '/' + s }
		return template.Value(base + path)
	})
	md_opts := mdrender.Options{
		base_url: r.cfg.base_url
	}
	r.engine.register_filter('markdownify', fn [md_opts] (v template.Value, args []template.Value) !template.Value {
		s := template.to_string(v)
		html := mdrender.render(s, md_opts)
		return template.Value(template.SafeString{
			value: html
		})
	})
}

fn (mut r Renderer) bundle_assets() ! {
	// CSS bundle: fonts.css + style.css → bundle.<hash>.css.
	fonts := r.pipeline.get('css/fonts.css')!
	style := r.pipeline.get('css/style.css')!
	mut css := r.pipeline.concat('css/bundle.css', [fonts, style])!
	css = r.pipeline.fingerprint(css)!
	r.pipeline.realise(css)!
	// JS bundle: shared modules from `themes/_shared/js/` (alphabetical) +
	// the theme's own `js/app.js`. Shared comes first so theme code can
	// rely on the helpers being initialised. Resolved through a Pipeline
	// rooted at `_shared/assets`, separate from the theme pipeline.
	mut js_parts := []&assets.Resource{}
	shared_js_root := os.join_path(r.cfg.root, 'themes', '_shared', 'assets')
	if os.is_dir(os.join_path(shared_js_root, 'js')) {
		mut shared_pipeline := assets.new(shared_js_root, r.output_dir, r.cfg.base_url)
		mut names := os.ls(os.join_path(shared_js_root, 'js')) or { []string{} }
		names.sort()
		for name in names {
			if !name.ends_with('.js') {
				continue
			}
			js_parts << shared_pipeline.get('js/${name}')!
		}
	}
	js_parts << r.pipeline.get('js/app.js')!
	mut js := r.pipeline.concat('js/app.js', js_parts)!
	js = r.pipeline.fingerprint(js)!
	r.pipeline.realise(js)!
	r.asset_ctx['css_url'] = template.Value(css.rel_url())
	r.asset_ctx['css_integrity'] = template.Value(css.integrity)
	r.asset_ctx['js_url'] = template.Value(js.rel_url())
	r.asset_ctx['js_integrity'] = template.Value(js.integrity)
}

// build renders every page to disk and returns the number of files written.
// `new()` already wiped `output_dir` and bundled assets — this just emits
// pages, copies static, writes 404/sitemap/RSS.
pub fn (mut r Renderer) build() !int {
	site_obj := r.site.as_template_object()
	mut count := 0
	for p in r.site.pages {
		out_path := r.output_path_for(p)
		html := r.render_page(p, site_obj) or { return error('render: ${p.source_path}: ${err}') }
		os.mkdir_all(os.dir(out_path))!
		r.write_page_md(p, out_path)!
		os.write_file(out_path, html)!
		count++
	}
	r.copy_static()!
	r.write_404(site_obj)!
	r.render_extras(site_obj)!
	r.write_llms_index()!
	return count
}

fn (r &Renderer) output_path_for(p &content.Page) string {
	rel := p.rel_permalink.trim_left('/').trim_right('/')
	if rel == '' {
		return os.join_path(r.output_dir, 'index.html')
	}
	return os.join_path(r.output_dir, rel, 'index.html')
}

fn (mut r Renderer) render_page(p &content.Page, site_obj template.Object) !string {
	mut ctx := r.base_context(site_obj)
	ctx['page'] = template.Value(p.as_template_object())
	template_name := r.template_name_for(p)
	return r.engine.render_template(template_name, ctx)
}

fn (r &Renderer) base_context(site_obj template.Object) map[string]template.Value {
	mut ctx := map[string]template.Value{}
	ctx['site'] = template.Value(site_obj)
	ctx['assets'] = template.Value(r.asset_ctx)
	ctx['config'] = template.Value(content.yaml_to_template_map(r.cfg.params))
	ctx['now'] = template.Value(now_object())
	return ctx
}

fn now_object() template.Object {
	captured := time.now()
	return template.Object{
		name: 'now'
		getter: fn [captured] (field string) ?template.Value {
			match field {
				'year' {
					return template.Value(i64(captured.year))
				}
				'month' {
					return template.Value(i64(captured.month))
				}
				'day' {
					return template.Value(i64(captured.day))
				}
				'unix' {
					return template.Value(captured.unix())
				}
				else {
					return none
				}
			}}
	}
}

fn (r &Renderer) template_name_for(p &content.Page) string {
	if p.is_home {
		if r.template_exists('index.html') {
			return 'index.html'
		}
	}
	if p.is_section {
		section_list := os.join_path(p.section, 'list.html')
		if r.template_exists(section_list) {
			return section_list
		}
		if r.template_exists('_default/list.html') {
			return '_default/list.html'
		}
	}
	if p.layout != '' {
		custom := os.join_path('_default', p.layout + '.html')
		if r.template_exists(custom) {
			return custom
		}
	}
	if p.section != '' {
		section_single := os.join_path(p.section, 'single.html')
		if r.template_exists(section_single) {
			return section_single
		}
	}
	return '_default/single.html'
}

fn (r &Renderer) template_exists(name string) bool {
	return os.exists(os.join_path(r.template_root, name))
}

fn (r &Renderer) wipe_output_dir() ! {
	if !os.exists(r.output_dir) {
		return
	}
	ensure_safe_to_wipe(r.output_dir, r.cfg.root)!
	os.rmdir_all(r.output_dir) or { return error('render: cannot wipe ${r.output_dir} (${err})') }
}

// assert_output_under_root requires `output_dir` to live strictly under
// `root` (allowlist). Canonicalises both sides syntactically with
// `os.norm_path` (so `-o ../escape` and `-o foo/../../escape` are caught)
// and through `os.real_path` (so a symlink pointing outside the project is
// also caught when the target exists). Used by `verne build`, `verne
// server`, and `verne clean` so a CLI `-o` override cannot point at the
// user's home, `/etc`, or the project root itself.
pub fn assert_output_under_root(output_dir string, root string) ! {
	out_norm := canonical(output_dir)
	root_norm := canonical(root)
	if root_norm == '' || root_norm == '/' {
		return error('refusing output `${output_dir}` — project root resolves to `${root_norm}`')
	}
	if out_norm == '' {
		return error('refusing output `${output_dir}` — does not resolve to a real path')
	}
	if out_norm == root_norm {
		return error('refusing output `${out_norm}` — equals project root')
	}
	if !out_norm.starts_with(root_norm + '/') {
		return error('refusing output `${out_norm}` — outside project root `${root_norm}`')
	}
}

// canonical produces a stable absolute path for prefix comparisons:
// `os.norm_path` collapses `..` / `.` syntactically, then we walk the
// longest existing prefix through `os.real_path` so a symlink hidden inside
// the project (e.g. `output -> /etc`) is resolved before the bounds check.
// On platforms where `realpath()` refuses non-existent leaves, this avoids
// the asymmetry of one side (the project root, which exists) being
// symlink-resolved while the other side (a yet-to-be-created output dir)
// is not, which would otherwise produce a false negative.
fn canonical(p string) string {
	normed := os.norm_path(p)
	if os.exists(normed) {
		return os.real_path(normed).trim_right('/')
	}
	mut prefix := normed
	mut suffix := ''
	for prefix != '' && prefix != '/' && !os.exists(prefix) {
		parent := os.dir(prefix)
		base := os.base(prefix)
		suffix = if suffix == '' { base } else { os.join_path(base, suffix) }
		if parent == prefix {
			break
		}
		prefix = parent
	}
	resolved_prefix := if prefix != '' && os.exists(prefix) {
		os.real_path(prefix)
	} else {
		prefix
	}
	joined := if suffix == '' { resolved_prefix } else { os.join_path(resolved_prefix, suffix) }
	return joined.trim_right('/')
}

// ensure_safe_to_wipe combines `assert_output_under_root` with a source-tree
// marker check, so even an in-root path that happens to look like content
// (e.g. `output_dir: content`) refuses to be wiped.
pub fn ensure_safe_to_wipe(output_dir string, root string) ! {
	assert_output_under_root(output_dir, root)!
	out_real := os.real_path(output_dir)
	for marker in ['content', 'themes', '.git', 'verne.yaml'] {
		if os.exists(os.join_path(out_real, marker)) {
			return error('refusing to wipe `${out_real}` — looks like a source tree (contains `${marker}`)')
		}
	}
}

fn (r &Renderer) copy_static() ! {
	candidates := [
		os.join_path(r.cfg.root, 'static'),
		os.join_path(r.theme_root, 'static'),
	]
	for src_dir in candidates {
		if !os.exists(src_dir) {
			continue
		}
		copy_dir(src_dir, r.output_dir)!
	}
}

fn copy_dir(src string, dst string) ! {
	for entry in os.ls(src)! {
		s := os.join_path(src, entry)
		d := os.join_path(dst, entry)
		if os.is_dir(s) {
			os.mkdir_all(d)!
			copy_dir(s, d)!
		} else {
			os.cp(s, d)!
		}
	}
}

fn (mut r Renderer) write_404(site_obj template.Object) ! {
	if !r.template_exists('404.html') {
		return
	}
	mut ctx := r.base_context(site_obj)
	// synthesise a minimal 404 page
	dummy := &content.Page{
		title: '404 Page not found'
		description: 'This page does not exist.'
		section: ''
		base_filename: '404'
	}
	ctx['page'] = template.Value(dummy.as_template_object())
	body := r.engine.render_template('404.html', ctx)!
	os.write_file(os.join_path(r.output_dir, '404.html'), body)!
}
