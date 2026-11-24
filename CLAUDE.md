# CLAUDE.md – Arbeitsnotizen für Homebound

## Zusammenarbeit
- Christian ist kein Programmierer. Er beschreibt Wünsche im Chat, Claude baut alles selbst
  (Code, Level, Szenen) und liefert spielbare Windows-Builds.
- Kommunikation mit Christian auf Deutsch, ohne Fachjargon.
- Kommentare im Code auf Deutsch, Bezeichner auf Englisch.
- Offene Designfragen aus GDD Kap. 21 nicht eigenmächtig festschreiben – nachfragen.
- Tempo vor Kontrollbildern: Bei kleinen Änderungen (Kamera drehen, Farbe, Lautstärke …) keine Screenshots,
  nur die schnellen Tests; Christian prüft selbst im Spiel. Screenshots nur bei größeren Umbauten oder auf Wunsch.
- Christian 15.11.: Immer alles gleich hochladen (nach Tests committen und pushen, nicht auf „hochladen“ warten).
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
  (Mails/News mit `day`; Familie: Frau Stefanie, Kinder Lena und Ben, Protagonist Christian, LKW-Unfall bei Regen).
  Müdigkeit 23–1 Uhr (TimeConfig `tired_*`): Hinweis „ins Bett“, wenn bis dahin nichts los war (ThreatDirector).
- Kamin: `Fireplace` brennt `burn_hours`, wird die letzten `fade_hours` dunkler/leiser, mit Holz neu (data/house/house.json).
- Nacht: erste Hälfte stockfinster, Mond geht ab ~1 Uhr auf (schwaches Licht). Streulicht der Hände nur auf Sichtebene 20.
- Bach: Ufer immer über Wasser (Terrain `BANK_HEIGHT`, `WATER_LEVEL`, `WATER_HALF_WIDTH`), Prüfung `--walk-test --stream`.
- Truhe `StorageChest` (Cabin/StorageChest, Werkstatt unter der Werkzeugwand, persistent), Menü in GameMenus („chest“).
- Bildchen für Gegenstände: `ItemIcons` lädt `assets/icons/items/<id>.png|jpg|webp`, sonst Platzhalter (Kategorie-Farbe + Kürzel).
  23.11.: Christian hat alle 134 geliefert (256 px, PNG mit Transparenz). Neue Gegenstände brauchen ein eigenes Bild, sonst Platzhalter.
- Alt = langsam und leise gehen und Atem anhalten (`walk_slow`, `Player.SLOW_FACTOR`, siehe „Schleichen“). Sprint nur, solange Shift wirklich gedrückt ist.
- Kreatur auf der Jagd bleibt `hunt_hours`, nur mit `whole_night_chance` die ganze Nacht (CreatureConfig).
- Möbel stehen so, dass man an jedes Fenster treten kann (Prüfung im `--walk-test`: „FENSTER … frei“).
  Werkbank Ostwand nördlich vom Fenster, Generator an der Westwand des Technikraums, Esstisch weg vom Wohnzimmerfenster.
- TEST-Knopf „zu Tag 10 springen“ ist entfernt (14.11.), `PauseMenu._test_jump_to_day` nur noch für Tests.
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
- Archiv (früher „Alien-Archiv“) und Notizen nur noch auf dem Tablet (Couch, Reiter Posteingang | Archiv | Notizen); J = seit 23.11. Aufgaben auf der Uhr.
  Analysegerät zeigt keine Ergebnistexte mehr: „Ergebnisse ans Tablet senden“ (`Research.send_results`, `sent`, `tablet_new`).
  Verknüpfen geht erst, wenn die Analysen gesendet sind. Test: `--night-test=tablet`.
- Bewegte Teile (Werkzeuge in der Hand, Türen, Schranktüren) mit `BuildKit.localize_materials` (Textur am Objekt).
- Hände/Werkzeuge ziehen sich vor Wänden zurück (`PlayerHands._avoid_walls`).
- Holzkorb `WoodBasket` (Cabin/WoodBasket, 1 Holz Start, max 6, E nehmen/R hineinlegen). Tankanzeige `FuelGauge`
  (Cabin/FuelGauge über dem Funktisch, `PowerManager.hours_left`). Traglast-Anzeige im HUD (`Hud._update_weight`).
- Verstecke (11/2026 neu): nur E = Tür auf/zu. Man geht selbst hinein und schließt von innen; drinnen + Tür zu = versteckt
  (`HideSpot._player_inside`). Drinnen alles normal (lehnen, Licht, ducken), kein Einsteigen per R mehr.
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
  (`Surveillance`, 3 Plätze) zeigt leere Plätze als „nicht installiert“.
  Tests nutzen `Surveillance.install_defaults()`. Test: `--night-test=supplies`.

## Story (beschlossen 10.11.2026, Story-Bibel: https://claude.ai/artifact/6FfYY9UAGpkPV9eYFJbYyL)
- Christian (Spielfigur), Frau Stefanie, Kinder Lena (9) und Ben (6). Unfall = Mord der Organisation (WURZELWERK, Firma ReZort Industries).
- Stefanie hat die Hütte ausgesucht (Messpunkt 4 in seinen Unterlagen), Förster Georg Wendt war Beobachter der Organisation,
  Christian überlebte, weil er länger in der Arbeit blieb. Tablet gehört Christian (alte Mails von Stefanie im Archiv).
- Bauteil W-17 (Umzugskarton Werkstatt): steckt im Analysegerät → später Suchgerät → Schlüssel im Wurzelknoten unter dem alten Brunnen.
- 5 Phasen (Zusammenbruch, Gebiet unter dem Wald, menschliche Beteiligung/Außenstelle Messpunkt 4, Wahrheit Familie/Stefanies Mappe,
  Bedeutung der Hütte/Saat). 7 Enden: Gehört (gut), Stille (gemischt), Abgeholt, Glut, Schutzstatus, Flucht, Zu spät (schlecht).
  Ende = Schluss (Warnung vorher, Abspann, Hauptmenü). Nur Phase 5 hat eine Frist (~5 Nächte ab Schacht offen), Phasen 1–4 offen.
  Aliens ohne Namen, Spieler nutzt Arbeitstitel (Kreatur, Drohne, Manipulator, Organismus, Sucher).
- Eine Episode, Hütte als Mittelpunkt + Ausflüge. Geplant: Open World ca. 5 km² (Wald, Lichtungen, Berge, Seen, viele Orte,
  Mehrtagesmärsche mit Zelt/Proviant).

## W-17 (Bauteil aus Stefanies Umzugskarton)
- Umzugskarton `MovingBox` (Cabin/MovingBox, unteres Fach am Funktisch, persistent): 1. E öffnen (Notizen karton_ausweis,
  karton_mappe), 2. E W-17 nehmen (Notiz w17_info). Item `w17` (items.json, Kategorie Fund).
- Das improvisierte Analysegerät braucht W-17 (recipes.json). Ohne W-17 im Gerät liest Stufe 1 nicht (`Research.device_reads`,
  `w17_in_device`, gespeichert). Fassung `W17Slot` am Radio: Ausbau erst nach Verknüpfung `link_w17` („Dieselbe Handschrift“).
- Mitgetragen = Suchgerät `W17Locator` (Balken + Piepen, Reichweite `RANGE`), Orte in map.json `w17_sites`
  (auch der alte Brunnen – Story-Hinweis). Der Sucher spürt W-17. Aufgaben moving_box, w17_locator. Test: `--night-test=w17`.

## Forschung 2.0 (Christian: XCOM-artig, voller Umfang)
- Christians Entscheidungen: Alien-Technik macht sichtbarer, bringt nützliche Werkzeuge gegen die Wesen / fürs Leben,
  keine Waffen. Labor im Bad (Waschtisch). Lebende Proben verderben nicht, dürfen aber ausbrechen. Voller Umfang mit
  Querverweisen, Technologiebaum und verschiedenen Tests.
- Inhalte: `data/research/research.json` – 54 Projekte (`analyses`: find, station, hours bis 72, requires, living/escape/
  escape_per_day, signature, experiments mit needs power|light|alien|heat|night|day|water|item:X|built:X, effect
  drain|noise|signal|escape|hurt), 37 Verknüpfungen (`links`: unlocks = Rezepte, grants = forecast|charger|alarm_mauler),
  `lab` (unlock Tag 4 + 3 gesendete Ergebnisse, Material, Stationen, Ladeschale), `drops` (Funde nach Nächten), `gadgets` (Werte).
- `Research` (Autoload): `stations` (device + bench/microscope/terrarium/shield/screen, alle parallel; `slot` = stations["device"]),
  `insert_project`, `available_projects`, `run_experiment(exp, station)`, `escape`, `build_lab/build_station/build_charger`,
  `signature()` = `carried_signature()` (items.json `signature`, Dämpfertasche ×0.4) + `home_signature()` (nachts laufende
  Projekte außer im Abschirmkasten, Ladeschale, Ausschlag `flare_until`). `expected_signature()` für die Nachtplanung.
- Labor: `Lab` (Cabin/Lab, Modelle + `Lab.LabControl` je Platz, `LabSetup` am Waschtisch = umbauen / Übersicht, R = Wucherung
  abkratzen). Unsichtbare Teile ohne Kollision. Handtuchhalter hängt jetzt an der Flurwand. Menü: `ResearchMenu.open_station(st)`, `open_lab()`.
- Ausbrüche: `LabEscape` (crawl = Probe kriecht im Haus herum und kratzt nachts, spread = Wucherung hinter der Hütte,
  call = Drohne kommt sicher (`ThreatDirector.force_event`), bloom = Bad wuchert, `Research.lab_bloom`).
- Funde: `AlienDrops` (Knoten „AlienDrops“, persistent) legt morgens Funde ab (`ThreatDirector._kinds_tonight`), Kameraaufnahmen
  warten am Monitor (`footage`). Diktiergerät + alter Laptop am Hochsitz (Georg Wendt), Datenträger Außenstelle, Protokolle Messstelle.
  Diktiergerät ist ein Hand-Gegenstand: Linksklick halten = Aufnahme (`PlayerHands.capture_recordings`), nimmt
  Manipulator-Stimme (`Manipulator.last_call_msec`) und ab Tag 5 den Funkspruch (`Radio.message_until_msec`) auf.
- Signatur: ThreatConfig `signature_drone_bonus`, `signature_seeker_bonus`, `signature_wakes_quiet`; Sucher spürt Signatur am Körper
  (`SeekerConfig.signature_min`, Reichweite w17_range × Signatur/0,5).
- Werkzeuge (Rezepte mit requires): Dämpfer-Stirnband (Hirn-Schaden), Nervenfühler (`GadgetHud`), Stimmfilter, Wärmekristall,
  Leichtmetall-Trage (`Inventory.MAX_WEIGHT` ist jetzt eine Eigenschaft), Dämpfertasche, Geruchstarnung (`use.buff`), Sporenmaske,
  Wabenfilter, Wurzelsalz (E an Wucherung), Drohnenköder + Lichtköder (Structure-Typen `drone_decoy`, `light_lure`).
- Tablet: Reiter „Forschungsbaum“ (`ResearchTree`, Bänder je Gebiet, Spalten = Stufen), Vorhersage in „Aufgaben“ (grant forecast).
- Tests: `--night-test=lab` (Daten, Labor, Parallelbetrieb, Ausbrüche, Signatur, Werkzeuge, Funde, Baum, Spielstand),
  `--walk-test --lab` (ausgebautes Labor verstellt nichts).

## Forschung: Sackgassen geschlossen (Christian, 12.11.2026)
- Jetzt 54 Projekte, 37 Verknüpfungen. Die fünf Projekte ohne Verknüpfung hängen jetzt an Teilen von Sucher und Zerfleischer:
  `link_brood` (Blutprobe + Reißzahn → grant `alarm_mauler`: Nervenfühler schlägt auch beim Zerfleischer an),
  `link_blind` (Gewebekultur + Schwarze Augenhaut → Blendaufsatz `glare_lens`: LED der Uhr reicht weiter/breiter, Werte in gadgets),
  `link_tether` (Geweih + Fadenspur → Fadenpendel `seeker_alarm`, Anzeige `GadgetHud.seeker_text`),
  `link_gardener` (Fremdpflanze im Topf + Lichtersplitter, nur Erkenntnis), `link_jump` (Sondenkern öffnen + Blitzasche, nur Erkenntnis).
- Neue Funde: `mauler_film` (Zerfleischer mit der Uhr-LED vertrieben, 1× pro Tag, `Mauler._drop_find`), `mauler_tooth`
  (Flucht vor hellem Licht, `MaulerConfig.tooth_chance`, 1× pro Tag; dazu morgens im Wald, drops after „mauler“),
  `seeker_ash` (wo der Sucher im Blitz verschwindet: nach einem Schlag immer, beim Abziehen `SeekerConfig.ash_leave_chance`;
  er verschwindet jetzt auch beim Abziehen mit einem Blitz).
