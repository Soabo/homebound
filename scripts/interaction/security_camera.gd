class_name SecurityCamera
extends Node3D
## Eine Überwachungskamera an Hauswand, Pfosten oder Schuppen (GDD 7.5).
## Ursprung = Montagepunkt; die Kamera blickt auf look_target (Weltkoordinaten).

@export var index: int = 0
@export var camera_name: String = "CAM"
@export var look_target: Vector3 = Vector3.ZERO
## Wo das Trugbild erscheint, das nur die Kamera sieht.
@export var phantom_spot: Vector3 = Vector3.ZERO

var _led_mat: StandardMaterial3D
var _t: float = 0.0


func _ready() -> void:
	add_to_group("security_camera")
	var dir := (look_target - global_position).normalized()
	# Gehäuse ausrichten
	var head := Node3D.new()
	add_child(head)
	head.look_at_from_position(global_position, look_target, Vector3.UP)
	head.global_position = global_position
	var body_mat := BuildKit.tex_mat("metal", 0.2, Color(1.5, 1.5, 1.45), 0.5)
	BuildKit.box(self, Vector3(0.05, 0.05, 0.2), Vector3(0, 0.03, 0), body_mat, false)
	BuildKit.box(head, Vector3(0.12, 0.1, 0.24), Vector3(0, 0, -0.08), body_mat, false)
	BuildKit.box(head, Vector3(0.16, 0.02, 0.28), Vector3(0, 0.06, -0.1), body_mat, false)
	BuildKit.cylinder(head, 0.035, 0.03, Vector3(0, 0, -0.205), BuildKit.color_mat(Color(0.05, 0.05, 0.06), 0.1), false, Vector3(90, 0, 0), -1.0, 10)
	_led_mat = BuildKit.emissive_mat(Color(1.0, 0.1, 0.05), 2.0)
	BuildKit.sphere(head, 0.01, Vector3(0.04, 0.035, -0.2), _led_mat, Vector3.ONE, 4)
	if dir.length() < 0.1:
		push_warning("Kamera %s hat kein Blickziel" % camera_name)


func eye_transform() -> Transform3D:
	var t := Transform3D()
	t.origin = global_position + Vector3(0, -0.02, 0)
	return t.looking_at(look_target, Vector3.UP)


func _process(delta: float) -> void:
	_t += delta
	var on := PowerManager.has_power() and fmod(_t, 2.0) < 0.15
	_led_mat.emission_energy_multiplier = 3.0 if on else 0.0
