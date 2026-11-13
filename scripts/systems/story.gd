extends Node
## Story (Story-Bibel: 5 Phasen) und der rote Faden („Spur“). Inhalte: data/story/story.json.
## Eine Phase beginnt, sobald eine Bedingung aus begins_any oder alle aus begins_all erfüllt sind (nur vorwärts).
## Spuren (steps): werden aktiv, wenn ihre start-Bedingungen gelten, und sind erledigt, wenn done gilt.
## Beim Start und beim Erledigen denkt Christian laut (Meldung), wer feststeckt, bekommt nach hint_days einen zweiten Hinweis.
## Anzeige: Tablet „Aufgaben“ (oben „Spur“) und Kreise auf der Karte (M). Andere Systeme fragen Story.phase ab.

signal phase_changed(phase: int)
signal steps_changed

var phase: int = 1
var steps_active: Dictionary = {}   ## id -> Aufgaben-Tag, an dem die Spur begann
var steps_done: Array = []          ## erledigte Spuren in der Reihenfolge
var hinted: Array = []              ## Spuren, für die der zweite Hinweis schon kam
var _check_t: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE


func data() -> Dictionary:
	return DataDB.load_json("res://data/story/story.json")


func phase_def(n: int) -> Dictionary:
	for p: Dictionary in data().get("phases", []):
		if int(p.get("id", 0)) == n:
			return p
	return {}


func step_def(id: String) -> Dictionary:
	for s: Dictionary in data().get("steps", []):
		if s.get("id", "") == id:
			return s
	return {}


func _process(delta: float) -> void:
	_check_t -= delta
	if _check_t > 0.0:
		return
	_check_t = 1.5
	if get_tree().get_first_node_in_group("player") == null:
		return   # Hauptmenü
	update(true)


## Alles einmal prüfen: Hinweise, Phasen, Spuren. announce = Gedanken/Meldungen zeigen.
func update(announce: bool) -> void:
	_check_beats()
	_check_phase()
	_check_steps(announce)


func _check_phase() -> void:
	var next := phase_def(phase + 1)
	if next.is_empty():
		return
	var any_ok := false
	for c: String in next.get("begins_any", []):
		if condition(c):
			any_ok = true
	var all: Array = next.get("begins_all", [])
	if any_ok or (not all.is_empty() and Tasks.check_all(all)):
		set_phase(phase + 1)


## Einmalige Story-Hinweise (story.json "beats"), z. B. der hohle Boden in Stefanies Büro.
func _check_beats() -> void:
	for b: Dictionary in data().get("beats", []):
		var flag := String(b.get("flag", "beat_" + String(b.get("id", ""))))
		if Tasks.flags.has(flag) or not condition(String(b.get("when", ""))):
			continue
		if TimeManager.hour < float(b.get("hour", 0.0)) or TimeManager.is_night():
			continue
		Tasks.flag(flag)
		if String(b.get("note", "")) != "":
			Research.read_note(String(b["note"]))
		if String(b.get("text", "")) != "":
			EventBus.notify(String(b["text"]), 6.0)


func _check_steps(announce: bool) -> void:
	var dirty := false
	for s: Dictionary in data().get("steps", []):
		var id := String(s.get("id", ""))
		if steps_done.has(id):
			continue
		var fresh := false
		if not steps_active.has(id):
			if not Tasks.check_all(s.get("start", [])):
				continue
			steps_active[id] = Tasks.task_day()
			fresh = true
			dirty = true
			if announce:
				Tasks.unseen += 1
		if step_finished(s):
			steps_active.erase(id)
			steps_done.append(id)
			dirty = true
			if announce:
				_say(String(s.get("finish", "")) if s.has("finish") else "Spur erledigt: " + String(s.get("title", id)), 0.0)
				SoundBank.play_ui(self, "menu_click", -8.0, 0.8)
			continue
		if fresh and announce:
			var t := String(s.get("thought", ""))
			if t == "":
				t = ("Neue Spur: " if s.get("main", false) else "Nebenspur: ") + String(s.get("title", id))
			_say(t + "  (Tablet)", 0.0)
		# feststecken: zweiter, deutlicherer Hinweis
		var hd := int(s.get("hint_days", 0))
		if announce and hd > 0 and not hinted.has(id) and Tasks.task_day() - int(steps_active[id]) >= hd \
				and not TimeManager.is_night():
			hinted.append(id)
			dirty = true
			var who := "Ilse über Funk: " if Tasks.flags.has("mast_repaired") else ""
			_say(who + String(s.get("hint", "")), 0.0)
	if dirty:
		steps_changed.emit()


