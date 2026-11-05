class_name ScreenshotTour
extends Node
## Entwickler-Werkzeug: fährt feste Kamerapositionen ab und speichert Screenshots.
## Start: godot --path . -- --screenshot-tour=/pfad/zum/ordner
## Wird nur geladen, wenn das Argument gesetzt ist.

var out_dir: String = "user://screenshots"
## Optional nur bestimmte Bilder, z. B. --shots=01,05
var only: PackedStringArray = []
## Frames bis zum Foto (Nebel/Schatten brauchen ein paar Bilder zum Einschwingen).
var frames: int = 50

const SHOTS := [
	{"name": "01_ankunft_nachmittag", "hour": 16.5, "pos": Vector3(-3.0, 0.0, 12.0), "look": Vector3(-2.0, 2.0, 0.0)},
	{"name": "02_garten_abend", "hour": 18.2, "pos": Vector3(16.0, 0.0, 16.0), "look": Vector3(0.0, 2.0, 0.0)},
	{"name": "03_wohnzimmer_tag", "hour": 15.0, "pos": Vector3(1.2, 0.45, 3.9), "look": Vector3(-5.5, 1.2, 1.5)},
	{"name": "04_daemmerung_licht_an", "hour": 19.4, "pos": Vector3(-9.0, 0.0, 14.0), "look": Vector3(-1.0, 2.0, 0.0), "lights": true},
	{"name": "05_wohnzimmer_nacht_kamin", "hour": 23.0, "pos": Vector3(1.2, 0.45, 3.9), "look": Vector3(-5.5, 1.2, 1.5)},
	{"name": "06_wald_nacht_taschenlampe", "hour": 23.5, "pos": Vector3(-1.0, 0.0, 30.0), "look": Vector3(4.0, 1.5, 45.0), "flashlight": true},
	{"name": "07_nacht_blick_zur_huette", "hour": 0.5, "pos": Vector3(-3.5, 0.0, 26.0), "look": Vector3(-2.0, 1.5, 0.0), "lights": true},
	{"name": "08_schlafzimmer_nacht", "hour": 22.0, "pos": Vector3(-1.6, 0.45, -1.6), "look": Vector3(-5.0, 0.9, -3.8), "lights": true},
	{"name": "09_bach_nachmittag", "hour": 15.5, "pos": Vector3(33.0, 0.0, 2.0), "look": Vector3(38.5, -1.0, 9.0)},
	{"name": "10_kueche_abend_licht", "hour": 21.0, "pos": Vector3(-3.6, 0.45, 3.6), "look": Vector3(-0.8, 1.3, -0.9), "lights": true},
	{"name": "12_kreatur_waldrand", "hour": 22.5, "pos": Vector3(-3.0, 0.45, 5.6), "look": Vector3(-3.5, 1.6, 15.0), "flashlight": true, "creature_at": Vector3(-3.5, 0, 14.0), "lights": true},
	{"name": "13_monitor_veranda", "hour": 22.6, "pos": Vector3(0.9, 0.45, 3.6), "look": Vector3(1.4, 1.4, 3.6), "monitor": true, "creature_at": Vector3(-4.0, 0, 13.0)},
	{"name": "14_fenster_kaputt", "hour": 21.5, "pos": Vector3(0.0, 0.45, 2.6), "look": Vector3(0.0, 1.5, 4.5), "lights": true, "break_window": true, "creature_at": Vector3(0.2, 0, 5.4)},
	{"name": "15_autowrack", "hour": 15.0, "pos": Vector3(1.6, 0.0, 29.6), "look": Vector3(4.6, 0.6, 33.0)},
	{"name": "16_werkbank", "hour": 14.0, "pos": Vector3(4.2, 0.45, 1.7), "look": Vector3(5.6, 1.2, 1.7), "menu": "crafting"},
	{"name": "17_verteidigung_nacht", "hour": 22.5, "pos": Vector3(-3.0, 0.45, 6.0), "look": Vector3(-2.0, 0.6, 14.0), "lights": true, "flashlight": true,
		"build": [["fence_panel", Vector3(-6.5, 0, 12.5), 0.2], ["spike_barricade", Vector3(-1.0, 0, 12.0), 0.0], ["stone_wall", Vector3(2.5, 0, 13.0), -0.3],
			["can_alarm", Vector3(-3.0, 0, 15.5), 0.0], ["motion_light", Vector3(1.5, 0, 10.5), 2.6]], "creature_at": Vector3(-1.5, 0, 16.5)},
	{"name": "18_maisfeld", "hour": 16.0, "pos": Vector3(8.0, 0.0, 5.5), "look": Vector3(17.0, 1.0, 12.5)},
	{"name": "19_regentonne", "hour": 14.0, "pos": Vector3(8.7, 0.0, -0.9), "look": Vector3(6.9, 0.5, -2.6)},
	{"name": "20_kamera_hausfront", "hour": 15.0, "pos": Vector3(4.2, 0.0, 9.0), "look": Vector3(5.6, 2.6, 4.9)},
	{"name": "21_maisfeld_nacht_monitor", "hour": 23.0, "pos": Vector3(0.9, 0.45, 3.6), "look": Vector3(1.4, 1.4, 3.6), "monitor": true, "monitor_cam": 2, "creature_at": Vector3(18.0, 0, 14.0)},
	{"name": "22_vorrat_symbole", "hour": 21.0, "pos": Vector3(0.7, 0.45, -2.5), "look": Vector3(0.7, 1.35, -4.1), "lights": true},
	{"name": "23_technik_kanister", "hour": 21.0, "pos": Vector3(3.5, 0.45, -2.6), "look": Vector3(2.975, 0.62, -4.2), "lights": true},
	{"name": "24_schuppendach", "hour": 15.5, "pos": Vector3(8.6, 0.0, 1.6), "look": Vector3(14.0, 2.0, 6.5)},
	{"name": "25_bach_verlauf", "hour": 15.0, "pos": Vector3(30.0, 0.0, -14.0), "look": Vector3(36.0, -1.5, 6.0)},
	{"name": "26_kamera_schuppen", "hour": 15.0, "pos": Vector3(0.9, 0.45, 3.6), "look": Vector3(1.4, 1.4, 3.6), "monitor": true, "monitor_cam": 2},
	{"name": "27_kreatur_nah_tag", "hour": 13.0, "pos": Vector3(3.0, 0.0, 9.8), "look": Vector3(3.0, 1.6, 11.6), "creature_at": Vector3(3.0, 0, 11.6)},
	{"name": "28_kreatur_seite_tag", "hour": 13.0, "pos": Vector3(4.6, 0.0, 10.6), "look": Vector3(3.0, 1.3, 11.6), "creature_at": Vector3(3.0, 0, 11.6), "creature_face": Vector3(-3.0, 0, 13.0)},
	{"name": "29_kreatur_nacht_taschenlampe", "hour": 23.0, "pos": Vector3(3.0, 0.0, 9.6), "look": Vector3(3.0, 1.7, 11.6), "creature_at": Vector3(3.0, 0, 11.6), "flashlight": true},
	{"name": "30_absturzstelle", "hour": 16.0, "pos": Vector3(-36.0, 0.0, -24.5), "look": Vector3(-42.0, 0.2, -30.0)},
	{"name": "11_werkstatt_taschenlampe", "hour": 23.5, "pos": Vector3(2.6, 0.45, 3.4), "look": Vector3(5.5, 1.2, 0.8), "flashlight": true},
]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--screenshot-tour="):
			out_dir = arg.get_slice("=", 1)
		elif arg.begins_with("--shots="):
			only = arg.get_slice("=", 1).split(",")
		elif arg.begins_with("--frames="):
			frames = int(arg.get_slice("=", 1))
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()


