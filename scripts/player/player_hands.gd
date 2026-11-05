class_name PlayerHands
extends Node3D
## Die Hände des Spielers im Bild (hängt an der Kamera).
##
## Rechte Hand: was auf dem gewählten Schnellplatz (1–9) liegt – Axt, Konserve, Wasserflasche –
## oder die Faust, wenn der Platz leer ist. Linksklick = Angriff / Benutzen, Rechtsklick = Blocken.
## Linke Hand: Smartwatch mit LED als Taschenlampe (F) und der Bauhammer im Baumodus (B).
## Beide Hände schwingen beim Umsehen verzögert nach; beim Wechsel taucht der alte Gegenstand
## nach unten ab und der neue kommt von unten.

const RIGHT_REST := Vector3(0.21, -0.2, -0.36)
const LEFT_REST := Vector3(-0.2, -0.2, -0.33)
const HIDE_DROP := 0.5
const SWITCH_SPEED := 6.5

## Faust und Axt: Reichweite, Stärke (verscheucht die Kreatur unterschiedlich lange), Abklingzeit
const MELEE := {
	"fist": {"reach": 1.5, "strength": 0.4, "cooldown": 0.45, "anim": "punch", "len": 0.34, "block": 0.5},
	"axe": {"reach": 2.1, "strength": 1.0, "cooldown": 0.8, "anim": "swing", "len": 0.6, "block": 0.3},
}

var player: Player
var watch_light: SpotLight3D
var blocking: bool = false

var _skin: StandardMaterial3D
var _sleeve: StandardMaterial3D
var _right: Node3D
var _right_model: Node3D
var _right_kind: String = ""
var _right_out: float = 1.0
var _left: Node3D
var _left_arm: Node3D
var _hammer: Node3D
var _left_out: float = 1.0
var _led: StandardMaterial3D
var _screen: StandardMaterial3D
var _watch_on: bool = false

var _action: String = ""
var _action_t: float = 0.0
var _action_len: float = 0.0
var _action_hit_done: bool = false
var _cooldown: float = 0.0
var _block_amount: float = 0.0

var _sway := Vector2.ZERO
var _sway_vel := Vector2.ZERO
var _last_yaw: float = 0.0
var _last_pitch: float = 0.0


func _ready() -> void:
	name = "Hands"
	_skin = BuildKit.color_mat(Color(0.62, 0.46, 0.38), 0.8)
	_sleeve = BuildKit.tex_mat("fabric", 0.15, Color(0.55, 0.65, 0.6))
	_right = Node3D.new()
	_right.name = "Right"
	add_child(_right)
	_left = Node3D.new()
	_left.name = "Left"
	add_child(_left)
	_build_left()
	# schwaches Streulicht, damit die Hände im Dunkeln erkennbar bleiben
	var fill := OmniLight3D.new()
	fill.position = Vector3(0.0, 0.1, -0.2)
	fill.omni_range = 0.6
	fill.light_energy = 0.25
	fill.light_color = Color(1.0, 0.92, 0.8)
	add_child(fill)
	Inventory.hotbar_changed.connect(_on_hotbar_changed)
	Inventory.changed.connect(_on_hotbar_changed)
	if player:
		_last_yaw = player.rotation.y
		_last_pitch = player.head.rotation.x


# --- Modelle ------------------------------------------------------------

