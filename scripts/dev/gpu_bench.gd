class_name GpuBench
extends RefCounted
## Entwickler-Test: Was kostet die Grafikkarte wie viel? Misst die GPU-Zeit pro Bild an ein paar Stellen,
## einmal mit allem und dann jeweils mit einer abgeschalteten Wirkung (Volumennebel, SSAO, Leuchten, Schatten …).
## Start: VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a godot --path . --rendering-driver vulkan
##        --resolution 1920x540 -- --night-test=gpu
## (Software-Grafik: absolute Zeiten sind viel höher als auf echter Hardware, die Verhältnisse zählen.)

const SPOTS := [
	["Hof morgens", Vector3(-3.0, 0.2, 14.0), Vector3(0, 1.5, 0), 7.6],
	["Talwald morgens", Vector3(-55.0, 0, 50.0), Vector3(-20, 0, 20), 7.6],
	["Talwald mittags", Vector3(-55.0, 0, 50.0), Vector3(-20, 0, 20), 13.0],
	["Hütte innen", Vector3(-1.0, 0.6, 1.0), Vector3(3, 1, -3), 13.0],
]


static func _measure(tree: SceneTree, frames: int = 12) -> float:
	var rid := tree.root.get_viewport_rid()
	for i in 6:
		await tree.process_frame
	var sum := 0.0
	for i in frames:
		await tree.process_frame
		sum += RenderingServer.viewport_get_measured_render_time_gpu(rid)
	return sum / float(frames)


static func run(host: Node) -> int:
	var tree := host.get_tree()
	var scene := tree.current_scene
	var player := tree.get_first_node_in_group("player") as Player
	ThreatDirector.set_process(false)
	TimeManager.running = false
	player.set_physics_process(false)
	RenderingServer.viewport_set_measure_render_time(tree.root.get_viewport_rid(), true)
	var env: Environment = DayNightEnvironment.current.env
	var sun: DirectionalLight3D = null
	for n in scene.find_children("*", "DirectionalLight3D", true, false):
		sun = n
	print("GPU-BENCH Auflösung 3D %s × %.2f" % [str(tree.root.get_visible_rect().size), tree.root.scaling_3d_scale])
	for s in SPOTS:
		TimeManager.set_time(18, float(s[3]))
		var terrain := scene.get_node_or_null("Terrain") as Terrain
		if terrain:
			terrain.load_around(s[1])
		player.global_position = Creature._ground(s[1]) + Vector3(0, 0.05, 0) if s[1].y < 0.5 else s[1]
		player.look_at(Vector3(s[2].x, player.global_position.y, s[2].z), Vector3.UP)
		for i in 30:
			await tree.process_frame
		var base: float = await _measure(tree)
		var line := "GPU-BENCH %-16s alles %.1f ms" % [s[0], base]
		var tests := {
			"Volumennebel": func(on: bool) -> void: env.volumetric_fog_enabled = on,
			"SSAO": func(on: bool) -> void: env.ssao_enabled = on,
			"Leuchten": func(on: bool) -> void: env.glow_enabled = on,
			"Nebel": func(on: bool) -> void: env.fog_enabled = on,
			"Sonnenschatten": func(on: bool) -> void: if sun: sun.shadow_enabled = on,
			"Retro": func(on: bool) -> void:
				var rf := tree.get_first_node_in_group("retro_filter")
				if rf: rf.visible = on,
		}
		for k: String in tests:
			var f: Callable = tests[k]
			# Wirkungen, die der Tag/Nacht-Wechsel jedes Bild neu setzt, bleiben über die Messung aus
			f.call(false)
			var t: float = await _measure(tree)
			f.call(true)
			line += " | ohne %s %.1f" % [k, t]
		print(line)
		await tree.process_frame
	return 0
