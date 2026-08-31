module main

// flag_column returns the tokens of a help line's left column, with the
// comma between short and long form dropped: `  -u, --base-url URL    …`
// becomes `['-u', '--base-url', 'URL']`.
fn flag_column(line string) []string {
	trimmed := line.trim_space()
	end := trimmed.index('  ') or { trimmed.len }
	return trimmed[..end].replace(',', ' ').fields()
}

fn test_every_command_is_documented() {
	for c in commands {
		assert c.name != ''
		assert c.args != ''
		assert c.summary != '', '${c.name}: missing one-line summary'
		assert !c.summary.ends_with('.'), '${c.name}: summary reads as a table cell, not a sentence'
		assert c.about != '', '${c.name}: missing description'
		assert c.flags.len > 0, '${c.name}: no flags documented'
		for line in c.about.split('\n') {
			// Runes, not bytes: the paragraphs carry em dashes, and a byte
			// count would measure each of them as three columns.
			assert line.runes().len <= 78, '${c.name}: help paragraph wraps past 78 columns: ${line}'
		}
	}
}

fn test_find_command_matches_the_table() {
	for c in commands {
		found := find_command(c.name) or { panic('${c.name} missing from the table') }
		assert found.name == c.name
	}
	assert find_command('serve') == none
	assert find_command('') == none
}

fn test_command_names_reads_as_a_list() {
	assert command_names() == 'init, build, server, or clean'
}

// A flag no parser accepts, used to stop an argument loop on demand.
const unknown_flag = '--zzz-not-a-flag'

// The help table is only useful if the parsers agree with it, so every
// documented flag goes back through its own command and the error must
// never be about that flag.
//
// A flag that takes a value is passed alone: the parser has to complain
// that the value is missing. A boolean flag is passed ahead of
// `unknown_flag`, which the loop can only reach by having accepted the
// boolean one first — and it still fails while parsing, so the command
// never runs.
fn test_documented_flags_are_accepted_by_their_parser() {
	for c in commands {
		for line in c.flags {
			tokens := flag_column(line)
			names := tokens.filter(it.starts_with('-'))
			if names.len == 0 {
				// positional DIR row
				continue
			}
			takes_value := !tokens.last().starts_with('-')
			for name in names {
				args := if takes_value { [name] } else { [name, unknown_flag] }
				want := if takes_value {
					'${c.name}: ${name} requires a value'
				} else {
					'${c.name}: unknown flag `${unknown_flag}`'
				}
				run_command(c.name, args) or {
					assert err.msg() == want, 'help documents `${name}` for `${c.name}`, but the parser says: ${err.msg()}'
					continue
				}
				assert false, '${c.name} ${args.join(' ')} unexpectedly succeeded'
			}
		}
	}
}

fn test_unknown_command_has_no_handler() {
	run_command('nope', []) or {
		assert err.msg().contains('no handler')
		return
	}
	assert false, 'run_command accepted an undocumented name'
}
