class_name Cabin
extends Node3D
## Die Blockhütte (GDD 3.3). Grundfläche 12 x 9 m, Eingang nach Süden (+z).
##
## Raumaufteilung (Draufsicht, Norden oben = -z):
##   +-------------+---------+-----------+
##   | Schlafzimmer| Vorrat  | Technik   |   z -4.5 .. -1
##   +-------------+---------+-----------+
##   |      Wohnzimmer       | Werkstatt |   z -1 .. 4.5
##   +----[Tür]--------------+-----------+
##   x -6        -1         2           6

const FLOOR_Y := 0.45
const WALL_H := 2.8
const WALL_TOP := FLOOR_Y + WALL_H
const EXT_T := 0.25
const INT_T := 0.15
const HALF_X := 6.0
const HALF_Z := 4.5

var front_door: Door
var switches: Dictionary = {}


## Für Atmosphäre/Sound: steht ein Punkt in der Hütte?
static func is_inside(p: Vector3) -> bool:
	return absf(p.x) < HALF_X and absf(p.z) < HALF_Z and p.y > FLOOR_Y - 0.3 and p.y < WALL_TOP + 0.5


func _ready() -> void:
	name = "Cabin"
	_build_shell()
	_build_roof()
	_build_porch()
	_build_openings()
	_build_fireplace()
	_build_lights()
	_build_living_room()
	_build_bedroom()
	_build_storage()
	_build_technical_room()
	_build_workshop()
	_build_reflection_probe()


## Innenraum-Reflexionen: verhindert, dass sich drinnen der blaue Himmel spiegelt.
func _build_reflection_probe() -> void:
	var probe := ReflectionProbe.new()
	probe.name = "InteriorProbe"
	probe.size = Vector3(HALF_X * 2.0, WALL_H, HALF_Z * 2.0)
	probe.position = Vector3(0, FLOOR_Y + WALL_H * 0.5, 0)
	probe.interior = true
	probe.box_projection = true
	probe.ambient_mode = ReflectionProbe.AMBIENT_COLOR
	probe.ambient_color = Color(0.2, 0.16, 0.12)
	probe.ambient_color_energy = 0.6
	probe.update_mode = ReflectionProbe.UPDATE_ONCE
	add_child(probe)


# --- Rohbau -------------------------------------------------------------

