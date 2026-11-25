class_name DrownedVillage
extends RefCounted
## Versunkenes Dorf (Grund des abgelassenen Stausees Altenreuth), neu gebaut am 14.11.2026 (Christian: „Kirche und Häuser
## grafisch nicht ansprechend, in die Kirche kommt man nicht rein“).
## Hausruinen mit Tür- und Fensteröffnungen, zackig abgebrochenen Mauerkronen, Eckquadern, dunklem Schlammrand bis zur
## alten Wasserlinie, eingestürzten Dachbalken und Schutt. Kirche mit begehbarem Turm (Durchgang), Strebepfeilern,
## hohen Fenstern, halb eingestürztem Dachstuhl, Bänken, Altar und Glocke.
## Namen der Knoten (Church, Ruin_N) und die Lage der Funde/Notizen bleiben wie vorher (Spielstand).

const WATERLINE := 1.8


static func _silt() -> Material:
	return BuildKit.tex_mat("stone_dark", 0.7, Color(0.62, 0.56, 0.44))


static func _wall_stone(tone: float) -> Material:
	return BuildKit.tex_mat("stone", 0.7, Color(0.92, 0.9, 0.84) * tone)


## Mauer mit Öffnungen, unten bis zur Wasserlinie verschlammt (dunkler), darüber Stein.
static func wall2(parent: Node3D, a: Vector2, b: Vector2, h: float, t: float, openings: Array, mat: Material, n: String) -> void:
	var low: Array = []
	var high: Array = []
	for o: Vector4 in openings:
		if o.z < WATERLINE:
			low.append(Vector4(o.x, o.y, o.z, minf(o.w, WATERLINE + 0.001) if o.w < WATERLINE else WATERLINE + 0.001))
		if o.w > WATERLINE:
			high.append(Vector4(o.x, o.y, maxf(o.z - WATERLINE, 0.0), o.w - WATERLINE))
	BuildKit.wall(parent, a, b, 0.0, minf(h, WATERLINE), t, _silt(), low, n + "_Low")
	if h > WATERLINE:
		BuildKit.wall(parent, a, b, WATERLINE, h - WATERLINE, t, mat, high, n)


## Zackig abgebrochene Mauerkrone: Steinblöcke unterschiedlicher Höhe auf der Mauer (nicht über Öffnungen).
static func ragged_top(parent: Node3D, a: Vector2, b: Vector2, top: float, t: float, extra: float, mat: Material, rng: RandomNumberGenerator) -> void:
	var d := b - a
	var len := d.length()
	var dir := d / len
	var x := 0.0
	while x < len - 0.3:
		var seg := minf(rng.randf_range(0.5, 1.4), len - x)
		var hh := rng.randf_range(0.0, extra) * (1.0 - absf((x + seg * 0.5) / len - 0.5) * 0.8)
		if hh > 0.12:
			var c := a + dir * (x + seg * 0.5)
			var bx := BuildKit.box(parent, Vector3(seg, hh, t * rng.randf_range(0.85, 1.0)), Vector3(c.x, top + hh * 0.5, c.y), mat, true)
			bx.rotation.y = -atan2(dir.y, dir.x)
		x += seg
	# ein paar lose Steine auf der Krone
	for k in rng.randi_range(1, 3):
		var c := a + dir * rng.randf_range(0.3, len - 0.3)
		BuildKit.box(parent, Vector3(0.35, 0.22, 0.3), Vector3(c.x, top + 0.11, c.y), mat, false, Vector3(0, rng.randf() * 90.0, rng.randf_range(-8, 8)))


static func rubble(parent: Node3D, center: Vector3, n: int, spread: float, mat: Material, rng: RandomNumberGenerator) -> void:
	for k in n:
		var s := rng.randf_range(0.18, 0.5)
		var p := center + Vector3(rng.randf_range(-spread, spread), s * 0.35, rng.randf_range(-spread, spread))
		BuildKit.box(parent, Vector3(s * 1.3, s * 0.7, s), p, mat, false, Vector3(rng.randf_range(-20, 20), rng.randf() * 180.0, rng.randf_range(-20, 20)))