- Nachgeholt am 12.11. (Godot 4.7.2 von GitHub geladen: Godot_v4.7.2-stable_linux.x86_64.zip): alle Nacht-, Lauf-, Daten-,
  Rückfall- und Bildraten-Tests ohne Fehler. OFFEN im 15-Tage-Durchlauf: „Nach der Nacht von Tag 11 ist Tag 13“ (Zeltnacht,
  zwei Zeltnacht-Planungen hintereinander) – noch nicht untersucht, ob das am langsamen Workspace liegt oder echt ist.
  Die Meldung „Lambda capture … was freed“ nach dem Neuladen kam aus `SoundBank.play_at` (Aufräum-Timer für Klangschleifen) – behoben.

## Große Welt (Open World, ca. 2,2 x 2,2 km)
- Daten: `data/world/map.json` (Berge, Seen, Mulden, Moor, Lichtungen, Orte mit `ring` near|day|multi, Wege, Wegweiser,
  Tunnel-Einschnitte). Zugriff statisch über `WorldMap` (Raster für schnelle Abfragen). Das Tal um die Hütte (r < ~95 m)
  bleibt exakt wie vorher; draußen mischt `WorldMap.macro_height` die große Landschaft dazu.
- `Terrain`: Tal (±128 m) fest beim Start, Rest in 64-m-Stücken mit HeightMapShape nachgeladen (Zeitbudget pro Bild),
  grobes Fernsicht-Gelände per Shader (sinkt um den Spieler weg, in der Ferne Baumkronen). `load_around()` für Teleports.
  Bach von Quellsee (Norden) bis Kartenrand Süden (`STREAM_BENDS`), Seen/Tümpel als Wasserscheiben, `water_level_at()`.
- `WildForest`: Wald außerhalb des Tals in Stücken (nah volle Bäume + Kollision + Bodenpflanzen, fern einfache Bäume).
  Das Tal pflanzt weiter `Forest`. `WorldTrails`: Wegweiser (Luftlinie + Entfernung) und Stege über den Bach.
- Orte: `Places` baut alle Orte aus map.json mit `PlacesNear` / `PlacesDay` / `PlacesFar`, Bausteine in `PlaceKit`
  (loot, note, blueprint, inspect, hut, fence). Funde = ItemPickup (persistent: Places/<ort>/…), Notizen in research.json,
  Baupläne `Blueprint` → `Research.blueprints`, Rezepte mit `"blueprint"`. Aktionen `PlaceInspect` (needs/gives/done_flag),
  z. B. Funkmast reparieren (`mast_repaired`), Sprengstofflager (`quarry_bunker`), Schacht B (`shaft_b_open`).
- Besuche: `Tasks.flag("visit_<ort>")` automatisch. Fernglas (Q halten), Wanderkarte (M, `MapScreen`, aus der Wetterstation),
  Zelt (`tent`, Structure: schlafen draußen), Waten (tiefer als 1,2 m geht nicht), Moor abseits der Stege = einsinken.
  Torf zählt als Brennstoff (`Inventory.count_fuel`). Verbandskasten `use.heal`.
- Weit weg von der Hütte (> 150 m) werden Haus-Ereignisse des ThreatDirectors zu Wald-Ereignissen um den Spieler
  (`far_from_home`, `_far_variant`).

## Entscheidungen Zeltnacht, Kälte, Sucher
- Zeltnacht = Psychoterror (Christian): keine Tötung, aber Verletzung + Zelt zerrissen; flicken mit 1 Brett + 3 Nägeln.
  `TentCamp` (Kind des Zelts): E hineinkriechen, drinnen E schlafen / R hinaus / F Licht (leuchtet nach außen).
  `ThreatDirector.plan_camp_night` plant `camp_events` Ereignisse („camp“): Schritte ums Zelt, Schatten auf der Plane,
  Plane eingedrückt, Stimme, Licht von oben, Feuer geht aus, Sucher. Morgens Spuren ums Zelt. Werte: ThreatConfig `camp_*`.
  Seit 14.11. viel mehr Vorfälle (siehe „Zeltnacht 2.0“).
- Kälte (Christian: ja): `Survival.warmth` (HUD „Wärme“), Werte `data/survival/survival.tres` (`SurvivalConfig`).
  Draußen nachts schnell kalt (Höhe, nass nach Waten schneller), Hütte mit Kamin/Ofen wärmt, Zelt halbiert den Verlust,
  Schlafsack (`sleeping_bag`: 3 Wolle + 1 Schaffell) noch mehr; Lagerfeuer (`campfire`-Bündel, 3 Holz, `Campfire`) wärmt,
  lockt aber Sucher/Drohne. Kalt = Zittern, weniger Ausdauer; sehr kalt = Schaden; durchgefroren aufwachen = Schaden.
  Wärmequellen in Gruppe `heat_source` (`heat_at`, `heats_cabin`).
- Sucher (Christian: bauen): `Seeker`, Werte `data/creatures/seeker.tres` (`SeekerConfig`), wann: ThreatConfig `seeker_*`.
  Dürr, ~2,7 m, Augenschlitz mit vielen kleinen Lichtern. Erscheint, beobachtet lange, sucht ab; reagiert auf Licht
  (Uhr, Licht im Zelt, Feuer), Geräusche (`noise_made`) und W-17 (`Inventory "w17"`).
  Findet er dich: Schlag bzw. Zelt aufreißen (nie unter `min_health`), dann Teleporterblitz. Test: `--night-test=camp`.
  In Hütte und Schuppen kommt er nicht (`Seeker.outside`, Umweg um die Wände); wer drinnen ist, wird nicht geschlagen.
- Tests: `--night-test=map` (Rechenzeit, Nachladen), `--night-test=places` (alle Orte, Funde, Mechaniken).

## Prüfrunde „runder und fehlerfreier“ (11/2026)
- Alle Tests auf einmal: `tools/run_tests.sh [ordner]` (Nacht-Tests, Lauftests, Daten, Rückfall-Prüfungen, Bildrate, Durchlauf).
- `--night-test=data` (`DataTest`): prüft alle Dateien unter `data/` gegeneinander und gegen die gebaute Welt.
- `--night-test=regress` (`RegressTest`): je behobenem Fehler eine Prüfung. Neue Fehler → dort eine Prüfung ergänzen (`_t_more`).
- `--night-test=playthrough` (`PlaythroughTest`, optional `--days=N`): spielt 15 Tage automatisch, sichert und lädt nach jedem Tag,
  vergleicht alles vorher/nachher.
- `--night-test=fps` (`FpsTest`, optional `--fps-detail=Ort`): Rechenzeit pro Bild an Hütte, Wald, großen Orten; Ruckler beim Laufen.
- Nachladen ohne Ruckler: `Terrain` baut ein Stück in Schritten (Höhen, Punkte/Farben, Netz, Kollision), `WildForest` baut nahe
  Stücke als `NearJob` über mehrere Bilder (das einfache Stück bleibt bis zum Tausch stehen). Größere Schritte teilen sich die Bilder
  über `Terrain.claim_heavy_step()`. Sofort-Bauen (Teleport, Tests, Fotos) geht weiter mit `load_around` / `update_around(pos, 0.0)`.
- `Player.input_locked` ist eine Eigenschaft: wer tot ist, bleibt gesperrt. E/R am Ziel läuft über `Player.use_target()`.
- „Ablegen“ im Rucksack wirft Einzelstücke (W-17, Werkzeuge, Kameras, Funde mit Stapel 1) nicht mehr weg (`GameMenus.can_discard`).
- Orte: Knoten, unter denen Funde liegen, brauchen feste Namen (sonst liegen die Funde nach dem Laden wieder da).

## Zerfleischer (Christian, 11/2026)
- Zweibeiner, Oberkörper weit vorn, lange Klauen, Grey-Augen + Reißzähne; jagt statt Psychohorror. Eigener Entwurf (keine
  Film-Kopie). `Mauler` (Werte `data/creatures/mauler.tres`, `MaulerConfig`), Zustände STALK → WARN (aufrichten, kreischen)
  → CHARGE (≈ Spieler-Sprint) → STRIKE → RETREAT → CIRCLE (Halbkreis) → erneut CHARGE; PROWL (Spieler im Haus/Versteck/Zelt
  oder im hellen Licht: schleicht herum, kommt nicht hinein), FLEE, LEAVE.
- Christians Entscheidungen: tötet bei mehreren Treffern (`hit_damage` 36 → 3 Treffer), nach jedem Treffer zurückweichen +
  Halbkreis; erst ab Story-Phase 2; darf auch an der Hütte auftauchen (wenn man draußen ist); Licht vertreibt zuverlässig:
  LED-Kegel der Uhr (nicht das weiße Display) `led_range/led_cone/led_time`, helle Quellen (Lagerfeuer, Scheinwerfer,
  Blitzlicht, Lichtköder, Außenlampen) im `bright_radius`.
- Wann: ThreatConfig `mauler_*` (Ereignis „mauler“ öffnet ein Zeitfenster, `ThreatDirector._check_mauler` lässt ihn erscheinen,
  sobald man draußen ist; tagsüber selten weit weg im dichten Wald). Beim Zelt nur herumschleichen.
- Story-Gerüst `Story` (Autoload, `phase`, im Spielstand). Auslöser der Phasen hängen seit 13.11. an der Spur (siehe „Roter Faden“).
- Test: `--night-test=mauler`. Tour-Bilder 73/74. Schnelle Figuren-Vorschau (Sekunden statt Minuten):
  `xvfb-run -a godot --path . --rendering-driver vulkan --resolution 960x540 res://scenes/dev/creature_preview.tscn -- --out=BILD.png --pose=warn|charge|stalk --angle=90`.

## Phase 9: Speichern und Hauptmenü (Christian, 11/2026)
- Entscheidungen: ~~Speichern jeden Morgen + beim Beenden~~ → seit 23.11. NUR beim Schlafen im Bett (`GameState.bed_save`,
  siehe „Bedrohung à la Resident Evil“); Tod = zurück zum letzten Bettschlaf; 3 Speicherplätze; Hauptmenü mit Einstellungen, Steuerung,
  gesehenen Enden und Titelbild der Hütte bei Nacht (langsam bewegt, Nebel, Fensterlicht).
- `GameState`: `slot`, `play_seconds`, `save_game(current)`, `load_game(n)`, `new_game(n)`, `delete_slot`, `latest_slot`,
  `slot_info`, `to_menu`, `quit_game`. Datei `user://saves/slot_N.save` (store_var) mit `current` (Stand jetzt) und
  `morning` (Tagesbeginn für den Tod). Neues Spiel = Zustand beim Programmstart (`_fresh`). Tests haben `slot = -1` (kein Speichern).
- Startszene ist `scenes/main_menu.tscn` (`MainMenu`). Mit irgendeinem Test-Schalter (`-- --night-test=…`, `--walk-test`,
  `--screenshot-tour=…`, `--skip-menu`) geht es sofort ins Spiel. Titelbild `assets/ui/title.jpg` (Tour-Bild 00_titelbild, 1920×1080).
- `Settings` (Autoload): Lautstärke (Master-Bus), Maus (Faktor), Helligkeit (Belichtung), Grafik low|medium|high
  (Auflösungsfaktor, Schatten, SSAO, Volumennebel), Vollbild; Enden `reach_ending(id)` (für die Story später).
  Startwerte + Liste der 7 Enden: `data/settings/default_settings.json`, gespeichert in `user://settings.cfg`.
  `SettingsPanel` in Hauptmenü und Pause.
- Tests: `--night-test=save` (Platz schreiben/lesen, Tagesbeginn, Einstellungen, Enden, Menü, Pause),
  `godot --headless --path . -s res://scripts/dev/flow_check.gd` (Menü → Neues Spiel → Hauptmenü → Laden).

## Änderungsliste 11/2026 (28 Punkte von Christian)
- Gießkanne = Hand-Gegenstand (steht anfangs bei den Beeten), füllen/gießen nur in der Hand. Generator läuft beim Start nicht.
- Kamera 1 unter der Werkbank, Ersatz-Zündkerze im Schuppenregal. Holzstapel am Schuppen: 4 Scheite, dann „nass“ (`ResourceNode.empty_text`).
- 17 Uhr Hinweis „Der Abend beginnt“ (TimeConfig `evening_warning_*`, ThreatDirector `_check_evening`). Aufgaben-Tag beginnt 8 Uhr
  (tasks.json `day_start_hour`, `Tasks.task_day()`).
- Experimente erst bei 100 % Analyse, dauern `lab.experiment_seconds`; fertiger Fund bleibt im Gerät (herausnehmen per Knopf);
  Sendezähler zählt Projekte (`Research.unsent_count`). Archiv ohne doppelte Einträge, Bilder anklickbar (groß).
