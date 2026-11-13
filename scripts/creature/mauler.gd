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
var _walk_phase: float = 0.0
var _swing: float = 0.0
var _model: Node3D
var _torso: Node3D
var _head: Node3D
var _jaw: Node3D
var _arms: Array[Node3D] = []
var _legs: Array[Node3D] = []


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
	cfg = MaulerConfig.get_default()
	_rng.randomize()
	_player = get_tree().get_first_node_in_group("player") as Player
	_build_model()
	Tasks.flag("mauler_seen")


func place_near(p: Vector3) -> void:
	var best := Vector3.ZERO
	for attempt in 10:
		var a := _rng.randf() * TAU
		var d := _rng.randf_range(cfg.spawn_distance.x, cfg.spawn_distance.y)
		var q := _ground(p + Vector3(cos(a), 0, sin(a)) * d)
		best = q
		if not Cabin.is_inside(q) and not Shed.is_inside(q) and _bright_at(q) == Vector3.INF and not _player_sees(q):
			break
	global_position = best
	print("[Mauler] erscheint bei ", global_position)


static func _ground(p: Vector3) -> Vector3:
	return Vector3(p.x, Terrain.height_at(p.x, p.z), p.z)


# --- Aussehen -----------------------------------------------------------------

func _build_model() -> void:
	var skin := BuildKit.tex_mat("alien_skin", 0.5, Color(0.62, 0.6, 0.64), 0.6)
	var dark := BuildKit.color_mat(Color(0.16, 0.15, 0.17), 0.45)
	var claw_mat := BuildKit.color_mat(Color(0.07, 0.065, 0.06), 0.2, 0.35)
	var eye := StandardMaterial3D.new()
	eye.albedo_color = Color(0.005, 0.005, 0.008)
	eye.metallic = 0.3
	eye.roughness = 0.04
	eye.metallic_specular = 1.0
	var tooth := BuildKit.color_mat(Color(0.88, 0.85, 0.76), 0.3)
	var gum := BuildKit.color_mat(Color(0.35, 0.1, 0.12), 0.55)
	_model = Node3D.new()
	_model.name = "Body"
	add_child(_model)
	# Becken
	BuildKit.sphere(_model, 0.21, Vector3(0, 1.05, -0.05), skin, Vector3(1.25, 0.85, 1.0), 9)
	# Beine (Zehengänger): Oberschenkel schräg nach vorn, Unterschenkel nach hinten, langer Mittelfuß nach vorn.
	# Ein Glied, das nach unten-vorn zeigt, ist um -Winkel um X gedreht, eins nach unten-hinten um +Winkel.
	for sx: float in [-1.0, 1.0]:
		var hip := Node3D.new()
		hip.position = Vector3(sx * 0.19, 1.05, -0.05)
		_model.add_child(hip)
		_limb(hip, Vector3.ZERO, Vector3(0, -0.4, 0.23), 0.14, 0.095, skin)
		BuildKit.sphere(hip, 0.15, Vector3(0, -0.05, 0.03), skin, Vector3(1.0, 1.2, 1.1), 8)
		var knee := Node3D.new()
		knee.name = "Knee"
		knee.position = Vector3(0, -0.4, 0.23)
		hip.add_child(knee)
		BuildKit.sphere(knee, 0.09, Vector3.ZERO, skin, Vector3.ONE, 7)
		_limb(knee, Vector3.ZERO, Vector3(0, -0.37, -0.31), 0.085, 0.06, skin)
		var ankle := Node3D.new()
		ankle.position = Vector3(0, -0.37, -0.31)
		knee.add_child(ankle)
		BuildKit.sphere(ankle, 0.06, Vector3.ZERO, skin, Vector3.ONE, 6)
		_limb(ankle, Vector3.ZERO, Vector3(0, -0.27, 0.1), 0.055, 0.045, skin)
		for t in 3:
			BuildKit.box(ankle, Vector3(0.035, 0.03, 0.17), Vector3((t - 1) * 0.05, -0.27, 0.19), claw_mat, false, Vector3(8, (t - 1) * 16.0, 0))
		_legs.append(hip)
	# Rumpf: weit nach vorn geneigt, kräftiger Brustkorb, Rippen und Wirbel
	_torso = Node3D.new()
	_torso.position = Vector3(0, 1.05, -0.05)
	_torso.rotation_degrees.x = 62.0
	_model.add_child(_torso)
	BuildKit.cylinder(_torso, 0.31, 0.82, Vector3(0, 0.42, 0), skin, false, Vector3.ZERO, 0.19, 10)
	BuildKit.sphere(_torso, 0.33, Vector3(0, 0.8, 0.03), skin, Vector3(1.2, 0.8, 1.0), 10)
	for k in 5:
		BuildKit.box(_torso, Vector3(0.44 - k * 0.04, 0.03, 0.06), Vector3(0, 0.36 + k * 0.1, 0.2 + k * 0.012), skin, false, Vector3(-8, 0, 0))
	for k in 8:
		BuildKit.sphere(_torso, 0.045, Vector3(0, 0.12 + k * 0.11, -0.2 - sin(k * 0.4) * 0.03), dark, Vector3(1.0, 0.7, 1.4), 5)
	# Hals und Kopf: großer Grey-Schädel, schräge schwarze Mandelaugen, darunter ein Maul voller Reißzähne
	var neck := Node3D.new()
	neck.position = Vector3(0, 1.02, 0.12)
	_torso.add_child(neck)
	BuildKit.cylinder(neck, 0.1, 0.22, Vector3(0, 0.06, 0.0), skin, false, Vector3.ZERO, 0.13, 7)
	_head = Node3D.new()
	_head.position = Vector3(0, 0.16, 0.02)
	_head.rotation_degrees.x = -60.0
	neck.add_child(_head)
	BuildKit.sphere(_head, 0.22, Vector3(0, 0.17, -0.03), skin, Vector3(1.0, 1.12, 1.1), 12)
	BuildKit.sphere(_head, 0.12, Vector3(0, 0.0, 0.08), skin, Vector3(0.95, 0.85, 1.15), 10)
	for sx: float in [-1.0, 1.0]:
		var sock := BuildKit.sphere(_head, 0.1, Vector3(sx * 0.09, 0.14, 0.13), dark, Vector3(1.0, 0.62, 0.45), 9)
		sock.rotation_degrees.z = sx * -28.0
		var e := BuildKit.sphere(_head, 0.095, Vector3(sx * 0.092, 0.14, 0.145), eye, Vector3(1.0, 0.55, 0.42), 10)
		e.rotation_degrees.z = sx * -28.0
	_jaw = Node3D.new()
	_jaw.position = Vector3(0, -0.03, 0.1)
	_head.add_child(_jaw)
	BuildKit.box(_jaw, Vector3(0.17, 0.04, 0.15), Vector3(0, -0.055, 0.05), skin, false)
	BuildKit.box(_jaw, Vector3(0.15, 0.02, 0.13), Vector3(0, -0.032, 0.05), gum, false)
	BuildKit.box(_head, Vector3(0.15, 0.02, 0.06), Vector3(0, -0.035, 0.17), gum, false)
	for i in 9:
		var x := (i - 4) * 0.017
		var long := i % 4 == 0
		BuildKit.cylinder(_jaw, 0.007, 0.055 if long else 0.032, Vector3(x, -0.01, 0.115 - absf(x) * 0.7), tooth, false, Vector3(180, 0, 0), 0.0, 4)
		BuildKit.cylinder(_head, 0.007, 0.06 if long else 0.035, Vector3(x, -0.06, 0.19 - absf(x) * 0.7), tooth, false, Vector3.ZERO, 0.0, 4)
	# Arme: lang, mit drei sichelförmigen Klauen je Hand
	for sx: float in [-1.0, 1.0]:
		var sh := Node3D.new()
		sh.position = Vector3(sx * 0.33, 0.82, 0.05)
		_torso.add_child(sh)
		BuildKit.sphere(sh, 0.1, Vector3.ZERO, skin, Vector3.ONE, 7)
		_limb(sh, Vector3.ZERO, Vector3(0, -0.5, 0), 0.08, 0.06, skin)
		var elbow := Node3D.new()
		elbow.name = "Elbow"
		elbow.position = Vector3(0, -0.5, 0)
		elbow.rotation.x = -0.5
		sh.add_child(elbow)
		BuildKit.sphere(elbow, 0.062, Vector3.ZERO, skin, Vector3.ONE, 6)
		_limb(elbow, Vector3.ZERO, Vector3(0, -0.46, 0), 0.06, 0.045, skin)
		BuildKit.sphere(elbow, 0.06, Vector3(0, -0.48, 0.01), skin, Vector3(1.1, 0.8, 0.9), 6)
		for f in 3:
			var c := BuildKit.cylinder(elbow, 0.016, 0.38, Vector3((f - 1) * 0.04, -0.66, 0.08), claw_mat, false, Vector3(-28 + absf(f - 1) * 6.0, 0, (f - 1) * 10.0), 0.002, 5)
			c.name = "Claw%d" % f
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
	match state:
		State.STALK:
			if not reachable:
				_enter(State.PROWL)
			else:
				_cues(delta, dist)
				_move_toward(_player.global_position, cfg.stalk_speed, delta)
				if dist < cfg.charge_distance and _clear_line():
					_enter(State.WARN)
		State.WARN:
			# sich aufrichten, Maul auf, kreischen – dann losrennen
			_face(_player.global_position, delta, 6.0)
			_speed_now = 0.0
			if _t < delta * 1.5:
				CreatureSounds.play(self, "shriek", global_position + Vector3(0, 1.6, 0), 2.0, 0.78, 70.0)
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
					CreatureSounds.play(self, "breath", global_position + Vector3(0, 1.4, 0), -2.0, 0.7, 30.0)
		State.STRIKE:
			_face(_player.global_position, delta, 10.0)
			_speed_now = 0.0
			_swing = clampf(_t / 0.35, 0.0, 1.0)
			if _t >= 0.28 and _t - delta < 0.28:
				if dist <= cfg.strike_range + 0.5 and reachable:
					hits += 1
					_player.take_damage(cfg.hit_damage, global_position)
					EventBus.screen_shake.emit(0.35)
					CreatureSounds.play(self, "shriek", global_position + Vector3(0, 1.5, 0), -2.0, 1.15, 40.0)
				else:
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
				CreatureSounds.play(self, "click", global_position + Vector3(0, 1.5, 0), -6.0, 0.8, 25.0)
			if _circle_left <= 0.0 or _t > 12.0:
				_enter(State.CHARGE if reachable else State.PROWL)
		State.PROWL:
			# um das Versteck / die Hütte herumschleichen, nicht hinein
			_lost += delta
			var a := _life * 0.25
			var c := _player.global_position + Vector3(cos(a), 0, sin(a)) * 10.0
			_move_toward(c, cfg.stalk_speed, delta)
			if _rng.randf() < delta * 0.3:
				CreatureSounds.play(self, "breath", global_position + Vector3(0, 1.4, 0), -6.0, 0.7, 30.0)
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
	CreatureSounds.play(self, "recoil", global_position + Vector3(0, 1.5, 0), 0.0, 0.85, 50.0)
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
	return _bright_at(pp) == Vector3.INF


