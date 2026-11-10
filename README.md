# HOMEBOUND

First-Person-Survival-Horror in einer abgelegenen Waldhütte.
Umgesetzt mit **Godot 4.7**. Das Game Design Document liegt unter [`docs/GDD.md`](docs/GDD.md).

## Spielen

- **Im Browser:** https://soabo.github.io/homebound/ (einfachere Grafik, ideal für schnelle Checks)
- **Windows (volle Grafik):** https://github.com/Soabo/homebound/releases/tag/neueste-version

Beides wird bei jeder Änderung automatisch neu gebaut.

## Windows-Version starten

1. Die ZIP-Datei mit dem aktuellen Build entpacken, z. B. nach `C:\Spiele\Homebound`.
2. `Homebound.exe` starten.
3. Falls Windows „Der Computer wurde durch Windows geschützt“ meldet:
   **Weitere Informationen → Trotzdem ausführen** (das Spiel ist nicht signiert).

## Steuerung

| Taste | Aktion |
|---|---|
| W A S D | Gehen |
| Shift | Rennen (nicht, wenn du überladen bist) |
| Alt | Langsam und leise gehen |
| Strg / C | Ducken |
| Leertaste | Springen |
| Y / X | Nach links / rechts lehnen (um Ecken schauen) |
| E | Benutzen (Türen, Lichtschalter, Bett); im Schrank/Spind: Tür auf/zu; Bärenfalle neu spannen |
| Linksklick | Gegenstand in der rechten Hand: Faust/Axt schlagen, mit der Blechschere zustechen, mit Axt Holz hacken, Konserve essen, Flasche trinken |
| Rechtsklick (halten) | Blocken mit Faust, Axt oder Blechschere |
| 1–9 / Mausrad | Schnellplatz wählen (leer = Faust) |
| R | Im Schrank/Spind: heraustreten; Tür ab-/aufschließen, Fenster verbarrikadieren, Tür reparieren, Benzin nachfüllen |
| F | Uhrlicht am linken Arm an/aus – gedrückt halten: zwischen LED-Lampe und weißem Display (schwaches Umgebungslicht) wechseln |
| Q (halten) | Mit dem Fernglas heranzoomen (wenn du eins gefunden hast) |
| M | Wanderkarte (wenn du sie gefunden hast) |
| T (halten) | Zeit vorspulen – nur zum Testen |
| A / D (am Monitor) | Kamera wechseln |
| Tab / I | Inventar (essen, trinken, bauen, ablegen); oben die Schnellplätze 1–9 – Gegenstände mit ✋ dorthin ziehen |
| B | Baumodus mit dem Bauhammer in der linken Hand: Bauteil wählen / weiter / beenden (R dreht, E oder Linksklick setzt) |
| F2 | Retro-Filter ein/aus |
| F1 | Steuerungshilfe ein/aus |
| F11 | Vollbild |
| Esc | Pause / Beenden |

## So überlebst du die Nacht

- **Strom:** Der Generator steht im Schuppen und braucht Benzin. Kanister liegen im Schuppen.
  Ohne Strom gibt es kein Licht und keine Kameras. Manchmal fällt der Strom nachts aus – dann musst du im Dunkeln raus zum Schuppen.
- **Verstecken:** Kleiderschrank im Schlafzimmer, Spind im Schuppen. E öffnet und schließt die Tür, R geht hinein
  und wieder hinaus. Bei geschlossener Tür bist du versteckt und siehst durch den Schlitz bzw. die Lamellen hinaus.
  Das Uhrlicht geht dabei aus und lässt sich drinnen nicht einschalten.
