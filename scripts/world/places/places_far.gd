class_name PlacesFar
extends RefCounted
## Orte für Mehrtagesmärsche: Außenstelle Messpunkt 4, Ilses Berghütte, Tunnelportal, Versunkenes Dorf,
## Wetterstation am Grat, Gewächshäuser, Der Wal, Raststätte an der Autobahn.



static func build(id: String, root: Node3D) -> bool:
	match id:
		"aussenstelle": _aussenstelle(root)
		"ilse": _ilse(root)
		"tunnel": _tunnel(root)
		"dorf": _dorf(root)
		"wetterstation": _wetterstation(root)
		"gewaechshaus": _gewaechshaus(root)
		"wal": _wal(root)
		"raststation": _raststation(root)
		_: return false
	return true


static func _label(parent: Node3D, text: String, pos: Vector3, size: int = 40, col: Color = Color(0.1, 0.1, 0.1), yaw: float = 0.0) -> Label3D:
	return PlacesDay.label(parent, text, pos, size, col, yaw)


## Innenwand mit Türöffnung (lokal im Gebäude, entlang z bei x).
static func _inner_wall_z(h: Node3D, x: float, z0: float, z1: float, height: float, door_at: float) -> void:
	BuildKit.wall(h, Vector2(x, z0), Vector2(x, z1), 0.0, height, 0.12, PlaceKit.mat("concrete"), [Vector4(door_at - z0, 1.0, 0.0, 2.05)], "Inner")


