class_name Animal
extends Node3D
## Ein einzelnes Tier (oder ein kleiner Schwarm). Wird vom Wildlife-Manager erzeugt und wieder entfernt.
## Arten:
##  Tag:   hare (Hase), snake (Ringelnatter), squirrel (Eichhörnchen am Baum), birds (Vögel am Boden),
##         butterfly (Schmetterling), insects (Mückenschwarm), flyover (Krähe/Bussard über dem Tal),
##         flock (Zugvögel in Keilformation)
##  Nacht: deer (Reh – im Dunkeln nur Umriss und leuchtende Augen), fox (Fuchs), hedgehog (Igel)
## Modelle schauen nach -z.

var kind: String = "hare"
var lifetime: float = 90.0
var cfg: WildlifeConfig
var tree: Vector4 = Vector4.ZERO      ## Eichhörnchen: Baum (x, Boden, z, Radius)
var flock_size: int = 24
var fly_dir: Vector3 = Vector3(0.7, 0, 0.7)

var _t: float = 0.0
var _player: Player
var _rng := RandomNumberGenerator.new()
var _state: String = "idle"           ## idle | move | flee | fly | curl
var _target: Vector3
var _wait: float = 0.0
var _speed: float = 1.0
var _model: Node3D
var _eye_mat: StandardMaterial3D
var _lit: float = 0.0
var _parts: Array[Node3D] = []        ## bewegliche Teile (Beine, Flügel, Schwanz, Schwarm)
var _trail: Array[Vector3] = []       ## Natter: Weg des Kopfes
var _climb: float = 1.5               ## Eichhörnchen: Höhe am Stamm
var _climb_ang: float = 0.0
var _climb_goal: float = 3.0
var _base: Vector3                    ## Schmetterling/Insekten: Mittelpunkt
var _phase: float = 0.0


func _ready() -> void:
	add_to_group("animal")
	_rng.randomize()
	_phase = _rng.randf() * TAU
	_player = get_tree().get_first_node_in_group("player") as Player
	_model = Node3D.new()
	add_child(_model)
	_base = global_position
	_target = global_position
	match kind:
		"hare": _build_hare()
		"snake": _build_snake()
		"squirrel": _build_squirrel()
		"birds": _build_ground_birds()
		"butterfly": _build_butterfly()
		"insects": _build_insects()
		"flyover": _build_flyover()
		"flock": _build_flock()
		"deer": _build_deer()
		"fox": _build_fox()
		"hedgehog": _build_hedgehog()
	_wait = _rng.randf_range(0.5, 3.0)


## Tag-/Nachtgruppe für den Manager
func is_night_kind() -> bool:
	return kind in ["deer", "fox", "hedgehog"]


func is_ground_kind() -> bool:
	return kind in ["hare", "snake", "squirrel", "birds"]


# --- Verhalten ----------------------------------------------------------

func _process(delta: float) -> void:
	_t += delta
	if _player == null:
		return
	var to_player := _player.global_position - global_position
	var pd := Vector2(to_player.x, to_player.z).length()
	# Weit weg oder Zeit um: verschwinden, sobald niemand hinsieht
	if (_t > lifetime or pd > cfg.despawn_distance) and not _in_view():
		queue_free()
		return
	match kind:
		"hare", "fox", "deer", "hedgehog":
			_walker(delta, pd)
		"snake":
			_snake(delta, pd)
		"squirrel":
			_squirrel(delta, pd)
		"birds":
			_ground_birds(delta, pd)
		"butterfly":
			_butterfly(delta)
		"insects":
			_insects(delta)
		"flyover", "flock":
			_flyer(delta)
	if _eye_mat:
		_update_eyes(delta)


