// Built-in filters. The set is intentionally small and display-oriented:
// no `filter`, `sort`, `group_by` (those compute — pre-compute in V instead).
module template

import strings
import time

fn register_builtins(mut e Engine) {
	e.register_filter('escape', fn_escape)
	e.register_filter('safe', fn_safe)
	e.register_filter('lower', fn_lower)
	e.register_filter('upper', fn_upper)
	e.register_filter('trim', fn_trim)
	e.register_filter('truncate', fn_truncate)
	e.register_filter('default', fn_default)
	e.register_filter('length', fn_length)
	e.register_filter('slugify', fn_slugify)
	e.register_filter('urlencode', fn_urlencode)
	e.register_filter('relurl', fn_relurl_passthrough)
	e.register_filter('absurl', fn_absurl_passthrough)
	e.register_filter('plainify', fn_plainify)
	e.register_filter('format_date', fn_format_date)
	e.register_filter('format_number', fn_format_number)
	e.register_filter('printf', fn_printf)
	e.register_filter('join', fn_join)
	e.register_filter('replace', fn_replace)
	e.register_filter('split', fn_split)
	e.register_filter('jsonify', fn_jsonify)
}

fn fn_escape(v Value, _ []Value) !Value {
	return Value(html_escape(to_string(v)))
}

fn fn_safe(v Value, _ []Value) !Value {
	return Value(SafeString{
		value: to_string(v)
	})
}

fn fn_lower(v Value, _ []Value) !Value {
	return Value(to_string(v).to_lower())
}

fn fn_upper(v Value, _ []Value) !Value {
	return Value(to_string(v).to_upper())
}

fn fn_trim(v Value, _ []Value) !Value {
	return Value(to_string(v).trim_space())
}

fn fn_truncate(v Value, args []Value) !Value {
	if args.len == 0 {
		return error('truncate: missing length argument')
	}
	n := must_int(args[0])!
	s := to_string(v)
	if s.len <= n {
		return Value(s)
	}
	return Value(s[..n] + '…')
}

fn fn_default(v Value, args []Value) !Value {
	if args.len == 0 {
		return error('default: missing fallback argument')
	}
	if is_empty(v) {
		return args[0]
	}
	return v
}

fn fn_length(v Value, _ []Value) !Value {
	return Value(i64(length(v)))
}

fn fn_slugify(v Value, _ []Value) !Value {
	s := to_string(v).to_lower()
	mut b := strings.new_builder(s.len)
	mut last_dash := true
	for c in s {
		if (c >= `a` && c <= `z`) || (c >= `0` && c <= `9`) {
			b.write_u8(c)
			last_dash = false
		} else if !last_dash {
			b.write_u8(`-`)
			last_dash = true
		}
	}
	mut out := b.str()
	if out.ends_with('-') {
		out = out[..out.len - 1]
	}
	return Value(out)
}

fn fn_urlencode(v Value, _ []Value) !Value {
	s := to_string(v)
	mut b := strings.new_builder(s.len)
	for c in s {
		if (c >= `a` && c <= `z`) || (c >= `A` && c <= `Z`) || (c >= `0` && c <= `9`)
			|| c == `-` || c == `_` || c == `.` || c == `~` {
			b.write_u8(c)
		} else {
			b.write_string('%${c:02X}')
		}
	}
	return Value(b.str())
}

// relurl/absurl are placeholders — the engine doesn't know base_url. The
// renderer wraps these to inject the real prefix; the default just returns
// the input unchanged.
fn fn_relurl_passthrough(v Value, _ []Value) !Value {
	return Value(to_string(v))
}

fn fn_absurl_passthrough(v Value, _ []Value) !Value {
	return Value(to_string(v))
}

fn fn_plainify(v Value, _ []Value) !Value {
	s := to_string(v)
	mut b := strings.new_builder(s.len)
	mut in_tag := false
	for c in s {
		match c {
			`<` {
				in_tag = true
			}
			`>` {
				in_tag = false
			}
			else {
				if !in_tag {
					b.write_u8(c)
				}
			}
		}
	}
	return Value(b.str())
}

fn fn_format_date(v Value, args []Value) !Value {
	if args.len == 0 {
		return error('format_date: missing layout argument')
	}
	layout := to_string(args[0])
	t := match v {
		DateValue { v.t }
		else { return error('format_date: expected date, got ${type_name(v)}') }
	}

	return Value(format_go(t, layout))
}

fn fn_format_number(v Value, _ []Value) !Value {
	n := must_int(v)!
	mut s := n.str()
	if s.starts_with('-') {
		return Value('-' + thousand_sep(s[1..]))
	}
	return Value(thousand_sep(s))
}

