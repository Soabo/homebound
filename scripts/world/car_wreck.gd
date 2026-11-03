class_name CarWreck
extends Node3D
## Verrosteter alter Pickup an der Zufahrtsstraße – Fundgrube für Schrott,
## Benzin, Batterie und Elektronik (GDD 3.2 / 6.2).

const SPOT := Vector3(4.6, 0.0, 33.0)


func _ready() -> void:
	name = "CarWreck"
	position = Vector3(SPOT.x, Terrain.height_at(SPOT.x, SPOT.z) - 0.12, SPOT.z)
	rotation_degrees = Vector3(-3.0, 22.0, 4.0)
	var rust := BuildKit.tex_mat("metal", 0.6, Color(1.35, 0.72, 0.45), 0.8)
	var paint := BuildKit.tex_mat("metal", 0.6, Color(0.9, 1.1, 1.15), 0.7)
	var dark := BuildKit.color_mat(Color(0.05, 0.05, 0.05), 0.2)
	var tire := BuildKit.color_mat(Color(0.08, 0.08, 0.08), 0.9)
	# Fahrgestell, Kabine, Motorhaube, Ladefläche (Fahrzeug zeigt nach +x)
	BuildKit.box(self, Vector3(4.8, 0.35, 1.8), Vector3(0, 0.55, 0), rust, true)
	BuildKit.box(self, Vector3(1.5, 0.6, 1.75), Vector3(1.55, 0.98, 0), paint, true)
	BuildKit.box(self, Vector3(1.25, 0.95, 1.75), Vector3(0.25, 1.2, 0), paint, true)
	BuildKit.box(self, Vector3(1.0, 0.06, 1.6), Vector3(0.3, 1.7, 0), rust, false)
	BuildKit.box(self, Vector3(0.03, 0.5, 1.5), Vector3(0.88, 1.38, 0), dark, false, Vector3(0, 0, -20))
	for z: float in [-0.88, 0.88]:
		BuildKit.box(self, Vector3(0.9, 0.42, 0.02), Vector3(0.25, 1.4, z), dark, false)
		BuildKit.box(self, Vector3(2.0, 0.5, 0.06), Vector3(-1.4, 0.95, z), rust, true)
	BuildKit.box(self, Vector3(0.06, 0.5, 1.8), Vector3(-2.4, 0.95, 0), rust, false, Vector3(0, 0, -50))
	BuildKit.box(self, Vector3(0.1, 0.18, 1.85), Vector3(2.35, 0.75, 0), BuildKit.tex_mat("metal", 0.3, Color(1.3, 1.3, 1.3), 0.4), false)
	for z: float in [-0.6, 0.6]:
		BuildKit.cylinder(self, 0.09, 0.03, Vector3(2.38, 1.0, z), BuildKit.color_mat(Color(0.6, 0.6, 0.55), 0.3), false, Vector3(0, 0, 90), -1.0, 10)
	# Räder – eines fehlt, die Achse liegt auf
	for p: Vector3 in [Vector3(1.5, 0.38, 0.92), Vector3(1.5, 0.38, -0.92), Vector3(-1.5, 0.38, 0.92)]:
		BuildKit.cylinder(self, 0.38, 0.26, p, tire, false, Vector3(90, 0, 0), -1.0, 12)
		BuildKit.cylinder(self, 0.18, 0.28, p, rust, false, Vector3(90, 0, 0), -1.0, 8)
	# Offene Fahrertür
	BuildKit.box(self, Vector3(0.9, 0.85, 0.05), Vector3(0.55, 1.15, 1.25), paint, false, Vector3(0, -55, 0))
	# Laub und Moos auf dem Wrack
	BuildKit.box(self, Vector3(1.6, 0.04, 1.5), Vector3(-1.4, 0.75, 0), BuildKit.tex_mat("moss", 0.5), false)
	BuildKit.box(self, Vector3(0.8, 0.03, 0.9), Vector3(0.3, 1.74, 0.2), BuildKit.tex_mat("moss", 0.5), false)

	_node("Scrap", "scrap", 1, 8, 0, "", "Schrott abmontieren", 2.0, "hammer", Vector3(-1.4, 0.7, 0), Vector3(1.8, 0.6, 1.6))
	_node("Battery", "battery", 1, 1, 0, "", "Batterie ausbauen", 2.4, "hammer", Vector3(1.6, 1.0, 0), Vector3(1.2, 0.5, 1.6))
	_node("Fuel", "fuel_can", 1, 1, 0, "", "Benzin abzapfen", 2.5, "step_grass", Vector3(-0.9, 0.6, -1.0), Vector3(0.6, 0.6, 0.4))
	_node("Radio", "electronics", 1, 2, 0, "", "Autoradio ausbauen", 1.8, "hammer", Vector3(0.5, 1.1, 0.6), Vector3(0.6, 0.5, 0.5))
	_node("Glovebox", "food", 1, 2, 0, "", "Handschuhfach durchsuchen", 1.0, "switch", Vector3(0.6, 1.0, -0.5), Vector3(0.5, 0.5, 0.5))


func _node(n: String, item: String, per: int, amount: int, regrow: int, tool: String, label: String,
		t: float, snd: String, at: Vector3, col: Vector3) -> void:
	var r := ResourceNode.new()
	r.name = n
	r.item_id = item
	r.per_action = per
	r.amount = amount
	r.max_amount = amount
	r.regrow_per_day = regrow
	r.tool = tool
	r.action_label = label
	r.action_time = t
	r.sound = snd
	r.anchor = at
	r.collider_size = col
	add_child(r)
