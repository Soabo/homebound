class_name WorldMap
extends RefCounted
## Die große Welt (ca. 2,2 x 2,2 km) – Berge, Seen, Mulden, Moor, Lichtungen, Orte und Wege.
## Inhalte: data/world/map.json. Alles statisch, damit Gelände, Wald und Orte dieselben Daten abfragen.
## Das Tal rund um die Hütte (Radius ~95 m) bleibt dabei genau wie vorher.

const PATH := "res://data/world/map.json"
## Wege-Raster für schnelle Abstandsabfragen
const BUCKET := 40.0
## Ab hier mischt sich die große Landschaft ins Tal
const VALLEY_INNER := 95.0
const VALLEY_OUTER := 280.0
const TRAIL_KINDS := ["path", "track", "asphalt"]

static var _data: Dictionary = {}
static var _places: Dictionary = {}      ## id -> {name, pos: Vector2, ring, clear, flat, base}
static var _lakes: Array = []            ## {id, name, pos: Vector2, r, depth, level}
static var _basins: Array = []           ## {pos, r, depth, steep, base}
static var _bogs: Array = []             ## {pos, r, base, pools: [Vector3(x, z, r)]}
static var _mountains: Array = []        ## {pos, r, h}
static var _clearings: Array = []        ## {pos, r}
static var _cuts: Array = []             ## Einschnitte für Tunnel: {pos, half: Vector2, yaw, place}
static var _segments: Array = []         ## [a: Vector2, b: Vector2, half_w, kind]
static var _buckets: Dictionary = {}     ## Vector2i -> PackedInt32Array
static var _noise: FastNoiseLite
static var _ready_flag: bool = false
## Raster für Landschaftsformen: Vector2i -> {"places": [...], "lakes": [...], ...}
const CELL := 64.0
static var _cells: Dictionary = {}
static var _empty := {"places": [], "clearings": [], "lakes": [], "bogs": [], "basins": [], "mountains": []}


