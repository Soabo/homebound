class_name NightTest
extends Node
## Entwickler-Test: Kreatur greift an, Protokoll der Zustände und Zugänge.
## Start: godot --headless --path . -- --night-test=attack   (oder observe / probe)

var mode: String = "attack"
var run_long: bool = true
static var _ran: bool = false


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--night-test="):
			mode = arg.get_slice("=", 1)
	_run.call_deferred()


func _run() -> void:
	if _ran:
		print("Nach Neustart: Tag %d, %s" % [TimeManager.day, TimeManager.get_clock_text()])
		print("Spannungsbogen nach Neustart: %s, %d Nächte seit Auftritt, %d ruhige übrig" % [ThreatDirector.night_kind, ThreatDirector.nights_since_appearance, ThreatDirector.quiet_left])
		if mode == "craft":
			for i in 5:
				await get_tree().physics_frame
			var w := get_tree().current_scene.get_node("Cabin/WindowLiving") as CabinWindow
			print("PERSISTENZ Fenster-Barrikade: %.0f (erwartet > 0)" % w.barricade)
			print("PERSISTENZ Bauten: %d Datensätze, %d in der Welt" % [Builder.records.size(), get_tree().get_nodes_in_group("structure").size()])
			print("PERSISTENZ Axt im Inventar: %d, Axt-Aufheber noch da: %d" % [Inventory.count("axe"), (get_tree().current_scene.get_node("Garden/Axe") as ItemPickup).amount])
			var door := get_tree().current_scene.get_node("Cabin/FrontDoor") as Door
			print("PERSISTENZ Tür verstärkt: %s, abgeschlossen: %s" % [door.upgraded, door.is_locked])
		get_tree().quit()
		return
	_ran = true
	# Tests mit den alten drei Kamerapositionen (im Spiel baut man sie selbst ein)
	if mode != "supplies":
		get_tree().call_group("surveillance", "install_defaults")
	if mode == "events":
		await _event_test()
		return
	if mode == "craft":
		await _craft_test()
		return
	if mode == "melee":
		await _melee_test()
		get_tree().quit()
		return
	if mode == "changes":
		await _changes_test()
		get_tree().quit()
		return
	if mode == "dread":
		await _dread_test()
		get_tree().quit()
		return
	if mode == "world":
		await _world_test()
		get_tree().quit()
		return
	if mode == "research":
		await _research_test()
		get_tree().quit()
		return
	if mode == "extras":
		await _extras_test()
		get_tree().quit()
		return
	if mode == "w17":
		await _w17_test()
		get_tree().quit()
		return
	if mode == "camp":
		await _camp_test()
		get_tree().quit()
		return
	if mode == "places":
		await _places_test()
		get_tree().quit()
		return
	if mode == "map":
		await _map_test()
		get_tree().quit()
		return
	if mode == "supplies":
		await _supplies_test()
		get_tree().quit()
		return
	if mode == "tablet":
		await _tablet_test()
		get_tree().quit()
		return
	if mode == "lurk":
		await _lurk_test()
		get_tree().quit()
		return
	if mode == "gear":
		await _gear_test()
		get_tree().quit()
		return
	for i in 10:
		await get_tree().physics_frame
	TimeManager.set_time(1, 21.0)
	TimeManager.running = false
	var player := get_tree().get_first_node_in_group("player") as Player
	player.global_position = Vector3(-1.0, 0.5, 1.0)  # im Wohnzimmer
	Engine.time_scale = 4.0
	if mode.ends_with("_locked"):
		mode = mode.trim_suffix("_locked")
		var door := get_tree().current_scene.get_node("Cabin/FrontDoor") as Door
		door.is_locked = true
		print("Haustür abgeschlossen")
	var c := Creature.new()
	get_tree().current_scene.add_child(c)
	ThreatDirector.creature = c
	c.begin(mode)
	c.global_position = Creature._ground(Vector3(-3.0, 0, 20.0))
	c._path.clear()
	c._path.append(Creature._ground(Vector3(-3.0, 0, 15.0)))
	var names := Creature.State.keys()
	for sec in (150 if run_long else 90):
		await get_tree().create_timer(1.0).timeout
		if not is_instance_valid(c):
			print("t=%d Kreatur ist gegangen" % sec)
			break
		var entry := ""
		if is_instance_valid(c._target_entry):
			entry = "%s (Stärke %.0f)" % [c._target_entry.name, c._target_entry.call("strength")]
		if sec % 3 == 0:
			print("t=%3d  %-9s pos=(%.1f, %.1f, %.1f)  Ziel=%s  Spieler-LP=%.0f" % [sec, names[c.state], c.global_position.x, c.global_position.y, c.global_position.z, entry, player.health])
		# Spieler stellt sich in Reichweite, sobald ein Zugang offen ist
		if c.state == Creature.State.REACH and is_instance_valid(c._target_entry):
			player.global_position = c._target_entry.call("inside_point") + Vector3(0, 0.1, 0)
		if GameState.dead:
			print("t=%d Spieler gestorben -> Neustart am Tagesbeginn" % sec)
			break
	Engine.time_scale = 1.0
	print("NIGHT TEST ENDE")
	await get_tree().create_timer(6.0).timeout
	print("Nach Neustart: Tag %d, %s, Szene neu geladen: %s" % [TimeManager.day, TimeManager.get_clock_text(), get_tree().current_scene != null])
	get_tree().quit()


func _event_test() -> void:
	for i in 10:
		await get_tree().physics_frame
	TimeManager.set_time(1, 22.0)
	for sw in get_tree().get_nodes_in_group("light_switch"):
		sw.switch_to(true)
	var types := ["twig", "steps", "silence", "camera_glitch", "breath_wall", "phantom", "scratch", "roof",
			"flicker", "radio", "signal", "knock_door", "rattle", "music_box", "handprint", "photo", "outage", "drone", "manipulator", "sighting"]
	for t in types:
		ThreatDirector._fire(t)
		await get_tree().create_timer(0.5).timeout
		print("Ereignis OK: ", t)
	print("Strom nach Ausfall: ", PowerManager.has_power())
	await get_tree().create_timer(5.0).timeout
	print("EVENT TEST ENDE")
	get_tree().quit()


func _craft_test() -> void:
	for i in 10:
		await get_tree().physics_frame
	var scene := get_tree().current_scene
	var player := get_tree().get_first_node_in_group("player") as Player
	# Ausrüsten
	(scene.get_node("Garden/Axe") as ItemPickup).interact(player)
	# Axt liegt automatisch auf einem Schnellplatz; ausrüsten und einen Stamm hacken
	var axe_slot := Inventory.slot_of("axe")
	print("AXT auf Platz: ", axe_slot + 1)
	Inventory.select(axe_slot)
	var trunks := scene.find_children("WoodLog_*", "", true, false)
	var trunk: ResourceNode = trunks[0] if not trunks.is_empty() else null
	if trunk:
		var wood_before := Inventory.count("wood")
		trunk.interact(player)
		await get_tree().create_timer(trunk.action_time + 0.6).timeout
		print("HACKEN mit Axt in der Hand: Holz +", Inventory.count("wood") - wood_before)
		Inventory.remove("wood", Inventory.count("wood"))
	for id: String in ["wood", "scrap", "stone", "cans", "battery", "electronics"]:
		Inventory.add(id, 6)
	print("Inventar vorher: ", Inventory.items, "  Gewicht %.1f" % Inventory.total_weight())
	for r: Dictionary in DataDB.recipes():
		var msg := Workbench.craft(r, get_tree())
		print("Rezept %-16s -> %s" % [r["id"], "OK" if msg == "" else msg])
	print("Inventar nachher: ", Inventory.items)
	# Fenster verbarrikadieren
	Inventory.add("planks", 4)
	Inventory.add("nails", 8)
	var w := scene.get_node("Cabin/WindowLiving") as CabinWindow
	w.secondary_interact(player)
	print("Fenster-Barrikade: %.0f" % w.barricade)
	var door := scene.get_node("Cabin/FrontDoor") as Door
	door.is_locked = true
	# Bauen: Zaun quer über den Weg der Kreatur, Spießbarrikade daneben
	var fence := Builder.place("fence_panel", Creature._ground(Vector3(-3.0, 0, 17.0)), 0.0)
	var spikes := Builder.place("spike_barricade", Creature._ground(Vector3(-3.0, 0, 13.0)), 0.0)
	Builder.place("can_alarm", Creature._ground(Vector3(-3.0, 0, 11.0)), 0.0)
	Builder.place("motion_light", Creature._ground(Vector3(0.0, 0, 11.0)), 0.0)
	print("Gebaut: %d Bauten" % Builder.records.size())
	GameState.take_snapshot()
	# Kreatur läuft durch Zaun und Spieße
	TimeManager.set_time(1, 21.0)
	TimeManager.running = false
	ThreatDirector.set_process(false)
	Engine.time_scale = 4.0
	var c := Creature.new()
	scene.add_child(c)
	ThreatDirector.creature = c
	c.begin("attack")
	c.global_position = Creature._ground(Vector3(-3.0, 0, 21.0))
	c._path.clear()
	c._path.append(Creature._ground(Vector3(-3.0, 0, 8.0)))
	c.state = Creature.State.PROWL
	var names := Creature.State.keys()
	for sec in 40:
		await get_tree().create_timer(1.0).timeout
		if not is_instance_valid(c):
			break
		var f := "weg" if not is_instance_valid(fence) else "%.0f" % fence.health
		var sp := "weg" if not is_instance_valid(spikes) else "%.0f" % spikes.health
		if sec % 2 == 0:
			print("t=%2d %-9s z=%.1f  zerlegt=%s  Zaun=%s  Spieße=%s" % [sec, names[c.state], c.global_position.z, is_instance_valid(c._breaking), f, sp])
	Engine.time_scale = 1.0
	print("CRAFT TEST: Tod auslösen, Neustart prüfen")
	GameState.kill_player()