func _build_shell() -> void:
	var stone := BuildKit.stone_mat(Color(0.45, 0.43, 0.4), 0.28)
	var logs := BuildKit.wood_mat(Color(0.42, 0.27, 0.16), 1, 0.27, 0.13)
	var inner := BuildKit.wood_mat(Color(0.55, 0.4, 0.26), 1, 0.2, 0.06)
	var floor_mat := BuildKit.wood_mat(Color(0.4, 0.27, 0.17), 0, 0.18, 0.05)

	BuildKit.box_mm(self, Vector3(-HALF_X - 0.15, 0, -HALF_Z - 0.15), Vector3(HALF_X + 0.15, FLOOR_Y - 0.06, HALF_Z + 0.15), stone, true, "Foundation")
	BuildKit.box_mm(self, Vector3(-HALF_X + 0.1, FLOOR_Y - 0.08, -HALF_Z + 0.1), Vector3(HALF_X - 0.1, FLOOR_Y, HALF_Z - 0.1), floor_mat, true, "Floor")

	var hz := HALF_Z - EXT_T * 0.5
	# Außenwände – Öffnungen: Vector4(mitte, breite, unterkante, oberkante)
	BuildKit.wall(self, Vector2(-HALF_X, HALF_Z), Vector2(HALF_X, HALF_Z), FLOOR_Y, WALL_H, EXT_T, logs,
			[Vector4(3.0, 1.0, 0.0, 2.1), Vector4(6.0, 1.3, 0.9, 2.0), Vector4(10.0, 1.0, 1.0, 1.9)], "WallFront")
	BuildKit.wall(self, Vector2(-HALF_X, -HALF_Z), Vector2(HALF_X, -HALF_Z), FLOOR_Y, WALL_H, EXT_T, logs,
			[Vector4(2.5, 1.0, 1.0, 1.9), Vector4(10.5, 0.6, 1.5, 2.0)], "WallBack")
	BuildKit.wall(self, Vector2(-HALF_X, -hz), Vector2(-HALF_X, hz), FLOOR_Y, WALL_H, EXT_T, logs, [], "WallWest")
	BuildKit.wall(self, Vector2(HALF_X, -hz), Vector2(HALF_X, hz), FLOOR_Y, WALL_H, EXT_T, logs,
			[Vector4(2.0 + hz, 1.0, 1.0, 1.9)], "WallEast")

	# Innenwände
	var ix := HALF_X - EXT_T * 0.5
	var iz := HALF_Z - EXT_T * 0.5
	BuildKit.wall(self, Vector2(-ix, -1.0), Vector2(ix, -1.0), FLOOR_Y, WALL_H, INT_T, inner,
			[Vector4(-2.5 + ix, 0.9, 0.0, 2.05), Vector4(0.5 + ix, 0.9, 0.0, 2.05), Vector4(4.0 + ix, 0.9, 0.0, 2.05)], "WallInnerHall")
	BuildKit.wall(self, Vector2(-1.0, -iz), Vector2(-1.0, -1.075), FLOOR_Y, WALL_H, INT_T, inner, [], "WallBedStorage")
	BuildKit.wall(self, Vector2(2.0, -iz), Vector2(2.0, -1.075), FLOOR_Y, WALL_H, INT_T, inner, [], "WallStorageTech")
	BuildKit.wall(self, Vector2(2.0, -0.925), Vector2(2.0, iz), FLOOR_Y, WALL_H, INT_T, inner,
			[Vector4(1.5 + 0.925, 1.0, 0.0, 2.05)], "WallLivingWorkshop")

	# Decke
	var ceiling := BuildKit.wood_mat(Color(0.36, 0.25, 0.16), 0, 0.22, 0.05)
	BuildKit.box_mm(self, Vector3(-HALF_X, WALL_TOP, -HALF_Z), Vector3(HALF_X, WALL_TOP + 0.1, HALF_Z), ceiling, false, "Ceiling")
	# Deckenbalken
	var beam := BuildKit.wood_mat(Color(0.3, 0.2, 0.12), 0, 0.5, 0.02)
	for x: float in [-4.0, -1.5, 1.0, 3.5]:
		BuildKit.box(self, Vector3(0.18, 0.2, HALF_Z * 2.0 - 0.3), Vector3(x, WALL_TOP - 0.1, 0), beam, false)


func _build_roof() -> void:
	var shingles := BuildKit.wood_mat(Color(0.2, 0.16, 0.14), 2, 0.22, 0.2)
	var logs := BuildKit.wood_mat(Color(0.42, 0.27, 0.16), 1, 0.27, 0.13)
	var rise := 2.2
	var overhang := 0.6
	var slope := rise / HALF_Z
	var angle := rad_to_deg(atan(slope))
	var run := HALF_Z + overhang
	var length := run / cos(atan(slope))
	var center_z := run * 0.5
	var center_y := WALL_TOP + rise - center_z * slope + 0.1
	var roof_len := HALF_X * 2.0 + overhang * 2.0
	BuildKit.box(self, Vector3(roof_len, 0.16, length), Vector3(0, center_y, center_z), shingles, false, Vector3(angle, 0, 0), "RoofSouth")
	BuildKit.box(self, Vector3(roof_len, 0.16, length), Vector3(0, center_y, -center_z), shingles, false, Vector3(-angle, 0, 0), "RoofNorth")
	BuildKit.box(self, Vector3(roof_len, 0.18, 0.25), Vector3(0, WALL_TOP + rise + 0.12, 0), BuildKit.color_mat(Color(0.15, 0.12, 0.1)), false)
	BuildKit.gable(self, HALF_Z * 2.0, rise, EXT_T, Vector3(-HALF_X + EXT_T * 0.5, WALL_TOP, 0), 90.0, logs)
	BuildKit.gable(self, HALF_Z * 2.0, rise, EXT_T, Vector3(HALF_X - EXT_T * 0.5, WALL_TOP, 0), 90.0, logs)
	# Schornstein außen an der Westwand
	var stone := BuildKit.stone_mat(Color(0.4, 0.39, 0.37), 0.25)
	BuildKit.box_mm(self, Vector3(-HALF_X - 0.8, 0, 1.2), Vector3(-HALF_X - 0.12, WALL_TOP + rise + 1.0, 2.3), stone, true, "Chimney")


