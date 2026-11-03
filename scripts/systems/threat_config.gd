class_name ThreatConfig
extends Resource
## Einstellungen für den Threat Director (GDD 8). Werte in data/threat/default_threat.tres.

## Langfristige Bedrohung: Startwert und Zuwachs pro Spieltag.
@export var base_threat: float = 1.0
@export var threat_per_day: float = 0.6

## Gewichte für die Intensität einer Nacht (0 = ruhig ... 3 = Angriff).
## Wird mit dem Threat Level verschoben, aber jede Stufe bleibt möglich (GDD 8.3).
@export var intensity_weights: PackedFloat32Array = PackedFloat32Array([0.25, 0.35, 0.25, 0.15])

## Wie oft pro Nacht kleine Ereignisse (Geräusche, Stromausfall) auftreten können.
@export var ambient_events_per_night: Vector2i = Vector2i(2, 5)

## Wahrscheinlichkeit für einen Stromausfall in einer Nacht ab Intensität 2.
@export var outage_chance: float = 0.35

## Lebenspunkte von Fenstern, Barrikaden und Tür.
@export var window_health: float = 60.0
@export var barricade_health: float = 120.0
@export var door_health: float = 180.0
