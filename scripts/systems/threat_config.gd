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
## So viele Nächte am Anfang ganz ohne Ereignisse (man soll glauben, man kann einfach schlafen)
@export var calm_first_nights: int = 2
@export var siege_from_night: int = 5
@export var siege_every: int = 4
## Endspurt (Schacht offen, Story-Bibel Phase 5): Belagerung frühestens alle N Nächte, ruhige Nächte werden zu Besuch (Chance) oder Jagd
@export var endgame_siege_every: int = 2
## Zelt an einem Rastplatz (map.json rest_spots): so nah dran zählt, so viele der Zeltnacht-Ereignisse bleiben
@export var camp_rest_radius: float = 14.0
@export var camp_rest_factor: float = 0.5
@export var endgame_visit_chance: float = 0.6
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
## Schleichen: Lautes im Haus (Schritte, knarrende Dielen) hört es auf dem Dach/vor dem Fenster – Druck je 9 m Hörweite
@export var siege_noise_pressure: float = 0.05
## Nach überstandenem Eindringen so viele Sekunden Ruhe, bevor die Aufgaben wieder drängen
@export var siege_calm_after: float = 40.0
## Im Versteck, wenn es davorsteht: Atem länger als so viele Sekunden nicht angehalten (Alt) = es findet dich
@export var siege_breath_grace: float = 2.0

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
## Etappe 6 (Bayerischer Wald): versunkene Glocke von Altenreuth ab Nacht …; Wilde Jagd nur in Rauhnächten oder bei Sturm
@export var omen_bell_from_night: int = 3
@export var omen_hunt_weight: float = 2.5
## Rauhnächte (Daten in data/audio/ambience.json): so viele Vorkommnisse mehr pro Nacht
@export var rauhnacht_omen_bonus: int = 2
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
## Tagsüber erst ab dieser Uhrzeit (nach dem Morgengrauen ist erst einmal Ruhe) und nicht am eigenen Zelt
@export var mauler_day_from_hour: float = 10.0
## Ab dieser Baumdichte (WorldMap.tree_density) gilt der Wald als dicht
@export var mauler_day_density: float = 0.55

@export_group("Türspion (Haustür)")
## Ab dieser Nacht sieht man manchmal etwas, Chance je Blick, höchstens so oft pro Nacht
@export var peephole_from_night: int = 3
@export var peephole_scare_chance: float = 0.35
@export var peephole_max_per_night: int = 2
## Tagsüber (ab Nacht 6): Gestalt am Tor
@export var peephole_day_chance: float = 0.04
## Was man sieht: eye (Auge vor der Linse), figure (an der Treppe, klopft danach), back (nah, dreht den Kopf), dark (Linse zugehalten)
@export var peephole_weights: Dictionary = {"eye": 3.0, "figure": 3.0, "back": 2.0, "dark": 2.0}

@export_group("Nachts durch den Wald (Christian 14.11.: einfach durchlaufen darf sich nicht lohnen)")
## Ab dieser Entfernung von der Hütte (und abseits vom eigenen Zelt) wird es nachts gefährlich
@export var roam_min_distance: float = 60.0
## Alle so viele Sekunden wird gewürfelt
@export var roam_check_seconds: float = 15.0
## Grundchance pro Wurf, dazu je 100 m, die man in dieser Nacht draußen gelaufen ist
@export var roam_base_chance: float = 0.04
@export var roam_chance_per_100m: float = 0.05
@export var roam_max_chance: float = 0.45
## Rennen ist laut: Faktor auf die Chance, solange man sprintet
@export var roam_run_factor: float = 1.8
## Erst eine Warnung (Schritte, Ast knackt), beim nächsten Treffer wird es ernst
@export var roam_warn_first: bool = true
## Abstand zwischen zwei Begegnungen (Spielstunden) und höchstens so viele pro Nacht
@export var roam_cooldown_hours: float = 1.0
@export var roam_max_per_night: int = 3
## So nah am eigenen Zelt (m) gilt man als „im Lager“
@export var roam_camp_radius: float = 25.0
## Tagsüber weit draußen (ab mauler_day_from_hour): Chance × diesen Faktor, nur der Zerfleischer kommt
@export var roam_day_factor: float = 0.5

