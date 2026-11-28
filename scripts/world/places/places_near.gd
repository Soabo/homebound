class_name PlacesNear
extends RefCounted
## Orte in der Nähe der Hütte (hin und zurück vor der Nacht): alter Brunnen, Waldkapelle,
## Hochstand-Friedhof, Imkerei Brandl.



static func build(id: String, root: Node3D) -> bool:
	match id:
		"brunnen": _brunnen(root)
		"kapelle": _kapelle(root)
		"friedhof": _friedhof(root)
		"imkerei": _imkerei(root)
		_: return false
	return true


## Alter Brunnen hinter der Hütte: Steinring, Dach mit Kurbel, mit Brettern zugenagelt (später: Schacht).
static func _brunnen(root: Node3D) -> void:
	var stone := PlaceKit.mat("stone")
	var wood := PlaceKit.mat("wood_old")
	var y := PlaceKit.ground(root, 0, 0)
	# Steinring
	for i in 14:
		var a := TAU * i / 14.0
		BuildKit.box(root, Vector3(0.36, 0.8, 0.26), Vector3(cos(a) * 0.72, y + 0.4, sin(a) * 0.72), stone, false, Vector3(0, -rad_to_deg(a) + 90.0, 0))
	BuildKit.cylinder(root, 0.92, 0.82, Vector3(0, y + 0.41, 0), PlaceKit.mat("dark"), false, Vector3.ZERO, -1.0, 14).visible = false
	var body := BuildKit.collider_box(root, Vector3(1.8, 0.85, 1.8), Vector3(0, y + 0.42, 0))
	body.name = "WellCollider"
	# Abdeckung aus Brettern, zugenagelt (verschwindet, wenn der Schacht geöffnet wird)
	var boards := Node3D.new()
	boards.name = "Boards"
	root.add_child(boards)
	for k in 5:
		BuildKit.box(boards, Vector3(1.6, 0.04, 0.3), Vector3(0, y + 0.83, -0.6 + k * 0.3), wood, false, Vector3(0, randf_range(-4, 4), 0))
	# Offen: dunkles Loch, Schachtwinde mit Seil (erscheint erst nach dem Öffnen)
	var winch := Node3D.new()
	winch.name = "Winch"
	root.add_child(winch)
	BuildKit.cylinder(winch, 0.6, 0.04, Vector3(0, y + 0.8, 0), PlaceKit.mat("dark"), false, Vector3.ZERO, -1.0, 14)
	BuildKit.box(winch, Vector3(0.5, 0.35, 0.35), Vector3(0.0, y + 1.0, -0.62), PlaceKit.mat("metal"), false)
	BuildKit.cylinder(winch, 0.12, 0.5, Vector3(0.0, y + 1.25, -0.62), PlaceKit.mat("rust"), false, Vector3(0, 0, 90), -1.0, 10)
	BuildKit.cylinder(winch, 0.015, 1.1, Vector3(0.0, y + 1.35, 0.0), PlaceKit.mat("fabric"), false, Vector3.ZERO, -1.0, 6)
	# Dach mit Kurbel
	for sx: float in [-1.0, 1.0]:
		BuildKit.box(root, Vector3(0.1, 1.6, 0.1), Vector3(sx * 0.85, y + 1.6, 0), wood, true)
	BuildKit.cylinder(root, 0.06, 1.8, Vector3(0, y + 1.9, 0), wood, false, Vector3(0, 0, 90), -1.0, 8)
	BuildKit.box(root, Vector3(0.05, 0.3, 0.05), Vector3(0.98, y + 1.78, 0.0), PlaceKit.mat("rust"), false)
	for sx: float in [-1.0, 1.0]:
		BuildKit.box(root, Vector3(1.0, 0.04, 2.0), Vector3(sx * 0.45, y + 2.55, 0), PlaceKit.mat("shingles"), false, Vector3(0, 0, -sx * 32.0))
	var shaft := WellShaft.new()
	shaft.name = "WellShaft"
	shaft.position = Vector3(0, y, 0)
	shaft.boards = boards
	shaft.winch = winch
	root.add_child(shaft)
	PlaceKit.note(root, "brunnen_hinweis", Vector3(0.0, y + 0.55, 0.86), true)
	_brunnen_details(root, y)


## Lebendige Orte: Pflaster um den Brunnen, Moos, Eimer an der Kette, Kurbel, Seilrolle, Trog, Laub.
static func _brunnen_details(root: Node3D, y: float) -> void:
	var stone := PlaceKit.mat("stone")
	var wood := PlaceKit.mat("wood_old")
	# Pflasterring aus flachen Granitplatten
	for i in 18:
		var a := TAU * i / 18.0 + 0.1
		var r := 1.25 + (i % 2) * 0.12
		var p := PlaceKit.on_ground(root, cos(a) * r, sin(a) * r, 0.02)
		BuildKit.box(root, Vector3(0.45, 0.06, 0.32), p, stone, false, Vector3(randf_range(-3, 3), -rad_to_deg(a) + 90.0, 0))
	# Abdeckstein-Kranz auf dem Ring, Moosflecken
	var moss := PlaceDetail.col(Color(0.14, 0.19, 0.08), 1.0)
	for i in 14:
		var a := TAU * (i + 0.5) / 14.0
		BuildKit.box(root, Vector3(0.38, 0.08, 0.3), Vector3(cos(a) * 0.74, y + 0.84, sin(a) * 0.74), stone, false, Vector3(0, -rad_to_deg(a) + 90.0, 0))
		if i % 3 == 0:
			BuildKit.box(root, Vector3(0.25, 0.02, 0.2), Vector3(cos(a) * 0.76, y + 0.885, sin(a) * 0.76), moss, false, Vector3(0, -rad_to_deg(a), 0))
	# Kurbel mit Griff, Kette und Eimer (hängt am Querholz)
	var iron := PlaceDetail.col(Color(0.18, 0.12, 0.08), 0.6, 0.7)
	BuildKit.box(root, Vector3(0.04, 0.32, 0.04), Vector3(1.0, y + 1.78, 0.0), iron, false)
	BuildKit.cylinder(root, 0.025, 0.2, Vector3(1.1, y + 1.62, 0.0), wood, false, Vector3(0, 0, 90), -1.0, 6)
	BuildKit.cylinder(root, 0.1, 0.5, Vector3(0, y + 1.9, 0), PlaceDetail.col(Color(0.14, 0.14, 0.14), 0.6, 0.6), false, Vector3(0, 0, 90), -1.0, 10)
	for k in 9:
		BuildKit.cylinder(root, 0.012, 0.05, Vector3(0.1, y + 1.82 - k * 0.05, 0.0), iron, false, Vector3(0, k * 90.0, 0), -1.0, 5)
	PlaceDetail.bucket(root, Vector3(0.1, y + 1.1, 0.0), "wood_old")
	# Dachbretter, Firstbrett
	BuildKit.box(root, Vector3(0.16, 0.04, 2.04), Vector3(0, y + 2.85, 0), wood, false)
	for sz: float in [-1.0, 1.0]:
		for sx: float in [-1.0, 1.0]:
			BuildKit.box(root, Vector3(1.0, 0.12, 0.03), Vector3(sx * 0.45, y + 2.5, sz * 1.0), wood, false, Vector3(0, 0, -sx * 32.0))
	# Steintrog mit Wasser, daneben ein zweiter Eimer und ein Seil
	var tp := PlaceKit.on_ground(root, 1.9, 0.9)
	BuildKit.box(root, Vector3(1.1, 0.45, 0.5), tp + Vector3(0, 0.22, 0), stone, true, Vector3(0, 20, 0))
	var water := BuildKit.color_mat(Color(0.08, 0.1, 0.1), 0.05, 0.2)
	BuildKit.box(root, Vector3(0.95, 0.02, 0.36), tp + Vector3(0, 0.4, 0), water, false, Vector3(0, 20, 0))
	PlaceDetail.bucket(root, PlaceKit.on_ground(root, 2.6, 0.2), "metal", true)
	for k in 3:
		HandKit.tube(root, HandKit.arc(PlaceKit.on_ground(root, 1.3, -1.6, 0.03 + k * 0.03), 0.22 - k * 0.03, 0, 360, 14, Vector3.RIGHT, Vector3.FORWARD), 0.015, PlaceKit.mat("sackcloth"), 5)
	PlaceDetail.litter(root, Vector3.ZERO, 3.0, 61, 30, ["leaf", "leaf", "twig", "stone"], func(x: float, z: float) -> float: return PlaceKit.ground(root, x, z) + 0.02)
	for k in 8:
		var a := TAU * k / 8.0
		PlaceDetail.weeds(root, PlaceKit.on_ground(root, cos(a) * 1.05, sin(a) * 1.05), 610 + k, 6, 0.15)


