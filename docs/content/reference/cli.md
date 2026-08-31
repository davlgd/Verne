---
title: "CLI"
description: "Every subcommand, every flag, every exit code."
---

Verne ships as a single binary. Run `verne` (no arguments) for a quick
usage summary; `verne help <subcommand>` (or `verne <subcommand> --help`)
for what that subcommand does and the flags it takes.

## Synopsis

```shell
verne init   [DIR] [flags]   scaffold a new site (interactive on a TTY)
verne build  [DIR] [flags]   render the site into <DIR>/public/
verne server [DIR] [flags]   render the site, then serve it over HTTP (default :1313)
verne clean  [DIR] [flags]   remove the build output
verne version                print the version
verne help [SUBCOMMAND]      print full or per-subcommand help
```

## `verne init`

Scaffolds a new Verne site at the given directory (or the current one if
omitted): `verne.yaml`, a starter `content/` tree, `static/`, and — unless
`--theme` names a theme you provide yourself — a minimal theme under
`themes/`. Existing files are left alone; only `--force` rewrites
`verne.yaml`.

Unlike the other subcommands, `init` takes the target directory as a
positional argument only — there is no `-r`/`--root` and no `-c`/`--config`
(there is no config to load yet).

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

Renders every page under `content/` into `<DIR>/public/`, together with the
fingerprinted CSS/JS bundles, the `static/` files, `404.html`, the sitemap,
the RSS feed and the `llms.txt` outputs. Wipes the output directory first,
so a renamed page leaves nothing stale behind. Needs `chroma` on `PATH`.

- **`-c, --config FILE`** — load this config instead of `<DIR>/verne.yaml`
- **`-r, --root DIR`** — same as positional `DIR`
- **`-u, --base-url URL`** — override `baseURL:` from `verne.yaml`
- **`-o, --output-dir DIR`** — override the output directory
  (default `<DIR>/public`)

`-c` and `-r`/positional `DIR` are mutually exclusive (the config file pins
its own root).

## `verne server`

Runs the same build as `verne build`, then serves the output directory on
`127.0.0.1:1313` over plain HTTP until you stop it with Ctrl-C. Inherits
every `build` flag. Every request reads from disk, so a rebuild started
from another shell is served without a restart.

- **`-p, --port N`** — listen port (default `1313`)
- **`--open`** — open the served URL in the default browser

## `verne clean`

Removes the build output — `<DIR>/public`, or the directory given to `-o`.
Refuses to wipe a path that is the project root or sits outside it, and
refuses any directory that looks like a source tree (contains `content/`,
`themes/`, `.git/`, or `verne.yaml`).

- **`-c, --config FILE`** — load this config instead of `<DIR>/verne.yaml`
- **`-r, --root DIR`** — same as positional `DIR`
- **`-o, --output-dir DIR`** — remove this directory instead of
  `<DIR>/public`
- **`--all`** — also remove caches under `<DIR>/.cache/`

`-c` and `-r`/positional `DIR` are mutually exclusive.

## Exit codes

- **`0`** — success
- **`1`** — build, server, or clean failure (config error, template error,
  …)
- **`2`** — CLI usage error (no args, unknown subcommand, unknown flag, …)
