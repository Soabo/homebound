class_name Icons
extends RefCounted
## Kleine Symbole und Etiketten auf wichtigen Gegenständen, damit man sie erkennt
## (Zapfhahn auf Benzinkanistern, "FOOD" auf Konserven …). Alles als Pixelbild per Code,
## passend zum Retro-Look, und als flaches Schild (Quad) auf die Oberfläche geklebt.

const SIZE := 64

static var _cache: Dictionary = {}
static var _mats: Dictionary = {}

## 5x7-Pixelschrift für die benötigten Buchstaben
const FONT := {
	"F": ["11111", "10000", "10000", "11110", "10000", "10000", "10000"],
	"O": ["01110", "10001", "10001", "10001", "10001", "10001", "01110"],
	"D": ["11110", "10001", "10001", "10001", "10001", "10001", "11110"],
	"W": ["10001", "10001", "10001", "10101", "10101", "10101", "01010"],
	"A": ["01110", "10001", "10001", "11111", "10001", "10001", "10001"],
	"T": ["11111", "00100", "00100", "00100", "00100", "00100", "00100"],
	"E": ["11111", "10000", "10000", "11110", "10000", "10000", "11111"],
	"R": ["11110", "10001", "10001", "11110", "10100", "10010", "10001"],
	"N": ["10001", "11001", "10101", "10011", "10001", "10001", "10001"],
	"I": ["11111", "00100", "00100", "00100", "00100", "00100", "11111"],
	"L": ["10000", "10000", "10000", "10000", "10000", "10000", "11111"],
	"S": ["01111", "10000", "10000", "01110", "00001", "00001", "11110"],
	"U": ["10001", "10001", "10001", "10001", "10001", "10001", "01110"],
	"G": ["01111", "10000", "10000", "10111", "10001", "10001", "01110"],
}


static func texture(kind: String) -> Texture2D:
	if _cache.has(kind):
		return _cache[kind]
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	match kind:
		"fuel": _fuel(img)
		"food": _text_label(img, "FOOD", Color(0.93, 0.88, 0.72), Color(0.65, 0.12, 0.08), Color(0.08, 0.06, 0.05))
		"nails": _text_label(img, "NAILS", Color(0.85, 0.82, 0.75), Color(0.2, 0.25, 0.35), Color(0.06, 0.06, 0.08))
		"water": _water(img)
		"power": _power(img)
		"can": _can_label(img)
	var tex := ImageTexture.create_from_image(img)
	_cache[kind] = tex
	return tex


static func material(kind: String) -> StandardMaterial3D:
	if _mats.has(kind):
		return _mats[kind]
	var m := StandardMaterial3D.new()
	m.albedo_texture = texture(kind)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	m.roughness = 0.8
	_mats[kind] = m
	return m


## Klebt ein Symbol auf eine Fläche. normal = Richtung, in die das Schild zeigt (lokal zu parent).
static func decal(parent: Node, kind: String, size: float, pos: Vector3, normal: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(size, size)
	mi.mesh = qm
	mi.material_override = material(kind)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.position = pos + normal.normalized() * 0.002
	# QuadMesh zeigt nach +Z: so drehen, dass +Z = normal
	var n := normal.normalized()
	mi.basis = Basis.looking_at(-n, Vector3.UP if absf(n.y) < 0.95 else Vector3.FORWARD)
	return mi


## Konservendose mit umlaufendem Etikett (Drehkörper, Etikett über die UVs).
static func food_can(parent: Node, pos: Vector3, radius: float = 0.042, height: float = 0.11) -> MeshInstance3D:
	var key := "can_mat"
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_texture = texture("can")
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
		m.uv1_scale = Vector3(1, -1, 1)
		m.uv1_offset = Vector3(0, 1, 0)
		m.roughness = 0.5
		m.metallic = 0.3
		_mats[key] = m
	var mi := BuildKit.lathe(parent, PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.93, 0.0), Vector2(1.0, 0.03),
			Vector2(1.0, 0.97), Vector2(0.93, 1.0), Vector2(0.0, 1.0)]), pos, _mats[key], 12)
	mi.scale = Vector3(radius, height, radius)
	return mi


# --- Zeichnen -----------------------------------------------------------

static func _rect(img: Image, x0: int, y0: int, x1: int, y1: int, c: Color) -> void:
	for y in range(maxi(y0, 0), mini(y1, SIZE)):
		for x in range(maxi(x0, 0), mini(x1, SIZE)):
			img.set_pixel(x, y, c)


