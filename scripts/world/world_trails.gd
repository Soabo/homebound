class_name WorldTrails
extends Node3D
## Wegweiser an Kreuzungen, Holzstege, wo ein Weg den Bach quert, und alles, was einen Waldweg ausmacht:
## Markierungspfosten (Farbe = mark des Wegs), Wanderbänke zum Hinsetzen, Holzpolter an Fahrwegen,
## Stufen aus Rundhölzern an steilen Pfaden, Schranken, wo ein Fahrweg von der Zufahrt abgeht,
## und die Wandertafel an der Hütte (Daten: data/world/map.json, Abstände unter "trail_kit").
## Die Wege selbst färbt und vertieft das Gelände (Terrain.ground_color, Terrain.trail_dip).

const REGION := 128.0

## Abstände entlang des Wegs (Meter) – Werte aus map.json "trail_kit"
var _marker_every := {0: 55.0, 1: 85.0}
var _bench_every := 270.0
var _polter_every := 210.0
var _step_slope := 0.2
var _view_range := 170.0
var _board_pos := Vector2(-8.5, 22.0)

var _wood: StandardMaterial3D
var _dark: StandardMaterial3D
var _post_mat: StandardMaterial3D
var _rng := RandomNumberGenerator.new()
var _mm: Dictionary = {}          ## "art|region" -> [Transform3D…], Farben
## Wo Bänke/Pfosten stehen (für Tests)
static var benches: Array[Vector3] = []
static var markers: Array[Vector3] = []
static var bridges: Array[Dictionary] = []


func _ready() -> void:
	name = "WorldTrails"
	# helles, gestrichenes Brett, damit die schwarze Schrift gut lesbar ist
	_wood = BuildKit.tex_mat("planks_h", 0.7, Color(1.5, 1.42, 1.2))
	_dark = BuildKit.tex_mat("bark", 0.6)
	var kit: Dictionary = WorldMap.data().get("trail_kit", {})
	_marker_every = {0: float(kit.get("marker_every_path", 55.0)), 1: float(kit.get("marker_every_track", 85.0))}
	_bench_every = float(kit.get("bench_every", 270.0))
	_polter_every = float(kit.get("polter_every", 210.0))
	_step_slope = float(kit.get("step_slope", 0.2))
	_view_range = float(kit.get("view_range", 170.0))
	if kit.has("board_pos"):
		_board_pos = Vector2(float(kit["board_pos"][0]), float(kit["board_pos"][1]))
	_post_mat = BuildKit.tex_mat("planks_v", 0.8, Color(0.85, 0.8, 0.72))
	_rng.seed = 4711
	benches.clear()
	markers.clear()
	bridges.clear()
	for s: Dictionary in WorldMap.data().get("signs", []):
		_sign(Vector2(float(s["pos"][0]), float(s["pos"][1])), s["to"])
	_bridges()
	for t: Dictionary in WorldMap.data().get("trails", []):
		if t.get("kind", "path") != "asphalt":
			_furnish(t)
	_flush_multimeshes()
	_board()
	print("[WorldTrails] Stege %d, Pfosten %d, Bänke %d" % [bridges.size(), markers.size(), benches.size()])


