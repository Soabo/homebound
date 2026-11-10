class_name WildForest
extends Node3D
## Der große Wald außerhalb des Tals (das Tal selbst pflanzt `Forest`).
## Wird in Stücken von 64 x 64 m um den Spieler nachgeladen:
##  nah  = volle Bäume mit Kollision, Felsen, Gras, Farn, Büsche, liegende Stämme
##  fern = einfache Bäume ohne Kollision (bis ~420 m, dahinter zeigt das Fernsicht-Gelände Baumkronen)
## Jedes Stück wird aus seiner Position „gewürfelt“ – es sieht also immer gleich aus.

const CHUNK := 64.0
const SPACING := 4.0
const NEAR_RADIUS := 125.0
const FAR_RADIUS := 420.0
const DROP_RADIUS := 470.0
const BUDGET_MS := 3.0
## Hier pflanzt `Forest` (Tal)
const INNER := 110.0

var _chunks: Dictionary = {}       ## Vector2i -> {"lod": 1|2, "node": Node3D, "trees": Array}
var _tree_cache: Dictionary = {}   ## Vector2i -> Array[Dictionary]
var _meshes: Dictionary = {}
var _mats: Dictionary = {}


func _ready() -> void:
	name = "WildForest"
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.55
	trunk.bottom_radius = 1.0
	trunk.height = 1.0
	trunk.radial_segments = 8
	trunk.rings = 1
	var trunk_lod := CylinderMesh.new()
	trunk_lod.top_radius = 0.5
	trunk_lod.bottom_radius = 1.0
	trunk_lod.height = 1.0
	trunk_lod.radial_segments = 5
	trunk_lod.rings = 1
	var rock := SphereMesh.new()
	rock.radius = 1.0
	rock.height = 2.0
	rock.radial_segments = 7
	rock.rings = 4
	_meshes = {"trunk": trunk, "trunk_lod": trunk_lod, "cone": Forest._fir_layer_mesh(11), "cone_lod": Forest._fir_layer_mesh(5),
		"crown": Forest._leaf_cluster_mesh(), "cross": Forest._cross_quad_mesh(), "rock": rock,
		"bush0": Forest.bush_mesh(300), "bush1": Forest.bush_mesh(307)}
	var needles := _textured("needles", 0.9)
	needles.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mats = {"bark": _textured("bark", 1.5), "needles": needles, "leaves": BuildKit.cutout_mat("leaves"),
		"grass": BuildKit.cutout_mat("grass_blades"), "fern": BuildKit.cutout_mat("fern"), "stone": _textured("stone", 1.2),
		"log": BuildKit.tex_mat("bark", 1.0), "moss": BuildKit.tex_mat("moss", 0.6)}


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


func _process(_delta: float) -> void:
	var p := get_tree().get_first_node_in_group("player") as Node3D
	if p == null:
		return
	update_around(p.global_position, BUDGET_MS)


## Lädt/entlädt Stücke um einen Punkt. budget_ms <= 0: alles sofort.
func update_around(focus: Vector3, budget_ms: float) -> void:
	var start := Time.get_ticks_usec()
	var f := Vector2(focus.x, focus.z)
	# Entladen bzw. auf einfach zurückstufen
	for key: Vector2i in _chunks.keys():
		var d := _center(key).distance_to(f)
		var c: Dictionary = _chunks[key]
		if d > DROP_RADIUS:
			(c["node"] as Node3D).queue_free()
			_chunks.erase(key)
			_tree_cache.erase(key)
		elif int(c["lod"]) == 2 and d > NEAR_RADIUS + 30.0:
			(c["node"] as Node3D).queue_free()
			_chunks.erase(key)
	for key: Vector2i in _tree_cache.keys():
		if _center(key).distance_to(f) > DROP_RADIUS + 64.0:
			_tree_cache.erase(key)
	# Nachladen nach Entfernung (nah zuerst)
	var cc := Vector2i(int(floorf(focus.x / CHUNK)), int(floorf(focus.z / CHUNK)))
	var r := int(ceilf(FAR_RADIUS / CHUNK)) + 1
	var todo: Array = []
	for dz in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var key := cc + Vector2i(dx, dz)
			if _inner_only(key):
				continue
			var d := _center(key).distance_to(f)
			if d > FAR_RADIUS:
				continue
			var want := 2 if d < NEAR_RADIUS else 1
			var have := int(_chunks[key]["lod"]) if _chunks.has(key) else 0
			if have != want:
				todo.append([d, key, want])
	todo.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for t: Array in todo:
		if budget_ms > 0.0 and Time.get_ticks_usec() - start > budget_ms * 1000.0:
			return
		var key: Vector2i = t[1]
		if _chunks.has(key):
			(_chunks[key]["node"] as Node3D).queue_free()
			_chunks.erase(key)
		_build_chunk(key, int(t[2]))