## Bodentiere, die laufen: Hase hoppelt, Fuchs trabt, Reh äst und flieht in Sprüngen, Igel trippelt.
func _walker(delta: float, pd: float) -> void:
	var sneaking := Input.is_action_pressed("crouch") or Input.is_action_pressed("walk_slow")
	var shy := cfg.shy_distance * (0.5 if sneaking else 1.0)
	var c: Node3D = ThreatDirector.creature if is_instance_valid(ThreatDirector.creature) else null
	match kind:
		"deer":
			shy = cfg.deer_flee_player * (0.6 if sneaking else 1.0)
			if c and c.global_position.distance_to(global_position) < cfg.deer_flee_creature:
				_flee_from(c.global_position, 9.0)
			if _lit > cfg.deer_light_tolerance:
				_flee_from(_player.global_position, 9.0)
		"fox":
			shy = 10.0
		"hedgehog":
			shy = 2.5
	if _state != "flee" and pd < shy:
		if kind == "hedgehog":
			_state = "curl"
			_wait = 6.0
		else:
			_flee_from(_player.global_position, {"hare": 7.5, "fox": 6.0, "deer": 9.0}.get(kind, 5.0))
	match _state:
		"curl":
			_model.scale = _model.scale.lerp(Vector3(1.0, 0.75, 0.8), clampf(delta * 6.0, 0.0, 1.0))
			_wait -= delta
			if _wait <= 0.0 and pd > 3.5:
				_state = "idle"
				_model.scale = Vector3.ONE
			return
		"idle":
			_wait -= delta
			_idle_pose(delta)
			if _wait <= 0.0:
				_pick_target()
		"move", "flee":
			var to := _target - global_position
			to.y = 0.0
			if to.length() < 0.4:
				if _state == "flee":
					lifetime = minf(lifetime, _t + 2.0)
				_state = "idle"
				_wait = _rng.randf_range(2.0, 7.0) if kind != "fox" else _rng.randf_range(1.0, 3.0)
				return
			var step := to.normalized() * _speed * delta
			var next := global_position + step
			if _blocked(next):
				_pick_target()
				return
			global_position = Vector3(next.x, Terrain.height_at(next.x, next.z), next.z)
			_face(_target)
			_gait(delta)


func _idle_pose(delta: float) -> void:
	# Kopf senken (äsen, schnuppern), Ohren zucken
	var head := _part("head")
	if head:
		head.rotation.x = lerpf(head.rotation.x, 0.5 if fmod(_t + _phase, 6.0) < 3.5 else -0.1, clampf(delta * 2.0, 0.0, 1.0))
	_model.position.y = lerpf(_model.position.y, 0.0, clampf(delta * 8.0, 0.0, 1.0))
	for k in 4:
		var leg := _part("leg%d" % k)
		if leg:
			leg.rotation.x = lerpf(leg.rotation.x, 0.0, clampf(delta * 8.0, 0.0, 1.0))


func _gait(delta: float) -> void:
	var f := _t * _speed * (2.2 if kind == "hare" else 3.0)
	var head := _part("head")
	if head:
		head.rotation.x = lerpf(head.rotation.x, -0.15, clampf(delta * 4.0, 0.0, 1.0))
	match kind:
		"hare":
			_model.position.y = absf(sin(f)) * (0.12 if _state == "flee" else 0.05)
			_model.rotation.x = cos(f) * 0.15
		"deer":
			if _state == "flee":
				_model.position.y = absf(sin(f * 0.6)) * 0.35
				_model.rotation.x = cos(f * 0.6) * 0.18
			for k in 4:
				var leg := _part("leg%d" % k)
				if leg:
					leg.rotation.x = sin(f + (PI if k % 2 == 0 else 0.0) + (0.5 if k >= 2 else 0.0)) * 0.5
		_:
			_model.position.y = absf(sin(f * 1.5)) * 0.01
			for k in 4:
				var leg := _part("leg%d" % k)
				if leg:
					leg.rotation.x = sin(f * 1.5 + (PI if (k == 0 or k == 3) else 0.0)) * 0.6
	var tail := _part("tail")
	if tail and kind == "fox":
		tail.rotation.y = sin(f * 0.8) * 0.2


func _pick_target() -> void:
	var r := {"hare": 8.0, "fox": 18.0, "deer": 6.0, "hedgehog": 3.0}.get(kind, 5.0) as float
	for i in 8:
		var a := _rng.randf() * TAU
		var p := global_position + Vector3(cos(a), 0, sin(a)) * _rng.randf_range(r * 0.4, r)
		if not _blocked(p) and (kind in ["hare", "hedgehog"] or Terrain.yard_distance(p.x, p.z) > 4.0):
			_target = p
			_state = "move"
			_speed = {"hare": 2.2, "fox": 1.6, "deer": 0.7, "hedgehog": 0.35}.get(kind, 1.0) as float
			return
	_wait = 2.0


func _flee_from(src: Vector3, speed: float) -> void:
	if _state == "flee":
		return
	var away := global_position - src
	away.y = 0.0
	if away.length() < 0.1:
		away = Vector3(1, 0, 0)
	away = away.normalized()
	# leicht zur Seite, damit nicht alle gleich laufen; um Gebäude herum
	for i in 6:
		var dir := away.rotated(Vector3.UP, _rng.randf_range(-0.5, 0.5) + (i * 0.6 if i > 0 else 0.0))
		var p := global_position + dir * 30.0
		if not _blocked(global_position + dir * 3.0):
			_target = p
			break
	_state = "flee"
	_speed = speed
	if kind == "deer":
		SoundBank.play_at(get_parent(), "twig", global_position + Vector3(0, 0.3, 0), -2.0, _rng.randf_range(0.8, 1.1))


