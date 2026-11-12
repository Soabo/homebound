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
var _jagged: MeshInstance3D  ## Glaszacken, die nach dem Zerbrechen im Rahmen stecken bleiben
var _boards: Array[MeshInstance3D] = []
var _board_body: StaticBody3D
var _handprints: int = 0


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

	_jagged = _build_jagged(rng, f)
	_jagged.visible = false
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
	add_to_group("persistent")
	GameState.restore(self)
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
	if barricade <= 0.0 and not Research.blueprints.has("bp_secure"):
		return ""   # erst nach der ersten unruhigen Nacht (Christian)
	if barricade <= 0.0:
		return "[R] Verbarrikadieren  (2 Bretter + 4 Nägel – du hast %d / %d)" % [Inventory.count("planks"), Inventory.count("nails")]
	if barricade < max_barricade:
		return "[R] Barrikade ausbessern  (1 Brett + 2 Nägel)"
	return ""


func secondary_interact(_player: Node) -> void:
	var need := 2 if barricade <= 0.0 else 1
	if barricade <= 0.0 and not Research.blueprints.has("bp_secure"):
		return
	if barricade >= max_barricade:
		return
	if not Inventory.remove_all({"planks": need, "nails": need * 2}):
		EventBus.notify("Du brauchst %d Bretter und %d Nägel. Beides gibt es in der Werkstatt." % [need, need * 2], 3.0)
		return
	barricade = max_barricade if need == 2 else minf(barricade + max_barricade * 0.5, max_barricade)
	Tasks.flag("barricaded")
	SoundBank.hammer_series(self, global_position + Vector3(0, height * 0.5, 0), 4 if need == 2 else 3)
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
	var pl := get_tree().get_first_node_in_group("player") as Node3D
	if pl and pl.global_position.distance_to(global_position) < 7.0:
		EventBus.screen_shake.emit(0.3)
	var pos := global_position + Vector3(0, height * 0.5, 0)
	if health > 0.0:
		var before := health
		health = maxf(health - damage, 0.0)
		if health <= 0.0:
			SoundBank.play_at(self, "glass_break", pos, 6.0)
			Fx.burst(get_tree().current_scene, pos, "glass", -global_transform.basis.z, 1.5)
			# Scherben rieseln nach
			get_tree().create_timer(0.35).timeout.connect(func() -> void:
				if is_inside_tree():
					SoundBank.play_at(self, "glass_crack", pos + Vector3(0, -0.4, 0), -4.0, 1.4))
			EventBus.noise_made.emit(pos, 25.0)
		elif before >= max_health:
			SoundBank.play_at(self, "glass_crack", pos, 0.0)
		else:
			SoundBank.play_at(self, "knock", pos, -2.0, 1.3)
	elif barricade > 0.0:
		barricade = maxf(barricade - damage, 0.0)
		SoundBank.play_at(self, "plank_break", pos, 0.0)
		Fx.burst(get_tree().current_scene, pos, "wood", -global_transform.basis.z)
		if barricade <= 0.0:
			SoundBank.play_at(self, "fence_break", pos, 2.0)
	_update_visuals()


## Spitze Glasreste an den Rändern jeder der vier Scheiben (Dreiecke, Basis am Rahmen, Spitze nach innen).
func _build_jagged(rng: RandomNumberGenerator, f: float) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half_w := width * 0.5 - f
	var bar := 0.0175
	var panes := [
		[Vector2(-half_w, f), Vector2(-bar, height * 0.5 - bar)], [Vector2(bar, f), Vector2(half_w, height * 0.5 - bar)],
		[Vector2(-half_w, height * 0.5 + bar), Vector2(-bar, height - f)], [Vector2(bar, height * 0.5 + bar), Vector2(half_w, height - f)]]
	for pane: Array in panes:
		var lo: Vector2 = pane[0]
		var hi: Vector2 = pane[1]
		var corners := [lo, Vector2(hi.x, lo.y), hi, Vector2(lo.x, hi.y)]
		var center := (lo + hi) * 0.5
		for e in 4:
			var a: Vector2 = corners[e]
			var b: Vector2 = corners[(e + 1) % 4]
			var t := 0.0
			while t < 0.98:
				var t2 := minf(t + rng.randf_range(0.18, 0.4), 1.0)
				var p0 := a.lerp(b, t)
				var p1 := a.lerp(b, t2)
				var mid := p0.lerp(p1, rng.randf_range(0.3, 0.7))
				var tip := mid + (center - mid).normalized() * rng.randf_range(0.03, 0.16)
				if rng.randf() < 0.8:
					for v: Vector2 in [p0, p1, tip]:
						st.set_normal(Vector3(0, 0, 1))
						st.add_vertex(Vector3(v.x, v.y, 0.0))
				t = t2
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.7, 0.8, 0.85, 0.35)
	m.roughness = 0.1
	m.metallic_specular = 0.5
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


func _update_visuals() -> void:
	_glass.visible = health > 0.0
	_jagged.visible = health <= 0.0
	_set_body(_glass_body, health > 0.0)
	_cracks.visible = health > 0.0 and health < max_health
	_shards.visible = health <= 0.0
	var boards := 0
	if barricade > 0.0:
		boards = clampi(int(ceil(barricade / max_barricade * 3.0)), 1, 3)
	for i in _boards.size():
		_boards[i].visible = i < boards
	_set_body(_board_body, barricade > 0.0)


## Abdruck einer dreifingrigen, langen Hand außen auf dem Glas (GDD 7.5 / Phase 5).
func add_handprint() -> void:
	if health <= 0.0 or _handprints >= 3:
		return
	_handprints += 1
	var mat := BuildKit.color_mat(Color(0.8, 0.85, 0.82), 0.3)
	var hand := Node3D.new()
	hand.position = Vector3(randf_range(-width * 0.25, width * 0.25), height * randf_range(0.35, 0.6), 0.012)
	hand.rotation_degrees.z = randf_range(-20, 20)
	_glass.add_child(hand)
	hand.position -= Vector3(0, height * 0.5, 0)
	BuildKit.box(hand, Vector3(0.07, 0.09, 0.002), Vector3.ZERO, mat, false)
	for f in 3:
		var finger := BuildKit.box(hand, Vector3(0.016, 0.16, 0.002), Vector3((f - 1) * 0.026, 0.12, 0), mat, false, Vector3(0, 0, (f - 1) * -9.0))
		finger.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func persist_key() -> String:
	return str(get_path())


func get_state() -> Dictionary:
	return {"health": health, "barricade": barricade}


func set_state(s: Dictionary) -> void:
	health = float(s.get("health", health))
	barricade = float(s.get("barricade", barricade))
