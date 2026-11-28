class_name PlaceKit
extends RefCounted
## Bausteine für die Orte der großen Welt: Funde zum Aufheben, Notizen, Baupläne, einfache Gebäude.
## Alle Positionen lokal zum Ort (root steht auf dem Boden in der Ortsmitte).

static var _m: Dictionary = {}


static func mat(kind: String) -> Material:
	if _m.has(kind):
		return _m[kind]
	var m: Material
	match kind:
		"wood": m = BuildKit.tex_mat("planks_v", 0.8, Color(0.9, 0.82, 0.72))
		"wood_old": m = BuildKit.tex_mat("planks_v", 0.8, Color(0.62, 0.6, 0.58))
		"wood_h": m = BuildKit.tex_mat("planks_h", 0.8, Color(0.85, 0.8, 0.72))
		"logs": m = BuildKit.tex_mat("logs", 0.8)
		"bark": m = BuildKit.tex_mat("bark", 0.8)
		"stone": m = BuildKit.tex_mat("stone", 0.7)
		"stone_dark": m = BuildKit.tex_mat("stone_dark", 0.7)
		"rock": m = BuildKit.tex_mat("rock", 2.0)
		"concrete": m = BuildKit.tex_mat("metal", 2.5, Color(0.78, 0.77, 0.73), 0.95)
		"metal": m = BuildKit.tex_mat("metal", 0.6, Color(1.2, 1.2, 1.2), 0.5)
		"rust": m = BuildKit.tex_mat("metal", 0.5, Color(1.1, 0.65, 0.4), 0.7)
		"steel_dark": m = BuildKit.tex_mat("metal", 0.5, Color(0.55, 0.57, 0.6), 0.4)
		"shingles": m = BuildKit.tex_mat("shingles", 1.2)
		"tin": m = BuildKit.tex_mat("metal", 0.3, Color(0.85, 0.88, 0.9), 0.5)
		"fabric": m = BuildKit.tex_mat("fabric", 0.5)
		"canvas": m = BuildKit.tex_mat("fabric", 0.6, Color(0.6, 0.68, 0.45))
		"glass": m = BuildKit.glass_mat()
		"paper": m = BuildKit.color_mat(Color(0.86, 0.82, 0.7), 0.9)
		"dark": m = BuildKit.color_mat(Color(0.06, 0.06, 0.07), 0.8)
		"alien": m = BuildKit.tex_mat("alien_skin", 0.8, Color(0.6, 0.55, 0.65), 0.3)
		"glow": m = BuildKit.emissive_mat(Color(0.6, 0.4, 1.0), 1.4)
		"red": m = BuildKit.color_mat(Color(0.65, 0.1, 0.08), 0.6)
		"white": m = BuildKit.color_mat(Color(0.88, 0.88, 0.85), 0.7)
		"yellow": m = BuildKit.color_mat(Color(0.9, 0.72, 0.15), 0.6)
		"olive": m = BuildKit.tex_mat("fabric", 0.5, Color(0.55, 0.6, 0.35))
		"asphalt": m = BuildKit.tex_mat("stone_dark", 2.0, Color(0.55, 0.55, 0.58))
		"mud": m = BuildKit.color_mat(Color(0.18, 0.15, 0.11), 1.0)
		# neu 27.11.: Orte mit Foto-Materialien (im Retro-Stil die gezeichneten Ersatzstoffe)
		"plaster": m = BuildKit.color_mat(Color(0.86, 0.84, 0.78), 0.9)
		"gravel": m = BuildKit.tex_mat("stone", 0.5, Color(0.75, 0.73, 0.7))
		"paving": m = BuildKit.tex_mat("stone", 0.8, Color(0.8, 0.78, 0.75))
		"corrugated": m = BuildKit.tex_mat("metal", 0.3, Color(0.6, 0.7, 0.62), 0.5)
		"furn": m = BuildKit.tex_mat("planks_h", 0.6, Color(0.8, 0.62, 0.45))
		"table": m = BuildKit.tex_mat("planks_h", 0.6, Color(0.7, 0.55, 0.4))
		"cabinet": m = BuildKit.tex_mat("planks_v", 0.6, Color(0.6, 0.45, 0.32))
		"cloth": m = BuildKit.tex_mat("fabric", 0.4, Color(0.85, 0.8, 0.72))
		"sackcloth": m = BuildKit.tex_mat("fabric", 0.4, Color(1.2, 1.05, 0.75))
		_: m = BuildKit.color_mat(Color(1, 0, 1))
	m = _photo(kind, m)
	# Schnee nur auf Materialien, die ausschließlich draußen liegen (Dächer, Felsen, Straße) – sonst schneit es drinnen
	if kind in ["rock", "tin", "shingles", "corrugated", "asphalt"] and m is BaseMaterial3D:
		m = SnowCover.register(m as BaseMaterial3D)
	_m[kind] = m
	return m