- Lagerfeuer: nur 1 tragbar, aus = abbauen. Leere Flaschen: Trinken gibt die Flasche zurück, dazu Müllflaschen im Wald
  (SupplyConfig `litter_bottles_per_day`). Speis-Kisten (`ItemPickup.restock`): R stellt Wasser/Konserven zurück.
- Wucherung: Schaden mit rotem Aufblitzen + Stöhnen. Holzkorb am Kamin = Metallständer. Glas: kaum Glanz.
  Wegweiser stehen am Wegrand (`WorldTrails.roadside`), schwarze Schrift auf hellem Brett. Hochsitz-Streben von Pfosten zu Pfosten.

## Baupläne nach und nach (Christian, 12.11.2026)
- Daten `data/research/blueprints.json` (Auslöser `on`: item | flag | fuel_below, `hint` = graue Zeile „Unbekannter Bauplan“
  an der Werkbank, `text` = Meldung). Rezepte verweisen mit `"blueprint"`. `Research.check_unlocks()` (Rucksack, `EventBus.flag_set`
  aus `Tasks.flag`, Tank), `unlock_blueprint`, `blueprint_hint`.
- Frei von Anfang an: Bretter, Nägel, Holzzaun. Erster Stein → Lagerfeuer + Steinwall; Dosen → Dosenalarm; Wachs → Kerzen;
  Wolle/Fell → Schlafsack. Morgen nach der ersten unruhigen Nacht (`unrest_night`, ThreatDirector) → Haustür verstärken +
  Fenster verbarrikadieren (`bp_secure`). Erster Besuch der Kreatur am Haus (`creature_visited`) → Spießbarrikade.
  Gefunden: Fallen-Anleitung am Hochsitz (Bärenfalle + Schlinge), Bewegungsmelder-Leuchte in der Imkerei.
  Funkmeldung Tag 7 (`radio_day_7`) oder erstes verseuchtes Wasser → Wasserfilter. Tank < 20 % → Holzvergaser. Zelt liegt im Ferienlager.
- Leere Blechdosen: alte Kühlbox im Wald westlich (`SupplyProps.COOLER_XZ`, CoolerCans, 8 Dosen), seit 14.11. auch 4 neben der Küchenspüle
  (`KitchenCans`) und 2 an jeder zweiten Schrottstelle (`ScrapSpot` Kind „Cans“, gerade `spot_id`). Sichtbare Dosen: `SupplyProps.empty_cans`.

## Neue Hände und Hand-Gegenstände (Christian, 12.11.2026)
- Drei neue Bausteine unter `scripts/player/`: `HandKit` (Formen: `loft` = Schlauch entlang einer Linie für Stiele, Henkel,
  Finger; `extrude` = ausgeschnittenes Blech mit Keilform; `arc`, `tube`, `disc`), `HandRig` (Hand mit beweglichen Fingern:
  `grip(radius)` legt Finger und Daumen um eine Stange, `grip_center(radius)` = wo sie in der Faust liegt, Haltungen
  `FIST`/`RELAXED`/`OPEN`, `mix` zum Überblenden) und `HandItems` (alle Modelle: `build(parent, modell)`, Ursprung = Griffstelle,
  +y oben, -z vorn; Meta `grip`, `tight`, `up`, `tilt`, `parts` für bewegliche Teile, `base` zum Hinstellen: `HandItems.place`).
- Welches Modell: items.json `hand` = Art (bestimmt die Bewegungen: fist, axe, tin_snips, food, water, dictaphone, watering_can),
  `hand_model` = eigenes Modell dazu (bottle_raw, bottle_tainted, radish, carrot, potato, meat_raw, meat_cooked, mug_soup,
  mug_stew, mug_potato, honey, ration, alien_fruit). Neuer Gegenstand für die Hand = Modell in `HandItems` + Eintrag in items.json.
- `PlayerHands`: Ruhelagen je Art in `REST` (Ort, Drehung, Handgelenk; z = -90 heißt Daumen oben). Bewegungen in `_pose_right`:
  punch, swing/chop, stab, snip (Backen und Finger drücken zu), drink (Deckel klappt auf, Wasserstand sinkt), eat (Dosendeckel
  geht auf), pour, fill; Diktiergerät: Linksklick halten hebt es an, Spulen drehen, Leuchte blinkt. Bauhammer: `hammer_taps(n)`
  (ruft der BuildController). Hände liegen nur auf ihrer eigenen Sichtebene (`HANDS_LAYER`) – Uhr-LED und Display-Licht
  beleuchten sie nicht (sonst grell weiß).
- Gießkanne: Linksklick gießt (`start_pour`, über einem Beet wird es gegossen und kostet Wasser; daneben läuft nur der Strahl,
  kostet nichts; halten = weitergießen), Rechtsklick füllt an Wasserhahn/Regentonne/Bach (`_secondary` → `start_fill`). E am Beet
  und R am Wasser gehen weiterhin. Wasserstand ist in der Kanne zu sehen (`HandItems.can_level`).
- Uhr: Kompass im Display (`_build_compass`, `_update_compass`): rote Nadelspitze zeigt nach Norden (Welt -z), pendelt nach,
  dreht durch, solange die Kreatur die Uhr stört (`_compass_jam`). Sichtbar wie die Uhr selbst nur bei eingeschaltetem Licht (F)
  oder im Baumodus.
- Dieselben Modelle liegen in der Welt: Gießkanne bei den Beeten, Diktiergerät und Flasche am Hochsitz, Konserven (`Icons.food_can`
  → `HandItems.can_body`), Blechschere an der Werkzeugwand (`PlayerHands.snips_model`).
- Schnelle Vorschau (Sekunden): `scenes/dev/hands_preview.tscn` (`scripts/dev/hands_preview.gd`), z. B.
  `VK_ICD_FILENAMES=/opt/lavapipe/lvp_icd.json xvfb-run -a godot --path . --rendering-driver vulkan --resolution 1280x720
  res://scenes/dev/hands_preview.tscn -- --out=BILD.png --mode=fp --item=watering_can --action=pour --p=0.5 --retro`
  (`--mode=item --item=axe` zeigt ein Modell von vier Seiten, `--mode=rig --pose=grip:0.017` die Hand allein).
- Prüfungen: `RegressTest._t_hands` (Modelle, Kompass, Gießkanne links/rechts).

## Feinschliff 12.11. abends (Christian)
- Nachschwingen der Hände wieder sichtbar: `_avoid_walls` verrechnet jetzt Feder (`_sway`) + Wippen (`_bob_pos`) statt sie zu überschreiben.
- Gießen: Linksklick halten, erst nach `SupplyConfig.water_pour_seconds` Wasser aufs Beet ist es gegossen (`PlayerHands._update_bed_pour`,
  `GardenBed.needs_water/finish_watering`); E am Beet gießt nicht mehr.
- Im Schrank/Spind: Uhrlicht an/aus und LED/Display wechseln geht, Hände werden dort kaum zurückgezogen (Gegenstände wechseln sichtbar).
- Monitor ohne Strom: schwarz und stumm (Shader `cctv` Parameter `dark`), nicht eingebaute Kamera = Rauschen.
- Holzkorb am Kamin: 6 Scheite (data/house/house.json `wood_basket`). Aufgabe d_water heißt „Trinkwasser aufnehmen (2 Flaschen)“.

## Anbauten, Dachboden, Keller (Christian, 12./13.11.2026)
- `CabinRooms` (scripts/world/cabin_rooms.gd) baut in die Hütte: **Büro** (Stefanie) hinter der Speis (`Cabin.OFFICE`, Fenster Nord +
  West, Tür in der Speis-Nordwand; Speis-Regal steht jetzt an der Westwand), **Kinderzimmer** im Nordwesten (`Cabin.KIDS`, Tür vom
  Wohnzimmer zwischen Schlafzimmerwand und Kamin, Fenster West + Nord, Betten Lena/Ben, Kisten, halb gestrichene Wand),
  Pultdächer (`ROOF_HI/LO`). `Cabin.is_inside` umfasst Anbauten, Dachboden und Keller; `Cabin.in_footprint` für Gegner-Wege
  (Creature `RING`, `_outside_house`) und Pflanzen.
- **Dachboden**: Decke ist fest (Dachboden-Boden), Dach fest; zwei Giebelfenster (`WindowAtticWest/East`, Gruppe attic_window, kein
  entry_point). `AtticHatch` in der Werkstattdecke (E Leiter herunterziehen/klettern, R hochschieben/-ziehen), Klettern über
  `LadderClimb.climb`. Bett warnt bei unten gelassener Leiter (`AtticHatch.down_now`). ThreatDirector-Ereignis „attic“ (Besuchs-/
  Jagdnächte, ThreatConfig `attic_*`): Schritte/Kratzen oben; Leiter unten → kommt herunter (Apparition „ladder“, Schaden ab
  `attic_hurt_from_night`, Merker creature_visited).
- **Keller** (`Cabin.CELLAR`, Boden `CELLAR_FLOOR`) unter Büro und Speis; Gelände dort per `Cabin.cellar_dip` abgesenkt (nur unter
  dem Haus). `CellarHatch` im Büro: Teppich erst nach Story-Hinweis wegziehbar (story.json `beats`: cellar_hint ab Tag 4, 8 Uhr,
  Notiz keller_hinweis), dann Luke auf/zu, Leiter. Weckgläser (restock), Säcke, **zugemauerte Stelle** an der Ostwand Richtung
  alter Brunnen (Wurzeln, Stempel „WW · MP4“, Notiz keller_mauer) – Durchbruch erst beim Story-Bau Phase 5 (Weg bleibt Brunnen + Winde).
- Notizen: buero_kalender, kinder_bild, dachboden_liste, keller_hinweis, keller_mauer. Tour-Bilder 80–87. Prüfung `RegressTest._t_rooms`,
  Lauftest „Vorratsraum -> Büro“, „Wohnzimmer -> Kinderzimmer“.

## Nächtliche Vorkommnisse (Christian, 13.11.2026)
- `NightOmens` (scripts/creature/night_omens.gd): ThreatDirector plant pro Nacht `omen_count_quiet/busy` Ereignisse „omen:<art>“
  (`_pick_omen`, Tagesgrenzen + Gewicht in ThreatConfig `omen_*`). Haus-Arten nur zuhause (`HOUSE_KINDS`), Wald-Arten überall.
- Christians Wünsche: **Hände durch Spalten** (`GapHand`, Orte `GAPS`; ansehen → zieht sich zurück, zu nah → `omen_hand_damage`),
  **Dinge im Haus wandern** (`InsideChanges`: Bens Teddy, Buch, Becher; morgens nach unruhigen Nächten `inside_change_*`, nachts
  „deco_move“ nur ungesehen; E = zurückstellen), **Wald**: Lichter (`Wisp`), fliehende Rehe, kurze Sichtungen von Sucher/Zerfleischer
  (`Glimpse`: nur Aussehen, schwaches Gegenlicht, weg nach Sekunden oder nach längerem Hinsehen); **Manipulator leuchtet schwach**
  (`ManipulatorConfig.glow_distance/glow_energy`, Ortswechsel nur ungesehen).
- Zehn weitere: Lampe pendelt, Klopfen wandert durch die Wände, Spieluhr im Kinderzimmer, Atem + Fingerstriche auf einer Scheibe
  (`FogPatch`), Schatten huscht am Fenster vorbei, Küchenhahn läuft (`TapGhost`, E zudrehen), Augen unter Bens Bett
  (`UnderBedEyes`), Vogel prallt ans Fenster, Kleiderschranktür geht auf, neue Kinderzeichnung mit fünfter Gestalt (einmalig,
  Notiz kinder_bild2). Wecken: gap_hand, knock_walk, music_box, tap_run. Prüfung `RegressTest._t_omens`, Tour-Bilder 88/89.

## Belagerungsnächte à la FNAF (Christian, 13.11.2026)
- Christians Entscheidungen: alle vier Raum-Aufgaben, Tod möglich, ab Nacht 5 etwa jede 4. Nacht, Babyfon + Monitor im Büro.
- ThreatDirector: `night_kind` "siege" (ThreatConfig `siege_from_night/every`, `last_siege_day`, `siege_count`, `siege_done_day`,
  im Spielstand), Ereignis "siege" um `siege_start_hour` startet `SiegeNight` (scripts/systems/siege_night.gd, Kind der Szene,
  `SiegeNight.current`), Ende `siege_end_hour` → `EventBus.siege_finished`. Kein Schlaf (`siege_tonight`, Bett + `sleep_blocker`),
  17-Uhr-Hinweis wird zur Warnung. Erste Belagerung `siege_tasks_first` Aufgaben, jede weitere eine mehr; Keller nur, wenn gefunden.
