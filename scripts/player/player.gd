class_name Player
extends CharacterBody3D
## First-Person-Steuerung (GDD 18.2): Gehen, Rennen, Ducken, Springen,
## Benutzen (E / R), Smartwatch-Lampe (F), Hände (Linksklick/Rechtsklick, 1–9, Mausrad).

@export var walk_speed: float = 3.0
@export var sprint_speed: float = 5.4
@export var crouch_speed: float = 1.6
@export var jump_velocity: float = 3.9
@export var mouse_sensitivity: float = 0.0022
@export var interact_distance: float = 2.4

const STAND_HEIGHT := 1.75
const CROUCH_HEIGHT := 1.05
const EYE_OFFSET := 0.13
## Langsames Gehen (Alt): Anteil der normalen Gehgeschwindigkeit
const SLOW_FACTOR := 0.42
const RADIUS := 0.32

var head: Node3D
var camera: Camera3D
var flashlight: SpotLight3D  ## LED der Smartwatch (linke Hand)
var hands: PlayerHands
var input_locked: bool = false
var health: float = 100.0
const MAX_HEALTH := 100.0
var current_interactable: Interactable = null
## Der Kollisionskörper, den das Fadenkreuz gerade trifft
var current_target_body: CollisionObject3D = null

var _ray: RayCast3D
var _shape: CollisionShape3D
var _capsule: CapsuleShape3D
var _height: float = STAND_HEIGHT
var _bob_time: float = 0.0
var _last_prompt: String = ""
var _gravity: float = 9.8
var _shake: float = 0.0
var _fear: float = 0.0
var _heart_timer: float = 0.0
var _exhausted: bool = false
## Gefahrenzone (z. B. Wucherung): 1 = stark verlangsamt; wird von außen gesetzt und klingt ab
var hazard: float = 0.0


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
	# Trugbilder (Ebene 2) sieht nur die Überwachungskamera, nicht der Spieler
	camera.cull_mask = 0xFFFFF & ~(1 << 1)

	_ray = RayCast3D.new()
	_ray.target_position = Vector3(0, 0, -interact_distance)
	_ray.add_exception(self)
	_ray.collide_with_areas = true
	camera.add_child(_ray)

	# Hände im Bild: rechts Faust/Gegenstand, links Smartwatch-Lampe und Bauhammer
	hands = PlayerHands.new()
	hands.player = self
	camera.add_child(hands)
	flashlight = hands.watch_light

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	EventBus.sleep_requested.connect(_on_sleep_requested)
	EventBus.sleep_finished.connect(_on_sleep_finished)
	EventBus.screen_shake.connect(_on_shake)


func _on_sleep_requested(_h: float) -> void:
	input_locked = true


func _on_shake(strength: float) -> void:
	_shake = maxf(_shake, strength)


func _on_sleep_finished() -> void:
	input_locked = false


## Im Versteck: umsehen ja, gehen nein. hidden_in = das Versteck, in dem man steht (oder null).
var look_only: bool = false
var hidden_in: Node = null
var _f_down: bool = false
var _f_held: float = 0.0
var _f_used: bool = false
const LIGHT_MODE_HOLD := 0.5  ## Sekunden F halten, um den Licht-Modus zu wechseln
var held_time: float = 0.0  ## Sekunden, die der Spieler festgehalten wird (Bärenfalle)


## Versteckt (im Schrank/Spind bei geschlossener Tür)?
func is_hidden() -> bool:
	return hidden_in != null and is_instance_valid(hidden_in) and hidden_in.call("hides_player")


func _unhandled_input(event: InputEvent) -> void:
	if look_only and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and event is InputEventMouseMotion:
		rotate_y(-event.relative.x * mouse_sensitivity)
		head.rotation.x = clampf(head.rotation.x - event.relative.y * mouse_sensitivity, -1.2, 1.2)
		return
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		if input_locked:
			return
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
		if _building():
			return
		if current_interactable:
			current_interactable.interact(self)
			_update_prompt(true)
	elif event.is_action_pressed("interact_secondary"):
		if _building():
			return
		if current_interactable:
			current_interactable.secondary_interact(self)
			_update_prompt(true)
	elif event.is_action_pressed("flashlight") and not event.is_echo():
		# kurz drücken = an/aus (beim Loslassen), gedrückt halten = Licht-Modus wechseln (siehe _process)
		_f_held = 0.0
		_f_down = true
		_f_used = false
	elif event.is_action_released("flashlight") and _f_down:
		_f_down = false
		if not _f_used and hidden_in == null:
			set_flashlight(not flashlight.visible)
			PlayerSounds.play(self, "flashlight", -6.0, randf_range(0.95, 1.05))


