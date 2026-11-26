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
	bc._unhandled_input(_action("attack"))
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
	await _t_batch5_1511()
	await _t_batch6_2311()
	await _t_watch_log()
	await _t_seeker_at_house()
	await _t_dread_2311()
	await _t_render_2411()
	await _t_hide_2411()
	await _t_bayerwald_2411()
	await _t_wild_wood_2411()
	await _t_season_2411()
	await _t_greens_2411()
	await _t_landscape_2411()
	await _t_places_2411()
	await _t_waldler_2411()
	await _t_sounds_2411()
	await _t_fixes_2511()
	await _t_fixes_2511b()
	await _t_build_hand_2511()
	await _t_fixes_2511c()
	await _t_ui_2611()


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
		var grp := forest.find_child(n, false, false) if forest else null
		var count := 0
		if grp:
			for c in grp.get_children():
				if c is MultiMeshInstance3D:
					count += (c as MultiMeshInstance3D).multimesh.instance_count
		if count > 0:
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
	# Vorkommnis „Schranktür geht auf“ zurücksetzen (spätere Prüfungen erwarten geschlossene Verstecke)
	for h in get_tree().get_nodes_in_group("hide_spot"):
		if h is HideSpot and not (h as HideSpot).occupied:
			(h as HideSpot).set_door((h as HideSpot).style == "curtain")


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
		_ok("Fenster: Verbarrikadieren erst nach unruhiger Nacht", String(win.call("board_prompt")) == "")
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
		if not (all[id] is Dictionary) or not (all[id] as Dictionary).has("hand") or String((all[id] as Dictionary)["hand"]) == "build":
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
## Christians Liste 15.11. abends: Stacheln im Wald, Zerfleischer am Morgen, Steine, Türspion, Esc am Monitor, Lagerfeuer-Vorschau, Uhr im Zelt.
func _t_batch5_1511() -> void:
	var p := _player()
	var keep := p.global_position
	var keep_d := TimeManager.day
	var keep_h := TimeManager.hour
	# Wurzelanläufe, Aststummel, Zweige: nichts darf senkrecht als Stachel aus dem Boden ragen
	var parts := TreeKit.Parts.new()
	for i in 30:
		TreeKit.build(TreeKit.make(float(i) * 7.0, 0.0, 0.0, "spruce" if i % 2 == 0 else "oak", 0.8, float(i), 100 + i), 2, parts, null)
	var spikes := 0
	for t: Transform3D in parts.trunks:
		# dünne Teile (keine Stämme): höchstens so hoch wie lang schräg
		var w := t.basis.x.length()
		var up := absf(t.basis.y.y)
		if w < 0.08 and up > 1.2 and t.origin.y < 1.0:
			spikes += 1
	_ok("Wald: keine senkrechten Stacheln an Bäumen (%d)" % spikes, spikes == 0)
	# Zerfleischer zieht im Morgengrauen ab
	TimeManager.set_time(keep_d, 23.0)
	p.global_position = Vector3(-140, Terrain.height_at(-140, 60) + 0.2, 60)
	var m := Mauler.spawn_near(_scene(), p.global_position)
	await _frames(3)
	TimeManager.set_time(keep_d, 8.0)
	ThreatDirector._on_phase_changed(false)
	await _frames(2)
	_ok("Morgengrauen: Zerfleischer zieht ab", is_instance_valid(m) and m.state == Mauler.State.LEAVE)
	if is_instance_valid(m):
		m.queue_free()
	# Steine im Wald
	var drops := AlienDrops.get_for(get_tree())
	var before := drops.entries.filter(func(e: Dictionary) -> bool: return e["item"] == "stone").size() if drops else 0
	Supplies._on_day_changed(TimeManager.day)
	var after := drops.entries.filter(func(e: Dictionary) -> bool: return e["item"] == "stone").size() if drops else 0
	_ok("Wald: neue lose Steine (%d → %d)" % [before, after], after > before)
	# Türspion: von innen benutzbar, zeigt etwas, E/Esc schließt
	var ph := _scene().find_child("Peephole", true, false) as Peephole
	_ok("Türspion: an der Haustür", ph != null)
	if ph:
		TimeManager.set_time(maxi(keep_d, 8), 23.0)
		p.global_position = Vector3(-3.0, Cabin.FLOOR_Y + 0.05, 3.6)
		_ok("Türspion: Hinweis von innen", ph.get_prompt(p) != "")
		Peephole._night_key = -1
		ph.interact(p)
		await _frames(3)
		var cam_ok := get_viewport().get_camera_3d() != p.camera and Peephole.current == ph and p.input_locked
		ph._kind = "back"
		ph._start_scare()
		await _frames(2)
		var scare_ok := ph._scare != null
		var closed := ph.esc_close()
		await _frames(2)
		_ok("Türspion: Blick hinaus, etwas steht da, Esc schließt", cam_ok and scare_ok and closed and Peephole.current == null and get_viewport().get_camera_3d() == p.camera and not p.input_locked)
		p.global_position = Vector3(-3.0, 0.2, 7.5)
		_ok("Türspion: von außen nicht benutzbar", ph.get_prompt(p) == "")
		var counts := {}
		Peephole._night_key = -1
		for i in 200:
			Peephole._night_count = 0
			var k := ph._pick_scare()
			counts[k] = int(counts.get(k, 0)) + 1
		_ok("Türspion: meist leer, manchmal etwas (%s)" % str(counts), int(counts.get("", 0)) > 80 and counts.size() >= 4)
	# Monitor: Esc schließt
	var hud := _scene().find_child("Hud", true, false)
	if hud == null:
		hud = get_tree().get_first_node_in_group("hud")
	get_tree().call_group("surveillance", "install_defaults")
	hud.call("open_monitor")
	await _frames(2)
	_ok("Monitor: Esc schließt", bool(hud.call("esc_close")) and not bool(hud.get("_monitor_open")))
	# Lagerfeuer-Vorschau hat Teile (sonst kein grün/rot)
	var pv := Structure.new()
	pv.type = "campfire"
	pv.preview = true
	add_child(pv)
	_ok("Lagerfeuer: Vorschau sichtbar", pv.find_children("*", "GeometryInstance3D", true, false).size() > 4)
	pv.queue_free()
	# Uhr: F halten wechselt LED/Display auch, wenn die Bewegung ruht (Zelt, Sitzen)
	p.set_physics_process(false)
	p.set_flashlight(true)
	var mode := p.hands.screen_mode
	p._f_down = true
	p._f_used = false
	p._f_held = 0.0
	Input.action_press("flashlight")
	await _wait(Player.LIGHT_MODE_HOLD + 0.3)
	Input.action_release("flashlight")
	_ok("Uhr: LED/Display wechseln ohne Laufen (Zelt)", p.hands.screen_mode != mode)
	p.set_physics_process(true)
	if p.hands.screen_mode != mode:
		p.hands.toggle_screen_mode()
	p.set_flashlight(false)
	# Tagsüber weit draußen: auch dann kann der Zerfleischer kommen (nicht direkt nach dem Morgengrauen)
	var keep_phase := Story.phase
	Story.phase = 2
	TimeManager.set_time(maxi(keep_d, 8), 14.0)
	ThreatDirector._roam_last = -99.0
	ThreatDirector.roam_count = 0
	ThreatDirector.roam_meters = 500.0
	p.global_position = Vector3(-420, Terrain.height_at(-420, 180) + 0.2, 180)
	var day_c := ThreatDirector.roam_chance()
	TimeManager.set_time(maxi(keep_d, 8), 8.0)
	var dawn_c := ThreatDirector.roam_chance()
	_ok("Tag weit draußen: Gefahr (%.2f), aber nicht gleich am Morgen (%.2f)" % [day_c, dawn_c], day_c > 0.0 and dawn_c == 0.0)
	Story.phase = keep_phase
	ThreatDirector.roam_meters = 0.0
	# Hände/Axt im Dunkeln: das Streulicht der Hände folgt der Umgebung
	var hands := p.hands
	p.global_position = Vector3(-60, Terrain.height_at(-60, 40) + 0.2, 40)
	p.set_flashlight(false)
	TimeManager.set_time(maxi(keep_d, 8), 23.0)
	var night_lv := hands.ambient_level()
	TimeManager.set_time(maxi(keep_d, 8), 13.0)
	var day_lv := hands.ambient_level()
	_ok("Hände: nachts kaum Streulicht (%.2f), am Tag voll (%.2f)" % [night_lv, day_lv], night_lv < 0.2 and day_lv > 0.6)
	# Todes-Bildschirm: jede Ursache hat Text und Ratschläge
	var missing: Array = []
	for c: String in ["creature", "mauler", "mind", "siege_found", "siege_fail", "attic", "gap_hand", "trap", "hunger", "thirst", "cold", "bog", "unknown", "gibtsnicht"]:
		var info := Hud.death_info(c)
		if String(info.get("title", "")) == "" or Array(info.get("tips", [])).size() < 2:
			missing.append(c)
	_ok("Todes-Bildschirm: Ursache und Ratschläge für alles (%s)" % str(missing), missing.is_empty())
	TimeManager.set_time(keep_d, keep_h)
	p.global_position = keep


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
	_ok("Schlaf heilt ein wenig (30 → %.0f nach 6 Stunden)" % p.health, absf(p.health - (30.0 + 6.0 * Survival.cfg.sleep_heal_per_hour)) < 0.5)
	p.health = keep_hp
	# Zelt: weit draußen im Wald aufstellbar (früher nur ±100 m um die Hütte), Dachflächen vom First nach außen
	var bc := _scene().get_node("BuildController") as BuildController
	Inventory.add("tent", 1)
	bc.start("tent")
	await _frames(2)
	var far_ok := false
	for spot: Vector2 in [Vector2(-420, 180), Vector2(300, -350), Vector2(-250, -500), Vector2(500, 300)]:
		var fp2 := Vector3(spot.x, Terrain.height_at(spot.x, spot.y), spot.y)
		if bc._check_valid(fp2):
			far_ok = true
			break
	_ok("Zelt: lässt sich weit weg von der Hütte aufstellen", far_ok)
	var cr := bc._preview.get_node_or_null("CanvasR") as Node3D
	var cl := bc._preview.get_node_or_null("CanvasL") as Node3D
	_ok("Zelt: Planen fallen vom First nach außen ab", cr != null and cl != null and cr.rotation.z < 0.0 and cl.rotation.z > 0.0)
	bc.stop()
	Inventory.remove("tent", 1)
	# Wechselbalg kommt öfter, wenn man nachts wach ist – aber nur einmal pro Nacht und nicht im Schlaf
	var keep_phase := Story.phase
	var keep_cl := ThreatDirector._changeling_tonight
	var keep_kind := ThreatDirector.night_kind
	Story.phase = 2
	ThreatDirector.night_kind = "visit"
	ThreatDirector._changeling_tonight = false
	TimeManager.set_time(maxi(keep_d, 8), 23.5)
	p.global_position = Vector3(4.0, Cabin.FLOOR_Y + 0.05, 2.5)
	var awake_ok := ThreatDirector.changeling_awake_possible()
	EventBus.sleeping = true
	var asleep_ok := ThreatDirector.changeling_awake_possible()
	EventBus.sleeping = false
	ThreatDirector._changeling_tonight = true
	var twice_ok := ThreatDirector.changeling_awake_possible()
	_ok("Wechselbalg: kommt, wenn man wach ist (nicht im Schlaf, nur einmal pro Nacht)", awake_ok and not asleep_ok and not twice_ok)
	Story.phase = keep_phase
	ThreatDirector._changeling_tonight = keep_cl
	ThreatDirector.night_kind = keep_kind
	TimeManager.set_time(keep_d, keep_h)
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
	# Balken landeten an der Hütte (look_at in Weltkoordinaten) – alle Teile müssen beim Dorf liegen
	var dorf := _scene().get_node_or_null("Places/dorf") as Node3D
	var stray := 0
	for m in dorf.find_children("*", "MeshInstance3D", true, false):
		if Vector2((m as Node3D).global_position.x, (m as Node3D).global_position.z).length() < 120.0:
			stray += 1
	_ok("Dorf: kein Teil fliegt woanders herum (%d)" % stray, stray == 0)


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


