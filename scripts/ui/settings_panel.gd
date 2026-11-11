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
	if OS.get_name() != "Web":
		var r2 := _row("Vollbild")
		var cb := CheckBox.new()
		cb.button_pressed = Settings.fullscreen
		cb.toggled.connect(func(on: bool) -> void: Settings.set_value("fullscreen", on))
		r2.add_child(cb)
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
