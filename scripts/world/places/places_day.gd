class_name PlacesDay
extends RefCounted
## Orte für einen Tagesmarsch: Messstelle 4-Nord, Funkmast, Rachelsee, Granitbruch, Kontrollpunkt Mauth,
## Ferienlager, Schäferkarren, Finsterauer Filz, Totholzhang, Lichtung der Spiegel, Reschbachklause (Etappe 4).
## Im Granitbruch dazu ein alter Stollen (Etappe 4, map.json „cuts“ mit floor_drop).



static func build(id: String, root: Node3D) -> bool:
	match id:
		"messstelle": _messstelle(root)
		"funkmast": _funkmast(root)
		"see": _see(root)
		"steinbruch": _steinbruch(root)
		"kontrollpunkt": _kontrollpunkt(root)
		"ferienlager": _ferienlager(root)
		"schaefer": _schaefer(root)
		"moor": _moor(root)
		"windwurf": _windwurf(root)
		"spiegel": _spiegel(root)
		"klause": _klause(root)
		_: return false
	return true


static func label(parent: Node3D, text: String, pos: Vector3, size: int = 40, col: Color = Color(0.1, 0.1, 0.1), yaw: float = 0.0) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.004
	l.modulate = col
	l.outline_size = 0
	l.position = pos
	l.rotation_degrees.y = yaw
	parent.add_child(l)
	return l


## Messstelle 4-Nord (27.11. neu, so detailliert wie die Hütte): eingezäuntes Kiesgelände von ReZort Industries mit
## Stacheldraht und offenem Tor, Wellblech-Container (Stufen, Klimagerät, Kabeltrasse, Scheinwerfer), drinnen Arbeitsplatz
## mit Monitor, Serverschrank mit blinkenden Lämpchen, Regal mit Ordnern, Whiteboard, Kalender, Feuerlöscher.
## Draußen Stromaggregat, Kabeltrommel, Fässer, Paletten, Messpfähle, Mast mit Schüssel, verschweißter Schacht.
## Knotennamen der Funde (Container/Electronics, Batteries, Keycard, Protocols, BP_bp_winch, Note_messstelle_log) bleiben.
static func _messstelle(root: Node3D) -> void:
	root.rotation_degrees.y = 10.0
	# Kiesfläche im Zaun
	for gx in 4:
		for gz in 3:
			var p := Vector3(-6.0 + gx * 4.0, 0, -4.0 + gz * 4.0)
			p.y = PlaceKit.ground(root, p.x, p.z) + 0.02
			BuildKit.box(root, Vector3(4.05, 0.04, 4.05), p, PlaceKit.mat("gravel"), false)
	_mess_fence(root)
	var c := _mess_container(root)
	_mess_inside(c)
	_mess_yard(root)


## Maschendrahtzaun mit Betonfüßen, Stacheldraht oben, Warnschildern, offenem Tor (aufgebrochenes Schloss).
static func _mess_fence(root: Node3D) -> void:
	var pts := [Vector2(-8, -6), Vector2(8, -6), Vector2(8, 6), Vector2(-8, 6), Vector2(-8, -6)]
	PlaceKit.fence(root, pts, 2.2, [Vector2(50.0, 53.5)])
	var wire := PlaceDetail.col(Color(0.35, 0.35, 0.36), 0.5, 0.8)
	var dist := 0.0
	for i in pts.size() - 1:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var steps := maxi(int(a.distance_to(b) / 3.0), 1)
		var out := Vector2(b.y - a.y, a.x - b.x).normalized() * -1.0
		for k in steps + 1:
			var q := a.lerp(b, float(k) / steps)
			var g := PlaceKit.ground(root, q.x, q.y)
			BuildKit.box(root, Vector3(0.22, 0.25, 0.22), Vector3(q.x, g + 0.05, q.y), PlaceKit.mat("concrete"), false)
			# Ausleger für den Stacheldraht (nach außen geneigt)
			BuildKit.beam_between(root, Vector3(q.x, g + 2.2, q.y), Vector3(q.x + out.x * 0.35, g + 2.55, q.y + out.y * 0.35), 0.03, PlaceKit.mat("metal"))
		for strand in 3:
			var off := 0.12 + strand * 0.11
			var ga := PlaceKit.ground(root, a.x, a.y)
			var gb := PlaceKit.ground(root, b.x, b.y)
			var mid := dist + a.distance_to(b) * 0.5
			if i == 3 and mid > 0.0:
				# Torseite: Draht nur bis zum Tor
				var cut := a.lerp(b, 6.0 / 12.0)
				var gc := PlaceKit.ground(root, cut.x, cut.y)
				PlaceDetail.cable(root, Vector3(a.x + out.x * off * 3.0, ga + 2.2 + off, a.y + out.y * off * 3.0), Vector3(cut.x + out.x * off * 3.0, gc + 2.2 + off, cut.y + out.y * off * 3.0), 0.04, 0.004, Color(0.3, 0.3, 0.3))
				var cut2 := a.lerp(b, 9.5 / 12.0)
				var gc2 := PlaceKit.ground(root, cut2.x, cut2.y)
				PlaceDetail.cable(root, Vector3(cut2.x + out.x * off * 3.0, gc2 + 2.2 + off, cut2.y + out.y * off * 3.0), Vector3(b.x + out.x * off * 3.0, gb + 2.2 + off, b.y + out.y * off * 3.0), 0.04, 0.004, Color(0.3, 0.3, 0.3))
				continue
			PlaceDetail.cable(root, Vector3(a.x + out.x * off * 3.0, ga + 2.2 + off, a.y + out.y * off * 3.0), Vector3(b.x + out.x * off * 3.0, gb + 2.2 + off, b.y + out.y * off * 3.0), 0.05, 0.004, Color(0.3, 0.3, 0.3))
		dist += a.distance_to(b)
	# Tor (Westseite, z 0 … -3,5): zwei Flügel aus Rohrrahmen, einer offen, Kette mit aufgebrochenem Schloss
	var gate_x := -8.0
	for k in 2:
		var hinge_z := 0.0 if k == 0 else -3.5
		var g := PlaceKit.ground(root, gate_x, hinge_z)
		var leaf := Node3D.new()
		leaf.name = "GateLeaf%d" % k
		leaf.position = Vector3(gate_x, g, hinge_z)
		leaf.rotation_degrees.y = -100.0 if k == 0 else 8.0
		root.add_child(leaf)
		var dir := -1.0 if k == 0 else 1.0
		var w := 1.72
		for yy: float in [0.12, 1.0, 1.95]:
			BuildKit.cylinder(leaf, 0.025, w, Vector3(0, yy, dir * w * 0.5), wire, false, Vector3(90, 0, 0), -1.0, 6)
		for zz: float in [0.0, w]:
			BuildKit.cylinder(leaf, 0.03, 1.95, Vector3(0, 1.0, dir * zz), wire, false, Vector3.ZERO, -1.0, 6)
		var mesh := PlaceKit.chainlink_mat()
		BuildKit.box(leaf, Vector3(0.01, 1.8, w), Vector3(0, 1.05, dir * w * 0.5), mesh, k == 1)
		BuildKit.cylinder(root, 0.06, 2.4, Vector3(gate_x, g + 1.2, hinge_z), PlaceKit.mat("metal"), true, Vector3.ZERO, -1.0, 8)
	# Kette mit aufgebrochenem Vorhängeschloss im Kies
	var lock_p := PlaceKit.on_ground(root, -7.4, -1.6, 0.03)
	for i in 8:
		BuildKit.cylinder(root, 0.012, 0.06, lock_p + Vector3(i * 0.05, 0, sin(i * 1.3) * 0.04), wire, false, Vector3(90, i * 40.0, 0), -1.0, 5)
	BuildKit.box(root, Vector3(0.06, 0.07, 0.025), lock_p + Vector3(0.45, 0.01, 0.02), PlaceDetail.col(Color(0.7, 0.6, 0.25), 0.4, 0.8), false, Vector3(70, 20, 0))
	# Warnschilder am Zaun
	var signs := [["BETRETEN VERBOTEN\nReZort Industries – Sondertechnik", Vector3(-8.03, 1.4, 1.5), -90.0, Color(0.9, 0.9, 0.86), Color(0.7, 0.1, 0.08)],
			["VORSICHT\nHochspannung", Vector3(-8.03, 1.4, -4.6), -90.0, Color(0.95, 0.8, 0.1), Color(0.05, 0.05, 0.05)],
			["Videoüberwacht", Vector3(2.0, 1.5, 6.03), 0.0, Color(0.9, 0.9, 0.86), Color(0.1, 0.1, 0.1)],
			["MP4-N · Messfeld\nKein Zutritt", Vector3(8.03, 1.4, -2.0), 90.0, Color(0.9, 0.9, 0.86), Color(0.1, 0.2, 0.45)]]
	for sg: Array in signs:
		var sp: Vector3 = sg[1]
		sp.y += PlaceKit.ground(root, sp.x, sp.z)
		PlaceDetail.sign(root, String(sg[0]), sp, Vector2(0.6, 0.38), float(sg[2]), sg[3] as Color, sg[4] as Color, 34)


## Wellblech-Container mit Stufen, Tür, vergittertem Fenster, Klimagerät, Antenne, Scheinwerfer, Beschriftung.
static func _mess_container(root: Node3D) -> Node3D:
	const HX := 3.03
	const HZ := 1.22
	const H := 2.6
	const T := 0.08
	var base_y := PlaceKit.ground(root, 0, -1.0) + 0.35
	var c := Node3D.new()
	c.name = "Container"
	c.position = Vector3(0, base_y, -1.0)
	root.add_child(c)
	var inner := PlaceDetail.col(Color(0.78, 0.79, 0.77), 0.8)
	var steel := PlaceKit.mat("steel_dark")
	# Fundament (Betonklötze), Boden, Decke
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			BuildKit.box(c, Vector3(0.4, 0.8, 0.4), Vector3(sx * (HX - 0.3), -0.55, sz * (HZ - 0.25)), PlaceKit.mat("concrete"), true)
	BuildKit.box(c, Vector3(HX * 2.0, 0.12, HZ * 2.0), Vector3(0, -0.06, 0), steel, true)
	BuildKit.box(c, Vector3(HX * 2.0 - 0.16, 0.01, HZ * 2.0 - 0.16), Vector3(0, 0.005, 0), PlaceDetail.col(Color(0.12, 0.12, 0.13), 0.95), false)
	BuildKit.box(c, Vector3(HX * 2.0 + 0.04, 0.14, HZ * 2.0 + 0.04), Vector3(0, H + 0.07, 0), PlaceKit.mat("corrugated"), true)
	BuildKit.box(c, Vector3(HX * 2.0 - 0.16, 0.02, HZ * 2.0 - 0.16), Vector3(0, H - 0.01, 0), inner, false)
	# Wände innen (hell gestrichen), Öffnungen: Tür rechts vorn, Fenster links vorn und an der linken Stirnseite
	BuildKit.wall(c, Vector2(-HX, HZ - T * 0.5), Vector2(HX, HZ - T * 0.5), 0.0, H, T, inner, [Vector4(HX + 1.7, 0.95, 0.0, 2.05), Vector4(HX - 1.4, 1.0, 1.0, 1.75)], "Front")
	BuildKit.wall(c, Vector2(HX, -HZ + T * 0.5), Vector2(-HX, -HZ + T * 0.5), 0.0, H, T, inner, [], "Back")
	BuildKit.wall(c, Vector2(-HX + T * 0.5, -HZ + T), Vector2(-HX + T * 0.5, HZ - T), 0.0, H, T, inner, [Vector4(HZ - T, 0.8, 1.1, 1.7)], "Left")
	BuildKit.wall(c, Vector2(HX - T * 0.5, HZ - T), Vector2(HX - T * 0.5, -HZ + T), 0.0, H, T, inner, [], "Right")
	# Wellblech außen
	var d := 0.03
	PlaceDetail.corrugated(c, Vector2(HX * 2.0, H), Vector3(0, H * 0.5, -HZ - d), Vector3(0, 180, 0))
	PlaceDetail.corrugated(c, Vector2(HZ * 2.0, H), Vector3(HX + d, H * 0.5, 0), Vector3(0, 90, 0))
	PlaceDetail.corrugated(c, Vector2(HZ * 2.0 - 0.8, H), Vector3(-HX - d, H * 0.5, -0.4), Vector3(0, -90, 0))
	PlaceDetail.corrugated(c, Vector2(0.15, H), Vector3(-HX - d, H * 0.5, HZ - 0.075), Vector3(0, -90, 0))
	PlaceDetail.corrugated(c, Vector2(0.8, 1.1), Vector3(-HX - d, 0.55, HZ - 0.55), Vector3(0, -90, 0))
	PlaceDetail.corrugated(c, Vector2(0.8, 0.9), Vector3(-HX - d, 2.15, HZ - 0.55), Vector3(0, -90, 0))
	# Front in Streifen um Fenster (x -2,1 … -1,1) und Tür (x 1,2 … 2,2)
	for seg: Vector4 in [Vector4(-HX, -2.1, 0.0, H), Vector4(-2.1, -1.1, 0.0, 1.0), Vector4(-2.1, -1.1, 1.75, H), Vector4(-1.1, 1.22, 0.0, H),
			Vector4(1.22, 2.18, 2.05, H), Vector4(2.18, HX, 0.0, H)]:
		PlaceDetail.corrugated(c, Vector2(seg.y - seg.x, seg.w - seg.z), Vector3((seg.x + seg.y) * 0.5, (seg.z + seg.w) * 0.5, HZ + d))
	# Eckbeschläge (Container-Ecken)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			for yy: float in [0.08, H - 0.08]:
				BuildKit.box(c, Vector3(0.18, 0.16, 0.18), Vector3(sx * (HX - 0.05), yy, sz * (HZ - 0.05)), steel, false)
			BuildKit.box(c, Vector3(0.1, H, 0.1), Vector3(sx * (HX - 0.03), H * 0.5, sz * (HZ - 0.03)), steel, false)
	# Stahltür (offen) und Fenster mit Gitter
	PlaceDetail.door(c, Vector3(1.7, 0.0, HZ - T * 0.5), 0.0, 0.95, 2.05, "steel", -75.0)
	PlaceDetail.window(c, Vector3(-1.6, 1.0, HZ - 0.02), 0.0, 1.0, 0.75, 0.1, "rect", Color(0.5, 0.58, 0.6, 0.4), "steel_dark", 1, true, "steel_dark")
	PlaceDetail.window(c, Vector3(-HX + 0.02, 1.1, HZ - T - 0.4), -90.0, 0.8, 0.6, 0.1, "rect", Color(0.5, 0.58, 0.6, 0.4), "steel_dark", 1, true, "steel_dark")
	# Gitterstufen vor der Tür
	var grate := PlaceDetail.col(Color(0.3, 0.31, 0.3), 0.6, 0.7)
	for k in 2:
		BuildKit.box(c, Vector3(1.1, 0.04, 0.3), Vector3(1.7, -0.15 - k * 0.18, HZ + 0.2 + k * 0.28), grate, true)
	for sx: float in [-1.0, 1.0]:
		BuildKit.box(c, Vector3(0.04, 0.5, 0.7), Vector3(1.7 + sx * 0.55, -0.3, HZ + 0.33), grate, false, Vector3(-30, 0, 0))
	# Beschriftung, Nummer, Warnzeichen
	PlaceDetail.sign(c, "ReZort Industries\nMessstelle 4-Nord\nBetreten verboten", Vector3(-0.1, 1.7, HZ + 0.06), Vector2(1.2, 0.55), 0.0, Color(0.92, 0.92, 0.9), Color(0.7, 0.1, 0.08), 36)
	var stencil := Label3D.new()
	stencil.text = "RZ-4N  0417"
	stencil.font_size = 96
	stencil.pixel_size = 0.004
	stencil.modulate = Color(0.85, 0.85, 0.8)
	stencil.outline_size = 0
	stencil.position = Vector3(0, 1.9, -HZ - 0.06)
	stencil.rotation_degrees.y = 180.0
	c.add_child(stencil)
	PlaceDetail.sign(c, "⚡", Vector3(2.75, 1.5, HZ + 0.06), Vector2(0.22, 0.22), 0.0, Color(0.95, 0.8, 0.1), Color(0.05, 0.05, 0.05), 60, false)
	# Klimagerät an der rechten Stirnseite, Kabeltrasse, Antenne, Scheinwerfer
	var ac := Node3D.new()
	ac.position = Vector3(HX + 0.25, 1.7, 0.2)
	c.add_child(ac)
	BuildKit.box(ac, Vector3(0.4, 0.6, 0.9), Vector3.ZERO, PlaceDetail.col(Color(0.82, 0.83, 0.8), 0.6), false)
	BuildKit.cylinder(ac, 0.22, 0.02, Vector3(0.21, 0.0, 0.0), PlaceDetail.col(Color(0.1, 0.1, 0.1)), false, Vector3(0, 0, 90), -1.0, 16)
	for k in 5:
		BuildKit.box(ac, Vector3(0.01, 0.5, 0.012), Vector3(0.215, 0, -0.2 + k * 0.1), PlaceDetail.col(Color(0.3, 0.3, 0.3)), false)
	BuildKit.box(c, Vector3(0.3, 0.04, 0.04), Vector3(HX + 0.12, 1.32, 0.2), steel, false)
	var tray := PlaceDetail.col(Color(0.55, 0.56, 0.55), 0.5, 0.6)
	BuildKit.box(c, Vector3(0.3, 0.06, 0.06), Vector3(-HX - 0.15, 0.4, -0.6), tray, false)
	BuildKit.cylinder(c, 0.02, 2.0, Vector3(-1.9, H + 1.0, -0.6), PlaceKit.mat("metal"), false, Vector3.ZERO, 0.008, 6)
	for k in 3:
		BuildKit.box(c, Vector3(0.5 - k * 0.12, 0.012, 0.012), Vector3(-1.9, H + 1.3 + k * 0.25, -0.6), PlaceKit.mat("metal"), false)
	PlaceDetail.lamp(c, Vector3(HX - 0.2, H - 0.15, HZ + 0.05), "flood", false, 20.0)
	PlaceDetail.lamp(c, Vector3(1.7, 2.3, HZ + 0.06), "cage", true, 0.0, Color(1.0, 0.9, 0.7), 0.5, 4.0)
	return c


