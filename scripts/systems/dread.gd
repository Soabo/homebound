class_name Dread
extends Node
## Spannung, die man nicht vorhersehen kann (Christian 23.11.2026: „wie Resident Evil / Alien Isolation“).
## Läuft als Kind des ThreatDirectors und kümmert sich um drei Dinge:
##  1. Verstecke lernen: wer nachts im Schrank/Spind sitzt, macht sie neugierig – je öfter dasselbe Versteck und je
##     länger, desto eher kommt sie nachsehen (`HideHunt`). Wer lange versteckt bleibt, dem wird das Haus beschädigt.
##  2. Stille eskaliert: wer nachts wach ist und sich kaum bewegt, hört erst Schritte, dann Kratzen, Klopfen,
##     Rütteln … und dann kommt sie selbst.
##  3. Tagsüber nicht sicher: ein paar zufällige Vorfälle am Tag (Klopfen, Schritte, Schrei im Wald, Gestalt
##     zwischen den Bäumen, Gesicht am Fenster, selten der Zerfleischer).
## Dazu der Druck (`ThreatDirector.menace`): steigt mit jeder ruhigen Nacht, fällt nach einem Auftritt.
## Werte: ThreatConfig (Gruppen „Unberechenbar“, „Verstecke lernen“, „Stille eskaliert“, „Tagsüber nicht sicher“).

var td: Node   ## ThreatDirector
var _rng := RandomNumberGenerator.new()

# Verstecke
var hidden_secs: float = 0.0        ## so lange in dieser Nacht (am Stück, kurze Pausen zählen mit) versteckt
var hunts_tonight: int = 0
var _hide_check: float = 5.0
var _counted: Dictionary = {}       ## Versteck → in dieser Nacht schon als benutzt gezählt
var _unhidden: float = 0.0
var _damage_t: float = 30.0
var _damage_told := false
var _night_key: int = -1

# Stille
var still_stage: int = -1
var _still_t: float = 80.0
var _still_from := Vector3.INF
var _still_creature := false

# Tag
var _day_key: int = -1
var day_left: int = 0
var _day_t: float = 30.0


func _ready() -> void:
	_rng.randomize()


func cfg() -> ThreatConfig:
	return td.get("config") as ThreatConfig


func _process(delta: float) -> void:
	if get_tree().current_scene == null or not GameState.in_game() and not _tests_run():
		return
	var player := get_tree().get_first_node_in_group("player") as Player
	if player == null or GameState.dead:
		return
	var night: int = td.call("current_night")
	if night != _night_key:
		_night_key = night
		_reset_night()
	if TimeManager.is_night():
		_check_hiding(player, delta)
		_check_stillness(player, delta)
	else:
		_check_day(player, delta)


## Tests laufen ohne Spielszene als „in_game“ – dort sind die Prüfungen trotzdem aktiv.
func _tests_run() -> bool:
	return GameState.slot < 0


func _reset_night() -> void:
	hidden_secs = 0.0
	hunts_tonight = 0
	_counted.clear()
	_damage_told = false
	still_stage = -1
	_still_from = Vector3.INF
	_still_creature = false


func _quiet_time(player: Player) -> bool:
	var c := cfg()
	return td.call("current_night") <= c.calm_first_nights or SiegeNight.current != null or td.call("far_from_home") \
			or EventBus.sleeping or player.in_tent != null


# --- 1. Verstecke lernen ---------------------------------------------------------

func _check_hiding(player: Player, delta: float) -> void:
	var c := cfg()
	if player.is_hidden():
		hidden_secs += delta
		_unhidden = 0.0
		var key := String((player.hidden_in as Node).name)
		if hidden_secs > c.hide_use_seconds and not _counted.has(key):
			_counted[key] = true
			var uses: Dictionary = td.get("hide_uses")
			uses[key] = int(uses.get(key, 0)) + 1
	else:
		_unhidden += delta
		if _unhidden > 30.0:
			hidden_secs = 0.0
		return
	if _quiet_time(player) or is_instance_valid(HideHunt.current):
		return
	# Kosten des Versteckens: draußen machen sie sich am Haus zu schaffen
	if hidden_secs > c.hide_damage_after and String(td.get("night_kind")) != "quiet":
		_damage_t -= delta
		if _damage_t <= 0.0:
			_damage_t = _rng.randf_range(c.hide_damage_every.x, c.hide_damage_every.y)
			_house_damage()
	_hide_check -= delta
	if _hide_check > 0.0:
		return
	_hide_check = 5.0
	if td.call("current_night") < c.hide_hunt_from_night or hunts_tonight >= c.hide_hunt_max:
		return
	if randf_hunt() < hunt_chance(player):
		start_hunt(player)


