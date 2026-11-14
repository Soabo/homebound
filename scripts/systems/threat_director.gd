extends Node
## Threat Director (GDD 8.4): plant jede Nacht, was passiert – und wann.
## Er entscheidet nur ÜBER Ereignisse; wie sich die Kreatur verhält,
## entscheidet ihre eigene KI (GDD 17.3).
##
## Drei getrennte Größen (GDD 8.1):
##  - threat_level: steigt langfristig mit den Tagen
##  - night_intensity: Würfelwurf pro Nacht (0 ruhig … 3 Angriff)
##  - Weltveränderung: kommt später mit dem World State Manager

signal night_planned(intensity: int)

const CONFIG_PATH := "res://data/threat/default_threat.tres"
const INTENSITY_NAMES := ["ruhig", "unheimlich", "Erkundung", "Angriff"]

var config: ThreatConfig
var threat_level: float = 1.0
var night_intensity: int = 0
## Geplante Ereignisse: {"at": Gesamtstunde, "type": String, "done": bool}
var events: Array[Dictionary] = []
var creature: Node = null
## Lernverhalten (GDD 9.5): wie oft wurde ein Zugang schon blockiert vorgefunden?
var blocked_memory: Dictionary = {}

## Spannungsbogen (Christians Entscheidung): Die Kreatur zeigt sich selten. Etwa jede dritte Nacht
## ein echter Auftritt, danach 1–2 ruhige Nächte, dazwischen nur Andeutungen und Spuren.
## Die ersten Nächte nur Sichtungen; ab Nacht 4 auch Erkundungen am Haus, ab Nacht 6 echte Angriffe.
## night_kind: quiet | hints | sighting | visit | hunt
var night_kind: String = "hints"
var nights_since_appearance: int = 0
var quiet_left: int = 0
var _appeared_tonight: bool = false
var _arc_day: int = -1
## War in der laufenden Nacht etwas Fremdes los? (für die Veränderungen am Morgen)
var _activity_tonight: bool = false
var _kinds_tonight: Array = []   ## welche Wesen heute Nacht da waren (für AlienDrops)
const ACTIVITY_EVENTS := ["creature", "sighting", "drone", "manipulator", "phantom", "signal", "music_box", "knock_door",
		"rattle", "handprint", "roof", "scratch", "breath_wall", "photo", "attic"]
var _forest_day_done: int = -1
var _forest_check: float = 30.0

var _planned_for_day: int = -1
var _rng := RandomNumberGenerator.new()
## Belagerungsnächte (SiegeNight): wann die letzte war, wie viele es schon gab, welche Nacht schon überstanden ist
var last_siege_day: int = -100
var siege_count: int = 0
var siege_done_day: int = -1
## Wechselbalg: in wie vielen Nächten er schon da war (bestimmt die Stufe), Tag, an dem man ihn tagsüber geschlagen hat
var changeling_count: int = 0
var changeling_offended_day: int = -100
var _changeling_tonight := false
var _changeling_day_rolled: int = -1
var _changeling_day_wanted := false
var _changeling_day_check: float = 20.0
var _day_changeling: Node = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	config = load(CONFIG_PATH) as ThreatConfig
	if config == null:
		config = ThreatConfig.new()
	_rng.randomize()
	TimeManager.phase_changed.connect(_on_phase_changed)
	EventBus.sleep_finished.connect(_on_woke_up)
	EventBus.siege_finished.connect(func(_ok: bool) -> void: siege_done_day = _planned_for_day)
	_plan_if_needed.call_deferred()


## Die Nacht, die gerade läuft (nach Mitternacht zählt noch die Nacht des Vortags).
func current_night() -> int:
	var d := TimeManager.day
	if TimeManager.hour < TimeManager.config.day_start_hour:
		d -= 1
	return d


## Spielstand: Spannungsbogen und Lernspeicher (die geplanten Ereignisse werden neu gewürfelt).
func get_state() -> Dictionary:
	return {"night_kind": night_kind, "nights_since": nights_since_appearance, "quiet_left": quiet_left,
		"arc_day": _arc_day, "last_inside_day": _last_inside_day, "forest_day": _forest_day_done,
		"scared_until": scared_until, "blocked": blocked_memory.duplicate(), "mauler_until": mauler_until,
		"last_siege": last_siege_day, "siege_count": siege_count, "siege_done": siege_done_day,
		"changeling_count": changeling_count, "changeling_offended": changeling_offended_day}


func set_state(s: Dictionary) -> void:
	night_kind = String(s.get("night_kind", "hints"))
	nights_since_appearance = int(s.get("nights_since", 0))
	quiet_left = int(s.get("quiet_left", 0))
	_arc_day = int(s.get("arc_day", -1))
	_last_inside_day = int(s.get("last_inside_day", -10))
	_forest_day_done = int(s.get("forest_day", -1))
	scared_until = float(s.get("scared_until", -1.0))
	mauler_until = float(s.get("mauler_until", -1.0))
	last_siege_day = int(s.get("last_siege", -100))
	siege_count = int(s.get("siege_count", 0))
	siege_done_day = int(s.get("siege_done", -1))
	changeling_count = int(s.get("changeling_count", 0))
	changeling_offended_day = int(s.get("changeling_offended", -100))
	blocked_memory = (s.get("blocked", {}) as Dictionary).duplicate()


func reset_for_new_scene() -> void:
	creature = null
	_planned_for_day = -1
	events.clear()
	# Was nur für die abgebrochene Nacht galt, vergessen – sonst gäbe es z. B. nach einem Tod
	# in derselben Nacht keine Zeltnacht-Ereignisse mehr.
	_camp_planned_night = -1
	_tired_night = -1
	_tired_at = -1.0
	_activity_tonight = false
	_appeared_tonight = false
	_kinds_tonight.clear()
	_plan_if_needed.call_deferred()


