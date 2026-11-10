class_name Seeker
extends Node3D
## Der Sucher: hoch, dürr, vornübergebeugt, statt eines Gesichts ein schmaler Schlitz voller kleiner,
## fahl leuchtender Augen. Er sucht nach Lebenszeichen – Licht, Geräusche, das Signal von W-17.
## Ablauf: erscheinen (Waldrand) → lange beobachten → Umgebung absuchen → bei einem Reiz hingehen →
## wer gefunden wird, wird verletzt (Zelt reißt auf), dann verschwindet er im Teleporterblitz.
## Er tötet nicht. Werte: data/creatures/seeker.tres. Wann er kommt: ThreatConfig seeker_*.

enum State { ARRIVE, WATCH, SEARCH, INVESTIGATE, STRIKE, LEAVE }

var cfg: SeekerConfig
var target: Vector3          ## Lager oder Hütte
var state: State = State.ARRIVE
var _rng := RandomNumberGenerator.new()
var _path: Array[Vector3] = []
var _hold: float = 0.0
var _life: float = 0.0
var _scan: float = 0.0
var _sense_t: float = 0.0
var _lure: Vector3 = Vector3.INF
var _head: Node3D
var _arms: Array[Node3D] = []
var _legs: Array[Node3D] = []
var _eye_mat: StandardMaterial3D
var _eye_light: OmniLight3D
var _walk_phase: float = 0.0
var _click_t: float = 3.0
var _player: Player


## Erscheint in der Nähe eines Ziels (Zelt/Lager oder Hütte).
static func spawn_for(scene: Node, near: Vector3) -> Seeker:
	for s in scene.get_tree().get_nodes_in_group("seeker"):
		return s as Seeker
	var sk := Seeker.new()
	sk.name = "Seeker"
	sk.target = near
	scene.add_child(sk)
	return sk


func _ready() -> void:
	add_to_group("seeker")
	cfg = SeekerConfig.get_default()
	_rng.randomize()
	_player = get_tree().get_first_node_in_group("player") as Player
	_build_model()
	var a := _rng.randf() * TAU
	var d := _rng.randf_range(cfg.spawn_distance.x, cfg.spawn_distance.y)
	var p := target + Vector3(cos(a) * d, 0, sin(a) * d)
	p.y = Terrain.height_at(p.x, p.z)
	global_position = p
	_go([_ground(target + (p - target).normalized() * (d * 0.55))])
	EventBus.noise_made.connect(_on_noise)
	Tasks.flag("seeker_seen")
	print("[Seeker] erscheint bei ", global_position)


func _ground(p: Vector3) -> Vector3:
	return Vector3(p.x, Terrain.height_at(p.x, p.z), p.z)


func _go(points: Array) -> void:
	_path.clear()
	for q: Vector3 in points:
		_path.append(q)


# --- Aussehen ------------------------------------------------------------------

func _build_model() -> void:
	var skin := BuildKit.tex_mat("alien_skin", 0.6, Color(0.3, 0.28, 0.32), 0.4)
	_eye_mat = StandardMaterial3D.new()
	_eye_mat.albedo_color = Color(0.6, 0.9, 1.0)
	_eye_mat.emission_enabled = true
	_eye_mat.emission = Color(0.55, 0.9, 1.0)
	_eye_mat.emission_energy_multiplier = 1.2
	var body := Node3D.new()
	body.name = "Body"
	add_child(body)
	# Beine (lang, nach hinten geknickt)
	for sx: float in [-1.0, 1.0]:
		var hip := Node3D.new()
		hip.position = Vector3(sx * 0.16, 1.35, 0)
		body.add_child(hip)
		BuildKit.cylinder(hip, 0.075, 0.75, Vector3(0, -0.36, -0.08), skin, false, Vector3(-14, 0, 0), 0.05, 6)
		BuildKit.cylinder(hip, 0.05, 0.72, Vector3(0, -1.0, 0.0), skin, false, Vector3(14, 0, 0), 0.035, 6)
		BuildKit.box(hip, Vector3(0.07, 0.03, 0.22), Vector3(0, -1.34, 0.07), skin, false)
		_legs.append(hip)
	# Rumpf: dünn, vornübergebeugt
	var torso := Node3D.new()
	torso.position = Vector3(0, 1.35, 0)
	torso.rotation_degrees.x = 24.0
	body.add_child(torso)
	BuildKit.cylinder(torso, 0.15, 0.95, Vector3(0, 0.48, 0), skin, false, Vector3.ZERO, 0.22, 8)
	for k in 5:
		BuildKit.box(torso, Vector3(0.3, 0.025, 0.05), Vector3(0, 0.3 + k * 0.12, 0.09), skin, false)
	# Hals und Kopf: schmaler, hoher Schlitz voller Augen
	_head = Node3D.new()
	_head.position = Vector3(0, 1.08, 0.05)
	torso.add_child(_head)
	BuildKit.cylinder(_head, 0.03, 0.32, Vector3(0, 0.14, 0), skin, false, Vector3(-20, 0, 0), 0.04, 6)
	var skull := BuildKit.sphere(_head, 0.16, Vector3(0, 0.42, 0.05), skin, Vector3(0.65, 1.8, 0.8), 10)
	skull.name = "Skull"
	for i in 9:
		var y := 0.27 + i * 0.035
		var x := (0.018 if i % 2 == 0 else -0.018)
		BuildKit.sphere(_head, 0.014, Vector3(x, y, 0.175), _eye_mat, Vector3.ONE, 5)
	_eye_light = OmniLight3D.new()
	_eye_light.light_color = Color(0.55, 0.85, 1.0)
	_eye_light.light_energy = 0.35
	_eye_light.omni_range = 2.5
	_eye_light.position = Vector3(0, 0.42, 0.3)
	_head.add_child(_eye_light)
	# Arme: sehr lang, Finger bis unters Knie
	for sx: float in [-1.0, 1.0]:
		var sh := Node3D.new()
		sh.position = Vector3(sx * 0.2, 0.92, 0.02)
		torso.add_child(sh)
		BuildKit.cylinder(sh, 0.045, 0.8, Vector3(0, -0.4, 0), skin, false, Vector3.ZERO, 0.035, 6)
		BuildKit.cylinder(sh, 0.035, 0.75, Vector3(0, -1.15, 0.05), skin, false, Vector3(8, 0, 0), 0.025, 6)
		for f in 4:
			BuildKit.cylinder(sh, 0.008, 0.28, Vector3((f - 1.5) * 0.02, -1.65, 0.08), skin, false, Vector3(10 + f * 3, 0, (f - 1.5) * 6), 0.004, 4)
		_arms.append(sh)