## Im klaren Stil bekommen die Ort-Materialien Foto-Texturen (Kachelgröße in m, Farbstich).
const PHOTO := {
	"wood": ["plank_wall_v", 2.4, Color(0.95, 0.9, 0.84)],
	"wood_old": ["plank_wall_v", 2.4, Color(0.72, 0.72, 0.7)],
	"wood_h": ["plank_wall", 2.4, Color(0.92, 0.88, 0.82)],
	"stone": ["rock", 1.6, Color(0.92, 0.9, 0.88)],
	"stone_dark": ["rock", 1.6, Color(0.6, 0.6, 0.6)],
	"rock": ["rock", 2.0, Color.WHITE],
	"concrete": ["concrete", 2.2, Color.WHITE],
	"rust": ["rust", 1.0, Color.WHITE],
	"shingles": ["shingles_wood", 1.0, Color.WHITE],
	"tin": ["corrugated", 0.9, Color(0.9, 0.95, 1.0)],
	"corrugated": ["corrugated", 0.9, Color.WHITE],
	"plaster": ["plaster", 1.8, Color.WHITE],
	"gravel": ["gravel", 1.2, Color.WHITE],
	"paving": ["gred", 1.6, Color.WHITE],
	"asphalt": ["concrete", 2.5, Color(0.42, 0.42, 0.44)],
	"furn": ["furn_fine", 1.0, Color.WHITE],
	"table": ["furn_table", 1.2, Color.WHITE],
	"cabinet": ["furn_cabinet", 1.2, Color.WHITE],
	"cloth": ["fab_bed", 0.6, Color(1.05, 1.0, 0.95)],
	"sackcloth": ["fab_sack", 0.5, Color.WHITE],
	"canvas": ["fab_sack", 0.8, Color(0.6, 0.7, 0.45)],
}


static func _photo(kind: String, m: Material) -> Material:
	if not PHOTO.has(kind):
		return m
	var d: Array = PHOTO[kind]
	var out := Look.photo_mat(m, String(d[0]), float(d[1]), d[2] as Color)
	if out != m and out is StandardMaterial3D:
		(out as StandardMaterial3D).normal_scale = 0.8   # Bauwerke dürfen etwas mehr Relief zeigen als Möbel
	return out


## Bodenhöhe relativ zum Ort.
static func ground(root: Node3D, lx: float, lz: float) -> float:
	var w := root.global_position + Vector3(lx, 0, lz).rotated(Vector3.UP, root.global_rotation.y)
	return Terrain.height_at(w.x, w.z) - root.global_position.y


## Punkt auf dem Boden (lokal).
static func on_ground(root: Node3D, lx: float, lz: float, lift: float = 0.0) -> Vector3:
	return Vector3(lx, ground(root, lx, lz) + lift, lz)


# --- Funde -------------------------------------------------------------------

## Etwas zum Aufheben. look = Aussehen (crate, box, sack, cans, jars, bottles, case, canister, medkit,
## paper, logs, parts, card, bag, candles, wool, peat, alien, cell, tool, device).
static func loot(root: Node3D, n: String, item: String, amount: int, pos: Vector3, look: String = "crate",
		per_take: int = 1, yaw: float = 0.0) -> ItemPickup:
	var p := ItemPickup.new()
	p.name = n
	p.item_id = item
	p.amount = amount
	p.per_take = per_take
	p.position = pos
	p.rotation_degrees.y = yaw
	var size := Vector3(0.5, 0.4, 0.5)
	match look:
		"crate": size = Vector3(0.7, 0.5, 0.5)
		"cans", "jars", "bottles", "candles": size = Vector3(0.45, 0.3, 0.3)
		"card", "paper": size = Vector3(0.3, 0.15, 0.3)
		"logs": size = Vector3(1.4, 0.7, 1.0)
		"parts": size = Vector3(1.0, 0.5, 0.8)
		"canister": size = Vector3(0.4, 0.5, 0.25)
		"sack", "wool", "peat": size = Vector3(0.6, 0.5, 0.5)
	p.collider_size = size
	p.collider_offset = Vector3(0, size.y * 0.5, 0)
	root.add_child(p)
	_loot_visual(p, look, amount)
	return p


