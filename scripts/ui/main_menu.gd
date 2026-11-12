class_name MainMenu
extends Control
## Hauptmenü (Phase 9): Titelbild mit der Hütte bei Nacht (langsam bewegt, Nebel, flackerndes Fensterlicht),
## Fortsetzen, Neues Spiel, Spiel laden (3 Plätze), Einstellungen, Steuerung, gesehene Enden, Beenden.
## Startet das Programm mit Test-Schaltern (--night-test, --walk-test, --screenshot-tour, --skip-menu …),
## geht es sofort ins Spiel.

const TITLE_IMAGE := "res://assets/ui/title.jpg"
const AMBER := Color(1.0, 0.78, 0.48)
const CONTROLS := [
	["W A S D", "Gehen"], ["Shift (halten)", "Rennen"], ["Alt (halten)", "Langsam und leise gehen"], ["C / Strg", "Ducken"],
	["Leertaste", "Springen"], ["Maus", "Umsehen"], ["E", "Benutzen, aufheben, öffnen"], ["R", "Zweite Aktion (z. B. hineinlegen, hinsetzen)"],
	["Linksklick", "Werkzeug in der Hand benutzen, schlagen"], ["Rechtsklick", "Blocken (Gießkanne: füllen)"], ["1 – 9 / Mausrad", "Schnellplatz wählen"],
	["F (kurz)", "Uhrlicht an/aus"], ["F (halten)", "Uhrlicht: LED oder weißes Display"], ["Tab / I", "Rucksack und Werkbank"],
	["B", "Bauen"], ["Q (halten)", "Fernglas"], ["M", "Wanderkarte"], ["Esc", "Pause"], ["F1", "Hilfe ein/aus"],
	["F2", "Retro-Bild ein/aus"], ["F11", "Vollbild"],
]

var _bg: TextureRect
var _fog: Array = []
var _glow: ColorRect
var _panel: PanelContainer
var _panel_box: VBoxContainer
var _panel_title: Label
var _t: float = 0.0
var _confirm: String = ""
static var test_show: bool = false   ## Tests: Menü trotz Test-Schalter aufbauen


func _ready() -> void:
	var shot := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--menu-shot="):
			shot = arg.get_slice("=", 1)
		elif arg.begins_with("--") and not test_show:
			get_tree().change_scene_to_file.call_deferred(GameState.GAME_SCENE)
			return
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = false
	_build_background()
	_build_buttons()
	_build_panel()
	# leiser Wind und Grillen im Hintergrund (wiederholen sich von selbst)
	for snd: Array in [["wind", -14.0], ["crickets", -20.0]]:
		var p := AudioStreamPlayer.new()
		p.stream = SoundBank.get_sound(String(snd[0]))
		p.volume_db = float(snd[1])
		p.autoplay = true
		add_child(p)
	if shot != "":
		_menu_shot(shot)


## Entwickler: Bild vom Hauptmenü (--menu-shot=/pfad/bild.png), mit offenem Einstellungsfenster als zweites Bild.
func _menu_shot(path: String) -> void:
	for i in 90:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(path)
	_show_settings()
	for i in 20:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(path.replace(".png", "_einstellungen.png"))
	get_tree().quit()


# --- Hintergrund ----------------------------------------------------------

