class_name PlaythroughTest
extends Node
## Entwickler-Test: spielt 15 Tage automatisch durch (essen, trinken, Generator, Forschung, Labor,
## Beete, Schlingen, Ausflüge zu allen Orten, zwei Zeltnächte, schlafen). Nach jedem Tag wird der
## Spielstand gesichert und neu geladen; dabei wird verglichen, ob etwas verloren geht oder doppelt da ist.
## Start: godot --headless --path . -- --night-test=playthrough   (optional --days=N)
##
## Der Test hängt am Wurzelknoten, damit er das Neuladen der Szene übersteht.

static var instance: PlaythroughTest = null

const DAYS := 15
## Spielstunden pro echter Sekunde, solange die „schnelle Uhr“ läuft (Abend, wach liegen)
const FAST_HOURS_PER_SECOND := 2.0
## Reihenfolge der Ausflüge (zwei Orte pro Tag)
const TRIPS := ["absturz", "hochsitz", "hoehle", "struktur", "brunnen", "kapelle", "friedhof", "imkerei", "messstelle", "see",
		"ferienlager", "schaefer", "windwurf", "funkmast", "steinbruch", "kontrollpunkt", "moor", "spiegel", "aussenstelle",
		"tunnel", "dorf", "ilse", "wetterstation", "gewaechshaus", "wal", "raststation"]
const CAMP_DAYS := [6, 11]

var problems: PackedStringArray = []
var deaths: int = 0
var _fast_clock: bool = false
var _trip_index: int = 0
var _crafted: Dictionary = {}
var _days: int = DAYS
var _restarted: bool = false
## Warum in der letzten Nacht nicht geschlafen wurde (Grund -> wie oft), für Fehlermeldungen
var _awake_why: Dictionary = {}


static func start(tree: SceneTree) -> void:
	if instance != null:
		return
	instance = PlaythroughTest.new()
	instance.name = "PlaythroughTest"
	instance.process_mode = Node.PROCESS_MODE_ALWAYS
	tree.root.add_child.call_deferred(instance)


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--days="):
			_days = int(arg.get_slice("=", 1))
	GameState.day_restarted.connect(func() -> void: _restarted = true)
	_run.call_deferred()


func _process(delta: float) -> void:
	if _fast_clock and TimeManager.running and not get_tree().paused:
		var hours := delta * FAST_HOURS_PER_SECOND
		TimeManager.advance_hours(hours)
		# Hunger, Durst, Wärme und Tank laufen im Spiel nach echter Zeit – hier im Zeitraffer mitziehen
		var as_seconds := hours / maxf(TimeManager.get_hours_per_second(), 0.0001)
		Survival._process(as_seconds)
		PowerManager._process(as_seconds)


# --- Hilfen -------------------------------------------------------------------

func _scene() -> Node:
	return get_tree().current_scene


func _player() -> Player:
	return get_tree().get_first_node_in_group("player") as Player


func _frames(n: int = 3) -> void:
	for i in n:
		await get_tree().physics_frame


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, false).timeout


func _problem(text: String) -> void:
	problems.append(text)
	print("FEHLER Durchlauf: ", text)


## Wartet, bis nach einem Neuladen wieder eine Szene mit Spieler da ist.
func _wait_scene() -> void:
	for i in 600:
		await get_tree().process_frame
		if _scene() != null and _player() != null and _player().is_inside_tree():
			break
	await _frames(12)


func _teleport(pos: Vector3, load_radius: float = 0.0) -> void:
	var p := _player()
	if p == null:
		return
	var terrain := _scene().get_node_or_null("Terrain") as Terrain
	if terrain and load_radius > 0.0:
		terrain.load_around(pos, load_radius)
	p.global_position = pos
	p.velocity = Vector3.ZERO
	await _frames(4)


func _go_home() -> void:
	await _teleport(Vector3(-2.0, Cabin.FLOOR_Y + 0.1, 1.0))


## Sammelt alles Aufhebbare unter einem Knoten ein, liest Notizen, nimmt Baupläne, schaut alles an.
func _use_everything(root: Node) -> void:
	var p := _player()
	if root == null or p == null:
		return
	var menu := _scene().get_node_or_null("ResearchMenu") as ResearchMenu
	for n in root.find_children("*", "Node3D", true, false):
		if not is_instance_valid(n) or n.is_queued_for_deletion():
			continue
		if n is ItemPickup:
			var ip := n as ItemPickup
			var guard := 0
			while ip.amount > 0 and guard < 40:
				guard += 1
				var before := ip.amount
				ip.interact(p)
				if ip.amount == before:
					break
		elif n is ResearchNote or n is Blueprint or n is PlaceInspect:
			(n as Interactable).interact(p)
			if menu and menu.is_open():
				menu.close()
		elif n is ResourceNode:
			pass  # Hacken dauert – wird gezielt gemacht
	await _frames(2)
	_fix_ui("nach dem Einsammeln")