## Waldkapelle St. Gunther (27.11. neu, so detailliert wie die Hütte): weiß gekalkte Kapelle mit Granitsockel und
## Eckquadern, steilem Schindeldach, Dachreiter mit Glocke und Zwiebelhaube, Vordach über der Rundbogentür.
## Innen: Granitboden, Bretterdecke, Kirchenbänke mit Kniebänken, Altar mit Antependium und Altarbild, Kerzen,
## Opferlichter, Kreuzweg, Votivtafeln, Liedtafel, Weihwasserbecken, Glockenseil, Spinnweben, Laub.
## Auf den Bänken liegen Steine – jeden Tag einer mehr. Knotennamen (Chapel, Candles, Matches, Stones) bleiben.
static func _kapelle(root: Node3D) -> void:
	root.rotation_degrees.y = 40.0
	const HX := 2.3
	const HZ := 3.6
	const T := 0.45
	const WALL_H := 3.2
	const FLOOR := 0.15
	const PITCH := 50.0
	var g0 := PlaceKit.ground(root, 0, 0)
	var h := Node3D.new()
	h.name = "Chapel"
	h.position = Vector3(0, g0, 0)
	root.add_child(h)
	var plaster := PlaceKit.mat("plaster")
	var granite := PlaceKit.mat("stone")
	# Sockel bis in den Hang, Granitband außen, Boden aus Granitplatten
	BuildKit.box(h, Vector3(HX * 2.0 + 0.1, 1.4, HZ * 2.0 + 0.1), Vector3(0, -0.6, 0), PlaceKit.mat("stone_dark"), true)
	BuildKit.box(h, Vector3(HX * 2.0 - T * 2.0 + 0.02, FLOOR, HZ * 2.0 - T * 2.0 + 0.02), Vector3(0, FLOOR * 0.5, 0), PlaceKit.mat("paving"), true)
	# Wände (wall-lokal: +z = außen)
	var front := BuildKit.wall(h, Vector2(-HX, HZ - T * 0.5), Vector2(HX, HZ - T * 0.5), 0.0, WALL_H, T, plaster, [Vector4(HX, 1.3, 0.0, 2.5)], "Front")
	var back := BuildKit.wall(h, Vector2(HX, -HZ + T * 0.5), Vector2(-HX, -HZ + T * 0.5), 0.0, WALL_H, T, plaster, [], "Back")
	var win_open := [Vector4(1.775, 0.7, 1.3, 2.8), Vector4(4.375, 0.7, 1.3, 2.8)]
	var left := BuildKit.wall(h, Vector2(-HX + T * 0.5, -HZ + T), Vector2(-HX + T * 0.5, HZ - T), 0.0, WALL_H, T, plaster, win_open, "Left")
	var right := BuildKit.wall(h, Vector2(HX - T * 0.5, HZ - T), Vector2(HX - T * 0.5, -HZ + T), 0.0, WALL_H, T, plaster, [Vector4(2.825, 0.7, 1.3, 2.8), Vector4(5.425, 0.7, 1.3, 2.8)], "Right")
	# Rundbogen über Tür und Fenstern, Bleiglasfenster mit Gitter
	PlaceDetail.arch_fill(front, Vector3(HX, 1.85, 0), 1.3, T, plaster)
	var amber := Color(0.75, 0.6, 0.3, 0.55)
	for w: Node3D in [left, right]:
		var ats: Array = [1.775, 4.375] if w == left else [2.825, 5.425]
		for at: float in ats:
			PlaceDetail.arch_fill(w, Vector3(at, 2.45, 0), 0.7, T, plaster)
			PlaceDetail.window(w, Vector3(at, 1.3, 0.04), 0.0, 0.7, 1.5, T, "arch", amber, "furn", 1, true)
	# Granit: Sockelband, Eckquader, Türgewände
	for side in 4:
		var along := HX * 2.0 if side % 2 == 0 else HZ * 2.0
		var nrm := [Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(-1, 0, 0)][side] as Vector3
		var off := HZ if side % 2 == 0 else HX
		var size := Vector3(along + 0.1, 0.42, 0.06) if side % 2 == 0 else Vector3(0.06, 0.42, along + 0.1)
		BuildKit.box(h, size, nrm * (off + 0.02) + Vector3(0, 0.21, 0), granite, false)
	for cx: float in [-1.0, 1.0]:
		for cz: float in [-1.0, 1.0]:
			for k in 6:
				var y := 0.6 + k * 0.42
				var long_x := k % 2 == 0
				BuildKit.box(h, Vector3(0.55 if long_x else 0.3, 0.38, 0.04), Vector3(cx * (HX - (0.275 if long_x else 0.15)), y, cz * (HZ + 0.02)), granite, false)
				BuildKit.box(h, Vector3(0.04, 0.38, 0.3 if long_x else 0.55), Vector3(cx * (HX + 0.02), y, cz * (HZ - (0.15 if long_x else 0.275))), granite, false)
	# Türgewände aus Granit mit Bogen, Tür (zweiflügelig, rechter Flügel halb offen)
	for sx: float in [-1.0, 1.0]:
		BuildKit.box(h, Vector3(0.16, 1.85, 0.12), Vector3(sx * 0.73, 0.925, HZ + 0.03), granite, false)
	HandKit.tube(h, HandKit.arc(Vector3(0, 1.85, HZ + 0.03), 0.73, 0, 180, 16), 0.08, granite, 6, Vector3(0, 0, 1))
	BuildKit.box(h, Vector3(0.16, 0.2, 0.14), Vector3(0, 2.6, HZ + 0.04), granite, false)   # Schlussstein
	PlaceDetail.door(h, Vector3(0, FLOOR, HZ - T * 0.5), 0.0, 1.3, 2.5, "arch", 55.0, true, "wood_old")
	# Stufen vor der Tür
	for k in 2:
		BuildKit.box(h, Vector3(1.8 - k * 0.2, 0.15, 0.4), Vector3(0, FLOOR - 0.075 - k * 0.15, HZ + 0.25 + k * 0.35), granite, true)
	# Giebel, Gesims
	var rise := HX * tan(deg_to_rad(PITCH))
	for sz: float in [-1.0, 1.0]:
		BuildKit.gable(h, HX * 2.0, rise, T, Vector3(0, WALL_H, sz * (HZ - T * 0.5)), 0.0, plaster)
	for sx: float in [-1.0, 1.0]:
		BuildKit.box(h, Vector3(0.12, 0.1, HZ * 2.0 + 0.1), Vector3(sx * (HX + 0.04), WALL_H - 0.05, 0), PlaceKit.mat("wood_old"), false)
	# Rundfenster im Frontgiebel (Okulus)
	var gm := BuildKit.glass_mat().duplicate() as StandardMaterial3D
	gm.albedo_color = Color(0.4, 0.5, 0.6, 0.6)
	BuildKit.cylinder(h, 0.3, 0.02, Vector3(0, WALL_H + 1.1, HZ + 0.01), gm, false, Vector3(90, 0, 0), -1.0, 18)
	HandKit.tube(h, HandKit.arc(Vector3(0, WALL_H + 1.1, HZ + 0.02), 0.32, 0, 360, 20), 0.035, granite, 6, Vector3(0, 0, 1))
	# Dach: zwei Schindelflächen mit Überstand, Stirnbretter, Firstbrett
	var eave := 0.5
	var run := HX + eave
	var slope_len := run / cos(deg_to_rad(PITCH)) + 0.12
	var ridge_y := WALL_H + rise
	for sx: float in [-1.0, 1.0]:
		var cx2 := sx * run * 0.5
		var cy2 := ridge_y - run * tan(deg_to_rad(PITCH)) * 0.5 + 0.09
		BuildKit.box(h, Vector3(slope_len, 0.12, HZ * 2.0 + 0.7), Vector3(cx2, cy2, 0), PlaceKit.mat("shingles"), true, Vector3(0, 0, -sx * PITCH))
		# Ortgang-Bretter an den Giebelseiten
		for sz: float in [-1.0, 1.0]:
			BuildKit.box(h, Vector3(slope_len, 0.22, 0.04), Vector3(cx2, cy2 - 0.08, sz * (HZ + 0.36)), PlaceKit.mat("wood_old"), false, Vector3(0, 0, -sx * PITCH))
		# Traufbrett und Rinne
		var ex := sx * (run - 0.02)
		var ey := ridge_y - run * tan(deg_to_rad(PITCH)) + 0.02
		BuildKit.box(h, Vector3(0.04, 0.2, HZ * 2.0 + 0.7), Vector3(ex, ey, 0), PlaceKit.mat("wood_old"), false)
		PlaceDetail.gutter(h, Vector3(ex + sx * 0.06, ey - 0.06, -HZ - 0.3), Vector3(ex + sx * 0.06, ey - 0.06, HZ + 0.25), FLOOR - 0.15, "rust",
				Vector3(-sx * (eave + 0.02), 0, -0.45))
	BuildKit.box(h, Vector3(0.26, 0.06, HZ * 2.0 + 0.72), Vector3(0, ridge_y + 0.17, 0), PlaceKit.mat("wood_old"), false)
	_kapelle_turret(h, Vector3(0, ridge_y, HZ - 1.0))
	# Vordach über der Tür auf zwei Kopfbändern
	for sx: float in [-1.0, 1.0]:
		BuildKit.box(h, Vector3(0.9, 0.05, 1.4), Vector3(sx * 0.45, 3.0, HZ + 0.5), PlaceKit.mat("shingles"), false, Vector3(0, 0, -sx * 30.0))
		BuildKit.beam_between(h, Vector3(sx * 0.85, 2.2, HZ + 0.02), Vector3(sx * 0.85, 2.72, HZ + 1.05), 0.08, PlaceKit.mat("wood_old"))
	# Innen: Bretterdecke mit Unterzügen
	var ceil_y := WALL_H - 0.08
	BuildKit.box(h, Vector3(HX * 2.0 - T * 2.0, 0.04, HZ * 2.0 - T * 2.0), Vector3(0, ceil_y, 0), PlaceKit.mat("wood_h"), false)
	for k in 4:
		BuildKit.box(h, Vector3(HX * 2.0 - T * 2.0, 0.14, 0.14), Vector3(0, ceil_y - 0.09, -2.4 + k * 1.6), PlaceKit.mat("wood_old"), false)
	_kapelle_inside(h, FLOOR, HX - T, HZ - T, ceil_y)
	# Außen: Bank, Feldkreuz, Weg aus Granitplatten, Laub, Unkraut am Sockel
	var bench := Node3D.new()
	bench.name = "OutsideBench"
	bench.position = Vector3(HX + 0.45, FLOOR - 0.15, 1.2)
	bench.rotation_degrees.y = 90.0
	h.add_child(bench)
	PlaceDetail.pew(bench, Vector3.ZERO, 1.4, "wood_old")
	_kapelle_cross(root, Vector3(3.6, 0, 5.8))
	for k in 7:
		var p := Vector3(0.0 + sin(k * 1.3) * 0.15, 0, HZ + 1.2 + k * 0.75)
		p.y = PlaceKit.ground(root, p.x, p.z) + 0.03
		BuildKit.box(root, Vector3(randf_range(0.6, 0.8), 0.06, randf_range(0.45, 0.6)), p, PlaceKit.mat("stone"), false, Vector3(0, randf_range(-15, 15), 0))
	PlaceDetail.litter(root, Vector3(0, 0, HZ + 2.0), 3.5, 401, 40, ["leaf", "leaf", "twig"], func(x: float, z: float) -> float: return PlaceKit.ground(root, x, z))
	for k in 10:
		var a := k * 0.7
		PlaceDetail.weeds(h, Vector3(cos(a) * (HX + 0.15) if k % 2 == 0 else (HX + 0.1) * (1.0 if k % 4 == 1 else -1.0), FLOOR - 0.15, sin(a) * HZ), 900 + k, 6, 0.3)


