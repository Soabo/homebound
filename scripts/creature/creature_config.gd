class_name CreatureConfig
extends Resource
## Verhalten der Kreatur (Gegner-KI). Werte in data/creatures/creature.tres.
## WANN sie kommt, entscheidet der Threat Director (data/threat/default_threat.tres) – hier steht nur, WIE sie sich verhält.

const PATH := "res://data/creatures/creature.tres"
static var _cached: CreatureConfig


static func get_default() -> CreatureConfig:
	if _cached == null:
		_cached = load(PATH) as CreatureConfig
		if _cached == null:
			_cached = CreatureConfig.new()
	return _cached


@export_group("Bewegung und Kraft")
@export var walk_speed: float = 1.5
@export var prowl_speed: float = 2.1
@export var chase_speed: float = 4.4
## Schaden am Spieler pro Treffer bzw. an Tür/Fenster pro Schlag.
@export var hit_damage: float = 34.0
@export var entry_hit: float = 14.0

@export_group("Entdecken")
## Bemerkt den Spieler draußen bis zu dieser Entfernung (beim Beobachten / Herumschleichen / an einem Zugang).
@export var spot_distance_observe: float = 22.0
@export var spot_distance_prowl: float = 18.0
@export var spot_distance_entry: float = 14.0
## Erkundung: so lange starrt sie den Spieler an, bevor sie mit dem Teleporterblitz verschwindet.
@export var stare_time: float = 2.2

@export_group("Erkundung (rütteln, tasten)")
## Wie viele Zugänge sie prüft, wie lange sie an einem bleibt, wie oft sie rüttelt/tastet.
@export var probe_entries: Vector2i = Vector2i(1, 2)
@export var probe_time: Vector2 = Vector2(7.0, 12.0)
@export var probe_interval: Vector2 = Vector2(3.0, 5.0)

@export_group("Klang")
## Wie oft ein Schritt zu hören ist (sonst lautlos) – beim Schleichen und auf der Jagd.
@export var step_chance: float = 0.25
@export var step_chance_chase: float = 0.8
@export var step_volume_db: float = -10.0
@export var step_volume_chase_db: float = -4.0
@export var step_pitch: Vector2 = Vector2(0.72, 0.82)
## Aus der Ferne meist still: Chance auf Stille statt Atmen, und Pause danach.
@export var far_silence_chance: float = 0.75
@export var far_silence_pause: Vector2 = Vector2(6.0, 14.0)
## Klicken und lautes Atmen erst ab dieser Nähe.
@export var close_distance: float = 10.0