## Innenraum: Arbeitsplatz, Serverschrank, Regal, Whiteboard, Funde.
static func _mess_inside(c: Node3D) -> void:
	var y := 0.01
	# Schreibtisch an der Rückwand mit Monitor, Tastatur, Becher, Papieren
	PlaceDetail.table(c, Vector3(1.4, y, -0.82), Vector3(1.9, 0.76, 0.66), "table")
	var ty := y + 0.76
	var dark := PlaceDetail.col(Color(0.06, 0.06, 0.07), 0.4)
	BuildKit.box(c, Vector3(0.5, 0.32, 0.03), Vector3(0.65, ty + 0.3, -1.02), dark, false)
	var screen := BuildKit.emissive_mat(Color(0.05, 0.18, 0.1), 0.8)
	BuildKit.box(c, Vector3(0.46, 0.28, 0.005), Vector3(0.65, ty + 0.3, -1.003), screen, false)
	for k in 6:
		BuildKit.box(c, Vector3(0.12 + (k * 37 % 5) * 0.05, 0.012, 0.002), Vector3(0.5 + (k * 37 % 5) * 0.025, ty + 0.4 - k * 0.035, -1.0), BuildKit.emissive_mat(Color(0.2, 0.9, 0.4), 1.5), false)
	BuildKit.box(c, Vector3(0.05, 0.14, 0.05), Vector3(0.65, ty + 0.07, -1.04), dark, false)
	BuildKit.box(c, Vector3(0.2, 0.012, 0.15), Vector3(0.65, ty + 0.006, -1.04), dark, false)
	BuildKit.box(c, Vector3(0.44, 0.02, 0.15), Vector3(0.7, ty + 0.01, -0.72), dark, false)
	BuildKit.box(c, Vector3(0.06, 0.02, 0.1), Vector3(1.0, ty + 0.01, -0.7), dark, false)
	BuildKit.lathe(c, PackedVector2Array([Vector2(0, 0), Vector2(0.04, 0), Vector2(0.042, 0.1), Vector2(0.038, 0.1), Vector2(0.036, 0.01), Vector2(0, 0.01)]), Vector3(0.25, ty, -0.7), PlaceDetail.col(Color(0.85, 0.82, 0.75), 0.3), 10)
	PlaceDetail.clutter(c, Vector3(1.85, ty, -0.95), Vector2(0.4, 0.3), 77, 2, ["papers"])
	PlaceDetail.office_chair(c, Vector3(1.0, y, -0.15), 160.0)
	PlaceKit.loot(c, "Keycard", "keycard_m4", 1, Vector3(1.15, ty + 0.01, -0.62), "card")
	PlaceKit.loot(c, "Protocols", "rz_protocol", 1, Vector3(1.5, ty + 0.01, -0.72), "paper")
	PlaceKit.blueprint(c, "bp_winch", "Kabelwinde", Vector3(2.15, ty + 0.03, -0.62))
	# Wartungsprotokoll: Klemmbrett an der Wand über dem Tisch – groß und beschriftet (Christian 27.11.: wurde übersehen)
	PlaceKit.note(c, "messstelle_log", Vector3(1.9, 1.3, -1.06), true)
	BuildKit.box(c, Vector3(0.34, 0.46, 0.015), Vector3(1.9, 1.42, -1.17), PlaceKit.mat("wood_old"), false)
	BuildKit.box(c, Vector3(0.28, 0.38, 0.004), Vector3(1.9, 1.4, -1.16), PlaceKit.mat("paper"), false)
	BuildKit.box(c, Vector3(0.12, 0.035, 0.02), Vector3(1.9, 1.63, -1.155), PlaceKit.mat("metal"), false)
	var log_lab := label(c, "WARTUNGS-\nPROTOKOLL\nMP4-N", Vector3(1.9, 1.5, -1.156), 18, Color(0.08, 0.08, 0.1))
	log_lab.pixel_size = 0.0035
	# Serverschrank mit blinkenden Lämpchen
	var rack := Node3D.new()
	rack.name = "Rack"
	rack.position = Vector3(-2.6, y, -0.85)
	c.add_child(rack)
	BuildKit.box(rack, Vector3(0.6, 2.0, 0.65), Vector3(0, 1.0, 0), PlaceDetail.col(Color(0.1, 0.1, 0.11), 0.5, 0.5), true)
	var leds := []
	for k in 9:
		BuildKit.box(rack, Vector3(0.5, 0.12, 0.01), Vector3(0, 0.3 + k * 0.18, 0.33), PlaceDetail.col(Color(0.18, 0.18, 0.2), 0.4, 0.6), false)
		for j in 3:
			var on := (k * 3 + j) % 4 != 0
			var cl := Color(0.2, 1.0, 0.3) if (k + j) % 5 != 0 else Color(1.0, 0.55, 0.1)
			var lm := BuildKit.emissive_mat(cl, 2.5 if on else 0.0)
			BuildKit.box(rack, Vector3(0.012, 0.012, 0.004), Vector3(0.18 + j * 0.03, 0.3 + k * 0.18, 0.337), lm, false)
			leds.append(lm)
	var blink := Timer.new()
	blink.wait_time = 0.35
	blink.autostart = true
	rack.add_child(blink)
	var rng := RandomNumberGenerator.new()
	rng.seed = 404
	blink.timeout.connect(func() -> void:
		for i in 3:
			var lm2: StandardMaterial3D = leds[rng.randi() % leds.size()]
			lm2.emission_energy_multiplier = 0.0 if lm2.emission_energy_multiplier > 0.5 else 2.5)
	for k in 4:
		PlaceDetail.cable(c, Vector3(-2.35, 1.8 - k * 0.3, -0.52), Vector3(-1.95 + k * 0.05, 2.5, -1.1), 0.25, 0.01, [Color(0.05, 0.05, 0.05), Color(0.1, 0.2, 0.6), Color(0.6, 0.5, 0.1), Color(0.5, 0.1, 0.1)][k] as Color)
	# Regal mit Ordnern und Kartons, Funde unten
	PlaceDetail.shelf(c, Vector3(-1.35, y, -1.18), 0.0, Vector3(1.1, 1.9, 0.4), 4, "steel_dark")
	PlaceDetail.clutter(c, Vector3(-1.35, y + 1.26, -0.98), Vector2(1.0, 0.36), 51, 4, ["binders"])
	PlaceDetail.clutter(c, Vector3(-1.35, y + 1.86, -0.98), Vector2(1.0, 0.36), 52, 3, ["boxes", "binders"])
	PlaceDetail.clutter(c, Vector3(-1.35, y + 0.66, -0.98), Vector2(1.0, 0.36), 53, 3, ["boxes", "tools"])
	PlaceKit.loot(c, "Electronics", "electronics", 3, Vector3(-1.6, y + 0.08, -0.98), "case")
	PlaceKit.loot(c, "Batteries", "battery", 2, Vector3(-1.05, y + 0.08, -0.98), "case")
	# Whiteboard an der linken Stirnseite (Skizze der Kabeltrasse), Kalender, Feuerlöscher, Erste Hilfe, Deckenleuchte
	var wb := PlaceDetail.sign(c, "K4-NORD → MP4\nKopplung W-Serie ??\nDrift 17.09.: ↑↑\nW-17 → AUSSCHUSS?\n\n(nicht wegwischen!)", Vector3(-2.95, 1.55, -0.45), Vector2(0.9, 0.62), 90.0,
			Color(0.95, 0.96, 0.95), Color(0.1, 0.2, 0.55), 30)
	wb.name = "Whiteboard"
	PlaceDetail.sign(c, "NOVEMBER\n\nMo Di Mi Do Fr Sa So\n2 3 4 5 6 7 8\n9 10 11 12 13 14 15\n16 ✕ 18 19 20 21 22", Vector3(2.95, 1.55, 0.3), Vector2(0.4, 0.5), -90.0,
			Color(0.95, 0.94, 0.9), Color(0.15, 0.15, 0.15), 22)
	var red := PlaceDetail.col(Color(0.75, 0.08, 0.06), 0.4, 0.2)
	BuildKit.cylinder(c, 0.075, 0.5, Vector3(2.65, y + 0.25, 1.05), red, false, Vector3.ZERO, -1.0, 12)
	BuildKit.box(c, Vector3(0.06, 0.06, 0.12), Vector3(2.65, y + 0.53, 1.07), dark, false)
	BuildKit.box(c, Vector3(0.3, 0.22, 0.1), Vector3(0.6, 1.6, 1.12), PlaceDetail.col(Color(0.15, 0.55, 0.25), 0.5), false)
	BuildKit.box(c, Vector3(0.1, 0.03, 0.005), Vector3(0.6, 1.6, 1.07), PlaceDetail.col(Color(0.95, 0.95, 0.95)), false)
	BuildKit.box(c, Vector3(0.03, 0.1, 0.005), Vector3(0.6, 1.6, 1.07), PlaceDetail.col(Color(0.95, 0.95, 0.95)), false)
	for sx: float in [-1.0, 1.0]:
		var tube := BuildKit.emissive_mat(Color(0.85, 0.95, 1.0), 0.0 if sx < 0.0 else 1.2)
		BuildKit.box(c, Vector3(1.2, 0.06, 0.16), Vector3(sx * 1.4, 2.55, 0), PlaceDetail.col(Color(0.8, 0.8, 0.78), 0.5), false)
		BuildKit.box(c, Vector3(1.1, 0.03, 0.08), Vector3(sx * 1.4, 2.51, 0), tube, false)
	var fl := OmniLight3D.new()
	fl.light_color = Color(0.85, 0.95, 1.0)
	fl.light_energy = 0.7
	fl.omni_range = 4.5
	fl.shadow_enabled = false
	fl.position = Vector3(1.4, 2.35, 0)
	c.add_child(fl)
	PlaceDetail.litter(c, Vector3(1.6, y, 0.7), 0.6, 33, 6, ["leaf", "paper"])
	# Leben im Container: Wandfugen, Kabelkanal, Pinnwand, Netzplan, Jacke am Haken, Kaffeeecke, Papierkorb, Heizlüfter
	var seam := PlaceDetail.col(Color(0.62, 0.63, 0.61), 0.7)
	for k in 5:
		var x := -2.4 + k * 1.2
		BuildKit.box(c, Vector3(0.025, 2.5, 0.006), Vector3(x, 1.27, -1.175), seam, false)
		BuildKit.box(c, Vector3(0.025, 2.5, 0.006), Vector3(x, 1.27, 1.175), seam, false)
	BuildKit.box(c, Vector3(5.9, 0.08, 0.06), Vector3(0, 2.42, -1.14), PlaceDetail.col(Color(0.88, 0.88, 0.86), 0.6), false)
	BuildKit.box(c, Vector3(5.9, 0.06, 0.05), Vector3(0, 0.12, -1.15), PlaceDetail.col(Color(0.88, 0.88, 0.86), 0.6), false)
	for k in 3:
		BuildKit.box(c, Vector3(0.08, 0.05, 0.02), Vector3(0.3 + k * 0.9, 0.3, -1.165), PlaceDetail.col(Color(0.95, 0.95, 0.93), 0.5), false)
	var cork := Node3D.new()
	cork.position = Vector3(-0.3, 1.55, 1.15)
	cork.rotation_degrees.y = 180.0
	c.add_child(cork)
	BuildKit.box(cork, Vector3(0.9, 0.6, 0.02), Vector3.ZERO, PlaceDetail.col(Color(0.62, 0.45, 0.28), 1.0), false)
	var nrng := RandomNumberGenerator.new()
	nrng.seed = 88
	for k in 9:
		var nc := [Color(0.95, 0.92, 0.6), Color(0.95, 0.95, 0.93), Color(0.7, 0.85, 0.95), Color(0.95, 0.75, 0.7)][k % 4] as Color
		BuildKit.box(cork, Vector3(nrng.randf_range(0.1, 0.2), nrng.randf_range(0.08, 0.2), 0.004), Vector3(nrng.randf_range(-0.35, 0.35), nrng.randf_range(-0.22, 0.22), 0.013), PlaceDetail.col(nc, 0.9), false, Vector3(0, 0, nrng.randf_range(-8, 8)))
	var map := PlaceDetail.sign(c, "MESSNETZ MP4\n· N  · O  · W  · Außenst.\n— K4-Nord —", Vector3(0.9, 1.6, 1.155), Vector2(0.8, 0.55), 180.0, Color(0.88, 0.9, 0.82), Color(0.15, 0.3, 0.2), 26)
	for k in 6:
		BuildKit.box(map, Vector3(0.012, 0.012, 0.002), Vector3(-0.3 + k * 0.12, -0.15 + sin(k * 1.7) * 0.08, 0.011), PlaceKit.mat("red"), false)
	# Jacke am Haken neben der Tür
	BuildKit.box(c, Vector3(0.04, 0.04, 0.08), Vector3(2.5, 1.8, 1.12), PlaceKit.mat("metal"), false)
	var coat := PlaceDetail.col(Color(0.85, 0.42, 0.08), 0.9)
	BuildKit.box(c, Vector3(0.45, 0.75, 0.14), Vector3(2.5, 1.38, 1.08), coat, false, Vector3(0, 0, 3))
	BuildKit.box(c, Vector3(0.46, 0.05, 0.145), Vector3(2.5, 1.22, 1.08), PlaceDetail.col(Color(0.85, 0.85, 0.75), 0.4, 0.4), false)
	PlaceDetail.sign(c, "ReZort", Vector3(2.5, 1.55, 1.005), Vector2(0.14, 0.05), 180.0, Color(0.85, 0.42, 0.08), Color(0.1, 0.1, 0.1), 20, false)
	# Kaffeeecke auf einem Unterschrank an der rechten Stirnseite
	BuildKit.box(c, Vector3(0.5, 0.8, 0.9), Vector3(2.7, y + 0.4, -0.55), PlaceDetail.col(Color(0.82, 0.82, 0.8), 0.6), true)
	BuildKit.box(c, Vector3(0.22, 0.32, 0.25), Vector3(2.72, y + 0.96, -0.75), dark, false)
	BuildKit.box(c, Vector3(0.14, 0.12, 0.012), Vector3(2.6, y + 0.88, -0.75), PlaceDetail.col(Color(0.15, 0.15, 0.17), 0.2), false)
	BuildKit.cylinder(c, 0.06, 0.12, Vector3(2.72, y + 0.86, -0.75), PlaceDetail.col(Color(0.3, 0.32, 0.35, 1.0), 0.15), false, Vector3.ZERO, -1.0, 10)
	for k in 3:
		BuildKit.lathe(c, PackedVector2Array([Vector2(0, 0), Vector2(0.04, 0), Vector2(0.042, 0.1), Vector2(0.038, 0.1), Vector2(0.036, 0.01), Vector2(0, 0.01)]), Vector3(2.62 + (k % 2) * 0.1, y + 0.8, -0.35 + k * 0.08), PlaceDetail.col([Color(0.85, 0.82, 0.75), Color(0.6, 0.1, 0.08), Color(0.2, 0.3, 0.55)][k], 0.3), 10)
	BuildKit.box(c, Vector3(0.3, 0.2, 0.2), Vector3(2.7, y + 0.9, -0.15), BuildKit.tex_mat("fabric", 0.3, Color(1.35, 1.12, 0.8)), false)
	PlaceDetail.sign(c, "Bitte Kaffee\nnachkaufen!!\n– M.", Vector3(2.96, 1.35, -0.6), Vector2(0.18, 0.14), -90.0, Color(0.95, 0.92, 0.55), Color(0.15, 0.15, 0.3), 18, false)
	# Papierkorb mit zerknülltem Papier, Heizlüfter, Hocker
	BuildKit.lathe(c, PackedVector2Array([Vector2(0, 0), Vector2(0.12, 0), Vector2(0.14, 0.32), Vector2(0.135, 0.32), Vector2(0.115, 0.01), Vector2(0, 0.01)]), Vector3(2.2, y, -0.4), PlaceDetail.col(Color(0.25, 0.25, 0.28), 0.6, 0.4), 12)
	for k in 4:
		BuildKit.sphere(c, 0.04, Vector3(2.2 + sin(k * 2.0) * 0.05, y + 0.3 + (k % 2) * 0.03, -0.4 + cos(k * 2.0) * 0.05), PlaceKit.mat("paper"), Vector3(1, 0.8, 1), 5)
	BuildKit.sphere(c, 0.04, Vector3(1.9, y + 0.03, -0.1), PlaceKit.mat("paper"), Vector3(1, 0.8, 1), 5)
	BuildKit.box(c, Vector3(0.3, 0.4, 0.18), Vector3(-0.3, y + 0.2, 0.95), PlaceDetail.col(Color(0.82, 0.82, 0.8), 0.5), false, Vector3(0, 15, 0))
	for k in 5:
		BuildKit.box(c, Vector3(0.22, 0.015, 0.005), Vector3(-0.3, y + 0.1 + k * 0.05, 0.85), PlaceDetail.col(Color(0.2, 0.2, 0.2)), false, Vector3(0, 15, 0))
	PlaceDetail.cable(c, Vector3(-0.3, y + 0.15, 0.86), Vector3(0.3, 0.3, -1.15), 0.05, 0.006)
	var stool := Node3D.new()
	stool.position = Vector3(-2.1, y, 0.6)
	c.add_child(stool)
	BuildKit.cylinder(stool, 0.17, 0.04, Vector3(0, 0.6, 0), PlaceDetail.col(Color(0.12, 0.12, 0.13), 0.8), false, Vector3.ZERO, -1.0, 12)
	for k in 3:
		var a := TAU * k / 3.0
		BuildKit.beam_between(stool, Vector3(cos(a) * 0.08, 0.58, sin(a) * 0.08), Vector3(cos(a) * 0.2, 0.0, sin(a) * 0.2), 0.02, PlaceKit.mat("metal"))


