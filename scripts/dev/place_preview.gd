extends Node3D
## Schnelle Ansicht EINES Ortes ohne die ganze Welt (Sekunden statt Minuten, wenig Speicher):
## xvfb-run -a godot --path . --rendering-driver vulkan --resolution 1280x720 res://scenes/dev/place_preview.tscn --
##   --place=kapelle --out=BILD.png --cam=x,y,z --look=x,y,z [--fov=70] [--night] [--radius=45]
## cam/look sind ORTS-Koordinaten (wie in den Bauanleitungen, Boden in der Ortsmitte = 0). Mehrere Bilder:
##   --shots="cx,cy,cz:lx,ly,lz;cx,cy,cz:lx,ly,lz" (Ausgabe BILD_0.png, BILD_1.png …)


func _ready() -> void:
	var out := "/tmp/place.png"
	var id := "kapelle"
	var cam_p := Vector3(10, 3, 10)
	var look := Vector3(0, 1.5, 0)
	var fov := 70.0
	var night := false
	var radius := 45.0
	var shots := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="): out = a.get_slice("=", 1)
		if a.begins_with("--place="): id = a.get_slice("=", 1)
		if a.begins_with("--cam="): cam_p = _v(a.get_slice("=", 1))
		if a.begins_with("--look="): look = _v(a.get_slice("=", 1))
		if a.begins_with("--fov="): fov = float(a.get_slice("=", 1))
		if a.begins_with("--radius="): radius = float(a.get_slice("=", 1))
		if a.begins_with("--shots="): shots = a.get_slice("=", 1)
		if a == "--night": night = true
	Look.set_style("klar")
	Look.patch_shaders()
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.03, 0.035, 0.05) if night else Color(0.62, 0.68, 0.74)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.5, 0.55, 0.7) if night else Color(0.85, 0.85, 0.82)
	e.ambient_light_energy = 0.12 if night else 0.75
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.fog_enabled = true
	e.fog_light_color = e.background_color
	e.fog_density = 0.008
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, 35, 0)
	sun.light_energy = 0.08 if night else 1.3
	sun.shadow_enabled = true
	add_child(sun)
	var root := Node3D.new()
	root.name = id
	add_child(root)
	root.global_position = WorldMap.place_point(id)
	var built := PlacesNear.build(id, root) or PlacesDay.build(id, root) or PlacesFar.build(id, root)
	if not built:
		push_error("Ort unbekannt: " + id)
	_ground(root, radius)
	for i in 5:
		await get_tree().process_frame
	var cam := Camera3D.new()
	cam.fov = fov
	cam.far = 600.0
	add_child(cam)
	var list: Array = []
	if shots != "":
		for s in shots.split(";"):
			list.append([_v(s.get_slice(":", 0)), _v(s.get_slice(":", 1))])
	else:
		list.append([cam_p, look])
	for i in list.size():
		cam.global_position = root.to_global(list[i][0])
		cam.look_at(root.to_global(list[i][1]))
		for k in 12:
			await get_tree().process_frame
		var path := out if list.size() == 1 else out.replace(".png", "_%d.png" % i)
		get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()


## Gelände um den Ort (echte Höhen, Bodenfarbe aus Terrain.ground_color, Foto-Kies darüber).
func _ground(root: Node3D, radius: float) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var c := root.global_position
	var step := 1.0
	var n := int(radius * 2.0 / step)
	var pts: Array = []
	for j in n + 1:
		var row: Array = []
		for i in n + 1:
			var x := c.x - radius + i * step
			var z := c.z - radius + j * step
			row.append(Vector3(x, Terrain.height_at(x, z), z))
		pts.append(row)
	for j in n:
		for i in n:
			var q := [pts[j][i], pts[j][i + 1], pts[j + 1][i + 1], pts[j + 1][i]]
			for idx: int in [0, 1, 2, 0, 2, 3]:
				var p: Vector3 = q[idx]
				var col := Terrain.ground_color(p.x, p.z, p.y, 1.0)
				col.a = 1.0
				st.set_color(col)
				st.set_uv(Vector2(p.x, p.z) * 0.5)
				st.add_vertex(p)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = load("res://assets/textures/ground/gravel_color.jpg")
	m.albedo_color = Color(1.3, 1.25, 1.15)
	m.roughness = 1.0
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	add_child(mi)


func _v(s: String) -> Vector3:
	var p := s.split(",")
	return Vector3(float(p[0]), float(p[1]), float(p[2]))
