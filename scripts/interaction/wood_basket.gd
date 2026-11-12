class_name WoodBasket
extends Interactable
## Holzkorb vor dem Kamin (filigraner Metallständer): Anfangs liegt 1 Holz darin, Platz für bis zu 6
## (Werte: data/house/house.json "wood_basket").
## [E] Holz herausnehmen, [R] Holz aus dem Rucksack hineinlegen. Füllstand ist Teil des Spielstands.

var max_wood: int = 6
var count: int = 1
var _logs: Array[Node3D] = []


func _ready() -> void:
	add_to_group("persistent")
	add_to_group("wood_basket")
	var cfg: Dictionary = DataDB.load_json("res://data/house/house.json").get("wood_basket", {})
	max_wood = clampi(int(cfg.get("max", 6)), 1, 6)
	count = clampi(int(cfg.get("start", 1)), 0, max_wood)
	# Filigraner Metallkorb (Kaminholzständer): dünne Eisenstäbe, man sieht die Scheite
	var iron := BuildKit.color_mat(Color(0.09, 0.09, 0.1), 0.45, 0.8)
	const L := 0.52     # Länge (x)
	const D := 0.40     # Tiefe (z)
	const T := 0.012    # Stabstärke
	# Bodenrahmen + Querstreben, auf denen die Scheite liegen
	for sz: float in [-1.0, 1.0]:
		BuildKit.box(self, Vector3(L, T, T), Vector3(0, 0.035, sz * D * 0.5), iron, false)
	for sx: float in [-0.17, 0.0, 0.17]:
		BuildKit.box(self, Vector3(T, T, D), Vector3(sx, 0.035, 0), iron, false)
	# Stirnseiten: U-Bügel mit Mittelstab
	for sx: float in [-1.0, 1.0]:
		var x := sx * L * 0.5
		for sz: float in [-1.0, 1.0]:
			BuildKit.box(self, Vector3(T, 0.36, T), Vector3(x, 0.18, sz * D * 0.5), iron, false)
		BuildKit.box(self, Vector3(T, T, D + T), Vector3(x, 0.36, 0), iron, false)
		BuildKit.box(self, Vector3(T, 0.32, T), Vector3(x, 0.19, 0), iron, false)
		# kleine Füße
		for sz: float in [-1.0, 1.0]:
			BuildKit.box(self, Vector3(0.04, 0.03, 0.04), Vector3(x, 0.015, sz * D * 0.5), iron, false)
	# niedrige Längsstäbe an den Seiten halten die Scheite
	for sz: float in [-1.0, 1.0]:
		BuildKit.box(self, Vector3(L, T, T), Vector3(0, 0.17, sz * D * 0.5), iron, false)
	# Scheite: 3 unten nebeneinander, 2 in den Mulden darüber, 1 obenauf – liegen auf den Streben, nichts steckt im Metall
	var bark := BuildKit.tex_mat("logs", 0.5)
	var spots := [Vector3(0, 0.103, -0.125), Vector3(0, 0.103, 0.0), Vector3(0, 0.103, 0.125),
			Vector3(0, 0.205, -0.0625), Vector3(0, 0.205, 0.0625), Vector3(0, 0.305, 0.0)]
	for i in max_wood:
		var l := BuildKit.cylinder(self, 0.056, 0.46, spots[i], bark, false, Vector3(0, 0, 90), -1.0, 7)
		_logs.append(l)
	# fester Körper, damit man nicht hindurchläuft (unsichtbar)
	var body := StaticBody3D.new()
	var bcs := CollisionShape3D.new()
	var bsh := BoxShape3D.new()
	bsh.size = Vector3(L, 0.36, D)
	bcs.shape = bsh
	bcs.position = Vector3(0, 0.18, 0)
	body.add_child(bcs)
	add_child(body)
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
		return "Holzkorb (%d/%d)  [E] Holz nehmen" % [count, max_wood]
	return "Holzkorb (leer)"


func get_secondary_prompt(_p: Node) -> String:
	if count < max_wood and Inventory.count("wood") > 0:
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
	if count >= max_wood or Inventory.count("wood") <= 0:
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
	count = clampi(int(s.get("count", 1)), 0, max_wood)
	if is_inside_tree():
		_update()
