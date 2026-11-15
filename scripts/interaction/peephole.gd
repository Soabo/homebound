class_name Peephole
extends Interactable
## Türspion in der Haustür (Christian 15.11.: „Lass dir was einfallen, was man da ab und zu sieht.“).
## E von innen = durch die Linse schauen (Fischauge), E/Esc = zurücktreten. Meist ist die Veranda leer.
## Nachts ab ThreatConfig.peephole_from_night manchmal (peephole_scare_chance, höchstens peephole_max_per_night):
##   eye    – ein Auge direkt vor der Linse, das zurückweicht
##   figure – es steht unten an der Verandatreppe und schaut zur Tür; beim zweiten Hinsehen ist es weg … und klopft
##   back   – es steht ganz nah mit dem Rücken zur Tür, der Kopf dreht sich langsam herum
##   dark   – etwas hält die Linse zu, man hört es atmen, dann klopft es dreimal
## Tagsüber selten (peephole_day_chance, ab Nacht 6): eine Gestalt steht reglos am Tor.

static var current: Peephole = null
static var _night_key: int = -1
static var _night_count: int = 0
static var _figure_waiting: bool = false

var door: Door
var _cam: Camera3D
var _overlay: CanvasLayer
var _mat: ShaderMaterial
var _scare: Node3D
var _kind := ""
var _opened_msec := 0
var _t := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	add_to_group("esc_close")
	var brass := BuildKit.color_mat(Color(0.55, 0.45, 0.25), 0.35, 0.8)
	var t := door.thickness if door else 0.07
	for side: float in [-1.0, 1.0]:
		BuildKit.cylinder(self, 0.024, 0.012, Vector3(0, 0, side * (t * 0.5 + 0.005)), brass, false, Vector3(90, 0, 0), -1.0, 10)
		BuildKit.cylinder(self, 0.011, 0.014, Vector3(0, 0, side * (t * 0.5 + 0.007)), BuildKit.color_mat(Color(0.05, 0.06, 0.07), 0.1, 0.5), false, Vector3(90, 0, 0), -1.0, 8)
	# kleiner Treffkörper, damit man den Spion gezielt anschauen kann
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.16, 0.16, t + 0.03)
	cs.shape = shape
	body.add_child(cs)
	add_child(body)


func get_prompt(player: Node) -> String:
	if door == null or door.is_open or door.is_broken() or not Cabin.is_inside((player as Node3D).global_position):
		return ""
	return "Türspion  [E] hindurchsehen"


func interact(player: Node) -> void:
	if current != null or door.is_open:
		return
	_open(player as Player)


# --- Blick durch die Linse ---------------------------------------------------------

func _out_dir() -> Vector3:
	var z := door.global_basis.z
	z.y = 0.0
	return z.normalized()


func _open(player: Player) -> void:
	current = self
	_opened_msec = Time.get_ticks_msec()
	_t = 0.0
	player.input_locked = true
	var out := _out_dir()
	_cam = Camera3D.new()
	_cam.fov = 118.0
	_cam.near = 0.02
	_cam.far = 400.0
	_cam.cull_mask = player.camera.cull_mask & ~PlayerHands.HANDS_LAYER
	get_tree().current_scene.add_child(_cam)
	_cam.global_position = global_position + out * 0.06
	_cam.look_at(_cam.global_position + out, Vector3.UP)
	_cam.make_current()
	_overlay = CanvasLayer.new()
	_overlay.layer = 60
	add_child(_overlay)
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://shaders/peephole.gdshader")
	var vs := get_viewport().get_visible_rect().size
	_mat.set_shader_parameter("aspect", vs.x / maxf(vs.y, 1.0))
	rect.material = _mat
	_overlay.add_child(rect)
	var hint := Label.new()
	hint.text = "E / Esc  zurücktreten"
	hint.add_theme_font_size_override("font_size", 20)
	hint.add_theme_color_override("font_color", Color(0.75, 0.72, 0.65, 0.8))
	hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hint.offset_top = -50
	hint.offset_left = -120
	_overlay.add_child(hint)
	SoundBank.play_at(get_tree().current_scene, "door_creak" if SoundBank.has_recording("door_creak") else "board_creak", global_position, -16.0, 1.4)
	_kind = _pick_scare()
	_start_scare()


func close() -> void:
	if current != self:
		return
	current = null
	if _scare and is_instance_valid(_scare):
		_scare.queue_free()
	_scare = null
	if _cam:
		_cam.queue_free()
	_cam = null
	if _overlay:
		_overlay.queue_free()
	_overlay = null
	var player := get_tree().get_first_node_in_group("player") as Player
	if player:
		player.camera.make_current()
		player.input_locked = false
	# Wer die Gestalt an der Treppe gesehen hat: kurz darauf klopft es
	if _kind == "figure":
		_figure_waiting = true
		get_tree().create_timer(_rng.randf_range(4.0, 8.0)).timeout.connect(_knock.bind(3))
	_kind = ""


## Für die Pause-Taste (Esc): erst den Türspion schließen.
func esc_close() -> bool:
	if current == self:
		close()
		return true
	return false


func _unhandled_input(event: InputEvent) -> void:
	if current != self or Time.get_ticks_msec() - _opened_msec < 250:
		return
	if event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		close()


func _process(delta: float) -> void:
	if current != self:
		return
	_t += delta
	if _mat:
		_mat.set_shader_parameter("time", _t)
	var player := get_tree().get_first_node_in_group("player") as Player
	if player == null or GameState.dead or door.is_open or door.is_broken():
		close()
		return
	_update_scare(delta)