## Menüs müssen Maus und Steuerung zurückgeben.
func _fix_ui(where: String) -> void:
	var p := _player()
	if p == null:
		return
	for path in ["ResearchMenu", "GameMenus", "TabletMenu", "MapScreen"]:
		var m := _scene().get_node_or_null(path)
		if m and m.has_method("is_open") and m.call("is_open"):
			_problem("Menü %s noch offen %s" % [path, where])
			m.call("close")
	if p.input_locked and not GameState.dead:
		_problem("Steuerung gesperrt %s" % where)
		p.input_locked = false
	if get_tree().paused:
		_problem("Spiel pausiert %s" % where)
		get_tree().paused = false


func _store_surplus() -> void:
	var chest := _scene().get_node_or_null("Cabin/StorageChest") as StorageChest
	if chest == null:
		return
	# schwere Baustoffe über einen Grundvorrat hinaus in die Truhe
	for id: String in ["wood", "stone", "scrap", "planks", "fuel_can", "car_parts", "peat", "explosive", "food", "water", "ration", "nails", "battery", "electronics"]:
		var keep := 6 if id in ["wood", "planks", "scrap", "nails", "electronics", "battery"] else 2
		var extra := Inventory.count(id) - keep
		if extra > 0 and Inventory.overloaded():
			chest.put(id, extra)


func _from_chest(id: String, amount: int) -> void:
	var chest := _scene().get_node_or_null("Cabin/StorageChest") as StorageChest
	if chest and Inventory.count(id) < amount:
		chest.take(id, amount - Inventory.count(id))


func _eat_and_drink() -> void:
	var p := _player()
	var guard := 0
	while Survival.hunger < 65.0 and guard < 12:
		guard += 1
		var best := ""
		for id: String in Inventory.items:
			var use: Dictionary = DataDB.item(id).get("use", {})
			if use.has("hunger") and not use.has("sick") and Inventory.count(id) > 0:
				best = id
		if best == "":
			_from_chest("food", 2)
			if Inventory.count("food") <= 0:
				break
			best = "food"
		Inventory.use(best)
	var tap := _scene().get_node_or_null("Cabin/KitchenTap") as WaterSource
	guard = 0
	while Survival.thirst < 70.0 and tap != null and guard < 6:
		guard += 1
		tap.interact(p)
	# leere Flaschen am Hahn füllen
	guard = 0
	while tap != null and Inventory.count("bottle_empty") > 0 and Inventory.count("water") < 4 and guard < 6:
		guard += 1
		tap.secondary_interact(p)
	if p.health < 60.0 and Inventory.count("medkit") > 0:
		Inventory.use("medkit")


func _generator() -> void:
	var p := _player()
	var gen := _scene().get_node_or_null("Shed/Generator") as Generator
	var service := _scene().find_child("GeneratorService", true, false) as GeneratorService
	if gen == null:
		_problem("Generator nicht gefunden")
		return
	gen.get_prompt(p)
	if PowerManager.fuel < 60.0:
		_from_chest("fuel_can", 1)
		gen.secondary_interact(p)
	if service:
		service.get_prompt(p)
		if Supplies.generator_condition < 70.0:
			service.interact(p)
			service.secondary_interact(p)
		elif Inventory.count("gasifier_kit") > 0 or Inventory.count("cell_adapter") > 0:
			service.interact(p)
	if not PowerManager.has_power():
		gen.interact(p)


func _fire() -> void:
	var p := _player()
	var fp := _scene().get_node_or_null("Cabin/Fireplace") as Fireplace
	if fp and not fp.heats_cabin():
		_from_chest("wood", 2)
		fp.interact(p)
	var basket := _scene().get_node_or_null("Cabin/WoodBasket") as WoodBasket
	if basket and Inventory.count("wood") > 3:
		basket.secondary_interact(p)


