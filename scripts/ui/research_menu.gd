class_name ResearchMenu
extends CanvasLayer
## Analysegerät und gefundene Notizen (GDD 12.4–12.6). Archiv und Notizen stehen auf dem Tablet (Couch);
## die Archiv-Inhalte baut fill_archive()/fill_notes(), damit das Tablet sie anzeigen kann.
## Die Welt läuft weiter, während man forscht.

var _root: Control
var _title: Label
var _info: Label
var _list: VBoxContainer
var _mode: String = ""   ## "", "station", "archive", "note"
var _note: String = ""
var _last_result: String = ""
var _tick: float = 0.0


func _ready() -> void:
	name = "ResearchMenu"
	layer = 8
	add_to_group("research_menu")
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.visible = false
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var panel := PanelContainer.new()
	panel.anchor_left = 0.15
	panel.anchor_right = 0.85
	panel.anchor_top = 0.07
	panel.anchor_bottom = 0.93
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.06, 0.07, 0.96)
	style.border_color = Color(0.3, 0.6, 0.65)
	style.set_border_width_all(2)
	style.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", style)
	_root.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 32)
	_title.add_theme_color_override("font_color", Color(0.7, 0.95, 1.0))
	v.add_child(_title)
	_info = Label.new()
	_info.add_theme_font_size_override("font_size", 17)
	_info.add_theme_color_override("font_color", Color(0.7, 0.8, 0.8))
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD
	v.add_child(_info)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_list)
	var hint := Label.new()
	hint.text = "Esc  schließen"
	hint.add_theme_font_size_override("font_size", 15)
	hint.add_theme_color_override("font_color", Color(0.5, 0.6, 0.6))
	v.add_child(hint)
	Research.changed.connect(_refresh)


func _input(event: InputEvent) -> void:
	if _mode != "" and (event.is_action_pressed("pause_menu") or event.is_action_pressed("inventory")):
		close()
		get_viewport().set_input_as_handled()


func _player_free() -> bool:
	var p := get_tree().get_first_node_in_group("player") as Player
	var menus := get_tree().get_first_node_in_group("game_menus") as GameMenus
	return p != null and not p.input_locked and not get_tree().paused and not (menus and menus.is_open())


func open_station() -> void:
	_last_result = ""
	_open("station")


func open_note(id: String) -> void:
	_note = id
	_open("note")


func is_open() -> bool:
	return _mode != ""


func _open(m: String) -> void:
	var was_open := _mode != ""
	_mode = m
	_root.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var p := get_tree().get_first_node_in_group("player") as Player
	if p and not was_open:
		p.input_locked = true
	SoundBank.play_ui(self, "menu_click", -6.0)
	_refresh()


func close() -> void:
	if _mode == "":
		return
	_mode = ""
	_root.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var p := get_tree().get_first_node_in_group("player") as Player
	if p:
		p.input_locked = false


func _process(delta: float) -> void:
	if _mode == "station":
		_tick -= delta
		if _tick <= 0.0:
			_tick = 1.0
			_refresh()


func _refresh() -> void:
	if _mode == "":
		return
	for c in _list.get_children():
		c.queue_free()
	match _mode:
		"station": _fill_station()
		"note": _fill_note()


# --- Analysegerät -----------------------------------------------------

