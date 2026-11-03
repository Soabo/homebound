# CLAUDE.md – Arbeitsnotizen für Homebound

## Zusammenarbeit
- Christian ist kein Programmierer. Er beschreibt Wünsche im Chat, Claude baut alles selbst
  (Code, Level, Szenen) und liefert spielbare Windows-Builds.
- Kommunikation mit Christian auf Deutsch, ohne Fachjargon.
- Kommentare im Code auf Deutsch, Bezeichner auf Englisch.
- Offene Designfragen aus GDD Kap. 21 nicht eigenmächtig festschreiben – nachfragen.

## Technik
- Engine: Godot 4.7.2 (Forward+), Physik: Jolt.
- Die Welt wird per GDScript gebaut (`scripts/world/*`), damit alles als Text im Repo liegt
  und ohne Editor geändert werden kann. `BuildKit` liefert Kisten, Wände mit Öffnungen,
  Materialien und Shader-Holz/-Stein.
- Spielwerte gehören in Datendateien unter `data/` (GDD 17.4): `.tres` für Konfiguration
  (Zeit, Bedrohung), JSON für Inhalte (`data/items/items.json`, `recipes.json`, `buildables.json`).
  JSON wird über `include_filter="*.json"` mit exportiert.
- Persistente Objekte brauchen feste, eindeutige Knotennamen (sonst passt der Spielstand nicht).
- Designentscheidung Phase 6: keine Waffen, Hunger/Durst sanft, freies Bauen.
- Systeme kommunizieren über `EventBus` (Autoload) statt sich direkt zu kennen.

## Befehle (Cloud-Workspace)
```bash
# Import / Klassen-Cache erzeugen
godot --headless --path . --import
# Kurzer Testlauf auf Skriptfehler
godot --headless --path . --quit-after 300
# Screenshots (Software-Vulkan, langsam: ~2-3 Min. pro Bild)
xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver vulkan \
  --resolution 1280x720 -- --screenshot-tour=/pfad/ordner
# Windows-Build
godot --headless --path . --export-release "Windows Desktop" build/windows/Homebound.exe
```
Export-Vorlagen müssen unter `~/.local/share/godot/export_templates/4.7.2.stable/` liegen
(aus `Godot_v4.7.2-stable_export_templates.tpz` von GitHub).

## Koordinaten
- Hütte: Mitte bei (0,0,0), 12 x 9 m, Boden auf y = 0.45, Eingang nach +z (Süden).
- Grundstück/Zaun: x -20..22, z -16..18. Schuppen bei (14, 0, 6.5).
- Zufahrt läuft vom Tor (x -3, z 18) nach Süden. Spielfeldgrenze ±72 m.
