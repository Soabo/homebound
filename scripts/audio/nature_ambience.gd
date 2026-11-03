class_name NatureAmbience
extends Node
## Lebendige Natur: Vögel am Tag, Grillen und Eulen in der Nacht.
## Ist etwas Fremdes in der Nähe, verstummen die Tiere (GDD 3.6 / 9.6) –
## Stille ist hier ein Warnsignal.

const CREATURE_SILENCE_RADIUS := 32.0

var _crickets: AudioStreamPlayer
var _birds: AudioStreamPlayer
var _owl_timer: float = 20.0
var _silence: float = 0.0  ## 0 = normal, 1 = völlige Stille
var _forced_silence_until: float = 0.0
var _t: float = 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	name = "NatureAmbience"
	add_to_group("nature_ambience")
	_rng.randomize()
	_crickets = _loop("crickets")
	_birds = _loop("birds")


func _loop(id: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = SoundBank.get_sound(id)
	p.volume_db = -80.0
	add_child(p)
	p.play()
	return p


## Für Ereignisse: Die Tiere verstummen für einige Sekunden.
func silence_for(seconds: float) -> void:
	_forced_silence_until = _t + seconds


func _process(delta: float) -> void:
	_t += delta
	var night := TimeManager.is_night()
	var hour := TimeManager.hour
	var dawn_dusk := hour > 5.5 and hour < 8.0 or hour > 18.0 and hour < 20.0
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var indoor := player != null and (Cabin.is_inside(player.global_position) or Shed.is_inside(player.global_position))

	var target_silence := 0.0
	var creature := ThreatDirector.creature as Node3D
	if is_instance_valid(creature) and player and creature.global_position.distance_to(player.global_position) < CREATURE_SILENCE_RADIUS:
		target_silence = 1.0
	if _t < _forced_silence_until:
		target_silence = 1.0
	_silence = move_toward(_silence, target_silence, delta * (0.5 if target_silence > _silence else 0.08))

	var indoor_db := -10.0 if indoor else 0.0
	var cricket_vol := (1.0 if night else (0.4 if dawn_dusk else 0.0)) * (1.0 - _silence)
	var bird_vol := (0.0 if night else (0.5 if dawn_dusk else 1.0)) * (1.0 - _silence)
	_crickets.volume_db = linear_to_db(maxf(cricket_vol, 0.0001)) - 8.0 + indoor_db
	_birds.volume_db = linear_to_db(maxf(bird_vol, 0.0001)) - 12.0 + indoor_db

	if night and _silence < 0.3:
		_owl_timer -= delta
		if _owl_timer <= 0.0:
			_owl_timer = _rng.randf_range(35.0, 90.0)
			var a := _rng.randf() * TAU
			var p := Vector3(cos(a) * 35.0, 0, sin(a) * 35.0)
			p.y = Terrain.height_at(p.x, p.z) + 8.0
			SoundBank.play_at(get_tree().current_scene, "owl", p, -4.0, _rng.randf_range(0.9, 1.05))