## Holzpfosten mit Brettern, je Ziel ein Pfeil in die (Luftlinien-)Richtung mit Entfernung.
func _sign(at: Vector2, targets: Array) -> void:
	var dirs_from := at
	at = roadside(at)
	var g := Terrain.height_at(at.x, at.y)
	var root := Node3D.new()
	root.name = "Sign_%d_%d" % [int(at.x), int(at.y)]
	root.position = Vector3(at.x, g, at.y)
	add_child(root)
	BuildKit.cylinder(root, 0.07, 2.4, Vector3(0, 1.2, 0), _dark, true, Vector3.ZERO, 0.06, 7)
	BuildKit.cylinder(root, 0.09, 0.08, Vector3(0, 2.42, 0), _dark, false, Vector3.ZERO, 0.0, 7)
	var y := 2.1
	for id: String in targets:
		var p := WorldMap.place_pos(id)
		var dir := p - dirs_from
		var dist := dir.length()
		var yaw := rad_to_deg(atan2(-dir.x, -dir.y))
		var arm := Node3D.new()
		arm.position = Vector3(0, y, 0)
		arm.rotation_degrees = Vector3(0, yaw + 90.0, 0)
		root.add_child(arm)
		# Brett zeigt in -x der Arm-Ebene … mit Spitze
		BuildKit.box(arm, Vector3(1.15, 0.2, 0.035), Vector3(-0.62, 0, 0), _wood, false)
		BuildKit.box(arm, Vector3(0.16, 0.16, 0.035), Vector3(-1.2, 0, 0), _wood, false, Vector3(0, 0, 45))
		var name_text: String = WorldMap.places()[id]["name"] if WorldMap.places().has(id) else id
		var km := ("%.1f km" % (dist / 1000.0)).replace(".", ",") if dist >= 950.0 else "%d m" % (int(round(dist / 50.0)) * 50)
		for side: float in [1.0, -1.0]:
			var lab := Label3D.new()
			lab.text = "%s  %s" % [name_text, km]
			lab.font_size = 40
			lab.pixel_size = 0.0023
			lab.modulate = Color(0.0, 0.0, 0.0)   # schwarze Schrift auf hellem Brett
			lab.outline_size = 0
			lab.double_sided = false
			lab.position = Vector3(-0.62, 0, 0.022 * side)
			lab.rotation_degrees = Vector3(0, 0 if side > 0 else 180, 0)
			lab.width = 400
			lab.autowrap_mode = TextServer.AUTOWRAP_OFF
			arm.add_child(lab)
		y -= 0.27


## Stellplatz am Wegrand: nahe der Datenposition, knapp neben dem Weg (nicht darauf, nicht im Wald, nicht im Wasser).
static func roadside(at: Vector2) -> Vector2:
	var ti := WorldMap.trail_info(at.x, at.y)
	if ti.x > 25.0:
		return at   # kein Weg in der Nähe: bleibt, wo er ist
	var best := at
	var best_d := INF
	for r: float in [0.0, 1.0, 2.0, 3.0, 4.5, 6.0, 8.0, 10.0, 13.0, 16.0, 20.0, 25.0]:
		var n := 1 if r == 0.0 else 24
		for k in n:
			var q := at + Vector2.from_angle(TAU * k / n) * r
			var e := WorldMap.trail_info(q.x, q.y).x
			if e < 0.35 or e > 1.1:
				continue   # 0,35–1,1 m neben dem Wegrand
			if z_on_road(q):
				continue   # nicht auf der Zufahrt
			var g := Terrain.height_at(q.x, q.y)
			if Terrain.water_level_at(q.x, q.y) > g - 0.1:
				continue
			if r < best_d:
				best_d = r
				best = q
		if best_d < INF:
			break
	return best


## Liegt der Punkt auf der befahrbaren Zufahrt (nur außerhalb des Grundstücks)?
static func z_on_road(q: Vector2) -> bool:
	return q.y > 14.0 and Terrain.road_distance(q.x, q.y) < 3.4


## Wo ein Weg den Bach kreuzt: ein Steg aus Bohlen von Ufer zu Ufer (auch über tief eingeschnittene Stellen).
func _bridges() -> void:
	var done: Array[Vector2] = []
	for s: Array in WorldMap.segments():
		var a: Vector2 = s[0]
		var b: Vector2 = s[1]
		var len := a.distance_to(b)
		var steps := int(len / 1.0)
		var prev := INF
		for i in steps + 1:
			var p := a.lerp(b, float(i) / maxf(steps, 1))
			var sd := Terrain.stream_distance(p.x, p.y)
			if sd < 0.6 and sd < prev:
				var near_done := false
				for q: Vector2 in done:
					if q.distance_to(p) < 12.0:
						near_done = true
				if not near_done:
					done.append(p)
					_bridge(p, (b - a).normalized(), float(s[2]) * 2.0, int(s[3]))
			prev = sd


## Ende des Stegs auf einer Seite: dort, wo die Bachböschung aufhört (Abstand vom Kreuzungspunkt).
static func _bank_reach(at: Vector2, dir: Vector2) -> float:
	var bed := Terrain.stream_bed_height(at.y)
	var s := 2.6
	while s < 12.0:
		var q := at + dir * s
		var sd := Terrain.stream_distance(q.x, q.y)
		var raw := Terrain._raw_height(q.x, q.y)
		var reach := 4.0 + clampf(absf(raw - bed) * 0.6, 0.0, 5.0)
		if sd >= minf(reach - 0.6, 8.0) and sd >= 2.6:
			return s
		s += 0.4
	return s


