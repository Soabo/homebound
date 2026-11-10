class_name Terrain
extends Node3D
## Gelände der großen Welt (ca. 2,2 x 2,2 km, siehe WorldMap / data/world/map.json).
## Mitte: flaches Grundstück, Hügel und Böschungen im Wald, alte Zufahrtsstraße nach Süden, Bach im Osten.
## Draußen: weite Hügel, Berge, Seen, Moor. Die Höhenfunktion ist statisch, damit
## Wald, Garten, Orte und Spieler dieselbe Höhe abfragen können.
##
## Darstellung: Das Tal (±128 m) wird beim Start fest gebaut. Um den Spieler herum werden Stücke von
## 64 x 64 m nachgeladen (fein, mit Kollision); weiter weg zeigt ein grobes Fernsicht-Gelände die Berge.

const HALF_SIZE := 1150.0
const CELL := 1.0
## Nachlade-Stücke
const CHUNK := 64.0
const CHUNK_RES := 64
## Festes Tal: Stücke -2..1 in beiden Richtungen (= ±128 m)
const CORE_CHUNKS := 2
const LOAD_RADIUS := 215.0
const UNLOAD_RADIUS := 290.0
## Fernsicht-Gelände
const FAR_CELL := 16.0
const FAR_DROP := 150.0
## Zeitbudget fürs Nachladen pro Bild (ms)
const BUDGET_MS := 3.5
## In den ersten Sekunden nach dem Start mehr (der Spieler steht noch im Tal)
const BUDGET_START_MS := 14.0
const START_SECONDS := 25.0

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


## Verlauf der alten Zufahrtsstraße (x-Position abhängig von z). Sie führt bis zur Autobahn im Süden.
static func road_x_at(z: float) -> float:
	if z <= 18.0:
		return -3.0
	return -3.0 + 7.0 * sin((z - 18.0) / 22.0)


static func road_distance(x: float, z: float) -> float:
	if z < 7.5:
		return Vector2(x + 3.0, z - 7.5).length()
	if z > 1086.0:
		return Vector2(x - road_x_at(1086.0), z - 1086.0).length()
	return absf(x - road_x_at(z))


## Verlauf des Bachs östlich des Grundstücks (GDD 3.2). Im Tal wie bisher, draußen in weiten Bögen:
## Er entspringt im Quellsee im Norden und verlässt die Karte im Süden.
const STREAM_BENDS := [[-1150.0, 60.0], [-1050.0, 60.0], [-900.0, 70.0], [-700.0, 110.0], [-500.0, 130.0], [-300.0, 80.0],
	[-110.0, 34.0], [110.0, 34.0], [300.0, 90.0], [550.0, 140.0], [800.0, 230.0], [885.0, 250.0], [1150.0, 250.0]]
## Hier beginnt der Bach (Südufer des Quellsees)
const STREAM_START := -1006.0


static func _stream_offset(z: float) -> float:
	if absf(z) <= 110.0:
		return 0.0
	for i in STREAM_BENDS.size() - 1:
		var a: Array = STREAM_BENDS[i]
		var b: Array = STREAM_BENDS[i + 1]
		if z >= float(a[0]) and z <= float(b[0]):
			var t := (z - float(a[0])) / (float(b[0]) - float(a[0]))
			t = t * t * (3.0 - 2.0 * t)
			return lerpf(float(a[1]), float(b[1]), t) - 34.0
	return float(STREAM_BENDS[-1][1]) - 34.0


static func stream_x_at(z: float) -> float:
	return 34.0 + 5.0 * sin(z / 14.0) + 2.0 * sin(z / 5.3) + _stream_offset(z)


static func stream_distance(x: float, z: float) -> float:
	if z < STREAM_START - 4.0:
		return INF
	return absf(x - stream_x_at(z))


## Höhe des Bachbetts – das Wasser folgt dieser Linie. Der Bach fließt nach Süden (+z)
## und darf nirgends ansteigen: Das Bett ist eine stetig fallende Linie, die dem Gelände
## so gut wie möglich folgt (Hügel werden durchschnitten, Senken leicht aufgefüllt).
const BED_STEP := 1.0
## Wasserspiegel über dem Bachbett, halbe Wasserbreite, Uferhöhe über dem Bett
const WATER_LEVEL := 0.22
const WATER_HALF_WIDTH := 1.35
const BANK_HEIGHT := 0.7
const BED_START := STREAM_START
static var _bed: PackedFloat32Array


