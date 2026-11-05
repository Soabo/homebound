class_name Cabin
extends Node3D
## Die Blockhütte (GDD 3.3). Grundfläche 12 x 9 m, Eingang nach Süden (+z).
##
## Raumaufteilung (Draufsicht, Norden oben = -z):
##   +-------------+---------+-----------+
##   | Schlafzimmer| Vorrat  | Technik   |   z -4.5 .. -1
##   +-------------+---------+-----------+
##   |  Wohnzimmer + Küche   | Werkstatt |   z -1 .. 4.5
##   +----[Tür]--------------+-----------+
##   x -6        -1         2           6
##
## Außen liegen echte Rundholz-Stämme mit Eckköpfen; die Kollision kommt von
## unsichtbaren Wandkörpern, innen sind die Wände mit Brettern verkleidet.

const FLOOR_Y := 0.45
const WALL_H := 2.8
const WALL_TOP := FLOOR_Y + WALL_H
const EXT_T := 0.25
const INT_T := 0.15
const HALF_X := 6.0
const HALF_Z := 4.5
const LOG_R := 0.155
const CLAD := 0.14  ## Abstand der Innenverkleidung von der Wandmitte
const ROOF_RISE := 2.2

const WINDOW_NAMES := {
	"WindowLiving": "Wohnzimmerfenster",
	"WindowWorkshopFront": "Werkstattfenster",
	"WindowBedroom": "Schlafzimmerfenster",
	"WindowTechnical": "Technikraumfenster",
	"WindowWorkshopEast": "Werkstattfenster Ost",
}

var front_door: Door
var switches: Dictionary = {}
var _rng := RandomNumberGenerator.new()

# Materialien
var m_logs: Material
var m_wall: Material
var m_floor: Material
var m_stone: Material
var m_stone_dark: Material
var m_beam: Material
var m_wood: Material
var m_wood_dark: Material
var m_iron: Material
var m_fabric: Material


## Für Atmosphäre/Sound: steht ein Punkt in der Hütte?
static func is_inside(p: Vector3) -> bool:
	return absf(p.x) < HALF_X and absf(p.z) < HALF_Z and p.y > FLOOR_Y - 0.3 and p.y < WALL_TOP + 0.5


func _ready() -> void:
	name = "Cabin"
	_rng.seed = 2024
	m_logs = BuildKit.tex_mat("logs", 1.1)
	m_wall = BuildKit.tex_mat("planks_v", 1.0)
	m_floor = BuildKit.tex_mat("floor", 1.4)
	m_stone = BuildKit.tex_mat("stone", 0.8)
	m_stone_dark = BuildKit.tex_mat("stone_dark", 0.9)
	m_beam = BuildKit.tex_mat("planks_h", 2.0, Color(0.55, 0.5, 0.48))
	m_wood = BuildKit.tex_mat("planks_h", 0.7)
	m_wood_dark = BuildKit.tex_mat("planks_h", 0.7, Color(0.55, 0.5, 0.48))
	m_iron = BuildKit.tex_mat("metal", 0.4, Color(0.55, 0.52, 0.5), 0.55)
	m_fabric = BuildKit.tex_mat("fabric", 0.5)

	_build_shell()
	_build_roof()
	_build_porch()
	_build_openings()
	_build_fireplace()
	_build_lights()
	_build_living_room()
	_build_kitchen()
	_build_bedroom()
	_build_storage()
	_build_technical_room()
	_build_workshop()
	_build_reflection_probe()
	# Staub in der Luft (sichtbar im Licht) und Rauch aus dem Schornstein
	var dust := ParticlesKit.dust(Vector3(HALF_X - 0.4, WALL_H * 0.45, HALF_Z - 0.4))
	dust.position = Vector3(0, FLOOR_Y + WALL_H * 0.5, 0)
	add_child(dust)
	var smoke := ParticlesKit.smoke()
	smoke.position = Vector3(-HALF_X - 0.5, WALL_TOP + ROOF_RISE + 1.2, 1.75)
	add_child(smoke)


# --- Rohbau -------------------------------------------------------------

func _build_shell() -> void:
	BuildKit.box_mm(self, Vector3(-HALF_X - 0.2, 0, -HALF_Z - 0.2), Vector3(HALF_X + 0.2, FLOOR_Y - 0.06, HALF_Z + 0.2), m_stone, true, "Foundation")
	BuildKit.box_mm(self, Vector3(-HALF_X + 0.1, FLOOR_Y - 0.08, -HALF_Z + 0.1), Vector3(HALF_X - 0.1, FLOOR_Y, HALF_Z - 0.1), m_floor, true, "Floor")

	var hz := HALF_Z - EXT_T * 0.5
	# Öffnungen: Vector4(mitte entlang der Wand, breite, unterkante, oberkante)
	var front := [Vector4(3.0, 1.0, 0.0, 2.1), Vector4(6.0, 1.3, 0.9, 2.0), Vector4(10.0, 1.0, 1.0, 1.9)]
	var back := [Vector4(2.5, 1.0, 1.0, 1.9), Vector4(10.5, 0.6, 1.5, 2.0)]
	# Unsichtbare Kollision
	BuildKit.wall(self, Vector2(-HALF_X, HALF_Z), Vector2(HALF_X, HALF_Z), FLOOR_Y, WALL_H, EXT_T, null, front, "WallFront")
	BuildKit.wall(self, Vector2(-HALF_X, -HALF_Z), Vector2(HALF_X, -HALF_Z), FLOOR_Y, WALL_H, EXT_T, null, back, "WallBack")
	BuildKit.wall(self, Vector2(-HALF_X, -hz), Vector2(-HALF_X, hz), FLOOR_Y, WALL_H, EXT_T, null, [], "WallWest")
	BuildKit.wall(self, Vector2(HALF_X, -hz), Vector2(HALF_X, hz), FLOOR_Y, WALL_H, EXT_T, null, [Vector4(2.0 + hz, 1.0, 1.0, 1.9)], "WallEast")

	# Außen: Rundholz-Stämme. Vorder-/Rückwand und Seiten um eine halbe Lage versetzt.
	var step := LOG_R * 1.85
	var low := FLOOR_Y - 0.02
	var to_world := func(ops: Array, y_off: float) -> Array:
		var r := []
		for o: Vector4 in ops:
			r.append(Vector4(o.x, o.y, o.z + y_off, o.w + y_off))
		return r
	BuildKit.log_wall(self, Vector2(-HALF_X, HALF_Z), Vector2(HALF_X, HALF_Z), low, WALL_TOP, LOG_R, 0.38, m_logs, to_world.call(front, FLOOR_Y))
	BuildKit.log_wall(self, Vector2(-HALF_X, -HALF_Z), Vector2(HALF_X, -HALF_Z), low, WALL_TOP, LOG_R, 0.38, m_logs, to_world.call(back, FLOOR_Y))
	BuildKit.log_wall(self, Vector2(-HALF_X, -HALF_Z), Vector2(-HALF_X, HALF_Z), low + step * 0.5, WALL_TOP, LOG_R, 0.38, m_logs, [])
	BuildKit.log_wall(self, Vector2(HALF_X, -HALF_Z), Vector2(HALF_X, HALF_Z), low + step * 0.5, WALL_TOP, LOG_R, 0.38, m_logs,
			to_world.call([Vector4(2.0 + HALF_Z, 1.0, 1.0, 1.9)], FLOOR_Y))

	# Innen: Bretterverkleidung der Außenwände (Öffnungen auf die verschobenen Startpunkte umgerechnet)
	var ix := HALF_X - CLAD
	var iz := HALF_Z - CLAD
	var shift := HALF_X - ix
	var front_in := []
	for o: Vector4 in front:
		front_in.append(Vector4(o.x - shift, o.y, o.z, o.w))
	var back_in := []
	for o: Vector4 in back:
		back_in.append(Vector4(o.x - shift, o.y, o.z, o.w))
	BuildKit.wall(self, Vector2(-ix, iz), Vector2(ix, iz), FLOOR_Y, WALL_H, 0.03, m_wall, front_in, "CladFront")
	BuildKit.wall(self, Vector2(-ix, -iz), Vector2(ix, -iz), FLOOR_Y, WALL_H, 0.03, m_wall, back_in, "CladBack")
	BuildKit.wall(self, Vector2(-ix, -iz), Vector2(-ix, iz), FLOOR_Y, WALL_H, 0.03, m_wall, [], "CladWest")
	BuildKit.wall(self, Vector2(ix, -iz), Vector2(ix, iz), FLOOR_Y, WALL_H, 0.03, m_wall, [Vector4(2.0 + iz, 1.0, 1.0, 1.9)], "CladEast")

	# Innenwände
	var px := HALF_X - EXT_T * 0.5
	var pz := HALF_Z - EXT_T * 0.5
	BuildKit.wall(self, Vector2(-px, -1.0), Vector2(px, -1.0), FLOOR_Y, WALL_H, INT_T, m_wall,
			[Vector4(-2.5 + px, 0.9, 0.0, 2.05), Vector4(0.5 + px, 0.9, 0.0, 2.05), Vector4(4.0 + px, 0.9, 0.0, 2.05)], "WallInnerHall")
	BuildKit.wall(self, Vector2(-1.0, -pz), Vector2(-1.0, -1.075), FLOOR_Y, WALL_H, INT_T, m_wall, [], "WallBedStorage")
	BuildKit.wall(self, Vector2(2.0, -pz), Vector2(2.0, -1.075), FLOOR_Y, WALL_H, INT_T, m_wall, [], "WallStorageTech")
	BuildKit.wall(self, Vector2(2.0, -0.925), Vector2(2.0, pz), FLOOR_Y, WALL_H, INT_T, m_wall,
			[Vector4(1.5 + 0.925, 1.0, 0.0, 2.05)], "WallLivingWorkshop")
	# Türzargen der Innentüren
	for x: float in [-2.5, 0.5, 4.0]:
		_door_trim(Vector3(x, FLOOR_Y, -1.0), 0.0, 0.9, 2.05, INT_T)
	_door_trim(Vector3(2.0, FLOOR_Y, 1.5), 90.0, 1.0, 2.05, INT_T)

	# Decke und Balken
	BuildKit.box_mm(self, Vector3(-HALF_X, WALL_TOP, -HALF_Z), Vector3(HALF_X, WALL_TOP + 0.1, HALF_Z),
			BuildKit.tex_mat("planks_h", 1.2, Color(0.62, 0.58, 0.55)), false, "Ceiling")
	for x: float in [-4.6, -2.2, 0.2, 2.6, 4.9]:
		BuildKit.box(self, Vector3(0.22, 0.24, HALF_Z * 2.0 - 0.3), Vector3(x, WALL_TOP - 0.12, 0), m_beam, false)
	# Fußleisten
	var skirting := BuildKit.tex_mat("planks_h", 1.0, Color(0.5, 0.45, 0.42))
	BuildKit.box_mm(self, Vector3(-ix, FLOOR_Y, -iz + 0.015), Vector3(ix, FLOOR_Y + 0.1, -iz + 0.04), skirting, false)
	BuildKit.box_mm(self, Vector3(-ix + 0.015, FLOOR_Y, -iz), Vector3(-ix + 0.04, FLOOR_Y + 0.1, iz), skirting, false)


