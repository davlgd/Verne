// Parser: token stream → AST. Grammar is fixed and small (see docs/content/reference/templates.md):
// no user-defined variables, no inline arithmetic, no extends/macro.
module template

pub type Node = ForNode | IfNode | IncludeNode | OutputNode | ShortcodeNode | TextNode | WithNode

pub struct TextNode {
pub:
	text string
}

pub struct OutputNode {
pub:
	expr Expr
	line int
	col  int
}

pub struct IfBranch {
pub:
	cond Expr
	body []Node
}

pub struct IfNode {
pub:
	branches  []IfBranch
	else_body []Node
}

pub struct ForNode {
pub:
	key_var string
	val_var string
	source  Expr
	body    []Node
}

pub struct WithNode {
pub:
	name   string
	source Expr
	body   []Node
}

pub struct IncludeNode {
pub:
	path string
}

pub struct ShortcodeArg {
pub:
	name  string
	value Expr
}

pub struct ShortcodeNode {
pub:
	name string
	args []ShortcodeArg
	body []Node
	line int
	col  int
}

// Expressions.
pub type Expr = BoolLit
	| FieldAccess
	| FilterCall
	| FuncCall
	| InTest
	| IndexAccess
	| IntLit
	| IsTest
	| LogicAnd
	| LogicNot
	| LogicOr
	| NoneLit
	| StringLit
	| VarRef
	| Compare

pub struct StringLit {
pub:
	value string
}

pub struct IntLit {
pub:
	value i64
}

pub struct BoolLit {
pub:
	value bool
}

pub struct NoneLit {}

pub struct VarRef {
pub:
	name string
	line int
	col  int
}

pub struct FieldAccess {
pub:
	base  Expr
	field string
}

pub struct IndexAccess {
pub:
	base Expr
	idx  Expr
}

pub struct FuncCall {
pub:
	name string
	args []Expr
}

pub struct FilterCall {
pub:
	base Expr
	name string
	args []Expr
}

pub struct Compare {
pub:
	op    string
	left  Expr
	right Expr
}

pub struct LogicAnd {
pub:
	left  Expr
	right Expr
}

pub struct LogicOr {
pub:
	left  Expr
	right Expr
}

pub struct LogicNot {
pub:
	inner Expr
}

pub struct IsTest {
pub:
	value  Expr
	test   string
	negate bool
}

pub struct InTest {
pub:
	value Expr
	list  Expr
}

struct Parser {
mut:
	toks []Tok
	pos  int
}

// parse turns a template source into the AST consumed by the evaluator.
pub fn parse(src string) ![]Node {
	toks := lex(src)!
	mut p := Parser{
		toks: toks
	}
	body, _ := p.parse_body([]string{})!
	return body
}

fn (p &Parser) peek() Tok {
	if p.pos < p.toks.len {
		return p.toks[p.pos]
	}
	return Tok{
		kind: .eof
	}
}

fn (p &Parser) peek2() Tok {
	if p.pos + 1 < p.toks.len {
		return p.toks[p.pos + 1]
	}
	return Tok{
		kind: .eof
	}
}

fn (mut p Parser) bump() Tok {
	t := p.toks[p.pos]
	p.pos++
	return t
}

fn (mut p Parser) expect(kind TokKind) !Tok {
	t := p.bump()
	if t.kind != kind {
		return error('parse: expected ${kind} at ${t.line}:${t.col}, got ${t.kind} "${t.value}"')
	}
	return t
}

// parse_body reads nodes until it hits a `{% terminator %}` (e.g. endif,
// endfor, else, elif, endwith, endshortcode) or EOF. On terminator match,
// returns positioned **right after the terminator ident** — the caller is
// responsible for consuming any following expression and the closing `%}`.
fn (mut p Parser) parse_body(terminators []string) !([]Node, string) {
	mut nodes := []Node{}
	for {
		t := p.peek()
		match t.kind {
			.eof {
				return nodes, ''
			}
			.text {
				p.bump()
				if t.value.len > 0 {
					nodes << Node(TextNode{
						text: trim_text(t.value, t.trim_left, t.trim_right)
					})
				}
			}
			.expr_open {
				p.bump()
				expr := p.parse_expression()!
				p.expect(.expr_close)!
				nodes << Node(OutputNode{
					expr: expr
					line: t.line
					col:  t.col
				})
			}
			.stmt_open {
				p.bump()
				name := p.expect(.ident)!
				if name.value in terminators {
					return nodes, name.value
				}
				node := p.parse_statement(name.value)!
				nodes << node
			}
			else {
				return error('parse: unexpected token ${t.kind} at ${t.line}:${t.col}')
			}
		}
	}
	return nodes, ''
}

