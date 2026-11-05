extends Node
## Threat Director (GDD 8.4): plant jede Nacht, was passiert – und wann.
## Er entscheidet nur ÜBER Ereignisse; wie sich die Kreatur verhält,
## entscheidet ihre eigene KI (GDD 17.3).
##
## Drei getrennte Größen (GDD 8.1):
##  - threat_level: steigt langfristig mit den Tagen
##  - night_intensity: Würfelwurf pro Nacht (0 ruhig … 3 Angriff)
##  - Weltveränderung: kommt später mit dem World State Manager

signal night_planned(intensity: int)

const CONFIG_PATH := "res://data/threat/default_threat.tres"
const INTENSITY_NAMES := ["ruhig", "unheimlich", "Erkundung", "Angriff"]

var config: ThreatConfig
var threat_level: float = 1.0
var night_intensity: int = 0
## Geplante Ereignisse: {"at": Gesamtstunde, "type": String, "done": bool}
var events: Array[Dictionary] = []
var creature: Node = null
## Lernverhalten (GDD 9.5): wie oft wurde ein Zugang schon blockiert vorgefunden?
var blocked_memory: Dictionary = {}

var _planned_for_day: int = -1
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	config = load(CONFIG_PATH) as ThreatConfig
	if config == null:
		config = ThreatConfig.new()
	_rng.randomize()
	TimeManager.phase_changed.connect(_on_phase_changed)
	_plan_if_needed.call_deferred()


func reset_for_new_scene() -> void:
	creature = null
	_planned_for_day = -1
	events.clear()
	_plan_if_needed.call_deferred()


func _on_phase_changed(is_night: bool) -> void:
	if not is_night:
		# Morgengrauen: Kreatur verschwindet, nächste Nacht wird geplant.
		if is_instance_valid(creature):
			creature.call("leave")
		_plan_if_needed()


## Plant die kommende (oder laufende) Nacht, falls noch nicht geschehen.
func _plan_if_needed() -> void:
	var night_day := TimeManager.day
	if TimeManager.hour < TimeManager.config.day_start_hour:
		night_day -= 1  # Wir sind schon in der Nacht nach Mitternacht
	if night_day == _planned_for_day:
		return
	_planned_for_day = night_day
	plan_night(night_day)


func plan_night(night_day: int) -> void:
	threat_level = config.base_threat + float(night_day - 1) * config.threat_per_day
	night_intensity = _roll_intensity(night_day)
	events.clear()
	var start := float(night_day - 1) * 24.0 + TimeManager.config.night_start_hour
	var night_len := TimeManager.get_night_length_hours()
	# Kleine, mehrdeutige Ereignisse in jeder Nacht (GDD 2.3)
	var n := _rng.randi_range(config.ambient_events_per_night.x, config.ambient_events_per_night.y) + night_intensity * 2
	var pool := _event_pool(night_intensity)
	for i in n:
		_add(start + _rng.randf_range(0.6, night_len - 1.0), pool[_rng.randi() % pool.size()])
	# Kreatur
	if night_intensity >= 1:
		_add(start + _rng.randf_range(1.0, 3.5), "creature")
	if night_intensity >= 2 and _rng.randf() < config.outage_chance:
		_add(start + _rng.randf_range(2.5, 6.0), "outage")
	# Phase 8: neue Arten, sobald sich das Tal verändert (oder ab der dritten Nacht)
	var st := WorldState.stage()
	if (st >= 1 or night_day >= 3) and _rng.randf() < 0.45 + 0.1 * st:
		_add(start + _rng.randf_range(1.5, night_len - 2.0), "drone")
	if (st >= 1 or night_day >= 4) and night_intensity >= 1 and _rng.randf() < 0.35 + 0.1 * st:
		_add(start + _rng.randf_range(2.0, night_len - 2.5), "manipulator")
	events.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["at"] < b["at"])
	night_planned.emit(night_intensity)
	print("[ThreatDirector] Nacht %d: Bedrohung %.1f, Intensität %d (%s), %d Ereignisse" %
			[night_day, threat_level, night_intensity, INTENSITY_NAMES[night_intensity], events.size()])