- **Holzkorb** vor dem Kamin: E nimmt Holz heraus, R legt Holz hinein (bis zu 4).
- **Tankanzeige** in der Werkstatt zeigt, wie viel Benzin noch im Generator im Schuppen ist.
- **Tür abschließen!** Eine nicht abgeschlossene Tür wird einfach aufgestoßen.
- **Fenster verbarrikadieren:** Bretter liegen in der Werkstatt (je Fenster 2 Bretter).
- **Kameras:** Drei nummerierte Überwachungskameras liegen in der Hütte (Werkbank, Esstisch, oben auf dem Kleiderschrank).
  Mit B (oder „Anbringen“ im Inventar) bringst du sie außen an Hütte oder Schuppen an, R schwenkt sie.
  Am Monitor im Wohnzimmer schaltest du mit A/D durch – leere Plätze zeigen „nicht installiert“. E an einer Kamera baut sie wieder ab.
  Traue nicht allem, was du siehst.
- **Licht:** Die Taschenlampe verrät dich – aber aus der Nähe blendet sie.
- **Schlafen:** Ab 16 Uhr. Wenn nachts etwas passiert, schreckst du hoch.
- **Tod:** Du beginnst den Tag von vorn.


## Die Kreatur

- Sie zeigt sich selten. Meist findest du nur Spuren: Abdrücke im Gras bis unter ein Fenster, Kratzer im Holz,
  Schritte auf dem Dach genau über dir, verstummte Tiere.
- Etwa jede dritte Nacht taucht sie auf – aber anders, als du denkst: reglos am Waldrand (schau direkt hin, und sie
  ist weg), als Gesicht am Fenster, nur auf der Kamera. Manchmal steht sie morgens im Haus, wenn du aufwachst.
- Erst nach einigen Nächten kommt sie ans Haus und prüft Türen und Fenster. Richtig gefährlich wird sie später.

## Tagsüber vorbereiten (Phase 6)

- **Axt** steckt im Hackklotz beim Schuppen. Sie landet auf einem Schnellplatz; nimm sie mit der Ziffer in die Hand
  und hacke mit Linksklick **Holz** an umgestürzten Stämmen im Wald.
- **Faust, Axt und Blechschere** verscheuchen die Kreatur (töten kann man sie nicht). Die Axt macht Hiebschaden
  (hinterlässt Gewebe), die Blechschere Stichschaden. Rechtsklick blockt Schläge von vorne.
- **Blechschere** hängt an der Werkzeugwand in der Werkstatt. Nur mit ihr bekommst du **Schrott** vom Autowrack.
- **Steine** liegen am Bach, **Benzin, Batterie, Elektronik** ebenfalls im alten Autowrack an der Zufahrt.
- **Werkbank** in der Werkstatt: Bretter, Nägel, Holzzaun, Spießbarrikade, Bärenfalle, Steinwall, Dosenalarm,
  Bewegungsmelder-Leuchte und eine verstärkte Haustür.
- **Bauen** (B): freies Platzieren auf dem Grundstück. Die Kreatur muss Zäune und Wälle erst zerlegen,
  Spieße verletzen sie (grünes Blut am Spieß = Blutprobe), Bärenfallen schnappen zu – auch bei dir! – und reißen
  ihr Gewebe heraus. Der Dosenalarm warnt dich, grelles Licht scheucht sie auf.
- **Hunger und Durst** sinken langsam: Konserven im Vorratsraum, trinken an Regentonne, Spüle oder Bach.
  Rennen kostet Ausdauer. Über 40 kg bist du überladen: du kannst noch alles aufnehmen, aber nur noch gehen.
- Was du gebaut und verbarrikadiert hast, bleibt auch nach einem Tod erhalten (Stand: Tagesbeginn).

## Forschung (Phase 7)

- **Absturzstelle** im Wald nordwestlich der Hütte – eine Rauchsäule zeigt tagsüber den Weg, das Radio gibt einen Hinweis.
  Dort liegen Metallfragmente, eine Energiezelle, eine Symbolplatte, Leuchtpilze, die Notiz eines Försters –
  und ein **fremdes Analysegerät** (12 kg).
- **Analysegerät:** An der Werkbank baust du das alte Funkgerät um (2 Elektronik, 1 Batterie, 2 Schrott).
  Es braucht Strom. Das fremde Gerät stellst du daneben auf – dann arbeitet es doppelt so schnell und ohne Strom.
