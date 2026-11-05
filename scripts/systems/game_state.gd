extends Node
## Spielstand-Grundlage (GDD 14): merkt sich den Zustand zu Tagesbeginn.
## Stirbt der Spieler, geht es zurück an den Anfang dieses Tages – inklusive
## Barrikaden, Bauten und allem, was bis dahin eingesammelt war.
##
## Objekte mit Zustand gehören zur Gruppe "persistent" und bieten
## persist_key(), get_state() und set_state(). Sie holen sich ihren
## gespeicherten Zustand in _ready() über GameState.restore(self).
## (Wird später zum Speichern auf die Festplatte erweitert.)

signal player_died
signal day_restarted

var _snapshot: Dictionary = {}
var _pending_world: Dictionary = {}
var dead: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	TimeManager.phase_changed.connect(_on_phase_changed)
	take_snapshot.call_deferred()


var _restoring: bool = false


func _on_phase_changed(is_night: bool) -> void:
	if not is_night and not _restoring:
		take_snapshot()


func take_snapshot() -> void:
	_snapshot = {
		"day": TimeManager.day,
		"hour": TimeManager.hour,
		"power": PowerManager.get_state(),
		"inventory": Inventory.get_state(),
		"survival": Survival.get_state(),
		"builds": Builder.get_state(),
		"research": Research.get_state(),
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
	var snap := _snapshot.duplicate(true)
	_restoring = true
	TimeManager.set_time(int(snap.get("day", 1)), float(snap.get("hour", TimeManager.config.wake_up_hour)))
	PowerManager.set_state(snap.get("power", {}))
	Inventory.set_state(snap.get("inventory", {}))
	Survival.set_state(snap.get("survival", {}))
	Builder.set_state(snap.get("builds", []))
	Research.set_state(snap.get("research", {}))
	_pending_world = snap.get("world", {})
	_snapshot = snap
	_restoring = false
	ThreatDirector.reset_for_new_scene()
	dead = false
	get_tree().paused = false
	get_tree().reload_current_scene()
	day_restarted.emit()
