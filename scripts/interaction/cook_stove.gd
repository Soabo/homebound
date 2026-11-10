class_name CookStove
extends Interactable
## Holzofen in der Küche: zum Kochen (Wasser abkochen, Fleisch braten, Suppe …).
## Ohne Feuer: [E] mit Holz anheizen (brennt einige Stunden). Mit Feuer: [E] Kochen (Menü).
## Glut hinter der Ofentür, leises Knistern. Brenndauer: data/supplies/supplies.tres (stove_burn_hours).
## Der Knoten liegt im Ursprung der Hütte; anchor = Mitte der Herdplatte.

@export var anchor: Vector3 = Vector3.ZERO
@export var door_center: Vector3 = Vector3.ZERO

var burn_until: float = -1.0
var _glow: StandardMaterial3D
var _light: OmniLight3D
var _crackle: FireCrackle


func _ready() -> void:
	add_to_group("persistent")
	add_to_group("cook_stove")
	_glow = BuildKit.emissive_mat(Color(1.0, 0.4, 0.1), 0.0)
	BuildKit.box(self, Vector3(0.3, 0.24, 0.005), door_center, _glow, false)
	_light = OmniLight3D.new()
	_light.position = door_center + Vector3(0, 0, 0.25)
	_light.light_color = Color(1.0, 0.5, 0.2)
	_light.omni_range = 3.5
	_light.light_energy = 0.0
	add_child(_light)
	_crackle = FireCrackle.new()
	_crackle.position = door_center
	add_child(_crackle)
	var area := Area3D.new()
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(0.8, 0.9, 0.6)
	cs.shape = sh
	cs.position = anchor + Vector3(0, -0.4, 0)
	area.add_child(cs)
	add_child(area)
	GameState.restore(self)


func lit() -> bool:
	return TimeManager.get_total_hours() < burn_until


func get_prompt(_p: Node) -> String:
	if lit():
		var left := burn_until - TimeManager.get_total_hours()
		return "Holzofen – brennt noch etwa %d Std.  [E] Kochen" % maxi(1, int(round(left)))
	return "Holzofen – kalt.  [E] mit 1 Holz anheizen (du hast %d)" % Inventory.count("wood")


func get_secondary_prompt(_p: Node) -> String:
	return "[R] Holz nachlegen" if lit() and Inventory.count("wood") > 0 else ""


func interact(_p: Node) -> void:
	if lit():
		get_tree().call_group("game_menus", "open_crafting", "stove")
		return
	_add_wood()


func secondary_interact(_p: Node) -> void:
	if lit():
		_add_wood()


func _add_wood() -> void:
	if not Inventory.remove("wood", 1):
		EventBus.notify("Dafür brauchst du Holz.", 2.0)
		return
	var now := TimeManager.get_total_hours()
	burn_until = maxf(burn_until, now) + Supplies.config.stove_burn_hours
	SoundBank.play_at(self, "place", global_position + door_center, -4.0)
	EventBus.notify("Der Ofen brennt.", 1.5)
	Tasks.flag("stove_lit")


func _process(_delta: float) -> void:
	var left := burn_until - TimeManager.get_total_hours()
	var s := clampf(left / 0.5, 0.0, 1.0)
	var flick := 0.85 + 0.15 * sin(Time.get_ticks_msec() / 90.0) * sin(Time.get_ticks_msec() / 37.0)
	_glow.emission_energy_multiplier = 2.5 * s * flick
	_light.light_energy = 0.6 * s * flick
	_crackle.set_strength(s * 0.6)


func persist_key() -> String:
	return str(get_path())


func get_state() -> Dictionary:
	return {"burn_until": burn_until}


func set_state(st: Dictionary) -> void:
	burn_until = float(st.get("burn_until", -1.0))
