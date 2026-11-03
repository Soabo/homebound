class_name RetroFilter
extends CanvasLayer
## Vollbild-Filter für den Retro-Horror-Look (F2 schaltet ihn zum Vergleich aus).
## Die Pixelgröße passt sich der Fensterhöhe an: ca. 360 "Retro-Zeilen".

const VIRTUAL_HEIGHT := 360.0

var _rect: ColorRect
var _mat: ShaderMaterial
var enabled: bool = true


func _ready() -> void:
	name = "RetroFilter"
	layer = 1
	process_mode = Node.PROCESS_MODE_ALWAYS
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://shaders/retro_screen.gdshader")
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.material = _mat
	add_child(_rect)
	get_viewport().size_changed.connect(_update_pixel_size)
	_update_pixel_size()


func _update_pixel_size() -> void:
	var h := float(get_viewport().get_visible_rect().size.y)
	_mat.set_shader_parameter("pixel_size", maxf(1.0, roundf(h / VIRTUAL_HEIGHT)))
	_apply_render_scale()


## Der Filter zeigt ohnehin nur ~360 Zeilen. Die 3D-Welt muss deshalb nicht in voller
## Bildschirmauflösung berechnet werden: etwa doppelt so viele Zeilen reichen.
## Das spart auf großen Bildschirmen einen Großteil der Grafikarbeit.
func _apply_render_scale() -> void:
	var vp := get_viewport()
	var h := float(vp.get_visible_rect().size.y)
	var scale := 1.0
	if enabled and h > 0.0:
		scale = clampf(VIRTUAL_HEIGHT * 2.0 / h, 0.5, 1.0)
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	vp.scaling_3d_scale = scale


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_retro"):
		enabled = not enabled
		_mat.set_shader_parameter("enabled", 1.0 if enabled else 0.0)
		_apply_render_scale()
		EventBus.notify("Retro-Filter %s" % ("an" if enabled else "aus"), 1.5)
