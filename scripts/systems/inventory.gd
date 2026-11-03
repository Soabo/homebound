extends Node
## Inventar-Grundlage (GDD 6.3): Gegenstände mit Anzahl und begrenzten Plätzen.
## Gegenstandsdaten stehen in ITEMS; später werden daraus eigene Datendateien.

signal changed

const MAX_SLOTS := 6

const ITEMS := {
	"fuel_can": {"name": "Benzinkanister", "stack": 2},
	"planks": {"name": "Bretter", "stack": 10},
}

var items: Dictionary = {}


func count(id: String) -> int:
	return int(items.get(id, 0))


func display_name(id: String) -> String:
	return ITEMS.get(id, {}).get("name", id)


## Fügt Gegenstände hinzu und gibt zurück, wie viele tatsächlich passten.
func add(id: String, amount: int = 1) -> int:
	var stack: int = ITEMS.get(id, {}).get("stack", 1)
	if not items.has(id) and items.size() >= MAX_SLOTS:
		return 0
	var room := stack - count(id)
	var added := clampi(amount, 0, room)
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


func get_state() -> Dictionary:
	return items.duplicate()


func set_state(s: Dictionary) -> void:
	items = s.duplicate()
	changed.emit()
