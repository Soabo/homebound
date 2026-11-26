class_name FleshKit
extends RefCounted
## Bausteine für organische Gegner-Figuren (Christian 23.11.: Sucher und Zerfleischer „wesentlich organischer und
## detaillierter“): weich gebogene, sich verjüngende Glieder (Catmull-Rom-Kurve + Schlauch), Muskelstränge,
## Knochenpunkte, Rippenbögen, Adern, Finger mit Knöcheln. Alles entsteht aus Code – keine Modelldateien.


## Hautmaterial: Textur am Körper festgemacht (wandert nicht beim Laufen), leicht feucht, mit Randlicht.
static func skin(tint: Color, roughness: float = 0.6, tex_m: float = 0.35) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = TextureFactory.get_texture("alien_skin")
	m.albedo_color = tint
	m.roughness = maxf(roughness, 0.55)   # matt-feucht statt Plastikglanz
	m.metallic_specular = 0.35
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	m.uv1_triplanar = true
	m.uv1_world_triplanar = false
	m.uv1_triplanar_sharpness = 3.0
	m.uv1_scale = Vector3.ONE / tex_m
	m.rim_enabled = true
	m.rim = 0.12
	m.rim_tint = 0.7
	return m


## Haut aus einem Foto-Satz (assets/textures/creatures/<name>_color|normal|rough.jpg), z. B. „mauler_skin“ (Christian 26.11.).
## tile_m = Kachelgröße in m, tint färbt (weiß = wie im Bild).
static func photo_skin(name: String, tint: Color = Color.WHITE, tile_m: float = 0.35) -> StandardMaterial3D:
	var base := "res://assets/textures/creatures/" + name + "_"
	if not ResourceLoader.exists(base + "color.jpg"):
		return skin(tint, 0.6, tile_m)
	var m := skin(tint, 0.6, tile_m)
	m.albedo_texture = load(base + "color.jpg")
	m.normal_enabled = true
	m.normal_texture = load(base + "normal.jpg")
	m.normal_scale = 1.2
	m.roughness_texture = load(base + "rough.jpg")
	m.roughness = 1.0
	m.metallic_specular = 0.5
	m.rim = 0.18   # dunkle Haut: Umriss im Licht trotzdem erkennbar
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m


## Glatte Kurve durch die Stützpunkte (Catmull-Rom), `steps` Zwischenpunkte je Abschnitt.
static func smooth(pts: Array, steps: int = 4) -> PackedVector3Array:
	var out := PackedVector3Array()
	var n := pts.size()
	if n < 3:
		for p: Vector3 in pts:
			out.append(p)
		return out
	for i in n - 1:
		var p0: Vector3 = pts[maxi(i - 1, 0)]
		var p1: Vector3 = pts[i]
		var p2: Vector3 = pts[i + 1]
		var p3: Vector3 = pts[mini(i + 2, n - 1)]
		for s in steps:
			var t := float(s) / steps
			var t2 := t * t
			var t3 := t2 * t
			out.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	out.append(pts[n - 1])
	return out


## Ein Glied entlang der Stützpunkte. rs = Radius je Stützpunkt (Zahl = rund, Vector2 = oval: Breite/Tiefe).
## up = Richtung, in die die Tiefe zeigt (für ovale Querschnitte).
static func limb(parent: Node, pts: Array, rs: Array, mat: Material, sides: int = 12, steps: int = 4,
		up: Vector3 = Vector3(0, 0, 1)) -> MeshInstance3D:
	var path := smooth(pts, steps)
	var radii := PackedVector2Array()
	var n := pts.size()
	for i in path.size():
		var f := float(i) / float(steps) if n >= 3 else float(i) * float(n - 1) / maxf(path.size() - 1, 1)
		var a := mini(int(f), n - 1)
		var b := mini(a + 1, n - 1)
		var t := smoothstep(0.0, 1.0, f - a)
		radii.append(_r2(rs[a]).lerp(_r2(rs[b]), t))
	return HandKit.loft(parent, path, radii, mat, sides, up)


