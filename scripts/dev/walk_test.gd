class_name WalkTest
extends Node
## Entwickler-Test: Läuft der Spieler durch die offenen Türen und das Tor?
## Start: godot --headless --path . -- --walk-test

const CASES := [
	{"name": "Haustür rein", "door": "Cabin/FrontDoor", "from": Vector3(-3.0, 0.5, 6.0), "yaw": 0.0, "check": "z", "target": 3.5},
	{"name": "Schuppentür rein", "door": "Shed/ShedDoor", "from": Vector3(10.5, 0.1, 6.5), "yaw": -90.0, "check": "x", "target": 13.5},
	{"name": "Tor zur Straße", "door": "", "from": Vector3(-3.0, 0.1, 14.0), "yaw": 180.0, "check": "z", "target": 21.0},
	{"name": "Wohnzimmer -> Schlafzimmer", "door": "", "from": Vector3(-2.5, 0.5, 0.2), "yaw": 0.0, "check": "z", "target": -2.0},
	{"name": "Wohnzimmer -> Vorratsraum", "door": "", "from": Vector3(0.5, 0.5, 0.6), "yaw": 0.0, "check": "z", "target": -2.0},
	{"name": "Wohnzimmer -> Werkstatt", "door": "", "from": Vector3(0.8, 0.5, 1.5), "yaw": -90.0, "check": "x", "target": 3.0},
	{"name": "Werkstatt -> Technikraum", "door": "", "from": Vector3(4.0, 0.5, 1.0), "yaw": 0.0, "check": "z", "target": -2.5},
]


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	for i in 10:
		await get_tree().physics_frame
	var player := get_tree().get_first_node_in_group("player") as Player
	var main := get_tree().current_scene
	var failed := 0
	for c: Dictionary in CASES:
		if c["door"] != "":
			var door := main.get_node(c["door"]) as Door
			door.set_open(true)
			for i in 60:
				await get_tree().physics_frame
		player.global_position = c["from"]
		player.velocity = Vector3.ZERO
		player.rotation_degrees.y = c["yaw"]
		Input.action_press("move_forward")
		for i in 240:
			await get_tree().physics_frame
		Input.action_release("move_forward")
		var v: float = player.global_position.z if c["check"] == "z" else player.global_position.x
		var target: float = c["target"]
		var ok := v < target if target < c["from"][2 if c["check"] == "z" else 0] else v > target
		print("%s: %s (Position %.2f, Ziel %.2f)" % [c["name"], "OK" if ok else "FEHLER", v, target])
		if not ok:
			failed += 1
	print("WALK TEST: %d Fehler" % failed)
	get_tree().quit(failed)
