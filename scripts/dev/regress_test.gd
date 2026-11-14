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
	# Nur eine Prüfung (schneller beim Entwickeln): -- --night-test=regress --only=_t_changeling
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			await call(arg.get_slice("=", 1))
			print("REGRESS TEST: %d Prüfungen, %d Fehler" % [checks, failed])
			get_tree().quit(1 if failed > 0 else 0)
			return
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
	# Seit 14.11. gibt es die Fremdpflanze – für die Prüfung kurz herausnehmen
	var crop: Dictionary = Supplies.config.crops.get("alien", {})
	Supplies.config.crops.erase("alien")
	Inventory.add("alien_seeds", 1)
	Supplies.beds[0] = Supplies._empty_bed()
	var planted := Supplies.plant(0, "alien_seeds")
	_ok("Hochbeet: unbekannte Pflanze wird nicht gesät", not planted and Supplies.bed_state(0) == "empty" and Inventory.count("alien_seeds") >= 1)
	Supplies.config.crops["alien"] = crop
	Inventory.remove("alien_seeds", Inventory.count("alien_seeds"))
	_ok("Rucksack: kein Eintrag ohne Namen", not Inventory.items.has(""))


## Weitere Prüfungen (später gefundene Fehler).
func _t_more() -> void:
	await _frames(1)
	_t_sleep_wake_passed()
	await _t_seat_first_time()
	_t_window_face()
	await _t_forest_steps()
	await _t_terrain_steps()
	_t_tasks_saved()
	await _t_seeker_house()
	_t_list_nov11()
	_t_blueprints()
	_t_nov12_evening()
	await _t_rooms()
	await _t_omens()
	await _t_siege()
	await _t_hands()
	_t_trails()
	_t_story()
	await _t_cover()
	await _t_atmosphere()
	await _t_fixes_1311()
	await _t_endings()
	await _t_camp_events()
	await _t_packing()
	await _t_stealth()
	await _t_changeling()
	await _t_fixes_1411()
	_t_village()
	await _t_batch3_1411()
	await _t_batch4_1411()


## Mehrtagesmarsch (14.11.): Ansage, Packliste, Warnung beim Losgehen
func _t_packing() -> void:
	var p := _player()
	var keep_pos := p.global_position
	var keep_active := Story.steps_active.duplicate()
	var keep_visit := Tasks.flags.has("visit_aussenstelle")
	Tasks.flags.erase("visit_aussenstelle")
	Tasks.flags.erase("packing_intro")
	Story.steps_active["p3_aussenstelle"] = Tasks.task_day()
	_ok("Mehrtagesmarsch: Außenstelle wird als Übernachtungsziel erkannt", Story.multi_trip_target() == "aussenstelle", Story.multi_trip_target())
	Story._check_packing()
	_ok("Mehrtagesmarsch: klare Ansage beim ersten Mal", Tasks.flags.has("packing_intro"))
	for id: String in ["tent", "sleeping_bag"]:
		while Inventory.count(id) > 0:
			Inventory.remove(id, 1)
	var missing := 0
	for it: Dictionary in Story.packing_status():
		if not it["ok"] and not it["optional"]:
			missing += 1
	_ok("Packliste: ohne Zelt und Schlafsack fehlt etwas", missing >= 2)
	Story._packing_warned_day = -1
	p.global_position = Vector3(80.0, Terrain.height_at(80.0, 0.0) + 0.2, 0.0)
	Story._check_packing()
	_ok("Beim Losgehen: Warnung, was fehlt", Story._packing_warned_day == TimeManager.day)
	Inventory.add("tent", 1)
	Inventory.add("sleeping_bag", 1)
	Inventory.add("food", 4)
	Inventory.add("water", 4)
	Inventory.add("wood", 4)
	missing = 0
	for it: Dictionary in Story.packing_status():
		if not it["ok"] and not it["optional"]:
			missing += 1
	_ok("Packliste: alles gepackt", missing == 0 and MapScreen.supply_text().contains("alles gepackt"))
	Inventory.remove("tent", 1)
	Inventory.remove("sleeping_bag", 1)
	Story.steps_active = keep_active
	if keep_visit:
		Tasks.flags["visit_aussenstelle"] = 1
	p.global_position = keep_pos


## Zeltnacht 2.0 (14.11.): viele Vorfälle, Tiere, Dinge zum Handeln – verletzt, tötet aber nicht.
func _t_camp_events() -> void:
	var p := _player()
	var keep_pos := p.global_position
	var keep_hp := p.health
	var cfgt := ThreatDirector.config
	# Planung: viele Vorfälle, höchstens camp_wake_max wecken
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var all_ok := true
	for k in 20:
		var kinds := CampEvents.plan(cfgt.camp_events.y, 6, cfgt.camp_wake_max, rng)
		var w := 0
		for kd: String in kinds:
			if CampEvents.wakes(kd):
				w += 1
		if w > cfgt.camp_wake_max or kinds.size() < cfgt.camp_events.y - 1:
			all_ok = false
	_ok("Zeltnacht: 4–7 Vorfälle, höchstens %d wecken" % cfgt.camp_wake_max, all_ok and cfgt.camp_events.x >= 4)
	_ok("Zeltnacht: über 20 verschiedene Vorfälle", CampEvents.data().size() >= 20)
	# Zelt aufbauen und hineinkriechen
	var base := Vector3(-60.0, 0.0, 30.0)
	base.y = Terrain.height_at(base.x, base.z)
	p.global_position = base + Vector3(0, 0.3, 3.0)
	await get_tree().physics_frame
	var tent := Builder.place("tent", base, 0.0)
	await get_tree().process_frame
	var camp: TentCamp = tent.camp if tent else null
	if camp == null:
		_ok("Zeltnacht: Zelt steht", false)
		return
	camp.interact(p)
	await get_tree().create_timer(1.3).timeout
	_ok("Zeltnacht: im Zelt", camp.occupied())
	# Reißverschluss: nicht festhalten → Hand greift herein, verletzt, aber nie unter camp_min_health
	p.health = 20.0
	camp.events.run("zipper")
	var w0 := 0.0
	while camp.events.busy() and w0 < 12.0:
		await get_tree().create_timer(0.2).timeout
		w0 += 0.2
	await get_tree().create_timer(0.6).timeout
	_ok("Reißverschluss nicht gehalten: Hand greift herein, aber man stirbt nicht", p.health < 20.0 and p.health >= cfgt.camp_min_health, "%.0f" % p.health)
	# Reißverschluss festhalten → nichts passiert
	p.health = 100.0
	camp.events.run("zipper")
	Input.action_press("interact")
	w0 = 0.0
	while camp.events.busy() and w0 < 14.0:
		await get_tree().create_timer(0.2).timeout
		w0 += 0.2
	Input.action_release("interact")
	_ok("Reißverschluss festgehalten: es lässt los", p.health == 100.0 and camp.occupied() and not camp.torn)
	# Marder: Licht an verscheucht ihn, ohne Licht klaut er Essen
	Inventory.add("food", 2)
	var food0 := Inventory.count("food")
	p.set_flashlight(true)
	camp.events.run("sniffer")
	await get_tree().create_timer(1.0).timeout
	p.set_flashlight(false)
	await get_tree().create_timer(0.3).timeout
	var kept := Inventory.count("food") == food0
	camp.events.run("sniffer")
	w0 = 0.0
	while camp.events.busy() and w0 < 10.0:
		await get_tree().create_timer(0.25).timeout
		w0 += 0.25
	_ok("Marder: Licht verscheucht ihn, ohne Licht ist Essen weg", kept and Inventory.count("food") < food0)
	# Atem: stillhalten = nichts passiert
	p.health = 100.0
	Survival.stamina = 100.0
	EventBus.sleeping = false
	Input.action_press("walk_slow")
	camp.events.run("breath_still")
	w0 = 0.0
	while camp.events.busy() and w0 < 11.0:
		await get_tree().create_timer(0.25).timeout
		w0 += 0.25
	Input.action_release("walk_slow")
	_ok("Atem am Kopf: wer stillhält und den Atem anhält (Alt), bleibt heil", p.health == 100.0)
	# … wer dabei atmet, wird bemerkt
	camp.events.run("breath_still")
	w0 = 0.0
	while camp.events.busy() and w0 < 11.0:
		await get_tree().create_timer(0.25).timeout
		w0 += 0.25
	_ok("Atem am Kopf: wer hörbar atmet, wird bemerkt", p.health < 100.0)
	p.health = 100.0
	# Wecken: leise Vorfälle wecken nicht, laute schon
	var now := TimeManager.get_total_hours()
	var keep_ev := ThreatDirector.events.duplicate(true)
	ThreatDirector.events = [{"at": now + 0.5, "type": "camp:owl_silence", "done": false}, {"at": now + 1.0, "type": "camp:zipper", "done": false}]
	var first := ThreatDirector.first_disturbance(now, now + 5.0)
	ThreatDirector.events = keep_ev
	_ok("Zeltnacht: Eule weckt nicht, Reißverschluss schon", is_equal_approx(first, now + 1.0))
	# Zelt schütteln nicht gehalten → bricht zusammen; der Zerfleischer lässt einen danach in Ruhe
	camp.events.run("shake")
	w0 = 0.0
	while camp.events.busy() and w0 < 12.0:
		await get_tree().create_timer(0.2).timeout
		w0 += 0.2
	await get_tree().process_frame
	_ok("Zelt geschüttelt, nicht gehalten: es bricht zusammen", camp.torn and not camp.occupied())
	_ok("Aufgerissenes Zelt: Zerfleischer lässt einen in dieser Nacht liegen", camp.spared_until > TimeManager.get_total_hours())
	# Stimme lockt: wer weggeht, verliert das Zelt (Zelt erst flicken)
	Inventory.add("planks", 1)
	Inventory.add("nails", 3)
	camp.interact(p)
	camp.interact(p)
	await get_tree().create_timer(1.3).timeout
	camp.events.run("lure")
	await get_tree().create_timer(0.6).timeout
	camp.leave()
	await get_tree().create_timer(1.2).timeout
	p.global_position = base + Vector3(14.0, 0.5, 0.0)
	w0 = 0.0
	while camp.events.busy() and w0 < 6.0:
		await get_tree().create_timer(0.25).timeout
		w0 += 0.25
	await get_tree().create_timer(1.2).timeout
	_ok("Kinderstimme gefolgt: das Zelt reißt hinter einem", camp.torn)
	# Alle übrigen Vorfälle einmal abspielen (keine Skriptfehler, kein Hängenbleiben)
	Inventory.add("planks", 1)
	Inventory.add("nails", 3)
	camp.interact(p)
	p.global_position = base + Vector3(0, 0.3, 3.0)
	await get_tree().physics_frame
	camp.interact(p)
	await get_tree().create_timer(1.3).timeout
	var stuck := ""
	Inventory.add("dictaphone", 1)
	for kd: String in ["owl_silence", "twigs", "deer", "wisps", "glimpse", "fox_scream", "pebbles", "radio_voice", "gear_moved",
			"face_door", "drone_scan", "mauler_prowl", "steps", "shadow", "press", "voice", "light"]:
		camp._busy = false
		camp.camp_event(kd)
		var wt := 0.0
		while (camp.events.busy() or camp._busy) and wt < 25.0:
			await get_tree().create_timer(0.25).timeout
			wt += 0.25
		if wt >= 25.0:
			stuck += kd + " "
	camp.events.morning(_scene())
	_ok("Zeltnacht: alle Vorfälle laufen durch", stuck == "", stuck)
	Inventory.remove("dictaphone", 1)
	# aufräumen
	if is_instance_valid(tent):
		Builder.remove(tent.uid)
	p.input_locked = false
	p.health = keep_hp
	p.global_position = keep_pos
	EventBus.interaction_prompt_changed.emit("")


