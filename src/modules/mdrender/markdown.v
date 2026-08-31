// Module markdown converts a Markdown subset to HTML. The subset is sized to
// the labs site and is broadly CommonMark-conformant for the constructs it
// supports:
//
//   block: ATX headings (#..######), paragraphs, fenced code (```lang),
//          unordered lists (- / *), ordered lists (1.), blockquotes (>),
//          horizontal rules (---/***/___), raw HTML blocks, GFM tables
//   inline: emphasis (* / _), strong (** / __), code (`...`), links,
//           images, autolinks (<http://...>), hard line breaks ("  \n"),
//           HTML pass-through (when allow_html=true)
//
// Output is a string of HTML. Code fences emit `<pre><code class="language-X">…</code></pre>`
// without applying syntax highlighting; the highlight module post-processes
// the produced HTML if the caller wants colored output.
//
// Limits:
//   - no setext headings (=== / ---)
//   - no reference-style links
//   - one nesting level for blockquotes/lists is the tested baseline; deeper
//     nesting works but is not fuzz-tested
module mdrender

import strings
import highlight

pub struct Options {
pub:
	allow_html bool = true
	base_url   string
}

// render converts a CommonMark source into HTML, honouring the supplied
// options (heading anchors, code highlighting, base URL rewriting).
pub fn render(src string, opts Options) string {
	mut r := Renderer{
		opts: opts
	}
	return r.render(src)
}

struct Renderer {
	opts Options
mut:
	out strings.Builder = strings.new_builder(1024)
}

fn (mut r Renderer) render(src string) string {
	lines := src.replace('\r\n', '\n').split('\n')
	mut i := 0
	for i < lines.len {
		line := lines[i]
		trimmed := line.trim_space()
		if trimmed == '' {
			i++
			continue
		}
		if is_hr(trimmed) {
			r.out.write_string('<hr>\n')
			i++
			continue
		}
		if fence_open_len(line) > 0 {
			i = r.fence(lines, i)
			continue
		}
		if h_level := atx_level(line) {
			r.heading(line, h_level)
			i++
			continue
		}
		if line.starts_with('> ') || line == '>' {
			i = r.blockquote(lines, i)
			continue
		}
		if is_ul_marker(line) {
			i = r.list(lines, i, false)
			continue
		}
		if is_ol_marker(line) {
			i = r.list(lines, i, true)
			continue
		}
		if r.opts.allow_html && line.len > 0 && line[0] == `<` && is_html_block_start(line) {
			i = r.html_block(lines, i)
			continue
		}
		if i + 1 < lines.len && is_table_separator(lines[i + 1]) && line.contains('|') {
			i = r.table(lines, i)
			continue
		}
		i = r.paragraph(lines, i)
	}
	return r.out.str()
}

fn is_hr(s string) bool {
	if s.len < 3 {
		return false
	}
	c := s[0]
	if c != `-` && c != `*` && c != `_` {
		return false
	}
	mut count := 0
	for ch in s {
		if ch == c {
			count++
		} else if ch != ` ` && ch != `\t` {
			return false
		}
	}
	return count >= 3
}

fn atx_level(line string) ?int {
	mut i := 0
	for i < line.len && line[i] == ` ` {
		i++
	}
	if i > 3 {
		return none
	}
	mut level := 0
	for i < line.len && line[i] == `#` {
		level++
		i++
	}
	if level == 0 || level > 6 {
		return none
	}
	if i < line.len && line[i] != ` ` {
		return none
	}
	return level
}

fn is_ul_marker(line string) bool {
	t := line.trim_left(' \t')
	return t.len >= 2 && (t[0] == `-` || t[0] == `*` || t[0] == `+`) && t[1] == ` `
}

fn is_ol_marker(line string) bool {
	t := line.trim_left(' \t')
	mut i := 0
	for i < t.len && t[i] >= `0` && t[i] <= `9` {
		i++
	}
	if i == 0 || i > 9 {
		return false
	}
	if i >= t.len {
		return false
	}
	if t[i] != `.` && t[i] != `)` {
		return false
	}
	if i + 1 >= t.len || t[i + 1] != ` ` {
		return false
	}
	return true
}

