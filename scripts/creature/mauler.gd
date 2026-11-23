class_name Mauler
extends Node3D
## Der Zerfleischer: geht auf zwei nach hinten geknickten Beinen, der Oberkörper ragt weit nach vorn,
## lange Klauen an den Händen, große schwarze Augen wie die klassischen „Greys“, darunter ein Maul voller Reißzähne.
## Er setzt nicht auf leise Angst, er jagt: heranschleichen (Warnzeichen: Äste, Hecheln) → kurz aufrichten und
## kreischen → Sprint, so schnell wie du → Klauenhieb → zurückweichen, Halbkreis, erneuter Angriff.
## Mehrere Treffer töten (der Tag beginnt neu). Licht vertreibt ihn zuverlässig: LED-Lampe der Uhr ins Gesicht,
## Feuer, Scheinwerfer, Lichtköder. Ins Haus kommt er nicht; wer drinnen oder versteckt ist, den verliert er.
## Werte: data/creatures/mauler.tres (MaulerConfig). Wann er kommt: ThreatConfig mauler_* (ab Story-Phase 2).

enum State { STALK, WARN, CHARGE, STRIKE, RETREAT, CIRCLE, FLEE, PROWL, LEAVE }

var _last_rustle_pos := Vector3.ZERO
var cfg: MaulerConfig
var state: State = State.STALK
var hits: int = 0                  ## Treffer in dieser Jagd (für Tests)
var _rng := RandomNumberGenerator.new()
var _player: Player
var _t: float = 0.0                ## Zeit im aktuellen Zustand
var _life: float = 0.0
var _lost: float = 0.0
var _lit: float = 0.0
var _cue_t: float = 2.0
var _goal: Vector3
var _circle_center: Vector3
var _circle_angle: float = 0.0
var _circle_left: float = 0.0
var _circle_dir: float = 1.0
var _flee_until: float = 0.0
var _speed_now: float = 0.0
var _steps: AudioStreamPlayer3D = null  # eigene Schritte (Schleife, Lautstärke nach Tempo)
var _walk_phase: float = 0.0
var _swing: float = 0.0
var _model: Node3D
var _torso: Node3D
var _head: Node3D
var _jaw: Node3D
var _arms: Array[Node3D] = []
var _legs: Array[Node3D] = []
## Verdacht (Stealth): erst wenn er dich wirklich bemerkt hat, richtet er sich auf und greift an
var awareness := Awareness.new()


## Erscheint außer Sicht im Wald rund um den Spieler (nur einer gleichzeitig).
static func spawn_near(scene: Node, player_pos: Vector3) -> Mauler:
	for m in scene.get_tree().get_nodes_in_group("mauler"):
		return m as Mauler
	var m := Mauler.new()
	m.name = "Mauler"
	scene.add_child(m)
	m.place_near(player_pos)
	return m


func _ready() -> void:
	add_to_group("mauler")
	add_to_group("aware")
	EventBus.noise_made.connect(_on_noise)
	cfg = MaulerConfig.get_default()
	_rng.randomize()
	_player = get_tree().get_first_node_in_group("player") as Player
	_build_model()
	_steps = SoundBank.attach_loop(self, "mauler_steps", -2.0, 45.0, 0.2)
	Tasks.flag("mauler_seen")


func place_near(p: Vector3) -> void:
	var best := Vector3.ZERO
	for attempt in 10:
		var a := _rng.randf() * TAU
		var d := _rng.randf_range(cfg.spawn_distance.x, cfg.spawn_distance.y)
		var q := _ground(p + Vector3(cos(a), 0, sin(a)) * d)
		best = q
		if not Cabin.is_inside(q) and not Shed.is_inside(q) and not Cabin.blocks_ground(q) and _bright_at(q) == Vector3.INF and not _player_sees(q):
			break
	global_position = best
	print("[Mauler] erscheint bei ", global_position)


static func _ground(p: Vector3) -> Vector3:
	return Vector3(p.x, Terrain.height_at(p.x, p.z), p.z)


# --- Aussehen -----------------------------------------------------------------