# --- Verhalten -----------------------------------------------------------------

func _process(delta: float) -> void:
	_life += delta
	_click_t -= delta
	if _click_t <= 0.0:
		_click_t = _rng.randf_range(4.0, 9.0)
		CreatureSounds.play_phrase(self, "click", global_position + Vector3(0, 2.2, 0), -12.0, 1.2, 18.0)
	# Am Morgen oder nach Ablauf der Zeit: abziehen
	if state != State.LEAVE and (not TimeManager.is_night() or _life > cfg.stay_time):
		_leave()
	_sense_t -= delta
	if _sense_t <= 0.0 and state in [State.WATCH, State.SEARCH, State.ARRIVE]:
		_sense_t = 0.5
		_sense()
	match state:
		State.ARRIVE, State.SEARCH, State.INVESTIGATE, State.LEAVE:
			_move(delta)
		State.WATCH:
			_hold -= delta
			_face(target, delta)
			_scan_head(delta)
			if _hold <= 0.0:
				_start_search()
		State.STRIKE:
			pass
	_animate(delta)


func _speed() -> float:
	return cfg.approach_speed if state == State.INVESTIGATE else cfg.walk_speed


func _move(delta: float) -> void:
	if _hold > 0.0:
		_hold -= delta
		_scan_head(delta)
		return
	if _path.is_empty():
		_arrived()
		return
	var goal := _path[0]
	var to := goal - global_position
	to.y = 0.0
	if to.length() < 0.6:
		_path.pop_front()
		if state == State.SEARCH:
			_hold = _rng.randf_range(cfg.search_hold.x, cfg.search_hold.y)
		return
	var step := to.normalized() * _speed() * delta
	var p := global_position + step
	p.y = Terrain.height_at(p.x, p.z)
	global_position = p
	_face(goal, delta)
	_walk_phase += delta * _speed() * 3.2


func _face(p: Vector3, delta: float) -> void:
	var d := p - global_position
	if Vector2(d.x, d.z).length() < 0.01:
		return
	var yaw := atan2(d.x, d.z)
	rotation.y = lerp_angle(rotation.y, yaw, clampf(delta * 2.5, 0.0, 1.0))


func _scan_head(delta: float) -> void:
	_scan += delta
	_head.rotation.y = sin(_scan * 0.9) * 0.6
	_head.rotation.z = sin(_scan * 0.37) * 0.25


func _arrived() -> void:
	match state:
		State.ARRIVE:
			state = State.WATCH
			_hold = _rng.randf_range(cfg.watch_time.x, cfg.watch_time.y)
		State.SEARCH:
			_start_search()
		State.INVESTIGATE:
			_investigate_done()
		State.LEAVE:
			queue_free()


func _start_search() -> void:
	state = State.SEARCH
	var pts: Array = []
	for i in _rng.randi_range(cfg.search_points.x, cfg.search_points.y):
		var a := _rng.randf() * TAU
		var r := _rng.randf_range(2.5, cfg.search_radius)
		pts.append(_ground(target + Vector3(cos(a) * r, 0, sin(a) * r)))
	_go(pts)


func _on_noise(pos: Vector3, radius: float) -> void:
	if state in [State.STRIKE, State.LEAVE]:
		return
	if pos.distance_to(global_position) < radius * cfg.hearing:
		_investigate(pos)