## Außenstelle Messpunkt 4: verlassene Forschungsstation mit Hauptgebäude (Büros, Labor, Schlafräume),
## Wachhäuschen, Antenne und dem verschlossenen Schachthaus „Schacht B“.
static func _aussenstelle(root: Node3D) -> void:
	PlaceKit.fence(root, [Vector2(-36, 26), Vector2(-36, -26), Vector2(36, -26), Vector2(36, 26), Vector2(-36, 26)], 2.6, [Vector2(244.0, 252.0)])
	_label(root, "ReZort Industries – Außenstelle MP4\nSperrgebiet", PlaceKit.on_ground(root, 6.0, 26.4, 2.4), 44, Color(0.75, 0.1, 0.08), 0.0)
	# Schranke + Wachhäuschen am Tor (Süden, x ≈ 0..8)
	var gate := PlaceKit.on_ground(root, 4.0, 26.0)
	BuildKit.box(root, Vector3(7.0, 0.12, 0.12), gate + Vector3(0, 1.0, 0.4), PlaceKit.mat("white"), false, Vector3(0, 0, 70))
	var guard := PlaceKit.hut(root, "Guard", PlaceKit.on_ground(root, -4.5, 22.0), Vector2(2.6, 2.4), 2.4, 0.0, "concrete", "flat", "concrete", 0.9, true)
	PlaceKit.loot(guard, "Medkit", "medkit", 2, Vector3(-0.7, 0.06, -0.7), "medkit")
	# Hauptgebäude
	var main := PlaceKit.hut(root, "Main", PlaceKit.on_ground(root, -8.0, -6.0), Vector2(22.0, 10.0), 3.0, 0.0, "concrete", "flat", "concrete", 1.4, true)
	_inner_wall_z(main, -3.5, -5.0, 5.0, 3.0, 3.6)
	_inner_wall_z(main, 3.5, -5.0, 5.0, 3.0, 3.6)
	# Büros (West)
	for k in 2:
		BuildKit.box(main, Vector3(1.6, 0.05, 0.8), Vector3(-9.0 + k * 3.2, 0.76, -3.6), PlaceKit.mat("wood"), true)
		BuildKit.box(main, Vector3(0.5, 0.35, 0.05), Vector3(-9.0 + k * 3.2, 1.0, -3.9), PlaceKit.mat("dark"), false)
	BuildKit.box(main, Vector3(0.5, 1.8, 2.4), Vector3(-10.7, 0.9, 1.0), PlaceKit.mat("steel_dark"), true)
	PlaceKit.note(main, "ast_wurzelwerk", Vector3(-9.0, 0.79, -3.5))
	PlaceKit.note(main, "ast_einsatzplan", Vector3(-5.8, 0.79, -3.5))
	PlaceKit.note(main, "ast_risiken", Vector3(-10.4, 0.06, 3.6))
	PlaceKit.loot(main, "Electronics", "electronics", 4, Vector3(-7.5, 0.06, 3.5), "case")
	# Labor (Mitte)
	BuildKit.box(main, Vector3(5.0, 0.95, 0.9), Vector3(0, 0.475, -4.2), PlaceKit.mat("white"), true)
	BuildKit.box(main, Vector3(1.0, 1.2, 0.8), Vector3(-2.2, 1.55, -4.2), PlaceKit.mat("glass"), false)
	BuildKit.box(main, Vector3(2.0, 0.95, 0.9), Vector3(0.8, 0.475, 1.5), PlaceKit.mat("white"), true)
	PlaceKit.loot(main, "Cells", "battery", 3, Vector3(0.8, 0.96, 1.5), "case")
	PlaceKit.note(main, "ast_schutzstatus", Vector3(-1.0, 0.96, -4.1))
	var tank := BuildKit.cylinder(main, 0.5, 1.8, Vector3(2.6, 0.9, -4.2), PlaceKit.mat("glass"), false, Vector3.ZERO, -1.0, 12)
	BuildKit.sphere(tank, 0.25, Vector3(0, -0.2, 0), PlaceKit.mat("alien"), Vector3(1.0, 1.4, 1.0), 9)
	# Schlafräume (Ost)
	for k in 3:
		BuildKit.box(main, Vector3(0.9, 0.45, 2.0), Vector3(5.0 + k * 1.9, 0.225, -3.6), PlaceKit.mat("steel_dark"), true)
		BuildKit.box(main, Vector3(0.85, 0.1, 1.9), Vector3(5.0 + k * 1.9, 0.5, -3.6), BuildKit.tex_mat("fabric", 0.4, Color(1.3, 1.35, 1.4)), false)
	PlaceKit.loot(main, "Food", "food", 4, Vector3(9.5, 0.06, 3.5), "cans")
	PlaceKit.loot(main, "Water", "water", 3, Vector3(8.4, 0.06, 3.6), "bottles")
	PlaceKit.loot(main, "Nails", "nails", 24, Vector3(6.0, 0.06, 3.6), "box", 12)
	# Fahrzeuge
	for k in 2:
		var vp := PlaceKit.on_ground(root, 14.0 + k * 4.0, 12.0)
		var van := Node3D.new()
		van.position = vp
		van.rotation_degrees.y = 90.0 + k * 8.0
		root.add_child(van)
		BuildKit.box(van, Vector3(2.0, 2.0, 4.8), Vector3(0, 1.2, 0), PlaceKit.mat("white"), true)
		BuildKit.box(van, Vector3(1.8, 0.7, 0.05), Vector3(0, 1.7, 2.42), PlaceKit.mat("glass"), false)
		for sx: float in [-0.9, 0.9]:
			for sz: float in [-1.5, 1.5]:
				BuildKit.cylinder(van, 0.35, 0.25, Vector3(sx, 0.35, sz), PlaceKit.mat("dark"), false, Vector3(0, 0, 90), -1.0, 10)
	PlaceKit.loot(root, "Fuel", "fuel_can", 1, PlaceKit.on_ground(root, 12.0, 15.0), "canister")
	# Antenne
	var ap := PlaceKit.on_ground(root, 26.0, -18.0)
	BuildKit.cylinder(root, 0.12, 16.0, ap + Vector3(0, 8.0, 0), PlaceKit.mat("metal"), true, Vector3.ZERO, 0.06, 8)
	BuildKit.cylinder(root, 1.2, 0.15, ap + Vector3(0, 12.0, 0.8), PlaceKit.mat("white"), false, Vector3(65, 0, 0), 0.2, 16)
	# Schachthaus „Schacht B“ – Tür mit Kartenleser
	var sh := PlaceKit.hut(root, "ShaftB", PlaceKit.on_ground(root, 20.0, -4.0), Vector2(6.0, 6.0), 3.6, -90.0, "concrete", "flat", "concrete", 1.3, false)
	_label(sh, "SCHACHT B", Vector3(-1.6, 2.6, 3.08), 50, Color(0.9, 0.85, 0.1))
	var door := BuildKit.box(sh, Vector3(1.3, 2.05, 0.08), Vector3(0, 1.025, 3.0), PlaceKit.mat("steel_dark"), true)
	door.name = "ShaftDoor"
	BuildKit.box(sh, Vector3(0.15, 0.25, 0.05), Vector3(0.9, 1.3, 3.08), PlaceKit.mat("dark"), false)
	var reader := BuildKit.box(sh, Vector3(0.06, 0.04, 0.01), Vector3(0.9, 1.36, 3.11), BuildKit.emissive_mat(Color(1.0, 0.15, 0.1), 1.5), false)
	var lock := PlaceKit.inspect(sh, "ShaftLock", "[E] Schlüsselkarte an den Leser halten", "Gesperrt. Neben der Tür ein Kartenleser: »MP4 – nur mit Karte«.", Vector3(0, 0, 3.2), Vector3(1.6, 2.1, 0.6))
	lock.needs = {"keycard_m4": 1}
	lock.done_flag = "shaft_b_open"
	lock.done_prompt = "Schacht B – offen"
	lock.done_text = "Der Leser piept grün. Die Tür gleitet auf. Drinnen: eine schwere Seilwinde und eine Treppe, die nach wenigen Metern im Schutt endet."
	var open_door := func() -> void:
		door.visible = false
		for c in door.get_children():
			c.queue_free()
		reader.material_override = BuildKit.emissive_mat(Color(0.2, 1.0, 0.3), 1.5)
	if lock.done:
		open_door.call()
	lock.acted.connect(open_door)
	# Inneres des Schachthauses
	BuildKit.box(sh, Vector3(2.4, 0.2, 2.4), Vector3(0, 0.1, -1.0), PlaceKit.mat("steel_dark"), false)
	BuildKit.cylinder(sh, 1.0, 0.1, Vector3(0, 0.22, -1.0), PlaceKit.mat("dark"), false, Vector3.ZERO, -1.0, 16)
	for k in 5:
		BuildKit.box(sh, Vector3(1.0, 0.18, 0.3), Vector3(1.9, 0.09 - k * 0.0, 1.8 - k * 0.3), PlaceKit.mat("concrete"), false)
	PlaceKit.loot(sh, "Winch", "shaft_winch", 1, Vector3(-1.8, 0.06, 1.6), "device")
	PlaceKit.note(sh, "ast_abschaltfolge1", Vector3(1.6, 0.06, -2.4))


