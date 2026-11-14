class_name ChangelingConfig
extends Resource
## Wie sich der Wechselbalg verhält (Gegner-KI). Wann er kommt: ThreatConfig changeling_*.
## Datei: data/creatures/changeling.tres.

const PATH := "res://data/creatures/changeling.tres"
static var _cached: ChangelingConfig


static func get_default() -> ChangelingConfig:
	if _cached == null:
		_cached = load(PATH) as ChangelingConfig
		if _cached == null:
			_cached = ChangelingConfig.new()
	return _cached


@export_group("Bewegen, nur ungesehen")
## Blickkegel des Spielers (halber Winkel in Grad), in dem er als „angesehen“ gilt, und größte Sichtweite
@export var look_cone: float = 40.0
@export var look_range: float = 45.0
## So lange muss er ungesehen sein, bevor er sich rührt (Sekunden)
@export var unseen_delay: float = 1.0
## Pause zwischen zwei Rucken: Stufe 2 (langsam) / ab Stufe 3 (bei jedem Wegsehen)
@export var move_interval_slow: Vector2 = Vector2(4.0, 8.0)
@export var move_interval_fast: Vector2 = Vector2(1.0, 2.2)
## Weg pro Ruck (Meter) und Dauer eines Rucks (Sekunden)
@export var step_slow: float = 0.9
@export var step_fast: float = 1.8
@export var step_time: float = 0.9
## So nah rückt er heran (ohne Zugreifen) / Reichweite zum Zupacken
@export var stop_distance: float = 1.8
@export var grab_range: float = 1.5

@export_group("Töne")
## Echo-Schritte: in dieser Nähe kommen deine Schritte um echo_delay Sekunden versetzt zurück
@export var echo_range: float = 14.0
@export var echo_delay: float = 0.17
@export var echo_db: float = -7.0
## Bleibst du stehen, folgt mit dieser Wahrscheinlichkeit noch genau ein Schritt
@export var echo_stop_chance: float = 0.5
## Hältst du den Atem an, hörst du ihn aus dieser Nähe atmen
@export var breath_range: float = 4.5
## Stuhl/Bank knarrt, als setze sich jemand (Wahrscheinlichkeit pro Sekunde, in sit_range)
@export var sit_chance: float = 0.03
@export var sit_range: float = 9.0
## Schleifen beim Rücken: Lautstärke (dB), hörbar bis drag_range
@export var drag_db: float = -4.0
@export var drag_range: float = 22.0

@export_group("Licht und wahre Gestalt")
## Uhr-LED zeigt den falschen Schatten: Reichweite und Kegel (Grad)
@export var led_range: float = 12.0
@export var led_cone: float = 16.0
## Sekunden, die man seine wahre Gestalt sieht: nach einem Treffer / im Blitz / im Spiegel
@export var reveal_hit: float = 0.8
@export var reveal_lightning: float = 0.18
@export var reveal_mirror: float = 0.5

@export_group("Zupacken und Entführen")
## So lange zieht er dich, bevor alles schwarz wird (Sekunden)
@export var grab_seconds: float = 7.0
## Losreißen: [E] halten füllt den Balken (pro Sekunde), loslassen leert ihn; LED auf ihn = schneller; Faust = Stoß
@export var struggle_rise: float = 0.22
@export var struggle_fall: float = 0.08
@export var struggle_led_factor: float = 2.0
@export var struggle_fist: float = 0.25
## Zug Richtung Wald (m/s), solange er dich hält
@export var pull_speed: float = 0.9
## Aufwachen: so weit von der Hütte (Meter), so viel Schaden (nie unter abduct_min_health), so viel Wärme weg
@export var abduct_distance: Vector2 = Vector2(80.0, 200.0)
@export var abduct_damage: float = 25.0
@export var abduct_min_health: float = 15.0
@export var abduct_cold: float = 35.0
## So viele Dinge aus dem Rucksack liegen verstreut auf dem Weg
@export var abduct_drops: int = 3

@export_group("Belagerung (falsches Ding im Haus)")
## Sekunden LED-Licht, bis er flieht; Pause bis zum nächsten falschen Ding
@export var siege_led_time: float = 1.5
@export var siege_respawn: Vector2 = Vector2(35.0, 70.0)
