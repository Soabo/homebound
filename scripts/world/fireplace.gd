class_name Fireplace
extends Interactable
## Feuer im Kachelofen (früher Kamin): Glut, Holzscheite, flackerndes Licht und Knistern.
## Die Kacheln speichern die Wärme: nach dem Erlöschen heizt der Ofen die Hütte noch stored_heat_hours weiter.
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
var pot: CookPot = null          ## Topf über dem Feuer (CookPot)
var _last_h: float = -1.0


func _ready() -> void:
	add_to_group("heat_source")
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
	var have := Inventory.count_fuel()
	if _strength <= 0.0:
		var state := "Kachelofen – erloschen, die Kacheln sind noch warm." if stored_heat() > 0.0 else "Kachelofen – erloschen und kalt."
		return "%s  [E] Feuer anzünden (%d Holz – du hast %d)" % [state, wood, have]
	if _strength < 1.0:
		return "Kachelofen – das Feuer wird schwächer.  [E] Holz nachlegen (%d Holz – du hast %d)" % [wood, have]
	return "Kachelofen – das Feuer brennt.  [E] Holz nachlegen (%d Holz)" % wood


func get_secondary_prompt(_player: Node) -> String:
	var inside := ("   Topf: " + pot.status_text()) if pot else ""
	if _strength > 0.2:
		return "[R] Über dem Feuer kochen" + inside
	return ("[R] Topf herausnehmen" + inside) if pot else ""


func secondary_interact(_player: Node) -> void:
	if _strength > 0.2:
		get_tree().call_group("game_menus", "open_crafting", "stove", self)
	elif pot:
		take_pot()


## Topf über dem Feuer (wie beim Küchenofen, CookPot): gart nur, solange es richtig brennt.
func start_cooking(r: Dictionary) -> String:
	if pot:
		return "Über dem Feuer hängt schon ein Topf: " + pot.status_text()
	if not Inventory.has_all(r.get("needs", {})):
		return "Dir fehlen Zutaten."
	Inventory.remove_all(r.get("needs", {}))
	pot = CookPot.start(r)
	return ""


func take_pot() -> void:
	if pot == null:
		return
	var msg := pot.take_out()
	if msg == "":
		EventBus.notify("Davon kannst du nicht mehr tragen – es bleibt im Topf.", 2.5)
		return
	pot = null
	EventBus.notify(msg, 2.5)


## Gegart wird, solange das Feuer noch kräftig brennt (wie die 0,2-Grenze beim Kochen).
func cook_until() -> float:
	return burn_until - 0.2 * maxf(float(_cfg.get("fade_hours", 6.0)), 0.01)


func interact(_player: Node) -> void:
	var wood := int(_cfg.get("wood", 1))
	if Inventory.count_fuel() < wood:
		EventBus.notify("Dafür brauchst du %d Holz." % wood, 2.5)
		return
	Inventory.remove_fuel(wood)
	burn_until = TimeManager.get_total_hours() + float(_cfg.get("burn_hours", 12.0))
	SoundBank.play_at(self, "place", global_position + Vector3(0.2, 0.3, 0), -4.0)
	EventBus.notify("Das Feuer brennt wieder.", 2.0)
	Tasks.flag("fire_lit")


## Heizt die Hütte: solange das Feuer brennt und danach, solange die Kacheln die Wärme halten.
func heats_cabin() -> bool:
	return strength() > 0.15 or stored_heat() > 0.0


## Gespeicherte Wärme der Kacheln nach dem Erlöschen (1 = gerade aus, 0 = kalt).
func stored_heat() -> float:
	var hours := float(_cfg.get("stored_heat_hours", 0.0))
	if hours <= 0.0:
		return 0.0
	var since := TimeManager.get_total_hours() - burn_until
	if since < 0.0:
		return 1.0
	return clampf(1.0 - since / hours, 0.0, 1.0)


## Wärme direkt vor dem Kamin (0..1, Reichweite SurvivalConfig.hearth_radius).
func heat_at(pos: Vector3) -> float:
	var st := strength()
	var d := to_global(Vector3(0.35, 0.45, 0)).distance_to(pos)
	var near := clampf(1.0 - d / SurvivalConfig.get_default().hearth_radius, 0.0, 1.0)
	if st <= 0.0:
		# warme Kacheln: direkt am Ofen (Ofenbank) noch etwas Wärme
		return near * float(_cfg.get("stored_heat_near", 0.4)) * stored_heat()
	return near * clampf(st * 2.0, 0.3, 1.0)


func strength() -> float:
	var left := burn_until - TimeManager.get_total_hours()
	return clampf(left / maxf(float(_cfg.get("fade_hours", 6.0)), 0.01), 0.0, 1.0)


func _process(delta: float) -> void:
	var now := TimeManager.get_total_hours()
	if _last_h >= 0.0:
		CookPot.tick(pot, _last_h, now, cook_until(), "Kachelofen")
	_last_h = now
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
	return {"burn_until": burn_until, "pot": pot.to_dict() if pot else {}}


func set_state(st: Dictionary) -> void:
	burn_until = float(st.get("burn_until", burn_until))
	pot = CookPot.from_dict(st.get("pot", {}))
	_last_h = -1.0