func _on_phase_changed(is_night: bool) -> void:
	var scene := get_tree().current_scene
	if is_night:
		roam_meters = 0.0
		roam_count = 0
		_roam_warned = false
		_roam_last = -99.0
		if scene:
			Traces.clear(scene)
		get_tree().call_group("changeling", "dusk")
		return
	# Morgengrauen: Kreatur verschwindet, Spuren der Nacht bleiben, nächste Nacht wird geplant.
	# Alle Kreaturen und Drohnen ziehen ab (nicht nur die gemerkte) – bei Tag greift keine mehr an.
	get_tree().call_group("creature", "leave")
	get_tree().call_group("drone", "leave")
	get_tree().call_group("changeling", "dawn")
	# Nach einer Nacht mit dem Wechselbalg: ein Stuhl im Schlafzimmer, der zum Bett schaut
	if scene and _changeling_tonight and changeling_count >= 2 and not far_from_home() and _rng.randf() < config.changeling_morning_chance:
		var sp := Changeling.spots("morning")
		if not sp.is_empty():
			Changeling.spawn_spot(scene, sp[_rng.randi() % sp.size()], {"mode": "morning", "vanish_when_unseen": true, "subtle": changeling_count >= config.changeling_subtle_after})
	_changeling_tonight = false
	# Merker für Baupläne: erste unruhige Nacht, erster Besuch der Kreatur am Haus
	if _activity_tonight:
		Tasks.flag("unrest_night")
		if _kinds_tonight.has("creature") and night_kind in ["visit", "hunt"] and not far_from_home():
			Tasks.flag("creature_visited")
	# Dinge im Haus stehen anders
	if scene and _activity_tonight and not far_from_home() and _rng.randf() < config.inside_change_chance:
		get_tree().call_group("inside_changes", "morning", _rng.randi_range(config.inside_change_count.x, config.inside_change_count.y))
	if scene and _activity_tonight and _rng.randf() < config.night_change_chance:
		get_tree().call_group("night_changes", "morning", _rng.randi_range(config.night_change_count.x, config.night_change_count.y), config.night_change_days)
		_kinds_tonight.append("change")
	_activity_tonight = false
	# Forschung 2.0: was die Wesen heute Nacht hinterlassen haben
	var drops := AlienDrops.get_for(get_tree())
	if drops:
		drops.morning(_kinds_tonight)
	_kinds_tonight.clear()
	if scene and night_kind in ["hints", "visit", "hunt"] and _rng.randf() < (config.traces_after_hints if night_kind == "hints" else config.traces_after_visit):
		Traces.morning(scene, _rng)
	_plan_if_needed()


## Plant die kommende (oder laufende) Nacht, falls noch nicht geschehen.
func _plan_if_needed() -> void:
	var night_day := TimeManager.day
	if TimeManager.hour < TimeManager.config.day_start_hour:
		night_day -= 1  # Wir sind schon in der Nacht nach Mitternacht
	if night_day == _planned_for_day:
		return
	_planned_for_day = night_day
	plan_night(night_day)


func plan_night(night_day: int) -> void:
	threat_level = config.base_threat + float(night_day - 1) * config.threat_per_day
	# Nach einem Neustart (Tod) dieselbe Nacht nicht neu würfeln – der Bogen läuft weiter wie geplant
	if night_day != _arc_day:
		_arc_day = night_day
		night_kind = _choose_night_kind(night_day)
		# Endspurt (Schacht offen): keine ruhigen Nächte mehr, Belagerungen öfter (Story-Bibel Phase 5)
		var endgame := Story.shaft_open_day >= 0
		if endgame and night_kind in ["quiet", "hints", "sighting"]:
			night_kind = "visit" if _rng.randf() < config.endgame_visit_chance else "hunt"
		var every := config.endgame_siege_every if endgame else config.siege_every
		# Belagerungsnacht: ab siege_from_night, frühestens alle siege_every Nächte
		if night_day >= config.siege_from_night and night_day - last_siege_day >= every:
			night_kind = "siege"
			last_siege_day = night_day
			siege_count += 1
		# Die ersten Nächte sind bewusst ganz ruhig: man soll glauben, man kann einfach schlafen (Christian 14.11.)
		if night_day <= config.calm_first_nights:
			night_kind = "quiet"
	var calm := night_day <= config.calm_first_nights
	night_intensity = int({"quiet": 0, "hints": 1, "sighting": 1, "visit": 2, "hunt": 3, "siege": 3}[night_kind])
	_appeared_tonight = false
	events.clear()
	var start := float(night_day - 1) * 24.0 + TimeManager.config.night_start_hour
	var night_len := TimeManager.get_night_length_hours()
	# Kleine, mehrdeutige Ereignisse (GDD 2.3) – in ruhigen Nächten nur ganz wenige
	# Belagerung: nur die Belagerung – keine anderen Wesen, Vorkommnisse oder Kleinigkeiten (Christian 14.11.)
	var n := 0 if night_kind == "siege" or calm else 1 if night_kind == "quiet" else _rng.randi_range(config.ambient_events_per_night.x, config.ambient_events_per_night.y) + mini(night_intensity, 2)
	var pool := _event_pool(night_intensity)
	for i in n:
		_add(start + _rng.randf_range(0.6, night_len - 1.0), pool[_rng.randi() % pool.size()])
	# Nächtliche Vorkommnisse (NightOmens): Hände, wandernde Dinge, Lichter und Sichtungen im Wald …
	var oc := config.omen_count_quiet if night_kind in ["quiet", "siege"] else config.omen_count_busy
	for i in (0 if night_kind == "siege" or calm else _rng.randi_range(oc.x, oc.y)):
		var kind := _pick_omen(night_day)
		if kind != "":
			_add(start + _rng.randf_range(0.3, night_len - 0.8), "omen:" + kind)
	match night_kind:
		"siege":
			# die ganze Nacht über: Belagerung (SiegeNight), keine anderen Auftritte
			_add(float(night_day - 1) * 24.0 + config.siege_start_hour, "siege")
		"sighting":
			_add(start + _rng.randf_range(1.0, night_len - 2.0), "sighting")
			if _rng.randf() < config.sighting_phantom_chance:
				_add(start + _rng.randf_range(1.0, night_len - 1.0), "phantom")
		"visit", "hunt":
			_add(start + _rng.randf_range(1.0, 3.5), "creature")
			# Über das Dach in den Dachboden (zweiter Weg ins Haus, wenn die Leiter unten ist)
			if night_day >= config.attic_from_night and _rng.randf() < config.attic_chance:
				_add(start + _rng.randf_range(2.0, night_len - 1.5), "attic")
			if night_kind == "hunt" and _rng.randf() < config.outage_chance:
				_add(start + _rng.randf_range(2.5, 6.0), "outage")
	# Wechselbalg ab Story-Phase 2 (nicht in Belagerungsnächten – dort ist er eine eigene Aufgabe)
	if Story.phase >= config.changeling_from_phase and night_kind != "siege" and not calm \
			and (_rng.randf() < config.changeling_chance or changeling_offended_day == night_day):
		_add(start + _rng.randf_range(0.8, maxf(night_len - 2.0, 1.0)), "changeling")
	# Phase 8: neue Arten, sobald sich das Tal verändert (oder ab der dritten Nacht) – nicht in ruhigen Nächten
	var st := WorldState.stage()
	# Fremde Dinge machen sichtbar (Forschung 2.0): wer viel davon trägt oder nachts forscht, wird eher gefunden
	var sig := Research.expected_signature()
	if night_kind != "siege" and not calm and (night_kind != "quiet" or sig >= config.signature_wakes_quiet):
		if (st >= 1 or night_day >= config.drone_from_night) and _rng.randf() < config.drone_chance + config.species_chance_per_stage * st + config.signature_drone_bonus * sig:
			_add(start + _rng.randf_range(1.5, night_len - 2.0), "drone")
		if (st >= 1 or night_day >= config.manipulator_from_night) and night_kind == "hints" and _rng.randf() < config.manipulator_chance + config.species_chance_per_stage * st:
			_add(start + _rng.randf_range(2.0, night_len - 2.5), "manipulator")
		if Story.phase >= 2 and _rng.randf() < config.mauler_night_chance + config.mauler_chance_per_stage * st:
			_add(start + _rng.randf_range(0.5, night_len - config.mauler_window_hours), "mauler")
		if night_day >= config.seeker_from_day and _rng.randf() < config.seeker_chance + config.seeker_chance_per_stage * st + config.signature_seeker_bonus * sig:
			_add(start + _rng.randf_range(1.0, night_len - 2.5), "seeker")
	events.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["at"] < b["at"])
	night_planned.emit(night_intensity)
	print("[ThreatDirector] Nacht %d: %s, Bedrohung %.1f, %d Ereignisse" % [night_day, night_kind, threat_level, events.size()])