func _chop_wood() -> void:
	var p := _player()
	if Inventory.count("axe") <= 0:
		var axe := _scene().get_node_or_null("Garden/Axe") as ItemPickup
		if axe:
			axe.interact(p)
	var slot := Inventory.slot_of("axe")
	if slot < 0:
		return
	Inventory.select(slot)
	var n := 0
	for t in _scene().find_children("WoodLog_*", "", true, false):
		var node := t as ResourceNode
		if node == null or node.amount <= 0 or n >= 2:
			continue
		n += 1
		node.interact(p)
		await _wait(node.action_time + 0.5)
	_fix_ui("nach dem Holzhacken")


func _garden(day: int) -> void:
	var p := _player()
	var barrel := _scene().get_node_or_null("Garden/RainBarrel") as WaterSource
	for i in Supplies.BED_COUNT:
		var bed := _scene().get_node_or_null("Garden/GardenBed%d" % (i + 1)) as GardenBed
		if bed == null:
			if day == 2:
				_problem("Hochbeet %d nicht gefunden" % (i + 1))
			continue
		bed.get_prompt(p)
		match Supplies.bed_state(i):
			"empty":
				bed.interact(p)
			"growing":
				if Supplies.can_water <= 0 and barrel:
					barrel.secondary_interact(p)
				bed.finish_watering()   # entspricht Linksklick halten mit der Kanne
			_:
				bed.interact(p)


func _snares(day: int) -> void:
	var p := _player()
	if day == 3:
		for r: Dictionary in DataDB.recipes():
			if r["id"] == "snare":
				Workbench.craft(r, get_tree())
		var k := 0
		while Inventory.count("snare") > 0 and k < 2:
			Inventory.remove("snare", 1)
			var pos := Vector3(-30.0 - k * 6.0, 0, 26.0)
			pos.y = Terrain.height_at(pos.x, pos.z)
			Builder.place("snare", pos, 0.0)
			k += 1
	for s in get_tree().get_nodes_in_group("structure"):
		var st := s as Structure
		if st and st.type == "snare":
			st.get_prompt(p)
			st.interact(p)


## Forschung: Geräte bauen, Projekte einlegen, Experimente, senden, verknüpfen, Labor ausbauen, Rezepte bauen.
func _research(day: int) -> void:
	var p := _player()
	# Umzugskarton und Analysegerät
	var box := _scene().get_node_or_null("Cabin/MovingBox") as MovingBox
	if box and Inventory.count("w17") <= 0 and not Research.w17_in_device:
		box.interact(p)
		box.interact(p)
	_close_note()
	if Research.tier < 1:
		for id: String in ["electronics", "battery", "scrap"]:
			_from_chest(id, 3)
		_craft("analyzer_improvised")
	if Inventory.count("alien_analyzer") > 0 and Research.tier < 2:
		var radio := _scene().get_node_or_null("Cabin/Radio") as Radio
		if radio:
			radio.get_prompt(p)
			radio.secondary_interact(p)
			radio.interact(p)
			_close_note()
	# Labor
	var setup := _scene().get_node_or_null("Cabin/Lab/LabSetup") as Interactable
	if Research.lab_offered and not Research.lab_built and setup:
		for id: String in Research.lab_def().get("needs", {}):
			_from_chest(id, int(Research.lab_def()["needs"][id]))
		setup.get_prompt(p)
		setup.interact(p)
		_close_note()
	if Research.lab_built:
		for st: String in Research.LAB_STATIONS:
			if not Research.lab_stations.has(st):
				for id: String in Research.lab_def()["stations"][st].get("needs", {}):
					_from_chest(id, int(Research.lab_def()["stations"][st]["needs"][id]))
				Research.build_station(st)
		if Research.charger_blocker() == "":
			Research.build_charger()
		if Research.lab_bloom and setup:
			setup.secondary_interact(p)
		while Research.take_charged_cell():
			pass
	# Projekte einlegen und Experimente
	for st: String in Research.stations.keys():
		if String(Research.stations[st]) == "" and Research.station_built(st):
			for pid: String in Research.available_projects(st):
				if Research.insert_project(st, pid):
					break
		var id := String(Research.stations.get(st, ""))
		if id != "":
			for e: Dictionary in Research.analysis(id).get("experiments", []):
				if String(Research.stations.get(st, "")) != id:
					break
				if Research.experiment_blocker(e, st) == "":
					Research.run_experiment(String(e["id"]), st)
	# Menüs einmal öffnen und schließen (müssen die Steuerung zurückgeben)
	var menu := _scene().get_node_or_null("ResearchMenu") as ResearchMenu
	if menu and Research.tier >= 1:
		menu.open_station("device")
		await _frames(2)
		menu.close()
		if Research.lab_built:
			menu.open_lab()
			await _frames(2)
			menu.close()
	Research.send_results()
	for l: String in Research.data().get("links", {}):
		if Research.can_link(l):
			Research.link(l)
	# lose Proben im Haus einfangen, Kameraaufnahmen holen
	var drops := AlienDrops.get_for(get_tree())
	if drops:
		await _use_everything(drops)
		drops.collect_footage()
	# alles bauen, was geht (je Rezept einmal)
	for r: Dictionary in DataDB.recipes():
		var rid := String(r["id"])
		if _crafted.has(rid) or r.has("minutes") or rid in ["analyzer_improvised", "snare", "planks", "nails"]:
			continue
		if Research.recipe_unlocked(r) and (r.has("requires") or r.has("blueprint") or day >= 3):
			if Workbench.craft(r, get_tree()) == "":
				_crafted[rid] = day
	_fix_ui("nach der Forschung")


