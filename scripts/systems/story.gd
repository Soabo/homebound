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
## Endspurt (Phase 5): Tag, an dem der Schacht geöffnet wurde (-1 = zu). Ab dann läuft die Frist (endings.json endgame.nights).
var shaft_open_day: int = -1
var warned: Array = []              ## schon gezeigte Endspurt-Warnungen (Anzahl Nächte als Text)
var ending_running: bool = false


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
	_check_deadline()
	_check_packing()


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
				Journal.step(s)
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


# --- Mehrtagesmarsch: Packliste und Warnung beim Losgehen --------------------------

var _packing_warned_day: int = -1


func packing_def() -> Dictionary:
	return data().get("packing", {})


## Aktive Spur mit einem Ziel, das man nur mit Übernachtung erreicht (map.json ring multi)? Rückgabe: Ziel-ID oder "".
func multi_trip_target() -> String:
	for s: Dictionary in active_steps():
		var ids: Array = []
		if s.has("target"):
			ids.append(s["target"])
		ids.append_array(s.get("targets", []))
		for v: Variant in ids:
			var id := str(v)
			var pl: Dictionary = WorldMap.places().get(id, {})
			if pl.get("ring", "") == "multi" and not Tasks.flags.has("visit_" + id):
				return id
	return ""


## Packliste mit Stand: [{label, have, need, ok, optional}]
func packing_status() -> Array:
	var out: Array = []
	for it: Dictionary in packing_def().get("items", []):
		var have := 0
		var need := 1
		if it.has("need"):
			var ok_all := true
			for id: String in it["need"]:
				need = int(it["need"][id])
				have = Inventory.count(id)
				if have < need:
					ok_all = false
			out.append({"label": it["label"], "have": have, "need": need, "ok": ok_all, "optional": bool(it.get("optional", false))})
			continue
		if it.has("any"):
			for id: String in it["any"]:
				have = maxi(have, Inventory.count(id))
		elif it.has("food"):
			need = int(it["food"])
			have = Inventory.count_food()
		elif it.has("water"):
			need = int(it["water"])
			have = Inventory.count_water()
		elif it.has("fuel"):
			need = int(it["fuel"])
			have = Inventory.count_fuel()
		out.append({"label": it["label"], "have": have, "need": need, "ok": have >= need, "optional": bool(it.get("optional", false))})
	return out


func _check_packing() -> void:
	var target := multi_trip_target()
	if target == "":
		return
	var pk := packing_def()
	# Erstes Mal: klare Ansage, dass es ein Mehrtagesmarsch wird
	if not Tasks.flags.has("packing_intro"):
		Tasks.flag("packing_intro")
		EventBus.notify(String(pk.get("intro", "")), 10.0)
		return
	# Beim Losgehen: einmal am Tag warnen, wenn etwas fehlt oder es schon spät ist
	var p := get_tree().get_first_node_in_group("player") as Node3D
	if p == null or _packing_warned_day == TimeManager.day:
		return
	var d := Vector2(p.global_position.x, p.global_position.z).length()
	if d < float(pk.get("leave_distance", 70.0)) or d > float(pk.get("leave_distance", 70.0)) + 60.0:
		return
	var missing: PackedStringArray = []
	for it: Dictionary in packing_status():
		if not it["ok"] and not it["optional"]:
			missing.append(String(it["label"]))
	if not missing.is_empty():
		_packing_warned_day = TimeManager.day
		EventBus.notify(String(pk.get("missing_text", "%s")) % ", ".join(missing), 8.0)
	elif TimeManager.hour >= float(pk.get("late_hour", 12.0)) and not TimeManager.is_night():
		_packing_warned_day = TimeManager.day
		EventBus.notify(String(pk.get("late_text", "")), 7.0)


# --- Endspurt und Enden ---------------------------------------------------------

func endings_data() -> Dictionary:
	return DataDB.load_json("res://data/story/endings.json")


func endgame_nights() -> int:
	return int(endings_data().get("endgame", {}).get("nights", 5))


## Schacht öffnen: ab jetzt läuft die Frist.
func open_shaft() -> void:
	if shaft_open_day >= 0:
		return
	shaft_open_day = TimeManager.day
	warned.clear()
	Tasks.flag("shaft_open")
	EventBus.notify("Die Bretter sind weg, die Winde sitzt. Von unten kommt warme Luft – und ein Ton wie ein Atem. Ich habe vielleicht fünf Nächte.", 8.0)


## Verbleibende Nächte bis »Zu spät« (-1 = Schacht noch zu). Die Nacht von Tag X zählt zu Tag X.
func nights_left() -> int:
	if shaft_open_day < 0:
		return -1
	return maxi(shaft_open_day + endgame_nights() - TimeManager.day, 0)


## 0..1: wie weit die Saat ist (für Himmel, Nebel, Funk). 0 = Schacht zu.
func saat_progress() -> float:
	if shaft_open_day < 0:
		return 0.0
	var total := float(endgame_nights())
	var passed := float(TimeManager.day - shaft_open_day) + clampf((TimeManager.hour - 8.0) / 24.0, 0.0, 1.0)
	return clampf(passed / total, 0.0, 1.0)


