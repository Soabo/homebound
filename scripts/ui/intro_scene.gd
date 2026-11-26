class_name IntroScene
extends Node3D
## Spielbares Intro (Christian 26.11.): Christian sitzt abends im Büro, draußen Regen. Das Handy klingelt – Stefanie.
## Man nimmt selbst ab [E], wählt zweimal eine Antwort (1/2), hört im Dunkeln den Unfall, die Uhr springt,
## das Handy vibriert: die Polizei. Danach Zeilen auf Schwarz in Schreibmaschine (Unfall, Beerdigung, Rückzug,
## die Hütte). Texte: data/story/intro.json. Esc halten = überspringen. Am Ende GameState.finish_intro().

enum Step { WAIT, RING, CALL, AFTER, CRASH, RING2, POLICE, EPILOGUE, DONE }

const SEAT := Vector3(0.0, 1.18, 0.38)
const PHONE_POS := Vector3(0.36, 0.79, -0.42)
const SKIP_HOLD := 1.2

static var preview_step := -1   ## Vorschaubilder: direkt in einen Abschnitt springen

var data: Dictionary
var step: int = Step.WAIT
var _cam: Camera3D
var _yaw := 0.0
var _pitch := -0.18
var _t := 0.0
var _phone_screen: StandardMaterial3D
var _phone_text: Label3D
var _clock3d: Label3D
var _window_mat: StandardMaterial3D
var _lamp: OmniLight3D

# Bildschirm
var _ui: CanvasLayer
var _fade: ColorRect
var _prompt: Label
var _who: Label
var _line: Label
var _thought: Label
var _choices: VBoxContainer
var _epi: Label
var _skip: Label
var _skip_t := 0.0

# Ton
var _rain: AudioStreamPlayer
var _ring: AudioStreamPlayer
var _buzz: AudioStreamPlayer

var _lines: Array = []
var _li := -1
var _line_t := 0.0
var _choice_wait := false
var _flash_t := 6.0


func _ready() -> void:
	data = DataDB.load_json("res://data/story/intro.json")
	_build_room()
	_build_ui()
	_build_sound()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	get_tree().paused = false
	_fade.color.a = 1.0
	create_tween().tween_property(_fade, "color:a", 0.0, 2.5)
	if preview_step >= 0:
		_fade.color.a = 0.0
		_set_step(preview_step)


# --- Raum ---------------------------------------------------------------------------------

