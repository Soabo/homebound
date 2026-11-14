class_name EndingScreen
extends CanvasLayer
## Schluss einer Geschichte: Bild blendet ins Dunkle, die Schlussszene erscheint Zeile für Zeile
## (data/story/endings.json), danach der Abspann mit dem Namen des Endes, dann zurück ins Hauptmenü.
## Leertaste/Klick = nächste Zeile schneller. Gespeichert wird hier nichts mehr (GameState.ending_lock) –
## der Stand von vor der Entscheidung bleibt. Das erreichte Ende merkt sich Settings.reach_ending.

## Tests stellen das schneller (1.0 = normal)
static var speed: float = 1.0

var ending_id: String = ""
var _bg: ColorRect
var _text: Label
var _title: Label
var _lines: Array = []
var _credits: Array = []
var _t: float = 0.0
var _stage: String = "fade"   ## fade | lines | gift | title | credits | done
var _index: int = 0
var _line_t: float = 0.0
var _audio: AudioStreamPlayer
var finished: bool = false

const LINE_SECONDS := 4.2
const FADE_SECONDS := 2.5


func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("ending_screen")
	var data: Dictionary = Story.endings_data()
	var e: Dictionary = data.get("endings", {}).get(ending_id, {})
	_lines = (e.get("lines", []) as Array).duplicate()
	if bool(e.get("gift", false)):
		_lines.append("Darin: eine Zeichnung. Wir vier vor der Hütte, die Sonne mit Gesicht. Darunter, in Lenas Schrift: »Für Papa, damit du nicht allein bist.«")
	_credits = (data.get("credits", []) as Array).duplicate()
	var c: Array = e.get("color", [0.03, 0.03, 0.04])
	_bg = ColorRect.new()
	_bg.color = Color(float(c[0]), float(c[1]), float(c[2]), 0.0)
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_bg)
	_text = Label.new()
	_text.set_anchors_preset(Control.PRESET_FULL_RECT)
	_text.offset_left = 180
	_text.offset_right = -180
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.add_theme_font_size_override("font_size", 26)
	_text.add_theme_color_override("font_color", Color(0.86, 0.84, 0.8))
	_text.modulate.a = 0.0
	add_child(_text)
	_title = Label.new()
	_title.set_anchors_preset(Control.PRESET_FULL_RECT)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 22)
	_title.add_theme_color_override("font_color", Color(0.7, 0.68, 0.64))
	_title.modulate.a = 0.0
	add_child(_title)
	# Hintergrundklang der Szene
	var snd := String(e.get("sound", ""))
	if snd != "":
		var stream := SoundBank.get_sound(snd)
		if stream:
			_audio = AudioStreamPlayer.new()
			_audio.stream = stream
			_audio.volume_db = -14.0
			_audio.process_mode = Node.PROCESS_MODE_ALWAYS
			add_child(_audio)
			_audio.play()
	# Spiel anhalten, Steuerung sperren, Maus frei
	var player := get_tree().get_first_node_in_group("player") as Player
	if player:
		player.input_locked = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	print("[Ende] ", ending_id, " – ", e.get("title", "?"))


func _unhandled_input(event: InputEvent) -> void:
	var skip: bool = (event is InputEventKey and event.pressed and not event.echo) or (event is InputEventMouseButton and event.pressed)
	if skip and _stage == "lines":
		_line_t = maxf(_line_t, LINE_SECONDS - 0.6)
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	var d := delta * speed
	_t += d
	match _stage:
		"fade":
			_bg.color.a = clampf(_t / FADE_SECONDS, 0.0, 1.0)
			if _t >= FADE_SECONDS:
				get_tree().paused = true
				_stage = "lines"
				_index = 0
				_line_t = 0.0
				_show_line()
		"lines":
			_line_t += d
			# Zeile ein- und ausblenden
			_text.modulate.a = clampf(minf(_line_t / 0.8, (LINE_SECONDS - _line_t) / 0.6), 0.0, 1.0)
			if _line_t >= LINE_SECONDS:
				_index += 1
				_line_t = 0.0
				if _index >= _lines.size():
					_stage = "title"
					_t = 0.0
					var e: Dictionary = Story.endings_data().get("endings", {}).get(ending_id, {})
					_title.text = "Ende: %s\n\n(%s)" % [e.get("title", ending_id), _kind_text(String(e.get("kind", "")))]
					Settings.reach_ending(ending_id)
				else:
					_show_line()
		"title":
			_title.modulate.a = clampf(minf(_t / 1.2, (5.0 - _t) / 1.0), 0.0, 1.0)
			if _t >= 5.0:
				_stage = "credits"
				_t = 0.0
				_index = 0
				_line_t = 0.0
				_text.text = ""
		"credits":
			_line_t += d
			_text.text = "\n".join(_credits)
			_text.modulate.a = clampf(minf(_line_t / 1.5, (9.0 - _line_t) / 1.5), 0.0, 1.0)
			if _line_t >= 9.0:
				_stage = "done"
				_finish()


func _show_line() -> void:
	_text.text = String(_lines[_index]) if _index < _lines.size() else ""


static func _kind_text(kind: String) -> String:
	match kind:
		"gut": return "ein gutes Ende"
		"gemischt": return "ein gemischtes Ende"
		_: return "ein schlechtes Ende"


func _finish() -> void:
	finished = true
	if _audio:
		_audio.stop()
	get_tree().paused = false
	# Tests (kein Speicherplatz) bleiben im Spiel, sonst zurück ins Hauptmenü
	if GameState.slot < 0:
		queue_free()
		return
	GameState.to_menu()
	queue_free()
