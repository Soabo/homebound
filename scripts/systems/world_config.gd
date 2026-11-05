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
