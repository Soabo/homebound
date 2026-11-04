class_name CornField
extends Node3D
## Maisfeld neben dem Schuppen bis fast an den Ost- und Südzaun.
## Spätsommerlich trocken, in Reihen gepflanzt, mit gepflügten Furchen und einer Vogelscheuche.
## Die Pflanzen haben keine Kollision: man (und die Kreatur) kann sich hindurchbewegen –
## aber sie verdecken die Sicht.

## Feldflächen (x, z, Breite, Tiefe) – L-Form um die Südost-Ecke des Schuppens
const AREAS := [
	Rect2(12.6, 9.4, 8.7, 7.9),
	Rect2(16.8, 2.8, 4.5, 6.6),
]
const ROW_SPACING := 0.75
const PLANT_SPACING := 0.32
## Freie Stelle um den alten Laubbaum
const TREE_SPOT := Vector2(17.5, 14.0)
const SCARECROW_SPOT := Vector3(15.6, 0.0, 13.2)

var _rng := RandomNumberGenerator.new()


static func is_inside(x: float, z: float) -> bool:
	for r: Rect2 in AREAS:
		if r.grow(0.2).has_point(Vector2(x, z)):
			return true
	return false


func _ready() -> void:
	name = "CornField"
	_rng.seed = 404
	_build_soil()
	_build_plants()
	_build_scarecrow()


func _build_soil() -> void:
	var soil := BuildKit.tex_mat("grass_ground", 0.6, Color(0.36, 0.25, 0.16))
	var ridge := BuildKit.tex_mat("grass_ground", 0.4, Color(0.42, 0.3, 0.2))
	for r: Rect2 in AREAS:
		var g := Terrain.height_at(r.get_center().x, r.get_center().y)
		BuildKit.box_mm(self, Vector3(r.position.x, g - 0.02, r.position.y), Vector3(r.end.x, g + 0.015, r.end.y), soil, false)
		# Erdwälle der Pflanzreihen
		var x := r.position.x + ROW_SPACING * 0.5
		while x < r.end.x:
			BuildKit.box_mm(self, Vector3(x - 0.16, g, r.position.y + 0.1), Vector3(x + 0.16, g + 0.07, r.end.y - 0.1), ridge, false)
			x += ROW_SPACING


func _build_plants() -> void:
	var variants: Array[ArrayMesh] = []
	for v in 3:
		variants.append(_corn_mesh(1000 + v * 17))
	var per_variant: Array = [[], [], []]
	var cols: Array = [[], [], []]
	for r: Rect2 in AREAS:
		var x := r.position.x + ROW_SPACING * 0.5
		while x < r.end.x:
			var z := r.position.y + 0.2
			while z < r.end.y - 0.15:
				z += PLANT_SPACING * _rng.randf_range(0.8, 1.2)
				if _rng.randf() < 0.06:
					continue  # Lücke in der Reihe
				var p := Vector2(x + _rng.randf_range(-0.07, 0.07), z)
				if p.distance_to(TREE_SPOT) < 1.6 or Vector2(p.x - SCARECROW_SPOT.x, p.y - SCARECROW_SPOT.z).length() < 0.7:
					continue
				if is_inside(p.x, p.y) and _overlaps_other_area(p, r):
					continue
				var s := _rng.randf_range(0.85, 1.15)
				var tilt := Vector3(_rng.randf_range(-0.06, 0.06), _rng.randf() * TAU, _rng.randf_range(-0.06, 0.06))
				# Ein paar umgeknickte Stängel
				if _rng.randf() < 0.03:
					tilt.x = _rng.randf_range(0.5, 0.9)
				var t := Transform3D(Basis.from_euler(tilt).scaled(Vector3(s, s * _rng.randf_range(0.9, 1.1), s)),
						Vector3(p.x, Terrain.height_at(p.x, p.y) + 0.05, p.y))
				var v := _rng.randi() % variants.size()
				per_variant[v].append(t)
				# trocken: mal mehr grün, mal mehr braun
				cols[v].append(Color(0.9, 0.92, 0.85).lerp(Color(0.85, 0.72, 0.55), _rng.randf()) * _rng.randf_range(0.75, 0.95))
			x += ROW_SPACING
	for v in variants.size():
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = variants[v]
		mm.instance_count = per_variant[v].size()
		for i in per_variant[v].size():
			mm.set_instance_transform(i, per_variant[v][i])
			mm.set_instance_color(i, cols[v][i])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Corn%d" % v
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		add_child(mmi)


