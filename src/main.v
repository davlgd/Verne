// Verne — minimal static site generator written in V.
//
// Two real subcommands: `build` and `server`. Everything else (`version`,
// `help`) is a one-liner.
module main

import os
import time
import config
import content
import highlight
import meta
import render
import net
import net.http
import net.urllib

fn main() {
	args := os.args[1..]
	if args.len == 0 {
		print_usage()
		exit(2)
	}
	cmd := args[0]
	rest := args[1..]
	// Intercept `--help`/`-h` after a known subcommand so `verne build --help`
	// prints the topic-specific help instead of erroring as an unknown flag.
	if rest.len > 0 && rest[0] in ['--help', '-h']
		&& cmd in ['init', 'build', 'server', 'serve', 'clean'] {
		print_help(if cmd == 'serve' { 'server' } else { cmd })
		return
	}
	match cmd {
		'build' {
			cmd_build(rest) or { fail(err) }
		}
		'server', 'serve' {
			cmd_server(rest) or { fail(err) }
		}
		'clean' {
			cmd_clean(rest) or { fail(err) }
		}
		'init' {
			cmd_init(rest) or { fail(err) }
		}
		'version' {
			println('verne ${meta.version}')
		}
		'--version', '-v' {
			eprintln('verne: `${cmd}` is not a flag — did you mean `verne version`?')
			exit(2)
		}
		'help', '--help', '-h' {
			topic := if rest.len > 0 { rest[0] } else { '' }
			normalised := if topic == 'serve' { 'server' } else { topic }
			if normalised != '' && normalised !in ['init', 'build', 'server', 'clean'] {
				eprintln('verne: unknown help topic `${topic}` (expected init, build, server, or clean)')
				exit(2)
			}
			print_help(normalised)
		}
		else {
			eprintln('verne: unknown command `${cmd}` — try `verne help`')
			exit(2)
		}
	}
}

fn print_usage() {
	print_help('')
}

// print_help renders the usage, optionally focused on one subcommand. With an
// empty topic it prints the full reference (default `verne` and `verne help`
// behaviour); with `init`, `build`, `server`, or `clean` it prints just that
// subcommand's flags so `verne help build` and `verne build --help` give a
// short, on-topic page.
fn print_help(topic string) {
	println('verne ${meta.version} — minimal static site generator')
	println('')
	if topic == '' {
		println('Usage:')
		println('  verne init   [DIR] [flags]   scaffold a new site (interactive on a TTY)')
		println('  verne build  [DIR] [flags]   build the site to <DIR>/public/')
		println('  verne server [DIR] [flags]   serve <DIR>/public/ over HTTP (default :1313)')
		println('  verne clean  [DIR] [flags]   remove the build output')
		println('  verne version                print the version')
		println('  verne help [SUBCOMMAND]      print full or per-subcommand help')
		println('')
	}
	if topic == '' || topic in ['init', 'build', 'server', 'clean'] {
		println('Common flags:')
		println('  DIR                   project root (defaults to current directory)')
		println('  -r, --root DIR        same as positional DIR')
		if topic != 'init' {
			println('  -c, --config FILE     load a specific config file instead of <DIR>/verne.yaml')
			println('                        (mutually exclusive with DIR/-r)')
		}
		println('')
	}
	if topic == '' || topic == 'init' {
		println('init flags:')
		println('  --title T             site title')
		println('  --theme N             bundle a starter theme named N (default: scaffold one)')
		println('  -u, --base-url URL    site base URL')
		println('  -l, --locale L        content locale (e.g. en-us)')
		println('  --tagline T           short tagline shown on the home page')
		println('  -y, --yes             accept all defaults — skip the interactive prompts')
		println('  -f, --force           scaffold into a non-empty directory (overwrites verne.yaml)')
		println('')
	}
	if topic == '' || topic in ['build', 'server'] {
		header := if topic == '' { 'build / server flags:' } else { '${topic} flags:' }
		println(header)
		println('  -u, --base-url URL    override the baseURL from verne.yaml')
		println('  -o, --output-dir DIR  override the output directory (defaults to <DIR>/public)')
	}
	if topic == '' || topic == 'server' {
		if topic == '' {
			println('')
			println('server flags:')
		}
		println('  -p, --port N          listen port (default 1313)')
		println('  --open                open the served URL in the default browser')
		println('')
	}
	if topic == '' || topic == 'clean' {
		println('clean flags:')
		println('  -o, --output-dir DIR  remove this directory instead of cfg.output_dir')
		println('  --all                 also remove caches under <DIR>/.cache/')
	}
}

// load_cfg resolves a project root or explicit config file from CLI args.
// Returns the loaded config plus the index after the consumed args.
fn load_cfg(dir string, config_file string) !config.Config {
	if config_file != '' {
		return config.load_file(config_file)!
	}
	root := if dir != '' { os.real_path(dir) } else { os.getwd() }
	if !os.is_dir(root) {
		return error('not a directory: `${root}`')
	}
	return config.load(root)!
}

fn fail(err IError) {
	eprintln('verne: ${err}')
	exit(1)
}

// parse_port accepts a decimal port number in 1..65535. Rejects empty
// strings, leading signs, embedded non-digits, and leading whitespace —
// `string.int()` alone would silently coerce `+80`/`80abc`/` 80` to a
// number and let an invalid value reach `net.listen_tcp`.
fn parse_port(raw string) !int {
	if raw == '' {
		return error('empty')
	}
	for c in raw {
		if c < `0` || c > `9` {
			return error('non-digit `${c.ascii_str()}`')
		}
	}
	n := raw.int()
	if n < 1 || n > 65535 {
		return error('out of range')
	}
	return n
}

// resolve_output_dir normalises a CLI -o value: absolute paths pass through,
// relative paths resolve against the project root (not cwd) so
// `verne build /path/to/site -o out` writes under the site, not next to the
// shell's working directory. Uses `os.norm_path` (syntactic) rather than
// `os.real_path` (filesystem-walking) because the target directory typically
// does not exist yet at this point — `real_path` would leave `..` segments
// in place and let an output-dir slip past the project-root bounds check.
fn resolve_output_dir(raw string, root string) string {
	joined := if os.is_abs_path(raw) { raw } else { os.join_path(root, raw) }
	return os.norm_path(joined)
}