func _close_note() -> void:
	var menu := _scene().get_node_or_null("ResearchMenu") as ResearchMenu
	if menu and menu.is_open():
		menu.close()


func _craft(rid: String) -> String:
	for r: Dictionary in DataDB.recipes():
		if r["id"] == rid:
			return Workbench.craft(r, get_tree())
	return "Rezept fehlt"


## Kochen am Ofen: Rohwasser abkochen, Fleisch braten.
func _cook() -> void:
	var p := _player()
	var stove := _scene().get_node_or_null("Cabin/CookStove") as CookStove
	if stove == null:
		return
	if Inventory.count("meat_raw") <= 0 and Inventory.count("water_raw") <= 0 and Inventory.count("potato") <= 0:
		return
	if not stove.lit():
		_from_chest("wood", 1)
		stove.interact(p)
	if not stove.lit():
		return
	stove.interact(p)
	await _frames(2)
	var menus := _scene().get_node_or_null("GameMenus") as GameMenus
	if menus and menus.is_open():
		for r: Dictionary in DataDB.recipes():
			if r.has("minutes") and Inventory.has_all(r.get("needs", {})):
				menus._on_craft(r)
		menus.close()
	_fix_ui("nach dem Kochen")


## Menüs im Haus: Inventar, Truhe, Tablet, Karte, Monitor – öffnen und schließen.
func _menus() -> void:
	var p := _player()
	var menus := _scene().get_node_or_null("GameMenus") as GameMenus
	if menus:
		menus.open_inventory()
		await _frames(2)
		menus.close()
		var chest := _scene().get_node_or_null("Cabin/StorageChest") as StorageChest
		if chest:
			chest.interact(p)
			await _frames(2)
			menus.close()
		menus.open_crafting()
		await _frames(2)
		menus.close()
	_fix_ui("nach Inventar/Truhe/Werkbank")
	var couch := _scene().get_node_or_null("Cabin/Couch") as Couch
	var tablet := _scene().get_node_or_null("TabletMenu") as TabletMenu
	if couch and tablet:
		couch.interact(p)
		await _wait(1.6)
		for tab in ["inbox", "archive", "notes", "tasks", "tree"]:
			if tablet.is_open():
				tablet._set_tab(tab)
				await _frames(2)
		for m: Dictionary in couch.available():
			couch.mark_read(String(m.get("id", "")))
		tablet.close()
		await _wait(1.4)
	_fix_ui("nach dem Tablet")
	var map := _scene().get_node_or_null("MapScreen") as MapScreen
	if map and Inventory.count("hiking_map") > 0:
		map.open()
		await _frames(2)
		map.close()
	var mon := _scene().get_node_or_null("Cabin/MonitorStation") as MonitorStation
	if mon:
		mon.interact(p)
		await _wait(1.6)
		var hud := get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("close_monitor"):
			hud.call("close_monitor")
		await _wait(1.4)
	_fix_ui("nach dem Monitor")
	var radio := _scene().get_node_or_null("Cabin/Radio") as Radio
	if radio and radio.has_new_message():
		radio.interact(p)
		_close_note()
	_fix_ui("nach dem Radio")


## Kameras, die man gefunden hat, außen anbringen.
func _cameras() -> void:
	var spots := [[Vector3(-3.0, 2.6, 4.62), Vector3(0, 0, 1)], [Vector3(6.12, 2.6, -1.0), Vector3(1, 0, 0)], [Vector3(-6.12, 2.6, 0.0), Vector3(-1, 0, 0)]]
	for i in 3:
		var item := "camera_%d" % (i + 1)
		if Inventory.count(item) > 0 and not Supplies.camera_installed(i):
			Inventory.remove(item, 1)
			Supplies.install_camera(i, spots[i][0], spots[i][1], 0.0)


