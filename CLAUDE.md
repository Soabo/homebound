# CLAUDE.md – Arbeitsnotizen für Homebound

## Zusammenarbeit
- Christian ist kein Programmierer. Er beschreibt Wünsche im Chat, Claude baut alles selbst
  (Code, Level, Szenen) und liefert spielbare Windows-Builds.
- Kommunikation mit Christian auf Deutsch, ohne Fachjargon.
- Kommentare im Code auf Deutsch, Bezeichner auf Englisch.
- Offene Designfragen aus GDD Kap. 21 nicht eigenmächtig festschreiben – nachfragen.
- Tempo vor Kontrollbildern: Bei kleinen Änderungen (Kamera drehen, Farbe, Lautstärke …) keine Screenshots,
  nur die schnellen Tests; Christian prüft selbst im Spiel. Screenshots nur bei größeren Umbauten oder auf Wunsch.
- Nach jedem Update immer die Links ausschreiben (nicht nur „der gewohnte Link“):
  Windows: https://github.com/Soabo/homebound/releases/tag/neueste-version
  Browser: https://soabo.github.io/homebound/

## Entscheidungen Phase 7 (Forschung)
- Analysegerät: zuerst improvisiert aus dem alten Funkgerät (Werkbank), später ein fremdes Gerät von der Absturzstelle im Wald.
- Forschung: Mischung aus passiver Analyse und aktiven Experimenten, Schwerpunkt aktiv.
- Story: erste Hinweise (man ahnt, dass sie etwas suchen, aber nicht was).
- Umsetzung: Inhalte in `data/research/research.json` (analyses mit experiments, links mit unlocks, notes);
  Rezepte mit `requires` = Verknüpfung. Gerät am Funkgerät (`Radio`), Absturzstelle `CrashSite` bei (-42, -30).
- Phase 6 bestätigt: Hunger/Durst sanft, freies Bauen.

## Entscheidungen Phase 8 (Weltentwicklung)
- Neue Arten: alle drei – Drohne (scannt nachts), Manipulator (lockt mit Geräuschen hinaus), Organismus (Wucherung, breitet sich aus).
- Terraforming: erst nur Stimmung, später mit Folgen (Wasser verunreinigt, fremde Pflanzen, Nebel …).
- Tempo: überlebte Tage + Forschungsfortschritt.
- Orte: größeres Gebiet, fremde Struktur (Vermessungspunkt), Höhle am Bach, Förster-Hochsitz.
- Umsetzung: `WorldState` (Wert = Tage + Analysen + Verknüpfungen, Stufen 0–4), `Terraformer` zeigt es an.
  Drohne `AlienDrone`, Manipulator `Manipulator` (Ereignisse im ThreatDirector, `spawn_ambush`), Organismus
  `OrganismNode` + `OrganismNode.Patch`. Struktur abschalten: Säulen in Reihenfolge `AlienStructure.ORDER`.
  Test: `--night-test=world`.

## Entscheidungen Kreatur 2.0 (unheimlich statt bedrohlich)
- Spannungsbogen im ThreatDirector (`night_kind`: quiet | hints | sighting | visit | hunt): etwa jede dritte Nacht
  ein Auftritt, danach 1–2 ruhige Nächte. Nacht 1–3 nur Sichtungen, ab 4 Erkundungen (rütteln, tasten, kein Einbruch;
  entdeckt sie dich draußen: starren, Teleporterblitz, weg), ab 6 echte Angriffe. `spawn_ambush` vor Tag 6 = nur Sichtung.
- Auftritte ohne Angriff: `Apparition` (edge = Waldrand/Augenwinkel, window = Gesicht am Fenster, inside = nach dem
  Aufwachen im Haus + Teleporterblitz beim Hinsehen, forest = tagsüber im Wald). Spuren: `Traces` (Abdrücke, Kratzer, Schlamm).