func _build_background() -> void:
	var black := ColorRect.new()
	black.color = Color(0.02, 0.025, 0.035)
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(black)
	_bg = TextureRect.new()
	if ResourceLoader.exists(TITLE_IMAGE):
		_bg.texture = load(TITLE_IMAGE)
	_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.pivot_offset = get_viewport_rect().size * 0.5
	add_child(_bg)
	# warmes Fensterlicht, das leicht flackert (Kamin)
	_glow = ColorRect.new()
	_glow.color = Color(1.0, 0.55, 0.2, 0.0)
	_glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = mat
	add_child(_glow)
	# Nebelbänke, die langsam vorbeiziehen
	var grad := Gradient.new()
	grad.set_color(0, Color(0.7, 0.75, 0.85, 0.0))
	grad.add_point(0.5, Color(0.7, 0.75, 0.85, 0.1))
	grad.set_color(grad.get_point_count() - 1, Color(0.7, 0.75, 0.85, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 512
	gt.height = 128
	for i in 6:
		var f := TextureRect.new()
		f.texture = gt
		f.mouse_filter = Control.MOUSE_FILTER_IGNORE
		f.size = Vector2(1400, 320)
		f.position = Vector2(-700.0 + i * 520.0, 520.0 + (i % 3) * 120.0)
		add_child(f)
		_fog.append([f, 6.0 + i * 3.0])
	# Abdunklung links für die Schrift, Vignette
	var shade := TextureRect.new()
	var g2 := Gradient.new()
	g2.set_color(0, Color(0, 0, 0, 0.82))
	g2.set_color(1, Color(0, 0, 0, 0.0))
	var t2 := GradientTexture2D.new()
	t2.gradient = g2
	t2.fill_from = Vector2(0, 0)
	t2.fill_to = Vector2(1, 0)
	shade.texture = t2
	shade.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	shade.offset_right = 900.0
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	add_child(shade)


func _process(delta: float) -> void:
	_t += delta
	# langsames Heranfahren und Schwenken (Ken-Burns)
	var k := 1.06 + sin(_t * 0.045) * 0.03
	_bg.scale = Vector2(k, k)
	_bg.pivot_offset = size * 0.5
	_bg.position = Vector2(sin(_t * 0.03) * 22.0, cos(_t * 0.022) * 10.0)
	_glow.color.a = 0.025 + (sin(_t * 7.3) * 0.5 + sin(_t * 12.1) * 0.3 + 0.8) * 0.012
	for f: Array in _fog:
		var r := f[0] as TextureRect
		r.position.x += float(f[1]) * delta
		if r.position.x > size.x + 100.0:
			r.position.x = -r.size.x


# --- Knöpfe --------------------------------------------------------------

func _build_buttons() -> void:
	var box := VBoxContainer.new()
	box.position = Vector2(110, 150)
	box.add_theme_constant_override("separation", 12)
	add_child(box)
	var title := Label.new()
	title.text = "HOMEBOUND"
	title.add_theme_font_size_override("font_size", 86)
	title.add_theme_color_override("font_color", Color(0.93, 0.9, 0.84))
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	title.add_theme_constant_override("shadow_offset_x", 3)
	title.add_theme_constant_override("shadow_offset_y", 4)
	box.add_child(title)
	var sub := Label.new()
	sub.text = "Etwas sucht etwas in diesem Wald."
	sub.add_theme_font_size_override("font_size", 22)
	sub.add_theme_color_override("font_color", Color(0.75, 0.72, 0.66))
	box.add_child(sub)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 46)
	box.add_child(gap)
	var latest := GameState.latest_slot()
	if latest >= 0:
		var info := GameState.slot_info(latest)
		var b := _button(box, "Fortsetzen", "Platz %d · Tag %d" % [latest + 1, int(info.get("day", 1))])
		b.pressed.connect(func() -> void: GameState.load_game(latest))
		b.grab_focus.call_deferred()
	_button(box, "Neues Spiel").pressed.connect(func() -> void: _show_slots("new"))
	if latest >= 0:
		_button(box, "Spiel laden").pressed.connect(func() -> void: _show_slots("load"))
	_button(box, "Einstellungen").pressed.connect(_show_settings)
	_button(box, "Steuerung").pressed.connect(_show_controls)
	_button(box, "Gesehene Enden").pressed.connect(_show_endings)
	if OS.get_name() != "Web":
		_button(box, "Beenden").pressed.connect(func() -> void: get_tree().quit())


func _button(parent: Control, text: String, small: String = "") -> Button:
	var b := Button.new()
	b.text = text + (("    " + small) if small != "" else "")
	b.flat = true
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(380, 44)
	b.add_theme_font_size_override("font_size", 28)
	b.add_theme_color_override("font_color", Color(0.86, 0.84, 0.8))
	b.add_theme_color_override("font_hover_color", AMBER)
	b.add_theme_color_override("font_focus_color", AMBER)
	b.add_theme_color_override("font_pressed_color", Color(1.0, 0.9, 0.7))
	b.mouse_entered.connect(func() -> void: SoundBank.play_ui(self, "menu_click", -22.0, 1.6))
	parent.add_child(b)
	return b


# --- Seitenfenster -------------------------------------------------------

func _build_panel() -> void:
	_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.045, 0.05, 0.9)
	sb.border_color = Color(0.5, 0.4, 0.28, 0.6)
	sb.set_border_width_all(1)
	sb.set_content_margin_all(28)
	sb.set_corner_radius_all(4)
	_panel.add_theme_stylebox_override("panel", sb)
	_panel.position = Vector2(620, 140)
	_panel.custom_minimum_size = Vector2(680, 0)
	add_child(_panel)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 18)
	_panel.add_child(outer)
	_panel_title = Label.new()
	_panel_title.add_theme_font_size_override("font_size", 32)
	_panel_title.add_theme_color_override("font_color", AMBER)
	outer.add_child(_panel_title)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(640, 560)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)
	_panel_box = VBoxContainer.new()
	_panel_box.add_theme_constant_override("separation", 12)
	_panel_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_panel_box)
	var close := Button.new()
	close.text = "Zurück (Esc)"
	close.custom_minimum_size = Vector2(180, 40)
	close.pressed.connect(func() -> void: _panel.visible = false)
	outer.add_child(close)
	_panel.visible = false