func _trip(id: String) -> void:
	var p := _player()
	if not WorldMap.places().has(id):
		_problem("Ausflugsziel fehlt in der Karte: " + id)
		return
	var at := WorldMap.place_point(id)
	await _teleport(at + Vector3(2.0, 1.0, 2.0), 90.0)
	# Besuch wird einmal pro Sekunde geprüft (nach dem Nachladen des Geländes hängt die Uhr kurz)
	var t0 := Time.get_ticks_msec()
	while not Tasks.flags.has("visit_" + id) and Time.get_ticks_msec() - t0 < 4000:
		await get_tree().process_frame
	var root: Node = _scene().get_node_or_null("Places/" + id)
	match id:
		"absturz": root = _scene().get_node_or_null("CrashSite")
		"struktur": root = _scene().get_node_or_null("AlienStructure")
		"hochsitz": root = _scene().get_node_or_null("RangerTower")
		"hoehle": root = _scene().get_node_or_null("StreamCave")
	if root == null:
		_problem("Ort %s hat keinen Knoten in der Welt" % id)
	else:
		await _use_everything(root)
	if not Tasks.flags.has("visit_" + id):
		_problem("Besuch von %s wurde nicht gezählt" % id)
	if p.global_position.y < Terrain.height_at(p.global_position.x, p.global_position.z) - 3.0:
		_problem("Spieler ist bei %s durch den Boden gefallen" % id)
	print("  Ausflug %s: Rucksack %.0f kg, Gesundheit %.0f" % [id, Inventory.total_weight(), p.health])


## Nacht im Zelt: Zelt und Feuer aufbauen, hineinkriechen, schlafen, morgens abbauen.
func _camp_night(day: int) -> bool:
	var p := _player()
	_from_chest("tent", 1)
	if Inventory.count("tent") <= 0:
		print("  Zeltnacht Tag %d: kein Zelt im Besitz – übersprungen" % day)
		return false
	_from_chest("wood", 4)
	if Inventory.count("campfire") <= 0:
		_craft("campfire")
	if Inventory.count("sleeping_bag") <= 0:
		_craft("sleeping_bag")
	var base := WorldMap.place_point("kapelle") + Vector3(18, 0, 12)
	base.y = Terrain.height_at(base.x, base.z)
	await _teleport(base + Vector3(0, 0.4, 4.0), 80.0)
	Inventory.remove("tent", 1)
	var tent := Builder.place("tent", base, 0.0)
	var fire: Structure = null
	if Inventory.remove("campfire", 1):
		fire = Builder.place("campfire", base + Vector3(0, 0, 3.4), 0.0)
	await _frames(4)
	await _clock_to(21.5)
	if not is_instance_valid(tent) or tent.camp == null:
		_problem("Zelt steht nicht")
		return false
	tent.interact(p)
	await _wait(1.5)
	if not tent.camp.occupied():
		_problem("Hineinkriechen ins Zelt ging nicht")
	var uid := tent.uid
	await _sleep_loop(func() -> void:
		var t := _camp_of(uid)
		if t and t.occupied() and not t.torn:
			t._try_sleep()
		elif t and t.torn and not t.occupied() and Inventory.has_all(TentCamp.REPAIR):
			t.interact(_player())
		elif t and not t.torn and not t.occupied():
			t.interact(_player()))
	if _restarted:
		return true
	# Morgen: hinaus, Zelt abbauen, Feuer bleibt als Rest stehen
	var camp := _camp_of(uid)
	if camp and camp.occupied():
		camp.leave()
		await _wait(1.4)
	_fix_ui("nach der Zeltnacht")
	if camp and is_instance_valid(camp.structure):
		camp.structure.secondary_interact(_player())
	if not Tasks.flags.has("slept_outside"):
		_problem("Zeltnacht wurde nicht als „draußen geschlafen“ gezählt (wach wegen: %s)" % str(_awake_why))
	print("  Zeltnacht Tag %d: Wärme %.0f, Gesundheit %.0f, Zelt zerrissen: %s" % [day, Survival.warmth, _player().health, Tasks.flags.has("tent_torn")])
	return true


func _camp_of(uid: int) -> TentCamp:
	for s in get_tree().get_nodes_in_group("structure"):
		var st := s as Structure
		if st and st.uid == uid:
			return st.camp
	return null


