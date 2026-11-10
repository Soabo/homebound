class_name Shed
extends Node3D
## Kleiner Holzschuppen im Garten (GDD 3.2). 4 x 3 m, Tür nach Westen zur Hütte.

const ORIGIN := Vector3(14.0, 0.0, 6.5)
const HALF := Vector2(2.0, 1.5)
const WALL_H := 2.2


## Pultdach: hoch über der Tür (Westen), niedrig im Osten.
const ROOF_HIGH := 2.75
const ROOF_LOW := WALL_H + 0.02


## Oberkante der Wände unter dem schrägen Dach an Stelle x (lokal).
static func roof_y(x: float) -> float:
	return lerpf(ROOF_HIGH, ROOF_LOW, (x + HALF.x) / (HALF.x * 2.0))


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
	_build_roof(boards, t)

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

	# Stromerzeuger an der Nordwand (Bedienfeld zum Raum). Fällt er aus, muss man nachts hier heraus.
	var gen := Generator.new()
	gen.name = "Generator"
	gen.anchor = Vector3(4.7, 0.03, -3.825)
	add_child(gen)
	Cabin.generator_model(gen, 0.03)
	gen.position = Vector3(-0.92, 0, -1.03) - Vector3(4.7, 0, -3.83)
	# Wartungsklappe vorne rechts am Generator; Holzvergaser (wenn gebaut) außen an der Nordwand
	var service := GeneratorService.new()
	service.name = "GeneratorService"
	service.position = Vector3(-0.42, 0.62, -0.6)
	service.gasifier_spot = ORIGIN + Vector3(-0.9, 0.0, -HALF.y - 0.45)
	add_child(service)
	# Kabel vom Generator durch die Wand Richtung Hütte, Sicherungskasten neben der Tür
	var cable := BuildKit.color_mat(Color(0.08, 0.08, 0.08), 0.6)
	BuildKit.box_mm(self, Vector3(-1.95, 0.05, -1.25), Vector3(-1.6, 0.08, -1.21), cable, false)
	BuildKit.box_mm(self, Vector3(-1.98, 0.05, -1.25), Vector3(-1.95, 1.3, -1.21), cable, false)
	BuildKit.box_mm(self, Vector3(-1.94, 1.2, -1.42), Vector3(-1.82, 1.75, -0.9), BuildKit.tex_mat("metal", 0.3, Color(1.6, 1.6, 1.5)), false, "FuseBox")
	Cabin.fuel_can(self, Vector3(-1.7, 0.03, -0.75), 90.0, "FuelCan_0")
	Cabin.fuel_can(self, Vector3(1.05, 0.03, -1.2), 0.0, "FuelCan_1")
	# Spind an der Nordwand – Versteck mit Lüftungslamellen auf Augenhöhe
	var locker := HideSpot.new()
	locker.name = "Locker"
	locker.style = "locker"
	locker.label = "Spind"
	locker.size = Vector3(0.62, 1.95, 0.55)
	locker.hinge_right = true
	locker.position = Vector3(0.36, 0.03, -1.17)
	add_child(locker)
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


