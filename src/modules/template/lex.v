// Lexer for the Verne mini-Tera dialect. Outputs a stream of tokens; the
// parser consumes them. The dialect has only two action delimiters
// (`{{ … }}` for expressions, `{% … %}` for statements) plus comments
// (`{# … #}`). Whitespace control with leading/trailing `-`.
module template

pub enum TokKind {
	text
	expr_open // {{ or {{-
	expr_close // }} or -}}
	stmt_open // {% or {%-
	stmt_close // %} or -%}
	ident
	str
	number
	dot
	comma
	pipe
	lparen
	rparen
	lbracket
	rbracket
	op_eq // ==
	op_ne // !=
	op_lt // <
	op_le // <=
	op_gt // >
	op_ge // >=
	op_assign // =
	eof
}

pub struct Tok {
pub:
	kind  TokKind
	value string
	line  int
	col   int
	// trim_left applies whitespace stripping from the previous text segment.
	trim_left  bool
	trim_right bool
}

struct Lexer {
mut:
	src              string
	pos              int
	line             int
	col              int
	in_action        bool
	trim_next_text   bool
	trim_one_newline bool
}

// lex tokenises a template source into the stream consumed by `parse`.
pub fn lex(src string) ![]Tok {
	mut l := Lexer{
		src: src
		pos: 0
		line: 1
		col: 1
	}
	mut out := []Tok{}
	for l.pos < l.src.len {
		if l.in_action {
			l.skip_ws_in_action()
			if l.pos >= l.src.len {
				return error('lex: unterminated action at ${l.line}:${l.col}')
			}
			t := l.next_action_token()!
			out << t
			if t.kind == .expr_close || t.kind == .stmt_close {
				l.in_action = false
			}
		} else {
			if l.trim_next_text {
				for l.pos < l.src.len {
					c := l.src[l.pos]
					if c == ` ` || c == `\t` || c == `\n` || c == `\r` {
						l.advance()
					} else {
						break
					}
				}
				l.trim_next_text = false
				l.trim_one_newline = false
				if l.pos >= l.src.len {
					break
				}
			}
			if l.trim_one_newline {
				if l.pos < l.src.len && l.src[l.pos] == `\r` {
					l.advance()
				}
				if l.pos < l.src.len && l.src[l.pos] == `\n` {
					l.advance()
				}
				l.trim_one_newline = false
				if l.pos >= l.src.len {
					break
				}
			}
			t := l.next_text_or_open()!
			out << t
		}
	}
	out << Tok{
		kind: .eof
		line: l.line
		col: l.col
	}
	return out
}

fn (mut l Lexer) advance() {
	if l.pos < l.src.len {
		c := l.src[l.pos]
		if c == `\n` {
			l.line++
			l.col = 1
		} else {
			l.col++
		}
		l.pos++
	}
}

fn (l &Lexer) peek(off int) u8 {
	p := l.pos + off
	if p < l.src.len {
		return l.src[p]
	}
	return 0
}

fn (mut l Lexer) skip_ws_in_action() {
	for l.pos < l.src.len {
		c := l.src[l.pos]
		if c == ` ` || c == `\t` || c == `\n` || c == `\r` {
			l.advance()
		} else {
			break
		}
	}
}

