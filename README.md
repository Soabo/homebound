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
| F2 | Retro-Filter ein/aus |
| F1 | Steuerungshilfe ein/aus |
| F11 | Vollbild |
| Esc | Pause / Beenden |

## So überlebst du die Nacht

- **Strom:** Der Generator im Technikraum braucht Benzin. Kanister liegen im Technikraum und im Schuppen.
  Ohne Strom gibt es kein Licht und keine Kameras. Manchmal fällt der Strom nachts aus – dann musst du rüber und neu starten.
- **Tür abschließen!** Eine nicht abgeschlossene Tür wird einfach aufgestoßen.
- **Fenster verbarrikadieren:** Bretter liegen in der Werkstatt (je Fenster 2 Bretter).
- **Kameras:** Am Monitor im Wohnzimmer siehst du Veranda, Garten hinten und Schuppen. Traue nicht allem, was du siehst.
- **Licht:** Die Taschenlampe verrät dich – aber aus der Nähe blendet sie.
- **Schlafen:** Ab 16 Uhr. Wenn nachts etwas passiert, schreckst du hoch.
- **Tod:** Du beginnst den Tag von vorn.

## Stand: Meilenstein 0.2

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
