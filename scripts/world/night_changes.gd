class_name NightChanges
extends Node3D
## Nach Nächten mit Alien-Aktivität ist draußen morgens etwas anders (Christians Wunsch).
## Kleine, unheimliche Veränderungen, die nach ein paar Tagen ebenso still wieder verschwinden.
## WANN etwas passiert, entscheidet der Threat Director (ThreatConfig: night_change_*);
## hier steht, WAS sich verändert. Zustand ist Teil des Spielstands.
##
## Arten:
##  towels_gone     – Handtücher an der Wäscheleine fehlen
##  towel_extra     – ein fremdes, verdrecktes Handtuch hängt dazwischen
##  bench_moved     – die Bank von der Veranda steht mitten im Garten und schaut zum Wald (oder zum Fenster)
##  fence_hole      – ein Zaunfeld ist herausgebrochen, die Stangen liegen im Gras
##  cairn           – eine Säule aus aufgeschichteten Flusssteinen steht in der Wiese
##  scarecrow       – die Vogelscheuche schaut zum Haus
##  shed_door       – die Schuppentür steht offen
##  log_circle      – Holzscheite liegen in einem exakten Kreis auf der Wiese
##  car_lights      – ein Scheinwerfer des Autowracks glimmt
##  stone_line      – eine Linie aus Flusssteinen führt vom Waldrand bis an die Veranda
##  shoes           – ein Paar alte Stiefel steht ordentlich vor der Haustür, Spitzen zur Tür

const KINDS := ["towels_gone", "towel_extra", "bench_moved", "fence_hole", "cairn", "scarecrow", "shed_door",
		"log_circle", "car_lights", "stone_line", "shoes"]
## Ursprüngliche Mitte der Verandabank (Hüttenkoordinaten, Beine stehen auf dem Verandaboden)
const BENCH_CENTER := Vector3(-0.45, Cabin.FLOOR_Y, 5.0)

## [{"kind": String, "until": int, ...Parameter}]
var active: Array = []
var _rng := RandomNumberGenerator.new()
var _visuals: Dictionary = {}  ## kind -> Node3D


func _ready() -> void:
	name = "NightChanges"
	add_to_group("night_changes")
	add_to_group("persistent")
	_rng.randomize()
	GameState.restore(self)


## Morgens nach einer unruhigen Nacht vom Threat Director aufgerufen.
func morning(count: int, days: Vector2i) -> void:
	_expire()
	var free := KINDS.filter(func(k: String) -> bool: return not _has(k))
	free.shuffle()
	for i in mini(count, free.size()):
		var c := _make(free[i], days)
		if not c.is_empty():
			active.append(c)
			_apply(c)


## Abgelaufene Veränderungen still zurücknehmen.
func _expire() -> void:
	var keep: Array = []
	for c: Dictionary in active:
		if int(c["until"]) <= TimeManager.day:
			_revert(c)
		else:
			keep.append(c)
	active = keep


func _has(kind: String) -> bool:
	for c: Dictionary in active:
		if c["kind"] == kind:
			return true
	return false


## Neue Veränderung mit zufälligen Werten (Positionen etc. werden mitgespeichert).
func _make(kind: String, days: Vector2i) -> Dictionary:
	var c := {"kind": kind, "until": TimeManager.day + _rng.randi_range(days.x, days.y)}
	match kind:
		"towels_gone":
			var idx := [0, 1, 2]
			idx.shuffle()
			c["hide"] = idx.slice(0, _rng.randi_range(1, 3))
		"towel_extra":
			c["x"] = _rng.randf_range(-11.4, -5.8)
		"bench_moved":
			var spots := [Vector3(-6.0, 0, 13.0), Vector3(5.0, 0, 12.5), Vector3(-14.0, 0, 0.0), Vector3(-9.0, 0, -12.0), Vector3(9.0, 0, -10.0)]
			var p: Vector3 = spots[_rng.randi() % spots.size()]
			c["x"] = p.x
			c["z"] = p.z
			# Blick: zum Wald (vom Haus weg) oder genau auf ein Fenster
			var away := Vector2(p.x, p.z).normalized()
			c["yaw"] = atan2(away.x, away.y) if _rng.randf() < 0.5 else atan2(-away.x, -away.y)
		"fence_hole":
			var segs := get_tree().get_nodes_in_group("fence_segment")
			if segs.is_empty():
				return {}
			c["seg"] = String(segs[_rng.randi() % segs.size()].name)
		"cairn":
			# freie Wiesenstellen (nicht auf Beeten, Weg oder im Mais)
			var spots := [Vector3(-6.0, 0, -12.0), Vector3(4.0, 0, -13.0), Vector3(-17.0, 0, -4.0), Vector3(-16.0, 0, 14.0),
					Vector3(-8.0, 0, 14.5), Vector3(18.0, 0, -12.0), Vector3(-17.5, 0, 2.5)]
			var p: Vector3 = spots[_rng.randi() % spots.size()]
			c["x"] = p.x + _rng.randf_range(-0.8, 0.8)
			c["z"] = p.z + _rng.randf_range(-0.8, 0.8)
			c["n"] = _rng.randi_range(6, 10)
			c["seed"] = _rng.randi()
		"log_circle":
			var spots := [Vector3(-8.0, 0, 11.0), Vector3(8.0, 0, -9.0), Vector3(-13.0, 0, -6.0), Vector3(3.0, 0, 13.0)]
			var p: Vector3 = spots[_rng.randi() % spots.size()]
			c["x"] = p.x
			c["z"] = p.z
		"stone_line":
			var a := _rng.randf_range(0.6, 2.5)  # irgendwo südlich, Richtung Veranda
			c["x"] = cos(a) * 19.0
			c["z"] = sin(a) * 19.0
		"shed_door":
			pass
	return c