func _build_room() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0, 0, 0)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.28, 0.32, 0.4)
	e.ambient_light_energy = 0.18
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.glow_enabled = true
	e.glow_intensity = 0.6
	env.environment = e
	add_child(env)

	var wall := BuildKit.color_mat(Color(0.2, 0.2, 0.21), 0.95)
	var floor_m := BuildKit.color_mat(Color(0.12, 0.12, 0.13), 0.9)
	var desk := BuildKit.color_mat(Color(0.32, 0.24, 0.17), 0.7)
	var black := BuildKit.color_mat(Color(0.03, 0.03, 0.035), 0.4)
	var grey := BuildKit.color_mat(Color(0.35, 0.35, 0.37), 0.6)
	var paper := BuildKit.color_mat(Color(0.82, 0.8, 0.74), 0.95)

	# Büro: Boden, Decke, Wände, Fenster hinter dem Schreibtisch
	BuildKit.box_mm(self, Vector3(-2.2, -0.05, -1.4), Vector3(2.2, 0.0, 2.0), floor_m, false)
	BuildKit.box_mm(self, Vector3(-2.2, 2.7, -1.4), Vector3(2.2, 2.75, 2.0), wall, false)
	BuildKit.box_mm(self, Vector3(-2.3, 0, -1.4), Vector3(-2.2, 2.7, 2.0), wall, false)
	BuildKit.box_mm(self, Vector3(2.2, 0, -1.4), Vector3(2.3, 2.7, 2.0), wall, false)
	BuildKit.box_mm(self, Vector3(-2.2, 0, 2.0), Vector3(2.2, 2.7, 2.1), wall, false)
	BuildKit.box_mm(self, Vector3(-2.2, 0, -1.5), Vector3(2.2, 0.95, -1.4), wall, false)
	BuildKit.box_mm(self, Vector3(-2.2, 2.25, -1.5), Vector3(2.2, 2.7, -1.4), wall, false)
	BuildKit.box_mm(self, Vector3(-2.2, 0.95, -1.5), Vector3(-1.3, 2.25, -1.4), wall, false)
	BuildKit.box_mm(self, Vector3(1.3, 0.95, -1.5), Vector3(2.2, 2.25, -1.4), wall, false)
	# Nachtstadt hinter nassem Glas
	_window_mat = BuildKit.emissive_mat(Color(0.05, 0.07, 0.12), 0.6)
	BuildKit.box_mm(self, Vector3(-1.3, 0.95, -1.6), Vector3(1.3, 2.25, -1.58), _window_mat, false)
	var lights := BuildKit.emissive_mat(Color(1.0, 0.75, 0.4), 1.6)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1842
	for i in 26:
		var p := Vector3(rng.randf_range(-1.25, 1.25), rng.randf_range(1.0, 1.55), -1.57)
		BuildKit.box(self, Vector3(0.012, 0.012, 0.004), p, lights, false)
	BuildKit.box_mm(self, Vector3(-0.02, 0.95, -1.47), Vector3(0.02, 2.25, -1.44), grey, false)   # Fenstersprosse
	_build_rain()

	# Schreibtisch
	BuildKit.box_mm(self, Vector3(-0.95, 0.74, -1.0), Vector3(0.95, 0.78, -0.2), desk, false)
	for x in [-0.9, 0.9]:
		BuildKit.box_mm(self, Vector3(x - 0.03, 0, -0.95), Vector3(x + 0.03, 0.74, -0.25), black, false)
	# Bildschirm mit Tabelle und Uhr
	BuildKit.box(self, Vector3(0.64, 0.4, 0.03), Vector3(-0.12, 1.08, -0.82), black, false)
	BuildKit.box(self, Vector3(0.05, 0.22, 0.05), Vector3(-0.12, 0.88, -0.84), black, false)
	var screen := BuildKit.emissive_mat(Color(0.2, 0.24, 0.32), 0.3)
	BuildKit.box(self, Vector3(0.6, 0.36, 0.004), Vector3(-0.12, 1.08, -0.804), screen, false)
	var row := BuildKit.emissive_mat(Color(0.55, 0.68, 0.85), 0.55)
	for i in 9:
		BuildKit.box(self, Vector3(0.52, 0.012, 0.002), Vector3(-0.12, 1.21 - i * 0.031, -0.8), row, false)
	_clock3d = _label3d(data.get("office_clock", "18:39"), Vector3(0.12, 0.925, -0.798), 0.016, Color(0.85, 0.9, 1.0))
	var mon_light := OmniLight3D.new()
	mon_light.light_color = Color(0.65, 0.75, 0.95)
	mon_light.light_energy = 0.45
	mon_light.omni_range = 1.6
	mon_light.position = Vector3(-0.12, 1.08, -0.6)
	add_child(mon_light)
	# Tastatur, Becher, Papierstapel, Ordner
	BuildKit.box(self, Vector3(0.44, 0.018, 0.14), Vector3(-0.12, 0.789, -0.48), grey, false)
	BuildKit.cylinder(self, 0.04, 0.1, Vector3(-0.62, 0.83, -0.5), BuildKit.color_mat(Color(0.55, 0.14, 0.12), 0.5), false)
	for i in 6:
		BuildKit.box(self, Vector3(0.21, 0.004, 0.297), Vector3(0.62 + rng.randf_range(-0.01, 0.01), 0.782 + i * 0.005, -0.7), paper, false, Vector3(0, rng.randf_range(-6, 6), 0))
	BuildKit.box(self, Vector3(0.06, 0.3, 0.24), Vector3(0.85, 0.93, -0.92), BuildKit.color_mat(Color(0.15, 0.25, 0.45), 0.7), false)
	# Schreibtischlampe
	BuildKit.cylinder(self, 0.07, 0.02, Vector3(0.72, 0.79, -0.3), black, false)
	BuildKit.cylinder(self, 0.008, 0.36, Vector3(0.72, 0.97, -0.34), black, false, Vector3(-12, 0, 0))
	BuildKit.cylinder(self, 0.05, 0.08, Vector3(0.72, 1.14, -0.42), black, false, Vector3(-60, 0, 0), 0.02)
	_lamp = OmniLight3D.new()
	_lamp.light_color = Color(1.0, 0.78, 0.5)
	_lamp.light_energy = 1.4
	_lamp.omni_range = 2.6
	_lamp.shadow_enabled = true
	_lamp.position = Vector3(0.68, 1.06, -0.48)
	add_child(_lamp)
	# Handy: liegt flach, Display leuchtet beim Klingeln
	BuildKit.box(self, Vector3(0.078, 0.009, 0.158), PHONE_POS, black, false)
	_phone_screen = BuildKit.emissive_mat(Color(0.02, 0.02, 0.02), 0.0)
	_phone_screen = _phone_screen.duplicate() as StandardMaterial3D
	BuildKit.box(self, Vector3(0.07, 0.002, 0.148), PHONE_POS + Vector3(0, 0.0055, 0), _phone_screen, false)
	_phone_text = _label3d("", PHONE_POS + Vector3(0, 0.008, 0.01), 0.0045, Color(0.95, 0.95, 0.95))
	_phone_text.rotation_degrees = Vector3(-90, 0, 0)

	_cam = Camera3D.new()
	_cam.fov = 62
	_cam.position = SEAT
	add_child(_cam)
	_apply_look()


