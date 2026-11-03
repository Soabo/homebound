class_name DataDB
extends RefCounted
## Lädt Spielinhalte aus JSON-Dateien unter data/ (GDD 17.4: datengetrieben).
## Neue Gegenstände, Rezepte oder Bauobjekte = neuer Eintrag in der Datei, kein Code.

static var _cache: Dictionary = {}


static func load_json(path: String) -> Dictionary:
	if _cache.has(path):
		return _cache[path]
	var data: Dictionary = {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f:
		var parsed: Variant = JSON.parse_string(f.get_as_text())
		if parsed is Dictionary:
			data = parsed
		else:
			push_error("Ungültiges JSON: " + path)
	else:
		push_error("Datei fehlt: " + path)
	_cache[path] = data
	return data


static func items() -> Dictionary:
	return load_json("res://data/items/items.json")


static func item(id: String) -> Dictionary:
	return items().get(id, {})


static func recipes() -> Array:
	return load_json("res://data/items/recipes.json").get("recipes", [])


static func buildables() -> Dictionary:
	return load_json("res://data/items/buildables.json")


static func buildable(id: String) -> Dictionary:
	return buildables().get(id, {})
