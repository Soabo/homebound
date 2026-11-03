class_name Forest
extends Node3D
## Wald rund um das Grundstück: Tannen mit vielen Astebenen, Laubbäume,
## Büsche, moosige Felsen, Farn, Grasbüschel und Blumen.
## Alles über MultiMesh (schnell); Stämme und große Felsen haben Kollision.

const SEED := 1337
const SPACING := 4.0
const LIMIT := 76.0

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	name = "Forest"
	_rng.seed = SEED
	_build_trees()
	_build_rocks()
	_build_ground_plants()


static func _tree_allowed(x: float, z: float) -> bool:
	if Terrain.yard_distance(x, z) < 2.5:
		return false
	if z > 14.0 and Terrain.road_distance(x, z) < 3.4:
		return false
	if Terrain.stream_distance(x, z) < 3.2:
		return false
	return true


func _build_trees() -> void:
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.55
	trunk_mesh.bottom_radius = 1.0
	trunk_mesh.height = 1.0
	trunk_mesh.radial_segments = 7
	trunk_mesh.rings = 1
	var cone_mesh := CylinderMesh.new()
	cone_mesh.top_radius = 0.0
	cone_mesh.bottom_radius = 1.0
	cone_mesh.height = 1.0
	cone_mesh.radial_segments = 7
	cone_mesh.rings = 1
	var crown_mesh := SphereMesh.new()
	crown_mesh.radius = 1.0
	crown_mesh.height = 2.0
	crown_mesh.radial_segments = 8
	crown_mesh.rings = 5

	var trunks: Array[Transform3D] = []
	var trunk_cols: Array[Color] = []
	var cones: Array[Transform3D] = []
	var cone_cols: Array[Color] = []
	var crowns: Array[Transform3D] = []
	var crown_cols: Array[Color] = []
	var colliders := StaticBody3D.new()
	colliders.name = "TreeColliders"
	add_child(colliders)

	var steps := int(LIMIT * 2.0 / SPACING)
	for gz in steps + 1:
		for gx in steps + 1:
			var x := -LIMIT + gx * SPACING + _rng.randf_range(-1.6, 1.6)
			var z := -LIMIT + gz * SPACING + _rng.randf_range(-1.6, 1.6)
			if not _tree_allowed(x, z) or _rng.randf() > 0.82:
				continue
			var g := Terrain.height_at(x, z)
			var conifer := _rng.randf() > 0.16
			var h := _rng.randf_range(10.0, 19.0) if conifer else _rng.randf_range(8.0, 12.0)
			var r := _rng.randf_range(0.2, 0.38)
			var yaw := _rng.randf() * TAU
			var bark := Color(0.9, 0.85, 0.8).lerp(Color(1.15, 1.05, 0.95), _rng.randf())
			var trunk_h := h * (0.85 if conifer else 0.62)
			var lean := Vector3(_rng.randf_range(-0.04, 0.04), 0, _rng.randf_range(-0.04, 0.04))
			trunks.append(Transform3D(Basis.from_euler(Vector3(lean.x, yaw, lean.z)).scaled(Vector3(r, trunk_h, r)),
					Vector3(x, g + trunk_h * 0.5 - 0.3, z)))
			trunk_cols.append(bark)

			if conifer:
				var green := Color(0.06, 0.13, 0.07).lerp(Color(0.11, 0.18, 0.09), _rng.randf())
				# Viele überlappende, schlanke Kegel ergeben die typische Tannenform.
				var layers := 9
				var crown_r := h * _rng.randf_range(0.15, 0.19)
				var bottom := h * _rng.randf_range(0.12, 0.22)
				for i in layers:
					var f := float(i) / float(layers - 1)
					var lr := crown_r * lerpf(1.0, 0.18, f) * _rng.randf_range(0.9, 1.1)
					var lh := h * lerpf(0.3, 0.2, f)
					var cy := g + lerpf(bottom, h * 0.92, f) + lh * 0.5
					var col := green * lerpf(0.8, 1.2, f)
					col.a = 1.0
					var tilt := Vector3(_rng.randf_range(-0.06, 0.06), yaw + i * 0.7, _rng.randf_range(-0.06, 0.06))
					cones.append(Transform3D(Basis.from_euler(tilt).scaled(Vector3(lr, lh, lr)), Vector3(x, cy, z)))
					cone_cols.append(col)
			else:
				var leaf := Color(0.14, 0.2, 0.08).lerp(Color(0.24, 0.26, 0.1), _rng.randf())
				for i in 5:
					var off := Vector3(_rng.randf_range(-1.6, 1.6), _rng.randf_range(-0.8, 1.2), _rng.randf_range(-1.6, 1.6))
					var s := _rng.randf_range(1.5, 2.5)
					crowns.append(Transform3D(Basis().scaled(Vector3(s, s * 0.75, s)), Vector3(x, g + trunk_h + 0.4, z) + off))
					crown_cols.append(leaf * _rng.randf_range(0.85, 1.15))

			var cs := CollisionShape3D.new()
			var shape := CylinderShape3D.new()
			shape.radius = r * 1.05
			shape.height = 4.0
			cs.shape = shape
			cs.position = Vector3(x, g + 1.8, z)
			colliders.add_child(cs)

	var bark_mat := _textured("bark", 1.5)
	var needle_mat := _textured("grass_ground", 0.8)
	var leaf_mat := _textured("grass_ground", 0.6)
	_add_multimesh("Trunks", trunk_mesh, trunks, trunk_cols, bark_mat, true)
	_add_multimesh("Needles", cone_mesh, cones, cone_cols, needle_mat, true)
	_add_multimesh("Crowns", crown_mesh, crowns, crown_cols, leaf_mat, true)


