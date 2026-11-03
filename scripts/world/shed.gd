class_name Shed
extends Node3D
## Kleiner Holzschuppen im Garten (GDD 3.2). 4 x 3 m, Tür nach Westen zur Hütte.

const ORIGIN := Vector3(14.0, 0.0, 6.5)
const HALF := Vector2(2.0, 1.5)
const WALL_H := 2.2


static func is_inside(p: Vector3) -> bool:
	return absf(p.x - ORIGIN.x) < HALF.x and absf(p.z - ORIGIN.z) < HALF.y and p.y < WALL_H + 0.5


func _ready() -> void:
	name = "Shed"
	position = ORIGIN
	var boards := BuildKit.tex_mat("planks_v", 0.9, Color(0.85, 0.85, 0.82))
	var floor_mat := BuildKit.tex_mat("floor", 1.0, Color(0.8, 0.78, 0.75))
	var t := 0.1
	BuildKit.box_mm(self, Vector3(-HALF.x, -0.1, -HALF.y), Vector3(HALF.x, 0.03, HALF.y), floor_mat, true, "Floor")
	var hz := HALF.y - t * 0.5
	BuildKit.wall(self, Vector2(-HALF.x, -hz), Vector2(-HALF.x, hz), 0.03, WALL_H, t, boards,
			[Vector4(hz, 0.95, 0.0, 1.95)], "WallWest")
	BuildKit.wall(self, Vector2(HALF.x, -hz), Vector2(HALF.x, hz), 0.03, WALL_H, t, boards, [], "WallEast")
	BuildKit.wall(self, Vector2(-HALF.x - t * 0.5, -HALF.y), Vector2(HALF.x + t * 0.5, -HALF.y), 0.03, WALL_H, t, boards, [], "WallNorth")
	BuildKit.wall(self, Vector2(-HALF.x - t * 0.5, HALF.y), Vector2(HALF.x + t * 0.5, HALF.y), 0.03, WALL_H, t, boards,
			[Vector4(HALF.x + t * 0.5 + 1.0, 0.5, 1.3, 1.7)], "WallSouth")
	# Pultdach
	BuildKit.box(self, Vector3(HALF.x * 2.0 + 0.6, 0.1, HALF.y * 2.0 + 0.6), Vector3(0, WALL_H + 0.18, 0),
			BuildKit.tex_mat("metal", 0.6, Color(0.9, 0.9, 0.9), 0.6), false, Vector3(0, 0, -6), "Roof")

	var door := Door.new()
	door.name = "ShedDoor"
	door.door_name = "Schuppentür"
	door.width = 0.95
	door.height = 1.93
	door.thickness = 0.05
	door.open_sign = 1.0
	door.color = Color(0.32, 0.27, 0.2)
	door.position = Vector3(-HALF.x, 0.03, -hz + hz - 0.475)
	door.rotation_degrees.y = -90.0
	add_child(door)

	# Innen: Regal, Kanister, Werkzeug
	var wood := BuildKit.tex_mat("planks_h", 0.7)
	for i in 3:
		BuildKit.box_mm(self, Vector3(1.4, 0.4 + i * 0.55, -1.4), Vector3(1.9, 0.43 + i * 0.55, 1.4), wood, true)
	BuildKit.box_mm(self, Vector3(1.85, 0.03, -1.4), Vector3(1.9, 1.6, 1.4), wood, false)
	Cabin.fuel_can(self, Vector3(1.65, 0.43, -1.0), 90.0, "FuelCan")
	BuildKit.box_mm(self, Vector3(1.5, 0.98, 0.2), Vector3(1.85, 1.15, 0.8), BuildKit.color_mat(Color(0.15, 0.3, 0.55), 0.5, 0.4), false, "Toolbox")
	# Brennholzstapel an der Südseite (außen)
	var log_mat := BuildKit.tex_mat("logs", 0.5)
	for row in 5:
		for i in 14:
			BuildKit.cylinder(self, 0.1, 0.45, Vector3(-1.7 + i * 0.23 + (row % 2) * 0.1, 0.1 + row * 0.18, HALF.y + 0.35),
					log_mat, false, Vector3(90, 0, 0), -1.0, 8)
	var pile := ResourceNode.new()
	pile.name = "Woodpile"
	pile.item_id = "wood"
	pile.per_action = 2
	pile.amount = 10
	pile.max_amount = 10
	pile.action_label = "Brennholz nehmen"
	pile.action_time = 0.6
	pile.sound = "step_wood"
	pile.anchor = Vector3(-0.05, 0.0, HALF.y + 0.35)
	pile.collider_size = Vector3(3.4, 0.95, 0.5)
	add_child(pile)
