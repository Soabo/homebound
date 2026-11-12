class_name CabinRooms
extends RefCounted
## Anbauten der Hütte (Christian, 12.11.2026): Stefanies Büro hinter der Speis (Fenster Nord + West),
## Kinderzimmer im Nordwesten neben dem Kamin (Fenster West + Nord), Dachboden mit Zugleiter in der
## Werkstatt und Keller unter dem Büro (Luke unter dem Teppich, zugemauerte Stelle Richtung alter Brunnen).
## Gebaut wird in den Cabin-Knoten hinein (gleiche Materialien, Fenster, Schalter).

## Pultdach der Anbauten: Höhe an der Hauswand und an der Außenwand
const ROOF_HI := 2.95
const ROOF_LO := 2.65

var c: Cabin
var _rng := RandomNumberGenerator.new()


static func build(cabin: Cabin) -> void:
	var r := CabinRooms.new()
	r.c = cabin
	r._rng.seed = 1117
	r._office()
	r._kids_room()
	r._attic()
	r._cellar()


# --- Helfer --------------------------------------------------------------

## Fläche (vier Ecken, beidseitig sichtbar) – für die schrägen Giebeldreiecke der Pultdächer.
func _panel(pts: Array, mat: Material) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var p0: Vector3 = pts[0]
	var p1: Vector3 = pts[1]
	var p2: Vector3 = pts[2]
	var p3: Vector3 = pts[3]
	var n := (p1 - p0).cross(p2 - p0).normalized()
	for tri: Array in [[p0, p1, p2], [p0, p2, p3], [p0, p2, p1], [p0, p3, p2]]:
		var nn := n if tri == [p0, p1, p2] or tri == [p0, p2, p3] else -n
		for v: Vector3 in tri:
			st.set_normal(nn)
			st.set_uv(Vector2(v.x + v.z, v.y))
			st.add_vertex(v)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	c.add_child(mi)


## Eine Anbauwand: unsichtbare Kollision, Rundholz außen, Bretter innen. openings wie BuildKit.wall (y relativ zum Boden).
## inner = Richtung ins Rauminnere (Draufsicht), top = Höhe der Wandkrone über dem Boden (Weltmaß).
func _annex_wall(a: Vector2, b: Vector2, top: float, inner: Vector2, openings: Array, wall_name: String) -> void:
	var y := Cabin.FLOOR_Y
	BuildKit.wall(c, a, b, y, top - y, Cabin.EXT_T, null, openings, wall_name)
	var world_ops := []
	for o: Vector4 in openings:
		world_ops.append(Vector4(o.x, o.y, o.z + y, o.w + y))
	BuildKit.log_wall(c, a, b, y - 0.02, top - Cabin.LOG_R, Cabin.LOG_R, 0.3, c.m_logs, world_ops)
	# Innenverkleidung etwas vor der Wandmitte
	var off := inner * Cabin.CLAD
	var dir := (b - a).normalized()
	var ia := a + off + dir * Cabin.CLAD
	var ib := b + off - dir * Cabin.CLAD
	var in_ops := []
	for o: Vector4 in openings:
		in_ops.append(Vector4(o.x - Cabin.CLAD, o.y, o.z, o.w))
	BuildKit.wall(c, ia, ib, y, top - y - 0.12, 0.03, c.m_wall, in_ops, wall_name + "Clad")


func _window(node_name: String, pos: Vector3, rot_y: float, w: float, h: float) -> void:
	c._window(node_name, pos, rot_y, w, h)


# --- Büro hinter der Speis ---------------------------------------------------