func randf_hunt() -> float:
	return _rng.randf()


## Chance pro Prüfung (alle 5 s), dass sie das Versteck absucht.
func hunt_chance(player: Player) -> float:
	var c := cfg()
	if not player.is_hidden():
		return 0.0
	var key := String((player.hidden_in as Node).name)
	var uses := int((td.get("hide_uses") as Dictionary).get(key, 0))
	var p := float(c.hide_hunt_base.get(String(td.get("night_kind")), 0.01)) + float(uses) * c.hide_hunt_per_use
	p += maxf(hidden_secs - c.hide_safe_seconds, 0.0) / 60.0 * c.hide_hunt_per_minute
	return clampf(p * (1.0 + float(td.get("menace"))), 0.0, 0.6)


func start_hunt(player: Player) -> HideHunt:
	var spot := player.hidden_in as HideSpot
	if spot == null:
		return null
	var key := String(spot.name)
	var uses := int((td.get("hide_uses") as Dictionary).get(key, 0))
	# Ist die Kreatur gerade draußen, ist sie es, die hereinkommt
	var cr = td.get("creature")
	if is_instance_valid(cr):
		(cr as Node).queue_free()
	var h := HideHunt.start(get_tree().current_scene, spot, uses, cfg())
	if h:
		hunts_tonight += 1
		td.call("note_activity", "creature")
	return h


func _house_damage() -> void:
	var entries := get_tree().get_nodes_in_group("entry_point").filter(func(e: Node) -> bool:
		return e.has_method("receive_hit") and not bool(e.call("is_breached")))
	if entries.is_empty():
		return
	var e: Node3D = entries[_rng.randi() % entries.size()]
	e.call("receive_hit", cfg().hide_house_damage)
	SoundBank.play_at(get_tree().current_scene, "bang", e.global_position, 2.0, _rng.randf_range(0.7, 0.9))
	EventBus.screen_shake.emit(0.3)
	EventBus.fear_spike.emit(0.5)
	if not _damage_told:
		_damage_told = true
		EventBus.notify("Draußen reißt etwas an Fenstern und Türen. Je länger du dich versteckst, desto mehr geht kaputt.", 4.5)


# --- 2. Stille eskaliert ---------------------------------------------------------

func _check_stillness(player: Player, delta: float) -> void:
	var c := cfg()
	if _quiet_time(player):
		_still_from = Vector3.INF
		return
	if _still_from == Vector3.INF:
		_still_from = player.global_position
		_still_t = _rng.randf_range(c.still_every.x, c.still_every.y)
		return
	_still_t -= delta
	if _still_t > 0.0:
		return
	_still_t = _rng.randf_range(c.still_every.x, c.still_every.y)
	if player.global_position.distance_to(_still_from) > c.still_move_meters:
		still_stage = -1
		_still_from = player.global_position
		return
	_still_from = player.global_position
	still_stage += 1
	var quiet := String(td.get("night_kind")) == "quiet"
	var top := mini(c.still_steps.size() - 1, 1 if quiet else c.still_steps.size() - 1)
	if still_stage > top:
		still_stage = top
		if quiet:
			return
	escalate(String(c.still_steps[still_stage]))


func escalate(kind: String) -> void:
	if kind == "creature":
		if _still_creature or is_instance_valid(td.get("creature")):
			return
		_still_creature = true
		td.call("_fire", "creature" if td.call("current_night") >= cfg().visit_from_night else "sighting")
		return
	td.call("_fire", kind)


# --- 3. Tagsüber -----------------------------------------------------------------