static func ensure() -> void:
	if _ready_flag:
		return
	_ready_flag = true
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		push_error("map.json fehlt")
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	_data = parsed if parsed is Dictionary else {}
	_noise = FastNoiseLite.new()
	_noise.seed = 4242
	_noise.frequency = 0.0016
	_noise.fractal_octaves = 4
	for m: Dictionary in _data.get("mountains", []):
		_mountains.append({"pos": _v2(m["pos"]), "r": float(m["r"]), "h": float(m["h"]), "name": m.get("name", "")})
	for c: Dictionary in _data.get("clearings", []):
		_clearings.append({"pos": _v2(c["pos"]), "r": float(c["r"])})
	# Orte (Position evtl. an Straße oder Bach gebunden)
	for p: Dictionary in _data.get("places", []):
		var pos := _resolve_pos(p)
		_places[p["id"]] = {"id": p["id"], "name": p.get("name", p["id"]), "pos": pos, "ring": p.get("ring", "near"),
			"clear": float(p.get("clear", 0)), "flat": float(p.get("flat", 0)), "base": NAN}
	for l: Dictionary in _data.get("lakes", []):
		_lakes.append({"id": l["id"], "name": l.get("name", ""), "pos": _resolve_pos(l), "r": float(l["r"]), "depth": float(l["depth"]), "level": NAN,
			"stream": l.has("stream_z")})
	for b: Dictionary in _data.get("basins", []):
		_basins.append({"id": b["id"], "pos": _resolve_pos(b), "r": float(b["r"]), "depth": float(b["depth"]), "steep": float(b.get("steep", 0.4)), "base": NAN})
	for b: Dictionary in _data.get("bogs", []):
		var pools: Array = []
		for q: Array in b.get("pools", []):
			pools.append(Vector3(float(q[0]), float(q[1]), float(q[2])))
		_bogs.append({"id": b["id"], "pos": _v2(b["pos"]), "r": float(b["r"]), "pools": pools, "base": NAN})
	for c: Dictionary in _data.get("cuts", []):
		_cuts.append({"pos": _v2(c["pos"]), "half": _v2(c["half"]), "yaw": deg_to_rad(float(c.get("yaw", 0.0))), "place": c.get("place", "")})
	# Formen ins Raster einsortieren (Einflussradius)
	for id: String in _places:
		var p: Dictionary = _places[id]
		_insert("places", p, p["pos"], maxf(float(p["flat"]) * 1.8, float(p["clear"]) * 1.25))
	for c: Dictionary in _clearings:
		_insert("clearings", c, c["pos"], float(c["r"]) * 1.1)
	for l: Dictionary in _lakes:
		_insert("lakes", l, l["pos"], float(l["r"]) * 1.6)
	for b: Dictionary in _bogs:
		_insert("bogs", b, b["pos"], float(b["r"]) * 1.4)
	for b: Dictionary in _basins:
		_insert("basins", b, b["pos"], float(b["r"]) * 1.25)
	for m: Dictionary in _mountains:
		_insert("mountains", m, m["pos"], float(m["r"]))
	# Wege in ein Raster einsortieren
	for t: Dictionary in _data.get("trails", []):
		var pts: Array = t["pts"]
		var hw := float(t.get("w", 2.0)) * 0.5
		var kind := TRAIL_KINDS.find(t.get("kind", "path"))
		for i in pts.size() - 1:
			var a := _v2(pts[i])
			var b := _v2(pts[i + 1])
			var idx := _segments.size()
			_segments.append([a, b, hw, kind])
			var lo := Vector2(minf(a.x, b.x), minf(a.y, b.y)) - Vector2.ONE * 24.0
			var hi := Vector2(maxf(a.x, b.x), maxf(a.y, b.y)) + Vector2.ONE * 24.0
			for bx in range(int(floorf(lo.x / BUCKET)), int(floorf(hi.x / BUCKET)) + 1):
				for bz in range(int(floorf(lo.y / BUCKET)), int(floorf(hi.y / BUCKET)) + 1):
					var key := Vector2i(bx, bz)
					var arr: PackedInt32Array = _buckets.get(key, PackedInt32Array())
					arr.append(idx)
					_buckets[key] = arr


static func _insert(kind: String, item: Dictionary, c: Vector2, r: float) -> void:
	if r <= 0.0:
		return
	for cx in range(int(floorf((c.x - r) / CELL)), int(floorf((c.x + r) / CELL)) + 1):
		for cz in range(int(floorf((c.y - r) / CELL)), int(floorf((c.y + r) / CELL)) + 1):
			var key := Vector2i(cx, cz)
			if not _cells.has(key):
				_cells[key] = {"places": [], "clearings": [], "lakes": [], "bogs": [], "basins": [], "mountains": []}
			(_cells[key][kind] as Array).append(item)


static func _cell(x: float, z: float) -> Dictionary:
	return _cells.get(Vector2i(int(floorf(x / CELL)), int(floorf(z / CELL))), _empty)


static func _v2(a: Array) -> Vector2:
	return Vector2(float(a[0]), float(a[1]))


static func _resolve_pos(p: Dictionary) -> Vector2:
	var off := _v2(p["offset"]) if p.has("offset") else Vector2.ZERO
	if p.has("road_z"):
		var z := float(p["road_z"])
		return Vector2(Terrain.road_x_at(z), z) + off
	if p.has("stream_z"):
		var z := float(p["stream_z"])
		return Vector2(Terrain.stream_x_at(z), z) + off
	return _v2(p["pos"])


static func data() -> Dictionary:
	ensure()
	return _data


static func half_size() -> float:
	ensure()
	return float(_data.get("half_size", 1150))


static func limit() -> float:
	ensure()
	return float(_data.get("limit", 1100))


static func places() -> Dictionary:
	ensure()
	return _places


static func place_pos(id: String) -> Vector2:
	ensure()
	return _places[id]["pos"] if _places.has(id) else Vector2.ZERO


## Weltposition eines Ortes (auf dem Boden).
static func place_point(id: String) -> Vector3:
	var p := place_pos(id)
	return Vector3(p.x, Terrain.height_at(p.x, p.y), p.y)


