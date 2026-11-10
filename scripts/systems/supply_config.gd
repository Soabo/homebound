class_name SupplyConfig
extends Resource
## Werte des Versorgungs-Managers (Supplies): Garten, Wasser, Fallen, Generator-Wartung, Metallquellen.
## Datei: data/supplies/supplies.tres

@export_group("Hochbeete")
## Je Pflanze: Tage bis zur Ernte, Ertrag (min/max), Samen-Gegenstand, Ernte-Gegenstand
@export var crops: Dictionary = {
	"radish": {"name": "Radieschen", "days": 2, "yield": [3, 5], "item": "radish"},
	"carrot": {"name": "Karotten", "days": 4, "yield": [3, 5], "item": "carrot"},
	"potato": {"name": "Kartoffeln", "days": 5, "yield": [4, 7], "item": "potato"},
}
## Samen, die man beim Ernten zusätzlich zurückbekommt (min/max)
@export var seeds_back: Vector2i = Vector2i(0, 2)
## Tage ohne Gießen, bis die Pflanzen eingehen (an einem ungegossenen Tag wächst nichts)
@export var dry_days_to_wither: int = 2
## Chance pro Tag je Talverwandlungs-Stufe 0..4, dass ein Beet „fremd“ wird (graue Blätter, Ernte verdorben)
@export var alien_spoil_chance: PackedFloat32Array = PackedFloat32Array([0.0, 0.03, 0.08, 0.18, 0.35])
## Gießkanne: so viele Beete pro Füllung
@export var watering_can_charges: int = 4

@export_group("Kochen")
## So viele Spielstunden brennt der Küchenofen mit einem Holz
@export var stove_burn_hours: float = 2.0

@export_group("Wasser")
## Chance, dass einem von Rohwasser/rohem Essen übel wird (zusätzlich zur Angabe am Gegenstand)
@export var sick_damage: float = 6.0
## Übelkeit: Durst und Hunger sinken so viel schneller (Faktor) für so viele Stunden
@export var sick_drain_factor: float = 2.0
@export var sick_hours: float = 4.0

@export_group("Fallen und Jagd")
## Chance pro Nacht, dass eine Schlinge einen Hasen fängt (im Wald), auf dem Grundstück halbiert
@export var snare_catch_chance: float = 0.4
@export var snare_meat: Vector2i = Vector2i(1, 2)
## Faktor je Talverwandlungs-Stufe 0..4 (die Tiere verschwinden)
@export var snare_stage_factor: PackedFloat32Array = PackedFloat32Array([1.0, 0.7, 0.45, 0.2, 0.0])

@export_group("Generator-Wartung")
## Zustand 0..100: sinkt pro Laufstunde
@export var wear_per_hour: float = 1.1
@export var oil_restore: float = 45.0
@export var plug_restore: float = 25.0
## Unter diesem Zustand stottert er: Chance pro Laufstunde, dass er ausgeht
@export var low_condition: float = 40.0
@export var low_outage_chance: float = 0.12
## Unter diesem Zustand springt er oft nicht an
@export var bad_condition: float = 15.0
@export var bad_start_fail: float = 0.5
## Holzvergaser: Tank-Prozent pro Holz; Energiezelle: Tank-Prozent pro Zelle
@export var fuel_per_wood: float = 7.0
@export var fuel_per_cell: float = 100.0

@export_group("Metallquellen im Wald")
## Höchstens so viele Fundstellen gleichzeitig, neue pro Tag (min/max)
@export var scrap_spots_max: int = 7
@export var scrap_spots_per_day: Vector2i = Vector2i(1, 2)
@export var scrap_spots_start: int = 3
## Anteil der neuen Stellen, die in der Nähe des Autowracks entstehen
@export var scrap_near_wreck: float = 0.45
## Je Art: Schrott (min/max), Chance auf Zündkerze / Motoröl
@export var scrap_kinds: Dictionary = {
	"exhaust": {"name": "Alter Auspuff", "scrap": [2, 3], "plug": 0.0, "oil": 0.0},
	"engine": {"name": "Alter Motorblock", "scrap": [3, 5], "plug": 0.6, "oil": 0.35},
	"silo": {"name": "Stück eines Metallsilos", "scrap": [4, 6], "plug": 0.0, "oil": 0.0},
	"tractor": {"name": "Traktorteile", "scrap": [3, 4], "plug": 0.3, "oil": 0.25},
	"barrel": {"name": "Rostiges Ölfass", "scrap": [2, 3], "plug": 0.0, "oil": 0.5},
}
