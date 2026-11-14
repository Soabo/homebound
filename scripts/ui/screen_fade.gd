class_name ScreenFade
extends CanvasLayer
## Kurz schwarz und wieder hell – für Ortswechsel (Schacht hinab/hinauf). teleport() setzt den Spieler in der dunklen Mitte um.

var _rect: ColorRect
var _t: float = 0.0
var _mid_done: bool = false
var _on_mid: Callable
var duration: float = 1.4


static func teleport(p: Player, pos: Vector3, look_at_pos: Vector3, message: String = "") -> void:
	var f := ScreenFade.new()
	f._on_mid = func() -> void:
		if not is_instance_valid(p):
			return
		p.global_position = pos
		p.velocity = Vector3.ZERO
		var d := look_at_pos - pos
		if Vector2(d.x, d.z).length() > 0.01:
			p.rotation.y = atan2(-d.x, -d.z)
		if message != "":
			EventBus.notify(message, 6.0)
	p.get_tree().root.add_child(f)


func _ready() -> void:
	layer = 105
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rect = ColorRect.new()
	_rect.color = Color(0, 0, 0, 0)
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rect)


func _process(delta: float) -> void:
	_t += delta
	var half := duration * 0.5
	_rect.color.a = clampf(1.0 - absf(_t - half) / half * 1.2 + 0.2, 0.0, 1.0)
	if _t >= half and not _mid_done:
		_mid_done = true
		if _on_mid.is_valid():
			_on_mid.call()
	if _t >= duration:
		queue_free()
