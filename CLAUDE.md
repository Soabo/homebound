# CLAUDE.md – Arbeitsnotizen für Homebound

## Zusammenarbeit
- Christian ist kein Programmierer. Er beschreibt Wünsche im Chat, Claude baut alles selbst
  (Code, Level, Szenen) und liefert spielbare Windows-Builds.
- Kommunikation mit Christian auf Deutsch, ohne Fachjargon.
- Kommentare im Code auf Deutsch, Bezeichner auf Englisch.
- Offene Designfragen aus GDD Kap. 21 nicht eigenmächtig festschreiben – nachfragen.
- Nach jedem Update immer die Links ausschreiben (nicht nur „der gewohnte Link“):
  Windows: https://github.com/Soabo/homebound/releases/tag/neueste-version
  Browser: https://soabo.github.io/homebound/

## Offene Fragen Phase 7 (Forschung) – vor Beginn von Christian beantworten lassen
1. Analysegerät gefunden (z. B. Absturzstelle im Wald) oder aus dem alten Funkgerät umgebaut?
2. Forschung passiv (Fund einlegen, warten) oder aktive Experimente (Strom, Licht, vergleichen) – Schwerpunkt?
3. Story: erste Hinweise, was die Wesen wollen, oder bleibt es ganz rätselhaft?
4. Phase-6-Wahl bestätigen: keine Waffen, Hunger/Durst sanft, freies Bauen.

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
- Sounds: Christian liefert echte Aufnahmen (oft lange Clips mit vielen Schritten).
  `tools/audio/slice.py QUELLE ZIEL 12` schneidet sie in Einzelschritte, mono OGG, gleich laut normiert.
  Ablage `assets/audio/steps/<wood|carpet|porch|grass|forest|gravel|soil|stone|water>/<sneak|walk|run|land|jump>_NN.ogg`
  (Landungen: `prepare.py land`; fehlende Arten über FALLBACK in footsteps.gd);
  Lautstärke je Untergrund/Gangart in `scripts/audio/footsteps.gd`. Kreatur: `assets/audio/creature/<art>_NN.ogg` über `CreatureSounds`
  (`tools/audio/prepare.py oneshot|long`; lange Atmen/Klicken-Aufnahmen werden als Zufallsausschnitte gespielt).
  Designentscheidung Kreaturklang: Mischung aus Insektenklicken und verzerrtem Atmen.
  Spieler: `assets/audio/player/<drink|eat|die|heartbeat|breath|flashlight>_NN.ogg` über `PlayerSounds` (ohne Raumklang).
  Übrige Geräusche (Haus, Umgebung, Wetter) noch prozedural (`SoundBank`, `WindAmbience`, `FireCrackle`).

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
