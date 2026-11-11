class_name ResearchNote
extends Interactable
## Ein lesbares Schriftstück (Notiz, Zettel). Der Text steht in data/research/research.json
## unter "notes" und landet nach dem Lesen im Archiv.

@export var note_id: String = ""
@export var anchor: Vector3 = Vector3.ZERO
## Kein eigener Zettel sichtbar (z. B. wenn eine Karte an der Wand das Modell ist)
@export var hide_paper: bool = false


func _ready() -> void:
	# nur zum Anvisieren (kein fester Körper – man soll darüber laufen können)
	var body := Area3D.new()
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.5, 0.3, 0.5)
	cs.shape = shape
	cs.position = anchor + Vector3(0, 0.1, 0)
	body.add_child(cs)
	add_child(body)
	if hide_paper:
		return
	var paper := BuildKit.color_mat(Color(0.82, 0.78, 0.66), 0.9)
	BuildKit.box(self, Vector3(0.21, 0.004, 0.28), anchor + Vector3(0, 0.03, 0), paper, false, Vector3(3, 25, -2))
	for k in 5:
		BuildKit.box(self, Vector3(0.15, 0.001, 0.006), anchor + Vector3(0.0, 0.034, -0.08 + k * 0.035), BuildKit.color_mat(Color(0.2, 0.2, 0.25)), false, Vector3(3, 25, -2))
	BuildKit.sphere(self, 0.07, anchor + Vector3(0.06, 0.06, 0.08), BuildKit.tex_mat("stone", 0.3), Vector3(1.2, 0.7, 1.0), 7)


func get_prompt(_player: Node) -> String:
	var def: Dictionary = Research.data().get("notes", {}).get(note_id, {})
	return "[E] %s lesen" % def.get("name", "Notiz")


func interact(_player: Node) -> void:
	Research.read_note(note_id)
	get_tree().call_group("research_menu", "open_note", note_id)
