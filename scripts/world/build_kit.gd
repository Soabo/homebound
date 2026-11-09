class_name BuildKit
extends RefCounted
## Werkzeugkasten zum Bauen der Welt per Code:
## Kisten, Zylinder, Wände mit Öffnungen, Materialien.
## Alle Maße in Metern.

static var _materials: Dictionary = {}
static var _wood_shader: Shader
static var _stone_shader: Shader


# --- Materialien --------------------------------------------------------

static func color_mat(color: Color, roughness: float = 0.9, metallic: float = 0.0) -> StandardMaterial3D:
	var key := "c_%s_%.2f_%.2f" % [color.to_html(), roughness, metallic]
	if _materials.has(key):
		return _materials[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	_materials[key] = m
	return m


## Eigenes Material pro Aufruf, damit es einzeln an/aus geschaltet werden kann.
static func emissive_mat(color: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	return m


static func glass_mat() -> StandardMaterial3D:
	var key := "glass"
	if _materials.has(key):
		return _materials[key]
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.55, 0.65, 0.7, 0.18)
	m.roughness = 0.05
	m.metallic_specular = 0.9
	_materials[key] = m
	return m


static func wood_mat(color: Color, axis: int = 1, stripe: float = 0.28, groove: float = 0.12) -> ShaderMaterial:
	var key := "w_%s_%d_%.2f_%.2f" % [color.to_html(), axis, stripe, groove]
	if _materials.has(key):
		return _materials[key]
	if _wood_shader == null:
		_wood_shader = load("res://shaders/wood_stripes.gdshader")
	var m := ShaderMaterial.new()
	m.shader = _wood_shader
	m.set_shader_parameter("base_color", color)
	m.set_shader_parameter("axis", axis)
	m.set_shader_parameter("stripe_size", stripe)
	m.set_shader_parameter("groove", groove)
	_materials[key] = m
	return m


static func stone_mat(color: Color, size: float = 0.32) -> ShaderMaterial:
	var key := "s_%s_%.2f" % [color.to_html(), size]
	if _materials.has(key):
		return _materials[key]
	if _stone_shader == null:
		_stone_shader = load("res://shaders/stone.gdshader")
	var m := ShaderMaterial.new()
	m.shader = _stone_shader
	m.set_shader_parameter("base_color", color)
	m.set_shader_parameter("stone_size", size)
	_materials[key] = m
	return m


## Material mit Pixel-Textur, in Weltkoordinaten projiziert (keine UVs nötig).
## repeat_m = wie viele Meter eine Textur-Kachel abdeckt.
static func tex_mat(kind: String, repeat_m: float = 1.0, tint: Color = Color.WHITE,
		roughness: float = 0.9) -> StandardMaterial3D:
	var key := "t_%s_%.2f_%s_%.2f" % [kind, repeat_m, tint.to_html(), roughness]
	if _materials.has(key):
		return _materials[key]
	var m := StandardMaterial3D.new()
	m.albedo_texture = TextureFactory.get_texture(kind)
	m.albedo_color = tint
	m.roughness = roughness
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_triplanar_sharpness = 4.0
	var s := 1.0 / repeat_m
	m.uv1_scale = Vector3(s, s, s)
	_materials[key] = m
	return m


## Für bewegte Dinge (Werkzeuge in der Hand, Türen): Texturen am Objekt festmachen statt an der Welt.
## Sonst „wandert“ die Holz-/Metallstruktur über das Objekt, wenn es sich bewegt.
static func localize_materials(n: Node) -> void:
	var list: Array = n.find_children("*", "MeshInstance3D", true, false)
	if n is MeshInstance3D:
		list.append(n)
	for mi: MeshInstance3D in list:
		var m := mi.material_override as StandardMaterial3D
		if m == null and mi.mesh and mi.mesh.get_surface_count() > 0:
			m = mi.get_active_material(0) as StandardMaterial3D
		if m == null or not m.uv1_world_triplanar:
			continue
		var key := "local_%d" % m.get_instance_id()
		if not _materials.has(key):
			var l := m.duplicate() as StandardMaterial3D
			l.uv1_world_triplanar = false
			_materials[key] = l
		mi.material_override = _materials[key]


## Jahresringe: Textur über normale UVs (Deckfläche des Zylinders).
static func log_end_mat() -> StandardMaterial3D:
	var key := "log_end"
	if _materials.has(key):
		return _materials[key]
	var m := StandardMaterial3D.new()
	m.albedo_texture = TextureFactory.get_texture("log_end")
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	m.uv1_triplanar = true
	m.uv1_world_triplanar = false
	m.uv1_scale = Vector3(1.0 / 0.32, 1.0 / 0.32, 1.0 / 0.32)
	m.uv1_offset = Vector3(0.5, 0.5, 0.5)
	m.roughness = 0.9
	_materials[key] = m
	return m


## Pflanzen-Karte: Textur mit Transparenz, beidseitig sichtbar.
static func cutout_mat(kind: String, tint: Color = Color.WHITE) -> StandardMaterial3D:
	var key := "cut_%s_%s" % [kind, tint.to_html()]
	if _materials.has(key):
		return _materials[key]
	var m := StandardMaterial3D.new()
	m.albedo_texture = TextureFactory.get_texture(kind)
	m.albedo_color = tint
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	m.roughness = 1.0
	m.vertex_color_use_as_albedo = true
	_materials[key] = m
	return m


# --- Grundformen --------------------------------------------------------

static func box(parent: Node, size: Vector3, pos: Vector3, mat: Material, collide: bool = true,
		rot_deg: Vector3 = Vector3.ZERO, node_name: String = "") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	bm.material = mat
	mi.mesh = bm
	mi.position = pos
	mi.rotation_degrees = rot_deg
	if node_name != "":
		mi.name = node_name
	parent.add_child(mi)
	if collide:
		var shape := BoxShape3D.new()
		shape.size = size
		_attach_collider(mi, shape)
	return mi


## Kiste über zwei Eckpunkte (min/max) – praktisch für Räume und Möbel.
static func box_mm(parent: Node, from: Vector3, to: Vector3, mat: Material, collide: bool = true,
		node_name: String = "") -> MeshInstance3D:
	var lo := Vector3(minf(from.x, to.x), minf(from.y, to.y), minf(from.z, to.z))
	var hi := Vector3(maxf(from.x, to.x), maxf(from.y, to.y), maxf(from.z, to.z))
	return box(parent, hi - lo, (lo + hi) * 0.5, mat, collide, Vector3.ZERO, node_name)


static func cylinder(parent: Node, radius: float, height: float, pos: Vector3, mat: Material,
		collide: bool = false, rot_deg: Vector3 = Vector3.ZERO, top_radius: float = -1.0,
		segments: int = 16) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.bottom_radius = radius
	cm.top_radius = radius if top_radius < 0.0 else top_radius
	cm.height = height
	cm.radial_segments = segments
	cm.rings = 1
	cm.material = mat
	mi.mesh = cm
	mi.position = pos
	mi.rotation_degrees = rot_deg
	parent.add_child(mi)
	if collide:
		var shape := CylinderShape3D.new()
		shape.radius = maxf(radius, cm.top_radius)
		shape.height = height
		_attach_collider(mi, shape)
	return mi


static func sphere(parent: Node, radius: float, pos: Vector3, mat: Material,
		scale: Vector3 = Vector3.ONE, segments: int = 16) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	sm.radial_segments = segments
	sm.rings = maxi(segments / 2, 4)
	sm.material = mat
	mi.mesh = sm
	mi.position = pos
	mi.scale = scale
	parent.add_child(mi)
	return mi


## Drehkörper aus einem Profil (x = Radius, y = Höhe), z. B. Fässer, Reifen, Kannen.
static func lathe(parent: Node, profile: PackedVector2Array, pos: Vector3, mat: Material,
		segments: int = 16, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in profile.size() - 1:
		var a := profile[i]
		var b := profile[i + 1]
		var slope := Vector2(b.y - a.y, -(b.x - a.x)).normalized()
		for k in segments:
			var t0 := TAU * k / segments
			var t1 := TAU * (k + 1) / segments
			var d0 := Vector3(cos(t0), 0, sin(t0))
			var d1 := Vector3(cos(t1), 0, sin(t1))
			var q := [d0 * a.x + Vector3(0, a.y, 0), d1 * a.x + Vector3(0, a.y, 0),
					d1 * b.x + Vector3(0, b.y, 0), d0 * b.x + Vector3(0, b.y, 0)]
			var n := [d0 * slope.x + Vector3(0, slope.y, 0), d1 * slope.x + Vector3(0, slope.y, 0)]
			var uv := [Vector2(float(k) / segments, a.y), Vector2(float(k + 1) / segments, a.y),
					Vector2(float(k + 1) / segments, b.y), Vector2(float(k) / segments, b.y)]
			# Reihenfolge so, dass die Außenseite die Vorderseite ist
			for idx: int in [0, 1, 2, 0, 2, 3]:
				st.set_normal(n[0] if idx == 0 or idx == 3 else n[1])
				st.set_uv(uv[idx])
				st.add_vertex(q[idx])
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	parent.add_child(mi)
	return mi


## Unsichtbarer Kollisionskörper, z. B. als Rampe unter einer Treppe.
static func collider_box(parent: Node, size: Vector3, pos: Vector3, rot_deg: Vector3 = Vector3.ZERO) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	body.rotation_degrees = rot_deg
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)
	parent.add_child(body)
	return body


## Gerade Wand von a nach b (Draufsicht, x/z) mit Öffnungen.
## openings: Liste von Vector4(mitte_entlang_wand, breite, unterkante, oberkante)
static func wall(parent: Node, a: Vector2, b: Vector2, y0: float, height: float, thickness: float,
		mat: Material, openings: Array = [], node_name: String = "Wall") -> Node3D:
	var root := Node3D.new()
	root.name = node_name
	parent.add_child(root)
	var d := b - a
	var length := d.length()
	var dir := d / length
	root.position = Vector3(a.x, y0, a.y)
	root.rotation.y = -atan2(dir.y, dir.x)

	var sorted := openings.duplicate()
	sorted.sort_custom(func(p: Vector4, q: Vector4) -> bool: return p.x < q.x)
	var cursor := 0.0
	for o: Vector4 in sorted:
		var s := o.x - o.y * 0.5
		var e := o.x + o.y * 0.5
		if s > cursor + 0.001:
			_wall_piece(root, cursor, s, 0.0, height, thickness, mat)
		if o.z > 0.001:
			_wall_piece(root, s, e, 0.0, o.z, thickness, mat)
		if o.w < height - 0.001:
			_wall_piece(root, s, e, o.w, height, thickness, mat)
		cursor = e
	if cursor < length - 0.001:
		_wall_piece(root, cursor, length, 0.0, height, thickness, mat)
	return root


## Stück einer Rundholzwand: liegende Stämme von a nach b (Draufsicht),
## an Öffnungen unterbrochen, an den Enden überstehend (Eckköpfe).
## openings wie bei wall(); first_row_y = Mitte der untersten Stammlage.
static func log_wall(parent: Node, a: Vector2, b: Vector2, first_row_y: float, top_y: float,
		radius: float, overhang: float, mat: Material, openings: Array = []) -> Node3D:
	var root := Node3D.new()
	root.name = "Logs"
	parent.add_child(root)
	var d := b - a
	var length := d.length()
	var dir := d / length
	root.position = Vector3(a.x, 0, a.y)
	root.rotation.y = -atan2(dir.y, dir.x)
	var step := radius * 1.85
	var y := first_row_y
	var row := 0
	while y <= top_y:
		# Freie Abschnitte dieser Lage bestimmen
		var cuts: Array[Vector2] = []
		for o: Vector4 in openings:
			if y + radius * 0.6 > o.z and y - radius * 0.6 < o.w:
				cuts.append(Vector2(o.x - o.y * 0.5, o.x + o.y * 0.5))
		cuts.sort_custom(func(p: Vector2, q: Vector2) -> bool: return p.x < q.x)
		var start := -overhang
		var segments: Array[Vector2] = []
		for c in cuts:
			if c.x > start + 0.05:
				segments.append(Vector2(start, c.x))
			start = c.y
		if length + overhang > start + 0.05:
			segments.append(Vector2(start, length + overhang))
		var rr := radius * (0.92 + 0.08 * sin(float(row) * 2.3))
		for s in segments:
			var len := s.y - s.x
			cylinder(root, rr, len, Vector3((s.x + s.y) * 0.5, y, 0), mat, false,
					Vector3(0, 0, 90), -1.0, 12)
			# Stammenden mit Jahresringen
			for e: float in [s.x - 0.004, s.y + 0.004]:
				cylinder(root, rr * 0.97, 0.01, Vector3(e, y, 0), log_end_mat(), false, Vector3(0, 0, 90), -1.0, 12)
		y += step
		row += 1
	return root


## Dreieckiger Giebel (Prisma). Basis liegt auf y=0, Spitze bei y=height.
static func gable(parent: Node, base_width: float, height: float, thickness: float, pos: Vector3,
		rot_y_deg: float, mat: Material) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hw := base_width * 0.5
	var ht := thickness * 0.5
	var f := [Vector3(-hw, 0, ht), Vector3(hw, 0, ht), Vector3(0, height, ht)]
	var k := [Vector3(-hw, 0, -ht), Vector3(hw, 0, -ht), Vector3(0, height, -ht)]
	_tri(st, f[0], f[1], f[2])
	_tri(st, k[0], k[2], k[1])
	_quad(st, f[0], k[0], k[1], f[1])
	_quad(st, f[1], k[1], k[2], f[2])
	_quad(st, f[2], k[2], k[0], f[0])
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees.y = rot_y_deg
	parent.add_child(mi)
	return mi


# --- intern -------------------------------------------------------------

static func _wall_piece(root: Node3D, s: float, e: float, y_from: float, y_to: float,
		thickness: float, mat: Material) -> void:
	var size := Vector3(e - s, y_to - y_from, thickness)
	var pos := Vector3((s + e) * 0.5, (y_from + y_to) * 0.5, 0.0)
	if mat == null:
		collider_box(root, size, pos)
	else:
		box(root, size, pos, mat, true)


static func _attach_collider(mi: MeshInstance3D, shape: Shape3D) -> void:
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)
	mi.add_child(body)


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	# Godot nutzt im Uhrzeigersinn orientierte Vorderseiten.
	st.add_vertex(a)
	st.add_vertex(c)
	st.add_vertex(b)


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	_tri(st, a, b, c)
	_tri(st, a, c, d)
