class_name Creature
extends Node3D
## Erste außerirdische Kreatur (GDD 9): ein großer, dünner "Grey".
## Mischt die Archetypen Beobachter, Jäger und Manipulator (GDD 9.3):
##  - observe: steht am Waldrand und starrt das Haus an; flieht vor Licht
##  - probe:   schleicht ums Haus, testet ein Fenster/die Tür, geht wieder
##  - attack:  versucht einzudringen; greift an, wenn der Spieler erreichbar ist
## Wahrnehmung (GDD 9.4): Sicht (abhängig von Licht), Geräusche, Taschenlampe.
## Der Threat Director entscheidet nur, DASS sie kommt – hier entscheidet sie, WIE.

enum State { ARRIVE, OBSERVE, PROWL, GO_ENTRY, HIT_ENTRY, REACH, CHASE, RECOIL, LEAVE }

## Werte (Tempo, Schaden, Entdecken, Klang) in data/creatures/creature.tres
var cfg: CreatureConfig = CreatureConfig.get_default()

## Beobachtungsplätze am Waldrand (Blick aufs Haus)
const OBSERVE_SPOTS := [
	Vector3(-3.5, 0, 25.0), Vector3(-25.0, 0, 3.0), Vector3(26.0, 0, -6.0),
	Vector3(2.0, 0, -23.0), Vector3(24.0, 0, 21.0), Vector3(-23.0, 0, -18.0),
]
## Ring ums Haus zwischen Hütte und Zaun (für Wege um die Hütte herum)
const RING := [
	Vector3(-8.5, 0, -7.0), Vector3(0.0, 0, -8.0), Vector3(8.5, 0, -7.0), Vector3(9.0, 0, 0.0),
	Vector3(8.5, 0, 8.0), Vector3(0.5, 0, 9.5), Vector3(-8.5, 0, 8.5), Vector3(-9.0, 0, 0.0),
]

var mode: String = "observe"
var state: State = State.ARRIVE
var _path: Array[Vector3] = []
var _speed: float = cfg.walk_speed
var _timer: float = 0.0
var _hit_timer: float = 0.0
var _step_timer: float = 0.0
var _breath_timer: float = 4.0
var _walk_phase: float = 0.0
var _target_entry: Node3D = null
var _spot: Vector3
var _lit_time: float = 0.0
var _lose_sight: float = 0.0
var _rng := RandomNumberGenerator.new()
var _parts: Dictionary = {}
var _attack_cooldown: float = 0.0
var _player: Player
var _voice: AudioStreamPlayer3D  ## gerade laufendes Atmen/Klicken
var _probes_left: int = 1
var _saw_player: bool = false
var _breaking: Structure = null
var _break_timer: float = 0.0
var _head_track: float = 0.0
var _seen_by_player: bool = false
var _unseen_time: float = 0.0


## Baut das Modell (auch für Trugbilder auf den Kameras verwendet).
static func build_model(root: Node3D) -> Dictionary:
	return CreatureModel.build(root)


func _ready() -> void:
	_rng.randomize()
	_parts = build_model(self)
	_player = get_tree().get_first_node_in_group("player") as Player
	EventBus.noise_made.connect(_on_noise)


## Wird vom Threat Director aufgerufen.
func begin(m: String) -> void:
	mode = m
	_probes_left = _rng.randi_range(cfg.probe_entries.x, cfg.probe_entries.y) if mode == "probe" else 99
	_spot = _pick_observe_spot()
	# Erscheint tief im Wald und läuft zum Beobachtungsplatz
	var dir := (_spot * Vector3(1, 0, 1)).normalized()
	global_position = _ground(_spot + dir * 22.0)
	_go([_spot], cfg.walk_speed)
	state = State.ARRIVE
	# Auf der Jagd bleibt sie nur eine Weile – manchmal die ganze Nacht
	_leave_at = -1.0
	if mode == "attack" and _rng.randf() >= cfg.whole_night_chance:
		_leave_at = TimeManager.get_total_hours() + _rng.randf_range(cfg.hunt_hours.x, cfg.hunt_hours.y)


