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
- Möbel stehen so, dass man an jedes Fenster treten kann (Prüfung im `--walk-test`: „FENSTER … frei“).
  Werkbank Ostwand nördlich vom Fenster, Generator an der Westwand des Technikraums, Esstisch weg vom Wohnzimmerfenster.
- TEST-Knopf im Pausenmenü „zu Tag 10 springen“ (`PauseMenu._test_jump_to_day`) – auf Christians Wunsch später entfernen.
- Andere Gegner ebenfalls unberechenbar: Drohne mit zufälligen Mustern (Bahnen, Kreisen, Suchen, vor Fenster
  schweben und hineinleuchten) und reagiert auf Geräusche; Manipulator wechselt ungesehen die Stelle, nähert sich
  manchmal, schweigt manchmal lange, ahmt Hausgeräusche nach; Organismus wächst verzweigt mit wechselnden Zielen,
  mal gar nicht, mal in Schüben, ab Stufe 3 Sporensprünge.

## Entscheidungen Verstecke, Fallen, Tiere
- Esstisch halbiert (2 Stühle). Technikraum ist jetzt Badezimmer (`_build_bathroom`), Generator steht im Schuppen
  (`Cabin.generator_model`) – bei Stromausfall muss man im Dunkeln raus.
- Verstecke `HideSpot` (Stil wardrobe = Kleiderschrank Cabin/Wardrobe mit Sehschlitz, locker = Spind Shed/Locker mit Lamellen):
  Tür geht zur Wand auf; drinnen + Tür zu = versteckt (`Player.is_hidden()`), Kreatur sieht einen dann nicht.
- Über 40 kg: Aufnehmen/Craften geht weiter, aber nur noch Gehen + Meldung (`Inventory.overloaded()`).
- Bärenfalle (Schrott 2 + Nägel 4, buildables `bear_trap`): immer gespannt, trifft auch den Spieler (Schaden + kurz
  festgehalten, `Player.held_time`); Kreatur verliert Gewebe (`Creature.on_trap`). Mit E neu spannen.
  Spießbarrikade verletzt die Kreatur → grünes Blut, Stachel mit Blut = `alien_blood` (Analyse `an_blood`).
- Blechschere `tin_snips` (Werkzeugwand, Cabin/TinSnips): rechte Hand, Stich (`MELEE` in PlayerHands), Schrott am Wagen nur damit.
  Schadensart an `Creature.on_melee_hit(…, damage)`: blunt | chop | stab (nur chop hinterlässt Gewebe).
- Tiere: `Wildlife` + `Animal`, Werte `data/world/wildlife.tres` (`WildlifeConfig`, gehört zum World State Manager).
  Weniger Tiere je Terraforming-Stufe, Zugvögel ab Stufe 1 bis 2. Rehe nachts nur Umriss + Augenreflex im Uhrlicht,
  fliehen vor Kreatur. Test: `--night-test=gear` (Verstecke, Überladung, Fallen, Schere, Tiere).

## Entscheidungen Kreatur 2.1 (noch gruseliger)
- Haltung: wechselt zufällig zwischen aufrecht und gebückt auf allen Vieren (schneller, Ellbogen nach hinten),
  `Creature._update_posture`, Werte `posture_interval`, `crawl_chance(_chase)`, `crawl_speed_factor` in CreatureConfig.
  Zum Schlagen/Hineingreifen/Anstarren richtet sie sich auf. Sichtprüfungen über `Creature.body_height()`.
- Lauernde Gestalt nur auf der Kamera: `Surveillance.spawn_lurker` (hockend, `CreatureModel.pose_crouch`, Orte
  `LURK_SPOTS` je Kamera, Sicht wird geprüft), verschwindet beim Umschalten/Schließen, dreht nach einer Weile
  den Kopf zur Kamera. Wie oft: ThreatConfig `camera_lurk_*`. Test: `--night-test=lurk`.