## Hände: Faust- und Axthieb verscheuchen die Kreatur, Blocken mindert Schaden, Wechsel der Schnellplätze.
func _melee_test() -> void:
	for i in 10:
		await get_tree().physics_frame
	var player := get_tree().get_first_node_in_group("player") as Player
	player.global_position = Creature._ground(Vector3(6.0, 0, 12.0))
	player.rotation.y = 0.0
	player.head.rotation.x = 0.0
	TimeManager.running = false
	var c := Creature.new()
	get_tree().current_scene.add_child(c)
	ThreatDirector.creature = c
	c.begin("attack")
	c.global_position = Creature._ground(player.global_position + Vector3(0, 0, -1.3))
	c._path.clear()
	c.state = Creature.State.CHASE
	for i in 30:
		await get_tree().physics_frame
	c.state = Creature.State.CHASE
	print("MELEE Hand: ", player.hands.current_kind())
	var cam := player.camera.global_transform
	var to := c.global_position + Vector3(0, 1.3, 0) - cam.origin
	print("MELEE Abstand %.2f, Richtung %.2f, Hand draußen %.2f, Abklingen %.2f" % [to.length(), (-cam.basis.z).dot(to.normalized()), player.hands._right_out, player.hands._cooldown])
	player.hands._primary()
	print("MELEE Aktion: ", player.hands._action)
	for i in 40:
		await get_tree().physics_frame
	print("MELEE Faust -> Zustand: ", Creature.State.keys()[c.state])
	# Axt aufnehmen, auf Platz legen, wechseln
	Inventory.add("axe", 1)
	Inventory.select(Inventory.slot_of("axe"))
	for i in 30:
		await get_tree().physics_frame
	print("MELEE Hand nach Wechsel: ", player.hands.current_kind())
	c.state = Creature.State.CHASE
	c.global_position = Creature._ground(player.global_position + Vector3(0, 0, -1.6))
	player.hands._cooldown = 0.0
	player.hands._primary()
	for i in 50:
		await get_tree().physics_frame
	print("MELEE Axt -> Zustand: ", Creature.State.keys()[c.state])
	# Blocken: Schaden von vorne wird gemindert
	player.hands._block_amount = 1.0
	var f := player.hands.block_factor(player.global_position + Vector3(0, 0, -1.0))
	print("MELEE Block-Faktor Axt von vorne: %.2f, von hinten: %.2f" % [f, player.hands.block_factor(player.global_position + Vector3(0, 0, 1.0))])
	Inventory.select(8)
	for i in 30:
		await get_tree().physics_frame
	print("MELEE leerer Platz -> ", player.hands.current_kind())
	player.set_flashlight(true)
	for i in 30:
		await get_tree().physics_frame
	print("MELEE Uhr-Lampe an: ", player.flashlight.visible)


## Phase 7: Absturzstelle, Analysegerät, Analysen, Experimente, Verknüpfungen, neue Baupläne.
func _research_test() -> void:
	for i in 10:
		await get_tree().physics_frame
	var scene := get_tree().current_scene
	var player := get_tree().get_first_node_in_group("player") as Player
	TimeManager.set_time(1, 10.0)
	PowerManager.add_fuel(100.0)
	PowerManager.start_generator()
	# Absturzstelle: alles einsammeln
	var site := scene.get_node("CrashSite")
	for n: String in ["Fragment_0", "Fragment_1", "EnergyCell", "GlyphPlate", "AlienAnalyzer", "GlowFungus_0", "GlowFungus_1"]:
		var p := site.get_node(n) as ItemPickup
		while p.amount > 0:
			Inventory.remove("alien_analyzer", 0)
			p.interact(player)
			if p.amount > 0 and Inventory.total_weight() > 30.0:
				break
	print("RESEARCH Funde: metal %d, cell %d, plate %d, fungus %d, Gerät %d" % [Inventory.count("metal_fragment"), Inventory.count("energy_cell"),
		Inventory.count("glyph_plate"), Inventory.count("glow_fungus"), Inventory.count("alien_analyzer")])
	(site.get_node("RangerNote") as ResearchNote).interact(player)
	get_tree().call_group("research_menu", "close")
	print("RESEARCH Notiz im Archiv: ", Research.notes)
	# Gewebeprobe durch Axthieb
	CrashSite.drop_tissue(scene, player.global_position + Vector3(1, 0, 0))
	await get_tree().physics_frame
	(scene.find_children("TissueSample_d1_*", "ItemPickup", false, false)[0] as ItemPickup).interact(player)
	print("RESEARCH Gewebeprobe: ", Inventory.count("alien_tissue"))
	# Improvisiertes Gerät an der Werkbank (braucht W-17 aus dem Umzugskarton)
	var box := scene.get_node("Cabin/MovingBox") as MovingBox
	box.interact(player)
	box.interact(player)
	print("RESEARCH W-17 aus dem Karton: %d, Notizen %s" % [Inventory.count("w17"), Research.notes.has("karton_mappe")])
	Inventory.add("electronics", 2)
	Inventory.add("battery", 1)
	Inventory.add("scrap", 2)
	for r: Dictionary in DataDB.recipes():
		if r["id"] == "analyzer_improvised":
			print("RESEARCH Umbau: ", "OK" if Workbench.craft(r, get_tree()) == "" else "FEHLER", " -> Stufe ", Research.tier)
	# Metall analysieren: Experimente + Zeit
	print("RESEARCH Einlegen Metall: ", Research.insert("metal_fragment"))
	print("RESEARCH Experiment Strom: ", Research.run_experiment("power").left(40))
	print("RESEARCH Experiment Licht: ", Research.run_experiment("light").left(40))
	TimeManager.set_time(1, 12.5)
	for i in 5:
		await get_tree().process_frame
	print("RESEARCH Metall fertig: ", Research.done.has("an_metal"))
	# Fremdes Gerät einbauen
	var radio := scene.get_node("Cabin/Radio") as Radio
	radio.interact(player)
	print("RESEARCH Stufe nach Einbau: ", Research.tier)
	for find: String in ["energy_cell", "alien_tissue", "glow_fungus", "glyph_plate"]:
		Research.insert(find)
		var id := Research.slot
		for exp: Dictionary in Research.analysis(id).get("experiments", []):
			Research.run_experiment(exp["id"])
		TimeManager.set_time(1, TimeManager.hour + 2.0)
		for i in 5:
			await get_tree().process_frame
		print("RESEARCH %s fertig: %s" % [id, Research.done.has(id)])
	print("RESEARCH vor dem Senden verknüpfbar: ", Research.can_link("link_power"))
	print("RESEARCH ans Tablet gesendet: ", Research.send_results())
	for l: String in ["link_power", "link_light", "link_signal"]:
		print("RESEARCH Verknüpfen %s: %s" % [l, Research.link(l)])
	# Neue Baupläne
	Inventory.add("scrap", 4)
	Inventory.add("electronics", 1)
	Inventory.add("battery", 1)
	Inventory.add("energy_cell", 1)
	Inventory.add("glow_fungus", 2)
	for r: Dictionary in DataDB.recipes():
		if r["id"] in ["resonance_sensor", "strobe_light"]:
			print("RESEARCH Bauplan %s: %s" % [r["id"], Workbench.craft(r, get_tree())])
	print("RESEARCH Bauteile: Sensor %d, Stroboskop %d" % [Inventory.count("resonance_sensor"), Inventory.count("strobe_light")])
	# Stroboskop gegen die Kreatur
	var strobe := Builder.place("strobe_light", Creature._ground(Vector3(8.0, 0, 12.0)), 0.0)
	var sensor := Builder.place("resonance_sensor", Creature._ground(Vector3(0.0, 0, 12.0)), 0.0)
	var c := Creature.new()
	scene.add_child(c)
	ThreatDirector.creature = c
	c.begin("attack")
	c.global_position = Creature._ground(Vector3(8.0, 0, 16.0))
	c._path.clear()
	c.state = Creature.State.CHASE
	for i in 30:
		await get_tree().physics_frame
	print("RESEARCH Kreatur am Stroboskop -> ", Creature.State.keys()[c.state])
	var st := Research.get_state()
	Research.set_state({})
	Research.set_state(st)
	print("RESEARCH Speichern/Laden: Stufe %d, Analysen %d, Verknüpfungen %d" % [Research.tier, Research.done.size(), Research.links_done.size()])
	print("RESEARCH Bauten da: ", is_instance_valid(strobe), " ", is_instance_valid(sensor))


