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
var _pos: Vector3


func _ready() -> void:
	name = "BuildController"
	add_to_group("build_controller")


func _buildable_items() -> Array[String]:
	var out: Array[String] = []
	for id in Inventory.items:
		if DataDB.item(id).has("build"):
			out.append(id)
	return out


func start(id: String) -> void:
	if Inventory.count(id) <= 0:
		return
	type = id
	active = true
	_make_preview()
	EventBus.notify("Bauen: %s  –  E platzieren, R drehen, B weiter/aus" % Inventory.display_name(id), 4.0)


func stop() -> void:
	active = false
	if _preview:
		_preview.queue_free()
		_preview = null
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
		_rot += PI * 0.25
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact") or (active and event.is_action_pressed("attack")):
		get_viewport().set_input_as_handled()
		_place()


func _physics_process(_delta: float) -> void:
	if not active or _preview == null:
		return
	if Inventory.count(type) <= 0:
		stop()
		return
	var player := get_tree().get_first_node_in_group("player") as Player
	if player == null:
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
	# Nicht im Haus, auf der Veranda, im Schuppen oder außerhalb der Welt
	if absf(p.x) < 7.0 and p.z > -5.6 and p.z < 7.9:
		return false
	if absf(p.x - Shed.ORIGIN.x) < 2.8 and absf(p.z - Shed.ORIGIN.z) < 2.4:
		return false
	if absf(p.x) > 68.0 or absf(p.z) > 68.0:
		return false
	if Terrain.stream_distance(p.x, p.z) < 2.0:
		return false
	# Nicht zu steil
	var size := _preview.size
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