fn (mut r Renderer) heading(line string, level int) {
	body := line.trim_left('#').trim_left(' \t').trim_right(' #\t')
	slug := slugify_heading(body)
	r.out.write_string('<h')
	r.out.write_string(level.str())
	r.out.write_string(' id="')
	r.out.write_string(escape_attr(slug))
	r.out.write_string('">')
	r.out.write_string(render_inline(body, r.opts))
	r.out.write_string('<a class="anchor mono" href="#')
	r.out.write_string(escape_attr(slug))
	r.out.write_string('" aria-label="Permalink to ')
	r.out.write_string(escape_attr(body))
	r.out.write_string('"><span aria-hidden="true">#</span></a></h')
	r.out.write_string(level.str())
	r.out.write_string('>\n')
}

// slugify_heading turns a heading string into the kebab-case anchor id used
// by the renderer (`Foo Bar 2!` → `foo-bar-2`).
pub fn slugify_heading(s string) string {
	mut buf := strings.new_builder(s.len)
	mut prev_dash := true
	for c in s.to_lower() {
		if (c >= `a` && c <= `z`) || (c >= `0` && c <= `9`) {
			buf.write_u8(c)
			prev_dash = false
		} else if c == ` ` || c == `-` || c == `_` || c == `\t` {
			if !prev_dash {
				buf.write_u8(`-`)
				prev_dash = true
			}
		}
	}
	mut out := buf.str()
	for out.ends_with('-') {
		out = out[..out.len - 1]
	}
	return out
}

// table_of_contents extracts an `<ul>` of nested heading links from a
// Markdown source, skipping headings inside fenced code blocks.
pub fn table_of_contents(src string) string {
	mut headings := []Heading{}
	lines := src.split_into_lines()
	mut i := 0
	mut in_fence := false
	for i < lines.len {
		l := lines[i]
		t := l.trim_left(' ')
		if t.starts_with('```') || t.starts_with('~~~') {
			in_fence = !in_fence
			i++
			continue
		}
		if in_fence {
			i++
			continue
		}
		if t.starts_with('## ') {
			body := t.trim_left('#').trim_left(' \t').trim_right(' #\t')
			headings << Heading{
				level: 2
				text: plain_inline(body)
				slug: slugify_heading(body)
			}
		}
		i++
	}
	if headings.len == 0 {
		return ''
	}
	mut out := strings.new_builder(256)
	out.write_string('<nav id="TableOfContents">\n  <ul>\n')
	for h in headings {
		out.write_string('    <li><a href="#')
		out.write_string(escape_attr(h.slug))
		out.write_string('">')
		out.write_string(escape_html(h.text))
		out.write_string('</a></li>\n')
	}
	out.write_string('  </ul>\n</nav>')
	return out.str()
}

struct Heading {
	level int
	text  string
	slug  string
}

fn plain_inline(s string) string {
	return s
}

fn (mut r Renderer) fence(lines []string, start int) int {
	open := lines[start].trim_left(' ')
	marker := open[0]
	mut open_len := 0
	for open_len < open.len && open[open_len] == marker {
		open_len++
	}
	info := open[open_len..].trim_space()
	lang, filename := parse_fence_info(info)
	mut buf := strings.new_builder(256)
	mut i := start + 1
	for i < lines.len {
		l := lines[i]
		if fence_close_len(l, marker) >= open_len {
			i++
			break
		}
		if buf.len > 0 {
			buf.write_string('\n')
		}
		buf.write_string(l)
		i++
	}
	code := buf.str()
	r.out.write_string('<div class="code-wrap reveal" data-lang="')
	r.out.write_string(escape_attr(if lang != '' { lang } else { 'text' }))
	r.out.write_string('"')
	if filename != '' {
		r.out.write_string(' data-filename="')
		r.out.write_string(escape_attr(filename))
		r.out.write_string('"')
	}
	r.out.write_string('><div class="code-meta">')
	if filename != '' {
		r.out.write_string('<span class="code-filename">')
		r.out.write_string(escape_html(filename))
		r.out.write_string('</span>')
	}
	r.out.write_string('<span class="code-lang">')
	r.out.write_string(escape_html(if lang != '' { lang } else { 'text' }))
	r.out.write_string('</span><button class="code-copy mono" type="button" aria-label="Copy code">copy</button></div>')
	if lang != '' {
		r.out.write_string(highlight.run(code, lang, highlight.Options{}) or {
			fallback_code_block(code, lang)
		})
	} else {
		r.out.write_string(fallback_code_block(code, lang))
	}
	r.out.write_string('</div>\n')
	return i
}

