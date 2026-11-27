class_name PlaceDetail
extends RefCounted
## Detail-Baukasten für die Orte (Christian 27.11.: „Lass die Compounds leben!“ – so liebevoll wie die Hütte).
## Fenster, Türen, Dächer mit Überstand, Rinnen, Lampen, Kerzen, Möbel, Kram, Schilder, Kabel, Wellblech, Laub.
## Alles lokal zum übergebenen Elternknoten; Materialien über PlaceKit.mat (im klaren Stil Foto-Texturen).


static func m(kind: String) -> Material:
	return PlaceKit.mat(kind)


static func col(c: Color, rough: float = 0.8, metal: float = 0.0) -> StandardMaterial3D:
	return BuildKit.color_mat(c, rough, metal)


# --- Wände, Öffnungen ---------------------------------------------------------------------

## Bogenfeld über einer rechteckigen Öffnung: füllt die Ecken über dem Halbkreis (Wandebene = lokale x/y,
## Dicke in z). spring = Höhe des Bogenansatzes (Mitte der Unterkante), w = Öffnungsbreite.
static func arch_fill(parent: Node3D, center: Vector3, w: float, thick: float, mat: Material, rot_y: float = 0.0) -> MeshInstance3D:
	var r := w * 0.5
	var pts := PackedVector2Array([Vector2(r, 0), Vector2(r, r + 0.002), Vector2(-r, r + 0.002), Vector2(-r, 0)])
	for i in range(1, 16):
		var a := PI - PI * i / 16.0
		pts.append(Vector2(cos(a) * r, sin(a) * r))
	var mi := HandKit.extrude(parent, pts, thick * 0.5, mat)
	mi.position = center
	mi.rotation_degrees.y = rot_y
	return mi


## Rundbogen- oder Rechteckfenster in einer Öffnung (Mitte Unterkante = pos, Wandebene x/y, außen = +z).
## style "arch" | "rect", glass = Glasfarbe (Butzen/Bleiglas), bars = Sprossen, grille = Eisengitter außen.
static func window(parent: Node3D, pos: Vector3, rot_y: float, w: float, h: float, wall_t: float,
		style: String = "rect", glass := Color(0.55, 0.62, 0.6, 0.45), frame_kind: String = "furn", bars: int = 2,
		grille: bool = false, sill_kind: String = "stone") -> Node3D:
	var n := Node3D.new()
	n.position = pos
	n.rotation_degrees.y = rot_y
	parent.add_child(n)
	var frame := m(frame_kind)
	var gm := BuildKit.glass_mat().duplicate() as StandardMaterial3D
	gm.albedo_color = glass
	var r := w * 0.5
	var rect_h := h - (r if style == "arch" else 0.0)
	var ft := 0.05
	# Rahmen
	BuildKit.box(n, Vector3(w, ft, 0.07), Vector3(0, ft * 0.5, 0), frame, false)
	for sx: float in [-1.0, 1.0]:
		BuildKit.box(n, Vector3(ft, rect_h, 0.07), Vector3(sx * (r - ft * 0.5), rect_h * 0.5, 0), frame, false)
	if style == "arch":
		var arc := HandKit.arc(Vector3(0, rect_h, 0), r - ft * 0.5, 0, 180, 14)
		HandKit.tube(n, arc, ft * 0.5, frame, 6, Vector3(0, 0, 1))
		var g := PackedVector2Array([Vector2(r - ft, 0), Vector2(r - ft, rect_h)])
		for i in range(1, 16):
			var a := PI * i / 16.0
			g.append(Vector2(cos(a) * (r - ft), rect_h + sin(a) * (r - ft)))
		g.append_array([Vector2(-(r - ft), rect_h), Vector2(-(r - ft), 0)])
		HandKit.extrude(n, g, 0.004, gm)
	else:
		BuildKit.box(n, Vector3(w, ft, 0.07), Vector3(0, h - ft * 0.5, 0), frame, false)
		BuildKit.box(n, Vector3(w - ft * 2.0, h - ft * 2.0, 0.008), Vector3(0, h * 0.5, 0), gm, false)
	# Sprossen / Bleiruten
	var lead := col(Color(0.12, 0.12, 0.13), 0.5, 0.6) if style == "arch" else frame
	var bt := 0.012 if style == "arch" else 0.03
	for i in bars:
		var x := -r + w * (i + 1) / (bars + 1)
		BuildKit.box(n, Vector3(bt, rect_h, 0.02), Vector3(x, rect_h * 0.5, 0), lead, false)
	var rows := maxi(int(rect_h / (0.35 if style == "arch" else 0.5)), 1)
	for j in range(1, rows):
		BuildKit.box(n, Vector3(w - ft * 2.0, bt, 0.02), Vector3(0, rect_h * j / rows, 0), lead, false)
	# Fensterbank außen (+z) und innen
	BuildKit.box(n, Vector3(w + 0.12, 0.05, wall_t * 0.5 + 0.08), Vector3(0, -0.025, wall_t * 0.25 + 0.04), m(sill_kind), false, Vector3(-6, 0, 0))
	BuildKit.box(n, Vector3(w + 0.04, 0.03, wall_t * 0.5), Vector3(0, -0.015, -wall_t * 0.25), frame, false)
	if grille:
		var iron := col(Color(0.08, 0.08, 0.09), 0.6, 0.7)
		for i in 4:
			var x := -r + w * (i + 0.5) / 4.0
			var top := rect_h + (sqrt(maxf(r * r - x * x, 0.0)) if style == "arch" else 0.0)
			BuildKit.cylinder(n, 0.008, top, Vector3(x, top * 0.5, wall_t * 0.5 + 0.03), iron, false, Vector3.ZERO, -1.0, 6)
		BuildKit.box(n, Vector3(w, 0.02, 0.012), Vector3(0, rect_h * 0.55, wall_t * 0.5 + 0.03), iron, false)
	return n