## Dachreiter: Holztürmchen mit Schallöffnungen, Glocke, Zwiebelhaube aus Blech, Kreuz.
static func _kapelle_turret(h: Node3D, at: Vector3) -> void:
	var t := Node3D.new()
	t.name = "Turret"
	t.position = at
	h.add_child(t)
	var wood := PlaceKit.mat("wood_old")
	BuildKit.box(t, Vector3(0.9, 0.9, 0.9), Vector3(0, -0.15, 0), PlaceKit.mat("plaster"), false)
	# Glockenstube: vier Eckpfosten, Schallläden, Glocke
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			BuildKit.box(t, Vector3(0.1, 0.9, 0.1), Vector3(sx * 0.4, 0.75, sz * 0.4), wood, false)
	for side in 4:
		var rot := side * 90.0
		var n := Node3D.new()
		n.rotation_degrees.y = rot
		t.add_child(n)
		for k in 3:
			BuildKit.box(n, Vector3(0.7, 0.08, 0.02), Vector3(0, 0.45 + k * 0.1, 0.4), wood, false, Vector3(35, 0, 0))
		BuildKit.box(n, Vector3(0.9, 0.08, 0.08), Vector3(0, 1.22, 0.42), wood, false)
	var bronze := BuildKit.color_mat(Color(0.42, 0.33, 0.16), 0.35, 0.85)
	BuildKit.lathe(t, PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.2, 0.0), Vector2(0.18, 0.05), Vector2(0.14, 0.2), Vector2(0.12, 0.33), Vector2(0.05, 0.38), Vector2(0.0, 0.38)]),
			Vector3(0, 0.62, 0), bronze, 14)
	BuildKit.box(t, Vector3(0.7, 0.06, 0.06), Vector3(0, 1.05, 0), wood, false)
	# Zwiebelhaube (grüne Patina) mit Kreuz
	var patina := BuildKit.color_mat(Color(0.32, 0.5, 0.42), 0.55, 0.4)
	BuildKit.box(t, Vector3(1.0, 0.08, 1.0), Vector3(0, 1.28, 0), wood, false)
	BuildKit.lathe(t, PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.52, 0.0), Vector2(0.56, 0.12), Vector2(0.5, 0.32), Vector2(0.32, 0.55),
			Vector2(0.14, 0.78), Vector2(0.1, 0.92), Vector2(0.14, 1.02), Vector2(0.08, 1.12), Vector2(0.03, 1.3), Vector2(0.0, 1.32)]), Vector3(0, 1.32, 0), patina, 16)
	var iron := BuildKit.color_mat(Color(0.12, 0.11, 0.1), 0.5, 0.7)
	BuildKit.box(t, Vector3(0.04, 0.6, 0.04), Vector3(0, 2.9, 0), iron, false)
	BuildKit.box(t, Vector3(0.3, 0.04, 0.04), Vector3(0, 3.0, 0), iron, false)
	BuildKit.sphere(t, 0.06, Vector3(0, 2.64, 0), BuildKit.color_mat(Color(0.75, 0.6, 0.25), 0.3, 0.9), Vector3.ONE, 10)


