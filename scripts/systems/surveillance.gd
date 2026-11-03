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
	camera.cull_mask = 0xFFFFF
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
	_collect.call_deferred()


func _collect() -> void:
	cameras.clear()
	for c in get_tree().get_nodes_in_group("security_camera"):
		cameras.append(c as SecurityCamera)
	cameras.sort_custom(func(a: SecurityCamera, b: SecurityCamera) -> bool: return a.index < b.index)
	set_active(0)


func set_active(i: int) -> void:
	if cameras.is_empty():
		return
	active_index = posmod(i, cameras.size())
	camera.global_transform = cameras[active_index].eye_transform()


func active_name() -> String:
	if cameras.is_empty():
		return ""
	return cameras[active_index].camera_name


func is_glitching() -> bool:
	return _time < glitch_until[active_index] if active_index < glitch_until.size() else false


func _process(delta: float) -> void:
	_time += delta
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var near_monitor := player != null and player.global_position.distance_to(Vector3(1.6, 1.0, 3.6)) < 4.5
	var render := PowerManager.has_power() and (viewing or near_monitor)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if render else SubViewport.UPDATE_DISABLED
	PowerManager.set_consumer("monitor", viewing)
	# Infrarot-Look: nachts aufgehellt, tagsüber normaler
	var day := smoothstep(-9.0, 12.0, DayNightEnvironment.sun_altitude_deg(TimeManager.hour))
	_env.ambient_light_energy = lerpf(0.55, 0.25, day)
	_env.background_color = Color(0.02, 0.02, 0.02).lerp(Color(0.7, 0.72, 0.7), day)
	_env.fog_light_color = _env.background_color
	if _phantom and _time > _phantom_until:
		_phantom.queue_free()
		_phantom = null


func _on_glitch(index: int, seconds: float) -> void:
	if index < glitch_until.size():
		glitch_until[index] = _time + seconds


## Trugbild: eine Gestalt, die nur auf dieser Kamera zu sehen ist.
func _on_phantom(index: int, seconds: float) -> void:
	if cameras.is_empty() or _phantom:
		return
	var cam := cameras[clampi(index, 0, cameras.size() - 1)]
	var scene := get_tree().current_scene
	_phantom = Node3D.new()
	_phantom.name = "Phantom"
	scene.add_child(_phantom)
	var spot := cam.phantom_spot
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
