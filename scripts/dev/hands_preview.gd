extends Node
## Schnelle Vorschau der Hände und Hand-Gegenstände ohne die ganze Welt (Sekunden statt Minuten):
##   xvfb-run -a godot --path . --rendering-driver vulkan --resolution 960x540 res://scenes/dev/hands_preview.tscn -- \
##       --out=/pfad/bild.png [--mode=rig|item|fp] …
## mode=rig:  nur die Hand in vier Ansichten      --pose=relaxed|fist|open|grip:0.017
## mode=item: ein Gegenstand in vier Ansichten    --item=axe|tin_snips|water|food|… (Gegenstands-ID)
## mode=fp:   Blick des Spielers                  --item=ID --action=swing --p=0.0,0.3,0.6 (mehrere Bilder: bild_0.png …)
##            --left=watch|hammer|none  --night  --yaw=GRAD (Blickrichtung, für den Kompass)  --retro (mit Bildfilter)

var _args: Dictionary = {}


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv := a.substr(2).split("=", true, 1)
			_args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	_run.call_deferred()


func _arg(k: String, d: String = "") -> String:
	return String(_args.get(k, d))


func _world(night: bool) -> Node3D:
	var world := Node3D.new()
	add_child(world)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.02, 0.025, 0.04) if night else Color(0.5, 0.58, 0.66)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.6, 0.65, 0.7)
	e.ambient_light_energy = 0.03 if night else 0.55
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	world.add_child(env)
	if not night:
		var sun := DirectionalLight3D.new()
		sun.rotation_degrees = Vector3(-48, 40, 0)
		sun.light_energy = 1.1
		sun.shadow_enabled = true
		world.add_child(sun)
	return world


func _run() -> void:
	var mode := _arg("mode", "fp")
	if mode == "fp":
		await _run_fp()
	else:
		await _run_sheet(mode)
	# Der Software-Grafiktreiber im Cloud-Workspace bleibt beim normalen Beenden manchmal hängen – hart beenden.
	OS.kill(OS.get_process_id())


## Vier Ansichten nebeneinander (von oben, von der Seite, von vorn, schräg), ohne Perspektive.
func _run_sheet(mode: String) -> void:
	var world := _world(false)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	var span := float(_arg("span", "0.3"))
	cam.size = span
	world.add_child(cam)
	cam.position = Vector3(0, 0, 2)
	var views := [Vector3(90, 0, 0), Vector3(0, 90, 0), Vector3(0, 180, 0), Vector3(25, -35, 0)]
	if _args.has("views"):
		views = []
		for v in _arg("views").split(";"):
			var c := v.split(",")
			views.append(Vector3(float(c[0]), float(c[1]), float(c[2])))
	var step := span * 16.0 / 9.0 / views.size()
	for i in views.size():
		var holder := Node3D.new()
		world.add_child(holder)
		holder.position = Vector3((i - (views.size() - 1) * 0.5) * step, float(_arg("y", "0")), 0)
		holder.rotation_degrees = views[i]
		var skin := BuildKit.color_mat(Color(0.62, 0.46, 0.38), 0.8)
		if mode == "rig":
			var h := HandRig.create(holder, float(_arg("side", "1")), skin)
			h.position = Vector3(0, 0, 0.05)
			var pose := _arg("pose", "relaxed")
			if pose.begins_with("grip:"):
				var r := float(pose.get_slice(":", 1))
				h.set_pose(HandRig.grip(r))
				var c := HandRig.grip_center(r)
				BuildKit.cylinder(h, r, 0.16, c, BuildKit.color_mat(Color(0.3, 0.5, 0.8)), false, Vector3(0, 0, 90), -1.0, 16)
			else:
				h.set_pose({"fist": HandRig.FIST, "open": HandRig.OPEN}.get(pose, HandRig.RELAXED))
		else:
			var it := HandItems.build(holder, _arg("item", "axe"))
			it.position = -(it.get_meta("center", Vector3.ZERO) as Vector3)
			BuildKit.localize_materials(holder)
	for i in 6:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(_arg("out", "/tmp/hands.png"))


## Blick des Spielers mit den echten Händen (PlayerHands), Aktion an festen Zeitpunkten eingefroren.
func _run_fp() -> void:
	var night := _args.has("night")
	var world := _world(night)
	var floor := BuildKit.box(world, Vector3(30, 0.2, 30), Vector3(0, -0.1, 0), BuildKit.color_mat(Color(0.25, 0.33, 0.2)), true)
	floor.name = "Floor"
	BuildKit.box(world, Vector3(4, 2.4, 0.2), Vector3(0, 1.2, -4.5), BuildKit.tex_mat("planks_h", 1.2), true)
	if _args.has("retro"):
		world.add_child(RetroFilter.new())
	var player := Player.new()
	world.add_child(player)
	player.position = Vector3(0, 0.02, 0)
	player.rotation_degrees.y = float(_arg("yaw", "0"))
	player.head.rotation_degrees.x = float(_arg("pitch", "0"))
	player.set_physics_process(false)
	player.set_process(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var hands := player.hands
	var item := _arg("item", "")
	if item != "":
		Inventory.add(item, 2)
		Inventory.set_slot(0, item)
		Inventory.select(0)
	if item == "watering_can":
		Supplies.can_water = int(_arg("water", "4"))
	var left := _arg("left", "none")
	if left == "watch":
		hands.set_watch(true)
		if _args.has("screen"):
			hands.toggle_screen_mode()
	for i in 200:
		await get_tree().process_frame
		if hands._right_kind != "" and (item == "" or hands._right_id == item):
			break
	hands._right_out = 0.0
	if left != "none":
		if left == "hammer":
			hands._set_left_mode(true)
		hands._left_out = 0.0
		hands._left.visible = true
	hands._right.visible = true
	var action := _arg("action", "")
	var out := _arg("out", "/tmp/hands.png")
	var ps := _arg("p", "0").split(",")
	hands.set_process(false)
	for i in ps.size():
		hands.preview_freeze(action, float(ps[i]), float(_arg("len", "1.0")))
		for k in (40 if action == "pour" else 3):
			await get_tree().process_frame
		var path := out if ps.size() == 1 else out.replace(".png", "_%d.png" % i)
		get_viewport().get_texture().get_image().save_png(path)
