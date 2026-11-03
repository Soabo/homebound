class_name PauseMenu
extends CanvasLayer
## Pausenmenü (Esc): Weiter / Beenden.

var _root: Control


func _ready() -> void:
	name = "PauseMenu"
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	center.add_child(box)

	var title := Label.new()
	title.text = "Pause"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	box.add_child(title)

	var resume := _button(box, "Weiter")
	resume.pressed.connect(func() -> void: set_paused(false))
	var quit := _button(box, "Spiel beenden")
	quit.pressed.connect(func() -> void: get_tree().quit())

	visible = false


func _button(parent: Control, text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(320, 56)
	b.add_theme_font_size_override("font_size", 24)
	parent.add_child(b)
	return b


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_menu"):
		set_paused(not get_tree().paused)
		get_viewport().set_input_as_handled()


func set_paused(value: bool) -> void:
	get_tree().paused = value
	visible = value
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if value else Input.MOUSE_MODE_CAPTURED
