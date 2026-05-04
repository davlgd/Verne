module mdrender

fn render_default(src string) string {
	return render(src, Options{})
}

fn test_paragraph() {
	assert render_default('Hello.') == '<p>Hello.</p>\n'
	assert render_default('First.\nSecond.') == '<p>First.\nSecond.</p>\n'
}

fn test_heading() {
	assert render_default('# Title') == '<h1 id="title">Title<a class="anchor mono" href="#title" aria-label="Permalink to Title"><span aria-hidden="true">#</span></a></h1>\n'
	assert render_default('## Sub') == '<h2 id="sub">Sub<a class="anchor mono" href="#sub" aria-label="Permalink to Sub"><span aria-hidden="true">#</span></a></h2>\n'
	assert render_default('###### Six') == '<h6 id="six">Six<a class="anchor mono" href="#six" aria-label="Permalink to Six"><span aria-hidden="true">#</span></a></h6>\n'
	// not a heading: no space after #
	assert render_default('#Nope').starts_with('<p>')
}

fn test_emphasis_strong() {
	assert render_default('a *italic* b') == '<p>a <em>italic</em> b</p>\n'
	assert render_default('a **bold** b') == '<p>a <strong>bold</strong> b</p>\n'
	assert render_default('_alone_') == '<p><em>alone</em></p>\n'
}

fn test_inline_code() {
	assert render_default('use `git push` here') == '<p>use <code>git push</code> here</p>\n'
	assert render_default('html: `<a>`') == '<p>html: <code>&lt;a&gt;</code></p>\n'
}

fn test_link_and_image() {
	got := render_default('See [V](https://vlang.io/).')
	assert got == '<p>See <a href="https://vlang.io/">V</a>.</p>\n', got
	img := render_default('![Alt](/img.webp)')
	assert img == '<p><figure class="article-figure reveal"><img src="/img.webp" alt="Alt" loading="lazy"><figcaption>Alt</figcaption></figure></p>\n', img
}

fn test_link_with_title() {
	got := render_default('[home](/x "Home page")')
	assert got == '<p><a href="/x" title="Home page">home</a></p>\n'
}

fn test_autolink() {
	got := render_default('see <https://example.com> ok')
	assert got == '<p>see <a href="https://example.com">https://example.com</a> ok</p>\n'
}

fn test_fenced_code_with_filename() {
	got := render_default('```bash filename="install.sh"\necho hi\n```')
	assert got.contains('data-filename="install.sh"')
	assert got.contains('<span class="code-filename">install.sh</span>')
	assert got.contains('<span class="code-lang">bash</span>')
}

fn test_fenced_code_with_bare_filename() {
	got := render_default('```bash app.sh\necho hi\n```')
	assert got.contains('data-filename="app.sh"')
	assert got.contains('<span class="code-filename">app.sh</span>')
}

fn test_fenced_code_no_filename() {
	got := render_default('```bash\necho hi\n```')
	assert !got.contains('data-filename')
	assert !got.contains('code-filename')
	assert got.contains('<span class="code-lang">bash</span>')
}

fn test_fenced_code_nested_with_longer_opener() {
	// A 4-backtick fence wraps a 3-backtick fence — the inner ``` must NOT
	// close the outer fence; only ```` (>= opener length) does.
	src := '````markdown\n```python\ndef greet():\n    pass\n```\n````\n'
	got := render_default(src)
	assert got.contains('python'), 'inner opener stripped: ${got}'
	assert got.contains('greet'), 'inner body missing: ${got}'
	// Exactly one <pre> block — the inner ``` must not have closed the outer.
	assert got.count('<pre') == 1, 'expected exactly one <pre> block: ${got}'
}

fn test_fenced_code() {
	src := '```bash\necho hi\n```\n'
	got := render_default(src)
	assert got.contains('<div class="code-wrap reveal" data-lang="bash">'), got
	assert got.contains('echo hi') || got.contains('echo'), got
	assert got.contains('<span class="code-lang">bash</span>'), got
}

fn test_unordered_list() {
	src := '- one\n- two\n- three\n'
	got := render_default(src)
	expected := '<ul>\n<li>one</li>\n<li>two</li>\n<li>three</li>\n</ul>\n'
	assert got == expected, got
}

fn test_ordered_list() {
	src := '1. one\n2. two\n'
	got := render_default(src)
	expected := '<ol>\n<li>one</li>\n<li>two</li>\n</ol>\n'
	assert got == expected, got
}