func _build_model() -> void:
	# Christian 23.11.: organischer und detaillierter – Muskeln, Sehnen, Rippen unter der Haut, Rückengrat,
	# Grey-Schädel mit Wangenknochen und Brauenwulst, Maul mit Zahnfleisch und Reißzähnen, sichelförmige Klauen.
	var rng := RandomNumberGenerator.new()
	rng.seed = 3601
	var skin := FleshKit.skin(Color(0.58, 0.55, 0.57), 0.6, 0.11)
	var shade := FleshKit.skin(Color(0.45, 0.42, 0.45), 0.6, 0.11)      # Muskelfurchen, Rückengrat
	var dark := BuildKit.color_mat(Color(0.16, 0.15, 0.17), 0.45)
	var vein_mat := BuildKit.color_mat(Color(0.27, 0.24, 0.32), 0.6)
	var claw_mat := BuildKit.color_mat(Color(0.07, 0.065, 0.06), 0.2, 0.35)
	var eye := StandardMaterial3D.new()
	eye.albedo_color = Color(0.005, 0.005, 0.008)
	eye.metallic = 0.3
	eye.roughness = 0.04
	eye.metallic_specular = 1.0
	var tooth := BuildKit.color_mat(Color(0.88, 0.85, 0.76), 0.3)
	var gum := FleshKit.skin(Color(0.45, 0.14, 0.16), 0.25, 0.11)
	_model = Node3D.new()
	_model.name = "Body"
	add_child(_model)
	# Becken
	FleshKit.limb(_model, [Vector3(0, 1.18, -0.08), Vector3(0, 1.06, -0.05), Vector3(0, 0.96, 0.0)], [Vector2(0.2, 0.15), Vector2(0.25, 0.17), Vector2(0.16, 0.12)], skin, 14)
	# Beine (Zehengänger): kräftige Oberschenkel, Unterschenkel nach hinten, langer Mittelfuß, drei Krallenzehen
	for sx: float in [-1.0, 1.0]:
		var hip := Node3D.new()
		hip.position = Vector3(sx * 0.19, 1.05, -0.05)
		_model.add_child(hip)
		FleshKit.limb(hip, [Vector3(0, 0.04, -0.02), Vector3(sx * 0.02, -0.18, 0.12), Vector3(0, -0.4, 0.23)], [0.14, Vector2(0.12, 0.13), 0.08], skin, 14)
		FleshKit.spindle(hip, Vector3(sx * 0.02, -0.02, 0.08), Vector3(0, -0.36, 0.28), 0.07, skin, 0.4)          # vorderer Oberschenkelmuskel
		FleshKit.spindle(hip, Vector3(sx * 0.05, -0.04, -0.06), Vector3(sx * 0.01, -0.36, 0.14), 0.06, shade, 0.45)   # hinterer
		FleshKit.vein(hip, [Vector3(sx * 0.1, -0.02, 0.06), Vector3(sx * 0.11, -0.15, 0.14), Vector3(sx * 0.09, -0.28, 0.2), Vector3(sx * 0.07, -0.37, 0.24)], 0.008, vein_mat, rng)
		var knee := Node3D.new()
		knee.name = "Knee"
		knee.position = Vector3(0, -0.4, 0.23)
		hip.add_child(knee)
		FleshKit.bulb(knee, Vector3(0, 0.01, 0.06), Vector3(0.05, 0.06, 0.03), shade)
		FleshKit.limb(knee, [Vector3.ZERO, Vector3(0, -0.18, -0.15), Vector3(0, -0.37, -0.31)], [0.08, 0.06, 0.045], skin, 12)
		FleshKit.spindle(knee, Vector3(0, -0.03, -0.06), Vector3(0, -0.3, -0.33), 0.055, skin, 0.3)   # Wade
		FleshKit.limb(knee, [Vector3(0, -0.06, 0.02), Vector3(0, -0.2, -0.1), Vector3(0, -0.34, -0.25)], [0.012, 0.016, 0.01], shade, 6)   # Schienbeinkante
		var ankle := Node3D.new()
		ankle.position = Vector3(0, -0.37, -0.31)
		knee.add_child(ankle)
		FleshKit.bulb(ankle, Vector3(0, 0, -0.01), Vector3(0.055, 0.05, 0.06), skin)
		FleshKit.limb(ankle, [Vector3.ZERO, Vector3(0, -0.14, 0.04), Vector3(0, -0.26, 0.1)], [Vector2(0.05, 0.045), Vector2(0.045, 0.04), Vector2(0.06, 0.035)], skin, 10)
		for t in 3:
			var tx := (t - 1) * 0.045
			FleshKit.finger(ankle, Vector3(tx, -0.265, 0.11), Vector3(tx * 2.5, -0.15, 1.0), Vector3(1, 0, 0), [0.06, 0.05], 12.0, 0.022, skin, claw_mat, 0.09)
		_legs.append(hip)
	# Rumpf: weit nach vorn geneigt, kräftiger Brustkorb, Rippen, Brustmuskeln, Rückengrat aus Knochenplatten
	_torso = Node3D.new()
	_torso.position = Vector3(0, 1.05, -0.05)
	_torso.rotation_degrees.x = 62.0
	_model.add_child(_torso)
	FleshKit.limb(_torso, [Vector3(0, 0.0, 0.0), Vector3(0, 0.2, 0.01), Vector3(0, 0.42, 0.04), Vector3(0, 0.66, 0.05), Vector3(0, 0.86, 0.04), Vector3(0, 1.0, 0.06)],
			[Vector2(0.21, 0.16), Vector2(0.19, 0.15), Vector2(0.27, 0.21), Vector2(0.33, 0.25), Vector2(0.34, 0.22), Vector2(0.17, 0.15)], skin, 18)
	for k in 6:
		var y := 0.4 + k * 0.075
		FleshKit.rib(_torso, Vector3(0, y, 0.04), 0.27 - absf(k - 2.5) * 0.02, 0.2 + 0.01 * minf(k, 3.0), 0.07, 0.016, shade)
	for k in 4:
		# Bauchmuskeln
		for sx: float in [-1.0, 1.0]:
			FleshKit.bulb(_torso, Vector3(sx * 0.055, 0.08 + k * 0.085, 0.16), Vector3(0.05, 0.036, 0.022), skin)
	for sx: float in [-1.0, 1.0]:
		FleshKit.bulb(_torso, Vector3(sx * 0.13, 0.78, 0.2), Vector3(0.14, 0.1, 0.06), skin, Vector3(0, 0, sx * -20.0))     # Brustmuskel
		FleshKit.spindle(_torso, Vector3(sx * 0.18, 0.3, -0.02), Vector3(sx * 0.3, 0.82, -0.04), 0.08, skin, 0.6)            # breiter Rückenmuskel
		FleshKit.bulb(_torso, Vector3(sx * 0.15, 0.78, -0.17), Vector3(0.12, 0.15, 0.05), shade, Vector3(10, 0, sx * -15.0))  # Schulterblatt
		FleshKit.vein(_torso, [Vector3(sx * 0.12, 0.15, 0.15), Vector3(sx * 0.17, 0.35, 0.19), Vector3(sx * 0.2, 0.52, 0.22), Vector3(sx * 0.15, 0.68, 0.24)], 0.008, vein_mat, rng)
	for k in 11:
		var y := 0.04 + k * 0.095
		var plate := FleshKit.bulb(_torso, Vector3(0, y, -0.2 - sin(k * 0.35) * 0.04), Vector3(0.04, 0.045, 0.035), dark, Vector3(-25, 0, 0))
		plate.name = "Spine%d" % k
	# Hals und Kopf: großer Grey-Schädel, schräge schwarze Mandelaugen, Wangenknochen, Brauenwulst, Maul voller Reißzähne
	var neck := Node3D.new()
	neck.position = Vector3(0, 1.02, 0.12)
	_torso.add_child(neck)
	FleshKit.limb(neck, [Vector3(0, -0.1, -0.04), Vector3(0, 0.03, 0.0), Vector3(0, 0.15, 0.03)], [Vector2(0.15, 0.12), Vector2(0.1, 0.09), Vector2(0.09, 0.08)], skin, 12)
	for sx: float in [-1.0, 1.0]:
		FleshKit.spindle(neck, Vector3(sx * 0.08, -0.1, 0.06), Vector3(sx * 0.03, 0.14, 0.09), 0.025, skin, 0.5, 7)
	_head = Node3D.new()
	_head.position = Vector3(0, 0.16, 0.02)
	_head.rotation_degrees.x = -60.0
	neck.add_child(_head)
	FleshKit.bulb(_head, Vector3(0, 0.2, -0.08), Vector3(0.19, 0.21, 0.28), skin, Vector3(-12, 0, 0), 26)
	FleshKit.limb(_head, [Vector3(0, 0.16, 0.02), Vector3(0, 0.07, 0.1), Vector3(0, -0.01, 0.16)], [Vector2(0.15, 0.12), Vector2(0.1, 0.085), Vector2(0.06, 0.05)], skin, 16)
	FleshKit.limb(_head, [Vector3(-0.15, 0.22, 0.1), Vector3(0, 0.25, 0.165), Vector3(0.15, 0.22, 0.1)], [0.015, 0.03, 0.015], skin, 8)   # Brauenwulst
	for sx: float in [-1.0, 1.0]:
		FleshKit.bulb(_head, Vector3(sx * 0.12, 0.08, 0.11), Vector3(0.05, 0.035, 0.045), skin, Vector3(0, 0, sx * 20.0))   # Wangenknochen
		var sock := BuildKit.sphere(_head, 0.1, Vector3(sx * 0.088, 0.15, 0.135), dark, Vector3(1.0, 0.62, 0.45), 14)
		sock.rotation_degrees.z = sx * -28.0
		var e := BuildKit.sphere(_head, 0.095, Vector3(sx * 0.09, 0.15, 0.15), eye, Vector3(1.0, 0.55, 0.42), 16)
		e.rotation_degrees.z = sx * -28.0
		BuildKit.sphere(_head, 0.008, Vector3(sx * 0.018, 0.02, 0.185), dark, Vector3(1.0, 1.6, 0.6), 6)   # Nasenschlitze
		FleshKit.vein(_head, [Vector3(sx * 0.08, 0.33, 0.0), Vector3(sx * 0.13, 0.3, -0.06), Vector3(sx * 0.17, 0.24, -0.1), Vector3(sx * 0.19, 0.14, -0.12)], 0.006, vein_mat, rng)
	_jaw = Node3D.new()
	_jaw.position = Vector3(0, -0.03, 0.1)
	_head.add_child(_jaw)
	FleshKit.limb(_jaw, [Vector3(-0.08, -0.04, -0.04), Vector3(-0.06, -0.06, 0.07), Vector3(0, -0.065, 0.12), Vector3(0.06, -0.06, 0.07), Vector3(0.08, -0.04, -0.04)], [0.02, 0.025, 0.028, 0.025, 0.02], skin, 8)
	FleshKit.limb(_jaw, [Vector3(-0.06, -0.035, 0.0), Vector3(0, -0.04, 0.1), Vector3(0.06, -0.035, 0.0)], [0.012, 0.018, 0.012], gum, 6)
	FleshKit.limb(_head, [Vector3(-0.07, -0.035, 0.08), Vector3(0, -0.04, 0.19), Vector3(0.07, -0.035, 0.08)], [0.012, 0.02, 0.012], gum, 6)
	for i in 11:
		var x := (i - 5) * 0.014
		var long := i % 5 == 0
		var bend := Vector3(8, 0, -x * 200.0)
		BuildKit.cylinder(_jaw, 0.006, 0.055 if long else 0.03, Vector3(x, -0.02, 0.115 - absf(x) * 0.75), tooth, false, Vector3(180, 0, 0) + bend, 0.0, 5)
		BuildKit.cylinder(_head, 0.006, 0.06 if long else 0.034, Vector3(x, -0.06, 0.19 - absf(x) * 0.75), tooth, false, bend, 0.0, 5)
	# Arme: lang und sehnig, drei sichelförmige Klauen je Hand
	for sx: float in [-1.0, 1.0]:
		var sh := Node3D.new()
		sh.position = Vector3(sx * 0.33, 0.82, 0.05)
		_torso.add_child(sh)
		FleshKit.bulb(sh, Vector3(sx * 0.02, -0.04, 0.0), Vector3(0.11, 0.13, 0.1), skin, Vector3(0, 0, sx * 10.0))     # Schultermuskel
		FleshKit.limb(sh, [Vector3.ZERO, Vector3(sx * 0.01, -0.25, 0.01), Vector3(0, -0.5, 0)], [0.085, Vector2(0.07, 0.075), 0.055], skin, 12)
		FleshKit.spindle(sh, Vector3(0, -0.08, 0.05), Vector3(0, -0.45, 0.04), 0.05, skin, 0.5)
		FleshKit.spindle(sh, Vector3(0, -0.06, -0.05), Vector3(0, -0.48, -0.04), 0.05, shade, 0.4)
		FleshKit.vein(sh, [Vector3(sx * 0.05, -0.1, 0.03), Vector3(sx * 0.06, -0.25, 0.05), Vector3(sx * 0.05, -0.4, 0.04), Vector3(sx * 0.03, -0.5, 0.03)], 0.007, vein_mat, rng)
		var elbow := Node3D.new()
		elbow.name = "Elbow"
		elbow.position = Vector3(0, -0.5, 0)
		elbow.rotation.x = -0.5
		sh.add_child(elbow)
		FleshKit.bulb(elbow, Vector3(0, 0, -0.03), Vector3(0.05, 0.055, 0.045), shade)
		FleshKit.limb(elbow, [Vector3.ZERO, Vector3(0, -0.22, 0.015), Vector3(0, -0.45, 0.0)], [0.06, Vector2(0.055, 0.045), 0.04], skin, 11)
		FleshKit.spindle(elbow, Vector3(0, -0.02, 0.03), Vector3(0, -0.36, 0.03), 0.04, skin, 0.35)
		FleshKit.limb(elbow, [Vector3(0, -0.44, 0.0), Vector3(0, -0.5, 0.02), Vector3(0, -0.55, 0.04)], [Vector2(0.05, 0.03), Vector2(0.065, 0.032), Vector2(0.06, 0.028)], skin, 10)
		for f in 3:
			var claw := Node3D.new()
			claw.name = "Claw%d" % f
			elbow.add_child(claw)
			var fx := (f - 1) * 0.038
			FleshKit.finger(claw, Vector3(fx, -0.55, 0.04), Vector3(fx * 1.8, -1.0, 0.35), Vector3(1, 0, 0), [0.06, 0.05], -14.0, 0.02, skin, claw_mat, 0.3)
		_arms.append(sh)