static func stream_bed_height(z: float) -> float:
	if _bed.is_empty():
		_build_bed_profile()
	var f := clampf((z - BED_START) / BED_STEP, 0.0, float(_bed.size() - 1))
	var i := int(floorf(f))
	var j := mini(i + 1, _bed.size() - 1)
	return lerpf(_bed[i], _bed[j], f - float(i))


static func _build_bed_profile() -> void:
	var n := int((HALF_SIZE + 10.0 - BED_START) / BED_STEP) + 1
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
		var cut := (1.0 - smoothstep(1.3, reach, sd)) * smoothstep(STREAM_START - 4.0, STREAM_START + 4.0, z)
		h = lerpf(h, bed, cut)
		# Klarer Uferrand: Das Ufer liegt immer über dem Wasserspiegel. Wo das Gelände dafür zu tief ist,
		# entsteht ein flacher Grasdamm, der nach außen wieder ins Gelände ausläuft.
		var bank := bed + BANK_HEIGHT * smoothstep(0.6, 2.4, sd)
		if h < bank:
			h = lerpf(h, bank, (1.0 - smoothstep(2.4, 4.8, sd)) * smoothstep(STREAM_START - 4.0, STREAM_START + 4.0, z))
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
	return WorldMap.shape_height(x, z, _raw_height_unshaped(x, z))


## Tal + große Landschaft, ohne Seen/Mulden/Orte.
static func _raw_height_unshaped(x: float, z: float) -> float:
	return _local_height(x, z) + WorldMap.macro_height(x, z)


## Das ursprüngliche Tal: Hügel im Wald, Krater, eingeschnittene Straße.
static func _local_height(x: float, z: float) -> float:
	_ensure_noise()
	var d := maxf(yard_distance(x, z), 0.0)
	var hills := (_noise.get_noise_2d(x, z) * 0.5 + 0.5) * 7.0 + _detail.get_noise_2d(x, z) * 0.35
	var h := hills * smoothstep(1.0, 18.0, d)
	# Einschlagkrater der Absturzstelle: Mulde mit aufgeworfenem Rand
	var cdist := Vector2(x - CrashSite.SITE.x, z - CrashSite.SITE.z).length()
	if cdist < 12.0:
		h += -1.0 * (1.0 - smoothstep(0.0, 5.0, cdist)) + 0.45 * exp(-pow(cdist - 5.8, 2.0) / 1.6)
	# Die Straße schneidet sich flacher durchs Gelände.
	if z > 16.0:
		var road := 1.0 - smoothstep(2.2, 6.0, road_distance(x, z))
		h = lerpf(h, h * 0.2, road)
	# Waldwege: kleine Unebenheiten glätten
	var ti := WorldMap.trail_info(x, z)
	if ti.x < 3.0:
		h -= _detail.get_noise_2d(x, z) * 0.35 * (1.0 - smoothstep(0.0, 3.0, ti.x))
	return h


## Wasserspiegel an dieser Stelle (Bach, See, Tümpel) oder -INF.
static func water_level_at(x: float, z: float) -> float:
	var l := WorldMap.water_level(x, z)
	if stream_distance(x, z) < WATER_HALF_WIDTH:
		l = maxf(l, stream_bed_height(z) + WATER_LEVEL)
	return l


