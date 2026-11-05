class_name TimeConfig
extends Resource
## Einstellungen für Tag/Nacht (GDD 4.1: Dauer konfigurierbar).
## Die Werte liegen in data/time/default_time_config.tres.

@export_group("Phasen")
## Uhrzeit, ab der es als Tag gilt.
@export_range(0.0, 24.0, 0.25) var day_start_hour: float = 7.0
## Uhrzeit, ab der es als Nacht gilt.
@export_range(0.0, 24.0, 0.25) var night_start_hour: float = 19.0
## Echtzeit-Minuten für die ganze Tagphase.
@export var day_duration_minutes: float = 10.0
## Echtzeit-Minuten für die ganze Nachtphase.
@export var night_duration_minutes: float = 10.0

@export_group("Start")
@export var start_day: int = 1
@export_range(0.0, 24.0, 0.25) var start_hour: float = 16.5

@export_group("Schlafen")
## Ab wann man ins Bett darf (GDD 4.4: ab dem Nachmittag).
@export_range(0.0, 24.0, 0.25) var sleep_allowed_from_hour: float = 16.0
## Bis wann man noch schlafen gehen darf.
@export_range(0.0, 24.0, 0.25) var sleep_allowed_until_hour: float = 6.5
## Aufwachzeit in der vereinfachten Prototyp-Version.
@export_range(0.0, 24.0, 0.25) var wake_up_hour: float = 7.0

## Zwischen diesen Uhrzeiten wird der Spieler müde (zufällig, einmal pro Nacht) – wenn bis dahin nichts passiert ist.
@export_range(0.0, 24.0, 0.25) var tired_from_hour: float = 23.0
@export_range(0.0, 24.0, 0.25) var tired_until_hour: float = 1.0

@export_group("Test")
## Faktor, wenn T gedrückt gehalten wird.
@export var debug_fast_forward_multiplier: float = 40.0