func _label3d(text: String, pos: Vector3, px: float, col: Color) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = UiStyle.font("ui_bold")
	l.font_size = 64
	l.pixel_size = px / 64.0 * 2.0
	l.modulate = col
	l.outline_size = 0
	l.position = pos
	l.shaded = false
	add_child(l)
	return l


func _build_rain() -> void:
	var p := CPUParticles3D.new()
	p.amount = 500
	p.lifetime = 0.6
	p.position = Vector3(0, 2.6, -2.6)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(3.0, 0.1, 0.8)
	p.direction = Vector3(0.08, -1, 0)
	p.spread = 3.0
	p.initial_velocity_min = 7.0
	p.initial_velocity_max = 9.0
	p.gravity = Vector3(0, -6, 0)
	var m := BoxMesh.new()
	m.size = Vector3(0.006, 0.18, 0.006)
	var mat := BuildKit.emissive_mat(Color(0.55, 0.62, 0.75), 0.35)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.6, 0.7, 0.85, 0.35)
	m.material = mat
	p.mesh = m
	add_child(p)


# --- Bildschirm und Ton ------------------------------------------------------------------

func _build_ui() -> void:
	_ui = CanvasLayer.new()
	add_child(_ui)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(root)
	_prompt = UiStyle.label(root, "ui_bold", 26, UiStyle.INK)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.anchor_right = 1.0
	_prompt.anchor_top = 0.56
	_prompt.anchor_bottom = 0.56
	var sub := VBoxContainer.new()
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sub.anchor_left = 0.18
	sub.anchor_right = 0.82
	sub.anchor_top = 0.74
	sub.anchor_bottom = 0.74
	sub.add_theme_constant_override("separation", 4)
	root.add_child(sub)
	_who = UiStyle.label(sub, "ui_bold", 20, UiStyle.EMBER)
	_who.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_line = UiStyle.label(sub, "ui", 32, UiStyle.INK)
	_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_thought = UiStyle.label(root, "thought", 40, UiStyle.INK)
	_thought.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_thought.anchor_right = 1.0
	_thought.anchor_top = 0.68
	_thought.anchor_bottom = 0.68
	_choices = VBoxContainer.new()
	_choices.anchor_left = 0.25
	_choices.anchor_right = 0.75
	_choices.anchor_top = 0.72
	_choices.anchor_bottom = 0.72
	_choices.add_theme_constant_override("separation", 10)
	root.add_child(_choices)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 1)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(_fade)
	_epi = UiStyle.label(root, "type", 34, UiStyle.INK, "")
	_epi.add_theme_constant_override("outline_size", 0)
	_epi.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_epi.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_epi.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_epi.anchor_left = 0.2
	_epi.anchor_right = 0.8
	_epi.anchor_top = 0.3
	_epi.anchor_bottom = 0.7
	_epi.visible_ratio = 0.0
	_skip = UiStyle.label(root, "ui", 16, UiStyle.INK_DIM, String(data.get("skip_hint", "")))
	_skip.anchor_left = 1.0
	_skip.anchor_right = 1.0
	_skip.anchor_top = 1.0
	_skip.anchor_bottom = 1.0
	_skip.offset_left = -380
	_skip.offset_right = -30
	_skip.offset_top = -46
	_skip.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT


