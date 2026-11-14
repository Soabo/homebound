class_name MapScreen
extends CanvasLayer
## Karte (Taste M). Christians alte Einsatzkarte („work_map“, aus dem Umzugskarton) zeigt Gelände, Wege und die Orte,
## die man kennt (besucht oder von einer Spur eingekreist). Die Wanderkarte aus der Wetterstation („hiking_map“) zeigt alle Orte.
## Spuren der Story (Story.map_targets) sind mit roten Bleistiftkreisen markiert (Hauptspur kräftig, Nebenspur blasser).

const RES := 220
## Zoomstufen (Mausrad), gezeigt wird ein Ausschnitt um _center
const ZOOMS := [1.0, 2.0, 4.0, 8.0]

static var _image: ImageTexture
var _zoom_i := 0
var _center := Vector2.ZERO
var _drag := false
var _dragged := 0.0

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
	title.text = "Karte – Revier 4 und Umgebung        Mausrad: zoomen · ziehen: verschieben        [M] schließen"
	title.add_theme_font_size_override("font_size", 20)
	title.position = Vector2(24, 8)
	_root.add_child(title)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("map"):
		get_viewport().set_input_as_handled()
		if _root.visible:
			close()
		elif not _player_free():
			pass  # anderes Menü offen, Schlaf, Sitzen, Pause: Karte bleibt zu
		elif Inventory.count("hiking_map") > 0 or Inventory.count("work_map") > 0:
			open()
		else:
			EventBus.notify("Ich habe keine Karte. Zum Glück stehen an den Wegen Schilder.", 2.5)
	elif _root.visible and event.is_action_pressed("pause_menu"):
		get_viewport().set_input_as_handled()
		close()


## Mausrad zoomt dorthin, wo die Maus steht; mit gedrückter Maustaste verschieben.
func _input(event: InputEvent) -> void:
	if not _root.visible:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			var at := _to_world(mb.position)
			var old := _half()
			_zoom_i = clampi(_zoom_i + (1 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else -1), 0, ZOOMS.size() - 1)
			_center = at - (at - _center) * (_half() / old)
			_clamp_center()
			_refresh_view()
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			_drag = mb.pressed
			if not mb.pressed and _dragged > 0.0:
				_dragged = 0.0
				_refresh_view()
	elif event is InputEventMouseMotion and _drag and _zoom_i > 0:
		var r := _map_rect()
		_center -= (event as InputEventMouseMotion).relative / r.size.x * _half() * 2.0
		_clamp_center()
		_dragged += (event as InputEventMouseMotion).relative.length()
		_place_marks()


func _half() -> float:
	return WorldMap.limit() / float(ZOOMS[_zoom_i])


func _clamp_center() -> void:
	var m := WorldMap.limit() - _half()
	_center = Vector2(clampf(_center.x, -m, m), clampf(_center.y, -m, m))


func _refresh_view() -> void:
	if _zoom_i == 0:
		_center = Vector2.ZERO
		_map.texture = _image
	else:
		_map.texture = ImageTexture.create_from_image(_render(_center, _half()))
	_place_marks()


func is_open() -> bool:
	return _root.visible


## Karte nur, wenn gerade nichts anderes die Steuerung hat (sonst gäbe das Schließen der Karte
## die Steuerung frei, obwohl z. B. noch das Inventar offen ist oder man auf der Couch sitzt).
func _player_free() -> bool:
	var p := get_tree().get_first_node_in_group("player") as Player
	return p != null and not p.input_locked and not get_tree().paused


func open() -> void:
	_player = get_tree().get_first_node_in_group("player") as Player
	if _image == null:
		_image = ImageTexture.create_from_image(_render())
	_map.texture = _image
	_zoom_i = 0
	_center = Vector2.ZERO
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
func _render(center: Vector2 = Vector2.ZERO, half: float = -1.0) -> Image:
	if half <= 0.0:
		half = WorldMap.limit()
	var img := Image.create(RES, RES, false, Image.FORMAT_RGB8)
	var step := half * 2.0 / RES
	var hs := PackedFloat32Array()
	hs.resize(RES * RES)
	for y in RES:
		for x in RES:
			hs[y * RES + x] = Terrain.height_at(center.x - half + (x + 0.5) * step, center.y - half + (y + 0.5) * step)
	for y in RES:
		for x in RES:
			var wx := center.x - half + (x + 0.5) * step
			var wz := center.y - half + (y + 0.5) * step
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


## Bildfläche der Karte (quadratisch, mittig).
func _map_rect() -> Rect2:
	var r := _map.get_rect()
	var side := minf(r.size.x, r.size.y)
	return Rect2(r.position + (r.size - Vector2(side, side)) * 0.5, Vector2(side, side))


func _to_screen(p: Vector2) -> Vector2:
	var half := _half()
	var r := _map_rect()
	return r.position + (p - _center + Vector2(half, half)) / (half * 2.0) * r.size.x


func _to_world(s: Vector2) -> Vector2:
	var half := _half()
	var r := _map_rect()
	return _center - Vector2(half, half) + (s - r.position) / r.size.x * half * 2.0


