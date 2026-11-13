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

@export_group("Belagerungsnacht (SiegeNight)")
## Ab Nacht … und dann frühestens alle … Nächte
@export var siege_from_night: int = 5
@export var siege_every: int = 4
## Von … bis … Uhr durchhalten (Spielzeit)
@export var siege_start_hour: float = 21.0
@export var siege_end_hour: float = 5.0
## Wie viele Aufgaben in der ersten Belagerung laufen (jede weitere eine mehr, höchstens alle vier)
@export var siege_tasks_first: int = 2
## Spieluhr: so viele Sekunden, bis sie abgelaufen ist; Aufziehen bringt so viel; Gnadenfrist danach (Sekunden)
@export var siege_music_seconds: float = 45.0
@export var siege_music_wind: float = 0.6
@export var siege_music_grace: float = 10.0
## Dachboden: Sekunden Druck bis zum Durchbruch (Leiter unten = dreimal so schnell), Dauer der Schübe, Pausen dazwischen
@export var siege_attic_seconds: float = 22.0
@export var siege_attic_burst: Vector2 = Vector2(10.0, 18.0)
@export var siege_attic_pause: Vector2 = Vector2(25.0, 45.0)
## Keller: Sekunden, bis die Mauer nachgibt
@export var siege_cellar_seconds: float = 75.0
## Fenster: Anschleichen, Sekunden bis zum Durchbruch, Pause nach dem Vertreiben, Reichweite der Uhr-LED, Schaden an Brettern
@export var siege_window_approach: Vector2 = Vector2(8.0, 16.0)
@export var siege_window_seconds: float = 20.0
@export var siege_window_pause: Vector2 = Vector2(12.0, 25.0)
@export var siege_light_range: float = 6.0
@export var siege_barricade_hit: float = 15.0
## Fehlschläge: Schaden beim ersten, Sekunden zum Verstecken danach, Sekunden draußen bis zum Angriff
@export var siege_hit_damage: float = 30.0
@export var siege_hide_seconds: float = 14.0
@export var siege_outside_seconds: float = 8.0

@export_group("Nächtliche Vorkommnisse (NightOmens)")
## Wie viele pro Nacht: ruhige Nacht / alle anderen
@export var omen_count_quiet: Vector2i = Vector2i(1, 2)
@export var omen_count_busy: Vector2i = Vector2i(2, 4)
## Draußen-Dinge (Lichter, fliehende Tiere, Sichtungen) kommen so viel öfter als Dinge im Haus
@export var omen_forest_weight: float = 1.6
## Hände durch Spalten ab Nacht …, Schaden aus der Nähe
@export var omen_hand_from_night: int = 3
@export var omen_hand_damage: float = 12.0
## Kurze Sichtungen am Waldrand: Sucher ab Nacht …, Zerfleischer ab Nacht …
@export var omen_seeker_from_night: int = 2
@export var omen_mauler_from_night: int = 5
## Neue Kinderzeichnung (einmalig) ab Nacht …
@export var omen_drawing_from_night: int = 5
## Morgens nach unruhigen Nächten stehen Dinge im Haus anders (Chance, Anzahl)
@export var inside_change_chance: float = 0.6
@export var inside_change_count: Vector2i = Vector2i(1, 2)

@export_group("Dachboden")
## In Nächten mit Besuch/Jagd: Chance, dass etwas über das Dach in den Dachboden kommt (Schritte, Kratzen an der Luke).
@export var attic_chance: float = 0.45
## Ab dieser Nacht kann es über die heruntergelassene Leiter ins Haus kommen.
@export var attic_from_night: int = 4
## Steht die Leiter unten, kommt es in Besuchsnächten fast sicher hinein.
@export var attic_ladder_down_chance: float = 0.9
## Ab dieser Nacht verletzt es dich, wenn du in der Nähe der Leiter bist (Schaden).
@export var attic_hurt_from_night: int = 6
@export var attic_damage: float = 25.0

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

@export_group("Zerfleischer (ab Story-Phase 2)")
## Chance pro Nacht (nicht in ruhigen Nächten), dass er jagt
@export var mauler_night_chance: float = 0.3
@export var mauler_chance_per_stage: float = 0.05
## So lange (Spielstunden) ist er in so einer Nacht unterwegs – erscheint, sobald du draußen bist
@export var mauler_window_hours: float = 2.5
## Tagsüber, weit weg von der Hütte im dichten Wald: Chance pro Spielstunde
@export var mauler_day_chance_per_hour: float = 0.05
## Ab dieser Baumdichte (WorldMap.tree_density) gilt der Wald als dicht
@export var mauler_day_density: float = 0.55

@export_group("Signatur (Forschung 2.0)")
## Zusatzchance pro Signaturpunkt, dass die Drohne kommt (Fremdes tragen, nachts forschen).
@export var signature_drone_bonus: float = 0.25
## Zusatzchance pro Signaturpunkt, dass der Sucher kommt.
@export var signature_seeker_bonus: float = 0.2
## Ab dieser Signatur bleibt auch eine „ruhige“ Nacht nicht ganz ruhig: Drohne und Sucher dürfen kommen.
@export var signature_wakes_quiet: float = 0.8
## Zeltnacht: so viele Ereignisse pro Nacht im Zelt (frühestens so viele Stunden nach dem Hinlegen)
@export var camp_events: Vector2i = Vector2i(1, 3)
@export var camp_first_after: float = 0.4

@export_group("Schlaf")
## Nach dem Hochschrecken so viele Spielstunden kein Schlaf.
@export var scared_awake_hours: float = 1.0
## Kein Schlaf, solange die Kreatur näher ist als (m).
@export var no_sleep_creature_distance: float = 60.0