- Aufgaben (Druck 0..1, Werte `siege_*`): **music** – `MusicBox` (Bens Spieluhr auf der Spielzeugkiste) läuft ab, E aufziehen;
  sonst Kinderstimmen (Untertitel + `CreatureSounds` "child", falls Aufnahmen da) und Verzerrung (`Player.mind_extra`, ohne
  Schaden), dann geht man zur Haustür. **attic** – Schübe gegen die Luke (`AtticHatch.bump`), E zuhalten, R zunageln (2 Bretter,
  nur für die Nacht), Leiter unten = 3× schneller. **cellar** – `CellarBrace` an der zugemauerten Stelle, Wurzeln wachsen, E mit
  1 Brett abstützen. **window** – Kreatur steht vor einem Fenster (CreatureModel + schwaches Gegenlicht), kratzt; Uhr-LED
  hineinleuchten (`siege_light_range`) vertreibt sie; Bretter verlangsamen (sie reißt daran).
- Fehlschläge: 1. = Schaden `siege_hit_damage`; ab 2. „Es ist im Haus“: `siege_hide_seconds` Zeit für Versteck (HideSpot, Keller
  mit geschlossener Luke, Dachboden mit hochgezogener Leiter – `SiegeNight.is_safe`), sonst Tod; versteckt → zieht ab, Strikes = 1.
  Draußen länger als `siege_outside_seconds` = Fehlschlag.
- Übersicht: `Babyfon` (Empfänger auf Stefanies Schreibtisch, Balken Kind/Dach/Keller, läuft mit Batterien auch ohne Strom; Sender in den drei Räumen)
  und zweiter Monitor `OfficeMonitorStation` (MonitorStation hat jetzt `screen_rot_y`, `chair_feet`, `face_dir`).
- Prüfung `RegressTest._t_siege` (inkl. Echtzeit-Lauf mit schnellen Werten).

## Waldwege (Christian, 13.11.2026)
- Wege sind jetzt überall sichtbar, auch im Tal: Boden-Shader `shaders/ground.gdshader` mischt Waldboden und Wegtextur
  (`TextureFactory` "path_ground"), Anteil im Alpha der Eckpunktfarbe (`Terrain.ground_color`). Wege liegen etwas tiefer
  (`Terrain.trail_dip`, `TRAIL_DIP_PATH/TRACK`), nicht im Garten, an Bach und Zufahrt flach. Talbäume/Felsen/Pflanzen meiden Wege
  (`Forest.on_trail`; der Zufall der übrigen Bäume bleibt gleich).
- Neue Wege in map.json: Bachpfad (`hoehle` + `bachpfad`, Hochsitz → Steg → Höhle → Ostufer → Ostweg), Kleiner Rundweg (`rundweg`,
  Lagerweg → an der Absturzstelle vorbei → Kapellenweg), Waldpfad (Imkerei ↔ Kapelle), Hangpfad (Friedhof ↔ Windwurf).
  Lagerweg beginnt jetzt an der Zufahrt. Wege haben optional `name`, `mark` (Farbe der Markierung), `board` (Zeile der Wandertafel).
- `WorldTrails`: Stege reichen von Ufer zu Ufer (`_bank_reach`, geneigt, Pfähle ins Bachbett), Markierungspfosten (MultiMesh je 128 m),
  Wanderbänke mit `Seat`, Holzpolter an Fahrwegen, Rundholzstufen an steilen Pfaden, offene Schranken, wo Fahrwege von der Zufahrt
  abgehen, Wandertafel `TrailBoard` an der Zufahrt. Abstände in map.json `trail_kit`. Listen `benches/markers/bridges`.
- Draufsicht zum Planen (Sekunden): `godot --headless --path . res://scenes/dev/map_dump.tscn -- --out=/tmp/map.png --cx=0 --cz=0 --size=300 --px=600`.
  Prüfung `RegressTest._t_trails`, Tour-Bilder 90–95.

## Roter Faden der Story (Christian, 13.11.2026)
- Christians Entscheidungen: Spur mit Eintrag auf der Karte, alle drei Fäden (Kabeltrasse, Wendts Zeichen, Stefanies Spuren),
  die meisten Orte in der Geschichte. Kette + Fäden auch in der Story-Bibel (Abschnitt „Der rote Faden (Spur)“).
- Daten: `data/story/story.json` `steps` (start/done bzw. done_count, main, target/targets, title/text, thought/finish,
  hint_days/hint), Phasen über `begins_all`/`begins_any`. Bedingungen = Tasks.check + neu `note:`, `step:`, `phase>=N`,
  `ws:structure_off`, `ws:source_dead`. Story-Orte stehen nicht mehr als Ziele in tasks.json.
- `Story`: `steps_active` (id → Starttag), `steps_done`, `hinted`, `update(announce)`, `active_steps`, `map_targets`, `step_progress`;
  Gedanken über `EventBus.notify`; zweiter Hinweis nach `hint_days` (von „Ilse über Funk“, sobald `mast_repaired`).
- Tablet „Aufgaben“ beginnt mit „SPUR“ (Hauptspuren, Nebenspuren, Hinweis, bisheriger Weg). Karte: `work_map` (Alte Einsatzkarte,
  aus dem Umzugskarton) zeigt nur bekannte/eingekreiste Orte, `hiking_map` alle; rote Kreise `MapScreen.Ring`.
- Welt: `StoryProps` (Kabeltrassen map.json `cables`, Meldekästen `wendt_boxes`), Stefanies Spuren als Notizen `stef_*` in den Orten,
  Weihnachtstruhe `XmasTrunk` auf dem Dachboden (Mappe erst ab Phase 4), Wendts Funkgerät in der Höhle (`hoehle_funkgeraet`),
  Kontrollrunde am Hochsitz (`wendt_runde`), Sattelzug an der Raststätte (`lkw_raststation`). Stefanies alte Mails im Posteingang
  (`old`, gelten als gelesen, nur „Kommst du nach?“ ungelesen, `Couch.is_unread`).
- Abstieg in den Brunnen und die Enden: siehe „Endspurt und Enden“.
  Prüfung `RegressTest._t_story`, Tour-Bilder 96–99.

## Lebendiger Wald + Tarnung im Gebüsch (Christian, 13.11.2026)
- `TreeKit` (scripts/world/tree_kit.gd) baut für Tal (`Forest`) und großen Wald (`WildForest`) dieselben Arten: Fichte, Kiefer
  (Schirmkrone, rötlicher Stamm), Buche (glatte graue Rinde, breite Krone), Birke (weiße Rinde, schmale helle Krone), alter Laubbaum,
  Dürrständer (kahle Äste) und Jungwuchs (junge Fichte/junger Laubbaum in Lücken, ohne Kollision, nur nah). Texturen birch_bark,
  smooth_bark. Anteile, Jungwuchs, Farn-/Buschzahlen: WorldConfig `forest_*`, `valley_*`, `wild_*`, `fern_clump` (world_state.tres).
- Farne wachsen in Gruppen, dazu dichte Gebüsche (Thickets) und flache Brombeerhecken. Talbäume behalten ihre Plätze (Arten aus eigenem Zufall).
- Tarnung: `Cover` (scripts/world/cover.gd) – große Büsche tragen sich ein (Tal „valley“, Waldstücke mit ihrem Schlüssel, beim Entladen raus).
  `Player.is_concealed()`: im Kern eines dichten Gebüschs, geduckt (oder Gebüsch ≥ `cover_stand_height`), Licht aus, langsamer als
  `cover_max_speed`. `Player.detectable_from(pos, sniff)`: Kreatur/Zerfleischer/Sucher (Config `cover_sniff_range` 2,5/3,0/2,2 m) nehmen
  einen dann nur ganz nah wahr, die Drohne gar nicht. Wer rennt, raschelt (Geräusch 9 m). W-17/Signatur lockt den Sucher trotzdem.
- Prüfung `RegressTest._t_cover`, Tour-Bilder A0/A1.

## Stimmung: Wind, Wetter, Himmel, Mond (Christian, 13.11.2026)
- Christian: Retro-Look bleibt; wichtig sind ein toller Mond und bedrohliches Wehen im Wald („ist es der Wind, oder lauert was?“).
- Shader-Globale (project.godot `[shader_globals]`): wind_strength, wind_dir, wind_time, rustle (xyz Ort, w Stärke), wetness.
  Gesetzt von `Wind` (scripts/world/wind.gd, `Wind.current`). Werte zur Laufzeit über `Wind.current` lesen (global_shader_parameter_get liefert null).
- Pflanzen wiegen sich: `shaders/foliage.gdshader` (`BuildKit.foliage_mat`, `Forest.plant_mat(kind)`), Böen-Welle identisch in Shader
  und `Wind.gust_at`. Böen hört man kommen (Aufnahme „gusts“, läuft mit der Welle). Rascheln: ThreatConfig `rustle_*` – mal Böe in
  Windrichtung, mal „etwas“ quer/hinter dir, verstummt beim Hinsehen, Vögel schweigen, manchmal Ast knackt. Gegner rascheln echt
  (`Wind.disturb` in Creature/Mauler/Seeker).
- Wetter in `WorldState` (weather, weather_until, wetness, `set_weather`, im Spielstand), Gewichte/Wind/Wolken/Blitze: WorldConfig
  `weather_*`, `wind_*`, `clouds_*`, `lightning_*`. `WeatherFx` (Regen, Tropfen, Regen aufs Dach, Gewitter, Wetterleuchten, nass),
  `AirFx` (Pollen, Mücken am Bach, Glühwürmchen, Blätter, Atemwolken, Dunst überm Bach morgens/abends).
- Himmel `shaders/sky.gdshader` + `DayNightEnvironment` (`current`): Sterne, Milchstraße, Mond mit Mondmeeren/Kratern/Phase/Hof,
  Wolken ziehen vorm Mond vorbei (dimmen das Mondlicht, CPU-Abfrage `_cloud_cover`), Blitz, grüner Schimmer bei Aliens.
  Farbstimmung je Tageszeit über `RetroFilter.set_grade`, Bodennebel morgens/abends, Augen-Anpassung beim Rein-/Rausgehen.
- Boden (`shaders/ground.gdshader`): Laubstreu, nass dunkler, Pfützen auf Wegen. Wald: Moos auf Steinen, Pilze, Äste, Wurzelanläufe.
  Wasser `shaders/water.gdshader` (Fließen, Glitzern, Regenringe, Schaum am Ufer).
- Hütte: Vorhänge wehen (`CurtainDraft`, stark bei zerbrochenem Fenster), Laufwege/Flecken/Ruß als Decals (`Cabin._build_wear`).
- Kamera: Fernglas mit Tiefenunschärfe, leichtes Schwanken beim Gehen. Tour-Bilder B0–B4 (Mond, Wolken, Morgennebel, Regen, Abendsonne).
- Prüfung `RegressTest._t_atmosphere`.
- Brummton „etwas ist da“ (Aufnahme silence, `NatureAmbience._dread_level`): nur bei echter Präsenz (Kreatur nah,
  `silence_for(s, true)`); Rascheln im Gebüsch ruft `silence_for(s, false)` = nur Vögel still. Talverwandlung legt ihn nur nachts leise darunter.

## Korrekturen 13.11. abends (Christian)
- Regale an Ost-/Westwänden: `Cabin._shelf` richtet Seitenbretter nach der langen Seite aus. Speis-Vorräte stehen auf den Brettern,
  ohne Kisten/Seitenwand zu berühren (`Cabin._overlaps`). Wandertafel linksbündig ab der Farbmarke, Kabelschacht-Schrift zweizeilig.
  Steg-Geländer fest (`RailCollision_L/R`).
- Lampen in Büro, Kinderzimmer, Dachboden, Keller: Stil `flush` (direkt an der Decke); nur Hängelampen pendeln (Vorkommnis).
- Leitern: Dachbodenleiter hängt an der Nordkante (`AtticHatch.LADDER_TOP_Z/LADDER_FOOT_Z`), Deckel klappt nach oben (`LID_OPEN`);
  Kellerleiter an der Nordkante (`CellarHatch.LADDER_RUN`). Kletterwege `climb_points()` – Kopf oberhalb der Decke immer in der Öffnung.
- Wasserhahn-Spuk: E am Küchenhahn dreht zu (`WaterSource.running_ghost`). Prüfung `RegressTest._t_fixes_1311`, Tour-Bilder 8A/8B.

## Endspurt und Enden (Christian: „alle Punkte“, 14.11.2026, nach Story-Bibel)
- Inhalte: `data/story/endings.json` (endgame: nights 5, Warnungen je Restnacht, late_hour; truck.needs; confirm-Text;
  endings mit title/kind/color/sound/lines/gift; credits). Ids wie in `default_settings.json`.