// parse_fence_info splits a fenced-code info string into (lang, filename).
// Supported forms: `lang`, `lang filename="app.js"`, `lang title="app.js"`.
// Bare second token without quotes is also accepted as a filename:
// `lang app.js`. Empty info yields ('','').
fn parse_fence_info(info string) (string, string) {
	if info == '' {
		return '', ''
	}
	mut sp := info.index(' ') or { return info, '' }
	lang := info[..sp]
	rest := info[sp..].trim_space()
	if rest == '' {
		return lang, ''
	}
	for prefix in ['filename=', 'title=', 'name='] {
		if rest.starts_with(prefix) {
			val := rest[prefix.len..]
			return lang, unquote_attr_value(val)
		}
	}
	return lang, unquote_attr_value(rest)
}

fn unquote_attr_value(s string) string {
	t := s.trim_space()
	if t.len >= 2 && (t[0] == `"` || t[0] == `'`) && t[t.len - 1] == t[0] {
		return t[1..t.len - 1]
	}
	return t
}

fn fallback_code_block(code string, lang string) string {
	cls := if lang != '' { ' class="language-${escape_attr(lang)}"' } else { '' }
	return '<pre><code${cls}>' + escape_html(code) + '\n</code></pre>'
}

// fence_open_len returns the length of the opening fence run on `line`
// (3+ identical backticks or tildes after at most three leading spaces),
// or 0 if the line isn't a fence opener.
fn fence_open_len(line string) int {
	t := line.trim_left(' ')
	if t.len < 3 {
		return 0
	}
	c := t[0]
	if c != `\`` && c != `~` {
		return 0
	}
	mut n := 0
	for n < t.len && t[n] == c {
		n++
	}
	if n < 3 {
		return 0
	}
	return n
}

// fence_close_len returns the length of a closing-fence run on `line`
// using the same `marker` char as the opener. Closing fences may have
// leading spaces and trailing whitespace but no info string.
fn fence_close_len(line string, marker u8) int {
	t := line.trim_left(' ')
	mut n := 0
	for n < t.len && t[n] == marker {
		n++
	}
	if n < 3 {
		return 0
	}
	for j := n; j < t.len; j++ {
		if t[j] != ` ` && t[j] != `\t` {
			return 0
		}
	}
	return n
}

fn (mut r Renderer) blockquote(lines []string, start int) int {
	mut buf := strings.new_builder(256)
	mut i := start
	mut first := true
	mut callout_kind := ''
	mut callout_title := ''
	mut callout_untitled := false
	for i < lines.len {
		l := lines[i]
		mut content := ''
		if l.starts_with('> ') {
			content = l[2..]
		} else if l == '>' {
			content = ''
		} else {
			break
		}
		if first {
			first = false
			if kind, title := parse_callout_marker(content) {
				callout_kind = kind
				if title != '' {
					callout_title = title
				} else {
					callout_title = callout_default_title(kind)
					callout_untitled = true
				}
				i++
				continue
			}
		}
		if buf.len > 0 {
			buf.write_string('\n')
		}
		buf.write_string(content)
		i++
	}
	if callout_kind != '' {
		role := if callout_kind == 'warning' || callout_kind == 'caution' {
			'alert'
		} else {
			'note'
		}
		r.out.write_string('<blockquote role="')
		r.out.write_string(role)
		r.out.write_string('" data-callout="')
		r.out.write_string(escape_attr(callout_kind))
		r.out.write_string('"')
		if callout_untitled {
			r.out.write_string(' data-callout-untitled')
		}
		r.out.write_string('>\n<p class="callout-badge">')
		r.out.write_string(escape_html(callout_default_title(callout_kind)))
		r.out.write_string('</p>\n')
		if !callout_untitled {
			r.out.write_string('<p class="callout-title">')
			r.out.write_string(render_inline(callout_title, r.opts))
			r.out.write_string('</p>\n')
		}
	} else {
		r.out.write_string('<blockquote>\n')
	}
	mut inner := Renderer{
		opts: r.opts
	}
	r.out.write_string(inner.render(buf.str()))
	r.out.write_string('</blockquote>\n')
	return i
}