fn trim_text(s string, left bool, right bool) string {
	mut out := s
	if left {
		out = out.trim_left(' \t\n\r')
	}
	if right {
		out = out.trim_right(' \t\n\r')
	}
	return out
}

fn (mut p Parser) parse_statement(name string) !Node {
	match name {
		'if' {
			return p.parse_if()
		}
		'for' {
			return p.parse_for()
		}
		'with' {
			return p.parse_with()
		}
		'include' {
			return p.parse_include()
		}
		'shortcode' {
			return p.parse_shortcode()
		}
		else {
			return error('parse: unknown statement "${name}"')
		}
	}
}

fn (mut p Parser) parse_if() !Node {
	mut branches := []IfBranch{}
	cond := p.parse_expression()!
	p.expect(.stmt_close)!
	body, term := p.parse_body(['elif', 'else', 'endif'])!
	branches << IfBranch{
		cond: cond
		body: body
	}
	mut else_body := []Node{}
	mut t := term
	for t == 'elif' {
		c := p.parse_expression()!
		p.expect(.stmt_close)!
		b, t2 := p.parse_body(['elif', 'else', 'endif'])!
		branches << IfBranch{
			cond: c
			body: b
		}
		t = t2
	}
	if t == 'else' {
		p.expect(.stmt_close)!
		eb, t3 := p.parse_body(['endif'])!
		else_body = eb.clone()
		if t3 != 'endif' {
			return error('parse: expected endif')
		}
		t = t3
	}
	if t != 'endif' {
		return error('parse: expected endif, got "${t}"')
	}
	p.expect(.stmt_close)!
	return Node(IfNode{
		branches:  branches
		else_body: else_body
	})
}

fn (mut p Parser) parse_for() !Node {
	first := p.expect(.ident)!
	mut key_var := ''
	mut val_var := first.value
	if p.peek().kind == .comma {
		p.bump()
		second := p.expect(.ident)!
		key_var = first.value
		val_var = second.value
	}
	in_kw := p.expect(.ident)!
	if in_kw.value != 'in' {
		return error('parse: expected "in" in for at ${in_kw.line}:${in_kw.col}')
	}
	src := p.parse_expression()!
	p.expect(.stmt_close)!
	body, term := p.parse_body(['endfor'])!
	if term != 'endfor' {
		return error('parse: expected endfor')
	}
	p.expect(.stmt_close)!
	return Node(ForNode{
		key_var: key_var
		val_var: val_var
		source:  src
		body:    body
	})
}

fn (mut p Parser) parse_with() !Node {
	name := p.expect(.ident)!
	p.expect(.op_assign)!
	src := p.parse_expression()!
	p.expect(.stmt_close)!
	body, term := p.parse_body(['endwith'])!
	if term != 'endwith' {
		return error('parse: expected endwith')
	}
	p.expect(.stmt_close)!
	return Node(WithNode{
		name:   name.value
		source: src
		body:   body
	})
}

fn (mut p Parser) parse_include() !Node {
	t := p.expect(.str)!
	p.expect(.stmt_close)!
	return Node(IncludeNode{
		path: t.value
	})
}

fn (mut p Parser) parse_shortcode() !Node {
	name := p.expect(.ident)!
	mut args := []ShortcodeArg{}
	for p.peek().kind == .ident {
		key := p.bump()
		p.expect(.op_assign)!
		val := p.parse_expression()!
		args << ShortcodeArg{
			name:  key.value
			value: val
		}
	}
	p.expect(.stmt_close)!
	// If next non-text token is `{% endshortcode %}`, it's paired; otherwise
	// it's self-closing.
	mut body := []Node{}
	saved := p.pos
	mut paired := false
	for i := p.pos; i < p.toks.len; i++ {
		t := p.toks[i]
		if t.kind == .stmt_open {
			n := if i + 1 < p.toks.len { p.toks[i + 1] } else { Tok{} }
			if n.kind == .ident && n.value == 'endshortcode' {
				paired = true
				break
			}
		}
	}
	p.pos = saved
	if paired {
		b, term := p.parse_body(['endshortcode'])!
		if term != 'endshortcode' {
			return error('parse: expected endshortcode')
		}
		body = b.clone()
		p.expect(.stmt_close)!
	}
	return Node(ShortcodeNode{
		name: name.value
		args: args
		body: body
		line: name.line
		col:  name.col
	})
}

// parse_expression: precedence top-down. or → and → not → compare → unary →
// postfix (filter pipe, field access, index, call) → primary.
fn (mut p Parser) parse_expression() !Expr {
	return p.parse_or()
}

