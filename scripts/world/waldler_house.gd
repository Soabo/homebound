class_name WaldlerHouse
extends RefCounted
## Etappe 5 (Christian 24.11.): Die Hütte als Waldlerhaus aus dem Bayerischen Wald.
## Kachelofen in der Stube (statt Steinkamin, mit Ofenbank und Ofenstange), Herrgottswinkel über dem
## Schreibtisch, Drudenfuß über der Haustür und an Bens Bett, Gred aus Granitplatten vor dem Haus.
## Das Feuer selbst (Holz, Wärme, Kochen) bleibt der Knoten Cabin/Fireplace.

## Kachelofen: Vorderseite, Breite (z), Höhen
const OVEN_FRONT := -5.0
const OVEN_Z0 := 0.85
const OVEN_Z1 := 2.65
const OVEN_BODY_H := 1.5
const OVEN_TOP_H := 2.05
## Schürloch (Feueröffnung)
const MOUTH_Z0 := 1.3
const MOUTH_Z1 := 2.2
const MOUTH_H := 0.8
const TILE := 0.2
## Ofenbank reicht von der Wand bis hier (x)
const BANK_X := -5.3

## Herrgottswinkel: Ecke Vorderwand/Werkstattwand in der Stube
const CORNER := Vector2(1.925 - 0.012, 4.36 - 0.012)


static func _glaze(tone: float) -> StandardMaterial3D:
	var m := BuildKit.color_mat(Color(0.15 * tone, 0.32 * tone, 0.23 * tone), 0.22, 0.05)
	return m


