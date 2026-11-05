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
	(scene.get_node("TissueSample_d1") as ItemPickup).interact(player)
	print("RESEARCH Gewebeprobe: ", Inventory.count("alien_tissue"))
	# Improvisiertes Gerät an der Werkbank
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
	var second := layer.get_child(0) as OrganismNode.Patch
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