## Welche kleinen Ereignisse in einer Nacht dieser Intensität vorkommen können.
## Mehrdeutig mit Absicht: Der Spieler weiß nie, ob wirklich etwas da ist (GDD 2.3, 9.6).
func _event_pool(intensity: int) -> Array[String]:
	var pool: Array[String] = ["twig", "steps", "silence", "camera_glitch"]
	if intensity >= 1:
		pool.append_array(["breath_wall", "phantom", "scratch", "roof", "flicker", "radio", "signal"])
	if intensity >= 2:
		pool.append_array(["knock_door", "rattle", "music_box", "handprint", "photo", "scratch", "roof"])
	return pool


func _roll_intensity(night_day: int) -> int:
	# Erste Nacht im Prototyp: die Kreatur zeigt sich und testet das Haus.
	if night_day == 1:
		return 2
	var w := config.intensity_weights.duplicate()
	var shift := clampf((threat_level - 1.0) * 0.3, 0.0, 2.0)
	for i in w.size():
		w[i] = w[i] * (1.0 + shift * float(i))
	var total := 0.0
	for x in w:
		total += x
	var roll := _rng.randf() * total
	for i in w.size():
		roll -= w[i]
		if roll <= 0.0:
			return i
	return w.size() - 1


func _add(at: float, type: String) -> void:
	events.append({"at": at, "type": type, "done": false})


func _process(_delta: float) -> void:
	var now := TimeManager.get_total_hours()
	for e in events:
		if not e["done"] and now >= e["at"]:
			e["done"] = true
			_fire(e["type"])


## Für das Schlafsystem (GDD 4.4): erstes störendes Ereignis zwischen jetzt und Aufwachzeit.
func first_disturbance(from_total: float, to_total: float) -> float:
	for e in events:
		if e["done"]:
			continue
		if e["type"] in ["creature", "outage", "drone", "manipulator", "steps", "breath_wall", "knock_door", "rattle", "scratch", "roof", "radio", "photo"] and e["at"] > from_total and e["at"] < to_total:
			return e["at"]
	return -1.0


func _fire(type: String) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var player := get_tree().get_first_node_in_group("player") as Node3D
	match type:
		"twig":
			SoundBank.play_at(scene, "twig", _random_forest_point(18.0, 30.0), -2.0, _rng.randf_range(0.8, 1.2))
		"steps":
			# Im Haus: eine Diele knarrt in einem anderen Zimmer. Draußen: Schritte im Wald.
			if player and Cabin.is_inside(player.global_position) and SoundBank.has_recording("floor_creak") and _rng.randf() < 0.6:
				var p := Vector3(_rng.randf_range(-5.0, 5.0), 0.6, _rng.randf_range(-3.5, 3.5))
				if p.distance_to(player.global_position) < 3.0:
					p = -p
				SoundBank.play_at(scene, "floor_creak", p, 0.0)
			else:
				_play_phantom_steps(scene)
		"breath_wall":
			var p := Vector3(_rng.randf_range(-6.5, 6.5), 1.4, -4.9 if _rng.randf() < 0.5 else 4.9)
			CreatureSounds.play_phrase(scene, "breath", p, -5.0, _rng.randf_range(4.0, 6.0), 14.0)
		"camera_glitch":
			EventBus.camera_glitch.emit(_rng.randi_range(0, 2), _rng.randf_range(2.0, 5.0))
		"phantom":
			EventBus.camera_phantom.emit(_rng.randi_range(0, 2), _rng.randf_range(4.0, 9.0))
		"silence":
			get_tree().call_group("nature_ambience", "silence_for", _rng.randf_range(20.0, 45.0))
		"scratch":
			SoundBank.play_at(scene, "scratch", _random_wall_point(), 0.0, _rng.randf_range(0.85, 1.1))
		"roof":
			SoundBank.play_at(scene, "roof_steps", Vector3(_rng.randf_range(-5.0, 5.0), Cabin.WALL_TOP + 1.2, _rng.randf_range(-3.0, 3.0)), 0.0)
		"flicker":
			for lamp in get_tree().get_nodes_in_group("lamp"):
				lamp.call("flicker", _rng.randf_range(1.5, 4.0))
		"radio":
			for r in get_tree().get_nodes_in_group("radio"):
				if not r.is_on:
					r.call("set_on", true)
		"signal":
			SoundBank.play_at(scene, "signal", _random_forest_point(15.0, 25.0) + Vector3(0, 2, 0), 2.0)
			for i in 3:
				EventBus.camera_glitch.emit(i, 3.0)
			for lamp in get_tree().get_nodes_in_group("lamp"):
				lamp.call("flicker", 2.5)
		"knock_door":
			# Klopfen an der Haustür – aber auf der Kamera ist niemand zu sehen.
			SoundBank.play_at(scene, "knock", Vector3(-3.0, 1.4, 4.75), 4.0, _rng.randf_range(0.9, 1.0))
		"rattle":
			var door := scene.get_node_or_null("Cabin/FrontDoor")
			if door:
				door.call("rattle")
		"music_box":
			# Der Manipulator lockt: eine Spieluhr irgendwo im dunklen Wald (GDD 9.3)
			SoundBank.play_at(scene, "music_box", _random_forest_point(20.0, 30.0) + Vector3(0, 1, 0), 0.0)
		"handprint":
			var windows := get_tree().get_nodes_in_group("entry_point").filter(func(e: Node) -> bool: return e is CabinWindow)
			if not windows.is_empty():
				windows[_rng.randi() % windows.size()].call("add_handprint")
		"photo":
			for ph in get_tree().get_nodes_in_group("family_photo"):
				if ph.rotation_degrees.x > -40.0:
					ph.rotation_degrees.x = -82.0
					SoundBank.play_at(scene, "picture_fall", ph.global_position, 0.0)
		"outage":
			if PowerManager.has_power():
				PowerManager.trigger_outage()
				if player:
					SoundBank.play_at(scene, "bang", Vector3(4.6, 1.0, -3.8), -4.0, 0.6)
		"creature":
			_spawn_creature(scene)
		"drone":
			if get_tree().get_nodes_in_group("drone").is_empty():
				var d := AlienDrone.new()
				d.name = "Drone"
				scene.add_child(d)
		"manipulator":
			if get_tree().get_nodes_in_group("manipulator").is_empty():
				var m := Manipulator.new()
				m.name = "Manipulator"
				scene.add_child(m)


