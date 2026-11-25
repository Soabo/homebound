extends Node
## Spielstand-Grundlage (GDD 14): merkt sich den Zustand zu Tagesbeginn.
## Stirbt der Spieler, geht es zurück an den Anfang dieses Tages – inklusive
## Barrikaden, Bauten und allem, was bis dahin eingesammelt war.
##
## Objekte mit Zustand gehören zur Gruppe "persistent" und bieten
## persist_key(), get_state() und set_state(). Sie holen sich ihren
## gespeicherten Zustand in _ready() über GameState.restore(self).
##
## Phase 9 (Christians Entscheidung): 3 Speicherplätze auf der Platte (user://saves/slot_N.save).
## Seit 25.11. (Christian): Gespeichert wird nach JEDEM Schlaf (Bett und Zelt) und zusätzlich jeden Morgen
## automatisch (Tagesbeginn) – nicht beim Beenden. Ein Tod führt zurück zum letzten Speicherstand.
## (Ausnahmen: neues Spiel legt den Platz an, vor einem Ende wird gesichert.)

signal player_died
signal day_restarted
signal saved(slot: int)

const SAVE_DIR := "user://saves/"
const SLOTS := 3
const SAVE_VERSION := 1
const GAME_SCENE := "res://scenes/main.tscn"
const MENU_SCENE := "res://scenes/main_menu.tscn"

var _snapshot: Dictionary = {}
var _pending_world: Dictionary = {}
var _fresh: Dictionary = {}        ## Zustand beim Programmstart (für „Neues Spiel“)
var dead: bool = false
## Ein Ende läuft: nichts mehr speichern (Story.start_ending)
var ending_lock: bool = false
var slot: int = -1                 ## aktiver Speicherplatz (-1 = keiner, z. B. in Tests)
var play_seconds: float = 0.0      ## gespielte Zeit in diesem Spielstand


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	TimeManager.phase_changed.connect(_on_phase_changed)
	EventBus.sleep_finished.connect(_on_slept)
	get_tree().set_auto_accept_quit(false)
	take_snapshot.call_deferred()
	(func() -> void: _fresh = _snapshot.duplicate(true)).call_deferred()


func _process(delta: float) -> void:
	if in_game() and not get_tree().paused and not dead:
		play_seconds += delta


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		quit_game()


## Läuft gerade das Spiel (nicht das Hauptmenü)?
func in_game() -> bool:
	var sc := get_tree().current_scene
	return sc != null and sc.scene_file_path == GAME_SCENE


var _restoring: bool = false


func _on_phase_changed(is_night: bool) -> void:
	# Jeden Morgen automatisch speichern (Christian 25.11.). Wer gerade schläft, wird beim Aufwachen gesichert.
	if is_night or dead or ending_lock or _restoring or EventBus.sleeping or not in_game():
		return
	(func() -> void:
		if not dead and not EventBus.sleeping:
			bed_save()).call_deferred()


## Nach jedem Schlaf (Bett, Zelt) speichern.
func _on_slept() -> void:
	if dead or not in_game():
		return
	bed_save()


## Geschlafen (Bett/Zelt) oder Morgen: jetzt wird gespeichert, und hierher führt ein Tod zurück.
var bed_day: int = 1
var bed_hour: float = 7.0


func bed_save() -> void:
	if dead or ending_lock:
		return
	take_snapshot()
	bed_day = TimeManager.day
	bed_hour = TimeManager.hour
	if in_game() and save_game(false):
		EventBus.notify("Gespeichert.", 2.0)


func take_snapshot() -> void:
	_snapshot = take_state()
	bed_day = int(_snapshot.get("day", 1))
	bed_hour = float(_snapshot.get("hour", 7.0))


## Der komplette Zustand jetzt (alle Manager + alle persistenten Objekte der Welt).
func take_state() -> Dictionary:
	return {
		"day": TimeManager.day,
		"hour": TimeManager.hour,
		"power": PowerManager.get_state(),
		"inventory": Inventory.get_state(),
		"survival": Survival.get_state(),
		"builds": Builder.get_state(),
		"research": Research.get_state(),
		"world_state": WorldState.get_state(),
		"threat": ThreatDirector.get_state(),
		"supplies": Supplies.get_state(),
		"tasks": Tasks.get_state(),
		"story": Story.get_state(),
		"journal": Journal.get_state(),
		"world": collect_world(),
	}