## Ein Balken, schräg von a nach b (eingestürztes Dach).
static func beam(parent: Node3D, a: Vector3, b: Vector3, r: float, mat: Material) -> void:
	var mid := (a + b) * 0.5
	var d := b - a
	var bx := BuildKit.box(parent, Vector3(r, r, d.length()), mid, mat, false)
	# lokal ausrichten (look_at arbeitet in Weltkoordinaten – dann landeten die Balken an der Hütte)
	bx.transform = Transform3D(Basis.looking_at(d.normalized(), Vector3.UP if absf(d.normalized().y) < 0.95 else Vector3.RIGHT), mid)


# --- Häuser ---------------------------------------------------------------------

static func house(ruin: Node3D, w: float, d: float, rng: RandomNumberGenerator) -> void:
	var hx := w * 0.5
	var hz := d * 0.5
	var t := 0.5
	var mat := _wall_stone(rng.randf_range(0.82, 1.0))
	var quoin := BuildKit.tex_mat("stone", 0.6, Color(1.05, 1.02, 0.95))
	var base := rng.randf_range(2.3, 3.0)
	var extra := rng.randf_range(0.6, 2.4)
	# Sockel (Hang) und schlammiger Boden
	BuildKit.box(ruin, Vector3(w + 0.3, 1.2, d + 0.3), Vector3(0, -0.58, 0), PlaceKit.mat("stone_dark"), true)
	BuildKit.box(ruin, Vector3(w - 0.6, 0.05, d - 0.6), Vector3(0, 0.03, 0), PlaceKit.mat("mud"), false)
	var door := rng.randf_range(1.2, w - 1.6)
	var win := Vector4(0, 0.9, 1.0, 1.9)
	var walls := [
		[Vector2(-hx, hz), Vector2(hx, hz), [Vector4(door, 1.1, 0.0, 2.0), Vector4(w - door > 2.4 and door + 1.6 or 0.9, 0.9, 1.0, 1.9)], "Front"],
		[Vector2(hx, -hz), Vector2(-hx, -hz), [Vector4(w * 0.35, 0.9, 1.0, 1.9), Vector4(w * 0.72, 0.9, 1.0, 1.9)], "Back"],
		[Vector2(-hx, -hz), Vector2(-hx, hz), [Vector4(d * 0.5, 0.9, 1.0, 1.9)], "Left"],
		[Vector2(hx, hz), Vector2(hx, -hz), [Vector4(d * 0.5, 0.9, 1.0, 1.9)], "Right"],
	]
	var broken := rng.randi() % 4   # eine Wand ist weit eingestürzt
	for i in walls.size():
		var wl: Array = walls[i]
		var hh := base * (0.45 if i == broken else 1.0)
		var ops: Array = (wl[2] as Array).filter(func(o: Vector4) -> bool: return o.w < hh - 0.2 and o.x > 0.5)
		wall2(ruin, wl[0], wl[1], hh, t, ops, mat, String(wl[3]))
		ragged_top(ruin, wl[0], wl[1], hh, t, extra * (0.4 if i == broken else 1.0), mat, rng)
		if i == broken:
			var mid: Vector2 = ((wl[0] as Vector2) + (wl[1] as Vector2)) * 0.5
			var out := Vector3(mid.x, 0, mid.y)
			rubble(ruin, out * 1.12, 14, 1.2, mat, rng)
	# Eckquader
	for c: Vector2 in [Vector2(-hx, -hz), Vector2(hx, -hz), Vector2(-hx, hz), Vector2(hx, hz)]:
		var qh := base + rng.randf_range(0.0, extra * 0.6)
		BuildKit.box(ruin, Vector3(0.62, qh, 0.62), Vector3(c.x, qh * 0.5, c.y), quoin, true)
	# Eingestürzte Dachbalken und Schutt innen
	var wood := PlaceKit.mat("wood_old")
	for k in rng.randi_range(2, 4):
		var sx := rng.randf_range(-hx + 0.6, hx - 0.6)
		beam(ruin, Vector3(sx, base - 0.1, -hz + 0.3), Vector3(sx + rng.randf_range(-1.2, 1.2), 0.15, rng.randf_range(-0.5, hz - 0.6)), 0.18, wood)
	beam(ruin, Vector3(-hx + 0.4, base + 0.2, rng.randf_range(-hz, hz) * 0.6), Vector3(hx - 0.4, base * 0.4, rng.randf_range(-hz, hz) * 0.6), 0.2, wood)
	rubble(ruin, Vector3(rng.randf_range(-hx, hx) * 0.5, 0, rng.randf_range(-hz, hz) * 0.5), 10, 0.9, mat, rng)
	# Ein Rest vom Dach: ein paar Schindelplatten, schief auf dem Schutt
	if rng.randf() < 0.6:
		var sh := BuildKit.box(ruin, Vector3(2.2, 0.08, 1.6), Vector3(rng.randf_range(-1.0, 1.0), 0.6, rng.randf_range(-1.0, 1.0)), PlaceKit.mat("shingles"), false)
		sh.rotation_degrees = Vector3(rng.randf_range(15, 30), rng.randf() * 180.0, rng.randf_range(-10, 10))


