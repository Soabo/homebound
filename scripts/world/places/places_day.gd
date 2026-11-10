class_name PlacesDay
extends RefCounted
## Orte für einen Tagesmarsch: Messstelle 4-Nord, Funkmast, Schwarzer See, Steinbruch, Kontrollpunkt,
## Ferienlager, Schäferkarren, Hochmoor, Windwurf-Schneise, Lichtung der Spiegel.



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


## Messstelle 4-Nord: eingezäunter Container von ReZort Industries, Kabel führen in einen Schacht.
static func _messstelle(root: Node3D) -> void:
	root.rotation_degrees.y = 10.0
	PlaceKit.fence(root, [Vector2(-8, -6), Vector2(8, -6), Vector2(8, 6), Vector2(-8, 6), Vector2(-8, -6)], 2.2, [Vector2(50.0, 53.5)])
	var c := PlaceKit.hut(root, "Container", Vector3(0, PlaceKit.ground(root, 0, 0) + 0.25, -1.0), Vector2(6.0, 2.6), 2.5, 0.0, "tin", "flat", "tin", 0.9, true)
	label(c, "ReZort Industries\nMessstelle 4-Nord\nBetreten verboten", Vector3(-1.8, 1.6, 1.38), 36, Color(0.75, 0.1, 0.08))
	BuildKit.box(c, Vector3(1.6, 0.04, 0.7), Vector3(1.4, 0.8, -0.8), PlaceKit.mat("steel_dark"), true)
	for sx: float in [-0.7, 0.7]:
		BuildKit.box(c, Vector3(0.04, 0.8, 0.6), Vector3(1.4 + sx, 0.4, -0.8), PlaceKit.mat("steel_dark"), false)
	PlaceKit.loot(c, "Electronics", "electronics", 3, Vector3(-1.8, 0.06, -0.8), "case")
	PlaceKit.loot(c, "Batteries", "battery", 2, Vector3(-1.0, 0.06, -0.85), "case")
	PlaceKit.loot(c, "Keycard", "keycard_m4", 1, Vector3(1.1, 0.83, -0.7), "card")
	PlaceKit.loot(c, "Protocols", "rz_protocol", 1, Vector3(0.75, 0.83, -0.75), "paper")
	PlaceKit.blueprint(c, "bp_winch", "Kabelwinde", Vector3(1.7, 0.83, -0.85))
	PlaceKit.note(c, "messstelle_log", Vector3(2.2, 1.4, -1.22), true)
	BuildKit.box(c, Vector3(0.24, 0.32, 0.01), Vector3(2.2, 1.4, -1.24), PlaceKit.mat("paper"), false)
	# Mast mit Schüssel
	var g := PlaceKit.ground(root, 5.5, 3.5)
	BuildKit.cylinder(root, 0.07, 7.0, Vector3(5.5, g + 3.5, 3.5), PlaceKit.mat("metal"), true, Vector3.ZERO, 0.05, 8)
	BuildKit.cylinder(root, 0.55, 0.12, Vector3(5.5, g + 6.4, 3.0), PlaceKit.mat("white"), false, Vector3(70, 0, 0), 0.1, 14)
	# Schachtdeckel mit Kabeln
	var m := PlaceKit.on_ground(root, -4.5, 3.5)
	BuildKit.cylinder(root, 0.6, 0.1, m + Vector3(0, 0.05, 0), PlaceKit.mat("steel_dark"), true, Vector3.ZERO, -1.0, 14)
	for k in 3:
		BuildKit.cylinder(root, 0.05, 4.2, m + Vector3(1.9, 0.07, -1.6 + k * 0.12), PlaceKit.mat("dark"), false, Vector3(0, 40, 88), -1.0, 6)
	PlaceKit.inspect(root, "Shaft", "[E] Schachtdeckel ansehen", "Verschweißt. Die Kabel verschwinden durch eine Dichtung in die Tiefe. Wenn man das Ohr an den Deckel legt: ein tiefes, gleichmäßiges Brummen.", m, Vector3(1.3, 0.3, 1.3))


## Funkmast auf dem Kahlen Kopf: Gittermast, Technikhäuschen ohne Strom. Reparieren = Funkkontakt.
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


## Schwarzer See: Bootshaus mit Steg, ein Auto halb im Wasser, darin ein Firmenausweis.
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
	water.label = "Schwarzer See"
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


## Steinbruch: tiefe Grube, Bagger, Bürocontainer am Rand, verschlossenes Sprengstofflager in der Wand.
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


## Kontrollpunkt an der Straße: Schranke, Armeezelte, Sandsäcke, umgekippter LKW. Niemand mehr da.
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


## Hochmoor: Holzstege über den Schlamm, Tümpel, Torfstich. Am Rand eines Tümpels liegt jemand.
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
	BuildKit.box(root, Vector3(1.0, 0.6, 0.04), sp + Vector3(0, 1.45, 0.05), BuildKit.color_mat(Color(0.2, 0.4, 0.2)), false)
	label(root, "NATURSCHUTZGEBIET\nStege nicht verlassen!", sp + Vector3(0, 1.45, 0.08), 30, Color(0.95, 0.95, 0.85))
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


## Windwurf-Schneise: Hunderte Bäume liegen strahlenförmig um einen kleinen Krater – weg von einem Punkt.
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