- **Analysieren:** Fund einlegen, Zeit vergehen lassen und Experimente machen (unter Strom setzen, mit Licht
  bestrahlen, mit dem fremden Gerät öffnen/vergleichen). Manche Experimente haben Folgen – Strom flackert, es wird laut.
- **Gewebeprobe:** Triffst du die Kreatur mit der Axt, bleibt etwas zurück.
- **Alien-Archiv (Tablet auf der Couch, Reiter „Alien-Archiv“ und „Notizen“):** Ergebnisse schickst du am Analysegerät mit „Ergebnisse ans Tablet senden“. sechs Forschungsbereiche, Notizen, offene Fragen. Passende Analysen lassen sich
  **verknüpfen** – daraus entstehen Erkenntnisse und neue Baupläne:
  - **Resonanz-Sensor:** spürt die Kreatur auf über 25 m und meldet die Richtung.
  - **Stroboskop-Leuchte:** flackerndes Licht, das sie viel länger vertreibt als normales Licht.

## Das Tal verändert sich (Phase 8)

- Das Gebiet ist größer geworden (rund 200 × 200 m). Neue Orte:
  - **Fremde Struktur** weit im Westen: drei Beine, ein schwebender Kristall, drei Säulen. Die Säulen leuchten
    immer wieder in einer Reihenfolge auf – berühre sie in genau dieser Reihenfolge, dann schaltet sich die Struktur ab
    (das Tal verändert sich dann nur noch halb so schnell). Falsche Reihenfolge = Stromschlag.
  - **Förster-Hochsitz** im Norden: Leiter hoch (E), Vorräte, Tagebuch und eine Karte des Försters.
  - **Höhle am Bach** im Nordosten: ganz hinten pulsiert der **Knoten** des Organismus. Mit der Axt zerschlagen (6 Hiebe).
- **Terraforming** – je mehr Tage vergehen und je mehr du erforschst, desto weiter geht es:
  Stille im Wald und Pilzringe → fremde Pflanzen, kahle Bäume, Nebel → **verfärbtes Wasser** (nur noch mit
  Wasserfilter trinkbar, Werkbank) → schwebende Steine und Adern im Boden.
- **Neue Arten:**
  - **Drohne:** fliegt nachts in Bahnen über das Grundstück. Erfasst dich ihr Lichtkegel draußen, kommt die Kreatur.
    Grelles Licht (Stroboskop) bringt sie ins Taumeln – einmal verliert sie dabei ein Teil.
  - **Manipulator:** eine große, dünne Gestalt am Waldrand. Sie lockt dich mit Geräuschen hinaus (Spieluhr,
    Klopfen, Schritte, dein eigenes Atmen). Wer nachsieht, hat die Kreatur im Rücken.
  - **Organismus:** graue Wucherungen wachsen von der Höhle zur Hütte. Sie bremsen und verletzen dich –
    mit der Axt weghacken oder den Knoten in der Höhle zerstören.
- **Neue Baupläne** (über Verknüpfungen im Archiv): **Störsender** (Drohnen drehen ab) und **Myzel-Sperre**
  (Wucherungen sterben ab und wachsen dort nicht mehr).

## Die große Welt

- Rund um die Hütte liegt jetzt ein Gebiet von gut 2 x 2 km: Wald, Lichtungen, Berge, Seen, ein Hochmoor.
- Waldwege führen von der Hütte zu über 20 Orten, an Kreuzungen stehen Wegweiser mit Entfernungen.
- **Nah** (vor der Nacht zurück): alter Brunnen, Waldkapelle, Hochstand-Friedhof, Imkerei.
- **Tagesmarsch:** Messstelle 4-Nord, Funkmast am Kahlen Kopf, Schwarzer See, Steinbruch, Kontrollpunkt,
  Ferienlager, Schäferkarren, Hochmoor, Windwurf-Schneise, Lichtung der Spiegel.
