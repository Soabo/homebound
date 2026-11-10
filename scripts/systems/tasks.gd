extends Node
## Aufgaben-Manager: Ziele, die sich nach und nach freischalten, und Tagesroutinen.
## Inhalte: data/tasks/tasks.json (Bedingungen siehe _info dort).
## Andere Systeme melden Ereignisse mit Tasks.flag("name"); gesehene Gegenstände merkt sich der Manager selbst.
## Anzeige: Tablet, Reiter „Aufgaben“. Teil des Spielstands.

signal changed

const DATA_PATH := "res://data/tasks/tasks.json"
## Orte, deren Besuch als Flag zählt (Mittelpunkt, Radius)
const PLACES := {
	"visit_crash": [Vector3(-42, 0, -30), 14.0],
	"visit_tower": [Vector3(12, 0, -80), 10.0],
	"visit_cave": [Vector3(49, 0, -72), 10.0],
	"visit_structure": [Vector3(-78, 0, 40), 16.0],
}

var flags: Dictionary = {}       ## Name -> Tag, an dem es zuletzt passiert ist
var got: Dictionary = {}         ## jemals besessene Gegenstände
var unlocked: Array = []         ## freigeschaltete Ziele
var done: Array = []             ## erledigte Ziele
var unseen: int = 0              ## neue Aufgaben, die auf dem Tablet noch nicht angesehen wurden
var _data: Dictionary = {}
var _t: float = 0.0


func _ready() -> void:
	_data = DataDB.load_json(DATA_PATH)
	Inventory.changed.connect(_on_inventory)


func data() -> Dictionary:
	return _data


func flag(name: String) -> void:
	flags[name] = TimeManager.day


func _on_inventory() -> void:
	for id: String in Inventory.items:
		if int(Inventory.items[id]) > 0:
			got[id] = true


func _process(delta: float) -> void:
	_t += delta
	if _t < 1.0:
		return
	_t = 0.0
	_check_places()
	_evaluate(true)


func _check_places() -> void:
	var p := get_tree().get_first_node_in_group("player") as Node3D
	if p == null:
		return
	for f: String in PLACES:
		var c: Vector3 = PLACES[f][0]
		if Vector2(p.global_position.x - c.x, p.global_position.z - c.z).length() < float(PLACES[f][1]):
			if not flags.has(f):
				flag(f)


## Prüft Ziele: neue freischalten, erledigte abhaken.
func _evaluate(announce: bool) -> void:
	var dirty := false
	for g: Dictionary in _data.get("goals", []):
		var id: String = g["id"]
		if done.has(id):
			continue
		if not unlocked.has(id):
			if check_all(g.get("unlock", [])):
				unlocked.append(id)
				unseen += 1
				dirty = true
				if announce:
					EventBus.notify("Neue Aufgabe: %s  (Tablet)" % g.get("title", id), 3.5)
			continue
		if check_all(g.get("done", [])):
			done.append(id)
			dirty = true
			if announce:
				EventBus.notify("Erledigt: %s" % g.get("title", id), 3.0)
				SoundBank.play_ui(self, "menu_click", -6.0, 1.3)
	if dirty:
		changed.emit()


func check_all(conds: Array) -> bool:
	for c: String in conds:
		if not check(c):
			return false
	return true


func check(c: String) -> bool:
	if c.begins_with("not:"):
		return not check(c.substr(4))
	if c.begins_with("flag:"):
		return flags.has(c.substr(5))
	if c.begins_with("today:"):
		return int(flags.get(c.substr(6), -1)) == TimeManager.day
	if c.begins_with("got:"):
		return got.has(c.substr(4)) or Inventory.count(c.substr(4)) > 0
	if c.begins_with("built:"):
		var t := c.substr(6)
		for r: Dictionary in Builder.records:
			if r.get("type", "") == t:
				return true
		return false
	if c.begins_with("link:"):
		return Research.links_done.has(c.substr(5))
	if c.begins_with("item:"):
		return _compare(c.substr(5), func(id: String) -> float: return Inventory.count(id))
	if c == "beds_planted":
		for i in Supplies.beds.size():
			if Supplies.bed_state(i) == "growing":
				return true
		return false
	if c == "beds_watered":
		for i in Supplies.beds.size():
			if Supplies.bed_state(i) == "growing" and not Supplies.beds[i]["watered"]:
				return false
		return true
	if c == "firewood":
		var basket := get_tree().get_first_node_in_group("wood_basket")
		var in_basket := int(basket.get("count")) if basket else 0
		return in_basket + Inventory.count("wood") >= 3
	if c == "radio_heard":
		var radio := get_tree().get_first_node_in_group("radio")
		return radio == null or not radio.call("has_new_message")
	if c == "water_bad":
		return WorldState.water_contaminated()
	# Vergleiche: name>=N, name<N
	var m := RegEx.create_from_string("^([a-z_]+)(>=|<=|<|>)([0-9.]+)$").search(c)
	if m:
		var v := _value(m.get_string(1))
		var n := float(m.get_string(3))
		match m.get_string(2):
			">=": return v >= n
			"<=": return v <= n
			"<": return v < n
			">": return v > n
	push_warning("Unbekannte Aufgaben-Bedingung: " + c)
	return false


func _compare(expr: String, getter: Callable) -> bool:
	var parts := expr.split(">=")
	var need := float(parts[1]) if parts.size() > 1 else 1.0
	return float(getter.call(parts[0])) >= need


func _value(name: String) -> float:
	match name:
		"day": return TimeManager.day
		"cameras": return Supplies.cameras.size()
		"tier": return Research.tier
		"analyses": return Research.done.size()
		"stage": return WorldState.stage()
		"fuel": return PowerManager.fuel
		"gencond": return Supplies.generator_condition
	return 0.0


## Für das Tablet: offene Ziele, erledigte Ziele, heutige Routinen [{title, done}].
func open_goals() -> Array:
	var out: Array = []
	for g: Dictionary in _data.get("goals", []):
		if unlocked.has(g["id"]) and not done.has(g["id"]):
			out.append(g)
	return out


func done_goals() -> Array:
	var out: Array = []
	for g: Dictionary in _data.get("goals", []):
		if done.has(g["id"]):
			out.append(g)
	return out


func daily() -> Array:
	var out: Array = []
	for d: Dictionary in _data.get("daily", []):
		if check_all(d.get("unlock", [])):
			out.append({"title": d.get("title", ""), "done": check_all(d.get("done", []))})
	return out


func mark_seen() -> void:
	if unseen != 0:
		unseen = 0
		changed.emit()


func get_state() -> Dictionary:
	return {"flags": flags.duplicate(), "got": got.duplicate(), "unlocked": unlocked.duplicate(), "done": done.duplicate(), "unseen": unseen}


func set_state(s: Dictionary) -> void:
	flags = (s.get("flags", {}) as Dictionary).duplicate()
	got = (s.get("got", {}) as Dictionary).duplicate()
	unlocked = (s.get("unlocked", []) as Array).duplicate()
	done = (s.get("done", []) as Array).duplicate()
	unseen = int(s.get("unseen", 0))
	# ohne Meldungen nachziehen (z. B. alter Spielstand)
	_evaluate(false)
	changed.emit()