func _open_panel(title: String) -> void:
	_panel_title.text = title
	for c in _panel_box.get_children():
		c.queue_free()
	_panel.visible = true
	_panel.position.x = maxf(560.0, size.x - 760.0 - 80.0)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_menu") and _panel.visible:
		_panel.visible = false
		get_viewport().set_input_as_handled()


func _label(text: String, size_px: int = 20, col: Color = Color(0.85, 0.84, 0.8)) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", col)
	return l


## Speicherplätze: mode "new" = Neues Spiel hier beginnen, "load" = laden.
func _show_slots(mode: String) -> void:
	_confirm = ""
	_fill_slots(mode)


func _fill_slots(mode: String) -> void:
	_open_panel("Neues Spiel – Platz wählen" if mode == "new" else "Spiel laden")
	for n in GameState.SLOTS:
		var info := GameState.slot_info(n)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(col)
		col.add_child(_label("Platz %d" % (n + 1), 24, AMBER))
		if info.is_empty():
			col.add_child(_label("leer", 17, Color(0.55, 0.55, 0.52)))
		else:
			var h := float(info.get("hour", 7.0))
			var mins := int(float(info.get("play_seconds", 0.0)) / 60.0)
			col.add_child(_label("Tag %d, %02d:%02d Uhr   ·   gespielt %d Std. %02d Min." % [int(info.get("day", 1)), int(h), int(fmod(h, 1.0) * 60.0), mins / 60, mins % 60], 17))
			col.add_child(_label("gespeichert " + _nice_date(String(info.get("saved_at", ""))), 15, Color(0.6, 0.6, 0.56)))
		if mode == "new":
			var key := "new%d" % n
			var text := "Hier beginnen" if info.is_empty() else ("Wirklich überschreiben?" if _confirm == key else "Überschreiben")
			var b := Button.new()
			b.text = text
			b.custom_minimum_size = Vector2(230, 42)
			b.pressed.connect(func() -> void:
				if info.is_empty() or _confirm == key:
					GameState.new_game(n)
				else:
					_confirm = key
					_fill_slots(mode))
			row.add_child(b)
		elif not info.is_empty():
			var b := Button.new()
			b.text = "Laden"
			b.custom_minimum_size = Vector2(120, 42)
			b.pressed.connect(func() -> void: GameState.load_game(n))
			row.add_child(b)
			var key2 := "del%d" % n
			var d := Button.new()
			d.text = "Wirklich löschen?" if _confirm == key2 else "Löschen"
			d.custom_minimum_size = Vector2(150, 42)
			d.pressed.connect(func() -> void:
				if _confirm == key2:
					GameState.delete_slot(n)
					_confirm = ""
					if GameState.latest_slot() < 0:
						get_tree().reload_current_scene()
						return
				else:
					_confirm = key2
				_fill_slots(mode))
			row.add_child(d)
		_panel_box.add_child(row)
		_panel_box.add_child(HSeparator.new())
	_panel_box.add_child(_label("Das Spiel speichert jeden Morgen und beim Beenden von selbst. Stirbst du, beginnt der Tag neu.", 15, Color(0.6, 0.6, 0.56)))


static func _nice_date(iso: String) -> String:
	# 2026-11-11 13:05:00 -> 11.11.2026, 13:05
	var p := iso.replace("T", " ").split(" ")
	if p.size() < 2:
		return iso
	var d := p[0].split("-")
	return "%s.%s.%s, %s" % [d[2], d[1], d[0], p[1].left(5)] if d.size() == 3 else iso


func _show_settings() -> void:
	_open_panel("Einstellungen")
	_panel_box.add_child(SettingsPanel.new())


func _show_controls() -> void:
	_open_panel("Steuerung")
	for c: Array in CONTROLS:
		var row := HBoxContainer.new()
		var k := _label(String(c[0]), 19, AMBER)
		k.custom_minimum_size = Vector2(210, 0)
		row.add_child(k)
		var v := _label(String(c[1]), 19)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(v)
		_panel_box.add_child(row)


func _show_endings() -> void:
	_open_panel("Gesehene Enden  (%d von %d)" % [Settings.endings_seen.size(), Settings.endings().size()])
	for e: Dictionary in Settings.endings():
		var seen := Settings.endings_seen.has(String(e["id"]))
		var row := HBoxContainer.new()
		var n := _label(String(e["name"]) if seen else "???", 24, AMBER if seen else Color(0.45, 0.45, 0.43))
		n.custom_minimum_size = Vector2(260, 0)
		row.add_child(n)
		row.add_child(_label(("erreicht am " + String(Settings.endings_seen[e["id"]])) if seen else "noch nicht erreicht", 16, Color(0.6, 0.6, 0.56)))
		_panel_box.add_child(row)
	_panel_box.add_child(_label("Es gibt sieben Enden. Nicht alle davon sind gut.", 16, Color(0.6, 0.6, 0.56)))