func _office() -> void:
	var r := Cabin.OFFICE
	var x0 := r.position.x
	var x1 := r.end.x
	var z0 := r.position.y       # Nordwand
	var z1 := r.end.y            # Hauswand
	var y := Cabin.FLOOR_Y
	var roof_at := func(z: float) -> float: return ROOF_LO + (ROOF_HI - ROOF_LO) * (z - z0) / (z1 - z0)
	var hole := CellarHatch.HOLE
	# Fundament + Boden mit Loch für die Kellerluke
	var foot := []
	var lo := Vector2(x0 - 0.12, z0 - 0.12)
	var hi := Vector2(x1 + 0.12, z1)
	foot.append([Vector2(lo.x, lo.y), Vector2(hole.position.x, hi.y)])
	foot.append([Vector2(hole.end.x, lo.y), Vector2(hi.x, hi.y)])
	foot.append([Vector2(hole.position.x, lo.y), Vector2(hole.end.x, hole.position.y)])
	foot.append([Vector2(hole.position.x, hole.end.y), Vector2(hole.end.x, hi.y)])
	for i in foot.size():
		var a: Vector2 = foot[i][0]
		var b: Vector2 = foot[i][1]
		BuildKit.box_mm(c, Vector3(a.x, -0.4, a.y), Vector3(b.x, y - 0.06, b.y), c.m_stone, true, "OfficeFoundation_%d" % i)
		BuildKit.box_mm(c, Vector3(maxf(a.x, x0), y - 0.08, maxf(a.y, z0)), Vector3(minf(b.x, x1), y, b.y), c.m_floor, true, "OfficeFloor_%d" % i)
	# Wände: Nord (Fenster), West (Fenster Richtung Schlafzimmerseite), Ost
	var north_top: float = roof_at.call(z0) - 0.1
	_annex_wall(Vector2(x0, z0), Vector2(x1, z0), north_top, Vector2(0, 1), [Vector4(1.6, 1.0, 1.0, 1.9)], "OfficeWallNorth")
	_annex_wall(Vector2(x0, z0), Vector2(x0, z1), north_top, Vector2(1, 0), [Vector4(1.7, 1.0, 1.0, 1.9)], "OfficeWallWest")
	_annex_wall(Vector2(x1, z0), Vector2(x1, z1), north_top, Vector2(-1, 0), [], "OfficeWallEast")
	_window("WindowOffice", Vector3(x0 + 1.6, y + 1.0, z0), 180.0, 1.0, 0.9)
	_window("WindowOfficeWest", Vector3(x0, y + 1.0, z0 + 1.7), -90.0, 1.0, 0.9)
	# Giebeldreiecke über den Seitenwänden (außen Bretter, innen Verkleidung) und Pultdach
	var gable_mat := BuildKit.tex_mat("planks_v", 0.8, Color(0.62, 0.52, 0.42))
	for x: float in [x0, x1]:
		for d: float in [-0.13, 0.13]:
			var xx := x + d
			_panel([Vector3(xx, north_top, z0), Vector3(xx, north_top, z1), Vector3(xx, roof_at.call(z1) + 0.05, z1), Vector3(xx, roof_at.call(z0) + 0.05, z0)],
					gable_mat if (d < 0.0) == (x == x0) else c.m_wall)
	_lean_to_z(x0 - 0.45, x1 + 0.45, z0 - 0.55, z1, roof_at)
	# Licht + Schalter (innen neben der Tür)
	var lamp := c._lamp(Vector3(0.0, roof_at.call(-6.3) - 0.12, -6.3), 0.9, 5.0, true)
	c._switch("office", "Licht Büro", Vector3(1.15, y + 1.25, z1 - 0.17), 180.0, [lamp])
	_office_furniture(x0, x1, z0, z1)
	# Kellerluke unter dem Teppich
	var hatch := CellarHatch.new()
	hatch.name = "CellarHatch"
	c.add_child(hatch)


## Pultdach, das nach Norden (zu kleinem z) abfällt.
func _lean_to_z(xa: float, xb: float, z_out: float, z_house: float, roof_at: Callable) -> void:
	var shingles := BuildKit.tex_mat("shingles", 1.3)
	var y_out: float = roof_at.call(z_out)
	var y_in: float = roof_at.call(z_house)
	var run := z_house - z_out
	var slope := atan2(y_in - y_out, run)
	var len := run / cos(slope)
	var mid := Vector3((xa + xb) * 0.5, (y_out + y_in) * 0.5 + 0.1, (z_out + z_house) * 0.5)
	BuildKit.box(c, Vector3(xb - xa, 0.18, len), mid, shingles, false, Vector3(-rad_to_deg(slope), 0, 0))
	# Innen: schräge Bretterdecke
	var ceil_mat := BuildKit.tex_mat("planks_h", 1.2, Color(0.62, 0.58, 0.55))
	BuildKit.box(c, Vector3(xb - xa - 0.9, 0.04, len - 0.6), mid + Vector3(0, -0.22, 0.3), ceil_mat, false, Vector3(-rad_to_deg(slope), 0, 0))
	# Traufbrett
	BuildKit.box(c, Vector3(xb - xa + 0.05, 0.2, 0.05), Vector3(mid.x, y_out + 0.05, z_out), c.m_wood_dark, false)


