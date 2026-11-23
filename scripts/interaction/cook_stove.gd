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
var pot: CookPot = null          ## was gerade im Ofen gart (CookPot), sonst null
var _last_h: float = -1.0


func _ready() -> void:
	add_to_group("heat_source")
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


func heats_cabin() -> bool:
	return lit()


## Wärme am Küchenofen (schwächer als der Kamin).
func heat_at(pos: Vector3) -> float:
	if not lit():
		return 0.0
	var d := to_global(anchor).distance_to(pos)
	return clampf(1.0 - d / SurvivalConfig.get_default().hearth_radius, 0.0, 1.0) * 0.7


func lit() -> bool:
	return TimeManager.get_total_hours() < burn_until


func get_prompt(_p: Node) -> String:
	var inside := ("   Im Ofen: " + pot.status_text()) if pot else ""
	if lit():
		var left := burn_until - TimeManager.get_total_hours()
		return "Holzofen – brennt noch etwa %d Std.  [E] Kochen%s" % [maxi(1, int(round(left))), inside]
	if pot and not pot.finished():
		inside += " (wartet aufs Feuer)"
	return "Holzofen – kalt.  [E] mit 1 Holz anheizen (du hast %d)%s" % [Inventory.count_fuel(), inside]


func get_secondary_prompt(_p: Node) -> String:
	if not lit() and pot:
		return "[R] Herausnehmen"
	return "[R] Holz nachlegen" if lit() and Inventory.count_fuel() > 0 else ""


func interact(_p: Node) -> void:
	if lit():
		get_tree().call_group("game_menus", "open_crafting", "stove", self)
		return
	_add_wood()


func secondary_interact(_p: Node) -> void:
	if lit():
		_add_wood()
	elif pot:
		take_pot()


## Kochen beginnen: Zutaten wandern aus dem Rucksack in den Ofen. "" = ok, sonst Grund.
func start_cooking(r: Dictionary) -> String:
	if pot:
		return "Im Ofen ist schon etwas: " + pot.status_text()
	if not Inventory.has_all(r.get("needs", {})):
		return "Dir fehlen Zutaten."
	Inventory.remove_all(r.get("needs", {}))
	pot = CookPot.start(r)
	SoundBank.play_at(self, "place", global_position + anchor, -6.0)
	return ""


## Inhalt herausnehmen (fertig = Gericht, unfertig = Zutaten zurück).
func take_pot() -> void:
	if pot == null:
		return
	var msg := pot.take_out()
	if msg == "":
		EventBus.notify("Davon kannst du nicht mehr tragen – es bleibt im Ofen.", 2.5)
		return
	pot = null
	SoundBank.play_at(self, "pickup", global_position + anchor, -6.0)
	EventBus.notify(msg, 2.5)


## Bis wann gegart wird (Spielstunden) – solange der Ofen brennt.
func cook_until() -> float:
	return burn_until


func _add_wood() -> void:
	if not Inventory.remove_fuel(1):
		EventBus.notify("Dafür brauchst du Holz.", 2.0)
		return
	var now := TimeManager.get_total_hours()
	burn_until = maxf(burn_until, now) + Supplies.config.stove_burn_hours
	SoundBank.play_at(self, "place", global_position + door_center, -4.0)
	EventBus.notify("Der Ofen brennt.", 1.5)
	Tasks.flag("stove_lit")


func _process(_delta: float) -> void:
	var now := TimeManager.get_total_hours()
	if _last_h >= 0.0:
		CookPot.tick(pot, _last_h, now, cook_until(), "Ofen")
	_last_h = now
	var left := burn_until - TimeManager.get_total_hours()
	var s := clampf(left / 0.5, 0.0, 1.0)
	var flick := 0.85 + 0.15 * sin(Time.get_ticks_msec() / 90.0) * sin(Time.get_ticks_msec() / 37.0)
	_glow.emission_energy_multiplier = 2.5 * s * flick
	_light.light_energy = 0.6 * s * flick
	_crackle.set_strength(s * 0.6)


func persist_key() -> String:
	return str(get_path())


func get_state() -> Dictionary:
	return {"burn_until": burn_until, "pot": pot.to_dict() if pot else {}}


func set_state(st: Dictionary) -> void:
	burn_until = float(st.get("burn_until", -1.0))
	pot = CookPot.from_dict(st.get("pot", {}))
	_last_h = -1.0
