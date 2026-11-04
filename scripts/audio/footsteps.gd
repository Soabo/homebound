class_name Footsteps
extends RefCounted
## Schrittgeräusche des Spielers aus echten Aufnahmen (assets/audio/steps/<untergrund>/<gangart>_NN.ogg).
## Die Aufnahmen wurden mit tools/audio/slice.py in einzelne Schritte geschnitten.
## Der Untergrund ergibt sich aus der Position (Hütte, Teppich, Veranda, Grundstück, Wald).

const BASE_DIR := "res://assets/audio/steps"
const SURFACES := ["wood", "carpet", "porch", "grass", "forest"]
const GAITS := ["sneak", "walk", "run"]
const MAX_VARIANTS := 24

## Lautstärke je Gangart und Untergrund (dB). Die Aufnahmen sind gleich laut normiert,
## damit hier allein das Spiel entscheidet, wie laut ein Untergrund klingt.
const GAIT_DB := {"sneak": -21.0, "walk": -14.0, "run": -9.0}
const SURFACE_DB := {"wood": 0.0, "carpet": -6.0, "porch": 1.5, "grass": -3.0, "forest": -1.5}

## Teppiche in der Hütte (x-min, z-min, x-max, z-max)
const RUGS := [
	Rect2(-4.6, 0.6, 2.2, 2.3),   # Wohnzimmer
	Rect2(-4.2, -2.3, 1.6, 1.0),  # Schlafzimmer
]
## Veranda samt Treppe
const PORCH := Rect2(-5.7, 4.5, 7.0, 3.1)
## Grundstück innerhalb des Zauns: dort wächst gemähtes Gras, draußen Waldboden
const YARD := Rect2(-20.0, -16.0, 42.0, 34.0)

static var _streams: Dictionary = {}
static var _last: Dictionary = {}


static func surface_at(p: Vector3) -> String:
	if Shed.is_inside(p):
		return "wood"
	if Cabin.is_inside(p):
		var flat := Vector2(p.x, p.z)
		for r: Rect2 in RUGS:
			if r.has_point(flat):
				return "carpet"
		return "wood"
	if p.y > 0.08 and PORCH.has_point(Vector2(p.x, p.z)):
		return "porch"
	if CornField.is_inside(p.x, p.z):
		return "forest"  # trockene Erde und raschelndes Laub
	if YARD.has_point(Vector2(p.x, p.z)):
		return "grass"
	return "forest"


static func variants(surface: String, gait: String) -> Array:
	var key := surface + "/" + gait
	if _streams.has(key):
		return _streams[key]
	var list: Array = []
	for i in range(1, MAX_VARIANTS + 1):
		var path := "%s/%s/%s_%02d.ogg" % [BASE_DIR, surface, gait, i]
		if not ResourceLoader.exists(path):
			break
		list.append(load(path))
	_streams[key] = list
	return list


## Zufälliger Schritt, aber nie zweimal hintereinander derselbe.
static func pick(surface: String, gait: String) -> AudioStream:
	var list := variants(surface, gait)
	if list.is_empty():
		return null
	var key := surface + "/" + gait
	var idx := randi() % list.size()
	if list.size() > 1 and idx == int(_last.get(key, -1)):
		idx = (idx + 1 + randi() % (list.size() - 1)) % list.size()
	_last[key] = idx
	return list[idx]


## Spielt einen Schritt an der Position. extra_db hebt z. B. Landungen an.
static func play(parent: Node, pos: Vector3, gait: String, extra_db: float = 0.0) -> void:
	var surface := surface_at(pos)
	var stream := pick(surface, gait)
	if stream == null:
		return
	var vol: float = GAIT_DB[gait] + SURFACE_DB[surface] + extra_db
	SoundBank.play_stream_at(parent, stream, pos, vol, randf_range(0.94, 1.06))