## Spannungsbogen: Wann zeigt sie sich, und wie?
func _choose_night_kind(night_day: int) -> String:
	if quiet_left > 0:
		quiet_left -= 1
		nights_since_appearance += 1
		return "quiet"
	var gaps := config.appear_chance_by_gap
	var chance: float = gaps[mini(nights_since_appearance, gaps.size() - 1)] if not gaps.is_empty() else 0.5
	if night_day == 1:
		chance = config.first_night_appear_chance  # erste Nacht: vielleicht ein flüchtiger Blick am Waldrand
	if _rng.randf() >= chance:
		nights_since_appearance += 1
		return "hints"
	nights_since_appearance = 0
	quiet_left = _rng.randi_range(config.quiet_nights_after.x, config.quiet_nights_after.y)
	if night_day < config.visit_from_night:
		return "sighting"
	if night_day < config.hunt_from_night:
		return "visit" if _rng.randf() < config.early_visit_share else "sighting"
	var hunt := clampf(config.hunt_chance_start + float(night_day - config.hunt_from_night) * config.hunt_chance_per_night, config.hunt_chance_start, config.hunt_chance_max)
	var r := _rng.randf()
	if r < hunt:
		return "hunt"
	return "visit" if r < hunt + config.late_visit_share else "sighting"


## Welche kleinen Ereignisse in einer Nacht dieser Intensität vorkommen können.
## Mehrdeutig mit Absicht: Der Spieler weiß nie, ob wirklich etwas da ist (GDD 2.3, 9.6).
func _event_pool(intensity: int) -> Array[String]:
	var pool: Array[String] = ["twig", "steps", "silence", "camera_glitch"]
	if intensity >= 1:
		pool.append_array(["breath_wall", "phantom", "scratch", "roof", "flicker", "radio", "signal"])
	if intensity >= 2:
		pool.append_array(["knock_door", "rattle", "music_box", "handprint", "photo", "scratch", "roof"])
	return pool


## Ist heute Nacht Belagerung (und noch nicht überstanden)? Dann gibt es keinen Schlaf.
func siege_tonight() -> bool:
	if night_kind != "siege" or siege_done_day == _planned_for_day:
		return false
	var h := TimeManager.hour
	return h >= 16.0 or h < config.siege_end_hour


## Welches Vorkommnis heute Nacht möglich ist (mit Tagesgrenzen), Draußen-Dinge etwas häufiger.
func _pick_omen(night_day: int) -> String:
	var opts: Array[String] = []
	var weights: Array[float] = []
	for k: String in NightOmens.HOUSE_KINDS + NightOmens.FOREST_KINDS:
		match k:
			"gap_hand":
				if night_day < config.omen_hand_from_night: continue
			"seeker_glimpse":
				if night_day < config.omen_seeker_from_night: continue
			"mauler_glimpse":
				if night_day < config.omen_mauler_from_night: continue
			"drawing":
				var ic := get_tree().get_first_node_in_group("inside_changes")
				if night_day < config.omen_drawing_from_night or _drawing_planned or (ic and ic.drawing_shown): continue
		opts.append(k)
		weights.append(config.omen_forest_weight if k in NightOmens.FOREST_KINDS else 1.0)
	if opts.is_empty():
		return ""
	var total := 0.0
	for w in weights:
		total += w
	var r := _rng.randf() * total
	for i in opts.size():
		r -= weights[i]
		if r <= 0.0:
			if opts[i] == "drawing":
				_drawing_planned = true
			return opts[i]
	return opts[0]


## Ereignis von außen einplanen (z. B. eine ausgebrochene Probe ruft die Drohne).
func force_event(type: String, delay_hours: float) -> void:
	_add(TimeManager.get_total_hours() + delay_hours, type)
	events.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["at"] < b["at"])


func _add(at: float, type: String) -> void:
	events.append({"at": at, "type": type, "done": false})


