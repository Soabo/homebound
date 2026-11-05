# Architektur

Umsetzung der Systeme aus GDD Kap. 17 in Godot.

| GDD-System | Godot-Umsetzung | Stand |
|---|---|---|
| Time Manager | Autoload `TimeManager` (`scripts/systems/time_manager.gd`) + `TimeConfig`-Daten | ✅ Tag/Nacht, Uhr, Zeitsprung beim Schlafen, Zustand speicherbar |
| Threat Director | Autoload `ThreatDirector` + `ThreatConfig` (`data/threat/`) | ✅ Bedrohungsstufe, Nacht-Intensität, Ereignisplan, Schlaf-Störungen, Lernspeicher |
| Alien AI | `Creature` (`scripts/creature/`), Wegpunkt-Ring ums Haus, Zustandsautomat | ✅ erste Kreatur: Sicht/Licht/Gehör, Zugänge angreifen, Verfolgung |
| Power (GDD 7.4) | Autoload `PowerManager` | ✅ Generator, Benzin, Verbraucher, Ausfall |
| Überwachung (GDD 7.5) | `Surveillance` + `SecurityCamera` + `MonitorStation` | ✅ 3 Kameras an Wandhaltern (Hausfront, Garten, Maisfeld), Gehäuse auf Sichtebene 4 (nicht im Kamerabild), Störungen, Trugbilder (Sichtebene 2) |
| World State Manager | Autoload `WorldState` + `Terraformer` (sichtbar machen) | ✅ Terraforming-Stufen aus Tagen + Forschung, verunreinigtes Wasser, Wucherungen des Organismus, fremde Struktur, Drohne (`AlienDrone`), Manipulator |
| Base Building Manager | Autoload `Builder` + `BuildController` + `Structure` | ✅ freies Platzieren, Hindernisse, Fallen, Alarm, Licht; Daten in `data/items/buildables.json` |
| Research Manager | Autoload `Research` + `ResearchMenu` (Analyse, Archiv J) + Daten `data/research/research.json` | ✅ Gerätestufen, Analysen mit Experimenten, Verknüpfungen → Baupläne, Notizen, Absturzstelle (`CrashSite`) |
| Inventory Manager | Autoload `Inventory` + `DataDB` | ✅ Traglast, Essen/Trinken; Daten in `data/items/items.json`, Rezepte in `recipes.json` |
| Survival (GDD 6.1) | Autoload `Survival` | ✅ Hunger, Durst, Ausdauer |
| Episode Manager | Autoload | ⏳ Phase 9 |
| Save Manager | Autoload `GameState` | 🟡 Tages-Schnappschuss inkl. Weltzustand (Gruppe `persistent`) und Bauten; Speichern auf Platte folgt |

## Grundregeln
- **Entkopplung:** Systeme senden Signale über `EventBus`. Der Threat Director löst nur
  Ereignisse aus; wie sich eine Kreatur verhält, entscheidet ihre eigene KI (GDD 17.3).
- **Spielstand:** Objekte mit Zustand sind in der Gruppe `persistent`, haben einen stabilen
  Namen und bieten `persist_key()`, `get_state()`, `set_state()`; in `_ready()` rufen sie
  `GameState.restore(self)` auf.
- **Daten statt Code:** Inhalte (Ereignisse, Spezies, Bauobjekte, Forschung) werden als
  `Resource`-Dateien unter `data/` angelegt, damit neue Inhalte ohne Umbau hinzukommen.
- **Interaktion:** Alles Benutzbare erbt von `Interactable` (`get_prompt`, `interact`,
  optional `get_secondary_prompt`, `secondary_interact`). Der Spieler findet es per Raycast.
- **Speicherbarkeit:** Jedes System mit Zustand bekommt `get_state()` / `set_state()`.

## Zugänge (Fenster/Türen)
Alles in der Gruppe `entry_point` bietet: `outside_point()`, `inside_point()`, `strength()`,
`is_breached()`, `receive_hit(dmg)`, `entry_name()`. Neue Zugänge (z. B. Kellerluke)
funktionieren dadurch automatisch mit der Kreaturen-KI.

## Erkennbarkeit
- `InteractFrame` (HUD): feine Eckklammern um die Kollisionsform des anvisierten, benutzbaren Objekts.
- `Icons`: Pixel-Symbole als Aufkleber (`Icons.decal`) – fuel, food, water, nails, power; `Icons.food_can` für Dosen.

## Tests
- `-- --walk-test`: läuft durch alle Türen und das Tor
- `-- --night-test=attack|probe|observe|attack_locked`: Kreatur-Protokoll
- `-- --night-test=events`: löst jedes Nacht-Ereignis einmal aus
- `-- --night-test=research`: Phase 7 komplett – Absturzstelle, Umbau, Analysen, fremdes Gerät, Verknüpfen, Baupläne, Stroboskop
- `-- --night-test=world`: Phase 8 – Stufen, Wasser/Filter, Wucherungen, Knoten, Säulenrätsel, Hochsitz, Drohne, Manipulator, Baupläne
- `-- --night-test=melee`: Hände – Faust/Axt gegen Kreatur, Blocken, Schnellplatz-Wechsel, Uhr-Lampe
- `-- --night-test=craft`: Rezepte, Barrikade, Bauen, Kreatur gegen Hindernisse, Neustart-Persistenz
- `-- --screenshot-tour=ORDNER [--shots=01,05] [--frames=30]`

## Ordner
```
data/            Spielwerte als .tres
docs/            GDD und Architektur
scenes/          main.tscn (baut die Welt per Skript)
scripts/core/    EventBus, Tastenbelegung
scripts/systems/ Manager (Zeit …)
scripts/world/   Gelände, Wald, Garten, Hütte, Schuppen, Licht/Himmel, BuildKit
scripts/interaction/ Türen, Fenster, Lampen, Schalter, Bett
scripts/player/  First-Person-Controller, Hände (PlayerHands)
scripts/ui/      HUD, Pausenmenü
scripts/audio/   SoundBank (prozedurale Platzhalter), Footsteps (echte Schritt-Aufnahmen), CreatureSounds (Kreatur)
assets/audio/    Tondateien (steps/ je Untergrund und Gangart, creature/)
tools/audio/     Python-Werkzeuge zum Zuschneiden von Aufnahmen (nicht im Spiel)
scripts/dev/     Entwickler-Werkzeuge (Screenshot-Tour)
shaders/         Holz- und Stein-Shader
```