func _check_deadline() -> void:
	if shaft_open_day < 0 or ending_running:
		return
	var eg: Dictionary = endings_data().get("endgame", {})
	var left := nights_left()
	# Morgens eine Warnung je verbleibender Nacht
	var key := str(left)
	if TimeManager.hour >= 8.0 and not warned.has(key) and (eg.get("warn", {}) as Dictionary).has(key):
		warned.append(key)
		EventBus.notify(String(eg["warn"][key]), 9.0)
	if left <= 0:
		if TimeManager.hour >= 8.0 and not warned.has("last"):
			warned.append("last")
			EventBus.notify(String(eg.get("last_warning", "")), 10.0)
		if TimeManager.hour >= float(eg.get("late_hour", 23.0)) or TimeManager.day > shaft_open_day + endgame_nights():
			start_ending("zu_spaet", false)


## Welche Wege an der Fassung im Knoten offen sind (Story-Bibel »Die Enden«). Rückgabe: Liste von
## {id, label, ending, ok, why} – ok = false heißt: sichtbar, aber es fehlt noch etwas (why).
func socket_options() -> Array:
	var has_w17 := Inventory.count("w17") > 0
	var shutdown_known := Tasks.check("note:ast_abschaltfolge1") and Tasks.check("note:tunnel_abschaltfolge2")
	var shutdown_ready := shutdown_known and Tasks.check("ws:structure_off") and Tasks.check("ws:source_dead")
	var mappe := Tasks.check("note:stef_mappe")
	var ilse := Tasks.check("flag:mast_repaired")
	var code := Tasks.check("note:ast_schutzstatus") and mappe
	var overload := Inventory.count("overload_module") > 0 and Inventory.count("blast_charge") > 0
	var out: Array = []
	if shutdown_known:
		out.append({"id": "shutdown", "label": "Den Knoten abschalten", "ending": "stille", "ok": shutdown_ready,
			"why": "Erst die Säulen der Struktur abschalten und die Leitung in der Höhle trennen."})
	if shutdown_known and mappe:
		out.append({"id": "shutdown_send", "label": "Abschalten und Stefanies Mappe über den Knoten senden",
			"ending": "gehoert" if ilse else "abgeholt", "ok": shutdown_ready,
			"why": "Erst die Säulen der Struktur abschalten und die Leitung in der Höhle trennen."})
	if mappe:
		out.append({"id": "send", "label": "Nur die Beweise senden, ohne abzuschalten", "ending": "abgeholt", "ok": true, "why": ""})
	if Inventory.count("overload_module") > 0 or Inventory.count("blast_charge") > 0 or Tasks.check("got:overload_module"):
		out.append({"id": "overload", "label": "Den Knoten überlasten (Überlastungsmodul + Sprengladung)", "ending": "glut", "ok": overload,
			"why": "Dafür brauche ich das Überlastungsmodul und eine Sprengladung."})
	if code:
		out.append({"id": "code", "label": "Den Code aus Senns Anlage eingeben", "ending": "schutzstatus", "ok": true, "why": ""})
	if not has_w17:
		for o: Dictionary in out:
			o["ok"] = false
			o["why"] = "Die Fassung ist leer. Hier gehört W-17 hinein – ich muss es bei mir tragen."
	return out


## Ein Ende beginnen. confirmed = die Abfrage »Das ist das Ende deiner Geschichte« ist schon beantwortet
## (bei »Zu spät« gibt es keine Abfrage, die Warnungen kamen vorher).
func start_ending(id: String, save_before: bool = true) -> void:
	if ending_running:
		return
	ending_running = true
	# Der Spielstand von vor der Entscheidung bleibt (nur, wenn der Spieler entschieden hat)
	if save_before:
		GameState.save_game(true)
	GameState.ending_lock = true
	var screen := EndingScreen.new()
	screen.ending_id = id
	get_tree().root.add_child(screen)


func get_state() -> Dictionary:
	return {"phase": phase, "active": steps_active.duplicate(), "done": steps_done.duplicate(), "hinted": hinted.duplicate(),
		"shaft_open_day": shaft_open_day, "warned": warned.duplicate()}


func set_state(s: Dictionary) -> void:
	phase = int(s.get("phase", 1))
	steps_active = (s.get("active", {}) as Dictionary).duplicate()
	steps_done = (s.get("done", []) as Array).duplicate()
	hinted = (s.get("hinted", []) as Array).duplicate()
	shaft_open_day = int(s.get("shaft_open_day", -1))
	warned = (s.get("warned", []) as Array).duplicate()
	ending_running = false
	# Alter Spielstand ohne Spuren: was schon stimmt, still nachziehen (keine Gedanken-Flut nach dem Laden)
	if not s.has("active"):
		update(false)
	steps_changed.emit()
