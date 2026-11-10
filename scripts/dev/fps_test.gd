class_name FpsTest
extends RefCounted
## Entwickler-Test: misst die Rechenzeit pro Bild an der Hütte, im Wald und an den großen Orten
## und sucht Ruckler beim Laufen durch den Wald (Nachladen von Gelände und Bäumen).
## Start: godot --headless --path . -- --night-test=fps          (Rechenzeit der Spiel-Logik)
##        xvfb-run -a godot --path . --rendering-driver vulkan --resolution 1280x720 -- --night-test=fps
##                                                                 (zusätzlich: Objekte, Zeichenaufrufe, Dreiecke)

## Ab so vielen Millisekunden zählt ein Bild als Ruckler (60 Bilder/s = 16,7 ms)
const HITCH_MS := 25.0
const SPOTS := [
	["Hütte Wohnzimmer", Vector3(-1.0, 0.6, 1.0), Vector3(3, 1, -3)],
	["Hütte Veranda → Hof", Vector3(-3.0, 0.6, 5.6), Vector3(-3, 0, 30)],
	["Hof → Hütte", Vector3(-3.0, 0.2, 15.0), Vector3(0, 2, 0)],
	["Talwald", Vector3(-60.0, 0, 60.0), Vector3(0, 0, 0)],
	["Bach", Vector3(40.0, 0, -40.0), Vector3(49, 0, -72)],
	["Wald draußen", Vector3(300.0, 0, -300.0), Vector3(600, 0, -600)],
]
const PLACES := ["absturz", "struktur", "kapelle", "imkerei", "messstelle", "funkmast", "see", "steinbruch", "kontrollpunkt",
	"ferienlager", "moor", "aussenstelle", "tunnel", "dorf", "wetterstation", "gewaechshaus", "wal", "raststation"]