## Pultdach, das nach Westen (zu kleinem x) abfällt.
func _lean_to_x(x_out: float, x_house: float, za: float, zb: float, roof_at: Callable) -> void:
	var shingles := BuildKit.tex_mat("shingles", 1.3)
	var y_out: float = roof_at.call(x_out)
	var y_in: float = roof_at.call(x_house)
	var run := x_house - x_out
	var slope := atan2(y_in - y_out, run)
	var len := run / cos(slope)
	var mid := Vector3((x_out + x_house) * 0.5, (y_out + y_in) * 0.5 + 0.1, (za + zb) * 0.5)
	BuildKit.box(c, Vector3(len, 0.18, zb - za), mid, shingles, false, Vector3(0, 0, rad_to_deg(slope)))
	var ceil_mat := BuildKit.tex_mat("planks_h", 1.2, Color(0.62, 0.58, 0.55))
	BuildKit.box(c, Vector3(len - 0.6, 0.04, zb - za - 0.9), mid + Vector3(0.3, -0.22, 0), ceil_mat, false, Vector3(0, 0, rad_to_deg(slope)))
	BuildKit.box(c, Vector3(0.05, 0.2, zb - za + 0.05), Vector3(x_out, y_out + 0.05, mid.z), c.m_wood_dark, false)


func _office_furniture(x0: float, x1: float, z0: float, z1: float) -> void:
	var y := Cabin.FLOOR_Y
	var wood := c.m_wood
	var dark := c.m_wood_dark
	var ix0 := x0 + Cabin.CLAD + 0.03
	var ix1 := x1 - Cabin.CLAD - 0.03
	var iz0 := z0 + Cabin.CLAD + 0.03
	# Schreibtisch an der Nordwand (Ostteil), Stuhl, Lampe, Papiere
	BuildKit.box_mm(c, Vector3(1.55, y + 0.72, iz0), Vector3(3.0, y + 0.76, iz0 + 0.7), wood, true, "OfficeDesk")
	for lx: float in [1.6, 2.95]:
		for lz: float in [iz0 + 0.05, iz0 + 0.65]:
			BuildKit.box(c, Vector3(0.05, 0.72, 0.05), Vector3(lx, y + 0.36, lz), dark, false)
	BuildKit.box_mm(c, Vector3(2.45, y + 0.1, iz0 + 0.05), Vector3(2.95, y + 0.7, iz0 + 0.65), dark, true)
	c._chair(Vector3(2.1, y, iz0 + 1.05), 180.0)
	var desk_lamp := BuildKit.color_mat(Color(0.15, 0.3, 0.22), 0.4, 0.4)
	BuildKit.cylinder(c, 0.07, 0.02, Vector3(1.8, y + 0.77, iz0 + 0.2), desk_lamp, false, Vector3.ZERO, -1.0, 10)
	BuildKit.cylinder(c, 0.01, 0.32, Vector3(1.8, y + 0.93, iz0 + 0.2), desk_lamp, false, Vector3(0, 0, 10), -1.0, 6)
	BuildKit.cylinder(c, 0.09, 0.1, Vector3(1.86, y + 1.08, iz0 + 0.25), desk_lamp, false, Vector3(35, 0, 0), 0.04, 10)
	var paper := BuildKit.color_mat(Color(0.9, 0.88, 0.82), 0.9)
	for i in 5:
		BuildKit.box(c, Vector3(0.21, 0.004, 0.29), Vector3(2.3 + _rng.randf_range(-0.2, 0.3), y + 0.764 + i * 0.004, iz0 + 0.35), paper, false, Vector3(0, _rng.randf_range(-25, 25), 0))
	# Aktenschrank in der Nordwestecke
	BuildKit.box_mm(c, Vector3(ix0, y, iz0), Vector3(ix0 + 0.5, y + 1.3, iz0 + 0.55), BuildKit.color_mat(Color(0.42, 0.45, 0.42), 0.5, 0.5), true, "FileCabinet")
	for k in 3:
		BuildKit.box(c, Vector3(0.12, 0.02, 0.02), Vector3(ix0 + 0.25, y + 0.3 + k * 0.4, iz0 + 0.56), c.m_iron, false)
	# Regal mit Ordnern an der Ostwand, Pinnwand mit Karte darüber
	c._shelf(Vector3(ix1 - 0.35, y, -6.2), Vector3(ix1, y + 1.8, -4.9), 4, false)
	var folder_cols := [Color(0.6, 0.15, 0.12), Color(0.15, 0.25, 0.5), Color(0.2, 0.4, 0.25), Color(0.75, 0.65, 0.2)]
	for lvl in 4:
		var sy := y + 0.05 + lvl * (1.75 / 4.0)
		var z := -6.1
		while z < -5.05:
			var w := _rng.randf_range(0.05, 0.08)
			BuildKit.box(c, Vector3(0.28, 0.3, w), Vector3(ix1 - 0.17, sy + 0.15, z + w * 0.5), BuildKit.color_mat(folder_cols[_rng.randi() % folder_cols.size()], 0.6), false)
			z += w + 0.01
			if _rng.randf() < 0.12:
				z += 0.12
	var board := BuildKit.tex_mat("planks_h", 0.6, Color(0.75, 0.6, 0.4))
	BuildKit.box_mm(c, Vector3(ix1 - 0.02, y + 1.1, -7.3), Vector3(ix1, y + 1.9, -6.4), board, false)
	BuildKit.box_mm(c, Vector3(ix1 - 0.025, y + 1.2, -7.2), Vector3(ix1 - 0.02, y + 1.8, -6.5), BuildKit.color_mat(Color(0.72, 0.78, 0.6), 0.9), false)
	for k in 5:
		BuildKit.sphere(c, 0.012, Vector3(ix1 - 0.03, y + 1.3 + _rng.randf() * 0.4, -7.1 + _rng.randf() * 0.5), BuildKit.color_mat(Color(0.85, 0.1, 0.1)), Vector3.ONE, 5)
	# Wandkalender neben der Tür (Notiz)
	var cal := ResearchNote.new()
	cal.name = "OfficeCalendar"
	cal.note_id = "buero_kalender"
	cal.hide_paper = true
	cal.anchor = Vector3(-0.35, y + 1.35, z1 - 0.2)
	c.add_child(cal)
	BuildKit.box_mm(c, Vector3(-0.55, y + 1.2, z1 - 0.18), Vector3(-0.15, y + 1.65, z1 - 0.16), BuildKit.color_mat(Color(0.92, 0.9, 0.85), 0.9), false)
	BuildKit.box_mm(c, Vector3(-0.55, y + 1.55, z1 - 0.185), Vector3(-0.15, y + 1.65, z1 - 0.178), BuildKit.color_mat(Color(0.6, 0.15, 0.12), 0.7), false)
	# Umzugskartons mit ihrem Namen
	var card := BuildKit.tex_mat("fabric", 0.3, Color(1.45, 1.2, 0.85))
	for b: Array in [[Vector3(-1.6, y, -5.3), 0.0], [Vector3(-1.55, y + 0.4, -5.32), 8.0], [Vector3(-1.0, y, -5.0), -12.0]]:
		var box := BuildKit.box(c, Vector3(0.5, 0.4, 0.4), (b[0] as Vector3) + Vector3(0, 0.2, 0), card, b[0].y < y + 0.1, Vector3(0, b[1], 0))
		var lab := Label3D.new()
		lab.text = "STEFANIE\nBÜRO"
		lab.font_size = 26
		lab.pixel_size = 0.0016
		lab.modulate = Color(0.1, 0.1, 0.12)
		lab.outline_size = 0
		lab.double_sided = false
		lab.position = Vector3(0, 0.02, 0.202)
		box.add_child(lab)