## Christians Liste 23.11.: Rauschen bleibt nicht hängen, Hinweis-Stapel, Karton erst mit Aufgabe, Topf auf dem Ofen,
## Bretterlager, Tablet öffnet mit Aufgaben, Bildrate in den Einstellungen.
func _t_batch6_2311() -> void:
	var p := _player()
	# Schleifen-Klänge ohne Positionsangabe (Rauschen) laufen nicht endlos
	var holder := Node.new()
	add_child(holder)
	SoundBank.play_ui(holder, "static", -40.0)
	await get_tree().create_timer(1.6).timeout
	_ok("Rauschen über play_ui hört von selbst auf", holder.get_child_count() == 0)
	holder.queue_free()
	# Hinweise stapeln sich: neuester oben, ältere bleiben darunter
	var hud := _scene().get_node_or_null("Hud") as Hud
	if hud == null:
		hud = get_tree().get_first_node_in_group("hud") as Hud
	if hud:
		# seit 26.11.: Gedanken nacheinander, beide lassen sich auf der Uhr nachlesen
		hud._queue.clear()
		hud._thought_t = 0.0
		hud.show_notification("Erster Hinweis", 0.5)
		hud.show_notification("Zweiter Hinweis", 3.0)
		_ok("Hinweise: erster bleibt sichtbar, zweiter wartet", hud.visible_thought() == "Erster Hinweis")
		_ok("Hinweise: beide auf der Uhr nachlesbar", hud.log_entries.size() >= 2 and String(hud.log_entries[0]["text"]) == "Zweiter Hinweis")
		await get_tree().create_timer(3.2).timeout
		_ok("Hinweise: danach kommt der zweite", hud.visible_thought() == "Zweiter Hinweis")
	else:
		_ok("Hinweise: Hud gefunden", false)
	# Umzugskarton erst mit Aufgabe
	var box := _scene().get_node("Cabin/MovingBox") as MovingBox
	var keep_open := box.opened
	var keep_bypass := MovingBox.bypass_lock
	var keep_active := Story.steps_active.duplicate()
	var keep_done := Story.steps_done.duplicate()
	var keep_got := Tasks.got.duplicate()
	box.opened = false
	MovingBox.bypass_lock = false
	Story.steps_active.erase("p1_karton")
	Story.steps_done.erase("p1_karton")
	Tasks.got.erase("metal_fragment")
	var keep_frag := Inventory.count("metal_fragment")
	Inventory.remove("metal_fragment", keep_frag)
	var locked := not box.can_open()
	Story.steps_active["p1_karton"] = Tasks.task_day()
	_ok("Umzugskarton: zu, bis die Spur dazu auffordert", locked and box.can_open())
	box.opened = keep_open
	MovingBox.bypass_lock = keep_bypass
	Story.steps_active = keep_active
	Story.steps_done = keep_done
	Tasks.got = keep_got
	Inventory.add("metal_fragment", keep_frag)
	# Topf im Ofen: gart nur mit Feuer, unfertig = Zutaten zurück, fertig = Ergebnis
	var stove := _scene().get_node("Cabin/CookStove") as CookStove
	var boil: Dictionary = {}
	for r: Dictionary in DataDB.recipes():
		if r.get("id", "") == "boil_water2":
			boil = r
	var keep_water := Inventory.count("water")
	var keep_raw := Inventory.count("water_raw")
	Inventory.remove("water", keep_water)   # Stapelgrenze der Flaschen soll den Test nicht stören
	Inventory.remove("water_raw", keep_raw)
	var raw0 := 0
	var clean0 := 0
	Inventory.add("water_raw", 2)
	stove.pot = null
	stove.burn_until = TimeManager.get_total_hours() + 0.1
	var why := stove.start_cooking(boil)
	_ok("Ofen: Flaschen kommen in den Topf (%s)" % why, why == "" and Inventory.count("water_raw") == raw0 and stove.pot != null)
	TimeManager.advance_hours(1.0)   # Feuer geht nach 0,1 Std. aus
	for i in 3:
		await get_tree().process_frame
	var part := stove.pot.progress() if stove.pot else -1.0
	_ok("Ofen: ohne Feuer bleibt es unfertig im Topf (%d %%)" % int(part * 100.0), stove.pot != null and part > 0.0 and part < 1.0)
	stove.take_pot()
	_ok("Ofen: unfertig herausnehmen gibt beide Flaschen zurück", stove.pot == null and Inventory.count("water_raw") == raw0 + 2)
	stove.burn_until = TimeManager.get_total_hours() + 3.0
	stove.start_cooking(boil)
	TimeManager.advance_hours(1.0)
	for i in 3:
		await get_tree().process_frame
	var done := stove.pot != null and stove.pot.finished()
	stove.take_pot()
	_ok("Ofen: mit Feuer fertig, abgekochtes Wasser herausgenommen", done and Inventory.count("water") == clean0 + 2)
	_ok("Ofen: Topf wird gespeichert", stove.get_state().has("pot"))
	Inventory.remove("water", Inventory.count("water"))
	Inventory.remove("water_raw", Inventory.count("water_raw"))
	Inventory.add("water", keep_water)
	Inventory.add("water_raw", keep_raw)
	stove.burn_until = -1.0
	# Bretterlager: nehmen und auffüllen, Bretter sichtbar
	var rack := _scene().get_node("Cabin/PlankPile") as PlankRack
	_ok("Bretterlager ist ein Regal mit einzelnen Brettern", rack != null and rack._planks.size() >= rack.max_amount)
	if rack:
		var a0 := rack.amount
		var pl0 := Inventory.count("planks")
		rack.interact(p)
		var after_take := rack.amount
		rack.secondary_interact(p)
		var shown := rack._planks.filter(func(n: Node3D) -> bool: return n.visible).size()
		_ok("Bretterlager: nehmen und wieder auffüllen (%d → %d → %d, sichtbar %d)" % [a0, after_take, rack.amount, shown],
				after_take < a0 and rack.amount >= a0 and shown == rack.amount and Inventory.count("planks") <= pl0)
	# Tablet öffnet mit den Aufgaben
	var tablet := _scene().get_node_or_null("TabletMenu") as TabletMenu
	var couch := _scene().get_node_or_null("Cabin/Couch") as Couch
	if tablet and couch:
		tablet.open(couch)
		await _frames(1)
		_ok("Tablet: beim Öffnen Reiter Aufgaben, Aufgaben steht vorne", tablet._tab == "tasks" and (tablet._tabs.keys()[0] == "tasks"))
		tablet._root.visible = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# Bildrate: Obergrenze greift
	var keep_fps := Settings.max_fps
	Settings.max_fps = 144
	Settings.apply_fps()
	_ok("Einstellungen: Max-FPS wird gesetzt", Engine.max_fps == 144 and Settings.FPS_CHOICES.has(0))
	Settings.max_fps = keep_fps
	Settings.apply_fps()


## Aufgaben auf der Uhr (J halten, 23.11.): Arm hebt die Uhr, Display zeigt die Checkliste, Liste über der Uhr
func _t_watch_log() -> void:
	var p := _player()
	var hands := p.hands
	_ok("Uhr-Aufgaben: Taste J belegt", InputMap.has_action("quest_log"))
	var hud := get_tree().get_first_node_in_group("hud") as Hud
	var lines := hud.watch_log_lines()
	var kinds := lines.map(func(l: Array) -> String: return String(l[1]))
	_ok("Uhr-Aufgaben: Hauptstory und HEUTE getrennt (%d Zeilen)" % lines.size(), kinds.has("head_story") and kinds.has("head_day")
			and kinds.find("head_story") < kinds.find("head_day"))
	hands.set_process(false)
	var rest := hands._left.position
	hands.log_raise = 1.0
	hands._left_out = 0.0
	hands._left.visible = true
	hands._pose_left(0.0)
	_ok("Uhr-Aufgaben: Arm hebt die Uhr, Display zeigt die Checkliste", hands._left.position.distance_to(rest) > 0.1
			and hands._checklist.visible and not hands._compass.visible)
	hud._update_watch_log(0.016)
	_ok("Uhr-Aufgaben: Liste erscheint über der Uhr", hud._watch_log != null and hud._watch_log.visible and hud._watch_log_box.get_child_count() >= 3)
	hands.log_raise = 0.0
	hands._pose_left(0.0)
	hud._update_watch_log(0.016)
	_ok("Uhr-Aufgaben: loslassen = Kompass zurück, Liste weg", hands._compass.visible and not hud._watch_log.visible)
	hands.set_process(true)


