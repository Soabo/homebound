class_name DroneConfig
extends Resource
## Verhalten der Drohne (Gegner-KI). Werte in data/creatures/drone.tres.

const PATH := "res://data/creatures/drone.tres"
static var _cached: DroneConfig


static func get_default() -> DroneConfig:
	if _cached == null:
		_cached = load(PATH) as DroneConfig
		if _cached == null:
			_cached = DroneConfig.new()
	return _cached


@export_group("Flug")
@export var speed: float = 5.0
## Wie lange sie bleibt, bevor sie abdreht (Sekunden).
@export var patrol_time: float = 95.0
@export var height_range: Vector2 = Vector2(6.5, 11.0)
## Anflug aus dieser Entfernung.
@export var approach_distance: float = 70.0

@export_group("Flugmuster")
## Muster und ihre Gewichte (je höher, desto häufiger).
@export var patterns: PackedStringArray = PackedStringArray(["lanes", "circle", "search", "window"])
@export var pattern_weights: PackedFloat32Array = PackedFloat32Array([1.0, 1.0, 1.0, 1.0])
## Chance auf ein zweites Muster danach.
@export var second_pattern_chance: float = 0.6
@export var lanes_rows: Vector2i = Vector2i(3, 5)
@export var circle_radius: Vector2 = Vector2(9.0, 18.0)
@export var circle_points: Vector2i = Vector2i(8, 16)
@export var search_points: Vector2i = Vector2i(4, 7)
@export var search_hold: Vector2 = Vector2(2.0, 6.0)
@export var window_count: Vector2i = Vector2i(1, 2)
@export var window_hold: Vector2 = Vector2(7.0, 12.0)
## Schwebt so weit vor dem Fenster und so hoch über dem Boden.
@export var window_distance: float = 3.5
@export var window_height: float = 3.2

@export_group("Lichtkegel und Erfassen")
## Radius des Lichtkegels am Boden bei 9 m Höhe.
@export var cone_radius: float = 5.0
## Durchs Fenster gesehen, wer so nah hinter der Scheibe steht (m).
@export var window_spot_distance: float = 2.6

@export_group("Geräusche")
## Reagiert auf Geräusche ab dieser Lautstärke, bis zu dieser Entfernung.
@export var hear_min_radius: float = 8.0
@export var hear_distance: float = 32.0
@export var hear_cooldown: float = 20.0
@export var hear_hold: Vector2 = Vector2(4.0, 7.0)

@export_group("Gegenmittel")
@export var jammer_range: float = 26.0
## Grelles Licht (Stroboskop, Bewegungsmelder) in dieser Entfernung bringt sie ins Taumeln.
@export var light_range: float = 9.0
@export var stagger_time: float = 2.5

@export_group("Tarnung im Gebüsch")
## Wer geduckt und ohne Licht in dichtem Gebüsch sitzt, wird erst so nah gewittert (m). 0 = nie.
@export var cover_sniff_range: float = 0.0
