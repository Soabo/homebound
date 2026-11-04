class_name Footsteps
extends RefCounted
## Schrittgeräusche des Spielers aus echten Aufnahmen (assets/audio/steps/<untergrund>/<art>_NN.ogg).
## Arten: sneak, walk, run (Schritte), land (Landung nach Sprung), jump (Absprung, nur Wasser).
## Die Aufnahmen wurden mit tools/audio/slice.py bzw. prepare.py zugeschnitten.
## Der Untergrund ergibt sich aus der Position (Hütte, Teppich, Veranda, Zufahrt, Bach, Feld, Wiese, Wald).

const BASE_DIR := "res://assets/audio/steps"
const SURFACES := ["wood", "carpet", "porch", "grass", "forest", "gravel", "soil", "stone", "water"]
const GAITS := ["sneak", "walk", "run"]
const MAX_VARIANTS := 24

## Lautstärke je Gangart und Untergrund (dB). Die Aufnahmen sind gleich laut normiert,
## damit hier allein das Spiel entscheidet, wie laut ein Untergrund klingt.
const GAIT_DB := {"sneak": -21.0, "walk": -14.0, "run": -9.0, "land": -8.0, "jump": -12.0}
const SURFACE_DB := {"wood": 0.0, "carpet": -6.0, "porch": 1.5, "grass": -3.0, "forest": -1.5,
		"gravel": 0.5, "soil": -2.0, "stone": 0.0, "water": 1.0}
## Fehlt für einen Untergrund eine Art (z. B. Landung auf der Veranda), wird diese ähnliche genommen.
const FALLBACK := {"porch": "wood", "forest": "soil", "carpet": "wood"}

## Teppiche in der Hütte (x, z, Breite, Tiefe)
const RUGS := [
	Rect2(-4.6, 0.6, 2.2, 2.3),   # Wohnzimmer
	Rect2(-4.2, -2.3, 1.6, 1.0),  # Schlafzimmer
]
## Veranda samt Treppe
const PORCH := Rect2(-5.7, 4.5, 7.0, 3.1)
## Grundstück innerhalb des Zauns: dort wächst gemähtes Gras, draußen Waldboden
const YARD := Rect2(-20.0, -16.0, 42.0, 34.0)
## Bach: im Wasser, daneben steiniges Ufer; Zufahrt: Kies
const WATER_DIST := 1.2
const BANK_DIST := 2.4
const ROAD_DIST := 1.8

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
	var sd := Terrain.stream_distance(p.x, p.z)
	if sd < WATER_DIST:
		return "water"
	if sd < BANK_DIST:
		return "stone"
	if CornField.is_inside(p.x, p.z):
		return "soil"
	if Terrain.road_distance(p.x, p.z) < ROAD_DIST:
		return "gravel"
	if YARD.has_point(Vector2(p.x, p.z)):
		return "grass"
	return "forest"


static func variants(surface: String, kind: String) -> Array:
	var key := surface + "/" + kind
	if _streams.has(key):
		return _streams[key]
	var list: Array = []
	for i in range(1, MAX_VARIANTS + 1):
		var path := "%s/%s/%s_%02d.ogg" % [BASE_DIR, surface, kind, i]
		if not ResourceLoader.exists(path):
			break
		list.append(load(path))
	_streams[key] = list
	return list


## Zufällige Aufnahme, nie zweimal hintereinander dieselbe.
static func pick(surface: String, kind: String) -> AudioStream:
	var list := variants(surface, kind)
	if list.is_empty():
		return null
	var key := surface + "/" + kind
	var idx := randi() % list.size()
	if list.size() > 1 and idx == int(_last.get(key, -1)):
		idx = (idx + 1 + randi() % (list.size() - 1)) % list.size()
	_last[key] = idx
	return list[idx]


## Spielt einen Schritt (oder Landung/Absprung) an der Position. extra_db hebt z. B. harte Landungen an.
## Gibt false zurück, wenn es für diesen Untergrund und diese Art nichts gibt.
static func play(parent: Node, pos: Vector3, kind: String, extra_db: float = 0.0) -> bool:
	var surface := surface_at(pos)
	var src := surface
	var stream := pick(src, kind)
	if stream == null and FALLBACK.has(surface):
		src = FALLBACK[surface]
		stream = pick(src, kind)
	if stream == null:
		return false
	var vol: float = GAIT_DB[kind] + SURFACE_DB[surface] + extra_db
	SoundBank.play_stream_at(parent, stream, pos, vol, randf_range(0.94, 1.06))
	return true


## Landung nach Sprung oder Sturz; ohne eigene Landeaufnahme zwei schnelle Laufschritte.
static func play_landing(parent: Node, pos: Vector3, extra_db: float) -> void:
	if not play(parent, pos, "land", extra_db):
		play(parent, pos, "run", 4.0 + extra_db)


## Absprung: im Wasser ein Platschen, sonst ein leiser Schritt.
static func play_jump(parent: Node, pos: Vector3) -> void:
	if not play(parent, pos, "jump"):
		play(parent, pos, "sneak", 6.0)