static func _loot_visual(p: ItemPickup, look: String, amount: int) -> void:
	var piece := func() -> Node3D:
		var v := Node3D.new()
		p.add_child(v)
		p.visuals.append(v)
		return v
	match look:
		"crate":
			var v: Node3D = piece.call()
			BuildKit.box(v, Vector3(0.66, 0.44, 0.46), Vector3(0, 0.22, 0), mat("wood_h"), false)
			for sx: float in [-1.0, 1.0]:
				BuildKit.box(v, Vector3(0.04, 0.46, 0.48), Vector3(sx * 0.3, 0.23, 0), mat("wood"), false)
		"box":
			var v: Node3D = piece.call()
			BuildKit.box(v, Vector3(0.45, 0.32, 0.35), Vector3(0, 0.16, 0), BuildKit.tex_mat("fabric", 0.3, Color(1.45, 1.2, 0.85)), false)
			BuildKit.box(v, Vector3(0.47, 0.02, 0.06), Vector3(0, 0.32, 0), BuildKit.color_mat(Color(0.75, 0.7, 0.5)), false)
		"sack", "peat", "wool":
			var col := Color(1.2, 1.05, 0.75) if look == "sack" else (Color(0.5, 0.38, 0.25) if look == "peat" else Color(1.8, 1.75, 1.6))
			for i in clampi(amount, 1, 4):
				var v: Node3D = piece.call()
				BuildKit.sphere(v, 0.2, Vector3(-0.15 + (i % 2) * 0.3, 0.17 + (i / 2) * 0.25, 0), BuildKit.tex_mat("fabric", 0.4, col), Vector3(1.1, 0.85, 0.9), 8)
		"cans":
			for i in clampi(amount, 1, 6):
				var v: Node3D = piece.call()
				Icons.food_can(v, Vector3(-0.14 + (i % 3) * 0.14, 0.0 + (i / 3) * 0.13, 0), 0.05, 0.12)
		"jars":
			for i in clampi(amount, 1, 6):
				var v: Node3D = piece.call()
				var x := -0.14 + (i % 3) * 0.14
				BuildKit.cylinder(v, 0.05, 0.12, Vector3(x, 0.06 + (i / 3) * 0.13, 0), BuildKit.color_mat(Color(0.85, 0.55, 0.12), 0.2), false, Vector3.ZERO, -1.0, 10)
				BuildKit.cylinder(v, 0.052, 0.025, Vector3(x, 0.13 + (i / 3) * 0.13, 0), mat("metal"), false, Vector3.ZERO, -1.0, 10)
		"bottles":
			for i in clampi(amount, 1, 6):
				var v: Node3D = piece.call()
				var bm := BuildKit.lathe(v, PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.95, 0.0), Vector2(1.0, 0.05), Vector2(1.0, 0.62),
						Vector2(0.45, 0.82), Vector2(0.35, 0.9), Vector2(0.0, 0.9)]), Vector3(-0.14 + (i % 3) * 0.14, 0, (i / 3) * 0.12), BuildKit.color_mat(Color(0.45, 0.65, 0.8), 0.1), 10)
				bm.scale = Vector3(0.045, 0.26, 0.045)
		"candles":
			for i in clampi(amount, 1, 6):
				var v: Node3D = piece.call()
				BuildKit.cylinder(v, 0.02, 0.18, Vector3(-0.12 + (i % 3) * 0.12, 0.09, (i / 3) * 0.1), BuildKit.color_mat(Color(0.95, 0.92, 0.82)), false, Vector3.ZERO, -1.0, 8)
		"case":
			var v: Node3D = piece.call()
			BuildKit.box(v, Vector3(0.48, 0.16, 0.34), Vector3(0, 0.08, 0), mat("steel_dark"), false)
			BuildKit.box(v, Vector3(0.14, 0.03, 0.03), Vector3(0, 0.175, 0), mat("dark"), false)
		"canister":
			for i in clampi(amount, 1, 3):
				var v: Node3D = piece.call()
				BuildKit.box(v, Vector3(0.18, 0.38, 0.28), Vector3(-0.1 + i * 0.2, 0.19, 0), BuildKit.color_mat(Color(0.7, 0.12, 0.08), 0.5, 0.2), false)
				BuildKit.cylinder(v, 0.025, 0.05, Vector3(-0.1 + i * 0.2, 0.4, 0.08), mat("dark"), false, Vector3.ZERO, -1.0, 6)
		"medkit":
			for i in clampi(amount, 1, 3):
				var v: Node3D = piece.call()
				BuildKit.box(v, Vector3(0.3, 0.12, 0.22), Vector3(0, 0.06 + i * 0.125, 0), mat("white"), false)
				BuildKit.box(v, Vector3(0.12, 0.004, 0.03), Vector3(0, 0.122 + i * 0.125, 0), mat("red"), false)
				BuildKit.box(v, Vector3(0.03, 0.004, 0.12), Vector3(0, 0.122 + i * 0.125, 0), mat("red"), false)
		"paper":
			var v: Node3D = piece.call()
			BuildKit.box(v, Vector3(0.24, 0.02, 0.32), Vector3(0, 0.01, 0), mat("paper"), false, Vector3(0, 12, 0))
		"card":
			var v: Node3D = piece.call()
			BuildKit.box(v, Vector3(0.085, 0.004, 0.055), Vector3(0, 0.003, 0), BuildKit.color_mat(Color(0.2, 0.45, 0.75), 0.4), false, Vector3(0, 20, 0))
			BuildKit.box(v, Vector3(0.02, 0.005, 0.015), Vector3(-0.02, 0.006, 0), BuildKit.color_mat(Color(0.85, 0.75, 0.3), 0.3, 0.6), false)
		"logs":
			for i in clampi(amount, 1, 8):
				var v: Node3D = piece.call()
				BuildKit.cylinder(v, 0.12, 1.2, Vector3(0, 0.12 + (i / 4) * 0.22, -0.36 + (i % 4) * 0.24), mat("bark"), false, Vector3(0, 0, 90), -1.0, 8)
		"parts":
			for i in clampi(amount, 1, 6):
				var v: Node3D = piece.call()
				BuildKit.box(v, Vector3(0.3, 0.12, 0.2), Vector3(-0.3 + (i % 3) * 0.3, 0.06 + (i / 3) * 0.13, randf_range(-0.2, 0.2)), mat("rust"), false, Vector3(randf_range(-10, 10), randf() * 90, 0))
		"bag":
			var v: Node3D = piece.call()
			BuildKit.box(v, Vector3(0.36, 0.48, 0.2), Vector3(0, 0.24, 0), BuildKit.tex_mat("fabric", 0.4, Color(0.7, 0.55, 0.35)), false, Vector3(-8, 0, 0))
		"alien", "cell":
			var v: Node3D = piece.call()
			if look == "cell":
				BuildKit.cylinder(v, 0.07, 0.22, Vector3(0, 0.11, 0), mat("steel_dark"), false, Vector3.ZERO, -1.0, 8)
				BuildKit.cylinder(v, 0.05, 0.16, Vector3(0, 0.11, 0), BuildKit.emissive_mat(Color(0.4, 0.9, 0.8), 1.5), false, Vector3.ZERO, -1.0, 8)
			else:
				BuildKit.sphere(v, 0.12, Vector3(0, 0.1, 0), mat("alien"), Vector3(1.2, 0.7, 1.0), 9)
				BuildKit.sphere(v, 0.05, Vector3(0.05, 0.16, 0.02), mat("glow"), Vector3.ONE, 6)
		"tool":
			var v: Node3D = piece.call()
			BuildKit.box(v, Vector3(0.18, 0.1, 0.12), Vector3(0, 0.05, 0), mat("dark"), false)
			for sx: float in [-1.0, 1.0]:
				BuildKit.cylinder(v, 0.032, 0.12, Vector3(sx * 0.045, 0.06, -0.08), mat("dark"), false, Vector3(90, 0, 0), -1.0, 8)
		"device":
			var v: Node3D = piece.call()
			BuildKit.box(v, Vector3(0.5, 0.35, 0.4), Vector3(0, 0.175, 0), mat("steel_dark"), false)
			BuildKit.cylinder(v, 0.12, 0.08, Vector3(0, 0.39, 0), mat("rust"), false, Vector3.ZERO, -1.0, 10)
			BuildKit.box(v, Vector3(0.6, 0.05, 0.05), Vector3(0, 0.33, 0.22), mat("dark"), false)
		_:
			var v: Node3D = piece.call()
			BuildKit.box(v, Vector3(0.3, 0.2, 0.3), Vector3(0, 0.1, 0), mat("wood"), false)


