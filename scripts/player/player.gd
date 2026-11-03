class_name Player
extends CharacterBody3D
## First-Person-Steuerung (GDD 18.2): Gehen, Rennen, Ducken, Springen,
## Benutzen (E / R) und Taschenlampe (F).

@export var walk_speed: float = 3.0
@export var sprint_speed: float = 5.4
@export var crouch_speed: float = 1.6
@export var jump_velocity: float = 3.9
@export var mouse_sensitivity: float = 0.0022
@export var interact_distance: float = 2.4

const STAND_HEIGHT := 1.75
const CROUCH_HEIGHT := 1.05
const EYE_OFFSET := 0.13
const RADIUS := 0.32

var head: Node3D
var camera: Camera3D
var flashlight: SpotLight3D
var input_locked: bool = false
var current_interactable: Interactable = null

var _ray: RayCast3D
var _shape: CollisionShape3D
var _capsule: CapsuleShape3D
var _flashlight_rig: Node3D
var _viewmodel: Node3D
var _height: float = STAND_HEIGHT
var _bob_time: float = 0.0
var _last_prompt: String = ""
var _gravity: float = 9.8


func _ready() -> void:
	name = "Player"
	add_to_group("player")
	_gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	floor_max_angle = deg_to_rad(50.0)
	floor_snap_length = 0.35

	_capsule = CapsuleShape3D.new()
	_capsule.radius = RADIUS
	_capsule.height = STAND_HEIGHT
	_shape = CollisionShape3D.new()
	_shape.shape = _capsule
	_shape.position.y = STAND_HEIGHT * 0.5
	add_child(_shape)

	head = Node3D.new()
	head.name = "Head"
	head.position.y = STAND_HEIGHT - EYE_OFFSET
	add_child(head)

	camera = Camera3D.new()
	camera.fov = 75.0
	camera.near = 0.05
	camera.far = 300.0
	head.add_child(camera)
	camera.current = true

	_ray = RayCast3D.new()
	_ray.target_position = Vector3(0, 0, -interact_distance)
	_ray.add_exception(self)
	camera.add_child(_ray)

	# Die Taschenlampe folgt der Blickrichtung mit leichter Verzögerung.
	_flashlight_rig = Node3D.new()
	_flashlight_rig.top_level = true
	add_child(_flashlight_rig)
	flashlight = SpotLight3D.new()
	flashlight.position = Vector3(0.25, -0.24, -0.62)
	flashlight.light_color = Color(1.0, 0.95, 0.85)
	flashlight.light_energy = 5.0
	flashlight.spot_range = 28.0
	flashlight.spot_angle = 26.0
	flashlight.spot_angle_attenuation = 1.6
	flashlight.spot_attenuation = 1.0
	flashlight.shadow_enabled = true
	flashlight.light_volumetric_fog_energy = 1.4
	flashlight.visible = false
	_flashlight_rig.add_child(flashlight)
	_flashlight_rig.global_transform = camera.global_transform
	_build_flashlight_model()

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	EventBus.sleep_requested.connect(func(_h: float) -> void: input_locked = true)
	EventBus.sleep_finished.connect(func() -> void: input_locked = false)


## Sichtbare Taschenlampe unten rechts im Bild, gehalten von einem Ärmel.
func _build_flashlight_model() -> void:
	_viewmodel = Node3D.new()
	_viewmodel.name = "FlashlightModel"
	_viewmodel.position = Vector3(0.24, -0.25, -0.42)
	_viewmodel.rotation_degrees = Vector3(4, 6, 0)
	camera.add_child(_viewmodel)
	var metal := BuildKit.tex_mat("metal", 0.15, Color(1.3, 1.3, 1.35), 0.4)
	var rubber := BuildKit.tex_mat("metal", 0.1, Color(0.35, 0.35, 0.35), 0.8)
	var sleeve := BuildKit.tex_mat("fabric", 0.15, Color(0.55, 0.65, 0.6))
	var skin := BuildKit.color_mat(Color(0.62, 0.46, 0.38), 0.8)
	BuildKit.cylinder(_viewmodel, 0.028, 0.22, Vector3(0, 0, 0.02), rubber, false, Vector3(90, 0, 0), -1.0, 8)
	BuildKit.cylinder(_viewmodel, 0.042, 0.07, Vector3(0, 0, -0.12), metal, false, Vector3(90, 0, 0), 0.03, 8)
	var lens := BuildKit.emissive_mat(Color(1.0, 0.95, 0.8), 2.0)
	BuildKit.cylinder(_viewmodel, 0.036, 0.005, Vector3(0, 0, -0.158), lens, false, Vector3(90, 0, 0), -1.0, 8)
	BuildKit.box(_viewmodel, Vector3(0.012, 0.015, 0.03), Vector3(0, 0.03, 0.0), metal, false)
	# Hand und Ärmel
	BuildKit.box(_viewmodel, Vector3(0.07, 0.06, 0.1), Vector3(0.0, -0.012, 0.05), skin, false, Vector3(0, 0, 10))
	BuildKit.box(_viewmodel, Vector3(0.1, 0.1, 0.3), Vector3(0.02, -0.04, 0.24), sleeve, false, Vector3(-8, 0, 0))
	# Schwaches Streulicht, damit Hand und Lampe im Dunkeln erkennbar bleiben
	var fill := OmniLight3D.new()
	fill.position = Vector3(-0.1, 0.12, -0.05)
	fill.omni_range = 0.5
	fill.light_energy = 0.35
	fill.light_color = Color(1.0, 0.92, 0.8)
	_viewmodel.add_child(fill)
	for mi in _viewmodel.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_viewmodel.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		if event is InputEventMouseButton and event.pressed:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			get_viewport().set_input_as_handled()
		return
	if input_locked:
		return
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * mouse_sensitivity)
		head.rotation.x = clampf(head.rotation.x - event.relative.y * mouse_sensitivity, -1.45, 1.45)
	elif event.is_action_pressed("interact"):
		if current_interactable:
			current_interactable.interact(self)
			_update_prompt(true)
	elif event.is_action_pressed("interact_secondary"):
		if current_interactable:
			current_interactable.secondary_interact(self)
			_update_prompt(true)
	elif event.is_action_pressed("flashlight"):
		set_flashlight(not flashlight.visible)


