class_name HandItems
extends RefCounted
## Modelle für alles, was der Spieler in der Hand hält (und dieselben Dinge, wenn sie in der Welt liegen).
##
## build(parent, modell) liefert einen Knoten. Ursprung = Mitte der Stelle, an der die Hand zufasst;
## +y zeigt nach oben, -z nach vorn (vom Spieler weg). Angaben für die Hand stehen als Meta am Knoten:
##   grip   Radius, um den sich die Finger legen        tight  wie fest (1 = ganz herum)
##   tilt   Neigung des Gegenstands in der Hand (Grad)  up     Versatz nach oben in der Hand
##   parts  bewegliche Teile für die Animationen        base   Unterkante (zum Hinstellen in der Welt)
## Welches Modell ein Gegenstand bekommt, steht in data/items/items.json ("hand_model", sonst "hand").

static var _tex: Dictionary = {}


static func model_of(item_id: String) -> String:
	var d := DataDB.item(item_id)
	return String(d.get("hand_model", d.get("hand", "fist")))


static func build(parent: Node, model: String) -> Node3D:
	var n := Node3D.new()
	n.name = "Item"
	parent.add_child(n)
	n.set_meta("grip", 0.02)
	n.set_meta("parts", {})
	match model:
		"axe": _axe(n)
		"tin_snips": _snips(n)
		"water", "bottle": _bottle(n, "clean")
		"bottle_raw": _bottle(n, "raw")
		"bottle_tainted": _bottle(n, "tainted")
		"food", "can": _can(n)
		"mug_soup": _mug(n, "soup")
		"mug_stew": _mug(n, "stew")
		"mug_potato": _mug(n, "potato")
		"honey": _honey(n)
		"ration": _ration(n)
		"radish": _radish(n)
		"carrot": _carrot(n)
		"potato": _potato(n)
		"meat_raw": _meat(n, false)
		"meat_cooked": _meat(n, true)
		"alien_fruit": _alien_fruit(n)
		"dictaphone": _dictaphone(n)
		"watering_can": _watering_can(n)
		"hammer": _hammer(n)
		_: n.set_meta("grip", 0.0)
	return n


## Stellt ein Modell in die Welt: Unterkante auf pos, um die Hochachse gedreht.
static func place(parent: Node, model: String, pos: Vector3, yaw_deg: float = 0.0, lying: bool = false) -> Node3D:
	var holder := Node3D.new()
	parent.add_child(holder)
	holder.position = pos
	holder.rotation_degrees.y = yaw_deg
	var it := build(holder, model)
	var base: Vector3 = it.get_meta("base", Vector3.ZERO)
	if lying:
		it.rotation_degrees.x = -90.0
		it.position = Vector3(0, float(it.get_meta("lie", 0.012)), 0)
	else:
		it.position = -base
	return holder


static func _steel(tint: float = 1.3, rough: float = 0.4) -> StandardMaterial3D:
	return BuildKit.tex_mat("metal", 0.15, Color(tint, tint, tint * 1.02), rough)


# --- Axt ---------------------------------------------------------------------

static func _axe(n: Node3D) -> void:
	var wood := BuildKit.tex_mat("planks_v", 0.16, Color(1.25, 1.0, 0.72), 0.7)
	var red := BuildKit.color_mat(Color(0.62, 0.1, 0.07), 0.6)
	var forged := BuildKit.tex_mat("metal", 0.12, Color(0.95, 0.97, 1.04), 0.45)
	var bright := BuildKit.tex_mat("metal", 0.1, Color(2.1, 2.1, 2.15), 0.22)
	# geschwungener Stiel mit Knauf, ovaler Querschnitt (schmal quer, breit in Schlagrichtung)
	var up := Vector3(0, 0, -1)
	HandKit.loft(n, PackedVector3Array([Vector3(0, -0.150, -0.016), Vector3(0, -0.138, -0.014), Vector3(0, -0.105, -0.006)]),
			PackedVector2Array([Vector2(0.011, 0.016), Vector2(0.0165, 0.025), Vector2(0.0135, 0.0195)]), red, 8, up)
	HandKit.loft(n, PackedVector3Array([Vector3(0, -0.105, -0.006), Vector3(0, -0.05, -0.001), Vector3(0, 0.0, 0.0), Vector3(0, 0.12, 0.006),
			Vector3(0, 0.26, 0.006), Vector3(0, 0.38, 0.001), Vector3(0, 0.50, 0.0)]),
			PackedVector2Array([Vector2(0.0135, 0.0195), Vector2(0.0128, 0.018), Vector2(0.0125, 0.0172), Vector2(0.012, 0.017),
			Vector2(0.012, 0.0178), Vector2(0.0125, 0.0195), Vector2(0.012, 0.021)]), wood, 8, up)
	# Kopf: Umriss von der Seite (x = nach vorn, y = Höhe), zur Schneide hin keilförmig dünn
	var head := Node3D.new()
	head.position = Vector3(0, 0.455, 0)
	head.rotation_degrees.y = 90.0
	n.add_child(head)
	var outline := PackedVector2Array([Vector2(-0.046, 0.033), Vector2(-0.046, -0.033), Vector2(-0.024, -0.04), Vector2(0.022, -0.041),
			Vector2(0.06, -0.056), Vector2(0.098, -0.08), Vector2(0.124, -0.09), Vector2(0.138, -0.058), Vector2(0.145, -0.012),
			Vector2(0.142, 0.036), Vector2(0.128, 0.066), Vector2(0.085, 0.047), Vector2(0.03, 0.04), Vector2(-0.024, 0.04)])
	var half := PackedFloat32Array()
	for p in outline:
		half.append(lerpf(0.0185, 0.0012, smoothstep(0.02, 0.145, p.x)))
	HandKit.extrude(head, outline, half, forged)
	# blank geschliffene Schneide
	var edge := PackedVector2Array([Vector2(0.124, -0.09), Vector2(0.138, -0.058), Vector2(0.145, -0.012), Vector2(0.142, 0.036),
			Vector2(0.128, 0.066), Vector2(0.112, 0.059), Vector2(0.123, 0.03), Vector2(0.126, -0.012), Vector2(0.120, -0.055), Vector2(0.108, -0.084)])
	var ehalf := PackedFloat32Array()
	for p in edge:
		ehalf.append(lerpf(0.0185, 0.0012, smoothstep(0.02, 0.145, p.x)) + 0.0005)
	HandKit.extrude(head, edge, ehalf, bright)
	# Stielende mit Stahlkeil schaut oben aus dem Öhr
	BuildKit.box(n, Vector3(0.022, 0.012, 0.04), Vector3(0, 0.5, 0), wood, false)
	BuildKit.box(n, Vector3(0.004, 0.004, 0.034), Vector3(0, 0.507, 0), bright, false)
	n.set_meta("grip", 0.0155)
	n.set_meta("tilt", Vector3(-10, 28, 0))
	n.set_meta("base", Vector3(0, -0.15, 0))
	n.set_meta("center", Vector3(0, 0.18, -0.04))


