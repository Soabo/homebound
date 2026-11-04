class_name CreatureModel
extends RefCounted
## Detailliertes Modell der ersten Kreatur (ein "Grey"): ca. 2,2 m, ausgemergelt, lange Glieder,
## großer Schädel mit Mandelaugen, drei lange Finger (passend zu den Handabdrücken).
## Liefert dieselben Gelenk-Knoten wie früher, damit die Bewegungen weiter funktionieren:
## hips, torso, neck, head, arm_±1, forearm_±1, leg_±1, knee_±1, eye_mat.

static var skin: StandardMaterial3D
static var skin_dark: StandardMaterial3D
static var nail: StandardMaterial3D


static func _materials() -> void:
	if skin != null:
		return
	skin = StandardMaterial3D.new()
	skin.albedo_texture = TextureFactory.get_texture("alien_skin")
	skin.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	skin.uv1_triplanar = true
	skin.uv1_world_triplanar = false
	skin.uv1_scale = Vector3(4.0, 4.0, 4.0)
	skin.albedo_color = Color(1.12, 1.15, 1.08)
	skin.roughness = 0.6
	skin.metallic_specular = 0.4
	# heller Rand im Gegenlicht (Taschenlampe)
	skin.rim_enabled = true
	skin.rim = 0.2
	skin.rim_tint = 0.4
	skin_dark = skin.duplicate() as StandardMaterial3D
	skin_dark.albedo_color = Color(0.75, 0.77, 0.74)
	nail = BuildKit.color_mat(Color(0.12, 0.11, 0.1), 0.2)


