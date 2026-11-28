class_name PlacesFar
extends RefCounted
## Orte für Mehrtagesmärsche: Außenstelle Messpunkt 4, Lusenschutzhaus (Ilse), Tunnelportal, Versunkenes Dorf,
## Wetterstation am Rachel, Gewächshäuser, Der Wal, Rasthaus an der B12, Alter Grenzübergang Bučina (Etappe 4).



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
		"grenze": _grenze(root)
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
	# Stefanies Spur: Polaroid hinter der Scheibe des Wachhäuschens
	BuildKit.box(guard, Vector3(0.09, 0.1, 0.004), Vector3(0.5, 1.35, -1.13), BuildKit.color_mat(Color(0.92, 0.92, 0.88)), false)
	BuildKit.box(guard, Vector3(0.075, 0.07, 0.003), Vector3(0.5, 1.36, -1.127), BuildKit.color_mat(Color(0.25, 0.3, 0.22)), false)
	PlaceKit.note(guard, "stef_polaroid", Vector3(0.5, 1.15, -1.0), true)
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
	PlaceKit.loot(main, "Drive", "rz_drive", 1, Vector3(-5.8, 0.79, -3.55), "card")
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
	_drop_door_leaf(sh)   # eigene Stahltür mit Kartenleser
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
	_aussenstelle_details(root, guard, main, sh)


## Ilses Hütte (Lusenschutzhaus): Blockhütte mit Funkantenne. Die Tür bleibt zu.
static func _ilse(root: Node3D) -> void:
	root.rotation_degrees.y = 150.0
	var h := PlaceKit.hut(root, "Hut", Vector3(0, PlaceKit.ground(root, 0, 0), 0), Vector2(5.0, 4.0), 2.4, 0.0, "logs", "gable", "shingles", 1.0, true)
	_drop_door_leaf(h)   # Ilses Tür bleibt zu
	BuildKit.box(h, Vector3(1.0, 2.05, 0.06), Vector3(0, 1.025, 2.0), PlaceKit.mat("wood_old"), true)
	var knock := PlaceKit.inspect(h, "Door", "[E] Anklopfen", "Niemand öffnet. Hinter der Tür rauscht leise ein Funkgerät. Ein Zettel am Rahmen: »Aufgmacht werd ned. Bloß übern Funk – Kanal 7. I.«", Vector3(0, 0, 2.3), Vector3(1.2, 2.0, 0.5))
	knock.done_flag = "ilse_knocked"
	_label(h, "LUSENSCHUTZHAUS", Vector3(0, 2.22, 2.07), 30, Color(0.92, 0.88, 0.78))
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
	_ilse_details(root, h, shed)


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
	PlaceKit.note(office, "stef_tunnel", Vector3(-0.35, 0.79, -0.75))   # Stefanies Spur: alter Parkschein
	PlaceKit.loot(office, "Electronics", "electronics", 3, Vector3(2.0, 0.06, -0.7), "case")
	var store := PlaceKit.hut(root, "Store", PlaceKit.on_ground(root, 2.0, 12.0), Vector2(6.0, 2.6), 2.5, 180.0, "tin", "flat", "tin", 0.9, false)
	PlaceKit.loot(store, "Scrap", "scrap", 8, Vector3(-1.4, 0.06, 0.0), "parts", 2)
	PlaceKit.loot(store, "Fuel", "fuel_can", 2, Vector3(1.6, 0.06, 0.4), "canister")
	_tunnel_details(root, tube, length, office)


## Hütten aus PlaceKit.hut bekommen einen offenen Türflügel – wo die Tür zu bleiben muss, kommt er weg.
static func _drop_door_leaf(h: Node3D) -> void:
	var dl := h.find_child("DoorLeaf", true, false)
	if dl:
		dl.get_parent().remove_child(dl)
		dl.free()


