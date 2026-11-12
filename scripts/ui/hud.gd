class_name Hud
extends CanvasLayer
## Bildschirmanzeige: Uhr, Fadenkreuz, Benutzen-Hinweis, Meldungen, Inventar,
## Verletzungs-Effekt, Monitor-Ansicht (Kameras), Schlaf- und Todesbildschirm.

const HELP_TEXT := "WASD  Gehen        Shift  Rennen        Strg / C  Ducken        Leertaste  Springen\n" + \
		"E / Linksklick  Benutzen        R  Abschließen / Verbarrikadieren / Nachfüllen        F  Taschenlampe        Y / X  Lehnen\n" + \
		"Tab  Inventar        B  Bauen        T (halten)  Zeit vorspulen (Test)        F2  Retro-Filter        Esc  Menü        F1  Hilfe"

var _clock: Label
var _prompt: Label
var _note: Label
var _help: Label
var _title: Label
var _inv: Label
var _weight: Label
var _fade: ColorRect
var _hurt: ColorRect
var _note_time: float = 0.0
var _help_time: float = 20.0
var _sleeping: bool = false

# Monitor-Ansicht
var _monitor_root: Control
var _monitor_view: TextureRect
var _monitor_mat: ShaderMaterial
var _monitor_label: Label
var _monitor_open: bool = false
var _monitor_opened_at: int = 0
var _static_player: AudioStreamPlayer
var _hum_player: AudioStreamPlayer

# Todesbildschirm
var _death: Label


func _ready() -> void:
	name = "Hud"
	layer = 5
	add_to_group("hud")
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_hurt = ColorRect.new()
	_hurt.color = Color(0.5, 0.0, 0.0, 0.0)
	_hurt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hurt.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(_hurt)

	root.add_child(InteractFrame.new())
	root.add_child(HotbarHud.new())

	var cross := ColorRect.new()
	cross.color = Color(1, 1, 1, 0.55)
	cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cross.anchor_left = 0.5
	cross.anchor_right = 0.5
	cross.anchor_top = 0.5
	cross.anchor_bottom = 0.5
	cross.offset_left = -2
	cross.offset_right = 2
	cross.offset_top = -2
	cross.offset_bottom = 2
	root.add_child(cross)

	_clock = _label(root, 30, HORIZONTAL_ALIGNMENT_RIGHT)
	_clock.anchor_left = 1.0
	_clock.anchor_right = 1.0
	_clock.offset_left = -400
	_clock.offset_right = -32
	_clock.offset_top = 24
	_clock.offset_bottom = 70

	_inv = _label(root, 20, HORIZONTAL_ALIGNMENT_RIGHT)
	_inv.anchor_left = 1.0
	_inv.anchor_right = 1.0
	_inv.anchor_top = 1.0
	_inv.anchor_bottom = 1.0
	_inv.offset_left = -600
	_inv.offset_right = -32
	_inv.offset_top = -60
	_inv.offset_bottom = -24
	# Traglast: getragen / Maximum, bei Überladung rot mit „ÜBERLADEN“
	_weight = _label(root, 20, HORIZONTAL_ALIGNMENT_RIGHT)
	_weight.anchor_left = 1.0
	_weight.anchor_right = 1.0
	_weight.anchor_top = 1.0
	_weight.anchor_bottom = 1.0
	_weight.offset_left = -600
	_weight.offset_right = -32
	_weight.offset_top = -92
	_weight.offset_bottom = -60

	_prompt = _label(root, 24, HORIZONTAL_ALIGNMENT_CENTER)
	_prompt.anchor_right = 1.0
	_prompt.anchor_top = 0.5
	_prompt.anchor_bottom = 0.5
	_prompt.offset_top = 40
	_prompt.offset_bottom = 120

	# Meldungen: mittig, höchstens ~60 % der Bildbreite, lange Texte brechen um (Radio, Tablet …)
	_note = _label(root, 26, HORIZONTAL_ALIGNMENT_CENTER)
	_note.anchor_left = 0.2
	_note.anchor_right = 0.8
	_note.anchor_top = 0.18
	_note.anchor_bottom = 0.18
	_note.offset_bottom = 60
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.grow_vertical = Control.GROW_DIRECTION_END
	_note.modulate.a = 0.0

	_help = _label(root, 18, HORIZONTAL_ALIGNMENT_LEFT)
	_help.anchor_top = 1.0
	_help.anchor_bottom = 1.0
	_help.anchor_right = 1.0
	_help.offset_left = 32
	_help.offset_top = -110
	_help.offset_bottom = -24
	_help.text = HELP_TEXT
	_help.modulate.a = 0.85

	_build_bars(root)
	_build_monitor(root)

	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 1)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(_fade)

	_title = _label(root, 64, HORIZONTAL_ALIGNMENT_CENTER)
	_title.anchor_right = 1.0
	_title.anchor_top = 0.38
	_title.anchor_bottom = 0.38
	_title.offset_bottom = 160
	_title.text = "HOMEBOUND"

	_death = _label(root, 34, HORIZONTAL_ALIGNMENT_CENTER)
	_death.anchor_right = 1.0
	_death.anchor_top = 0.42
	_death.anchor_bottom = 0.42
	_death.offset_bottom = 120
	_death.add_theme_color_override("font_color", Color(0.85, 0.2, 0.15))
	_death.modulate.a = 0.0

	EventBus.interaction_prompt_changed.connect(_on_prompt)
	EventBus.notification_requested.connect(show_notification)
	EventBus.sleep_requested.connect(_on_sleep_requested)
	EventBus.player_hurt.connect(_on_hurt)
	EventBus.fear_changed.connect(_on_fear)
	TimeManager.phase_changed.connect(_on_phase_changed)
	TimeManager.day_changed.connect(_on_day_changed)
	Inventory.changed.connect(_update_inventory)
	GameState.player_died.connect(_on_player_died)
	_update_inventory()
	_intro()


