class_name FireCrackle
extends AudioStreamPlayer3D
## Prozedural erzeugtes Kaminfeuer: leises Rauschen plus zufälliges Knistern.
## Platzhalter, bis echte Sounds da sind (GDD Phase 5).

const RATE := 22050.0

var _playback: AudioStreamGeneratorPlayback
var _rng := RandomNumberGenerator.new()
var _rumble := 0.0
var _pop := 0.0
var _prev := 0.0


func _ready() -> void:
	if SoundBank.has_recording("fire"):
		# echte Aufnahme vom Lagerfeuer
		stream = SoundBank.get_sound("fire")
		volume_db = -6.0
		_base_db = -6.0
		unit_size = 2.5
		max_distance = 16.0
		play()
		return
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = RATE
	gen.buffer_length = 0.2
	stream = gen
	volume_db = -4.0
	_base_db = -4.0
	unit_size = 2.5
	max_distance = 16.0
	play()
	_playback = get_stream_playback()


var _base_db: float = -6.0


## Feuerstärke 0..1: leiser werden bis ganz still (Kaminfeuer brennt herunter).
func set_strength(s: float) -> void:
	if s <= 0.001:
		if playing:
			stop()
		return
	if not playing:
		play()
	volume_db = _base_db + linear_to_db(s)


func _process(_delta: float) -> void:
	if _playback == null:
		return
	var frames := _playback.get_frames_available()
	for i in frames:
		var white := _rng.randf() * 2.0 - 1.0
		_rumble += (white - _rumble) * 0.03
		if _rng.randf() < 0.0009:
			_pop = _rng.randf_range(0.3, 1.0)
		var crack := (_rng.randf() * 2.0 - 1.0) * _pop
		_pop *= 0.982
		var hp := crack - _prev
		_prev = crack
		var s := _rumble * 0.35 + hp * 0.45
		_playback.push_frame(Vector2(s, s))