func _center(key: Vector2i) -> Vector2:
	return Vector2((key.x + 0.5) * CHUNK, (key.y + 0.5) * CHUNK)


## Liegt das Stück ganz im Tal (dort pflanzt `Forest`)?
func _inner_only(key: Vector2i) -> bool:
	var x0 := key.x * CHUNK
	var z0 := key.y * CHUNK
	return x0 >= -INNER and x0 + CHUNK <= INNER and z0 >= -INNER and z0 + CHUNK <= INNER


static func _chunk_rng(key: Vector2i, salt: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector3i(key.x, key.y, salt))
	return rng


## Bäume eines Stücks (Position, Höhe, Art) – einmal gewürfelt, solange in der Nähe gemerkt.
func _trees(key: Vector2i) -> Array:
	if _tree_cache.has(key):
		return _tree_cache[key]
	var rng := _chunk_rng(key, 1)
	var out: Array = []
	var n := int(CHUNK / SPACING)
	for gz in n:
		for gx in n:
			var x := key.x * CHUNK + gx * SPACING + SPACING * 0.5 + rng.randf_range(-1.6, 1.6)
			var z := key.y * CHUNK + gz * SPACING + SPACING * 0.5 + rng.randf_range(-1.6, 1.6)
			var roll := rng.randf()
			var conifer_roll := rng.randf()
			var size_roll := rng.randf()
			if maxf(absf(x), absf(z)) <= INNER:
				continue
			if roll > 0.82:
				continue
			if Terrain.stream_distance(x, z) < 3.2 or (z > 14.0 and Terrain.road_distance(x, z) < 3.6):
				continue
			var g := Terrain.height_at(x, z)
			var dens := WorldMap.tree_density(x, z, g)
			if roll > 0.82 * dens:
				continue
			if Terrain.water_level_at(x, z) > g - 0.2:
				continue
			# höher oben fast nur Nadelbäume
			var conifer := conifer_roll > lerpf(0.2, 0.0, smoothstep(40.0, 90.0, g))
			var h := lerpf(10.0, 19.0, size_roll) if conifer else lerpf(8.0, 12.0, size_roll)
			h *= lerpf(1.0, 0.6, smoothstep(100.0, 150.0, g))
			out.append({"x": x, "z": z, "g": g, "c": conifer, "h": h, "r": lerpf(0.2, 0.38, size_roll), "yaw": rng.randf() * TAU,
				"seed": rng.randi()})
	_tree_cache[key] = out
	return out


