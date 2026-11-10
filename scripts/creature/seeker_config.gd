class_name SeekerConfig
extends Resource
## Verhalten des Suchers (Gegner-KI). Werte in data/creatures/seeker.tres.
## Der Sucher sucht nach menschlichen Lebenszeichen: Licht, Geräusche und das Signal von W-17.
## Er tötet nicht – er findet dich, verletzt dich (Zelt reißt) und verschwindet.

const PATH := "res://data/creatures/seeker.tres"
static var _cached: SeekerConfig


static func get_default() -> SeekerConfig:
	if _cached == null:
		_cached = load(PATH) as SeekerConfig
		if _cached == null:
			_cached = SeekerConfig.new()
	return _cached


@export_group("Bewegung")
@export var walk_speed: float = 1.1
@export var approach_speed: float = 3.2
## Erscheint so weit vom Ziel entfernt (Hütte oder Lager)
@export var spawn_distance: Vector2 = Vector2(38.0, 55.0)

@export_group("Ablauf")
## Erst beobachten (Sekunden), dann absuchen
@export var watch_time: Vector2 = Vector2(12.0, 30.0)
@export var search_points: Vector2i = Vector2i(4, 7)
@export var search_radius: float = 11.0
@export var search_hold: Vector2 = Vector2(2.5, 6.0)
## Wie lange er insgesamt bleibt, bevor er abzieht
@export var stay_time: float = 220.0

@export_group("Wahrnehmung")
## Licht (Uhr, Feuer, Licht im Zelt) sieht er aus dieser Entfernung
@export var light_range: float = 45.0
@export var fire_range: float = 70.0
## Geräusche: Faktor auf den Geräuschradius
@export var hearing: float = 1.3
## W-17 spürt er aus dieser Entfernung (wenn man es bei sich trägt)
@export var w17_range: float = 120.0
## Sieht den Spieler im Dunkeln / angeleuchtet aus dieser Entfernung
@export var sight_dark: float = 8.0
@export var sight_lit: float = 20.0

@export_group("Angriff")
## Schaden beim Zuschlagen bzw. Zelt-Aufreißen – nie unter min_health
@export var strike_damage: float = 24.0
@export var min_health: float = 15.0
## Zelt aufreißen: Chance, wenn er am Zelt ist und kein Licht/W-17 ihn lockt
@export var tear_chance_dark: float = 0.25
@export var tear_from_day: int = 6