## Endspurt und Enden (14.11.): Brunnen öffnen, Kammer, Fassung, Frist, Pickup, Abschluss-Bildschirm.
func _t_endings() -> void:
	var p := _player()
	var keep_phase := Story.phase
	var keep_seen := Settings.endings_seen.duplicate()
	var keep_pos := p.global_position
	# Daten: sieben Enden wie im Hauptmenü, jedes mit Schlussszene
	var data: Dictionary = Story.endings_data()
	var all_ok := true
	for e: Dictionary in Settings.endings():
		var d: Dictionary = data.get("endings", {}).get(e["id"], {})
		if (d.get("lines", []) as Array).size() < 3:
			all_ok = false
	_ok("Enden: alle sieben haben eine Schlussszene", all_ok and Settings.endings().size() == 7)
	# Fassung: ohne Wissen keine Wege, mit Wissen die richtigen Enden
	Story.phase = 5
	var notes := ["ast_abschaltfolge1", "tunnel_abschaltfolge2", "stef_mappe", "ast_schutzstatus"]
	var keep_notes: Array = []
	for n: String in notes:
		if Research.notes.has(n):
			keep_notes.append(n)
		Research.notes.erase(n)
	_ok("Fassung: ohne Abschaltfolge/Mappe keine Möglichkeiten", Story.socket_options().is_empty())
	for n: String in notes:
		Research.notes.append(n)
	Inventory.add("w17", 1)
	var opts: Array = Story.socket_options()
	var by_id := {}
	for o: Dictionary in opts:
		by_id[o["id"]] = o
	_ok("Fassung: Abschalten erst nach Säulen + Höhle", by_id.has("shutdown") and (not bool(by_id["shutdown"]["ok"]) or (Tasks.check("ws:structure_off") and Tasks.check("ws:source_dead"))))
	_ok("Fassung: Senden ohne Ilse = Abgeholt, Code = Schutzstatus", by_id.has("send") and by_id["send"]["ending"] == "abgeholt" \
			and by_id.has("code") and by_id["code"]["ending"] == "schutzstatus")
	var keep_mast := Tasks.check("flag:mast_repaired")
	Tasks.flag("mast_repaired")
	var with_ilse := ""
	for o: Dictionary in Story.socket_options():
		if o["id"] == "shutdown_send":
			with_ilse = o["ending"]
	_ok("Fassung: Abschalten + Senden mit Ilse = Gehört", with_ilse == "gehoert", with_ilse)
	if not keep_mast:
		Tasks.flags.erase("mast_repaired")
	# Brunnen: mit Schachtwinde öffnen (Frist beginnt), dann hinab in die Kammer und wieder hinauf
	var shaft := get_tree().get_first_node_in_group("well_shaft") as WellShaft
	Story.shaft_open_day = -1
	Inventory.add("shaft_winch", 1)
	var prompt := shaft.get_prompt(p) if shaft else ""
	if shaft:
		shaft._on_choice("open")
	_ok("Brunnen: Schachtwinde montieren öffnet den Schacht, Frist läuft", shaft != null and prompt.contains("Schachtwinde") \
			and Story.shaft_open_day == TimeManager.day and Story.nights_left() == Story.endgame_nights() \
			and Inventory.count("shaft_winch") == 0 and not shaft.boards.visible and shaft.winch.visible)
	shaft.descend(p)
	await get_tree().create_timer(1.6).timeout
	var down := RootChamber.is_inside(p.global_position)
	await get_tree().physics_frame
	await get_tree().create_timer(0.5).timeout
	var still_down := RootChamber.is_inside(p.global_position)
	_ok("Schacht: unten in der Kammer des Wurzelknotens, man fällt nicht durch", down and still_down, str(p.global_position))
	var rope := get_tree().get_first_node_in_group("root_chamber").find_child("RopeUp", true, false) as Interactable
	rope.interact(p)
	await get_tree().create_timer(1.6).timeout
	_ok("Schacht: am Seil wieder hinauf neben den Brunnen", not RootChamber.is_inside(p.global_position) and p.global_position.distance_to(Vector3(13.5, p.global_position.y, -13.0)) < 4.0)
	# Frist: am letzten Abend tritt »Zu spät« ein; Abschluss-Bildschirm läuft bis zum Ende, speichert nichts
	EndingScreen.speed = 40.0
	var keep_h := TimeManager.hour
	var keep_day := TimeManager.day
	TimeManager.day = 10
	TimeManager.hour = 23.5
	Story.shaft_open_day = TimeManager.day - Story.endgame_nights()
	Story._check_deadline()
	await get_tree().process_frame
	var screen := get_tree().get_first_node_in_group("ending_screen") as EndingScreen
	var started := screen != null and screen.ending_id == "zu_spaet" and GameState.ending_lock
	var waited := 0.0
	while is_instance_valid(screen) and not screen.finished and waited < 20.0:
		await get_tree().create_timer(0.25, true, false, true).timeout
		waited += 0.25
	_ok("Frist abgelaufen: »Zu spät« mit Schlussszene und Abspann", started and Settings.endings_seen.has("zu_spaet"), "%.1f s" % waited)
	_ok("Ende: Spiel läuft danach weiter (nicht angehalten)", not get_tree().paused)
	# Pickup: reparieren, dann wegfahren = Flucht
	Story.ending_running = false
	GameState.ending_lock = false
	Story.shaft_open_day = -1
	TimeManager.hour = keep_h
	TimeManager.day = keep_day
	var truck := get_tree().get_first_node_in_group("escape_truck") as EscapeTruck
	var keep_rep := truck.repaired if truck else false
	if truck:
		truck.repaired = false
		for id: String in truck.needs():
			Inventory.add(id, int(truck.needs()[id]))
		truck.interact(p)
	_ok("Pickup: mit Autoteilen, Batterie, Benzin repariert", truck != null and truck.repaired)
	if truck:
		truck._confirmed("yes")
		await get_tree().process_frame
		var s2 := get_tree().get_first_node_in_group("ending_screen") as EndingScreen
		var ok2 := s2 != null and s2.ending_id == "flucht"
		waited = 0.0
		while is_instance_valid(s2) and not s2.finished and waited < 20.0:
			await get_tree().create_timer(0.25, true, false, true).timeout
			waited += 0.25
		_ok("Pickup: wegfahren = Ende »Flucht«", ok2 and Settings.endings_seen.has("flucht"))
		truck.repaired = keep_rep
		truck._update_visuals()
	# Fremdpflanze (alien_seeds): wächst ohne Wasser, wird nie grau, lockt nachts (Signatur)
	var keep_bed: Dictionary = Supplies.beds[0].duplicate()
	Supplies.beds[0] = Supplies._empty_bed()
	Inventory.add("alien_seeds", 1)
	var planted := Supplies.plant(0, "alien_seeds")
	var sig_before := Supplies.alien_bed_signature()
	for d in 4:
		Supplies._on_day_changed(TimeManager.day)
	_ok("Fremdpflanze: wächst ohne Gießen, wird reif und lockt nachts", planted and Supplies.bed_state(0) == "ripe" \
			and not bool(Supplies.beds[0]["alien"]) and sig_before > 0.0, Supplies.bed_state(0))
	var fruit_before := Inventory.count("alien_fruit")
	Supplies.harvest(0)
	_ok("Fremdpflanze: Ernte = Fremdfrüchte", Inventory.count("alien_fruit") > fruit_before)
	Supplies.beds[0] = keep_bed
	# Rastplätze: an den langen Wegen, Feuerstelle wärmt, Zeltnacht dort ruhiger, Marschplanung auf der Karte
	var spots := get_tree().get_nodes_in_group("rest_spot")
	var rf := (spots[0] as Node).find_child("RestFire", false, false) if not spots.is_empty() else null
	var lit_ok := false
	if rf:
		Inventory.add("wood", 1)
		rf.interact(p)
		lit_ok = rf.burning() and rf.heat_at(rf.global_position + Vector3(1, 0, 0)) > 0.0
		rf.put_out()
	_ok("Rastplätze: an den Wegen, Feuerstelle brennt und wärmt", spots.size() == (WorldMap.data().get("rest_spots", []) as Array).size() \
			and spots.size() >= 10 and lit_ok)
	var near_rest := RestSpot.near((spots[0] as Node3D).global_position + Vector3(4, 0, 0), ThreatDirector.config.camp_rest_radius, get_tree())
	var far_rest := RestSpot.near(Vector3(0, 0, 0), ThreatDirector.config.camp_rest_radius, get_tree())
	_ok("Rastplätze: Zelt daneben zählt, an der Hütte nicht", near_rest and not far_rest)
	var mt := MapScreen.march_text(1000.0)
	_ok("Karte: Marschplanung mit Entfernung, Gehzeit und Proviant", mt.contains("km") and mt.contains("zu Fuß") \
			and MapScreen.supply_text().contains("Wasser"), mt)
	# Doppelter Schlaf (Zelt, zweimal E): die Uhr darf nur bis zum nächsten Morgen springen (früher: Tag 11 → 13)
	var d0 := TimeManager.day
	TimeManager.set_time(d0, 22.0)
	var first := EventBus.request_sleep(7.0)
	await get_tree().create_timer(0.3).timeout
	var second := EventBus.request_sleep(7.0)
	var slept := 0.0
	while EventBus.sleeping and slept < 12.0:
		await get_tree().create_timer(0.25).timeout
		slept += 0.25
	_ok("Schlafen: zweites Einschlafen wird ignoriert, nur ein Tag vergeht", first and not second and TimeManager.day <= d0 + 1,
			"Tag %d → %d" % [d0, TimeManager.day])
	p.input_locked = false
	TimeManager.set_time(d0, keep_h)
	# Zeltnacht ohne Schlafsack: durchgefroren aufwachen verletzt, aber man erfriert nicht gleich danach
	var keep_w := Survival.warmth
	var keep_hp := p.health
	Survival.warmth = 40.0
	p.health = 100.0
	Survival._sleep_from = TimeManager.get_total_hours() - 9.0
	Survival._sleep_rate = -20.0
	Survival._sleep_fire_hours = 0.0
	Survival._on_woke()
	_ok("Kälte im Zelt: verletzt, aber Gnadenfrist zum Aufwärmen", p.health >= Survival.cfg.sleep_min_health and p.health < 100.0 \
			and Survival.warmth > Survival.cfg.freeze_below and Survival.starvation_damage() == 0.0 or Survival.hunger <= 0.0 or Survival.thirst <= 0.0,
			"Wärme %.0f, Gesundheit %.0f" % [Survival.warmth, p.health])
	Survival.warmth = keep_w
	p.health = keep_hp
	# Tagebuch: Ereignisse, Notizen, Nacht – im Spielstand
	var keep_j := Journal.get_state()
	Journal.entries.clear()
	Journal._on_flag("visit_kapelle")
	Journal.note("stef_mappe")
	Journal._on_flag("story_phase_4")
	var texts: Array = []
	for e: Dictionary in Journal.entries:
		texts.append(e["text"])
	var st_j := Journal.get_state()
	Journal.set_state({})
	Journal.set_state(st_j)
	_ok("Tagebuch: Orte, Funde und Erkenntnisse stehen drin und bleiben im Spielstand", texts.size() == 3 \
			and String(texts[0]).contains(String(WorldMap.places()["kapelle"]["name"])) and Journal.entries.size() == 3 \
			and Journal.by_day().size() == 1, str(texts))
	Journal.set_state(keep_j)
	# aufräumen
	EndingScreen.speed = 1.0
	Story.ending_running = false
	GameState.ending_lock = false
	Story.phase = keep_phase
	Inventory.remove("w17", 1)
	for n: String in notes:
		if not keep_notes.has(n):
			Research.notes.erase(n)
	Settings.endings_seen = keep_seen
	p.input_locked = false
	p.global_position = keep_pos
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Fehler vom 13.11. abends: Regal-Clipping, Lampen zu tief, Leitern, Wasserhahn-Spuk, Brummton am Tag.
func _t_fixes_1311() -> void:
	var cabin := _scene().find_child("Cabin", true, false) as Cabin
	# 1) Speis-Regal: nichts ragt ins Brett, in die Seitenwand, in die Kisten oder ineinander
	var sx := -1.0 + Cabin.INT_T * 0.5 + 0.02
	var y := Cabin.FLOOR_Y
	var boards: Array[float] = []
	for lvl in 5:
		boards.append(y + 0.05 + lvl * (2.05 / 5.0))
	var items: Array[AABB] = []
	for c in cabin.get_children():
		var mi := c as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var bb := mi.transform * mi.get_aabb()
		var mid := bb.get_center()
		if mid.x < sx or mid.x > sx + 0.45 or mid.z < -4.3 or mid.z > -1.55 or mid.y < y or mid.y > y + 2.1:
			continue
		if bb.size.z > 1.0 or bb.size.y > 1.0 or bb.size.y < 0.05:
			continue   # Bretter und Seitenwände
		items.append(bb)
	var bad := 0
	for bb in items:
		var on_board := false
		for b in boards:
			if absf(bb.position.y - b) < 0.012:
				on_board = true
		if not on_board or bb.position.z < -4.26 or bb.end.z > -1.585:
			bad += 1
		var lvl_y := bb.position.y
		if absf(lvl_y - boards[2]) < 0.02 and (Cabin._overlaps(bb.position.z, bb.end.z, -3.83, -3.37) or Cabin._overlaps(bb.position.z, bb.end.z, -2.84, -2.46)):
			bad += 1
	for i in items.size():
		for j in range(i + 1, items.size()):
			if items[i].grow(-0.005).intersects(items[j].grow(-0.005)):
				bad += 1
	_ok("Speis-Regal: Vorräte stehen auf den Brettern, ohne sich zu überschneiden", items.size() > 20 and bad == 0, "%d Teile, %d Fehler" % [items.size(), bad])
	# 2) Lampen in Büro, Kinderzimmer, Dachboden, Keller sitzen an der Decke
	var flush := 0
	var hanging_new := 0
	for l in get_tree().get_nodes_in_group("lamp"):
		var lamp := l as Lamp
		if lamp == null:
			continue
		var gp := lamp.global_position
		var new_room := Cabin.OFFICE.has_point(Vector2(gp.x, gp.z)) or Cabin.KIDS.has_point(Vector2(gp.x, gp.z)) \
				or gp.y > Cabin.WALL_TOP + 0.3 or gp.y < Cabin.FLOOR_Y - 0.2
		if new_room:
			if lamp.style == "flush":
				flush += 1
			else:
				hanging_new += 1
	_ok("Neue Räume: Lampen direkt an der Decke", flush >= 5 and hanging_new == 0, "%d an der Decke, %d hängend" % [flush, hanging_new])
	# 3) Leitern: oberhalb der Decke ist der Kopf immer in der Öffnung
	var ah := _scene().find_child("AtticHatch", true, false) as AtticHatch
	var ah_ok := ah != null and _climb_head_ok(ah.climb_points(), Cabin.WALL_TOP - 0.05, AtticHatch.HOLE)
	_ok("Dachbodenleiter: Kopf geht durch die Öffnung, nicht durch die Decke", ah_ok)
	var ch := _scene().find_child("CellarHatch", true, false) as CellarHatch
	var hole := Rect2(Vector2(ch.global_position.x, ch.global_position.z) - CellarHatch.HOLE.size * 0.5, CellarHatch.HOLE.size) if ch else Rect2()
	var ch_ok := ch != null and _climb_head_ok(ch.climb_points(), -0.06, hole)
	_ok("Kellerleiter: Kopf geht durch die Öffnung, nicht durch den Boden", ch_ok)
	# 4) Wasserhahn-Spuk: am Küchenhahn mit E zudrehen
	NightOmens._tap_run(_scene())
	await get_tree().process_frame
	var tap := _scene().find_child("KitchenTap", true, false) as WaterSource
	var ghost := get_tree().get_first_node_in_group("tap_ghost")
	var had_ghost := ghost != null
	var prompt := tap.get_prompt(_player()) if tap else ""
	if tap:
		tap.interact(_player())
	await get_tree().process_frame
	await get_tree().process_frame
	_ok("Wasserhahn läuft von selbst: am Hahn [E] zudrehen", had_ghost and prompt.contains("zudrehen") \
			and get_tree().get_nodes_in_group("tap_ghost").is_empty(), prompt)
	# 5) Brummton: Rascheln im Gebüsch am Tag ohne Brummen, echte Präsenz mit
	var amb := get_tree().get_first_node_in_group("nature_ambience") as NatureAmbience
	if amb == null:
		for n in get_tree().get_nodes_in_group("nature_ambience"):
			if n is NatureAmbience:
				amb = n
	if amb:
		var keep_h := TimeManager.hour
		TimeManager.hour = 13.0
		amb._dread_level = 0.0
		amb._dread_until = -1.0
		amb.silence_for(3.0, false)
		await get_tree().create_timer(1.0).timeout
		var rustle_level := amb._dread_level
		amb.silence_for(3.0, true)
		await get_tree().create_timer(1.5).timeout
		var real_level := amb._dread_level
		amb._forced_silence_until = -1.0
		amb._dread_until = -1.0
		TimeManager.hour = keep_h
		_ok("Brummton: kein Brummen tagsüber beim Rascheln, aber bei echter Präsenz", rustle_level < 0.01 and real_level > 0.3,
				"%.2f / %.2f" % [rustle_level, real_level])
	else:
		_ok("Brummton: Naturklang gefunden", false)