var _leave_at: float = -1.0


func leave() -> void:
	if state == State.LEAVE:
		return
	state = State.LEAVE
	var away := (global_position * Vector3(1, 0, 1)).normalized()
	if away.length() < 0.1:
		away = Vector3(0, 0, -1)
	_go(_ring_path_to(_nearest_ring(global_position)) + [_nearest_observe_spot() + away * 25.0], cfg.prowl_speed)


# --- Hauptschleife ------------------------------------------------------

func _physics_process(delta: float) -> void:
	if _player == null or GameState.dead:
		return
	_timer -= delta
	_attack_cooldown -= delta
	var moving := false if is_instance_valid(_breaking) else _follow_path(delta)
	_animate(delta, moving)
	_sounds(delta, moving)
	var sees := _can_see_player()
	_update_light(delta)
	# Bemerkt den Spieler: Kopf dreht sich ruckartig zu ihm
	if sees and not _saw_player:
		_head_track = 4.0
		CreatureSounds.play(get_parent(), "head_snap", global_position + Vector3(0, 1.9, 0), -1.0, _rng.randf_range(0.9, 1.1))
	_saw_player = sees
	_head_track -= delta
	_check_vanish(delta)
	if _leave_at > 0.0 and TimeManager.get_total_hours() >= _leave_at and state not in [State.CHASE, State.LEAVE, State.REACH]:
		_leave_at = -1.0
		leave()
	_mind_and_light(delta)
	var eye := _parts.get("eye_mat") as StandardMaterial3D
	if eye:
		eye.emission_energy_multiplier = lerpf(eye.emission_energy_multiplier, 3.5 if _lit_time > 0.0 else 0.25, clampf(delta * 6.0, 0.0, 1.0))

	# Ein Bauwerk versperrt den Weg: erst zerlegen (GDD 7.3)
	if is_instance_valid(_breaking):
		_face(_breaking.global_position)
		_break_timer -= delta
		if _break_timer <= 0.0:
			_break_timer = _rng.randf_range(1.2, 1.7)
			_strike()
			_breaking.receive_hit(22.0)
			if is_instance_valid(_breaking) and _breaking.hurts():
				# Spieße: tut weh – die Kreatur weicht zurück
				CreatureSounds.play(get_parent(), "pain", global_position + Vector3(0, 1.8, 0), 2.0, _rng.randf_range(0.9, 1.05))
				var spike_pos := _breaking.global_position
				_breaking.receive_hit(15.0)
				_breaking = null
				_recoil_from(spike_pos)
		return
	_breaking = null

	if _stare >= 0.0:
		_face(_player.global_position)
		_path.clear()
		_stare += delta
		if _stare > cfg.stare_time:
			Apparition.flash(get_parent(), global_position + Vector3(0, 1.4, 0), true)
			queue_free()
		return
	match state:
		State.ARRIVE:
			if not moving:
				state = State.OBSERVE
				_timer = _rng.randf_range(25.0, 50.0) if mode == "observe" else _rng.randf_range(12.0, 25.0)
		State.OBSERVE:
			_face(_player.global_position)
			if _player_outside() and sees and mode != "observe" and _dist() < cfg.spot_distance_observe:
				_spotted()
			elif _timer <= 0.0:
				if mode == "observe":
					leave()
				else:
					_start_prowl()
		State.PROWL:
			if _player_outside() and sees and _dist() < cfg.spot_distance_prowl:
				_spotted()
			elif not moving:
				_choose_entry()
		State.GO_ENTRY:
			if _player_outside() and sees and _dist() < cfg.spot_distance_entry:
				_spotted()
			elif not moving:
				state = State.HIT_ENTRY
				_hit_timer = 0.8
				_timer = _rng.randf_range(cfg.probe_time.x, cfg.probe_time.y) if mode == "probe" else 60.0
				if not is_instance_valid(_target_entry) or _target_entry.call("is_breached"):
					state = State.REACH
					_timer = 25.0
		State.HIT_ENTRY:
			if not is_instance_valid(_target_entry):
				leave()
				return
			_face(_target_entry.call("outside_point") - _forward_of_entry())
			_hit_timer -= delta
			if _hit_timer <= 0.0 and mode == "probe":
				# Erkundung: sie testet, statt einzubrechen – rüttelt an der Klinke, tastet am Fenster
				_hit_timer = _rng.randf_range(cfg.probe_interval.x, cfg.probe_interval.y)
				if _target_entry is Door:
					_target_entry.call("rattle")
				else:
					SoundBank.play_at(get_parent(), "scratch" if _rng.randf() < 0.5 else "knock", _target_entry.global_position, -2.0)
					_target_entry.call("add_handprint")
			elif _hit_timer <= 0.0:
				_hit_timer = _rng.randf_range(1.3, 2.0)
				_strike()
				var dmg := cfg.entry_hit
				_target_entry.call("receive_hit", dmg)
				if _dist() < 10.0:
					EventBus.screen_shake.emit(0.35)
			if _target_entry.call("is_breached"):
				state = State.REACH
				_timer = 30.0
				CreatureSounds.play(get_parent(), "shriek", global_position + Vector3(0, 1.8, 0), 0.0, 0.85)
			elif _timer <= 0.0:
				if mode == "probe":
					_probes_left -= 1
					ThreatDirector.remember_blocked(_target_entry.call("entry_name"))
					if _probes_left <= 0:
						leave()
					else:
						_choose_entry()
				else:
					# Zu stark – anderen Zugang versuchen (Lernverhalten)
					ThreatDirector.remember_blocked(_target_entry.call("entry_name"))
					_choose_entry()
		State.REACH:
			# Greift durch die Öffnung; kommt nicht ganz ins Haus
			var inside: Vector3 = _target_entry.call("inside_point")
			_face(inside)
			var reach_dist := 1.4 if mode == "probe" else 2.6
			if _player.global_position.distance_to(inside) < reach_dist and _attack_cooldown <= 0.0:
				_attack()
			if mode == "probe" and _timer > 6.0:
				_timer = 6.0  # In der Erkundungsnacht nur kurz hineinstarren
			if _timer <= 0.0:
				if mode == "probe":
					leave()
					return
				if mode == "attack" and _player_outside():
					_start_chase()
				else:
					_start_prowl()
		State.CHASE:
			_lose_sight = _lose_sight - delta if not sees else 6.0
			if _player_outside():
				_path = [_ground(_player.global_position)]
				_speed = cfg.chase_speed
			if _dist() < 1.5 and _attack_cooldown <= 0.0:
				_attack()
			if _lose_sight <= 0.0 or not _player_outside():
				if mode == "observe":
					leave()
				else:
					_choose_entry()
		State.RECOIL:
			if not moving and _timer <= 0.0:
				if mode == "observe":
					leave()
				else:
					_start_prowl()
		State.LEAVE:
			if not moving:
				queue_free()