fn cmd_build(args []string) ! {
	mut dir := ''
	mut config_file := ''
	mut base_url := ''
	mut output_dir := ''
	mut i := 0
	for i < args.len {
		a := args[i]
		match a {
			'-c', '--config' {
				i++
				if i >= args.len {
					return error('build: ${a} requires a value')
				}
				config_file = args[i]
			}
			'-r', '--root' {
				i++
				if i >= args.len {
					return error('build: ${a} requires a value')
				}
				if dir != '' {
					return error('build: ${a} conflicts with positional DIR')
				}
				dir = args[i]
			}
			'-u', '--base-url' {
				i++
				if i >= args.len {
					return error('build: ${a} requires a value')
				}
				base_url = args[i]
			}
			'-o', '--output-dir' {
				i++
				if i >= args.len {
					return error('build: ${a} requires a value')
				}
				output_dir = args[i]
			}
			else {
				if a.starts_with('-') {
					return error('build: unknown flag `${a}`')
				}
				if dir != '' {
					return error('build: unexpected argument `${a}`')
				}
				dir = a
			}
		}

		i++
	}
	if config_file != '' && dir != '' {
		return error('build: -c/--config and DIR/-r are mutually exclusive (the config file pins its own root)')
	}
	highlight.ensure_available()!
	t_start := time.now()
	mut cfg := load_cfg(dir, config_file)!
	if base_url != '' {
		config.validate_base_url(base_url)!
		cfg.base_url = base_url
	}
	if output_dir != '' {
		cfg.output_dir = resolve_output_dir(output_dir, cfg.root)
	}
	out := if cfg.output_dir != '' { cfg.output_dir } else { os.join_path(cfg.root, 'public') }
	render.assert_output_under_root(out, cfg.root)!
	site := content.build_site(cfg)!
	mut renderer := render.new(cfg, site)!
	count := renderer.build()!
	dur := time.now() - t_start
	println('Built ${count} pages in ${dur.milliseconds()}ms → ${os.real_path(out)}/')
}

fn cmd_init(args []string) ! {
	mut dir := ''
	mut title := ''
	mut theme := ''
	mut base_url := ''
	mut locale := ''
	mut tagline := ''
	mut force := false
	mut yes := false
	mut i := 0
	for i < args.len {
		a := args[i]
		match a {
			'--title' {
				i++
				if i >= args.len {
					return error('init: ${a} requires a value')
				}
				title = args[i]
			}
			'--theme' {
				i++
				if i >= args.len {
					return error('init: ${a} requires a value')
				}
				theme = args[i]
			}
			'--base-url', '-u' {
				i++
				if i >= args.len {
					return error('init: ${a} requires a value')
				}
				base_url = args[i]
			}
			'--locale', '-l' {
				i++
				if i >= args.len {
					return error('init: ${a} requires a value')
				}
				locale = args[i]
			}
			'--tagline' {
				i++
				if i >= args.len {
					return error('init: ${a} requires a value')
				}
				tagline = args[i]
			}
			'--force', '-f' {
				force = true
			}
			'--yes', '-y' {
				yes = true
			}
			else {
				if a.starts_with('-') {
					return error('init: unknown flag `${a}`')
				}
				if dir != '' {
					return error('init: unexpected argument `${a}`')
				}
				dir = a
			}
		}

		i++
	}
	target := if dir == '' { os.getwd() } else { os.real_path(dir) }
	if os.exists(target) {
		if !os.is_dir(target) {
			return error('init: ${target} exists and is not a directory')
		}
		entries := os.ls(target) or { []string{} }
		visible := entries.filter(!it.starts_with('.'))
		if visible.len > 0 && !force {
			return error('init: ${target} is not empty (use --force to scaffold anyway)')
		}
	} else {
		os.mkdir_all(target) or { return error('init: cannot create ${target} (${err})') }
	}
	// Mirror mdBook / Zola: when stdin is a TTY and no `--yes` was passed,
	// prompt for the bits that are tedious to retype later. Anything already
	// supplied via flags skips its prompt — that keeps the command scriptable.
	interactive := !yes && os.is_atty(0) > 0
	if interactive {
		if title == '' {
			title = prompt_with_default('Site title', 'My Verne site')
		}
		if base_url == '' {
			base_url = prompt_with_default('Base URL', 'http://localhost:1313/')
		}
		if locale == '' {
			locale = prompt_with_default('Locale', 'en')
		}
		if tagline == '' {
			tagline = prompt_with_default('Tagline (optional, blank to skip)', '')
		}
		if theme == '' {
			ans := prompt_with_default('Bundle the default theme? (Y/n)', 'Y')
			if ans.to_lower().starts_with('n') {
				theme = prompt_with_default('Theme name (will be referenced from verne.yaml; you provide the files)',
					'custom')
			}
		}
	}
	if title == '' {
		title = 'My Verne site'
	}
	if base_url == '' {
		base_url = 'http://localhost:1313/'
	}
	if locale == '' {
		locale = 'en'
	}
	// `--theme X` opts out of the bundled default — the user is bringing
	// their own theme. We still create the parent `themes/` dir and write
	// the chosen name into verne.yaml, but we don't scaffold any files
	// inside `themes/X/`.
	theme_name := if theme != '' { theme } else { 'default' }
	scaffold_default_theme := theme == ''
	theme_dir := os.join_path(target, 'themes', theme_name)
	mut subs := ['content/posts', 'static', 'themes']
	if scaffold_default_theme {
		subs << os.join_path('themes', theme_name, 'templates/_default')
		subs << os.join_path('themes', theme_name, 'templates/partials')
		subs << os.join_path('themes', theme_name, 'assets/css')
		subs << os.join_path('themes', theme_name, 'assets/js')
	}
	for sub in subs {
		os.mkdir_all(os.join_path(target, sub)) or { return error('init: ${err}') }
	}
	cfg_path := os.join_path(target, 'verne.yaml')
	if !os.exists(cfg_path) || force {
		if os.exists(cfg_path) {
			eprintln('init: overwriting verne.yaml (--force); existing content/, themes/, and other files left untouched')
		}
		os.write_file(cfg_path, scaffold_config(title, theme_name, base_url, locale, tagline)) or {
			return error('init: cannot write verne.yaml (${err})')
		}
	}
	gi_path := os.join_path(target, '.gitignore')
	if !os.exists(gi_path) {
		os.write_file(gi_path, '/public/\n/.cache/\n') or {
			return error('init: cannot write .gitignore (${err})')
		}
	}
	for rel, body in scaffold_content_files() {
		full := os.join_path(target, rel)
		os.mkdir_all(os.dir(full)) or { return error('init: ${err}') }
		if !os.exists(full) {
			os.write_file(full, body) or { return error('init: cannot write ${rel} (${err})') }
		}
	}
	if scaffold_default_theme {
		// Only scaffold the theme files when the directory is fresh — never
		// stomp on a user's customised theme on a re-run with --force.
		for path, body in scaffold_theme_files() {
			full := os.join_path(theme_dir, path)
			if !os.exists(full) {
				os.write_file(full, body) or { return error('init: cannot write ${path} (${err})') }
			}
		}
	}
	in_cwd := target == os.getwd()
	println('Scaffolded Verne site in ${target}')
	if scaffold_default_theme {
		if in_cwd {
			println('Next: verne server')
		} else {
			println('Next: cd ${target} && verne server')
		}
	} else {
		theme_path := os.join_path(target, 'themes', theme_name)
		build_arg := if in_cwd { '' } else { ' ${target}' }
		println('Next: drop your `${theme_name}` theme into ${theme_path}/ and run `verne build${build_arg}`')
	}
}

