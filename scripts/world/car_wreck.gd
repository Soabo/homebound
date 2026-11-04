class_name CarWreck
extends Node3D
## Verrosteter alter Pickup an der Zufahrtsstraße – Fundgrube für Schrott,
## Benzin, Batterie und Elektronik (GDD 3.2 / 6.2).
## Fahrzeug zeigt lokal nach +x, Fahrerseite ist +z. Ein Hinterrad fehlt,
## der Wagen liegt dort auf Steinen.

const SPOT := Vector3(4.6, 0.0, 33.0)
const WHEEL_R := 0.38

var _rng := RandomNumberGenerator.new()
var paint: StandardMaterial3D
var rust: StandardMaterial3D
var chrome: StandardMaterial3D
var dark: StandardMaterial3D
var rubber: StandardMaterial3D
var glass: StandardMaterial3D


func _ready() -> void:
	name = "CarWreck"
	_rng.seed = 1971
	position = Vector3(SPOT.x, Terrain.height_at(SPOT.x, SPOT.z) - 0.12, SPOT.z)
	rotation_degrees = Vector3(-3.0, 22.0, 4.0)
	paint = BuildKit.tex_mat("car_paint", 0.9, Color(1.1, 1.1, 1.1), 0.75)
	rust = BuildKit.tex_mat("metal", 0.5, Color(1.45, 0.75, 0.45), 0.85)
	chrome = BuildKit.tex_mat("metal", 0.3, Color(1.9, 1.85, 1.75), 0.35)
	dark = BuildKit.color_mat(Color(0.04, 0.04, 0.04), 0.6)
	rubber = BuildKit.color_mat(Color(0.07, 0.07, 0.07), 0.95)
	glass = BuildKit.glass_mat()
	_build_frame()
	_build_front()
	_build_cab()
	_build_interior()
	_build_bed()
	_build_wheels()
	_build_overgrowth()
	_build_colliders()

	_node("Scrap", "scrap", 1, 8, 0, "", "Schrott abmontieren", 2.0, "hammer", Vector3(-1.4, 0.95, 0), Vector3(1.8, 0.6, 1.6))
	_node("Battery", "battery", 1, 1, 0, "", "Batterie ausbauen", 2.4, "hammer", Vector3(1.65, 1.15, 0), Vector3(1.2, 0.35, 1.5))
	_node("Fuel", "fuel_can", 1, 1, 0, "", "Benzin abzapfen", 2.5, "step_grass", Vector3(-0.95, 0.95, -0.95), Vector3(0.5, 0.5, 0.35))
	_node("Radio", "electronics", 1, 2, 0, "", "Autoradio ausbauen", 1.8, "hammer", Vector3(0.62, 1.2, 0.3), Vector3(0.4, 0.3, 0.5))
	_node("Glovebox", "food", 1, 2, 0, "", "Handschuhfach durchsuchen", 1.0, "switch", Vector3(0.62, 1.2, -0.45), Vector3(0.35, 0.3, 0.4))


func _build_frame() -> void:
	for z: float in [-0.45, 0.45]:
		BuildKit.box(self, Vector3(4.5, 0.13, 0.1), Vector3(0, 0.45, z), rust, false)
	for x: float in [-1.8, -0.4, 1.0, 2.0]:
		BuildKit.box(self, Vector3(0.1, 0.1, 0.9), Vector3(x, 0.45, 0), rust, false)
	# Achsen, Auspuff hängt abgerissen herunter
	BuildKit.cylinder(self, 0.05, 1.7, Vector3(1.5, WHEEL_R, 0), rust, false, Vector3(90, 0, 0), -1.0, 6)
	BuildKit.cylinder(self, 0.06, 1.7, Vector3(-1.5, WHEEL_R, 0), rust, false, Vector3(90, 0, 0), -1.0, 6)
	BuildKit.box(self, Vector3(0.6, 0.12, 0.12), Vector3(-1.5, WHEEL_R, 0), rust, false)
	BuildKit.cylinder(self, 0.035, 2.4, Vector3(-0.6, 0.33, -0.55), rust, false, Vector3(0, 0, 90), -1.0, 6)
	BuildKit.cylinder(self, 0.035, 0.7, Vector3(-2.05, 0.18, -0.55), rust, false, Vector3(0, 0, 65), -1.0, 6)
	BuildKit.cylinder(self, 0.07, 0.35, Vector3(-0.5, 0.33, -0.55), rust, false, Vector3(0, 0, 90), -1.0, 8)
	# Tank mit Einfüllstutzen an der Beifahrerseite
	BuildKit.box(self, Vector3(0.75, 0.3, 0.42), Vector3(-0.95, 0.5, -0.62), rust, false)
	BuildKit.cylinder(self, 0.045, 0.06, Vector3(-0.95, 0.97, -0.915), chrome, false, Vector3(90, 0, 0), -1.0, 10)
	BuildKit.cylinder(self, 0.05, 0.015, Vector3(-0.95, 0.97, -0.95), dark, false, Vector3(90, 0, 0), -1.0, 10)


