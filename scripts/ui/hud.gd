class_name Hud
extends CanvasLayer
## Bildschirmanzeige: Uhr, Fadenkreuz, Benutzen-Hinweis, Meldungen, Inventar,
## Verletzungs-Effekt, Monitor-Ansicht (Kameras), Schlaf- und Todesbildschirm.


var _clock: Label
var _prompt: Label
var _thought: Label           ## Gedanke unten in Handschrift – immer nur einer (Christian 26.11.)
var _queue: Array = []         ## wartende Gedanken [Text, Dauer]
var _thought_t := 0.0          ## Restzeit des sichtbaren Gedankens
var _thought_age := 0.0        ## so lange ist er schon zu sehen
var _last_text := ""
var log_entries: Array = []    ## Uhr: ZULETZT (neueste zuerst) {text, clock}
var unread := 0                ## stille Einträge, seit man zuletzt auf die Uhr geschaut hat
var _needs: NeedsHud
var _keycard: Control
var _clock_day: Label
var _help: Label
var _title: Label
var _weight: Label
var _fade: ColorRect
var _hurt: ColorRect
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

	# Uhrzeit groß, darunter Tag + Datum klein (Barlow, Papier-Weiß)
	_clock = _label(root, 34, HORIZONTAL_ALIGNMENT_RIGHT)
	UiStyle.style(_clock, "ui_bold", 34)
	_clock.anchor_left = 1.0
	_clock.anchor_right = 1.0
	_clock.offset_left = -400
	_clock.offset_right = -32
	_clock.offset_top = 18
	_clock.offset_bottom = 62
	_clock_day = _label(root, 18, HORIZONTAL_ALIGNMENT_RIGHT)
	UiStyle.style(_clock_day, "ui", 18, UiStyle.INK_DIM)
	_clock_day.anchor_left = 1.0
	_clock_day.anchor_right = 1.0
	_clock_day.offset_left = -400
	_clock_day.offset_right = -32
	_clock_day.offset_top = 58
	_clock_day.offset_bottom = 84

	# Christian 23.11.: keine Inventar-Zeile mehr unten rechts (Inhalt steht im Rucksack, Tab)
	# Traglast: getragen / Maximum, bei Überladung rot mit „ÜBERLADEN“
	_weight = _label(root, 18, HORIZONTAL_ALIGNMENT_RIGHT)
	_weight.anchor_left = 1.0
	_weight.anchor_right = 1.0
	_weight.anchor_top = 1.0
	_weight.anchor_bottom = 1.0
	_weight.offset_left = -600
	_weight.offset_right = -32
	_weight.offset_top = -60
	_weight.offset_bottom = -28

	_prompt = _label(root, 24, HORIZONTAL_ALIGNMENT_CENTER)
	UiStyle.style(_prompt, "ui_bold", 25)
	_prompt.anchor_right = 1.0
	_prompt.anchor_top = 0.5
	_prompt.anchor_bottom = 0.5
	_prompt.offset_top = 40
	_prompt.offset_bottom = 120

	# Gedanken: unten in Handschrift, höchstens ~56 % der Bildbreite, lange Texte brechen um
	_thought = Label.new()
	_thought.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_thought.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_thought.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_thought.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiStyle.style(_thought, "thought", 36, UiStyle.INK, 7)
	_thought.anchor_left = 0.22
	_thought.anchor_right = 0.78
	_thought.anchor_top = 0.62
	_thought.anchor_bottom = 0.79
	_thought.modulate.a = 0.0
	root.add_child(_thought)
	_help = _thought   # alte Tests/Verweise: _help gibt es nicht mehr als Tastenzeile (Tastenbild: F1)

	_needs = NeedsHud.new()
	root.add_child(_needs)
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
	UiStyle.style(_title, "type", 76, UiStyle.INK, 0)

	_death = _label(root, 34, HORIZONTAL_ALIGNMENT_CENTER)
	_death.anchor_right = 1.0
	_death.anchor_top = 0.34
	_death.anchor_bottom = 0.34
	_death.offset_bottom = 120
	UiStyle.style(_death, "type", 38, Color(0.85, 0.22, 0.17))
	_death.modulate.a = 0.0
	_death_tips = _label(root, 22, HORIZONTAL_ALIGNMENT_CENTER)
	_death_tips.anchor_right = 1.0
	_death_tips.anchor_top = 0.56
	_death_tips.anchor_bottom = 0.56
	_death_tips.offset_left = 260
	_death_tips.offset_right = -260
	_death_tips.offset_bottom = 300
	_death_tips.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiStyle.style(_death_tips, "ui", 23, UiStyle.INK)
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
	UiStyle.style(l, "ui", size)
	parent.add_child(l)
	return l


