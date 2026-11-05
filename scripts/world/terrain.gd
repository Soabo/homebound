class_name Terrain
extends Node3D
## Gelände: flaches Grundstück in der Mitte, Hügel und Böschungen im Wald,
## alte Zufahrtsstraße nach Süden. Die Höhenfunktion ist statisch, damit
## Wald, Garten und Spieler-Spawn dieselbe Höhe abfragen können.

const HALF_SIZE := 112.0
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


## Höhe des Bachbetts – das Wasser folgt dieser Linie. Der Bach fließt nach Süden (+z)
## und darf nirgends ansteigen: Das Bett ist eine stetig fallende Linie, die dem Gelände
## so gut wie möglich folgt (Hügel werden durchschnitten, Senken leicht aufgefüllt).
const BED_STEP := 1.0
const BED_START := -HALF_SIZE - 6.0
static var _bed: PackedFloat32Array


static func stream_bed_height(z: float) -> float:
	if _bed.is_empty():
		_build_bed_profile()
	var f := clampf((z - BED_START) / BED_STEP, 0.0, float(_bed.size() - 1))
	var i := int(floorf(f))
	var j := mini(i + 1, _bed.size() - 1)
	return lerpf(_bed[i], _bed[j], f - float(i))


static func _build_bed_profile() -> void:
	var n := int((HALF_SIZE * 2.0 + 12.0) / BED_STEP) + 1
	var raw := PackedFloat32Array()
	raw.resize(n)
	for i in n:
		var z := BED_START + i * BED_STEP
		raw[i] = _raw_height(stream_x_at(z), z) - 1.1
	# Ausgleich zu einer nie steigenden Linie (Blöcke zusammenfassen, bis alles fällt)
	var values: Array[float] = []
	var counts: Array[int] = []
	for i in n:
		values.append(raw[i])
		counts.append(1)
		while values.size() > 1 and values[-1] > values[-2]:
			var c := counts[-1] + counts[-2]
			var v := (values[-1] * counts[-1] + values[-2] * counts[-2]) / c
			values.pop_back()
			counts.pop_back()
			values[-1] = v
			counts[-1] = c
	var bed := PackedFloat32Array()
	for k in values.size():
		for c in counts[k]:
			bed.append(values[k])
	# Mindestgefälle, damit es überall sichtbar fließt
	for i in range(1, n):
		bed[i] = minf(bed[i], bed[i - 1] - 0.012)
	# weich glätten (bleibt dabei fallend)
	var smooth := PackedFloat32Array()
	smooth.resize(n)
	for i in n:
		var sum := 0.0
		var cnt := 0
		for k in range(-4, 5):
			var q := clampi(i + k, 0, n - 1)
			sum += bed[q]
			cnt += 1
		smooth[i] = sum / cnt
	_bed = smooth


static func height_at(x: float, z: float) -> float:
	var h := _raw_height(x, z)
	var sd := stream_distance(x, z)
	if sd < 9.0:
		var bed := stream_bed_height(z)
		# Je tiefer sich der Bach einschneiden muss, desto flacher die Böschung
		var reach := 4.0 + clampf(absf(h - bed) * 0.6, 0.0, 5.0)
		var cut := 1.0 - smoothstep(1.3, reach, sd)
		h = lerpf(h, bed, cut)
	return h


## Rohhöhe inkl. Höhle: im Bereich der Höhle liegt das Gelände nie über ihrem Boden.
static func _raw_height(x: float, z: float) -> float:
	var h := _raw_height_core(x, z)
	var lx := x - StreamCave.SITE.x
	var lz := z - StreamCave.SITE.z
	if lx > -1.5 and lx < 19.0 and absf(lz) < 5.5:
		var floor_h := StreamCave.floor_height()
		var w := smoothstep(-1.5, 0.5, lx) * (1.0 - smoothstep(4.0, 5.5, absf(lz)))
		h = lerpf(h, minf(h, floor_h - 0.05), clampf(w, 0.0, 1.0))
	return h


static func _raw_height_core(x: float, z: float) -> float:
	_ensure_noise()
	var d := maxf(yard_distance(x, z), 0.0)
	var hills := (_noise.get_noise_2d(x, z) * 0.5 + 0.5) * 7.0 + _detail.get_noise_2d(x, z) * 0.35
	var h := hills * smoothstep(1.0, 18.0, d)
	# Talrand: zum Kartenrand hin steigt das Gelände an.
	var edge := maxf(absf(x), absf(z))
	# Im Süden verlässt der Bach das Tal: dort steigt der Rand nicht an.
	var valley := lerpf(1.0, smoothstep(4.0, 18.0, stream_distance(x, z)), smoothstep(50.0, 85.0, z))
	h += smoothstep(86.0, 108.0, edge) * 9.0 * valley
	# Einschlagkrater der Absturzstelle: Mulde mit aufgeworfenem Rand
	var cdist := Vector2(x - CrashSite.SITE.x, z - CrashSite.SITE.z).length()
	if cdist < 12.0:
		h += -1.0 * (1.0 - smoothstep(0.0, 5.0, cdist)) + 0.45 * exp(-pow(cdist - 5.8, 2.0) / 1.6)
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
			# Absturzstelle: verbrannte Erde
			var cd := Vector2(x - CrashSite.SITE.x, z - CrashSite.SITE.z).length()
			col = col.lerp(Color(0.03, 0.028, 0.025), 1.0 - smoothstep(4.0, 10.0, cd))
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
		# Terraforming Stufe 3+: das Wasser verfärbt sich rostig-violett
		var dirty := WorldState.water_contaminated()
		var target := Color(0.62, 0.42, 0.55, 0.9) if dirty else Color(0.65, 0.78, 0.72, 0.85)
		_water_mat.albedo_color = _water_mat.albedo_color.lerp(target, clampf(delta * 0.5, 0.0, 1.0))
