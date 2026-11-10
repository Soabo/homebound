class_name SupplyProps
extends Node3D
## Fundstücke für die Selbstversorgung und die drei Überwachungskameras zum Selbst-Einbauen:
##  Kamera 1 auf der Werkbank, Kamera 2 auf dem Esstisch, Kamera 3 oben auf dem Kleiderschrank,
##  leere Flaschen auf der Küchenarbeitsplatte, Samen und Motoröl im Schuppenregal, Gießkanne bei den Hochbeeten.
## Alle Positionen in Weltkoordinaten (Hütte im Ursprung).

var _y := Cabin.FLOOR_Y


func _ready() -> void:
	name = "SupplyProps"
	_camera_box("Camera1Box", "camera_1", 1, Vector3(5.55, _y + 0.92, 0.05), 90.0)
	_camera_box("Camera2Box", "camera_2", 2, Vector3(-0.25, _y + 0.76, 2.05), 20.0)
	_camera_box("Camera3Box", "camera_3", 3, Vector3(-1.6, _y + 2.05, -3.8), -15.0)
	_bottles(Vector3(-0.75, _y + 0.92, -0.925 + 0.32))
	var so := Shed.ORIGIN
	_seed_packet("SeedsRadish", "seeds_radish", so + Vector3(1.62, 0.98, -1.05), Color(0.85, 0.2, 0.3))
	_seed_packet("SeedsCarrot", "seeds_carrot", so + Vector3(1.62, 0.98, -0.75), Color(0.95, 0.55, 0.1))
	_potato_sack("SeedPotatoes", so + Vector3(1.0, 0.03, 1.15))
	_oil_can("MotorOil", so + Vector3(1.62, 0.43, 0.35))
	_watering_can("WateringCan", Vector3(-12.25, 0.0, 7.75))


func _pickup(n: String, item: String, amount: int, per_take: int, collider: Vector3, at: Vector3) -> ItemPickup:
	var p := ItemPickup.new()
	p.name = n
	p.item_id = item
	p.amount = amount
	p.per_take = per_take
	p.collider_size = collider
	p.collider_offset = at + Vector3(0, collider.y * 0.5, 0)
	add_child(p)
	return p


## Überwachungskamera im Karton mit großer Nummer auf dem Deckel.
func _camera_box(n: String, item: String, number: int, at: Vector3, yaw: float) -> void:
	var p := _pickup(n, item, 1, 1, Vector3(0.36, 0.22, 0.3), at)
	var v := Node3D.new()
	p.add_child(v)
	v.position = at
	v.rotation_degrees.y = yaw
	var card := BuildKit.tex_mat("fabric", 0.3, Color(1.45, 1.2, 0.85))
	var body := BuildKit.tex_mat("metal", 0.2, Color(1.6, 1.6, 1.55), 0.5)
	var dark := BuildKit.color_mat(Color(0.08, 0.08, 0.09), 0.4, 0.3)
	# offener Karton, Kamera liegt darin
	BuildKit.box(v, Vector3(0.3, 0.012, 0.24), Vector3(0, 0.006, 0), card, false)
	for s: float in [-1.0, 1.0]:
		BuildKit.box(v, Vector3(0.3, 0.1, 0.01), Vector3(0, 0.05, s * 0.12), card, false)
		BuildKit.box(v, Vector3(0.01, 0.1, 0.24), Vector3(s * 0.15, 0.05, 0), card, false)
	var cam := Node3D.new()
	v.add_child(cam)
	cam.position = Vector3(0, 0.07, 0)
	cam.rotation_degrees = Vector3(0, 0, 8)
	BuildKit.box(cam, Vector3(0.22, 0.09, 0.1), Vector3.ZERO, body, false)
	BuildKit.box(cam, Vector3(0.26, 0.012, 0.13), Vector3(0, 0.05, 0), body, false)
	BuildKit.cylinder(cam, 0.035, 0.02, Vector3(-0.12, 0, 0), dark, false, Vector3(0, 0, 90), -1.0, 10)
	# Nummer auf einem Klebeschild
	var lab := Label3D.new()
	lab.text = str(number)
	lab.font_size = 96
	lab.pixel_size = 0.0011
	lab.modulate = Color(0.1, 0.1, 0.1)
	lab.outline_size = 0
	lab.position = Vector3(0.02, 0.0, 0.051)
	cam.add_child(lab)
	BuildKit.box(cam, Vector3(0.07, 0.07, 0.002), Vector3(0.02, 0, 0.0505), BuildKit.color_mat(Color(0.95, 0.85, 0.3)), false)
	p.visuals.append(v)