# --- Was man sieht ----------------------------------------------------------------

func _cfg() -> ThreatConfig:
	return ThreatDirector.config


func _pick_scare() -> String:
	var night := ThreatDirector.current_night()
	if _night_key != night:
		_night_key = night
		_night_count = 0
	# Wer die Gestalt an der Treppe gesehen hat, sieht beim zweiten Mal: nichts.
	if _figure_waiting:
		_figure_waiting = false
		return ""
	if not TimeManager.is_night():
		if night >= 6 and _rng.randf() < _cfg().peephole_day_chance:
			return "far"
		return ""
	if night < _cfg().peephole_from_night or _night_count >= _cfg().peephole_max_per_night:
		return ""
	if _rng.randf() >= _cfg().peephole_scare_chance:
		return ""
	_night_count += 1
	var w: Dictionary = _cfg().peephole_weights
	var total := 0.0
	for k: String in w:
		total += float(w[k])
	var r := _rng.randf() * total
	for k: String in w:
		r -= float(w[k])
		if r <= 0.0:
			return k
	return "eye"


func _ground_ahead(d: float) -> Vector3:
	var p := global_position + _out_dir() * d
	p.y = Cabin.FLOOR_Y if d < 2.5 else Terrain.height_at(p.x, p.z)   # nah = Veranda
	return p


func _creature_at(at: Vector3, facing_door: bool) -> Dictionary:
	_scare = Node3D.new()
	get_tree().current_scene.add_child(_scare)
	_scare.global_position = at
	var parts := CreatureModel.build(_scare)
	var target := global_position
	target.y = at.y
	if facing_door:
		_scare.look_at(target, Vector3.UP)
	else:
		_scare.look_at(at + (at - target), Vector3.UP)
	# schwaches Gegenlicht, damit man im Dunkeln die Umrisse sieht
	var rim := OmniLight3D.new()
	rim.light_color = Color(0.55, 0.65, 0.75)
	rim.light_energy = 0.5
	rim.omni_range = 3.5
	_scare.add_child(rim)
	rim.position = Vector3(0, 2.0, 1.2)
	return parts


var _parts: Dictionary = {}


func _start_scare() -> void:
	_parts = {}
	var scene := get_tree().current_scene
	match _kind:
		"eye":
			_scare = Node3D.new()
			scene.add_child(_scare)
			_scare.global_position = global_position + _out_dir() * 0.2
			_scare.look_at(global_position, Vector3.UP)
			var white := BuildKit.color_mat(Color(0.78, 0.74, 0.62), 0.15)
			var iris := BuildKit.color_mat(Color(0.12, 0.2, 0.14), 0.1)
			var pupil := BuildKit.color_mat(Color(0.0, 0.0, 0.0), 0.05)
			BuildKit.sphere(_scare, 0.16, Vector3.ZERO, white, Vector3.ONE, 16)
			BuildKit.sphere(_scare, 0.075, Vector3(0, 0, -0.11), iris, Vector3(1, 1, 0.5), 14)
			_parts["pupil"] = BuildKit.sphere(_scare, 0.04, Vector3(0, 0, -0.135), pupil, Vector3(1, 1, 0.4), 12)
			var l := OmniLight3D.new()
			l.light_energy = 0.35
			l.omni_range = 1.0
			_scare.add_child(l)
			l.position = Vector3(0, 0.2, -0.4)
			CreatureSounds.play(scene, "breath", global_position + _out_dir() * 0.3, -2.0)
		"figure":
			_creature_at(_ground_ahead(4.2), true)
		"back":
			_parts = _creature_at(_ground_ahead(0.9), false)
			CreatureSounds.play(scene, "click", global_position + _out_dir(), -8.0)
		"dark":
			CreatureSounds.play(scene, "breath", global_position + _out_dir() * 0.3, 0.0, 0.85)
		"far":
			_creature_at(Vector3(-3.0, Terrain.height_at(-3.0, 18.5), 18.5), true)


func _update_scare(_delta: float) -> void:
	match _kind:
		"eye":
			if _parts.has("pupil"):
				var s := 1.0 + sin(_t * 9.0) * 0.08 - clampf(_t - 0.6, 0.0, 0.6)
				(_parts["pupil"] as Node3D).scale = Vector3(s, s, 0.4).max(Vector3(0.3, 0.3, 0.4))
			if _t > 2.0 and _scare:
				_scare.global_position += _out_dir() * 3.0 * _delta
			if _t > 2.6 and _scare:
				_scare.queue_free()
				_scare = null
				_parts.clear()
		"back":
			# der Kopf dreht sich langsam um – bis er durch die Linse schaut
			var head := _parts.get("head") as Node3D
			if head:
				head.rotation.y = lerpf(0.0, PI * 0.85, smoothstep(1.5, 6.0, _t))
		"dark":
			_mat.set_shader_parameter("darkness", 0.97 if _t < 3.4 else clampf(0.97 - (_t - 3.4) * 1.2, 0.0, 0.97))
			if _t > 3.0 and not _parts.has("knocked"):
				_parts["knocked"] = true
				_knock(3)


func _knock(n: int) -> void:
	if not is_inside_tree():
		return
	var scene := get_tree().current_scene
	for k in n:
		get_tree().create_timer(k * 0.75).timeout.connect(func() -> void:
			if is_inside_tree():
				SoundBank.play_at(scene, "knock", global_position, -2.0, 0.75))
	EventBus.screen_shake.emit(0.15)