## Phase 8: Weltzustand, Orte, neue Arten.
func _world_test() -> void:
	for i in 10:
		await get_tree().physics_frame
	var scene := get_tree().current_scene
	var player := get_tree().get_first_node_in_group("player") as Player
	ThreatDirector.set_process(false)
	# Stufen über die Tage
	for d in [1, 4, 5, 6, 7, 9]:
		TimeManager.set_time(d, 8.0)
		WorldState._on_day_changed(d)
		await get_tree().process_frame
		print("WORLD Tag %d: Wert %.2f, Stufe %d, Wucherungen %d" % [d, WorldState.level(), WorldState.stage(), WorldState.patches.size()])
	var plants := scene.get_node_or_null("Terraformer/Plants")
	print("WORLD Fremdpflanzen: ", plants.get_child_count() if plants else 0, ", Pilzringe: ", scene.has_node("Terraformer/Rings"))
	# Verunreinigtes Wasser
	var tap: WaterSource = null
	for w in scene.find_children("*", "WaterSource", true, false):
		if (w as WaterSource).contaminable:
			tap = w
			break
	player.health = 100.0
	tap.interact(player)
	print("WORLD Wasser ohne Filter: Gesundheit %.0f (erwartet 88)" % player.health)
	Inventory.add("water_filter", 1)
	tap.interact(player)
	print("WORLD Wasser mit Filter: Gesundheit %.0f (erwartet 88)" % player.health)
	# Wucherungen: weghacken und Sperre
	await get_tree().process_frame
	var layer := scene.get_node("Terraformer/Patches")
	print("WORLD Wucherungs-Knoten in der Welt: ", layer.get_child_count())
	var first := layer.get_child(0) as OrganismNode.Patch
	for i in 3:
		first.axe_hit(player)
	await get_tree().process_frame
	print("WORLD Nach 3 Axthieben: %d Wucherungen, Proben %d" % [WorldState.patches.size(), Inventory.count("organism_sample")])
	var second: OrganismNode.Patch = null
	for c in get_tree().get_nodes_in_group("organism_patch"):
		if not c.is_queued_for_deletion():
			second = c
			break
	if second == null:
		WorldState._add_patch(Vector3(10, 0, -20))
		WorldState.changed.emit()
		await get_tree().process_frame
		second = get_tree().get_nodes_in_group("organism_patch")[0]
	var before := WorldState.patches.size()
	var barrier := Builder.place("growth_barrier", second.global_position + Vector3(2, 0, 0), 0.0)
	await get_tree().process_frame
	await get_tree().process_frame
	print("WORLD Myzel-Sperre: %d -> %d Wucherungen, in Gruppe: %s" % [before, WorldState.patches.size(), barrier.is_in_group("growth_barrier")])
	print("WORLD Ausbreitung blockiert bei Sperre: ", WorldState._blocked_by_barrier(barrier.global_position + Vector3(5, 0, 0)))
	# Knoten in der Höhle
	var src := scene.get_node("StreamCave/OrganismSource") as OrganismNode
	for i in 6:
		src.axe_hit(player)
	print("WORLD Knoten zerschlagen: lebt %s, Proben liegen: %s" % [WorldState.source_alive, src.has_node("OrganismSamples")])
	# Säulenrätsel
	var st := scene.get_node("AlienStructure") as AlienStructure
	player.health = 100.0
	st.pylon_pressed(AlienStructure.ORDER[1], player)
	print("WORLD Falsche Säule: Gesundheit %.0f, aus: %s" % [player.health, WorldState.pylons_off])
	for i in AlienStructure.ORDER:
		st.pylon_pressed(i, player)
	await get_tree().process_frame
	print("WORLD Struktur aus: %s, Kristallsplitter: %s, Wert jetzt %.2f" % [WorldState.structure_off, st.has_node("CrystalShard") or scene.find_child("CrystalShard", true, false) != null, WorldState.level()])
	# Hochsitz
	var ladder := scene.get_node("RangerTower/Ladder") as TowerLadder
	player.global_position = ladder.to_global(ladder.bottom)
	ladder.interact(player)
	await get_tree().create_timer(0.8).timeout
	print("WORLD Leiter hoch: y %.1f" % player.global_position.y)
	(scene.get_node("RangerTower/TowerDiary") as ResearchNote).interact(player)
	get_tree().call_group("research_menu", "close")
	ladder.interact(player)
	await get_tree().create_timer(0.8).timeout
	print("WORLD Leiter runter: y %.1f, Notizen %s" % [player.global_position.y, Research.notes])
	# Drohne: erfasst den Spieler draußen
	TimeManager.set_time(9, 23.0)
	TimeManager.running = false
	Engine.time_scale = 4.0
	player.global_position = Creature._ground(Vector3(-10, 0, -14)) + Vector3(0, 0.1, 0)
	var dr := AlienDrone.new()
	scene.add_child(dr)
	dr.global_position = Vector3(-10, AlienDrone.HEIGHT, -14)
	for i in 20:
		await get_tree().physics_frame
	print("WORLD Drohne Alarm: %s, Kreatur da: %s" % [dr._alarm_done, is_instance_valid(ThreatDirector.creature)])
	if is_instance_valid(ThreatDirector.creature):
		ThreatDirector.creature.queue_free()
	dr.queue_free()
	# Drohne + Stroboskop -> Teil fällt ab
	var strobe := Builder.place("strobe_light", Creature._ground(Vector3(5, 0, -8)), 0.0)
	strobe._strobe_time = 10.0
	player.global_position = Vector3(-1.0, 0.5, 1.0)
	var dr2 := AlienDrone.new()
	scene.add_child(dr2)
	dr2.global_position = Vector3(5, AlienDrone.HEIGHT, -8)
	for i in 5:
		await get_tree().physics_frame
	print("WORLD Drohne geblendet: Teil fällt %s, liegt da: %s" % [WorldState.drone_part_dropped, scene.has_node("DronePart")])
	dr2.queue_free()
	# Drohne + Störsender -> dreht ab
	var jam := Builder.place("signal_jammer", Creature._ground(Vector3(-6, 0, 10)), 0.0)
	var dr3 := AlienDrone.new()
	scene.add_child(dr3)
	dr3.global_position = Vector3(-6, AlienDrone.HEIGHT, 4)
	for i in 3:
		await get_tree().physics_frame
	print("WORLD Störsender: Drohne dreht ab %s" % dr3._leaving)
	dr3.queue_free()
	# Manipulator: lockt, verschwindet bei Nähe -> Hinterhalt
	var m := Manipulator.new()
	scene.add_child(m)
	await get_tree().create_timer(6.0).timeout
	print("WORLD Manipulator steht bei %s (Abstand Hütte %.0f m)" % [m.global_position.round(), Vector2(m.global_position.x, m.global_position.z).length()])
	player.global_position = m.global_position + (Vector3(0, m.global_position.y, 0) - m.global_position).normalized() * 8.0 + Vector3(0, 0.5, 0)
	for i in 5:
		await get_tree().physics_frame
	print("WORLD Manipulator verschwunden: %s, Kreatur greift an: %s" % [m._gone, is_instance_valid(ThreatDirector.creature)])
	Engine.time_scale = 1.0
	# Baupläne hinter Verknüpfungen
	for r: Dictionary in DataDB.recipes():
		if r["id"] in ["signal_jammer", "growth_barrier"]:
			print("WORLD Bauplan %s vorher frei: %s" % [r["id"], Research.recipe_unlocked(r)])
	Research.links_done.append_array(["link_drone", "link_growth"])
	for r: Dictionary in DataDB.recipes():
		if r["id"] in ["signal_jammer", "growth_barrier"]:
			print("WORLD Bauplan %s nachher frei: %s" % [r["id"], Research.recipe_unlocked(r)])
	# Speichern/Laden
	var ws := WorldState.get_state()
	WorldState.set_state({})
	WorldState.set_state(ws)
	print("WORLD Speichern/Laden: Struktur aus %s, Quelle lebt %s, Wucherungen %d" % [WorldState.structure_off, WorldState.source_alive, WorldState.patches.size()])
	print("WORLD Bauten noch da: ", is_instance_valid(jam), " ", is_instance_valid(barrier))


## Spannungsbogen und Auftritte ohne Angriff.
func _dread_test() -> void:
	for i in 10:
		await get_tree().physics_frame
	var scene := get_tree().current_scene
	var player := get_tree().get_first_node_in_group("player") as Player
	ThreatDirector.set_process(false)
	var kinds := []
	for d in range(1, 16):
		ThreatDirector.plan_night(d)
		kinds.append("%d:%s" % [d, ThreatDirector.night_kind])
	print("DREAD Nächte: ", " ".join(kinds))
	TimeManager.set_time(5, 23.0)
	TimeManager.running = false
	# Am Waldrand: im Augenwinkel bleibt sie, direkt angeschaut verschwindet sie
	player.global_position = Vector3(-3.0, 0.1, 10.0)
	player.rotation.y = 0.0
	player.head.rotation.x = 0.0
	await get_tree().physics_frame
	var a := Apparition.spawn(scene, "edge")
	for i in 30:
		await get_tree().physics_frame
	print("DREAD Waldrand nach 0,5 s (nicht angeschaut) noch da: ", is_instance_valid(a))
	var to := a.global_position - player.global_position
	player.rotation.y = atan2(-to.x, -to.z)
	for i in 60:
		await get_tree().physics_frame
	print("DREAD Waldrand angeschaut -> weg: ", not is_instance_valid(a))
	# Fenster: Spieler im Wohnzimmer
	player.global_position = Vector3(0.5, 0.5, 2.5)
	await get_tree().physics_frame
	var w := Apparition.spawn(scene, "window")
	print("DREAD Fenster-Gesicht: ", w != null)
	if w:
		var tw := w.global_position + Vector3(0, 2.2, 0) - player.camera.global_position
		player.rotation.y = atan2(-tw.x, -tw.z)
		for i in 60:
			await get_tree().physics_frame
		print("DREAD Fenster angeschaut -> weggeduckt: ", not is_instance_valid(w))
	# Nach dem Aufwachen im Haus: Spieler im Schlafzimmer
	player.global_position = Vector3(-3.5, 0.5, -2.8)
	player.rotation.y = 0.0
	await get_tree().physics_frame
	var ins := Apparition.spawn(scene, "inside")
	print("DREAD Im Haus erschienen: %s, Schlammspuren: %d" % [ins != null, get_tree().get_nodes_in_group("traces").size()])
	if ins:
		player.global_position = Vector3(-2.5, 0.5, -1.0)
		var ti := ins.global_position + Vector3(0, 1.9, 0) - player.camera.global_position
		player.rotation.y = atan2(-ti.x, -ti.z)
		player.head.rotation.x = 0.0
		for i in 30:
			await get_tree().physics_frame
		print("DREAD Im Haus angeschaut -> Blitz und weg: ", not is_instance_valid(ins))
	# Morgenspuren
	Traces.morning(scene, RandomNumberGenerator.new())
	print("DREAD Spuren am Morgen: ", get_tree().get_nodes_in_group("traces").size())
	Traces.clear(scene)
	# Erkundung: entdeckt den Spieler draußen -> starrt, verschwindet statt anzugreifen
	player.global_position = Vector3(-3.0, 0.1, 12.0)
	var c := Creature.new()
	scene.add_child(c)
	ThreatDirector.creature = c
	c.begin("probe")
	c.global_position = Creature._ground(Vector3(-3.0, 0, 22.0))
	c.state = Creature.State.OBSERVE
	c._timer = 30.0
	Engine.time_scale = 2.0
	for i in 240:
		await get_tree().physics_frame
	Engine.time_scale = 1.0
	print("DREAD Erkundung sieht Spieler -> verschwunden statt Jagd: ", not is_instance_valid(c))
	# Andere Gegner: laufen eine Weile ohne Fehler, Muster wechseln
	player.global_position = Vector3(-1.0, 0.5, 1.0)
	for k in 3:
		var dr := AlienDrone.new()
		scene.add_child(dr)
		print("DREAD Drohne %d: %d Wegpunkte, erster Halt %.1f s" % [k, dr._path.size(), dr._hold[0] if not dr._hold.is_empty() else 0.0])
	var m := Manipulator.new()
	scene.add_child(m)
	var m_start := m.global_position
	WorldState.source_alive = true
	WorldState.patches.clear()
	TimeManager.set_time(12, 8.0)
	for d in range(12, 20):
		WorldState.spread_day = 0
		TimeManager.set_time(d, 8.0)
		WorldState._spread_organism()
	var pts := []
	for q: Dictionary in WorldState.patches:
		pts.append("(%d,%d)" % [int(q["x"]), int(q["z"])])
	print("DREAD Wucherungen nach 8 Tagen: ", " ".join(pts))
	Engine.time_scale = 4.0
	await get_tree().create_timer(60.0).timeout
	Engine.time_scale = 1.0
	print("DREAD Manipulator gewandert: %s -> %s" % [m_start.round(), m.global_position.round() if is_instance_valid(m) else "weg"])
	print("DREAD Drohnen noch unterwegs: ", get_tree().get_nodes_in_group("drone").size())
	# Ab Nacht 6: Ansehen schadet, Wegsehen klingt ab; Lampe flackert
	for x in get_tree().get_nodes_in_group("drone") + get_tree().get_nodes_in_group("manipulator"):
		x.queue_free()
	TimeManager.set_time(7, 23.0)
	TimeManager.running = false
	player.health = 100.0
	player.global_position = Vector3(-3.0, 0.1, 10.0)
	player.velocity = Vector3.ZERO
	var k := Creature.new()
	scene.add_child(k)
	ThreatDirector.creature = k
	k.begin("attack")
	k.global_position = Creature._ground(Vector3(-3.0, 0, 20.0))
	player.set_flashlight(true)
	k.state = Creature.State.LEAVE  # steht still, greift nicht an
	k._path.clear()
	k.state = Creature.State.RECOIL
	k._timer = 999.0
	var tk := k.global_position + Vector3(0, 1.4, 0) - player.camera.global_position
	player.rotation.y = atan2(-tk.x, -tk.z)
	player.head.rotation.x = 0.0
	for i in 120:
		await get_tree().physics_frame
	print("DREAD Nacht 7, 2 s hingesehen: Stärke %.2f, Gesundheit %.0f" % [player.mind, player.health])
	player.rotation.y += PI
	for i in 180:
		await get_tree().physics_frame
	print("DREAD 3 s weggesehen: Stärke %.2f" % player.mind)
	player.set_flashlight(true)
	player.hands.interfere(0.5, 0.6)
	await get_tree().create_timer(0.7).timeout
	print("DREAD Lampe gestört: eingeschaltet %s, leuchtet %s" % [player.flashlight.visible, player.light_shining()])
	await get_tree().create_timer(0.6).timeout
	print("DREAD Lampe danach: leuchtet %s" % player.light_shining())
	k.queue_free()