## Ilses Berghütte: Blockhütte mit Funkantenne. Die Tür bleibt zu.
static func _ilse(root: Node3D) -> void:
	root.rotation_degrees.y = 150.0
	var h := PlaceKit.hut(root, "Hut", Vector3(0, PlaceKit.ground(root, 0, 0), 0), Vector2(5.0, 4.0), 2.4, 0.0, "logs", "gable", "shingles", 1.0, true)
	BuildKit.box(h, Vector3(1.0, 2.05, 0.06), Vector3(0, 1.025, 2.0), PlaceKit.mat("wood_old"), true)
	var knock := PlaceKit.inspect(h, "Door", "[E] Anklopfen", "Niemand öffnet. Hinter der Tür rauscht leise ein Funkgerät. Ein Zettel am Rahmen: »Nur über Funk. Kanal 7.«", Vector3(0, 0, 2.3), Vector3(1.2, 2.0, 0.5))
	knock.done_flag = "ilse_knocked"
	# Veranda mit Tisch und Logbuch
	BuildKit.box(h, Vector3(5.4, 0.08, 1.8), Vector3(0, 0.04, 3.0), PlaceKit.mat("wood_h"), true)
	BuildKit.box(h, Vector3(1.0, 0.05, 0.6), Vector3(1.6, 0.75, 3.0), PlaceKit.mat("wood"), true)
	PlaceKit.note(h, "ilse_logbuch", Vector3(1.6, 0.78, 3.0))
	# Antenne
	BuildKit.cylinder(h, 0.05, 8.0, Vector3(-2.2, 6.0, -1.6), PlaceKit.mat("metal"), false, Vector3.ZERO, 0.03, 6)
	for k in 4:
		BuildKit.box(h, Vector3(1.6 - k * 0.3, 0.03, 0.03), Vector3(-2.2, 7.0 + k * 0.6, -1.6), PlaceKit.mat("metal"), false)
	# Holzschuppen
	var shed := PlaceKit.hut(root, "WoodShed", PlaceKit.on_ground(root, 5.0, -2.0), Vector2(2.0, 2.4), 1.8, 90.0, "wood_old", "flat", "tin", 1.0, false)
	PlaceKit.loot(shed, "Food", "food", 2, Vector3(-0.4, 0.06, -0.6), "cans")
	PlaceKit.loot(shed, "RadioParts", "radio_parts", 1, Vector3(0.4, 0.06, -0.7), "case")
	PlaceKit.loot(shed, "Wood", "wood", 6, Vector3(0.0, 0.06, 0.4), "logs", 2)


