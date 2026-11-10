class_name RegressTest
extends Node
## Entwickler-Test: je behobenem Fehler eine eigene Prüfung, damit er nicht zurückkommt.
## Start: godot --headless --path . -- --night-test=regress
##
## Der Test hängt am Wurzelknoten (übersteht das Neuladen der Szene).

static var instance: RegressTest = null

var failed: int = 0
var checks: int = 0


static func start(tree: SceneTree) -> void:
	if instance != null:
		return
	instance = RegressTest.new()
	instance.name = "RegressTest"
	instance.process_mode = Node.PROCESS_MODE_ALWAYS
	tree.root.add_child.call_deferred(instance)


func _ready() -> void:
	_run.call_deferred()


func _ok(name: String, cond: bool, detail: String = "") -> void:
	checks += 1
	if cond:
		print("OK      %s" % name)
	else:
		failed += 1
		print("FEHLER  %s  %s" % [name, detail])


func _scene() -> Node:
	return get_tree().current_scene


func _player() -> Player:
	return get_tree().get_first_node_in_group("player") as Player


func _frames(n: int = 3) -> void:
	for i in n:
		await get_tree().physics_frame


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _wait_scene() -> void:
	for i in 600:
		await get_tree().process_frame
		if _scene() != null and _player() != null and _player().is_inside_tree():
			break
	await _frames(12)


func _reload() -> void:
	GameState.take_snapshot()
	GameState.restart_day()
	await _wait_scene()


func _action(name: String) -> InputEventAction:
	var ev := InputEventAction.new()
	ev.action = name
	ev.pressed = true
	return ev


func _run() -> void:
	await _wait_scene()
	ThreatDirector.set_process(false)
	await _t_persist_names()
	await _t_chapel_stones()
	await _t_cameras()
	await _t_phantom_steps()
	_t_camp_replan()
	_t_bottle()
	await _t_snare()
	_t_takeout_full()
	await _t_dead_locked()
	await _t_tent_light()
	_t_survival_reset()
	await _t_map_guard()
	await _t_pause_mouse()
	await _t_seat_double()
	await _t_build_through_menu()
	_t_discard()
	_t_plant_unknown()
	await _t_more()
	print("REGRESS TEST: %d Prüfungen, %d Fehler" % [checks, failed])
	get_tree().quit(1 if failed > 0 else 0)


## Funde an Kontrollpunkt und Wrack hatten Eltern ohne festen Namen: nach jedem Laden lagen sie wieder da.
func _t_persist_names() -> void:
	var bad: PackedStringArray = []
	for n in get_tree().get_nodes_in_group("persistent"):
		var k := String(n.call("persist_key"))
		if k.contains("@"):
			bad.append(k)
	_ok("Spielstand: alle Objekte haben feste Namen", bad.is_empty(), ", ".join(bad))
	var ration := _scene().get_node_or_null("Places/kontrollpunkt/Tent1/Rations") as ItemPickup
	var cells := _scene().get_node_or_null("Places/wal/Hull/Inner/Cells") as ItemPickup
	_ok("Kontrollpunkt/Wrack: Funde unter festem Namen", ration != null and cells != null)
	if ration == null or cells == null:
		return
	while ration.amount > 0:
		ration.interact(_player())
	while cells.amount > 0:
		cells.interact(_player())
	var had := Inventory.count("ration")
	await _reload()
	ration = _scene().get_node_or_null("Places/kontrollpunkt/Tent1/Rations") as ItemPickup
	cells = _scene().get_node_or_null("Places/wal/Hull/Inner/Cells") as ItemPickup
	_ok("Eingesammelte Funde bleiben nach dem Laden weg", ration != null and ration.amount == 0 and cells != null and cells.amount == 0 and Inventory.count("ration") == had)


## Die Steine in der Kapelle hingen an der Uhr und wurden nach einem Neustart weiter aufgerufen (Skriptfehler).
func _t_chapel_stones() -> void:
	var before := TimeManager.day_changed.get_connections().size()
	await _reload()
	await _reload()
	var after := TimeManager.day_changed.get_connections().size()
	_ok("Uhr: nach dem Neuladen keine alten Verbindungen übrig", after == before, "%d -> %d" % [before, after])
	TimeManager.day_changed.emit(TimeManager.day)  # darf keinen Skriptfehler auslösen
	var stones := _scene().get_node_or_null("Places/kapelle").find_child("Stones", true, false)
	_ok("Kapelle: Steine liegen auf den Bänken", stones != null and stones.get_child_count() > 0)


