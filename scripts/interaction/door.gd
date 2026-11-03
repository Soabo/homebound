class_name Door
extends Interactable
## Drehtür mit Scharnier am linken Rand (lokale x-Achse = Türbreite).
## Optional abschließbar. Später: Schaden, Barrikaden (GDD 7.3).

@export var door_name: String = "Tür"
@export var width: float = 1.0
@export var height: float = 2.05
@export var thickness: float = 0.06
@export var lockable: bool = false
@export var open_angle_deg: float = 100.0
## +1 öffnet in Richtung lokales -z, -1 in Richtung +z.
@export var open_sign: float = 1.0
@export var color: Color = Color(0.36, 0.24, 0.15)

var is_open: bool = false
var is_locked: bool = false
var _hinge: Node3D
var _tween: Tween


func _ready() -> void:
	_build()


func _build() -> void:
	_hinge = Node3D.new()
	_hinge.name = "Hinge"
	add_child(_hinge)
	# StaticBody folgt der Drehung des Scharniers zuverlässig (AnimatableBody tat das mit Jolt nicht).
	var body := StaticBody3D.new()
	body.position = Vector3(width * 0.5, height * 0.5, 0.0)
	_hinge.add_child(body)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(width - 0.02, height, thickness)
	cs.shape = shape
	body.add_child(cs)

	var plank := BuildKit.wood_mat(color, 0, 0.16, 0.08)
	BuildKit.box(body, Vector3(width - 0.02, height, thickness), Vector3.ZERO, plank, false)
	# Querleisten
	var batten := BuildKit.wood_mat(color.darkened(0.25), 1, 0.2, 0.1)
	for y: float in [-height * 0.32, height * 0.32]:
		BuildKit.box(body, Vector3(width - 0.12, 0.12, 0.02), Vector3(0, y, thickness * 0.5 + 0.01), batten, false)
		BuildKit.box(body, Vector3(width - 0.12, 0.12, 0.02), Vector3(0, y, -thickness * 0.5 - 0.01), batten, false)
	# Griffe
	var metal := BuildKit.color_mat(Color(0.15, 0.14, 0.13), 0.4, 0.8)
	for side: float in [1.0, -1.0]:
		BuildKit.box(body, Vector3(0.03, 0.14, 0.04), Vector3(width * 0.5 - 0.12, -0.05, side * (thickness * 0.5 + 0.03)), metal, false)


func get_prompt(_player: Node) -> String:
	if is_locked:
		return "[E] %s (abgeschlossen)" % door_name
	return "[E] %s %s" % [door_name, "schließen" if is_open else "öffnen"]


func get_secondary_prompt(_player: Node) -> String:
	if not lockable or is_open:
		return ""
	return "[R] %s" % ("Aufschließen" if is_locked else "Abschließen")


func interact(_player: Node) -> void:
	if is_locked:
		EventBus.notify("Abgeschlossen.", 1.5)
		return
	set_open(not is_open)


func secondary_interact(_player: Node) -> void:
	if not lockable or is_open:
		return
	is_locked = not is_locked
	EventBus.notify("%s %s." % [door_name, "abgeschlossen" if is_locked else "aufgeschlossen"], 1.5)


func set_open(value: bool) -> void:
	is_open = value
	if _tween:
		_tween.kill()
	_tween = create_tween()
	var target := deg_to_rad(open_angle_deg) * open_sign if is_open else 0.0
	_tween.tween_property(_hinge, "rotation:y", target, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func get_state() -> Dictionary:
	return {"open": is_open, "locked": is_locked}
