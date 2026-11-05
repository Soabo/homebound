class_name Forest
extends Node3D
## Wald rund um das Grundstück: Tannen mit vielen Astebenen, Laubbäume,
## Büsche, moosige Felsen, Farn, Grasbüschel und Blumen.
## Alles über MultiMesh (schnell); Stämme und große Felsen haben Kollision.

const SEED := 1337
const SPACING := 4.0
const LIMIT := 108.0

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	name = "Forest"
	_rng.seed = SEED
	_build_trees()
	_build_rocks()
	_build_ground_plants()
	_build_forest_details()


static func _tree_allowed(x: float, z: float) -> bool:
	if Terrain.yard_distance(x, z) < 2.5:
		return false
	if CrashSite.is_near(x, z, 10.0):
		return false
	if AlienStructure.is_near(x, z, 12.0) or RangerTower.is_near(x, z, 5.0) or StreamCave.is_near(x, z, 13.0):
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
	trunk_mesh.radial_segments = 10
	trunk_mesh.rings = 1
	var cone_mesh := _fir_layer_mesh(11)
	var crown_mesh := _leaf_cluster_mesh()

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
					cones.append(Transform3D(Basis.from_euler(tilt).scaled(Vector3(lr, lh, lr)), Vector3(x, cy - lh * 0.5, z)))
					cone_cols.append(col)
			else:
				var leaf := Color(0.14, 0.2, 0.08).lerp(Color(0.24, 0.26, 0.1), _rng.randf())
				for i in 9:
					var off := Vector3(_rng.randf_range(-1.8, 1.8), _rng.randf_range(-1.2, 1.6), _rng.randf_range(-1.8, 1.8))
					var s := _rng.randf_range(2.2, 3.4)
					var rot := Basis.from_euler(Vector3(_rng.randf_range(-0.4, 0.4), _rng.randf() * TAU, _rng.randf_range(-0.4, 0.4)))
					crowns.append(Transform3D(rot.scaled(Vector3(s, s, s)), Vector3(x, g + trunk_h - 0.4, z) + off))
					var lc := Color(0.75, 0.85, 0.6) * _rng.randf_range(0.75, 1.15)
					lc.a = 1.0
					crown_cols.append(lc)

			var cs := CollisionShape3D.new()
			var shape := CylinderShape3D.new()
			shape.radius = r * 1.05
			shape.height = 4.0
			cs.shape = shape
			cs.position = Vector3(x, g + 1.8, z)
			colliders.add_child(cs)

	var bark_mat := _textured("bark", 1.5)
	var needle_mat := _textured("needles", 0.9)
	needle_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var leaf_mat := BuildKit.cutout_mat("leaves")
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
	while placed < 230 and tries < 6000:
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
	while grass.size() < 15000 and tries < 80000:
		tries += 1
		var x := _rng.randf_range(-LIMIT, LIMIT)
		var z := _rng.randf_range(-LIMIT, LIMIT)
		var yd := Terrain.yard_distance(x, z)
		if yd > 8.0 and _rng.randf() < 0.6:
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
	while ferns.size() < 4800 and tries < 60000:
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
	while bushes.size() < 440 and tries < 8000:
		tries += 1
		var x := _rng.randf_range(-LIMIT, LIMIT)
		var z := _rng.randf_range(-LIMIT, LIMIT)
		if Terrain.yard_distance(x, z) < 0.8 or _blocked_for_plants(x, z) or Terrain.stream_distance(x, z) < 2.0:
			continue
		var g := Terrain.height_at(x, z)
		var s := _rng.randf_range(0.5, 1.2)
		bushes.append(Transform3D(Basis.from_euler(Vector3(0, _rng.randf() * TAU, 0)).scaled(Vector3(s * 1.25, s * 0.9, s * 1.2)), Vector3(x, g - 0.05, z)))
		bush_cols.append(Color(0.48, 0.62, 0.4).lerp(Color(0.72, 0.82, 0.52), _rng.randf()))

	# Kleine weiße und gelbe Blüten am Waldrand und am Bach
	tries = 0
	while flowers.size() < 2200 and tries < 40000:
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
	# Drei Buschformen im Wechsel
	for v in 3:
		var tv: Array[Transform3D] = []
		var cv: Array[Color] = []
		for i in range(v, bushes.size(), 3):
			tv.append(bushes[i])
			cv.append(bush_cols[i])
		_add_multimesh("Bushes%d" % v, bush_mesh(300 + v * 7), tv, cv, null, true)
	var flower_mat := StandardMaterial3D.new()
	flower_mat.vertex_color_use_as_albedo = true
	flower_mat.roughness = 1.0
	_add_multimesh("Flowers", flower_mesh, flowers, flower_cols, flower_mat, false)


