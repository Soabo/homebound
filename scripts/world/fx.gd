class_name Fx
extends RefCounted
## Kleine Partikel-Effekte (einmalige Schübe): Holzspäne, Steinsplitter, Funken, Erde, Glas, Staub.
## Fx.burst(parent, Position, Art, Richtung) – räumt sich selbst wieder auf.

const KINDS := {
	# Farbe(n), Anzahl, Größe, Tempo, Lebenszeit, Schwerkraft, leuchtend
	"wood": {"colors": [Color(0.72, 0.55, 0.34), Color(0.88, 0.75, 0.52), Color(0.45, 0.32, 0.2)], "amount": 16, "size": Vector3(0.035, 0.008, 0.02), "speed": Vector2(1.5, 3.5), "life": 0.9, "gravity": 9.0},
	"stone": {"colors": [Color(0.55, 0.55, 0.53), Color(0.7, 0.69, 0.66), Color(0.4, 0.4, 0.4)], "amount": 12, "size": Vector3(0.025, 0.02, 0.025), "speed": Vector2(1.2, 3.0), "life": 0.8, "gravity": 12.0},
	"metal": {"colors": [Color(1.0, 0.75, 0.3), Color(1.0, 0.55, 0.15), Color(1.0, 0.9, 0.6)], "amount": 18, "size": Vector3(0.006, 0.006, 0.05), "speed": Vector2(3.0, 6.0), "life": 0.35, "gravity": 6.0, "glow": true},
	"dirt": {"colors": [Color(0.32, 0.24, 0.16), Color(0.42, 0.34, 0.22), Color(0.3, 0.38, 0.2)], "amount": 12, "size": Vector3(0.03, 0.02, 0.03), "speed": Vector2(1.0, 2.5), "life": 0.7, "gravity": 12.0},
	"glass": {"colors": [Color(0.75, 0.85, 0.9), Color(0.9, 0.95, 1.0)], "amount": 22, "size": Vector3(0.03, 0.003, 0.02), "speed": Vector2(1.5, 3.5), "life": 1.0, "gravity": 10.0},
	"dust": {"colors": [Color(0.6, 0.56, 0.5, 0.6), Color(0.7, 0.66, 0.6, 0.5)], "amount": 10, "size": Vector3(0.05, 0.05, 0.05), "speed": Vector2(0.3, 0.9), "life": 1.2, "gravity": -0.3},
	"water": {"colors": [Color(0.6, 0.75, 0.85, 0.7), Color(0.8, 0.9, 1.0, 0.6)], "amount": 14, "size": Vector3(0.02, 0.02, 0.02), "speed": Vector2(1.0, 2.2), "life": 0.6, "gravity": 9.0},
}


static func burst(parent: Node, pos: Vector3, kind: String, normal: Vector3 = Vector3.UP, scale: float = 1.0) -> void:
	if parent == null or not parent.is_inside_tree() or not KINDS.has(kind):
		return
	var d: Dictionary = KINDS[kind]
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 0.92
	p.amount = maxi(2, int(float(d["amount"]) * scale))
	p.lifetime = float(d["life"])
	p.local_coords = false
	var mesh := BoxMesh.new()
	mesh.size = d["size"]
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.8
	if d.get("glow", false):
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if (d["colors"][0] as Color).a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = m
	p.mesh = mesh
	# zufällige Farbe je Teilchen aus der Palette
	var g := Gradient.new()
	var cols: Array = d["colors"]
	var offs := PackedFloat32Array()
	var cs := PackedColorArray()
	for i in cols.size():
		offs.append(float(i) / maxf(cols.size() - 1, 1))
		cs.append(cols[i])
	g.offsets = offs
	g.colors = cs
	p.color_initial_ramp = g
	# im Flug ausblenden
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 1))
	fade.set_color(1, Color(1, 1, 1, 0.0))
	p.color_ramp = fade
	p.direction = normal.normalized() if normal.length() > 0.01 else Vector3.UP
	p.spread = 55.0
	p.initial_velocity_min = (d["speed"] as Vector2).x
	p.initial_velocity_max = (d["speed"] as Vector2).y
	p.gravity = Vector3(0, -float(d["gravity"]), 0)
	p.angular_velocity_min = -360.0
	p.angular_velocity_max = 360.0
	p.particle_flag_rotate_y = true
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	p.damping_min = 0.5
	p.damping_max = 1.5
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(p)
	p.global_position = pos
	p.emitting = true
	parent.get_tree().create_timer(p.lifetime + 0.3).timeout.connect(p.queue_free)


## Welche Partikel passen zu einem gesammelten Material?
static func kind_for_item(item_id: String) -> String:
	match item_id:
		"wood", "planks", "branches": return "wood"
		"stone", "rock": return "stone"
		"scrap", "electronics", "battery", "nails": return "metal"
		"water": return "water"
	return "dust"
