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
	{"name": "Werkstatt -> Bad", "door": "", "from": Vector3(4.0, 0.5, 1.0), "yaw": 0.0, "check": "z", "target": -2.5},
	{"name": "Vorratsraum -> Büro", "door": "", "from": Vector3(0.5, 0.5, -2.0), "yaw": 0.0, "check": "z", "target": -6.5},
	{"name": "Wohnzimmer -> Kinderzimmer", "door": "", "from": Vector3(-4.6, 0.5, -0.05), "yaw": 90.0, "check": "x", "target": -7.5},
]


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	for i in 10:
		await get_tree().physics_frame
	var player := get_tree().get_first_node_in_group("player") as Player
	var main := get_tree().current_scene
	var failed := 0
	# --lab: komplett ausgebautes Labor im Bad – darf weder Tür noch Fenster verstellen
	if "--lab" in OS.get_cmdline_user_args():
		Research.lab_built = true
		Research.lab_stations = ["bench", "microscope", "terrarium", "shield", "screen"]
		Research.charger_built = true
		Research.changed.emit()
		for i in 5:
			await get_tree().physics_frame
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
	# Jedes Fenster erreichbar? Spielerkörper direkt davor darf nirgends anstoßen
	for w in get_tree().get_nodes_in_group("entry_point"):
		if not w is CabinWindow:
			continue
		var inner: Vector3 = w.call("inside_point")
		var out: Vector3 = w.call("outside_point")
		var dir := (inner - out)
		dir.y = 0.0
		dir = dir.normalized()
		var wp := (w as Node3D).global_position
		var stand := Vector3(wp.x, Cabin.FLOOR_Y, wp.z) + dir * 0.6
		var q := PhysicsShapeQueryParameters3D.new()
		var cap := CapsuleShape3D.new()
		cap.radius = 0.32
		cap.height = 1.6
		q.shape = cap
		q.transform = Transform3D(Basis(), stand + Vector3(0, 0.85, 0))
		q.exclude = [player.get_rid()]
		var hits := []
		for r in player.get_world_3d().direct_space_state.intersect_shape(q, 8):
			hits.append(String((r["collider"] as Node).get_parent().name) + " bei " + str(((r["collider"] as Node3D).global_position).snapped(Vector3(0.1, 0.1, 0.1))))
		print("FENSTER %s: %s" % [w.name, "frei" if hits.is_empty() else "verstellt von " + ", ".join(hits)])
		if not hits.is_empty():
			failed += 1
	if "--stream" in OS.get_cmdline_user_args():
		failed += await _stream_walk(player)
	print("WALK TEST: %d Fehler" % failed)
	get_tree().quit(failed)


## Läuft das Bachbett von Norden nach Süden entlang und meldet Stellen, an denen man hängen bleibt.
func _stream_walk(player: Player) -> int:
	var stuck := 0
	# Ufer überall über dem Wasser? (Gelände per Strahl von oben gemessen, wie es wirklich gebaut ist)
	var low := 0
	var worst := 0.0
	var ez := -100.0
	while ez < 100.0:
		for sgn: float in [-1.0, 1.0]:
			var ex := Terrain.stream_x_at(ez) + sgn * (Terrain.WATER_HALF_WIDTH + 0.05)
			var q := PhysicsRayQueryParameters3D.create(Vector3(ex, 60, ez), Vector3(ex, -60, ez))
			q.collide_with_areas = false
			var hit := player.get_world_3d().direct_space_state.intersect_ray(q)
			if not hit.is_empty():
				var d := (hit["position"] as Vector3).y - (Terrain.stream_bed_height(ez) + Terrain.WATER_LEVEL)
				if d < 0.0:
					low += 1
					worst = minf(worst, d)
		ez += 0.5
	print("BACH Uferkante unter Wasser: %d Stellen, schlimmste %.2f m" % [low, worst])
	for side: float in [0.0, -1.6, 1.6]:
		var z := -96.0
		player.global_position = Vector3(Terrain.stream_x_at(z) + side, Terrain.height_at(Terrain.stream_x_at(z) + side, z) + 0.3, z)
		player.velocity = Vector3.ZERO
		Input.action_press("move_forward")
		var last := player.global_position
		var still := 0.0
		var frames := 0
		while player.global_position.z < 96.0 and frames < 60 * 120:
			frames += 1
			var ahead_z := player.global_position.z + 3.0
			var target := Vector3(Terrain.stream_x_at(ahead_z) + side, 0, ahead_z)
			var d := target - player.global_position
			player.rotation.y = atan2(-d.x, -d.z)
			await get_tree().physics_frame
			if frames % 60 == 0:
				if player.global_position.distance_to(last) < 0.6:
					still += 1.0
					var at_bridge := false
					for ci in player.get_slide_collision_count():
						if String((player.get_slide_collision(ci).get_collider() as Node).name).begins_with("Bridge"):
							at_bridge = true
					if still >= 2.0 and at_bridge:
						# Steg über den Bach: absichtlich niedrig – drüberklettern
						player.global_position += Vector3(0, 0.6, 3.5)
						still = 0.0
					elif still >= 2.0:
						print("BACH hängt fest (Seite %.1f) bei x %.1f z %.1f" % [side, player.global_position.x, player.global_position.z])
						stuck += 1
						var q := PhysicsShapeQueryParameters3D.new()
						var sh := SphereShape3D.new()
						sh.radius = 1.2
						q.shape = sh
						q.transform = Transform3D(Basis(), player.global_position + Vector3(0, 0.8, 0))
						q.exclude = [player.get_rid()]
						var pz := player.global_position.z
						var hs := []
						for dz in range(-4, 5):
							var zz := pz + dz
							hs.append("%.0f:%.2f/%.2f" % [zz, Terrain.height_at(Terrain.stream_x_at(zz), zz), Terrain.stream_bed_height(zz)])
						print("   Höhen (Mitte/Bett): ", " ".join(hs), "  Spieler y %.2f" % player.global_position.y)
						var xs := []
						for dx in range(-5, 6):
							var xx := player.global_position.x + dx * 0.5
							xs.append("%.2f" % Terrain.height_at(xx, pz))
						for ci in player.get_slide_collision_count():
							var col := player.get_slide_collision(ci)
							print("   Kontakt: ", (col.get_collider() as Node).name, " Normale ", col.get_normal(), " bei ", col.get_position())
						print("   Querschnitt x±2.5: ", " ".join(xs), "  vel ", player.velocity, " floor ", player.is_on_floor(), " wall ", player.is_on_wall())
						player.global_position += Vector3(0, 0.5, 2.0)
						still = 0.0
				else:
					still = 0.0
				last = player.global_position
		Input.action_release("move_forward")
		print("BACH Seite %.1f: bis z %.1f" % [side, player.global_position.z])
	return stuck
