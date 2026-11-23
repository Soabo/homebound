class_name Hud
extends CanvasLayer
## Bildschirmanzeige: Uhr, Fadenkreuz, Benutzen-Hinweis, Meldungen, Inventar,
## Verletzungs-Effekt, Monitor-Ansicht (Kameras), Schlaf- und Todesbildschirm.

const HELP_TEXT := "WASD  Gehen        Shift  Rennen        Strg / C  Ducken        Alt  Langsam + Atem anhalten        Leertaste  Springen\n" + \
		"E / Linksklick  Benutzen        R  Abschließen / Verbarrikadieren / Nachfüllen        F  Taschenlampe        Y / X  Lehnen\n" + \
		"Tab  Inventar        B  Bauen        T (halten)  Zeit vorspulen (Test)        F2  Retro-Filter        J (halten)  Aufgaben        Esc  Menü        F1  Hilfe"

var _clock: Label
var _prompt: Label
var _notes: VBoxContainer   ## Hinweise oben: neuester oben, ältere rutschen nach unten und grauen aus
var _help: Label
var _title: Label
var _weight: Label
var _fade: ColorRect
var _hurt: ColorRect
const NOTE_MAX := 4            ## so viele Hinweise stehen höchstens untereinander
const NOTE_OLD_MIN := 4.0      ## ein nach unten gerutschter Hinweis bleibt noch mindestens so lange lesbar
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
var _death_tips: Label


func _ready() -> void:
	name = "Hud"
	layer = 5
	add_to_group("hud")
	add_to_group("esc_close")
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
	root.add_child(StealthHud.new())

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

	# Christian 23.11.: keine Inventar-Zeile mehr unten rechts (Inhalt steht im Rucksack, Tab)
	# Traglast: getragen / Maximum, bei Überladung rot mit „ÜBERLADEN“
	_weight = _label(root, 20, HORIZONTAL_ALIGNMENT_RIGHT)
	_weight.anchor_left = 1.0
	_weight.anchor_right = 1.0
	_weight.anchor_top = 1.0
	_weight.anchor_bottom = 1.0
	_weight.offset_left = -600
	_weight.offset_right = -32
	_weight.offset_top = -60
	_weight.offset_bottom = -28

	_prompt = _label(root, 24, HORIZONTAL_ALIGNMENT_CENTER)
	_prompt.anchor_right = 1.0
	_prompt.anchor_top = 0.5
	_prompt.anchor_bottom = 0.5
	_prompt.offset_top = 40
	_prompt.offset_bottom = 120

	# Meldungen: mittig, höchstens ~60 % der Bildbreite, lange Texte brechen um (Radio, Tablet …)
	_notes = VBoxContainer.new()
	_notes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_notes.anchor_left = 0.2
	_notes.anchor_right = 0.8
	_notes.anchor_top = 0.18
	_notes.anchor_bottom = 0.18
	_notes.grow_vertical = Control.GROW_DIRECTION_END
	_notes.add_theme_constant_override("separation", 4)
	root.add_child(_notes)

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
	_death.anchor_top = 0.34
	_death.anchor_bottom = 0.34
	_death.offset_bottom = 120
	_death.add_theme_color_override("font_color", Color(0.85, 0.2, 0.15))
	_death.modulate.a = 0.0
	_death_tips = _label(root, 22, HORIZONTAL_ALIGNMENT_CENTER)
	_death_tips.anchor_right = 1.0
	_death_tips.anchor_top = 0.56
	_death_tips.anchor_bottom = 0.56
	_death_tips.offset_left = 260
	_death_tips.offset_right = -260
	_death_tips.offset_bottom = 300
	_death_tips.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_death_tips.add_theme_color_override("font_color", Color(0.85, 0.8, 0.72))
	_death_tips.modulate.a = 0.0

	EventBus.interaction_prompt_changed.connect(_on_prompt)
	EventBus.notification_requested.connect(show_notification)
	EventBus.sleep_requested.connect(_on_sleep_requested)
	EventBus.player_hurt.connect(_on_hurt)
	EventBus.fear_changed.connect(_on_fear)
	TimeManager.phase_changed.connect(_on_phase_changed)
	TimeManager.day_changed.connect(_on_day_changed)
	GameState.player_died.connect(_on_player_died)
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
	_update_notes(delta)
	_update_watch_log(delta)
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


