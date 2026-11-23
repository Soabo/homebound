class_name Changeling
extends Node3D
## Der Wechselbalg (Christian 14.11.2026). Sieht aus wie ein Gegenstand von Stuhlgröße an aufwärts – aber jede
## Tarnung hat genau einen Fehler (ChangelingModel). Er bewegt sich nur, wenn niemand hinsieht, und rückt dann ruckweise
## näher (Schleifen, das beim Hinsehen schlagartig verstummt). Seine wahre Gestalt sieht man nur ganz selten: auf der
## Überwachungskamera, im Blitz, im Badezimmerspiegel, nach einem Axthieb – und kurz bevor er zupackt.
## Ab Nacht changeling_abduct_from_night packt er von hinten zu und zieht einen in den Wald (Aufwachen in der Nähe).
## Tagsüber steht er harmlos als zweite Bank oder falscher Wegweiser herum und folgt einem.
## Werte: data/creatures/changeling.tres (ChangelingConfig), wann: ThreatConfig changeling_*, Orte/Texte: changeling.json.

const DATA := "res://data/creatures/changeling.json"
## Tarnung: sieht nur der Spieler, nicht die Überwachungskameras (die zeigen die wahre Gestalt auf Surveillance.PHANTOM_LAYER)
const MASK_LAYER := 1 << 4
const PHANTOM_BIT := 1 << 1

static var grabbing: Changeling = null
static var _skin_day: int = -100

var cfg: ChangelingConfig
var disguise: String = "chair"
var subtle: bool = false
## night | yard | morning | day | camp | siege
var mode: String = "night"
var approach: bool = false
var can_grab: bool = false
var fast: bool = false
var echo: bool = false
var vanish_when_unseen: bool = false
var stop_distance: float = -1.0
## Sekunden, die die Uhr-LED ihn schon anleuchtet (Belagerung: vertreibt ihn)
var lit_time: float = 0.0
var spot_id: String = ""

var _player: Player
var _rng := RandomNumberGenerator.new()
var _mask: Node3D
var _true: Node3D
var _stand: Node3D
var _body: StaticBody3D
var _shadow: Decal
var _mirror: Sprite3D
var _mirror_done := false
var _size := Vector3(0.5, 1.0, 0.5)
var _height := 1.0
var _inside := false
var _unseen := 0.0
var _seen_total := 0.0
var was_seen := false
var _thought_done := false
var _move_t := 3.0
var _moving := false
var _move_from := Vector3.ZERO
var _move_to := Vector3.ZERO
var _move_p := 0.0
var _drag: AudioStreamPlayer3D
var _pull: AudioStreamPlayer3D
var _reveal_t := 0.0
var _fleeing := false
var _breath_t := 2.0
var _last_step_msec := -100000
var _stop_pending := false
var _grab_t := -1.0
var _struggle := 0.0


static func data() -> Dictionary:
	return DataDB.load_json(DATA)


static func text(key: String) -> String:
	return String(data().get("texts", {}).get(key, ""))


static func spots(where: String) -> Array:
	return data().get("spots", []).filter(func(s: Dictionary) -> bool: return s.get("where", "") == where)


## Einen Wechselbalg an einem Ort aus changeling.json aufstellen.
static func spawn_spot(scene: Node, spot: Dictionary, settings: Dictionary = {}) -> Changeling:
	var p: Array = spot.get("pos", [0, 0])
	var ch := spawn(scene, String(spot.get("disguise", "chair")), Vector3(float(p[0]), 0.0, float(p[1])), settings)
	ch.spot_id = String(spot.get("id", ""))
	if spot.has("face"):
		var f: Array = spot["face"]
		ch.face_dir(Vector3(float(f[0]), 0, float(f[1])))
	if spot.has("lean"):
		var l: Array = spot["lean"]
		ch.face_dir(-Vector3(float(l[0]), 0, float(l[1])))
	return ch