## Etwas ist auf dem Dachboden: Schritte über der Decke, Kratzen an der Luke. Steht die Leiter unten
## (oder ist sie heruntergelassen worden), kommt es herunter: Gestalt am Leiterfuß, Schlammspur, Weckruf.
func _attic_event(scene: Node, player: Node3D) -> void:
	var hatch_pos := Vector3(AtticHatch.FOOT.x, Cabin.WALL_TOP + 0.4, AtticHatch.HOLE.get_center().y)
	for k in 3:
		get_tree().create_timer(k * 2.2).timeout.connect(func() -> void:
			if is_instance_valid(scene):
				SoundBank.play_at(scene, "roof_steps", hatch_pos + Vector3(_rng.randf_range(-3.0, 1.0), 0.3, _rng.randf_range(-1.0, 1.0)), -2.0, 0.8))
	SoundBank.play_at(scene, "scratch", hatch_pos, 0.0, 0.8)
	var down := AtticHatch.down_now
	if not down or TimeManager.day < config.attic_from_night or _rng.randf() > config.attic_ladder_down_chance:
		# Leiter oben: es kratzt nur an der Luke – morgens Schlamm oben auf dem Dachboden
		get_tree().create_timer(5.0).timeout.connect(func() -> void:
			if is_instance_valid(scene):
				SoundBank.play_at(scene, "knock", hatch_pos, -2.0, 0.7))
		return
	# Leiter unten: es kommt herunter
	SoundBank.play_at(scene, "floor_creak", AtticHatch.FOOT + Vector3(0, 1.5, -0.5), 2.0, 0.7)
	Tasks.flag("creature_visited")
	get_tree().create_timer(3.0).timeout.connect(func() -> void:
		if not is_instance_valid(scene):
			return
		Apparition.spawn(scene, "ladder")
		CreatureSounds.play(scene, "breath", AtticHatch.FOOT + Vector3(0, 1.6, 0), -4.0, 0.9)
		var pl := get_tree().get_first_node_in_group("player") as Player
		if pl and TimeManager.day >= config.attic_hurt_from_night and pl.global_position.distance_to(AtticHatch.FOOT) < 3.5:
			pl.take_damage(config.attic_damage, AtticHatch.FOOT + Vector3(0, 1.2, 0))
			EventBus.screen_shake.emit(0.6))


## Gegen 23–1 Uhr wird der Spieler müde – wenn bis dahin nichts passiert ist, sagt er es.
var _tired_night: int = -1
var _tired_at: float = -1.0


func _check_tired() -> void:
	if not TimeManager.is_night():
		return
	var night := current_night()
	var tc := TimeManager.config
	if _tired_night != night:
		_tired_night = night
		var span := fposmod(tc.tired_until_hour - tc.tired_from_hour, 24.0)
		_tired_at = float(night - 1) * 24.0 + tc.tired_from_hour + _rng.randf() * span
	if _tired_at > 0.0 and TimeManager.get_total_hours() >= _tired_at:
		_tired_at = -1.0
		if not _activity_tonight and not GameState.dead:
			var sitting := get_tree().get_nodes_in_group("couch").any(func(c: Node) -> bool: return c.get("sitting"))
			EventBus.notify("Die Augen fallen dir fast zu. Zeit, ins Bett zu gehen." if sitting else "Du wirst müde. Zeit, ins Bett zu gehen.", 5.0)


var _evening_warned: int = -1


func _process(delta: float) -> void:
	_check_evening()
	_check_forest_stalker(delta)
	_check_mauler(delta)
	_check_night_roam(delta)
	_check_tired()
	_check_changeling_day(delta)
	var now := TimeManager.get_total_hours()
	for e in events:
		if not e["done"] and now >= e["at"]:
			e["done"] = true
			# Leise Zeltnacht-Vorfälle, die man verschlafen hat, finden nicht nachträglich statt
			var t := String(e["type"])
			if t.begins_with("camp:") and not CampEvents.wakes(t.substr(5)) and now - float(e["at"]) > 0.25:
				continue
			_fire(t)


## Gegen 17 Uhr: „Der Abend beginnt“ (Zeit-Werte in TimeConfig evening_warning_*).
func _check_evening() -> void:
	var cfg := TimeManager.config
	if _evening_warned == TimeManager.day or get_tree().current_scene == null or not GameState.in_game():
		return
	if TimeManager.hour >= cfg.evening_warning_hour and TimeManager.hour < cfg.night_start_hour:
		_evening_warned = TimeManager.day
		if siege_tonight():
			EventBus.notify("Etwas stimmt nicht. Heute Nacht kommen sie – kein Schlaf. Bereite die Hütte vor: Holz, Diesel, Bretter.", 7.0)
			SoundBank.play_ui(self, "sting_dusk", -4.0)
			return
		EventBus.notify(cfg.evening_warning_text, 4.0)
		SoundBank.play_ui(self, "menu_click", -10.0, 0.7)
	elif TimeManager.hour < cfg.evening_warning_hour and TimeManager.hour > 6.0:
		pass


## Zerfleischer (ab Story-Phase 2): nachts im Zeitfenster eines „mauler“-Ereignisses, sobald du draußen bist
## (am Haus, im Wald, beim Zelt – dort schleicht er nur herum); selten auch tagsüber weit weg im dichten Wald.
var mauler_until: float = -1.0
var _drawing_planned := false
var _mauler_check: float = 0.0
var _mauler_last_hour: float = -1.0


func _check_mauler(delta: float) -> void:
	_mauler_check -= delta
	if _mauler_check > 0.0:
		return
	_mauler_check = 3.0
	if Story.phase < 2 or GameState.dead or not get_tree().get_nodes_in_group("mauler").is_empty():
		return
	var scene := get_tree().current_scene
	var player := get_tree().get_first_node_in_group("player") as Player
	if scene == null or player == null:
		return
	var p := player.global_position
	if Cabin.is_inside(p) or Shed.is_inside(p) or player.is_hidden():
		return
	var now := TimeManager.get_total_hours()
	if TimeManager.is_night():
		if now < mauler_until:
			mauler_until = -1.0
			Mauler.spawn_near(scene, p)
			_activity_tonight = true
			if not _kinds_tonight.has("mauler"):
				_kinds_tonight.append("mauler")
		return
	# Tag: nur weit weg und im dichten Wald, je Spielstunde eine kleine Chance
	if _mauler_last_hour < 0.0 or now < _mauler_last_hour:
		_mauler_last_hour = now
		return
	var dh := now - _mauler_last_hour
	_mauler_last_hour = now
	if far_from_home() and WorldMap.tree_density(p.x, p.z, p.y) >= config.mauler_day_density and _rng.randf() < config.mauler_day_chance_per_hour * dh:
		var m := Mauler.spawn_near(scene, p)
		m.set_meta("day_hunt", true)


## Nachts weit draußen unterwegs: je mehr man läuft (und je lauter), desto eher stellt sich einem etwas in den Weg.
## Erst eine Warnung (Schritte, Ast), dann Zerfleischer (ab Phase 2), Sucher oder Kreatur. Werte: ThreatConfig roam_*.
var roam_meters: float = 0.0
var roam_count: int = 0
var _roam_warned := false
var _roam_last: float = -99.0
var _roam_check: float = 0.0
var _roam_prev := Vector3.INF


