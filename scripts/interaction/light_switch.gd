class_name LightSwitch
extends Interactable
## Lichtschalter an der Wand. Die Vorderseite zeigt in lokale +z-Richtung.

@export var room_name: String = "Licht"

var lamps: Array[Lamp] = []
var is_on: bool = false
var _toggle: MeshInstance3D


func _ready() -> void:
	add_to_group("light_switch")
	var plate_mat := BuildKit.color_mat(Color(0.82, 0.8, 0.74), 0.6)
	var body := StaticBody3D.new()
	add_child(body)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.22, 0.28, 0.08)
	cs.shape = shape
	body.add_child(cs)
	BuildKit.box(self, Vector3(0.08, 0.12, 0.015), Vector3.ZERO, plate_mat, false)
	_toggle = BuildKit.box(self, Vector3(0.025, 0.045, 0.02), Vector3(0, 0, 0.015),
			BuildKit.color_mat(Color(0.7, 0.68, 0.62), 0.5), false)
	add_to_group("persistent")
	GameState.restore(self)
	_update_visual()


func get_prompt(_player: Node) -> String:
	return "[E] %s %s" % [room_name, "ausschalten" if is_on else "einschalten"]


func interact(_player: Node) -> void:
	SoundBank.play_at(self, "light_switch", global_position, -2.0)
	switch_to(not is_on)


func switch_to(value: bool) -> void:
	is_on = value
	for lamp in lamps:
		lamp.set_on(is_on)
	_update_visual()


func _update_visual() -> void:
	if _toggle:
		_toggle.rotation_degrees.x = -18.0 if is_on else 18.0


func persist_key() -> String:
	return str(get_path())


func get_state() -> Dictionary:
	return {"on": is_on}


func set_state(s: Dictionary) -> void:
	switch_to.call_deferred(bool(s.get("on", false)))
