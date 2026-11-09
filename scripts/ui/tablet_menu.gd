class_name TabletMenu
extends CanvasLayer
## Das Tablet, solange man auf der Couch sitzt. Reiter:
##  Posteingang  – Mails und Nachrichten (links Liste, rechts Text)
##  Alien-Archiv – vom Analysegerät gesendete Ergebnisse, Verknüpfungen
##  Notizen      – gefundene Notizen
## Die Zeit läuft weiter. [E] legt das Tablet weg und man steht auf.

var _couch: Couch
var _root: Control
var _clock: Label
var _list: VBoxContainer
var _from: Label
var _subject: Label
var _body: Label
var _hint: Label
var _current: String = ""
var _flicker: float = 0.0
var _screen_bg: ColorRect
var _tab: String = "inbox"
var _tabs: Dictionary = {}       ## Reiter-ID -> Button
var _title: Label
var _split: HBoxContainer
var _wide_scroll: ScrollContainer
var _wide: VBoxContainer


func _ready() -> void:
	name = "TabletMenu"
	layer = 7
	add_to_group("tablet_menu")
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.visible = false
	add_child(_root)

	# Gehäuse: dunkler Rahmen mit runden Ecken, unten mittig – wie in den Händen gehalten
	var case := PanelContainer.new()
	case.anchor_left = 0.17
	case.anchor_right = 0.83
	case.anchor_top = 0.16
	case.anchor_bottom = 0.97
	var cs := StyleBoxFlat.new()
	cs.bg_color = Color(0.04, 0.04, 0.05)
	cs.set_corner_radius_all(26)
	cs.set_content_margin_all(22)
	cs.border_color = Color(0.16, 0.16, 0.18)
	cs.set_border_width_all(2)
	case.add_theme_stylebox_override("panel", cs)
	_root.add_child(case)

	var screen := Control.new()
	screen.clip_contents = true
	case.add_child(screen)
	_screen_bg = ColorRect.new()
	_screen_bg.color = Color(0.09, 0.1, 0.12)
	_screen_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.add_child(_screen_bg)

	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 14
	v.offset_right = -14
	v.offset_top = 8
	v.offset_bottom = -10
	v.add_theme_constant_override("separation", 8)
	screen.add_child(v)

	# Statusleiste
	var bar := HBoxContainer.new()
	v.add_child(bar)
	_title = _label("Posteingang", 18, Color(0.75, 0.8, 0.88))
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(_title)
	_clock = _label("", 18, Color(0.75, 0.8, 0.88))
	bar.add_child(_clock)

	# Reiter
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	v.add_child(tabs)
	for t: Array in [["inbox", "Posteingang"], ["archive", "Alien-Archiv"], ["notes", "Notizen"]]:
		var tb := Button.new()
		tb.text = t[1]
		tb.toggle_mode = true
		tb.custom_minimum_size = Vector2(170, 36)
		tb.add_theme_font_size_override("font_size", 16)
		tb.pressed.connect(_set_tab.bind(t[0]))
		tabs.add_child(tb)
		_tabs[t[0]] = tb

	var split := HBoxContainer.new()
	_split = split
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_theme_constant_override("separation", 14)
	v.add_child(split)
	# breite Seite für Archiv und Notizen
	_wide_scroll = ScrollContainer.new()
	_wide_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_wide_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_wide_scroll.visible = false
	v.add_child(_wide_scroll)
	_wide = VBoxContainer.new()
	_wide.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_wide.add_theme_constant_override("separation", 6)
	_wide_scroll.add_child(_wide)

	var ls := ScrollContainer.new()
	ls.custom_minimum_size = Vector2(300, 0)
	ls.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	split.add_child(ls)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	ls.add_child(_list)

	var rs := ScrollContainer.new()
	rs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rs.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	split.add_child(rs)
	var read := VBoxContainer.new()
	read.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	read.add_theme_constant_override("separation", 6)
	rs.add_child(read)
	_from = _label("", 17, Color(0.6, 0.66, 0.75))
	read.add_child(_from)
	_subject = _label("", 24, Color(0.92, 0.94, 0.97))
	_subject.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	read.add_child(_subject)
	_body = _label("", 19, Color(0.82, 0.84, 0.88))
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	read.add_child(_body)

	_hint = _label("Klicke eine Nachricht an.     [E] Tablet weglegen und aufstehen", 16, Color(0.55, 0.6, 0.68))
	v.add_child(_hint)
	Research.changed.connect(func() -> void:
		if _root.visible:
			_refresh())


