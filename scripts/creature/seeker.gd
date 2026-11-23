class_name Seeker
extends Node3D
## Der Sucher: hoch, dürr, vornübergebeugt, statt eines Gesichts ein schmaler Schlitz voller kleiner,
## fahl leuchtender Augen. Er sucht nach Lebenszeichen – Licht, Geräusche, das Signal von W-17.
## Ablauf: erscheinen (Waldrand) → lange beobachten → Umgebung absuchen → bei einem Reiz hingehen →
## wer gefunden wird, wird verletzt (Zelt reißt auf), dann verschwindet er im Teleporterblitz.
## Er tötet nicht. Werte: data/creatures/seeker.tres. Wann er kommt: ThreatConfig seeker_*.

enum State { ARRIVE, WATCH, SEARCH, INVESTIGATE, STRIKE, LEAVE }

var _last_rustle_pos := Vector3.ZERO
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
var _hum: AudioStreamPlayer3D = null    # eigenes Summen (Schleife), solange er da ist
var _steps: AudioStreamPlayer3D = null  # eigene Schritte (Schleife), nur beim Gehen
var _moving: bool = false
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


## Verdacht in Stufen (Stealth)
var awareness := Awareness.new()

func _ready() -> void:
	add_to_group("seeker")
	add_to_group("aware")
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
	_hum = SoundBank.attach_loop(self, "seeker_hum", -8.0, 30.0, 2.3)
	_steps = SoundBank.attach_loop(self, "seeker_steps", -4.0, 35.0, 0.2)
	SoundBank.play_rec.call_deferred(get_parent(), "seeker_teleport", p + Vector3(0, 1.4, 0), -6.0, 50.0)
	Tasks.flag("seeker_seen")
	print("[Seeker] erscheint bei ", global_position)


func _ground(p: Vector3) -> Vector3:
	return Vector3(p.x, Terrain.height_at(p.x, p.z), p.z)


func _go(points: Array) -> void:
	_path.clear()
	for q: Vector3 in points:
		_path.append(outside(q))


## In Hütte und Schuppen kommt er nicht: Punkte darin werden nach draußen vor die Wand geschoben.
static func outside(p: Vector3) -> Vector3:
	var q := p
	for c: Vector3 in [Vector3.ZERO, Shed.ORIGIN]:
		var guard := 0
		while (Cabin.is_inside(q) or Shed.is_inside(q) or Cabin.blocks_ground(q)) and guard < 40:
			var dir := Vector3(q.x - c.x, 0, q.z - c.z)
			if dir.length() < 0.1:
				dir = Vector3(0, 0, 1)
			q += dir.normalized() * 0.5
			guard += 1
	if q != p:
		q.y = Terrain.height_at(q.x, q.z)
	return q


## Abstand zu Hütte und Schuppen: er ist 2,7 m groß und vorgebeugt – ohne Abstand ragte sein Kopf durch Dachkante und
## Wand (Christian 23.11.). Geprüft wird deshalb ein Ring um ihn herum.
const WALL_MARGIN := 1.1


static func _blocked(p: Vector3) -> bool:
	if _blocked_at(p):
		return true
	for k in 8:
		var a := k * TAU / 8.0
		if _blocked_at(p + Vector3(cos(a), 0.0, sin(a)) * WALL_MARGIN):
			return true
	return false


static func _blocked_at(p: Vector3) -> bool:
	return Cabin.is_inside(p) or Shed.is_inside(p) or Cabin.blocks_ground(p)


# --- Aussehen ------------------------------------------------------------------