## Sucher am Haus (23.11.): Lichtstrahl durchs Fenster verletzt, Arme aus Wand/Boden/Decke, LED/Schlag vertreiben, nie tödlich
func _t_seeker_at_house() -> void:
	var p := _player()
	var keep := p.global_position
	var keep_h := p.health
	var keep_d := TimeManager.day
	TimeManager.set_time(keep_d, 23.0)
	# im Wohnzimmer, etwas hinter dem Südfenster
	p.global_position = Vector3(0.0, Cabin.FLOOR_Y + 0.05, Cabin.HALF_Z - 2.2)
	p.velocity = Vector3.ZERO
	p.health = 100.0
	await _frames(3)
	var sk := Seeker.spawn_for(_scene(), Vector3.ZERO)
	await _frames(2)
	sk.set_process(false)
	sk.global_position = Vector3(6, Terrain.height_at(6, 14), 14)
	var house := sk._house_check()
	_ok("Sucher: Spieler im Haus → er belagert das Haus", house and sk.state == Seeker.State.HOUSE and sk._house_window != null)
	var stand: Vector3 = sk._path[-1] if not sk._path.is_empty() else sk.global_position
	_ok("Sucher: stellt sich draußen vors Fenster (%s)" % stand, not Cabin.is_inside(stand + Vector3(0, 1, 0)) and not Cabin.blocks_ground(stand))
	# direkt vors Wohnzimmerfenster stellen und den Strahl auf den Spieler richten
	var win := _scene().get_node("Cabin/WindowLiving") as Node3D
	sk._house_window = win
	sk._house_out = Vector3(0, 0, 1)
	sk.global_position = Vector3(0.0, Terrain.height_at(0.0, Cabin.HALF_Z + 1.8), Cabin.HALF_Z + 1.8)
	sk._path.clear()
	sk._beam_lock = 1.0
	sk._beam_aim = p.global_position + Vector3(0, 1.0, 0)
	var h0 := p.health
	for i in 60:
		sk._house_tick(1.0 / 30.0)
		await get_tree().process_frame
	_ok("Sucher: Lichtstrahl durchs Fenster verletzt (%.0f → %.0f)" % [h0, p.health], p.health < h0)
	p.health = sk.cfg.min_health + 1.0
	for i in 90:
		sk._house_tick(1.0 / 30.0)
	_ok("Sucher: Strahl tötet nie (bleibt bei %.0f)" % p.health, p.health >= sk.cfg.min_health)
	p.health = 100.0
	sk._beam_on(false)
	# Arme: Wand, Boden, Decke im Haus
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var kinds := {}
	var made := 0
	for i in 20:
		var arm := SeekerArm.spawn(_scene(), p, sk.cfg, rng, i % 2 == 0)
		if arm:
			made += 1
			var k := "floor" if arm.normal.y > 0.7 else ("ceiling" if arm.normal.y < -0.7 else "wall")
			kinds[k] = true
			arm.queue_free()
	await _frames(2)
	_ok("Sucher-Arme: kommen aus Wand, Boden und Decke (%d, %s)" % [made, kinds.keys()], made >= 12 and kinds.size() == 3)
	# ein Arm greift zu: verletzt und zieht sich zurück
	var arm2 := SeekerArm.spawn(_scene(), p, sk.cfg, rng, false)
	var touched := false
	if arm2:
		arm2.global_position = p.global_position + Vector3(0.6, 0.0, 0.0)
		arm2.normal = Vector3.UP
		var hh := p.health
		for i in 150:
			await get_tree().process_frame
			if p.health < hh:
				touched = true
				break
		_ok("Sucher-Arm: erreicht dich und verletzt (%.0f → %.0f)" % [hh, p.health], touched)
		_ok("Sucher-Arm: zieht sich danach zurück", arm2._leaving)
	else:
		_ok("Sucher-Arm: Stelle gefunden", false)
	# Schlag vertreibt
	var arm3 := SeekerArm.spawn(_scene(), p, sk.cfg, rng, false)
	if arm3:
		await _frames(3)
		arm3.on_melee_hit("axe")
		_ok("Sucher-Arm: Schlag → zurück", arm3._leaving)
	# raus aus dem Haus: Belagerung endet, Arme verschwinden
	p.global_position = Vector3(0.0, Terrain.height_at(0.0, 25.0) + 0.1, 25.0)
	await _frames(2)
	sk._house_check()
	_ok("Sucher: Spieler draußen → keine Belagerung mehr", sk.state != Seeker.State.HOUSE)
	sk.queue_free()
	for a in get_tree().get_nodes_in_group("seeker_arm"):
		a.queue_free()
	p.global_position = keep
	p.health = keep_h
	TimeManager.set_time(keep_d, 10.0)
	await _frames(3)


## Bedrohung à la Resident Evil (Christian 23.11.): Angst, Gesundheit, Speichern am Bett, Verstecke lernen,
## Stille eskaliert, Druck, Tagesvorfälle
func _t_dread_2311() -> void:
	var p := _player()
	var keep_pos := p.global_position
	var keep_day := TimeManager.day
	var keep_h := TimeManager.hour
	# --- Angst
	p.fear.level = 0.0
	p.fear.spike = 0.0
	EventBus.fear_spike.emit(0.8)
	_ok("Angst: Schreck lässt sie hochspringen (%.2f)" % p.fear.level, p.fear.level >= 0.79)
	var quiet_noise := 1.0
	p.fear.level = 0.0
	quiet_noise = p.fear.noise_factor()
	p.fear.level = 1.0
	_ok("Angst: macht lauter, Atem verrät, Rennen kostet mehr", p.fear.noise_factor() > quiet_noise and p.fear.betrays_breath() and p.fear.sprint_drain() > 1.2)
	p.fear.spike = 0.0
	p.global_position = Vector3(0.0, Cabin.FLOOR_Y + 0.05, 0.0)
	TimeManager.set_time(keep_day, 12.0)
	for i in 90:
		p.fear.update(p, 0.2)
	_ok("Angst: klingt ohne Gefahr wieder ab (%.2f)" % p.fear.level, p.fear.level < 0.3)
	# Draußen nachts im Dunkeln: etwas Grundangst
	TimeManager.set_time(keep_day, 23.0)
	p.global_position = Creature._ground(Vector3(-12, 0, 30)) + Vector3(0, 0.05, 0)
	p.set_flashlight(false)
	await _frames(2)
	p.fear.level = 0.0
	for i in 20:
		p.fear.update(p, 0.2)
	_ok("Angst: nachts draußen im Dunkeln steigt sie (%.2f)" % p.fear.level, p.fear.level >= Fear.cfg().dark_outside * 0.9)
	p.fear.level = 0.0
	# --- Gesundheit: härtere Treffer, Bein
	p.health = 100.0
	Survival.leg_until = -1.0
	p.take_damage(34.0, p.global_position + Vector3(1, 1, 0), "creature")
	var hit := 100.0 - p.health
	_ok("Gesundheit: Treffer zählen mehr (%.0f statt 34)" % hit, hit > 40.0)
	p.health = 100.0
	p.take_damage(10.0, p.global_position + Vector3(1, 1, 0), "trap")
	_ok("Gesundheit: kein verletztes Bein mehr (Christian 25.11.)", not Survival.leg_hurt())
	_ok("Gesundheit: Schlaf heilt nur wenig (%.1f/Std.)" % Survival.cfg.sleep_heal_per_hour, Survival.cfg.sleep_heal_per_hour <= 5.0)
	p.health = 40.0
	var st := Survival.get_state()
	_ok("Gesundheit gehört zum Spielstand", absf(float(st.get("health", 0)) - 40.0) < 0.01)
	p.health = 100.0
	# --- Speichern am Bett
	GameState.take_snapshot()
	var snap_day := int(GameState._snapshot.get("day", -1))
	GameState._on_phase_changed(false)
	_ok("Speichern: der Morgen speichert nicht mehr von selbst", int(GameState._snapshot.get("day", -1)) == snap_day)
	TimeManager.set_time(keep_day, 8.0)
	GameState.bed_save()
	_ok("Speichern: Schlaf im Bett merkt sich den Stand (Tag %d %.1f)" % [GameState.bed_day, GameState.bed_hour], GameState.bed_day == keep_day and absf(GameState.bed_hour - 8.0) < 0.1)
	# --- Druck
	var keep_menace := ThreatDirector.menace
	ThreatDirector.menace = 0.2
	ThreatDirector.night_kind = "quiet"
	ThreatDirector._update_menace()
	var up := ThreatDirector.menace
	ThreatDirector.night_kind = "hunt"
	ThreatDirector._update_menace()
	_ok("Druck: steigt in ruhigen Nächten, fällt nach einem Angriff (%.2f → %.2f)" % [up, ThreatDirector.menace], up > 0.2 and ThreatDirector.menace < up)
	ThreatDirector.menace = keep_menace
	# --- Verstecke lernen
	var dr := ThreatDirector.dread
	var wd := _scene().get_node("Cabin/Wardrobe") as HideSpot
	TimeManager.set_time(maxi(keep_day, 6), 23.0)
	ThreatDirector.night_kind = "visit"
	wd.enter(p, true)
	await get_tree().create_timer(0.3).timeout
	_ok("Versteck: im Schrank versteckt", p.is_hidden())
	var keep_uses := ThreatDirector.hide_uses.duplicate()
	ThreatDirector.hide_uses["Wardrobe"] = 0
	dr.hidden_secs = 10.0
	var c0 := dr.hunt_chance(p)
	ThreatDirector.hide_uses["Wardrobe"] = 5
	dr.hidden_secs = 300.0
	var c1 := dr.hunt_chance(p)
	_ok("Versteck: oft benutzt und lange drin = sie kommt eher nachsehen (%.3f → %.3f)" % [c0, c1], c1 > c0 * 3.0 and c1 > 0.05)
	# Sie kommt, schnüffelt, rüttelt – mit Atem angehalten und neuem Versteck zieht sie eher ab
	var h := dr.start_hunt(p)
	_ok("Versteck: sie sucht das Versteck ab", h != null)
	if h:
		h.ccfg = h.ccfg.duplicate()
		h.ccfg.hide_walk_speed = 6.0
		h.ccfg.hide_sniff_time = Vector2(0.5, 0.5)
		h.uses = 50   # kennt das Versteck genau → reißt sicher auf
		h.tcfg = h.tcfg.duplicate()
		h.tcfg.hide_tear_max = 1.0
		h.breath_heard = 10.0
		var hp := p.health
		var waited := 0.0
		while waited < 15.0 and is_instance_valid(h) and not h.torn:
			await get_tree().create_timer(0.1).timeout
			waited += 0.1
		_ok("Versteck: ein bekanntes Versteck reißt sie auf (Tür offen, Schaden) nach %.1f s" % waited, is_instance_valid(h) and h.torn and wd.door_open and p.health < hp,
				"Schritt %s" % (str(h.step) if is_instance_valid(h) else "weg"))
		await get_tree().create_timer(1.6).timeout
		_ok("Versteck: danach ist sie weg", not is_instance_valid(HideHunt.current))
	ThreatDirector.hide_uses = keep_uses
	p.health = 100.0
	wd.set_door(false)   # aufgerissene Schranktür wieder zu (spätere Prüfungen)
	# --- Stille eskaliert
	p.global_position = Vector3(0.0, Cabin.FLOOR_Y + 0.05, 0.0)
	await _frames(2)
	dr.still_stage = -1
	dr.escalate("knock_door")
	_ok("Stille: Eskalationsstufen sind Ereignisse des ThreatDirectors", Array(ThreatDirector.config.still_steps).has("creature"))
	# --- Tagsüber
	TimeManager.set_time(maxi(keep_day, 6), 12.0)
	var kinds := {}
	for i in 60:
		kinds[dr.pick_day_kind(true, p)] = true
	_ok("Tag: Vorfälle im Haus (%s)" % [kinds.keys()], kinds.size() >= 3)
	_ok("Tag: Klopfen bei Tag geht", dr.day_incident("knock", p))
	# Aufräumen
	p.global_position = keep_pos
	TimeManager.set_time(keep_day, keep_h)
	p.health = 100.0