static func spawn(scene: Node, kind: String, pos: Vector3, settings: Dictionary = {}) -> Changeling:
	var ch := Changeling.new()
	ch.disguise = kind
	for k: String in settings:
		ch.set(k, settings[k])
	ch.name = "Changeling_%d" % (Time.get_ticks_usec() % 1000000)
	scene.add_child(ch)
	ch.global_position = pos
	ch.snap_ground()
	return ch


func _ready() -> void:
	add_to_group("changeling")
	cfg = ChangelingConfig.get_default()
	_rng.randomize()
	_player = get_tree().get_first_node_in_group("player") as Player
	_mask = Node3D.new()
	_mask.name = "Mask"
	add_child(_mask)
	var info := ChangelingModel.build(_mask, disguise, subtle)
	_size = info.get("size", _size)
	_height = float(info.get("height", 1.0))
	_set_layers(_mask, MASK_LAYER)
	_true = Node3D.new()
	_true.name = "TrueForm"
	add_child(_true)
	ChangelingModel.build_true(_true, "crouch")
	_set_layers(_true, PHANTOM_BIT)
	_stand = Node3D.new()
	_stand.name = "TrueStand"
	_stand.visible = false
	add_child(_stand)
	ChangelingModel.build_true(_stand, "stand")
	_set_layers(_stand, 1 | PHANTOM_BIT)
	_body = BuildKit.collider_box(self, _size, Vector3(0, _size.y * 0.5, 0))
	_body.name = "Body"
	_shadow = Decal.new()
	_shadow.texture_albedo = ChangelingModel.shadow_texture()
	_shadow.size = Vector3(1.0, 1.6, 1.8)
	_shadow.modulate = Color(0, 0, 0, 0)
	_shadow.top_level = true
	_shadow.cull_mask = 1
	add_child(_shadow)
	_drag = _loop_player("changeling_drag", cfg.drag_db)
	_pull = _loop_player("changeling_pull", -2.0)
	if stop_distance < 0.0:
		stop_distance = cfg.stop_distance
	_move_t = _interval()
	if _player:
		_player.stepped.connect(_on_step)


func _exit_tree() -> void:
	if grabbing == self:
		grabbing = null
		if is_instance_valid(_player):
			_player.grabbed_by = null


func _loop_player(id: String, db: float) -> AudioStreamPlayer3D:
	var a := AudioStreamPlayer3D.new()
	a.stream = SoundBank.get_sound(id)   # Schleifen und Ziehen sind Klangschleifen (SoundBank.LOOP_IDS)
	a.volume_db = db
	a.unit_size = 3.0
	a.max_distance = cfg.drag_range
	a.position = Vector3(0, 0.3, 0)
	add_child(a)
	return a


static func _set_layers(n: Node, layers: int) -> void:
	if n is VisualInstance3D:
		(n as VisualInstance3D).layers = layers
	for c in n.get_children():
		_set_layers(c, layers)


## Vorderseite (+z) in eine Richtung drehen.
func face_dir(d: Vector3) -> void:
	d.y = 0.0
	if d.length() < 0.01:
		return
	look_at(global_position - d.normalized(), Vector3.UP)


## Auf den Boden darunter stellen (Hüttenboden, Veranda, Gelände).
func snap_ground() -> void:
	_inside = Cabin.is_inside(global_position + Vector3(0, Cabin.FLOOR_Y + 0.2, 0)) or Cabin.is_inside(global_position)
	if _inside:
		var y := Cabin.FLOOR_Y
		if Cabin.in_cellar(global_position):
			y = Cabin.CELLAR_FLOOR
		global_position.y = y
		return
	var top := global_position + Vector3(0, 4.0, 0)
	top.y = maxf(top.y, Terrain.height_at(global_position.x, global_position.z) + 4.0)
	var q := PhysicsRayQueryParameters3D.create(top, top - Vector3(0, 12.0, 0))
	q.exclude = [_body.get_rid()] if _body else []
	var hit := get_world_3d().direct_space_state.intersect_ray(q) if is_inside_tree() else {}
	global_position.y = float(hit["position"].y) if not hit.is_empty() else Terrain.height_at(global_position.x, global_position.z)