func _label(t: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l


func open(couch: Couch) -> void:
	_couch = couch
	_root.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_current = ""
	_tab = "inbox"
	_refresh()
	var av := couch.available()
	for m: Dictionary in av:
		if not couch.read_ids.has(m["id"]):
			_show(m)
			break


func close() -> void:
	if not _root.visible:
		return
	_root.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if _couch:
		_couch.stand_up()


func is_open() -> bool:
	return _root.visible


func _set_tab(t: String) -> void:
	_tab = t
	SoundBank.play_ui(self, "menu_click", -10.0)
	_refresh()


func _refresh() -> void:
	for id: String in _tabs:
		(_tabs[id] as Button).button_pressed = id == _tab
	var nb := _tabs["archive"] as Button
	nb.text = "Alien-Archiv" + ("  ● %d neu" % Research.tablet_new if Research.tablet_new > 0 and _tab != "archive" else "")
	_split.visible = _tab == "inbox"
	_wide_scroll.visible = _tab != "inbox"
	if _tab != "inbox":
		for c in _wide.get_children():
			c.queue_free()
		if _tab == "archive":
			_title.text = "Alien-Archiv"
			_hint.text = "Ergebnisse kommen vom Analysegerät in der Werkstatt.     [E] Tablet weglegen und aufstehen"
			ResearchMenu.fill_archive(_wide)
			Research.mark_tablet_seen.call_deferred()
		else:
			_title.text = "Notizen"
			_hint.text = "[E] Tablet weglegen und aufstehen"
			ResearchMenu.fill_notes(_wide)
		return
	_title.text = "Posteingang"
	_hint.text = "Klicke eine Nachricht an.     [E] Tablet weglegen und aufstehen"
	for c in _list.get_children():
		c.queue_free()
	for m: Dictionary in _couch.available():
		var b := Button.new()
		var unread := not _couch.read_ids.has(m["id"])
		var kind := "✉ " if m.get("type", "mail") == "mail" else "▤ "
		b.text = ("● " if unread else "   ") + kind + String(m.get("from", "")) + "\n      " + String(m.get("subject", ""))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 16)
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		b.custom_minimum_size = Vector2(0, 56)
		if m["id"] == _current:
			b.add_theme_color_override("font_color", Color(1.0, 0.85, 0.5))
		b.pressed.connect(_show.bind(m))
		_list.add_child(b)
	if _list.get_child_count() == 0:
		_list.add_child(_label("Keine Nachrichten.", 16, Color(0.6, 0.6, 0.65)))


func _show(m: Dictionary) -> void:
	_current = String(m["id"])
	_couch.mark_read(_current)
	var kind := "E-Mail von " if m.get("type", "mail") == "mail" else "Nachrichten – "
	_from.text = kind + String(m.get("from", ""))
	_subject.text = String(m.get("subject", ""))
	_body.text = String(m.get("body", ""))
	SoundBank.play_ui(self, "menu_click", -10.0)
	_refresh()


func _process(delta: float) -> void:
	if not _root.visible:
		return
	_clock.text = "Tag %d   %s" % [TimeManager.day, TimeManager.get_clock_text()]
	if not get_tree().paused and Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# kurzes Flackern des Bildschirms, wenn draußen etwas Seltsames passiert
	if _flicker > 0.0:
		_flicker -= delta
		_screen_bg.color = Color(0.09, 0.1, 0.12) if randf() < 0.5 else Color(0.25, 0.27, 0.3)
		_body.modulate.a = randf_range(0.3, 1.0)
	else:
		_screen_bg.color = Color(0.09, 0.1, 0.12)
		_body.modulate.a = 1.0
	if GameState.dead:
		close()


func flicker(seconds: float = 1.2) -> void:
	_flicker = seconds


func _input(event: InputEvent) -> void:
	if not _root.visible:
		return
	if event.is_action_pressed("interact") and not event.is_echo():
		close()
		get_viewport().set_input_as_handled()
