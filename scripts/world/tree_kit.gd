class_name TreeKit
extends RefCounted
## Baumarten für Tal (`Forest`) und großen Wald (`WildForest`): Fichte, Kiefer, Buche, Birke, alter Laubbaum,
## abgestorbener Baum (Dürrständer) und Jungwuchs (junge Fichte, junger Laubbaum, ohne Kollision).
## Ein Baum ist ein Dictionary {x, z, g, kind, h, r, yaw, seed}; `build` legt seine Teile in `Parts` ab.
## Wie oft welche Art wächst (nach Höhe, Nähe zum Wasser, Waldrand) steht in WorldConfig (forest_*).

const KINDS := ["spruce", "pine", "beech", "birch", "leaf", "dead"]

## Teile eines Waldstücks, je Material ein MultiMesh.
class Parts:
	extends RefCounted
	var trunks: Array[Transform3D] = []      ## Rinde braun (Fichte, Kiefer, Laubbaum, Äste)
	var trunk_cols: Array[Color] = []
	var birch: Array[Transform3D] = []       ## Birkenrinde
	var birch_cols: Array[Color] = []
	var smooth: Array[Transform3D] = []      ## Buchenrinde
	var smooth_cols: Array[Color] = []
	var cones: Array[Transform3D] = []       ## Nadel-Etagen
	var cone_cols: Array[Color] = []
	var crowns: Array[Transform3D] = []      ## Laubbüschel
	var crown_cols: Array[Color] = []


static var _cfg: WorldConfig


static func cfg() -> WorldConfig:
	if _cfg == null:
		_cfg = load("res://data/world/world_state.tres") as WorldConfig
	return _cfg


## Art für einen Platz: roll 0..1, g = Höhe, wet = 0..1 (nah am Bach/See), edge = 0..1 (Lichtung/Waldrand).
static func pick_kind(roll: float, g: float, wet: float, edge: float) -> String:
	var c := cfg()
	var high := smoothstep(40.0, 90.0, g)
	var w := {
		"spruce": c.forest_spruce + 0.4 * high,
		"pine": c.forest_pine + 0.1 * high,
		"beech": c.forest_beech * (1.0 - high),
		"birch": (c.forest_birch + 0.25 * wet + 0.15 * edge) * (1.0 - 0.7 * high),
		"leaf": c.forest_leaf * (1.0 - high),
		"dead": c.forest_dead,
	}
	var total := 0.0
	for k: String in KINDS:
		total += float(w[k])
	var acc := 0.0
	for k: String in KINDS:
		acc += float(w[k]) / total
		if roll <= acc:
			return k
	return "spruce"


## Höhe und Stammdicke je Art (size 0..1).
static func make(x: float, z: float, g: float, kind: String, size: float, yaw: float, seed_value: int) -> Dictionary:
	var h := 0.0
	var r := 0.0
	match kind:
		"spruce": h = lerpf(10.0, 19.0, size); r = lerpf(0.2, 0.38, size)
		"pine": h = lerpf(13.0, 21.0, size); r = lerpf(0.22, 0.34, size)
		"beech": h = lerpf(12.0, 17.0, size); r = lerpf(0.32, 0.52, size)
		"birch": h = lerpf(9.0, 15.0, size); r = lerpf(0.11, 0.19, size)
		"leaf": h = lerpf(8.0, 12.0, size); r = lerpf(0.2, 0.38, size)
		"dead": h = lerpf(7.0, 14.0, size); r = lerpf(0.16, 0.3, size)
		"young_spruce": h = lerpf(1.1, 3.4, size); r = 0.0
		"young_leaf": h = lerpf(1.4, 3.2, size); r = 0.035
	h *= lerpf(1.0, 0.6, smoothstep(100.0, 150.0, g))
	return {"x": x, "z": z, "g": g, "kind": kind, "h": h, "r": r, "yaw": yaw, "seed": seed_value}


static func is_young(t: Dictionary) -> bool:
	return String(t["kind"]).begins_with("young")


