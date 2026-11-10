class_name Places
extends Node3D
## Baut alle Orte der großen Welt (data/world/map.json → places) an ihrer Stelle auf.
## Die Bauanleitungen stehen in PlacesNear / PlacesDay / PlacesFar. Ältere Orte (Absturzstelle,
## Struktur, Höhle, Hochsitz) bauen ihre eigenen Skripte.
## Persistente Teile (Funde, Notizen, Türen) haben feste Namen: Places/<ort>/…


func _ready() -> void:
	name = "Places"
	var t := Time.get_ticks_msec()
	for id: String in WorldMap.places():
		var root := Node3D.new()
		root.name = id
		add_child(root)
		root.global_position = WorldMap.place_point(id)
		var built := PlacesNear.build(id, root) or PlacesDay.build(id, root) or PlacesFar.build(id, root)
		if not built:
			root.queue_free()
			continue
		var ring := String(WorldMap.places()[id]["ring"])
		PlaceKit.limit_visibility(root, 260.0 if ring == "near" else 320.0, 900.0)
	print("[Places] gebaut in %d ms" % (Time.get_ticks_msec() - t))