## Tunnelportal: halbfertiger Bahntunnel in der Ostwand, Baucontainer davor. Tief drinnen wird es fremd.
static func _tunnel(root: Node3D) -> void:
	var g := PlaceKit.ground(root, 0, 0)
	var floor_y := g
	# Portal (Beton) bei x = +20, Tunnel nach +x
	var portal := Node3D.new()
	portal.name = "Portal"
	portal.position = Vector3(20.0, floor_y, 0)
	root.add_child(portal)
	var conc := PlaceKit.mat("concrete")
	BuildKit.box(portal, Vector3(1.5, 7.5, 2.0), Vector3(0, 3.75, -3.4), conc, true)
	BuildKit.box(portal, Vector3(1.5, 7.5, 2.0), Vector3(0, 3.75, 3.4), conc, true)
	BuildKit.box(portal, Vector3(1.5, 2.0, 8.8), Vector3(0, 6.5, 0), conc, true)
	_label(portal, "TUNNEL OST – ReZort Industries\nBaustelle – Betreten verboten", Vector3(-0.8, 6.6, 0), 40, Color(0.9, 0.85, 0.2), -90.0)
	# Tunnelröhre bis 46 m
	var length := 46.0
	var tube := Node3D.new()
	tube.name = "Tube"
	tube.position = Vector3(20.0, floor_y, 0)
	root.add_child(tube)
	BuildKit.box(tube, Vector3(length, 0.3, 6.0), Vector3(length * 0.5, -0.15, 0), PlaceKit.mat("stone_dark"), true)
	for sz: float in [-1.0, 1.0]:
		BuildKit.box(tube, Vector3(length, 5.5, 0.6), Vector3(length * 0.5, 2.75, sz * 3.0), PlaceKit.mat("rock"), true)
	BuildKit.box(tube, Vector3(length, 0.6, 6.6), Vector3(length * 0.5, 5.6, 0), PlaceKit.mat("rock"), true)
	# Fels über der Röhre (deckt den Einschnitt im Berg ab)
	var top := floor_y
	for k in 7:
		top = maxf(top, PlaceKit.ground(root, 20.0 + k * 7.5, 4.5))
		top = maxf(top, PlaceKit.ground(root, 20.0 + k * 7.5, -4.5))
	if top > floor_y + 5.9:
		BuildKit.box(root, Vector3(length + 1.0, top - floor_y - 5.6, 9.5), Vector3(20.0 + length * 0.5, floor_y + 5.6 + (top - floor_y - 5.6) * 0.5, 0), PlaceKit.mat("rock"), false)
	# Schienen und Schwellen
	for k in int(length / 0.8):
		BuildKit.box(tube, Vector3(0.25, 0.12, 2.4), Vector3(0.5 + k * 0.8, 0.06, 0), PlaceKit.mat("wood_old"), false)
	for sz: float in [-0.7, 0.7]:
		BuildKit.box(tube, Vector3(length - 6.0, 0.1, 0.08), Vector3((length - 6.0) * 0.5, 0.17, sz), PlaceKit.mat("rust"), false)
	# Baulampen (aus)
	for k in 6:
		BuildKit.box(tube, Vector3(0.3, 0.12, 0.12), Vector3(4.0 + k * 7.0, 4.6, 2.55), BuildKit.emissive_mat(Color(1.0, 0.85, 0.5), 0.0 if k > 1 else 0.8), false)
	# Am Ende: fremdes Geflecht verschließt die Röhre
	var wall := Node3D.new()
	wall.position = Vector3(length - 2.0, 0, 0)
	tube.add_child(wall)
	for i in 30:
		BuildKit.sphere(wall, randf_range(0.4, 1.1), Vector3(randf_range(-0.8, 0.8), randf_range(0.3, 5.0), randf_range(-2.6, 2.6)), PlaceKit.mat("alien"), Vector3(0.6, 1.0, 1.0), 8)
	for i in 8:
		BuildKit.sphere(wall, 0.12, Vector3(-0.9, randf_range(0.5, 4.5), randf_range(-2.2, 2.2)), PlaceKit.mat("glow"), Vector3.ONE, 6)
	var glow := OmniLight3D.new()
	glow.light_color = Color(0.7, 0.45, 1.0)
	glow.light_energy = 1.4
	glow.omni_range = 12.0
	glow.position = Vector3(-2.0, 2.5, 0)
	wall.add_child(glow)
	BuildKit.box(tube, Vector3(0.8, 0.6, 0.8), Vector3(length - 6.0, 0.3, 1.6), PlaceKit.mat("wood_h"), true)
	PlaceKit.note(tube, "tunnel_abschaltfolge2", Vector3(length - 6.0, 0.62, 1.6))
	# Baucontainer vor dem Portal
	var office := PlaceKit.hut(root, "SiteOffice", PlaceKit.on_ground(root, 2.0, -12.0), Vector2(6.0, 2.6), 2.5, 0.0, "tin", "flat", "tin", 0.9, true)
	BuildKit.box(office, Vector3(1.6, 0.05, 0.8), Vector3(-1.5, 0.76, -0.7), PlaceKit.mat("wood"), true)
	PlaceKit.note(office, "tunnel_massnahme11", Vector3(-1.8, 0.79, -0.7))
	PlaceKit.blueprint(office, "bp_overload", "Überlastungsmodul", Vector3(-1.0, 0.79, -0.7))
	PlaceKit.loot(office, "Electronics", "electronics", 3, Vector3(2.0, 0.06, -0.7), "case")
	var store := PlaceKit.hut(root, "Store", PlaceKit.on_ground(root, 2.0, 12.0), Vector2(6.0, 2.6), 2.5, 180.0, "tin", "flat", "tin", 0.9, false)
	PlaceKit.loot(store, "Scrap", "scrap", 8, Vector3(-1.4, 0.06, 0.0), "parts", 2)
	PlaceKit.loot(store, "Fuel", "fuel_can", 2, Vector3(1.6, 0.06, 0.4), "canister")


