extends SceneTree

## Headless test runner: validates all 90 missions, runs reference and failure programs.
## godot --headless --path godot --script res://tests/test_runner.gd

const SimClass := preload("res://scripts/core/simulator.gd")

var failed := 0
var passed := 0
var failures: Array[String] = []


func _initialize() -> void:
	var data_dir := ProjectSettings.globalize_path("res://").path_join("../data/missions").simplify_path()
	var dir := DirAccess.open(data_dir)
	if dir == null:
		printerr("Cannot open ", data_dir)
		quit(2)
		return
	var files: Array[String] = []
	for f in dir.get_files():
		if f.ends_with(".json") and f != "source_catalog.json":
			files.append(f)
	files.sort()
	print("ElephantCoding test runner: ", files.size(), " mission files")
	for f in files:
		var path := data_dir.path_join(f)
		var text := FileAccess.get_file_as_string(path)
		var parsed = JSON.parse_string(text)
		if typeof(parsed) != TYPE_DICTIONARY:
			_fail(f, "invalid JSON")
			continue
		_test_mission(parsed, f)
	print("\nPASS: ", passed, "  FAIL: ", failed)
	if failed > 0:
		for item in failures:
			printerr("  - ", item)
		quit(1)
	else:
		quit(0)


func _test_mission(m: Dictionary, file: String) -> void:
	var required := ["id", "world", "title", "grid", "spawn", "goal", "reference_program", "hints", "tests"]
	for k in required:
		if not m.has(k):
			_fail(file, "missing field " + k)
			return
	if m.hints.size() != 3:
		_fail(m.id, "expected 3 hints")
	var ref: String = m.reference_program
	var sim = SimClass.new()
	sim.setup(m)
	var res: Dictionary = sim.run(ref)
	if not res.success:
		_fail(m.id, "reference FAILED: " + str(res.failure_reason) + " | " + ref.replace("\n", " ; "))
	else:
		_passed()
	for t in m.tests:
		var mm: Dictionary = m.duplicate(true)
		if t.has("override"):
			for key in t.override:
				mm[key] = t.override[key]
		var s2 = SimClass.new()
		s2.setup(mm)
		var r2: Dictionary = s2.run(t.program)
		if bool(r2.success) != bool(t.expect_success):
			_fail(m.id + "/" + t.name, "expected success=" + str(t.expect_success) + " got=" + str(r2.success) + " reason=" + str(r2.failure_reason))
		else:
			_passed()


func _fail(id: String, msg: String) -> void:
	failed += 1
	failures.append(id + ": " + msg)


func _passed() -> void:
	passed += 1
