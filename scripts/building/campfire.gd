class_name Campfire
extends Node3D
## Lagerfeuer (gebaut aus einem Lagerfeuer-Bündel): wärmt, macht Licht, hält Tiere fern –
## lockt aber Drohne und Sucher an. Brennt ein paar Stunden, R legt Holz/Torf nach, E löscht/zündet.
## Werte: data/survival/survival.tres (campfire_*, fire_gain).

var structure: Structure
var _light: OmniLight3D
var _flame: MeshInstance3D
var _crackle: FireCrackle
var _t: float = 0.0
var _cfg: SurvivalConfig


func _ready() -> void:
	_cfg = SurvivalConfig.get_default()
	add_to_group("heat_source")
	add_to_group("campfire")
	var stone := BuildKit.tex_mat("stone", 0.4)
	for i in 9:
		var a := TAU * i / 9.0
		BuildKit.sphere(self, 0.13, Vector3(cos(a) * 0.45, 0.06, sin(a) * 0.45), stone, Vector3(1.2, 0.7, 1.0), 6)
	var logs := BuildKit.tex_mat("bark", 0.4)
	for k in 4:
		BuildKit.cylinder(self, 0.05, 0.6, Vector3(0, 0.12, 0), logs, false, Vector3(70, k * 45.0, 0), 0.04, 6)
	BuildKit.cylinder(self, 0.3, 0.02, Vector3(0, 0.01, 0), BuildKit.color_mat(Color(0.05, 0.04, 0.03)), false, Vector3.ZERO, -1.0, 12)
	var flame_mat := BuildKit.emissive_mat(Color(1.0, 0.55, 0.15), 3.0)
	_flame = BuildKit.cylinder(self, 0.18, 0.5, Vector3(0, 0.35, 0), flame_mat, false, Vector3.ZERO, 0.0, 8)
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.62, 0.3)
	_light.omni_range = 9.0
	_light.shadow_enabled = true
	_light.position = Vector3(0, 0.6, 0)
	add_child(_light)
	_crackle = FireCrackle.new()
	_crackle.position = Vector3(0, 0.3, 0)
	add_child(_crackle)
	if not _rec().has("burn_until"):
		_rec()["burn_until"] = TimeManager.get_total_hours() + _cfg.campfire_hours
		Tasks.flag("campfire")


func _rec() -> Dictionary:
	return Builder.record(structure.uid) if structure else {}


func hours_left() -> float:
	return maxf(float(_rec().get("burn_until", 0.0)) - TimeManager.get_total_hours(), 0.0)


func burning() -> bool:
	return hours_left() > 0.0


## Wärme an einem Punkt (0..1).
func heat_at(pos: Vector3) -> float:
	if not burning():
		return 0.0
	var d := global_position.distance_to(pos)
	return clampf(1.0 - d / _cfg.campfire_radius, 0.0, 1.0) * clampf(hours_left() / 0.5, 0.3, 1.0)


## Löschen (z. B. durch ein Ereignis in der Zeltnacht).
func put_out() -> void:
	_rec()["burn_until"] = TimeManager.get_total_hours()
	SoundBank.play_at(get_parent(), "drip", global_position + Vector3(0, 0.3, 0), -2.0, 0.6)


func get_prompt() -> String:
	if burning():
		return "Lagerfeuer (brennt noch ca. %d Min.)  [E] Löschen" % int(hours_left() * 60.0)
	return "Lagerfeuer (aus)  [E] Anzünden (1 Holz oder Torf)"


func get_secondary_prompt() -> String:
	return "[R] Holz nachlegen (%d dabei)" % Inventory.count_fuel()


func interact() -> void:
	if burning():
		put_out()
		EventBus.notify("Feuer gelöscht. Jetzt ist es dunkel.", 2.0)
		return
	if not Inventory.remove_fuel(1):
		EventBus.notify("Ich brauche Holz oder Torf.", 2.0)
		return
	_rec()["burn_until"] = TimeManager.get_total_hours() + _cfg.campfire_hours_per_wood
	EventBus.notify("Das Feuer brennt.", 2.0)


func secondary_interact() -> void:
	if not Inventory.remove_fuel(1):
		EventBus.notify("Kein Holz und kein Torf dabei.", 2.0)
		return
	var base := maxf(float(_rec().get("burn_until", 0.0)), TimeManager.get_total_hours())
	_rec()["burn_until"] = base + _cfg.campfire_hours_per_wood
	SoundBank.play_at(get_parent(), "place", global_position + Vector3(0, 0.3, 0), -4.0)
	EventBus.notify("Holz nachgelegt – brennt noch ca. %d Min." % int(hours_left() * 60.0), 2.0)


func _process(delta: float) -> void:
	_t += delta
	var s := clampf(hours_left() / 0.4, 0.0, 1.0)
	_flame.visible = s > 0.02
	_flame.scale = Vector3(1.0, 0.6 + 0.4 * s + sin(_t * 9.0) * 0.08, 1.0) * maxf(s, 0.3)
	_light.light_energy = s * (1.6 + sin(_t * 11.0) * 0.25 + sin(_t * 23.0) * 0.12)
	_light.visible = s > 0.02
	_crackle.volume_db = lerpf(-60.0, -8.0, s)