func _check_day(player: Player, delta: float) -> void:
	var c := cfg()
	if TimeManager.day != _day_key:
		_day_key = TimeManager.day
		var extra := int(round(float(td.get("menace")) * c.day_menace_extra * _rng.randf()))
		day_left = _rng.randi_range(c.day_incidents.x, c.day_incidents.y) + extra if TimeManager.day >= c.day_from_day else 0
	_day_t -= delta
	if _day_t > 0.0:
		return
	_day_t = c.day_check_seconds * _rng.randf_range(0.6, 1.4)
	if day_left <= 0 or EventBus.sleeping or player.in_tent != null or SiegeNight.current != null:
		return
	if _rng.randf() >= c.day_incident_chance:
		return
	var inside := Cabin.is_inside(player.global_position) or Shed.is_inside(player.global_position)
	var kind := pick_day_kind(inside, player)
	if kind != "" and day_incident(kind, player):
		day_left -= 1


func pick_day_kind(inside: bool, player: Player) -> String:
	var c := cfg()
	var w: Dictionary = (c.day_inside_kinds if inside else c.day_outside_kinds).duplicate()
	if TimeManager.day < c.day_window_from_day:
		w.erase("window")
	if Story.phase < 2 or Vector2(player.global_position.x, player.global_position.z).length() < c.day_mauler_min_distance \
			or not get_tree().get_nodes_in_group("mauler").is_empty():
		w.erase("mauler")
	if not Cabin.is_inside(player.global_position):
		w.erase("window")
	var total := 0.0
	for k in w:
		total += float(w[k])
	if total <= 0.0:
		return ""
	var r := _rng.randf() * total
	for k in w:
		r -= float(w[k])
		if r <= 0.0:
			return String(k)
	return String(w.keys()[0])


func day_incident(kind: String, player: Player) -> bool:
	var scene := get_tree().current_scene
	var p := player.global_position
	match kind:
		"knock":
			SoundBank.play_at(scene, "knock", Vector3(-3.0, 1.4, 4.75), 4.0, _rng.randf_range(0.85, 0.95))
			EventBus.fear_spike.emit(0.45)
		"creak":
			var at := Vector3(_rng.randf_range(-5.0, 5.0), Cabin.FLOOR_Y + 0.2, _rng.randf_range(-3.5, 3.5))
			if at.distance_to(p) < 3.0:
				at = Vector3(-at.x, at.y, -at.z)
			SoundBank.play_at(scene, "board_creak", at, 0.0, 0.85)
		"roof":
			SoundBank.play_at(scene, "roof_steps", Vector3(p.x, Cabin.WALL_TOP + 1.2, p.z), -2.0)
			EventBus.fear_spike.emit(0.35)
		"radio":
			for r in get_tree().get_nodes_in_group("radio"):
				if not r.is_on:
					r.call("set_on", true, true)
		"window":
			if Apparition.spawn(scene, "window") == null:
				return false
		"steps":
			# Schritte im Laub hinter dir – sie hören auf, wenn du stehen bleibst
			_steps_behind(scene, player)
		"silence":
			get_tree().call_group("nature_ambience", "silence_for", _rng.randf_range(25.0, 50.0), true)
			EventBus.notify("Die Vögel sind verstummt.", 2.5)
		"scream":
			var back := player.global_transform.basis.z
			back.y = 0.0
			var at2 := p + back.normalized().rotated(Vector3.UP, _rng.randf_range(-1.2, 1.2)) * _rng.randf_range(45.0, 70.0)
			at2.y = Terrain.height_at(at2.x, at2.z) + 1.5
			CreatureSounds.play(scene, "shriek", at2, -4.0, _rng.randf_range(0.7, 0.85), 120.0)
			EventBus.fear_spike.emit(0.4)
		"watcher":
			if Apparition.spawn(scene, "forest") == null:
				return false
		"mauler":
			var m := Mauler.spawn_near(scene, p)
			if m == null:
				return false
			m.set_meta("day_hunt", true)
		_:
			return false
	return true


func _steps_behind(scene: Node, player: Player) -> void:
	var back := player.global_transform.basis.z
	back.y = 0.0
	var start := player.global_position + back.normalized() * _rng.randf_range(9.0, 14.0)
	for i in 5:
		if not is_instance_valid(scene) or not scene.is_inside_tree() or not is_instance_valid(player):
			return
		var q := start + (player.global_position - start).normalized() * float(i) * 0.6
		q.y = Terrain.height_at(q.x, q.z) + 0.1
		CreatureSounds.play(scene, "step", q, -4.0, _rng.randf_range(0.9, 1.05), 40.0)
		await get_tree().create_timer(0.55).timeout