## Uhr schnell vorlaufen lassen bis zu einer Uhrzeit (die Welt läuft dabei weiter).
func _clock_to(hour: float) -> void:
	_fast_clock = true
	var guard := 0
	while guard < 4000 and not _restarted:
		guard += 1
		await get_tree().process_frame
		var diff := fposmod(hour - TimeManager.hour, 24.0)
		if diff < 0.05 or diff > 23.0:
			break
	_fast_clock = false


## Schlafen, bis es Morgen ist. try_sleep wird aufgerufen, sooft Schlafen möglich scheint.
func _sleep_loop(try_sleep: Callable) -> void:
	var day_start := TimeManager.config.day_start_hour
	var guard := 0
	_awake_why.clear()
	_fast_clock = true
	while guard < 400 and not _restarted:
		guard += 1
		if not TimeManager.is_night() and TimeManager.hour >= day_start and TimeManager.hour < 12.0:
			break
		var p := _player()
		if p == null or GameState.dead:
			await _wait(0.5)
			continue
		var why := "Uhrzeit" if not TimeManager.can_sleep() else ("Steuerung gesperrt" if p.input_locked else ThreatDirector.sleep_blocker())
		if why != "":
			_awake_why[why] = int(_awake_why.get(why, 0)) + 1
		# Solange draußen etwas umgeht, läuft die Uhr normal weiter (wie beim echten Spieler, der wach liegt und
		# wartet) – im Zeitraffer wäre sonst die ganze Nacht vorbei, bevor das Wesen wieder weg ist.
		if why != "" and why != "Uhrzeit" and why != "Steuerung gesperrt":
			_fast_clock = false
			var waited := 0.0
			while waited < 150.0 and not _restarted and not GameState.dead and ThreatDirector.sleep_blocker() != "":
				await _wait(0.5)
				waited += 0.5
			_fast_clock = true
			continue
		if why == "":
			var asleep := [false]
			var done := [false]
			var on_sleep := func(_h: float) -> void: asleep[0] = true
			var on_wake := func() -> void: done[0] = true
			EventBus.sleep_requested.connect(on_sleep)
			EventBus.sleep_finished.connect(on_wake)
			try_sleep.call()
			if not asleep[0]:
				_awake_why["Schlafversuch ohne Wirkung"] = int(_awake_why.get("Schlafversuch ohne Wirkung", 0)) + 1
			if asleep[0]:
				_fast_clock = false
				var t := 0.0
				while not done[0] and t < 12.0 and not _restarted:
					await get_tree().process_frame
					t += get_process_delta_time()
				if not done[0] and not _restarted:
					_problem("Schlaf endet nicht (Tag %d, %s)" % [TimeManager.day, TimeManager.get_clock_text()])
				_fast_clock = true
			EventBus.sleep_requested.disconnect(on_sleep)
			EventBus.sleep_finished.disconnect(on_wake)
		await _wait(0.4)
	_fast_clock = false
	if guard >= 400:
		_problem("Nacht endet nicht (Tag %d, %s)" % [TimeManager.day, TimeManager.get_clock_text()])


# --- Vergleich vor/nach dem Neuladen -------------------------------------------

func _flatten(prefix: String, v: Variant, out: Dictionary) -> void:
	if v is Dictionary:
		var keys: Array = (v as Dictionary).keys()
		for k in keys:
			_flatten("%s/%s" % [prefix, str(k)], v[k], out)
	elif v is Array:
		for i in (v as Array).size():
			_flatten("%s[%d]" % [prefix, i], v[i], out)
	elif v is float:
		out[prefix] = "%.3f" % v
	elif v is Vector3:
		out[prefix] = "(%.2f, %.2f, %.2f)" % [v.x, v.y, v.z]
	else:
		out[prefix] = str(v)