func _climb_head_ok(pts: Array, ceiling_y: float, hole: Rect2) -> bool:
	for i in range(pts.size() - 1):
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		for k in 21:
			var f := a.lerp(b, k / 20.0)
			var head := f + Vector3(0, Player.STAND_HEIGHT, 0)
			# Kopf zwischen Unterseite der Decke und Fußhöhe darüber = steckt in der Decke
			if head.y > ceiling_y and f.y < ceiling_y + 0.1:
				if not hole.grow(-0.05).has_point(Vector2(head.x, head.z)):
					return false
	return true


## Stimmung (13.11.): Wind, Rascheln, Wetter, Himmel mit Mond, Vorhänge im Luftzug, Abnutzung.
func _t_atmosphere() -> void:
	var w := Wind.current
	_ok("Wind: läuft und setzt die Shader-Werte", w != null and w.strength > 0.0)
	if w:
		var g1 := w.gust_at(Vector3(0, 0, 0))
		var g2 := w.gust_at(Vector3(300, 0, 200))
		_ok("Wind: Böen sind nicht überall gleich", absf(g1 - g2) > 0.001 or w.strength < 0.05)
		Wind.disturb(Vector3(3, 0, 3), 1.0)
		w._start_rustle()
		_ok("Wind: Rascheln startet (Wind oder etwas anderes)", not w._ev.is_empty())
		w._ev = {}
	var keep_w := WorldState.weather
	for k: String in ["clear", "cloudy", "rain", "fog", "storm"]:
		WorldState.set_weather(k, 2.0)
	_ok("Wetter: Sturm ist stürmischer als klar", WorldState.weather_wind() > 0.0)
	WorldState.set_weather("rain", 2.0)
	var st := WorldState.get_state()
	_ok("Wetter: steht im Spielstand", st.get("weather", "") == "rain")
	WorldState.set_weather(keep_w, 3.0)
	var sky := DayNightEnvironment.current
	_ok("Himmel: eigener Himmel mit Mond und Wolken", sky != null)
	_ok("Wetter: Regen und Luftteilchen sind da", _scene().find_child("WeatherFx", true, false) != null \
		and _scene().find_child("AirFx", true, false) != null)
	var cur := _scene().find_child("Curtain_WindowLiving", true, false) as CurtainDraft
	_ok("Hütte: Vorhang am Wohnzimmerfenster weht", cur != null and cur.panels.size() == 6)
	if cur and cur._win:
		var keep_h := cur._win.health
		var keep_b := cur._win.barricade
		cur._win.health = 0.0
		cur._win.barricade = 0.0
		var swing := 0.0
		for k in 12:
			await get_tree().create_timer(0.1).timeout
			swing = maxf(swing, absf(cur.panels[0].rotation.x))
		cur._win.health = keep_h
		cur._win.barricade = keep_b
		_ok("Hütte: zerbrochenes Fenster = Vorhang bläht sich", swing > 0.12, "%.2f" % swing)
	var decals := 0
	var cabin := _scene().find_child("Cabin", true, false)
	if cabin:
		for c in cabin.get_children():
			if c is Decal:
				decals += 1
	_ok("Hütte: Laufwege und Flecken auf dem Boden", decals >= 6, "%d" % decals)


## Lebendiger Wald + Tarnung im Gebüsch (13.11.): Baumarten, Jungwuchs, dichte Gebüsche, geduckt + ohne Licht = getarnt.
func _t_cover() -> void:
	var forest := _scene().find_child("Forest", true, false)
	var kinds := 0
	for n: String in ["Trunks", "BirchTrunks", "BeechTrunks", "Needles", "Crowns"]:
		var mmi := forest.find_child(n, false, false) as MultiMeshInstance3D if forest else null
		if mmi and mmi.multimesh.instance_count > 0:
			kinds += 1
	_ok("Wald: Fichten, Birken, Buchen, Laubbäume im Tal", kinds == 5)
	_ok("Wald: viele dichte Gebüsche zum Verstecken", Cover.count() >= 200, "%d" % Cover.count())
	var n0 := Cover.count()
	Cover.add("test", 2000.0, 2000.0, 1.0, 1.2)
	Cover.add(Vector2i(99, 99), 2001.0, 2001.0, 1.0, 1.2)
	Cover.remove_owner(Vector2i(99, 99))
	Cover.remove_owner("test")
	_ok("Gebüsch: Stücke tragen sich sauber aus (gemischte Besitzer)", Cover.count() == n0)
	var p := _player()
	var keep := p.global_position
	var b := Cover.nearest(Vector3(-40, 0, 40))
	_ok("Wald: ein Gebüsch gefunden", b != Vector4.ZERO)
	if b == Vector4.ZERO:
		return
	var at := Vector3(b.x, Terrain.height_at(b.x, b.y) + 0.1, b.y)
	p.global_position = at
	p.velocity = Vector3.ZERO
	p.flashlight.visible = false
	Input.action_press("crouch")
	for i in 40:
		await get_tree().physics_frame
	_ok("Gebüsch: geduckt und ohne Licht getarnt", p.is_concealed())
	_ok("Gebüsch: Zerfleischer wittert dich erst ganz nah", not p.detectable_from(at + Vector3(10, 0, 0), 3.0) and p.detectable_from(at + Vector3(2, 0, 0), 3.0))
	p.flashlight.visible = true
	for i in 3:
		await get_tree().physics_frame
	var lit := p.light_shining()
	_ok("Gebüsch: mit Licht nicht getarnt", (not p.is_concealed()) if lit else true)
	p.flashlight.visible = false
	Input.action_release("crouch")
	for i in 40:
		await get_tree().physics_frame
	_ok("Gebüsch: aufrecht im normalen Gebüsch nicht getarnt", not p.is_concealed() or b.w >= TreeKit.cfg().cover_stand_height)
	p.global_position = keep


## Roter Faden der Story (13.11.): Spuren werden aktiv/erledigt, Phasen folgen, Karte, Truhe, Hinweise, Spielstand, Fäden in der Welt.
func _t_story() -> void:
	var keep_story := Story.get_state()
	var keep_flags := Tasks.flags.duplicate()
	var keep_got := Tasks.got.duplicate()
	var keep_notes := Research.notes.duplicate()
	var keep_w17 := Inventory.count("w17")
	if keep_w17 > 0:
		Inventory.remove("w17", keep_w17)
	Tasks.flags = {}
	Tasks.got = {}
	Research.notes = []
	Story.set_state({"phase": 1, "active": {}, "done": [], "hinted": []})
	Story.update(false)
	_ok("Spur: Am Anfang führt die Spur zur Absturzstelle", Story.steps_active.has("p1_absturz") and Story.active_steps().size() == 1)
	Tasks.flag("visit_crash")
	Story.update(false)
	_ok("Spur: Nach der Absturzstelle zum Umzugskarton", Story.steps_done.has("p1_absturz") and Story.steps_active.has("p1_karton"))
	Tasks.got["w17"] = true
	Story.update(false)
	var circled := false
	for t: Dictionary in Story.map_targets():
		circled = circled or (t["pos"] as Vector2).distance_to(WorldMap.place_pos("hochsitz")) < 1.0
	_ok("Spur: Dann zum Hochsitz, auf der Karte eingekreist", Story.steps_active.has("p1_hochsitz") and circled)
	Research.notes.append("ranger_map")
	Story.update(false)
	Story.update(false)
	_ok("Spur: Wendts Karte öffnet Phase 2 (Säulen + Höhle)", Story.phase == 2 and Story.steps_active.has("p2_saeulen") and Story.steps_active.has("p2_hoehle"),
		"Phase %d" % Story.phase)
	Research.notes.append("wendt_runde")
	Story.update(false)
	_ok("Spur: Kontrollrunde kreist sechs Meldekästen ein", Story.steps_active.has("p2_wendt") and Story.map_targets().size() >= 6 + 2)
	for k in 4:
		Research.notes.append("wendt_kp%d" % (k + 1))
	Story.update(false)
	_ok("Spur: Vier Meldekästen reichen", Story.steps_done.has("p2_wendt"))
	Research.notes.append("hoehle_funkgeraet")
	Story.update(false)
	Research.notes.append("messstelle_log")
	Story.update(false)
	Story.update(false)
	_ok("Spur: Höhle → Messstelle → Phase 3 (Funkmast)", Story.phase == 3 and Story.steps_active.has("p3_funkmast"), "Phase %d" % Story.phase)
	var trunk := _scene().find_child("XmasTrunk", true, false) as XmasTrunk
	_ok("Weihnachtstruhe auf dem Dachboden", trunk != null)
	if trunk:
		trunk.interact(_player())
		_ok("Truhe: vor Phase 4 nur Weihnachtssachen", not Research.notes.has("stef_mappe"))
		Research.notes.append("ast_risiken")
		Story.update(false)
		trunk.interact(_player())
		Story.update(false)
		_ok("Truhe: in Phase 4 Stefanies Mappe, dann zum Tunnel", Story.phase == 4 and Research.notes.has("stef_mappe") and Story.steps_active.has("p4_tunnel"),
			"Phase %d" % Story.phase)
	# Feststecken: zweiter Hinweis
	Story.steps_active["p4_tunnel"] = Tasks.task_day() - 20
	var night := TimeManager.is_night()
	if not night:
		Story.update(true)
		_ok("Spur: Wer feststeckt, bekommt einen zweiten Hinweis", Story.hint_shown("p4_tunnel"))
	var st := Story.get_state()
	Story.set_state({"phase": 1, "active": {}, "done": [], "hinted": []})
	Story.set_state(st)
	_ok("Spur: übersteht Speichern und Laden", Story.phase == 4 and Story.steps_done.size() == (st["done"] as Array).size()
		and Story.steps_active.has("p4_tunnel"))
	# Fäden in der Welt
	var boxes_ok := StoryProps.wendt_boxes.size() == 6
	for nr: int in StoryProps.wendt_boxes:
		var b: Vector3 = StoryProps.wendt_boxes[nr]
		if WorldMap.trail_info(b.x, b.z).x < 0.3 or Terrain.water_level_at(b.x, b.z) > b.y - 0.1:
			boxes_ok = false
	_ok("Wendts sechs Meldekästen stehen neben dem Weg im Trockenen", boxes_ok)
	var near_hut := false
	for c: Vector3 in StoryProps.cable_posts:
		near_hut = near_hut or Vector2(c.x, c.z).length() < 70.0
	_ok("Kabeltrasse: Pfosten von der Hütte bis zu den Anlagen", StoryProps.cable_posts.size() >= 30 and near_hut, "%d Pfosten" % StoryProps.cable_posts.size())
	_ok("Stefanies letzte Mail ist ungelesen, die alten nicht", _old_mails_ok())
	# zurück
	Story.set_state(keep_story)
	Tasks.flags = keep_flags
	Tasks.got = keep_got
	Research.notes = keep_notes
	if keep_w17 > 0:
		Inventory.add("w17", keep_w17)


func _old_mails_ok() -> bool:
	var couch := _scene().find_child("Couch", true, false)
	if couch == null:
		return false
	var last := false
	var first := true
	for m: Dictionary in couch.call("available"):
		if m["id"] == "mail_stef_letzte":
			last = couch.call("is_unread", m)
		if m["id"] == "mail_stef_kiste":
			first = not couch.call("is_unread", m)
	return last and first


## Waldwege (13.11.): sichtbar und vertieft auch im Tal, keine Bäume darauf, Stege von Ufer zu Ufer, Ausstattung.
func _t_trails() -> void:
	# Stege: Geländer ist fest (13.11.: man konnte hindurchlaufen)
	var railed := 0
	var bridges_with_rail := 0
	var wt := _scene().find_child("WorldTrails", true, false)
	if wt:
		for c in wt.get_children():
			if String(c.name).begins_with("Bridge_"):
				var has := c.find_child("RailCollision_L", false, false) != null and c.find_child("RailCollision_R", false, false) != null
				if c.find_child("RailCollision*", false, false) != null:
					bridges_with_rail += 1
				if has:
					railed += 1
	_ok("Stege: Geländer hat auf beiden Seiten einen festen Körper", railed > 0 and railed == bridges_with_rail, "%d" % railed)
	# Wandertafel: Zeilen beginnen links auf der Tafel und laufen nicht über den Rand
	var board := _scene().find_child("TrailBoard", true, false)
	var inside := true
	if board:
		for c in board.get_children():
			if c is Label3D and (c as Label3D).horizontal_alignment == HORIZONTAL_ALIGNMENT_LEFT:
				var lab := c as Label3D
				var longest := 0
				for line in lab.text.split("\n"):
					longest = maxi(longest, line.length())
				var right := lab.position.x + longest * lab.font_size * 0.55 * lab.pixel_size
				if lab.position.x < -0.7 or right > 0.74:
					inside = false
	_ok("Wandertafel: Schrift bleibt auf der Tafel", board != null and inside)
	var on_path := Vector2(5.0, -40.0)   # Nordweg kurz hinter dem Gartentor
	var dip := Terrain.trail_dip(on_path.x, on_path.y, WorldMap.trail_info(on_path.x, on_path.y), 20.0)
	_ok("Weg im Tal liegt tiefer als der Waldboden", dip > 0.1, "%.2f m" % dip)
	var col := Terrain.ground_color(on_path.x, on_path.y, 1.0, 1.0)
	_ok("Weg im Tal ist als Weg eingefärbt (Alpha = Wegboden)", col.a < 0.3, "a=%.2f" % col.a)
	var on_trees := 0
	for t: Vector4 in Forest.trees:
		if WorldMap.trail_info(t.x, t.z).x < 0.8:
			on_trees += 1
	_ok("Keine Talbäume auf Wegen", on_trees == 0, "%d Bäume" % on_trees)
	_ok("Stege vorhanden (Nordweg, Ostweg, Höhle)", WorldTrails.bridges.size() >= 3)
	var bad := []
	for b: Dictionary in WorldTrails.bridges:
		for k: String in ["a", "b"]:
			var e: Vector3 = b[k]
			if absf(e.y - Terrain.height_at(e.x, e.z)) > 0.25:
				bad.append("%s %s" % [k, e])
		if (b["a"] as Vector3).y < (b["pos"] as Vector3).y + 0.25:
			bad.append("zu tief %s" % b["pos"])
	_ok("Stege liegen auf beiden Ufern auf (nicht unten im Bach)", bad.is_empty(), str(bad))
	_ok("Wanderbänke und Markierungspfosten stehen", WorldTrails.benches.size() >= 15 and WorldTrails.markers.size() >= 100,
		"%d Bänke, %d Pfosten" % [WorldTrails.benches.size(), WorldTrails.markers.size()])
	_ok("Wandertafel an der Zufahrt", _scene().find_child("TrailBoard", true, false) != null)
	var benches_blocked := 0
	for b: Vector3 in WorldTrails.benches:
		if WorldMap.trail_info(b.x, b.z).x < 0.6:
			benches_blocked += 1
	_ok("Bänke stehen neben dem Weg, nicht darauf", benches_blocked == 0)


