extends Node
## Versorgungs-Manager: alles, was man selbst herstellt, statt es nur zu finden.
##  - Hochbeete (säen, gießen, ernten; Talverwandlung kann Ernten verderben)
##  - Gießkanne (Füllung), Übelkeit von Rohwasser / rohem Essen
##  - Kleintierschlingen (Fang über Nacht)
##  - Generator-Wartung (Zustand, Öl, Zündkerze), Holzvergaser, Zellen-Adapter
##  - Metall-Fundstellen im Wald (tauchen zufällig auf, verschwinden nach dem Abbauen)
##  - eingebaute Überwachungskameras
## Werte: data/supplies/supplies.tres (SupplyConfig). Teil des Spielstands.

signal changed

const CONFIG_PATH := "res://data/supplies/supplies.tres"
const BED_COUNT := 4
const WRECK := Vector3(2.0, 0, 33.0)

var config: SupplyConfig
## Beete: {"crop": "", "growth": 0.0 (Tage), "watered": false, "dry": 0, "alien": false, "withered": false}
var beds: Array = []
var can_water: int = 0                ## Füllung der Gießkanne
var sick_until: float = -1.0          ## Spielstunden-Zeitpunkt (Tag*24+Stunde), bis dahin ist einem übel
var generator_condition: float = 85.0
var gasifier: bool = false
var cell_adapter: bool = false
## Metall-Fundstellen: {"id": int, "kind": String, "x": float, "z": float, "yaw": float}
var scrap_spots: Array = []
var _next_spot_id: int = 1
## Eingebaute Kameras: {"index": int, "pos": Vector3, "normal": Vector3, "yaw": float}
var cameras: Array = []
## Schlingen, die heute Morgen etwas gefangen haben (Builder-uid)
var snare_catches: Array = []
var _last_hour_abs: float = -1.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	config = load(CONFIG_PATH) as SupplyConfig
	if config == null:
		config = SupplyConfig.new()
	_reset()
	TimeManager.day_changed.connect(_on_day_changed)


func _reset() -> void:
	beds.clear()
	for i in BED_COUNT:
		beds.append(_empty_bed())
	can_water = 0
	sick_until = -1.0
	generator_condition = 85.0
	gasifier = false
	cell_adapter = false
	scrap_spots.clear()
	cameras.clear()
	snare_catches.clear()
	for i in config.scrap_spots_start:
		_spawn_scrap_spot()


func _empty_bed() -> Dictionary:
	return {"crop": "", "growth": 0.0, "watered": false, "dry": 0, "alien": false, "withered": false}


func _hour_abs() -> float:
	return TimeManager.day * 24.0 + TimeManager.hour


# --- Zeit -----------------------------------------------------------------

func _process(_delta: float) -> void:
	var h := _hour_abs()
	if _last_hour_abs < 0.0:
		_last_hour_abs = h
		return
	var dh := h - _last_hour_abs
	if dh <= 0.0 or dh > 48.0:
		_last_hour_abs = h
		return
	_last_hour_abs = h
	# Generator nutzt sich ab, solange er läuft
	if PowerManager.generator_running and not PowerManager.outage:
		generator_condition = maxf(generator_condition - config.wear_per_hour * dh, 0.0)
		if generator_condition < config.low_condition and _rng.randf() < config.low_outage_chance * dh:
			PowerManager.trigger_outage()
			EventBus.notify("Der Generator stottert und geht aus. Er braucht Wartung (Öl, Zündkerze).", 4.0)
			Tasks.flag("generator_stalled")
	# Übelkeit: Hunger und Durst sinken schneller
	if is_sick():
		var f := (config.sick_drain_factor - 1.0) * dh
		Survival.drain(Survival.HUNGER_PER_HOUR * f, Survival.THIRST_PER_HOUR * f)


func _on_day_changed(_day: int) -> void:
	var stage := WorldState.stage()
	# Beete wachsen über Nacht – nur gegossene
	for b: Dictionary in beds:
		if b["crop"] == "" or b["withered"]:
			continue
		var crop: Dictionary = config.crops.get(b["crop"], {})
		if b["watered"]:
			b["growth"] = float(b["growth"]) + 1.0
			b["dry"] = 0
		else:
			b["dry"] = int(b["dry"]) + 1
			if int(b["dry"]) >= config.dry_days_to_wither:
				b["withered"] = true
		b["watered"] = false
		if not b["alien"] and _rng.randf() < config.alien_spoil_chance[clampi(stage, 0, config.alien_spoil_chance.size() - 1)]:
			b["alien"] = true
		if float(b["growth"]) >= float(crop.get("days", 3)) and not b["withered"]:
			b["growth"] = float(crop.get("days", 3))
	# Schlingen: Fang über Nacht
	snare_catches.clear()
	var fac: float = config.snare_stage_factor[clampi(stage, 0, config.snare_stage_factor.size() - 1)]
	for rec: Dictionary in Builder.records:
		if rec.get("type", "") != "snare":
			continue
		var p: Vector3 = rec.get("pos", Vector3.ZERO)
		var chance := config.snare_catch_chance * fac
		if Terrain.yard_distance(p.x, p.z) < 2.0:
			chance *= 0.5
		if _rng.randf() < chance:
			rec["caught"] = true
	# neue Metall-Fundstellen
	var n := _rng.randi_range(config.scrap_spots_per_day.x, config.scrap_spots_per_day.y)
	for i in n:
		if scrap_spots.size() >= config.scrap_spots_max:
			break
		_spawn_scrap_spot()
	changed.emit()
	get_tree().call_group("scrap_field", "sync")
	get_tree().call_group("garden_bed", "refresh")
	get_tree().call_group("structure", "refresh_catch")