func _bridge(at: Vector2, dir: Vector2, width: float, kind: int) -> void:
	var water := Terrain.stream_bed_height(at.y) + Terrain.WATER_LEVEL
	var w := clampf(width, 1.3, 6.0)
	var mat := _wood if kind < 2 else BuildKit.tex_mat("concrete", 0.5)
	var sa := _bank_reach(at, -dir)
	var sb := _bank_reach(at, dir)
	if kind >= 2:
		sa = maxf(sa, 7.0)
		sb = maxf(sb, 7.0)
	var pa := at - dir * sa
	var pb := at + dir * sb
	var ha := maxf(Terrain.height_at(pa.x, pa.y), water + 0.3) + 0.06
	var hb := maxf(Terrain.height_at(pb.x, pb.y), water + 0.3) + 0.06
	var length := sa + sb
	var mid := (pa + pb) * 0.5
	var root := StaticBody3D.new()
	root.name = "Bridge_%d_%d" % [int(at.x), int(at.y)]
	# lokal z = Laufrichtung, leicht geneigt, wenn die Ufer verschieden hoch sind
	var pitch := atan2(hb - ha, length)
	root.transform = Transform3D(Basis(Vector3.UP, atan2(dir.x, dir.y)) * Basis(Vector3.RIGHT, -pitch),
			Vector3(mid.x, (ha + hb) * 0.5, mid.y))
	add_child(root)
	bridges.append({"pos": Vector3(at.x, water, at.y), "length": length, "a": Vector3(pa.x, ha, pa.y), "b": Vector3(pb.x, hb, pb.y)})
	var span := length / cos(pitch)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(w, 0.12, span + 0.4)
	cs.shape = shape
	cs.position = Vector3(0, -0.06, 0)
	root.add_child(cs)
	if kind < 2:
		var n := int(span / 0.32)
		for i in n:
			BuildKit.box(root, Vector3(w, 0.07, 0.28), Vector3(0, -0.035, -span * 0.5 + 0.16 + i * 0.32), mat, false, Vector3(0, randf_range(-1.5, 1.5), 0))
		for sx: float in [-1.0, 1.0]:
			BuildKit.box(root, Vector3(0.12, 0.16, span + 0.3), Vector3(sx * (w * 0.5 - 0.1), -0.15, 0), _dark, false)
			# Geländer mit Pfosten alle ~1,8 m
			var posts := maxi(3, int(span / 1.8) + 1)
			for k in posts:
				var z := -span * 0.42 + k * span * 0.84 / (posts - 1)
				BuildKit.cylinder(root, 0.045, 0.95, Vector3(sx * (w * 0.5 - 0.05), 0.45, z), _dark, false, Vector3.ZERO, -1.0, 6)
			BuildKit.cylinder(root, 0.04, span * 0.86, Vector3(sx * (w * 0.5 - 0.05), 0.9, 0), _dark, false, Vector3(90, 0, 0), -1.0, 6)
			# Geländer ist fest: man kann nicht seitlich vom Steg laufen
			var rail_cs := CollisionShape3D.new()
			rail_cs.name = "RailCollision_%s" % ("L" if sx < 0.0 else "R")
			var rail_shape := BoxShape3D.new()
			rail_shape.size = Vector3(0.1, 1.0, span * 0.86)
			rail_cs.shape = rail_shape
			rail_cs.position = Vector3(sx * (w * 0.5 - 0.05), 0.5, 0)
			root.add_child(rail_cs)
		# Joche: Pfähle bis ins Bachbett, wo der Steg hoch über dem Wasser liegt
		for zl: float in [-1.2, 1.2]:
			var world := root.global_transform * Vector3(0, 0, zl) if root.is_inside_tree() else root.transform * Vector3(0, 0, zl)
			var bed := Terrain.height_at(world.x, world.z) - 0.3
			var drop := world.y - bed
			if drop > 0.5:
				for sx: float in [-1.0, 1.0]:
					var pile := BuildKit.cylinder(self, 0.09, drop, Vector3(0, 0, 0), _dark, false, Vector3.ZERO, -1.0, 7)
					var side := (root.transform.basis.x * sx * (w * 0.5 - 0.15))
					pile.position = Vector3(world.x, bed + drop * 0.5, world.z) + Vector3(side.x, 0, side.z)
	else:
		BuildKit.box(root, Vector3(w, 0.5, span), Vector3(0, -0.25, 0), mat, false)
		for sx: float in [-1.0, 1.0]:
			BuildKit.box(root, Vector3(0.3, 0.8, span), Vector3(sx * (w * 0.5 - 0.15), 0.4, 0), mat, false)