## Kachelofen mit Schürloch (Türen offen), Gesims, Aufsatz, Ofenbank, Ofenstange.
static func kachelofen(c: Cabin) -> void:
	var y := Cabin.FLOOR_Y
	var wx := -Cabin.HALF_X + Cabin.CLAD
	var fx := OVEN_FRONT
	var oven := Node3D.new()
	oven.name = "Kachelofen"
	c.add_child(oven)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1849
	var glazes: Array[StandardMaterial3D] = []
	for t: float in [0.82, 0.92, 1.0, 1.1, 1.2]:
		glazes.append(_glaze(t))
	var dark := _glaze(0.55)
	var grout := BuildKit.color_mat(Color(0.72, 0.7, 0.64), 0.9)
	# Sockel aus Granit
	BuildKit.box_mm(oven, Vector3(wx, y, OVEN_Z0 - 0.04), Vector3(fx + 0.05, y + 0.12, OVEN_Z1 + 0.04), c.m_stone_dark, true, "OvenPlinth")
	# Körper (fest) in Stücken um das Schürloch – vor der Öffnung darf nichts den Blick aufs Feuer verstellen
	var top := y + OVEN_BODY_H
	BuildKit.box_mm(oven, Vector3(wx, y + 0.12, OVEN_Z0), Vector3(fx, top, MOUTH_Z0), grout, true)
	BuildKit.box_mm(oven, Vector3(wx, y + 0.12, MOUTH_Z1), Vector3(fx, top, OVEN_Z1), grout, true)
	BuildKit.box_mm(oven, Vector3(wx, y + MOUTH_H, MOUTH_Z0), Vector3(fx, top, MOUTH_Z1), grout, true)
	# Feuerraum: Schamotte, Ruß
	BuildKit.box_mm(oven, Vector3(wx, y + 0.12, MOUTH_Z0), Vector3(wx + 0.06, y + MOUTH_H, MOUTH_Z1), BuildKit.color_mat(Color(0.32, 0.2, 0.15)), false)
	BuildKit.box_mm(oven, Vector3(wx + 0.06, y + MOUTH_H - 0.12, MOUTH_Z0), Vector3(fx - 0.02, y + MOUTH_H, MOUTH_Z1), BuildKit.color_mat(Color(0.04, 0.035, 0.03)), false)
	# Kacheln vorn und an beiden Seiten (am Ende zu einem Netz zusammengefasst)
	var tiles := Node3D.new()
	tiles.name = "Tiles"
	oven.add_child(tiles)
	var rows := int(round((OVEN_BODY_H - 0.14) / TILE))
	var cols := int(round((OVEN_Z1 - OVEN_Z0) / TILE))
	for r in rows:
		var ty := y + 0.14 + (r + 0.5) * TILE
		for k in cols:
			var tz := OVEN_Z0 + (k + 0.5) * (OVEN_Z1 - OVEN_Z0) / cols
			if tz > MOUTH_Z0 - 0.02 and tz < MOUTH_Z1 + 0.02 and ty < y + MOUTH_H + 0.02:
				continue
			_tile(tiles, Vector3(fx + 0.018, ty, tz), Vector3(0.036, TILE - 0.014, (OVEN_Z1 - OVEN_Z0) / cols - 0.014), glazes[rng.randi() % glazes.size()], 0)
		var depth := fx - wx
		var dcols := int(round(depth / TILE))
		for k in dcols:
			var tx := wx + (k + 0.5) * depth / dcols
			for sz: float in [OVEN_Z0 - 0.018, OVEN_Z1 + 0.018]:
				_tile(tiles, Vector3(tx, ty, sz), Vector3(depth / dcols - 0.014, TILE - 0.014, 0.036), glazes[rng.randi() % glazes.size()], 2)
	# Gesims (Ablage) und Aufsatz
	BuildKit.box_mm(oven, Vector3(wx, top, OVEN_Z0 - 0.07), Vector3(fx + 0.08, top + 0.1, OVEN_Z1 + 0.07), dark, true, "OvenLedge")
	var ax := fx - 0.15
	var az0 := OVEN_Z0 + 0.18
	var az1 := OVEN_Z1 - 0.18
	var atop := y + OVEN_TOP_H
	BuildKit.box_mm(oven, Vector3(wx, top + 0.1, az0), Vector3(ax, atop, az1), grout, true)
	var acols := int(round((az1 - az0) / TILE))
	var arows := int(round((atop - top - 0.1) / TILE))
	for r in arows:
		for k in acols:
			_tile(tiles, Vector3(ax + 0.018, top + 0.1 + (r + 0.5) * (atop - top - 0.1) / arows, az0 + (k + 0.5) * (az1 - az0) / acols),
					Vector3(0.036, (atop - top - 0.1) / arows - 0.014, (az1 - az0) / acols - 0.014), glazes[rng.randi() % glazes.size()], 0)
	BuildKit.box_mm(oven, Vector3(wx, atop, az0 - 0.05), Vector3(ax + 0.06, atop + 0.07, az1 + 0.05), dark, false)
	# Rauchrohr bis zur Decke, weiß gekalkt
	var lime := BuildKit.tex_mat("stone", 0.6, Color(1.7, 1.66, 1.58))
	BuildKit.box_mm(oven, Vector3(wx, atop + 0.07, 1.25), Vector3(-5.45, Cabin.WALL_TOP, 2.25), lime, true)
	# Schürloch: gusseiserner Rahmen, zwei offene Türchen
	var iron := BuildKit.tex_mat("metal", 0.4, Color(0.3, 0.29, 0.28), 0.6)
	var fz := fx + 0.04
	BuildKit.box_mm(oven, Vector3(fx, y + 0.1, MOUTH_Z0 - 0.06), Vector3(fz, y + 0.16, MOUTH_Z1 + 0.06), iron, false)
	BuildKit.box_mm(oven, Vector3(fx, y + MOUTH_H - 0.02, MOUTH_Z0 - 0.06), Vector3(fz, y + MOUTH_H + 0.05, MOUTH_Z1 + 0.06), iron, false)
	for zz: float in [MOUTH_Z0 - 0.06, MOUTH_Z1]:
		BuildKit.box_mm(oven, Vector3(fx, y + 0.1, zz), Vector3(fz, y + MOUTH_H + 0.05, zz + 0.06), iron, false)
	var wing := (MOUTH_Z1 - MOUTH_Z0) * 0.5
	for hinge: Array in [[MOUTH_Z0 - 0.03, 1.0, 112.0], [MOUTH_Z1 + 0.03, -1.0, -108.0]]:
		var pivot := Node3D.new()
		pivot.position = Vector3(fz, y + 0.12 + (MOUTH_H - 0.12) * 0.5, hinge[0])
		pivot.rotation_degrees.y = hinge[2]
		oven.add_child(pivot)
		var s: float = hinge[1]
		BuildKit.box(pivot, Vector3(0.025, MOUTH_H - 0.16, wing), Vector3(0, 0, s * wing * 0.5), iron, false)
		# Zierleiste und Griff
		BuildKit.box(pivot, Vector3(0.012, MOUTH_H - 0.3, wing - 0.12), Vector3(0.018, 0, s * wing * 0.5), BuildKit.color_mat(Color(0.18, 0.17, 0.16), 0.5, 0.4), false)
		BuildKit.cylinder(pivot, 0.018, 0.05, Vector3(0.04, 0, s * (wing - 0.05)), BuildKit.color_mat(Color(0.6, 0.5, 0.3), 0.4, 0.6), false, Vector3(0, 0, 90), -1.0, 6)
	merge_meshes(tiles)
	# Ofenbank an der Südseite (Sitzbrett auf Füßen, darunter Platz für Holz)
	var bank := BuildKit.tex_mat("planks_h", 0.7, Color(0.85, 0.7, 0.55))
	var bz0 := OVEN_Z1 + 0.04
	var bz1 := OVEN_Z1 + 0.38
	# nur bis BANK_X: davor bleibt Platz zum Durchgehen zwischen Ofen und Schaukelstuhl (Christian 25.11.)
	BuildKit.box_mm(oven, Vector3(wx, y + 0.42, bz0), Vector3(BANK_X, y + 0.47, bz1), bank, true, "Ofenbank")
	for px: float in [wx + 0.06, BANK_X - 0.06]:
		BuildKit.box_mm(oven, Vector3(px - 0.04, y, bz1 - 0.08), Vector3(px + 0.04, y + 0.42, bz1 - 0.02), c.m_wood_dark, false)
	BuildKit.box_mm(oven, Vector3(wx, y + 0.3, bz0), Vector3(wx + 0.03, y + 0.42, bz1), c.m_wood_dark, false)
	var logs := BuildKit.tex_mat("logs", 0.6)
	for i in 4:
		BuildKit.cylinder(oven, 0.07, 0.3, Vector3(-5.78 + i * 0.12, y + 0.08, bz0 + 0.17), logs, false, Vector3(90, rng.randf_range(-8, 8), 0), -1.0, 7)
	# Ofenstange unter der Decke: Handtuch und Wollsocken zum Trocknen
	var rod_y := y + 2.12
	var rod_x := fx + 0.12
	BuildKit.cylinder(oven, 0.015, OVEN_Z1 - OVEN_Z0 - 0.1, Vector3(rod_x, rod_y, (OVEN_Z0 + OVEN_Z1) * 0.5), c.m_iron, false, Vector3(90, 0, 0), -1.0, 6)
	for hz: float in [OVEN_Z0 + 0.1, OVEN_Z1 - 0.1]:
		BuildKit.box_mm(oven, Vector3(rod_x - 0.006, rod_y, hz - 0.006), Vector3(rod_x + 0.006, Cabin.WALL_TOP - 0.24, hz + 0.006), c.m_iron, false)
	BuildKit.box(oven, Vector3(0.01, 0.45, 0.32), Vector3(rod_x, rod_y - 0.22, 1.25), BuildKit.tex_mat("fabric", 0.4, Color(1.6, 1.5, 1.3)), false)
	var wool := BuildKit.tex_mat("fabric_red", 0.3)
	for i in 2:
		var sz := 2.05 + i * 0.14
		BuildKit.box(oven, Vector3(0.02, 0.26, 0.08), Vector3(rod_x, rod_y - 0.13, sz), wool, false)
		BuildKit.box(oven, Vector3(0.02, 0.07, 0.15), Vector3(rod_x, rod_y - 0.28, sz + 0.035), wool, false)