## Farbe des Bodens (Albedo-Tönung). a = Walddichte (fürs Fernsicht-Gelände).
static func ground_color(x: float, z: float, h: float, ny: float, with_density: bool = false) -> Color:
	_ensure_noise()
	var grass_a := Color(0.16, 0.24, 0.08)
	var grass_b := Color(0.25, 0.3, 0.1)
	var forest_floor := Color(0.11, 0.12, 0.06)
	var d := maxf(yard_distance(x, z), 0.0)
	var n := _detail.get_noise_2d(x * 1.7, z * 1.7) * 0.5 + 0.5
	var col := grass_a.lerp(grass_b, n)
	var forest := smoothstep(1.0, 9.0, d) * 0.85
	var far := Vector2(x, z).length() > WorldMap.VALLEY_INNER - 15.0
	var meadow := WorldMap.meadow(x, z) if far else 0.0
	col = col.lerp(forest_floor, forest * (1.0 - meadow))
	var road := 1.0 - smoothstep(1.6, 3.2, road_distance(x, z))
	if z > 6.5:
		col = col.lerp(Color(0.3, 0.24, 0.16), road)
	if far:
		# Waldwege, Schotterwege, Autobahn
		var ti := WorldMap.trail_info(x, z)
		if ti.x < 1.2:
			var path_col := [Color(0.27, 0.21, 0.14), Color(0.36, 0.33, 0.27), Color(0.2, 0.2, 0.21)][clampi(int(ti.y), 0, 2)] as Color
			col = col.lerp(path_col, 1.0 - smoothstep(-0.4, 1.2, ti.x))
		# Bergwiese oberhalb des Waldes, Fels nur an steilen Stellen und ganz oben
		col = col.lerp(Color(0.2, 0.22, 0.09).lerp(Color(0.26, 0.25, 0.12), n), smoothstep(115.0, 160.0, h) * 0.8)
		var rock := maxf(1.0 - smoothstep(0.55, 0.72, ny), smoothstep(190.0, 240.0, h) * 0.85)
		col = col.lerp(Color(0.36, 0.35, 0.33).lerp(Color(0.46, 0.45, 0.42), n), rock)
		# Mulden: Steinbruch = Fels, abgelassener Stausee = trockener, rissiger Schlamm
		var bi := WorldMap.basin_info(x, z)
		if bi.x > 0.0:
			var basin_col := Color(0.28, 0.27, 0.25).lerp(Color(0.36, 0.35, 0.32), n) if bi.y < 0.5 else Color(0.13, 0.105, 0.075).lerp(Color(0.19, 0.155, 0.11), n)
			col = col.lerp(basin_col, bi.x)
		# Moor: dunkel, nass
		var bog := WorldMap.bog_factor(x, z)
		col = col.lerp(Color(0.13, 0.12, 0.07), bog * 0.8)
	# Bachufer: moosig, im Bett Kies und Schlamm
	var sd := stream_distance(x, z)
	if sd < 6.0:
		col = col.lerp(Color(0.14, 0.2, 0.08), 1.0 - smoothstep(2.5, 5.0, sd))
		col = col.lerp(Color(0.22, 0.2, 0.16), 1.0 - smoothstep(1.0, 2.0, sd))
	# Seeufer und Seegrund: Schlamm
	var wl := WorldMap.water_level(x, z) if far else -INF
	if wl > -INF and h < wl + 0.4:
		col = col.lerp(Color(0.15, 0.13, 0.1), 0.8)
	# Absturzstelle: verbrannte Erde
	var cd := Vector2(x - CrashSite.SITE.x, z - CrashSite.SITE.z).length()
	if cd < 10.0:
		col = col.lerp(Color(0.03, 0.028, 0.025), 1.0 - smoothstep(4.0, 10.0, cd))
	col.a = (WorldMap.tree_density(x, z, h) if far else smoothstep(4.0, 12.0, d)) if with_density else 1.0
	return col


# --- Darstellung -------------------------------------------------------------

var _chunks: Dictionary = {}          ## Vector2i -> Node3D
var _job: Dictionary = {}             ## laufendes Nachladen
var _ground_mat: StandardMaterial3D
var _far_mat: ShaderMaterial
var _water_mat: StandardMaterial3D
var _flow: float = 0.0
static var _indices: PackedInt32Array
var _born: int = 0


func _ready() -> void:
	name = "Terrain"
	_born = Time.get_ticks_msec()
	WorldMap.ensure()
	_ensure_noise()
	_ground_mat = StandardMaterial3D.new()
	_ground_mat.vertex_color_use_as_albedo = true
	_ground_mat.roughness = 1.0
	_ground_mat.albedo_texture = TextureFactory.get_texture("grass_ground")
	_ground_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	_build_water_material()
	# Das Tal sofort (Spieler, Garten und Hütte stehen darauf)
	for cz in range(-CORE_CHUNKS, CORE_CHUNKS):
		for cx in range(-CORE_CHUNKS, CORE_CHUNKS):
			_build_chunk_now(Vector2i(cx, cz))
	var t_core := Time.get_ticks_msec() - _born
	_build_far()
	_build_stream()
	_build_lakes()
	print("[Terrain] Tal %d ms, gesamt %d ms" % [t_core, Time.get_ticks_msec() - _born])


static func is_core(key: Vector2i) -> bool:
	return key.x >= -CORE_CHUNKS and key.x < CORE_CHUNKS and key.y >= -CORE_CHUNKS and key.y < CORE_CHUNKS


