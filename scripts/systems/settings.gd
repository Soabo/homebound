extends Node
## Einstellungen (Phase 9): Lautstärke, Maus, Helligkeit, Grafik, Vollbild – und die gesehenen Enden.
## Startwerte in data/settings/default_settings.json, gespeichert in user://settings.cfg (gilt für alle Spielstände).

signal changed

const FILE := "user://settings.cfg"

var volume: float = 0.85
var mouse: float = 1.0
var brightness: float = 1.0
var quality: String = "high"
var fullscreen: bool = true
var endings_seen: Dictionary = {}   ## Ende-ID -> Datum


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var d := defaults()
	volume = float(d.get("volume", volume))
	mouse = float(d.get("mouse", mouse))
	brightness = float(d.get("brightness", brightness))
	quality = String(d.get("quality", quality))
	fullscreen = bool(d.get("fullscreen", fullscreen))
	var cfg := ConfigFile.new()
	if cfg.load(FILE) == OK:
		volume = float(cfg.get_value("audio", "volume", volume))
		mouse = float(cfg.get_value("input", "mouse", mouse))
		brightness = float(cfg.get_value("video", "brightness", brightness))
		quality = String(cfg.get_value("video", "quality", quality))
		fullscreen = bool(cfg.get_value("video", "fullscreen", fullscreen))
		endings_seen = cfg.get_value("profile", "endings", {})
	apply.call_deferred()


func defaults() -> Dictionary:
	return DataDB.load_json("res://data/settings/default_settings.json")


func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "volume", volume)
	cfg.set_value("input", "mouse", mouse)
	cfg.set_value("video", "brightness", brightness)
	cfg.set_value("video", "quality", quality)
	cfg.set_value("video", "fullscreen", fullscreen)
	cfg.set_value("profile", "endings", endings_seen)
	cfg.save(FILE)


## Wendet alles an, was nicht von selbst nachgelesen wird (Lautstärke, Vollbild, Auflösung).
func apply() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.0001)))
	AudioServer.set_bus_mute(0, volume <= 0.001)
	if OS.get_name() != "Web" and DisplayServer.get_name() != "headless":
		var want := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
		var now := DisplayServer.window_get_mode()
		var is_full := now == DisplayServer.WINDOW_MODE_FULLSCREEN or now == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
		if is_full != fullscreen:
			DisplayServer.window_set_mode(want)
	var q := quality_values()
	get_viewport().scaling_3d_scale = float(q.get("scale", 1.0))
	RenderingServer.directional_shadow_atlas_set_size(int(q.get("shadow_size", 4096)), true)
	changed.emit()


func quality_values() -> Dictionary:
	return defaults().get("quality_levels", {}).get(quality, {})


func set_value(key: String, value: Variant) -> void:
	set(key, value)
	save()
	apply()


# --- Enden -------------------------------------------------------------

func endings() -> Array:
	return defaults().get("endings", [])


## Später von der Story aufgerufen, wenn ein Ende erreicht wird.
func reach_ending(id: String) -> void:
	if not endings_seen.has(id):
		endings_seen[id] = Time.get_date_string_from_system()
		save()
