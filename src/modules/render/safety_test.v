module render

import os

fn test_assert_output_under_root_rejects_outside_root() {
	root := os.join_path(os.temp_dir(), 'verne-safety-${os.getpid()}-1')
	os.mkdir_all(root) or { panic(err) }
	defer {
		os.rmdir_all(root) or {}
	}
	assert_output_under_root(os.join_path(root, '..', 'escape'), root) or {
		assert err.msg().contains('outside project root'), err.msg()
		return
	}
	assert false, 'should have rejected `..` escape'
}

fn test_assert_output_under_root_rejects_equal_root() {
	root := os.join_path(os.temp_dir(), 'verne-safety-${os.getpid()}-2')
	os.mkdir_all(root) or { panic(err) }
	defer {
		os.rmdir_all(root) or {}
	}
	assert_output_under_root(root, root) or {
		assert err.msg().contains('equals project root'), err.msg()
		return
	}
	assert false, 'should have rejected output == root'
}

fn test_assert_output_under_root_rejects_root_filesystem_root() {
	assert_output_under_root('/etc', '/') or {
		assert err.msg().contains('project root resolves to'), err.msg()
		return
	}
	assert false, 'should have rejected root="/"'
}

fn test_assert_output_under_root_accepts_legitimate_subpath() {
	root := os.join_path(os.temp_dir(), 'verne-safety-${os.getpid()}-3')
	os.mkdir_all(root) or { panic(err) }
	defer {
		os.rmdir_all(root) or {}
	}
	assert_output_under_root(os.join_path(root, 'public'), root) or {
		assert false, 'should have accepted root/public: ${err}'
	}
}

fn test_ensure_safe_to_wipe_rejects_source_tree_marker() {
	root := os.join_path(os.temp_dir(), 'verne-safety-${os.getpid()}-4')
	out := os.join_path(root, 'mixed')
	os.mkdir_all(os.join_path(out, 'content')) or { panic(err) }
	defer {
		os.rmdir_all(root) or {}
	}
	ensure_safe_to_wipe(out, root) or {
		assert err.msg().contains('source tree'), err.msg()
		return
	}
	assert false, 'should have rejected directory containing content/'
}
