class_name RangerTower
extends Node3D
## Verlassener Hochsitz des Försters R. W. im Norden (Phase 8, Erkundung).
## Vier Pfosten, Plattform in gut 4 m Höhe mit Geländer und Dach, Leiter zum Hochklettern.
## Oben: Tagebuch, Revierkarte mit den drei Vermessungspunkten, ein paar Vorräte.

## Ein paar Meter neben dem Nordweg (Christian 14.11.: stand vorher mitten auf dem Weg)
const SITE := Vector3(7.2, 0.0, -81.2)
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
	# Kreuzstreben: auf jeder Seite zwei Kreuze, jeweils genau von Pfosten zu Pfosten
	var levels := [0.5, 2.3, DECK - 0.15]
	for face in 4:
		# Ecken der Seite (sx, sz) und Richtung nach außen
		var c: Array = [[Vector2(-1, 1), Vector2(1, 1)], [Vector2(1, 1), Vector2(1, -1)],
				[Vector2(1, -1), Vector2(-1, -1)], [Vector2(-1, -1), Vector2(-1, 1)]][face]
		var out := Vector3((c[0].x + c[1].x) * 0.5, 0, (c[0].y + c[1].y) * 0.5).normalized() * 0.1
		for k in 2:
			var a0 := _leg_point(c[0].x, c[0].y, levels[k]) + out
			var b0 := _leg_point(c[1].x, c[1].y, levels[k]) + out
			var a1 := _leg_point(c[0].x, c[0].y, levels[k + 1]) + out
			var b1 := _leg_point(c[1].x, c[1].y, levels[k + 1]) + out
			_beam(a0, b1, logs)
			_beam(b0, a1, logs)
		# waagrechter Riegel unter der Plattform
		_beam(_leg_point(c[0].x, c[0].y, DECK - 0.15) + out, _leg_point(c[1].x, c[1].y, DECK - 0.15) + out, logs)
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
	# Georg Wendts Diktiergerät und sein alter Laptop (Forschung: Aufnahmen, Auswertungsplatz)
	_pickup("TowerDictaphone", "dictaphone", 1, Vector3(0.35, DECK + 0.06, 0.55))
	_pickup("TowerLaptop", "old_laptop", 1, Vector3(-0.85, DECK + 0.06, -0.35))
	# Georg Wendts Fallen-Anleitung (Bauplan: Bärenfalle + Kleintierschlinge)
	PlaceKit.blueprint(self, "bp_traps", "Fallen-Anleitung", Vector3(0.25, DECK + 0.07, -1.05))
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
	# Wendts Kontrollrunde: Blatt unter der Karte (führt zu den Meldekästen, Story-Spur)
	BuildKit.box(self, Vector3(0.21, 0.28, 0.008), Vector3(0.55, DECK + 1.15, -1.425), BuildKit.color_mat(Color(0.88, 0.86, 0.8), 0.9), false)
	BuildKit.box(self, Vector3(0.03, 0.03, 0.006), Vector3(0.55, DECK + 1.27, -1.42), BuildKit.color_mat(Color(0.75, 0.1, 0.08)), false)
	var round_note := ResearchNote.new()
	round_note.name = "TowerRound"
	round_note.note_id = "wendt_runde"
	round_note.anchor = Vector3(0.55, DECK + 1.0, -1.3)
	round_note.hide_paper = true
	add_child(round_note)
	_details()


