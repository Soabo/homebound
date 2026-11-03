extends Node3D
## Hauptszene: setzt die Welt des ersten Spielgebiets zusammen (GDD 3.2 / 18.2).
## Die Welt wird bewusst per Code gebaut, damit alles als Text im Repo liegt.

const PLAYER_SPAWN := Vector3(-3.0, 0.0, 11.5)
const WORLD_LIMIT := 72.0


func _ready() -> void:
	add_child(DayNightEnvironment.new())
	add_child(Terrain.new())
	add_child(Forest.new())
	add_child(Garden.new())
	add_child(Cabin.new())
	add_child(Shed.new())
	_build_world_limits()

	var player := Player.new()
	player.position = PLAYER_SPAWN + Vector3(0, Terrain.height_at(PLAYER_SPAWN.x, PLAYER_SPAWN.z) + 0.05, 0)
	add_child(player)

	add_child(WindAmbience.new())
	add_child(Hud.new())
	add_child(PauseMenu.new())

	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--screenshot-tour"):
			add_child(ScreenshotTour.new())
		if arg == "--walk-test":
			add_child(WalkTest.new())


func _build_world_limits() -> void:
	var body := StaticBody3D.new()
	body.name = "WorldLimits"
	add_child(body)
	for n: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
		var cs := CollisionShape3D.new()
		var shape := WorldBoundaryShape3D.new()
		shape.plane = Plane(n, -WORLD_LIMIT)
		cs.shape = shape
		body.add_child(cs)
