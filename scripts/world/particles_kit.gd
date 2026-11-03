class_name ParticlesKit
extends RefCounted
## Partikel-Effekte (CPU-Partikel, laufen auch im Browser).


## Feiner Staub, der langsam durch die Luft schwebt.
## Leuchtet nur dort auf, wo Licht hinfällt – z. B. im Taschenlampenkegel.
static func dust(extents: Vector3, amount: int = 220) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = "Dust"
	p.amount = amount
	p.lifetime = 14.0
	p.preprocess = 14.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = extents
	p.direction = Vector3(0, 1, 0)
	p.spread = 180.0
	p.initial_velocity_min = 0.005
	p.initial_velocity_max = 0.04
	p.gravity = Vector3(0.0, -0.004, 0.0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.2
	var q := QuadMesh.new()
	q.size = Vector2(0.012, 0.012)
	var m := StandardMaterial3D.new()
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.albedo_color = Color(0.95, 0.92, 0.85)
	m.roughness = 1.0
	q.material = m
	p.mesh = q
	return p


## Rauch aus dem Schornstein.
static func smoke() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = "Smoke"
	p.amount = 26
	p.lifetime = 9.0
	p.preprocess = 9.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.2
	p.direction = Vector3(0, 1, 0)
	p.spread = 12.0
	p.initial_velocity_min = 0.5
	p.initial_velocity_max = 0.8
	p.gravity = Vector3(0.18, 0.06, 0.08)
	p.damping_min = 0.05
	p.damping_max = 0.1
	p.angle_min = 0.0
	p.angle_max = 360.0
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.1
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.3))
	curve.add_point(Vector2(1.0, 2.4))
	p.scale_amount_curve = curve
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.55, 0.55, 0.55, 0.0))
	ramp.add_point(0.12, Color(0.6, 0.6, 0.6, 0.45))
	ramp.set_color(ramp.get_point_count() - 1, Color(0.7, 0.7, 0.72, 0.0))
	p.color_ramp = ramp
	var q := QuadMesh.new()
	q.size = Vector2(0.9, 0.9)
	var m := StandardMaterial3D.new()
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = _soft_dot()
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.roughness = 1.0
	m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	q.material = m
	p.mesh = q
	return p


static func _soft_dot() -> ImageTexture:
	var s := 16
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	for y in s:
		for x in s:
			var d := Vector2(x - s / 2.0 + 0.5, y - s / 2.0 + 0.5).length() / (s / 2.0)
			var a := clampf(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a * a))
	return ImageTexture.create_from_image(img)