static func run(host: Node) -> int:
	var tree := host.get_tree()
	var scene := tree.current_scene
	var player := tree.get_first_node_in_group("player") as Player
	var terrain := scene.get_node("Terrain") as Terrain
	var render := DisplayServer.get_name() != "headless"
	ThreatDirector.set_process(false)
	TimeManager.set_time(2, 13.0)
	TimeManager.running = false
	player.set_physics_process(false)
	var spots: Array = SPOTS.duplicate()
	for id: String in PLACES:
		var c := WorldMap.place_point(id)
		var clear := float(WorldMap.places()[id].get("clear", 0))
		var off := Vector3(maxf(clear * 0.6, 14.0), 0, maxf(clear * 0.6, 14.0))
		spots.append(["Ort " + id, c + off, c])
	var worst := 0.0
	var slow: PackedStringArray = []
	# --fps-detail=Bach: nur diesen Ort, dafür aufgeschlüsselt, welcher Teil der Welt die Zeit braucht
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--fps-detail="):
			var want := arg.get_slice("=", 1).to_lower()
			for s: Array in spots:
				if String(s[0]).to_lower().contains(want):
					await _detail(tree, scene, player, terrain, s)
			return 0
	print("BILDRATE  %-24s %9s %9s %8s%s" % ["Ort", "Ø ms", "max ms", "Physik", "   Objekte  Aufrufe  Dreiecke" if render else ""])
	for s: Array in spots:
		var pos: Vector3 = s[1]
		pos.y = maxf(pos.y, Terrain.height_at(pos.x, pos.z)) + 0.1
		terrain.load_around(pos, 120.0)
		player.global_position = pos
		var look: Vector3 = s[2]
		look.y = Terrain.height_at(look.x, look.z) + 1.5 if look.y == 0.0 else look.y
		player.look_at(Vector3(look.x, player.global_position.y, look.z), Vector3.UP)
		# warten, bis alles nachgeladen ist (gemessen wird der ruhige Zustand, das Nachladen prüft der Lauf unten)
		var wild := scene.get_node_or_null("WildForest") as WildForest
		if wild and render:
			wild.update_around(pos, 0.0)
		for i in (12 if render else 30):
			await tree.process_frame
		var waited := 0
		while not render and waited < 3000 and (terrain.is_loading() or (wild and wild.is_loading())):
			waited += 1
			await tree.process_frame
		var frames := 6 if render else 240
		# Die Bremse auf 60 Bilder/s lösen: dann ist die Zeit pro Bild genau die Rechenzeit der Spiel-Logik
		Engine.max_fps = 0
		for i in 5:
			await tree.process_frame
		var sum := 0.0
		var mx := 0.0
		var phys := 0.0
		var last := Time.get_ticks_usec()
		for i in frames:
			await tree.process_frame
			var now := Time.get_ticks_usec()
			var ms := (now - last) / 1000.0
			last = now
			sum += ms
			mx = maxf(mx, ms)
			phys += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		var avg := sum / frames
		Engine.max_fps = 60
		var extra := ""
		if render:
			extra = "  %8d %8d %9d" % [int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)),
				int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)), int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))]
		print("BILDRATE  %-24s %9.2f %9.2f %8.2f%s" % [s[0], avg, mx, phys / frames, extra])
		if not render:
			worst = maxf(worst, avg)
			if avg > 8.0:
				await _detail(tree, scene, player, terrain, s, false)
			if avg > 8.0:
				slow.append("%s (Ø %.1f ms)" % [s[0], avg])
	# Lauf durch den Wald: 25 Sekunden Rennen quer durch Tal und Wildwald, Ruckler zählen
	var hitches := 0
	var hitch_max := 0.0
	if not render:
		player.set_physics_process(true)
		var from := Vector3(20, 0, -90)
		var dir := Vector3(0.35, 0, -1).normalized()
		# erst am Startpunkt alles laden lassen – gemessen wird das Nachladen beim Laufen, nicht der Sprung dorthin
		player.global_position = Vector3(from.x, Terrain.height_at(from.x, from.z) + 0.2, from.z)
		terrain.load_around(player.global_position, 120.0)
		var wf := scene.get_node_or_null("WildForest") as WildForest
		var settle := 0
		while settle < 3000 and (settle < 30 or terrain.is_loading() or (wf and wf.is_loading())):
			settle += 1
			await tree.process_frame
		var t := 0.0
		var last := Time.get_ticks_usec()
		var n := 0
		var sum := 0.0
		while t < 25.0:
			await tree.process_frame
			var now := Time.get_ticks_usec()
			var ms := (now - last) / 1000.0
			last = now
			t += minf(ms / 1000.0, 0.05)
			var p := from + dir * player.sprint_speed * t
			player.global_position = Vector3(p.x, Terrain.height_at(p.x, p.z) + 0.2, p.z)
			player.velocity = Vector3.ZERO
			n += 1
			sum += ms
			if ms > HITCH_MS:
				hitches += 1
				hitch_max = maxf(hitch_max, ms)
		print("BILDRATE  Lauf durch den Wald (%.0f m): Ø %.2f ms, %d Ruckler über %.0f ms, längster %.1f ms" % [player.sprint_speed * 25.0, sum / n, hitches, HITCH_MS, hitch_max])
	TimeManager.running = true
	print("BILDRATE langsame Orte: %s" % (", ".join(slow) if not slow.is_empty() else "keine"))
	# Fehler: ein Ort rechnet im Schnitt zu lange, oder beim Laufen dauert ein einzelnes Bild über 30 ms
	var errors := slow.size() + (1 if hitch_max > 30.0 else 0)
	print("BILDRATE TEST: %d Fehler" % errors)
	return errors


## Schaltet nacheinander jeden Teil der Welt kurz ab und misst, wie viel Rechenzeit er pro Bild kostet.
static func _detail(tree: SceneTree, scene: Node, player: Player, terrain: Terrain, s: Array, settle: bool = true) -> void:
	if settle:
		var pos: Vector3 = s[1]
		pos.y = maxf(pos.y, Terrain.height_at(pos.x, pos.z)) + 0.1
		terrain.load_around(pos, 120.0)
		player.global_position = pos
		for i in 200:
			await tree.process_frame
	var base := await _avg_ms(tree, 90)
	print("BILDRATE Aufschlüsselung %s: zusammen %.2f ms" % [s[0], base])
	var nodes: Array = scene.get_children()
	for a in tree.root.get_children():
		if a != scene:
			nodes.append(a)
	var rows: Array = []
	for n: Node in nodes:
		var old := n.process_mode
		n.process_mode = Node.PROCESS_MODE_DISABLED
		var t := await _avg_ms(tree, 45)
		n.process_mode = old
		rows.append([base - t, String(n.name)])
		base = base * 0.7 + (await _avg_ms(tree, 30)) * 0.3
	rows.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	for r: Array in rows.slice(0, 12):
		print("BILDRATE   %-22s %6.2f ms" % [r[1], r[0]])


static func _avg_ms(tree: SceneTree, frames: int) -> float:
	Engine.max_fps = 0
	for i in 5:
		await tree.process_frame
	var t0 := Time.get_ticks_usec()
	for i in frames * 4:
		await tree.process_frame
	Engine.max_fps = 60
	return (Time.get_ticks_usec() - t0) / 1000.0 / (frames * 4)