func _build_front() -> void:
	# Kotflügel vorne, Motorhaube leicht aufgebogen (dort sitzt die Batterie)
	for side: float in [-1.0, 1.0]:
		BuildKit.box_mm(self, Vector3(0.95, 0.8, side * 0.62), Vector3(2.3, 1.1, side * 0.9), paint, false)
		BuildKit.box_mm(self, Vector3(0.95, 0.62, side * 0.62), Vector3(1.05, 0.8, side * 0.9), paint, false)
		BuildKit.box_mm(self, Vector3(2.2, 0.62, side * 0.62), Vector3(2.32, 0.8, side * 0.9), paint, false)
		_wheel_arch(Vector3(1.5, WHEEL_R, side * 0.9), side)
	BuildKit.box_mm(self, Vector3(0.95, 0.62, -0.62), Vector3(2.32, 1.08, 0.62), dark, false)
	var hood := Node3D.new()
	hood.position = Vector3(0.98, 1.1, 0)
	hood.rotation_degrees.z = 5.0
	add_child(hood)
	BuildKit.box(hood, Vector3(1.36, 0.05, 1.55), Vector3(0.68, 0.025, 0), paint, false)
	BuildKit.box(hood, Vector3(1.3, 0.04, 0.3), Vector3(0.68, 0.06, 0), paint, false)
	BuildKit.box(hood, Vector3(0.3, 0.02, 0.3), Vector3(0.9, 0.09, 0.4), BuildKit.tex_mat("moss", 0.4), false)
	# Batterie unter der Haube erahnbar
	BuildKit.box(self, Vector3(0.25, 0.18, 0.18), Vector3(1.75, 1.03, 0.45), dark, false)
	BuildKit.box(self, Vector3(0.03, 0.03, 0.03), Vector3(1.68, 1.13, 0.4), BuildKit.color_mat(Color(0.6, 0.1, 0.08)), false)
	# Kühlergrill mit Streben, runde Scheinwerfer (einer zerbrochen), verbogene Stoßstange
	BuildKit.box_mm(self, Vector3(2.3, 0.72, -0.62), Vector3(2.34, 1.08, 0.62), dark, false)
	BuildKit.box_mm(self, Vector3(2.32, 0.7, -0.64), Vector3(2.37, 0.74, 0.64), chrome, false)
	BuildKit.box_mm(self, Vector3(2.32, 1.06, -0.64), Vector3(2.37, 1.1, 0.64), chrome, false)
	for i in 5:
		BuildKit.box(self, Vector3(0.03, 0.025, 1.1), Vector3(2.35, 0.78 + i * 0.065, 0), chrome, false)
	BuildKit.box(self, Vector3(0.03, 0.34, 0.03), Vector3(2.355, 0.9, 0), chrome, false)
	for side: float in [-1.0, 1.0]:
		var hl := Vector3(2.33, 0.92, side * 0.75)
		BuildKit.cylinder(self, 0.1, 0.06, hl, chrome, false, Vector3(0, 0, 90), -1.0, 12)
		if side > 0:
			BuildKit.cylinder(self, 0.08, 0.02, hl + Vector3(0.03, 0, 0), glass, false, Vector3(0, 0, 90), -1.0, 12)
			BuildKit.cylinder(self, 0.035, 0.022, hl + Vector3(0.035, 0, 0), BuildKit.color_mat(Color(0.8, 0.8, 0.75), 0.2, 0.6), false, Vector3(0, 0, 90), -1.0, 8)
		else:
			BuildKit.cylinder(self, 0.08, 0.02, hl + Vector3(0.02, 0, 0), dark, false, Vector3(0, 0, 90), -1.0, 12)
			for k in 3:
				BuildKit.box(self, Vector3(0.01, 0.04, 0.03), Vector3(2.37, 0.85 + k * 0.05, side * 0.7 + k * 0.03), glass, false, Vector3(k * 30, 0, 0))
	var bumper := BuildKit.box(self, Vector3(0.12, 0.13, 1.95), Vector3(2.47, 0.6, 0.05), chrome, false, Vector3(0, 7, -4))
	BuildKit.box(bumper, Vector3(0.02, 0.12, 0.3), Vector3(0.07, 0.0, 0.0), BuildKit.tex_mat("metal", 0.2, Color(1.6, 1.55, 1.3)), false)
	for z: float in [-0.5, 0.5]:
		BuildKit.box(self, Vector3(0.25, 0.06, 0.06), Vector3(2.35, 0.6, z), rust, false)