## Ein Glied von a nach b (Zylinder entlang der Strecke, dicker am Anfang).
func _limb(parent: Node3D, a: Vector3, b: Vector3, r0: float, r1: float, mat: Material) -> void:
	var d := b - a
	var mi := BuildKit.cylinder(parent, r0, d.length(), (a + b) * 0.5, mat, false, Vector3.ZERO, r1, 7)
	mi.basis = Basis(Quaternion(Vector3.UP, d.normalized()))
	mi.position = (a + b) * 0.5


# --- Verhalten -----------------------------------------------------------------

func _process(delta: float) -> void:
	# Wer sich durchs Gebüsch bewegt, bringt es zum Rascheln (Wind-Knoten: Pflanzen wackeln, „ist das nur der Wind?“)
	var _moved := global_position.distance_to(_last_rustle_pos)
	if _moved > 0.02:
		Wind.disturb(global_position + Vector3(0, 0.6, 0), clampf(_moved / maxf(delta, 0.001) / 4.0, 0.0, 1.0) * 0.9)
	_last_rustle_pos = global_position
	if _player == null or not is_instance_valid(_player):
		queue_free()
		return
	SoundBank.loop_level(_steps, _speed_now / maxf(cfg.charge_speed, 0.1) * 1.3, delta)
	_life += delta
	_t += delta
	var to_p := _player.global_position - global_position
	to_p.y = 0.0
	var dist := to_p.length()
	# Am Morgen oder nach der Jagdzeit: weg
	if state != State.LEAVE and state != State.FLEE and (_life > cfg.hunt_time or (not TimeManager.is_night() and not _day_hunt_ok())):
		_enter(State.LEAVE)
	# Licht vertreibt ihn – immer
	if state in [State.STALK, State.WARN, State.CHARGE, State.RETREAT, State.CIRCLE, State.PROWL]:
		if _led_on_me(dist):
			_lit += delta
			if _lit >= cfg.led_time:
				_flee("led")
				return
		else:
			_lit = maxf(_lit - delta, 0.0)
		var b := _bright_at(global_position)
		if b != Vector3.INF:
			_flee("bright", b)
			return
	# Wer im Haus, im Versteck oder im Zelt ist, den verliert er
	var reachable := _player_reachable()
	_perceive(delta, dist, reachable)
	match state:
		State.STALK:
			if not reachable:
				_enter(State.PROWL)
			else:
				_cues(delta, dist)
				_move_toward(_player.global_position, cfg.stalk_speed, delta)
				if dist < cfg.charge_distance and _clear_line() and awareness.alert():
					_enter(State.WARN)
					EventBus.fear_spike.emit(0.9)
		State.WARN:
			# sich aufrichten, Maul auf, kreischen – dann losrennen
			_face(_player.global_position, delta, 6.0)
			_speed_now = 0.0
			if _t < delta * 1.5:
				_voice("mauler_roar", "shriek", 1.6, 2.0, 0.78, 70.0)
			if _t >= cfg.charge_warning:
				_enter(State.CHARGE)
		State.CHARGE:
			if not reachable:
				_enter(State.PROWL)
			elif dist <= cfg.strike_range:
				_enter(State.STRIKE)
			else:
				_move_toward(_player.global_position, cfg.charge_speed, delta)
				if _rng.randf() < delta * 0.8:
					_voice("mauler_snarl", "breath", 1.4, -2.0, 0.7, 30.0)
		State.STRIKE:
			_face(_player.global_position, delta, 10.0)
			_speed_now = 0.0
			_swing = clampf(_t / 0.35, 0.0, 1.0)
			if _t >= 0.28 and _t - delta < 0.28:
				SoundBank.play_rec(get_parent(), "mauler_swipe", global_position + Vector3(0, 1.3, 0), 0.0, 35.0)
				if dist <= cfg.strike_range + 0.5 and reachable:
					hits += 1
					_player.take_damage(cfg.hit_damage, global_position, "mauler")
					EventBus.screen_shake.emit(0.35)
					_voice("mauler_snarl", "shriek", 1.5, -2.0, 1.15, 40.0)
				elif not SoundBank.has_recording("mauler_swipe"):
					SoundBank.play_at(get_parent(), "gusts", global_position + Vector3(0, 1.3, 0), -10.0, 2.2)
			if _t >= 0.6:
				_start_retreat()
		State.RETREAT:
			_move_toward(_goal, cfg.retreat_speed, delta)
			if _flat(_goal - global_position).length() < 1.0 or _t > 5.0:
				_start_circle()
		State.CIRCLE:
			# Halbkreis um dich herum, dann erneuter Angriff
			_circle_center = _player.global_position
			var step := cfg.retreat_speed * delta / maxf(cfg.circle_radius, 1.0)
			_circle_angle += step * _circle_dir
			_circle_left -= step
			var p := _circle_center + Vector3(cos(_circle_angle), 0, sin(_circle_angle)) * cfg.circle_radius
			_move_toward(p, cfg.retreat_speed, delta)
			if _rng.randf() < delta * 0.5:
				_voice("mauler_snarl", "click", 1.5, -8.0, 0.8, 25.0)
			if _circle_left <= 0.0 or _t > 12.0:
				_enter(State.CHARGE if reachable else State.PROWL)
		State.PROWL:
			# um das Versteck / die Hütte herumschleichen, nicht hinein
			_lost += delta
			var a := _life * 0.25
			var c := _player.global_position + Vector3(cos(a), 0, sin(a)) * 10.0
			_move_toward(c, cfg.stalk_speed, delta)
			if _rng.randf() < delta * 0.3:
				_voice("mauler_snarl", "breath", 1.4, -8.0, 0.7, 30.0)
			if reachable:
				_lost = 0.0
				_enter(State.STALK)
			elif _lost > cfg.lose_time:
				_enter(State.LEAVE)
		State.FLEE:
			if _flat(_goal - global_position).length() > 2.0:
				_move_toward(_goal, cfg.flee_speed, delta)
			else:
				_speed_now = 0.0
				visible = false   # im Wald untergetaucht
			if _t >= _flee_until:
				if TimeManager.is_night() and _rng.randf() < cfg.return_chance and _life < cfg.hunt_time:
					place_near(_player.global_position)
					visible = true
					_enter(State.STALK)
				else:
					queue_free()
					return
		State.LEAVE:
			_move_toward(_goal, cfg.flee_speed * 0.8, delta)
			if _flat(_goal - global_position).length() < 2.0 or _t > 20.0:
				queue_free()
				return
	_animate(delta)