## Innenraum der Kapelle. ix/iz = halbe Innenmaße, y = Bodenhöhe.
static func _kapelle_inside(h: Node3D, y: float, ix: float, iz: float, ceil_y: float) -> void:
	# Altarstufe, Kommunionbank mit Durchgang
	BuildKit.box(h, Vector3(ix * 2.0, 0.15, 1.2), Vector3(0, y + 0.075, -iz + 0.6), PlaceKit.mat("stone"), true)
	var rail := PlaceKit.mat("furn")
	for sx: float in [-1.0, 1.0]:
		BuildKit.box(h, Vector3(ix - 0.4, 0.06, 0.16), Vector3(sx * (ix * 0.5 + 0.2), y + 0.8, -iz + 1.22), rail, false)
		for k in 5:
			BuildKit.cylinder(h, 0.025, 0.72, Vector3(sx * (0.5 + k * (ix - 0.5) / 4.6), y + 0.42, -iz + 1.22), rail, false, Vector3.ZERO, 0.02, 8)
		BuildKit.collider_box(h, Vector3(ix - 0.4, 0.8, 0.16), Vector3(sx * (ix * 0.5 + 0.2), y + 0.4, -iz + 1.22))
	var ay := y + 0.15
	# Altar: Steintisch, weißes Tuch, rotes Antependium mit Goldborte
	BuildKit.box(h, Vector3(1.5, 0.95, 0.7), Vector3(0, ay + 0.475, -iz + 0.5), PlaceKit.mat("stone"), true)
	BuildKit.box(h, Vector3(1.62, 0.025, 0.78), Vector3(0, ay + 0.96, -iz + 0.5), PlaceDetail.col(Color(0.92, 0.9, 0.84), 0.9), false)
	BuildKit.box(h, Vector3(1.6, 0.25, 0.01), Vector3(0, ay + 0.84, -iz + 0.895), PlaceDetail.col(Color(0.92, 0.9, 0.84), 0.9), false)
	BuildKit.box(h, Vector3(1.3, 0.6, 0.01), Vector3(0, ay + 0.4, -iz + 0.86), PlaceDetail.col(Color(0.5, 0.08, 0.07), 0.8), false)
	BuildKit.box(h, Vector3(1.3, 0.03, 0.012), Vector3(0, ay + 0.68, -iz + 0.862), PlaceDetail.col(Color(0.75, 0.6, 0.25), 0.3, 0.9), false)
	BuildKit.box(h, Vector3(0.2, 0.2, 0.012), Vector3(0, ay + 0.42, -iz + 0.862), PlaceDetail.col(Color(0.75, 0.6, 0.25), 0.3, 0.9), false, Vector3(0, 0, 45))
	# Altaraufbau: Säulen, Altarbild (St. Gunther als Einsiedler im Wald), Kreuz, Gesims
	var gold := PlaceDetail.col(Color(0.7, 0.55, 0.22), 0.35, 0.85)
	var wall_z := -iz + 0.04
	BuildKit.box(h, Vector3(1.8, 0.3, 0.2), Vector3(0, ay + 1.12, wall_z + 0.1), PlaceKit.mat("furn"), false)
	for sx: float in [-1.0, 1.0]:
		BuildKit.cylinder(h, 0.07, 1.5, Vector3(sx * 0.72, ay + 2.0, wall_z + 0.12), PlaceDetail.col(Color(0.45, 0.18, 0.12), 0.4), false, Vector3.ZERO, 0.06, 12)
		BuildKit.box(h, Vector3(0.2, 0.08, 0.2), Vector3(sx * 0.72, ay + 2.78, wall_z + 0.12), gold, false)
	PlaceDetail.picture(h, Vector3(0, ay + 1.95, wall_z + 0.02), Vector2(1.1, 1.3), 0.0, Color(0.7, 0.55, 0.22),
			[Color(0.12, 0.16, 0.12), Color(0.1, 0.08, 0.06)], true)
	# angedeutete Figur im Bild: Einsiedler in brauner Kutte, Heiligenschein
	BuildKit.box(h, Vector3(0.18, 0.55, 0.004), Vector3(-0.1, ay + 1.75, wall_z + 0.03), PlaceDetail.col(Color(0.32, 0.2, 0.12), 0.9), false)
	BuildKit.cylinder(h, 0.06, 0.004, Vector3(-0.1, ay + 2.08, wall_z + 0.03), PlaceDetail.col(Color(0.85, 0.7, 0.4), 0.9), false, Vector3(90, 0, 0), -1.0, 10)
	BuildKit.cylinder(h, 0.1, 0.003, Vector3(-0.1, ay + 2.1, wall_z + 0.029), gold, false, Vector3(90, 0, 0), -1.0, 14)
	for k in 5:
		BuildKit.box(h, Vector3(0.04, 0.5 + k * 0.08, 0.004), Vector3(0.12 + k * 0.08, ay + 1.6 + k * 0.04, wall_z + 0.03), PlaceDetail.col(Color(0.08, 0.14, 0.08), 0.9), false)
	BuildKit.box(h, Vector3(1.9, 0.12, 0.26), Vector3(0, ay + 2.86, wall_z + 0.12), PlaceKit.mat("furn"), false)
	BuildKit.box(h, Vector3(0.06, 0.5, 0.04), Vector3(0, ay + 3.15 - 0.2, wall_z + 0.2), PlaceKit.mat("furn"), false)
	# Kreuz auf dem Altar, Leuchter mit Kerzen, Vasen mit Trockenblumen
	BuildKit.box(h, Vector3(0.04, 0.42, 0.03), Vector3(0, ay + 1.18, -iz + 0.38), gold, false)
	BuildKit.box(h, Vector3(0.2, 0.035, 0.03), Vector3(0, ay + 1.3, -iz + 0.38), gold, false)
	for sx: float in [-1.0, 1.0]:
		BuildKit.lathe(h, PackedVector2Array([Vector2(0, 0), Vector2(0.07, 0), Vector2(0.06, 0.02), Vector2(0.015, 0.06), Vector2(0.02, 0.2), Vector2(0.04, 0.24), Vector2(0, 0.24)]),
				Vector3(sx * 0.5, ay + 0.97, -iz + 0.42), gold, 10)
		PlaceDetail.candle(h, Vector3(sx * 0.5, ay + 1.21, -iz + 0.42), 0.26, true, sx > 0.0, 0.02)
		BuildKit.lathe(h, PackedVector2Array([Vector2(0, 0), Vector2(0.05, 0), Vector2(0.07, 0.08), Vector2(0.04, 0.2), Vector2(0.05, 0.24), Vector2(0, 0.24)]),
				Vector3(sx * 0.28, ay + 0.97, -iz + 0.62), PlaceDetail.col(Color(0.82, 0.8, 0.75), 0.3), 10)
		for f in 6:
			var a := f * 1.05
			BuildKit.cylinder(h, 0.005, 0.32, Vector3(sx * 0.28 + cos(a) * 0.02, ay + 1.33, -iz + 0.62 + sin(a) * 0.02), PlaceDetail.col(Color(0.45, 0.38, 0.22), 1.0), false,
					Vector3(cos(a) * 12.0, 0, sin(a) * 12.0), 0.003, 4)
			BuildKit.sphere(h, 0.022, Vector3(sx * 0.28 + cos(a) * 0.06, ay + 1.5, -iz + 0.62 + sin(a) * 0.06), PlaceDetail.col(Color(0.5, 0.32, 0.3), 1.0), Vector3(1, 0.7, 1), 6)
	PlaceKit.loot(h, "Candles", "candles", 4, Vector3(0.62, ay + 0.97, -iz + 0.68), "candles")
	PlaceKit.loot(h, "Matches", "matches", 1, Vector3(-0.62, ay + 0.97, -iz + 0.7), "box")
	# Ewiges Licht (rote Ampel) an der Kette
	var lamp := Node3D.new()
	lamp.position = Vector3(0.9, ceil_y - 0.15, -iz + 1.2)
	h.add_child(lamp)
	BuildKit.cylinder(lamp, 0.004, 0.9, Vector3(0, -0.45, 0), PlaceDetail.col(Color(0.6, 0.5, 0.2), 0.4, 0.8), false, Vector3.ZERO, -1.0, 4)
	PlaceDetail.votive(lamp, Vector3(0, -1.0, 0), true)
	# Bänke (je drei pro Seite), Steine darauf
	var benches: Array[Vector3] = []
	for row in 3:
		for sx: float in [-1.0, 1.0]:
			var p := Vector3(sx * 1.08, y, 1.55 - row * 1.0)
			benches.append(p)
			PlaceDetail.pew(h, p, 1.25, "cabinet")
	PlaceKit.note(h, "stef_kapelle", Vector3(-1.08, y, 1.75))
	# Weihwasserbecken, Lesepult mit Gästebuch, Opferlichter, Opferstock, Glockenseil
	BuildKit.lathe(h, PackedVector2Array([Vector2(0, 0), Vector2(0.06, 0), Vector2(0.06, 0.04), Vector2(0.16, 0.12), Vector2(0.16, 0.16), Vector2(0.13, 0.16), Vector2(0.12, 0.13), Vector2(0, 0.13)]),
			Vector3(-0.95, y + 0.95, iz - 0.12), PlaceKit.mat("stone"), 14)
	BuildKit.box(h, Vector3(0.12, 0.95, 0.12), Vector3(-0.95, y + 0.475, iz - 0.12), PlaceKit.mat("stone"), false)
	var lect := Node3D.new()
	lect.position = Vector3(-1.45, y, iz - 0.75)
	lect.rotation_degrees.y = 60.0
	h.add_child(lect)
	BuildKit.box(lect, Vector3(0.1, 1.05, 0.1), Vector3(0, 0.525, 0), PlaceKit.mat("furn"), true)
	BuildKit.box(lect, Vector3(0.5, 0.03, 0.38), Vector3(0, 1.1, 0), PlaceKit.mat("furn"), false, Vector3(-18, 0, 0))
	BuildKit.box(lect, Vector3(0.36, 0.035, 0.26), Vector3(0, 1.135, 0.01), PlaceDetail.col(Color(0.35, 0.12, 0.08), 0.8), false, Vector3(-18, 0, 0))
	BuildKit.box(lect, Vector3(0.34, 0.006, 0.24), Vector3(0, 1.155, 0.01), PlaceKit.mat("paper"), false, Vector3(-18, 0, 0))
	BuildKit.cylinder(lect, 0.004, 0.14, Vector3(0.12, 1.17, 0.02), PlaceDetail.col(Color(0.1, 0.1, 0.3)), false, Vector3(0, 30, 80), -1.0, 4)
	PlaceKit.note(lect, "kapelle_buch", Vector3(0, 1.0, 0.05))
	var stand := Node3D.new()
	stand.name = "VotiveStand"
	stand.position = Vector3(1.4, y, iz - 0.55)
	h.add_child(stand)
	var iron := PlaceDetail.col(Color(0.1, 0.09, 0.08), 0.6, 0.7)
	BuildKit.box(stand, Vector3(0.7, 0.03, 0.35), Vector3(0, 0.8, 0), iron, true)
	BuildKit.box(stand, Vector3(0.7, 0.03, 0.25), Vector3(0, 0.95, -0.08), iron, false)
	for sx: float in [-1.0, 1.0]:
		BuildKit.box(stand, Vector3(0.03, 0.95, 0.03), Vector3(sx * 0.33, 0.475, 0.12), iron, false)
		BuildKit.box(stand, Vector3(0.03, 0.95, 0.03), Vector3(sx * 0.33, 0.475, -0.12), iron, false)
	var lit_count := 0
	for k in 10:
		var tier := k / 5
		var lit := (k * 7) % 3 != 0
		PlaceDetail.votive(stand, Vector3(-0.26 + (k % 5) * 0.13, 0.815 + tier * 0.15, 0.06 - tier * 0.14), lit)
		lit_count += 1 if lit else 0
	var vl := OmniLight3D.new()
	vl.light_color = Color(1.0, 0.45, 0.3)
	vl.light_energy = 0.55
	vl.omni_range = 3.2
	vl.shadow_enabled = false
	vl.position = Vector3(0, 1.2, 0.1)
	stand.add_child(vl)
	BuildKit.box(h, Vector3(0.22, 0.32, 0.18), Vector3(1.4, y + 0.16, iz - 0.15), iron, true)   # Opferstock
	BuildKit.box(h, Vector3(0.1, 0.008, 0.02), Vector3(1.4, y + 0.325, iz - 0.15), PlaceDetail.col(Color(0.02, 0.02, 0.02)), false)
	PlaceDetail.sign(h, "Für die Armen\nder Pfarrei", Vector3(1.4, y + 0.5, iz - 0.02), Vector2(0.24, 0.12), 180.0, Color(0.85, 0.82, 0.72), Color(0.1, 0.08, 0.06), 20, false)
	BuildKit.cylinder(h, 0.012, ceil_y - y - 0.9, Vector3(0.75, y + 0.9 + (ceil_y - y - 0.9) * 0.5, iz - 0.3), PlaceKit.mat("sackcloth"), false, Vector3.ZERO, -1.0, 6)
	BuildKit.sphere(h, 0.035, Vector3(0.75, y + 0.88, iz - 0.3), PlaceKit.mat("sackcloth"), Vector3(1, 1.6, 1), 6)
	# Kreuzweg (je drei Stationen pro Seite), Votivtafeln beim Altar, Liedtafel
	for sx: float in [-1.0, 1.0]:
		for k in 3:
			var z := 1.6 - k * 1.25
			if absf(z - (-1.6)) < 0.5 or absf(z - 1.0) < 0.5:
				z += 0.55
			var pic := PlaceDetail.picture(h, Vector3(sx * (ix - 0.02), y + 1.95, z), Vector2(0.26, 0.32), -sx * 90.0, Color(0.3, 0.22, 0.12),
					[Color(0.35, 0.3, 0.25), Color(0.28, 0.22, 0.15)])
			var lab := Label3D.new()
			lab.text = ["I", "IV", "VII", "X", "XII", "XIV"][k + (0 if sx < 0.0 else 3)]
			lab.font_size = 22
			lab.pixel_size = 0.0018
			lab.modulate = Color(0.1, 0.08, 0.05)
			lab.outline_size = 0
			lab.position = Vector3(0, 0.22, 0.02)
			pic.add_child(lab)
			BuildKit.box(pic, Vector3(0.012, 0.06, 0.012), Vector3(0, 0.22, 0.02), PlaceDetail.col(Color(0.2, 0.15, 0.1)), false)
	for k in 4:
		PlaceDetail.picture(h, Vector3(ix - 0.02, y + 1.0 + (k % 2) * 0.3, -iz + 0.45 + (k / 2) * 0.3), Vector2(0.18, 0.22), -90.0, Color(0.5, 0.4, 0.25),
				[Color(0.6, 0.55, 0.42), Color(0.45, 0.38, 0.28)])
	var hymn := PlaceDetail.sign(h, "84\n312\n—\n27", Vector3(-ix + 0.02, y + 1.8, -iz + 1.6), Vector2(0.3, 0.55), 90.0, Color(0.18, 0.12, 0.08), Color(0.9, 0.86, 0.75), 46)
	hymn.name = "HymnBoard"
	# Spinnweben, Laub an der Tür, ein umgekippter Strauß
	PlaceDetail.cobweb(h, Vector3(-ix, ceil_y - 0.1, -iz), Vector3(1, 0, 0), Vector3(0, 0, 1), 0.45)
	PlaceDetail.cobweb(h, Vector3(ix, ceil_y - 0.1, iz), Vector3(-1, 0, 0), Vector3(0, 0, -1), 0.4)
	PlaceDetail.cobweb(h, Vector3(-ix, ceil_y - 0.1, iz), Vector3(1, 0, 0), Vector3(0, 0, -1), 0.3)
	PlaceDetail.litter(h, Vector3(0.3, y, iz - 0.5), 0.9, 77, 18, ["leaf", "leaf", "leaf", "twig"])
	# Steine auf den Bänken (wächst mit den Tagen)
	var stones := Node3D.new()
	stones.name = "Stones"
	h.add_child(stones)
	var place := func() -> void:
		for c in stones.get_children():
			c.queue_free()
		var count := clampi(TimeManager.day + 3, 4, 18)
		var rng := RandomNumberGenerator.new()
		rng.seed = 4711
		for i in count:
			var b := benches[i % benches.size()]
			var off := -0.5 + (i / benches.size()) * 0.33
			BuildKit.sphere(stones, rng.randf_range(0.05, 0.08), b + Vector3(off, 0.5, rng.randf_range(-0.06, 0.1)), PlaceKit.mat("stone_dark"), Vector3(1.2, 0.7, 1.0), 6)
	place.call()
	# Die Verbindung muss mit dem Ort verschwinden – sonst ruft die Uhr nach einem Neustart
	# (Tod, neuer Tag) noch die alte, längst gelöschte Kapelle auf.
	var on_day := func(_d: int) -> void: place.call()
	TimeManager.day_changed.connect(on_day)
	stones.tree_exiting.connect(func() -> void:
		if TimeManager.day_changed.is_connected(on_day):
			TimeManager.day_changed.disconnect(on_day))