## Neuer Hinweis erscheint oben; die älteren rutschen nach unten, werden grau und kleiner
## und bleiben noch eine Weile lesbar (Christian 23.11.: schnell aufeinanderfolgende Hinweise nachlesen können).
func show_notification(text: String, duration: float = 3.0) -> void:
	if _notes.get_child_count() > 0:
		var top := _notes.get_child(0) as Label
		if top.text == text:
			top.set_meta("t", maxf(float(top.get_meta("t")), duration))
			top.modulate.a = 1.0
			return
	for c in _notes.get_children():
		var old := c as Label
		old.set_meta("t", maxf(float(old.get_meta("t")), NOTE_OLD_MIN))
		old.add_theme_font_size_override("font_size", 20)
		old.add_theme_color_override("font_color", Color(0.62, 0.62, 0.6))
	var l := Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", 26)
	l.add_theme_color_override("font_color", Color(0.92, 0.9, 0.85))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 8)
	l.text = text
	l.set_meta("t", duration)
	_notes.add_child(l)
	_notes.move_child(l, 0)
	while _notes.get_child_count() > NOTE_MAX:
		var last := _notes.get_child(_notes.get_child_count() - 1)
		_notes.remove_child(last)
		last.queue_free()


## Der jüngste Hinweis im Stapel (leer, wenn keiner da ist) – auch für Tests.
func current_notification() -> String:
	return (_notes.get_child(0) as Label).text if _notes.get_child_count() > 0 else ""


func _update_notes(delta: float) -> void:
	for c in _notes.get_children():
		var l := c as Label
		var t := float(l.get_meta("t")) - delta
		l.set_meta("t", t)
		var faded := 0.55 if c.get_index() > 0 else 1.0   # ältere sind blasser
		l.modulate.a = clampf(t / 0.6, 0.0, 1.0) * faded
		if t <= 0.0:
			_notes.remove_child(l)
			l.queue_free()


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
	if Survival.leg_hurt():
		_weight.text = "Bein verletzt   ·   " + _weight.text


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
	var target_total := to_total if disturb < 0.0 else disturb + 0.02
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 1.4)
	tw.tween_callback(func() -> void: TimeManager.skip_to_total(target_total))
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
		sh.code = "shader_type canvas_item;\nuniform float fear = 0.0;\nvoid fragment(){ vec2 v = UV - 0.5; float d = length(v) * 1.4; float pulse = 0.82 + 0.18 * sin(TIME * (5.0 + 5.0 * fear)); float edge = smoothstep(0.85 - 0.45 * fear, 1.15, d); COLOR = vec4(0.015, 0.0, 0.0, clamp(edge * (0.45 + 0.6 * fear) * fear * pulse * 1.4, 0.0, 0.92)); }"
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
	var player := get_tree().get_first_node_in_group("player") as Player
	var info := death_info(player.death_cause if player else "")
	_death.text = "Du bist gestorben.\n%s" % String(info.get("title", ""))
	_death_tips.text = "Beim nächsten Mal:\n" + "\n".join(PackedStringArray(Array(info.get("tips", [])).map(func(t: Variant) -> String: return "•  " + String(t)))) \
			+ "\n\nZurück zum letzten Schlaf im Bett (Tag %d)   –   [E] weiter" % GameState.bed_day
	var tw := create_tween()
	tw.tween_property(_hurt, "color:a", 0.6, 0.3)
	tw.tween_property(_fade, "color:a", 1.0, 1.8)
	tw.parallel().tween_property(_death, "modulate:a", 1.0, 1.5)
	tw.tween_property(_death_tips, "modulate:a", 1.0, 1.0)


## Ursache → Überschrift und Ratschläge aus data/ui/deaths.json.
static func death_info(cause: String) -> Dictionary:
	var all: Dictionary = DataDB.load_json("res://data/ui/deaths.json")
	return all.get(cause, all.get("unknown", {}))


func _input(event: InputEvent) -> void:
	if GameState.dead and _death_tips and _death_tips.modulate.a > 0.5:
		if event.is_action_pressed("interact") or event.is_action_pressed("jump") or (event is InputEventMouseButton and event.pressed):
			GameState.death_continue()
			get_viewport().set_input_as_handled()


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
	hint.text = "A / D  Kamera wechseln        E / Esc  Monitor verlassen"
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


## Esc am Monitor = Monitor verlassen (Christian 15.11.).
func esc_close() -> bool:
	if _monitor_open:
		close_monitor()
		return true
	return false


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



# --- Aufgaben auf der Uhr (J gedrückt halten, Christian 23.11.) ----------------------------------