func set_flashlight(on: bool) -> void:
	flashlight.visible = on
	if _viewmodel:
		_viewmodel.visible = on


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta

	var crouching := not input_locked and Input.is_action_pressed("crouch")
	if not crouching and _height < STAND_HEIGHT and _blocked_above():
		crouching = true
	var target_h := CROUCH_HEIGHT if crouching else STAND_HEIGHT
	_height = move_toward(_height, target_h, delta * 4.0)
	_capsule.height = _height
	_shape.position.y = _height * 0.5

	var input := Vector2.ZERO
	if not input_locked:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		if Input.is_action_just_pressed("jump") and is_on_floor() and not crouching:
			velocity.y = jump_velocity
	var sprinting := not crouching and Input.is_action_pressed("sprint") and input.y < 0.0
	var speed := crouch_speed if crouching else (sprint_speed if sprinting else walk_speed)
	var dir := (transform.basis * Vector3(input.x, 0, input.y)).normalized()
	var accel := 10.0 if is_on_floor() else 2.0
	velocity.x = lerpf(velocity.x, dir.x * speed, clampf(accel * delta, 0.0, 1.0))
	velocity.z = lerpf(velocity.z, dir.z * speed, clampf(accel * delta, 0.0, 1.0))
	move_and_slide()

	# Kopfwippen beim Gehen
	var horizontal := Vector2(velocity.x, velocity.z).length()
	var bob := 0.0
	if is_on_floor() and horizontal > 0.3:
		_bob_time += delta * horizontal * 2.2
		bob = sin(_bob_time) * 0.035 * clampf(horizontal / walk_speed, 0.0, 1.5)
	head.position.y = lerpf(head.position.y, _height - EYE_OFFSET + bob, clampf(delta * 12.0, 0.0, 1.0))

	if global_position.y < -30.0:
		global_position = Vector3(-3.0, 1.0, 11.5)
		velocity = Vector3.ZERO

	_update_interaction()


func _process(delta: float) -> void:
	var target := camera.global_transform
	var t := clampf(delta * 14.0, 0.0, 1.0)
	_flashlight_rig.global_transform = Transform3D(
			_flashlight_rig.global_transform.basis.orthonormalized().slerp(target.basis.orthonormalized(), t),
			target.origin)


func _blocked_above() -> bool:
	var space := get_world_3d().direct_space_state
	var from := global_position + Vector3(0, _height, 0)
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3(0, STAND_HEIGHT - _height + 0.05, 0))
	query.exclude = [get_rid()]
	return not space.intersect_ray(query).is_empty()


func _update_interaction() -> void:
	var found: Interactable = null
	if not input_locked and _ray.is_colliding():
		var node: Node = _ray.get_collider() as Node
		while node != null and not (node is Interactable):
			node = node.get_parent()
		found = node as Interactable
	if found != current_interactable:
		current_interactable = found
	_update_prompt(false)


func _update_prompt(force: bool) -> void:
	var text := ""
	if current_interactable:
		text = current_interactable.get_prompt(self)
		var second := current_interactable.get_secondary_prompt(self)
		if second != "":
			text += "\n" + second
	if force or text != _last_prompt:
		_last_prompt = text
		EventBus.interaction_prompt_changed.emit(text)


## Für den späteren Save Manager.
func get_state() -> Dictionary:
	return {"position": global_position, "yaw": rotation.y, "pitch": head.rotation.x, "flashlight": flashlight.visible}