func _bottles(at: Vector3) -> void:
	var p := _pickup("EmptyBottles", "bottle_empty", 3, 1, Vector3(0.45, 0.3, 0.2), at)
	var glass := BuildKit.color_mat(Color(0.55, 0.7, 0.75), 0.1)
	for i in 3:
		var b := Node3D.new()
		p.add_child(b)
		var bp := at + Vector3(-0.14 + i * 0.14, 0, 0)
		var bm := BuildKit.lathe(b, PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.95, 0.0), Vector2(1.0, 0.05), Vector2(1.0, 0.62),
				Vector2(0.45, 0.82), Vector2(0.35, 0.9), Vector2(0.0, 0.9)]), bp, glass, 10)
		bm.scale = Vector3(0.045, 0.26, 0.045)
		p.visuals.append(b)


func _seed_packet(n: String, item: String, at: Vector3, col: Color) -> void:
	var p := _pickup(n, item, 6, 6, Vector3(0.2, 0.18, 0.2), at)
	var v := Node3D.new()
	p.add_child(v)
	var paper := BuildKit.color_mat(Color(0.92, 0.88, 0.75), 0.9)
	for k in 3:
		var pk := BuildKit.box(v, Vector3(0.09, 0.13, 0.012), at + Vector3(0, 0.065, -0.04 + k * 0.035), paper, false, Vector3(-8, 0, 0))
		BuildKit.box(pk, Vector3(0.07, 0.06, 0.002), Vector3(0, 0.0, 0.007), BuildKit.color_mat(col, 0.8), false)
	p.visuals.append(v)


func _potato_sack(n: String, at: Vector3) -> void:
	var p := _pickup(n, "seed_potato", 6, 6, Vector3(0.45, 0.45, 0.45), at)
	var v := Node3D.new()
	p.add_child(v)
	BuildKit.sphere(v, 0.2, at + Vector3(0, 0.18, 0), BuildKit.tex_mat("fabric", 0.4, Color(1.2, 1.05, 0.75)), Vector3(1.0, 0.9, 0.9), 10)
	for k in 4:
		BuildKit.sphere(v, 0.045, at + Vector3(-0.08 + k * 0.05, 0.36, 0.02 * k), BuildKit.color_mat(Color(0.6, 0.45, 0.28), 0.9), Vector3(1.2, 0.9, 1.0), 6)
	p.visuals.append(v)


func _oil_can(n: String, at: Vector3) -> void:
	var p := _pickup(n, "motor_oil", 1, 1, Vector3(0.22, 0.3, 0.16), at)
	var v := Node3D.new()
	p.add_child(v)
	BuildKit.box(v, Vector3(0.16, 0.22, 0.08), at + Vector3(0, 0.11, 0), BuildKit.color_mat(Color(0.75, 0.6, 0.1), 0.5, 0.2), false)
	BuildKit.cylinder(v, 0.02, 0.04, at + Vector3(0.05, 0.24, 0), BuildKit.color_mat(Color(0.1, 0.1, 0.1)), false, Vector3.ZERO, -1.0, 8)
	BuildKit.box(v, Vector3(0.1, 0.08, 0.002), at + Vector3(0, 0.11, 0.041), BuildKit.color_mat(Color(0.15, 0.15, 0.15)), false)
	p.visuals.append(v)


func _watering_can(n: String, at: Vector3) -> void:
	var g := Terrain.height_at(at.x, at.z)
	var pos := Vector3(at.x, g, at.z)
	var p := _pickup(n, "watering_can", 1, 1, Vector3(0.5, 0.4, 0.3), pos)
	var v := Node3D.new()
	p.add_child(v)
	v.position = pos
	v.rotation_degrees.y = 30.0
	var zinc := BuildKit.tex_mat("metal", 0.25, Color(1.2, 1.25, 1.25), 0.6)
	BuildKit.cylinder(v, 0.12, 0.25, Vector3(0, 0.125, 0), zinc, false, Vector3.ZERO, 0.11, 12)
	BuildKit.cylinder(v, 0.015, 0.36, Vector3(0.2, 0.2, 0), zinc, false, Vector3(0, 0, -55), 0.012, 6)
	BuildKit.cylinder(v, 0.035, 0.04, Vector3(0.34, 0.31, 0), zinc, false, Vector3(0, 0, -55), 0.02, 8)
	BuildKit.box(v, Vector3(0.02, 0.02, 0.2), Vector3(-0.02, 0.33, 0), zinc, false)
	p.visuals.append(v)
