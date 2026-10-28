extends SceneTree

## Headless UI smoke test: builds every screen, runs a mission and exercises
## the block editor. Run with:
##   godot --headless --path godot --script res://tests/ui_smoke.gd

var main: Node
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _wait(0.5)
	_check(main.current_name == "menu", "menu opened at startup")

	for spec in [
		{"name": "worlds", "args": {}},
		{"name": "hub", "args": {"world_id": "giardino"}},
		{"name": "lab", "args": {}},
		{"name": "settings", "args": {}},
		{"name": "teacher", "args": {}},
		{"name": "credits", "args": {}},
	]:
		main.show_screen(str(spec.name), spec.args)
		await _wait(0.55)
		_check(main.current != null, "screen %s exists" % spec.name)
		_check(main.viewport.get_child_count() > 0 or spec.name in ["worlds", "settings", "teacher", "credits"], "screen %s has a stage" % spec.name)

	main.show_screen("mission", {"world_id": "giardino", "mission_id": "P1-01"})
	await _wait(0.6)
	var scr = main.current
	_check(scr != null and scr.mission_id == "P1-01", "mission loaded")
	if scr == null:
		_finish()
		return

	_check(scr.editor.is_graphic(), "P1-01 uses the graphic command tray")
	_check(not scr.editor._tabs.visible, "graphic missions hide the text tab")
	_check(not scr._right_open, "elementary mission starts with the help drawer closed")
	_check(scr.editor._palette.get_child_count() >= 7, "graphic tray exposes command tiles")
	scr.editor.blocks = []
	scr.editor._target = scr.editor.blocks
	scr.editor._rebuild()
	scr.editor._palette.get_child(0).pressed.emit()
	_check(scr.editor.blocks.size() == 1, "a command tile appends a block")
	_check(scr.editor.get_source() == "SINISTRA", "the first tile serialises SINISTRA")
	var field_open: float = scr.rig.safe_rect.size.x
	scr._toggle_left_panel()
	await process_frame
	_check(scr.rig.safe_rect.size.x > field_open, "collapsing the program drawer enlarges the field")
	scr._toggle_left_panel()
	await process_frame
	_check(absf(scr.rig.safe_rect.size.x - field_open) < 0.001, "reopening restores the field area")

	scr.editor._switch_tab("text")
	scr.editor.set_source("AVANTI 4")
	scr._execute(false)
	await _wait(0.15)
	var guard := 0
	while not scr.playback.is_finished() and guard < 200:
		scr.playback.step()
		guard += 1
		await process_frame
	_check(bool(scr.result.get("success", false)), "P1-01 executes through the UI")

	# Block editor round-trip.
	scr.editor._switch_tab("blocks")
	scr.editor.blocks = []
	scr.editor._target = scr.editor.blocks
	scr.editor._add_block("AVANTI")
	scr.editor._add_block("RIPETI")
	scr.editor._add_block("DESTRA")
	scr.editor._add_block("AVANTI")
	var serialized: String = scr.editor.get_source()
	_check(serialized.contains("RIPETI x3"), "block editor serialises loops")
	_check(serialized.contains("DESTRA"), "block editor serialises turns")

	# Graphic-only path: a child can finish INF-01 without ever seeing text.
	main.show_screen("mission", {"world_id": "savana", "mission_id": "INF-01"})
	await _wait(0.5)
	scr = main.current
	_check(_press_tile(scr.editor, "AVANTI"), "graphic tray exposes AVANTI")
	scr._execute(false)
	await _wait(0.1)
	var graphic_guard := 0
	while not scr.playback.is_finished() and graphic_guard < 200:
		scr.playback.step()
		graphic_guard += 1
		await process_frame
	_check(bool(scr.result.get("success", false)), "INF-01 succeeds with the graphic tray only")

	main.show_screen("mission", {"world_id": "cittadella", "mission_id": "S1-01"})
	await _wait(0.5)
	scr = main.current
	scr.editor._switch_tab("text")
	scr.editor.set_source(str(scr.mission.get("reference_program", "")))
	scr._execute(true)
	await _wait(0.2)
	scr.playback.speed = 60.0
	await _wait(2.0)
	_check(bool(scr.result.get("success", false)), "S1-01 reference program succeeds")

	main.show_screen("mission", {"world_id": "isola", "mission_id": "P4-01"})
	await _wait(0.5)
	scr = main.current
	scr.editor._switch_tab("text")
	scr.editor.set_source("VAI A (2,1)")
	scr._execute(true)
	scr.playback.speed = 60.0
	await _wait(1.5)
	_check(bool(scr.result.get("success", false)), "P4-01 coordinate program succeeds")

	_finish()


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout


## Presses the graphic command tile with the given caption.
func _press_tile(editor, caption: String) -> bool:
	for i in range(editor._palette.get_child_count()):
		var tile: Button = editor._palette.get_child(i)
		if tile.tooltip_text == caption:
			tile.pressed.emit()
			return true
	return false


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok   ", label)
	else:
		failures.append(label)
		printerr("  FAIL ", label)


func _finish() -> void:
	print("\nUI SMOKE: %d failures" % failures.size())
	if failures.is_empty():
		quit(0)
	else:
		for f in failures:
			printerr(" - ", f)
		quit(1)
