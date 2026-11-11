class_name ResearchMenu
extends CanvasLayer
## Analysegerät und gefundene Notizen (GDD 12.4–12.6). Archiv und Notizen stehen auf dem Tablet (Couch);
## die Archiv-Inhalte baut fill_archive()/fill_notes(), damit das Tablet sie anzeigen kann.
## Die Welt läuft weiter, während man forscht.

var _root: Control
var _title: Label
var _info: Label
var _list: VBoxContainer
var _mode: String = ""   ## "", "station", "lab", "note"
var _station: String = "device"
var _note: String = ""
var _last_result: String = ""
var _tick: float = 0.0
var _exp_running: String = ""   ## laufendes Experiment (ID)
var _exp_left: float = 0.0


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


func open_station(st: String = "device") -> void:
	_last_result = ""
	_station = st
	_open("station")


## Labor-Übersicht: Plätze einbauen, Ladeschale, Wucherung.
func open_lab() -> void:
	_last_result = ""
	_open("lab")


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
	if _exp_running != "":
		_exp_left -= delta
		if _exp_left <= 0.0 or _mode != "station":
			_finish_experiment()
	if _mode in ["station", "lab"]:
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
		"lab": _fill_lab()
		"note": _fill_note()


# --- Stationen (Analysegerät und Labor) -----------------------------------

## Spielstunden lesbar: „ca. 3 Std.“ bzw. „ca. 1,5 Tage“.
static func fmt_hours(h: float) -> String:
	if h >= 20.0:
		return "ca. %s Tage" % ("%.1f" % (h / 24.0)).replace(".", ",")
	if h >= 10.0:
		return "ca. %d Std." % int(round(h))
	return "ca. %s Std." % ("%.1f" % h).replace(".", ",")


func _fill_station() -> void:
	var st := _station
	_title.text = Research.station_name(st)
	var info := ""
	if st == "device":
		info = "Strom: " + ("läuft" if PowerManager.has_power() else "AUS – der Generator muss laufen")
		if Research.tier >= 2:
			info = "Eigene Energie – arbeitet doppelt so schnell"
	else:
		var def: Dictionary = Research.lab_def().get("stations", {}).get(st, {})
		info = String(def.get("info", ""))
		if bool(def.get("power", false)):
			info += "   Strom: " + ("läuft" if PowerManager.has_power() else "AUS")
	if st == "shield":
		info += "   Was hier läuft, strahlt nachts nicht nach außen."
	_info.text = info
	var id := String(Research.stations.get(st, ""))
	if id != "":
		var a := Research.analysis(id)
		_list.add_child(_text("%s   (%s)" % [a.get("name", id), a.get("area", "")], 24, Color(0.85, 1.0, 1.0)))
		var tags := _tags(id)
		if tags != "":
			_list.add_child(_text(tags, 15, Color(0.9, 0.7, 0.55)))
		var pr := Research.progress_of(id)
		var status := "Fortschritt %d %%" % int(pr * 100.0)
		if pr < 1.0:
			status += "   –   noch " + fmt_hours(Research.hours_left(id))
			var why := Research.station_blocker(st)
			if why != "":
				status += "  (pausiert: %s)" % why
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
				var l := _text(String(exp.get("label", eid)) + _effect_hint(String(exp.get("effect", ""))), 19)
				l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				row.add_child(l)
				var blocker := Research.experiment_blocker(exp, st)
				if _exp_running == eid:
					row.add_child(_text("läuft … %d s" % int(ceil(_exp_left)), 16, Color(1.0, 0.85, 0.5)))
				elif blocker != "":
					row.add_child(_text(blocker, 16, Color(0.85, 0.55, 0.45)))
				elif _exp_running != "":
					row.add_child(_text("warten …", 16, Color(0.6, 0.6, 0.55)))
				else:
					var b := _button("Durchführen")
					b.pressed.connect(_on_experiment.bind(eid))
					row.add_child(b)
			_list.add_child(row)
		if _last_result != "":
			_list.add_child(_text(_last_result, 18, Color(1.0, 0.9, 0.6)))
		var finished := Research.done.has(id)
		var out := _button("Fund herausnehmen" if finished else "Herausnehmen")
		out.pressed.connect(func() -> void: Research.take_out(st))
		_list.add_child(out)
		if finished:
			_list.add_child(_text("Fertig untersucht. Der Fund liegt noch im Gerät – legst du etwas Neues ein, kommt er zurück in den Rucksack.", 16, Color(0.6, 0.85, 0.7)))
	if id == "" or Research.done.has(id):
		if id == "":
			_list.add_child(_text("Frei.", 22, Color(0.85, 1.0, 1.0)))
		var avail := Research.available_projects(st)
		var any := false
		for pid: String in avail:
			var a := Research.analysis(pid)
			var find := String(a.get("find", ""))
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 12)
			var tags := _tags(pid)
			var have := Inventory.count(find)
			var l := _text("%s   →  %s, %s%s" % [a.get("name", pid), a.get("area", ""), fmt_hours(Research.hours_needed(pid) * (1.0 - Research.progress_of(pid)) / Research.station_speed(st)),
				("   [" + tags + "]") if tags != "" else ""], 18, Color(0.88, 0.9, 0.88) if have > 0 else Color(0.55, 0.58, 0.58))
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(l)
			if have > 0:
				any = true
				var b := _button("Einlegen")
				b.pressed.connect(_on_insert.bind(pid))
				row.add_child(b)
			elif Research.seen.has(find):
				row.add_child(_text("braucht: %s" % Inventory.display_name(find), 15, Color(0.75, 0.6, 0.5)))
			else:
				continue
			_list.add_child(row)
		var locked := 0
		for pid: String in Research.data().get("analyses", {}):
			if Research.station_of(pid) == st and not Research.done.has(pid) and not Research.requirements_met(pid):
				locked += 1
		if not any:
			var hint := "Du hast nichts dabei, was sich hier untersuchen lässt."
			if st == "device" and Research.done.is_empty():
				hint += " Draußen im Wald soll etwas abgestürzt sein …"
			_list.add_child(_text(hint, 18, Color(0.6, 0.7, 0.7)))
		if locked > 0:
			_list.add_child(_text("Noch %d Projekt(e) an diesem Platz gesperrt – Voraussetzungen stehen im Forschungsbaum auf dem Tablet." % locked, 15, Color(0.55, 0.6, 0.62)))
	_add_send_button()


