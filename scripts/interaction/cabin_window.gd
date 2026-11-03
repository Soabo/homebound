class_name CabinWindow
extends Interactable
## Fenster mit Rahmen, Sprossen und Glas. Ursprung = Mitte der Unterkante,
## lokales -z zeigt nach innen (GDD 7.3).
##
## Zustände: intakt → gesprungen → zerbrochen. Mit 2 Brettern kann man es
## von innen verbarrikadieren; Kreaturen müssen dann erst die Bretter zerlegen.

@export var width: float = 1.0
@export var height: float = 0.9
@export var wall_thickness: float = 0.25
@export var window_name: String = "Fenster"

var health: float = 60.0
var max_health: float = 60.0
var barricade: float = 0.0
var max_barricade: float = 120.0

var _glass: MeshInstance3D
var _glass_body: StaticBody3D
var _cracks: Node3D
var _shards: Node3D
var _boards: Array[MeshInstance3D] = []
var _board_body: StaticBody3D


func _ready() -> void:
	add_to_group("entry_point")
	var cfg := ThreatDirector.config
	if cfg:
		max_health = cfg.window_health
		max_barricade = cfg.barricade_health
	health = max_health
	var frame := BuildKit.tex_mat("planks_h", 0.6, Color(0.6, 0.55, 0.5))
	var f := 0.07
	var d := wall_thickness + 0.04
	BuildKit.box(self, Vector3(width, f, d), Vector3(0, f * 0.5, 0), frame, false)
	BuildKit.box(self, Vector3(width, f, d), Vector3(0, height - f * 0.5, 0), frame, false)
	BuildKit.box(self, Vector3(f, height, d), Vector3(-width * 0.5 + f * 0.5, height * 0.5, 0), frame, false)
	BuildKit.box(self, Vector3(f, height, d), Vector3(width * 0.5 - f * 0.5, height * 0.5, 0), frame, false)
	BuildKit.box(self, Vector3(0.035, height - f * 2.0, 0.05), Vector3(0, height * 0.5, 0), frame, false)
	BuildKit.box(self, Vector3(width - f * 2.0, 0.035, 0.05), Vector3(0, height * 0.5, 0), frame, false)
	BuildKit.box(self, Vector3(width + 0.12, 0.04, 0.22), Vector3(0, -0.02, -wall_thickness * 0.5 - 0.06),
			BuildKit.tex_mat("planks_h", 0.8), false)

	_glass = BuildKit.box(self, Vector3(width - f * 2.0, height - f * 2.0, 0.012),
			Vector3(0, height * 0.5, 0), BuildKit.glass_mat(), false)
	_glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_glass_body = _make_body(Vector3(width - f * 2.0, height - f * 2.0, 0.05), Vector3(0, height * 0.5, 0))

	# Risse (unsichtbar, bis das Glas beschädigt ist)
	_cracks = Node3D.new()
	add_child(_cracks)
	var crack_mat := BuildKit.color_mat(Color(0.85, 0.9, 0.95), 0.2)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(width * 1000 + height * 100)
	var center := Vector3(rng.randf_range(-width * 0.2, width * 0.2), height * rng.randf_range(0.35, 0.65), 0.008)
	for i in 9:
		var a := TAU * float(i) / 9.0 + rng.randf_range(-0.2, 0.2)
		var l := rng.randf_range(0.15, minf(width, height) * 0.5)
		var line := BuildKit.box(_cracks, Vector3(l, 0.006, 0.004), center + Vector3(cos(a), sin(a), 0) * l * 0.5, crack_mat, false, Vector3(0, 0, rad_to_deg(a)))
		line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_cracks.visible = false

	# Scherben auf der Fensterbank
	_shards = Node3D.new()
	add_child(_shards)
	for i in 7:
		BuildKit.box(_shards, Vector3(rng.randf_range(0.04, 0.12), 0.004, rng.randf_range(0.03, 0.08)),
				Vector3(rng.randf_range(-width * 0.4, width * 0.4), 0.005, -wall_thickness * 0.5 - rng.randf_range(0.0, 0.12)),
				BuildKit.glass_mat(), false, Vector3(0, rng.randf() * 180.0, 0))
	_shards.visible = false

	# Bretter der Barrikade (innen)
	var board_mat := BuildKit.tex_mat("planks_h", 1.0, Color(1.2, 1.15, 1.0))
	for i in 3:
		var y := height * (0.22 + i * 0.28)
		var b := BuildKit.box(self, Vector3(width + 0.25, 0.16, 0.035), Vector3(0, y, -wall_thickness * 0.5 - 0.05),
				board_mat, false, Vector3(0, 0, rng.randf_range(-9, 9)))
		b.visible = false
		_boards.append(b)
	_board_body = _make_body(Vector3(width + 0.2, height, 0.06), Vector3(0, height * 0.5, -wall_thickness * 0.5 - 0.05))
	_set_body(_board_body, false)

	# Unsichtbare Fläche zum Anvisieren (auch wenn das Glas weg ist)
	var aim := Area3D.new()
	var acs := CollisionShape3D.new()
	var ashape := BoxShape3D.new()
	ashape.size = Vector3(width, height, wall_thickness + 0.1)
	acs.shape = ashape
	acs.position = Vector3(0, height * 0.5, 0)
	aim.add_child(acs)
	add_child(aim)
	_update_visuals()