func _build_sound() -> void:
	_rain = _player(SoundBank.get_sound("rain"), -15.0)
	_rain.play()
	var hum := _player(SoundBank.get_sound("light_buzz"), -32.0)
	hum.play()
	_ring = _player(_ringtone(), -8.0)
	_buzz = _player(_vibrate(), -10.0)


func _player(s: AudioStream, db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = s
	p.volume_db = db
	add_child(p)
	return p


## Klingelton: kleine Marimba-Melodie, dann Pause (Schleife).
static func _ringtone() -> AudioStreamWAV:
	var rate := SoundBank.RATE
	var notes := [659.3, 830.6, 987.8, 1318.5, 987.8, 1318.5]
	var b := PackedFloat32Array()
	b.resize(int(rate * 2.4))
	for n in notes.size():
		var start := int(rate * 0.17 * n)
		for i in int(rate * 0.5):
			if start + i >= b.size():
				break
			var t := float(i) / rate
			var f: float = notes[n]
			b[start + i] += (sin(TAU * f * t) + 0.35 * sin(TAU * f * 4.0 * t) * exp(-t * 30.0)) * exp(-t * 9.0) * 0.32
	return SoundBank._to_wav(b, true)


## Vibrieren auf der Tischplatte: tiefes Brummen in Stößen.
static func _vibrate() -> AudioStreamWAV:
	var rate := SoundBank.RATE
	var b := PackedFloat32Array()
	b.resize(int(rate * 2.0))
	var r := RandomNumberGenerator.new()
	r.seed = 7
	for i in b.size():
		var t := float(i) / rate
		var on := 1.0 if fmod(t, 1.0) < 0.45 else 0.0
		b[i] = on * (signf(sin(TAU * 165.0 * t)) * 0.25 + (r.randf() - 0.5) * 0.15) * (0.6 + 0.4 * sin(TAU * 31.0 * t))
	return SoundBank._to_wav(b, true)


## Reifen auf nasser Straße: rauschendes Kreischen, das ansteigt und abreißt.
static func _skid() -> AudioStreamWAV:
	var rate := SoundBank.RATE
	var b := PackedFloat32Array()
	b.resize(int(rate * 1.4))
	var r := RandomNumberGenerator.new()
	r.seed = 99
	var lp := 0.0
	for i in b.size():
		var t := float(i) / rate
		var k := t / 1.4
		lp = lerpf(lp, r.randf() - 0.5, 0.35)
		var tone := sin(TAU * (900.0 + 500.0 * k) * t + 3.0 * sin(TAU * 7.0 * t))
		b[i] = (lp * 0.5 + tone * 0.18) * smoothstep(0.0, 0.25, k) * (1.0 - smoothstep(0.85, 1.0, k))
	return SoundBank._to_wav(b, false)


# --- Ablauf ------------------------------------------------------------------------------

func _set_step(s: int) -> void:
	step = s
	_t = 0.0
	match s:
		Step.RING:
			_phone_text.text = String(data.get("caller", ""))
			_ring.play()
		Step.CALL:
			_ring.stop()
			SoundBank.play_ui(self, "switch", -12.0)
			_phone_text.text = "Anruf · 0:00"
			_start_lines(Array(data.get("call", [])))
		Step.AFTER:
			_phone_text.text = "Anruf beendet"
			_show_thought(String(data.get("after_call", "")))
		Step.CRASH:
			var tw := create_tween()
			tw.tween_property(_fade, "color:a", 1.0, 1.5)
			tw.tween_interval(1.2)
			tw.tween_callback(func() -> void:
				var p := _player(_skid(), -6.0)
				p.play())
			tw.tween_interval(1.25)
			tw.tween_callback(func() -> void:
				SoundBank.play_ui(self, "bang", 0.0)
				SoundBank.play_ui(self, "glass_break", -3.0)
				_rain.volume_db = -60.0)
			tw.tween_interval(0.25)
			tw.tween_callback(func() -> void: SoundBank.play_ui(self, "thud", -2.0))
			tw.tween_interval(3.2)
			tw.tween_callback(func() -> void:
				_rain.volume_db = -15.0
				_clock3d.text = String(data.get("later_clock", "19:58"))
				_phone_text.text = String(data.get("police_caller", ""))
				_set_step(Step.RING2))
			tw.tween_property(_fade, "color:a", 0.0, 1.5)
		Step.RING2:
			_buzz.play()
		Step.POLICE:
			_buzz.stop()
			_phone_text.text = "Anruf · 0:00"
			_start_lines(Array(data.get("police", [])))
		Step.EPILOGUE:
			_who.text = ""
			_line.text = ""
			_prompt.text = ""
			_epilogue()


func _process(delta: float) -> void:
	_t += delta
	_update_skip(delta)
	if step == Step.EPILOGUE or step == Step.DONE:
		return
	_flash(delta)
	match step:
		Step.WAIT:
			if _t > 3.0:
				_set_step(Step.RING)
		Step.RING, Step.RING2:
			var pulse := 0.5 + 0.5 * sin(_t * 7.0)
			_phone_screen.emission = Color(0.55, 0.85, 0.7) if step == Step.RING else Color(0.8, 0.82, 0.9)
			_phone_screen.emission_energy_multiplier = 0.6 + 1.4 * pulse
			var looking := _looking_at_phone()
			_prompt.text = "[E] Abnehmen" if looking or _t > 14.0 else ""
			if _t > 9.0 and _t - delta <= 9.0:
				_show_thought("Das Handy.")
		Step.CALL, Step.POLICE:
			_phone_screen.emission_energy_multiplier = 0.5
			_update_lines(delta)
		Step.AFTER:
			_phone_screen.emission_energy_multiplier = maxf(0.0, 0.5 - _t * 0.2)
			if _t > 3.5:
				_set_step(Step.CRASH)


func _looking_at_phone() -> bool:
	var to := (PHONE_POS - _cam.global_position).normalized()
	return (-_cam.global_transform.basis.z).dot(to) > cos(deg_to_rad(16.0))


func _flash(delta: float) -> void:
	_flash_t -= delta
	if _flash_t <= 0.0:
		_flash_t = randf_range(9.0, 16.0)
		var tw := create_tween()
		tw.tween_property(_window_mat, "emission_energy_multiplier", 6.0, 0.05)
		tw.tween_property(_window_mat, "emission_energy_multiplier", 0.6, 0.5)
		get_tree().create_timer(randf_range(1.0, 2.5)).timeout.connect(func() -> void: SoundBank.play_ui(self, "thunder", -14.0))


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and step != Step.EPILOGUE:
		var mm := event as InputEventMouseMotion
		var sens := 0.0025 * Settings.mouse
		_yaw = clampf(_yaw - mm.relative.x * sens, -1.2, 1.2)
		_pitch = clampf(_pitch - mm.relative.y * sens, -0.7, 0.5)
		_apply_look()
		return
	var pressed := event.is_action_pressed("interact") or event.is_action_pressed("jump") \
			or (event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT)
	if (step == Step.RING or step == Step.RING2) and pressed and (_looking_at_phone() or _t > 14.0):
		_set_step(Step.CALL if step == Step.RING else Step.POLICE)
		get_viewport().set_input_as_handled()
		return
	if (step == Step.CALL or step == Step.POLICE) and not _choice_wait and pressed and _line_t > 0.6:
		_next_line()   # Zeile weiterklicken
		return
	if _choice_wait and event is InputEventKey and (event as InputEventKey).pressed:
		var k := (event as InputEventKey).physical_keycode
		if k == KEY_1 or k == KEY_2:
			_pick(0 if k == KEY_1 else 1)


func _apply_look() -> void:
	_cam.rotation = Vector3(_pitch, _yaw, 0.0)


func _show_thought(text: String) -> void:
	_thought.text = text
	var tw := create_tween()
	_thought.modulate.a = 0.0
	tw.tween_property(_thought, "modulate:a", 1.0, 0.6)
	tw.tween_interval(2.6)
	tw.tween_property(_thought, "modulate:a", 0.0, 0.8)


# --- Gespräch ----------------------------------------------------------------------------

func _start_lines(lines: Array) -> void:
	_lines = lines
	_li = -1
	_next_line()


func _next_line() -> void:
	_li += 1
	_line_t = 0.0
	if _li >= _lines.size():
		_who.text = ""
		_line.text = ""
		_set_step(Step.AFTER if step == Step.CALL else Step.EPILOGUE)
		return
	var ln: Dictionary = _lines[_li]
	if ln.has("choice"):
		_ask(Array(ln["choice"]))
		return
	_who.text = String(ln.get("who", "")).to_upper()
	_line.text = String(ln.get("text", ""))
	_who.add_theme_color_override("font_color", UiStyle.INK_DIM if _who.text == "CHRISTIAN" else UiStyle.EMBER)
	UiStyle.fade_in(_line, 0.3, 4.0)


func _update_lines(delta: float) -> void:
	if _choice_wait or _li < 0 or _li >= _lines.size():
		return
	_line_t += delta
	_phone_text.text = "Anruf · 0:%02d" % mini(59, int(_t))
	var text := _line.text
	if _line_t > 1.6 + text.length() / 15.0:
		_next_line()


func _ask(options: Array) -> void:
	_choice_wait = true
	_who.text = ""
	_line.text = ""
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for i in options.size():
		var b := Button.new()
		b.text = "%d   %s" % [i + 1, String(options[i])]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_override("font", UiStyle.font("thought"))
		b.add_theme_font_size_override("font_size", 32)
		b.add_theme_stylebox_override("normal", UiStyle.paper(0.7, 6, 12))
		var hov := UiStyle.paper(0.9, 6, 12)
		hov.border_color = UiStyle.EMBER
		b.add_theme_stylebox_override("hover", hov)
		b.add_theme_stylebox_override("focus", hov)
		b.add_theme_stylebox_override("pressed", hov)
		var idx := i
		b.pressed.connect(func() -> void: _pick(idx))
		_choices.add_child(b)
		UiStyle.fade_in(b, 0.35 + 0.15 * i, 0.0)   # im Container: nur einblenden, nicht verschieben


func _pick(i: int) -> void:
	if not _choice_wait:
		return
	var b := _choices.get_child(i) as Button
	var said := b.text.substr(4)
	for c in _choices.get_children():
		_choices.remove_child(c)
		c.queue_free()
	_choice_wait = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_who.text = "CHRISTIAN"
	_who.add_theme_color_override("font_color", UiStyle.INK_DIM)
	_line.text = said
	_line_t = 0.0
	UiStyle.fade_in(_line, 0.3, 4.0)


# --- Nachspann: Zeilen auf Schwarz -------------------------------------------------------

func _epilogue() -> void:
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 2.0)
	tw.tween_callback(func() -> void:
		_rain.volume_db = -26.0
		_thought.text = "")
	for e: Dictionary in Array(data.get("epilogue", [])):
		var text := String(e.get("text", ""))
		var snd := String(e.get("sound", ""))
		tw.tween_callback(func() -> void:
			_epi.text = text
			_epi.visible_ratio = 0.0
			_epi.modulate.a = 1.0
			if snd == "wind":
				_rain.stop()
			if snd != "":
				SoundBank.play_ui(self, snd, -8.0)
			SoundBank.play_ui(self, "switch", -30.0))
		# Schreibmaschine: Buchstabe für Buchstabe
		tw.tween_property(_epi, "visible_ratio", 1.0, maxf(1.0, text.length() / 28.0))
		tw.tween_interval(float(e.get("hold", 4.0)))
		tw.tween_property(_epi, "modulate:a", 0.0, 0.9)
		tw.tween_interval(0.5)
	tw.tween_callback(func() -> void:
		_epi.text = "HOMEBOUND"
		_epi.add_theme_font_size_override("font_size", 76)
		_epi.visible_ratio = 1.0)
	tw.tween_property(_epi, "modulate:a", 1.0, 2.0)
	tw.tween_interval(2.0)
	tw.tween_property(_epi, "modulate:a", 0.0, 1.5)
	tw.tween_callback(_finish)


func _update_skip(delta: float) -> void:
	if Input.is_action_pressed("pause_menu"):
		_skip_t += delta
		_skip.modulate.a = 1.0
		_skip.text = "Überspringen …  %d %%" % int(minf(100.0, _skip_t / SKIP_HOLD * 100.0))
		if _skip_t >= SKIP_HOLD and step != Step.DONE:
			_finish()
	else:
		_skip_t = 0.0
		_skip.text = String(data.get("skip_hint", ""))
		_skip.modulate.a = 0.55 if _t < 8.0 or step == Step.EPILOGUE else 0.3


func _finish() -> void:
	if step == Step.DONE:
		return
	step = Step.DONE
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if preview_step >= 0:
		return
	GameState.finish_intro()