func _build_model() -> void:
	# Christian 23.11.: organisch statt „Robotertonne“ – ausgemergelter, überlanger Körper, Haut über Knochen,
	# vorgebeugt, Finger bis unters Knie, Kopf ohne Gesicht: nur ein senkrechter Spalt voller kleiner Augen.
	var rng := RandomNumberGenerator.new()
	rng.seed = 2701
	var hide := FleshKit.skin(Color(0.44, 0.39, 0.41), 0.36, 0.11)
	var pale := FleshKit.skin(Color(0.5, 0.45, 0.44), 0.42, 0.11)     # Knochenpunkte unter dünner Haut
	var dark := FleshKit.skin(Color(0.16, 0.13, 0.15), 0.3, 0.11)
	var vein_mat := BuildKit.color_mat(Color(0.14, 0.12, 0.17), 0.6)
	var lip := FleshKit.skin(Color(0.42, 0.22, 0.26), 0.25)
	var nail := BuildKit.color_mat(Color(0.1, 0.09, 0.08), 0.2, 0.2)
	var slit := StandardMaterial3D.new()
	slit.albedo_color = Color(0.02, 0.01, 0.015)
	slit.roughness = 0.9
	_eye_mat = StandardMaterial3D.new()
	_eye_mat.albedo_color = Color(0.6, 0.9, 1.0)
	_eye_mat.emission_enabled = true
	_eye_mat.emission = Color(0.55, 0.9, 1.0)
	_eye_mat.emission_energy_multiplier = 1.2
	var body := Node3D.new()
	body.name = "Body"
	add_child(body)
	# Becken mit vorstehenden Beckenknochen
	FleshKit.limb(body, [Vector3(0, 1.5, -0.01), Vector3(0, 1.4, -0.02), Vector3(0, 1.3, 0.0)], [Vector2(0.1, 0.075), Vector2(0.145, 0.095), Vector2(0.09, 0.07)], hide, 14)
	for sx: float in [-1.0, 1.0]:
		FleshKit.bulb(body, Vector3(sx * 0.12, 1.44, 0.04), Vector3(0.035, 0.03, 0.03), pale)
	# Beine: dürr, knotige Knie, lange Füße mit vier Zehen
	for sx: float in [-1.0, 1.0]:
		var hip := Node3D.new()
		hip.position = Vector3(sx * 0.11, 1.36, 0)
		body.add_child(hip)
		FleshKit.limb(hip, [Vector3.ZERO, Vector3(sx * 0.012, -0.3, 0.09), Vector3(0, -0.64, 0.12)], [0.072, Vector2(0.06, 0.066), 0.04], hide, 12)
		FleshKit.spindle(hip, Vector3(sx * 0.03, -0.05, 0.06), Vector3(sx * 0.008, -0.6, 0.13), 0.034, hide, 0.35)
		FleshKit.bulb(hip, Vector3(0, -0.655, 0.152), Vector3(0.034, 0.044, 0.02), pale, Vector3(-10, 0, 0))
		FleshKit.limb(hip, [Vector3(0, -0.64, 0.12), Vector3(0, -0.96, 0.02), Vector3(0, -1.28, -0.06)], [0.042, 0.034, 0.026], hide, 10)
		FleshKit.spindle(hip, Vector3(0, -0.7, 0.08), Vector3(0, -1.2, -0.09), 0.03, hide, 0.3)
		FleshKit.bulb(hip, Vector3(0, -1.3, -0.065), Vector3(0.03, 0.026, 0.03), hide)
		FleshKit.limb(hip, [Vector3(0, -1.3, -0.07), Vector3(0, -1.34, 0.04), Vector3(0, -1.355, 0.12)], [0.03, Vector2(0.04, 0.018), Vector2(0.045, 0.014)], hide, 8, 3, Vector3.UP)
		for t in 4:
			var tx := (t - 1.5) * 0.022
			FleshKit.finger(hip, Vector3(tx, -1.352, 0.12), Vector3(tx * 2.0, -0.05, 1.0), Vector3(1, 0, 0), [0.05, 0.04, 0.03], 9.0, 0.011, hide, nail, 0.03)
		FleshKit.vein(hip, [Vector3(sx * 0.04, -0.1, 0.06), Vector3(sx * 0.045, -0.3, 0.09), Vector3(sx * 0.03, -0.5, 0.08), Vector3(sx * 0.02, -0.64, 0.07)], 0.006, vein_mat, rng)
		_legs.append(hip)
	# Rumpf: eingefallener Bauch, Brustkorb mit Rippen, Wirbelsäule und Schulterblätter am krummen Rücken
	var torso := Node3D.new()
	torso.position = Vector3(0, 1.36, 0)
	torso.rotation_degrees.x = 24.0
	body.add_child(torso)
	FleshKit.limb(torso, [Vector3(0, 0, 0), Vector3(0, 0.22, 0.0), Vector3(0, 0.46, -0.02), Vector3(0, 0.72, -0.01), Vector3(0, 0.92, -0.03), Vector3(0, 1.02, -0.02)],
			[Vector2(0.13, 0.09), Vector2(0.095, 0.065), Vector2(0.14, 0.1), Vector2(0.175, 0.125), Vector2(0.19, 0.11), Vector2(0.09, 0.07)], hide, 14)
	for k in 7:
		var y := 0.48 + k * 0.065
		FleshKit.rib(torso, Vector3(0, y, -0.02), 0.165 - absf(k - 3.0) * 0.012, 0.118 + (0.006 if k < 4 else -0.004 * (k - 3)), 0.06, 0.008, hide)
	FleshKit.limb(torso, [Vector3(0, 0.5, 0.11), Vector3(0, 0.7, 0.13), Vector3(0, 0.88, 0.115)], [0.014, 0.018, 0.016], pale, 6)   # Brustbein
	# Wirbelsäule als durchgehender Grat mit leichten Knoten
	var spine: Array = []
	for k in 8:
		spine.append(Vector3(0, 0.02 + k * 0.135, -0.075 - sin(k * 0.45) * 0.035))
	FleshKit.limb(torso, spine, [0.012, 0.016, 0.018, 0.02, 0.02, 0.018, 0.016, 0.012], hide, 6)
	for k in 14:
		var y := 0.04 + k * 0.072
		FleshKit.bulb(torso, Vector3(0, y, -0.08 - sin(y / 0.135 * 0.45) * 0.035), Vector3(0.018, 0.012, 0.012), hide)
	for sx: float in [-1.0, 1.0]:
		FleshKit.bulb(torso, Vector3(sx * 0.1, 0.82, -0.1), Vector3(0.075, 0.1, 0.025), hide, Vector3(10, 0, sx * -12.0))
		FleshKit.limb(torso, [Vector3(sx * 0.03, 0.97, 0.08), Vector3(sx * 0.11, 0.99, 0.075), Vector3(sx * 0.19, 0.97, 0.03)], [0.012, 0.014, 0.012], pale, 6)   # Schlüsselbein
		FleshKit.vein(torso, [Vector3(sx * 0.06, 0.2, 0.06), Vector3(sx * 0.08, 0.34, 0.075), Vector3(sx * 0.1, 0.48, 0.1), Vector3(sx * 0.12, 0.6, 0.12)], 0.005, vein_mat, rng)
	# Hals mit Sehnen
	FleshKit.limb(torso, [Vector3(0, 0.96, -0.02), Vector3(0, 1.06, 0.01), Vector3(0, 1.17, 0.06)], [Vector2(0.06, 0.05), 0.04, 0.046], hide, 12)
	for sx: float in [-1.0, 1.0]:
		FleshKit.spindle(torso, Vector3(sx * 0.03, 0.96, 0.06), Vector3(sx * 0.012, 1.16, 0.09), 0.011, hide, 0.5, 6)
	# Kopf: lang, schmal, nach hinten gebogen. Vorn ein senkrechter Spalt mit wulstigen Rändern und vielen Augen.
	_head = Node3D.new()
	_head.position = Vector3(0, 1.14, 0.06)
	_head.rotation_degrees.x = -12.0   # Kopf fast senkrecht über dem gebeugten Rumpf, der Spalt schaut nach vorn
	torso.add_child(_head)
	var skull := FleshKit.limb(_head, [Vector3(0, 0.0, 0.0), Vector3(0, 0.12, 0.03), Vector3(0, 0.3, 0.03), Vector3(0, 0.48, 0.0), Vector3(0, 0.6, -0.05)],
			[Vector2(0.05, 0.06), Vector2(0.085, 0.095), Vector2(0.1, 0.11), Vector2(0.08, 0.095), Vector2(0.03, 0.04)], hide, 16)
	skull.name = "Skull"
	for k in 5:
		# Hautfalten am Hinterkopf
		var y := 0.18 + k * 0.07
		FleshKit.limb(_head, [Vector3(-0.07, y, -0.06), Vector3(0, y + 0.012, -0.105 + k * 0.006), Vector3(0.07, y, -0.06)], [0.004, 0.009, 0.004], hide, 5, 3)
	FleshKit.limb(_head, [Vector3(0, 0.1, 0.116), Vector3(0, 0.25, 0.128), Vector3(0, 0.4, 0.12), Vector3(0, 0.5, 0.09)], [Vector2(0.006, 0.01), Vector2(0.016, 0.012), Vector2(0.016, 0.012), Vector2(0.005, 0.008)], slit, 6)
	for sx: float in [-1.0, 1.0]:
		FleshKit.limb(_head, [Vector3(sx * 0.008, 0.08, 0.108), Vector3(sx * 0.026, 0.2, 0.124), Vector3(sx * 0.028, 0.34, 0.124), Vector3(sx * 0.018, 0.46, 0.106), Vector3(sx * 0.004, 0.52, 0.085)],
				[0.006, 0.013, 0.014, 0.011, 0.005], lip, 7)
	for i in 15:
		var y := 0.12 + i * 0.024 + rng.randf_range(-0.006, 0.006)
		var x := rng.randf_range(-0.011, 0.011)
		var r := rng.randf_range(0.0065, 0.012) * (1.0 - absf(i - 7.0) / 14.0)
		BuildKit.sphere(_head, r, Vector3(x, y, 0.13), _eye_mat, Vector3.ONE, 6)
	_eye_light = OmniLight3D.new()
	_eye_light.light_color = Color(0.55, 0.85, 1.0)
	_eye_light.light_energy = 0.35
	_eye_light.omni_range = 2.5
	_eye_light.position = Vector3(0, 0.3, 0.3)
	_head.add_child(_eye_light)
	# Arme: dünn, knochige Ellbogen, lange Hände mit fünf Fingern bis unters Knie
	for sx: float in [-1.0, 1.0]:
		var sh := Node3D.new()
		sh.position = Vector3(sx * 0.2, 0.95, 0.0)
		torso.add_child(sh)
		FleshKit.bulb(sh, Vector3(sx * 0.008, -0.06, 0.0), Vector3(0.04, 0.075, 0.042), hide, Vector3(0, 0, sx * 8.0))
		FleshKit.limb(sh, [Vector3.ZERO, Vector3(sx * 0.01, -0.4, 0.0), Vector3(0, -0.78, 0.0)], [0.04, 0.032, 0.026], hide, 10)
		FleshKit.spindle(sh, Vector3(sx * 0.01, -0.06, 0.02), Vector3(0, -0.6, 0.02), 0.024, hide, 0.35, 8)
		FleshKit.bulb(sh, Vector3(0, -0.8, -0.028), Vector3(0.024, 0.03, 0.02), pale)
		FleshKit.limb(sh, [Vector3(0, -0.8, 0.0), Vector3(0, -1.15, 0.06), Vector3(0, -1.48, 0.09)], [0.028, 0.022, 0.017], hide, 9)
		FleshKit.spindle(sh, Vector3(0, -0.84, 0.02), Vector3(0, -1.3, 0.05), 0.019, hide, 0.3, 7)
		FleshKit.vein(sh, [Vector3(0, -0.85, 0.03), Vector3(sx * 0.01, -1.05, 0.05), Vector3(0, -1.25, 0.06), Vector3(0, -1.45, 0.065)], 0.0045, vein_mat, rng)
		FleshKit.bulb(sh, Vector3(0, -1.5, 0.05), Vector3(0.02, 0.018, 0.016), hide)
		FleshKit.limb(sh, [Vector3(0, -1.5, 0.05), Vector3(0, -1.56, 0.058), Vector3(0, -1.6, 0.06)], [Vector2(0.024, 0.012), Vector2(0.03, 0.011), Vector2(0.032, 0.01)], hide, 8, 3)
		for f in 5:
			var fx := (f - 2.0) * 0.014
			var thumb := f == (0 if sx > 0.0 else 4)
			var base := Vector3(fx, -1.6, 0.06 + (0.012 if thumb else 0.0))
			var dir := Vector3(fx * 1.5 + (sx * -0.25 if thumb else 0.0), -1.0, 0.18)
			var lens := [0.06, 0.05, 0.045] if thumb else [0.11, 0.1, 0.085]
			FleshKit.finger(sh, base, dir, Vector3(1, 0, 0), lens, -13.0, 0.009, hide, nail, 0.03)
		_arms.append(sh)