func _enter(s: State) -> void:
	state = s
	_t = 0.0
	if s == State.LEAVE:
		_goal = _ground(global_position + _flat(global_position - _player.global_position).normalized() * 60.0)


func _start_retreat() -> void:
	_swing = 0.0
	var away := _flat(global_position - _player.global_position).normalized()
	if away == Vector3.ZERO:
		away = Vector3.FORWARD
	_goal = _ground(_player.global_position + away.rotated(Vector3.UP, _rng.randf_range(-0.6, 0.6)) * _rng.randf_range(cfg.retreat_distance.x, cfg.retreat_distance.y))
	_enter(State.RETREAT)


func _start_circle() -> void:
	var rel := _flat(global_position - _player.global_position)
	_circle_angle = atan2(rel.z, rel.x)
	_circle_dir = 1.0 if _rng.randf() < 0.5 else -1.0
	_circle_left = deg_to_rad(_rng.randf_range(cfg.circle_degrees.x, cfg.circle_degrees.y))
	_enter(State.CIRCLE)


## Vertrieben: weg vom Licht (bzw. weg von dir), für eine Weile.
func _flee(why: String, from: Vector3 = Vector3.INF) -> void:
	var src := _player.global_position if from == Vector3.INF else from
	var away := _flat(global_position - src).normalized()
	if away == Vector3.ZERO:
		away = Vector3.BACK
	_goal = _ground(global_position + away * 45.0)
	_flee_until = _rng.randf_range(cfg.flee_time.x, cfg.flee_time.y)  # Sekunden
	_lit = 0.0
	_swing = 0.0
	_voice("mauler_roar", "recoil", 1.5, -3.0, 0.85, 50.0)
	if why == "led":
		Tasks.flag("mauler_repelled")
	_drop_find(why)
	_enter(State.FLEE)