- `Story`: `shaft_open_day`, `warned`, `open_shaft()`, `nights_left()`, `saat_progress()` (Himmel/Nebel/Farbstich in
  DayNightEnvironment), `_check_deadline()` (Warnungen morgens, letzte Nacht ab late_hour → „zu_spaet“), `socket_options()`
  (Bedingungen der Enden), `start_ending(id)` (speichert vorher, dann `GameState.ending_lock` = nichts mehr speichern).
- Brunnen `WellShaft` (Places/brunnen, ersetzt WellInspect): ab Phase 5 mit `shaft_winch` → ChoiceDialog-Warnung → offen
  (Bretter weg, Winde+Seil, violettes Licht). Hinab = `ScreenFade.teleport` in `RootChamber` (CENTER (13.5,-36,-13), geschlossen,
  Wurzeln, pulsierender Knoten, `RopeUp`, `NodeSocket`). Player-Rettung „durchgefallen“ ignoriert die Kammer. Unter der Erde kein Himmelslicht.
- Fassung: shutdown → Stille (Abschaltfolge 1+2 + structure_off + source_dead), shutdown_send → Gehört (mit mast_repaired) sonst
  Abgeholt, send → Abgeholt, overload → Glut (overload_module + blast_charge), code → Schutzstatus (ast_schutzstatus + stef_mappe;
  das Blatt mit dem Code liegt in Stefanies Mappe). Ohne getragenes W-17 alles gesperrt. Vor jedem Ende: „Das ist das Ende deiner Geschichte.“
- Flucht: `EscapeTruck` (Christians Pickup, `EscapeTruck.HOME` (6.5, 0, 13.6), persistent): Autoteile 2, Batterie, Benzin 2 → repariert → wegfahren.
- `EndingScreen` (Schlussszene Zeile für Zeile, Titel „Ende: …“, Abspann, `Settings.reach_ending`, Hauptmenü; Tests: `EndingScreen.speed`,
  ohne Speicherplatz bleibt man im Spiel). `ChoiceDialog` (Auswahlfenster, Esc = zurück, Pausenmenü gesperrt).
- Endspurt-Druck: ThreatConfig `endgame_siege_every` (2), `endgame_visit_chance` – keine ruhigen Nächte mehr.
- Prüfung `RegressTest._t_endings`, Tour-Bilder C0–C3 (Kammer, Fassung, offener Brunnen, Pickup; Schlüssel `shaft_open`, `abs_y`).

## Weitere Punkte 14.11.2026
- Test-Knopf „zu Tag 10“ aus dem Pausenmenü entfernt (Funktion bleibt nur für `--night-test=changes`).
- Pfützen größer + Fresnel-Glanz (ground.gdshader), Abendsonne goldener/kräftiger (DayNightEnvironment).
- Fremdpflanze: supplies.tres crops `alien` (no_water, stage_bonus, signature) aus `alien_seeds`: wächst ohne Wasser, wird nie grau,
  nachts grünes Licht + Signatur (`Supplies.alien_bed_signature` in `Research.home_signature`), Ernte `alien_fruit`.
- Tagebuch: Autoload `Journal` (data/story/journal.json: Texte zu Ereignissen + Nächten), Einträge aus Tasks.flag, Notizen, Spuren,
  morgens die Nacht; Tablet-Reiter „Tagebuch“; im Spielstand („journal“).
- Mehrtagesmärsche: Rastplätze map.json `rest_spots` (13, auf halbem Weg der langen Pfade), `RestSpot` (Feuerstelle `RestFire`,
  Sitzstämme, Holz, Schild) aus WorldTrails; Zelt in `camp_rest_radius` → weniger Zeltnacht-Ereignisse (`camp_rest_factor`).
  Karte: △ Rastplätze (Wanderkarte), Entfernung + Gehzeit an Spur-Zielen (`MapScreen.march_text`), Proviantzeile (`supply_text`).

## Zeltnacht 2.0 (Christian 14.11.2026: „umfangreicher und bedrohlicher, Geräusche, Bewegungen, Tiere, Dinge zum Handeln“)
- Inhalte `data/threat/camp_events.json` (24 Vorfälle: id, weight, wakes, from_night, needs fire|phase2|dictaphone, act).
  Menge/Werte ThreatConfig: `camp_events` (4,7), `camp_wake_max` 3, `camp_hold_rise/fall/seconds`, `camp_hand_damage`,
  `camp_still_damage`, `camp_min_health`. ThreatDirector plant Ereignisse „camp:<id>“ (`CampEvents.plan`); nur `wakes` weckt
  (`first_disturbance`), verschlafene leise Vorfälle entfallen.
- `CampEvents` (scripts/building/camp_events.gd, Kind von TentCamp): Stimmung (owl_silence, twigs, deer/wisps/glimpse über
  NightOmens, fox_scream, pebbles, radio_voice, gear_moved → Steinkreis am Morgen, face_door nur beim Hinsehen) und Handeln:
  sniffer ([F] Licht, sonst Essen weg), zipper/shake ([E] halten, Druckbalken in der Hinweiszeile; sonst Hand greift herein bzw.
  Zelt bricht = `tear(0)`), breath_still (stillhalten), drone_scan (Licht aus, sonst Signatur + Sucher), mauler_prowl (LED zum
  Eingang hinaus, Feuer hält ihn fern, sonst Krallenrisse), lure (Kinderstimme; wer >10 m weggeht, dem reißt das Zelt; morgens
  Kinderfußspuren). Ältere Vorfälle (steps, shadow, press, voice, light, fire_out, seeker) bleiben in TentCamp.
- Regel bleibt: verletzt, tötet nicht. Nach dem Aufreißen `TentCamp.spared_until` → Zerfleischer greift dort bis zum Morgen nicht an.
- Prüfung `RegressTest._t_camp_events` (Planung, echtes Zelt, alle Handlungen richtig/falsch, alle Vorfälle einmal).

## Vorbereitung Mehrtagesmarsch (Christian 14.11.2026)
- story.json `packing` (intro, items mit need/food/water/fuel/any/optional, leave_distance, late_hour, Texte). Gilt, sobald eine aktive
  Spur ein Ziel mit map.json ring „multi“ hat, das noch nicht besucht ist (`Story.multi_trip_target`). Erstes Mal: Gedanke (Flag
  `packing_intro`); Tablet „Aufgaben“ zeigt oben die PACKLISTE (`Story.packing_status`); Karte zeigt „es fehlt: …“; beim Losgehen
  (70–130 m von der Hütte) einmal am Tag Warnung, wenn etwas fehlt oder es nach 12 Uhr ist (`Story._check_packing`).
  `Inventory.count_food/count_water`. Ilses Text zur Zeltspur nennt jetzt Zelt, Essen/Wasser für 2 Tage, Holz, Schlafsack.
- Prüfung `RegressTest._t_packing`.

## Fehler im 15-Tage-Durchlauf (14.11.2026, behoben)
- „Nach Tag 11 kommt Tag 13“ war echt: zweites Einschlafen (E im Zelt während der Abblende) sprang zum übernächsten Morgen.
  Jetzt `EventBus.request_sleep()` + `EventBus.sleeping` (Bett und Zelt), zurückgesetzt in `GameState._apply`.
- Durchgefroren aufwachen tötete Sekunden später (Wärme 0): jetzt Gnadenfrist `SurvivalConfig.wake_grace`.
- Hunger/Durst-Abnahme steht jetzt in `data/survival/survival.tres` (`hunger_per_hour`, `thirst_per_hour`) statt im Code.
- Testprogramm: Zeitraffer des Bots pro Bild auf 0,1 Std. begrenzt (Ruckler ließen die Uhr über 21:30 springen → „Tag 2 → 4“).
- Zweiter Fall „Tag 8 → 10“ (14.11. nachmittags): Weckte ein Ereignis gleich nach dem Einschlafen, war der Weckzeitpunkt nach der
  Abblende schon vorbei und `skip_to_hour` sprang einen Tag weiter. Hud schläft jetzt mit `TimeManager.skip_to_total` (Vergangenes = nichts).
  Dazu `Story.multi_trip_target` (Skriptfehler bei Spur-Zielen, `str()` statt `String()`).
- 15-Tage-Durchlauf: 0 Tode, 0 Fehler. Beobachtung: Der Bot tankt erst spät nach (Tank tagelang 0) – im Spiel hilft der Holzvergaser.

## Schleichen (Christian 14.11.2026: Punkte 1, 2, 4, 5, 6, 7)
- Zwei Fragen für alles: wie laut, wie sichtbar? Spieler-Seite `Stealth` (scripts/player/stealth.gd), Gegner-Seite `Awareness`
  (scripts/creature/awareness.gd). Alle Werte `data/stealth/stealth.tres` (`StealthConfig`).
- Hören: jeder Schritt meldet `Player.make_noise` (Hörweite = Gangart sneak|slow|walk|run × Untergrund `surface_factor`, im Haus
  × `indoor_factor`); im Wald knackt manchmal ein Ast. Knarrende Dielen: data/house/house.json `creaky_boards` (helle lose Bretter
  `CreakyBoard_N`, `Cabin._build_creaky_boards`), normal gehen = immer laut, geduckt/Alt = selten leise. Wind-Böen und Regen
  übertönen (`Stealth.mask_at`).
- Atem (Christian: Alt = langsam gehen UND Atem anhalten zugleich): `Player.holding_breath`, kostet Ausdauer (`breath_drain`), Herz
  wird lauter; ohne Puste lautes Luftschnappen (`gasp_radius`, dann `breath_recover` Sekunden Sperre). Hörbarer Atem aus der Nähe
  (`breath_radius`, außer Atem nach Rennen `breath_radius_panting`). Atemwolke (AirFx) nur ohne Anhalten, macht etwas sichtbarer.
  Läuft in `Player._process` (auch im Sitzen/auf der Couch). Zeltnacht „breath_still“: Alt halten (ThreatConfig `camp_breath_grace`).
  Belagerung: im Versteck steht es davor – wer länger als `siege_breath_grace` atmet, wird gefunden (Schaden, dann weg).
- Sehen: `Player.visibility` 0..1 (Dunkel, Mond `Stealth.moonlight`, Schatten unter Kronen `Stealth.canopy`, eigenes Licht,
  Lampe/Feuer in `near_light_range`, beleuchteter Raum, geduckt, rennen). Sichtweite der Gegner `Stealth.sight_range(vis)`.
  Fensterglas lässt Blicke durch (Gruppe `see_through`, `Stealth.line_clear`) – wer im hellen Zimmer steht, wird gesehen;
  seitlich neben dem Fenster nicht, und dort (oder geduckt unterm Fenster) greift die Kreatur nicht hinein (`Creature._reach_clear`).
- Lehnen (Y/X): `Stealth.seen_part` – ist der Körper verdeckt und nur der Kopf frei, zählt man nur `peek_lean` (lehnend) / `peek_head`.
- Verdacht: `Awareness` (Stufen CALM → SUSPECT ab `suspect_at` → INVESTIGATE ab `investigate_at` → ALERT bei 1), Sehen
  (`notice_close/far`), Geräusche (`noise_gain`, laute zählen mehr), Atem, Abklingen. Kreatur: neue Zustände SUSPECT (hält inne,
  Kopf zum Reiz) und INVESTIGATE (geht hin, sucht `investigate_time`); entdeckt erst bei ALERT + Sicht; sieht/hört sie dich im
  Haus, geht sie zum nächsten Zugang (`_choose_entry(near)`). Zerfleischer greift erst an, wenn er dich bemerkt hat
  (MaulerConfig `sight_factor`, `hearing`), Sucher sieht nach ab INVESTIGATE. Belagerung: Lärm im Haus erhöht Dachboden-/Fensterdruck
  (ThreatConfig `siege_noise_pressure`).
- Anzeige `StealthHud` über dem Schnellplatz (Auge = höchster Verdacht in Gruppe „aware“, Punkt = Sichtbarkeit + Atem-Ring,
  Wellen = letztes Geräusch), abschaltbar: Einstellungen „Schleich-Anzeige“ (`Settings.stealth_hud`).
- Prüfung `RegressTest._t_stealth`.

## Wechselbalg (Christian 14.11.2026: „alle Ideen“)
- Christians Entscheidungen: Name Wechselbalg; Entführen = Aufwachen im Wald, nicht weit von der Hütte; tagsüber maskiert ja;
  ab Story-Phase 2; Axt geht immer (auch tagsüber); Töne nimmt Christian auf (Wunschliste: schleifen_holz/schleifen_laub, gelenke,
  atmen_leise, setzen, entfalten, ziehen, schrei → tools/audio/sfx.py MAP → SoundBank-IDs changeling_*; bis dahin Ersatzklänge).