## Belagerungsnacht (13.11.): Aufgaben, Gegenmittel, Fehlschläge, Verstecken, Ende.
func _t_siege() -> void:
	var p := _player()
	var keep := p.global_position
	var keep_rot := p.rotation
	var td := ThreatDirector
	var keep_kind: String = td.night_kind
	var keep_last: int = td.last_siege_day
	# Planung: ab Nacht 5 und dann alle 4 Nächte
	_ok("Belagerung: erste ab Nacht %d, dann alle %d Nächte" % [td.config.siege_from_night, td.config.siege_every],
		td.config.siege_from_night == 5 and td.config.siege_every == 4)
	td.night_kind = "siege"
	td.siege_done_day = -1
	var keep_hour := TimeManager.hour
	TimeManager.hour = 22.0
	_ok("Belagerung: kein Schlaf", td.siege_tonight() and td.sleep_blocker() != "")
	TimeManager.hour = keep_hour
	var ch := _scene().find_child("CellarHatch", true, false) as CellarHatch
	var keep_rug := ch.rug_moved
	ch.rug_moved = true
	var s := SiegeNight.new()
	s.cfg = td.config
	s.index = 9
	s.end_total = TimeManager.get_total_hours() + 100.0
	_scene().add_child(s)
	s.set_process(false)
	_ok("Belagerung: alle vier Aufgaben laufen", s.active("music") and s.active("attic") and s.active("cellar") and s.active("window"))
	var bf := _scene().find_child("Babyfon", true, false)
	_ok("Babyfon und Büromonitor stehen bereit", bf != null and _scene().find_child("OfficeMonitorStation", true, false) != null)
	# Spieluhr
	s.wind = 0.1
	s._update_music(0.5)
	_ok("Spieluhr fast abgelaufen: Verzerrung", p.mind_extra > 0.1)
	var mb := _scene().find_child("MusicBox", true, false) as MusicBox
	mb.interact(p)
	_ok("Spieluhr aufgezogen", s.wind >= 0.6 and p.mind_extra == 0.0)
	# Dachboden
	s._attic_burst = 20.0
	for k in 10:
		s._update_attic(1.0)
	var ap := s.pressure("attic")
	s.attic_hold()
	_ok("Dachboden: Druck steigt, Zuhalten senkt ihn", ap > 0.2 and s.pressure("attic") < ap)
	Inventory.add("planks", 3)
	_ok("Dachboden: mit 2 Brettern zugenagelt", s.attic_nail() and s.nailed)
	# Keller
	for k in 30:
		s._update_cellar(1.0)
	var cp := s.pressure("cellar")
	_ok("Keller: Abstützen mit einem Brett", cp > 0.3 and s.cellar_brace() and s.pressure("cellar") == 0.0)
	# Fenster: hineinleuchten vertreibt sie
	var win: CabinWindow = null
	for w in get_tree().get_nodes_in_group("entry_point"):
		if w is CabinWindow and w.name == "WindowLivingSouth":
			win = w
	if win == null:
		for w in get_tree().get_nodes_in_group("entry_point"):
			if w is CabinWindow:
				win = w
	s._window = win
	s._stalker_phase = "work"
	s._show_stalker()
	s._set_p("window", 0.5)
	var wpos := win.global_position + Vector3(0, win.height * 0.5, 0)
	p.global_position = win.inside_point() + (win.inside_point() - win.global_position).normalized() * 1.5
	p.global_position.y = Cabin.FLOOR_Y
	await get_tree().physics_frame
	p.look_at(Vector3(wpos.x, p.global_position.y + 1.0, wpos.z), Vector3.UP)
	p.rotation.x = 0.0
	p.head.rotation.x = 0.0
	p.set_flashlight(true)
	await get_tree().process_frame
	s._update_window(0.1)
	_ok("Fenster: mit der Uhr hineinleuchten vertreibt sie", s._stalker_phase == "away" and s.pressure("window") == 0.0,
		"Phase %s, Druck %.2f" % [s._stalker_phase, s.pressure("window")])
	p.set_flashlight(false)
	# Fehlschläge: erster = Verletzung, zweiter = es ist im Haus → im Keller mit geschlossener Luke sicher
	var hp := p.health
	s._strike("test", p.global_position + Vector3(0, 1, 1))
	_ok("Erster Fehlschlag verletzt", p.health < hp and s.strikes == 1)
	p.health = 100.0
	s._strike("test", Vector3(-3.0, 1.0, 3.6))
	_ok("Zweiter Fehlschlag: es kommt herein", s._intrusion >= 0.0)
	ch.open = false
	p.global_position = Vector3(0.3, Cabin.CELLAR_FLOOR + 0.05, -3.2)
	await get_tree().physics_frame
	_ok("Im Keller mit geschlossener Luke ist man sicher", s.is_safe(p))
	s._update_intrusion(td.config.siege_hide_seconds + 9.0)
	_ok("Versteckt: es zieht wieder ab, man lebt", s._intrusion < 0.0 and s.strikes == 1 and p.health > 0.0 and not GameState.dead)
	# Echtzeit-Lauf mit schnellen Werten: Fenster + Keller drücken, man sitzt im Keller (sicher) – keine Abstürze
	s.set_process(true)
	var fast := td.config.duplicate() as ThreatConfig
	fast.siege_window_approach = Vector2(0.5, 1.0)
	fast.siege_window_seconds = 3.0
	fast.siege_cellar_seconds = 4.0
	fast.siege_hide_seconds = 2.0
	s.cfg = fast
	s.tasks["music"]["on"] = false
	s.tasks["attic"]["on"] = false
	s._stalker_phase = "away"
	s._stalker_t = 0.2
	await get_tree().create_timer(14.0).timeout
	_ok("Echtzeit: Fehlschläge passieren, im Versteck überlebt", s.strikes >= 1 and not GameState.dead and p.health > 0.0,
		"Fehlschläge %d, Gesundheit %.0f" % [s.strikes, p.health])
	s.cfg = td.config
	p.health = 100.0
	var survived := [false]
	var cb := func(ok: bool) -> void: survived[0] = ok
	EventBus.siege_finished.connect(cb)
	s.finish(true)
	await get_tree().process_frame
	EventBus.siege_finished.disconnect(cb)
	_ok("Morgengrauen: Belagerung überstanden", survived[0] and SiegeNight.current == null and Tasks.flags.has("siege_survived"))
	ch.rug_moved = keep_rug
	td.night_kind = keep_kind
	td.last_siege_day = keep_last
	p.global_position = keep
	p.rotation = keep_rot
	p.head.rotation = Vector3.ZERO
	await get_tree().create_timer(2.0).timeout   # Kompassnadel kommt zur Ruhe


## Nächtliche Vorkommnisse (13.11.): alle Arten einmal auslösen, ein paar Ergebnisse prüfen.
func _t_omens() -> void:
	var p := _player()
	var keep := p.global_position
	var keep_rot := p.rotation
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var cfg := ThreatDirector.config
	p.global_position = Vector3(-2.5, Cabin.FLOOR_Y, 2.5)   # Wohnzimmer
	var all: Array = NightOmens.HOUSE_KINDS + NightOmens.FOREST_KINDS
	for k: String in all:
		NightOmens.fire(k, _scene(), p, cfg, rng)
	await get_tree().process_frame
	_ok("Vorkommnisse: alle %d Arten laufen ohne Absturz" % all.size(), true)
	var tap := get_tree().get_first_node_in_group("tap_ghost")
	_ok("Wasserhahn läuft von selbst und lässt sich zudrehen", tap != null)
	if tap:
		tap.interact(p)
	await get_tree().process_frame
	_ok("Wasserhahn zu", get_tree().get_first_node_in_group("tap_ghost") == null)
	var ic := get_tree().get_first_node_in_group("inside_changes") as InsideChanges
	_ok("Dinge im Haus: Teddy, Buch, Becher vorhanden", ic != null and ic._props.size() == 3)
	if ic:
		ic.morning(2)
		_ok("Dinge im Haus: morgens stehen 2 anders", ic.changed_count() >= 2)
		for id: String in ic.state.keys():
			ic.put_back(id)
		_ok("Dinge im Haus: zurückgestellt", ic.changed_count() == 0)
		_ok("Neue Kinderzeichnung liegt auf dem Tisch", ic.drawing_shown and ic.find_child("KidsDrawing2", true, false) != null)
	# Hand durch Spalte: ansehen → zieht sich zurück
	for h in _scene().get_children():
		if h is NightOmens.GapHand:
			h.queue_free()
	await get_tree().process_frame
	var hand := NightOmens.GapHand.new()
	hand.inward = Vector3.UP
	_scene().add_child(hand)
	hand.global_position = Vector3(-2.0, 0.44, 0.5)
	p.global_position = Vector3(-2.0, Cabin.FLOOR_Y, 4.0)
	p.look_at(Vector3(-2.0, Cabin.FLOOR_Y + 1.0, 0.5), Vector3.UP)
	p.rotation.x = 0.0
	p.head.rotation.x = -0.35
	await get_tree().create_timer(3.5).timeout
	_ok("Hand zieht sich zurück, wenn man hinsieht", not is_instance_valid(hand) or hand._leaving)
	# Sichtung verschwindet von selbst
	var g := NightOmens.Glimpse.new()
	g.what = "mauler"
	_scene().add_child(g)
	g.global_position = Vector3(-30, Terrain.height_at(-30, 30), 30)
	_ok("Zerfleischer-Sichtung: nur Aussehen, kein Verhalten", get_tree().get_nodes_in_group("mauler").is_empty())
	var hp := p.health
	await get_tree().create_timer(10.5).timeout
	_ok("Sichtung ist nach ein paar Sekunden weg", not is_instance_valid(g))
	_ok("Sichtung verletzt niemanden", p.health >= hp - 0.1)
	p.global_position = keep
	p.rotation = keep_rot
	p.head.rotation.x = 0.0


## Anbauten (13.11.): Büro, Kinderzimmer, Dachboden mit Zugleiter, Keller unter dem Teppich.
func _t_rooms() -> void:
	# Regale an Ost-/Westwänden (Speis, Büro) liegen längs der Wand (13.11.: um 90° verdreht)
	var cabin := _scene().find_child("Cabin", true, false) as Cabin
	if cabin:
		var probe := Node3D.new()
		cabin.add_child(probe)
		var before := cabin.get_child_count()
		cabin._shelf(Vector3(1.0, 0.5, 1.0), Vector3(1.4, 2.0, 2.6), 3, false)
		var side_ok := false
		for i in range(before, cabin.get_child_count()):
			var n := cabin.get_child(i)
			var mi := n as MeshInstance3D
			if mi and mi.get_aabb().size.z < 0.1 and mi.get_aabb().size.y > 1.0:
				side_ok = true
		for i in range(cabin.get_child_count() - 1, before - 1, -1):
			cabin.get_child(i).queue_free()
		probe.queue_free()
		_ok("Regal an der Seitenwand: Seitenbretter quer, Fächer zum Raum offen", side_ok)
	var p := _player()
	_ok("Haus: Büro, Kinderzimmer, Dachboden und Keller zählen als drinnen",
		Cabin.is_inside(Vector3(0.5, 0.6, -6.5)) and Cabin.is_inside(Vector3(-7.5, 0.6, -2.0))
		and Cabin.is_inside(Vector3(0.0, Cabin.WALL_TOP + 0.3, 0.0)) and Cabin.is_inside(Vector3(0.5, Cabin.CELLAR_FLOOR + 0.2, -4.0)))
	_ok("Gelände unter dem Keller abgesenkt, daneben nicht", Terrain.height_at(0.0, -5.0) < Cabin.CELLAR_FLOOR and Terrain.height_at(-3.0, -6.0) > -0.5)
	var ah := _scene().find_child("AtticHatch", true, false) as AtticHatch
	var ch := _scene().find_child("CellarHatch", true, false) as CellarHatch
	_ok("Dachbodenluke und Kellerluke vorhanden", ah != null and ch != null)
	if ah == null or ch == null:
		return
	var keep_pos := p.global_position
	# Dachboden: Leiter herunterziehen, hochklettern, oben ankommen, wieder runter, Leiter hoch
	ah.set_down(false)
	p.global_position = AtticHatch.FOOT + Vector3(0, 0, 0.5)
	ah.interact(p)
	_ok("Dachbodenleiter lässt sich herunterziehen", ah.down and AtticHatch.down_now)
	await get_tree().create_timer(0.8).timeout
	ah.interact(p)
	await get_tree().create_timer(6.0).timeout
	_ok("Auf den Dachboden geklettert", p.global_position.y > Cabin.WALL_TOP and Cabin.is_inside(p.global_position) and not p.input_locked,
		"Position %s" % p.global_position)
	ah.interact(p)
	await get_tree().create_timer(6.0).timeout
	_ok("Vom Dachboden wieder herunter", p.global_position.y < 1.0 and not p.input_locked, "Position %s" % p.global_position)
	ah.secondary_interact(p)
	_ok("Leiter hochgeschoben", not ah.down and not AtticHatch.down_now)
	# Keller: ohne Hinweis lässt sich der Teppich nicht wegziehen
	var had_hint := Tasks.flags.has(CellarHatch.HINT_FLAG)
	Tasks.flags.erase(CellarHatch.HINT_FLAG)
	ch.rug_moved = false
	ch.open = false
	ch._apply(false)
	p.global_position = ch.global_position + Vector3(0.0, 0.0, 1.0)
	_ok("Teppich: ohne Story-Hinweis nichts zu sehen", ch.get_prompt(p) == "")
	ch.interact(p)
	_ok("Teppich bleibt ohne Hinweis liegen", not ch.rug_moved)
	Tasks.flag(CellarHatch.HINT_FLAG)
	ch.interact(p)
	ch.interact(p)
	_ok("Mit Hinweis: Teppich weg, Luke offen", ch.rug_moved and ch.open)
	await get_tree().create_timer(0.7).timeout
	ch.interact(p)
	await get_tree().create_timer(7.0).timeout
	_ok("In den Keller gestiegen", Cabin.in_cellar(p.global_position) and not p.input_locked, "Position %s" % p.global_position)
	ch.interact(p)
	await get_tree().create_timer(7.0).timeout
	_ok("Aus dem Keller wieder hinauf", p.global_position.y > 0.3 and not p.input_locked, "Position %s" % p.global_position)
	ch.secondary_interact(p)
	if not had_hint:
		Tasks.flags.erase(CellarHatch.HINT_FLAG)
	p.global_position = keep_pos
	# Bett warnt bei heruntergelassener Leiter
	ah.set_down(true)
	var bed := _scene().find_child("Bed", true, false)
	if bed and TimeManager.can_sleep():
		_ok("Bett warnt bei heruntergelassener Leiter", String(bed.call("get_prompt", p)).contains("Dachbodenleiter"))
	ah.set_down(false)