## Brettertür mit Rahmen, Querleisten, Beschlägen. open_deg = wie weit offen (Angel links). Ursprung = Mitte unten.
## style "plank" | "arch" (oben rund) | "steel". double = zweiflügelig.
static func door(parent: Node3D, pos: Vector3, rot_y: float, w: float, h: float, style: String = "plank",
		open_deg: float = 0.0, double: bool = false, kind: String = "wood_old") -> Node3D:
	var n := Node3D.new()
	n.position = pos
	n.rotation_degrees.y = rot_y
	parent.add_child(n)
	var leaves := 2 if double else 1
	var lw := w / leaves
	var iron := col(Color(0.1, 0.09, 0.08), 0.6, 0.6)
	var mat := m(kind) if style != "steel" else m("corrugated")
	for k in leaves:
		var hinge := Node3D.new()
		var sx := -1.0 if k == 0 else 1.0
		hinge.position = Vector3(sx * w * 0.5, 0, 0)
		hinge.rotation_degrees.y = -sx * open_deg * (1.0 if k == 0 else 0.7)
		n.add_child(hinge)
		var cx := -sx * lw * 0.5
		var lh := h
		if style == "arch":
			lh = h - w * 0.5
		BuildKit.box(hinge, Vector3(lw - 0.01, lh, 0.05), Vector3(cx, lh * 0.5, 0), mat, false)
		if style == "arch":
			# Bogenstück des Flügels: Viertelkreis (zweiflügelig) bzw. Halbkreis (einflügelig)
			var r := w * 0.5
			var q := PackedVector2Array([Vector2(0, 0)])
			var from := 0.0 if (k == 1 or leaves == 1) else 90.0
			var to := 180.0 if (k == 0 or leaves == 1) else 90.0
			if leaves == 2 and k == 1:
				to = 90.0
			for i in 13:
				var a := deg_to_rad(lerpf(from, to, i / 12.0))
				q.append(Vector2(cos(a) * r, sin(a) * r))
			if leaves == 1:
				q.remove_at(0)
			var piece := HandKit.extrude(hinge, q, 0.025, mat)
			piece.position = Vector3(cx if leaves == 1 else cx * 2.0, lh, 0)
		if style != "steel":
			for yy: float in [0.25, lh - 0.3]:
				BuildKit.box(hinge, Vector3(lw - 0.06, 0.1, 0.03), Vector3(cx, yy, 0.035), mat, false)
			# Bänder (lange Eisenbeschläge) und Griff
			for yy: float in [0.3, lh - 0.35]:
				BuildKit.box(hinge, Vector3(lw * 0.6, 0.035, 0.01), Vector3(-sx * lw * 0.3, yy, 0.055), iron, false)
		BuildKit.cylinder(hinge, 0.018, 0.12, Vector3(-sx * (lw - 0.1), 1.0, 0.06), iron, false, Vector3(0, 0, 90), -1.0, 6)
		BuildKit.box(hinge, Vector3(0.05, 0.12, 0.01), Vector3(-sx * (lw - 0.1), 1.0, 0.03), iron, false)
		if style == "steel":
			BuildKit.box(hinge, Vector3(lw - 0.01, h, 0.045), Vector3(cx, h * 0.5, -0.004), m("steel_dark"), false)
	return n


## Dachfläche (rechteckige Platte mit Überstand) + Stirnbrett. Für Satteldächer zweimal aufrufen.
static func roof_plane(parent: Node3D, center: Vector3, size: Vector2, angle_deg: float, rot_y: float,
		kind: String = "shingles", thick: float = 0.12, fascia := true) -> MeshInstance3D:
	var mi := BuildKit.box(parent, Vector3(size.x, thick, size.y), center, m(kind), true, Vector3(0, rot_y, angle_deg))
	if fascia:
		var dir := Vector3(cos(deg_to_rad(angle_deg)), sin(deg_to_rad(angle_deg)), 0).rotated(Vector3.UP, deg_to_rad(rot_y))
		var lower := center - dir * size.x * 0.5
		BuildKit.box(parent, Vector3(0.04, 0.18, size.y + 0.02), lower + Vector3(0, -0.06, 0), m("wood_old"), false, Vector3(0, rot_y, 0))
	return mi