func _door_trim(pos: Vector3, rot_y: float, w: float, h: float, wall_t: float) -> void:
	var n := Node3D.new()
	n.position = pos
	n.rotation_degrees.y = rot_y
	add_child(n)
	var d := wall_t + 0.04
	BuildKit.box(n, Vector3(0.08, h + 0.08, d), Vector3(-w * 0.5 - 0.04, h * 0.5 + 0.04, 0), m_wood_dark, false)
	BuildKit.box(n, Vector3(0.08, h + 0.08, d), Vector3(w * 0.5 + 0.04, h * 0.5 + 0.04, 0), m_wood_dark, false)
	BuildKit.box(n, Vector3(w + 0.16, 0.1, d), Vector3(0, h + 0.05, 0), m_wood_dark, false)


func _build_roof() -> void:
	var shingles := BuildKit.tex_mat("shingles", 1.3)
	var overhang := 0.7
	var slope := ROOF_RISE / HALF_Z
	var angle := rad_to_deg(atan(slope))
	var run := HALF_Z + overhang
	var length := run / cos(atan(slope))
	var center_z := run * 0.5
	var center_y := WALL_TOP + ROOF_RISE - center_z * slope + 0.25
	var roof_len := HALF_X * 2.0 + overhang * 2.0
	for side: float in [1.0, -1.0]:
		BuildKit.box(self, Vector3(roof_len, 0.2, length), Vector3(0, center_y, center_z * side), shingles, false, Vector3(angle * side, 0, 0))
		# Traufbrett
		var eave_y := WALL_TOP + ROOF_RISE - run * slope + 0.18
		BuildKit.box(self, Vector3(roof_len + 0.05, 0.22, 0.06), Vector3(0, eave_y, run * side), m_wood_dark, false, Vector3(angle * side, 0, 0))
		# Ortgangbretter an den Giebelseiten
		for x: float in [-roof_len * 0.5, roof_len * 0.5]:
			BuildKit.box(self, Vector3(0.06, 0.28, length), Vector3(x, center_y - 0.04, center_z * side), m_wood_dark, false, Vector3(angle * side, 0, 0))
	# Firstbalken als Stamm
	BuildKit.cylinder(self, 0.16, roof_len + 0.1, Vector3(0, WALL_TOP + ROOF_RISE + 0.32, 0), m_logs, false, Vector3(0, 0, 90), -1.0, 8)
	# Giebel aus kürzer werdenden Stämmen, dahinter eine Bretterfüllung
	for sx: float in [-HALF_X, HALF_X]:
		var y := WALL_TOP + LOG_R
		while y < WALL_TOP + ROOF_RISE:
			var half := HALF_Z * (1.0 - (y - WALL_TOP) / ROOF_RISE) + 0.15
			BuildKit.cylinder(self, LOG_R * 0.95, half * 2.0, Vector3(sx, y, 0), m_logs, false, Vector3(90, 0, 0), -1.0, 8)
			y += LOG_R * 1.85
		BuildKit.gable(self, HALF_Z * 2.0, ROOF_RISE, 0.05, Vector3(sx - signf(sx) * 0.12, WALL_TOP, 0), 90.0, m_wall)
	# Schornstein mit Abdeckplatte
	var cx0 := -HALF_X - 0.85
	var cx1 := -HALF_X - 0.15
	BuildKit.box_mm(self, Vector3(cx0, 0, 1.15), Vector3(cx1, WALL_TOP + ROOF_RISE + 1.0, 2.35), m_stone, true, "Chimney")
	BuildKit.box_mm(self, Vector3(cx0 - 0.08, WALL_TOP + ROOF_RISE + 1.0, 1.07), Vector3(cx1 + 0.08, WALL_TOP + ROOF_RISE + 1.1, 2.43), m_stone_dark, false)
	BuildKit.box_mm(self, Vector3(cx0 + 0.15, WALL_TOP + ROOF_RISE + 1.1, 1.45), Vector3(cx1 - 0.15, WALL_TOP + ROOF_RISE + 1.12, 2.05), BuildKit.color_mat(Color(0.03, 0.03, 0.03)), false)


func _build_porch() -> void:
	var deck := BuildKit.tex_mat("floor", 1.2, Color(0.95, 0.92, 0.9))
	var z0 := HALF_Z + 0.2
	BuildKit.box_mm(self, Vector3(-5.6, FLOOR_Y - 0.08, z0), Vector3(1.2, FLOOR_Y, 6.6), deck, true, "PorchDeck")
	BuildKit.box_mm(self, Vector3(-5.6, 0, z0), Vector3(1.2, FLOOR_Y - 0.08, 6.5), m_stone, true)
	# Treppe: sichtbare Stufen, darunter eine unsichtbare Rampe zum Hochlaufen
	BuildKit.box_mm(self, Vector3(-4.0, 0, 6.6), Vector3(-2.0, 0.3, 7.05), deck, false)
	BuildKit.box_mm(self, Vector3(-4.0, 0, 7.05), Vector3(-2.0, 0.15, 7.5), deck, false)
	var ramp_len := sqrt(1.3 * 1.3 + FLOOR_Y * FLOOR_Y)
	var ramp_angle := rad_to_deg(atan(FLOOR_Y / 1.3))
	BuildKit.collider_box(self, Vector3(2.0, 0.1, ramp_len), Vector3(-3.0, FLOOR_Y * 0.5 - 0.05, 7.25), Vector3(ramp_angle, 0, 0))
	# Pfosten aus Rundholz, Geländer
	var post_top := WALL_TOP - 0.62
	for x: float in [-5.4, -4.15, -1.85, 1.0]:
		BuildKit.cylinder(self, 0.1, post_top - FLOOR_Y, Vector3(x, (FLOOR_Y + post_top) * 0.5, 6.4), m_logs, true, Vector3.ZERO, 0.09, 8)
	for span: Vector2 in [Vector2(-5.4, -4.15), Vector2(-1.85, 1.0)]:
		var mid := (span.x + span.y) * 0.5
		var len := span.y - span.x
		BuildKit.cylinder(self, 0.05, len, Vector3(mid, FLOOR_Y + 0.9, 6.4), m_logs, false, Vector3(0, 0, 90), -1.0, 6)
		BuildKit.collider_box(self, Vector3(len, 0.9, 0.1), Vector3(mid, FLOOR_Y + 0.45, 6.4))
		var n := int(len / 0.35)
		for i in n:
			BuildKit.box(self, Vector3(0.05, 0.85, 0.05), Vector3(span.x + 0.2 + i * (len - 0.4) / maxf(n - 1, 1), FLOOR_Y + 0.45, 6.4), m_wood, false)
	var roof_angle := rad_to_deg(atan(0.5 / 2.4))
	BuildKit.box(self, Vector3(7.2, 0.12, 2.6), Vector3(-2.2, WALL_TOP - 0.52, 5.85), BuildKit.tex_mat("shingles", 1.3), false, Vector3(roof_angle, 0, 0), "PorchRoof")
	BuildKit.box(self, Vector3(7.0, 0.16, 0.16), Vector3(-2.2, post_top + 0.02, 6.4), m_beam, false)
	# Sitzbank an der Hauswand
	_porch_bench()
	# Feuerholz auf der Veranda
	var log_mat := BuildKit.tex_mat("logs", 0.6)
	for row in 5:
		for i in 7 - row:
			BuildKit.cylinder(self, 0.09, 0.85, Vector3(-5.3, FLOOR_Y + 0.09 + row * 0.16, 4.95 + i * 0.19 + row * 0.09),
					log_mat, false, Vector3(0, _rng.randf_range(-6, 6), 90), -1.0, 7)
	BuildKit.collider_box(self, Vector3(0.9, 0.8, 1.4), Vector3(-5.3, FLOOR_Y + 0.4, 5.5))


## Gartenbank auf der Veranda als eigener Knoten (nachts kann sie woanders stehen).
func _porch_bench() -> void:
	var bench := Node3D.new()
	bench.name = "PorchBench"
	add_child(bench)
	# Sitzfläche aus Latten, vier kräftige Beine mit Querstreben, Rückenlehne und Armlehnen
	var bz0 := 4.8
	var bz1 := 5.22
	for i in 4:
		var z := bz0 + 0.02 + i * 0.1
		BuildKit.box_mm(bench, Vector3(-1.5, FLOOR_Y + 0.42, z), Vector3(0.6, FLOOR_Y + 0.465, z + 0.085), m_wood, false)
	BuildKit.collider_box(bench, Vector3(2.1, 0.47, 0.42), Vector3(-0.45, FLOOR_Y + 0.235, (bz0 + bz1) * 0.5))
	for x: float in [-1.42, 0.52]:
		for z: float in [bz0 + 0.04, bz1 - 0.04]:
			BuildKit.box_mm(bench, Vector3(x - 0.04, FLOOR_Y, z - 0.04), Vector3(x + 0.04, FLOOR_Y + 0.42, z + 0.04), m_wood_dark, false)
		BuildKit.box_mm(bench, Vector3(x - 0.03, FLOOR_Y + 0.12, bz0), Vector3(x + 0.03, FLOOR_Y + 0.17, bz1), m_wood_dark, false)
		# Armlehne mit Stütze vorn
		BuildKit.box_mm(bench, Vector3(x - 0.04, FLOOR_Y + 0.465, bz1 - 0.08), Vector3(x + 0.04, FLOOR_Y + 0.68, bz1), m_wood_dark, false)
		BuildKit.box_mm(bench, Vector3(x - 0.05, FLOOR_Y + 0.68, bz0 - 0.04), Vector3(x + 0.05, FLOOR_Y + 0.72, bz1 + 0.02), m_wood, false)
	BuildKit.box_mm(bench, Vector3(-1.38, FLOOR_Y + 0.12, (bz0 + bz1) * 0.5 - 0.025), Vector3(0.48, FLOOR_Y + 0.16, (bz0 + bz1) * 0.5 + 0.025), m_wood_dark, false)
	# Rückenlehne: zwei Pfosten, drei Latten
	for x: float in [-1.42, 0.52]:
		BuildKit.box_mm(bench, Vector3(x - 0.04, FLOOR_Y + 0.42, bz0 - 0.02), Vector3(x + 0.04, FLOOR_Y + 0.95, bz0 + 0.05), m_wood_dark, false)
	for k in 3:
		var y := FLOOR_Y + 0.56 + k * 0.13
		BuildKit.box_mm(bench, Vector3(-1.4, y, bz0 - 0.01), Vector3(0.5, y + 0.08, bz0 + 0.03), m_wood, false)


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
	front_door.make_entry()
	_door_trim(Vector3(-3.0, FLOOR_Y, HALF_Z), 0.0, 1.0, 2.1, 0.36)

	# Fenster (GDD 18.2: zwei zerstörbare Fenster im Wohnbereich – Schaden folgt später)
	_window("WindowLiving", Vector3(0.0, FLOOR_Y + 0.9, HALF_Z), 0.0, 1.3, 1.1)
	_window("WindowWorkshopFront", Vector3(4.0, FLOOR_Y + 1.0, HALF_Z), 0.0, 1.0, 0.9)
	_window("WindowBedroom", Vector3(-3.5, FLOOR_Y + 1.0, -HALF_Z), 180.0, 1.0, 0.9)
	_window("WindowTechnical", Vector3(4.5, FLOOR_Y + 1.5, -HALF_Z), 180.0, 0.6, 0.5)
	_window("WindowWorkshopEast", Vector3(HALF_X, FLOOR_Y + 1.0, 2.0), 90.0, 1.0, 0.9)
	# Fensterläden außen
	_shutters(Vector3(0.0, FLOOR_Y + 0.9, HALF_Z + 0.2), 0.0, 1.3, 1.1)
	_shutters(Vector3(4.0, FLOOR_Y + 1.0, HALF_Z + 0.2), 0.0, 1.0, 0.9)
	_shutters(Vector3(-3.5, FLOOR_Y + 1.0, -HALF_Z - 0.2), 180.0, 1.0, 0.9)
	# Vorhänge innen
	_curtains(Vector3(0.0, FLOOR_Y + 2.15, HALF_Z - CLAD - 0.08), 0.0, 1.3, BuildKit.tex_mat("fabric", 0.6, Color(1.5, 1.3, 0.95)))
	_curtains(Vector3(-3.5, FLOOR_Y + 2.05, -HALF_Z + CLAD + 0.08), 180.0, 1.0, BuildKit.tex_mat("fabric_red", 0.6))