fn scaffold_config(title string, theme string, base_url string, locale string, tagline string) string {
	tag := if tagline == '' { 'A small place on the web.' } else { tagline }
	return 'title: ${yaml_escape(title)}
baseURL: ${yaml_escape(base_url)}
locale: ${yaml_escape(locale)}
theme: ${yaml_escape(theme)}

permalinks:
  posts: "/posts/:slug/"

params:
  tagline: ${yaml_escape(tag)}

  # How many posts to show on the home page. Anything past this number
  # is reachable from the "All writing →" link. Default: 5.
  recent_posts_limit: 5
'
}

// yaml_escape produces a safely-quoted YAML scalar. Plain identifiers stay
// bare; anything containing whitespace, quotes, colons, or leading/trailing
// punctuation gets wrapped in double quotes with `\` and `"` escaped.
fn yaml_escape(s string) string {
	if s == '' {
		return '""'
	}
	// YAML indicators at the start of a scalar change its parse type
	// (`- foo` becomes a sequence, `? foo` a complex key, `[`/`{` flow
	// collections, `*`/`&` aliases, `!` a tag, `|`/`>` block scalars,
	// `@`/`` ` `` reserved, `%` a directive). Always quote when the first
	// byte is one of those, even if the rest is harmless.
	mut needs_quotes := s[0] in [u8(`-`), `?`, `[`, `]`, `{`, `}`, `,`, `*`, `&`, `!`, `|`, `>`,
		`@`, `\``, `%`]
	if !needs_quotes {
		for c in s {
			if c == ` ` || c == `:` || c == `#` || c == `'` || c == `"` || c == `\\` || c < 0x20 {
				needs_quotes = true
				break
			}
		}
	}
	if !needs_quotes {
		return s
	}
	mut out := '"'
	for c in s {
		match c {
			`"` {
				out += '\\"'
			}
			`\\` {
				out += '\\\\'
			}
			`\n` {
				out += '\\n'
			}
			`\r` {
				out += '\\r'
			}
			`\t` {
				out += '\\t'
			}
			else {
				if c < 0x20 {
					out += '\\x${c:02x}'
				} else {
					out += c.ascii_str()
				}
			}
		}
	}
	out += '"'
	return out
}

fn prompt_with_default(prompt string, default_value string) string {
	suffix := if default_value == '' { '' } else { ' [${default_value}]' }
	print('${prompt}${suffix}: ')
	os.flush()
	answer := os.get_line().trim_space()
	if answer == '' {
		return default_value
	}
	return answer
}

fn scaffold_theme_files() map[string]string {
	return {
		'templates/index.html':           scaffold_tpl_index()
		'templates/_default/single.html': scaffold_tpl_single()
		'templates/_default/list.html':   scaffold_tpl_list()
		'templates/partials/head.html':   scaffold_tpl_head()
		'templates/partials/header.html': scaffold_tpl_header()
		'templates/partials/footer.html': scaffold_tpl_footer()
		'assets/css/fonts.css':           '/* Default theme uses the system font stack. */\n'
		'assets/css/style.css':           scaffold_css()
		'assets/js/app.js':               '/* Default theme JS placeholder. */\n'
	}
}

fn scaffold_tpl_index() string {
	return '<!doctype html>
<html lang="{{ site.language }}">
<head>
{% include "partials/head.html" %}
</head>
<body>
{% include "partials/header.html" %}
<main id="main" class="container">
  <section class="lede">
    <h1>{{ site.title }}</h1>
    {%- if site.params.tagline %}
    <p>{{ site.params.tagline }}</p>
    {%- endif %}
  </section>
  <section class="entries" aria-labelledby="entries-title">
    <h2 id="entries-title" class="eyebrow">Recent writing</h2>
    <ol class="entry-list" reversed>
      {%- for p in site.recent_posts %}
      <li class="entry">
        <a class="entry-link" href="{{ p.relpermalink }}">
          <time class="entry-date" datetime="{{ p.date | format_date("2006-01-02") }}">{{ p.date | format_date("Jan 2, 2006") }}</time>
          <span class="entry-title">{{ p.title }}</span>
        </a>
        {%- if p.description %}
        <p class="entry-summary">{{ p.description }}</p>
        {%- endif %}
      </li>
      {%- endfor %}
    </ol>
    {%- if site.has_more_posts %}
    <p class="see-all"><a href="/posts/">All posts →</a></p>
    {%- endif %}
  </section>
</main>
{% include "partials/footer.html" %}
</body>
</html>
'
}

