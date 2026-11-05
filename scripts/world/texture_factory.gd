class_name TextureFactory
extends RefCounted
## Erzeugt kleine Pixel-Texturen per Code (Retro-Look, scharfe Pixel).
## Jede Textur wird einmal erzeugt und dann wiederverwendet.

const SIZE := 64

static var _cache: Dictionary = {}


static func get_texture(kind: String) -> Texture2D:
	if _cache.has(kind):
		return _cache[kind]
	var img: Image
	match kind:
		"planks_v": img = _planks(false, Color(0.5, 0.33, 0.19), 8)
		"planks_h": img = _planks(true, Color(0.47, 0.31, 0.18), 8)
		"floor": img = _planks(true, Color(0.42, 0.28, 0.17), 11)
		"logs": img = _logs()
		"bark": img = _bark()
		"stone": img = _stone(Color(0.46, 0.44, 0.41), 14)
		"stone_dark": img = _stone(Color(0.3, 0.27, 0.25), 18)
		"shingles": img = _shingles()
		"fabric": img = _fabric(Color(0.42, 0.42, 0.36))
		"fabric_red": img = _fabric(Color(0.45, 0.14, 0.12))
		"blanket": img = _checker(Color(0.32, 0.16, 0.14), Color(0.22, 0.24, 0.3))
		"rug": img = _rug()
		"metal": img = _metal()
		"grass_ground": img = _ground()
		"fern": img = _fern()
		"grass_blades": img = _grass_blades()
		"water": img = _water()
		"needles": img = _needles()
		"leaves": img = _leaves()
		"log_end": img = _log_end()
		"moss": img = _moss()
		"corn_leaf": img = _corn_leaf()
		"car_paint": img = _car_paint()
		"alien_skin": img = _alien_skin()
		"glyphs": img = _glyphs()
		_:
			img = Image.create(4, 4, false, Image.FORMAT_RGBA8)
			img.fill(Color.MAGENTA)
	var tex := ImageTexture.create_from_image(img)
	_cache[kind] = tex
	return tex


# --- Generatoren --------------------------------------------------------

static func _img() -> Image:
	return Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)