func collect_world() -> Dictionary:
	var world := {}
	for n in get_tree().get_nodes_in_group("persistent"):
		world[n.call("persist_key")] = n.call("get_state")
	return world


## Von persistenten Objekten in _ready() aufgerufen.
func restore(node: Node) -> void:
	var key: String = node.call("persist_key")
	if _pending_world.has(key):
		node.call("set_state", _pending_world[key])


func kill_player() -> void:
	if dead:
		return
	dead = true
	_death_go = false
	var pl := get_tree().get_first_node_in_group("player")
	print("[GameState] Tod am Tag %d, %s: %s" % [TimeManager.day, TimeManager.get_clock_text(), String(pl.get("death_cause")) if pl else "?"])
	player_died.emit()
	PlayerSounds.play(self, "die", 0.0)
	# Todes-Bildschirm (Ursache + Ratschläge): im Spiel weiter mit E/Leertaste/Klick (spätestens nach DEATH_MAX_WAIT),
	# in Tests ohne Speicherplatz nach 4,5 s wie bisher
	var waited := 0.0
	var limit := 4.5 if slot < 0 else DEATH_MAX_WAIT
	while waited < limit and not (_death_go and waited > DEATH_MIN_WAIT):
		await get_tree().process_frame
		waited += get_process_delta_time()
	restart_day()


const DEATH_MIN_WAIT := 2.5
const DEATH_MAX_WAIT := 60.0
var _death_go := false


## Todes-Bildschirm: „Weiter“ gedrückt.
func death_continue() -> void:
	_death_go = true


## revive = false nur für Tests (Sichern/Laden vergleichen): sonst wacht man nach einem Tod überlebensfähig auf.
func restart_day(revive: bool = true) -> void:
	# Kopie verwenden: das Zurückstellen der Uhr löst sonst einen neuen Schnappschuss aus
	_apply(_snapshot.duplicate(true), _snapshot.duplicate(true))
	if revive:
		Survival.make_survivable()
	get_tree().reload_current_scene()
	day_restarted.emit()


## Stellt alle Manager auf einen Stand und merkt sich die Welt für die neu geladene Szene.
## morning = Tagesbeginn für einen späteren Tod.
func _apply(snap: Dictionary, morning: Dictionary) -> void:
	_restoring = true
	TimeManager.set_time(int(snap.get("day", 1)), float(snap.get("hour", TimeManager.config.wake_up_hour)))
	PowerManager.set_state(snap.get("power", {}))
	Inventory.set_state(snap.get("inventory", {}))
	Survival.set_state(snap.get("survival", {}))
	Builder.set_state(snap.get("builds", []))
	Research.set_state(snap.get("research", {}))
	WorldState.set_state(snap.get("world_state", {}))
	if snap.has("threat"):
		ThreatDirector.set_state(snap["threat"])
	Supplies.set_state(snap.get("supplies", {}))
	Tasks.set_state(snap.get("tasks", {}))
	Story.set_state(snap.get("story", {}))
	Journal.set_state(snap.get("journal", {}))
	_pending_world = snap.get("world", {})
	_snapshot = morning
	bed_day = int(morning.get("day", 1))
	bed_hour = float(morning.get("hour", 7.0))
	_restoring = false
	ThreatDirector.reset_for_new_scene()
	dead = false
	ending_lock = false
	EventBus.sleeping = false
	get_tree().paused = false


# --- Speicherplätze -------------------------------------------------------

static func slot_path(n: int) -> String:
	return SAVE_DIR + "slot_%d.save" % n


## Kurzinfo eines Platzes für das Menü ({} = leer): day, hour, saved_at, play_seconds.
func slot_info(n: int) -> Dictionary:
	var data := _read(n)
	return data.get("meta", {}) if not data.is_empty() else {}


func _read(n: int) -> Dictionary:
	if not FileAccess.file_exists(slot_path(n)):
		return {}
	var f := FileAccess.open(slot_path(n), FileAccess.READ)
	if f == null:
		return {}
	var v: Variant = f.get_var(false)
	return v if v is Dictionary else {}


