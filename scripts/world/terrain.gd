class_name Terrain
extends Node3D
## Gelände: flaches Grundstück in der Mitte, Hügel und Böschungen im Wald,
## alte Zufahrtsstraße nach Süden. Die Höhenfunktion ist statisch, damit
## Wald, Garten und Spieler-Spawn dieselbe Höhe abfragen können.

const HALF_SIZE := 80.0
const CELL := 1.0

## Grundstück (wie der Zaun im Garten): x -20..22, z -16..18
const YARD_CENTER := Vector2(1.0, 1.0)
const YARD_HALF := Vector2(21.0, 17.0)

static var _noise: FastNoiseLite
static var _detail: FastNoiseLite


static func _ensure_noise() -> void:
	if _noise != null:
		return
	_noise = FastNoiseLite.new()
	_noise.seed = 7
	_noise.frequency = 0.022
	_noise.fractal_octaves = 3
	_detail = FastNoiseLite.new()
	_detail.seed = 11
	_detail.frequency = 0.15


## Abstand eines Punktes zum Grundstücksrechteck (0 = innerhalb).
static func yard_distance(x: float, z: float) -> float:
	var q := Vector2(absf(x - YARD_CENTER.x), absf(z - YARD_CENTER.y)) - YARD_HALF
	return Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0)


## Verlauf der alten Zufahrtsstraße (x-Position abhängig von z).
static func road_x_at(z: float) -> float:
	if z <= 18.0:
		return -3.0
	return -3.0 + 7.0 * sin((z - 18.0) / 22.0)


static func road_distance(x: float, z: float) -> float:
	if z < 7.5:
		return Vector2(x + 3.0, z - 7.5).length()
	return absf(x - road_x_at(z))


## Verlauf des Bachs östlich des Grundstücks (GDD 3.2).
static func stream_x_at(z: float) -> float:
	return 34.0 + 5.0 * sin(z / 14.0) + 2.0 * sin(z / 5.3)


static func stream_distance(x: float, z: float) -> float:
	return absf(x - stream_x_at(z))


## Höhe des Bachbetts (ohne Einschnitt) – das Wasser folgt dieser Linie.
static func stream_bed_height(z: float) -> float:
	return _raw_height(stream_x_at(z), z) - 1.1


static func height_at(x: float, z: float) -> float:
	var h := _raw_height(x, z)
	var sd := stream_distance(x, z)
	if sd < 5.0:
		var cut := 1.0 - smoothstep(1.3, 4.0, sd)
		h = lerpf(h, stream_bed_height(z), cut)
	return h


static func _raw_height(x: float, z: float) -> float:
	_ensure_noise()
	var d := maxf(yard_distance(x, z), 0.0)
	var hills := (_noise.get_noise_2d(x, z) * 0.5 + 0.5) * 7.0 + _detail.get_noise_2d(x, z) * 0.35
	var h := hills * smoothstep(1.0, 18.0, d)
	# Talrand: zum Kartenrand hin steigt das Gelände an.
	var edge := maxf(absf(x), absf(z))
	h += smoothstep(52.0, 76.0, edge) * 9.0
	# Die Straße schneidet sich flacher durchs Gelände.
	if z > 16.0:
		var road := 1.0 - smoothstep(2.2, 6.0, road_distance(x, z))
		h = lerpf(h, h * 0.2, road)
	return h


func _ready() -> void:
	name = "Terrain"
	_build()


func _build() -> void:
	_ensure_noise()
	var steps := int(HALF_SIZE * 2.0 / CELL)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var grass_a := Color(0.16, 0.24, 0.08)
	var grass_b := Color(0.25, 0.3, 0.1)
	var forest_floor := Color(0.11, 0.12, 0.06)
	var road_col := Color(0.3, 0.24, 0.16)

	for iz in steps + 1:
		for ix in steps + 1:
			var x := -HALF_SIZE + ix * CELL
			var z := -HALF_SIZE + iz * CELL
			var h := height_at(x, z)
			var d := maxf(yard_distance(x, z), 0.0)
			var n := _detail.get_noise_2d(x * 1.7, z * 1.7) * 0.5 + 0.5
			var col := grass_a.lerp(grass_b, n)
			col = col.lerp(forest_floor, smoothstep(1.0, 9.0, d) * 0.85)
			var road := 1.0 - smoothstep(1.6, 3.2, road_distance(x, z))
			if z > 6.5:
				col = col.lerp(road_col, road)
			# Bachufer: moosig, im Bett Kies und Schlamm
			var sd := stream_distance(x, z)
			col = col.lerp(Color(0.14, 0.2, 0.08), 1.0 - smoothstep(2.5, 5.0, sd))
			col = col.lerp(Color(0.22, 0.2, 0.16), 1.0 - smoothstep(1.0, 2.0, sd))
			st.set_color(col)
			st.set_uv(Vector2(x, z) * 0.25)
			st.add_vertex(Vector3(x, h, z))

	var row := steps + 1
	for iz in steps:
		for ix in steps:
			var i := iz * row + ix
			st.add_index(i)
			st.add_index(i + 1)
			st.add_index(i + row)
			st.add_index(i + 1)
			st.add_index(i + row + 1)
			st.add_index(i + row)
	st.generate_normals()
	var mesh := st.commit()

	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	mat.albedo_texture = TextureFactory.get_texture("grass_ground")
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	mat.uv1_scale = Vector3(1.0, 1.0, 1.0)
	mesh.surface_set_material(0, mat)
	_build_stream()

	var mi := MeshInstance3D.new()
	mi.name = "Ground"
	mi.mesh = mesh
	add_child(mi)

	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	cs.shape = mesh.create_trimesh_shape()
	body.add_child(cs)
	add_child(body)


## Wasserband entlang des Bachs, folgt dem Bachbett.
func _build_stream() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half_w := 1.6
	var z := -HALF_SIZE
	var prev_l := Vector3.ZERO
	var prev_r := Vector3.ZERO
	var first := true
	while z <= HALF_SIZE:
		var cx := stream_x_at(z)
		var y := stream_bed_height(z) + 0.35
		var l := Vector3(cx - half_w, y, z)
		var r := Vector3(cx + half_w, y, z)
		if not first:
			for v: Vector3 in [prev_l, prev_r, r, prev_l, r, l]:
				st.set_uv(Vector2(v.x, v.z) * 0.5)
				st.add_vertex(v)
		prev_l = l
		prev_r = r
		first = false
		z += 1.0
	st.generate_normals()
	var mesh := st.commit()
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = TextureFactory.get_texture("water")
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	mat.albedo_color = Color(0.65, 0.78, 0.72, 0.85)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.3
	mat.metallic_specular = 0.35
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_set_material(0, mat)
	var mi := MeshInstance3D.new()
	mi.name = "Stream"
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	_water_mat = mat


var _water_mat: StandardMaterial3D
var _flow: float = 0.0


func _process(delta: float) -> void:
	# Wasser fließt langsam nach Süden
	if _water_mat:
		_flow += delta * 0.25
		_water_mat.uv1_offset = Vector3(0, -_flow, 0)