fn (mut l Lexer) next_text_or_open() !Tok {
	start := l.pos
	start_line := l.line
	start_col := l.col
	for l.pos < l.src.len {
		c := l.src[l.pos]
		if c == `{` && l.pos + 1 < l.src.len {
			n := l.src[l.pos + 1]
			if n == `{` || n == `%` || n == `#` {
				break
			}
		}
		l.advance()
	}
	if l.pos > start {
		mut text := l.src[start..l.pos]
		// Look ahead: if the action starts with `{%-`, `{{-`, `{#-`, mark
		// trim_right on this text token.
		mut trim_r := false
		if l.pos + 2 < l.src.len && l.src[l.pos + 2] == `-` {
			trim_r = true
		}
		// lstrip_blocks: when the action is `{%` (statement), strip leading
		// whitespace on its line — if the trailing run of spaces/tabs follows
		// a `\n`, remove it. Mirrors Jinja2 `lstrip_blocks=True`. Statements
		// only, not `{{ }}`.
		if l.pos + 1 < l.src.len && l.src[l.pos + 1] == `%` {
			mut last_nl := -1
			for j := text.len - 1; j >= 0; j-- {
				if text[j] == `\n` {
					last_nl = j
					break
				}
			}
			if last_nl >= 0 {
				mut all_ws := true
				for j := last_nl + 1; j < text.len; j++ {
					c := text[j]
					if c != ` ` && c != `\t` {
						all_ws = false
						break
					}
				}
				if all_ws {
					text = text[..last_nl + 1]
				}
			}
		}
		// We handle comments transparently: lex skips them, but the
		// surrounding text still gets emitted up to before the comment.
		if l.pos + 1 < l.src.len && l.src[l.pos + 1] == `#` {
			// emit text first, then absorb the comment, then continue.
			tok := Tok{
				kind: .text
				value: text
				line: start_line
				col: start_col
				trim_right: trim_r
			}
			l.skip_comment()!
			return tok
		}
		return Tok{
			kind: .text
			value: text
			line: start_line
			col: start_col
			trim_right: trim_r
		}
	}
	// l.pos sits on `{`. Decide which open we are looking at.
	if l.pos + 1 >= l.src.len {
		return error('lex: stray "{" at ${l.line}:${l.col}')
	}
	n := l.src[l.pos + 1]
	if n == `#` {
		l.skip_comment()!
		// Loop will pick up text after the comment on the next call.
		return l.next_text_or_open()
	}
	mut trim_l := false
	if l.pos + 2 < l.src.len && l.src[l.pos + 2] == `-` {
		trim_l = true
	}
	open_line := l.line
	open_col := l.col
	if n == `{` {
		l.advance()
		l.advance()
		if trim_l {
			l.advance()
		}
		l.in_action = true
		return Tok{
			kind: .expr_open
			line: open_line
			col: open_col
			trim_left: trim_l
		}
	}
	if n == `%` {
		l.advance()
		l.advance()
		if trim_l {
			l.advance()
		}
		l.in_action = true
		return Tok{
			kind: .stmt_open
			line: open_line
			col: open_col
			trim_left: trim_l
		}
	}
	return error('lex: unexpected sequence "{${n.ascii_str()}" at ${l.line}:${l.col}')
}

fn (mut l Lexer) skip_comment() ! {
	// pos is at `{`; n is `#`.
	l.advance() // {
	l.advance() // #
	for l.pos + 1 < l.src.len {
		if l.src[l.pos] == `#` && l.src[l.pos + 1] == `}` {
			l.advance() // #
			l.advance() // }
			return
		}
		l.advance()
	}
	return error('lex: unterminated comment')
}

