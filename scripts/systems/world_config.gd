class_name WorldConfig
extends Resource
## Einstellungen des World State Managers: Tempo der Talverwandlung und Wachstum des Organismus.
## Werte in data/world/world_state.tres.

@export_group("Tempo der Veränderung (Tage + Forschung)")
@export var level_per_day: float = 0.13
## Ist die fremde Struktur abgeschaltet, wirkt jeder Tag nur noch so stark.
@export var structure_off_factor: float = 0.5
@export var level_per_analysis: float = 0.04
@export var level_per_link: float = 0.07
## Ab diesen Werten beginnen die Stufen 1 bis 4.
@export var stage_thresholds: PackedFloat32Array = PackedFloat32Array([0.2, 0.45, 0.7, 1.0])
## Ab dieser Stufe ist das Wasser verunreinigt.
@export var water_stage: int = 3

@export_group("Organismus")
## Wächst ab dieser Stufe, solange der Knoten in der Höhle lebt.
@export var spread_from_stage: int = 2
## Neue Wucherungen pro Tag: zufällig einer dieser Werte (gleich oft vertreten = wahrscheinlicher).
@export var spread_per_day: PackedInt32Array = PackedInt32Array([0, 1, 1, 2])
## Ab Stufe 3: Chance auf eine zusätzliche Wucherung.
@export var extra_spread_chance: float = 0.5
## Chance, von einer bestehenden Wucherung weiterzuwachsen (sonst von der Höhle aus).
@export var branch_chance: float = 0.75
## Wie weit ein neues Stück wächst und wie stark es von der Richtung abweicht (Bogenmaß).
@export var step_length: Vector2 = Vector2(5.0, 9.0)
@export var direction_jitter: float = 0.8
## Ziele, auf die sie zuwächst: Hütte, Schuppen, Regentonne, Bach, Maisfeld, hinter der Hütte.
@export var spread_goals: PackedVector3Array = PackedVector3Array([Vector3(6, 0, -10), Vector3(14, 0, 2), Vector3(9, 0, -2),
		Vector3(33, 0, -20), Vector3(17, 0, 12), Vector3(-8, 0, -12)])
## Sporensprünge: ab dieser Stufe, mit dieser Chance pro Tag, in diesem Abstand zur Hütte.
@export var spore_from_stage: int = 3
@export var spore_chance: float = 0.2
@export var spore_distance: Vector2 = Vector2(14.0, 34.0)
## Mindestabstand zwischen zwei Wucherungen, Wirkbereich der Myzel-Sperre.
@export var patch_spacing: float = 3.0
@export var barrier_range: float = 15.0

@export_group("Wald (Baumarten, Dichte)")
## Anteile der Baumarten im Tiefland (oben am Berg mehr Fichte und Kiefer, am Wasser und Waldrand mehr Birke).
@export var forest_spruce: float = 0.46
@export var forest_pine: float = 0.12
@export var forest_beech: float = 0.15
@export var forest_birch: float = 0.12
@export var forest_leaf: float = 0.07
@export var forest_dead: float = 0.035
## Chance auf Jungwuchs (junge Fichte / junger Laubbaum) in einer Lücke zwischen den Bäumen.
@export var forest_young_chance: float = 0.45
## Tal: wie viele Farne, Büsche, dichte Gebüsche, Brombeerhecken.
@export var valley_ferns: int = 13000
@export var valley_bushes: int = 1100
@export var valley_thickets: int = 260
@export var valley_brambles: int = 220
## Großer Wald: Versuche pro 64-m-Stück (mehr = dichter), Farne wachsen in Gruppen von so vielen.
@export var wild_ground_tries: int = 1500
@export var fern_clump: Vector2i = Vector2i(2, 5)
## Anteil dichter Gebüsche unter den Büschen im großen Wald.
@export var wild_thicket_share: float = 0.3

@export_group("Tarnung im Gebüsch")
## Ab dieser Größe gilt ein Busch als dicht genug zum Verstecken (Radius in m).
@export var cover_min_radius: float = 0.75
## Man muss geduckt sein, außer das Gebüsch ist mindestens so hoch (m).
@export var cover_stand_height: float = 1.9
## Wer sich schneller bewegt, raschelt und ist nicht getarnt (m/s).
@export var cover_max_speed: float = 1.3

@export_group("Wetter und Wind")
## Wie oft welches Wetter kommt (Gewichte). Morgens zwischen 4 und 9 Uhr ist Nebel häufiger (fog_morning_factor).
@export var weather_clear: float = 0.38
@export var weather_cloudy: float = 0.27
@export var weather_rain: float = 0.15
@export var weather_fog: float = 0.12
@export var weather_storm: float = 0.08
@export var fog_morning_factor: float = 3.0
## Wie lange ein Wetter anhält (Spielstunden)
@export var weather_hours: Vector2 = Vector2(3.0, 9.0)
## Windstärke je Wetter (0..1), dazu Böen
@export var wind_clear: float = 0.22
@export var wind_cloudy: float = 0.38
@export var wind_rain: float = 0.45
@export var wind_fog: float = 0.06
@export var wind_storm: float = 0.95
## Bewölkung je Wetter (0..1, Wolken vor dem Mond dämpfen sein Licht)
@export var clouds_clear: float = 0.15
@export var clouds_cloudy: float = 0.6
@export var clouds_rain: float = 0.85
@export var clouds_fog: float = 0.5
@export var clouds_storm: float = 0.95
## Draußen im Regen wird man nass (kälter)
@export var rain_wets: bool = true
## Gewitter: Abstand zwischen Blitzen (s), Wetterleuchten in klaren Nächten (Chance pro Minute)
@export var lightning_seconds: Vector2 = Vector2(14.0, 45.0)
@export var heat_lightning_chance: float = 0.12
## Wie schnell Boden und Pflanzen nass werden bzw. trocknen (pro Spielstunde)
@export var wet_per_hour: float = 1.5
@export var dry_per_hour: float = 0.35
