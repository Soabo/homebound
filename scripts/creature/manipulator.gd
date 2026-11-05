class_name Manipulator
extends Node3D
## Der Manipulator (Phase 8, GDD 9.3): eine sehr große, dünne Gestalt am Waldrand.
## Er greift nicht an – er lockt. Er ahmt Geräusche nach: Spieluhr, Klopfen, menschliche Schritte,
## sogar dein eigenes Atmen. Kommt der Spieler draußen zu nah, ist er weg – und die Kreatur
## steht hinter einem. Wer drinnen bleibt, hört ihn nach einer Weile verschwinden.
## Zu sehen ist er nur kurz: im Lichtkegel oder ganz aus der Nähe.

const LIFETIME := 100.0
const VANISH_DIST := 12.0

var _t: float = 0.0
var _lure_timer: float = 4.0
var _model: Node3D
var _eye: StandardMaterial3D
var _player: Player
var _gone: bool = false


func _ready() -> void:
	add_to_group("manipulator")
	_player = get_tree().get_first_node_in_group("player") as Player
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var a := rng.randf() * TAU
	var d := rng.randf_range(27.0, 33.0)
	global_position = Creature._ground(Vector3(cos(a) * d, 0, sin(a) * d))
	look_at(Vector3(0, global_position.y, 0), Vector3.UP)
	_build_model()
	get_tree().call_group("nature_ambience", "silence_for", LIFETIME)


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
	if _t > LIFETIME:
		_vanish(false)
		return
	_update_visibility()
	_lure_timer -= delta
	if _lure_timer <= 0.0:
		_lure_timer = randf_range(7.0, 12.0)
		_lure()
	# zu nah draußen: Falle schnappt zu
	if _player and not GameState.dead:
		var p := _player.global_position
		var outside := not Cabin.is_inside(p) and not Shed.is_inside(p)
		if outside and p.distance_to(global_position) < VANISH_DIST:
			_vanish(true)


## Nur im Lichtkegel der Uhr oder aus der Nähe sichtbar – meist ein flüchtiger Schatten.
func _update_visibility() -> void:
	if _player == null:
		return
	var cam := _player.camera.global_transform
	var to := (global_position + Vector3(0, 2.0, 0)) - cam.origin
	var d := to.length()
	var lit := _player.flashlight.visible and d < 30.0 and (-cam.basis.z).dot(to.normalized()) > 0.93
	_model.visible = lit or d < 16.0
	_eye.emission_energy_multiplier = 2.5 if lit else 0.6


func _lure() -> void:
	var at := global_position + Vector3(0, 1.5, 0)
	var scene := get_parent()
	match randi() % 5:
		0:
			SoundBank.play_at(scene, "music_box", at, 0.0, randf_range(0.95, 1.05))
		1:
			for i in 3:
				SoundBank.play_at(scene, "knock", at, 2.0, 0.9)
		2:
			# menschliche Schritte im Laub
			for i in 5:
				get_tree().create_timer(i * 0.5).timeout.connect(func() -> void: Footsteps.play(scene, global_position, "walk", 4.0))
		3:
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
		4:
			SoundBank.play_at(scene, "radio", at, -2.0, 0.85)


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
