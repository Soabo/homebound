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
## Schleich-Anzeige (Auge/Licht/Geräusch über dem Schnellplatz)
var stealth_hud: bool = true
## Bilder pro Sekunde: Obergrenze (0 = unbegrenzt), Bildsynchronisierung, Anzeige oben rechts (Christian 23.11.)
var max_fps: int = 0
var vsync: bool = true
var show_fps: bool = false
const FPS_CHOICES := [30, 60, 120, 144, 165, 240, 0]
var _fps_layer: CanvasLayer
var _fps_label: Label
var _fps_t := 0.0
var endings_seen: Dictionary = {}   ## Ende-ID -> Datum


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var d := defaults()
	volume = float(d.get("volume", volume))
	mouse = float(d.get("mouse", mouse))
	brightness = float(d.get("brightness", brightness))
	quality = String(d.get("quality", quality))
	fullscreen = bool(d.get("fullscreen", fullscreen))
	stealth_hud = bool(d.get("stealth_hud", stealth_hud))
	max_fps = int(d.get("max_fps", max_fps))
	vsync = bool(d.get("vsync", vsync))
	show_fps = bool(d.get("show_fps", show_fps))
	var cfg := ConfigFile.new()
	if cfg.load(FILE) == OK:
		volume = float(cfg.get_value("audio", "volume", volume))
		mouse = float(cfg.get_value("input", "mouse", mouse))
		brightness = float(cfg.get_value("video", "brightness", brightness))
		quality = String(cfg.get_value("video", "quality", quality))
		fullscreen = bool(cfg.get_value("video", "fullscreen", fullscreen))
		stealth_hud = bool(cfg.get_value("game", "stealth_hud", stealth_hud))
		max_fps = int(cfg.get_value("video", "max_fps", max_fps))
		vsync = bool(cfg.get_value("video", "vsync", vsync))
		show_fps = bool(cfg.get_value("video", "show_fps", show_fps))
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
	cfg.set_value("game", "stealth_hud", stealth_hud)
	cfg.set_value("video", "max_fps", max_fps)
	cfg.set_value("video", "vsync", vsync)
	cfg.set_value("video", "show_fps", show_fps)
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
	apply_fps()
	changed.emit()


## Bildrate: Obergrenze + Bildsynchronisierung (VSync) setzen, Anzeige ein/aus.
func apply_fps() -> void:
	Engine.max_fps = max_fps
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	if show_fps and _fps_layer == null:
		_fps_layer = CanvasLayer.new()
		_fps_layer.layer = 120
		_fps_label = Label.new()
		_fps_label.anchor_left = 1.0
		_fps_label.anchor_right = 1.0
		_fps_label.offset_left = -190
		_fps_label.offset_right = -12
		_fps_label.offset_top = 8
		_fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_fps_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_fps_label.add_theme_font_size_override("font_size", 18)
		_fps_label.add_theme_color_override("font_color", Color(0.7, 1.0, 0.6))
		_fps_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		_fps_label.add_theme_constant_override("outline_size", 6)
		_fps_layer.add_child(_fps_label)
		add_child(_fps_layer)
	if _fps_layer:
		_fps_layer.visible = show_fps


## Text einer Bildraten-Stufe, z. B. „60“ oder „Unbegrenzt“.
static func fps_name(v: int) -> String:
	return "Unbegrenzt" if v <= 0 else str(v)


func _process(delta: float) -> void:
	if not show_fps or _fps_label == null:
		return
	_fps_t -= delta
	if _fps_t <= 0.0:
		_fps_t = 0.5
		var fps := Engine.get_frames_per_second()
		_fps_label.text = "%d FPS   %.1f ms" % [fps, 1000.0 / maxf(fps, 1.0)]


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
