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
## Chance auf Blitzasche, wenn er von selbst abzieht (nach einem Schlag bleibt immer welche)
@export var ash_leave_chance: float = 0.5

@export_group("Wahrnehmung")
## Licht (Uhr, Feuer, Licht im Zelt) sieht er aus dieser Entfernung
@export var light_range: float = 45.0
@export var fire_range: float = 70.0
## Geräusche: Faktor auf den Geräuschradius
@export var hearing: float = 1.3
## W-17 spürt er aus dieser Entfernung (wenn man es bei sich trägt)
@export var w17_range: float = 120.0
## Ab dieser Signatur am Körper (Research.carried_signature) spürt er dich überhaupt.
@export var signature_min: float = 0.15
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

@export_group("Tarnung im Gebüsch")
## Wer geduckt und ohne Licht in dichtem Gebüsch sitzt, wird erst so nah gewittert (m). 0 = nie.
@export var cover_sniff_range: float = 2.2

@export_group("Im Haus (Christian 23.11.)")
## Ist der Spieler in der Hütte und der Sucher näher als das, belagert er das Haus: Lichtstrahl durch die Fenster, lange Arme
@export var house_range: float = 45.0
## so lange (s) bleibt er an einem Fenster, dann sucht er sich ein neues (meist das nächste zum Spieler, manchmal ein zufälliges)
@export var house_window_time: Vector2 = Vector2(10.0, 22.0)
@export var house_random_window: float = 0.3
## Lichtstrahl aus dem Augenspalt: Reichweite (m), halber Öffnungswinkel (Grad), Schaden pro Sekunde, Pendelweite (m)
@export var beam_range: float = 10.0
@export var beam_angle: float = 13.0
@export var beam_damage: float = 7.0
@export var beam_sweep: float = 1.8
## wie schnell (m/s) der Strahl dir folgt, sobald er dich erfasst hat
@export var beam_follow: float = 0.9
## Arme durch Wand, Boden, Decke: Abstand zwischen zwei Armen (s), Schaden bei Berührung, Lebensdauer (s), Reichweite (m)
@export var reach_interval: Vector2 = Vector2(6.0, 15.0)
@export var reach_damage: float = 14.0
@export var reach_time: float = 9.0
@export var reach_length: float = 1.7
## Gewicht für Wand / Boden / Decke
@export var reach_weights: Vector3 = Vector3(0.45, 0.3, 0.25)
## Chance auf einen zweiten Arm kurz danach, Chance, dass er hinter dir herauskommt
@export var reach_double_chance: float = 0.25
@export var reach_behind_chance: float = 0.35
## so lange (s) muss die Uhr-LED auf die Hand leuchten, bis sie sich zurückzieht
@export var reach_led_time: float = 0.6
## höchstens so viele Arme gleichzeitig
@export var reach_max: int = 2
