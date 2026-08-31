// Module highlight applies syntax colouring to a code string by piping it
// through `chroma` (https://github.com/alecthomas/chroma) over stdin/stdout
// using an argv array — no shell is involved, so neither the binary path
// nor the language tag can be used to inject commands.
//
// Resolution order for the chroma binary:
//   1. `$VERNE_CHROMA_PATH` if set. The value is a directory; the dot `.` means
//      the directory of the running verne binary (chroma sitting next to it).
//   2. `$PATH` lookup.
//
// Defaults match what the reference theme expects: `style: github-dark`,
// `noClasses: false`, `lineNos: false`, `tabWidth: 2`.
module highlight

import os

pub const install_url = 'https://github.com/alecthomas/chroma#using-the-chroma-command'

pub struct Options {
pub:
	style      string = 'github-dark'
	no_classes bool
	line_nos   bool
	tab_width  int = 2
}

pub struct VerifyResult {
pub:
	found    bool
	path     string
	runnable bool
	version  string
	err      string
}

// resolve returns the absolute path to the chroma binary, or an empty
// string when it cannot be located. Honours `$VERNE_CHROMA_PATH` (a directory
// where `.` means "next to the verne binary") before falling back to
// the regular `$PATH` lookup.
pub fn resolve() string {
	if dir := os.getenv_opt('VERNE_CHROMA_PATH') {
		if dir != '' {
			base := if dir == '.' { os.dir(os.executable()) } else { dir }
			candidate := os.join_path(base, 'chroma')
			if os.is_executable(candidate) {
				return os.real_path(candidate)
			}
			return ''
		}
	}
	return os.find_abs_path_of_executable('chroma') or { '' }
}

// available reports whether the chroma binary can be located.
pub fn available() bool {
	return resolve() != ''
}

// verify locates the chroma binary and runs `chroma --version` to confirm
// it executes. Used by the CLI as a preflight check.
pub fn verify() VerifyResult {
	path := resolve()
	if path == '' {
		return VerifyResult{}
	}
	out, code := exec_argv(path, ['--version'], '') or {
		return VerifyResult{
			found: true
			path: path
			err: err.msg()
		}
	}
	if code != 0 {
		return VerifyResult{
			found: true
			path: path
			err: out.trim_space()
		}
	}
	return VerifyResult{
		found: true
		path: path
		runnable: true
		version: out.trim_space()
	}
}

// ensure_available is the preflight contract for any command whose output
// depends on chroma. Returns a descriptive error pointing at the install docs.
pub fn ensure_available() ! {
	r := verify()
	if !r.found {
		hint := if cp := os.getenv_opt('VERNE_CHROMA_PATH') {
			' (VERNE_CHROMA_PATH=${cp} did not yield a runnable `chroma`)'
		} else {
			''
		}
		return error('chroma binary not found${hint} — install it from ${install_url} or set VERNE_CHROMA_PATH to its directory')
	}
	if !r.runnable {
		return error('chroma at ${r.path} failed to run (${r.err}) — reinstall from ${install_url}')
	}
}

// run pipes `code` through chroma for `lang`. Returns the rendered HTML
// wrapped in `<div class="highlight">…</div>` so theme CSS targets it.
// If chroma is not installed or the lexer is unknown, falls back to a
// plain `<pre><code>` block.
pub fn run(code string, lang string, opts Options) !string {
	path := resolve()
	if path == '' {
		return fallback(code, lang)
	}
	if !valid_lang(lang) {
		return fallback(code, lang)
	}
	mut args := ['--html', '--html-only', '--lexer=${lang}', '--formatter=html',
		'--style=${opts.style}']
	if opts.no_classes {
		args << '--html-inline-styles'
	}
	if opts.line_nos {
		args << '--html-lines'
	}
	out, code_status := exec_argv(path, args, code) or { return fallback(code, lang) }
	if code_status != 0 {
		return fallback(code, lang)
	}
	body := out.trim_right('\n')
	// chroma emits `<pre class="chroma">…<code>…</code></pre>`; we decorate
	// the `<pre>` with `tabindex="0"`, attach `class="language-X"
	// data-lang="X"` to the bare `<code>`, and wrap the block in
	// `<div class="highlight">` so theme CSS can target it.
	mut decorated := body.replace_once('<pre class="chroma">', '<pre tabindex="0" class="chroma">')
	lang_attrs := ' class="language-${escape_attr(lang)}" data-lang="${escape_attr(lang)}"'
	decorated = decorated.replace_once('<code>', '<code${lang_attrs}>')
	return '<div class="highlight">' + decorated + '</div>'
}

// exec_argv spawns `path` with `args` (no shell), pipes `stdin_data` to its
// stdin, and returns (stdout, exit_code). Using argv + os.Process means
// neither the binary path nor any flag is interpreted by /bin/sh.
fn exec_argv(path string, args []string, stdin_data string) !(string, int) {
	mut p := os.new_process(path)
	p.set_args(args)
	p.set_redirect_stdio()
	p.run()
	if stdin_data != '' {
		p.stdin_write(stdin_data)
	}
	os.fd_close(p.stdio_fd[0])
	out := p.stdout_slurp()
	p.wait()
	code := p.code
	p.close()
	return out, code
}

fn fallback(code string, lang string) string {
	cls := if lang != '' { ' class="language-${escape_attr(lang)}"' } else { '' }
	return '<pre><code${cls}>${escape_html(code)}</code></pre>'
}

fn valid_lang(lang string) bool {
	if lang == '' || lang.len > 32 {
		return false
	}
	for c in lang {
		if !((c >= `a` && c <= `z`) || (c >= `A` && c <= `Z`) || (c >= `0` && c <= `9`) || c == `_` || c == `-` || c == `+`) {
			return false
		}
	}
	return true
}

fn escape_html(s string) string {
	return s.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')
}

fn escape_attr(s string) string {
	return escape_html(s).replace('"', '&quot;')
}