## Dachrinne mit Fallrohr entlang einer Traufe (von a nach b, lokal), Fallrohr am Ende b bis zum Boden y=ground.
## back = Versatz vom Rinnenende zur Hauswand (das Fallrohr läuft an der Wand hinunter).
static func gutter(parent: Node3D, a: Vector3, b: Vector3, ground_y: float, kind: String = "rust", back := Vector3.ZERO) -> void:
	var mat := m(kind)
	var pts := PackedVector3Array([a, b])
	HandKit.tube(parent, pts, 0.055, mat, 8)
	var w := b + back
	var down := PackedVector3Array([b, b + Vector3(0, -0.12, 0), w + Vector3(0, -0.45, 0), Vector3(w.x, ground_y + 0.25, w.z),
			Vector3(w.x, ground_y + 0.06, w.z) + Vector3(back.x, 0, back.z).normalized() * -0.2])
	HandKit.tube(parent, down, 0.04, mat, 8)


# --- Licht -------------------------------------------------------------------------------

## Kerze (optional brennend: kleine Flamme + schwaches Licht ohne Schatten).
static func candle(parent: Node3D, pos: Vector3, h: float = 0.16, lit: bool = false, light: bool = false, r: float = 0.018) -> void:
	BuildKit.cylinder(parent, r, h, pos + Vector3(0, h * 0.5, 0), col(Color(0.93, 0.9, 0.8), 0.6), false, Vector3.ZERO, -1.0, 8)
	if lit:
		var f := BuildKit.emissive_mat(Color(1.0, 0.7, 0.3), 4.0)
		BuildKit.sphere(parent, 0.008, pos + Vector3(0, h + 0.012, 0), f, Vector3(1, 2.2, 1), 6)
		if light:
			var l := OmniLight3D.new()
			l.light_color = Color(1.0, 0.72, 0.45)
			l.light_energy = 0.45
			l.omni_range = 3.5
			l.shadow_enabled = false
			l.position = pos + Vector3(0, h + 0.08, 0)
			parent.add_child(l)


## Grablicht/Opferlicht im roten Glas.
static func votive(parent: Node3D, pos: Vector3, lit: bool = true, color := Color(0.75, 0.08, 0.06)) -> void:
	var g := BuildKit.glass_mat().duplicate() as StandardMaterial3D
	g.albedo_color = Color(color.r, color.g, color.b, 0.7)
	if lit:
		g.emission_enabled = true
		g.emission = color
		g.emission_energy_multiplier = 0.9
	BuildKit.cylinder(parent, 0.035, 0.1, pos + Vector3(0, 0.05, 0), g, false, Vector3.ZERO, 0.03, 10)
	BuildKit.cylinder(parent, 0.036, 0.012, pos + Vector3(0, 0.106, 0), col(Color(0.7, 0.62, 0.3), 0.4, 0.8), false, Vector3.ZERO, -1.0, 10)