## Grafikstufe überschreibt die Einsparung des Retro-Filters nicht mehr (Christian 24.11.: 5120×1440, nur 75 FPS)
func _t_render_2411() -> void:
	var vp := get_viewport()
	var keep_q := Settings.quality
	var keep_look := Settings.look
	Settings.look = "retro"   # die Einsparung gilt nur im Retro-Stil
	Settings.quality = "high"
	Settings.apply()
	var rf := get_tree().get_first_node_in_group("retro_filter")
	var h := vp.get_visible_rect().size.y
	if rf and bool(rf.get("enabled")) and h > 0.0:
		var want := clampf(RetroFilter.VIRTUAL_HEIGHT * float(Settings.quality_values().get("retro_oversample", 1.5)) / h, 0.25, 1.0)
		_ok("Grafik: mit Retro-Filter rechnet die 3D-Welt nur so fein, wie der Filter zeigt (%.2f), ohne MSAA" % vp.scaling_3d_scale,
				absf(vp.scaling_3d_scale - want) < 0.01 and vp.msaa_3d == Viewport.MSAA_DISABLED)
	else:
		_ok("Grafik: Retro-Filter vorhanden", false)
	Settings.look = keep_look
	Settings.quality = keep_q
	Settings.apply()


## Verstecke (Christian 24.11.): sieben Stück, alle gleich – E hinein (mit Bewegung), E heraus, zu von Haus aus,
## drinnen versteckt, ein wenig bewegen, Uhrlicht; Ein- und Ausstieg frei. Dazu Dachfenster doppelt so breit.
func _t_hide_2411() -> void:
	var p := _player()
	var keep := p.global_position
	var want := ["Cabin/Wardrobe", "Shed/Locker", "Cabin/HideBehindChair", "Cabin/HideShower", "Cabin/HideUnderDesk",
			"Cabin/HideKidsCorner", "Cabin/HideAtticChest"]
	for path: String in want:
		var h := _scene().get_node_or_null(path) as HideSpot
		if h == null:
			_ok("Versteck %s vorhanden" % path, false)
			continue
		_ok("Versteck %s: von Haus aus zu (Duschvorhang offen)" % h.label, h.door_open == (h.style == "curtain"))
		# draußen: Ausstiegspunkt frei (Spieler passt hin)
		var out := h.front_point(h.exit_dist)
		var free := _capsule_free(out + Vector3(0, 0.05, 0), p)
		_ok("Versteck %s: Platz zum Herauskommen bei %s" % [h.label, str(out.snappedf(0.01))], free)
		p.global_position = out + Vector3(0, 0.05, 0)
		p.velocity = Vector3.ZERO
		await get_tree().create_timer(0.15).timeout
		h.interact(p)
		await get_tree().create_timer(0.3).timeout
		var mid := p.is_hidden()
		var waited := 0.0
		while waited < 3.0 and not h.settled:
			await get_tree().create_timer(0.1).timeout
			waited += 0.1
		_ok("Versteck %s: [E] hinein → versteckt (Bewegung %.1f s, vorher nicht versteckt)" % [h.label, waited + 0.3], h.settled and p.is_hidden() and not mid and not h.door_open)
		_ok("Versteck %s: Augenhöhe stimmt (%.2f)" % [h.label, p.head.position.y], absf(p.head.position.y - h.eye) < 0.12)
		# ein wenig bewegen: nie aus dem kleinen Raum hinaus
		p.hide_offset = Vector2(5.0, 5.0)
		await get_tree().physics_frame
		await get_tree().physics_frame
		var off := h.to_local(p.global_position) - h.anchor
		_ok("Versteck %s: drinnen nur ein wenig bewegen" % h.label, absf(off.x) <= h.move.x + 0.01 and absf(off.z) <= h.move.y + 0.01)
		p.hide_offset = Vector2.ZERO
		p.set_flashlight(true)
		_ok("Versteck %s: Uhrlicht geht, bleibt versteckt" % h.label, p.flashlight.visible and p.is_hidden())
		p.set_flashlight(false)
		# [E] heraus (über das, was der Spieler als Ziel hat – das Versteck selbst)
		await get_tree().physics_frame
		_ok("Versteck %s: Hinweis [E] Versteck verlassen" % h.label, p.current_interactable == h and h.get_prompt(p).contains("verlassen"))
		p.use_target(false)
		waited = 0.0
		while waited < 3.0 and h.occupied:
			await get_tree().create_timer(0.1).timeout
			waited += 0.1
		await get_tree().create_timer(0.5).timeout
		_ok("Versteck %s: [E] heraus → draußen, nicht versteckt, wieder zu" % h.label, not h.occupied and not p.is_hidden() and p.hidden_in == null and h.door_open == (h.style == "curtain") and p.global_position.distance_to(out) < 0.6,
				"drin %s versteckt %s Tür offen %s Abstand %.2f" % [h.occupied, p.is_hidden(), h.door_open, p.global_position.distance_to(out)])
	# Aufreißen wirft einen hinaus
	var wd := _scene().get_node("Cabin/Wardrobe") as HideSpot
	wd.enter(p, true)
	await get_tree().physics_frame
	wd.force_open()
	await get_tree().create_timer(0.8).timeout
	_ok("Versteck: aufgerissen = draußen und nicht mehr versteckt", not p.is_hidden() and p.hidden_in == null)
	wd.set_door(false)
	# Teleport aus dem Versteck heraus beendet das Verstecken
	wd.enter(p, true)
	await get_tree().physics_frame
	p.global_position = keep
	await get_tree().physics_frame
	await get_tree().physics_frame
	_ok("Versteck: woandershin versetzt = nicht mehr drin", p.hidden_in == null and p.global_position.distance_to(keep) < 0.5)
	var aw := _scene().get_node_or_null("Cabin/WindowAtticWest") as CabinWindow
	_ok("Dachfenster doppelt so breit (%.2f m)" % (aw.width if aw else 0.0), aw != null and absf(aw.width - 1.4) < 0.01)
	p.global_position = keep


## Passt der Spieler (Kapsel) an diese Stelle, ohne in Möbeln oder Wänden zu stecken?
func _capsule_free(feet: Vector3, p: Player) -> bool:
	var sh := CapsuleShape3D.new()
	sh.radius = 0.3
	sh.height = 1.6
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = sh
	q.transform = Transform3D(Basis(), feet + Vector3(0, 0.85, 0))
	q.exclude = [p.get_rid()]
	q.collide_with_areas = false
	return p.get_world_3d().direct_space_state.intersect_shape(q, 4).is_empty()


## Bayerischer Wald, Etappe 1 (Christian 24.11.): echte Namen, Ilse und Wendt auf Bairisch, Totenbretter der Familie.
func _t_bayerwald_2411() -> void:
	var names: Array = []
	for id: String in WorldMap.places():
		names.append(String(WorldMap.places()[id]["name"]))
	_ok("Bayerwald: Orte heißen echt (Lusenschutzhaus, Rachelsee, Siebensteinkopf, Finsterauer Filz)",
			names.has("Lusenschutzhaus") and names.has("Rachelsee") and names.has("Funkmast am Siebensteinkopf") \
			and names.has("Finsterauer Filz") and not names.has("Berghütte") and not names.has("Schwarzer See"), str(names))
	# keine alten Namen mehr in den Texten
	var old := ["Kahlen Kopf", "Kahler Kopf", "Schwarzen See", "Schwarzer See", "Berghütte", "Windwurf-Schneise", "Raststätte", "Autobahn"]
	var hits: Array = []
	for f: String in ["res://data/story/story.json", "res://data/research/research.json", "res://data/story/endings.json",
			"res://data/tasks/tasks.json", "res://data/world/map.json"]:
		var txt := FileAccess.get_file_as_string(f)
		for o: String in old:
			if txt.contains(o):
				hits.append("%s: %s" % [f.get_file(), o])
	_ok("Bayerwald: alte Ortsnamen aus den Texten verschwunden", hits.is_empty(), str(hits))
	# Ilse spricht Bairisch – auch in den Hinweisen über Funk
	var steps: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/story/story.json"))["steps"]
	var ilse := 0
	for s: Dictionary in steps:
		if s.has("hint_ilse"):
			ilse += 1
	_ok("Bayerwald: Ilses Funkhinweise auf Bairisch (%d)" % ilse, ilse >= 10)
	var rd: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/research/research.json"))
	var logbook := String(rd["notes"]["ilse_logbuch"]["text"])
	_ok("Bayerwald: Ilses Logbuch auf Bairisch", logbook.contains("koana") and logbook.contains("Siebensteinkopf"))
	# Totenbretter: am Weg, nicht im Garten, drei Bretter, Notiz zum Ansehen
	var tb := _scene().get_node_or_null("StoryProps/Totenbretter") as Node3D
	if tb == null:
		_ok("Totenbretter vorhanden", false)
		return
	var p2 := Vector2(tb.global_position.x, tb.global_position.z)
	var edge := WorldMap.trail_info(p2.x, p2.y).x
	var boards := 0
	for c in tb.get_children():
		if c.name.begins_with("Brett_"):
			boards += 1
	_ok("Totenbretter: drei Bretter am Wegrand des Gunthersteigs (%.1f m neben dem Weg)" % edge,
			boards == 3 and edge >= 0.9 and edge <= 2.6 and Terrain.yard_distance(p2.x, p2.y) >= 1.9 \
			and p2.distance_to(Vector2(5, -40)) < 12.0, "%s" % p2)
	var note_ok := false
	for c in tb.get_children():
		if c is ResearchNote and (c as ResearchNote).note_id == "totenbretter":
			note_ok = true
	_ok("Totenbretter: Notiz zum Ansehen", note_ok)
	var tree_d := INF
	for tr: Vector4 in Forest.trees:
		tree_d = minf(tree_d, Vector2(tr.x, tr.z).distance_to(p2) - tr.w)
	_ok("Totenbretter: kein Baumstamm im Weg (%.1f m)" % tree_d, tree_d >= 1.5)


