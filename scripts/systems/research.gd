extends Node
## Forschung und Alien-Archiv (GDD 12). Inhalte in data/research/research.json.
##
## Ablauf: Fund an einer Station einlegen → Projekt läuft (Spielstunden, manche Stationen brauchen Strom)
## + aktive Experimente → fertige Projekte ans Tablet senden → zwei passende Ergebnisse verknüpfen →
## Erkenntnis, ggf. neue Baupläne (unlocks) oder Fähigkeiten (grants).
##
## Stationen: device = Analysegerät am Funktisch (Stufe 1 = umgebautes Funkgerät mit W-17, 2 = fremdes Gerät),
## dazu das Labor im Bad (bench, microscope, terrarium, shield, screen). Jede Station hat einen Platz,
## alle laufen gleichzeitig. Lebende Proben verderben nicht, können aber ausbrechen (LabEscape).
##
## Fremde Dinge machen sichtbar: signature() zählt, was du trägst, was nachts im Labor läuft und kurze
## Ausschläge (Experimente). Der ThreatDirector und der Sucher reagieren darauf.

signal changed
signal escaped(project: String, kind: String)

const SPEED := {1: 1.0, 2: 2.0}
const LAB_STATIONS := ["bench", "microscope", "terrarium", "shield", "screen"]

var tier: int = 0
var stations: Dictionary = {"device": ""}  ## Station -> laufendes Projekt ("" = leer)
## Platz im Analysegerät (alter Name, gleichbedeutend mit stations["device"])
var slot: String:
	get:
		return String(stations.get("device", ""))
	set(v):
		stations["device"] = v
var progress: Dictionary = {}      ## Projekt -> erledigte Spielstunden
var experiments: Dictionary = {}   ## Projekt -> Array erledigter Experiment-IDs
var done: Array = []               ## fertige Projekte
var links_done: Array = []         ## gefundene Verknüpfungen
var seen: Array = []               ## jemals aufgehobene Funde (für das Archiv)
var notes: Array = []              ## gelesene Notizen
var blueprints: Array = []         ## in der Welt gefundene Baupläne
var w17_in_device: bool = false    ## W-17 steckt im umgebauten Funkgerät (ohne W-17 liest es nichts)
var sent: Array = []               ## ans Tablet gesendete Ergebnisse: "projekt" bzw. "projekt/experiment"
var tablet_new: int = 0            ## neue, auf dem Tablet noch nicht angesehene Ergebnisse
# Labor im Bad
var lab_offered: bool = false      ## Christian hat beschlossen, das Bad umzubauen (Bedingung erfüllt)
var lab_built: bool = false
var lab_stations: Array = []       ## eingebaute Laborplätze
var charger_built: bool = false
var charger_hours: float = 0.0
var charger_ready: int = 0         ## geladene Zellen in der Ladeschale
var escapes: int = 0               ## wie oft schon etwas ausgebrochen ist
var lab_bloom: bool = false        ## Wucherung im Bad (Ausbruch „bloom“), bis man sie abkratzt
# Sichtbarkeit und Hilfsmittel
var flare_until: float = -1.0      ## bis zu dieser Spielstunde strahlt ein Experiment nach
var buffs: Dictionary = {}         ## z. B. "scent" -> bis Spielstunde

var _last_hour: float = -1.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_rng.randomize()
	Inventory.changed.connect(_on_inventory_changed)


func data() -> Dictionary:
	return DataDB.load_json("res://data/research/research.json")


func analysis(id: String) -> Dictionary:
	return data().get("analyses", {}).get(id, {})


func link_def(id: String) -> Dictionary:
	return data().get("links", {}).get(id, {})


func lab_def() -> Dictionary:
	return data().get("lab", {})


func station_of(id: String) -> String:
	return String(analysis(id).get("station", "device"))


## Zu welchem Projekt am Analysegerät gehört ein Fund? (sonst das erste passende Projekt überhaupt)
func analysis_for_find(find: String) -> String:
	var all: Dictionary = data().get("analyses", {})
	var other := ""
	for id in all:
		if all[id].get("find", "") != find:
			continue
		if String(all[id].get("station", "device")) == "device":
			return id
		if other == "":
			other = id
	return other