static func lakes() -> Array:
	ensure()
	return _lakes


static func bogs() -> Array:
	ensure()
	return _bogs


static func mountains() -> Array:
	ensure()
	return _mountains


static func segments() -> Array:
	ensure()
	return _segments


# --- Höhe ------------------------------------------------------------------

## Große Landschaft: weite Hügel, Bach- und Straßental, Berge, Anstieg am Rand.
## Im Tal um die Hütte 0 (dort gilt das alte Gelände).
static func macro_height(x: float, z: float) -> float:
	ensure()
	var r := Vector2(x, z).length()
	var mask := smoothstep(VALLEY_INNER, VALLEY_OUTER, r)
	if mask <= 0.0:
		return 0.0
	var n := _noise.get_noise_2d(x, z) * 0.5 + 0.5
	var h := pow(n, 1.6) * 38.0
	# Bach und Straße laufen in einem flachen Tal
	var corridor := smoothstep(14.0, 170.0, Terrain.stream_distance(x, z))
	if z > 16.0:
		corridor = minf(corridor, smoothstep(10.0, 150.0, Terrain.road_distance(x, z)))
	h *= lerpf(0.12, 1.0, corridor)
	# Das Gelände fällt von Norden nach Süden – der Bach fließt nach Süden
	h += -z * (0.025 if z < 0.0 else 0.018)
	for m: Dictionary in _cell(x, z)["mountains"]:
		var d := (m["pos"] as Vector2).distance_to(Vector2(x, z))
		var mr: float = m["r"]
		if d < mr:
			var t := 1.0 - d / mr
			var ridge := 0.85 + 0.3 * (_noise.get_noise_2d(x * 3.1 + 500.0, z * 3.1) * 0.5 + 0.5)
			h += float(m["h"]) * t * t * (3.0 - 2.0 * t) * ridge * lerpf(0.4, 1.0, corridor)
	# Am Kartenrand steigt das Land an (außer dort, wo Bach und Straße hinausführen)
	var edge := maxf(absf(x), absf(z))
	h += smoothstep(930.0, 1120.0, edge) * 80.0 * corridor
	return h * mask


## Orte einebnen, Seen, Mulden und Moor eintiefen. base = Höhe ohne diese Formen.
static func shape_height(x: float, z: float, base: float) -> float:
	ensure()
	var h := base
	var q := Vector2(x, z)
	if q.length() < VALLEY_INNER - 10.0:
		return h
	var cell := _cell(x, z)
	for p: Dictionary in cell["places"]:
		var fr: float = p["flat"]
		if fr <= 0.0:
			continue
		var d := (p["pos"] as Vector2).distance_to(q)
		if d < fr * 1.8:
			var w := 1.0 - smoothstep(fr, fr * 1.8, d)
			h = lerpf(h, _place_base(p), w)
	for b: Dictionary in cell["bogs"]:
		var d := (b["pos"] as Vector2).distance_to(q)
		var br: float = b["r"]
		if d < br * 1.4:
			var w := 1.0 - smoothstep(br * 0.7, br * 1.4, d)
			h = lerpf(h, _bog_base(b), w)
			for pool: Vector3 in b["pools"]:
				var pd := Vector2(pool.x, pool.y).distance_to(q)
				if pd < pool.z:
					h -= 1.1 * (1.0 - smoothstep(pool.z * 0.4, pool.z, pd))
	for b: Dictionary in cell["basins"]:
		var d := (b["pos"] as Vector2).distance_to(q)
		var br: float = b["r"]
		if d < br * 1.25:
			var base_h := _basin_base(b)
			var edge := lerpf(0.95, 0.55, 1.0 - float(b["steep"]))
			var w := 1.0 - smoothstep(br * edge, br * 1.05, d)
			var rim := 1.0 - smoothstep(br * 1.0, br * 1.25, d)
			# Rand leicht angeglichen, innen flacher Boden
			h = lerpf(h, maxf(h, base_h), rim * 0.4)
			h = lerpf(h, base_h - float(b["depth"]), w)
	for c: Dictionary in _cuts:
		var rel := (q - (c["pos"] as Vector2)).rotated(-float(c["yaw"]))
		var hf: Vector2 = c["half"]
		if absf(rel.x) < hf.x + 1.0 and absf(rel.y) < hf.y + 1.0:
			var floor_h := _place_base(_places[c["place"]]) - 0.05
			var w := (1.0 - smoothstep(hf.x, hf.x + 1.0, absf(rel.x))) * (1.0 - smoothstep(hf.y, hf.y + 1.0, absf(rel.y)))
			h = lerpf(h, minf(h, floor_h), w)
	for l: Dictionary in cell["lakes"]:
		var d := (l["pos"] as Vector2).distance_to(q)
		var lr: float = l["r"]
		if d < lr * 1.6:
			var level := lake_level(l)
			# Ufer: nie unter dem Wasserspiegel außerhalb des Sees
			var bank := level + 0.5
			var shore := 1.0 - smoothstep(lr, lr * 1.6, d)
			h = lerpf(h, maxf(h, bank), shore)
			if d < lr * 1.05:
				var t := clampf(d / lr, 0.0, 1.05)
				var bottom := level - float(l["depth"]) * (1.0 - t * t)
				var w := 1.0 - smoothstep(0.85, 1.05, t)
				h = lerpf(h, minf(h, bottom), w)
	return h