# --- Ausstattung entlang der Wege ---------------------------------------------

## Läuft den Weg in 1,5-m-Schritten ab und stellt Pfosten, Bänke, Polter, Stufen und Schranken auf.
func _furnish(t: Dictionary) -> void:
	var pts: Array = t["pts"]
	var kind := 1 if t.get("kind", "path") == "track" else 0
	var hw := float(t.get("w", 2.0)) * 0.5
	var mark := Color(str(t.get("mark", "#e8e8e8" if kind == 0 else "#d9b21c")))
	var marker_every: float = _marker_every[kind]
	var next_marker := 14.0
	var next_bench := _bench_every * _rng.randf_range(0.35, 0.8)
	var next_polter := _polter_every * _rng.randf_range(0.3, 0.9)
	var side := 1.0 if _rng.randf() < 0.5 else -1.0
	var dist := 0.0
	var total := 0.0
	for i in pts.size() - 1:
		total += _v(pts[i]).distance_to(_v(pts[i + 1]))
	for i in pts.size() - 1:
		var a := _v(pts[i])
		var b := _v(pts[i + 1])
		var seg := a.distance_to(b)
		var dir := (b - a) / maxf(seg, 0.001)
		var right := Vector2(-dir.y, dir.x)
		var s := 0.0
		while s < seg:
			var p := a + dir * s
			# Markierungspfosten, abwechselnd links/rechts
			if dist >= next_marker and dist < total - 6.0:
				var q := p + right * side * (hw + 0.45)
				if _free(q, 0.25):
					_marker(q, dir, mark)
					side = -side
					next_marker = dist + marker_every * _rng.randf_range(0.85, 1.15)
				else:
					next_marker = dist + 3.0
			# Wanderbank am Wegrand, mit Blick auf den Weg
			if dist >= next_bench and dist < total - 20.0:
				var q := p + right * side * (hw + 1.15)
				if _free(q, 1.0) and _flat(q, dir, 0.35):
					_bench(q, -right * side)
					next_bench = dist + _bench_every * _rng.randf_range(0.8, 1.3)
				else:
					next_bench = dist + 5.0
			# Holzpolter an Fahrwegen
			if kind == 1 and dist >= next_polter and dist < total - 15.0:
				var q := p - right * side * (hw + 2.4)
				if _free(q, 1.3) and _flat(q, dir, 0.6):
					_polter(q, dir)
					next_polter = dist + _polter_every * _rng.randf_range(0.7, 1.4)
				else:
					next_polter = dist + 8.0
			# Stufen an steilen Pfaden
			if kind == 0:
				var h1 := Terrain.height_at(p.x - dir.x * 0.75, p.y - dir.y * 0.75)
				var h2 := Terrain.height_at(p.x + dir.x * 0.75, p.y + dir.y * 0.75)
				if absf(h2 - h1) / 1.5 > _step_slope and _free(p, -10.0, true):
					_add_mm("step", p, Basis(Vector3.UP, atan2(right.x, right.y)) * Basis(Vector3.RIGHT, PI * 0.5) * Basis.from_scale(Vector3(1.0, hw * 2.0 + 0.2, 1.0)),
							Terrain.height_at(p.x, p.y) + 0.03, Color(1, 1, 1))
			s += 1.5
			dist += 1.5
	# Schranke, wo ein Fahrweg von der Zufahrt abgeht
	if kind == 1:
		for end: int in [0, pts.size() - 1]:
			var e := _v(pts[end])
			if e.y > 16.0 and Terrain.road_distance(e.x, e.y) < 8.0:
				var inner := _v(pts[1 if end == 0 else end - 1])
				var d := (inner - e).normalized()
				_barrier(e + d * 9.0, d, hw)


static func _v(a: Array) -> Vector2:
	return Vector2(float(a[0]), float(a[1]))


