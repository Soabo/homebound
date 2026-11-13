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
  (Mails/News mit `day`; Familie: Frau Stefanie, Kinder Lena und Ben, Protagonist Christian, LKW-Unfall bei Regen).
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
- Archiv (früher „Alien-Archiv“) und Notizen nur noch auf dem Tablet (Couch, Reiter Posteingang | Archiv | Notizen), Taste J entfällt.
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
  (`Surveillance`, 3 Plätze) zeigt leere Plätze als „nicht installiert“. Icons für camera_1..3 liefert Christian.
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
  Bekannter offener Punkt (kein Fehler): `alien_seeds` hat `seed: alien`, aber es gibt noch keine Pflanze „alien“.
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
- Entscheidungen: Speichern automatisch jeden Morgen + beim Beenden (Pause → „Speichern und zum Hauptmenü/beenden“,
  Fenster schließen); Tod = zurück an Tagesbeginn; 3 Speicherplätze; Hauptmenü mit Einstellungen, Steuerung,
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
- Leere Blechdosen nicht im Haus: alte Kühlbox im Wald westlich (`SupplyProps.COOLER_XZ`, CoolerCans, 8 Dosen, im Gras eingewachsen).

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
- Übersicht: `Babyfon` (Empfänger auf Stefanies Schreibtisch, Balken Kind/Dach/Keller, braucht Strom; Sender in den drei Räumen)
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
- Offen: Abstieg in den Brunnen (`flag:well_descended`) und die Enden – DataTest führt das als bekannt offen.
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
- Orte: Absturzstelle (-42,-30), fremde Struktur (-78, 40), Höhle am Bach (49, -72), Förster-Hochsitz (12, -80).