## Vom Licht vertrieben lässt er etwas für die Forschung zurück (je einmal pro Tag):
## im LED-Kegel der Uhr reißt die schwarze Augenhaut ab, vor hellem Licht verliert er manchmal einen Reißzahn.
static var _film_day: int = -1
static var _tooth_day: int = -1


func _drop_find(why: String) -> void:
	var drops := AlienDrops.get_for(get_tree())
	if drops == null:
		return
	var at := _ground(global_position) + Vector3(0, 0.02, 0)
	if why == "led" and _film_day != TimeManager.day:
		_film_day = TimeManager.day
		drops.spawn("mauler_film", at)
	elif why == "bright" and _tooth_day != TimeManager.day and _rng.randf() < cfg.tooth_chance:
		_tooth_day = TimeManager.day
		drops.spawn("mauler_tooth", at)


## Morgengrauen (ThreatDirector): zieht ab und verschwindet spätestens nach 20 s.
func dawn() -> void:
	if has_meta("day_hunt"):
		remove_meta("day_hunt")
	if state != State.LEAVE:
		visible = true
		_enter(State.LEAVE)


func _day_hunt_ok() -> bool:
	# tagsüber nur, wenn er ausdrücklich für den Tag gerufen wurde (dichter Wald, weit weg)
	return has_meta("day_hunt")