## Drei Kameras im selben Augenblick angebracht: es blieben doppelte Kameras in der Welt stehen.
func _t_cameras() -> void:
	var sv := get_tree().get_first_node_in_group("surveillance") as Surveillance
	sv.install_defaults()
	await _frames(4)
	var n := 0
	for c in get_tree().get_nodes_in_group("security_camera"):
		if not c.is_queued_for_deletion():
			n += 1
	_ok("Kameras: genau drei in der Welt", n == 3, "gefunden %d" % n)
	for i in 3:
		Supplies.uninstall_camera(i)
	await _frames(3)


## Schritte im Wald liefen weiter, während die Szene neu geladen wurde (Zugriff auf gelöschte Welt).
func _t_phantom_steps() -> void:
	ThreatDirector._play_phantom_steps(_scene())
	await _wait(0.3)
	await _reload()
	await _wait(1.5)
	_ok("Geisterschritte überstehen das Neuladen", true)


## Nach einem Tod in der Zeltnacht wurden in derselben Nacht keine Zelt-Ereignisse mehr geplant.
func _t_camp_replan() -> void:
	ThreatDirector._camp_planned_night = ThreatDirector.current_night()
	ThreatDirector._activity_tonight = true
	ThreatDirector._kinds_tonight.append("drone")
	ThreatDirector.reset_for_new_scene()
	_ok("Bedrohung: Neustart vergisst die abgebrochene Nacht", ThreatDirector._camp_planned_night == -1 and not ThreatDirector._activity_tonight and ThreatDirector._kinds_tonight.is_empty())


## Flasche füllen, obwohl schon vier volle im Rucksack sind: die leere Flasche verschwand.
func _t_bottle() -> void:
	var tap := _scene().get_node_or_null("Cabin/KitchenTap") as WaterSource
	Inventory.items.erase("water")
	Inventory.items.erase("bottle_empty")
	Inventory.add("water", int(DataDB.item("water").get("stack", 4)))
	Inventory.add("bottle_empty", 1)
	tap.secondary_interact(_player())
	_ok("Wasserhahn: leere Flasche bleibt, wenn kein Platz ist", Inventory.count("bottle_empty") == 1)
	Inventory.remove("water", 1)
	tap.secondary_interact(_player())
	_ok("Wasserhahn: Flasche wird gefüllt, wenn Platz ist", Inventory.count("bottle_empty") == 0 and Inventory.count("water") == int(DataDB.item("water").get("stack", 4)))


## Schlinge leeren mit vollem Fleisch-Stapel: der Fang verschwand.
func _t_snare() -> void:
	var s := Builder.place("snare", Vector3(-30, Terrain.height_at(-30, 26), 26), 0.0)
	await _frames(2)
	Builder.record(s.uid)["caught"] = true
	Inventory.items.erase("meat_raw")
	Inventory.add("meat_raw", int(DataDB.item("meat_raw").get("stack", 6)))
	s.interact(_player())
	_ok("Schlinge: Fang bleibt, wenn kein Platz ist", bool(Builder.record(s.uid).get("caught", false)))
	Inventory.remove("meat_raw", 3)
	s.interact(_player())
	_ok("Schlinge: Fang wird genommen, wenn Platz ist", not bool(Builder.record(s.uid).get("caught", false)) and Inventory.count("meat_raw") > 3)
	Builder.remove(s.uid)
	s.queue_free()
	await _frames(2)


## Fund aus dem Gerät nehmen, obwohl der Stapel voll ist: bleibt im Gerät (und die Meldung nennt den Grund).
func _t_takeout_full() -> void:
	var old_tier := Research.tier
	Research.tier = 1
	Research.w17_in_device = true
	Inventory.items.erase("metal_fragment")
	Inventory.add("metal_fragment", 1)
	Research.stations["device"] = ""
	Research.done.erase("an_metal")
	var inserted := Research.insert_project("device", "an_metal")
	Inventory.add("metal_fragment", int(DataDB.item("metal_fragment").get("stack", 6)))
	Research.take_out("device")
	_ok("Analysegerät: Fund bleibt drin, wenn kein Platz ist", inserted and String(Research.stations["device"]) == "an_metal")
	Inventory.remove("metal_fragment", 2)
	Research.take_out("device")
	_ok("Analysegerät: Fund kommt heraus, wenn Platz ist", String(Research.stations["device"]) == "")
	Research.tier = old_tier


