class_name MaulerConfig
extends Resource
## Verhalten des Zerfleischers (Gegner-KI). Werte in data/creatures/mauler.tres.
## Ein Jäger auf zwei Beinen: schleicht heran, sprintet, schlägt mit den Klauen zu, weicht nach jedem
## Treffer zurück, läuft einen Halbkreis und greift erneut an. Licht (LED-Lampe, Feuer, Scheinwerfer) vertreibt ihn.
## Wann er kommt: ThreatConfig mauler_*.

const PATH := "res://data/creatures/mauler.tres"
static var _cached: MaulerConfig


static func get_default() -> MaulerConfig:
	if _cached == null:
		_cached = load(PATH) as MaulerConfig
		if _cached == null:
			_cached = MaulerConfig.new()
	return _cached


@export_group("Bewegung")
## Heranschleichen (m/s)
@export var stalk_speed: float = 2.2
## Sprint auf der Jagd – etwa so schnell wie der Spieler beim Sprinten (5,4)
@export var charge_speed: float = 5.3
## Zurückweichen nach einem Treffer und Halbkreis
@export var retreat_speed: float = 4.4
@export var flee_speed: float = 6.5
## Erscheint so weit vom Spieler entfernt, außer Sicht
@export var spawn_distance: Vector2 = Vector2(45.0, 65.0)

@export_group("Jagd")
## Ab dieser Entfernung sprintet er los
@export var charge_distance: float = 22.0
## Vor dem Sprint: kurz stehen, Kopf heben, kreischen (Sekunden) – die faire Warnung
@export var charge_warning: float = 1.4
## Reichweite der Klauen
@export var strike_range: float = 1.7
## Schaden pro Treffer (100 = volle Gesundheit; 3 Treffer reichen fast immer)
@export var hit_damage: float = 36.0
## Nach einem Treffer: so weit zurück (m), dann Halbkreis mit diesem Radius
@export var retreat_distance: Vector2 = Vector2(9.0, 13.0)
@export var circle_radius: float = 11.0
## Wie viel vom Kreis er läuft (Grad), bevor er erneut angreift
@export var circle_degrees: Vector2 = Vector2(120.0, 200.0)
## Höchstens so lange auf einer Jagd (Sekunden), dann verschwindet er wieder im Wald
@export var hunt_time: float = 240.0
## Verliert er dich so lange aus den Augen (versteckt, im Haus), gibt er auf
@export var lose_time: float = 45.0

@export_group("Licht")
## LED-Lampe der Uhr: so weit reicht der Schreck (m) …
@export var led_range: float = 17.0
## … innerhalb dieses Kegels (Grad, halber Öffnungswinkel um die Blickrichtung)
@export var led_cone: float = 24.0
## So lange muss ihn der Lichtkegel treffen (Sekunden)
@export var led_time: float = 0.35
## Danach flieht er so lange (Sekunden) und kommt (vielleicht) zurück
@export var flee_time: Vector2 = Vector2(45.0, 90.0)
## Chance, dass er nach der Flucht in derselben Nacht noch einmal kommt
@export var return_chance: float = 0.45
## Helle Lichtquellen (Feuer, Scheinwerfer, Laternen, Lichtköder): Radius, den er meidet (m)
@export var bright_radius: float = 9.0
## Chance, dass er auf der Flucht vor hellem Licht einen Reißzahn verliert (höchstens einer pro Tag)
@export var tooth_chance: float = 0.5

@export_group("Geräusche")
## Abstand der Warnzeichen beim Heranschleichen (Äste, Hecheln) in Sekunden
@export var cue_interval: Vector2 = Vector2(3.0, 7.0)