## Lesbare Notiz (Text in data/research/research.json unter "notes").
static func note(root: Node3D, note_id: String, pos: Vector3, hide_paper: bool = false) -> ResearchNote:
	var n := ResearchNote.new()
	n.name = "Note_" + note_id
	n.note_id = note_id
	n.anchor = pos
	n.hide_paper = hide_paper
	root.add_child(n)
	return n


## Bauplan zum Mitnehmen.
static func blueprint(root: Node3D, bp_id: String, label: String, pos: Vector3) -> Blueprint:
	var b := Blueprint.new()
	b.name = "BP_" + bp_id
	b.bp_id = bp_id
	b.label = label
	b.position = pos
	root.add_child(b)
	return b


## Etwas zum Anschauen (Text) – optional mit Aktion.
static func inspect(root: Node3D, n: String, prompt: String, text: String, pos: Vector3, size: Vector3 = Vector3(1, 1, 1)) -> PlaceInspect:
	var i := PlaceInspect.new()
	i.name = n
	i.prompt = prompt
	i.text = text
	i.position = pos
	i.area_size = size
	root.add_child(i)
	return i


# --- Gebäude -----------------------------------------------------------------

## Einfache Hütte/Baracke: Wände mit Türöffnung (vorne = +z) und Fenstern, Boden, Dach.
## Rückgabe: Knoten in Hüttenmitte auf Bodenhöhe (Inneres lokal hinzufügen, Boden y = 0).
static func hut(root: Node3D, n: String, center: Vector3, size: Vector2, height: float, yaw: float,
		wall_mat: String = "wood", roof: String = "gable", roof_mat: String = "shingles", door: float = 1.0,
		windows: bool = true, broken: bool = false) -> Node3D:
	var h := Node3D.new()
	h.name = n
	h.position = center
	h.rotation_degrees.y = yaw
	root.add_child(h)
	var hx := size.x * 0.5
	var hz := size.y * 0.5
	var t := 0.14
	var wm := mat(wall_mat)
	# Sockel bis in den Boden (Hang)
	BuildKit.box(h, Vector3(size.x + 0.2, 1.2, size.y + 0.2), Vector3(0, -0.55, 0), mat("stone_dark") if wall_mat != "concrete" else mat("concrete"), true)
	BuildKit.box(h, Vector3(size.x - 0.1, 0.06, size.y - 0.1), Vector3(0, 0.03, 0), mat("wood_h"), false)
	var win := [] if not windows else [Vector4(hx * 0.5, 0.8, 0.9, 1.7)]
	var front_open := [Vector4(hx, door, 0.0, 2.05)] if door > 0.0 else []
	if windows and size.x > 4.0:
		front_open.append(Vector4(hx * 0.45, 0.8, 0.9, 1.7))
	var walls := {
		"Front": [BuildKit.wall(h, Vector2(-hx, hz), Vector2(hx, hz), 0.0, height, t, wm, front_open, "Front"), front_open],
		"Back": [BuildKit.wall(h, Vector2(hx, -hz), Vector2(-hx, -hz), 0.0, height, t, wm, win, "Back"), win],
		"Left": [BuildKit.wall(h, Vector2(-hx, -hz), Vector2(-hx, hz), 0.0, height, t, wm, win if size.y > 3.0 else [], "Left"), win if size.y > 3.0 else []],
		"Right": [BuildKit.wall(h, Vector2(hx, hz), Vector2(hx, -hz), 0.0, height, t, wm, [] if broken else (win if size.y > 3.0 else []), "Right"),
				[] if broken else (win if size.y > 3.0 else [])],
	}
	_hut_details(h, walls, size, height, t, wall_mat, door, broken)
	if roof == "flat":
		BuildKit.box(h, Vector3(size.x + 0.4, 0.16, size.y + 0.4), Vector3(0, height + 0.08, 0), mat(roof_mat), true)
	elif roof == "gable":
		var rise := minf(size.x * 0.35, 1.6)
		var slope := sqrt(hx * hx + rise * rise) + 0.3
		var ang := rad_to_deg(atan2(rise, hx))
		for sx: float in [-1.0, 1.0]:
			if broken and sx > 0.0:
				continue
			BuildKit.box(h, Vector3(slope, 0.1, size.y + 0.5), Vector3(sx * hx * 0.5, height + rise * 0.5 + 0.05, 0), mat(roof_mat), true, Vector3(0, 0, -sx * ang))
		for sz: float in [-1.0, 1.0]:
			BuildKit.gable(h, size.x, rise, t, Vector3(0, height, sz * (hz - t * 0.5)), 0.0, wm)
		# Lebendige Orte: Stirnbretter, Firstbrett, Traufbretter, Rinne mit Fallrohr
		var ow := mat("wood_old")
		for sx: float in [-1.0, 1.0]:
			if broken and sx > 0.0:
				continue
			for sz: float in [-1.0, 1.0]:
				BuildKit.box(h, Vector3(slope, 0.16, 0.035), Vector3(sx * hx * 0.5, height + rise * 0.5 - 0.02, sz * (hz + 0.26)), ow, false, Vector3(0, 0, -sx * ang))
			var ex := sx * (hx + 0.3 * cos(deg_to_rad(ang)))
			var ey := height - 0.3 * sin(deg_to_rad(ang)) + 0.02
			BuildKit.box(h, Vector3(0.035, 0.16, size.y + 0.5), Vector3(ex, ey, 0), ow, false)
			if not broken and sx < 0.0:
				PlaceDetail.gutter(h, Vector3(ex - 0.05, ey - 0.05, -hz - 0.25), Vector3(ex - 0.05, ey - 0.05, hz + 0.2), 0.0, "rust", Vector3(0.3, 0, -0.3))
		if not broken:
			BuildKit.box(h, Vector3(0.22, 0.05, size.y + 0.52), Vector3(0, height + rise + 0.08, 0), ow, false)
	return h