func _scene() -> Node:
	return get_tree().current_scene


func _apply(c: Dictionary) -> void:
	var scene := _scene()
	var kind: String = c["kind"]
	match kind:
		"towels_gone":
			for i: int in c["hide"]:
				var t := scene.get_node_or_null("Garden/Towels/Towel_%d" % i) as Node3D
				if t:
					t.visible = false
		"towel_extra":
			var v := _holder(kind)
			var cloth := BuildKit.tex_mat("fabric", 0.4, Color(0.55, 0.5, 0.42))
			var t := BuildKit.box(v, Vector3(0.55, 0.9, 0.01), Vector3(float(c["x"]), 1.5, -9.0), cloth, false, Vector3(0, 0, 3))
			# dunkle Flecken
			for k in 4:
				BuildKit.box(t, Vector3(0.12, 0.1, 0.012), Vector3(_rng.randf_range(-0.2, 0.2), _rng.randf_range(-0.35, 0.3), 0), BuildKit.color_mat(Color(0.14, 0.11, 0.09)), false)
		"bench_moved":
			var bench := scene.get_node_or_null("Cabin/PorchBench") as Node3D
			if bench:
				var p := Vector3(float(c["x"]), 0, float(c["z"]))
				p.y = Terrain.height_at(p.x, p.z)
				bench.transform = Transform3D(Basis(Vector3.UP, float(c["yaw"])), p) * Transform3D(Basis(), -BENCH_CENTER)
		"fence_hole":
			var seg := scene.get_node_or_null("Garden/" + String(c["seg"])) as Node3D
			if seg:
				_set_active(seg, false)
				var v := _holder(kind)
				var center: Vector3 = seg.get_meta("center", seg.global_position)
				var along_x: bool = seg.get_meta("along_x", true)
				var rail := BuildKit.tex_mat("logs", 0.6)
				for k in 2:
					var off := Vector3(0, 0, 0.8 + k * 0.5) if along_x else Vector3(0.8 + k * 0.5, 0, 0)
					var p := center + off * (1.0 if _rng.randf() < 0.5 else -1.0)
					p.y = Terrain.height_at(p.x, p.z) + 0.05
					BuildKit.cylinder(v, 0.05, 1.3 + k * 0.4, p, rail, false, Vector3(90, _rng.randf() * 180.0, 0), -1.0, 6)
				# Splitter am Rand
				for k in 6:
					var p := center + Vector3(_rng.randf_range(-1.2, 1.2), 0, _rng.randf_range(-0.6, 0.6))
					p.y = Terrain.height_at(p.x, p.z) + 0.02
					BuildKit.box(v, Vector3(0.18, 0.02, 0.04), p, rail, false, Vector3(0, _rng.randf() * 180.0, 0))
		"cairn":
			var v := _holder(kind)
			var r := RandomNumberGenerator.new()
			r.seed = int(c["seed"])
			var stone := BuildKit.tex_mat("rock", 0.4, Color(0.95, 0.95, 0.92))
			var base := Vector3(float(c["x"]), 0, float(c["z"]))
			var y := Terrain.height_at(base.x, base.z)
			for k in int(c["n"]):
				var s := lerpf(0.28, 0.12, float(k) / float(c["n"]))
				var h := s * r.randf_range(0.45, 0.6)
				BuildKit.sphere(v, s, base + Vector3(r.randf_range(-0.02, 0.02), y + h * 0.9, r.randf_range(-0.02, 0.02)), stone, Vector3(1.0, 0.5, 0.9), 9)
				y += h * 1.7
		"scarecrow":
			var sc := scene.get_node_or_null("CornField/Scarecrow") as Node3D
			if sc:
				c["old_yaw"] = sc.rotation.y
				var to := -sc.global_position
				sc.rotation.y = atan2(to.x, to.z)
		"shed_door":
			var door := scene.get_node_or_null("Shed/ShedDoor") as Door
			if door and not door.is_open:
				door.is_locked = false
				door.set_open(true, true)
		"log_circle":
			var v := _holder(kind)
			var logs := BuildKit.tex_mat("logs", 0.6)
			var center := Vector3(float(c["x"]), 0, float(c["z"]))
			for k in 12:
				var a := TAU * k / 12.0
				var p := center + Vector3(cos(a), 0, sin(a)) * 1.8
				p.y = Terrain.height_at(p.x, p.z) + 0.09
				BuildKit.cylinder(v, 0.09, 0.7, p, logs, false, Vector3(90, -rad_to_deg(a), 0), -1.0, 7)
		"car_lights":
			var car := scene.get_node_or_null("CarWreck") as Node3D
			if car:
				var v := _holder(kind)
				v.reparent(car, false)
				v.position = Vector3(2.5, 0.92, 0.75)
				var l := OmniLight3D.new()
				l.light_color = Color(1.0, 0.85, 0.6)
				l.light_energy = 0.8
				l.omni_range = 4.0
				v.add_child(l)
				BuildKit.sphere(v, 0.075, Vector3(-0.15, 0, 0), BuildKit.emissive_mat(Color(1.0, 0.85, 0.55), 2.5), Vector3(0.4, 1, 1), 10)
		"stone_line":
			var v := _holder(kind)
			var stone := BuildKit.tex_mat("rock", 0.4, Color(0.9, 0.9, 0.88))
			var from := Vector3(float(c["x"]), 0, float(c["z"]))
			var to := Vector3(-3.0, 0, 7.8)
			var n := int(from.distance_to(to) / 0.7)
			for k in n:
				var p := from.lerp(to, float(k) / float(n))
				p.y = Terrain.height_at(p.x, p.z) + 0.03
				BuildKit.sphere(v, 0.09, p, stone, Vector3(1.2, 0.5, 1.0), 7)
		"shoes":
			var v := _holder(kind)
			var leather := BuildKit.color_mat(Color(0.18, 0.12, 0.08), 0.8)
			for side: float in [-1.0, 1.0]:
				var p := Vector3(-3.0 + side * 0.13, Cabin.FLOOR_Y, 5.25)
				BuildKit.box(v, Vector3(0.11, 0.07, 0.28), p + Vector3(0, 0.035, 0), leather, false)
				BuildKit.box(v, Vector3(0.1, 0.22, 0.11), p + Vector3(0, 0.15, 0.08), leather, false)
				BuildKit.box(v, Vector3(0.12, 0.02, 0.3), p + Vector3(0, 0.005, 0), BuildKit.color_mat(Color(0.06, 0.05, 0.05)), false)