func _window(node_name: String, pos: Vector3, rot_y: float, w: float, h: float) -> void:
	var win := CabinWindow.new()
	win.name = node_name
	win.window_name = WINDOW_NAMES.get(node_name, "Fenster")
	win.width = w
	win.height = h
	win.wall_thickness = 0.34
	win.position = pos
	win.rotation_degrees.y = rot_y
	add_child(win)


func _shutters(pos: Vector3, rot_y: float, w: float, h: float) -> void:
	var n := Node3D.new()
	n.position = pos
	n.rotation_degrees.y = rot_y
	add_child(n)
	var mat := BuildKit.tex_mat("planks_v", 0.6, Color(0.55, 0.6, 0.5))
	for side: float in [-1.0, 1.0]:
		var x := side * (w * 0.5 + w * 0.25 + 0.06)
		BuildKit.box(n, Vector3(w * 0.5, h + 0.1, 0.04), Vector3(x, h * 0.5, 0.0), mat, false, Vector3(0, side * 8.0, 0))
		BuildKit.box(n, Vector3(w * 0.45, 0.06, 0.02), Vector3(x, h * 0.25, 0.03), m_wood_dark, false)
		BuildKit.box(n, Vector3(w * 0.45, 0.06, 0.02), Vector3(x, h * 0.75, 0.03), m_wood_dark, false)


func _curtains(rod_pos: Vector3, rot_y: float, w: float, mat: Material) -> void:
	var n := Node3D.new()
	n.position = rod_pos
	n.rotation_degrees.y = rot_y
	add_child(n)
	BuildKit.cylinder(n, 0.015, w + 0.6, Vector3.ZERO, m_iron, false, Vector3(0, 0, 90), -1.0, 6)
	for side: float in [-1.0, 1.0]:
		for f in 3:
			var x := side * (w * 0.5 + 0.05 + f * 0.09)
			BuildKit.box(n, Vector3(0.1, 1.4, 0.02), Vector3(x, -0.72, -0.02 + (f % 2) * 0.03), mat, false)


# --- Kamin --------------------------------------------------------------

func _build_fireplace() -> void:
	var wx := -HALF_X + CLAD
	var y := FLOOR_Y
	var front_x := -5.15
	# Kern: Herdplatte, Pfeiler, Sturz, Rückwand
	BuildKit.box_mm(self, Vector3(wx, y, 0.85), Vector3(-4.85, y + 0.12, 2.65), m_stone, true)
	BuildKit.box_mm(self, Vector3(wx, y, 0.95), Vector3(front_x, y + 1.32, 1.3), m_stone, true)
	BuildKit.box_mm(self, Vector3(wx, y, 2.2), Vector3(front_x, y + 1.32, 2.55), m_stone, true)
	BuildKit.box_mm(self, Vector3(wx, y + 0.95, 1.3), Vector3(front_x, y + 1.32, 2.2), m_stone, true)
	BuildKit.box_mm(self, Vector3(wx, y + 0.12, 1.3), Vector3(wx + 0.06, y + 0.95, 2.2), m_stone_dark, false)
	# Ruß im Feuerraum
	BuildKit.box_mm(self, Vector3(wx + 0.06, y + 0.7, 1.3), Vector3(front_x - 0.05, y + 0.95, 2.2), BuildKit.color_mat(Color(0.04, 0.035, 0.03)), false)
	# Einzelne Steine auf der Front für Tiefe
	var sy := y + 0.14
	var row := 0
	while sy < y + 1.28:
		var h := _rng.randf_range(0.11, 0.16)
		var z := 0.95 + (0.0 if row % 2 == 0 else 0.1)
		while z < 2.55:
			var w := _rng.randf_range(0.14, 0.24)
			var zc := z + w * 0.5
			var in_opening := zc > 1.25 and zc < 2.25 and sy < y + 0.97
			if not in_opening and zc < 2.55:
				var tone := _rng.randf_range(0.75, 1.15)
				BuildKit.box(self, Vector3(0.05, h - 0.02, w - 0.02), Vector3(front_x + 0.02, sy + h * 0.5, minf(zc, 2.5)),
						BuildKit.tex_mat("stone", 0.8, Color(tone, tone, tone)), false, Vector3(_rng.randf_range(-4, 4), 0, 0))
			z += w
		sy += h
		row += 1
	# Bogensteine
	var center := Vector2(1.75, y + 0.5)
	for i in 9:
		var a := PI * float(i) / 8.0
		var p := center + Vector2(cos(a), sin(a)) * 0.62
		BuildKit.box(self, Vector3(0.07, 0.12, 0.2), Vector3(front_x + 0.04, p.y, p.x), m_stone_dark, false, Vector3(rad_to_deg(a) - 90.0, 0, 0))
	# Kaminsims
	BuildKit.box_mm(self, Vector3(wx, y + 1.32, 0.82), Vector3(-5.0, y + 1.42, 2.68), m_beam, true, "Mantel")
	for z: float in [1.0, 2.5]:
		BuildKit.box_mm(self, Vector3(-5.2, y + 1.18, z - 0.05), Vector3(-5.05, y + 1.32, z + 0.05), m_beam, false)
	# Kaminschacht bis zur Decke
	BuildKit.box_mm(self, Vector3(wx, y + 1.42, 1.1), Vector3(-5.4, WALL_TOP, 2.4), m_stone_dark, true)
	var fire := Fireplace.new()
	fire.name = "Fireplace"
	fire.position = Vector3(-5.6, y + 0.12, 1.75)
	add_child(fire)
	# Funkenschutzgitter
	var grate := Node3D.new()
	grate.position = Vector3(-4.98, y + 0.12, 1.75)
	add_child(grate)
	BuildKit.box(grate, Vector3(0.02, 0.03, 1.0), Vector3(0, 0.6, 0), m_iron, false)
	BuildKit.box(grate, Vector3(0.02, 0.03, 1.0), Vector3(0, 0.02, 0), m_iron, false)
	for i in 11:
		BuildKit.box(grate, Vector3(0.015, 0.6, 0.015), Vector3(0, 0.3, -0.5 + i * 0.1), m_iron, false)
	# Kaminbesteck und Holzkorb
	BuildKit.cylinder(self, 0.08, 0.02, Vector3(-4.75, y + 0.01, 2.85), m_iron, false, Vector3.ZERO, -1.0, 8)
	BuildKit.cylinder(self, 0.012, 0.75, Vector3(-4.75, y + 0.38, 2.85), m_iron, false, Vector3.ZERO, -1.0, 4)
	for i in 3:
		BuildKit.cylinder(self, 0.008, 0.6, Vector3(-4.75 + (i - 1) * 0.04, y + 0.35, 2.9), m_iron, false, Vector3((i - 1) * 6.0, 0, (i - 1) * 6.0), -1.0, 4)
	BuildKit.cylinder(self, 0.25, 0.3, Vector3(-4.75, y + 0.15, 0.55), BuildKit.tex_mat("planks_v", 0.4, Color(0.8, 0.7, 0.6)), true, Vector3.ZERO, 0.22, 10)
	for i in 4:
		BuildKit.cylinder(self, 0.06, 0.5, Vector3(-4.75 + (i % 2) * 0.1 - 0.05, y + 0.34 + (i / 2) * 0.1, 0.55), BuildKit.tex_mat("logs", 0.5), false, Vector3(90, 30 * i, 0), -1.0, 6)
	# Auf dem Sims: Familienfoto (GDD 3.1), Krug, Kerzen
	_photo(Vector3(-5.35, y + 1.42, 2.25), 90.0, 0.16, 0.12).add_to_group("family_photo")
	BuildKit.cylinder(self, 0.08, 0.2, Vector3(-5.3, y + 1.52, 1.35), BuildKit.color_mat(Color(0.5, 0.22, 0.12), 0.7), false, Vector3.ZERO, 0.05, 10)
	for z: float in [1.75, 1.9]:
		BuildKit.cylinder(self, 0.025, 0.12 + (z - 1.75), Vector3(-5.3, y + 1.48 + (z - 1.75) * 0.5, z), BuildKit.color_mat(Color(0.9, 0.86, 0.75)), false, Vector3.ZERO, -1.0, 6)


# --- Licht --------------------------------------------------------------

func _build_lights() -> void:
	var living := _lamp(Vector3(-2.2, WALL_TOP - 0.24, 1.75), 1.5, 8.5, true)
	var dining := _lamp(Vector3(-0.2, WALL_TOP, 3.0), 0.9, 5.0, false)
	var lantern_a := _lantern(Vector3(-HALF_X + CLAD + 0.02, FLOOR_Y + 1.85, 0.6), 90.0)
	var lantern_b := _lantern(Vector3(-HALF_X + CLAD + 0.02, FLOOR_Y + 1.85, 2.9), 90.0)
	var bedroom := _lamp(Vector3(-3.5, WALL_TOP, -2.75), 1.0, 5.5, true)
	var storage := _lamp(Vector3(0.5, WALL_TOP, -2.75), 0.8, 4.0, false)
	var tech := _lamp(Vector3(4.0, WALL_TOP, -2.75), 1.0, 5.0, true)
	var workshop := _lamp(Vector3(4.0, WALL_TOP, 1.75), 1.3, 6.5, true)
	var porch := Lamp.new()
	porch.style = "lantern"
	porch.energy = 1.5
	porch.light_range = 9.0
	porch.position = Vector3(-4.0, FLOOR_Y + 2.0, HALF_Z + 0.2)
	add_child(porch)

	var inside_front := HALF_Z - CLAD - 0.03
	var hall_back := -1.0 - INT_T * 0.5 - 0.012
	_switch("living", "Licht Wohnzimmer", Vector3(-3.8, FLOOR_Y + 1.25, inside_front), 180.0, [living, dining, lantern_a, lantern_b])
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


func _lantern(pos: Vector3, rot_y: float) -> Lamp:
	var lamp := Lamp.new()
	lamp.style = "lantern"
	lamp.energy = 0.7
	lamp.light_range = 4.5
	lamp.casts_shadow = false
	lamp.position = pos
	lamp.rotation_degrees.y = rot_y
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


# --- Wohnzimmer ---------------------------------------------------------

