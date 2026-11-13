extends Node
## Entwickler-Werkzeug: Draufsicht der Welt als Bild (Boden, Schummerung, Wege, Bach, Orte).
## godot --headless --path . res://scenes/dev/map_dump.tscn -- --out=/tmp/map.png --cx=0 --cz=0 --size=2200 --px=1100

func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=")
		if kv.size() == 2:
			args[kv[0]] = kv[1]
	var out: String = args.get("out", "/tmp/map.png")
	var cx := float(args.get("cx", "0"))
	var cz := float(args.get("cz", "0"))
	var size := float(args.get("size", "2200"))
	var px := int(args.get("px", "1100"))
	var overlay: bool = args.get("overlay", "1") == "1"
	WorldMap.ensure()
	var img := Image.create(px, px, false, Image.FORMAT_RGB8)
	var m := size / px
	for iy in px:
		for ix in px:
			var x := cx - size * 0.5 + (ix + 0.5) * m
			var z := cz - size * 0.5 + (iy + 0.5) * m
			var h := Terrain.height_at(x, z)
			var hx := Terrain.height_at(x + m, z)
			var hz := Terrain.height_at(x, z + m)
			var nrm := Vector3(h - hx, m, h - hz).normalized()
			var col := Terrain.ground_color(x, z, h, nrm.y)
			var shade := clampf(nrm.dot(Vector3(-0.5, 0.8, -0.4).normalized()), 0.2, 1.0)
			col = col * (0.5 + shade * 1.6)
			if Terrain.water_level_at(x, z) > h:
				col = Color(0.15, 0.3, 0.6)
			if overlay:
				var dens := WorldMap.tree_density(x, z, h) if Vector2(x, z).length() > 95.0 else 1.0
				col = col.lerp(Color(0.02, 0.08, 0.02), dens * 0.25)
			img.set_pixel(ix, iy, Color(clampf(col.r, 0, 1), clampf(col.g, 0, 1), clampf(col.b, 0, 1)))
	if overlay:
		for id: String in WorldMap.places():
			var p := WorldMap.place_pos(id)
			var q := Vector2i(int((p.x - cx + size * 0.5) / m), int((p.y - cz + size * 0.5) / m))
			for dy in range(-3, 4):
				for dx in range(-3, 4):
					var r := q + Vector2i(dx, dy)
					if r.x >= 0 and r.y >= 0 and r.x < px and r.y < px:
						img.set_pixelv(r, Color(1, 0.2, 0.9))
		for s: Dictionary in WorldMap.data().get("signs", []):
			var q := Vector2i(int((float(s["pos"][0]) - cx + size * 0.5) / m), int((float(s["pos"][1]) - cz + size * 0.5) / m))
			for dy in range(-2, 3):
				for dx in range(-2, 3):
					var r := q + Vector2i(dx, dy)
					if r.x >= 0 and r.y >= 0 and r.x < px and r.y < px:
						img.set_pixelv(r, Color(1, 1, 0))
	img.save_png(out)
	print("Karte: ", out)
	get_tree().quit()