## Veränderungen draußen, Radio-Nachrichten, Test-Sprung zu Tag 10.
func _changes_test() -> void:
	for i in 10:
		await get_tree().physics_frame
	var scene := get_tree().current_scene
	ThreatDirector.set_process(false)
	var nc := scene.get_node("NightChanges") as NightChanges
	for k: String in NightChanges.KINDS:
		var c := nc._make(k, Vector2i(2, 2))
		nc.active.append(c)
		nc._apply(c)
	await get_tree().process_frame
	var bench := scene.get_node("Cabin/PorchBench") as Node3D
	var seg_name := ""
	for c: Dictionary in nc.active:
		if c["kind"] == "fence_hole":
			seg_name = c["seg"]
	var seg := scene.get_node("Garden/" + seg_name) as Node3D
	print("CHANGES alle %d Arten angewendet. Bank bei %s, Zaunfeld %s sichtbar %s, Schuppentür offen %s, Vogelscheuche %.0f°" % [
		nc.active.size(), (bench.global_transform * NightChanges.BENCH_CENTER).round(), seg_name, seg.visible,
		(scene.get_node("Shed/ShedDoor") as Door).is_open, rad_to_deg((scene.get_node("CornField/Scarecrow") as Node3D).rotation.y)])
	var st := nc.get_state()
	TimeManager.set_time(5, 8.0)
	nc._expire()
	await get_tree().process_frame
	print("CHANGES nach Ablauf: aktiv %d, Bank zurück %s, Zaunfeld sichtbar %s, Handtücher %s" % [nc.active.size(),
		bench.transform.is_equal_approx(Transform3D()), seg.visible,
		[(scene.get_node("Garden/Towels/Towel_0") as Node3D).visible, (scene.get_node("Garden/Towels/Towel_1") as Node3D).visible, (scene.get_node("Garden/Towels/Towel_2") as Node3D).visible]])
	nc.set_state(st)
	await get_tree().process_frame
	await get_tree().process_frame
	print("CHANGES Laden stellt wieder her: aktiv %d, Zaunfeld sichtbar %s" % [nc.active.size(), seg.visible])
	# Radio
	TimeManager.set_time(1, 10.0)
	var radio := scene.get_node("Cabin/Radio") as Radio
	radio.heard_day = 0
	print("RADIO neue Nachricht: %s" % radio.has_new_message())
	radio.set_on(true)
	print("RADIO an, Nachricht gehört: %s, Text: %s" % [not radio.has_new_message(), radio.message_for_today().left(50)])
	Engine.time_scale = 8.0
	await get_tree().create_timer(26.0).timeout
	Engine.time_scale = 1.0
	print("RADIO nach ~26 s: an %s" % radio.is_on)
	for d in [2, 6, 11, 17]:
		TimeManager.set_time(d, 10.0)
		print("RADIO Tag %d neu: %s – %s" % [d, radio.has_new_message(), radio.message_for_today().left(60)])
	# Test-Sprung
	TimeManager.set_time(3, 10.0)
	Survival.hunger = 20.0
	var pm := scene.get_node("PauseMenu") as PauseMenu
	pm._test_jump_to_day(10)
	await get_tree().process_frame
	print("SPRUNG: Tag %d %s, Hunger %.0f, Durst %.0f, Stufe %d, Wucherungen %d, Nacht: %s" % [TimeManager.day, TimeManager.get_clock_text(),
		Survival.hunger, Survival.thirst, WorldState.stage(), WorldState.patches.size(), ThreatDirector.night_kind])
	# Couch und Tablet
	var player2 := get_tree().get_first_node_in_group("player") as Player
	TimeManager.set_time(1, 21.0)
	player2.global_position = Vector3(-3.0, 0.5, 0.4)
	await get_tree().physics_frame
	var couch := scene.get_node("Cabin/Couch") as Couch
	print("COUCH Nachrichten an Tag 1: %d, ungelesen %d, Hinweis: %s" % [couch.available().size(), couch.unread_count(), couch.get_prompt(player2)])
	couch.interact(player2)
	await get_tree().process_frame
	var tm := scene.get_node("TabletMenu") as TabletMenu
	print("COUCH sitzt: %s, Tablet offen: %s, Augenhöhe %.2f, ungelesen jetzt %d" % [couch.sitting, tm.is_open(), player2.head.global_position.y, couch.unread_count()])
	tm.close()
	await get_tree().physics_frame
	print("COUCH aufgestanden: %s, Steuerung frei: %s" % [not couch.sitting, not player2.input_locked])
	# Kamin
	var fire := scene.get_node("Cabin/Fireplace") as Fireplace
	fire.burn_until = TimeManager.get_total_hours() + 3.0
	await get_tree().process_frame
	print("KAMIN 3 h Rest: Stärke %.2f" % fire.strength())
	fire.burn_until = TimeManager.get_total_hours() - 0.1
	await get_tree().process_frame
	print("KAMIN aus: Stärke %.2f, Prompt: %s" % [fire.strength(), fire.get_prompt(player2)])
	Inventory.add("wood", 1)
	fire.interact(player2)
	print("KAMIN mit Holz: Stärke %.2f, Holz übrig %d" % [fire.strength(), Inventory.count("wood")])
	# Müdigkeit
	ThreatDirector._activity_tonight = false
	ThreatDirector._tired_night = -1
	TimeManager.set_time(1, 22.9)
	ThreatDirector._check_tired()
	print("MÜDE geplant für %.2f (Gesamtstunde, 23–25 erwartet)" % ThreatDirector._tired_at)
	# Truhe
	var chest := scene.get_node("Cabin/StorageChest") as StorageChest
	Inventory.add("planks", 6)
	var before_p := Inventory.count("planks")
	chest.put("planks", 4)
	print("TRUHE rein: Rucksack %d -> %d, Truhe %d" % [before_p, Inventory.count("planks"), int(chest.items.get("planks", 0))])
	var cst := chest.get_state()
	chest.take("planks", 1)
	chest.set_state(cst)
	print("TRUHE Laden: Truhe %d (erwartet 4)" % int(chest.items.get("planks", 0)))
	chest.take("planks", 9999)
	print("TRUHE raus: Rucksack %d, Truhe leer %s" % [Inventory.count("planks"), not chest.items.has("planks")])
	var gm := scene.get_node("GameMenus") as GameMenus
	gm.open_chest(chest)
	await get_tree().process_frame
	print("TRUHE Menü offen: %s" % gm.is_open())
	gm.close()
	# Kreatur bleibt nicht immer die ganze Nacht
	var leaves := 0
	for i in 20:
		var cr := Creature.new()
		scene.add_child(cr)
		cr.begin("attack")
		if cr._leave_at > 0.0:
			leaves += 1
		cr.queue_free()
	print("KREATUR geht vor dem Morgen: %d von 20 (erwartet etwa 16)" % leaves)


