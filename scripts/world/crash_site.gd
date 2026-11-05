class_name CrashSite
extends Node3D
## Absturzstelle im Wald nordwestlich der Hütte (GDD 12.3/12.5, Phase 7).
## Ein Krater mit verbrannter Erde, ein zerborstenes fremdes Flugobjekt, umgeknickte,
## verkohlte Bäume, Leuchtpilze – und die ersten Forschungsobjekte: Metallfragmente,
## eine Energiezelle, eine Symbolplatte, das fremde Analysegerät und die Notiz eines Försters.
## Eine Rauchsäule weist tagsüber den Weg.

const SITE := Vector3(-42.0, 0.0, -30.0)

var _rng := RandomNumberGenerator.new()
var _glow_light: OmniLight3D
var _t: float = 0.0
var _hum_timer: float = 3.0
static var _glow: StandardMaterial3D
static var _hull: StandardMaterial3D


static func is_near(x: float, z: float, radius: float) -> bool:
	return Vector2(x - SITE.x, z - SITE.z).length() < radius


static func ground(x: float, z: float) -> float:
	return Terrain.height_at(SITE.x + x, SITE.z + z)


static func glow_material() -> StandardMaterial3D:
	if _glow == null:
		_glow = BuildKit.emissive_mat(Color(0.35, 0.95, 1.0), 2.5)
	return _glow


static func hull_material() -> StandardMaterial3D:
	if _hull == null:
		_hull = StandardMaterial3D.new()
		_hull.albedo_texture = TextureFactory.get_texture("metal")
		_hull.albedo_color = Color(0.45, 0.48, 0.55)
		_hull.metallic = 0.85
		_hull.roughness = 0.28
		_hull.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
		_hull.uv1_triplanar = true
		_hull.uv1_scale = Vector3(3, 3, 3)
	return _hull


## Das fremde Analysegerät: flacher dunkler Körper mit leuchtendem Zeichenfeld und Ring.
static func build_analyzer_model(parent: Node3D, pos: Vector3, scale: float = 1.0) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	root.scale = Vector3.ONE * scale
	parent.add_child(root)
	BuildKit.sphere(root, 0.18, Vector3(0, 0.09, 0), hull_material(), Vector3(1.0, 0.45, 0.72), 14)
	var panel := StandardMaterial3D.new()
	panel.albedo_texture = TextureFactory.get_texture("glyphs")
	panel.emission_enabled = true
	panel.emission_texture = TextureFactory.get_texture("glyphs")
	panel.emission = Color(0.6, 1.0, 1.0)
	panel.emission_energy_multiplier = 1.6
	panel.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	BuildKit.box(root, Vector3(0.16, 0.004, 0.1), Vector3(0, 0.168, 0.0), panel, false, Vector3(0, 0, 0))
	BuildKit.lathe(root, PackedVector2Array([Vector2(0.19, 0.08), Vector2(0.2, 0.09), Vector2(0.19, 0.1)]), Vector3.ZERO, glow_material(), 20)
	for k in 3:
		var a := TAU * k / 3.0
		BuildKit.box(root, Vector3(0.025, 0.08, 0.025), Vector3(cos(a) * 0.13, 0.03, sin(a) * 0.09), hull_material(), false, Vector3(sin(a) * 25.0, 0, -cos(a) * 25.0))
	return root


func _ready() -> void:
	name = "CrashSite"
	_rng.seed = 1947
	position = Vector3(SITE.x, 0.0, SITE.z)
	_build_scorch()
	_build_wreck()
	_build_trees()
	_build_finds()
	_build_smoke()


func _p(x: float, z: float, lift: float = 0.0) -> Vector3:
	return Vector3(x, ground(x, z) + lift, z)