## Baumstümpfe, umgestürzte Stämme, Pilze, junge Tannen und Schilf am Bach.
func _build_forest_details() -> void:
	var bark := BuildKit.tex_mat("bark", 1.0)
	var ends := BuildKit.log_end_mat()
	var body := StaticBody3D.new()
	body.name = "DetailColliders"
	add_child(body)
	var cap_white := BuildKit.color_mat(Color(0.85, 0.8, 0.7), 0.8)
	var cap_red := BuildKit.color_mat(Color(0.7, 0.15, 0.1), 0.6)
	var stem := BuildKit.color_mat(Color(0.88, 0.85, 0.78), 0.9)

	var spots: Array[Vector3] = []
	var tries := 0
	while spots.size() < 120 and tries < 5000:
		tries += 1
		var x := _rng.randf_range(-LIMIT + 4, LIMIT - 4)
		var z := _rng.randf_range(-LIMIT + 4, LIMIT - 4)
		if not _tree_allowed(x, z) or Terrain.yard_distance(x, z) < 4.0:
			continue
		spots.append(Vector3(x, Terrain.height_at(x, z), z))

	for i in spots.size():
		var p := spots[i]
		if i < 40:
			# Baumstumpf
			var r := _rng.randf_range(0.25, 0.45)
			var h := _rng.randf_range(0.3, 0.7)
			BuildKit.cylinder(self, r, h, p + Vector3(0, h * 0.5 - 0.05, 0), bark, false, Vector3(_rng.randf_range(-4, 4), 0, 0), r * 0.92, 10)
			BuildKit.cylinder(self, r * 0.9, 0.01, p + Vector3(0, h - 0.04, 0), ends, false, Vector3.ZERO, -1.0, 10)
			_add_col_cylinder(body, r, h, p + Vector3(0, h * 0.5, 0))
		else:
			# Umgestürzter, moosiger Stamm
			var r := _rng.randf_range(0.2, 0.35)
			var len := _rng.randf_range(3.0, 7.0)
			var yaw := _rng.randf() * 180.0
			var log := BuildKit.cylinder(self, r, len, p + Vector3(0, r * 0.7, 0), bark, false, Vector3(0, yaw, 90), r * 0.8, 10)
			var moss := BuildKit.cylinder(log, r * 1.02, len * 0.6, Vector3(0, 0, 0), BuildKit.tex_mat("moss", 0.6), false, Vector3(0, 0, 0), r * 0.85, 10)
			moss.scale = Vector3(1.0, 1.0, 0.6)
			moss.position = Vector3(-r * 0.25, _rng.randf_range(-0.5, 0.5), 0)
			var cs := CollisionShape3D.new()
			var shape := CylinderShape3D.new()
			shape.radius = r
			shape.height = len
			cs.shape = shape
			cs.position = log.position
			cs.rotation_degrees = Vector3(0, yaw, 90)
			body.add_child(cs)
			# Holz hacken (braucht die Axt), wächst langsam nach
			var wood := ResourceNode.new()
			wood.name = "WoodLog_%d" % i
			wood.item_id = "wood"
			wood.per_action = 2
			wood.amount = 6
			wood.max_amount = 6
			wood.regrow_per_day = 2
			wood.tool = "axe"
			wood.action_label = "Holz hacken"
			wood.action_time = 1.8
			wood.sound = "chop"
			wood.anchor = p + Vector3(0, 0, 0)
			wood.collider_size = Vector3(1.2, r * 2.0 + 0.2, 1.2)
			add_child(wood)
		# Pilze an Stumpf/Stamm
		for k in _rng.randi_range(2, 6):
			var q := p + Vector3(_rng.randf_range(-0.7, 0.7), 0, _rng.randf_range(-0.7, 0.7))
			q.y = Terrain.height_at(q.x, q.z)
			var s := _rng.randf_range(0.6, 1.4)
			BuildKit.cylinder(self, 0.012 * s, 0.07 * s, q + Vector3(0, 0.035 * s, 0), stem, false, Vector3.ZERO, -1.0, 5)
			BuildKit.cylinder(self, 0.045 * s, 0.03 * s, q + Vector3(0, 0.075 * s, 0), cap_red if _rng.randf() < 0.3 else cap_white, false, Vector3.ZERO, 0.01, 7)

	# Junge Tannen am Waldrand
	var saplings: Array[Transform3D] = []
	var sap_cols: Array[Color] = []
	tries = 0
	while saplings.size() < 900 and tries < 14000:
		tries += 1
		var x := _rng.randf_range(-LIMIT, LIMIT)
		var z := _rng.randf_range(-LIMIT, LIMIT)
		var yd := Terrain.yard_distance(x, z)
		if yd < 1.5 or yd > 20.0 or not _tree_allowed(x, z) and yd > 2.5:
			continue
		if _blocked_for_plants(x, z) or Terrain.stream_distance(x, z) < 2.0:
			continue
		var g := Terrain.height_at(x, z)
		var h := _rng.randf_range(0.6, 2.4)
		for i in 3:
			var f := float(i) / 2.0
			var lr := h * lerpf(0.35, 0.12, f)
			var lh := h * 0.5
			saplings.append(Transform3D(Basis.from_euler(Vector3(0, _rng.randf() * TAU, 0)).scaled(Vector3(lr, lh, lr)), Vector3(x, g + h * f * 0.55, z)))
			sap_cols.append(Color(0.1, 0.2, 0.09) * _rng.randf_range(0.9, 1.3))
	_add_multimesh("Saplings", _fir_layer_mesh(8), saplings, sap_cols, _textured("needles", 0.6), true)

	# Schilf und hohe Gräser am Bachufer
	var reeds: Array[Transform3D] = []
	var reed_cols: Array[Color] = []
	tries = 0
	while reeds.size() < 1400 and tries < 10000:
		tries += 1
		var z := _rng.randf_range(-LIMIT, LIMIT)
		var side := -1.0 if _rng.randf() < 0.5 else 1.0
		var x := Terrain.stream_x_at(z) + side * _rng.randf_range(1.3, 2.8)
		var g := Terrain.height_at(x, z)
		var s := _rng.randf_range(0.7, 1.3)
		reeds.append(Transform3D(Basis.from_euler(Vector3(0, _rng.randf() * TAU, 0)).scaled(Vector3(s * 0.7, s * 1.6, s * 0.7)), Vector3(x, g - 0.05, z)))
		reed_cols.append(Color(0.95, 1.1, 0.65) * _rng.randf_range(0.8, 1.1))
	_add_multimesh("Reeds", _cross_quad_mesh(), reeds, reed_cols, BuildKit.cutout_mat("grass_blades"), false)
	_build_stream_spots()