func _build_porch() -> void:
	var deck := BuildKit.wood_mat(Color(0.38, 0.27, 0.18), 0, 0.16, 0.08)
	var stone := BuildKit.stone_mat(Color(0.42, 0.4, 0.38), 0.25)
	var post := BuildKit.wood_mat(Color(0.33, 0.22, 0.14), 1, 0.6, 0.02)
	var z0 := HALF_Z + EXT_T * 0.5
	BuildKit.box_mm(self, Vector3(-5.6, FLOOR_Y - 0.08, z0), Vector3(1.2, FLOOR_Y, 6.6), deck, true, "PorchDeck")
	BuildKit.box_mm(self, Vector3(-5.6, 0, z0), Vector3(1.2, FLOOR_Y - 0.08, 6.5), stone, true)
	# Treppe: sichtbare Stufen, darunter eine unsichtbare Rampe zum Hochlaufen
	BuildKit.box_mm(self, Vector3(-4.0, 0, 6.6), Vector3(-2.0, 0.3, 7.05), deck, false)
	BuildKit.box_mm(self, Vector3(-4.0, 0, 7.05), Vector3(-2.0, 0.15, 7.5), deck, false)
	var ramp_len := sqrt(1.3 * 1.3 + FLOOR_Y * FLOOR_Y)
	var ramp_angle := rad_to_deg(atan(FLOOR_Y / 1.3))
	BuildKit.collider_box(self, Vector3(2.0, 0.1, ramp_len), Vector3(-3.0, FLOOR_Y * 0.5 - 0.05, 7.25), Vector3(ramp_angle, 0, 0))
	# Pfosten und Vordach
	for x: float in [-5.4, -1.6, 1.0]:
		BuildKit.box_mm(self, Vector3(x - 0.08, FLOOR_Y, 6.3), Vector3(x + 0.08, WALL_TOP - 0.68, 6.46), post, true)
	var roof_angle := rad_to_deg(atan(0.5 / 2.4))
	BuildKit.box(self, Vector3(7.2, 0.1, 2.5), Vector3(-2.2, WALL_TOP - 0.6, 5.8),
			BuildKit.wood_mat(Color(0.2, 0.16, 0.14), 2, 0.22, 0.2), false, Vector3(roof_angle, 0, 0), "PorchRoof")
	# Feuerholz auf der Veranda
	var log_mat := BuildKit.color_mat(Color(0.35, 0.25, 0.16))
	for row in 4:
		for i in 6 - row:
			BuildKit.cylinder(self, 0.09, 0.9, Vector3(-5.35, FLOOR_Y + 0.09 + row * 0.16, 4.95 + i * 0.19 + row * 0.09),
					log_mat, false, Vector3(0, 0, 90), -1.0, 8)
	# Schaukelstuhl-Ersatz: einfacher Stuhl
	_chair(Vector3(-0.1, FLOOR_Y, 5.5), 200.0)


func _build_openings() -> void:
	front_door = Door.new()
	front_door.name = "FrontDoor"
	front_door.door_name = "Haustür"
	front_door.width = 1.0
	front_door.height = 2.08
	front_door.thickness = 0.07
	front_door.lockable = true
	front_door.open_sign = 1.0
	front_door.position = Vector3(-3.5, FLOOR_Y, HALF_Z)
	add_child(front_door)
	# Türrahmen
	var frame := BuildKit.wood_mat(Color(0.28, 0.19, 0.12), 1, 0.3, 0.04)
	BuildKit.box_mm(self, Vector3(-3.58, FLOOR_Y, HALF_Z - 0.15), Vector3(-3.5, FLOOR_Y + 2.1, HALF_Z + 0.15), frame, false)
	BuildKit.box_mm(self, Vector3(-2.5, FLOOR_Y, HALF_Z - 0.15), Vector3(-2.42, FLOOR_Y + 2.1, HALF_Z + 0.15), frame, false)
	BuildKit.box_mm(self, Vector3(-3.58, FLOOR_Y + 2.1, HALF_Z - 0.15), Vector3(-2.42, FLOOR_Y + 2.2, HALF_Z + 0.15), frame, false)

	# Fenster (GDD 18.2: zwei zerstörbare Fenster im Wohnbereich – Schaden folgt in Phase 2/4)
	_window("WindowLiving", Vector3(0.0, FLOOR_Y + 0.9, HALF_Z), 0.0, 1.3, 1.1)
	_window("WindowWorkshopFront", Vector3(4.0, FLOOR_Y + 1.0, HALF_Z), 0.0, 1.0, 0.9)
	_window("WindowBedroom", Vector3(-3.5, FLOOR_Y + 1.0, -HALF_Z), 180.0, 1.0, 0.9)
	_window("WindowTechnical", Vector3(4.5, FLOOR_Y + 1.5, -HALF_Z), 180.0, 0.6, 0.5)
	_window("WindowWorkshopEast", Vector3(HALF_X, FLOOR_Y + 1.0, 2.0), 90.0, 1.0, 0.9)


