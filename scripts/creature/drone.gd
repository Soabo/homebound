class_name AlienDrone
extends Node3D
## Drohne (Phase 8, GDD 9.2 / 11.2): fliegt nachts über das Grundstück und leuchtet den Boden ab.
## Unberechenbar: jedes Mal ein anderes Muster – Bahnen, Kreisen, Suchen mit Halten,
## vor einem Fenster schweben und hineinleuchten. Auf Geräusche fliegt sie zu. Erfasst ihr Lichtkegel den Spieler im Freien, schlägt sie Alarm –
## dann greift die Kreatur an. Störsender lenken sie ab; Stroboskop- und Bewegungsmelder-Licht
## bringen sie ins Taumeln (einmal verliert sie dabei ein Teil).

## Werte (Muster, Höhen, Reichweiten) in data/creatures/drone.tres
const HEIGHT := 9.0  ## Bezugshöhe für die Kegelgröße
var cfg: DroneConfig = DroneConfig.get_default()

var _path: Array[Vector3] = []
## Zu jedem Wegpunkt: wie lange dort schweben, wohin leuchten (null = nach unten)
var _hold: Array[float] = []
var _aims: Array = []
var _hold_left: float = 0.0
var _aim: Variant = null
var _sweep: float = 0.0
var _heard_cooldown: float = 0.0
var _rng := RandomNumberGenerator.new()
var _leaving: bool = false
var _alarm_done: bool = false
var _t: float = 0.0
var _spot: SpotLight3D
var _ring: Node3D
var _blink: StandardMaterial3D
var _hum: AudioStreamPlayer3D
var _glitch_timer: float = 0.0
var _stagger: float = 0.0
var _player: Player


func _ready() -> void:
	add_to_group("drone")
	_player = get_tree().get_first_node_in_group("player") as Player
	_rng.randomize()
	_build_model()
	# Anflug aus einer zufälligen Richtung
	var a := _rng.randf() * TAU
	global_position = Vector3(cos(a), 0, sin(a)) * cfg.approach_distance + Vector3(0, HEIGHT + 8.0, 0)
	_plan()
	EventBus.noise_made.connect(_on_noise)
	SoundBank.play_at(get_parent(), "signal", global_position, -6.0, 1.8)


## Ein oder zwei zufällige Flugmuster hintereinander.
func _plan() -> void:
	var names := Array(cfg.patterns)
	var weights := Array(cfg.pattern_weights)
	var first := _pick_weighted(names, weights)
	_add_pattern(first)
	if _rng.randf() < cfg.second_pattern_chance and names.size() > 1:
		var i := names.find(first)
		names.remove_at(i)
		if i < weights.size():
			weights.remove_at(i)
		_add_pattern(_pick_weighted(names, weights))


func _pick_weighted(names: Array, weights: Array) -> String:
	var total := 0.0
	for i in names.size():
		total += float(weights[i]) if i < weights.size() else 1.0
	var r := _rng.randf() * total
	for i in names.size():
		r -= float(weights[i]) if i < weights.size() else 1.0
		if r <= 0.0:
			return names[i]
	return names[names.size() - 1]


func _leg(p: Vector3, hold: float = 0.0, aim: Variant = null) -> void:
	_path.append(p)
	_hold.append(hold)
	_aims.append(aim)