## Versunkenes Dorf: Grund des abgelassenen Stausees. Hausruinen, Kirche mit Glocke, gebrochener Damm.
static func _dorf(root: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1962
	var stone := PlaceKit.mat("stone")
	for i in 6:
		var a := rng.randf_range(0, TAU)
		var r := rng.randf_range(16.0, 45.0)
		var p := Vector3(cos(a) * r, 0, sin(a) * r)
		var ruin := Node3D.new()
		ruin.name = "Ruin_%d" % i
		ruin.position = PlaceKit.on_ground(root, p.x, p.z)
		ruin.rotation_degrees.y = rng.randf_range(0, 90)
		root.add_child(ruin)
		var w := rng.randf_range(6.0, 9.0)
		var d := rng.randf_range(5.0, 7.0)
		for k in 4:
			var hh := rng.randf_range(1.2, 3.5)
			var along := k % 2 == 0
			var len := w if along else d
			var off := Vector3(0, hh * 0.5, (d * 0.5 if k == 0 else -d * 0.5)) if along else Vector3((w * 0.5 if k == 1 else -w * 0.5), hh * 0.5, 0)
			var gap := 1.2 if k == 0 else 0.0
			if gap > 0.0:
				BuildKit.box(ruin, Vector3((len - gap) * 0.5, hh, 0.5), off + Vector3(-(len + gap) * 0.25, 0, 0), stone, true)
				BuildKit.box(ruin, Vector3((len - gap) * 0.5, hh, 0.5), off + Vector3((len + gap) * 0.25, 0, 0), stone, true)
			else:
				BuildKit.box(ruin, Vector3(len if along else 0.5, hh, 0.5 if along else len), off, stone, true)
		BuildKit.box(ruin, Vector3(w - 0.6, 0.05, d - 0.6), Vector3(0, 0.03, 0), PlaceKit.mat("mud"), false)
		if i == 1:
			PlaceKit.loot(ruin, "Scrap", "scrap", 8, Vector3(1.0, 0.06, 0.5), "parts", 2)
		elif i == 2:
			PlaceKit.loot(ruin, "Nails", "nails", 15, Vector3(-1.0, 0.06, 0.0), "box", 15)
			PlaceKit.loot(ruin, "Planks", "planks", 6, Vector3(1.2, 0.06, -1.0), "logs", 2)
		elif i == 4:
			PlaceKit.loot(ruin, "Food", "food", 2, Vector3(0.0, 0.06, 0.8), "cans")
	# Kirche mit Turm
	var ch := PlaceKit.hut(root, "Church", PlaceKit.on_ground(root, 0, -6.0), Vector2(7.0, 12.0), 5.0, 0.0, "stone", "gable", "shingles", 1.6, true, true)
	var tower := Node3D.new()
	tower.position = Vector3(0, 0, 7.5)
	ch.add_child(tower)
	BuildKit.box(tower, Vector3(3.2, 15.0, 3.2), Vector3(0, 7.5, 0), stone, true)
	BuildKit.cylinder(tower, 2.4, 5.0, Vector3(0, 17.5, 0), PlaceKit.mat("shingles"), false, Vector3.ZERO, 0.0, 4)
	for sx: float in [-1.0, 1.0]:
		BuildKit.box(tower, Vector3(0.1, 1.4, 0.8), Vector3(sx * 1.62, 13.0, 0), PlaceKit.mat("dark"), false)
	var bell := Node3D.new()
	bell.name = "Bell"
	bell.position = Vector3(0, 14.0, 0)
	tower.add_child(bell)
	var bm := BuildKit.lathe(bell, PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.55, 0.0), Vector2(0.5, 0.15), Vector2(0.35, 0.6), Vector2(0.3, 0.9), Vector2(0.0, 0.95)]),
			Vector3(0, -0.95, 0), BuildKit.color_mat(Color(0.45, 0.35, 0.2), 0.4, 0.8), 14)
	bm.position = Vector3(0, -0.95, 0)
	var t := bell.create_tween().set_loops()
	t.tween_property(bell, "rotation_degrees:z", 9.0, 2.6).set_trans(Tween.TRANS_SINE)
	t.tween_property(bell, "rotation_degrees:z", -9.0, 2.6).set_trans(Tween.TRANS_SINE)
	PlaceKit.note(ch, "dorf_chronik", Vector3(0.0, 0.06, -4.5))
	for k in 4:
		BuildKit.box(ch, Vector3(2.4, 0.06, 0.4), Vector3(-1.6 + (k % 2) * 3.2, 0.45, -1.0 + (k / 2) * 2.0), PlaceKit.mat("wood_old"), false, Vector3(0, 0, rng.randf_range(-12, 12)))
	# Gestrandete Boote
	for k in 3:
		var bp := PlaceKit.on_ground(root, rng.randf_range(-40, 40), rng.randf_range(20, 50), 0.1)
		BuildKit.box(root, Vector3(1.2, 0.4, 3.4), bp, PlaceKit.mat("wood_old"), true, Vector3(rng.randf_range(-12, 12), rng.randf() * 180.0, rng.randf_range(-20, 20)))
	# Damm im Süden mit Bruch, durch den der Bach läuft
	var dam_z := 150.0
	var dam_y := PlaceKit.ground(root, -60.0, dam_z)
	for side: float in [-1.0, 1.0]:
		var c := Vector3(side * 70.0 - 24.0, dam_y + 4.0, dam_z)
		BuildKit.box(root, Vector3(120.0, 16.0, 7.0), c + Vector3(side * 0.0, -2.0, 0), PlaceKit.mat("concrete"), true)
	_label(root, "STAUSEE ALTENREUTH  1964", Vector3(40.0, dam_y + 9.0, dam_z - 3.6), 120, Color(0.25, 0.25, 0.25), 180.0)