## Verstecke, Überladung, Bärenfalle, Blut an der Spießbarrikade, Blechschere, Tiere.
func _gear_test() -> void:
	for i in 10:
		await get_tree().physics_frame
	var scene := get_tree().current_scene
	var player := get_tree().get_first_node_in_group("player") as Player
	# Verstecke
	for path: String in ["Cabin/Wardrobe", "Shed/Locker"]:
		var h := scene.get_node_or_null(path) as HideSpot
		if h == null:
			print("VERSTECK FEHLT: ", path)
			continue
		player.set_flashlight(true)
		h.interact(player)  # E: Tür auf
		await get_tree().create_timer(0.5).timeout
		h.secondary_interact(player)  # R: hinein
		await get_tree().create_timer(0.9).timeout
		h.set_door(false)  # drinnen: E schließt die Tür
		await get_tree().create_timer(0.5).timeout
		print("VERSTECK %s: drin=%s, Tür zu=%s, versteckt=%s, Licht aus=%s" % [path, h.occupied, not h.door_open, player.is_hidden(), not player.flashlight.visible])
		h._leave()
		await get_tree().create_timer(0.8).timeout
		print("VERSTECK %s verlassen: versteckt=%s" % [path, player.is_hidden()])
	# Überladung
	var added := {}
	for id: String in ["fuel_can", "stone", "wood", "battery", "water", "food", "planks", "scrap"]:
		added[id] = Inventory.add(id, 12)
	print("ÜBERLADEN: %s (%.1f kg)" % [Inventory.overloaded(), Inventory.total_weight()])
	for id: String in added:
		Inventory.remove(id, int(added[id]))
	print("NICHT MEHR ÜBERLADEN: %s" % (not Inventory.overloaded()))
	# Bärenfalle: craften lassen wir weg, direkt aufstellen
	player.global_position = Creature._ground(Vector3(-10, 0, 14)) + Vector3(0, 0.05, 0)
	await get_tree().create_timer(0.3).timeout
	var hp := player.health
	var trap := Builder.place("bear_trap", Creature._ground(Vector3(-10, 0, 14.0)), 0.0)
	await get_tree().create_timer(0.3).timeout
	print("FALLE Spieler: gespannt=%s, Leben %.0f -> %.0f, festgehalten=%.1f s" % [trap.armed, hp, player.health, player.held_time])
	trap.interact(player)
	print("FALLE neu gespannt: ", trap.armed)
	player.global_position = Creature._ground(Vector3(-20, 0, 14)) + Vector3(0, 0.05, 0)
	TimeManager.set_time(6, 22.0)
	var c := Creature.new()
	scene.add_child(c)
	ThreatDirector.creature = c
	c.begin("attack")
	c.global_position = Creature._ground(Vector3(-10, 0, 14.0))
	await get_tree().physics_frame
	await get_tree().physics_frame
	var tissue := scene.find_children("TissueSample_*", "ItemPickup", false, false).size()
	print("FALLE Kreatur: gespannt=%s, Gewebeproben am Boden=%d, Zustand=%s" % [trap.armed, tissue, Creature.State.keys()[c.state]])
	# Spießbarrikade: Kreatur verletzt sich -> Blutprobe
	var spikes := Builder.place("spike_barricade", Creature._ground(Vector3(-14, 0, 8.0)), 0.0)
	spikes.bloody()
	var blood := scene.find_children("BloodSpike_*", "ItemPickup", false, false)
	print("BLUT an Spießen: %d Blutprobe(n)" % blood.size())
	if not blood.is_empty():
		(blood[0] as ItemPickup).interact(player)
	print("BLUTPROBE im Inventar: %d, Analyse vorhanden: %s" % [Inventory.count("alien_blood"), Research.analysis_for_find("alien_blood")])
	c.queue_free()
	ThreatDirector.creature = null
	# Blechschere: ohne sie kein Schrott vom Wagen
	var scrap := scene.find_children("Scrap", "ResourceNode", true, false)
	if not scrap.is_empty():
		var node := scrap[0] as ResourceNode
		print("SCHROTT ohne Schere: ", node.get_prompt(player))
		(scene.get_node("Cabin/TinSnips") as ItemPickup).interact(player)
		Inventory.select(Inventory.slot_of("tin_snips"))
		await get_tree().create_timer(0.4).timeout
		var before := Inventory.count("scrap")
		node.interact(player)
		await get_tree().create_timer(node.action_time + 0.8).timeout
		print("SCHROTT mit Schere: +%d" % (Inventory.count("scrap") - before))
		player.hands._primary()
		await get_tree().create_timer(0.6).timeout
		print("STICH ausgeführt (kein Fehler)")
	# Tiere: jede Art einmal, kurz laufen lassen
	var wl := scene.get_node("Wildlife") as Wildlife
	player.global_position = Creature._ground(Vector3(-30, 0, 30)) + Vector3(0, 0.05, 0)
	for k: String in ["hare", "snake", "squirrel", "birds", "butterfly", "insects", "flyover", "flock", "deer", "fox", "hedgehog"]:
		var a := wl.spawn_test(k, Creature._ground(Vector3(-30 + randf_range(-8, 8), 0, 22)))
		a.lifetime = 999.0
	await get_tree().create_timer(3.0).timeout
	var kinds := {}
	for a in get_tree().get_nodes_in_group("animal"):
		kinds[(a as Animal).kind] = (a as Animal).global_position
	print("TIERE nach 3 s: ", kinds.keys())
	# Spieler läuft auf die Bodentiere zu -> sie fliehen
	player.global_position = Creature._ground(Vector3(-30, 0, 22)) + Vector3(0, 0.05, 0)
	await get_tree().create_timer(1.0).timeout
	var fleeing := 0
	for a in get_tree().get_nodes_in_group("animal"):
		if (a as Animal)._state in ["flee", "fly", "curl"]:
			fleeing += 1
	print("TIERE fliehen/rollen sich ein: ", fleeing)
	print("GEAR TEST ENDE")


## Lauernde Gestalt auf den Kameras + Kreatur auf allen Vieren.
func _lurk_test() -> void:
	for i in 10:
		await get_tree().physics_frame
	var sv := get_tree().get_first_node_in_group("surveillance") as Surveillance
	sv.viewing = true
	await get_tree().process_frame
	for i in sv.cameras.size():
		sv.set_active(i)
		for k in Surveillance.LURK_SPOTS[i].size():
			var okk := sv.spawn_lurker(k)
			var lp := sv._lurker.global_position if sv._lurker else Vector3.ZERO
			var sp := sv.camera.unproject_position(lp + Vector3(0, 0.8, 0)) if sv._lurker else Vector2.ZERO
			print("  Kamera %d Ort %d: %s  Bildpunkt %s" % [i, k, okk, sp])
			sv._remove_lurker()
			sv._last_lurk = -1e9
		var ok := sv.spawn_lurker()
		print("LAUERN Kamera %d (%s): %s %s" % [i, sv.active_name(), ok, sv._lurker.global_position if sv._lurker else ""])
		await get_tree().create_timer(0.3).timeout
	sv.set_active(0)
	sv._last_lurk = -1e9
	TimeManager.set_time(1, 23.0)
	get_tree().call_group("hud", "open_monitor")
	get_tree().call_group("surveillance", "set_active", 0)
	get_tree().call_group("surveillance", "spawn_lurker", 1)
	for f in 20:
		await get_tree().process_frame
	print("LAUERN nach 20 Bildern noch da: %s, Strom %s, Ebenen %s, Kameramaske %s" % [sv._lurker != null and is_instance_valid(sv._lurker), PowerManager.has_power(),
			(sv._lurker.find_children("*", "VisualInstance3D", true, false)[0] as VisualInstance3D).layers if sv._lurker else -1, sv.camera.cull_mask])
	(get_tree().get_first_node_in_group("hud") as Hud).close_monitor()
	sv.set_active(0)
	print("LAUERN nach Umschalten weg: ", sv._lurker == null or not is_instance_valid(sv._lurker))
	sv.viewing = false
	TimeManager.set_time(7, 22.0)
	var scene := get_tree().current_scene
	var c := Creature.new()
	scene.add_child(c)
	c.global_position = Creature._ground(Vector3(-30, 0, 20))
	c.begin("prowl")
	c._crawl = true
	c._posture_timer = 99.0
	var p0 := c.global_position
	await get_tree().create_timer(3.0).timeout
	var hips := c._parts["hips"] as Node3D
	print("VIERBEINIG: Mischung %.2f, Hüfthöhe %.2f, Weg in 3 s: %.1f m" % [c._crawl_blend, hips.position.y, c.global_position.distance_to(p0)])
	c._crawl = false
	await get_tree().create_timer(1.5).timeout
	print("AUFRECHT: Mischung %.2f, Hüfthöhe %.2f" % [c._crawl_blend, hips.position.y])
	print("LURK TEST ENDE")


## Ergebnisse vom Analysegerät ans Tablet senden, Reiter durchschalten.
func _tablet_test() -> void:
	for i in 10:
		await get_tree().physics_frame
	Research.tier = 1
	Research.w17_in_device = true
	Inventory.add("alien_tissue", 1)
	Research.insert("alien_tissue")
	var id := Research.slot
	for exp: Dictionary in Research.analysis(id).get("experiments", []):
		if Research.experiment_blocker(exp) == "":
			Research.run_experiment(String(exp["id"]))
	print("TABLET ungesendet: %d" % Research.unsent_results().size())
	var n := Research.send_results()
	print("TABLET gesendet: %d, neu auf dem Tablet: %d, offen: %d" % [n, Research.tablet_new, Research.unsent_results().size()])
	var couch := get_tree().current_scene.get_node("Cabin/Couch") as Couch
	var player := get_tree().get_first_node_in_group("player") as Player
	couch.interact(player)
	await get_tree().create_timer(1.3).timeout
	var tm := get_tree().get_first_node_in_group("tablet_menu") as TabletMenu
	for t: String in ["archive", "notes", "inbox"]:
		tm._set_tab(t)
		await get_tree().process_frame
		await get_tree().process_frame
		var cnt := tm._wide.get_child_count() if t != "inbox" else tm._list.get_child_count()
		print("TABLET Reiter %s: %d Einträge, Titel %s" % [t, cnt, tm._title.text])
	print("TABLET neu nach Ansehen: ", Research.tablet_new)
	var st := Research.get_state()
	Research.set_state(st)
	print("TABLET Speichern/Laden gesendet: ", Research.sent.size())
	tm.close()
	print("TABLET TEST ENDE")


