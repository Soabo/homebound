extends Node3D
## Schnelle Ansicht der Hütte ohne Welt (Sekunden statt Minuten, wenig Speicher):
## xvfb-run -a godot --path . --rendering-driver vulkan --resolution 1280x720 res://scenes/dev/cabin_preview.tscn --
##   --out=BILD.png --cam=x,y,z --look=x,y,z [--fov=70] [--open=MovingBox]


func _ready() -> void:
	var out := "/tmp/cabin.png"
	var cam_p := Vector3(3.0, 1.6, 2.0)
	var look := Vector3(5.5, 1.0, 3.0)
	var fov := 70.0
	var open := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="): out = a.get_slice("=", 1)
		if a.begins_with("--cam="): cam_p = _v(a.get_slice("=", 1))
		if a.begins_with("--look="): look = _v(a.get_slice("=", 1))
		if a.begins_with("--fov="): fov = float(a.get_slice("=", 1))
		if a.begins_with("--open="): open = a.get_slice("=", 1)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.5, 0.6, 0.7)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.9, 0.85, 0.8)
	e.ambient_light_energy = 0.9
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	sun.light_energy = 1.2
	add_child(sun)
	var lamp := OmniLight3D.new()
	lamp.position = cam_p + Vector3(0, 0.3, 0)
	lamp.omni_range = 8.0
	lamp.light_energy = 1.5
	add_child(lamp)
	Look.set_style("klar")   # Vorschau immer im klaren Stil mit Foto-Texturen
	Look.patch_shaders()
	var cabin := Cabin.new()
	cabin.name = "Cabin"
	add_child(cabin)
	for i in 5:
		await get_tree().process_frame
	if open != "":
		var n := cabin.get_node_or_null(open)
		if n and "opened" in n:
			n.set("opened", true)
			n.call("_apply")
	if Research.tier < 2:
		Research.tier = 2
		Research.changed.emit()
	var cam := Camera3D.new()
	cam.fov = fov
	add_child(cam)
	cam.position = cam_p
	cam.look_at(look)
	for i in 20:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(out)
	get_tree().quit()


func _v(s: String) -> Vector3:
	var p := s.split(",")
	return Vector3(float(p[0]), float(p[1]), float(p[2]))