# --- Kinderzimmer --------------------------------------------------------

func _kids_room() -> void:
	var r := Cabin.KIDS
	var x0 := r.position.x       # Westwand
	var x1 := r.end.x            # Hauswand
	var z0 := r.position.y       # Nordwand
	var z1 := r.end.y            # Südwand
	var y := Cabin.FLOOR_Y
	var roof_at := func(x: float) -> float: return ROOF_LO + (ROOF_HI - ROOF_LO) * (x - x0) / (x1 - x0)
	BuildKit.box_mm(c, Vector3(x0 - 0.12, -0.4, z0 - 0.12), Vector3(x1, y - 0.06, z1 + 0.12), c.m_stone, true, "KidsFoundation")
	BuildKit.box_mm(c, Vector3(x0, y - 0.08, z0), Vector3(x1, y, z1), c.m_floor, true, "KidsFloor")
	var west_top: float = roof_at.call(x0) - 0.1
	_annex_wall(Vector2(x0, z0), Vector2(x0, z1), west_top, Vector2(1, 0), [Vector4(2.5, 1.0, 1.0, 1.9)], "KidsWallWest")
	_annex_wall(Vector2(x0, z0), Vector2(x1 - 0.4, z0), west_top, Vector2(0, 1), [Vector4(1.7, 1.0, 1.0, 1.9)], "KidsWallNorth")
	_annex_wall(Vector2(x0, z1), Vector2(x1, z1), west_top, Vector2(0, -1), [], "KidsWallSouth")
	_window("WindowKids", Vector3(x0, y + 1.0, z0 + 2.5), -90.0, 1.0, 0.9)
	_window("WindowKidsNorth", Vector3(x0 + 1.7, y + 1.0, z0), 180.0, 1.0, 0.9)
	var gable_mat := BuildKit.tex_mat("planks_v", 0.8, Color(0.62, 0.52, 0.42))
	for z: float in [z0, z1]:
		for d: float in [-0.13, 0.13]:
			var zz := z + d
			_panel([Vector3(x0, west_top, zz), Vector3(x1, west_top, zz), Vector3(x1, roof_at.call(x1) + 0.05, zz), Vector3(x0, roof_at.call(x0) + 0.05, zz)],
					gable_mat if (d < 0.0) == (z == z0) else c.m_wall)
	_lean_to_x(x0 - 0.55, x1, z0 - 0.45, z1 + 0.4, roof_at)
	var lamp := c._lamp(Vector3(-7.5, roof_at.call(-7.5) - 0.12, -2.0), 0.9, 5.0, true)
	c._switch("kids", "Licht Kinderzimmer", Vector3(x1 - 0.17, y + 1.25, -0.75), -90.0, [lamp])
	_kids_furniture(x0, x1, z0, z1)


