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
	await _t_seeker_house()
	_t_list_nov11()
	_t_blueprints()
	_t_nov12_evening()
	await _t_rooms()
	await _t_hands()


## Anbauten (13.11.): Büro, Kinderzimmer, Dachboden mit Zugleiter, Keller unter dem Teppich.
func _t_rooms() -> void:
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