## 12.11. abends: Holzkorb 6, Licht im Versteck, Aufgabenname.
func _t_nov12_evening() -> void:
	var basket := _scene().get_node_or_null("Cabin/WoodBasket") as WoodBasket
	_ok("Holzkorb: Platz für 6 Scheite", basket != null and basket.max_wood == 6 and basket._logs.size() == 6)
	var p := _player()
	var spot: Node = null
	for h in get_tree().get_nodes_in_group("hide_spot"):
		spot = h
	var keep: Node = p.hidden_in
	p.hidden_in = spot if spot else p
	var was: bool = p.flashlight.visible
	p.set_flashlight(true)
	_ok("Versteck: Uhrlicht lässt sich drinnen einschalten", p.flashlight.visible)
	p.set_flashlight(was)
	p.hidden_in = keep
	var title := ""
	for t: Dictionary in DataDB.load_json("res://data/tasks/tasks.json").get("daily", []):
		if t.get("id", "") == "d_water":
			title = String(t.get("title", ""))
	_ok("Aufgabe heißt „Trinkwasser aufnehmen“", title.begins_with("Trinkwasser aufnehmen"), title)


## Baupläne nach und nach (12.11.): Holz frei, Stein/Dosen beim ersten Fund, Sichern nach unruhiger Nacht.
func _t_blueprints() -> void:
	var keep: Array = Research.blueprints.duplicate()
	var keep_flags: Dictionary = Tasks.flags.duplicate()
	var keep_inv: Dictionary = Inventory.items.duplicate()
	Research.blueprints.clear()
	for f: String in ["unrest_night", "creature_visited", "radio_day_7"]:
		Tasks.flags.erase(f)
	for it: String in ["stone", "cans", "wax", "wool", "sheepskin", "water_tainted"]:
		Inventory.items.erase(it)
	var rec := {}
	for r: Dictionary in DataDB.recipes():
		rec[r["id"]] = r
	_ok("Baupläne: Holzsachen von Anfang an", Research.recipe_unlocked(rec["planks"]) and Research.recipe_unlocked(rec["fence_panel"]))
	_ok("Baupläne: Lagerfeuer/Steinwall/Stachelwand/Falle gesperrt", not Research.recipe_unlocked(rec["campfire"])
		and not Research.recipe_unlocked(rec["stone_wall"]) and not Research.recipe_unlocked(rec["spike_barricade"])
		and not Research.recipe_unlocked(rec["bear_trap"]) and not Research.recipe_unlocked(rec["door_upgrade"]))
	_ok("Baupläne: gesperrt mit grauem Hinweis", Research.blueprint_hint(rec["campfire"]) != "" and Research.blueprint_hint(rec["bear_trap"]) != "")
	var win: Node = null
	for w in get_tree().get_nodes_in_group("entry_point"):
		if w is CabinWindow and (w as CabinWindow).barricade <= 0.0:
			win = w
	if win:
		_ok("Fenster: Verbarrikadieren erst nach unruhiger Nacht", String(win.call("get_secondary_prompt", _player())) == "")
	Inventory.add("stone", 1)
	_ok("Baupläne: erster Stein schaltet Lagerfeuer + Steinwall frei", Research.recipe_unlocked(rec["campfire"]) and Research.recipe_unlocked(rec["stone_wall"]))
	Tasks.flag("unrest_night")
	_ok("Baupläne: unruhige Nacht schaltet Tür + Fenster frei", Research.recipe_unlocked(rec["door_upgrade"]) and Research.blueprints.has("bp_secure"))
	Tasks.flag("creature_visited")
	_ok("Baupläne: Besuch der Kreatur schaltet Spießbarrikade frei", Research.recipe_unlocked(rec["spike_barricade"]))
	_ok("Dosen: keine im Haus, Kühlbox im Wald", _scene().find_child("EmptyCans", true, false) == null
		and _scene().find_child("CoolerCans", true, false) != null)
	Research.blueprints = keep
	Tasks.flags = keep_flags
	Inventory.items = keep_inv
	Inventory.changed.emit()


## Änderungsliste 11.11.: Sendezähler, Speis-Kisten, Lagerfeuer, Generator.
func _t_list_nov11() -> void:
	# Zwei Experimente am selben Projekt zählen beim Senden nur einmal
	var keep_exp: Dictionary = Research.experiments.duplicate(true)
	var keep_done: Array = Research.done.duplicate()
	var keep_sent: Array = Research.sent.duplicate()
	Research.experiments = {"an_test_x": ["e1", "e2"]}
	Research.done = []
	Research.sent = []
	_ok("Senden: zwei Experimente desselben Funds zählen 1", Research.unsent_count() == 1)
	Research.experiments = keep_exp
	Research.done.assign(keep_done)
	Research.sent = keep_sent
	# Speis: Konserve zurückstellen
	var shelf := _scene().find_child("FoodShelf", true, false) as ItemPickup
	_ok("Speis: Konservenkiste ist ein Lager", shelf != null and shelf.restock)
	if shelf:
		var before := shelf.amount
		shelf.amount = 0
		Inventory.add("food", 1)
		shelf.secondary_interact(_player())
		_ok("Speis: Konserve lässt sich wieder hineinstellen", shelf.amount == 1)
		shelf.amount = before
		shelf._update_visuals()
	_ok("Lagerfeuer: nur eines tragbar", int(DataDB.item("campfire").get("stack", 99)) == 1)
	_ok("Diktiergerät und Gießkanne sind Hand-Gegenstände", String(DataDB.item("dictaphone").get("hand", "")) == "dictaphone"
		and String(DataDB.item("watering_can").get("hand", "")) == "watering_can")


## Der Sucher lief an der Hütte durch die Wände hinein und schlug den Spieler im Haus (Christian, 11.11.).
func _t_seeker_house() -> void:
	var p := _player()
	p.global_position = Vector3(-2.0, Cabin.FLOOR_Y + 0.1, 1.0)
	Tasks.flags.erase("seeker_struck")
	var sk := Seeker.spawn_for(_scene(), Vector3.ZERO)
	sk.global_position = Mauler._ground(Vector3(0, 0, 30))
	sk._investigate(p.global_position)
	var was_inside := false
	for i in 900:
		await get_tree().process_frame
		was_inside = was_inside or Cabin.is_inside(sk.global_position)
		if not is_instance_valid(sk):
			break
	_ok("Sucher: kommt nicht in die Hütte", not was_inside)
	_ok("Sucher: schlägt niemanden im Haus", not Tasks.flags.has("seeker_struck"))
	if is_instance_valid(sk):
		sk.queue_free()
	await _frames(2)


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


## Neue Hände (12.11.): jedes Ding für die Hand hat ein Modell und einen Griff, der Kompass zeigt nach Norden,
## Gießkanne: Rechtsklick füllt, Linksklick gießt.
func _t_hands() -> void:
	var p := _player()
	var h := p.hands
	var holder := Node3D.new()
	add_child(holder)
	var bad: Array = []
	var all := DataDB.items()
	for id: String in all:
		if not (all[id] is Dictionary) or not (all[id] as Dictionary).has("hand"):
			continue
		var it := HandItems.build(holder, HandItems.model_of(id))
		if it.get_child_count() == 0 or float(it.get_meta("grip", 0.0)) <= 0.0:
			bad.append(id)
	holder.queue_free()
	_ok("Hände: jeder Hand-Gegenstand hat ein Modell mit Griff", bad.is_empty(), str(bad))
	# Kompass: Nadel zeigt in der Welt nach Norden (-z), egal wohin man schaut
	var old_yaw := p.rotation.y
	p.set_flashlight(true)
	h._left.visible = true
	var worst := 0.0
	for yaw: float in [0.0, 1.2, -2.0, 3.0]:
		p.rotation.y = yaw
		p.force_update_transform()
		h._update_compass(0.0)
		var dir := -h._compass.global_transform.basis.z
		dir.y = 0.0
		worst = maxf(worst, rad_to_deg(dir.normalized().angle_to(Vector3(0, 0, -1))))
	_ok("Uhr: Kompassnadel zeigt nach Norden", worst < 12.0, "Abweichung %.1f°" % worst)
	p.rotation.y = old_yaw
	p.set_flashlight(false)
	# Gießkanne in der Hand: Rechtsklick am Wasser füllt, Linksklick am Beet gießt
	Inventory.add("watering_can", 1)
	Inventory.select(Inventory.slot_of("watering_can"))
	for i in 60:
		await _frames(1)
		if h.current_kind() == "watering_can" and h._right_out <= 0.01:
			break
	_ok("Gießkanne liegt in der Hand", h.current_kind() == "watering_can")
	var tap := _scene().get_node_or_null("Cabin/KitchenTap") as WaterSource
	if tap == null:
		for w in _scene().find_children("*", "WaterSource", true, false):
			tap = w as WaterSource
			break
	var can_before := Supplies.can_water
	var beds_before: Array = Supplies.beds.duplicate(true)
	Supplies.can_water = 0
	var old_target := p.current_interactable
	p.current_interactable = tap
	h._action = ""
	h._secondary()
	_ok("Gießkanne: Rechtsklick am Wasser füllt", Supplies.can_water == Supplies.config.watering_can_charges and h._action == "fill",
			"Füllung %d, Bewegung %s" % [Supplies.can_water, h._action])
	var bed := _scene().get_node_or_null("Garden/GardenBed1") as GardenBed
	if bed:
		Inventory.add("seeds_radish", 1)
		Supplies.beds[0] = Supplies._empty_bed()
		Supplies.plant(0, "seeds_radish")
		p.current_interactable = bed
		h._action = ""
		h._cooldown = 0.0
		h._primary()
		_ok("Gießkanne: kurzer Klick am Beet gießt noch nicht", not bool(Supplies.beds[0]["watered"]) and h._action == "pour" and h._pour_wet)
		# Wasser läuft lange genug aufs Beet (Linksklick halten)
		h._flowing = true
		for k in 4:   # erster Aufruf merkt sich das Beet, danach zählt die Zeit
			h._update_bed_pour(Supplies.config.water_pour_seconds * 0.4)
		_ok("Gießkanne: Linksklick halten am Beet gießt", bool(Supplies.beds[0]["watered"]),
				"gegossen %s, Bewegung %s" % [Supplies.beds[0]["watered"], h._action])
	h._action = ""
	h._stop_pour()
	p.current_interactable = old_target
	Supplies.beds = beds_before
	Supplies.can_water = can_before
	Supplies.changed.emit()