- `Changeling` (scripts/creature/changeling.gd), Modelle `ChangelingModel` (10 Tarnungen chair, office_chair, broom, lamp,
  coat_stand, bench, stump, backpack, signpost, tent – je ein deutlicher und ein feiner Fehler; wahre Gestalt build_true
  crouch|stand: zu viele Gelenke, schiefer Kopf, Lächeln bis zu den Ohren, aufgerissene Augen in dunklen Höhlen).
  Orte/Gedanken/Texte: data/creatures/changeling.json (spots where yard|house|morning|siege). Verhalten: data/creatures/changeling.tres
  (`ChangelingConfig`), wann: ThreatConfig `changeling_*`.
- Regeln: bewegt sich nur ungesehen (`is_seen`: Blickkegel + freie Sicht auf oben/Mitte/unten), rückt ruckweise näher (Schleifen
  bricht beim Hinsehen ab), dreht sich dabei zu dir. Tarnung auf Ebene `MASK_LAYER` (Überwachungskameras sehen sie nicht),
  wahre Gestalt auf PHANTOM-Ebene (nur Kameras). Wahre Gestalt sonst nur: Blitz (`DayNightEnvironment.flash` → `on_lightning`),
  Badezimmerspiegel (Gesichtsbild `face_texture`), Axthieb (`on_melee_hit`, über PlayerHands._melee_hit), Zupacken.
  Uhr-LED zeigt einen falschen Schatten (Decal mit langen Fingern). Töne: Echo-Schritte (Player-Signal `stepped`), leises Atmen nur
  beim eigenen Atem-Anhalten, Stuhl knarrt „als setze sich jemand“, Gelenkknacken beim Rücken.
- Stufen (`ThreatDirector.changeling_stage`, `changeling_count` im Spielstand): 1 = „ein Ding zu viel“ auf dem Hof (verschwindet
  ungesehen), 2 = im Haus mit deutlichem Fehler, rückt langsam, 3 = feiner Fehler, rückt bei jedem Wegsehen, Echo-Schritte;
  ab `changeling_abduct_from_night` packt er von hinten zu. Endspurt: `changeling_multi` gleichzeitig. Morgens manchmal ein Stuhl,
  der zum Bett schaut. Wach nachts (nicht eingeschlafen): zusätzlich `changeling_awake_check/chance` (Christian 15.11.: öfter, wenn
  man wach ist), höchstens einmal pro Nacht (`changeling_awake_possible`). Tagsüber (`changeling_day_*`): zweite Bank neben Wanderbank/Rastplatz oder falscher Wegweiser, folgt dir.
- Zupacken: `Changeling.grabbing`, `Player.grabbed_by` (Zug weg von der Hütte), [E] halten / LED auf ihn / Faust = Balken,
  Axt = sofort frei. Sonst `_abduct`: Abblende, Aufwachen `abduct_distance` von der Hütte, Morgen, Schaden (nie unter
  `abduct_min_health`), kalt, `abduct_drops` Sachen verstreut auf dem Weg (`scatter_items`, nie Einzelstücke). Merker abducted.
- Axt/Faust auf die Tarnung: enttarnt, Schrei, Blitz, weg, Gelenkhaut `changeling_skin` (1× pro Tag). Tagsüber geschlagen =
  gekränkt (`changeling_offended`): in der Nacht kommt er sicher und schneller. Schlag gegen echte Dinge = laut (`melee_noise`).
- Zelt (camp_events.json, needs phase2): cl_backpack (zweiter Rucksack), cl_stump (Stumpf rückt näher), cl_tent (morgens ein zweites
  Zelt). Er packt am Zelt nicht zu. Belagerung: Aufgabe „fake“ (5. Aufgabe, ab Phase 2): falsches Ding rückt näher, LED
  `siege_led_time` vertreibt es, erreicht es dich = Fehlschlag.
- Forschung: an_changeling_skin (Gelenkhaut) + an_membrane → link_mimic „Nachahmer“ → Rezept `fake_probe` (Echtheitsprüfer,
  `GadgetHud.fake_text`, piept beim Hinsehen). Drop nach Nächten mit ihm (after „changeling“).
- OFFEN: Im 15-Tage-Durchlauf vom 14.11. abends einmal „Lambda capture at index 0/4 was freed“ (Tag 10, nach dem Neuladen,
  Ausflug Außenstelle) – Herkunft noch nicht gefunden, kein Absturz.
- Prüfung `RegressTest._t_changeling` (einzeln: `-- --night-test=regress --only=_t_changeling`). Vorschau der Modelle:
  `creature_preview.tscn -- --changeling=masks|true`.

## Christians Testrunde 14.11. abends (bis zur ersten Belagerung)
- Belagerung: In Belagerungsnächten keine anderen Wesen, Vorkommnisse oder Kleinigkeiten (nur „siege“). Spieluhr-Zwang zieht
  niemanden aus dem Versteck (`SiegeNight._lure_to_door` zählt dann nur als Fehlschlag). Nach überstandenem Eindringen
  `siege_calm_after` Sekunden Ruhe. Sucher/Zerfleischer meiden Grundriss von Hütte, Anbauten, Schuppen am Boden
  (`Cabin.blocks_ground` – `is_inside` prüft die Höhe ab Hüttenboden, Punkte auf dem Gelände fielen durch).
- Die ersten `calm_first_nights` (2) Nächte ganz ohne Ereignisse (ThreatConfig).
- Bett: Hinlegen/Aufstehen mit Kamerabewegung (`Bed._lie_down/_on_woke`, aufgeschreckt schneller). Nach jedem Schlaf (Bett,
  Zelt) ist die Uhr aus und im LED-Modus (`Player._on_sleep_finished`).
- Klänge: Diele `board_creak` (0,75 s, aus floor_creak geschnitten), Ast beim Gehen `twig_snap` (knackt sofort),
  Dachschritte halb so lang (sfx.py clip 4.95). Regen aufs Dach drinnen leiser, nach Regen seltener gleich wieder Regen
  (WorldConfig `rain_repeat_factor`).
- Gießkanne am Rand des östlichen Hochbeets. Couchtisch schmaler, Holzkorb an die Wand neben den Kamin (Lauftests
  „Zwischen Couchtisch und …“). Annex-Dächer fest (Kinderzimmer/Büro). Hochsitz neben dem Nordweg.
- Aufgabe Trinkwasser zählt volle Flaschen jeder Art (`bottles_full`), Aufgabe Versteck nennt (E). Tablet flackert nur, wenn
  wirklich ein Wesen da ist. Karte (M): Mausrad zoomt (ZOOMS 1/2/4/8 um die Maus), ziehen verschiebt. Experiment-Hinweise
  erklären die Folgen („laut“ = Wesen hören das).
- Prüfung `RegressTest._t_fixes_1411`, `_t_window_sides`.

## Christians dritte Liste 14.11. abends
- Versunkenes Dorf neu: `DrownedVillage` (scripts/world/places/drowned_village.gd) baut Hausruinen (Schlammrand bis `WATERLINE`,
  Steinmauern mit Öffnungen, eingestürzte Wand, Balken, Schutt) und die Kirche (Schiff mit Rundbogenfenstern, Bänken, Altar, halbem Dach,
  Turm davor mit Tor + Durchgang ins Schiff, Glocke). Knotennamen Church / Ruin_N bleiben (Funde, Notizen auf dem Altar). Tour-Bilder D0/D1.
- Nachts im Wald (Christian: „einfach durchlaufen darf nicht belohnt werden“): `ThreatDirector._check_night_roam` / `roam_chance()` –
  ab `roam_min_distance` von der Hütte, nicht im Zelt-Umkreis, nicht im Gebüsch versteckt: Chance pro Wurf wächst mit der nachts
  gelaufenen Strecke (`roam_meters`), Rennen × `roam_run_factor`. Erst Warnung (Schritte), dann Zerfleischer (ab Phase 2), Sucher oder
  Kreatur. Werte ThreatConfig `roam_*`, nicht in ruhigen Nächten / Belagerung.
- Morgengrauen: alle Kreaturen (`call_group("creature","leave")`) und Drohnen (`AlienDrone.leave`) ziehen ab; Kreatur bei Tag
  verlässt sofort die Jagd, nach `CreatureConfig.leave_timeout` Teleporterblitz. Drohne späht bei Tag nicht, `spawn_ambush` bei Tag = nichts.
- Spieluhr: Vorkommnis „music_box“ lässt Bens Spieluhr selbst spielen (`MusicBox.play_ghost`), E hält sie dann an.
- Regen-Schleife nahtlos (`SoundBank._seamless`), nach Regen seltener gleich wieder Regen. Gras wächst nicht durch Anbau-Böden
  (`Forest._add_multimesh` filtert `Cabin.in_footprint`). Wege schneiden sich als Hohlweg ins Gelände (`Terrain.TRAIL_CUT_REACH`).
- Prüfung `RegressTest._t_village`, `_t_batch3_1411`.

## Christians vierte Liste 14.11. nachts
- Hauptmenü: Knopf „Test: ab Tag 15“ (Platz wählen) → `GameState.new_game(n, 15)` → `GameState.test_start(day)`: Nächte fortschreiben,
  Tag 15 um `TEST_START_HOUR`, Marschgepäck `TEST_KIT` (Zelt, Schlafsack, Lagerfeuer, Holz, Essen, Wasser, Karte, Axt …), heute Nacht
  keine Belagerung. Das Zelt im normalen Spiel liegt in der Kantine im Ferienlager (Lagerweg, blaue Markierung).
- Archiv: unerforschte Funde ohne Bild, nur Platzhalter „???“ (`ResearchMenu.unknown_picture`); Zeile nennt den Platz.
  Analysegerät listet Funde, die woanders untersucht werden (`ResearchMenu.elsewhere_lines`, z. B. Vogel ohne Augen → Mikroskop im Labor).
- Wärme: Kamin und Küchenofen haben `heat_at` (SurvivalConfig `hearth_radius`), direkt davor lädt sie mit `fire_gain` (90/Std.) auf.
- Babyfon läuft mit Batterien (ohne Strom). Holzstapel am Schuppen: data/house/house.json `woodpile` (`refill_days` 2, `ResourceNode.refill_days`).
- Schlaf heilt: SurvivalConfig `sleep_heal_per_hour` (nicht mit leerem Magen/Durst), in `Survival._on_woke`.
- Prüfung `RegressTest._t_batch4_1411` (dazu Sprungprobe im Büro in `_t_fixes_1411`).
- 15.11. abends: Zelt-Modell richtig herum (Planen vom First nach außen, Rückwand als Dreieck, Firststange), Bauteile mit
  buildables.json `anywhere` (Zelt, Lagerfeuer, Fallen, Köder) dürfen überall auf der Karte stehen (sonst ±100 m), nie im Wasser.
  Dorf-Balken lagen an der Hütte (look_at in Weltkoordinaten) → `BuildKit.beam_between` / lokale Basis. Wegweiser ohne Arm
  für Orte unter 60 m. Tour-Bilder E0 (Zelt), E1 (Hüttendach).

## Christians Liste 15.11. abends (nach der ersten Zeltnacht)
- Stacheln im Wald: Wurzelanläufe, Aststummel, liegende Zweige wurden mit `Basis.scaled` (Weltachsen) gestreckt → senkrechte
  Stacheln. Jetzt `scaled_local` (TreeKit, WildForest-Zweige). Bei gedrehten Basen immer `scaled_local` nehmen!
- Morgengrauen: Zerfleischer (`Mauler.dawn`) und Sucher (`Seeker.dawn`) ziehen ab. Zerfleischer bei Tag erst ab
  ThreatConfig `mauler_day_from_hour`, nicht am eigenen Zelt. Gefahr weit draußen jetzt auch tagsüber (`roam_day_factor`, nur
  Zerfleischer, ab Phase 2); `roam_*`-Zähler werden auch im Morgengrauen zurückgesetzt.
- Steine im Wald: SupplyConfig `forest_stones_per_day` (AlienDrops-Ort „wild“: im Tal 30–100 m, unterwegs um den Spieler).
- Hauptmenü-Titelbild ohne Retro-Filter (Tour-Schlüssel `no_retro`, Bild 00 neu gerendert, leicht aufgehellt).
- Türspion `Peephole` (scripts/interaction/peephole.gd, an `Door.add_peephole`, Haustür innen, Shader `shaders/peephole.gdshader`):
  E = Fischaugen-Blick nach draußen, E/Esc zurück. Was man sieht: ThreatConfig `peephole_*` (eye, figure → klopft danach,
  back → dreht den Kopf, dark → Linse zugehalten + Klopfen; tagsüber selten Gestalt am Tor).