func _interval() -> float:
	var r := cfg.move_interval_fast if fast else cfg.move_interval_slow
	return _rng.randf_range(r.x, r.y)


func _center() -> Vector3:
	return global_position + Vector3(0, _height * 0.5, 0)


func dist() -> float:
	return global_position.distance_to(_player.global_position) if _player else 999.0


# --- Hauptschleife ---------------------------------------------------------------

func _process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player) or GameState.dead:
		return
	if grabbing == self:
		_update_grab(delta)
		return
	_update_reveal(delta)
	if _fleeing:
		return
	var seen := is_seen()
	if seen:
		_unseen = 0.0
		_seen_total += delta
		if _seen_total > 0.4:
			was_seen = true
		if _moving:
			_stop_move()
		_maybe_thought()
	else:
		_unseen += delta
	if vanish_when_unseen and was_seen and _unseen > 2.5:
		queue_free()
		return
	# Rücken nur ungesehen
	if _moving:
		_update_move(delta)
	elif approach and not seen and _unseen > cfg.unseen_delay:
		_move_t -= delta
		if _move_t <= 0.0:
			_move_t = _interval()
			_try_step()
	# Zupacken: von hinten, wenn man ihm den Rücken zukehrt
	if can_grab and not seen and grabbing == null and dist() < cfg.grab_range and _player_turned_away() \
			and not _player.is_hidden() and _player.in_tent == null and not _player.input_locked:
		_start_grab()
		return
	_sounds(delta, seen)
	_update_light(delta)
	_check_mirror()


func is_seen() -> bool:
	var cam := _player.camera.global_transform
	var c := _center()
	var to := c - cam.origin
	if to.length() > cfg.look_range:
		return false
	if (-cam.basis.z).dot(to.normalized()) < cos(deg_to_rad(cfg.look_cone)):
		return false
	# gesehen, wenn irgendein Teil frei ist (oben, Mitte, unten) – ein Stuhl hinter dem Tisch zählt mit der Lehne
	var ex := [_player.get_rid(), _body.get_rid()]
	for h: float in [0.88, 0.5, 0.2]:
		if Stealth.line_clear(get_world_3d(), cam.origin, global_position + Vector3(0, _height * h, 0), ex):
			return true
	return false


func _player_turned_away() -> bool:
	var to := global_position - _player.global_position
	to.y = 0.0
	var fwd := -_player.global_transform.basis.z
	fwd.y = 0.0
	return fwd.normalized().dot(to.normalized()) < -0.1


func _maybe_thought() -> void:
	if _thought_done or dist() > 5.0 or _seen_total < (3.0 if subtle else 1.2):
		return
	_thought_done = true
	var t: Dictionary = data().get("thoughts", {}).get(disguise, {})
	var s := String(t.get("subtle" if subtle else "obvious", ""))
	if s != "":
		EventBus.notify(s, 4.5)
	Tasks.flag("changeling_seen")


# --- Rücken -----------------------------------------------------------------------

func _try_step() -> void:
	var to := _player.global_position - global_position
	to.y = 0.0
	var d := to.length()
	if d <= stop_distance + 0.1:
		return
	var step := minf(cfg.step_fast if fast else cfg.step_slow, d - stop_distance)
	var base := to.normalized()
	for ang: float in [0.0, 40.0, -40.0, 80.0, -80.0]:
		var dir := base.rotated(Vector3.UP, deg_to_rad(ang))
		var goal := global_position + dir * step
		if _free_path(global_position, goal):
			_move_from = global_position
			_move_to = goal
			_move_p = 0.0
			_moving = true
			SoundBank.play_at(get_parent(), "changeling_joints", _center(), -6.0, _rng.randf_range(0.85, 1.1))
			if not _inside:
				_drag.stream = SoundBank.get_sound("changeling_drag_forest")
			_drag.play(_rng.randf_range(0.0, 0.5))
			return


