class_name Manipulator
extends Node3D
## Der Manipulator (Phase 8, GDD 9.3): eine sehr große, dünne Gestalt am Waldrand.
## Er greift nicht an – er lockt. Er ahmt Geräusche nach: Spieluhr, Klopfen, menschliche Schritte,
## sogar dein eigenes Atmen. Kommt der Spieler draußen zu nah, ist er weg – und die Kreatur
## steht hinter einem. Wer drinnen bleibt, hört ihn nach einer Weile verschwinden.
## Zu sehen ist er nur kurz: im Lichtkegel oder ganz aus der Nähe.
## Unberechenbar: Er wechselt ungesehen die Stelle, kommt manchmal Stück für Stück näher, schweigt
## manchmal lange, und er ahmt Geräusche deines eigenen Hauses nach (Tür, Lichtschalter, Holzhacken …).

## Werte (Abstände, Zeiten, Lock-Geräusche) in data/creatures/manipulator.tres
var cfg: ManipulatorConfig = ManipulatorConfig.get_default()

var _t: float = 0.0
var _lure_timer: float = 4.0
var _model: Node3D
var _eye: StandardMaterial3D
var _player: Player
var _gone: bool = false
var _lifetime: float = 100.0
var _move_timer: float = 25.0
var _approach: bool = false
var _silent_until: float = 0.0
var _last_lure: String = ""
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group("manipulator")
	_player = get_tree().get_first_node_in_group("player") as Player
	_rng.randomize()
	_lifetime = _rng.randf_range(cfg.lifetime.x, cfg.lifetime.y)
	_approach = _rng.randf() < cfg.approach_chance
	# manchmal steht er erst lange still da, bevor er anfängt
	_silent_until = _rng.randf_range(cfg.silent_start.x, cfg.silent_start.y) if _rng.randf() < cfg.silent_start_chance else 0.0
	_lure_timer = _rng.randf_range(cfg.first_lure_after.x, cfg.first_lure_after.y)
	_move_timer = _rng.randf_range(cfg.relocate_interval.x, cfg.relocate_interval.y)
	_place(_rng.randf() * TAU, _rng.randf_range(cfg.distance.x, cfg.distance.y))
	_build_model()
	get_tree().call_group("nature_ambience", "silence_for", _lifetime)


func _place(angle: float, dist: float) -> void:
	global_position = Creature._ground(Vector3(cos(angle) * dist, 0, sin(angle) * dist))
	look_at(Vector3(0, global_position.y, 0), Vector3.UP)


## Ungesehen an eine andere Stelle wechseln – beim Annähern jedes Mal ein Stück näher.
func _relocate() -> void:
	var a := atan2(global_position.z, global_position.x) + _rng.randf_range(0.6, 1.6) * (1.0 if _rng.randf() < 0.5 else -1.0)
	var d := Vector2(global_position.x, global_position.z).length()
	d = maxf(d - _rng.randf_range(cfg.approach_step.x, cfg.approach_step.y), cfg.approach_min_distance) if _approach else _rng.randf_range(cfg.distance.x, cfg.distance.y)
	_place(a, d)


func _build_model() -> void:
	_model = Node3D.new()
	add_child(_model)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.03, 0.03, 0.035)
	dark.roughness = 0.9
	dark.rim_enabled = true
	dark.rim = 0.4
	dark.rim_tint = 0.2
	# sehr lange Beine, schmaler Rumpf leicht gebeugt, Arme bis unter die Knie
	for s: float in [-1.0, 1.0]:
		BuildKit.cylinder(_model, 0.05, 1.6, Vector3(s * 0.1, 0.8, 0), dark, false, Vector3.ZERO, 0.035, 6)
		BuildKit.cylinder(_model, 0.035, 1.9, Vector3(s * 0.27, 1.55, -0.05), dark, false, Vector3(-4, 0, s * 4), 0.02, 6)
		BuildKit.cylinder(_model, 0.012, 0.25, Vector3(s * 0.33, 0.48, -0.06), dark, false, Vector3(0, 0, s * 8), 0.004, 4)
	BuildKit.lathe(_model, PackedVector2Array([Vector2(0.0, 1.55), Vector2(0.12, 1.6), Vector2(0.09, 2.0), Vector2(0.17, 2.4), Vector2(0.06, 2.55), Vector2(0.0, 2.56)]),
			Vector3.ZERO, dark, 8, Vector3(-6, 0, 0))
	BuildKit.cylinder(_model, 0.03, 0.22, Vector3(0, 2.65, -0.05), dark, false, Vector3(-10, 0, 0), -1.0, 6)
	BuildKit.sphere(_model, 0.11, Vector3(0, 2.86, -0.07), dark, Vector3(0.85, 1.35, 0.9), 10)
	# senkrechter, schwach leuchtender Schlitz statt Gesicht
	_eye = BuildKit.emissive_mat(Color(0.95, 0.9, 0.75), 0.0)
	BuildKit.box(_model, Vector3(0.012, 0.13, 0.01), Vector3(0, 2.87, 0.025), _eye, false)
	_model.visible = false