func _player_sees(p: Vector3) -> bool:
	if _player == null:
		return false
	var cam := _player.camera.global_transform
	var to := (p + Vector3(0, 1.3, 0)) - cam.origin
	return rad_to_deg((-cam.basis.z).angle_to(to.normalized())) < 50.0 and to.length() < 40.0


func _clear_line() -> bool:
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 1.4, 0), _player.global_position + Vector3(0, 1.4, 0))
	q.exclude = [_player.get_rid()]
	var hit := space.intersect_ray(q)
	return hit.is_empty()


## Warnzeichen beim Heranschleichen: Äste knacken, Hecheln, leises Klicken.
func _cues(delta: float, dist: float) -> void:
	_cue_t -= delta
	if _cue_t > 0.0:
		return
	_cue_t = _rng.randf_range(cfg.cue_interval.x, cfg.cue_interval.y) * (0.6 if dist < 30.0 else 1.0)
	match _rng.randi() % 3:
		0: SoundBank.play_at(get_parent(), "twig", global_position + Vector3(0, 0.3, 0), 0.0, _rng.randf_range(0.7, 0.9))
		1: CreatureSounds.play(self, "breath", global_position + Vector3(0, 1.4, 0), -4.0, 0.72, 40.0)
		2: CreatureSounds.play(self, "click", global_position + Vector3(0, 1.5, 0), -6.0, 0.75, 30.0)


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
		if space.intersect_ray(q).is_empty() and not Cabin.is_inside(next) and not Shed.is_inside(next):
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
