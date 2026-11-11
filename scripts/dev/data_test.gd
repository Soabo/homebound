class_name DataTest
extends RefCounted
## Entwickler-Test: prüft alle Datendateien unter data/ gegeneinander und gegen die gebaute Welt.
## Jeder Gegenstand, jedes Rezept, jede Verknüpfung, jede Aufgabe, jeder Ort muss auf etwas Vorhandenes zeigen.
## Start: godot --headless --path . -- --night-test=data

## Bekannte offene Punkte (angelegt, aber noch nicht fertig gebaut) – werden gemeldet, zählen nicht als Fehler.
## alien_seeds: „seed: alien“ ist vorbereitet, aber es gibt noch keine Pflanze „alien“ fürs Hochbeet.
const KNOWN_OPEN := ["Gegenstand alien_seeds: Pflanze „alien“ gibt es nicht (supplies.tres crops)"]

const NEED_KINDS := ["", "power", "light", "alien", "heat", "night", "day", "water"]
const EFFECTS := ["", "drain", "noise", "signal", "hurt", "escape"]
const ESCAPES := ["crawl", "spread", "call", "bloom"]
const DROP_AFTER := ["any", "creature", "drone", "manipulator", "seeker", "change"]
const DROP_WHERE := ["yard", "window", "porch", "garden", "forest", "stream", "patch", "player"]
const HAND_KINDS := ["axe", "tin_snips", "food", "water", "watering_can", "dictaphone"]
const TASK_VALUES := ["day", "cameras", "tier", "analyses", "stage", "fuel", "gencond"]
const TASK_WORDS := ["beds_planted", "beds_watered", "firewood", "radio_heard", "water_bad"]
## Flags, die mit einem Vorsatz + Kennung gemeldet werden (Tasks.flag("vorsatz" + id))
const FLAG_PREFIXES := ["visit_", "done_", "lab_", "cooked_", "link_", "bp_", "ate_"]