## Wandlampe / Hängelampe / Mastleuchte. on = leuchtet.
static func lamp(parent: Node3D, pos: Vector3, style: String = "wall", on: bool = false, rot_y: float = 0.0,
		color := Color(1.0, 0.85, 0.6), energy: float = 1.2, range_m: float = 7.0) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	n.rotation_degrees.y = rot_y
	parent.add_child(n)
	var metal := col(Color(0.15, 0.16, 0.15), 0.5, 0.6)
	var bulb := BuildKit.emissive_mat(color, 3.0 if on else 0.0)
	match style:
		"wall":
			BuildKit.box(n, Vector3(0.12, 0.18, 0.04), Vector3(0, 0, 0.02), metal, false)
			BuildKit.box(n, Vector3(0.03, 0.03, 0.25), Vector3(0, 0.05, 0.14), metal, false)
			BuildKit.cylinder(n, 0.13, 0.08, Vector3(0, 0.02, 0.28), metal, false, Vector3.ZERO, 0.05, 12)
			BuildKit.sphere(n, 0.045, Vector3(0, -0.02, 0.28), bulb, Vector3.ONE, 8)
		"cage":
			BuildKit.cylinder(n, 0.07, 0.14, Vector3(0, 0, 0.09), bulb, false, Vector3(90, 0, 0), -1.0, 10)
			for k in 4:
				BuildKit.box(n, Vector3(0.008, 0.008, 0.16), Vector3(cos(k * PI / 2) * 0.075, sin(k * PI / 2) * 0.075, 0.09), metal, false)
			BuildKit.box(n, Vector3(0.18, 0.18, 0.03), Vector3(0, 0, 0.01), metal, false)
		"flood":
			BuildKit.box(n, Vector3(0.36, 0.26, 0.12), Vector3(0, 0, 0.1), metal, false, Vector3(-25, 0, 0))
			BuildKit.box(n, Vector3(0.3, 0.2, 0.01), Vector3(0, -0.03, 0.17), bulb, false, Vector3(-25, 0, 0))
		"hanging":
			BuildKit.cylinder(n, 0.006, 0.6, Vector3(0, 0.3, 0), metal, false, Vector3.ZERO, -1.0, 4)
			BuildKit.cylinder(n, 0.22, 0.14, Vector3(0, -0.04, 0), metal, false, Vector3.ZERO, 0.06, 14)
			BuildKit.sphere(n, 0.05, Vector3(0, -0.1, 0), bulb, Vector3.ONE, 8)
	if on:
		var l: Light3D = OmniLight3D.new() if style != "flood" else SpotLight3D.new()
		l.light_color = color
		l.light_energy = energy
		if l is OmniLight3D:
			(l as OmniLight3D).omni_range = range_m
		else:
			(l as SpotLight3D).spot_range = range_m
			(l as SpotLight3D).spot_angle = 50.0
			l.rotation_degrees.x = -30.0
		l.shadow_enabled = false
		l.position = Vector3(0, -0.12, 0.3)
		n.add_child(l)
	return n


# --- Möbel --------------------------------------------------------------------------------

## Kirchenbank mit Kniebank und geschnitzten Wangen. Ursprung = Mitte am Boden, Blick nach -z (Lehne bei +z).
static func pew(parent: Node3D, pos: Vector3, length: float, kind: String = "furn") -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	var mt := m(kind)
	BuildKit.box(n, Vector3(length, 0.05, 0.38), Vector3(0, 0.45, 0.02), mt, true)
	BuildKit.box(n, Vector3(length, 0.42, 0.04), Vector3(0, 0.72, 0.22), mt, false, Vector3(-8, 0, 0))
	BuildKit.box(n, Vector3(length, 0.06, 0.06), Vector3(0, 0.95, 0.25), mt, false)
	# Kniebank und Buchablage für die Reihe dahinter
	BuildKit.box(n, Vector3(length - 0.1, 0.06, 0.14), Vector3(0, 0.12, 0.42), mt, false)
	BuildKit.box(n, Vector3(length - 0.06, 0.03, 0.18), Vector3(0, 0.82, 0.33), mt, false)
	for sx: float in [-1.0, 1.0]:
		var wange := PackedVector2Array([Vector2(-0.22, 0), Vector2(0.3, 0), Vector2(0.3, 0.98), Vector2(0.22, 1.04),
				Vector2(0.12, 0.98), Vector2(0.08, 0.6), Vector2(-0.18, 0.5), Vector2(-0.24, 0.42)])
		var w := HandKit.extrude(n, wange, 0.03, mt)
		w.position = Vector3(sx * length * 0.5, 0, 0.02)
		w.rotation_degrees.y = -90.0
	return n


static func table(parent: Node3D, pos: Vector3, size: Vector3, kind: String = "table", rot_y: float = 0.0) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	n.rotation_degrees.y = rot_y
	parent.add_child(n)
	var mt := m(kind)
	BuildKit.box(n, Vector3(size.x, 0.04, size.z), Vector3(0, size.y - 0.02, 0), mt, true)
	BuildKit.box(n, Vector3(size.x - 0.12, 0.08, size.z - 0.12), Vector3(0, size.y - 0.08, 0), mt, false)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			BuildKit.box(n, Vector3(0.05, size.y - 0.04, 0.05), Vector3(sx * (size.x * 0.5 - 0.06), (size.y - 0.04) * 0.5, sz * (size.z * 0.5 - 0.06)), mt, false)
	return n


static func chair(parent: Node3D, pos: Vector3, rot_y: float, kind: String = "furn", tipped: bool = false) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	n.rotation_degrees.y = rot_y
	if tipped:
		n.rotation_degrees.x = -86.0
		n.position.y += 0.22
	parent.add_child(n)
	var mt := m(kind)
	BuildKit.box(n, Vector3(0.42, 0.04, 0.42), Vector3(0, 0.45, 0), mt, false)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			BuildKit.box(n, Vector3(0.035, 0.45, 0.035), Vector3(sx * 0.18, 0.225, sz * 0.18), mt, false)
		BuildKit.box(n, Vector3(0.035, 0.5, 0.035), Vector3(sx * 0.18, 0.7, 0.19), mt, false)
	for yy: float in [0.62, 0.86]:
		BuildKit.box(n, Vector3(0.36, 0.06, 0.02), Vector3(0, yy, 0.19), mt, false)
	return n


