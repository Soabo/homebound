class_name Fireplace
extends Interactable
## Kaminfeuer: Glut, Holzscheite, flackerndes Licht und Knistern.
## Der Knoten sitzt mittig vor der Feuerstelle; das Feuer strahlt nach +x.
## Es brennt etwa einen halben Tag; die letzten Stunden wird es dunkler und leiser, bis es aus ist.
## Mit Holz (E) brennt es wieder. Werte: data/house/house.json ("fireplace").

var burn_until: float = -1.0  ## Gesamtstunde, bis zu der es brennt
var _cfg: Dictionary = {}
var _strength: float = 1.0
var _flame: MeshInstance3D
var _crackle: FireCrackle
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
	_flame = BuildKit.cylinder(self, 0.12, 0.3, Vector3(-0.08, 0.32, 0), flame_mat, false, Vector3.ZERO, 0.0, 8)

	_light = OmniLight3D.new()
	_light.position = Vector3(0.35, 0.45, 0)
	_light.light_color = Color(1.0, 0.55, 0.25)
	_light.light_energy = 2.2
	_light.omni_range = 10.0
	_light.omni_attenuation = 1.4
	_light.shadow_enabled = true
	add_child(_light)

	_crackle = FireCrackle.new()
	_crackle.position = Vector3(0.1, 0.3, 0)
	add_child(_crackle)

	# zum Anvisieren (Holz nachlegen)
	var area := Area3D.new()
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(0.7, 0.6, 1.0)
	cs.shape = sh
	cs.position = Vector3(0.1, 0.3, 0)
	area.add_child(cs)
	add_child(area)

	_cfg = DataDB.load_json("res://data/house/house.json").get("fireplace", {})
	burn_until = TimeManager.get_total_hours() + float(_cfg.get("burn_hours", 12.0))
	add_to_group("persistent")
	GameState.restore(self)


func get_prompt(_player: Node) -> String:
	var wood := int(_cfg.get("wood", 1))
	var have := Inventory.count("wood")
	if _strength <= 0.0:
		return "Kamin – erloschen.  [E] Feuer anzünden (%d Holz – du hast %d)" % [wood, have]
	if _strength < 1.0:
		return "Kamin – das Feuer wird schwächer.  [E] Holz nachlegen (%d Holz – du hast %d)" % [wood, have]
	return "Kamin – das Feuer brennt.  [E] Holz nachlegen (%d Holz)" % wood


func interact(_player: Node) -> void:
	var wood := int(_cfg.get("wood", 1))
	if Inventory.count("wood") < wood:
		EventBus.notify("Dafür brauchst du %d Holz." % wood, 2.5)
		return
	Inventory.remove("wood", wood)
	burn_until = TimeManager.get_total_hours() + float(_cfg.get("burn_hours", 12.0))
	SoundBank.play_at(self, "place", global_position + Vector3(0.2, 0.3, 0), -4.0)
	EventBus.notify("Das Feuer brennt wieder.", 2.0)


## Wie stark das Feuer gerade brennt (1 = voll, 0 = aus).
func strength() -> float:
	var left := burn_until - TimeManager.get_total_hours()
	return clampf(left / maxf(float(_cfg.get("fade_hours", 6.0)), 0.01), 0.0, 1.0)


func _process(delta: float) -> void:
	_t += delta
	_strength = strength()
	var s := _strength
	var n := _noise.get_noise_1d(_t * 10.0) * 0.5 + 0.5
	var n2 := _noise.get_noise_1d(_t * 31.0 + 100.0) * 0.5 + 0.5
	_light.visible = s > 0.0
	_light.light_energy = (2.4 + n * 1.2 + n2 * 0.5) * s
	_light.omni_range = lerpf(3.0, 10.0, s)
	_light.position.z = (n2 - 0.5) * 0.12
	# Glut glimmt am längsten, Flammen werden kleiner und verschwinden zuerst
	_ember_mat.emission_energy_multiplier = (2.2 + n * 1.6) * sqrt(s)
	_flame.visible = s > 0.15
	_flame.scale = Vector3(lerpf(0.5, 1.0, s), maxf(s, 0.05), lerpf(0.5, 1.0, s))
	_crackle.set_strength(s)


func persist_key() -> String:
	return str(get_path())


func get_state() -> Dictionary:
	return {"burn_until": burn_until}


func set_state(st: Dictionary) -> void:
	burn_until = float(st.get("burn_until", burn_until))
