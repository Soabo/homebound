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
	# Abdeckung aus Brettern, zugenagelt
	for k in 5:
		BuildKit.box(root, Vector3(1.6, 0.04, 0.3), Vector3(0, y + 0.83, -0.6 + k * 0.3), wood, false, Vector3(0, randf_range(-4, 4), 0))
	# Dach mit Kurbel
	for sx: float in [-1.0, 1.0]:
		BuildKit.box(root, Vector3(0.1, 1.6, 0.1), Vector3(sx * 0.85, y + 1.6, 0), wood, true)
	BuildKit.cylinder(root, 0.06, 1.8, Vector3(0, y + 1.9, 0), wood, false, Vector3(0, 0, 90), -1.0, 8)
	BuildKit.box(root, Vector3(0.05, 0.3, 0.05), Vector3(0.98, y + 1.78, 0.0), PlaceKit.mat("rust"), false)
	for sx: float in [-1.0, 1.0]:
		BuildKit.box(root, Vector3(1.0, 0.04, 2.0), Vector3(sx * 0.45, y + 2.55, 0), PlaceKit.mat("shingles"), false, Vector3(0, 0, -sx * 32.0))
	var ins := PlaceKit.inspect(root, "WellInspect", "[E] Alten Brunnen ansehen",
			"Mit Brettern zugenagelt. Durch die Ritzen kommt kalte Luft herauf – und ein ganz leises Summen.", Vector3(0, y, 0), Vector3(1.8, 1.0, 1.8))
	ins.done_flag = "visit_brunnen"
	PlaceKit.note(root, "brunnen_hinweis", Vector3(0.0, y + 0.55, 0.86), true)


## Waldkapelle: Steinkapelle mit Bänken. Auf den Bänken liegen Steine – jeden Tag einer mehr.
static func _kapelle(root: Node3D) -> void:
	root.rotation_degrees.y = 40.0
	var h := PlaceKit.hut(root, "Chapel", Vector3(0, PlaceKit.ground(root, 0, 0), 0), Vector2(4.6, 7.2), 3.0, 0.0, "stone", "gable", "shingles", 1.2, true)
	# Dachreiter mit Kreuz
	BuildKit.box(h, Vector3(0.7, 0.9, 0.7), Vector3(0, 4.8, 2.6), PlaceKit.mat("wood_old"), false)
	BuildKit.cylinder(h, 0.55, 0.9, Vector3(0, 5.7, 2.6), PlaceKit.mat("shingles"), false, Vector3.ZERO, 0.0, 4)
	BuildKit.box(h, Vector3(0.05, 0.6, 0.05), Vector3(0, 6.4, 2.6), PlaceKit.mat("rust"), false)
	BuildKit.box(h, Vector3(0.3, 0.05, 0.05), Vector3(0, 6.5, 2.6), PlaceKit.mat("rust"), false)
	# Bänke
	var bench_mat := PlaceKit.mat("wood_old")
	var benches: Array[Vector3] = []
	for row in 3:
		for sx: float in [-1.0, 1.0]:
			var p := Vector3(sx * 1.15, 0, 1.6 - row * 1.3)
			benches.append(p)
			BuildKit.box(h, Vector3(1.6, 0.06, 0.4), p + Vector3(0, 0.45, 0), bench_mat, true)
			BuildKit.box(h, Vector3(1.6, 0.4, 0.05), p + Vector3(0, 0.75, -0.2), bench_mat, false)
			for lx: float in [-0.7, 0.7]:
				BuildKit.box(h, Vector3(0.06, 0.45, 0.35), p + Vector3(lx, 0.22, 0), bench_mat, false)
	# Altar mit Kreuz, Kerzen, Gästebuch
	BuildKit.box(h, Vector3(1.6, 0.95, 0.7), Vector3(0, 0.475, -2.9), PlaceKit.mat("stone"), true)
	BuildKit.box(h, Vector3(1.7, 0.05, 0.75), Vector3(0, 0.97, -2.9), BuildKit.color_mat(Color(0.85, 0.82, 0.75)), false)
	BuildKit.box(h, Vector3(0.08, 1.2, 0.06), Vector3(0, 1.9, -3.45), PlaceKit.mat("wood"), false)
	BuildKit.box(h, Vector3(0.6, 0.08, 0.06), Vector3(0, 2.2, -3.45), PlaceKit.mat("wood"), false)
	PlaceKit.loot(h, "Candles", "candles", 4, Vector3(0.45, 1.0, -2.8), "candles")
	PlaceKit.loot(h, "Matches", "matches", 1, Vector3(-0.5, 1.0, -2.75), "box")
	PlaceKit.note(h, "kapelle_buch", Vector3(0.0, 0.97, -2.75))
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
			var off := -0.6 + (i / benches.size()) * 0.4
			BuildKit.sphere(stones, rng.randf_range(0.05, 0.08), b + Vector3(off, 0.52, rng.randf_range(-0.08, 0.08)), PlaceKit.mat("stone_dark"), Vector3(1.2, 0.7, 1.0), 6)
	place.call()
	TimeManager.day_changed.connect(func(_d: int) -> void: place.call())


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
	BuildKit.box(h, Vector3(0.25, 0.32, 0.01), Vector3(0.4, 1.3, 2.08), PlaceKit.mat("paper"), false)
	var sign := Label3D.new()
	sign.text = "IMKEREI BRANDL\nHonig vom Waldrand"
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
