---
title: "Installation — macOS"
description: "Running Verne on Apple Silicon and Intel Macs."
---


Both Apple Silicon (M1/M2/M3) and Intel Macs are supported. There is no
Rosetta involved — Verne builds natively for the host architecture.

## Prerequisites

```bash
brew install vlang chroma
```

`vlang` is V itself; `chroma` is the highlighter Verne shells out to for
fenced code blocks.

## Build

```bash
git clone https://github.com/davlgd/Verne
cd Verne
mise run prod
./verne version
```

You should see `verne 0.1.0` (or whatever the current version is).

## Smoke test

```bash
./verne build --root examples/vernebook
./verne server --root examples/vernebook --open
```

If your default browser shows the home page of *this very book*, the install
is complete.