## Radlauf als Bogen aus kurzen Blechstücken über dem Rad.
func _wheel_arch(center: Vector3, side: float) -> void:
	for k in 9:
		var a := PI * float(k) / 8.0
		var p := center + Vector3(cos(a) * 0.48, sin(a) * 0.48, 0)
		BuildKit.box(self, Vector3(0.18, 0.05, 0.08), p - Vector3(0, 0, side * 0.03), paint, false, Vector3(0, 0, rad_to_deg(a) + 90.0))


func _build_cab() -> void:
	# Unterteil der Kabine und Türen
	BuildKit.box_mm(self, Vector3(-0.35, 0.62, -0.9), Vector3(0.98, 1.15, -0.86), paint, false)
	BuildKit.box_mm(self, Vector3(-0.35, 0.62, 0.86), Vector3(-0.3, 1.15, 0.9), paint, false)
	BuildKit.box_mm(self, Vector3(0.93, 0.62, 0.86), Vector3(0.98, 1.15, 0.9), paint, false)
	BuildKit.box_mm(self, Vector3(-0.35, 0.62, -0.9), Vector3(-0.3, 1.75, 0.9), paint, false)
	BuildKit.box_mm(self, Vector3(-0.35, 0.58, -0.9), Vector3(0.98, 0.64, 0.9), rust, false)
	# Fugen und Griff der Beifahrertür, Rostloch unten
	BuildKit.box(self, Vector3(0.015, 0.5, 0.01), Vector3(0.88, 0.9, -0.905), dark, false)
	BuildKit.box(self, Vector3(0.015, 0.5, 0.01), Vector3(-0.22, 0.9, -0.905), dark, false)
	BuildKit.box(self, Vector3(0.12, 0.025, 0.02), Vector3(-0.1, 1.05, -0.915), chrome, false)
	BuildKit.box(self, Vector3(0.3, 0.12, 0.01), Vector3(0.4, 0.7, -0.905), BuildKit.color_mat(Color(0.2, 0.1, 0.05)), false)
	# Säulen, Dach (eingedellt), Rückwand mit kleinem Fenster
	for side: float in [-1.0, 1.0]:
		BuildKit.box(self, Vector3(0.06, 0.66, 0.06), Vector3(0.83, 1.45, side * 0.86), paint, false, Vector3(0, 0, 22))
		BuildKit.box(self, Vector3(0.08, 0.6, 0.06), Vector3(-0.31, 1.45, side * 0.86), paint, false)
		BuildKit.box_mm(self, Vector3(-0.35, 1.13, side * 0.9 - 0.04 * side), Vector3(0.97, 1.17, side * 0.9), paint, false)
	BuildKit.box_mm(self, Vector3(-0.37, 1.74, -0.92), Vector3(0.72, 1.8, 0.92), paint, false)
	BuildKit.box(self, Vector3(0.5, 0.04, 0.6), Vector3(0.2, 1.79, 0.1), paint, false, Vector3(3, 0, -3))
	BuildKit.box_mm(self, Vector3(-0.36, 1.15, -0.86), Vector3(-0.3, 1.74, 0.86), paint, false)
	BuildKit.box(self, Vector3(0.02, 0.28, 0.9), Vector3(-0.29, 1.47, 0), glass, false)
	_cracks(Vector3(-0.275, 1.48, 0.2), Vector3(0, 0, 1), 5, 0.25)
	# Windschutzscheibe mit Sprung-Stern
	BuildKit.box(self, Vector3(0.02, 0.62, 1.66), Vector3(0.84, 1.45, 0), glass, false, Vector3(0, 0, 22))
	_cracks(Vector3(0.86, 1.5, -0.35), Vector3(0, 0, 1), 8, 0.35)
	# Tannennadeln am unteren Scheibenrand
	BuildKit.box(self, Vector3(0.12, 0.03, 1.5), Vector3(0.98, 1.17, 0), BuildKit.tex_mat("needles", 0.3, Color(0.7, 0.5, 0.3)), false)
	# Rückspiegel und abgeknickte Antenne
	BuildKit.box(self, Vector3(0.03, 0.08, 0.16), Vector3(0.62, 1.68, 0), dark, false)
	BuildKit.cylinder(self, 0.006, 0.9, Vector3(0.95, 1.55, -0.9), chrome, false, Vector3(35, 0, -40), -1.0, 4)
	# Offene Fahrertür mit Fensterrahmen, Spiegel und Griff
	var door := Node3D.new()
	door.position = Vector3(0.95, 0.62, 0.9)
	door.rotation_degrees.y = -58.0
	add_child(door)
	BuildKit.box_mm(door, Vector3(-1.25, 0.0, 0.0), Vector3(0.0, 0.53, 0.05), paint, false)
	BuildKit.box_mm(door, Vector3(-1.25, 0.53, 0.0), Vector3(-1.2, 1.1, 0.04), paint, false)
	BuildKit.box_mm(door, Vector3(-1.25, 1.06, 0.0), Vector3(-0.15, 1.1, 0.04), paint, false)
	BuildKit.box(door, Vector3(0.05, 0.6, 0.04), Vector3(-0.08, 0.8, 0.02), paint, false, Vector3(0, 0, 22))
	BuildKit.box_mm(door, Vector3(-1.2, 0.05, -0.02), Vector3(-0.05, 0.5, 0.0), BuildKit.tex_mat("fabric", 0.3, Color(0.7, 0.65, 0.6)), false)
	BuildKit.box(door, Vector3(0.14, 0.025, 0.02), Vector3(-1.0, 0.4, 0.06), chrome, false)
	BuildKit.box(door, Vector3(0.04, 0.12, 0.18), Vector3(-0.15, 0.7, 0.12), chrome, false, Vector3(0, -20, 0))
	BuildKit.box(door, Vector3(0.01, 0.1, 0.15), Vector3(-0.14, 0.7, 0.2), glass, false, Vector3(0, -20, 0))
	# Glasscherben auf dem Boden vor der Tür
	for k in 8:
		BuildKit.box(self, Vector3(0.05, 0.005, 0.04), Vector3(_rng.randf_range(-0.2, 0.6), 0.1, _rng.randf_range(1.0, 1.6)), glass, false, Vector3(0, _rng.randf() * 180.0, 0))