fn (mut l Lexer) next_action_token() !Tok {
	if l.pos >= l.src.len {
		return error('lex: unexpected EOF in action')
	}
	c := l.src[l.pos]
	line := l.line
	col := l.col
	// Closing delimiters.
	if c == `-` && l.pos + 2 < l.src.len {
		// `-}}` or `-%}`
		n1 := l.src[l.pos + 1]
		n2 := l.src[l.pos + 2]
		if n1 == `}` && n2 == `}` {
			l.advance()
			l.advance()
			l.advance()
			l.trim_next_text = true
			return Tok{
				kind: .expr_close
				line: line
				col: col
				trim_left: true
			}
		}
		if n1 == `%` && n2 == `}` {
			l.advance()
			l.advance()
			l.advance()
			l.trim_next_text = true
			return Tok{
				kind: .stmt_close
				line: line
				col: col
				trim_left: true
			}
		}
	}
	if c == `}` && l.peek(1) == `}` {
		l.advance()
		l.advance()
		return Tok{
			kind: .expr_close
			line: line
			col: col
		}
	}
	if c == `%` && l.peek(1) == `}` {
		l.advance()
		l.advance()
		l.trim_one_newline = true
		return Tok{
			kind: .stmt_close
			line: line
			col: col
		}
	}
	// String literal.
	if c == `"` || c == `'` {
		return l.read_string(c)!
	}
	// Number.
	if c == `-` && is_digit(l.peek(1)) {
		return l.read_number()
	}
	if is_digit(c) {
		return l.read_number()
	}
	// Identifier / keyword.
	if is_ident_start(c) {
		return l.read_ident()
	}
	// Single-char punctuation and operators.
	match c {
		`.` {
			l.advance()
			return Tok{
				kind: .dot
				line: line
				col: col
			}
		}
		`,` {
			l.advance()
			return Tok{
				kind: .comma
				line: line
				col: col
			}
		}
		`|` {
			l.advance()
			return Tok{
				kind: .pipe
				line: line
				col: col
			}
		}
		`(` {
			l.advance()
			return Tok{
				kind: .lparen
				line: line
				col: col
			}
		}
		`)` {
			l.advance()
			return Tok{
				kind: .rparen
				line: line
				col: col
			}
		}
		`[` {
			l.advance()
			return Tok{
				kind: .lbracket
				line: line
				col: col
			}
		}
		`]` {
			l.advance()
			return Tok{
				kind: .rbracket
				line: line
				col: col
			}
		}
		`=` {
			if l.peek(1) == `=` {
				l.advance()
				l.advance()
				return Tok{
					kind: .op_eq
					line: line
					col: col
				}
			}
			l.advance()
			return Tok{
				kind: .op_assign
				line: line
				col: col
			}
		}
		`!` {
			if l.peek(1) == `=` {
				l.advance()
				l.advance()
				return Tok{
					kind: .op_ne
					line: line
					col: col
				}
			}
		}
		`<` {
			if l.peek(1) == `=` {
				l.advance()
				l.advance()
				return Tok{
					kind: .op_le
					line: line
					col: col
				}
			}
			l.advance()
			return Tok{
				kind: .op_lt
				line: line
				col: col
			}
		}
		`>` {
			if l.peek(1) == `=` {
				l.advance()
				l.advance()
				return Tok{
					kind: .op_ge
					line: line
					col: col
				}
			}
			l.advance()
			return Tok{
				kind: .op_gt
				line: line
				col: col
			}
		}
		else {}
	}

	return error('lex: unexpected character "${c.ascii_str()}" at ${line}:${col}')
}

fn (mut l Lexer) read_string(quote u8) !Tok {
	line := l.line
	col := l.col
	l.advance() // opening quote
	mut buf := []u8{}
	for l.pos < l.src.len {
		c := l.src[l.pos]
		if c == quote {
			l.advance()
			return Tok{
				kind: .str
				value: buf.bytestr()
				line: line
				col: col
			}
		}
		if c == `\\` && l.pos + 1 < l.src.len {
			n := l.src[l.pos + 1]
			match n {
				`\\` { buf << `\\` }
				`"` { buf << `"` }
				`'` { buf << `'` }
				`n` { buf << `\n` }
				`t` { buf << `\t` }
				else { buf << n }
			}

			l.advance()
			l.advance()
			continue
		}
		buf << c
		l.advance()
	}
	return error('lex: unterminated string at ${line}:${col}')
}

fn (mut l Lexer) read_number() Tok {
	line := l.line
	col := l.col
	mut buf := []u8{}
	if l.src[l.pos] == `-` {
		buf << `-`
		l.advance()
	}
	for l.pos < l.src.len && is_digit(l.src[l.pos]) {
		buf << l.src[l.pos]
		l.advance()
	}
	return Tok{
		kind: .number
		value: buf.bytestr()
		line: line
		col: col
	}
}

fn (mut l Lexer) read_ident() Tok {
	line := l.line
	col := l.col
	mut buf := []u8{}
	for l.pos < l.src.len && is_ident_part(l.src[l.pos]) {
		buf << l.src[l.pos]
		l.advance()
	}
	return Tok{
		kind: .ident
		value: buf.bytestr()
		line: line
		col: col
	}
}

fn is_digit(c u8) bool {
	return c >= `0` && c <= `9`
}

fn is_ident_start(c u8) bool {
	return (c >= `a` && c <= `z`) || (c >= `A` && c <= `Z`) || c == `_`
}

fn is_ident_part(c u8) bool {
	return is_ident_start(c) || is_digit(c)
}