# --- Blechschere -------------------------------------------------------------

static func _snips(n: Node3D) -> void:
	var steel := _steel(1.25, 0.45)
	var bright := BuildKit.tex_mat("metal", 0.1, Color(2.2, 2.2, 2.2), 0.25)
	var dark := BuildKit.color_mat(Color(0.1, 0.1, 0.11), 0.5, 0.5)
	var yellow := BuildKit.color_mat(Color(0.93, 0.68, 0.06), 0.5)
	var black := BuildKit.color_mat(Color(0.05, 0.05, 0.055), 0.85)
	var ph := Vector3(0, 0.078, 0)    # Drehpunkt der Griffe
	var pj := Vector3(0, 0.112, 0)    # Drehpunkt der Backen
	var parts := {}
	for side: float in [1.0, -1.0]:
		var key := "a" if side > 0.0 else "b"
		# Griff: Stahlschenkel mit dickem gelbem Kunststoff und schwarzer Kappe, zur Hand hin gebogen
		var h := Node3D.new()
		h.position = ph
		n.add_child(h)
		var up := Vector3(0, 0, 1)
		HandKit.loft(h, PackedVector3Array([Vector3(side * 0.004, 0.012, 0), Vector3(side * 0.012, -0.012, 0), Vector3(side * 0.021, -0.04, 0)]),
				PackedVector2Array([Vector2(0.0055, 0.004)]), steel, 6, up)
		HandKit.loft(h, PackedVector3Array([Vector3(side * 0.019, -0.034, 0), Vector3(side * 0.025, -0.07, 0), Vector3(side * 0.027, -0.105, 0),
				Vector3(side * 0.024, -0.14, 0), Vector3(side * 0.02, -0.158, 0)]),
				PackedVector2Array([Vector2(0.0075, 0.0085), Vector2(0.0085, 0.0095), Vector2(0.0085, 0.0095), Vector2(0.008, 0.009), Vector2(0.0078, 0.0088)]), yellow, 7, up)
		HandKit.loft(h, PackedVector3Array([Vector3(side * 0.02, -0.156, 0), Vector3(side * 0.019, -0.168, 0), Vector3(side * 0.0185, -0.174, 0)]),
				PackedVector2Array([Vector2(0.009, 0.01), Vector2(0.0095, 0.0105), Vector2(0.006, 0.007)]), black, 7, up)
		# Griffmulden
		for gy: float in [-0.075, -0.1, -0.125]:
			BuildKit.box(h, Vector3(0.003, 0.012, 0.0196), Vector3(side * (0.0262 - absf(gy + 0.1) * 0.06) - side * 0.0085, gy, 0), black, false)
		parts["handle_" + key] = h
		# Backe: kräftiger Stahlkeil, die beiden gleiten aneinander vorbei
		var j := Node3D.new()
		j.position = pj + Vector3(0, 0, side * 0.0032)
		n.add_child(j)
		var s := -side
		HandKit.extrude(j, PackedVector2Array([Vector2(s * -0.004, -0.03), Vector2(s * 0.014, -0.028), Vector2(s * 0.017, -0.004), Vector2(s * 0.0165, 0.02),
				Vector2(s * 0.011, 0.05), Vector2(s * 0.003, 0.074), Vector2(s * -0.002, 0.073), Vector2(s * -0.0035, 0.03), Vector2(s * -0.006, 0.0)]), 0.003, steel)
		HandKit.extrude(j, PackedVector2Array([Vector2(s * -0.0035, 0.004), Vector2(s * -0.0005, 0.004), Vector2(s * 0.0012, 0.072), Vector2(s * -0.002, 0.073)]), 0.0034, bright)
		parts["jaw_" + key] = j
	# Hebelplatten vorn und hinten, drei Bolzen, Feder, Verschlussbügel
	for pz: float in [-0.0075, 0.0075]:
		var plate := HandKit.extrude(n, PackedVector2Array([Vector2(-0.013, 0.064), Vector2(0.013, 0.064), Vector2(0.016, 0.09), Vector2(0.012, 0.122),
				Vector2(0.0, 0.128), Vector2(-0.012, 0.122), Vector2(-0.016, 0.09)]), 0.0014, dark)
		plate.position.z = pz
		for bolt: Vector3 in [Vector3(0, 0.112, 0), Vector3(-0.007, 0.078, 0), Vector3(0.007, 0.078, 0)]:
			BuildKit.cylinder(n, 0.0048, 0.003, bolt + Vector3(0, 0, pz * 1.25), bright, false, Vector3(90, 0, 0), -1.0, 6)
	var spring := HandKit.tube(n, HandKit.arc(Vector3(0, 0.046, 0), 0.012, 200, 340, 6), 0.0016, bright, 4, Vector3(0, 0, 1))
	parts["spring"] = spring
	n.set_meta("parts", parts)
	n.set_meta("grip", 0.027)
	n.set_meta("tight", 0.92)
	n.set_meta("up", 0.012)
	n.set_meta("base", Vector3(0, -0.1, 0))
	n.set_meta("center", Vector3(0, 0.04, 0))
	n.set_meta("lie", 0.01)
	snips_open(n, 1.0)


## Blechschere öffnen (1) oder zudrücken (0): Griffe und Backen drehen um ihre Bolzen.
static func snips_open(n: Node3D, amount: float) -> void:
	var p: Dictionary = n.get_meta("parts", {})
	if p.is_empty():
		return
	var a := deg_to_rad(7.5) * amount
	(p["handle_a"] as Node3D).rotation.z = a
	(p["handle_b"] as Node3D).rotation.z = -a
	(p["jaw_a"] as Node3D).rotation.z = a * 1.5
	(p["jaw_b"] as Node3D).rotation.z = -a * 1.5
	(p["spring"] as Node3D).scale.x = 0.75 + 0.5 * amount


# --- Wasserflasche -----------------------------------------------------------

