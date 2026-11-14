class_name ChangelingModel
extends RefCounted
## Modelle des Wechselbalgs: Tarnungen (jede mit genau einem Fehler) und die wahre Gestalt.
## Ursprung = Boden, Vorderseite = +z. build() gibt {height, size} zurück (für Kollision und Sicht).
## obvious = deutlicher Fehler, subtle = feiner Fehler (ab Stufe 3).

const KINDS := ["chair", "office_chair", "broom", "lamp", "coat_stand", "bench", "stump", "backpack", "signpost", "tent"]

static var _mats: Dictionary = {}


static func _m(key: String) -> Material:
	if _mats.has(key):
		return _mats[key]
	var m: Material
	match key:
		"wood": m = BuildKit.tex_mat("planks_h", 0.6, Color(0.85, 0.72, 0.55))
		"dark": m = BuildKit.tex_mat("planks_h", 0.6, Color(0.55, 0.42, 0.32))
		"metal": m = BuildKit.color_mat(Color(0.32, 0.33, 0.34), 0.5, 0.6)
		"black": m = BuildKit.color_mat(Color(0.08, 0.08, 0.08), 0.7)
		"fabric": m = BuildKit.tex_mat("fabric", 0.4, Color(0.55, 0.5, 0.42))
		"jacket": m = BuildKit.tex_mat("fabric", 0.4, Color(0.45, 0.5, 0.38))
		"shade": m = BuildKit.color_mat(Color(0.85, 0.78, 0.6), 0.9)
		"straw": m = BuildKit.color_mat(Color(0.72, 0.6, 0.35), 1.0)
		"bark": m = BuildKit.tex_mat("bark", 1.0, Color(0.8, 0.72, 0.62))
		"rings": m = BuildKit.color_mat(Color(0.7, 0.56, 0.38), 1.0)
		"pack": m = BuildKit.tex_mat("fabric", 0.35, Color(0.36, 0.42, 0.3))
		"tent": m = BuildKit.color_mat(Color(0.32, 0.4, 0.3), 0.95)
		"board": m = BuildKit.color_mat(Color(0.85, 0.8, 0.66), 0.9)
		"skin": m = BuildKit.color_mat(Color(0.62, 0.6, 0.55), 0.55)
		"skin_dark": m = BuildKit.color_mat(Color(0.3, 0.27, 0.25), 0.7)
		"socket": m = BuildKit.color_mat(Color(0.08, 0.06, 0.06), 0.9)
		"mouth": m = BuildKit.color_mat(Color(0.12, 0.03, 0.03), 0.6)
		"teeth": m = BuildKit.color_mat(Color(0.92, 0.9, 0.8), 0.4)
		"eye": m = BuildKit.color_mat(Color(0.97, 0.96, 0.94), 0.3)
		"pupil": m = BuildKit.color_mat(Color(0.02, 0.02, 0.02), 0.2)
		_: m = BuildKit.color_mat(Color(0.5, 0.5, 0.5))
	_mats[key] = m
	return m


## Stab von a nach b (Zylinder entlang der Verbindung).
static func bar(root: Node3D, a: Vector3, b: Vector3, r: float, mat: Material, seg: int = 8) -> MeshInstance3D:
	var d := b - a
	var mi := BuildKit.cylinder(root, r, maxf(d.length(), 0.001), (a + b) * 0.5, mat, false, Vector3.ZERO, -1.0, seg)
	if d.length() > 0.0001:
		var up := d.normalized()
		mi.basis = Basis(Quaternion(Vector3.UP, up))
	return mi


static func build(root: Node3D, kind: String, subtle: bool) -> Dictionary:
	match kind:
		"chair": return _chair(root, subtle)
		"office_chair": return _office_chair(root, subtle)
		"broom": return _broom(root, subtle)
		"lamp": return _lamp(root, subtle)
		"coat_stand": return _coat_stand(root, subtle)
		"bench": return _bench(root, subtle)
		"stump": return _stump(root, subtle)
		"backpack": return _backpack(root, subtle)
		"signpost": return _signpost(root, subtle)
		"tent": return _tent(root, subtle)
	return _chair(root, subtle)


# --- Tarnungen ---------------------------------------------------------------