## Gedanke am Bildschirmrand – lange Texte bleiben länger stehen.
func _say(text: String, seconds: float) -> void:
	if text.strip_edges() == "":
		return
	EventBus.notify(text, seconds if seconds > 0.0 else clampf(text.length() / 15.0, 4.0, 10.0))


func step_finished(s: Dictionary) -> bool:
	if s.has("done_count"):
		var dc: Dictionary = s["done_count"]
		var n := 0
		for c: String in dc.get("of", []):
			if Tasks.check(c):
				n += 1
		return n >= int(dc.get("need", 1))
	var d: Array = s.get("done", [])
	return not d.is_empty() and Tasks.check_all(d)


## Fortschritt einer Zähl-Spur (z. B. 2 / 4 Meldekästen), sonst leer.
func step_progress(s: Dictionary) -> String:
	if not s.has("done_count"):
		return ""
	var dc: Dictionary = s["done_count"]
	var n := 0
	for c: String in dc.get("of", []):
		if Tasks.check(c):
			n += 1
	return "%d / %d" % [mini(n, int(dc.get("need", 1))), int(dc.get("need", 1))]


## Aktive Spuren in der Reihenfolge der Datei (Hauptspuren zuerst).
func active_steps() -> Array:
	var main: Array = []
	var side: Array = []
	for s: Dictionary in data().get("steps", []):
		if steps_active.has(s.get("id", "")):
			(main if s.get("main", false) else side).append(s)
	return main + side


func done_step_defs() -> Array:
	var out: Array = []
	for id: String in steps_done:
		var s := step_def(id)
		if not s.is_empty():
			out.append(s)
	return out


## War der zweite Hinweis schon da? (Tablet zeigt ihn dann mit an.)
func hint_shown(id: String) -> bool:
	return hinted.has(id)


## Kreise für die Karte: [{pos: Vector2, label, main}]
func map_targets() -> Array:
	var out: Array = []
	for s: Dictionary in active_steps():
		var main := bool(s.get("main", false))
		if s.has("targets"):
			for t: Dictionary in s["targets"]:
				if not Tasks.check(String(t.get("done", ""))):
					out.append({"pos": target_pos(String(t["place"])), "label": _place_name(String(t["place"])), "main": main})
		elif s.has("target"):
			out.append({"pos": target_pos(String(s["target"])), "label": String(s.get("title", "")), "main": main})
	return out


static func target_pos(id: String) -> Vector2:
	if id == "hut":
		return Vector2.ZERO
	return WorldMap.place_pos(id)


static func _place_name(id: String) -> String:
	return String(WorldMap.places()[id]["name"]) if WorldMap.places().has(id) else id


## Bedingungen: wie in tasks.json (Tasks.check), z. B. flag:X, link:X, note:X, step:X, day>=N
static func condition(c: String) -> bool:
	if c == "":
		return false
	return Tasks.check(c)


func set_phase(n: int) -> void:
	if n <= phase:
		return
	phase = n
	var text := String(phase_def(n).get("text", ""))
	if text != "":
		EventBus.notify(text, 7.0)
	Tasks.flag("story_phase_%d" % n)
	phase_changed.emit(n)
	print("[Story] Phase ", n, ": ", phase_def(n).get("name", ""))


func get_state() -> Dictionary:
	return {"phase": phase, "active": steps_active.duplicate(), "done": steps_done.duplicate(), "hinted": hinted.duplicate()}


func set_state(s: Dictionary) -> void:
	phase = int(s.get("phase", 1))
	steps_active = (s.get("active", {}) as Dictionary).duplicate()
	steps_done = (s.get("done", []) as Array).duplicate()
	hinted = (s.get("hinted", []) as Array).duplicate()
	# Alter Spielstand ohne Spuren: was schon stimmt, still nachziehen (keine Gedanken-Flut nach dem Laden)
	if not s.has("active"):
		update(false)
	steps_changed.emit()