static func _r2(v) -> Vector2:
	return v if v is Vector2 else Vector2(float(v), float(v))


## Rundliche Form (Gelenk, Muskelbauch, Schädel): Kugel mit vielen Flächen, skaliert und gedreht.
static func bulb(parent: Node, pos: Vector3, size: Vector3, mat: Material, rot: Vector3 = Vector3.ZERO, seg: int = 18) -> MeshInstance3D:
	var mi := BuildKit.sphere(parent, 1.0, pos, mat, size, seg)
	mi.rotation_degrees = rot
	return mi


## Muskelstrang oder Sehne von a nach b: dünn an den Enden, in der Mitte dick (bulge 0..1 = wo der Bauch sitzt).
static func spindle(parent: Node, a: Vector3, b: Vector3, r: float, mat: Material, bulge: float = 0.45, sides: int = 10) -> MeshInstance3D:
	var mid := a.lerp(b, bulge)
	return limb(parent, [a, a.lerp(b, bulge * 0.5), mid, mid.lerp(b, 0.5), b], [r * 0.25, r * 0.75, r, r * 0.65, r * 0.2], mat, sides, 3)


## Ader: dünner, leicht geschlängelter Strang auf der Haut.
static func vein(parent: Node, pts: Array, r: float, mat: Material, rng: RandomNumberGenerator) -> void:
	var wig: Array = []
	for i in pts.size():
		var p: Vector3 = pts[i]
		if i > 0 and i < pts.size() - 1:
			p += Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * r * 1.5
		wig.append(p)
	limb(parent, wig, [r * 0.4, r, r, r * 0.4], mat, 5, 3)


## Finger aus Gliedern: base = Ansatz, dir = Richtung, lens = Gliedlängen, curl = Krümmung je Gelenk (Grad, um side),
## r = Dicke am Ansatz. Knöchel als kleine Verdickung, am Ende eine Kralle/ein Nagel (tip_mat).
static func finger(parent: Node, base: Vector3, dir: Vector3, side: Vector3, lens: Array, curl: float, r: float,
		mat: Material, tip_mat: Material, tip_len: float = 0.0) -> void:
	var pts: Array = [base]
	var rs: Array = [r]
	var d := dir.normalized()
	var p := base
	for i in lens.size():
		d = d.rotated(side.normalized(), deg_to_rad(curl))
		p += d * float(lens[i])
		pts.append(p)
		rs.append(r * (0.85 - 0.15 * i))
		if i < lens.size() - 1:
			bulb(parent, p, Vector3.ONE * r * 0.95, mat, Vector3.ZERO, 8)
	limb(parent, pts, rs, mat, 7, 3)
	if tip_len > 0.0:
		# Kralle: gebogene, spitz zulaufende Sichel
		var t0 := p
		var cd := d
		var cpts: Array = [t0]
		var crs: Array = [r * 0.7]
		for k in 4:
			cd = cd.rotated(side.normalized(), deg_to_rad(curl * 0.9 + 8.0))
			t0 += cd * tip_len / 4.0
			cpts.append(t0)
			crs.append(r * 0.7 * (1.0 - (k + 1) / 4.5))
		limb(parent, cpts, crs, tip_mat, 6, 3)


## Rippenbogen vorn um den Brustkorb: Mitte c, halbe Breite w, Tiefe d, fällt nach vorn um drop ab.
static func rib(parent: Node, c: Vector3, w: float, d: float, drop: float, r: float, mat: Material, from_deg: float = 15.0, to_deg: float = 165.0) -> void:
	var pts: Array = []
	for i in 9:
		var a := deg_to_rad(lerpf(from_deg, to_deg, i / 8.0))
		var front := sin(a)
		pts.append(c + Vector3(cos(a) * w, -drop * front, front * d))
	limb(parent, pts, [r * 0.5, r, r, r, r, r, r, r, r * 0.5], mat, 5, 2)
