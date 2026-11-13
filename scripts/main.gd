extends Node3D
## Hauptszene: setzt die Welt des ersten Spielgebiets zusammen (GDD 3.2 / 18.2).
## Die Welt wird bewusst per Code gebaut, damit alles als Text im Repo liegt.

const PLAYER_SPAWN := Vector3(-3.0, 0.0, 11.5)
const WORLD_LIMIT := 1100.0


func _ready() -> void:
	add_child(DayNightEnvironment.new())
	add_child(Terrain.new())
	add_child(Forest.new())
	add_child(WildForest.new())
	add_child(WorldTrails.new())
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
	add_child(NightChanges.new())
	add_child(InsideChanges.new())
	add_child(Wildlife.new())
	add_child(ScrapField.new())
	add_child(SupplyProps.new())
	add_child(Places.new())
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
	add_child(TabletMenu.new())
	add_child(MapScreen.new())
	add_child(W17Locator.new())
	add_child(GadgetHud.new())
	add_child(AlienDrops.new())
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
## Überwachungskameras baut der Spieler selbst ein (Kamera 1–3 finden, außen anbringen) – siehe Surveillance/Supplies.
func _build_cameras() -> void:
	pass


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