# --- Wahrnehmung -----------------------------------------------------------------

## Trifft ihn gerade der LED-Kegel der Uhr (nicht das weiße Display)?
func _led_on_me(dist: float) -> bool:
	# Blendaufsatz (Forschung): die LED reicht weiter und streut breiter
	var lens := Inventory.count("glare_lens") > 0
	var reach := cfg.led_range * (float(Research.gadget("glare_lens", "led_range_factor", 1.6)) if lens else 1.0)
	var cone := cfg.led_cone * (float(Research.gadget("glare_lens", "led_cone_factor", 1.5)) if lens else 1.0)
	if dist > reach or not _player.light_shining() or _player.hands.screen_mode:
		return false
	var cam := _player.camera.global_transform
	var to := (global_position + Vector3(0, 1.3, 0)) - cam.origin
	if rad_to_deg((-cam.basis.z).angle_to(to.normalized())) > cone:
		return false
	return _clear_line()


## Helles Licht in der Nähe dieses Punktes? Gibt die Lichtquelle zurück (INF = keine).
func _bright_at(p: Vector3) -> Vector3:
	var r := cfg.bright_radius
	for c in get_tree().get_nodes_in_group("campfire"):
		if c.has_method("burning") and c.call("burning") and (c as Node3D).global_position.distance_to(p) < r:
			return (c as Node3D).global_position
	for s in get_tree().get_nodes_in_group("structure"):
		var st := s as Structure
		if st and st.type in ["motion_light", "strobe_light", "light_lure"] and (st.type == "light_lure" or st.is_lit()) and st.global_position.distance_to(p) < r:
			return st.global_position
	for l in get_tree().get_nodes_in_group("lamp"):
		var lamp := l as Node3D
		var light := lamp.get("light") as Light3D
		if light and light.visible and light.global_position.distance_to(p) < minf(r, 6.0) and not Cabin.is_inside(light.global_position):
			return light.global_position
	return Vector3.INF