## Schleichen (Christian 14.11.): Untergrund, Wind/Regen, Atem anhalten (Alt), Licht und Schatten, Lehnen/Fenster, Verdacht in Stufen.
func _t_stealth() -> void:
	var p := _player()
	var keep := p.global_position
	var keep_rot := p.rotation
	var keep_w: String = WorldState.weather
	var keep_h := TimeManager.hour
	var sc := Stealth.cfg()
	# Zustand aus früheren Prüfungen (Zelt, Sitzen, Schlaf) zurücksetzen
	p.set_physics_process(true)
	p.input_locked = false
	p.look_only = false
	p.in_tent = null
	p.hidden_in = null
	EventBus.sleeping = false
	var keep_wind := Wind.current.strength if Wind.current else 0.0
	if Wind.current:
		Wind.current.strength = 0.0
	_ok("Schleichen: Werte geladen (data/stealth/stealth.tres)", ResourceLoader.exists(StealthConfig.PATH) and sc.step_walk > sc.step_slow)
	_ok("Schleichen: knarrende Dielen im Haus (mit losen Brettern)", Stealth.boards().size() >= 6 and _scene().find_child("CreakyBoard_0", true, false) != null)
	var b0: Dictionary = Stealth.boards()[0]
	var bp := Vector3(float(b0["x"]), Cabin.FLOOR_Y + 0.05, float(b0["z"]))
	_ok("Schleichen: Diele knarrt nur an ihrer Stelle", Stealth.creaky_board(bp) and not Stealth.creaky_board(bp + Vector3(1.5, 0, 0)))
	# Untergrund und Gangart
	WorldState.weather = "clear"
	var o := Vector3(-40, 0, 40)
	var g := Stealth.step_radius(o, "walk", "gravel")
	var gr := Stealth.step_radius(o, "walk", "grass")
	_ok("Schleichen: Kies lauter als Wiese, Laub lauter als Erde", g > gr and Stealth.step_radius(o, "walk", "forest") > Stealth.step_radius(o, "walk", "soil"))
	_ok("Schleichen: Rennen > Gehen > langsam > geduckt", Stealth.step_radius(o, "run", "forest") > Stealth.step_radius(o, "walk", "forest") \
		and Stealth.step_radius(o, "walk", "forest") > Stealth.step_radius(o, "slow", "forest") and Stealth.step_radius(o, "slow", "forest") > Stealth.step_radius(o, "sneak", "forest"))
	_ok("Schleichen: Im Haus dämpfen die Wände", Stealth.step_radius(bp, "walk", "wood") < Stealth.step_radius(o, "walk", "wood"))
	var dry := Stealth.mask_at(o)
	WorldState.weather = "rain"
	var wet := Stealth.mask_at(o)
	WorldState.weather = "storm"
	_ok("Schleichen: Regen und Gewitter übertönen Schritte", wet >= dry + 0.3 and Stealth.mask_at(o) > wet and Stealth.step_radius(o, "walk", "gravel") < g * 0.6)
	WorldState.weather = "clear"
	# Sichtbarkeit
	TimeManager.hour = 23.5
	p.global_position = Vector3(-30, Terrain.height_at(-30, 30) + 0.1, 30)
	p.velocity = Vector3.ZERO
	p.flashlight.visible = false
	for i in 6:
		await get_tree().physics_frame
	AirFx.breath_cloud_until = 0
	var dark := Stealth.visibility(p)
	p.flashlight.visible = true
	for i in 6:
		await get_tree().physics_frame
	var lit := p.visibility if p.light_shining() else 1.0
	p.flashlight.visible = false
	TimeManager.hour = 13.0
	for i in 4:
		await get_tree().physics_frame
	var day := p.visibility
	_ok("Schleichen: nachts im Dunkeln kaum, mit Licht und am Tag gut zu sehen", dark < 0.45 and lit > 0.9 and day > 0.4, "%.2f / %.2f / %.2f" % [dark, lit, day])
	TimeManager.hour = 23.5
	Input.action_press("crouch")
	for i in 40:
		await get_tree().physics_frame
	AirFx.breath_cloud_until = 0
	var low := Stealth.visibility(p)
	_ok("Schleichen: geduckt weniger sichtbar", low < dark, "%.2f < %.2f" % [low, dark])
	Input.action_release("crouch")
	_ok("Schleichen: Sichtweite der Gegner hängt an der Sichtbarkeit", Stealth.sight_range(dark) < 15.0 and Stealth.sight_range(1.0) > 30.0)
	_ok("Schleichen: unter Bäumen Schatten, auf dem Hof nicht", Stealth.canopy(Vector3(0, 0, 0)) == 0.0)
	# Atem anhalten (Alt) + Luftschnappen
	for i in 30:
		await get_tree().physics_frame
	Survival.stamina = 100.0
	_ok("Atem: ohne Alt hört man ihn aus der Nähe", Stealth.breath_radius(p) > 0.0)
	Input.action_press("walk_slow")
	for i in 30:
		await get_tree().physics_frame
	_ok("Atem: Alt hält ihn an (unhörbar) und kostet Puste", p.holding_breath and Stealth.breath_radius(p) == 0.0 and Survival.stamina < 100.0)
	var n0 := p.last_noise_msec
	Survival.stamina = sc.breath_gasp_at - 1.0
	for i in 4:
		await get_tree().physics_frame
	_ok("Atem: ohne Puste schnappt man laut nach Luft und kann kurz nicht anhalten", not p.holding_breath and p.last_noise_msec > n0 and p.last_noise_radius > 3.0)
	Input.action_release("walk_slow")
	Survival.stamina = 100.0
	p._gasp_block = 0.0
	# Verdacht in Stufen
	var aw := Awareness.new()
	aw.see(0.5, Vector3.ZERO, 1.0, 1.0, 30.0)
	_ok("Verdacht: ganz nah und voll sichtbar schnell bemerkt", aw.stage() >= Awareness.Stage.INVESTIGATE)
	var aw2 := Awareness.new()
	aw2.see(0.5, Vector3.ZERO, sc.peek_lean, 25.0, 30.0)
	_ok("Verdacht: nur der Kopf schaut hervor, weit weg = kaum", aw2.stage() == Awareness.Stage.CALM)
	var aw3 := Awareness.new()
	aw3.hear(Vector3.ZERO, 7.0, 2.0)
	_ok("Verdacht: ein Schritt nah = stutzt", aw3.stage() == Awareness.Stage.SUSPECT)
	aw3.hear(Vector3.ZERO, 7.0, 2.0)
	_ok("Verdacht: zweiter Schritt = sieht nach", aw3.stage() >= Awareness.Stage.INVESTIGATE)
	for i in 40:
		aw3.tick(0.5)
	_ok("Verdacht: klingt ohne neue Reize ab", aw3.stage() == Awareness.Stage.CALM)
	# Kreatur: Geräusch → stutzt / sieht nach statt sofort hinzulaufen
	var c := Creature.new()
	_scene().add_child(c)
	c.mode = "attack"
	c.state = Creature.State.PROWL
	p.global_position = Vector3(-30, Terrain.height_at(-30, 30) + 0.1, 30)
	c.global_position = Creature._ground(p.global_position + Vector3(60, 0, 0))
	await get_tree().physics_frame
	c._path.clear()
	c._on_noise(c.global_position + Vector3(0, 0, 3), 7.0)
	for i in 3:
		await get_tree().physics_frame
	var s1: int = c.state
	c._on_noise(c.global_position + Vector3(0, 0, 6), 10.0)
	for i in 3:
		await get_tree().physics_frame
	_ok("Kreatur: leises Geräusch = hält inne, lautes = kommt nachsehen", s1 == Creature.State.SUSPECT and c.state == Creature.State.INVESTIGATE,
		"%s / %s" % [Creature.State.keys()[s1], Creature.State.keys()[c.state]])
	# Fenster: Glas lässt durchsehen, neben dem Fenster ist man verdeckt und nicht zu greifen
	var win := _scene().find_child("WindowLiving", true, false) as CabinWindow
	if win == null:
		for w in get_tree().get_nodes_in_group("entry_point"):
			if w is CabinWindow:
				win = w
				break
	var eye: Vector3 = win.outside_point() + Vector3(0, 1.6, 0)
	var front: Vector3 = win.inside_point()
	front.y = Cabin.FLOOR_Y + 0.05
	var side_dir := win.global_transform.basis.x.normalized()
	var beside := front + side_dir * (win.width * 0.5 + 0.55) + (win.outside_point() - win.inside_point()).normalized() * 0.4
	beside.y = Cabin.FLOOR_Y + 0.05
	p.global_position = front
	await get_tree().physics_frame
	await get_tree().physics_frame
	var seen_front := Stealth.seen_part(p.get_world_3d(), eye, p)
	c._target_entry = win
	var reach_front := c._reach_clear()
	p.global_position = beside
	await get_tree().physics_frame
	await get_tree().physics_frame
	var seen_side := Stealth.seen_part(p.get_world_3d(), eye, p)
	var reach_side := c._reach_clear()
	_ok("Fenster: durchs Glas sichtbar, seitlich daneben verdeckt", seen_front > 0.0 and seen_side == 0.0, "%.2f / %.2f" % [seen_front, seen_side])
	_ok("Fenster: davor greift sie hinein, daneben nicht", reach_front and not reach_side)
	c.queue_free()
	# Lehnen: Kopf schaut hervor = nur ein Teil sichtbar
	p._lean = 1.0
	_ok("Lehnen: spähen zählt weniger als ganz gesehen", sc.peek_lean < sc.peek_head and sc.peek_head < 1.0 and p.leaning())
	p._lean = 0.0
	# Belagerung: Lärm im Haus hört es oben
	var s := SiegeNight.new()
	s.cfg = ThreatDirector.config
	s.index = 9
	s.end_total = TimeManager.get_total_hours() + 100.0
	_scene().add_child(s)
	s.set_process(false)
	var ap := s.pressure("attic")
	EventBus.noise_made.emit(bp, 9.0)
	_ok("Belagerung: Knarren im Haus erhöht den Druck auf dem Dachboden", s.pressure("attic") > ap or not s.active("attic"))
	s.queue_free()
	WorldState.weather = keep_w
	TimeManager.hour = keep_h
	if Wind.current:
		Wind.current.strength = keep_wind
	p.global_position = keep
	p.rotation = keep_rot


## Fehler 14.11. (15-Tage-Durchlauf „Tag 8 → 10“): Weckt ein Ereignis gleich nach dem Einschlafen, war der Weckzeitpunkt nach der
## Abblende schon vorbei – skip_to_hour sprang dann einen ganzen Tag weiter. Jetzt skip_to_total: Vergangenes = nichts tun.
func _t_sleep_wake_passed() -> void:
	var d := TimeManager.day
	var h := TimeManager.hour
	var t0 := TimeManager.get_total_hours()
	TimeManager.skip_to_total(t0 - 0.01)
	_ok("Schlaf: knapp verpasster Weckzeitpunkt springt nicht einen Tag weiter", TimeManager.day == d and is_equal_approx(TimeManager.hour, h))
	TimeManager.skip_to_total(t0 + 0.5)
	_ok("Schlaf: Weckzeitpunkt in der Zukunft wird erreicht", is_equal_approx(TimeManager.get_total_hours(), t0 + 0.5))
	TimeManager.set_time(d, h)
	# Packliste: Ziele der Spur sind Texte (Fehler „Invalid call 'String' constructor“ im Durchlauf)
	_ok("Packliste: Mehrtagesziel ohne Skriptfehler", Story.multi_trip_target() is String)


## Wechselbalg (Christian 14.11.): Tarnungen mit Fehler, nur ungesehen bewegen, Enttarnen, Zupacken/Entführen, Tag, Zelt, Belagerung, Forschung.
func _t_changeling() -> void:
	var p := _player()
	var keep := p.global_position
	var keep_rot := p.rotation
	var keep_phase := Story.phase
	var keep_count := ThreatDirector.changeling_count
	var keep_h := TimeManager.hour
	var keep_d := TimeManager.day
	var keep_health := p.health
	p.set_physics_process(true)
	p.input_locked = false
	p.in_tent = null
	p.hidden_in = null
	Story.phase = 2
	var cfg := ChangelingConfig.get_default()
	_ok("Wechselbalg: Werte geladen", ResourceLoader.exists(ChangelingConfig.PATH) and cfg.grab_seconds > 0.0)
	# Alle Tarnungen bauen, deutlich und fein
	var built := 0
	for k: String in ChangelingModel.KINDS:
		for sub: bool in [false, true]:
			var r := Node3D.new()
			_scene().add_child(r)
			var info := ChangelingModel.build(r, k, sub)
			if float(info.get("height", 0.0)) > 0.4 and r.find_children("*", "MeshInstance3D", true, false).size() >= 3:
				built += 1
			else:
				print("  Tarnung zu klein: ", k, " ", sub, " ", info)
			r.queue_free()
	_ok("Wechselbalg: alle %d Tarnungen mit deutlichem und feinem Fehler" % ChangelingModel.KINDS.size(), built == ChangelingModel.KINDS.size() * 2)
	var tf := Node3D.new()
	_scene().add_child(tf)
	_ok("Wechselbalg: wahre Gestalt mit Gesicht", ChangelingModel.build_true(tf, "stand").get("head") != null)
	tf.queue_free()
	_ok("Wechselbalg: Gedanken zu jeder Tarnung", ChangelingModel.KINDS.all(func(k: String) -> bool: return Changeling.data().get("thoughts", {}).has(k)))
	# Orte im Haus: nichts steckt in Möbeln oder Wänden
	var bad: Array = []
	for where: String in ["house", "morning", "siege", "yard"]:
		for sp: Dictionary in Changeling.spots(where):
			var ch := Changeling.spawn_spot(_scene(), sp)
			ch.set_process(false)
			await get_tree().physics_frame
			var q := PhysicsShapeQueryParameters3D.new()
			var box := BoxShape3D.new()
			box.size = ch._size * Vector3(0.8, 0.8, 0.8) - Vector3(0, 0.1, 0)
			q.shape = box
			q.transform = Transform3D(ch.global_basis, ch.global_position + Vector3(0, ch._size.y * 0.5 + 0.08, 0))
			q.exclude = [ch._body.get_rid(), p.get_rid()]
			if not ch.get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty():
				bad.append(sp["id"])
			ch.queue_free()
	_ok("Wechselbalg: Tarn-Orte frei (keine Möbel/Wände)", bad.is_empty(), str(bad))
	# Kameras zeigen die wahre Gestalt, der Spieler die Tarnung
	var sv := _scene().find_child("Surveillance", true, false)
	var cam_mask := int(sv.get("camera").cull_mask) if sv and sv.get("camera") else 0
	_ok("Wechselbalg: Überwachungskamera sieht die wahre Gestalt, nicht die Tarnung",
		cam_mask & Changeling.MASK_LAYER == 0 and cam_mask & Changeling.PHANTOM_BIT != 0 and p.camera.cull_mask & Changeling.MASK_LAYER != 0)
	# Bewegt sich nur ungesehen
	var sp0: Dictionary = Changeling.spots("house").filter(func(s: Dictionary) -> bool: return s["id"] == "dining_third")[0]
	var c := Changeling.spawn_spot(_scene(), sp0, {"mode": "night", "approach": true, "fast": true})
	p.global_position = Vector3(-3.5, Cabin.FLOOR_Y + 0.05, 2.6)
	p.velocity = Vector3.ZERO
	_look(p, c.global_position + Vector3(0, 0.5, 0))
	var at0 := c.global_position
	var unseen_frames := 0
	for i in 210:
		await get_tree().process_frame
		if not c.is_seen():
			unseen_frames += 1
	print("  ungesehen in Bildern: ", unseen_frames, "  Abstand ", c.dist())
	_ok("Wechselbalg: angesehen rührt er sich nicht", c.is_seen() and c.global_position.distance_to(at0) < 0.05, "gesehen %s, bewegt %.2f" % [c.is_seen(), c.global_position.distance_to(at0)])
	_look(p, p.global_position + Vector3(-3, 0, 0))
	await _wait(6.0)
	var moved := c.global_position.distance_to(at0)
	_ok("Wechselbalg: ungesehen rückt er näher", moved > 0.5 and c.dist() < at0.distance_to(p.global_position), "%.2f m" % moved)
	c._try_step()
	_look(p, c.global_position + Vector3(0, 0.5, 0))
	await _wait(0.3)
	_ok("Wechselbalg: Hinsehen – Schleifen bricht ab", not c._moving and not c._drag.playing)
	# Uhr-LED: falscher Schatten
	p.flashlight.visible = true
	await _wait(1.0)
	_ok("Wechselbalg: im Uhrlicht ein falscher Schatten", (c._shadow.visible and c.lit_time > 0.3) or not p.light_shining())
	p.flashlight.visible = false
	# Echtheitsprüfer
	_ok("Wechselbalg: Echtheitsprüfer piept beim Hinsehen", GadgetHud.fake_text(p) != "")
	# Axt: enttarnt, flieht, hinterlässt Gelenkhaut
	Changeling._skin_day = -100
	var drops := AlienDrops.get_for(get_tree())
	var n0: int = drops.entries.size() if drops else 0
	c.on_melee_hit("axe")
	_ok("Wechselbalg: Treffer zeigt die wahre Gestalt", not c._mask.visible and c._fleeing)
	await _wait(1.2)
	_ok("Wechselbalg: danach weg, Gelenkhaut liegt da", not is_instance_valid(c) and drops and drops.entries.size() > n0 and String(drops.entries[-1]["item"]) == "changeling_skin")
	# Tagsüber geschlagen: gekränkt, kommt in der Nacht sicher
	TimeManager.hour = 13.0
	var ev0 := ThreatDirector.events.duplicate(true)
	var d := Changeling.spawn(_scene(), "bench", Vector3(30, 0, 30), {"mode": "day"})
	d.on_melee_hit("axe")
	_ok("Wechselbalg: tagsüber geschlagen – gekränkt", ThreatDirector.changeling_offended_day == TimeManager.day)
	ThreatDirector.events = ev0
	ThreatDirector.changeling_offended_day = -100
	_ok("Wechselbalg: Tagestarnung findet einen Platz (Bank/Wegweiser)", not ThreatDirector.changeling_day_spot(Vector3(0, 0, 0), RandomNumberGenerator.new()).is_empty())
	# Stufen
	ThreatDirector.changeling_count = 0
	var s1 := ThreatDirector.changeling_stage()
	ThreatDirector.changeling_count = 1
	var s2 := ThreatDirector.changeling_stage()
	ThreatDirector.changeling_count = 5
	_ok("Wechselbalg: Stufen 1 (Hof) → 2 (Haus) → 3 (fein, schnell)", s1 == 1 and s2 == 2 and ThreatDirector.changeling_stage() == 3)
	# Zupacken: Axt befreit
	TimeManager.hour = 23.0
	p.global_position = Vector3(-3.5, Cabin.FLOOR_Y + 0.05, 2.6)
	var g := Changeling.spawn(_scene(), "lamp", p.global_position + Vector3(1.0, 0, 0), {"mode": "night", "can_grab": true})
	await _frames(2)
	g._start_grab()
	_ok("Wechselbalg: packt zu – du hängst fest", Changeling.grabbing == g and p.grabbed_by == g and g._stand.visible)
	g.struggle_hit("axe")
	await _frames(3)
	_ok("Wechselbalg: Axthieb befreit", Changeling.grabbing == null and p.grabbed_by == null and not is_instance_valid(g))
	# Zupacken: [E] halten befreit
	var g2 := Changeling.spawn(_scene(), "lamp", p.global_position + Vector3(1.0, 0, 0), {"mode": "night", "can_grab": true})
	await _frames(2)
	g2._start_grab()
	Input.action_press("interact")
	await _wait(cfg.grab_seconds - 0.5)
	Input.action_release("interact")
	_ok("Wechselbalg: [E] halten reißt dich los", Changeling.grabbing == null and not is_instance_valid(g2), "Balken %.2f" % (g2._struggle if is_instance_valid(g2) else -1.0))
	# Entführt: Aufwachen im Wald, nicht weit, verletzt, Sachen verstreut, Morgen
	Inventory.add("wood", 3)
	p.health = 100.0
	var g3 := Changeling.spawn(_scene(), "lamp", p.global_position + Vector3(1.0, 0, 0), {"mode": "night", "can_grab": true})
	await _frames(2)
	g3._start_grab()
	g3._abduct()
	await _wait(2.0)
	var r := Vector2(p.global_position.x, p.global_position.z).length()
	_ok("Wechselbalg: entführt – Aufwachen im Wald, nicht weit von der Hütte", r >= cfg.abduct_distance.x - 1.0 and r <= cfg.abduct_distance.y + 1.0 and not Cabin.is_inside(p.global_position), "%.0f m" % r)
	_ok("Wechselbalg: verletzt, Morgen, Merker", p.health < 100.0 and p.health >= cfg.abduct_min_health and not TimeManager.is_night() and Tasks.flags.has("abducted") and not p.input_locked)
	# Zelt: Vorfälle da
	var ids := CampEvents.data().map(func(e: Dictionary) -> String: return e["id"])
	_ok("Wechselbalg: drei Zeltnacht-Vorfälle", ids.has("cl_backpack") and ids.has("cl_stump") and ids.has("cl_tent"))
	# Belagerung: falsches Ding im Haus, Licht vertreibt
	TimeManager.set_time(keep_d, 23.0)
	p.global_position = Vector3(-3.5, Cabin.FLOOR_Y + 0.05, 2.6)
	var s := SiegeNight.new()
	s.cfg = ThreatDirector.config
	s.index = 9
	s.end_total = TimeManager.get_total_hours() + 100.0
	_scene().add_child(s)
	s.set_process(false)
	s._fake_wait = 0.0
	s._update_fake(0.1)
	_ok("Belagerung: Aufgabe „falsches Ding“ ab Phase 2", s.active("fake") and is_instance_valid(s.fake))
	if is_instance_valid(s.fake):
		s.fake.lit_time = 99.0
		s._update_fake(0.1)
		_ok("Belagerung: Uhr-LED vertreibt das falsche Ding", s.fake == null and s.pressure("fake") == 0.0)
	s.finish(true)
	s.queue_free()
	# Forschung
	_ok("Wechselbalg: Forschung Gelenkhaut → Nachahmer → Echtheitsprüfer", Research.data().get("analyses", {}).has("an_changeling_skin") \
		and Research.data().get("links", {}).has("link_mimic") and DataDB.item("fake_probe").size() > 0)
	_ok("Wechselbalg: Stand im Spielstand", ThreatDirector.get_state().has("changeling_count"))
	for n in get_tree().get_nodes_in_group("changeling"):
		n.queue_free()
	Story.phase = keep_phase
	ThreatDirector.changeling_count = keep_count
	TimeManager.set_time(keep_d, keep_h)
	p.health = keep_health
	p.global_position = keep
	p.rotation = keep_rot


