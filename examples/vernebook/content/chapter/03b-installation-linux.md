---
title: "Installation — Linux"
description: "Running Verne on Linux x86_64 and ARM64."
---


Tested on Ubuntu 22.04+, Debian 12, and Fedora 40. ARM64 (`aarch64`) is fully
supported — the project's CI builds for it.

## Prerequisites

Debian / Ubuntu:

```bash
sudo apt install -y build-essential git curl chroma
```

Fedora:

```bash
sudo dnf install -y @development-tools git curl chroma
```

V itself has no Debian package as of this writing — install it from source:

```bash
git clone https://github.com/vlang/v
cd v && make
sudo ./v symlink
```

## Build

```bash
git clone https://github.com/davlgd/Verne
cd Verne
mise run prod
./verne version
```

## Smoke test

```bash
./verne server --root examples/vernebook
# → Serving … on http://127.0.0.1:1313/
```

Open the URL in any browser.