func _no_shadows(n: Node) -> void:
	for mi in n.find_children("*", "GeometryInstance3D", true, false):
		(mi as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Unterarm im Ärmel bis zum Handgelenk (Hand bei z = 0, Arm nach hinten-unten).
func _forearm(parent: Node3D) -> void:
	BuildKit.box(parent, Vector3(0.105, 0.105, 0.34), Vector3(0.0, -0.035, 0.24), _sleeve, false, Vector3(-8, 0, 0))
	BuildKit.box(parent, Vector3(0.11, 0.11, 0.03), Vector3(0.0, -0.022, 0.075), _sleeve, false)
	BuildKit.box(parent, Vector3(0.064, 0.058, 0.07), Vector3(0.0, -0.005, 0.04), _skin, false)


## Geballte Faust mit Knöcheln, Fingerfalten und Daumen.
func _fist(parent: Node3D, side: float) -> void:
	BuildKit.box(parent, Vector3(0.085, 0.08, 0.095), Vector3(0, 0, -0.03), _skin, false)
	var dark := BuildKit.color_mat(Color(0.45, 0.32, 0.26), 0.85)
	for i in 4:
		var x := -0.03 + i * 0.02
		BuildKit.box(parent, Vector3(0.019, 0.022, 0.024), Vector3(x, 0.022, -0.078), _skin, false)
		BuildKit.box(parent, Vector3(0.002, 0.05, 0.002), Vector3(x + 0.01, -0.005, -0.079), dark, false)
	BuildKit.box(parent, Vector3(0.024, 0.026, 0.062), Vector3(-side * 0.047, -0.012, -0.045), _skin, false, Vector3(0, side * 18.0, 0))


func _make_right(kind: String) -> Node3D:
	var m := Node3D.new()
	_forearm(m)
	match kind:
		"axe":
			# Hand um 90° nach rechts gedreht: Daumen zeigt nach oben, der Stiel läuft senkrecht durch die Faust
			var grip := Node3D.new()
			grip.rotation_degrees.z = -90.0
			m.add_child(grip)
			_fist(grip, 1.0)
			var wood := BuildKit.tex_mat("planks_v", 0.2, Color(1.1, 0.95, 0.8))
			var steel := BuildKit.tex_mat("metal", 0.15, Color(1.4, 1.4, 1.42), 0.35)
			var axe := Node3D.new()
			axe.position = Vector3(0, 0.0, -0.035)
			axe.rotation_degrees = Vector3(-14, 0, 0)
			m.add_child(axe)
			BuildKit.cylinder(axe, 0.017, 0.66, Vector3(0, 0.2, 0), wood, false, Vector3.ZERO, 0.015, 8)
			BuildKit.box(axe, Vector3(0.034, 0.1, 0.06), Vector3(0, 0.5, 0), steel, false)
			BuildKit.box(axe, Vector3(0.016, 0.13, 0.14), Vector3(0, 0.5, -0.09), steel, false)
			BuildKit.box(axe, Vector3(0.008, 0.15, 0.02), Vector3(0, 0.5, -0.165), BuildKit.tex_mat("metal", 0.1, Color(2.0, 2.0, 2.0), 0.2), false)
			BuildKit.box(axe, Vector3(0.03, 0.05, 0.03), Vector3(0, 0.5, 0.045), steel, false)
		"food":
			_fist(m, 1.0)
			Icons.food_can(m, Vector3(0.0, -0.01, -0.06), 0.042, 0.11)
		"water":
			_fist(m, 1.0)
			var bottle := BuildKit.lathe(m, PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.95, 0.0), Vector2(1.0, 0.05), Vector2(1.0, 0.62),
					Vector2(0.45, 0.82), Vector2(0.35, 0.9), Vector2(0.0, 0.9)]), Vector3(0.0, -0.06, -0.06), BuildKit.color_mat(Color(0.45, 0.65, 0.8), 0.1), 10)
			bottle.scale = Vector3(0.045, 0.26, 0.045)
			BuildKit.cylinder(m, 0.018, 0.03, Vector3(0.0, 0.18, -0.06), BuildKit.color_mat(Color(0.15, 0.3, 0.7), 0.5), false, Vector3.ZERO, -1.0, 8)
		_:
			_fist(m, 1.0)
	_no_shadows(m)
	return m


