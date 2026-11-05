class_name Traces
extends RefCounted
## Spuren der Kreatur, die man morgens findet (Christians Wunsch: erst Andeutungen, dann Auftritte).
## Alles liegt in der Gruppe "traces" und wird mit Einbruch der nächsten Nacht weggeräumt.

static var _mud: StandardMaterial3D
static var _claw: StandardMaterial3D


static func _mats() -> void:
	if _mud:
		return
	_mud = BuildKit.color_mat(Color(0.16, 0.12, 0.09), 0.95)
	_claw = BuildKit.color_mat(Color(0.12, 0.1, 0.08), 0.9)


static func _holder(scene: Node, n: String) -> Node3D:
	var h := Node3D.new()
	h.name = n
	h.add_to_group("traces")
	scene.add_child(h)
	return h


## Lange, dreizehige Abdrücke in einer Linie von a nach b.
static func footprints(scene: Node, a: Vector3, b: Vector3, on_floor: float = -1.0) -> void:
	_mats()
	var h := _holder(scene, "Footprints")
	var dir := (b - a)
	dir.y = 0.0
	var n := int(dir.length() / 0.9)
	if n <= 0:
		return
	var step := dir / float(n)
	var yaw := atan2(dir.x, dir.z)
	for i in n:
		var side := 0.22 if i % 2 == 0 else -0.22
		var p := a + step * (i + 0.5) + Vector3(cos(yaw), 0, -sin(yaw)) * side
		p.y = (on_floor if on_floor >= 0.0 else Terrain.height_at(p.x, p.z)) + 0.012
		var foot := Node3D.new()
		h.add_child(foot)
		foot.position = p
		foot.rotation.y = yaw
		BuildKit.box(foot, Vector3(0.12, 0.006, 0.22), Vector3(0, 0, 0), _mud, false)
		for t in 3:
			BuildKit.box(foot, Vector3(0.025, 0.006, 0.16), Vector3((t - 1) * 0.06, 0, 0.17), _mud, false, Vector3(0, (t - 1) * -14.0, 0))


## Schlamm im Haus: Abdrücke von der Stelle, an der sie stand, bis vor die Schlafzimmertür.
static func mud_trail(scene: Node, from: Vector3, to: Vector3) -> void:
	footprints(scene, from, to, Cabin.FLOOR_Y)


## Vier tiefe Kratzer in einer Außenwand.
static func claw_marks(scene: Node, pos: Vector3, normal: Vector3) -> void:
	_mats()
	var h := _holder(scene, "ClawMarks")
	h.position = pos + normal * 0.18
	h.look_at(h.position + normal, Vector3.UP)
	for k in 4:
		BuildKit.box(h, Vector3(0.02, 0.55, 0.02), Vector3((k - 1.5) * 0.07, -k * 0.03, 0), _claw, false, Vector3(0, 0, 8.0 + k * 2.0))


## Morgendliche Spuren rund ums Haus: Abdrücke bis unter ein Fenster, manchmal Kratzer am Holz.
static func morning(scene: Node, rng: RandomNumberGenerator) -> void:
	var windows := scene.get_tree().get_nodes_in_group("entry_point").filter(func(e: Node) -> bool: return e is CabinWindow)
	if windows.is_empty():
		return
	var w := windows[rng.randi() % windows.size()] as Node3D
	var under: Vector3 = w.call("outside_point")
	var away := Vector3(under.x, 0, under.z).normalized()
	footprints(scene, under + away * 9.0 + Vector3(rng.randf_range(-2, 2), 0, 0), under)
	if rng.randf() < 0.5:
		var n := away
		if absf(n.x) > absf(n.z):
			n = Vector3(signf(n.x), 0, 0)
		else:
			n = Vector3(0, 0, signf(n.z))
		var off := rng.randf_range(1.1, 1.6) * (1.0 if rng.randf() < 0.5 else -1.0)  # neben dem Fenster
		var wall := Vector3(under.x + off * absf(n.z), 1.3, under.z + off * absf(n.x))
		wall.x = signf(n.x) * Cabin.HALF_X if n.x != 0.0 else wall.x
		wall.z = signf(n.z) * Cabin.HALF_Z if n.z != 0.0 else wall.z
		claw_marks(scene, wall, n)


static func clear(scene: Node) -> void:
	for t in scene.get_tree().get_nodes_in_group("traces"):
		t.queue_free()