- Schritte der Kreatur sparsam und tief, Klicken nur aus der Nähe. Test: `--night-test=dread`.
- Ab Nacht 6 (`mind_from_night`): Wer die Kreatur ansieht (sichtbar: nah, angeleuchtet, Tag), dem dringt sie ins Hirn –
  Verzerrung im Retro-Shader (`mind`), Ton `assets/audio/creature/mind_01.ogg`, Schaden pro Sekunde; Wegsehen klingt ab.
  Sie stört die Uhr-Lampe (Flackern, kurzer Ausfall), wenn sie schleicht, jagt oder angeleuchtet wird (`PlayerHands.interfere`).
  Licht zählt nur, wenn es wirklich leuchtet: `Player.light_shining()`.
- Veränderungen draußen nach Nächten mit Alien-Aktivität: `NightChanges` (Gruppe night_changes, persistent;
  Handtücher fehlen/fremdes Handtuch, Bank versetzt, Zaunloch, Steinsäule, Vogelscheuche schaut zum Haus,
  Schuppentür offen, Holzkreis, Scheinwerfer glimmt, Steinlinie, Stiefel vor der Tür). Wann/wie oft/wie lange:
  ThreatConfig `night_change_*`. Bank = `Cabin/PorchBench`, Handtücher `Garden/Towels/Towel_N`, Zaun `Garden/FenceSeg_N`.
- Radio: Nachricht pro Tag aus `data/radio/radio.json` (Texte = Platzhalter, Story offen laut GDD 21), grüne Leuchte
  bei ungehörter Nachricht, blendet nach `play_seconds` aus und schaltet ab. Test: `--night-test=changes`.
- Couch + Tablet: `Couch` (Cabin/Couch, persistent: gelesene Nachrichten), `TabletMenu`; Inhalte `data/tablet/tablet.json`
  (Mails/News mit `day`; Familie: Frau Julia, Kinder Lena und Ben, LKW-Unfall bei Regen – Namen sind Platzhalter).
  Müdigkeit 23–1 Uhr (TimeConfig `tired_*`): Hinweis „ins Bett“, wenn bis dahin nichts los war (ThreatDirector).
- Kamin: `Fireplace` brennt `burn_hours`, wird die letzten `fade_hours` dunkler/leiser, mit Holz neu (data/house/house.json).
- Nacht: erste Hälfte stockfinster, Mond geht ab ~1 Uhr auf (schwaches Licht). Streulicht der Hände nur auf Sichtebene 20.
- Bach: Ufer immer über Wasser (Terrain `BANK_HEIGHT`, `WATER_LEVEL`, `WATER_HALF_WIDTH`), Prüfung `--walk-test --stream`.
- Truhe `StorageChest` (Cabin/StorageChest, Werkstatt unter der Werkzeugwand, persistent), Menü in GameMenus („chest“).
- Bildchen für Gegenstände: `ItemIcons` lädt `assets/icons/items/<id>.png|jpg|webp`, sonst Platzhalter (Kategorie-Farbe + Kürzel).
- Alt = langsam und leise gehen (`walk_slow`, `Player.SLOW_FACTOR`). Sprint nur, solange Shift wirklich gedrückt ist.
- Kreatur auf der Jagd bleibt `hunt_hours`, nur mit `whole_night_chance` die ganze Nacht (CreatureConfig).
- TEST-Knopf im Pausenmenü „zu Tag 10 springen“ (`PauseMenu._test_jump_to_day`) – auf Christians Wunsch später entfernen.
- Andere Gegner ebenfalls unberechenbar: Drohne mit zufälligen Mustern (Bahnen, Kreisen, Suchen, vor Fenster
  schweben und hineinleuchten) und reagiert auf Geräusche; Manipulator wechselt ungesehen die Stelle, nähert sich
  manchmal, schweigt manchmal lange, ahmt Hausgeräusche nach; Organismus wächst verzweigt mit wechselnden Zielen,
  mal gar nicht, mal in Schüben, ab Stufe 3 Sporensprünge.

## Technik
- Engine: Godot 4.7.2 (Forward+), Physik: Jolt.
- Die Welt wird per GDScript gebaut (`scripts/world/*`), damit alles als Text im Repo liegt
  und ohne Editor geändert werden kann. `BuildKit` liefert Kisten, Wände mit Öffnungen,
  Materialien und Shader-Holz/-Stein.
