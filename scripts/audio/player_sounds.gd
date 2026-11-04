class_name PlayerSounds
extends RefCounted
## Geräusche des Spielers selbst aus Christians Aufnahmen (assets/audio/player/<art>_NN.ogg):
## drink, eat, die, heartbeat, breath (außer Atem), flashlight (Klick).
## Sie klingen "im Kopf" – ohne Richtung und Entfernung.

const BASE_DIR := "res://assets/audio/player"
const MAX_VARIANTS := 12

static var _streams: Dictionary = {}
static var _last: Dictionary = {}


static func pick(kind: String) -> AudioStream:
	if not _streams.has(kind):
		var list: Array = []
		for i in range(1, MAX_VARIANTS + 1):
			var path := "%s/%s_%02d.ogg" % [BASE_DIR, kind, i]
			if not ResourceLoader.exists(path):
				break
			list.append(load(path))
		_streams[kind] = list
	var list: Array = _streams[kind]
	if list.is_empty():
		return null
	var idx := randi() % list.size()
	if list.size() > 1 and idx == int(_last.get(kind, -1)):
		idx = (idx + 1) % list.size()
	_last[kind] = idx
	return list[idx]


## Ganzer Laut.
static func play(parent: Node, kind: String, volume_db: float = 0.0, pitch: float = 1.0) -> AudioStreamPlayer:
	var stream := pick(kind)
	if stream == null:
		return null
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = pitch
	parent.add_child(p)
	p.play()
	p.finished.connect(p.queue_free)
	return p


## Ausschnitt aus einer längeren Aufnahme mit weichem Ein- und Ausblenden.
static func play_phrase(parent: Node, kind: String, volume_db: float, duration: float, from_start: bool = false) -> AudioStreamPlayer:
	var stream := pick(kind)
	if stream == null:
		return null
	var length := stream.get_length()
	duration = minf(duration, length)
	var start := 0.0 if from_start else randf_range(0.0, maxf(0.0, length - duration))
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = -40.0
	parent.add_child(p)
	p.play(start)
	var fade := minf(0.4, duration * 0.2)
	var tw := p.create_tween()
	tw.tween_property(p, "volume_db", volume_db, fade)
	tw.tween_interval(maxf(0.0, duration - fade * 2.0))
	tw.tween_property(p, "volume_db", -40.0, fade)
	tw.tween_callback(p.queue_free)
	return p