func _build_chunk(key: Vector2i, lod: int) -> void:
	var trees := _trees(key)
	var root := Node3D.new()
	root.name = "W_%d_%d_%d" % [key.x, key.y, lod]
	add_child(root)
	_chunks[key] = {"lod": lod, "node": root}
	var trunks: Array[Transform3D] = []
	var trunk_cols: Array[Color] = []
	var cones: Array[Transform3D] = []
	var cone_cols: Array[Color] = []
	var crowns: Array[Transform3D] = []
	var crown_cols: Array[Color] = []
	var body: StaticBody3D
	if lod == 2:
		body = StaticBody3D.new()
		body.name = "Colliders"
		root.add_child(body)
	for t: Dictionary in trees:
		var rng := RandomNumberGenerator.new()
		rng.seed = int(t["seed"])
		var x: float = t["x"]
		var z: float = t["z"]
		var g: float = t["g"]
		var h: float = t["h"]
		var r: float = t["r"]
		var yaw: float = t["yaw"]
		var conifer: bool = t["c"]
		var trunk_h := h * (0.85 if conifer else 0.62)
		var bark := Color(0.9, 0.85, 0.8).lerp(Color(1.15, 1.05, 0.95), rng.randf())
		trunks.append(Transform3D(Basis.from_euler(Vector3(rng.randf_range(-0.04, 0.04), yaw, rng.randf_range(-0.04, 0.04))).scaled(Vector3(r, trunk_h, r)),
				Vector3(x, g + trunk_h * 0.5 - 0.3, z)))
		trunk_cols.append(bark)
		if conifer:
			var green := Color(0.06, 0.13, 0.07).lerp(Color(0.11, 0.18, 0.09), rng.randf())
			var crown_r := h * rng.randf_range(0.15, 0.19)
			var bottom := h * rng.randf_range(0.12, 0.22)
			var layers := 9 if lod == 2 else 3
			for i in layers:
				var fr := float(i) / float(layers - 1)
				var lr := crown_r * lerpf(1.0, 0.18, fr) * rng.randf_range(0.9, 1.1)
				var lh := h * (lerpf(0.3, 0.2, fr) if lod == 2 else lerpf(0.45, 0.35, fr))
				var cy := g + lerpf(bottom, h * 0.92, fr) + lh * 0.5
				var col := green * lerpf(0.8, 1.2, fr)
				col.a = 1.0
				var tilt := Vector3(rng.randf_range(-0.06, 0.06), yaw + i * 0.7, rng.randf_range(-0.06, 0.06))
				cones.append(Transform3D(Basis.from_euler(tilt).scaled(Vector3(lr, lh, lr)), Vector3(x, cy - lh * 0.5, z)))
				cone_cols.append(col)
		else:
			var count := 9 if lod == 2 else 3
			for i in count:
				var off := Vector3(rng.randf_range(-1.8, 1.8), rng.randf_range(-1.2, 1.6), rng.randf_range(-1.8, 1.8))
				var s := rng.randf_range(2.2, 3.4) * (1.0 if lod == 2 else 1.4)
				var rot := Basis.from_euler(Vector3(rng.randf_range(-0.4, 0.4), rng.randf() * TAU, rng.randf_range(-0.4, 0.4)))
				crowns.append(Transform3D(rot.scaled(Vector3(s, s, s)), Vector3(x, g + trunk_h - 0.4, z) + off * (1.0 if lod == 2 else 0.6)))
				var lc := Color(0.75, 0.85, 0.6) * rng.randf_range(0.75, 1.15)
				lc.a = 1.0
				crown_cols.append(lc)
		if body:
			var cs := CollisionShape3D.new()
			var shape := CylinderShape3D.new()
			shape.radius = r * 1.05
			shape.height = 4.0
			cs.shape = shape
			cs.position = Vector3(x, g + 1.8, z)
			body.add_child(cs)
	var shadows := lod == 2
	_mm(root, "Trunks", _meshes["trunk" if lod == 2 else "trunk_lod"], trunks, trunk_cols, _mats["bark"], shadows)
	_mm(root, "Needles", _meshes["cone" if lod == 2 else "cone_lod"], cones, cone_cols, _mats["needles"], shadows)
	_mm(root, "Crowns", _meshes["crown"], crowns, crown_cols, _mats["leaves"], shadows)
	if lod == 2:
		_build_ground(key, root, body)