func _make_body(size: Vector3, pos: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	cs.position = pos
	body.add_child(cs)
	add_child(body)
	return body


func _set_body(body: StaticBody3D, enabled: bool) -> void:
	for c in body.get_children():
		(c as CollisionShape3D).set_deferred("disabled", not enabled)


# --- Interaktion --------------------------------------------------------

func get_prompt(_player: Node) -> String:
	var state := "intakt"
	if health <= 0.0:
		state = "zerbrochen"
	elif health < max_health:
		state = "gesprungen"
	if barricade > 0.0:
		state += ", verbarrikadiert (%d%%)" % int(barricade / max_barricade * 100.0)
	return "%s – %s" % [window_name, state]


func get_secondary_prompt(_player: Node) -> String:
	if barricade <= 0.0:
		return "[R] Verbarrikadieren  (2 Bretter, du hast %d)" % Inventory.count("planks")
	if barricade < max_barricade:
		return "[R] Barrikade ausbessern  (1 Brett, du hast %d)" % Inventory.count("planks")
	return ""


func secondary_interact(_player: Node) -> void:
	var need := 2 if barricade <= 0.0 else 1
	if barricade >= max_barricade:
		return
	if not Inventory.remove("planks", need):
		EventBus.notify("Du brauchst %d Bretter. In der Werkstatt liegt ein Stapel." % need, 3.0)
		return
	barricade = max_barricade if need == 2 else minf(barricade + max_barricade * 0.5, max_barricade)
	SoundBank.play_at(self, "hammer", global_position + Vector3(0, height * 0.5, 0), -2.0)
	EventBus.noise_made.emit(global_position, 12.0)
	_update_visuals()


# --- Zugang für Kreaturen ----------------------------------------------

func entry_name() -> String:
	return name


## Wo eine Kreatur draußen vor dem Fenster steht.
func outside_point() -> Vector3:
	return to_global(Vector3(0, 0, 0.75))


func inside_point() -> Vector3:
	return to_global(Vector3(0, 0, -0.9))


func is_breached() -> bool:
	return health <= 0.0 and barricade <= 0.0


func strength() -> float:
	return maxf(health, 0.0) + barricade


func receive_hit(damage: float) -> void:
	var pos := global_position + Vector3(0, height * 0.5, 0)
	if health > 0.0:
		var before := health
		health = maxf(health - damage, 0.0)
		if health <= 0.0:
			SoundBank.play_at(self, "glass_break", pos, 2.0)
			EventBus.noise_made.emit(pos, 25.0)
		elif before >= max_health:
			SoundBank.play_at(self, "glass_crack", pos, 0.0)
		else:
			SoundBank.play_at(self, "knock", pos, -2.0, 1.3)
	elif barricade > 0.0:
		barricade = maxf(barricade - damage, 0.0)
		SoundBank.play_at(self, "wood_crack", pos, 0.0, randf_range(0.8, 1.1))
		if barricade <= 0.0:
			SoundBank.play_at(self, "bang", pos, 0.0, 0.8)
	_update_visuals()


func _update_visuals() -> void:
	_glass.visible = health > 0.0
	_set_body(_glass_body, health > 0.0)
	_cracks.visible = health > 0.0 and health < max_health
	_shards.visible = health <= 0.0
	var boards := 0
	if barricade > 0.0:
		boards = clampi(int(ceil(barricade / max_barricade * 3.0)), 1, 3)
	for i in _boards.size():
		_boards[i].visible = i < boards
	_set_body(_board_body, barricade > 0.0)