func _on_inventory_changed() -> void:
	for id in Inventory.items:
		if DataDB.item(id).get("category", "") == "Fund" and not seen.has(id):
			seen.append(id)
			if id != "alien_analyzer":
				EventBus.notify("Neuer Fund: %s – im Alien-Archiv auf dem Tablet vermerkt" % Inventory.display_name(id), 3.5)
			changed.emit()


func now() -> float:
	return TimeManager.day * 24.0 + TimeManager.hour


# --- Stationen ---------------------------------------------------------

func has_power_for_analysis() -> bool:
	return station_powered("device")


## Kann das Gerät fremde Proben lesen? Das umgebaute Funkgerät nur mit W-17, das fremde Gerät immer.
func device_reads() -> bool:
	return tier >= 2 or (tier >= 1 and w17_in_device)


func set_tier(t: int) -> void:
	if t > tier:
		tier = t
		changed.emit()


func device_name() -> String:
	match tier:
		1: return "Analysegerät (umgebautes Funkgerät)"
		2: return "Fremdes Analysegerät"
	return "kein Analysegerät"


func station_name(st: String) -> String:
	if st == "device":
		return device_name()
	return String(lab_def().get("stations", {}).get(st, {}).get("name", st))


func station_built(st: String) -> bool:
	if st == "device":
		return tier >= 1
	return lab_built and lab_stations.has(st)


func station_powered(st: String) -> bool:
	if st == "device":
		return tier >= 2 or PowerManager.has_power()
	if not bool(lab_def().get("stations", {}).get(st, {}).get("power", false)):
		return true
	return PowerManager.has_power()


## Läuft die Station gerade? ("" = ja, sonst der Grund)
func station_blocker(st: String) -> String:
	if not station_built(st):
		return "nicht gebaut"
	if not station_powered(st):
		return "kein Strom"
	if st == "device" and not device_reads():
		return "W-17 fehlt im Gerät"
	return ""


func station_speed(st: String) -> float:
	return float(SPEED.get(tier, 1.0)) if st == "device" else 1.0


## An welcher Station läuft ein Projekt gerade? ("" = nirgends)
func running_at(id: String) -> String:
	for st: String in stations:
		if stations[st] == id:
			return st
	return ""


func requirement_done(r: String) -> bool:
	return done.has(r) or links_done.has(r)


func requirements_met(id: String) -> bool:
	for r: String in analysis(id).get("requires", []):
		if not requirement_done(r):
			return false
	return true


## Projekte, die man an dieser Station beginnen könnte (Voraussetzungen erfüllt, noch nicht fertig).
func available_projects(st: String) -> Array:
	var out: Array = []
	var all: Dictionary = data().get("analyses", {})
	for id: String in all:
		if String(all[id].get("station", "device")) != st or done.has(id) or running_at(id) != "":
			continue
		if requirements_met(id):
			out.append(id)
	return out


## Altes Einlegen am Analysegerät: Fund -> passendes Projekt.
func insert(find: String) -> bool:
	for id: String in available_projects("device"):
		if analysis(id).get("find", "") == find:
			return insert_project("device", id)
	return false


func insert_project(st: String, id: String) -> bool:
	if not station_built(st) or String(stations.get(st, "")) != "" or done.has(id) or station_of(id) != st:
		return false
	if not requirements_met(id) or running_at(id) != "":
		return false
	var find: String = analysis(id).get("find", "")
	if find != "" and Inventory.count(find) <= 0:
		return false
	if find != "":
		Inventory.remove(find, 1)
	stations[st] = id
	changed.emit()
	return true


## Fund wieder herausnehmen (Fortschritt bleibt erhalten).
func take_out(st: String = "device") -> void:
	var id := String(stations.get(st, ""))
	if id == "":
		return
	var find: String = analysis(id).get("find", "")
	if find != "" and Inventory.add(find, 1) <= 0:
		EventBus.notify("Zu schwer – du kannst den Fund nicht tragen.", 2.0)
		return
	stations[st] = ""
	PowerManager.set_consumer("research_" + st, false)
	changed.emit()


func hours_needed(id: String) -> float:
	return float(analysis(id).get("hours", 2.0))


