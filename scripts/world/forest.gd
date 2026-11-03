class_name Forest
extends Node3D
## Wald rund um das Grundstück: Nadelbäume, einige Laubbäume, Büsche, Felsen.
## Gezeichnet über MultiMesh (schnell), Stämme haben Kollision.

const SEED := 1337
const SPACING := 4.0
const LIMIT := 76.0


func _ready() -> void:
	name = "Forest"
	_build()


func _build() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED

	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.65
	trunk_mesh.bottom_radius = 1.0
	trunk_mesh.height = 1.0
	trunk_mesh.radial_segments = 8
	trunk_mesh.rings = 1

	var cone_mesh := CylinderMesh.new()
	cone_mesh.top_radius = 0.0
	cone_mesh.bottom_radius = 1.0
	cone_mesh.height = 1.0
	cone_mesh.radial_segments = 9
	cone_mesh.rings = 1

	var crown_mesh := SphereMesh.new()
	crown_mesh.radius = 1.0
	crown_mesh.height = 2.0
	crown_mesh.radial_segments = 10
	crown_mesh.rings = 6

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
			var x := -LIMIT + gx * SPACING + rng.randf_range(-1.6, 1.6)
			var z := -LIMIT + gz * SPACING + rng.randf_range(-1.6, 1.6)
			if not _tree_allowed(x, z):
				continue
			if rng.randf() > 0.82:
				continue
			var ground := Terrain.height_at(x, z)
			var conifer := rng.randf() > 0.16
			var h := rng.randf_range(9.0, 17.0) if conifer else rng.randf_range(8.0, 12.0)
			var r := rng.randf_range(0.18, 0.34)
			var yaw := rng.randf() * TAU
			var bark := Color(0.24, 0.17, 0.12).lerp(Color(0.32, 0.25, 0.19), rng.randf())

			var trunk_h := h * (0.75 if conifer else 0.62)
			trunks.append(Transform3D(Basis.from_euler(Vector3(0, yaw, 0)).scaled(Vector3(r, trunk_h, r)),
					Vector3(x, ground + trunk_h * 0.5 - 0.2, z)))
			trunk_cols.append(bark)

			if conifer:
				var green := Color(0.07, 0.14, 0.08).lerp(Color(0.12, 0.19, 0.1), rng.randf())
				var layers := 4
				var crown_r := h * rng.randf_range(0.17, 0.23)
				for i in layers:
					var f := float(i) / float(layers)
					var lr := crown_r * (1.0 - f * 0.62)
					var lh := h * 0.36
					var cy := ground + h * (0.28 + f * 0.19) + lh * 0.5
					cones.append(Transform3D(Basis.from_euler(Vector3(0, yaw + i, 0)).scaled(Vector3(lr, lh, lr)),
							Vector3(x, cy, z)))
					cone_cols.append(green)
			else:
				var leaf := Color(0.16, 0.22, 0.09).lerp(Color(0.25, 0.27, 0.11), rng.randf())
				for i in 3:
					var off := Vector3(rng.randf_range(-1.2, 1.2), rng.randf_range(-0.6, 0.8), rng.randf_range(-1.2, 1.2))
					var s := rng.randf_range(1.8, 2.8)
					crowns.append(Transform3D(Basis().scaled(Vector3(s, s * 0.8, s)),
							Vector3(x, ground + trunk_h + 0.6, z) + off))
					crown_cols.append(leaf)

			var cs := CollisionShape3D.new()
			var shape := CylinderShape3D.new()
			shape.radius = r * 1.05
			shape.height = 4.0
			cs.shape = shape
			cs.position = Vector3(x, ground + 1.8, z)
			colliders.add_child(cs)

	_add_multimesh("Trunks", trunk_mesh, trunks, trunk_cols, 0.95)
	_add_multimesh("Needles", cone_mesh, cones, cone_cols, 0.9)
	_add_multimesh("Crowns", crown_mesh, crowns, crown_cols, 0.9)
	_build_undergrowth(rng)


static func _tree_allowed(x: float, z: float) -> bool:
	if Terrain.yard_distance(x, z) < 2.5:
		return false
	if z > 14.0 and Terrain.road_distance(x, z) < 3.4:
		return false
	return true


func _build_undergrowth(rng: RandomNumberGenerator) -> void:
	var bush_mesh := SphereMesh.new()
	bush_mesh.radius = 1.0
	bush_mesh.height = 2.0
	bush_mesh.radial_segments = 8
	bush_mesh.rings = 5
	var rock_mesh := SphereMesh.new()
	rock_mesh.radius = 1.0
	rock_mesh.height = 2.0
	rock_mesh.radial_segments = 7
	rock_mesh.rings = 4

	var bushes: Array[Transform3D] = []
	var bush_cols: Array[Color] = []
	var rocks: Array[Transform3D] = []
	var rock_cols: Array[Color] = []
	var rock_body := StaticBody3D.new()
	rock_body.name = "RockColliders"
	add_child(rock_body)

	var placed := 0
	while placed < 320:
		var x := rng.randf_range(-LIMIT, LIMIT)
		var z := rng.randf_range(-LIMIT, LIMIT)
		if Terrain.yard_distance(x, z) < 0.5 or Terrain.road_distance(x, z) < 2.6:
			continue
		var g := Terrain.height_at(x, z)
		var s := rng.randf_range(0.5, 1.2)
		bushes.append(Transform3D(Basis.from_euler(Vector3(0, rng.randf() * TAU, 0)).scaled(Vector3(s * 1.3, s * 0.75, s * 1.2)),
				Vector3(x, g + s * 0.35, z)))
		bush_cols.append(Color(0.1, 0.17, 0.08).lerp(Color(0.19, 0.24, 0.1), rng.randf()))
		placed += 1

	placed = 0
	while placed < 70:
		var x := rng.randf_range(-LIMIT, LIMIT)
		var z := rng.randf_range(-LIMIT, LIMIT)
		if Terrain.yard_distance(x, z) < 1.5 or Terrain.road_distance(x, z) < 3.0:
			continue
		var g := Terrain.height_at(x, z)
		var s := rng.randf_range(0.3, 1.4)
		var scale := Vector3(s * rng.randf_range(1.0, 1.8), s * rng.randf_range(0.5, 0.9), s * rng.randf_range(1.0, 1.6))
		rocks.append(Transform3D(Basis.from_euler(Vector3(rng.randf() * 0.4, rng.randf() * TAU, rng.randf() * 0.4)).scaled(scale),
				Vector3(x, g + scale.y * 0.3, z)))
		rock_cols.append(Color(0.34, 0.34, 0.32).lerp(Color(0.45, 0.44, 0.4), rng.randf()))
		if s > 0.7:
			var cs := CollisionShape3D.new()
			var shape := SphereShape3D.new()
			shape.radius = maxf(scale.x, scale.z) * 0.8
			cs.shape = shape
			cs.position = Vector3(x, g, z)
			rock_body.add_child(cs)
		placed += 1

	_add_multimesh("Bushes", bush_mesh, bushes, bush_cols, 0.95)
	_add_multimesh("Rocks", rock_mesh, rocks, rock_cols, 0.95)


func _add_multimesh(node_name: String, mesh: Mesh, transforms: Array[Transform3D], colors: Array[Color],
		roughness: float) -> void:
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = roughness
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
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(mmi)