func _kids_furniture(x0: float, x1: float, z0: float, z1: float) -> void:
	var y := Cabin.FLOOR_Y
	var ix0 := x0 + Cabin.CLAD + 0.03
	var iz0 := z0 + Cabin.CLAD + 0.03
	var iz1 := z1 - Cabin.CLAD - 0.03
	var frame := BuildKit.tex_mat("planks_h", 0.8, Color(0.95, 0.9, 0.8))
	var sheet_a := BuildKit.tex_mat("fabric", 0.5, Color(0.9, 1.5, 1.0))     # Lena: grün
	var sheet_b := BuildKit.tex_mat("fabric", 0.5, Color(1.0, 1.1, 1.7))     # Ben: blau
	# Zwei Kinderbetten an der Westwand, das Fenster dazwischen bleibt frei
	for b: Array in [[iz0, sheet_a, "Lena"], [iz1 - 1.75, sheet_b, "Ben"]]:
		var bz: float = b[0]
		BuildKit.box_mm(c, Vector3(ix0, y + 0.08, bz), Vector3(ix0 + 0.85, y + 0.32, bz + 1.75), frame, true)
		BuildKit.box_mm(c, Vector3(ix0 + 0.03, y + 0.32, bz + 0.03), Vector3(ix0 + 0.82, y + 0.44, bz + 1.72), BuildKit.tex_mat("fabric", 0.5, Color(1.7, 1.66, 1.55)), false)
		BuildKit.box_mm(c, Vector3(ix0 + 0.02, y + 0.44, bz + 0.55), Vector3(ix0 + 0.83, y + 0.48, bz + 1.73), b[1], false)
		var head_z := bz + 0.05 if b[2] == "Lena" else bz + 1.7
		BuildKit.box(c, Vector3(0.45, 0.1, 0.3), Vector3(ix0 + 0.42, y + 0.5, head_z + (0.15 if b[2] == "Lena" else -0.15)), BuildKit.tex_mat("fabric", 0.4, Color(1.9, 1.85, 1.75)), false)
		# Kopfteil (Lena: Norden, Ben: Süden)
		var hz := bz if b[2] == "Lena" else bz + 1.71
		BuildKit.box_mm(c, Vector3(ix0, y, hz), Vector3(ix0 + 0.85, y + 0.75, hz + 0.04), frame, false)
	# Kuscheltier auf Bens Bett
	var fur := BuildKit.tex_mat("fabric", 0.4, Color(1.1, 0.8, 0.55))
	var bear := Vector3(ix0 + 0.5, y + 0.55, iz1 - 0.6)
	BuildKit.sphere(c, 0.1, bear, fur, Vector3(1.0, 1.1, 0.9), 8)
	BuildKit.sphere(c, 0.075, bear + Vector3(0, 0.15, 0), fur, Vector3.ONE, 8)
	for s: float in [-1.0, 1.0]:
		BuildKit.sphere(c, 0.03, bear + Vector3(s * 0.06, 0.22, 0), fur, Vector3.ONE, 6)
	# Halb gestrichene Wand: grüner Streifen an der Nordwand, Farbeimer, Rolle
	var green := BuildKit.color_mat(Color(0.45, 0.65, 0.45), 0.9)
	BuildKit.box_mm(c, Vector3(ix0 + 0.95, y + 0.1, iz0 - 0.03), Vector3(-7.95, y + 2.0, iz0 - 0.02), green, false)
	BuildKit.cylinder(c, 0.14, 0.22, Vector3(-6.7, y + 0.11, iz0 + 0.3), BuildKit.color_mat(Color(0.75, 0.75, 0.72), 0.4, 0.6), true, Vector3.ZERO, -1.0, 12)
	BuildKit.cylinder(c, 0.13, 0.01, Vector3(-6.7, y + 0.225, iz0 + 0.3), green, false, Vector3.ZERO, -1.0, 12)
	BuildKit.cylinder(c, 0.035, 0.22, Vector3(-6.95, y + 0.04, iz0 + 0.65), BuildKit.tex_mat("fabric", 0.3, Color(0.7, 1.1, 0.7)), false, Vector3(0, 0, 90), -1.0, 8)
	# Kisten mit den Namen der Kinder (nie ausgepackt)
	var card := BuildKit.tex_mat("fabric", 0.3, Color(1.45, 1.2, 0.85))
	for b: Array in [[Vector3(-6.75, y, -3.1), "LENA", 4.0], [Vector3(-6.75, y, -2.4), "BEN", -6.0], [Vector3(-6.7, y + 0.4, -2.75), "SPIELZEUG", 2.0]]:
		var box := BuildKit.box(c, Vector3(0.5, 0.4, 0.55), (b[0] as Vector3) + Vector3(0, 0.2, 0), card, (b[0] as Vector3).y < y + 0.1, Vector3(0, b[2], 0))
		var lab := Label3D.new()
		lab.text = b[1]
		lab.font_size = 34
		lab.pixel_size = 0.0016
		lab.modulate = Color(0.08, 0.08, 0.1)
		lab.outline_size = 0
		lab.double_sided = false
		lab.rotation_degrees.y = -90.0
		lab.position = Vector3(-0.252, 0.03, 0)
		box.add_child(lab)
	# Zeichnung auf Lenas Bett (Notiz)
	var drawing := ResearchNote.new()
	drawing.name = "KidsDrawing"
	drawing.note_id = "kinder_bild"
	drawing.anchor = Vector3(ix0 + 0.45, y + 0.46, iz0 + 1.2)
	c.add_child(drawing)
	# Kleiner Teppich
	BuildKit.box_mm(c, Vector3(-8.0, y, -2.6), Vector3(-6.9, y + 0.012, -1.4), BuildKit.tex_mat("rug", 1.2, Color(1.0, 1.1, 0.9)), false)