## Ist das Gelände an dieser Stelle schon begehbar (Stück geladen)?
func is_loaded(x: float, z: float) -> bool:
	return _chunks.has(Vector2i(int(floorf(x / CHUNK)), int(floorf(z / CHUNK))))


## Lädt sofort alle Stücke um einen Punkt (z. B. nach dem Teleport im Test oder beim Laden eines Spielstands).
func load_around(p: Vector3, radius: float = 100.0) -> void:
	var c := Vector2i(int(floorf(p.x / CHUNK)), int(floorf(p.z / CHUNK)))
	var r := int(ceilf(radius / CHUNK))
	for dz in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var key := c + Vector2i(dx, dz)
			if not _chunks.has(key) and _in_world(key):
				_build_chunk_now(key)


func _in_world(key: Vector2i) -> bool:
	var m := int(ceilf(HALF_SIZE / CHUNK))
	return key.x >= -m and key.x < m and key.y >= -m and key.y < m


func _process(delta: float) -> void:
	# Wasser fließt langsam nach Süden
	if _water_mat:
		_flow += delta * 0.25
		_water_mat.uv1_offset = Vector3(0, -_flow, 0)
		# Terraforming Stufe 3+: das Wasser verfärbt sich rostig-violett
		var dirty := WorldState.water_contaminated()
		var target := Color(0.62, 0.42, 0.55, 0.9) if dirty else Color(0.65, 0.78, 0.72, 0.85)
		_water_mat.albedo_color = _water_mat.albedo_color.lerp(target, clampf(delta * 0.5, 0.0, 1.0))
	var focus := _focus()
	if _far_mat:
		_far_mat.set_shader_parameter("player_pos", focus)
	_stream_chunks(focus)


func _focus() -> Vector3:
	var p := get_tree().get_first_node_in_group("player") as Node3D
	if p:
		return p.global_position
	var cam := get_viewport().get_camera_3d()
	return cam.global_position if cam else Vector3.ZERO


func _stream_chunks(focus: Vector3) -> void:
	var start := Time.get_ticks_usec()
	var budget := (BUDGET_START_MS if Time.get_ticks_msec() - _born < START_SECONDS * 1000.0 else BUDGET_MS) * 1000.0
	# Wenn der Spieler auf einem nicht geladenen Stück steht: sofort bauen
	var here := Vector2i(int(floorf(focus.x / CHUNK)), int(floorf(focus.z / CHUNK)))
	if not _chunks.has(here) and _in_world(here):
		if _job.get("key", Vector2i(999999, 0)) == here:
			_job.clear()
		_build_chunk_now(here)
	# Entladen
	for key: Vector2i in _chunks.keys():
		if is_core(key):
			continue
		var c := Vector2((key.x + 0.5) * CHUNK, (key.y + 0.5) * CHUNK)
		if c.distance_to(Vector2(focus.x, focus.z)) > UNLOAD_RADIUS:
			(_chunks[key] as Node3D).queue_free()
			_chunks.erase(key)
	# Nachladen: nächstgelegenes fehlendes Stück
	while Time.get_ticks_usec() - start < budget:
		if _job.is_empty():
			var key := _next_missing(focus)
			if key == Vector2i(999999, 0):
				return
			_job = {"key": key, "row": 0, "h": PackedFloat32Array(), "c": PackedColorArray()}
			var hs: PackedFloat32Array = _job["h"]
			hs.resize((CHUNK_RES + 3) * (CHUNK_RES + 3))
			_job["h"] = hs
		_work_job(start, budget)


func _next_missing(focus: Vector3) -> Vector2i:
	var best := Vector2i(999999, 0)
	var best_d := LOAD_RADIUS
	var c := Vector2i(int(floorf(focus.x / CHUNK)), int(floorf(focus.z / CHUNK)))
	var r := int(ceilf(LOAD_RADIUS / CHUNK)) + 1
	for dz in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var key := c + Vector2i(dx, dz)
			if _chunks.has(key) or not _in_world(key):
				continue
			var d := Vector2((key.x + 0.5) * CHUNK, (key.y + 0.5) * CHUNK).distance_to(Vector2(focus.x, focus.z))
			if d < best_d:
				best_d = d
				best = key
	return best