const callout_kinds = ['NOTE', 'TIP', 'IMPORTANT', 'WARNING', 'CAUTION']!

fn parse_callout_marker(line string) ?(string, string) {
	if !line.starts_with('[!') {
		return none
	}
	close := line.index_after(']', 2) or { return none }
	kind_upper := line[2..close]
	if kind_upper !in callout_kinds {
		return none
	}
	rest := line[close + 1..]
	return kind_upper.to_lower(), rest.trim_space()
}

fn callout_default_title(kind string) string {
	return match kind {
		'note' { 'Note' }
		'tip' { 'Tip' }
		'important' { 'Important' }
		'warning' { 'Warning' }
		'caution' { 'Caution' }
		else { kind }
	}
}

fn (mut r Renderer) list(lines []string, start int, ordered bool) int {
	tag := if ordered { 'ol' } else { 'ul' }
	r.out.write_string('<')
	r.out.write_string(tag)
	r.out.write_string('>\n')
	mut i := start
	for i < lines.len {
		line := lines[i]
		if line.trim_space() == '' {
			// blank line: peek next; end list if next is non-list
			if i + 1 >= lines.len {
				i++
				break
			}
			next := lines[i + 1]
			if !(if ordered {
				is_ol_marker(next)} else {
				is_ul_marker(next)}) && !next.starts_with('  ') && !next.starts_with('\t') {
				i++
				break
			}
			i++
			continue
		}
		if (ordered && !is_ol_marker(line)) || (!ordered && !is_ul_marker(line)) {
			break
		}
		mut content := strings.new_builder(64)
		// strip the marker
		t := line.trim_left(' \t')
		body := if ordered {
			mut j := 0
			for j < t.len && t[j] >= `0` && t[j] <= `9` {
				j++
			}
			t[j + 2..] // skip "." or ")" then space
		} else {
			t[2..]
		}
		content.write_string(body)
		// gather indented continuations
		i++
		for i < lines.len {
			c := lines[i]
			if c.starts_with('  ') || c.starts_with('\t') {
				content.write_string('\n')
				content.write_string(c.trim_left(' \t'))
				i++
			} else {
				break
			}
		}
		r.out.write_string('<li>')
		inner := content.str()
		if inner.contains('\n\n') {
			mut sub := Renderer{
				opts: r.opts
			}
			r.out.write_string('\n')
			r.out.write_string(sub.render(inner))
		} else {
			r.out.write_string(render_inline(inner, r.opts))
		}
		r.out.write_string('</li>\n')
	}
	r.out.write_string('</')
	r.out.write_string(tag)
	r.out.write_string('>\n')
	return i
}

fn (mut r Renderer) paragraph(lines []string, start int) int {
	mut buf := strings.new_builder(256)
	mut i := start
	for i < lines.len {
		l := lines[i]
		if l.trim_space() == '' {
			break
		}
		if atx_level(l) != none || l.starts_with('```') || l.starts_with('~~~') || is_ul_marker(l) || is_ol_marker(l) || l.starts_with('> ') || is_hr(l.trim_space()) {
			break
		}
		if buf.len > 0 {
			buf.write_string('\n')
		}
		buf.write_string(l)
		i++
	}
	r.out.write_string('<p>')
	r.out.write_string(render_inline(buf.str(), r.opts))
	r.out.write_string('</p>\n')
	return i
}