## Natter: schlängelt sich, der Körper folgt dem Kopf. Bei Annäherung flieht sie schneller.
func _snake(delta: float, pd: float) -> void:
	if _state != "flee" and pd < cfg.shy_distance * 0.6:
		_flee_from(_player.global_position, 1.1)
	if _state == "idle":
		_wait -= delta
		if _wait <= 0.0:
			_pick_target()
			_speed = 0.35
	if _state in ["move", "flee"]:
		var to := _target - global_position
		to.y = 0.0
		if to.length() < 0.3:
			if _state == "flee":
				lifetime = minf(lifetime, _t + 2.0)
			_state = "idle"
			_wait = _rng.randf_range(3.0, 9.0)
		else:
			var fwd := to.normalized()
			var side := Vector3(-fwd.z, 0, fwd.x)
			var p := global_position + fwd * _speed * delta + side * cos(_t * 6.0) * 0.2 * _speed * delta
			if not _blocked(p):
				global_position = Vector3(p.x, Terrain.height_at(p.x, p.z), p.z)
	# Weg aufzeichnen, Glieder entlang des Weges aufreihen
	if _trail.is_empty() or _trail[0].distance_to(global_position) > 0.03:
		_trail.push_front(global_position)
		if _trail.size() > 60:
			_trail.pop_back()
	var dist := 0.0
	var idx := 0
	for k in _parts.size():
		var want := k * 0.06
		while idx < _trail.size() - 1 and dist + _trail[idx].distance_to(_trail[idx + 1]) < want:
			dist += _trail[idx].distance_to(_trail[idx + 1])
			idx += 1
		var p: Vector3 = _trail[mini(idx, _trail.size() - 1)]
		_parts[k].global_position = p + Vector3(0, 0.025, 0)
	if _parts.size() > 1:
		var head := _parts[0]
		var look := head.global_position + (head.global_position - _parts[1].global_position)
		if look.distance_to(head.global_position) > 0.001:
			head.look_at(look, Vector3.UP)


## Eichhörnchen: klettert in Spiralen den Stamm hoch und runter, hält inne, flitzt bei Annäherung nach oben.
func _squirrel(delta: float, pd: float) -> void:
	if pd < cfg.shy_distance and _state != "flee":
		_state = "flee"
		_climb_goal = _rng.randf_range(6.0, 9.0)
	if _state == "idle":
		_wait -= delta
		if _wait <= 0.0:
			_state = "move"
			_climb_goal = _rng.randf_range(0.3, 6.0)
	if _state in ["move", "flee"]:
		var sp := 2.5 if _state == "flee" else 1.2
		var dh := _climb_goal - _climb
		if absf(dh) < 0.05:
			_state = "idle" if _state == "move" else "hidden"
			_wait = _rng.randf_range(1.0, 5.0)
			if _state == "hidden":
				lifetime = minf(lifetime, _t + 1.0)
		else:
			_climb += signf(dh) * minf(absf(dh), sp * delta)
			_climb_ang += signf(dh) * sp * delta * 1.2
	var r := tree.w + 0.06
	var g := tree.y
	var center := Vector3(tree.x, g + _climb, tree.z)
	var out := Vector3(cos(_climb_ang), 0, sin(_climb_ang))
	global_position = center + out * r
	# Kopf nach oben oder unten, Bauch zum Stamm
	var up_down := 1.0 if _climb_goal >= _climb else -1.0
	var b := Basis()
	var fwd := Vector3(0, up_down, 0)
	b.z = -fwd
	b.y = out
	b.x = b.y.cross(b.z).normalized()
	_model.global_transform.basis = b
	_model.global_position = global_position
	var tail := _part("tail")
	if tail:
		tail.rotation.x = sin(_t * 9.0) * 0.15