fn test_blockquote() {
	src := '> A quote.\n> with two lines.\n'
	got := render_default(src)
	assert got.starts_with('<blockquote>')
	assert got.contains('<p>A quote.\nwith two lines.</p>')
	assert got.ends_with('</blockquote>\n')
}

fn test_callout_note_default_title() {
	got := render_default('> [!NOTE]\n> Useful information.')
	assert got.starts_with('<blockquote role="note" data-callout="note" data-callout-untitled>')
	assert got.contains('<p class="callout-badge">Note</p>')
	assert !got.contains('<p class="callout-title">')
	assert got.contains('<p>Useful information.</p>')
	assert !got.contains('[!NOTE]')
	assert got.ends_with('</blockquote>\n')
}

fn test_callout_with_inline_title_has_no_untitled_flag() {
	got := render_default('> [!NOTE] My title\n> body')
	assert got.contains('<blockquote role="note" data-callout="note">')
	assert !got.contains('data-callout-untitled')
}

fn test_callout_with_inline_title() {
	got := render_default('> [!NOTE] This is a title\n> Useful information.')
	assert got.contains('<blockquote role="note" data-callout="note">')
	assert got.contains('<p class="callout-badge">Note</p>')
	assert got.contains('<p class="callout-title">This is a title</p>')
	assert got.contains('<p>Useful information.</p>')
	assert !got.contains('[!NOTE]')
}

fn test_callout_kinds() {
	kinds := {
		'TIP':       'tip'
		'IMPORTANT': 'important'
		'WARNING':   'warning'
		'CAUTION':   'caution'
	}
	for marker, kind in kinds {
		got := render_default('> [!${marker}]\n> body')
		assert got.contains('data-callout="${kind}"'), 'missing data-callout for ${marker}'
		assert !got.contains('[!${marker}]'), 'marker leaked for ${marker}'
	}
}

fn test_callout_unknown_kind_is_plain_blockquote() {
	got := render_default('> [!UNKNOWN]\n> body')
	assert !got.contains('data-callout')
	assert got.contains('[!UNKNOWN]')
}

fn test_callout_only_marker_no_body() {
	got := render_default('> [!TIP]')
	assert got.contains('<blockquote role="note" data-callout="tip" data-callout-untitled>')
	assert got.contains('<p class="callout-badge">Tip</p>')
	assert !got.contains('<p class="callout-title">')
	assert got.ends_with('</blockquote>\n')
}

fn test_callout_title_inline_formatting() {
	got := render_default('> [!WARNING] **Bold** title\n> body')
	assert got.contains('<p class="callout-title"><strong>Bold</strong> title</p>')
}

fn test_callout_marker_only_on_first_line() {
	got := render_default('> Intro line.\n> [!NOTE] not a title\n> body')
	assert !got.contains('data-callout')
	assert got.contains('[!NOTE]')
}

fn test_hr() {
	assert render_default('---') == '<hr>\n'
	assert render_default('***') == '<hr>\n'
}

fn test_html_passthrough() {
	got := render_default('<div class="x">raw</div>\n')
	assert got.starts_with('<div class="x">'), got
}

fn test_escape_in_text() {
	got := render_default('a < b & c > d')
	assert got == '<p>a &lt; b &amp; c &gt; d</p>\n'
}

fn test_plain_strips_markup() {
	src := '# Title\n\nA *fast* [link](/x) and `code`.\n\n```bash\nignored\n```\n'
	p := plain(src)
	assert p.contains('Title')
	assert p.contains('A fast link and code.')
	// Code-block contents count as words (kept in plain + word_count).
	assert p.contains('ignored')
	assert !p.contains('`')
}

fn test_word_count_and_reading_time() {
	src := '# T\n\nOne two three four five.\n'
	assert word_count(src) == 6
	assert reading_time(src) == 1
}

fn test_codeblock_with_html_inside_is_escaped() {
	src := '```html\n<div>x</div>\n```\n'
	got := render_default(src)
	// chroma renders as token spans with escaped angle brackets; either
	// way the literal `<div>` must not appear unescaped in the output.
	assert !got.contains('<div>x</div>'), got
	assert got.contains('&lt;') && got.contains('div'), got
}

fn test_paragraph_break_on_blank_line() {
	got := render_default('A.\n\nB.')
	assert got == '<p>A.</p>\n<p>B.</p>\n'
}

fn test_multiple_blocks() {
	src := '# Title\n\nIntro.\n\n## Sub\n\n- a\n- b\n'
	got := render_default(src)
	assert got.starts_with('<h1 id="title">Title')
	assert got.contains('<p>Intro.</p>')
	assert got.contains('<h2 id="sub">Sub')
	assert got.contains('<ul>')
}