func _fingerprint() -> Dictionary:
	var out := {}
	out["zeit"] = "Tag %d %s" % [TimeManager.day, TimeManager.get_clock_text()]
	_flatten("strom", PowerManager.get_state(), out)
	_flatten("rucksack", Inventory.get_state(), out)
	_flatten("ueberleben", Survival.get_state(), out)
	_flatten("bauten", Builder.get_state(), out)
	_flatten("forschung", Research.get_state(), out)
	_flatten("welt", WorldState.get_state(), out)
	_flatten("bedrohung", ThreatDirector.get_state(), out)
	_flatten("versorgung", Supplies.get_state(), out)
	_flatten("aufgaben", Tasks.get_state(), out)
	var world := GameState.collect_world()
	for k: String in world.keys():
		# eingesammelte Alien-Funde werden absichtlich vergessen (AlienDrops merkt sich nur, was noch liegt)
		if k.contains("/AlienDrops/Drop_"):
			world.erase(k)
	_flatten("objekte", world, out)
	# Was wirklich in der Welt steht
	var types := {}
	for s in get_tree().get_nodes_in_group("structure"):
		var st := s as Structure
		if st and not st.is_queued_for_deletion():
			types[st.type] = int(types.get(st.type, 0)) + 1
	_flatten("welt_bauten", types, out)
	out["welt_wucherungen"] = str(get_tree().get_nodes_in_group("organism_patch").size())
	out["welt_kameras"] = str(get_tree().get_nodes_in_group("security_camera").size())
	var pickups := 0
	for n in get_tree().get_nodes_in_group("persistent"):
		if n is ItemPickup and (n as ItemPickup).amount > 0:
			pickups += 1
	out["welt_aufhebbares"] = str(pickups)
	return out


func _compare(day: int, a: Dictionary, b: Dictionary) -> void:
	var lost := 0
	for k: String in a:
		if not b.has(k):
			lost += 1
			_problem("Tag %d nach dem Laden VERLOREN: %s = %s" % [day, k, a[k]])
		elif a[k] != b[k]:
			_problem("Tag %d nach dem Laden ANDERS: %s  vorher %s, nachher %s" % [day, k, a[k], b[k]])
	for k: String in b:
		if not a.has(k):
			_problem("Tag %d nach dem Laden NEU/DOPPELT: %s = %s" % [day, k, b[k]])


## Nichts darf doppelt in Listen stehen, nichts im Rucksack kaputt sein.
func _invariants(day: int) -> void:
	var lists := {"Analysen": Research.done, "Verknüpfungen": Research.links_done, "Notizen": Research.notes, "Funde": Research.seen,
			"Gesendet": Research.sent, "Baupläne": Research.blueprints, "Laborplätze": Research.lab_stations,
			"Aufgaben frei": Tasks.unlocked, "Aufgaben erledigt": Tasks.done}
	for name: String in lists:
		var seen := {}
		for x in lists[name]:
			if seen.has(x):
				_problem("Tag %d: %s doppelt: %s" % [day, name, str(x)])
			seen[x] = true
	for id: String in Inventory.items:
		var n := Inventory.count(id)
		if n <= 0:
			_problem("Tag %d: Rucksack-Eintrag ohne Menge: %s" % [day, id])
		if DataDB.item(id).is_empty():
			_problem("Tag %d: unbekannter Gegenstand im Rucksack: %s" % [day, id])
		elif n > int(DataDB.item(id).get("stack", 99)):
			_problem("Tag %d: mehr als ein Stapel von %s (%d)" % [day, id, n])
	for id: String in Inventory.hotbar:
		if id != "" and Inventory.count(id) <= 0:
			_problem("Tag %d: Schnellplatz zeigt auf %s, aber keins im Rucksack" % [day, id])
	var uids := {}
	for r: Dictionary in Builder.records:
		if uids.has(r["uid"]):
			_problem("Tag %d: Bau-Nummer doppelt: %s" % [day, str(r["uid"])])
		uids[r["uid"]] = true
	var world_structs := 0
	for s in get_tree().get_nodes_in_group("structure"):
		if not s.is_queued_for_deletion():
			world_structs += 1
	if world_structs != Builder.records.size():
		_problem("Tag %d: %d Bauten gespeichert, aber %d in der Welt" % [day, Builder.records.size(), world_structs])
	var keys := {}
	for n in get_tree().get_nodes_in_group("persistent"):
		var k := String(n.call("persist_key"))
		if keys.has(k):
			_problem("Tag %d: zwei Objekte teilen sich einen Spielstand-Namen: %s" % [day, k])
		if k.contains("@"):
			_problem("Tag %d: Objekt ohne festen Namen im Spielstand: %s" % [day, k])
		keys[k] = true
	var st := Survival
	for v: float in [st.hunger, st.thirst, st.warmth, st.stamina, PowerManager.fuel, Supplies.generator_condition]:
		if is_nan(v) or v < -0.01 or v > 100.01:
			_problem("Tag %d: Wert außerhalb 0–100: %s" % [day, str(v)])
	for st_id: String in Research.stations:
		var pid := String(Research.stations[st_id])
		if pid != "" and Research.analysis(pid).is_empty():
			_problem("Tag %d: Station %s enthält unbekanntes Projekt %s" % [day, st_id, pid])


