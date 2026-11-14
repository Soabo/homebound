extends Node
## Tagebuch (Autoload „Journal“): was an welchem Tag passiert ist, als kurze Sätze. Anzeige im Tablet-Reiter „Tagebuch“.
## Einträge kommen aus Ereignissen (Tasks.flag, Texte in data/story/journal.json), gelesenen Notizen (Research.read_note),
## erledigten Spuren (Story) und morgens aus der vergangenen Nacht (ThreatDirector.night_kind). Im Spielstand.

signal changed

var entries: Array = []   ## [{day, text}]
var _night_logged_day: int = -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	EventBus.flag_set.connect(_on_flag)
	TimeManager.hour_changed.connect(_on_hour)


func data() -> Dictionary:
	return DataDB.load_json("res://data/story/journal.json")


func add(text: String, day: int = -1) -> void:
	if text == "" or get_tree().get_first_node_in_group("player") == null:
		return
	var d := TimeManager.day if day < 0 else day
	# keine doppelten Sätze am selben Tag
	for e: Dictionary in entries:
		if int(e["day"]) == d and e["text"] == text:
			return
	entries.append({"day": d, "text": text})
	changed.emit()


func _on_flag(name: String) -> void:
	var flags: Dictionary = data().get("flags", {})
	if flags.has(name):
		add(String(flags[name]))
		return
	for key: String in flags:
		if key.ends_with("*") and name.begins_with(key.trim_suffix("*")):
			var rest := name.substr(key.length() - 1)
			add(String(flags[key]).replace("{name}", _pretty(key, rest)))
			return


func _pretty(key: String, rest: String) -> String:
	match key:
		"visit_*":
			return String(WorldMap.places()[rest]["name"]) if WorldMap.places().has(rest) else rest
		"link_*":
			return String(Research.link_def(rest).get("name", rest))
	return rest


## Gelesene Notiz (Research.read_note)
func note(id: String) -> void:
	var n: Dictionary = Research.data().get("notes", {}).get(id, {})
	if not n.is_empty():
		add("Gefunden: %s." % String(n.get("name", id)))


## Erledigte Spur (Story)
func step(s: Dictionary) -> void:
	var t := String(s.get("finish", ""))
	add(t if t != "" else "Erledigt: %s." % String(s.get("title", "")))


func _on_hour(day: int, hour: int) -> void:
	# Morgens um 8: ein Satz zur vergangenen Nacht (gehört zum Vortag)
	if hour == 8 and day > 1 and _night_logged_day != day:
		_night_logged_day = day
		var t := String(data().get("nights", {}).get(ThreatDirector.night_kind, ""))
		if t != "":
			add(t, day - 1)


## Einträge nach Tagen gruppiert, neueste zuerst: [[day, [texte]], ...]
func by_day() -> Array:
	var days := {}
	for e: Dictionary in entries:
		var d := int(e["day"])
		if not days.has(d):
			days[d] = []
		(days[d] as Array).append(String(e["text"]))
	var keys := days.keys()
	keys.sort()
	keys.reverse()
	var out: Array = []
	for k: int in keys:
		out.append([k, days[k]])
	return out


func get_state() -> Dictionary:
	return {"entries": entries.duplicate(true), "night_day": _night_logged_day}


func set_state(s: Dictionary) -> void:
	entries = (s.get("entries", []) as Array).duplicate(true)
	_night_logged_day = int(s.get("night_day", -1))
	changed.emit()
