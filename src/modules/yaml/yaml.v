// Module yaml is a small YAML subset parser, sufficient for Verne's needs:
// site config (`verne.yaml`) and post frontmatter.
//
// Supported:
//   - block-style maps (key: value, optionally nested via indentation)
//   - block-style lists (`- item`)
//   - scalars: bare, double-quoted, single-quoted
//   - integers and booleans (true/false/yes/no/on/off)
//   - block scalars `|` (literal, preserves newlines) and `>` (folded)
//   - comments (`#` to end of line, outside quoted strings)
//   - empty lines
//
// Not supported (deliberately):
//   - flow style ([a, b], {a: 1}) — except top-level scalar coercion
//   - anchors (&) and references (*)
//   - custom tags (!!str etc.)
//   - multi-document streams (---)
//
// All errors are returned with `path:line` context.
module yaml

import strings

pub type Value = []Value | bool | f64 | i64 | map[string]Value | string

pub fn parse(src string) !map[string]Value {
	mut p := Parser{
		lines: tokenize(src)
	}
	return p.parse_map(0)!
}

// str_or returns the value when it is a string, or `default` otherwise.
pub fn (v Value) str_or(default string) string {
	return match v {
		string { v }
		else { default }
	}
}

// as_string returns the value as a string, or none if it is another variant.
pub fn (v Value) as_string() ?string {
	return match v {
		string { v }
		else { none }
	}
}

// as_list returns the value as a list, or none if it is another variant.
pub fn (v Value) as_list() ?[]Value {
	return match v {
		[]Value { v }
		else { none }
	}
}

// as_map returns the value as a map, or none if it is another variant.
pub fn (v Value) as_map() ?map[string]Value {
	return match v {
		map[string]Value { v }
		else { none }
	}
}

struct Line {
	num     int
	indent  int
	content string
}

struct Parser {
mut:
	lines []Line
	pos   int
}

fn tokenize(src string) []Line {
	mut out := []Line{}
	mut num := 0
	for raw in src.split_into_lines() {
		num++
		stripped := strip_comment(raw)
		if stripped.trim_space() == '' {
			continue
		}
		mut indent := 0
		for c in stripped {
			if c == ` ` {
				indent++
			} else if c == `\t` {
				// treat tabs as 4 spaces; YAML technically forbids them but
				// some editors emit them. Accept silently.
				indent += 4
			} else {
				break
			}
		}
		out << Line{
			num:     num
			indent:  indent
			content: stripped[indent..]
		}
	}
	return out
}

fn strip_comment(s string) string {
	mut in_dq := false
	mut in_sq := false
	for i, c in s {
		match c {
			`"` {
				if !in_sq {
					in_dq = !in_dq
				}
			}
			`'` {
				if !in_dq {
					in_sq = !in_sq
				}
			}
			`#` {
				if !in_dq && !in_sq {
					if i == 0 || s[i - 1] == ` ` || s[i - 1] == `\t` {
						return s[..i].trim_right(' \t')
					}
				}
			}
			else {}
		}
	}
	return s.trim_right(' \t')
}

fn (mut p Parser) parse_map(min_indent int) !map[string]Value {
	mut out := map[string]Value{}
	for p.pos < p.lines.len {
		line := p.lines[p.pos]
		if line.indent < min_indent {
			break
		}
		if line.content.starts_with('- ') || line.content == '-' {
			break
		}
		colon := find_colon(line.content) or {
			return error('yaml: expected key: value at line ${line.num}: "${line.content}"')
		}
		key := unquote(line.content[..colon].trim_space())
		rest := line.content[colon + 1..].trim_space()
		p.pos++
		if rest == '|' || rest == '|-' || rest == '|+' {
			out[key] = Value(parse_block_scalar(mut p, line.indent, true))
		} else if rest == '>' || rest == '>-' || rest == '>+' {
			out[key] = Value(parse_block_scalar(mut p, line.indent, false))
		} else if rest == '' {
			// nested map or list
			if p.pos < p.lines.len && p.lines[p.pos].indent > line.indent {
				next := p.lines[p.pos]
				if next.content.starts_with('- ') || next.content == '-' {
					out[key] = Value(p.parse_list(next.indent)!)
				} else {
					out[key] = Value(p.parse_map(next.indent)!)
				}
			} else {
				out[key] = Value('')
			}
		} else {
			out[key] = scalar(rest)
		}
	}
	return out
}

