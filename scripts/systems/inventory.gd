extends Node
## Inventar (GDD 6.3): Gegenstände mit Anzahl, begrenzte Traglast in kg.
## Die Gegenstandsdaten kommen aus data/items/items.json.

signal changed

const MAX_WEIGHT := 40.0

var items: Dictionary = {}


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
	var by_weight := int(floor((MAX_WEIGHT - total_weight()) / maxf(weight_of(id), 0.001) + 0.0001))
	var added := clampi(mini(amount, mini(by_stack, by_weight)), 0, amount)
	if added > 0:
		items[id] = count(id) + added
		changed.emit()
	return added


func remove(id: String, amount: int = 1) -> bool:
	if count(id) < amount:
		return false
	items[id] = count(id) - amount
	if items[id] <= 0:
		items.erase(id)
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
	return items.duplicate()


func set_state(s: Dictionary) -> void:
	items = s.duplicate()
	changed.emit()
