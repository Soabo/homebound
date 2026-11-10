extends Node
## Forschung und Alien-Archiv (GDD 12). Inhalte in data/research/research.json.
##
## Ablauf: Fund ins Analysegerät legen → passive Analyse (Spielstunden, braucht beim
## improvisierten Gerät Strom) + aktive Experimente → fertige Analysen ins Archiv.
## Zwei passende Analysen lassen sich im Archiv verknüpfen → Erkenntnis, ggf. neue Baupläne.
##
## Gerätestufe: 0 = keins, 1 = improvisiert (umgebautes Funkgerät), 2 = fremdes Analysegerät.

signal changed

const SPEED := {1: 1.0, 2: 2.0}

var tier: int = 0
var slot: String = ""              ## Analyse-ID des eingelegten Fundes ("" = leer)
var progress: Dictionary = {}      ## Analyse-ID -> erledigte Spielstunden
var experiments: Dictionary = {}   ## Analyse-ID -> Array erledigter Experiment-IDs
var done: Array = []               ## fertige Analysen
var links_done: Array = []         ## gefundene Verknüpfungen
var seen: Array = []               ## jemals aufgehobene Funde (für das Archiv)
var notes: Array = []              ## gelesene Notizen
var blueprints: Array = []         ## in der Welt gefundene Baupläne
var sent: Array = []               ## ans Tablet gesendete Ergebnisse: "analyse" bzw. "analyse/experiment"
var tablet_new: int = 0            ## neue, auf dem Tablet noch nicht angesehene Ergebnisse

var _last_hour: float = -1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	Inventory.changed.connect(_on_inventory_changed)


func data() -> Dictionary:
	return DataDB.load_json("res://data/research/research.json")


func analysis(id: String) -> Dictionary:
	return data().get("analyses", {}).get(id, {})


func link_def(id: String) -> Dictionary:
	return data().get("links", {}).get(id, {})


## Zu welcher Analyse gehört ein Fund?
func analysis_for_find(find: String) -> String:
	var all: Dictionary = data().get("analyses", {})
	for id in all:
		if all[id].get("find", "") == find:
			return id
	return ""


func _on_inventory_changed() -> void:
	for id in Inventory.items:
		if DataDB.item(id).get("category", "") == "Fund" and not seen.has(id):
			seen.append(id)
			if id != "alien_analyzer":
				EventBus.notify("Neuer Fund: %s – im Alien-Archiv auf dem Tablet vermerkt" % Inventory.display_name(id), 3.5)
			changed.emit()


# --- Gerät ------------------------------------------------------------

func has_power_for_analysis() -> bool:
	return tier >= 2 or PowerManager.has_power()


func set_tier(t: int) -> void:
	if t > tier:
		tier = t
		changed.emit()


func device_name() -> String:
	match tier:
		1: return "Analysegerät (umgebautes Funkgerät)"
		2: return "Fremdes Analysegerät"
	return "kein Analysegerät"


func insert(find: String) -> bool:
	var id := analysis_for_find(find)
	if tier <= 0 or slot != "" or id == "" or done.has(id) or Inventory.count(find) <= 0:
		return false
	Inventory.remove(find, 1)
	slot = id
	changed.emit()
	return true


## Fund wieder herausnehmen (Fortschritt bleibt erhalten).
func take_out() -> void:
	if slot == "":
		return
	var find: String = analysis(slot).get("find", "")
	if Inventory.add(find, 1) <= 0:
		EventBus.notify("Zu schwer – du kannst den Fund nicht tragen.", 2.0)
		return
	slot = ""
	changed.emit()


func hours_needed(id: String) -> float:
	return float(analysis(id).get("hours", 2.0))


func progress_of(id: String) -> float:
	return clampf(float(progress.get(id, 0.0)) / hours_needed(id), 0.0, 1.0)


func experiment_done(id: String, exp_id: String) -> bool:
	return (experiments.get(id, []) as Array).has(exp_id)


## Warum geht ein Experiment gerade nicht? ("" = geht)
func experiment_blocker(exp: Dictionary) -> String:
	match String(exp.get("needs", "")):
		"power":
			if not PowerManager.has_power():
				return "braucht Strom (Generator)"
		"alien":
			if tier < 2:
				return "braucht das fremde Analysegerät"
	return ""


## Führt ein Experiment am eingelegten Fund aus. Gibt den Befund zurück ("" = ging nicht).
func run_experiment(exp_id: String) -> String:
	if slot == "":
		return ""
	for exp: Dictionary in analysis(slot).get("experiments", []):
		if exp.get("id", "") != exp_id:
			continue
		if experiment_blocker(exp) != "":
			return ""
		var list: Array = experiments.get(slot, [])
		if not list.has(exp_id):
			list.append(exp_id)
		experiments[slot] = list
		_apply_effect(String(exp.get("effect", "")))
		_check_complete(slot)
		changed.emit()
		return String(exp.get("text", ""))
	return ""


func _apply_effect(effect: String) -> void:
	var radio := get_tree().get_first_node_in_group("radio") as Node3D
	var cabin_pos := radio.global_position + Vector3(0, 0.2, 0) if radio else Vector3(2.4, 1.3, -0.7)
	match effect:
		"drain":
			PowerManager.fuel = maxf(PowerManager.fuel - 6.0, 0.0)
			get_tree().call_group("lamp", "flicker", 1.5)
			SoundBank.play_at(get_tree().current_scene, "static", cabin_pos, -4.0, 0.7)
		"noise":
			SoundBank.play_at(get_tree().current_scene, "signal", cabin_pos, 2.0, 1.4)
			EventBus.noise_made.emit(cabin_pos, 30.0)


