# HOMEBOUND

First-Person-Survival-Horror in einer abgelegenen Waldhütte.
Umgesetzt mit **Godot 4.7**. Das Game Design Document liegt unter [`docs/GDD.md`](docs/GDD.md).

## Spielen (Windows)

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
| R | Tür ab- bzw. aufschließen |
| F | Taschenlampe |
| T (halten) | Zeit vorspulen – nur zum Testen |
| F1 | Steuerungshilfe ein/aus |
| F11 | Vollbild |
| Esc | Pause / Beenden |

## Stand: Meilenstein 0.1

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