static func _label_tex(kind: String) -> Texture2D:
	if _tex.has(kind):
		return _tex[kind]
	var s := Icons.SIZE
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	match kind:
		"bottle":
			img.fill(Color(0.12, 0.36, 0.72))
			Icons._rect(img, 0, 0, s, 9, Color(0.93, 0.96, 1.0))
			Icons._rect(img, 0, 55, s, s, Color(0.93, 0.96, 1.0))
			for x in s:
				var y := 44 + int(round(sin(x * TAU / 32.0) * 3.0))
				Icons._rect(img, x, y, x + 1, y + 3, Color(0.55, 0.8, 1.0))
			Icons._text(img, "WASSER", 32, 26, 1, Color(1, 1, 1))
		"tape":
			img.fill(Color(0.86, 0.8, 0.62))
			Icons._text(img, "ROH", 32, 32, 2, Color(0.15, 0.12, 0.3))
			for i in 14:
				Icons._rect(img, (i * 37) % s, (i * 23) % s, (i * 37) % s + 2, (i * 23) % s + 1, Color(0.74, 0.68, 0.52))
		"can":
			img.fill(Color(0.93, 0.87, 0.7))
			Icons._rect(img, 0, 0, s, 20, Color(0.72, 0.13, 0.08))
			Icons._rect(img, 0, 20, s, 23, Color(0.95, 0.75, 0.2))
			Icons._rect(img, 0, 52, s, s, Color(0.2, 0.42, 0.18))
			for half in 2:
				var cx := 16 + half * 32
				# Schüssel mit dampfendem Eintopf
				Icons._disc(img, cx, 36, 9.5, Color(0.55, 0.3, 0.14))
				Icons._rect(img, cx - 11, 25, cx + 12, 36, Color(0.93, 0.87, 0.7))
				Icons._rect(img, cx - 10, 35, cx + 11, 38, Color(0.75, 0.42, 0.16))
				Icons._rect(img, cx - 5, 45, cx + 6, 48, Color(0.4, 0.2, 0.1))
				Icons._rect(img, cx - 4, 27, cx - 2, 33, Color(0.78, 0.74, 0.62))
				Icons._rect(img, cx + 2, 26, cx + 4, 32, Color(0.78, 0.74, 0.62))
				Icons._text(img, "FOOD", cx, 10, 1, Color(1.0, 0.95, 0.85))
		"ration":
			img.fill(Color(0.33, 0.36, 0.22))
			Icons._rect(img, 6, 12, 58, 40, Color(0.25, 0.28, 0.17))
			Icons._text(img, "FELD", 32, 21, 1, Color(0.85, 0.83, 0.65))
			Icons._text(img, "RATION", 32, 31, 1, Color(0.85, 0.83, 0.65))
			Icons._rect(img, 0, 50, s, 53, Color(0.8, 0.72, 0.2))
		"honey":
			img.fill(Color(0.95, 0.9, 0.72))
			Icons._rect(img, 0, 0, s, 8, Color(0.75, 0.5, 0.08))
			Icons._rect(img, 0, 56, s, s, Color(0.75, 0.5, 0.08))
			for half in 2:
				var cx := 16 + half * 32
				# Wabe
				for q: Vector2 in [Vector2(-5, 0), Vector2(5, 0), Vector2(0, -8), Vector2(0, 8)]:
					Icons._disc(img, cx + q.x, 32 + q.y, 4.6, Color(0.55, 0.36, 0.05))
					Icons._disc(img, cx + q.x, 32 + q.y, 3.2, Color(0.96, 0.7, 0.12))
		"rose":
			img.fill(Color(0.62, 0.48, 0.2))
			for ring: Array in [[0.0, 1], [11.0, 6], [22.0, 11]]:
				for k in int(ring[1]):
					var a := TAU * k / int(ring[1])
					Icons._disc(img, 32 + cos(a) * float(ring[0]), 32 + sin(a) * float(ring[0]), 2.6, Color(0.1, 0.08, 0.05))
		"speaker":
			img.fill(Color(0.2, 0.2, 0.22))
			for y in range(4, s, 8):
				Icons._rect(img, 4, y, s - 4, y + 3, Color(0.05, 0.05, 0.06))
		"dial":
			img.fill(Color(0, 0, 0, 0))
	var t := ImageTexture.create_from_image(img)
	_tex[kind] = t
	return t


## Material mit einem ringsum laufenden Etikett (für BuildKit.lathe mit Einheitsprofil).
static func _label_mat(kind: String, rough: float = 0.7, repeat: float = 2.0) -> StandardMaterial3D:
	var key := "label_%s_%.1f" % [kind, repeat]
	if not _tex.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_texture = _label_tex(kind)
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
		# u läuft beim Drehkörper von außen gesehen rückwärts: spiegeln, damit die Schrift stimmt
		m.uv1_scale = Vector3(-repeat, -1, 1)
		m.uv1_offset = Vector3(0, 1, 0)
		m.roughness = rough
		_tex[key] = m
	return _tex[key]


static func _band(parent: Node, kind: String, radius: float, y0: float, y1: float, rough: float = 0.7, segments: int = 12) -> MeshInstance3D:
	var mi := BuildKit.lathe(parent, PackedVector2Array([Vector2(1.0, 0.0), Vector2(1.0, 1.0)]), Vector3(0, y0, 0), _label_mat(kind, rough), segments)
	mi.scale = Vector3(radius, y1 - y0, radius)
	return mi


static func _bottle(n: Node3D, kind: String) -> void:
	var b := Node3D.new()
	b.position = Vector3(0, -0.085, 0)
	n.add_child(b)
	var water_col := {"clean": Color(0.35, 0.62, 0.88), "raw": Color(0.52, 0.5, 0.3), "tainted": Color(0.42, 0.2, 0.55)}[kind] as Color
	var shell := HandKit.clear_mat(Color(0.8, 0.9, 1.0, 0.3))
	var water := HandKit.own_mat(water_col, 0.25)
	if kind == "tainted":
		water.emission_enabled = true
		water.emission = Color(0.5, 0.25, 0.8)
		water.emission_energy_multiplier = 0.35
	# Wasser (deckend) – wird beim Trinken von oben her weniger
	var w := BuildKit.lathe(b, PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.62, 0.0), Vector2(0.95, 0.03), Vector2(1.0, 0.09), Vector2(1.0, 0.32),
			Vector2(0.95, 0.345), Vector2(1.0, 0.37), Vector2(1.0, 0.47), Vector2(0.9, 0.59), Vector2(1.0, 0.71), Vector2(1.0, 0.93), Vector2(0.93, 1.0), Vector2(0.0, 1.0)]),
			Vector3(0, 0.003, 0), water, 12)
	w.scale = Vector3(0.0305, 0.16, 0.0305)
	# Flasche: Bodenwulst, Rillen, Taille zum Greifen, Schulter, Hals mit Gewindering
	BuildKit.lathe(b, PackedVector2Array([Vector2(0.0, 0.005), Vector2(0.02, 0.0), Vector2(0.03, 0.004), Vector2(0.0325, 0.015), Vector2(0.0325, 0.05),
			Vector2(0.031, 0.054), Vector2(0.0325, 0.058), Vector2(0.0325, 0.075), Vector2(0.0295, 0.095), Vector2(0.0325, 0.115), Vector2(0.0325, 0.152),
			Vector2(0.03, 0.166), Vector2(0.02, 0.186), Vector2(0.0142, 0.197), Vector2(0.0136, 0.212), Vector2(0.0158, 0.2135), Vector2(0.0158, 0.2165),
			Vector2(0.0132, 0.218), Vector2(0.0132, 0.226), Vector2(0.0, 0.226)]), Vector3.ZERO, shell, 12)
	if kind == "clean":
		_band(b, "bottle", 0.0329, 0.117, 0.151, 0.6)
	elif kind == "raw":
		# Kreppband mit Aufschrift statt Etikett
		_band(b, "tape", 0.0329, 0.122, 0.146, 0.9)
	# Deckel an einem Halteband: klappt beim Trinken zur Seite
	var cap_col := {"clean": Color(0.1, 0.3, 0.75), "raw": Color(0.85, 0.85, 0.82), "tainted": Color(0.16, 0.16, 0.18)}[kind] as Color
	var cap_mat := BuildKit.color_mat(cap_col, 0.5)
	var hinge := Node3D.new()
	hinge.position = Vector3(-0.0158, 0.2165, 0)
	b.add_child(hinge)
	BuildKit.cylinder(hinge, 0.0158, 0.014, Vector3(0.0158, 0.0085, 0), cap_mat, false, Vector3.ZERO, 0.015, 10)
	BuildKit.cylinder(hinge, 0.0162, 0.004, Vector3(0.0158, 0.003, 0), cap_mat, false, Vector3.ZERO, -1.0, 10)
	BuildKit.cylinder(b, 0.0161, 0.003, Vector3(0, 0.2145, 0), cap_mat, false, Vector3.ZERO, -1.0, 10)
	n.set_meta("parts", {"water": w, "cap": hinge, "water_full": 0.16})
	n.set_meta("grip", 0.0315)
	n.set_meta("tilt", Vector3(-6, 0, 0))
	n.set_meta("base", Vector3(0, -0.085, 0))
	n.set_meta("center", Vector3(0, 0.03, 0))
	n.set_meta("lie", 0.033)