## Fenster mit Rahmen/Glas/Fensterbank, Tür mit Zarge und Beschlägen, Eckbretter, Stufe, Unkraut – für alle Hütten der Orte.
static func _hut_details(h: Node3D, walls: Dictionary, size: Vector2, height: float, t: float, wall_mat: String, door: float, broken: bool) -> void:
	var hx := size.x * 0.5
	var hz := size.y * 0.5
	var frame := "wood_old" if wall_mat != "concrete" else "steel_dark"
	for key: String in walls:
		var w: Node3D = walls[key][0]
		for o: Vector4 in walls[key][1]:
			if o.z < 0.01:
				# Tür: Zarge außen + Flügel (halb offen, nach innen)
				var ow := mat(frame)
				for sx: float in [-1.0, 1.0]:
					BuildKit.box(w, Vector3(0.08, o.w + 0.08, 0.04), Vector3(o.x + sx * (o.y * 0.5 + 0.04), (o.w + 0.08) * 0.5, t * 0.5 + 0.02), ow, false)
				BuildKit.box(w, Vector3(o.y + 0.24, 0.1, 0.05), Vector3(o.x, o.w + 0.06, t * 0.5 + 0.02), ow, false)
				var leaf := PlaceDetail.door(w, Vector3(o.x, 0.0, -t * 0.25), 0.0, o.y - 0.04, o.w - 0.02,
						"steel" if wall_mat == "concrete" else "plank", 25.0 if broken else 65.0, false, "wood_old")
				leaf.name = "DoorLeaf"
				# Schwelle / Stufe davor
				BuildKit.box(w, Vector3(o.y + 0.4, 0.14, 0.4), Vector3(o.x, -0.05, t * 0.5 + 0.2), mat("stone"), true)
			else:
				if broken:
					var ow2 := mat(frame)
					BuildKit.box(w, Vector3(o.y, 0.05, 0.08), Vector3(o.x, o.z, 0), ow2, false)
					BuildKit.box(w, Vector3(o.y, 0.05, 0.08), Vector3(o.x, o.w, 0), ow2, false)
					var shard := BuildKit.glass_mat()
					BuildKit.box(w, Vector3(o.y * 0.3, 0.25, 0.006), Vector3(o.x - o.y * 0.3, o.z + 0.14, 0), shard, false, Vector3(0, 0, 25))
					BuildKit.box(w, Vector3(o.y * 0.2, 0.18, 0.006), Vector3(o.x + o.y * 0.32, o.w - 0.1, 0), shard, false, Vector3(0, 0, -35))
				else:
					PlaceDetail.window(w, Vector3(o.x, o.z, 0.0), 0.0, o.y, o.w - o.z, t, "rect", Color(0.5, 0.56, 0.55, 0.4), frame, 1, false, "wood_old")
	# Eckbretter an Holzhütten
	if wall_mat in ["wood", "wood_old", "wood_h"]:
		var cm := mat("wood_old")
		for sx: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				BuildKit.box(h, Vector3(0.12, height, 0.12), Vector3(sx * (hx + 0.01), height * 0.5, sz * (hz + 0.01)), cm, false)
	# Unkraut und Laub am Sockel (fester Zufall je Hütte)
	var seed_v := int(absf(h.position.x * 31.0 + h.position.z * 17.0)) + 5
	for k in 6:
		var a := k * 1.1 + seed_v
		PlaceDetail.weeds(h, Vector3(clampf(cos(a) * hx * 1.3, -hx - 0.1, hx + 0.1), 0.0, clampf(sin(a) * hz * 1.3, -hz - 0.1, hz + 0.1)), seed_v + k, 5, 0.25)


