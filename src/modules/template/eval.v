// Evaluator: walks AST against a Scope chain, writes output into a strings.Builder.
module template

import strings

@[heap]
pub struct Scope {
pub mut:
	vars   map[string]Value
	parent &Scope = unsafe { nil }
}

// new_scope creates a root scope seeded with the given variables.
pub fn new_scope(vars map[string]Value) &Scope {
	return &Scope{
		vars:   vars.clone()
		parent: unsafe { nil }
	}
}

fn (s &Scope) lookup(name string) ?Value {
	if v := s.vars[name] {
		return v
	}
	if !isnil(s.parent) {
		return s.parent.lookup(name)
	}
	return none
}

fn child_scope(parent &Scope) &Scope {
	return &Scope{
		vars:   map[string]Value{}
		parent: unsafe { parent }
	}
}

fn (mut e Engine) eval_body(nodes []Node, scope &Scope, mut out strings.Builder) ! {
	for n in nodes {
		e.eval_node(n, scope, mut out)!
	}
}

fn (mut e Engine) eval_node(n Node, scope &Scope, mut out strings.Builder) ! {
	match n {
		TextNode {
			out.write_string(n.text)
		}
		OutputNode {
			v := e.eval_expr(n.expr, scope) or {
				return error('${err.msg()} (at ${n.line}:${n.col})')
			}
			out.write_string(render_value(v))
		}
		IfNode {
			mut matched := false
			for br in n.branches {
				cond := e.eval_expr(br.cond, scope)!
				if truthy(cond) {
					mut child := child_scope(scope)
					e.eval_body(br.body, child, mut out)!
					matched = true
					break
				}
			}
			if !matched {
				mut child := child_scope(scope)
				e.eval_body(n.else_body, child, mut out)!
			}
		}
		ForNode {
			src := e.eval_expr(n.source, scope)!
			match src {
				[]Value {
					for i, item in src {
						mut child := child_scope(scope)
						child.vars[n.val_var] = item
						if n.key_var.len > 0 {
							child.vars[n.key_var] = Value(i64(i))
						}
						child.vars['loop'] = Value(loop_object(i, src.len))
						e.eval_body(n.body, child, mut out)!
					}
				}
				map[string]Value {
					mut keys := src.keys()
					keys.sort()
					for i, k in keys {
						v := src[k] or { Value('') }
						mut child := child_scope(scope)
						if n.key_var.len > 0 {
							child.vars[n.key_var] = Value(k)
							child.vars[n.val_var] = v
						} else {
							child.vars[n.val_var] = Value(k)
						}
						child.vars['loop'] = Value(loop_object(i, keys.len))
						e.eval_body(n.body, child, mut out)!
					}
				}
				NoneValue {}
				else {
					return error('for: cannot iterate over ${type_name(src)}')
				}
			}
		}
		WithNode {
			v := e.eval_expr(n.source, scope)!
			mut child := child_scope(scope)
			child.vars[n.name] = v
			e.eval_body(n.body, child, mut out)!
		}
		IncludeNode {
			body := e.load_template(n.path)!
			sub_nodes := parse(body) or { return error('parse include "${n.path}": ${err}') }
			mut child := child_scope(scope)
			e.eval_body(sub_nodes, child, mut out) or {
				return error('eval include "${n.path}": ${err}')
			}
		}
		ShortcodeNode {
			e.eval_shortcode(n, scope, mut out)!
		}
	}
}