var _watch_log: PanelContainer
var _watch_log_box: VBoxContainer
var _watch_log_t := 0.0
const WATCH_LOG_WIDTH := 380.0


func _build_watch_log() -> void:
	_watch_log = PanelContainer.new()
	_watch_log.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.05, 0.06, 0.62)
	sb.border_color = Color(0.4, 0.75, 0.85, 0.5)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	_watch_log.add_theme_stylebox_override("panel", sb)
	_watch_log.custom_minimum_size = Vector2(WATCH_LOG_WIDTH, 0)
	_watch_log_box = VBoxContainer.new()
	_watch_log_box.add_theme_constant_override("separation", 2)
	_watch_log.add_child(_watch_log_box)
	_watch_log.visible = false
	add_child(_watch_log)


func _log_line(text: String, size: int, col: Color) -> void:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(WATCH_LOG_WIDTH - 24.0, 0)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 4)
	_watch_log_box.add_child(l)


## Kurze Checkliste: Hauptstory (Hauptspuren + offene Ziele) und Tagesroutine (HEUTE).
func watch_log_lines() -> Array:
	var lines: Array = []   # [Text, Art] Art: head_story | story | goal | head_day | done | open | none
	lines.append(["HAUPTSTORY", "head_story"])
	var n := 0
	for st: Dictionary in Story.active_steps():
		if not bool(st.get("main", false)):
			continue
		var prog := Story.step_progress(st)
		lines.append(["○  " + String(st.get("title", "")) + ("  (%s)" % prog if prog != "" else ""), "story"])
		n += 1
	for g: Dictionary in Tasks.open_goals():
		if n >= 4:
			break
		lines.append(["○  " + String(g.get("title", "")), "goal"])
		n += 1
	if n == 0:
		lines.append(["Im Moment nichts Offenes.", "none"])
	lines.append(["HEUTE", "head_day"])
	var routine := Tasks.daily()
	if routine.is_empty():
		lines.append(["Noch keine festen Routinen.", "none"])
	for d: Dictionary in routine:
		lines.append([("✓  " if d["done"] else "○  ") + String(d["title"]), "done" if d["done"] else "open"])
	return lines


func _fill_watch_log() -> void:
	for c in _watch_log_box.get_children():
		_watch_log_box.remove_child(c)
		c.queue_free()
	for ln: Array in watch_log_lines():
		match String(ln[1]):
			"head_story":
				_log_line(String(ln[0]), 13, Color(1.0, 0.58, 0.42))
			"head_day":
				_log_line(String(ln[0]), 13, Color(1.0, 0.82, 0.45))
			"story":
				_log_line(String(ln[0]), 16, Color(1.0, 0.88, 0.74))
			"goal":
				_log_line(String(ln[0]), 15, Color(0.85, 0.88, 0.93))
			"done":
				_log_line(String(ln[0]), 15, Color(0.5, 0.78, 0.52))
			"open":
				_log_line(String(ln[0]), 15, Color(0.92, 0.94, 0.97))
			_:
				_log_line(String(ln[0]), 14, Color(0.6, 0.62, 0.66))


func _update_watch_log(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	var k := player.hands.log_raise if player and player.hands else 0.0
	if _watch_log == null:
		if k <= 0.0:
			return
		_build_watch_log()
	if k < 0.4:
		_watch_log.visible = false
		_watch_log_t = 0.0
		return
	if not _watch_log.visible or _watch_log_t <= 0.0:
		_fill_watch_log()
		_watch_log_t = 1.0
	_watch_log_t -= delta
	_watch_log.visible = true
	_watch_log.modulate.a = clampf((k - 0.4) / 0.5, 0.0, 1.0)
	# über der Uhr: Bildschirmpunkt der Uhr, Liste mittig darüber
	var cam := get_viewport().get_camera_3d()
	var wp := player.hands.watch_global_position()
	var vp := get_viewport().get_visible_rect().size
	var at := Vector2(vp.x * 0.36, vp.y * 0.62)
	if cam and wp != Vector3.INF and not cam.is_position_behind(wp):
		at = cam.unproject_position(wp)
	var sz := _watch_log.get_combined_minimum_size()
	var pos := at - Vector2(sz.x * 0.5, sz.y + 46.0)
	_watch_log.size = sz
	_watch_log.position = Vector2(clampf(pos.x, 12.0, vp.x - sz.x - 12.0), clampf(pos.y, 12.0, vp.y - sz.y - 12.0))