# --- Dachboden -------------------------------------------------------------

func _attic() -> void:
	var y := Cabin.WALL_TOP + 0.1
	var hatch := AtticHatch.new()
	hatch.name = "AtticHatch"
	c.add_child(hatch)
	# ein paar Bodenbretter längs, damit es nach Dachboden aussieht
	var boards := BuildKit.tex_mat("planks_h", 0.9, Color(0.75, 0.68, 0.6))
	BuildKit.box_mm(c, Vector3(-5.6, y, -0.9), Vector3(3.6, y + 0.02, 0.9), boards, false)
	BuildKit.box_mm(c, Vector3(4.7, y, -0.9), Vector3(5.6, y + 0.02, 0.9), boards, false)
	# Glühbirne am First + Schalter an einem Pfosten neben der Luke
	var bulb := c._lamp(Vector3(0.0, Cabin.WALL_TOP + Cabin.ROOF_RISE - 0.15, 0.0), 0.7, 6.5, true)
	var bulb2 := c._lamp(Vector3(4.6, Cabin.WALL_TOP + Cabin.ROOF_RISE - 0.15, 0.0), 0.5, 4.5, false)
	BuildKit.box(c, Vector3(0.1, Cabin.ROOF_RISE, 0.1), Vector3(3.0, y + Cabin.ROOF_RISE * 0.5 - 0.05, 0.7), c.m_beam, true)
	c._switch("attic", "Licht Dachboden", Vector3(3.06, y + 1.2, 0.7), 90.0, [bulb, bulb2])
	# Gerümpel: alte Truhe, Stuhl, Kartons von Stefanie, Wiege
	var card := BuildKit.tex_mat("fabric", 0.3, Color(1.3, 1.1, 0.8))
	BuildKit.box_mm(c, Vector3(-5.6, y, -0.5), Vector3(-4.8, y + 0.55, 0.4), BuildKit.tex_mat("planks_h", 0.5, Color(0.6, 0.4, 0.28)), true, "AtticTrunk")
	BuildKit.box_mm(c, Vector3(-5.62, y + 0.5, -0.52), Vector3(-4.78, y + 0.58, 0.42), c.m_iron, false)
	for b: Array in [[Vector3(-3.6, y, 0.9), 0.0], [Vector3(-3.1, y, 1.0), 14.0], [Vector3(-3.4, y + 0.4, 0.95), -6.0], [Vector3(1.2, y, -1.0), 5.0], [Vector3(1.8, y, -1.05), -9.0]]:
		BuildKit.box(c, Vector3(0.5, 0.4, 0.45), (b[0] as Vector3) + Vector3(0, 0.2, 0), card, (b[0] as Vector3).y < y + 0.1, Vector3(0, b[1], 0))
	c._chair(Vector3(-1.5, y, -0.9), 30.0)
	# Wiege
	var cradle := BuildKit.tex_mat("planks_h", 0.6, Color(0.95, 0.88, 0.75))
	BuildKit.box_mm(c, Vector3(-0.6, y + 0.15, 0.55), Vector3(0.3, y + 0.45, 1.05), cradle, true)
	for s: float in [-0.6, 0.3]:
		BuildKit.cylinder(c, 0.2, 0.04, Vector3(s, y + 0.2, 0.8), cradle, false, Vector3(0, 0, 90), -1.0, 12)
	# Stefanies Zettel am Karton
	var note := ResearchNote.new()
	note.name = "AtticNote"
	note.note_id = "dachboden_liste"
	note.anchor = Vector3(-3.35, y + 0.8, 0.95)
	c.add_child(note)
	# Staub
	var dust := ParticlesKit.dust(Vector3(5.0, 0.8, 1.2))
	dust.position = Vector3(0, y + 1.0, 0)
	c.add_child(dust)


