class_name Surveillance
extends Node
## Überwachungsanlage: eine Bildquelle (SubViewport), die zwischen den Kameras
## umschaltet. Liefert das Bild für den Monitor am Schreibtisch und die
## Monitor-Ansicht. Kameras zeigen nicht immer die Wahrheit (GDD 7.5):
## Störungen und Trugbilder, die nur auf dem Bildschirm existieren.

const PHANTOM_LAYER := 2  ## Sichtbarkeits-Ebene, die nur Überwachungskameras sehen

var viewport: SubViewport
var camera: Camera3D
var active_index: int = 0
var cameras: Array[SecurityCamera] = []
var viewing: bool = false
var glitch_until: Array[float] = [0.0, 0.0, 0.0]

var _env: Environment
var _phantom: Node3D
var _phantom_cam: int = -1
var _phantom_until: float = 0.0
var _time: float = 0.0
## Lauernde Gestalt: hockt nur im Bild der aktuellen Kamera, verschwindet beim Umschalten.
## Orte je Kamera (werden zur Laufzeit auf Sichtbarkeit geprüft); "bush" bringt einen Busch als Versteck mit.
const LURK_SPOTS := [
	[[Vector3(-4.45, 0, 5.25), "door"], [Vector3(1.75, 0, 6.2), "window"], [Vector3(-2.4, 0, 7.3), "door"],
			[Vector3(-6.2, 0, 9.5), "bush"], [Vector3(0.2, 0, 13.5), "bush"], [Vector3(-5.6, 0, 16.6), "plain"],
			[Vector3(-0.8, 0, 9.8), "plain"]],
	[[Vector3(-8.5, 0, -10.5), "bush"], [Vector3(-12.5, 0, -15.2), "plain"], [Vector3(-6.4, 0, -7.5), "plain"],
			[Vector3(-3.0, 0, -6.6), "bush"], [Vector3(-15.0, 0, -9.5), "bush"]],
	[[Vector3(6.8, 0, 2.6), "window"], [Vector3(6.0, 0, 14.8), "corn"], [Vector3(8.5, 0, 15.6), "corn"],
			[Vector3(3.0, 0, 9.5), "bush"], [Vector3(7.2, 0, 8.0), "plain"]],
]
var _lurker: Node3D
var _lurker_parts: Dictionary
var _lurk_cam: Camera3D
var _lurk_look_at: float = 0.0
var _last_lurk: float = -1e9
var _was_viewing: bool = false


func _ready() -> void:
	name = "Surveillance"
	add_to_group("surveillance")
	viewport = SubViewport.new()
	viewport.size = Vector2i(320, 240)
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	viewport.msaa_3d = Viewport.MSAA_DISABLED
	add_child(viewport)
	camera = Camera3D.new()
	camera.fov = 72.0
	camera.far = 120.0
	# ohne Kameragehäuse (sonst sieht man die eigene Kamera von innen)
	camera.cull_mask = 0xFFFFF & ~SecurityCamera.BODY_LAYER
	viewport.add_child(camera)
	_env = Environment.new()
	_env.background_mode = Environment.BG_COLOR
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_color = Color(0.75, 0.8, 0.75)
	_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_env.fog_enabled = true
	_env.fog_density = 0.02
	_env.adjustment_enabled = true
	_env.adjustment_saturation = 0.0
	_env.adjustment_contrast = 1.25
	camera.environment = _env
	EventBus.camera_glitch.connect(_on_glitch)
	EventBus.camera_phantom.connect(_on_phantom)
	Supplies.changed.connect(_on_supplies)
	_collect.call_deferred()


var _cam_sig: String = ""


func _on_supplies() -> void:
	# nur neu aufbauen, wenn sich an den Kameras etwas geändert hat
	var sig := str(Supplies.cameras)
	if sig != _cam_sig:
		_cam_sig = sig
		_collect()


## Kameras kommen aus dem Versorgungs-Manager (selbst eingebaut). Drei feste Plätze 0..2, leere zeigen „kein Signal“.
const SLOTS := 3


func _collect() -> void:
	for c in get_tree().get_nodes_in_group("security_camera"):
		if not (c as Node).is_queued_for_deletion():
			c.queue_free()
	cameras.clear()
	for i in SLOTS:
		cameras.append(null)
	var scene := get_tree().current_scene
	for d: Dictionary in Supplies.cameras:
		var i := int(d["index"])
		if i < 0 or i >= SLOTS:
			continue
		var cam := SecurityCamera.from_install(d)
		scene.add_child.call_deferred(cam)
		cameras[i] = cam
	set_active(active_index)


func installed(i: int) -> bool:
	return i >= 0 and i < cameras.size() and cameras[i] != null and is_instance_valid(cameras[i])


func set_active(i: int) -> void:
	active_index = posmod(i, SLOTS)
	_remove_lurker()
	if installed(active_index):
		_apply_camera.call_deferred()
		if viewing:
			_maybe_lurk.call_deferred()


