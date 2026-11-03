class_name Lamp
extends Node3D
## Deckenlampe oder Wandleuchte mit Glühbirne.
## Später hängt sie am Stromnetz (GDD 7.4) – dann zählt zusätzlich, ob Strom da ist.

@export var light_color: Color = Color(1.0, 0.8, 0.55)
@export var energy: float = 1.3
@export var light_range: float = 7.0
@export var casts_shadow: bool = true
## "ceiling" hängt von der Decke, "wall" sitzt an der Wand (Leuchte zeigt nach +z).
@export var style: String = "ceiling"

var is_on: bool = false
var light: OmniLight3D
var _bulb_mat: StandardMaterial3D
var _glass_mat: StandardMaterial3D


func _ready() -> void:
	_bulb_mat = BuildKit.emissive_mat(light_color, 0.0)
	_bulb_mat.albedo_color = Color(0.9, 0.88, 0.8)
	var metal := BuildKit.color_mat(Color(0.12, 0.11, 0.1), 0.5, 0.6)
	var light_pos := Vector3.ZERO
	if style == "lantern":
		# Wandlaterne: Halter, Eisenrahmen, Glas, warmes Licht
		var iron := BuildKit.tex_mat("metal", 0.5, Color(0.6, 0.55, 0.5), 0.6)
		BuildKit.box(self, Vector3(0.04, 0.04, 0.22), Vector3(0, 0.22, 0.1), iron, false)
		BuildKit.box(self, Vector3(0.08, 0.14, 0.03), Vector3(0, 0.2, 0.015), iron, false)
		BuildKit.cylinder(self, 0.09, 0.03, Vector3(0, 0.12, 0.2), iron, false, Vector3.ZERO, 0.04, 6)
		BuildKit.cylinder(self, 0.08, 0.04, Vector3(0, -0.16, 0.2), iron, false, Vector3.ZERO, -1.0, 6)
		for p: Vector2 in [Vector2(-0.06, -0.06), Vector2(0.06, -0.06), Vector2(-0.06, 0.06), Vector2(0.06, 0.06)]:
			BuildKit.box(self, Vector3(0.012, 0.25, 0.012), Vector3(p.x, -0.02, 0.2 + p.y), iron, false)
		var glass := BuildKit.emissive_mat(Color(1.0, 0.75, 0.4), 0.0)
		glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		glass.albedo_color = Color(1.0, 0.85, 0.6, 0.35)
		_glass_mat = glass
		BuildKit.box(self, Vector3(0.11, 0.2, 0.11), Vector3(0, -0.02, 0.2), glass, false)
		BuildKit.sphere(self, 0.025, Vector3(0, -0.04, 0.2), _bulb_mat, Vector3(1, 1.6, 1), 6)
		light_pos = Vector3(0, -0.02, 0.32)
	elif style == "wall":
		BuildKit.box(self, Vector3(0.14, 0.2, 0.06), Vector3(0, 0, 0.03), metal, false)
		BuildKit.sphere(self, 0.07, Vector3(0, 0.02, 0.13), _bulb_mat)
		BuildKit.cylinder(self, 0.11, 0.12, Vector3(0, 0.1, 0.13), metal, false, Vector3.ZERO, 0.05)
		light_pos = Vector3(0, -0.05, 0.25)
	else:
		BuildKit.box(self, Vector3(0.01, 0.5, 0.01), Vector3(0, -0.25, 0), metal, false)
		BuildKit.cylinder(self, 0.22, 0.16, Vector3(0, -0.56, 0), metal, false, Vector3.ZERO, 0.06)
		BuildKit.sphere(self, 0.06, Vector3(0, -0.62, 0), _bulb_mat)
		light_pos = Vector3(0, -0.72, 0)
	light = OmniLight3D.new()
	light.position = light_pos
	light.light_color = light_color
	light.light_energy = energy
	light.omni_range = light_range
	light.omni_attenuation = 1.2
	light.shadow_enabled = casts_shadow
	light.light_volumetric_fog_energy = 0.6
	add_child(light)
	set_on(is_on)


## Schalter-Stellung setzen. Leuchten tut die Lampe nur, wenn auch Strom da ist.
func set_on(value: bool) -> void:
	is_on = value
	_refresh()


func _refresh() -> void:
	var lit := is_on and PowerManager.has_power()
	if light:
		light.visible = lit
	if _bulb_mat:
		_bulb_mat.emission_energy_multiplier = 4.0 if lit else 0.0
	if _glass_mat:
		_glass_mat.emission_energy_multiplier = 1.2 if lit else 0.0
	PowerManager.set_consumer(str(get_instance_id()), is_on)


func _enter_tree() -> void:
	if not PowerManager.power_changed.is_connected(_on_power_changed):
		PowerManager.power_changed.connect(_on_power_changed)


func _exit_tree() -> void:
	PowerManager.set_consumer(str(get_instance_id()), false)


func _on_power_changed(_p: bool) -> void:
	# Kurzes Flackern, wenn der Strom wiederkommt oder ausfällt
	if is_on and light:
		for i in 3:
			light.visible = not light.visible
			await get_tree().create_timer(0.06).timeout
	_refresh()
