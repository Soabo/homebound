class_name WaterSource
extends Interactable
## Trinkstelle: Regentonne, Spüle oder Bach (GDD 6.1).
## E: direkt trinken. Liegt im Ursprung des Erbauers; anchor = Position.

@export var label: String = "Regentonne"
@export var anchor: Vector3 = Vector3.ZERO
@export var collider_size: Vector3 = Vector3(0.8, 1.0, 0.8)
@export var thirst_gain: float = 30.0


func _ready() -> void:
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = collider_size
	cs.shape = shape
	cs.position = anchor + Vector3(0, collider_size.y * 0.5, 0)
	body.add_child(cs)
	add_child(body)


func get_prompt(_player: Node) -> String:
	return "[E] %s – trinken  (Durst %d%%)" % [label, int(Survival.thirst)]


func interact(_player: Node) -> void:
	Survival.apply({"thirst": thirst_gain})
	SoundBank.play_at(self, "step_grass", to_global(anchor) + Vector3(0, 0.5, 0), -6.0, 1.6)
