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
## Grafikstil: retro (grobe Pixel, wie bisher) | klar (volle Auflösung, weiche Texturen, abgeschrägte Kanten) – Christian 25.11.
var look: String = "klar"
const LOOKS := ["retro", "klar"]
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
	look = String(d.get("look", look))
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
		look = String(cfg.get_value("video", "look", look))
		endings_seen = cfg.get_value("profile", "endings", {})
	# Befehlszeile (Vergleichsbilder, Tests): -- --look=klar
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--look="):
			look = a.substr(7)
	if not look in LOOKS:
		look = "retro"
	# vor dem Weltaufbau setzen – Texturen, Kanten und Shader richten sich danach
	Look.set_style(look)
	Look.patch_shaders()
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
	cfg.set_value("video", "look", look)
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
	RenderingServer.directional_shadow_atlas_set_size(int(q.get("shadow_size", 4096)), true)
	var rf := get_tree().get_first_node_in_group("retro_filter") if is_inside_tree() else null
	if rf:
		rf.call("set_look", look)
	apply_render_scale()
	apply_fps()
	changed.emit()


## Wie fein die 3D-Welt berechnet wird – EINE Stelle für Grafikstufe und Retro-Filter (vorher überschrieb die
## Grafikstufe die Einsparung des Filters: auf Christians 5120×1440-Bildschirm wurde alles in voller Größe + MSAA gerechnet).
## Mit Retro-Filter: nur so viele Zeilen, wie der Filter zeigt × retro_oversample (Stufe), ohne MSAA (die Retro-Pixel
## glätten ohnehin). Ohne Filter: Faktor "scale" der Stufe + MSAA der Stufe.
func apply_render_scale() -> void:
	var vp := get_viewport()
	var q := quality_values()
	var retro := get_tree().get_first_node_in_group("retro_filter") if is_inside_tree() else null
	var retro_on := retro != null and bool(retro.get("enabled")) and look == "retro"
	var scale := float(q.get("scale", 1.0))
	var msaa := int(q.get("msaa", 2))
	var h := float(vp.get_visible_rect().size.y)
	if retro_on and h > 0.0:
		var lines := RetroFilter.VIRTUAL_HEIGHT * float(q.get("retro_oversample", 1.5))
		scale = clampf(lines / h, 0.25, 1.0)
		msaa = 0
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	vp.scaling_3d_scale = scale
	vp.msaa_3d = Viewport.MSAA_4X if msaa >= 4 else (Viewport.MSAA_2X if msaa >= 2 else Viewport.MSAA_DISABLED)
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED if retro_on else Viewport.SCREEN_SPACE_AA_FXAA


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
		_fps_label.offset_left = -420
		_fps_label.offset_right = -12
		_fps_label.offset_top = 76   # unter der Uhrzeit (Hud._clock)
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
	# Rechenzeit der Grafikkarte messen (nur mit Anzeige – kostet sonst nichts)
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), show_fps)


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
		# CPU- und Grafikkarten-Zeit pro Bild: zeigt, ob der Bildschirm (Bildsync) bremst oder wirklich die Rechenzeit
		var rid := get_viewport().get_viewport_rid()
		var cpu := RenderingServer.viewport_get_measured_render_time_cpu(rid) + RenderingServer.get_frame_setup_time_cpu()
		var gpu := RenderingServer.viewport_get_measured_render_time_gpu(rid)
		var hz := DisplayServer.screen_get_refresh_rate() if DisplayServer.get_name() != "headless" else -1.0
		var line2 := ""
		if vsync and hz > 0.0:
			line2 = "\nBildsync an – Bildschirm %d Hz" % int(round(hz))
		elif max_fps > 0:
			line2 = "\nObergrenze %d" % max_fps
		# Welche Grafikkarte rechnet, in welcher Größe (3D-Auflösung nach Grafikstufe/Retro-Filter)
		var vp := get_viewport()
		var size := vp.get_visible_rect().size * vp.scaling_3d_scale
		var line3 := "\n%s – 3D %d×%d" % [RenderingServer.get_video_adapter_name(), int(size.x), int(size.y)]
		_fps_label.text = "%d FPS   CPU %.1f ms   GPU %.1f ms%s%s" % [fps, cpu, gpu, line2, line3]


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
