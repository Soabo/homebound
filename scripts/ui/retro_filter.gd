class_name RetroFilter
extends CanvasLayer
## Vollbild-Filter für den Retro-Horror-Look (F2 schaltet ihn zum Vergleich aus).
## Die Pixelgröße passt sich der Fensterhöhe an: ca. 720 "Retro-Zeilen".

const VIRTUAL_HEIGHT := 720.0  ## halb so grob wie früher (360)

var _rect: ColorRect
var _mat: ShaderMaterial
var enabled: bool = true


func _ready() -> void:
	name = "RetroFilter"
	add_to_group("retro_filter")
	layer = 1
	process_mode = Node.PROCESS_MODE_ALWAYS
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://shaders/retro_screen.gdshader")
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.material = _mat
	add_child(_rect)
	set_look(Settings.look)
	get_viewport().size_changed.connect(_update_pixel_size)
	_update_pixel_size()


func _update_pixel_size() -> void:
	var h := float(get_viewport().get_visible_rect().size.y)
	_mat.set_shader_parameter("pixel_size", maxf(1.0, roundf(h / VIRTUAL_HEIGHT)))
	_apply_render_scale()


## Der Filter zeigt ohnehin nur ~360 Zeilen. Die 3D-Welt muss deshalb nicht in voller
## Bildschirmauflösung berechnet werden: etwa doppelt so viele Zeilen reichen.
## Das spart auf großen Bildschirmen einen Großteil der Grafikarbeit.
## Rechnet jetzt Settings.apply_render_scale (zusammen mit der Grafikstufe).
func _apply_render_scale() -> void:
	Settings.apply_render_scale()


## Grafikstil (Settings.look): retro = grobe Pixel + Farbstufen, klar = nur Vignette und feines Korn.
func set_look(style: String) -> void:
	_mat.set_shader_parameter("pixelate", 1.0 if style == "retro" else 0.0)


## Stärke der Verzerrung durch den Blick der Kreatur (0..1).
func set_mind(v: float) -> void:
	_mat.set_shader_parameter("mind", v)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_retro"):
		enabled = not enabled
		_mat.set_shader_parameter("enabled", 1.0 if enabled else 0.0)
		_apply_render_scale()
		EventBus.notify("Retro-Filter %s" % ("an" if enabled else "aus"), 1.5)


## Farbabstimmung je Tageszeit (ruft DayNightEnvironment jedes Bild).
func set_grade(tint: Color, lift: Color, saturation: float, contrast: float) -> void:
	_mat.set_shader_parameter("grade_tint", Vector3(tint.r, tint.g, tint.b))
	_mat.set_shader_parameter("grade_lift", Vector3(lift.r, lift.g, lift.b))
	_mat.set_shader_parameter("grade_sat", saturation)
	_mat.set_shader_parameter("grade_contrast", contrast)
