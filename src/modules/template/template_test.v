module template

fn render(src string, ctx map[string]template.Value) string {
	mut e := new()
	return e.render(src, ctx) or { panic(err) }
}

fn test_text_passthrough() {
	assert render('hello', map[string]Value{}) == 'hello'
}

fn test_simple_var() {
	mut ctx := map[string]Value{}
	ctx['name'] = Value('world')
	assert render('hello {{ name }}', ctx) == 'hello world'
}

fn test_html_escape_default() {
	mut ctx := map[string]Value{}
	ctx['x'] = Value('<a>&"\'')
	assert render('{{ x }}', ctx) == '&lt;a&gt;&amp;&#34;&#39;'
}

fn test_safe_filter_skips_escape() {
	mut ctx := map[string]Value{}
	ctx['x'] = Value('<b>raw</b>')
	assert render('{{ x | safe }}', ctx) == '<b>raw</b>'
}

fn test_lower_upper() {
	mut ctx := map[string]Value{}
	ctx['s'] = Value('Hello')
	assert render('{{ s | lower }}', ctx) == 'hello'
	assert render('{{ s | upper }}', ctx) == 'HELLO'
}

fn test_default_filter() {
	mut ctx := map[string]Value{}
	ctx['empty'] = Value('')
	assert render('{{ empty | default("fallback") }}', ctx) == 'fallback'
	ctx['present'] = Value('x')
	assert render('{{ present | default("fallback") }}', ctx) == 'x'
}

fn test_if_truthy() {
	mut ctx := map[string]Value{}
	ctx['flag'] = Value(true)
	assert render('{% if flag %}yes{% else %}no{% endif %}', ctx) == 'yes'
	ctx['flag'] = Value(false)
	assert render('{% if flag %}yes{% else %}no{% endif %}', ctx) == 'no'
}

fn test_for_list() {
	mut ctx := map[string]Value{}
	ctx['xs'] = Value([Value('a'), Value('b'), Value('c')])
	assert render('{% for x in xs %}{{ x }}-{% endfor %}', ctx) == 'a-b-c-'
}

fn test_for_with_loop_index() {
	mut ctx := map[string]Value{}
	ctx['xs'] = Value([Value('a'), Value('b'), Value('c')])
	got := render('{% for x in xs %}{{ loop.index }}:{{ x }} {% endfor %}', ctx)
	assert got == '1:a 2:b 3:c '
}

fn test_for_first_last() {
	mut ctx := map[string]Value{}
	ctx['xs'] = Value([Value('a'), Value('b'), Value('c')])
	got := render('{% for x in xs %}{% if loop.first %}[{% endif %}{{ x }}{% if loop.last %}]{% endif %}{% endfor %}', ctx)
	assert got == '[abc]', got
}

fn test_with_binding() {
	mut ctx := map[string]Value{}
	ctx['n'] = Value('NAME')
	got := render('{% with x = n %}{{ x | lower }}{% endwith %}', ctx)
	assert got == 'name'
}

fn test_compare_eq() {
	mut ctx := map[string]Value{}
	ctx['s'] = Value('foo')
	assert render('{% if s == "foo" %}Y{% else %}N{% endif %}', ctx) == 'Y'
	assert render('{% if s != "foo" %}Y{% else %}N{% endif %}', ctx) == 'N'
}

fn test_is_defined() {
	ctx := map[string]Value{}
	assert render('{% if x is defined %}Y{% else %}N{% endif %}', ctx) == 'N'
}

fn test_in_membership() {
	mut ctx := map[string]Value{}
	ctx['xs'] = Value([Value('a'), Value('b')])
	assert render('{% if "a" in xs %}Y{% else %}N{% endif %}', ctx) == 'Y'
	assert render('{% if "z" in xs %}Y{% else %}N{% endif %}', ctx) == 'N'
}

fn test_truncate() {
	mut ctx := map[string]Value{}
	ctx['s'] = Value('abcdefghij')
	assert render('{{ s | truncate(4) }}', ctx) == 'abcd…'
}

fn test_slugify() {
	mut ctx := map[string]Value{}
	ctx['s'] = Value('Hello World!')
	assert render('{{ s | slugify }}', ctx) == 'hello-world'
}

fn test_join() {
	mut ctx := map[string]Value{}
	ctx['xs'] = Value([Value('a'), Value('b'), Value('c')])
	assert render('{{ xs | join(", ") }}', ctx) == 'a, b, c'
}

