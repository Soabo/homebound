class_name Garden
extends Node3D
## Grundstück rund um die Hütte (GDD 3.4): Rundholzzaun, Hochbeete, Regentonne,
## Hackklotz, Wäscheleine, Picknicktisch, zwei alte Laubbäume.
## Später wird das Grundstück frei bebaubar (Base Building Manager).

const FENCE_MIN := Vector2(-20.0, -16.0)
const FENCE_MAX := Vector2(22.0, 18.0)
const POST_SPACING := 2.6

var _rng := RandomNumberGenerator.new()
var m_post: Material
var m_rail: Material
var m_wood: Material


func _ready() -> void:
	name = "Garden"
	_rng.seed = 99
	m_post = BuildKit.tex_mat("logs", 0.8, Color(0.85, 0.85, 0.8))
	m_rail = BuildKit.tex_mat("logs", 0.9, Color(1.0, 0.95, 0.88))
	m_wood = BuildKit.tex_mat("planks_h", 0.8)
	_build_fence()
	_build_props()


func _build_fence() -> void:
	# Lücken: Tor zur Zufahrt im Süden, schmaler Durchgang in den Wald im Norden
	_fence_line(Vector2(FENCE_MIN.x, FENCE_MAX.y), Vector2(FENCE_MAX.x, FENCE_MAX.y), Vector2(-5.0, -1.0))
	_fence_line(Vector2(FENCE_MIN.x, FENCE_MIN.y), Vector2(FENCE_MAX.x, FENCE_MIN.y), Vector2(3.0, 6.0))
	_fence_line(Vector2(FENCE_MIN.x, FENCE_MIN.y), Vector2(FENCE_MIN.x, FENCE_MAX.y), Vector2.ZERO)
	_fence_line(Vector2(FENCE_MAX.x, FENCE_MIN.y), Vector2(FENCE_MAX.x, FENCE_MAX.y), Vector2.ZERO)
	# Torbogen über der Zufahrt – hoch genug zum Durchgehen
	for x: float in [-5.0, -1.0]:
		BuildKit.cylinder(self, 0.13, 2.8, Vector3(x, 1.4, FENCE_MAX.y), m_post, true, Vector3.ZERO, 0.11, 8)
	BuildKit.cylinder(self, 0.1, 4.6, Vector3(-3.0, 2.72, FENCE_MAX.y), m_rail, false, Vector3(0, 0, 90), -1.0, 8)
	BuildKit.box(self, Vector3(1.2, 0.3, 0.05), Vector3(-3.0, 2.45, FENCE_MAX.y + 0.06), m_wood, false)
	for x: float in [-3.45, -2.55]:
		BuildKit.box(self, Vector3(0.015, 0.2, 0.015), Vector3(x, 2.62, FENCE_MAX.y + 0.06), BuildKit.color_mat(Color(0.2, 0.2, 0.2)), false)


## Zaunlinie entlang x oder z mit runden Pfosten und zwei Rundholz-Querstangen.
## gap = Lücke (von, bis) entlang der Laufrichtung, Vector2.ZERO = keine Lücke.
func _fence_line(a: Vector2, b: Vector2, gap: Vector2) -> void:
	var along_x := absf(b.x - a.x) > absf(b.y - a.y)
	var start := a.x if along_x else a.y
	var end := b.x if along_x else b.y
	var has_gap := gap != Vector2.ZERO
	var posts: Array[float] = []
	var p := start
	while p < end - 0.3:
		if not (has_gap and p > gap.x - 0.3 and p < gap.y + 0.3):
			posts.append(p)
		p += POST_SPACING
	posts.append(end)
	if has_gap:
		posts.append(gap.x)
		posts.append(gap.y)
	posts.sort()
	for v in posts:
		var pos := Vector3(v, 0.0, a.y) if along_x else Vector3(a.x, 0.0, v)
		var h := _rng.randf_range(1.1, 1.25)
		BuildKit.cylinder(self, 0.075, h, pos + Vector3(0, h * 0.5, 0), m_post, true, Vector3(_rng.randf_range(-3, 3), 0, _rng.randf_range(-3, 3)), 0.06, 7)
	for i in posts.size() - 1:
		var s := posts[i]
		var e := posts[i + 1]
		var mid := (s + e) * 0.5
		if has_gap and mid > gap.x and mid < gap.y:
			continue
		var length := e - s + 0.25
		for h: float in [0.5, 0.98]:
			var y := h + _rng.randf_range(-0.04, 0.04)
			var pos := Vector3(mid, y, a.y + 0.08) if along_x else Vector3(a.x + 0.08, y, mid)
			var rot := Vector3(0, 0, 90 + _rng.randf_range(-2, 2)) if along_x else Vector3(90 + _rng.randf_range(-2, 2), 0, 0)
			BuildKit.cylinder(self, 0.05, length, pos, m_rail, false, rot, -1.0, 6)
		var col_size := Vector3(e - s, 1.0, 0.15) if along_x else Vector3(0.15, 1.0, e - s)
		var col_pos := Vector3(mid, 0.5, a.y) if along_x else Vector3(a.x, 0.5, mid)
		BuildKit.collider_box(self, col_size, col_pos)