func progress_of(id: String) -> float:
	return clampf(float(progress.get(id, 0.0)) / hours_needed(id), 0.0, 1.0)


func hours_left(id: String) -> float:
	var st := running_at(id)
	var speed := station_speed(st if st != "" else station_of(id))
	return maxf(hours_needed(id) * (1.0 - progress_of(id)) / speed, 0.0)


func experiment_done(id: String, exp_id: String) -> bool:
	return (experiments.get(id, []) as Array).has(exp_id)


## Warum geht ein Experiment gerade nicht? ("" = geht)
func experiment_blocker(exp: Dictionary, st: String = "device") -> String:
	var need := String(exp.get("needs", ""))
	if need.begins_with("item:"):
		var it := need.substr(5)
		if Inventory.count(it) <= 0:
			return "braucht: %s" % Inventory.display_name(it)
		return ""
	if need.begins_with("built:"):
		var s := need.substr(6)
		return "" if station_built(s) else "braucht: %s im Labor" % station_name(s)
	match need:
		"power":
			if not PowerManager.has_power() and not (st == "device" and tier >= 2):
				return "braucht Strom (Generator)"
		"alien":
			if tier < 2:
				return "braucht das fremde Analysegerät"
		"heat":
			if not heat_available():
				return "braucht Feuer (Kamin/Ofen) oder den Gaskocher im Labor"
		"water":
			if not lab_built:
				return "braucht fließendes Wasser (Labor)"
		"night":
			if not TimeManager.is_night():
				return "geht nur nachts"
		"day":
			if TimeManager.is_night():
				return "geht nur bei Tageslicht"
	return ""


func heat_available() -> bool:
	if lab_built:
		return true  # Gaskocher auf der Arbeitsplatte
	for h in get_tree().get_nodes_in_group("heat_source"):
		if h.has_method("heats_cabin") and h.call("heats_cabin"):
			return true
	return false


## Führt ein Experiment am Projekt einer Station aus. Gibt den Befund zurück ("" = ging nicht).
func run_experiment(exp_id: String, st: String = "device") -> String:
	var id := String(stations.get(st, ""))
	if id == "":
		return ""
	for exp: Dictionary in analysis(id).get("experiments", []):
		if exp.get("id", "") != exp_id:
			continue
		if experiment_blocker(exp, st) != "" or experiment_done(id, exp_id):
			return ""
		var need := String(exp.get("needs", ""))
		if need.begins_with("item:"):
			Inventory.remove(need.substr(5), 1)
		var list: Array = experiments.get(id, [])
		list.append(exp_id)
		experiments[id] = list
		_apply_effect(String(exp.get("effect", "")), st)
		_check_complete(id)
		changed.emit()
		return String(exp.get("text", ""))
	return ""


func _station_pos(st: String) -> Vector3:
	if st != "device":
		var lab := get_tree().get_first_node_in_group("lab") as Node3D
		if lab and lab.has_method("station_point"):
			return lab.call("station_point", st)
	var radio := get_tree().get_first_node_in_group("radio") as Node3D
	return radio.global_position + Vector3(0, 0.2, 0) if radio else Vector3(2.4, 1.3, -0.7)


func _apply_effect(effect: String, st: String = "device") -> void:
	var pos := _station_pos(st)
	match effect:
		"drain":
			PowerManager.fuel = maxf(PowerManager.fuel - 6.0, 0.0)
			get_tree().call_group("lamp", "flicker", 1.5)
			SoundBank.play_at(get_tree().current_scene, "static", pos, -4.0, 0.7)
		"noise":
			SoundBank.play_at(get_tree().current_scene, "signal", pos, 2.0, 1.4)
			EventBus.noise_made.emit(pos, 30.0)
		"signal":
			# kurzer, starker Ausschlag: draußen hat man das gesehen
			flare_until = now() + float(lab_def().get("flare_hours", 10.0))
			SoundBank.play_at(get_tree().current_scene, "signal", pos, 0.0, 0.6)
			EventBus.notify("Ein greller Ton, dann Stille. Das hat man draußen bemerkt.", 3.5)
		"hurt":
			var p := get_tree().get_first_node_in_group("player")
			if p:
				p.set("health", maxf(float(p.get("health")) - 8.0, 5.0))
			EventBus.screen_shake.emit(0.15)
		"escape":
			if _rng.randf() < 0.5:
				escape(st)