// is_table_separator reports whether `line` is a GFM table delimiter row
// (e.g. `| --- | :---: | ---: |`). At least one pipe is required; cells
// must contain only dashes with optional leading/trailing colons.
fn is_table_separator(line string) bool {
	t := line.trim_space()
	if !t.contains('|') {
		return false
	}
	cells := split_table_row(t)
	if cells.len == 0 {
		return false
	}
	for c in cells {
		s := c.trim_space()
		if s.len == 0 {
			return false
		}
		mut start := 0
		mut endi := s.len
		if s[0] == `:` {
			start = 1
		}
		if s.len > 1 && s[s.len - 1] == `:` {
			endi = s.len - 1
		}
		if start >= endi {
			return false
		}
		for k := start; k < endi; k++ {
			if s[k] != `-` {
				return false
			}
		}
	}
	return true
}

// split_table_row splits a GFM table row on unescaped `|` separators,
// stripping the optional leading and trailing pipes.
fn split_table_row(line string) []string {
	mut t := line.trim_space()
	if t.starts_with('|') {
		t = t[1..]
	}
	if t.ends_with('|') && !(t.len >= 2 && t[t.len - 2] == `\\`) {
		t = t[..t.len - 1]
	}
	mut cells := []string{}
	mut buf := strings.new_builder(32)
	mut k := 0
	for k < t.len {
		c := t[k]
		if c == `\\` && k + 1 < t.len && t[k + 1] == `|` {
			buf.write_u8(`|`)
			k += 2
			continue
		}
		if c == `|` {
			cells << buf.str()
			buf = strings.new_builder(32)
			k++
			continue
		}
		buf.write_u8(c)
		k++
	}
	cells << buf.str()
	return cells
}

// table_alignments returns one alignment per column derived from the
// separator row: '', 'left', 'right', or 'center'.
fn table_alignments(sep string) []string {
	cells := split_table_row(sep.trim_space())
	mut out := []string{cap: cells.len}
	for c in cells {
		s := c.trim_space()
		left := s.len > 0 && s[0] == `:`
		right := s.len > 0 && s[s.len - 1] == `:`
		if left && right {
			out << 'center'
		} else if right {
			out << 'right'
		} else if left {
			out << 'left'
		} else {
			out << ''
		}
	}
	return out
}

fn (mut r Renderer) table(lines []string, start int) int {
	header := lines[start]
	sep := lines[start + 1]
	headers := split_table_row(header)
	aligns := table_alignments(sep)
	r.out.write_string('<table>\n<thead>\n<tr>')
	for idx, h in headers {
		align := if idx < aligns.len { aligns[idx] } else { '' }
		if align != '' {
			r.out.write_string('<th style="text-align:${align}">')
		} else {
			r.out.write_string('<th>')
		}
		r.out.write_string(render_inline(h.trim_space(), r.opts))
		r.out.write_string('</th>')
	}
	r.out.write_string('</tr>\n</thead>\n')
	mut i := start + 2
	mut body_open := false
	for i < lines.len {
		l := lines[i]
		if l.trim_space() == '' || !l.contains('|') {
			break
		}
		if !body_open {
			r.out.write_string('<tbody>\n')
			body_open = true
		}
		cells := split_table_row(l)
		r.out.write_string('<tr>')
		for idx in 0 .. headers.len {
			align := if idx < aligns.len { aligns[idx] } else { '' }
			cell := if idx < cells.len { cells[idx].trim_space() } else { '' }
			if align != '' {
				r.out.write_string('<td style="text-align:${align}">')
			} else {
				r.out.write_string('<td>')
			}
			r.out.write_string(render_inline(cell, r.opts))
			r.out.write_string('</td>')
		}
		r.out.write_string('</tr>\n')
		i++
	}
	if body_open {
		r.out.write_string('</tbody>\n')
	}
	r.out.write_string('</table>\n')
	return i
}

fn is_html_block_start(line string) bool {
	if line.len < 2 {
		return false
	}
	if line[0] != `<` {
		return false
	}
	c := line[1]
	if c == `/` || (c >= `a` && c <= `z`) || (c >= `A` && c <= `Z`) || c == `!` {
		return true
	}
	return false
}

fn (mut r Renderer) html_block(lines []string, start int) int {
	mut i := start
	for i < lines.len {
		if lines[i].trim_space() == '' {
			break
		}
		r.out.write_string(lines[i])
		r.out.write_string('\n')
		i++
	}
	return i
}