func _build_living_room() -> void:
	var y := FLOOR_Y
	BuildKit.box_mm(self, Vector3(-4.6, y, 0.6), Vector3(-2.4, y + 0.015, 2.9), BuildKit.tex_mat("rug", 2.2), false, "Rug")
	_sofa(Vector3(-2.5, y, 1.75), 90.0)
	_rocking_chair(Vector3(-4.3, y, 3.45), 140.0)
	# Couchtisch mit Becher und Buch
	BuildKit.box_mm(self, Vector3(-4.2, y + 0.38, 1.3), Vector3(-3.5, y + 0.44, 2.2), m_wood, true, "CoffeeTable")
	for p: Vector2 in [Vector2(-4.12, 1.38), Vector2(-3.58, 1.38), Vector2(-4.12, 2.12), Vector2(-3.58, 2.12)]:
		BuildKit.box_mm(self, Vector3(p.x - 0.03, y, p.y - 0.03), Vector3(p.x + 0.03, y + 0.38, p.y + 0.03), m_wood_dark, false)
	BuildKit.cylinder(self, 0.04, 0.1, Vector3(-3.8, y + 0.49, 1.55), BuildKit.color_mat(Color(0.75, 0.73, 0.68), 0.6), false, Vector3.ZERO, -1.0, 8)
	BuildKit.box(self, Vector3(0.22, 0.04, 0.16), Vector3(-3.85, y + 0.46, 1.95), BuildKit.color_mat(Color(0.35, 0.18, 0.12)), false, Vector3(0, 20, 0))
	# Bücherregal
	_shelf(Vector3(-5.7, y, -0.92), Vector3(-4.4, y + 1.9, -0.55), 4, true)
	# Esstisch – für vier gedeckt, benutzt wird nur ein Platz (GDD 3.1)
	_table(Vector3(-0.9, y, 2.5), Vector3(0.5, y + 0.76, 3.6))
	var plate := BuildKit.color_mat(Color(0.86, 0.82, 0.74), 1.0)
	for p: Vector3 in [Vector3(-0.55, 0, 2.75), Vector3(0.15, 0, 2.75), Vector3(-0.55, 0, 3.35), Vector3(0.15, 0, 3.35)]:
		BuildKit.cylinder(self, 0.13, 0.015, Vector3(p.x, y + 0.775, p.z), plate, false, Vector3.ZERO, -1.0, 12)
		BuildKit.box(self, Vector3(0.015, 0.005, 0.16), Vector3(p.x + 0.17, y + 0.773, p.z), m_iron, false)
	BuildKit.cylinder(self, 0.035, 0.18, Vector3(-0.2, y + 0.85, 3.05), BuildKit.color_mat(Color(0.25, 0.35, 0.25, 1), 0.2), false, Vector3.ZERO, 0.02, 8)
	_chair(Vector3(-0.55, y, 2.15), 0.0)
	_chair(Vector3(0.15, y, 2.15), 0.0)
	_chair(Vector3(-0.55, y, 3.95), 180.0)
	_chair(Vector3(0.15, y, 3.95), 180.0)
	# Kinderzeichnung an der Wand
	var paper := BuildKit.color_mat(Color(0.92, 0.9, 0.84), 0.9)
	var dz := -1.0 + INT_T * 0.5 + 0.006
	BuildKit.box_mm(self, Vector3(-4.2, y + 1.35, dz), Vector3(-3.8, y + 1.65, dz + 0.004), paper, false)
	BuildKit.box_mm(self, Vector3(-4.15, y + 1.38, dz + 0.004), Vector3(-3.85, y + 1.43, dz + 0.006), BuildKit.color_mat(Color(0.2, 0.55, 0.2)), false)
	BuildKit.box_mm(self, Vector3(-4.08, y + 1.43, dz + 0.004), Vector3(-3.96, y + 1.56, dz + 0.006), BuildKit.color_mat(Color(0.8, 0.25, 0.2)), false)
	BuildKit.box_mm(self, Vector3(-3.94, y + 1.55, dz + 0.004), Vector3(-3.88, y + 1.61, dz + 0.007), BuildKit.color_mat(Color(0.95, 0.8, 0.1)), false)
	# Schreibtisch mit altem Röhrenmonitor und Radio – später die Überwachungsstation (GDD 7.5)
	BuildKit.box_mm(self, Vector3(1.2, y + 0.7, 3.0), Vector3(1.925, y + 0.76, 4.25), m_wood, true, "Desk")
	BuildKit.box_mm(self, Vector3(1.25, y, 3.05), Vector3(1.9, y + 0.7, 3.45), m_wood_dark, true)
	BuildKit.box_mm(self, Vector3(1.85, y, 4.15), Vector3(1.9, y + 0.7, 4.2), m_wood_dark, false)
	var plastic := BuildKit.color_mat(Color(0.62, 0.6, 0.55), 0.6)
	BuildKit.box_mm(self, Vector3(1.4, y + 0.76, 3.3), Vector3(1.9, y + 1.18, 3.95), plastic, false, "Monitor")
	BuildKit.box_mm(self, Vector3(1.75, y + 0.8, 3.38), Vector3(1.92, y + 1.12, 3.87), plastic, false)
	BuildKit.box_mm(self, Vector3(1.39, y + 0.82, 3.37), Vector3(1.4, y + 1.12, 3.88), BuildKit.color_mat(Color(0.05, 0.07, 0.06), 0.1), false)
	BuildKit.box_mm(self, Vector3(1.35, y + 0.76, 3.98), Vector3(1.7, y + 0.78, 4.2), BuildKit.color_mat(Color(0.2, 0.2, 0.2)), false)
	var radio := BuildKit.color_mat(Color(0.25, 0.17, 0.12), 0.5)
	BuildKit.box_mm(self, Vector3(1.5, y + 0.76, 3.02), Vector3(1.85, y + 0.95, 3.25), radio, false, "RadioBody")
	var radio_node := Radio.new()
	radio_node.name = "Radio"
	radio_node.anchor = Vector3(1.675, y + 0.76, 3.135)
	add_child(radio_node)
	BuildKit.box_mm(self, Vector3(1.49, y + 0.8, 3.06), Vector3(1.5, y + 0.92, 3.16), BuildKit.color_mat(Color(0.6, 0.55, 0.4)), false)
	BuildKit.cylinder(self, 0.005, 0.35, Vector3(1.8, y + 1.1, 3.2), m_iron, false, Vector3(15, 0, -20), -1.0, 4)
	_chair(Vector3(0.85, y, 3.6), 90.0)
	var station := MonitorStation.new()
	station.name = "MonitorStation"
	station.screen_center = Vector3(1.385, y + 0.97, 3.625)
	station.screen_size = Vector2(0.48, 0.32)
	add_child(station)
	# Wanduhr
	var clock := Node3D.new()
	clock.position = Vector3(-1.4, y + 2.1, HALF_Z - CLAD - 0.03)
	add_child(clock)
	BuildKit.cylinder(clock, 0.17, 0.04, Vector3.ZERO, m_wood_dark, false, Vector3(90, 0, 0), -1.0, 14)
	BuildKit.cylinder(clock, 0.14, 0.01, Vector3(0, 0, -0.022), BuildKit.color_mat(Color(0.88, 0.86, 0.8)), false, Vector3(90, 0, 0), -1.0, 14)
	BuildKit.box(clock, Vector3(0.012, 0.1, 0.005), Vector3(0.02, 0.04, -0.03), BuildKit.color_mat(Color(0.05, 0.05, 0.05)), false, Vector3(0, 0, -30))
	BuildKit.box(clock, Vector3(0.012, 0.07, 0.005), Vector3(-0.025, -0.01, -0.03), BuildKit.color_mat(Color(0.05, 0.05, 0.05)), false, Vector3(0, 0, 110))
	# Pflanzen in Tontöpfen
	_plant(Vector3(-5.45, y, 0.3), 1.0)
	_plant(Vector3(0.95, y, 4.1), 0.8)
	_plant(Vector3(-5.5, y, 4.0), 1.2)


func _build_kitchen() -> void:
	var y := FLOOR_Y
	var z0 := -1.0 + INT_T * 0.5
	var counter := BuildKit.tex_mat("planks_v", 0.7, Color(0.45, 0.42, 0.4))
	BuildKit.box_mm(self, Vector3(-1.95, y, z0), Vector3(-0.1, y + 0.86, z0 + 0.6), counter, true, "Counter")
	BuildKit.box_mm(self, Vector3(-1.98, y + 0.86, z0), Vector3(-0.07, y + 0.92, z0 + 0.63), m_wood, false)
	for x: float in [-1.5, -1.0, -0.55]:
		BuildKit.box(self, Vector3(0.012, 0.6, 0.01), Vector3(x, y + 0.45, z0 + 0.605), BuildKit.color_mat(Color(0.12, 0.1, 0.08)), false)
	# Spüle aus Stein
	BuildKit.box_mm(self, Vector3(-1.75, y + 0.78, z0 + 0.08), Vector3(-1.15, y + 0.93, z0 + 0.52), BuildKit.tex_mat("stone", 0.5, Color(1.2, 1.2, 1.2)), false)
	BuildKit.box_mm(self, Vector3(-1.7, y + 0.86, z0 + 0.12), Vector3(-1.2, y + 0.935, z0 + 0.48), BuildKit.color_mat(Color(0.12, 0.12, 0.12)), false)
	BuildKit.cylinder(self, 0.015, 0.25, Vector3(-1.45, y + 1.05, z0 + 0.06), m_iron, false, Vector3.ZERO, -1.0, 6)
	var tap := WaterSource.new()
	tap.name = "KitchenTap"
	tap.label = "Wasserhahn"
	tap.contaminable = true
	tap.sound = "faucet"
	# der Hahn tropft leise vor sich hin
	if SoundBank.has_recording("drip"):
		var drip := AudioStreamPlayer3D.new()
		drip.name = "TapDrip"
		drip.stream = SoundBank.get_sound("drip")
		drip.position = Vector3(-1.45, y + 0.95, z0 + 0.2)
		drip.volume_db = -22.0
		drip.unit_size = 1.2
		drip.max_distance = 8.0
		drip.autoplay = true
		add_child(drip)
	tap.anchor = Vector3(-1.45, y + 0.8, z0 + 0.3)
	tap.collider_size = Vector3(0.6, 0.4, 0.45)
	add_child(tap)
	BuildKit.box(self, Vector3(0.02, 0.02, 0.15), Vector3(-1.45, y + 1.17, z0 + 0.12), m_iron, false)
	# Holzofen mit Rohr
	var iron_dark := BuildKit.tex_mat("metal", 0.4, Color(0.4, 0.38, 0.36), 0.5)
	BuildKit.box_mm(self, Vector3(1.0, y, z0 + 0.05), Vector3(1.75, y + 0.8, z0 + 0.6), iron_dark, true, "Stove")
	BuildKit.box_mm(self, Vector3(0.98, y + 0.8, z0 + 0.03), Vector3(1.77, y + 0.84, z0 + 0.62), iron_dark, false)
	BuildKit.box_mm(self, Vector3(1.1, y + 0.2, z0 + 0.6), Vector3(1.45, y + 0.5, z0 + 0.62), BuildKit.color_mat(Color(0.1, 0.09, 0.09), 0.4), false)
	for i in 2:
		BuildKit.cylinder(self, 0.11, 0.01, Vector3(1.2 + i * 0.35, y + 0.845, z0 + 0.32), BuildKit.color_mat(Color(0.08, 0.08, 0.08)), false, Vector3.ZERO, -1.0, 10)
	BuildKit.cylinder(self, 0.07, WALL_TOP - y - 0.84, Vector3(1.6, (y + 0.84 + WALL_TOP) * 0.5, z0 + 0.2), iron_dark, false, Vector3.ZERO, -1.0, 8)
	BuildKit.cylinder(self, 0.14, 0.12, Vector3(1.3, y + 0.9, z0 + 0.3), iron_dark, false, Vector3.ZERO, 0.12, 10)
	# Hängende Stange mit Pfannen, Kräutern und Würsten (wie in einer Jagdhütte)
	var rack_y := WALL_TOP - 0.62
	BuildKit.cylinder(self, 0.02, 1.9, Vector3(-1.02, rack_y, z0 + 0.35), m_iron, false, Vector3(0, 0, 90), -1.0, 6)
	for x: float in [-1.85, -0.2]:
		BuildKit.box(self, Vector3(0.008, 0.62, 0.008), Vector3(x, rack_y + 0.31, z0 + 0.35), m_iron, false)
	var dark_meat := BuildKit.color_mat(Color(0.25, 0.1, 0.08), 0.7)
	var herb := BuildKit.color_mat(Color(0.3, 0.38, 0.18), 1.0)
	var pan := BuildKit.tex_mat("metal", 0.3, Color(0.5, 0.48, 0.46), 0.4)
	for i in 7:
		var x := -1.8 + i * 0.26
		BuildKit.box(self, Vector3(0.006, 0.12, 0.006), Vector3(x, rack_y - 0.06, z0 + 0.35), m_iron, false)
		match i % 3:
			0:
				BuildKit.cylinder(self, 0.035, 0.35, Vector3(x, rack_y - 0.3, z0 + 0.35), dark_meat, false, Vector3(0, 0, 4), 0.03, 6)
			1:
				BuildKit.cylinder(self, 0.06, 0.25, Vector3(x, rack_y - 0.25, z0 + 0.35), herb, false, Vector3(180, 0, 0), 0.015, 6)
			2:
				BuildKit.cylinder(self, 0.13, 0.025, Vector3(x, rack_y - 0.28, z0 + 0.36), pan, false, Vector3(90, 0, 0), -1.0, 10)
				BuildKit.box(self, Vector3(0.025, 0.18, 0.01), Vector3(x, rack_y - 0.09, z0 + 0.36), pan, false)