fn scaffold_tpl_single() string {
	return '<!doctype html>
<html lang="{{ site.language }}">
<head>
{% include "partials/head.html" %}
</head>
<body>
{% include "partials/header.html" %}
<main id="main" class="container">
  <article class="prose">
    <header class="prose-head">
      <h1>{{ page.title }}</h1>
      {%- if page.section == "posts" %}
      <p class="prose-meta">
        <time datetime="{{ page.date | format_date("2006-01-02") }}">{{ page.date | format_date("January 2, 2006") }}</time>
        <span class="sep" aria-hidden="true">/</span>
        <span>{{ page.reading_time }} min</span>
        {%- if page.tags %}
        <span class="sep" aria-hidden="true">/</span>
        <span class="prose-tags">
          {%- for t in page.tags -%}
          {%- if not loop.first %}, {% endif -%}
          <span>{{ t }}</span>
          {%- endfor -%}
        </span>
        {%- endif %}
      </p>
      {%- endif %}
    </header>
    <div class="prose-body">
      {{ page.content }}
    </div>
  </article>
  {%- if page.section == "posts" and ((page.prev_in_section is defined and page.prev_in_section is not none) or (page.next_in_section is defined and page.next_in_section is not none)) %}
  <nav class="prose-nav" aria-label="Adjacent posts">
    {%- if page.prev_in_section is defined and page.prev_in_section is not none %}
    <a class="prose-nav-prev" rel="prev" href="{{ page.prev_in_section.relpermalink }}">
      <span class="prose-nav-eyebrow">Earlier</span>
      <span class="prose-nav-title">{{ page.prev_in_section.title }}</span>
    </a>
    {%- endif %}
    {%- if page.next_in_section is defined and page.next_in_section is not none %}
    <a class="prose-nav-next" rel="next" href="{{ page.next_in_section.relpermalink }}">
      <span class="prose-nav-eyebrow">Later</span>
      <span class="prose-nav-title">{{ page.next_in_section.title }}</span>
    </a>
    {%- endif %}
  </nav>
  {%- endif %}
</main>
{% include "partials/footer.html" %}
</body>
</html>
'
}

fn scaffold_tpl_list() string {
	return '<!doctype html>
<html lang="{{ site.language }}">
<head>
{% include "partials/head.html" %}
</head>
<body>
{% include "partials/header.html" %}
<main id="main" class="container">
  <section class="lede">
    <h1>{{ page.title }}</h1>
    {%- if page.description %}
    <p>{{ page.description }}</p>
    {%- endif %}
  </section>
  {%- if page.content %}
  <div class="prose-body lede-body">{{ page.content }}</div>
  {%- endif %}
  <ol class="entry-list" reversed>
    {%- for p in page.pages %}
    <li class="entry">
      <a class="entry-link" href="{{ p.relpermalink }}">
        <time class="entry-date" datetime="{{ p.date | format_date("2006-01-02") }}">{{ p.date | format_date("Jan 2, 2006") }}</time>
        <span class="entry-title">{{ p.title }}</span>
      </a>
      {%- if p.description %}
      <p class="entry-summary">{{ p.description }}</p>
      {%- endif %}
    </li>
    {%- endfor %}
  </ol>
</main>
{% include "partials/footer.html" %}
</body>
</html>
'
}

fn scaffold_tpl_head() string {
	return '<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<meta name="color-scheme" content="light dark">
<meta name="theme-color" content="#fbfaf7" media="(prefers-color-scheme: light)">
<meta name="theme-color" content="#0f1012" media="(prefers-color-scheme: dark)">
<title>{% if not page.is_home %}{{ page.title }} · {% endif %}{{ site.title }}</title>
<meta name="description" content="{{ page.meta_description }}">
<meta name="generator" content="{{ site.generator }}">
<link rel="canonical" href="{{ page.permalink }}">
<link rel="alternate" type="application/rss+xml" title="{{ site.title }}" href="/index.xml">
<meta property="og:type" content="{{ page.og_type }}">
<meta property="og:title" content="{{ page.title }}">
<meta property="og:description" content="{{ page.meta_description }}">
<meta property="og:url" content="{{ page.permalink }}">
<meta property="og:site_name" content="{{ site.title }}">
<meta property="og:locale" content="{{ site.language_code }}">
<meta name="twitter:card" content="summary">
<link rel="stylesheet" href="{{ assets.css_url }}" integrity="{{ assets.css_integrity }}" crossorigin="anonymous">
<script defer src="{{ assets.js_url }}" integrity="{{ assets.js_integrity }}" crossorigin="anonymous"></script>
'
}

fn scaffold_tpl_header() string {
	return '<a class="skip-link" href="#main">Skip to content</a>
<header class="site-header" role="banner">
  <div class="container row">
    <a class="brand" href="/" rel="home">{{ site.title }}</a>
    <nav aria-label="Primary">
      <a href="/"{% if page.is_home %} aria-current="page"{% endif %}>Home</a>
      <a href="/posts/"{% if page.section == "posts" %} aria-current="page"{% endif %}>Posts</a>
      <a href="/about/"{% if page.relpermalink == "/about/" %} aria-current="page"{% endif %}>About</a>
    </nav>
  </div>
</header>
'
}

fn scaffold_tpl_footer() string {
	return '<footer class="site-footer" role="contentinfo">
  <div class="container row">
    <p class="copyright">© {{ now.year }} {{ site.title }}</p>
    <p class="colophon"><a href="/index.xml" rel="alternate" type="application/rss+xml">RSS</a></p>
  </div>
</footer>
'
}

