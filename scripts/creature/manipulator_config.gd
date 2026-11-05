class_name ManipulatorConfig
extends Resource
## Verhalten des Manipulators (Gegner-KI). Werte in data/creatures/manipulator.tres.

const PATH := "res://data/creatures/manipulator.tres"
static var _cached: ManipulatorConfig


static func get_default() -> ManipulatorConfig:
	if _cached == null:
		_cached = load(PATH) as ManipulatorConfig
		if _cached == null:
			_cached = ManipulatorConfig.new()
	return _cached


@export_group("Auftritt")
## Wie lange er bleibt (Sekunden, zufällig dazwischen).
@export var lifetime: Vector2 = Vector2(70.0, 140.0)
## Abstand zur Hütte (m).
@export var distance: Vector2 = Vector2(22.0, 38.0)
## Kommt der Spieler draußen näher als das: weg – und die Kreatur steht hinter ihm.
@export var vanish_distance: float = 12.0
## Sichtbar aus der Nähe bzw. im Lichtkegel der Uhr bis zu dieser Entfernung.
@export var visible_distance: float = 16.0
@export var flashlight_distance: float = 30.0

@export_group("Ortswechsel")
## Wechselt ungesehen die Stelle, alle … Sekunden.
@export var relocate_interval: Vector2 = Vector2(18.0, 32.0)
## Chance, dass er sich bei jedem Wechsel nähert – um so viele Meter, aber nicht näher als das Minimum.
@export var approach_chance: float = 0.35
@export var approach_step: Vector2 = Vector2(3.0, 5.0)
@export var approach_min_distance: float = 17.0

@export_group("Locken")
## Geräusche, mit denen er lockt. "steps" = Schritte im Laub, "breath" = dein eigenes Atmen,
## alles andere ist eine Geräusch-ID aus der SoundBank (z. B. Hausgeräusche).
@export var lures: PackedStringArray = PackedStringArray(["music_box", "knock", "steps", "breath", "radio", "door_close",
		"door_open", "light_switch", "chop", "rattle", "clatter"])
@export var lure_interval: Vector2 = Vector2(5.0, 15.0)
@export var first_lure_after: Vector2 = Vector2(3.0, 9.0)
## Chance, dass zwei Geräusche kurz hintereinander kommen.
@export var double_lure_chance: float = 0.2
## Chance auf eine lange stumme Phase am Anfang, und wie lange sie dauert.
@export var silent_start_chance: float = 0.3
@export var silent_start: Vector2 = Vector2(25.0, 45.0)