func _save_reload_check(day: int) -> void:
	await _frames(4)
	_invariants(day)
	# Uhr anhalten, damit sich zwischen Sichern und Vergleichen nichts von selbst ändert
	TimeManager.running = false
	await _frames(2)
	GameState.take_snapshot()
	var before := _fingerprint()
	_restarted = false
	GameState.restart_day()
	await _wait_scene()
	_restarted = false
	var after := _fingerprint()
	TimeManager.running = true
	_compare(day, before, after)
	_invariants(day)
	_fix_ui("nach dem Laden")


# --- Ablauf ----------------------------------------------------------------------

func _play_day(day: int) -> void:
	var p := _player()
	print("TAG %d  %s  Hunger %.0f Durst %.0f Wärme %.0f Gesundheit %.0f Tank %.0f Stufe %d  (%s)" % [TimeManager.day, TimeManager.get_clock_text(),
		Survival.hunger, Survival.thirst, Survival.warmth, p.health, PowerManager.fuel, WorldState.stage(), ThreatDirector.night_kind])
	await _go_home()
	# Haus und Hof: alles einsammeln, was herumliegt
	if day == 1:
		for root_name in ["Cabin", "Shed", "Garden", "SupplyProps", "CarWreck"]:
			await _use_everything(_scene().get_node_or_null(root_name))
		_store_surplus()
	_eat_and_drink()
	_generator()
	await _chop_wood()
	_cameras()
	_garden(day)
	_snares(day)
	await _research(day)
	await _cook()
	await _menus()
	_store_surplus()
	# zwei Ausflüge
	for k in 2:
		if _trip_index < TRIPS.size() and not _restarted:
			await _trip(TRIPS[_trip_index])
			_trip_index += 1
	if _restarted:
		return
	await _go_home()
	_store_surplus()
	await _research(day)
	_eat_and_drink()
	_fire()
	# Schrott-Fundstellen im Wald
	for s in get_tree().get_nodes_in_group("scrap_spot"):
		if s is ScrapSpot and Inventory.count("tin_snips") > 0:
			(s as ScrapSpot).get_prompt(p)
	# Nacht
	if day in CAMP_DAYS and await _camp_night(day):
		pass
	else:
		await _go_home()
		await _clock_to(21.5)
		var bed := _scene().get_node_or_null("Cabin/Bed") as Bed
		if bed == null:
			_problem("Bett nicht gefunden")
			return
		await _teleport(Vector3(-4.0, Cabin.FLOOR_Y + 0.1, -3.0))
		await _sleep_loop(func() -> void:
			var b := _scene().get_node_or_null("Cabin/Bed") as Bed
			if b:
				b.interact(_player()))


func _run() -> void:
	await _wait_scene()
	print("DURCHLAUF Start: %d Tage" % _days)
	var day := 1
	var tries := 0
	while day <= _days and tries < _days * 3:
		tries += 1
		_restarted = false
		await _play_day(day)
		if _restarted:
			# gestorben: der Tag beginnt von vorn
			deaths += 1
			print("  gestorben an Tag %d – Neustart am Tagesbeginn (Tag %d)" % [day, TimeManager.day])
			await _wait_scene()
			_fix_ui("nach dem Tod")
			day = TimeManager.day
			continue
		if TimeManager.day != day + 1:
			_problem("Nach der Nacht von Tag %d ist Tag %d" % [day, TimeManager.day])
		await _save_reload_check(TimeManager.day)
		day = TimeManager.day
	var p := _player()
	print("DURCHLAUF Ende: Tag %d, %d Tode, Analysen %d, Verknüpfungen %d, Labor %s (%d Plätze), Orte besucht %d, Aufgaben erledigt %d/%d, gebaut: %s" % [
		TimeManager.day, deaths, Research.done.size(), Research.links_done.size(), Research.lab_built, Research.lab_stations.size(),
		Tasks.flags.keys().filter(func(f: String) -> bool: return f.begins_with("visit_")).size(), Tasks.done.size(),
		(Tasks.data().get("goals", []) as Array).size(), ", ".join(_crafted.keys())])
	print("DURCHLAUF Gesundheit %.0f, Hunger %.0f, Durst %.0f" % [p.health if p else -1.0, Survival.hunger, Survival.thirst])
	print("DURCHLAUF: %d Fehler" % problems.size())
	get_tree().quit(1 if not problems.is_empty() else 0)