# --- Konserve, Becher, Glas, Ration ------------------------------------------

## Dosenkörper mit Rillen und umlaufendem Etikett (auch für Dosen im Regal).
static func can_body(parent: Node, pos: Vector3, radius: float = 0.0375, height: float = 0.108) -> Node3D:
	var c := Node3D.new()
	c.position = pos
	parent.add_child(c)
	var tin := BuildKit.tex_mat("metal", 0.2, Color(1.3, 1.3, 1.28), 0.4)
	var r := radius
	var h := height
	BuildKit.lathe(c, PackedVector2Array([Vector2(0.0, 0.004), Vector2(r * 0.9, 0.004), Vector2(r * 0.9, 0.0), Vector2(r * 1.03, 0.0), Vector2(r * 1.03, 0.006), Vector2(r, 0.008),
			Vector2(r, 0.014), Vector2(r, h - 0.014), Vector2(r, h - 0.008), Vector2(r * 1.03, h - 0.006), Vector2(r * 1.03, h), Vector2(r * 0.9, h),
			Vector2(r * 0.9, h - 0.004)]), Vector3.ZERO, tin, 12)
	_band(c, "can", r * 1.012, 0.012, h - 0.012, 0.75)
	return c


static func _can(n: Node3D) -> void:
	var h := 0.108
	var r := 0.0375
	var c := can_body(n, Vector3(0, -h * 0.5, 0), r, h)
	var tin := BuildKit.tex_mat("metal", 0.2, Color(1.45, 1.45, 1.42), 0.3)
	# Inhalt (sichtbar, wenn der Deckel aufgezogen ist) und Deckel mit Zuglasche
	BuildKit.cylinder(c, r * 0.89, 0.002, Vector3(0, h - 0.012, 0), BuildKit.color_mat(Color(0.5, 0.26, 0.1), 0.7), false, Vector3.ZERO, -1.0, 12)
	for q: Vector3 in [Vector3(0.012, 0, 0.006), Vector3(-0.01, 0, -0.012), Vector3(-0.004, 0, 0.016), Vector3(0.016, 0, -0.012)]:
		BuildKit.sphere(c, 0.007, q + Vector3(0, h - 0.011, 0), BuildKit.color_mat(Color(0.7, 0.42, 0.14), 0.7), Vector3(1.2, 0.5, 1.0), 5)
	var lid := Node3D.new()
	lid.position = Vector3(0, h - 0.0035, r * 0.88)
	c.add_child(lid)
	BuildKit.cylinder(lid, r * 0.89, 0.0015, Vector3(0, 0, -r * 0.88), tin, false, Vector3.ZERO, -1.0, 12)
	HandKit.tube(lid, HandKit.arc(Vector3(0, 0.0022, -r * 1.3), 0.009, 0, 360, 8, Vector3.RIGHT, Vector3(0, 0, 1), 0.011), 0.0014, tin, 4, Vector3.UP)
	BuildKit.box(lid, Vector3(0.007, 0.002, 0.012), Vector3(0, 0.0015, -r * 0.98), tin, false)
	n.set_meta("parts", {"lid": lid})
	n.set_meta("grip", 0.036)
	n.set_meta("tilt", Vector3(-8, 0, 0))
	n.set_meta("up", 0.012)
	n.set_meta("base", Vector3(0, -h * 0.5, 0))


## Emaille-Becher mit Löffel: Suppe, Eintopf, Bratkartoffeln.
static func _mug(n: Node3D, kind: String) -> void:
	var h := 0.086
	var r := 0.041
	var c := Node3D.new()
	c.position = Vector3(0, -h * 0.5, 0)
	n.add_child(c)
	var enamel := BuildKit.color_mat(Color(0.9, 0.9, 0.86), 0.3)
	var rim := BuildKit.color_mat(Color(0.1, 0.14, 0.32), 0.35)
	BuildKit.lathe(c, PackedVector2Array([Vector2(0.0, 0.0), Vector2(r * 0.9, 0.0), Vector2(r * 0.96, 0.006), Vector2(r, h - 0.006)]), Vector3.ZERO, enamel, 12)
	BuildKit.lathe(c, PackedVector2Array([Vector2(r, h - 0.006), Vector2(r * 1.04, h - 0.002), Vector2(r * 1.03, h), Vector2(r * 0.93, h), Vector2(r * 0.93, h - 0.012)]), Vector3.ZERO, rim, 12)
	# abgeplatzte Stellen
	BuildKit.box(c, Vector3(0.008, 0.006, 0.002), Vector3(0.012, 0.03, r * 0.985), rim, false, Vector3(0, 0, 20))
	BuildKit.box(c, Vector3(0.005, 0.009, 0.002), Vector3(-0.018, 0.055, r * 0.96), rim, false, Vector3(0, -25, -10))
	# Henkel auf der Außenseite (weg von der Handfläche)
	HandKit.loft(c, HandKit.arc(Vector3(-r * 0.96, h * 0.5, 0), 0.024, -80, 80, 6, Vector3(-1, 0, 0), Vector3.UP, 0.028),
			PackedVector2Array([Vector2(0.007, 0.003)]), enamel, 6, Vector3(0, 0, 1))
	var col := {"soup": Color(0.85, 0.5, 0.15), "stew": Color(0.42, 0.24, 0.12), "potato": Color(0.8, 0.62, 0.25)}[kind] as Color
	BuildKit.cylinder(c, r * 0.93, 0.002, Vector3(0, h - 0.012, 0), BuildKit.color_mat(col, 0.5), false, Vector3.ZERO, -1.0, 12)
	var bits := {"soup": [Color(0.9, 0.35, 0.1), Color(0.35, 0.6, 0.2)], "stew": [Color(0.6, 0.38, 0.2), Color(0.85, 0.5, 0.15)], "potato": [Color(0.9, 0.72, 0.3), Color(0.6, 0.4, 0.15)]}[kind] as Array
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 9:
		var a := rng.randf() * TAU
		var d := rng.randf() * r * 0.7
		var big := 0.012 if kind == "potato" else 0.008
		BuildKit.box(c, Vector3(big, big * (1.0 if kind == "potato" else 0.5), big * 1.2), Vector3(cos(a) * d, h - 0.01 + (rng.randf() * 0.008 if kind == "potato" else 0.0), sin(a) * d),
				BuildKit.color_mat(bits[i % 2], 0.6), false, Vector3(rng.randf() * 40, rng.randf() * 180, rng.randf() * 40))
	# Löffel lehnt im Becher
	var spoon := Node3D.new()
	spoon.position = Vector3(0.012, h - 0.02, -0.01)
	spoon.rotation_degrees = Vector3(-22, 20, -14)
	c.add_child(spoon)
	var st := _steel(1.5, 0.3)
	BuildKit.box(spoon, Vector3(0.007, 0.1, 0.0022), Vector3(0, 0.05, 0), st, false)
	BuildKit.sphere(spoon, 0.011, Vector3(0, -0.006, 0), st, Vector3(1.0, 1.5, 0.35), 6)
	n.set_meta("grip", 0.039)
	n.set_meta("tilt", Vector3(-8, 0, 0))
	n.set_meta("up", 0.01)
	n.set_meta("base", Vector3(0, -h * 0.5, 0))