## Verbrannte Erde: eine dunkle Fläche, die dem Gelände folgt und zum Rand hin ausläuft.
func _build_scorch() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var r := 11.0
	var n := 22
	var step := r * 2.0 / n
	for iz in n + 1:
		for ix in n + 1:
			var x := -r + ix * step
			var z := -r + iz * step
			var d := Vector2(x, z).length()
			var noise := sin(x * 1.7) * cos(z * 1.3) * 0.8
			var a := 1.0 - smoothstep(5.5, 10.5, d + noise)
			st.set_color(Color(0.05, 0.045, 0.04, a * 0.92))
			st.set_uv(Vector2(x, z) * 0.3)
			st.set_normal(Vector3.UP)
			st.add_vertex(Vector3(x, ground(x, z) + 0.04, z))
	var row := n + 1
	for iz in n:
		for ix in n:
			var i := iz * row + ix
			for k: int in [i, i + 1, i + row, i + 1, i + row + 1, i + row]:
				st.add_index(k)
	var mi := MeshInstance3D.new()
	mi.name = "Scorch"
	mi.mesh = st.commit()
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = TextureFactory.get_texture("grass_ground")
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	m.roughness = 1.0
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _build_wreck() -> void:
	var hull := hull_material()
	var wreck := Node3D.new()
	wreck.name = "Wreck"
	wreck.position = _p(0.0, 0.0, 0.1)
	# schräg eingeschlagen: eine Kante steckt tief im Boden
	wreck.rotation_degrees = Vector3(-6, 28, 22)
	add_child(wreck)
	# flache Scheibe mit gewölbter Ober- und Unterseite, scharfer Rand, Kuppel
	BuildKit.lathe(wreck, PackedVector2Array([Vector2(0.0, -0.32), Vector2(1.2, -0.26), Vector2(2.3, -0.08), Vector2(2.55, 0.0),
			Vector2(2.3, 0.1), Vector2(1.4, 0.3), Vector2(0.9, 0.38), Vector2(0.0, 0.42)]), Vector3.ZERO, hull, 28)
	BuildKit.lathe(wreck, PackedVector2Array([Vector2(2.56, -0.03), Vector2(2.62, 0.0), Vector2(2.56, 0.03)]), Vector3.ZERO, glow_material(), 28)
	var dome := BuildKit.sphere(wreck, 0.75, Vector3(0, 0.42, 0), hull, Vector3(1.0, 0.5, 1.0), 16)
	dome.name = "Dome"
	# eingedrückter Riss in der Kuppel, dahinter Glühen
	var dark := BuildKit.color_mat(Color(0.02, 0.02, 0.03), 0.4)
	BuildKit.box(wreck, Vector3(0.9, 0.22, 0.08), Vector3(0.25, 0.62, 0.55), dark, false, Vector3(10, -20, 12))
	BuildKit.sphere(wreck, 0.16, Vector3(0.3, 0.6, 0.55), glow_material(), Vector3(1.4, 0.6, 0.6), 10)
	# radiale Nähte und Platten auf der Oberseite
	for k in 12:
		var ang := TAU * k / 12.0
		BuildKit.box(wreck, Vector3(1.2, 0.01, 0.02), Vector3(cos(ang) * 1.75, 0.22, sin(ang) * 1.75), glow_material() if k % 3 == 0 else dark, false,
				Vector3(0, -rad_to_deg(ang), 8.0))
	# abgerissene Randstücke
	BuildKit.box(wreck, Vector3(0.8, 0.06, 0.5), Vector3(2.0, 0.25, -1.2), hull, false, Vector3(20, 30, 35))
	BuildKit.collider_box(wreck, Vector3(5.0, 0.9, 5.0), Vector3.ZERO)
	_glow_light = OmniLight3D.new()
	_glow_light.position = Vector3(0.4, 0.9, 0.9)
	_glow_light.light_color = Color(0.4, 0.95, 1.0)
	_glow_light.light_energy = 1.6
	_glow_light.omni_range = 9.0
	wreck.add_child(_glow_light)
	# abgerissene Rumpfteile, schräg im Boden steckend
	for k in 9:
		var a := _rng.randf() * TAU
		var d := _rng.randf_range(2.5, 6.5)
		var x := cos(a) * d
		var z := sin(a) * d
		var shard := BuildKit.box(self, Vector3(_rng.randf_range(0.3, 0.9), 0.03, _rng.randf_range(0.2, 0.6)), _p(x, z, 0.08), hull, false,
				Vector3(_rng.randf_range(-40, 40), _rng.randf() * 360.0, _rng.randf_range(-35, 35)))
		if k % 3 == 0:
			BuildKit.box(shard, Vector3(0.4, 0.035, 0.012), Vector3(0, 0.01, 0), glow_material(), false)
	# Schleifspur in Flugrichtung
	for k in 6:
		BuildKit.box(self, Vector3(0.8, 0.05, 2.2), _p(-2.0 - k * 1.6, 3.0 + k * 1.1, -0.02), BuildKit.color_mat(Color(0.12, 0.09, 0.07)), false, Vector3(0, 55, 0))


