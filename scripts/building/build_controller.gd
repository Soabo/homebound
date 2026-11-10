class_name BuildController
extends Node
## Baumodus (GDD 7.1/7.2): freies Platzieren auf dem Grundstück mit Vorschau.
##  B          Baumodus an / nächstes Bauteil / aus
##  R          drehen (45°)
##  E / Klick  platzieren
## Grün = passt, rot = geht hier nicht (Haus, Schuppen, zu steil, belegt).

const REACH := 6.0
const GRID := 0.25

var active: bool = false
var type: String = ""
var _rot: float = 0.0
var _preview: Structure
var _valid: bool = false
## Flächen, auf denen nicht gebaut werden kann: Hütte (mit Wandstärke), Veranda, Treppe
const NO_BUILD := [Rect2(-6.4, -4.9, 12.8, 9.8), Rect2(-5.8, 4.6, 7.2, 2.2), Rect2(-4.2, 6.6, 2.4, 1.0)]
var _pos: Vector3


func _ready() -> void:
	name = "BuildController"
	add_to_group("build_controller")


func _buildable_items() -> Array[String]:
	var out: Array[String] = []
	for id in Inventory.items:
		if DataDB.item(id).has("build") or DataDB.item(id).has("camera"):
			out.append(id)
	return out


# --- Kameras anbringen ------------------------------------------------------
## Kameras nur außen an Hütte oder Schuppen, zwischen diesen Höhen (über dem Boden der Wand)
var _cam_preview: SecurityCamera
var _cam_key: String = ""
var _cam_pos: Vector3
var _cam_normal: Vector3
var _cam_yaw: float = 0.0


func _is_camera() -> bool:
	return DataDB.item(type).has("camera")


func _camera_update(player: Player) -> void:
	var cam := player.camera.global_transform
	var q := PhysicsRayQueryParameters3D.create(cam.origin, cam.origin - cam.basis.z * REACH)
	q.exclude = [player.get_rid()]
	var hit := player.get_world_3d().direct_space_state.intersect_ray(q)
	_valid = false
	var why := "Ziel auf eine Außenwand von Hütte oder Schuppen."
	if not hit.is_empty():
		var n: Vector3 = hit["normal"]
		var p: Vector3 = hit["position"]
		var owner := ""
		var node := hit["collider"] as Node
		while node:
			if node.name in ["Cabin", "Shed"]:
				owner = node.name
				break
			node = node.get_parent()
		if owner != "" and absf(n.y) < 0.3:
			n.y = 0.0
			n = n.normalized()
			# Außenseite: Wandrichtung zeigt von der Gebäudemitte weg
			var center := Vector3.ZERO if owner == "Cabin" else Shed.ORIGIN
			var outward := (p - center)
			outward.y = 0.0
			var lo := (Cabin.FLOOR_Y + 1.5) if owner == "Cabin" else 1.4
			var hi := (Cabin.WALL_TOP - 0.15) if owner == "Cabin" else 2.15
			# vor der Wand muss draußen sein (nicht an Innenwänden)
			var front := p + n * 0.3
			var inside := Cabin.is_inside(front) if owner == "Cabin" else \
					(absf(front.x - Shed.ORIGIN.x) < Shed.HALF.x and absf(front.z - Shed.ORIGIN.z) < Shed.HALF.y)
			if outward.dot(n) <= 0.0 or inside:
				why = "Nur außen am Gebäude."
			elif p.y < lo:
				why = "Höher anbringen (über Kopfhöhe)."
			elif p.y > hi:
				why = "Hier ist kein Platz mehr unterm Dach."
			else:
				_valid = true
				_cam_pos = p
				_cam_normal = n
	var key := "%s|%.1f|%.1f|%.1f|%.2f|%s" % [type, _cam_pos.x, _cam_pos.y, _cam_pos.z, _cam_yaw, _valid]
	if key != _cam_key:
		_cam_key = key
		if _cam_preview:
			_cam_preview.queue_free()
			_cam_preview = null
		if _valid:
			_cam_preview = SecurityCamera.new()
			_cam_preview.preview = true
			_cam_preview.wall_normal = _cam_normal
			_cam_preview.position = _cam_pos
			_cam_preview.look_target = SecurityCamera.aim_target(_cam_pos, _cam_normal, _cam_yaw)
			get_tree().current_scene.add_child(_cam_preview)
	EventBus.interaction_prompt_changed.emit("%s  –  [E / Linksklick] anbringen   [R] schwenken   [B] weiter / beenden%s" % [
		Inventory.display_name(type), "" if _valid else "\n" + why])


func _camera_place() -> void:
	if not _valid:
		EventBus.notify("Kameras gehen nur außen an Hütte oder Schuppen.", 2.0)
		return
	var idx := int(DataDB.item(type).get("camera", 0))
	if not Inventory.remove(type, 1):
		return
	Supplies.install_camera(idx, _cam_pos, _cam_normal, _cam_yaw)
	SoundBank.hammer_series(get_tree().current_scene, _cam_pos, 3)
	EventBus.notify("%s angebracht. Das Bild siehst du am Monitor im Wohnzimmer." % Inventory.display_name(type), 3.0)
	_cam_yaw = 0.0
	var items := _buildable_items()
	if items.is_empty():
		stop()
	else:
		start(items[0])