## Linker Arm mit Smartwatch (rundes dunkles Gehäuse, orangefarbenes Armband, LED vorne)
## und dem Bauhammer, der im Baumodus in der Faust liegt.
func _build_left() -> void:
	_left_arm = Node3D.new()
	_left_arm.rotation_degrees = Vector3(4, -14, 0)
	_left.add_child(_left_arm)
	_forearm(_left_arm)
	_fist(_left_arm, -1.0)
	var case_mat := BuildKit.tex_mat("metal", 0.1, Color(0.45, 0.45, 0.47), 0.4)
	var strap := BuildKit.color_mat(Color(0.85, 0.32, 0.1), 0.7)
	var watch := Node3D.new()
	watch.position = Vector3(0.0, 0.032, 0.05)
	_left_arm.add_child(watch)
	# Armband rund ums Handgelenk
	BuildKit.box(watch, Vector3(0.072, 0.008, 0.026), Vector3(0, -0.004, 0), strap, false)
	BuildKit.box(watch, Vector3(0.072, 0.008, 0.026), Vector3(0, -0.066, 0), strap, false)
	for sx: float in [-1.0, 1.0]:
		BuildKit.box(watch, Vector3(0.008, 0.068, 0.026), Vector3(sx * 0.036, -0.035, 0), strap, false)
	for k in 3:
		BuildKit.box(watch, Vector3(0.06, 0.009, 0.004), Vector3(0, -0.067, -0.008 + k * 0.008), BuildKit.color_mat(Color(0.12, 0.05, 0.03)), false)
	# Gehäuse mit Lünette, Drückern und Display
	BuildKit.cylinder(watch, 0.03, 0.014, Vector3(0, 0.008, 0), case_mat, false, Vector3.ZERO, -1.0, 16)
	BuildKit.cylinder(watch, 0.031, 0.004, Vector3(0, 0.016, 0), BuildKit.color_mat(Color(0.12, 0.12, 0.13), 0.3, 0.6), false, Vector3.ZERO, -1.0, 16)
	for a: float in [40.0, 140.0, 220.0, 320.0]:
		var r := deg_to_rad(a)
		BuildKit.box(watch, Vector3(0.006, 0.006, 0.006), Vector3(cos(r) * 0.032, 0.008, sin(r) * 0.032), case_mat, false)
	_screen = StandardMaterial3D.new()
	_screen.albedo_color = Color(0.02, 0.02, 0.025)
	_screen.roughness = 0.1
	_screen.emission_enabled = true
	_screen.emission = Color(0.4, 0.7, 0.9)
	_screen.emission_energy_multiplier = 0.0
	BuildKit.cylinder(watch, 0.025, 0.002, Vector3(0, 0.0185, 0), _screen, false, Vector3.ZERO, -1.0, 16)
	# LED vorne am Gehäuse
	_led = BuildKit.emissive_mat(Color(1.0, 0.97, 0.9), 0.0)
	BuildKit.box(watch, Vector3(0.014, 0.006, 0.004), Vector3(0, 0.01, -0.031), _led, false)
	watch_light = SpotLight3D.new()
	watch_light.position = Vector3(0, 0.012, -0.04)
	watch_light.rotation_degrees = Vector3(2, 10, 0)
	watch_light.light_color = Color(1.0, 0.97, 0.9)
	watch_light.light_energy = 4.5
	watch_light.spot_range = 24.0
	watch_light.spot_angle = 30.0
	watch_light.spot_angle_attenuation = 1.4
	watch_light.spot_attenuation = 1.0
	watch_light.shadow_enabled = true
	watch_light.light_volumetric_fog_energy = 1.2
	watch_light.visible = false
	watch.add_child(watch_light)
	# Bauhammer
	_hammer = Node3D.new()
	_hammer.position = Vector3(0, 0.0, -0.035)
	_hammer.rotation_degrees = Vector3(-55, 0, -6)
	_left_arm.add_child(_hammer)
	var wood := BuildKit.tex_mat("planks_v", 0.2, Color(1.15, 1.0, 0.85))
	var steel := BuildKit.tex_mat("metal", 0.15, Color(1.3, 1.3, 1.32), 0.35)
	BuildKit.cylinder(_hammer, 0.014, 0.34, Vector3(0, 0.1, 0), wood, false, Vector3.ZERO, 0.012, 8)
	BuildKit.box(_hammer, Vector3(0.03, 0.03, 0.08), Vector3(0, 0.27, 0.025), steel, false)
	BuildKit.cylinder(_hammer, 0.019, 0.03, Vector3(0, 0.27, 0.075), steel, false, Vector3(90, 0, 0), -1.0, 10)
	BuildKit.box(_hammer, Vector3(0.022, 0.018, 0.07), Vector3(0, 0.262, -0.045), steel, false, Vector3(-18, 0, 0))
	_hammer.visible = false
	_no_shadows(_left)


