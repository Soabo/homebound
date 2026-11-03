extends Node
## Spielstand-Grundlage (GDD 14.1): merkt sich den Zustand zu Tagesbeginn.
## Stirbt der Spieler, geht es zurück an den Anfang dieses Tages.
## (Wird später zum vollwertigen Save Manager ausgebaut.)

signal player_died
signal day_restarted

var _snapshot: Dictionary = {}
var dead: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	TimeManager.phase_changed.connect(func(is_night: bool) -> void:
		if not is_night:
			take_snapshot())
	take_snapshot.call_deferred()


func take_snapshot() -> void:
	_snapshot = {
		"day": TimeManager.day,
		"hour": TimeManager.hour,
		"power": PowerManager.get_state(),
		"inventory": Inventory.get_state(),
	}


func kill_player() -> void:
	if dead:
		return
	dead = true
	player_died.emit()
	SoundBank.play_ui(self, "hurt", 2.0, 0.7)
	await get_tree().create_timer(4.5).timeout
	restart_day()


func restart_day() -> void:
	TimeManager.set_time(int(_snapshot.get("day", 1)), float(_snapshot.get("hour", TimeManager.config.wake_up_hour)))
	PowerManager.set_state(_snapshot.get("power", {}))
	Inventory.set_state(_snapshot.get("inventory", {}))
	ThreatDirector.reset_for_new_scene()
	dead = false
	get_tree().paused = false
	get_tree().reload_current_scene()
	day_restarted.emit()
