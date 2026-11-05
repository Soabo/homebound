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

const STAGE_THRESHOLDS := [0.2, 0.45, 0.7, 1.0]
const STAGE_MESSAGES := {
	1: "Heute Morgen ist es seltsam still im Wald. Kaum ein Vogel ist zu hören.",
	2: "Nebel zieht gegen den Wind durchs Tal. Im Wald wachsen Pflanzen, die du nie gesehen hast.",
	3: "Das Wasser im Bach hat sich verfärbt. Ohne Filter solltest du es nicht mehr trinken.",
	4: "Bei der fremden Struktur schweben Steine in der Luft. Das Tal verändert sich grundlegend.",
}
## Organismus: wächst von der Höhle am Bach Richtung Hütte
const CAVE := Vector3(49.0, 0.0, -72.0)
const SPREAD_TARGET := Vector3(6.0, 0.0, -10.0)
const PATCH_STEP := 7.0

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
	TimeManager.day_changed.connect(_on_day_changed)
	Research.changed.connect(_check_stage)


## Terraforming-Wert: ~0.13 pro Tag (halb so viel, wenn die Struktur abgeschaltet ist) + Forschung.
func level() -> float:
	var days := float(maxi(TimeManager.day - 1, 0)) * 0.13 * (0.5 if structure_off else 1.0)
	return days + 0.04 * Research.done.size() + 0.07 * Research.links_done.size()


func stage() -> int:
	var l := level()
	var s := 0
	for t: float in STAGE_THRESHOLDS:
		if l >= t:
			s += 1
	return s


func water_contaminated() -> bool:
	return stage() >= 3


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


## Jeden Tag wächst die Wucherung ein Stück weiter Richtung Hütte (ab Stufe 2, solange die Quelle lebt).
func _spread_organism() -> void:
	if not source_alive or stage() < 2 or spread_day == TimeManager.day:
		return
	spread_day = TimeManager.day
	var count := 1 + (1 if stage() >= 3 else 0)
	for i in count:
		var n := patches.size()
		var dir := (SPREAD_TARGET - CAVE)
		dir.y = 0.0
		var dist := minf(8.0 + n * PATCH_STEP * 0.6, dir.length() - 4.0)
		var side := Vector3(-dir.z, 0, dir.x).normalized() * (sin(float(n) * 1.7) * 3.5)
		var p := CAVE + dir.normalized() * dist + side
		if _blocked_by_barrier(p):
			continue
		patches.append({"id": next_patch_id, "x": p.x, "z": p.z})
		next_patch_id += 1
	if count > 0:
		EventBus.notify("Etwas Graues wuchert vom Bach her durch den Wald …", 4.0)
	changed.emit()


func _blocked_by_barrier(p: Vector3) -> bool:
	for b in get_tree().get_nodes_in_group("growth_barrier"):
		if (b as Node3D).global_position.distance_to(Vector3(p.x, (b as Node3D).global_position.y, p.z)) < 15.0:
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
