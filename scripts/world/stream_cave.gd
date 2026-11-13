class_name StreamCave
extends Node3D
## Höhle am Bach im Nordosten (Phase 8). Ein Felshügel mit niedrigem Gang nach Osten und einer
## Kammer am Ende. Drinnen ist es stockdunkel – ohne Licht sieht man nichts.
## In der Kammer sitzt der Knoten des Organismus, von dem aus die Wucherungen zur Hütte wachsen.
## Daneben: der Rucksack des Försters mit seiner letzten Notiz.

## Eingang (Boden), der Gang verläuft nach +x
const SITE := Vector3(46.0, 0.0, -72.0)
const LENGTH := 12.0
const WIDTH := 3.0
const HEIGHT := 2.5

static var _floor_h: float = INF


## Bodenhöhe der Höhle = Geländehöhe vor dem Eingang (ohne Höhlen-Einschnitt).
static func floor_height() -> float:
	if _floor_h == INF:
		_floor_h = Terrain._raw_height_core(SITE.x - 2.0, SITE.z)
	return _floor_h


static func is_near(x: float, z: float, radius: float) -> bool:
	return Vector2(x - (SITE.x + 8.0), z - SITE.z).length() < radius


func _ready() -> void:
	name = "StreamCave"
	position = Vector3(SITE.x, floor_height(), SITE.z)
	var rock := BuildKit.tex_mat("rock", 2.0, Color(0.6, 0.58, 0.56))
	var rock_out := BuildKit.tex_mat("rock", 3.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 66
	# Boden, Wände, Decke des Gangs (unregelmäßig aus mehreren Blöcken)
	BuildKit.box_mm(self, Vector3(-0.5, -0.3, -WIDTH * 0.5 - 0.4), Vector3(LENGTH + 6.0, 0.02, WIDTH * 0.5 + 0.4), rock, true)
	var x := 0.0
	while x < LENGTH:
		var seg := rng.randf_range(1.2, 2.0)
		for side: float in [-1.0, 1.0]:
			var off := rng.randf_range(-0.15, 0.15)
			BuildKit.box(self, Vector3(seg + 0.2, HEIGHT + 0.4, 0.6), Vector3(x + seg * 0.5, HEIGHT * 0.5, side * (WIDTH * 0.5 + 0.3 + off)), rock, true,
					Vector3(rng.randf_range(-3, 3), rng.randf_range(-4, 4), side * rng.randf_range(2, 7)))
		BuildKit.box(self, Vector3(seg + 0.2, 0.6, WIDTH + 1.4), Vector3(x + seg * 0.5, HEIGHT + 0.25 + rng.randf_range(-0.15, 0.1), 0), rock, true,
				Vector3(rng.randf_range(-4, 4), 0, rng.randf_range(-3, 3)))
		x += seg
	# Kammer am Ende (breiter und höher)
	var cx := LENGTH + 3.0
	for side: float in [-1.0, 1.0]:
		BuildKit.box(self, Vector3(6.4, HEIGHT + 1.4, 0.7), Vector3(cx, (HEIGHT + 1.0) * 0.5, side * 3.2), rock, true, Vector3(0, 0, side * 4))
	BuildKit.box(self, Vector3(0.8, HEIGHT + 1.4, 7.0), Vector3(cx + 3.2, (HEIGHT + 1.0) * 0.5, 0), rock, true)
	BuildKit.box(self, Vector3(7.0, 0.7, 7.4), Vector3(cx, HEIGHT + 1.2, 0), rock, true, Vector3(0, 0, 3))
	# Zwischenwände, die den Gang zur Kammer hin abschließen
	for side: float in [-1.0, 1.0]:
		BuildKit.box(self, Vector3(0.7, HEIGHT + 1.2, 1.8), Vector3(LENGTH - 0.1, (HEIGHT + 1.0) * 0.5, side * 2.4), rock, true)
	# Felshügel außen (deckt alles ab)
	# Brocken nur außen an den Wänden und auf der Decke, nie in den Gang hinein
	for k in 9:
		var mx := 0.8 + k * 2.1
		var chamber := mx > LENGTH - 0.5
		var half := (3.6 if chamber else WIDTH * 0.5 + 0.7)
		var roof := (HEIGHT + 1.6 if chamber else HEIGHT + 0.65)
		var r := rng.randf_range(2.2, 3.0)
		for side: float in [-1.0, 1.0]:
			BuildKit.sphere(self, r, Vector3(mx, r * 0.45, side * (half + r * 0.95)), rock_out, Vector3(1.1, 0.9, 1.0), 10)
		var rt := rng.randf_range(2.6, 3.4)
		BuildKit.sphere(self, rt, Vector3(mx, roof + rt * 0.5, rng.randf_range(-0.4, 0.4)), rock_out, Vector3(1.0, 0.5, 1.15), 10)
	# Eingangsfelsen
	for side: float in [-1.0, 1.0]:
		BuildKit.sphere(self, 1.2, Vector3(-0.4, 0.8, side * 2.0), rock_out, Vector3(0.8, 1.4, 0.9), 8)
	BuildKit.box(self, Vector3(1.0, 0.5, 4.2), Vector3(-0.3, HEIGHT + 0.1, 0), rock_out, false, Vector3(0, 0, -8))
	# Fäden der Wucherung an Wänden und Decke, zur Kammer hin dichter
	var vein := BuildKit.color_mat(Color(0.32, 0.3, 0.33), 0.35, 0.1)
	var glow := BuildKit.emissive_mat(Color(0.75, 0.55, 1.0), 1.5)
	for k in 40:
		var vx := rng.randf_range(4.0, LENGTH + 5.0)
		var side := -1.0 if k % 2 == 0 else 1.0
		var half := (WIDTH * 0.5 + 0.02) if vx < LENGTH else 2.85
		var vy := rng.randf_range(0.1, HEIGHT)
		BuildKit.box(self, Vector3(rng.randf_range(0.6, 1.6), 0.03, 0.03), Vector3(vx, vy, side * half), vein, false,
				Vector3(0, 0, rng.randf_range(-50, 50)))
		if k % 4 == 0:
			BuildKit.sphere(self, 0.05, Vector3(vx, vy, side * (half - 0.03)), glow, Vector3.ONE, 6)
	# der Knoten
	var node := OrganismNode.new()
	node.name = "OrganismSource"
	node.position = Vector3(cx + 0.5, 0.0, 0.0)
	add_child(node)
	# Rucksack des Försters mit letzter Notiz
	var bag := BuildKit.tex_mat("fabric", 0.3, Color(0.75, 0.85, 0.6))
	BuildKit.box(self, Vector3(0.4, 0.5, 0.25), Vector3(cx - 1.8, 0.25, 2.2), bag, false, Vector3(-15, 20, 8))
	BuildKit.box(self, Vector3(0.3, 0.2, 0.08), Vector3(cx - 1.8, 0.2, 2.06), bag, false, Vector3(-15, 20, 8))
	var note := ResearchNote.new()
	note.name = "RangerNote3"
	note.note_id = "ranger_note3"
	note.anchor = Vector3(cx - 1.4, 0.0, 1.7)
	add_child(note)
	# Wendts Funkgerät der Firma (Kanal 4) – führt zur Messstelle Nord
	var radio_mat := BuildKit.color_mat(Color(0.12, 0.12, 0.13), 0.6)
	BuildKit.box(self, Vector3(0.07, 0.2, 0.04), Vector3(cx - 2.25, 0.1, 2.45), radio_mat, false, Vector3(0, 30, 70))
	BuildKit.box(self, Vector3(0.012, 0.012, 0.12), Vector3(cx - 2.3, 0.1, 2.55), radio_mat, false, Vector3(0, 30, 0))
	BuildKit.box(self, Vector3(0.04, 0.02, 0.005), Vector3(cx - 2.25, 0.14, 2.47), BuildKit.color_mat(Color(0.9, 0.5, 0.1)), false, Vector3(0, 30, 70))
	var radio := ResearchNote.new()
	radio.name = "RangerRadio"
	radio.note_id = "hoehle_funkgeraet"
	radio.anchor = Vector3(cx - 2.25, 0.0, 2.45)
	radio.hide_paper = true
	add_child(radio)