// ---- inline ----
fn render_inline(src string, opts Options) string {
	mut out := strings.new_builder(src.len)
	bytes := src
	mut i := 0
	for i < bytes.len {
		c := bytes[i]
		match c {
			`\\` {
				if i + 1 < bytes.len && is_punct(bytes[i + 1]) {
					out.write_u8(bytes[i + 1])
					i += 2
					continue
				}
				out.write_u8(c)
				i++
			}
			`\`` {
				end := find_code_close(bytes, i)
				if end > i {
					out.write_string('<code>')
					out.write_string(escape_html(bytes[i + 1..end]))
					out.write_string('</code>')
					i = end + 1
					continue
				}
				out.write_u8(c)
				i++
			}
			`*`, `_` {
				if span_len, body := emphasis(bytes, i, c) {
					if span_len >= 4 {
						out.write_string('<strong>')
						out.write_string(render_inline(body, opts))
						out.write_string('</strong>')
					} else {
						out.write_string('<em>')
						out.write_string(render_inline(body, opts))
						out.write_string('</em>')
					}
					i += span_len + body.len
					continue
				}
				out.write_u8(c)
				i++
			}
			`!` {
				if i + 1 < bytes.len && bytes[i + 1] == `[` {
					if alt, url, title, advance := parse_link(bytes, i + 1) {
						out.write_string('<figure class="article-figure reveal"><img src="')
						out.write_string(escape_attr(resolve_url(url, opts)))
						out.write_string('" alt="')
						out.write_string(escape_attr(alt))
						out.write_string('"')
						if title != '' {
							out.write_string(' title="')
							out.write_string(escape_attr(title))
							out.write_string('"')
						}
						out.write_string(' loading="lazy">')
						caption := if title != '' { title } else { alt }
						if caption != '' {
							out.write_string('<figcaption>')
							out.write_string(escape_attr(caption))
							out.write_string('</figcaption>')
						}
						out.write_string('</figure>')
						i += 1 + advance
						continue
					}
				}
				out.write_u8(c)
				i++
			}
			`[` {
				if text, url, title, advance := parse_link(bytes, i) {
					out.write_string('<a href="')
					out.write_string(escape_attr(resolve_url(url, opts)))
					out.write_string('"')
					if title != '' {
						out.write_string(' title="')
						out.write_string(escape_attr(title))
						out.write_string('"')
					}
					out.write_string('>')
					out.write_string(render_inline(text, opts))
					out.write_string('</a>')
					i += advance
					continue
				}
				out.write_u8(c)
				i++
			}
			`<` {
				if end := autolink_end(bytes, i) {
					url := bytes[i + 1..end]
					out.write_string('<a href="')
					out.write_string(escape_attr(url))
					out.write_string('">')
					out.write_string(escape_html(url))
					out.write_string('</a>')
					i = end + 1
					continue
				}
				if opts.allow_html {
					if end := html_tag_end(bytes, i) {
						out.write_string(bytes[i..end + 1])
						i = end + 1
						continue
					}
				}
				out.write_string('&lt;')
				i++
			}
			`&` {
				if is_entity(bytes, i) {
					out.write_u8(c)
					i++
					continue
				}
				out.write_string('&amp;')
				i++
			}
			`>` {
				out.write_string('&gt;')
				i++
			}
			`"` {
				// SmartyPants: open quote at start/after whitespace, close otherwise.
				prev := if i > 0 { bytes[i - 1] } else { ` ` }
				if prev == ` ` || prev == `\n` || prev == `\t` || prev == `(` || prev == `[` || prev == 0 {
					out.write_string('&ldquo;')
				} else {
					out.write_string('&rdquo;')
				}
				i++
			}
			`'` {
				out.write_string('&rsquo;')
				i++
			}
			`.` {
				if i + 2 < bytes.len && bytes[i + 1] == `.` && bytes[i + 2] == `.` {
					out.write_string('&hellip;')
					i += 3
					continue
				}
				out.write_u8(c)
				i++
			}
			` ` {
				if i + 2 < bytes.len && bytes[i + 1] == ` ` && bytes[i + 2] == `\n` {
					out.write_string('<br>\n')
					i += 3
					continue
				}
				out.write_u8(c)
				i++
			}
			`\n` {
				out.write_u8(`\n`)
				i++
			}
			else {
				out.write_u8(c)
				i++
			}
		}
	}
	return out.str()
}