static func run(tree: SceneTree) -> int:
	var errs: PackedStringArray = []
	var items: Dictionary = DataDB.items().duplicate()
	items.erase("_info")
	var builds: Dictionary = DataDB.buildables().duplicate()
	builds.erase("_info")
	var recipes: Array = DataDB.recipes()
	var res: Dictionary = Research.data()
	var analyses: Dictionary = res.get("analyses", {})
	var links: Dictionary = res.get("links", {})
	var notes: Dictionary = res.get("notes", {})
	var lab: Dictionary = res.get("lab", {})
	var code := _all_code()
	var scene := tree.current_scene

	# --- Gegenstände
	for id: String in items:
		var it: Dictionary = items[id]
		for key in ["name", "weight", "stack", "category"]:
			if not it.has(key):
				errs.append("Gegenstand %s: Angabe „%s“ fehlt" % [id, key])
		if it.has("build") and not builds.has(String(it["build"])):
			errs.append("Gegenstand %s: Bauobjekt %s gibt es nicht" % [id, it["build"]])
		var use: Dictionary = it.get("use", {})
		if use.has("returns") and not items.has(String(use["returns"])):
			errs.append("Gegenstand %s: gibt %s zurück, das es nicht gibt" % [id, use["returns"]])
		if it.has("seed") and not Supplies.config.crops.has(String(it["seed"])):
			errs.append("Gegenstand %s: Pflanze „%s“ gibt es nicht (supplies.tres crops)" % [id, it["seed"]])
		if it.has("hand") and not HAND_KINDS.has(String(it["hand"])):
			errs.append("Gegenstand %s: Hand-Modell %s gibt es nicht" % [id, it["hand"]])
		if it.has("camera") and (int(it["camera"]) < 0 or int(it["camera"]) >= Surveillance.SLOTS):
			errs.append("Gegenstand %s: Kameraplatz %s gibt es nicht" % [id, str(it["camera"])])
	for crop: String in Supplies.config.crops:
		var c: Dictionary = Supplies.config.crops[crop]
		if not items.has(String(c.get("item", ""))):
			errs.append("Pflanze %s: Ernte %s gibt es nicht" % [crop, c.get("item", "")])
		var has_seed := false
		for id: String in items:
			if String(items[id].get("seed", "")) == crop:
				has_seed = true
		if not has_seed:
			errs.append("Pflanze %s: kein Saatgut dafür" % crop)
	for seed: String in GardenBed.SEEDS:
		if not items.has(seed) or not Supplies.config.crops.has(String(items[seed].get("seed", ""))):
			errs.append("Hochbeet: Saatgut %s passt zu keiner Pflanze" % seed)
	for b: String in builds:
		if not items.has(b) or String(items[b].get("build", "")) != b:
			errs.append("Bauobjekt %s: kein Gegenstand, mit dem man es bauen kann" % b)
	for k: String in Supplies.config.scrap_kinds:
		pass

	# --- Rezepte
	var recipe_ids := {}
	for r: Dictionary in recipes:
		var rid := String(r.get("id", ""))
		if recipe_ids.has(rid):
			errs.append("Rezept %s doppelt" % rid)
		recipe_ids[rid] = r
		for it: String in r.get("needs", {}):
			if not items.has(it):
				errs.append("Rezept %s: Zutat %s gibt es nicht" % [rid, it])
		for it: String in r.get("gives", {}):
			if not items.has(it):
				errs.append("Rezept %s: Ergebnis %s gibt es nicht" % [rid, it])
		if (r.get("gives", {}) as Dictionary).is_empty() and not String(r.get("special", "")) in ["build_analyzer", "door_upgrade"]:
			errs.append("Rezept %s: ergibt nichts" % rid)
		if not String(r.get("station", "workbench")) in ["workbench", "stove"]:
			errs.append("Rezept %s: Station %s gibt es nicht" % [rid, r.get("station", "")])
		var req := String(r.get("requires", ""))
		if req != "":
			if not links.has(req):
				errs.append("Rezept %s: Verknüpfung %s gibt es nicht" % [rid, req])
			elif not (links[req].get("unlocks", []) as Array).has(rid):
				errs.append("Rezept %s: Verknüpfung %s nennt es nicht als Bauplan (Spieler erfährt nie davon)" % [rid, req])
		var bp := String(r.get("blueprint", ""))
		if bp != "" and not code.contains("\"%s\"" % bp):
			errs.append("Rezept %s: Bauplan %s liegt nirgends in der Welt" % [rid, bp])

	# --- Forschung
	var areas: Array = res.get("areas", [])
	var stations: Dictionary = lab.get("stations", {})
	for id: String in analyses:
		var a: Dictionary = analyses[id]
		if not items.has(String(a.get("find", ""))):
			errs.append("Projekt %s: Fund %s gibt es nicht" % [id, a.get("find", "")])
		var st := String(a.get("station", "device"))
		if st != "device" and not stations.has(st):
			errs.append("Projekt %s: Station %s gibt es nicht" % [id, st])
		if not areas.has(a.get("area", "")):
			errs.append("Projekt %s: Gebiet „%s“ gibt es nicht" % [id, a.get("area", "")])
		for r: String in a.get("requires", []):
			if not analyses.has(r) and not links.has(r):
				errs.append("Projekt %s: Voraussetzung %s gibt es nicht" % [id, r])
		if bool(a.get("living", false)) and not ESCAPES.has(String(a.get("escape", "crawl"))):
			errs.append("Projekt %s: Ausbruchsart %s gibt es nicht" % [id, a.get("escape", "")])
		var exp_ids := {}
		for e: Dictionary in a.get("experiments", []):
			var eid := String(e.get("id", ""))
			if exp_ids.has(eid):
				errs.append("Projekt %s: Experiment %s doppelt" % [id, eid])
			exp_ids[eid] = true
			var n := String(e.get("needs", ""))
			if n.begins_with("item:"):
				if not items.has(n.substr(5)):
					errs.append("Projekt %s/%s: braucht %s, das es nicht gibt" % [id, eid, n.substr(5)])
			elif n.begins_with("built:"):
				if not stations.has(n.substr(6)):
					errs.append("Projekt %s/%s: braucht Laborplatz %s, den es nicht gibt" % [id, eid, n.substr(6)])
			elif not NEED_KINDS.has(n):
				errs.append("Projekt %s/%s: unbekannte Bedingung %s" % [id, eid, n])
			if not EFFECTS.has(String(e.get("effect", ""))):
				errs.append("Projekt %s/%s: unbekannte Wirkung %s" % [id, eid, e.get("effect", "")])
			if String(e.get("text", "")) == "":
				errs.append("Projekt %s/%s: kein Befundtext" % [id, eid])
	for l: String in links:
		var ld: Dictionary = links[l]
		if not areas.has(ld.get("area", "")):
			errs.append("Verknüpfung %s: Gebiet „%s“ gibt es nicht" % [l, ld.get("area", "")])
		for n: String in ld.get("needs", []):
			if not analyses.has(n):
				errs.append("Verknüpfung %s: braucht %s, das es nicht gibt" % [l, n])
		for u: String in ld.get("unlocks", []):
			if not recipe_ids.has(u):
				errs.append("Verknüpfung %s: Rezept %s gibt es nicht" % [l, u])
			elif String(recipe_ids[u].get("requires", "")) != l:
				errs.append("Verknüpfung %s: nennt Rezept %s, aber das Rezept verlangt etwas anderes" % [l, u])
		for g: String in ld.get("grants", []):
			if not g in ["forecast", "charger"]:
				errs.append("Verknüpfung %s: unbekannte Fähigkeit %s" % [l, g])
	# alles erreichbar? (Voraussetzungen der Reihe nach auflösen)
	var reach := {}
	var grew := true
	while grew:
		grew = false
		for id: String in analyses:
			if not reach.has(id) and (analyses[id].get("requires", []) as Array).all(func(r: String) -> bool: return reach.has(r)):
				reach[id] = true
				grew = true
		for l: String in links:
			if not reach.has(l) and (links[l].get("needs", []) as Array).all(func(r: String) -> bool: return reach.has(r)):
				reach[l] = true
				grew = true
	for id: String in analyses:
		if not reach.has(id):
			errs.append("Projekt %s: nie erreichbar (Voraussetzungen im Kreis oder fehlen)" % id)
	for l: String in links:
		if not reach.has(l):
			errs.append("Verknüpfung %s: nie erreichbar" % l)
	# Labor
	for it: String in lab.get("needs", {}):
		if not items.has(it):
			errs.append("Labor: Material %s gibt es nicht" % it)
	for st: String in stations:
		if not Research.LAB_STATIONS.has(st):
			errs.append("Labor: Platz %s kennt das Spiel nicht" % st)
		for it: String in stations[st].get("needs", {}):
			if not items.has(it):
				errs.append("Laborplatz %s: Material %s gibt es nicht" % [st, it])
		for r: String in stations[st].get("requires_any", []):
			if not analyses.has(r) and not links.has(r):
				errs.append("Laborplatz %s: Erkenntnis %s gibt es nicht" % [st, r])
	for it: String in lab.get("charger", {}).get("needs", {}):
		if not items.has(it):
			errs.append("Ladeschale: Material %s gibt es nicht" % it)
	for d: Dictionary in res.get("drops", []):
		if not items.has(String(d.get("item", ""))):
			errs.append("Fund nach der Nacht: %s gibt es nicht" % d.get("item", ""))
		if not DROP_AFTER.has(String(d.get("after", "any"))) or not DROP_WHERE.has(String(d.get("where", "yard"))):
			errs.append("Fund nach der Nacht %s: unbekanntes after/where" % d.get("item", ""))
		var dreq := String(d.get("requires", ""))
		if dreq != "" and not analyses.has(dreq) and not links.has(dreq):
			errs.append("Fund nach der Nacht %s: Voraussetzung %s gibt es nicht" % [d.get("item", ""), dreq])
	for g: String in res.get("gadgets", {}):
		if g != "_info" and not items.has(g) and g != "dictaphone":
			errs.append("Werkzeug-Werte %s: Gegenstand gibt es nicht" % g)
	# jeder Fund lässt sich untersuchen
	var finds := {}
	for id: String in analyses:
		finds[String(analyses[id].get("find", ""))] = true
	for id: String in items:
		if String(items[id].get("category", "")) == "Fund" and not finds.has(id) and not id in ["alien_analyzer", "w17"]:
			errs.append("Fund %s: kein Forschungsprojekt dazu" % id)
	# Notizen: im Code benutzte gibt es, vorhandene werden benutzt
	for n: String in notes:
		if not code.contains("\"%s\"" % n):
			errs.append("Notiz %s: wird nirgends in der Welt abgelegt" % n)

	# --- Aufgaben
	var tasks: Dictionary = Tasks.data()
	var task_ids := {}
	for group in ["goals", "daily"]:
		for g: Dictionary in tasks.get(group, []):
			var gid := String(g.get("id", ""))
			if task_ids.has(gid):
				errs.append("Aufgabe %s doppelt" % gid)
			task_ids[gid] = true
			if String(g.get("title", "")) == "":
				errs.append("Aufgabe %s: kein Titel" % gid)
			for c: String in (g.get("unlock", []) as Array) + (g.get("done", []) as Array):
				var e := _check_condition(c, items, builds, links, analyses, code)
				if e != "":
					errs.append("Aufgabe %s: %s" % [gid, e])

	# --- Karte
	var map: Dictionary = WorldMap.data()
	var places := {}
	for p: Dictionary in map.get("places", []):
		var pid := String(p.get("id", ""))
		if places.has(pid):
			errs.append("Ort %s doppelt" % pid)
		places[pid] = true
		if not String(p.get("ring", "")) in ["near", "day", "multi"]:
			errs.append("Ort %s: unbekannter Ring %s" % [pid, p.get("ring", "")])
		var pos := WorldMap.place_pos(pid)
		if absf(pos.x) > WorldMap.limit() or absf(pos.y) > WorldMap.limit():
			errs.append("Ort %s liegt außerhalb der Spielfeldgrenze" % pid)
		var old := {"absturz": "CrashSite", "struktur": "AlienStructure", "hochsitz": "RangerTower", "hoehle": "StreamCave"}
		if scene and scene.get_node_or_null("Places/" + pid) == null and scene.get_node_or_null(String(old.get(pid, "-"))) == null:
			errs.append("Ort %s steht in der Karte, wird aber nicht gebaut" % pid)
	for s: Dictionary in map.get("signs", []):
		for t: String in s.get("to", []):
			if not places.has(t):
				errs.append("Wegweiser bei %s: Ziel %s gibt es nicht" % [str(s.get("pos", "")), t])
	for w: String in map.get("w17_sites", []):
		if not places.has(w):
			errs.append("W-17-Ort %s gibt es nicht" % w)
	for c: Dictionary in map.get("cuts", []):
		if not places.has(String(c.get("place", ""))):
			errs.append("Einschnitt: Ort %s gibt es nicht" % c.get("place", ""))
	for t: Dictionary in map.get("trails", []):
		if (t.get("pts", []) as Array).size() < 2:
			errs.append("Weg %s: weniger als zwei Punkte" % t.get("id", ""))

	# --- Radio und Tablet
	var radio := DataDB.load_json("res://data/radio/radio.json")
	for k: String in radio.get("days", {}):
		if not k.is_valid_int():
			errs.append("Radio: Tag „%s“ ist keine Zahl" % k)
	var tablet := DataDB.load_json("res://data/tablet/tablet.json")
	var msg_ids := {}
	for m: Dictionary in tablet.get("messages", []):
		var mid := String(m.get("id", ""))
		if msg_ids.has(mid):
			errs.append("Tablet-Nachricht %s doppelt" % mid)
		msg_ids[mid] = true
		if not String(m.get("type", "")) in ["mail", "news"]:
			errs.append("Tablet-Nachricht %s: unbekannte Art" % mid)
		# Familie laut Story: Stefanie, Lena, Ben – der alte Platzhaltername darf nicht mehr vorkommen
		if String(m.get("body", "")).contains("Julia"):
			errs.append("Tablet-Nachricht %s: alter Platzhaltername „Julia“ (die Frau heißt Stefanie)" % mid)

	# --- Welt: alles, was man anfassen kann, zeigt auf vorhandene Daten
	if scene:
		for n in scene.find_children("*", "Node3D", true, false):
			if n is ItemPickup:
				if not items.has((n as ItemPickup).item_id):
					errs.append("Fund in der Welt %s: Gegenstand %s gibt es nicht" % [n.get_path(), (n as ItemPickup).item_id])
			elif n is ResearchNote:
				if not notes.has((n as ResearchNote).note_id):
					errs.append("Notiz in der Welt %s: Text %s gibt es nicht" % [n.get_path(), (n as ResearchNote).note_id])
			elif n is Blueprint:
				var used := false
				for r: Dictionary in recipes:
					if String(r.get("blueprint", "")) == (n as Blueprint).bp_id:
						used = true
				if not used:
					errs.append("Bauplan in der Welt %s: kein Rezept braucht %s" % [n.get_path(), (n as Blueprint).bp_id])
			elif n is PlaceInspect:
				var pi := n as PlaceInspect
				for it: String in pi.needs.keys() + pi.gives.keys():
					if not items.has(it):
						errs.append("Aktion in der Welt %s: Gegenstand %s gibt es nicht" % [n.get_path(), it])
			elif n is ResourceNode:
				var rn := n as ResourceNode
				if not items.has(rn.item_id) or (rn.tool != "" and not items.has(rn.tool)):
					errs.append("Rohstoff in der Welt %s: %s / Werkzeug %s gibt es nicht" % [n.get_path(), rn.item_id, rn.tool])
		# Namen im Spielstand: fest und eindeutig
		var keys := {}
		for n in tree.get_nodes_in_group("persistent"):
			var k := String(n.call("persist_key"))
			if keys.has(k):
				errs.append("Spielstand: zwei Objekte heißen %s" % k)
			if k.contains("@"):
				errs.append("Spielstand: Objekt ohne festen Namen %s" % k)
			keys[k] = true

	# --- Gegenstände im Code (Inventory.add/remove/count mit festem Namen)
	var rx := RegEx.create_from_string("Inventory\\.(?:add|remove|count|use|slot_of)\\(\\s*\"([a-z0-9_]+)\"")
	for m in rx.search_all(code):
		if not items.has(m.get_string(1)):
			errs.append("Code benutzt Gegenstand %s, den es nicht gibt" % m.get_string(1))
	var rx2 := RegEx.create_from_string("\"((?:an|link)_[a-z0-9_]+)\"")
	for m in rx2.search_all(code):
		var rid := m.get_string(1)
		if not analyses.has(rid) and not links.has(rid) and not rid.ends_with("_"):
			errs.append("Code benutzt Forschung %s, die es nicht gibt" % rid)

	var real := 0
	for e in errs:
		if KNOWN_OPEN.has(e):
			print("DATEN offen (bekannt): ", e)
		else:
			real += 1
			print("FEHLER Daten: ", e)
	print("DATEN: %d Gegenstände, %d Rezepte, %d Projekte, %d Verknüpfungen, %d Notizen, %d Aufgaben, %d Orte geprüft" % [items.size(), recipes.size(),
		analyses.size(), links.size(), notes.size(), task_ids.size(), places.size()])
	print("DATEN TEST: %d Fehler" % real)
	return real


