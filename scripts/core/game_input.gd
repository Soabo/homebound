extends Node
## Legt die Tastenbelegung beim Start an.
## Physische Tasten, damit WASD auch auf QWERTZ/AZERTY an der gleichen Stelle liegt.

const KEY_ACTIONS := {
	"move_forward": [KEY_W, KEY_UP],
	"move_back": [KEY_S, KEY_DOWN],
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"sprint": [KEY_SHIFT],
	"crouch": [KEY_C, KEY_CTRL],
	"jump": [KEY_SPACE],
	"interact": [KEY_E],
	"interact_secondary": [KEY_R],
	"flashlight": [KEY_F],
	"pause_menu": [KEY_ESCAPE],
	"toggle_help": [KEY_F1],
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
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("interact", click)


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
