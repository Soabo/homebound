class_name StructurePylon
extends Interactable
## Eine der drei Säulen um die fremde Struktur. Leuchtet auf, wenn sie in der Reihenfolge dran ist.

var index: int = 0
var structure: AlienStructure

var _mat: StandardMaterial3D
var _light: OmniLight3D


func _ready() -> void:
	var hull := CrashSite.hull_material()
	BuildKit.lathe(self, PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.4, 0.0), Vector2(0.3, 0.3), Vector2(0.18, 2.2), Vector2(0.0, 2.4)]), Vector3.ZERO, hull, 6)
	_mat = BuildKit.emissive_mat(Color(0.5, 1.0, 1.0), 0.5)
	var glyph := BuildKit.box(self, Vector3(0.05, 0.9, 0.2), Vector3(0.0, 1.3, 0.22), _mat, false)
	glyph.rotation_degrees.y = 0.0
	# Punkte zeigen die Nummer der Säule (1–3)
	for k in index + 1:
		BuildKit.sphere(self, 0.035, Vector3(0.0, 0.7 - k * 0.1, 0.26), _mat, Vector3.ONE, 6)
	_light = OmniLight3D.new()
	_light.position = Vector3(0, 1.4, 0.4)
	_light.light_color = Color(0.5, 1.0, 1.0)
	_light.omni_range = 4.0
	_light.light_energy = 0.0
	add_child(_light)
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = 0.4
	sh.height = 2.4
	cs.shape = sh
	cs.position = Vector3(0, 1.2, 0)
	body.add_child(cs)
	add_child(body)
	# Glyphe zur Mitte der Struktur drehen
	look_at(Vector3(get_parent().global_position.x, global_position.y, get_parent().global_position.z), Vector3.UP)
	rotate_y(PI)


func refresh() -> void:
	var off := WorldState.structure_off or WorldState.pylons_off.has(index)
	if off:
		_mat.emission_energy_multiplier = 0.05
		_light.light_energy = 0.0


func pulse(on: bool) -> void:
	if WorldState.pylons_off.has(index):
		return
	_mat.emission_energy_multiplier = 4.0 if on else 0.5
	_light.light_energy = 2.0 if on else 0.0


func get_prompt(_player: Node) -> String:
	if WorldState.structure_off:
		return "Säule – erloschen"
	if WorldState.pylons_off.has(index):
		return "Säule %d – abgeschaltet" % (index + 1)
	return "[E] Säule %d berühren" % (index + 1)


func interact(player: Node) -> void:
	if structure:
		structure.pylon_pressed(index, player)