static func _honey(n: Node3D) -> void:
	var h := 0.092
	var r := 0.035
	var c := Node3D.new()
	c.position = Vector3(0, -h * 0.5, 0)
	n.add_child(c)
	var honey := HandKit.own_mat(Color(0.86, 0.52, 0.06), 0.25)
	honey.emission_enabled = true
	honey.emission = Color(0.8, 0.45, 0.05)
	honey.emission_energy_multiplier = 0.08
	BuildKit.lathe(c, PackedVector2Array([Vector2(0.0, 0.004), Vector2(r * 0.86, 0.004), Vector2(r * 0.93, 0.012), Vector2(r * 0.93, h * 0.78), Vector2(0.0, h * 0.78)]), Vector3.ZERO, honey, 12)
	BuildKit.lathe(c, PackedVector2Array([Vector2(0.0, 0.0), Vector2(r * 0.9, 0.0), Vector2(r, 0.01), Vector2(r, h * 0.8), Vector2(r * 0.86, h * 0.88), Vector2(r * 0.86, h * 0.92)]),
			Vector3.ZERO, HandKit.clear_mat(Color(1.0, 0.97, 0.9, 0.12)), 12)
	_band(c, "honey", r * 1.012, 0.02, h * 0.6, 0.8)
	var gold := BuildKit.color_mat(Color(0.8, 0.62, 0.15), 0.35, 0.7)
	BuildKit.cylinder(c, r * 0.93, 0.014, Vector3(0, h * 0.94, 0), gold, false, Vector3.ZERO, -1.0, 12)
	BuildKit.cylinder(c, r * 0.95, 0.003, Vector3(0, h * 0.885, 0), gold, false, Vector3.ZERO, -1.0, 12)
	n.set_meta("grip", 0.034)
	n.set_meta("tilt", Vector3(-8, 0, 0))
	n.set_meta("up", 0.008)
	n.set_meta("base", Vector3(0, -h * 0.5, 0))


static func _ration(n: Node3D) -> void:
	var olive := BuildKit.color_mat(Color(0.33, 0.36, 0.22), 0.7)
	var seam := BuildKit.color_mat(Color(0.24, 0.27, 0.16), 0.8)
	# Folienbeutel: bauchig in der Mitte, oben und unten flach verschweißt
	HandKit.loft(n, PackedVector3Array([Vector3(0, -0.062, 0), Vector3(0, -0.05, 0), Vector3(0, -0.02, 0), Vector3(0, 0.03, 0), Vector3(0, 0.06, 0), Vector3(0, 0.072, 0)]),
			PackedVector2Array([Vector2(0.04, 0.002), Vector2(0.04, 0.012), Vector2(0.039, 0.019), Vector2(0.039, 0.017), Vector2(0.04, 0.008), Vector2(0.04, 0.002)]), olive, 8, Vector3(0, 0, 1))
	BuildKit.box(n, Vector3(0.082, 0.012, 0.003), Vector3(0, 0.078, 0), seam, false)
	BuildKit.box(n, Vector3(0.082, 0.01, 0.003), Vector3(0, -0.066, 0), seam, false)
	# Aufdruck vorn (zur Kamera)
	var m := StandardMaterial3D.new()
	m.albedo_texture = _label_tex("ration")
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	m.roughness = 0.7
	var q := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(0.066, 0.066)
	q.mesh = qm
	q.material_override = m
	q.position = Vector3(0, 0.012, 0.0185)
	n.add_child(q)
	n.set_meta("grip", 0.021)
	n.set_meta("tight", 0.9)
	n.set_meta("up", 0.03)
	n.set_meta("tilt", Vector3(-10, 12, 0))
	n.set_meta("base", Vector3(0, -0.07, 0))
	n.set_meta("lie", 0.02)


# --- Gemüse, Fleisch, Fremdfrucht ---------------------------------------------

static func _leaves(parent: Node3D, at: Vector3, count: int, length: float, col: Color) -> void:
	var mat := BuildKit.color_mat(col, 0.8)
	var stem := BuildKit.color_mat(col.lightened(0.25), 0.8)
	for i in count:
		var l := Node3D.new()
		l.position = at
		l.rotation_degrees = Vector3(-22.0 - (i % 3) * 9.0, i * 360.0 / count + 15.0, 0)
		parent.add_child(l)
		var len := length * (0.8 + 0.2 * ((i * 7) % 3) / 2.0)
		BuildKit.box(l, Vector3(0.003, len * 0.5, 0.003), Vector3(0, len * 0.25, 0), stem, false)
		HandKit.loft(l, PackedVector3Array([Vector3(0, len * 0.4, 0), Vector3(0, len * 0.7, 0), Vector3(0, len, 0)]),
				PackedVector2Array([Vector2(0.004, 0.0012), Vector2(0.015, 0.0015), Vector2(0.003, 0.001)]), mat, 5, Vector3(0, 0, 1))


static func _radish(n: Node3D) -> void:
	var red := BuildKit.color_mat(Color(0.82, 0.12, 0.26), 0.45)
	var white := BuildKit.color_mat(Color(0.95, 0.9, 0.88), 0.6)
	# Bund aus drei Radieschen am Grün gehalten
	for i in 3:
		var a := i * TAU / 3.0
		var at := Vector3(cos(a) * 0.016, 0.03 + i * 0.004, sin(a) * 0.016)
		BuildKit.lathe(n, PackedVector2Array([Vector2(0.0, -0.022), Vector2(0.004, -0.012), Vector2(0.015, 0.0), Vector2(0.019, 0.012), Vector2(0.015, 0.026), Vector2(0.005, 0.031), Vector2(0.0, 0.031)]), at, red, 8)
		BuildKit.cylinder(n, 0.0025, 0.022, at + Vector3(0, -0.026, 0), white, false, Vector3(i * 9.0 - 9.0, 0, 0), 0.0005, 5)
		_leaves(n, at + Vector3(0, 0.03, 0), 3, 0.085, Color(0.24, 0.5, 0.16))
	n.set_meta("grip", 0.017)
	n.set_meta("tight", 0.9)
	n.set_meta("up", 0.03)
	n.set_meta("tilt", Vector3(-10, 0, 0))
	n.set_meta("base", Vector3(0, 0.0, 0))