## Die zweite Fläche schließt an die erste an – doppelte Pflanzen am Übergang vermeiden.
func _overlaps_other_area(p: Vector2, own: Rect2) -> bool:
	for r: Rect2 in AREAS:
		if r != own and r.has_point(p) and r.position.y < own.position.y:
			return true
	return false


## Eine Maispflanze (ca. 2,1 m): Stängel, gebogene Blätter, Rispe oben, ein bis zwei Kolben.
## Zwei Flächen: Stängel/Kolben (fest) und Blätter (Textur mit Spitze, beidseitig).
func _corn_mesh(seed_value: int) -> ArrayMesh:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var height := r.randf_range(1.9, 2.3)
	var stalk_col := Color(0.7, 0.62, 0.4)
	# Stängel: leicht gebogen und nach oben dünner
	var bend := Vector3(r.randf_range(-0.08, 0.08), 0, r.randf_range(-0.08, 0.08))
	var rings := 6
	var sides := 5
	for i in rings:
		var t0 := float(i) / rings
		var t1 := float(i + 1) / rings
		var c0 := Vector3(0, t0 * height, 0) + bend * t0 * t0
		var c1 := Vector3(0, t1 * height, 0) + bend * t1 * t1
		var r0 := lerpf(0.028, 0.012, t0)
		var r1 := lerpf(0.028, 0.012, t1)
		for k in sides:
			var a0 := TAU * k / sides
			var a1 := TAU * (k + 1) / sides
			var d0 := Vector3(cos(a0), 0, sin(a0))
			var d1 := Vector3(cos(a1), 0, sin(a1))
			var col := stalk_col * lerpf(0.7, 1.05, t0)
			_vert(st, c0 + d0 * r0, d0, col)
			_vert(st, c1 + d1 * r1, d1, col)
			_vert(st, c1 + d0 * r1, d0, col)
			_vert(st, c0 + d0 * r0, d0, col)
			_vert(st, c0 + d1 * r0, d1, col)
			_vert(st, c1 + d1 * r1, d1, col)
	# Kolben mit Lieschblättern
	var cobs := 1 if r.randf() < 0.6 else 2
	for c in cobs:
		var h := r.randf_range(0.85, 1.25)
		var a := r.randf() * TAU
		var base := Vector3(0, h, 0) + bend * (h / height) * (h / height)
		var dir := Vector3(cos(a) * 0.45, 1.0, sin(a) * 0.45).normalized()
		_spindle(st, base + Vector3(cos(a), 0, sin(a)) * 0.02, dir, 0.24, 0.035, Color(0.88, 0.8, 0.55))
		# aufgeplatzte Spitze mit Narbenfäden
		_spindle(st, base + dir * 0.22, dir.lerp(Vector3.DOWN, 0.4).normalized(), 0.08, 0.012, Color(0.45, 0.28, 0.15))
	# Rispe an der Spitze
	var top := Vector3(0, height, 0) + bend
	for k in 5:
		var a := TAU * k / 5.0 + r.randf() * 0.5
		var d := Vector3(cos(a) * 0.5, 1.0, sin(a) * 0.5).normalized()
		_spindle(st, top, d, r.randf_range(0.18, 0.28), 0.008, Color(0.78, 0.66, 0.4))
	_spindle(st, top - Vector3(0, 0.02, 0), Vector3.UP, 0.3, 0.01, Color(0.8, 0.68, 0.42))
	var mesh := ArrayMesh.new()
	st.commit(mesh)
	var stalk_mat := StandardMaterial3D.new()
	stalk_mat.vertex_color_use_as_albedo = true
	stalk_mat.roughness = 1.0
	mesh.surface_set_material(0, stalk_mat)

	# Blätter: lange, bogenförmig hängende Bänder, abwechselnd zu beiden Seiten
	var lt := SurfaceTool.new()
	lt.begin(Mesh.PRIMITIVE_TRIANGLES)
	var leaves := r.randi_range(10, 13)
	var side := r.randf() * TAU
	for i in leaves:
		var h := lerpf(0.25, height * 0.9, float(i) / leaves) + r.randf_range(-0.05, 0.05)
		side += PI + r.randf_range(-0.6, 0.6)
		var out := Vector3(cos(side), 0, sin(side))
		var length := r.randf_range(0.55, 0.85) * (1.0 - float(i) / leaves * 0.35)
		var width := r.randf_range(0.085, 0.12)
		var droop := r.randf_range(0.6, 1.4)
		var start := Vector3(0, h, 0) + bend * (h / height) * (h / height) + out * 0.015
		var right := out.cross(Vector3.UP).normalized()
		var seg := 5
		# trockene Blätter unten, grünere oben
		var col := Color(0.6, 0.5, 0.3).lerp(Color(0.5, 0.62, 0.28), clampf(float(i) / leaves + r.randf_range(-0.2, 0.2), 0.0, 1.0))
		var prev_c := start
		var prev_w := width * 0.6
		for j in seg:
			var t := float(j + 1) / seg
			# steigt erst an, dann hängt das Blatt nach unten
			var c := start + out * (length * t) + Vector3(0, length * (0.55 * t - droop * t * t * 0.7), 0)
			var w := width * (1.0 - t * 0.4)
			var v0 := 1.0 - float(j) / seg
			var v1 := 1.0 - t
			var n := Vector3.UP.lerp(out, t * 0.6).normalized()
			_leaf_vert(lt, prev_c - right * prev_w, Vector2(0, v0), n, col)
			_leaf_vert(lt, c + right * w, Vector2(1, v1), n, col)
			_leaf_vert(lt, prev_c + right * prev_w, Vector2(1, v0), n, col)
			_leaf_vert(lt, prev_c - right * prev_w, Vector2(0, v0), n, col)
			_leaf_vert(lt, c - right * w, Vector2(0, v1), n, col)
			_leaf_vert(lt, c + right * w, Vector2(1, v1), n, col)
			prev_c = c
			prev_w = w
	lt.commit(mesh)
	var leaf_mat := BuildKit.cutout_mat("corn_leaf")
	mesh.surface_set_material(1, leaf_mat)
	return mesh


