# Architektur

Umsetzung der Systeme aus GDD Kap. 17 in Godot.

| GDD-System | Godot-Umsetzung | Stand |
|---|---|---|
| Time Manager | Autoload `TimeManager` (`scripts/systems/time_manager.gd`) + `TimeConfig`-Daten | ✅ Tag/Nacht, Uhr, Zeitsprung beim Schlafen, Zustand speicherbar |
| Threat Director | Autoload `ThreatDirector` + `ThreatConfig` (`data/threat/`) | ✅ Bedrohungsstufe, Nacht-Intensität, Ereignisplan, Schlaf-Störungen, Lernspeicher |
| Alien AI | `Creature` (`scripts/creature/`), Wegpunkt-Ring ums Haus, Zustandsautomat | ✅ erste Kreatur: Sicht/Licht/Gehör, Zugänge angreifen, Verfolgung |
| Power (GDD 7.4) | Autoload `PowerManager` | ✅ Generator, Benzin, Verbraucher, Ausfall |
| Überwachung (GDD 7.5) | `Surveillance` + `SecurityCamera` + `MonitorStation` | ✅ 3 Kameras, Störungen, Trugbilder (Sichtebene 2) |
| World State Manager | Autoload, Terraforming-Zustand | ⏳ Phase 8 |
| Base Building Manager | Platzierungssystem fürs Grundstück | ⏳ Phase 2/6 |
| Research Manager | Autoload + Forschungsobjekte als Ressourcen | ⏳ Phase 7 |
| Inventory Manager | Autoload `Inventory` | 🟡 Grundlage (Benzin, Bretter); Item-Daten noch im Skript |
| Episode Manager | Autoload | ⏳ Phase 9 |
| Save Manager | Autoload `GameState` | 🟡 Schnappschuss zu Tagesbeginn, Neustart nach Tod; Speichern auf Platte folgt |

## Grundregeln
- **Entkopplung:** Systeme senden Signale über `EventBus`. Der Threat Director löst nur
  Ereignisse aus; wie sich eine Kreatur verhält, entscheidet ihre eigene KI (GDD 17.3).
- **Daten statt Code:** Inhalte (Ereignisse, Spezies, Bauobjekte, Forschung) werden als
  `Resource`-Dateien unter `data/` angelegt, damit neue Inhalte ohne Umbau hinzukommen.
- **Interaktion:** Alles Benutzbare erbt von `Interactable` (`get_prompt`, `interact`,
  optional `get_secondary_prompt`, `secondary_interact`). Der Spieler findet es per Raycast.
- **Speicherbarkeit:** Jedes System mit Zustand bekommt `get_state()` / `set_state()`.

## Zugänge (Fenster/Türen)
Alles in der Gruppe `entry_point` bietet: `outside_point()`, `inside_point()`, `strength()`,
`is_breached()`, `receive_hit(dmg)`, `entry_name()`. Neue Zugänge (z. B. Kellerluke)
funktionieren dadurch automatisch mit der Kreaturen-KI.

## Tests
- `-- --walk-test`: läuft durch alle Türen und das Tor
- `-- --night-test=attack|probe|observe|attack_locked`: Kreatur-Protokoll
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
scripts/player/  First-Person-Controller
scripts/ui/      HUD, Pausenmenü
scripts/audio/   Prozedurale Platzhalter-Sounds
scripts/dev/     Entwickler-Werkzeuge (Screenshot-Tour)
shaders/         Holz- und Stein-Shader
```