## Gelände: Stromaggregat, Kabeltrommel, Fässer, Paletten, Messpfähle, Mast, Schacht, Stefanies Spur.
static func _mess_yard(root: Node3D) -> void:
	# Stromaggregat (Gehäuse auf Kufen) mit Tank und Kanister
	var gp := PlaceKit.on_ground(root, 5.4, -4.3)
	var gen := Node3D.new()
	gen.name = "Generator"
	gen.position = gp
	gen.rotation_degrees.y = 90.0
	root.add_child(gen)
	var green := PlaceDetail.col(Color(0.22, 0.32, 0.22), 0.6, 0.3)
	BuildKit.box(gen, Vector3(1.8, 1.1, 0.95), Vector3(0, 0.65, 0), green, true)
	for sx: float in [-1.0, 1.0]:
		BuildKit.box(gen, Vector3(2.0, 0.1, 0.1), Vector3(0, 0.05, sx * 0.4), PlaceKit.mat("steel_dark"), false)
	for k in 8:
		BuildKit.box(gen, Vector3(0.02, 0.5, 0.012), Vector3(-0.6 + k * 0.08, 0.75, 0.48), PlaceDetail.col(Color(0.08, 0.08, 0.08)), false)
	BuildKit.cylinder(gen, 0.05, 0.5, Vector3(0.7, 1.4, 0.0), PlaceKit.mat("rust"), false, Vector3.ZERO, -1.0, 8)
	PlaceDetail.sign(gen, "ReZort\nNotstrom 20 kVA", Vector3(0.3, 0.95, 0.485), Vector2(0.4, 0.2), 0.0, Color(0.9, 0.9, 0.85), Color(0.1, 0.1, 0.1), 26)
	PlaceDetail.cable(root, gp + Vector3(-0.4, 0.4, 0.0), Vector3(3.08, PlaceKit.ground(root, 3.1, -1.6) + 0.7, -1.6), 0.4, 0.02)
	# Kabeltrommel, Fässer, Paletten, Eimer
	var drum := PlaceKit.on_ground(root, 5.6, 3.6)
	for sx: float in [-1.0, 1.0]:
		BuildKit.cylinder(root, 0.6, 0.06, drum + Vector3(sx * 0.35, 0.6, 0), PlaceKit.mat("wood_old"), false, Vector3(0, 0, 90), -1.0, 16)
	BuildKit.cylinder(root, 0.4, 0.64, drum + Vector3(0, 0.6, 0), PlaceDetail.col(Color(0.08, 0.08, 0.08), 0.6), true, Vector3(0, 0, 90), -1.0, 16)
	PlaceDetail.barrel(root, PlaceKit.on_ground(root, 6.6, -1.0), "rust")
	PlaceDetail.barrel(root, PlaceKit.on_ground(root, 7.1, -0.3), "rust", false, 40.0)
	PlaceDetail.barrel(root, PlaceKit.on_ground(root, 6.3, 0.6), "rust", true, 70.0)
	PlaceDetail.pallet(root, PlaceKit.on_ground(root, -4.8, 4.3), 15.0)
	PlaceDetail.pallet(root, PlaceKit.on_ground(root, -4.75, 4.3, 0.15), 22.0)
	PlaceDetail.pallet(root, PlaceKit.on_ground(root, -7.6, 3.6), 90.0, true)
	PlaceDetail.bucket(root, PlaceKit.on_ground(root, -3.6, 4.0), "metal", true)
	PlaceDetail.crate(root, PlaceKit.on_ground(root, -5.9, 4.6), Vector3(0.7, 0.5, 0.5), 10.0)
	PlaceDetail.crate(root, PlaceKit.on_ground(root, -5.9, 4.6, 0.5), Vector3(0.6, 0.4, 0.45), 30.0)
	# Mast mit Schüssel, Leitersprossen, Kabel zum Container
	var g := PlaceKit.ground(root, 5.5, 3.5)
	BuildKit.cylinder(root, 0.09, 7.0, Vector3(5.5, g + 3.5, 1.8), PlaceKit.mat("metal"), true, Vector3.ZERO, 0.06, 10)
	for k in 14:
		BuildKit.box(root, Vector3(0.3, 0.025, 0.025), Vector3(5.5, g + 0.5 + k * 0.45, 1.9), PlaceKit.mat("metal"), false)
	var dish := Node3D.new()
	dish.position = Vector3(5.5, g + 6.4, 1.5)
	dish.rotation_degrees = Vector3(65, 30, 0)
	root.add_child(dish)
	BuildKit.lathe(dish, PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.3, 0.03), Vector2(0.55, 0.12), Vector2(0.6, 0.16), Vector2(0.58, 0.17), Vector2(0.0, 0.02)]), Vector3.ZERO, PlaceKit.mat("white"), 20)
	BuildKit.cylinder(dish, 0.015, 0.5, Vector3(0, 0.3, 0), PlaceKit.mat("metal"), false, Vector3.ZERO, -1.0, 6)
	BuildKit.box(dish, Vector3(0.1, 0.1, 0.1), Vector3(0, 0.56, 0), PlaceDetail.col(Color(0.2, 0.2, 0.2)), false)
	PlaceDetail.cable(root, Vector3(5.5, g + 5.8, 1.75), Vector3(3.0, PlaceKit.ground(root, 3, -1) + 2.9, -0.6), 0.6, 0.014)
	# Messpfähle draußen im Wald (weiße Kästchen auf Pfosten mit Leuchtdiode)
	for k in 5:
		var mp := PlaceKit.on_ground(root, -14.0 + k * 7.0, -11.0 - (k % 2) * 3.0)
		BuildKit.box(root, Vector3(0.08, 1.2, 0.08), mp + Vector3(0, 0.6, 0), PlaceKit.mat("wood_old"), false)
		BuildKit.box(root, Vector3(0.18, 0.22, 0.12), mp + Vector3(0, 1.25, 0.05), PlaceKit.mat("white"), false)
		BuildKit.box(root, Vector3(0.012, 0.012, 0.004), mp + Vector3(0.05, 1.3, 0.112), BuildKit.emissive_mat(Color(1.0, 0.2, 0.1), 2.0), false)
		PlaceDetail.sign(root, "MP4-N/%02d" % (k + 1), mp + Vector3(0, 1.08, 0.115), Vector2(0.16, 0.05), 0.0, Color(0.95, 0.95, 0.9), Color(0.1, 0.1, 0.1), 18, false)
	# Schachtdeckel mit Betonring, Warnstreifen, Kabeln im Schutzrohr
	var m := PlaceKit.on_ground(root, -4.5, 3.5)
	BuildKit.cylinder(root, 0.85, 0.2, m + Vector3(0, 0.05, 0), PlaceKit.mat("concrete"), true, Vector3.ZERO, -1.0, 18)
	BuildKit.cylinder(root, 0.6, 0.1, m + Vector3(0, 0.18, 0), PlaceKit.mat("steel_dark"), true, Vector3.ZERO, -1.0, 14)
	for k in 8:
		var a := TAU * k / 8.0
		BuildKit.box(root, Vector3(0.12, 0.012, 0.25), m + Vector3(cos(a) * 0.72, 0.155, sin(a) * 0.72), PlaceKit.mat("yellow") if k % 2 == 0 else PlaceDetail.col(Color(0.05, 0.05, 0.05)), false, Vector3(0, -rad_to_deg(a), 0))
	var orange := PlaceDetail.col(Color(0.85, 0.4, 0.08), 0.6)
	HandKit.tube(root, PackedVector3Array([m + Vector3(0.6, 0.1, -0.2), m + Vector3(1.5, 0.05, -1.0), m + Vector3(3.0, 0.05, -2.3), Vector3(-1.2, PlaceKit.ground(root, -1.2, 0.3) + 0.05, 0.3)]), 0.06, orange, 8)
	HandKit.tube(root, PackedVector3Array([m + Vector3(-0.5, 0.1, 0.3), m + Vector3(-2.0, -0.2, 2.0), m + Vector3(-3.5, -0.3, 4.5)]), 0.06, orange, 8)
	PlaceKit.inspect(root, "Shaft", "[E] Schachtdeckel ansehen", "Verschweißt. Die Kabel verschwinden durch eine Dichtung in die Tiefe. Wenn man das Ohr an den Deckel legt: ein tiefes, gleichmäßiges Brummen.", m, Vector3(1.3, 0.3, 1.3))
	# Stefanies Spur: Haarspange im Zaun (Ostseite)
	var clip := PlaceKit.on_ground(root, 8.15, 1.5, 1.05)
	BuildKit.box(root, Vector3(0.012, 0.018, 0.07), clip, BuildKit.color_mat(Color(0.15, 0.3, 0.75), 0.4), false, Vector3(0, 0, 15))
	BuildKit.box(root, Vector3(0.014, 0.014, 0.014), clip + Vector3(0.0, 0.01, 0.0), BuildKit.color_mat(Color(0.85, 0.85, 0.9), 0.3, 0.6), false)
	PlaceKit.note(root, "stef_spange", clip - Vector3(0, 0.9, 0), true)
	# Laub, Unkraut am Zaun
	PlaceDetail.litter(root, Vector3(0, 0, 0), 9.0, 909, 70, ["leaf", "leaf", "twig", "stone"], func(x: float, z: float) -> float: return PlaceKit.ground(root, x, z) + 0.04)
	for k in 16:
		var a := TAU * k / 16.0
		var p := Vector3(clampf(cos(a) * 11.0, -7.8, 7.8), 0, clampf(sin(a) * 9.0, -5.8, 5.8))
		p.y = PlaceKit.ground(root, p.x, p.z)
		PlaceDetail.weeds(root, p, 700 + k, 7, 0.5)


## Funkmast auf dem Siebensteinkopf: Gittermast, Technikhäuschen ohne Strom. Reparieren = Funkkontakt.
static func _funkmast(root: Node3D) -> void:
	var steel := PlaceKit.mat("metal")
	var g := PlaceKit.ground(root, 0, 0)
	var top := 28.0
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			# Beine laufen nach oben zusammen
			var a := Vector3(sx * 0.95, g, sz * 0.95)
			var e := Vector3(sx * 0.25, g + top, sz * 0.25)
			var dir := (e - a).normalized()
			var rot := Basis(Quaternion(Vector3.UP, dir)).get_euler()
			BuildKit.cylinder(root, 0.08, a.distance_to(e), (a + e) * 0.5, steel, false, rot * (180.0 / PI), 0.05, 6)
	var y := 1.5
	while y < top:
		var w := lerpf(1.9, 0.5, y / top)
		for k in 4:
			var a := k * 90.0
			var off := Vector3(0, 0, w * 0.5).rotated(Vector3.UP, deg_to_rad(a))
			BuildKit.box(root, Vector3(w, 0.05, 0.05), Vector3(off.x, g + y, off.z), steel, false, Vector3(0, a, 0))
			BuildKit.box(root, Vector3(w * 1.35, 0.04, 0.04), Vector3(off.x, g + y + 0.9, off.z), steel, false, Vector3(0, a, 35))
		y += 1.8
	BuildKit.collider_box(root, Vector3(2.0, top, 2.0), Vector3(0, g + top * 0.5, 0))
	for k in 3:
		BuildKit.cylinder(root, 0.35, 0.8, Vector3(0.3 * (k - 1), g + top - 2.0 - k * 2.5, 0.5), PlaceKit.mat("white"), false, Vector3(90, k * 30, 0), -1.0, 10)
	var lamp_mat := StandardMaterial3D.new()
	lamp_mat.albedo_color = Color(0.4, 0.05, 0.03)
	lamp_mat.emission_enabled = true
	lamp_mat.emission = Color(1.0, 0.15, 0.1)
	lamp_mat.emission_energy_multiplier = 0.0
	var lamp := BuildKit.sphere(root, 0.15, Vector3(0, g + top + 0.2, 0), lamp_mat, Vector3.ONE, 8)
	lamp.name = "MastLamp"
	var hut := PlaceKit.hut(root, "TechHut", Vector3(5.5, PlaceKit.ground(root, 5.5, 3.0), 3.0), Vector2(3.2, 2.6), 2.4, -90.0, "concrete", "flat", "concrete", 0.9, false)
	BuildKit.box(hut, Vector3(0.9, 1.0, 0.6), Vector3(-0.9, 0.5, -0.8), PlaceKit.mat("steel_dark"), true)
	BuildKit.box(hut, Vector3(0.6, 1.8, 0.5), Vector3(0.9, 0.9, -0.9), PlaceKit.mat("steel_dark"), true)
	for k in 5:
		BuildKit.box(hut, Vector3(0.5, 0.02, 0.02), Vector3(0.9, 0.4 + k * 0.3, -0.64), BuildKit.emissive_mat(Color(0.2, 0.8, 0.3), 0.0), false)
	PlaceKit.loot(hut, "RadioParts", "radio_parts", 2, Vector3(-1.0, 1.02, -0.8), "case")
	PlaceKit.loot(hut, "Electronics", "electronics", 2, Vector3(0.2, 0.06, 0.6), "box")
	PlaceKit.blueprint(hut, "bp_antenna", "Richtantenne", Vector3(-0.6, 1.02, -0.7))
	PlaceKit.note(hut, "funkmast_zettel", Vector3(0.3, 1.5, -1.22), true)
	BuildKit.box(hut, Vector3(0.22, 0.3, 0.01), Vector3(0.3, 1.5, -1.24), PlaceKit.mat("paper"), false)
	var fix := PlaceKit.inspect(hut, "MastRepair", "[E] Notstrom und Sender reparieren", "Das Notstromaggregat ist leer und der Sender ausgeschlachtet. Ich brauche Funkteile und eine Batterie.",
			Vector3(0.9, 0.0, -0.6), Vector3(0.8, 1.8, 0.8))
	fix.needs = {"radio_parts": 2, "battery": 1}
	fix.done_flag = "mast_repaired"
	fix.done_prompt = "Sender läuft  –  Kanal 7"
	fix.done_text = "Der Sender summt, oben blinkt die rote Lampe. Aus dem Lautsprecher: Rauschen – und ganz kurz eine Frauenstimme: »…Kanal sieben… ist da jemand?«"
	var apply := func() -> void:
		lamp_mat.emission_energy_multiplier = 3.0
	if fix.done:
		apply.call()
	fix.acted.connect(apply)
	_funkmast_details(root, hut)


## Rachelsee: Bootshaus mit Steg, ein Auto halb im Wasser, darin ein Firmenausweis.
static func _see(root: Node3D) -> void:
	var house := PlaceKit.hut(root, "Boathouse", Vector3(0, PlaceKit.ground(root, 0, 4.0) + 0.1, 4.0), Vector2(4.0, 5.0), 2.4, 0.0, "wood_old", "gable", "shingles", 1.4, true)
	PlaceKit.loot(house, "Plugs", "spark_plug", 2, Vector3(-1.2, 0.06, 1.6), "box")
	PlaceKit.loot(house, "Oil", "motor_oil", 1, Vector3(1.2, 0.06, 1.7), "canister")
	PlaceKit.loot(house, "Fuel", "fuel_can", 1, Vector3(1.3, 0.06, -1.6), "canister")
	BuildKit.box(house, Vector3(1.0, 0.35, 2.6), Vector3(-0.8, 0.2, -0.4), PlaceKit.mat("wood"), true, Vector3(0, 8, 0))
	# Steg in den See (+z = Wasser)
	var level := WorldMap.lake_level(WorldMap.lakes()[0]) - root.global_position.y
	var jetty := StaticBody3D.new()
	jetty.name = "Jetty"
	root.add_child(jetty)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.6, 0.12, 16.0)
	cs.shape = shape
	cs.position = Vector3(1.5, level + 0.45, 16.0)
	jetty.add_child(cs)
	for k in 50:
		BuildKit.box(root, Vector3(1.6, 0.06, 0.28), Vector3(1.5, level + 0.48, 8.2 + k * 0.32), PlaceKit.mat("wood_old"), false, Vector3(0, randf_range(-2, 2), 0))
	for k in 6:
		for sx: float in [-0.75, 0.75]:
			BuildKit.cylinder(root, 0.07, 3.0, Vector3(1.5 + sx, level - 0.9, 9.0 + k * 3.0), PlaceKit.mat("bark"), false, Vector3.ZERO, -1.0, 6)
	# Ruderboot am Steg
	var boat := Node3D.new()
	boat.position = Vector3(3.2, level + 0.05, 18.0)
	boat.rotation_degrees = Vector3(0, 5, 3)
	root.add_child(boat)
	BuildKit.box(boat, Vector3(1.1, 0.35, 3.2), Vector3(0, 0.1, 0), PlaceKit.mat("wood"), false)
	BuildKit.box(boat, Vector3(0.9, 0.05, 2.9), Vector3(0, 0.25, 0), PlaceKit.mat("wood_old"), false)
	var water := WaterSource.new()
	water.name = "LakeWater"
	water.label = "Rachelsee"
	water.anchor = Vector3(1.5, level - 0.4, 23.5)
	water.solid = false
	water.contaminable = true
	water.collider_size = Vector3(1.6, 0.9, 1.0)
	root.add_child(water)
	# Auto halb im Wasser
	var car := Node3D.new()
	car.name = "SunkenCar"
	car.position = Vector3(-9.0, PlaceKit.ground(root, -9.0, 17.0) + 0.3, 17.0)
	car.rotation_degrees = Vector3(6, 160, -8)
	root.add_child(car)
	var paint := BuildKit.tex_mat("car_paint", 1.0, Color(0.35, 0.4, 0.5))
	BuildKit.box(car, Vector3(1.8, 0.7, 4.3), Vector3(0, 0.45, 0), paint, true)
	BuildKit.box(car, Vector3(1.6, 0.55, 2.2), Vector3(0, 1.08, -0.2), paint, false)
	BuildKit.box(car, Vector3(1.55, 0.45, 0.04), Vector3(0, 1.1, 0.92), PlaceKit.mat("glass"), false, Vector3(-30, 0, 0))
	for sx: float in [-0.92, 0.92]:
		for sz: float in [-1.3, 1.3]:
			BuildKit.cylinder(car, 0.32, 0.22, Vector3(sx, 0.15, sz), PlaceKit.mat("dark"), false, Vector3(0, 0, 90), -1.0, 12)
	PlaceKit.note(car, "see_ausweis", Vector3(0.95, 0.95, 0.3), true)
	_see_details(root, house, car, level)


## Granitbruch: tiefe Grube, Bagger, Bürocontainer am Rand, verschlossenes Sprengstofflager in der Wand.
static func _steinbruch(root: Node3D) -> void:
	# Bagger auf der Sohle
	var dig := Node3D.new()
	dig.name = "Excavator"
	dig.position = PlaceKit.on_ground(root, 6.0, 4.0)
	dig.rotation_degrees.y = 35.0
	root.add_child(dig)
	var yellow := PlaceKit.mat("yellow")
	BuildKit.box(dig, Vector3(2.6, 0.7, 3.6), Vector3(0, 0.35, 0), PlaceKit.mat("dark"), true)
	BuildKit.box(dig, Vector3(2.4, 1.4, 2.4), Vector3(0, 1.4, -0.3), yellow, true)
	BuildKit.box(dig, Vector3(1.0, 1.1, 1.0), Vector3(-0.6, 2.6, 0.4), PlaceKit.mat("glass"), false)
	BuildKit.box(dig, Vector3(0.4, 0.4, 4.0), Vector3(0.5, 2.8, 2.4), yellow, false, Vector3(-35, 0, 0))
	BuildKit.box(dig, Vector3(0.35, 0.35, 3.0), Vector3(0.5, 2.4, 5.0), yellow, false, Vector3(60, 0, 0))
	BuildKit.box(dig, Vector3(1.2, 0.7, 0.8), Vector3(0.5, 0.6, 6.2), PlaceKit.mat("rust"), false)
	PlaceKit.loot(root, "Scrap", "scrap", 6, PlaceKit.on_ground(root, 2.5, 8.5), "parts", 2)
	# Felsbrocken auf der Sohle
	for i in 10:
		var a := TAU * i / 10.0 + 0.4
		BuildKit.sphere(root, randf_range(0.6, 1.4), PlaceKit.on_ground(root, cos(a) * 25.0, sin(a) * 25.0, 0.3), PlaceKit.mat("rock"), Vector3(1.3, 0.8, 1.1), 7)
	# Sprengstofflager in der Nordwand
	var bp := PlaceKit.on_ground(root, -4.0, -30.0)
	var bunker := Node3D.new()
	bunker.name = "Bunker"
	bunker.position = bp
	root.add_child(bunker)
	BuildKit.box(bunker, Vector3(4.0, 2.6, 3.0), Vector3(0, 1.3, -1.0), PlaceKit.mat("concrete"), true)
	BuildKit.box(bunker, Vector3(1.2, 2.0, 0.08), Vector3(0, 1.0, 0.55), PlaceKit.mat("steel_dark"), false)
	label(bunker, "SPRENGSTOFF\nZutritt verboten", Vector3(0, 2.2, 0.6), 34, Color(0.8, 0.1, 0.05))
	var lock := PlaceKit.inspect(bunker, "BunkerDoor", "[E] Stahltür des Sprengstofflagers öffnen", "Abgeschlossen. Der Schlüssel muss irgendwo im Büro sein.", Vector3(0, 0, 0.9), Vector3(1.4, 2.0, 0.6))
	lock.needs = {"quarry_key": 1}
	lock.gives = {"explosive": 2}
	lock.done_flag = "quarry_bunker"
	lock.done_prompt = "Sprengstofflager – leer geräumt"
	lock.done_text = "Die Tür schwingt auf. Zwei Kisten Sprengstoff – nimm sie mit, aber vorsichtig."
	# Büro am oberen Rand
	var op := PlaceKit.on_ground(root, 30.0, -36.0)
	var office := PlaceKit.hut(root, "Office", op + Vector3(0, 0.2, 0), Vector2(5.0, 2.5), 2.4, 230.0, "tin", "flat", "tin", 0.9, true)
	BuildKit.box(office, Vector3(1.4, 0.04, 0.7), Vector3(-1.2, 0.78, -0.7), PlaceKit.mat("wood"), true)
	PlaceKit.note(office, "steinbruch_buch", Vector3(-1.4, 0.8, -0.7))
	PlaceKit.loot(office, "Key", "quarry_key", 1, Vector3(-0.8, 0.8, -0.8), "card")
	PlaceKit.blueprint(office, "bp_charge", "Sprengladung", Vector3(1.4, 0.06, -0.8))
	PlaceKit.loot(office, "Nails", "nails", 20, Vector3(1.6, 0.06, 0.6), "box", 10)
	_steinbruch_details(root, dig, office)


## Kontrollpunkt an der Straße: Schranke, Armeezelte, Sandsäcke, umgekippter LKW. Niemand mehr da.
	_stollen(root)