fn (mut e Engine) eval_shortcode(n ShortcodeNode, scope &Scope, mut out strings.Builder) ! {
	mut args := map[string]Value{}
	for a in n.args {
		args[a.name] = e.eval_expr(a.value, scope)!
	}
	mut body_str := ''
	if n.body.len > 0 {
		mut sub := strings.new_builder(64)
		e.eval_body(n.body, scope, mut sub)!
		body_str = sub.str()
	}
	page := scope.lookup('page') or { Value(none_value) }
	site := scope.lookup('site') or { Value(none_value) }
	ctx := ShortcodeContext{
		body: body_str
		page: page
		site: site
	}
	if f := e.shortcodes[n.name] {
		result := f(ctx, args) or {
			return error('shortcode "${n.name}": ${err.msg()} (at ${n.line}:${n.col})')
		}
		out.write_string(result)
		return
	}
	// Fallback: HTML shortcode in templates/shortcodes/<name>.html.
	tpl_name := 'shortcodes/${n.name}.html'
	src := e.load_template(tpl_name) or {
		return error('unknown shortcode "${n.name}" (at ${n.line}:${n.col})')
	}
	mut sub := strings.new_builder(src.len)
	mut child := child_scope(scope)
	child.vars['args'] = Value(args)
	child.vars['body'] = Value(SafeString{
		value: body_str
	})
	sub_nodes := parse(src)!
	e.eval_body(sub_nodes, child, mut sub)!
	out.write_string(sub.str())
}

fn (mut e Engine) eval_expr(ex Expr, scope &Scope) !Value {
	match ex {
		StringLit {
			return Value(ex.value)
		}
		IntLit {
			return Value(ex.value)
		}
		BoolLit {
			return Value(ex.value)
		}
		NoneLit {
			return none_value
		}
		VarRef {
			return scope.lookup(ex.name) or {
				return error('variable "${ex.name}" is undefined (at ${ex.line}:${ex.col})')
			}
		}
		FieldAccess {
			base := e.eval_expr(ex.base, scope)!
			return access_field(base, ex.field) or {
				return error('field "${ex.field}" not found on ${type_name(base)}')
			}
		}
		IndexAccess {
			base := e.eval_expr(ex.base, scope)!
			idx := e.eval_expr(ex.idx, scope)!
			return access_index(base, idx)!
		}
		FuncCall {
			mut args := []Value{cap: ex.args.len}
			for a in ex.args {
				args << e.eval_expr(a, scope)!
			}
			return e.call_filter_or_func(ex.name, args, none_value, false)
		}
		FilterCall {
			base := e.eval_expr(ex.base, scope)!
			mut args := []Value{cap: ex.args.len}
			for a in ex.args {
				args << e.eval_expr(a, scope)!
			}
			return e.call_filter_or_func(ex.name, args, base, true)
		}
		Compare {
			l := e.eval_expr(ex.left, scope)!
			r := e.eval_expr(ex.right, scope)!
			return Value(do_compare(l, r, ex.op))
		}
		LogicAnd {
			l := e.eval_expr(ex.left, scope)!
			if !truthy(l) {
				return Value(false)
			}
			r := e.eval_expr(ex.right, scope)!
			return Value(truthy(r))
		}
		LogicOr {
			l := e.eval_expr(ex.left, scope)!
			if truthy(l) {
				return Value(true)
			}
			r := e.eval_expr(ex.right, scope)!
			return Value(truthy(r))
		}
		LogicNot {
			v := e.eval_expr(ex.inner, scope)!
			return Value(!truthy(v))
		}
		IsTest {
			r := e.eval_is(ex, scope)!
			final := if ex.negate { !r } else { r }
			return Value(final)
		}
		InTest {
			needle := e.eval_expr(ex.value, scope)!
			haystack := e.eval_expr(ex.list, scope)!
			match haystack {
				[]Value {
					for el in haystack {
						if equals(needle, el) {
							return Value(true)
						}
					}
					return Value(false)
				}
				string {
					if needle is string {
						return Value(haystack.contains(needle))
					}
					return Value(false)
				}
				else {
					return Value(false)
				}
			}
		}
	}
}

fn (mut e Engine) eval_is(ex IsTest, scope &Scope) !bool {
	match ex.test {
		'defined' {
			// `is defined` is special: VarRef must be looked up gracefully.
			if ex.value is VarRef {
				_ := scope.lookup(ex.value.name) or { return false }
				return true
			}
			v := e.eval_expr(ex.value, scope) or { return false }
			return v !is NoneValue
		}
		'none' {
			v := e.eval_expr(ex.value, scope) or { return true }
			return v is NoneValue
		}
		'empty' {
			v := e.eval_expr(ex.value, scope)!
			return is_empty(v)
		}
		'string' {
			v := e.eval_expr(ex.value, scope)!
			return v is string || v is SafeString
		}
		'number' {
			v := e.eval_expr(ex.value, scope)!
			return v is i64
		}
		'list' {
			v := e.eval_expr(ex.value, scope)!
			return v is []Value
		}
		'map' {
			v := e.eval_expr(ex.value, scope)!
			return v is map[string]Value
		}
		else {
			return error('unknown test "is ${ex.test}"')
		}
	}
}