static func _base_at(x: float, z: float) -> float:
	return Terrain._raw_height_unshaped(x, z)


static func _place_base(p: Dictionary) -> float:
	if is_nan(float(p["base"])):
		var c: Vector2 = p["pos"]
		p["base"] = _base_at(c.x, c.y)
	return p["base"]


static func _bog_base(b: Dictionary) -> float:
	if is_nan(float(b["base"])):
		var c: Vector2 = b["pos"]
		b["base"] = _base_at(c.x, c.y) - 0.3
	return b["base"]


static func _basin_base(b: Dictionary) -> float:
	if is_nan(float(b["base"])):
		var c: Vector2 = b["pos"]
		b["base"] = _base_at(c.x, c.y)
	return b["base"]


static func lake_level(l: Dictionary) -> float:
	if is_nan(float(l["level"])) and l.get("stream", false):
		# See am Bach: Spiegel = Wasser am Bachanfang
		l["level"] = _base_at(Terrain.stream_x_at(Terrain.STREAM_START), Terrain.STREAM_START) - 1.1 + Terrain.WATER_LEVEL + 0.05
	if is_nan(float(l["level"])):
		var c: Vector2 = l["pos"]
		# Wasserspiegel: tiefster Punkt am Rand, damit der See nirgends überläuft
		var lowest := INF
		for k in 16:
			var a := TAU * k / 16.0
			var p := c + Vector2(cos(a), sin(a)) * float(l["r"]) * 1.15
			lowest = minf(lowest, _base_at(p.x, p.y))
		l["level"] = minf(lowest, _base_at(c.x, c.y)) - 0.6
	return l["level"]


# --- Wasser, Moor ----------------------------------------------------------

## Wasserspiegel an dieser Stelle (Seen, Moortümpel) oder -INF.
static func water_level(x: float, z: float) -> float:
	ensure()
	var q := Vector2(x, z)
	var cell := _cell(x, z)
	for l: Dictionary in cell["lakes"]:
		if (l["pos"] as Vector2).distance_to(q) < float(l["r"]) * 1.02:
			return lake_level(l)
	for b: Dictionary in cell["bogs"]:
		if (b["pos"] as Vector2).distance_to(q) < float(b["r"]) * 1.2:
			for pool: Vector3 in b["pools"]:
				if Vector2(pool.x, pool.y).distance_to(q) < pool.z * 0.9:
					return _bog_base(b) - 0.25
	return -INF


