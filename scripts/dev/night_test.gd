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
		get_tree().quit()
		return
	_ran = true
	if mode == "events":
		await _event_test()
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
		sw.set_state(true)
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
