---
title: "Installation"
description: "Getting Verne onto your machine."
---


Verne is a single binary. There is no runtime, no Node, no Bundler.
Pick the install method that suits your system, then jump to the
platform-specific notes via the sidebar.

## Quick options

```bash
# From source (V toolchain installed)
git clone https://github.com/davlgd/Verne
cd Verne
mise run prod         # builds ./verne for your host

# From a pre-built release
# (visit the GitHub Releases page and grab the matching asset)
```

## Verifying the install

```bash
./verne version
# → verne 0.1.0
```

If the command prints a version, you're good. The next chapters drill into
each platform.

> **Note**: an external `chroma` binary is needed for syntax highlighting in
> Markdown code fences. Without it, code blocks render as plain text. Most
> distros provide it via their package manager (`brew install chroma`,
> `apt install chroma`, etc.).
