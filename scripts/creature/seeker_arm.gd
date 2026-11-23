class_name SeekerArm
extends Node3D
## Ein langer Arm des Suchers, der durch Wand, Boden oder Decke ins Haus bricht (Christian 23.11.:
## „auch von der Decke oder aus dem Boden – ein wenig unberechenbar“). Er tastet nach dir; berührt die Hand dich,
## verletzt sie (nie unter SeekerConfig.min_health) und zieht sich zurück. Uhr-LED drauf oder ein Schlag = zurück.
## Wo und wann: Seeker._house_tick. Werte: data/creatures/seeker.tres (reach_*).

var normal := Vector3.UP          ## zeigt aus der Fläche ins Zimmer
var cfg: SeekerConfig
var _player: Player
var _root: Node3D                 ## Ansatz in der Fläche
var _j1: Node3D
var _hand: Node3D
var _out := 0.0
var _t := 0.0
var _lit_t := 0.0
var _leaving := false
var _hurt := false
var _rng := RandomNumberGenerator.new()
var _wobble := Vector3.ZERO
const SEG1 := 0.62
const SEG2 := 0.58


## Sucht eine Stelle nahe beim Spieler (Wand, Boden oder Decke) und lässt dort einen Arm herausbrechen.
## behind = möglichst hinter dem Spieler. null = keine passende Stelle gefunden.
static func spawn(scene: Node, player: Player, c: SeekerConfig, rng: RandomNumberGenerator, behind: bool) -> SeekerArm:
	var space := player.get_world_3d().direct_space_state
	var chest := player.global_position + Vector3(0, 1.1, 0)
	var back := player.camera.global_basis.z
	back.y = 0.0
	back = back.normalized()
	for attempt in 10:
		var w := c.reach_weights
		var roll := rng.randf() * (w.x + w.y + w.z)
		var kind := "wall" if roll < w.x else ("floor" if roll < w.x + w.y else "ceiling")
		var a := rng.randf() * TAU
		var dir := Vector3(cos(a), 0.0, sin(a))
		if behind and back.length() > 0.1:
			dir = back.rotated(Vector3.UP, rng.randf_range(-0.9, 0.9))
		var from := chest
		var to := chest + dir * 4.0
		if kind != "wall":
			var r := rng.randf_range(1.1, 2.3)
			from = chest + dir * r
			to = from + Vector3(0, -3.0 if kind == "floor" else 3.0, 0)
			# der Startpunkt muss frei vom Spieler aus erreichbar sein (nicht hinter einer Wand)
			if not Stealth.line_clear(player.get_world_3d(), chest, from, [player.get_rid()]):
				continue
		var q := PhysicsRayQueryParameters3D.create(from, to)
		q.exclude = [player.get_rid()]
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			continue
		var p: Vector3 = hit["position"]
		var n: Vector3 = hit["normal"]
		var col := hit["collider"] as Node
		if col and col.is_in_group("see_through"):
			continue   # nicht durch Glas
		if kind == "wall" and (absf(n.y) > 0.35 or p.distance_to(chest) < 0.9):
			continue
		if kind == "floor" and n.y < 0.7:
			continue
		if kind == "ceiling" and n.y > -0.7:
			continue
		if not Cabin.is_inside(p + n * 0.3):
			continue
		var arm := SeekerArm.new()
		arm.normal = n.normalized()
		arm.cfg = c
		scene.add_child(arm)
		arm.global_position = p
		EventBus.fear_spike.emit(0.75)
		return arm
	return null


func _ready() -> void:
	add_to_group("seeker_arm")
	_rng.randomize()
	_wobble = Vector3(_rng.randf() * 10.0, _rng.randf() * 10.0, _rng.randf() * 10.0)
	_player = get_tree().get_first_node_in_group("player") as Player
	# Ausrichtung: lokales +y = aus der Fläche heraus
	var y := normal
	var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
	basis = Basis(x, y, x.cross(y).normalized())
	var skin := FleshKit.skin(Color(0.44, 0.39, 0.41), 0.55, 0.11)
	var pale := FleshKit.skin(Color(0.5, 0.45, 0.44), 0.55, 0.11)
	var nail := BuildKit.color_mat(Color(0.1, 0.09, 0.08), 0.2, 0.2)
	var hole := BuildKit.color_mat(Color(0.02, 0.015, 0.015), 1.0)
	# Loch mit splittrigem Rand
	var disc := BuildKit.cylinder(self, 0.16, 0.012, Vector3(0, 0.004, 0), hole, false, Vector3.ZERO, -1.0, 9)
	disc.name = "Hole"
	for k in 7:
		var aa := k * TAU / 7.0 + _rng.randf() * 0.3
		BuildKit.box(self, Vector3(0.025, 0.012, _rng.randf_range(0.08, 0.16)), Vector3(cos(aa) * 0.17, 0.008, sin(aa) * 0.17),
				BuildKit.tex_mat("planks_h", 0.6, Color(0.6, 0.5, 0.42)), false, Vector3(_rng.randf_range(-25, 25), -rad_to_deg(aa) + 90.0, 0))
	_root = Node3D.new()
	add_child(_root)
	FleshKit.limb(_root, [Vector3(0, -0.3, 0), Vector3(0.01, SEG1 * 0.5, 0.01), Vector3(0, SEG1, 0)], [0.06, 0.048, 0.04], skin, 10)
	FleshKit.spindle(_root, Vector3(0, 0.0, 0.03), Vector3(0, SEG1 * 0.85, 0.03), 0.034, skin, 0.4, 8)
	_j1 = Node3D.new()
	_j1.position = Vector3(0, SEG1, 0)
	_root.add_child(_j1)
	FleshKit.bulb(_j1, Vector3(0, 0, -0.018), Vector3(0.04, 0.045, 0.033), pale)
	FleshKit.limb(_j1, [Vector3.ZERO, Vector3(0, SEG2 * 0.5, 0.02), Vector3(0, SEG2, 0.03)], [0.042, 0.034, 0.027], skin, 10)
	_hand = Node3D.new()
	_hand.position = Vector3(0, SEG2, 0.03)
	_j1.add_child(_hand)
	_hand.scale = Vector3.ONE * 1.7   # große, lange Hand
	FleshKit.limb(_hand, [Vector3.ZERO, Vector3(0, 0.05, 0.005), Vector3(0, 0.1, 0.01)], [Vector2(0.024, 0.012), Vector2(0.03, 0.011), Vector2(0.032, 0.01)], skin, 8)
	for f in 5:
		var fx := (f - 2.0) * 0.014
		var thumb := f == 0
		var lens := [0.06, 0.05, 0.045] if thumb else [0.11, 0.1, 0.085]
		FleshKit.finger(_hand, Vector3(fx, 0.1, 0.01), Vector3(fx * 1.6 + (-0.3 if thumb else 0.0), 1.0, 0.15), Vector3(1, 0, 0), lens, 12.0, 0.009, skin, nail, 0.03)
	_root.position = Vector3(0, -(SEG1 + SEG2 + 0.3), 0)   # steckt noch in der Fläche
	# Treffer mit Axt/Faust: Bereich um die Hand
	var area := Area3D.new()
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 0.25
	cs.shape = sh
	area.add_child(cs)
	_hand.add_child(area)
	Fx.burst(get_parent(), global_position + normal * 0.05, "wood", normal, 1.2)
	SoundBank.play_at(get_parent(), "wood_crack", global_position, 0.0, 0.85)
	SoundBank.play_rec(get_parent(), "seeker_chitter", global_position, -6.0, 18.0)
	EventBus.screen_shake.emit(0.12)