func _build_props() -> void:
	var soil := BuildKit.tex_mat("grass_ground", 0.5, Color(0.22, 0.15, 0.1))
	var frame := BuildKit.tex_mat("planks_h", 0.6, Color(0.9, 0.85, 0.8))
	var leaf := BuildKit.cutout_mat("fern", Color(0.9, 1.1, 0.8))
	# Hochbeete westlich der Hütte mit Pflanzen
	for bed: Vector3 in [Vector3(-14.0, 0, 6.0), Vector3(-14.0, 0, 9.5), Vector3(-10.5, 0, 6.0), Vector3(-10.5, 0, 9.5)]:
		BuildKit.box(self, Vector3(2.4, 0.42, 1.4), bed + Vector3(0, 0.21, 0), frame, true)
		BuildKit.box(self, Vector3(2.3, 0.05, 1.3), bed + Vector3(0, 0.42, 0), soil, false)
		for i in 5:
			for j in 2:
				var q := MeshInstance3D.new()
				var qm := QuadMesh.new()
				qm.size = Vector2(0.45, 0.45)
				qm.material = leaf
				q.mesh = qm
				q.position = bed + Vector3(-0.9 + i * 0.45, 0.66, -0.3 + j * 0.6)
				q.rotation_degrees.y = _rng.randf() * 180.0
				add_child(q)
	# Regentonne mit Eisenbändern
	var barrel := BuildKit.tex_mat("planks_v", 0.5, Color(0.85, 0.8, 0.75))
	var band := BuildKit.tex_mat("metal", 0.3, Color(0.7, 0.7, 0.7), 0.5)
	BuildKit.cylinder(self, 0.4, 1.0, Vector3(6.9, 0.5, -2.6), barrel, true, Vector3.ZERO, 0.37, 12)
	for y: float in [0.15, 0.85]:
		BuildKit.cylinder(self, 0.41, 0.05, Vector3(6.9, y, -2.6), band, false, Vector3.ZERO, -1.0, 12)
	BuildKit.cylinder(self, 0.36, 0.01, Vector3(6.9, 0.95, -2.6), BuildKit.color_mat(Color(0.05, 0.07, 0.08), 0.05), false, Vector3.ZERO, -1.0, 12)
	# Hackklotz mit Axt neben dem Schuppen, Späne
	BuildKit.cylinder(self, 0.32, 0.5, Vector3(11.0, 0.25, 10.5), BuildKit.tex_mat("bark", 0.6), true, Vector3.ZERO, -1.0, 10)
	BuildKit.cylinder(self, 0.3, 0.01, Vector3(11.0, 0.505, 10.5), BuildKit.color_mat(Color(0.6, 0.48, 0.32)), false, Vector3.ZERO, -1.0, 10)
	BuildKit.box(self, Vector3(0.04, 0.7, 0.04), Vector3(11.05, 0.8, 10.5), m_wood, false, Vector3(0, 0, 25))
	BuildKit.box(self, Vector3(0.18, 0.12, 0.03), Vector3(10.95, 0.55, 10.5), band, false, Vector3(0, 0, 25))
	for i in 12:
		BuildKit.box(self, Vector3(0.08, 0.01, 0.04), Vector3(11.0 + _rng.randf_range(-0.8, 0.8), 0.01, 10.5 + _rng.randf_range(-0.8, 0.8)),
				BuildKit.color_mat(Color(0.62, 0.5, 0.34)), false, Vector3(0, _rng.randf() * 180, 0))
	# Wäscheleine hinter der Hütte
	var pole := BuildKit.tex_mat("logs", 0.6)
	BuildKit.cylinder(self, 0.05, 2.1, Vector3(-12.0, 1.05, -9.0), pole, true, Vector3.ZERO, -1.0, 7)
	BuildKit.cylinder(self, 0.05, 2.1, Vector3(-5.0, 1.05, -9.0), pole, true, Vector3.ZERO, -1.0, 7)
	BuildKit.box(self, Vector3(7.0, 0.01, 0.01), Vector3(-8.5, 1.95, -9.0), BuildKit.color_mat(Color(0.8, 0.8, 0.78)), false)
	BuildKit.box(self, Vector3(0.6, 0.8, 0.01), Vector3(-9.5, 1.55, -9.0), BuildKit.tex_mat("fabric", 0.4, Color(1.3, 1.45, 1.6)), false)
	BuildKit.box(self, Vector3(0.5, 0.6, 0.01), Vector3(-8.2, 1.65, -9.0), BuildKit.tex_mat("fabric", 0.4, Color(1.7, 1.65, 1.5)), false)
	BuildKit.box(self, Vector3(0.4, 0.5, 0.01), Vector3(-7.2, 1.7, -9.0), BuildKit.tex_mat("fabric_red", 0.4), false)
	# Picknicktisch
	BuildKit.box_mm(self, Vector3(-12.0, 0.72, -3.4), Vector3(-10.0, 0.78, -2.6), m_wood, true)
	BuildKit.box_mm(self, Vector3(-12.0, 0.42, -4.0), Vector3(-10.0, 0.46, -3.7), m_wood, true)
	BuildKit.box_mm(self, Vector3(-12.0, 0.42, -2.3), Vector3(-10.0, 0.46, -2.0), m_wood, true)
	for x: float in [-11.8, -10.2]:
		BuildKit.box(self, Vector3(0.08, 0.85, 0.08), Vector3(x, 0.38, -3.0), m_wood, false, Vector3(30, 0, 0))
		BuildKit.box(self, Vector3(0.08, 0.85, 0.08), Vector3(x, 0.38, -3.0), m_wood, false, Vector3(-30, 0, 0))
	_build_planting()
	# Zwei alte Laubbäume auf dem Grundstück
	_garden_tree(Vector3(-16.0, 0, -12.0), 1.0)
	_garden_tree(Vector3(17.5, 0, 14.0), 0.85)


