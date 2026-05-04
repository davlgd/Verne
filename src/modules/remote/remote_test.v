module remote

fn test_refuses_non_http_scheme() {
	get('file:///etc/passwd', Options{}) or {
		assert err.msg().contains('refusing')
		return
	}
	assert false, 'expected error for file:// URL'
}