func _build_trees() -> void:
	var charred := BuildKit.tex_mat("bark", 0.8, Color(0.25, 0.22, 0.2))
	var splinter := BuildKit.tex_mat("planks_v", 0.3, Color(0.55, 0.45, 0.32))
	# abgeknickte, verkohlte Stämme am Kraterrand
	for k in 6:
		var a := TAU * k / 6.0 + _rng.randf_range(-0.3, 0.3)
		var d := _rng.randf_range(7.5, 9.5)
		var x := cos(a) * d
		var z := sin(a) * d
		var h := _rng.randf_range(1.2, 3.2)
		BuildKit.cylinder(self, 0.28, h, _p(x, z, h * 0.5), charred, true, Vector3(_rng.randf_range(-6, 6), 0, _rng.randf_range(-6, 6)), 0.22, 9)
		for s in 4:
			BuildKit.box(self, Vector3(0.06, _rng.randf_range(0.25, 0.5), 0.05), _p(x + _rng.randf_range(-0.15, 0.15), z + _rng.randf_range(-0.15, 0.15), h + 0.12),
					splinter, false, Vector3(_rng.randf_range(-25, 25), 0, _rng.randf_range(-25, 25)))
		# der obere Teil liegt umgestürzt, vom Krater weg
		if k % 2 == 0:
			var len := _rng.randf_range(5.0, 8.0)
			var dir := Vector2(cos(a), sin(a))
			var mid := Vector2(x, z) + dir * (len * 0.5 + 0.5)
			BuildKit.cylinder(self, 0.22, len, _p(mid.x, mid.y, 0.25), charred, true, Vector3(0, -rad_to_deg(a), 90), 0.12, 8)


func _pickup(n: String, item: String, amount: int, at: Vector3, size: Vector3) -> ItemPickup:
	var p := ItemPickup.new()
	p.name = n
	p.item_id = item
	p.amount = amount
	p.per_take = amount
	p.collider_size = size
	p.collider_offset = at + Vector3(0, size.y * 0.5, 0)
	add_child(p)
	return p


func _build_finds() -> void:
	var hull := hull_material()
	# Metallfragmente
	for k in 2:
		var at := _p(-3.2 + k * 6.5, 2.4 - k * 4.5, 0.0)
		var p := _pickup("Fragment_%d" % k, "metal_fragment", 1, at, Vector3(0.5, 0.3, 0.5))
		var v := Node3D.new()
		p.add_child(v)
		BuildKit.box(v, Vector3(0.28, 0.025, 0.16), at + Vector3(0, 0.05, 0), hull, false, Vector3(18, k * 70.0, -12))
		BuildKit.box(v, Vector3(0.2, 0.012, 0.01), at + Vector3(0, 0.065, 0), glow_material(), false, Vector3(18, k * 70.0, -12))
		p.visuals.append(v)
	# Energiezelle in einer Halterung
	var cell_at := _p(2.6, 2.2, 0.0)
	var cell := _pickup("EnergyCell", "energy_cell", 1, cell_at, Vector3(0.4, 0.35, 0.4))
	var cv := Node3D.new()
	cell.add_child(cv)
	BuildKit.cylinder(cv, 0.07, 0.24, cell_at + Vector3(0, 0.14, 0), glow_material(), false, Vector3(0, 0, 70), -1.0, 10)
	for s: float in [-1.0, 1.0]:
		BuildKit.cylinder(cv, 0.085, 0.04, cell_at + Vector3(s * 0.12, 0.1, 0), hull, false, Vector3(0, 0, 70), -1.0, 10)
	cell.visuals.append(cv)
	# Symbolplatte
	var plate_at := _p(-1.8, -3.0, 0.0)
	var plate := _pickup("GlyphPlate", "glyph_plate", 1, plate_at, Vector3(0.6, 0.3, 0.5))
	var pv := Node3D.new()
	plate.add_child(pv)
	var glyph := StandardMaterial3D.new()
	glyph.albedo_texture = TextureFactory.get_texture("glyphs")
	glyph.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	glyph.metallic = 0.6
	glyph.roughness = 0.35
	BuildKit.box(pv, Vector3(0.45, 0.03, 0.32), plate_at + Vector3(0, 0.08, 0), glyph, false, Vector3(-25, 40, 8))
	plate.visuals.append(pv)
	# Das fremde Analysegerät
	var dev_at := _p(3.4, -1.6, 0.0)
	var dev := _pickup("AlienAnalyzer", "alien_analyzer", 1, dev_at, Vector3(0.6, 0.4, 0.6))
	var dv := Node3D.new()
	dev.add_child(dv)
	build_analyzer_model(dv, dev_at + Vector3(0, 0.02, 0))
	dev.visuals.append(dv)
	# Leuchtpilze auf zwei verkohlten Stümpfen am Rand
	for k in 2:
		var a := 1.2 + k * 2.4
		var at := _p(cos(a) * 6.8, sin(a) * 6.8, 0.0)
		var f := _pickup("GlowFungus_%d" % k, "glow_fungus", 3, at, Vector3(0.7, 0.5, 0.7))
		f.per_take = 1
		for i in 3:
			var cap := Node3D.new()
			f.add_child(cap)
			var c := at + Vector3(_rng.randf_range(-0.25, 0.25), 0.05, _rng.randf_range(-0.25, 0.25))
			BuildKit.cylinder(cap, 0.012, 0.07, c + Vector3(0, 0.035, 0), BuildKit.color_mat(Color(0.75, 0.8, 0.8)), false, Vector3.ZERO, -1.0, 5)
			BuildKit.sphere(cap, 0.045, c + Vector3(0, 0.075, 0), glow_material(), Vector3(1.0, 0.45, 1.0), 8)
			f.visuals.append(cap)
		var fl := OmniLight3D.new()
		fl.position = at + Vector3(0, 0.25, 0)
		fl.light_color = Color(0.4, 1.0, 0.95)
		fl.light_energy = 0.5
		fl.omni_range = 2.5
		f.add_child(fl)
	# Notiz des Försters, mit einem Stein beschwert
	var note_at := _p(-4.5, -1.0, 0.0)
	var note := ResearchNote.new()
	note.name = "RangerNote"
	note.note_id = "ranger_note"
	note.anchor = note_at
	add_child(note)