func _tags(id: String) -> String:
	var a := Research.analysis(id)
	var t: PackedStringArray = []
	if bool(a.get("living", false)):
		t.append("lebend – kann ausbrechen")
	if float(a.get("signature", 0.0)) > 0.0 and Research.station_of(id) != "shield":
		t.append("strahlt nachts nach außen")
	return ", ".join(t)


static func _effect_hint(effect: String) -> String:
	match effect:
		"noise": return "  (laut)"
		"signal": return "  (strahlt kurz grell)"
		"drain": return "  (zieht viel Strom)"
		"hurt": return "  (riskant)"
		"escape": return "  (die Probe wird unruhig)"
	return ""


func _add_send_button() -> void:
	# Ergebnisse werden nicht hier gelesen, sondern aufs Tablet geschickt
	var unsent := Research.unsent_count()
	if unsent > 0:
		var send := _button("Ergebnisse ans Tablet senden (%d)" % unsent)
		send.custom_minimum_size = Vector2(320, 42)
		send.pressed.connect(func() -> void:
			if Research.send_results() > 0:
				_last_result = "Gesendet. Nachlesen auf dem Tablet (Couch) im Archiv."
				SoundBank.play_ui(self, "signal", -10.0, 1.8)
			_refresh())
		_list.add_child(send)
	else:
		_list.add_child(_text("Alle Ergebnisse sind auf dem Tablet.", 16, Color(0.55, 0.7, 0.7)))


func _on_insert(pid: String) -> void:
	_last_result = ""
	if Research.insert_project(_station, pid):
		SoundBank.play_ui(self, "menu_click", -4.0)


## Ein Experiment dauert einen kurzen Moment (research.json lab.experiment_seconds), dann liegt das Ergebnis vor.
func _on_experiment(eid: String) -> void:
	if _exp_running != "":
		return
	_exp_running = eid
	_exp_left = float(Research.lab_def().get("experiment_seconds", 3.0))
	SoundBank.play_ui(self, "static", -14.0, 1.2)
	_refresh()


func _finish_experiment() -> void:
	var eid := _exp_running
	_exp_running = ""
	var r := Research.run_experiment(eid, _station)
	if r != "":
		_last_result = "Experiment durchgeführt – das Ergebnis kann ans Tablet gesendet werden."
		SoundBank.play_ui(self, "signal", -10.0, 1.6)
	_refresh()


# --- Labor-Übersicht ------------------------------------------------------