## Darf hier etwas stehen? (nicht auf einem Weg, nicht im Wasser, nicht im Garten, auf der Zufahrt oder in einem Ort)
static func _free(q: Vector2, keep_off_trail: float, allow_on_trail: bool = false) -> bool:
	if not allow_on_trail and WorldMap.trail_info(q.x, q.y).x < keep_off_trail:
		return false
	if Terrain.yard_distance(q.x, q.y) < 3.0 or z_on_road(q) or Terrain.stream_distance(q.x, q.y) < 5.0:
		return false
	var g := Terrain.height_at(q.x, q.y)
	if Terrain.water_level_at(q.x, q.y) > g - 0.3 or WorldMap.bog_factor(q.x, q.y) > 0.2:
		return false
	for id: String in WorldMap.places():
		var pl: Dictionary = WorldMap.places()[id]
		if (pl["pos"] as Vector2).distance_to(q) < maxf(float(pl.get("flat", 0.0)), 8.0) + 2.0:
			return false
	if CrashSite.is_near(q.x, q.y, 11.0) or AlienStructure.is_near(q.x, q.y, 12.0) or StreamCave.is_near(q.x, q.y, 14.0):
		return false
	return absf(q.x) < WorldMap.limit() - 5.0 and absf(q.y) < WorldMap.limit() - 5.0


## Ist der Boden um q eben genug (Höhenunterschied über ±1 m)?
static func _flat(q: Vector2, dir: Vector2, tol: float) -> bool:
	var hs: Array[float] = []
	for o: Vector2 in [dir, -dir, Vector2(-dir.y, dir.x), Vector2(dir.y, -dir.x)]:
		hs.append(Terrain.height_at(q.x + o.x, q.y + o.y))
	return hs.max() - hs.min() < tol


## Kleinteile sammeln (je Art und 128-m-Bereich ein MultiMesh).
func _add_mm(kind: String, q: Vector2, basis: Basis, y: float, col: Color) -> void:
	var key := "%s|%d|%d" % [kind, int(floorf(q.x / REGION)), int(floorf(q.y / REGION))]
	if not _mm.has(key):
		_mm[key] = [[], []]
	(_mm[key][0] as Array).append(Transform3D(basis, Vector3(q.x, y, q.y)))
	(_mm[key][1] as Array).append(col)