func _add_pattern(kind: String) -> void:
	var h := _rng.randf_range(cfg.height_range.x, cfg.height_range.y)
	match kind:
		"lanes":
			# Bahnen, mal längs, mal quer, mal nur ein Teil des Grundstücks
			var across := _rng.randf() < 0.5
			var rows := _rng.randi_range(cfg.lanes_rows.x, cfg.lanes_rows.y)
			var start := _rng.randf_range(-14.0, -6.0)
			for r in rows:
				var c := start + r * 7.5
				var ends := [-18.0, 20.0] if r % 2 == 0 else [20.0, -18.0]
				for e: float in ends:
					_leg(Vector3(c, h, e) if across else Vector3(e, h, c))
		"circle":
			var rad := _rng.randf_range(cfg.circle_radius.x, cfg.circle_radius.y)
			var dirn := 1.0 if _rng.randf() < 0.5 else -1.0
			var a0 := _rng.randf() * TAU
			var n := _rng.randi_range(cfg.circle_points.x, cfg.circle_points.y)
			for k in n:
				var a := a0 + dirn * TAU * k / 10.0
				_leg(Vector3(cos(a) * rad, h + sin(k * 0.9) * 1.5, sin(a) * rad))
		"search":
			# Wahllos über dem Grundstück, bleibt immer wieder stehen und sucht mit dem Licht
			for k in _rng.randi_range(cfg.search_points.x, cfg.search_points.y):
				_leg(Vector3(_rng.randf_range(-18, 20), _rng.randf_range(cfg.height_range.x - 1.0, cfg.height_range.y - 1.0), _rng.randf_range(-14, 16)), _rng.randf_range(cfg.search_hold.x, cfg.search_hold.y))
		"window":
			# Schwebt tief vor einem Fenster und leuchtet hinein
			var wins := get_tree().get_nodes_in_group("entry_point").filter(func(e: Node) -> bool: return e is CabinWindow)
			wins.shuffle()
			for w in wins.slice(0, _rng.randi_range(cfg.window_count.x, cfg.window_count.y)):
				var out: Vector3 = w.call("outside_point")
				var inner: Vector3 = w.call("inside_point")
				var dir := (out - inner)
				dir.y = 0.0
				var hover := out + dir.normalized() * cfg.window_distance
				hover.y = Terrain.height_at(hover.x, hover.z) + cfg.window_height
				_leg(hover, _rng.randf_range(cfg.window_hold.x, cfg.window_hold.y), inner + Vector3(0, -0.2, 0))


func _build_model() -> void:
	var hull := CrashSite.hull_material()
	BuildKit.lathe(self, PackedVector2Array([Vector2(0.0, -0.12), Vector2(0.45, -0.08), Vector2(0.62, 0.0), Vector2(0.45, 0.08), Vector2(0.2, 0.16), Vector2(0.0, 0.18)]),
			Vector3.ZERO, hull, 18)
	BuildKit.sphere(self, 0.14, Vector3(0, -0.12, 0), CrashSite.glow_material(), Vector3(1.0, 0.6, 1.0), 10)
	_ring = Node3D.new()
	add_child(_ring)
	_blink = BuildKit.emissive_mat(Color(1.0, 0.2, 0.15), 3.0)
	for k in 4:
		var a := TAU * k / 4.0
		BuildKit.sphere(_ring, 0.035, Vector3(cos(a) * 0.6, 0.0, sin(a) * 0.6), _blink, Vector3.ONE, 6)
	_spot = SpotLight3D.new()
	_spot.position = Vector3(0, -0.2, 0)
	_spot.spot_angle = rad_to_deg(atan(cfg.cone_radius / HEIGHT))
	_spot.spot_range = HEIGHT + 6.0
	_spot.light_energy = 7.0
	_spot.light_color = Color(0.75, 0.95, 1.0)
	_spot.light_volumetric_fog_energy = 3.0
	_spot.shadow_enabled = true
	add_child(_spot)
	_hum = AudioStreamPlayer3D.new()
	_hum.stream = SoundBank.get_generated("generator")
	_hum.pitch_scale = 2.6
	_hum.volume_db = -10.0
	_hum.unit_size = 6.0
	_hum.max_distance = 45.0
	add_child(_hum)
	_hum.play()


func _physics_process(delta: float) -> void:
	_t += delta
	_ring.rotation.y += delta * 3.0
	_blink.emission_energy_multiplier = 4.0 if fmod(_t, 1.0) < 0.12 else 0.2
	if _t > cfg.patrol_time:
		_leave()
	# Taumeln nach grellem Licht
	if _stagger > 0.0:
		_stagger -= delta
		rotation = Vector3(sin(_t * 9.0) * 0.4, rotation.y, cos(_t * 7.0) * 0.4)
		global_position.y += sin(_t * 5.0) * delta * 2.0
	else:
		rotation.x = lerpf(rotation.x, 0.0, delta * 3.0)
		rotation.z = lerpf(rotation.z, 0.0, delta * 3.0)
	_fly(delta)
	if _spot.visible:
		_point_spot()
	if not _leaving:
		_check_jammer()
		_check_lights()
		_scan()
	_glitch_cameras(delta)


