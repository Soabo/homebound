extends Node
## Legt die Tastenbelegung beim Start an.
## Physische Tasten, damit WASD auch auf QWERTZ/AZERTY an der gleichen Stelle liegt.

const KEY_ACTIONS := {
	"move_forward": [KEY_W, KEY_UP],
	"move_back": [KEY_S, KEY_DOWN],
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"sprint": [KEY_SHIFT],
	"walk_slow": [KEY_ALT],
	"crouch": [KEY_C, KEY_CTRL],
	"jump": [KEY_SPACE],
	"interact": [KEY_E],
	"interact_secondary": [KEY_R],
	"flashlight": [KEY_F],
	"pause_menu": [KEY_ESCAPE],
	"toggle_help": [KEY_F1],
	"toggle_retro": [KEY_F2],
	"inventory": [KEY_TAB, KEY_I],
	"build": [KEY_B],
	"archive": [KEY_J],
	"toggle_fullscreen": [KEY_F11],
	"debug_time_fast": [KEY_T],
}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for action: String in KEY_ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key: int in KEY_ACTIONS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)
	# Maus: links = Angriff/Benutzen des Gegenstands in der Hand, rechts = Blocken,
	# Mausrad = Schnellplatz wechseln
	for pair: Array in [["attack", MOUSE_BUTTON_LEFT], ["block", MOUSE_BUTTON_RIGHT],
			["slot_prev", MOUSE_BUTTON_WHEEL_UP], ["slot_next", MOUSE_BUTTON_WHEEL_DOWN]]:
		if not InputMap.has_action(pair[0]):
			InputMap.add_action(pair[0])
		var mb := InputEventMouseButton.new()
		mb.button_index = pair[1]
		InputMap.action_add_event(pair[0], mb)
	# Ziffern 1–9: Schnellplätze
	for i in 9:
		var action := "slot_%d" % (i + 1)
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		var ev := InputEventKey.new()
		ev.physical_keycode = KEY_1 + i
		InputMap.action_add_event(action, ev)
	Engine.max_fps = FPS_LIMIT


## Obergrenze für Bilder pro Sekunde: schont Grafikkarte und Akku
## (ohne Grenze rechnet ein schneller Laptop sonst mit 165+ Bildern pro Sekunde).
const FPS_LIMIT := 60
## Im Hintergrund (anderes Fenster aktiv) fast nichts mehr zeichnen.
const FPS_BACKGROUND := 10


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		Engine.max_fps = FPS_BACKGROUND
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		Engine.max_fps = FPS_LIMIT


func _process(_delta: float) -> void:
	# Test-Hilfe: T gedrückt halten spult die Zeit vor.
	TimeManager.fast_forward = not get_tree().paused and Input.is_action_pressed("debug_time_fast")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_fullscreen"):
		var mode := DisplayServer.window_get_mode()
		if mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