## Entscheidungen Feinschliff nach 10 Spieltagen
- Radio + Analysegerät stehen in der Werkstatt an der Nordwand (`Cabin._build_radio_corner`, Radio-Knoten lokal gedreht).
- Alien-Archiv und Notizen nur noch auf dem Tablet (Couch, Reiter Posteingang | Alien-Archiv | Notizen), Taste J entfällt.
  Analysegerät zeigt keine Ergebnistexte mehr: „Ergebnisse ans Tablet senden“ (`Research.send_results`, `sent`, `tablet_new`).
  Verknüpfen geht erst, wenn die Analysen gesendet sind. Test: `--night-test=tablet`.
- Bewegte Teile (Werkzeuge in der Hand, Türen, Schranktüren) mit `BuildKit.localize_materials` (Textur am Objekt).
- Hände/Werkzeuge ziehen sich vor Wänden zurück (`PlayerHands._avoid_walls`).
- Holzkorb `WoodBasket` (Cabin/WoodBasket, 1 Holz Start, max 4, E nehmen/R hineinlegen). Tankanzeige `FuelGauge`
  (Cabin/FuelGauge über dem Funktisch, `PowerManager.hours_left`). Traglast-Anzeige im HUD (`Hud._update_weight`).
- Verstecke: E Tür auf/zu, R hinein/hinaus; Uhrlicht geht aus und bleibt drinnen aus.
- Uhr: F kurz = an/aus, F halten (`Player.LIGHT_MODE_HOLD`) = LED ↔ weißes Display (`PlayerHands.screen_mode`, schwaches Umgebungslicht).
- Hinsetzen mit Kamerabewegung: `Seat` (Verandabank, wandert mit), Couch, Monitorstuhl (`MonitorStation`), Leiter klettern
  (`TowerLadder`), Verstecke. Partikel `Fx.burst` (Holz, Stein, Funken, Erde, Glas, Staub).
- Tablet flackert nur nachts bei Alien-Aktivität. Fenster: Glaszacken bleiben im Rahmen, Hammerserie beim Verbarrikadieren.
- Forschungsbilder (KI-Bilder von Christian): `assets/research/<fund-id>.jpg` (512 px, Import verlustbehaftet),
  im Tablet-Archiv groß, sobald gesendet, vorher abgedunkelt (`ResearchMenu.research_picture`).
- Hochsitz: Rückwand bis unters Dach, Dach fest, Notizen ohne festen Körper. Test: `--night-test=extras`.

## Entscheidungen Versorgung & Aufgaben
- Verbrauchsstoffe haben später eine Quelle: Essen aus Hochbeeten (`GardenBed`, Garden/GardenBed1..4) und Schlingen (buildables `snare`),
  Wasser aus Flaschen (Hahn sauber, Regentonne/Bach roh → am Küchenofen `CookStove` abkochen), Generator mit Wartung
  (`GeneratorService`, Öl/Zündkerze) plus Holzvergaser und außerirdischer Energiezelle (Christian: „beides“).
- Metall: zufällige Fundstellen im Wald (`ScrapField`/`ScrapSpot`, Auspuff/Motor/Silo/Traktor/Fass), nur mit Blechschere,
  verschwinden nach dem Abbau, neue pro Tag, nahe Autowrack häufiger.
- Versorgungs-Manager `Supplies` (Autoload), Werte `data/supplies/supplies.tres` (`SupplyConfig`). Fundstücke: `SupplyProps`.
- Aufgaben-Manager `Tasks` (Autoload), Inhalte `data/tasks/tasks.json` (Ziele + Tagesroutine, Bedingungen siehe `_info`),
  Systeme melden mit `Tasks.flag("…")`. Anzeige: Tablet-Reiter „Aufgaben“ (Christian: „Ziele + Tagesroutine“).
- Überwachungskameras baut man selbst ein: Kamera 1–3 (`camera_N`) in der Hütte finden, im Baumodus nur außen an Hütte
  oder Schuppen anbringen (`BuildController._camera_update`), R schwenkt; gespeichert in `Supplies.cameras`, Monitor
  (`Surveillance`, 3 Plätze) zeigt leere Plätze als „nicht installiert“. Icons für camera_1..3 liefert Christian.
  Tests nutzen `Surveillance.install_defaults()`. Test: `--night-test=supplies`.

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