@export_group("Signatur (Forschung 2.0)")
## Zusatzchance pro Signaturpunkt, dass die Drohne kommt (Fremdes tragen, nachts forschen).
@export var signature_drone_bonus: float = 0.25
## Zusatzchance pro Signaturpunkt, dass der Sucher kommt.
@export var signature_seeker_bonus: float = 0.2
## Ab dieser Signatur bleibt auch eine „ruhige“ Nacht nicht ganz ruhig: Drohne und Sucher dürfen kommen.
@export var signature_wakes_quiet: float = 0.8
## Zeltnacht: so viele Ereignisse pro Nacht im Zelt (frühestens so viele Stunden nach dem Hinlegen)
@export var camp_events: Vector2i = Vector2i(4, 7)
## So viele Vorfälle einer Zeltnacht wecken höchstens auf (die übrigen erlebt man nur wach im Zelt)
@export var camp_wake_max: int = 3
## Reißverschluss/Zelt schütteln: so schnell steigt der Druck (pro Sekunde), so schnell sinkt er beim Halten von E
@export var camp_hold_rise: float = 0.16
@export var camp_hold_fall: float = 0.3
@export var camp_hold_seconds: float = 9.0
## Schaden, wenn die Hand durch den Reißverschluss greift / wenn man sich beim Atem bewegt (nie unter camp_min_health)
@export var camp_hand_damage: float = 14.0
@export var camp_still_damage: float = 8.0
## Stillhalten im Zelt: so viele Sekunden darf man hörbar atmen (Alt nicht gedrückt), bevor es einen bemerkt
@export var camp_breath_grace: float = 2.0
@export var camp_min_health: float = 15.0
@export var camp_first_after: float = 0.4

@export_group("Schlaf")
## Nach dem Hochschrecken so viele Spielstunden kein Schlaf.
@export var scared_awake_hours: float = 1.0
## Kein Schlaf, solange die Kreatur näher ist als (m).
@export var no_sleep_creature_distance: float = 60.0

@export_group("Rascheln im Wald (Wind oder etwas anderes?)")
## Abstand zwischen zwei Raschel-Ereignissen draußen (Spielminuten), tags und nachts
@export var rustle_minutes_day: Vector2 = Vector2(6.0, 14.0)
@export var rustle_minutes_night: Vector2 = Vector2(3.0, 8.0)
## Anteil, bei dem es ganz sicher nur der Wind ist (in einer Böe, in Windrichtung)
@export var rustle_wind_share: float = 0.45
## So weit weg beginnt das Rascheln (m), so lange dauert es (s)
@export var rustle_distance: Vector2 = Vector2(9.0, 18.0)
@export var rustle_seconds: Vector2 = Vector2(3.0, 8.0)
## Schaut man direkt hin, verstummt es (Grad) – dann schweigen die Vögel so lange (s)
@export var rustle_look_angle: float = 22.0
@export var rustle_silence_seconds: float = 18.0
## Danach knackt manchmal ein Ast hinter dir
@export var rustle_twig_chance: float = 0.35

@export_group("Wechselbalg (wann; Verhalten: data/creatures/changeling.tres)")
## Ab dieser Story-Phase gibt es ihn; Chance pro Nacht (außer Belagerung)
@export var changeling_from_phase: int = 2
@export var changeling_chance: float = 0.4
## Ab so vielen Nächten mit ihm: feine Fehler, rückt bei jedem Wegsehen, Echo-Schritte (Stufe 3)
@export var changeling_subtle_after: int = 3
## Ab dieser Nacht packt er zu und entführt (nur Stufe 3)
@export var changeling_abduct_from_night: int = 12
## Endspurt (Schacht offen): so viele falsche Dinge gleichzeitig
@export var changeling_multi: int = 3
## Morgen nach einer Nacht mit ihm: Stuhl im Schlafzimmer, der zum Bett schaut
@export var changeling_morning_chance: float = 0.45
## Tagsüber maskiert unterwegs (zweite Bank, falscher Wegweiser): Chance pro Tag, Abstand zum Spieler beim Aufstellen
@export var changeling_day_chance: float = 0.35
## Wer nachts wach bleibt, dem begegnet er öfter (Christian 15.11.): alle so viele Sekunden ein Wurf mit dieser Chance,
## höchstens einmal pro Nacht, zusätzlich zur geplanten Nacht (changeling_chance)
@export var changeling_awake_check: float = 30.0
@export var changeling_awake_chance: float = 0.06
@export var changeling_day_distance: Vector2 = Vector2(45.0, 140.0)