## Holz und Steine im großen Wald (Christian 24.11.): liegende Stämme und Polter mit der Axt, Steinhaufen (am Wasser häufiger).
## Ihr Stand liegt in Supplies.wild, weil die Waldstücke entladen werden.
func _t_wild_wood_2411() -> void:
	var wf := _scene().get_node_or_null("WildForest") as WildForest
	var logs := 0
	var stones := 0
	var wet_stones := 0
	for c: Vector3 in [Vector3(300, 0, -300), Vector3(-400, 0, 200), Vector3(150, 0, 500), Vector3(-200, 0, -600), Vector3(0, 0, -450)]:
		wf.update_around(c, 0.0)
		await _frames(2)
		for n in wf.find_children("WildLog_*", "ResourceNode", true, false):
			logs += 1
		for n in wf.find_children("WildStones", "ResourceNode", true, false):
			stones += 1
			var a := (n as ResourceNode).anchor
			for k in 6:
				var q := Vector2(a.x, a.z) + Vector2.from_angle(TAU * k / 6.0) * 3.0
				if Terrain.water_level_at(q.x, q.y) > Terrain.height_at(q.x, q.y) + 0.05:
					wet_stones += 1
					break
	_ok("Großer Wald: liegende Stämme zum Holzhacken (%d)" % logs, logs >= 5)
	_ok("Großer Wald: Steinhaufen (%d, davon %d am Wasser)" % [stones, wet_stones], stones >= 3)
	var polter := (_scene().get_node("WorldTrails") as Node).find_children("PolterWood", "ResourceNode", true, false)
	_ok("Holzpolter an Fahrwegen geben Holz (%d)" % polter.size(), polter.size() >= 5 and (polter[0] as ResourceNode).tool == "axe")
	# Stand bleibt über das Entladen hinweg und wächst nach
	var key := "log_test_1"
	var full := Supplies.config.wild_log_wood
	Supplies.wild_store(key, 0, full)
	var rn := ResourceNode.new()
	rn.wild_key = key
	rn.max_amount = full
	rn.amount = full
	rn.regrow_per_day = Supplies.config.wild_log_regrow
	_scene().add_child(rn)
	_ok("Großer Wald: abgehackter Stamm bleibt leer, auch wenn das Stück neu geladen wird", rn.amount == 0)
	Supplies.wild[key] = [0, TimeManager.day - 2]
	_ok("Großer Wald: Stamm wächst über die Tage nach", Supplies.wild_amount(key, full, Supplies.config.wild_log_regrow) == mini(full, 2 * Supplies.config.wild_log_regrow))
	_ok("Großer Wald: Stand steht im Spielstand", (Supplies.get_state()["wild"] as Dictionary).has(key))
	_ok("Großer Wald: Stellen gehören nicht zur Welt-Liste (keine Altlasten im Spielstand)", not rn.is_in_group("persistent"))
	Supplies.wild.erase(key)
	rn.queue_free()
	wf.update_around(_player().global_position, 0.0)


## Etappe 2 (Christian 24.11.): Spätherbst mit erstem Schnee – Kalender, erster Schnee, Schneedecke, Raureif, Kälte,
## Sichtbarkeit auf Schnee, Knirschen, Spuren im Schnee.
func _t_season_2411() -> void:
	var p := _player()
	var keep_pos := p.global_position
	var keep_day := TimeManager.day
	var keep_hour := TimeManager.hour
	var keep_state := WorldState.get_state()
	_ok("Kalender: Tag 1 = %s, Tag 17 = %s" % [TimeManager.date_text(1), TimeManager.date_text(17)],
			TimeManager.date_text(1) == "Mo 16. Nov." and TimeManager.date_text(17) == "Mi 2. Dez.")
	# vor dem ersten Schnee schneit es nie
	WorldState.first_snow_done = false
	WorldState.snow = 0.0
	TimeManager.set_time(2, 12.0)
	var snows := 0
	for i in 200:
		WorldState._next_weather(TimeManager.get_total_hours())
		if WorldState.weather == "snow":
			snows += 1
	_ok("Wetter: vor dem ersten Schnee kein Schneefall", snows == 0)
	# erster Schnee am Abend von Tag 3
	WorldState.set_weather("cloudy", 50.0)
	TimeManager.set_time(WorldState.config.first_snow_day, WorldState.config.first_snow_hour + 0.1)
	WorldState._wet_last = TimeManager.get_total_hours()
	WorldState._process(0.0)
	_ok("Erster Schnee kommt sicher am Abend von Tag %d" % WorldState.config.first_snow_day, WorldState.first_snow_done and WorldState.weather == "snow")
	# danach kann es schneien
	snows = 0
	TimeManager.set_time(WorldState.config.first_snow_day + 6, 12.0)
	for i in 300:
		WorldState._next_weather(TimeManager.get_total_hours())
		if WorldState.weather == "snow":
			snows += 1
	_ok("Wetter: im Spätherbst schneit es öfter (%d von 300)" % snows, snows >= 30)
	# Schneedecke wächst, Regen taut
	WorldState.set_weather("snow", 50.0)
	WorldState.snow = 0.0
	var now := TimeManager.get_total_hours()
	WorldState._update_snow(now, 3.0)
	var after_snow := WorldState.snow
	WorldState.set_weather("rain", 50.0)
	WorldState._update_snow(now, 1.0)
	_ok("Schneedecke: wächst beim Schneien (%.2f), taut im Regen (%.2f)" % [after_snow, WorldState.snow],
			after_snow > 0.5 and WorldState.snow < after_snow - 0.2)
	# Raureif in klarer Nacht, taut am Vormittag
	WorldState.set_weather("clear", 50.0)
	WorldState.frost = 0.0
	TimeManager.set_time(TimeManager.day, 3.0)
	WorldState._update_snow(TimeManager.get_total_hours(), 3.0)
	var rime := WorldState.frost
	TimeManager.set_time(TimeManager.day, 10.0)
	WorldState._update_snow(TimeManager.get_total_hours(), 2.0)
	_ok("Raureif: bildet sich in klarer Nacht (%.2f), taut am Vormittag (%.2f)" % [rime, WorldState.frost], rime > 0.4 and WorldState.frost < rime - 0.4)
	# Schnee auf Dächern/Felsen: zweiter Durchgang hängt nur bei Schnee an
	WorldState.snow = 0.8
	SnowCover.update(0.8, 0.0)
	_ok("Schnee auf Dächern und Felsen: %d Materialien, Durchgang an" % SnowCover.count(), SnowCover.count() >= 5 and SnowCover.active)
	SnowCover.update(0.0, 0.0)
	_ok("Ohne Schnee kostet der Durchgang nichts (abgehängt)", not SnowCover.active)
	# Kälte: Schneetreiben kühlt schneller aus
	TimeManager.set_time(TimeManager.day, 14.0)
	p.global_position = Vector3(-3.0, Terrain.height_at(-3.0, 26.0) + 0.1, 26.0)
	await _frames(2)
	WorldState.snow = 0.0
	WorldState.set_weather("clear", 50.0)
	var loss_clear := Survival.warmth_rate(p)
	WorldState.snow = 0.9
	WorldState.set_weather("snow", 50.0)
	var loss_snow := Survival.warmth_rate(p)
	_ok("Kälte: im Schneetreiben kühlt man schneller aus (%.1f → %.1f pro Std.)" % [loss_clear, loss_snow], loss_snow < loss_clear - 1.0)
	# Knirschen und Sichtbarkeit
	_ok("Schritte: draußen auf Schnee knirscht es", Footsteps.surface_at(p.global_position) == "snow")
	TimeManager.set_time(TimeManager.day, 1.0)
	WorldState.set_weather("clear", 50.0)
	WorldState.snow = 0.0
	var vis0 := Stealth.visibility(p)
	WorldState.snow = 1.0
	var vis1 := Stealth.visibility(p)
	_ok("Nachts auf Schnee sieht man dich eher (%.2f → %.2f)" % [vis0, vis1], vis1 > vis0 + 0.02)
	# Spuren: eigene Schritte hinterlassen Abdrücke, Neuschnee deckt sie zu
	var st := SnowTracks.current
	_ok("Spuren im Schnee: Knoten vorhanden", st != null)
	if st:
		var before := st.visible_count(st.boots())
		for k in 6:
			p.stepped.emit("walk", p.global_position + Vector3(0, 0, -0.8 * k))
		await _frames(1)
		var after := st.visible_count(st.boots())
		_ok("Spuren: eigene Schritte im Schnee (%d → %d)" % [before, after], after >= before + 5)
		WorldState.snowfall_total += WorldState.config.track_cover_snow * 1.2
		st._fade_t = 0.0
		st._process(0.0)
		_ok("Spuren: Neuschnee deckt sie zu", st.visible_count(st.boots()) == 0)
		# Wesen hinterlassen Krallenabdrücke
		var c0 := st.visible_count(st.claws())
		var dummy := Node3D.new()
		dummy.add_to_group("mauler")
		_scene().add_child(dummy)
		for k in 8:
			dummy.global_position = Vector3(-10.0, Terrain.height_at(-10.0, 30.0 + k * 1.3), 30.0 + k * 1.3)
			st._process(0.0)
		_ok("Spuren: Wesen hinterlassen Krallenabdrücke", st.visible_count(st.claws()) > c0 + 3)
		dummy.queue_free()
	# aufräumen
	WorldState.set_state(keep_state)
	TimeManager.set_time(keep_day, keep_hour)
	p.global_position = keep_pos
	await _frames(2)


## Wintergemüse (Christian 24.11.): Feldsalat + Winterspinat im Folientunnel, Karotten/Kartoffeln als Kellervorrat.
func _t_greens_2411() -> void:
	var scene := _scene()
	for id: String in ["lambs_lettuce", "spinach", "seeds_lettuce", "seeds_spinach"]:
		_ok("Wintergemüse: %s mit eigenem Bild" % id, not DataDB.item(id).is_empty() and ResourceLoader.exists("res://assets/icons/items/%s.png" % id))
	var img := (load("res://assets/icons/items/spinach.png") as Texture2D).get_image()
	_ok("Wintergemüse: Bild mit durchsichtigem Hintergrund", img.get_pixel(2, 2).a < 0.1 and img.get_pixel(128, 128).a > 0.9)
	_ok("Wintergemüse: Samen liegen im Schuppen", scene.get_node_or_null("SupplyProps/SeedsLettuce") is ItemPickup \
			and scene.get_node_or_null("SupplyProps/SeedsSpinach") is ItemPickup and scene.get_node_or_null("SupplyProps/SeedPotatoes") == null)
	var pot := scene.get_node_or_null("Cabin/CellarPotatoes") as ItemPickup
	var car := scene.get_node_or_null("Cabin/CellarCarrots") as ItemPickup
	_ok("Kellervorrat: Kartoffeln und Karotten", pot != null and car != null and pot.item_id == "potato" and car.item_id == "carrot")
	# säen, wachsen lassen, ernten
	var keep: Array = Supplies.beds.duplicate(true)
	Supplies.beds[2] = Supplies._empty_bed()
	Inventory.add("seeds_spinach", 1)
	_ok("Winterspinat säen", Supplies.plant(2, "seeds_spinach") and String(Supplies.beds[2]["crop"]) == "spinach")
	Supplies.beds[2]["growth"] = float(Supplies.config.crops["spinach"]["days"])
	(scene.get_node("Garden/GardenBed3") as GardenBed).refresh()
	var before := Inventory.count("spinach")
	Supplies.harvest(2)
	_ok("Winterspinat ernten (%d)" % (Inventory.count("spinach") - before), Inventory.count("spinach") - before >= 3)
	_ok("Folientunnel über dem Beet", scene.get_node_or_null("Garden/GardenBed3/Tunnel/Foil") != null)
	for m: String in ["lambs_lettuce", "spinach"]:
		var n := Node3D.new()
		var it := HandItems.build(n, m)
		_ok("Handmodell %s" % m, it.get_child_count() >= 6)
		n.free()
	Supplies.beds = keep
	scene.get_tree().call_group("garden_bed", "refresh")