func _label(parent: Control, size: int, align: HorizontalAlignment) -> Label:
	var l := Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color(0.92, 0.9, 0.85))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 8)
	parent.add_child(l)
	return l


func _on_prompt(text: String) -> void:
	_prompt.text = text


func _process(delta: float) -> void:
	_clock.text = "Tag %d    %s" % [TimeManager.day, TimeManager.get_clock_text()]
	_update_weight()
	if _note_time > 0.0:
		_note_time -= delta
		_note.modulate.a = clampf(_note_time / 0.6, 0.0, 1.0)
	if _help_time > 0.0:
		_help_time -= delta
		if _help_time <= 0.0:
			_fade_help(false)
	if Input.is_action_just_pressed("toggle_help"):
		_fade_help(_help.modulate.a < 0.5)
	_hurt.color.a = move_toward(_hurt.color.a, 0.0, delta * 0.5)
	# Bei wenig Lebenspunkten bleibt der Rand rot
	var player := get_tree().get_first_node_in_group("player") as Player
	if player and player.health < 50.0:
		_hurt.color.a = maxf(_hurt.color.a, (50.0 - player.health) / 50.0 * 0.25)
	if _monitor_open:
		_update_monitor(delta)
	_update_bars()


func show_notification(text: String, duration: float = 3.0) -> void:
	_note.text = text
	_note_time = duration
	_note.modulate.a = 1.0


func _fade_help(show: bool) -> void:
	_help_time = 0.0
	create_tween().tween_property(_help, "modulate:a", 0.85 if show else 0.0, 0.5)


func _update_weight() -> void:
	var w := Inventory.total_weight()
	if Inventory.overloaded():
		_weight.text = "ÜBERLADEN   %.1f / %.0f kg" % [w, Inventory.MAX_WEIGHT]
		var pulse := 0.6 + 0.4 * absf(sin(Time.get_ticks_msec() / 300.0))
		_weight.add_theme_color_override("font_color", Color(1.0, 0.35, 0.3, pulse))
	else:
		_weight.text = "Traglast  %.1f / %.0f kg" % [w, Inventory.MAX_WEIGHT]
		var near := w > Inventory.MAX_WEIGHT * 0.85
		_weight.add_theme_color_override("font_color", Color(1.0, 0.8, 0.45) if near else Color(0.85, 0.85, 0.8, 0.85))