# --- Keller ----------------------------------------------------------------

func _cellar() -> void:
	var r := Cabin.CELLAR
	var x0 := r.position.x
	var x1 := r.end.x
	var z0 := r.position.y
	var z1 := r.end.y
	var fy := Cabin.CELLAR_FLOOR
	var stone := BuildKit.tex_mat("stone", 0.7, Color(0.7, 0.68, 0.64))
	var stone_dark := BuildKit.tex_mat("stone_dark", 0.8)
	var t := 0.2
	BuildKit.box_mm(c, Vector3(x0, fy - 0.15, z0), Vector3(x1, fy, z1), stone_dark, true, "CellarFloor")
	BuildKit.box_mm(c, Vector3(x0 - t * 0.5, fy - 0.15, z0 - t * 0.5), Vector3(x0 + t * 0.5, 0.0, z1 + t * 0.5), stone, true, "CellarWallWest")
	BuildKit.box_mm(c, Vector3(x1 - t * 0.5, fy - 0.15, z0 - t * 0.5), Vector3(x1 + t * 0.5, 0.0, z1 + t * 0.5), stone, true, "CellarWallEast")
	BuildKit.box_mm(c, Vector3(x0, fy - 0.15, z0 - t * 0.5), Vector3(x1, 0.0, z0 + t * 0.5), stone, true, "CellarWallNorth")
	BuildKit.box_mm(c, Vector3(x0, fy - 0.15, z1 - t * 0.5), Vector3(x1, 0.0, z1 + t * 0.5), stone, true, "CellarWallSouth")
	# Decke: Balken + Bretter, Loch unter der Luke
	var hole := CellarHatch.HOLE
	var ceil_mat := BuildKit.tex_mat("planks_h", 1.0, Color(0.5, 0.45, 0.42))
	BuildKit.box_mm(c, Vector3(x0, -0.06, z0), Vector3(hole.position.x, 0.0, z1), ceil_mat, false)
	BuildKit.box_mm(c, Vector3(hole.end.x, -0.06, z0), Vector3(x1, 0.0, z1), ceil_mat, false)
	BuildKit.box_mm(c, Vector3(hole.position.x, -0.06, z0), Vector3(hole.end.x, 0.0, hole.position.y), ceil_mat, false)
	BuildKit.box_mm(c, Vector3(hole.position.x, -0.06, hole.end.y), Vector3(hole.end.x, 0.0, z1), ceil_mat, false)
	for bz: float in [-6.2, -4.6, -3.0]:
		BuildKit.box(c, Vector3(x1 - x0, 0.16, 0.14), Vector3((x0 + x1) * 0.5, -0.14, bz), c.m_beam, false)
	# Licht (nackte Birne) mit Schalter an der Leiter
	var bulb := c._lamp(Vector3(0.5, -0.3, -4.2), 0.6, 5.0, true)
	c._switch("cellar", "Licht Keller", Vector3(x0 + 0.12, fy + 1.35, -4.6), 90.0, [bulb])
	# Vorratsregal an der Westwand: Weckgläser (zum Mitnehmen), Säcke aus der Speis
	var shelf_x := x0 + 0.1
	c._shelf(Vector3(shelf_x, fy, -6.6), Vector3(shelf_x + 0.4, fy + 1.7, -5.0), 4, false)
	var glass := BuildKit.color_mat(Color(0.75, 0.6, 0.35), 0.2)
	var jars := ItemPickup.new()
	jars.name = "CellarJars"
	jars.item_id = "food"
	jars.amount = 3
	jars.per_take = 1
	jars.restock = true
	jars.label = "Weckgläser"
	jars.collider_size = Vector3(0.4, 0.3, 0.9)
	jars.collider_offset = Vector3(shelf_x + 0.2, fy + 0.62, -5.8)
	c.add_child(jars)
	var holder := Node3D.new()
	jars.add_child(holder)
	jars.visuals.append(holder)   # Regalbrett bleibt, Gläser verschwinden einzeln
	for i in 3:
		var j := Node3D.new()
		jars.add_child(j)
		BuildKit.cylinder(j, 0.06, 0.16, Vector3(shelf_x + 0.2, fy + 0.57, -6.1 + i * 0.25), glass, false, Vector3.ZERO, -1.0, 10)
		BuildKit.cylinder(j, 0.062, 0.02, Vector3(shelf_x + 0.2, fy + 0.66, -6.1 + i * 0.25), c.m_iron, false, Vector3.ZERO, -1.0, 10)
		jars.visuals.append(j)
	var sack := BuildKit.tex_mat("fabric", 0.4, Color(1.4, 1.25, 0.95))
	BuildKit.sphere(c, 0.28, Vector3(0.0, fy + 0.22, -3.0), sack, Vector3(1.0, 0.8, 0.8), 10)
	BuildKit.sphere(c, 0.28, Vector3(-0.1, fy + 0.22, -2.6), sack, Vector3(0.9, 0.8, 0.9), 10)
	# Die zugemauerte Stelle an der Ostwand (Richtung alter Brunnen): jüngere Ziegel, Wurzeln in den Fugen
	_bricked_wall(x1 - t * 0.5, fy)
	# kühle, feuchte Luft
	var dust := ParticlesKit.dust(Vector3(1.0, 0.8, 2.0))
	dust.position = Vector3((x0 + x1) * 0.5, fy + 1.0, (z0 + z1) * 0.5)
	c.add_child(dust)