fn scaffold_css() string {
	return '/*
  Verne default theme.
  An editorial, sober scaffold — meant to read well first, look styled second.
  Pick your accent in `:root` and the rest follows.
*/

/* --------------------------------------------------------------------------
   Tokens
   -------------------------------------------------------------------------- */

:root {
  /* Type. We stay on the system stack (cleaner across OSes than yet another
     web font swap) and lean on OpenType for the typographic finish. */
  --font-ui: ui-sans-serif, system-ui, -apple-system, "Segoe UI", Roboto,
             "Helvetica Neue", Arial, sans-serif;
  --font-prose: "Iowan Old Style", "Source Serif Pro", "Apple Garamond",
                Cambria, Georgia, serif;
  --font-mono: ui-monospace, "SF Mono", "JetBrains Mono", "Fira Code",
               "Cascadia Code", Menlo, Consolas, monospace;

  /* Modular scale, manually picked — not a generated 1.25 ramp. */
  --step-0:  1.0625rem;   /* 17px body UI */
  --step-prose: 1.125rem; /* 18px article body */
  --step-1:  1.1875rem;
  --step-2:  1.4375rem;
  --step-3:  1.75rem;
  --step-4:  2.375rem;
  --step-display: clamp(2.375rem, 4.5vw + 1rem, 3.5rem);

  --leading-tight: 1.18;
  --leading-snug: 1.35;
  --leading-prose: 1.7;
  --measure: 38rem;       /* prose measure — about 70 characters */
  --gutter: clamp(1.25rem, 4vw, 2rem);

  /* Light palette — warm off-white, deep slate ink, indigo-aubergine accent.
     Contrast on --bg: ink 14:1, ink-muted 5.5:1, ink-faint 4.6:1 (all WCAG AA). */
  --bg: #fbfaf7;
  --bg-sunk: #f3f1eb;
  --ink: #1d1d1f;
  --ink-muted: #56544f;
  --ink-faint: #6e6b65;
  --rule: #d8d4ca;
  --rule-soft: #ece8de;
  --accent: oklch(45% 0.15 280);
  --accent-ink: oklch(38% 0.13 280);
  --selection: oklch(82% 0.10 280 / 0.6);
}

@media (prefers-color-scheme: dark) {
  :root {
    --bg: #0f1012;
    --bg-sunk: #16181b;
    --ink: #e8e6e1;
    --ink-muted: #b1ada4;
    --ink-faint: #8b8780;
    --rule: #2c2e32;
    --rule-soft: #1c1e21;
    --accent: oklch(78% 0.13 270);
    --accent-ink: oklch(86% 0.10 270);
    --selection: oklch(60% 0.12 270 / 0.5);
  }
}

/* --------------------------------------------------------------------------
   Reset
   -------------------------------------------------------------------------- */

*, *::before, *::after { box-sizing: border-box; }
* { margin: 0; }

html {
  -webkit-text-size-adjust: 100%;
  text-rendering: optimizeLegibility;
  font-feature-settings: "kern", "liga", "calt";
  font-variant-ligatures: common-ligatures contextual;
}

body {
  font-family: var(--font-ui);
  font-size: var(--step-0);
  line-height: var(--leading-snug);
  color: var(--ink);
  background: var(--bg);
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
  display: flex;
  flex-direction: column;
  min-height: 100svh;
  padding-inline: env(safe-area-inset-left) env(safe-area-inset-right);
}

::selection { background: var(--selection); }

img, svg, video { max-width: 100%; display: block; }
hr { border: 0; border-top: 1px solid var(--rule); margin-block: 2.5rem; }
:focus { outline: none; }
:focus-visible {
  outline: 2px solid var(--accent);
  outline-offset: 3px;
  border-radius: 2px;
}

a {
  color: inherit;
  text-decoration-color: var(--ink-faint);
  text-decoration-thickness: 1px;
  text-underline-offset: 0.18em;
  text-decoration-skip-ink: auto;
  transition: text-decoration-color 120ms ease, color 120ms ease;
}
a:hover { color: var(--accent-ink); text-decoration-color: currentColor; }

/* --------------------------------------------------------------------------
   Layout primitives
   -------------------------------------------------------------------------- */

.container {
  width: 100%;
  max-width: 56rem;
  margin-inline: auto;
  padding-inline: var(--gutter);
}
.row {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  gap: 1.5rem;
  flex-wrap: wrap;
}

.skip-link {
  position: absolute;
  top: 0.5rem;
  left: 0.5rem;
  padding: 0.5rem 0.875rem;
  background: var(--ink);
  color: var(--bg);
  text-decoration: none;
  font-size: 0.875rem;
  border-radius: 4px;
  transform: translateY(-150%);
  transition: transform 100ms ease;
  z-index: 50;
}
.skip-link:focus { transform: translateY(0); }

/* --------------------------------------------------------------------------
   Header & footer
   -------------------------------------------------------------------------- */

.site-header {
  padding-block: 1.75rem 1.25rem;
  border-bottom: 1px solid var(--rule-soft);
}
.site-header .brand {
  font-family: var(--font-ui);
  font-size: 0.875rem;
  font-weight: 600;
  letter-spacing: 0.06em;
  text-transform: uppercase;
  text-decoration: none;
  color: var(--ink);
}
.site-header .brand:hover { color: var(--accent-ink); }
.site-header nav {
  display: flex;
  gap: 1.5rem;
  font-size: 0.9375rem;
}
.site-header nav a {
  text-decoration: none;
  color: var(--ink-muted);
  padding-block: 0.125rem;
  border-bottom: 1px solid transparent;
}
.site-header nav a:hover { color: var(--ink); }
.site-header nav a[aria-current="page"] {
  color: var(--ink);
  border-bottom-color: var(--ink);
}

.site-footer {
  margin-top: auto;
  padding-block: 2rem 2.5rem;
  border-top: 1px solid var(--rule-soft);
  color: var(--ink-faint);
  font-size: 0.8125rem;
}
.site-footer .copyright { letter-spacing: 0.02em; }
.site-footer a {
  text-decoration: underline;
  text-decoration-color: var(--rule);
}
.site-footer a:hover { text-decoration-color: currentColor; }

/* --------------------------------------------------------------------------
   Main column
   -------------------------------------------------------------------------- */

main.container {
  flex: 1;
  padding-block: clamp(2.5rem, 6vw, 5rem) clamp(3rem, 8vw, 6rem);
}

/* --------------------------------------------------------------------------
   Lede (home / list intro)
   -------------------------------------------------------------------------- */

.lede {
  max-width: 32rem;
  margin-bottom: clamp(2.5rem, 6vw, 4.5rem);
}
.lede h1 {
  font-family: var(--font-ui);
  font-size: var(--step-display);
  font-weight: 600;
  line-height: var(--leading-tight);
  letter-spacing: -0.025em;
  text-wrap: balance;
  color: var(--ink);
}
.lede p {
  margin-top: 1rem;
  font-family: var(--font-prose);
  font-size: var(--step-2);
  line-height: 1.45;
  color: var(--ink-muted);
  text-wrap: pretty;
}
.lede-body { margin-bottom: clamp(2rem, 4vw, 3rem); max-width: var(--measure); }

.eyebrow {
  font-family: var(--font-ui);
  font-size: 0.75rem;
  font-weight: 600;
  letter-spacing: 0.12em;
  text-transform: uppercase;
  color: var(--ink-faint);
  margin-bottom: 1.25rem;
}

/* --------------------------------------------------------------------------
   Entry list (editorial: date in margin on desktop, stacked on mobile)
   -------------------------------------------------------------------------- */

.entry-list {
  list-style: none;
  padding: 0;
  border-top: 1px solid var(--rule-soft);
}
.entry {
  padding-block: 1.5rem;
  border-bottom: 1px solid var(--rule-soft);
}
.entry-link {
  display: grid;
  grid-template-columns: 1fr;
  gap: 0.25rem;
  align-items: baseline;
  text-decoration: none;
  color: inherit;
}
.entry-date {
  font-family: var(--font-ui);
  font-size: 0.8125rem;
  letter-spacing: 0.04em;
  font-variant-numeric: tabular-nums;
  text-transform: uppercase;
  color: var(--ink-faint);
}
.entry-title {
  font-family: var(--font-ui);
  font-size: var(--step-2);
  font-weight: 600;
  letter-spacing: -0.015em;
  line-height: var(--leading-snug);
  color: var(--ink);
  text-wrap: balance;
}
.entry-link:hover .entry-title {
  color: var(--accent-ink);
  text-decoration: underline;
  text-decoration-thickness: 1px;
  text-underline-offset: 0.2em;
}
.entry-summary {
  margin-top: 0.5rem;
  font-family: var(--font-prose);
  font-size: var(--step-0);
  line-height: 1.55;
  color: var(--ink-muted);
  max-width: var(--measure);
  text-wrap: pretty;
}

@media (min-width: 48rem) {
  .entry-link {
    grid-template-columns: 7.5rem minmax(0, 1fr);
    column-gap: 2.5rem;
  }
  .entry-date { padding-top: 0.35rem; }
  .entry-summary { padding-inline-start: calc(7.5rem + 2.5rem); }
}

.see-all {
  margin-top: 2rem;
  font-family: var(--font-ui);
  font-size: 0.9375rem;
}
.see-all a {
  color: var(--ink-muted);
  text-decoration-color: var(--rule);
  letter-spacing: 0.01em;
}
.see-all a:hover { color: var(--accent-ink); text-decoration-color: currentColor; }

/* --------------------------------------------------------------------------
   Prose (article body)
   -------------------------------------------------------------------------- */

.prose { max-width: var(--measure); }
.prose-head { margin-bottom: 2rem; }
.prose-head h1 {
  font-family: var(--font-ui);
  font-size: var(--step-4);
  font-weight: 600;
  line-height: var(--leading-tight);
  letter-spacing: -0.02em;
  text-wrap: balance;
  color: var(--ink);
}
.prose-meta {
  margin-top: 0.875rem;
  display: flex;
  flex-wrap: wrap;
  gap: 0.5rem 0.75rem;
  align-items: baseline;
  font-family: var(--font-ui);
  font-size: 0.8125rem;
  letter-spacing: 0.04em;
  text-transform: uppercase;
  color: var(--ink-faint);
}
.prose-meta time { font-variant-numeric: tabular-nums; }
.prose-meta .sep { color: var(--ink-faint); opacity: 0.5; }
.prose-meta .prose-tags { text-transform: none; letter-spacing: 0.02em; font-style: italic; }

.prose-body {
  font-family: var(--font-prose);
  font-size: var(--step-prose);
  line-height: var(--leading-prose);
  color: var(--ink);
  hyphens: auto;
  -webkit-hyphens: auto;
  text-wrap: pretty;
}
.prose-body > * + * { margin-top: 1.1em; }
.prose-body h2,
.prose-body h3,
.prose-body h4 {
  font-family: var(--font-ui);
  font-weight: 600;
  letter-spacing: -0.015em;
  line-height: var(--leading-snug);
  color: var(--ink);
  margin-top: 2.25em;
  text-wrap: balance;
}
.prose-body h2 { font-size: var(--step-3); }
.prose-body h3 { font-size: var(--step-2); }
.prose-body h4 { font-size: var(--step-1); }
.prose-body h2 a.anchor,
.prose-body h3 a.anchor,
.prose-body h4 a.anchor {
  margin-inline-start: 0.4em;
  color: var(--ink-faint);
  font-weight: 400;
  text-decoration: none;
  opacity: 0;
  transition: opacity 100ms ease;
}
.prose-body h2:hover a.anchor,
.prose-body h3:hover a.anchor,
.prose-body h4:hover a.anchor { opacity: 1; }

.prose-body p { text-wrap: pretty; }
.prose-body a {
  color: var(--accent-ink);
  text-decoration-color: var(--accent);
  text-decoration-thickness: 1px;
  text-underline-offset: 0.22em;
}
.prose-body a:hover { text-decoration-thickness: 2px; }

.prose-body blockquote {
  margin-inline: 0;
  padding-inline-start: 1.25rem;
  border-inline-start: 2px solid var(--ink-faint);
  font-style: italic;
  color: var(--ink-muted);
}
.prose-body blockquote > * + * { margin-top: 0.6em; }

.prose-body ul, .prose-body ol { padding-inline-start: 1.4em; }
.prose-body li + li { margin-top: 0.25em; }
.prose-body li::marker { color: var(--ink-faint); }

.prose-body :not(pre) > code {
  font-family: var(--font-mono);
  font-size: 0.85em;
  padding: 0.1em 0.4em;
  background: var(--bg-sunk);
  border: 1px solid var(--rule-soft);
  border-radius: 3px;
  hyphens: none;
}
.prose-body pre {
  font-family: var(--font-mono);
  font-size: 0.875rem;
  line-height: 1.55;
  background: var(--bg-sunk);
  color: var(--ink);
  border: 1px solid var(--rule-soft);
  border-radius: 4px;
  padding: 1rem 1.125rem;
  overflow-x: auto;
  hyphens: none;
}
.prose-body pre code { font-size: inherit; padding: 0; background: none; border: none; }

.prose-body figure { margin-block: 2em; }
.prose-body figcaption {
  margin-top: 0.5rem;
  font-family: var(--font-ui);
  font-size: 0.8125rem;
  color: var(--ink-faint);
  text-align: center;
}

.prose-body img {
  border-radius: 2px;
  max-width: 100%;
  height: auto;
}

.prose-body table {
  width: 100%;
  border-collapse: collapse;
  font-size: 0.95em;
}
.prose-body th, .prose-body td {
  text-align: start;
  padding: 0.5rem 0.75rem;
  border-bottom: 1px solid var(--rule-soft);
}
.prose-body th {
  font-family: var(--font-ui);
  font-weight: 600;
  letter-spacing: 0.02em;
  color: var(--ink);
}

/* --------------------------------------------------------------------------
   Prev / next
   -------------------------------------------------------------------------- */

.prose-nav {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 1.5rem;
  margin-top: clamp(3rem, 6vw, 5rem);
  padding-top: 2rem;
  border-top: 1px solid var(--rule-soft);
  max-width: var(--measure);
}
.prose-nav a {
  display: flex;
  flex-direction: column;
  gap: 0.25rem;
  text-decoration: none;
  color: var(--ink);
}
.prose-nav-eyebrow {
  font-family: var(--font-ui);
  font-size: 0.75rem;
  letter-spacing: 0.1em;
  text-transform: uppercase;
  color: var(--ink-faint);
}
.prose-nav-title {
  font-family: var(--font-ui);
  font-size: var(--step-1);
  font-weight: 600;
  letter-spacing: -0.01em;
  text-wrap: balance;
}
.prose-nav-prev .prose-nav-eyebrow::before { content: "← "; }
.prose-nav-next { text-align: end; align-items: flex-end; }
.prose-nav-next .prose-nav-eyebrow::after { content: " →"; }
.prose-nav a:hover .prose-nav-title {
  color: var(--accent-ink);
  text-decoration: underline;
  text-decoration-thickness: 1px;
  text-underline-offset: 0.22em;
}

@media (max-width: 36rem) {
  .prose-nav { grid-template-columns: 1fr; }
  .prose-nav-next { text-align: start; align-items: flex-start; }
}

/* --------------------------------------------------------------------------
   Motion & print
   -------------------------------------------------------------------------- */

@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after {
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: 0.01ms !important;
    scroll-behavior: auto !important;
  }
}

