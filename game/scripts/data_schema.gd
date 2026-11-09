class_name DataSchema
extends RefCounted
## The data schema (data/schema.json, docs/architecture/data-schema.md): which kind of entry each dictionary in
## game/data is, the keys each kind may hold (type, the default a missing optional key reads as, the keys every entry
## must have) and the keys that name ids elsewhere. GameData builds one when it loads, checks every data file against
## it once (check), and GameData.opt reads optional keys with its defaults and variants.
##
## What check reports, each as "<file>.json <where>: <what>" through push_error by GameData:
## a key the kind does not list (a typo), a required key missing, a value of the wrong type, and an id that points
## nowhere (a status, ability, item, enemy, affinity, rune, construct word, station or crafting skill).

const SCHEMA_PATH := "res://data/schema.json"

## kind -> {key: default}; kind -> {key: {variant: default}}.
var defaults: Dictionary = {}
var variants: Dictionary = {}
## kind -> {"types": {key: mask}, "ints": {key: true}, "required": Array, "refs": {key: target}}.
var kinds: Dictionary = {}
## file -> {"paths": {pattern: kind}, "idmaps": {pattern: true}, "maps": {pattern: spec}, "kids": {pattern: {key: child
## pattern}}} - the walk goes only where a kind or a map lies below.
var files: Dictionary = {}
var loaded := false

var _errors: Array[String] = []
var _ids: Dictionary = {}
var _file := ""
## The keys and list indices down to the dictionary being checked; joined only when there is something to say.
var _at: Array = []

const _TYPE_BITS := {
	"number": (1 << TYPE_FLOAT) | (1 << TYPE_INT), "int": (1 << TYPE_FLOAT) | (1 << TYPE_INT),
	"string": 1 << TYPE_STRING, "bool": 1 << TYPE_BOOL, "array": 1 << TYPE_ARRAY,
	"object": 1 << TYPE_DICTIONARY, "null": 1 << TYPE_NIL, "any": -1,
}


## Reads data/schema.json. False (and an error) if it is missing or broken.
func load_file(parsed: Dictionary) -> bool:
	if parsed.is_empty():
		return false
	for kind: String in parsed.get("kinds", {}):
		var ko: Dictionary = parsed["kinds"][kind]
		var types: Dictionary = {}
		var ints: Dictionary = {}
		var dflt: Dictionary = {}
		var vars: Dictionary = {}
		var keys: Dictionary = ko.get("keys", {})
		for key: String in keys:
			var spec: Array = keys[key]
			var tstr: String = str(spec[0])
			types[key] = _mask(tstr)
			var is_int: bool = tstr.split("|").has("int")
			if is_int:
				ints[key] = true
			if spec.size() > 1:
				dflt[key] = _typed(spec[1], is_int)
			if spec.size() > 2:
				var vs: Dictionary = {}
				for v: String in spec[2]:
					vs[v] = _typed(spec[2][v], is_int)
				vars[key] = vs
		kinds[kind] = {"types": types, "ints": ints, "required": ko.get("required", []), "refs": ko.get("refs", {})}
		defaults[kind] = dflt
		variants[kind] = vars
	for f: String in parsed.get("files", {}):
		var fo: Dictionary = parsed["files"][f]
		var descend: Dictionary = {}
		var paths: Dictionary = fo.get("paths", {})
		var maps: Dictionary = fo.get("maps", {})
		for pat: String in paths.keys() + maps.keys():
			_add_prefixes(descend, pat)
		var idm: Dictionary = {}
		for p: String in fo.get("idmaps", []):
			idm[p] = true
		var skip: Array = fo.get("skip", [])
		# pattern -> {child key ("*" for an id map's entries, "[]" for a list's elements): child pattern}
		var kids: Dictionary = {}
		for q: String in descend:
			if q == "" or skip.has(q):
				continue
			var parent: String
			var key: String
			if q.ends_with("[]"):
				parent = q.substr(0, q.length() - 2)
				key = "[]"
			else:
				var dot: int = q.rfind(".")
				parent = q.substr(0, dot) if dot >= 0 else ""
				key = q.substr(dot + 1)
			if not kids.has(parent):
				kids[parent] = {}
			kids[parent][key] = q
		files[f] = {"paths": paths, "idmaps": idm, "maps": maps, "kids": kids}
	loaded = true
	return true


## Every problem in the data: `data` is {file name without .json: parsed file}, `ids` {target: {id: true}} for the
## reference checks (a target "affinity+own+plain" also takes the words after it). Returns the messages (empty when
## the data is clean).
func check(data: Dictionary, ids: Dictionary) -> Array[String]:
	_errors = []
	_ids = ids
	for f: String in files:
		if not data.has(f):
			_errors.append("%s.json: not loaded for the check" % f)
			continue
		_file = f
		_at = []
		_walk(files[f], data[f], "")
	return _errors


func _where(extra: String = "") -> String:
	var s := ""
	for part: Variant in _at:
		if part is int:
			s += "[%d]" % part
		else:
			s += ("." if s != "" else "") + str(part)
	if extra != "":
		s += ("." if s != "" else "") + extra
	return "%s.json %s" % [_file, s]