func _fill_station() -> void:
	_title.text = Research.device_name()
	var power := "Strom: " + ("läuft" if PowerManager.has_power() else "AUS – der Generator muss laufen")
	if Research.tier >= 2:
		power = "Eigene Energie – arbeitet doppelt so schnell"
	_info.text = power
	if Research.slot != "":
		var id := Research.slot
		var a := Research.analysis(id)
		_list.add_child(_text("%s   (%s)" % [a.get("name", id), a.get("area", "")], 24, Color(0.85, 1.0, 1.0)))
		var pr := Research.progress_of(id)
		var left := maxf(Research.hours_needed(id) * (1.0 - pr) / float(Research.SPEED.get(Research.tier, 1.0)), 0.0)
		var status := "Analyse %d %%" % int(pr * 100.0)
		if pr < 1.0:
			status += "   –   noch etwa %.1f Std." % left + ("" if Research.has_power_for_analysis() else "  (pausiert: kein Strom)")
		_list.add_child(_bar(pr))
		_list.add_child(_text(status, 18, Color(0.7, 0.85, 0.85)))
		_list.add_child(_text("Experimente:", 20, Color(0.9, 0.9, 0.8)))
		for exp: Dictionary in a.get("experiments", []):
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 12)
			var eid: String = exp.get("id", "")
			if Research.experiment_done(id, eid):
				var where := "auf dem Tablet" if Research.is_sent("%s/%s" % [id, eid]) else "Ergebnis liegt vor"
				var l := _text("✓ %s – %s" % [exp.get("label", eid), where], 17, Color(0.6, 0.9, 0.7))
				l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				row.add_child(l)
			else:
				var l := _text(String(exp.get("label", eid)), 19)
				l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				row.add_child(l)
				var blocker := Research.experiment_blocker(exp)
				if blocker != "":
					row.add_child(_text(blocker, 16, Color(0.85, 0.55, 0.45)))
				else:
					var b := _button("Durchführen")
					b.pressed.connect(_on_experiment.bind(eid))
					row.add_child(b)
			_list.add_child(row)
		if _last_result != "":
			_list.add_child(_text(_last_result, 18, Color(1.0, 0.9, 0.6)))
		var out := _button("Herausnehmen")
		out.pressed.connect(func() -> void: Research.take_out())
		_list.add_child(out)
	else:
		_list.add_child(_text("Kein Fund eingelegt.", 22, Color(0.85, 1.0, 1.0)))
		var any := false
		for find in Inventory.items:
			var aid := Research.analysis_for_find(find)
			if aid == "" or Research.done.has(aid):
				continue
			any = true
			var row := HBoxContainer.new()
			var l := _text("%s  ×%d   →  %s" % [Inventory.display_name(find), Inventory.count(find), Research.analysis(aid).get("area", "")], 19)
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(l)
			var b := _button("Einlegen")
			b.pressed.connect(_on_insert.bind(find))
			row.add_child(b)
			_list.add_child(row)
		if not any:
			_list.add_child(_text("Du hast keine unerforschten Funde dabei. Draußen im Wald soll etwas abgestürzt sein …", 18, Color(0.6, 0.7, 0.7)))
	# Ergebnisse werden nicht hier gelesen, sondern aufs Tablet geschickt
	var unsent := Research.unsent_results().size()
	if unsent > 0:
		var send := _button("Ergebnisse ans Tablet senden (%d)" % unsent)
		send.custom_minimum_size = Vector2(320, 42)
		send.pressed.connect(func() -> void:
			if Research.send_results() > 0:
				_last_result = "Gesendet. Nachlesen auf dem Tablet (Couch) im Alien-Archiv."
				SoundBank.play_ui(self, "signal", -10.0, 1.8)
			_refresh())
		_list.add_child(send)
	else:
		_list.add_child(_text("Alle Ergebnisse sind auf dem Tablet.", 16, Color(0.55, 0.7, 0.7)))


func _on_insert(find: String) -> void:
	_last_result = ""
	if Research.insert(find):
		SoundBank.play_ui(self, "menu_click", -4.0)


func _on_experiment(eid: String) -> void:
	var r := Research.run_experiment(eid)
	if r != "":
		_last_result = "Experiment durchgeführt – das Ergebnis kann ans Tablet gesendet werden."
		SoundBank.play_ui(self, "signal", -10.0, 1.6)
	_refresh()


# --- Archiv -------------------------------------------------------------