## Zaun aus Pfosten und Maschendraht zwischen Punkten (lokal, Draufsicht). gap = Öffnungen entlang der Strecke.
static func fence(root: Node3D, pts: Array, height: float = 2.0, gaps: Array = []) -> void:
	var post := mat("metal")
	var mesh := chainlink_mat()
	var dist := 0.0
	for i in pts.size() - 1:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var len := a.distance_to(b)
		var steps := maxi(int(len / 3.0), 1)
		for k in steps:
			var p0 := a.lerp(b, float(k) / steps)
			var p1 := a.lerp(b, float(k + 1) / steps)
			var mid_d := dist + len * (k + 0.5) / steps
			var in_gap := false
			for g: Vector2 in gaps:
				if mid_d > g.x and mid_d < g.y:
					in_gap = true
			var g0 := ground(root, p0.x, p0.y)
			BuildKit.cylinder(root, 0.03, height, Vector3(p0.x, g0 + height * 0.5, p0.y), post, true, Vector3.ZERO, -1.0, 6)
			if in_gap:
				continue
			var g1 := ground(root, p1.x, p1.y)
			var c := (p0 + p1) * 0.5
			var seg := p1 - p0
			var y := (g0 + g1) * 0.5 + height * 0.5
			BuildKit.box(root, Vector3(seg.length(), height * 0.9, 0.02), Vector3(c.x, y, c.y), mesh, true, Vector3(0, -rad_to_deg(atan2(seg.y, seg.x)), 0))
		dist += len