## Bürostuhl (Stahlrohr, Polster) – für Container und Büros.
static func office_chair(parent: Node3D, pos: Vector3, rot_y: float) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	n.rotation_degrees.y = rot_y
	parent.add_child(n)
	var pad := col(Color(0.12, 0.13, 0.15), 0.9)
	var steel := col(Color(0.3, 0.3, 0.32), 0.4, 0.8)
	for k in 5:
		var a := TAU * k / 5.0
		BuildKit.box(n, Vector3(0.03, 0.03, 0.3), Vector3(cos(a) * 0.14, 0.06, sin(a) * 0.14), steel, false, Vector3(0, -rad_to_deg(a) + 90.0, 0))
		BuildKit.sphere(n, 0.025, Vector3(cos(a) * 0.28, 0.025, sin(a) * 0.28), pad, Vector3.ONE, 6)
	BuildKit.cylinder(n, 0.025, 0.36, Vector3(0, 0.24, 0), steel, false, Vector3.ZERO, -1.0, 8)
	BuildKit.box(n, Vector3(0.46, 0.08, 0.44), Vector3(0, 0.46, 0), pad, false)
	BuildKit.box(n, Vector3(0.44, 0.5, 0.07), Vector3(0, 0.8, 0.22), pad, false, Vector3(-8, 0, 0))
	return n


## Regal (Bretter + Seiten). Ursprung = Mitte unten an der Rückwand, Bretter nach +z.
static func shelf(parent: Node3D, pos: Vector3, rot_y: float, size: Vector3, boards: int = 4, kind: String = "furn") -> Node3D:
	var n := Node3D.new()
	n.position = pos
	n.rotation_degrees.y = rot_y
	parent.add_child(n)
	var mt := m(kind)
	for sx: float in [-1.0, 1.0]:
		BuildKit.box(n, Vector3(0.03, size.y, size.z), Vector3(sx * size.x * 0.5, size.y * 0.5, size.z * 0.5), mt, false)
	for i in boards:
		var y := 0.06 + (size.y - 0.08) * i / maxf(boards - 1, 1)
		BuildKit.box(n, Vector3(size.x, 0.025, size.z), Vector3(0, y, size.z * 0.5), mt, i == 0)
	return n


## Allerlei Kram auf einer Fläche (Bücher, Dosen, Flaschen, Kisten, Papier) – Zufall mit festem Startwert.
## area = Breite x Tiefe, kinds = Auswahl ("books", "jars", "cans", "bottles", "boxes", "tools", "papers", "binders").
static func clutter(parent: Node3D, pos: Vector3, area: Vector2, seed_v: int, count: int = 6, kinds := ["books", "jars", "boxes"]) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var x := -area.x * 0.5
	for i in count:
		if x > area.x * 0.5 - 0.05:
			break
		var k := String(kinds[rng.randi() % kinds.size()])
		var z := rng.randf_range(-area.y * 0.25, area.y * 0.25)
		match k:
			"books":
				var nb := rng.randi_range(3, 7)
				for b in nb:
					var bw := rng.randf_range(0.025, 0.05)
					var bh := rng.randf_range(0.17, 0.26)
					var c := Color.from_hsv(rng.randf(), rng.randf_range(0.3, 0.6), rng.randf_range(0.25, 0.55))
					var lean := 0.0 if b < nb - 1 else rng.randf_range(0.0, 18.0)
					BuildKit.box(parent, Vector3(bw, bh, rng.randf_range(0.14, 0.2)), pos + Vector3(x + bw * 0.5, bh * 0.5, z), col(c, 0.8), false, Vector3(0, 0, -lean))
					x += bw + 0.002
			"binders":
				for b in rng.randi_range(3, 6):
					var c2 := [Color(0.15, 0.2, 0.45), Color(0.5, 0.1, 0.08), Color(0.2, 0.2, 0.22), Color(0.6, 0.55, 0.2)][rng.randi() % 4] as Color
					BuildKit.box(parent, Vector3(0.07, 0.31, 0.28), pos + Vector3(x + 0.035, 0.155, z), col(c2, 0.6), false)
					BuildKit.box(parent, Vector3(0.002, 0.08, 0.05), pos + Vector3(x + 0.035, 0.2, z + 0.141), col(Color(0.9, 0.9, 0.85)), false)
					x += 0.072
			"jars":
				for b in rng.randi_range(2, 4):
					var c3 := Color.from_hsv(rng.randf_range(0.02, 0.12), 0.7, rng.randf_range(0.3, 0.7))
					BuildKit.cylinder(parent, 0.045, 0.13, pos + Vector3(x + 0.045, 0.065, z), col(c3, 0.25), false, Vector3.ZERO, -1.0, 10)
					BuildKit.cylinder(parent, 0.046, 0.02, pos + Vector3(x + 0.045, 0.14, z), m("metal"), false, Vector3.ZERO, -1.0, 10)
					x += 0.1
			"cans":
				for b in rng.randi_range(2, 4):
					Icons.food_can(parent, pos + Vector3(x + 0.045, 0, z), 0.042, 0.11)
					x += 0.095
			"bottles":
				for b in rng.randi_range(2, 4):
					var bm := BuildKit.lathe(parent, PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.95, 0.0), Vector2(1.0, 0.05), Vector2(1.0, 0.62),
							Vector2(0.45, 0.82), Vector2(0.35, 1.0), Vector2(0.0, 1.0)]), pos + Vector3(x + 0.04, 0, z),
							col(Color(0.2, 0.32, 0.18) if rng.randf() < 0.6 else Color(0.35, 0.22, 0.1), 0.15), 10)
					bm.scale = Vector3(0.035, rng.randf_range(0.22, 0.3), 0.035)
					x += 0.085
			"boxes":
				var bs := Vector3(rng.randf_range(0.18, 0.32), rng.randf_range(0.1, 0.22), rng.randf_range(0.15, 0.25))
				BuildKit.box(parent, bs, pos + Vector3(x + bs.x * 0.5, bs.y * 0.5, z), BuildKit.tex_mat("fabric", 0.3, Color(1.35, 1.12, 0.8)), false, Vector3(0, rng.randf_range(-8, 8), 0))
				x += bs.x + 0.02
			"tools":
				BuildKit.box(parent, Vector3(0.22, 0.03, 0.04), pos + Vector3(x + 0.11, 0.015, z), col(Color(0.5, 0.15, 0.1), 0.6), false, Vector3(0, rng.randf_range(-30, 30), 0))
				BuildKit.box(parent, Vector3(0.12, 0.02, 0.02), pos + Vector3(x + 0.11, 0.035, z + 0.05), m("metal"), false, Vector3(0, rng.randf_range(-30, 30), 0))
				x += 0.25
			"papers":
				for b in rng.randi_range(1, 3):
					BuildKit.box(parent, Vector3(0.21, 0.003, 0.297), pos + Vector3(x + 0.1, 0.002 + b * 0.003, z), m("paper"), false, Vector3(0, rng.randf_range(-25, 25), 0))
				x += 0.24
		x += rng.randf_range(0.02, 0.08)


