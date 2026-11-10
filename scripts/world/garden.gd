class_name Garden
extends Node3D
## Grundstück rund um die Hütte (GDD 3.4): Rundholzzaun, Hochbeete, Regentonne,
## Hackklotz, Wäscheleine, Picknicktisch, zwei alte Laubbäume.
## Später wird das Grundstück frei bebaubar (Base Building Manager).

const FENCE_MIN := Vector2(-20.0, -16.0)
const FENCE_MAX := Vector2(22.0, 18.0)
var _seg_count: int = 0
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
		# jedes Zaunfeld ein eigener Knoten (feste Namen: nachts kann ein Loch hineinkommen)
		var seg := Node3D.new()
		seg.name = "FenceSeg_%d" % _seg_count
		seg.add_to_group("fence_segment")
		seg.set_meta("along_x", along_x)
		_seg_count += 1
		add_child(seg)
		for h: float in [0.5, 0.98]:
			var y := h + _rng.randf_range(-0.04, 0.04)
			var pos := Vector3(mid, y, a.y + 0.08) if along_x else Vector3(a.x + 0.08, y, mid)
			var rot := Vector3(0, 0, 90 + _rng.randf_range(-2, 2)) if along_x else Vector3(90 + _rng.randf_range(-2, 2), 0, 0)
			BuildKit.cylinder(seg, 0.05, length, pos, m_rail, false, rot, -1.0, 6)
		var col_size := Vector3(e - s, 1.0, 0.15) if along_x else Vector3(0.15, 1.0, e - s)
		var col_pos := Vector3(mid, 0.5, a.y) if along_x else Vector3(a.x, 0.5, mid)
		BuildKit.collider_box(seg, col_size, col_pos)
		seg.set_meta("center", col_pos)