func _revert(c: Dictionary) -> void:
	var scene := _scene()
	match String(c["kind"]):
		"towels_gone":
			for i: int in c["hide"]:
				var t := scene.get_node_or_null("Garden/Towels/Towel_%d" % i) as Node3D
				if t:
					t.visible = true
		"bench_moved":
			var bench := scene.get_node_or_null("Cabin/PorchBench") as Node3D
			if bench:
				bench.transform = Transform3D()
		"fence_hole":
			var seg := scene.get_node_or_null("Garden/" + String(c["seg"])) as Node3D
			if seg:
				_set_active(seg, true)
		"scarecrow":
			var sc := scene.get_node_or_null("CornField/Scarecrow") as Node3D
			if sc and c.has("old_yaw"):
				sc.rotation.y = float(c["old_yaw"])
	var kind := String(c["kind"])
	if _visuals.has(kind) and is_instance_valid(_visuals[kind]):
		(_visuals[kind] as Node).queue_free()
	_visuals.erase(kind)


func _holder(kind: String) -> Node3D:
	var v := Node3D.new()
	v.name = "Change_" + kind
	add_child(v)
	_visuals[kind] = v
	return v


## Sichtbar + fest (true) oder unsichtbar + durchlässig (false).
func _set_active(n: Node3D, on: bool) -> void:
	n.visible = on
	for cs in n.find_children("*", "CollisionShape3D", true, false):
		(cs as CollisionShape3D).set_deferred("disabled", not on)


# --- Spielstand ---------------------------------------------------------

func persist_key() -> String:
	return "night_changes"


func get_state() -> Dictionary:
	return {"active": active.duplicate(true)}


func set_state(s: Dictionary) -> void:
	for c: Dictionary in active:
		_revert(c)
	active = (s.get("active", []) as Array).duplicate(true)
	# nach dem Laden erst anwenden, wenn die ganze Welt steht
	_reapply.call_deferred()


func _reapply() -> void:
	for c: Dictionary in active:
		_apply(c)
