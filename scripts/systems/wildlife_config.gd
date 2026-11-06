class_name WildlifeConfig
extends Resource
## Einstellungen für die Tierwelt (gehört zum World State Manager): wie oft welche Tiere auftauchen,
## wie scheu sie sind und wie sie mit der Talverwandlung verschwinden. Werte in data/world/wildlife.tres.

@export_group("Allgemein")
## Abstand zum Spieler, in dem Tiere auftauchen (außerhalb des Blickfelds) und ab dem sie verschwinden.
@export var spawn_distance: Vector2 = Vector2(22.0, 42.0)
@export var despawn_distance: float = 75.0
## Wie viele Tiere je Terraforming-Stufe 0..4 noch da sind (1 = alle, 0 = keine).
@export var stage_factor: PackedFloat32Array = PackedFloat32Array([1.0, 0.65, 0.35, 0.12, 0.0])

@export_group("Tag – Bodentiere")
## Sekunden zwischen zwei neuen Tieren (zufällig im Bereich).
@export var day_spawn_interval: Vector2 = Vector2(14.0, 35.0)
@export var max_ground_animals: int = 4
## Gewichte: je größer, desto öfter.
@export var hare_weight: float = 3.0
@export var snake_weight: float = 1.0
@export var squirrel_weight: float = 3.0
@export var ground_birds_weight: float = 3.0
## Ab diesem Abstand flieht ein Tier vor dem Spieler (Gehen); Schleichen halbiert ihn.
@export var shy_distance: float = 7.0

@export_group("Tag – Insekten und Vögel")
## Schmetterlinge nur zwischen diesen Uhrzeiten.
@export var butterfly_hours: Vector2 = Vector2(9.0, 18.5)
@export var max_butterflies: int = 6
@export var max_insect_swarms: int = 3
## Sekunden zwischen Vögeln, die über das Tal fliegen (Krähen, Bussard).
@export var flyover_interval: Vector2 = Vector2(35.0, 110.0)

@export_group("Zugvögel")
## Zugvögel ziehen in Scharen ab, sobald die Tiere das Tal verlassen (ab Stufe 1, bis einschließlich Stufe 2).
@export var migration_from_stage: int = 1
@export var migration_until_stage: int = 2
@export var migration_interval: Vector2 = Vector2(50.0, 150.0)
@export var migration_flock_size: Vector2i = Vector2i(18, 40)
## Richtung, in die sie ziehen (weg vom Krater, nach Südosten).
@export var migration_direction: Vector2 = Vector2(0.7, 0.7)

@export_group("Nacht")
@export var night_spawn_interval: Vector2 = Vector2(50.0, 150.0)
@export var max_night_animals: int = 2
@export var deer_weight: float = 2.0
@export var fox_weight: float = 2.0
@export var hedgehog_weight: float = 2.0
## Rehe kommen zu ein bis zwei.
@export var deer_group: Vector2i = Vector2i(1, 2)
## Rehe fliehen, wenn der Spieler so nah kommt oder die Kreatur in diesem Umkreis ist.
@export var deer_flee_player: float = 16.0
@export var deer_flee_creature: float = 45.0
## Leuchtet man sie so lange an, laufen sie weg (Sekunden).
@export var deer_light_tolerance: float = 1.5
