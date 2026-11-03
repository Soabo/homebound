# Architektur

Umsetzung der Systeme aus GDD Kap. 17 in Godot.

| GDD-System | Godot-Umsetzung | Stand |
|---|---|---|
| Time Manager | Autoload `TimeManager` (`scripts/systems/time_manager.gd`) + `TimeConfig`-Daten | ✅ Tag/Nacht, Uhr, Zeitsprung beim Schlafen, Zustand speicherbar |
| Threat Director | Autoload, wählt Ereignisse aus Daten (`data/events/`) | ⏳ Phase 4 |
| Alien AI | Eigene Szene je Kreatur mit `NavigationAgent3D` + Wahrnehmungs-Komponenten | ⏳ Phase 4 |
| World State Manager | Autoload, Terraforming-Zustand | ⏳ Phase 8 |
| Base Building Manager | Platzierungssystem fürs Grundstück | ⏳ Phase 2/6 |
| Research Manager | Autoload + Forschungsobjekte als Ressourcen | ⏳ Phase 7 |
| Inventory Manager | Autoload + Item-Ressourcen | ⏳ Phase 2/6 |
| Episode Manager | Autoload | ⏳ Phase 9 |
| Save Manager | Autoload, sammelt `get_state()`/`set_state()` aller Systeme | ⏳ vorbereitet (`get_state` in Time Manager, Tür, Spieler) |

## Grundregeln
- **Entkopplung:** Systeme senden Signale über `EventBus`. Der Threat Director löst nur
  Ereignisse aus; wie sich eine Kreatur verhält, entscheidet ihre eigene KI (GDD 17.3).
- **Daten statt Code:** Inhalte (Ereignisse, Spezies, Bauobjekte, Forschung) werden als
  `Resource`-Dateien unter `data/` angelegt, damit neue Inhalte ohne Umbau hinzukommen.
- **Interaktion:** Alles Benutzbare erbt von `Interactable` (`get_prompt`, `interact`,
  optional `get_secondary_prompt`, `secondary_interact`). Der Spieler findet es per Raycast.
- **Speicherbarkeit:** Jedes System mit Zustand bekommt `get_state()` / `set_state()`.

## Ordner
```
data/            Spielwerte als .tres
docs/            GDD und Architektur
scenes/          main.tscn (baut die Welt per Skript)
scripts/core/    EventBus, Tastenbelegung
scripts/systems/ Manager (Zeit …)
scripts/world/   Gelände, Wald, Garten, Hütte, Schuppen, Licht/Himmel, BuildKit
scripts/interaction/ Türen, Fenster, Lampen, Schalter, Bett
scripts/player/  First-Person-Controller
scripts/ui/      HUD, Pausenmenü
scripts/audio/   Prozedurale Platzhalter-Sounds
scripts/dev/     Entwickler-Werkzeuge (Screenshot-Tour)
shaders/         Holz- und Stein-Shader
```
