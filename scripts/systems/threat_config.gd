class_name ThreatConfig
extends Resource
## Einstellungen für den Threat Director (GDD 8). Werte in data/threat/default_threat.tres.

## Langfristige Bedrohung: Startwert und Zuwachs pro Spieltag.
@export var base_threat: float = 1.0
@export var threat_per_day: float = 0.6

## Wie oft pro Nacht kleine Ereignisse (Geräusche, Stromausfall) auftreten können.
@export var ambient_events_per_night: Vector2i = Vector2i(2, 5)

## Wahrscheinlichkeit für einen Stromausfall in einer Nacht ab Intensität 2.
@export var outage_chance: float = 0.35

## Lebenspunkte von Fenstern, Barrikaden und Tür.
@export var window_health: float = 60.0
@export var barricade_health: float = 120.0
@export var door_health: float = 180.0

@export_group("Spannungsbogen (wie oft die Kreatur auftaucht)")
## Chance auf einen Auftritt, je nachdem wie viele Nächte seit dem letzten vergangen sind (Index 0, 1, 2, 3+).
@export var appear_chance_by_gap: PackedFloat32Array = PackedFloat32Array([0.0, 0.0, 0.5, 1.0])
## Chance auf einen Auftritt in der allerersten Nacht.
@export var first_night_appear_chance: float = 0.5
## Nach einem Auftritt so viele ruhige Nächte (zufällig dazwischen).
@export var quiet_nights_after: Vector2i = Vector2i(1, 2)
## Ab dieser Nacht kann sie das Haus erkunden (rütteln, tasten), ab dieser Nacht echt angreifen.
@export var visit_from_night: int = 4
@export var hunt_from_night: int = 6
## Bis zur ersten Angriffsnacht: Anteil Erkundung (Rest = Sichtung).
@export var early_visit_share: float = 0.5
## Ab der ersten Angriffsnacht: Angriffs-Chance = Start + Zuwachs pro Nacht, höchstens Maximum.
@export var hunt_chance_start: float = 0.25
@export var hunt_chance_per_night: float = 0.08
@export var hunt_chance_max: float = 0.6
## Ab der ersten Angriffsnacht: Anteil Erkundung (Rest nach Angriff und Erkundung = Sichtung).
@export var late_visit_share: float = 0.35
## In Sichtungsnächten zusätzlich ein Trugbild auf der Kamera.
@export var sighting_phantom_chance: float = 0.4
## Sichtung, während man im Haus ist: Anteil Gesicht am Fenster (Rest = Waldrand).
@export var sighting_window_share: float = 0.65
## Spuren am Morgen: nach Nächten mit Andeutungen / nach Erkundung oder Angriff.
@export var traces_after_hints: float = 0.5
@export var traces_after_visit: float = 0.85

@export_group("Kreatur im Haus nach dem Aufwachen")
@export var inside_from_day: int = 3
## Mindestabstand in Tagen zwischen zwei solchen Auftritten.
@export var inside_min_gap_days: int = 2
@export var inside_chance_after_appearance: float = 0.45
@export var inside_chance_otherwise: float = 0.15

@export_group("Gestalt im Wald (tagsüber)")
@export var forest_from_day: int = 2
## Erst ab dieser Entfernung zur Hütte.
@export var forest_min_distance: float = 40.0
## Chance alle 30 Sekunden im Wald (höchstens einmal am Tag).
@export var forest_chance_per_check: float = 0.06

@export_group("Andere Arten (wann sie kommen)")
@export var drone_from_night: int = 3
@export var drone_chance: float = 0.35
@export var manipulator_from_night: int = 4
@export var manipulator_chance: float = 0.3
## Zusätzliche Chance je Terraforming-Stufe (Drohne und Manipulator).
@export var species_chance_per_stage: float = 0.1

@export_group("Veränderungen draußen nach unruhigen Nächten")
## Chance am Morgen nach einer Nacht mit Alien-Aktivität, dass sich draußen etwas verändert hat.
@export var night_change_chance: float = 0.6
## Wie viele Veränderungen auf einmal, und wie viele Tage sie bleiben.
@export var night_change_count: Vector2i = Vector2i(1, 2)
@export var night_change_days: Vector2i = Vector2i(2, 4)

@export_group("Lauernde Gestalt auf den Kameras (nur auf dem Bildschirm)")
## Chance pro Kamerabild (beim Öffnen des Monitors oder Umschalten), dass sie dort hockt und lauert.
@export var camera_lurk_chance_night: float = 0.12
@export var camera_lurk_chance_day: float = 0.03
## Mindestabstand zwischen zwei solchen Erscheinungen (Echtzeit-Sekunden).
@export var camera_lurk_cooldown: float = 180.0
## Ab welchem Tag es vorkommen kann.
@export var camera_lurk_from_day: int = 1
## Nach so vielen Sekunden Hinsehen dreht sie langsam den Kopf zur Kamera.
@export var camera_lurk_look_after: Vector2 = Vector2(2.0, 5.0)

@export_group("Sucher und Zeltnacht")
## Ab welcher Nacht der Sucher kommen kann, wie wahrscheinlich (plus je Terraforming-Stufe)
@export var seeker_from_day: int = 5
@export var seeker_chance: float = 0.2
@export var seeker_chance_per_stage: float = 0.06
## Zeltnacht: so viele Ereignisse pro Nacht im Zelt (frühestens so viele Stunden nach dem Hinlegen)
@export var camp_events: Vector2i = Vector2i(1, 3)
@export var camp_first_after: float = 0.4

@export_group("Schlaf")
## Nach dem Hochschrecken so viele Spielstunden kein Schlaf.
@export var scared_awake_hours: float = 1.0
## Kein Schlaf, solange die Kreatur näher ist als (m).
@export var no_sleep_creature_distance: float = 60.0