## Kleine Vögel am Boden: hüpfen, picken. Kommt man nahe, fliegen alle auf.
func _ground_birds(delta: float, pd: float) -> void:
	if _state != "fly" and pd < cfg.shy_distance:
		_state = "fly"
		_target = global_position + Vector3(_rng.randf_range(-1, 1), 0, _rng.randf_range(-1, 1)).normalized() * 40.0 + Vector3(0, 14, 0)
		SoundBank.play_at(get_parent(), "twig", global_position, -14.0, 2.4)
	for i in _parts.size():
		var b := _parts[i]
		if _state == "fly":
			var to := (_target - b.global_position)
			b.global_position += (to.normalized() + Vector3(sin(_t * 3.0 + i), 0.3, cos(_t * 2.0 + i)) * 0.3) * 8.0 * delta
			_face_node(b, b.global_position + to)
			var fl := sin(_t * 30.0 + i) * 1.0
			(b.get_meta("wl") as Node3D).rotation.z = fl
			(b.get_meta("wr") as Node3D).rotation.z = -fl
			lifetime = minf(lifetime, _t + 6.0)
		else:
			# hüpfen und picken
			var ph := fmod(_t * 1.3 + i * 0.7, 3.0)
			var base: Vector3 = b.get_meta("home")
			if ph < 0.25:
				var hop: Vector3 = b.get_meta("hop")
				base += hop * delta * 2.0
				b.set_meta("home", base)
				b.global_position = Vector3(base.x, Terrain.height_at(base.x, base.z) + sin(ph / 0.25 * PI) * 0.06, base.z)
			elif ph > 2.0:
				b.set_meta("hop", Vector3(_rng.randf_range(-0.3, 0.3), 0, _rng.randf_range(-0.3, 0.3)))
				b.rotation.x = 0.6 if fmod(_t * 6.0 + i, 2.0) < 1.0 else 0.0
			else:
				b.rotation.x = 0.0


func _butterfly(delta: float) -> void:
	# taumelnder Flug um einen Mittelpunkt, der langsam wandert
	if _t > _wait:
		_wait = _t + _rng.randf_range(3.0, 7.0)
		_target = _base + Vector3(_rng.randf_range(-6, 6), 0, _rng.randf_range(-6, 6))
	var p := global_position
	var to := _target - p
	to.y = 0.0
	var ground := Terrain.height_at(p.x, p.z)
	var h := 0.6 + sin(_t * 1.7 + _phase) * 0.35 + sin(_t * 4.1) * 0.15
	var dir := to.normalized() * 0.8 + Vector3(sin(_t * 2.3 + _phase), 0, cos(_t * 1.9 + _phase)) * 0.9
	p += dir * delta * 1.1
	global_position = Vector3(p.x, ground + h, p.z)
	_face(global_position + dir)
	var fl := (sin(_t * 22.0) * 0.5 + 0.5) * 1.3
	_parts[0].rotation.z = fl
	_parts[1].rotation.z = -fl


func _insects(_delta: float) -> void:
	for i in _parts.size():
		var b := _parts[i]
		var s := float(i) * 1.7
		b.position = Vector3(sin(_t * 3.1 + s) * 0.5 + sin(_t * 7.3 + s * 2.0) * 0.15,
				sin(_t * 2.3 + s * 1.3) * 0.3 + 1.3, cos(_t * 2.7 + s) * 0.5 + cos(_t * 6.1 + s) * 0.15)


## Krähe, Bussard oder Zugvögel ziehen über das Tal.
func _flyer(delta: float) -> void:
	var sp := 9.0 if kind == "flyover" else 7.0
	if kind == "flyover" and bool(get_meta("circle", false)):
		# Bussard kreist mit gespreizten Flügeln
		_phase += delta * 0.25
		var c: Vector3 = get_meta("center")
		global_position = c + Vector3(cos(_phase) * 20.0, sin(_t * 0.3) * 1.5, sin(_phase) * 20.0)
		_face(global_position + Vector3(-sin(_phase), 0, cos(_phase)))
		_model.rotation.z = 0.25
		return
	global_position += fly_dir * sp * delta
	_face(global_position + fly_dir)
	for i in _parts.size():
		var b := _parts[i]
		var fl := sin(_t * (9.0 if kind == "flock" else 5.0) + i * 0.9) * 0.7
		(b.get_meta("wl") as Node3D).rotation.z = fl
		(b.get_meta("wr") as Node3D).rotation.z = -fl
		if kind == "flock":
			var home: Vector3 = b.get_meta("home")
			b.position = home + Vector3(sin(_t * 0.7 + i) * 0.4, sin(_t * 1.1 + i * 1.3) * 0.3, cos(_t * 0.5 + i) * 0.4)


## Augen leuchten nur, wenn das Uhrlicht sie trifft (Augenreflex) – nachts erkennt man so oft nur zwei Punkte.
func _update_eyes(delta: float) -> void:
	var cam := _player.camera.global_transform
	var eye_pos := global_position + Vector3(0, 1.3 if kind == "deer" else 0.3, 0)
	var to := eye_pos - cam.origin
	var in_beam := _player.light_shining() and to.length() < 50.0 and (-cam.basis.z).dot(to.normalized()) > 0.93
	_lit = _lit + delta if in_beam else maxf(_lit - delta * 0.5, 0.0)
	_eye_mat.emission_energy_multiplier = lerpf(_eye_mat.emission_energy_multiplier, 6.0 if in_beam else 0.0, clampf(delta * 10.0, 0.0, 1.0))