## Feldkreuz mit kleinem Dach und Herrgott, davor Grablicht und Trockenblumen.
static func _kapelle_cross(root: Node3D, at: Vector3) -> void:
	var g := PlaceKit.ground(root, at.x, at.z)
	var c := Node3D.new()
	c.name = "FieldCross"
	c.position = Vector3(at.x, g, at.z)
	c.rotation_degrees.y = -20.0
	root.add_child(c)
	var wood := PlaceKit.mat("wood_old")
	BuildKit.box(c, Vector3(0.6, 0.3, 0.6), Vector3(0, 0.1, 0), PlaceKit.mat("stone"), true)
	BuildKit.box(c, Vector3(0.14, 3.0, 0.12), Vector3(0, 1.6, 0), wood, true)
	BuildKit.box(c, Vector3(1.3, 0.12, 0.1), Vector3(0, 2.5, 0), wood, false)
	for sx: float in [-1.0, 1.0]:
		BuildKit.box(c, Vector3(0.5, 0.03, 0.4), Vector3(sx * 0.22, 3.2, 0.08), PlaceKit.mat("tin"), false, Vector3(0, 0, -sx * 28.0))
	var body := PlaceDetail.col(Color(0.82, 0.75, 0.62), 0.6)
	BuildKit.box(c, Vector3(0.1, 0.55, 0.06), Vector3(0, 2.2, 0.1), body, false)
	BuildKit.sphere(c, 0.05, Vector3(0, 2.5, 0.11), body, Vector3.ONE, 8)
	for sx: float in [-1.0, 1.0]:
		BuildKit.box(c, Vector3(0.38, 0.045, 0.04), Vector3(sx * 0.2, 2.44, 0.1), body, false, Vector3(0, 0, sx * 12.0))
	BuildKit.box(c, Vector3(0.14, 0.18, 0.06), Vector3(0, 1.95, 0.1), PlaceDetail.col(Color(0.88, 0.86, 0.8)), false)
	PlaceDetail.votive(c, Vector3(0.15, 0.25, 0.25), true)
	PlaceDetail.votive(c, Vector3(-0.12, 0.25, 0.22), false)