func _build_rocks() -> void:
	var rock_mesh := SphereMesh.new()
	rock_mesh.radius = 1.0
	rock_mesh.height = 2.0
	rock_mesh.radial_segments = 7
	rock_mesh.rings = 4
	var rocks: Array[Transform3D] = []
	var cols: Array[Color] = []
	var body := StaticBody3D.new()
	body.name = "RockColliders"
	add_child(body)
	var placed := 0
	var tries := 0
	while placed < 140 and tries < 4000:
		tries += 1
		var near_stream := placed < 60
		var z := _rng.randf_range(-LIMIT, LIMIT)
		var x := Terrain.stream_x_at(z) + _rng.randf_range(-3.5, 3.5) if near_stream else _rng.randf_range(-LIMIT, LIMIT)
		if Terrain.yard_distance(x, z) < 1.5 or Terrain.road_distance(x, z) < 3.0:
			continue
		var g := Terrain.height_at(x, z)
		var s := _rng.randf_range(0.25, 0.8) if near_stream else _rng.randf_range(0.3, 1.5)
		var scale := Vector3(s * _rng.randf_range(1.0, 1.7), s * _rng.randf_range(0.5, 0.85), s * _rng.randf_range(1.0, 1.5))
		rocks.append(Transform3D(Basis.from_euler(Vector3(_rng.randf() * 0.4, _rng.randf() * TAU, _rng.randf() * 0.4)).scaled(scale),
				Vector3(x, g + scale.y * 0.25, z)))
		var mossy := _rng.randf() < 0.6
		cols.append(Color(0.75, 0.75, 0.72) * _rng.randf_range(0.8, 1.1) if not mossy else Color(0.45, 0.6, 0.32) * _rng.randf_range(0.8, 1.1))
		if s > 0.7:
			var cs := CollisionShape3D.new()
			var shape := SphereShape3D.new()
			shape.radius = maxf(scale.x, scale.z) * 0.75
			cs.shape = shape
			cs.position = Vector3(x, g, z)
			body.add_child(cs)
		placed += 1
	_add_multimesh("Rocks", rock_mesh, rocks, cols, _textured("stone", 1.2), true)


