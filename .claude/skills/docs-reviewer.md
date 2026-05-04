---
name: docs-reviewer
description: Review the Verne documentation under docs/ for factual alignment with the source code — every claim must trace to V code or to a runtime behaviour.
---

# Documentation review

You are reviewing `docs/content/**/*.md` (and `README.md` when it cites the
docs) as someone who reads the source first and the prose second. Verne
ships its docs as a deliverable: `docs/` is published at
`https://www.verne-ssg.org/`. A doc that drifts from the code is worse than
a missing doc — it actively misleads the reader.

The work is **cross-referencing**, not editing for style. Treat every
factual sentence as a claim that must trace back to:

- a V symbol or constant in `src/modules/<x>/`,
- a runtime behaviour observable from a fresh `verne build` / `verne server`,
- or an explicit unit test in a `*_test.v` file.

If a claim does not trace back cleanly, it is a finding.

## Review checklist

1. **CLI claims (reference/cli.md)**
   - Every flag listed exists in `src/main.v`'s `cmd_<name>` parser.
     Check long form, short form, default, and the mutual-exclusion notes.
   - The synopsis matches `print_help('')` byte-for-byte (subcommand list,
     directories, default port).
   - Exit codes match: `0` success, `1` runtime failure (`fail()` /
     `exit(1)`), `2` CLI usage error (`exit(2)` paths in `main`).

2. **Configuration claims (reference/configuration.md)**
   - Every key parsed in `src/modules/config/config.v` has a row in the doc
     and vice versa. Catch reserved-but-unused keys (`markup`, `outputs`,
     `security`) — they must be flagged as such, not described as
     "uncommon, see source".
   - Defaults match the V struct field defaults in `Config{}`. A V default
     of `bool = true` must read "default `true`" in the doc, not "default
     `false`".
   - Direction of maps (`taxonomies`: singular → plural, `frontmatter`:
     canonical → aliases). Easy to invert in prose.
   - Validation rules: which schemes `baseURL` allows, which placeholders
     `edit_url` requires (`{path}`), which permalink tokens `:slug`,
     `:section`, `:year`, `:month`, `:day`, `:filename`, `:contentbasename`.

3. **Template claims (reference/templates.md)**
   - The filter table matches `register_builtins()` in
     `src/modules/template/filters.v` plus the override registrations in
     `src/modules/render/render.v` (`relurl`, `absurl`, `markdownify`).
     Filter count and signatures must match.
   - The test list (`is defined`, `is none`, `is empty`, `is string`, `is
     number`, `is list`, `is map`) matches `eval_is()` in `eval.v`.
   - The expression grammar matches the lexer (no hyphens in identifiers,
     no inline arithmetic, `with` as the only naming construct).
   - The page/site/config field tables match the getters in
     `content/template_adapter.v`. Fields exposed but undocumented
     (`page.layout`, `page.chapter_no`, `page.meta_description`, …) are
     findings; documented but absent fields are findings.
   - Whitespace control (`{%-`, `-%}`, `trim_blocks`, `lstrip_blocks` defaults)
     matches the lexer comments.

4. **Shortcode claims (reference/shortcodes.md)**
   - Resolution order (V registry first, then `templates/shortcodes/<name>.html`)
     matches `eval_shortcode()` in `eval.v`.
   - The name regex matches `is_ident_start`/`is_ident_part` in
     `lex.v` — no hyphens. Examples must obey it.
   - The `ShortcodeContext` struct fields match the V definition.
   - The "zero built-in shortcodes" claim is honest — grep
     `register_shortcode` to confirm none are wired in `src/`.

5. **Markdown / writing claims (guides/writing-content.md)**
   - The "what works" list matches the renderer's actual support: ATX
     headings, fenced code, lists, blockquotes (with GitHub callouts),
     pipe tables, autolinks, raw HTML — but not setext headings or
     reference-style links. Drift here is the most common failure mode.
   - TOC is only built from `## ` headings (not `###`) — see
     `mdrender.table_of_contents`.
   - The code-fence wrapper attribute (`data-lang`) lives on the outer
     `<div class="code-wrap">`, not on `<pre>`.
   - The callout markup contract: a `<p class="callout-badge">` always,
     a `<p class="callout-title">` only when an inline title is given,
     `data-callout-untitled` only when no title was set,
     `role="alert"` only for `WARNING`/`CAUTION`.

6. **Internal links and anchors**
   - Every relative link resolves to a real file under `docs/content/`.
   - Every `#anchor` resolves — anchors are slugified from `## `/`### `
     headings via `mdrender.slugify_heading`. Run the doc and verify each
     fragment lands.

7. **Examples and tutorials**
   - Code blocks marked `bash`/`yaml`/`v` are runnable as written. Copy
     them into a fresh shell or sandbox and execute when in doubt.
   - The "five-minute" claims in quick-start actually take five minutes
     against the current binary.

## How to apply

For each modified docs page:

1. Open the page and the matching source files side by side.
2. Walk every factual sentence and answer: which file, which symbol, which
   behaviour does this claim?
3. Where the answer is "I don't know" — that's a finding. Either fix the
   doc to match what the code actually does, or fix the code if the doc
   describes the intended contract.
4. For deletions, also check `MEMORY.md`, `README.md`, and the homepage
   `_index.md` for stale cross-links.

Cite finding location as `docs/content/<path>.md:line — claim "X" but
src/modules/<m>/<f>.v:line shows Y`. End with `LGTM` / `nits only` /
`changes requested` and the count of factual mismatches found.