func _look(p: Player, at: Vector3) -> void:
	var d := at - p.camera.global_position
	p.rotation.y = atan2(-d.x, -d.z)
	p.head.rotation.x = atan2(d.y, Vector2(d.x, d.z).length())


## Fehler 14.11. (Christian, erste Belagerung): Gestalt stand im Kinderzimmer statt vor dem Fenster.
## Jedes Fenster: außen liegt draußen, innen liegt drinnen.
func _t_window_sides() -> void:
	var bad: Array = []
	for w in get_tree().get_nodes_in_group("entry_point"):
		if w is CabinWindow:
			var o: Vector3 = w.outside_point()
			var i: Vector3 = w.inside_point()
			if Cabin.is_inside(o + Vector3(0, 0.3, 0)) or Cabin.in_footprint(o.x, o.z, 0.0) or not Cabin.is_inside(Vector3(i.x, Cabin.FLOOR_Y + 0.5, i.z)):
				bad.append(String(w.name))
	_ok("Fenster: außen ist draußen, innen ist drinnen (alle Fenster)", bad.is_empty(), str(bad))


## Christians Testrunde 14.11. abends (erste Belagerung + 15 Punkte).
## Christians vierte Liste 14.11. nachts: Archiv-Platzhalter, Vogel, Wärme am Feuer, Babyfon, Holzstapel, Schlaf, Teststart.
func _t_batch4_1411() -> void:
	var p := _player()
	var keep := p.global_position
	var keep_d := TimeManager.day
	var keep_h := TimeManager.hour
	# Archiv: nicht erforschte Funde ohne Bild, nur „???“; der Vogel steht drin, mit seinem Platz
	Inventory.add("blind_bird", 1)
	await _frames(2)
	var list := VBoxContainer.new()
	add_child(list)
	ResearchMenu.fill_archive(list)
	var texts := ""
	var pics := 0
	var unknown := 0
	for n in list.find_children("*", "", true, false):
		if n is Label:
			texts += (n as Label).text + "\n"
		elif n is TextureRect:
			pics += 1
		if n.name == "UnknownPicture":
			unknown += 1
	_ok("Archiv: Vogel ohne Augen steht drin (mit Platz)", texts.contains("Vogel ohne Augen") and texts.contains("Mikroskop"), "")
	_ok("Archiv: unerforschte Funde zeigen kein Bild, nur ???", unknown > 0 and pics <= Research.done.filter(func(id: String) -> bool: return Research.is_sent(id)).size(), "Bilder %d, ??? %d" % [pics, unknown])
	list.queue_free()
	var el := ResearchMenu.elsewhere_lines("device")
	_ok("Analysegerät: sagt, wo der Vogel untersucht wird", Array(el).any(func(l: String) -> bool: return l.contains("Vogel")), str(el))
	Inventory.remove("blind_bird", 1)
	# Wärme: direkt am Kamin deutlich schneller als nur in geheizter Hütte
	var fp := _scene().find_child("Fireplace", true, false) as Fireplace
	if fp:
		var keep_burn := fp.burn_until
		fp.burn_until = TimeManager.get_total_hours() + 10.0
		p.global_position = fp.to_global(Vector3(1.4, 0.0, 0.0))
		p.global_position.y = Cabin.FLOOR_Y + 0.05
		var near := Survival.warmth_rate(p)
		p.global_position = Vector3(4.0, Cabin.FLOOR_Y + 0.05, 2.5)
		var far := Survival.warmth_rate(p)
		_ok("Wärme: am Kamin schneller (%.0f) als im Rest der Hütte (%.0f)" % [near, far], near > far * 2.0)
		fp.burn_until = keep_burn
	# Babyfon ohne Strom
	var bf := _scene().find_child("Babyfon", true, false)
	if bf:
		_ok("Babyfon: kein „kein Strom“ mehr", not String(bf.call("get_prompt", p)).contains("Strom"))
	# Holzstapel: alle zwei Tage wieder trocken
	var pile := _scene().find_child("Woodpile", true, false) as ResourceNode
	if pile:
		var keep_a := pile.amount
		pile.amount = 0
		pile._on_day_changed(3)
		var odd := pile.amount
		pile._on_day_changed(4)
		_ok("Holzstapel: jeden zweiten Tag wieder Scheite (%d → %d)" % [odd, pile.amount], odd == 0 and pile.amount == pile.max_amount)
		pile.amount = keep_a
	# Schlaf heilt
	var keep_hp := p.health
	p.health = 30.0
	Survival.hunger = maxf(Survival.hunger, 50.0)
	Survival.thirst = maxf(Survival.thirst, 50.0)
	p.global_position = Vector3(4.0, Cabin.FLOOR_Y + 0.05, 2.5)
	Survival._sleep_from = TimeManager.get_total_hours() - 6.0
	Survival._sleep_rate = 0.0
	Survival._on_woke()
	_ok("Schlaf heilt (30 → %.0f nach 6 Stunden)" % p.health, p.health >= 90.0)
	p.health = keep_hp
	# Teststart ab Tag 15: Zelt, Schlafsack, keine Belagerung heute Nacht
	var keep_inv := Inventory.items.duplicate(true)
	var keep_threat: Dictionary = ThreatDirector.get_state()
	GameState.test_start(15)
	_ok("Teststart: Tag 15 mit Zelt und Schlafsack, heute keine Belagerung",
		TimeManager.day == 15 and Inventory.count("tent") >= 1 and Inventory.count("sleeping_bag") >= 1 and not ThreatDirector.siege_tonight() and ThreatDirector.night_kind != "siege",
		"Tag %d, Nacht %s" % [TimeManager.day, ThreatDirector.night_kind])
	Inventory.items = keep_inv
	Inventory.changed.emit()
	ThreatDirector.set_state(keep_threat)
	TimeManager.set_time(keep_d, keep_h)
	p.global_position = keep


## Christians dritte Liste 14.11.: Regen nahtlos, Spieluhr, Dosen, Morgengrauen, nachts im Wald.
func _t_batch3_1411() -> void:
	var p := _player()
	var keep := p.global_position
	var keep_d := TimeManager.day
	var keep_h := TimeManager.hour
	# Regen als Schleife ohne Sprung: Ende und Anfang passen zusammen
	var rain := SoundBank.get_generated("rain")
	var ok_rain := rain != null and rain.loop_mode == AudioStreamWAV.LOOP_FORWARD
	if ok_rain:
		var d := rain.data
		var a := d.decode_s16(0)
		var b := d.decode_s16(d.size() - 2)
		ok_rain = absi(a - b) < 9000
	_ok("Regen: Schleife ohne Lücke", ok_rain)
	# Spieluhr: spielt sie von allein, hält E sie an (keine zweite Melodie)
	var box := _scene().get_tree().get_first_node_in_group("music_box") as MusicBox
	if box:
		NightOmens._music_box(_scene())
		var was: bool = box.is_playing()
		box.interact(p)
		_ok("Spieluhr: Vorkommnis spielt die Spieluhr selbst, E hält sie an", was and not box.is_playing())
	# Leere Dosen: vier in der Küche, an jeder zweiten Schrottstelle zwei
	var kc := _scene().find_child("KitchenCans", true, false) as ItemPickup
	_ok("Dosen: vier leere Dosen neben der Spüle", kc != null and kc.item_id == "cans" and kc.amount == 4 and Cabin.is_inside(kc.collider_offset))
	var sp := ScrapSpot.new()
	sp.spot_id = 8
	sp.kind = "barrel"
	_scene().add_child(sp)
	_ok("Dosen: an Schrottstellen liegen Dosen", sp.get_node_or_null("Cans") is ItemPickup)
	sp.queue_free()
	# Morgengrauen: Kreatur und Drohne ziehen ab, bei Tag kein Hinterhalt
	TimeManager.set_time(keep_d, 23.0)
	p.global_position = Vector3(-30, Terrain.height_at(-30, 30) + 0.1, 30)
	var c := Creature.new()
	_scene().add_child(c)
	c.global_position = Creature._ground(Vector3(-10, 0, 30))
	var dr := AlienDrone.new()
	_scene().add_child(dr)
	dr.global_position = Vector3(-20, AlienDrone.HEIGHT, 30)
	await get_tree().physics_frame
	TimeManager.set_time(keep_d, 9.0)
	ThreatDirector._on_phase_changed(false)
	await get_tree().physics_frame
	_ok("Morgengrauen: Kreatur zieht ab", c.state == Creature.State.LEAVE)
	_ok("Morgengrauen: Drohne zieht ab", dr._leaving)
	c._leave_gone()
	await get_tree().process_frame
	_ok("Morgengrauen: wer trödelt, verschwindet", not is_instance_valid(c))
	dr.queue_free()
	var before := get_tree().get_nodes_in_group("creature").size()
	ThreatDirector.spawn_ambush(p.global_position + Vector3(20, 0, 0))
	_ok("Tag: kein Hinterhalt nach Drohnen-Alarm", get_tree().get_nodes_in_group("creature").size() == before)
	# Nachts weit draußen wird es gefährlich, an der Hütte nicht
	TimeManager.set_time(maxi(keep_d, ThreatDirector.config.calm_first_nights + 2), 23.0)
	var keep_m := ThreatDirector.roam_meters
	var keep_last := ThreatDirector._roam_last
	ThreatDirector._roam_last = -99.0
	ThreatDirector.roam_count = 0
	p.global_position = Vector3(-130, Terrain.height_at(-130, 40) + 0.2, 40)
	ThreatDirector.roam_meters = 0.0
	var c0 := ThreatDirector.roam_chance()
	ThreatDirector.roam_meters = 400.0
	var c1 := ThreatDirector.roam_chance()
	p.global_position = Vector3(0, 0.5, 6.0)
	var c2 := ThreatDirector.roam_chance()
	_ok("Nachts im Wald: Gefahr wächst mit der Strecke (%.2f → %.2f), an der Hütte keine (%.2f)" % [c0, c1, c2], c0 > 0.0 and c1 > c0 and c2 == 0.0)
	ThreatDirector.roam_meters = keep_m
	ThreatDirector._roam_last = keep_last
	TimeManager.set_time(keep_d, keep_h)
	p.global_position = keep


