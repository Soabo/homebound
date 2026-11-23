class_name SurvivalConfig
extends Resource
## Werte für Kälte und Wärme (Survival-Manager). Datei: data/survival/survival.tres.
## Wärme 100 = warm, 0 = erfroren. Raten in Punkten pro Spielstunde.

const PATH := "res://data/survival/survival.tres"
static var _cached: SurvivalConfig


static func get_default() -> SurvivalConfig:
	if _cached == null:
		_cached = load(PATH) as SurvivalConfig
		if _cached == null:
			_cached = SurvivalConfig.new()
	return _cached


@export_group("Hunger und Durst")
## Abnahme pro Spielstunde (bewusst sanft: eine Konserve reicht gut einen Spieltag)
@export var hunger_per_hour: float = 1.3
@export var thirst_per_hour: float = 2.0

@export_group("Auskühlen draußen")
## Verlust pro Stunde draußen am Tag / in der Nacht
@export var outdoor_loss_day: float = 1.5
@export var outdoor_loss_night: float = 9.0
## Zusätzlicher Verlust pro Stunde je 100 m Höhe
@export var altitude_loss_per_100m: float = 3.0
## Nass (nach dem Waten): so viel schneller kühlt man aus, so lange (Stunden)
@export var wet_factor: float = 2.0
@export var wet_hours: float = 1.5

@export_group("Hütte, Zelt, Schlafsack")
## In der Hütte: Gewinn, wenn Kamin oder Ofen brennen; ohne Feuer wärmt man sich nur langsam auf
@export var cabin_heated_gain: float = 14.0
@export var cabin_unheated_gain_day: float = 4.0
@export var cabin_unheated_gain_night: float = 1.0
## Im Zelt kühlt man so viel langsamer aus (Faktor auf den Verlust); mit Schlafsack noch einmal
@export var tent_factor: float = 0.5
@export var sleeping_bag_factor: float = 0.25

@export_group("Feuer")
## Gewinn pro Stunde direkt am Feuer (nimmt mit der Entfernung ab)
@export var fire_gain: float = 90.0
@export var campfire_radius: float = 5.0
## So weit (m) wärmen Kamin und Küchenofen in der Hütte spürbar schneller
@export var hearth_radius: float = 3.5
## Lagerfeuer: so lange brennt es (Stunden), so viel länger je Holz
@export var campfire_hours: float = 3.0
@export var campfire_hours_per_wood: float = 1.5

@export_group("Schlaf")
## Heilung pro geschlafener Stunde (Christian 23.11.: Schlaf heilt nur wenig)
@export var sleep_heal_per_hour: float = 3.5

@export_group("Gesundheit (Christian 23.11.: härter, Verbandskästen selten)")
## Alle Treffer × diesen Faktor (Kreatur/Zerfleischer: 2–3 Treffer reichen)
@export var damage_factor: float = 1.35
## Von selbst heilt man nur langsam (pro Spielstunde, satt und nicht durstig) und nur bis heal_cap
@export var passive_heal_per_hour: float = 2.0
@export var passive_heal_cap: float = 60.0
## Nach dem Laden / Tod mindestens so viel Gesundheit
@export var restore_min_health: float = 50.0
## … und so warm, satt und nicht durstig (sonst stirbt man gleich wieder: Todesschleife)
@export var restore_min_warmth: float = 60.0
@export var restore_min_food: float = 25.0
## Bein verletzt: ab so viel Schaden (nach Faktor) mit dieser Chance; Fallen immer
@export var leg_hit_min: float = 25.0
@export var leg_chance: float = 0.45
## so lange (Spielstunden) humpelt man ohne Verbandskasten
@export var leg_hours: float = 20.0
## Humpeln: Gehen × dieser Faktor, rennen geht nicht
@export var leg_speed_factor: float = 0.78

@export_group("Folgen")
## Unter diesem Wert friert man (Hinweis, Zittern, weniger Ausdauer)
@export var cold_warn: float = 35.0
@export var cold_stamina_cut: float = 25.0
## Unter diesem Wert nimmt man Schaden (pro Sekunde)
@export var freeze_below: float = 12.0
@export var freeze_damage: float = 0.35
## Beim Aufwachen durchgefroren: höchstens so viel Schaden, nie unter diese Gesundheit
@export var sleep_freeze_damage: float = 30.0
@export var sleep_min_health: float = 20.0
## Nach dem durchgefrorenen Aufwachen bleibt so viel Wärme über der Erfrier-Grenze (Gnadenfrist)
@export var wake_grace: float = 8.0