func _process(_delta: float) -> void:
	var h := now()
	if _last_hour < 0.0 or h < _last_hour:
		_last_hour = h
		return
	var dh := h - _last_hour
	if dh <= 0.0:
		return
	_last_hour = h
	_check_lab_offer()
	for st: String in stations.keys():
		var id := String(stations[st])
		if id == "" or station_blocker(st) != "":
			PowerManager.set_consumer("research_" + st, false)
			continue
		var before := progress_of(id)
		progress[id] = minf(float(progress.get(id, 0.0)) + dh * station_speed(st), hours_needed(id))
		if bool(lab_def().get("stations", {}).get(st, {}).get("power", st == "device")):
			PowerManager.set_consumer("research_" + st, true)
		if before < 1.0 and progress_of(id) >= 1.0:
			var missing := _missing_experiments(id)
			if missing > 0:
				EventBus.notify("„%s“ fast fertig – noch %d Experiment(e) an %s." % [analysis(id).get("name", id), missing, station_name(st)], 4.0)
			changed.emit()
		_check_complete(id)
		# lebende Proben: ab und zu bricht etwas aus
		var a := analysis(id)
		if bool(a.get("living", false)) and stations.get(st, "") == id and not done.has(id):
			if _rng.randf() < float(a.get("escape_per_day", 0.0)) / 24.0 * dh:
				escape(st)
	_update_charger(dh)


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
		Tasks.flag("done_" + id)
		var st := running_at(id)
		if st != "":
			stations[st] = ""
			PowerManager.set_consumer("research_" + st, false)
		EventBus.notify("Abgeschlossen: %s – am Gerät ans Tablet senden" % analysis(id).get("name", id), 4.5)
		SoundBank.play_ui(self, "signal", -8.0, 1.3)
		changed.emit()


# --- Ausbrüche lebender Proben -----------------------------------------

## Eine lebende Probe bricht aus. Was passiert, steht in research.json (escape) und LabEscape.
func escape(st: String) -> void:
	var id := String(stations.get(st, ""))
	if id == "" or done.has(id):
		return
	var kind := String(analysis(id).get("escape", "crawl"))
	escapes += 1
	if kind == "crawl":
		# Probe ist weg (Fortschritt halbiert), liegt irgendwo im Haus und muss eingefangen werden
		stations[st] = ""
		progress[id] = float(progress.get(id, 0.0)) * 0.5
		PowerManager.set_consumer("research_" + st, false)
	LabEscape.happen(get_tree(), id, kind, _station_pos(st))
	escaped.emit(id, kind)
	changed.emit()


# --- Labor im Bad ------------------------------------------------------

func _check_lab_offer() -> void:
	if lab_offered:
		return
	var u: Dictionary = lab_def().get("unlock", {})
	var sent_done := done.filter(func(x: String) -> bool: return sent.has(x)).size()
	if TimeManager.day >= int(u.get("day", 4)) and sent_done >= int(u.get("sent", 3)):
		offer_lab()


func offer_lab() -> void:
	if lab_offered:
		return
	lab_offered = true
	Tasks.flag("lab_offered")
	read_note("lab_decision")
	EventBus.notify(String(lab_def().get("unlock_text", "")), 7.0)
	changed.emit()


func missing_needs(needs: Dictionary) -> String:
	var miss: PackedStringArray = []
	for it: String in needs:
		var have := Inventory.count(it)
		if have < int(needs[it]):
			miss.append("%s %d/%d" % [Inventory.display_name(it), have, int(needs[it])])
	return ", ".join(miss)


func _consume(needs: Dictionary) -> void:
	for it: String in needs:
		Inventory.remove(it, int(needs[it]))