## Eine Kachel mit erhabener Mitte (Füllung). axis 0 = Fläche zeigt nach +x, 2 = nach ±z.
static func _tile(parent: Node3D, pos: Vector3, size: Vector3, mat: Material, axis: int) -> void:
	BuildKit.box(parent, size, pos, mat, false)
	var inner := size * 0.62
	var out := 0.012
	if axis == 0:
		inner.x = size.x
		BuildKit.box(parent, inner, pos + Vector3(out, 0, 0), mat, false)
	else:
		inner.z = size.z
		var sgn := 1.0 if pos.z > (OVEN_Z0 + OVEN_Z1) * 0.5 else -1.0
		BuildKit.box(parent, inner, pos + Vector3(0, 0, out * sgn), mat, false)


## Herrgottswinkel: Eckbrett mit Kruzifix, Palmbuschen, zwei Heiligenbildchen und rotem Ewigen Licht.
static func herrgottswinkel(c: Cabin) -> void:
	var y := Cabin.FLOOR_Y
	var cx := CORNER.x
	var cz := CORNER.y
	var n := Node3D.new()
	n.name = "Herrgottswinkel"
	c.add_child(n)
	var wood := BuildKit.tex_mat("planks_h", 0.5, Color(0.7, 0.5, 0.35))
	var dark := BuildKit.tex_mat("planks_h", 0.5, Color(0.35, 0.24, 0.17))
	var sy := y + 1.92
	# Eckbrett bündig in der Ecke, vorn eine Zierleiste
	BuildKit.box_mm(n, Vector3(cx - 0.34, sy - 0.03, cz - 0.34), Vector3(cx, sy, cz), wood, false)
	BuildKit.box_mm(n, Vector3(cx - 0.34, sy - 0.08, cz - 0.36), Vector3(cx, sy - 0.03, cz - 0.34), dark, false)
	BuildKit.box_mm(n, Vector3(cx - 0.36, sy - 0.08, cz - 0.34), Vector3(cx - 0.34, sy - 0.03, cz), dark, false)
	# Kreuz auf der Diagonale, Blick in die Stube
	var cross := Node3D.new()
	cross.position = Vector3(cx - 0.15, sy, cz - 0.15)
	cross.rotation_degrees.y = 45.0
	n.add_child(cross)
	BuildKit.box(cross, Vector3(0.04, 0.52, 0.025), Vector3(0, 0.29, 0), dark, false)
	BuildKit.box(cross, Vector3(0.28, 0.04, 0.025), Vector3(0, 0.4, 0), dark, false)
	BuildKit.box(cross, Vector3(0.08, 0.035, 0.015), Vector3(0, 0.53, -0.012), BuildKit.color_mat(Color(0.82, 0.78, 0.68)), false)
	var ivory := BuildKit.color_mat(Color(0.86, 0.8, 0.68), 0.6)
	BuildKit.box(cross, Vector3(0.035, 0.15, 0.02), Vector3(0, 0.31, -0.02), ivory, false)
	BuildKit.box(cross, Vector3(0.2, 0.018, 0.015), Vector3(0, 0.395, -0.02), ivory, false)
	BuildKit.sphere(cross, 0.018, Vector3(0, 0.405, -0.024), ivory, Vector3.ONE, 6)
	# Palmbuschen hinter dem Kreuz
	var twig := BuildKit.color_mat(Color(0.38, 0.27, 0.16))
	var leaf := BuildKit.color_mat(Color(0.3, 0.36, 0.2))
	for i in 5:
		var stick := Node3D.new()
		stick.position = Vector3(0.0, 0.05, 0.03)
		stick.rotation_degrees = Vector3(8.0, 0, -30.0 + i * 15.0)
		cross.add_child(stick)
		BuildKit.box(stick, Vector3(0.008, 0.4, 0.008), Vector3(0, 0.2, 0), twig, false)
		BuildKit.sphere(stick, 0.03, Vector3(0, 0.38, 0), leaf, Vector3(1.0, 1.6, 0.7), 5)
	# Heiligenbildchen an beiden Wänden
	var gold := BuildKit.color_mat(Color(0.55, 0.42, 0.18), 0.4, 0.5)
	BuildKit.box(n, Vector3(0.14, 0.18, 0.012), Vector3(cx - 0.36, sy + 0.34, cz - 0.006), gold, false)
	BuildKit.box(n, Vector3(0.11, 0.15, 0.006), Vector3(cx - 0.36, sy + 0.34, cz - 0.014), BuildKit.color_mat(Color(0.35, 0.42, 0.62)), false)
	BuildKit.box(n, Vector3(0.012, 0.18, 0.14), Vector3(cx - 0.006, sy + 0.34, cz - 0.36), gold, false)
	BuildKit.box(n, Vector3(0.006, 0.15, 0.11), Vector3(cx - 0.014, sy + 0.34, cz - 0.36), BuildKit.color_mat(Color(0.6, 0.3, 0.25)), false)
	# Ewiges Licht: rotes Glas, glimmt schwach (kein eigenes Licht)
	BuildKit.cylinder(n, 0.035, 0.08, Vector3(cx - 0.27, sy + 0.04, cz - 0.07), BuildKit.emissive_mat(Color(0.8, 0.08, 0.05), 0.9), false, Vector3.ZERO, 0.03, 8)
	var look := PlaceInspect.new()
	look.name = "HerrgottswinkelLook"
	look.prompt = "[E] Herrgottswinkel ansehen"
	look.text = "Der Herrgottswinkel war schon da, als wir die Hütte zum ersten Mal gesehen haben. Stefanie wollte ihn unbedingt behalten. „Das gehört hierher“, hat sie gesagt. Das kleine rote Licht lasse ich brennen. Für sie."
	look.area_size = Vector3(0.5, 0.65, 0.5)
	look.position = Vector3(cx - 0.2, sy - 0.05, cz - 0.2)
	c.add_child(look)


