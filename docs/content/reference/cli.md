---
title: "CLI"
description: "Every subcommand, every flag, every exit code."
---

Verne ships as a single binary. Run `verne` (no arguments) for a quick
usage summary; `verne help <subcommand>` for the per-subcommand flag list.

## Synopsis

```shell
verne init   [DIR] [flags]   scaffold a new site (interactive on a TTY)
verne build  [DIR] [flags]   build the site to <DIR>/public/
verne server [DIR] [flags]   serve <DIR>/public/ over HTTP (default :1313)
verne clean  [DIR] [flags]   remove the build output
verne version                print the version
verne help [SUBCOMMAND]      print full or per-subcommand help
```

## `verne init`

Scaffolds a new Verne site at the given directory (or the current one if
omitted).

- **`--title T`** — site title
- **`--theme N`** — bundle a starter theme named *N* (default: scaffold one)
- **`-u, --base-url URL`** — site base URL
- **`-l, --locale L`** — content locale (e.g. `en-us`)
- **`--tagline T`** — short tagline shown on the home page
- **`-y, --yes`** — accept all defaults — skip the interactive prompts
- **`-f, --force`** — scaffold into a non-empty directory (overwrites
  `verne.yaml`)

Interactive on a TTY, scriptable with `--yes`.

## `verne build`

Builds the site to `<DIR>/public/`. Wipes the output directory first to
avoid stale artifacts.

- **`-c, --config FILE`** — load this config instead of `<DIR>/verne.yaml`
- **`-r, --root DIR`** — same as positional `DIR`
- **`-u, --base-url URL`** — override `baseURL:` from `verne.yaml`
- **`-o, --output-dir DIR`** — override the output directory
  (default `<DIR>/public`)

`-c` and `-r`/positional `DIR` are mutually exclusive (the config file pins
its own root).

## `verne server`

Rebuilds and serves on `127.0.0.1:1313`. Inherits every `build` flag.

- **`-p, --port N`** — listen port (default `1313`)
- **`--open`** — open the served URL in the default browser

## `verne clean`

Removes the build output. Refuses to wipe a path that is the project
root or sits outside it, and refuses any directory that looks like a
source tree (contains `content/`, `themes/`, `.git/`, or `verne.yaml`).

- **`-c, --config FILE`** — load this config instead of `<DIR>/verne.yaml`
- **`-r, --root DIR`** — same as positional `DIR`
- **`-o, --output-dir DIR`** — remove this directory instead of
  `cfg.output_dir`
- **`--all`** — also remove caches under `<DIR>/.cache/`

`-c` and `-r`/positional `DIR` are mutually exclusive.

## Exit codes

- **`0`** — success
- **`1`** — build, server, or clean failure (config error, template error,
  …)
- **`2`** — CLI usage error (no args, unknown subcommand, unknown flag, …)