## Holzkorb, Tankanzeige, Hochsitz-Leiter, Bank, Monitorstuhl, Uhr-Display, Fensterzacken, Partikel.
func _extras_test() -> void:
	for i in 10:
		await get_tree().physics_frame
	var scene := get_tree().current_scene
	var player := get_tree().get_first_node_in_group("player") as Player
	var basket := scene.get_node("Cabin/WoodBasket") as WoodBasket
	var w0 := Inventory.count("wood")
	basket.interact(player)
	print("HOLZKORB genommen: Korb %d, Holz %d -> %d" % [basket.count, w0, Inventory.count("wood")])
	Inventory.add("wood", 5)
	for i in 6:
		basket.secondary_interact(player)
	print("HOLZKORB gefüllt: %d (max 4)" % basket.count)
	var gauge := scene.get_node("Cabin/FuelGauge") as FuelGauge
	await get_tree().process_frame
	print("TANK: ", gauge.get_prompt(player), "  Zeiger %.0f°" % gauge._needle.rotation_degrees.z)
	# Uhr: Licht an, F halten -> Display-Modus
	player.set_flashlight(true)
	player.hands.toggle_screen_mode()
	print("UHR Display-Modus: %s, LED leuchtet: %s, Umgebungslicht %.2f" % [player.hands.screen_mode, player.light_shining(), player.hands._screen_light.light_energy])
	player.hands.toggle_screen_mode()
	player.set_flashlight(false)
	# Bank
	var seat := scene.get_node("Cabin/PorchBench/Seat") as Seat
	player.global_position = Vector3(-0.45, Cabin.FLOOR_Y + 0.05, 6.0)
	await get_tree().create_timer(0.3).timeout
	seat.interact(player)
	await get_tree().create_timer(1.0).timeout
	print("BANK sitzt: Augen %.2f, gesperrt %s, umschauen %s" % [player.head.position.y, player.input_locked, player.look_only])
	var ev := InputEventAction.new()
	ev.action = "interact"
	ev.pressed = true
	seat._unhandled_input(ev)
	await get_tree().create_timer(0.9).timeout
	print("BANK aufgestanden: gesperrt %s" % player.input_locked)
	# Monitor
	var station := scene.get_node("Cabin/MonitorStation") as MonitorStation
	station.interact(player)
	await get_tree().create_timer(1.0).timeout
	var sv := get_tree().get_first_node_in_group("surveillance") as Surveillance
	print("MONITOR sitzt: Augen %.2f, Bild offen %s" % [player.head.position.y, sv.viewing])
	(get_tree().get_first_node_in_group("hud") as Hud).close_monitor()
	await get_tree().create_timer(0.9).timeout
	print("MONITOR aufgestanden: gesperrt %s, Bewegung %s" % [player.input_locked, player.is_physics_processing()])
	# Hochsitz
	var tower := scene.get_node("RangerTower") as Node3D
	var ladder := tower.get_node("Ladder") as TowerLadder
	player.global_position = ladder.to_global(ladder.bottom) + Vector3(0, 0.1, 0)
	await get_tree().create_timer(0.3).timeout
	ladder.interact(player)
	await get_tree().create_timer(5.0).timeout
	print("HOCHSITZ oben: %.1f m über Boden (Plattform %.1f), gesperrt %s" % [player.global_position.y - tower.global_position.y, RangerTower.DECK, player.input_locked])
	# springen: Dach muss halten
	player.velocity.y = 8.0
	var top_y := player.global_position.y
	for i in 40:
		await get_tree().physics_frame
		top_y = maxf(top_y, player.global_position.y)
	print("HOCHSITZ Sprung: höchster Punkt %.2f m über Plattform (Dach ca. 1,9 m)" % (top_y - tower.global_position.y - RangerTower.DECK))
	# Fenster zerbrechen
	var win := scene.get_node("Cabin/WindowBedroom") as CabinWindow
	win.receive_hit(9999.0)
	print("FENSTER zerbrochen: Zacken sichtbar %s, Glas weg %s" % [win._jagged.visible, not win._glass.visible])
	print("EXTRAS TEST ENDE")


func _aim(player: Player, target: Vector3) -> void:
	var eye := player.camera.global_position
	var d := target - eye
	player.rotation.y = atan2(-d.x, -d.z)
	player.head.rotation.x = atan2(d.y, Vector2(d.x, d.z).length())


## Selbstversorgung: Beete, Wasser, Kochen, Schlinge, Generator, Schrott, Kameras, Aufgaben, Tablet.
func _supplies_test() -> void:
	for i in 10:
		await get_tree().physics_frame
	var scene := get_tree().current_scene
	var player := get_tree().get_first_node_in_group("player") as Player
	var sv := get_tree().get_first_node_in_group("surveillance") as Surveillance
	print("AUFGABEN Start offen: %s" % [Tasks.open_goals().map(func(g: Dictionary) -> String: return g["id"])])
	print("KAMERAS am Start installiert: %d, Monitor Kamera 1 installiert: %s" % [Supplies.cameras.size(), sv.installed(0)])
	# Fundstücke
	for n: String in ["SupplyProps/Camera1Box", "SupplyProps/Camera2Box", "SupplyProps/Camera3Box", "SupplyProps/EmptyBottles",
			"SupplyProps/SeedsRadish", "SupplyProps/SeedsCarrot", "SupplyProps/SeedPotatoes", "SupplyProps/MotorOil", "SupplyProps/WateringCan"]:
		var pk := scene.get_node(n) as ItemPickup
		while pk.amount > 0:
			pk.interact(player)
	print("FUNDE: Kameras %d/%d/%d, Flaschen %d, Samen R%d K%d P%d, Öl %d, Kanne %d" % [Inventory.count("camera_1"), Inventory.count("camera_2"), Inventory.count("camera_3"),
		Inventory.count("bottle_empty"), Inventory.count("seeds_radish"), Inventory.count("seeds_carrot"), Inventory.count("seed_potato"), Inventory.count("motor_oil"), Inventory.count("watering_can")])
	await get_tree().create_timer(1.2).timeout
	# Hochbeet: säen, ohne Kanne gießen geht nicht, Kanne füllen, gießen, wachsen, ernten
	var bed := scene.get_node("Garden/GardenBed1") as GardenBed
	bed.interact(player)
	print("BEET gesät: %s (%s)" % [Supplies.bed_state(0), Supplies.beds[0]["crop"]])
	var barrel := [scene.get_node("Garden/RainBarrel")]
	var tap := scene.get_node("Cabin/KitchenTap") as WaterSource
	tap.secondary_interact(player)
	print("KANNE gefüllt: %d" % Supplies.can_water)
	bed.interact(player)
	print("BEET gegossen: %s, Kanne %d" % [Supplies.beds[0]["watered"], Supplies.can_water])
	var days := int(Supplies.config.crops[Supplies.beds[0]["crop"]]["days"])
	for d in days:
		Supplies.beds[0]["watered"] = true
		Supplies._on_day_changed(TimeManager.day)
	print("BEET nach %d Tagen: %s" % [days, Supplies.bed_state(0)])
	var before := Inventory.count("radish")
	bed.interact(player)
	print("ERNTE Radieschen +%d, Beet %s, Flag %s" % [Inventory.count("radish") - before, Supplies.bed_state(1 - 1), Tasks.flags.has("harvested")])
	# vertrocknen
	Supplies.plant(1, "seeds_carrot")
	for d in Supplies.config.dry_days_to_wither:
		Supplies._on_day_changed(TimeManager.day)
	print("BEET 2 ohne Wasser: %s" % Supplies.bed_state(1))
	# Wasser: Hahn = sauber, Regentonne = roh, abkochen
	tap.secondary_interact(player)
	print("FLASCHE am Hahn: Wasser %d" % Inventory.count("water"))
	if not barrel.is_empty():
		(barrel[0] as WaterSource).secondary_interact(player)
	print("FLASCHE draußen (%s): roh %d, verseucht %d" % [barrel[0].label if not barrel.is_empty() else "-", Inventory.count("water_raw"), Inventory.count("water_tainted")])
	Inventory.use("water")
	print("TRINKEN: leere Flaschen zurück %d" % Inventory.count("bottle_empty"))
	# Küchenofen
	var stove := scene.get_node("Cabin/CookStove") as CookStove
	Inventory.add("wood", 3)
	stove.interact(player)
	await get_tree().process_frame
	stove.interact(player)
	await get_tree().process_frame
	print("OFEN an: %s" % stove.lit())
	var menus := get_tree().get_first_node_in_group("game_menus")
	print("OFEN Menü offen: %s, Station %s" % [menus.call("is_open") if menus.has_method("is_open") else "?", menus.get("_station")])
	get_tree().call_group("game_menus", "close")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Inventory.add("meat_raw", 1)
	var h0 := TimeManager.hour
	for r: Dictionary in DataDB.recipes():
		if r.get("id", "") == "meat_cooked":
			menus.call("_on_craft", r)
	print("KOCHEN: Fleisch gebraten %d, Zeit +%.2f h" % [Inventory.count("meat_cooked"), TimeManager.hour - h0])
	# Schlinge
	var snare := Builder.place("snare", Vector3(30, Terrain.height_at(30, 30), 30), 0.0)
	var saved := Supplies.config.snare_catch_chance
	Supplies.config.snare_catch_chance = 1.0
	Supplies._on_day_changed(TimeManager.day)
	Supplies.config.snare_catch_chance = saved
	print("SCHLINGE Fang: %s, Hase sichtbar %s" % [Builder.record(snare.uid).get("caught", false), snare._catch.visible if snare._catch else false])
	snare.interact(player)
	print("SCHLINGE geleert: Fleisch %d" % Inventory.count("meat_raw"))
	# Generator: Wartung, Holzvergaser, Zelle
	var svc := scene.get_node("Shed/GeneratorService") as GeneratorService
	Supplies.generator_condition = 30.0
	svc.interact(player)
	print("WARTUNG mit Öl: Zustand %.0f" % Supplies.generator_condition)
	Inventory.add("gasifier_kit", 1)
	svc.interact(player)
	var gen := scene.get_node("Shed/Generator")
	PowerManager.fuel = 50.0
	Inventory.add("wood", 2)
	gen.secondary_interact(player)
	print("HOLZVERGASER: eingebaut %s, Tank %.0f" % [Supplies.gasifier, PowerManager.fuel])
	Inventory.add("cell_adapter", 1)
	svc.interact(player)
	Inventory.add("energy_cell", 1)
	PowerManager.fuel = 10.0
	gen.secondary_interact(player)
	print("ZELLE: Adapter %s, Tank %.0f" % [Supplies.cell_adapter, PowerManager.fuel])
	# Schrott-Fundstellen
	var spots := scene.get_node("ScrapField").get_children().filter(func(n: Node) -> bool: return n is ScrapSpot)
	print("SCHROTT Fundstellen: %d (Daten %d)" % [spots.size(), Supplies.scrap_spots.size()])
	if not spots.is_empty():
		var sp := spots[0] as ScrapSpot
		Inventory.add("tin_snips", 1)
		Inventory.set_slot(0, "tin_snips")
		Inventory.select(0)
		var sc := Inventory.count("scrap")
		sp.interact(player)
		await get_tree().create_timer(3.0).timeout
		await get_tree().process_frame
		print("SCHROTT abgebaut: +%d, Stelle weg %s" % [Inventory.count("scrap") - sc, not is_instance_valid(sp) or sp.is_queued_for_deletion()])
	# Kamera anbringen: vor der Ostwand stehen und hochzielen
	var bc := get_tree().get_first_node_in_group("build_controller") as BuildController
	player.global_position = Vector3(Cabin.HALF_X + 2.5, Terrain.height_at(Cabin.HALF_X + 2.5, -1.0) + 0.1, -1.0)
	await get_tree().create_timer(0.3).timeout
	_aim(player, Vector3(Cabin.HALF_X + 0.15, Cabin.FLOOR_Y + 2.3, -1.0))
	bc.start("camera_1")
	for i in 4:
		await get_tree().physics_frame
	print("KAMERA Ostwand gültig: %s (Vorschau %s)" % [bc._valid, bc._cam_preview != null])
	var cq := PhysicsRayQueryParameters3D.create(player.camera.global_position, player.camera.global_position - player.camera.global_transform.basis.z * 6.0)
	cq.exclude = [player.get_rid()]
	var ch := player.get_world_3d().direct_space_state.intersect_ray(cq)
	print("  Treffer: %s" % [[ch.get("collider"), (ch.get("collider") as Node).get_path() if ch.get("collider") else "", ch.get("position"), ch.get("normal")] if not ch.is_empty() else "nichts"])
	_aim(player, Vector3(Cabin.HALF_X + 0.15, Cabin.FLOOR_Y + 0.8, -1.0))
	for i in 3:
		await get_tree().physics_frame
	print("KAMERA zu tief gültig: %s" % bc._valid)
	_aim(player, Vector3(Cabin.HALF_X + 0.15, Cabin.FLOOR_Y + 2.3, -1.0))
	for i in 3:
		await get_tree().physics_frame
	bc._cam_yaw = deg_to_rad(30.0)
	bc._camera_place()
	await get_tree().process_frame
	await get_tree().process_frame
	print("KAMERA 1 angebracht: %s, Inventar %d, Surveillance %s (%s)" % [Supplies.camera_installed(0), Inventory.count("camera_1"), sv.installed(0), sv.active_name()])
	# drinnen geht nicht
	player.global_position = Vector3(3.0, Cabin.FLOOR_Y + 0.1, -1.0)
	await get_tree().create_timer(0.3).timeout
	_aim(player, Vector3(Cabin.HALF_X - 0.15, Cabin.FLOOR_Y + 2.2, -1.0))
	bc.start("camera_2")
	for i in 4:
		await get_tree().physics_frame
	print("KAMERA innen gültig: %s" % bc._valid)
	# Schuppen außen
	player.global_position = Shed.ORIGIN + Vector3(0, 0, Shed.HALF.y + 2.0)
	player.global_position.y = Terrain.height_at(player.global_position.x, player.global_position.z) + 0.1
	await get_tree().create_timer(0.3).timeout
	_aim(player, Shed.ORIGIN + Vector3(0.5, 1.8, Shed.HALF.y))
	for i in 4:
		await get_tree().physics_frame
	print("KAMERA Schuppen gültig: %s" % bc._valid)
	bc._camera_place()
	bc.stop()
	await get_tree().process_frame
	await get_tree().process_frame
	print("KAMERAS installiert: %d, Monitor-Slots %s/%s/%s" % [Supplies.cameras.size(), sv.installed(0), sv.installed(1), sv.installed(2)])
	# abbauen
	var cam1: SecurityCamera = sv.cameras[0]
	cam1.interact(player)
	await get_tree().process_frame
	await get_tree().process_frame
	print("KAMERA 1 abgebaut: installiert %s, Inventar %d" % [sv.installed(0), Inventory.count("camera_1")])
	# Aufgaben + Tablet
	Tasks._evaluate(true)
	print("AUFGABEN erledigt: %s" % [Tasks.done.duplicate()])
	print("AUFGABEN offen: %s" % [Tasks.open_goals().map(func(g: Dictionary) -> String: return g["id"])])
	print("ROUTINE: %s" % [Tasks.daily().map(func(d: Dictionary) -> String: return "%s=%s" % [d["title"], d["done"]])])
	var couch := scene.get_node("Cabin/Couch") as Couch
	get_tree().call_group("tablet_menu", "open", couch)
	var tm := get_tree().get_first_node_in_group("tablet_menu") as TabletMenu
	print("TABLET Reiter: %s" % (tm._tabs["tasks"] as Button).text)
	tm._set_tab("tasks")
	await get_tree().process_frame
	await get_tree().process_frame
	print("TABLET Aufgaben-Zeilen: %d, ungesehen %d" % [tm._wide.get_child_count(), Tasks.unseen])
	tm.close()
	# Spielstand
	var st := Supplies.get_state()
	Supplies.set_state(st)
	print("SPIELSTAND: Beete %d, Kameras %d, Vergaser %s" % [Supplies.beds.size(), Supplies.cameras.size(), Supplies.gasifier])