- **Mehrtägig** (Zelt, Proviant, Wasser): Außenstelle Messpunkt 4, Berghütte, Tunnelportal, Versunkenes Dorf,
  Wetterstation am Grat, Gewächshäuser, Der Wal, Raststätte an der Autobahn.
- Dort liegen Vorräte, Notizen (Tablet → Notizen), Baupläne (danach an der Werkbank baubar) und neue Funde für die Forschung.
- Tiefes Wasser kann man nicht durchqueren, im Moor sinkt man abseits der Stege ein.
- **Kälte:** Nachts kühlt man draußen schnell aus (oben am Berg und nass noch schneller). Wärme gibt es in der Hütte
  am Kamin/Ofen, am Lagerfeuer (Bündel an der Werkbank bauen, draußen mit B aufstellen, R legt Holz nach) und im Zelt mit Schlafsack.
- **Die Nacht im Zelt:** E kriecht hinein, drinnen E schlafen, R hinaus. Licht im Zelt sieht man von weit her.
  Etwas kann ums Zelt schleichen – oder es aufreißen. Ein zerrissenes Zelt flickt man mit einem Brett und drei Nägeln.
- **Der Sucher:** hoch, dürr, viele kleine Lichter im Gesicht. Er sucht nach Licht und Lärm. Er tötet nicht – aber er findet dich.
- **W-17:** Im Umzugskarton unter dem Funktisch liegt ein Bauteil aus Stefanies Sachen. Ohne W-17 funktioniert das
  improvisierte Analysegerät nicht. Später kann man es ausbauen und mitnehmen – dann piept es in der Nähe bestimmter Orte.
  Aber Vorsicht: Der Sucher spürt es.

## Selbstversorgung und Aufgaben

- **Aufgaben** stehen auf dem Tablet (Couch, Reiter „Aufgaben“): Tagesroutine für heute und Ziele, die nach und nach dazukommen.
- **Hochbeete:** E sät (R wechselt die Samenart), gießt und erntet. Samen im Schuppenregal, Saatkartoffeln im Sack am Boden,
  die Gießkanne steht bei den Beeten (an Wasserhahn, Regentonne oder Bach mit R füllen). Ungegossen wächst nichts, nach 2 Tagen vertrocknet es.
- **Wasser:** Leere Flaschen (Küche) mit R füllen. Hahn = Trinkwasser, Regentonne/Bach = Rohwasser – lieber am Ofen abkochen.
- **Küchenofen:** E zündet ihn mit Holz an, dann E = kochen (braten, Suppe, Eintopf), R legt Holz nach. Auch über dem Kaminfeuer (R).
- **Schlinge** (Werkbank): im Wald aufstellen, morgens nachsehen – manchmal hängt ein Hase darin.
- **Generator-Wartung:** Ölwechsel (E) und Zündkerze (R) am Werkzeugbrett neben dem Generator. Später: Holzvergaser (mit Holz tanken)
  oder Zellen-Adapter (fremde Energiezelle).
- **Metall:** Im Wald liegen immer wieder alte Auspuffe, Motorblöcke, Silo- und Traktorteile – mit der Blechschere abbauen,
  danach sind sie weg. Nahe dem Autowrack öfter.

## Rund ums Haus

- **Maisfeld** neben dem Schuppen bis an den Zaun – trocken, dicht, mit Vogelscheuche. Man sieht nicht, was darin steht.
- **Benutzbares erkennen:** Zielst du aus der Nähe auf etwas Benutzbares, erscheint ein feiner Rahmen darum.
- **Symbole:** Zapfhahn auf Benzinkanistern und am Generator-Tank, „FOOD“ auf Konserven, Wassertropfen auf Wasserflaschen, „NAILS“ auf der Nagelkiste.

## Sound

- Schritte aus echten Aufnahmen: Holzboden, Teppich, Veranda, Gras, Waldboden, Kies (Zufahrt), Erde (Maisfeld),
  Steine (Bachufer) und flaches Wasser (Bach) – jeweils schleichen, gehen und rennen.
  Absprung und Landung klingen je nach Untergrund.
