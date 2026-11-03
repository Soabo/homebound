class_name Hud
extends CanvasLayer
## Bildschirmanzeige: Uhr, Fadenkreuz, Benutzen-Hinweis, Meldungen,
## Steuerungshilfe (F1) und die Schlaf-Abblende.

const HELP_TEXT := "WASD  Gehen        Shift  Rennen        Strg / C  Ducken        Leertaste  Springen\n" + \
		"E / Linksklick  Benutzen        R  Abschließen        F  Taschenlampe\n" + \
		"T (halten)  Zeit vorspulen (Test)        F11  Vollbild        Esc  Menü        F1  Hilfe ein/aus"

var _clock: Label
var _prompt: Label
var _note: Label
var _help: Label
var _title: Label
var _fade: ColorRect
var _note_time: float = 0.0
var _help_time: float = 20.0
var _sleeping: bool = false


func _ready() -> void:
	name = "Hud"
	layer = 5
	add_to_group("hud")
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

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

	_prompt = _label(root, 24, HORIZONTAL_ALIGNMENT_CENTER)
	_prompt.anchor_right = 1.0
	_prompt.anchor_top = 0.5
	_prompt.anchor_bottom = 0.5
	_prompt.offset_top = 40
	_prompt.offset_bottom = 120

	_note = _label(root, 26, HORIZONTAL_ALIGNMENT_CENTER)
	_note.anchor_right = 1.0
	_note.anchor_top = 0.22
	_note.anchor_bottom = 0.22
	_note.offset_bottom = 60
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

	_title = _label(root, 64, HORIZONTAL_ALIGNMENT_CENTER)
	_title.anchor_right = 1.0
	_title.anchor_top = 0.38
	_title.anchor_bottom = 0.38
	_title.offset_bottom = 160
	_title.text = "HOMEBOUND"

	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 1)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(_fade)
	# Titel über der Abblende
	_title.reparent(root)

	EventBus.interaction_prompt_changed.connect(func(t: String) -> void: _prompt.text = t)
	EventBus.notification_requested.connect(show_notification)
	EventBus.sleep_requested.connect(_on_sleep_requested)
	TimeManager.phase_changed.connect(_on_phase_changed)
	TimeManager.day_changed.connect(_on_day_changed)
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


func _process(delta: float) -> void:
	_clock.text = "Tag %d    %s" % [TimeManager.day, TimeManager.get_clock_text()]
	if _note_time > 0.0:
		_note_time -= delta
		_note.modulate.a = clampf(_note_time / 0.6, 0.0, 1.0)
	if _help_time > 0.0:
		_help_time -= delta
		if _help_time <= 0.0:
			_fade_help(false)
	if Input.is_action_just_pressed("toggle_help"):
		_fade_help(_help.modulate.a < 0.5)


func show_notification(text: String, duration: float = 3.0) -> void:
	_note.text = text
	_note_time = duration
	_note.modulate.a = 1.0


func _fade_help(show: bool) -> void:
	_help_time = 0.0
	create_tween().tween_property(_help, "modulate:a", 0.85 if show else 0.0, 0.5)


func _intro() -> void:
	var tw := create_tween()
	tw.tween_interval(1.2)
	tw.tween_property(_fade, "color:a", 0.0, 2.5)
	tw.parallel().tween_property(_title, "modulate:a", 0.0, 3.5)
	tw.tween_callback(func() -> void: show_notification("Die Sonne steht schon tief.", 4.0))


func _on_sleep_requested(wake_hour: float) -> void:
	_sleeping = true
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 1.4)
	tw.tween_callback(func() -> void: TimeManager.skip_to_hour(wake_hour))
	tw.tween_interval(1.6)
	tw.tween_callback(func() -> void:
		show_notification("Tag %d  –  %s" % [TimeManager.day, TimeManager.get_clock_text()], 4.0))
	tw.tween_property(_fade, "color:a", 0.0, 1.8)
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