# --- Hilfen -------------------------------------------------------------

func _part(n: String) -> Node3D:
	return _model.find_child(n, true, false) as Node3D


func _face(p: Vector3) -> void:
	var look := Vector3(p.x, global_position.y if kind not in ["flyover", "flock", "butterfly"] else p.y, p.z)
	if look.distance_to(global_position) > 0.01:
		look_at(look, Vector3.UP)


func _face_node(n: Node3D, p: Vector3) -> void:
	if p.distance_to(n.global_position) > 0.01:
		n.look_at(p, Vector3.UP)


## Im Haus, im Schuppen, im Maisfeld oder außerhalb des Spielfelds läuft kein Tier.
static func _blocked(p: Vector3) -> bool:
	if absf(p.x) < 6.8 and absf(p.z) < 5.4:
		return true
	if absf(p.x - 14.0) < 2.5 and absf(p.z - 6.5) < 2.0:
		return true
	if absf(p.x) > WorldMap.limit() - 5.0 or absf(p.z) > WorldMap.limit() - 5.0:
		return true
	if Terrain.water_level_at(p.x, p.z) > Terrain.height_at(p.x, p.z) - 0.1:
		return true
	return Terrain.stream_distance(p.x, p.z) < 1.6


func _in_view() -> bool:
	if _player == null:
		return false
	var cam := _player.camera.global_transform
	var to := global_position - cam.origin
	if to.length() > 90.0 and kind not in ["flock", "flyover"]:
		return false
	return (-cam.basis.z).dot(to.normalized()) > 0.5


# --- Modelle ------------------------------------------------------------

func _pivot(parent: Node3D, n: String, pos: Vector3) -> Node3D:
	var p := Node3D.new()
	p.name = n
	p.position = pos
	parent.add_child(p)
	return p


func _eyes(parent: Node3D, pos: Vector3, spread: float, r: float) -> void:
	_eye_mat = BuildKit.emissive_mat(Color(0.85, 1.0, 0.75), 0.0)
	_eye_mat.albedo_color = Color(0.05, 0.05, 0.04)
	for sx: float in [-1.0, 1.0]:
		BuildKit.sphere(parent, r, pos + Vector3(sx * spread, 0, 0), _eye_mat, Vector3.ONE, 6)


func _build_hare() -> void:
	var fur := BuildKit.color_mat(Color(0.42, 0.33, 0.24), 1.0)
	var light := BuildKit.color_mat(Color(0.75, 0.7, 0.62), 1.0)
	var dark := BuildKit.color_mat(Color(0.08, 0.07, 0.06), 0.6)
	BuildKit.sphere(_model, 0.16, Vector3(0, 0.17, 0.04), fur, Vector3(0.9, 0.85, 1.35), 10)
	BuildKit.sphere(_model, 0.05, Vector3(0, 0.2, 0.25), light, Vector3.ONE, 6)
	for sx: float in [-1.0, 1.0]:
		BuildKit.sphere(_model, 0.06, Vector3(sx * 0.08, 0.08, 0.12), fur, Vector3(0.7, 0.8, 1.6), 6)
		BuildKit.box(_model, Vector3(0.025, 0.1, 0.025), Vector3(sx * 0.05, 0.05, -0.12), fur, false)
	var head := _pivot(_model, "head", Vector3(0, 0.27, -0.16))
	BuildKit.sphere(head, 0.075, Vector3(0, 0, -0.04), fur, Vector3(0.85, 0.9, 1.25), 8)
	for sx: float in [-1.0, 1.0]:
		BuildKit.box(head, Vector3(0.035, 0.17, 0.015), Vector3(sx * 0.03, 0.12, 0.02), fur, false, Vector3(-15, 0, sx * 12))
		BuildKit.box(head, Vector3(0.036, 0.03, 0.016), Vector3(sx * 0.044, 0.2, 0.0), dark, false, Vector3(-15, 0, sx * 12))
		BuildKit.sphere(head, 0.012, Vector3(sx * 0.05, 0.015, -0.06), dark, Vector3.ONE, 5)