## Weg frei? Nicht durch Wände/Möbel, im Haus bleibt er im Haus, draußen draußen.
func _free_path(a: Vector3, b: Vector3) -> bool:
	if _inside != (Cabin.is_inside(b + Vector3(0, 0.3, 0))):
		return false
	var ex := [_body.get_rid(), _player.get_rid()]
	var side := (b - a).normalized().cross(Vector3.UP) * (_size.x * 0.45)
	for h: float in [0.25, minf(_height * 0.8, 1.2)]:
		for off: Vector3 in [Vector3.ZERO, side, -side]:
			var q := PhysicsRayQueryParameters3D.create(a + Vector3(0, h, 0) + off, b + Vector3(0, h, 0) + off + (b - a).normalized() * (_size.z * 0.5))
			q.exclude = ex
			if not get_world_3d().direct_space_state.intersect_ray(q).is_empty():
				return false
	return true


func _update_move(delta: float) -> void:
	_move_p = minf(_move_p + delta / maxf(cfg.step_time, 0.05), 1.0)
	var p := _move_from.lerp(_move_to, _move_p * _move_p * (3.0 - 2.0 * _move_p))
	global_position = p
	if not _inside:
		global_position.y = Terrain.height_at(p.x, p.z)
	# dreht sich beim Rücken langsam zu dir
	var to := _player.global_position - global_position
	to.y = 0.0
	if to.length() > 0.1 and disguise not in ["broom"]:
		var t := global_transform.looking_at(global_position - to.normalized(), Vector3.UP)
		global_transform.basis = global_transform.basis.slerp(t.basis.orthonormalized(), clampf(delta * 3.0, 0.0, 1.0))
	if _move_p >= 1.0:
		_stop_move()


## Hört schlagartig auf (beim Hinsehen oder am Ziel).
func _stop_move() -> void:
	_moving = false
	if _drag.playing:
		_drag.stop()


# --- Töne ---------------------------------------------------------------------------

func _sounds(delta: float, seen: bool) -> void:
	var d := dist()
	# Er atmet ganz leise – das hört nur, wer selbst den Atem anhält
	if _player.holding_breath and d < cfg.breath_range:
		_breath_t -= delta
		if _breath_t <= 0.0:
			_breath_t = _rng.randf_range(2.6, 3.6)
			SoundBank.play_at(get_parent(), "changeling_breath", _center() + Vector3(0, _height * 0.3, 0), -12.0, _rng.randf_range(0.92, 1.05))
	# Ein Stuhl knarrt, als setze sich jemand
	if not seen and disguise in ["chair", "office_chair", "bench"] and d < cfg.sit_range and _rng.randf() < cfg.sit_chance * delta:
		SoundBank.play_at(get_parent(), "changeling_sit", _center(), -6.0, _rng.randf_range(0.9, 1.05))
	# Echo-Schritte: bleibt man stehen, folgt manchmal noch genau ein Schritt
	if _stop_pending and Time.get_ticks_msec() - _last_step_msec > 600 and Vector2(_player.velocity.x, _player.velocity.z).length() < 0.3:
		_stop_pending = false
		if _rng.randf() < cfg.echo_stop_chance:
			Footsteps.play(get_parent(), _behind_player(), "walk", cfg.echo_db - 2.0)


func _behind_player() -> Vector3:
	return _player.global_position + _player.global_transform.basis.z * 1.3


func _on_step(gait: String, _pos: Vector3) -> void:
	if not echo or _fleeing or dist() > cfg.echo_range or mode in ["day", "siege"]:
		return
	_last_step_msec = Time.get_ticks_msec()
	_stop_pending = true
	var at := _behind_player()
	get_tree().create_timer(cfg.echo_delay).timeout.connect(func() -> void:
		if is_instance_valid(self) and is_inside_tree():
			Footsteps.play(get_parent(), at, gait, cfg.echo_db))


# --- Licht, Schatten, Spiegel, Blitz -----------------------------------------------

func _led_on_me() -> bool:
	if not _player.light_shining():
		return false
	var cam := _player.camera.global_transform
	var to := _center() - cam.origin
	if to.length() > cfg.led_range:
		return false
	if (-cam.basis.z).dot(to.normalized()) < cos(deg_to_rad(cfg.led_cone)):
		return false
	return Stealth.line_clear(get_world_3d(), cam.origin, _center(), [_player.get_rid(), _body.get_rid()])