static func build(root: Node3D) -> Dictionary:
	_materials()
	var eye := StandardMaterial3D.new()
	eye.albedo_color = Color(0.01, 0.01, 0.015)
	eye.roughness = 0.12
	eye.metallic_specular = 1.0
	eye.clearcoat_enabled = true
	eye.clearcoat = 1.0
	eye.emission_enabled = true
	eye.emission = Color(0.25, 0.45, 0.35)
	eye.emission_energy_multiplier = 0.08
	var p := {"eye_mat": eye}

	var hips := Node3D.new()
	hips.position = Vector3(0, 1.05, 0)
	root.add_child(hips)
	p["hips"] = hips
	_pelvis(hips)

	var torso := Node3D.new()
	torso.rotation_degrees.x = 8.0
	hips.add_child(torso)
	p["torso"] = torso
	_torso(torso)

	var neck := Node3D.new()
	neck.position = Vector3(0, 0.66, -0.02)
	neck.rotation_degrees.x = 14.0
	torso.add_child(neck)
	p["neck"] = neck
	_neck(neck)

	var head := Node3D.new()
	head.position = Vector3(0, 0.2, 0.0)
	head.rotation_degrees.x = -10.0
	neck.add_child(head)
	p["head"] = head
	_head(head, eye)

	for side: float in [-1.0, 1.0]:
		var sh := Node3D.new()
		sh.position = Vector3(side * 0.2, 0.58, -0.01)
		sh.rotation_degrees.z = side * 4.0
		torso.add_child(sh)
		p["arm_%d" % int(side)] = sh
		var el := _upper_arm(sh, side)
		p["forearm_%d" % int(side)] = el
		_forearm_and_hand(el, side)

	for side: float in [-1.0, 1.0]:
		var hip := Node3D.new()
		hip.position = Vector3(side * 0.09, -0.02, 0)
		hips.add_child(hip)
		p["leg_%d" % int(side)] = hip
		var knee := _thigh(hip)
		p["knee_%d" % int(side)] = knee
		_shin_and_foot(knee, side)

	for vi in root.find_children("*", "GeometryInstance3D", true, false):
		(vi as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return p


# --- Körperteile ------------------------------------------------------

static func _pelvis(hips: Node3D) -> void:
	BuildKit.sphere(hips, 0.12, Vector3(0, 0.02, 0), skin, Vector3(1.3, 0.75, 0.85), 12)
	# vorstehende Beckenknochen
	for side: float in [-1.0, 1.0]:
		BuildKit.sphere(hips, 0.04, Vector3(side * 0.12, 0.07, 0.05), skin, Vector3(1.0, 0.7, 0.9), 8)
	BuildKit.sphere(hips, 0.05, Vector3(0, -0.06, 0.03), skin_dark, Vector3(1.0, 0.8, 0.7), 8)


static func _torso(t: Node3D) -> void:
	# Bauch schmal und eingefallen, Brustkorb breit; Profil von unten nach oben
	var body := BuildKit.lathe(t, PackedVector2Array([
			Vector2(0.0, 0.0), Vector2(0.13, 0.02), Vector2(0.11, 0.16), Vector2(0.1, 0.26),
			Vector2(0.15, 0.36), Vector2(0.18, 0.46), Vector2(0.185, 0.54), Vector2(0.17, 0.62),
			Vector2(0.1, 0.68), Vector2(0.0, 0.7)]), Vector3.ZERO, skin, 16)
	body.scale = Vector3(1.0, 1.0, 0.75)
	# Rippen: Bögen aus kurzen Stücken auf Brust und Flanken
	for i in 6:
		var y := 0.36 + i * 0.045
		var rad := 0.15 + sin(PI * (i + 1) / 7.0) * 0.037
		for side: float in [-1.0, 1.0]:
			for k in 4:
				var a0 := deg_to_rad(15.0 + k * 28.0)
				var a1 := deg_to_rad(15.0 + (k + 1) * 28.0)
				var p0 := Vector3(side * sin(a0) * rad, y - k * 0.008, cos(a0) * rad * 0.77)
				var p1 := Vector3(side * sin(a1) * rad, y - (k + 1) * 0.008, cos(a1) * rad * 0.77)
				_seg(t, p0, p1, [0.011, 0.012, 0.011], skin)
	# Brustbein, Schlüsselbeine
	_seg(t, Vector3(0, 0.37, 0.12), Vector3(0, 0.6, 0.115), [0.012, 0.015, 0.012], skin)
	for side: float in [-1.0, 1.0]:
		_seg(t, Vector3(side * 0.02, 0.63, 0.07), Vector3(side * 0.17, 0.6, 0.02), [0.011, 0.013, 0.01], skin)
		# Schulterblätter am Rücken
		var blade := BuildKit.sphere(t, 0.06, Vector3(side * 0.08, 0.53, -0.1), skin, Vector3(1.0, 1.3, 0.35), 8)
		blade.rotation_degrees.z = side * 12.0
	# Wirbelsäule als Höckerreihe
	for i in 12:
		var y := 0.04 + i * 0.053
		var back := 0.07 if y < 0.3 else 0.09 + sin(PI * (y - 0.3) / 0.4) * 0.02
		BuildKit.sphere(t, 0.016, Vector3(0, y, -back), skin, Vector3(1.2, 0.8, 1.0), 6)
	# Bauchfalten
	for i in 3:
		BuildKit.box(t, Vector3(0.12 - i * 0.02, 0.006, 0.01), Vector3(0, 0.12 + i * 0.06, 0.064), skin_dark, false)


static func _neck(n: Node3D) -> void:
	_seg(n, Vector3.ZERO, Vector3(0, 0.24, 0.0), [0.05, 0.04, 0.036, 0.042], skin)
	# Sehnen und Kehlkopf
	for side: float in [-1.0, 1.0]:
		_seg(n, Vector3(side * 0.03, 0.0, 0.015), Vector3(side * 0.012, 0.2, 0.03), [0.008, 0.009, 0.007], skin)
	BuildKit.sphere(n, 0.014, Vector3(0, 0.1, 0.035), skin, Vector3(1.0, 1.4, 1.0), 6)


static func _head(h: Node3D, eye: Material) -> void:
	# Hinterkopf: großer, nach hinten gezogener Schädel
	BuildKit.sphere(h, 0.19, Vector3(0, 0.22, -0.07), skin, Vector3(0.92, 1.0, 1.32), 18)
	# Stirn und Schläfen
	BuildKit.sphere(h, 0.16, Vector3(0, 0.2, 0.06), skin, Vector3(1.08, 1.0, 0.85), 14)
	# Gesicht verjüngt sich zum spitzen Kinn
	var face := BuildKit.lathe(h, PackedVector2Array([Vector2(0.0, -0.15), Vector2(0.025, -0.145), Vector2(0.06, -0.1),
			Vector2(0.11, 0.0), Vector2(0.145, 0.1), Vector2(0.0, 0.14)]), Vector3(0, 0.0, 0.05), skin, 16)
	face.scale = Vector3(1.0, 1.0, 0.85)
	# Wangenknochen und Augenbrauenwulst
	for side: float in [-1.0, 1.0]:
		BuildKit.sphere(h, 0.035, Vector3(side * 0.095, 0.05, 0.11), skin, Vector3(1.0, 0.6, 0.8), 8)
		var brow := BuildKit.sphere(h, 0.04, Vector3(side * 0.07, 0.165, 0.15), skin, Vector3(1.4, 0.45, 0.6), 8)
		brow.rotation_degrees.z = side * -22.0
	# Große Mandelaugen, schräg gestellt, mit dunklem Lidrand
	for side: float in [-1.0, 1.0]:
		var socket := BuildKit.sphere(h, 0.07, Vector3(side * 0.078, 0.1, 0.135), skin_dark, Vector3(1.0, 0.6, 0.45), 12)
		socket.rotation_degrees = Vector3(0, side * 18.0, side * -30.0)
		var e := BuildKit.sphere(h, 0.068, Vector3(side * 0.08, 0.1, 0.148), eye, Vector3(1.0, 0.55, 0.5), 14)
		e.rotation_degrees = Vector3(0, side * 18.0, side * -30.0)
	# Nasenschlitze und schmaler Mund
	for side: float in [-1.0, 1.0]:
		BuildKit.box(h, Vector3(0.006, 0.018, 0.008), Vector3(side * 0.012, 0.015, 0.165), nail, false, Vector3(0, 0, side * 15.0))
	BuildKit.box(h, Vector3(0.045, 0.004, 0.01), Vector3(0, -0.075, 0.12), nail, false)
	BuildKit.sphere(h, 0.018, Vector3(0, -0.065, 0.12), skin, Vector3(1.6, 0.4, 0.6), 6)
	# Ohrlöcher
	for side: float in [-1.0, 1.0]:
		BuildKit.cylinder(h, 0.012, 0.01, Vector3(side * 0.165, 0.1, -0.02), nail, false, Vector3(0, 0, 90), -1.0, 6)
	# Adern auf dem Schädel
	for k in 5:
		var a := -0.9 + k * 0.45
		_seg(h, Vector3(sin(a) * 0.16, 0.3, cos(a) * 0.1 - 0.06), Vector3(sin(a) * 0.2, 0.18, cos(a) * 0.13 - 0.14),
				[0.004, 0.005, 0.003], skin_dark)


static func _upper_arm(sh: Node3D, side: float) -> Node3D:
	BuildKit.sphere(sh, 0.058, Vector3(0, 0, 0), skin, Vector3(1.0, 0.9, 1.0), 10)
	_seg(sh, Vector3.ZERO, Vector3(0, -0.42, 0), [0.052, 0.048, 0.038, 0.03, 0.033], skin)
	var el := Node3D.new()
	el.position = Vector3(0, -0.42, 0)
	sh.add_child(el)
	BuildKit.sphere(el, 0.036, Vector3(0, 0, -0.01), skin, Vector3(1.0, 1.0, 1.1), 8)
	return el


static func _forearm_and_hand(el: Node3D, side: float) -> void:
	_seg(el, Vector3.ZERO, Vector3(0, -0.42, 0.01), [0.033, 0.034, 0.027, 0.021, 0.022], skin)
	# Elle als Kante
	_seg(el, Vector3(0, -0.02, -0.015), Vector3(0, -0.4, -0.006), [0.007, 0.008, 0.006], skin)
	# Hand: schmaler Handteller, drei lange Finger mit Gelenken und dunklen Krallen, kurzer Daumen
	var hand := Node3D.new()
	hand.position = Vector3(0, -0.43, 0.01)
	hand.rotation_degrees.x = 8.0
	el.add_child(hand)
	BuildKit.sphere(hand, 0.04, Vector3(0, -0.04, 0), skin, Vector3(0.9, 1.2, 0.45), 10)
	for f in 3:
		var x := (f - 1) * 0.022
		var spread := (f - 1) * 7.0
		var base := Vector3(x, -0.085, 0.0)
		var dir := Vector3(sin(deg_to_rad(spread)) * 0.3, -1.0, 0.12).normalized()
		var lengths := [0.075, 0.065, 0.055]
		var p := base
		for j in 3:
			# Finger krümmen sich nach unten innen
			dir = dir.rotated(Vector3.RIGHT, deg_to_rad(-14.0))
			var q: Vector3 = p + dir * lengths[j]
			_seg(hand, p, q, [0.009 - j * 0.0015, 0.0085 - j * 0.0015, 0.0075 - j * 0.0015], skin)
			BuildKit.sphere(hand, 0.0095 - j * 0.0015, p, skin, Vector3.ONE, 6)
			p = q
		_seg(hand, p, p + dir * 0.025, [0.005, 0.003, 0.0005], nail)
	_seg(hand, Vector3(-side * 0.03, -0.03, 0.015), Vector3(-side * 0.045, -0.085, 0.04), [0.009, 0.008, 0.006], skin)


static func _thigh(hip: Node3D) -> Node3D:
	_seg(hip, Vector3.ZERO, Vector3(0, -0.5, 0.0), [0.07, 0.066, 0.052, 0.04, 0.042], skin)
	var knee := Node3D.new()
	knee.position = Vector3(0, -0.5, 0)
	hip.add_child(knee)
	BuildKit.sphere(knee, 0.044, Vector3(0, 0, 0.012), skin, Vector3(1.0, 1.1, 1.0), 8)
	return knee


static func _shin_and_foot(knee: Node3D, side: float) -> void:
	_seg(knee, Vector3.ZERO, Vector3(0, -0.5, -0.01), [0.042, 0.04, 0.03, 0.021, 0.022], skin)
	# Schienbeinkante
	_seg(knee, Vector3(0, -0.04, 0.02), Vector3(0, -0.46, 0.012), [0.008, 0.009, 0.006], skin)
	var ankle := Vector3(0, -0.51, -0.01)
	BuildKit.sphere(knee, 0.022, ankle, skin, Vector3(1.2, 1.0, 1.0), 8)
	# langer, schmaler Fuß mit drei Zehen und Krallen
	BuildKit.sphere(knee, 0.04, ankle + Vector3(0, -0.015, 0.06), skin, Vector3(0.9, 0.45, 1.8), 10)
	for f in 3:
		var x := (f - 1) * 0.02
		var p0 := ankle + Vector3(x, -0.025, 0.12)
		var p1 := p0 + Vector3(x * 0.4, -0.008, 0.06)
		_seg(knee, p0, p1, [0.009, 0.008, 0.006], skin)
		_seg(knee, p1, p1 + Vector3(0, -0.012, 0.02), [0.005, 0.003, 0.0005], nail)
	# Ferse
	BuildKit.sphere(knee, 0.018, ankle + Vector3(0, -0.02, -0.02), skin, Vector3.ONE, 6)


## Organisches Glied zwischen zwei Punkten: Drehkörper mit Radien entlang der Länge.
static func _seg(parent: Node3D, from: Vector3, to: Vector3, radii: Array, mat: Material) -> MeshInstance3D:
	var len := from.distance_to(to)
	var prof := PackedVector2Array([Vector2(0.0, 0.0)])
	for i in radii.size():
		prof.append(Vector2(float(radii[i]), len * float(i) / float(radii.size() - 1)))
	prof.append(Vector2(0.0, len))
	var mi := BuildKit.lathe(parent, prof, from, mat, 8)
	var y := (to - from).normalized()
	var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
	var z := x.cross(y).normalized()
	mi.basis = Basis(x, y, z)
	return mi