## Hochstand-Friedhof: ein Dutzend umgestürzter Hochsitze im Kreis, alle zur Mitte gedreht.
static func _friedhof(root: Node3D) -> void:
	var wood := PlaceKit.mat("wood_old")
	var rng := RandomNumberGenerator.new()
	rng.seed = 1212
	for i in 12:
		var a := TAU * i / 12.0
		var r := 14.0 + rng.randf_range(-1.0, 1.5)
		var p := Vector3(cos(a) * r, 0, sin(a) * r)
		p.y = PlaceKit.ground(root, p.x, p.z)
		var stand := Node3D.new()
		stand.name = "Stand_%d" % i
		stand.position = p
		root.add_child(stand)
		# Blick zur Mitte
		stand.rotation.y = atan2(-p.x, -p.z)
		var fallen := i % 3 != 0
		if fallen:
			stand.rotation_degrees.x = rng.randf_range(-78.0, -62.0)
		for sx: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				BuildKit.cylinder(stand, 0.07, 3.2, Vector3(sx * 0.6, 1.6, sz * 0.6), wood, false, Vector3(sz * 4.0, 0, -sx * 4.0), 0.06, 6)
		BuildKit.box(stand, Vector3(1.5, 0.08, 1.5), Vector3(0, 3.2, 0), wood, false)
		BuildKit.box(stand, Vector3(1.4, 0.7, 0.06), Vector3(0, 3.6, -0.7), wood, false)
		for sx: float in [-1.0, 1.0]:
			BuildKit.box(stand, Vector3(0.06, 0.7, 1.4), Vector3(sx * 0.7, 3.6, 0), wood, false)
		BuildKit.box(stand, Vector3(1.6, 0.06, 1.6), Vector3(0, 4.2, 0), PlaceKit.mat("shingles"), false, Vector3(-10, 0, 0))
		# Leiter, unten abgesägt
		for k in 6:
			BuildKit.box(stand, Vector3(0.5, 0.05, 0.05), Vector3(0, 1.4 + k * 0.32, 0.95), wood, false)
		BuildKit.collider_box(root, Vector3(1.6, 1.2 if fallen else 4.0, 1.6), p + Vector3(0, 0.6 if fallen else 2.0, 0))
	# In der Mitte: verbrannter Kreis aus Steinen
	for i in 9:
		var a := TAU * i / 9.0
		var p := Vector3(cos(a) * 2.2, 0, sin(a) * 2.2)
		BuildKit.sphere(root, rng.randf_range(0.18, 0.28), PlaceKit.on_ground(root, p.x, p.z, 0.08), PlaceKit.mat("stone"), Vector3(1.2, 0.7, 1.0), 7)
	BuildKit.cylinder(root, 1.9, 0.02, PlaceKit.on_ground(root, 0, 0, 0.02), BuildKit.color_mat(Color(0.05, 0.045, 0.04)), false, Vector3.ZERO, -1.0, 18)
	# Funde
	PlaceKit.loot(root, "Binoculars", "binoculars", 1, PlaceKit.on_ground(root, 11.5, 3.5), "tool", 1, 30.0)
	PlaceKit.loot(root, "Wood", "wood", 6, PlaceKit.on_ground(root, -10.0, 7.0), "logs", 2)
	PlaceKit.loot(root, "Scrap", "scrap", 4, PlaceKit.on_ground(root, 6.0, -11.5), "parts", 2)
	var post := PlaceKit.on_ground(root, 0.0, 3.4)
	BuildKit.box(root, Vector3(0.1, 1.4, 0.1), post + Vector3(0, 0.7, 0), wood, true)
	PlaceKit.note(root, "friedhof_liste", post + Vector3(0, 1.1, 0.06), true)
	_friedhof_details(root, rng)


## Lebendige Orte: Sitzbretter, Schießscharten, Strichlisten in den Pfosten, herumliegende Sprossen und Bretter,
## verkohlte Scheite in der Mitte, Geweih, Blechdose als Laterne, Zettelpfosten mit Schutzdach, Laub.
static func _friedhof_details(root: Node3D, rng: RandomNumberGenerator) -> void:
	var wood := PlaceKit.mat("wood_old")
	for i in 12:
		var stand := root.get_node_or_null("Stand_%d" % i) as Node3D
		if stand == null:
			continue
		BuildKit.box(stand, Vector3(1.2, 0.05, 0.3), Vector3(0, 3.65, -0.45), wood, false)
		BuildKit.box(stand, Vector3(1.3, 0.05, 0.2), Vector3(0, 3.95, 0.68), wood, false)
		for k in rng.randi_range(3, 7):
			BuildKit.box(stand, Vector3(0.008, 0.08, 0.004), Vector3(-0.66 + k * 0.025, 1.4, 0.66), PlaceDetail.col(Color(0.12, 0.1, 0.08)), false)
		if i % 4 == 1:
			BuildKit.cylinder(stand, 0.04, 0.09, Vector3(0.5, 3.4, -0.62), PlaceKit.mat("rust"), false, Vector3.ZERO, -1.0, 8)
	# herumliegende Leitersprossen und Bretter
	for k in 14:
		var a := rng.randf() * TAU
		var r := rng.randf_range(4.0, 12.0)
		var p := PlaceKit.on_ground(root, cos(a) * r, sin(a) * r, 0.03)
		BuildKit.box(root, Vector3(rng.randf_range(0.5, 1.6), 0.04, 0.1 if k % 2 == 0 else 0.22), p, wood, false, Vector3(rng.randf_range(-6, 6), rng.randf() * 360.0, 0))
	# verkohlte Scheite und Asche in der Mitte, Geweih
	var char := PlaceDetail.col(Color(0.06, 0.05, 0.045), 1.0)
	for k in 7:
		var a := TAU * k / 7.0
		BuildKit.cylinder(root, 0.06, 0.8, PlaceKit.on_ground(root, cos(a) * 0.5, sin(a) * 0.5, 0.08), char, false, Vector3(80, -rad_to_deg(a), 0), 0.04, 6)
	var bone := PlaceDetail.col(Color(0.82, 0.78, 0.68), 0.7)
	var ant := PlaceKit.on_ground(root, 0.3, -0.2, 0.15)
	for sx: float in [-1.0, 1.0]:
		HandKit.tube(root, PackedVector3Array([ant, ant + Vector3(sx * 0.18, 0.12, 0.05), ant + Vector3(sx * 0.32, 0.3, 0.0), ant + Vector3(sx * 0.4, 0.48, -0.05)]), 0.018, bone, 6)
		HandKit.tube(root, PackedVector3Array([ant + Vector3(sx * 0.25, 0.2, 0.02), ant + Vector3(sx * 0.18, 0.36, 0.1)]), 0.012, bone, 5)
	BuildKit.sphere(root, 0.08, ant, bone, Vector3(1.0, 0.7, 1.4), 8)
	# Schutzdach über dem Zettelpfosten
	var post := PlaceKit.on_ground(root, 0.0, 3.4)
	BuildKit.box(root, Vector3(0.4, 0.03, 0.3), post + Vector3(0, 1.45, 0.06), PlaceKit.mat("shingles"), false, Vector3(-15, 0, 0))
	for k in 3:
		BuildKit.box(root, Vector3(0.002, 0.003, 0.05), post + Vector3(-0.03 + k * 0.03, 1.32, 0.055), PlaceKit.mat("metal"), false)
	PlaceDetail.litter(root, Vector3.ZERO, 15.0, 1213, 110, ["leaf", "leaf", "leaf", "twig", "twig", "stone"], func(x: float, z: float) -> float: return PlaceKit.ground(root, x, z) + 0.02)