func _window(node_name: String, pos: Vector3, rot_y: float, w: float, h: float) -> void:
	var win := CabinWindow.new()
	win.name = node_name
	win.width = w
	win.height = h
	win.position = pos
	win.rotation_degrees.y = rot_y
	add_child(win)


func _build_fireplace() -> void:
	var stone := BuildKit.stone_mat(Color(0.47, 0.45, 0.42), 0.2)
	var wx := -HALF_X + EXT_T * 0.5
	var y := FLOOR_Y
	BuildKit.box_mm(self, Vector3(wx, y, 0.9), Vector3(-4.95, y + 0.12, 2.6), stone, true)
	BuildKit.box_mm(self, Vector3(wx, y, 1.0), Vector3(-5.2, y + 1.25, 1.3), stone, true)
	BuildKit.box_mm(self, Vector3(wx, y, 2.2), Vector3(-5.2, y + 1.25, 2.5), stone, true)
	BuildKit.box_mm(self, Vector3(wx, y + 0.8, 1.3), Vector3(-5.2, y + 1.25, 2.2), stone, true)
	BuildKit.box_mm(self, Vector3(wx, y + 0.12, 1.3), Vector3(wx + 0.05, y + 0.8, 2.2), BuildKit.color_mat(Color(0.06, 0.05, 0.05)), false)
	BuildKit.box_mm(self, Vector3(wx, y + 1.25, 0.88), Vector3(-5.1, y + 1.33, 2.62), BuildKit.wood_mat(Color(0.3, 0.2, 0.12), 0, 0.5, 0.02), true, "Mantel")
	BuildKit.box_mm(self, Vector3(wx, y + 1.33, 1.15), Vector3(-5.45, WALL_TOP, 2.35), stone, true)
	var fire := Fireplace.new()
	fire.name = "Fireplace"
	fire.position = Vector3(-5.6, y + 0.12, 1.75)
	add_child(fire)
	# Familienfoto auf dem Kaminsims (GDD 3.1)
	_photo(Vector3(-5.35, y + 1.33, 2.2), 90.0, 0.16, 0.12)


func _build_lights() -> void:
	var living := _lamp(Vector3(-2.0, WALL_TOP, 1.75), 1.5, 8.5, true)
	var dining := _lamp(Vector3(-0.2, WALL_TOP, 3.0), 0.9, 5.0, false)
	var bedroom := _lamp(Vector3(-3.5, WALL_TOP, -2.75), 1.0, 5.5, true)
	var storage := _lamp(Vector3(0.5, WALL_TOP, -2.75), 0.8, 4.0, false)
	var tech := _lamp(Vector3(4.0, WALL_TOP, -2.75), 1.0, 5.0, true)
	var workshop := _lamp(Vector3(4.0, WALL_TOP, 1.75), 1.3, 6.5, true)
	var porch := Lamp.new()
	porch.style = "wall"
	porch.energy = 1.4
	porch.light_range = 9.0
	porch.position = Vector3(-4.0, FLOOR_Y + 2.05, HALF_Z + EXT_T * 0.5)
	add_child(porch)

	var inside_front := HALF_Z - EXT_T * 0.5 - 0.012
	var hall_back := -1.0 - INT_T * 0.5 - 0.012
	_switch("living", "Licht Wohnzimmer", Vector3(-3.8, FLOOR_Y + 1.25, inside_front), 180.0, [living, dining])
	_switch("porch", "Licht Veranda", Vector3(-4.05, FLOOR_Y + 1.25, inside_front), 180.0, [porch])
	_switch("bedroom", "Licht Schlafzimmer", Vector3(-1.75, FLOOR_Y + 1.25, hall_back), 180.0, [bedroom])
	_switch("storage", "Licht Vorratsraum", Vector3(1.3, FLOOR_Y + 1.25, hall_back), 180.0, [storage])
	_switch("tech", "Licht Technikraum", Vector3(4.75, FLOOR_Y + 1.25, hall_back), 180.0, [tech])
	_switch("workshop", "Licht Werkstatt", Vector3(2.0 + INT_T * 0.5 + 0.012, FLOOR_Y + 1.25, 2.35), 90.0, [workshop])