## Wetterstation am Grat: höchster Gipfel. Fernrohr, Windmesser, Kuppel – und eine Karte mit allen Orten.
static func _wetterstation(root: Node3D) -> void:
	var h := PlaceKit.hut(root, "Station", PlaceKit.on_ground(root, -3.0, 0), Vector2(5.0, 4.0), 2.6, 90.0, "stone", "flat", "concrete", 1.0, true)
	BuildKit.box(h, Vector3(1.8, 0.05, 0.8), Vector3(0, 0.78, -1.4), PlaceKit.mat("wood"), true)
	PlaceKit.loot(h, "Map", "hiking_map", 1, Vector3(-0.4, 0.8, -1.4), "paper")
	PlaceKit.note(h, "wetter_log", Vector3(0.5, 0.8, -1.4))
	PlaceKit.loot(h, "Food", "food", 2, Vector3(1.8, 0.06, 1.4), "cans")
	# Kuppel
	var dp := PlaceKit.on_ground(root, 6.0, -3.0)
	BuildKit.cylinder(root, 2.0, 2.4, dp + Vector3(0, 1.2, 0), PlaceKit.mat("concrete"), true, Vector3.ZERO, -1.0, 16)
	BuildKit.sphere(root, 2.0, dp + Vector3(0, 2.4, 0), PlaceKit.mat("white"), Vector3(1.0, 0.8, 1.0), 16)
	# Mast mit Windmesser (dreht sich)
	var mp := PlaceKit.on_ground(root, 3.0, 5.0)
	BuildKit.cylinder(root, 0.06, 9.0, mp + Vector3(0, 4.5, 0), PlaceKit.mat("metal"), true, Vector3.ZERO, 0.04, 6)
	var cups := Node3D.new()
	cups.position = mp + Vector3(0, 9.1, 0)
	root.add_child(cups)
	for k in 3:
		var a := TAU * k / 3.0
		BuildKit.box(cups, Vector3(0.6, 0.02, 0.02), Vector3(cos(a) * 0.3, 0, sin(a) * 0.3), PlaceKit.mat("metal"), false, Vector3(0, -rad_to_deg(a), 0))
		BuildKit.sphere(cups, 0.08, Vector3(cos(a) * 0.6, 0, sin(a) * 0.6), PlaceKit.mat("red"), Vector3.ONE, 8)
	var spin := cups.create_tween().set_loops()
	spin.tween_property(cups, "rotation:y", TAU, 1.6).from(0.0)
	# Fernrohr auf Stativ
	var tp := PlaceKit.on_ground(root, 1.0, -6.0)
	for k in 3:
		var a := TAU * k / 3.0
		BuildKit.cylinder(root, 0.025, 1.4, tp + Vector3(cos(a) * 0.25, 0.65, sin(a) * 0.25), PlaceKit.mat("dark"), false, Vector3(cos(a) * 12.0, 0, -sin(a) * 12.0), -1.0, 5)
	BuildKit.cylinder(root, 0.07, 0.9, tp + Vector3(0, 1.45, 0), PlaceKit.mat("steel_dark"), false, Vector3(70, 30, 0), 0.05, 10)
	var scope := PlaceKit.inspect(root, "Telescope", "[E] Durchs Fernrohr ins Tal schauen", "", tp, Vector3(0.8, 1.6, 0.8))
	scope.done_flag = "telescope"
	scope.text_provider = func() -> String:
		var st := WorldState.stage()
		var what: String = ["Das Tal sieht aus wie immer. Nur über der Hütte hängt ein feiner Dunst.",
			"Im Wald rund um die Hütte: Flecken, wo die Bäume grauer sind als sonst.",
			"Nebelbänke liegen still in den Senken, obwohl Wind geht. Ein Netz aus hellen Linien zieht sich durch den Wald.",
			"Der Bach glänzt violett. Lichtungen, die es vor Wochen nicht gab, liegen wie Pockennarben im Wald.",
			"Das ganze Tal atmet. Von hier oben sieht man, dass die hellen Linien auf einen Punkt zulaufen – die Hütte."][clampi(st, 0, 4)]
		return "Durchs Fernrohr: " + what


## Gewächshäuser: drei lange Glashäuser, zerbrochen. Drinnen wachsen nur noch fremde Pflanzen.
static func _gewaechshaus(root: Node3D) -> void:
	var frame := PlaceKit.mat("metal")
	var glass := PlaceKit.mat("glass")
	var rng := RandomNumberGenerator.new()
	rng.seed = 333
	for gh in 3:
		var house := Node3D.new()
		house.name = "Greenhouse_%d" % gh
		house.position = PlaceKit.on_ground(root, -18.0 + gh * 14.0, 0)
		root.add_child(house)
		var len := 30.0
		var w := 9.0
		for k in int(len / 3.0) + 1:
			var z := -len * 0.5 + k * 3.0
			for sx: float in [-1.0, 1.0]:
				BuildKit.box(house, Vector3(0.08, 2.6, 0.08), Vector3(sx * w * 0.5, 1.3, z), frame, false)
				BuildKit.box(house, Vector3(w * 0.56, 0.06, 0.06), Vector3(sx * w * 0.25, 3.2, z), frame, false, Vector3(0, 0, -sx * 18.0))
		for sx: float in [-1.0, 1.0]:
			for k in 10:
				if rng.randf() < 0.45:
					continue
				BuildKit.box(house, Vector3(0.02, 2.4, 2.9), Vector3(sx * w * 0.5, 1.3, -len * 0.5 + 1.5 + k * 3.0), glass, false)
			BuildKit.collider_box(house, Vector3(0.2, 2.6, len), Vector3(sx * w * 0.5, 1.3, 0))
		# Beete mit fremden Pflanzen
		for k in 18:
			var p := Vector3(rng.randf_range(-3.5, 3.5), 0, rng.randf_range(-13.0, 13.0))
			var pl := Node3D.new()
			pl.position = p
			house.add_child(pl)
			var s := rng.randf_range(0.6, 1.6)
			for f in 5:
				BuildKit.cylinder(pl, 0.04 * s, 1.2 * s, Vector3(0, 0.6 * s, 0), PlaceKit.mat("alien"), false, Vector3(rng.randf_range(-30, 30), f * 72.0, rng.randf_range(-30, 30)), 0.0, 5)
			BuildKit.sphere(pl, 0.1 * s, Vector3(0, 1.25 * s, 0), PlaceKit.mat("glow"), Vector3.ONE, 6)
	PlaceKit.loot(root.get_node("Greenhouse_1"), "Seeds", "alien_seeds", 4, Vector3(0.0, 0.0, 2.0), "alien", 2)
	var office := PlaceKit.hut(root, "Office", PlaceKit.on_ground(root, 0, -24.0), Vector2(5.0, 3.0), 2.5, 0.0, "concrete", "flat", "concrete", 1.0, true)
	BuildKit.box(office, Vector3(1.6, 0.05, 0.7), Vector3(-1.2, 0.76, -0.9), PlaceKit.mat("wood"), true)
	PlaceKit.note(office, "gw_bericht", Vector3(-1.4, 0.79, -0.9))
	PlaceKit.loot(office, "Filter", "water_filter", 1, Vector3(1.4, 0.06, -0.9), "box")
	PlaceKit.loot(office, "Food", "food", 2, Vector3(1.6, 0.06, 0.6), "cans")
	PlaceKit.loot(office, "Nails", "nails", 10, Vector3(-1.6, 0.06, 0.8), "box", 10)