func _sofa(pos: Vector3, rot_y: float) -> void:
	var n := Node3D.new()
	n.position = pos
	n.rotation_degrees.y = rot_y
	add_child(n)
	var fabric := BuildKit.tex_mat("fabric", 0.5)
	var leg := m_wood_dark
	# Lokale Achsen: Sitzfläche entlang x, Front zeigt nach -z
	BuildKit.box_mm(n, Vector3(-0.85, 0.1, -0.45), Vector3(0.85, 0.32, 0.45), fabric, true)
	for i in 3:
		BuildKit.box_mm(n, Vector3(-0.8 + i * 0.54, 0.32, -0.42), Vector3(-0.28 + i * 0.54, 0.46, 0.2), fabric, false)
	BuildKit.box_mm(n, Vector3(-0.85, 0.32, 0.18), Vector3(0.85, 0.9, 0.45), fabric, false)
	for x: float in [-0.92, 0.92]:
		BuildKit.box_mm(n, Vector3(x - 0.1, 0.1, -0.45), Vector3(x + 0.1, 0.55, 0.45), fabric, false)
		BuildKit.cylinder(n, 0.12, 0.9, Vector3(x, 0.58, 0.0), fabric, false, Vector3(90, 0, 0), -1.0, 8)
	for p: Vector2 in [Vector2(-0.95, -0.4), Vector2(0.95, -0.4), Vector2(-0.95, 0.4), Vector2(0.95, 0.4)]:
		BuildKit.box_mm(n, Vector3(p.x - 0.03, 0, p.y - 0.03), Vector3(p.x + 0.03, 0.1, p.y + 0.03), leg, false)
	# Kissen
	BuildKit.box(n, Vector3(0.38, 0.36, 0.12), Vector3(-0.55, 0.62, 0.08), BuildKit.tex_mat("blanket", 0.3), false, Vector3(-15, 10, 0))
	BuildKit.box(n, Vector3(0.36, 0.34, 0.12), Vector3(0.6, 0.6, 0.08), BuildKit.tex_mat("fabric_red", 0.3), false, Vector3(-15, -12, 5))
	# Wolldecke über der Lehne
	BuildKit.box(n, Vector3(0.6, 0.02, 0.5), Vector3(0.1, 0.86, 0.2), BuildKit.tex_mat("blanket", 0.5), false, Vector3(-70, 0, 0))


func _rocking_chair(pos: Vector3, rot_y: float) -> void:
	var n := Node3D.new()
	n.position = pos
	n.rotation_degrees.y = rot_y
	add_child(n)
	var w := m_wood_dark
	# Kufen aus drei Segmenten
	for x: float in [-0.25, 0.25]:
		for s in 3:
			var z := -0.3 + s * 0.3
			BuildKit.box(n, Vector3(0.04, 0.04, 0.32), Vector3(x, 0.04 + absf(s - 1) * 0.03, z), w, false, Vector3((s - 1) * -12.0, 0, 0))
		BuildKit.box(n, Vector3(0.04, 0.38, 0.04), Vector3(x, 0.25, -0.2), w, false)
		BuildKit.box(n, Vector3(0.04, 0.38, 0.04), Vector3(x, 0.25, 0.2), w, false)
		BuildKit.box(n, Vector3(0.05, 0.04, 0.5), Vector3(x, 0.66, -0.02), w, false)
		BuildKit.box(n, Vector3(0.04, 0.26, 0.04), Vector3(x, 0.55, 0.22), w, false)
	BuildKit.box_mm(n, Vector3(-0.27, 0.42, -0.24), Vector3(0.27, 0.46, 0.24), m_wood, true)
	# Lehne hinten (gegenüber den vorderen Armlehnstützen), leicht nach hinten geneigt
	var back := Node3D.new()
	back.position = Vector3(0, 0.46, -0.24)
	back.rotation_degrees.x = 12
	n.add_child(back)
	for i in 5:
		BuildKit.box(back, Vector3(0.06, 0.7, 0.025), Vector3(-0.2 + i * 0.1, 0.35, 0), m_wood, false)
	BuildKit.box(back, Vector3(0.56, 0.08, 0.04), Vector3(0, 0.72, 0), w, false)


func _plant(pos: Vector3, s: float) -> void:
	var pot := BuildKit.color_mat(Color(0.55, 0.3, 0.18), 0.9)
	BuildKit.cylinder(self, 0.16 * s, 0.32 * s, pos + Vector3(0, 0.16 * s, 0), pot, true, Vector3.ZERO, 0.21 * s, 10)
	BuildKit.cylinder(self, 0.2 * s, 0.03, pos + Vector3(0, 0.32 * s, 0), BuildKit.color_mat(Color(0.18, 0.12, 0.08)), false, Vector3.ZERO, -1.0, 10)
	var leaf := BuildKit.cutout_mat("fern")
	for i in 3:
		var q := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(0.7, 0.7) * s
		qm.material = leaf
		q.mesh = qm
		q.position = pos + Vector3(0, 0.32 * s + 0.33 * s, 0)
		q.rotation_degrees.y = i * 60.0
		add_child(q)


# --- Schlafzimmer -------------------------------------------------------

func _build_bedroom() -> void:
	var y := FLOOR_Y
	var bed := Bed.new()
	bed.name = "Bed"
	bed.position = Vector3(-5.82, y, -4.32)
	add_child(bed)
	BuildKit.box_mm(self, Vector3(-4.2, y, -2.3), Vector3(-2.6, y + 0.012, -1.3), BuildKit.tex_mat("rug", 1.6), false)
	# Nachttisch mit Kerze und Familienbild
	BuildKit.box_mm(self, Vector3(-4.2, y + 0.5, -4.33), Vector3(-3.72, y + 0.55, -3.88), m_wood, true)
	BuildKit.box_mm(self, Vector3(-4.18, y, -4.31), Vector3(-3.74, y + 0.5, -3.9), m_wood_dark, false)
	BuildKit.box(self, Vector3(0.012, 0.012, 0.06), Vector3(-3.95, y + 0.4, -3.89), m_iron, false)
	_photo(Vector3(-4.05, y + 0.55, -4.22), 0.0, 0.18, 0.14)
	BuildKit.cylinder(self, 0.03, 0.1, Vector3(-3.85, y + 0.6, -4.05), BuildKit.color_mat(Color(0.9, 0.86, 0.75)), false, Vector3.ZERO, -1.0, 6)
	# Kleiderschrank mit zwei Türen
	BuildKit.box_mm(self, Vector3(-2.05, y, -4.33), Vector3(-1.13, y + 2.05, -3.65), m_wall, true, "Wardrobe")
	BuildKit.box_mm(self, Vector3(-2.06, y + 2.05, -4.35), Vector3(-1.12, y + 2.12, -3.62), m_wood_dark, false)
	for x: float in [-1.62, -1.56]:
		BuildKit.box(self, Vector3(0.02, 0.12, 0.02), Vector3(x, y + 1.1, -3.64), m_iron, false)
	BuildKit.box_mm(self, Vector3(-1.6, y + 0.05, -3.66), Vector3(-1.58, y + 2.0, -3.645), m_wood_dark, false)
	# Ungeöffnetes Geburtstagsgeschenk (GDD 3.1)
	BuildKit.box_mm(self, Vector3(-1.62, y, -1.65), Vector3(-1.3, y + 0.28, -1.33), BuildKit.color_mat(Color(0.65, 0.12, 0.14), 0.6), true, "Gift")
	var ribbon := BuildKit.color_mat(Color(0.95, 0.78, 0.2), 0.4)
	BuildKit.box_mm(self, Vector3(-1.49, y, -1.66), Vector3(-1.43, y + 0.285, -1.32), ribbon, false)
	BuildKit.box_mm(self, Vector3(-1.63, y, -1.52), Vector3(-1.29, y + 0.285, -1.46), ribbon, false)
	BuildKit.sphere(self, 0.05, Vector3(-1.46, y + 0.3, -1.49), ribbon, Vector3(1.2, 0.6, 1.2), 6)
	# Kleiderhaken mit Jacke
	var hz := -1.0 - INT_T * 0.5
	BuildKit.box_mm(self, Vector3(-5.6, y + 1.6, hz - 0.03), Vector3(-4.6, y + 1.7, hz), m_wood_dark, false)
	BuildKit.box(self, Vector3(0.4, 0.75, 0.08), Vector3(-5.2, y + 1.25, hz - 0.07), BuildKit.tex_mat("fabric", 0.4, Color(0.7, 0.85, 0.75)), false, Vector3(4, 0, 0))


# --- Vorratsraum, Technik, Werkstatt -----------------------------------

