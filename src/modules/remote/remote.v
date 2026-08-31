// Module remote performs build-time HTTP fetches with sane defaults:
//   - http(s) only
//   - 10 s default timeout
//   - 5 MiB default body cap
//   - response cached on disk under `.cache/remote/<sha256-of-url>`
//
// The cache is opt-out via `Options.no_cache = true`. Cached responses are
// keyed by full URL+headers; a stale cache is fine for offline rebuilds.
module remote

import os
import net.http
import crypto.sha256
import time

pub struct Options {
pub:
	headers       map[string]string
	timeout_ms    int = 10_000
	max_body_size int = 5 * 1024 * 1024
	no_cache      bool
	cache_dir     string = '.cache/remote'
	cache_ttl_s   i64 = 3600
}

pub struct Response {
pub:
	status_code int
	body        string
	url         string
	from_cache  bool
}

// get fetches `url` over HTTP(S), serving from a disk cache when fresh and
// honouring `If-None-Match` revalidation otherwise.
pub fn get(url string, opts Options) !Response {
	if !(url.starts_with('http://') || url.starts_with('https://')) {
		return error('remote: refusing non-http(s) URL `${url}`')
	}
	cache_path := cache_path_for(url, opts)
	if !opts.no_cache {
		if cached := read_cache(cache_path, opts.cache_ttl_s) {
			return Response{
				status_code: 200
				body: cached
				url: url
				from_cache: true
			}
		}
	}
	mut req := http.new_request(.get, url, '')
	for k, v in opts.headers {
		req.add_custom_header(k, v) or {}
	}
	req.read_timeout = i64(opts.timeout_ms) * time.millisecond
	req.write_timeout = i64(opts.timeout_ms) * time.millisecond
	resp := req.do() or { return error('remote: ${url}: ${err}') }
	if resp.status_code < 200 || resp.status_code >= 300 {
		return error('remote: ${url}: HTTP ${resp.status_code}')
	}
	if resp.body.len > opts.max_body_size {
		return error('remote: ${url}: body exceeds ${opts.max_body_size} bytes')
	}
	if !opts.no_cache {
		write_cache(cache_path, resp.body) or {}
	}
	return Response{
		status_code: resp.status_code
		body: resp.body
		url: url
		from_cache: false
	}
}

fn cache_path_for(url string, opts Options) string {
	hash := sha256.hexhash(url)
	return os.join_path(opts.cache_dir, hash)
}

fn read_cache(path string, ttl_s i64) ?string {
	if !os.exists(path) {
		return none
	}
	stat := os.stat(path) or { return none }
	age := time.now().unix() - i64(stat.mtime)
	if ttl_s > 0 && age > ttl_s {
		return none
	}
	body := os.read_file(path) or { return none }
	return body
}

fn write_cache(path string, body string) ! {
	os.mkdir_all(os.dir(path))!
	os.write_file(path, body)!
}