// access_field returns Value or error when the base has no such field.
// For maps and Objects we propagate the lookup; for scalars we error.
fn access_field(base Value, name string) ?Value {
	return match base {
		map[string]Value { base[name] or { none_value } }
		Object { base.get(name) or { none_value } }
		NoneValue { none_value }
		else { none }
	}
}

fn access_index(base Value, idx Value) !Value {
	if base is []Value {
		if idx is i64 {
			i := int(idx)
			if i < 0 || i >= base.len {
				return none_value
			}
			return base[i]
		}
		return error('index: list requires integer index, got ${type_name(idx)}')
	}
	if base is map[string]Value {
		if idx is string {
			return base[idx] or { none_value }
		}
		return error('index: map requires string key, got ${type_name(idx)}')
	}
	if base is Object {
		if idx is string {
			return base.get(idx) or { none_value }
		}
		return error('index: object requires string key, got ${type_name(idx)}')
	}
	return error('index: cannot index ${type_name(base)}')
}

fn do_compare(l Value, r Value, op string) bool {
	match op {
		'==' { return equals(l, r) }
		'!=' { return !equals(l, r) }
		else {}
	}

	c := compare(l, r) or { return false }
	return match op {
		'<' { c < 0 }
		'<=' { c <= 0 }
		'>' { c > 0 }
		'>=' { c >= 0 }
		else { false }
	}
}

// call_filter_or_func handles both pipe-style filters (`x | foo(arg)`) where
// `value` is `x` and `is_filter` is true, and bare function calls (`foo(arg)`).
// Functions are looked up in the same registry.
fn (mut e Engine) call_filter_or_func(name string, args []Value, value Value, is_filter bool) !Value {
	f := e.filters[name] or {
		return error('unknown ${if is_filter { 'filter' } else { 'function' }} "${name}"')
	}
	if is_filter {
		return f(value, args)
	}
	// As a free function, the first arg becomes the "value", the rest are extras.
	if args.len == 0 {
		return f(none_value, []Value{})
	}
	return f(args[0], args[1..])
}

// render_value: how a Value gets serialised into the output stream. Strings
// are HTML-escaped; SafeString passes through.
fn render_value(v Value) string {
	return match v {
		string {
			html_escape(v)
		}
		SafeString {
			v.value
		}
		bool {
			v.str()
		}
		i64 {
			v.str()
		}
		DateValue {
			v.t.format()
		}
		NoneValue {
			''
		}
		[]Value {
			mut parts := []string{cap: v.len}
			for el in v {
				parts << render_value(el)
			}
			parts.join('')
		}
		map[string]Value {
			''
		}
		Object {
			''
		}
	}
}

fn html_escape(s string) string {
	if s.index_any('&<>"\'') < 0 {
		return s
	}
	mut b := strings.new_builder(s.len + 8)
	for c in s {
		match c {
			`&` { b.write_string('&amp;') }
			`<` { b.write_string('&lt;') }
			`>` { b.write_string('&gt;') }
			`"` { b.write_string('&#34;') }
			`'` { b.write_string('&#39;') }
			else { b.write_u8(c) }
		}
	}
	return b.str()
}

fn loop_object(i int, total int) Object {
	captured_i := i64(i)
	captured_total := i64(total)
	return Object{
		name:   'loop'
		getter: fn [captured_i, captured_total] (field string) ?Value {
			match field {
				'index' { return Value(captured_i + 1) }
				'index0' { return Value(captured_i) }
				'reverse_index' { return Value(captured_total - captured_i) }
				'reverse_index0' { return Value(captured_total - captured_i - 1) }
				'first' { return Value(captured_i == 0) }
				'last' { return Value(captured_i == captured_total - 1) }
				'length' { return Value(captured_total) }
				else { return none }
			}
		}
	}
}