## Wer tot ist, darf nichts mehr anfassen – auch wenn sich gerade ein Menü schließt.
func _t_dead_locked() -> void:
	var p := _player()
	var menus := _scene().get_node("GameMenus") as GameMenus
	menus.open_inventory()
	GameState.dead = true
	menus.close()
	var locked_dead := p.input_locked
	GameState.dead = false
	_ok("Tod: Steuerung bleibt gesperrt, auch wenn ein Menü schließt", locked_dead and not p.input_locked)
	await _frames(1)


## „Licht von oben“ in der Zeltnacht blieb am Himmel hängen, wenn das Zelt währenddessen verschwand.
func _t_tent_light() -> void:
	var base := Vector3(-34, Terrain.height_at(-34, 30), 30)
	var tent := Builder.place("tent", base, 0.0)
	await _frames(2)
	tent.camp._light_from_above()
	await _frames(2)
	Builder.remove(tent.uid)
	tent.queue_free()
	await _frames(3)
	var left := 0
	for n in _scene().get_children():
		if n is SpotLight3D:
			left += 1
	_ok("Zelt: Licht von oben verschwindet mit dem Zelt", left == 0, "übrig %d" % left)


## Nasse Kleidung und Warnungen des abgebrochenen Tages galten nach dem Neustart weiter.
func _t_survival_reset() -> void:
	Survival.set_wet()
	Survival.set_state(Survival.get_state())
	_ok("Überleben: Neustart macht trocken", Survival.wet_until < 0.0)


## Karte (M) ließ sich über einem offenen Inventar öffnen; Schließen gab dann die Steuerung frei.
func _t_map_guard() -> void:
	var p := _player()
	var menus := _scene().get_node("GameMenus") as GameMenus
	var map := _scene().get_node("MapScreen") as MapScreen
	Inventory.add("hiking_map", 1)
	menus.open_inventory()
	map._unhandled_input(_action("map"))
	_ok("Karte: öffnet nicht über dem Inventar", not map.is_open() and p.input_locked)
	menus.close()
	map._unhandled_input(_action("map"))
	_ok("Karte: öffnet, wenn der Spieler frei ist", map.is_open())
	# Esc schließt zuerst die Karte, statt zu pausieren
	var pause := _scene().get_node("PauseMenu") as PauseMenu
	pause._unhandled_input(_action("pause_menu"))
	_ok("Karte: Esc schließt die Karte, keine Pause", not map.is_open() and not get_tree().paused and not p.input_locked)
	await _frames(1)


## Nach der Pause wurde die Maus eingefangen, obwohl noch ein Menü mit Mauszeiger offen war.
func _t_pause_mouse() -> void:
	var menus := _scene().get_node("GameMenus") as GameMenus
	var pause := _scene().get_node("PauseMenu") as PauseMenu
	menus.open_inventory()
	_ok("Pause: erkennt offenes Menü mit Mauszeiger", pause._menu_needs_mouse())
	menus.close()
	_ok("Pause: ohne Menü wird die Maus eingefangen", not pause._menu_needs_mouse())
	await _frames(1)


## E zweimal schnell an der Bank: Hinsetzen und Aufstehen zogen gleichzeitig am Spieler.
func _t_seat_double() -> void:
	var p := _player()
	var back := Vector3(-2.0, Cabin.FLOOR_Y + 0.05, 1.0)
	p.global_position = back
	await _frames(2)
	Seat.sit_down(self, p, back + Vector3(1.5, 0, 0), Vector3(0, 0, 1), 1.1, true)
	await _wait(0.2)
	Seat.stand_up(self, p, back)
	await _wait(1.2)
	_ok("Sitzen: sofortiges Aufstehen endet am Ausgangspunkt", p.global_position.distance_to(back) < 0.25 and not p.look_only and not p.input_locked,
		"Abstand %.2f, look_only %s" % [p.global_position.distance_to(back), p.look_only])


## Im Baumodus ließ sich durch ein offenes Menü hindurch bauen.
func _t_build_through_menu() -> void:
	var bc := _scene().get_node("BuildController") as BuildController
	var menus := _scene().get_node("GameMenus") as GameMenus
	Inventory.add("fence_panel", 1)
	bc.start("fence_panel")
	await _frames(3)
	var before := Builder.records.size()
	menus.open_inventory()
	bc._unhandled_input(_action("interact"))
	_ok("Bauen: nicht durch ein offenes Menü", Builder.records.size() == before)
	menus.close()
	bc.stop()
	Inventory.remove("fence_panel", Inventory.count("fence_panel"))
	await _frames(2)