func _building() -> bool:
	var bc := get_tree().get_first_node_in_group("build_controller") as BuildController
	return bc != null and bc.active


func set_flashlight(on: bool) -> void:
	if on and hidden_in != null:
		return  # im Schrank geht kein Licht an
	hands.set_watch(on)


## F gedrückt halten: zwischen LED und weißem Display umschalten (nur wenn die Uhr leuchtet).
func _update_light_hold(delta: float) -> void:
	if not _f_down or _f_used:
		return
	if not Input.is_action_pressed("flashlight"):
		_f_down = false
		return
	_f_held += delta
	if _f_held >= LIGHT_MODE_HOLD and flashlight.visible and hidden_in == null:
		_f_used = true
		hands.toggle_screen_mode()
		PlayerSounds.play(self, "flashlight", -10.0, 1.3)
		EventBus.notify("Uhr: Display-Licht" if hands.screen_mode else "Uhr: LED-Lampe", 1.5)


func _physics_process(delta: float) -> void:
	_update_light_hold(delta)
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
			Footsteps.play_jump(get_parent(), global_position)
	# Sicherung gegen „hängende“ Shift-Taste: rennen nur, wenn Shift wirklich gerade gedrückt ist
	var shift_down := Input.is_physical_key_pressed(KEY_SHIFT) or Input.is_key_pressed(KEY_SHIFT)
	if Input.is_action_pressed("sprint") and not shift_down:
		Input.action_release("sprint")
	var slow := not input_locked and Input.is_action_pressed("walk_slow")
	var wants_sprint := not crouching and not slow and not Inventory.overloaded() and shift_down and Input.is_action_pressed("sprint") and input.y < 0.0 and not input_locked
	if Survival.stamina <= 0.0:
		_exhausted = true
	elif Survival.stamina > 30.0:
		_exhausted = false
	var sprinting := wants_sprint and not _exhausted and Survival.use_stamina(20.0 * delta)
	_update_breathing(sprinting)
	if not sprinting:
		Survival.regen_stamina((14.0 if input.length() < 0.1 else 9.0) * delta)
	var speed := crouch_speed if crouching else (sprint_speed if sprinting else walk_speed)
	# Alt gedrückt: langsam und leise gehen
	if slow and not crouching:
		speed = walk_speed * SLOW_FACTOR
	speed *= 1.0 - 0.55 * hazard
	hazard = move_toward(hazard, 0.0, delta * 3.0)
	# In der Falle: festgehalten, danach humpelt man kurz
	if held_time > 0.0:
		held_time -= delta
		speed = 0.0 if held_time > 0.0 else speed
	var dir := (transform.basis * Vector3(input.x, 0, input.y)).normalized()
	var accel := 10.0 if is_on_floor() else 2.0
	velocity.x = lerpf(velocity.x, dir.x * speed, clampf(accel * delta, 0.0, 1.0))
	velocity.z = lerpf(velocity.z, dir.z * speed, clampf(accel * delta, 0.0, 1.0))
	var fall_speed := -velocity.y
	var was_airborne := not is_on_floor()
	move_and_slide()
	# Landung nach Sprung oder Sturz, je nach Untergrund
	if was_airborne and is_on_floor() and fall_speed > 3.0:
		var extra := clampf((fall_speed - 3.0) * 1.5, 0.0, 6.0)
		Footsteps.play_landing(get_parent(), global_position, extra)

	# Kopfwippen beim Gehen
	var horizontal := Vector2(velocity.x, velocity.z).length()
	var bob := 0.0
	if is_on_floor() and horizontal > 0.3:
		var before := sin(_bob_time)
		_bob_time += delta * horizontal * 2.2
		bob = sin(_bob_time) * 0.035 * clampf(horizontal / walk_speed, 0.0, 1.5)
		# Ein Schritt bei jedem Nulldurchgang der Kopfbewegung (links, rechts)
		if signf(before) != signf(sin(_bob_time)):
			_footstep(horizontal, crouching)
	head.position.y = lerpf(head.position.y, _height - EYE_OFFSET + bob, clampf(delta * 12.0, 0.0, 1.0))
	_update_lean(delta)

	if global_position.y < -30.0:
		global_position = Vector3(-3.0, 1.0, 11.5)
		velocity = Vector3.ZERO

	_update_interaction()
	_update_mind(delta)
	var starve := Survival.starvation_damage()
	if starve > 0.0:
		health -= starve * delta
		if health <= 0.0 and not GameState.dead:
			GameState.kill_player()
	elif Survival.hunger > 30.0 and Survival.thirst > 30.0:
		health = minf(health + delta * 1.5, MAX_HEALTH)