## Reize: Licht (Uhr, Zelt, Feuer), W-17, den Spieler direkt sehen.
func _sense() -> void:
	if _player == null:
		return
	var pp := _player.global_position
	var d := global_position.distance_to(pp)
	var camp := _player.in_tent as TentCamp
	var lit := _player.light_shining()
	if _player.is_hidden():
		return
	# W-17 ruft ihn aus großer Entfernung
	if Inventory.count("w17") > 0 and d < cfg.w17_range:
		_investigate(pp)
		return
	if lit and d < cfg.light_range and (camp != null or _sees(pp)):
		_investigate(pp)
		return
	for f in get_tree().get_nodes_in_group("campfire"):
		var fp := (f as Node3D).global_position
		if f.call("burning") and fp.distance_to(global_position) < cfg.fire_range and fp.distance_to(target) > 3.0:
			target = fp
			_investigate(fp)
			return
	if camp == null and d < (cfg.sight_lit if lit else cfg.sight_dark) and _sees(pp):
		_investigate(pp)


func _sees(p: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 2.3, 0), p + Vector3(0, 1.2, 0))
	q.exclude = [_player.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _investigate(pos: Vector3) -> void:
	if state == State.INVESTIGATE and _lure.distance_to(pos) < 2.0:
		return
	state = State.INVESTIGATE
	_lure = pos
	_hold = 0.6
	_eye_mat.emission_energy_multiplier = 3.5
	_eye_light.light_energy = 1.0
	CreatureSounds.play(self, "head_snap", global_position + Vector3(0, 2.3, 0), -4.0, 0.8, 30.0)
	_go([_ground(pos)])


## Am Reiz angekommen: Spieler da? Dann zuschlagen (Zelt aufreißen), sonst weitersuchen.
func _investigate_done() -> void:
	_eye_mat.emission_energy_multiplier = 1.2
	_eye_light.light_energy = 0.35
	if _player == null:
		_start_search()
		return
	var camp := _player.in_tent as TentCamp
	var d := global_position.distance_to(_player.global_position)
	if camp and d < 3.5:
		var lured := camp.glowing() or Inventory.count("w17") > 0
		if lured or (ThreatDirector.current_night() >= cfg.tear_from_day and _rng.randf() < cfg.tear_chance_dark):
			_strike(camp)
			return
		# Er steht vor dem Zelt, atmet – und geht weiter
		CreatureSounds.play_phrase(self, "breath_click", global_position + Vector3(0, 2.0, 0), -4.0, 4.0, 14.0)
		_hold = 5.0
		_start_search()
		return
	if camp == null and d < 2.2 and not _player.is_hidden():
		_strike(null)
		return
	_start_search()


func _strike(camp: TentCamp) -> void:
	state = State.STRIKE
	_face(_player.global_position, 1.0)
	# Arme hoch
	var tw := create_tween().set_parallel(true)
	for a in _arms:
		tw.tween_property(a, "rotation_degrees:x", -140.0, 0.35)
	await tw.finished
	if not is_inside_tree():
		return
	var dmg := cfg.strike_damage
	if camp:
		camp.tear(dmg)
	elif _player:
		var h := _player.health
		_player.health = maxf(h - dmg, minf(h, cfg.min_health))
		EventBus.player_hurt.emit(dmg)
		EventBus.screen_shake.emit(0.7)
		CreatureSounds.play(self, "shriek", global_position + Vector3(0, 2.2, 0), 0.0)
	Tasks.flag("seeker_struck")
	await get_tree().create_timer(0.8).timeout
	if is_inside_tree():
		Apparition.flash(get_parent(), global_position + Vector3(0, 1.4, 0), true)
		queue_free()


func _leave() -> void:
	state = State.LEAVE
	_eye_mat.emission_energy_multiplier = 0.8
	var away := (global_position - target)
	away.y = 0.0
	away = away.normalized() if away.length() > 0.1 else Vector3(0, 0, 1)
	_go([_ground(global_position + away * 60.0)])


func _animate(delta: float) -> void:
	var moving := not _path.is_empty() and _hold <= 0.0 and state != State.WATCH
	var s := sin(_walk_phase)
	for i in _legs.size():
		var target_x := (s if i == 0 else -s) * 22.0 if moving else 0.0
		_legs[i].rotation_degrees.x = lerpf(_legs[i].rotation_degrees.x, target_x, clampf(delta * 6.0, 0.0, 1.0))
	if state != State.STRIKE:
		for i in _arms.size():
			var ax := (-s if i == 0 else s) * 10.0 + 6.0
			_arms[i].rotation_degrees.x = lerpf(_arms[i].rotation_degrees.x, ax, clampf(delta * 4.0, 0.0, 1.0))
			_arms[i].rotation_degrees.z = (1.0 if i == 0 else -1.0) * (4.0 + sin(_life * 0.7 + i) * 3.0)