## „Ablegen“ warf auch Einzelstücke wie W-17 unwiederbringlich weg.
func _t_discard() -> void:
	var menus := _scene().get_node("GameMenus") as GameMenus
	Inventory.items.erase("w17")
	Inventory.add("w17", 1)
	Inventory.add("wood", 2)
	menus._on_drop("w17")
	menus._on_drop("wood")
	_ok("Ablegen: W-17 bleibt, Holz geht", Inventory.count("w17") == 1 and Inventory.count("wood") == 0)
	_ok("Ablegen: Werkzeuge, Kameras und Schlüssel sind geschützt", not GameMenus.can_discard("axe") and not GameMenus.can_discard("camera_1")
		and not GameMenus.can_discard("quarry_key") and GameMenus.can_discard("food") and GameMenus.can_discard("metal_fragment"))
	Inventory.remove("w17", 1)


## Saatgut ohne passende Pflanze (Fremde Samen) darf kein kaputtes Beet hinterlassen.
func _t_plant_unknown() -> void:
	Inventory.add("alien_seeds", 1)
	Supplies.beds[0] = Supplies._empty_bed()
	var planted := Supplies.plant(0, "alien_seeds")
	_ok("Hochbeet: unbekannte Pflanze wird nicht gesät", not planted and Supplies.bed_state(0) == "empty" and Inventory.count("alien_seeds") >= 1)
	Inventory.remove("alien_seeds", Inventory.count("alien_seeds"))
	_ok("Rucksack: kein Eintrag ohne Namen", not Inventory.items.has(""))


## Weitere Prüfungen (später gefundene Fehler).
func _t_more() -> void:
	await _frames(1)
	await _t_seat_first_time()
	_t_window_face()
	await _t_forest_steps()
	await _t_terrain_steps()
	_t_tasks_saved()


## Beim allerersten Hinsetzen nach dem Laden gab es eine Fehlermeldung (kein vorheriges Hinsetzen gemerkt).
func _t_seat_first_time() -> void:
	var p := _player()
	if p.has_meta("seat_tween"):
		p.remove_meta("seat_tween")
	Seat._stop_move(p)
	_ok("Sitzen: erstes Hinsetzen ohne Vorgeschichte", not p.has_meta("seat_tween"))
	await _frames(1)


## Das Gesicht am Fenster erschien an einem Fenster hinter einer Zwischenwand (z. B. Werkstatt statt Wohnzimmer).
func _t_window_face() -> void:
	var scene := _scene()
	var windows: Array = []
	for w in get_tree().get_nodes_in_group("entry_point"):
		if w is CabinWindow:
			windows.append(w)
	var with_view := 0
	var wrong := 0
	for ix in range(-5, 6):
		for iz in range(-4, 5):
			var p := Vector3(ix, Cabin.FLOOR_Y + 0.05, iz)
			var can_see := false
			for w: Node3D in windows:
				var inner := w.call("inside_point") as Vector3
				var d := inner.distance_to(p)
				if d > 1.6 and d < 7.0 and Apparition._clear_view(scene, p, inner):
					can_see = true
			if not can_see:
				continue
			with_view += 1
			var pick := Apparition._window_near(scene, p)
			if pick == null or not Apparition._clear_view(scene, p, pick.call("inside_point") as Vector3):
				wrong += 1
	_ok("Fenster-Gesicht: immer an einem Fenster, das man sieht", with_view > 10 and wrong == 0, "%d Standorte mit Sicht, %d falsch" % [with_view, wrong])


## Was in einem Waldstück steht (Art -> Anzahl, dazu eine Prüfsumme der Positionen).
func _forest_summary(root: Node) -> Dictionary:
	var out := {}
	for c in root.get_children():
		if c is MultiMeshInstance3D:
			var mm := (c as MultiMeshInstance3D).multimesh
			var sum := Vector3.ZERO
			for i in mm.instance_count:
				sum += mm.get_instance_transform(i).origin
			out[String(c.name)] = "%d / %s" % [mm.instance_count, sum.snappedf(0.01)]
		elif c is StaticBody3D:
			out[String(c.name)] = str(c.get_child_count())
		else:
			out["sonstige"] = int(out.get("sonstige", 0)) + 1
	return out