func _place_marks() -> void:
	for c in _marks.get_children():
		c.queue_free()
	var all := WorldMap.places()
	var full := Inventory.count("hiking_map") > 0
	var targets := Story.map_targets()
	var me_xz := Vector2(_player.global_position.x, _player.global_position.z) if _player else Vector2.ZERO
	for t: Dictionary in targets:
		var ring := Ring.new()
		ring.main = bool(t["main"])
		ring.position = _to_screen(t["pos"]) - Vector2(22, 22)
		_marks.add_child(ring)
		# Marschplanung: Entfernung und Gehzeit zum Spur-Ziel
		var dist := me_xz.distance_to(t["pos"])
		if dist > 60.0:
			var eta := Label.new()
			eta.text = march_text(dist)
			eta.add_theme_font_size_override("font_size", 12)
			eta.add_theme_color_override("font_color", Color(1.0, 0.7, 0.6))
			eta.add_theme_color_override("font_outline_color", Color(0, 0, 0))
			eta.add_theme_constant_override("outline_size", 4)
			eta.position = _to_screen(t["pos"]) + Vector2(-20, 16)
			_marks.add_child(eta)
	# Rastplätze (nur auf der Wanderkarte)
	if full:
		for r: Dictionary in WorldMap.data().get("rest_spots", []):
			var rl := Label.new()
			rl.text = "△"
			rl.tooltip_text = String(r.get("name", "Rastplatz"))
			rl.add_theme_font_size_override("font_size", 14)
			rl.add_theme_color_override("font_color", Color(0.75, 0.95, 0.7))
			rl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
			rl.add_theme_constant_override("outline_size", 4)
			rl.position = _to_screen(Vector2(float(r["pos"][0]), float(r["pos"][1]))) - Vector2(5, 10)
			_marks.add_child(rl)
	# Unten: was man für einen Marsch dabei hat und wie lange es noch hell ist
	var plan := Label.new()
	plan.text = supply_text()
	plan.add_theme_font_size_override("font_size", 16)
	plan.add_theme_color_override("font_color", Color(0.9, 0.88, 0.8))
	plan.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	plan.add_theme_constant_override("outline_size", 4)
	plan.position = Vector2(24, get_viewport().get_visible_rect().size.y - (56 if plan.text.contains("\n") else 34))
	plan.set_meta("fixed", true)
	_marks.add_child(plan)
	for id: String in all:
		var p: Dictionary = all[id]
		var alias: String = {"absturz": "visit_crash", "struktur": "visit_structure", "hoehle": "visit_cave", "hochsitz": "visit_tower"}.get(id, "-")
		var seen := Tasks.flags.has("visit_" + id) or Tasks.flags.has(alias)
		var circled := false
		for t: Dictionary in targets:
			if (t["pos"] as Vector2).distance_to(p["pos"]) < 1.0:
				circled = true
		if not full and not seen and not circled:
			continue   # alte Einsatzkarte: unbekannte Orte fehlen
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
	# beim Zoomen: was außerhalb des Ausschnitts liegt, ausblenden
	var area := _map_rect().grow(4.0)
	for c in _marks.get_children():
		if c is Control and not c.is_queued_for_deletion() and not c.has_meta("fixed"):
			var ctl := c as Control
			ctl.visible = area.has_point(ctl.position + Vector2(10, 10))


## Entfernung + ungefähre Gehzeit in Spielstunden (Wege sind länger als die Luftlinie: ×1,3)
static func march_text(dist: float) -> String:
	var real_s := dist * 1.3 / 3.0
	var game_h := real_s * 12.0 / (TimeManager.config.day_duration_minutes * 60.0)
	return "%.1f km · ca. %s zu Fuß" % [dist / 1000.0, ("%d Std." % int(round(game_h))) if game_h >= 1.0 else ("%d Min." % int(round(game_h * 60.0 / 10.0) * 10))]


## Zeit bis zur Nacht und Proviant im Rucksack
static func supply_text() -> String:
	var h := TimeManager.hour
	var night := TimeManager.config.night_start_hour
	var light := "Es ist Nacht." if TimeManager.is_night() else "Hell noch ca. %d Std." % int(maxf(night - h, 0.0))
	var food := Inventory.count_food()
	var water := Inventory.count_water()
	var parts := ["%s" % light, "Essen %d" % food, "Wasser %d" % water,
		"Zelt " + ("ja" if Inventory.count("tent") > 0 else "nein"),
		"Schlafsack " + ("ja" if Inventory.count("sleeping_bag") > 0 else "nein"),
		"Brennstoff %d" % Inventory.count_fuel()]
	var trip := Story.multi_trip_target()
	var head := "Marsch:  "
	if trip != "":
		var missing: PackedStringArray = []
		for it: Dictionary in Story.packing_status():
			if not it["ok"] and not it["optional"]:
				missing.append(String(it["label"]))
		head = "Mehrtagesmarsch (%s) – %s\n" % [WorldMap.places()[trip]["name"], "alles gepackt" if missing.is_empty() else "es fehlt: " + ", ".join(missing)]
	return head + "   ·   ".join(parts) + ("     △ = Rastplatz (Feuerstelle, ruhigere Zeltnacht)" if Inventory.count("hiking_map") > 0 else "")


## Bleistiftkreis um ein Spur-Ziel (zweimal leicht versetzt gezogen, wie von Hand).
class Ring extends Control:
	var main := true

	func _init() -> void:
		size = Vector2(44, 44)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := Color(0.95, 0.2, 0.15, 0.95) if main else Color(0.9, 0.55, 0.45, 0.6)
		draw_arc(Vector2(22, 22), 17.0, 0.2, TAU + 0.5, 40, c, 2.5 if main else 1.6)
		draw_arc(Vector2(23, 21), 19.0, 1.4, TAU + 0.9, 40, c, 1.4 if main else 1.0)
