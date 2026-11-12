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
	{"name": "31_struktur", "hour": 15.5, "day": 7, "pos": Vector3(-64.0, 0.0, 30.0), "look": Vector3(-78.0, 3.5, 40.0)},
	{"name": "32_hochsitz", "hour": 15.0, "pos": Vector3(3.0, 0.0, -70.0), "look": Vector3(12.0, 3.0, -80.0)},
	{"name": "33_hoehle_eingang", "hour": 15.0, "day": 7, "pos": Vector3(40.5, 0.0, -77.5), "look": Vector3(46.0, 0.5, -72.0)},
	{"name": "34_hoehle_knoten", "hour": 15.0, "cave": true, "pos": Vector3(55.0, 0.0, -72.0), "look": Vector3(61.5, 0.7, -72.0), "flashlight": true},
	{"name": "35_drohne_nacht", "hour": 23.0, "pos": Vector3(-3.0, 0.0, 26.0), "look": Vector3(-2.0, 7.0, 15.0), "drone_at": Vector3(-2.0, 9.0, 15.0)},
	{"name": "36_generator", "hour": 21.0, "pos": Vector3(4.2, 0.45, -1.8), "look": Vector3(2.5, 0.45, -2.6), "lights": true},
	{"name": "37_werkzeugwand", "hour": 21.0, "pos": Vector3(2.8, 0.45, 2.7), "look": Vector3(2.8, 1.5, 4.4), "lights": true},
	{"name": "38_gartenbank", "hour": 14.0, "pos": Vector3(-0.4, 0.0, 8.6), "look": Vector3(-0.45, 0.8, 5.0)},
	{"name": "39_schaukelstuhl", "hour": 21.0, "pos": Vector3(-2.3, 0.45, 1.6), "look": Vector3(-4.3, 0.7, 3.45), "lights": true},
	{"name": "40_blick_ins_hirn", "hour": 22.5, "pos": Vector3(-3.0, 0.45, 5.6), "look": Vector3(-3.5, 1.6, 15.0), "flashlight": true, "creature_at": Vector3(-3.5, 0, 14.0), "lights": true, "mind": 0.8},
	{"name": "41_veraenderungen", "hour": 9.0, "pos": Vector3(-2.0, 0.45, 6.2), "look": Vector3(-6.0, 0.6, 13.0), "changes": true},
	{"name": "42_tablet", "hour": 21.5, "pos": Vector3(-3.0, 0.45, 0.4), "look": Vector3(-5.0, 0.8, 1.75), "lights": true, "couch": true},
	{"name": "43_mondnacht", "hour": 4.0, "pos": Vector3(-3.0, 0.0, 12.0), "look": Vector3(-3.0, 1.0, 30.0)},
	{"name": "44_erste_nachthaelfte", "hour": 23.0, "pos": Vector3(-3.0, 0.0, 12.0), "look": Vector3(-3.0, 1.0, 30.0)},
	{"name": "45_truhe", "hour": 21.0, "pos": Vector3(2.9, 0.45, 2.3), "look": Vector3(2.78, 0.6, 4.2), "lights": true},
	{"name": "46_truhe_menue", "hour": 21.0, "pos": Vector3(2.9, 0.45, 2.3), "look": Vector3(2.78, 0.6, 4.2), "lights": true, "chest_menu": true},
	{"name": "47_blechschere_hand", "hour": 14.0, "pos": Vector3(3.0, 0.45, 0.5), "look": Vector3(3.0, 1.0, -3.0), "lights": true, "equip": "tin_snips"},
	{"name": "48_bad", "hour": 14.0, "pos": Vector3(5.4, 0.45, -1.4), "look": Vector3(2.4, 0.9, -4.2), "lights": true},
	{"name": "49_kreatur_vierbeinig", "hour": 13.0, "pos": Vector3(5.2, 0.0, 10.4), "look": Vector3(3.0, 0.8, 11.8), "creature_at": Vector3(3.0, 0, 11.8), "creature_face": Vector3(-3.0, 0, 12.5), "crawl": true},
	{"name": "50_kamera_lauert", "hour": 23.0, "pos": Vector3(0.9, 0.45, 3.6), "look": Vector3(1.4, 1.4, 3.6), "monitor": true, "monitor_cam": 0, "lurk": true, "lurk_spot": 1},
	{"name": "51_funkecke_werkstatt", "hour": 14.0, "pos": Vector3(3.6, 0.45, 1.6), "look": Vector3(2.6, 1.1, -0.9), "lights": true},
	{"name": "52_bad_dusche", "hour": 14.0, "pos": Vector3(4.6, 0.45, -1.6), "look": Vector3(2.4, 1.0, -4.0), "lights": true},
	{"name": "53_pickup_heck", "hour": 14.0, "pos": Vector3(1.0, 0.0, 37.0), "look": Vector3(3.0, 0.6, 34.4)},
	{"name": "54_picknick", "hour": 14.0, "pos": Vector3(-8.6, 0.0, -0.6), "look": Vector3(-11.0, 0.4, -3.0)},
	{"name": "55_hochsitz", "hour": 13.0, "pos": Vector3(18.29, 0.0, -73.92), "look": Vector3(12.0, 3.5, -80.0)},
	{"name": "57_hochsitz_oben", "hour": 13.0, "pos": Vector3(12.26, 4.3, -79.03), "look": Vector3(11.64, 4.8, -81.35), "tower": true},
	{"name": "56_tankanzeige", "hour": 14.0, "pos": Vector3(3.3, 0.45, 0.9), "look": Vector3(2.8, 1.95, -0.92), "lights": true},
	{"name": "58_tablet_archiv", "hour": 14.0, "pos": Vector3(-2.0, 0.45, 2.0), "look": Vector3(-2.0, 1.0, 0.0), "lights": true, "tablet_tab": "archive"},
	{"name": "60_weite_welt", "hour": 12.0, "place": "funkmast", "off": Vector3(4.0, 0.0, 6.0), "look_off": Vector3(300.0, -40.0, 200.0)},
	{"name": "61_waldweg", "hour": 11.0, "place": "messstelle", "off": Vector3(-8.0, 0.0, 230.0), "look_off": Vector3(-6.0, 1.0, 180.0)},
	{"name": "62_see", "hour": 14.0, "place": "see", "off": Vector3(-7.0, 0.0, -4.0), "look_off": Vector3(0.0, -2.0, 60.0)},
	{"name": "63_kapelle", "hour": 15.0, "place": "kapelle", "off": Vector3(9.0, 0.0, 12.0), "look_off": Vector3(0.0, 1.0, 0.0)},
	{"name": "64_funkmast", "hour": 13.0, "place": "funkmast", "off": Vector3(-14.0, 0.0, 12.0), "look_off": Vector3(0.0, 8.0, 0.0)},
	{"name": "65_aussenstelle", "hour": 14.0, "place": "aussenstelle", "off": Vector3(4.0, 0.0, 40.0), "look_off": Vector3(-4.0, 2.0, 0.0)},
	{"name": "66_wal", "hour": 16.0, "place": "wal", "off": Vector3(48.0, 0.0, 22.0), "look_off": Vector3(0.0, 4.0, 0.0)},
	{"name": "67_dorf", "hour": 15.0, "place": "dorf", "off": Vector3(20.0, 0.0, 32.0), "look_off": Vector3(0.0, 6.0, -6.0)},
	{"name": "68_ferienlager", "hour": 11.0, "place": "ferienlager", "off": Vector3(6.0, 0.0, 22.0), "look_off": Vector3(0.0, 1.5, -4.0)},
	{"name": "69_imkerei", "hour": 12.0, "place": "imkerei", "off": Vector3(10.0, 0.0, 14.0), "look_off": Vector3(-2.0, 0.5, 0.0)},
	{"name": "70_sucher_am_lager", "hour": 21.2, "pos": Vector3(5.0, 0.0, 9.0), "look": Vector3(9.0, 1.9, 14.5),
		"build": [["tent", Vector3(10.5, 0.0, 11.0), -0.9], ["campfire", Vector3(7.5, 0.0, 12.0), 0.0]], "seeker_at": Vector3(9.3, 0.0, 15.0)},
	{"name": "73_zerfleischer_tag", "hour": 15.5, "pos": Vector3(4.0, 0.0, 16.5), "look": Vector3(4.0, 1.3, 11.5), "mauler_at": Vector3(4.0, 0.0, 12.0), "mauler_pose": "warn", "clean": true},
	{"name": "74_zerfleischer_seite", "hour": 15.5, "pos": Vector3(9.0, 0.0, 12.5), "look": Vector3(4.0, 1.1, 12.0), "mauler_at": Vector3(4.0, 0.0, 12.0), "mauler_face": Vector3(4.0, 0.0, 17.0), "mauler_pose": "charge", "clean": true},
	{"name": "00_titelbild", "hour": 2.5, "pos": Vector3(-12.5, 0.0, 19.0), "look": Vector3(0.5, 2.6, 0.0), "lights": true, "clean": true},
	{"name": "71_labor_im_bad", "hour": 21.0, "pos": Vector3(2.75, 0.45, -1.5), "look": Vector3(5.8, 1.2, -3.0), "lights": true, "lab": true},
	{"name": "72_forschungsbaum", "hour": 14.0, "pos": Vector3(-3.0, 0.45, 2.0), "look": Vector3(-3.0, 1.0, 0.0), "lab": true, "tablet": "tree"},
	{"name": "80_anbau_nordwest", "hour": 15.0, "pos": Vector3(-15.0, 0.0, -14.0), "look": Vector3(-3.0, 1.8, -3.0)},
	{"name": "81_anbau_nord", "hour": 15.0, "pos": Vector3(6.0, 0.0, -16.0), "look": Vector3(-1.0, 1.8, -5.0)},
	{"name": "82_buero", "hour": 14.0, "pos": Vector3(0.5, 0.45, -4.3), "look": Vector3(0.5, 1.0, -8.0), "lights": true},
	{"name": "83_kinderzimmer", "hour": 14.0, "pos": Vector3(-6.4, 0.45, 0.2), "look": Vector3(-8.8, 0.9, -3.0), "lights": true},
	{"name": "84_werkstatt_leiter", "hour": 14.0, "pos": Vector3(3.2, 0.45, 3.8), "look": Vector3(4.15, 2.2, 0.6), "lights": true, "attic_down": true},
	{"name": "85_dachboden", "hour": 14.0, "pos": Vector3(3.3, 3.36, 0.1), "look": Vector3(-5.5, 3.9, 0.0), "lights": true, "attic_down": true},
	{"name": "86_keller", "hour": 14.0, "pos": Vector3(0.2, -2.1, -2.6), "look": Vector3(1.6, -1.3, -3.6), "lights": true, "cellar_open": true},
	{"name": "87_speis", "hour": 14.0, "pos": Vector3(1.3, 0.45, -1.3), "look": Vector3(0.3, 1.1, -6.0), "lights": true, "cellar_open": true},
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
	get_tree().call_group("surveillance", "install_defaults")
	for shot: Dictionary in SHOTS:
		if not only.is_empty() and not (String(shot["name"]).left(2) in only):
			continue
		TimeManager.set_time(int(shot.get("day", 1)), shot["hour"])
		WorldState._check_stage()
		var pos: Vector3 = shot.get("pos", Vector3.ZERO)
		var look: Vector3 = shot.get("look", Vector3.ZERO)
		if shot.get("tower", false):
			var th := Terrain.height_at(RangerTower.SITE.x, RangerTower.SITE.z)
			pos.y += th
			look.y += th
		elif shot.get("cave", false):
			var fh := StreamCave.floor_height()
			pos.y = fh + 0.05
			look.y += fh
		elif shot.has("place"):
			var base := WorldMap.place_point(shot["place"])
			pos = base + shot.get("off", Vector3.ZERO)
			pos.y = Terrain.height_at(pos.x, pos.z)
			look = base + shot.get("look_off", Vector3(0, 1, -10))
			look.y = base.y + float(shot.get("look_off", Vector3(0, 1, -10)).y) + 1.6
		elif pos.y <= 0.0:
			pos.y = Terrain.height_at(pos.x, pos.z)
		# große Welt: Gelände und Wald um den Standpunkt sofort laden
		var terrain := get_tree().current_scene.get_node_or_null("Terrain") as Terrain
		if terrain:
			terrain.load_around(pos, 200.0)
		var wild := get_tree().current_scene.get_node_or_null("WildForest") as WildForest
		if wild:
			wild.update_around(pos, 0.0)
		player.global_position = pos
		player.velocity = Vector3.ZERO
		var eye := pos + Vector3(0, Player.STAND_HEIGHT - Player.EYE_OFFSET, 0)
		var d := (look - eye).normalized()
		player.rotation.y = atan2(-d.x, -d.z)
		player.head.rotation.x = asin(clampf(d.y, -1.0, 1.0))
		player.set_flashlight(shot.get("flashlight", false))
		if shot.has("equip"):
			Inventory.add(shot["equip"], 1)
			Inventory.select(Inventory.slot_of(shot["equip"]))
		if shot.get("lights", false):
			PowerManager.add_fuel(30.0)
			PowerManager.start_generator()   # Generator läuft seit 11/2026 beim Start nicht mehr
		for sw in get_tree().get_nodes_in_group("light_switch"):
			sw.switch_to(shot.get("lights", false))
		if shot.get("attic_down", false):
			var ah := get_tree().get_first_node_in_group("attic_hatch") as AtticHatch
			if ah:
				ah.down = true
				ah._apply(false)
		if shot.get("cellar_open", false):
			var ch := get_tree().get_first_node_in_group("cellar_hatch") as CellarHatch
			if ch:
				ch.rug_moved = true
				ch.open = true
				ch._apply(false)
		if shot.get("lab", false):
			# Forschung 2.0: Labor voll ausgebaut, einiges erforscht, Probe im Terrarium
			PowerManager.add_fuel(100.0)
			PowerManager.start_generator()
			Research.tier = 1
			Research.lab_offered = true
			Research.lab_built = true
			Research.lab_stations = ["bench", "microscope", "terrarium", "shield", "screen"]
			Research.charger_built = true
			for id: String in ["an_metal", "an_cell", "an_tissue", "an_fungus", "an_glyph", "an_organism", "an_tissue_nerves", "an_claw", "an_shed", "an_saliva", "an_lens", "an_drone"]:
				if not Research.done.has(id):
					Research.done.append(id)
			for f: String in ["metal_fragment", "energy_cell", "alien_tissue", "glow_fungus", "glyph_plate", "organism_sample", "creature_shed", "drone_lens", "rz_drive"]:
				if not Research.seen.has(f):
					Research.seen.append(f)
			Research.sent = Research.unsent_results()
			Research.link("link_growing")
			Research.stations = {"device": "", "bench": "", "microscope": "an_metal_struct", "terrarium": "an_fungus_culture", "shield": "an_cell_drain", "screen": "an_rz_drive"}
			Research.progress["an_fungus_culture"] = 9.0
			Research.progress["an_rz_drive"] = 26.0
			Research.changed.emit()
		if shot.has("tablet"):
			var couch := get_tree().current_scene.get_node_or_null("Cabin/Couch")
			var tm := get_tree().get_first_node_in_group("tablet_menu")
			if couch and tm:
				tm.call("open", couch)
				tm.call("_set_tab", String(shot["tablet"]))
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
			if shot.get("crawl", false):
				creature._crawl_blend = 1.0
				creature._walk_phase = 1.0
				for k in 60:
					creature._animate(0.05, true)
		var seeker: Seeker = null
		if shot.has("seeker_at"):
			seeker = Seeker.new()
			seeker.target = pos
			get_tree().current_scene.add_child(seeker)
			seeker.global_position = Creature._ground(shot["seeker_at"])
			seeker.set_process(false)
			var sf := pos - seeker.global_position
			seeker.rotation.y = atan2(sf.x, sf.z)
			seeker._eye_mat.emission_energy_multiplier = 3.0
		for old in get_tree().get_nodes_in_group("mauler"):
			old.queue_free()
		if shot.has("mauler_at"):
			var ml := Mauler.new()
			get_tree().current_scene.add_child(ml)
			ml.global_position = Creature._ground(shot["mauler_at"])
			ml.set_process(false)
			var mf: Vector3 = shot.get("mauler_face", pos) - ml.global_position
			ml.rotation.y = atan2(mf.x, mf.z)
			ml.state = Mauler.State.WARN if shot.get("mauler_pose", "") == "warn" else Mauler.State.CHARGE
			ml._speed_now = 0.0 if ml.state == Mauler.State.WARN else ml.cfg.charge_speed
			for k in 30:
				ml._animate(0.1)
		var drone: AlienDrone = null
		if shot.has("drone_at"):
			drone = AlienDrone.new()
			get_tree().current_scene.add_child(drone)
			drone.global_position = shot["drone_at"]
			drone.set_physics_process(false)
		if shot.get("changes", false):
			var nc := get_tree().current_scene.get_node("NightChanges") as NightChanges
			for c: Dictionary in [{"kind": "bench_moved", "until": 99, "x": -6.0, "z": 13.0, "yaw": 2.6},
					{"kind": "cairn", "until": 99, "x": -9.0, "z": 9.5, "n": 9, "seed": 7},
					{"kind": "log_circle", "until": 99, "x": -2.0, "z": 12.5},
					{"kind": "shoes", "until": 99}, {"kind": "stone_line", "until": 99, "x": -12.0, "z": 15.0}]:
				nc.active.append(c)
				nc._apply(c)
		var built: Array[Structure] = []
		for b in shot.get("build", []):
			built.append(Builder.place(b[0], Creature._ground(b[1]), b[2]))
		if shot.has("menu"):
			for id: String in ["wood", "scrap", "nails", "planks", "battery", "electronics"]:
				Inventory.add(id, 4)
			get_tree().call_group("game_menus", "open_crafting")
		if shot.has("tablet_tab"):
			# Beispiel-Forschungsstand: drei Analysen fertig und gesendet, zwei Funde offen
			for an: String in ["an_tissue", "an_crystal", "an_fungus"]:
				Research.done.append(an)
				Research.seen.append(String(Research.analysis(an)["find"]))
			for f: String in ["alien_blood", "metal_fragment"]:
				Research.seen.append(f)
			Research.sent = Research.unsent_results()
			var couch := get_tree().current_scene.get_node("Cabin/Couch") as Couch
			get_tree().call_group("tablet_menu", "open", couch)
			(get_tree().get_first_node_in_group("tablet_menu") as TabletMenu)._set_tab(shot["tablet_tab"])
		if shot.get("break_window", false):
			var w := get_tree().current_scene.get_node("Cabin/WindowLiving") as CabinWindow
			w.receive_hit(999.0)
		if shot.get("monitor", false):
			get_tree().call_group("hud", "open_monitor")
			if shot.has("monitor_cam"):
				get_tree().call_group("surveillance", "set_active", shot["monitor_cam"])
			if shot.get("lurk", false):
				get_tree().call_group("surveillance", "spawn_lurker", int(shot.get("lurk_spot", -1)))
		get_tree().call_group("retro_filter", "set_mind", float(shot.get("mind", 0.0)))
		if shot.get("clean", false):
			# Titelbild: ohne Anzeigen und Hände, Kamin brennt
			for h in get_tree().get_nodes_in_group("hud"):
				(h as CanvasLayer).visible = false
			for ph in get_tree().current_scene.find_children("*", "PlayerHands", true, false):
				(ph as Node3D).visible = false
			for fp in get_tree().get_nodes_in_group("heat_source"):
				if fp is Fireplace:
					(fp as Fireplace).burn_until = TimeManager.get_total_hours() + 12.0
		if shot.get("chest_menu", false):
			var ch := get_tree().current_scene.get_node("Cabin/StorageChest") as StorageChest
			for it in [["wood", 8], ["food", 3], ["water", 2], ["axe", 1], ["metal_fragment", 1]]:
				Inventory.add(it[0], it[1])
			ch.items = {"planks": 12, "nails": 40, "battery": 1, "glow_fungus": 2}
			ch.interact(null)
		if shot.get("couch", false):
			var couch := get_tree().current_scene.get_node("Cabin/Couch") as Couch
			couch.interact(get_tree().get_first_node_in_group("player"))
		for f in frames:
			await get_tree().process_frame
		if shot.get("lurk", false):
			var sv := get_tree().get_first_node_in_group("surveillance") as Surveillance
			print("Lauernde Gestalt: ", sv._lurker, " bei ", sv._lurker.global_position if sv._lurker else Vector3.ZERO)
			sv.viewport.get_texture().get_image().save_png(out_dir.path_join(String(shot["name"]) + "_kamera.png"))
		if shot.get("monitor", false):
			(get_tree().get_first_node_in_group("hud") as Hud).close_monitor.call_deferred()
		var img := get_viewport().get_texture().get_image()
		var path := out_dir.path_join(String(shot["name"]) + ".png")
		img.save_png(path)
		print("Screenshot: ", path)
		if creature:
			creature.queue_free()
		if drone:
			drone.queue_free()
		if seeker:
			seeker.queue_free()
		for b in built:
			if is_instance_valid(b):
				Builder.remove(b.uid)
				b.queue_free()
		if shot.has("menu"):
			get_tree().call_group("game_menus", "close")
	get_tree().quit()