static func _carrot(n: Node3D) -> void:
	var orange := BuildKit.color_mat(Color(0.93, 0.47, 0.08), 0.6)
	var ring := BuildKit.color_mat(Color(0.7, 0.32, 0.05), 0.7)
	BuildKit.lathe(n, PackedVector2Array([Vector2(0.0, -0.075), Vector2(0.004, -0.068), Vector2(0.009, -0.03), Vector2(0.013, 0.02), Vector2(0.016, 0.06), Vector2(0.0145, 0.072), Vector2(0.006, 0.076), Vector2(0.0, 0.076)]),
			Vector3.ZERO, orange, 8)
	for y: float in [-0.04, -0.012, 0.018, 0.045]:
		BuildKit.cylinder(n, 0.0115 + y * 0.07, 0.0012, Vector3(0, y, 0), ring, false, Vector3(4, 0, 3), -1.0, 8)
	_leaves(n, Vector3(0, 0.074, 0), 5, 0.1, Color(0.22, 0.5, 0.14))
	n.set_meta("grip", 0.012)
	n.set_meta("up", 0.02)
	n.set_meta("tilt", Vector3(-12, 0, 0))
	n.set_meta("base", Vector3(0, -0.075, 0))
	n.set_meta("lie", 0.016)


static func _potato(n: Node3D) -> void:
	var skin := BuildKit.color_mat(Color(0.62, 0.47, 0.28), 0.9)
	var eye := BuildKit.color_mat(Color(0.4, 0.29, 0.17), 0.95)
	var p := BuildKit.sphere(n, 0.03, Vector3.ZERO, skin, Vector3(0.95, 1.4, 0.85), 8)
	p.rotation_degrees = Vector3(0, 0, 8)
	BuildKit.sphere(n, 0.018, Vector3(0.008, 0.028, 0.004), skin, Vector3(1.0, 1.0, 0.9), 6)
	for q: Vector3 in [Vector3(0.012, 0.03, 0.022), Vector3(-0.014, 0.012, 0.021), Vector3(0.004, 0.046, 0.012), Vector3(-0.02, 0.034, -0.012)]:
		BuildKit.sphere(n, 0.0035, q, eye, Vector3(1, 1, 0.5), 4)
	n.set_meta("grip", 0.026)
	n.set_meta("tight", 0.95)
	n.set_meta("up", 0.036)
	n.set_meta("base", Vector3(0, -0.04, 0))


static func _meat(n: Node3D, cooked: bool) -> void:
	var bone := BuildKit.color_mat(Color(0.9, 0.86, 0.76), 0.6)
	var meat := BuildKit.color_mat(Color(0.5, 0.27, 0.12) if cooked else Color(0.78, 0.3, 0.3), 0.55 if cooked else 0.35)
	var mark := BuildKit.color_mat(Color(0.22, 0.11, 0.05) if cooked else Color(0.92, 0.78, 0.74), 0.7)
	# Keule: Knochen in der Faust, Fleisch oben
	BuildKit.cylinder(n, 0.0065, 0.1, Vector3(0, -0.01, 0), bone, false, Vector3.ZERO, 0.0055, 6)
	BuildKit.sphere(n, 0.0095, Vector3(0.004, -0.062, 0), bone, Vector3.ONE, 5)
	BuildKit.sphere(n, 0.0095, Vector3(-0.004, -0.062, 0), bone, Vector3.ONE, 5)
	BuildKit.lathe(n, PackedVector2Array([Vector2(0.008, 0.03), Vector2(0.02, 0.04), Vector2(0.031, 0.065), Vector2(0.033, 0.09), Vector2(0.026, 0.112), Vector2(0.012, 0.124), Vector2(0.0, 0.126)]), Vector3.ZERO, meat, 8)
	for i in 3:
		BuildKit.box(n, Vector3(0.05, 0.004, 0.003), Vector3(0, 0.062 + i * 0.019, 0.0285 - absf(i - 1) * 0.004), mark, false, Vector3(0, 0, 18))
	n.set_meta("grip", 0.011)
	n.set_meta("up", 0.012)
	n.set_meta("tilt", Vector3(-14, 0, 0))
	n.set_meta("base", Vector3(0, -0.07, 0))
	n.set_meta("lie", 0.03)


static func _alien_fruit(n: Node3D) -> void:
	var skin := BuildKit.tex_mat("alien_skin", 0.06, Color(0.75, 0.6, 1.1), 0.35)
	var glow := BuildKit.emissive_mat(Color(0.45, 1.0, 0.8), 1.6)
	BuildKit.lathe(n, PackedVector2Array([Vector2(0.0, -0.036), Vector2(0.016, -0.03), Vector2(0.031, -0.01), Vector2(0.034, 0.01), Vector2(0.026, 0.03), Vector2(0.012, 0.04), Vector2(0.004, 0.052), Vector2(0.0, 0.054)]), Vector3.ZERO, skin, 9)
	# leuchtende Adern und Poren
	for i in 5:
		var a := i * TAU / 5.0
		HandKit.tube(n, PackedVector3Array([Vector3(cos(a) * 0.012, 0.042, sin(a) * 0.012), Vector3(cos(a + 0.2) * 0.029, 0.026, sin(a + 0.2) * 0.029),
				Vector3(cos(a + 0.5) * 0.0345, 0.004, sin(a + 0.5) * 0.0345), Vector3(cos(a + 0.7) * 0.027, -0.02, sin(a + 0.7) * 0.027)]), 0.0014, glow, 4)
	BuildKit.sphere(n, 0.004, Vector3(0, 0.055, 0), glow, Vector3.ONE, 5)
	n.set_meta("grip", 0.031)
	n.set_meta("tight", 0.9)
	n.set_meta("up", 0.024)
	n.set_meta("base", Vector3(0, -0.036, 0))


# --- Diktiergerät ------------------------------------------------------------