func _player_reachable() -> bool:
	if GameState.dead or not _player.detectable_from(global_position, cfg.cover_sniff_range):
		return false   # versteckt oder getarnt im Gebüsch – er schleicht nur herum
	var pp := _player.global_position
	if Cabin.is_inside(pp) or Shed.is_inside(pp):
		return false
	for t in get_tree().get_nodes_in_group("tent_camp"):
		if t.has_method("occupied") and t.call("occupied"):
			return false
		# aufgerissenes Zelt: in dieser Nacht lässt er einen dort liegen (Zeltnacht tötet nicht)
		var tc := t as TentCamp
		if tc and tc.spared_until > TimeManager.get_total_hours() and tc.global_position.distance_to(pp) < 15.0:
			return false
	return _bright_at(pp) == Vector3.INF


func _player_sees(p: Vector3) -> bool:
	if _player == null:
		return false
	var cam := _player.camera.global_transform
	var to := (p + Vector3(0, 1.3, 0)) - cam.origin
	return rad_to_deg((-cam.basis.z).angle_to(to.normalized())) < 50.0 and to.length() < 40.0


## Sehen (Sichtbarkeit, Lehnen) und Hören sammeln Verdacht; Atem hört er aus der Nähe.
func _perceive(delta: float, dist: float, reachable: bool) -> void:
	if reachable:
		var range_m := Stealth.sight_range(_player.visibility, cfg.sight_factor)
		if dist < range_m:
			var part := Stealth.seen_part(get_world_3d(), global_position + Vector3(0, 1.5, 0), _player)
			awareness.see(delta, _player.global_position, part, dist, range_m)
		var br := Stealth.breath_radius(_player)
		if br > 0.0 and dist < br:
			awareness.hear_breath(delta, _player.global_position)
	var ch := awareness.tick(delta)
	if ch >= Awareness.Stage.SUSPECT and ch > awareness.prev_stage and state == State.STALK:
		_voice("mauler_snarl", "click", 1.5, -6.0, 0.7, 30.0)


func _on_noise(pos: Vector3, radius: float) -> void:
	if state in [State.STALK, State.PROWL, State.CIRCLE]:
		awareness.hear(pos, radius, pos.distance_to(global_position), cfg.hearing, clampf(radius / 8.0, 0.5, 1.6))


func _clear_line() -> bool:
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 1.4, 0), _player.global_position + Vector3(0, 1.4, 0))
	q.exclude = [_player.get_rid()]
	var hit := space.intersect_ray(q)
	return hit.is_empty()


## Eigene Stimme (Sound_Paket_III); fehlt die Aufnahme, klingt er wie bisher nach der Kreatur.
func _voice(id: String, fallback: String, height: float, db: float, pitch: float, max_d: float) -> void:
	var pos := global_position + Vector3(0, height, 0)
	if not SoundBank.play_rec(get_parent(), id, pos, db, max_d):
		CreatureSounds.play(self, fallback, pos, db, pitch, max_d)