fn thousand_sep(s string) string {
	if s.len <= 3 {
		return s
	}
	mut out := ''
	mut i := s.len
	for i > 3 {
		out = ',' + s[i - 3..i] + out
		i -= 3
	}
	return s[..i] + out
}

fn fn_printf(v Value, args []Value) !Value {
	if args.len == 0 {
		return error('printf: missing format string')
	}
	fmt := to_string(args[0])
	// The "value" itself is treated as the first positional argument when
	// the call is `value | printf("fmt")`; if the call is `printf("fmt", x, y)`
	// then value == args[1]/args[2]/...
	mut all_args := []Value{cap: args.len}
	if v !is NoneValue {
		all_args << v
	}
	for i := 1; i < args.len; i++ {
		all_args << args[i]
	}
	return Value(printf_format(fmt, all_args))
}

fn printf_format(fmt string, args []Value) string {
	mut b := strings.new_builder(fmt.len)
	mut i := 0
	mut ai := 0
	for i < fmt.len {
		c := fmt[i]
		if c != `%` || i + 1 >= fmt.len {
			b.write_u8(c)
			i++
			continue
		}
		// scan flags, width.
		mut spec_end := i + 1
		for spec_end < fmt.len {
			cc := fmt[spec_end]
			if (cc >= `0` && cc <= `9`) || cc == `-` || cc == `+` || cc == ` `
				|| cc == `0` || cc == `.` || cc == `#` {
				spec_end++
				continue
			}
			break
		}
		if spec_end >= fmt.len {
			b.write_u8(c)
			i++
			continue
		}
		verb := fmt[spec_end]
		spec := fmt[i + 1..spec_end]
		if verb == `%` {
			b.write_u8(`%`)
			i = spec_end + 1
			continue
		}
		if ai >= args.len {
			b.write_string(fmt[i..spec_end + 1])
			i = spec_end + 1
			continue
		}
		arg := args[ai]
		ai++
		match verb {
			`s` {
				b.write_string(to_string(arg))
			}
			`d` {
				if arg is i64 {
					formatted := apply_int_spec(spec, arg)
					b.write_string(formatted)
				} else {
					b.write_string(to_string(arg))
				}
			}
			`v` {
				b.write_string(to_string(arg))
			}
			else {
				b.write_string(to_string(arg))
			}
		}

		i = spec_end + 1
	}
	return b.str()
}

fn apply_int_spec(spec string, n i64) string {
	if spec.starts_with('0') && spec.len > 1 {
		// zero-padded width.
		width := spec[1..].int()
		s := n.str()
		neg := s.starts_with('-')
		body := if neg { s[1..] } else { s }
		if body.len >= width {
			return s
		}
		pad := '0'.repeat(width - body.len)
		return if neg { '-' + pad + body } else { pad + body }
	}
	return n.str()
}

fn fn_join(v Value, args []Value) !Value {
	sep := if args.len > 0 { to_string(args[0]) } else { '' }
	if v is []Value {
		mut parts := []string{cap: v.len}
		for el in v {
			parts << to_string(el)
		}
		return Value(parts.join(sep))
	}
	return error('join: expected list, got ${type_name(v)}')
}

fn fn_replace(v Value, args []Value) !Value {
	if args.len < 2 {
		return error('replace: expected (old, new)')
	}
	return Value(to_string(v).replace(to_string(args[0]), to_string(args[1])))
}

fn fn_split(v Value, args []Value) !Value {
	if args.len == 0 {
		return error('split: missing separator')
	}
	parts := to_string(v).split(to_string(args[0]))
	mut out := []Value{cap: parts.len}
	for p in parts {
		out << Value(p)
	}
	return Value(out)
}

fn fn_jsonify(v Value, _ []Value) !Value {
	return Value(SafeString{
		value: jsonify(v)
	})
}

// jsonify serialises a Value to compact JSON.
pub fn jsonify(v Value) string {
	return jsonify_inner(v, '', '')
}

// jsonify_pretty serialises with the given indent string (e.g. '  ') for
// human-readable JSON-LD output.
pub fn jsonify_pretty(v Value, indent string) string {
	return jsonify_inner(v, indent, '')
}

