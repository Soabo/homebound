class_name WorldTrails
extends Node3D
## Wegweiser an Kreuzungen und Holzstege, wo ein Weg den Bach quert (Daten: data/world/map.json).
## Die Wege selbst färbt das Gelände ein (Terrain.ground_color).

var _wood: StandardMaterial3D
var _dark: StandardMaterial3D


func _ready() -> void:
	name = "WorldTrails"
	_wood = BuildKit.tex_mat("planks_h", 0.7, Color(0.85, 0.78, 0.7))
	_dark = BuildKit.tex_mat("bark", 0.6)
	for s: Dictionary in WorldMap.data().get("signs", []):
		_sign(Vector2(float(s["pos"][0]), float(s["pos"][1])), s["to"])
	_bridges()


## Holzpfosten mit Brettern, je Ziel ein Pfeil in die (Luftlinien-)Richtung mit Entfernung.
func _sign(at: Vector2, targets: Array) -> void:
	var g := Terrain.height_at(at.x, at.y)
	var root := Node3D.new()
	root.name = "Sign_%d_%d" % [int(at.x), int(at.y)]
	root.position = Vector3(at.x, g, at.y)
	add_child(root)
	BuildKit.cylinder(root, 0.07, 2.4, Vector3(0, 1.2, 0), _dark, true, Vector3.ZERO, 0.06, 7)
	BuildKit.cylinder(root, 0.09, 0.08, Vector3(0, 2.42, 0), _dark, false, Vector3.ZERO, 0.0, 7)
	var y := 2.1
	for id: String in targets:
		var p := WorldMap.place_pos(id)
		var dir := p - at
		var dist := dir.length()
		var yaw := rad_to_deg(atan2(-dir.x, -dir.y))
		var arm := Node3D.new()
		arm.position = Vector3(0, y, 0)
		arm.rotation_degrees = Vector3(0, yaw + 90.0, 0)
		root.add_child(arm)
		# Brett zeigt in -x der Arm-Ebene … mit Spitze
		BuildKit.box(arm, Vector3(1.15, 0.2, 0.035), Vector3(-0.62, 0, 0), _wood, false)
		BuildKit.box(arm, Vector3(0.16, 0.16, 0.035), Vector3(-1.2, 0, 0), _wood, false, Vector3(0, 0, 45))
		var name_text: String = WorldMap.places()[id]["name"] if WorldMap.places().has(id) else id
		var km := ("%.1f km" % (dist / 1000.0)).replace(".", ",") if dist >= 950.0 else "%d m" % (int(round(dist / 50.0)) * 50)
		for side: float in [1.0, -1.0]:
			var lab := Label3D.new()
			lab.text = "%s  %s" % [name_text, km]
			lab.font_size = 34
			lab.pixel_size = 0.0028
			lab.modulate = Color(0.12, 0.09, 0.06)
			lab.outline_size = 0
			lab.position = Vector3(-0.62, 0, 0.02 * side)
			lab.rotation_degrees = Vector3(0, 0 if side > 0 else 180, 0)
			lab.width = 400
			lab.autowrap_mode = TextServer.AUTOWRAP_OFF
			arm.add_child(lab)
		y -= 0.27


## Wo ein Weg den Bach kreuzt: ein schmaler Steg aus Bohlen.
func _bridges() -> void:
	var done: Array[Vector2] = []
	for s: Array in WorldMap.segments():
		var a: Vector2 = s[0]
		var b: Vector2 = s[1]
		var len := a.distance_to(b)
		var steps := int(len / 1.0)
		var prev := INF
		for i in steps + 1:
			var p := a.lerp(b, float(i) / maxf(steps, 1))
			var sd := Terrain.stream_distance(p.x, p.y)
			if sd < 0.6 and sd < prev:
				var near_done := false
				for q: Vector2 in done:
					if q.distance_to(p) < 12.0:
						near_done = true
				if not near_done:
					done.append(p)
					_bridge(p, (b - a).normalized(), float(s[2]) * 2.0, int(s[3]))
			prev = sd
	print("[WorldTrails] Stege: %d" % done.size())


func _bridge(at: Vector2, dir: Vector2, width: float, kind: int) -> void:
	var water := Terrain.stream_bed_height(at.y) + Terrain.WATER_LEVEL
	var root := StaticBody3D.new()
	root.name = "Bridge_%d_%d" % [int(at.x), int(at.y)]
	root.position = Vector3(at.x, water + 0.35, at.y)
	root.rotation.y = atan2(dir.x, dir.y)
	add_child(root)
	var w := clampf(width, 1.4, 6.0)
	var length := 7.0 if kind < 2 else 14.0
	var mat := _wood if kind < 2 else BuildKit.tex_mat("concrete", 0.5)
	# Bohlen quer zur Laufrichtung (lokal z = Laufrichtung)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(w, 0.12, length)
	cs.shape = shape
	root.add_child(cs)
	if kind < 2:
		var n := int(length / 0.32)
		for i in n:
			BuildKit.box(root, Vector3(w, 0.07, 0.28), Vector3(0, 0, -length * 0.5 + 0.16 + i * 0.32), mat, false, Vector3(0, randf_range(-1.5, 1.5), 0))
		for sx: float in [-1.0, 1.0]:
			BuildKit.box(root, Vector3(0.12, 0.14, length), Vector3(sx * (w * 0.5 - 0.1), -0.1, 0), _dark, false)
			# Geländer
			for k in 3:
				BuildKit.cylinder(root, 0.04, 0.9, Vector3(sx * (w * 0.5 - 0.05), 0.45, -length * 0.4 + k * length * 0.4), _dark, false, Vector3.ZERO, -1.0, 6)
			BuildKit.cylinder(root, 0.035, length * 0.85, Vector3(sx * (w * 0.5 - 0.05), 0.88, 0), _dark, false, Vector3(90, 0, 0), -1.0, 6)
	else:
		BuildKit.box(root, Vector3(w, 0.5, length), Vector3(0, -0.2, 0), mat, false)
		for sx: float in [-1.0, 1.0]:
			BuildKit.box(root, Vector3(0.3, 0.8, length), Vector3(sx * (w * 0.5 - 0.15), 0.4, 0), mat, false)
