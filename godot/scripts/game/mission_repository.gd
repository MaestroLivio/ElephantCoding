class_name MissionRepository
extends RefCounted

## Loads worlds and missions from data/. The same data feeds the native,
## web and classroom builds. No mission logic lives in the UI.

static var _missions: Dictionary = {}
static var _worlds: Dictionary = {}
static var _loaded := false


static func data_root() -> String:
	# Exported builds keep data inside the PCK; only res:// paths work there.
	# Editor runs also prefer res://data (the synced mirror of ../data).
	if DirAccess.open("res://data/missions") != null:
		return "res://data"
	var candidates := [
		ProjectSettings.globalize_path("res://").path_join("../data").simplify_path(),
		ProjectSettings.globalize_path("res://../data"),
	]
	for c in candidates:
		if DirAccess.dir_exists_absolute(c.path_join("missions")):
			return c
	return candidates[0]


static func load_all() -> void:
	if _loaded:
		return
	_loaded = true
	var root := data_root()
	var mdir := root.path_join("missions")
	var d := DirAccess.open(mdir)
	if d != null:
		for f in d.get_files():
			if not f.ends_with(".json") or f == "source_catalog.json":
				continue
			var m = _read_json(mdir.path_join(f))
			if typeof(m) == TYPE_DICTIONARY and m.has("id"):
				_missions[str(m.id)] = m
	var wdir := root.path_join("worlds")
	var wd := DirAccess.open(wdir)
	if wd != null:
		for f in wd.get_files():
			if not f.ends_with(".json"):
				continue
			var w = _read_json(wdir.path_join(f))
			if typeof(w) == TYPE_DICTIONARY and w.has("id"):
				_worlds[str(w.id)] = w


static func _read_json(path: String):
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_warning("Data file vuoto o non leggibile: " + path)
		return null
	return JSON.parse_string(text)


static func missions() -> Array:
	load_all()
	var out: Array = _missions.values()
	out.sort_custom(func(a, b): return str(a.id) < str(b.id))
	return out


static func mission(id: String) -> Dictionary:
	load_all()
	return _missions.get(id, {})


static func worlds() -> Array:
	load_all()
	var out: Array = _worlds.values()
	out.sort_custom(func(a, b): return str(a.code) < str(b.code))
	return out


static func world(id: String) -> Dictionary:
	load_all()
	return _worlds.get(id, {})


static func world_missions(world_id: String) -> Array:
	var out: Array = []
	for m in missions():
		if str(m.get("world", "")) == world_id:
			out.append(m)
	return out


static func mission_ids(world_id: String) -> Array:
	var out: Array = []
	for m in world_missions(world_id):
		out.append(str(m.id))
	return out


static func total_missions() -> int:
	return missions().size()