## Im Uhrlicht wirft er einen Schatten, der nicht zu ihm passt: lange Finger.
func _update_light(delta: float) -> void:
	var lit := _led_on_me()
	lit_time = lit_time + delta if lit else 0.0
	var target := 0.85 if lit else 0.0
	var a := move_toward(_shadow.modulate.a, target, delta * 3.0)
	_shadow.modulate = Color(0, 0, 0, a)
	_shadow.visible = a > 0.01
	if _shadow.visible:
		var dir := global_position - _player.camera.global_position
		dir.y = 0.0
		dir = dir.normalized() if dir.length() > 0.01 else Vector3.FORWARD
		var c := global_position + dir * (0.5 + _size.z * 0.5 + 0.8) + Vector3(0, 0.6, 0)
		_shadow.global_transform = Transform3D(Basis.looking_at(dir, Vector3.UP), c)


## Badezimmerspiegel: dort steht hinter dir etwas, das im Raum nicht da ist.
func _check_mirror() -> void:
	if _mirror_done or not _inside:
		return
	var mpos := Vector3(Cabin.HALF_X - Cabin.CLAD - 0.06, Cabin.FLOOR_Y + 1.5, -2.3)
	var cam := _player.camera.global_transform
	var to := mpos - cam.origin
	if to.length() > 2.6 or (-cam.basis.z).dot(to.normalized()) < cos(deg_to_rad(14.0)):
		return
	_mirror_done = true
	_mirror = Sprite3D.new()
	_mirror.texture = ChangelingModel.face_texture()
	_mirror.pixel_size = 0.0022
	_mirror.rotation_degrees.y = -90.0
	_mirror.modulate = Color(1, 1, 1, 0.85)
	_mirror.shaded = false
	get_parent().add_child(_mirror)
	_mirror.global_position = mpos + Vector3(-0.004, 0.02, 0.0)
	SoundBank.play_ui(get_parent(), "changeling_unfold", -14.0, 0.9)
	EventBus.notify(text("mirror"), 3.5)
	var m := _mirror
	get_tree().create_timer(cfg.reveal_mirror).timeout.connect(func() -> void:
		if is_instance_valid(m):
			m.queue_free())


## Blitz (DayNightEnvironment.flash): für ein Bild ist er zu sehen, wie er wirklich ist.
func on_lightning() -> void:
	if _player == null or _fleeing:
		return
	var cam := _player.camera.global_transform
	var to := _center() - cam.origin
	if to.length() < 45.0 and (-cam.basis.z).dot(to.normalized()) > cos(deg_to_rad(55.0)):
		reveal(cfg.reveal_lightning, false)


## Wahre Gestalt zeigen (Sekunden); sound = Entfalten hörbar.
func reveal(seconds: float, sound: bool = true) -> void:
	_reveal_t = maxf(_reveal_t, seconds)
	_mask.visible = false
	_set_layers(_true, 1 | PHANTOM_BIT)
	if sound:
		SoundBank.play_at(get_parent(), "changeling_unfold", _center(), 0.0, _rng.randf_range(0.9, 1.05))


func _update_reveal(delta: float) -> void:
	if _reveal_t <= 0.0:
		return
	_reveal_t -= delta
	if _reveal_t <= 0.0:
		if _fleeing:
			Apparition.flash(get_parent(), _center(), true)
			queue_free()
			return
		_mask.visible = true
		_set_layers(_true, PHANTOM_BIT)


## Er flieht (Treffer, Licht in der Belagerung): kurz die wahre Gestalt, Schrei, Blitz, weg.
func flee(show: float = -1.0) -> void:
	if _fleeing:
		return
	_fleeing = true
	_stop_move()
	reveal(cfg.reveal_hit if show < 0.0 else show)
	SoundBank.play_at(get_parent(), "changeling_shriek", _center() + Vector3(0, 0.4, 0), 2.0, _rng.randf_range(0.95, 1.1))