func _build_storage() -> void:
	var y := FLOOR_Y
	_shelf(Vector3(-0.85, y, -4.35), Vector3(1.85, y + 2.1, -3.9), 5, false)
	var colors := [Color(0.6, 0.5, 0.3), Color(0.4, 0.45, 0.3), Color(0.7, 0.3, 0.2), Color(0.5, 0.5, 0.55), Color(0.75, 0.7, 0.55)]
	for level in 5:
		var sy := y + 0.05 + level * (2.05 / 5.0)
		var x := -0.75
		while x < 1.7:
			# Platz für die beschrifteten Kisten (Konserven, Wasser) auf der mittleren Ebene
			if level == 2 and ((x > -0.12 and x < 0.48) or (x > 0.95 and x < 1.45)):
				x += 0.05
				continue
			var c: Color = colors[_rng.randi() % colors.size()]
			if _rng.randf() < 0.5:
				BuildKit.cylinder(self, 0.05, 0.13, Vector3(x, sy + 0.065, -4.12), BuildKit.color_mat(c, 0.5, 0.3), false, Vector3.ZERO, -1.0, 8)
				x += 0.13
			else:
				var w := _rng.randf_range(0.15, 0.3)
				BuildKit.box(self, Vector3(w, _rng.randf_range(0.12, 0.3), 0.3), Vector3(x + w * 0.5, sy + 0.1, -4.12), BuildKit.color_mat(c), false)
				x += w + 0.05
	# Vorräte zum Mitnehmen: Konserven, Wasserflaschen, leere Dosen
	# Konserven in einer Kiste mit "FOOD"-Etikett, Wasserflaschen in einer Kiste mit Tropfen-Symbol
	var food := _crate_pickup("FoodShelf", "food", 6, 1, Vector3(0.2, y + 0.9, -4.12), Vector3(0.44, 0.08, 0.27), "food", Vector3(0, 0, 1))
	for i in 6:
		var c := Node3D.new()
		food.add_child(c)
		Icons.food_can(c, Vector3(0.2 - 0.14 + (i % 3) * 0.14, y + 0.915, -4.12 - 0.06 + (i / 3) * 0.12))
		food.visuals.append(c)
	var water := _crate_pickup("WaterBottles", "water", 4, 1, Vector3(1.2, y + 0.9, -4.12), Vector3(0.36, 0.08, 0.26), "water", Vector3(0, 0, 1))
	var bottle_mat := BuildKit.color_mat(Color(0.45, 0.65, 0.8), 0.1)
	var cap_mat := BuildKit.color_mat(Color(0.15, 0.3, 0.7), 0.5)
	for i in 4:
		var b := Node3D.new()
		water.add_child(b)
		var bp := Vector3(1.2 - 0.08 + (i % 2) * 0.16, y + 0.915, -4.12 - 0.055 + (i / 2) * 0.11)
		var bm := BuildKit.lathe(b, PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.95, 0.0), Vector2(1.0, 0.05), Vector2(1.0, 0.62),
				Vector2(0.45, 0.82), Vector2(0.35, 0.9), Vector2(0.0, 0.9)]), bp, bottle_mat, 10)
		bm.scale = Vector3(0.045, 0.26, 0.045)
		BuildKit.cylinder(b, 0.018, 0.03, bp + Vector3(0, 0.245, 0), cap_mat, false, Vector3.ZERO, -1.0, 8)
		BuildKit.cylinder(b, 0.0455, 0.07, bp + Vector3(0, 0.1, 0), BuildKit.color_mat(Color(0.85, 0.9, 0.95), 0.6), false, Vector3.ZERO, -1.0, 10)
		water.visuals.append(b)
	_pickup("EmptyCans", "cans", 8, 4, Vector3(1.45, y + 0.8, -1.6), Vector3(0.4, 0.2, 0.4), BuildKit.tex_mat("metal", 0.2, Color(1.5, 1.5, 1.5), 0.4))
	var sack := BuildKit.tex_mat("fabric", 0.4, Color(1.4, 1.25, 0.95))
	BuildKit.sphere(self, 0.28, Vector3(-0.55, y + 0.22, -2.3), sack, Vector3(1.0, 0.8, 0.8), 10)
	BuildKit.sphere(self, 0.28, Vector3(-0.55, y + 0.22, -2.85), sack, Vector3(0.9, 0.8, 0.9), 10)
	var crate := BuildKit.tex_mat("planks_h", 0.5, Color(1.1, 1.05, 0.95))
	BuildKit.box_mm(self, Vector3(1.1, y, -1.9), Vector3(1.8, y + 0.45, -1.3), crate, true)
	BuildKit.box_mm(self, Vector3(1.2, y + 0.45, -1.85), Vector3(1.75, y + 0.8, -1.35), crate, true)


func _build_technical_room() -> void:
	var y := FLOOR_Y
	# Generator (GDD 7.4) – die Teile hängen am Generator-Knoten, damit man ihn anvisieren kann
	var gen := Generator.new()
	gen.name = "Generator"
	gen.anchor = Vector3(4.7, y, -3.825)
	add_child(gen)
	_generator_model(gen, y)
	# Sicherungskasten mit Kabeln
	var ex := HALF_X - CLAD
	BuildKit.box_mm(self, Vector3(ex - 0.12, y + 1.2, -3.2), Vector3(ex, y + 1.8, -2.6), BuildKit.tex_mat("metal", 0.3, Color(1.6, 1.6, 1.5)), false, "FuseBox")
	for i in 3:
		BuildKit.box_mm(self, Vector3(ex - 0.04, y + 0.2 + i * 0.02, -3.0 + i * 0.12), Vector3(ex - 0.02, y + 1.2, -2.98 + i * 0.12), BuildKit.color_mat(Color(0.1, 0.1, 0.1)), false)
	# Benzinkanister zum Mitnehmen
	for i in 2:
		fuel_can(self, Vector3(2.575 + i * 0.4, y, -4.2), 0.0, "FuelCan_%d" % i)


## Tragbarer Stromerzeuger im Rohrrahmen: Motor mit Kühlrippen und Seilzugstarter, Lichtmaschine,
## Auspufftopf mit Hitzeschutz, roter Tank mit Deckel und Anzeige, Bedienfeld mit Steckdosen.
func _generator_model(gen: Node3D, y: float) -> void:
	var red := BuildKit.tex_mat("metal", 0.4, Color(1.9, 0.5, 0.35), 0.45)
	var red_dark := BuildKit.tex_mat("metal", 0.4, Color(1.3, 0.32, 0.22), 0.5)
	var tube := BuildKit.tex_mat("metal", 0.3, Color(0.35, 0.35, 0.37), 0.35)
	var engine := BuildKit.tex_mat("metal", 0.3, Color(0.55, 0.55, 0.56), 0.5)
	var engine_dark := BuildKit.color_mat(Color(0.12, 0.12, 0.13), 0.6, 0.4)
	var black := BuildKit.color_mat(Color(0.05, 0.05, 0.05), 0.7)
	var chrome := BuildKit.color_mat(Color(0.75, 0.75, 0.78), 0.25, 0.9)
	var x0 := 4.02
	var x1 := 5.38
	var z0 := -4.18
	var z1 := -3.48
	# Rohrrahmen: vier Pfosten, obere und untere Holme, Gummifüße
	for x: float in [x0, x1]:
		for z: float in [z0, z1]:
			BuildKit.cylinder(gen, 0.022, 0.7, Vector3(x, y + 0.45, z), tube, false, Vector3.ZERO, -1.0, 8)
			BuildKit.cylinder(gen, 0.04, 0.05, Vector3(x, y + 0.025, z), black, false, Vector3.ZERO, -1.0, 8)
		for h: float in [0.1, 0.8]:
			BuildKit.cylinder(gen, 0.022, z1 - z0, Vector3(x, y + h, (z0 + z1) * 0.5), tube, false, Vector3(90, 0, 0), -1.0, 8)
	for z: float in [z0, z1]:
		for h: float in [0.1, 0.8]:
			BuildKit.cylinder(gen, 0.022, x1 - x0, Vector3((x0 + x1) * 0.5, y + h, z), tube, false, Vector3(0, 0, 90), -1.0, 8)
	BuildKit.box_mm(gen, Vector3(x0 + 0.03, y + 0.1, z0 + 0.03), Vector3(x1 - 0.03, y + 0.13, z1 - 0.03), engine_dark, false)
	# Motorblock mit schräg stehendem Zylinderkopf und Kühlrippen
	BuildKit.box_mm(gen, Vector3(4.12, y + 0.13, -4.05), Vector3(4.72, y + 0.42, -3.62), engine, false)
	var head := Node3D.new()
	head.position = Vector3(4.3, y + 0.5, -3.84)
	head.rotation_degrees.z = 25
	gen.add_child(head)
	BuildKit.box(head, Vector3(0.2, 0.18, 0.26), Vector3.ZERO, engine, false)
	for k in 6:
		BuildKit.box(head, Vector3(0.26, 0.012, 0.32), Vector3(0, -0.07 + k * 0.03, 0), engine, false)
	BuildKit.cylinder(head, 0.025, 0.06, Vector3(0, 0.12, 0), black, false, Vector3.ZERO, -1.0, 8)  # Zündkerzenstecker
	# Seilzugstarter vorn, mit T-Griff
	BuildKit.cylinder(gen, 0.13, 0.06, Vector3(4.42, y + 0.3, -3.59), red_dark, false, Vector3(90, 0, 0), -1.0, 18)
	BuildKit.cylinder(gen, 0.05, 0.02, Vector3(4.42, y + 0.3, -3.555), black, false, Vector3(90, 0, 0), -1.0, 12)
	BuildKit.box(gen, Vector3(0.11, 0.025, 0.025), Vector3(4.42, y + 0.3, -3.53), black, false)
	# Luftfilterkasten seitlich
	BuildKit.box_mm(gen, Vector3(4.06, y + 0.25, -3.95), Vector3(4.13, y + 0.45, -3.7), black, false)
	# Lichtmaschine: liegender Zylinder mit Lüftungsschlitzen
	BuildKit.cylinder(gen, 0.17, 0.46, Vector3(4.97, y + 0.32, -3.85), engine, false, Vector3(0, 0, 90), -1.0, 20)
	for k in 5:
		BuildKit.cylinder(gen, 0.172, 0.012, Vector3(4.8 + k * 0.08, y + 0.32, -3.85), engine_dark, false, Vector3(0, 0, 90), -1.0, 20)
	BuildKit.cylinder(gen, 0.17, 0.03, Vector3(5.21, y + 0.32, -3.85), red_dark, false, Vector3(0, 0, 90), -1.0, 20)
	# Auspufftopf hinten mit gelochtem Hitzeschutz
	BuildKit.cylinder(gen, 0.075, 0.42, Vector3(4.45, y + 0.5, -4.1), engine_dark, false, Vector3(0, 0, 90), -1.0, 14)
	BuildKit.box_mm(gen, Vector3(4.24, y + 0.52, -4.17), Vector3(4.66, y + 0.6, -4.05), chrome, false)
	for k in 6:
		BuildKit.box_mm(gen, Vector3(4.27 + k * 0.065, y + 0.6, -4.15), Vector3(4.3 + k * 0.065, y + 0.602, -4.07), black, false)
	BuildKit.cylinder(gen, 0.02, 0.08, Vector3(4.22, y + 0.5, -4.1), black, false, Vector3(0, 0, 90), -1.0, 8)
	# Tank: rot, mit abgerundeten Kanten, Tankdeckel und Füllstandsanzeige
	BuildKit.box_mm(gen, Vector3(4.12, y + 0.62, -4.08), Vector3(5.28, y + 0.79, -3.55), red, false, "Tank")
	BuildKit.box_mm(gen, Vector3(4.16, y + 0.79, -4.04), Vector3(5.24, y + 0.815, -3.59), red, false)
	for z: float in [-4.08, -3.55]:
		BuildKit.cylinder(gen, 0.03, 1.12, Vector3(4.7, y + 0.79, z + (0.03 if z < -4.0 else -0.03)), red, false, Vector3(0, 0, 90), -1.0, 10)
	BuildKit.box_mm(gen, Vector3(4.12, y + 0.59, -4.08), Vector3(5.28, y + 0.62, -3.55), red_dark, false)
	BuildKit.cylinder(gen, 0.065, 0.035, Vector3(4.55, y + 0.83, -3.82), black, false, Vector3.ZERO, -1.0, 16)
	BuildKit.cylinder(gen, 0.07, 0.01, Vector3(4.55, y + 0.815, -3.82), chrome, false, Vector3.ZERO, -1.0, 16)
	for k in 4:
		BuildKit.box(gen, Vector3(0.012, 0.02, 0.1), Vector3(4.55, y + 0.86, -3.82), black, false, Vector3(0, k * 45.0, 0))
	BuildKit.cylinder(gen, 0.045, 0.012, Vector3(4.95, y + 0.82, -3.75), BuildKit.color_mat(Color(0.85, 0.85, 0.8), 0.3), false, Vector3.ZERO, -1.0, 14)
	BuildKit.box(gen, Vector3(0.006, 0.004, 0.035), Vector3(4.95, y + 0.828, -3.76), black, false, Vector3(0, 30, 0))
	# Bedienfeld vorn rechts: Steckdosen, Sicherungsschalter, Betriebsstundenzähler
	BuildKit.box_mm(gen, Vector3(4.82, y + 0.17, -3.53), Vector3(5.34, y + 0.56, -3.49), engine_dark, false)
	for k in 2:
		var sx := 4.92 + k * 0.17
		BuildKit.cylinder(gen, 0.055, 0.02, Vector3(sx, y + 0.27, -3.48), black, false, Vector3(90, 0, 0), -1.0, 16)
		for hx: float in [-0.018, 0.018]:
			BuildKit.box(gen, Vector3(0.008, 0.008, 0.01), Vector3(sx + hx, y + 0.27, -3.47), chrome, false)
	BuildKit.box(gen, Vector3(0.05, 0.03, 0.02), Vector3(4.92, y + 0.44, -3.475), BuildKit.color_mat(Color(0.7, 0.1, 0.08), 0.5), false)
	BuildKit.box(gen, Vector3(0.08, 0.04, 0.012), Vector3(5.24, y + 0.47, -3.48), BuildKit.color_mat(Color(0.85, 0.85, 0.8), 0.3), false)
	Icons.decal(gen, "fuel", 0.14, Vector3(4.8, y + 0.7, -3.545), Vector3(0, 0, 1))
	Icons.decal(gen, "power", 0.1, Vector3(5.1, y + 0.44, -3.485), Vector3(0, 0, 1))