static func _rng(seed_value: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	return r


## Bretter mit Fugen, Maserung, Ästen und Nägeln.
static func _planks(horizontal: bool, base: Color, board: int) -> Image:
	var img := _img()
	var r := _rng(board * 31 + (1 if horizontal else 0))
	var tones: Array[float] = []
	var offsets: Array[int] = []
	for i in SIZE / board + 1:
		tones.append(r.randf_range(0.78, 1.18))
		offsets.append(r.randi() % SIZE)
	for y in SIZE:
		for x in SIZE:
			var across := y if horizontal else x
			var along := x if horizontal else y
			var b := across / board
			var inb := across % board
			var c := base * tones[b]
			var grain := sin(float(along) * 0.35 + float(inb) * 1.7 + float(b) * 5.0) * 0.06
			grain += (r.randf() - 0.5) * 0.07
			c = c * (1.0 + grain)
			if inb == 0:
				c = base * 0.35
			elif inb == 1:
				c = c * 0.82
			# Stoß der Bretter
			if (along + offsets[b]) % SIZE == 0:
				c = base * 0.4
			c.a = 1.0
			img.set_pixel(x, y, c)
	# Äste
	for k in 3:
		var kx := r.randi() % SIZE
		var ky := r.randi() % SIZE
		for dy in range(-2, 3):
			for dx in range(-2, 3):
				if dx * dx + dy * dy <= 4:
					var px := (kx + dx + SIZE) % SIZE
					var py := (ky + dy + SIZE) % SIZE
					img.set_pixel(px, py, base * (0.45 if dx * dx + dy * dy <= 1 else 0.65))
	# Nägel
	for b in SIZE / board:
		for along: int in [4, SIZE / 2 + 4]:
			var x := along if horizontal else b * board + board / 2
			var y := b * board + board / 2 if horizontal else along
			img.set_pixel(x % SIZE, y % SIZE, Color(0.12, 0.11, 0.1))
	return img


## Rundhölzer: Rinde mit hellen Schälstellen, Streifen entlang u.
static func _logs() -> Image:
	var img := _img()
	var r := _rng(77)
	var base := Color(0.4, 0.27, 0.16)
	for y in SIZE:
		for x in SIZE:
			var streak := sin(float(y) * 0.9 + sin(float(x) * 0.15) * 2.0) * 0.08
			var c := base * (1.0 + streak + (r.randf() - 0.5) * 0.12)
			c.a = 1.0
			img.set_pixel(x, y, c)
	for k in 14:
		var sx := r.randi() % SIZE
		var sy := r.randi() % SIZE
		var w := r.randi_range(4, 12)
		for i in w:
			img.set_pixel((sx + i) % SIZE, sy, Color(0.62, 0.48, 0.32))
			img.set_pixel((sx + i) % SIZE, (sy + 1) % SIZE, Color(0.55, 0.41, 0.27))
	return img


static func _bark() -> Image:
	var img := _img()
	var r := _rng(5)
	var base := Color(0.25, 0.19, 0.14)
	var cols: Array[float] = []
	for x in SIZE:
		cols.append(r.randf_range(0.7, 1.25))
	for y in SIZE:
		for x in SIZE:
			var crack := 0.55 if (x + int(sin(float(y) * 0.2) * 2.0)) % 7 == 0 else 1.0
			var c := base * cols[x] * crack * (1.0 + (r.randf() - 0.5) * 0.15)
			c.a = 1.0
			img.set_pixel(x, y, c)
	return img


## Bruchsteine: Zellen um Zufallspunkte, dunkle Fugen dazwischen.
static func _stone(base: Color, count: int) -> Image:
	var img := _img()
	var r := _rng(count * 13)
	var pts: Array[Vector2] = []
	var shades: Array[float] = []
	for i in count:
		pts.append(Vector2(r.randf() * SIZE, r.randf() * SIZE))
		shades.append(r.randf_range(0.7, 1.25))
	for y in SIZE:
		for x in SIZE:
			var p := Vector2(x, y)
			var d1 := 1e9
			var d2 := 1e9
			var idx := 0
			for i in count:
				for ox in [-SIZE, 0, SIZE]:
					for oy in [-SIZE, 0, SIZE]:
						var d := p.distance_to(pts[i] + Vector2(ox, oy))
						if d < d1:
							d2 = d1
							d1 = d
							idx = i
						elif d < d2:
							d2 = d
			var c := base * shades[idx] * (1.0 + (r.randf() - 0.5) * 0.12)
			if d2 - d1 < 1.6:
				c = base * 0.35
			elif d2 - d1 < 3.0:
				c = c * 0.8
			c.a = 1.0
			img.set_pixel(x, y, c)
	return img


## Holzschindeln mit Moosflecken.
static func _shingles() -> Image:
	var img := _img()
	var r := _rng(9)
	var base := Color(0.27, 0.21, 0.17)
	var moss := Color(0.22, 0.3, 0.13)
	var row_h := 8
	var w := 10
	for y in SIZE:
		var row := y / row_h
		var shift := (row % 2) * (w / 2)
		for x in SIZE:
			var col := (x + shift) / w
			var tone := 0.75 + float((row * 7 + col * 13) % 9) / 16.0
			var c := base * tone
			var iy := y % row_h
			if iy == row_h - 1 or (x + shift) % w == 0:
				c = base * 0.35
			elif iy >= row_h - 3:
				c = c * 0.85
			var m := sin(float(x) * 0.21) * sin(float(y) * 0.17 + 1.0) + r.randf() * 0.5
			if m > 0.75:
				c = moss * (0.8 + r.randf() * 0.4)
			c.a = 1.0
			img.set_pixel(x, y, c)
	return img


static func _fabric(base: Color) -> Image:
	var img := _img()
	var r := _rng(int(base.r * 100))
	for y in SIZE:
		for x in SIZE:
			var weave := 0.92 if (x + y) % 2 == 0 else 1.06
			var c := base * weave * (1.0 + (r.randf() - 0.5) * 0.06)
			c.a = 1.0
			img.set_pixel(x, y, c)
	return img


static func _checker(a: Color, b: Color) -> Image:
	var img := _img()
	for y in SIZE:
		for x in SIZE:
			var cx := (x / 8) % 2
			var cy := (y / 8) % 2
			var c := a if cx == cy else b
			if x % 8 == 0 or y % 8 == 0:
				c = c.lightened(0.15)
			c = c * (0.94 if (x + y) % 2 == 0 else 1.04)
			c.a = 1.0
			img.set_pixel(x, y, c)
	return img


static func _rug() -> Image:
	var img := _img()
	var base := Color(0.4, 0.13, 0.1)
	var border := Color(0.7, 0.55, 0.3)
	var dark := Color(0.15, 0.1, 0.12)
	for y in SIZE:
		for x in SIZE:
			var ex := mini(x, SIZE - 1 - x)
			var ey := mini(y, SIZE - 1 - y)
			var e := mini(ex, ey)
			var c := base
			if e < 3:
				c = dark
			elif e < 5:
				c = border
			elif e < 7:
				c = dark
			else:
				var cx := absi(x - SIZE / 2)
				var cy := absi(y - SIZE / 2)
				if (cx + cy) % 10 < 2:
					c = border * 0.9
				elif cx + cy < 8:
					c = dark
			c = c * (0.93 if (x + y) % 2 == 0 else 1.05)
			c.a = 1.0
			img.set_pixel(x, y, c)
	return img


static func _metal() -> Image:
	var img := _img()
	var r := _rng(3)
	var base := Color(0.28, 0.27, 0.27)
	for y in SIZE:
		for x in SIZE:
			var c := base * (1.0 + (r.randf() - 0.5) * 0.15)
			if r.randf() < 0.05:
				c = Color(0.38, 0.22, 0.12)
			c.a = 1.0
			img.set_pixel(x, y, c)
	return img


## Bodentextur: grobe Halme und Erdflecken (wird mit der Geländefarbe multipliziert).
static func _ground() -> Image:
	var img := _img()
	var r := _rng(21)
	for y in SIZE:
		for x in SIZE:
			var v := 0.85 + r.randf() * 0.3
			if r.randf() < 0.08:
				v = 0.6
			if r.randf() < 0.05:
				v = 1.3
			img.set_pixel(x, y, Color(v, v, v * 0.95, 1.0))
	return img


## Farnwedel auf transparentem Grund (für Pflanzen-Karten).
static func _fern() -> Image:
	var img := _img()
	img.fill(Color(0, 0, 0, 0))
	var r := _rng(8)
	for frond in 5:
		var angle := lerpf(-0.9, 0.9, float(frond) / 4.0) + r.randf_range(-0.1, 0.1)
		var length := r.randf_range(40.0, 58.0)
		var dir := Vector2(sin(angle), -cos(angle))
		var base := Vector2(SIZE / 2.0, SIZE - 1.0)
		for s in int(length):
			var t := float(s) / length
			var bend := Vector2(dir.x, dir.y + t * 0.45).normalized()
			var p := base + bend * s
			var g := Color(0.2, 0.4, 0.12).lerp(Color(0.32, 0.5, 0.16), t)
			_plot(img, p, g)
			if s % 3 == 0 and t > 0.1:
				var leaf := int((1.0 - t) * 9.0) + 2
				var n := Vector2(-bend.y, bend.x)
				for l in leaf:
					var droop := Vector2(0, l * 0.25)
					_plot(img, p + n * l + droop, g * 0.9)
					_plot(img, p - n * l + droop, g * 0.85)
	return img


static func _grass_blades() -> Image:
	var img := _img()
	img.fill(Color(0, 0, 0, 0))
	var r := _rng(14)
	for b in 22:
		var x0 := r.randf_range(4.0, SIZE - 4.0)
		var h := r.randf_range(24.0, 62.0)
		var lean := r.randf_range(-0.4, 0.4)
		var col := Color(0.22, 0.36, 0.11).lerp(Color(0.42, 0.45, 0.18), r.randf())
		for s in int(h):
			var t := float(s) / h
			var p := Vector2(x0 + lean * s * t, SIZE - 1 - s)
			_plot(img, p, col * (0.7 + t * 0.4))
			if t < 0.4:
				_plot(img, p + Vector2(1, 0), col * 0.75)
	return img


static func _water() -> Image:
	var img := _img()
	var r := _rng(2)
	for y in SIZE:
		for x in SIZE:
			var w := sin(float(x) * 0.3 + sin(float(y) * 0.2) * 2.0) * 0.5 + 0.5
			var c := Color(0.14, 0.2, 0.2).lerp(Color(0.32, 0.4, 0.38), w * w)
			if r.randf() < 0.02:
				c = Color(0.6, 0.66, 0.62)
			c.a = 1.0
			img.set_pixel(x, y, c)
	return img


## Tannennadeln: dunkle, schräge Nadelbüschel (wird mit der Baumfarbe multipliziert).
static func _needles() -> Image:
	var img := _img()
	var r := _rng(31)
	img.fill(Color(0.55, 0.6, 0.55))
	for k in 260:
		var p := Vector2(r.randf() * SIZE, r.randf() * SIZE)
		var len := r.randi_range(3, 7)
		var dir := 1 if r.randf() < 0.5 else -1
		var v := r.randf_range(0.7, 1.5)
		for i in len:
			var x := (int(p.x) + i * dir + SIZE) % SIZE
			var y := (int(p.y) + i + SIZE) % SIZE
			img.set_pixel(x, y, Color(v, v * 1.05, v * 0.85))
	for k in 140:
		img.set_pixel(r.randi() % SIZE, r.randi() % SIZE, Color(0.3, 0.32, 0.28))
	return img


## Laub: viele kleine Blätter auf transparentem Grund (für Laubkronen-Karten).
static func _leaves() -> Image:
	var img := _img()
	img.fill(Color(0, 0, 0, 0))
	var r := _rng(17)
	for k in 170:
		var c := Vector2(r.randf_range(4, SIZE - 4), r.randf_range(4, SIZE - 4))
		# Runde Gesamtform der Krone
		if c.distance_to(Vector2(SIZE / 2.0, SIZE / 2.0)) > SIZE * 0.47:
			continue
		var col := Color(0.55, 0.8, 0.35).lerp(Color(0.95, 1.05, 0.55), r.randf()) * r.randf_range(0.6, 1.1)
		var a := r.randf() * PI
		for dy in range(-3, 4):
			for dx in range(-3, 4):
				var q := Vector2(dx, dy).rotated(a)
				if (q.x * q.x) / 9.0 + (q.y * q.y) / 2.5 <= 1.0:
					_plot(img, c + Vector2(dx, dy), col * (0.85 if dy > 0 else 1.0))
	return img


## Jahresringe für Stammenden.
static func _log_end() -> Image:
	var img := _img()
	var r := _rng(4)
	var center := Vector2(SIZE / 2.0, SIZE / 2.0)
	for y in SIZE:
		for x in SIZE:
			var d := Vector2(x, y).distance_to(center) / (SIZE * 0.5)
			var ring := sin(d * 38.0 + sin(atan2(y - center.y, x - center.x) * 3.0) * 0.6) * 0.5 + 0.5
			var c := Color(0.68, 0.52, 0.34).lerp(Color(0.52, 0.37, 0.22), ring)
			if d > 0.88:
				c = Color(0.28, 0.2, 0.14)
			if absf(x - center.x) < 1.0 and d < 0.6 and r.randf() < 0.7:
				c = c * 0.6
			c = c * (1.0 + (r.randf() - 0.5) * 0.08)
			c.a = 1.0
			img.set_pixel(x, y, c)
	return img


static func _moss() -> Image:
	var img := _img()
	var r := _rng(12)
	for y in SIZE:
		for x in SIZE:
			var v := r.randf_range(0.7, 1.2)
			var c := Color(0.25, 0.36, 0.14) * v
			if r.randf() < 0.06:
				c = Color(0.42, 0.5, 0.2)
			c.a = 1.0
			img.set_pixel(x, y, c)
	return img


## Fremde Zeichen: Kreise, Bögen und Linien, hell auf dunkel (Symbolplatte, Gerätedisplay).
static func _glyphs() -> Image:
	var img := _img()
	var r := _rng(91)
	img.fill(Color(0.08, 0.09, 0.1))
	var lite := Color(0.55, 0.85, 0.9)
	for k in 6:
		var c := Vector2(8 + (k % 3) * 24, 14 + (k / 3) * 30)
		var rad := r.randf_range(4.0, 8.0)
		for a in 64:
			if r.randf() < 0.18:
				continue
			var t := TAU * a / 64.0
			_plot(img, c + Vector2(cos(t), sin(t)) * rad, lite)
		# Speichen und Punkte
		for s in r.randi_range(1, 3):
			var t := r.randf() * TAU
			for q in int(rad) + 4:
				_plot(img, c + Vector2(cos(t), sin(t)) * q, lite * 0.85)
		_plot(img, c, lite)
	# Verbindungslinien
	for k in 3:
		var a := Vector2(r.randf_range(4, 60), r.randf_range(4, 60))
		var b := Vector2(r.randf_range(4, 60), r.randf_range(4, 60))
		for q in 40:
			_plot(img, a.lerp(b, q / 40.0), lite * 0.6)
	return img


## Haut der Kreatur: fahles Grau mit Flecken, feinen Falten und dunklen Adern.
static func _alien_skin() -> Image:
	var img := _img()
	var r := _rng(66)
	var n := FastNoiseLite.new()
	n.seed = 66
	n.frequency = 0.09
	for y in SIZE:
		for x in SIZE:
			var v := n.get_noise_2d(x, y) * 0.5 + 0.5
			var c := Color(0.6, 0.63, 0.58).lerp(Color(0.48, 0.5, 0.47), v)
			# feine Querfalten
			if (y + int(n.get_noise_2d(x * 2.0, 7.0) * 3.0)) % 9 == 0:
				c *= 0.88
			c *= r.randf_range(0.95, 1.04)
			img.set_pixel(x, y, Color(c.r, c.g, c.b, 1.0))
	# Adern: verzweigte dunkle Linien
	for k in 7:
		var p := Vector2(r.randf_range(0, SIZE), r.randf_range(0, SIZE))
		var a := r.randf() * TAU
		for s in 40:
			a += r.randf_range(-0.45, 0.45)
			p += Vector2(cos(a), sin(a))
			var px := posmod(int(p.x), SIZE)
			var py := posmod(int(p.y), SIZE)
			var old := img.get_pixel(px, py)
			img.set_pixel(px, py, old.lerp(Color(0.32, 0.36, 0.42), 0.55))
	return img


## Verblichener türkiser Autolack mit Rostflecken und Laufspuren nach unten.
static func _car_paint() -> Image:
	var img := _img()
	var r := _rng(33)
	var rust := Image.create(SIZE, SIZE, false, Image.FORMAT_RF)
	# Rostflecken als Keime, die nach unten "auslaufen"
	var spots: Array[Vector3] = []
	for k in 9:
		spots.append(Vector3(r.randf_range(0, SIZE), r.randf_range(0, SIZE), r.randf_range(3.0, 8.0)))
	for y in SIZE:
		for x in SIZE:
			var v := 0.0
			for sp in spots:
				var dx := wrapf(x - sp.x, -SIZE * 0.5, SIZE * 0.5)
				var dy := wrapf(y - sp.y, -SIZE * 0.5, SIZE * 0.5)
				var d := Vector2(dx, dy * (0.45 if dy > 0 else 1.0)).length()
				v = maxf(v, 1.0 - d / sp.z)
			v += (r.randf() - 0.5) * 0.3
			var c := Color(0.46, 0.6, 0.6) * r.randf_range(0.92, 1.05)
			if v > 0.55:
				c = Color(0.55, 0.3, 0.16) * r.randf_range(0.7, 1.1)
			elif v > 0.35:
				c = c.lerp(Color(0.7, 0.5, 0.35), 0.6)
			if r.randf() < 0.01:
				c = Color(0.95, 0.95, 0.92)
			img.set_pixel(x, y, Color(c.r, c.g, c.b, 1.0))
	return img


## Maisblatt: oben die Spitze, Mittelrippe, Längsadern, trockene Ränder und Risse.
static func _corn_leaf() -> Image:
	var img := _img()
	img.fill(Color(0, 0, 0, 0))
	var r := _rng(21)
	for y in SIZE:
		var t := float(y) / SIZE
		var half := (SIZE * 0.5 - 1.0) * clampf(t * 3.2, 0.08, 1.0)
		for x in SIZE:
			var dx := absf(x - SIZE * 0.5 + 0.5)
			if dx > half:
				continue
			# kleine Risse und Fraßlöcher
			if r.randf() < 0.012 or (dx > half - 2.0 and r.randf() < 0.25):
				continue
			var c := Color(0.92, 0.95, 0.85) * r.randf_range(0.9, 1.05)
			if dx < 1.0:
				c = Color(1.0, 1.0, 0.9)
			elif int(dx) % 5 == 0:
				c = c * 0.82
			# vertrocknete Ränder
			if dx > half - 4.0:
				c = c.lerp(Color(0.75, 0.6, 0.4), 0.6)
			img.set_pixel(x, y, Color(c.r, c.g, c.b, 1.0))
	return img


static func _plot(img: Image, p: Vector2, c: Color) -> void:
	var x := int(p.x)
	var y := int(p.y)
	if x < 0 or y < 0 or x >= SIZE or y >= SIZE:
		return
	c.a = 1.0
	img.set_pixel(x, y, c)
