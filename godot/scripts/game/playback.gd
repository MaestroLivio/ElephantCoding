class_name Playback
extends Node

## Replays the deterministic event stream produced by CodingSimulator on the
## 3D stage. The simulator already decided the outcome: this node only makes
## it visible, one event at a time, with pause and single-step support.

signal event_applied(event: Dictionary)
signal finished
signal state_changed(playing: bool, index: int, total: int)

var events: Array = []
var index := 0
var playing := false
var speed := 2.6
var builder: WorldBuilder
var _accum := 0.0
var _event_duration := 0.30

var _turn_duration := 0.16
var _applied_entities: Dictionary = {}


func _ready() -> void:
	set_process(true)


func load_events(p_events: Array, p_builder: WorldBuilder) -> void:
	events = p_events.duplicate(true)
	index = 0
	playing = false
	_accum = 0.0
	builder = p_builder
	_applied_entities.clear()
	state_changed.emit(false, index, events.size())


func play() -> void:
	if index >= events.size():
		reset()
	playing = true
	_accum = 0.0
	state_changed.emit(true, index, events.size())


func pause() -> void:
	playing = false
	state_changed.emit(false, index, events.size())


func toggle() -> void:
	if playing:
		pause()
	else:
		play()


func reset() -> void:
	index = 0
	_accum = 0.0
	playing = false
	for id in _applied_entities:
		if builder != null:
			builder.set_entity_state(str(id), false)
	_applied_entities.clear()
	if builder != null and builder.nilo != null:
		var spawn: Dictionary = builder.mission.get("spawn", {})
		var cell = spawn.get("cell", [0, 0])
		var heading: int = ["N", "E", "S", "W"].find(str(spawn.get("heading", "E")))
		if heading < 0:
			heading = 1
		builder.nilo.teleport(builder.cell_to_world(Vector2i(int(cell[0]), int(cell[1])), 0.04), heading)
		builder.draw_trace([])
	state_changed.emit(false, 0, events.size())


func step() -> bool:
	if index >= events.size():
		return false
	_apply_event(events[index])
	index += 1
	state_changed.emit(false, index, events.size())
	if index >= events.size():
		playing = false
		finished.emit()
	return true


func is_finished() -> bool:
	return index >= events.size()


func _process(delta: float) -> void:
	if not playing or index >= events.size():
		return
	_accum += delta * speed
	if _accum < 1.0:
		return
	_accum = 0.0
	_apply_event(events[index])
	index += 1
	state_changed.emit(true, index, events.size())
	if index >= events.size():
		playing = false
		state_changed.emit(false, index, events.size())
		finished.emit()


func _apply_event(ev: Dictionary) -> void:
	match str(ev.get("kind", "")):
		"start":
			pass
		"step":
			if builder != null and builder.nilo != null:
				var c = ev.get("cell", [0, 0])
				var heading := int(ev.get("heading", 1))
				builder.nilo.move_to_world(builder.cell_to_world(Vector2i(int(c[0]), int(c[1])), 0.04), heading, _event_duration * 0.9)
			_draw_progress(ev)
		"turn":
			if builder != null and builder.nilo != null:
				builder.nilo.face_heading(int(ev.get("heading", 1)))
		"raccogli", "attiva", "apri", "accendi", "suona", "foto", "scansiona", "lascia", "deposita":
			var id := str(ev.get("entity", ""))
			if id != "" and builder != null:
				builder.set_entity_state(id, true)
				_applied_entities[id] = true
			if builder != null and builder.nilo != null:
				builder.nilo.celebrate()
		"chiudi":
			pass
		"error":
			if builder != null and builder.nilo != null:
				builder.nilo.oops()
	event_applied.emit(ev)


func _draw_progress(_ev: Dictionary) -> void:
	if builder == null:
		return
	var cells: Array = []
	for i in range(0, index + 1):
		var e: Dictionary = events[i]
		if str(e.get("kind", "")) == "step":
			cells.append(e.get("cell", [0, 0]))
	if not cells.is_empty():
		builder.draw_trace(cells)