## Eigener Zufall je Haus (die Ruinen behalten ihren Platz, auch wenn sich ihr Aufbau ändert).
static func _sub_rng(seed_value: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	return r


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
		DrownedVillage.house(ruin, w, d, _sub_rng(1962 + i * 31))
		if i == 1:
			PlaceKit.loot(ruin, "Scrap", "scrap", 8, Vector3(1.0, 0.06, 0.5), "parts", 2)
		elif i == 2:
			PlaceKit.loot(ruin, "Nails", "nails", 15, Vector3(-1.0, 0.06, 0.0), "box", 15)
			PlaceKit.loot(ruin, "Planks", "planks", 6, Vector3(1.2, 0.06, -1.0), "logs", 2)
		elif i == 4:
			PlaceKit.loot(ruin, "Food", "food", 2, Vector3(0.0, 0.06, 0.8), "cans")
	# Bayerwald (Etappe 4): Altenreuth war ein Glashüttendorf – Ruine des Glasofens mit Scherbenhalde
	var ruins: Array[Vector3] = []
	for r in root.get_children():
		if r.name.begins_with("Ruin_"):
			ruins.append((r as Node3D).position)
	var best := Vector3.ZERO
	var best_d := -1.0
	for k in 16:
		var a := TAU * k / 16.0
		var c := Vector3(cos(a) * 30.0, 0, sin(a) * 30.0 - 6.0)
		var d := INF
		for rp: Vector3 in ruins:
			d = minf(d, Vector2(rp.x - c.x, rp.z - c.z).length())
		d = minf(d, Vector2(c.x, c.z + 6.0).length() - 12.0)   # Abstand zur Kirche
		if d > best_d:
			best_d = d
			best = c
	_glass_furnace(root, PlaceKit.on_ground(root, best.x, best.z), rng)
	# Kirche mit begehbarem Turm (Christian 14.11.: schöner, und man muss hineinkommen)
	var ch := Node3D.new()
	ch.name = "Church"
	ch.position = PlaceKit.on_ground(root, 0, -6.0)
	root.add_child(ch)
	DrownedVillage.church(ch, _sub_rng(77))
	PlaceKit.note(ch, "dorf_chronik", Vector3(-0.5, 1.29, -5.9))   # auf dem Altar
	PlaceKit.note(ch, "stef_dorf", Vector3(0.5, 1.29, -5.9))   # Stefanies Spur: Zeitungsausschnitt
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


## Wetterstation am Rachel: höchster Gipfel. Fernrohr, Windmesser, Kuppel – und eine Karte mit allen Orten.
static func _wetterstation(root: Node3D) -> void:
	var h := PlaceKit.hut(root, "Station", PlaceKit.on_ground(root, -3.0, 0), Vector2(5.0, 4.0), 2.6, 90.0, "stone", "flat", "concrete", 1.0, true)
	_wetterstation_details(root, h)
	BuildKit.box(h, Vector3(1.8, 0.05, 0.8), Vector3(0, 0.78, -1.4), PlaceKit.mat("wood"), true)
	PlaceKit.loot(h, "Map", "hiking_map", 1, Vector3(-0.4, 0.8, -1.4), "paper")
	PlaceKit.note(h, "wetter_log", Vector3(0.5, 0.8, -1.4))
	PlaceKit.note(h, "stef_gipfelbuch", Vector3(1.2, 0.8, -1.45))   # Stefanies Spur: Gipfelbuch
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
	# Bayerwald (Etappe 4): stillgelegte Radarstation – zwei große weiße Kuppeln auf Betontürmen, Zaun mit Schild
	for k in 2:
		var rp := PlaceKit.on_ground(root, -12.0 if k == 0 else 12.0, -11.0 if k == 0 else 12.0)
		var radar := Node3D.new()
		radar.name = "Radome_%d" % k
		radar.position = rp
		root.add_child(radar)
		BuildKit.cylinder(radar, 2.3, 6.0, Vector3(0, 3.0, 0), PlaceKit.mat("concrete"), true, Vector3.ZERO, -1.0, 14)
		BuildKit.box(radar, Vector3(1.0, 2.0, 0.08), Vector3(0, 1.0, 2.28), PlaceKit.mat("steel_dark"), false)
		BuildKit.sphere(radar, 3.7, Vector3(0, 8.9, 0), PlaceKit.mat("white"), Vector3(1.0, 0.92, 1.0), 20)
		# Nähte der Kuppelhaut (dunkle Ringe)
		for ry: float in [-1.6, 0.0, 1.6]:
			var rr := sqrt(maxf(3.72 * 3.72 - ry * ry / (0.92 * 0.92), 0.1))
			BuildKit.cylinder(radar, rr + 0.02, 0.05, Vector3(0, 8.9 + ry, 0), PlaceKit.mat("steel_dark"), false, Vector3.ZERO, -1.0, 20)
		if k == 0:
			var sign_p := Vector3(0, 0, 3.6)
			BuildKit.box(radar, Vector3(0.08, 1.6, 0.08), sign_p + Vector3(0, 0.8, 0), PlaceKit.mat("metal"), true)
			BuildKit.box(radar, Vector3(1.4, 0.7, 0.04), sign_p + Vector3(0, 1.45, 0.05), PlaceKit.mat("white"), false)
			_label(radar, "MILITÄRISCHER\nSICHERHEITSBEREICH\nRadarstation – stillgelegt", sign_p + Vector3(0, 1.45, 0.08), 22, Color(0.7, 0.08, 0.05))
			var look := PlaceKit.inspect(radar, "RadarDoor", "[E] Stahltür am Radarturm", "Verschweißt. Jemand hat mit Kreide daneben geschrieben: »Sie hören noch.« Darunter, frischer: »Wer?«", Vector3(0, 0, 2.6), Vector3(1.4, 2.0, 0.6))


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
	_gewaechshaus_details(root, office)


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
	# fester Name: die Funde darin gehören zum Spielstand
	inner.name = "Inner"
	inner.position = Vector3(length * 0.32, 3.1, 0)
	hull.add_child(inner)
	PlaceKit.loot(inner, "Cells", "energy_cell", 2, Vector3(0, 0, 1.5), "cell")
	PlaceKit.loot(inner, "Hull", "hull_sample", 1, Vector3(-2.0, 0, -1.8), "alien")
	_wal_details(root, hull)


## Rasthaus Waldblick an der B12: Tankstelle, Laden, verlassene Autos.
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
	_label(root, "Rasthaus WALDBLICK", Vector3(-6.0, g + 5.4, 19.05), 70, Color(0.95, 0.95, 0.95))
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
	# Leitplanken an der B12
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
	# Eingedrückte Stoßstange mit blauem Lacksplitter (Story: Maßnahme 11)
	BuildKit.box(truck, Vector3(0.25, 0.3, 2.4), Vector3(9.8, 0.55, 0.0), PlaceKit.mat("steel_dark"), false, Vector3(0, 8, 0))
	BuildKit.box(truck, Vector3(0.03, 0.12, 0.2), Vector3(9.95, 0.62, 0.7), BuildKit.color_mat(Color(0.15, 0.3, 0.75), 0.4), false)
	PlaceKit.note(truck, "lkw_raststation", Vector3(10.3, 0.0, 0.4), true)
	_raststation_details(root, canopy, shop, truck)


## Alter Grenzübergang Bučina (Etappe 4): Zollhaus, offene Schranke, Grenzpfähle (Bayern/Tschechien), Grenzstein,
## Reste des Eisernen Vorhangs (schiefe Betonpfosten mit Stacheldraht) und ein umgekippter Wachturm auf der anderen Seite.
## Die Grenze verläuft im Norden (-z) am Kartenrand.
static func _grenze(root: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1989
	# Zollhaus
	var h := PlaceKit.hut(root, "Zollhaus", PlaceKit.on_ground(root, -9.0, 3.0), Vector2(6.0, 4.0), 2.6, 0.0, "wood", "gable", "shingles", 1.0, true)
	BuildKit.box(h, Vector3(1.6, 0.05, 0.8), Vector3(-1.4, 0.78, -1.3), PlaceKit.mat("wood"), true)
	PlaceKit.note(h, "grenze_dienstbuch", Vector3(-1.7, 0.81, -1.3))
	PlaceKit.loot(h, "Battery", "battery", 2, Vector3(-0.8, 0.81, -1.35), "box", 1)
	PlaceKit.loot(h, "Food", "food", 2, Vector3(2.0, 0.06, 1.3), "cans")
	_label(h, "ZOLL · CLO", Vector3(0, 2.15, 2.1), 30, Color(0.95, 0.92, 0.85))
	# Schranke (offen, rostig), rot-weiß
	var bp := PlaceKit.on_ground(root, -3.2, -3.0)
	BuildKit.box(root, Vector3(0.35, 1.1, 0.35), bp + Vector3(0, 0.55, 0), PlaceKit.mat("concrete"), true)
	var arm := Node3D.new()
	arm.name = "Barrier"
	arm.position = bp + Vector3(0, 1.05, 0)
	arm.rotation_degrees = Vector3(0, 0, 68)   # hochgeklappt
	root.add_child(arm)
	for k in 8:
		BuildKit.box(arm, Vector3(0.75, 0.12, 0.12), Vector3(0.4 + k * 0.75, 0, 0), PlaceKit.mat("red" if k % 2 == 0 else "white"), false)
	var gate := PlaceKit.inspect(root, "BarrierLook", "[E] Schranke ansehen", "Rostig, hochgeklappt. Seit über dreißig Jahren hat hier keiner mehr kontrolliert. Im Schnee davor: frische Spuren – sie führen nur in eine Richtung, über die Grenze.", bp, Vector3(1.0, 1.4, 1.0))
	# Grenzpfähle und Grenzstein
	var de := PlaceKit.on_ground(root, -2.0, -9.0)
	var cz := PlaceKit.on_ground(root, 2.2, -10.0)
	for k in 6:   # Bayern: weiß-blau, Deutschland: schwarz-rot-gold (oben)
		var c := ["white", "blue", "white", "black", "red", "gold"][k] as String
		BuildKit.cylinder(root, 0.09, 0.3, de + Vector3(0, 0.15 + k * 0.3, 0), _flag_mat(c), true, Vector3.ZERO, -1.0, 8)
	for k in 6:   # Tschechien: rot-weiß-blau im Wechsel
		var c := ["red", "white", "blue"][k % 3] as String
		BuildKit.cylinder(root, 0.09, 0.3, cz + Vector3(0, 0.15 + k * 0.3, 0), _flag_mat(c), true, Vector3.ZERO, -1.0, 8)
	var stone_p := PlaceKit.on_ground(root, 0.0, -9.6)
	BuildKit.box(root, Vector3(0.45, 0.7, 0.3), stone_p + Vector3(0, 0.3, 0), PlaceKit.mat("stone"), true)
	_label(root, "D", stone_p + Vector3(0, 0.45, 0.16), 34, Color(0.1, 0.1, 0.1))
	_label(root, "Č", stone_p + Vector3(0, 0.45, -0.16), 34, Color(0.1, 0.1, 0.1), 180.0)
	# Grenzschild
	var sp := PlaceKit.on_ground(root, 4.5, -6.0)
	BuildKit.box(root, Vector3(0.08, 2.0, 0.08), sp + Vector3(-0.7, 1.0, 0), PlaceKit.mat("metal"), true)
	BuildKit.box(root, Vector3(0.08, 2.0, 0.08), sp + Vector3(0.7, 1.0, 0), PlaceKit.mat("metal"), true)
	BuildKit.box(root, Vector3(1.8, 0.8, 0.04), sp + Vector3(0, 1.75, 0.05), PlaceKit.mat("white"), false)
	_label(root, "STAATSGRENZE\nSTÁTNÍ HRANICE", sp + Vector3(0, 1.75, 0.08), 28, Color(0.1, 0.12, 0.35))
	# Eiserner Vorhang: schiefe Betonpfosten mit Stacheldraht, manche umgefallen
	var wire := PlaceKit.mat("rust")
	var prev := Vector3.INF
	for k in 14:
		var lx := -26.0 + k * 4.0
		var lp := PlaceKit.on_ground(root, lx, -19.0 + rng.randf_range(-0.4, 0.4))
		var fallen := rng.randf() < 0.2
		var post := Node3D.new()
		post.position = lp
		post.rotation_degrees = Vector3(rng.randf_range(-6, 6), 0, 80.0 if fallen else rng.randf_range(-5, 5))
		root.add_child(post)
		BuildKit.box(post, Vector3(0.16, 2.2, 0.16), Vector3(0, 1.1, 0), PlaceKit.mat("concrete"), not fallen)
		BuildKit.box(post, Vector3(0.12, 0.6, 0.12), Vector3(0, 2.35, -0.2), PlaceKit.mat("concrete"), false, Vector3(-45, 0, 0))
		if not fallen and prev != Vector3.INF and rng.randf() < 0.75:
			for wy: float in [0.4, 0.9, 1.4, 1.9]:
				var a := prev + Vector3(0, wy, 0)
				var b := lp + Vector3(0, wy + rng.randf_range(-0.25, 0.1), 0)
				BuildKit.beam_between(root, a, b, 0.012, wire)
		prev = Vector3.INF if fallen else lp
	# umgekippter Wachturm drüben
	var tw := Node3D.new()
	tw.name = "Watchtower"
	tw.position = PlaceKit.on_ground(root, 14.0, -27.0)
	tw.rotation_degrees = Vector3(0, 25, -14)
	root.add_child(tw)
	for lx: float in [-1.2, 1.2]:
		for lz: float in [-1.2, 1.2]:
			BuildKit.box(tw, Vector3(0.18, 6.0, 0.18), Vector3(lx, 3.0, lz), PlaceKit.mat("wood_old"), true)
	BuildKit.box(tw, Vector3(3.2, 0.15, 3.2), Vector3(0, 6.0, 0), PlaceKit.mat("wood_old"), false)
	BuildKit.box(tw, Vector3(3.2, 1.0, 0.1), Vector3(0, 6.6, 1.55), PlaceKit.mat("wood_old"), false)
	BuildKit.box(tw, Vector3(3.6, 0.12, 3.6), Vector3(0, 7.8, 0), PlaceKit.mat("tin"), false, Vector3(0, 0, 8))
	_grenze_details(root, h)


static func _flag_mat(c: String) -> Material:
	match c:
		"blue": return BuildKit.color_mat(Color(0.15, 0.3, 0.7), 0.6)
		"black": return BuildKit.color_mat(Color(0.06, 0.06, 0.06), 0.6)
		"gold": return BuildKit.color_mat(Color(0.9, 0.72, 0.1), 0.5)
		"red": return PlaceKit.mat("red")
	return PlaceKit.mat("white")


## Glasofen der alten Glashütte Altenreuth: runder Ziegelsockel, halb eingestürzte Kuppel mit Arbeitsöffnungen,
## Kaminstumpf, Scherben in Grün, Blau und Bernstein, Schlacke. Schild + Notiz.
static func _glass_furnace(root: Node3D, at: Vector3, rng: RandomNumberGenerator) -> void:
	var f := Node3D.new()
	f.name = "Glashuette"
	f.position = at
	root.add_child(f)
	var brick := BuildKit.color_mat(Color(0.5, 0.26, 0.18), 0.95)
	var soot := BuildKit.color_mat(Color(0.12, 0.1, 0.09), 1.0)
	BuildKit.cylinder(f, 2.6, 1.1, Vector3(0, 0.45, 0), brick, true, Vector3.ZERO, -1.0, 16)
	var dome := BuildKit.sphere(f, 2.3, Vector3(0, 1.0, 0), brick, Vector3(1.0, 0.75, 1.0), 14)
	dome.rotation_degrees = Vector3(18, 0, 0)   # eingesackt
	for k in 4:   # Arbeitslöcher (Glasmacher standen rundherum)
		var a := TAU * k / 4.0 + 0.4
		BuildKit.box(f, Vector3(0.55, 0.45, 0.3), Vector3(cos(a) * 2.25, 1.2, sin(a) * 2.25), soot, false, Vector3(0, -rad_to_deg(a), 0))
	BuildKit.cylinder(f, 0.55, 2.4, Vector3(-1.6, 2.2, -1.2), brick, true, Vector3(0, 0, 6), 0.45, 10)   # Kaminstumpf
	DrownedVillage.rubble(f, Vector3(1.8, 0, 1.6), 9, 1.2, brick, rng)
	# Scherbenhalde: viele kleine Glasstücke, leicht glänzend
	var colors := [Color(0.25, 0.55, 0.3, 0.75), Color(0.2, 0.35, 0.65, 0.75), Color(0.7, 0.45, 0.12, 0.75), Color(0.75, 0.8, 0.78, 0.6)]
	for i in 70:
		var col: Color = colors[rng.randi() % colors.size()]
		var m := StandardMaterial3D.new()
		m.albedo_color = col
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.roughness = 0.08
		m.metallic_specular = 0.9
		var r := rng.randf_range(2.8, 5.5)
		var a := rng.randf() * TAU
		var gx := cos(a) * r
		var gz := sin(a) * r
		BuildKit.box(f, Vector3(rng.randf_range(0.04, 0.12), 0.01, rng.randf_range(0.03, 0.09)),
				Vector3(gx, PlaceKit.ground(root, at.x + gx, at.z + gz) - at.y + 0.02, gz),
				m, false, Vector3(rng.randf_range(-20, 20), rng.randf() * 180.0, rng.randf_range(-20, 20)))
	# Schild
	var sp := Vector3(0, 0, 3.6)
	BuildKit.box(f, Vector3(0.1, 1.4, 0.1), sp + Vector3(0, 0.7, 0), PlaceKit.mat("wood_old"), true)
	BuildKit.box(f, Vector3(1.3, 0.55, 0.05), sp + Vector3(0, 1.3, 0.06), PlaceKit.mat("wood_old"), false)
	_label(f, "Glashütte Altenreuth\n1721 – 1898", sp + Vector3(0, 1.3, 0.1), 24, Color(0.92, 0.88, 0.78))
	PlaceKit.note(f, "dorf_glashuette", Vector3(0.45, 0.08, 3.4))


## Lebendige Orte: Außenstelle in Eile verlassen – Büros mit Stühlen, Monitoren, Aktenschränken und Papier überall,
## Labor mit Abzug, Mikroskop, Kolben, Warnzeichen, Schlafraum mit Spinden, Teeküche, Notbeleuchtung; draußen Parkplatz-
## linien, Flutlichtmasten, Kameras am Zaun, Fahnenmast, Aggregat, Container, Wachhäuschen mit Schlüsselbrett.
static func _aussenstelle_details(root: Node3D, guard: Node3D, main: Node3D, sh: Node3D) -> void:
	var dark := PlaceDetail.col(Color(0.06, 0.06, 0.07), 0.4)
	var grey := PlaceDetail.col(Color(0.62, 0.63, 0.62), 0.5, 0.3)
	var rng := RandomNumberGenerator.new()
	rng.seed = 404
	# Büros (West): Stühle (einer umgekippt), Monitore an, Aktenschränke, Papier am Boden, Pinnwand, Deckenlampen
	for k in 2:
		PlaceDetail.office_chair(main, Vector3(-9.0 + k * 3.2, 0.06, -2.9), 180.0 + k * 30.0)
		var scr := BuildKit.emissive_mat(Color(0.1, 0.25, 0.4), 0.9 if k == 0 else 0.0)
		BuildKit.box(main, Vector3(0.46, 0.3, 0.005), Vector3(-9.0 + k * 3.2, 1.0, -3.87), scr, false)
		BuildKit.box(main, Vector3(0.44, 0.02, 0.15), Vector3(-9.0 + k * 3.2, 0.79, -3.4), dark, false)
		PlaceDetail.clutter(main, Vector3(-8.5 + k * 3.2, 0.79, -3.7), Vector2(0.5, 0.3), 40 + k, 2, ["papers", "binders"])
	PlaceDetail.chair(main, Vector3(-6.5, 0.06, -1.5), 40.0, "furn", true)
	for k in 3:
		var fc := Node3D.new()
		fc.position = Vector3(-10.6, 0.06, -2.0 + k * 0.55)
		main.add_child(fc)
		BuildKit.box(fc, Vector3(0.6, 1.3, 0.5), Vector3(0, 0.65, 0), grey, true)
		for d in 3:
			BuildKit.box(fc, Vector3(0.02, 0.36, 0.44), Vector3(0.31, 0.25 + d * 0.42, 0), grey, false)
			BuildKit.box(fc, Vector3(0.03, 0.03, 0.12), Vector3(0.33, 0.38 + d * 0.42, 0), PlaceKit.mat("metal"), false)
		if k == 1:
			BuildKit.box(fc, Vector3(0.38, 0.3, 0.44), Vector3(0.45, 0.67, 0), grey, false)
	PlaceDetail.litter(main, Vector3(-7.5, 0.06, 0.0), 3.0, 405, 40, ["paper", "paper", "paper"])
	PlaceDetail.sign(main, "EVAKUIERUNG\nSammelplatz: Tor Süd\nUnterlagen NICHT mitnehmen!", Vector3(-4.2, 1.6, 0.0), Vector2(0.6, 0.4), -90.0, Color(0.95, 0.95, 0.93), Color(0.7, 0.1, 0.08), 26)
	# Labor (Mitte): Abzug, Mikroskop, Kolben, Gefahrzeichen, Augendusche
	var hood := Node3D.new()
	hood.position = Vector3(-1.0, 0.95, -4.4)
	main.add_child(hood)
	BuildKit.box(hood, Vector3(1.6, 1.2, 0.05), Vector3(0, 0.6, -0.3), grey, false)
	BuildKit.box(hood, Vector3(1.6, 0.05, 0.7), Vector3(0, 1.2, 0.05), grey, false)
	BuildKit.box(hood, Vector3(1.5, 0.6, 0.01), Vector3(0, 0.75, 0.38), PlaceKit.mat("glass"), false)
	var mic := Node3D.new()
	mic.position = Vector3(1.2, 0.95, -4.2)
	main.add_child(mic)
	BuildKit.box(mic, Vector3(0.22, 0.04, 0.28), Vector3(0, 0.02, 0), dark, false)
	BuildKit.box(mic, Vector3(0.06, 0.32, 0.06), Vector3(0, 0.18, -0.1), dark, false)
	BuildKit.cylinder(mic, 0.03, 0.18, Vector3(0, 0.33, 0.0), dark, false, Vector3(30, 0, 0), -1.0, 8)
	BuildKit.box(mic, Vector3(0.12, 0.012, 0.12), Vector3(0, 0.12, 0.02), PlaceKit.mat("metal"), false)
	var glass := BuildKit.glass_mat().duplicate() as StandardMaterial3D
	glass.albedo_color = Color(0.7, 0.85, 0.8, 0.35)
	for k in 5:
		var fp := Vector3(1.8 + k * 0.14, 0.95, -4.1 + (k % 2) * 0.12)
		BuildKit.lathe(main, PackedVector2Array([Vector2(0, 0), Vector2(0.05, 0), Vector2(0.05, 0.02), Vector2(0.015, 0.1), Vector2(0.015, 0.16), Vector2(0, 0.16)]), fp, glass, 10)
		BuildKit.lathe(main, PackedVector2Array([Vector2(0, 0), Vector2(0.04, 0), Vector2(0.014, 0.07), Vector2(0, 0.07)]), fp + Vector3(0, 0.005, 0), PlaceDetail.col([Color(0.2, 0.7, 0.4), Color(0.6, 0.3, 0.7), Color(0.8, 0.6, 0.1)][k % 3], 0.2), 10)
	PlaceDetail.sign(main, "☣ BIOGEFAHR\nStufe 3 – Proben MP4", Vector3(0.0, 2.0, -4.97), Vector2(0.5, 0.3), 0.0, Color(0.95, 0.8, 0.1), Color(0.05, 0.05, 0.05), 26)
	BuildKit.box(main, Vector3(0.25, 0.25, 0.15), Vector3(3.2, 1.6, -4.9), PlaceDetail.col(Color(0.2, 0.6, 0.3), 0.5), false)
	# Schlafraum (Ost): Spinde, Wolldecken, Spiegel
	for k in 4:
		var lp := Vector3(10.6, 0.06, -1.6 + k * 0.5)
		BuildKit.box(main, Vector3(0.5, 1.9, 0.48), lp + Vector3(0, 0.95, 0), PlaceDetail.col(Color(0.35, 0.4, 0.45), 0.4, 0.5), true)
		for v in 3:
			BuildKit.box(main, Vector3(0.01, 0.02, 0.3), lp + Vector3(-0.26, 1.6 + v * 0.05, 0), dark, false)
		if k == 2:
			var door := Node3D.new()
			door.position = lp + Vector3(-0.25, 0, -0.24)
			door.rotation_degrees.y = -70.0
			main.add_child(door)
			BuildKit.box(door, Vector3(0.02, 1.85, 0.48), Vector3(0, 0.95, 0.24), PlaceDetail.col(Color(0.35, 0.4, 0.45), 0.4, 0.5), false)
	for k in 3:
		BuildKit.box(main, Vector3(0.7, 0.05, 0.8), Vector3(5.0 + k * 1.9, 0.57, -3.2), PlaceKit.mat("cloth"), false, Vector3(0, k * 10.0, 3))
	# Teeküche im Flur, Notbeleuchtung (rot), Deckenleuchten
	BuildKit.box(main, Vector3(1.6, 0.9, 0.6), Vector3(5.5, 0.45, 4.3), PlaceKit.mat("cabinet"), true)
	PlaceDetail.clutter(main, Vector3(5.5, 0.9, 4.3), Vector2(1.4, 0.4), 406, 4, ["cans", "jars", "bottles"])
	for k in 5:
		var x := -9.0 + k * 4.5
		BuildKit.box(main, Vector3(1.2, 0.05, 0.16), Vector3(x, 2.9, 0), PlaceDetail.col(Color(0.8, 0.8, 0.78), 0.5), false)
		BuildKit.box(main, Vector3(1.1, 0.03, 0.08), Vector3(x, 2.87, 0), BuildKit.emissive_mat(Color(0.85, 0.95, 1.0), 0.0), false)
	for k in 3:
		var ep := Vector3(-6.0 + k * 6.0, 2.6, 4.85)
		BuildKit.box(main, Vector3(0.3, 0.12, 0.08), ep, BuildKit.emissive_mat(Color(1.0, 0.1, 0.05), 1.8), false)
		var el := OmniLight3D.new()
		el.light_color = Color(1.0, 0.15, 0.08)
		el.light_energy = 0.4
		el.omni_range = 5.0
		el.shadow_enabled = false
		el.position = ep + Vector3(0, -0.2, -0.3)
		main.add_child(el)
	# Wachhäuschen: Tisch, Monitore, Schlüsselbrett, Stuhl
	PlaceDetail.table(guard, Vector3(0.4, 0.06, -0.75), Vector3(1.2, 0.75, 0.5), "steel_dark")
	for k in 2:
		BuildKit.box(guard, Vector3(0.3, 0.22, 0.2), Vector3(0.15 + k * 0.4, 0.92, -0.85), dark, false)
		BuildKit.box(guard, Vector3(0.26, 0.18, 0.003), Vector3(0.15 + k * 0.4, 0.92, -0.749), BuildKit.emissive_mat(Color(0.3, 0.35, 0.3), 0.4), false)
	PlaceDetail.office_chair(guard, Vector3(0.4, 0.06, -0.1), 180.0)
	var kb := PlaceDetail.sign(guard, "SCHLÜSSEL", Vector3(-1.15, 1.5, 0.3), Vector2(0.4, 0.45), 90.0, Color(0.6, 0.45, 0.28), Color(0.95, 0.95, 0.9), 22)
	for k in 6:
		BuildKit.box(kb, Vector3(0.015, 0.06, 0.01), Vector3(-0.12 + (k % 3) * 0.12, -0.05 - (k / 3) * 0.12, 0.02), PlaceKit.mat("metal") if k != 4 else PlaceDetail.col(Color(0.7, 0.6, 0.3), 0.3, 0.8), false)
	# Draußen: Parkplatzlinien, Flutlichtmasten, Kameras, Fahnenmast, Aggregat, Container
	var white := PlaceDetail.col(Color(0.9, 0.9, 0.88), 0.7)
	for k in 6:
		BuildKit.box(root, Vector3(0.1, 0.01, 5.0), PlaceKit.on_ground(root, 12.0 + k * 2.6, 12.0, 0.03), white, false)
	for p: Vector2 in [Vector2(-30, 20), Vector2(30, 20), Vector2(-30, -20), Vector2(30, -20)]:
		var lp := PlaceKit.on_ground(root, p.x, p.y)
		BuildKit.cylinder(root, 0.1, 7.0, lp + Vector3(0, 3.5, 0), PlaceKit.mat("metal"), true, Vector3.ZERO, 0.07, 8)
		PlaceDetail.lamp(root, lp + Vector3(0, 6.9, 0), "flood", false, rad_to_deg(atan2(-p.x, -p.y)))
	for k in 6:
		var a := TAU * k / 6.0
		var cp := PlaceKit.on_ground(root, clampf(cos(a) * 40.0, -36.0, 36.0), clampf(sin(a) * 30.0, -26.0, 26.0), 2.5)
		BuildKit.box(root, Vector3(0.12, 0.12, 0.3), cp, PlaceDetail.col(Color(0.85, 0.85, 0.82), 0.5), false, Vector3(-20, rad_to_deg(atan2(-cp.x, -cp.z)), 0))
	var fp := PlaceKit.on_ground(root, 0.0, 18.0)
	BuildKit.cylinder(root, 0.06, 8.0, fp + Vector3(0, 4.0, 0), PlaceKit.mat("metal"), true, Vector3.ZERO, 0.04, 8)
	var flag := BuildKit.box(root, Vector3(1.4, 0.9, 0.01), fp + Vector3(0.72, 7.4, 0), PlaceDetail.col(Color(0.15, 0.25, 0.4), 0.9), false, Vector3(0, 0, -3))
	PlaceDetail.sign(flag, "ReZort", Vector3(0, 0, 0.008), Vector2(1.1, 0.4), 0.0, Color(0.15, 0.25, 0.4), Color(0.95, 0.95, 0.9), 44, false)
	var gp := PlaceKit.on_ground(root, -28.0, 8.0)
	BuildKit.box(root, Vector3(3.0, 1.6, 1.4), gp + Vector3(0, 0.8, 0), PlaceDetail.col(Color(0.25, 0.32, 0.25), 0.6, 0.3), true)
	for k in 10:
		BuildKit.box(root, Vector3(0.02, 0.8, 0.015), gp + Vector3(-1.2 + k * 0.25, 0.9, 0.71), dark, false)
	for k in 2:
		var cont := Node3D.new()
		cont.position = PlaceKit.on_ground(root, -26.0 + k * 3.0, -18.0)
		cont.rotation_degrees.y = 90.0
		root.add_child(cont)
		BuildKit.box(cont, Vector3(6.0, 2.5, 2.4), Vector3(0, 1.25, 0), PlaceDetail.col([Color(0.55, 0.15, 0.1), Color(0.15, 0.3, 0.45)][k], 0.6, 0.3), true)
		PlaceDetail.corrugated(cont, Vector2(6.0, 2.5), Vector3(0, 1.25, 1.22), Vector3.ZERO, "rust" if k == 0 else "corrugated")
	PlaceDetail.sign(sh, "⚠ Absturzgefahr\nZutritt nur mit Karte", Vector3(1.6, 1.8, 3.08), Vector2(0.45, 0.3), 0.0, Color(0.95, 0.8, 0.1), Color(0.05, 0.05, 0.05), 24)
	PlaceDetail.litter(root, Vector3.ZERO, 30.0, 407, 140, ["leaf", "leaf", "paper", "twig"], func(x: float, z: float) -> float: return PlaceKit.ground(root, x, z) + 0.02)


## Lebendige Orte: Ilse ist DA – warmes Licht hinter zugezogenen Vorhängen, Rauch aus dem Kamin; Verandageländer, Bank,
## Holzstoß an der Wand, Stiefel, Laterne, Briefkasten, Antennenkabel, Schild „Lusenschutzhaus 1373 m“, Wetterfahne.
static func _ilse_details(root: Node3D, h: Node3D, shed: Node3D) -> void:
	var wood := PlaceKit.mat("wood_old")
	# Licht innen + Vorhänge vor den Fenstern
	var warm := OmniLight3D.new()
	warm.light_color = Color(1.0, 0.7, 0.4)
	warm.light_energy = 1.1
	warm.omni_range = 4.5
	warm.shadow_enabled = false
	warm.position = Vector3(0.5, 1.6, -0.5)
	h.add_child(warm)
	var curtain := PlaceDetail.col(Color(0.65, 0.2, 0.15), 0.9)
	curtain.emission_enabled = true
	curtain.emission = Color(0.5, 0.25, 0.1)
	curtain.emission_energy_multiplier = 0.35
	for w: Node3D in [h.get_node_or_null("Front"), h.get_node_or_null("Back"), h.get_node_or_null("Left"), h.get_node_or_null("Right")]:
		if w == null:
			continue
		for win in w.get_children():
			if win is Node3D and win.get_child_count() > 6 and win.name != "DoorLeaf":
				BuildKit.box(win, Vector3(0.84, 0.82, 0.01), Vector3(0, 0.41, -0.08), curtain, false)
	# Kamin mit Rauch
	BuildKit.box(h, Vector3(0.5, 1.4, 0.5), Vector3(1.4, 3.0, -0.8), PlaceKit.mat("stone"), false)
	var smoke := CPUParticles3D.new()
	smoke.position = Vector3(1.4, 3.8, -0.8)
	smoke.amount = 24
	smoke.lifetime = 6.0
	smoke.direction = Vector3(0.2, 1, 0)
	smoke.spread = 12.0
	smoke.initial_velocity_min = 0.4
	smoke.initial_velocity_max = 0.8
	smoke.gravity = Vector3(0.15, 0.05, 0)
	smoke.scale_amount_min = 0.6
	smoke.scale_amount_max = 1.4
	var sm := SphereMesh.new()
	sm.radius = 0.35
	sm.height = 0.7
	var smat := StandardMaterial3D.new()
	smat.albedo_color = Color(0.6, 0.6, 0.62, 0.25)
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.material = smat
	smoke.mesh = sm
	h.add_child(smoke)
	# Verandageländer, Bank, Holzstoß, Stiefel, Laterne
	for k in 6:
		BuildKit.box(h, Vector3(0.08, 0.9, 0.08), Vector3(-2.6 + k * 1.04, 0.5, 3.85), wood, false)
	BuildKit.box(h, Vector3(5.3, 0.08, 0.08), Vector3(0, 0.95, 3.85), wood, false)
	var bench := Node3D.new()
	bench.position = Vector3(-1.6, 0.08, 2.4)
	bench.rotation_degrees.y = 180.0
	h.add_child(bench)
	PlaceDetail.pew(bench, Vector3.ZERO, 1.3, "wood_old")
	for row in 6:
		for k in 8:
			BuildKit.cylinder(h, 0.08, 0.4, Vector3(-2.75, 0.12 + row * 0.15, -1.5 + k * 0.18 + (row % 2) * 0.09), PlaceKit.mat("bark"), false, Vector3(0, 0, 90), -1.0, 7)
	BuildKit.box(h, Vector3(0.45, 0.03, 1.7), Vector3(-2.75, 1.05, -0.85), PlaceKit.mat("tin"), false)
	for sx: float in [-0.08, 0.08]:
		BuildKit.box(h, Vector3(0.1, 0.25, 0.26), Vector3(0.9 + sx, 0.2, 2.3), PlaceDetail.col(Color(0.15, 0.12, 0.1), 0.8), false)
	PlaceDetail.lamp(h, Vector3(-0.8, 2.0, 2.08), "wall", true, 0.0, Color(1.0, 0.75, 0.45), 0.6, 4.0)
	# Briefkasten, Schild, Wetterfahne, Antennenkabel
	var mb := PlaceKit.on_ground(root, 2.5, 5.5)
	BuildKit.box(root, Vector3(0.08, 1.1, 0.08), mb + Vector3(0, 0.55, 0), wood, true)
	BuildKit.box(root, Vector3(0.35, 0.25, 0.25), mb + Vector3(0, 1.2, 0), PlaceDetail.col(Color(0.85, 0.65, 0.1), 0.5, 0.3), false)
	PlaceDetail.sign(root, "I. Rankl", mb + Vector3(0, 1.2, 0.13), Vector2(0.2, 0.06), 0.0, Color(0.95, 0.95, 0.9), Color(0.1, 0.1, 0.1), 20, false)
	PlaceDetail.sign(h, "LUSENSCHUTZHAUS · 1373 m", Vector3(0, 2.55, 2.12), Vector2(1.6, 0.25), 0.0, Color(0.55, 0.4, 0.25), Color(0.95, 0.9, 0.75), 30, false)
	var vane := Node3D.new()
	vane.position = Vector3(-1.8, 3.9, 0)
	vane.rotation_degrees.y = 35.0
	h.add_child(vane)
	BuildKit.box(vane, Vector3(0.03, 0.6, 0.03), Vector3(0, -0.2, 0), PlaceKit.mat("metal"), false)
	BuildKit.box(vane, Vector3(0.5, 0.18, 0.01), Vector3(0.15, 0.1, 0), PlaceKit.mat("dark"), false)
	PlaceDetail.cable(h, Vector3(-2.2, 6.0, -1.6), Vector3(-2.5, 1.6, -1.2), 0.0, 0.01)
	PlaceDetail.litter(root, Vector3(0, 0, 3.0), 6.0, 1373, 40, ["leaf", "twig", "stone"], func(x: float, z: float) -> float: return PlaceKit.ground(root, x, z) + 0.02)


## Lebendige Orte: Bauzaun mit Planen, Baustellenschilder, Lüftungsschlauch unter der Tunneldecke, Kabel an der Wand,
## Notausgang-Schilder, Lore auf den Schienen, Betonmischer, Bewehrungsstahl, Schubkarre, Helm; Container innen.
static func _tunnel_details(root: Node3D, tube: Node3D, length: float, office: Node3D) -> void:
	# Lüftungsschlauch (gelb) und Kabelstrang
	var duct := PlaceDetail.col(Color(0.85, 0.7, 0.15), 0.8)
	var pts := PackedVector3Array()
	for k in 12:
		pts.append(Vector3(-2.0 + k * (length - 4.0) / 11.0, 4.9 - sin(k * 0.9) * 0.08, -2.0))
	HandKit.tube(tube, pts, 0.38, duct, 12)
	for k in 8:
		BuildKit.box(tube, Vector3(0.02, 0.6, 0.02), Vector3(2.0 + k * 5.5, 5.25, -2.0), PlaceKit.mat("metal"), false)
	for k in 3:
		PlaceDetail.cable(tube, Vector3(-1.0, 3.2 - k * 0.12, 2.68), Vector3(length - 4.0, 3.2 - k * 0.12, 2.68), 0.0, 0.02, [Color(0.05, 0.05, 0.05), Color(0.6, 0.3, 0.1), Color(0.1, 0.2, 0.5)][k] as Color)
	for k in 4:
		PlaceDetail.sign(tube, "NOTAUSGANG ←", Vector3(6.0 + k * 10.0, 2.4, 2.66), Vector2(0.45, 0.16), 180.0, Color(0.1, 0.55, 0.25), Color(0.95, 0.95, 0.95), 26, false)
	# Lore auf den Schienen
	var cart := Node3D.new()
	cart.position = Vector3(18.0, 0.2, 0)
	tube.add_child(cart)
	BuildKit.lathe(cart, PackedVector2Array([Vector2(0, 0), Vector2(0.55, 0), Vector2(0.7, 0.7), Vector2(0.66, 0.7), Vector2(0.52, 0.04), Vector2(0, 0.04)]), Vector3(0, 0.35, 0), PlaceKit.mat("rust"), 4).scale = Vector3(1.2, 1, 0.9)
	for sx: float in [-0.5, 0.5]:
		for sz: float in [-0.7, 0.7]:
			BuildKit.cylinder(cart, 0.15, 0.06, Vector3(sx, 0.15, sz), PlaceKit.mat("dark"), false, Vector3(90, 0, 0), -1.0, 10)
	for k in 6:
		BuildKit.sphere(cart, 0.18, Vector3(-0.3 + (k % 3) * 0.3, 0.95, -0.2 + (k / 3) * 0.4), PlaceKit.mat("rock"), Vector3(1.2, 0.8, 1.0), 6)
	# Vor dem Portal: Bauzaun mit Planen, Schilder, Mischer, Bewehrungsstahl, Schubkarre, Helm
	for k in 6:
		var bp := PlaceKit.on_ground(root, 14.0, -9.0 + k * 3.6)
		if absf(-9.0 + k * 3.6) < 3.0:
			continue
		for sx: float in [-1.6, 1.6]:
			BuildKit.box(root, Vector3(0.5, 0.15, 0.25), bp + Vector3(0, 0.07, sx), PlaceKit.mat("concrete"), false)
		BuildKit.box(root, Vector3(0.03, 2.0, 3.4), bp + Vector3(0, 1.15, 0), PlaceKit.chainlink_mat(), true)
		if k % 2 == 0:
			BuildKit.box(root, Vector3(0.01, 1.8, 3.3), bp + Vector3(-0.03, 1.15, 0), PlaceDetail.col(Color(0.15, 0.3, 0.2), 0.9), false)
	PlaceDetail.sign(root, "BAUSTELLE\nZutritt verboten\nEltern haften für ihre Kinder", PlaceKit.on_ground(root, 13.9, 5.0, 1.4), Vector2(0.7, 0.45), -90.0, Color(0.95, 0.8, 0.1), Color(0.05, 0.05, 0.05), 28)
	var mix := Node3D.new()
	mix.position = PlaceKit.on_ground(root, 8.0, 5.0)
	mix.rotation_degrees.y = 30.0
	root.add_child(mix)
	BuildKit.lathe(mix, PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.35, 0.0), Vector2(0.55, 0.35), Vector2(0.5, 0.7), Vector2(0.25, 0.9), Vector2(0.2, 0.9), Vector2(0.0, 0.85)]), Vector3(0, 0.7, 0), PlaceDetail.col(Color(0.85, 0.4, 0.1), 0.5, 0.3), 14).rotation_degrees.x = 40.0
	for sx: float in [-0.4, 0.4]:
		BuildKit.box(mix, Vector3(0.06, 0.8, 0.06), Vector3(sx, 0.4, 0), PlaceKit.mat("metal"), false)
		BuildKit.cylinder(mix, 0.2, 0.08, Vector3(sx * 1.2, 0.2, -0.3), PlaceKit.mat("dark"), false, Vector3(0, 0, 90), -1.0, 10)
	for k in 12:
		BuildKit.cylinder(root, 0.012, 6.0, PlaceKit.on_ground(root, 6.0, -4.0 + k * 0.04, 0.05 + (k % 3) * 0.025), PlaceKit.mat("rust"), false, Vector3(0, 0, 90), -1.0, 5)
	BuildKit.sphere(root, 0.15, PlaceKit.on_ground(root, 10.0, -1.0, 0.1), PlaceDetail.col(Color(0.95, 0.95, 0.92), 0.5), Vector3(1.0, 0.7, 1.15), 10)
	PlaceDetail.bucket(root, PlaceKit.on_ground(root, 9.0, -3.0), "metal", true)
	# Container innen: Stuhl, Bauplan an der Wand, Helme, Kaffeebecher
	PlaceDetail.chair(office, Vector3(-1.5, 0.06, 0.0), 180.0, "furn")
	PlaceDetail.sign(office, "TUNNEL OST – BAUABSCHNITT 3\nVortrieb: 46 m – EINGESTELLT\nMaßnahme 11 umsetzen!", Vector3(0.6, 1.5, -1.24), Vector2(1.0, 0.55), 0.0, Color(0.92, 0.94, 0.96), Color(0.1, 0.15, 0.35), 24)
	for k in 2:
		BuildKit.sphere(office, 0.14, Vector3(2.4 - k * 0.35, 1.6, 1.2), PlaceDetail.col(Color(0.95, 0.95, 0.92), 0.5), Vector3(1.0, 0.75, 1.1), 10)
	PlaceDetail.clutter(office, Vector3(-1.2, 0.79, -0.5), Vector2(0.4, 0.2), 4646, 1, ["papers"])
	PlaceDetail.litter(root, Vector3(8.0, 0, 0), 14.0, 4647, 70, ["stone", "leaf", "twig", "paper"], func(x: float, z: float) -> float: return PlaceKit.ground(root, x, z) + 0.02)