static func _chair(root: Node3D, subtle: bool) -> Dictionary:
	var w := _m("wood")
	var dk := _m("dark")
	BuildKit.box_mm(root, Vector3(-0.21, 0.42, -0.21), Vector3(0.21, 0.46, 0.21), w, false)
	for x: float in [-0.18, 0.18]:
		BuildKit.box_mm(root, Vector3(x - 0.025, 0.46, -0.21), Vector3(x + 0.025, 0.98, -0.17), dk, false)
	for yy: float in [0.68, 0.9]:
		BuildKit.box_mm(root, Vector3(-0.18, yy - 0.04, -0.205), Vector3(0.18, yy + 0.04, -0.18), w, false)
	for p: Vector2 in [Vector2(-0.18, -0.18), Vector2(0.18, -0.18), Vector2(-0.18, 0.18), Vector2(0.18, 0.18)]:
		BuildKit.box_mm(root, Vector3(p.x - 0.022, 0, p.y - 0.022), Vector3(p.x + 0.022, 0.42, p.y + 0.022), dk, false)
	if subtle:
		# Fehler: ein fünftes Bein, vorne in der Mitte
		BuildKit.box_mm(root, Vector3(-0.022, 0, 0.158), Vector3(0.022, 0.42, 0.202), dk, false)
	else:
		# Fehler: die Seitenlehnen sitzen UNTER der Sitzfläche
		for x: float in [-0.25, 0.25]:
			BuildKit.box_mm(root, Vector3(x - 0.03, 0.24, -0.2), Vector3(x + 0.03, 0.28, 0.24), w, false)
			BuildKit.box_mm(root, Vector3(x - 0.02, 0.28, 0.17), Vector3(x + 0.02, 0.42, 0.21), dk, false)
	return {"height": 0.98, "size": Vector3(0.5, 0.98, 0.5)}


static func _office_chair(root: Node3D, subtle: bool) -> Dictionary:
	var met := _m("metal")
	var blk := _m("black")
	var fab := _m("fabric")
	var arms := 7 if subtle else 5
	for i in arms:
		var a := TAU * i / arms
		var tip := Vector3(sin(a) * 0.3, 0.06, cos(a) * 0.3)
		bar(root, Vector3(0, 0.1, 0), tip, 0.018, met)
		BuildKit.sphere(root, 0.03, tip - Vector3(0, 0.03, 0), blk, Vector3.ONE, 8)
	BuildKit.cylinder(root, 0.03, 0.36, Vector3(0, 0.28, 0), met, false)
	BuildKit.box(root, Vector3(0.48, 0.08, 0.46), Vector3(0, 0.5, 0), fab, false)
	if subtle:
		BuildKit.box(root, Vector3(0.44, 0.52, 0.06), Vector3(0, 0.82, -0.22), fab, false)
		BuildKit.box(root, Vector3(0.05, 0.3, 0.04), Vector3(0, 0.6, -0.22), met, false)
	else:
		# Fehler: die Lehne hängt nach unten, unter den Sitz
		BuildKit.box(root, Vector3(0.05, 0.12, 0.04), Vector3(0, 0.42, -0.22), met, false)
		BuildKit.box(root, Vector3(0.44, 0.4, 0.06), Vector3(0, 0.22, -0.24), fab, false)
	return {"height": 1.08 if subtle else 0.55, "size": Vector3(0.62, 1.0, 0.62)}


static func _broom(root: Node3D, subtle: bool) -> Dictionary:
	# Steht schräg an der Wand: die Wand liegt in -z (lean zeigt dorthin)
	var w := _m("wood")
	var s := _m("straw")
	var tilt := Node3D.new()
	tilt.rotation_degrees.x = -12.0
	root.add_child(tilt)
	BuildKit.cylinder(tilt, 0.016, 1.3, Vector3(0, 0.85, 0), w, false)
	if subtle:
		# Fehler: der Kopf steht unten, aber die Borsten zeigen nach oben
		BuildKit.box(tilt, Vector3(0.3, 0.05, 0.07), Vector3(0, 0.22, 0), _m("dark"), false)
		BuildKit.cylinder(tilt, 0.13, 0.17, Vector3(0, 0.33, 0), s, false, Vector3.ZERO, 0.06, 8)
		BuildKit.box(tilt, Vector3(0.05, 0.2, 0.05), Vector3(0, 0.12, 0), w, false)
	else:
		for top: bool in [false, true]:
			# Fehler: ein Besenkopf oben UND unten
			var y := 1.58 if top else 0.12
			BuildKit.cylinder(tilt, 0.06, 0.24, Vector3(0, y, 0), s, false, Vector3(180 if top else 0, 0, 0), 0.14, 8)
			BuildKit.box(tilt, Vector3(0.22, 0.05, 0.06), Vector3(0, y + (-0.13 if top else 0.13), 0), _m("dark"), false)
	return {"height": 1.7, "size": Vector3(0.3, 1.7, 0.3)}