# --- Zustand ------------------------------------------------------------

func set_watch(on: bool) -> void:
	_watch_on = on
	watch_light.visible = on
	_led.emission_energy_multiplier = 6.0 if on else 0.0
	_screen.emission_energy_multiplier = 0.6 if on else 0.0


func _building() -> bool:
	var bc := get_tree().get_first_node_in_group("build_controller") as BuildController
	return bc != null and bc.active


func _wanted_right() -> String:
	if player and (player.input_locked or GameState.dead):
		return ""
	var id := Inventory.equipped()
	var kind := "fist"
	if id != "":
		kind = String(DataDB.item(id).get("hand", "fist"))
	return kind


func _on_hotbar_changed() -> void:
	pass  # der Wechsel passiert weich in _process


func current_kind() -> String:
	return _right_kind


# --- Eingabe ------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if player == null or player.input_locked or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED or get_tree().paused:
		return
	for i in Inventory.SLOTS:
		if event.is_action_pressed("slot_%d" % (i + 1)):
			Inventory.select(i)
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("slot_next"):
		Inventory.select(Inventory.selected + 1)
	elif event.is_action_pressed("slot_prev"):
		Inventory.select(Inventory.selected - 1)
	elif event.is_action_pressed("attack") and not _building():
		_primary()
		get_viewport().set_input_as_handled()


func _primary() -> void:
	if _cooldown > 0.0 or _action != "" or _right_out > 0.2 or blocking:
		return
	match _right_kind:
		"axe":
			# Über einem umgestürzten Stamm: fällen statt zuschlagen
			var node := player.current_interactable as ResourceNode
			if node and node.tool == "axe":
				node.interact(player)
				return
			_start_action("swing", MELEE["axe"]["len"])
			_cooldown = MELEE["axe"]["cooldown"]
		"fist":
			_start_action("punch", MELEE["fist"]["len"])
			_cooldown = MELEE["fist"]["cooldown"]
		"food", "water":
			_start_action("consume", 1.1)
			_cooldown = 1.2


## Ein einzelner Hieb ohne Treffer-Prüfung (z. B. beim Holzhacken, pro Schlag aufgerufen).
func tool_swing() -> void:
	_start_action("chop", 0.45)


func _start_action(a: String, length: float) -> void:
	_action = a
	_action_t = 0.0
	_action_len = length
	_action_hit_done = false