## Höhen zeilenweise berechnen (Zeitbudget), danach Netz und Kollision bauen.
func _work_job(start: int, budget: float) -> void:
	var key: Vector2i = _job["key"]
	var n := CHUNK_RES + 3
	var x0 := key.x * CHUNK - CELL
	var z0 := key.y * CHUNK - CELL
	var hs: PackedFloat32Array = _job["h"]
	while int(_job["row"]) < n:
		var row := int(_job["row"])
		for ix in n:
			hs[row * n + ix] = height_at(x0 + ix * CELL, z0 + row * CELL)
		_job["row"] = row + 1
		if Time.get_ticks_usec() - start > budget:
			_job["h"] = hs
			return
	_job["h"] = hs
	_finish_chunk(key, hs)
	_job.clear()


func _build_chunk_now(key: Vector2i) -> void:
	var n := CHUNK_RES + 3
	var hs := PackedFloat32Array()
	hs.resize(n * n)
	var x0 := key.x * CHUNK - CELL
	var z0 := key.y * CHUNK - CELL
	for iz in n:
		for ix in n:
			hs[iz * n + ix] = height_at(x0 + ix * CELL, z0 + iz * CELL)
	_finish_chunk(key, hs)


## Aus den Höhen (mit einem Rand von 1 Feld für die Normalen) Netz + Kollision machen.
func _finish_chunk(key: Vector2i, hs: PackedFloat32Array) -> void:
	if _chunks.has(key):
		return
	var n := CHUNK_RES + 3
	var v := CHUNK_RES + 1
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	verts.resize(v * v)
	normals.resize(v * v)
	colors.resize(v * v)
	uvs.resize(v * v)
	var ox := key.x * CHUNK
	var oz := key.y * CHUNK
	var heights := PackedFloat32Array()
	heights.resize(v * v)
	for iz in v:
		for ix in v:
			var hi := (iz + 1) * n + (ix + 1)
			var h := hs[hi]
			var x := ox + ix * CELL
			var z := oz + iz * CELL
			var nrm := Vector3(hs[hi - 1] - hs[hi + 1], 2.0 * CELL, hs[hi - n] - hs[hi + n]).normalized()
			var i := iz * v + ix
			verts[i] = Vector3(ix * CELL, h, iz * CELL)
			normals[i] = nrm
			colors[i] = ground_color(x, z, h, nrm.y)
			uvs[i] = Vector2(x, z) * 0.25
			heights[i] = h
	if _indices.is_empty():
		for iz in CHUNK_RES:
			for ix in CHUNK_RES:
				var i := iz * v + ix
				_indices.append_array([i, i + 1, i + v, i + 1, i + v + 1, i + v])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = _indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, _ground_mat)
	var root := Node3D.new()
	root.name = "Chunk_%d_%d" % [key.x, key.y]
	root.position = Vector3(ox, 0, oz)
	var mi := MeshInstance3D.new()
	mi.name = "Ground"
	mi.mesh = mesh
	root.add_child(mi)
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := HeightMapShape3D.new()
	shape.map_width = v
	shape.map_depth = v
	shape.map_data = heights
	cs.shape = shape
	cs.position = Vector3(CHUNK * 0.5, 0, CHUNK * 0.5)
	body.add_child(cs)
	root.add_child(body)
	add_child(root)
	_chunks[key] = root


## Grobes Gelände bis zum Kartenrand. Rund um den Spieler (und im Tal) sinkt es per Shader weg,
## dort liegt das feine Gelände. In der Ferne hebt es sich über Wald leicht an (wirkt wie Baumkronen).
func _build_far() -> void:
	var steps := int(HALF_SIZE * 2.0 / FAR_CELL)
	var v := steps + 1
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var hs := PackedFloat32Array()
	hs.resize(v * v)
	for iz in v:
		for ix in v:
			hs[iz * v + ix] = height_at(-HALF_SIZE + ix * FAR_CELL, -HALF_SIZE + iz * FAR_CELL)
	for iz in v:
		for ix in v:
			var x := -HALF_SIZE + ix * FAR_CELL
			var z := -HALF_SIZE + iz * FAR_CELL
			var h := hs[iz * v + ix]
			var hl := hs[iz * v + maxi(ix - 1, 0)]
			var hr := hs[iz * v + mini(ix + 1, v - 1)]
			var hu := hs[maxi(iz - 1, 0) * v + ix]
			var hd := hs[mini(iz + 1, v - 1) * v + ix]
			var nrm := Vector3(hl - hr, 2.0 * FAR_CELL, hu - hd).normalized()
			verts.append(Vector3(x, h, z))
			normals.append(nrm)
			var col := ground_color(x, z, h, nrm.y, true)
			# Wald von weitem: dunkles Grün der Baumkronen
			var dens := col.a
			col = Color(col.r, col.g, col.b).lerp(Color(0.07, 0.12, 0.06), dens * 0.85)
			col.a = dens
			colors.append(col)
			uvs.append(Vector2(x, z) * 0.06)
	var idx := PackedInt32Array()
	for iz in steps:
		for ix in steps:
			var i := iz * v + ix
			idx.append_array([i, i + 1, i + v, i + 1, i + v + 1, i + v])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