static func _lamp(root: Node3D, subtle: bool) -> Dictionary:
	var met := _m("metal")
	var sh := _m("shade")
	BuildKit.cylinder(root, 0.16, 0.03, Vector3(0, 0.015, 0), met, false)
	BuildKit.cylinder(root, 0.015, 1.45, Vector3(0, 0.75, 0), met, false)
	if subtle:
		# Fehler: der Schirm sitzt verkehrt herum, und es gibt kein Kabel
		BuildKit.cylinder(root, 0.14, 0.28, Vector3(0, 1.52, 0), sh, false, Vector3.ZERO, 0.24, 14)
	else:
		BuildKit.cylinder(root, 0.24, 0.28, Vector3(0, 1.52, 0), sh, false, Vector3.ZERO, 0.14, 14)
		# Fehler: ein zweiter Schirm unten am Fuß, verkehrt herum
		BuildKit.cylinder(root, 0.14, 0.24, Vector3(0, 0.2, 0), sh, false, Vector3.ZERO, 0.22, 14)
		bar(root, Vector3(0, 0.02, 0.0), Vector3(0.0, 0.02, 0.5), 0.006, _m("black"), 4)
	return {"height": 1.66, "size": Vector3(0.45, 1.66, 0.45)}


static func _coat_stand(root: Node3D, subtle: bool) -> Dictionary:
	var dk := _m("dark")
	for i in 3:
		var a := TAU * i / 3.0
		bar(root, Vector3(0, 0.25, 0), Vector3(sin(a) * 0.28, 0.0, cos(a) * 0.28), 0.018, dk)
	BuildKit.cylinder(root, 0.025, 1.78, Vector3(0, 0.89, 0), dk, false)
	for i in 4:
		var a := TAU * i / 4.0 + 0.4
		var dir := Vector3(sin(a), 0, cos(a))
		# subtle = Fehler: die Haken zeigen nach unten
		var tip := Vector3(0, 1.55, 0) + dir * 0.16 + Vector3(0, -0.14 if subtle else 0.1, 0)
		bar(root, Vector3(0, 1.62, 0), tip, 0.012, dk, 6)
	# Jacke am vorderen Haken
	var jk := _m("jacket")
	BuildKit.box(root, Vector3(0.42, 0.62, 0.14), Vector3(0, 1.22, 0.12), jk, false)
	BuildKit.box(root, Vector3(0.16, 0.08, 0.1), Vector3(0, 1.55, 0.1), jk, false)
	var sleeves := [-0.26, 0.26]
	if not subtle:
		sleeves.append(0.0)   # Fehler: ein dritter Ärmel mitten auf der Brust
	for sx: float in sleeves:
		var from := Vector3(sx * 0.8, 1.44, 0.14 + (0.06 if sx == 0.0 else 0.0))
		bar(root, from, from + Vector3(sx * 0.15, -0.55, 0.04), 0.06, jk, 8)
	return {"height": 1.82, "size": Vector3(0.6, 1.82, 0.6)}


static func _bench(root: Node3D, subtle: bool) -> Dictionary:
	var w := _m("wood")
	var dk := _m("dark")
	for i in 3:
		BuildKit.box(root, Vector3(1.5, 0.035, 0.11), Vector3(0, 0.45, -0.13 + i * 0.13), w, false)
	var legs := [Vector2(-0.65, -0.15), Vector2(0.65, -0.15), Vector2(-0.65, 0.15), Vector2(0.65, 0.15)]
	if subtle:
		legs.remove_at(3)   # Fehler: nur drei Beine – und sie steht trotzdem gerade
	for l: Vector2 in legs:
		BuildKit.box(root, Vector3(0.07, 0.44, 0.07), Vector3(l.x, 0.22, l.y), dk, false)
	for side: float in ([-1.0] if subtle else [-1.0, 1.0]):
		# Rückenlehne – obvious = Fehler: auf beiden Seiten
		for x: float in [-0.65, 0.65]:
			BuildKit.box(root, Vector3(0.06, 0.45, 0.05), Vector3(x, 0.69, 0.2 * side), dk, false)
		BuildKit.box(root, Vector3(1.5, 0.12, 0.03), Vector3(0, 0.82, 0.21 * side), w, false)
	return {"height": 0.9, "size": Vector3(1.55, 0.9, 0.5)}


