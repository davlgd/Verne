// Module assets is a tiny build-time pipeline for static assets. It supports:
//
//   get        — read a file from <theme>/assets/<rel>
//   concat     — concatenate multiple resources into one
//   fingerprint — append `.<sha256>.` to the filename so the URL is
//                 content-addressed
//
// All produced resources are written to `<output>/<rel>` (or to the
// fingerprinted path) the first time they are realised, and the integrity
// hash is exposed on `Resource.integrity` for SRI <link integrity="…">.
module assets

import os
import crypto.sha256
import encoding.base64

@[heap]
pub struct Pipeline {
pub:
	asset_root string // typically `<root>/themes/<theme>/assets`
	output_dir string // typically `<root>/public`
	base_url   string // baseURL prefix for absolute links
mut:
	cache map[string]&Resource
}

@[heap]
pub struct Resource {
pub mut:
	rel       string // path under output_dir, e.g. `css/style.4f3a.css`
	bytes     []u8
	integrity string // `sha256-…` base64
	written   bool
}

// new builds a Pipeline rooted at `asset_root` (where source assets live)
// that emits fingerprinted files under `output_dir`.
pub fn new(asset_root string, output_dir string, base_url string) &Pipeline {
	return &Pipeline{
		asset_root: asset_root
		output_dir: output_dir
		base_url:   base_url
	}
}

// get loads a single asset relative to `asset_root` into memory.
pub fn (mut p Pipeline) get(rel string) !&Resource {
	clean := rel.trim_left('/')
	full := os.join_path(p.asset_root, clean)
	if !os.exists(full) {
		return error('assets: not found `${rel}`')
	}
	bytes := os.read_file(full)!.bytes()
	return &Resource{
		rel:   clean
		bytes: bytes
	}
}

// concat returns a new resource that is the byte-wise concatenation of
// `parts`, addressed by `target_rel`.
pub fn (mut p Pipeline) concat(target_rel string, parts []&Resource) !&Resource {
	mut buf := []u8{}
	for r in parts {
		buf << r.bytes
	}
	return &Resource{
		rel:   target_rel.trim_left('/')
		bytes: buf
	}
}

// fingerprint returns a copy of `r` with an 8-hex sha256 prefix injected
// before the extension, plus a populated `integrity` SRI value.
pub fn (mut p Pipeline) fingerprint(r &Resource) !&Resource {
	hash := sha256.sum(r.bytes)
	hex := hash.hex()
	short := hex[..8]
	dir := os.dir(r.rel)
	base := os.file_name(r.rel)
	dot := base.last_index('.') or { base.len }
	new_base := if dot < base.len {
		base[..dot] + '.' + short + base[dot..]
	} else {
		base + '.' + short
	}
	new_rel := if dir == '.' || dir == '' { new_base } else { dir + '/' + new_base }
	integrity := 'sha256-' + base64.encode(hash[..])
	return &Resource{
		rel:       new_rel
		bytes:     r.bytes
		integrity: integrity
	}
}

// realise writes the resource's bytes to `output_dir/r.rel` and returns
// that relative path.
pub fn (mut p Pipeline) realise(r &Resource) !string {
	out := os.join_path(p.output_dir, r.rel)
	os.mkdir_all(os.dir(out))!
	os.write_file(out, r.bytes.bytestr())!
	return r.rel
}

// rel_url returns the resource's site-root-relative URL (`/path/file.hash.css`).
pub fn (r &Resource) rel_url() string {
	return '/' + r.rel
}

// abs_url returns the resource URL prefixed with the configured base URL.
pub fn (r &Resource) abs_url(base string) string {
	prefix := base.trim_right('/')
	return prefix + '/' + r.rel
}
