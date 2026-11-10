extends Node
## World State Manager (GDD 3.6 / 17.2): verwaltet, wie sehr die Aliens das Tal verändern.
##
## Terraforming-Wert wächst mit jedem Tag und mit dem Forschungsfortschritt (Entscheidung Phase 8).
## Daraus ergeben sich Stufen:
##   0 normal · 1 Stille, Pilzringe · 2 fremde Pflanzen, Nebel gegen den Wind, kahle Bäume
##   3 verfärbtes Wasser (Filter nötig) · 4 schwebende Steine, Adern im Boden
## Außerdem: Wucherungen des Organismus (Quelle in der Höhle), Zustand der fremden Struktur.

signal changed
signal stage_changed(stage: int)

const CONFIG_PATH := "res://data/world/world_state.tres"
const STAGE_MESSAGES := {
	1: "Heute Morgen ist es seltsam still im Wald. Kaum ein Vogel ist zu hören.",
	2: "Nebel zieht gegen den Wind durchs Tal. Im Wald wachsen Pflanzen, die du nie gesehen hast.",
	3: "Das Wasser im Bach hat sich verfärbt. Ohne Filter solltest du es nicht mehr trinken.",
	4: "Bei der fremden Struktur schweben Steine in der Luft. Das Tal verändert sich grundlegend.",
}
## Organismus: wächst von der Höhle am Bach Richtung Hütte
const CAVE := Vector3(49.0, 0.0, -72.0)

## Tempo und Wachstum: data/world/world_state.tres
var config: WorldConfig

var structure_off: bool = false
var pylons_off: Array = []
var source_alive: bool = true
var patches: Array = []          ## [{"id": int, "x": float, "z": float}]
var next_patch_id: int = 0
var drone_part_dropped: bool = false
var last_stage: int = 0
var spread_day: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	config = load(CONFIG_PATH) as WorldConfig
	if config == null:
		config = WorldConfig.new()
	TimeManager.day_changed.connect(_on_day_changed)
	Research.changed.connect(_check_stage)


## Terraforming-Wert: ~0.13 pro Tag (halb so viel, wenn die Struktur abgeschaltet ist) + Forschung.
func level() -> float:
	var days := float(maxi(TimeManager.day - 1, 0)) * config.level_per_day * (config.structure_off_factor if structure_off else 1.0)
	return days + config.level_per_analysis * Research.done.size() + config.level_per_link * Research.links_done.size()


func stage() -> int:
	var l := level()
	var s := 0
	for t: float in config.stage_thresholds:
		if l >= t:
			s += 1
	return s


func water_contaminated() -> bool:
	return stage() >= config.water_stage


func _check_stage() -> void:
	var s := stage()
	if s != last_stage:
		var up := s > last_stage
		last_stage = s
		if up and STAGE_MESSAGES.has(s):
			EventBus.notify(STAGE_MESSAGES[s], 7.0)
		stage_changed.emit(s)
		changed.emit()


func _on_day_changed(_day: int) -> void:
	_check_stage()
	_spread_organism()


## Die Wucherung wächst unberechenbar (ab Stufe 2, solange die Quelle lebt):
##  - mal gar nicht, mal ein, mal zwei Stücke pro Tag
##  - verzweigt sich: wächst von irgendeiner Spitze aus weiter, nicht stur geradeaus
##  - hat wechselnde Ziele: Hütte, Schuppen, Regentonne, Bach, Maisfeld
##  - ab Stufe 3 springt sie manchmal (Sporen): eine neue Stelle taucht weit entfernt auf


