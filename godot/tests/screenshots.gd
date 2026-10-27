extends SceneTree

## Development helper: renders every screen to PNG for visual review.
## Run without --headless:
##   godot --path godot --script res://tests/screenshots.gd

const OUT := "/private/var/folders/r0/hr61pl8j4xg9rqr18ktbmvg00000gn/T/opencode/ec_shots"

var main: Node


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	call_deferred("_run")


func _run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _wait(1.0)
	await _shot("01_menu")

	main.show_screen("worlds")
	await _wait(0.8)
	await _shot("02_worlds")

	main.show_screen("hub", {"world_id": "giardino"})
	await _wait(1.0)
	await _shot("03_hub")

	main.show_screen("mission", {"world_id": "giardino", "mission_id": "P1-01"})
	await _wait(1.0)
	await _shot("04_mission_icons")

	var scr = main.current
	scr._toggle_left_panel()
	await _wait(0.6)
	await _shot("04b_mission_field")
	scr._toggle_left_panel()
	await _wait(0.4)

	main.show_screen("mission", {"world_id": "savana", "mission_id": "INF-01"})
	await _wait(0.8)
	await _shot("04c_mission_inf")
	main.show_screen("mission", {"world_id": "giardino", "mission_id": "P1-01"})
	await _wait(0.8)
	scr = main.current
	scr.editor.blocks = [{"op": "AVANTI", "n": 4}]
	scr.editor._target = scr.editor.blocks
	scr.editor._rebuild()
	scr._execute(true)
	await _wait(1.2)
	await _shot("05_mission_running")
	scr.playback.speed = 40.0
	await _wait(2.0)
	await _shot("06_mission_success")

	main.show_screen("mission", {"world_id": "cittadella", "mission_id": "S1-01"})
	await _wait(0.9)
	await _shot("07_mission_text")

	main.show_screen("lab")
	await _wait(0.9)
	await _shot("08_lab")

	main.show_screen("settings")
	await _wait(0.8)
	await _shot("09_settings")

	main.show_screen("teacher")
	await _wait(0.9)
	await _shot("10_teacher")

	main.show_screen("credits")
	await _wait(0.8)
	await _shot("11_credits")

	quit()


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout


func _shot(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	if img == null:
		printerr("No image for ", name)
		return
	img.save_png(OUT.path_join(name + ".png"))
	print("saved ", name, " ", img.get_width(), "x", img.get_height())