func _garden_tree(pos: Vector3, s: float) -> void:
	var bark := BuildKit.tex_mat("bark", 1.2)
	var leaves := BuildKit.tex_mat("grass_ground", 0.6, Color(0.2, 0.28, 0.11))
	BuildKit.cylinder(self, 0.38 * s, 5.0 * s, pos + Vector3(0, 2.5 * s, 0), bark, true, Vector3.ZERO, 0.24 * s, 9)
	# Hauptäste
	for i in 3:
		var a := TAU * float(i) / 3.0 + 0.4
		BuildKit.cylinder(self, 0.12 * s, 2.2 * s, pos + Vector3(cos(a) * 0.6, 4.6, sin(a) * 0.6) * Vector3(s, s, s),
				bark, false, Vector3(sin(a) * 40.0, 0, -cos(a) * 40.0), 0.06 * s, 6)
	for i in 7:
		var off := Vector3(_rng.randf_range(-1.8, 1.8), _rng.randf_range(-0.6, 1.2), _rng.randf_range(-1.8, 1.8)) * s
		var r := _rng.randf_range(1.5, 2.3) * s
		var crown := BuildKit.sphere(self, r, pos + Vector3(0, 5.8 * s, 0) + off, leaves, Vector3(1, 0.8, 1), 8)
		crown.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON


## Sträucher und Blumen rund um die Hütte und vor der Veranda.
func _build_planting() -> void:
	var leaf_mesh := Forest._leaf_cluster_mesh()
	var shrubs: Array[Transform3D] = []
	var flowers: Array[Transform3D] = []
	var flower_cols: Array[Color] = []
	var spots: Array[Vector2] = []
	# Entlang der West-, Nord- und Ostwand
	for i in 16:
		spots.append(Vector2(-6.9, -4.2 + i * 0.55))
		spots.append(Vector2(-5.5 + i * 0.75, -5.4))
	for i in 10:
		spots.append(Vector2(6.95, 0.0 + i * 0.45))
	# Vor der Veranda links und rechts der Treppe
	for i in 6:
		spots.append(Vector2(-5.4 + i * 0.25, 7.0))
		spots.append(Vector2(-1.6 + i * 0.45, 7.0))
	for p in spots:
		if absf(p.x + 7.0) < 0.6 and p.y > 0.9 and p.y < 2.6:
			continue  # Schornstein
		var s := _rng.randf_range(0.5, 0.95)
		shrubs.append(Transform3D(Basis.from_euler(Vector3(0, _rng.randf() * TAU, 0)).scaled(Vector3(s, s, s)),
				Vector3(p.x + _rng.randf_range(-0.15, 0.15), s * 0.42, p.y + _rng.randf_range(-0.15, 0.15))))
		for k in 3:
			flowers.append(Transform3D(Basis().scaled(Vector3(0.04, 0.03, 0.04)),
					Vector3(p.x + _rng.randf_range(-0.4, 0.4), _rng.randf_range(0.35, 0.7), p.y + _rng.randf_range(-0.3, 0.3))))
			var c := [Color(0.9, 0.85, 0.95), Color(0.85, 0.3, 0.25), Color(0.95, 0.8, 0.25), Color(0.6, 0.45, 0.85)]
			flower_cols.append(c[_rng.randi() % c.size()])
	var cols: Array[Color] = []
	for i in shrubs.size():
		cols.append(Color(0.7, 0.9, 0.55) * _rng.randf_range(0.8, 1.1))
	_multimesh(leaf_mesh, shrubs, cols, BuildKit.cutout_mat("leaves"))
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 6
	sphere.rings = 3
	var fm := StandardMaterial3D.new()
	fm.vertex_color_use_as_albedo = true
	_multimesh(sphere, flowers, flower_cols, fm)


func _multimesh(mesh: Mesh, transforms: Array[Transform3D], colors: Array[Color], mat: Material) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
		mm.set_instance_color(i, colors[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	add_child(mmi)
