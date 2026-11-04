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
| Shift | Rennen |
| Strg / C | Ducken |
| Leertaste | Springen |
| E / Linksklick | Benutzen (Türen, Lichtschalter, Bett) |
| R | Tür ab-/aufschließen, Fenster verbarrikadieren, Tür reparieren, Benzin nachfüllen |
| F | Taschenlampe |
| T (halten) | Zeit vorspulen – nur zum Testen |
| A / D (am Monitor) | Kamera wechseln |
| Tab / I | Inventar (essen, trinken, bauen, ablegen) |
| B | Baumodus: Bauteil wählen / weiter / beenden (R dreht, E setzt) |
| F2 | Retro-Filter ein/aus |
| F1 | Steuerungshilfe ein/aus |
| F11 | Vollbild |
| Esc | Pause / Beenden |

## So überlebst du die Nacht

- **Strom:** Der Generator im Technikraum braucht Benzin. Kanister liegen im Technikraum und im Schuppen.
  Ohne Strom gibt es kein Licht und keine Kameras. Manchmal fällt der Strom nachts aus – dann musst du rüber und neu starten.
- **Tür abschließen!** Eine nicht abgeschlossene Tür wird einfach aufgestoßen.
- **Fenster verbarrikadieren:** Bretter liegen in der Werkstatt (je Fenster 2 Bretter).
- **Kameras:** Am Monitor im Wohnzimmer siehst du die Hausfront mit Veranda, den Garten hinten und das Maisfeld am Schuppen. Traue nicht allem, was du siehst.
- **Licht:** Die Taschenlampe verrät dich – aber aus der Nähe blendet sie.
- **Schlafen:** Ab 16 Uhr. Wenn nachts etwas passiert, schreckst du hoch.
- **Tod:** Du beginnst den Tag von vorn.

## Tagsüber vorbereiten (Phase 6)

- **Axt** steckt im Hackklotz beim Schuppen. Damit hackst du **Holz** an umgestürzten Stämmen im Wald.
- **Steine** liegen am Bach, **Schrott, Benzin, Batterie, Elektronik** im alten Autowrack an der Zufahrt.
- **Werkbank** in der Werkstatt: Bretter, Nägel, Holzzaun, Spießbarrikade, Steinwall, Dosenalarm,
  Bewegungsmelder-Leuchte und eine verstärkte Haustür.
- **Bauen** (B): freies Platzieren auf dem Grundstück. Die Kreatur muss Zäune und Wälle erst zerlegen,
  Spieße verletzen sie, der Dosenalarm warnt dich, grelles Licht scheucht sie auf.
- **Hunger und Durst** sinken langsam: Konserven im Vorratsraum, trinken an Regentonne, Spüle oder Bach.
  Rennen kostet Ausdauer. Du kannst höchstens 40 kg tragen.
- Was du gebaut und verbarrikadiert hast, bleibt auch nach einem Tod erhalten (Stand: Tagesbeginn).

## Rund ums Haus

- **Maisfeld** neben dem Schuppen bis an den Zaun – trocken, dicht, mit Vogelscheuche. Man sieht nicht, was darin steht.
- **Benutzbares erkennen:** Zielst du aus der Nähe auf etwas Benutzbares, erscheint ein feiner Rahmen darum.
- **Symbole:** Zapfhahn auf Benzinkanistern und am Generator-Tank, „FOOD“ auf Konserven, Wassertropfen auf Wasserflaschen, „NAILS“ auf der Nagelkiste.

## Sound

- Schritte aus echten Aufnahmen: Holzboden, Teppich, Veranda, Gras, Waldboden, Kies (Zufahrt), Erde (Maisfeld),
  Steine (Bachufer) und flaches Wasser (Bach) – jeweils schleichen, gehen und rennen.
  Absprung und Landung klingen je nach Untergrund.
- Spieler: Essen, Trinken, Herzschlag bei Angst, schweres Atmen nach langem Rennen, Klick der Taschenlampe, Todesschrei.
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

- Begehbare Blockhütte mit Wohnzimmer (Kamin), Schlafzimmer, Vorratsraum, Technikraum und Werkstatt
- Veranda, Garten mit Zaun, Schuppen, Wald mit Hügeln und alter Zufahrtsstraße
- First-Person-Steuerung, Interaktion, abschließbare Haustür, Lichtschalter je Raum
- Tag-Nacht-Wechsel (10 Min. Tag / 10 Min. Nacht), Uhr, vereinfachtes Schlafen ab 16 Uhr
- Taschenlampe, Kaminfeuer, prozeduraler Wind
- Umgebungsdetails zur Vorgeschichte (GDD 3.1)

Nächste Schritte laut GDD-Roadmap: Generator & Strom, zerstörbare Fenster/Barrikaden,
Kamerasystem mit Monitor, erste Kreatur.

## Für Entwickler

Siehe [`CLAUDE.md`](CLAUDE.md) und [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).