- Spieler: Essen, Trinken, Herzschlag bei Angst, schweres Atmen nach langem Rennen, Klick der Taschenlampe, Todesschrei.
- Haus und Umgebung aus echten Aufnahmen: Türen (öffnen, schließen, abschließen, Klinke rüttelt, aufbrechen),
  Klopfen, Glas, Bretter, knarrende Dielen, Bild fällt von der Wand, Wasserhahn und Tropfen, flackernde Lampe,
  Lichtschalter, Monitor und Kamerawechsel, Radio, Generator, Spieluhr, Kaminfeuer, Schritte auf dem Dach.
- Natur: Vögel, Grillen, Frösche am Bach, plätschernder Bach (wandert mit), Wind und Böen, Eulen, knackende Äste,
  bedrückende Stille, wenn etwas Fremdes nah ist. Eigene Klang-Akzente bei Abenddämmerung, Morgengrauen
  und wenn die Kreatur dich entdeckt.
- Bauen und Sammeln: Holz hacken, Steine und Metall sammeln, Aufheben, Abstellen, Werkbank, Dosenalarm,
  Bewegungsmelder, Zaun bricht. Menü-Klick und Rucksack öffnen.
- Die Kreatur: Klicken beim Beobachten, verzerrtes Atmen aus der Nähe, Knacken wenn der Kopf herumruckt,
  Schrei, Schmerzlaut an den Spießen, Zischen bei grellem Licht, eigene Schritte.

## Stand: Phase 5 – Atmosphäre und Horror

- Lebendige Natur: Vögel am Tag, Grillen und Eulen nachts – **verstummen sie, ist etwas in der Nähe**
- Mehrdeutige Ereignisse: Kratzen an der Wand, Schritte auf dem Dach, Klopfen ohne Besucher,
  rüttelnde Türklinke, flackerndes Licht, Radio springt an, Familienfoto fällt um, fremde Signale
- Der Manipulator: eine Spieluhr-Melodie im dunklen Wald lockt dich hinaus
- Handabdrücke mit drei langen Fingern an den Fenstern
- Kreatur: Kopf dreht sich ruckartig zu dir, Augen reflektieren dein Licht,
  der Beobachter ist weg, sobald du kurz wegschaust
- Herzschlag und dunkler Bildrand, wenn sie nah ist; Bildwackeln bei Schlägen

## Meilenstein 0.2

- Stromsystem mit Generator, Benzin und Stromausfällen
- Fenster und Haustür beschädigbar, Barrikaden und Reparatur mit Brettern
- Drei Überwachungskameras mit Monitor
- Threat Director: jede Nacht anders (ruhig, unheimlich, Erkundung, Angriff)
- Erste Kreatur mit Wahrnehmung (Sicht, Licht, Geräusch) und Lernverhalten
- Prozedurale Geräusche, Tod und Neustart am Tagesbeginn

## Meilenstein 0.1

- Begehbare Blockhütte mit Wohnzimmer (Kamin), Schlafzimmer, Vorratsraum, Badezimmer und Werkstatt; Generator im Schuppen
- Veranda, Garten mit Zaun, Schuppen, Wald mit Hügeln und alter Zufahrtsstraße
- First-Person-Steuerung, Interaktion, abschließbare Haustür, Lichtschalter je Raum
- Tag-Nacht-Wechsel (10 Min. Tag / 10 Min. Nacht), Uhr, vereinfachtes Schlafen ab 16 Uhr
- Taschenlampe, Kaminfeuer, prozeduraler Wind
- Umgebungsdetails zur Vorgeschichte (GDD 3.1)

Nächste Schritte laut GDD-Roadmap: Generator & Strom, zerstörbare Fenster/Barrikaden,
Kamerasystem mit Monitor, erste Kreatur.

## Für Entwickler

Siehe [`CLAUDE.md`](CLAUDE.md) und [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).