func _spread_organism() -> void:
	if not source_alive or stage() < config.spread_from_stage or spread_day == TimeManager.day:
		return
	spread_day = TimeManager.day
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var per_day := config.spread_per_day
	var count: int = (per_day[rng.randi() % per_day.size()] if not per_day.is_empty() else 1) \
			+ (1 if stage() >= 3 and rng.randf() < config.extra_spread_chance else 0)
	var grown := 0
	for i in count:
		for attempt in 5:
			var origin := CAVE
			if not patches.is_empty() and rng.randf() < config.branch_chance:
				var tip: Dictionary = patches[rng.randi() % patches.size()]
				origin = Vector3(float(tip["x"]), 0, float(tip["z"]))
			var goal: Vector3 = config.spread_goals[rng.randi() % config.spread_goals.size()]
			var dir := goal - origin
			dir.y = 0.0
			if dir.length() < 3.0:
				continue
			dir = dir.normalized().rotated(Vector3.UP, rng.randf_range(-config.direction_jitter, config.direction_jitter))
			var p := origin + dir * rng.randf_range(config.step_length.x, config.step_length.y)
			if _patch_ok(p):
				_add_patch(p)
				grown += 1
				break
	# Sporensprung: plötzlich wächst etwas ganz woanders
	if stage() >= config.spore_from_stage and rng.randf() < config.spore_chance:
		for attempt in 5:
			var a := rng.randf() * TAU
			var p := Vector3(cos(a), 0, sin(a)) * rng.randf_range(config.spore_distance.x, config.spore_distance.y)
			if _patch_ok(p):
				_add_patch(p)
				grown += 1
				break
	if grown > 0:
		EventBus.notify("Über Nacht hat sich etwas Graues weiter ausgebreitet …", 4.0)
	changed.emit()


func _patch_ok(p: Vector3) -> bool:
	if absf(p.x) < 7.5 and absf(p.z) < 6.0:
		return false  # nicht in der Hütte
	if Shed.is_inside(p) or Vector2(p.x, p.z).length() > 100.0 or _blocked_by_barrier(p):
		return false
	for q: Dictionary in patches:
		if Vector2(float(q["x"]) - p.x, float(q["z"]) - p.z).length() < config.patch_spacing:
			return false
	return true


## Neue Wucherung in der Nähe eines Punktes (z. B. Ausbruch im Labor). true = hat geklappt.
func spawn_patch_near(center: Vector3) -> bool:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in 16:
		var p := center + Vector3(rng.randf_range(-3.0, 3.0), 0, rng.randf_range(-2.5, 2.5)) * (1.0 + i * 0.15)
		if _patch_ok(p):
			_add_patch(p)
			changed.emit()
			return true
	return false


func _add_patch(p: Vector3) -> void:
	patches.append({"id": next_patch_id, "x": p.x, "z": p.z})
	next_patch_id += 1


func _blocked_by_barrier(p: Vector3) -> bool:
	for b in get_tree().get_nodes_in_group("growth_barrier"):
		if (b as Node3D).global_position.distance_to(Vector3(p.x, (b as Node3D).global_position.y, p.z)) < config.barrier_range:
			return true
	return false


func remove_patch(id: int) -> void:
	for i in patches.size():
		if int(patches[i]["id"]) == id:
			patches.remove_at(i)
			changed.emit()
			return


func kill_source() -> void:
	if not source_alive:
		return
	source_alive = false
	EventBus.notify("Der Knoten fällt in sich zusammen. Die Wucherungen werden nicht weiter wachsen.", 5.0)
	changed.emit()


func set_pylon_off(index: int) -> void:
	if not pylons_off.has(index):
		pylons_off.append(index)
		changed.emit()


func reset_pylons() -> void:
	pylons_off.clear()
	changed.emit()


func shut_down_structure() -> void:
	if structure_off:
		return
	structure_off = true
	EventBus.notify("Die Struktur verstummt. Das Summen im Boden wird schwächer – das Tal verändert sich langsamer.", 6.0)
	_check_stage()
	changed.emit()


func get_state() -> Dictionary:
	return {"structure_off": structure_off, "pylons_off": pylons_off.duplicate(), "source_alive": source_alive,
		"patches": patches.duplicate(true), "next_patch_id": next_patch_id, "drone_part": drone_part_dropped,
		"last_stage": last_stage, "spread_day": spread_day}


func set_state(s: Dictionary) -> void:
	structure_off = bool(s.get("structure_off", false))
	pylons_off = (s.get("pylons_off", []) as Array).duplicate()
	source_alive = bool(s.get("source_alive", true))
	patches = (s.get("patches", []) as Array).duplicate(true)
	next_patch_id = int(s.get("next_patch_id", 0))
	drone_part_dropped = bool(s.get("drone_part", false))
	last_stage = int(s.get("last_stage", 0))
	spread_day = int(s.get("spread_day", 0))
	changed.emit()
