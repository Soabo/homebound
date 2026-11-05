class_name AlienDrone
extends Node3D
## Drohne (Phase 8, GDD 9.2 / 11.2): fliegt nachts in Bahnen über das Grundstück und
## leuchtet den Boden ab. Erfasst ihr Lichtkegel den Spieler im Freien, schlägt sie Alarm –
## dann greift die Kreatur an. Störsender lenken sie ab; Stroboskop- und Bewegungsmelder-Licht
## bringen sie ins Taumeln (einmal verliert sie dabei ein Teil).

const HEIGHT := 9.0
const SPEED := 5.0
const CONE := 5.0     ## Radius des Lichtkegels am Boden
const PATROL_TIME := 95.0

var _path: Array[Vector3] = []
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
	_build_model()
	# Anflug aus Richtung der Struktur, dann Bahnen über dem Grundstück
	global_position = AlienStructure.SITE * 0.6 + Vector3(0, HEIGHT + 8.0, 0)
	var rows := 5
	for r in rows:
		var z := -14.0 + r * 7.5
		var xs := [-18.0, 20.0] if r % 2 == 0 else [20.0, -18.0]
		for x: float in xs:
			_path.append(Vector3(x, HEIGHT, z))
	SoundBank.play_at(get_parent(), "signal", global_position, -6.0, 1.8)


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
	_spot.rotation_degrees.x = -90.0
	_spot.spot_angle = rad_to_deg(atan(CONE / HEIGHT))
	_spot.spot_range = HEIGHT + 6.0
	_spot.light_energy = 7.0
	_spot.light_color = Color(0.75, 0.95, 1.0)
	_spot.light_volumetric_fog_energy = 3.0
	_spot.shadow_enabled = true
	add_child(_spot)
	_hum = AudioStreamPlayer3D.new()
	_hum.stream = SoundBank.get_sound("generator")
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
	if _t > PATROL_TIME:
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
	if not _leaving:
		_check_jammer()
		_check_lights()
		_scan()
	_glitch_cameras(delta)


func _fly(delta: float) -> void:
	if _path.is_empty():
		if _leaving:
			queue_free()
		else:
			_leave()
		return
	var target := _path[0]
	var to := target - global_position
	var step := SPEED * delta * (0.4 if _stagger > 0.0 else 1.0)
	if to.length() <= step:
		_path.pop_front()
	else:
		global_position += to.normalized() * step


func _leave() -> void:
	if _leaving:
		return
	_leaving = true
	_spot.visible = false
	_path.clear()
	_path.append(global_position + Vector3(0, 12, 0))
	_path.append(AlienStructure.SITE + Vector3(0, 30, 0))


## Im Lichtkegel und im Freien? Dann Alarm.
func _scan() -> void:
	if _alarm_done or _player == null or GameState.dead:
		return
	var p := _player.global_position
	if Cabin.is_inside(p) or Shed.is_inside(p):
		return
	var flat := Vector2(p.x - global_position.x, p.z - global_position.z).length()
	if flat > CONE:
		return
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3(0, -0.3, 0), p + Vector3(0, 1.4, 0))
	q.exclude = [_player.get_rid()]
	if not get_world_3d().direct_space_state.intersect_ray(q).is_empty():
		return
	_alarm_done = true
	_spot.light_color = Color(1.0, 0.25, 0.2)
	SoundBank.play_at(get_parent(), "signal", global_position, 6.0, 2.2)
	EventBus.notify("Der Lichtkegel bleibt auf dir stehen – die Drohne hat dich erfasst!", 3.5)
	EventBus.noise_made.emit(p, 80.0)
	var away := (p - Vector3(0, p.y, 0)).normalized() if Vector2(p.x, p.z).length() > 1.0 else Vector3(0, 0, 1)
	ThreatDirector.spawn_ambush(p + away * 26.0)
	get_tree().create_timer(4.0).timeout.connect(_leave)


## Störsender in der Nähe: die Drohne verliert das Signal und dreht ab.
func _check_jammer() -> void:
	for j in get_tree().get_nodes_in_group("jammer"):
		var n := j as Node3D
		if Vector2(n.global_position.x - global_position.x, n.global_position.z - global_position.z).length() < 26.0:
			_stagger = 1.5
			SoundBank.play_at(get_parent(), "static", global_position, -4.0, 1.6)
			EventBus.notify("Die Drohne flackert, verliert das Signal und dreht ab.", 3.0)
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
		if Vector2(st.global_position.x - global_position.x, st.global_position.z - global_position.z).length() < 9.0:
			_stagger = 2.5
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
	EventBus.notify("Etwas ist von der Drohne abgefallen …", 3.0)


func _glitch_cameras(delta: float) -> void:
	_glitch_timer -= delta
	if _glitch_timer > 0.0:
		return
	_glitch_timer = 2.0
	var cams := get_tree().get_nodes_in_group("security_camera")
	for i in cams.size():
		if (cams[i] as Node3D).global_position.distance_to(global_position) < 16.0:
			EventBus.camera_glitch.emit((cams[i] as SecurityCamera).index, 1.5)
