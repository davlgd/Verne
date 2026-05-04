---
title: "Installation"
description: "Build the Verne binary from source — it takes a few seconds."
---

Verne is distributed as a single binary written in [V](https://github.com/vlang/v).
It links against `libgc` (provided by V) and depends on one external
runtime tool: the [`chroma`](https://github.com/alecthomas/chroma)
command-line binary, used for code-fence syntax highlighting.

## Build from source

The current path while pre-built releases are not yet shipped:

```bash
git clone https://github.com/davlgd/Verne
cd Verne
mise run prod        # or: v -prod -o verne src/
./verne version      # → verne 0.1.0
```

The repository ships a [`mise`](https://mise.jdx.dev/) task file. If you do
not use mise, the underlying command is `v -prod -o verne src/`. Either way,
you end up with a `./verne` binary — fully self-contained, statically linked
against `libgc`, ~2 MB.

Move it somewhere on `$PATH` (`/usr/local/bin/`, `~/.local/bin/`, or
similar) when you are happy with it.

## Runtime dependency: `chroma`

Code-fence syntax highlighting is delegated to the external
[`chroma`](https://github.com/alecthomas/chroma) binary. `verne build`
and `verne server` check at launch that `chroma` is runnable; if it is
not, they exit with a pointer to its install docs. Compiling Verne
itself does not need `chroma`.

### Installing `chroma`

On macOS:

```bash
brew install chroma
```

On Linux:

```bash
go install github.com/alecthomas/chroma/v2/cmd/chroma@latest
# or download a pre-built binary from https://github.com/alecthomas/chroma/releases
```

### `$VERNE_CHROMA_PATH`

By default, Verne looks for `chroma` on `$PATH`. The `$VERNE_CHROMA_PATH`
environment variable overrides that lookup with a directory; the
special value `.` means "next to the `verne` binary":

```bash
VERNE_CHROMA_PATH=/opt/tools/bin verne build
VERNE_CHROMA_PATH=. verne build       # chroma alongside ./verne
```

Useful for sandboxed environments and CI runners where you ship both
binaries together.

## Verifying the install

```bash
verne version
# verne 0.1.0
```

If you see the version line, you are done. Move on to
[Quick start](../quick-start/).
