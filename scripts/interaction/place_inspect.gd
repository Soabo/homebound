class_name PlaceInspect
extends Interactable
## Etwas an einem Ort, das man sich ansehen kann (E zeigt einen kurzen Text).
## Optional: Aktion statt Text (action liefert den Text zurück, z. B. „Funkmast reparieren“).
## needs = Gegenstände, die die Aktion braucht (werden verbraucht); flag = Aufgaben-Flag, sobald erledigt.

@export var prompt: String = "[E] Ansehen"
@export var text: String = ""
@export var area_size: Vector3 = Vector3.ONE
@export var needs: Dictionary = {}
@export var done_flag: String = ""
@export var done_prompt: String = ""
@export var done_text: String = ""
## Gegenstände, die man bekommt, wenn die Aktion klappt
@export var gives: Dictionary = {}

var done: bool = false
## Optional: liefert den Text erst beim Anschauen (z. B. Fernrohr – hängt vom Zustand des Tals ab)
var text_provider: Callable
signal acted


func _ready() -> void:
	add_to_group("persistent")
	GameState.restore(self)
	var area := Area3D.new()
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = area_size
	cs.shape = shape
	cs.position = Vector3(0, area_size.y * 0.5, 0)
	area.add_child(cs)
	add_child(area)


func get_prompt(_player: Node) -> String:
	if done and done_prompt != "":
		return done_prompt
	if needs.is_empty() or done:
		return prompt
	var parts: PackedStringArray = []
	for id: String in needs:
		parts.append("%s %d/%d" % [Inventory.display_name(id), Inventory.count(id), int(needs[id])])
	return "%s   (braucht: %s)" % [prompt, ", ".join(parts)]


func interact(_player: Node) -> void:
	if done:
		EventBus.notify(done_text if done_text != "" else text, 4.0)
		return
	if not needs.is_empty():
		if not Inventory.has_all(needs):
			EventBus.notify(text, 4.0)
			return
		for id: String in needs:
			Inventory.remove(id, int(needs[id]))
		done = true
		for id: String in gives:
			Inventory.add(id, int(gives[id]))
		if done_flag != "":
			Tasks.flag(done_flag)
		SoundBank.play_ui(self, "pickup", -4.0)
		EventBus.notify(done_text, 5.0)
		acted.emit()
		return
	if done_flag != "":
		Tasks.flag(done_flag)
	EventBus.notify(text_provider.call() if text_provider.is_valid() else text, 6.0)


func persist_key() -> String:
	return str(get_path())


func get_state() -> Dictionary:
	return {"done": done}


func set_state(s: Dictionary) -> void:
	done = bool(s.get("done", false))