func _vert(st: SurfaceTool, p: Vector3, n: Vector3, c: Color) -> void:
	st.set_color(c)
	st.set_normal(n)
	st.add_vertex(p)


func _leaf_vert(st: SurfaceTool, p: Vector3, uv: Vector2, n: Vector3, c: Color) -> void:
	st.set_color(c)
	st.set_uv(uv)
	st.set_normal(n)
	st.add_vertex(p)


## Spindelform (Kolben, Rispenäste): dick in der Mitte, spitz an den Enden.
func _spindle(st: SurfaceTool, base: Vector3, dir: Vector3, length: float, radius: float, col: Color) -> void:
	var right := dir.cross(Vector3.FORWARD if absf(dir.z) < 0.9 else Vector3.RIGHT).normalized()
	var fwd := dir.cross(right).normalized()
	var sides := 5
	var steps := 3
	for i in steps:
		var t0 := float(i) / steps
		var t1 := float(i + 1) / steps
		var r0 := radius * sin(PI * clampf(t0 * 0.85 + 0.15, 0.0, 1.0))
		var r1 := radius * sin(PI * clampf(t1 * 0.85 + 0.15, 0.0, 1.0))
		for k in sides:
			var a0 := TAU * k / sides
			var a1 := TAU * (k + 1) / sides
			var d0 := right * cos(a0) + fwd * sin(a0)
			var d1 := right * cos(a1) + fwd * sin(a1)
			var p00 := base + dir * length * t0 + d0 * r0
			var p01 := base + dir * length * t0 + d1 * r0
			var p10 := base + dir * length * t1 + d0 * r1
			var p11 := base + dir * length * t1 + d1 * r1
			_vert(st, p00, d0, col)
			_vert(st, p11, d1, col)
			_vert(st, p10, d0, col)
			_vert(st, p00, d0, col)
			_vert(st, p01, d1, col)
			_vert(st, p11, d1, col)