fn (mut p Parser) parse_or() !Expr {
	mut left := p.parse_and()!
	for p.peek().kind == .ident && p.peek().value == 'or' {
		p.bump()
		right := p.parse_and()!
		left = Expr(LogicOr{
			left:  left
			right: right
		})
	}
	return left
}

fn (mut p Parser) parse_and() !Expr {
	mut left := p.parse_not()!
	for p.peek().kind == .ident && p.peek().value == 'and' {
		p.bump()
		right := p.parse_not()!
		left = Expr(LogicAnd{
			left:  left
			right: right
		})
	}
	return left
}

fn (mut p Parser) parse_not() !Expr {
	if p.peek().kind == .ident && p.peek().value == 'not' {
		p.bump()
		inner := p.parse_not()!
		return Expr(LogicNot{
			inner: inner
		})
	}
	return p.parse_compare()
}

fn (mut p Parser) parse_compare() !Expr {
	left := p.parse_filter()!
	t := p.peek()
	// `is defined`, `is none`, `is empty`, `is not defined`, etc.
	if t.kind == .ident && t.value == 'is' {
		p.bump()
		mut negate := false
		if p.peek().kind == .ident && p.peek().value == 'not' {
			p.bump()
			negate = true
		}
		test := p.expect(.ident)!
		return Expr(IsTest{
			value:  left
			test:   test.value
			negate: negate
		})
	}
	// `x in xs`
	if t.kind == .ident && t.value == 'in' {
		p.bump()
		right := p.parse_filter()!
		return Expr(InTest{
			value: left
			list:  right
		})
	}
	// Comparison operators.
	op := match t.kind {
		.op_eq { '==' }
		.op_ne { '!=' }
		.op_lt { '<' }
		.op_le { '<=' }
		.op_gt { '>' }
		.op_ge { '>=' }
		else { '' }
	}

	if op != '' {
		p.bump()
		right := p.parse_filter()!
		return Expr(Compare{
			op:    op
			left:  left
			right: right
		})
	}
	return left
}

fn (mut p Parser) parse_filter() !Expr {
	mut left := p.parse_postfix()!
	for p.peek().kind == .pipe {
		p.bump()
		name := p.expect(.ident)!
		mut args := []Expr{}
		if p.peek().kind == .lparen {
			p.bump()
			if p.peek().kind != .rparen {
				args << p.parse_expression()!
				for p.peek().kind == .comma {
					p.bump()
					args << p.parse_expression()!
				}
			}
			p.expect(.rparen)!
		}
		left = Expr(FilterCall{
			base: left
			name: name.value
			args: args
		})
	}
	return left
}

fn (mut p Parser) parse_postfix() !Expr {
	mut left := p.parse_primary()!
	for {
		t := p.peek()
		if t.kind == .dot {
			p.bump()
			f := p.expect(.ident)!
			left = Expr(FieldAccess{
				base:  left
				field: f.value
			})
			continue
		}
		if t.kind == .lbracket {
			p.bump()
			idx := p.parse_expression()!
			p.expect(.rbracket)!
			left = Expr(IndexAccess{
				base: left
				idx:  idx
			})
			continue
		}
		break
	}
	return left
}

fn (mut p Parser) parse_primary() !Expr {
	t := p.peek()
	match t.kind {
		.str {
			p.bump()
			return Expr(StringLit{
				value: t.value
			})
		}
		.number {
			p.bump()
			return Expr(IntLit{
				value: t.value.i64()
			})
		}
		.lparen {
			p.bump()
			e := p.parse_expression()!
			p.expect(.rparen)!
			return e
		}
		.ident {
			p.bump()
			match t.value {
				'true' {
					return Expr(BoolLit{
						value: true
					})
				}
				'false' {
					return Expr(BoolLit{
						value: false
					})
				}
				'none' {
					return Expr(NoneLit{})
				}
				else {}
			}

			// Function call?  ident(...)
			if p.peek().kind == .lparen {
				p.bump()
				mut args := []Expr{}
				if p.peek().kind != .rparen {
					args << p.parse_expression()!
					for p.peek().kind == .comma {
						p.bump()
						args << p.parse_expression()!
					}
				}
				p.expect(.rparen)!
				return Expr(FuncCall{
					name: t.value
					args: args
				})
			}
			return Expr(VarRef{
				name: t.value
				line: t.line
				col:  t.col
			})
		}
		else {
			return error('parse: unexpected token ${t.kind} "${t.value}" at ${t.line}:${t.col}')
		}
	}
}