fn test_printf_padding() {
	mut ctx := map[string]Value{}
	ctx['n'] = Value(i64(7))
	assert render('{{ n | printf("%02d") }}', ctx) == '07'
}

fn test_field_access_on_map() {
	mut user := map[string]Value{}
	user['name'] = Value('alice')
	mut ctx := map[string]Value{}
	ctx['user'] = Value(user)
	assert render('{{ user.name }}', ctx) == 'alice'
}

fn test_field_access_on_object() {
	getter := fn (field string) ?Value {
		if field == 'title' {
			return Value('My Page')
		}
		return none
	}
	mut ctx := map[string]Value{}
	ctx['page'] = Value(Object{
		name: 'page'
		getter: getter
	})
	assert render('{{ page.title }}', ctx) == 'My Page'
}

fn test_comments_dropped() {
	assert render('a{# comment #}b', map[string]Value{}) == 'ab'
}

fn test_whitespace_control() {
	got := render('a   {{- "x" -}}   b', map[string]Value{})
	assert got == 'axb', got
}

fn test_undefined_var_errors() {
	mut e := new()
	if _ := e.render('{{ missing }}', map[string]Value{}) {
		assert false, 'expected error for undefined variable'
	} else {
		assert err.msg().contains('missing'), err.msg()
	}
}

fn test_unknown_filter_errors() {
	mut e := new()
	mut ctx := map[string]Value{}
	ctx['x'] = Value('a')
	if _ := e.render('{{ x | nope }}', ctx) {
		assert false, 'expected error for unknown filter'
	} else {
		assert err.msg().contains('nope'), err.msg()
	}
}

fn test_v_shortcode_no_body_with_args() {
	mut e := new()
	e.register_shortcode('greet', fn (ctx ShortcodeContext, args map[string]template.Value) !string {
		who := to_string(args['who'] or { Value('world') })
		return 'hello ${who}'
	})
	got := e.render('{% shortcode greet who="alice" %}', map[string]Value{}) or { panic(err) }
	assert got == 'hello alice', got
}

fn test_v_shortcode_with_body() {
	mut e := new()
	e.register_shortcode('shout', fn (ctx ShortcodeContext, args map[string]template.Value) !string {
		return '<strong>${ctx.body}</strong>'
	})
	got := e.render('{% shortcode shout %}hi{% endshortcode %}', map[string]Value{}) or {
		panic(err)
	}
	assert got == '<strong>hi</strong>', got
}

fn test_v_shortcode_args_evaluated_in_scope() {
	mut e := new()
	e.register_shortcode('echo', fn (ctx ShortcodeContext, args map[string]template.Value) !string {
		return to_string(args['msg'] or { Value('') })
	})
	mut ctx := map[string]Value{}
	ctx['name'] = Value('bob')
	got := e.render('{% shortcode echo msg=name %}', ctx) or { panic(err) }
	assert got == 'bob', got
}

fn test_html_fallback_shortcode() {
	mut e := new()
	// Pre-populate the partials cache so load_template doesn't hit disk.
	e.partials['shortcodes/note.html'] = '<aside class="note">{{ args.text }}: {{ body | safe }}</aside>'
	got := e.render('{% shortcode note text="warn" %}careful{% endshortcode %}', map[string]Value{}) or {
		panic(err)
	}
	assert got == '<aside class="note">warn: careful</aside>', got
}

fn test_v_shortcode_wins_over_html_fallback() {
	mut e := new()
	e.partials['shortcodes/dup.html'] = 'HTML version'
	e.register_shortcode('dup', fn (ctx ShortcodeContext, args map[string]template.Value) !string {
		return 'V version'
	})
	got := e.render('{% shortcode dup %}', map[string]Value{}) or { panic(err) }
	assert got == 'V version', got
}

fn test_unknown_shortcode_errors() {
	mut e := new()
	if _ := e.render('{% shortcode nope %}', map[string]Value{}) {
		assert false, 'expected error for unknown shortcode'
	} else {
		assert err.msg().contains('nope'), err.msg()
	}
}

fn test_html_fallback_shortcode_sees_body_as_safe() {
	mut e := new()
	// body is exposed as SafeString so `{{ body }}` (without `| safe`) doesn't
	// double-escape pre-rendered HTML produced inside the shortcode block.
	e.partials['shortcodes/wrap.html'] = '<div>{{ body }}</div>'
	got := e.render('{% shortcode wrap %}<b>x</b>{% endshortcode %}', map[string]Value{}) or {
		panic(err)
	}
	assert got == '<div><b>x</b></div>', got
}