## Steinhaufen zum Sammeln und Trinkstellen entlang des Bachs.
func _build_stream_spots() -> void:
	var stone_mat := BuildKit.tex_mat("stone", 0.5)
	var k := 0
	var z := -58.0
	while z <= 58.0:
		var side := 1.0 if k % 2 == 0 else -1.0
		var x := Terrain.stream_x_at(z) + side * 2.3
		var g := Terrain.height_at(x, z)
		var pile := ResourceNode.new()
		pile.name = "Stones_%d" % k
		pile.item_id = "stone"
		pile.per_action = 2
		pile.amount = 6
		pile.max_amount = 6
		pile.regrow_per_day = 3
		pile.action_label = "Steine sammeln"
		pile.action_time = 1.2
		pile.sound = "collect_stone"
		pile.anchor = Vector3(x, g, z)
		pile.collider_size = Vector3(1.0, 0.5, 1.0)
		add_child(pile)
		for i in 6:
			BuildKit.sphere(self, _rng.randf_range(0.1, 0.2), Vector3(x + _rng.randf_range(-0.35, 0.35), g + 0.06, z + _rng.randf_range(-0.35, 0.35)),
					stone_mat, Vector3(1.2, 0.6, 1.0), 6)
		if k % 2 == 0:
			var drink := WaterSource.new()
			drink.name = "StreamDrink_%d" % k
			drink.label = "Bach"
			drink.thirst_gain = 35.0
			drink.contaminable = true
			drink.anchor = Vector3(Terrain.stream_x_at(z), Terrain.stream_bed_height(z) + 0.2, z)
			drink.collider_size = Vector3(2.4, 0.4, 2.0)
			add_child(drink)
		k += 1
		z += 13.0