func _build_snake() -> void:
	var skin := BuildKit.color_mat(Color(0.2, 0.22, 0.18), 0.5)
	var belly := BuildKit.color_mat(Color(0.85, 0.75, 0.2), 0.6)
	var n := 14
	for k in n:
		var seg := Node3D.new()
		add_child(seg)
		var r := 0.022 if k < n - 4 else 0.022 * (1.0 - (k - n + 4) * 0.2)
		BuildKit.sphere(seg, r, Vector3.ZERO, skin, Vector3(1.0, 0.75, 1.6), 6)
		if k == 1:
			# gelbe Halbmonde hinter dem Kopf: eine Ringelnatter
			for sx: float in [-1.0, 1.0]:
				BuildKit.sphere(seg, 0.012, Vector3(sx * 0.016, 0.006, 0), belly, Vector3.ONE, 5)
		_parts.append(seg)
		seg.top_level = true
	BuildKit.sphere(_parts[0], 0.02, Vector3(0, 0.002, -0.025), skin, Vector3(0.9, 0.6, 1.3), 6)
	# Weg nach hinten vorbelegen, damit der Körper gestreckt liegt
	var back := Vector3(_rng.randf_range(-1, 1), 0, _rng.randf_range(-1, 1)).normalized()
	for k in 30:
		var p := global_position + back * k * 0.03
		_trail.append(Vector3(p.x, Terrain.height_at(p.x, p.z), p.z))


func _build_squirrel() -> void:
	var fur := BuildKit.color_mat(Color(0.55, 0.22, 0.08), 1.0)
	var light := BuildKit.color_mat(Color(0.85, 0.75, 0.6), 1.0)
	_model.top_level = true
	BuildKit.sphere(_model, 0.06, Vector3(0, 0.05, 0), fur, Vector3(0.9, 0.8, 1.6), 8)
	BuildKit.sphere(_model, 0.035, Vector3(0, 0.03, -0.01), light, Vector3(0.8, 0.5, 1.2), 6)
	var head := _pivot(_model, "head", Vector3(0, 0.07, -0.1))
	BuildKit.sphere(head, 0.04, Vector3.ZERO, fur, Vector3(0.9, 0.9, 1.1), 8)
	for sx: float in [-1.0, 1.0]:
		BuildKit.box(head, Vector3(0.012, 0.035, 0.008), Vector3(sx * 0.02, 0.04, 0.01), fur, false)
		BuildKit.sphere(head, 0.007, Vector3(sx * 0.025, 0.01, -0.03), BuildKit.color_mat(Color(0.03, 0.03, 0.03), 0.3), Vector3.ONE, 4)
	var tail := _pivot(_model, "tail", Vector3(0, 0.08, 0.1))
	BuildKit.sphere(tail, 0.055, Vector3(0, 0.07, 0.05), fur, Vector3(0.8, 1.6, 0.8), 8)


func _bird(parent: Node3D, body_col: Color, belly_col: Color, size: float) -> Node3D:
	var b := Node3D.new()
	parent.add_child(b)
	var body := BuildKit.color_mat(body_col, 0.8)
	var belly := BuildKit.color_mat(belly_col, 0.8)
	BuildKit.sphere(b, 0.05 * size, Vector3(0, 0.05 * size, 0), body, Vector3(0.9, 0.9, 1.5), 6)
	BuildKit.sphere(b, 0.035 * size, Vector3(0, 0.04 * size, -0.02 * size), belly, Vector3(0.8, 0.8, 1.0), 6)
	BuildKit.sphere(b, 0.032 * size, Vector3(0, 0.09 * size, -0.06 * size), body, Vector3.ONE, 6)
	BuildKit.box(b, Vector3(0.012, 0.01, 0.03) * size, Vector3(0, 0.088 * size, -0.095 * size), BuildKit.color_mat(Color(0.9, 0.6, 0.1)), false)
	BuildKit.box(b, Vector3(0.04, 0.008, 0.07) * size, Vector3(0, 0.06 * size, 0.08 * size), body, false, Vector3(-15, 0, 0))
	for sx: float in [-1.0, 1.0]:
		var w := Node3D.new()
		w.position = Vector3(sx * 0.03 * size, 0.07 * size, 0)
		b.add_child(w)
		BuildKit.box(w, Vector3(0.11, 0.006, 0.06) * size, Vector3(sx * 0.055 * size, 0, 0.01 * size), body, false)
		b.set_meta("wl" if sx < 0 else "wr", w)
	return b


func _build_ground_birds() -> void:
	# Spatzen, Amseln oder Rotkehlchen, in kleinen Gruppen
	var kinds := [[Color(0.45, 0.33, 0.22), Color(0.7, 0.62, 0.5), 1.0], [Color(0.06, 0.06, 0.06), Color(0.1, 0.09, 0.08), 1.4],
			[Color(0.4, 0.33, 0.25), Color(0.85, 0.4, 0.15), 1.0]]
	var k: Array = kinds[_rng.randi() % kinds.size()]
	var n := _rng.randi_range(2, 5) if k[2] < 1.2 else _rng.randi_range(1, 2)
	for i in n:
		var b := _bird(_model, k[0], k[1], k[2])
		b.top_level = true
		var p := global_position + Vector3(_rng.randf_range(-1.5, 1.5), 0, _rng.randf_range(-1.5, 1.5))
		b.global_position = Vector3(p.x, Terrain.height_at(p.x, p.z), p.z)
		b.rotation.y = _rng.randf() * TAU
		b.set_meta("home", b.global_position)
		b.set_meta("hop", Vector3.ZERO)
		_parts.append(b)