## Treffer: Kreatur vor dem Spieler wird verscheucht; sonst ein dumpfer Schlag gegen Wände.
func _melee_hit(kind: String) -> void:
	var cfg: Dictionary = MELEE[kind]
	var cam := player.camera.global_transform
	var fwd := -cam.basis.z
	var c: Creature = (ThreatDirector.creature as Creature) if is_instance_valid(ThreatDirector.creature) else null
	if c:
		# waagerecht prüfen: Abstand und ob sie vor dem Spieler steht (ganz nah genügt "grob vorne")
		var to := c.global_position - player.global_position
		to.y = 0.0
		var fwd_h := Vector3(fwd.x, 0.0, fwd.z).normalized()
		var d := to.length()
		var facing := fwd_h.dot(to.normalized()) if d > 0.01 else 1.0
		if d < float(cfg["reach"]) + 0.4 and (facing > 0.6 or (d < 1.0 and facing > 0.0)):
			c.on_melee_hit(float(cfg["strength"]), player.global_position)
			SoundBank.play_at(get_tree().current_scene, "wood_crack" if kind == "axe" else "knock", c.global_position + Vector3(0, 1.3, 0), -2.0, 1.3)
			EventBus.screen_shake.emit(0.15)
			return
	var q := PhysicsRayQueryParameters3D.create(cam.origin, cam.origin + fwd * float(cfg["reach"]))
	q.exclude = [player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		SoundBank.play_at(get_tree().current_scene, "knock", hit["position"], -10.0, randf_range(1.2, 1.5))
		EventBus.noise_made.emit(hit["position"], 6.0)


## Schadensminderung beim Blocken (1 = kein Block).
func block_factor(from: Vector3) -> float:
	if _block_amount < 0.6 or not MELEE.has(_right_kind):
		return 1.0
	var to := (from - player.global_position)
	to.y = 0.0
	var fwd := -player.global_transform.basis.z
	if fwd.dot(to.normalized()) < 0.2:
		return 1.0
	return float(MELEE[_right_kind]["block"])


# --- Ablauf -------------------------------------------------------------

func _process(delta: float) -> void:
	if player == null:
		return
	_cooldown = maxf(_cooldown - delta, 0.0)
	blocking = MELEE.has(_right_kind) and Input.is_action_pressed("block") and not player.input_locked \
			and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not _building() and _action == ""
	_block_amount = move_toward(_block_amount, 1.0 if blocking else 0.0, delta * 7.0)

	# Rechte Hand: alten Gegenstand wegnehmen, neuen holen
	var want := _wanted_right()
	if want != _right_kind:
		_action = ""
		_right_out = move_toward(_right_out, 1.0, delta * SWITCH_SPEED)
		if _right_out >= 1.0:
			if _right_model:
				_right_model.queue_free()
				_right_model = null
			_right_kind = want
			if want != "":
				_right_model = _make_right(want)
				_right.add_child(_right_model)
	elif _right_kind != "":
		_right_out = move_toward(_right_out, 0.0, delta * SWITCH_SPEED)

	# Linke Hand: sichtbar bei eingeschalteter Uhr-Lampe oder im Baumodus (Hammer)
	var build := _building()
	var left_wanted := (_watch_on or build) and not GameState.dead
	if build != _hammer.visible and _left_out >= 0.99:
		_hammer.visible = build
	if left_wanted and (build == _hammer.visible):
		_left_out = move_toward(_left_out, 0.0, delta * SWITCH_SPEED)
	else:
		_left_out = move_toward(_left_out, 1.0, delta * SWITCH_SPEED)
	_left.visible = _left_out < 0.99
	_right.visible = _right_out < 0.99 and _right_kind != ""

	_update_sway(delta)
	_pose_right(delta)
	_pose_left()


## Nachschwingen: die Hände bleiben beim Umsehen etwas zurück und federn nach.
func _update_sway(delta: float) -> void:
	var yaw := player.rotation.y
	var pitch := player.head.rotation.x
	var dyaw := wrapf(yaw - _last_yaw, -PI, PI)
	var dpitch := pitch - _last_pitch
	_last_yaw = yaw
	_last_pitch = pitch
	_sway -= Vector2(dyaw, dpitch) * 0.85
	var k := 140.0
	var damping := 13.0
	_sway_vel += (-_sway * k - _sway_vel * damping) * delta
	_sway += _sway_vel * delta
	_sway = _sway.clamp(Vector2(-0.3, -0.25), Vector2(0.3, 0.25))
	rotation = Vector3(_sway.y, _sway.x, _sway.x * 0.6)
	# Wippen beim Gehen
	var t: float = player._bob_time
	var moving := Vector2(player.velocity.x, player.velocity.z).length() > 0.3 and player.is_on_floor()
	var target := Vector3(sin(t * 0.5) * 0.012, -absf(cos(t * 0.5)) * 0.01, 0.0) if moving else Vector3.ZERO
	position = position.lerp(target, clampf(delta * 10.0, 0.0, 1.0))


func _pose_right(delta: float) -> void:
	var pos := RIGHT_REST
	var rot := Vector3.ZERO
	var e := _right_out * _right_out
	pos.y -= HIDE_DROP * e
	rot.x -= 35.0 * e
	if _right_kind == "axe":
		pos = Vector3(0.25, -0.3, -0.36) + Vector3(0, -HIDE_DROP * e, 0)
		rot.z -= 8.0
	elif _right_kind == "fist":
		# Faust in Ruhe nur angedeutet am unteren Bildrand
		pos = Vector3(0.27, -0.34, -0.3) + Vector3(0, -HIDE_DROP * e, 0)
		rot.x -= 12.0
	# Blocken: Faust bzw. Axt quer vors Gesicht
	if _block_amount > 0.0:
		var bp := Vector3(0.06, -0.09, -0.3) if _right_kind == "fist" else Vector3(0.02, -0.1, -0.38)
		var br := Vector3(10, 25, 70) if _right_kind == "fist" else Vector3(0, 20, 78)
		var b := smoothstep(0.0, 1.0, _block_amount)
		pos = pos.lerp(bp, b)
		rot = rot.lerp(br, b)
	if _action != "":
		_action_t += delta
		var p := clampf(_action_t / _action_len, 0.0, 1.0)
		match _action:
			"punch":
				var f := sin(clampf(p * 2.2, 0.0, 1.0) * PI * 0.5) if p < 0.45 else 1.0 - smoothstep(0.45, 1.0, p)
				# aus der tiefen Ruhelage hoch und nach vorne
				pos += Vector3(-0.1, 0.15, -0.27) * f
				rot += Vector3(20, 6, -10) * f
				if p >= 0.4 and not _action_hit_done:
					_action_hit_done = true
					_melee_hit("fist")
			"swing", "chop":
				var up := smoothstep(0.0, 0.28, p)
				var down := smoothstep(0.28, 0.5, p)
				var back := smoothstep(0.55, 1.0, p)
				# Drehung um den Ellbogen (hinter der Hand), damit Unterarm und Ärmel
				# nie vor die Kamera klappen; Ausholen nach hinten, Schlag nur bis schräg nach vorne
				var swing := (35.0 * up - 80.0 * down) * (1.0 - back)
				rot.x += swing
				var elbow := Vector3(0.0, -0.06, 0.32)
				pos += elbow - Basis.from_euler(Vector3(deg_to_rad(swing), 0.0, 0.0)) * elbow
				pos += Vector3(-0.05, 0.04 * up, -0.04 * down) * (1.0 - back)
				if _action == "swing" and p >= 0.47 and not _action_hit_done:
					_action_hit_done = true
					_melee_hit("axe")
			"consume":
				var f := smoothstep(0.0, 0.35, p) * (1.0 - smoothstep(0.75, 1.0, p))
				pos = pos.lerp(Vector3(0.04, -0.1, -0.2), f)
				rot += Vector3(55, 0, -30) * f
				if p >= 0.6 and not _action_hit_done:
					_action_hit_done = true
					var id := Inventory.equipped()
					if id != "":
						Inventory.use(id)
		if p >= 1.0:
			_action = ""
	_right.position = pos
	_right.rotation_degrees = rot


func _pose_left() -> void:
	var e := _left_out * _left_out
	_left.position = LEFT_REST + Vector3(0, -HIDE_DROP * e, 0)
	_left.rotation_degrees = Vector3(-35.0 * e, 0, 0)
	if _hammer.visible:
		# Hammer etwas weiter ins Bild
		_left.position += Vector3(0.03, 0.0, -0.03)