## Holzkiste (stapelbar), Fass, Palette, Eimer.
static func crate(parent: Node3D, pos: Vector3, size: Vector3 = Vector3(0.6, 0.45, 0.45), rot_y: float = 0.0, collide := true) -> void:
	var n := Node3D.new()
	n.position = pos
	n.rotation_degrees.y = rot_y
	parent.add_child(n)
	BuildKit.box(n, size - Vector3(0.02, 0.02, 0.02), Vector3(0, size.y * 0.5, 0), m("wood"), collide)
	for sx: float in [-1.0, 1.0]:
		BuildKit.box(n, Vector3(0.03, size.y, size.z + 0.01), Vector3(sx * (size.x * 0.5 - 0.015), size.y * 0.5, 0), m("wood_old"), false)
	BuildKit.box(n, Vector3(size.x + 0.01, 0.05, 0.03), Vector3(0, size.y * 0.5, size.z * 0.5), m("wood_old"), false, Vector3(0, 0, rad_to_deg(atan2(size.y, size.x)) * 0.8))


static func barrel(parent: Node3D, pos: Vector3, kind: String = "rust", tipped: bool = false, rot_y: float = 0.0) -> void:
	var n := Node3D.new()
	n.position = pos
	n.rotation_degrees = Vector3(0, rot_y, 90.0 if tipped else 0.0)
	if tipped:
		n.position.y += 0.29
	parent.add_child(n)
	var mt := m(kind)
	BuildKit.cylinder(n, 0.29, 0.88, Vector3(0, 0.44, 0), mt, true, Vector3.ZERO, -1.0, 16)
	for yy: float in [0.12, 0.44, 0.76]:
		BuildKit.cylinder(n, 0.3, 0.035, Vector3(0, yy, 0), mt, false, Vector3.ZERO, -1.0, 16)
	BuildKit.cylinder(n, 0.03, 0.02, Vector3(0.15, 0.885, 0.05), col(Color(0.1, 0.1, 0.1)), false, Vector3.ZERO, -1.0, 6)


static func pallet(parent: Node3D, pos: Vector3, rot_y: float = 0.0, leaning: bool = false) -> void:
	var n := Node3D.new()
	n.position = pos
	n.rotation_degrees = Vector3(-78.0 if leaning else 0.0, rot_y, 0)
	if leaning:
		n.position.y += 0.05
	parent.add_child(n)
	var mt := m("wood_old")
	for i in 5:
		BuildKit.box(n, Vector3(1.2, 0.022, 0.1), Vector3(0, 0.13, -0.4 + i * 0.2), mt, false)
	for sx: float in [-0.55, 0.0, 0.55]:
		BuildKit.box(n, Vector3(0.1, 0.1, 1.0), Vector3(sx, 0.06, 0), mt, false)