- Esc schließt Monitor und Türspion: Gruppe `esc_close` mit `esc_close() -> bool`, PauseMenu fragt sie zuerst.
- Lagerfeuer-Vorschau (Baumodus) hat eigene Umrisse (vorher unsichtbar, kein grün/rot).
- F halten (LED ↔ Display) läuft in `Player._process` → geht auch im Zelt, im Sitzen, im Schrank.
- Todes-Bildschirm: `Player.death_cause` (take_damage(…, cause), Hunger/Durst/Kälte/Hirn/Moor), Texte `data/ui/deaths.json`
  (title + tips), `Hud.death_info`; weiter mit E/Leertaste/Klick (`GameState.death_continue`, nach `DEATH_MIN_WAIT`), Tests ohne
  Speicherplatz wie bisher nach 4,5 s.
- Hände/Gegenstände im Dunkeln: Streulicht der Hände folgt der Umgebung (`PlayerHands.ambient_level`, StealthConfig `hand_fill_*`,
  mit Uhr an etwas heller). Tour-Schlüssel `hold` (Gegenstand in der Hand), Bilder E2/E3.
- Prüfung `RegressTest._t_batch5_1511`.

## Christians Liste 23.11. (Tablet, Karton, Rauschen, Hinweise, Ofen, Bretter, Bildrate)
- Tablet öffnet mit „Aufgaben“ (erster Reiter), Posteingang zeigt „● n neu“ und schlägt beim Anklicken die erste ungelesene auf.
- Umzugskarton erst offen, wenn die Spur `p1_karton` läuft/erledigt ist oder die Aufgabe „Analysegerät“ (got:metal_fragment) da ist
  (`MovingBox.can_open`, Tests setzen `MovingBox.bypass_lock`).
- Dauerrauschen: `static` ist eine Schleife (LOOP_IDS) und lief über `SoundBank.play_ui` endlos (Nervenfühler, Analysegerät,
  Manipulator). `play_ui` blendet Schleifen jetzt nach 1,2 s aus (`_is_loop`, `_cut_loop`) – wie `play_stream_at`.
- Hinweise oben: Stapel `Hud._notes` (neuester oben, ältere kleiner/grau, bleiben `NOTE_OLD_MIN` s, höchstens `NOTE_MAX`),
  `Hud.current_notification()`.
- Kochen: `CookPot` (scripts/interaction/cook_pot.gd) im Küchenofen und Kamin (`pot`, `start_cooking`, `take_pot`, `cook_until`):
  Zutaten gehen in den Topf, garen nur mit Feuer (Spielzeit), Fortschritt in % (Hinweis + Kochmenü, live), fertig = Ergebnis,
  unfertig herausnehmen = Zutaten zurück, gespeichert. Kalter Ofen: [R] herausnehmen. `GameMenus.open_crafting(station, cooker)`.
- Bretterlager: `PlankRack` (Kragarmregal, Knotenname bleibt `Cabin/PlankPile`, 12 Plätze, jedes Brett sichtbar), [E] nehmen,
  [R] alle getragenen zurücklegen. Werte data/house/house.json `plank_rack`. Tour-Bild F0.
- Buch/Becher/Teddy: [E] ansehen = kurzer Gedanke (house.json `inside_things`); sie wandern nachts (InsideChanges).
- Bildrate: `Settings.max_fps` (Stufen `FPS_CHOICES` 30/60/120/144/165/240/unbegrenzt, Start unbegrenzt), `vsync` (an), `show_fps`
  (Anzeige oben rechts), `Settings.apply_fps()`. Vorher fest 60 + VSync → auf 144-Hz-Bildschirmen ungleichmäßig. GameInput nimmt den Wert
  beim Zurückholen des Fensters. CPU-Zeit im FPS-Test ~7 ms/Bild (kein Engpass). Prüfung `RegressTest._t_batch6_2311`.

## Aufgaben auf der Uhr (Christian 23.11.: kein dauerhaftes Questlog)
- J halten (`quest_log`): `PlayerHands.log_raise` hebt den linken Arm (`log_offset`, `log_rot`), Display zeigt statt Kompass eine
  angedeutete Checkliste (`_checklist`, leuchtet selbst), `watch_global_position()`. Hud blendet darüber eine kleine Liste ein
  (`Hud._update_watch_log`, `watch_log_lines()`): HAUPTSTORY (Hauptspuren ◉ + offene Ziele ○, höchstens 4) und HEUTE (Tagesroutine ✓/○).
  Nicht im Baumodus/gesperrt. `force_log` nur für Bilder/Tests (Tour-Schlüssel `log`, Bild F1). Vorschau: hands_preview `--log=1`
  (`--logrot`, `--logoff`). Prüfung `RegressTest._t_watch_log`.

## Organische Gegner (Christian 23.11.: Sucher „wie eine Robotertonne“, Zerfleischer ebenso überarbeiten)
- `FleshKit` (scripts/creature/flesh_kit.gd): `skin` (matt-feuchtes Hautmaterial, Textur am Körper), `smooth` (Catmull-Rom),
  `limb` (gebogene, sich verjüngende Glieder, ovale Querschnitte), `bulb`, `spindle` (Muskeln/Sehnen), `vein`, `finger` (Glieder +
  Knöchel + gebogene Kralle), `rib`. Sucher: ausgemergelt, Rippen, Wirbelgrat, Schulterblätter, knotige Knie, fünf lange Finger,
  Kopf mit senkrechtem Spalt (wulstige Ränder, 15 Augen). Zerfleischer: Muskeln, Bauchmuskeln, Rückenplatten (`Spine%d`), Grey-Schädel
  mit Brauenwulst/Wangenknochen, Zahnfleisch, Sichelklauen. Knotennamen für die Animation unverändert (Knee, Elbow, Claw%d, Skull).
  Vorschau: creature_preview `--what=seeker` (`--dist=`), Mauler wie bisher `--pose=`.
- HUD: Inventar-Zeile unten rechts entfernt (Traglast bleibt). Aufgabenlisten: alle offenen Punkte ○ (kein ◉ mehr).
- Schnellleiste (`HotbarHud`): keine Namen in den Kästchen mehr, größere Bildchen (36 px) + Anzahl; Name des gewählten
  Gegenstands kurz klein über der Leiste. Sucher hält `Seeker.WALL_MARGIN` (1,1 m) Abstand zu Hütte/Schuppen (Kopf ragte durch
  Dachkante); Zuschlagen prüft weiter nur `_blocked_at` (wer direkt an der Wand steht, ist nicht sicher).

## Sucher am Haus (Christian 23.11.: „bedrohlicher, wenn man im Haus ist“ – Idee 1 mit Schaden + lange Arme, unberechenbar)
- `Seeker.State.HOUSE` (`_house_check` alle 0,5 s): Spieler in der Hütte (inkl. Dachboden/Keller, nicht in Belagerungsnächten) und
  Sucher näher als `house_range` → stellt sich vor ein Fenster (meist dem Spieler nächstes, `house_random_window` zufällig;
  `entry_point`-CabinWindows + `attic_window`), nicht unters Verandadach (`_under_porch`), wechselt nach `house_window_time`.
  Lichtstrahl `_beam` (SpotLight3D aus dem Augenspalt) pendelt durchs Zimmer, erfasst er dich (`Stealth.line_clear`: Glas zählt nicht,
  Bretter schon), folgt er (`beam_follow`) und brennt (`beam_damage`/s). Kommt man hinaus → `_investigate`.
- `SeekerArm` (scripts/creature/seeker_arm.gd): bricht aus Wand/Boden/Decke (Raycasts vom Spieler aus, `reach_weights`, oft hinter
  dir `reach_behind_chance`, manchmal zwei kurz nacheinander `reach_double_chance`, höchstens `reach_max`), Holzsplitter + Loch,
  tastet zum Spieler, Berührung = `reach_damage`, Uhr-LED `reach_led_time` oder Axt/Faust (`PlayerHands._melee_hit`, Gruppe
  `seeker_arm`) = zurück; danach bleibt 90 s ein Loch. Im Versteck (`is_hidden`) erwischt sie dich nicht.
- Schaden immer über `Seeker.hurt_player` (nie unter `min_health` – der Sucher tötet nicht). Todesbildschirm-Texte seeker_beam/seeker_arm.
- Werte SeekerConfig „Im Haus“ (`house_*`, `beam_*`, `reach_*`). Vorschau Arm: creature_preview `--what=arm`. Prüfung `RegressTest._t_seeker_at_house`.

## Bedrohung à la Resident Evil / Alien Isolation (Christian 23.11.2026)
- Christians Wahl: Verstecke lernen (komplett), Angst (komplett), Gesundheit härter OHNE Bluten und OHNE Uhr-Akku (Uhr bleibt
  dauerhaft), nur „Speichern am Bett“, Spannungsbogen enorm und unberechenbar, auch tagsüber nicht sicher.
- Angst `Fear` (scripts/player/fear.gd, `Player.fear`, Werte data/player/fear.tres `FearConfig`): steigt durch gesehene/gehörte
  Wesen (Gruppen `threat_groups`), bemerkt werden (Awareness ALERT), Dunkelheit draußen, weit weg nachts, Belagerung, Atem anhalten,
  Treffer, Schreckmomente `EventBus.fear_spike(amount)` (statt fear_changed direkt). Sinkt am Licht/Feuer und im Versteck.
  Folgen: Herzschlag, dunkle Ränder (Hud-Shader), Zittern von Händen + LED (`PlayerHands._avoid_walls`), `make_noise` × noise_factor,
  Atem hörbar ab `breath_betray_from` (Stealth.breath_radius), Rennen/Atemanhalten kosten mehr Puste.
- Gesundheit (SurvivalConfig „Gesundheit“): `damage_factor` 1,35 auf alle Treffer (take_damage), von selbst nur langsam bis
  `passive_heal_cap`, Schlaf 3,5/Std., Gesundheit + Bein im Spielstand (`Survival.health`, `leg_until`, nach Laden mind.
  `restore_min_health`; nach einem Tod `Survival.make_survivable`: mind. Wärme/Essen `restore_min_*` – keine Todesschleife). Bein verletzt (`Survival.hurt_leg`: Falle, harter Sturz, schwere Treffer mit `leg_chance`): humpeln,
  kein Rennen, Hud „Bein verletzt“; Verbandskasten heilt es. Todesgründe fall, hide_found.
- Speichern: `GameState.bed_save()` beim Aufwachen im Bett (Bed._on_woke) = Schnappschuss + Platz. Kein Morgen-Speichern, Beenden/
  Hauptmenü speichern nicht (Pause zeigt „Zuletzt: Tag X“). `bed_day/bed_hour`. Neues Spiel und Enden sichern weiter.
  Nach dem Laden mitten in der Nacht holt der ThreatDirector Vergangenes nicht nach (`_skip_past`, außer „siege“).
- `Dread` (scripts/systems/dread.gd, Kind des ThreatDirectors, `ThreatDirector.dread`), Werte ThreatConfig:
  **Verstecke lernen** – `ThreatDirector.hide_uses` (Knotenname → Nächte), Chance `hunt_chance` (Nachtart, Benutzungen, Minuten über
  `hide_safe_seconds`, × (1 + Druck)) → `HideHunt` (scripts/creature/hide_hunt.gd): Schritte bis vors Versteck, schnüffeln (Alt!),
  rütteln (`HideSpot.rattle`), aufreißen (`HideSpot.force_open`, Chance `tear_chance`: Benutzungen + hörbarer Atem) oder abziehen;
  wer nicht mehr drin ist, wird geschlagen. Lange versteckt = Schläge gegen Fenster/Türen (`hide_damage_*`). In der Belagerung reißt
  sie oft benutzte Verstecke auch mit angehaltenem Atem auf. **Stille eskaliert** – wer nachts wach ist und sich kaum bewegt:
  `still_steps` (Schritte → Kratzen → Klopfen → Rütteln → Dach → sie selbst). **Tagsüber** – `day_incidents` pro Tag (+ Druck):
  drinnen Klopfen, Diele, Dach, Radio, Gesicht am Fenster (ab `day_window_from_day`); draußen Schritte hinter dir, Stille,
  Schrei, Gestalt (Apparition forest), selten Zerfleischer (Phase 2, > `day_mauler_min_distance`).
- Druck `ThreatDirector.menace` (im Spielstand): ruhige Nächte +`menace_rise`, Auftritte −`menace_drop_*`; erhöht Auftrittschance,
  `break_calm_chance` bricht die erwartete Ruhe, `late_arrival_chance` (kommt spät), `second_wave_chance` (kommt wieder).