fn jsonify_inner(v Value, indent string, current string) string {
	pretty := indent != ''
	next := current + indent
	return match v {
		string {
			json_string(v)
		}
		SafeString {
			json_string(v.value)
		}
		i64 {
			v.str()
		}
		bool {
			v.str()
		}
		NoneValue {
			'null'
		}
		[]Value {
			if v.len == 0 {
				'[]'
			} else {
				mut parts := []string{cap: v.len}
				for el in v {
					parts << if pretty {
						'${next}${jsonify_inner(el, indent, next)}'
					} else {
						jsonify_inner(el, indent, next)
					}
				}
				if pretty {
					'[\n' + parts.join(',\n') + '\n${current}]'
				} else {
					'[' + parts.join(',') + ']'
				}
			}
		}
		map[string]Value {
			if v.len == 0 {
				'{}'
			} else {
				mut keys := v.keys()
				keys.sort()
				mut parts := []string{cap: keys.len}
				for k in keys {
					val := v[k] or { Value('') }
					sep := if pretty { ': ' } else { ':' }
					parts << if pretty {
						'${next}${json_string(k)}${sep}${jsonify_inner(val, indent, next)}'
					} else {
						'${json_string(k)}${sep}${jsonify_inner(val, indent, next)}'
					}
				}
				if pretty {
					'{\n' + parts.join(',\n') + '\n${current}}'
				} else {
					'{' + parts.join(',') + '}'
				}
			}
		}
		else {
			'"<object>"'
		}
	}
}

fn json_string(s string) string {
	mut b := strings.new_builder(s.len + 2)
	b.write_u8(`"`)
	for c in s {
		match c {
			`"` {
				b.write_string('\\"')
			}
			`\\` {
				b.write_string('\\\\')
			}
			`\n` {
				b.write_string('\\n')
			}
			`\r` {
				b.write_string('\\r')
			}
			`\t` {
				b.write_string('\\t')
			}
			else {
				if c < 0x20 {
					b.write_string('\\u${c:04x}')
				} else {
					b.write_u8(c)
				}
			}
		}
	}
	b.write_u8(`"`)
	return b.str()
}

fn must_int(v Value) !int {
	if v is i64 {
		return int(v)
	}
	if v is string {
		return v.int()
	}
	return error('expected integer, got ${type_name(v)}')
}

// format_go: minimal Go-style date formatter (the subset used by themes).
// Layouts use the Go reference time `Mon Jan 2 15:04:05 MST 2006`.
fn format_go(t time.Time, layout string) string {
	mut out := strings.new_builder(layout.len)
	mut i := 0
	for i < layout.len {
		if i + 7 <= layout.len && layout[i..i + 7] == 'January' {
			out.write_string(month_full[t.month - 1])
			i += 7
			continue
		}
		if i + 6 <= layout.len && layout[i..i + 6] == 'Monday' {
			out.write_string(day_full[(t.day_of_week() - 1 + 7) % 7])
			i += 6
			continue
		}
		if i + 6 <= layout.len && layout[i..i + 6] == 'Z07:00' {
			out.write_string('Z')
			i += 6
			continue
		}
		if i + 5 <= layout.len && layout[i..i + 5] == '-0700' {
			out.write_string('+0000')
			i += 5
			continue
		}
		if i + 4 <= layout.len && layout[i..i + 4] == '2006' {
			out.write_string(t.year.str())
			i += 4
			continue
		}
		if i + 3 <= layout.len {
			tok3 := layout[i..i + 3]
			match tok3 {
				'Mon' {
					out.write_string(day_short[(t.day_of_week() - 1 + 7) % 7])
					i += 3
					continue
				}
				'Jan' {
					out.write_string(month_short[t.month - 1])
					i += 3
					continue
				}
				'MST' {
					out.write_string('UTC')
					i += 3
					continue
				}
				else {}
			}
		}
		if i + 2 <= layout.len {
			tok2 := layout[i..i + 2]
			match tok2 {
				'06' {
					out.write_string('${t.year % 100:02d}')
					i += 2
					continue
				}
				'01' {
					out.write_string('${t.month:02d}')
					i += 2
					continue
				}
				'02' {
					out.write_string('${t.day:02d}')
					i += 2
					continue
				}
				'15' {
					out.write_string('${t.hour:02d}')
					i += 2
					continue
				}
				'04' {
					out.write_string('${t.minute:02d}')
					i += 2
					continue
				}
				'05' {
					out.write_string('${t.second:02d}')
					i += 2
					continue
				}
				else {}
			}
		}
		c := layout[i]
		match c {
			`1` {
				out.write_string(t.month.str())
				i++
				continue
			}
			`2` {
				out.write_string(t.day.str())
				i++
				continue
			}
			else {}
		}

		out.write_u8(c)
		i++
	}
	return out.str()
}

const month_short = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov',
	'Dec']!

const month_full = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August',
	'September', 'October', 'November', 'December']!

const day_short = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']!

const day_full = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday']!