static func _dictaphone(n: Node3D) -> void:
	var body := BuildKit.color_mat(Color(0.13, 0.13, 0.15), 0.45, 0.2)
	var silver := BuildKit.color_mat(Color(0.6, 0.61, 0.65), 0.32, 0.65)
	var glass := BuildKit.color_mat(Color(0.03, 0.04, 0.05), 0.1, 0.3)
	var w := 0.06
	var h := 0.116
	var t := 0.024
	# Gehäuse mit abgeschrägten Kanten (Schlauch mit flachem Querschnitt), silberne Frontblende
	HandKit.loft(n, PackedVector3Array([Vector3(0, -h * 0.5, 0), Vector3(0, -h * 0.5 + 0.004, 0), Vector3(0, h * 0.5 - 0.004, 0), Vector3(0, h * 0.5, 0)]),
			PackedVector2Array([Vector2(w * 0.46, t * 0.4), Vector2(w * 0.54, t * 0.54), Vector2(w * 0.54, t * 0.54), Vector2(w * 0.46, t * 0.4)]), body, 8, Vector3(0, 0, 1))
	BuildKit.box(n, Vector3(w * 0.84, h * 0.9, 0.002), Vector3(0, 0, t * 0.5 + 0.0004), silver, false)
	# Kassettenfenster mit zwei Spulen
	BuildKit.box(n, Vector3(w * 0.7, 0.03, 0.002), Vector3(0, 0.022, t * 0.5 + 0.0012), glass, false)
	var parts := {}
	var white := BuildKit.color_mat(Color(0.88, 0.88, 0.85), 0.5)
	for i in 2:
		var reel := Node3D.new()
		reel.position = Vector3(-0.0105 + i * 0.021, 0.022, t * 0.5 + 0.0024)
		n.add_child(reel)
		BuildKit.cylinder(reel, 0.0078, 0.0012, Vector3.ZERO, white, false, Vector3(90, 0, 0), -1.0, 6)
		BuildKit.cylinder(reel, 0.0035, 0.0016, Vector3.ZERO, glass, false, Vector3(90, 0, 0), -1.0, 6)
		for k in 3:
			BuildKit.box(reel, Vector3(0.0018, 0.0055, 0.0018), Vector3(sin(k * TAU / 3.0) * 0.005, cos(k * TAU / 3.0) * 0.005, 0), glass, false, Vector3(0, 0, -rad_to_deg(k * TAU / 3.0)))
		parts["reel_%d" % i] = reel
	# Lautsprecher-Schlitze unten, Mikrofon oben, Markenstreifen
	var sp := StandardMaterial3D.new()
	sp.albedo_texture = _label_tex("speaker")
	sp.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	sp.roughness = 0.6
	var q := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(w * 0.6, 0.034)
	q.mesh = qm
	q.material_override = sp
	q.position = Vector3(0, -0.03, t * 0.5 + 0.0016)
	n.add_child(q)
	BuildKit.box(n, Vector3(w * 0.5, 0.004, 0.002), Vector3(0, 0.0005, t * 0.5 + 0.0014), BuildKit.color_mat(Color(0.75, 0.1, 0.08), 0.5), false)
	BuildKit.cylinder(n, 0.007, 0.01, Vector3(-0.012, h * 0.5 + 0.003, 0), body, false, Vector3.ZERO, 0.006, 8)
	BuildKit.cylinder(n, 0.0055, 0.002, Vector3(-0.012, h * 0.5 + 0.0085, 0), silver, false, Vector3.ZERO, -1.0, 8)
	# Aufnahme-Leuchte und Tasten an der Daumenseite
	var led := BuildKit.emissive_mat(Color(1.0, 0.1, 0.05), 0.0)
	BuildKit.sphere(n, 0.0038, Vector3(0.017, 0.046, t * 0.5 + 0.001), led, Vector3(1, 1, 0.6), 6)
	BuildKit.cylinder(n, 0.0052, 0.0012, Vector3(0.017, 0.046, t * 0.5 + 0.0008), body, false, Vector3(90, 0, 0), -1.0, 8)
	var rec := BuildKit.box(n, Vector3(0.005, 0.016, 0.01), Vector3(w * 0.54 + 0.0015, 0.02, 0), BuildKit.color_mat(Color(0.8, 0.1, 0.08), 0.5), false)
	BuildKit.box(n, Vector3(0.004, 0.011, 0.01), Vector3(w * 0.54 + 0.001, 0.0, 0), silver, false)
	BuildKit.box(n, Vector3(0.004, 0.011, 0.01), Vector3(w * 0.54 + 0.001, -0.016, 0), silver, false)
	# Trageschlaufe
	HandKit.tube(n, HandKit.arc(Vector3(0.018, -h * 0.5 - 0.016, 0), 0.01, 0, 360, 8, Vector3.RIGHT, Vector3.UP, 0.02), 0.0013, BuildKit.color_mat(Color(0.08, 0.08, 0.08), 0.9), 4, Vector3(0, 0, 1))
	parts["led"] = led
	parts["rec"] = rec
	n.set_meta("parts", parts)
	n.set_meta("grip", 0.0215)
	n.set_meta("tight", 0.9)
	n.set_meta("up", 0.036)
	n.set_meta("tilt", Vector3(-14, 16, 0))
	n.set_meta("base", Vector3(0, -h * 0.5, 0))
	n.set_meta("lie", 0.012)


# --- Gießkanne ---------------------------------------------------------------