## Etappe 3 (Christian 24.11.): Bayerwald-Landschaft – mehr Fichten, Totholz, Granit-Blockmeere, Latschen im Filz, Schachten.
func _t_landscape_2411() -> void:
	var spruce := 0
	for i in 1000:
		if TreeKit.pick_kind((i + 0.5) / 1000.0, 50.0, 0.0, 0.0) == "spruce":
			spruce += 1
	_ok("Landschaft: Fichte ist der Hauptbaum (%d %%)" % (spruce / 10), spruce >= 550)
	_ok("Landschaft: Totholz am Totholzhang (%.2f)" % WorldMap.deadwood_at(262, -282).x, WorldMap.deadwood_at(262, -282).x > 0.5)
	_ok("Landschaft: Blockmeer am Lusen", WorldMap.blockfield_at(-1010, -930).x > 0.8)
	_ok("Landschaft: zwei Schachten, baumfrei", WorldMap.schachten().size() == 2 and WorldMap.tree_density(650, -760, 60.0) <= 0.0)
	var wf := _scene().get_node("WildForest") as WildForest
	var kinds := {}
	for pos: Vector2 in [Vector2(360, -282), Vector2(262, -380), Vector2(-680, 80), Vector2(-600, 0)]:
		for t: Dictionary in wf._trees(Vector2i(int(floorf(pos.x / WildForest.CHUNK)), int(floorf(pos.y / WildForest.CHUNK)))):
			kinds[t["kind"]] = int(kinds.get(t["kind"], 0)) + 1
	_ok("Landschaft: tote Fichten am Totholzhang (%d)" % int(kinds.get("snag", 0)), int(kinds.get("snag", 0)) >= 8)
	_ok("Landschaft: Spirken im Filz (%d)" % int(kinds.get("bog_pine", 0)), int(kinds.get("bog_pine", 0)) >= 3)
	var hute := 0
	for s: Dictionary in WorldMap.schachten():
		var sp: Vector2 = s["pos"]
		var sr: float = s["r"]
		var seen := {}
		for dx in [-1, 0, 1]:
			for dz in [-1, 0, 1]:
				var key := Vector2i(int(floorf((sp.x + dx * sr) / WildForest.CHUNK)), int(floorf((sp.y + dz * sr) / WildForest.CHUNK)))
				if seen.has(key):
					continue
				seen[key] = true
				for t: Dictionary in wf._trees(key):
					if t["kind"] == "hute":
						hute += 1
	_ok("Landschaft: alte Hutebuchen auf den Schachten (%d)" % hute, hute >= 4)
	_ok("Landschaft: Schild am Hochschachten", _scene().get_node_or_null("WorldTrails/Schachten_hochschachten") != null)
	# Blockmeer: deutlich mehr Felsen als im normalen Wald; Latschen im Filz zum Verstecken
	var rocks_block := _rock_count(wf, Vector3(-1000, 0, -920))
	var rocks_norm := _rock_count(wf, Vector3(-300, 0, 400))
	_ok("Landschaft: Blockmeer voller Granit (%d gegen %d Felsen)" % [rocks_block, rocks_norm], rocks_block > rocks_norm * 2 and rocks_block >= 30)
	var bkey := Vector2i(int(floorf(-640.0 / WildForest.CHUNK)), int(floorf(40.0 / WildForest.CHUNK)))
	var gp := wf._ground_start(bkey)
	wf._ground_scatter(bkey, gp, -1)
	var latschen := 0
	for c: Color in gp.bush_cols:
		if c.g < 0.4 and c.r < 0.3:
			latschen += 1
	gp.body.free()
	_ok("Landschaft: Latschen im Filz bieten Deckung (%d Latschen, %d Verstecke)" % [latschen, gp.cover.size()], latschen >= 60 and latschen <= 400 and gp.cover.size() >= 40)
	wf.update_around(_player().global_position, 0.0)


func _rock_count(wf: WildForest, at: Vector3) -> int:
	wf.update_around(at, 0.0)
	var key := Vector2i(int(floorf(at.x / WildForest.CHUNK)), int(floorf(at.z / WildForest.CHUNK)))
	var root := wf.get_node_or_null("W_%d_%d_2" % [key.x, key.y])
	if root == null:
		return -1
	var mm := root.get_node_or_null("Rocks") as MultiMeshInstance3D
	return mm.multimesh.instance_count if mm else 0


## Etappe 4 (Christian 24.11.): Grenzübergang Bučina, Radarkuppeln am Rachel, Reschbachklause, Stollen im Granitbruch,
## Glashütte im versunkenen Dorf.
func _t_places_2411() -> void:
	var places := _scene().get_node("Places")
	var g := places.get_node_or_null("grenze")
	_ok("Grenzübergang: Zollhaus, Schranke, Wachturm, Dienstbuch",
			g != null and g.get_node_or_null("Zollhaus") != null and g.get_node_or_null("Barrier") != null and g.get_node_or_null("Watchtower") != null \
			and g.find_children("*", "ResearchNote", true, false).size() >= 1)
	var gp: Vector2 = WorldMap.places()["grenze"]["pos"]
	_ok("Grenzübergang: Grenzsteig führt hin (%.1f m)" % WorldMap.trail_info(gp.x - 12.0, gp.y + 5.0).x, WorldMap.trail_info(gp.x - 12.0, gp.y + 5.0).x < 4.0)
	var w := places.get_node_or_null("wetterstation")
	_ok("Radarkuppeln an der Wetterstation", w != null and w.get_node_or_null("Radome_0") != null and w.get_node_or_null("Radome_1") != null)
	var k := places.get_node_or_null("klause")
	_ok("Reschbachklause: Damm mit Klaustor und Infotafel", k != null and k.get_node_or_null("KlausTor") != null and k.find_children("*", "ResearchNote", true, false).size() >= 1)
	var kp: Vector2 = WorldMap.places()["klause"]["pos"]
	var up := Vector2(kp.x, kp.y - 18.0)
	_ok("Reschbachklause: Klausweiher dahinter", Terrain.water_level_at(up.x, up.y) > Terrain.height_at(up.x, up.y) + 0.3)
	_ok("Reschbachklause: Weg zum Damm", WorldMap.trail_info(kp.x - 8.0, kp.y).x < 3.0)
	# Stollen: Boden begehbar, Gelände darunter, Decke darüber
	var s := places.get_node_or_null("steinbruch/Stollen") as Node3D
	_ok("Stollen im Granitbruch vorhanden", s != null)
	if s:
		var inside := s.global_position + Vector3(8.0, 1.0, 0.0)
		var ground_h := Terrain.height_at(inside.x, inside.z)
		var space := (s as Node3D).get_world_3d().direct_space_state
		var q := PhysicsRayQueryParameters3D.create(inside, inside + Vector3(0, -3, 0))
		var hit := space.intersect_ray(q)
		var q2 := PhysicsRayQueryParameters3D.create(inside, inside + Vector3(0, 4, 0))
		var hit2 := space.intersect_ray(q2)
		var ent := s.global_position + Vector3(-2.5, 0.0, 0.0)
		_ok("Stollen: Boden trägt, Gelände liegt darunter (Boden %.2f, Gelände %.2f)" % [s.global_position.y, ground_h],
				not hit.is_empty() and ground_h < s.global_position.y + 0.05)
		_ok("Stollen: Decke über dem Kopf", not hit2.is_empty() and float((hit2["position"] as Vector3).y) < inside.y + 2.0)
		_ok("Stollen: Eingang ebenerdig vom Bruch aus (%.2f m Stufe)" % absf(Terrain.height_at(ent.x, ent.z) - s.global_position.y),
				absf(Terrain.height_at(ent.x, ent.z) - s.global_position.y) < 0.6)
		_ok("Stollen: Notizen (Tafel + Zettel)", s.find_children("*", "ResearchNote", true, false).size() >= 2)
	var d := places.get_node_or_null("dorf/Glashuette")
	_ok("Glashütte im versunkenen Dorf", d != null and d.find_children("*", "ResearchNote", true, false).size() >= 1)
	_ok("Dorf heißt jetzt Altenreuth", String(WorldMap.places()["dorf"]["name"]).begins_with("Altenreuth"))


## Etappe 5 (Christian 24.11.): Waldlerhaus – Kachelofen mit Speicherwärme, Herrgottswinkel, Drudenfuß, Gred
func _t_waldler_2411() -> void:
	var cabin := _scene().get_node("Cabin")
	var oven := cabin.get_node_or_null("Kachelofen")
	_ok("Kachelofen gebaut (%d Teile)" % (oven.get_child_count() if oven else 0), oven != null and oven.get_node_or_null("Tiles/Merged") != null and (oven.get_node("Tiles/Merged") as MeshInstance3D).mesh.get_surface_count() >= 5)
	_ok("Kachelofen: Ofenbank zum Draufsetzen", oven != null and oven.get_node_or_null("Ofenbank") != null)
	var fp := cabin.get_node("Fireplace") as Fireplace
	var keep := fp.burn_until
	var now := TimeManager.get_total_hours()
	fp.burn_until = now - 2.0
	_ok("Kachelofen: 2 Std. nach dem Erlöschen heizen die Kacheln noch", fp.heats_cabin() and fp.stored_heat() > 0.0)
	_ok("Kachelofen: direkt davor noch etwas warm", fp.heat_at(fp.global_position + Vector3(0.9, 0.5, 0)) > 0.0)
	fp.burn_until = now - 6.0
	_ok("Kachelofen: nach 6 Std. ist er kalt", not fp.heats_cabin())
	fp.burn_until = keep
	# vom Schürloch aus erreicht man das Feuer (kein fester Körper davor)
	var space := (cabin as Node3D).get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(Vector3(-4.4, Cabin.FLOOR_Y + 0.45, 1.75), Vector3(-5.6, Cabin.FLOOR_Y + 0.45, 1.75))
	q.collide_with_areas = true
	var hit := space.intersect_ray(q)
	var target: Node = hit.get("collider") if not hit.is_empty() else null
	_ok("Kachelofen: Feuer durchs Schürloch anvisierbar", target != null and target.get_parent() == fp)
	_ok("Herrgottswinkel mit Gedanken", cabin.get_node_or_null("Herrgottswinkel") != null and cabin.get_node_or_null("HerrgottswinkelLook") != null)
	_ok("Drudenfuß über der Tür und an Bens Bett", cabin.get_node_or_null("Drudenfuss") != null and cabin.find_child("DrudenfussBen", true, false) != null)
	var gred := cabin.get_node_or_null("Gred")
	_ok("Gred aus Granitplatten (ein Netz)", gred != null and gred.get_node_or_null("Merged") != null)
	_ok("Gred: Schritte klingen nach Stein", Footsteps.surface_at(Vector3(-2.0, Cabin.FLOOR_Y + 0.05, 5.6)) == "stone")