func _check_night_roam(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	var scene := get_tree().current_scene
	if player == null or scene == null or GameState.dead or not GameState.in_game() or not TimeManager.is_night():
		_roam_prev = Vector3.INF
		return
	var p := player.global_position
	var outside := not (Cabin.is_inside(p) or Shed.is_inside(p) or player.is_hidden() or player.in_tent != null)
	if outside and _roam_prev != Vector3.INF:
		var step := Vector2(p.x - _roam_prev.x, p.z - _roam_prev.z).length()
		if step < 5.0:   # Teleports (Aufwachen, Laden) zählen nicht
			roam_meters += step
	_roam_prev = p
	_roam_check -= delta
	if _roam_check > 0.0:
		return
	_roam_check = config.roam_check_seconds
	var chance := roam_chance()
	if chance <= 0.0 or _rng.randf() >= chance:
		return
	_roam_encounter(scene, player)


## Chance für den nächsten Wurf (0 = gerade sicher). Auch für Tests.
func roam_chance() -> float:
	var player := get_tree().get_first_node_in_group("player") as Player
	if player == null or not TimeManager.is_night() or siege_tonight() or TimeManager.day <= config.calm_first_nights:
		return 0.0
	var p := player.global_position
	if Vector2(p.x, p.z).length() < config.roam_min_distance or Cabin.is_inside(p) or Shed.is_inside(p) or player.is_hidden() or player.in_tent != null:
		return 0.0
	for t in get_tree().get_nodes_in_group("tent_camp"):
		if (t as Node3D).global_position.distance_to(p) < config.roam_camp_radius:
			return 0.0
	if roam_count >= config.roam_max_per_night or TimeManager.get_total_hours() - _roam_last < config.roam_cooldown_hours:
		return 0.0
	var c := config.roam_base_chance + config.roam_chance_per_100m * roam_meters / 100.0
	if player.is_concealed():
		return 0.0   # wer still im Gebüsch hockt, wird nicht gefunden
	if Vector2(player.velocity.x, player.velocity.z).length() > player.walk_speed * 1.2:
		c *= config.roam_run_factor
	return minf(c, config.roam_max_chance)


func _roam_encounter(scene: Node, player: Player) -> void:
	var p := player.global_position
	_activity_tonight = true
	if config.roam_warn_first and not _roam_warned:
		_roam_warned = true
		_play_phantom_steps(scene)
		EventBus.notify("Da war etwas. Hinter mir, zwischen den Bäumen.", 3.5)
		return
	_roam_warned = false   # nach einer Begegnung warnt es wieder erst
	_roam_last = TimeManager.get_total_hours()
	roam_count += 1
	var options: Array[String] = []
	if Story.phase >= 2 and get_tree().get_nodes_in_group("mauler").is_empty():
		options.append("mauler")
	if get_tree().get_nodes_in_group("seeker").is_empty():
		options.append("seeker")
	if not is_instance_valid(creature) and TimeManager.day >= config.hunt_from_night:
		options.append("creature")
	if options.is_empty():
		_play_phantom_steps(scene)
		return
	var pick := options[_rng.randi() % options.size()]
	if not _kinds_tonight.has(pick):
		_kinds_tonight.append(pick)
	match pick:
		"mauler":
			Mauler.spawn_near(scene, p)
		"seeker":
			Seeker.spawn_for(scene, p)
		"creature":
			var away := Vector3(_rng.randf_range(-1, 1), 0, _rng.randf_range(-1, 1)).normalized()
			spawn_ambush(p + away * 26.0)


## Nach dem Hochschrecken mindestens eine Spielstunde wach bleiben (Gesamtstunde, bis wann).
var scared_until: float = -1.0


## Warum gerade nicht geschlafen werden kann ("" = Schlafen erlaubt).
func sleep_blocker() -> String:
	if siege_tonight():
		return "Heute Nacht kann ich nicht schlafen. Sie kommen."
	if TimeManager.get_total_hours() < scared_until:
		return "Du bist viel zu aufgewühlt, um wieder einzuschlafen."
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if is_instance_valid(creature) and player and (creature as Node3D).global_position.distance_to(player.global_position) < config.no_sleep_creature_distance:
		return "Da draußen ist etwas. An Schlaf ist nicht zu denken."
	for g in ["manipulator", "drone", "apparition", "seeker", "mauler"]:
		if not get_tree().get_nodes_in_group(g).is_empty():
			return "Da draußen ist etwas. An Schlaf ist nicht zu denken."
	return ""


## Für das Schlafsystem (GDD 4.4): erstes störendes Ereignis zwischen jetzt und Aufwachzeit.
func first_disturbance(from_total: float, to_total: float) -> float:
	for e in events:
		if e["done"]:
			continue
		var t := String(e["type"])
		var wakes := t in ["creature", "sighting", "outage", "drone", "manipulator", "seeker", "mauler", "camp", "steps", "breath_wall", "knock_door", "rattle", "scratch", "roof", "radio", "photo", "attic",
				"omen:gap_hand", "omen:knock_walk", "omen:music_box", "omen:tap_run", "siege"] or (t.begins_with("camp:") and CampEvents.wakes(t.substr(5)))
		if wakes and e["at"] > from_total and e["at"] < to_total:
			return e["at"]
	return -1.0


func _fire(type: String) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if type == "siege":
		_kinds_tonight.append_array(["creature", "manipulator"])
		_activity_tonight = true
		if far_from_home() or SiegeNight.current != null:
			return
		var s := SiegeNight.new()
		s.cfg = config
		s.index = siege_count
		s.end_total = float(_planned_for_day) * 24.0 + config.siege_end_hour
		scene.add_child(s)
		return
	if type == "changeling":
		_spawn_changeling(scene, player as Player)
		return
	if type.begins_with("omen:"):
		var kind := type.substr(5)
		# Dinge am Haus nur, wenn man zuhause ist; Wald-Dinge überall um einen herum
		if kind in NightOmens.HOUSE_KINDS and far_from_home():
			return
		if kind in ["gap_hand", "knock_walk", "music_box", "tap_run"]:
			_activity_tonight = true
		NightOmens.fire(kind, scene, player as Player, config, _rng)
		return
	# Weit weg von der Hütte (Ausflug, Zelt): Ereignisse am Haus werden zu Ereignissen im Wald um dich herum
	if far_from_home():
		type = _far_variant(type)
		if type == "":
			return
	if type in ["creature", "drone", "manipulator", "seeker"] and not _kinds_tonight.has(type):
		_kinds_tonight.append(type)
	if type in ACTIVITY_EVENTS:
		_activity_tonight = true
		# Tablet flackert nur nachts – ein Hinweis, dass draußen etwas ist
		if TimeManager.is_night():
			get_tree().call_group("tablet_menu", "flicker")
	match type:
		"twig":
			SoundBank.play_at(scene, "twig", _random_forest_point(18.0, 30.0), -2.0, _rng.randf_range(0.8, 1.2))
		"steps":
			# Im Haus: eine Diele knarrt in einem anderen Zimmer. Draußen: Schritte im Wald.
			if player and Cabin.is_inside(player.global_position) and SoundBank.has_recording("floor_creak") and _rng.randf() < 0.6:
				var p := Vector3(_rng.randf_range(-5.0, 5.0), 0.6, _rng.randf_range(-3.5, 3.5))
				if p.distance_to(player.global_position) < 3.0:
					p = -p
				SoundBank.play_at(scene, "floor_creak", p, 0.0)
			else:
				_play_phantom_steps(scene)
		"breath_wall":
			var p := Vector3(_rng.randf_range(-6.5, 6.5), 1.4, -4.9 if _rng.randf() < 0.5 else 4.9)
			CreatureSounds.play_phrase(scene, "breath", p, -5.0, _rng.randf_range(4.0, 6.0), 14.0)
		"camera_glitch":
			EventBus.camera_glitch.emit(_rng.randi_range(0, 2), _rng.randf_range(2.0, 5.0))
		"phantom":
			EventBus.camera_phantom.emit(_rng.randi_range(0, 2), _rng.randf_range(4.0, 9.0))
		"silence":
			get_tree().call_group("nature_ambience", "silence_for", _rng.randf_range(20.0, 45.0))
		"scratch":
			SoundBank.play_at(scene, "scratch", _random_wall_point(), 0.0, _rng.randf_range(0.85, 1.1))
		"attic":
			_attic_event(scene, player)
		"roof":
			# Schritte auf dem Dach – wenn du drin bist, genau über dir
			var rp := Vector3(_rng.randf_range(-5.0, 5.0), Cabin.WALL_TOP + 1.2, _rng.randf_range(-3.0, 3.0))
			if player and Cabin.is_inside(player.global_position):
				rp = Vector3(player.global_position.x, Cabin.WALL_TOP + 1.2, player.global_position.z)
			SoundBank.play_at(scene, "roof_steps", rp, 0.0)
		"flicker":
			for lamp in get_tree().get_nodes_in_group("lamp"):
				lamp.call("flicker", _rng.randf_range(1.5, 4.0))
		"radio":
			for r in get_tree().get_nodes_in_group("radio"):
				if not r.is_on:
					r.call("set_on", true, true)
		"signal":
			SoundBank.play_at(scene, "signal", _random_forest_point(15.0, 25.0) + Vector3(0, 2, 0), 2.0)
			for i in 3:
				EventBus.camera_glitch.emit(i, 3.0)
			for lamp in get_tree().get_nodes_in_group("lamp"):
				lamp.call("flicker", 2.5)
		"knock_door":
			# Klopfen an der Haustür – aber auf der Kamera ist niemand zu sehen.
			SoundBank.play_at(scene, "knock", Vector3(-3.0, 1.4, 4.75), 4.0, _rng.randf_range(0.9, 1.0))
		"rattle":
			var door := scene.get_node_or_null("Cabin/FrontDoor")
			if door:
				door.call("rattle")
		"music_box":
			# Der Manipulator lockt: eine Spieluhr irgendwo im dunklen Wald (GDD 9.3)
			SoundBank.play_at(scene, "music_box", _random_forest_point(20.0, 30.0) + Vector3(0, 1, 0), 0.0)
		"handprint":
			var windows := get_tree().get_nodes_in_group("entry_point").filter(func(e: Node) -> bool: return e is CabinWindow)
			if not windows.is_empty():
				windows[_rng.randi() % windows.size()].call("add_handprint")
		"photo":
			for ph in get_tree().get_nodes_in_group("family_photo"):
				if ph.rotation_degrees.x > -40.0:
					ph.rotation_degrees.x = -82.0
					SoundBank.play_at(scene, "picture_fall", ph.global_position, 0.0)
		"outage":
			if PowerManager.has_power():
				PowerManager.trigger_outage()
				if player:
					SoundBank.play_at(scene, "bang", Vector3(4.6, 1.0, -3.8), -4.0, 0.6)
		"creature":
			_spawn_creature(scene)
		"sighting":
			_sighting(scene, player)
		"forest_sighting":
			_appeared_tonight = true
			Apparition.spawn(scene, "forest")
			CreatureSounds.play_phrase(scene, "breath", _random_forest_point(14.0, 20.0) + Vector3(0, 1.2, 0), -4.0, _rng.randf_range(3.0, 5.0), 30.0)
		"seeker":
			Seeker.spawn_for(scene, _seeker_target(player))
		"mauler":
			# Er ist jetzt draußen unterwegs – sobald du hinausgehst, jagt er dich
			mauler_until = TimeManager.get_total_hours() + config.mauler_window_hours
		"camp":
			var camps := get_tree().get_nodes_in_group("tent_camp").filter(func(c: Node) -> bool: return c.call("occupied"))
			if not camps.is_empty():
				camps[0].call("camp_event", "")
			elif far_from_home():
				_play_phantom_steps(scene)
		_ when type.begins_with("camp:"):
			var camps2 := get_tree().get_nodes_in_group("tent_camp").filter(func(c: Node) -> bool: return c.call("occupied"))
			if not camps2.is_empty():
				camps2[0].call("camp_event", type.substr(5))
			elif far_from_home():
				_play_phantom_steps(scene)
		"drone":
			if get_tree().get_nodes_in_group("drone").is_empty():
				var d := AlienDrone.new()
				d.name = "Drone"
				scene.add_child(d)
		"manipulator":
			if get_tree().get_nodes_in_group("manipulator").is_empty():
				var m := Manipulator.new()
				m.name = "Manipulator"
				scene.add_child(m)


## Hinterhalt / Alarm (Drohne, Manipulator): Kreatur greift an, nahe einer Stelle.
func spawn_ambush(at: Vector3) -> void:
	var scene := get_tree().current_scene
	if not TimeManager.is_night():
		return   # bei Tag kein Hinterhalt mehr (Drohnen-Alarm im Morgengrauen)
	# In den ersten Nächten noch keine Jagd: Sie zeigt sich nur – starrend am Waldrand.
	if TimeManager.day < config.hunt_from_night and not is_instance_valid(creature):
		Apparition.spawn(scene, "edge")
		return
	if is_instance_valid(creature):
		creature.call("_start_chase")
		return
	var c := Creature.new()
	c.name = "Creature"
	scene.add_child(c)
	creature = c
	c.call("begin", "attack")
	c.global_position = Creature._ground(at)
	c.call("_start_chase")


## Ein echter Auftritt ohne Angriff: am Fenster, wenn du drin bist – sonst am Waldrand.
func _sighting(scene: Node, player: Node3D) -> void:
	_appeared_tonight = true
	var inside := player != null and Cabin.is_inside(player.global_position)
	var a: Apparition = null
	if inside and _rng.randf() < config.sighting_window_share:
		a = Apparition.spawn(scene, "window")
	if a == null:
		a = Apparition.spawn(scene, "edge")
	if a == null:
		EventBus.camera_phantom.emit(_rng.randi_range(0, 2), _rng.randf_range(5.0, 9.0))


## Nach dem Aufstehen steht sie manchmal im Haus (nicht in den ersten Nächten, nie zweimal hintereinander).
var _last_inside_day: int = -10


func _on_woke_up() -> void:
	var scene := get_tree().current_scene
	if scene == null or TimeManager.is_night() or TimeManager.day < config.inside_from_day or TimeManager.day - _last_inside_day < config.inside_min_gap_days:
		return
	var chance := config.inside_chance_after_appearance if night_kind in ["sighting", "visit", "hunt"] else config.inside_chance_otherwise
	if _rng.randf() < chance:
		_last_inside_day = TimeManager.day
		Apparition.spawn(scene, "inside")


## Tagsüber, weit weg vom Haus: ganz selten eine Gestalt zwischen den Bäumen, die dir folgt.
func _check_forest_stalker(delta: float) -> void:
	_forest_check -= delta
	if _forest_check > 0.0:
		return
	_forest_check = 30.0
	if TimeManager.is_night() or TimeManager.day < config.forest_from_day or _forest_day_done == TimeManager.day:
		return
	var scene := get_tree().current_scene
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if scene == null or player == null or not get_tree().get_nodes_in_group("apparition").is_empty():
		return
	if Vector2(player.global_position.x, player.global_position.z).length() < config.forest_min_distance:
		return
	if _rng.randf() < config.forest_chance_per_check:
		_forest_day_done = TimeManager.day
		Apparition.spawn(scene, "forest")


func _spawn_creature(scene: Node) -> void:
	if is_instance_valid(creature):
		return
	var c := Creature.new()
	c.name = "Creature"
	scene.add_child(c)
	creature = c
	_appeared_tonight = true
	c.call("begin", "attack" if night_kind == "hunt" else "probe")


func _play_phantom_steps(scene: Node) -> void:
	# Schritte im Laub – ohne Kreatur. Der Spieler weiß nicht, ob da etwas ist.
	var start := _random_forest_point(10.0, 16.0)
	var dir := Vector3(_rng.randf_range(-1, 1), 0, _rng.randf_range(-1, 1)).normalized()
	for i in 6:
		var p := start + dir * i * 0.7
		p.y = Terrain.height_at(p.x, p.z) + 0.1
		CreatureSounds.play(scene, "step", p, -3.0, _rng.randf_range(0.9, 1.05), 40.0)
		await get_tree().create_timer(0.6).timeout
		# Szene inzwischen neu geladen (Tod, Tagesneustart)? Dann gibt es den alten Wald nicht mehr.
		if not is_instance_valid(scene) or not scene.is_inside_tree():
			return


## Wo sucht der Sucher: am Zelt, um den Spieler draußen oder an der Hütte.
func _seeker_target(player: Node3D) -> Vector3:
	if player and player.get("in_tent"):
		return (player.get("in_tent") as Node3D).global_position
	if player and far_from_home():
		return player.global_position
	return Vector3.ZERO


## Zeltnacht: ein bis drei Ereignisse zwischen jetzt und dem Morgen (einmal pro Nacht).
var _camp_planned_night: int = -1


func plan_camp_night(camp: Node) -> void:
	var night := current_night()
	if _camp_planned_night == night or camp == null:
		return
	_camp_planned_night = night
	var now := TimeManager.get_total_hours()
	var night_end := float(night) * 24.0 + TimeManager.config.day_start_hour
	if night_end <= now + 1.0:
		return
	var n := _rng.randi_range(config.camp_events.x, config.camp_events.y)
	# Zelt an einem Rastplatz: ruhigere Nacht
	if camp is Node3D and RestSpot.near((camp as Node3D).global_position, config.camp_rest_radius, get_tree()):
		n = maxi(1, int(round(float(n) * config.camp_rest_factor)))
	# Vorfälle aus data/threat/camp_events.json; höchstens camp_wake_max wecken den Schlafenden
	var kinds := CampEvents.plan(n, night, config.camp_wake_max, _rng)
	var times: Array[float] = []
	for i in kinds.size():
		times.append(_rng.randf_range(now + config.camp_first_after, night_end - 0.8))
	times.sort()
	for i in kinds.size():
		_add(times[i], "camp:" + String(kinds[i]))
	events.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["at"] < b["at"])
	n = kinds.size()
	print("[ThreatDirector] Zeltnacht: %d Ereignisse" % n)