func _build_roof(boards: Material, t: float) -> void:
	var beam := BuildKit.tex_mat("planks_h", 0.6, Color(0.75, 0.68, 0.6))
	# Giebelstücke: Wände von der Wandoberkante schräg bis unters Dach (keine Lücken)
	for zs: float in [-1.0, 1.0]:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var x0 := -HALF.x - t * 0.5
		var x1 := HALF.x + t * 0.5
		var zf := zs * HALF.y
		for side: float in [-1.0, 1.0]:
			var z := zf + side * t * 0.5
			var q := [Vector3(x0, WALL_H, z), Vector3(x1, WALL_H, z), Vector3(x1, roof_y(x1), z), Vector3(x0, roof_y(x0), z)]
			var idx := [0, 1, 2, 0, 2, 3] if side > 0 else [0, 2, 1, 0, 3, 2]
			for k: int in idx:
				st.set_normal(Vector3(0, 0, side))
				st.add_vertex(q[k])
		st.generate_normals()
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		mi.material_override = boards
		add_child(mi)
	# Westwand über der Tür bis zum hohen Dachrand
	BuildKit.box_mm(self, Vector3(-HALF.x - t * 0.5, WALL_H, -HALF.y), Vector3(-HALF.x + t * 0.5, ROOF_HIGH, HALF.y), boards, false)
	# Sparren in Dachneigung, Pfette oben und unten, Stirnbretter
	var run := HALF.x * 2.0 + 0.7
	var angle := rad_to_deg(atan2(ROOF_HIGH - ROOF_LOW, HALF.x * 2.0))
	var mid_y := (ROOF_HIGH + ROOF_LOW) * 0.5
	for z: float in [-HALF.y - 0.05, -0.75, 0.75, HALF.y + 0.05]:
		BuildKit.box(self, Vector3(run, 0.12, 0.07), Vector3(0, mid_y + 0.04, z), beam, false, Vector3(0, 0, -angle))
	for x: float in [-HALF.x, HALF.x]:
		BuildKit.box(self, Vector3(0.1, 0.1, HALF.y * 2.0 + 0.5), Vector3(x, roof_y(x) + 0.02, 0), beam, false)
	# Wellblech in drei Bahnen, leicht überlappend, eine Ecke hochgebogen
	# beidseitig sichtbar (von innen sieht man die Unterseite)
	var tin := BuildKit.tex_mat("metal", 0.5, Color(1.25, 1.15, 1.05), 0.55).duplicate() as StandardMaterial3D
	tin.cull_mode = BaseMaterial3D.CULL_DISABLED
	var rusty := BuildKit.tex_mat("metal", 0.5, Color(1.45, 0.85, 0.55), 0.7).duplicate() as StandardMaterial3D
	rusty.cull_mode = BaseMaterial3D.CULL_DISABLED
	var width := (HALF.y * 2.0 + 0.6) / 3.0
	for k in 3:
		var sheet := MeshInstance3D.new()
		sheet.mesh = _corrugated(run + 0.1, width + 0.08)
		sheet.material_override = rusty if k == 1 else tin
		sheet.position = Vector3(0, mid_y + 0.13 + k * 0.004, -HALF.y - 0.3 + width * (k + 0.5))
		sheet.rotation_degrees = Vector3(0.8 if k == 2 else 0.0, 0, -angle)
		add_child(sheet)
	# Stirnbretter vorne und hinten
	for zs: float in [-1.0, 1.0]:
		BuildKit.box(self, Vector3(run + 0.05, 0.14, 0.03), Vector3(0, mid_y + 0.06, zs * (HALF.y + 0.32)), beam, false, Vector3(0, 0, -angle))
	# Regenrinne an der niedrigen Ostseite, Fallrohr in eine Blechwanne
	var zinc := BuildKit.tex_mat("metal", 0.3, Color(1.3, 1.3, 1.3), 0.45)
	var gx := HALF.x + 0.42
	var gy := ROOF_LOW + 0.02
	BuildKit.box(self, Vector3(0.12, 0.02, HALF.y * 2.0 + 0.6), Vector3(gx, gy - 0.06, 0), zinc, false)
	BuildKit.box(self, Vector3(0.02, 0.08, HALF.y * 2.0 + 0.6), Vector3(gx + 0.06, gy - 0.03, 0), zinc, false)
	BuildKit.box(self, Vector3(0.02, 0.06, HALF.y * 2.0 + 0.6), Vector3(gx - 0.06, gy - 0.04, 0), zinc, false)
	var pipe_z := -HALF.y - 0.2
	BuildKit.cylinder(self, 0.04, gy - 0.3, Vector3(gx, (gy - 0.06 + 0.24) * 0.5, pipe_z), zinc, false, Vector3.ZERO, -1.0, 8)
	BuildKit.cylinder(self, 0.04, 0.2, Vector3(gx + 0.06, 0.22, pipe_z), zinc, false, Vector3(0, 0, -50), -1.0, 8)
	BuildKit.lathe(self, PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.22, 0.0), Vector2(0.25, 0.2), Vector2(0.26, 0.21)]),
			Vector3(gx + 0.25, 0.0, pipe_z), zinc, 12)
	BuildKit.cylinder(self, 0.23, 0.01, Vector3(gx + 0.25, 0.16, pipe_z), BuildKit.color_mat(Color(0.12, 0.14, 0.14), 0.1, 0.3), false, Vector3.ZERO, -1.0, 12)
	# Laub und Moos auf dem Blech
	var moss := BuildKit.tex_mat("moss", 0.4)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for k in 6:
		var x := rng.randf_range(-HALF.x, HALF.x)
		BuildKit.box(self, Vector3(rng.randf_range(0.25, 0.5), 0.02, rng.randf_range(0.2, 0.4)), Vector3(x, roof_y(x) + 0.19, rng.randf_range(-HALF.y, HALF.y)),
				moss, false, Vector3(0, rng.randf() * 90.0, -angle))


## Wellblech: Längsrillen in Gefällerichtung (x), flach in der x-z-Ebene.
func _corrugated(length: float, width: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pitch := 0.076
	var amp := 0.018
	var n := int(width / (pitch * 0.5))
	var hx := length * 0.5
	for i in n:
		var z0 := -width * 0.5 + i * pitch * 0.5
		var z1 := z0 + pitch * 0.5
		var y0 := amp if i % 2 == 0 else -amp
		var y1 := -y0
		var nrm := Vector3(0, 1, 0).lerp(Vector3(0, 0, 1 if i % 2 == 0 else -1), 0.3).normalized()
		var q := [Vector3(-hx, y0, z0), Vector3(hx, y0, z0), Vector3(hx, y1, z1), Vector3(-hx, y1, z1)]
		for k: int in [0, 2, 1, 0, 3, 2]:
			st.set_normal(nrm)
			st.add_vertex(q[k])
	var m := st.commit()
	return m