static func _kontrollpunkt(root: Node3D) -> void:
	var olive := PlaceKit.mat("olive")
	# Schranke über die Straße
	var g := PlaceKit.ground(root, 0, 0)
	BuildKit.box(root, Vector3(0.4, 1.0, 0.4), Vector3(-4.0, g + 0.5, 0), PlaceKit.mat("concrete"), true)
	var bar := BuildKit.box(root, Vector3(7.5, 0.12, 0.12), Vector3(-0.3, g + 1.0, 0), PlaceKit.mat("white"), false, Vector3(0, 0, 12))
	for k in 5:
		BuildKit.box(bar, Vector3(0.6, 0.13, 0.13), Vector3(-3.0 + k * 1.5, 0, 0), PlaceKit.mat("red"), false)
	# Sandsäcke
	for side: float in [-1.0, 1.0]:
		for k in 8:
			for row in 3:
				var p := PlaceKit.on_ground(root, side * 7.0, -3.0 + k * 0.8, 0.15 + row * 0.25)
				BuildKit.box(root, Vector3(0.6, 0.25, 0.75), p + Vector3(0, 0, (row % 2) * 0.3), BuildKit.tex_mat("fabric", 0.4, Color(0.9, 0.82, 0.6)), false)
		BuildKit.collider_box(root, Vector3(0.7, 0.8, 6.5), PlaceKit.on_ground(root, side * 7.0, 0.0, 0.4))
	# Zelte
	for t in 2:
		var tp := PlaceKit.on_ground(root, 12.0 + t * 7.0, -5.0 + t * 8.0)
		var tent := Node3D.new()
		# fester Name: die Funde darin gehören zum Spielstand
		tent.name = "Tent%d" % (t + 1)
		tent.position = tp
		tent.rotation_degrees.y = 90.0
		root.add_child(tent)
		for sx: float in [-1.0, 1.0]:
			BuildKit.box(tent, Vector3(3.0, 0.05, 5.0), Vector3(sx * 1.2, 1.1, 0), olive, true, Vector3(0, 0, sx * 48.0))
		BuildKit.box(tent, Vector3(3.6, 1.8, 0.05), Vector3(0, 0.9, -2.5), olive, false)
		if t == 0:
			BuildKit.box(tent, Vector3(1.6, 0.05, 0.8), Vector3(0, 0.75, -1.0), PlaceKit.mat("wood"), true)
			PlaceKit.note(tent, "kontrollpunkt_funk", Vector3(-0.3, 0.78, -1.0))
			BuildKit.box(tent, Vector3(0.4, 0.3, 0.3), Vector3(0.4, 0.92, -1.1), PlaceKit.mat("steel_dark"), false)
			PlaceKit.loot(tent, "Rations", "ration", 4, Vector3(-0.8, 0.0, 1.0), "box", 1)
			PlaceKit.loot(tent, "Medkits", "medkit", 2, Vector3(0.8, 0.0, 1.2), "medkit")
		else:
			PlaceKit.loot(tent, "Water", "water", 2, Vector3(0.0, 0.0, 0.8), "bottles")
			PlaceKit.loot(tent, "Fuel", "fuel_can", 1, Vector3(-0.9, 0.0, -1.2), "canister")
			for k in 4:
				BuildKit.box(tent, Vector3(0.7, 0.3, 1.8), Vector3(-1.0 + (k % 2) * 2.0, 0.15, -1.5 + (k / 2) * 2.2), olive, false)
	# Umgekippter Militär-LKW
	var truck := Node3D.new()
	truck.position = PlaceKit.on_ground(root, -13.0, 9.0, 1.2)
	truck.rotation_degrees = Vector3(0, 70, 84)
	root.add_child(truck)
	BuildKit.box(truck, Vector3(2.4, 2.4, 2.2), Vector3(0, 0, 3.0), olive, false)
	BuildKit.box(truck, Vector3(2.4, 2.6, 5.0), Vector3(0, 0.2, -0.8), olive, false)
	for sz: float in [3.0, -0.5, -2.5]:
		for sx: float in [-1.1, 1.1]:
			BuildKit.cylinder(truck, 0.5, 0.4, Vector3(sx, -1.2, sz), PlaceKit.mat("dark"), false, Vector3(0, 0, 90), -1.0, 12)
	BuildKit.collider_box(root, Vector3(3.0, 2.6, 7.5), PlaceKit.on_ground(root, -13.0, 9.0, 1.2), Vector3(0, 70, 0))
	_kontrollpunkt_details(root)


## Ferienlager Waldfuchs: kleine Hütten im Halbkreis, Speisehütte, Fahnenmast. Die Betten sind frisch gemacht.
static func _ferienlager(root: Node3D) -> void:
	var canteen := PlaceKit.hut(root, "Canteen", Vector3(0, PlaceKit.ground(root, 0, -8.0), -8.0), Vector2(8.0, 5.0), 2.6, 0.0, "wood", "gable", "shingles", 1.2, true)
	for k in 2:
		BuildKit.box(canteen, Vector3(3.0, 0.05, 0.9), Vector3(-1.8 + k * 3.6, 0.75, 0.0), PlaceKit.mat("wood"), true)
	PlaceKit.loot(canteen, "Tent", "tent", 1, Vector3(-2.8, 0.06, -1.6), "bag")
	PlaceKit.loot(canteen, "Food", "food", 3, Vector3(1.8, 0.78, 0.0), "cans")
	PlaceKit.loot(canteen, "Batteries", "battery", 2, Vector3(3.0, 0.06, -1.7), "case")
	label(canteen, "FERIENLAGER WALDFUCHS", Vector3(0, 2.25, 2.58), 44, Color(0.15, 0.3, 0.12))
	BuildKit.box(canteen, Vector3(3.6, 0.4, 0.03), Vector3(0, 2.25, 2.56), BuildKit.color_mat(Color(0.95, 0.9, 0.75)), false)
	for i in 5:
		var a := deg_to_rad(-60.0 + i * 30.0)
		var p := Vector3(sin(a) * 15.0, 0, cos(a) * 15.0 - 2.0)
		var cab := PlaceKit.hut(root, "Cabin_%d" % i, Vector3(p.x, PlaceKit.ground(root, p.x, p.z), p.z), Vector2(3.0, 3.2), 2.2, rad_to_deg(a) + 180.0, "wood", "gable", "shingles", 0.9, true)
		for b in 2:
			BuildKit.box(cab, Vector3(0.9, 0.3, 2.0), Vector3(-0.9 + b * 1.8, 0.3, -0.4), PlaceKit.mat("wood_h"), true)
			BuildKit.box(cab, Vector3(0.85, 0.08, 1.9), Vector3(-0.9 + b * 1.8, 0.49, -0.4), BuildKit.tex_mat("fabric", 0.4, Color(1.7, 1.65, 1.5)), false)
			BuildKit.box(cab, Vector3(0.5, 0.1, 0.3), Vector3(-0.9 + b * 1.8, 0.57, -1.2), BuildKit.tex_mat("fabric", 0.4, Color(1.9, 1.85, 1.75)), false)
		if i == 2:
			PlaceKit.note(cab, "lager_bild", Vector3(0.0, 1.4, -1.53), true)
			BuildKit.box(cab, Vector3(0.4, 0.3, 0.01), Vector3(0.0, 1.4, -1.55), BuildKit.color_mat(Color(0.95, 0.95, 0.9)), false)
	# Fahnenmast mit Wimpelkette
	var fp := PlaceKit.on_ground(root, 0, 4.0)
	BuildKit.cylinder(root, 0.06, 8.0, fp + Vector3(0, 4.0, 0), PlaceKit.mat("white"), true, Vector3.ZERO, 0.04, 8)
	for k in 10:
		var t := float(k) / 9.0
		var c := [Color(0.8, 0.2, 0.15), Color(0.95, 0.75, 0.2), Color(0.2, 0.5, 0.8)][k % 3] as Color
		BuildKit.box(root, Vector3(0.25, 0.3, 0.01), fp + Vector3(t * 7.0, 7.6 - t * 6.0 - sin(t * PI) * 0.8, 0), BuildKit.color_mat(c), false, Vector3(0, 0, 180))
	# Fahrräder
	for k in 3:
		var bp := PlaceKit.on_ground(root, -6.0 + k * 1.0, 1.5)
		BuildKit.cylinder(root, 0.33, 0.03, bp + Vector3(0, 0.33, -0.5), PlaceKit.mat("dark"), false, Vector3(0, 0, 90), -1.0, 12)
		BuildKit.cylinder(root, 0.33, 0.03, bp + Vector3(0, 0.33, 0.5), PlaceKit.mat("dark"), false, Vector3(0, 0, 90), -1.0, 12)
		BuildKit.box(root, Vector3(0.04, 0.04, 1.0), bp + Vector3(0, 0.55, 0), BuildKit.color_mat([Color(0.7, 0.1, 0.1), Color(0.1, 0.3, 0.7), Color(0.2, 0.6, 0.2)][k]), false, Vector3(-15, 0, 0))
	_ferienlager_details(root, canteen)


## Schäferkarren: Bauwagen auf einer Lichtung, die Herde liegt in einem perfekten Kreis, Köpfe nach innen.
static func _schaefer(root: Node3D) -> void:
	var wagon := Node3D.new()
	wagon.name = "Wagon"
	wagon.position = PlaceKit.on_ground(root, 0, -14.0, 0.7)
	wagon.rotation_degrees.y = 15.0
	root.add_child(wagon)
	BuildKit.box(wagon, Vector3(2.2, 2.0, 4.2), Vector3(0, 1.0, 0), PlaceKit.mat("wood"), true)
	BuildKit.cylinder(wagon, 1.25, 4.4, Vector3(0, 2.0, 0), PlaceKit.mat("tin"), false, Vector3(90, 0, 0), -1.0, 12).scale = Vector3(1.0, 1.0, 0.5)
	for sx: float in [-1.15, 1.15]:
		for sz: float in [-1.4, 1.4]:
			BuildKit.cylinder(wagon, 0.45, 0.1, Vector3(sx, -0.25, sz), PlaceKit.mat("wood_old"), false, Vector3(0, 0, 90), -1.0, 12)
	BuildKit.box(wagon, Vector3(0.8, 0.5, 0.05), Vector3(0.4, 1.2, 2.12), PlaceKit.mat("glass"), false)
	PlaceKit.note(wagon, "schaefer_tagebuch", Vector3(-0.5, 0.0, 2.3))
	PlaceKit.loot(wagon, "Wool", "wool", 3, Vector3(0.6, -0.65, 2.6), "wool")
	PlaceKit.loot(wagon, "Skin", "sheepskin", 1, Vector3(-0.6, -0.65, 2.7), "sack")
	PlaceKit.loot(wagon, "Food", "food", 1, Vector3(1.4, -0.65, 0.0), "cans")
	# Die Herde
	var wool := BuildKit.tex_mat("fabric", 0.3, Color(1.7, 1.65, 1.5))
	var dark := BuildKit.color_mat(Color(0.12, 0.1, 0.09))
	for i in 22:
		var a := TAU * i / 22.0
		var p := Vector3(cos(a) * 9.0, 0, sin(a) * 9.0)
		var s := Node3D.new()
		s.position = PlaceKit.on_ground(root, p.x, p.z, 0.25)
		s.rotation.y = atan2(-p.x, -p.z)
		root.add_child(s)
		BuildKit.sphere(s, 0.45, Vector3(0, 0, 0), wool, Vector3(0.9, 0.6, 1.4), 8)
		BuildKit.sphere(s, 0.16, Vector3(0, 0.05, -0.7), dark, Vector3(0.8, 0.8, 1.3), 6)
	# Pferch
	for k in 10:
		var a := TAU * k / 10.0
		BuildKit.cylinder(root, 0.06, 1.1, PlaceKit.on_ground(root, cos(a) * 13.0 + 3.0, sin(a) * 6.0 - 22.0, 0.55), PlaceKit.mat("bark"), false, Vector3.ZERO, -1.0, 6)
	_schaefer_details(root, wagon)


## Finsterauer Filz (Hochmoor): Holzstege über den Schlamm, Tümpel, Torfstich. Am Rand eines Tümpels liegt jemand.
static func _moor(root: Node3D) -> void:
	var o := root.global_position
	var plank := PlaceKit.mat("wood_old")
	var body := StaticBody3D.new()
	body.name = "Boardwalk"
	root.add_child(body)
	var bog: Dictionary = WorldMap.bogs()[0]
	var bc: Vector2 = bog["pos"]
	var br: float = bog["r"]
	for s: Array in WorldMap.segments():
		var a: Vector2 = s[0]
		var b: Vector2 = s[1]
		var len := a.distance_to(b)
		var n := int(len / 2.0)
		for k in n:
			var p := a.lerp(b, (k + 0.5) / n)
			if p.distance_to(bc) > br * 1.1:
				continue
			var dir := (b - a).normalized()
			var gy := Terrain.height_at(p.x, p.y) - o.y
			var lp := Vector3(p.x - o.x, gy + 0.32, p.y - o.z)
			var yaw := -rad_to_deg(atan2(dir.y, dir.x))
			BuildKit.box(root, Vector3(2.05, 0.07, 1.4), lp, plank, false, Vector3(0, yaw, 0))
			if k % 2 == 0:
				for side: float in [-0.6, 0.6]:
					var off := Vector2(-dir.y, dir.x) * side
					BuildKit.cylinder(root, 0.06, 0.8, lp + Vector3(off.x, -0.35, off.y), PlaceKit.mat("bark"), false, Vector3.ZERO, -1.0, 5)
			var cs := CollisionShape3D.new()
			var shape := BoxShape3D.new()
			shape.size = Vector3(2.1, 0.12, 1.4)
			cs.shape = shape
			cs.position = lp
			cs.rotation_degrees.y = yaw
			body.add_child(cs)
	# Schild am Stegbeginn (Süden)
	var sp := PlaceKit.on_ground(root, 26.0, 88.0)
	BuildKit.box(root, Vector3(0.1, 1.6, 0.1), sp + Vector3(0, 0.8, 0), PlaceKit.mat("bark"), true)
	BuildKit.box(root, Vector3(1.15, 0.66, 0.04), sp + Vector3(0, 1.45, 0.05), BuildKit.color_mat(Color(0.2, 0.4, 0.2)), false)
	label(root, "NATIONALPARK\nBAYERISCHER WALD\nFinsterauer Filz\nStege nicht verlassen!", sp + Vector3(0, 1.45, 0.08), 21, Color(0.95, 0.95, 0.85))
	PlaceKit.note(root, "moor_schild", sp + Vector3(0, 1.0, 0.1), true)
	# Moorleiche am Tümpel
	var pool: Vector3 = bog["pools"][0]
	var bp := Vector3(pool.x + pool.z * 0.95 - o.x, 0, pool.y - o.z)
	bp.y = Terrain.height_at(bp.x + o.x, bp.z + o.z) - o.y
	var corpse := Node3D.new()
	corpse.name = "BogBody"
	corpse.position = bp
	corpse.rotation_degrees.y = 60.0
	root.add_child(corpse)
	var skin := BuildKit.color_mat(Color(0.25, 0.17, 0.1), 0.6)
	BuildKit.box(corpse, Vector3(0.45, 0.22, 0.9), Vector3(0, 0.05, 0), skin, false)
	BuildKit.sphere(corpse, 0.13, Vector3(0, 0.08, -0.6), skin, Vector3(1.0, 0.8, 1.1), 8)
	BuildKit.box(corpse, Vector3(0.12, 0.1, 0.7), Vector3(0.3, 0.03, -0.2), skin, false, Vector3(0, 25, 0))
	BuildKit.box(corpse, Vector3(0.14, 0.12, 0.8), Vector3(-0.12, 0.0, 0.8), skin, false)
	PlaceKit.loot(corpse, "Implant", "alien_implant", 1, Vector3(0.0, 0.12, -0.72), "alien")
	# Torfstich am Steg
	var tp := PlaceKit.on_ground(root, 22.0, 30.0)
	PlaceKit.loot(root, "Peat", "peat", 6, tp, "peat", 2)
	BuildKit.box(root, Vector3(2.0, 0.02, 1.2), tp + Vector3(1.6, -0.1, 0), PlaceKit.mat("mud"), false)
	_moor_details(root, tp, corpse)