## Große Welt: Rechenzeit, Orte, Seen, Nachladen.
func _map_test() -> void:
	var t := Time.get_ticks_msec()
	for i in 2000:
		Terrain.height_at(randf_range(-1000, 1000), randf_range(-1000, 1000))
	print("MAP 2000 Höhen draußen: %d ms" % (Time.get_ticks_msec() - t))
	t = Time.get_ticks_msec()
	for i in 2000:
		Terrain.height_at(randf_range(-80, 80), randf_range(-80, 80))
	print("MAP 2000 Höhen im Tal: %d ms" % (Time.get_ticks_msec() - t))
	t = Time.get_ticks_msec()
	for i in 2000:
		Terrain.ground_color(randf_range(-1000, 1000), randf_range(-1000, 1000), 10.0, 0.9, true)
	print("MAP 2000 Farben: %d ms" % (Time.get_ticks_msec() - t))
	for id: String in WorldMap.places():
		var p := WorldMap.place_point(id)
		print("MAP Ort %s: %s" % [id, p])
	for l: Dictionary in WorldMap.lakes():
		print("MAP See %s: Spiegel %.1f bei %s" % [l["id"], WorldMap.lake_level(l), l["pos"]])
	print("MAP Bachbett z -1000/0/500/885/1100: %.1f %.1f %.1f %.1f %.1f" % [Terrain.stream_bed_height(-1000), Terrain.stream_bed_height(0), Terrain.stream_bed_height(500), Terrain.stream_bed_height(885), Terrain.stream_bed_height(1100)])
	# Nachladen: Spieler weit weg teleportieren
	var player := get_tree().get_first_node_in_group("player") as Player
	var terrain := get_tree().current_scene.get_node("Terrain") as Terrain
	for id: String in ["kapelle", "funkmast", "aussenstelle"]:
		var p := WorldMap.place_point(id)
		t = Time.get_ticks_msec()
		terrain.load_around(p, 70.0)
		print("MAP Laden um %s: %d ms" % [id, Time.get_ticks_msec() - t])
		player.global_position = p + Vector3(0, 2, 0)
		var frames := 0
		var t0 := Time.get_ticks_msec()
		while frames < 600:
			await get_tree().process_frame
			frames += 1
			if terrain._job.is_empty() and terrain._next_missing(player.global_position) == Vector2i(999999, 0):
				break
		print("MAP alles geladen bei %s nach %d Bildern (%d ms), Stücke %d, Spieler y %.1f / Boden %.1f" % [id, frames, Time.get_ticks_msec() - t0, terrain._chunks.size(), player.global_position.y, p.y])


## Alle Orte der großen Welt abgehen: Funde, Notizen, Baupläne zählen, Boden prüfen; dazu Fernglas,
## Karte, Zelt, Funkmast, Sprengstofflager, Bauplan → Rezept, Torf als Brennstoff, Waten, Moor.
func _places_test() -> void:
	for i in 10:
		await get_tree().physics_frame
	var scene := get_tree().current_scene
	var player := get_tree().get_first_node_in_group("player") as Player
	var terrain := scene.get_node("Terrain") as Terrain
	var wild := scene.get_node("WildForest") as WildForest
	var places := scene.get_node("Places")
	for root: Node in places.get_children():
		var id := String(root.name)
		var p := WorldMap.place_point(id)
		terrain.load_around(p, 70.0)
		wild.update_around(p, 0.0)
		player.global_position = p + Vector3(0, 1.5, 0)
		player.velocity = Vector3.ZERO
		for i in 20:
			await get_tree().physics_frame
		var pickups := root.find_children("*", "ItemPickup", true, false)
		var notes := root.find_children("*", "ResearchNote", true, false)
		var bps := root.find_children("*", "Blueprint", true, false)
		var items: PackedStringArray = []
		for pk: ItemPickup in pickups:
			items.append("%s×%d" % [pk.item_id, pk.amount])
		print("ORT %-14s Boden %.1f  Spieler y %.1f  auf Boden: %s  Funde: %s  Notizen %d  Baupläne %d  besucht %s" % [id, p.y, player.global_position.y,
			absf(player.global_position.y - p.y) < 6.0, ", ".join(items), notes.size(), bps.size(), Tasks.flags.has("visit_" + id)])
		# alles einsammeln/lesen
		for pk: ItemPickup in pickups:
			while pk.amount > 0:
				var before := pk.amount
				pk.interact(player)
				if pk.amount == before:
					break
		for n: ResearchNote in notes:
			Research.read_note(n.note_id)
		for b: Blueprint in bps:
			b.interact(player)
	print("BAUPLÄNE: %s" % [Research.blueprints])
	for r: Dictionary in DataDB.recipes():
		if r.has("blueprint"):
			print("REZEPT %s frei: %s" % [r["id"], Research.recipe_unlocked(r)])
	# Funkmast reparieren (Funkteile + Batterie)
	Inventory.add("battery", 1)
	var mast := places.get_node("funkmast/TechHut/MastRepair") as PlaceInspect
	mast.interact(player)
	print("FUNKMAST repariert: %s, Flag %s" % [mast.done, Tasks.flags.has("mast_repaired")])
	var bunker := places.get_node("steinbruch/Bunker/BunkerDoor") as PlaceInspect
	var ex := Inventory.count("explosive")
	bunker.interact(player)
	print("SPRENGSTOFFLAGER offen: %s, Sprengstoff +%d" % [bunker.done, Inventory.count("explosive") - ex])
	var shaft := places.get_node("aussenstelle/ShaftB/ShaftLock") as PlaceInspect
	shaft.interact(player)
	print("SCHACHT B offen: %s" % shaft.done)
	var scope := places.get_node("wetterstation/Telescope") as PlaceInspect
	print("FERNROHR: %s" % scope.text_provider.call())
	# Torf als Brennstoff
	Inventory.remove("wood", Inventory.count("wood"))
	print("BRENNSTOFF: Torf %d, zählt als Brennstoff %d" % [Inventory.count("peat"), Inventory.count_fuel()])
	# Heilen
	player.health = 40.0
	Inventory.use("medkit")
	print("VERBAND: Gesundheit %.0f" % player.health)
	# Karte
	var map := scene.get_node("MapScreen") as MapScreen
	var t := Time.get_ticks_msec()
	map.open()
	await get_tree().process_frame
	await get_tree().process_frame
	print("KARTE offen: %s, Markierungen %d, Bild in %d ms" % [map.is_open(), map._marks.get_child_count(), Time.get_ticks_msec() - t])
	map.close()
	# Fernglas
	Input.action_press("zoom")
	for i in 40:
		await get_tree().process_frame
	print("FERNGLAS: Sichtfeld %.0f°" % player.camera.fov)
	Input.action_release("zoom")
	# Zelt bei der Kapelle aufbauen und Schlafen anbieten
	var kp := WorldMap.place_point("kapelle") + Vector3(14, 0, 6)
	kp.y = Terrain.height_at(kp.x, kp.z)
	var tent := Builder.place("tent", kp, 0.0)
	TimeManager.set_time(TimeManager.day, 22.0)
	print("ZELT: %s" % tent.get_prompt(player))
	# Waten: am Schwarzen See ins Tiefe laufen
	var lake: Dictionary = WorldMap.lakes()[0]
	var lc: Vector2 = lake["pos"]
	var shore := Vector3(lc.x, 0, lc.y + float(lake["r"]) * 0.97)
	shore.y = Terrain.height_at(shore.x, shore.z) + 0.2
	terrain.load_around(shore, 70.0)
	player.global_position = shore
	for i in 10:
		await get_tree().physics_frame
	Input.action_press("move_forward")
	player.rotation.y = 0.0
	for i in 240:
		await get_tree().physics_frame
	Input.action_release("move_forward")
	var depth := WorldMap.lake_level(lake) - player.global_position.y
	print("SEE: Spieler steht %.1f m tief im Wasser (darf nicht über 1.2), Abstand zur Mitte %.0f m" % [depth, Vector2(player.global_position.x, player.global_position.z).distance_to(lc)])
	# Moor: abseits vom Steg einsinken
	var pool: Vector3 = WorldMap.bogs()[0]["pools"][1]
	var mp := Vector3(pool.x + pool.z + 3.0, 0, pool.y)
	mp.y = Terrain.height_at(mp.x, mp.z) + 0.1
	terrain.load_around(mp, 50.0)
	player.global_position = mp
	player.health = 100.0
	for i in 400:
		await get_tree().physics_frame
	print("MOOR: Gesundheit nach ~6 s im Schlamm %.0f" % player.health)
	print("AUFGABEN-Flags Besuche: %d" % Tasks.flags.keys().filter(func(k: String) -> bool: return k.begins_with("visit_")).size())


