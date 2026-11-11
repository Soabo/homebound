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
## Gespeichert wird automatisch jeden Morgen und beim Beenden (Pause → Hauptmenü/Beenden, Fenster schließen).
## Eine Datei enthält den aktuellen Stand und den Tagesbeginn – stirbt man nach dem Laden, geht es
## an den Anfang des Tages zurück (wie bisher).

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
var slot: int = -1                 ## aktiver Speicherplatz (-1 = keiner, z. B. in Tests)
var play_seconds: float = 0.0      ## gespielte Zeit in diesem Spielstand


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	TimeManager.phase_changed.connect(_on_phase_changed)
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
	if not is_night and not _restoring:
		take_snapshot()
		if in_game():
			save_game(false)  # Autospeichern am Morgen


func take_snapshot() -> void:
	_snapshot = take_state()


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
	player_died.emit()
	PlayerSounds.play(self, "die", 0.0)
	await get_tree().create_timer(4.5).timeout
	restart_day()


func restart_day() -> void:
	# Kopie verwenden: das Zurückstellen der Uhr löst sonst einen neuen Schnappschuss aus
	_apply(_snapshot.duplicate(true), _snapshot.duplicate(true))
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
	_pending_world = snap.get("world", {})
	_snapshot = morning
	_restoring = false
	ThreatDirector.reset_for_new_scene()
	dead = false
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
	if slot < 0 or dead:
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
func new_game(n: int) -> void:
	slot = n
	play_seconds = 0.0
	_apply(_fresh.duplicate(true), _fresh.duplicate(true))
	get_tree().change_scene_to_file(GAME_SCENE)
	# gleich einmal sichern, damit „Fortsetzen“ den Platz kennt
	await get_tree().create_timer(1.0).timeout
	take_snapshot()
	save_game(false)


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


## Zurück ins Hauptmenü (vorher speichern).
func to_menu() -> void:
	if in_game():
		save_game(true)
	get_tree().paused = false
	get_tree().change_scene_to_file(MENU_SCENE)


## Spiel beenden (vorher speichern).
func quit_game() -> void:
	if in_game():
		save_game(true)
	get_tree().quit()