func _lamp(pos: Vector3, energy: float, light_range: float, shadow: bool) -> Lamp:
	var lamp := Lamp.new()
	lamp.position = pos
	lamp.energy = energy
	lamp.light_range = light_range
	lamp.casts_shadow = shadow
	add_child(lamp)
	return lamp


func _switch(key: String, label: String, pos: Vector3, rot_y: float, lamps: Array) -> void:
	var sw := LightSwitch.new()
	sw.name = "Switch_" + key
	sw.room_name = label
	for l: Lamp in lamps:
		sw.lamps.append(l)
	sw.position = pos
	sw.rotation_degrees.y = rot_y
	add_child(sw)
	switches[key] = sw


# --- Einrichtung --------------------------------------------------------

func _build_living_room() -> void:
	var y := FLOOR_Y
	var fabric := BuildKit.color_mat(Color(0.29, 0.31, 0.26), 1.0)
	var wood := BuildKit.wood_mat(Color(0.38, 0.25, 0.15), 0, 0.12, 0.04)
	BuildKit.box_mm(self, Vector3(-5.0, y, 0.6), Vector3(-2.4, y + 0.012, 2.9), BuildKit.color_mat(Color(0.33, 0.12, 0.1), 1.0), false, "Rug")
	# Sofa Richtung Kamin
	BuildKit.box_mm(self, Vector3(-3.0, y, 0.9), Vector3(-2.1, y + 0.45, 2.6), fabric, true, "Sofa")
	BuildKit.box_mm(self, Vector3(-2.3, y + 0.45, 0.9), Vector3(-2.05, y + 0.95, 2.6), fabric, false)
	BuildKit.box_mm(self, Vector3(-3.0, y + 0.45, 0.75), Vector3(-2.05, y + 0.65, 0.92), fabric, false)
	BuildKit.box_mm(self, Vector3(-3.0, y + 0.45, 2.58), Vector3(-2.05, y + 0.65, 2.75), fabric, false)
	BuildKit.box_mm(self, Vector3(-4.2, y, 1.3), Vector3(-3.5, y + 0.42, 2.2), wood, true, "CoffeeTable")
	BuildKit.cylinder(self, 0.04, 0.12, Vector3(-3.8, y + 0.48, 1.6), BuildKit.color_mat(Color(0.8, 0.8, 0.78), 0.3), false)
	# Sessel
	BuildKit.box_mm(self, Vector3(-4.9, y, 3.2), Vector3(-4.2, y + 0.45, 3.9), fabric, true)
	BuildKit.box_mm(self, Vector3(-4.9, y + 0.45, 3.75), Vector3(-4.2, y + 0.95, 3.95), fabric, false)
	# Bücherregal an der Innenwand
	_shelf(Vector3(-5.6, y, -0.92), Vector3(-4.4, y + 1.9, -0.6), 4, true)
	# Esstisch – für vier gedeckt, benutzt wird nur ein Platz (GDD 3.1)
	_table(Vector3(-0.9, y, 2.5), Vector3(0.5, y + 0.76, 3.6))
	var plate := BuildKit.color_mat(Color(0.86, 0.85, 0.82), 0.7)
	for p: Vector3 in [Vector3(-0.55, 0, 2.75), Vector3(0.15, 0, 2.75), Vector3(-0.55, 0, 3.35), Vector3(0.15, 0, 3.35)]:
		BuildKit.cylinder(self, 0.13, 0.015, Vector3(p.x, y + 0.775, p.z), plate, false, Vector3.ZERO, -1.0, 20)
	_chair(Vector3(-0.55, y, 2.15), 0.0)
	_chair(Vector3(0.15, y, 2.15), 0.0)
	_chair(Vector3(-0.55, y, 3.95), 180.0)
	_chair(Vector3(0.15, y, 3.95), 180.0)
	# Kinderzeichnung an der Wand
	var paper := BuildKit.color_mat(Color(0.92, 0.9, 0.84), 0.9)
	var drawing_z := -1.0 + INT_T * 0.5 + 0.006
	BuildKit.box_mm(self, Vector3(-0.6, y + 1.35, drawing_z), Vector3(-0.2, y + 1.65, drawing_z + 0.004), paper, false)
	BuildKit.box_mm(self, Vector3(-0.55, y + 1.38, drawing_z + 0.004), Vector3(-0.25, y + 1.43, drawing_z + 0.006), BuildKit.color_mat(Color(0.2, 0.55, 0.2)), false)
	BuildKit.box_mm(self, Vector3(-0.48, y + 1.43, drawing_z + 0.004), Vector3(-0.36, y + 1.56, drawing_z + 0.006), BuildKit.color_mat(Color(0.8, 0.25, 0.2)), false)
	BuildKit.sphere(self, 0.035, Vector3(-0.27, y + 1.59, drawing_z + 0.008), BuildKit.color_mat(Color(0.95, 0.8, 0.1)), Vector3(1, 1, 0.2), 8)
	# Schreibtisch mit altem Monitor – wird später die Überwachungsstation (GDD 7.5)
	BuildKit.box_mm(self, Vector3(1.2, y, 3.0), Vector3(1.925, y + 0.75, 4.25), wood, true, "Desk")
	var dark := BuildKit.color_mat(Color(0.1, 0.1, 0.1), 0.6)
	BuildKit.box_mm(self, Vector3(1.45, y + 0.75, 3.35), Vector3(1.9, y + 1.15, 3.9), dark, false, "Monitor")
	BuildKit.box_mm(self, Vector3(1.44, y + 0.8, 3.4), Vector3(1.45, y + 1.1, 3.85), BuildKit.color_mat(Color(0.03, 0.05, 0.04), 0.1), false)
	_chair(Vector3(0.85, y, 3.6), 90.0)