func build_lab() -> String:
	if lab_built:
		return ""
	if not lab_offered:
		return "Noch braucht es kein Labor."
	var needs: Dictionary = lab_def().get("needs", {})
	var miss := missing_needs(needs)
	if miss != "":
		return "Es fehlt: " + miss
	_consume(needs)
	lab_built = true
	for st: String in lab_def().get("stations", {}):
		if bool(lab_def()["stations"][st].get("built_with_lab", false)) and not lab_stations.has(st):
			lab_stations.append(st)
			stations[st] = ""
	Tasks.flag("lab_built")
	EventBus.notify("Das Bad ist jetzt ein Labor. Weitere Plätze baust du an der Arbeitsplatte ein.", 4.5)
	changed.emit()
	return ""


## Warum kann man eine Station (noch) nicht einbauen? ("" = geht)
func station_build_blocker(st: String) -> String:
	if not lab_built:
		return "erst das Labor einrichten"
	if lab_stations.has(st):
		return "schon eingebaut"
	var def: Dictionary = lab_def().get("stations", {}).get(st, {})
	var any: Array = def.get("requires_any", [])
	if not any.is_empty() and not any.any(func(r: String) -> bool: return requirement_done(r)):
		var names: PackedStringArray = []
		for r: String in any:
			names.append(String(analysis(r).get("name", link_def(r).get("name", r))))
		return "braucht erst eine Erkenntnis: " + " oder ".join(names)
	var miss := missing_needs(def.get("needs", {}))
	return ("Es fehlt: " + miss) if miss != "" else ""


func build_station(st: String) -> String:
	var b := station_build_blocker(st)
	if b != "":
		return b
	_consume(lab_def()["stations"][st].get("needs", {}))
	lab_stations.append(st)
	stations[st] = ""
	Tasks.flag("lab_" + st)
	EventBus.notify("%s eingebaut." % station_name(st), 3.0)
	changed.emit()
	return ""


func charger_blocker() -> String:
	var def: Dictionary = lab_def().get("charger", {})
	if charger_built:
		return "schon gebaut"
	if not lab_built:
		return "erst das Labor einrichten"
	if not has_grant("charger"):
		return "braucht erst eine Erkenntnis"
	var miss := missing_needs(def.get("needs", {}))
	return ("Es fehlt: " + miss) if miss != "" else ""


func build_charger() -> String:
	var b := charger_blocker()
	if b != "":
		return b
	_consume(lab_def()["charger"].get("needs", {}))
	charger_built = true
	EventBus.notify("Die Ladeschale steht im Labor.", 3.0)
	changed.emit()
	return ""


func _update_charger(dh: float) -> void:
	if not charger_built or charger_ready >= 2:
		return
	charger_hours += dh
	if charger_hours >= float(lab_def().get("charger", {}).get("hours", 48.0)):
		charger_hours = 0.0
		charger_ready += 1
		EventBus.notify("In der Ladeschale im Labor liegt eine geladene Energiezelle.", 4.0)
		changed.emit()


## Wucherung im Bad abkratzen – gibt Leuchtpilz.
func clean_bloom() -> void:
	if not lab_bloom:
		return
	lab_bloom = false
	PowerManager.set_consumer("lab_bloom", false)
	Inventory.add("glow_fungus", 2)
	EventBus.notify("Abgekratzt. Zwei Hände voll Leuchtpilz – immerhin.", 3.0)
	changed.emit()


func take_charged_cell() -> bool:
	if charger_ready <= 0 or Inventory.add("energy_cell", 1) <= 0:
		return false
	charger_ready -= 1
	changed.emit()
	return true


# --- Sichtbarkeit und Hilfsmittel --------------------------------------

## Wie stark du gerade für sie „leuchtest“ (0 = gar nicht, 1 = deutlich, mehr = grell).
func signature() -> float:
	return carried_signature() + home_signature()


## Für die Planung der kommenden Nacht (tagsüber): so, als wäre schon Nacht.
func expected_signature() -> float:
	return carried_signature() + home_signature(true)


## Was du am Körper trägst (Fremdes, Alien-Werkzeuge). Die Dämpfertasche schluckt einen Teil davon.
func carried_signature() -> float:
	var s := 0.0
	for id: String in Inventory.items:
		var v := float(DataDB.item(id).get("signature", 0.0))
		if v > 0.0:
			s += v * minf(float(Inventory.count(id)), 3.0)
	if Inventory.count("signature_pouch") > 0:
		s *= float(lab_def().get("pouch_factor", 0.4))
	return s


