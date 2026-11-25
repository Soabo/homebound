class_name ChoiceDialog
extends CanvasLayer
## Einfaches Auswahlfenster mitten im Bild (Überschrift, Text, Knöpfe). Esc = Abbrechen.
## options: [{id, label, ok (bool), why (Text, wenn nicht wählbar)}]. on_pick(id) bekommt "" beim Abbrechen.

var title: String = ""
var text: String = ""
var options: Array = []
var on_pick: Callable
var _player: Player
## Spiel anhalten, solange das Fenster offen ist (Erklärung vor der ersten Belagerung)
var pause_game: bool = false
## Knopf „Zurück (Esc)“ anzeigen
var show_cancel: bool = true


static func open(tree: SceneTree, p_title: String, p_text: String, p_options: Array, callback: Callable) -> ChoiceDialog:
	var d := ChoiceDialog.new()
	d.title = p_title
	d.text = p_text
	d.options = p_options
	d.on_pick = callback
	tree.root.add_child(d)
	return d


func _ready() -> void:
	layer = 110
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("choice_dialog")
	_player = get_tree().get_first_node_in_group("player") as Player
	if _player:
		_player.input_locked = true
	if pause_game:
		get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(720, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.07, 0.08, 0.96)
	sb.border_color = Color(0.45, 0.42, 0.36)
	sb.set_border_width_all(1)
	sb.set_content_margin_all(22)
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	var h := Label.new()
	h.text = title
	h.add_theme_font_size_override("font_size", 24)
	h.add_theme_color_override("font_color", Color(0.92, 0.88, 0.8))
	box.add_child(h)
	if text != "":
		var t := Label.new()
		t.text = text
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		t.custom_minimum_size = Vector2(676, 0)
		t.add_theme_font_size_override("font_size", 17)
		t.add_theme_color_override("font_color", Color(0.78, 0.76, 0.72))
		box.add_child(t)
	for o: Dictionary in options:
		var b := Button.new()
		b.text = String(o.get("label", "?"))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 17)
		var ok := bool(o.get("ok", true))
		b.disabled = not ok
		if not ok and String(o.get("why", "")) != "":
			b.text += "\n    – " + String(o["why"])
		b.pressed.connect(_pick.bind(String(o.get("id", ""))))
		box.add_child(b)
	if show_cancel:
		var cancel := Button.new()
		cancel.text = "Zurück  (Esc)"
		cancel.pressed.connect(_pick.bind(""))
		box.add_child(cancel)
	# Mitte ausrichten, sobald die Größe feststeht
	await get_tree().process_frame
	panel.position = (get_viewport().get_visible_rect().size - panel.size) * 0.5


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_pick("" if show_cancel else String(options[0].get("id", "")) if not options.is_empty() else "")


func _pick(id: String) -> void:
	if is_queued_for_deletion():
		return
	if _player and is_instance_valid(_player):
		_player.input_locked = false
	if pause_game:
		get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	queue_free()
	if on_pick.is_valid():
		on_pick.call(id)
