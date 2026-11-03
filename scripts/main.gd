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
	_build_cameras()
	add_child(Surveillance.new())

	var player := Player.new()
	player.position = PLAYER_SPAWN + Vector3(0, Terrain.height_at(PLAYER_SPAWN.x, PLAYER_SPAWN.z) + 0.05, 0)
	add_child(player)

	add_child(WindAmbience.new())
	add_child(NatureAmbience.new())
	add_child(RetroFilter.new())
	add_child(Hud.new())
	add_child(PauseMenu.new())

	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--screenshot-tour"):
			add_child(ScreenshotTour.new())
		if arg == "--walk-test":
			add_child(WalkTest.new())
		if arg.begins_with("--night-test"):
			add_child(NightTest.new())


## Drei Überwachungskameras (GDD 18.2): Veranda/Zufahrt, Garten hinten, Schuppen/Osten.
func _build_cameras() -> void:
	var setups := [
		["Veranda / Zufahrt", Vector3(1.65, 2.45, 7.25), Vector3(-3.0, 0.8, 18.0), Vector3(-7.0, 0, 16.0)],
		["Garten hinten", Vector3(-5.6, 2.95, -4.85), Vector3(-9.0, 0.8, -15.0), Vector3(-13.0, 0, -14.0)],
		["Schuppen / Osten", Vector3(11.85, 2.25, 4.85), Vector3(18.0, 0.5, -10.0), Vector3(20.0, 0, -12.0)],
	]
	for i in setups.size():
		var cam := SecurityCamera.new()
		cam.name = "Camera%d" % (i + 1)
		cam.index = i
		cam.camera_name = setups[i][0]
		cam.look_target = setups[i][2]
		cam.phantom_spot = setups[i][3]
		cam.position = setups[i][1]
		add_child(cam)


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
