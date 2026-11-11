extends Node
## Schnelle Vorschau einer Gegner-Figur ohne die ganze Welt:
## xvfb-run godot --path . --rendering-driver vulkan --resolution 960x540 res://scenes/dev/creature_preview.tscn -- --out=/pfad/bild.png --pose=warn|charge|stalk --angle=0

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
	cam.position = Vector3(0, 1.3, 3.6)
	cam.look_at(Vector3(0, 1.05, 0))
	cam.fov = 50
	for i in 12:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(out)
	get_tree().quit()