## Totholzhang (Windwurf): Hunderte Bäume liegen strahlenförmig um einen kleinen Krater – weg von einem Punkt.
static func _windwurf(root: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	var bark := PlaceKit.mat("bark")
	var body := StaticBody3D.new()
	body.name = "Logs"
	root.add_child(body)
	for i in 70:
		var a := rng.randf() * TAU
		var r := rng.randf_range(9.0, 64.0)
		var len := rng.randf_range(10.0, 16.0)
		var dir := Vector3(cos(a), 0, sin(a))
		var base := Vector3(dir.x * r, 0, dir.z * r)
		var mid := base + dir * len * 0.5
		var gy := PlaceKit.ground(root, mid.x, mid.z)
		var tr := rng.randf_range(0.18, 0.34)
		var yaw := -rad_to_deg(a)
		BuildKit.cylinder(root, tr, len, Vector3(mid.x, gy + tr, mid.z), bark, false, Vector3(0, yaw, 90), tr * 0.6, 7)
		# Wurzelteller zur Mitte hin
		var rb := BuildKit.cylinder(root, tr * 4.0, 0.3, Vector3(base.x, PlaceKit.ground(root, base.x, base.z) + tr * 3.0, base.z), PlaceKit.mat("mud"), false, Vector3(0, yaw, 90), -1.0, 9)
		rb.scale = Vector3(1.0, 1.0, 0.8)
		if r < 40.0:
			var cs := CollisionShape3D.new()
			var shape := CylinderShape3D.new()
			shape.radius = tr
			shape.height = len
			cs.shape = shape
			cs.position = Vector3(mid.x, gy + tr, mid.z)
			cs.rotation_degrees = Vector3(0, yaw, 90)
			body.add_child(cs)
	# Krater mit Sonde
	BuildKit.cylinder(root, 4.0, 0.03, PlaceKit.on_ground(root, 0, 0, 0.02), PlaceKit.mat("mud"), false, Vector3.ZERO, -1.0, 18)
	for i in 12:
		var a := TAU * i / 12.0
		BuildKit.sphere(root, 0.9, PlaceKit.on_ground(root, cos(a) * 4.2, sin(a) * 4.2), PlaceKit.mat("mud"), Vector3(1.6, 0.4, 1.0), 6)
	PlaceKit.loot(root, "Probe", "probe_core", 1, PlaceKit.on_ground(root, 0.3, -0.2), "device")
	PlaceKit.loot(root, "Wood1", "wood", 6, PlaceKit.on_ground(root, 12.0, 6.0), "logs", 2)
	PlaceKit.loot(root, "Wood2", "wood", 6, PlaceKit.on_ground(root, -14.0, -8.0), "logs", 2)
	_windwurf_details(root, rng)


## Lichtung der Spiegel: Spiegel an kahlen Stämmen, alle nach oben gerichtet. Darunter ein verlassenes Lager.
static func _spiegel(root: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var mirror := BuildKit.color_mat(Color(0.75, 0.8, 0.85), 0.05, 0.95)
	var frame := PlaceKit.mat("wood_old")
	for i in 14:
		var a := TAU * i / 14.0
		var p := PlaceKit.on_ground(root, cos(a) * 22.0, sin(a) * 22.0)
		var h := rng.randf_range(9.0, 14.0)
		BuildKit.cylinder(root, 0.3, h, p + Vector3(0, h * 0.5, 0), PlaceKit.mat("bark"), true, Vector3.ZERO, 0.18, 7)
		for k in 3:
			var y := 1.8 + k * rng.randf_range(1.6, 2.4)
			var out := Vector3(-cos(a), 0, -sin(a)) * 0.35
			var m := Node3D.new()
			m.position = p + out + Vector3(0, y, 0)
			m.rotation = Vector3(deg_to_rad(-rng.randf_range(55.0, 75.0)), atan2(-cos(a), -sin(a)), 0)
			root.add_child(m)
			BuildKit.box(m, Vector3(0.5, 0.65, 0.03), Vector3.ZERO, frame, false)
			BuildKit.box(m, Vector3(0.42, 0.57, 0.01), Vector3(0, 0, 0.02), mirror, false)
	# Lager unter der Plane
	var c := PlaceKit.on_ground(root, 3.0, 2.0)
	for sx: float in [-1.0, 1.0]:
		BuildKit.cylinder(root, 0.04, 1.6, c + Vector3(sx * 1.3, 0.8, 1.0), frame, false, Vector3.ZERO, -1.0, 6)
	BuildKit.box(root, Vector3(3.0, 0.03, 2.6), c + Vector3(0, 1.1, 0), PlaceKit.mat("canvas"), true, Vector3(25, 0, 0))
	BuildKit.box(root, Vector3(0.7, 0.12, 1.9), c + Vector3(-0.5, 0.06, -0.2), BuildKit.tex_mat("blanket", 0.5), false)
	PlaceKit.note(root, "spiegel_notiz", c + Vector3(0.6, 0.0, -0.4))
	PlaceKit.loot(root, "Food", "food", 1, c + Vector3(1.0, 0.0, 0.5), "cans")
	PlaceKit.loot(root, "Water", "water", 1, c + Vector3(1.0, 0.0, -0.6), "bottles")
	for k in 3:
		BuildKit.box(root, Vector3(0.22, 0.3, 0.14), c + Vector3(-1.2 + k * 0.3, 0.15, 1.3), BuildKit.color_mat(Color(0.2, 0.35, 0.6), 0.4), false, Vector3(0, 0, 80))
	_spiegel_details(root, c, rng)


## Alter Feldspat-Stollen in der Ostwand des Granitbruchs: Holzportal, Türstöcke, Schienen, ein Hunt (Förderwagen),
## am Ende verschüttet – und durch den Schutt wachsen fremde Wurzeln (Story: Wurzelwerk). Der Berg darüber ist per „cut“
## ausgeschnitten (map.json, floor_drop), das Gestein darüber deckt der Felsklotz ab.
static func _stollen(root: Node3D) -> void:
	# Portal am Fuß der Ostwand; der Geländeeinschnitt (map.json cuts) muss zu X0/LEN passen
	const X0 := 37.0
	const LEN := 24.0
	var floor_y := PlaceKit.ground(root, X0 - 3.0, 0.0)
	var s := Node3D.new()
	s.name = "Stollen"
	s.position = Vector3(X0, floor_y, 0)
	root.add_child(s)
	var rock := PlaceKit.mat("rock")
	var timber := PlaceKit.mat("wood_old")
	BuildKit.box(s, Vector3(LEN, 0.5, 3.4), Vector3(LEN * 0.5, -0.25, 0), PlaceKit.mat("stone_dark"), true)
	for sz: float in [-1.0, 1.0]:
		BuildKit.box(s, Vector3(LEN, 2.6, 0.5), Vector3(LEN * 0.5, 1.3, sz * 1.45), rock, true)
	BuildKit.box(s, Vector3(LEN, 0.5, 3.4), Vector3(LEN * 0.5, 2.75, 0), rock, true)
	# Gestein über dem Stollen bis zur Geländeoberfläche, abschnittsweise (folgt dem Hang)
	const SEGS := 24
	for k in SEGS:
		var x0 := X0 + k * LEN / SEGS
		var xm := x0 + LEN / SEGS * 0.5
		var top := (PlaceKit.ground(root, xm, -3.5) + PlaceKit.ground(root, xm, 3.5)) * 0.5 + 0.1
		if top > floor_y + 3.0:
			BuildKit.box(root, Vector3(LEN / SEGS + 0.05, top - floor_y - 2.9, 6.5), Vector3(xm, floor_y + 2.9 + (top - floor_y - 2.9) * 0.5, 0), rock, false)
	# Portal mit Schild
	for sz: float in [-1.0, 1.0]:
		BuildKit.box(s, Vector3(0.3, 2.6, 0.3), Vector3(0.1, 1.3, sz * 1.25), timber, true)
	BuildKit.box(s, Vector3(0.4, 0.35, 3.0), Vector3(0.1, 2.55, 0), timber, false)
	label(s, "STOLLEN I · 1923\nGlück auf", Vector3(-0.15, 2.55, 0), 24, Color(0.92, 0.88, 0.78), -90.0)
	# Türstöcke (Holzrahmen) alle 2,2 m, einer ist eingeknickt
	for k in int(LEN / 2.2):
		var x := 1.6 + k * 2.2
		var tilt := 9.0 if k == 6 else 0.0
		for sz: float in [-1.0, 1.0]:
			BuildKit.box(s, Vector3(0.18, 2.4, 0.18), Vector3(x, 1.2, sz * 1.1), timber, false, Vector3(tilt, 0, 0))
		BuildKit.box(s, Vector3(0.2, 0.18, 2.4), Vector3(x, 2.42, 0), timber, false, Vector3(0, 0, tilt * 0.5))
	# Schienen und Schwellen, Hunt
	for k in int((LEN - 4.0) / 0.7):
		BuildKit.box(s, Vector3(0.18, 0.08, 1.3), Vector3(0.6 + k * 0.7, 0.04, 0), timber, false)
	for sz: float in [-0.35, 0.35]:
		BuildKit.box(s, Vector3(LEN - 4.0, 0.06, 0.05), Vector3((LEN - 4.0) * 0.5 + 0.3, 0.11, sz), PlaceKit.mat("rust"), false)
	var cart := Node3D.new()
	cart.name = "Hunt"
	cart.position = Vector3(9.0, 0.14, 0)
	s.add_child(cart)
	BuildKit.box(cart, Vector3(1.3, 0.7, 0.9), Vector3(0, 0.55, 0), PlaceKit.mat("rust"), true)
	for wx: float in [-0.4, 0.4]:
		for wz: float in [-0.38, 0.38]:
			BuildKit.cylinder(cart, 0.14, 0.06, Vector3(wx, 0.14, wz), PlaceKit.mat("steel_dark"), false, Vector3(90, 0, 0), -1.0, 10)
	PlaceKit.loot(cart, "Scrap", "scrap", 4, Vector3(0, 0.92, 0), "parts", 2)
	PlaceKit.note(s, "stollen_tafel", Vector3(1.0, 0.05, -0.9))
	# Grubenlampe, fast leer
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.75, 0.45)
	lamp.light_energy = 0.35
	lamp.omni_range = 5.0
	lamp.position = Vector3(5.0, 2.2, 0.9)
	s.add_child(lamp)
	BuildKit.box(s, Vector3(0.12, 0.18, 0.12), Vector3(5.0, 2.2, 0.95), BuildKit.emissive_mat(Color(1.0, 0.75, 0.4), 0.8), false)
	# Verschüttetes Ende, fremde Wurzeln drängen durch
	var end_x := LEN - 3.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 1923
	for i in 16:
		BuildKit.sphere(s, rng.randf_range(0.35, 0.8), Vector3(end_x + rng.randf_range(-0.6, 1.4), rng.randf_range(0.2, 2.2), rng.randf_range(-1.1, 1.1)), rock, Vector3(1.2, 0.8, 1.0), 7)
	for i in 7:
		var a := Vector3(end_x + 1.5, rng.randf_range(0.4, 2.4), rng.randf_range(-1.0, 1.0))
		var b := Vector3(end_x - rng.randf_range(1.0, 3.0), rng.randf_range(0.0, 1.8), rng.randf_range(-1.2, 1.2))
		BuildKit.beam_between(s, a, b, rng.randf_range(0.06, 0.13), PlaceKit.mat("alien"))
	BuildKit.box(s, Vector3(0.6, 0.4, 0.6), Vector3(end_x - 2.2, 0.2, 0.7), PlaceKit.mat("wood_h"), true)
	PlaceKit.note(s, "stollen_wurzeln", Vector3(end_x - 2.2, 0.42, 0.7))
	var glow := OmniLight3D.new()
	glow.light_color = Color(0.6, 0.45, 1.0)
	glow.light_energy = 0.5
	glow.omni_range = 4.0
	glow.position = Vector3(end_x, 1.2, 0)
	s.add_child(glow)


## Reschbachklause (Etappe 4): alte Triftklause am Bach – Staudamm aus Granitquadern und Holz mit Klaustor,
## dahinter der Klausweiher (map.json lakes). Oben ein Steg zum Hinübergehen, Infotafel.
static func _klause(root: Node3D) -> void:
	var bed := PlaceKit.ground(root, 0, 0)
	var bank := maxf(PlaceKit.ground(root, -6.0, 0), PlaceKit.ground(root, 6.0, 0))
	var top := maxf(bank + 0.4, bed + 2.2)
	var stone := PlaceKit.mat("stone")
	var wood := PlaceKit.mat("wood_old")
	# Widerlager aus Granit links und rechts
	for sx: float in [-1.0, 1.0]:
		var gy := PlaceKit.ground(root, sx * 5.0, 0)
		var lo := minf(gy, bed) - 1.0
		BuildKit.box(root, Vector3(3.0, top - lo, 3.2), Vector3(sx * 4.5, lo + (top - lo) * 0.5, 0), stone, true)
	# Holzwand zwischen den Widerlagern (Bohlen), Mitte = Klaustor (etwas hochgezogen, Wasser läuft darunter durch)
	for k in int((top - bed) / 0.3) + 1:
		var y := bed - 0.4 + k * 0.3
		if y > top - 0.15:
			break
		BuildKit.box(root, Vector3(1.9, 0.26, 0.22), Vector3(-2.05, y, 0), wood, true)
		BuildKit.box(root, Vector3(1.9, 0.26, 0.22), Vector3(2.05, y, 0), wood, true)
		if y > bed + 0.55:
			BuildKit.box(root, Vector3(2.2, 0.26, 0.2), Vector3(0, y, -0.15), wood, false)
	for sx: float in [-1.15, 1.15]:
		BuildKit.box(root, Vector3(0.3, top - bed + 1.6, 0.3), Vector3(sx, bed + (top - bed + 1.6) * 0.5 - 0.3, 0), wood, true)
	BuildKit.box(root, Vector3(2.6, 0.3, 0.35), Vector3(0, top + 1.1, 0), wood, false)
	# Zugstange des Tors mit Kurbel
	BuildKit.box(root, Vector3(0.08, 1.4, 0.08), Vector3(0, top + 0.4, -0.15), PlaceKit.mat("rust"), false)
	BuildKit.cylinder(root, 0.25, 0.06, Vector3(0.4, top + 1.25, 0), PlaceKit.mat("rust"), false, Vector3(0, 0, 90), -1.0, 10)
	# Steg oben (begehbar) mit Geländer
	BuildKit.box(root, Vector3(12.0, 0.15, 1.3), Vector3(0, top, 0.85), wood, true)
	for k in 7:
		var x := -6.0 + k * 2.0
		BuildKit.box(root, Vector3(0.1, 1.0, 0.1), Vector3(x, top + 0.5, 1.45), wood, false)
	BuildKit.box(root, Vector3(12.0, 0.08, 0.08), Vector3(0, top + 0.95, 1.45), wood, true)
	var gate := PlaceKit.inspect(root, "KlausTor", "[E] Klaustor ansehen", "Das Tor sitzt fest, verkeilt mit altem Treibholz. Wasser drückt dagegen. Im Holz eingeschnitzt: »G. W. 1998« – und darunter, frisch, dieselben Buchstaben.", Vector3(0, top - 0.5, 0), Vector3(2.4, 1.6, 0.8))
	# Infotafel am Westufer
	var tp := PlaceKit.on_ground(root, -7.5, 2.5)
	BuildKit.box(root, Vector3(0.1, 1.5, 0.1), tp + Vector3(-0.6, 0.75, 0), wood, true)
	BuildKit.box(root, Vector3(0.1, 1.5, 0.1), tp + Vector3(0.6, 0.75, 0), wood, true)
	BuildKit.box(root, Vector3(1.4, 0.8, 0.05), tp + Vector3(0, 1.35, 0.06), PlaceKit.mat("wood_h"), false)
	label(root, "RESCHBACHKLAUSE\nTriftklause · erbaut 1849", tp + Vector3(0, 1.45, 0.1), 22, Color(0.1, 0.08, 0.05))
	PlaceKit.note(root, "klause_tafel", tp + Vector3(0.3, 1.15, 0.1))
	PlaceKit.loot(root, "Planks", "planks", 3, PlaceKit.on_ground(root, -7.0, -1.5), "logs", 1)
	_klause_details(root, bed, top)


## Lebendige Orte: Zaun mit Tor um den Mast, Steigleiter mit Rückenschutz, Kabelpritsche zur Technikhütte,
## Antennen, Warnschilder, Kiesfläche, Dieseltank, Kabeltrommel, Hütte innen mit Pult, Telefon, Schaltplan.
static func _funkmast_details(root: Node3D, hut: Node3D) -> void:
	var g := PlaceKit.ground(root, 0, 0)
	var steel := PlaceKit.mat("metal")
	PlaceKit.fence(root, [Vector2(-4.5, -4.5), Vector2(4.5, -4.5), Vector2(4.5, 4.5), Vector2(-4.5, 4.5), Vector2(-4.5, -4.5)], 2.0, [Vector2(27.5, 30.0)])
	for gx in 3:
		for gz in 3:
			var p := PlaceKit.on_ground(root, -3.0 + gx * 3.0, -3.0 + gz * 3.0, 0.02)
			BuildKit.box(root, Vector3(3.05, 0.04, 3.05), p, PlaceKit.mat("gravel"), false)
	# Steigleiter mit Rückenschutz (Ringe) an einem Bein
	for k in 40:
		BuildKit.box(root, Vector3(0.4, 0.025, 0.025), Vector3(0.0, g + 0.4 + k * 0.6, 1.05 - k * 0.012), steel, false)
	for k in 10:
		HandKit.tube(root, HandKit.arc(Vector3(0, g + 3.0 + k * 2.2, 1.05 - (3.0 + k * 2.2) * 0.02), 0.38, 200, 340, 8, Vector3.RIGHT, Vector3.FORWARD), 0.012, steel, 4)
	# Plattform oben, Richtantennen, Kabelbündel nach unten
	BuildKit.box(root, Vector3(1.6, 0.06, 1.6), Vector3(0, g + 24.5, 0), PlaceKit.mat("steel_dark"), false)
	for k in 4:
		var a := k * 90.0 + 45.0
		var off := Vector3(0, 0, 0.8).rotated(Vector3.UP, deg_to_rad(a))
		BuildKit.box(root, Vector3(0.04, 0.5, 1.6), Vector3(off.x, g + 24.8, off.z), steel, false, Vector3(0, a, 0))
		BuildKit.box(root, Vector3(0.28, 1.6, 0.1), Vector3(off.x * 0.7, g + 26.3, off.z * 0.7), PlaceKit.mat("white"), false, Vector3(0, a, 0))
	PlaceDetail.cable(root, Vector3(0.2, g + 24.4, 0.3), Vector3(0.3, g + 1.0, 0.8), 0.0, 0.035)
	# Kabelpritsche zur Hütte
	var hp := hut.global_position - root.global_position
	for k in 6:
		var t := float(k) / 5.0
		var p := Vector3(0.6, g, 0.8).lerp(Vector3(hp.x - 1.2, g, hp.z), t)
		p.y = PlaceKit.ground(root, p.x, p.z)
		BuildKit.box(root, Vector3(0.06, 0.9, 0.06), p + Vector3(0, 0.45, 0), steel, false)
	PlaceDetail.cable(root, Vector3(0.6, g + 0.9, 0.8), Vector3(hp.x - 1.2, PlaceKit.ground(root, hp.x - 1.2, hp.z) + 0.9, hp.z), 0.05, 0.05)
	PlaceDetail.sign(root, "Funkstation Siebensteinkopf\nBetreten verboten – Lebensgefahr", PlaceKit.on_ground(root, -4.55, -1.0, 1.3), Vector2(0.7, 0.36), -90.0, Color(0.95, 0.8, 0.1), Color(0.05, 0.05, 0.05), 28)
	PlaceDetail.sign(root, "Hochfrequenz!\nHerzschrittmacher-\nträger fernbleiben", PlaceKit.on_ground(root, 1.5, 4.55, 1.3), Vector2(0.45, 0.36), 0.0, Color(0.95, 0.95, 0.9), Color(0.6, 0.1, 0.08), 24)
	# Dieseltank, Kabeltrommel, Fass
	var tp := PlaceKit.on_ground(root, 8.5, -1.0)
	BuildKit.cylinder(root, 0.6, 2.0, tp + Vector3(0, 0.75, 0), PlaceDetail.col(Color(0.3, 0.38, 0.3), 0.6, 0.4), true, Vector3(90, 0, 0), -1.0, 16)
	for sz: float in [-0.7, 0.7]:
		BuildKit.box(root, Vector3(1.0, 0.2, 0.15), tp + Vector3(0, 0.1, sz), PlaceKit.mat("concrete"), false)
	PlaceDetail.sign(root, "DIESEL", tp + Vector3(0.61, 0.85, 0), Vector2(0.4, 0.15), 90.0, Color(0.95, 0.95, 0.9), Color(0.1, 0.1, 0.1), 28, false)
	PlaceDetail.barrel(root, PlaceKit.on_ground(root, 9.5, 1.2), "rust", true, 30.0)
	# Hütte innen: Pult, Telefon, Schaltplan, Leuchte, Stuhl
	PlaceDetail.table(hut, Vector3(1.15, 0.06, 0.55), Vector3(1.0, 0.75, 0.55), "steel_dark", 90.0)
	BuildKit.box(hut, Vector3(0.22, 0.08, 0.18), Vector3(1.15, 0.85, 0.5), PlaceDetail.col(Color(0.15, 0.15, 0.15), 0.4), false)
	PlaceDetail.office_chair(hut, Vector3(0.6, 0.06, 0.55), -90.0)
	PlaceDetail.sign(hut, "SCHALTPLAN NA 20\n— Netz —|— Akku —|— Sender K7 —", Vector3(-1.45, 1.5, 0.3), Vector2(0.9, 0.5), 90.0, Color(0.92, 0.94, 0.95), Color(0.1, 0.2, 0.5), 22)
	PlaceDetail.lamp(hut, Vector3(0, 2.3, 0), "hanging", false)
	PlaceDetail.clutter(hut, Vector3(1.15, 0.81, 0.3), Vector2(0.4, 0.3), 77, 2, ["papers"])
	PlaceDetail.litter(root, Vector3(4.0, 0, 2.0), 7.0, 433, 40, ["leaf", "twig", "stone"], func(x: float, z: float) -> float: return PlaceKit.ground(root, x, z) + 0.02)


## Lebendige Orte: Bootshaus mit Rudern, Rettungsring, Netzen, Bojen, Seilen, Werkzeugbrett; Steg mit Pollern, Leiter und
## Laternenpfahl; Bank, Schilf, Schild; das Auto mit Scheinwerfern, Stoßstangen, offener Tür, Kennzeichen.
static func _see_details(root: Node3D, house: Node3D, car: Node3D, level: float) -> void:
	var wood := PlaceKit.mat("wood_old")
	for k in 2:
		BuildKit.box(house, Vector3(0.06, 0.04, 2.4), Vector3(1.75, 1.2 + k * 0.15, 0.0), PlaceKit.mat("furn"), false, Vector3(0, 0, 70))
		BuildKit.box(house, Vector3(0.18, 0.02, 0.5), Vector3(1.8, 1.2 + k * 0.15, -1.1), PlaceKit.mat("furn"), false, Vector3(0, 0, 70))
	HandKit.tube(house, HandKit.arc(Vector3(-1.95, 1.4, 1.0), 0.28, 0, 360, 18, Vector3.FORWARD, Vector3.UP), 0.07, PlaceDetail.col(Color(0.9, 0.3, 0.1), 0.7), 8)
	for k in 4:
		HandKit.tube(house, HandKit.arc(Vector3(-1.96, 1.4, 1.0), 0.29, k * 90.0 + 20.0, k * 90.0 + 50.0, 4, Vector3.FORWARD, Vector3.UP), 0.072, PlaceDetail.col(Color(0.95, 0.95, 0.92), 0.7), 8)
	var net := BuildKit.color_mat(Color(0.35, 0.38, 0.3, 0.7), 1.0)
	net.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	net.cull_mode = BaseMaterial3D.CULL_DISABLED
	BuildKit.box(house, Vector3(0.02, 1.2, 1.4), Vector3(1.93, 1.4, -1.6), net, false, Vector3(0, 0, 4))
	for k in 3:
		BuildKit.sphere(house, 0.11, Vector3(1.85, 0.75 + k * 0.08, -1.2 - k * 0.3), PlaceDetail.col([Color(0.9, 0.4, 0.1), Color(0.95, 0.95, 0.9), Color(0.85, 0.15, 0.1)][k], 0.5), Vector3(1, 1.2, 1), 8)
	PlaceDetail.shelf(house, Vector3(0.0, 0.06, -2.4), 0.0, Vector3(1.4, 1.6, 0.35), 4, "wood_old")
	PlaceDetail.clutter(house, Vector3(0.0, 0.88, -2.22), Vector2(1.3, 0.3), 88, 4, ["jars", "tools", "boxes"])
	PlaceDetail.clutter(house, Vector3(0.0, 1.38, -2.22), Vector2(1.3, 0.3), 89, 3, ["bottles", "cans"])
	PlaceDetail.lamp(house, Vector3(0, 2.2, 0), "hanging", false)
	# Steg: Poller, Leiter am Ende, Laternenpfahl, Taue
	for k in 4:
		BuildKit.cylinder(root, 0.1, 0.5, Vector3(0.75 + (k % 2) * 1.5, level + 0.75, 10.0 + (k / 2) * 10.0), PlaceKit.mat("bark"), false, Vector3.ZERO, 0.08, 8)
	for k in 5:
		BuildKit.box(root, Vector3(0.5, 0.04, 0.05), Vector3(1.5, level + 0.3 - k * 0.3, 24.25), PlaceKit.mat("metal"), false)
	for sx: float in [-0.25, 0.25]:
		BuildKit.box(root, Vector3(0.04, 1.6, 0.04), Vector3(1.5 + sx, level - 0.1, 24.25), PlaceKit.mat("metal"), false)
	BuildKit.cylinder(root, 0.06, 2.4, Vector3(2.25, level + 1.65, 14.0), wood, false, Vector3.ZERO, 0.05, 8)
	PlaceDetail.lamp(root, Vector3(2.25, level + 2.8, 14.0), "wall", false, -90.0)
	PlaceDetail.cable(root, Vector3(2.25, level + 0.75, 20.0), Vector3(3.2, level + 0.35, 18.8), 0.15, 0.015, Color(0.65, 0.55, 0.35))
	# Bank am Ufer, Schild, Schilf
	var bench := Node3D.new()
	bench.position = PlaceKit.on_ground(root, -3.5, 7.0)
	bench.rotation_degrees.y = 180.0
	root.add_child(bench)
	PlaceDetail.pew(bench, Vector3.ZERO, 1.6, "wood_old")
	var sp := PlaceKit.on_ground(root, 4.5, 7.0)
	BuildKit.box(root, Vector3(0.08, 1.4, 0.08), sp + Vector3(0, 0.7, 0), wood, true)
	PlaceDetail.sign(root, "Rachelsee\nBaden und Bootfahren\nverboten – Nationalpark", sp + Vector3(0, 1.25, 0.05), Vector2(0.6, 0.36), 0.0, Color(0.25, 0.4, 0.25), Color(0.95, 0.95, 0.9), 28)
	var reed := PlaceDetail.col(Color(0.55, 0.5, 0.3), 1.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 707
	for k in 90:
		var x := rng.randf_range(-14.0, 12.0)
		if absf(x - 1.5) < 1.5:
			continue
		var z := 9.0 + rng.randf_range(-1.0, 2.0)
		var y := minf(PlaceKit.ground(root, x, z), level)
		var h := rng.randf_range(0.8, 1.6)
		BuildKit.cylinder(root, 0.008, h, Vector3(x, y + h * 0.5, z), reed, false, Vector3(rng.randf_range(-12, 12), 0, rng.randf_range(-12, 12)), 0.003, 3)
		if k % 4 == 0:
			BuildKit.cylinder(root, 0.025, 0.14, Vector3(x, y + h - 0.05, z), PlaceDetail.col(Color(0.3, 0.2, 0.12), 1.0), false, Vector3.ZERO, -1.0, 6)
	# Auto: Scheinwerfer, Stoßstangen, Rückleuchten, Kennzeichen, offene Fahrertür
	var chrome := PlaceDetail.col(Color(0.6, 0.62, 0.64), 0.3, 0.8)
	for sx: float in [-0.65, 0.65]:
		BuildKit.box(car, Vector3(0.35, 0.15, 0.03), Vector3(sx, 0.6, 2.16), PlaceDetail.col(Color(0.85, 0.85, 0.8), 0.2), false)
		BuildKit.box(car, Vector3(0.3, 0.12, 0.03), Vector3(sx, 0.62, -2.16), PlaceDetail.col(Color(0.6, 0.05, 0.05), 0.3), false)
	for sz: float in [2.17, -2.17]:
		BuildKit.box(car, Vector3(1.85, 0.12, 0.08), Vector3(0, 0.25, sz), chrome, false)
	PlaceDetail.sign(car, "PA-RZ 404", Vector3(0, 0.38, 2.22), Vector2(0.52, 0.11), 0.0, Color(0.95, 0.95, 0.92), Color(0.05, 0.05, 0.05), 40)
	var door := Node3D.new()
	door.position = Vector3(0.9, 0.45, 0.6)
	door.rotation_degrees.y = 55.0
	car.add_child(door)
	BuildKit.box(door, Vector3(0.05, 0.65, 1.1), Vector3(0, 0, -0.55), BuildKit.tex_mat("car_paint", 1.0, Color(0.35, 0.4, 0.5)), false)
	BuildKit.box(door, Vector3(0.03, 0.4, 0.9), Vector3(0, 0.55, -0.5), PlaceKit.mat("glass"), false)
	BuildKit.box(car, Vector3(1.4, 0.4, 0.5), Vector3(0, 0.75, -0.6), PlaceDetail.col(Color(0.15, 0.13, 0.12), 0.9), false)
	BuildKit.box(car, Vector3(1.4, 0.4, 0.5), Vector3(0, 0.75, 0.4), PlaceDetail.col(Color(0.15, 0.13, 0.12), 0.9), false)
	BuildKit.cylinder(car, 0.18, 0.04, Vector3(0.4, 1.0, 0.75), PlaceDetail.col(Color(0.08, 0.08, 0.08)), false, Vector3(60, 0, 0), -1.0, 12)
	PlaceDetail.litter(root, Vector3(0, 0, 5.0), 7.0, 909, 50, ["leaf", "twig", "stone"], func(x: float, z: float) -> float: return PlaceKit.ground(root, x, z) + 0.02)


## Lebendige Orte: Bagger mit Ketten, Schaufelzähnen, Sitz und Hydraulik; gesägte Granitblöcke mit Bohrlöchern,
## Schotterkegel, Dixi-Klo, Warnschilder, Kabeltrommel; Büro mit Helmen, Schichtplan, Kaffeemaschine.
static func _steinbruch_details(root: Node3D, dig: Node3D, office: Node3D) -> void:
	var dark := PlaceKit.mat("dark")
	for sx: float in [-1.0, 1.0]:
		BuildKit.box(dig, Vector3(0.65, 0.75, 3.9), Vector3(sx * 1.05, 0.38, 0), PlaceDetail.col(Color(0.12, 0.12, 0.12), 0.7, 0.4), false)
		for k in 13:
			BuildKit.box(dig, Vector3(0.67, 0.05, 0.08), Vector3(sx * 1.05, 0.76, -1.8 + k * 0.3), dark, false)
	for k in 5:
		BuildKit.box(dig, Vector3(0.1, 0.18, 0.12), Vector3(0.1 + k * 0.2, 0.2, 6.6), PlaceKit.mat("steel_dark"), false, Vector3(30, 0, 0))
	BuildKit.box(dig, Vector3(0.5, 0.15, 0.5), Vector3(-0.6, 2.25, 0.4), PlaceDetail.col(Color(0.15, 0.15, 0.15), 0.8), false)
	BuildKit.box(dig, Vector3(0.5, 0.5, 0.1), Vector3(-0.6, 2.5, 0.15), PlaceDetail.col(Color(0.15, 0.15, 0.15), 0.8), false)
	BuildKit.cylinder(dig, 0.08, 2.0, Vector3(0.75, 3.1, 1.9), PlaceKit.mat("metal"), false, Vector3(-60, 0, 0), -1.0, 8)
	BuildKit.cylinder(dig, 0.06, 0.6, Vector3(-0.9, 2.3, -1.4), PlaceKit.mat("rust"), false, Vector3.ZERO, -1.0, 8)
	# Granitblöcke (gesägt, Bohrlochreihen), Schotterkegel
	var granite := PlaceKit.mat("stone")
	var rng := RandomNumberGenerator.new()
	rng.seed = 3131
	for k in 9:
		var p := PlaceKit.on_ground(root, -10.0 + (k % 3) * 2.4, 6.0 + (k / 3) * 1.8)
		var sz := Vector3(rng.randf_range(1.6, 2.2), rng.randf_range(0.9, 1.3), rng.randf_range(1.0, 1.4))
		var b := BuildKit.box(root, sz, p + Vector3(0, sz.y * 0.5, 0), granite, true, Vector3(0, rng.randf_range(-8, 8), 0))
		for d in 5:
			BuildKit.cylinder(b, 0.025, sz.y + 0.01, Vector3(-sz.x * 0.4 + d * sz.x * 0.2, 0, sz.z * 0.5 - 0.02), PlaceDetail.col(Color(0.25, 0.25, 0.25)), false, Vector3.ZERO, -1.0, 6)
		if k % 3 == 0:
			var top := BuildKit.box(root, sz * 0.8, p + Vector3(0, sz.y + sz.y * 0.4, 0), granite, true, Vector3(0, rng.randf_range(-15, 15), 0))
			top.name = "Block_%d" % k
	for k in 3:
		var cp := PlaceKit.on_ground(root, 14.0 + k * 5.0, -8.0 - k * 3.0)
		BuildKit.lathe(root, PackedVector2Array([Vector2(0, 0), Vector2(3.2 - k * 0.6, 0), Vector2(0.3, 2.0 - k * 0.3), Vector2(0, 2.05 - k * 0.3)]), cp, PlaceKit.mat("gravel"), 14)
		BuildKit.collider_box(root, Vector3(3.0, 1.5, 3.0), cp + Vector3(0, 0.75, 0))
	# Dixi-Klo neben dem Büro
	var dp := PlaceKit.on_ground(root, 26.0, -33.0)
	var dixi := Node3D.new()
	dixi.position = dp
	dixi.rotation_degrees.y = 230.0
	root.add_child(dixi)
	BuildKit.box(dixi, Vector3(1.1, 2.2, 1.1), Vector3(0, 1.1, 0), PlaceDetail.col(Color(0.15, 0.35, 0.7), 0.5), true)
	BuildKit.box(dixi, Vector3(1.15, 0.12, 1.15), Vector3(0, 2.25, 0), PlaceDetail.col(Color(0.9, 0.9, 0.88), 0.5), false)
	BuildKit.box(dixi, Vector3(0.8, 1.9, 0.02), Vector3(0, 1.0, 0.56), PlaceDetail.col(Color(0.12, 0.3, 0.6), 0.5), false)
	BuildKit.box(dixi, Vector3(0.12, 0.05, 0.02), Vector3(0.25, 1.1, 0.575), PlaceDetail.col(Color(0.8, 0.1, 0.1)), false)
	# Warnschilder, Kabeltrommel, Fässer
	PlaceDetail.sign(root, "STEINBRUCH\nBetreten verboten!\nSteinschlag – Sprengarbeiten", PlaceKit.on_ground(root, 22.0, -30.0, 1.3), Vector2(0.7, 0.45), 230.0, Color(0.95, 0.8, 0.1), Color(0.05, 0.05, 0.05), 28)
	BuildKit.box(root, Vector3(0.08, 1.2, 0.08), PlaceKit.on_ground(root, 22.0, -30.0, 0.6), PlaceKit.mat("metal"), true)
	PlaceDetail.barrel(root, PlaceKit.on_ground(root, 4.0, 9.0), "rust")
	PlaceDetail.barrel(root, PlaceKit.on_ground(root, 4.8, 9.6), "rust", true, 80.0)
	var dr := PlaceKit.on_ground(root, 9.0, 9.5)
	for sx: float in [-1.0, 1.0]:
		BuildKit.cylinder(root, 0.55, 0.05, dr + Vector3(sx * 0.3, 0.55, 0), PlaceKit.mat("wood_old"), false, Vector3(0, 0, 90), -1.0, 14)
	BuildKit.cylinder(root, 0.38, 0.56, dr + Vector3(0, 0.55, 0), PlaceDetail.col(Color(0.1, 0.1, 0.1), 0.6), true, Vector3(0, 0, 90), -1.0, 14)
	# Büro: Helme am Haken, Schichtplan, Kaffeemaschine, Stuhl
	for k in 3:
		BuildKit.sphere(office, 0.14, Vector3(1.6 - k * 0.35, 1.6, 1.05), PlaceDetail.col([Color(0.95, 0.8, 0.1), Color(0.95, 0.95, 0.92), Color(0.9, 0.45, 0.1)][k], 0.5), Vector3(1.0, 0.75, 1.1), 10)
	PlaceDetail.sign(office, "SCHICHTPLAN KW 46\nMo–Fr 6:00\nSprengung Do 11:00\n— Bereich Ost GESPERRT —", Vector3(0.6, 1.5, -1.15), Vector2(0.6, 0.45), 0.0, Color(0.95, 0.95, 0.93), Color(0.1, 0.1, 0.2), 22)
	BuildKit.box(office, Vector3(0.22, 0.3, 0.24), Vector3(-1.9, 0.95, -0.85), PlaceDetail.col(Color(0.1, 0.1, 0.1), 0.4), false)
	PlaceDetail.chair(office, Vector3(-1.2, 0.06, -0.1), 180.0, "furn")
	PlaceDetail.clutter(office, Vector3(-1.2, 0.8, -0.6), Vector2(1.2, 0.3), 31, 2, ["papers", "binders"])
	PlaceDetail.litter(root, Vector3(0, 0, 0), 20.0, 3132, 80, ["stone", "stone", "leaf", "twig"], func(x: float, z: float) -> float: return PlaceKit.ground(root, x, z) + 0.03)


## Lebendige Orte: Polizeiwagen mit Blaulicht und offener Tür, Leitkegel, Nagelband, Warndreieck, Schild „Halt Polizei“,
## Feldbetten, Funktisch mit Lampe und Karte, Kanister, Kisten, Absperrband, liegengelassener Helm, Lampenmast.
static func _kontrollpunkt_details(root: Node3D) -> void:
	var orange := PlaceDetail.col(Color(0.95, 0.4, 0.08), 0.6)
	var white := PlaceDetail.col(Color(0.95, 0.95, 0.92), 0.6)
	for k in 8:
		var cp := PlaceKit.on_ground(root, -3.0 + (k % 4) * 1.6, -2.0 if k < 4 else 2.2)
		var cone := Node3D.new()
		cone.position = cp
		if k == 5:
			cone.rotation_degrees.z = 88.0
			cone.position.y += 0.12
		root.add_child(cone)
		BuildKit.box(cone, Vector3(0.36, 0.03, 0.36), Vector3(0, 0.015, 0), PlaceDetail.col(Color(0.1, 0.1, 0.1)), false)
		BuildKit.lathe(cone, PackedVector2Array([Vector2(0, 0.03), Vector2(0.15, 0.03), Vector2(0.03, 0.7), Vector2(0, 0.7)]), Vector3.ZERO, orange, 10)
		BuildKit.cylinder(cone, 0.095, 0.08, Vector3(0, 0.35, 0), white, false, Vector3.ZERO, 0.075, 10)
	# Nagelband über die Fahrbahn
	var sp := PlaceKit.on_ground(root, 2.5, 0.0, 0.02)
	BuildKit.box(root, Vector3(0.12, 0.03, 6.0), sp, PlaceDetail.col(Color(0.1, 0.1, 0.1), 0.6), false, Vector3(0, 10, 0))
	for k in 20:
		BuildKit.box(root, Vector3(0.015, 0.06, 0.015), sp + Vector3(0.0, 0.03, -2.85 + k * 0.3).rotated(Vector3.UP, deg_to_rad(10.0)), PlaceKit.mat("metal"), false)
	# Schild auf Ständer
	var hp := PlaceKit.on_ground(root, -5.0, -5.0)
	BuildKit.box(root, Vector3(0.05, 1.6, 0.05), hp + Vector3(0, 0.8, 0), PlaceKit.mat("metal"), true)
	PlaceDetail.sign(root, "HALT\nPOLIZEI\nGrenzkontrolle", hp + Vector3(0, 1.45, 0.04), Vector2(0.6, 0.6), 0.0, Color(0.9, 0.9, 0.88), Color(0.1, 0.35, 0.15), 40)
	var tri := PlaceKit.on_ground(root, 6.0, -1.0, 0.0)
	for k in 3:
		var a := k * 120.0
		BuildKit.box(root, Vector3(0.5, 0.06, 0.03), tri + Vector3(0, 0.25, 0) + Vector3(0, 0.15, 0).rotated(Vector3.FORWARD, deg_to_rad(a + 90.0)), PlaceDetail.col(Color(0.85, 0.1, 0.08), 0.4), false, Vector3(0, 0, a))
	# Polizeiwagen (verlassen, Tür offen, Blaulicht aus)
	var car := Node3D.new()
	car.name = "PoliceCar"
	car.position = PlaceKit.on_ground(root, 4.0, 6.5, 0.3)
	car.rotation_degrees.y = 100.0
	root.add_child(car)
	var paint := PlaceDetail.col(Color(0.9, 0.9, 0.88), 0.4, 0.2)
	var green := PlaceDetail.col(Color(0.1, 0.35, 0.6), 0.4, 0.2)
	BuildKit.box(car, Vector3(1.8, 0.7, 4.6), Vector3(0, 0.45, 0), paint, true)
	BuildKit.box(car, Vector3(1.6, 0.55, 2.4), Vector3(0, 1.08, -0.2), paint, false)
	BuildKit.box(car, Vector3(1.82, 0.18, 4.62), Vector3(0, 0.5, 0), green, false)
	BuildKit.box(car, Vector3(1.55, 0.45, 0.04), Vector3(0, 1.1, 1.0), PlaceKit.mat("glass"), false, Vector3(-30, 0, 0))
	BuildKit.box(car, Vector3(1.0, 0.1, 0.25), Vector3(0, 1.42, -0.2), PlaceDetail.col(Color(0.15, 0.2, 0.8), 0.3), false)
	PlaceDetail.sign(car, "POLIZEI", Vector3(0.92, 0.72, 0.6), Vector2(0.9, 0.16), 90.0, Color(0.1, 0.35, 0.6), Color(0.95, 0.95, 0.95), 40, false)
	for sx: float in [-0.92, 0.92]:
		for sz: float in [-1.4, 1.4]:
			BuildKit.cylinder(car, 0.32, 0.22, Vector3(sx, 0.15, sz), PlaceKit.mat("dark"), false, Vector3(0, 0, 90), -1.0, 12)
	var door := Node3D.new()
	door.position = Vector3(0.9, 0.45, 0.7)
	door.rotation_degrees.y = 60.0
	car.add_child(door)
	BuildKit.box(door, Vector3(0.05, 0.65, 1.1), Vector3(0, 0, -0.55), paint, false)
	# Feldbetten und Funktisch in den Zelten, Kisten, Kanister
	for t in 2:
		var tent := root.get_node_or_null("Tent%d" % (t + 1)) as Node3D
		if tent == null:
			continue
		for b in 2:
			var cot := Node3D.new()
			cot.position = Vector3(-0.9 + b * 1.8, 0, 0.8 if t == 0 else -0.2)
			tent.add_child(cot)
			BuildKit.box(cot, Vector3(0.7, 0.04, 1.9), Vector3(0, 0.42, 0), PlaceKit.mat("olive"), false)
			for sz: float in [-0.85, 0.85]:
				BuildKit.box(cot, Vector3(0.75, 0.42, 0.04), Vector3(0, 0.21, sz), PlaceKit.mat("metal"), false)
			BuildKit.box(cot, Vector3(0.6, 0.08, 0.5), Vector3(0, 0.48, -0.6), PlaceKit.mat("cloth"), false)
		PlaceDetail.lamp(tent, Vector3(0, 1.9, 0), "hanging", false)
		PlaceDetail.crate(tent, Vector3(1.3, 0, -2.0), Vector3(0.6, 0.4, 0.4), 10.0)
	var t1 := root.get_node_or_null("Tent1") as Node3D
	if t1:
		PlaceDetail.sign(t1, "LAGEKARTE\nB12 · Mauth · Finsterau\nSperrkreis MP4 (rot)", Vector3(0, 1.3, -2.44), Vector2(0.9, 0.6), 0.0, Color(0.88, 0.9, 0.82), Color(0.15, 0.25, 0.15), 26)
		BuildKit.cylinder(t1, 0.2, 0.004, Vector3(0.2, 1.25, -2.43), PlaceKit.mat("red"), false, Vector3(90, 0, 0), -1.0, 16)
	for k in 4:
		var jp := PlaceKit.on_ground(root, 9.0 + k * 0.45, -8.0)
		BuildKit.box(root, Vector3(0.18, 0.46, 0.34), jp + Vector3(0, 0.23, 0), PlaceKit.mat("olive"), false)
		BuildKit.box(root, Vector3(0.06, 0.06, 0.1), jp + Vector3(0, 0.49, 0.1), PlaceKit.mat("olive"), false)
	# Absperrband zwischen den Sandsäcken, liegengelassener Helm, Lampenmast
	for k in 2:
		var a := PlaceKit.on_ground(root, -7.0 + k * 14.0, -3.5, 0.9)
		var b := PlaceKit.on_ground(root, -7.0 + k * 14.0, 3.5, 0.9)
		var a2 := PlaceKit.on_ground(root, -7.0 + k * 14.0, -3.5, 0.9)
		PlaceDetail.cable(root, a, a2 + Vector3(0, 0, -3.0), 0.1, 0.012, Color(0.9, 0.1, 0.08))
		PlaceDetail.cable(root, b, b + Vector3(0, 0, 3.0), 0.1, 0.012, Color(0.95, 0.95, 0.95))
	BuildKit.sphere(root, 0.15, PlaceKit.on_ground(root, 1.0, 4.0, 0.08), PlaceKit.mat("olive"), Vector3(1.0, 0.7, 1.15), 10)
	var lp := PlaceKit.on_ground(root, -6.0, 6.0)
	BuildKit.cylinder(root, 0.06, 4.0, lp + Vector3(0, 2.0, 0), PlaceKit.mat("metal"), true, Vector3.ZERO, 0.05, 8)
	PlaceDetail.lamp(root, lp + Vector3(0, 3.9, 0), "flood", false, 120.0)
	BuildKit.box(root, Vector3(0.6, 0.5, 0.4), lp + Vector3(0.6, 0.25, 0), PlaceDetail.col(Color(0.3, 0.38, 0.3), 0.6), true)
	PlaceDetail.cable(root, lp + Vector3(0.35, 0.3, 0), lp + Vector3(0.04, 0.5, 0), 0.05, 0.015)
	PlaceDetail.litter(root, Vector3(0, 0, 0), 12.0, 4545, 60, ["leaf", "leaf", "paper", "twig"], func(x: float, z: float) -> float: return PlaceKit.ground(root, x, z) + 0.02)


## Lebendige Orte: Speisehütte mit Tischdecken, Geschirr, Küchenzeile, Pinnwand mit Kinderbildern; Lagerfeuerkreis mit
## Baumstamm-Bänken, Schaukel, Volleyballnetz, Plumpsklo, Waschrinne, Wegweiserpfahl, vergessene Rucksäcke.
static func _ferienlager_details(root: Node3D, canteen: Node3D) -> void:
	var wood := PlaceKit.mat("wood_old")
	# Speisehütte innen
	for k in 2:
		BuildKit.box(canteen, Vector3(3.05, 0.01, 0.95), Vector3(-1.8 + k * 3.6, 0.78, 0.0), PlaceDetail.col(Color(0.75, 0.2, 0.18), 0.9), false)
		for sz: float in [-0.75, 0.75]:
			BuildKit.box(canteen, Vector3(3.0, 0.05, 0.3), Vector3(-1.8 + k * 3.6, 0.45, sz), PlaceKit.mat("furn"), true)
		for d in 4:
			BuildKit.cylinder(canteen, 0.11, 0.015, Vector3(-3.0 + k * 3.6 + d * 0.8, 0.79, 0.25 - (d % 2) * 0.5), PlaceDetail.col(Color(0.95, 0.95, 0.92), 0.3), false, Vector3.ZERO, -1.0, 12)
			BuildKit.lathe(canteen, PackedVector2Array([Vector2(0, 0), Vector2(0.035, 0), Vector2(0.04, 0.09), Vector2(0.036, 0.09), Vector2(0.032, 0.01), Vector2(0, 0.01)]), Vector3(-2.8 + k * 3.6 + d * 0.8, 0.79, 0.35 - (d % 2) * 0.7), PlaceDetail.col(Color(0.3, 0.5, 0.75), 0.3), 10)
	BuildKit.box(canteen, Vector3(2.0, 0.9, 0.6), Vector3(2.6, 0.45, -2.1), PlaceKit.mat("cabinet"), true)
	BuildKit.box(canteen, Vector3(0.5, 0.15, 0.4), Vector3(2.2, 0.95, -2.1), PlaceKit.mat("metal"), false)
	PlaceDetail.clutter(canteen, Vector3(3.0, 0.9, -2.1), Vector2(0.8, 0.4), 919, 3, ["cans", "jars"])
	var board := PlaceDetail.sign(canteen, "WOCHENPLAN\nMo Schnitzeljagd · Di Bach · Mi Wanderung Lusen\nDo Lagerfeuer · Fr Abschlussfest", Vector3(-1.0, 1.6, -2.42), Vector2(1.4, 0.7), 0.0, Color(0.62, 0.45, 0.28), Color(0.1, 0.08, 0.05), 24)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2468
	for k in 6:
		var c := Color.from_hsv(rng.randf(), 0.4, 0.95)
		BuildKit.box(board, Vector3(0.2, 0.15, 0.004), Vector3(-0.55 + k * 0.22, -0.22 + (k % 2) * 0.06, 0.012), PlaceDetail.col(c, 0.9), false, Vector3(0, 0, rng.randf_range(-10, 10)))
	PlaceDetail.lamp(canteen, Vector3(-1.8, 2.3, 0), "hanging", false)
	PlaceDetail.lamp(canteen, Vector3(1.8, 2.3, 0), "hanging", false)
	# Lagerfeuerkreis mit Stammbänken
	var fp := PlaceKit.on_ground(root, -6.0, 8.0)
	for k in 10:
		var a := TAU * k / 10.0
		BuildKit.sphere(root, 0.16, fp + Vector3(cos(a) * 0.7, 0.06, sin(a) * 0.7), PlaceKit.mat("stone"), Vector3(1.2, 0.7, 1.0), 7)
	for k in 5:
		BuildKit.cylinder(root, 0.05, 0.6, fp + Vector3(cos(k * 1.3) * 0.2, 0.08, sin(k * 1.3) * 0.2), PlaceDetail.col(Color(0.07, 0.06, 0.05), 1.0), false, Vector3(80, k * 70.0, 0), 0.035, 6)
	for k in 4:
		var a := TAU * k / 4.0 + 0.4
		var lp := fp + Vector3(cos(a) * 2.4, 0, sin(a) * 2.4)
		lp.y = PlaceKit.ground(root, lp.x, lp.z)
		BuildKit.cylinder(root, 0.2, 1.8, lp + Vector3(0, 0.2, 0), PlaceKit.mat("bark"), true, Vector3(0, -rad_to_deg(a), 90), -1.0, 10)
	# Schaukel, Volleyballnetz, Plumpsklo, Waschrinne
	var sw := PlaceKit.on_ground(root, 7.0, 6.0)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			BuildKit.beam_between(root, sw + Vector3(sx * 1.2, 0, sz * 0.6), sw + Vector3(sx * 1.0, 2.4, 0), 0.06, wood)
	BuildKit.cylinder(root, 0.06, 2.2, sw + Vector3(0, 2.42, 0), wood, false, Vector3(0, 0, 90), -1.0, 8)
	for sx: float in [-0.3, 0.3]:
		PlaceDetail.cable(root, sw + Vector3(sx, 2.4, 0), sw + Vector3(sx, 0.55, 0.0), 0.0, 0.01, Color(0.6, 0.5, 0.35))
	BuildKit.box(root, Vector3(0.7, 0.04, 0.22), sw + Vector3(0, 0.55, 0), wood, false)
	var vp := PlaceKit.on_ground(root, 10.0, -4.0)
	for sx: float in [-1.0, 1.0]:
		BuildKit.cylinder(root, 0.04, 2.5, vp + Vector3(sx * 4.0, 1.25, 0), PlaceKit.mat("metal"), true, Vector3.ZERO, -1.0, 6)
	var net := BuildKit.color_mat(Color(0.15, 0.15, 0.15, 0.55), 1.0)
	net.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	net.cull_mode = BaseMaterial3D.CULL_DISABLED
	BuildKit.box(root, Vector3(8.0, 0.8, 0.01), vp + Vector3(0, 2.0, 0), net, false, Vector3(0, 0, 3))
	BuildKit.sphere(root, 0.11, PlaceKit.on_ground(root, 11.5, -2.5, 0.11), PlaceDetail.col(Color(0.95, 0.95, 0.9), 0.6), Vector3.ONE, 10)
	var op := PlaceKit.on_ground(root, -12.0, -10.0)
	var out := Node3D.new()
	out.position = op
	out.rotation_degrees.y = 60.0
	root.add_child(out)
	BuildKit.box(out, Vector3(1.2, 2.1, 1.2), Vector3(0, 1.05, 0), PlaceKit.mat("wood"), true)
	BuildKit.box(out, Vector3(1.4, 0.06, 1.5), Vector3(0, 2.15, 0), PlaceKit.mat("shingles"), false, Vector3(-12, 0, 0))
	BuildKit.box(out, Vector3(0.12, 0.2, 0.02), Vector3(0, 1.75, 0.61), PlaceDetail.col(Color(0.05, 0.05, 0.05)), false, Vector3(0, 0, 45))
	var wt := PlaceKit.on_ground(root, -4.0, -2.0)
	BuildKit.box(root, Vector3(3.0, 0.3, 0.5), wt + Vector3(0, 0.8, 0), PlaceKit.mat("metal"), true)
	for k in 4:
		BuildKit.cylinder(root, 0.015, 0.25, wt + Vector3(-1.2 + k * 0.8, 1.05, -0.2), PlaceKit.mat("metal"), false, Vector3(-30, 0, 0), -1.0, 6)
	for sx: float in [-1.4, 1.4]:
		BuildKit.box(root, Vector3(0.1, 0.8, 0.1), wt + Vector3(sx, 0.4, 0), PlaceKit.mat("metal"), false)
	# Wegweiserpfahl im Lager, vergessene Rucksäcke
	var gp := PlaceKit.on_ground(root, 3.0, 2.0)
	BuildKit.box(root, Vector3(0.1, 2.4, 0.1), gp + Vector3(0, 1.2, 0), wood, true)
	var dirs := [["Speisehütte", 0.0], ["Lagerfeuer", 140.0], ["Klo", 210.0], ["Bach", 300.0]]
	for k in dirs.size():
		var sg := PlaceDetail.sign(root, String(dirs[k][0]), gp + Vector3(0, 2.1 - k * 0.25, 0), Vector2(0.6, 0.14), float(dirs[k][1]), Color(0.9, 0.8, 0.55), Color(0.2, 0.12, 0.05), 28, false)
		sg.position += Vector3(0.3, 0, 0).rotated(Vector3.UP, deg_to_rad(float(dirs[k][1])))
	for k in 2:
		var bp := PlaceKit.on_ground(root, -2.0 + k * 1.2, 5.0, 0.2)
		BuildKit.box(root, Vector3(0.35, 0.45, 0.22), bp, PlaceDetail.col([Color(0.8, 0.2, 0.2), Color(0.2, 0.4, 0.75)][k], 0.8), false, Vector3(-70 + k * 20, k * 40.0, 0))
	PlaceDetail.litter(root, Vector3(0, 0, 0), 14.0, 1357, 90, ["leaf", "leaf", "twig", "paper"], func(x: float, z: float) -> float: return PlaceKit.ground(root, x, z) + 0.02)


## Lebendige Orte: Schäferkarren mit Treppe, Tür, Ofenrohr, Fensterläden, Innenleben (Pritsche, Ofen, Kessel);
## Zaunlatten im Pferch, Heuballen, Tränke, Hundehütte mit leerer Kette, Hirtenstab, Wäscheleine.
static func _schaefer_details(root: Node3D, wagon: Node3D) -> void:
	var wood := PlaceKit.mat("wood_old")
	for k in 3:
		BuildKit.box(wagon, Vector3(0.8, 0.05, 0.3), Vector3(-0.5, -0.5 + k * 0.25, 2.45 - k * 0.12), wood, true)
	BuildKit.box(wagon, Vector3(0.75, 1.75, 0.05), Vector3(-0.5, 0.9, 2.13), PlaceKit.mat("wood_h"), false)
	BuildKit.cylinder(wagon, 0.025, 0.1, Vector3(-0.2, 1.0, 2.18), PlaceKit.mat("metal"), false, Vector3(90, 0, 0), -1.0, 6)
	for sx: float in [-1.0, 1.0]:
		BuildKit.box(wagon, Vector3(0.05, 0.6, 0.6), Vector3(sx * 1.13, 1.3, -0.6), PlaceKit.mat("glass"), false)
		BuildKit.box(wagon, Vector3(0.04, 0.62, 0.3), Vector3(sx * 1.15, 1.3, -1.06), PlaceDetail.col(Color(0.2, 0.35, 0.22), 0.8), false, Vector3(0, sx * 30.0, 0))
	BuildKit.cylinder(wagon, 0.07, 1.0, Vector3(0.6, 3.0, -1.2), PlaceKit.mat("rust"), false, Vector3.ZERO, -1.0, 8)
	BuildKit.cylinder(wagon, 0.12, 0.1, Vector3(0.6, 3.5, -1.2), PlaceKit.mat("rust"), false, Vector3.ZERO, -1.0, 8)
	BuildKit.box(wagon, Vector3(2.3, 0.08, 0.5), Vector3(0, 0.1, 2.3), wood, false)
	# Deichsel
	BuildKit.beam_between(wagon, Vector3(0, -0.3, -2.1), Vector3(0, -0.6, -3.6), 0.07, wood)
	# Heuballen, Tränke, Hundehütte, Hirtenstab, Wäscheleine
	for k in 4:
		var hp := PlaceKit.on_ground(root, 5.0 + (k % 2) * 1.4, -16.0 - (k / 2) * 1.0, 0.6)
		BuildKit.cylinder(root, 0.6, 1.2, hp, PlaceDetail.col(Color(0.52, 0.45, 0.26), 1.0), true, Vector3(0, k * 25.0, 90), -1.0, 14)
	var tr := PlaceKit.on_ground(root, 3.0, -20.0)
	BuildKit.box(root, Vector3(2.0, 0.4, 0.6), tr + Vector3(0, 0.2, 0), PlaceKit.mat("metal"), true)
	BuildKit.box(root, Vector3(1.9, 0.02, 0.5), tr + Vector3(0, 0.36, 0), BuildKit.color_mat(Color(0.08, 0.1, 0.1), 0.05, 0.2), false)
	var dh := PlaceKit.on_ground(root, -3.5, -13.0)
	var dog := Node3D.new()
	dog.position = dh
	dog.rotation_degrees.y = 20.0
	root.add_child(dog)
	BuildKit.box(dog, Vector3(0.9, 0.7, 1.1), Vector3(0, 0.35, 0), PlaceKit.mat("wood"), true)
	for sx: float in [-1.0, 1.0]:
		BuildKit.box(dog, Vector3(0.6, 0.04, 1.25), Vector3(sx * 0.25, 0.85, 0), PlaceKit.mat("shingles"), false, Vector3(0, 0, -sx * 35.0))
	BuildKit.box(dog, Vector3(0.4, 0.45, 0.02), Vector3(0, 0.26, 0.56), PlaceDetail.col(Color(0.03, 0.03, 0.03)), false)
	for k in 10:
		BuildKit.cylinder(root, 0.01, 0.05, dh + Vector3(0.1 + k * 0.08, 0.02, 0.7 + sin(k) * 0.05), PlaceKit.mat("metal"), false, Vector3(90, k * 45.0, 0), -1.0, 5)
	BuildKit.cylinder(root, 0.06, 0.03, dh + Vector3(0.95, 0.03, 0.75), PlaceKit.mat("metal"), false, Vector3.ZERO, 0.05, 10)
	var cr := PlaceKit.on_ground(root, 1.6, -11.5)
	HandKit.tube(root, PackedVector3Array([cr, cr + Vector3(0.05, 1.5, 0.3), cr + Vector3(0.05, 1.7, 0.42), cr + Vector3(0.05, 1.62, 0.55)]), 0.02, wood, 6)
	var lp1 := PlaceKit.on_ground(root, -2.0, -17.5)
	var lp2 := PlaceKit.on_ground(root, -6.0, -16.0)
	for lp: Vector3 in [lp1, lp2]:
		BuildKit.box(root, Vector3(0.08, 1.8, 0.08), lp + Vector3(0, 0.9, 0), wood, true)
	PlaceDetail.cable(root, lp1 + Vector3(0, 1.75, 0), lp2 + Vector3(0, 1.75, 0), 0.2, 0.006, Color(0.8, 0.8, 0.75))
	for k in 3:
		var t := 0.3 + k * 0.2
		var p := (lp1 + Vector3(0, 1.75, 0)).lerp(lp2 + Vector3(0, 1.75, 0), t) + Vector3(0, -0.2 * 4.0 * t * (1.0 - t) - 0.25, 0)
		BuildKit.box(root, Vector3(0.4, 0.5, 0.01), p, PlaceDetail.col([Color(0.4, 0.35, 0.5), Color(0.8, 0.78, 0.7), Color(0.3, 0.4, 0.3)][k], 0.9), false, Vector3(0, rad_to_deg(atan2(lp2.z - lp1.z, lp2.x - lp1.x)) * -1.0, 0))
	# Zaunlatten am Pferch
	for k in 10:
		var a := TAU * k / 10.0
		var b := TAU * (k + 1) / 10.0
		var pa := PlaceKit.on_ground(root, cos(a) * 13.0 + 3.0, sin(a) * 6.0 - 22.0, 0.8)
		var pb := PlaceKit.on_ground(root, cos(b) * 13.0 + 3.0, sin(b) * 6.0 - 22.0, 0.8)
		if k == 3:
			continue
		BuildKit.beam_between(root, pa, pb, 0.05, wood)
		BuildKit.beam_between(root, pa - Vector3(0, 0.4, 0), pb - Vector3(0, 0.4, 0), 0.05, wood)
	PlaceDetail.litter(root, Vector3(0, 0, -14.0), 8.0, 2121, 50, ["leaf", "twig"], func(x: float, z: float) -> float: return PlaceKit.ground(root, x, z) + 0.02)


## Lebendige Orte: Torfziegel zum Trocknen, Spaten im Stich, Schubkarre; Unterstand mit Bank und Tafel „Moorschichten“;
## Moorleiche mit Anorak, Rucksack, Taschenlampe und einem Stiefel im Schlamm; Birkenstangen, Wollgras.
static func _moor_details(root: Node3D, tp: Vector3, corpse: Node3D) -> void:
	var peat := PlaceDetail.col(Color(0.18, 0.12, 0.07), 1.0)
	for row in 3:
		for k in 8:
			BuildKit.box(root, Vector3(0.28, 0.12, 0.12), tp + Vector3(-1.5 + k * 0.32, 0.06 + row * 0.12, 1.2 + (row % 2) * 0.06), peat, false, Vector3(0, (k * 13) % 7 - 3.0, 0))
	var sp := tp + Vector3(1.0, 0.0, -0.4)
	BuildKit.box(root, Vector3(0.2, 0.3, 0.02), sp + Vector3(0, 0.05, 0), PlaceKit.mat("metal"), false, Vector3(-15, 0, 0))
	BuildKit.cylinder(root, 0.02, 1.0, sp + Vector3(0, 0.65, -0.12), PlaceKit.mat("wood_old"), false, Vector3(-15, 0, 0), -1.0, 6)
	BuildKit.box(root, Vector3(0.14, 0.03, 0.03), sp + Vector3(0, 1.15, -0.25), PlaceKit.mat("wood_old"), false)
	# Unterstand mit Bank und Tafel am Steg
	var us := PlaceKit.on_ground(root, 24.5, 80.0)
	var shelter := Node3D.new()
	shelter.name = "Shelter"
	shelter.position = us
	shelter.rotation_degrees.y = 15.0
	root.add_child(shelter)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			BuildKit.box(shelter, Vector3(0.12, 2.2 if sz < 0.0 else 2.6, 0.12), Vector3(sx * 1.2, 1.1 if sz < 0.0 else 1.3, sz * 0.7), PlaceKit.mat("wood_old"), true)
	BuildKit.box(shelter, Vector3(2.8, 0.08, 1.9), Vector3(0, 2.5, 0), PlaceKit.mat("shingles"), false, Vector3(-12, 0, 0))
	BuildKit.box(shelter, Vector3(2.5, 1.2, 0.04), Vector3(0, 1.6, -0.72), PlaceKit.mat("wood"), true)
	PlaceDetail.pew(shelter, Vector3(0, 0, -0.35), 2.0, "wood_old")
	PlaceDetail.sign(shelter, "MOORSCHICHTEN\nTorf wächst 1 mm im Jahr.\nDieser Filz ist 9000 Jahre alt.\nWas hier versinkt, bleibt.", Vector3(0, 1.75, -0.69), Vector2(1.6, 0.8), 0.0, Color(0.85, 0.8, 0.65), Color(0.15, 0.1, 0.05), 28)
	for k in 5:
		BuildKit.box(shelter, Vector3(1.4, 0.1, 0.01), Vector3(0, 1.45 - k * 0.1, -0.68), PlaceDetail.col(Color(0.15 + k * 0.08, 0.1 + k * 0.05, 0.05), 1.0), false)
	# Moorleiche: Anorak, Rucksack, Lampe, Stiefel
	BuildKit.box(corpse, Vector3(0.5, 0.18, 0.6), Vector3(0, 0.1, 0.0), PlaceDetail.col(Color(0.15, 0.25, 0.32), 0.9), false)
	BuildKit.box(corpse, Vector3(0.4, 0.3, 0.25), Vector3(0.45, 0.08, 0.3), PlaceDetail.col(Color(0.5, 0.3, 0.12), 0.9), false, Vector3(0, 30, 70))
	BuildKit.cylinder(corpse, 0.025, 0.18, Vector3(-0.5, 0.03, -0.3), PlaceDetail.col(Color(0.1, 0.1, 0.1), 0.5), false, Vector3(0, 40, 90), -1.0, 8)
	BuildKit.box(corpse, Vector3(0.12, 0.3, 0.28), Vector3(0.1, 0.05, 1.5), PlaceDetail.col(Color(0.1, 0.25, 0.12), 0.5), false, Vector3(20, 0, 10))
	# Birkenstangen und Wollgras um den Torfstich
	var rng := RandomNumberGenerator.new()
	rng.seed = 818
	for k in 6:
		var p := tp + Vector3(rng.randf_range(-4, 4), 0, rng.randf_range(-3, 3))
		p.y = PlaceKit.ground(root, p.x, p.z)
		BuildKit.cylinder(root, 0.04, 2.5, p + Vector3(0, 0.3, 0), PlaceDetail.col(Color(0.7, 0.68, 0.62), 0.9), false, Vector3(80, rng.randf() * 360.0, 0), 0.03, 6)
	for k in 40:
		var p := tp + Vector3(rng.randf_range(-6, 6), 0, rng.randf_range(-5, 5))
		p.y = PlaceKit.ground(root, p.x, p.z)
		BuildKit.cylinder(root, 0.004, 0.35, p + Vector3(0, 0.17, 0), PlaceDetail.col(Color(0.5, 0.45, 0.25), 1.0), false, Vector3(rng.randf_range(-10, 10), 0, 0), 0.002, 3)
		BuildKit.sphere(root, 0.03, p + Vector3(0, 0.36, 0), PlaceDetail.col(Color(0.95, 0.95, 0.9), 1.0), Vector3(1, 1.3, 1), 5)


## Lebendige Orte: Wurzelteller mit herausragenden Wurzeln, Baumstümpfe mit gesplitterten Enden, Absperrband und Warnschild,
## verlassener Rückezug, Sondensplitter und verglaster Boden um den Krater, Rinde und Äste.
static func _windwurf_details(root: Node3D, rng: RandomNumberGenerator) -> void:
	var wood := PlaceKit.mat("bark")
	var root_mat := PlaceDetail.col(Color(0.3, 0.22, 0.14), 0.9)
	rng.seed = 778
	for i in 18:
		var a := rng.randf() * TAU
		var r := rng.randf_range(10.0, 30.0)
		var p := PlaceKit.on_ground(root, cos(a) * r, sin(a) * r)
		# Stumpf mit gesplittertem Ende
		var h := rng.randf_range(0.8, 2.6)
		BuildKit.cylinder(root, 0.3, h, p + Vector3(0, h * 0.5, 0), wood, true, Vector3.ZERO, 0.28, 8)
		for k in 5:
			var sa := k * 72.0 + rng.randf_range(-15, 15)
			var off := Vector3(0.18, 0, 0).rotated(Vector3.UP, deg_to_rad(sa))
			BuildKit.box(root, Vector3(0.1, rng.randf_range(0.3, 0.8), 0.08), p + off + Vector3(0, h + 0.2, 0), PlaceDetail.col(Color(0.75, 0.65, 0.48), 0.9), false, Vector3(rng.randf_range(-20, 20), sa, rng.randf_range(-20, 20)))
		# Wurzeln am Fuß
		for k in 5:
			var ra := k * 72.0 + 30.0
			var d := Vector3(cos(deg_to_rad(ra)), 0, sin(deg_to_rad(ra)))
			HandKit.tube(root, PackedVector3Array([p + Vector3(0, 0.2, 0), p + d * 0.5 + Vector3(0, 0.05, 0), p + d * 1.0 + Vector3(0, -0.05, 0)]), 0.07, root_mat, 6)
	# Absperrband und Warnschild am Rand
	for k in 4:
		var a1 := TAU * k / 8.0 + 2.0
		var a2 := TAU * (k + 1) / 8.0 + 2.0
		var p1 := PlaceKit.on_ground(root, cos(a1) * 66.0, sin(a1) * 66.0, 0.9)
		var p2 := PlaceKit.on_ground(root, cos(a2) * 66.0, sin(a2) * 66.0, 0.9)
		BuildKit.box(root, Vector3(0.06, 1.0, 0.06), p1 - Vector3(0, 0.45, 0), PlaceKit.mat("wood_old"), false)
		PlaceDetail.cable(root, p1, p2, 0.4, 0.012, Color(0.9, 0.1, 0.08) if k % 2 == 0 else Color(0.95, 0.95, 0.95))
	var wp := PlaceKit.on_ground(root, cos(2.0) * 66.0, sin(2.0) * 66.0)
	PlaceDetail.sign(root, "LEBENSGEFAHR\nTotholz – Betreten verboten\nNationalparkverwaltung", wp + Vector3(0, 1.4, 0), Vector2(0.7, 0.45), -rad_to_deg(2.0) - 90.0, Color(0.95, 0.85, 0.1), Color(0.05, 0.05, 0.05), 28)
	# Rückezug (Forstmaschine), verlassen, mit Kran
	var tr := Node3D.new()
	tr.name = "Skidder"
	tr.position = PlaceKit.on_ground(root, 30.0, 18.0, 0.6)
	tr.rotation_degrees.y = 40.0
	root.add_child(tr)
	var green := PlaceDetail.col(Color(0.25, 0.42, 0.15), 0.5, 0.3)
	BuildKit.box(tr, Vector3(2.2, 1.2, 2.6), Vector3(0, 0.8, -1.6), green, true)
	BuildKit.box(tr, Vector3(1.8, 1.4, 1.6), Vector3(0, 2.0, -1.8), PlaceKit.mat("glass"), false)
	BuildKit.box(tr, Vector3(2.4, 0.5, 4.0), Vector3(0, 0.7, 1.6), PlaceDetail.col(Color(0.2, 0.2, 0.2), 0.6, 0.4), true)
	for sz: float in [-2.2, -0.8, 0.8, 2.4]:
		for sx: float in [-1.15, 1.15]:
			BuildKit.cylinder(tr, 0.6, 0.5, Vector3(sx, 0.0, sz), PlaceKit.mat("dark"), false, Vector3(0, 0, 90), -1.0, 14)
	BuildKit.beam_between(tr, Vector3(0, 1.2, 0.0), Vector3(0.5, 3.4, 1.2), 0.12, PlaceKit.mat("yellow"))
	BuildKit.beam_between(tr, Vector3(0.5, 3.4, 1.2), Vector3(0.8, 2.0, 3.6), 0.1, PlaceKit.mat("yellow"))
	for k in 3:
		BuildKit.cylinder(tr, 0.22, 4.2, Vector3(-0.5 + k * 0.5, 1.2, 1.8), PlaceKit.mat("bark"), false, Vector3(90, 0, 0), 0.2, 8)
	# Sondensplitter, verglaster Boden im Krater
	var glass := BuildKit.color_mat(Color(0.12, 0.14, 0.12), 0.05, 0.6)
	for k in 10:
		var a := rng.randf() * TAU
		var r := rng.randf_range(0.5, 3.5)
		BuildKit.box(root, Vector3(rng.randf_range(0.2, 0.6), 0.01, rng.randf_range(0.2, 0.5)), PlaceKit.on_ground(root, cos(a) * r, sin(a) * r, 0.04), glass, false, Vector3(0, rng.randf() * 360.0, 0))
	for k in 7:
		var a := rng.randf() * TAU
		var r := rng.randf_range(2.0, 9.0)
		BuildKit.box(root, Vector3(0.12, 0.03, 0.25), PlaceKit.on_ground(root, cos(a) * r, sin(a) * r, 0.04), PlaceDetail.col(Color(0.5, 0.52, 0.5), 0.3, 0.8), false, Vector3(rng.randf_range(-30, 30), rng.randf() * 360.0, 0))
	PlaceDetail.litter(root, Vector3.ZERO, 30.0, 779, 160, ["twig", "twig", "leaf", "stone"], func(x: float, z: float) -> float: return PlaceKit.ground(root, x, z) + 0.02)


## Lebendige Orte: Planen-Lager mit Abspannseilen, Kocher, Topf, Laterne, Schlafsack, Kiste mit verpackten Spiegeln,
## Leiter an einem Stamm, Seile in die Bäume, Spiegelscherben am Boden, Stativ mit Kompass, Skizzen.
static func _spiegel_details(root: Node3D, c: Vector3, rng: RandomNumberGenerator) -> void:
	var rope := Color(0.6, 0.5, 0.32)
	for sx: float in [-1.0, 1.0]:
		PlaceDetail.cable(root, c + Vector3(sx * 1.5, 1.6, 1.3), c + Vector3(sx * 2.6, 0.02, 2.2), 0.05, 0.008, rope)
		PlaceDetail.cable(root, c + Vector3(sx * 1.5, 0.6, -1.3), c + Vector3(sx * 2.4, 0.02, -2.0), 0.03, 0.008, rope)
	var st := c + Vector3(0.9, 0.0, 0.0)
	BuildKit.cylinder(root, 0.1, 0.12, st + Vector3(0, 0.06, 0), PlaceDetail.col(Color(0.3, 0.3, 0.32), 0.4, 0.8), false, Vector3.ZERO, -1.0, 10)
	BuildKit.cylinder(root, 0.11, 0.12, st + Vector3(0, 0.18, 0), PlaceDetail.col(Color(0.25, 0.25, 0.26), 0.3, 0.8), false, Vector3.ZERO, 0.1, 12)
	PlaceDetail.lamp(root, c + Vector3(0, 1.0, 0.0), "hanging", false)
	BuildKit.box(root, Vector3(0.75, 0.15, 2.0), c + Vector3(-0.5, 0.15, -0.2), PlaceDetail.col(Color(0.15, 0.25, 0.4), 0.8), false)
	var crate := c + Vector3(-1.8, 0, -0.8)
	PlaceDetail.crate(root, crate, Vector3(0.9, 0.5, 0.6), 15.0)
	var mirror := BuildKit.color_mat(Color(0.75, 0.8, 0.85), 0.05, 0.95)
	for k in 4:
		BuildKit.box(root, Vector3(0.5, 0.6, 0.02), crate + Vector3(-0.25 + k * 0.15, 0.6, 0.0), PlaceKit.mat("cloth"), false, Vector3(0, 15, 8))
	for k in 18:
		var a := rng.randf() * TAU
		var r := rng.randf_range(2.0, 20.0)
		BuildKit.box(root, Vector3(rng.randf_range(0.05, 0.18), 0.004, rng.randf_range(0.05, 0.14)), PlaceKit.on_ground(root, cos(a) * r, sin(a) * r, 0.02), mirror, false, Vector3(0, rng.randf() * 360.0, 0))
	# Leiter an einem der Stämme, Seile hinauf
	var a0 := TAU * 3 / 14.0
	var tp := PlaceKit.on_ground(root, cos(a0) * 22.0, sin(a0) * 22.0)
	var lad := Node3D.new()
	lad.position = tp + Vector3(-cos(a0), 0, -sin(a0)) * 1.2
	lad.rotation = Vector3(deg_to_rad(-15.0), atan2(-cos(a0), -sin(a0)) + PI, 0)
	root.add_child(lad)
	for sx: float in [-0.22, 0.22]:
		BuildKit.box(lad, Vector3(0.05, 4.5, 0.06), Vector3(sx, 2.25, 0), PlaceKit.mat("wood_old"), false)
	for k in 13:
		BuildKit.box(lad, Vector3(0.44, 0.04, 0.04), Vector3(0, 0.3 + k * 0.33, 0), PlaceKit.mat("wood_old"), false)
	for k in 3:
		var a := TAU * (k * 4 + 1) / 14.0
		var p := PlaceKit.on_ground(root, cos(a) * 22.0, sin(a) * 22.0)
		PlaceDetail.cable(root, p + Vector3(-cos(a) * 0.3, 8.0, -sin(a) * 0.3), p + Vector3(-cos(a) * 1.0, 0.05, -sin(a) * 1.0), 0.0, 0.01, rope)
	# Stativ mit Kompass und Skizzenblock
	var tri := c + Vector3(3.0, 0, -1.5)
	for k in 3:
		var a := TAU * k / 3.0
		BuildKit.beam_between(root, tri + Vector3(0, 1.3, 0), tri + Vector3(cos(a) * 0.45, 0, sin(a) * 0.45), 0.015, PlaceKit.mat("metal"))
	BuildKit.cylinder(root, 0.07, 0.03, tri + Vector3(0, 1.33, 0), PlaceDetail.col(Color(0.7, 0.6, 0.3), 0.3, 0.8), false, Vector3.ZERO, -1.0, 12)
	PlaceDetail.clutter(root, c + Vector3(0.2, 0.0, 0.9), Vector2(0.6, 0.3), 991, 2, ["papers"])
	PlaceDetail.litter(root, Vector3.ZERO, 20.0, 992, 90, ["leaf", "leaf", "twig"], func(x: float, z: float) -> float: return PlaceKit.ground(root, x, z) + 0.02)


## Lebendige Orte: Steinlagen und Moos an den Widerlagern, eiserne Ringe, Treibholz vor dem Tor, Triftstämme am Ufer,
## Flößerhaken, Pegellatte, Bank, Weg aus Trittsteinen.
static func _klause_details(root: Node3D, bed: float, top: float) -> void:
	var dark := PlaceDetail.col(Color(0.25, 0.25, 0.24), 0.9)
	var moss := PlaceDetail.col(Color(0.15, 0.22, 0.08), 1.0)
	for sx: float in [-1.0, 1.0]:
		var y := bed
		while y < top:
			BuildKit.box(root, Vector3(3.02, 0.03, 3.22), Vector3(sx * 4.5, y, 0), dark, false)
			y += 0.45
		for k in 6:
			BuildKit.box(root, Vector3(0.6, 0.02, 0.5), Vector3(sx * 4.5 + (k % 3 - 1) * 0.8, top + 0.01, -1.0 + (k / 3) * 2.0), moss, false, Vector3(0, k * 33.0, 0))
		BuildKit.box(root, Vector3(0.04, 0.4, 0.4), Vector3(sx * 3.0, top - 0.6, -1.62), moss, false)
		HandKit.tube(root, HandKit.arc(Vector3(sx * 3.0, top - 0.5, -1.65), 0.1, 0, 360, 12, Vector3.RIGHT, Vector3.UP), 0.015, PlaceKit.mat("rust"), 5)
	# Treibholz vor dem Tor (Bergseite = -z)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1849
	for k in 9:
		BuildKit.cylinder(root, rng.randf_range(0.06, 0.15), rng.randf_range(1.2, 3.0), Vector3(rng.randf_range(-1.6, 1.6), bed + 0.4 + rng.randf() * 0.4, -0.6 - rng.randf() * 1.0), PlaceKit.mat("bark"), false,
				Vector3(rng.randf_range(-20, 20), rng.randf_range(-50, 50), 90), -1.0, 6)
	# Triftstämme am Ufer, Flößerhaken, Pegellatte
	for k in 5:
		var p := PlaceKit.on_ground(root, 8.0 + (k % 2) * 0.3, -3.0 + k * 0.45, 0.2)
		BuildKit.cylinder(root, 0.2, 4.0, p + Vector3(0, (k / 2) * 0.32, 0), PlaceKit.mat("bark"), true, Vector3(90, 0, 0), 0.18, 8)
	var hk := PlaceKit.on_ground(root, 7.0, 2.0, 0.05)
	BuildKit.cylinder(root, 0.025, 3.0, hk, PlaceKit.mat("wood_old"), false, Vector3(90, 30, 0), -1.0, 6)
	BuildKit.box(root, Vector3(0.05, 0.04, 0.2), hk + Vector3(1.5, 0, 0).rotated(Vector3.UP, deg_to_rad(-60.0)), PlaceKit.mat("rust"), false)
	var pg := Vector3(-2.9, bed, -1.65)
	BuildKit.box(root, Vector3(0.12, top - bed + 0.5, 0.02), pg + Vector3(0, (top - bed + 0.5) * 0.5 - 0.3, 0), PlaceDetail.col(Color(0.95, 0.95, 0.9), 0.6), false)
	for k in int((top - bed) / 0.1):
		BuildKit.box(root, Vector3(0.06 if k % 5 != 0 else 0.1, 0.012, 0.004), pg + Vector3(-0.02, k * 0.1 - 0.25, -0.012), PlaceDetail.col(Color(0.1, 0.1, 0.1)), false)
	# Bank und Trittsteine
	var bench := Node3D.new()
	bench.position = PlaceKit.on_ground(root, -8.5, 0.5)
	bench.rotation_degrees.y = 90.0
	root.add_child(bench)
	PlaceDetail.pew(bench, Vector3.ZERO, 1.5, "wood_old")
	for k in 6:
		BuildKit.box(root, Vector3(0.6, 0.08, 0.5), PlaceKit.on_ground(root, -9.0 + k * 0.6, 3.5 + sin(k) * 0.4, 0.03), PlaceKit.mat("stone"), false, Vector3(0, k * 20.0, 0))
	PlaceDetail.litter(root, Vector3(-7.5, 0, 0), 4.0, 1850, 30, ["leaf", "twig", "stone"], func(x: float, z: float) -> float: return PlaceKit.ground(root, x, z) + 0.02)