static func _check_condition(c: String, items: Dictionary, builds: Dictionary, links: Dictionary, analyses: Dictionary, code: String) -> String:
	if c.begins_with("not:"):
		return _check_condition(c.substr(4), items, builds, links, analyses, code)
	if c.begins_with("flag:") or c.begins_with("today:"):
		var f := c.get_slice(":", 1)
		if code.contains("\"%s\"" % f) or code.contains("done_flag = \"%s\"" % f):
			return ""
		for pre: String in FLAG_PREFIXES:
			if f.begins_with(pre):
				var rest := f.substr(pre.length())
				if pre == "done_" and analyses.has(rest):
					return ""
				if pre == "lab_" and (Research.LAB_STATIONS.has(rest) or rest in ["built", "offered", "escape"]):
					return ""
				if pre == "visit_" and WorldMap.places().has(rest):
					return ""
				if pre == "cooked_" or pre == "link_" or pre == "bp_" or pre == "ate_":
					return ""
		return "Ereignis „%s“ meldet nie ein System" % f
	if c.begins_with("got:"):
		return "" if items.has(c.substr(4)) else "Gegenstand %s gibt es nicht" % c.substr(4)
	if c.begins_with("item:"):
		var it := c.substr(5).get_slice(">=", 0)
		return "" if items.has(it) else "Gegenstand %s gibt es nicht" % it
	if c.begins_with("built:"):
		return "" if builds.has(c.substr(6)) else "Bauobjekt %s gibt es nicht" % c.substr(6)
	if c.begins_with("link:"):
		return "" if links.has(c.substr(5)) else "Verknüpfung %s gibt es nicht" % c.substr(5)
	if TASK_WORDS.has(c):
		return ""
	var m := RegEx.create_from_string("^([a-z_]+)(>=|<=|<|>)([0-9.]+)$").search(c)
	if m and TASK_VALUES.has(m.get_string(1)):
		return ""
	return "unbekannte Bedingung „%s“" % c


## Der gesamte Spielcode als ein Text (ohne die Entwickler-Tests).
static func _all_code() -> String:
	var out := ""
	var stack := ["res://scripts"]
	while not stack.is_empty():
		var dir: String = stack.pop_back()
		var d := DirAccess.open(dir)
		if d == null:
			continue
		for sub in d.get_directories():
			if sub != "dev":
				stack.append(dir + "/" + sub)
		for f in d.get_files():
			if f.ends_with(".gd"):
				out += FileAccess.get_file_as_string(dir + "/" + f) + "\n"
	return out
