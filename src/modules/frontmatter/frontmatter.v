// Module frontmatter extracts a YAML frontmatter block delimited by `---`
// at the top of a Markdown document, and returns it together with the
// remaining body.
module frontmatter

import yaml

pub struct Document {
pub:
	meta map[string]yaml.Value
	body string
}

// parse splits `src` into (frontmatter map, body). If `src` does not start
// with `---` (after optional BOM/whitespace), the whole input is returned as
// the body and `meta` is empty.
pub fn parse(src string) !Document {
	mut s := src
	if s.starts_with('﻿') {
		s = s[3..]
	}
	if !s.starts_with('---') {
		return Document{
			body: src
		}
	}
	// require newline after first ---
	mut i := 3
	if i < s.len && s[i] == `\r` {
		i++
	}
	if i >= s.len || s[i] != `\n` {
		return Document{
			body: src
		}
	}
	i++
	header_start := i
	closing := find_closing(s, i) or {
		return error('frontmatter: missing closing "---" delimiter')
	}
	header := s[header_start..closing.start]
	body_start := closing.end
	meta := yaml.parse(header) or { return error('frontmatter: ${err}') }
	return Document{
		meta: meta
		body: s[body_start..]
	}
}

struct Closing {
	start int
	end   int
}

fn find_closing(s string, from int) ?Closing {
	mut i := from
	for i < s.len {
		// must be at start of line
		if (i == 0 || s[i - 1] == `\n`) && i + 3 <= s.len && s[i] == `-` && s[i + 1] == `-` && s[i + 2] == `-` {
			j := i + 3
			if j == s.len {
				return Closing{i, j}
			}
			if s[j] == `\n` {
				return Closing{i, j + 1}
			}
			if s[j] == `\r` && j + 1 < s.len && s[j + 1] == `\n` {
				return Closing{i, j + 2}
			}
		}
		i++
	}
	return none
}