# --- Verhalten -----------------------------------------------------------------

func _process(delta: float) -> void:
	# Wer sich durchs Gebüsch bewegt, bringt es zum Rascheln (Wind-Knoten: Pflanzen wackeln, „ist das nur der Wind?“)
	var _moved := global_position.distance_to(_last_rustle_pos)
	if _moved > 0.02:
		Wind.disturb(global_position + Vector3(0, 0.6, 0), clampf(_moved / maxf(delta, 0.001) / 4.0, 0.0, 1.0) * 0.5)
	_last_rustle_pos = global_position
	_life += delta
	_click_t -= delta
	if _click_t <= 0.0:
		_click_t = _rng.randf_range(4.0, 9.0)
		if not SoundBank.play_rec(get_parent(), "seeker_chitter", global_position + Vector3(0, 2.2, 0), -12.0, 18.0):
			CreatureSounds.play_phrase(self, "click", global_position + Vector3(0, 2.2, 0), -12.0, 1.2, 18.0)
	# Am Morgen oder nach Ablauf der Zeit: abziehen
	if state != State.LEAVE and (not TimeManager.is_night() or _life > cfg.stay_time):
		_leave()
	_sense_t -= delta
	if _sense_t <= 0.0 and state in [State.WATCH, State.SEARCH, State.ARRIVE]:
		_sense_t = 0.5
		_sense()
	_moving = false
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
	SoundBank.loop_level(_hum, 1.0 if state == State.WATCH else 0.7, delta, 1.0)
	SoundBank.loop_level(_steps, 1.0 if _moving else 0.0, delta)
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
	if _blocked(p):
		# um die Hütte / den Schuppen herum statt hindurch
		var c := Shed.ORIGIN if Shed.is_inside(p) else Vector3.ZERO
		var out := Vector3(global_position.x - c.x, 0, global_position.z - c.z).normalized()
		var tan := Vector3(-out.z, 0, out.x)
		if tan.dot(to) < 0.0:
			tan = -tan
		p = global_position + tan * _speed() * delta
		if _blocked(p):
			p = global_position + out * _speed() * delta
	p.y = Terrain.height_at(p.x, p.z)
	global_position = p
	_face(goal, delta)
	_walk_phase += delta * _speed() * 3.2
	_moving = true


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
			# zieht er von selbst ab, verschwindet er ebenfalls im Blitz – manchmal mit Asche
			Apparition.flash(get_parent(), global_position + Vector3(0, 1.4, 0))
			SoundBank.play_rec(get_parent(), "seeker_teleport", global_position + Vector3(0, 1.4, 0), 0.0, 60.0)
			_drop_ash(cfg.ash_leave_chance)
			queue_free()