## Hinterhalt / Alarm (Drohne, Manipulator): Kreatur greift an, nahe einer Stelle.
func spawn_ambush(at: Vector3) -> void:
	var scene := get_tree().current_scene
	if is_instance_valid(creature):
		creature.call("_start_chase")
		return
	var c := Creature.new()
	c.name = "Creature"
	scene.add_child(c)
	creature = c
	c.call("begin", "attack")
	c.global_position = Creature._ground(at)
	c.call("_start_chase")


func _spawn_creature(scene: Node) -> void:
	if is_instance_valid(creature):
		return
	var c := Creature.new()
	c.name = "Creature"
	scene.add_child(c)
	creature = c
	var mode := "observe"
	if night_intensity == 2:
		mode = "probe"
	elif night_intensity >= 3:
		mode = "attack"
	c.call("begin", mode)


func _play_phantom_steps(scene: Node) -> void:
	# Schritte im Laub – ohne Kreatur. Der Spieler weiß nicht, ob da etwas ist.
	var start := _random_forest_point(10.0, 16.0)
	var dir := Vector3(_rng.randf_range(-1, 1), 0, _rng.randf_range(-1, 1)).normalized()
	for i in 6:
		var p := start + dir * i * 0.7
		p.y = Terrain.height_at(p.x, p.z) + 0.1
		CreatureSounds.play(scene, "step", p, -3.0, _rng.randf_range(0.9, 1.05), 40.0)
		await get_tree().create_timer(0.6).timeout


func _random_forest_point(min_d: float, max_d: float) -> Vector3:
	var a := _rng.randf() * TAU
	var d := _rng.randf_range(min_d, max_d)
	var x := cos(a) * d
	var z := sin(a) * d
	return Vector3(x, Terrain.height_at(x, z) + 0.3, z)


func _random_wall_point() -> Vector3:
	var side := _rng.randi() % 4
	match side:
		0: return Vector3(_rng.randf_range(-5.5, 5.5), 1.2, 4.75)
		1: return Vector3(_rng.randf_range(-5.5, 5.5), 1.2, -4.75)
		2: return Vector3(-6.25, 1.2, _rng.randf_range(-4.0, 4.0))
	return Vector3(6.25, 1.2, _rng.randf_range(-4.0, 4.0))


## Lernverhalten: Zugang wurde verstärkt vorgefunden.
func remember_blocked(entry_name: String) -> void:
	blocked_memory[entry_name] = int(blocked_memory.get(entry_name, 0)) + 1