# --- Hochbeete --------------------------------------------------------------

func bed_state(i: int) -> String:
	var b: Dictionary = beds[i]
	if b["crop"] == "":
		return "empty"
	if b["withered"]:
		return "withered"
	var crop: Dictionary = config.crops.get(b["crop"], {})
	if float(b["growth"]) >= float(crop.get("days", 3)):
		return "ripe"
	return "growing"


func plant(i: int, seed_item: String) -> bool:
	var crop: String = DataDB.item(seed_item).get("seed", "")
	if crop == "" or beds[i]["crop"] != "" or not Inventory.remove(seed_item, 1):
		return false
	beds[i] = _empty_bed()
	beds[i]["crop"] = crop
	beds[i]["watered"] = false
	Tasks.flag("planted")
	changed.emit()
	return true


func water_bed(i: int) -> bool:
	if beds[i]["crop"] == "" or beds[i]["watered"] or bed_state(i) in ["ripe", "withered"]:
		return false
	if can_water <= 0 or Inventory.count("watering_can") <= 0:
		return false
	can_water -= 1
	beds[i]["watered"] = true
	Tasks.flag("watered")
	changed.emit()
	return true


## Erntet ein Beet. Gibt eine Meldung zurück.
func harvest(i: int) -> String:
	var b: Dictionary = beds[i]
	var st := bed_state(i)
	if st == "withered":
		beds[i] = _empty_bed()
		changed.emit()
		return "Die Pflanzen waren vertrocknet. Das Beet ist wieder frei."
	if st != "ripe":
		return ""
	var crop: Dictionary = config.crops.get(b["crop"], {})
	beds[i] = _empty_bed()
	changed.emit()
	if b["alien"]:
		# fremd geworden: graue, kalte Knollen – essbar ist das nicht mehr, aber vielleicht interessant
		if WorldState.stage() >= 2 and Inventory.add("alien_plant", 1) > 0:
			return "Die Ernte ist grau und kalt, wie aus Metall. Eine der Pflanzen hat sich verändert – du nimmst sie mit."
		return "Die Ernte ist grau und kalt, wie aus Metall. Das isst du lieber nicht."
	var y: Array = crop.get("yield", [3, 5])
	var got := Inventory.add(String(crop.get("item", "")), _rng.randi_range(int(y[0]), int(y[1])))
	var seed_item := ""
	var all := DataDB.items()
	for id in all:
		if all[id] is Dictionary and String((all[id] as Dictionary).get("seed", "")) == String(b["crop"]):
			seed_item = id
	var back := _rng.randi_range(config.seeds_back.x, config.seeds_back.y)
	if seed_item != "" and back > 0:
		Inventory.add(seed_item, back)
	Tasks.flag("harvested")
	return "%s geerntet: %d%s" % [crop.get("name", ""), got, (" (+%d Samen)" % back) if back > 0 else ""]


func fill_can(dirty: bool) -> bool:
	if Inventory.count("watering_can") <= 0 or can_water >= config.watering_can_charges:
		return false
	can_water = config.watering_can_charges
	if dirty:
		EventBus.notify("Die Gießkanne ist voll – das Wasser schimmert seltsam.", 2.5)
	changed.emit()
	return true


# --- Übelkeit ---------------------------------------------------------------

func is_sick() -> bool:
	return _hour_abs() < sick_until


## Nach dem Essen/Trinken: mit chance wird einem übel (kurzer Schaden, Hunger/Durst sinken schneller).
func maybe_sick(chance: float, extra_damage: float = 0.0) -> void:
	var p := get_tree().get_first_node_in_group("player") as Player
	if extra_damage > 0.0 and p:
		p.health = maxf(p.health - extra_damage, 1.0)
		EventBus.player_hurt.emit(extra_damage)
	if chance <= 0.0 or _rng.randf() >= chance:
		return
	sick_until = _hour_abs() + config.sick_hours
	if p:
		p.health = maxf(p.health - config.sick_damage, 1.0)
		EventBus.player_hurt.emit(config.sick_damage)
	EventBus.notify("Dir wird übel. Abkochen hätte geholfen.", 3.5)


# --- Generator --------------------------------------------------------------