fn (mut p Parser) parse_list(min_indent int) ![]Value {
	mut out := []Value{}
	for p.pos < p.lines.len {
		line := p.lines[p.pos]
		if line.indent < min_indent {
			break
		}
		if line.indent > min_indent {
			return error('yaml: unexpected indent at line ${line.num}')
		}
		if !(line.content.starts_with('- ') || line.content == '-') {
			break
		}
		rest := if line.content == '-' { '' } else { line.content[2..].trim_space() }
		p.pos++
		if rest == '' {
			if p.pos < p.lines.len && p.lines[p.pos].indent > line.indent {
				next := p.lines[p.pos]
				if next.content.starts_with('- ') || next.content == '-' {
					out << Value(p.parse_list(next.indent)!)
				} else {
					out << Value(p.parse_map(next.indent)!)
				}
			} else {
				out << Value('')
			}
		} else if find_colon(rest) != none {
			// inline map item: -<sp>key: value [more keys at deeper indent]
			fake_indent := line.indent + 2
			p.lines.insert(p.pos, Line{
				num:     line.num
				indent:  fake_indent
				content: rest
			})
			out << Value(p.parse_map(fake_indent)!)
		} else {
			out << scalar(rest)
		}
	}
	return out
}

fn parse_block_scalar(mut p Parser, parent_indent int, literal bool) string {
	mut buf := strings.new_builder(64)
	mut base := -1
	mut first := true
	for p.pos < p.lines.len {
		line := p.lines[p.pos]
		if line.indent <= parent_indent {
			break
		}
		if base == -1 {
			base = line.indent
		}
		piece := ' '.repeat(line.indent - base) + line.content
		if first {
			first = false
		} else if literal {
			buf.write_string('\n')
		} else {
			buf.write_string(' ')
		}
		buf.write_string(piece)
		p.pos++
	}
	if literal {
		buf.write_string('\n')
	}
	return buf.str()
}

fn find_colon(s string) ?int {
	mut in_dq := false
	mut in_sq := false
	for i, c in s {
		match c {
			`"` {
				if !in_sq {
					in_dq = !in_dq
				}
			}
			`'` {
				if !in_dq {
					in_sq = !in_sq
				}
			}
			`:` {
				if !in_dq && !in_sq {
					if i + 1 == s.len || s[i + 1] == ` ` || s[i + 1] == `\t` {
						return i
					}
				}
			}
			else {}
		}
	}
	return none
}

fn scalar(raw string) Value {
	s := raw.trim_space()
	if s.len == 0 {
		return Value('')
	}
	if s.len >= 2 && s[0] == `"` && s[s.len - 1] == `"` {
		return Value(unquote_double(s[1..s.len - 1]))
	}
	if s.len >= 2 && s[0] == `'` && s[s.len - 1] == `'` {
		return Value(s[1..s.len - 1].replace("''", "'"))
	}
	lower := s.to_lower()
	match lower {
		'true', 'yes', 'on' { return Value(true) }
		'false', 'no', 'off' { return Value(false) }
		'null', '~' { return Value('') }
		else {}
	}

	if i := try_int(s) {
		return Value(i)
	}
	if f := try_float(s) {
		return Value(f)
	}
	return Value(s)
}

fn unquote(s string) string {
	if s.len >= 2 && s[0] == `"` && s[s.len - 1] == `"` {
		return unquote_double(s[1..s.len - 1])
	}
	if s.len >= 2 && s[0] == `'` && s[s.len - 1] == `'` {
		return s[1..s.len - 1].replace("''", "'")
	}
	return s
}

fn unquote_double(s string) string {
	mut out := strings.new_builder(s.len)
	mut i := 0
	for i < s.len {
		c := s[i]
		if c == `\\` && i + 1 < s.len {
			n := s[i + 1]
			match n {
				`n` {
					out.write_string('\n')
				}
				`t` {
					out.write_string('\t')
				}
				`r` {
					out.write_string('\r')
				}
				`"` {
					out.write_string('"')
				}
				`\\` {
					out.write_string('\\')
				}
				else {
					out.write_u8(c)
					out.write_u8(n)
				}
			}

			i += 2
		} else {
			out.write_u8(c)
			i++
		}
	}
	return out.str()
}

fn try_int(s string) ?i64 {
	if s == '' {
		return none
	}
	mut i := 0
	if s[0] == `-` || s[0] == `+` {
		if s.len == 1 {
			return none
		}
		i = 1
	}
	for ; i < s.len; i++ {
		if s[i] < `0` || s[i] > `9` {
			return none
		}
	}
	return s.i64()
}

fn try_float(s string) ?f64 {
	mut seen_dot := false
	mut seen_e := false
	mut i := 0
	if s == '' {
		return none
	}
	if s[0] == `-` || s[0] == `+` {
		i = 1
	}
	if i == s.len {
		return none
	}
	for ; i < s.len; i++ {
		c := s[i]
		if c >= `0` && c <= `9` {
			continue
		}
		if c == `.` && !seen_dot && !seen_e {
			seen_dot = true
			continue
		}
		if (c == `e` || c == `E`) && !seen_e {
			seen_e = true
			if i + 1 < s.len && (s[i + 1] == `+` || s[i + 1] == `-`) {
				i++
			}
			continue
		}
		return none
	}
	if !seen_dot && !seen_e {
		return none
	}
	return s.f64()
}
