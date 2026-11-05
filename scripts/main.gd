extends Node3D
## Hauptszene: setzt die Welt des ersten Spielgebiets zusammen (GDD 3.2 / 18.2).
## Die Welt wird bewusst per Code gebaut, damit alles als Text im Repo liegt.

const PLAYER_SPAWN := Vector3(-3.0, 0.0, 11.5)
const WORLD_LIMIT := 104.0


func _ready() -> void:
	add_child(DayNightEnvironment.new())
	add_child(Terrain.new())
	add_child(Forest.new())
	add_child(Garden.new())
	add_child(Cabin.new())
	add_child(Shed.new())
	add_child(CornField.new())
	add_child(CrashSite.new())
	add_child(AlienStructure.new())
	add_child(RangerTower.new())
	add_child(StreamCave.new())
	add_child(Terraformer.new())
	add_child(CarWreck.new())
	_build_world_limits()
	_build_cameras()
	Builder.spawn_all(self)
	add_child(Surveillance.new())

	var player := Player.new()
	player.position = PLAYER_SPAWN + Vector3(0, Terrain.height_at(PLAYER_SPAWN.x, PLAYER_SPAWN.z) + 0.05, 0)
	add_child(player)

	add_child(WindAmbience.new())
	add_child(NatureAmbience.new())
	add_child(RetroFilter.new())
	add_child(Hud.new())
	add_child(GameMenus.new())
	add_child(ResearchMenu.new())
	add_child(BuildController.new())
	add_child(PauseMenu.new())

	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--screenshot-tour"):
			add_child(ScreenshotTour.new())
		if arg == "--walk-test":
			add_child(WalkTest.new())
		if arg.begins_with("--night-test"):
			add_child(NightTest.new())


## Drei Überwachungskameras (GDD 18.2), jeweils fest an einer Wand montiert:
## Hausfront mit Veranda und Haustür, Garten hinten, Maisfeld am Schuppen.
func _build_cameras() -> void:
	var front_z := Cabin.HALF_Z + Cabin.LOG_R
	var setups := [
		# Name, Punkt auf der Wand, Wand-Richtung nach außen, Blickziel, Trugbild-Ort
		["Hausfront / Veranda", Vector3(5.7, Cabin.WALL_TOP - 0.35, front_z), Vector3(0, 0, 1), Vector3(-3.5, 0.5, 9.0), Vector3(-1.5, 0, 10.5)],
		["Garten hinten", Vector3(-5.0, Cabin.WALL_TOP - 0.35, -front_z), Vector3(0, 0, -1), Vector3(-9.0, 0.8, -15.0), Vector3(-13.0, 0, -14.0)],
		# an der Südwest-Ecke des Schuppens, starker Weitwinkel: links der Maisfeldrand, rechts die Hütte
		["Schuppen / Maisfeld", Vector3(Shed.ORIGIN.x - Shed.HALF.x - 0.05, 2.05, Shed.ORIGIN.z + Shed.HALF.y + 0.05), Vector3(-1, 0, 1), Vector3(5.4, 0.3, 14.4), Vector3(12.0, 0, 12.5), 106.0],
	]
	for i in setups.size():
		var cam := SecurityCamera.new()
		cam.name = "Camera%d" % (i + 1)
		cam.index = i
		cam.camera_name = setups[i][0]
		cam.position = setups[i][1]
		cam.wall_normal = setups[i][2]
		cam.look_target = setups[i][3]
		cam.phantom_spot = setups[i][4]
		if setups[i].size() > 5:
			cam.fov = setups[i][5]
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