## Ist der Spieler weit weg von der Hütte (Ausflug, Nacht im Zelt)?
const FAR_FROM_HOME := 150.0


func far_from_home() -> bool:
	var p := get_tree().get_first_node_in_group("player") as Node3D
	return p != null and Vector2(p.global_position.x, p.global_position.z).length() > FAR_FROM_HOME


## Ersatz für Ereignisse, die nur an der Hütte Sinn ergeben. "" = entfällt.
func _far_variant(type: String) -> String:
	match type:
		"scratch", "roof", "knock_door", "rattle", "breath_wall", "attic":
			return "steps" if _rng.randf() < 0.6 else "twig"
		"handprint", "photo", "flicker", "radio", "outage":
			return ""
		"creature", "sighting":
			return "forest_sighting"
	return type


func _random_forest_point(min_d: float, max_d: float) -> Vector3:
	var a := _rng.randf() * TAU
	var d := _rng.randf_range(min_d, max_d)
	var c := Vector3.ZERO
	if far_from_home():
		c = (get_tree().get_first_node_in_group("player") as Node3D).global_position
	var x := c.x + cos(a) * d
	var z := c.z + sin(a) * d
	return Vector3(x, Terrain.height_at(x, z) + 0.3, z)


func _random_wall_point() -> Vector3:
	var side := _rng.randi() % 4
	match side:
		0: return Vector3(_rng.randf_range(-5.5, 5.5), 1.2, 4.75)
		1: return Vector3(_rng.randf_range(-5.5, 5.5), 1.2, -4.75)
		2: return Vector3(-6.25, 1.2, _rng.randf_range(-4.0, 4.0))
	return Vector3(6.25, 1.2, _rng.randf_range(-4.0, 4.0))