## Der Wal: ein riesiger, halb im Hang vergrabener Rumpf. Er atmet. Drinnen schläft etwas.
static func _wal(root: Node3D) -> void:
	var hull := Node3D.new()
	hull.name = "Hull"
	hull.position = Vector3(0, PlaceKit.ground(root, 0, 0) - 3.0, 0)
	hull.rotation_degrees = Vector3(0, 25.0, 6.0)
	root.add_child(hull)
	var skin := BuildKit.tex_mat("alien_skin", 3.0, Color(0.42, 0.4, 0.46), 0.35)
	var skin_in := skin.duplicate() as StandardMaterial3D
	skin_in.cull_mode = BaseMaterial3D.CULL_DISABLED
	var length := 56.0
	var seg := 14
	for i in seg:
		var t := (i + 0.5) / seg
		var r := 8.5 * sqrt(maxf(1.0 - pow(t * 2.0 - 1.0, 2.0), 0.05))
		if i == seg - 1:
			continue  # aufgerissenes Ende
		var c := CylinderMesh.new()
		c.top_radius = r
		c.bottom_radius = 8.5 * sqrt(maxf(1.0 - pow(((i + 1.5) / seg) * 2.0 - 1.0, 2.0), 0.05))
		c.height = length / seg + 0.1
		c.cap_top = false
		c.cap_bottom = false
		c.radial_segments = 18
		c.material = skin_in
		var mi := MeshInstance3D.new()
		mi.mesh = c
		mi.position = Vector3(-length * 0.5 + (i + 0.5) * length / seg, 0, 0)
		mi.rotation_degrees = Vector3(0, 0, -90)
		hull.add_child(mi)
		# Rippe
		var rib := BuildKit.cylinder(hull, r + 0.25, 0.6, mi.position, PlaceKit.mat("steel_dark"), false, Vector3(0, 0, 90), -1.0, 18)
		rib.scale = Vector3(1.0, 1.0, 1.0)
	BuildKit.sphere(hull, 2.0, Vector3(-length * 0.5 + 0.5, 0, 0), skin, Vector3(1.0, 1.0, 1.0), 12)
	# Wände zum Anlehnen (innen begehbar)
	for sz: float in [-1.0, 1.0]:
		var wall := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(length, 10.0, 1.0)
		cs.shape = shape
		cs.position = Vector3(0, 3.0, sz * 6.2)
		wall.add_child(cs)
		hull.add_child(wall)
	# Leuchtknoten innen
	for k in 14:
		BuildKit.sphere(hull, 0.18, Vector3(-length * 0.4 + k * 3.4, randf_range(2.0, 5.0), randf_range(-5.0, 5.0)), PlaceKit.mat("glow"), Vector3.ONE, 6)
	var light := OmniLight3D.new()
	light.light_color = Color(0.6, 0.45, 1.0)
	light.light_energy = 0.8
	light.omni_range = 18.0
	light.position = Vector3(-8.0, 4.0, 0)
	hull.add_child(light)
	# Atmen: langsames Heben und Senken
	var breathe := hull.create_tween().set_loops()
	breathe.tween_property(hull, "scale", Vector3(1.0, 1.035, 1.03), 4.5).set_trans(Tween.TRANS_SINE)
	breathe.tween_property(hull, "scale", Vector3(1.0, 0.985, 0.99), 4.5).set_trans(Tween.TRANS_SINE)
	# Was dort schläft
	var sleeper := Node3D.new()
	sleeper.name = "Sleeper"
	sleeper.position = Vector3(-length * 0.3, 3.1, 0)
	sleeper.rotation_degrees.y = 90.0
	hull.add_child(sleeper)
	CreatureModel.pose_crouch(Creature.build_model(sleeper))
	# Funde nahe am Riss
	var inner := Node3D.new()
	inner.position = Vector3(length * 0.32, 3.1, 0)
	hull.add_child(inner)
	PlaceKit.loot(inner, "Cells", "energy_cell", 2, Vector3(0, 0, 1.5), "cell")
	PlaceKit.loot(inner, "Hull", "hull_sample", 1, Vector3(-2.0, 0, -1.8), "alien")