func _build_smoke() -> void:
	var smoke := ParticlesKit.smoke()
	smoke.amount = 48
	smoke.lifetime = 16.0
	smoke.preprocess = 16.0
	smoke.emission_sphere_radius = 0.8
	smoke.initial_velocity_min = 1.0
	smoke.initial_velocity_max = 1.6
	smoke.scale_amount_min = 1.5
	smoke.scale_amount_max = 2.4
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.25, 0.25, 0.25, 0.0))
	ramp.add_point(0.1, Color(0.3, 0.3, 0.3, 0.5))
	ramp.set_color(ramp.get_point_count() - 1, Color(0.5, 0.5, 0.52, 0.0))
	smoke.color_ramp = ramp
	smoke.position = _p(0.6, 0.6, 0.6)
	add_child(smoke)


func _process(delta: float) -> void:
	_t += delta
	if _glow_light:
		_glow_light.light_energy = 1.4 + sin(_t * 0.9) * 0.4 + (randf() * 0.6 if randf() < 0.02 else 0.0)
	# leises Summen, wenn der Spieler in der Nähe ist
	_hum_timer -= delta
	if _hum_timer <= 0.0:
		_hum_timer = randf_range(6.0, 11.0)
		var p := get_tree().get_first_node_in_group("player") as Node3D
		if p and p.global_position.distance_to(global_position) < 28.0:
			SoundBank.play_at(self, "signal", global_position + Vector3(0, 1.0, 0), -14.0, randf_range(0.55, 0.7))


## Gewebeprobe: fällt, wenn die Kreatur mit der Axt getroffen wird (einmal pro Tag).
static var _tissue_day: int = -1


static func drop_tissue(scene: Node, at: Vector3) -> void:
	if TimeManager.day == _tissue_day:
		return
	_tissue_day = TimeManager.day
	var p := ItemPickup.new()
	p.name = "TissueSample_d%d" % TimeManager.day
	p.item_id = "alien_tissue"
	p.amount = 1
	p.collider_size = Vector3(0.5, 0.25, 0.5)
	p.collider_offset = Vector3(0, 0.12, 0)
	p.position = Creature._ground(at)
	scene.add_child(p)
	var v := Node3D.new()
	p.add_child(v)
	var goo := BuildKit.color_mat(Color(0.25, 0.3, 0.27), 0.15, 0.2)
	BuildKit.sphere(v, 0.07, Vector3(0, 0.03, 0), goo, Vector3(1.4, 0.4, 1.0), 8)
	BuildKit.cylinder(v, 0.18, 0.004, Vector3(0.05, 0.004, 0.03), BuildKit.color_mat(Color(0.12, 0.16, 0.14), 0.1, 0.3), false, Vector3.ZERO, -1.0, 10)
	p.visuals.append(v)
	EventBus.notify("Etwas Graues ist am Boden zurückgeblieben …", 3.0)