# --- Kirche -----------------------------------------------------------------------

## Kirche: Schiff 8 × 15 m, Turm an der Front mit Durchgang. Ursprung = Mitte des Schiffs am Boden, Front +z.
static func church(ch: Node3D, rng: RandomNumberGenerator) -> void:
	var W := 8.0
	var L := 15.0
	var H := 6.5
	var t := 0.7
	var hx := W * 0.5
	var hz := L * 0.5
	var mat := _wall_stone(0.95)
	var dark := PlaceKit.mat("stone_dark")
	var wood := PlaceKit.mat("wood_old")
	# Fundament und Boden (Steinplatten mit Schlamm)
	BuildKit.box(ch, Vector3(W + 0.8, 1.6, L + 0.8), Vector3(0, -0.78, 0), dark, true)
	BuildKit.box(ch, Vector3(W - 0.4, 0.05, L - 0.4), Vector3(0, 0.025, 0), BuildKit.tex_mat("stone", 1.6, Color(0.7, 0.66, 0.58)), false)
	for k in 9:
		BuildKit.box(ch, Vector3(rng.randf_range(0.8, 2.2), 0.012, rng.randf_range(0.6, 1.8)), Vector3(rng.randf_range(-3, 3), 0.056, rng.randf_range(-6.5, 6.5)), PlaceKit.mat("mud"), false, Vector3(0, rng.randf() * 180.0, 0))
	# Mauern: Front mit großem Portal, Seiten mit je drei hohen Fenstern, Rückwand mit Rundfenster
	var side_win := [Vector4(L * 0.22, 1.1, 2.6, 5.3), Vector4(L * 0.5, 1.1, 2.6, 5.3), Vector4(L * 0.78, 1.1, 2.6, 5.3)]
	wall2(ch, Vector2(-hx, hz), Vector2(hx, hz), H, t, [Vector4(hx, 2.0, 0.0, 3.3)], mat, "Front")
	wall2(ch, Vector2(hx, -hz), Vector2(-hx, -hz), H, t, [Vector4(hx, 1.5, 4.0, 5.5)], mat, "Back")
	wall2(ch, Vector2(-hx, -hz), Vector2(-hx, hz), H, t, side_win, mat, "Left")
	wall2(ch, Vector2(hx, hz), Vector2(hx, -hz), H, t, side_win, mat, "Right")
	# Bogen über den Fenstern und dem Portal (dunkle Steine)
	for side: float in [-1.0, 1.0]:
		for o: Vector4 in side_win:
			var z := -hz + o.x if side < 0.0 else hz - o.x
			for k in 5:
				var a := PI * float(k) / 4.0
				BuildKit.box(ch, Vector3(t + 0.06, 0.16, 0.24), Vector3(side * hx, o.w + sin(a) * 0.35, z + cos(a) * 0.62), dark, false, Vector3(rad_to_deg(a) - 90.0, 0, 0))
	# Giebeldreiecke vorn und hinten
	var rise := 3.2
	for z: float in [hz, -hz]:
		for k in 8:
			var f := float(k) / 8.0
			var ww := W * (1.0 - f)
			BuildKit.box(ch, Vector3(ww, rise / 8.0 + 0.02, t), Vector3(0, H + rise * (f + 0.0625), z), mat, true)
	# Strebepfeiler außen
	for side: float in [-1.0, 1.0]:
		for z: float in [-hz + 0.4, -hz + L * 0.36, -hz + L * 0.64, hz - 0.4]:
			BuildKit.box(ch, Vector3(0.8, 4.2, 0.9), Vector3(side * (hx + 0.55), 2.1, z), mat, true)
			BuildKit.box(ch, Vector3(0.5, 1.6, 0.9), Vector3(side * (hx + 0.4), 4.9, z), mat, true, Vector3(0, 0, side * 18.0))
	# Dachstuhl, halb eingestürzt: Sparrenpaare, Firstbalken, links noch ein Teil der Deckung
	var ridge := H + rise
	var z0 := -hz + 0.5
	var n := 9
	for k in n:
		var z := z0 + (L - 1.0) * float(k) / float(n - 1)
		if k == 5 or k == 6:
			beam(ch, Vector3(-hx, H, z), Vector3(rng.randf_range(-1.5, 1.5), 0.3, z + rng.randf_range(-1.0, 1.0)), 0.22, wood)   # heruntergebrochen
			continue
		beam(ch, Vector3(-hx, H, z), Vector3(0, ridge, z), 0.22, wood)
		beam(ch, Vector3(hx, H, z), Vector3(0, ridge, z), 0.22, wood)
		beam(ch, Vector3(-hx + 0.6, H + 0.5, z), Vector3(hx - 0.6, H + 0.5, z), 0.18, wood)
	beam(ch, Vector3(0, ridge, -hz + 0.3), Vector3(0, ridge, -1.0), 0.26, wood)
	beam(ch, Vector3(0, ridge, 3.2), Vector3(0, ridge, hz - 0.3), 0.26, wood)
	var slope := Vector2(hx, rise).length() + 0.4
	var ang := rad_to_deg(atan2(rise, hx))
	for seg: Vector2 in [Vector2(-hz - 0.3, -1.5), Vector2(3.6, hz + 0.3)]:
		var lz := seg.y - seg.x
		var roof := BuildKit.box(ch, Vector3(slope, 0.16, lz), Vector3(-hx * 0.5, H + rise * 0.5 + 0.1, (seg.x + seg.y) * 0.5), PlaceKit.mat("shingles"), false)
		roof.rotation_degrees.z = ang
	var part := BuildKit.box(ch, Vector3(slope * 0.6, 0.16, 3.0), Vector3(hx * 0.32, H + rise * 0.7, -hz + 2.0), PlaceKit.mat("shingles"), false)
	part.rotation_degrees.z = -ang
	# Bänke in zwei Reihen (ein paar umgestürzt), Mittelgang frei
	for row in 6:
		for side: float in [-1.0, 1.0]:
			var p := Vector3(side * 1.85, 0, 3.6 - row * 1.35)
			var pew := Node3D.new()
			pew.position = p
			ch.add_child(pew)
			if rng.randf() < 0.25:
				pew.rotation_degrees = Vector3(rng.randf_range(70, 90) * (1.0 if rng.randf() < 0.5 else -1.0), rng.randf_range(-15, 15), 0)
				pew.position.y = 0.3
			else:
				pew.rotation_degrees.y = rng.randf_range(-6, 6)
			BuildKit.box(pew, Vector3(2.6, 0.07, 0.42), Vector3(0, 0.46, 0), wood, true)
			BuildKit.box(pew, Vector3(2.6, 0.55, 0.06), Vector3(0, 0.75, 0.22), wood, false)   # Lehne hinten, Blick zum Altar
			for lx: float in [-1.2, 1.2]:
				BuildKit.box(pew, Vector3(0.07, 0.46, 0.42), Vector3(lx, 0.23, 0), wood, false)
	# Altarraum: Stufe, Altar, Kreuz an der Rückwand
	BuildKit.box(ch, Vector3(W - 1.4, 0.25, 2.6), Vector3(0, 0.125, -hz + 1.8), dark, true)
	BuildKit.box(ch, Vector3(2.0, 0.95, 0.9), Vector3(0, 0.25 + 0.475, -hz + 1.6), mat, true)
	BuildKit.box(ch, Vector3(2.2, 0.08, 1.0), Vector3(0, 1.24, -hz + 1.6), BuildKit.tex_mat("stone", 0.6, Color(1.1, 1.08, 1.0)), false)
	BuildKit.box(ch, Vector3(0.16, 2.2, 0.1), Vector3(0, 3.6, -hz + t * 0.5 + 0.06), PlaceKit.mat("dark"), false)
	BuildKit.box(ch, Vector3(1.1, 0.16, 0.1), Vector3(0, 4.2, -hz + t * 0.5 + 0.06), PlaceKit.mat("dark"), false)
	# heruntergefallener Leuchter (Ring aus Eisen) und Schutt unter dem Loch im Dach
	for k in 10:
		var a := TAU * k / 10.0
		BuildKit.box(ch, Vector3(0.28, 0.04, 0.05), Vector3(0.6 + cos(a) * 0.45, 0.08, -0.4 + sin(a) * 0.45), PlaceKit.mat("rust"), false, Vector3(0, -rad_to_deg(a) + 90.0, 0))
	rubble(ch, Vector3(0.0, 0, 1.0), 16, 1.4, mat, rng)
	_tower(ch, Vector3(0, 0, hz + 2.0), mat, dark)