func _on_prompt(text: String) -> void:
	_prompt.text = text


func _process(delta: float) -> void:
	_clock.text = TimeManager.get_clock_text()
	_clock_day.text = "Tag %d · %s" % [TimeManager.day, TimeManager.date_text()]
	_update_weight()
	_update_notes(delta)
	_update_watch_log(delta)
	_needs.unread = unread
	if Input.is_action_just_pressed("toggle_help"):
		toggle_keycard()
	_hurt.color.a = move_toward(_hurt.color.a, 0.0, delta * 0.5)
	# Bei wenig Lebenspunkten bleibt der Rand rot
	var player := get_tree().get_first_node_in_group("player") as Player
	if player and player.health < 50.0:
		_hurt.color.a = maxf(_hurt.color.a, (50.0 - player.health) / 50.0 * 0.25)
	if _monitor_open:
		_update_monitor(delta)


## Meldungen (Christian 26.11.: „nicht überladen“): Unwichtiges (data/ui/notices.json „quiet“) geht still auf die Uhr,
## alles andere erscheint als Gedanke unten – immer nur einer, die nächsten warten kurz. Mit „!“ drängelt eine Meldung vor.
func show_notification(text: String, duration: float = 3.0) -> void:
	if text.strip_edges() == "":
		return
	_last_text = text
	_remember(text)
	if is_quiet(text):
		unread += 1
		return
	duration = maxf(duration, 2.5)
	if _thought_t > 0.0 and _thought.text == text:
		_thought_t = maxf(_thought_t, duration)
		return
	for q: Array in _queue:
		if String(q[0]) == text:
			return
	if _thought_t <= 0.0:
		_show_thought(text, duration)
		return
	if text.contains("!"):
		_queue.push_front([text, duration])
		_thought_t = minf(_thought_t, 0.35)   # der aktuelle Gedanke macht sofort Platz
	else:
		_queue.append([text, duration])
	while _queue.size() > int(notice_cfg().get("queue_max", 3)):
		_queue.pop_back() if text.contains("!") else _queue.pop_front()


static var _cfg: Dictionary = {}


static func notice_cfg() -> Dictionary:
	if _cfg.is_empty():
		_cfg = DataDB.load_json("res://data/ui/notices.json")
	return _cfg


## Gehört die Meldung zu den stillen (nur auf der Uhr)?
static func is_quiet(text: String) -> bool:
	for q in Array(notice_cfg().get("quiet", [])):
		if text.begins_with(String(q)):
			return true
	return false


func _remember(text: String) -> void:
	if not log_entries.is_empty() and String(log_entries[0]["text"]) == text:
		return
	log_entries.push_front({"text": text, "clock": TimeManager.get_clock_text()})
	while log_entries.size() > int(notice_cfg().get("log_keep", 12)):
		log_entries.pop_back()


func _show_thought(text: String, duration: float) -> void:
	_thought.text = text
	# lange Texte etwas kleiner, damit sie nicht den halben Bildschirm füllen
	_thought.add_theme_font_size_override("font_size", 36 if text.length() < 90 else (32 if text.length() < 170 else 28))
	_thought_t = duration
	_thought_age = 0.0


## Die jüngste Meldung (auch stille) – für Tests.
func current_notification() -> String:
	return _last_text


## Der gerade sichtbare Gedanke (leer, wenn keiner da ist).
func visible_thought() -> String:
	return _thought.text if _thought_t > 0.0 else ""


func _update_notes(delta: float) -> void:
	if _thought_t > 0.0:
		_thought_t -= delta
		_thought_age += delta
		if not _queue.is_empty() and _thought_age >= float(notice_cfg().get("min_seconds", 2.2)):
			_thought_t = minf(_thought_t, 0.35)
		_thought.modulate.a = clampf(_thought_t / 0.35, 0.0, 1.0) * clampf(_thought_age / 0.3, 0.0, 1.0)
	elif not _queue.is_empty():
		var q: Array = _queue.pop_front()
		_show_thought(String(q[0]), float(q[1]))
	else:
		_thought.modulate.a = 0.0


