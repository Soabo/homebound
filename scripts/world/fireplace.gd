class_name Fireplace
extends Node3D
## Kaminfeuer: Glut, Holzscheite, flackerndes Licht und Knistern.
## Der Knoten sitzt mittig vor der Feuerstelle; das Feuer strahlt nach +x.

var _light: OmniLight3D
var _ember_mat: StandardMaterial3D
var _noise := FastNoiseLite.new()
var _t := 0.0


func _ready() -> void:
	_noise.frequency = 1.6
	_ember_mat = BuildKit.emissive_mat(Color(1.0, 0.35, 0.08), 3.0)
	BuildKit.box(self, Vector3(0.36, 0.06, 0.6), Vector3(-0.1, 0.03, 0), _ember_mat, false)
	var log_mat := BuildKit.color_mat(Color(0.12, 0.08, 0.06), 0.95)
	BuildKit.cylinder(self, 0.06, 0.55, Vector3(-0.12, 0.1, -0.05), log_mat, false, Vector3(90, 15, 0), -1.0, 8)
	BuildKit.cylinder(self, 0.055, 0.5, Vector3(-0.05, 0.17, 0.06), log_mat, false, Vector3(90, -20, 0), -1.0, 8)
	var flame_mat := BuildKit.emissive_mat(Color(1.0, 0.55, 0.15), 5.0)
	flame_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flame_mat.albedo_color = Color(1.0, 0.6, 0.2, 0.6)
	flame_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	BuildKit.cylinder(self, 0.12, 0.3, Vector3(-0.08, 0.32, 0), flame_mat, false, Vector3.ZERO, 0.0, 8)

	_light = OmniLight3D.new()
	_light.position = Vector3(0.35, 0.45, 0)
	_light.light_color = Color(1.0, 0.55, 0.25)
	_light.light_energy = 2.2
	_light.omni_range = 10.0
	_light.omni_attenuation = 1.4
	_light.shadow_enabled = true
	add_child(_light)

	var crackle := FireCrackle.new()
	crackle.position = Vector3(0.1, 0.3, 0)
	add_child(crackle)


func _process(delta: float) -> void:
	_t += delta
	var n := _noise.get_noise_1d(_t * 10.0) * 0.5 + 0.5
	var n2 := _noise.get_noise_1d(_t * 31.0 + 100.0) * 0.5 + 0.5
	_light.light_energy = 2.4 + n * 1.2 + n2 * 0.5
	_light.position.z = (n2 - 0.5) * 0.12
	_ember_mat.emission_energy_multiplier = 2.2 + n * 1.6
