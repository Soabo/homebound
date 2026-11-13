class_name StoryProps
extends Node3D
## Fäden der Story in der Welt (Christian: alle drei):
##  1. Kabeltrassen von ReZort Industries (map.json "cables"): orange Schutzrohre, die aus dem Boden ragen, und
##     nummerierte Kabelpfosten. Wer ihnen folgt, kommt vom alten Brunnen zur Messstelle und weiter zu den anderen Anlagen.
##  2. Wendts Meldekästen (map.json "wendt_boxes"): Kasten am Pfosten mit rotem Kreuz und Nummer, am Weg beim Ort,
##     davor zwei rot markierte Pfähle. Darin seine Meldung (Notiz).
##  3. Stefanies Spuren liegen direkt in den Orten (PlacesDay/PlacesFar/PlacesNear, Notizen stef_*).

const PIPE_EVERY := 14.0
const POST_EVERY := 35.0

static var cable_posts: Array[Vector3] = []
static var wendt_boxes: Dictionary = {}   ## Nummer -> Position (für Tests)

var _paint_red: StandardMaterial3D
var _orange: StandardMaterial3D
var _concrete: StandardMaterial3D


func _ready() -> void:
	name = "StoryProps"
	_paint_red = BuildKit.color_mat(Color(0.75, 0.06, 0.05), 0.7)
	_orange = BuildKit.color_mat(Color(0.95, 0.45, 0.08), 0.6)
	_concrete = BuildKit.tex_mat("concrete", 0.6, Color(1.1, 1.1, 1.08))
	cable_posts.clear()
	wendt_boxes.clear()
	for c: Dictionary in WorldMap.data().get("cables", []):
		_cable(c)
	for b: Dictionary in WorldMap.data().get("wendt_boxes", []):
		_wendt_box(b)
	print("[StoryProps] Kabelpfosten %d, Meldekästen %d" % [cable_posts.size(), wendt_boxes.size()])


# --- Kabeltrassen ------------------------------------------------------------------

func _cable(c: Dictionary) -> void:
	var pts: Array = c["pts"]
	var root := Node3D.new()
	root.name = "Cable_" + String(c["id"]).replace("-", "_")
	add_child(root)
	var pipes: Array[Transform3D] = []
	var posts: Array[Transform3D] = []
	var caps: Array[Transform3D] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(String(c["id"]))
	var dist := 0.0
	var next_pipe := 4.0
	var next_post := 10.0
	var nr := 1
	for i in pts.size() - 1:
		var a := Vector2(float(pts[i][0]), float(pts[i][1]))
		var b := Vector2(float(pts[i + 1][0]), float(pts[i + 1][1]))
		var seg := a.distance_to(b)
		var dir := (b - a) / maxf(seg, 0.001)
		var s := 0.0
		while s < seg:
			var q := a + dir * s
			if dist >= next_pipe:
				next_pipe = dist + PIPE_EVERY * rng.randf_range(0.8, 1.2)
				if _ok(q):
					# Schutzrohr ragt schräg aus dem Boden, in Laufrichtung der Trasse
					var g := Terrain.height_at(q.x, q.y)
					var basis := Basis(Vector3.UP, atan2(dir.x, dir.y) + rng.randf_range(-0.3, 0.3)) * Basis(Vector3.RIGHT, deg_to_rad(rng.randf_range(30.0, 55.0)))
					pipes.append(Transform3D(basis, Vector3(q.x, g + 0.12, q.y)))
			if dist >= next_post:
				next_post = dist + POST_EVERY
				var side := Vector2(-dir.y, dir.x) * 0.9
				var pq := q + side
				if _ok(pq):
					var g := Terrain.height_at(pq.x, pq.y)
					var yaw := atan2(dir.x, dir.y)
					posts.append(Transform3D(Basis(Vector3.UP, yaw), Vector3(pq.x, g + 0.65, pq.y)))
					caps.append(Transform3D(Basis(Vector3.UP, yaw), Vector3(pq.x, g + 1.34, pq.y)))
					_post_label(root, Vector3(pq.x, g, pq.y), yaw, "RZ · %s\n%03d" % [String(c["id"]), nr])
					cable_posts.append(Vector3(pq.x, g, pq.y))
					nr += 1
			s += 2.0
			dist += 2.0
	_multimesh(root, "Pipes", _pipe_mesh(), pipes, _orange)
	_multimesh(root, "Posts", _box_mesh(Vector3(0.14, 1.3, 0.14)), posts, _concrete)
	_multimesh(root, "Caps", _box_mesh(Vector3(0.16, 0.12, 0.16)), caps, _orange)
	# Kabelschacht am Anfang (z. B. hinter dem Gartenzaun am alten Brunnen)
	var start := Vector2(float(pts[0][0]), float(pts[0][1]))
	if _ok(start):
		var g := Terrain.height_at(start.x, start.y)
		BuildKit.box(root, Vector3(0.9, 0.25, 0.9), Vector3(start.x, g + 0.08, start.y), _concrete, true)
		BuildKit.box(root, Vector3(0.7, 0.04, 0.7), Vector3(start.x, g + 0.22, start.y), BuildKit.color_mat(Color(0.25, 0.26, 0.27), 0.5, 0.7), false)
		var lab := Label3D.new()
		# zweizeilig und kleiner, damit die Schrift auf dem Deckel bleibt
		lab.text = "ReZort Industries\nKabelschacht"
		lab.font_size = 15
		lab.pixel_size = 0.003
		lab.modulate = Color(0.1, 0.1, 0.1)
		lab.outline_size = 0
		lab.position = Vector3(start.x, g + 0.245, start.y)
		lab.rotation_degrees = Vector3(-90, 0, 0)
		lab.visibility_range_end = 20.0
		root.add_child(lab)