static func bucket(parent: Node3D, pos: Vector3, kind: String = "metal", tipped := false) -> void:
	var n := Node3D.new()
	n.position = pos
	if tipped:
		n.rotation_degrees.z = 95.0
		n.position.y += 0.13
	parent.add_child(n)
	var mt := m(kind)
	var b := BuildKit.lathe(n, PackedVector2Array([Vector2(0, 0.0), Vector2(0.11, 0.0), Vector2(0.14, 0.27), Vector2(0.135, 0.27), Vector2(0.105, 0.012), Vector2(0, 0.012)]), Vector3.ZERO, mt, 12)
	var g := (mt as StandardMaterial3D)
	if g:
		b.material_override = g
	HandKit.tube(n, HandKit.arc(Vector3(0, 0.27, 0), 0.135, 0, 180, 8, Vector3.RIGHT, Vector3(0, 0.6, 0.8)), 0.004, col(Color(0.2, 0.2, 0.2), 0.5, 0.7), 4)


# --- Schilder, Bilder, Kleinkram ---------------------------------------------------------

## Schild / Tafel mit Text (Vorderseite +z). bg = Grundfarbe, fg = Schriftfarbe.
static func sign(parent: Node3D, text: String, pos: Vector3, size: Vector2, rot_y: float = 0.0,
		bg := Color(0.9, 0.88, 0.8), fg := Color(0.08, 0.08, 0.08), font: int = 32, border := true) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	n.rotation_degrees.y = rot_y
	parent.add_child(n)
	BuildKit.box(n, Vector3(size.x, size.y, 0.015), Vector3.ZERO, col(bg, 0.6, 0.2), false)
	if border:
		BuildKit.box(n, Vector3(size.x + 0.02, size.y + 0.02, 0.008), Vector3(0, 0, -0.006), col(fg.lerp(bg, 0.3), 0.6), false)
	var l := Label3D.new()
	l.text = text
	l.font_size = font
	l.pixel_size = 0.0022 * size.y / 0.3 * 0.7 if font > 0 else 0.002
	l.modulate = fg
	l.outline_size = 0
	l.width = size.x / l.pixel_size * 0.92
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.position = Vector3(0, 0, 0.009)
	n.add_child(l)
	return n


## Gerahmtes Bild an der Wand (Vorderseite +z). paint = Farben (Himmel/Grund) für ein angedeutetes Motiv.
static func picture(parent: Node3D, pos: Vector3, size: Vector2, rot_y: float = 0.0, frame := Color(0.55, 0.42, 0.18),
		paint: Array = [Color(0.25, 0.3, 0.35), Color(0.3, 0.25, 0.18)], gilded := false) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	n.rotation_degrees.y = rot_y
	parent.add_child(n)
	var fm := col(frame, 0.35 if gilded else 0.7, 0.8 if gilded else 0.0)
	var fw := maxf(size.x, size.y) * 0.07
	BuildKit.box(n, Vector3(size.x, fw, 0.03), Vector3(0, size.y * 0.5 - fw * 0.5, 0), fm, false)
	BuildKit.box(n, Vector3(size.x, fw, 0.03), Vector3(0, -size.y * 0.5 + fw * 0.5, 0), fm, false)
	for sx: float in [-1.0, 1.0]:
		BuildKit.box(n, Vector3(fw, size.y, 0.03), Vector3(sx * (size.x * 0.5 - fw * 0.5), 0, 0), fm, false)
	var inner := size - Vector2(fw * 2.0, fw * 2.0)
	BuildKit.box(n, Vector3(inner.x, inner.y * 0.55, 0.006), Vector3(0, inner.y * 0.225, 0), col(paint[0], 0.9), false)
	BuildKit.box(n, Vector3(inner.x, inner.y * 0.45, 0.006), Vector3(0, -inner.y * 0.275, 0), col(paint[1], 0.9), false)
	return n