func _build_props() -> void:
	var soil := BuildKit.tex_mat("grass_ground", 0.5, Color(0.22, 0.15, 0.1))
	var frame := BuildKit.tex_mat("planks_h", 0.6, Color(0.9, 0.85, 0.8))
	var leaf := BuildKit.cutout_mat("fern", Color(0.9, 1.1, 0.8))
	# Hochbeete westlich der Hütte mit Pflanzen
	# Hochbeete westlich der Hütte: bepflanzbar (GardenBed, Zustand im Versorgungs-Manager)
	var beds := [Vector3(-14.0, 0, 6.0), Vector3(-14.0, 0, 9.5), Vector3(-10.5, 0, 6.0), Vector3(-10.5, 0, 9.5)]
	for i in beds.size():
		var gb := GardenBed.new()
		gb.name = "GardenBed%d" % (i + 1)
		gb.index = i
		gb.position = beds[i]
		add_child(gb)
	_build_rain_barrel(Vector3(6.9, 0.0, -2.6))
	var band := BuildKit.tex_mat("metal", 0.3, Color(0.7, 0.7, 0.7), 0.5)
	var barrel_water := WaterSource.new()
	barrel_water.name = "RainBarrel"
	barrel_water.label = "Regentonne"
	barrel_water.contaminable = true  # wird mit Bach und Leitung zusammen vergiftet
	barrel_water.anchor = Vector3(6.9, 0.0, -2.6)
	barrel_water.collider_size = Vector3(0.9, 1.05, 0.9)
	add_child(barrel_water)
	# Hackklotz mit Axt neben dem Schuppen, Späne
	BuildKit.cylinder(self, 0.32, 0.5, Vector3(11.0, 0.25, 10.5), BuildKit.tex_mat("bark", 0.6), true, Vector3.ZERO, -1.0, 10)
	var block_top := BuildKit.cylinder(self, 0.16, 0.01, Vector3(11.0, 0.505, 10.5), BuildKit.log_end_mat(), false, Vector3.ZERO, -1.0, 10)
	block_top.scale = Vector3(0.3 / 0.16, 1.0, 0.3 / 0.16)
	var axe := ItemPickup.new()
	axe.name = "Axe"
	axe.item_id = "axe"
	axe.amount = 1
	axe.collider_size = Vector3(0.8, 0.6, 0.8)
	axe.collider_offset = Vector3(11.0, 0.8, 10.5)
	add_child(axe)
	# Axt steckt mit der Klinge schräg im Hackklotz, der Stiel ragt nach oben
	# (gleiches Modell wie in der Hand: runder Stiel, Stahlkopf mit Schneide und Nacken)
	var axe_vis := Node3D.new()
	axe_vis.position = Vector3(11.0, 0.505 + 0.143 - 0.03, 10.5)
	axe_vis.rotation_degrees = Vector3(-60, 35, 5)
	axe.add_child(axe_vis)
	axe.visuals.append(axe_vis)
	var handle := BuildKit.tex_mat("planks_v", 0.2, Color(1.1, 0.95, 0.8))
	var steel := BuildKit.tex_mat("metal", 0.15, Color(1.4, 1.4, 1.42), 0.35)
	BuildKit.cylinder(axe_vis, 0.017, 0.66, Vector3(0, 0.3, 0), handle, false, Vector3.ZERO, 0.015, 8)
	BuildKit.box(axe_vis, Vector3(0.034, 0.1, 0.06), Vector3(0, 0, 0), steel, false)
	BuildKit.box(axe_vis, Vector3(0.016, 0.13, 0.14), Vector3(0, 0, -0.09), steel, false)
	BuildKit.box(axe_vis, Vector3(0.008, 0.15, 0.02), Vector3(0, 0, -0.165), BuildKit.tex_mat("metal", 0.1, Color(2.0, 2.0, 2.0), 0.2), false)
	BuildKit.box(axe_vis, Vector3(0.03, 0.05, 0.03), Vector3(0, 0, 0.045), steel, false)
	# Kerbe und Spalt im Hackklotz unter der Klinge
	# liegt knapp über der Schnittfläche (nicht in derselben Ebene – sonst flimmert es)
	BuildKit.box(self, Vector3(0.02, 0.004, 0.2), Vector3(11.0, 0.5125, 10.5), BuildKit.color_mat(Color(0.2, 0.14, 0.09)), false, Vector3(0, 35, 0))
	for i in 12:
		BuildKit.box(self, Vector3(0.08, 0.01, 0.04), Vector3(11.0 + _rng.randf_range(-0.8, 0.8), 0.01, 10.5 + _rng.randf_range(-0.8, 0.8)),
				BuildKit.color_mat(Color(0.62, 0.5, 0.34)), false, Vector3(0, _rng.randf() * 180, 0))
	# Wäscheleine hinter der Hütte (Handtücher als eigene Knoten – nachts können welche fehlen)
	var pole := BuildKit.tex_mat("logs", 0.6)
	BuildKit.cylinder(self, 0.05, 2.1, Vector3(-12.0, 1.05, -9.0), pole, true, Vector3.ZERO, -1.0, 7)
	BuildKit.cylinder(self, 0.05, 2.1, Vector3(-5.0, 1.05, -9.0), pole, true, Vector3.ZERO, -1.0, 7)
	BuildKit.box(self, Vector3(7.0, 0.01, 0.01), Vector3(-8.5, 1.95, -9.0), BuildKit.color_mat(Color(0.8, 0.8, 0.78)), false)
	var towels := Node3D.new()
	towels.name = "Towels"
	add_child(towels)
	var t0 := BuildKit.box(towels, Vector3(0.6, 0.8, 0.01), Vector3(-9.5, 1.55, -9.0), BuildKit.tex_mat("fabric", 0.4, Color(1.3, 1.45, 1.6)), false)
	var t1 := BuildKit.box(towels, Vector3(0.5, 0.6, 0.01), Vector3(-8.2, 1.65, -9.0), BuildKit.tex_mat("fabric", 0.4, Color(1.7, 1.65, 1.5)), false)
	var t2 := BuildKit.box(towels, Vector3(0.4, 0.5, 0.01), Vector3(-7.2, 1.7, -9.0), BuildKit.tex_mat("fabric_red", 0.4), false)
	for i in 3:
		[t0, t1, t2][i].name = "Towel_%d" % i
	# Picknicktisch: Platte auf zwei X-Böcken, zwei Sitzbänke mit eigenen Beinen – alles steht auf dem Boden
	var g := Terrain.height_at(-11.0, -3.0)
	BuildKit.box_mm(self, Vector3(-12.0, g + 0.72, -3.4), Vector3(-10.0, g + 0.78, -2.6), m_wood, true)
	for bz: Array in [[-4.0, -3.7], [-2.3, -2.0]]:
		BuildKit.box_mm(self, Vector3(-12.0, g + 0.42, bz[0]), Vector3(-10.0, g + 0.46, bz[1]), m_wood, true)
		var cz: float = (bz[0] + bz[1]) * 0.5
		for x: float in [-11.75, -10.25]:
			# zwei schräge Beine je Bankende, unten gespreizt
			for sx: float in [-1.0, 1.0]:
				BuildKit.box(self, Vector3(0.06, 0.5, 0.07), Vector3(x + sx * 0.06, g + 0.2, cz), m_wood, false, Vector3(0, 0, -sx * 12.0))
	for x: float in [-11.8, -10.2]:
		for a: float in [30.0, -30.0]:
			BuildKit.box(self, Vector3(0.08, 0.9, 0.08), Vector3(x, g + 0.36, -3.0), m_wood, false, Vector3(a, 0, 0))
		# Querstrebe unter der Platte
		BuildKit.box(self, Vector3(0.08, 0.06, 0.78), Vector3(x, g + 0.68, -3.0), m_wood, false)
	_build_planting()
	# Zwei alte Laubbäume auf dem Grundstück
	_garden_tree(Vector3(-16.0, 0, -12.0), 1.0)
	_garden_tree(Vector3(17.5, 0, 14.0), 0.85)


