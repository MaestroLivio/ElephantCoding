extends Node

## Local-only profile, progress and settings service.
## No account, no network, no personal data required.

signal progress_changed
signal settings_changed
signal profile_changed

const SAVE_PATH := "user://elephantcoding_profile.json"
const SCHEMA_VERSION := 2
const MAX_PROFILES := 8

const DEFAULT_SETTINGS := {
	"camera_mode": "fixed",
	"subtitles": true,
	"voice": true,
	"tts_fallback": true,
	"volume": 0.9,
	"high_contrast": false,
	"reduce_motion": false,
	"large_controls": true,
	"touch_controls": true,
	"classroom_mode": false,
	"ui_scale": 1.0,
	"fps": 60,
	"show_solution": false,
	"teacher_pin": "",
	"language": "it",
	"free_worlds": true,
}

var profiles: Array = []
var active_index := 0
var settings: Dictionary = {}
var _loaded := false


func _ready() -> void:
	load_state()


func load_state() -> void:
	settings = DEFAULT_SETTINGS.duplicate(true)
	if not FileAccess.file_exists(SAVE_PATH):
		profiles = [_default_profile("Esploratore")]
		active_index = 0
		_loaded = true
		save_state()
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		profiles = [_default_profile("Esploratore")]
		active_index = 0
		_loaded = true
		return
	var txt := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(txt)
	if typeof(parsed) != TYPE_DICTIONARY:
		profiles = [_default_profile("Esploratore")]
		active_index = 0
		_loaded = true
		return
	for k in parsed.get("settings", {}):
		if settings.has(k):
			settings[k] = parsed.settings[k]
	var loaded_profiles = parsed.get("profiles", [])
	if loaded_profiles is Array and not loaded_profiles.is_empty():
		profiles = []
		for p in loaded_profiles:
			if p is Dictionary and p.has("nickname"):
				profiles.append(_normalise_profile(p))
		if profiles.is_empty():
			profiles = [_default_profile("Esploratore")]
	active_index = clampi(int(parsed.get("active", 0)), 0, profiles.size() - 1)
	_loaded = true