## Herumliegende Blätter, Zweige, Papier am Boden (flache Teile, keine Kollision).
static func litter(parent: Node3D, center: Vector3, radius: float, seed_v: int, count: int = 20, kinds := ["leaf", "twig"], ground: Callable = Callable()) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var leaf_cols := [Color(0.45, 0.28, 0.12), Color(0.55, 0.38, 0.15), Color(0.35, 0.22, 0.1), Color(0.5, 0.42, 0.25)]
	for i in count:
		var a := rng.randf() * TAU
		var d := sqrt(rng.randf()) * radius
		var p := center + Vector3(cos(a) * d, 0, sin(a) * d)
		if ground.is_valid():
			p.y = float(ground.call(p.x, p.z))
		var k := String(kinds[rng.randi() % kinds.size()])
		match k:
			"leaf":
				BuildKit.box(parent, Vector3(0.06, 0.003, 0.08), p + Vector3(0, 0.004, 0), col(leaf_cols[rng.randi() % 4], 0.9), false, Vector3(rng.randf_range(-10, 10), rng.randf() * 360.0, 0))
			"twig":
				BuildKit.cylinder(parent, 0.008, rng.randf_range(0.2, 0.5), p + Vector3(0, 0.01, 0), m("bark"), false, Vector3(90, rng.randf() * 360.0, 0), 0.004, 5)
			"paper":
				BuildKit.box(parent, Vector3(0.21, 0.002, 0.297), p + Vector3(0, 0.003, 0), m("paper"), false, Vector3(rng.randf_range(-6, 6), rng.randf() * 360.0, 0))
			"stone":
				BuildKit.sphere(parent, rng.randf_range(0.05, 0.14), p, m("stone"), Vector3(1.2, 0.6, 1.0), 6)


## Spinnweben in einer Raumecke (halbdurchsichtige Dreiecke).
static func cobweb(parent: Node3D, corner: Vector3, dir_a: Vector3, dir_b: Vector3, size: float = 0.35) -> void:
	var mat := BuildKit.color_mat(Color(0.85, 0.85, 0.85, 0.18), 1.0)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var a := corner
	var b := corner + dir_a * size
	var c := corner + dir_b * size
	var d := corner + (dir_a + dir_b) * size * 0.35 + Vector3(0, -0.04, 0)
	for t in [[a, b, d], [a, d, c]]:
		for v: Vector3 in t:
			st.set_normal(Vector3.UP)
			st.add_vertex(v)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	parent.add_child(mi)


## Durchhängendes Kabel zwischen zwei Punkten.
static func cable(parent: Node3D, a: Vector3, b: Vector3, sag: float = 0.3, r: float = 0.012, c := Color(0.06, 0.06, 0.06)) -> void:
	var pts := PackedVector3Array()
	for i in 13:
		var t := i / 12.0
		pts.append(a.lerp(b, t) + Vector3(0, -sag * 4.0 * t * (1.0 - t), 0))
	HandKit.tube(parent, pts, r, col(c, 0.6), 5)


## Wellblechtafel (echte Wellen im Netz). Ursprung = Mitte, Wellen laufen entlang x, Fläche in x/y, Dicke z.
static func corrugated(parent: Node3D, size: Vector2, pos: Vector3, rot := Vector3.ZERO, kind: String = "corrugated", depth: float = 0.018, collide := false) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var waves := int(size.x / 0.076)
	var steps := waves * 6
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	for i in steps:
		var x0 := -hx + size.x * i / steps
		var x1 := -hx + size.x * (i + 1) / steps
		var z0 := sin(TAU * waves * i / steps) * depth
		var z1 := sin(TAU * waves * (i + 1) / steps) * depth
		var n0 := Vector3(-cos(TAU * waves * i / steps) * depth * TAU * waves / size.x, 0, 1).normalized()
		var n1 := Vector3(-cos(TAU * waves * (i + 1) / steps) * depth * TAU * waves / size.x, 0, 1).normalized()
		for face: float in [1.0, -1.0]:
			var q := [Vector3(x0, -hy, z0), Vector3(x1, -hy, z1), Vector3(x1, hy, z1), Vector3(x0, hy, z0)]
			var nn := [n0 * face, n1 * face, n1 * face, n0 * face]
			var order := [0, 2, 1, 0, 3, 2] if face > 0.0 else [0, 1, 2, 0, 2, 3]
			for o: int in order:
				st.set_normal(nn[o])
				st.add_vertex(q[o])
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = m(kind)
	mi.position = pos
	mi.rotation_degrees = rot
	parent.add_child(mi)
	if collide:
		var shape := BoxShape3D.new()
		shape.size = Vector3(size.x, size.y, depth * 2.0 + 0.02)
		BuildKit._attach_collider(mi, shape)
	return mi


## Einfacher Busch/Grasbüschel an Hauswänden (dunkelgrün, ohne Kollision).
static func weeds(parent: Node3D, pos: Vector3, seed_v: int, count: int = 5, spread: float = 0.4) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	for i in count:
		var p := pos + Vector3(rng.randf_range(-spread, spread), 0, rng.randf_range(-spread, spread))
		var h := rng.randf_range(0.15, 0.45)
		var c := Color(0.32, 0.3, 0.16).lerp(Color(0.5, 0.42, 0.22), rng.randf())   # Spätherbst: strohig
		BuildKit.cylinder(parent, 0.004, h, p + Vector3(0, h * 0.5, 0), col(c, 1.0), false, Vector3(rng.randf_range(-20, 20), 0, rng.randf_range(-20, 20)), 0.001, 3)