func _apply_camera() -> void:
	if installed(active_index) and cameras[active_index].is_inside_tree():
		camera.global_transform = cameras[active_index].eye_transform()
		camera.fov = cameras[active_index].fov


func active_name() -> String:
	if not installed(active_index):
		return "nicht installiert"
	return cameras[active_index].camera_name


## Ältere Tests/Kontrollbilder: die drei Kameras an den früheren festen Stellen einbauen.
func install_defaults() -> void:
	var front_z := Cabin.HALF_Z + Cabin.LOG_R
	var setups := [
		[Vector3(5.7, Cabin.WALL_TOP - 0.35, front_z), Vector3(0, 0, 1), -0.75],
		[Vector3(-5.0, Cabin.WALL_TOP - 0.35, -front_z), Vector3(0, 0, -1), 0.35],
		[Vector3(Shed.ORIGIN.x - Shed.HALF.x - 0.05, 2.05, Shed.ORIGIN.z + 1.2), Vector3(-1, 0, 0), 0.6],
	]
	for i in setups.size():
		Supplies.install_camera(i, setups[i][0], setups[i][1], setups[i][2])
	_collect()


func is_glitching() -> bool:
	return _time < glitch_until[active_index] if active_index < glitch_until.size() else false


func _process(delta: float) -> void:
	_time += delta
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var near_monitor := player != null and player.global_position.distance_to(Vector3(1.6, 1.0, 3.6)) < 4.5
	var render := PowerManager.has_power() and (viewing or near_monitor) and installed(active_index)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if render else SubViewport.UPDATE_DISABLED
	PowerManager.set_consumer("monitor", viewing)
	# Infrarot-Look: nachts aufgehellt, tagsüber normaler
	var day := smoothstep(-9.0, 12.0, DayNightEnvironment.sun_altitude_deg(TimeManager.hour))
	_env.ambient_light_energy = lerpf(0.55, 0.25, day)
	_env.background_color = Color(0.02, 0.02, 0.02).lerp(Color(0.7, 0.72, 0.7), day)
	_env.fog_light_color = _env.background_color
	if viewing and not _was_viewing:
		_maybe_lurk()
	elif not viewing and _was_viewing:
		_remove_lurker()
	_was_viewing = viewing
	_update_lurker(delta)
	if _phantom and _time > _phantom_until:
		_phantom.queue_free()
		_phantom = null


func _on_glitch(index: int, seconds: float) -> void:
	if index < glitch_until.size():
		glitch_until[index] = _time + seconds


## Trugbild: eine Gestalt, die nur auf dieser Kamera zu sehen ist.
func _on_phantom(index: int, seconds: float) -> void:
	if _phantom:
		return
	# nur auf einer eingebauten Kamera; sonst auf irgendeiner, die es gibt
	if not installed(index):
		index = -1
		for i in SLOTS:
			if installed(i):
				index = i
				break
		if index < 0:
			return
	var cam: SecurityCamera = cameras[index]
	var scene := get_tree().current_scene
	_phantom = Node3D.new()
	_phantom.name = "Phantom"
	scene.add_child(_phantom)
	# ein Stück vor der Kamera auf dem Boden, etwas seitlich
	var eye := cam.eye_transform()
	var fwd := -eye.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var spot := eye.origin + fwd * randf_range(9.0, 13.0) + Vector3(-fwd.z, 0, fwd.x) * randf_range(-2.5, 2.5)
	spot.y = Terrain.height_at(spot.x, spot.z)
	_phantom.global_position = spot
	Creature.build_model(_phantom)
	for vi in _phantom.find_children("*", "VisualInstance3D", true, false):
		(vi as VisualInstance3D).layers = 1 << (PHANTOM_LAYER - 1)
	var face := cam.global_position
	face.y = spot.y
	_phantom.look_at(face, Vector3.UP)
	_phantom.rotate_y(PI)
	_phantom_cam = cam.index
	_phantom_until = _time + seconds


func _maybe_lurk() -> void:
	if not installed(active_index):
		return
	var tc := ThreatDirector.config
	if tc == null or TimeManager.day < tc.camera_lurk_from_day or not PowerManager.has_power():
		return
	if _time - _last_lurk < tc.camera_lurk_cooldown or _phantom or is_glitching():
		return
	var chance := tc.camera_lurk_chance_night if TimeManager.is_night() else tc.camera_lurk_chance_day
	if randf() >= chance:
		return
	spawn_lurker()