func _start_search() -> void:
	state = State.SEARCH
	var pts: Array = []
	for i in _rng.randi_range(cfg.search_points.x, cfg.search_points.y):
		var a := _rng.randf() * TAU
		var r := _rng.randf_range(2.5, cfg.search_radius)
		pts.append(_ground(target + Vector3(cos(a) * r, 0, sin(a) * r)))
	_go(pts)


## Geräusche bringen Verdacht (Stealth): ab „sieht nach“ geht er hin, vorher hält er nur inne.
func _on_noise(pos: Vector3, radius: float) -> void:
	if state in [State.STRIKE, State.LEAVE]:
		return
	if awareness.hear(pos, radius, pos.distance_to(global_position), cfg.hearing, clampf(radius / 8.0, 0.5, 1.6)):
		awareness.tick(0.0)
		if awareness.stage() >= Awareness.Stage.INVESTIGATE:
			_investigate(pos)
		elif awareness.stage() >= Awareness.Stage.SUSPECT:
			_hold = maxf(_hold, 1.5)


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
	# Lichtköder (Forschung) zieht ihn an – solange du nicht direkt vor ihm stehst
	if d > 6.0:
		var lure_r := float(Research.gadget("light_lure", "range", 70.0))
		for lure in get_tree().get_nodes_in_group("seeker_lure"):
			var lp := (lure as Node3D).global_position
			if lp.distance_to(global_position) < lure_r and lp.distance_to(target) > 3.0:
				target = lp
				_investigate(lp)
				return
	# Fremdes am Körper (W-17, Funde, Alien-Werkzeuge) ruft ihn – je mehr, desto weiter (W-17 allein: w17_range)
	var sig := Research.carried_signature()
	if sig >= cfg.signature_min and d < cfg.w17_range * clampf(sig / 0.5, 0.0, 2.0):
		_investigate(pp)
		return
	# getarnt im Gebüsch: nur ganz nah gewittert
	if not _player.detectable_from(global_position, cfg.cover_sniff_range):
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
	# Sehen und Atem: Verdacht in Stufen (dunkel, im Schatten, hinter einer Kante lehnend sieht er dich später)
	if camp == null:
		var range_m := lerpf(cfg.sight_dark * 0.4, cfg.sight_lit, _player.visibility)
		if d < range_m:
			var part := Stealth.seen_part(get_world_3d(), global_position + Vector3(0, 2.3, 0), _player)
			awareness.see(0.5, pp, part, d, range_m)
	var br := Stealth.breath_radius(_player)
	if br > 0.0 and d < br:
		awareness.hear_breath(0.5, pp)
	awareness.tick(0.5)
	if awareness.stage() >= Awareness.Stage.INVESTIGATE:
		_investigate(awareness.last_pos)


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
		var lured := camp.glowing() or Research.carried_signature() >= 0.4
		if lured or (ThreatDirector.current_night() >= cfg.tear_from_day and _rng.randf() < cfg.tear_chance_dark):
			_strike(camp)
			return
		# Er steht vor dem Zelt, atmet – und geht weiter
		CreatureSounds.play_phrase(self, "breath_click", global_position + Vector3(0, 2.0, 0), -4.0, 4.0, 14.0)
		_hold = 5.0
		_start_search()
		return
	if camp == null and d < 2.2 and not _player.is_hidden() and not _blocked_at(_player.global_position):
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
		SoundBank.play_rec(get_parent(), "seeker_teleport", global_position + Vector3(0, 1.4, 0), 0.0, 60.0)
		_drop_ash(1.0)
		queue_free()


## Wo er im Blitz verschwindet, bleibt Asche zurück (Forschung).
func _drop_ash(chance: float) -> void:
	var drops := AlienDrops.get_for(get_tree())
	if drops and _rng.randf() < chance:
		drops.spawn("seeker_ash", _ground(global_position) + Vector3(0, 0.02, 0))


## Morgengrauen (ThreatDirector): abziehen.
func dawn() -> void:
	if state != State.LEAVE:
		_leave()


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