fn is_punct(c u8) bool {
	return (c >= 33 && c <= 47) || (c >= 58 && c <= 64) || (c >= 91 && c <= 96) || (c >= 123 && c <= 126)
}

fn find_code_close(s string, start int) int {
	mut count := 0
	mut i := start
	for i < s.len && s[i] == `\`` {
		count++
		i++
	}
	for j := i; j < s.len;  {
		if s[j] != `\`` {
			j++
			continue
		}
		mut run := 0
		for j < s.len && s[j] == `\`` {
			run++
			j++
		}
		if run == count {
			return j - 1
		}
	}
	return -1
}

fn emphasis(s string, start int, marker u8) ?(int, string) {
	mut span := 0
	for start + span < s.len && s[start + span] == marker && span < 3 {
		span++
	}
	want := if span >= 2 { 4 } else { 2 }
	delim_len := if span >= 2 { 2 } else { 1 }
	mut i := start + delim_len
	if i >= s.len || s[i] == ` ` {
		return none
	}
	for i < s.len {
		if s[i] == marker {
			mut run := 0
			for i + run < s.len && s[i + run] == marker {
				run++
			}
			if run >= delim_len && (i + run >= s.len || s[i + run] != marker) && s[i - 1] != ` ` {
				body := s[start + delim_len..i]
				return want, body
			}
			i += run
		} else {
			i++
		}
	}
	return none
}

fn parse_link(s string, start int) ?(string, string, string, int) {
	if s[start] != `[` {
		return none
	}
	mut depth := 1
	mut i := start + 1
	for i < s.len && depth > 0 {
		match s[i] {
			`\\` {
				i += 2
				continue
			}
			`[` {
				depth++
			}
			`]` {
				depth--
			}
			else {}
		}

		if depth == 0 {
			break
		}
		i++
	}
	if i >= s.len || depth != 0 || i + 1 >= s.len || s[i + 1] != `(` {
		return none
	}
	text := s[start + 1..i]
	mut j := i + 2
	for j < s.len && s[j] == ` ` {
		j++
	}
	url_start := j
	mut url := ''
	if j < s.len && s[j] == `<` {
		j++
		begin := j
		for j < s.len && s[j] != `>` && s[j] != `\n` {
			j++
		}
		if j >= s.len || s[j] != `>` {
			return none
		}
		url = s[begin..j]
		j++
	} else {
		mut p := 0
		for j < s.len && s[j] != ` ` && s[j] != `)` && s[j] != `\n` {
			if s[j] == `(` {
				p++
			} else if s[j] == `)` {
				if p == 0 {
					break
				}
				p--
			}
			j++
		}
		url = s[url_start..j]
	}
	mut title := ''
	for j < s.len && s[j] == ` ` {
		j++
	}
	if j < s.len && (s[j] == `"` || s[j] == `'`) {
		quote := s[j]
		j++
		t_start := j
		for j < s.len && s[j] != quote {
			j++
		}
		if j >= s.len {
			return none
		}
		title = s[t_start..j]
		j++
		for j < s.len && s[j] == ` ` {
			j++
		}
	}
	if j >= s.len || s[j] != `)` {
		return none
	}
	return text, url, title, j + 1 - start
}

fn autolink_end(s string, start int) ?int {
	mut i := start + 1
	for i < s.len && s[i] != `>` && s[i] != ` ` && s[i] != `\n` {
		i++
	}
	if i >= s.len || s[i] != `>` {
		return none
	}
	url := s[start + 1..i]
	if !(url.starts_with('http://') || url.starts_with('https://') || url.starts_with('mailto:')) {
		return none
	}
	return i
}

fn html_tag_end(s string, start int) ?int {
	if start + 1 >= s.len {
		return none
	}
	c := s[start + 1]
	is_tag_start := c == `/` || c == `!` || c == `?` || (c >= `a` && c <= `z`) || (c >= `A` && c <= `Z`)
	if !is_tag_start {
		return none
	}
	mut i := start + 1
	for i < s.len && s[i] != `>` && s[i] != `\n` && s[i] != `<` {
		i++
	}
	if i >= s.len || s[i] != `>` {
		return none
	}
	return i
}