func _walk(fo: Dictionary, v: Variant, pat: String) -> void:
	var kids: Dictionary = (fo["kids"] as Dictionary).get(pat, {})
	if v is Dictionary:
		var d: Dictionary = v
		var spec: Variant = (fo["maps"] as Dictionary).get(pat)
		var is_id: bool = (fo["idmaps"] as Dictionary).has(pat)
		if spec != null:
			_check_map(d, spec)
		elif not is_id:
			var kind: Variant = (fo["paths"] as Dictionary).get(pat)
			if kind != null:
				_check_entry(d, kind)
		if kids.is_empty():
			return
		if is_id:
			var child: Variant = kids.get("*")
			if child != null:
				for k: Variant in d:
					_at.append(k)
					_walk(fo, d[k], child)
					_at.pop_back()
			return
		for key: String in kids:
			if d.has(key):
				_at.append(key)
				_walk(fo, d[key], kids[key])
				_at.pop_back()
	elif v is Array:
		var child2: Variant = kids.get("[]")
		if child2 == null:
			return
		var arr: Array = v
		for i: int in arr.size():
			var x: Variant = arr[i]
			if x is Dictionary or x is Array:
				_at.append(i)
				_walk(fo, x, child2)
				_at.pop_back()


func _check_entry(d: Dictionary, kind: String) -> void:
	var ko: Dictionary = kinds.get(kind, {})
	if ko.is_empty():
		_errors.append("%s: kind '%s' is not in the schema" % [_where(), kind])
		return
	var types: Dictionary = ko["types"]
	var ints: Dictionary = ko["ints"]
	for key: Variant in d:
		var mask: Variant = types.get(key)
		if mask == null:
			if not str(key).begins_with("_"):
				_errors.append("%s: unknown key '%s' (not a key of %s)" % [_where(), str(key), kind])
			continue
		var val: Variant = d[key]
		if int(mask) != -1 and (int(mask) & (1 << typeof(val))) == 0:
			_errors.append("%s: %s where %s wants %s" % [_where(str(key)), _tname(val), kind, _mask_text(mask)])
		elif val is float and ints.has(key) and float(val) != floorf(float(val)):
			_errors.append("%s: %s, but it is read as a whole number" % [_where(str(key)), str(val)])
	var required: Array = ko["required"]
	if not d.has_all(required):
		for req: Variant in required:
			if not d.has(req):
				_errors.append("%s: missing required key '%s' (%s)" % [_where(), str(req), kind])
	var refs: Dictionary = ko["refs"]
	for rk: String in refs:
		if rk.ends_with("[]"):
			var lk: String = rk.trim_suffix("[]")
			var list: Variant = d.get(lk)
			if list is Array:
				for x: Variant in list:
					_ref(lk, x, refs[rk])
		else:
			var one: Variant = d.get(rk)
			if one is String:
				_ref(rk, one, refs[rk])


func _check_map(d: Dictionary, spec: Dictionary) -> void:
	var key_target: Variant = spec.get("keys")
	var mask: int = _mask(str(spec.get("values", "any")))
	var value_target: String = str(spec.get("value_refs", ""))
	for k: Variant in d:
		if str(k).begins_with("_"):
			continue
		if key_target is String:
			_ref("", k, key_target)
		var val: Variant = d[k]
		if mask != -1 and (mask & (1 << typeof(val))) == 0:
			_errors.append("%s: %s where %s" % [_where(str(k)), _tname(val), _mask_text(mask)])
		if value_target != "" and val is String:
			_ref(str(k), val, value_target)


## One id check; "" means "none" and is fine. `target` may carry allowed words after "+" ("affinity+own+plain").
func _ref(key: String, id: Variant, target: String) -> void:
	if not (id is String) or str(id) == "":
		return
	var plus: int = target.find("+")
	var set_name: String = target if plus < 0 else target.substr(0, plus)
	if (_ids.get(set_name, {}) as Dictionary).has(id):
		return
	if plus >= 0 and target.substr(plus + 1).split("+").has(id):
		return
	_errors.append("%s: '%s' is not a known %s" % [_where(key), str(id), set_name])


## Every prefix of a pattern at a segment boundary ("a.*.b[]" -> a, a.*, a.*.b, a.*.b[]).
static func _add_prefixes(out: Dictionary, pat: String) -> void:
	for i: int in pat.length():
		var c: String = pat[i]
		if c == "." or c == "[":
			out[pat.substr(0, i)] = true
	out[pat] = true


static func _mask(tstr: String) -> int:
	var m := 0
	for t: String in tstr.split("|"):
		var bits: int = _TYPE_BITS.get(t, -1)
		if bits == -1:
			return -1
		m |= bits
	return m


static func _mask_text(mask: int) -> String:
	var out: Array[String] = []
	for t: String in ["number", "string", "bool", "array", "object", "null"]:
		if mask & int(_TYPE_BITS[t]):
			out.append(t)
	return " or ".join(out)


static func _tname(v: Variant) -> String:
	match typeof(v):
		TYPE_FLOAT, TYPE_INT:
			return "a number"
		TYPE_STRING:
			return "a string"
		TYPE_BOOL:
			return "a bool"
		TYPE_ARRAY:
			return "a list"
		TYPE_DICTIONARY:
			return "an object"
		TYPE_NIL:
			return "null"
	return type_string(typeof(v))


static func _typed(v: Variant, is_int: bool) -> Variant:
	if is_int and (v is float or v is int):
		return int(v)
	return v