func _fly(delta: float) -> void:
	_heard_cooldown -= delta
	if _hold_left > 0.0:
		_hold_left -= delta
		_sweep += delta
		return
	if _path.is_empty():
		if _leaving:
			queue_free()
		else:
			_leave()
		return
	var target := _path[0]
	var to := target - global_position
	var speed := cfg.speed * (0.4 if _stagger > 0.0 else 1.0) * (1.6 if _leaving else 1.0)
	var step := speed * delta
	if to.length() <= step:
		global_position = target
		_path.pop_front()
		_hold_left = _hold.pop_front() if not _hold.is_empty() else 0.0
		_aim = _aims.pop_front() if not _aims.is_empty() else null
		if _aim == null and _hold_left > 0.0:
			_sweep = 0.0
	else:
		global_position += to.normalized() * step
		if _hold_left <= 0.0 and not _aims.is_empty() and _aims[0] == null:
			_aim = null


## Wohin der Lichtkegel zeigt: nach unten, beim Suchen kreisend, oder gezielt (Fenster, Geräusch).
func _aim_point() -> Vector3:
	if _aim != null:
		return _aim
	var g := global_position
	g.y = Terrain.height_at(g.x, g.z)
	if _hold_left > 0.0:
		g += Vector3(cos(_sweep * 1.3), 0, sin(_sweep * 1.3)) * 3.0
	return g


func _point_spot() -> void:
	var t := _aim_point()
	var d := t - _spot.global_position
	if d.length() < 0.1:
		return
	var up := Vector3.FORWARD if absf(d.normalized().y) > 0.98 else Vector3.UP
	_spot.look_at(t, up)


## Ein Geräusch in der Nähe: Sie fliegt hin, bleibt stehen und leuchtet die Stelle ab.
func _on_noise(pos: Vector3, radius: float) -> void:
	if _leaving or _heard_cooldown > 0.0 or radius < cfg.hear_min_radius:
		return
	if Vector2(pos.x - global_position.x, pos.z - global_position.z).length() > cfg.hear_distance:
		return
	_heard_cooldown = cfg.hear_cooldown
	var above := Vector3(pos.x + _rng.randf_range(-2, 2), Terrain.height_at(pos.x, pos.z) + _rng.randf_range(6.0, 8.0), pos.z + _rng.randf_range(-2, 2))
	_path.insert(0, above)
	_hold.insert(0, _rng.randf_range(cfg.hear_hold.x, cfg.hear_hold.y))
	_aims.insert(0, null)
	_hold_left = 0.0


func _leave() -> void:
	if _leaving:
		return
	_leaving = true
	_spot.visible = false
	_path.clear()
	_hold.clear()
	_aims.clear()
	_hold_left = 0.0
	var away := Vector3(_rng.randf_range(-1, 1), 0, _rng.randf_range(-1, 1)).normalized() * 90.0
	_path.append(global_position + Vector3(0, 12, 0))
	_path.append(away + Vector3(0, 30, 0))