@media print {
  :root { --bg: #ffffff; --ink: #000; --ink-muted: #444; --rule: #ccc; }
  body { font-size: 11pt; line-height: 1.5; }
  .site-header nav, .site-footer .colophon, .skip-link, .prose-nav { display: none; }
  a { text-decoration: underline; }
  .prose-body a::after { content: " (" attr(href) ")"; font-size: 0.85em; color: #666; }
  .prose-body pre, .prose-body :not(pre) > code { border: 1px solid #ccc; background: none; }
  h1, h2, h3 { page-break-after: avoid; break-after: avoid; }
  pre, blockquote, figure { page-break-inside: avoid; break-inside: avoid; }
}

/* Tighten on narrow screens (no need to override font sizes — clamp does the job). */
@media (max-width: 32rem) {
  .site-header .container.row { flex-direction: column; align-items: flex-start; gap: 0.5rem; }
}
'
}

fn scaffold_content_files() map[string]string {
	return {
		'content/posts/_index.md':      scaffold_posts_index()
		'content/posts/hello-verne.md': scaffold_post()
		'content/about.md':             scaffold_about()
	}
}

fn scaffold_posts_index() string {
	return '---
title: Posts
description: All posts on this site, newest first.
---

Everything I have written so far. Newest posts come first.
'
}

fn scaffold_post() string {
	return '---
title: Hello, Verne
date: 2026-01-01T00:00:00Z
description: First post on a freshly scaffolded Verne site.
tags:
  - intro
  - meta
---

Welcome to your new Verne site. This file lives in `content/posts/` and was
created by `verne init`. Edit it, drop a few more `.md` files next to it, and
run `verne server` to preview your changes locally.

## What just happened?

`verne init` scaffolded:

- a `content/` tree with this post, a section index, and an About page,
- a `themes/default/` theme with a small but presentable CSS bundle,
- a `verne.yaml` already wired to the theme.

## Next steps

1. Edit this post.
2. Add another file in `content/posts/` — front matter with `title`, `date`,
   `description` is enough.
3. Customise the theme under `themes/default/` or swap it via the `theme:`
   key in `verne.yaml`.
'
}

fn scaffold_about() string {
	return '---
title: About
description: A page about this site and its author.
---

This is a regular content page, sitting at the root of `content/` rather than
inside a section. It renders through the same `_default/single.html` template
as a post, just without the date and prev/next navigation.

Edit `content/about.md` to replace this text.
'
}

fn cmd_clean(args []string) ! {
	mut dir := ''
	mut config_file := ''
	mut output_dir := ''
	mut clean_cache := false
	mut i := 0
	for i < args.len {
		a := args[i]
		match a {
			'-c', '--config' {
				i++
				if i >= args.len {
					return error('clean: ${a} requires a value')
				}
				config_file = args[i]
			}
			'-r', '--root' {
				i++
				if i >= args.len {
					return error('clean: ${a} requires a value')
				}
				if dir != '' {
					return error('clean: ${a} conflicts with positional DIR')
				}
				dir = args[i]
			}
			'-o', '--output-dir' {
				i++
				if i >= args.len {
					return error('clean: ${a} requires a value')
				}
				output_dir = args[i]
			}
			'--all' {
				clean_cache = true
			}
			else {
				if a.starts_with('-') {
					return error('clean: unknown flag `${a}`')
				}
				if dir != '' {
					return error('clean: unexpected argument `${a}`')
				}
				dir = a
			}
		}

		i++
	}
	if config_file != '' && dir != '' {
		return error('clean: -c/--config and DIR/-r are mutually exclusive (the config file pins its own root)')
	}
	mut cfg := load_cfg(dir, config_file)!
	if output_dir != '' {
		cfg.output_dir = resolve_output_dir(output_dir, cfg.root)
	}
	out := if cfg.output_dir != '' { cfg.output_dir } else { os.join_path(cfg.root, 'public') }
	mut removed := []string{}
	if os.exists(out) {
		render.ensure_safe_to_wipe(out, cfg.root)!
		os.rmdir_all(out) or { return error('cannot remove ${out}: ${err}') }
		removed << os.real_path(out)
	}
	if clean_cache {
		cache := os.join_path(cfg.root, '.cache')
		if os.exists(cache) {
			os.rmdir_all(cache) or { return error('cannot remove ${cache}: ${err}') }
			removed << cache
		}
	}
	if removed.len == 0 {
		println('Nothing to clean.')
	} else {
		for p in removed {
			println('Removed ${p}')
		}
	}
}

fn cmd_server(args []string) ! {
	mut port := 1313
	mut dir := ''
	mut config_file := ''
	mut base_url := ''
	mut output_dir := ''
	mut open_browser := false
	mut i := 0
	for i < args.len {
		a := args[i]
		match a {
			'-p', '--port' {
				i++
				if i >= args.len {
					return error('server: ${a} requires a value')
				}
				raw := args[i]
				port = parse_port(raw) or {
					return error('server: ${a} expects a port number 1..65535, got `${raw}`')
				}
			}
			'--open' {
				open_browser = true
			}
			'-c', '--config' {
				i++
				if i >= args.len {
					return error('server: ${a} requires a value')
				}
				config_file = args[i]
			}
			'-r', '--root' {
				i++
				if i >= args.len {
					return error('server: ${a} requires a value')
				}
				if dir != '' {
					return error('server: ${a} conflicts with positional DIR')
				}
				dir = args[i]
			}
			'-u', '--base-url' {
				i++
				if i >= args.len {
					return error('server: ${a} requires a value')
				}
				base_url = args[i]
			}
			'-o', '--output-dir' {
				i++
				if i >= args.len {
					return error('server: ${a} requires a value')
				}
				output_dir = args[i]
			}
			else {
				if a.starts_with('-') {
					return error('server: unknown flag `${a}`')
				}
				if dir != '' {
					return error('server: unexpected argument `${a}`')
				}
				dir = a
			}
		}

		i++
	}
	if config_file != '' && dir != '' {
		return error('server: -c/--config and DIR/-r are mutually exclusive (the config file pins its own root)')
	}
	mut cfg := load_cfg(dir, config_file)!
	if base_url != '' {
		config.validate_base_url(base_url)!
		cfg.base_url = base_url
	}
	if output_dir != '' {
		cfg.output_dir = resolve_output_dir(output_dir, cfg.root)
	}
	public_dir := if cfg.output_dir != '' {
		cfg.output_dir
	} else {
		os.join_path(cfg.root, 'public')
	}
	render.assert_output_under_root(public_dir, cfg.root)!
	highlight.ensure_available()!
	t_start := time.now()
	site := content.build_site(cfg)!
	mut renderer := render.new(cfg, site)!
	count := renderer.build()!
	dur := time.now() - t_start
	println('Built ${count} pages in ${dur.milliseconds()}ms → ${public_dir}/')
	addr := '127.0.0.1:${port}'
	listener := net.listen_tcp(.ip, addr) or {
		return error('server: cannot bind ${addr} (${err.msg()}) — is port ${port} already in use?')
	}
	url := 'http://${addr}/'
	println('Serving ${public_dir} on ${url}')
	if open_browser {
		open_url(url)
	}
	mut server := &http.Server{
		addr:                 addr
		listener:             listener
		show_startup_message: false
		handler:              FileHandler{
			root: public_dir
		}
	}
	server.listen_and_serve()
}

// open_url asks the OS to open `url` in the user's default browser.
// Best-effort: the spawned helper's exit code is ignored — the server still
// runs even if no opener is installed (e.g. headless Linux without xdg-open).
// Caller must pre-validate `url`; we forward it to a shell-safe quoter and
// the intended caller (`cmd_server`) only hands in `http://127.0.0.1:PORT/`.
fn open_url(url string) {
	$if macos {
		os.execute('open ${os.quoted_path(url)}')
	} $else $if linux {
		os.execute('xdg-open ${os.quoted_path(url)}')
	} $else $if windows {
		os.execute('cmd /c start ${url}')
	} $else {
		// no opener known for this OS
	}
}

struct FileHandler {
	root string
}

fn (h FileHandler) handle(req http.Request) http.Response {
	mut path := req.url
	if pos := path.index('?') {
		path = path[..pos]
	}
	decoded := urllib.query_unescape(path) or { path }
	clean := decoded.trim_left('/')
	if clean.contains('..') {
		return http.new_response(
			status: .forbidden
			body:   'forbidden'
			header: text_header()
		)
	}
	mut full := os.join_path(h.root, clean)
	if os.is_dir(full) {
		full = os.join_path(full, 'index.html')
	}
	if !os.exists(full) {
		return http.new_response(
			status: .not_found
			body:   '404 not found'
			header: text_header()
		)
	}
	body := os.read_file(full) or {
		return http.new_response(
			status: .internal_server_error
			body:   'read error'
			header: text_header()
		)
	}
	return http.new_response(
		status: .ok
		body:   body
		header: header_for(full)
	)
}

fn header_for(path string) http.Header {
	mime := match os.file_ext(path) {
		'.html' { 'text/html; charset=utf-8' }
		'.css' { 'text/css; charset=utf-8' }
		'.js' { 'application/javascript; charset=utf-8' }
		'.json' { 'application/json' }
		'.svg' { 'image/svg+xml' }
		'.png' { 'image/png' }
		'.jpg', '.jpeg' { 'image/jpeg' }
		'.webp' { 'image/webp' }
		'.woff2' { 'font/woff2' }
		'.xml' { 'application/xml; charset=utf-8' }
		'.txt' { 'text/plain; charset=utf-8' }
		'.md' { 'text/markdown; charset=utf-8' }
		else { 'application/octet-stream' }
	}

	mut h := http.new_header()
	h.add(.content_type, mime)
	h.add_custom('X-Content-Type-Options', 'nosniff') or {}
	return h
}

fn text_header() http.Header {
	mut h := http.new_header()
	h.add(.content_type, 'text/plain; charset=utf-8')
	return h
}