## Werkzeugwand: Lochplatte mit Rahmen, daran Hammer, Säge, Schraubenschlüssel, Schraubenzieher, Zange, Seil.
func _tool_wall(fz: float, y: float) -> void:
	var board := BuildKit.tex_mat("planks_v", 0.6, Color(1.25, 1.12, 0.95))
	var frame := m_wood_dark
	var steel := BuildKit.color_mat(Color(0.62, 0.63, 0.66), 0.35, 0.85)
	var rust := BuildKit.tex_mat("metal", 0.3, Color(1.1, 0.85, 0.7), 0.6)
	var handle := BuildKit.tex_mat("logs", 0.3, Color(1.3, 1.1, 0.85))
	var red := BuildKit.color_mat(Color(0.65, 0.12, 0.08), 0.5)
	var yellow := BuildKit.color_mat(Color(0.8, 0.62, 0.1), 0.5)
	var hole := BuildKit.color_mat(Color(0.12, 0.09, 0.07), 0.9)
	var x0 := 2.15
	var x1 := 3.4
	var z := fz - 0.03
	BuildKit.box_mm(self, Vector3(x0, y + 0.95, z), Vector3(x1, y + 2.05, fz), board, false, "Pegboard")
	for k in 2:
		BuildKit.box_mm(self, Vector3(x0 - 0.03, y + 0.93 + k * 1.12, z - 0.01), Vector3(x1 + 0.03, y + 0.97 + k * 1.12, fz), frame, false)
		BuildKit.box_mm(self, Vector3(x0 - 0.03 + k * (x1 - x0 + 0.02), y + 0.93, z - 0.01), Vector3(x0 + 0.01 + k * (x1 - x0 + 0.02), y + 2.09, fz), frame, false)
	# Lochraster
	for ix in 11:
		for iy in 9:
			BuildKit.box(self, Vector3(0.012, 0.012, 0.004), Vector3(x0 + 0.08 + ix * 0.11, y + 1.03 + iy * 0.115, z - 0.001), hole, false)
	var f := z - 0.025  # Ebene der Werkzeuge
	# Hammer (Kopf oben, Stiel nach unten)
	BuildKit.box(self, Vector3(0.035, 0.32, 0.03), Vector3(2.3, y + 1.6, f), handle, false)
	BuildKit.box(self, Vector3(0.13, 0.04, 0.04), Vector3(2.3, y + 1.78, f), steel, false)
	BuildKit.box(self, Vector3(0.04, 0.035, 0.03), Vector3(2.37, y + 1.8, f), steel, false, Vector3(0, 0, 30))
	# Fuchsschwanz-Säge: Blatt schmal zulaufend, Griff
	var saw := Node3D.new()
	saw.position = Vector3(2.62, y + 1.48, f)
	saw.rotation_degrees.z = -8
	add_child(saw)
	BuildKit.box(saw, Vector3(0.1, 0.42, 0.004), Vector3(0, -0.02, 0), steel, false)
	BuildKit.box(saw, Vector3(0.06, 0.1, 0.004), Vector3(0.02, -0.26, 0), steel, false)
	for t in 14:
		BuildKit.box(saw, Vector3(0.01, 0.012, 0.004), Vector3(-0.055, -0.21 + t * 0.03, 0), steel, false, Vector3(0, 0, 45))
	BuildKit.box(saw, Vector3(0.11, 0.13, 0.03), Vector3(0, 0.24, 0), handle, false)
	BuildKit.box(saw, Vector3(0.05, 0.06, 0.035), Vector3(0, 0.25, 0), hole, false)
	# Schraubenschlüssel in drei Größen
	for k in 3:
		var wx := 2.86 + k * 0.07
		var ln := 0.16 + k * 0.04
		BuildKit.box(self, Vector3(0.022, ln, 0.01), Vector3(wx, y + 1.72 - ln * 0.5, f), steel, false)
		BuildKit.box(self, Vector3(0.045, 0.035, 0.01), Vector3(wx, y + 1.73, f), steel, false)
		BuildKit.box(self, Vector3(0.015, 0.02, 0.012), Vector3(wx, y + 1.745, f), board, false)
		BuildKit.cylinder(self, 0.02, 0.01, Vector3(wx, y + 1.72 - ln, f), steel, false, Vector3(90, 0, 0), -1.0, 10)
	# Schraubenzieher mit bunten Griffen
	for k in 4:
		var sx := 3.12 + k * 0.06
		BuildKit.cylinder(self, 0.016, 0.1, Vector3(sx, y + 1.74, f), red if k % 2 == 0 else yellow, false, Vector3.ZERO, 0.013, 8)
		BuildKit.cylinder(self, 0.004, 0.13 + k * 0.02, Vector3(sx, y + 1.625 - k * 0.01, f), steel, false, Vector3.ZERO, -1.0, 6)
	# Zange
	for side: float in [-1.0, 1.0]:
		BuildKit.box(self, Vector3(0.018, 0.17, 0.012), Vector3(2.92 + side * 0.025, y + 1.24, f), red, false, Vector3(0, 0, side * 6.0))
		BuildKit.box(self, Vector3(0.015, 0.07, 0.012), Vector3(2.92 + side * 0.006, y + 1.36, f), steel, false, Vector3(0, 0, -side * 4.0))
	# Seilrolle an einem Haken
	var rope := BuildKit.tex_mat("fabric", 0.2, Color(1.6, 1.35, 0.9))
	BuildKit.lathe(self, PackedVector2Array([Vector2(0.09, -0.03), Vector2(0.13, -0.035), Vector2(0.15, 0.0), Vector2(0.13, 0.035), Vector2(0.09, 0.03), Vector2(0.08, 0.0)]),
			Vector3(3.2, y + 1.25, f - 0.02), rope, 16, Vector3(90, 0, 0))
	BuildKit.box(self, Vector3(0.012, 0.06, 0.04), Vector3(3.2, y + 1.37, f + 0.01), steel, false)
	# Werkzeughaken
	for hx: float in [2.3, 2.62, 2.92, 3.2]:
		BuildKit.box(self, Vector3(0.01, 0.01, 0.05), Vector3(hx, y + 1.9 if hx < 2.5 else y + 1.71, z - 0.02), rust, false)


func _build_workshop() -> void:
	var y := FLOOR_Y
	var ex := HALF_X - CLAD
	BuildKit.box_mm(self, Vector3(5.1, y + 0.82, -0.2), Vector3(ex, y + 0.92, 3.6), BuildKit.tex_mat("floor", 0.8, Color(1.15, 1.1, 1.0)), true, "Workbench")
	for z: float in [-0.1, 1.7, 3.5]:
		BuildKit.box_mm(self, Vector3(5.15, y, z - 0.05), Vector3(5.8, y + 0.82, z + 0.05), m_wood_dark, true)
	BuildKit.box_mm(self, Vector3(5.15, y + 0.2, -0.1), Vector3(5.8, y + 0.24, 3.5), m_wood, false)
	BuildKit.box_mm(self, Vector3(5.2, y + 0.92, 0.3), Vector3(5.45, y + 1.04, 0.6), m_iron, false, "Vise")
	# Werkbank zum Herstellen (Crafting)
	var bench := Workbench.new()
	bench.name = "WorkbenchStation"
	bench.anchor = Vector3(5.5, y + 0.92, 1.7)
	add_child(bench)
	# Kiste mit Nägeln
	var nails := _crate_pickup("NailBox", "nails", 24, 12, Vector3(5.6, y + 0.92, 3.1), Vector3(0.25, 0.14, 0.3), "nails", Vector3(-1, 0, 0))
	var heap := Node3D.new()
	nails.add_child(heap)
	var nail_mat := BuildKit.color_mat(Color(0.45, 0.45, 0.47), 0.5, 0.6)
	for k in 18:
		BuildKit.box(heap, Vector3(0.006, 0.006, 0.07), Vector3(5.6 + _rng.randf_range(-0.09, 0.09), y + 1.07 + _rng.randf_range(0.0, 0.015), 3.1 + _rng.randf_range(-0.12, 0.12)),
				nail_mat, false, Vector3(_rng.randf_range(-20, 20), _rng.randf() * 180.0, 0))
	nails.visuals.append(heap)
	# Säge, Hammer, Hobel auf der Werkbank
	BuildKit.box(self, Vector3(0.12, 0.01, 0.6), Vector3(5.5, y + 0.93, 1.2), BuildKit.tex_mat("metal", 0.3, Color(1.4, 1.4, 1.4), 0.3), false, Vector3(0, 10, 0))
	BuildKit.box(self, Vector3(0.1, 0.05, 0.15), Vector3(5.5, y + 0.95, 0.85), m_wood, false)
	BuildKit.box(self, Vector3(0.03, 0.03, 0.3), Vector3(5.35, y + 0.94, 2.2), m_wood, false, Vector3(0, 40, 0))
	BuildKit.box(self, Vector3(0.1, 0.05, 0.04), Vector3(5.42, y + 0.95, 2.32), m_iron, false, Vector3(0, 40, 0))
	BuildKit.box(self, Vector3(0.08, 0.08, 0.25), Vector3(5.6, y + 0.96, 2.8), m_wood_dark, false)
	# Werkzeugwand an der Vorderwand links vom Werkstattfenster (nicht über einer Tür!)
	_tool_wall(HALF_Z - CLAD - 0.015, y)
	# Bretterstapel an der Vorderwand (unter dem Fenster), Sägebock davor
	var lumber := BuildKit.tex_mat("planks_h", 1.5, Color(1.25, 1.2, 1.05))
	var pile := ItemPickup.new()
	pile.name = "PlankPile"
	pile.item_id = "planks"
	pile.amount = 10
	pile.per_take = 2
	pile.label = "Bretter"
	pile.collider_size = Vector3(1.6, 0.4, 0.4)
	pile.collider_offset = Vector3(4.25, y + 0.2, 4.1)
	add_child(pile)
	for i in 5:
		pile.visuals.append(BuildKit.box_mm(pile, Vector3(3.45, y + i * 0.06, 3.95), Vector3(5.05, y + 0.05 + i * 0.06, 4.25), lumber, false))
	BuildKit.box_mm(self, Vector3(3.45, y, 3.95), Vector3(5.05, y + 0.05, 4.25), lumber, true)
	for x: float in [3.3, 4.3]:
		BuildKit.box(self, Vector3(0.06, 0.75, 0.06), Vector3(x, y + 0.36, 2.95), m_wood, false, Vector3(18, 0, 0))
		BuildKit.box(self, Vector3(0.06, 0.75, 0.06), Vector3(x, y + 0.36, 3.25), m_wood, false, Vector3(-18, 0, 0))
	BuildKit.box_mm(self, Vector3(3.1, y + 0.7, 3.03), Vector3(4.5, y + 0.76, 3.17), m_wood, true)
	BuildKit.box(self, Vector3(1.6, 0.05, 0.22), Vector3(3.8, y + 0.79, 3.1), BuildKit.tex_mat("planks_h", 1.0, Color(1.3, 1.25, 1.1)), false, Vector3(0, 4, 0))
	# Hackklotz mit Beil in der Ecke neben der Werkbank
	BuildKit.cylinder(self, 0.22, 0.45, Vector3(5.45, y + 0.225, 3.95), BuildKit.tex_mat("bark", 0.5), true, Vector3.ZERO, -1.0, 12)
	BuildKit.box(self, Vector3(0.035, 0.5, 0.035), Vector3(5.5, y + 0.65, 3.95), m_wood, false, Vector3(0, 0, 20))
	BuildKit.box(self, Vector3(0.16, 0.1, 0.02), Vector3(5.43, y + 0.47, 3.95), m_iron, false, Vector3(0, 0, 20))