- Spielwerte gehören in Datendateien unter `data/` (GDD 17.4): `.tres` für Konfiguration
  (Zeit, Bedrohung), JSON für Inhalte (`data/items/items.json`, `recipes.json`, `buildables.json`).
  JSON wird über `include_filter="*.json"` mit exportiert.
- Christians Regel: Spielwerte immer gleich beim zuständigen Manager/System ablegen, nicht im Code verstreut.
  Wann etwas passiert (Spannungsbogen, wie oft die Kreatur/Drohne/Manipulator kommt, Schlafsperre) →
  Threat Director `data/threat/default_threat.tres` (`ThreatConfig`). Wie sich ein Gegner verhält → Gegner-KI
  `data/creatures/<art>.tres` (`CreatureConfig`, `DroneConfig`, `ManipulatorConfig`). Talverwandlung und
  Wachstum des Organismus → World State Manager `data/world/world_state.tres` (`WorldConfig`).
  Zeit → `data/time/default_time_config.tres`.
- Persistente Objekte brauchen feste, eindeutige Knotennamen (sonst passt der Spielstand nicht).
- Designentscheidung Phase 6: Hunger/Durst sanft, freies Bauen. Keine Schusswaffen; Nahkampf mit Faust/Axt
  (Christians Wunsch) verscheucht die Kreatur nur (`Creature.on_melee_hit`), töten geht nicht.
- Hände: `PlayerHands` (an der Kamera). Rechts = Schnellplatz 1–9 (`Inventory.hotbar`, Items mit `"hand"` in items.json),
  leer = Faust. Links = Smartwatch-LED (F, `player.flashlight`) und Bauhammer im Baumodus. Nachschwingen per Feder.
- Systeme kommunizieren über `EventBus` (Autoload) statt sich direkt zu kennen.
- Sounds: Christian liefert echte Aufnahmen (oft lange Clips mit vielen Schritten).
  `tools/audio/slice.py QUELLE ZIEL 12` schneidet sie in Einzelschritte, mono OGG, gleich laut normiert.
  Ablage `assets/audio/steps/<wood|carpet|porch|grass|forest|gravel|soil|stone|water>/<sneak|walk|run|land|jump>_NN.ogg`
  (Landungen: `prepare.py land`; fehlende Arten über FALLBACK in footsteps.gd);
  Lautstärke je Untergrund/Gangart in `scripts/audio/footsteps.gd`. Kreatur: `assets/audio/creature/<art>_NN.ogg` über `CreatureSounds`
  (`tools/audio/prepare.py oneshot|long`; lange Atmen/Klicken-Aufnahmen werden als Zufallsausschnitte gespielt).
  Designentscheidung Kreaturklang: Mischung aus Insektenklicken und verzerrtem Atmen.
  Störgeräusche (Brummen/Rauschen) entfernt `tools/audio/denoise.py EIN AUS [stärke] [hochpass_hz]`.
  Spieler: `assets/audio/player/<drink|eat|die|heartbeat|breath|flashlight>_NN.ogg` über `PlayerSounds` (ohne Raumklang).
  Haus/Umgebung/Bauen/Menü: `tools/audio/sfx.py QUELLORDNER` (Zuordnung Dateiname -> ID in MAP) legt
  `assets/audio/sfx/<id>_NN.ogg` an. `SoundBank.get_sound(id)` nimmt zuerst diese Aufnahmen (LOOP_IDS werden
  wiederholt, GAIN = Lautstärke-Ausgleich), sonst den prozeduralen Ersatz (`get_generated`).

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
- Zufahrt läuft vom Tor (x -3, z 18) nach Süden. Spielfeldgrenze ±104 m (Gelände ±112, Wald ±108).
- Orte: Absturzstelle (-42,-30), fremde Struktur (-78, 40), Höhle am Bach (49, -72), Förster-Hochsitz (12, -80).
