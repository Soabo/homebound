class_name SettingsPanel
extends VBoxContainer
## Einstellungen (Hauptmenü und Pause): Lautstärke, Maus, Helligkeit, Grafikqualität, Vollbild.
## Jede Änderung wird sofort angewendet und gespeichert (Settings).

const QUALITY := [["low", "Niedrig"], ["medium", "Mittel"], ["high", "Hoch"]]


func _ready() -> void:
	add_theme_constant_override("separation", 14)
	_slider("Lautstärke", "volume", 0.0, 1.0, 0.05, func(v: float) -> String: return "%d %%" % int(round(v * 100.0)))
	_slider("Mausempfindlichkeit", "mouse", 0.3, 2.5, 0.05, func(v: float) -> String: return ("%.2f" % v).replace(".", ",") + " ×")
	_slider("Helligkeit", "brightness", 0.6, 1.8, 0.05, func(v: float) -> String: return "%d %%" % int(round(v * 100.0)))
	var row := _row("Grafikqualität")
	var opt := OptionButton.new()
	for q: Array in QUALITY:
		opt.add_item(String(q[1]))
		if q[0] == Settings.quality:
			opt.select(opt.item_count - 1)
	opt.custom_minimum_size = Vector2(220, 36)
	opt.item_selected.connect(func(i: int) -> void: Settings.set_value("quality", String(QUALITY[i][0])))
	row.add_child(opt)
	# Grafikstil (Christian 25.11.): Retro = grobe Pixel wie bisher, Klar = volle Auflösung, weiche Texturen, runde Kanten
	var rl := _row("Grafikstil")
	var lo := OptionButton.new()
	for pair: Array in [["retro", "Retro (Pixel)"], ["klar", "Klar (weich, runde Kanten)"]]:
		lo.add_item(String(pair[1]))
		if pair[0] == Settings.look:
			lo.select(lo.item_count - 1)
	lo.custom_minimum_size = Vector2(220, 36)
	lo.tooltip_text = "Bildschicht wechselt sofort. Texturen und Kanten ändern sich beim nächsten Laden eines Spielstands."
	lo.item_selected.connect(func(i: int) -> void:
		var style: String = ["retro", "klar"][i]
		Settings.set_value("look", style)
		EventBus.notify("Grafikstil: %s – Texturen und Kanten ab dem nächsten Laden" % ("Retro" if style == "retro" else "Klar"), 4.0))
	rl.add_child(lo)
	if OS.get_name() != "Web":
		var r2 := _row("Vollbild")
		var cb := CheckBox.new()
		cb.button_pressed = Settings.fullscreen
		cb.toggled.connect(func(on: bool) -> void: Settings.set_value("fullscreen", on))
		r2.add_child(cb)
	var rf := _row("Bilder pro Sekunde (max.)")
	var fo := OptionButton.new()
	for v: int in Settings.FPS_CHOICES:
		fo.add_item(Settings.fps_name(v))
		if v == Settings.max_fps:
			fo.select(fo.item_count - 1)
	fo.custom_minimum_size = Vector2(220, 36)
	fo.item_selected.connect(func(i: int) -> void: Settings.set_value("max_fps", int(Settings.FPS_CHOICES[i])))
	rf.add_child(fo)
	if OS.get_name() != "Web":
		var rv := _row("Bildsynchronisierung")
		var vs := CheckBox.new()
		vs.button_pressed = Settings.vsync
		vs.tooltip_text = "An: kein Bildreißen, die Bildrate folgt dem Bildschirm (z. B. 144 Hz). Aus: so schnell wie möglich."
		vs.toggled.connect(func(on: bool) -> void: Settings.set_value("vsync", on))
		rv.add_child(vs)
	var rc := _row("Bildrate anzeigen")
	var fc := CheckBox.new()
	fc.button_pressed = Settings.show_fps
	fc.toggled.connect(func(on: bool) -> void: Settings.set_value("show_fps", on))
	rc.add_child(fc)
	var r3 := _row("Schleich-Anzeige")
	var sh := CheckBox.new()
	sh.button_pressed = Settings.stealth_hud
	sh.tooltip_text = "Kleines Auge über dem Schnellplatz: wie sehr dich etwas bemerkt, wie sichtbar und wie laut du bist."
	sh.toggled.connect(func(on: bool) -> void: Settings.set_value("stealth_hud", on))
	r3.add_child(sh)
	var hint := Label.new()
	hint.text = "Niedrig rechnet mit kleinerer Auflösung und weniger Schatten – gut für ältere Rechner und den Browser."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(520, 0)
	hint.add_theme_font_size_override("font_size", 15)
	hint.add_theme_color_override("font_color", Color(0.62, 0.62, 0.58))
	add_child(hint)


func _row(label: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(230, 0)
	l.add_theme_font_size_override("font_size", 20)
	row.add_child(l)
	add_child(row)
	return row


func _slider(label: String, key: String, lo: float, hi: float, step: float, fmt: Callable) -> void:
	var row := _row(label)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = float(Settings.get(key))
	s.custom_minimum_size = Vector2(260, 28)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(s)
	var v := Label.new()
	v.text = fmt.call(s.value)
	v.custom_minimum_size = Vector2(80, 0)
	v.add_theme_font_size_override("font_size", 18)
	row.add_child(v)
	s.value_changed.connect(func(x: float) -> void:
		v.text = fmt.call(x)
		Settings.set_value(key, x))
