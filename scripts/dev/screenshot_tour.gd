class_name ScreenshotTour
extends Node
## Entwickler-Werkzeug: fährt feste Kamerapositionen ab und speichert Screenshots.
## Start: godot --path . -- --screenshot-tour=/pfad/zum/ordner
## Wird nur geladen, wenn das Argument gesetzt ist.

var out_dir: String = "user://screenshots"

const SHOTS := [
	{"name": "01_ankunft_nachmittag", "hour": 16.5, "pos": Vector3(-3.0, 0.0, 12.0), "look": Vector3(-2.0, 2.0, 0.0)},
	{"name": "02_garten_abend", "hour": 18.2, "pos": Vector3(16.0, 0.0, 16.0), "look": Vector3(0.0, 2.0, 0.0)},
	{"name": "03_wohnzimmer_tag", "hour": 15.0, "pos": Vector3(1.2, 0.45, 3.9), "look": Vector3(-5.5, 1.2, 1.5)},
	{"name": "04_daemmerung_licht_an", "hour": 19.4, "pos": Vector3(-9.0, 0.0, 14.0), "look": Vector3(-1.0, 2.0, 0.0), "lights": true},
	{"name": "05_wohnzimmer_nacht_kamin", "hour": 23.0, "pos": Vector3(1.2, 0.45, 3.9), "look": Vector3(-5.5, 1.2, 1.5)},
	{"name": "06_wald_nacht_taschenlampe", "hour": 23.5, "pos": Vector3(-1.0, 0.0, 30.0), "look": Vector3(4.0, 1.5, 45.0), "flashlight": true},
	{"name": "07_nacht_blick_zur_huette", "hour": 0.5, "pos": Vector3(-3.5, 0.0, 26.0), "look": Vector3(-2.0, 1.5, 0.0), "lights": true},
	{"name": "08_schlafzimmer_nacht", "hour": 22.0, "pos": Vector3(-1.6, 0.45, -1.6), "look": Vector3(-5.0, 0.9, -3.8), "lights": true},
]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--screenshot-tour="):
			out_dir = arg.get_slice("=", 1)
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()


func _run() -> void:
	for i in 20:
		await get_tree().process_frame
	var player := get_tree().get_first_node_in_group("player") as Player
	TimeManager.running = false
	for shot: Dictionary in SHOTS:
		TimeManager.set_time(1, shot["hour"])
		var pos: Vector3 = shot["pos"]
		if pos.y <= 0.0:
			pos.y = Terrain.height_at(pos.x, pos.z)
		player.global_position = pos
		player.velocity = Vector3.ZERO
		var eye := pos + Vector3(0, Player.STAND_HEIGHT - Player.EYE_OFFSET, 0)
		var look: Vector3 = shot["look"]
		var d := (look - eye).normalized()
		player.rotation.y = atan2(-d.x, -d.z)
		player.head.rotation.x = asin(clampf(d.y, -1.0, 1.0))
		player.flashlight.visible = shot.get("flashlight", false)
		for sw in get_tree().get_nodes_in_group("light_switch"):
			sw.set_state(shot.get("lights", false))
		for f in 50:
			await get_tree().process_frame
		var img := get_viewport().get_texture().get_image()
		var path := out_dir.path_join(String(shot["name"]) + ".png")
		img.save_png(path)
		print("Screenshot: ", path)
	get_tree().quit()