func start(id: String) -> void:
	if Inventory.count(id) <= 0:
		return
	type = id
	active = true
	_cam_key = ""
	if _is_camera():
		if _preview:
			_preview.queue_free()
			_preview = null
		EventBus.notify("Kamera anbringen: auf eine Außenwand zielen  –  E anbringen, R schwenken, B weiter/aus", 4.0)
		return
	_make_preview()
	EventBus.notify("Bauen: %s  –  E platzieren, R drehen, B weiter/aus" % Inventory.display_name(id), 4.0)


func stop() -> void:
	active = false
	if _preview:
		_preview.queue_free()
		_preview = null
	if _cam_preview:
		_cam_preview.queue_free()
		_cam_preview = null
	EventBus.interaction_prompt_changed.emit("")


func _make_preview() -> void:
	if _preview:
		_preview.queue_free()
	_preview = Structure.new()
	_preview.type = type
	_preview.preview = true
	get_tree().current_scene.add_child(_preview)


func _unhandled_input(event: InputEvent) -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	if player == null or get_tree().paused:
		return
	if event.is_action_pressed("build"):
		if player.input_locked and not active:
			return
		var items := _buildable_items()
		if items.is_empty():
			if active:
				stop()
			else:
				EventBus.notify("Keine Bauteile dabei. An der Werkbank kannst du welche herstellen.", 3.0)
			return
		if not active:
			start(items[0])
		else:
			var i := items.find(type)
			if i < 0 or i == items.size() - 1:
				stop()
			else:
				start(items[i + 1])
		get_viewport().set_input_as_handled()
		return
	if not active:
		return
	if event.is_action_pressed("interact_secondary"):
		if _is_camera():
			# schwenken: -75° … +75° in 15°-Schritten
			_cam_yaw += deg_to_rad(15.0)
			if _cam_yaw > deg_to_rad(76.0):
				_cam_yaw = deg_to_rad(-75.0)
		else:
			_rot += PI * 0.25
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact") or (active and event.is_action_pressed("attack")):
		get_viewport().set_input_as_handled()
		if _is_camera():
			_camera_place()
		else:
			_place()


func _physics_process(_delta: float) -> void:
	if not active:
		return
	if Inventory.count(type) <= 0:
		stop()
		return
	var player := get_tree().get_first_node_in_group("player") as Player
	if player == null:
		return
	if _is_camera():
		_camera_update(player)
		return
	if _preview == null:
		return
	var cam := player.camera.global_transform
	var from := cam.origin
	var to := from - cam.basis.z * REACH
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.exclude = [player.get_rid()]
	var hit := player.get_world_3d().direct_space_state.intersect_ray(q)
	var p: Vector3 = hit["position"] if not hit.is_empty() else to
	p.x = snappedf(p.x, GRID)
	p.z = snappedf(p.z, GRID)
	p.y = Terrain.height_at(p.x, p.z)
	_pos = p
	_preview.global_position = p
	_preview.rotation.y = _rot
	_valid = _check_valid(p)
	_preview.set_preview_valid(_valid)
	EventBus.interaction_prompt_changed.emit("%s  –  [E / Linksklick] platzieren   [R] drehen   [B] weiter / beenden%s" % [
		Inventory.display_name(type), "" if _valid else "\nHier geht es nicht."])


func _check_valid(p: Vector3) -> bool:
	# Nicht im Haus, auf der Veranda/Treppe oder im Schuppen – geprüft wird die ganze Grundfläche des Bauteils
	var size := _preview.size
	var ax := Vector3(cos(_rot), 0, -sin(_rot)) * size.x * 0.5
	var az := Vector3(sin(_rot), 0, cos(_rot)) * maxf(size.z, 0.3) * 0.5
	for c: Vector3 in [p, p + ax + az, p + ax - az, p - ax + az, p - ax - az, p + ax, p - ax]:
		for r: Rect2 in NO_BUILD:
			if r.has_point(Vector2(c.x, c.z)):
				return false
		if absf(c.x - Shed.ORIGIN.x) < Shed.HALF.x + 0.3 and absf(c.z - Shed.ORIGIN.z) < Shed.HALF.y + 0.3:
			return false
	if absf(p.x) > 100.0 or absf(p.z) > 100.0:
		return false
	if Terrain.stream_distance(p.x, p.z) < 2.0:
		return false
	# Nicht zu steil
	var dx := Vector3(cos(_rot), 0, -sin(_rot)) * size.x * 0.5
	var h1 := Terrain.height_at(p.x + dx.x, p.z + dx.z)
	var h2 := Terrain.height_at(p.x - dx.x, p.z - dx.z)
	if absf(h1 - h2) > 0.7:
		return false
	# Nicht auf anderen Bauten
	for s in get_tree().get_nodes_in_group("structure"):
		if (s as Node3D).global_position.distance_to(p) < 0.9:
			return false
	return true


func _place() -> void:
	if not _valid:
		EventBus.notify("Hier kannst du das nicht aufstellen.", 2.0)
		return
	if not Inventory.remove(type, 1):
		stop()
		return
	var build_type: String = DataDB.item(type).get("build", type)
	Builder.place(build_type, _pos, _rot)
	SoundBank.play_at(get_tree().current_scene, "place", _pos + Vector3(0, 0.5, 0), 0.0)
	EventBus.noise_made.emit(_pos, 14.0)
	if Inventory.count(type) <= 0:
		var items := _buildable_items()
		if items.is_empty():
			stop()
		else:
			start(items[0])
