class_name Garden
extends Node3D
## Grundstück rund um die Hütte (GDD 3.4): Zaun, Beete, Regentonne,
## Hackklotz, Wäscheleine, zwei Laubbäume.
## Später wird das Grundstück frei bebaubar (Base Building Manager).

const FENCE_MIN := Vector2(-20.0, -16.0)
const FENCE_MAX := Vector2(22.0, 18.0)
const POST_SPACING := 2.5


func _ready() -> void:
	name = "Garden"
	_build_fence()
	_build_props()


func _build_fence() -> void:
	var post := BuildKit.wood_mat(Color(0.32, 0.25, 0.18), 1, 0.4, 0.03)
	var rail := BuildKit.wood_mat(Color(0.38, 0.3, 0.21), 0, 0.5, 0.02)
	# Lücken: Tor zur Zufahrt im Süden, schmaler Durchgang in den Wald im Norden
	_fence_line(Vector2(FENCE_MIN.x, FENCE_MAX.y), Vector2(FENCE_MAX.x, FENCE_MAX.y), Vector2(-5.0, -1.0), post, rail)
	_fence_line(Vector2(FENCE_MIN.x, FENCE_MIN.y), Vector2(FENCE_MAX.x, FENCE_MIN.y), Vector2(3.0, 6.0), post, rail)
	_fence_line(Vector2(FENCE_MIN.x, FENCE_MIN.y), Vector2(FENCE_MIN.x, FENCE_MAX.y), Vector2.ZERO, post, rail)
	_fence_line(Vector2(FENCE_MAX.x, FENCE_MIN.y), Vector2(FENCE_MAX.x, FENCE_MAX.y), Vector2.ZERO, post, rail)
	# Torpfosten
	var gate := BuildKit.wood_mat(Color(0.28, 0.21, 0.15), 1, 0.4, 0.03)
	for x: float in [-5.0, -1.0]:
		BuildKit.box(self, Vector3(0.22, 2.7, 0.22), Vector3(x, 1.35, FENCE_MAX.y), gate, true)
	# Querbalken hoch genug, dass man (auch springend) darunter durchkommt
	BuildKit.box(self, Vector3(4.3, 0.18, 0.18), Vector3(-3.0, 2.7, FENCE_MAX.y), gate, false)


## Zaunlinie entlang x oder z. gap = (von, bis) entlang der Laufrichtung, Vector2.ZERO = keine Lücke.
func _fence_line(a: Vector2, b: Vector2, gap: Vector2, post: Material, rail: Material) -> void:
	var along_x := absf(b.x - a.x) > absf(b.y - a.y)
	var start := a.x if along_x else a.y
	var end := b.x if along_x else b.y
	var points: Array[float] = []
	var p := start
	while p < end - 0.01:
		points.append(p)
		p += POST_SPACING
	points.append(end)
	var has_gap := gap != Vector2.ZERO
	for i in points.size():
		var v := points[i]
		if has_gap and v > gap.x + 0.01 and v < gap.y - 0.01:
			continue
		var pos := Vector3(v, 0.6, a.y) if along_x else Vector3(a.x, 0.6, v)
		BuildKit.box(self, Vector3(0.14, 1.2, 0.14), pos, post, true)
		if i == points.size() - 1:
			continue
		var nv := points[i + 1]
		var s := v
		var e := nv
		if has_gap:
			if s >= gap.x - 0.01 and s < gap.y:
				continue
			if e > gap.x:
				e = minf(e, gap.x)
		if e - s < 0.05:
			continue
		var mid := (s + e) * 0.5
		var length := e - s
		for h: float in [0.45, 0.95]:
			if along_x:
				BuildKit.box(self, Vector3(length, 0.09, 0.05), Vector3(mid, h, a.y), rail, true)
			else:
				BuildKit.box(self, Vector3(0.05, 0.09, length), Vector3(a.x, h, mid), rail, true)
	if has_gap:
		for v: float in [gap.x, gap.y]:
			var pos := Vector3(v, 0.6, a.y) if along_x else Vector3(a.x, 0.6, v)
			BuildKit.box(self, Vector3(0.16, 1.2, 0.16), pos, post, true)
		# Rest hinter der Lücke bis zum nächsten Pfosten
		for i in points.size():
			if points[i] >= gap.y:
				var length2 := points[i] - gap.y
				if length2 > 0.05:
					var mid2 := (gap.y + points[i]) * 0.5
					for h: float in [0.45, 0.95]:
						if along_x:
							BuildKit.box(self, Vector3(length2, 0.09, 0.05), Vector3(mid2, h, a.y), rail, true)
						else:
							BuildKit.box(self, Vector3(0.05, 0.09, length2), Vector3(a.x, h, mid2), rail, true)
				break


