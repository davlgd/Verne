// Value is the runtime type the engine evaluates over. Templates only see
// these — anything richer (a `&Page`, a `&Site`) is exposed via Object's
// getter, lazily, so we never deep-clone domain objects into a context map.
module template

import time

pub type Value = []Value
	| DateValue
	| NoneValue
	| Object
	| SafeString
	| bool
	| i64
	| map[string]Value
	| string

pub struct NoneValue {}

pub const none_value = Value(NoneValue{})

// SafeString opts out of HTML escaping. Used by `safe`, `markdownify`, etc.
pub struct SafeString {
pub:
	value string
}

pub struct DateValue {
pub:
	t time.Time
}

@[heap]
pub struct Object {
pub:
	name   string
	getter fn (string) ?Value @[required]
}

// get resolves a field on the object lazily, returning none when the field
// is unknown.
pub fn (o &Object) get(field string) ?Value {
	return o.getter(field)
}

// truthy: false, 0, "", none, empty list/map, are falsy. Everything else is
// truthy (including empty strings inside SafeString — that's an explicit
// "trust me" wrapper).
pub fn truthy(v Value) bool {
	return match v {
		bool { v }
		i64 { v != 0 }
		string { v.len > 0 }
		SafeString { true }
		DateValue { true }
		NoneValue { false }
		[]Value { v.len > 0 }
		map[string]Value { v.len > 0 }
		Object { true }
	}
}

// to_string renders a Value to its display form (the same form used by
// `{{ value }}` interpolation).
pub fn to_string(v Value) string {
	return match v {
		string {
			v
		}
		SafeString {
			v.value
		}
		bool {
			v.str()
		}
		i64 {
			v.str()
		}
		DateValue {
			v.t.format()
		}
		NoneValue {
			''
		}
		[]Value {
			mut parts := []string{cap: v.len}
			for el in v {
				parts << to_string(el)
			}
			parts.join(' ')
		}
		map[string]Value {
			'<map>'
		}
		Object {
			'<object:${v.name}>'
		}
	}
}

// equals returns true when both values are equal under the engine's loose
// rules (string ↔ SafeString are interchangeable, all other comparisons are
// strict same-variant).
pub fn equals(a Value, b Value) bool {
	return match a {
		string {
			if b is string {
				a == b
			} else if b is SafeString {
				a == b.value
			} else {
				false
			}
		}
		i64 {
			if b is i64 {
				a == b
			} else {
				false
			}
		}
		bool {
			if b is bool {
				a == b
			} else {
				false
			}
		}
		SafeString {
			if b is SafeString {
				a.value == b.value
			} else if b is string {
				a.value == b
			} else {
				false
			}
		}
		NoneValue {
			b is NoneValue
		}
		else {
			false
		}
	}
}

// compare returns -1, 0, 1 for ordered pairs (numbers and strings), or none
// for incomparable types.
pub fn compare(a Value, b Value) ?int {
	if a is i64 && b is i64 {
		return if a < b {
			-1
		} else if a > b {
			1
		} else {
			0
		}
	}
	if a is string && b is string {
		return if a < b {
			-1
		} else if a > b {
			1
		} else {
			0
		}
	}
	return none
}

// length returns the size of strings, lists and maps; 0 otherwise.
pub fn length(v Value) int {
	return match v {
		string { v.len }
		SafeString { v.value.len }
		[]Value { v.len }
		map[string]Value { v.len }
		else { 0 }
	}
}

// is_empty mirrors the `is empty` template test: none, empty string, empty
// list and empty map are empty.
pub fn is_empty(v Value) bool {
	return match v {
		NoneValue { true }
		string { v.len == 0 }
		SafeString { v.value.len == 0 }
		[]Value { v.len == 0 }
		map[string]Value { v.len == 0 }
		else { false }
	}
}

// type_name returns the user-visible name of the variant, used by error
// messages and the `is string` / `is number` / … tests.
pub fn type_name(v Value) string {
	return match v {
		string { 'string' }
		i64 { 'number' }
		bool { 'bool' }
		SafeString { 'string' }
		DateValue { 'date' }
		NoneValue { 'none' }
		[]Value { 'list' }
		map[string]Value { 'map' }
		Object { 'object' }
	}
}
