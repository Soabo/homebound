class_name CreatureSounds
extends RefCounted
## Geräusche der Kreatur aus Christians Aufnahmen (assets/audio/creature/<art>_NN.ogg).
## Kurze Laute (Schrei, Schmerz …) werden ganz abgespielt. Lange Aufnahmen (Atmen, Klicken)
## werden als zufällige Ausschnitte mit Ein- und Ausblenden gespielt, damit es nie gleich klingt.

const BASE_DIR := "res://assets/audio/creature"
const MAX_VARIANTS := 24
## Lange Klangflächen, aus denen Ausschnitte gespielt werden
const PHRASE_KINDS := ["breath", "breath_click", "click"]

static var _streams: Dictionary = {}
static var _last: Dictionary = {}


static func variants(kind: String) -> Array:
	if _streams.has(kind):
		return _streams[kind]
	var list: Array = []
	for i in range(1, MAX_VARIANTS + 1):
		var path := "%s/%s_%02d.ogg" % [BASE_DIR, kind, i]
		if not ResourceLoader.exists(path):
			break
		list.append(load(path))
	_streams[kind] = list
	return list


static func pick(kind: String) -> AudioStream:
	var list := variants(kind)
	if list.is_empty():
		return null
	var idx := randi() % list.size()
	if list.size() > 1 and idx == int(_last.get(kind, -1)):
		idx = (idx + 1 + randi() % (list.size() - 1)) % list.size()
	_last[kind] = idx
	return list[idx]


static func _player(parent: Node, stream: AudioStream, pos: Vector3, volume_db: float, pitch: float, max_distance: float) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.unit_size = 4.0
	p.max_distance = max_distance
	p.attenuation_filter_cutoff_hz = 6000.0
	parent.add_child(p)
	p.global_position = pos
	return p


## Kurzer Laut: shriek, pain, recoil, head_snap, step
static func play(parent: Node, kind: String, pos: Vector3, volume_db: float = 0.0, pitch: float = 1.0, max_distance: float = 60.0) -> void:
	var stream := pick(kind)
	if stream == null:
		return
	var p := _player(parent, stream, pos, volume_db, pitch, max_distance)
	p.play()
	p.finished.connect(p.queue_free)


## Zufälliger Ausschnitt aus einer langen Aufnahme (breath, breath_click, click).
## Gibt den Abspieler zurück, damit eine Kreatur ihn mitbewegen kann (wenn parent = Kreatur).
static func play_phrase(parent: Node, kind: String, pos: Vector3, volume_db: float = 0.0,
		duration: float = 4.0, max_distance: float = 22.0) -> AudioStreamPlayer3D:
	var stream := pick(kind)
	if stream == null:
		return null
	var length := stream.get_length()
	duration = minf(duration, length)
	var start := randf_range(0.0, maxf(0.0, length - duration))
	var p := _player(parent, stream, pos, -40.0, randf_range(0.92, 1.05), max_distance)
	p.unit_size = 2.5
	p.play(start)
	var fade := minf(0.6, duration * 0.25)
	var tw := p.create_tween()
	tw.tween_property(p, "volume_db", volume_db, fade)
	tw.tween_interval(maxf(0.0, duration - fade * 2.0))
	tw.tween_property(p, "volume_db", -40.0, fade)
	tw.tween_callback(p.queue_free)
	return p