func _add_col_cylinder(body: StaticBody3D, r: float, h: float, pos: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = r
	shape.height = h
	cs.shape = shape
	cs.position = pos
	body.add_child(cs)


## Eine Astebene einer Tanne: gezackter Stern mit hängenden Zweigspitzen.
## Fußpunkt bei y = 0, Spitze bei y = 1, Radius 1.
static func _fir_layer_mesh(branches: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var apex := Vector3(0, 1, 0)
	var under := Vector3(0, 0.22, 0)
	var rim: Array[Vector3] = []
	for i in branches * 2:
		var a := TAU * float(i) / float(branches * 2)
		var tip := i % 2 == 0
		var rad := 1.0 if tip else 0.5
		var y := 0.0 if tip else 0.2
		rim.append(Vector3(cos(a) * rad, y, sin(a) * rad))
	for i in rim.size():
		var a := rim[i]
		var b := rim[(i + 1) % rim.size()]
		for v: Vector3 in [apex, a, b, under, b, a]:
			st.add_vertex(v)
	st.generate_normals()
	return st.commit()


## Laubbüschel: drei gekreuzte senkrechte und eine waagrechte Blattkarte.
static func _leaf_cluster_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var uvs := [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
	for k in 3:
		var a := PI * float(k) / 3.0
		var d := Vector3(cos(a), 0, sin(a)) * 0.5
		var pts := [-d - Vector3(0, 0.5, 0), d - Vector3(0, 0.5, 0), d + Vector3(0, 0.5, 0), -d + Vector3(0, 0.5, 0)]
		for idx: int in [0, 2, 1, 0, 3, 2]:
			st.set_normal(Vector3.UP)
			st.set_uv(uvs[idx])
			st.add_vertex(pts[idx])
	var flat := [Vector3(-0.5, 0, -0.5), Vector3(0.5, 0, -0.5), Vector3(0.5, 0, 0.5), Vector3(-0.5, 0, 0.5)]
	for idx: int in [0, 1, 2, 0, 2, 3]:
		st.set_normal(Vector3.UP)
		st.set_uv(uvs[idx])
		st.add_vertex(flat[idx])
	return st.commit()


## Detaillierter Busch (ca. 1,2 m hoch, Fuß bei y = 0): dichter dunkler Kern, Zweige
## am Boden und viele Blattbüschel, die nach außen zeigen. Oben heller, unten dunkler.
static func bush_mesh(seed_value: int) -> ArrayMesh:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	var mesh := ArrayMesh.new()
	var center := Vector3(0, 0.62, 0)
	var radii := Vector3(0.72, 0.55, 0.7)
	# Kern: unregelmäßige Kugel
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lat := 6
	var lon := 9
	var pts: Array = []
	for i in lat + 1:
		var row: Array[Vector3] = []
		var phi := PI * float(i) / lat
		for j in lon:
			var theta := TAU * float(j) / lon
			var d := Vector3(sin(phi) * cos(theta), cos(phi), sin(phi) * sin(theta))
			var k := r.randf_range(0.82, 1.08) if i > 0 and i < lat else 1.0
			row.append(center + d * radii * k)
		pts.append(row)
	for i in lat:
		for j in lon:
			var a: Vector3 = pts[i][j]
			var b: Vector3 = pts[i][(j + 1) % lon]
			var c: Vector3 = pts[i + 1][j]
			var d: Vector3 = pts[i + 1][(j + 1) % lon]
			for v: Vector3 in [a, d, c, a, b, d]:
				var n := (v - center).normalized()
				st.set_color(Color(1, 1, 1) * lerpf(0.35, 0.75, clampf(v.y / 1.1, 0.0, 1.0)))
				st.set_normal(n)
				st.set_uv(Vector2(v.x + v.z, v.y))
				st.add_vertex(v)
	# Zweige vom Boden in den Busch
	for k in 6:
		var a := r.randf() * TAU
		var top := center + Vector3(cos(a) * 0.45, r.randf_range(-0.1, 0.25), sin(a) * 0.45)
		var base := Vector3(cos(a) * 0.08, 0.0, sin(a) * 0.08)
		var dir := (top - base).normalized()
		var side := dir.cross(Vector3.UP).normalized() * 0.022
		var side2 := dir.cross(side).normalized() * 0.022
		for q: Array in [[side, side2], [side2, -side], [-side, -side2], [-side2, side]]:
			var p0: Vector3 = base + q[0]
			var p1: Vector3 = base + q[1]
			var p2: Vector3 = top + q[1] * 0.4
			var p3: Vector3 = top + q[0] * 0.4
			var n: Vector3 = ((q[0] + q[1]) as Vector3).normalized()
			for v: Vector3 in [p0, p2, p1, p0, p3, p2]:
				st.set_color(Color(0.28, 0.2, 0.14))
				st.set_normal(n)
				st.set_uv(Vector2(v.x, v.y))
				st.add_vertex(v)
	st.commit(mesh)
	var core := StandardMaterial3D.new()
	core.albedo_texture = TextureFactory.get_texture("moss")
	core.albedo_color = Color(0.75, 0.95, 0.65)
	core.vertex_color_use_as_albedo = true
	core.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	core.uv1_scale = Vector3(2.0, 2.0, 2.0)
	core.roughness = 1.0
	mesh.surface_set_material(0, core)
	# Blattbüschel
	var lt := SurfaceTool.new()
	lt.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cards := 38
	for k in cards:
		# Punkte auf der Hülle, eher oben und seitlich
		var phi := acos(clampf(r.randf_range(-0.45, 1.0), -1.0, 1.0))
		var theta := r.randf() * TAU
		var d := Vector3(sin(phi) * cos(theta), cos(phi), sin(phi) * sin(theta))
		var c := center + d * radii * r.randf_range(0.85, 1.1)
		var size := r.randf_range(0.5, 0.72)
		var normal := (d + Vector3(r.randf_range(-0.4, 0.4), r.randf_range(-0.2, 0.5), r.randf_range(-0.4, 0.4))).normalized()
		var tangent := normal.cross(Vector3.UP if absf(normal.y) < 0.95 else Vector3.RIGHT).normalized()
		tangent = tangent.rotated(normal, r.randf() * TAU)
		var bitan := normal.cross(tangent).normalized()
		var hs := size * 0.5
		var quad := [c - tangent * hs - bitan * hs, c + tangent * hs - bitan * hs, c + tangent * hs + bitan * hs, c - tangent * hs + bitan * hs]
		var uvs := [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
		var shade := lerpf(0.55, 1.1, clampf((c.y - 0.15) / 1.0, 0.0, 1.0)) * r.randf_range(0.85, 1.1)
		for idx: int in [0, 2, 1, 0, 3, 2]:
			var v: Vector3 = quad[idx]
			lt.set_color(Color(1, 1, 1) * shade)
			lt.set_normal((v - center).normalized().lerp(Vector3.UP, 0.25).normalized())
			lt.set_uv(uvs[idx])
			lt.add_vertex(v)
	lt.commit(mesh)
	mesh.surface_set_material(1, BuildKit.cutout_mat("leaves"))
	return mesh


## Keine Pflanzen auf Wegen, im Haus, im Schuppen oder im Wasser.
static func _blocked_for_plants(x: float, z: float) -> bool:
	if absf(x) < 7.2 and z > -5.2 and z < 7.8:
		return true
	if absf(x - Shed.ORIGIN.x) < 2.6 and absf(z - Shed.ORIGIN.z) < 2.3:
		return true
	if CornField.is_inside(x, z):
		return true
	if CrashSite.is_near(x, z, 7.5):
		return true
	if AlienStructure.is_near(x, z, 9.0) or RangerTower.is_near(x, z, 3.0) or StreamCave.is_near(x, z, 11.0):
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
