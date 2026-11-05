class_name StorageChest
extends Interactable
## Truhe zum Lagern: [E] öffnet Rucksack und Truhe nebeneinander. Was drin liegt, zählt nicht zur Traglast.
## Inhalt ist Teil des Spielstands.

var items: Dictionary = {}  ## id -> Anzahl
var size := Vector3(1.0, 0.5, 0.52)
var _lid: Node3D


func _ready() -> void:
	add_to_group("persistent")
	add_to_group("storage_chest")
	var wood := BuildKit.tex_mat("planks_h", 0.6, Color(0.85, 0.7, 0.55))
	var dark := BuildKit.tex_mat("planks_h", 0.6, Color(0.5, 0.42, 0.36))
	var iron := BuildKit.color_mat(Color(0.2, 0.2, 0.21), 0.5, 0.7)
	var h := size.y * 0.72
	# Kasten mit Bodenleisten, Eisenbeschlägen an den Ecken, Griffen an den Seiten
	BuildKit.box(self, Vector3(size.x, h, size.z), Vector3(0, h * 0.5 + 0.03, 0), wood, true)
	BuildKit.box(self, Vector3(size.x + 0.02, 0.04, size.z + 0.02), Vector3(0, 0.02, 0), dark, false)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			BuildKit.box(self, Vector3(0.06, h, 0.06), Vector3(sx * (size.x * 0.5 - 0.02), h * 0.5 + 0.03, sz * (size.z * 0.5 - 0.02)), iron, false)
		BuildKit.box(self, Vector3(0.02, 0.04, 0.16), Vector3(sx * (size.x * 0.5 + 0.015), h * 0.75, 0), iron, false)
	for x: float in [-0.3, 0.3]:
		BuildKit.box(self, Vector3(0.05, h + 0.005, size.z + 0.01), Vector3(x, h * 0.5 + 0.03, 0), iron, false)
	# Deckel (leicht gewölbt) mit Schloss vorne
	_lid = Node3D.new()
	_lid.position = Vector3(0, h + 0.03, -size.z * 0.5)
	add_child(_lid)
	BuildKit.box(_lid, Vector3(size.x + 0.02, 0.06, size.z + 0.02), Vector3(0, 0.03, size.z * 0.5), dark, false)
	BuildKit.box(_lid, Vector3(size.x - 0.04, 0.05, size.z - 0.06), Vector3(0, 0.08, size.z * 0.5), wood, false)
	for x: float in [-0.3, 0.3]:
		BuildKit.box(_lid, Vector3(0.05, 0.11, size.z + 0.03), Vector3(x, 0.055, size.z * 0.5), iron, false)
	BuildKit.box(_lid, Vector3(0.09, 0.1, 0.02), Vector3(0, -0.02, size.z + 0.02), iron, false)
	BuildKit.box(_lid, Vector3(0.03, 0.03, 0.025), Vector3(0, -0.04, size.z + 0.03), BuildKit.color_mat(Color(0.6, 0.5, 0.25), 0.4, 0.8), false)
	GameState.restore(self)


func get_prompt(_p: Node) -> String:
	var n := 0
	for id in items:
		n += int(items[id])
	return "[E] Truhe öffnen" + ("  (%d Sachen drin)" % n if n > 0 else "  (leer)")


func interact(_p: Node) -> void:
	SoundBank.play_at(self, "door_open", global_position + Vector3(0, 0.4, 0), -6.0)
	create_tween().tween_property(_lid, "rotation_degrees:x", -70.0, 0.35)
	get_tree().call_group("game_menus", "open_chest", self)


func closed() -> void:
	create_tween().tween_property(_lid, "rotation_degrees:x", 0.0, 0.3)
	SoundBank.play_at(self, "door_close", global_position + Vector3(0, 0.4, 0), -8.0)


## Aus dem Rucksack in die Truhe (so viele wie möglich von amount).
func put(id: String, amount: int) -> int:
	amount = mini(amount, Inventory.count(id))
	if amount <= 0:
		return 0
	Inventory.remove(id, amount)
	items[id] = int(items.get(id, 0)) + amount
	return amount


## Aus der Truhe in den Rucksack – nur so viel, wie man tragen kann.
func take(id: String, amount: int) -> int:
	amount = mini(amount, int(items.get(id, 0)))
	var got := Inventory.add(id, amount) if amount > 0 else 0
	if got > 0:
		items[id] = int(items[id]) - got
		if int(items[id]) <= 0:
			items.erase(id)
	return got


func persist_key() -> String:
	return str(get_path())


func get_state() -> Dictionary:
	return {"items": items.duplicate()}


func set_state(s: Dictionary) -> void:
	items = {}
	var d: Dictionary = s.get("items", {})
	for k in d:
		items[String(k)] = int(d[k])