## Lernverhalten: Zugang wurde verstärkt vorgefunden.
func remember_blocked(entry_name: String) -> void:
	blocked_memory[entry_name] = int(blocked_memory.get(entry_name, 0)) + 1


# --- Wechselbalg ------------------------------------------------------------------

## Stufe: 1 = nur „ein Ding zu viel“ auf dem Hof, 2 = im Haus mit deutlichem Fehler, rückt langsam,
## 3 = feine Fehler, rückt bei jedem Wegsehen, Echo-Schritte.
func changeling_stage() -> int:
	if changeling_count <= 0:
		return 1
	if changeling_count < config.changeling_subtle_after:
		return 2
	return 3


## Tagsüber geschlagen: in der nächsten Nacht kommt er sicher (und schneller).
func changeling_offended() -> void:
	changeling_offended_day = TimeManager.day
	if _planned_for_day == TimeManager.day and not events.any(func(e: Dictionary) -> bool: return e["type"] == "changeling" and not e["done"]):
		var start := float(TimeManager.day - 1) * 24.0 + TimeManager.config.night_start_hour
		_add(start + _rng.randf_range(1.0, 3.0), "changeling")


func _spawn_changeling(scene: Node, player: Player) -> void:
	if far_from_home() or player == null:
		return   # draußen im Zelt: eigene Zeltnacht-Vorfälle
	var stage := changeling_stage()
	var night := current_night()
	changeling_count += 1
	_changeling_tonight = true
	_activity_tonight = true
	if not _kinds_tonight.has("changeling"):
		_kinds_tonight.append("changeling")
	var offended := changeling_offended_day == night
	if stage == 1:
		var yard := Changeling.spots("yard")
		Changeling.spawn_spot(scene, yard[_rng.randi() % yard.size()], {"mode": "yard", "vanish_when_unseen": true})
		return
	var inside := Cabin.is_inside(player.global_position)
	var pool: Array = Changeling.spots("house" if inside else "yard")
	pool.shuffle()
	var n := config.changeling_multi if Story.shaft_open_day >= 0 else 1
	for i in mini(n, pool.size()):
		var sp: Dictionary = pool[i]
		var at := Vector3(float(sp["pos"][0]), player.global_position.y, float(sp["pos"][1]))
		if at.distance_to(player.global_position) < 3.0 and pool.size() > n:
			continue
		Changeling.spawn_spot(scene, sp, {"mode": "night", "subtle": stage >= 3, "approach": true,
			"fast": stage >= 3 or offended, "echo": stage >= 3,
			"can_grab": stage >= 3 and night >= config.changeling_abduct_from_night})
	print("[Changeling] Nacht %d, Stufe %d, %d Stück" % [night, stage, mini(n, pool.size())])