func _build_ground_plants() -> void:
	var cross := _cross_quad_mesh()
	var grass: Array[Transform3D] = []
	var grass_cols: Array[Color] = []
	var ferns: Array[Transform3D] = []
	var fern_cols: Array[Color] = []
	var bush_mesh := SphereMesh.new()
	bush_mesh.radius = 1.0
	bush_mesh.height = 2.0
	bush_mesh.radial_segments = 7
	bush_mesh.rings = 4
	var bushes: Array[Transform3D] = []
	var bush_cols: Array[Color] = []
	var flower_mesh := SphereMesh.new()
	flower_mesh.radius = 1.0
	flower_mesh.height = 2.0
	flower_mesh.radial_segments = 5
	flower_mesh.rings = 3
	var flowers: Array[Transform3D] = []
	var flower_cols: Array[Color] = []

	# Grasbüschel: dicht im Garten (nicht auf Wegen, nicht unter Gebäuden) und am Waldrand
	var tries := 0
	while grass.size() < 6000 and tries < 30000:
		tries += 1
		var x := _rng.randf_range(-LIMIT, LIMIT)
		var z := _rng.randf_range(-LIMIT, LIMIT)
		var yd := Terrain.yard_distance(x, z)
		if yd > 8.0 and _rng.randf() < 0.75:
			continue
		if _blocked_for_plants(x, z):
			continue
		var g := Terrain.height_at(x, z)
		var s := _rng.randf_range(0.35, 0.75)
		grass.append(Transform3D(Basis.from_euler(Vector3(0, _rng.randf() * TAU, 0)).scaled(Vector3(s, s * _rng.randf_range(0.8, 1.3), s)), Vector3(x, g - 0.02, z)))
		var gc := Color(0.75, 0.9, 0.6).lerp(Color(1.1, 1.05, 0.7), _rng.randf())
		grass_cols.append(gc)

	# Farn im Wald und am Bach
	tries = 0
	while ferns.size() < 1600 and tries < 20000:
		tries += 1
		var by_stream := _rng.randf() < 0.3
		var z := _rng.randf_range(-LIMIT, LIMIT)
		var x := Terrain.stream_x_at(z) + _rng.randf_range(-6.0, 6.0) if by_stream else _rng.randf_range(-LIMIT, LIMIT)
		if Terrain.yard_distance(x, z) < 0.5 or _blocked_for_plants(x, z) or Terrain.stream_distance(x, z) < 1.4:
			continue
		var g := Terrain.height_at(x, z)
		var s := _rng.randf_range(0.6, 1.2)
		ferns.append(Transform3D(Basis.from_euler(Vector3(0, _rng.randf() * TAU, 0)).scaled(Vector3(s, s, s)), Vector3(x, g - 0.03, z)))
		fern_cols.append(Color(0.8, 0.95, 0.7) * _rng.randf_range(0.75, 1.1))

	# Büsche
	tries = 0
	while bushes.size() < 260 and tries < 5000:
		tries += 1
		var x := _rng.randf_range(-LIMIT, LIMIT)
		var z := _rng.randf_range(-LIMIT, LIMIT)
		if Terrain.yard_distance(x, z) < 0.8 or _blocked_for_plants(x, z) or Terrain.stream_distance(x, z) < 2.0:
			continue
		var g := Terrain.height_at(x, z)
		var s := _rng.randf_range(0.5, 1.2)
		bushes.append(Transform3D(Basis.from_euler(Vector3(0, _rng.randf() * TAU, 0)).scaled(Vector3(s * 1.3, s * 0.75, s * 1.2)), Vector3(x, g + s * 0.3, z)))
		bush_cols.append(Color(0.5, 0.75, 0.4).lerp(Color(0.8, 0.95, 0.55), _rng.randf()))

	# Kleine weiße und gelbe Blüten am Waldrand und am Bach
	tries = 0
	while flowers.size() < 900 and tries < 20000:
		tries += 1
		var cx := _rng.randf_range(-LIMIT, LIMIT)
		var cz := _rng.randf_range(-LIMIT, LIMIT)
		if _rng.randf() < 0.5:
			cx = Terrain.stream_x_at(cz) + _rng.randf_range(-5.0, 5.0)
		var yd := Terrain.yard_distance(cx, cz)
		if (yd < -1.0 or yd > 6.0) and Terrain.stream_distance(cx, cz) > 5.0:
			continue
		if _blocked_for_plants(cx, cz) or Terrain.stream_distance(cx, cz) < 1.6:
			continue
		for k in 4:
			var x := cx + _rng.randf_range(-0.4, 0.4)
			var z := cz + _rng.randf_range(-0.4, 0.4)
			var g := Terrain.height_at(x, z)
			flowers.append(Transform3D(Basis().scaled(Vector3(0.035, 0.025, 0.035)), Vector3(x, g + _rng.randf_range(0.12, 0.25), z)))
			flower_cols.append(Color(0.95, 0.95, 0.88) if _rng.randf() < 0.75 else Color(0.95, 0.8, 0.25))

	var grass_mat := BuildKit.cutout_mat("grass_blades")
	var fern_mat := BuildKit.cutout_mat("fern")
	_add_multimesh("Grass", cross, grass, grass_cols, grass_mat, false)
	_add_multimesh("Ferns", cross, ferns, fern_cols, fern_mat, false)
	_add_multimesh("Bushes", bush_mesh, bushes, bush_cols, _textured("grass_ground", 0.5), true)
	var flower_mat := StandardMaterial3D.new()
	flower_mat.vertex_color_use_as_albedo = true
	flower_mat.roughness = 1.0
	_add_multimesh("Flowers", flower_mesh, flowers, flower_cols, flower_mat, false)


## Keine Pflanzen auf Wegen, im Haus, im Schuppen oder im Wasser.
static func _blocked_for_plants(x: float, z: float) -> bool:
	if absf(x) < 7.2 and z > -5.2 and z < 7.8:
		return true
	if absf(x - Shed.ORIGIN.x) < 2.6 and absf(z - Shed.ORIGIN.z) < 2.3:
		return true
	if z > 6.5 and Terrain.road_distance(x, z) < 2.2:
		return true
	return false


## Zwei gekreuzte senkrechte Flächen, Fußpunkt bei y = 0, 1 m hoch.
static func _cross_quad_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for a: float in [0.0, PI * 0.5]:
		var d := Vector3(cos(a), 0, sin(a)) * 0.5
		var n := Vector3(-sin(a), 0, cos(a))
		var p0 := -d
		var p1 := d
		var p2 := d + Vector3.UP
		var p3 := -d + Vector3.UP
		var uvs := [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
		var pts := [p0, p1, p2, p3]
		for idx: int in [0, 2, 1, 0, 3, 2]:
			st.set_normal(Vector3.UP.lerp(n, 0.3).normalized())
			st.set_uv(uvs[idx])
			st.add_vertex(pts[idx])
	return st.commit()


func _textured(kind: String, repeat_m: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = TextureFactory.get_texture(kind)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	var s := 1.0 / repeat_m
	m.uv1_scale = Vector3(s, s, s)
	m.roughness = 0.95
	return m


func _add_multimesh(node_name: String, mesh: Mesh, transforms: Array[Transform3D], colors: Array[Color],
		mat: Material, shadows: bool) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
		mm.set_instance_color(i, colors[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = node_name
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