## Wo die Hand gerade ist (Spitze der Finger ungefähr).
func hand_position() -> Vector3:
	return _hand.global_position + _hand.global_basis.y * 0.25


func _process(delta: float) -> void:
	_t += delta
	if _leaving:
		_out = maxf(_out - delta * 2.4, 0.0)
	else:
		_out = minf(_out + delta * 1.1, 1.0)
	var e := smoothstep(0.0, 1.0, _out)
	_root.position = Vector3(0, -(SEG1 + SEG2 + 0.3) * (1.0 - e), 0)
	if _leaving and _out <= 0.0:
		_leave_hole()
		queue_free()
		return
	if _player == null or not is_instance_valid(_player):
		return
	# zum Spieler tasten: Oberarm zielt grob hin, Unterarm und Hand schlängeln und greifen
	var target := _player.global_position + Vector3(0, 1.0, 0)
	var local_t := global_basis.inverse() * (target - global_position)
	var aim := local_t.normalized() if local_t.length() > 0.01 else Vector3.UP
	aim = Vector3.UP.lerp(aim, 0.75 * e).normalized()
	var wav := Vector3(sin(_t * 1.7 + _wobble.x), 0.0, sin(_t * 1.3 + _wobble.z)) * 0.18
	_root.basis = Basis(Quaternion(Vector3.UP, (aim + wav).normalized()))
	var in_root := (_root.global_basis.inverse() * (target - _j1.global_position)).normalized()
	_j1.basis = Basis(Quaternion(Vector3.UP, Vector3.UP.lerp(in_root, 0.7 * e).normalized() + Vector3(sin(_t * 2.3 + _wobble.y), 0, cos(_t * 1.9)) * 0.15).normalized())
	_hand.rotation = Vector3(sin(_t * 3.1) * 0.35 - 0.2, sin(_t * 2.2) * 0.3, sin(_t * 2.7) * 0.25)
	if _leaving:
		return
	if _t > cfg.reach_time:
		retreat()
		return
	# Uhr-LED auf die Hand: zuckt zurück
	if _player.light_shining() and not _player.hands.screen_mode:
		var to := hand_position() - _player.camera.global_position
		if to.length() < 9.0 and (-_player.camera.global_basis.z).dot(to.normalized()) > 0.93:
			_lit_t += delta
			if _lit_t >= cfg.reach_led_time:
				CreatureSounds.play(get_parent(), "recoil", hand_position(), -4.0, 1.3)
				retreat()
				return
	# Berührung: verletzt und zieht sich zurück
	if not _hurt and e > 0.7:
		var hp := hand_position()
		var d := minf(hp.distance_to(_player.global_position + Vector3(0, 1.0, 0)), hp.distance_to(_player.camera.global_position))
		if d < 0.5 and not _player.is_hidden():
			_hurt = true
			Seeker.hurt_player(_player, cfg.reach_damage, hp, "seeker_arm")
			EventBus.screen_shake.emit(0.4)
			SoundBank.play_rec(get_parent(), "seeker_chitter", hp, 0.0, 20.0)
			retreat()


## Axt oder Faust: die Hand zuckt zurück.
func on_melee_hit(_kind: String) -> void:
	CreatureSounds.play(get_parent(), "recoil", hand_position(), 0.0, 1.2)
	retreat()


func retreat() -> void:
	if _leaving:
		return
	_leaving = true
	SoundBank.play_at(get_parent(), "scratch", global_position, -6.0, 0.8)


## Zurück bleibt eine Weile ein dunkles, splittriges Loch.
func _leave_hole() -> void:
	var h := Node3D.new()
	h.name = "SeekerHole"
	get_parent().add_child(h)
	h.global_transform = global_transform
	for c in get_children():
		if c != _root and c is MeshInstance3D:
			c.reparent(h)
	h.create_tween().tween_interval(90.0).finished.connect(h.queue_free)