- Bildrate (24.11.): Christian hat RTX 5070 + Samsung C49RG9X (5120×1440, 120 Hz) – nicht der Bildschirm war schuld:
  `Settings.apply` setzte die volle Auflösung der Grafikstufe und überschrieb die Einsparung des Retro-Filters → 7,4 Mio. Pixel + MSAA.
  Jetzt EINE Stelle `Settings.apply_render_scale()` (RetroFilter ruft sie): mit Filter Zeilen = `RetroFilter.VIRTUAL_HEIGHT` ×
  `retro_oversample` (quality_levels: 1.0/1.25/1.5), ohne MSAA/FXAA; ohne Filter `scale` + `msaa` der Stufe.
  FPS-Anzeige: FPS, CPU/GPU-ms, Bildschirm-Hz, Grafikkarte (`get_video_adapter_name`) und 3D-Auflösung. Prüfung `_t_render_2411`.
  Danach lief es erst auf der AMD-Grafik im Prozessor (Windows-Grafikeinstellung), mit RTX 10 ms GPU bei 3840×1080 → Tal-Wald
  (`Forest._add_multimesh`) jetzt in Feldern von `Forest.CHUNK` 36 m (Knoten „Trunks“ usw. = Gruppe mit Feldern), kleine Pflanzen
  ohne Schatten nur bis `PLANT_RANGE` 60 m; Mondschatten nur ohne Sonne (2 Stufen), Sonnenschatten-Stufen je Grafikstufe
  (`shadow_splits`), Volumennebel-Raster 64×64 (project.godot). FPS-Anzeige unter der Uhrzeit. GPU-Messung `--night-test=gpu`
  (`GpuBench`) nur auf echter Grafik aussagekräftig – mit Software-Vulkan (lavapipe) sind die Zahlen wertlos.
- Prüfung `RegressTest._t_dread_2311`.

## Verstecke 2.0 (Christian 24.11.2026: alle gleich, mehr im Haus)
- `HideSpot` (scripts/interaction/hide_spot.gd): [E] hinein = kurze Bewegung (Tür/Vorhang/Deckel/Klappe auf → Kopf an die
  Stelle `anchor` + Augenhöhe `eye`, Blick `face` → zu), [E] heraus = rückwärts zu `front_point(exit_dist)` (`exit_dir` für seitlich).
  Türen von Haus aus zu (Duschvorhang hängt offen). Tür-Kollision nur, wenn zu (`_door_solid`). `hides_player` = drin + `settled` + zu.
  Drinnen (`Player._hide_physics`, `Player.hide_offset`): keine Schwerkraft, WASD im kleinen Raum `move`, Strg = `crouch_drop`, Y/X
  lehnen, Uhrlicht, E über `current_interactable` = Versteck. Woandershin versetzt (> 1,5 m) = automatisch raus. `force_open` wirft hinaus.
- Sieben Verstecke: Cabin/Wardrobe (wardrobe), Shed/Locker (locker), Cabin/HideBehindChair (open, hinter dem Schaukelstuhl),
  Cabin/HideShower (curtain, Vorhang L-förmig), Cabin/HideUnderDesk (open, Stefanies Schreibtisch), Cabin/HideKidsCorner (fort,
  Deckenhöhle NO-Ecke Kinderzimmer, Farbeimer dafür nach Westen), Cabin/HideAtticChest (chest, Sehschlitz Richtung Luke).
  Tour-Schlüssel `hide` (+ `hide_yaw`, `hide_pitch`), Bilder G0–G4. Prüfung `RegressTest._t_hide_2411` (Ausstieg frei, Augenhöhe, Spielraum).
- Dachfenster `Cabin.ATTIC_WIN_W` 1,4 m (doppelt). Radio-LED-Licht mit Schatten (schien durch die Wand), nur sichtbar, wenn es leuchtet.
- Tunnelportal: map.json Ort `drop` (Fläche tiefer in den Hang, `WorldMap._place_base`) – Tunnel 20 m tiefer, Aufstieg von Westen
  vorher bis 140 % Steigung, jetzt höchstens ~40 %.

## Bayerischer Wald (Christian 24.11.2026: echte Namen, Spätherbst mit erstem Schnee, Bairisch nur Ilse + Wendt, Totenbretter ja)
- Schauplatz: Nationalpark Bayerischer Wald um Finsterau/Mauth an der tschechischen Grenze. Sechs Etappen geplant:
  1 Namen/Bairisch/Totenbretter (erledigt), 2 Spätherbst + Schnee, 3 Landschaft (Fichten, Granit, Totholz, Filz, Schachten),
  4 Orte umbauen (Grenzstation, Radarkuppeln, Triftklause, Stollen, Glashüttendorf), 5 Hütte als Waldlerhaus (Kachelofen,
  Herrgottswinkel, Drudenfuß, Gred), 6 Klänge (Kirchenglocken, Kauz, Hirsch, Rauhnacht) + Wunschliste.
- Etappe 1: Namen in map.json (ids unverändert): Siebensteinkopf (Funkmast), Lusen (Ilse, Lusenschutzhaus), Rachel (Wetterstation),
  Schwarzberg, Haidel, Grenzkamm, Rachelsee, Reschbachquelle, Finsterauer Filz, Höhle am Reschbach, Totholzhang (früher Windwurf),
  Granitbruch, Kontrollpunkt Mauth (Grenzpolizei), Rasthaus Waldblick an der B12, Waldkapelle St. Gunther, Gunthersteig (früher
  Kapellenweg), Reschbachsteig (früher Bachpfad). Orte können `sign` = Kurzname für Wegweiser haben; zu lange Wegweiser-Texte werden kleiner.
- Bairisch: Ilses Sätze (story.json, Logbuch, Ende „Gehört“, Zettel an ihrer Tür) und Wendts Notizen/Meldungen. Spur-Hinweise haben
  `hint_ilse` (Bairisch) – nach `mast_repaired` sagt Ilse sie über Funk, sonst bleibt `hint` ein eigener Gedanke. Christian selbst spricht Hochdeutsch.
- Totenbretter: map.json `totenbretter` (Texte, Farben, Wunschpunkt am Abzweig des Gunthersteigs), gebaut in `StoryProps._totenbretter`
  (Stelle am Wegrand `memorial_spot`, weg von Stämmen), Notiz `totenbretter`. Tour-Bild H0 (Schlüssel `node`/`node_off`). Prüfung `RegressTest._t_bayerwald_2411`.
- Hinweis: Die Himmelsrichtungen im Spiel sind verdichtet (Rachel liegt im Spiel im Nordosten).
- Holz und Steine im großen Wald (Christian 24.11.): liegende Stämme in `WildForest` (`WildLog_N`, Axt) und Steinhaufen
  (`WildStones`, `_stone_pile`, am Bach/See fast immer), Holzpolter an Fahrwegen (`PolterWood`, Axt). Ihr Stand liegt in
  `Supplies.wild` (Schlüssel `ResourceNode.wild_key`, `wild_amount`/`wild_store`, Nachwuchs pro Tag), nicht in der Welt-Liste,
  weil die Waldstücke entladen werden. Werte SupplyConfig „Holz und Steine im großen Wald“. Prüfung `RegressTest._t_wild_wood_2411`.
- Etappe 2 Spätherbst mit erstem Schnee:
  - Kalender: TimeConfig `start_year/month/date` (Tag 1 = Mo 16. Nov. 2026), `TimeManager.date_text()` in HUD-Uhr, Tagesanzeige, Pause.
  - Wetter „snow“ in `WorldState` (WorldConfig „Spätherbst und Schnee“): erster Schnee sicher am Abend von `first_snow_day` (3)
    (verschlafen = man wacht im Weißen auf, Tagebuch `first_snow`), danach Schneefall-Gewicht steigt über `snow_ramp_days`, Regen
    und Gewitter seltener. `WorldState.snow` (Decke 0..1, wächst/taut), `frost` (Raureif nachts ohne Niederschlag, taut ab
    `frost_melt_from_hour`), `snowfall_total`, alles im Spielstand. Test-Start Tag 15: Schnee liegt schon.
  - Shader-Globale `snow`/`frost` (project.godot, gesetzt vom Wind-Knoten): `ground.gdshader` (Decke dünn fleckig, Wege zertreten,
    Reif mit Glitzern), `foliage.gdshader` (`snow_hold` = Schnee bleibt oben liegen, `snow_bury` = niedrige Pflanzen versinken).
    Dächer, Felsen, liegende Stämme, Polter, Blechdächer: `SnowCover.register(material)` → zweiter Durchgang
    `shaders/snow_overlay.gdshader`, nur angehängt, solange Schnee/Reif liegt. Neue Außen-Materialien bei Bedarf dort anmelden
    (keine Materialien, die auch drinnen benutzt werden – sonst schneit es auf den Kaminsims).
  - Spätherbst-Farben: Gras strohig, Farn braun, Laubkronen rostbraun (`Forest.plant_mat`), Blüten verblüht.
  - `WeatherFx` Schneeflocken, `DayNightEnvironment` (Wetter „snow“: Nebel dichter, Sonne schwächer; Schnee hellt draußen nachts auf).
  - Kälte (SurvivalConfig): draußen 2,5/Std. am Tag, 10,5 nachts; × `snowing_factor`, `rain_cold_factor`, `snow_cover_factor`, `frost_factor`.
  - Schleichen: auf Schnee knirscht es (`Footsteps` Untergrund „snow“ ab `SNOW_FROM`, bis eigene Aufnahmen da sind = Kies),
    nachts hebt man sich ab (`StealthConfig.vis_snow`).
  - Spuren im Schnee: `SnowTracks` (Stiefel über `Player.stepped`, Krallen von creature/mauler/seeker/changeling), verblassen nach
    `track_hours`, Neuschnee `track_cover_snow` deckt sie zu, Tauwetter löscht sie (WorldConfig `track_*`).
  - Tour-Bilder H1–H5 (Schlüssel `snow`, `frost`, `tracks`). Prüfung `RegressTest._t_season_2411`.
  - Tag/Nacht-Uhrzeiten bleiben wie bisher (7–19 Uhr), obwohl es Ende November früher dunkel wird – ggf. mit Christian klären.

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
  `SoundBank.ALIAS` nutzt vorhandene Aufnahmen anderer Ordner (Herzschlag, Kreatur-Atem, Schritte). Wunschliste 22.11. für
  ElevenLabs: neue MAP-Einträge in sfx.py (bed_creak, door_creak, glass_crack, thud, bang, scratch, switch, hammer, wood_crack,
  trap_snap, rain, rain_roof, thunder, rustle, signal, static, hurt) + Wechselbalg + Kinderstimme (`prepare.py oneshot child`).
  22.11. geliefert und eingebaut: signal, static, hurt, alle 8 Wechselbalg-Klänge (schleifen_wald = Laub), child. sfx.py ignoriert
  jetzt Groß-/Kleinschreibung. 22.11. abends Rest geliefert (Sound_Pack_II): alle 14 eingebaut – damit sind alle Wunsch-Klänge echt.
  Wind-Rascheln braucht eine Schleife: `rustle_loop` (aus den 4 Rascheln-Clips zusammengeblendet, 10,6 s), Einzelclips `rustle` fürs Zelt.
  23.11. Sound_Paket_III = eigene Stimmen der Gegner: Zerfleischer `mauler_roar` (Warnschrei, Zurückweichen vor Licht),
  `mauler_snarl` (Knurren statt Kreatur-Atem/Klicken), `mauler_swipe` (Klauenhieb), `mauler_steps` (Schleife, laut nach Tempo);
  Sucher `seeker_hum` (Summen, Schleife), `seeker_chitter` (statt Klicken), `seeker_steps` (Schleife beim Gehen),
  `seeker_teleport` (Erscheinen + Blitz beim Verschwinden); Drohne `drone_hover` (ersetzt Generatorsummen), `drone_scan`
  (alle 6–14 s beim Suchen, sofort beim Fensterleuchten); Organismus `organism_pulse` (Pochen am Knoten), `organism_growth`
  (neue Wucherung, `Patch.fresh`, nicht beim Laden). Hilfen: `SoundBank.play_rec` (false = keine Aufnahme → alter Ersatzklang),
  `SoundBank.attach_loop` + `loop_level` (Schleife hängt am Gegner). Manipulator bleibt bei Hausgeräuschen (Absicht).

## Befehle (Cloud-Workspace)
```bash
# Import / Klassen-Cache erzeugen
godot --headless --path . --import
# Kurzer Testlauf auf Skriptfehler (ohne Hauptmenü)
godot --headless --path . --quit-after 300 -- --skip-menu
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
- Zufahrt läuft vom Tor (x -3, z 18) nach Süden bis zur Autobahn (z ≈ 1086). Spielfeldgrenze ±1100 m (Gelände ±1150).
  Tal-Wald (`Forest`) ±108 m, danach `WildForest`. Alle Orte und ihre Koordinaten: `data/world/map.json`.
- Orte: Absturzstelle (-42,-30), fremde Struktur (-78, 40), Höhle am Bach (49, -72), Förster-Hochsitz (7.2, -81.2) (seit 14.11. neben dem Nordweg).
