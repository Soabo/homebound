class_name FearConfig
extends Resource
## Werte für die Angst des Spielers (Christian 23.11.2026: „wahrhaftige Angst wie in Resident Evil / Alien Isolation“).
## Datei: data/player/fear.tres. Benutzt von `Fear` (scripts/player/fear.gd).
## Angst 0..1 steigt durch gesehene und gehörte Wesen, Dunkelheit draußen, Treffer und Schreckmomente.
## Sie macht lauter (Schritte, Atem), kostet beim Rennen mehr Puste, lässt Hände und Uhr-LED zittern.
## Ruhe kommt am Licht/Feuer und im Versteck (durchatmen).

const PATH := "res://data/player/fear.tres"
static var _cached: FearConfig


static func get_default() -> FearConfig:
	if _cached == null:
		_cached = load(PATH) as FearConfig
		if _cached == null:
			_cached = FearConfig.new()
	return _cached


@export_group("Quellen")
## Gruppen, deren Mitglieder Angst machen (Wesen, Arme, Erscheinungen)
@export var threat_groups: PackedStringArray = ["creature", "mauler", "seeker", "seeker_arm", "drone", "manipulator", "apparition"]
## Bis zu dieser Entfernung (m) macht ein GESEHENES Wesen Angst – je näher, desto mehr
@export var seen_range: float = 28.0
## Angst durch ein gesehenes Wesen ganz nah / an der Grenze
@export var seen_near: float = 1.0
@export var seen_far: float = 0.35
## Bis hierhin (m) spürt man ein Wesen auch ungesehen (Geräusche, Nähe)
@export var heard_range: float = 14.0
@export var heard_target: float = 0.45
## Ein Wesen, das einen bemerkt hat (Gruppe aware, Stufe ALERT): mindestens so viel
@export var alert_target: float = 0.8
## Nachts draußen, ohne eigenes Licht, nicht am Feuer
@export var dark_outside: float = 0.18
## Nachts weit weg von der Hütte (Wald, Zelt)
@export var far_night: float = 0.28
## Belagerungsnacht: Grundangst
@export var siege_base: float = 0.4
## Atem anhalten: ab so vielen Sekunden steigt die Angst (Herz wird lauter)
@export var breath_hold_from: float = 2.0
@export var breath_hold_max: float = 0.7
## Treffer: Schreck = Schaden / hurt_scale (höchstens 1)
@export var hurt_scale: float = 40.0
## Schreckmomente (EventBus.fear_spike) klingen so schnell ab (pro Sekunde)
@export var spike_decay: float = 0.09

@export_group("Ruhe")
## Licht oder Feuer in dieser Entfernung beruhigt (Kamin, Lampe, Lagerfeuer)
@export var calm_light_range: float = 4.5
## so viel Angst bleibt am Licht übrig (Faktor auf die Grundangst)
@export var calm_light_factor: float = 0.45
## Im Versteck, ohne Wesen in der Nähe: Grundangst × dieser Faktor
@export var calm_hidden_factor: float = 0.3
## Steigen / Sinken pro Sekunde
@export var rise_speed: float = 0.9
@export var fall_speed: float = 0.05
## Sinken am Licht, im Versteck (durchatmen) oder in der hellen Hütte
@export var fall_speed_calm: float = 0.16

@export_group("Folgen")
## Schritte und Geräusche: Hörweite × (1 + noise_extra × Angst)
@export var noise_extra: float = 0.6
## Ab dieser Angst atmet man hörbar (auch im Stehen), Atemradius × (1 + breath_extra × Angst)
@export var breath_betray_from: float = 0.55
@export var breath_extra: float = 1.2
## Atem anhalten kostet mehr: × (1 + breath_drain_extra × Angst)
@export var breath_drain_extra: float = 0.9
## Rennen kostet mehr Puste: × (1 + sprint_drain_extra × Angst)
@export var sprint_drain_extra: float = 0.8
## Hände zittern (Meter / Grad) und die LED wackelt
@export var tremble_pos: float = 0.009
@export var tremble_rot: float = 2.4
## Ab hier Herzschlag
@export var heart_from: float = 0.08
