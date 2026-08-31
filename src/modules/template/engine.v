// Engine: public API. Owns filter and shortcode registries, plus the
// loaded set of partials. Stateless across renders — each render call
// creates its own scope chain.
module template

import os
import strings

pub type FilterFn = fn(val Value, args []Value) !Value

pub type ShortcodeFn = fn(ctx ShortcodeContext, args map[string]Value) !string

pub struct ShortcodeContext {
pub:
	body string
	page Value
	site Value
}

@[heap]
pub struct Engine {
mut:
	filters    map[string]FilterFn
	shortcodes map[string]ShortcodeFn
	partials   map[string]string // path → source, lazily filled
	roots      []string // directories to search for `include` and shortcodes
}

// new returns a fresh engine with the built-in filters registered.
pub fn new() &Engine {
	mut e := &Engine{}
	register_builtins(mut e)
	return e
}

// add_root appends a directory the engine searches when resolving `include`
// targets and shortcode template fragments.
pub fn (mut e Engine) add_root(dir string) {
	e.roots << dir
}

// register_filter binds a filter name to its implementation, available as
// `value | name` in templates.
pub fn (mut e Engine) register_filter(name string, f FilterFn) {
	e.filters[name] = f
}

// register_shortcode binds a shortcode name to its V handler, callable as
// `{% shortcode name %}` in templates.
pub fn (mut e Engine) register_shortcode(name string, f ShortcodeFn) {
	e.shortcodes[name] = f
}

// render renders a template source string against a context map.
pub fn (mut e Engine) render(src string, ctx map[string]Value) !string {
	nodes := parse(src) or { return error('parse: ${err}') }
	mut scope := new_scope(ctx)
	mut out := strings.new_builder(src.len)
	e.eval_body(nodes, scope, mut out)!
	return out.str()
}

// render_template loads a named template from the engine's roots and renders
// it. Used for partials/layouts.
pub fn (mut e Engine) render_template(name string, ctx map[string]Value) !string {
	src := e.load_template(name)!
	nodes := parse(src) or { return error('parse "${name}": ${err}') }
	mut scope := new_scope(ctx)
	mut out := strings.new_builder(src.len)
	e.eval_body(nodes, scope, mut out) or { return error('render "${name}": ${err}') }
	return out.str()
}

fn (mut e Engine) load_template(name string) !string {
	if cached := e.partials[name] {
		return cached
	}
	for root in e.roots {
		full := os.join_path(root, name)
		if os.exists(full) {
			body := os.read_file(full)!
			e.partials[name] = body
			return body
		}
	}
	return error('template "${name}" not found in [${e.roots.join(', ')}]')
}