## Regentonne aus Holzdauben mit Eisenreifen, Zapfhahn, Wasser mit Laub,
## halbem Deckel, Schöpfkelle und Gießkanne daneben.
func _build_rain_barrel(at: Vector3) -> void:
	var root := Node3D.new()
	root.name = "RainBarrelModel"
	root.position = at
	add_child(root)
	var h := 0.98
	var stone := BuildKit.tex_mat("stone", 0.5)
	BuildKit.box(root, Vector3(0.95, 0.1, 0.9), Vector3(0, 0.05, 0), stone, true, Vector3(0, 12, 0))
	var y0 := 0.1
	# Dauben: einzelne gebogene Bretter mit kleinen Fugen und unterschiedlichem Farbton
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var staves := 18
	var rows := 6
	for k in staves:
		var a0 := TAU * (k + 0.04) / staves
		var a1 := TAU * (k + 0.96) / staves
		var shade := _rng.randf_range(0.75, 1.15)
		for i in rows:
			var t0 := float(i) / rows
			var t1 := float(i + 1) / rows
			var r0 := 0.34 + 0.05 * sin(PI * t0)
			var r1 := 0.34 + 0.05 * sin(PI * t1)
			var q := [Vector3(cos(a0) * r0, y0 + t0 * h, sin(a0) * r0), Vector3(cos(a1) * r0, y0 + t0 * h, sin(a1) * r0),
					Vector3(cos(a1) * r1, y0 + t1 * h, sin(a1) * r1), Vector3(cos(a0) * r1, y0 + t1 * h, sin(a0) * r1)]
			var n := Vector3(cos((a0 + a1) * 0.5), 0, sin((a0 + a1) * 0.5))
			# unten feucht und dunkler
			var c := Color(1, 1, 1) * shade * lerpf(0.6, 1.0, minf(t0 * 3.0, 1.0))
			for idx: int in [0, 2, 1, 0, 3, 2]:
				st.set_color(c)
				st.set_normal(n)
				st.add_vertex(q[idx])
	var staves_mi := MeshInstance3D.new()
	staves_mi.mesh = st.commit()
	var wood := StandardMaterial3D.new()
	wood.albedo_texture = TextureFactory.get_texture("planks_v")
	wood.albedo_color = Color(1.35, 1.15, 0.95)
	wood.vertex_color_use_as_albedo = true
	wood.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	wood.uv1_triplanar = true
	wood.uv1_world_triplanar = true
	wood.uv1_scale = Vector3(2.0, 2.0, 2.0)
	wood.cull_mode = BaseMaterial3D.CULL_DISABLED
	wood.roughness = 0.95
	staves_mi.material_override = wood
	root.add_child(staves_mi)
	# dunkler Innenraum und Boden
	BuildKit.cylinder(root, 0.33, 0.02, Vector3(0, y0 + 0.02, 0), BuildKit.color_mat(Color(0.12, 0.08, 0.05)), false, Vector3.ZERO, -1.0, 16)
	# Eisenreifen der Bauchform folgend, mit Nieten
	var iron := BuildKit.tex_mat("metal", 0.3, Color(1.1, 0.75, 0.55), 0.6)
	for t: float in [0.08, 0.36, 0.64, 0.92]:
		var rr := 0.34 + 0.05 * sin(PI * t) + 0.008
		BuildKit.lathe(root, PackedVector2Array([Vector2(rr, y0 + t * h - 0.025), Vector2(rr + 0.004, y0 + t * h), Vector2(rr, y0 + t * h + 0.025)]),
				Vector3.ZERO, iron, 20)
		for k in 6:
			var a := TAU * k / 6.0 + t
			BuildKit.sphere(root, 0.009, Vector3(cos(a) * (rr + 0.004), y0 + t * h, sin(a) * (rr + 0.004)), iron, Vector3.ONE, 4)
	# Wasser mit treibendem Laub
	var water := StandardMaterial3D.new()
	water.albedo_texture = TextureFactory.get_texture("water")
	water.albedo_color = Color(0.25, 0.3, 0.3)
	water.roughness = 0.05
	water.metallic = 0.4
	water.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	BuildKit.cylinder(root, 0.35, 0.01, Vector3(0, y0 + h - 0.12, 0), water, false, Vector3.ZERO, -1.0, 16)
	var leaf := BuildKit.cutout_mat("leaves", Color(0.9, 0.6, 0.3))
	for k in 5:
		var q := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(0.12, 0.12)
		qm.material = leaf
		q.mesh = qm
		q.position = Vector3(_rng.randf_range(-0.2, 0.2), y0 + h - 0.11, _rng.randf_range(-0.2, 0.2))
		q.rotation_degrees = Vector3(-90, _rng.randf() * 360.0, 0)
		root.add_child(q)
	# halber Deckel aus zwei Brettern, verrutscht
	var lid := BuildKit.tex_mat("planks_h", 0.4, Color(0.85, 0.8, 0.72))
	BuildKit.box(root, Vector3(0.75, 0.025, 0.17), Vector3(0.0, y0 + h + 0.015, -0.18), lid, false, Vector3(0, 8, 2))
	BuildKit.box(root, Vector3(0.65, 0.025, 0.15), Vector3(-0.03, y0 + h + 0.02, -0.02), lid, false, Vector3(0, 11, -2))
	BuildKit.box(root, Vector3(0.05, 0.03, 0.4), Vector3(0.18, y0 + h + 0.045, -0.1), lid, false, Vector3(0, 10, 0))
	# Schöpfkelle am Rand
	var tin := BuildKit.tex_mat("metal", 0.2, Color(1.5, 1.5, 1.45), 0.4)
	BuildKit.box(root, Vector3(0.02, 0.3, 0.015), Vector3(0.36, y0 + h - 0.05, 0.12), tin, false, Vector3(0, 0, -15))
	BuildKit.lathe(root, PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.05, 0.01), Vector2(0.06, 0.05)]), Vector3(0.43, y0 + h - 0.24, 0.12), tin, 10, Vector3(0, 0, 180))
	# Zapfhahn unten mit nasser Stelle
	var brass := BuildKit.color_mat(Color(0.55, 0.42, 0.2), 0.4, 0.7)
	BuildKit.cylinder(root, 0.02, 0.1, Vector3(0, y0 + 0.14, 0.4), brass, false, Vector3(90, 0, 0), -1.0, 8)
	BuildKit.box(root, Vector3(0.015, 0.06, 0.015), Vector3(0, y0 + 0.11, 0.44), brass, false)
	BuildKit.box(root, Vector3(0.06, 0.012, 0.012), Vector3(0, y0 + 0.19, 0.42), brass, false)
	var wet := BuildKit.color_mat(Color(0.16, 0.14, 0.11), 0.35)
	BuildKit.cylinder(root, 0.13, 0.004, Vector3(0.02, 0.01, 0.52), wet, false, Vector3.ZERO, -1.0, 10)
	# Moos am Fuß
	for k in 7:
		var a := _rng.randf() * TAU
		BuildKit.sphere(root, 0.07, Vector3(cos(a) * 0.38, y0 + 0.02, sin(a) * 0.38), BuildKit.tex_mat("moss", 0.3), Vector3(1.2, 0.5, 1.0), 6)
	# Verzinkte Gießkanne daneben
	var can := Node3D.new()
	can.position = Vector3(0.62, 0.0, 0.35)
	can.rotation_degrees.y = 35.0
	root.add_child(can)
	var zinc := BuildKit.tex_mat("metal", 0.25, Color(1.35, 1.4, 1.4), 0.5)
	BuildKit.lathe(can, PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.13, 0.0), Vector2(0.14, 0.02), Vector2(0.13, 0.3), Vector2(0.1, 0.33), Vector2(0.0, 0.34)]), Vector3.ZERO, zinc, 14)
	BuildKit.cylinder(can, 0.015, 0.4, Vector3(0.22, 0.2, 0), zinc, false, Vector3(0, 0, -55), 0.025, 8)
	BuildKit.cylinder(can, 0.045, 0.04, Vector3(0.38, 0.32, 0), zinc, false, Vector3(0, 0, -55), 0.05, 10)
	BuildKit.box(can, Vector3(0.24, 0.02, 0.02), Vector3(-0.02, 0.43, 0), zinc, false)
	BuildKit.box(can, Vector3(0.02, 0.12, 0.02), Vector3(-0.13, 0.37, 0), zinc, false)
	BuildKit.box(can, Vector3(0.02, 0.1, 0.02), Vector3(0.09, 0.38, 0), zinc, false)


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
		var s := _rng.randf_range(0.45, 0.8)
		shrubs.append(Transform3D(Basis.from_euler(Vector3(0, _rng.randf() * TAU, 0)).scaled(Vector3(s, s * 0.95, s)),
				Vector3(p.x + _rng.randf_range(-0.15, 0.15), -0.03, p.y + _rng.randf_range(-0.15, 0.15))))
		for k in 3:
			flowers.append(Transform3D(Basis().scaled(Vector3(0.04, 0.03, 0.04)),
					Vector3(p.x + _rng.randf_range(-0.4, 0.4), _rng.randf_range(0.35, 0.7), p.y + _rng.randf_range(-0.3, 0.3))))
			var c := [Color(0.9, 0.85, 0.95), Color(0.85, 0.3, 0.25), Color(0.95, 0.8, 0.25), Color(0.6, 0.45, 0.85)]
			flower_cols.append(c[_rng.randi() % c.size()])
	var cols: Array[Color] = []
	for i in shrubs.size():
		cols.append(Color(0.58, 0.72, 0.48) * _rng.randf_range(0.85, 1.1))
	# Zwei Buschformen im Wechsel (dasselbe Modell wie im Wald)
	for v in 2:
		var tv: Array[Transform3D] = []
		var cv: Array[Color] = []
		for i in range(v, shrubs.size(), 2):
			tv.append(shrubs[i])
			cv.append(cols[i])
		_multimesh(Forest.bush_mesh(500 + v * 11), tv, cv, null)
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