## Nahe Waldstücke werden jetzt über mehrere Bilder verteilt gebaut (vorher ein Ruckler pro Stück).
## Das Ergebnis muss haargenau dasselbe sein wie beim Bauen in einem Rutsch, und kein Schritt darf lange dauern.
func _t_forest_steps() -> void:
	var wild := _scene().get_node("WildForest") as WildForest
	wild.set_process(false)
	var key := Vector2i(5, -6)
	if wild._chunks.has(key):
		(wild._chunks[key]["node"] as Node).free()
		wild._chunks.erase(key)
	wild._drop_job()
	wild._build_chunk(key, 2)
	var whole := _forest_summary(wild._chunks[key]["node"])
	(wild._chunks[key]["node"] as Node).free()
	wild._chunks.erase(key)
	wild._job = WildForest.NearJob.new(key)
	var frames := 0
	var longest := 0.0
	while wild._job != null and frames < 600:
		frames += 1
		var t0 := Time.get_ticks_usec()
		wild._work_job(t0 + 3000)
		longest = maxf(longest, (Time.get_ticks_usec() - t0) / 1000.0)
		await get_tree().process_frame
	var ok := wild._job == null and wild._chunks.has(key)
	var stepped := _forest_summary(wild._chunks[key]["node"]) if ok else {}
	_ok("Wald: schrittweise gebautes Stück ist fertig geworden", ok, "%d Bilder" % frames)
	_ok("Wald: schrittweise = in einem Rutsch", ok and stepped == whole and whole.size() >= 5, "%s / %s" % [stepped, whole])
	_ok("Wald: verteilt auf mehrere Bilder, kein Schritt über 20 ms", frames >= 6 and longest < 20.0, "%d Bilder, längster Schritt %.1f ms" % [frames, longest])
	if ok:
		(wild._chunks[key]["node"] as Node).free()
		wild._chunks.erase(key)
	wild.set_process(true)


## Dasselbe für das Gelände: Höhen, Farben, Netz und Kollision in eigenen Schritten.
func _t_terrain_steps() -> void:
	var terrain := _scene().get_node("Terrain") as Terrain
	terrain.set_process(false)
	terrain._drop_job()
	var key := Vector2i(11, 9)
	if terrain._chunks.has(key):
		(terrain._chunks[key] as Node).free()
		terrain._chunks.erase(key)
	terrain._build_chunk_now(key)
	var a := _terrain_summary(terrain._chunks[key])
	(terrain._chunks[key] as Node).free()
	terrain._chunks.erase(key)
	var hs := PackedFloat32Array()
	hs.resize((Terrain.CHUNK_RES + 3) * (Terrain.CHUNK_RES + 3))
	terrain._job = {"key": key, "row": 0, "h": hs, "c": PackedColorArray()}
	var frames := 0
	var longest := 0.0
	while not terrain._job.is_empty() and frames < 600:
		frames += 1
		var t0 := Time.get_ticks_usec()
		terrain._work_job(t0, 3500.0)
		longest = maxf(longest, (Time.get_ticks_usec() - t0) / 1000.0)
		await get_tree().process_frame
	var ok := terrain._job.is_empty() and terrain._chunks.has(key)
	var b := _terrain_summary(terrain._chunks[key]) if ok else ""
	_ok("Gelände: schrittweise = in einem Rutsch", ok and a == b and a != "", "%s / %s" % [b, a])
	_ok("Gelände: verteilt auf mehrere Bilder, kein Schritt über 20 ms", frames >= 4 and longest < 20.0, "%d Bilder, längster Schritt %.1f ms" % [frames, longest])
	if ok:
		(terrain._chunks[key] as Node).free()
		terrain._chunks.erase(key)
	terrain.set_process(true)


func _terrain_summary(root: Node) -> String:
	var mi := root.get_node_or_null("Ground") as MeshInstance3D
	var body: StaticBody3D = null
	for c in root.get_children():
		if c is StaticBody3D:
			body = c
	if mi == null or body == null or body.get_child_count() == 0:
		return ""
	var arr := mi.mesh.surface_get_arrays(0)
	var shape := (body.get_child(0) as CollisionShape3D).shape as HeightMapShape3D
	return "%d Punkte, %d, %d, %d Höhen, %d" % [(arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size(), hash(arr[Mesh.ARRAY_VERTEX]),
		hash(arr[Mesh.ARRAY_COLOR]), shape.map_data.size(), hash(shape.map_data)]


## Was in der letzten Sekunde vor dem Sichern erledigt wurde, stand nicht im Spielstand (Aufgabe erst nach dem Laden abgehakt).
func _t_tasks_saved() -> void:
	Tasks.set_process(false)
	var before := Tasks.get_state()
	Tasks.done.erase("dictaphone")
	Tasks.unlocked.erase("dictaphone")
	Tasks.got.erase("dictaphone")
	Tasks.got.erase("rec_voice")
	Tasks.got["dictaphone"] = true
	Tasks.got["rec_voice"] = true
	var saved := Tasks.get_state()
	_ok("Aufgaben: frisch Erledigtes steht schon im Spielstand", (saved["done"] as Array).has("dictaphone"))
	Tasks.set_state(before)
	Tasks.set_process(true)
