class_name InteractFrame
extends Control
## Feiner Rahmen (nur die vier Ecken) um ein benutzbares Objekt im Fadenkreuz.
## Die Größe ergibt sich aus der Kollisionsform des anvisierten Objekts,
## auf den Bildschirm projiziert. Blendet weich ein und aus.

const PADDING := 6.0
const MIN_SIZE := 26.0

var _alpha: float = 0.0
var _pos := Vector2.ZERO
var _size := Vector2.ZERO
var _aabb_cache: Dictionary = {}


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	var show := false
	if player and player.has_usable_target():
		var r := _screen_rect(player.camera, player.current_target_body)
		if r.size.x > 0.0:
			show = true
			r = r.grow(PADDING)
			if r.size.x < MIN_SIZE:
				r = r.grow_individual((MIN_SIZE - r.size.x) * 0.5, 0, (MIN_SIZE - r.size.x) * 0.5, 0)
			if r.size.y < MIN_SIZE:
				r = r.grow_individual(0, (MIN_SIZE - r.size.y) * 0.5, 0, (MIN_SIZE - r.size.y) * 0.5)
			if _alpha < 0.05:
				# beim Auftauchen leicht größer starten und zusammenziehen
				_pos = r.position - Vector2(8, 8)
				_size = r.size + Vector2(16, 16)
			var k := clampf(delta * 14.0, 0.0, 1.0)
			_pos = _pos.lerp(r.position, k)
			_size = _size.lerp(r.size, k)
	_alpha = move_toward(_alpha, 1.0 if show else 0.0, delta * (7.0 if show else 5.0))
	queue_redraw()


func _draw() -> void:
	if _alpha <= 0.01:
		return
	var col := Color(1, 1, 1, 0.75 * _alpha)
	var shadow := Color(0, 0, 0, 0.35 * _alpha)
	var len := clampf(minf(_size.x, _size.y) * 0.22, 6.0, 18.0)
	var a := _pos
	var b := _pos + _size
	var corners := [
		[Vector2(a.x, a.y), Vector2(1, 0), Vector2(0, 1)],
		[Vector2(b.x, a.y), Vector2(-1, 0), Vector2(0, 1)],
		[Vector2(a.x, b.y), Vector2(1, 0), Vector2(0, -1)],
		[Vector2(b.x, b.y), Vector2(-1, 0), Vector2(0, -1)],
	]
	for c: Array in corners:
		var p: Vector2 = c[0]
		for d: Vector2 in [c[1], c[2]]:
			draw_line(p + Vector2(1, 1), p + d * len + Vector2(1, 1), shadow, 1.0)
			draw_line(p, p + d * len, col, 1.0)


## Bildschirm-Rechteck aller Kollisionsformen des Objekts (leer, wenn hinter der Kamera).
func _screen_rect(cam: Camera3D, body: CollisionObject3D) -> Rect2:
	if body == null or not is_instance_valid(body):
		return Rect2()
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	var any := false
	for owner_id in body.get_shape_owners():
		var t := body.global_transform * body.shape_owner_get_transform(owner_id)
		for i in body.shape_owner_get_shape_count(owner_id):
			var box := _shape_aabb(body.shape_owner_get_shape(owner_id, i))
			for k in 8:
				var w := t * box.get_endpoint(k)
				if cam.is_position_behind(w):
					return Rect2()
				var s := cam.unproject_position(w)
				lo = lo.min(s)
				hi = hi.max(s)
				any = true
	if not any:
		return Rect2()
	var view := get_viewport_rect()
	lo = lo.clamp(view.position, view.end)
	hi = hi.clamp(view.position, view.end)
	return Rect2(lo, hi - lo)


func _shape_aabb(shape: Shape3D) -> AABB:
	if _aabb_cache.has(shape):
		return _aabb_cache[shape]
	var box := AABB()
	if shape is BoxShape3D:
		var sz := (shape as BoxShape3D).size
		box = AABB(-sz * 0.5, sz)
	else:
		box = shape.get_debug_mesh().get_aabb()
	_aabb_cache[shape] = box
	return box
