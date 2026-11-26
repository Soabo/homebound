class_name TutorialCard
extends PanelContainer
## Notizkarte der Einführung oben links (Christian 26.11.): kleiner Kopf „ERSTER TAG · 2/9“, Gedanke in Handschrift,
## Tasten als Kästchen, darunter eine kurze Erklärung. Erledigt = Haken, Karte blendet aus, die nächste kommt.

const WIDTH := 470.0

var _box: VBoxContainer
var _head: Label
var _thought: Label
var _keys: VBoxContainer
var _text: Label
var _tick: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", UiStyle.paper(0.78, 8, 18))
	custom_minimum_size = Vector2(WIDTH, 0)
	position = Vector2(30, 110)
	_box = VBoxContainer.new()
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_theme_constant_override("separation", 8)
	add_child(_box)
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(top)
	_head = UiStyle.label(top, "ui_bold", 18, UiStyle.EMBER)
	_head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tick = UiStyle.label(top, "ui_bold", 18, Color(0.55, 0.85, 0.55), "")
	_thought = UiStyle.label(_box, "thought", 34, UiStyle.INK)
	_thought.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_thought.custom_minimum_size = Vector2(WIDTH - 36.0, 0)
	_keys = VBoxContainer.new()
	_keys.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_keys.add_theme_constant_override("separation", 5)
	_box.add_child(_keys)
	_text = UiStyle.label(_box, "ui", 20, UiStyle.INK_DIM)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(WIDTH - 36.0, 0)
	_text.add_theme_constant_override("outline_size", 0)
	modulate.a = 0.0
	visible = false


func show_step(st: Dictionary, n: int, total: int) -> void:
	_head.text = "ERSTER TAG  ·  %d / %d" % [n, total]
	_tick.text = ""
	_thought.text = String(st.get("thought", ""))
	for c in _keys.get_children():
		_keys.remove_child(c)
		c.queue_free()
	for k: Array in Array(st.get("keys", [])):
		var row := UiStyle.key_row(_keys, String(k[0]), String(k[1]), 20)
		(row.get_child(row.get_child_count() - 1) as Label).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		(row.get_child(row.get_child_count() - 1) as Label).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text.text = String(st.get("text", ""))
	_text.visible = _text.text != ""
	visible = true
	position = Vector2(30, 110)
	size = Vector2(WIDTH, 0)
	_fit.call_deferred()
	UiStyle.fade_in(self, 0.6, 0.0)


## Höhe an den Inhalt anpassen (umbrechende Zeilen kennen ihre Höhe erst nach dem Layout).
func _fit() -> void:
	size = Vector2(WIDTH, 0)
	reset_size()


## Schritt erledigt: Haken, dann ausblenden.
func complete() -> void:
	_tick.text = "✓ erledigt"
	var tw := create_tween()
	tw.tween_interval(0.9)
	tw.tween_property(self, "modulate:a", 0.0, 0.6)


func hide_card() -> void:
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.5)
	tw.tween_callback(func() -> void: visible = false)
