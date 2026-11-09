extends Node
## Inventar (GDD 6.3): Gegenstände mit Anzahl, begrenzte Traglast in kg.
## Die Gegenstandsdaten kommen aus data/items/items.json.

signal changed
## Schnellplätze oder Auswahl haben sich geändert
signal hotbar_changed

const MAX_WEIGHT := 40.0
var _was_overloaded: bool = false


func _ready() -> void:
	changed.connect(_check_overload)


## Mehr als die Traglast im Rucksack: nur noch gehen, kein Rennen.
func overloaded() -> bool:
	return total_weight() > MAX_WEIGHT + 0.001


func _check_overload() -> void:
	var o := overloaded()
	if o and not _was_overloaded:
		EventBus.notify("Überladen! (%.1f / %.0f kg) – du kannst nur noch langsam gehen." % [total_weight(), MAX_WEIGHT], 4.0)
	elif not o and _was_overloaded:
		EventBus.notify("Du bist nicht mehr überladen.", 2.0)
	_was_overloaded = o
const SLOTS := 9

var items: Dictionary = {}
## Schnellplätze 1–9: Gegenstands-IDs für die rechte Hand ("" = leer → Faust)
var hotbar: Array = ["", "", "", "", "", "", "", "", ""]
var selected: int = 0


## Kann man den Gegenstand in die rechte Hand nehmen?
func is_holdable(id: String) -> bool:
	return DataDB.item(id).has("hand")


## Was gerade in der rechten Hand liegt ("" = Faust).
func equipped() -> String:
	var id: String = hotbar[selected]
	return id if id != "" and count(id) > 0 else ""


func select(i: int) -> void:
	i = posmod(i, SLOTS)
	if i != selected:
		selected = i
		hotbar_changed.emit()


func set_slot(i: int, id: String) -> void:
	# ein Gegenstand liegt nur auf einem Platz
	for k in SLOTS:
		if hotbar[k] == id and id != "":
			hotbar[k] = ""
	hotbar[i] = id
	hotbar_changed.emit()


func swap_slots(a: int, b: int) -> void:
	var t: String = hotbar[a]
	hotbar[a] = hotbar[b]
	hotbar[b] = t
	hotbar_changed.emit()


func slot_of(id: String) -> int:
	return hotbar.find(id)


## Neue Handgegenstände landen automatisch auf dem ersten freien Platz.
func _auto_slot(id: String) -> void:
	if not is_holdable(id) or slot_of(id) >= 0:
		return
	for k in SLOTS:
		if hotbar[k] == "":
			hotbar[k] = id
			hotbar_changed.emit()
			EventBus.notify("%s liegt auf Taste %d" % [display_name(id), k + 1], 3.0)
			return


func count(id: String) -> int:
	return int(items.get(id, 0))


func display_name(id: String) -> String:
	return DataDB.item(id).get("name", id)


func weight_of(id: String) -> float:
	return float(DataDB.item(id).get("weight", 1.0))


func total_weight() -> float:
	var w := 0.0
	for id in items:
		w += weight_of(id) * count(id)
	return w


## Fügt Gegenstände hinzu und gibt zurück, wie viele tatsächlich passten
## (begrenzt durch Stapelgröße und Traglast).
func add(id: String, amount: int = 1) -> int:
	var stack := int(DataDB.item(id).get("stack", 99))
	var by_stack := stack - count(id)
	# Über die Traglast hinaus darf man aufnehmen – dann ist man überladen und kann nur noch gehen.
	var added := clampi(mini(amount, by_stack), 0, amount)
	if added > 0:
		items[id] = count(id) + added
		changed.emit()
		_auto_slot(id)
	return added


func remove(id: String, amount: int = 1) -> bool:
	if count(id) < amount:
		return false
	items[id] = count(id) - amount
	if items[id] <= 0:
		items.erase(id)
		var k := slot_of(id)
		if k >= 0:
			hotbar[k] = ""
			hotbar_changed.emit()
	changed.emit()
	return true


func has_all(needs: Dictionary) -> bool:
	for id in needs:
		if count(id) < int(needs[id]):
			return false
	return true


func remove_all(needs: Dictionary) -> bool:
	if not has_all(needs):
		return false
	for id in needs:
		remove(id, int(needs[id]))
	return true


## Benutzt Essen/Trinken. Gibt true zurück, wenn etwas passiert ist.
func use(id: String) -> bool:
	var effect: Dictionary = DataDB.item(id).get("use", {})
	if effect.is_empty() or count(id) <= 0:
		return false
	remove(id, 1)
	Survival.apply(effect)
	return true


func get_state() -> Dictionary:
	return {"items": items.duplicate(), "hotbar": hotbar.duplicate(), "selected": selected}


func set_state(s: Dictionary) -> void:
	if s.has("items"):
		items = (s["items"] as Dictionary).duplicate()
		hotbar = (s.get("hotbar", hotbar) as Array).duplicate()
		selected = int(s.get("selected", 0))
	else:
		items = s.duplicate()
	changed.emit()
	hotbar_changed.emit()