## Zeltnacht, Kälte, Lagerfeuer, Sucher.
func _camp_test() -> void:
	for i in 10:
		await get_tree().physics_frame
	var scene := get_tree().current_scene
	var player := get_tree().get_first_node_in_group("player") as Player
	var terrain := scene.get_node("Terrain") as Terrain
	TimeManager.set_time(6, 22.5)
	ThreatDirector.set_process(false)
	# Wärme in der Hütte mit/ohne Kamin
	player.global_position = Vector3(-2, Cabin.FLOOR_Y + 0.1, 1)
	await get_tree().physics_frame
	print("WÄRME Hütte nachts: %.1f/h" % Survival.warmth_rate(player))
	# Lager bei der Kapelle
	var base := WorldMap.place_point("kapelle") + Vector3(16, 0, 10)
	base.y = Terrain.height_at(base.x, base.z)
	terrain.load_around(base, 70.0)
	player.global_position = base + Vector3(0, 0.3, 4)
	await get_tree().physics_frame
	print("WÄRME draußen nachts (Höhe %.0f m): %.1f/h" % [base.y, Survival.warmth_rate(player)])
	var tent := Builder.place("tent", base, 0.0) as Structure
	var fire := Builder.place("campfire", base + Vector3(0, 0, 3.2), 0.0) as Structure
	for i in 3:
		await get_tree().process_frame
	print("FEUER: %s, Wärme am Feuer %.2f, Rate %.1f/h" % [fire.fire.get_prompt(), fire.fire.heat_at(player.global_position), Survival.warmth_rate(player)])
	tent.camp.interact(player)
	await get_tree().create_timer(1.2).timeout
	print("ZELT drinnen: %s, Rate ohne Schlafsack %.1f/h" % [tent.camp.occupied(), Survival.warmth_rate(player)])
	Inventory.add("sleeping_bag", 1)
	print("ZELT mit Schlafsack: %.1f/h" % Survival.warmth_rate(player))
	print("ZELT-Ereignisse geplant: %d" % ThreatDirector.events.filter(func(e: Dictionary) -> bool: return e["type"] == "camp").size())
	# Alle Ereignisarten
	for k: String in ["steps", "shadow", "press", "voice", "light", "fire_out"]:
		tent.camp._busy = false
		tent.camp.camp_event(k)
		await get_tree().create_timer(1.0).timeout
		print("ZELT-Ereignis %s ok" % k)
	print("FEUER nach fire_out: brennt %s" % fire.fire.burning())
	fire.fire.secondary_interact()
	Inventory.add("wood", 2)
	fire.fire.interact()
	print("FEUER wieder an: %s" % fire.fire.burning())
	# Sucher: Licht im Zelt an → er findet das Zelt und reißt es auf
	player.health = 100.0
	tent.camp._busy = false
	var sk := Seeker.spawn_for(scene, tent.global_position)
	sk.global_position = tent.global_position + Vector3(12, 0, 0)
	sk.global_position.y = Terrain.height_at(sk.global_position.x, sk.global_position.z)
	sk._hold = 0.0
	if not player.light_shining():
		player.set_flashlight(true)
	print("SUCHER da: Licht im Zelt %s" % tent.camp.glowing())
	var t := 0.0
	while is_instance_valid(sk) and t < 40.0:
		await get_tree().create_timer(0.5).timeout
		t += 0.5
	print("SUCHER nach %.0f s: weg %s, Zelt zerrissen %s, Gesundheit %.0f, im Zelt %s" % [t, not is_instance_valid(sk), tent.camp.torn, player.health, tent.camp.occupied()])
	print("ZELT Prompt: %s" % tent.camp.get_prompt())
	Inventory.add("planks", 1)
	Inventory.add("nails", 3)
	tent.camp.interact(player)
	print("ZELT geflickt: %s" % (not tent.camp.torn))
	# Schlafen im Zelt: Kälte über die Nacht
	await get_tree().create_timer(1.0).timeout
	tent.camp.interact(player)
	await get_tree().create_timer(1.2).timeout
	Inventory.remove("sleeping_bag", 1)
	fire.fire.put_out()
	Survival.warmth = 70.0
	EventBus.sleep_requested.emit(7.0)
	await get_tree().create_timer(5.0).timeout
	print("SCHLAF ohne Schlafsack/Feuer: Wärme %.0f, Gesundheit %.0f, Uhr %s" % [Survival.warmth, player.health, TimeManager.get_clock_text()])
	# Sucher an der Hütte (nur beobachten/suchen)
	tent.camp.leave()
	await get_tree().create_timer(1.0).timeout
	TimeManager.set_time(7, 23.0)
	player.global_position = Vector3(-2, Cabin.FLOOR_Y + 0.1, 1)
	var sk2 := Seeker.spawn_for(scene, Vector3.ZERO)
	for i in 20:
		await get_tree().create_timer(0.5).timeout
	print("SUCHER an der Hütte: Zustand %s, Abstand zur Hütte %.0f m" % [Seeker.State.keys()[sk2.state] if is_instance_valid(sk2) else "weg", sk2.global_position.length() if is_instance_valid(sk2) else -1.0])
	print("RAMP: Wärme draußen tagsüber Rate: ", Survival.warmth_rate(player))


## W-17: Karton, Einbau, Ausbau nach der Verknüpfung, Suchgerät, Sucher spürt es.
func _w17_test() -> void:
	for i in 10:
		await get_tree().physics_frame
	var scene := get_tree().current_scene
	var player := get_tree().get_first_node_in_group("player") as Player
	var slot := scene.get_node("Cabin/Radio/W17Slot") as W17Slot
	var box := scene.get_node("Cabin/MovingBox") as MovingBox
	print("W17 Karton: %s" % box.get_prompt(player))
	box.interact(player)
	box.interact(player)
	print("W17 genommen: %d" % Inventory.count("w17"))
	for id: String in ["electronics", "battery", "scrap"]:
		Inventory.add(id, 3)
	for r: Dictionary in DataDB.recipes():
		if r["id"] == "analyzer_improvised":
			print("W17 Umbau: %s, Stufe %d, im Gerät %s, liest %s" % [Workbench.craft(r, get_tree()), Research.tier, Research.w17_in_device, Research.device_reads()])
	await get_tree().process_frame
	print("W17 Fassung vorher: %s" % slot.get_prompt(player))
	slot.interact(player)
	print("W17 noch im Gerät (ohne Verknüpfung): %s" % Research.w17_in_device)
	Research.links_done.append("link_w17")
	print("W17 Fassung nach Verknüpfung: %s" % slot.get_prompt(player))
	slot.interact(player)
	print("W17 ausgebaut: Inventar %d, Gerät liest %s" % [Inventory.count("w17"), Research.device_reads()])
	# Suchgerät: Signal an verschiedenen Orten
	for p: Vector3 in [Vector3(0, 0, 30), WorldMap.place_point("absturz"), WorldMap.place_point("schaefer"), WorldMap.place_point("wal") + Vector3(40, 0, 0)]:
		var sig := W17Locator.signal_at(p)
		print("W17 Signal bei (%.0f, %.0f): %.2f (%s)" % [p.x, p.z, sig[0], sig[1]])
	var loc := scene.get_node("W17Locator") as W17Locator
	await get_tree().process_frame
	print("W17 Anzeige: %s %s" % [loc._label.visible, loc._label.text])
	# Sucher spürt W-17 aus der Ferne
	TimeManager.set_time(7, 23.0)
	player.global_position = Vector3(-30, Terrain.height_at(-30, 40) + 0.2, 40)
	var sk := Seeker.spawn_for(scene, player.global_position)
	sk.global_position = player.global_position + Vector3(70, 0, 0)
	sk.global_position.y = Terrain.height_at(sk.global_position.x, sk.global_position.z)
	sk._path.clear()
	sk.state = Seeker.State.WATCH
	sk._hold = 30.0
	await get_tree().create_timer(1.2).timeout
	print("W17 Sucher reagiert: Zustand %s" % Seeker.State.keys()[sk.state])
	sk.queue_free()
	# wieder einsetzen
	player.global_position = Vector3(2.5, Cabin.FLOOR_Y + 0.1, 0.5)
	slot.interact(player)
	print("W17 wieder eingesetzt: %s, Gerät liest %s" % [Research.w17_in_device, Research.device_reads()])
	var st := Research.get_state()
	Research.set_state(st)
	print("W17 Spielstand: im Gerät %s" % Research.w17_in_device)
