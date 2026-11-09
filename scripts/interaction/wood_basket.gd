class_name WoodBasket
extends Interactable
## Holzkorb vor dem Kamin: Anfangs liegt 1 Holz darin, Platz für bis zu 4.
## [E] Holz herausnehmen, [R] Holz aus dem Rucksack hineinlegen. Füllstand ist Teil des Spielstands.

const MAX := 4
var count: int = 1
var _logs: Array[Node3D] = []


func _ready() -> void:
	add_to_group("persistent")
	var staves := BuildKit.tex_mat("planks_v", 0.4, Color(0.8, 0.7, 0.6))
	BuildKit.cylinder(self, 0.25, 0.3, Vector3(0, 0.15, 0), staves, true, Vector3.ZERO, 0.22, 10)
	# Boden innen dunkel, damit ein leerer Korb auch leer aussieht
	BuildKit.cylinder(self, 0.21, 0.01, Vector3(0, 0.05, 0), BuildKit.color_mat(Color(0.18, 0.13, 0.09), 0.9), false, Vector3.ZERO, -1.0, 10)
	var bark := BuildKit.tex_mat("logs", 0.5)
	var spots := [Vector3(-0.07, 0.12, 0), Vector3(0.07, 0.12, 0), Vector3(-0.0, 0.22, 0.02), Vector3(0.0, 0.22, -0.06)]
	for i in MAX:
		var l := BuildKit.cylinder(self, 0.06, 0.48, spots[i], bark, false, Vector3(90, 25 * i - 20, 0), -1.0, 6)
		_logs.append(l)
	# zum Anvisieren: etwas größer als der Korb
	var area := Area3D.new()
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(0.6, 0.5, 0.6)
	cs.shape = sh
	cs.position = Vector3(0, 0.25, 0)
	area.add_child(cs)
	add_child(area)
	GameState.restore(self)
	_update()


func _update() -> void:
	for i in _logs.size():
		_logs[i].visible = i < count


func get_prompt(_p: Node) -> String:
	if count > 0:
		return "Holzkorb (%d/%d)  [E] Holz nehmen" % [count, MAX]
	return "Holzkorb (leer)"


func get_secondary_prompt(_p: Node) -> String:
	if count < MAX and Inventory.count("wood") > 0:
		return "[R] Holz hineinlegen"
	return ""


func interact(_p: Node) -> void:
	if count <= 0:
		return
	if Inventory.add("wood", 1) > 0:
		count -= 1
		SoundBank.play_at(self, "pickup", global_position + Vector3(0, 0.3, 0), -4.0, 0.9)
		_update()


func secondary_interact(_p: Node) -> void:
	if count >= MAX or Inventory.count("wood") <= 0:
		return
	if Inventory.remove("wood", 1):
		count += 1
		SoundBank.play_at(self, "place", global_position + Vector3(0, 0.3, 0), -4.0, 1.1)
		_update()


func persist_key() -> String:
	return str(get_path())


func get_state() -> Dictionary:
	return {"count": count}


func set_state(s: Dictionary) -> void:
	count = clampi(int(s.get("count", 1)), 0, MAX)
	if is_inside_tree():
		_update()
