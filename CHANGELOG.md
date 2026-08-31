# Changelog

All notable changes to Verne will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- `verne help` and `verne <subcommand> --help` now read from a single
  command table, so a subcommand's one-line summary and its detailed page
  cannot drift apart. Every per-subcommand page opens with a `Usage:` line
  and a paragraph describing what the command actually does.
- Subcommand summaries now match the behaviour: `verne server` renders the
  site *and* serves it, `verne build` renders (assets, sitemap, RSS,
  `llms.txt`) rather than just "builds".

### Fixed

- `verne help init` no longer advertises `-r/--root` and `-c/--config`:
  `init` never accepted them.
- `verne help clean` described `-o` as replacing `cfg.output_dir`, an
  internal field no `verne.yaml` key can set; it now says `<DIR>/public`.

## [0.2.0] - 2026-05-11

### Added

- Native [llms.txt](https://llmstxt.org/) outputs alongside every HTML
  build:
  - `/llms.txt` — curated index conforming to the llms.txt standard
    (H1 site title, blockquote summary, one H2 per content section,
    bullets `[Title](url): description` pointing at the markdown twins).
  - `/llms-full.txt` — every included page's markdown concatenated and
    separated by horizontal rules, in the same canonical order as
    `llms.txt`.
  - `<page>.html.md` — a self-contained markdown twin written next to
    each `index.html`, matching the companion-file proposal from the
    spec.
- Per-page `llms` frontmatter knob:
  - `false` drops the page from every output.
  - `"optional"` files the page under a trailing `## Optional` H2 in
    `/llms.txt` (the spec-reserved bucket for URLs an LLM may skip
    for shorter context) and moves it to the tail of `/llms-full.txt`.
  - `true` (or omitted) is the default.
- Site-wide off-switch via `llms: { enabled: false }` in `verne.yaml`.
- `yaml.Value.as_bool()` helper, symmetric with `as_string` /
  `as_list` / `as_map`.

## [0.1.0] - 2026-05-05

Initial public release.
