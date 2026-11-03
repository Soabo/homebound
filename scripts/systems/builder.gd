extends Node
## Base Building Manager (GDD 17.2): verwaltet alles, was der Spieler auf dem
## Grundstück platziert hat. Hält die Bauten als Datensätze, damit sie Tod/Neustart
## überstehen, und setzt sie beim Laden der Szene wieder in die Welt.

signal structures_changed

## Datensätze: {"uid": int, "type": String, "pos": Vector3, "rot": float, "health": float}
var records: Array[Dictionary] = []
var _next_uid: int = 1


## Platziert ein neues Bauobjekt und erzeugt es in der aktuellen Szene.
func place(type: String, pos: Vector3, rot_y: float) -> Structure:
	var def := DataDB.buildable(type)
	var rec := {"uid": _next_uid, "type": type, "pos": pos, "rot": rot_y, "health": float(def.get("health", 50))}
	_next_uid += 1
	records.append(rec)
	structures_changed.emit()
	return _spawn(rec)


## Setzt nach dem Laden der Szene alle Bauten wieder hin.
func spawn_all(scene: Node) -> void:
	for rec in records:
		_spawn(rec, scene)


func _spawn(rec: Dictionary, scene: Node = null) -> Structure:
	if scene == null:
		scene = get_tree().current_scene
	var s := Structure.new()
	s.uid = rec["uid"]
	s.type = rec["type"]
	s.health = rec["health"]
	s.name = "Build_%d" % rec["uid"]
	scene.add_child(s)
	s.global_position = rec["pos"]
	s.rotation.y = rec["rot"]
	return s


func record(uid: int) -> Dictionary:
	for r in records:
		if r["uid"] == uid:
			return r
	return {}


func update_health(uid: int, health: float) -> void:
	var r := record(uid)
	if not r.is_empty():
		r["health"] = health


func remove(uid: int) -> void:
	for i in records.size():
		if records[i]["uid"] == uid:
			records.remove_at(i)
			structures_changed.emit()
			return


func get_state() -> Array:
	var out: Array = []
	for r in records:
		out.append(r.duplicate())
	return out


func set_state(s: Array) -> void:
	records.clear()
	for r in s:
		records.append((r as Dictionary).duplicate())
		_next_uid = maxi(_next_uid, int(r["uid"]) + 1)
	structures_changed.emit()