static func _disc(img: Image, cx: float, cy: float, r: float, c: Color) -> void:
	for y in SIZE:
		for x in SIZE:
			if Vector2(x + 0.5 - cx, y + 0.5 - cy).length() <= r:
				img.set_pixel(x, y, c)


static func _text(img: Image, text: String, cx: int, cy: int, scale: int, c: Color) -> void:
	var w := text.length() * 6 * scale - scale
	var x0 := cx - w / 2
	var y0 := cy - 7 * scale / 2
	for i in text.length():
		var glyph: Array = FONT.get(text[i], [])
		for gy in glyph.size():
			var row: String = glyph[gy]
			for gx in row.length():
				if row[gx] == "1":
					_rect(img, x0 + (i * 6 + gx) * scale, y0 + gy * scale, x0 + (i * 6 + gx + 1) * scale, y0 + (gy + 1) * scale, c)


## Gelbes Warnschild mit schwarzem Zapfhahn.
static func _fuel(img: Image) -> void:
	var black := Color(0.06, 0.05, 0.04)
	var yellow := Color(0.95, 0.72, 0.1)
	_rect(img, 4, 4, 60, 60, black)
	_rect(img, 7, 7, 57, 57, yellow)
	# Schlauch von links unten
	_rect(img, 12, 27, 18, 50, black)
	_rect(img, 12, 27, 24, 32, black)
	# Griffstück
	_rect(img, 22, 22, 42, 32, black)
	# Zapfrohr nach rechts, vorne nach unten geknickt
	_rect(img, 40, 24, 50, 28, black)
	_rect(img, 47, 26, 51, 38, black)
	# Abzugsbügel unter dem Griff
	_rect(img, 24, 32, 27, 42, black)
	_rect(img, 24, 39, 40, 42, black)
	_rect(img, 37, 32, 40, 42, black)
	# Tropfen
	_disc(img, 49.0, 44.0, 2.2, black)


## Etikett mit Text, oben und unten farbige Streifen.
static func _text_label(img: Image, text: String, paper: Color, band: Color, ink: Color) -> void:
	_rect(img, 2, 14, 62, 50, paper)
	_rect(img, 2, 14, 62, 19, band)
	_rect(img, 2, 45, 62, 50, band)
	_text(img, text, 32, 32, 2, ink)


## Blauer Kreis mit weißem Wassertropfen.
static func _water(img: Image) -> void:
	_disc(img, 32, 32, 28, Color(0.06, 0.1, 0.18))
	_disc(img, 32, 32, 25.5, Color(0.2, 0.5, 0.85))
	var white := Color(0.95, 0.97, 1.0)
	_disc(img, 32, 38, 11, white)
	for y in range(14, 38):
		var half := (y - 14) * 0.45
		_rect(img, int(32 - half), y, int(32 + half + 1), y + 1, white)
	_disc(img, 28, 39, 3, Color(0.75, 0.88, 1.0))


## Blitz auf gelbem Grund (Strom/Generator).
static func _power(img: Image) -> void:
	var black := Color(0.06, 0.05, 0.04)
	_rect(img, 4, 4, 60, 60, black)
	_rect(img, 7, 7, 57, 57, Color(0.95, 0.72, 0.1))
	for y in range(12, 33):
		var x := 38 - (y - 12) * 0.7
		_rect(img, int(x - 5), y, int(x + 4), y + 1, black)
	_rect(img, 20, 30, 44, 35, black)
	for y in range(33, 54):
		var x := 36 - (y - 33) * 0.7
		_rect(img, int(x - 4), y, int(x + 5), y + 1, black)


## Dosenetikett: Blechränder, Papier mit rotem Band und zweimal "FOOD" ringsum.
static func _can_label(img: Image) -> void:
	var tin := Color(0.62, 0.62, 0.6)
	_rect(img, 0, 0, SIZE, SIZE, tin)
	_rect(img, 0, 8, SIZE, 56, Color(0.9, 0.84, 0.66))
	_rect(img, 0, 12, SIZE, 22, Color(0.7, 0.14, 0.09))
	_rect(img, 0, 44, SIZE, 50, Color(0.7, 0.14, 0.09))
	_text(img, "FOOD", 16, 33, 1, Color(0.08, 0.06, 0.05))
	_text(img, "FOOD", 48, 33, 1, Color(0.08, 0.06, 0.05))
	for x in SIZE:
		img.set_pixel(x, 2, tin * 0.7)
		img.set_pixel(x, 61, tin * 0.7)