## Um die Ecke lehnen: Y = links, X = rechts. Vor einer Wand lehnt man nur so weit, wie Platz ist.
var _lean: float = 0.0
const LEAN_OFFSET := 0.42
const LEAN_ROLL := 11.0


func _update_lean(delta: float) -> void:
	var want := 0.0
	if not input_locked and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if Input.is_key_pressed(KEY_Y):
			want -= 1.0
		if Input.is_key_pressed(KEY_X):
			want += 1.0
	_lean = move_toward(_lean, want, delta * 4.5)
	var room := LEAN_OFFSET
	if absf(_lean) > 0.01:
		var origin := global_position + Vector3(0, head.position.y, 0)
		var side := global_transform.basis.x * signf(_lean)
		var q := PhysicsRayQueryParameters3D.create(origin, origin + side * (LEAN_OFFSET + 0.2))
		q.exclude = [get_rid()]
		var hit := get_world_3d().direct_space_state.intersect_ray(q)
		if not hit.is_empty():
			room = clampf(origin.distance_to(hit["position"]) - 0.2, 0.0, LEAN_OFFSET)
	head.position.x = _lean * room
	head.rotation.z = -_lean * deg_to_rad(LEAN_ROLL) * (0.4 + 0.6 * room / LEAN_OFFSET)


func _process(delta: float) -> void:
	# Kamerawackeln
	_shake = move_toward(_shake, 0.0, delta * 1.5)
	camera.h_offset = randf_range(-1.0, 1.0) * _shake * 0.05
	camera.v_offset = randf_range(-1.0, 1.0) * _shake * 0.05
	# Angst: Herzschlag, wenn die Kreatur nah und sichtbar ist
	var target_fear := 0.0
	var c: Creature = ThreatDirector.creature if is_instance_valid(ThreatDirector.creature) else null
	if is_instance_valid(c):
		var d := c.global_position.distance_to(global_position)
		if d < 20.0 and c.is_in_player_view():
			target_fear = clampf(1.0 - d / 20.0, 0.2, 1.0)
		elif d < 8.0:
			target_fear = 0.4
	_fear = move_toward(_fear, target_fear, delta * (0.8 if target_fear > _fear else 0.15))
	if _fear > 0.05:
		_heart_timer -= delta
		if _heart_timer <= 0.0:
			_heart_timer = lerpf(1.1, 0.45, _fear)
			PlayerSounds.play(self, "heartbeat", lerpf(-14.0, 0.0, _fear), lerpf(0.95, 1.12, _fear))
	EventBus.fear_changed.emit(_fear)


func _footstep(speed: float, crouching: bool = false) -> void:
	var indoor := Cabin.is_inside(global_position) or Shed.is_inside(global_position) or global_position.y > 0.35
	var gait := "sneak" if crouching or speed < crouch_speed + 0.4 else ("run" if speed > walk_speed + 0.5 else "walk")
	Footsteps.play(get_parent(), global_position, gait)
	# Rennen draußen ist laut (GDD 9.4)
	if speed > walk_speed + 0.5 and not indoor:
		EventBus.noise_made.emit(global_position, 16.0)


## Außer Atem: nach langem Rennen schweres Atmen, bis die Ausdauer wieder da ist.
var _out_of_breath: bool = false
var _breath_player: AudioStreamPlayer = null


func _update_breathing(sprinting: bool) -> void:
	# setzt früh ein, bleibt aber zunächst leise und wird mit der Erschöpfung lauter
	if sprinting and Survival.stamina < 65.0:
		_out_of_breath = true
	elif Survival.stamina > 85.0 or GameState.dead:
		_out_of_breath = false
	if _out_of_breath and not is_instance_valid(_breath_player):
		var strength := 1.0 - clampf(Survival.stamina / 85.0, 0.0, 1.0)
		_breath_player = PlayerSounds.play_phrase(self, "breath", lerpf(-26.0, -10.0, strength), randf_range(3.0, 4.5))