func _build_bedroom() -> void:
	var y := FLOOR_Y
	var bed := Bed.new()
	bed.name = "Bed"
	bed.position = Vector3(-5.85, y, -4.35)
	add_child(bed)
	# Nachttisch mit Familienbild
	var wood := BuildKit.wood_mat(Color(0.35, 0.23, 0.14), 0, 0.15, 0.04)
	BuildKit.box_mm(self, Vector3(-4.2, y, -4.35), Vector3(-3.75, y + 0.55, -3.9), wood, true)
	_photo(Vector3(-4.0, y + 0.55, -4.25), 0.0, 0.18, 0.14)
	# Kleiderschrank
	BuildKit.box_mm(self, Vector3(-2.0, y, -4.35), Vector3(-1.15, y + 2.0, -3.65), wood, true, "Wardrobe")
	# Ungeöffnetes Geburtstagsgeschenk (GDD 3.1)
	BuildKit.box_mm(self, Vector3(-1.62, y, -1.65), Vector3(-1.3, y + 0.28, -1.33), BuildKit.color_mat(Color(0.65, 0.12, 0.14), 0.6), true, "Gift")
	var ribbon := BuildKit.color_mat(Color(0.95, 0.78, 0.2), 0.4)
	BuildKit.box_mm(self, Vector3(-1.49, y, -1.66), Vector3(-1.43, y + 0.285, -1.32), ribbon, false)
	BuildKit.box_mm(self, Vector3(-1.63, y, -1.52), Vector3(-1.29, y + 0.285, -1.46), ribbon, false)
	BuildKit.sphere(self, 0.05, Vector3(-1.46, y + 0.3, -1.49), ribbon, Vector3(1.2, 0.6, 1.2), 8)