func _build_reflection_probe() -> void:
	var probe := ReflectionProbe.new()
	probe.name = "InteriorProbe"
	probe.size = Vector3(HALF_X * 2.0, WALL_H, HALF_Z * 2.0)
	probe.position = Vector3(0, FLOOR_Y + WALL_H * 0.5, 0)
	probe.interior = true
	probe.box_projection = true
	probe.ambient_mode = ReflectionProbe.AMBIENT_COLOR
	probe.ambient_color = Color(0.32, 0.25, 0.18)
	probe.ambient_color_energy = 1.0
	probe.update_mode = ReflectionProbe.UPDATE_ONCE
	probe.add_to_group("interior_probe")
	add_child(probe)


# --- Möbel-Helfer -------------------------------------------------------

## Stapel zum Aufheben: mehrere kleine Kisten/Dosen als Anzeige, wie viel noch da ist.
func _pickup(n: String, item: String, amount: int, per_take: int, at: Vector3, box_size: Vector3, mat: Material) -> ItemPickup:
	var p := ItemPickup.new()
	p.name = n
	p.item_id = item
	p.amount = amount
	p.per_take = per_take
	p.collider_size = box_size + Vector3(0.1, 0.1, 0.1)
	p.collider_offset = at + Vector3(0, box_size.y * 0.5, 0)
	add_child(p)
	var parts := 4
	for i in parts:
		var w := box_size.x / parts
		p.visuals.append(BuildKit.box(p, Vector3(w * 0.85, box_size.y, box_size.z), at + Vector3(-box_size.x * 0.5 + w * (i + 0.5), box_size.y * 0.5, 0), mat, false))
	return p


## Kiste mit Etikett als Vorrat zum Mitnehmen. Die Kiste ist das erste sichtbare Teil
## (verschwindet erst, wenn alles weg ist); der Inhalt wird vom Aufrufer als weitere Teile angehängt.
func _crate_pickup(n: String, item: String, amount: int, per_take: int, at: Vector3, box_size: Vector3,
		label_kind: String, facing: Vector3) -> ItemPickup:
	var p := ItemPickup.new()
	p.name = n
	p.item_id = item
	p.amount = amount
	p.per_take = per_take
	p.collider_size = box_size + Vector3(0.1, 0.22, 0.1)
	p.collider_offset = at + Vector3(0, 0.11, 0)
	add_child(p)
	var crate := Node3D.new()
	p.add_child(crate)
	var card := BuildKit.tex_mat("fabric", 0.3, Color(1.45, 1.2, 0.85))
	var hx := box_size.x * 0.5
	var hz := box_size.z * 0.5
	BuildKit.box_mm(crate, at + Vector3(-hx, 0, -hz), at + Vector3(hx, 0.012, hz), card, false)
	for side: float in [-1.0, 1.0]:
		BuildKit.box_mm(crate, at + Vector3(-hx, 0, side * hz - 0.006), at + Vector3(hx, box_size.y, side * hz + 0.006), card, false)
		BuildKit.box_mm(crate, at + Vector3(side * hx - 0.006, 0, -hz), at + Vector3(side * hx + 0.006, box_size.y, hz), card, false)
	var f := facing.normalized()
	var face := at + Vector3(f.x * (hx + 0.007), box_size.y * 0.5, f.z * (hz + 0.007))
	Icons.decal(crate, label_kind, minf(maxf(box_size.x, box_size.z) * 0.8, 0.22), face + Vector3(0, 0.02, 0), f)
	p.visuals.append(crate)
	return p


## Roter Benzinkanister zum Aufheben (auch vom Schuppen genutzt).
static func fuel_can(parent: Node, pos: Vector3, rot_y: float = 0.0, node_name: String = "FuelCan") -> ItemPickup:
	var p := ItemPickup.new()
	p.name = node_name
	p.item_id = "fuel_can"
	p.amount = 1
	p.collider_size = Vector3(0.4, 0.5, 0.3)
	p.collider_offset = Vector3(0, 0.25, 0)
	p.position = pos
	p.rotation_degrees.y = rot_y
	parent.add_child(p)
	var can := BuildKit.tex_mat("metal", 0.3, Color(1.8, 0.5, 0.35), 0.5)
	var body := BuildKit.box(p, Vector3(0.35, 0.42, 0.2), Vector3(0, 0.21, 0), can, false)
	p.visuals.append(body)
	# geprägtes X auf beiden Seiten, Schweißnaht rundum
	for zs: float in [-1.0, 1.0]:
		for a: float in [52.0, -52.0]:
			BuildKit.box(body, Vector3(0.44, 0.022, 0.01), Vector3(0, 0, zs * 0.102), can, false, Vector3(0, 0, a))
		Icons.decal(body, "fuel", 0.24, Vector3(0, 0.0, zs * 0.108), Vector3(0, 0, zs))
	BuildKit.box(body, Vector3(0.36, 0.43, 0.012), Vector3(0, 0, 0), can, false)
	# Dreifach-Griff oben, Ausguss mit Verschluss an der Ecke
	BuildKit.box(body, Vector3(0.22, 0.03, 0.05), Vector3(-0.03, 0.29, 0), can, false)
	for x: float in [-0.13, -0.03, 0.07]:
		BuildKit.box(body, Vector3(0.025, 0.08, 0.04), Vector3(x, 0.25, 0), can, false)
	BuildKit.cylinder(body, 0.03, 0.06, Vector3(0.13, 0.24, 0), can, false, Vector3(0, 0, -25), -1.0, 8)
	BuildKit.cylinder(body, 0.034, 0.03, Vector3(0.145, 0.28, 0), BuildKit.color_mat(Color(0.1, 0.1, 0.1)), false, Vector3(0, 0, -25), -1.0, 8)
	return p


func _table(from: Vector3, to: Vector3) -> void:
	BuildKit.box_mm(self, Vector3(from.x, to.y - 0.05, from.z), to, m_wood, true)
	for p: Vector2 in [Vector2(from.x + 0.08, from.z + 0.08), Vector2(to.x - 0.08, from.z + 0.08),
			Vector2(from.x + 0.08, to.z - 0.08), Vector2(to.x - 0.08, to.z - 0.08)]:
		BuildKit.cylinder(self, 0.045, to.y - 0.05 - from.y, Vector3(p.x, (from.y + to.y - 0.05) * 0.5, p.y), m_wood_dark, true, Vector3.ZERO, 0.035, 6)


func _chair(pos: Vector3, rot_y: float) -> void:
	var chair := Node3D.new()
	chair.position = pos
	chair.rotation_degrees.y = rot_y
	add_child(chair)
	BuildKit.box_mm(chair, Vector3(-0.21, 0.42, -0.21), Vector3(0.21, 0.46, 0.21), m_wood, true)
	for x: float in [-0.18, 0.18]:
		BuildKit.box_mm(chair, Vector3(x - 0.025, 0.46, -0.21), Vector3(x + 0.025, 0.98, -0.17), m_wood_dark, false)
	for yy: float in [0.68, 0.9]:
		BuildKit.box_mm(chair, Vector3(-0.18, yy - 0.04, -0.205), Vector3(0.18, yy + 0.04, -0.18), m_wood, false)
	for p: Vector2 in [Vector2(-0.18, -0.18), Vector2(0.18, -0.18), Vector2(-0.18, 0.18), Vector2(0.18, 0.18)]:
		BuildKit.box_mm(chair, Vector3(p.x - 0.022, 0, p.y - 0.022), Vector3(p.x + 0.022, 0.42, p.y + 0.022), m_wood_dark, false)


func _shelf(from: Vector3, to: Vector3, levels: int, books: bool) -> void:
	var lo := Vector3(minf(from.x, to.x), from.y, minf(from.z, to.z))
	var hi := Vector3(maxf(from.x, to.x), to.y, maxf(from.z, to.z))
	BuildKit.box_mm(self, Vector3(lo.x, lo.y, lo.z), Vector3(lo.x + 0.04, hi.y, hi.z), m_wood_dark, true)
	BuildKit.box_mm(self, Vector3(hi.x - 0.04, lo.y, lo.z), Vector3(hi.x, hi.y, hi.z), m_wood_dark, true)
	for i in levels:
		var sy := lo.y + 0.05 + i * ((hi.y - lo.y - 0.05) / float(levels))
		BuildKit.box_mm(self, Vector3(lo.x, sy - 0.03, lo.z), Vector3(hi.x, sy, hi.z), m_wood, true)
		if books:
			var x := lo.x + 0.06
			while x < hi.x - 0.12:
				var w := _rng.randf_range(0.03, 0.07)
				var h := _rng.randf_range(0.18, 0.3)
				var c := Color.from_hsv(_rng.randf(), _rng.randf_range(0.3, 0.6), _rng.randf_range(0.2, 0.45))
				var tilt := _rng.randf_range(-8, 8) if _rng.randf() < 0.15 else 0.0
				BuildKit.box(self, Vector3(w, h, (hi.z - lo.z) * 0.8), Vector3(x + w * 0.5, sy + h * 0.5, (lo.z + hi.z) * 0.5), BuildKit.color_mat(c), false, Vector3(0, 0, tilt))
				x += w + 0.006
				if _rng.randf() < 0.08:
					x += 0.15


func _photo(pos: Vector3, rot_y: float, w: float, h: float) -> Node3D:
	var p := Node3D.new()
	p.position = pos
	p.rotation_degrees.y = rot_y
	add_child(p)
	BuildKit.box(p, Vector3(w, h, 0.015), Vector3(0, h * 0.5, 0), BuildKit.color_mat(Color(0.2, 0.15, 0.1), 0.6), false, Vector3(-12, 0, 0))
	BuildKit.box(p, Vector3(w * 0.78, h * 0.72, 0.004), Vector3(0, h * 0.5, 0.009), BuildKit.color_mat(Color(0.55, 0.5, 0.42), 0.4), false, Vector3(-12, 0, 0))
	return p