## Alien-Archiv (für das Tablet): nur Ergebnisse, die vom Analysegerät gesendet wurden.
static func fill_archive(list: VBoxContainer) -> void:
	var total := (Research.data().get("analyses", {}) as Dictionary).size()
	var sent_done := Research.done.filter(func(id: String) -> bool: return Research.is_sent(id)).size()
	list.add_child(_text("Analysen %d / %d     Erkenntnisse %d / %d     Gerät: %s" % [sent_done, total,
		Research.links_done.size(), (Research.data().get("links", {}) as Dictionary).size(), Research.device_name()], 16, Color(0.6, 0.7, 0.75)))
	var analyses: Dictionary = Research.data().get("analyses", {})
	for area: String in Research.data().get("areas", []):
		list.add_child(_text(area, 22, Color(0.7, 0.95, 1.0)))
		var any := false
		for id in analyses:
			var a: Dictionary = analyses[id]
			if a.get("area", "") != area:
				continue
			var find: String = a.get("find", "")
			var sent_exp: Array = []
			for exp: Dictionary in a.get("experiments", []):
				if Research.is_sent("%s/%s" % [id, exp.get("id", "")]):
					sent_exp.append(exp)
			# Eintrag: Bild links, Text rechts. Bild erst richtig, wenn das Ergebnis gesendet ist – vorher abgedunkelt.
			var col := VBoxContainer.new()
			col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			col.add_theme_constant_override("separation", 4)
			var revealed := false
			if Research.done.has(id) and Research.is_sent(id):
				revealed = true
				col.add_child(_text("✓ %s" % a.get("name", id), 19, Color(0.85, 0.95, 0.9)))
				col.add_child(_text(String(a.get("summary", "")), 16, Color(0.78, 0.86, 0.84)))
			elif Research.slot == id or not sent_exp.is_empty() or Research.done.has(id):
				var state := "Analyse fertig – Ergebnis noch am Analysegerät" if Research.done.has(id) else "wird untersucht (%d %%)" % int(Research.progress_of(id) * 100.0)
				col.add_child(_text("◐ %s – %s" % [a.get("name", id), state], 17, Color(0.8, 0.85, 0.7)))
			elif Research.seen.has(find):
				var pr := Research.progress_of(id)
				col.add_child(_text("○ Fund: %s – noch nicht untersucht%s" % [Inventory.display_name(find), (" (%d %%)" % int(pr * 100.0)) if pr > 0.0 else ""], 17, Color(0.7, 0.7, 0.65)))
			else:
				continue
			any = true
			for exp: Dictionary in sent_exp:
				col.add_child(_text("· %s: %s" % [exp.get("label", ""), exp.get("text", "")], 15, Color(0.6, 0.75, 0.75)))
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 14)
			var pic := research_picture(find)
			if pic:
				var tr := TextureRect.new()
				tr.texture = pic
				tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
				tr.custom_minimum_size = Vector2(210, 210) if revealed else Vector2(90, 90)
				tr.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
				tr.modulate = Color.WHITE if revealed else Color(0.25, 0.27, 0.3)
				row.add_child(tr)
			row.add_child(col)
			list.add_child(row)
		if not any:
			list.add_child(_text("   – noch nichts –", 15, Color(0.45, 0.5, 0.5)))
	# Verknüpfungen und Hypothesen
	list.add_child(_text("Verknüpfungen und Hypothesen", 22, Color(1.0, 0.85, 0.55)))
	var links: Dictionary = Research.data().get("links", {})
	for lid in links:
		var l: Dictionary = links[lid]
		if Research.links_done.has(lid):
			list.add_child(_text("◆ %s – %s" % [l.get("name", lid), l.get("text", "")], 17, Color(1.0, 0.92, 0.75)))
		elif Research.can_link(lid):
			var row := HBoxContainer.new()
			var names: PackedStringArray = []
			for n: String in l.get("needs", []):
				names.append(Research.analysis(n).get("name", n))
			var t := _text("? Passt das zusammen: %s" % " + ".join(names), 18, Color(1.0, 0.85, 0.5))
			t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(t)
			var b := _button("Verknüpfen")
			b.pressed.connect(func() -> void: Research.link(lid))
			row.add_child(b)
			list.add_child(row)
		else:
			var parts: PackedStringArray = []
			for n: String in l.get("needs", []):
				var a := Research.analysis(n)
				parts.append(String(a.get("name", "?")) if Research.done.has(n) and Research.is_sent(n) else "???")
			list.add_child(_text("? Offene Frage – braucht: %s" % ", ".join(parts), 16, Color(0.6, 0.6, 0.55)))


## Bild zum Fund aus assets/research/<id>.jpg|png (KI-Bilder von Christian), sonst null.
static func research_picture(find: String) -> Texture2D:
	for ext: String in ["jpg", "png", "webp"]:
		var path := "res://assets/research/%s.%s" % [find, ext]
		if ResourceLoader.exists(path):
			return load(path) as Texture2D
	return null


## Gefundene Notizen (für das Tablet).
static func fill_notes(list: VBoxContainer) -> void:
	if Research.notes.is_empty():
		list.add_child(_text("Noch keine Notizen gefunden.", 17, Color(0.6, 0.6, 0.65)))
		return
	for nid: String in Research.notes:
		var n: Dictionary = Research.data().get("notes", {}).get(nid, {})
		list.add_child(_text(String(n.get("name", nid)), 21, Color(0.95, 0.88, 0.7)))
		list.add_child(_text(String(n.get("text", "")), 17, Color(0.85, 0.82, 0.72)))


func _fill_note() -> void:
	var n: Dictionary = Research.data().get("notes", {}).get(_note, {})
	_title.text = String(n.get("name", "Notiz"))
	_info.text = "Auf dem Tablet unter „Notizen“ abgelegt."
	_list.add_child(_text(String(n.get("text", "")), 22, Color(0.92, 0.88, 0.76)))


# --- Bausteine ----------------------------------------------------------

static func _text(t: String, size: int = 19, color: Color = Color(0.88, 0.9, 0.88)) -> Label:
	var l := Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	l.custom_minimum_size = Vector2(200, 0)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func _button(t: String) -> Button:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = Vector2(150, 38)
	b.add_theme_font_size_override("font_size", 17)
	return b


static func _bar(v: float) -> ProgressBar:
	var p := ProgressBar.new()
	p.min_value = 0.0
	p.max_value = 1.0
	p.value = v
	p.show_percentage = false
	p.custom_minimum_size = Vector2(0, 14)
	return p
