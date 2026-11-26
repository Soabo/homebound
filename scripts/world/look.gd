class_name Look
extends RefCounted
## Grafikstil (Christian 25.11.: „zu pixelig und zu klötzchenhaft“).
##   retro = wie bisher: grobe Bildpunkte, wenige Farbstufen, Pixel-Texturen, scharfe Kistenkanten
##   klar  = volle Auflösung, weich gefilterte Texturen, abgeschrägte Kanten an allen Kisten, rundere Zylinder
## Wird beim Programmstart aus den Einstellungen gesetzt (Settings.look) – die Welt baut sich danach mit dem
## passenden Stil. Ein Wechsel im Menü wirkt für Texturen und Kanten erst beim nächsten Laden.

## Foto-Waldboden im klaren Stil (Befehlszeile -- --no-photo-floor schaltet ihn ab, für Vergleichsbilder)
static var forest_photo: bool = not ("--no-photo-floor" in OS.get_cmdline_user_args())
static var smooth := false

static var _bevel_cache: Dictionary = {}
static var _patched := false


static func set_style(style: String) -> void:
	smooth = style == "klar"


## Texturfilter für alle Materialien mit Pixel-Texturen
static func tex_filter() -> BaseMaterial3D.TextureFilter:
	return BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC if smooth else BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS


## Filter-Angabe für Shader-Texte (Gelände, Pflanzen, Wasser)
static func shader_code(code: String) -> String:
	if not smooth:
		return code
	return code.replace("filter_nearest_mipmap", "filter_linear_mipmap_anisotropic")


## Shader-Dateien mit Pixel-Filter auf den gewählten Stil umstellen (einmal vor dem Weltaufbau).
static func patch_shaders() -> void:
	if _patched or not smooth:
		return
	_patched = true
	for p in ["res://shaders/ground.gdshader", "res://shaders/foliage.gdshader", "res://shaders/water.gdshader"]:
		var sh := load(p) as Shader
		if sh:
			sh.code = shader_code(sh.code)


## Zylinder-/Kugelunterteilung: im klaren Stil runder (bewusst eckige Formen mit ≤ 4 Seiten bleiben)
static func segments(n: int) -> int:
	if smooth and n >= 5:
		return maxi(n, 14)
	return n


## Kiste mit abgeschrägten Kanten (nur klarer Stil). Gleiche Maße teilen sich ein Netz.
static func bevel_box(size: Vector3) -> Mesh:
	var mn := minf(size.x, minf(size.y, size.z))
	var b := clampf(mn * 0.14, 0.0, 0.022)
	var key := "%d_%d_%d" % [roundi(size.x * 1000.0), roundi(size.y * 1000.0), roundi(size.z * 1000.0)]
	if _bevel_cache.has(key):
		return _bevel_cache[key]
	var h := size * 0.5
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Hauptflächen (je Achse und Seite), eingerückt um b an den Rändern
	for ax in 3:
		var u := (ax + 1) % 3
		var v := (ax + 2) % 3
		for s: float in [-1.0, 1.0]:
			var pts: Array[Vector3] = []
			for c: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
				var p := Vector3.ZERO
				p[ax] = s * h[ax]
				p[u] = c.x * (h[u] - b)
				p[v] = c.y * (h[v] - b)
				pts.append(p)
			var n := Vector3.ZERO
			n[ax] = s
			HandKit.quad_flat(st, pts[0], pts[1], pts[2], pts[3], n)
	# Kantenschrägen: 12 Kanten, jeweils entlang einer Achse
	for ax in 3:
		var u := (ax + 1) % 3
		var v := (ax + 2) % 3
		for su: float in [-1.0, 1.0]:
			for sv: float in [-1.0, 1.0]:
				var q: Array[Vector3] = []
				for e: float in [-1.0, 1.0]:
					var a := Vector3.ZERO
					a[ax] = e * (h[ax] - b)
					a[u] = su * h[u]
					a[v] = sv * (h[v] - b)
					var c2 := Vector3.ZERO
					c2[ax] = e * (h[ax] - b)
					c2[u] = su * (h[u] - b)
					c2[v] = sv * h[v]
					q.append(a)
					q.append(c2)
				var n := Vector3.ZERO
				n[u] = su
				n[v] = sv
				HandKit.quad_flat(st, q[0], q[2], q[3], q[1], n.normalized())
	# Ecken: 8 kleine Dreiecke
	for sx: float in [-1.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				var a := Vector3(sx * h.x, sy * (h.y - b), sz * (h.z - b))
				var c3 := Vector3(sx * (h.x - b), sy * h.y, sz * (h.z - b))
				var d := Vector3(sx * (h.x - b), sy * (h.y - b), sz * h.z)
				var n := Vector3(sx, sy, sz).normalized()
				HandKit.tri(st, a, c3, d, n, n, n)
	var mesh := st.commit()
	_bevel_cache[key] = mesh
	return mesh


## Foto-Texturen (Christian 25.11.) für Materialien im klaren Stil: Farbe + Normalen + Rauheit.
## Sätze: "rock" = Fels (Felsbrocken, Granit, Höhle), "wood_floor" = Hüttenboden. Gibt true zurück, wenn gesetzt.
const PHOTO_SETS := {
	"rock": "res://assets/textures/ground/rock_",
	"wood_floor": "res://assets/textures/ground/wood_floor_",
	"logs": "res://assets/textures/ground/logs_",
	"furn_fine": "res://assets/textures/ground/furn_fine_",
	"furn_table": "res://assets/textures/ground/furn_table_",
	"furn_cabinet": "res://assets/textures/ground/furn_cabinet_",
	"furn_painted": "res://assets/textures/ground/furn_painted_",
	"gred": "res://assets/textures/ground/gred_",
	"plank_wall": "res://assets/textures/ground/plank_wall_",
}


## Kopie eines Materials mit Foto-Satz (nur im klaren Stil; sonst bleibt es das gezeichnete Material).
## tile_m = Kachelgröße in Metern (Materialien von tex_mat sind dreiseitig in Weltkoordinaten projiziert), tint = Farbe darüber.
static func photo_mat(base: Material, set_name: String, tile_m: float, tint: Color = Color.WHITE) -> Material:
	if not smooth or not forest_photo or not (base is StandardMaterial3D) or not PHOTO_SETS.has(set_name):
		return base
	var m := (base as StandardMaterial3D).duplicate() as StandardMaterial3D
	m.albedo_color = tint
	m.uv1_scale = Vector3.ONE / tile_m
	apply_photo(m, set_name)
	m.normal_scale = 0.5   # Möbel: Holzporen nur andeuten, sonst wirkt es wie Pressspan
	return m


static func apply_photo(m: StandardMaterial3D, set_name: String) -> bool:
	if not smooth or not forest_photo or m == null or not PHOTO_SETS.has(set_name):
		return false
	var base := String(PHOTO_SETS[set_name])
	m.albedo_texture = load(base + "color.jpg")
	m.normal_enabled = true
	m.normal_texture = load(base + "normal.jpg")
	m.normal_scale = 1.0
	m.roughness_texture = load(base + "rough.jpg")
	m.roughness = 1.0
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return true