@export_group("Unberechenbar (Christian 23.11.: Spannungsbogen enorm und unberechenbar)")
## Druck 0..1: steigt in jeder ruhigen Nacht um einen Zufallswert, fällt nach einem Auftritt
@export var menace_rise: Vector2 = Vector2(0.12, 0.3)
@export var menace_drop_visit: float = 0.55
@export var menace_drop_sighting: float = 0.2
## Druck erhöht die Chance auf einen Auftritt (zusätzlich zu appear_chance_by_gap)
@export var menace_appear_bonus: float = 0.5
## Die erwartete Ruhe nach einem Auftritt bricht manchmal einfach (+ Druck × 0,3)
@export var break_calm_chance: float = 0.18
## Sie kommt nicht immer früh: Anteil der Nächte mit spätem Auftritt (irgendwann in der Nacht)
@export var late_arrival_chance: float = 0.4
## Nach dem Abziehen kommt sie noch einmal (Chance je Besuchs-/Jagdnacht, + Druck × 0,3)
@export var second_wave_chance: float = 0.25

@export_group("Verstecke lernen (Christian 23.11.)")
## Ab so vielen Sekunden im selben Versteck zählt es als „benutzt“ (einmal pro Nacht)
@export var hide_use_seconds: float = 25.0
## So lange (s) ist ein Versteck in einer Nacht „sicher“, danach wird sie neugierig
@export var hide_safe_seconds: float = 70.0
## Chance pro Prüfung (alle 5 s): Grundwert je Nachtart, + je Benutzung, + je Minute über hide_safe_seconds
@export var hide_hunt_base: Dictionary = {"quiet": 0.0, "hints": 0.004, "sighting": 0.008, "visit": 0.02, "hunt": 0.03}
@export var hide_hunt_per_use: float = 0.012
@export var hide_hunt_per_minute: float = 0.02
## höchstens so oft pro Nacht; nicht in den ersten Nächten (calm_first_nights) und nicht vor dieser Nacht
@export var hide_hunt_max: int = 2
@export var hide_hunt_from_night: int = 3
## Reißt sie die Tür auf? Grundwert + je Benutzung + je Sekunde hörbarer Atem (höchstens hide_tear_max)
@export var hide_tear_base: float = 0.15
@export var hide_tear_per_use: float = 0.12
@export var hide_tear_per_breath: float = 0.12
@export var hide_tear_max: float = 0.85
## Wer lange versteckt bleibt, dem nehmen sie das Haus auseinander: ab so vielen Sekunden alle hide_damage_every s
## ein Schlag gegen Fenster/Tür (Schaden hide_house_damage)
@export var hide_damage_after: float = 90.0
@export var hide_damage_every: Vector2 = Vector2(25.0, 50.0)
@export var hide_house_damage: float = 18.0

@export_group("Stille eskaliert (Christian 23.11.)")
## Wer nachts wach ist und sich kaum bewegt (versteckt, sitzend, stehend): alle still_every Sekunden eine Stufe mehr
@export var still_every: Vector2 = Vector2(60.0, 110.0)
## weniger als so viele Meter in still_every = still
@export var still_move_meters: float = 3.0
## Stufen der Eskalation (Ereignis-Typen des ThreatDirectors), danach kommt sie selbst ("creature")
@export var still_steps: PackedStringArray = ["steps", "scratch", "knock_door", "rattle", "roof", "creature"]

@export_group("Tagsüber nicht sicher (Christian 23.11.)")
## Ab diesem Tag; Vorfälle pro Tag (Zufall) + Druck × day_menace_extra
@export var day_from_day: int = 3
@export var day_incidents: Vector2i = Vector2i(0, 2)
@export var day_menace_extra: float = 2.0
## Prüfung alle so viele Sekunden mit dieser Chance
@export var day_check_seconds: float = 40.0
@export var day_incident_chance: float = 0.12
## Gewichte: drinnen / draußen
@export var day_inside_kinds: Dictionary = {"knock": 3.0, "creak": 3.0, "roof": 2.0, "radio": 1.0, "window": 0.6}
@export var day_outside_kinds: Dictionary = {"steps": 3.0, "silence": 2.0, "scream": 1.5, "watcher": 2.0, "mauler": 0.8}
## Gesicht am Fenster bei Tag erst ab diesem Tag; Zerfleischer bei Tag nahe der Hütte ab Phase 2, mindestens so weit von der Hütte (m)
@export var day_window_from_day: int = 7
@export var day_mauler_min_distance: float = 35.0