## Tastenbild (F1) ein/aus.
func toggle_keycard() -> void:
	if _keycard and is_instance_valid(_keycard):
		var k := _keycard
		_keycard = null
		var tw := k.create_tween()
		tw.tween_property(k, "modulate:a", 0.0, 0.25)
		tw.tween_callback(k.queue_free)
		return
	# mittig: CenterContainer über den ganzen Bildschirm, darin die Karte
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hurt.get_parent().add_child(center)
	center.add_child(KeyCard.new())
	_keycard = center
	UiStyle.fade_in(_keycard, 0.3, 0.0)


func keycard_open() -> bool:
	return _keycard != null and is_instance_valid(_keycard)


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
		tw.tween_callback(show_day_card)


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
			show_day_card())
	tw.tween_property(_fade, "color:a", 0.0, 1.8 if disturb < 0.0 else 0.6)
	tw.tween_callback(func() -> void:
		_sleeping = false
		EventBus.sleep_finished.emit())


## Tageskarte nach dem Aufwachen: Tag + Datum in Schreibmaschine, mittig, blendet langsam aus.
var _day_card: Label


func show_day_card() -> void:
	if _day_card == null:
		_day_card = _label(_hurt.get_parent(), 40, HORIZONTAL_ALIGNMENT_CENTER)
		UiStyle.style(_day_card, "type", 40, UiStyle.INK, 0)
		_day_card.anchor_right = 1.0
		_day_card.anchor_top = 0.3
		_day_card.anchor_bottom = 0.3
		_day_card.offset_bottom = 110
	_day_card.text = "Tag %d\n%s · %s" % [TimeManager.day, TimeManager.date_text(), TimeManager.get_clock_text()]
	_remember(_day_card.text.replace("\n", "  ·  "))
	var tw := create_tween()
	_day_card.modulate.a = 0.0
	tw.tween_property(_day_card, "modulate:a", 1.0, 1.2)
	tw.tween_interval(2.4)
	tw.tween_property(_day_card, "modulate:a", 0.0, 1.6)


func _on_phase_changed(is_night: bool) -> void:
	if _sleeping:
		return
	show_notification("Es wird dunkel." if is_night else "Der Morgen graut.", 3.5)


func _on_day_changed(day: int) -> void:
	if _sleeping:
		return
	show_notification("Tag %d  –  %s" % [day, TimeManager.date_text(day)], 3.0)


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
			+ "\n\nZurück zum letzten Speicherstand (Tag %d)   –   [E] weiter" % GameState.bed_day
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
	# Uhr-Display: dunkles Glas mit kaltem Rand
	var sb := UiStyle.paper(0.7, 8, 14)
	sb.bg_color = Color(0.02, 0.04, 0.05, 0.72)
	sb.border_color = Color(UiStyle.WATCH.r, UiStyle.WATCH.g, UiStyle.WATCH.b, 0.45)
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
	UiStyle.style(l, "ui_bold" if size <= 14 else "ui", size + 2, col, 3)
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
	var siege_line := ThreatDirector.siege_watch_line()
	if siege_line != "":
		lines.append(["⚠  " + siege_line, "open"])
	var routine := Tasks.daily()
	if routine.is_empty():
		lines.append(["Noch keine festen Routinen.", "none"])
	for d: Dictionary in routine:
		lines.append([("✓  " if d["done"] else "○  ") + String(d["title"]), "done" if d["done"] else "open"])
	# ZULETZT: die letzten Meldungen zum Nachlesen (auch die stillen)
	if not log_entries.is_empty():
		lines.append(["ZULETZT", "head_log"])
		for i in mini(4, log_entries.size()):
			var e: Dictionary = log_entries[i]
			var t := String(e["text"])
			if t.length() > 90:
				t = t.left(88) + " …"
			lines.append([String(e["clock"]) + "   " + t, "log_new" if i < unread else "log"])
	return lines


func _fill_watch_log() -> void:
	for c in _watch_log_box.get_children():
		_watch_log_box.remove_child(c)
		c.queue_free()
	for ln: Array in watch_log_lines():
		match String(ln[1]):
			"head_story":
				_log_line(String(ln[0]), 13, Color(1.0, 0.58, 0.42))
			"head_day", "head_log":
				_log_line(String(ln[0]), 13, Color(1.0, 0.82, 0.45))
			"log_new":
				_log_line(String(ln[0]), 14, UiStyle.INK)
			"log":
				_log_line(String(ln[0]), 14, UiStyle.INK_DIM)
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
		if _watch_log.visible:
			unread = 0   # gelesen, sobald die Liste einmal dastand
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
