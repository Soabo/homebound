class_name HideHunt
extends Node3D
## Sie sucht das Versteck ab (Christian 23.11.2026: „Verstecke lernen“). Der ThreatDirector schickt sie, wenn man
## nachts lange oder immer wieder im selben Versteck sitzt (`ThreatDirector._check_hiding`).
## Ablauf: Schritte durchs Haus bis vor den Schrank/Spind → sie schnüffelt (Atem anhalten mit [Alt]!) → rüttelt an
## der Tür → reißt sie auf (Chance wächst mit jeder Benutzung des Verstecks und mit hörbarem Atem) oder zieht ab.
## Wer nicht mehr im Versteck ist, wenn sie davorsteht, wird geschlagen. Werte: ThreatConfig hide_* (wann, wie oft
## aufreißen), CreatureConfig hide_* (Tempo, Schaden).

enum Step { WALK, SNIFF, RATTLE, LEAVE }

var spot: HideSpot
var uses: int = 0
var tcfg: ThreatConfig
var ccfg: CreatureConfig
var step: int = Step.WALK
var breath_heard: float = 0.0     ## Sekunden hörbarer Atem vor dem Versteck
var torn: bool = false            ## Tür aufgerissen (für Tests)
var _player: Player
var _model: Node3D
var _t: float = 0.0
var _step_t: float = 0.0
var _rattles_left: int = 0
var _told := false
var _rng := RandomNumberGenerator.new()
static var current: HideHunt = null


static func start(scene: Node, at_spot: HideSpot, n_uses: int, threat_cfg: ThreatConfig) -> HideHunt:
	if is_instance_valid(current) or at_spot == null:
		return null
	var h := HideHunt.new()
	h.name = "HideHunt"
	h.spot = at_spot
	h.uses = n_uses
	h.tcfg = threat_cfg
	h.ccfg = CreatureConfig.get_default()
	scene.add_child(h)
	return h


func _ready() -> void:
	current = self
	_rng.randomize()
	_player = get_tree().get_first_node_in_group("player") as Player
	_model = Node3D.new()
	add_child(_model)
	CreatureModel.build(_model)
	# Start: an der Haustür (Hütte) bzw. vor der Schuppentür – ein Stück weg vom Versteck
	var front := spot.front_point(1.0)
	var out := front - spot.global_position
	out.y = 0.0
	var start := front + out.normalized() * 5.0
	if Cabin.is_inside(spot.global_position):
		# aus dem Zimmer heraus auf das Versteck zu (so weit es im Haus bleibt), sonst von der Haustür
		start = Vector3(-3.0, Cabin.FLOOR_Y, 3.6)
		for d: float in [3.0, 2.4, 1.8]:
			var q := front + out.normalized() * d
			if Cabin.is_inside(q + Vector3(0, 0.5, 0)):
				start = q
				break
	start.y = front.y
	global_position = start
	_rattles_left = _rng.randi_range(ccfg.hide_rattles.x, ccfg.hide_rattles.y)
	SoundBank.play_at(get_parent(), "door_open", start + Vector3(0, 1.0, 0), -4.0, 0.8)
	EventBus.fear_spike.emit(0.5)


func _exit_tree() -> void:
	if current == self:
		current = null


func _process(delta: float) -> void:
	if not is_instance_valid(spot) or _player == null or GameState.dead:
		queue_free()
		return
	_t += delta
	var front := spot.front_point(0.95)
	match step:
		Step.WALK:
			var to := front - global_position
			to.y = 0.0
			if to.length() > 0.15:
				global_position += to.normalized() * minf(ccfg.hide_walk_speed * delta, to.length())
				_face(global_position + to)
				_step_t -= delta
				if _step_t <= 0.0:
					_step_t = 0.85
					CreatureSounds.play(get_parent(), "step", global_position, -3.0, 0.8)
					if Stealth.creaky_board(global_position) and _rng.randf() < 0.5:
						SoundBank.play_at(get_parent(), "board_creak", global_position, -2.0, 0.8)
			else:
				_enter(Step.SNIFF, _rng.randf_range(ccfg.hide_sniff_time.x, ccfg.hide_sniff_time.y))
				CreatureSounds.play_phrase(get_parent(), "breath", global_position + Vector3(0, 1.8, 0), 2.0, _step_t, 10.0)
		Step.SNIFF, Step.RATTLE:
			_face(spot.global_position)
			# vor dem Versteck: wer nicht mehr drin ist, wird gesehen
			if not _player.is_hidden():
				_strike_open()
				return
			if not _told:
				_told = true
				EventBus.notify("Es steht direkt vor dir. [Alt] Atem anhalten!", 3.0)
			if not _player.holding_breath and Stealth.breath_radius(_player) > 0.5:
				breath_heard += delta
			_step_t -= delta
			if step == Step.SNIFF and fmod(_t, 2.2) < delta:
				CreatureSounds.play_phrase(get_parent(), "click", global_position + Vector3(0, 1.8, 0), -6.0, 1.2, 12.0)
			if step == Step.RATTLE and _step_t <= 0.0 and _rattles_left > 0:
				_rattles_left -= 1
				_step_t = _rng.randf_range(1.2, 2.2)
				spot.rattle()
				EventBus.fear_spike.emit(0.9)
			if _step_t <= 0.0:
				if step == Step.SNIFF:
					_enter(Step.RATTLE, 0.3)
				elif _rattles_left <= 0:
					_decide()
		Step.LEAVE:
			var away := global_position - spot.global_position
			away.y = 0.0
			global_position += away.normalized() * ccfg.hide_walk_speed * delta
			_face(global_position + away)
			if _t > 4.0:
				Apparition.flash(get_parent(), global_position + Vector3(0, 1.3, 0))
				queue_free()


func _enter(s: int, secs: float) -> void:
	step = s
	_step_t = secs
	_t = 0.0


## Aufreißen oder abziehen?
func tear_chance() -> float:
	return clampf(tcfg.hide_tear_base + float(uses) * tcfg.hide_tear_per_use + breath_heard * tcfg.hide_tear_per_breath, 0.0, tcfg.hide_tear_max)


func _decide() -> void:
	if _rng.randf() < tear_chance():
		torn = true
		spot.force_open()
		CreatureSounds.play(get_parent(), "shriek", global_position + Vector3(0, 1.8, 0), 6.0)
		EventBus.screen_shake.emit(0.8)
		EventBus.fear_spike.emit(1.0)
		_player.take_damage(ccfg.hide_tear_damage, global_position + Vector3(0, 1.4, 0), "hide_found")
		EventBus.notify("Es reißt die Tür auf! Es kennt dein Versteck.", 4.0)
		_vanish_soon(1.2)
	else:
		EventBus.notify("Die Schritte entfernen sich …", 2.5)
		_enter(Step.LEAVE, 0.0)


func _strike_open() -> void:
	CreatureSounds.play(get_parent(), "shriek", global_position + Vector3(0, 1.8, 0), 6.0)
	_face(_player.global_position)
	if _player.global_position.distance_to(global_position) < 4.0:
		_player.take_damage(ccfg.hide_open_damage, global_position + Vector3(0, 1.4, 0), "hide_found")
	_vanish_soon(0.8)


func _vanish_soon(secs: float) -> void:
	step = -1
	await get_tree().create_timer(secs).timeout
	if is_inside_tree():
		Apparition.flash(get_parent(), global_position + Vector3(0, 1.3, 0), true)
		queue_free()


func _face(at: Vector3) -> void:
	var d := at - global_position
	d.y = 0.0
	if d.length() > 0.05:
		look_at(global_position + d.normalized(), Vector3.UP)