## Warnzeichen beim Heranschleichen: Äste knacken, Hecheln, leises Klicken.
func _cues(delta: float, dist: float) -> void:
	_cue_t -= delta
	if _cue_t > 0.0:
		return
	_cue_t = _rng.randf_range(cfg.cue_interval.x, cfg.cue_interval.y) * (0.6 if dist < 30.0 else 1.0)
	match _rng.randi() % 3:
		0: SoundBank.play_at(get_parent(), "twig", global_position + Vector3(0, 0.3, 0), 0.0, _rng.randf_range(0.7, 0.9))
		1: _voice("mauler_snarl", "breath", 1.4, -6.0, 0.72, 40.0)
		2: _voice("mauler_snarl", "click", 1.5, -10.0, 0.75, 30.0)


# --- Bewegung -----------------------------------------------------------------

static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


func _face(p: Vector3, delta: float, rate: float = 5.0) -> void:
	var d := p - global_position
	if Vector2(d.x, d.z).length() < 0.01:
		return
	rotation.y = lerp_angle(rotation.y, atan2(d.x, d.z), clampf(delta * rate, 0.0, 1.0))


## Läuft auf ein Ziel zu, weicht Bäumen und Wänden aus und betritt nie Hütte oder Schuppen.
func _move_toward(goal: Vector3, speed: float, delta: float) -> void:
	var to := _flat(goal - global_position)
	if to.length() < 0.2:
		_speed_now = 0.0
		return
	var dir := to.normalized()
	var space := get_world_3d().direct_space_state
	var chosen := Vector3.ZERO
	for ang: float in [0.0, 0.5, -0.5, 1.0, -1.0, 1.6, -1.6]:
		var d := dir.rotated(Vector3.UP, ang)
		var from := global_position + Vector3(0, 1.0, 0)
		var q := PhysicsRayQueryParameters3D.create(from, from + d * 1.3)
		q.exclude = [_player.get_rid()]
		var next := global_position + d * maxf(speed * delta, 0.05) * 6.0
		if space.intersect_ray(q).is_empty() and not Cabin.is_inside(next) and not Shed.is_inside(next) and not Cabin.blocks_ground(next, 0.2):
			chosen = d
			break
	if chosen == Vector3.ZERO:
		_speed_now = 0.0
		return
	var p := global_position + chosen * speed * delta
	p.y = Terrain.height_at(p.x, p.z)
	global_position = p
	_speed_now = speed
	_face(global_position + chosen, delta, 8.0)


# --- Bewegung der Glieder -----------------------------------------------------------

func _animate(delta: float) -> void:
	_walk_phase += delta * (_speed_now * 2.6 + 0.4)
	var run := clampf(_speed_now / cfg.charge_speed, 0.0, 1.0)
	var s := sin(_walk_phase)
	for i in _legs.size():
		var sgn := 1.0 if i == 0 else -1.0
		_legs[i].rotation.x = s * sgn * lerpf(0.2, 0.55, run)
		(_legs[i].get_node("Knee") as Node3D).rotation.x = maxf(0.0, -s * sgn) * 0.45 * run
	_model.position.y = absf(cos(_walk_phase)) * 0.06 * run
	# Oberkörper: auf der Jagd noch tiefer, zum Kreischen aufgerichtet
	var lean := 62.0 + run * 12.0
	if state == State.WARN:
		lean = 50.0
	elif state == State.STRIKE:
		lean = 52.0
	_torso.rotation_degrees.x = lerpf(_torso.rotation_degrees.x, lean, clampf(delta * 6.0, 0.0, 1.0))
	_head.rotation_degrees.x = -lean + (-12.0 if state == State.WARN else 4.0)
	# Kiefer: beim Kreischen, Zuschlagen und Hecheln offen
	var jaw := 0.0
	if state in [State.WARN, State.STRIKE]:
		jaw = 38.0
	elif state == State.CHARGE:
		jaw = 12.0 + sin(_life * 9.0) * 6.0
	_jaw.rotation_degrees.x = lerpf(_jaw.rotation_degrees.x, jaw, clampf(delta * 10.0, 0.0, 1.0))
	# Arme (im geneigten Rumpf): hängen nach unten-vorn, beim Rennen pendelnd, beim Kreischen weit gespreizt,
	# beim Hieb von oben nach vorn
	var down := -deg_to_rad(_torso.rotation_degrees.x)
	for i in _arms.size():
		var sgn := 1.0 if i == 0 else -1.0
		var a := _arms[i]
		if state == State.STRIKE and i == 1:
			a.rotation.x = down + lerpf(-2.2, 0.6, _swing)
			a.rotation.z = 0.0
		elif state == State.WARN:
			a.rotation.x = down - 1.0
			a.rotation.z = -sgn * 0.95
		else:
			a.rotation.x = down - 0.35 + s * sgn * lerpf(0.15, 0.5, run)
			a.rotation.z = -sgn * 0.12