## Imkerei Brandl: Bienenhaus, Bienenkästen in zwei Reihen. In manchen wächst graues Geflecht.
static func _imkerei(root: Node3D) -> void:
	root.rotation_degrees.y = -35.0
	var h := PlaceKit.hut(root, "BeeHouse", Vector3(0, PlaceKit.ground(root, 0, -6.0), -6.0), Vector2(6.0, 4.0), 2.5, 0.0, "wood", "gable", "shingles", 1.0, true)
	# Regal mit Honig, Wachs
	BuildKit.box(h, Vector3(2.4, 0.04, 0.4), Vector3(-1.4, 1.0, -1.6), PlaceKit.mat("wood"), true)
	BuildKit.box(h, Vector3(2.4, 0.04, 0.4), Vector3(-1.4, 1.5, -1.6), PlaceKit.mat("wood"), true)
	PlaceKit.loot(h, "Honey", "honey", 3, Vector3(-1.8, 1.02, -1.6), "jars")
	PlaceKit.loot(h, "Wax", "wax", 2, Vector3(-0.8, 1.52, -1.6), "box")
	BuildKit.box(h, Vector3(1.4, 0.8, 0.7), Vector3(1.6, 0.4, -1.5), PlaceKit.mat("wood_h"), true)
	BuildKit.box(h, Vector3(0.4, 0.3, 0.3), Vector3(1.4, 0.95, -1.5), PlaceKit.mat("tin"), false)
	PlaceKit.note(h, "imkerei_notiz", Vector3(0.4, 1.2, 2.06), true)
	# Bauplan: Leuchte mit Bewegungsmelder (Brandl schützte so die Bienenstöcke)
	PlaceKit.blueprint(h, "bp_motion", "Bewegungsmelder-Leuchte", Vector3(1.95, 0.81, -1.4))
	BuildKit.box(h, Vector3(0.25, 0.32, 0.01), Vector3(0.4, 1.3, 2.08), PlaceKit.mat("paper"), false)
	var sign := Label3D.new()
	sign.text = "IMKEREI BRANDL\nWaldhonig aus Finsterau"
	sign.font_size = 48
	sign.pixel_size = 0.004
	sign.modulate = Color(0.2, 0.12, 0.05)
	sign.outline_size = 0
	sign.position = Vector3(-1.4, 2.0, 2.09)
	h.add_child(sign)
	BuildKit.box(h, Vector3(1.6, 0.55, 0.03), Vector3(-1.4, 2.0, 2.07), PlaceKit.mat("wood_h"), false)
	# Bienenkästen
	var white := BuildKit.color_mat(Color(0.85, 0.82, 0.7), 0.8)
	var yellow := BuildKit.color_mat(Color(0.85, 0.68, 0.2), 0.8)
	for row in 2:
		for k in 4:
			var p := Vector3(-4.5 + k * 3.0, 0, 2.0 + row * 3.2)
			p.y = PlaceKit.ground(root, p.x, p.z)
			var hive := Node3D.new()
			hive.name = "Hive_%d_%d" % [row, k]
			hive.position = p
			root.add_child(hive)
			BuildKit.box(hive, Vector3(0.7, 0.4, 0.6), Vector3(0, 0.2, 0), PlaceKit.mat("wood_old"), true)
			BuildKit.box(hive, Vector3(0.55, 0.65, 0.5), Vector3(0, 0.72, 0), white if (row + k) % 2 == 0 else yellow, true)
			var open := (row == 1 and k == 2) or (row == 0 and k == 0)
			if open:
				BuildKit.box(hive, Vector3(0.6, 0.05, 0.55), Vector3(0.45, 0.4, 0.1), PlaceKit.mat("wood"), false, Vector3(0, 30, 60))
				for f in 7:
					BuildKit.cylinder(hive, 0.015, 0.6, Vector3(randf_range(-0.2, 0.2), 1.2, randf_range(-0.18, 0.18)), PlaceKit.mat("alien"), false,
							Vector3(randf_range(-40, 40), 0, randf_range(-40, 40)), 0.003, 5)
			else:
				BuildKit.box(hive, Vector3(0.62, 0.05, 0.56), Vector3(0, 1.07, 0), PlaceKit.mat("tin"), false)
	PlaceKit.loot(root, "Comb", "alien_comb", 1, PlaceKit.on_ground(root, 1.5, 5.2, 1.06), "alien")
	PlaceKit.loot(root, "Comb2", "alien_comb", 1, PlaceKit.on_ground(root, -4.5, 2.0, 1.06), "alien")
	_imkerei_details(root, h)