func _run() -> void:
	for i in 20:
		await get_tree().process_frame
	var player := get_tree().get_first_node_in_group("player") as Player
	TimeManager.running = false
	ThreatDirector.set_process(false)  # keine zufälligen Ereignisse während der Fotos
	for shot: Dictionary in SHOTS:
		if not only.is_empty() and not String(shot["name"]).left(2) in only:
			continue
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
		player.set_flashlight(shot.get("flashlight", false))
		for sw in get_tree().get_nodes_in_group("light_switch"):
			sw.switch_to(shot.get("lights", false))
		var creature: Creature = null
		if shot.has("creature_at"):
			creature = Creature.new()
			get_tree().current_scene.add_child(creature)
			creature.global_position = Creature._ground(shot["creature_at"])
			creature.set_physics_process(false)
			var face: Vector3 = shot.get("creature_face", pos)
			face.y = creature.global_position.y
			creature.look_at(face, Vector3.UP)
			creature.rotate_y(PI)
		var built: Array[Structure] = []
		for b in shot.get("build", []):
			built.append(Builder.place(b[0], Creature._ground(b[1]), b[2]))
		if shot.has("menu"):
			for id: String in ["wood", "scrap", "nails", "planks", "battery", "electronics"]:
				Inventory.add(id, 4)
			get_tree().call_group("game_menus", "open_crafting")
		if shot.get("break_window", false):
			var w := get_tree().current_scene.get_node("Cabin/WindowLiving") as CabinWindow
			w.receive_hit(999.0)
		if shot.get("monitor", false):
			get_tree().call_group("hud", "open_monitor")
			if shot.has("monitor_cam"):
				get_tree().call_group("surveillance", "set_active", shot["monitor_cam"])
		for f in frames:
			await get_tree().process_frame
		if shot.get("monitor", false):
			(get_tree().get_first_node_in_group("hud") as Hud).close_monitor.call_deferred()
		var img := get_viewport().get_texture().get_image()
		var path := out_dir.path_join(String(shot["name"]) + ".png")
		img.save_png(path)
		print("Screenshot: ", path)
		if creature:
			creature.queue_free()
		for b in built:
			if is_instance_valid(b):
				Builder.remove(b.uid)
				b.queue_free()
		if shot.has("menu"):
			get_tree().call_group("game_menus", "close")
	get_tree().quit()
