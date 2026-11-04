class_name SecurityCamera
extends Node3D
## Eine Überwachungskamera an Hauswand oder Schuppen (GDD 7.5).
## Ursprung = Punkt auf der Wandoberfläche, wall_normal zeigt von der Wand weg.
## Ein Wandhalter mit Arm trägt das Gehäuse; das Gehäuse blickt auf look_target.
## Das Gehäuse liegt auf einer eigenen Sichtebene, die die Überwachungsbilder ausblenden –
## sonst sähe man auf dem Monitor das Innere der eigenen Kamera.

## Sichtebene (Bit) für Kameragehäuse – Überwachungskameras rendern sie nicht.
const BODY_LAYER := 1 << 3
const ARM_LENGTH := 0.32

@export var index: int = 0
@export var camera_name: String = "CAM"
@export var look_target: Vector3 = Vector3.ZERO
@export var wall_normal: Vector3 = Vector3(0, 0, 1)
## Wo das Trugbild erscheint, das nur die Kamera sieht.
@export var phantom_spot: Vector3 = Vector3.ZERO

var _led_mat: StandardMaterial3D
var _head: Node3D
var _t: float = 0.0


func _ready() -> void:
	add_to_group("security_camera")
	var n := wall_normal.normalized()
	var body_mat := BuildKit.tex_mat("metal", 0.2, Color(1.6, 1.6, 1.55), 0.5)
	var dark_mat := BuildKit.color_mat(Color(0.08, 0.08, 0.09), 0.4, 0.3)
	# Wandhalter: Platte auf der Wand, Arm nach außen (lokal +Z = von der Wand weg)
	var mount := Node3D.new()
	add_child(mount)
	mount.basis = Basis.looking_at(-n, Vector3.UP if absf(n.y) < 0.9 else Vector3.FORWARD)
	BuildKit.box(mount, Vector3(0.14, 0.18, 0.025), Vector3(0, 0, 0.012), body_mat, false)
	for sx: float in [-0.045, 0.045]:
		for sy: float in [-0.065, 0.065]:
			BuildKit.cylinder(mount, 0.008, 0.01, Vector3(sx, sy, 0.028), dark_mat, false, Vector3(90, 0, 0), -1.0, 6)
	BuildKit.cylinder(mount, 0.018, ARM_LENGTH, Vector3(0, 0, ARM_LENGTH * 0.5), body_mat, false, Vector3(90, 0, 0), 0.014, 8)
	BuildKit.sphere(mount, 0.03, Vector3(0, 0, ARM_LENGTH), dark_mat, Vector3.ONE, 8)
	# Kabel: vom Halter an der Wand entlang nach unten
	BuildKit.cylinder(mount, 0.007, 0.5, Vector3(0.05, -0.33, 0.01), dark_mat, false, Vector3.ZERO, -1.0, 5)
	BuildKit.cylinder(mount, 0.007, 0.07, Vector3(0.05, -0.07, 0.03), dark_mat, false, Vector3(70, 0, 0), -1.0, 5)
	# Gehäuse am Gelenk, blickt aufs Ziel
	_head = Node3D.new()
	add_child(_head)
	var joint := n * ARM_LENGTH
	_head.position = joint
	var up := Vector3.UP if absf((look_target - global_position - joint).normalized().y) < 0.95 else Vector3.FORWARD
	_head.basis = Basis.looking_at(look_target - (global_position + joint), up)
	BuildKit.box(_head, Vector3(0.04, 0.06, 0.04), Vector3(0, -0.035, 0), dark_mat, false)
	BuildKit.box(_head, Vector3(0.11, 0.1, 0.26), Vector3(0, -0.1, -0.06), body_mat, false)
	BuildKit.box(_head, Vector3(0.15, 0.015, 0.31), Vector3(0, -0.04, -0.08), body_mat, false)
	BuildKit.box(_head, Vector3(0.015, 0.06, 0.3), Vector3(0.07, -0.07, -0.08), body_mat, false)
	BuildKit.box(_head, Vector3(0.015, 0.06, 0.3), Vector3(-0.07, -0.07, -0.08), body_mat, false)
	BuildKit.cylinder(_head, 0.04, 0.02, Vector3(0, -0.1, -0.195), dark_mat, false, Vector3(90, 0, 0), -1.0, 12)
	BuildKit.cylinder(_head, 0.028, 0.012, Vector3(0, -0.1, -0.207), BuildKit.glass_mat(), false, Vector3(90, 0, 0), -1.0, 12)
	_led_mat = BuildKit.emissive_mat(Color(1.0, 0.1, 0.05), 2.0)
	BuildKit.sphere(_head, 0.008, Vector3(0.035, -0.065, -0.192), _led_mat, Vector3.ONE, 4)
	for vi in find_children("*", "VisualInstance3D", true, false):
		(vi as VisualInstance3D).layers = BODY_LAYER


## Blickpunkt des Überwachungsbilds: vor der Linse, Richtung Ziel.
func eye_transform() -> Transform3D:
	var lens := global_position + wall_normal.normalized() * ARM_LENGTH + Vector3(0, -0.1, 0)
	var dir := (look_target - lens).normalized()
	var t := Transform3D(Basis(), lens + dir * 0.25)
	return t.looking_at(look_target, Vector3.UP)


func _process(delta: float) -> void:
	_t += delta
	var on := PowerManager.has_power() and fmod(_t, 2.0) < 0.15
	_led_mat.emission_energy_multiplier = 3.0 if on else 0.0