func _update_inventory() -> void:
	var parts: PackedStringArray = []
	for id in Inventory.items:
		parts.append("%s %d" % [Inventory.display_name(id), Inventory.count(id)])
	_inv.text = "   ·   ".join(parts)


func _intro() -> void:
	var tw := create_tween()
	tw.tween_interval(1.2)
	tw.tween_property(_fade, "color:a", 0.0, 2.5)
	tw.parallel().tween_property(_title, "modulate:a", 0.0, 3.5)
	if TimeManager.day == TimeManager.config.start_day and TimeManager.hour > 16.0:
		tw.tween_callback(func() -> void: show_notification("Die Sonne steht schon tief.", 4.0))
	else:
		tw.tween_callback(func() -> void: show_notification("Tag %d" % TimeManager.day, 3.0))


# --- Schlafen -----------------------------------------------------------

func _on_sleep_requested(wake_hour: float) -> void:
	_sleeping = true
	var from_total := TimeManager.get_total_hours()
	var to_total := from_total + fposmod(wake_hour - TimeManager.hour, 24.0)
	# Störung während des Schlafs? Dann wacht man vorher auf (GDD 4.4).
	var disturb := ThreatDirector.first_disturbance(from_total, to_total)
	var target_hour := wake_hour if disturb < 0.0 else fmod(disturb, 24.0) + 0.02
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 1.4)
	tw.tween_callback(func() -> void: TimeManager.skip_to_hour(target_hour))
	tw.tween_interval(1.6 if disturb < 0.0 else 0.5)
	tw.tween_callback(func() -> void:
		if disturb >= 0.0:
			ThreatDirector.scared_until = TimeManager.get_total_hours() + ThreatDirector.config.scared_awake_hours
			show_notification("Du schreckst hoch.  %s" % TimeManager.get_clock_text(), 4.0)
		else:
			show_notification("Tag %d  –  %s" % [TimeManager.day, TimeManager.get_clock_text()], 4.0))
	tw.tween_property(_fade, "color:a", 0.0, 1.8 if disturb < 0.0 else 0.6)
	tw.tween_callback(func() -> void:
		_sleeping = false
		EventBus.sleep_finished.emit())


func _on_phase_changed(is_night: bool) -> void:
	if _sleeping:
		return
	show_notification("Es wird dunkel." if is_night else "Der Morgen graut.", 3.5)


func _on_day_changed(day: int) -> void:
	if _sleeping:
		return
	show_notification("Tag %d" % day, 3.0)


# --- Schaden und Tod ----------------------------------------------------

var _fear_rect: ColorRect


func _on_fear(fear: float) -> void:
	if _fear_rect == null:
		_fear_rect = ColorRect.new()
		_fear_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_fear_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		var m := ShaderMaterial.new()
		var sh := Shader.new()
		sh.code = "shader_type canvas_item;\nuniform float fear = 0.0;\nvoid fragment(){ vec2 v = UV - 0.5; float d = length(v) * 1.4; float pulse = 0.85 + 0.15 * sin(TIME * 7.0); COLOR = vec4(0.02, 0.0, 0.0, smoothstep(0.45, 1.0, d) * fear * pulse); }"
		m.shader = sh
		_fear_rect.material = m
		_hurt.get_parent().add_child(_fear_rect)
		_hurt.get_parent().move_child(_fear_rect, 0)
	(_fear_rect.material as ShaderMaterial).set_shader_parameter("fear", fear)


func _on_hurt(amount: float) -> void:
	_hurt.color.a = clampf(0.25 + amount / 100.0, 0.0, 0.7)
	if _monitor_open:
		close_monitor()