## Lebendige Orte: Wetterhütte (weißer Lamellenkasten), Regenmesser, Schneepegel, Solarpaneel, Abspannseile am Mast,
## Gipfelkreuz des Rachel mit Bank; Station innen mit Barograph, Funkgerät, Pritsche, Karte, Thermometer.
static func _wetterstation_details(root: Node3D, h: Node3D) -> void:
	var white := PlaceDetail.col(Color(0.93, 0.93, 0.9), 0.6)
	var sc := Node3D.new()
	sc.name = "Screen"
	sc.position = PlaceKit.on_ground(root, 6.0, 4.0)
	root.add_child(sc)
	for sx: float in [-0.35, 0.35]:
		for sz: float in [-0.3, 0.3]:
			BuildKit.box(sc, Vector3(0.06, 1.2, 0.06), Vector3(sx, 0.6, sz), white, false)
	BuildKit.box(sc, Vector3(0.8, 0.7, 0.7), Vector3(0, 1.55, 0), white, true)
	for k in 6:
		BuildKit.box(sc, Vector3(0.82, 0.02, 0.06), Vector3(0, 1.3 + k * 0.1, 0.36), white, false, Vector3(40, 0, 0))
	BuildKit.box(sc, Vector3(0.9, 0.05, 0.8), Vector3(0, 1.93, 0), white, false, Vector3(-6, 0, 0))
	var rg := PlaceKit.on_ground(root, 4.0, 2.0)
	BuildKit.box(root, Vector3(0.08, 1.0, 0.08), rg + Vector3(0, 0.5, 0), PlaceKit.mat("metal"), false)
	BuildKit.cylinder(root, 0.1, 0.35, rg + Vector3(0, 1.15, 0), PlaceKit.mat("metal"), false, Vector3.ZERO, 0.08, 12)
	var sp := PlaceKit.on_ground(root, 8.0, 0.0)
	BuildKit.box(root, Vector3(0.1, 3.0, 0.1), sp + Vector3(0, 1.5, 0), PlaceDetail.col(Color(0.9, 0.3, 0.1), 0.6), false)
	for k in 15:
		BuildKit.box(root, Vector3(0.11, 0.02, 0.11), sp + Vector3(0, 0.2 + k * 0.2, 0), PlaceDetail.col(Color(0.05, 0.05, 0.05)), false)
	var pv := PlaceKit.on_ground(root, 0.5, 3.0)
	BuildKit.box(root, Vector3(0.08, 1.2, 0.08), pv + Vector3(0, 0.6, 0), PlaceKit.mat("metal"), false)
	BuildKit.box(root, Vector3(1.2, 0.04, 0.8), pv + Vector3(0, 1.25, 0), PlaceDetail.col(Color(0.08, 0.1, 0.2), 0.2, 0.5), false, Vector3(-35, 0, 0))
	var mp := PlaceKit.on_ground(root, 3.0, 5.0)
	for k in 3:
		var a := TAU * k / 3.0
		var anchor := PlaceKit.on_ground(root, 3.0 + cos(a) * 4.0, 5.0 + sin(a) * 4.0)
		PlaceDetail.cable(root, mp + Vector3(0, 7.0, 0), anchor + Vector3(0, 0.1, 0), 0.0, 0.006)
		BuildKit.box(root, Vector3(0.3, 0.15, 0.3), anchor, PlaceKit.mat("concrete"), false)
	# Gipfelkreuz mit Bank
	var gk := PlaceKit.on_ground(root, -10.0, 8.0)
	BuildKit.box(root, Vector3(1.4, 0.8, 1.4), gk + Vector3(0, 0.3, 0), PlaceKit.mat("stone"), true)
	BuildKit.box(root, Vector3(0.22, 5.0, 0.22), gk + Vector3(0, 3.0, 0), PlaceKit.mat("wood_old"), true)
	BuildKit.box(root, Vector3(2.4, 0.22, 0.2), gk + Vector3(0, 4.3, 0), PlaceKit.mat("wood_old"), false)
	BuildKit.box(root, Vector3(0.4, 0.3, 0.2), gk + Vector3(0, 1.5, 0.2), PlaceKit.mat("tin"), false)
	PlaceDetail.sign(root, "RACHEL\n1453 m", gk + Vector3(0, 2.1, 0.12), Vector2(0.5, 0.3), 0.0, Color(0.55, 0.4, 0.25), Color(0.95, 0.9, 0.75), 30, false)
	var bench := Node3D.new()
	bench.position = gk + Vector3(0, 0, 2.5)
	bench.rotation_degrees.y = 180.0
	root.add_child(bench)
	PlaceDetail.pew(bench, Vector3.ZERO, 1.6, "wood_old")
	# Station innen (Hütte um 90° gedreht, Tisch an der Rückwand)
	var dark := PlaceDetail.col(Color(0.12, 0.12, 0.12), 0.5)
	var baro := Node3D.new()
	baro.position = Vector3(-0.6, 0.81, -1.55)
	h.add_child(baro)
	BuildKit.box(baro, Vector3(0.35, 0.18, 0.2), Vector3(0, 0.09, 0), PlaceKit.mat("furn"), false)
	BuildKit.cylinder(baro, 0.06, 0.12, Vector3(-0.08, 0.2, 0), PlaceDetail.col(Color(0.95, 0.95, 0.9), 0.5), false, Vector3.ZERO, -1.0, 12)
	BuildKit.box(baro, Vector3(0.3, 0.22, 0.2), Vector3(0, 0.12, 0), PlaceKit.mat("glass"), false)
	BuildKit.box(h, Vector3(0.4, 0.22, 0.25), Vector3(0.0, 0.92, -1.55), dark, false)
	PlaceDetail.chair(h, Vector3(0.3, 0.06, -0.8), 180.0, "furn")
	BuildKit.box(h, Vector3(0.8, 0.4, 1.9), Vector3(1.9, 0.26, 0.6), PlaceKit.mat("furn"), true)
	BuildKit.box(h, Vector3(0.75, 0.1, 1.85), Vector3(1.9, 0.5, 0.6), PlaceKit.mat("cloth"), false)
	PlaceDetail.sign(h, "BAYERISCHER WALD\nRachel · Lusen · Grenzkamm", Vector3(-2.4, 1.5, 0.0), Vector2(1.0, 0.7), 90.0, Color(0.85, 0.88, 0.78), Color(0.15, 0.25, 0.15), 26)
	BuildKit.box(h, Vector3(0.06, 0.4, 0.02), Vector3(0.9, 1.5, -1.9), white, false)
	BuildKit.box(h, Vector3(0.015, 0.3, 0.01), Vector3(0.9, 1.45, -1.885), PlaceKit.mat("red"), false)
	PlaceDetail.lamp(h, Vector3(0, 2.4, 0), "hanging", false)
	PlaceDetail.litter(root, Vector3(0, 0, 0), 10.0, 1453, 50, ["stone", "stone", "twig"], func(x: float, z: float) -> float: return PlaceKit.ground(root, x, z) + 0.02)