func save_state() -> void:
	var payload := {
		"schema_version": SCHEMA_VERSION,
		"active": active_index,
		"profiles": profiles,
		"settings": settings,
		"saved_at": Time.get_datetime_string_from_system(true),
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_error("Impossibile salvare il profilo in " + SAVE_PATH)
		return
	f.store_string(JSON.stringify(payload, "  "))
	f.close()


func _default_profile(nickname: String) -> Dictionary:
	return {
		"nickname": nickname,
		"created_at": Time.get_datetime_string_from_system(true),
		"progress": {},
		"creations": [],
		"badges": [],
	}


func _normalise_profile(p: Dictionary) -> Dictionary:
	var out := _default_profile(str(p.get("nickname", "Esploratore")))
	out.created_at = str(p.get("created_at", out.created_at))
	if p.get("progress") is Dictionary:
		out.progress = p.progress
	if p.get("creations") is Array:
		out.creations = p.creations
	if p.get("badges") is Array:
		out.badges = p.badges
	return out


func current_profile() -> Dictionary:
	if profiles.is_empty():
		profiles = [_default_profile("Esploratore")]
	return profiles[clampi(active_index, 0, profiles.size() - 1)]


func current_nickname() -> String:
	return str(current_profile().get("nickname", "Esploratore"))


func new_profile(nickname: String) -> bool:
	if profiles.size() >= MAX_PROFILES:
		return false
	var name := nickname.strip_edges()
	if name.is_empty():
		name = "Esploratore %d" % (profiles.size() + 1)
	profiles.append(_default_profile(name))
	active_index = profiles.size() - 1
	save_state()
	profile_changed.emit()
	return true


func select_profile(index: int) -> void:
	if index >= 0 and index < profiles.size():
		active_index = index
		save_state()
		profile_changed.emit()


func delete_profile(index: int) -> bool:
	if profiles.size() <= 1 or index < 0 or index >= profiles.size():
		return false
	profiles.remove_at(index)
	active_index = clampi(active_index, 0, profiles.size() - 1)
	save_state()
	profile_changed.emit()
	return true


func rename_profile(name: String) -> void:
	var p := current_profile()
	p.nickname = name.strip_edges() if not name.strip_edges().is_empty() else "Esploratore"
	save_state()
	profile_changed.emit()


func progress_for(mission_id: String) -> Dictionary:
	var p := current_profile()
	var all: Dictionary = p.get("progress", {})
	return all.get(mission_id, {"completed": false, "attempts": 0, "best_steps": 0, "hints": 0, "last_at": ""})


func is_complete(mission_id: String) -> bool:
	return bool(progress_for(mission_id).get("completed", false))


func record_attempt(mission_id: String, success: bool, steps: int, hints_used: int) -> void:
	var p := current_profile()
	if not p.has("progress"):
		p.progress = {}
	var pr: Dictionary = p.progress.get(mission_id, {"completed": false, "attempts": 0, "best_steps": 0, "hints": 0, "last_at": ""})
	pr["attempts"] = int(pr.get("attempts", 0)) + 1
	pr["hints"] = maxi(int(pr.get("hints", 0)), hints_used)
	pr["last_at"] = Time.get_datetime_string_from_system(true)
	if success:
		pr["completed"] = true
		var best := int(pr.get("best_steps", 0))
		if best <= 0 or steps < best:
			pr["best_steps"] = steps
	p.progress[mission_id] = pr
	save_state()
	progress_changed.emit()


func award_badge(badge: String) -> void:
	var p := current_profile()
	if not p.has("badges"):
		p.badges = []
	if not p.badges.has(badge):
		p.badges.append(badge)
		save_state()
		profile_changed.emit()


func has_badge(badge: String) -> bool:
	return current_profile().get("badges", []).has(badge)


func completed_count(mission_ids: Array) -> int:
	var n := 0
	for id in mission_ids:
		if is_complete(str(id)):
			n += 1
	return n


func get_setting(key: String, fallback = null):
	return settings.get(key, fallback)


func set_setting(key: String, value) -> void:
	settings[key] = value
	save_state()
	settings_changed.emit()


func reset_progress() -> void:
	var p := current_profile()
	p.progress = {}
	p.creations = []
	p.badges = []
	save_state()
	progress_changed.emit()


func add_creation(creation: Dictionary) -> void:
	var p := current_profile()
	if not p.has("creations"):
		p.creations = []
	p.creations.append(creation)
	save_state()


func export_progress() -> String:
	var dir := ProjectSettings.globalize_path("user://exports")
	DirAccess.make_dir_recursive_absolute(dir)
	var stamp := Time.get_datetime_string_from_system(true).replace(":", "-").replace(" ", "_")
	var path := "user://exports/elephantcoding_%s.json" % stamp
	var payload := {
		"app": "ElephantCoding",
		"schema_version": SCHEMA_VERSION,
		"exported_at": Time.get_datetime_string_from_system(true),
		"active_profile": current_nickname(),
		"profiles": profiles,
		"settings": {"high_contrast": settings.high_contrast, "reduce_motion": settings.reduce_motion},
	}
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return ""
	f.store_string(JSON.stringify(payload, "  "))
	f.close()
	return path


func import_progress(path: String) -> bool:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return false
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY or not (parsed.get("profiles") is Array):
		return false
	for p in parsed.profiles:
		if p is Dictionary and p.has("nickname") and profiles.size() < MAX_PROFILES:
			profiles.append(_normalise_profile(p))
	if profiles.size() > MAX_PROFILES:
		profiles.resize(MAX_PROFILES)
	save_state()
	profile_changed.emit()
	progress_changed.emit()
	return true
