class_name MapScreen
extends CanvasLayer
## Wanderkarte (Taste M, nur mit der Karte aus der Wetterstation – Gegenstand „hiking_map“).
## Zeigt Gelände, Seen, Bach, Wege, alle Orte (besuchte hell, unbesuchte grau) und den eigenen Standort.

const RES := 220

static var _image: ImageTexture

var _root: Control
var _map: TextureRect
var _marks: Control
var _player_mark: Label
var _player: Player


func _ready() -> void:
	name = "MapScreen"
	layer = 20
	add_to_group("map_screen")
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.visible = false
	add_child(_root)
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.82)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(bg)
	_map = TextureRect.new()
	_map.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_map.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_map.set_anchors_preset(Control.PRESET_FULL_RECT)
	_map.offset_top = 40
	_map.offset_bottom = -40
	_root.add_child(_map)
	_marks = Control.new()
	_marks.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_marks)
	var title := Label.new()
	title.text = "Wanderkarte – Revier 4 und Umgebung        [M] schließen"
	title.add_theme_font_size_override("font_size", 20)
	title.position = Vector2(24, 8)
	_root.add_child(title)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("map"):
		get_viewport().set_input_as_handled()
		if _root.visible:
			close()
		elif Inventory.count("hiking_map") > 0:
			open()
		else:
			EventBus.notify("Ich habe keine Karte. Zum Glück stehen an den Wegen Schilder.", 2.5)
	elif _root.visible and event.is_action_pressed("pause_menu"):
		get_viewport().set_input_as_handled()
		close()


func is_open() -> bool:
	return _root.visible


func open() -> void:
	_player = get_tree().get_first_node_in_group("player") as Player
	if _image == null:
		_image = ImageTexture.create_from_image(_render())
	_map.texture = _image
	_root.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _player:
		_player.input_locked = true
	_place_marks.call_deferred()


func close() -> void:
	_root.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if _player:
		_player.input_locked = false


## Gelände als Bild: Höhenstufen mit Schattierung, Wasser, Wege.
func _render() -> Image:
	var half := WorldMap.limit()
	var img := Image.create(RES, RES, false, Image.FORMAT_RGB8)
	var step := half * 2.0 / RES
	var hs := PackedFloat32Array()
	hs.resize(RES * RES)
	for y in RES:
		for x in RES:
			hs[y * RES + x] = Terrain.height_at(-half + (x + 0.5) * step, -half + (y + 0.5) * step)
	for y in RES:
		for x in RES:
			var wx := -half + (x + 0.5) * step
			var wz := -half + (y + 0.5) * step
			var h := hs[y * RES + x]
			var hl := hs[y * RES + maxi(x - 1, 0)]
			var hu := hs[maxi(y - 1, 0) * RES + x]
			var shade := clampf(0.5 + (hl - h + hu - h) * 0.06, 0.25, 1.0)
			var col := Color(0.32, 0.42, 0.24).lerp(Color(0.55, 0.5, 0.38), smoothstep(40.0, 120.0, h)).lerp(Color(0.85, 0.85, 0.82), smoothstep(150.0, 210.0, h))
			col = col.lerp(Color(0.5, 0.62, 0.32), WorldMap.meadow(wx, wz) * 0.7)
			col *= shade * 1.3
			if Terrain.water_level_at(wx, wz) > h:
				col = Color(0.25, 0.4, 0.55)
			var ti := WorldMap.trail_info(wx, wz)
			if ti.x < step * 0.6 or (wz > 16.0 and Terrain.road_distance(wx, wz) < step * 0.7):
				col = Color(0.75, 0.62, 0.42) if ti.y != 2 else Color(0.3, 0.3, 0.32)
			img.set_pixel(x, y, Color(col.r, col.g, col.b))
	return img


func _to_screen(p: Vector2) -> Vector2:
	var half := WorldMap.limit()
	var r := _map.get_rect()
	var side := minf(r.size.x, r.size.y)
	var origin := r.position + (r.size - Vector2(side, side)) * 0.5
	return origin + (p + Vector2(half, half)) / (half * 2.0) * side


func _place_marks() -> void:
	for c in _marks.get_children():
		c.queue_free()
	var all := WorldMap.places()
	for id: String in all:
		var p: Dictionary = all[id]
		var alias: String = {"absturz": "visit_crash", "struktur": "visit_structure", "hoehle": "visit_cave", "hochsitz": "visit_tower"}.get(id, "-")
		var seen := Tasks.flags.has("visit_" + id) or Tasks.flags.has(alias)
		var l := Label.new()
		l.text = "● " + String(p["name"])
		l.add_theme_font_size_override("font_size", 14)
		l.add_theme_color_override("font_color", Color(1.0, 0.95, 0.8) if seen else Color(0.75, 0.75, 0.75, 0.75))
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		l.add_theme_constant_override("outline_size", 4)
		l.position = _to_screen(p["pos"]) - Vector2(5, 10)
		_marks.add_child(l)
	var home := Label.new()
	home.text = "⌂ Hütte"
	home.add_theme_font_size_override("font_size", 16)
	home.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	home.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	home.add_theme_constant_override("outline_size", 4)
	home.position = _to_screen(Vector2.ZERO) - Vector2(6, 10)
	_marks.add_child(home)
	if _player:
		var me := Label.new()
		me.text = "▲ ich"
		me.add_theme_font_size_override("font_size", 18)
		me.add_theme_color_override("font_color", Color(1.0, 0.3, 0.25))
		me.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		me.add_theme_constant_override("outline_size", 5)
		me.position = _to_screen(Vector2(_player.global_position.x, _player.global_position.z)) - Vector2(6, 12)
		_marks.add_child(me)