uniform sampler2D tex : source_color, filter_nearest_mipmap, repeat_enable;
uniform vec3 player_pos;
uniform float drop_r = %.1f;
uniform float core = %.1f;
void vertex() {
	vec3 w = VERTEX;
	float d = distance(w.xz, player_pos.xz);
	bool in_core = abs(w.x) < core && abs(w.z) < core;
	if (d < drop_r || in_core) {
		VERTEX.y -= 500.0;
	} else {
		// knapp unter dem feinen Gelände, in der Ferne Baumkronen
		VERTEX.y -= 1.6 * (1.0 - smoothstep(drop_r, drop_r + 160.0, d));
		VERTEX.y += COLOR.a * 11.0 * smoothstep(330.0, 600.0, d);
	}
}
void fragment() {
	ALBEDO = texture(tex, UV).rgb * COLOR.rgb;
	ROUGHNESS = 1.0;
}
""" % [FAR_DROP, CORE_CHUNKS * CHUNK - 8.0]
	_far_mat = ShaderMaterial.new()
	_far_mat.shader = sh
	_far_mat.set_shader_parameter("tex", TextureFactory.get_texture("grass_ground"))
	mesh.surface_set_material(0, _far_mat)
	var mi := MeshInstance3D.new()
	mi.name = "FarGround"
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 600.0
	add_child(mi)


func _build_water_material() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = TextureFactory.get_texture("water")
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	mat.albedo_color = Color(0.65, 0.78, 0.72, 0.85)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.3
	mat.metallic_specular = 0.35
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_water_mat = mat


## Wasserband entlang des Bachs, folgt dem Bachbett.
func _build_stream() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half_w := WATER_HALF_WIDTH
	var z := STREAM_START
	var prev_l := Vector3.ZERO
	var prev_r := Vector3.ZERO
	var first := true
	while z <= HALF_SIZE:
		var cx := stream_x_at(z)
		var y := stream_bed_height(z) + WATER_LEVEL
		var l := Vector3(cx - half_w, y, z)
		var r := Vector3(cx + half_w, y, z)
		if not first:
			for vv: Vector3 in [prev_l, prev_r, r, prev_l, r, l]:
				st.set_uv(Vector2(vv.x, vv.z) * 0.5)
				st.add_vertex(vv)
		prev_l = l
		prev_r = r
		first = false
		z += 1.0
	st.generate_normals()
	var mesh := st.commit()
	mesh.surface_set_material(0, _water_mat)
	var mi := MeshInstance3D.new()
	mi.name = "Stream"
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


## Seen und Moortümpel: runde Wasserflächen auf ihrem Spiegel.
func _build_lakes() -> void:
	for l: Dictionary in WorldMap.lakes():
		var c: Vector2 = l["pos"]
		_water_disc("Lake_" + String(l["id"]), Vector3(c.x, WorldMap.lake_level(l), c.y), float(l["r"]) * 1.03)
	for b: Dictionary in WorldMap.bogs():
		var k := 0
		for pool: Vector3 in b["pools"]:
			_water_disc("Pool_%s_%d" % [b["id"], k], Vector3(pool.x, WorldMap.water_level(pool.x, pool.y), pool.y), pool.z * 0.92)
			k += 1


func _water_disc(n: String, center: Vector3, radius: float) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs := 40
	for i in segs:
		var a0 := TAU * i / segs
		var a1 := TAU * (i + 1) / segs
		for p: Vector2 in [Vector2.ZERO, Vector2(cos(a1), sin(a1)) * radius, Vector2(cos(a0), sin(a0)) * radius]:
			st.set_normal(Vector3.UP)
			st.set_uv((p + Vector2(center.x, center.z)) * 0.3)
			st.add_vertex(Vector3(p.x, 0, p.y))
	var mesh := st.commit()
	mesh.surface_set_material(0, _water_mat)
	var mi := MeshInstance3D.new()
	mi.name = n
	mi.mesh = mesh
	mi.position = center
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