func _build_butterfly() -> void:
	var cols := [Color(0.95, 0.5, 0.1), Color(0.95, 0.95, 0.9), Color(0.95, 0.85, 0.2), Color(0.3, 0.45, 0.95), Color(0.6, 0.15, 0.1)]
	var wing := BuildKit.color_mat(cols[_rng.randi() % cols.size()], 0.8)
	wing.cull_mode = BaseMaterial3D.CULL_DISABLED
	BuildKit.box(_model, Vector3(0.008, 0.008, 0.04), Vector3.ZERO, BuildKit.color_mat(Color(0.1, 0.08, 0.06)), false)
	for sx: float in [-1.0, 1.0]:
		var w := _pivot(_model, "w%d" % int(sx), Vector3.ZERO)
		BuildKit.box(w, Vector3(0.045, 0.002, 0.05), Vector3(sx * 0.024, 0, -0.005), wing, false)
		_parts.append(w)


func _build_insects() -> void:
	var mat := BuildKit.color_mat(Color(0.05, 0.05, 0.04), 0.9)
	for i in 22:
		var b := Node3D.new()
		_model.add_child(b)
		BuildKit.box(b, Vector3(0.012, 0.012, 0.012), Vector3.ZERO, mat, false)
		_parts.append(b)


func _build_flyover() -> void:
	var buzzard := _rng.randf() < 0.4
	if buzzard:
		set_meta("circle", true)
		set_meta("center", global_position)
		var b := _bird(_model, Color(0.35, 0.25, 0.17), Color(0.75, 0.68, 0.55), 9.0)
		(b.get_meta("wl") as Node3D).rotation.z = 0.08
		(b.get_meta("wr") as Node3D).rotation.z = -0.08
		lifetime = 70.0
	else:
		# ein paar Krähen
		for i in _rng.randi_range(1, 3):
			var b := _bird(_model, Color(0.05, 0.05, 0.06), Color(0.08, 0.08, 0.09), 5.0)
			b.position = Vector3(_rng.randf_range(-3, 3), _rng.randf_range(-1, 1), _rng.randf_range(-3, 3))
			_parts.append(b)


func _build_flock() -> void:
	# Keilformation: Spitze vorne, zwei Schenkel nach hinten
	for i in flock_size:
		var b := _bird(_model, Color(0.12, 0.12, 0.13), Color(0.6, 0.6, 0.6), 4.5)
		var row := (i + 1) / 2
		var side := -1.0 if i % 2 == 0 else 1.0
		var home := Vector3(side * row * 1.4, _rng.randf_range(-0.3, 0.3), row * 1.6)
		if i > flock_size * 0.7:
			home += Vector3(_rng.randf_range(-3, 3), _rng.randf_range(-1, 1), _rng.randf_range(-2, 2))
		b.position = home
		b.set_meta("home", home)
		_parts.append(b)
	lifetime = 60.0


func _build_deer() -> void:
	# Dunkel, im Wald kaum zu erkennen: Umriss, helle Spiegel, leuchtende Augen
	var fur := BuildKit.color_mat(Color(0.28, 0.2, 0.14), 1.0)
	var rump := BuildKit.color_mat(Color(0.75, 0.7, 0.62), 1.0)
	BuildKit.sphere(_model, 0.25, Vector3(0, 0.82, 0), fur, Vector3(0.9, 0.95, 2.2), 10)
	BuildKit.sphere(_model, 0.1, Vector3(0, 0.88, 0.5), rump, Vector3(1.1, 1.1, 0.5), 6)
	var legs := [Vector3(-0.11, 0.65, -0.38), Vector3(0.11, 0.65, -0.38), Vector3(-0.11, 0.65, 0.38), Vector3(0.11, 0.65, 0.38)]
	for k in 4:
		var leg := _pivot(_model, "leg%d" % k, legs[k])
		BuildKit.box(leg, Vector3(0.05, 0.66, 0.05), Vector3(0, -0.32, 0), fur, false)
	BuildKit.cylinder(_model, 0.07, 0.45, Vector3(0, 1.08, -0.42), fur, false, Vector3(-35, 0, 0), 0.06, 8)
	var head := _pivot(_model, "head", Vector3(0, 1.28, -0.58))
	BuildKit.sphere(head, 0.09, Vector3(0, 0, -0.06), fur, Vector3(0.85, 0.9, 1.6), 8)
	for sx: float in [-1.0, 1.0]:
		BuildKit.box(head, Vector3(0.05, 0.12, 0.02), Vector3(sx * 0.07, 0.1, 0.03), fur, false, Vector3(0, 0, sx * 35))
	_eyes(head, Vector3(0, 0.03, -0.11), 0.055, 0.018)