func _on_player_died() -> void:
	close_monitor()
	_death.text = "Du hast die Nacht nicht überlebt.\nZurück zum Beginn von Tag %d …" % TimeManager.day
	var tw := create_tween()
	tw.tween_property(_hurt, "color:a", 0.6, 0.3)
	tw.tween_property(_fade, "color:a", 1.0, 1.8)
	tw.parallel().tween_property(_death, "modulate:a", 1.0, 1.5)


# --- Survival-Anzeige ---------------------------------------------------

var _bars: Dictionary = {}
var _bar_root: VBoxContainer


func _build_bars(root: Control) -> void:
	_bar_root = VBoxContainer.new()
	_bar_root.anchor_top = 1.0
	_bar_root.anchor_bottom = 1.0
	_bar_root.offset_left = 32
	_bar_root.offset_top = -212
	_bar_root.offset_right = 260
	_bar_root.offset_bottom = -120
	_bar_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar_root.add_theme_constant_override("separation", 4)
	root.add_child(_bar_root)
	for key: String in ["Ausdauer", "Hunger", "Durst", "Wärme", "Gesundheit"]:
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var l := _label(row, 14, HORIZONTAL_ALIGNMENT_LEFT)
		l.text = key
		l.custom_minimum_size = Vector2(90, 0)
		var bg := ColorRect.new()
		bg.color = Color(0, 0, 0, 0.5)
		bg.custom_minimum_size = Vector2(120, 8)
		bg.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(bg)
		var fg := ColorRect.new()
		fg.color = {"Ausdauer": Color(0.9, 0.9, 0.85), "Hunger": Color(0.9, 0.6, 0.25), "Durst": Color(0.35, 0.65, 0.95),
			"Wärme": Color(0.95, 0.75, 0.35), "Gesundheit": Color(0.85, 0.2, 0.2)}[key]
		fg.size = Vector2(120, 8)
		fg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bg.add_child(fg)
		_bar_root.add_child(row)
		_bars[key] = [row, fg]


func _update_bars() -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	var values := {"Ausdauer": Survival.stamina, "Hunger": Survival.hunger, "Durst": Survival.thirst,
			"Wärme": Survival.warmth, "Gesundheit": player.health if player else 100.0}
	for key in _bars:
		var v: float = values[key]
		var row: Control = _bars[key][0]
		var fg: ColorRect = _bars[key][1]
		fg.size.x = 120.0 * clampf(v / 100.0, 0.0, 1.0)
		# Nur zeigen, wenn es etwas zu sehen gibt
		var show := v < 60.0 if key in ["Hunger", "Durst", "Wärme"] else v < 99.0
		if key == "Wärme":
			fg.color = Color(0.95, 0.75, 0.35).lerp(Color(0.45, 0.7, 1.0), 1.0 - clampf(v / 60.0, 0.0, 1.0))
		row.modulate.a = move_toward(row.modulate.a, 1.0 if show else 0.0, 0.05)


# --- Monitor-Ansicht ----------------------------------------------------

func _build_monitor(root: Control) -> void:
	_monitor_root = Control.new()
	_monitor_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_monitor_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_monitor_root.visible = false
	root.add_child(_monitor_root)
	var bg := ColorRect.new()
	bg.color = Color(0.01, 0.01, 0.01, 0.92)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_monitor_root.add_child(bg)
	_monitor_view = TextureRect.new()
	_monitor_view.anchor_left = 0.12
	_monitor_view.anchor_right = 0.88
	_monitor_view.anchor_top = 0.08
	_monitor_view.anchor_bottom = 0.86
	_monitor_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_monitor_view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_monitor_view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_monitor_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_monitor_mat = ShaderMaterial.new()
	_monitor_mat.shader = load("res://shaders/cctv.gdshader")
	_monitor_view.material = _monitor_mat
	_monitor_root.add_child(_monitor_view)
	_monitor_label = _label(_monitor_root, 26, HORIZONTAL_ALIGNMENT_LEFT)
	_monitor_label.anchor_left = 0.14
	_monitor_label.anchor_right = 0.86
	_monitor_label.anchor_top = 0.1
	_monitor_label.anchor_bottom = 0.1
	_monitor_label.offset_bottom = 40
	_monitor_label.add_theme_color_override("font_color", Color(0.75, 1.0, 0.75))
	var hint := _label(_monitor_root, 20, HORIZONTAL_ALIGNMENT_CENTER)
	hint.anchor_right = 1.0
	hint.anchor_top = 0.9
	hint.anchor_bottom = 0.9
	hint.offset_bottom = 40
	hint.text = "A / D  Kamera wechseln        E  Monitor verlassen"
	_static_player = AudioStreamPlayer.new()
	_static_player.stream = SoundBank.get_sound("static")
	_static_player.volume_db = -20.0
	add_child(_static_player)
	_hum_player = AudioStreamPlayer.new()
	_hum_player.stream = SoundBank.get_sound("monitor_hum")
	_hum_player.volume_db = -26.0
	add_child(_hum_player)