func _bricked_wall(wx: float, fy: float) -> void:
	var brick := BuildKit.color_mat(Color(0.48, 0.3, 0.24), 0.9)
	var mortar := BuildKit.color_mat(Color(0.62, 0.6, 0.55), 1.0)
	var face := wx - 0.005
	var zc := -3.35
	var w := 1.1
	var h := 1.6
	# Bogen aus dunklerem Stein, dahinter Ziegel
	BuildKit.box_mm(c, Vector3(face - 0.01, fy, zc - w * 0.5 - 0.12), Vector3(face, fy + h + 0.15, zc + w * 0.5 + 0.12), BuildKit.tex_mat("stone_dark", 0.6), false)
	BuildKit.box_mm(c, Vector3(face - 0.015, fy, zc - w * 0.5), Vector3(face - 0.01, fy + h, zc + w * 0.5), mortar, false)
	var row := 0
	var by := fy + 0.02
	while by < fy + h - 0.08:
		var bz := zc - w * 0.5 + (0.0 if row % 2 == 0 else 0.12)
		while bz < zc + w * 0.5 - 0.05:
			var bw := minf(0.24, zc + w * 0.5 - bz)
			var tone := _rng.randf_range(0.85, 1.15)
			BuildKit.box_mm(c, Vector3(face - 0.05, by, bz + 0.01), Vector3(face - 0.015, by + 0.075, bz + bw - 0.01),
					BuildKit.color_mat(Color(0.48 * tone, 0.3 * tone, 0.24 * tone), 0.9), false)
			bz += bw
		by += 0.085
		row += 1
	# Wurzeln: graue, dünne Stränge aus den Fugen, einige hängen herab
	var root_mat := BuildKit.color_mat(Color(0.42, 0.42, 0.4), 0.6)
	for k in 14:
		var p := Vector3(face - 0.05, fy + _rng.randf_range(0.2, h - 0.1), zc + _rng.randf_range(-w * 0.45, w * 0.45))
		var len := _rng.randf_range(0.15, 0.55)
		BuildKit.cylinder(c, _rng.randf_range(0.008, 0.02), len, p + Vector3(-len * 0.3, -len * 0.3, 0), root_mat, false,
				Vector3(_rng.randf_range(-30, 30), 0, _rng.randf_range(30, 70)), 0.003, 5)
	# verblasster Stempel auf einem Ziegel
	var lab := Label3D.new()
	lab.text = "WW · MP4"
	lab.font_size = 22
	lab.pixel_size = 0.0018
	lab.modulate = Color(0.12, 0.1, 0.1, 0.55)
	lab.outline_size = 0
	lab.double_sided = false
	lab.rotation_degrees.y = -90.0
	lab.position = Vector3(face - 0.055, fy + 1.05, zc + 0.15)
	c.add_child(lab)
	var note := ResearchNote.new()
	note.name = "CellarWallNote"
	note.note_id = "keller_mauer"
	note.hide_paper = true
	note.anchor = Vector3(face - 0.2, fy + 0.9, zc)
	c.add_child(note)