func _fill_lab() -> void:
	_title.text = "Labor im Bad"
	_info.text = "Jeder Platz arbeitet für sich – mehrere Projekte laufen gleichzeitig. Strom brauchen Mikroskop, Abschirmkasten und Auswertungsplatz."
	var defs: Dictionary = Research.lab_def().get("stations", {})
	for st: String in defs:
		var def: Dictionary = defs[st]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(col)
		if Research.station_built(st):
			var id := String(Research.stations.get(st, ""))
			col.add_child(_text("✓ %s" % def.get("name", st), 20, Color(0.75, 0.95, 0.85)))
			col.add_child(_text(("läuft: %s (%d %%)" % [Research.analysis(id).get("name", id), int(Research.progress_of(id) * 100.0)]) if id != "" else "frei", 15, Color(0.6, 0.75, 0.75)))
			var b := _button("Öffnen")
			b.pressed.connect(func() -> void: open_station(st))
			row.add_child(b)
		else:
			col.add_child(_text(String(def.get("name", st)), 20, Color(0.85, 0.85, 0.75)))
			col.add_child(_text(String(def.get("info", "")), 15, Color(0.6, 0.65, 0.65)))
			col.add_child(_text("Material: " + _needs_text(def.get("needs", {})), 15, Color(0.7, 0.7, 0.6)))
			var why := Research.station_build_blocker(st)
			if why != "":
				row.add_child(_text(why, 15, Color(0.85, 0.55, 0.45)))
			else:
				var b := _button("Einbauen")
				b.pressed.connect(func() -> void:
					var err := Research.build_station(st)
					_last_result = err if err != "" else ""
					SoundBank.play_ui(self, "menu_click", -4.0)
					_refresh())
				row.add_child(b)
		_list.add_child(row)
	# Ladeschale
	var ch: Dictionary = Research.lab_def().get("charger", {})
	if Research.charger_built:
		var row := HBoxContainer.new()
		var l := _text("✓ %s – %d geladene Zelle(n), nächste in %s" % [ch.get("name", "Ladeschale"), Research.charger_ready,
			fmt_hours(maxf(float(ch.get("hours", 48.0)) - Research.charger_hours, 0.0))], 18, Color(0.75, 0.95, 0.85))
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		if Research.charger_ready > 0:
			var b := _button("Zelle nehmen")
			b.pressed.connect(func() -> void:
				Research.take_charged_cell()
				_refresh())
			row.add_child(b)
		_list.add_child(row)
	elif Research.has_grant("charger"):
		var row := HBoxContainer.new()
		var l := _text("%s – %s  (Material: %s)" % [ch.get("name", ""), ch.get("info", ""), _needs_text(ch.get("needs", {}))], 16, Color(0.85, 0.85, 0.75))
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		var why := Research.charger_blocker()
		if why != "":
			row.add_child(_text(why, 15, Color(0.85, 0.55, 0.45)))
		else:
			var b := _button("Bauen")
			b.pressed.connect(func() -> void:
				Research.build_charger()
				_refresh())
			row.add_child(b)
		_list.add_child(row)
	if Research.lab_bloom:
		var b := _button("Wucherung im Bad abkratzen")
		b.custom_minimum_size = Vector2(320, 40)
		b.pressed.connect(func() -> void:
			Research.clean_bloom()
			_refresh())
		_list.add_child(b)
	var drops := AlienDrops.get_for(get_tree())
	if drops and drops.loose_count() > 0:
		_list.add_child(_text("Irgendwo im Haus ist noch eine entkommene Probe. Nachts hört man sie kratzen.", 17, Color(1.0, 0.75, 0.55)))
	var sig := Research.signature()
	_list.add_child(_text("Fremde Signatur gerade: %s" % signature_bar(sig), 16, Color(0.7, 0.75, 0.8)))
	if _last_result != "":
		_list.add_child(_text(_last_result, 17, Color(1.0, 0.85, 0.6)))
	_add_send_button()


static func _needs_text(needs: Dictionary) -> String:
	var parts: PackedStringArray = []
	for it: String in needs:
		parts.append("%s %d/%d" % [Inventory.display_name(it), Inventory.count(it), int(needs[it])])
	return ", ".join(parts)


## ▮▮▮▯▯ – fünf Stufen bis Signatur 1.25
static func signature_bar(sig: float) -> String:
	var n := clampi(int(ceil(sig / 0.25)), 0, 5)
	var word := "keine" if sig < 0.05 else ("schwach" if sig < 0.4 else ("deutlich" if sig < 0.9 else "grell"))
	return "%s%s  %s" % ["▮".repeat(n), "▯".repeat(5 - n), word]


# --- Archiv -------------------------------------------------------------