## Lebendige Orte: Pflanztische mit Töpfen, Bewässerungsrohre unter dem Dach, Heizungsrohre, Glasscherben, Erdsäcke,
## Wasserbehälter, Schild „ReZort AgroBio – Versuchsanbau“, Büro mit Messtabelle und Probenkühlschrank.
static func _gewaechshaus_details(root: Node3D, office: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 334
	var pot := PlaceDetail.col(Color(0.6, 0.3, 0.18), 0.8)
	for gh in 3:
		var house := root.get_node_or_null("Greenhouse_%d" % gh) as Node3D
		if house == null:
			continue
		for sx: float in [-1.0, 1.0]:
			for k in 4:
				var tp := Vector3(sx * 3.4, 0, -10.5 + k * 7.0)
				PlaceDetail.table(house, tp, Vector3(1.0, 0.8, 4.0), "wood_old")
				for p in 6:
					var pp := tp + Vector3(rng.randf_range(-0.3, 0.3), 0.8, -1.6 + p * 0.64)
					BuildKit.lathe(house, PackedVector2Array([Vector2(0, 0), Vector2(0.07, 0), Vector2(0.1, 0.16), Vector2(0, 0.16)]), pp, pot, 8)
					if rng.randf() < 0.4:
						BuildKit.cylinder(house, 0.01, 0.3, pp + Vector3(0, 0.3, 0), PlaceKit.mat("alien"), false, Vector3(rng.randf_range(-20, 20), 0, rng.randf_range(-20, 20)), 0.004, 4)
			HandKit.tube(house, PackedVector3Array([Vector3(sx * 2.0, 2.9, -15.0), Vector3(sx * 2.0, 2.9, 15.0)]), 0.025, PlaceDetail.col(Color(0.15, 0.15, 0.15), 0.6), 6)
			HandKit.tube(house, PackedVector3Array([Vector3(sx * 4.3, 0.2, -15.0), Vector3(sx * 4.3, 0.2, 15.0)]), 0.05, PlaceKit.mat("rust"), 8)
		for k in 16:
			BuildKit.box(house, Vector3(rng.randf_range(0.1, 0.35), 0.005, rng.randf_range(0.1, 0.3)), Vector3(rng.randf_range(-4.8, 4.8), 0.01, rng.randf_range(-15, 15)), PlaceKit.mat("glass"), false, Vector3(0, rng.randf() * 360.0, 0))
		for k in 3:
			BuildKit.box(house, Vector3(0.5, 0.25, 0.8), Vector3(-1.0 + k * 0.6, 0.12, 13.5), PlaceKit.mat("sackcloth"), false, Vector3(0, k * 20.0, 0))
	var tank := PlaceKit.on_ground(root, -27.0, -10.0)
	BuildKit.cylinder(root, 1.2, 2.4, tank + Vector3(0, 1.2, 0), PlaceDetail.col(Color(0.2, 0.35, 0.3), 0.6, 0.2), true, Vector3.ZERO, -1.0, 16)
	PlaceDetail.sign(root, "ReZort AgroBio\nVersuchsanbau MP4-G\nZutritt nur mit Schutzkleidung", PlaceKit.on_ground(root, 0, -18.0, 1.5), Vector2(0.9, 0.5), 0.0, Color(0.92, 0.95, 0.9), Color(0.15, 0.4, 0.2), 28)
	BuildKit.box(root, Vector3(0.08, 1.4, 0.08), PlaceKit.on_ground(root, -0.4, -18.0, 0.7), PlaceKit.mat("metal"), true)
	BuildKit.box(root, Vector3(0.08, 1.4, 0.08), PlaceKit.on_ground(root, 0.4, -18.0, 0.7), PlaceKit.mat("metal"), true)
	PlaceDetail.sign(office, "WACHSTUM (cm/Tag)\nKW44: 0,8  KW45: 2,1\nKW46: 6,4 (!!)  KW47: —", Vector3(0.6, 1.5, -1.45), Vector2(0.8, 0.5), 0.0, Color(0.95, 0.95, 0.93), Color(0.1, 0.1, 0.2), 24)
	BuildKit.box(office, Vector3(0.6, 1.5, 0.6), Vector3(2.1, 0.81, -1.1), PlaceDetail.col(Color(0.9, 0.9, 0.9), 0.4), true)
	BuildKit.box(office, Vector3(0.02, 0.4, 0.04), Vector3(1.79, 1.1, -0.9), PlaceKit.mat("metal"), false)
	PlaceDetail.chair(office, Vector3(-1.2, 0.06, -0.2), 180.0, "furn")
	PlaceDetail.litter(root, Vector3(0, 0, 0), 22.0, 335, 90, ["leaf", "leaf", "twig", "paper"], func(x: float, z: float) -> float: return PlaceKit.ground(root, x, z) + 0.02)


## Lebendige Orte: Trümmerfeld um den „Wal“ – aufgerissene Hautplatten, geknickte Bäume, verbrannter Boden, leuchtende
## Lachen, Adern in den Boden; Spuren von ReZort-Leuten: Lampenstativ, Probenkisten, Absperrband, umgefallenes Zelt.
static func _wal_details(root: Node3D, hull: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5656
	var skin := BuildKit.tex_mat("alien_skin", 3.0, Color(0.42, 0.4, 0.46), 0.35)
	var burnt := PlaceDetail.col(Color(0.05, 0.045, 0.04), 1.0)
	for k in 14:
		var a := rng.randf() * TAU
		var r := rng.randf_range(10.0, 34.0)
		var p := PlaceKit.on_ground(root, cos(a) * r, sin(a) * r, 0.05)
		BuildKit.box(root, Vector3(rng.randf_range(0.8, 2.4), 0.08, rng.randf_range(0.6, 1.6)), p + Vector3(0, 0.1, 0), skin, false, Vector3(rng.randf_range(-25, 25), rng.randf() * 360.0, rng.randf_range(-25, 25)))
	for k in 10:
		var a := rng.randf() * TAU
		var r := rng.randf_range(4.0, 26.0)
		BuildKit.cylinder(root, rng.randf_range(1.0, 2.6), 0.02, PlaceKit.on_ground(root, cos(a) * r, sin(a) * r, 0.02), burnt, false, Vector3.ZERO, -1.0, 12)
	for k in 8:
		var a := rng.randf() * TAU
		var p := PlaceKit.on_ground(root, cos(a) * rng.randf_range(16.0, 30.0), sin(a) * rng.randf_range(16.0, 30.0))
		var h := rng.randf_range(1.5, 4.0)
		BuildKit.cylinder(root, 0.25, h, p + Vector3(0, h * 0.5, 0), PlaceKit.mat("bark"), true, Vector3.ZERO, 0.22, 8)
		BuildKit.cylinder(root, 0.22, rng.randf_range(6, 12), p + Vector3(cos(a) * 3.0, h, sin(a) * 3.0), PlaceKit.mat("bark"), false, Vector3(0, -rad_to_deg(a), 80), 0.12, 8)
	var glow := BuildKit.emissive_mat(Color(0.55, 0.35, 1.0), 1.2)
	for k in 5:
		var a := rng.randf() * TAU
		BuildKit.cylinder(root, rng.randf_range(0.4, 1.0), 0.01, PlaceKit.on_ground(root, cos(a) * rng.randf_range(6, 18), sin(a) * rng.randf_range(6, 18), 0.03), glow, false, Vector3.ZERO, -1.0, 12)
	var vein := PlaceDetail.col(Color(0.25, 0.2, 0.3), 0.5)
	for k in 7:
		var a := TAU * k / 7.0 + 0.3
		var pts := PackedVector3Array()
		for s in 6:
			var r := 6.0 + s * 3.5
			pts.append(PlaceKit.on_ground(root, cos(a + sin(s) * 0.15) * r, sin(a + sin(s) * 0.15) * r, 0.06))
		HandKit.tube(root, pts, 0.09, vein, 6)
	# Spuren der Untersucher
	var lp := PlaceKit.on_ground(root, 14.0, 10.0)
	for k in 3:
		var a := TAU * k / 3.0
		BuildKit.beam_between(root, lp + Vector3(0, 2.2, 0), lp + Vector3(cos(a) * 0.7, 0, sin(a) * 0.7), 0.025, PlaceKit.mat("metal"))
	PlaceDetail.lamp(root, lp + Vector3(0, 2.25, 0), "flood", false, 200.0)
	for k in 3:
		var cp := PlaceKit.on_ground(root, 12.0 + k * 0.7, 12.5)
		BuildKit.box(root, Vector3(0.6, 0.35, 0.4), cp + Vector3(0, 0.18, 0), PlaceDetail.col(Color(0.85, 0.85, 0.82), 0.5), false, Vector3(0, k * 15.0, 0))
		PlaceDetail.sign(root, "RZ · PROBE", cp + Vector3(0, 0.25, 0.21), Vector2(0.3, 0.08), k * 15.0, Color(0.85, 0.85, 0.82), Color(0.7, 0.1, 0.08), 20, false)
	var t := Node3D.new()
	t.position = PlaceKit.on_ground(root, 18.0, 15.0)
	t.rotation_degrees = Vector3(0, 30, 70)
	root.add_child(t)
	BuildKit.box(t, Vector3(2.0, 0.04, 2.6), Vector3(0, 0.8, 0), PlaceDetail.col(Color(0.85, 0.5, 0.1), 0.9), false, Vector3(0, 0, 45))
	for k in 6:
		var a := TAU * k / 6.0
		var p1 := PlaceKit.on_ground(root, cos(a) * 36.0, sin(a) * 36.0, 0.9)
		var p2 := PlaceKit.on_ground(root, cos(a + TAU / 6.0) * 36.0, sin(a + TAU / 6.0) * 36.0, 0.9)
		BuildKit.box(root, Vector3(0.05, 1.0, 0.05), p1 - Vector3(0, 0.45, 0), PlaceKit.mat("metal"), false)
		if k % 2 == 0:
			PlaceDetail.cable(root, p1, p2, 0.6, 0.012, Color(0.9, 0.1, 0.08))


## Lebendige Orte: Zapfsäulen mit Schläuchen und Preisanzeige, Preistafel, Mülleimer, Luftdruckstation, Picknicktische,
## Laternen, Telefonzelle, Container; Laden mit Regalen voller Waren, Kasse, Kühlregal, Kaffeeautomat, Zeitungsständer;
## Sattelzug mit Rädern, Spiegeln, Scheiben.
static func _raststation_details(root: Node3D, canopy: Vector3, shop: Node3D, truck: Node3D) -> void:
	var dark := PlaceDetail.col(Color(0.08, 0.08, 0.08), 0.5)
	for k in 2:
		var pp := canopy + Vector3(-2.5 + k * 5.0, 0, 0)
		BuildKit.box(root, Vector3(1.2, 0.25, 0.9), pp + Vector3(0, 0.12, 0), PlaceKit.mat("concrete"), false)
		BuildKit.box(root, Vector3(0.45, 0.25, 0.005), pp + Vector3(0, 1.32, 0.262), BuildKit.emissive_mat(Color(0.2, 0.6, 0.3), 0.0), false)
		for sx: float in [-1.0, 1.0]:
			HandKit.tube(root, PackedVector3Array([pp + Vector3(sx * 0.42, 1.2, 0.0), pp + Vector3(sx * 0.55, 0.6, 0.15), pp + Vector3(sx * 0.48, 0.9, 0.3)]), 0.02, dark, 6)
			BuildKit.box(root, Vector3(0.06, 0.18, 0.12), pp + Vector3(sx * 0.42, 1.0, 0.27), dark, false)
	var pb := canopy + Vector3(8.5, 0, 6.0)
	BuildKit.box(root, Vector3(0.2, 5.0, 0.2), pb + Vector3(0, 2.5, 0), PlaceKit.mat("white"), true)
	PlaceDetail.sign(root, "WALDBLICK\nDiesel  1,79\nSuper E10  1,85\nSuper  1,92", pb + Vector3(0, 4.0, 0.12), Vector2(1.4, 1.6), 0.0, Color(0.85, 0.15, 0.12), Color(0.98, 0.98, 0.95), 26)
	for k in 3:
		var bp := canopy + Vector3(-5.5 + k * 5.5, 0, -4.6)
		BuildKit.cylinder(root, 0.25, 0.8, bp + Vector3(0, 0.4, 0), PlaceDetail.col(Color(0.2, 0.3, 0.25), 0.6, 0.3), true, Vector3.ZERO, -1.0, 12)
	var air := canopy + Vector3(7.5, 0, -3.0)
	BuildKit.box(root, Vector3(0.4, 1.4, 0.35), air + Vector3(0, 0.7, 0), PlaceDetail.col(Color(0.15, 0.35, 0.7), 0.5, 0.3), true)
	HandKit.tube(root, PackedVector3Array([air + Vector3(0.2, 1.0, 0.0), air + Vector3(0.5, 0.3, 0.2), air + Vector3(0.3, 0.6, 0.4)]), 0.012, dark, 5)
	for k in 2:
		var tp := PlaceKit.on_ground(root, -18.0 + k * 4.0, 6.0)
		PlaceDetail.table(root, tp, Vector3(1.8, 0.75, 0.7), "wood_old")
		for sz: float in [-0.65, 0.65]:
			BuildKit.box(root, Vector3(1.8, 0.05, 0.3), tp + Vector3(0, 0.45, sz), PlaceKit.mat("wood_old"), true)
	for k in 4:
		var lp := PlaceKit.on_ground(root, -22.0 + k * 10.0, -4.0)
		BuildKit.cylinder(root, 0.07, 6.0, lp + Vector3(0, 3.0, 0), PlaceKit.mat("metal"), true, Vector3.ZERO, 0.05, 8)
		PlaceDetail.lamp(root, lp + Vector3(0, 5.9, 0), "flood", false, 0.0)
	var ph := PlaceKit.on_ground(root, 3.0, 4.0)
	var booth := Node3D.new()
	booth.position = ph
	root.add_child(booth)
	BuildKit.box(booth, Vector3(1.0, 2.3, 1.0), Vector3(0, 1.15, 0), PlaceKit.mat("glass"), false)
	BuildKit.box(booth, Vector3(1.05, 0.25, 1.05), Vector3(0, 2.35, 0), PlaceDetail.col(Color(0.95, 0.8, 0.1), 0.5), true)
	for sx: float in [-0.5, 0.5]:
		for sz: float in [-0.5, 0.5]:
			BuildKit.box(booth, Vector3(0.05, 2.3, 0.05), Vector3(sx, 1.15, sz), PlaceDetail.col(Color(0.95, 0.8, 0.1), 0.5), true)
	BuildKit.box(booth, Vector3(0.25, 0.4, 0.12), Vector3(0, 1.4, -0.42), dark, false)
	var dump := PlaceKit.on_ground(root, 20.0, -6.0)
	BuildKit.box(root, Vector3(2.0, 1.3, 1.2), dump + Vector3(0, 0.65, 0), PlaceDetail.col(Color(0.15, 0.3, 0.2), 0.6, 0.3), true)
	# Laden innen
	for k in 3:
		PlaceDetail.clutter(shop, Vector3(-1.5, 1.6, -2.0 + k * 1.8), Vector2(3.8, 0.4), 700 + k, 10, ["cans", "bottles", "boxes", "jars"])
		PlaceDetail.clutter(shop, Vector3(-1.5, 0.9, -2.0 + k * 1.8), Vector2(3.8, 0.4), 710 + k, 8, ["boxes", "cans"])
	BuildKit.box(shop, Vector3(0.35, 0.25, 0.3), Vector3(3.3, 1.12, 2.0), dark, false)
	BuildKit.box(shop, Vector3(0.3, 0.18, 0.004), Vector3(3.3, 1.2, 1.84), BuildKit.emissive_mat(Color(0.2, 0.5, 0.3), 0.3), false)
	var fridge := BuildKit.emissive_mat(Color(0.75, 0.9, 1.0), 0.4)
	BuildKit.box(shop, Vector3(3.0, 2.0, 0.7), Vector3(1.0, 1.0, -3.6), PlaceDetail.col(Color(0.85, 0.85, 0.85), 0.4), true)
	BuildKit.box(shop, Vector3(2.9, 1.8, 0.01), Vector3(1.0, 1.0, -3.24), fridge, false)
	BuildKit.box(shop, Vector3(0.6, 1.7, 0.5), Vector3(5.4, 0.85, 3.4), PlaceDetail.col(Color(0.2, 0.15, 0.1), 0.5), true)
	BuildKit.box(shop, Vector3(0.4, 0.3, 0.01), Vector3(5.4, 1.3, 3.14), BuildKit.emissive_mat(Color(0.9, 0.6, 0.3), 0.3), false)
	BuildKit.box(shop, Vector3(0.6, 1.2, 0.4), Vector3(2.2, 0.6, 3.5), PlaceKit.mat("metal"), false)
	PlaceDetail.clutter(shop, Vector3(2.2, 1.2, 3.5), Vector2(0.5, 0.3), 720, 2, ["papers"])
	PlaceDetail.litter(shop, Vector3(0, 0.06, 0), 4.0, 721, 25, ["paper", "leaf"])
	# Sattelzug: Räder, Spiegel, Scheiben
	for sx: float in [-1.0, 1.0]:
		for x: float in [-5.0, -3.8, 4.5, 8.8]:
			BuildKit.cylinder(truck, 0.5, 0.35, Vector3(x, 0.5, sx * 1.1), PlaceKit.mat("dark"), false, Vector3(90, 0, 0), -1.0, 14)
		BuildKit.box(truck, Vector3(0.05, 0.4, 0.2), Vector3(9.2, 2.6, sx * 1.4), dark, false)
	BuildKit.box(truck, Vector3(0.04, 1.2, 2.3), Vector3(9.71, 2.6, 0), PlaceKit.mat("glass"), false)
	PlaceDetail.litter(root, Vector3(0, 0, 0), 24.0, 722, 90, ["leaf", "paper", "twig"], func(x: float, z: float) -> float: return PlaceKit.ground(root, x, z) + 0.02)


## Lebendige Orte: Zollhaus innen mit Schreibtisch, Stempeln, Schreibmaschine, Kanonenofen, Fahnen, altem Plakat; draußen
## Kontrollhäuschen, Wegweiser mit Entfernungen, Bank, Telefonkasten, rostige Laterne.
static func _grenze_details(root: Node3D, h: Node3D) -> void:
	var dark := PlaceDetail.col(Color(0.1, 0.1, 0.1), 0.5)
	var tw := Node3D.new()
	tw.position = Vector3(-1.2, 0.81, -1.4)
	h.add_child(tw)
	BuildKit.box(tw, Vector3(0.4, 0.12, 0.3), Vector3(0, 0.06, 0), dark, false, Vector3(-8, 0, 0))
	BuildKit.box(tw, Vector3(0.36, 0.02, 0.12), Vector3(0, 0.14, 0.08), PlaceDetail.col(Color(0.2, 0.2, 0.2)), false)
	BuildKit.box(tw, Vector3(0.22, 0.003, 0.3), Vector3(0, 0.2, -0.12), PlaceKit.mat("paper"), false, Vector3(-70, 0, 0))
	for k in 3:
		BuildKit.cylinder(h, 0.02, 0.08, Vector3(-0.4 + k * 0.06, 0.85, -1.15), PlaceDetail.col(Color(0.5, 0.25, 0.1), 0.6), false, Vector3.ZERO, -1.0, 8)
	PlaceDetail.chair(h, Vector3(-1.4, 0.06, -0.6), 180.0, "furn")
	var stove := Node3D.new()
	stove.position = Vector3(2.3, 0.06, -1.3)
	h.add_child(stove)
	BuildKit.cylinder(stove, 0.25, 0.7, Vector3(0, 0.45, 0), dark, true, Vector3.ZERO, 0.2, 12)
	BuildKit.cylinder(stove, 0.07, 2.2, Vector3(0, 1.9, 0), dark, false, Vector3.ZERO, -1.0, 8)
	for k in 3:
		BuildKit.cylinder(stove, 0.03, 0.1, Vector3(cos(k * 2.1) * 0.18, 0.05, sin(k * 2.1) * 0.18), dark, false, Vector3.ZERO, -1.0, 6)
	PlaceDetail.sign(h, "ZOLLAMT BUČINA\nGrenzübertritt nur mit\ngültigem Reisepass – 1987", Vector3(0.5, 1.6, -1.93), Vector2(0.7, 0.5), 0.0, Color(0.85, 0.8, 0.65), Color(0.2, 0.1, 0.05), 24)
	for k in 2:
		var fl := BuildKit.box(h, Vector3(0.4, 0.26, 0.01), Vector3(-2.2 + k * 0.5, 1.9, -1.92), _flag_mat(["blue", "red"][k]), false, Vector3(0, 0, -10))
		BuildKit.cylinder(h, 0.01, 0.6, Vector3(-2.4 + k * 0.5, 1.9, -1.9), dark, false, Vector3(0, 0, -10), -1.0, 4)
	PlaceDetail.lamp(h, Vector3(0, 2.4, 0), "hanging", false)
	PlaceDetail.cobweb(h, Vector3(-2.9, 2.5, -1.9), Vector3(1, 0, 0), Vector3(0, 0, 1), 0.4)
	# Kontrollhäuschen auf der Straßenmitte
	var kh := PlaceKit.on_ground(root, 0.5, -3.0)
	var booth := Node3D.new()
	booth.position = kh
	root.add_child(booth)
	BuildKit.box(booth, Vector3(1.4, 0.2, 1.4), Vector3(0, 0.1, 0), PlaceKit.mat("concrete"), true)
	BuildKit.box(booth, Vector3(1.2, 2.2, 1.2), Vector3(0, 1.3, 0), PlaceDetail.col(Color(0.85, 0.85, 0.8), 0.6), true)
	for side in 4:
		var n := Node3D.new()
		n.rotation_degrees.y = side * 90.0
		booth.add_child(n)
		BuildKit.box(n, Vector3(0.8, 0.6, 0.01), Vector3(0, 1.6, 0.605), PlaceKit.mat("glass"), false)
	BuildKit.box(booth, Vector3(1.4, 0.12, 1.4), Vector3(0, 2.45, 0), PlaceKit.mat("rust"), false)
	# Wegweiser, Bank, Telefonkasten, Laterne
	var wp := PlaceKit.on_ground(root, -4.0, 0.0)
	BuildKit.box(root, Vector3(0.1, 2.2, 0.1), wp + Vector3(0, 1.1, 0), PlaceKit.mat("metal"), true)
	PlaceDetail.sign(root, "Železná Ruda 31 km", wp + Vector3(0.4, 2.0, 0), Vector2(0.8, 0.15), 0.0, Color(0.95, 0.95, 0.92), Color(0.1, 0.1, 0.1), 26, false)
	PlaceDetail.sign(root, "Mauth 9 km", wp + Vector3(-0.4, 1.75, 0), Vector2(0.8, 0.15), 180.0, Color(0.95, 0.85, 0.2), Color(0.1, 0.1, 0.1), 26, false)
	var bench := Node3D.new()
	bench.position = PlaceKit.on_ground(root, -9.0, 6.6)
	bench.rotation_degrees.y = 180.0
	root.add_child(bench)
	PlaceDetail.pew(bench, Vector3.ZERO, 1.4, "wood_old")
	BuildKit.box(h, Vector3(0.25, 0.35, 0.15), Vector3(2.2, 1.4, 2.1), PlaceDetail.col(Color(0.85, 0.65, 0.1), 0.5, 0.3), false)
	var lp := PlaceKit.on_ground(root, 3.0, 2.0)
	BuildKit.cylinder(root, 0.05, 4.0, lp + Vector3(0, 2.0, 0), PlaceKit.mat("rust"), true, Vector3.ZERO, 0.04, 8)
	PlaceDetail.lamp(root, lp + Vector3(0, 3.9, 0), "wall", false, 180.0)
	PlaceDetail.litter(root, Vector3(0, 0, 0), 16.0, 1990, 70, ["leaf", "twig", "stone"], func(x: float, z: float) -> float: return PlaceKit.ground(root, x, z) + 0.02)