## Drudenfuß (Pentagramm aus fünf Strichen) in einer Fläche mit Normale +z (lokal).
static func drudenfuss(parent: Node3D, center: Vector3, r: float, mat: Material, thick: float = 0.012) -> void:
	var pts: Array[Vector3] = []
	for k in 5:
		var a := TAU * k / 5.0
		pts.append(center + Vector3(sin(a) * r, cos(a) * r, 0))
	for k in 5:
		BuildKit.beam_between(parent, pts[k], pts[(k + 2) % 5], thick, mat)


## Drudenfuß über der Haustür (eingebranntes Brett) mit Sternsinger-Kreide, kleiner an Bens Bett.
static func door_signs(c: Cabin) -> void:
	var y := Cabin.FLOOR_Y
	var n := Node3D.new()
	n.name = "Drudenfuss"
	n.position = Vector3(-3.0, y + 2.42, Cabin.HALF_Z + 0.2)
	c.add_child(n)
	BuildKit.box(n, Vector3(0.52, 0.34, 0.03), Vector3.ZERO, BuildKit.tex_mat("planks_h", 0.5, Color(0.95, 0.82, 0.62)), false)
	drudenfuss(n, Vector3(0, -0.01, 0.017), 0.13, BuildKit.color_mat(Color(0.12, 0.07, 0.04)), 0.014)
	var chalk := PlacesDay.label(n, "20 * C + M + B * 26", Vector3(0, -0.24, 0.0), 16, Color(0.92, 0.92, 0.88))
	chalk.position.z = 0.05
	var look := PlaceInspect.new()
	look.name = "DrudenfussLook"
	look.prompt = "[E] Zeichen über der Tür ansehen"
	look.text = "Ein Drudenfuß, ins Brett gebrannt. Gegen die Drud, die sich nachts auf die Brust der Schlafenden setzt, sagen die Alten hier. Darunter die Kreide der Sternsinger. Früher hätte ich darüber gelacht."
	look.area_size = Vector3(0.7, 0.5, 0.4)
	look.position = Vector3(-3.0, y + 2.18, Cabin.HALF_Z + 0.3)
	c.add_child(look)


