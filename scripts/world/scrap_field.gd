class_name ScrapField
extends Node3D
## Metall-Fundstellen im Wald (Versorgungs-Manager: Supplies.scrap_spots).
## Alte Auspuffe, Motorblöcke, Silo-Teile, Traktorteile, Ölfässer – einmal mit der Blechschere abbauen,
## dann verschwinden sie. Neue tauchen jeden Tag zufällig auf, rund um das Autowrack häufiger.

var _nodes: Dictionary = {}   ## Fundstellen-ID -> Knoten


func _ready() -> void:
	name = "ScrapField"
	add_to_group("scrap_field")
	Supplies.changed.connect(sync)
	sync()


## Knoten an die Liste im Versorgungs-Manager angleichen.
func sync() -> void:
	var ids := {}
	for s: Dictionary in Supplies.scrap_spots:
		ids[int(s["id"])] = s
	for id: int in _nodes.keys():
		if not ids.has(id):
			(_nodes[id] as Node).queue_free()
			_nodes.erase(id)
	for id: int in ids:
		if not _nodes.has(id):
			_nodes[id] = _make(ids[id])


func _make(s: Dictionary) -> Node3D:
	var spot := ScrapSpot.new()
	spot.spot_id = int(s["id"])
	spot.kind = String(s["kind"])
	spot.name = "ScrapSpot_%d" % spot.spot_id
	var p := Vector3(float(s["x"]), 0, float(s["z"]))
	p.y = Terrain.height_at(p.x, p.z)
	spot.position = p
	spot.rotation.y = float(s.get("yaw", 0.0))
	add_child(spot)
	return spot