func service(item: String) -> String:
	if item == "motor_oil" and Inventory.remove("motor_oil", 1):
		generator_condition = minf(generator_condition + config.oil_restore, 100.0)
	elif item == "spark_plug" and Inventory.remove("spark_plug", 1):
		generator_condition = minf(generator_condition + config.plug_restore, 100.0)
	else:
		return ""
	Tasks.flag("generator_serviced")
	changed.emit()
	return "Generator gewartet: Zustand %d %%" % int(generator_condition)


## Springt der Generator beim Startversuch an?
func start_ok() -> bool:
	if generator_condition < config.bad_condition and _rng.randf() < config.bad_start_fail:
		return false
	return true


func condition_text() -> String:
	if generator_condition >= 70.0:
		return "läuft rund"
	if generator_condition >= config.low_condition:
		return "braucht bald Wartung"
	if generator_condition >= config.bad_condition:
		return "stottert – Wartung nötig"
	return "kaum noch fahrbereit"


# --- Metallquellen -------------------------------------------------------------

func _spawn_scrap_spot() -> void:
	var kinds: Array = config.scrap_kinds.keys()
	if kinds.is_empty():
		return
	for attempt in 30:
		var p: Vector3
		if _rng.randf() < config.scrap_near_wreck:
			var a := _rng.randf() * TAU
			p = WRECK + Vector3(cos(a), 0, sin(a)) * _rng.randf_range(6.0, 22.0)
		else:
			p = Vector3(_rng.randf_range(-92.0, 92.0), 0, _rng.randf_range(-92.0, 92.0))
		if Terrain.yard_distance(p.x, p.z) < 8.0 or Terrain.stream_distance(p.x, p.z) < 3.0:
			continue
		if p.distance_to(Vector3(-42, 0, -30)) < 14.0 or p.distance_to(Vector3(-78, 0, 40)) < 16.0:
			continue
		var clash := false
		for s: Dictionary in scrap_spots:
			if Vector2(float(s["x"]) - p.x, float(s["z"]) - p.z).length() < 8.0:
				clash = true
		if clash:
			continue
		scrap_spots.append({"id": _next_spot_id, "kind": kinds[_rng.randi() % kinds.size()], "x": p.x, "z": p.z, "yaw": _rng.randf() * TAU})
		_next_spot_id += 1
		return


## Fundstelle abgebaut: Schrott und evtl. Zündkerze/Öl. Gibt Meldung zurück.
func harvest_spot(id: int) -> String:
	for i in scrap_spots.size():
		var s: Dictionary = scrap_spots[i]
		if int(s["id"]) != id:
			continue
		var k: Dictionary = config.scrap_kinds.get(s["kind"], {})
		var r: Array = k.get("scrap", [2, 3])
		var got := Inventory.add("scrap", _rng.randi_range(int(r[0]), int(r[1])))
		var extra := ""
		if _rng.randf() < float(k.get("plug", 0.0)) and Inventory.add("spark_plug", 1) > 0:
			extra += ", Zündkerze"
		if _rng.randf() < float(k.get("oil", 0.0)) and Inventory.add("motor_oil", 1) > 0:
			extra += ", Motoröl"
		scrap_spots.remove_at(i)
		Tasks.flag("scrap_spot")
		changed.emit()
		return "Metallschrott +%d%s" % [got, extra]
	return ""


# --- Kameras ----------------------------------------------------------------

func camera_installed(index: int) -> bool:
	for c: Dictionary in cameras:
		if int(c["index"]) == index:
			return true
	return false


func install_camera(index: int, pos: Vector3, normal: Vector3, yaw: float) -> void:
	uninstall_camera(index)
	cameras.append({"index": index, "pos": pos, "normal": normal, "yaw": yaw})
	Tasks.flag("camera_installed")
	changed.emit()


func uninstall_camera(index: int) -> void:
	for i in range(cameras.size() - 1, -1, -1):
		if int(cameras[i]["index"]) == index:
			cameras.remove_at(i)
	changed.emit()


# --- Spielstand ---------------------------------------------------------------

func get_state() -> Dictionary:
	return {"beds": beds.duplicate(true), "can": can_water, "sick": sick_until, "gen": generator_condition,
		"gasifier": gasifier, "adapter": cell_adapter, "spots": scrap_spots.duplicate(true), "next_spot": _next_spot_id,
		"cameras": cameras.duplicate(true)}


func set_state(s: Dictionary) -> void:
	if s.is_empty():
		_reset()
		changed.emit()
		return
	beds = (s.get("beds", []) as Array).duplicate(true)
	while beds.size() < BED_COUNT:
		beds.append(_empty_bed())
	can_water = int(s.get("can", 0))
	sick_until = float(s.get("sick", -1.0))
	generator_condition = float(s.get("gen", 85.0))
	gasifier = bool(s.get("gasifier", false))
	cell_adapter = bool(s.get("adapter", false))
	scrap_spots = (s.get("spots", []) as Array).duplicate(true)
	_next_spot_id = int(s.get("next_spot", 1))
	cameras = (s.get("cameras", []) as Array).duplicate(true)
	_last_hour_abs = -1.0
	changed.emit()
