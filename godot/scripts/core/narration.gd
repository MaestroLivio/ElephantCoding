extends Node

## Narrative voice + subtitles.
## Prefers a recorded CC-BY neural voice pack in res://assets/audio/voice/it/.
## If a clip is missing, optionally uses the operating-system TTS as a
## development fallback. Subtitles are always available.

signal subtitle(text: String, seconds: float)
signal finished

const VOICE_DIR := "res://assets/audio/voice/it/"
var _player: AudioStreamPlayer
var _current_text := ""
var _tts_active := false
var _fallback_warned := false


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.bus = "Master"
	add_child(_player)
	_player.finished.connect(_on_finished)


func speak(line_id: String, text: String, seconds := 6.0) -> void:
	stop()
	_current_text = text
	var enabled := bool(GameState.get_setting("voice", true))
	if enabled:
		var path := VOICE_DIR + line_id + ".ogg"
		if ResourceLoader.exists(path):
			var stream = load(path)
			if stream is AudioStream:
				_player.stream = stream
				_player.volume_db = linear_to_db(clampf(float(GameState.get_setting("volume", 0.9)), 0.0, 1.0))
				_player.play()
				subtitle.emit(text, maxf(seconds, 3.0))
				return
		elif bool(GameState.get_setting("tts_fallback", true)):
			_speak_tts(text)
	if bool(GameState.get_setting("subtitles", true)):
		subtitle.emit(text, seconds)


func _speak_tts(text: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var voices := DisplayServer.tts_get_voices_for_language("it")
	if voices.is_empty():
		if not _fallback_warned:
			_fallback_warned = true
			push_warning("Nessuna voce TTS italiana disponibile. Verranno mostrati solo i sottotitoli.")
		return
	_tts_active = true
	DisplayServer.tts_speak(text, voices[0], int(clampf(float(GameState.get_setting("volume", 0.9)), 0.0, 1.0) * 100.0))
	subtitle.emit(text, maxf(3.0, float(text.length()) * 0.06))
	# TTS has no reliable finished callback on every platform: release the flag.
	get_tree().create_timer(maxf(2.0, float(text.length()) * 0.06)).timeout.connect(func(): _tts_active = false)


func stop() -> void:
	if _player != null:
		_player.stop()
	if _tts_active and DisplayServer.get_name() != "headless":
		DisplayServer.tts_stop()
	_tts_active = false


func _on_finished() -> void:
	finished.emit()


func available_voice_lines() -> Array:
	var dir := DirAccess.open(VOICE_DIR)
	if dir == null:
		return []
	var out: Array = []
	for f in dir.get_files():
		if f.ends_with(".ogg"):
			out.append(f.get_basename())
	return out