static func _watering_can(n: Node3D) -> void:
	var zinc := BuildKit.tex_mat("metal", 0.22, Color(1.22, 1.3, 1.32), 0.42)
	var zinc_dark := BuildKit.tex_mat("metal", 0.22, Color(0.8, 0.86, 0.9), 0.5)
	var brass := BuildKit.color_mat(Color(0.72, 0.55, 0.2), 0.35, 0.7)
	var inside := BuildKit.color_mat(Color(0.1, 0.11, 0.12), 0.8)
	var grip_at := Vector3(0, 0.1025, 0.168)
	var c := Node3D.new()
	c.position = -grip_at
	n.add_child(c)
	# Kannenkörper mit Bodenwulst, Sicke in der Mitte und umgebördeltem Rand
	BuildKit.lathe(c, PackedVector2Array([Vector2(0.0, 0.004), Vector2(0.078, 0.0), Vector2(0.086, 0.004), Vector2(0.087, 0.012), Vector2(0.083, 0.017), Vector2(0.083, 0.088),
			Vector2(0.0858, 0.093), Vector2(0.083, 0.098), Vector2(0.083, 0.174), Vector2(0.0875, 0.179), Vector2(0.0875, 0.186), Vector2(0.08, 0.186), Vector2(0.08, 0.168)]),
			Vector3.ZERO, zinc, 14)
	BuildKit.cylinder(c, 0.08, 0.002, Vector3(0, 0.02, 0), inside, false, Vector3.ZERO, -1.0, 14)
	BuildKit.lathe(c, PackedVector2Array([Vector2(0.08, 0.186), Vector2(0.08, 0.02)]), Vector3.ZERO, inside, 14).scale = Vector3(-1, 1, 1)
	# Wasserspiegel (sichtbar durch die hintere Öffnung)
	var water_mat := HandKit.own_mat(Color(0.25, 0.42, 0.55), 0.08)
	water_mat.metallic_specular = 0.9
	var water := BuildKit.cylinder(c, 0.0795, 0.002, Vector3(0, 0.15, 0), water_mat, false, Vector3.ZERO, -1.0, 14)
	# halber Deckel vorn
	var cover := HandKit.extrude(c, _half_disc(0.0855), 0.0012, zinc)
	cover.rotation_degrees.x = 90.0
	cover.position = Vector3(0, 0.186, 0)
	BuildKit.box(c, Vector3(0.171, 0.006, 0.004), Vector3(0, 0.187, 0.0), zinc_dark, false)
	# hinterer Griff (hier fasst die Hand zu) und Tragebügel oben: flache Blechbänder mit Wulst
	var strap := PackedVector2Array([Vector2(0.004, 0.0115)])
	HandKit.loft(c, HandKit.arc(Vector3(0, 0.1025, 0.08), 0.088, 84, -84, 10, Vector3(0, 0, 1), Vector3.UP, 0.076), strap, zinc, 6, Vector3.RIGHT)
	HandKit.loft(c, HandKit.arc(Vector3(0, 0.184, 0.006), 0.07, 6, 174, 9, Vector3(0, 0, 1), Vector3.UP, 0.062), strap, zinc, 6, Vector3.RIGHT)
	for q: Vector3 in [Vector3(0, 0.178, 0.082), Vector3(0, 0.027, 0.085), Vector3(0, 0.19, -0.062)]:
		BuildKit.box(c, Vector3(0.03, 0.014, 0.006), q, zinc_dark, false)
	# lange Tülle, nach vorn dünner, mit Strebe zum Körper
	HandKit.loft(c, PackedVector3Array([Vector3(0, 0.03, -0.066), Vector3(0, 0.062, -0.118), Vector3(0, 0.14, -0.215), Vector3(0, 0.212, -0.3)]),
			PackedVector2Array([Vector2(0.027, 0.027), Vector2(0.021, 0.021), Vector2(0.0145, 0.0145), Vector2(0.0118, 0.0118)]), zinc, 8, Vector3.RIGHT)
	BuildKit.cylinder(c, 0.03, 0.012, Vector3(0, 0.036, -0.077), zinc_dark, false, Vector3(58, 0, 0), 0.027, 8)
	HandKit.tube(c, PackedVector3Array([Vector3(0, 0.178, -0.083), Vector3(0, 0.168, -0.15), Vector3(0, 0.15, -0.222)]), 0.0032, zinc_dark, 5, Vector3.RIGHT)
	# Brause aus Messing mit Lochscheibe
	var rose := Node3D.new()
	rose.position = Vector3(0, 0.212, -0.3)
	rose.rotation_degrees.x = -62.0
	c.add_child(rose)
	BuildKit.lathe(rose, PackedVector2Array([Vector2(0.0125, -0.006), Vector2(0.0135, 0.004), Vector2(0.031, 0.036), Vector2(0.0325, 0.042), Vector2(0.03, 0.045), Vector2(0.0, 0.049)]), Vector3.ZERO, brass, 10)
	BuildKit.cylinder(rose, 0.0135, 0.006, Vector3(0, -0.003, 0), brass, false, Vector3.ZERO, -1.0, 8)
	var holes := StandardMaterial3D.new()
	holes.albedo_texture = _label_tex("rose")
	holes.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	holes.roughness = 0.4
	holes.metallic = 0.5
	HandKit.disc(rose, 0.027, Vector3(0, 0.0485, 0), holes, 10)
	var tip := Node3D.new()
	tip.position = Vector3(0, 0.052, 0)
	rose.add_child(tip)
	n.set_meta("parts", {"rose": tip, "water": water, "water_y": Vector2(0.03, 0.158)})
	n.set_meta("grip", 0.0115)
	n.set_meta("tilt", Vector3(4, 0, 0))
	n.set_meta("base", Vector3(0, -grip_at.y, -grip_at.z))
	n.set_meta("center", Vector3(0, 0.0, -0.2))


static func _half_disc(r: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in 9:
		var a := PI * i / 8.0
		out.append(Vector2(cos(a) * r, sin(a) * r))
	return out


## Wasserstand in der Kanne zeigen (0 = leer, 1 = voll).
static func can_level(n: Node3D, frac: float) -> void:
	var p: Dictionary = n.get_meta("parts", {})
	if not p.has("water"):
		return
	var w := p["water"] as Node3D
	var range_y: Vector2 = p["water_y"]
	w.visible = frac > 0.01
	w.position.y = lerpf(range_y.x, range_y.y, clampf(frac, 0.0, 1.0))


# --- Bauhammer ---------------------------------------------------------------

static func _hammer(n: Node3D) -> void:
	var wood := BuildKit.tex_mat("planks_v", 0.16, Color(1.3, 1.08, 0.8), 0.7)
	var steel := _steel(1.0, 0.4)
	var bright := BuildKit.tex_mat("metal", 0.1, Color(1.9, 1.9, 1.95), 0.25)
	var up := Vector3(0, 0, -1)
	HandKit.loft(n, PackedVector3Array([Vector3(0, -0.105, 0.004), Vector3(0, -0.095, 0.004), Vector3(0, -0.04, 0.001), Vector3(0, 0.03, 0), Vector3(0, 0.14, 0), Vector3(0, 0.226, 0)]),
			PackedVector2Array([Vector2(0.01, 0.013), Vector2(0.0135, 0.0185), Vector2(0.012, 0.0165), Vector2(0.0105, 0.0145), Vector2(0.0095, 0.013), Vector2(0.0098, 0.0135)]), wood, 8, up)
	# Kopf: Auge, Hals, runde Bahn vorn, gespaltene Klaue hinten
	var head := Node3D.new()
	head.position = Vector3(0, 0.205, 0)
	n.add_child(head)
	BuildKit.box(head, Vector3(0.026, 0.032, 0.03), Vector3.ZERO, steel, false)
	BuildKit.cylinder(head, 0.0105, 0.03, Vector3(0, 0.001, -0.029), steel, false, Vector3(90, 0, 0), 0.0125, 8)
	BuildKit.cylinder(head, 0.0155, 0.014, Vector3(0, 0.001, -0.05), steel, false, Vector3(90, 0, 0), -1.0, 10)
	BuildKit.cylinder(head, 0.0145, 0.002, Vector3(0, 0.001, -0.058), bright, false, Vector3(90, 0, 0), -1.0, 10)
	for sx: float in [-1.0, 1.0]:
		var claw := HandKit.extrude(head, PackedVector2Array([Vector2(0.012, 0.013), Vector2(0.03, 0.012), Vector2(0.052, 0.002), Vector2(0.066, -0.016),
				Vector2(0.064, -0.02), Vector2(0.048, -0.008), Vector2(0.03, -0.002), Vector2(0.012, -0.004)]), PackedFloat32Array([0.0055, 0.0055, 0.0045, 0.002, 0.002, 0.004, 0.005, 0.0055]), steel)
		claw.rotation_degrees.y = -90.0
		claw.position.x = sx * 0.0072
	n.set_meta("grip", 0.0135)
	n.set_meta("tilt", Vector3(-16, 0, 0))
	n.set_meta("base", Vector3(0, -0.105, 0))
	n.set_meta("center", Vector3(0, 0.06, 0))
