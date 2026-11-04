class_name HotbarHud
extends Control
## Schmale Leiste unten in der Bildmitte: Schnellplätze 1–9, der gewählte ist hervorgehoben.
## Blendet sich nach einem Wechsel nach ein paar Sekunden dezent aus.

const BOX := Vector2(58, 46)
const GAP := 6.0

var _boxes: Array[PanelContainer] = []
var _labels: Array[Label] = []
var _fade: float = 4.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 1.0
	anchor_bottom = 1.0
	var total := BOX.x * Inventory.SLOTS + GAP * (Inventory.SLOTS - 1)
	offset_left = -total * 0.5
	offset_right = total * 0.5
	offset_top = -BOX.y - 92
	offset_bottom = -92
	for i in Inventory.SLOTS:
		var p := PanelContainer.new()
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.position = Vector2(i * (BOX.x + GAP), 0)
		p.size = BOX
		add_child(p)
		var v := VBoxContainer.new()
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_theme_constant_override("separation", 0)
		p.add_child(v)
		var num := Label.new()
		num.text = str(i + 1)
		num.add_theme_font_size_override("font_size", 12)
		num.add_theme_color_override("font_color", Color(0.75, 0.72, 0.65))
		v.add_child(num)
		var l := Label.new()
		l.add_theme_font_size_override("font_size", 12)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.clip_text = true
		l.custom_minimum_size = Vector2(BOX.x - 8, 0)
		v.add_child(l)
		_boxes.append(p)
		_labels.append(l)
	Inventory.hotbar_changed.connect(_refresh)
	Inventory.changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	_fade = 4.0
	for i in Inventory.SLOTS:
		var id: String = Inventory.hotbar[i]
		_labels[i].text = Inventory.display_name(id) if id != "" and Inventory.count(id) > 0 else ""
		var st := StyleBoxFlat.new()
		var sel := i == Inventory.selected
		st.bg_color = Color(0.08, 0.07, 0.06, 0.75 if sel else 0.45)
		st.border_color = Color(0.95, 0.85, 0.6) if sel else Color(0.4, 0.35, 0.28, 0.7)
		st.set_border_width_all(2 if sel else 1)
		st.set_content_margin_all(4)
		_boxes[i].add_theme_stylebox_override("panel", st)


func _process(delta: float) -> void:
	_fade -= delta
	modulate.a = move_toward(modulate.a, 1.0 if _fade > 0.0 else 0.35, delta * 2.0)
