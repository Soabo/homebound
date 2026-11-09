class_name RangerTower
extends Node3D
## Verlassener Hochsitz des Försters R. W. im Norden (Phase 8, Erkundung).
## Vier Pfosten, Plattform in gut 4 m Höhe mit Geländer und Dach, Leiter zum Hochklettern.
## Oben: Tagebuch, Revierkarte mit den drei Vermessungspunkten, ein paar Vorräte.

const SITE := Vector3(12.0, 0.0, -80.0)
const DECK := 4.2


static func is_near(x: float, z: float, radius: float) -> bool:
	return Vector2(x - SITE.x, z - SITE.z).length() < radius


func _ready() -> void:
	name = "RangerTower"
	position = Vector3(SITE.x, Terrain.height_at(SITE.x, SITE.z), SITE.z)
	rotation_degrees.y = 15.0
	var logs := BuildKit.tex_mat("logs", 0.5, Color(0.85, 0.8, 0.75))
	var planks := BuildKit.tex_mat("planks_h", 0.8, Color(0.85, 0.8, 0.72))
	var boards := BuildKit.tex_mat("planks_v", 0.8, Color(0.8, 0.75, 0.68))
	# Pfosten leicht schräg nach innen, mit Querstreben
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			# vorne kürzer, hinten länger: Pfosten enden genau unter dem schrägen Dach
			var ph := DECK + (2.15 if sz > 0.0 else 2.6)
			BuildKit.cylinder(self, 0.12, ph, Vector3(sx * 1.35, ph * 0.5 - 0.3, sz * 1.35), logs, true, Vector3(sz * -3.0, 0, sx * 3.0), 0.1, 8)
	for h: float in [1.4, 2.9]:
		for side: float in [-1.0, 1.0]:
			BuildKit.cylinder(self, 0.06, 2.8, Vector3(side * 1.3, h, 0), logs, false, Vector3(35, 0, 0), -1.0, 6)
			BuildKit.cylinder(self, 0.06, 2.8, Vector3(0, h, side * 1.3), logs, false, Vector3(0, 0, 35), -1.0, 6)
	# Plattform
	BuildKit.box(self, Vector3(3.0, 0.12, 3.0), Vector3(0, DECK, 0), planks, true)
	# Brüstung aus Brettern an drei Seiten, vorne (+z, Leiter) offen mit zwei kurzen Handläufen.
	# Bretter laufen jeweils entlang ihrer Seite; Ecken überlappen nicht.
	var wall_h := 0.95
	# Rückwand bis unters Dach (dort hängt die Revierkarte), Seiten nur brusthoch
	var back_h := 2.3
	BuildKit.box(self, Vector3(2.9, back_h, 0.04), Vector3(0, DECK + 0.06 + back_h * 0.5, -1.47), boards, true)
	for side: Array in [[Vector3(1.47, 0, 0), 90.0], [Vector3(-1.47, 0, 0), 90.0]]:
		var at: Vector3 = side[0]
		BuildKit.box(self, Vector3(2.9, wall_h, 0.04), at + Vector3(0, DECK + 0.06 + wall_h * 0.5, 0), boards, true, Vector3(0, side[1], 0))
		# Handlauf oben
		BuildKit.box(self, Vector3(3.0, 0.06, 0.1), at + Vector3(0, DECK + 0.06 + wall_h + 0.03, 0), planks, false, Vector3(0, side[1], 0))
	for s: float in [-1.0, 1.0]:
		BuildKit.box(self, Vector3(0.95, 0.06, 0.08), Vector3(s * 1.0, DECK + 0.98, 1.47), planks, true)
		BuildKit.box(self, Vector3(0.06, 0.9, 0.06), Vector3(s * 0.52, DECK + 0.51, 1.47), logs, false)
	# Dach: Pultdach auf vier Stützen, fest (man kann nicht hindurchspringen)
	var roof_y := DECK + 2.25
	BuildKit.box(self, Vector3(3.6, 0.08, 3.6), Vector3(0, roof_y, 0), BuildKit.tex_mat("shingles", 1.0), true, Vector3(10, 0, 0))
	BuildKit.box(self, Vector3(3.0, 0.1, 3.0), Vector3(0, roof_y - 0.12, 0), planks, true, Vector3(10, 0, 0))
	# Leiter auf der Vorderseite (+z)
	for s: float in [-1.0, 1.0]:
		BuildKit.box(self, Vector3(0.07, DECK + 1.0, 0.07), Vector3(s * 0.3, (DECK + 1.0) * 0.5, 1.62), logs, false)
	for k in 12:
		BuildKit.box(self, Vector3(0.6, 0.05, 0.05), Vector3(0, 0.3 + k * 0.36, 1.62), logs, false)
	var ladder := TowerLadder.new()
	ladder.name = "Ladder"
	ladder.bottom = Vector3(0, 0.1, 2.3)
	ladder.top = Vector3(0, DECK + 0.1, 0.9)
	add_child(ladder)
	# Oben: Kiste mit Vorräten, Tagebuch, Karte an der Rückwand
	var crate := BuildKit.tex_mat("planks_h", 0.4, Color(1.0, 0.95, 0.85))
	BuildKit.box(self, Vector3(0.6, 0.35, 0.4), Vector3(0.9, DECK + 0.24, -1.0), crate, true)
	_pickup("TowerFood", "food", 2, Vector3(0.75, DECK + 0.42, -1.0))
	_pickup("TowerBattery", "battery", 1, Vector3(1.05, DECK + 0.42, -1.0))
	_pickup("TowerWater", "water", 1, Vector3(-0.9, DECK + 0.06, -1.05))
	var diary := ResearchNote.new()
	diary.name = "TowerDiary"
	diary.note_id = "ranger_note2"
	diary.anchor = Vector3(-0.6, DECK + 0.06, 0.4)
	add_child(diary)
	# Revierkarte an der Rückwand (nach innen gewandt)
	var map_mat := BuildKit.color_mat(Color(0.82, 0.8, 0.68), 0.9)
	BuildKit.box(self, Vector3(0.8, 0.6, 0.01), Vector3(0, DECK + 1.3, -1.43), map_mat, false)
	for k in 3:
		BuildKit.box(self, Vector3(0.05, 0.05, 0.005), Vector3(-0.25 + k * 0.25, DECK + 1.25 + (k % 2) * 0.12, -1.42), BuildKit.color_mat(Color(0.7, 0.1, 0.1)), false)
	var map := ResearchNote.new()
	map.name = "TowerMap"
	map.note_id = "ranger_map"
	map.anchor = Vector3(0, DECK + 1.1, -1.3)
	map.hide_paper = true
	add_child(map)


func _pickup(n: String, item: String, amount: int, at: Vector3) -> void:
	var p := ItemPickup.new()
	p.name = n
	p.item_id = item
	p.amount = amount
	p.per_take = amount
	p.collider_size = Vector3(0.3, 0.2, 0.3)
	p.collider_offset = at + Vector3(0, 0.1, 0)
	add_child(p)
	var v := Node3D.new()
	p.add_child(v)
	match item:
		"food":
			Icons.food_can(v, at, 0.042, 0.11)
		"water":
			BuildKit.cylinder(v, 0.045, 0.26, at + Vector3(0, 0.13, 0), BuildKit.color_mat(Color(0.45, 0.65, 0.8), 0.1), false, Vector3.ZERO, -1.0, 10)
		_:
			BuildKit.box(v, Vector3(0.12, 0.08, 0.07), at + Vector3(0, 0.04, 0), BuildKit.color_mat(Color(0.15, 0.15, 0.15)), false)
	p.visuals.append(v)