## Sie entdeckt den Spieler draußen. Auf der Jagd: Verfolgung. Bei einer Erkundung: Sie starrt ihn
## einen Moment an – und ist mit einem Teleporterblitz weg (noch keine direkte Bedrohung).
var _stare: float = -1.0


func _spotted() -> void:
	if mode == "attack":
		_start_chase()
		return
	if _stare < 0.0:
		_stare = 0.0
		_head_track = 4.0
		CreatureSounds.play(get_parent(), "head_snap", global_position + Vector3(0, 1.9, 0), -1.0)


func _start_prowl() -> void:
	state = State.PROWL
	var start := _nearest_ring(global_position)
	var lap: Array[Vector3] = []
	var steps := _rng.randi_range(3, 6)
	var dirn := 1 if _rng.randf() < 0.5 else -1
	for i in steps:
		lap.append(_ground(RING[posmod(start + i * dirn, RING.size())]))
	_go(lap, cfg.prowl_speed)


static var _sting_at: int = -999999

var _interfere_check: float = 1.0
var _interfere_cooldown: float = 8.0


## Schaut der Spieler sie an? (im Blickfeld, freie Sicht – egal ob sie ihn sieht)
func _player_looks_at_me() -> bool:
	var cam := _player.camera.global_transform
	var chest := global_position + Vector3(0, 1.5, 0)
	var to := chest - cam.origin
	if (-cam.basis.z).dot(to.normalized()) < cos(deg_to_rad(30.0)):
		return false
	var q := PhysicsRayQueryParameters3D.create(cam.origin, chest)
	q.exclude = [_player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return true
	var n := hit["collider"] as Node
	while n:
		if n == self or n is CabinWindow:
			return true
		n = n.get_parent()
	return false


## Ab einer bestimmten Nacht: Wer sie ansieht, dem dringt sie ins Hirn (Verzerrung + Schaden).
## Außerdem stört sie die Uhr-Lampe, wann es ihr passt: wenn sie sich anschleicht, jagt
## oder angeleuchtet wird.
func _mind_and_light(delta: float) -> void:
	if state == State.LEAVE or _player == null:
		return
	var night := ThreatDirector.current_night()
	# Nur wenn man sie auch wirklich sehen kann: nah, angeleuchtet oder bei Tageslicht
	var visible_now := _dist() < 12.0 or _lit_time > 0.0 or not TimeManager.is_night() \
			or (_player.light_shining() and _dist() < 24.0) or _player_near_light()
	if night >= cfg.mind_from_night and _dist() < cfg.mind_distance and visible_now and _player_looks_at_me():
		_player.mind_gaze()
	if night < cfg.flicker_from_night or not _player.flashlight.visible:
		return
	_interfere_cooldown -= delta
	_interfere_check -= delta
	if _interfere_check > 0.0 or _interfere_cooldown > 0.0:
		return
	_interfere_check = 1.0
	if _dist() > cfg.flicker_distance:
		return
	var wants := state in [State.ARRIVE, State.PROWL, State.GO_ENTRY, State.CHASE, State.HIT_ENTRY] or _lit_time > 0.0
	if wants and _rng.randf() < cfg.flicker_chance:
		_interfere_cooldown = _rng.randf_range(cfg.flicker_cooldown.x, cfg.flicker_cooldown.y)
		var black := _rng.randf_range(cfg.blackout_time.x, cfg.blackout_time.y) if _rng.randf() < cfg.blackout_chance else 0.0
		_player.hands.interfere(_rng.randf_range(cfg.flicker_time.x, cfg.flicker_time.y), black)


func _start_chase() -> void:
	if mode == "observe":
		return
	if state != State.CHASE:
		CreatureSounds.play(get_parent(), "shriek", global_position + Vector3(0, 1.8, 0), 2.0)
		# Schreck-Akzent, höchstens alle 45 s
		var now := Time.get_ticks_msec()
		if now - _sting_at > 45000:
			_sting_at = now
			SoundBank.play_ui(get_parent(), "sting_creature", -2.0)
	state = State.CHASE
	_lose_sight = 6.0


## Wählt einen Zugang: schwächere Stellen und solche, die noch nicht blockiert waren, bevorzugt.
func _choose_entry() -> void:
	var entries := get_tree().get_nodes_in_group("entry_point")
	if entries.is_empty():
		leave()
		return
	var best: Node3D = null
	var best_score := INF
	for e in entries:
		var s: float = e.call("strength")
		s += float(ThreatDirector.blocked_memory.get(e.call("entry_name"), 0)) * 60.0
		s += _rng.randf_range(0.0, 40.0)
		if e == _target_entry and state == State.HIT_ENTRY:
			s += 80.0
		if s < best_score:
			best_score = s
			best = e
	_target_entry = best
	var goal := _ground(best.call("outside_point"))
	var route: Array = _ring_path_to(_nearest_ring(goal))
	# Auf die Veranda nur über die Treppe
	if goal.z > 4.6 and goal.z < 6.8 and goal.x > -5.8 and goal.x < 1.4:
		route.append(Vector3(-3.0, 0, 8.4))
		route.append(Vector3(-3.0, 0, 6.2))
	route.append(goal)
	_go(route, cfg.prowl_speed)
	state = State.GO_ENTRY


func _strike() -> void:
	var arm := _parts.get("arm_1") as Node3D
	if arm:
		var tw := create_tween()
		tw.tween_property(arm, "rotation_degrees:x", -110.0, 0.15)
		tw.tween_property(arm, "rotation_degrees:x", -20.0, 0.4)


func _attack() -> void:
	_attack_cooldown = 2.2
	_strike()
	CreatureSounds.play(get_parent(), "shriek", global_position + Vector3(0, 1.8, 0), 3.0, 1.1)
	_player.take_damage(cfg.hit_damage, global_position)
	EventBus.screen_shake.emit(0.8)


# --- Wahrnehmung --------------------------------------------------------

func _dist() -> float:
	return global_position.distance_to(_player.global_position)


func _player_outside() -> bool:
	return not Cabin.is_inside(_player.global_position) and not Shed.is_inside(_player.global_position)


## Sicht: Reichweite hängt davon ab, ob der Spieler Licht macht.
func _can_see_player() -> bool:
	var d := _dist()
	var lit := _player.light_shining() or _player_near_light()
	var range_m := 34.0 if lit else 13.0
	if d > range_m:
		return false
	var eye := global_position + Vector3(0, 2.0, 0)
	var target := _player.global_position + Vector3(0, 1.5, 0)
	var q := PhysicsRayQueryParameters3D.create(eye, target)
	q.exclude = [_player.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _player_near_light() -> bool:
	if not PowerManager.has_power():
		return false
	for sw in get_tree().get_nodes_in_group("light_switch"):
		if sw.is_on and sw.global_position.distance_to(_player.global_position) < 6.0:
			return true
	return false


## Taschenlampe: trifft der Lichtkegel die Kreatur?
func _update_light(delta: float) -> void:
	if not _player.light_shining():
		_lit_time = 0.0
		return
	var cam := _player.camera.global_transform
	var to_me := (global_position + Vector3(0, 1.6, 0)) - cam.origin
	var d := to_me.length()
	if d > 30.0:
		_lit_time = 0.0
		return
	var fwd := -cam.basis.z
	if fwd.dot(to_me.normalized()) < cos(deg_to_rad(14.0)) or not _can_see_player():
		_lit_time = 0.0
		return
	_lit_time += delta
	if _lit_time > 0.6 and state in [State.OBSERVE, State.ARRIVE, State.PROWL]:
		# Beobachter wollen nicht gesehen werden
		if mode == "observe":
			_lit_time = 0.0
			SoundBank.play_at(get_parent(), "twig", global_position, 0.0)
			leave()
	if _lit_time > 0.4 and d < 9.0 and state in [State.REACH, State.CHASE, State.HIT_ENTRY]:
		# Aus nächster Nähe geblendet: weicht zurück (Licht gezielt einsetzen, GDD 2.4)
		_lit_time = 0.0
		CreatureSounds.play(get_parent(), "recoil", global_position + Vector3(0, 1.8, 0), 3.0)
		state = State.RECOIL
		_timer = _rng.randf_range(12.0, 22.0)
		var away := (global_position - _player.global_position)
		away.y = 0
		_go([_ground(global_position + away.normalized() * 14.0)], cfg.chase_speed)


## Ist die Kreatur gerade im Blickfeld des Spielers (und nicht verdeckt)?
func is_in_player_view() -> bool:
	var cam := _player.camera.global_transform
	var to_me := (global_position + Vector3(0, 1.4, 0)) - cam.origin
	if to_me.length() > 45.0:
		return false
	if (-cam.basis.z).dot(to_me.normalized()) < cos(deg_to_rad(38.0)):
		return false
	return _can_see_player()


## Beobachter: Wer wegschaut, findet beim erneuten Hinsehen nur noch leeren Wald (GDD 2.3).
func _check_vanish(delta: float) -> void:
	if mode != "observe" or state != State.OBSERVE:
		return
	if is_in_player_view():
		_seen_by_player = true
		_unseen_time = 0.0
	elif _seen_by_player:
		_unseen_time += delta
		if _unseen_time > 2.5:
			queue_free()


func _on_noise(pos: Vector3, radius: float) -> void:
	if state in [State.LEAVE, State.CHASE, State.HIT_ENTRY, State.REACH, State.RECOIL]:
		return
	if global_position.distance_to(pos) > radius * 1.5 or mode == "observe":
		return
	# Neugierig: schaut nach, woher das Geräusch kam
	var goal := _ground(pos + (global_position - pos).normalized() * 3.0)
	if Cabin.is_inside(goal) or absf(goal.x) < 7.0 and absf(goal.z) < 5.5:
		_choose_entry()
	else:
		_go([goal], cfg.prowl_speed)
		state = State.PROWL


# --- Bewegung -----------------------------------------------------------

func _go(points: Array, speed: float) -> void:
	_path.clear()
	for p in points:
		_path.append(_ground(_outside_house(p)))
	_speed = speed


## Die Kreatur betritt das Haus nicht: Ziele im Grundriss werden nach draußen geschoben.
static func _outside_house(p: Vector3) -> Vector3:
	var hx := Cabin.HALF_X + 0.9
	var hz := Cabin.HALF_Z + 0.9
	if absf(p.x) >= hx or absf(p.z) >= hz:
		return p
	# Veranda ist erlaubt (dort stehen Tür und Wohnzimmerfenster)
	if p.z > Cabin.HALF_Z + 0.1 and p.x > -5.8 and p.x < 1.4:
		return p
	var dx := hx - absf(p.x)
	var dz := hz - absf(p.z)
	if dx < dz:
		return Vector3(signf(p.x) * hx, p.y, p.z)
	return Vector3(p.x, p.y, signf(p.z) * hz)


func _follow_path(delta: float) -> bool:
	if _path.is_empty():
		return false
	var target := _path[0]
	var to := target - global_position
	to.y = 0.0
	var step := _speed * delta
	if to.length() <= step + 0.05:
		global_position = target
		_path.remove_at(0)
		return not _path.is_empty()
	var dir := to.normalized()
	var next := global_position + dir * step
	var ob := _obstacle_at(global_position + dir * 0.6)
	if ob:
		if _breaking != ob:
			_breaking = ob
			_break_timer = 0.5
		return false
	global_position = _ground(next)
	var look := global_position + dir
	look.y = global_position.y
	if look.distance_to(global_position) > 0.01:
		var t := global_transform.looking_at(look, Vector3.UP)
		global_transform.basis = global_transform.basis.slerp(t.basis.rotated(Vector3.UP, PI).orthonormalized(), clampf(delta * 6.0, 0.0, 1.0))
	return true


func _obstacle_at(p: Vector3) -> Structure:
	for o in get_tree().get_nodes_in_group("obstacle"):
		if (o as Structure).blocks_point(p, 0.35):
			return o
	return null


## Grelles Licht (Bewegungsmelder): Beobachter fliehen, andere weichen kurz zurück.
func on_bright_light(source: Vector3) -> void:
	if state == State.LEAVE:
		return
	_lit_time = 0.5
	if mode == "observe":
		leave()
	elif _rng.randf() < 0.6:
		CreatureSounds.play(get_parent(), "recoil", global_position + Vector3(0, 1.8, 0), 1.0)
		_recoil_from(source)


## Stroboskop (Forschung): flackerndes Licht verkrampft ihr Gewebe – sie flieht deutlich länger.
func on_strobe(source: Vector3) -> void:
	if state == State.LEAVE:
		return
	CreatureSounds.play(get_parent(), "recoil", global_position + Vector3(0, 1.8, 0), 3.0, 0.9)
	if mode == "observe":
		leave()
		return
	_recoil_from(source)
	_timer = _rng.randf_range(25.0, 40.0)


## Faustschlag oder Axthieb des Spielers: tut weh und verscheucht die Kreatur eine Weile.
## (Töten kann man sie damit nicht.) strength 0..1 – die Axt wirkt länger als die Faust.
func on_melee_hit(strength: float, from: Vector3) -> void:
	if state == State.LEAVE:
		return
	CreatureSounds.play(get_parent(), "pain", global_position + Vector3(0, 1.8, 0), 2.0, _rng.randf_range(0.95, 1.1))
	_head_track = 2.0
	# Ein Axthieb hinterlässt eine Gewebeprobe für die Forschung
	if strength >= 1.0:
		CrashSite.drop_tissue(get_parent(), global_position + Vector3(0.3, 0, 0.3))
	if mode == "observe":
		leave()
		return
	_recoil_from(from)
	_timer = lerpf(5.0, 14.0, strength)


func _recoil_from(source: Vector3) -> void:
	state = State.RECOIL
	_timer = _rng.randf_range(10.0, 18.0)
	var away := global_position - source
	away.y = 0.0
	if away.length() < 0.1:
		away = global_position * Vector3(1, 0, 1)
	_go([_ground(global_position + away.normalized() * 10.0)], cfg.chase_speed)


func _face(p: Vector3) -> void:
	var look := p
	look.y = global_position.y
	if look.distance_to(global_position) < 0.05:
		return
	var t := global_transform.looking_at(look, Vector3.UP)
	global_transform.basis = global_transform.basis.slerp(t.basis.rotated(Vector3.UP, PI).orthonormalized(), 0.05)


func _forward_of_entry() -> Vector3:
	if not is_instance_valid(_target_entry):
		return Vector3.ZERO
	var o: Vector3 = _target_entry.call("outside_point")
	var i: Vector3 = _target_entry.call("inside_point")
	return (o - i).normalized()


## Bodenhöhe: Gelände, auf der Veranda die Dielen.
static func _ground(p: Vector3) -> Vector3:
	var y := Terrain.height_at(p.x, p.z)
	if p.x > -5.6 and p.x < 1.2 and p.z > 4.6 and p.z < 6.6:
		y = Cabin.FLOOR_Y
	return Vector3(p.x, y, p.z)


func _nearest_ring(p: Vector3) -> int:
	var best := 0
	var bd := INF
	for i in RING.size():
		var d: float = (RING[i] as Vector3).distance_to(Vector3(p.x, 0, p.z))
		if d < bd:
			bd = d
			best = i
	return best


## Weg entlang des Rings vom nächsten Ringpunkt bis zum Ziel-Ringpunkt (kürzere Richtung).
func _ring_path_to(target_index: int) -> Array[Vector3]:
	var start := _nearest_ring(global_position)
	var n := RING.size()
	var fwd := posmod(target_index - start, n)
	var dirn := 1 if fwd <= n / 2 else -1
	var steps := fwd if dirn == 1 else n - fwd
	var out: Array[Vector3] = []
	for i in steps + 1:
		out.append(RING[posmod(start + i * dirn, n)])
	return out


func _pick_observe_spot() -> Vector3:
	return OBSERVE_SPOTS[_rng.randi() % OBSERVE_SPOTS.size()]


func _nearest_observe_spot() -> Vector3:
	var best: Vector3 = OBSERVE_SPOTS[0]
	for s in OBSERVE_SPOTS:
		if (s as Vector3).distance_to(global_position) < best.distance_to(global_position):
			best = s
	return best


# --- Animation und Geräusche -------------------------------------------

func _animate(delta: float, moving: bool) -> void:
	var speed_factor := _speed / cfg.walk_speed if moving else 0.0
	if moving:
		_walk_phase += delta * (2.4 + speed_factor * 1.6)
	var swing := sin(_walk_phase) * (28.0 if moving else 0.0) * clampf(speed_factor, 0.6, 1.6)
	for side: int in [-1, 1]:
		var leg := _parts.get("leg_%d" % side) as Node3D
		var knee := _parts.get("knee_%d" % side) as Node3D
		var arm := _parts.get("arm_%d" % side) as Node3D
		var fore := _parts.get("forearm_%d" % side) as Node3D
		if leg:
			leg.rotation_degrees.x = swing * side
			knee.rotation_degrees.x = maxf(0.0, -swing * side) * 1.2 + (6.0 if moving else 2.0)
		if arm and not (side == 1 and state == State.HIT_ENTRY):
			arm.rotation_degrees.x = lerpf(arm.rotation_degrees.x, -swing * side * 0.6 - (25.0 if state == State.CHASE else 4.0), clampf(delta * 8.0, 0.0, 1.0))
			fore.rotation_degrees.x = -10.0 - (30.0 if state == State.CHASE else 0.0)
	var hips := _parts.get("hips") as Node3D
	if hips:
		hips.position.y = 1.05 + absf(sin(_walk_phase)) * 0.04
	var head := _parts.get("head") as Node3D
	if head:
		# Unheimliches, langsames Neigen des Kopfes beim Stillstehen
		var t := Time.get_ticks_msec() / 1000.0
		head.rotation_degrees.z = (sin(t * 0.4) * 18.0) if not moving else sin(_walk_phase * 0.5) * 4.0
		head.rotation_degrees.x = -8.0 if state == State.OBSERVE else 0.0
		if _head_track > 0.0 and _player:
			# Kopf blickt direkt in die Kamera des Spielers
			var local := to_local(_player.camera.global_position)
			var yaw := clampf(rad_to_deg(atan2(local.x, local.z)), -80.0, 80.0)
			head.rotation_degrees.y = lerpf(head.rotation_degrees.y, yaw, clampf(delta * 14.0, 0.0, 1.0))
			head.rotation_degrees.z *= 0.2
		else:
			head.rotation_degrees.y = lerpf(head.rotation_degrees.y, 0.0, clampf(delta * 2.0, 0.0, 1.0))
	var torso := _parts.get("torso") as Node3D
	if torso:
		torso.rotation_degrees.x = 22.0 if state == State.CHASE else 8.0


func _sounds(delta: float, moving: bool) -> void:
	if moving:
		_step_timer -= delta * (_speed / cfg.walk_speed)
		if _step_timer <= 0.0:
			_step_timer = 0.55
			# Nur ab und zu ein Schritt, tief und dumpf – meist bewegt sie sich lautlos.
			# Auf der Jagd hört man sie deutlicher.
			var chance := cfg.step_chance_chase if state == State.CHASE else cfg.step_chance
			if _rng.randf() < chance:
				CreatureSounds.play(get_parent(), "step", global_position + Vector3(0, 0.1, 0), cfg.step_volume_db if _speed <= cfg.walk_speed else cfg.step_volume_chase_db, _rng.randf_range(cfg.step_pitch.x, cfg.step_pitch.y), 30.0)
			if _rng.randf() < 0.05:
				SoundBank.play_at(get_parent(), "twig", global_position, -2.0)
	# Atmen und Klicken: beim Beobachten eher Klicken, beim Herumschleichen gemischt,
	# ganz nah (am Fenster, auf der Jagd) schweres Atmen
	_breath_timer -= delta
	if _breath_timer <= 0.0 and _dist() < 22.0 and not is_instance_valid(_voice) and state != State.LEAVE:
		# Meist Stille. Klicken nur selten und nur, wenn sie nah ist – dann bedeutet es etwas.
		var close := _dist() < cfg.close_distance or state in [State.REACH, State.CHASE, State.HIT_ENTRY]
		if not close and _rng.randf() < cfg.far_silence_chance:
			_breath_timer = _rng.randf_range(cfg.far_silence_pause.x, cfg.far_silence_pause.y)
			return
		var kind := "breath"
		var vol := -6.0
		if close:
			kind = "breath" if _rng.randf() < 0.7 else ("click" if _rng.randf() < 0.5 else "breath_click")
			vol = -2.0
		var dur := _rng.randf_range(2.5, 5.5)
		_voice = CreatureSounds.play_phrase(self, kind, global_position + Vector3(0, 1.8, 0), vol, dur)
		# Pausen dazwischen – Stille macht es unheimlicher
		_breath_timer = dur + _rng.randf_range(2.0, 7.0)