func _process(_delta: float) -> void:
	var h := TimeManager.day * 24.0 + TimeManager.hour
	if _last_hour < 0.0 or h < _last_hour:
		_last_hour = h
		return
	var dh := h - _last_hour
	_last_hour = h
	if slot == "" or tier <= 0 or not has_power_for_analysis():
		PowerManager.set_consumer("analyzer", false)
		return
	var before := progress_of(slot)
	progress[slot] = minf(float(progress.get(slot, 0.0)) + dh * float(SPEED[tier]), hours_needed(slot))
	PowerManager.set_consumer("analyzer", true)
	if before < 1.0 and progress_of(slot) >= 1.0:
		var missing := _missing_experiments(slot)
		if missing > 0:
			EventBus.notify("Analyse „%s“ fast fertig – noch %d Experiment(e) am Gerät." % [analysis(slot).get("name", slot), missing], 4.0)
		changed.emit()
	_check_complete(slot)


func _missing_experiments(id: String) -> int:
	var n := 0
	for exp: Dictionary in analysis(id).get("experiments", []):
		if not experiment_done(id, exp.get("id", "")):
			n += 1
	return n


func _check_complete(id: String) -> void:
	if id == "" or done.has(id):
		return
	if progress_of(id) >= 1.0 and _missing_experiments(id) == 0:
		done.append(id)
		if slot == id:
			slot = ""
		PowerManager.set_consumer("analyzer", false)
		EventBus.notify("Analyse abgeschlossen: %s – am Analysegerät ans Tablet senden" % analysis(id).get("name", id), 4.5)
		SoundBank.play_ui(self, "signal", -8.0, 1.3)
		changed.emit()


# --- Ergebnisse ans Tablet ----------------------------------------------

## Ergebnisse, die am Analysegerät vorliegen, aber noch nicht ans Tablet gesendet wurden.
func unsent_results() -> Array:
	var out: Array = []
	for id: String in experiments:
		for eid: String in experiments[id]:
			var key := "%s/%s" % [id, eid]
			if not sent.has(key):
				out.append(key)
	for id: String in done:
		if not sent.has(id):
			out.append(id)
	return out


func is_sent(key: String) -> bool:
	return sent.has(key)


## Schickt alle vorliegenden Ergebnisse ans Tablet. Gibt die Anzahl zurück.
func send_results() -> int:
	var list := unsent_results()
	if list.is_empty():
		return 0
	sent.append_array(list)
	tablet_new += list.size()
	EventBus.notify("%d Ergebnis%s ans Tablet gesendet – auf der Couch im Alien-Archiv nachlesen" % [list.size(), "" if list.size() == 1 else "se"], 4.0)
	for l in data().get("links", {}):
		if can_link(l):
			EventBus.notify("Im Alien-Archiv lässt sich etwas verknüpfen …", 4.0)
			break
	changed.emit()
	return list.size()


func mark_tablet_seen() -> void:
	if tablet_new != 0:
		tablet_new = 0
		changed.emit()


# --- Verknüpfungen -----------------------------------------------------

func can_link(id: String) -> bool:
	if links_done.has(id):
		return false
	for n: String in link_def(id).get("needs", []):
		if not done.has(n) or not sent.has(n):
			return false
	return true


func link(id: String) -> bool:
	if not can_link(id):
		return false
	links_done.append(id)
	var def := link_def(id)
	var unlocks: Array = def.get("unlocks", [])
	if unlocks.is_empty():
		EventBus.notify("Neue Erkenntnis: %s" % def.get("name", id), 4.0)
	else:
		var names: PackedStringArray = []
		for r: String in unlocks:
			names.append(Inventory.display_name(r))
		EventBus.notify("Neue Erkenntnis: %s – Bauplan an der Werkbank: %s" % [def.get("name", id), ", ".join(names)], 5.0)
	changed.emit()
	return true


## Ist ein Rezept freigeschaltet? (Rezepte ohne "requires" immer)
func recipe_unlocked(recipe: Dictionary) -> bool:
	var req: String = recipe.get("requires", "")
	var bp: String = recipe.get("blueprint", "")
	return (req == "" or links_done.has(req)) and (bp == "" or blueprints.has(bp))


## Bauplan gefunden (Werkbank kennt das Rezept ab jetzt).
func learn_blueprint(id: String) -> bool:
	if blueprints.has(id):
		return false
	blueprints.append(id)
	changed.emit()
	return true


func read_note(id: String) -> void:
	if not notes.has(id):
		notes.append(id)
		changed.emit()


# --- Spielstand --------------------------------------------------------

func get_state() -> Dictionary:
	return {"tier": tier, "slot": slot, "progress": progress.duplicate(), "experiments": experiments.duplicate(true),
		"done": done.duplicate(), "links": links_done.duplicate(), "seen": seen.duplicate(), "notes": notes.duplicate(),
		"sent": sent.duplicate(), "tablet_new": tablet_new, "blueprints": blueprints.duplicate()}


func set_state(s: Dictionary) -> void:
	tier = int(s.get("tier", 0))
	slot = String(s.get("slot", ""))
	progress = (s.get("progress", {}) as Dictionary).duplicate()
	experiments = (s.get("experiments", {}) as Dictionary).duplicate(true)
	done = (s.get("done", []) as Array).duplicate()
	links_done = (s.get("links", []) as Array).duplicate()
	seen = (s.get("seen", []) as Array).duplicate()
	notes = (s.get("notes", []) as Array).duplicate()
	tablet_new = int(s.get("tablet_new", 0))
	blueprints = (s.get("blueprints", []) as Array).duplicate()
	if s.has("sent"):
		sent = (s.get("sent", []) as Array).duplicate()
	else:
		# alter Spielstand (vor dem Tablet-Archiv): alles Bisherige gilt als gesendet
		sent = []
		sent = unsent_results()
	_last_hour = -1.0
	changed.emit()