## Etappe 6 (Christian 24.11.): Klänge des Bayerischen Waldes – Glocken, Käuze, Hirsch, Raben, Specht, Rauhnacht
func _t_sounds_2411() -> void:
	var fv := _scene().get_tree().get_first_node_in_group("forest_voices") as ForestVoices
	_ok("ForestVoices läuft", fv != null)
	if fv == null:
		return
	var ids := ["church_bell", "sunken_bell", "owl_kuwitt", "owl_boreal", "deer_bark", "crow", "woodpecker", "wild_hunt"]
	var ok_all := true
	for id: String in ids:
		var st := SoundBank.get_sound(id)
		if st == null or st.get_length() < 0.3:
			ok_all = false
	_ok("Alle neuen Klänge vorhanden (Aufnahme oder Ersatz)", ok_all)
	_ok("Rauhnächte: 21.12. bis 5.1. (Tag 36 ja, 35 nein, 40 ja, 51 ja, 52 nein)",
			ForestVoices.is_rauhnacht(36) and not ForestVoices.is_rauhnacht(35) and ForestVoices.is_rauhnacht(40) \
			and ForestVoices.is_rauhnacht(51) and not ForestVoices.is_rauhnacht(52) and not ForestVoices.is_rauhnacht(1))
	var keep_day := TimeManager.day
	var keep_hour := TimeManager.hour
	var bells0 := int(fv.played.get("church_bell", 0))
	fv._bells_done.clear()   # frühere Prüfungen können den Tag schon auf Mittag gestellt haben
	TimeManager.set_time(keep_day, 12.05)
	for i in 30:
		await _scene().get_tree().process_frame
	await _scene().get_tree().create_timer(0.4).timeout
	_ok("Mittagsläuten um 12 Uhr", int(fv.played.get("church_bell", 0)) > bells0)
	ForestVoices.omen(_scene(), "sunken_bell")
	ForestVoices.omen(_scene(), "wild_hunt")
	await _scene().get_tree().create_timer(0.3).timeout
	_ok("Vorkommnisse: versunkene Glocke und Wilde Jagd", int(fv.played.get("sunken_bell", 0)) > 0 and int(fv.played.get("wild_hunt", 0)) > 0)
	var hunts_r := 0
	var hunts_n := 0
	for i in 300:
		if ThreatDirector._pick_omen(40) == "wild_hunt":
			hunts_r += 1
		if ThreatDirector._pick_omen(10) == "wild_hunt" and WorldState.weather != "storm":
			hunts_n += 1
	ThreatDirector._drawing_planned = false
	_ok("Wilde Jagd nur in Rauhnächten (%d) / sonst nicht (%d)" % [hunts_r, hunts_n], hunts_r > 0 and hunts_n == 0)
	TimeManager.set_time(keep_day, 22.0)
	for i in 120:
		await _scene().get_tree().process_frame
	var na := _scene().get_node_or_null("NatureAmbience") as NatureAmbience
	_ok("Spätherbst: keine Grillen nachts (%.0f dB)" % na._crickets.volume_db, na._crickets.volume_db < -60.0)
	TimeManager.set_time(keep_day, keep_hour)


## Christians Liste 25.11.: Wegweiser zeigen zum Ziel, Kapelle, Hütte, Truhe
func _t_fixes_2511() -> void:
	var trails := _scene().find_child("WorldTrails", true, false)
	var bad: Array[String] = []
	var arms := 0
	if trails:
		for sign in trails.get_children():
			if not String(sign.name).begins_with("Sign_"):
				continue
			for arm in sign.get_children():
				if not (arm is Node3D) or arm.get_child_count() == 0:
					continue
				var lab := arm.get_child(arm.get_child_count() - 1) as Label3D
				if lab == null:
					continue
				arms += 1
				var tip: Vector3 = (arm as Node3D).global_transform * Vector3(-1.2, 0, 0)
				var base: Vector3 = (arm as Node3D).global_position
				var pointing := Vector2(tip.x - base.x, tip.z - base.z).normalized()
				# Ziel aus dem Schildtext suchen
				var target := Vector2.INF
				for id in WorldMap.places():
					var pl: Dictionary = WorldMap.places()[id]
					if lab.text.begins_with(String(pl.get("sign", pl["name"])) + "  "):
						target = WorldMap.place_pos(id)
				if target == Vector2.INF:
					continue
				var want := (target - Vector2(base.x, base.z)).normalized()
				if pointing.dot(want) < 0.95:
					bad.append("%s→%s (%.2f)" % [sign.name, lab.text, pointing.dot(want)])
	_ok("Wegweiser: alle %d Arme zeigen zum Ziel %s" % [arms, str(bad.slice(0, 6))], arms > 10 and bad.is_empty())
	# Durchgang zwischen Kachelofen/Ofenbank und Schaukelstuhl: der Spieler passt durch
	var shape := CapsuleShape3D.new()
	shape.radius = Player.RADIUS
	shape.height = 1.7
	var space := (_scene() as Node3D).get_world_3d().direct_space_state
	var stuck: Array[float] = []
	var z := 3.1
	while z <= 3.9:
		var qp := PhysicsShapeQueryParameters3D.new()
		qp.shape = shape
		qp.transform = Transform3D(Basis.IDENTITY, Vector3(-4.82, Cabin.FLOOR_Y + 0.9, z))
		if not space.intersect_shape(qp, 1).is_empty():
			stuck.append(z)
		z += 0.2
	_ok("Durchgang Kachelofen ↔ Schaukelstuhl frei %s" % str(stuck), stuck.is_empty())
	var cabin := _scene().get_node("Cabin")
	var sw := cabin.get_node_or_null("Switch_workshop") as Node3D
	_ok("Werkstatt: Lichtschalter nördlich der Tür (nicht am Bretterregal)", sw != null and sw.position.z < 1.0)


## Christians zweite Liste 25.11.: Dosen/Flaschen nicht ineinander, Kamera 3 in der Speis, Speichern bei jedem Schlaf + morgens.
func _t_fixes_2511b() -> void:
	var sp := _scene().find_child("SupplyProps", true, false)
	var bot := sp.get_node_or_null("EmptyBottles") as ItemPickup if sp else null
	var cans := sp.get_node_or_null("KitchenCans") as ItemPickup if sp else null
	var gap := 0.0
	if bot and cans:
		gap = absf(cans.collider_offset.x - bot.collider_offset.x) - (bot.collider_size.x + cans.collider_size.x) * 0.5
	_ok("Küche: Flaschen und Dosen stehen nebeneinander (Abstand %.2f m)" % gap, bot != null and cans != null and gap >= 0.0)
	var cam3 := sp.get_node_or_null("Camera3Box") as ItemPickup if sp else null
	var c3 := cam3.collider_offset if cam3 else Vector3.ZERO
	_ok("Kamera 3 liegt in der Speis auf der Kiste (%.2f, %.2f, %.2f)" % [c3.x, c3.y, c3.z],
			cam3 != null and c3.x > -1.0 and c3.x < 2.0 and c3.z > -4.5 and c3.z < -1.0 and c3.y > Cabin.FLOOR_Y + 0.75)
	# Sitzen/Liegen: gespeichert wird die Stelle, an der man danach steht
	var p := _player()
	var before := p.global_position
	p.set_meta("stand_from", before + Vector3(0.5, 0, 0))
	var st := p.get_state()
	p.remove_meta("stand_from")
	_ok("Speichern im Sitzen/Liegen nimmt die Stelle vor dem Bett/Sitz", (st["position"] as Vector3).distance_to(before + Vector3(0.5, 0, 0)) < 0.01)
	# Morgen und Schlaf speichern (ohne Platz: nur der Schnappschuss)
	var keep_day := TimeManager.day
	GameState.bed_day = -5
	GameState._on_phase_changed(false)
	await get_tree().process_frame
	var morning_ok := GameState.bed_day == keep_day
	GameState.bed_day = -5
	GameState._on_slept()
	_ok("Speichern: jeden Morgen und nach jedem Schlaf (Bett/Zelt)", morning_ok and GameState.bed_day == keep_day)