## Sprünge in einer Scheibe: dünne dunkle Striche sternförmig vom Einschlag aus.
func _cracks(center: Vector3, _axis: Vector3, count: int, length: float) -> void:
	var line := BuildKit.color_mat(Color(0.75, 0.8, 0.8), 0.2)
	for k in count:
		var a := TAU * k / count + _rng.randf_range(-0.2, 0.2)
		var l := length * _rng.randf_range(0.4, 1.0)
		var dir := Vector3(0, sin(a), cos(a))
		BuildKit.box(self, Vector3(0.012, 0.006, l), center + dir * l * 0.5, line, false, Vector3(-rad_to_deg(a), 0, 0))


func _build_interior() -> void:
	var seat := BuildKit.tex_mat("fabric_red", 0.3, Color(0.85, 0.75, 0.7))
	BuildKit.box_mm(self, Vector3(-0.28, 0.7, -0.8), Vector3(0.25, 0.92, 0.8), seat, false)
	BuildKit.box(self, Vector3(0.14, 0.55, 1.6), Vector3(-0.22, 1.18, 0), seat, false, Vector3(0, 0, 10))
	# aufgerissener Sitz mit Schaumstoff
	var foam := BuildKit.color_mat(Color(0.75, 0.65, 0.35))
	for k in 5:
		BuildKit.sphere(self, 0.05, Vector3(_rng.randf_range(-0.15, 0.15), 0.93, _rng.randf_range(0.1, 0.5)), foam, Vector3(1, 0.6, 1), 6)
	# Armaturenbrett mit Rundinstrumenten, Lenkrad, Radio-Schacht, Handschuhfach
	BuildKit.box_mm(self, Vector3(0.55, 1.05, -0.84), Vector3(0.8, 1.25, 0.84), BuildKit.color_mat(Color(0.12, 0.11, 0.1), 0.7), false)
	for k in 2:
		BuildKit.cylinder(self, 0.05, 0.01, Vector3(0.545, 1.17, 0.42 + k * 0.13), BuildKit.color_mat(Color(0.7, 0.68, 0.6), 0.3), false, Vector3(0, 0, 90), -1.0, 10)
	BuildKit.box(self, Vector3(0.02, 0.06, 0.2), Vector3(0.545, 1.15, 0.12), dark, false)
	BuildKit.box(self, Vector3(0.02, 0.12, 0.3), Vector3(0.548, 1.14, -0.45), BuildKit.color_mat(Color(0.18, 0.16, 0.14)), false, Vector3(0, 0, 25))
	BuildKit.cylinder(self, 0.025, 0.45, Vector3(0.42, 1.12, 0.45), dark, false, Vector3(0, 0, 60), -1.0, 6)
	BuildKit.lathe(self, PackedVector2Array([Vector2(0.17, -0.012), Vector2(0.185, 0.0), Vector2(0.17, 0.012), Vector2(0.155, 0.0), Vector2(0.17, -0.012)]),
			Vector3(0.24, 1.25, 0.45), dark, 16, Vector3(0, 0, 60))
	BuildKit.box(self, Vector3(0.3, 0.02, 0.025), Vector3(0.24, 1.25, 0.45), dark, false, Vector3(0, 0, 60))
	# Laub und eine alte Zeitung im Fußraum
	BuildKit.box(self, Vector3(0.5, 0.02, 1.4), Vector3(0.5, 0.66, 0), BuildKit.tex_mat("needles", 0.4, Color(0.6, 0.45, 0.3)), false)
	BuildKit.box(self, Vector3(0.25, 0.005, 0.32), Vector3(0.0, 0.93, -0.45), BuildKit.color_mat(Color(0.7, 0.68, 0.6)), false, Vector3(0, 25, 0))