func _build_storage() -> void:
	var y := FLOOR_Y
	_shelf(Vector3(-0.85, y, -4.35), Vector3(1.85, y + 2.1, -3.9), 5, false)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var colors := [Color(0.6, 0.5, 0.3), Color(0.4, 0.45, 0.3), Color(0.7, 0.3, 0.2), Color(0.5, 0.5, 0.55), Color(0.75, 0.7, 0.55)]
	for level in 5:
		var sy := y + 0.05 + level * (2.05 / 5.0)
		var x := -0.75
		while x < 1.7:
			var c: Color = colors[rng.randi() % colors.size()]
			if rng.randf() < 0.5:
				BuildKit.cylinder(self, 0.05, 0.13, Vector3(x, sy + 0.065, -4.12), BuildKit.color_mat(c, 0.5, 0.3), false, Vector3.ZERO, -1.0, 10)
				x += 0.13
			else:
				var w := rng.randf_range(0.15, 0.3)
				BuildKit.box(self, Vector3(w, rng.randf_range(0.12, 0.3), 0.3), Vector3(x + w * 0.5, sy + 0.1, -4.12), BuildKit.color_mat(c), false)
				x += w + 0.05
	# Säcke
	var sack := BuildKit.color_mat(Color(0.6, 0.53, 0.4), 1.0)
	BuildKit.sphere(self, 0.28, Vector3(-0.5, y + 0.22, -1.6), sack, Vector3(1.0, 0.8, 0.8), 10)
	BuildKit.sphere(self, 0.28, Vector3(-0.1, y + 0.22, -1.55), sack, Vector3(0.9, 0.8, 0.9), 10)


func _build_technical_room() -> void:
	var y := FLOOR_Y
	# Generator (noch ohne Funktion – Phase 3)
	var body := BuildKit.color_mat(Color(0.55, 0.15, 0.1), 0.6, 0.3)
	var metal := BuildKit.color_mat(Color(0.2, 0.2, 0.2), 0.5, 0.7)
	BuildKit.box_mm(self, Vector3(4.0, y, -4.25), Vector3(5.4, y + 0.1, -3.4), metal, true)
	BuildKit.box_mm(self, Vector3(4.1, y + 0.1, -4.15), Vector3(5.3, y + 0.75, -3.5), body, true, "Generator")
	BuildKit.cylinder(self, 0.18, 0.5, Vector3(4.45, y + 0.6, -3.82), metal, false, Vector3(0, 0, 90), -1.0, 12)
	BuildKit.cylinder(self, 0.05, 0.9, Vector3(5.0, y + 1.1, -4.3), metal, false, Vector3.ZERO, -1.0, 8)
	# Sicherungskasten
	BuildKit.box_mm(self, Vector3(5.8, y + 1.2, -3.2), Vector3(5.875, y + 1.8, -2.6), BuildKit.color_mat(Color(0.6, 0.6, 0.58), 0.5, 0.5), false, "FuseBox")
	# Kanister
	var red := BuildKit.color_mat(Color(0.7, 0.12, 0.08), 0.5)
	BuildKit.box_mm(self, Vector3(2.4, y, -4.3), Vector3(2.75, y + 0.45, -4.1), red, true)
	BuildKit.box_mm(self, Vector3(2.8, y, -4.3), Vector3(3.15, y + 0.45, -4.1), red, true)


func _build_workshop() -> void:
	var y := FLOOR_Y
	var wood := BuildKit.wood_mat(Color(0.45, 0.32, 0.2), 0, 0.15, 0.04)
	var metal := BuildKit.color_mat(Color(0.3, 0.3, 0.32), 0.45, 0.8)
	BuildKit.box_mm(self, Vector3(5.1, y + 0.82, -0.2), Vector3(5.875, y + 0.9, 3.6), wood, true, "Workbench")
	for z: float in [-0.1, 3.5]:
		BuildKit.box_mm(self, Vector3(5.15, y, z - 0.05), Vector3(5.8, y + 0.82, z + 0.05), wood, true)
	BuildKit.box_mm(self, Vector3(5.2, y + 0.9, 0.3), Vector3(5.45, y + 1.02, 0.6), metal, false, "Vise")
	# Werkzeugwand
	var board_z := -1.0 + INT_T * 0.5
	BuildKit.box_mm(self, Vector3(3.0, y + 1.0, board_z), Vector3(5.0, y + 2.0, board_z + 0.03), BuildKit.color_mat(Color(0.6, 0.5, 0.36)), false, "Pegboard")
	for i in 6:
		BuildKit.box(self, Vector3(0.05, 0.3 + (i % 3) * 0.08, 0.03), Vector3(3.25 + i * 0.3, y + 1.5, board_z + 0.05), metal, false)
	# Bretterstapel
	var lumber := BuildKit.wood_mat(Color(0.55, 0.42, 0.28), 0, 0.5, 0.02)
	for i in 5:
		BuildKit.box_mm(self, Vector3(2.4, y + i * 0.06, 3.6), Vector3(4.6, y + 0.05 + i * 0.06, 3.85), lumber, i == 0)