## Axt/Faust trifft die Tarnung: enttarnt, er flieht. Tagsüber gekränkt: in der nächsten Nacht kommt er sicher.
func on_melee_hit(kind: String) -> void:
	if _fleeing:
		return
	Tasks.flag("changeling_revealed")
	EventBus.notify(text("revealed"), 4.0)
	_drop_skin()
	if mode == "day":
		ThreatDirector.changeling_offended()
		get_tree().create_timer(2.5).timeout.connect(func() -> void: EventBus.notify(Changeling.text("offended"), 3.5))
	EventBus.screen_shake.emit(0.25)
	flee()


func _drop_skin() -> void:
	if _skin_day == TimeManager.day:
		return
	var drops := AlienDrops.get_for(get_tree())
	if drops:
		_skin_day = TimeManager.day
		var at := global_position + Vector3(0.3, 0.02, 0.3)
		if not _inside:
			at.y = Terrain.height_at(at.x, at.z) + 0.02
		drops.spawn("changeling_skin", at)


func dawn() -> void:
	if mode in ["night", "yard", "camp", "siege"] and grabbing != self:
		queue_free()


func dusk() -> void:
	if mode == "day":
		queue_free()


# --- Zupacken und Entführen ------------------------------------------------------------

func _start_grab() -> void:
	grabbing = self
	_grab_t = 0.0
	_struggle = 0.0
	_stop_move()
	_mask.visible = false
	_true.visible = false
	_stand.visible = true
	_player.grabbed_by = self
	_place_behind()
	SoundBank.play_at(get_parent(), "changeling_unfold", _center(), 2.0)
	SoundBank.play_at(get_parent(), "changeling_shriek", _player.global_position + Vector3(0, 1.6, 0), 0.0, 0.85)
	EventBus.screen_shake.emit(0.6)
	EventBus.fear_spike.emit(1.0)
	Tasks.flag("changeling_grabbed")
	_pull.play()


func _place_behind() -> void:
	var back := _player.global_transform.basis.z
	back.y = 0.0
	global_position = _player.global_position + back.normalized() * 0.55
	if _inside:
		global_position.y = _player.global_position.y
	else:
		global_position.y = Terrain.height_at(global_position.x, global_position.z)
	look_at(global_position + (global_position - _player.global_position).normalized() * Vector3(1, 0, 1), Vector3.UP)


## Zugrichtung: weg von der Hütte, Richtung Wald.
func pull_vector() -> Vector3:
	var away := _player.global_position
	away.y = 0.0
	if away.length() < 0.5:
		away = Vector3(0, 0, 1)
	return away.normalized() * cfg.pull_speed


func _update_grab(delta: float) -> void:
	_grab_t += delta
	_place_behind()
	var cam := _player.camera.global_transform
	var to := (global_position + Vector3(0, 1.5, 0)) - cam.origin
	var led := _player.light_shining() and (-cam.basis.z).dot(to.normalized()) > cos(deg_to_rad(28.0))
	if _struggle >= 1.0:
		_free()
		return
	if Input.is_action_pressed("interact"):
		_struggle += cfg.struggle_rise * delta * (cfg.struggle_led_factor if led else 1.0)
	elif led:
		_struggle += cfg.struggle_rise * 0.5 * delta
	else:
		_struggle = maxf(_struggle - cfg.struggle_fall * delta, 0.0)
	var bar := "▮".repeat(int(_struggle * 10.0)) + "▯".repeat(10 - int(clampf(_struggle, 0.0, 1.0) * 10.0))
	EventBus.interaction_prompt_changed.emit(text("grabbed") + "   " + bar)
	if _struggle >= 1.0:
		_free()
	elif _grab_t >= cfg.grab_seconds:
		_abduct()


## Treffer während er dich hält: Axt = sofort frei, sonst ein Stoß.
func struggle_hit(kind: String) -> void:
	if kind == "axe":
		_struggle = 1.0
		_free.call_deferred()
	else:
		_struggle += cfg.struggle_fist


