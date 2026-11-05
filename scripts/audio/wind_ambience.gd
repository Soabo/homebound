class_name WindAmbience
extends AudioStreamPlayer
## Prozeduraler Wind mit Böen. Drinnen gedämpft, nachts etwas lauter.
## Platzhalter, bis echte Atmosphären-Sounds da sind (GDD Phase 5).

const RATE := 22050.0

var _playback: AudioStreamGeneratorPlayback
var _rng := RandomNumberGenerator.new()
var _noise := FastNoiseLite.new()
var _brown_l := 0.0
var _brown_r := 0.0
var _lp_l := 0.0
var _lp_r := 0.0
var _gain := 0.0
var _cutoff := 0.05
var _t := 0.0


var _gusts: AudioStreamPlayer
var _recorded := false


func _ready() -> void:
	name = "WindAmbience"
	_noise.frequency = 0.05
	if SoundBank.has_recording("wind"):
		# echte Aufnahmen: ruhiger Wind als Grund, Böen kommen und gehen darüber
		_recorded = true
		stream = SoundBank.get_sound("wind")
		volume_db = -16.0
		play()
		if SoundBank.has_recording("gusts"):
			_gusts = AudioStreamPlayer.new()
			_gusts.stream = SoundBank.get_sound("gusts")
			_gusts.volume_db = -60.0
			add_child(_gusts)
			_gusts.play()
		return
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = RATE
	gen.buffer_length = 0.25
	stream = gen
	volume_db = -22.0
	_noise.frequency = 0.05
	play()
	_playback = get_stream_playback()


func _process(delta: float) -> void:
	if _recorded:
		_t += delta
		var g := smoothstep(0.45, 0.9, _noise.get_noise_1d(_t * 4.0) * 0.5 + 0.5)
		var inside := _player_indoors()
		var night := 3.0 if TimeManager.is_night() else 0.0
		var damp := -14.0 if inside else 0.0
		volume_db = lerpf(volume_db, -17.0 + night + damp, delta)
		if _gusts:
			_gusts.volume_db = lerpf(_gusts.volume_db, linear_to_db(maxf(g, 0.0001)) - 14.0 + night + damp, delta * 2.0)
		return
	if _playback == null:
		return
	_t += delta
	# Böen kommen und gehen – dazwischen ist es fast still.
	var n := _noise.get_noise_1d(_t * 4.0) * 0.5 + 0.5
	var gust := smoothstep(0.35, 0.85, n)
	var indoor := _player_indoors()
	var target_gain := (0.08 + gust) * (1.2 if TimeManager.is_night() else 0.8) * (0.25 if indoor else 1.0)
	var target_cutoff := 0.018 if indoor else 0.05 + gust * 0.03
	var frames := _playback.get_frames_available()
	for i in frames:
		_gain += (target_gain - _gain) * 0.0004
		_cutoff += (target_cutoff - _cutoff) * 0.0004
		_brown_l = (_brown_l + 0.02 * (_rng.randf() * 2.0 - 1.0)) / 1.02
		_brown_r = (_brown_r + 0.02 * (_rng.randf() * 2.0 - 1.0)) / 1.02
		_lp_l += (_brown_l * 3.5 - _lp_l) * _cutoff * 4.0
		_lp_r += (_brown_r * 3.5 - _lp_r) * _cutoff * 4.0
		_playback.push_frame(Vector2(_lp_l, _lp_r) * _gain)


func _player_indoors() -> bool:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return false
	return Cabin.is_inside(player.global_position) or Shed.is_inside(player.global_position)