func _process(delta: float) -> void:
	if _gone:
		return
	_t += delta
	if _t > _lifetime:
		_vanish(false)
		return
	_update_visibility()
	_move_timer -= delta
	if _move_timer <= 0.0 and not _model.visible:
		_move_timer = _rng.randf_range(cfg.relocate_interval.x, cfg.relocate_interval.y)
		_relocate()
	_lure_timer -= delta
	if _lure_timer <= 0.0 and _t > _silent_until:
		_lure_timer = _rng.randf_range(cfg.lure_interval.x, cfg.lure_interval.y)
		_lure()
		# ab und zu zwei Geräusche kurz hintereinander
		if _rng.randf() < cfg.double_lure_chance:
			_lure_timer = _rng.randf_range(1.5, 3.0)
	# zu nah draußen: Falle schnappt zu
	if _player and not GameState.dead:
		var p := _player.global_position
		var outside := not Cabin.is_inside(p) and not Shed.is_inside(p)
		if outside and p.distance_to(global_position) < cfg.vanish_distance:
			_vanish(true)


## Nur im Lichtkegel der Uhr oder aus der Nähe sichtbar – meist ein flüchtiger Schatten.
func _update_visibility() -> void:
	if _player == null:
		return
	var cam := _player.camera.global_transform
	var to := (global_position + Vector3(0, 2.0, 0)) - cam.origin
	var d := to.length()
	var lit := _player.light_shining() and d < cfg.flashlight_distance and (-cam.basis.z).dot(to.normalized()) > 0.93
	_model.visible = lit or d < cfg.visible_distance
	_eye.emission_energy_multiplier = 2.5 if lit else 0.6


func _lure() -> void:
	var at := global_position + Vector3(0, 1.5, 0)
	var scene := get_parent()
	var lures := cfg.lures
	if lures.is_empty():
		return
	var kind: String = lures[_rng.randi() % lures.size()]
	if kind == _last_lure and lures.size() > 1:
		kind = lures[(lures.find(kind) + 1 + _rng.randi() % (lures.size() - 1)) % lures.size()]
	_last_lure = kind
	match kind:
		"music_box":
			SoundBank.play_at(scene, "music_box", at, 0.0)
		"knock":
			SoundBank.play_at(scene, "knock", at, 2.0)
		"steps":
			# menschliche Schritte im Laub
			for i in _rng.randi_range(3, 7):
				get_tree().create_timer(i * 0.5).timeout.connect(func() -> void:
					if is_instance_valid(self):
						Footsteps.play(scene, global_position, "walk", 4.0))
		"breath":
			# ahmt dein eigenes Atmen nach – aus dem Wald
			var p := AudioStreamPlayer3D.new()
			p.stream = PlayerSounds.pick("breath")
			p.volume_db = 0.0
			p.unit_size = 6.0
			p.max_distance = 50.0
			scene.add_child(p)
			p.global_position = at
			p.play(randf() * 2.0)
			get_tree().create_timer(3.5).timeout.connect(p.queue_free)
		"radio":
			SoundBank.play_at(scene, "radio", at, -2.0)
		_:
			# Geräusche aus deinem eigenen Haus – nur kommen sie aus dem Wald
			SoundBank.play_at(scene, kind, at, 2.0)


func _vanish(ambush: bool) -> void:
	_gone = true
	_model.visible = false
	CreatureSounds.play_phrase(get_parent(), "click", global_position + Vector3(0, 2.5, 0), -4.0, 1.5)
	if ambush and _player:
		# hinter dem Spieler, Richtung Haus abgeschnitten
		var back := _player.global_transform.basis.z
		back.y = 0.0
		ThreatDirector.spawn_ambush(_player.global_position + back.normalized() * 11.0)
	get_tree().create_timer(2.0).timeout.connect(queue_free)