static func _stump(root: Node3D, subtle: bool) -> Dictionary:
	var bk := _m("bark")
	BuildKit.cylinder(root, 0.34, 0.5, Vector3(0, 0.25, 0), bk, false, Vector3.ZERO, 0.3, 10)
	BuildKit.cylinder(root, 0.29, 0.02, Vector3(0, 0.505, 0), _m("rings"), false, Vector3.ZERO, -1.0, 10)
	for i in 5:
		var a := TAU * i / 5.0 + 0.3
		var d := Vector3(sin(a), 0, cos(a))
		bar(root, d * 0.28 + Vector3(0, 0.1, 0), d * 0.62 + Vector3(0, -0.02, 0), 0.06, bk, 6)
		if not subtle:
			# Fehler: auch oben wachsen Wurzeln heraus
			bar(root, d * 0.18 + Vector3(0, 0.5, 0), d * 0.4 + Vector3(0, 0.78, 0), 0.04, bk, 6)
	return {"height": 0.8 if not subtle else 0.52, "size": Vector3(0.8, 0.6, 0.8)}


static func _backpack(root: Node3D, subtle: bool) -> Dictionary:
	var p := _m("pack")
	var blk := _m("black")
	BuildKit.box(root, Vector3(0.36, 0.52, 0.22), Vector3(0, 0.26, 0), p, false)
	BuildKit.box(root, Vector3(0.38, 0.16, 0.24), Vector3(0, 0.5, 0.01), p, false)
	BuildKit.box(root, Vector3(0.26, 0.18, 0.06), Vector3(0, 0.2, 0.13), p, false)
	var sides := [-1.0] if subtle else [-1.0, 1.0]   # obvious = Fehler: Träger vorne UND hinten
	for s: float in sides:
		for x: float in [-0.1, 0.1]:
			bar(root, Vector3(x, 0.5, 0.12 * s), Vector3(x * 1.3, 0.06, 0.13 * s), 0.018, blk, 4)
	var handles := [0.0] if not subtle else [-0.08, 0.08]   # subtle = Fehler: zwei Griffe oben
	for hx: float in handles:
		bar(root, Vector3(hx - 0.04, 0.58, 0), Vector3(hx + 0.04, 0.58, 0), 0.012, blk, 4)
	return {"height": 0.6, "size": Vector3(0.4, 0.6, 0.3)}


static func _signpost(root: Node3D, subtle: bool) -> Dictionary:
	var dk := _m("dark")
	BuildKit.cylinder(root, 0.05, 1.9, Vector3(0, 0.95, 0), dk, false, Vector3.ZERO, -1.0, 8)
	var boards := [[1.0, 1.6]] if subtle else [[1.0, 1.6], [-1.0, 1.35]]
	for b: Array in boards:
		var dir: float = b[0]
		var board := BuildKit.box(root, Vector3(0.62, 0.15, 0.03), Vector3(dir * 0.33, b[1], 0.05), _m("board"), false)
		var l := Label3D.new()
		l.text = "Hütte"
		l.font_size = 34
		l.pixel_size = 0.004
		l.modulate = Color(0.08, 0.07, 0.06)
		l.outline_size = 0
		l.position = Vector3(0, 0, 0.018)
		board.add_child(l)
		bar(root, Vector3(dir * 0.64, b[1] + 0.075, 0.05), Vector3(dir * 0.72, b[1], 0.05), 0.02, _m("board"), 4)
		bar(root, Vector3(dir * 0.64, b[1] - 0.075, 0.05), Vector3(dir * 0.72, b[1], 0.05), 0.02, _m("board"), 4)
	return {"height": 1.9, "size": Vector3(0.4, 1.9, 0.4)}