func _flush_multimeshes() -> void:
	var post := BoxMesh.new()
	post.size = Vector3(0.12, 1.25, 0.12)
	var band := BoxMesh.new()
	band.size = Vector3(0.13, 0.12, 0.13)
	var paint := StandardMaterial3D.new()
	paint.vertex_color_use_as_albedo = true
	paint.roughness = 0.7
	var step := CylinderMesh.new()
	step.top_radius = 0.08
	step.bottom_radius = 0.09
	step.height = 1.0
	step.radial_segments = 6
	step.rings = 1
	var meshes := {"post": [post, _post_mat], "band": [band, paint], "step": [step, BuildKit.tex_mat("logs", 0.6)]}
	for key: String in _mm:
		var kind := key.get_slice("|", 0)
		var data: Array = _mm[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = kind == "band"
		mm.mesh = meshes[kind][0]
		mm.instance_count = (data[0] as Array).size()
		for i in mm.instance_count:
			mm.set_instance_transform(i, data[0][i])
			if mm.use_colors:
				mm.set_instance_color(i, data[1][i])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "MM_" + key.replace("|", "_").replace("-", "m")
		mmi.multimesh = mm
		mmi.material_override = meshes[kind][1]
		mmi.visibility_range_end = _view_range
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if kind == "step" else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		add_child(mmi)
	_mm.clear()


## Markierungspfosten: Vierkantholz mit farbigem Kopf (Farbe des Wegs).
func _marker(q: Vector2, dir: Vector2, col: Color) -> void:
	var g := Terrain.height_at(q.x, q.y)
	var b := Basis(Vector3.UP, atan2(dir.x, dir.y) + _rng.randf_range(-0.2, 0.2)) * Basis(Vector3.RIGHT, _rng.randf_range(-0.04, 0.04))
	_add_mm("post", q, b, g + 0.5, Color.WHITE)
	_add_mm("band", q, b, g + 0.5 + (b * Vector3(0, 0.5, 0)).y, col)
	markers.append(Vector3(q.x, g, q.y))


func _view_limit(n: Node) -> void:
	for c in n.get_children():
		if c is GeometryInstance3D:
			(c as GeometryInstance3D).visibility_range_end = _view_range
		_view_limit(c)


## Wanderbank aus zwei Klötzen, Sitzbrett und Rückenlehne; [E] hinsetzen.
func _bench(q: Vector2, facing: Vector2) -> void:
	var g := Terrain.height_at(q.x, q.y)
	var root := Node3D.new()
	root.name = "TrailBench_%d_%d" % [int(q.x), int(q.y)]
	root.position = Vector3(q.x, g - 0.04, q.y)
	root.rotation.y = atan2(facing.x, facing.y)
	add_child(root)
	var seat_mat := BuildKit.tex_mat("planks_h", 0.7, Color(0.9, 0.82, 0.7))
	var log_mat := BuildKit.tex_mat("logs", 0.6)
	for x: float in [-0.62, 0.62]:
		BuildKit.box(root, Vector3(0.14, 0.5, 0.42), Vector3(x, 0.21, 0.0), _dark, false)
		BuildKit.box(root, Vector3(0.1, 0.9, 0.1), Vector3(x, 0.45, -0.2), _dark, false, Vector3(-8, 0, 0))
	BuildKit.box(root, Vector3(1.6, 0.06, 0.42), Vector3(0, 0.47, 0.02), seat_mat, false)
	BuildKit.box(root, Vector3(1.6, 0.16, 0.04), Vector3(0, 0.78, -0.24), seat_mat, false, Vector3(-10, 0, 0))
	BuildKit.box(root, Vector3(1.6, 0.12, 0.04), Vector3(0, 0.6, -0.22), seat_mat, false, Vector3(-10, 0, 0))
	BuildKit.cylinder(root, 0.05, 1.5, Vector3(0, 0.1, 0.0), log_mat, false, Vector3(0, 0, 90), -1.0, 6)
	BuildKit.collider_box(root, Vector3(1.6, 0.5, 0.45), Vector3(0, 0.25, 0))
	var seat := Seat.new()
	seat.name = "Seat"
	seat.label = "Bank"
	seat.spot = Vector3(0, 0.04, 0.32)
	seat.facing = Vector3(0, 0, 1)
	seat.eye = 1.12
	seat.area_size = Vector3(1.6, 0.5, 0.45)
	seat.area_offset = Vector3(0, 0.5, 0)
	root.add_child(seat)
	_view_limit(root)
	benches.append(root.position)


## Holzpolter: gestapelte Stämme parallel zum Weg, die Stirnseiten hell.
func _polter(q: Vector2, dir: Vector2) -> void:
	var g := Terrain.height_at(q.x, q.y)
	var root := Node3D.new()
	root.name = "Polter_%d_%d" % [int(q.x), int(q.y)]
	root.position = Vector3(q.x, g - 0.05, q.y)
	root.rotation.y = atan2(dir.x, dir.y)
	add_child(root)
	var bark := BuildKit.tex_mat("bark", 1.2)
	var ends := BuildKit.log_end_mat()
	var length := _rng.randf_range(3.2, 4.5)
	var rows := _rng.randi_range(2, 4)
	for row in rows:
		var n := 6 - row
		for i in n:
			var r := _rng.randf_range(0.14, 0.2)
			var x := (i - (n - 1) * 0.5) * 0.36
			var off := _rng.randf_range(-0.15, 0.15)
			var trunk := BuildKit.cylinder(root, r, length, Vector3(x, r + row * 0.3, off), bark, false, Vector3(90, 0, 0), -1.0, 8)
			for zs: float in [-1.0, 1.0]:
				var cap := BuildKit.cylinder(trunk, r * 0.95, 0.01, Vector3(0, zs * (length * 0.5 + 0.004), 0), ends, false, Vector3.ZERO, -1.0, 8)
				cap.rotation_degrees = Vector3.ZERO
	BuildKit.collider_box(root, Vector3((6) * 0.36, rows * 0.3 + 0.1, length), Vector3(0, (rows * 0.3 + 0.1) * 0.5, 0))
	_view_limit(root)


## Schranke am Beginn eines Fahrwegs (offen, zur Seite geschwenkt).
func _barrier(q: Vector2, dir: Vector2, hw: float) -> void:
	var right := Vector2(-dir.y, dir.x)
	var base := q + right * (hw + 0.5)
	var g := Terrain.height_at(base.x, base.y)
	var root := Node3D.new()
	root.name = "Barrier_%d_%d" % [int(q.x), int(q.y)]
	root.position = Vector3(base.x, g, base.y)
	root.rotation.y = atan2(dir.x, dir.y)
	add_child(root)
	var metal := BuildKit.color_mat(Color(0.35, 0.36, 0.37), 0.5, 0.6)
	var red := BuildKit.color_mat(Color(0.7, 0.1, 0.08), 0.6)
	var white := BuildKit.color_mat(Color(0.85, 0.85, 0.82), 0.6)
	BuildKit.box(root, Vector3(0.14, 1.0, 0.14), Vector3(0, 0.5, 0), metal, true)
	# Schlagbaum offen: liegt am Wegrand in Laufrichtung, vorn auf einer Gabel
	var len := hw * 2.0 + 0.8
	var seg := 0.4
	var n := int(len / seg)
	for i in n:
		BuildKit.box(root, Vector3(0.08, 0.08, seg), Vector3(0, 0.95, 0.2 + seg * (i + 0.5)), red if i % 2 == 0 else white, false)
	BuildKit.box(root, Vector3(0.06, 0.9, 0.06), Vector3(0, 0.45, len - 0.1), metal, false)
	BuildKit.box(root, Vector3(0.2, 0.25, 0.25), Vector3(0, 0.95, -0.2), metal, false)
	_view_limit(root)


## Wandertafel an der Zufahrt: alle Wege mit Farbe und Zielen.
func _board() -> void:
	var g := Terrain.height_at(_board_pos.x, _board_pos.y)
	var root := Node3D.new()
	root.name = "TrailBoard"
	root.position = Vector3(_board_pos.x, g, _board_pos.y)
	root.rotation.y = PI * 0.5   # Tafel schaut nach Osten zur Zufahrt
	add_child(root)
	for x: float in [-0.75, 0.75]:
		BuildKit.cylinder(root, 0.07, 2.3, Vector3(x, 1.15, -0.05), _dark, true, Vector3.ZERO, 0.06, 7)
	BuildKit.box(root, Vector3(1.6, 1.4, 0.04), Vector3(0, 1.45, -0.01), _dark, false)
	BuildKit.box(root, Vector3(1.5, 1.3, 0.02), Vector3(0, 1.45, 0.015), BuildKit.color_mat(Color(0.86, 0.83, 0.72), 0.8), false)
	BuildKit.box(root, Vector3(1.75, 0.05, 0.42), Vector3(0, 2.16, 0.06), _dark, false, Vector3(18, 0, 0))
	var title := _label(root, "WANDERWEGE", Vector3(0, 1.98, 0.03), 44)
	title.width = 600
	var y := 1.8
	for t: Dictionary in WorldMap.data().get("trails", []):
		if not t.has("board"):
			continue
		var sq := BuildKit.box(root, Vector3(0.08, 0.08, 0.01), Vector3(-0.64, y, 0.03), BuildKit.color_mat(Color(str(t.get("mark", "#ffffff"))), 0.6), false)
		sq.name = "Mark_" + str(t["id"])
		var km := ("%.1f km" % (_length(t) / 1000.0)).replace(".", ",")
		# Zeile beginnt links neben der Farbmarke (linksbündig ab dem Ankerpunkt)
		var lab := _label(root, "%s  (%s)\n%s" % [t.get("name", t["id"]), km, t["board"]], Vector3(-0.56, y, 0.03), 20)
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lab.offset = Vector2.ZERO
		y -= 0.16
	var foot := _label(root, "Bitte auf den Wegen bleiben.", Vector3(0, 0.88, 0.03), 20)
	foot.modulate = Color(0.2, 0.2, 0.2)
	BuildKit.collider_box(root, Vector3(1.6, 1.4, 0.12), Vector3(0, 1.45, 0))


func _label(parent: Node3D, text: String, pos: Vector3, size: int) -> Label3D:
	var lab := Label3D.new()
	lab.text = text
	lab.font_size = size
	lab.pixel_size = 0.0021
	lab.modulate = Color(0.05, 0.05, 0.05)
	lab.outline_size = 0
	lab.double_sided = false
	lab.position = pos
	parent.add_child(lab)
	return lab


static func _length(t: Dictionary) -> float:
	var pts: Array = t["pts"]
	var l := 0.0
	for i in pts.size() - 1:
		l += _v(pts[i]).distance_to(_v(pts[i + 1]))
	return l
