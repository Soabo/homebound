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


func _ready() -> void:
	_bulb_mat = BuildKit.emissive_mat(light_color, 0.0)
	_bulb_mat.albedo_color = Color(0.9, 0.88, 0.8)
	var metal := BuildKit.color_mat(Color(0.12, 0.11, 0.1), 0.5, 0.6)
	var light_pos := Vector3.ZERO
	if style == "wall":
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


func set_on(value: bool) -> void:
	is_on = value
	if light:
		light.visible = value
	if _bulb_mat:
		_bulb_mat.emission_energy_multiplier = 4.0 if value else 0.0