## Vogelscheuche aus Latten, Jutesack-Kopf, alter Jacke und Hut.
func _build_scarecrow() -> void:
	var root := Node3D.new()
	root.name = "Scarecrow"
	root.position = SCARECROW_SPOT + Vector3(0, Terrain.height_at(SCARECROW_SPOT.x, SCARECROW_SPOT.z), 0)
	root.rotation_degrees = Vector3(0, -35.0, 3.0)
	add_child(root)
	var wood := BuildKit.tex_mat("planks_v", 0.5, Color(0.8, 0.75, 0.7))
	var sack := BuildKit.tex_mat("fabric", 0.25, Color(1.5, 1.3, 0.95))
	var coat := BuildKit.tex_mat("fabric", 0.3, Color(0.75, 0.8, 0.7))
	var shirt := BuildKit.tex_mat("fabric_red", 0.25, Color(0.9, 0.85, 0.85))
	var straw := BuildKit.color_mat(Color(0.75, 0.62, 0.35))
	var dark := BuildKit.color_mat(Color(0.06, 0.05, 0.05))
	BuildKit.box(root, Vector3(0.08, 2.4, 0.08), Vector3(0, 1.2, 0), wood, true)
	BuildKit.box(root, Vector3(1.5, 0.07, 0.07), Vector3(0, 1.65, 0), wood, false, Vector3(0, 0, -4))
	# Körper: Hemd und offene Jacke
	BuildKit.box(root, Vector3(0.42, 0.62, 0.22), Vector3(0, 1.38, 0), shirt, false)
	BuildKit.box(root, Vector3(0.2, 0.66, 0.26), Vector3(-0.15, 1.36, 0.0), coat, false, Vector3(0, 0, 4))
	BuildKit.box(root, Vector3(0.2, 0.66, 0.26), Vector3(0.15, 1.36, 0.0), coat, false, Vector3(0, 0, -4))
	for sx: float in [-1.0, 1.0]:
		BuildKit.box(root, Vector3(0.55, 0.17, 0.18), Vector3(sx * 0.45, 1.63, 0), coat, false, Vector3(0, 0, -4 + sx * -6))
		# Stroh quillt aus den Ärmeln
		for k in 4:
			BuildKit.box(root, Vector3(0.12, 0.012, 0.012), Vector3(sx * (0.76 + k * 0.012), 1.6 + k * 0.02 - 0.03, (k - 1.5) * 0.03), straw, false, Vector3(0, k * 20.0, sx * (-20.0 + k * 15.0)))
	# Kopf: zugebundener Jutesack, aufgenähte Augen, schief
	var head := BuildKit.sphere(root, 0.17, Vector3(0.02, 1.98, 0), sack, Vector3(1.0, 1.15, 0.95), 10)
	head.rotation_degrees.z = 14.0
	BuildKit.cylinder(root, 0.06, 0.08, Vector3(0, 1.8, 0), sack, false, Vector3.ZERO, 0.045, 8)
	BuildKit.cylinder(root, 0.065, 0.015, Vector3(0, 1.83, 0), BuildKit.color_mat(Color(0.3, 0.22, 0.14)), false, Vector3.ZERO, -1.0, 8)
	for ex: float in [-0.06, 0.06]:
		BuildKit.box(root, Vector3(0.05, 0.012, 0.01), Vector3(ex + 0.03, 2.02 + ex * 0.2, 0.165), dark, false, Vector3(0, 0, 45))
		BuildKit.box(root, Vector3(0.05, 0.012, 0.01), Vector3(ex + 0.03, 2.02 + ex * 0.2, 0.165), dark, false, Vector3(0, 0, -45))
	BuildKit.box(root, Vector3(0.14, 0.01, 0.01), Vector3(0.02, 1.92, 0.16), dark, false, Vector3(0, 0, -8))
	# Hut mit Krempe
	var hat := BuildKit.tex_mat("fabric", 0.3, Color(0.55, 0.45, 0.35))
	BuildKit.cylinder(root, 0.3, 0.02, Vector3(0.04, 2.15, 0), hat, false, Vector3(0, 0, 12), -1.0, 12)
	BuildKit.cylinder(root, 0.13, 0.16, Vector3(0.05, 2.24, 0), hat, false, Vector3(0, 0, 12), 0.11, 10)