## Turm vor dem Portal, innen hohl mit Durchgang: vorne Tor, hinten offen zum Schiff. Glocke im Glockenstuhl.
static func _tower(ch: Node3D, at: Vector3, mat: Material, dark: Material) -> void:
	var tw := Node3D.new()
	tw.name = "Tower"
	tw.position = at
	ch.add_child(tw)
	var s := 4.0
	var hs := s * 0.5
	var H := 15.0
	var t := 0.6
	BuildKit.box(tw, Vector3(s + 0.4, 1.6, s + 0.4), Vector3(0, -0.78, 0), dark, true)
	BuildKit.box(tw, Vector3(s - 0.6, 0.05, s - 0.6), Vector3(0, 0.025, 0), PlaceKit.mat("mud"), false)
	var bell_ops := Vector4(hs, 1.0, 11.6, 13.6)
	# Front (Tor), Seiten (schmale Schlitze + Schallöffnungen), Rückseite zum Schiff: unten offen
	wall2(tw, Vector2(-hs, hs), Vector2(hs, hs), H, t, [Vector4(hs, 1.8, 0.0, 3.1), Vector4(hs, 0.35, 6.0, 7.2), bell_ops], mat, "TowerFront")
	wall2(tw, Vector2(hs, -hs), Vector2(-hs, -hs), H, t, [Vector4(hs, 2.0, 0.0, 3.3), bell_ops], mat, "TowerBack")
	wall2(tw, Vector2(-hs, -hs), Vector2(-hs, hs), H, t, [Vector4(hs, 0.35, 5.0, 6.2), bell_ops], mat, "TowerLeft")
	wall2(tw, Vector2(hs, hs), Vector2(hs, -hs), H, t, [Vector4(hs, 0.35, 5.0, 6.2), bell_ops], mat, "TowerRight")
	# Gesims und spitzes Dach mit Kreuz
	BuildKit.box(tw, Vector3(s + 0.5, 0.3, s + 0.5), Vector3(0, H + 0.15, 0), dark, true)
	var roof := BuildKit.cylinder(tw, hs * 1.42, 6.5, Vector3(0, H + 3.55, 0), PlaceKit.mat("shingles"), false, Vector3.ZERO, 0.0, 4)
	roof.rotation_degrees.y = 45.0
	BuildKit.box(tw, Vector3(0.1, 1.4, 0.1), Vector3(0, H + 7.4, 0), PlaceKit.mat("rust"), false)
	BuildKit.box(tw, Vector3(0.7, 0.1, 0.1), Vector3(0, H + 7.7, 0), PlaceKit.mat("rust"), false)
	# Glockenstuhl mit schwingender Glocke
	BuildKit.box(tw, Vector3(s - 0.8, 0.2, 0.25), Vector3(0, 13.9, 0), PlaceKit.mat("wood_old"), false)
	var bell := Node3D.new()
	bell.name = "Bell"
	bell.position = Vector3(0, 13.8, 0)
	tw.add_child(bell)
	var bm := BuildKit.lathe(bell, PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.55, 0.0), Vector2(0.5, 0.15), Vector2(0.35, 0.6), Vector2(0.3, 0.9), Vector2(0.0, 0.95)]),
			Vector3(0, -0.95, 0), BuildKit.color_mat(Color(0.45, 0.35, 0.2), 0.4, 0.8), 14)
	bm.position = Vector3(0, -0.95, 0)
	var tween := bell.create_tween().set_loops()
	tween.tween_property(bell, "rotation_degrees:z", 9.0, 2.6).set_trans(Tween.TRANS_SINE)
	tween.tween_property(bell, "rotation_degrees:z", -9.0, 2.6).set_trans(Tween.TRANS_SINE)
	# Glockenseil hängt bis unten
	BuildKit.cylinder(tw, 0.02, 12.6, Vector3(0.25, 7.2, 0.0), PlaceKit.mat("fabric"), false, Vector3.ZERO, -1.0, 4)