## Mulden: (Anteil 0..1, Art) – Art 0 = Steinbruch (Fels), 1 = Stausee (Schlamm).
static func basin_info(x: float, z: float) -> Vector2:
	ensure()
	var q := Vector2(x, z)
	for b: Dictionary in _cell(x, z)["basins"]:
		var d := (b["pos"] as Vector2).distance_to(q)
		var br: float = b["r"]
		if d < br * 1.05:
			return Vector2(1.0 - smoothstep(br * 0.8, br * 1.05, d), 0.0 if b["id"] == "steinbruch" else 1.0)
	return Vector2.ZERO


## 0..1: wie stark man hier im Moor einsinkt (Stege zählen nicht – das prüft der Spieler selbst).
static func bog_factor(x: float, z: float) -> float:
	ensure()
	var q := Vector2(x, z)
	var f := 0.0
	for b: Dictionary in _cell(x, z)["bogs"]:
		var d := (b["pos"] as Vector2).distance_to(q)
		f = maxf(f, 1.0 - smoothstep(float(b["r"]) * 0.6, float(b["r"]) * 1.05, d))
	return f


# --- Wege ------------------------------------------------------------------

## Abstand zum nächsten Weg (vom Wegrand aus, negativ = auf dem Weg) und Art (0 path, 1 track, 2 asphalt).
static func trail_info(x: float, z: float) -> Vector2:
	ensure()
	var key := Vector2i(int(floorf(x / BUCKET)), int(floorf(z / BUCKET)))
	if not _buckets.has(key):
		return Vector2(INF, -1)
	var q := Vector2(x, z)
	var best := INF
	var kind := -1
	for idx in _buckets[key]:
		var s: Array = _segments[idx]
		var d := _seg_dist(q, s[0], s[1]) - float(s[2])
		if d < best:
			best = d
			kind = s[3]
	return Vector2(best, kind)


static func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return p.distance_to(a + ab * t)


# --- Bäume -----------------------------------------------------------------

## 0..1: Wie dicht hier Wald wächst (0 = Lichtung, Weg, See, Ort).
static func tree_density(x: float, z: float, h: float) -> float:
	ensure()
	var q := Vector2(x, z)
	var dens := 1.0
	var ti := trail_info(x, z)
	if ti.x < 1.6:
		return 0.0
	dens *= smoothstep(1.6, 4.0, ti.x)
	var cell := _cell(x, z)
	for p: Dictionary in cell["places"]:
		var cr: float = p["clear"]
		if cr > 0.0:
			var d := (p["pos"] as Vector2).distance_to(q)
			if d < cr:
				return 0.0
			dens *= smoothstep(cr, cr * 1.25, d) if d < cr * 1.25 else 1.0
	for c: Dictionary in cell["clearings"]:
		var d := (c["pos"] as Vector2).distance_to(q)
		if d < float(c["r"]):
			return 0.0
	for l: Dictionary in cell["lakes"]:
		if (l["pos"] as Vector2).distance_to(q) < float(l["r"]) * 1.15:
			return 0.0
	for b: Dictionary in cell["bogs"]:
		var d := (b["pos"] as Vector2).distance_to(q)
		if d < float(b["r"]):
			dens *= 0.08
	for b: Dictionary in cell["basins"]:
		if (b["pos"] as Vector2).distance_to(q) < float(b["r"]) * 1.05:
			return 0.0
	# Über der Baumgrenze nur noch vereinzelt
	dens *= 1.0 - smoothstep(110.0, 150.0, h) * 0.9
	return dens


## Lichtungen/Orte/Moor: Wiese statt Waldboden (0..1).
static func meadow(x: float, z: float) -> float:
	ensure()
	var q := Vector2(x, z)
	var m := 0.0
	var cell := _cell(x, z)
	for c: Dictionary in cell["clearings"]:
		m = maxf(m, 1.0 - smoothstep(float(c["r"]) * 0.7, float(c["r"]) * 1.1, (c["pos"] as Vector2).distance_to(q)))
	for p: Dictionary in cell["places"]:
		var cr: float = p["clear"]
		if cr > 0.0:
			m = maxf(m, 1.0 - smoothstep(cr * 0.6, cr * 1.05, (p["pos"] as Vector2).distance_to(q)))
	return m