fn is_entity(s string, start int) bool {
	if start + 1 >= s.len {
		return false
	}
	mut i := start + 1
	if s[i] == `#` {
		i++
	}
	for i < s.len && i - start < 12 {
		c := s[i]
		if c == `;` && i > start + 1 {
			return true
		}
		if !((c >= `0` && c <= `9`) || (c >= `a` && c <= `z`) || (c >= `A` && c <= `Z`)) {
			return false
		}
		i++
	}
	return false
}

fn resolve_url(url string, opts Options) string {
	if opts.base_url == '' {
		return url
	}
	if url.starts_with('http://') || url.starts_with('https://') || url.starts_with('mailto:') || url.starts_with('#') || url.starts_with('//') {
		return url
	}
	return opts.base_url.trim_right('/') + '/' + url.trim_left('/')
}

// escape_html replaces `<`, `>`, `&` and `"` with their HTML entities.
pub fn escape_html(s string) string {
	if s.index_any('<>&"') < 0 {
		return s
	}
	mut out := strings.new_builder(s.len)
	for c in s {
		match c {
			`<` { out.write_string('&lt;') }
			`>` { out.write_string('&gt;') }
			`&` { out.write_string('&amp;') }
			`"` { out.write_string('&quot;') }
			else { out.write_u8(c) }
		}
	}
	return out.str()
}

// escape_attr escapes the same character set as escape_html — kept as a
// distinct name so attribute-context call sites stay readable.
pub fn escape_attr(s string) string {
	return escape_html(s)
}

// plain returns the source with all Markdown markup stripped, suitable for
// search indexing or excerpts.
pub fn plain(src string) string {
	mut out := strings.new_builder(src.len)
	mut i := 0
	mut in_fence := false
	lines := src.replace('\r\n', '\n').split('\n')
	for line in lines {
		if line.trim_left(' ').starts_with('```') || line.trim_left(' ').starts_with('~~~') {
			in_fence = !in_fence
			continue
		}
		if in_fence {
			// Code-block tokens count as words. Append the line verbatim
			// so word_count and plain include them.
			t := line.trim_space()
			if t != '' {
				if out.len > 0 {
					out.write_string(' ')
				}
				out.write_string(t)
			}
			continue
		}
		mut t := line.trim_left('#').trim_left(' >\t-*+').trim_space()
		// strip inline code
		for t.contains('`') {
			a := t.index('`') or { break }
			b := t.index_after('`', a + 1) or { break }
			t = t[..a] + t[a + 1..b] + t[b + 1..]
		}
		// strip links: [text](url) -> text
		for t.contains('](') {
			start := t.index('[') or { break }
			mid := t.index_after('](', start) or { break }
			end := t.index_after(')', mid) or { break }
			text := t[start + 1..mid]
			t = t[..start] + text + t[end + 1..]
		}
		// strip images
		for t.contains('![') {
			a := t.index('![') or { break }
			mid := t.index_after('](', a) or { break }
			end := t.index_after(')', mid) or { break }
			t = t[..a] + t[a + 2..mid] + t[end + 1..]
		}
		// strip bold/italic markers
		t = t.replace('**', '').replace('__', '').replace('*', '').replace('_', '')
		if t == '' {
			continue
		}
		if out.len > 0 {
			out.write_string(' ')
		}
		out.write_string(t)
		i++
	}
	return out.str()
}

// word_count returns the number of whitespace-separated words in `plain(src)`.
pub fn word_count(src string) int {
	p := plain(src)
	if p == '' {
		return 0
	}
	mut n := 0
	mut in_word := false
	for c in p {
		if c == ` ` || c == `\t` || c == `\n` {
			if in_word {
				n++
				in_word = false
			}
		} else {
			in_word = true
		}
	}
	if in_word {
		n++
	}
	return n
}

// reading_time returns minutes assuming 200 words/min, minimum 1.
pub fn reading_time(src string) int {
	w := word_count(src)
	mins := w / 200
	if mins < 1 {
		return 1
	}
	return mins
}