func _build_bed() -> void:
	# Ladefläche mit Rippen, Seitenwände mit Oberkante, Stirnwand, offene Heckklappe an Ketten
	BuildKit.box_mm(self, Vector3(-2.4, 0.66, -0.86), Vector3(-0.4, 0.72, 0.86), rust, false)
	for z: float in [-0.6, -0.3, 0.0, 0.3, 0.6]:
		BuildKit.box(self, Vector3(1.95, 0.03, 0.06), Vector3(-1.4, 0.735, z), paint, false)
	for side: float in [-1.0, 1.0]:
		BuildKit.box_mm(self, Vector3(-2.4, 0.62, side * 0.86), Vector3(-0.4, 1.12, side * 0.9), paint, false)
		BuildKit.box_mm(self, Vector3(-2.42, 1.1, side * 0.83), Vector3(-0.38, 1.15, side * 0.93), rust, false)
		BuildKit.box_mm(self, Vector3(-2.0, 0.72, side * 0.62), Vector3(-1.0, 0.95, side * 0.86), rust, false)
		_wheel_arch(Vector3(-1.5, WHEEL_R, side * 0.9), side)
		for x: float in [-2.25, -1.4, -0.55]:
			BuildKit.box(self, Vector3(0.08, 0.06, 0.06), Vector3(x, 1.13, side * 0.88), dark, false)
		# Rücklicht (eins zerbrochen)
		var tl := BuildKit.color_mat(Color(0.5, 0.05, 0.03), 0.3) if side > 0 else dark
		BuildKit.box(self, Vector3(0.04, 0.16, 0.1), Vector3(-2.42, 0.95, side * 0.8), tl, false)
	BuildKit.box_mm(self, Vector3(-0.42, 0.72, -0.86), Vector3(-0.38, 1.12, 0.86), paint, false)
	var gate := Node3D.new()
	gate.position = Vector3(-2.4, 0.7, 0)
	gate.rotation_degrees.z = -95.0
	add_child(gate)
	BuildKit.box_mm(gate, Vector3(-0.04, 0.0, -0.84), Vector3(0.0, 0.45, 0.84), paint, false)
	BuildKit.box(gate, Vector3(0.01, 0.12, 0.5), Vector3(-0.045, 0.25, 0), BuildKit.color_mat(Color(0.75, 0.75, 0.7)), false)
	for side: float in [-1.0, 1.0]:
		for k in 4:
			BuildKit.box(self, Vector3(0.03, 0.06, 0.02), Vector3(-2.43 - k * 0.05, 1.05 - k * 0.09, side * 0.84), rust, false, Vector3(0, 0, 30))
	# Altreifen, Kanister, Holzbretter und Laub in der Ladefläche
	_tire(Vector3(-1.9, 0.86, 0.35), Vector3(90, 0, 15), 0.3, 0.12)
	BuildKit.box(self, Vector3(1.3, 0.03, 0.15), Vector3(-1.2, 0.78, -0.55), BuildKit.tex_mat("planks_h", 0.5, Color(0.7, 0.65, 0.6)), false, Vector3(0, 8, 3))
	BuildKit.box(self, Vector3(1.0, 0.03, 0.14), Vector3(-1.3, 0.81, -0.38), BuildKit.tex_mat("planks_h", 0.5, Color(0.6, 0.55, 0.5)), false, Vector3(0, -5, 6))
	BuildKit.box(self, Vector3(1.6, 0.02, 1.4), Vector3(-1.45, 0.755, 0.05), BuildKit.tex_mat("needles", 0.4, Color(0.65, 0.48, 0.3)), false)