## Was zu Hause strahlt: Projekte, die nachts laufen (nicht im Abschirmkasten), die Ladeschale, Ausschläge.
func home_signature(assume_night: bool = false) -> float:
	var s := 0.0
	if assume_night or TimeManager.is_night():
		for st: String in stations:
			var id := String(stations[st])
			if id != "" and st != "shield":
				s += float(analysis(id).get("signature", 0.0))
		if charger_built:
			s += float(lab_def().get("charger", {}).get("signature", 0.3))
	if now() < flare_until:
		s += 0.5
	return s


## Wert eines Forschungs-Werkzeugs aus research.json "gadgets".
func gadget(id: String, key: String, default: Variant) -> Variant:
	return data().get("gadgets", {}).get(id, {}).get(key, default)


func has_grant(g: String) -> bool:
	for l: String in links_done:
		if (link_def(l).get("grants", []) as Array).has(g):
			return true
	return false


func add_buff(b: String, hours: float) -> void:
	buffs[b] = maxf(float(buffs.get(b, 0.0)), now() + hours)
	changed.emit()


func buff_active(b: String) -> bool:
	return now() < float(buffs.get(b, -1.0))


# --- Ergebnisse ans Tablet ----------------------------------------------

## Ergebnisse, die an den Geräten vorliegen, aber noch nicht ans Tablet gesendet wurden.
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
	_check_lab_offer()
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
	Tasks.flag("link_" + id.trim_prefix("link_"))
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
	return {"tier": tier, "stations": stations.duplicate(), "progress": progress.duplicate(), "experiments": experiments.duplicate(true),
		"done": done.duplicate(), "links": links_done.duplicate(), "seen": seen.duplicate(), "notes": notes.duplicate(),
		"sent": sent.duplicate(), "tablet_new": tablet_new, "blueprints": blueprints.duplicate(), "w17": w17_in_device,
		"lab_offered": lab_offered, "lab_built": lab_built, "lab_stations": lab_stations.duplicate(),
		"charger": charger_built, "charger_hours": charger_hours, "charger_ready": charger_ready, "escapes": escapes, "bloom": lab_bloom,
		"flare_until": flare_until, "buffs": buffs.duplicate()}


func set_state(s: Dictionary) -> void:
	tier = int(s.get("tier", 0))
	if s.has("stations"):
		stations = (s["stations"] as Dictionary).duplicate()
	else:
		stations = {"device": String(s.get("slot", ""))}
	if not stations.has("device"):
		stations["device"] = ""
	progress = (s.get("progress", {}) as Dictionary).duplicate()
	experiments = (s.get("experiments", {}) as Dictionary).duplicate(true)
	done = (s.get("done", []) as Array).duplicate()
	links_done = (s.get("links", []) as Array).duplicate()
	seen = (s.get("seen", []) as Array).duplicate()
	notes = (s.get("notes", []) as Array).duplicate()
	tablet_new = int(s.get("tablet_new", 0))
	blueprints = (s.get("blueprints", []) as Array).duplicate()
	w17_in_device = bool(s.get("w17", tier >= 1))
	lab_offered = bool(s.get("lab_offered", false))
	lab_built = bool(s.get("lab_built", false))
	lab_stations = (s.get("lab_stations", []) as Array).duplicate()
	for st: String in lab_stations:
		if not stations.has(st):
			stations[st] = ""
	charger_built = bool(s.get("charger", false))
	charger_hours = float(s.get("charger_hours", 0.0))
	charger_ready = int(s.get("charger_ready", 0))
	escapes = int(s.get("escapes", 0))
	lab_bloom = bool(s.get("bloom", false))
	PowerManager.set_consumer("lab_bloom", lab_bloom)
	flare_until = float(s.get("flare_until", -1.0))
	buffs = (s.get("buffs", {}) as Dictionary).duplicate()
	if s.has("sent"):
		sent = (s.get("sent", []) as Array).duplicate()
	else:
		# alter Spielstand (vor dem Tablet-Archiv): alles Bisherige gilt als gesendet
		sent = []
		sent = unsent_results()
	_last_hour = -1.0
	changed.emit()