func open_monitor() -> void:
	var sv := get_tree().get_first_node_in_group("surveillance") as Surveillance
	if sv == null:
		return
	_monitor_view.texture = sv.viewport.get_texture()
	sv.viewing = true
	_monitor_open = true
	_monitor_opened_at = Time.get_ticks_msec()
	_monitor_root.visible = true
	_set_player_locked(true)
	_static_player.play()
	if SoundBank.has_recording("monitor_hum"):
		_hum_player.play()
	SoundBank.play_ui(self, "camera_switch", -6.0)


func close_monitor() -> void:
	if not _monitor_open:
		return
	var sv := get_tree().get_first_node_in_group("surveillance") as Surveillance
	if sv:
		sv.viewing = false
	_monitor_open = false
	_monitor_root.visible = false
	_static_player.stop()
	_hum_player.stop()
	_set_player_locked(false)
	get_tree().call_group("monitor_station", "on_monitor_closed")


func _set_player_locked(v: bool) -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	if player:
		player.input_locked = v
		# beim Öffnen sitzt der Spieler (Bewegung ruht) – erst beim Schließen wieder freigeben
		if not v:
			player.set_physics_process(true)


func _update_monitor(_delta: float) -> void:
	var sv := get_tree().get_first_node_in_group("surveillance") as Surveillance
	if sv == null:
		return
	if Input.is_action_just_pressed("move_left"):
		sv.set_active(sv.active_index - 1)
		SoundBank.play_ui(self, "camera_switch", -6.0)
	elif Input.is_action_just_pressed("move_right"):
		sv.set_active(sv.active_index + 1)
		SoundBank.play_ui(self, "camera_switch", -6.0)
	elif Input.is_action_just_pressed("interact") and Time.get_ticks_msec() - _monitor_opened_at > 250:
		close_monitor()
		return
	var power := PowerManager.has_power()
	var cam_ok := sv.installed(sv.active_index)
	# ohne Strom bleibt das Bild schwarz und stumm (kein Störbild); nicht eingebaute Kamera = Rauschen
	_monitor_mat.set_shader_parameter("dark", 0.0 if power else 1.0)
	_monitor_mat.set_shader_parameter("no_signal", 0.0 if cam_ok else 1.0)
	_monitor_mat.set_shader_parameter("glitch", 1.0 if sv.is_glitching() and power else 0.0)
	_static_player.volume_db = -80.0 if not power else (-6.0 if sv.is_glitching() else -22.0)
	var blink := "REC" if fmod(Time.get_ticks_msec() / 1000.0, 1.0) < 0.5 else "      "
	_monitor_label.text = "%s   CAM %d – %s        Tag %d  %s" % [blink, sv.active_index + 1, sv.active_name(), TimeManager.day, TimeManager.get_clock_text()]
	if not power:
		_monitor_label.text = "KEIN SIGNAL – kein Strom"
	elif not cam_ok:
		_monitor_label.text = "KAMERA %d – nicht installiert        [A/D] umschalten" % (sv.active_index + 1)