## Kleiner Drudenfuß ins Kopfteil von Bens Bett geritzt (Kopfteil Innenseite zeigt nach Norden).
static func ben_bed_sign(parent: Node3D, center: Vector3) -> void:
	var holder := Node3D.new()
	holder.name = "DrudenfussBen"
	holder.position = center
	holder.rotation_degrees.y = 180.0   # lokal +z zeigt nach Norden (-z der Welt)
	parent.add_child(holder)
	drudenfuss(holder, Vector3.ZERO, 0.09, BuildKit.color_mat(Color(0.45, 0.36, 0.26)), 0.008)


## Gred: Granitplatten vor dem Haus (unter dem Vordach), Fugen dunkel, Platten in Reihen versetzt.
static func gred(c: Cabin, x0: float, x1: float, z0: float, z1: float) -> void:
	var y := Cabin.FLOOR_Y
	var n := Node3D.new()
	n.name = "Gred"
	c.add_child(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1721
	var mats: Array[Material] = []
	for t: float in [1.05, 1.15, 1.25, 1.35]:
		mats.append(BuildKit.tex_mat("stone", 0.9, Color(t, t * 0.98, t * 0.95)))
	var z := z0
	while z < z1 - 0.05:
		var depth := minf(rng.randf_range(0.55, 0.75), z1 - z)
		if z1 - (z + depth) < 0.3:
			depth = z1 - z
		var x := x0 - rng.randf_range(0.0, 0.4)
		while x < x1 - 0.05:
			var w := rng.randf_range(0.6, 1.1)
			var a := maxf(x, x0)
			var b := minf(x + w, x1)
			if b - a > 0.15:
				BuildKit.box_mm(n, Vector3(a + 0.012, y, z + 0.012), Vector3(b - 0.012, y + 0.014, z + depth - 0.012), mats[rng.randi() % mats.size()], false)
			x += w
		z += depth
	merge_meshes(n)


## Fasst alle einfachen Kisten-Kinder eines Knotens zu einem Netz zusammen (je Material eine Fläche) –
## spart Zeichenaufrufe bei vielen kleinen Teilen (Kacheln, Platten).
static func merge_meshes(holder: Node3D) -> void:
	var tools := {}
	var mats := {}
	var parts: Array[Node] = []
	for ch in holder.get_children():
		var mi := ch as MeshInstance3D
		if mi == null or mi.mesh == null or mi.get_child_count() > 0:
			continue
		var mat: Material = mi.material_override if mi.material_override else mi.mesh.surface_get_material(0)
		var key := mat.get_instance_id() if mat else 0
		if not tools.has(key):
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			tools[key] = st
			mats[key] = mat
		(tools[key] as SurfaceTool).append_from(mi.mesh, 0, mi.transform)
		parts.append(mi)
	if parts.size() < 2:
		return
	var mesh := ArrayMesh.new()
	for key in tools:
		var st: SurfaceTool = tools[key]
		mesh = st.commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, mats[key])
	for p in parts:
		holder.remove_child(p)
		p.free()
	var merged := MeshInstance3D.new()
	merged.name = "Merged"
	merged.mesh = mesh
	holder.add_child(merged)