## Lebendige Orte: Sitzbrett mit Kissen, Thermoskanne, Patronenschachtel-Dose als Aschenbecher, Geweih am Pfosten,
## Schild „Jagdliche Einrichtung“, Salzlecke und Futterraufe in Sichtweite, Laub und Zweige.
func _details() -> void:
	var wood := PlaceKit.mat("wood_old")
	BuildKit.box(self, Vector3(1.8, 0.05, 0.35), Vector3(0, DECK + 0.5, -1.2), wood, false)
	for sx: float in [-0.8, 0.8]:
		BuildKit.box(self, Vector3(0.06, 0.45, 0.3), Vector3(sx, DECK + 0.28, -1.2), wood, false)
	BuildKit.box(self, Vector3(0.45, 0.06, 0.32), Vector3(-0.3, DECK + 0.55, -1.2), PlaceKit.mat("cloth"), false)
	BuildKit.cylinder(self, 0.045, 0.3, Vector3(1.25, DECK + 1.2, -1.2), PlaceDetail.col(Color(0.15, 0.3, 0.2), 0.4, 0.5), false, Vector3.ZERO, -1.0, 10)
	BuildKit.cylinder(self, 0.04, 0.03, Vector3(-1.25, DECK + 1.04, -0.4), PlaceKit.mat("rust"), false, Vector3.ZERO, -1.0, 10)
	var bone := PlaceDetail.col(Color(0.82, 0.78, 0.68), 0.7)
	var ant := Vector3(0, DECK + 2.0, -1.44)
	BuildKit.box(self, Vector3(0.2, 0.25, 0.03), ant, wood, false)
	for sx: float in [-1.0, 1.0]:
		HandKit.tube(self, PackedVector3Array([ant + Vector3(sx * 0.04, 0.05, 0.03), ant + Vector3(sx * 0.15, 0.2, 0.05), ant + Vector3(sx * 0.2, 0.35, 0.03)]), 0.012, bone, 5)
	var sp := Vector3(1.9, 0, 2.6)
	BuildKit.box(self, Vector3(0.08, 1.3, 0.08), sp + Vector3(0, 0.65, 0), wood, true)
	PlaceDetail.sign(self, "Jagdliche Einrichtung\nBetreten verboten!\nRevier Finsterau", sp + Vector3(0, 1.15, 0.05), Vector2(0.45, 0.3), 0.0, Color(0.92, 0.9, 0.82), Color(0.25, 0.15, 0.05), 24)
	# Salzlecke und Futterraufe auf der Lichtung vor dem Hochsitz (+z)
	var sl := Vector3(-3.0, 0, 9.0)
	sl.y = Terrain.height_at(global_position.x + sl.x, global_position.z + sl.z) - global_position.y if is_inside_tree() else 0.0
	BuildKit.cylinder(self, 0.08, 1.4, sl + Vector3(0, 0.7, 0), PlaceKit.mat("bark"), false, Vector3.ZERO, 0.07, 8)
	BuildKit.box(self, Vector3(0.18, 0.12, 0.18), sl + Vector3(0, 1.45, 0), PlaceDetail.col(Color(0.82, 0.78, 0.72), 0.8), false)
	var fr := Vector3(3.0, 0, 11.0)
	fr.y = Terrain.height_at(global_position.x + fr.x, global_position.z + fr.z) - global_position.y if is_inside_tree() else 0.0
	var rack := Node3D.new()
	rack.position = fr
	rack.rotation_degrees.y = 20.0
	add_child(rack)
	for sx: float in [-0.9, 0.9]:
		BuildKit.box(rack, Vector3(0.1, 1.8, 0.1), Vector3(sx, 0.9, 0), wood, true)
	for k in 7:
		BuildKit.box(rack, Vector3(0.03, 0.8, 0.03), Vector3(-0.75 + k * 0.25, 1.1, 0.1), wood, false, Vector3(25, 0, 0))
	for sx: float in [-1.0, 1.0]:
		BuildKit.box(rack, Vector3(2.2, 0.04, 0.7), Vector3(0, 1.95, sx * 0.25), PlaceKit.mat("shingles"), false, Vector3(-sx * 30.0, 0, 0))
	for k in 14:
		BuildKit.box(rack, Vector3(0.02, 0.5, 0.02), Vector3(-0.7 + k * 0.1, 1.15, 0.16), PlaceDetail.col(Color(0.42, 0.36, 0.2), 1.0), false, Vector3(25 + (k % 3) * 8, 0, (k % 5) * 6 - 12))


## Mittelpunkt des Pfostens (sx, sz) auf Höhe y – die Pfosten stehen leicht schräg.
func _leg_point(sx: float, sz: float, y: float) -> Vector3:
	var ph := DECK + (2.15 if sz > 0.0 else 2.6)
	var center := Vector3(sx * 1.35, ph * 0.5 - 0.3, sz * 1.35)
	var axis := Basis.from_euler(Vector3(deg_to_rad(sz * -3.0), 0, deg_to_rad(sx * 3.0))) * Vector3.UP
	return center + axis * ((y - center.y) / axis.y)


## Rundholz von a nach b.
func _beam(a: Vector3, b: Vector3, mat: Material) -> void:
	var mi := BuildKit.cylinder(self, 0.055, a.distance_to(b), (a + b) * 0.5, mat, false, Vector3.ZERO, -1.0, 6)
	var y := (b - a).normalized()
	var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
	mi.basis = Basis(x, y, x.cross(y).normalized())


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
			HandItems.place(v, "bottle", at)
		"old_laptop":
			var dark := BuildKit.color_mat(Color(0.12, 0.12, 0.13), 0.5)
			BuildKit.box(v, Vector3(0.34, 0.025, 0.24), at + Vector3(0, 0.012, 0), dark, false)
			BuildKit.box(v, Vector3(0.34, 0.22, 0.015), at + Vector3(0, 0.12, -0.115), dark, false, Vector3(-15, 0, 0))
		"dictaphone":
			HandItems.place(v, "dictaphone", at, 30.0, true)
		_:
			BuildKit.box(v, Vector3(0.12, 0.08, 0.07), at + Vector3(0, 0.04, 0), BuildKit.color_mat(Color(0.15, 0.15, 0.15)), false)
	p.visuals.append(v)
