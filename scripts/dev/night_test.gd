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
			"flicker", "radio", "signal", "knock_door", "rattle", "music_box", "handprint", "photo", "outage"]
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