static func _tent(root: Node3D, subtle: bool) -> Dictionary:
	var t := _m("tent")
	var half_w := 0.85
	var h := 1.1
	var length := 2.2
	for side: float in [-1.0, 1.0]:
		var panel := BuildKit.box(root, Vector3(0.02, Vector2(half_w, h).length(), length), Vector3(side * half_w * 0.5, h * 0.5, 0), t, false)
		panel.rotation.z = side * atan2(half_w, h)
	var doors := [1.0] if subtle else [1.0, -1.0]   # obvious = Fehler: Eingang auf beiden Seiten
	for d: float in doors:
		var door := BuildKit.box(root, Vector3(0.9, 0.85, 0.02), Vector3(0, 0.43, d * length * 0.5), _m("black"), false)
		door.scale = Vector3(1, 1, 1)
	if not subtle:
		for c: float in [-1.0, 1.0]:
			bar(root, Vector3(c * half_w, 0.02, length * 0.5), Vector3(c * (half_w + 0.4), 0.0, length * 0.5 + 0.3), 0.01, _m("board"), 4)
	return {"height": h, "size": Vector3(half_w * 2.0, h, length)}


# --- Wahre Gestalt -------------------------------------------------------------

## Zu lang, zu viele Gelenke, zusammengefaltet. Ein fast menschliches Gesicht: breites Lächeln, weit
## aufgerissene, ängstliche Augen (Christian: besonders furchteinflößend, Forschung zum Unheimlichen).
## pose: "crouch" (zusammengefaltet wie ein Ding) | "stand" (aufgerichtet hinter dir)
static func build_true(root: Node3D, pose: String = "crouch") -> Dictionary:
	var skin := _m("skin")
	var dark := _m("skin_dark")
	var stand := pose == "stand"
	var hip := Vector3(0, 1.05 if stand else 0.55, 0)
	var chest := hip + (Vector3(0, 0.75, 0.05) if stand else Vector3(0, 0.45, 0.35))
	var neck := chest + (Vector3(0, 0.28, 0.08) if stand else Vector3(0, 0.22, 0.2))
	# Rumpf: gekrümmte Wirbelsäule, darüber Rippenbögen
	var mid := hip.lerp(chest, 0.5) + Vector3(0, 0, -0.08)
	bar(root, hip, mid, 0.075, skin, 10)
	bar(root, mid, chest, 0.085, skin, 10)
	for i in 6:
		var c := mid.lerp(chest, float(i) / 6.0) if i > 1 else hip.lerp(mid, 0.5 + i * 0.25)
		for sx: float in [-1.0, 1.0]:
			bar(root, c + Vector3(0, 0, -0.04), c + Vector3(sx * 0.12, -0.03, 0.06), 0.012, dark, 5)
	bar(root, chest, neck, 0.035, skin, 8)
	# Kopf: länglich, leicht schief gelegt
	var head := Node3D.new()
	head.name = "Head"
	head.position = neck + Vector3(0, 0.16, 0.02)
	head.rotation_degrees.z = 22.0
	root.add_child(head)
	BuildKit.sphere(head, 0.15, Vector3.ZERO, skin, Vector3(0.82, 1.32, 0.9), 16)
	# Augen: tiefe dunkle Höhlen, weit aufgerissen, winzige Pupillen (Angst)
	for sx: float in [-0.052, 0.052]:
		BuildKit.sphere(head, 0.036, Vector3(sx, 0.055, 0.105), _m("socket"), Vector3(1.0, 1.25, 0.6), 10)
		BuildKit.sphere(head, 0.024, Vector3(sx, 0.055, 0.118), _m("eye"), Vector3(1.0, 1.2, 0.55), 10)
		BuildKit.sphere(head, 0.006, Vector3(sx + 0.004, 0.05, 0.131), _m("pupil"), Vector3.ONE, 6)
	# Lächeln: ein durchgehender, viel zu breiter Spalt bis fast an die Ohren, voller schmaler Zähne
	var n := 22
	for i in n:
		var t := (float(i) / float(n - 1)) * 2.0 - 1.0
		var a := t * 1.15
		var y := -0.085 + t * t * 0.07
		var pos := Vector3(sin(a) * 0.118, y, cos(a) * 0.118)
		var seg := BuildKit.box(head, Vector3(0.022, 0.024 - absf(t) * 0.012, 0.02), pos, _m("mouth"), false)
		seg.rotation.y = a
		var tooth := BuildKit.box(head, Vector3(0.006, 0.016 - absf(t) * 0.006, 0.006), pos + Vector3(sin(a), 0, cos(a)) * 0.006 + Vector3(0, 0.002, 0), _m("teeth"), false)
		tooth.rotation.y = a
	# Arme und Beine: je vier Glieder mit Knoten an jedem Gelenk
	for side: float in [-1.0, 1.0]:
		var sh := chest + Vector3(side * 0.16, -0.02, 0)
		var pts: Array
		if stand:
			pts = [sh, sh + Vector3(side * 0.22, -0.25, 0.25), sh + Vector3(side * 0.1, -0.15, 0.6), sh + Vector3(side * 0.05, 0.05, 0.85), sh + Vector3(side * -0.05, 0.1, 1.0)]
		else:
			pts = [sh, sh + Vector3(side * 0.3, 0.25, -0.1), sh + Vector3(side * 0.45, -0.2, 0.15), sh + Vector3(side * 0.35, -0.5, 0.45), sh + Vector3(side * 0.25, -0.92, 0.6)]
		_limb(root, pts, 0.035, skin, dark)
		# lange Finger am Ende
		var hand: Vector3 = pts[pts.size() - 1]
		for f in 4:
			var spread := (float(f) - 1.5) * 0.04
			bar(root, hand, hand + Vector3(spread * side + side * 0.02, -0.2 if not stand else 0.05, 0.12 if not stand else 0.2), 0.008, dark, 4)
		var hp := hip + Vector3(side * 0.1, 0, 0)
		var legs: Array
		if stand:
			legs = [hp, hp + Vector3(side * 0.08, -0.3, 0.12), hp + Vector3(side * 0.05, -0.62, -0.1), hp + Vector3(side * 0.06, -0.9, 0.05), hp + Vector3(side * 0.06, -1.05, 0.12)]
		else:
			legs = [hp, hp + Vector3(side * 0.32, 0.35, 0.25), hp + Vector3(side * 0.45, -0.1, 0.45), hp + Vector3(side * 0.35, -0.5, 0.2), hp + Vector3(side * 0.3, -0.55, 0.45)]
		_limb(root, legs, 0.04, skin, dark)
	return {"height": head.position.y + 0.18, "head": head}