## Im Lichtkegel und im Freien? Dann Alarm.
func _scan() -> void:
	if _alarm_done or _player == null or GameState.dead:
		return
	var p := _player.global_position
	var aim := _aim_point()
	if _aim != null:
		# leuchtet durchs Fenster: wer nah dahinter steht, wird gesehen
		if p.distance_to(aim) > cfg.window_spot_distance:
			return
	else:
		if Cabin.is_inside(p) or Shed.is_inside(p):
			return
		var radius := tan(deg_to_rad(_spot.spot_angle)) * maxf(global_position.y - aim.y, 1.0) * 0.9
		if Vector2(p.x - aim.x, p.z - aim.z).length() > radius:
			return
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3(0, -0.3, 0), p + Vector3(0, 1.4, 0))
	q.exclude = [_player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		# durch eine Fensterscheibe sieht sie trotzdem
		var n := hit["collider"] as Node
		while n and not n is CabinWindow:
			n = n.get_parent()
		if n == null or _aim == null:
			return
	_alarm_done = true
	_spot.light_color = Color(1.0, 0.25, 0.2)
	SoundBank.play_at(get_parent(), "signal", global_position, 6.0, 2.2)
	EventBus.notify("Der Lichtkegel bleibt auf dir stehen – du wurdest gesehen!" if _aim == null else "Das Licht durchs Fenster bleibt auf dir stehen – du wurdest gesehen!", 3.5)
	EventBus.noise_made.emit(p, 80.0)
	var away := (p - Vector3(0, p.y, 0)).normalized() if Vector2(p.x, p.z).length() > 1.0 else Vector3(0, 0, 1)
	ThreatDirector.spawn_ambush(p + away * 26.0)
	get_tree().create_timer(4.0).timeout.connect(_leave)


## Störsender in der Nähe: die Drohne verliert das Signal und dreht ab.
func _check_jammer() -> void:
	for j in get_tree().get_nodes_in_group("jammer"):
		var n := j as Node3D
		if Vector2(n.global_position.x - global_position.x, n.global_position.z - global_position.z).length() < cfg.jammer_range:
			_stagger = 1.5
			SoundBank.play_at(get_parent(), "static", global_position, -4.0, 1.6)
			EventBus.notify("Das Licht über dir flackert, wird schwächer und zieht ab.", 3.0)
			_leave()
			return


## Grelles Licht von Stroboskop oder Bewegungsmelder: taumeln, einmal ein Teil verlieren.
func _check_lights() -> void:
	if _stagger > 0.0:
		return
	for s in get_tree().get_nodes_in_group("structure"):
		var st := s as Structure
		if st == null or not st.type in ["strobe_light", "motion_light"] or not st.is_lit():
			continue
		if Vector2(st.global_position.x - global_position.x, st.global_position.z - global_position.z).length() < cfg.light_range:
			_stagger = cfg.stagger_time
			SoundBank.play_at(get_parent(), "static", global_position, 0.0, 2.0)
			if not WorldState.drone_part_dropped:
				WorldState.drone_part_dropped = true
				_drop_part()
			return


func _drop_part() -> void:
	var g := Creature._ground(global_position)
	var p := ItemPickup.new()
	p.name = "DronePart"
	p.item_id = "drone_part"
	p.amount = 1
	p.collider_size = Vector3(0.6, 0.4, 0.6)
	p.collider_offset = Vector3(0, 0.2, 0)
	p.position = g
	get_parent().add_child(p)
	var v := Node3D.new()
	p.add_child(v)
	BuildKit.lathe(v, PackedVector2Array([Vector2(0.15, -0.02), Vector2(0.2, 0.0), Vector2(0.15, 0.02)]), Vector3(0, 0.05, 0), CrashSite.glow_material(), 12, Vector3(70, 0, 0))
	BuildKit.sphere(v, 0.08, Vector3(0, 0.08, 0), CrashSite.hull_material(), Vector3.ONE, 8)
	p.visuals.append(v)
	SoundBank.play_at(get_parent(), "clatter", g, 0.0, 1.4)
	EventBus.notify("Etwas ist von dem fliegenden Licht abgefallen …", 3.0)


func _glitch_cameras(delta: float) -> void:
	_glitch_timer -= delta
	if _glitch_timer > 0.0:
		return
	_glitch_timer = 2.0
	var cams := get_tree().get_nodes_in_group("security_camera")
	for i in cams.size():
		if (cams[i] as Node3D).global_position.distance_to(global_position) < 16.0:
			EventBus.camera_glitch.emit((cams[i] as SecurityCamera).index, 1.5)