func _build_wheels() -> void:
	_wheel(Vector3(1.5, WHEEL_R, 0.92), 1.0, false)
	_wheel(Vector3(1.5, WHEEL_R * 0.86, -0.92), -1.0, true)
	_wheel(Vector3(-1.5, WHEEL_R, 0.92), 1.0, false)
	# fehlendes Rad: Bremstrommel liegt auf Steinen
	BuildKit.cylinder(self, 0.16, 0.1, Vector3(-1.5, 0.3, -0.85), rust, false, Vector3(90, 0, 0), -1.0, 12)
	for k in 5:
		BuildKit.cylinder(self, 0.015, 0.04, Vector3(-1.5 + cos(TAU * k / 5.0) * 0.08, 0.3 + sin(TAU * k / 5.0) * 0.08, -0.9), chrome, false, Vector3(90, 0, 0), -1.0, 6)
	var stone := BuildKit.tex_mat("stone", 0.4)
	BuildKit.sphere(self, 0.16, Vector3(-1.45, 0.1, -0.82), stone, Vector3(1.3, 0.8, 1.0), 7)
	BuildKit.sphere(self, 0.12, Vector3(-1.62, 0.07, -0.7), stone, Vector3(1.0, 0.7, 1.2), 6)
	BuildKit.box(self, Vector3(0.4, 0.2, 0.25), Vector3(-1.5, 0.12, -0.9), BuildKit.tex_mat("stone_dark", 0.3), false, Vector3(0, 15, 0))


func _wheel(center: Vector3, side: float, flat: bool) -> void:
	var tire := _tire(center, Vector3(90, 0, 0), WHEEL_R, 0.13)
	if flat:
		tire.scale = Vector3(1.0, 1.0, 0.82)
	# Felge mit Radkappe und Radmuttern
	BuildKit.lathe(self, PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.17, 0.0), Vector2(0.2, 0.03), Vector2(0.22, 0.05)]),
			center + Vector3(0, 0, side * 0.12), rust, 14, Vector3(90 * side, 0, 0))
	BuildKit.cylinder(self, 0.09, 0.03, center + Vector3(0, 0, side * 0.13), chrome, false, Vector3(90, 0, 0), 0.07, 12)
	for k in 5:
		var a := TAU * k / 5.0
		BuildKit.cylinder(self, 0.012, 0.03, center + Vector3(cos(a) * 0.12, sin(a) * 0.12, side * 0.125), chrome, false, Vector3(90, 0, 0), -1.0, 6)