static func _limb(root: Node3D, pts: Array, r: float, skin: Material, dark: Material) -> void:
	for i in pts.size() - 1:
		bar(root, pts[i], pts[i + 1], r * (1.0 - i * 0.12), skin, 8)
		BuildKit.sphere(root, r * 1.35, pts[i + 1], dark, Vector3.ONE, 8)


## Bild der wahren Gestalt für den Spiegel: blasses Gesicht mit Lächeln und Angst-Augen (128×160).
static func face_texture() -> ImageTexture:
	var img := Image.create(128, 160, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := Vector2(64, 76)
	for y in 160:
		for x in 128:
			var p := (Vector2(x, y) - c) / Vector2(44, 60)
			var d := p.length()
			if d < 1.0:
				var shade := 0.78 - p.y * 0.08 - d * 0.18
				img.set_pixel(x, y, Color(shade, shade * 0.93, shade * 0.86, clampf((1.0 - d) * 4.0, 0.0, 0.85)))
	for ex: int in [44, 84]:
		for y in range(50, 74):
			for x in range(ex - 11, ex + 12):
				var e := Vector2(float(x - ex) / 11.0, float(y - 62) / 12.0).length()
				if e < 1.0:
					img.set_pixel(x, y, Color(0.96, 0.95, 0.92, 0.95) if e > 0.22 else Color(0.02, 0.02, 0.02, 1))
	for x in range(26, 102):
		var t := float(x - 64) / 38.0
		var yy := int(104.0 - t * t * 12.0)
		for y in range(yy - 3, yy + 4):
			img.set_pixel(x, y, Color(0.12, 0.03, 0.03, 1) if absi(y - yy) > 1 else Color(0.9, 0.88, 0.8, 1))
	return ImageTexture.create_from_image(img)


## Falscher Schatten im Uhrlicht: lange Finger statt Stuhlbeinen (Decal-Textur, 128×128).
static func shadow_texture() -> ImageTexture:
	var img := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for f in 5:
		var base := Vector2(34 + f * 15, 120)
		var tip := Vector2(20 + f * 22, 8 + absi(f - 2) * 14)
		for s in 60:
			var t := float(s) / 59.0
			var p := base.lerp(tip, t) + Vector2(sin(t * 9.0 + f) * 3.0, 0)
			var r := lerpf(5.0, 2.0, t)
			for oy in range(-6, 7):
				for ox in range(-6, 7):
					if Vector2(ox, oy).length() <= r:
						var q := Vector2i(int(p.x) + ox, int(p.y) + oy)
						if q.x >= 0 and q.x < 128 and q.y >= 0 and q.y < 128:
							img.set_pixelv(q, Color(0, 0, 0, 0.9))
	return ImageTexture.create_from_image(img)