## Darf hier ein Rohr/Pfosten stehen? (nicht im Wasser, nicht im Garten, nicht auf einem Weg oder der Zufahrt)
static func _ok(q: Vector2) -> bool:
	if Terrain.yard_distance(q.x, q.y) < 1.0 or WorldTrails.z_on_road(q):
		return false
	if WorldMap.trail_info(q.x, q.y).x < 0.4:
		return false
	var g := Terrain.height_at(q.x, q.y)
	return Terrain.water_level_at(q.x, q.y) < g - 0.2


func _post_label(root: Node3D, at: Vector3, yaw: float, text: String) -> void:
	for side: float in [1.0, -1.0]:
		var lab := Label3D.new()
		lab.text = text
		lab.font_size = 18
		lab.pixel_size = 0.0022
		lab.modulate = Color(0.08, 0.08, 0.08)
		lab.outline_size = 0
		lab.double_sided = false
		lab.position = at + Basis(Vector3.UP, yaw) * Vector3(0, 1.05, 0.072 * side)
		lab.rotation = Vector3(0, yaw + (0.0 if side > 0 else PI), 0)
		lab.visibility_range_end = 25.0
		root.add_child(lab)


static func _pipe_mesh() -> Mesh:
	var m := CylinderMesh.new()
	m.top_radius = 0.06
	m.bottom_radius = 0.06
	m.height = 0.7
	m.radial_segments = 8
	m.rings = 1
	return m


static func _box_mesh(size: Vector3) -> Mesh:
	var m := BoxMesh.new()
	m.size = size
	return m