## Archiv (für das Tablet): nur Ergebnisse, die vom Analysegerät gesendet wurden.
static func fill_archive(list: VBoxContainer) -> void:
	var total := (Research.data().get("analyses", {}) as Dictionary).size()
	var sent_done := Research.done.filter(func(id: String) -> bool: return Research.is_sent(id)).size()
	list.add_child(_text("Analysen %d / %d     Erkenntnisse %d / %d     Gerät: %s" % [sent_done, total,
		Research.links_done.size(), (Research.data().get("links", {}) as Dictionary).size(), Research.device_name()], 16, Color(0.6, 0.7, 0.75)))
	var analyses: Dictionary = Research.data().get("analyses", {})
	var listed_finds := {}   # Funde, die schon als „noch nicht untersucht“ dastehen (keine Doppelten)
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
			elif Research.running_at(id) != "" or not sent_exp.is_empty() or Research.done.has(id):
				var state := "Analyse fertig – Ergebnis noch am Analysegerät" if Research.done.has(id) else "wird untersucht (%d %%)" % int(Research.progress_of(id) * 100.0)
				col.add_child(_text("◐ %s – %s" % [a.get("name", id), state], 17, Color(0.8, 0.85, 0.7)))
			elif Research.seen.has(find) and Research.requirements_met(id) and not listed_finds.has(find + "/" + str(a.get("requires", []).is_empty())):
				# Folgeprojekte (mit Voraussetzung) erst, wenn sie möglich sind – und unter eigenem Namen
				listed_finds[find + "/" + str(a.get("requires", []).is_empty())] = true
				var pr := Research.progress_of(id)
				var title := ("Fund: %s" % Inventory.display_name(find)) if (a.get("requires", []) as Array).is_empty() else ("%s (%s)" % [a.get("name", id), Inventory.display_name(find)])
				col.add_child(_text("○ %s – noch nicht untersucht%s" % [title, (" (%d %%)" % int(pr * 100.0)) if pr > 0.0 else ""], 17, Color(0.7, 0.7, 0.65)))
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
				if revealed:
					# anklicken = groß ansehen
					tr.mouse_filter = Control.MOUSE_FILTER_STOP
					tr.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
					tr.tooltip_text = "Anklicken: groß ansehen"
					var title2 := String(a.get("name", id))
					tr.gui_input.connect(func(ev: InputEvent) -> void:
						if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
							show_big_picture(tr, pic, title2))
				row.add_child(tr)
			row.add_child(col)
			list.add_child(row)
		if not any:
			list.add_child(_text("   – noch nichts –", 15, Color(0.45, 0.5, 0.5)))
	# Verknüpfungen und Hypothesen
	list.add_child(_text("Verknüpfungen und Hypothesen", 22, Color(1.0, 0.85, 0.55)))
	var links: Dictionary = Research.data().get("links", {})
	var hidden_q := 0
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
			# nur Fragen zeigen, zu denen man schon eine Spur hat
			var parts: PackedStringArray = []
			var known := 0
			for n: String in l.get("needs", []):
				var a := Research.analysis(n)
				if Research.done.has(n) and Research.is_sent(n):
					known += 1
					parts.append(String(a.get("name", "?")))
				else:
					parts.append("???")
			if known > 0:
				list.add_child(_text("? Offene Frage – braucht: %s" % ", ".join(parts), 16, Color(0.6, 0.6, 0.55)))
			else:
				hidden_q += 1
	if hidden_q > 0:
		list.add_child(_text("… und %d weitere Fragen, zu denen dir noch jede Spur fehlt." % hidden_q, 15, Color(0.5, 0.52, 0.5)))


## Forschungsbild groß über dem Tablet (Klick oder Esc schließt).
static func show_big_picture(from: Control, pic: Texture2D, title: String) -> void:
	var layer: Node = from
	while layer and not (layer is CanvasLayer):
		layer = layer.get_parent()
	if layer == null:
		return
	var over := Control.new()
	over.name = "BigPicture"
	over.set_anchors_preset(Control.PRESET_FULL_RECT)
	over.mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.88)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	over.add_child(bg)
	var tr := TextureRect.new()
	tr.texture = pic
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	tr.offset_top = 60
	tr.offset_bottom = -60
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	over.add_child(tr)
	var l := _text("%s      (Klicken oder Esc: schließen)" % title, 22, Color(0.9, 0.9, 0.85))
	l.position = Vector2(40, 18)
	over.add_child(l)
	over.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed:
			over.queue_free())
	layer.add_child(over)


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