## Raststätte Waldblick an der Autobahn: Tankstelle, Laden, verlassene Autos.
static func _raststation(root: Node3D) -> void:
	var g := PlaceKit.ground(root, 0, 0)
	# Tankdach
	var canopy := Vector3(-6.0, g, 14.0)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			BuildKit.box(root, Vector3(0.4, 5.0, 0.4), canopy + Vector3(sx * 6.0, 2.5, sz * 4.0), PlaceKit.mat("white"), true)
	BuildKit.box(root, Vector3(14.0, 0.8, 10.0), canopy + Vector3(0, 5.4, 0), PlaceKit.mat("white"), false)
	BuildKit.box(root, Vector3(14.1, 0.3, 10.1), canopy + Vector3(0, 5.0, 0), PlaceKit.mat("red"), false)
	for k in 2:
		var pp := canopy + Vector3(-2.5 + k * 5.0, 0, 0)
		BuildKit.box(root, Vector3(0.8, 1.7, 0.5), pp + Vector3(0, 0.85, 0), PlaceKit.mat("red"), true)
		BuildKit.box(root, Vector3(0.5, 0.3, 0.02), pp + Vector3(0, 1.3, 0.26), PlaceKit.mat("dark"), false)
	_label(root, "Raststätte WALDBLICK", Vector3(-6.0, g + 5.4, 19.05), 70, Color(0.95, 0.95, 0.95))
	# Laden
	var shop := PlaceKit.hut(root, "Shop", PlaceKit.on_ground(root, 12.0, -4.0), Vector2(12.0, 8.0), 3.2, 180.0, "concrete", "flat", "concrete", 1.6, true)
	for k in 3:
		BuildKit.box(shop, Vector3(4.0, 1.6, 0.5), Vector3(-1.5, 0.8, -2.0 + k * 1.8), PlaceKit.mat("steel_dark"), true)
	BuildKit.box(shop, Vector3(2.4, 1.0, 0.7), Vector3(3.8, 0.5, 2.0), PlaceKit.mat("wood_h"), true)
	PlaceKit.note(shop, "rast_zettel", Vector3(3.6, 1.02, 2.0))
	PlaceKit.loot(shop, "Food", "food", 4, Vector3(-1.5, 1.62, -2.0), "cans")
	PlaceKit.loot(shop, "Water", "water", 4, Vector3(-1.5, 1.62, -0.2), "bottles")
	PlaceKit.loot(shop, "Fuel", "fuel_can", 3, Vector3(4.6, 0.06, -3.0), "canister")
	PlaceKit.loot(shop, "CarParts", "car_parts", 2, Vector3(-4.8, 0.06, -3.2), "parts", 1)
	PlaceKit.loot(shop, "Battery", "battery", 1, Vector3(-4.0, 0.06, -2.2), "case")
	# Verlassene Autos auf dem Parkplatz
	var rng := RandomNumberGenerator.new()
	rng.seed = 55
	for k in 5:
		var cp := PlaceKit.on_ground(root, -20.0 + k * 4.0 + rng.randf_range(-0.5, 0.5), -10.0 + rng.randf_range(-1, 1))
		var car := Node3D.new()
		car.position = cp
		car.rotation_degrees.y = rng.randf_range(-10, 10)
		root.add_child(car)
		var paint := BuildKit.tex_mat("car_paint", 1.0, [Color(0.5, 0.1, 0.1), Color(0.2, 0.25, 0.35), Color(0.6, 0.6, 0.6), Color(0.15, 0.3, 0.2), Color(0.8, 0.75, 0.6)][k])
		BuildKit.box(car, Vector3(1.8, 0.7, 4.2), Vector3(0, 0.6, 0), paint, true)
		BuildKit.box(car, Vector3(1.6, 0.55, 2.0), Vector3(0, 1.2, -0.2), paint, false)
		for sx: float in [-0.9, 0.9]:
			for sz: float in [-1.3, 1.3]:
				BuildKit.cylinder(car, 0.32, 0.22, Vector3(sx, 0.32, sz), PlaceKit.mat("dark"), false, Vector3(0, 0, 90), -1.0, 10)
		if k == 2:
			car.rotation_degrees.z = 4.0
			BuildKit.box(car, Vector3(1.0, 0.02, 1.4), Vector3(0, 0.02, 0), PlaceKit.mat("mud"), false)
	# Leitplanken an der Autobahn
	var hz := 1086.0 - root.global_position.z
	for k in 16:
		var x := -60.0 + k * 8.0
		for side: float in [-1.0, 1.0]:
			var p := PlaceKit.on_ground(root, x, hz + side * 6.2, 0.55)
			BuildKit.box(root, Vector3(8.0, 0.3, 0.1), p, PlaceKit.mat("metal"), true)
	# Abgestellter Sattelzug
	var truck := Node3D.new()
	truck.position = PlaceKit.on_ground(root, 30.0, hz - 2.0)
	root.add_child(truck)
	BuildKit.box(truck, Vector3(13.0, 3.4, 2.5), Vector3(0, 2.2, 0), PlaceKit.mat("white"), true)
	BuildKit.box(truck, Vector3(3.0, 3.0, 2.5), Vector3(8.2, 2.0, 0), PlaceKit.mat("red"), true)
	_label(truck, "DEG-RZ 117", Vector3(9.72, 0.9, 0), 40, Color(0.1, 0.1, 0.1), 90.0)