## Nahbereich: Felsen, Gras (auf Lichtungen dicht), Farn, Büsche, liegende Stämme.
func _build_ground(key: Vector2i, root: Node3D, body: StaticBody3D) -> void:
	var rng := _chunk_rng(key, 2)
	var x0 := key.x * CHUNK
	var z0 := key.y * CHUNK
	var grass: Array[Transform3D] = []
	var grass_cols: Array[Color] = []
	var ferns: Array[Transform3D] = []
	var fern_cols: Array[Color] = []
	var bushes: Array[Transform3D] = []
	var bush_cols: Array[Color] = []
	var rocks: Array[Transform3D] = []
	var rock_cols: Array[Color] = []
	var tries := 0
	while tries < 900:
		tries += 1
		var x := x0 + rng.randf() * CHUNK
		var z := z0 + rng.randf() * CHUNK
		var roll := rng.randf()
		var s := rng.randf_range(0.35, 1.2)
		var yaw := rng.randf() * TAU
		if maxf(absf(x), absf(z)) <= INNER:
			continue
		var ti := WorldMap.trail_info(x, z)
		if ti.x < 0.3 or Terrain.road_distance(x, z) < 3.0 and z > 14.0:
			continue
		var g := Terrain.height_at(x, z)
		if Terrain.water_level_at(x, z) > g - 0.05:
			continue
		var meadow := WorldMap.meadow(x, z)
		var high := smoothstep(120.0, 160.0, g)
		if roll < 0.55 + meadow * 0.35:
			# Gras: auf Lichtungen und am Wegrand dicht, im Wald dünn
			if rng.randf() > 0.25 + meadow * 0.75 or high > 0.8:
				continue
			grass.append(Transform3D(Basis.from_euler(Vector3(0, yaw, 0)).scaled(Vector3(s * 0.6, s * 0.65, s * 0.6)), Vector3(x, g - 0.02, z)))
			grass_cols.append(Color(0.75, 0.9, 0.6).lerp(Color(1.1, 1.05, 0.7), rng.randf()))
		elif roll < 0.85:
			if meadow > 0.6 or high > 0.5:
				continue
			ferns.append(Transform3D(Basis.from_euler(Vector3(0, yaw, 0)).scaled(Vector3(s, s, s)), Vector3(x, g - 0.03, z)))
			fern_cols.append(Color(0.8, 0.95, 0.7) * rng.randf_range(0.75, 1.1))
		elif roll < 0.95:
			if high > 0.6:
				continue
			bushes.append(Transform3D(Basis.from_euler(Vector3(0, yaw, 0)).scaled(Vector3(s * 1.25, s * 0.9, s * 1.2)), Vector3(x, g - 0.05, z)))
			bush_cols.append(Color(0.48, 0.62, 0.4).lerp(Color(0.72, 0.82, 0.52), rng.randf()))
		else:
			var rs := s * (1.0 + high * 1.5)
			var sc := Vector3(rs * rng.randf_range(1.0, 1.7), rs * rng.randf_range(0.5, 0.85), rs * rng.randf_range(1.0, 1.5))
			rocks.append(Transform3D(Basis.from_euler(Vector3(rng.randf() * 0.4, yaw, rng.randf() * 0.4)).scaled(sc), Vector3(x, g + sc.y * 0.25, z)))
			rock_cols.append(Color(0.75, 0.75, 0.72) * rng.randf_range(0.8, 1.1) if rng.randf() < 0.5 else Color(0.45, 0.6, 0.32) * rng.randf_range(0.8, 1.1))
			if rs > 0.7:
				var cs := CollisionShape3D.new()
				var shape := SphereShape3D.new()
				shape.radius = maxf(sc.x, sc.z) * 0.75
				cs.shape = shape
				cs.position = Vector3(x, g, z)
				body.add_child(cs)
	# Ein, zwei liegende Stämme
	for k in rng.randi_range(0, 2):
		var x := x0 + rng.randf_range(6.0, CHUNK - 6.0)
		var z := z0 + rng.randf_range(6.0, CHUNK - 6.0)
		var g := Terrain.height_at(x, z)
		if maxf(absf(x), absf(z)) <= INNER or WorldMap.tree_density(x, z, g) < 0.5 or WorldMap.trail_info(x, z).x < 3.0:
			continue
		var r := rng.randf_range(0.2, 0.35)
		var len := rng.randf_range(3.0, 7.0)
		var yaw := rng.randf() * 180.0
		var lg := BuildKit.cylinder(root, r, len, Vector3(x, g + r * 0.7, z), _mats["log"], false, Vector3(0, yaw, 90), r * 0.8, 8)
		var moss := BuildKit.cylinder(lg, r * 1.02, len * 0.6, Vector3(-r * 0.25, 0, 0), _mats["moss"], false, Vector3.ZERO, r * 0.85, 8)
		moss.scale = Vector3(1.0, 1.0, 0.6)
		var cs := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = r
		shape.height = len
		cs.shape = shape
		cs.position = Vector3(x, g + r * 0.7, z)
		cs.rotation_degrees = Vector3(0, yaw, 90)
		body.add_child(cs)
	_mm(root, "Grass", _meshes["cross"], grass, grass_cols, _mats["grass"], false)
	_mm(root, "Ferns", _meshes["cross"], ferns, fern_cols, _mats["fern"], false)
	var b0: Array[Transform3D] = []
	var c0: Array[Color] = []
	var b1: Array[Transform3D] = []
	var c1: Array[Color] = []
	for i in bushes.size():
		if i % 2 == 0:
			b0.append(bushes[i])
			c0.append(bush_cols[i])
		else:
			b1.append(bushes[i])
			c1.append(bush_cols[i])
	_mm(root, "Bushes0", _meshes["bush0"], b0, c0, null, true)
	_mm(root, "Bushes1", _meshes["bush1"], b1, c1, null, true)
	_mm(root, "Rocks", _meshes["rock"], rocks, rock_cols, _mats["stone"], true)


func _mm(root: Node3D, n: String, mesh: Mesh, transforms: Array[Transform3D], colors: Array[Color], mat: Material, shadows: bool) -> void:
	if transforms.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
		mm.set_instance_color(i, colors[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = n
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mmi)