## --- Blick der Kreatur ins Hirn -------------------------------------------
## Die Kreatur ruft mind_gaze() in jedem Physik-Schritt, solange der Spieler sie ansieht.
var mind: float = 0.0
var _gazed: bool = false
var _mind_audio: AudioStreamPlayer
var _mind_shown: float = -1.0


func mind_gaze() -> void:
	_gazed = true


func _update_mind(delta: float) -> void:
	var cfg := CreatureConfig.get_default()
	if _gazed and not GameState.dead:
		mind = minf(mind + delta / maxf(cfg.mind_rise_time, 0.1), 1.0)
	else:
		mind = maxf(mind - delta / maxf(cfg.mind_fall_time, 0.1), 0.0)
	_gazed = false
	if mind > 0.02 and not GameState.dead:
		health -= cfg.mind_damage_per_second * mind * delta
		_shake = maxf(_shake, mind * 0.25)
		if health <= 0.0:
			input_locked = true
			set_flashlight(false)
			GameState.kill_player()
	# Sichtfeld pumpt leicht mit
	camera.fov = 75.0 + sin(Time.get_ticks_msec() * 0.007) * 5.0 * mind
	if absf(mind - _mind_shown) > 0.005:
		_mind_shown = mind
		get_tree().call_group("retro_filter", "set_mind", mind)
	if _mind_audio == null:
		var st := CreatureSounds.pick("mind")
		if st == null:
			return
		if st is AudioStreamOggVorbis:
			st = st.duplicate()
			(st as AudioStreamOggVorbis).loop = true
		_mind_audio = AudioStreamPlayer.new()
		_mind_audio.stream = st
		_mind_audio.volume_db = -60.0
		add_child(_mind_audio)
	if mind > 0.01:
		if not _mind_audio.playing:
			_mind_audio.play()
		_mind_audio.volume_db = linear_to_db(clampf(mind * 1.2, 0.001, 1.0)) + 2.0
	elif _mind_audio.playing:
		_mind_audio.stop()


## Leuchtet die Uhr-Lampe gerade wirklich (nicht nur eingeschaltet, sondern nicht gestört)?
func light_shining() -> bool:
	return flashlight.visible and hands.light_shining()


func take_damage(amount: float, from: Vector3) -> void:
	if GameState.dead:
		return
	var f := hands.block_factor(from)
	if f < 1.0:
		amount *= f
		SoundBank.play_ui(self, "thud", -4.0, 0.8)
	health -= amount
	EventBus.player_hurt.emit(amount)
	SoundBank.play_ui(self, "hurt", -2.0, randf_range(0.9, 1.1))
	var push := global_position - from
	push.y = 0.0
	velocity += push.normalized() * 4.0 + Vector3(0, 2.0, 0)
	if health <= 0.0:
		input_locked = true
		set_flashlight(false)
		GameState.kill_player()


func _blocked_above() -> bool:
	var space := get_world_3d().direct_space_state
	var from := global_position + Vector3(0, _height, 0)
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3(0, STAND_HEIGHT - _height + 0.05, 0))
	query.exclude = [get_rid()]
	return not space.intersect_ray(query).is_empty()


func _update_interaction() -> void:
	var found: Interactable = null
	var body: CollisionObject3D = null
	if not input_locked and _ray.is_colliding():
		body = _ray.get_collider() as CollisionObject3D
		var node: Node = body
		while node != null and not (node is Interactable):
			node = node.get_parent()
		found = node as Interactable
	if found != current_interactable:
		current_interactable = found
	current_target_body = body if found else null
	_update_prompt(false)


## Wohin schaut der Spieler gerade? {"position", "normal"} oder leer.
func aim_point() -> Dictionary:
	if _ray and _ray.is_colliding():
		return {"position": _ray.get_collision_point(), "normal": _ray.get_collision_normal()}
	return {}


## Gibt es gerade etwas Benutzbares im Fadenkreuz? (für den feinen Rahmen im HUD)
func has_usable_target() -> bool:
	return current_interactable != null and is_instance_valid(current_target_body) and _last_prompt != "" and not _building()


func _update_prompt(force: bool) -> void:
	if _building():
		return
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
