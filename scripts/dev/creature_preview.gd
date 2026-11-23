extends Node
## Schnelle Vorschau einer Gegner-Figur ohne die ganze Welt:
## xvfb-run godot --path . --rendering-driver vulkan --resolution 960x540 res://scenes/dev/creature_preview.tscn -- --out=/pfad/bild.png --pose=warn|charge|stalk --angle=0
## Sucher: --what=seeker  (Abstand --dist=3.6)
## Wechselbalg: --changeling=masks (alle Tarnungen, oben deutlicher Fehler, unten feiner) | --changeling=true (wahre Gestalt)

func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := "/tmp/preview.png"
	var pose := "warn"
	var angle := 20.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="): out = a.get_slice("=", 1)
		if a.begins_with("--pose="): pose = a.get_slice("=", 1)
		if a.begins_with("--angle="): angle = float(a.get_slice("=", 1))
	var world := Node3D.new()
	add_child(world)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.55, 0.62, 0.7)
	e.ambient_light_color = Color(0.6, 0.65, 0.7)
	e.ambient_light_energy = 0.6
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 35, 0)
	sun.shadow_enabled = true
	world.add_child(sun)
	var floor := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(20, 20)
	floor.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.3, 0.38, 0.25)
	floor.material_override = fm
	world.add_child(floor)
	var cl := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--changeling="): cl = a.get_slice("=", 1)
	if cl != "":
		_changeling_lineup(world, cl, angle)
		for i in 12:
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png(out)
		get_tree().quit()
		return
	var what := "mauler"
	var dist := 3.6
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--what="): what = a.get_slice("=", 1)
		if a.begins_with("--dist="): dist = float(a.get_slice("=", 1))
	if what == "seeker":
		var sk := Seeker.new()
		world.add_child(sk)
		sk.set_process(false)
		sk.position = Vector3.ZERO
		sk.rotation_degrees.y = angle
		var cam2 := Camera3D.new()
		world.add_child(cam2)
		cam2.position = Vector3(0, 1.6, dist + 1.0)
		cam2.look_at(Vector3(0, 1.45, 0))
		cam2.fov = 50
		for i in 12:
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png(out)
		get_tree().quit()
		return
	var m := Mauler.new()
	world.add_child(m)
	m.set_process(false)
	m.rotation_degrees.y = angle
	m.state = {"warn": Mauler.State.WARN, "charge": Mauler.State.CHARGE, "strike": Mauler.State.STRIKE}.get(pose, Mauler.State.STALK)
	m._speed_now = m.cfg.charge_speed if pose == "charge" else (0.0 if pose != "stalk" else m.cfg.stalk_speed)
	m._swing = 0.5
	for k in 30:
		m._animate(0.1)
	var cam := Camera3D.new()
	world.add_child(cam)
	cam.position = Vector3(0, 1.3, dist)
	cam.look_at(Vector3(0, 1.05, 0))
	cam.fov = 50
	for i in 12:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(out)
	get_tree().quit()


func _changeling_lineup(world: Node3D, what: String, angle: float) -> void:
	var cam := Camera3D.new()
	world.add_child(cam)
	if what == "true":
		for i in 2:
			var r := Node3D.new()
			world.add_child(r)
			r.position = Vector3(-0.9 + i * 1.8, 0, 0)
			r.rotation_degrees.y = angle - 20.0 + i * 40.0
			ChangelingModel.build_true(r, "crouch" if i == 0 else "stand")
		cam.position = Vector3(0, 1.3, 4.2)
		cam.look_at(Vector3(0, 0.95, 0))
		cam.fov = 50
		return
	var kinds := ChangelingModel.KINDS
	for row in 2:
		for i in kinds.size():
			var r := Node3D.new()
			world.add_child(r)
			r.position = Vector3(-6.75 + i * 1.5, 0, -row * 2.6)
			r.rotation_degrees.y = angle
			ChangelingModel.build(r, kinds[i], row == 1)
	cam.position = Vector3(0, 3.2, 8.5)
	cam.look_at(Vector3(0, 0.6, -1.3))
	cam.fov = 58