## Speichert in den aktiven Platz. current = true: der Stand jetzt (beim Beenden), sonst der Tagesbeginn.
func save_game(current: bool = true) -> bool:
	# Während eines Endes wird nichts mehr gespeichert: der Stand von vor der Entscheidung bleibt
	if slot < 0 or dead or ending_lock:
		return false
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var now := take_state() if current else _snapshot.duplicate(true)
	var data := {
		"version": SAVE_VERSION,
		"meta": {"day": int(now.get("day", 1)), "hour": float(now.get("hour", 7.0)), "play_seconds": play_seconds,
			"saved_at": Time.get_datetime_string_from_system(false, true)},
		"current": now,
		"morning": _snapshot,
	}
	var f := FileAccess.open(slot_path(slot), FileAccess.WRITE)
	if f == null:
		return false
	f.store_var(data, false)
	f.close()
	saved.emit(slot)
	return true


## Lädt einen Platz und startet das Spiel dort.
func load_game(n: int) -> bool:
	var data := _read(n)
	if data.is_empty():
		return false
	slot = n
	play_seconds = float(data.get("meta", {}).get("play_seconds", 0.0))
	_apply(data.get("current", {}), data.get("morning", data.get("current", {})))
	get_tree().change_scene_to_file(GAME_SCENE)
	return true


## Neues Spiel in einen Platz (überschreibt ihn beim ersten Speichern).
## start_day > 1 = Teststart (Hauptmenü): gleich an diesem Tag, mit Zelt, Schlafsack und Marschgepäck.
func new_game(n: int, start_day: int = 1) -> void:
	slot = n
	play_seconds = 0.0
	_apply(_fresh.duplicate(true), _fresh.duplicate(true))
	get_tree().change_scene_to_file(GAME_SCENE)
	# gleich einmal sichern, damit „Fortsetzen“ den Platz kennt
	await get_tree().create_timer(1.0).timeout
	if start_day > 1:
		test_start(start_day)
	take_snapshot()
	save_game(false)


## Teststart (Christian 14.11.): Nächte bis start_day fortschreiben, Tag start_day um TEST_START_HOUR,
## volles Marschgepäck. Heute Nacht keine Belagerung, damit man draußen zelten kann.
const TEST_START_HOUR := 14.0
const TEST_KIT := {"tent": 1, "sleeping_bag": 1, "campfire": 1, "wood": 6, "food": 4, "water": 4,
		"hiking_map": 1, "axe": 1, "medkit": 1, "planks": 2, "nails": 6}


func test_start(day: int) -> void:
	for d in range(TimeManager.day, day):
		ThreatDirector.plan_night(d)   # Spannungsbogen der übersprungenen Nächte fortschreiben
		TimeManager.set_time(d + 1, 8.0)
		WorldState._on_day_changed(d + 1)
	ThreatDirector.last_siege_day = day   # heute Nacht keine Belagerung
	# Spätherbst: der erste Schnee ist längst gefallen
	WorldState.first_snow_done = true
	WorldState.snow = 0.6
	ThreatDirector._arc_day = -1
	ThreatDirector._planned_for_day = -1
	TimeManager.set_time(day, TEST_START_HOUR)
	ThreatDirector._on_phase_changed(false)
	Survival.hunger = 100.0
	Survival.thirst = 100.0
	Survival.warmth = 100.0
	Survival.stamina = Survival.STAMINA_MAX
	for id: String in TEST_KIT:
		Inventory.add(id, int(TEST_KIT[id]))
	var player := get_tree().get_first_node_in_group("player") as Player
	if player:
		player.health = Player.MAX_HEALTH
	EventBus.notify("TEST: Tag %d, %s. Im Rucksack: Zelt, Schlafsack, Lagerfeuer, Holz, Essen, Wasser, Wanderkarte. Bau das Zelt draußen mit B auf (weit weg von der Hütte)." % [day, TimeManager.get_clock_text()], 9.0)


func delete_slot(n: int) -> void:
	if FileAccess.file_exists(slot_path(n)):
		DirAccess.remove_absolute(slot_path(n))


## Der zuletzt gespeicherte Platz (-1 = keiner) – für „Fortsetzen“.
func latest_slot() -> int:
	var best := -1
	var best_t := ""
	for n in SLOTS:
		var i := slot_info(n)
		if not i.is_empty() and String(i.get("saved_at", "")) > best_t:
			best_t = String(i.get("saved_at", ""))
			best = n
	return best


## Zurück ins Hauptmenü (ohne Speichern – gespeichert wird nur im Bett).
func to_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(MENU_SCENE)


## Spiel beenden (ohne Speichern – gespeichert wird nur im Bett).
func quit_game() -> void:
	get_tree().quit()
