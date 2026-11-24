class_name StealthConfig
extends Resource
## Werte fürs Schleichen (Christian 14.11.2026): wie laut und wie sichtbar der Spieler ist,
## wie Wind/Regen übertönen, Atem anhalten (Alt) und wie schnell Gegner etwas bemerken.
## Datei: data/stealth/stealth.tres. Benutzt von `Stealth` (Spieler-Seite) und `Awareness` (Gegner-Seite).

const PATH := "res://data/stealth/stealth.tres"
static var _cached: StealthConfig


static func get_default() -> StealthConfig:
	if _cached == null:
		_cached = load(PATH) as StealthConfig
		if _cached == null:
			_cached = StealthConfig.new()
	return _cached


@export_group("Schritte (Hörweite in Metern)")
## Hörweite eines Schritts je Gangart: geduckt, langsam (Alt), normal, rennen
@export var step_sneak: float = 1.5
@export var step_slow: float = 2.0
@export var step_walk: float = 7.0
@export var step_run: float = 18.0
## Faktor je Untergrund (Laub und Äste, Kies und Wasser laut; Teppich, Erde, Wiese leise)
@export var surface_factor: Dictionary = {
	"wood": 1.0, "carpet": 0.4, "porch": 1.2, "grass": 0.7, "forest": 1.3,
	"gravel": 1.5, "soil": 0.6, "stone": 0.9, "water": 1.8, "snow": 1.1,
}
## Im Haus dämpfen die Wände, was draußen ankommt
@export var indoor_factor: float = 0.5
## Im Wald knackt beim Gehen/Rennen manchmal ein Ast (Wahrscheinlichkeit pro Schritt, Hörweite × Faktor)
@export var twig_chance: float = 0.12
@export var twig_factor: float = 2.0
## Schlag mit Faust/Werkzeug gegen etwas Festes (Hörweite)
@export var melee_noise: float = 9.0

@export_group("Knarrende Dielen")
## Dielen (Orte in data/house/house.json „creaky_boards“): Hörweite beim normalen Gehen / Rennen
@export var creak_radius: float = 9.0
## Geduckt oder langsam knarrt es nur manchmal und leiser
@export var creak_soft_chance: float = 0.3
@export var creak_soft_radius: float = 3.0

@export_group("Wind und Regen übertönen")
## Ab dieser Windstärke am Ort (Wind.at) beginnt der Wind Schritte zu übertönen, bei wind_mask_full am meisten
@export var wind_mask_from: float = 0.25
@export var wind_mask_full: float = 0.7
@export var wind_mask_max: float = 0.6
## Regen / Gewitter übertönen draußen so viel (im Haus die Hälfte: Regen aufs Dach)
@export var rain_mask: float = 0.45
@export var storm_mask: float = 0.65
## Höchstens so viel wird zusammen übertönt
@export var mask_max: float = 0.75

@export_group("Atem anhalten (Alt)")
## Ausdauer pro Sekunde beim Anhalten; bei breath_gasp_at schnappt man laut nach Luft
@export var breath_drain: float = 6.0
@export var breath_gasp_at: float = 4.0
## Hörweite des Luftschnappens, danach so lange kein Anhalten möglich
@export var gasp_radius: float = 8.0
@export var breath_recover: float = 5.0
## Atem hört ein Gegner aus dieser Nähe (ruhig / außer Atem nach dem Rennen)
@export var breath_radius: float = 2.5
@export var breath_radius_panting: float = 6.0

@export_group("Sichtbarkeit (0 = unsichtbar, 1 = voll zu sehen)")
@export var vis_dark: float = 0.22
## Dazu im Mondlicht (bei vollem, freiem Mond)
@export var vis_moon: float = 0.35
## Auf Schnee hebt man sich nachts als dunkle Gestalt ab (Zuschlag bei voller Schneedecke, draußen, nicht im Dunkel ohne Mond)
@export var vis_snow: float = 0.12
@export var vis_day: float = 1.0
## Eigenes Licht / in der Nähe einer brennenden Lampe oder eines Feuers
@export var vis_own_light: float = 1.0
@export var vis_near_light: float = 0.9
@export var near_light_range: float = 6.0
## Im Haus: Raum beleuchtet (durchs Fenster zu sehen) / dunkel
@export var vis_inside_lit: float = 0.9
@export var vis_inside_dark: float = 0.2
## Unter dichten Baumkronen (Schatten) wird Mond- und Tageslicht so stark gedämpft
@export var canopy_shade: float = 0.5

@export_group("Hände im Dunkeln (Christian 15.11.: Axt & Co. sollen von der Umgebung beleuchtet werden)")
## Streulicht nur für die Hände: so hell bei vollem Tageslicht / Lampe, im Stockdunkeln nur hand_fill_min davon
@export var hand_fill_energy: float = 0.25
@export var hand_fill_min: float = 0.04
## Mit eingeschalteter Uhr bekommen die Hände etwas Licht vom Handgelenk
@export var hand_fill_watch: float = 0.35
## Geduckt / rennend
@export var crouch_factor: float = 0.7
@export var run_bonus: float = 0.15
## Atemwolke in kalten Nächten (kurz nach jedem Ausatmen)
@export var breath_cloud_bonus: float = 0.1

@export_group("Lehnen und Spähen")
## Nur der Kopf schaut hervor: so viel vom Spieler sieht ein Gegner (beim Lehnen / ohne Lehnen über eine Kante)
@export var peek_lean: float = 0.25
@export var peek_head: float = 0.5

@export_group("Verdacht (Gegner)")
## Stufen: ab suspect hält es inne und schaut, ab investigate kommt es nachsehen, bei 1 hat es dich entdeckt
@export var suspect_at: float = 0.3
@export var investigate_at: float = 0.6
## Sekunden bis zum Entdecken bei voller Sichtbarkeit: ganz nah / am Rand der Sichtweite
@export var notice_close: float = 0.7
@export var notice_far: float = 4.5
## Ein Geräusch direkt neben dem Gegner bringt so viel Verdacht (weiter weg weniger)
@export var noise_gain: float = 0.7
## Gehörter Atem pro Sekunde
@export var breath_gain: float = 0.35
## Verdacht klingt ab (pro Sekunde), wenn es eine Weile nichts mehr wahrnimmt
@export var decay: float = 0.12
@export var decay_delay: float = 2.5
## Sichtweite eines Gegners: bei Sichtbarkeit 0 / 1 (die Kreatur: 4 → 34 m)
@export var sight_min: float = 4.0
@export var sight_max: float = 34.0
## Wie lange es am Verdachtsort sucht (Sekunden)
@export var investigate_time: Vector2 = Vector2(6.0, 11.0)