## Setzt die hockende Gestalt an einen Ort, den die aktuelle Kamera wirklich sieht. Gibt false zurück, wenn keiner passt.
func spawn_lurker(only_spot: int = -1) -> bool:
	if not installed(active_index):
		return false
	_apply_camera()
	# alle Orte rund um Haus und Schuppen – geprüft wird, ob die aktive Kamera sie wirklich sieht
	var spots: Array = []
	for group: Array in LURK_SPOTS:
		spots.append_array(group)
	spots.shuffle()
	if only_spot >= 0:
		spots = [LURK_SPOTS[0][only_spot]]
	var player := get_tree().get_first_node_in_group("player") as Node3D
	for sp: Array in spots:
		var pos: Vector3 = sp[0]
		pos.y = Terrain.height_at(pos.x, pos.z) if absf(pos.x) > Cabin.HALF_X + 0.2 or absf(pos.z) > Cabin.HALF_Z + 1.6 else maxf(Terrain.height_at(pos.x, pos.z), _porch_height(pos))
		var head := pos + Vector3(0, 1.0, 0)
		if not camera.is_position_in_frustum(head) or not camera.is_position_in_frustum(pos + Vector3(0, 0.2, 0)):
			continue
		# steht der Spieler draußen ganz in der Nähe, würde er merken, dass dort nichts ist
		if player and player.global_position.distance_to(pos) < 6.0 and not Cabin.is_inside(player.global_position):
			continue
		var q := PhysicsRayQueryParameters3D.create(camera.global_position, head)
		var hit := camera.get_world_3d().direct_space_state.intersect_ray(q)
		if not hit.is_empty() and (hit["position"] as Vector3).distance_to(head) > 0.6:
			continue
		_build_lurker(pos, String(sp[1]))
		return true
	return false


func _porch_height(p: Vector3) -> float:
	# Veranda vor der Hütte liegt etwas höher als das Gelände
	if p.z > Cabin.HALF_Z and p.z < Cabin.HALF_Z + 1.6 and p.x > -6.0 and p.x < 1.6:
		return Cabin.FLOOR_Y - 0.03
	return 0.0


func _build_lurker(pos: Vector3, kind: String) -> void:
	_last_lurk = _time
	_lurker = Node3D.new()
	_lurker.name = "CameraLurker"
	get_tree().current_scene.add_child(_lurker)
	_lurker.global_position = pos
	_lurker_parts = Creature.build_model(_lurker)
	CreatureModel.pose_crouch(_lurker_parts)
	var eye := _lurker_parts.get("eye_mat") as StandardMaterial3D
	if eye:
		eye.emission_energy_multiplier = 3.0  # im Infrarot spiegeln die Augen
	if kind in ["bush", "corn"]:
		# halb verdeckt im Gebüsch bzw. zwischen den Maispflanzen
		var leaf := BuildKit.color_mat(Color(0.32, 0.42, 0.26) if kind == "bush" else Color(0.55, 0.55, 0.3), 0.9)
		var dir_cam := (camera.global_position - pos)
		dir_cam.y = 0.0
		dir_cam = dir_cam.normalized()
		for k in 5:
			var off := dir_cam * randf_range(0.35, 0.6) + Vector3(-dir_cam.z, 0, dir_cam.x) * randf_range(-0.55, 0.55)
			if kind == "bush":
				BuildKit.sphere(_lurker, randf_range(0.3, 0.45), off + Vector3(0, randf_range(0.25, 0.55), 0), leaf, Vector3(1.2, 0.85, 1.0), 8)
			else:
				BuildKit.box(_lurker, Vector3(0.05, 1.9, 0.05), off + Vector3(0, 0.95, 0), leaf, false, Vector3(randf_range(-6, 6), 0, randf_range(-6, 6)))
	for vi in _lurker.find_children("*", "VisualInstance3D", true, false):
		(vi as VisualInstance3D).layers = 1 << (PHANTOM_LAYER - 1)
	# Körper zur Kamera gedreht, aber nicht ganz – der Kopf dreht sich erst, wenn man hinsieht
	var face := camera.global_position
	face.y = pos.y
	_lurker.look_at(face, Vector3.UP)
	_lurker.rotate_y(PI + randf_range(0.5, 0.9) * (1.0 if randf() < 0.5 else -1.0))
	var tc := ThreatDirector.config
	_lurk_look_at = _time + (randf_range(tc.camera_lurk_look_after.x, tc.camera_lurk_look_after.y) if tc else 3.0)


func _update_lurker(delta: float) -> void:
	if _lurker == null:
		return
	if not viewing or not PowerManager.has_power():
		_remove_lurker()
		return
	var head := _lurker_parts.get("head") as Node3D
	if head == null:
		return
	if _time > _lurk_look_at:
		# dreht langsam den Kopf zur Kamera und schaut direkt hinein
		var local := _lurker.to_local(camera.global_position)
		var yaw := clampf(rad_to_deg(atan2(local.x, local.z)), -85.0, 85.0)
		head.rotation_degrees.y = lerpf(head.rotation_degrees.y, yaw, clampf(delta * 1.4, 0.0, 1.0))
		head.rotation_degrees.z = lerpf(head.rotation_degrees.z, 4.0, clampf(delta * 1.0, 0.0, 1.0))
	else:
		# leichtes Atmen, sonst reglos
		var torso := _lurker_parts.get("torso") as Node3D
		if torso:
			torso.rotation_degrees.x = 48.0 + sin(_time * 1.6) * 1.2


func _remove_lurker() -> void:
	if _lurker:
		_lurker.queue_free()
		_lurker = null
		_lurker_parts = {}