func _build_fox() -> void:
	var fur := BuildKit.color_mat(Color(0.6, 0.28, 0.08), 1.0)
	var white := BuildKit.color_mat(Color(0.85, 0.82, 0.75), 1.0)
	var dark := BuildKit.color_mat(Color(0.08, 0.06, 0.05), 0.9)
	BuildKit.sphere(_model, 0.12, Vector3(0, 0.32, 0), fur, Vector3(0.85, 0.85, 2.2), 8)
	var legs := [Vector3(-0.06, 0.24, -0.18), Vector3(0.06, 0.24, -0.18), Vector3(-0.06, 0.24, 0.18), Vector3(0.06, 0.24, 0.18)]
	for k in 4:
		var leg := _pivot(_model, "leg%d" % k, legs[k])
		BuildKit.box(leg, Vector3(0.03, 0.25, 0.03), Vector3(0, -0.12, 0), dark, false)
	var head := _pivot(_model, "head", Vector3(0, 0.4, -0.3))
	BuildKit.sphere(head, 0.07, Vector3(0, 0, 0), fur, Vector3(1.0, 0.85, 1.0), 8)
	BuildKit.cylinder(head, 0.04, 0.12, Vector3(0, -0.02, -0.09), white, false, Vector3(-90, 0, 0), 0.01, 6)
	for sx: float in [-1.0, 1.0]:
		BuildKit.cylinder(head, 0.03, 0.08, Vector3(sx * 0.04, 0.08, 0.0), fur, false, Vector3(0, 0, -sx * 12), 0.002, 4)
	_eyes(head, Vector3(0, 0.02, -0.06), 0.03, 0.012)
	var tail := _pivot(_model, "tail", Vector3(0, 0.32, 0.25))
	BuildKit.sphere(tail, 0.07, Vector3(0, -0.04, 0.18), fur, Vector3(0.8, 0.8, 2.6), 8)
	BuildKit.sphere(tail, 0.045, Vector3(0, -0.07, 0.36), white, Vector3(0.9, 0.9, 1.2), 6)


func _build_hedgehog() -> void:
	var spikes := BuildKit.color_mat(Color(0.3, 0.24, 0.17), 1.0)
	var tip := BuildKit.color_mat(Color(0.7, 0.65, 0.55), 1.0)
	var face := BuildKit.color_mat(Color(0.5, 0.4, 0.3), 1.0)
	BuildKit.sphere(_model, 0.11, Vector3(0, 0.07, 0.02), spikes, Vector3(1.0, 0.7, 1.3), 8)
	for i in 36:
		var a := _rng.randf() * TAU
		var e := _rng.randf_range(0.2, 1.3)
		var n := Vector3(cos(a) * cos(e), sin(e) * 0.7, sin(a) * cos(e) * 1.3 + 0.02)
		var s := BuildKit.box(_model, Vector3(0.006, 0.05, 0.006), Vector3(0, 0.07, 0) + n * 0.1, tip if i % 3 == 0 else spikes, false)
		s.look_at_from_position(s.position, s.position + n + Vector3(0, 0.001, 0.0011), Vector3.UP)
		s.rotate_object_local(Vector3.RIGHT, PI * 0.5)
	var head := _pivot(_model, "head", Vector3(0, 0.05, -0.12))
	BuildKit.sphere(head, 0.045, Vector3(0, 0, -0.02), face, Vector3(0.9, 0.8, 1.4), 6)
	BuildKit.sphere(head, 0.012, Vector3(0, -0.005, -0.08), BuildKit.color_mat(Color(0.03, 0.03, 0.03), 0.3), Vector3.ONE, 4)
	_eyes(head, Vector3(0, 0.015, -0.04), 0.022, 0.007)
	var legs := [Vector3(-0.05, 0.03, -0.06), Vector3(0.05, 0.03, -0.06), Vector3(-0.05, 0.03, 0.07), Vector3(0.05, 0.03, 0.07)]
	for k in 4:
		var leg := _pivot(_model, "leg%d" % k, legs[k])
		BuildKit.box(leg, Vector3(0.015, 0.035, 0.015), Vector3(0, -0.015, 0), face, false)