## Maschendraht: Rauten-Textur mit Durchsicht (dreiseitig in Weltkoordinaten, Masche ≈ 5 cm).
static func chainlink_mat() -> StandardMaterial3D:
	if _m.has("_chainlink"):
		return _m["_chainlink"]
	var mesh := StandardMaterial3D.new()
	mesh.albedo_texture = load("res://assets/textures/ground/chainlink.png")
	mesh.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mesh.alpha_scissor_threshold = 0.5
	mesh.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.uv1_triplanar = true
	mesh.uv1_world_triplanar = true
	mesh.uv1_scale = Vector3.ONE / 0.3
	mesh.metallic = 0.6
	mesh.roughness = 0.5
	mesh.texture_filter = Look.tex_filter()
	_m["_chainlink"] = mesh
	return mesh


## Fernwirkung: Sichtweite für alle Teile eines Ortes begrenzen (große Teile weiter sichtbar).
static func limit_visibility(n: Node, near: float = 320.0, far: float = 900.0) -> void:
	for gi in n.find_children("*", "GeometryInstance3D", true, false):
		var g := gi as GeometryInstance3D
		var aabb := g.get_aabb()
		var big := aabb.size.length() > 8.0
		g.visibility_range_end = far if big else near
		g.visibility_range_end_margin = 20.0
		g.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		if not big:
			g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if aabb.size.length() > 1.5 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