func _build_props() -> void:
	var soil := BuildKit.color_mat(Color(0.2, 0.14, 0.09), 1.0)
	var frame := BuildKit.wood_mat(Color(0.36, 0.27, 0.18), 1, 0.15, 0.06)
	var leaf := BuildKit.color_mat(Color(0.2, 0.35, 0.14), 0.9)
	# Hochbeete westlich der Hütte
	for bed: Vector3 in [Vector3(-14.0, 0, 6.0), Vector3(-14.0, 0, 9.5), Vector3(-10.5, 0, 6.0), Vector3(-10.5, 0, 9.5)]:
		BuildKit.box(self, Vector3(2.4, 0.4, 1.4), bed + Vector3(0, 0.2, 0), frame, true)
		BuildKit.box(self, Vector3(2.3, 0.05, 1.3), bed + Vector3(0, 0.4, 0), soil, false)
		for i in 5:
			BuildKit.sphere(self, 0.16, bed + Vector3(-0.9 + i * 0.45, 0.5, 0.25 * (1 if i % 2 == 0 else -1)), leaf, Vector3(1, 0.8, 1), 8)
	# Regentonne an der Hütte
	var barrel := BuildKit.wood_mat(Color(0.32, 0.22, 0.14), 0, 0.15, 0.1)
	BuildKit.cylinder(self, 0.4, 1.0, Vector3(6.7, 0.5, -4.9), barrel, true, Vector3.ZERO, 0.38, 14)
	# Hackklotz mit Axt neben dem Schuppen
	var stump := BuildKit.color_mat(Color(0.4, 0.3, 0.2), 0.95)
	BuildKit.cylinder(self, 0.32, 0.5, Vector3(11.0, 0.25, 10.5), stump, true, Vector3.ZERO, -1.0, 12)
	BuildKit.box(self, Vector3(0.04, 0.7, 0.04), Vector3(11.05, 0.75, 10.5), BuildKit.color_mat(Color(0.5, 0.38, 0.22)), false, Vector3(0, 0, 25))
	BuildKit.box(self, Vector3(0.18, 0.12, 0.03), Vector3(10.95, 0.5, 10.5), BuildKit.color_mat(Color(0.35, 0.35, 0.37), 0.4, 0.8), false, Vector3(0, 0, 25))
	# Wäscheleine hinter der Hütte
	var pole := BuildKit.color_mat(Color(0.4, 0.4, 0.42), 0.5, 0.6)
	BuildKit.cylinder(self, 0.04, 2.0, Vector3(-12.0, 1.0, -9.0), pole, true, Vector3.ZERO, -1.0, 8)
	BuildKit.cylinder(self, 0.04, 2.0, Vector3(-5.0, 1.0, -9.0), pole, true, Vector3.ZERO, -1.0, 8)
	BuildKit.box(self, Vector3(7.0, 0.01, 0.01), Vector3(-8.5, 1.9, -9.0), BuildKit.color_mat(Color(0.8, 0.8, 0.78)), false)
	BuildKit.box(self, Vector3(0.6, 0.8, 0.01), Vector3(-9.5, 1.5, -9.0), BuildKit.color_mat(Color(0.55, 0.6, 0.65), 1.0), false)
	BuildKit.box(self, Vector3(0.5, 0.6, 0.01), Vector3(-8.2, 1.6, -9.0), BuildKit.color_mat(Color(0.7, 0.68, 0.6), 1.0), false)
	# Picknicktisch
	var table := BuildKit.wood_mat(Color(0.4, 0.3, 0.2), 0, 0.15, 0.05)
	BuildKit.box_mm(self, Vector3(-12.0, 0.72, -3.4), Vector3(-10.0, 0.78, -2.6), table, true)
	BuildKit.box_mm(self, Vector3(-12.0, 0.42, -4.0), Vector3(-10.0, 0.46, -3.7), table, true)
	BuildKit.box_mm(self, Vector3(-12.0, 0.42, -2.3), Vector3(-10.0, 0.46, -2.0), table, true)
	for x: float in [-11.8, -10.2]:
		BuildKit.box_mm(self, Vector3(x - 0.05, 0, -3.9), Vector3(x + 0.05, 0.72, -2.1), table, false)
	# Zwei alte Laubbäume auf dem Grundstück
	_garden_tree(Vector3(-16.0, 0, -12.0), 1.0)
	_garden_tree(Vector3(17.5, 0, 14.0), 0.85)


func _garden_tree(pos: Vector3, s: float) -> void:
	var bark := BuildKit.color_mat(Color(0.28, 0.22, 0.16), 0.95)
	var leaves := BuildKit.color_mat(Color(0.2, 0.27, 0.11), 0.9)
	BuildKit.cylinder(self, 0.35 * s, 5.0 * s, pos + Vector3(0, 2.5 * s, 0), bark, true, Vector3.ZERO, 0.22 * s, 10)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(pos.x * 13.0 + pos.z)
	for i in 6:
		var off := Vector3(rng.randf_range(-1.8, 1.8), rng.randf_range(-0.6, 1.2), rng.randf_range(-1.8, 1.8)) * s
		var r := rng.randf_range(1.6, 2.4) * s
		var crown := BuildKit.sphere(self, r, pos + Vector3(0, 5.6 * s, 0) + off, leaves, Vector3(1, 0.8, 1), 12)
		crown.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
