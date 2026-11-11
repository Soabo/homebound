class_name ItemPickup
extends Interactable
## Etwas zum Aufheben (Benzinkanister, Bretter …).
## Die sichtbaren Teile hängt der Erbauer als Kinder an; sie verschwinden,
## wenn nichts mehr übrig ist. Bei Stapeln verschwindet pro Stück ein Teil.

@export var item_id: String = "planks"
@export var amount: int = 1
@export var label: String = ""
## Wie viele Stück pro Benutzung genommen werden.
@export var per_take: int = 1
@export var collider_size: Vector3 = Vector3(0.4, 0.4, 0.4)
@export var collider_offset: Vector3 = Vector3(0, 0.2, 0)

## Vorratskiste: man kann mit R wieder hineinstellen (bis zur Anfangsmenge); die Kiste selbst (visuals[0]) bleibt stehen.
@export var restock: bool = false

var visuals: Array[Node3D] = []


func _ready() -> void:
	add_to_group("persistent")
	_initial()
	GameState.restore(self)
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = collider_size
	cs.shape = shape
	cs.position = collider_offset
	body.add_child(cs)
	add_child(body)
	_update_visuals()
	# Erbauer hängen die sichtbaren Teile oft erst nach add_child an
	_update_visuals.call_deferred()
	if amount <= 0 and not restock:
		body.queue_free()


func get_prompt(_player: Node) -> String:
	if amount <= 0 and restock:
		return "%s – leer" % (label if label != "" else "Vorratskiste")
	if amount <= 0:
		return ""
	var name_text := label if label != "" else Inventory.display_name(item_id)
	if amount > 1:
		return "[E] %s nehmen  (%d übrig)" % [name_text, amount]
	return "[E] %s nehmen" % name_text


func get_secondary_prompt(_player: Node) -> String:
	if not restock or amount >= _initial() or Inventory.count(item_id) <= 0:
		return ""
	return "[R] %s hineinstellen (%d dabei)" % [Inventory.display_name(item_id), Inventory.count(item_id)]


## Vorratskiste: ein Stück zurück in die Kiste.
func secondary_interact(_player: Node) -> void:
	if not restock or amount >= _initial() or not Inventory.remove(item_id, 1):
		return
	amount += 1
	SoundBank.play_ui(self, "place", -8.0)
	_update_visuals()


func interact(_player: Node) -> void:
	if amount <= 0:
		return
	var took := Inventory.add(item_id, mini(per_take, amount))
	if took <= 0:
		EventBus.notify("Kein Platz mehr für %s." % Inventory.display_name(item_id), 2.0)
		return
	amount -= took
	SoundBank.play_ui(self, "pickup", -6.0)
	EventBus.notify("%s +%d  (jetzt %d)" % [Inventory.display_name(item_id), took, Inventory.count(item_id)], 2.0)
	_update_visuals()
	if amount <= 0 and not restock:
		for c in get_children():
			if c is StaticBody3D:
				c.queue_free()


func _update_visuals() -> void:
	if visuals.is_empty():
		return
	var show := int(ceil(float(visuals.size()) * float(amount) / float(maxi(_initial(), 1))))
	for i in visuals.size():
		visuals[i].visible = i < show or (restock and i == 0)


var _initial_amount: int = -1


func _initial() -> int:
	if _initial_amount < 0:
		_initial_amount = amount
	return _initial_amount


func persist_key() -> String:
	return str(get_path())


func get_state() -> Dictionary:
	return {"amount": amount}


func set_state(s: Dictionary) -> void:
	amount = int(s.get("amount", amount))