## Tagsüber: harmlos maskiert als zweite Bank oder falscher Wegweiser – und er folgt dir zum nächsten Ort.
func _check_changeling_day(delta: float) -> void:
	_changeling_day_check -= delta
	if _changeling_day_check > 0.0:
		return
	_changeling_day_check = 15.0
	if TimeManager.is_night() or Story.phase < config.changeling_from_phase or not GameState.in_game():
		return
	var scene := get_tree().current_scene
	var player := get_tree().get_first_node_in_group("player") as Player
	if scene == null or player == null:
		return
	if _changeling_day_rolled != TimeManager.day:
		_changeling_day_rolled = TimeManager.day
		_changeling_day_wanted = _rng.randf() < config.changeling_day_chance
	if not _changeling_day_wanted:
		return
	var ch := _day_changeling as Changeling if is_instance_valid(_day_changeling) else null
	if ch:
		# Folgen: gesehen und weit hinter dir? Dann steht er beim nächsten Ort wieder da.
		if ch.was_seen and ch.dist() > config.changeling_day_distance.y and not ch.is_seen():
			ch.queue_free()
			ch = null
		else:
			return
	var spot := changeling_day_spot(player.global_position, _rng)
	if spot.is_empty():
		return
	_day_changeling = Changeling.spawn(scene, String(spot["disguise"]), spot["pos"], {"mode": "day", "subtle": _rng.randf() < 0.5})
	(_day_changeling as Changeling).face_dir(spot["face"])


## Ort für die Tagestarnung: neben einer Wanderbank (zweite Bank) oder einem Wegweiser (falsches Schild),
## in changeling_day_distance vom Spieler und nicht gerade in seinem Blick.
func changeling_day_spot(at: Vector3, rng: RandomNumberGenerator) -> Dictionary:
	var cands: Array = []
	for b: Vector3 in WorldTrails.benches:
		cands.append({"disguise": "bench", "pos": b + Vector3(2.1, 0, 0.4), "face": at - b})
	for sg: Dictionary in WorldMap.data().get("signs", []):
		var p := Vector3(float(sg["pos"][0]), 0, float(sg["pos"][1]))
		cands.append({"disguise": "signpost", "pos": p + Vector3(1.2, 0, 0.8), "face": at - p})
	for r: Dictionary in WorldMap.data().get("rest_spots", []):
		var p := Vector3(float(r["pos"][0]), 0, float(r["pos"][1]))
		cands.append({"disguise": "bench", "pos": p + Vector3(2.5, 0, -1.5), "face": at - p})
	cands.shuffle()
	var player := get_tree().get_first_node_in_group("player") as Player
	for c: Dictionary in cands:
		var p: Vector3 = c["pos"]
		var d := Vector2(p.x - at.x, p.z - at.z).length()
		if d < config.changeling_day_distance.x or d > config.changeling_day_distance.y:
			continue
		if player:
			var to := p - player.camera.global_position
			to.y = 0.0
			var f := -player.camera.global_transform.basis.z
			f.y = 0.0
			if f.normalized().dot(to.normalized()) > 0.6:
				continue
		p.y = Terrain.height_at(p.x, p.z)
		c["pos"] = p
		return c
	return {}