## Reifen als gerundeter Ring mit Profil-Stollen.
func _tire(center: Vector3, rot: Vector3, radius: float, width: float) -> MeshInstance3D:
	var r0 := radius - 0.14
	var prof := PackedVector2Array()
	for k in 9:
		var a := -PI * 0.5 + PI * float(k) / 8.0
		prof.append(Vector2(r0 + 0.02 + (radius - r0 - 0.02) * cos(a * 0.9) , width * 0.5 * sin(a)))
	var t := BuildKit.lathe(self, prof, center, rubber, 20, rot)
	for k in 16:
		var a := TAU * k / 16.0
		BuildKit.box(t, Vector3(0.05, width * 0.8, 0.035), Vector3(cos(a) * (radius - 0.005), 0, sin(a) * (radius - 0.005)), rubber, false, Vector3(0, -rad_to_deg(a), 0))
	return t


## Gras und Farn wachsen um und unter dem Wrack, Moos auf dem Dach.
func _build_overgrowth() -> void:
	var grass := BuildKit.cutout_mat("grass_blades", Color(0.85, 0.95, 0.6))
	var fern := BuildKit.cutout_mat("fern", Color(0.8, 0.95, 0.65))
	for k in 26:
		var p := Vector3(_rng.randf_range(-2.6, 2.6), 0.0, _rng.randf_range(-1.1, 1.1))
		if absf(p.z) < 0.85 and absf(p.x) < 2.3 and _rng.randf() < 0.6:
			p.z = signf(p.z + 0.01) * _rng.randf_range(0.9, 1.1)
		var size := _rng.randf_range(0.35, 0.7)
		for a: float in [0.0, 90.0]:
			var q := MeshInstance3D.new()
			var qm := QuadMesh.new()
			qm.size = Vector2(size, size)
			qm.material = fern if k % 3 == 0 else grass
			q.mesh = qm
			q.position = p + Vector3(0, size * 0.5 + 0.05, 0)
			q.rotation_degrees.y = a + _rng.randf() * 40.0
			add_child(q)
	# junges Bäumchen wächst durch die Ladefläche
	BuildKit.cylinder(self, 0.015, 0.8, Vector3(-1.0, 1.1, 0.4), BuildKit.tex_mat("bark", 0.3), false, Vector3(0, 0, 6), 0.008, 5)
	for k in 4:
		var q := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(0.4, 0.4)
		qm.material = BuildKit.cutout_mat("leaves", Color(0.85, 1.0, 0.7))
		q.mesh = qm
		q.position = Vector3(-1.02, 1.25 + k * 0.15, 0.4)
		q.rotation_degrees = Vector3(_rng.randf_range(-30, 30), k * 47.0, 0)
		add_child(q)
	BuildKit.box(self, Vector3(0.45, 0.025, 0.5), Vector3(-0.05, 1.81, -0.35), BuildKit.tex_mat("moss", 0.4), false)


func _build_colliders() -> void:
	BuildKit.collider_box(self, Vector3(4.8, 0.55, 1.8), Vector3(0, 0.85, 0))
	BuildKit.collider_box(self, Vector3(1.3, 0.65, 1.8), Vector3(0.3, 1.45, 0))


func _node(n: String, item: String, per: int, amount: int, regrow: int, tool: String, label: String,
		t: float, snd: String, at: Vector3, col: Vector3) -> void:
	var r := ResourceNode.new()
	r.name = n
	r.item_id = item
	r.per_action = per
	r.amount = amount
	r.max_amount = amount
	r.regrow_per_day = regrow
	r.tool = tool
	r.action_label = label
	r.action_time = t
	r.sound = snd
	r.anchor = at
	r.collider_size = col
	add_child(r)