## Teile eines Baums anlegen. lod 2 = nah (voll), 1 = fern (wenige Teile). body: Kollision (nur große Bäume).
static func build(t: Dictionary, lod: int, p: Parts, body: StaticBody3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(t["seed"])
	var x: float = t["x"]
	var z: float = t["z"]
	var g: float = t["g"]
	var h: float = t["h"]
	var r: float = t["r"]
	var yaw: float = t["yaw"]
	var kind := String(t["kind"])
	var near := lod == 2
	match kind:
		"spruce":
			var th := h * 0.85
			_trunk(p.trunks, p.trunk_cols, x, z, g, r, th, yaw, rng, 0.04, Color(0.9, 0.85, 0.8).lerp(Color(1.15, 1.05, 0.95), rng.randf()))
			var green := Color(0.06, 0.13, 0.07).lerp(Color(0.11, 0.18, 0.09), rng.randf())
			_fir(p, x, z, g, h, yaw, rng, green, 9 if near else 3, rng.randf_range(0.15, 0.19), rng.randf_range(0.12, 0.22), near)
		"pine":
			var th := h * 0.86
			_trunk(p.trunks, p.trunk_cols, x, z, g, r, th, yaw, rng, 0.05, Color(1.3, 0.92, 0.66) * rng.randf_range(0.9, 1.05))
			# Schirmkrone: wenige flache, breite Nadel-Etagen ganz oben
			var green := Color(0.07, 0.12, 0.08).lerp(Color(0.1, 0.16, 0.09), rng.randf())
			var layers := 5 if near else 2
			var crown_r := h * rng.randf_range(0.13, 0.17)
			for i in layers:
				var f := float(i) / maxf(layers - 1, 1)
				var lr := crown_r * lerpf(1.0, 0.45, f) * rng.randf_range(0.85, 1.15)
				var lh := h * (0.09 if near else 0.14)
				var cy := g + lerpf(h * 0.68, h * 0.93, f)
				var off := Vector3(rng.randf_range(-0.6, 0.6), 0, rng.randf_range(-0.6, 0.6)) * (1.0 - f)
				p.cones.append(Transform3D(Basis.from_euler(Vector3(rng.randf_range(-0.12, 0.12), yaw + i * 1.1, rng.randf_range(-0.12, 0.12))).scaled(Vector3(lr, lh, lr)),
						Vector3(x, cy, z) + off))
				var col := green * lerpf(0.85, 1.15, f)
				col.a = 1.0
				p.cone_cols.append(col)
		"beech":
			var th := h * 0.52
			_trunk(p.smooth, p.smooth_cols, x, z, g, r, th, yaw, rng, 0.03, Color(1.15, 1.12, 1.0) * rng.randf_range(0.9, 1.15))
			_crown(p, x, z, g + th - 0.2, rng, 15 if near else 4, Vector2(2.6, 3.9), Vector3(3.1, 2.2, 3.1),
					Color(0.6, 0.82, 0.45), Color(0.78, 0.9, 0.5), near)
		"birch":
			var th := h * 0.8
			_trunk(p.birch, p.birch_cols, x, z, g, r, th, yaw, rng, 0.1, Color(0.86, 0.83, 0.76) * rng.randf_range(0.9, 1.05))
			# schmale, hohe Krone aus kleinen hellen Büscheln
			var count := 9 if near else 3
			for i in count:
				var f := float(i) / maxf(count - 1, 1)
				var off := Vector3(rng.randf_range(-1.3, 1.3), lerpf(-h * 0.35, h * 0.12, f), rng.randf_range(-1.3, 1.3))
				var s := rng.randf_range(1.3, 2.1) * (1.0 if near else 1.5)
				p.crowns.append(Transform3D(Basis.from_euler(Vector3(rng.randf_range(-0.5, 0.5), rng.randf() * TAU, rng.randf_range(-0.5, 0.5))).scaled(Vector3(s, s * 1.2, s)),
						Vector3(x, g + th, z) + off))
				var lc := Color(0.95, 1.08, 0.62) * rng.randf_range(0.85, 1.1)
				lc.a = 1.0
				p.crown_cols.append(lc)
		"leaf":
			var th := h * 0.62
			_trunk(p.trunks, p.trunk_cols, x, z, g, r, th, yaw, rng, 0.04, Color(0.9, 0.85, 0.8).lerp(Color(1.15, 1.05, 0.95), rng.randf()))
			_crown(p, x, z, g + th - 0.4, rng, 9 if near else 3, Vector2(2.2, 3.4), Vector3(1.8, 1.4, 1.8),
					Color(0.6, 0.72, 0.5), Color(0.85, 0.95, 0.62), near)
		"dead":
			var th := h * 0.78
			var grey := Color(0.72, 0.7, 0.68) * rng.randf_range(0.85, 1.05)
			_trunk(p.trunks, p.trunk_cols, x, z, g, r, th, yaw, rng, 0.06, grey)
			# kahle Äste
			for i in (rng.randi_range(3, 6) if near else 2):
				var ay := g + th * rng.randf_range(0.35, 0.85)
				var ang := rng.randf() * TAU
				var tilt := rng.randf_range(0.7, 1.15)
				var len := rng.randf_range(1.2, 2.8) * (h / 12.0)
				var b := Basis(Vector3.UP, ang) * Basis(Vector3.RIGHT, tilt)
				var mid := Vector3(x, ay, z) + b * Vector3(0, len * 0.5, 0)
				p.trunks.append(Transform3D(b.scaled(Vector3(r * 0.22, len, r * 0.22)), mid))
				p.trunk_cols.append(grey)
		"young_spruce":
			var green := Color(0.08, 0.15, 0.08).lerp(Color(0.13, 0.21, 0.1), rng.randf())
			_fir(p, x, z, g - 0.05, h, yaw, rng, green, 5 if near else 2, rng.randf_range(0.2, 0.26), 0.05, near)
		"young_leaf":
			_trunk(p.trunks, p.trunk_cols, x, z, g, 0.035, h * 0.8, yaw, rng, 0.08, Color(1.0, 0.9, 0.8))
			_crown(p, x, z, g + h * 0.75, rng, 3 if near else 1, Vector2(0.7, 1.15), Vector3(0.6, 0.5, 0.6),
					Color(0.7, 0.88, 0.5), Color(0.9, 1.0, 0.6), near)
	if body and r > 0.06:
		var cs := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = r * 1.05
		shape.height = 4.0
		cs.shape = shape
		cs.position = Vector3(x, g + 1.8, z)
		body.add_child(cs)


static func _trunk(arr: Array[Transform3D], cols: Array[Color], x: float, z: float, g: float, r: float, th: float, yaw: float,
		rng: RandomNumberGenerator, lean: float, col: Color) -> void:
	arr.append(Transform3D(Basis.from_euler(Vector3(rng.randf_range(-lean, lean), yaw, rng.randf_range(-lean, lean))).scaled(Vector3(r, th, r)),
			Vector3(x, g + th * 0.5 - 0.3, z)))
	col.a = 1.0
	cols.append(col)


## Viele überlappende, schlanke Kegel ergeben die typische Fichtenform.
static func _fir(p: Parts, x: float, z: float, g: float, h: float, yaw: float, rng: RandomNumberGenerator, green: Color,
		layers: int, crown_f: float, bottom_f: float, near: bool) -> void:
	var crown_r := h * crown_f
	var bottom := h * bottom_f
	for i in layers:
		var fr := float(i) / float(maxi(layers - 1, 1))
		var lr := crown_r * lerpf(1.0, 0.18, fr) * rng.randf_range(0.9, 1.1)
		var lh := h * (lerpf(0.3, 0.2, fr) if near else lerpf(0.45, 0.35, fr))
		var cy := g + lerpf(bottom, h * 0.92, fr) + lh * 0.5
		var col := green * lerpf(0.8, 1.2, fr)
		col.a = 1.0
		var tilt := Vector3(rng.randf_range(-0.06, 0.06), yaw + i * 0.7, rng.randf_range(-0.06, 0.06))
		p.cones.append(Transform3D(Basis.from_euler(tilt).scaled(Vector3(lr, lh, lr)), Vector3(x, cy - lh * 0.5, z)))
		p.cone_cols.append(col)


static func _crown(p: Parts, x: float, z: float, top: float, rng: RandomNumberGenerator, count: int, size: Vector2, spread: Vector3,
		c0: Color, c1: Color, near: bool) -> void:
	for i in count:
		var off := Vector3(rng.randf_range(-spread.x, spread.x), rng.randf_range(-spread.y * 0.8, spread.y), rng.randf_range(-spread.z, spread.z))
		var s := rng.randf_range(size.x, size.y) * (1.0 if near else 1.4)
		var rot := Basis.from_euler(Vector3(rng.randf_range(-0.4, 0.4), rng.randf() * TAU, rng.randf_range(-0.4, 0.4)))
		p.crowns.append(Transform3D(rot.scaled(Vector3(s, s, s)), Vector3(x, top, z) + off * (1.0 if near else 0.6)))
		var lc := c0.lerp(c1, rng.randf()) * rng.randf_range(0.85, 1.12)
		lc.a = 1.0
		p.crown_cols.append(lc)