## Christian 25.11.: Bauen aus der Hand statt Baumodus (B), R halten = abbauen, Bretter in der Hand = Fenster zunageln.
func _t_build_hand_2511() -> void:
	var bc := _scene().get_node("BuildController") as BuildController
	var p := _player()
	_ok("Bauen: Taste B gibt es nicht mehr", not InputMap.has_action("build"))
	Inventory.add("fence_panel", 2)
	var slot := Inventory.slot_of("fence_panel")
	if slot < 0:
		slot = 7   # Leiste war voll: auf Platz 8 legen (wie „In die Hand“ im Inventar)
		Inventory.set_slot(slot, "fence_panel")
	_ok("Bauen: Zaun liegt auf der Schnellleiste", Inventory.slot_of("fence_panel") >= 0)
	var old_sel := Inventory.selected
	Inventory.select(slot)
	await _frames(3)
	_ok("Bauen: Zaun anwählen = Vorschau", bc.active and bc.type == "fence_panel" and bc._preview != null)
	_ok("Bauen: rechte Hand frei, Hammer links", p.hands._wanted_right() == "")
	var rot := bc._rot
	bc.tick_r(0.1, true, p)
	bc.tick_r(0.0, false, p)
	_ok("Bauen: R tippen dreht", absf(bc._rot - rot - PI * 0.25) < 0.01)
	# Aufstellen an einer freien Stelle im Garten
	bc._pos = Vector3(12.0, Terrain.height_at(12.0, -12.0), -12.0)
	bc._valid = true
	var before := Builder.records.size()
	bc._place()
	await _frames(2)
	_ok("Bauen: Linksklick stellt auf", Builder.records.size() == before + 1)
	# Abbauen: R halten auf dem Zaun
	var st: Structure = null
	var uid := int(Builder.records[Builder.records.size() - 1]["uid"])
	for s in get_tree().get_nodes_in_group("structure"):
		if not (s as Structure).preview and (s as Structure).uid == uid:
			st = s
	var had := Inventory.count("fence_panel")
	if st:
		p.current_interactable = st
		_ok("Abbauen: Hinweis R halten", String(st.get_secondary_prompt(p)).contains("R halten") and BuildController.can_dismantle(st))
		bc.tick_r(0.1, true, p)
		bc.tick_r(0.0, false, p)
		_ok("Abbauen: kurz tippen baut nicht ab", is_instance_valid(st) and not st.is_queued_for_deletion())
		for i in 12:
			bc.tick_r(0.1, true, p)
		bc.tick_r(0.0, false, p)
		await _frames(2)
		_ok("Abbauen: R halten baut ab, Teil zurück", not is_instance_valid(st) and Inventory.count("fence_panel") == had + 1)
		p.current_interactable = null
	else:
		_ok("Abbauen: Zaun gefunden", false)
	# Anderen Platz wählen = Bauen aus
	var other := slot
	for k in Inventory.SLOTS:
		var hid: String = Inventory.hotbar[k]
		if hid == "" or not BuildController.is_build_item(hid):
			other = k
			break
	Inventory.select(other)
	await _frames(2)
	_ok("Bauen: anderer Platz = Bauen aus", not bc.active, "Leiste %s, gewählt %d, Typ %s" % [Inventory.hotbar, other, bc.type])
	# Bretter in der Hand: Fenster zunageln (kostet Nägel)
	if not Research.blueprints.has("bp_secure"):
		Research.blueprints.append("bp_secure")
	var win: CabinWindow = null
	for w in get_tree().get_nodes_in_group("entry_point"):
		if w is CabinWindow and (w as CabinWindow).barricade <= 0.0:
			win = w
	Inventory.add("planks", 4)
	Inventory.add("nails", 8)
	var ps := Inventory.slot_of("planks")
	if ps < 0:
		ps = 8
		Inventory.set_slot(ps, "planks")
	Inventory.select(ps)
	await _frames(2)
	_ok("Bretter: anwählen = Bauen mit Brettern", bc.active and bc.type == "planks", "Leiste %s, gewählt %d, Typ %s %s" % [Inventory.hotbar, Inventory.selected, bc.type, bc.active])
	if win:
		p.current_interactable = win
		var planks := Inventory.count("planks")
		var nails := Inventory.count("nails")
		_ok("Bretter: Fenster zeigt Hinweis, R nicht mehr", win.board_prompt() != "" and win.get_secondary_prompt(p) == "")
		bc._board_up(p)
		_ok("Bretter: Linksklick nagelt zu (2 Bretter, 4 Nägel)", win.barricade > 0.0 and Inventory.count("planks") == planks - 2 and Inventory.count("nails") == nails - 4)
		win.barricade = 0.0
		win.call("_update_visuals")
		p.current_interactable = null
	Inventory.remove("planks", Inventory.count("planks"))
	Inventory.remove("fence_panel", Inventory.count("fence_panel"))
	Inventory.select(old_sel)
	await _frames(2)
	_ok("Bretter weg = Bauen aus", not bc.active)
	# W-17: Gedanke beim Tragen und Markierung auf der Karte
	Tasks.flags.erase("w17_hint")
	var loc := _scene().find_child("W17Locator", true, false) as W17Locator
	if loc:
		loc._carried_for = 10.0
		loc._explain(0.5)
		loc._mark_site("absturz")
	_ok("W-17: erklärt sich und markiert Orte", Tasks.flags.has("w17_hint") and W17Locator.hit_sites().has("absturz"))
	Tasks.flags.erase("w17_hit_absturz")


## Christians Liste 25.11. abends (nach der ersten Belagerung).
func _t_fixes_2511c() -> void:
	var p := _player()
	var keep := p.global_position
	Survival.hurt_leg()
	_ok("Kein verletztes Bein mehr", not Survival.leg_hurt())
	# Belagerung: Erklärung kennt die Aufgaben, Notiz landet auf dem Tablet
	var td := ThreatDirector
	var keep_kind: String = td.night_kind
	td.night_kind = "siege"
	td.siege_done_day = -1
	Tasks.flags.erase("siege_briefed")
	var planned := SiegeNight.planned_tasks(get_tree())
	var shown := td.brief_siege()
	_ok("Belagerung: Erklärung mit Aufgaben (%s), Notiz auf dem Tablet" % str(planned),
		shown and not planned.is_empty() and Research.notes.has("belagerung_regeln") and Tasks.flags.has("siege_briefed"))
	_ok("Belagerung: Hinweis auf der Uhr", TimeManager.is_night() or td.siege_watch_line() != "")
	# Eindringen: erscheint vor dem Versteck, geht in die Hocke, verschwindet
	var s := SiegeNight.new()
	s.cfg = td.config
	s.index = 1
	s.end_total = TimeManager.get_total_hours() + 100.0
	_scene().add_child(s)
	s.set_process(false)
	var hs := _scene().find_child("Wardrobe", true, false) as HideSpot
	s._start_intrusion(Vector3(-3.0, 1.0, 3.6))
	_ok("Eindringen: anfangs unsichtbar (nur Schritte)", s._intrusion >= 0.0 and not is_instance_valid(s._intruder))
	var hidden_ok := false
	if hs:
		p.hidden_in = hs
		hs.occupied = true
		hs.settled = true
		hs.door_open = false
		hidden_ok = p.is_hidden()
	p.holding_breath = true
	s._update_intrusion(td.config.siege_hide_seconds + 0.1)
	var appeared := is_instance_valid(s._intruder)
	var near := appeared and s._intruder.global_position.distance_to(hs.global_position) < 2.5
	s._update_intrusion(5.0)
	var crouched := appeared and is_instance_valid(s._intruder)
	_ok("Eindringen: steht mit Blitz vor dem Versteck, man ist versteckt", hidden_ok and appeared and near and crouched and p.health > 0.0)
	s._update_intrusion(5.0)
	_ok("Eindringen: mit angehaltenem Atem verschwindet es wieder", s._intrusion < 0.0 and not is_instance_valid(s._intruder) and p.health > 0.0)
	p.holding_breath = false
	hs.occupied = false
	hs.settled = false
	p.hidden_in = null
	s.queue_free()
	td.night_kind = keep_kind
	p.global_position = keep
	# Schrott ums Haus, Wasser im Topf
	_ok("Schrott: Fundstellen auch ums Haus", Supplies.config.scrap_near_home > 0.2 and Supplies.config.scrap_spots_max >= 10)
	_ok("Wasser: 8 Flaschen tragbar", int(DataDB.item("water").get("stack", 0)) >= 8)
	# Foto-Fels/Hüttenboden im klaren Stil
	var m := StandardMaterial3D.new()
	_ok("Foto-Texturen: Fels setzbar", Look.apply_photo(m, "rock") == (Look.smooth and Look.forest_photo) and (not Look.smooth or m.normal_texture != null))


## Einführung, Meldungen, Look (Christian 26.11.)
func _t_ui_2611() -> void:
	for k: String in UiStyle.FONTS:
		_ok("Schrift %s lädt" % k, UiStyle.font(k) != null)
	_ok("Tastenbild: drei Gruppen", Array(KeyCard.data().get("groups", [])).size() >= 3)
	var hud := get_tree().get_first_node_in_group("hud") as Hud
	if hud:
		var u := hud.unread
		hud.show_notification("Gespeichert.", 2.0)
		_ok("Meldungen: Unwichtiges nur still auf der Uhr", hud.unread == u + 1 and hud.visible_thought() != "Gespeichert." and String(hud.log_entries[0]["text"]) == "Gespeichert.")
		hud.show_notification("Ein ruhiger Gedanke.", 3.0)
		hud.show_notification("Gefahr! Lauf!", 3.0)
		await get_tree().create_timer(0.5).timeout
		_ok("Meldungen: Gefahr drängelt vor", hud.visible_thought() == "Gefahr! Lauf!" or hud._queue.is_empty() == false and String(hud._queue[0][0]) == "Gefahr! Lauf!")
		hud._queue.clear()
		hud.unread = 0
		_ok("Bedürfnis-Ringe vorhanden", hud._needs != null)
		Survival.thirst = 30.0
		_ok("Durst-Ring erscheint bei Durst", hud._needs.visible_needs().has("thirst"))
		Survival.thirst = 100.0
		hud.toggle_keycard()
		_ok("F1: Tastenbild auf", hud.keycard_open())
		hud.toggle_keycard()
	# Einführung
	var tut := _scene().get_node_or_null("Tutorial") as Tutorial
	_ok("Einführung: Knoten in der Szene", tut != null)
	var keep_flags := Tasks.flags.duplicate()
	var fp := _scene().get_node_or_null("Cabin/Fireplace")
	var keep_burn: float = fp.get("burn_until") if fp else 0.0
	for f in ["tutorial_on", "tutorial_done", "fire_lit", "tablet_opened"]:
		Tasks.flags.erase(f)
	for st: Dictionary in tut.steps:
		Tasks.flags.erase("tut_" + String(st["id"]))
	Tutorial.begin()
	_ok("Einführung: aktiv, Ofen aus, Durst gesenkt", Tutorial.active() and Survival.thirst < 60.0 and fp != null and float(fp.get("burn_until")) < TimeManager.get_total_hours())
	await get_tree().create_timer(0.6).timeout
	_ok("Einführung: erster Schritt läuft, Uhr steht (%d, %.2f)" % [tut.index, TimeManager.tempo], tut.index == 0 and TimeManager.tempo == 0.0)
	_ok("Einführung: Karte sichtbar", tut.card != null and tut.card.visible)
	if fp:
		Inventory.add("wood", 1)
		fp.call("interact", _player())
	var fire_step: Dictionary = tut.steps[1]
	_ok("Einführung: Ofen anheizen erkannt", tut.is_done(fire_step))
	Tasks.flag("tablet_opened")
	_ok("Einführung: Tablet erkannt", tut.is_done(tut.steps[4]))
	Tutorial.skip()
	await get_tree().create_timer(0.3).timeout
	_ok("Einführung: überspringen → Uhr läuft", not Tutorial.active() and TimeManager.tempo == 1.0)
	Tasks.flags = keep_flags
	if fp:
		fp.set("burn_until", keep_burn)
	Survival.thirst = 100.0
	Survival.hunger = 100.0
	Survival.warmth = 100.0
	# Intro: Texte und Klingelton
	var intro: Dictionary = DataDB.load_json("res://data/story/intro.json")
	_ok("Intro: Gespräch, Polizei, Nachspann", Array(intro.get("call", [])).size() >= 5 and Array(intro.get("police", [])).size() >= 1 and Array(intro.get("epilogue", [])).size() >= 5)
	_ok("Intro: Klingelton und Vibration", IntroScene._ringtone() != null and IntroScene._vibrate() != null and IntroScene._skid() != null)
	_ok("Intro: Szene vorhanden", ResourceLoader.exists(GameState.INTRO_SCENE))