func _multimesh(root: Node3D, n: String, mesh: Mesh, xf: Array[Transform3D], mat: Material) -> void:
	if xf.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xf.size()
	for i in xf.size():
		mm.set_instance_transform(i, xf[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = n
	mmi.multimesh = mm
	mmi.material_override = mat
	root.add_child(mmi)


# --- Wendts Meldekästen ------------------------------------------------------------

func _wendt_box(b: Dictionary) -> void:
	var place := String(b["place"])
	if not WorldMap.places().has(place):
		return
	var c := WorldMap.place_pos(place)
	var clear := float(WorldMap.places()[place].get("clear", 20.0))
	var want := clampf(clear * 0.8, 12.0, 30.0)
	# Punkt am Weg, ungefähr want Meter vom Ortsmittelpunkt entfernt
	var best := Vector2.INF
	var best_dir := Vector2.RIGHT
	var best_err := INF
	for s: Array in WorldMap.segments():
		if int(s[3]) == 2:
			continue
		var a: Vector2 = s[0]
		var e: Vector2 = s[1]
		var n := int(a.distance_to(e) / 1.5) + 1
		for k in n + 1:
			var q := a.lerp(e, float(k) / n)
			var d := q.distance_to(c)
			if d > 80.0:
				continue
			var err := absf(d - want)
			if err < best_err:
				best_err = err
				best = q
				best_dir = (e - a).normalized()
	if best == Vector2.INF:
		best = c + Vector2(want, 0)
	var hw := WorldMap.trail_info(best.x, best.y).x   # negativ: Abstand Mitte → Rand
	var right := Vector2(-best_dir.y, best_dir.x)
	# Seite, die vom Ort wegzeigt (nicht in die Gebäude)
	if (best + right - c).length() < (best - right - c).length():
		right = -right
	var at := best + right * (absf(hw) + 1.3)
	var g := Terrain.height_at(at.x, at.y)
	var root := Node3D.new()
	root.name = "WendtBox_%d" % int(b["nr"])
	root.position = Vector3(at.x, g, at.y)
	root.rotation.y = atan2(-right.x, -right.y)   # Kasten schaut zum Weg
	add_child(root)
	var wood := BuildKit.tex_mat("planks_v", 0.8, Color(0.75, 0.68, 0.58))
	var metal := BuildKit.color_mat(Color(0.32, 0.36, 0.3), 0.55, 0.4)
	BuildKit.box(root, Vector3(0.12, 1.5, 0.12), Vector3(0, 0.75, -0.08), wood, true)
	_red_cross(root, Vector3(0, 1.0, -0.015), 0.22)
	BuildKit.box(root, Vector3(0.34, 0.26, 0.16), Vector3(0, 1.38, 0.02), metal, false)
	BuildKit.box(root, Vector3(0.36, 0.03, 0.19), Vector3(0, 1.52, 0.03), metal, false, Vector3(-8, 0, 0))
	BuildKit.box(root, Vector3(0.2, 0.012, 0.005), Vector3(0, 1.43, 0.103), BuildKit.color_mat(Color(0.1, 0.1, 0.1)), false)
	var lab := Label3D.new()
	lab.text = str(int(b["nr"]))
	lab.font_size = 64
	lab.pixel_size = 0.0025
	lab.modulate = Color(0.75, 0.06, 0.05)
	lab.outline_size = 0
	lab.position = Vector3(0, 1.33, 0.104)
	lab.double_sided = false
	root.add_child(lab)
	var note := ResearchNote.new()
	note.name = "Note"
	note.note_id = String(b["note"])
	note.anchor = Vector3(0, 1.22, 0.05)
	note.hide_paper = true
	root.add_child(note)
	wendt_boxes[int(b["nr"])] = root.position
	# Zwei rot markierte Pfähle am Weg davor (in beide Richtungen)
	for k: float in [-16.0, 16.0]:
		var sp := best + best_dir * k
		var ti := WorldMap.trail_info(sp.x, sp.y)
		var sq := sp + right * (absf(ti.x) + 0.9) if ti.x < 0.0 else sp + right * 1.2
		if not _ok(sq):
			continue
		var sg := Terrain.height_at(sq.x, sq.y)
		var stake := Node3D.new()
		stake.name = "WendtStake_%d_%d" % [int(b["nr"]), int(k)]
		stake.position = Vector3(sq.x, sg, sq.y)
		stake.rotation.y = root.rotation.y
		add_child(stake)
		BuildKit.box(stake, Vector3(0.09, 1.1, 0.09), Vector3(0, 0.55, 0), wood, false, Vector3(randf_range(-4, 4), 0, randf_range(-4, 4)))
		_red_cross(stake, Vector3(0, 0.85, 0.05), 0.14)
		PlaceKit.limit_visibility(stake, 120.0, 140.0)
	PlaceKit.limit_visibility(root, 150.0, 170.0)


## Gesprühtes rotes Kreuz.
func _red_cross(parent: Node3D, pos: Vector3, size: float) -> void:
	for r: float in [45.0, -45.0]:
		BuildKit.box(parent, Vector3(size, size * 0.18, 0.012), pos, _paint_red, false, Vector3(0, 0, r))
