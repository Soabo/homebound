class_name Blueprint
extends Interactable
## Ein gefundener Bauplan (zusammengerollt, mit Schnur). E = mitnehmen → die Werkbank kennt das Rezept.

@export var bp_id: String = ""
@export var label: String = "Bauplan"

var _taken: bool = false
var _vis: Node3D


func _ready() -> void:
	add_to_group("persistent")
	GameState.restore(self)
	var area := Area3D.new()
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.6, 0.25, 0.3)
	cs.shape = shape
	cs.position = Vector3(0, 0.1, 0)
	area.add_child(cs)
	add_child(area)
	_vis = Node3D.new()
	add_child(_vis)
	var paper := BuildKit.color_mat(Color(0.55, 0.68, 0.85), 0.9)
	BuildKit.cylinder(_vis, 0.035, 0.5, Vector3(0, 0.035, 0), paper, false, Vector3(0, 0, 90), -1.0, 10)
	BuildKit.cylinder(_vis, 0.037, 0.02, Vector3(0.08, 0.035, 0), BuildKit.color_mat(Color(0.7, 0.2, 0.15)), false, Vector3(0, 0, 90), -1.0, 10)
	BuildKit.box(_vis, Vector3(0.25, 0.003, 0.18), Vector3(-0.05, 0.002, 0.09), paper, false, Vector3(0, 10, 0))
	_vis.visible = not _taken
	if _taken:
		area.queue_free()


func get_prompt(_player: Node) -> String:
	return "" if _taken else "[E] Bauplan mitnehmen: %s" % label


func interact(_player: Node) -> void:
	if _taken:
		return
	_taken = true
	_vis.visible = false
	for c in get_children():
		if c is Area3D:
			c.queue_free()
	Research.learn_blueprint(bp_id)
	Tasks.flag("bp_" + bp_id)
	SoundBank.play_ui(self, "pickup", -6.0)
	EventBus.notify("Bauplan gefunden: %s – jetzt an der Werkbank baubar." % label, 4.0)


func persist_key() -> String:
	return str(get_path())


func get_state() -> Dictionary:
	return {"taken": _taken}


func set_state(s: Dictionary) -> void:
	_taken = bool(s.get("taken", false))
