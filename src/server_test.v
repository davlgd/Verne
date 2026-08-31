module main

import os

fn test_inject_livereload_goes_before_the_body_close() {
	out := inject_livereload('<html><body><p>hi</p></body></html>')
	assert out.contains('data-verne-livereload')
	assert out.index('data-verne-livereload')? < out.index('</body>')?
	assert out.ends_with('</body></html>')
}

fn test_inject_livereload_matches_an_uppercase_tag() {
	out := inject_livereload('<HTML><BODY>hi</BODY></HTML>')
	assert out.contains('data-verne-livereload')
	assert out.ends_with('</BODY></HTML>')
}

fn test_inject_livereload_appends_when_there_is_no_body() {
	out := inject_livereload('just text')
	assert out.starts_with('just text')
	assert out.contains('data-verne-livereload')
}

fn watch_tree() string {
	dir := os.join_path(os.temp_dir(), 'verne-watch-${os.getpid()}')
	os.rmdir_all(dir) or {}
	os.mkdir_all(os.join_path(dir, 'content')) or { panic(err) }
	os.write_file(os.join_path(dir, 'content', 'a.md'), 'a') or { panic(err) }
	return dir
}

fn test_tree_fingerprint_tracks_the_watched_files() {
	dir := watch_tree()
	defer {
		os.rmdir_all(dir) or {}
	}
	roots := [os.join_path(dir, 'content')]
	base := tree_fingerprint(roots, '')
	assert base != 0
	assert tree_fingerprint(roots, '') == base, 'an untouched tree must fingerprint the same'

	os.write_file(os.join_path(dir, 'content', 'a.md'), 'a much longer body') or { panic(err) }
	edited := tree_fingerprint(roots, '')
	assert edited != base, 'an edit must change the fingerprint'

	os.write_file(os.join_path(dir, 'content', 'b.md'), 'b') or { panic(err) }
	added := tree_fingerprint(roots, '')
	assert added != edited, 'a new file must change the fingerprint'

	os.mv(os.join_path(dir, 'content', 'b.md'), os.join_path(dir, 'content', 'c.md')) or {
		panic(err)
	}
	renamed := tree_fingerprint(roots, '')
	assert renamed != added, 'a rename must change the fingerprint even at equal size and mtime'

	os.rm(os.join_path(dir, 'content', 'c.md')) or { panic(err) }
	assert tree_fingerprint(roots, '') == edited, 'removing the new file must restore the fingerprint'
}

fn test_tree_fingerprint_skips_hidden_files_and_the_output_dir() {
	dir := watch_tree()
	defer {
		os.rmdir_all(dir) or {}
	}
	roots := [os.join_path(dir, 'content')]
	base := tree_fingerprint(roots, '')

	os.write_file(os.join_path(dir, 'content', '.DS_Store'), 'noise') or { panic(err) }
	assert tree_fingerprint(roots, '') == base, 'hidden files must not trigger a rebuild'

	// An output directory nested under a watched root would otherwise make
	// every build look like a source change.
	public := os.join_path(dir, 'content', 'public')
	os.mkdir_all(public) or { panic(err) }
	os.write_file(os.join_path(public, 'index.html'), '<html></html>') or { panic(err) }
	assert tree_fingerprint(roots, public) == base, 'the output directory must be skipped'
	assert tree_fingerprint(roots, '') != base, 'and counted when it is not'
}

fn test_tree_fingerprint_ignores_a_missing_root() {
	assert tree_fingerprint([os.join_path(os.temp_dir(), 'verne-does-not-exist')], '') == 0
}
