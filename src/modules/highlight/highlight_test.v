module highlight

fn test_fallback_when_no_chroma() {
	out := fallback('echo hi', 'bash')
	assert out == '<pre><code class="language-bash">echo hi</code></pre>'
}

fn test_fallback_no_lang() {
	out := fallback('plain text', '')
	assert out == '<pre><code>plain text</code></pre>'
}

fn test_valid_lang_filter() {
	assert valid_lang('bash')
	assert valid_lang('c++')
	assert !valid_lang('')
	assert !valid_lang('a; rm -rf /')
	assert !valid_lang('with space')
}

fn test_html_escape_in_fallback() {
	out := fallback('<script>', 'html')
	assert out.contains('&lt;script&gt;')
}

fn test_verify_matches_available() {
	r := verify()
	assert r.found == available()
	if r.found {
		assert r.path != ''
		assert r.runnable
		assert r.version != ''
	}
}

fn test_ensure_available_when_present() {
	if !available() {
		return
	}
	ensure_available() or { assert false, 'ensure_available failed: ${err}' }
}