# --- Möbel-Helfer -------------------------------------------------------

func _table(from: Vector3, to: Vector3) -> void:
	var wood := BuildKit.wood_mat(Color(0.4, 0.26, 0.16), 0, 0.12, 0.04)
	BuildKit.box_mm(self, Vector3(from.x, to.y - 0.05, from.z), to, wood, true)
	for p: Vector2 in [Vector2(from.x + 0.06, from.z + 0.06), Vector2(to.x - 0.06, from.z + 0.06),
			Vector2(from.x + 0.06, to.z - 0.06), Vector2(to.x - 0.06, to.z - 0.06)]:
		BuildKit.box_mm(self, Vector3(p.x - 0.04, from.y, p.y - 0.04), Vector3(p.x + 0.04, to.y - 0.05, p.y + 0.04), wood, true)


func _chair(pos: Vector3, rot_y: float) -> void:
	var chair := Node3D.new()
	chair.position = pos
	chair.rotation_degrees.y = rot_y
	add_child(chair)
	var wood := BuildKit.wood_mat(Color(0.36, 0.24, 0.15), 0, 0.12, 0.04)
	BuildKit.box_mm(chair, Vector3(-0.21, 0.42, -0.21), Vector3(0.21, 0.46, 0.21), wood, true)
	BuildKit.box_mm(chair, Vector3(-0.21, 0.46, -0.21), Vector3(0.21, 0.95, -0.18), wood, false)
	for p: Vector2 in [Vector2(-0.18, -0.18), Vector2(0.18, -0.18), Vector2(-0.18, 0.18), Vector2(0.18, 0.18)]:
		BuildKit.box_mm(chair, Vector3(p.x - 0.025, 0, p.y - 0.025), Vector3(p.x + 0.025, 0.42, p.y + 0.025), wood, false)


func _shelf(from: Vector3, to: Vector3, levels: int, books: bool) -> void:
	var wood := BuildKit.wood_mat(Color(0.34, 0.23, 0.14), 0, 0.12, 0.03)
	var lo := Vector3(minf(from.x, to.x), from.y, minf(from.z, to.z))
	var hi := Vector3(maxf(from.x, to.x), to.y, maxf(from.z, to.z))
	BuildKit.box_mm(self, Vector3(lo.x, lo.y, lo.z), Vector3(lo.x + 0.03, hi.y, hi.z), wood, true)
	BuildKit.box_mm(self, Vector3(hi.x - 0.03, lo.y, lo.z), Vector3(hi.x, hi.y, hi.z), wood, true)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(absf(from.x * 100.0 + from.z * 10.0))
	for i in levels:
		var sy := lo.y + 0.05 + i * ((hi.y - lo.y - 0.05) / float(levels))
		BuildKit.box_mm(self, Vector3(lo.x, sy - 0.025, lo.z), Vector3(hi.x, sy, hi.z), wood, true)
		if books:
			var x := lo.x + 0.05
			while x < hi.x - 0.1:
				var w := rng.randf_range(0.03, 0.07)
				var h := rng.randf_range(0.2, 0.3)
				var c := Color.from_hsv(rng.randf(), rng.randf_range(0.3, 0.6), rng.randf_range(0.25, 0.5))
				BuildKit.box(self, Vector3(w, h, (hi.z - lo.z) * 0.8), Vector3(x + w * 0.5, sy + h * 0.5, (lo.z + hi.z) * 0.5), BuildKit.color_mat(c), false)
				x += w + 0.005


func _photo(pos: Vector3, rot_y: float, w: float, h: float) -> void:
	var p := Node3D.new()
	p.position = pos
	p.rotation_degrees.y = rot_y
	add_child(p)
	BuildKit.box(p, Vector3(w, h, 0.015), Vector3(0, h * 0.5, 0), BuildKit.color_mat(Color(0.2, 0.15, 0.1), 0.6), false, Vector3(-12, 0, 0))
	BuildKit.box(p, Vector3(w * 0.78, h * 0.72, 0.004), Vector3(0, h * 0.5, 0.009), BuildKit.color_mat(Color(0.55, 0.5, 0.42), 0.4), false, Vector3(-12, 0, 0))