## Lebendige Orte: Honigschleuder, Rähmchen, Smoker, Imkerhut am Haken, Gläser im Regal, Wachsblöcke, Kalender;
## draußen Fluglöcher, Steine auf den Deckeln, Schubkarre, Bank, Schild „Honig ab Hof“, verblühtes Beet, Laub.
static func _imkerei_details(root: Node3D, h: Node3D) -> void:
	var metal := PlaceKit.mat("metal")
	# Honigschleuder (Edelstahltrommel mit Kurbel) auf der Werkbank-Seite
	var ex := Node3D.new()
	ex.position = Vector3(2.35, 0.06, 0.4)
	h.add_child(ex)
	BuildKit.cylinder(ex, 0.3, 0.7, Vector3(0, 0.55, 0), PlaceDetail.col(Color(0.75, 0.76, 0.78), 0.3, 0.4), true, Vector3.ZERO, -1.0, 16)
	for k in 3:
		var a := TAU * k / 3.0
		BuildKit.cylinder(ex, 0.025, 0.25, Vector3(cos(a) * 0.26, 0.1, sin(a) * 0.26), metal, false, Vector3.ZERO, -1.0, 6)
	BuildKit.box(ex, Vector3(0.65, 0.04, 0.06), Vector3(0, 0.92, 0), metal, false)
	BuildKit.box(ex, Vector3(0.04, 0.18, 0.04), Vector3(0.3, 1.02, 0), metal, false)
	BuildKit.cylinder(ex, 0.02, 0.12, Vector3(0.36, 1.1, 0), PlaceDetail.col(Color(0.1, 0.1, 0.1)), false, Vector3(0, 0, 90), -1.0, 6)
	BuildKit.cylinder(ex, 0.03, 0.08, Vector3(0, 0.25, 0.3), metal, false, Vector3(90, 0, 0), -1.0, 6)
	# Rähmchen-Stapel, Smoker, Gläser, Wachsblöcke
	for k in 6:
		var f := Node3D.new()
		f.position = Vector3(1.55 + (k % 3) * 0.02, 0.86 + k * 0.03, -1.45)
		f.rotation_degrees.y = (k % 2) * 6.0
		h.add_child(f)
		BuildKit.box(f, Vector3(0.45, 0.025, 0.25), Vector3.ZERO, PlaceKit.mat("wood"), false)
		BuildKit.box(f, Vector3(0.4, 0.01, 0.2), Vector3(0, 0.014, 0), PlaceDetail.col(Color(0.75, 0.6, 0.25), 0.5), false)
	var smoker := Node3D.new()
	smoker.position = Vector3(1.0, 0.81, -1.45)
	h.add_child(smoker)
	BuildKit.cylinder(smoker, 0.06, 0.2, Vector3(0, 0.1, 0), PlaceDetail.col(Color(0.4, 0.38, 0.35), 0.4, 0.8), false, Vector3.ZERO, -1.0, 10)
	BuildKit.lathe(smoker, PackedVector2Array([Vector2(0.06, 0), Vector2(0.03, 0.06), Vector2(0.012, 0.1), Vector2(0, 0.1)]), Vector3(0, 0.2, 0), metal, 10)
	BuildKit.box(smoker, Vector3(0.1, 0.04, 0.16), Vector3(-0.1, 0.1, 0), PlaceKit.mat("cloth"), false, Vector3(0, 0, 20))
	PlaceDetail.clutter(h, Vector3(-1.4, 1.52, -1.6), Vector2(2.2, 0.36), 401, 5, ["jars"])
	PlaceDetail.clutter(h, Vector3(-1.4, 1.02, -1.6), Vector2(2.2, 0.36), 402, 4, ["jars", "boxes"])
	for k in 3:
		BuildKit.box(h, Vector3(0.14, 0.08, 0.1), Vector3(-0.3 - k * 0.16, 1.06 + (k % 2) * 0.0, -1.55), PlaceDetail.col(Color(0.85, 0.7, 0.3), 0.6), false, Vector3(0, k * 10.0, 0))
	# Imkerhut mit Schleier und Handschuhe am Haken neben der Tür
	BuildKit.box(h, Vector3(0.04, 0.04, 0.1), Vector3(1.4, 1.75, 1.88), metal, false)
	BuildKit.cylinder(h, 0.2, 0.02, Vector3(1.4, 1.62, 1.82), PlaceDetail.col(Color(0.9, 0.88, 0.8), 0.8), false, Vector3(70, 0, 0), -1.0, 14)
	var veil := BuildKit.color_mat(Color(0.15, 0.15, 0.15, 0.55), 0.9)
	veil.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	veil.cull_mode = BaseMaterial3D.CULL_DISABLED
	BuildKit.cylinder(h, 0.17, 0.35, Vector3(1.4, 1.42, 1.86), veil, false, Vector3(70, 0, 0), 0.2, 14)
	for sx: float in [-1.0, 1.0]:
		BuildKit.box(h, Vector3(0.1, 0.28, 0.05), Vector3(1.7 + sx * 0.07, 1.45, 1.9), PlaceDetail.col(Color(0.85, 0.75, 0.55), 0.9), false, Vector3(0, 0, sx * 6.0))
	PlaceDetail.sign(h, "Schleudern:\nSa 14.11.\n— 38 Gläser —\nKasten 3 + 6:\nSIEHE NOTIZ", Vector3(-2.95, 1.5, 0.5), Vector2(0.35, 0.45), 90.0, Color(0.95, 0.93, 0.85), Color(0.2, 0.15, 0.1), 22)
	PlaceDetail.lamp(h, Vector3(0, 2.4, 0), "hanging", false)
	PlaceDetail.cobweb(h, Vector3(-2.9, 2.4, -1.9), Vector3(1, 0, 0), Vector3(0, 0, 1), 0.4)
	# draußen: Fluglöcher und Steine auf den Kastendeckeln, Kastenständer
	for row in 2:
		for k in 4:
			var hive := root.get_node_or_null("Hive_%d_%d" % [row, k]) as Node3D
			if hive == null:
				continue
			BuildKit.box(hive, Vector3(0.3, 0.025, 0.01), Vector3(0, 0.45, 0.255), PlaceDetail.col(Color(0.05, 0.04, 0.03)), false)
			BuildKit.box(hive, Vector3(0.36, 0.015, 0.08), Vector3(0, 0.43, 0.29), PlaceKit.mat("wood_old"), false)
			if not ((row == 1 and k == 2) or (row == 0 and k == 0)):
				BuildKit.sphere(hive, 0.1, Vector3(0.05, 1.15, -0.05), PlaceKit.mat("stone"), Vector3(1.3, 0.7, 1.0), 7)
	# Schubkarre, Bank, Schild am Weg, verblühtes Beet
	var wb := Node3D.new()
	wb.position = PlaceKit.on_ground(root, 4.2, -2.5)
	wb.rotation_degrees.y = 30.0
	root.add_child(wb)
	BuildKit.lathe(wb, PackedVector2Array([Vector2(0, 0), Vector2(0.3, 0.0), Vector2(0.42, 0.3), Vector2(0.4, 0.3), Vector2(0.28, 0.02), Vector2(0, 0.02)]), Vector3(0, 0.3, 0), PlaceKit.mat("rust"), 12).scale = Vector3(1.0, 1.0, 1.5)
	BuildKit.cylinder(wb, 0.16, 0.06, Vector3(0, 0.16, 0.75), PlaceDetail.col(Color(0.08, 0.08, 0.08)), false, Vector3(0, 0, 90), -1.0, 12)
	for sx: float in [-1.0, 1.0]:
		BuildKit.beam_between(wb, Vector3(sx * 0.2, 0.3, 0.6), Vector3(sx * 0.28, 0.55, -0.9), 0.03, PlaceKit.mat("wood_old"))
		BuildKit.box(wb, Vector3(0.03, 0.3, 0.03), Vector3(sx * 0.22, 0.15, -0.35), metal, false)
	var bench := Node3D.new()
	bench.position = PlaceKit.on_ground(root, -2.0, -3.4)
	root.add_child(bench)
	PlaceDetail.pew(bench, Vector3.ZERO, 1.6, "wood_old")
	var sp := PlaceKit.on_ground(root, -6.5, 6.5)
	BuildKit.box(root, Vector3(0.1, 1.5, 0.1), sp + Vector3(0, 0.75, 0), PlaceKit.mat("wood_old"), true)
	PlaceDetail.sign(root, "Honig ab Hof\n€ 6,– / Glas\nKasse des Vertrauens", sp + Vector3(0, 1.3, 0.06), Vector2(0.6, 0.36), 0.0, Color(0.95, 0.85, 0.35), Color(0.25, 0.15, 0.05), 30)
	BuildKit.box(root, Vector3(0.25, 0.2, 0.18), sp + Vector3(0, 0.9, 0.1), PlaceKit.mat("tin"), false)
	for k in 12:
		var p := PlaceKit.on_ground(root, 3.0 + (k % 4) * 0.5, -4.5 + (k / 4) * 0.5)
		BuildKit.cylinder(root, 0.006, 0.45, p + Vector3(0, 0.22, 0), PlaceDetail.col(Color(0.35, 0.3, 0.15), 1.0), false, Vector3(randf_range(-15, 15), 0, randf_range(-15, 15)), 0.003, 4)
		BuildKit.sphere(root, 0.03, p + Vector3(0, 0.45, 0), PlaceDetail.col(Color(0.3, 0.22, 0.12), 1.0), Vector3.ONE, 5)
	BuildKit.box(root, Vector3(2.2, 0.15, 1.7), PlaceKit.on_ground(root, 3.75, -3.75, 0.0), PlaceKit.mat("wood_old"), false)
	PlaceDetail.litter(root, Vector3(0, 0, 2.0), 7.0, 455, 70, ["leaf", "leaf", "twig"], func(x: float, z: float) -> float: return PlaceKit.ground(root, x, z) + 0.02)