func _free() -> void:
	if _fleeing:
		return
	_fleeing = true
	grabbing = null
	_player.grabbed_by = null
	_pull.stop()
	EventBus.interaction_prompt_changed.emit("")
	EventBus.notify(text("freed"), 4.0)
	Tasks.flag("changeling_escaped")
	_drop_skin()
	Apparition.flash(get_parent(), global_position + Vector3(0, 1.4, 0), true)
	queue_free()


## Zu spät: alles wird schwarz, man wacht im Morgengrauen im Wald auf – nicht weit von der Hütte.
func _abduct() -> void:
	grabbing = null
	_pull.stop()
	EventBus.interaction_prompt_changed.emit("")
	var p := _player
	p.input_locked = true
	var start := p.global_position
	var wake := wake_point(_rng, cfg)
	var f := ScreenFade.new()
	var c := cfg
	var rng := _rng
	f._on_mid = func() -> void:
		if not is_instance_valid(p):
			return
		Changeling.scatter_items(p.get_tree(), start, wake, c.abduct_drops, rng)
		var terrain := p.get_tree().current_scene.get_node_or_null("Terrain")
		if terrain and terrain.has_method("load_around"):
			terrain.call("load_around", wake, 70.0)
		p.global_position = wake
		p.velocity = Vector3.ZERO
		p.rotation.y = atan2(wake.x, wake.z)   # Blick ungefähr Richtung Hütte
		p.grabbed_by = null
		if TimeManager.is_night():
			var add := fposmod(TimeManager.config.wake_up_hour - TimeManager.hour, 24.0)
			TimeManager.skip_to_total(TimeManager.get_total_hours() + add)
		p.health = maxf(p.health - c.abduct_damage, minf(p.health, c.abduct_min_health))
		EventBus.player_hurt.emit(c.abduct_damage)
		Survival.warmth = maxf(Survival.warmth - c.abduct_cold, 5.0)
		p.input_locked = false
		Tasks.flag("abducted")
		EventBus.notify(Changeling.text("abducted"), 7.0)
	get_tree().root.add_child(f)
	queue_free()


## Aufwachort: im Wald, abduct_distance von der Hütte, nicht im Wasser, nicht auf dem Hof.
static func wake_point(rng: RandomNumberGenerator, c: ChangelingConfig) -> Vector3:
	for i in 40:
		var a := rng.randf() * TAU
		var r := rng.randf_range(c.abduct_distance.x, c.abduct_distance.y)
		var x := cos(a) * r
		var z := sin(a) * r
		if Terrain.stream_distance(x, z) < 5.0 or Terrain.yard_distance(x, z) < 6.0 or Terrain.road_distance(x, z) < 4.0:
			continue
		var h := Terrain.height_at(x, z)
		if Terrain.water_level_at(x, z) > h - 0.2:
			continue
		return Vector3(x, h + 0.3, z)
	return Vector3(0, Terrain.height_at(0, 90) + 0.3, 90)


## Ein paar Dinge aus dem Rucksack liegen verstreut auf dem Weg (nie Einzelstücke wie W-17 oder Werkzeuge).
static func scatter_items(tree: SceneTree, from: Vector3, to: Vector3, n: int, rng: RandomNumberGenerator) -> Array:
	var drops := AlienDrops.get_for(tree)
	var out: Array = []
	if drops == null:
		return out
	var pool: Array = []
	for id: String in Inventory.items.keys():
		if Inventory.count(id) > 0 and GameMenus.can_discard(id):
			pool.append(id)
	for i in n:
		if pool.is_empty():
			break
		var id: String = pool[rng.randi() % pool.size()]
		Inventory.remove(id, 1)
		if Inventory.count(id) <= 0:
			pool.erase(id)
		var p := from.lerp(to, 0.35 + 0.6 * float(i + 1) / float(n + 1)) + Vector3(rng.randf_range(-1.5, 1.5), 0, rng.randf_range(-1.5, 1.5))
		p.y = Terrain.height_at(p.x, p.z) + 0.03
		drops.spawn(id, p, true)
		out.append(id)
	return out