## Versunkenes Dorf (14.11.): Kirche durch Turm und Portal bis zum Altar begehbar, Häuser neu gebaut.
func _t_village() -> void:
	var ch := _scene().get_node_or_null("Places/dorf/Church") as Node3D
	_ok("Dorf: Kirche vorhanden", ch != null)
	if ch == null:
		return
	var space := ch.get_world_3d().direct_space_state
	var sph := SphereShape3D.new()
	sph.radius = 0.32
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = sph
	var blocked := ""
	var z := 13.0
	while z > -3.5:
		q.transform = Transform3D(Basis(), ch.to_global(Vector3(0, 1.3, z)))
		for hit in space.intersect_shape(q, 4):
			var col := hit.collider as Node
			if col and ch.is_ancestor_of(col):
				blocked = "%s bei z %.1f" % [col.get_parent().name if col.get_parent() else col.name, z]
		if blocked != "":
			break
		z -= 0.5
	# Gegenprobe: an der Seitenwand muss die Abfrage etwas treffen
	q.transform = Transform3D(Basis(), ch.to_global(Vector3(4.0, 1.3, -2.0)))
	_ok("Dorf: Kirchenwand ist fest", not space.intersect_shape(q, 4).is_empty())
	_ok("Dorf: vom Turmtor bis zum Altar frei (%s)" % (blocked if blocked != "" else "frei"), blocked == "")
	var ruins := 0
	for i in 6:
		var r := _scene().get_node_or_null("Places/dorf/Ruin_%d" % i) as Node3D
		if r and r.get_child_count() > 20:
			ruins += 1
	_ok("Dorf: sechs ausgebaute Hausruinen (%d)" % ruins, ruins == 6)


func _t_fixes_1411() -> void:
	var p := _player()
	var keep := p.global_position
	var keep_d := TimeManager.day
	var keep_h := TimeManager.hour
	p.set_physics_process(true)
	p.input_locked = false
	p.in_tent = null
	p.hidden_in = null
	EventBus.sleeping = false
	_t_window_sides()
	# Gießkanne am Beetrand, nicht mitten im Gras
	var can := _scene().find_child("WateringCan", true, false) as Node3D
	var bed := _scene().find_child("GardenBed4", true, false) as Node3D
	var cpos: Vector3 = can.get("collider_offset") if can else Vector3.ZERO
	_ok("Gießkanne steht am Rand des Hochbeets", can != null and bed != null and Vector2(cpos.x - bed.global_position.x, cpos.z - bed.global_position.z).length() < 2.0,
		"%s / %s" % [str(cpos), str(bed.global_position) if bed else "-"])
	# Kurze Klänge
	var bc := SoundBank.get_sound("board_creak")
	var ts := SoundBank.get_sound("twig_snap")
	var rs := SoundBank.get_sound("roof_steps")
	_ok("Diele knarzt kurz (unter 1 s), Ast knackt sofort, Dachschritte halb so lang",
		SoundBank.has_recording("board_creak") and bc.get_length() < 1.0 and SoundBank.has_recording("twig_snap") and ts.get_length() < 0.8 \
		and rs.get_length() < 5.5, "%.2f / %.2f / %.2f s" % [bc.get_length(), ts.get_length(), rs.get_length()])
	# Die ersten beiden Nächte: nichts
	var keep_events := ThreatDirector.events.duplicate(true)
	var keep_arc: int = ThreatDirector._arc_day
	var calm := true
	for night in [1, 2]:
		ThreatDirector._arc_day = -1
		ThreatDirector.plan_night(night)
		calm = calm and ThreatDirector.events.is_empty() and ThreatDirector.night_kind == "quiet"
	_ok("Nacht 1 und 2 sind ganz ruhig", calm)
	# Belagerungsnacht: nur die Belagerung
	var keep_last: int = ThreatDirector.last_siege_day
	var keep_count: int = ThreatDirector.siege_count
	ThreatDirector._arc_day = -1
	ThreatDirector.last_siege_day = -100
	ThreatDirector.plan_night(maxi(ThreatDirector.config.siege_from_night, 9))
	var types := ThreatDirector.events.map(func(e: Dictionary) -> String: return e["type"])
	_ok("Belagerungsnacht: keine anderen Wesen und Vorkommnisse", ThreatDirector.night_kind == "siege" and types == ["siege"], str(types))
	ThreatDirector.events = keep_events
	ThreatDirector._arc_day = keep_arc
	ThreatDirector.last_siege_day = keep_last
	ThreatDirector.siege_count = keep_count
	# Sucher kommt nicht ins Kinderzimmer (Punkt am Boden, y ≈ 0)
	var inside_kids := Vector3(Cabin.KIDS.get_center().x, 0.0, Cabin.KIDS.get_center().y)
	var out := Seeker.outside(inside_kids)
	_ok("Sucher: Kinderzimmer zählt als Haus, er bleibt draußen", not Cabin.in_footprint(out.x, out.z, 0.2) and Seeker._blocked(inside_kids))
	# Belagerung: im Schrank zieht die Spieluhr einen nicht heraus
	var wardrobe := Node3D.new()
	wardrobe.set_script(load("res://scripts/dev/hide_stub.gd"))
	_scene().add_child(wardrobe)
	var s := SiegeNight.new()
	s.cfg = ThreatDirector.config
	s.index = 1
	s.end_total = TimeManager.get_total_hours() + 100.0
	_scene().add_child(s)
	s.set_process(false)
	p.hidden_in = wardrobe
	var at := p.global_position
	s._lure_to_door()
	await _frames(5)
	_ok("Belagerung: versteckt wird man nicht zur Tür gezogen", p.global_position.distance_to(at) < 0.6 and not p.input_locked and s.strikes == 1,
		"bewegt %.2f, gesperrt %s, Fehlschläge %d" % [p.global_position.distance_to(at), str(p.input_locked), s.strikes])
	p.hidden_in = null
	wardrobe.queue_free()
	s.finish(true)
	s.queue_free()
	# Nach dem Schlafen ist die Uhr aus
	p.set_flashlight(true)
	p.hands.screen_mode = true
	EventBus.sleep_finished.emit()
	await _frames(2)
	_ok("Aufwachen: Uhr ist aus, wieder LED-Modus", not p.flashlight.visible and not p.hands.screen_mode)
	# Trinkwasser-Aufgabe: auch mit aufgefüllten Flaschen
	var w0 := Inventory.count("water")
	if w0 > 0:
		Inventory.remove("water", w0)
	Inventory.add("water_raw", 2)
	_ok("Aufgabe Trinkwasser: zwei aufgefüllte Flaschen zählen", Tasks.check("bottles_full>=2"))
	Inventory.remove("water_raw", 2)
	if w0 > 0:
		Inventory.add("water", w0)
	# Tablet flackert tagsüber nie
	TimeManager.hour = 12.0
	var tab := get_tree().get_first_node_in_group("tablet_menu")
	if tab:
		tab.call("flicker", 2.0)
	_ok("Tablet flackert am Tag nicht", tab == null or float(tab.get("_flicker")) <= 0.0)
	# Aufgabe Versteck nennt E, nicht R
	var hide_text := ""
	for g: Dictionary in DataDB.load_json("res://data/tasks/tasks.json").get("goals", []):
		if g.get("id", "") == "hide":
			hide_text = String(g.get("text", ""))
	_ok("Aufgabe Versteck: (E) statt (R)", hide_text.contains("(E)") and not hide_text.contains("(R)"))
	# Karte zoomt
	var ms := get_tree().get_first_node_in_group("map_screen")
	if ms:
		Inventory.add("hiking_map", 1)
		ms.call("open")
		await _frames(2)
		ms.set("_zoom_i", 2)
		ms.set("_center", Vector2(100, -200))
		ms.call("_refresh_view")
		var w: Vector2 = ms.call("_to_world", ms.call("_to_screen", Vector2(130, -170)))
		_ok("Karte: Mausrad-Zoom, Ausschnitt stimmt", w.distance_to(Vector2(130, -170)) < 1.0 and float(ms.call("_half")) < WorldMap.limit() * 0.3)
		ms.call("close")
		Inventory.remove("hiking_map", 1)
	# Kinderzimmer: Dach ist fest
	var c := Vector3(Cabin.KIDS.get_center().x, Cabin.FLOOR_Y + 1.5, Cabin.KIDS.get_center().y)
	var q := PhysicsRayQueryParameters3D.create(c, c + Vector3(0, 3.0, 0))
	q.exclude = [p.get_rid()]
	_ok("Kinderzimmer: man springt nicht durch die Decke", not p.get_world_3d().direct_space_state.intersect_ray(q).is_empty())
	# Büro und Kinderzimmer: überall ist über dem Kopf etwas Festes (Raster, auch an den Rändern)
	var holes: Array = []
	for room: Rect2 in [Cabin.OFFICE, Cabin.KIDS]:
		for ix in 9:
			for iz in 9:
				var pt := Vector3(room.position.x + 0.25 + (room.size.x - 0.5) * ix / 8.0, Cabin.FLOOR_Y + 1.2, room.position.y + 0.25 + (room.size.y - 0.5) * iz / 8.0)
				var rq := PhysicsRayQueryParameters3D.create(pt, pt + Vector3(0, 4.0, 0))
				rq.exclude = [p.get_rid()]
				var hit := p.get_world_3d().direct_space_state.intersect_ray(rq)
				if hit.is_empty() or float(hit["position"].y) > Cabin.FLOOR_Y + 2.9:
					holes.append(Vector2(snappedf(pt.x, 0.1), snappedf(pt.z, 0.1)))
	_ok("Anbauten: keine Lücke in der Decke (%d)" % holes.size(), holes.is_empty(), str(holes.slice(0, 12)))
	# echter Sprung im Büro, nah an der Hauswand (dort ist das Pultdach am höchsten), doppelt so kräftig wie normal
	var top := -99.0
	for spot: Vector2 in [Vector2(0.5, -4.9), Vector2(-1.5, -7.5), Vector2(2.8, -6.0)]:
		p.global_position = Vector3(spot.x, Cabin.FLOOR_Y + 0.1, spot.y)
		p.velocity = Vector3.ZERO
		await _frames(10)
		p.velocity.y = p.jump_velocity * 2.0
		for i in 60:
			await get_tree().physics_frame
			top = maxf(top, p.global_position.y)
	_ok("Büro: kräftiger Sprung bleibt unter dem Dach (%.2f)" % top, top < CabinRooms.ROOF_HI)
	# Lose Dielen: nicht unter Teppichen oder Möbeln (Christian 14.11.: Teppich im Kinderzimmer, Diele unter der Couch)
	var rugs := [Rect2(-4.6, 0.6, 2.2, 2.3), Rect2(-4.2, -2.3, 1.6, 1.0), Rect2(-8.0, -2.6, 1.1, 1.2)]
	var bad_b: Array = []
	for b: Dictionary in Stealth.boards():
		if bool(b.get("attic", false)):
			continue
		var r := Rect2(float(b["x"]) - 0.55, float(b["z"]) - 0.08, 1.1, 0.16)
		var bq := PhysicsShapeQueryParameters3D.new()
		var bx := BoxShape3D.new()
		bx.size = Vector3(1.0, 0.5, 0.3)
		bq.shape = bx
		bq.transform = Transform3D(Basis(), Vector3(float(b["x"]), Cabin.FLOOR_Y + 0.35, float(b["z"])))
		bq.exclude = [p.get_rid()]
		# nur feste Möbel der Hütte zählen (Gegner/Bauteile aus früheren Prüfungen stehen manchmal noch herum)
		var cabin := _scene().get_node_or_null("Cabin")
		var furn := p.get_world_3d().direct_space_state.intersect_shape(bq, 8).filter(func(h: Dictionary) -> bool:
			return cabin != null and cabin.is_ancestor_of(h.collider as Node))
		if rugs.any(func(g: Rect2) -> bool: return g.intersects(r)) or not furn.is_empty():
			bad_b.append(Vector2(b["x"], b["z"]))
	_ok("Lose Dielen liegen frei (kein Teppich, keine Möbel darüber)", bad_b.is_empty(), str(bad_b))
	# Hochsitz neben dem Weg
	var ti := WorldMap.trail_info(RangerTower.SITE.x, RangerTower.SITE.z)
	_ok("Hochsitz steht neben dem Weg, nicht darauf", ti.x > 3.0, "%.1f m" % ti.x)
	# Experiment-Hinweise verständlich
	_ok("Experiment-Hinweis erklärt „laut“", ResearchMenu._effect_hint("noise").contains("hören"))
	# Bett: hinlegen und aufstehen
	TimeManager.set_time(keep_d, 22.5)
	var bd := _scene().find_child("Bed", true, false)
	if bd == null:
		for n in _scene().find_children("*", "Bed", true, false):
			bd = n
			break
	if bd:
		p.global_position = (bd as Node3D).to_global(Vector3(0.75, 0.2, -0.6))
		await _frames(3)
		bd.call("interact", p)
		await _wait(1.6)
		var lying: bool = p.head.rotation.x > 0.8 and not p.hands.visible
		var t := 0.0
		while (EventBus.sleeping or p.input_locked) and t < 20.0:
			await _wait(0.5)
			t += 0.5
		_ok("Bett: hinlegen (Blick zur Decke), aufwachen und aufstehen", lying and not p.input_locked and p.hands.visible and absf(p.head.rotation.x) < 0.3,
			"liegt %s, frei nach %.1f s" % [str(lying), t])
	TimeManager.set_time(keep_d, keep_h)
	p.global_position = keep
