# HOMEBOUND
## Game Design Document (GDD)

**Version:** 1.0  
**Status:** Konzeptionsgrundlage  
**Genre:** First-Person Survival Horror / Base Building / Exploration / Research  
**Spielmodus:** Singleplayer (Koop als mögliche spätere Erweiterung)  
**Engine:** Unreal Engine 5  
**Arbeitstitel:** HOMEBOUND

---

# 1. HIGH CONCEPT

## 1.1 Spielbeschreibung

HOMEBOUND ist ein First-Person-Survival-Horror-Spiel, in dem der Spieler in einer abgelegenen Waldhütte lebt und sich gegen eine zunehmend bedrohliche außerirdische Präsenz behaupten muss.

Was zunächst wie ein abgelegenes, ruhiges Leben in der Natur wirkt, entwickelt sich langsam zu einem Albtraum.

Der Spieler sammelt Ressourcen, baut seine Unterkunft aus, errichtet Verteidigungsanlagen, erforscht außerirdische Technologien und untersucht die Veränderungen seiner Umgebung. Tagsüber erkundet er die nähere Umgebung und bereitet sich auf die Nacht vor.

Nachts wird das eigene Zuhause zum Mittelpunkt des Spiels.

Unbekannte Wesen bewegen sich durch den Wald. Geräusche sind zu hören. Etwas beobachtet die Hütte. Kameras zeigen Bewegungen, die der Spieler nicht einordnen kann. Strom fällt aus, Türen werden beschädigt und fremdartige Geräte beginnen plötzlich zu funktionieren.

Nicht jede Bedrohung lässt sich erschießen. Manche müssen überlistet, vertrieben, untersucht oder durch das Lösen einer ungewöhnlichen Aufgabe überwunden werden.

Im Verlauf des Spiels wird deutlich, dass die außerirdischen Aktivitäten nicht nur einzelne Angriffe darstellen. Die Umgebung verändert sich. Natur, Tiere und Landschaft werden zunehmend von fremdartigen Prozessen beeinflusst.

Der Spieler beginnt, diese Vorgänge zu erforschen und die dahinterliegenden Technologien zu verstehen.

Langfristig kann er seine ursprüngliche Heimat verlassen, neue Gebiete erschließen und an anderen Orten neue Stützpunkte errichten.

## 1.2 Das zentrale Spielerlebnis

Das wichtigste Ziel ist nicht, möglichst viele Gegner zu töten oder möglichst große Basen zu errichten.

Das zentrale Erlebnis lautet:

**Ein vertrauter, selbst gestalteter Rückzugsort wird zunehmend von einer unbekannten Bedrohung infiltriert. Der Spieler muss lernen, diese Bedrohung zu verstehen, bevor sie ihn überwältigt.**

Das Spiel soll folgende Gefühle erzeugen:

- Geborgenheit während der Vorbereitung am Tag.
- Anspannung, wenn die Dunkelheit hereinbricht.
- Angst vor Dingen, die der Spieler nicht sehen kann.
- Unsicherheit darüber, ob eine Begegnung gefährlich ist.
- Erleichterung, wenn eine Nacht überstanden wurde.
- Neugier auf neue Funde und außerirdische Technologien.
- Stolz auf die eigene Basis und deren Entwicklung.
- Das Gefühl, einer immer größeren Bedrohung langsam auf die Spur zu kommen.

## 1.3 Inspirationsquellen

Die folgenden Spiele dienen als Inspirationsquellen für einzelne Aspekte. HOMEBOUND soll daraus eine eigenständige Spielerfahrung entwickeln.

| Spiel | Inspiration |
|---|---|
| Project Zomboid | Survival, Ressourcenmanagement, Basisverteidigung |
| The Forest | Erkundung, Atmosphäre, unvorhersehbare Kreaturenbegegnungen |
| Sons of the Forest | Basenbau, Umgebung, technische Spielmechaniken |
| Five Nights at Freddy's | Kameras, gleichzeitige Bedrohungen, Beobachtung und Entscheidungsdruck |
| XCOM | Umfangreiches Forschungs- und Analysesystem |

---

# 2. DESIGN-PHILOSOPHIE

## 2.1 Qualität vor Weltgröße

HOMEBOUND soll keine riesige, generische Open World werden.

Die Spielwelt darf bewusst kompakt sein. Dafür sollen Umgebung, Sounddesign, Gegnerverhalten und Interaktionsmöglichkeiten besonders detailliert ausgearbeitet werden.

Ein kleiner Waldabschnitt mit glaubwürdigen Kreaturen, interessanten Ereignissen und einer starken Atmosphäre ist wertvoller als eine riesige, aber weitgehend leere Spielwelt.

## 2.2 Das Zuhause als emotionaler Mittelpunkt

Die eigene Basis ist mehr als ein funktionales Gebäude.

Sie soll sich mit der Zeit wie ein echtes Zuhause anfühlen. Der Spieler kennt jeden Raum, jede Tür und jedes Fenster. Er hat Möbel aufgestellt, Gegenstände gesammelt und Verteidigungsanlagen errichtet.

Gerade deshalb ist es besonders wirkungsvoll, wenn die Bedrohung in diesen vertrauten Bereich eindringt.

Das Haus darf niemals vollständig sicher sein.

## 2.3 Ungewissheit statt permanenter Action

Nicht jede Nacht muss ein Angriff stattfinden.

Manchmal hört der Spieler lediglich etwas im Wald. Manchmal steht eine Gestalt minutenlang zwischen den Bäumen. Manchmal ist auf einer Kamera etwas zu erkennen, das beim direkten Nachsehen verschwunden ist.

Andere Nächte können dagegen sehr gefährlich werden.

Die Unvorhersehbarkeit ist ein wesentlicher Bestandteil des Horrors.

## 2.4 Bedrohungen mit unterschiedlichen Lösungen

Nicht jede außerirdische Lebensform soll bekämpft werden können oder müssen.

Mögliche Reaktionen:

- Kämpfen
- Verstecken
- Flüchten
- Türen und Fenster sichern
- Fallen aufstellen
- Licht und Strom gezielt einsetzen
- Außerirdische Geräte manipulieren
- Rätsel und technische Aufgaben lösen
- Verhalten beobachten und daraus lernen

Der Spieler soll Situationen verstehen und Entscheidungen treffen, statt ausschließlich auf Gegner zu schießen.

## 2.5 Wissen ist Macht

Forschung ist eine der zentralen Spielmechaniken.

Der Spieler soll nicht einfach immer bessere Waffen herstellen. Er soll verstehen, was in seiner Umgebung passiert.

Neue Erkenntnisse ermöglichen neue Technologien, Verteidigungsmaßnahmen, Werkzeuge und Möglichkeiten zur Interaktion mit der außerirdischen Welt.

---

# 3. SPIELWELT UND UMGEBUNG

## 3.1 Ausgangssituation

Das Spiel beginnt in einer abgelegenen Blockhütte im Wald.

Der Spieler hat sich bewusst für ein zurückgezogenes Leben entschieden. Er wollte Abstand von der Gesellschaft gewinnen und sich in der Natur ein neues Leben aufbauen.

Er ist kein Soldat, kein Wissenschaftler und kein ausgebildeter Überlebenskünstler.

Er ist ein gewöhnlicher Mensch.

Seine Frau und seine Kinder sind bei einem Autounfall ums Leben gekommen. Diese Vergangenheit soll nicht durch lange Zwischensequenzen erklärt werden, sondern durch Umgebungsdetails.

Beispiele:

- Familienfotos
- Kinderzeichnungen
- Ein altes Familienbild am Bett
- Unbenutzte Teller
- Ein nicht ausgepacktes Geburtstagsgeschenk
- Persönliche Gegenstände der verstorbenen Familienmitglieder

Die Vergangenheit des Spielers soll emotional spürbar sein, ohne ständig thematisiert zu werden.

## 3.2 Das erste Spielgebiet

Das erste Gebiet besteht aus:

- Blockhütte
- Garten und Grundstück
- Kleinem Schuppen
- Wald
- Kleinem Bach
- Lichtung
- Erhöhtem Gelände beziehungsweise Plateau
- Alter Zufahrtsstraße
- Natürlichen Böschungen und Hügeln

Die Umgebung soll kompakt, handgebaut und wiedererkennbar sein.

Die Topografie soll auch spielerisch relevant sein. Beispielsweise können Böschungen als natürliche Verteidigung dienen, während der Wald Sichtlinien unterbricht und Kreaturen Deckung bietet.

## 3.3 Das Haus

Das Haus besitzt fest definierte Räume.

Mögliche Raumaufteilung:

- Wohnzimmer mit Kamin und zentralem Aufenthaltsbereich
- Schlafzimmer
- Werkstatt
- Vorratsraum
- Technikraum mit Generator und Stromversorgung
- Möglicher versteckter Sicherheitsraum

Die Räume können funktional erweitert und eingerichtet werden.

Die bauliche Grundstruktur des Hauses bleibt zunächst fest. Der Spieler kann dagegen das Grundstück und den Garten relativ frei gestalten.

## 3.4 Das Grundstück

Das Grundstück ist frei bebaubar.

Mögliche Elemente:

- Zäune
- Barrikaden
- Fallen
- Beleuchtung
- Kameras
- Generatoren
- Lagerflächen
- Werkstätten
- Verteidigungsanlagen
- Wasseraufbereitung
- Technische Geräte

Die Platzierung soll strategische Entscheidungen ermöglichen.

Der Spieler muss beispielsweise entscheiden, ob er einen Bereich beleuchtet, eine Kamera installiert oder eine physische Barriere errichtet.

## 3.5 Die Welt außerhalb des Grundstücks

Die unmittelbare Umgebung ist das erste große Erkundungsgebiet.

Später sollen weitere Regionen erreichbar werden. Dafür können auch Fahrzeuge eine Rolle spielen.

Neue Gebiete können eigene Episoden beziehungsweise größere Spielabschnitte darstellen.

Ein Beispiel für eine mögliche Struktur:

1. Waldhütte – erste Begegnungen und Überleben.
2. Verlassener Außenposten – erweiterte technische Möglichkeiten.
3. Sperrgebiet – massive Terraforming-Aktivitäten und stärkere Alien-Präsenz.
4. Weiter entfernte Region – neue Erkenntnisse über die außerirdischen Aktivitäten.

Diese Episodenstruktur ist eine mögliche Entwicklungsrichtung und noch keine endgültig festgelegte Story.

## 3.6 Terraforming

Die Aliens verändern nicht nur Gebäude und technische Infrastruktur. Sie beeinflussen auch die Natur.

Terraforming soll zunächst subtil beginnen und später deutlicher werden.

Mögliche Veränderungen:

- Pflanzen wachsen in geometrischen Mustern.
- Bäume entwickeln symmetrische, unnatürliche Strukturen.
- Baumrinde verschwindet über Nacht.
- Insekten verschwinden aus bestimmten Gebieten.
- Tiere verlassen ihre bisherigen Lebensräume.
- Wasser wird verfärbt oder verunreinigt.
- Nebel bewegt sich entgegen der Windrichtung.
- Organische Netzwerke entstehen unter der Erdoberfläche.
- Fremdartige Pflanzenarten breiten sich aus.
- Lokale Schwerkraftanomalien verändern das Verhalten von Gegenständen.
- Neue biologische Ökosysteme entstehen.

Terraforming ist nicht nur ein optischer Effekt.

Veränderungen der Umwelt können sich auf Ressourcen, Wasserqualität, Tierverhalten, Sichtverhältnisse und die Sicherheit des Spielers auswirken.

Der World State Manager muss diese Veränderungen zentral verwalten.

---

# 4. SPIELSTRUKTUR UND ZEITSYSTEM

## 4.1 Tag und Nacht

Der Tages- und Nachtzyklus ist ein zentraler Bestandteil des Spiels.

Zielwerte für die normale Spielgeschwindigkeit:

| Phase | Dauer |
|---|---:|
| Tag | ca. 10 Minuten |
| Nacht | ca. 10 Minuten |

Die Zeiten sind zunächst Richtwerte und sollen später konfigurierbar sein.

## 4.2 Tagesphase

Tagsüber stehen folgende Aktivitäten im Mittelpunkt:

- Ressourcen sammeln
- Umgebung erkunden
- Gegenstände untersuchen
- Forschung betreiben
- Werkzeuge herstellen
- Basis ausbauen
- Verteidigungsanlagen reparieren
- Stromversorgung sicherstellen
- Nahrung und Wasser organisieren
- Auf die nächste Nacht vorbereiten

Der Tag soll sich vergleichsweise ruhig und sicher anfühlen.

Allerdings ist auch tagsüber keine vollständige Sicherheit garantiert.

## 4.3 Nachtphase

Nachts steigt die Gefahr deutlich.

Mögliche Ereignisse:

- Kreaturen bewegen sich durch den Wald.
- Unbekannte Geräusche sind zu hören.
- Wesen beobachten das Haus.
- Türen und Fenster werden untersucht.
- Verteidigungsanlagen werden angegriffen.
- Stromversorgung fällt aus.
- Kameras werden gestört.
- Außerirdische Geräte werden aktiviert.
- Fremdartige Signale treten auf.
- Kreaturen versuchen, in das Gebäude einzudringen.

Nicht jede Nacht muss einen direkten Angriff enthalten.

## 4.4 Schlafsystem

Der Spieler kann ab dem Nachmittag schlafen.

Er kann selbst bestimmen, wann er schlafen geht und wann er wieder aufwachen möchte.

Beispiele:

- Schlafen ab 18:00 Uhr bis 22:00 Uhr.
- Schlafen ab 20:00 Uhr bis Mitternacht.
- Schlafen ab Mitternacht bis zum Sonnenaufgang.

Die Nacht kann auch ohne Schlaf erlebt werden.

Wird der Spieler während des Schlafens gestört, kann er jederzeit aufwachen.

Beispiel:

Der Spieler schläft. Um 02:17 Uhr hört er plötzlich heftiges Klopfen an der Haustür. Er wacht auf. Der Strom ist ausgefallen.

Schlaf ist damit eine strategische Entscheidung und keine bloße Zeitbeschleunigung.

## 4.5 Jahreszeiten

Ein Jahreszeitensystem ist für die spätere Architektur vorgesehen.

Mögliche Auswirkungen:

**Sommer**
- Längere Tage
- Dichte Vegetation
- Gute Sichtverhältnisse in bestimmten Bereichen

**Herbst**
- Kürzere Tage
- Nebel und Regen
- Veränderte Geräuschkulisse

**Winter**
- Schnee
- Kälte
- Höherer Energiebedarf
- Eingeschränkte Beweglichkeit

**Frühling**
- Neue Vegetation
- Schmelzwasser
- Veränderte Ressourcenverfügbarkeit

Jahreszeiten müssen nicht im ersten Prototyp enthalten sein. Das Zeitsystem soll aber so entwickelt werden, dass sie später ergänzt werden können.

---

# 5. SPIELLOOP

## 5.1 Hauptspielschleife

Die zentrale Spielschleife besteht aus vier miteinander verbundenen Phasen:

**1. Erkunden**

Der Spieler verlässt seine Basis, untersucht die Umgebung, sammelt Ressourcen und entdeckt außerirdische Spuren.

**2. Analysieren und Vorbereiten**

Gefundene Gegenstände werden untersucht. Neue Erkenntnisse ermöglichen Technologien und Baupläne. Der Spieler verbessert seine Basis und bereitet sich auf die Nacht vor.

**3. Überleben**

Nachts muss der Spieler auf Ereignisse reagieren. Er beobachtet Kameras, hört Geräusche, sichert das Haus und entscheidet, ob er kämpfen, fliehen, sich verstecken oder ein Problem anderweitig lösen muss.

**4. Weiterentwickeln**

Nach einer überstandenen Nacht werden Schäden repariert, neue Erkenntnisse ausgewertet und die nächsten Erkundungsziele geplant.

Dieser Kreislauf bildet das Rückgrat des Spiels.

## 5.2 Langfristiger Fortschritt

Der Spieler entwickelt sich auf mehreren Ebenen:

- Bessere Ausrüstung
- Größere technische Möglichkeiten
- Verbesserte Verteidigungsanlagen
- Neue Forschungskenntnisse
- Neue Baupläne
- Verständnis verschiedener Spezies
- Erkenntnisse über die Terraforming-Prozesse
- Erschließung weiterer Gebiete

Der Fortschritt soll nicht ausschließlich über klassische Charakterlevel erfolgen.

Wissen, Ausrüstung und die Entwicklung der Basis sind wichtiger.

---

# 6. SURVIVAL-SYSTEM

## 6.1 Grundwerte

Vorgesehene Spielerwerte:

- Gesundheit
- Ausdauer
- Verletzungen
- Hunger
- Durst
- Inventarkapazität

Hunger und Durst sollen keine lästige Daueraufgabe darstellen.

Sie sollen nur dann relevant werden, wenn daraus interessante Entscheidungen entstehen.

Beispielsweise kann eine längere Erkundungstour eine gute Vorbereitung erfordern.

## 6.2 Ressourcen

Mögliche Ressourcen:

- Holz
- Metall
- Steine
- Stoffe
- Elektronik
- Treibstoff
- Batterien
- Wasser
- Nahrung
- Medizinische Materialien
- Außerirdische Materialien

Ressourcen werden für Bau, Reparatur, Crafting und Forschung verwendet.

## 6.3 Inventar

Der Spieler besitzt ein begrenztes Inventar.

Gegenstände können unterschiedliche Eigenschaften besitzen:

- Gewicht beziehungsweise Platzbedarf
- Kategorie
- Zustand
- Verwendungszweck
- Forschungsrelevanz
- Technologische Eigenschaften

Einige Gegenstände können zunächst keinen erkennbaren Nutzen haben.

Sie sollen trotzdem aufbewahrt und später neu untersucht werden können.

---

# 7. BASE BUILDING UND VERTEIDIGUNG

## 7.1 Grundprinzip

Die Basis ist ein zentraler Bestandteil des Spiels.

Der Spieler soll seine Unterkunft funktional und optisch weiterentwickeln können.

Das Haus selbst besitzt feste Räume. Das Grundstück und der Garten sind dagegen frei bebaubar.

## 7.2 Bau- und Verteidigungselemente

Mögliche Bauobjekte:

- Holzzäune
- Metallzäune
- Barrikaden
- Verstärkte Türen
- Fensterverstärkungen
- Fallen
- Beleuchtung
- Bewegungsmelder
- Kameras
- Alarmsysteme
- Generatoren
- Batterien
- Technische Verteidigungsanlagen

## 7.3 Zerstörbarkeit

Die Basis ist physisch angreifbar.

Folgende Elemente können beschädigt oder zerstört werden:

- Fenster
- Türen
- Barrikaden
- Zäune
- Fallen
- Generatoren
- Kameras
- Technische Anlagen

Schäden sollen sichtbar und nachvollziehbar sein.

Eine beschädigte Tür darf nicht einfach wieder automatisch intakt sein.

Der Spieler muss sie reparieren oder ersetzen.

## 7.4 Stromversorgung

Die Stromversorgung ist eine wichtige Gameplay-Komponente.

Mögliche Bestandteile:

- Generator
- Treibstoff
- Batterien
- Sicherungen
- Stromleitungen
- Verbraucher
- Beleuchtung
- Kameras
- Technische Geräte

Der Spieler muss mit begrenzter Energie haushalten.

Ein Stromausfall kann eine Nacht erheblich gefährlicher machen.

## 7.5 Überwachungssystem

Kameras sind eine der wichtigsten Verteidigungs- und Horror-Mechaniken.

Der Spieler kann mehrere Kameras auf dem Grundstück und im Haus installieren.

Die Kameras werden über einen Monitor beziehungsweise eine zentrale Überwachungsstation betrachtet.

Mögliche Funktionen:

- Umschalten zwischen Kameras
- Beobachten von Eingängen
- Überwachung des Gartens
- Erkennen von Bewegungen
- Erkennen bestimmter Anomalien

Kameras können beschädigt, manipuliert oder gestört werden.

Besonders wichtig: Die Kameras dürfen nicht immer verlässliche Informationen liefern.

Beispiele:

- Eine Gestalt steht am Waldrand.
- Eine Kamera zeigt kurz eine Bewegung.
- Ein Wesen ist auf der Kamera zu sehen, aber beim Blick aus dem Fenster nicht mehr vorhanden.
- Eine Kamera zeigt ein Objekt, das sich scheinbar gegen die normale Physik bewegt.
- Die Übertragung wird durch ein unbekanntes Signal gestört.

Das Kamerasystem soll den Spieler zu Entscheidungen zwingen.

Wenn mehrere Ereignisse gleichzeitig auftreten, kann er nicht überall sein.

---

# 8. BEDROHUNGSSYSTEM UND SCHWIERIGKEIT

## 8.1 Grundprinzip

Die Schwierigkeit steigt langfristig an, aber nicht gleichmäßig.

Es soll ruhige Nächte und unerwartet gefährliche Nächte geben.

Die Spannung entsteht aus einer Kombination aus:

1. Langfristig steigendem Bedrohungsniveau.
2. Individueller Intensität der jeweiligen Nacht.
3. Fortschreitendem Zustand der außerirdischen Weltveränderung.

Diese drei Werte müssen unabhängig voneinander verwaltet werden.

## 8.2 Threat Level

Das Threat Level beschreibt die langfristige Grundbedrohung.

Es kann beispielsweise beeinflusst werden durch:

- Vergangene Spieltage
- Fortschritt der außerirdischen Aktivitäten
- Erkundungsfortschritt
- Bestimmte Ereignisse
- Fortschritt der Story

Es beeinflusst unter anderem, welche Arten von Ereignissen und Gegnern grundsätzlich möglich sind.

## 8.3 Night Intensity

Die Night Intensity beschreibt die Intensität einer einzelnen Nacht.

Sie wird dynamisch bestimmt.

Beispiele:

- Sehr ruhige Nacht
- Ungewöhnliche Geräusche
- Beobachtende Kreatur
- Einzelner Angriff
- Mehrere gleichzeitige Ereignisse
- Schwere Angriffsnacht

Eine hohe Night Intensity darf auch früh im Spiel vorkommen.

Eine niedrige Night Intensity ist auch später möglich.

## 8.4 Threat Director

Der Threat Director ist das zentrale System zur Auswahl und Koordination von Bedrohungsereignissen.

Er entscheidet beispielsweise:

- Welche Ereignisse stattfinden
- Wann sie stattfinden
- Welche Ereignisse kombiniert werden
- Welche Intensität eine Nacht besitzt
- Welche Gegner grundsätzlich erscheinen dürfen
- Welche Bedingungen ein Ereignis erfüllen muss

Der Threat Director steuert jedoch nicht direkt die Bewegungs- und Kampf-KI der Kreaturen.

Diese Aufgaben gehören in die jeweiligen Alien-AI-Systeme.

## 8.5 Ereignisse

Mögliche Ereignisse:

- Eine Kreatur beobachtet das Haus.
- Eine Kreatur untersucht die Verteidigung.
- Ein Stromausfall tritt auf.
- Ein unbekanntes Signal wird empfangen.
- Ein Wesen bewegt sich um das Haus.
- Ein Tier verhält sich ungewöhnlich.
- Eine Kamera wird gestört.
- Eine fremdartige Drohne scannt das Grundstück.
- Mehrere Kreaturen nähern sich aus verschiedenen Richtungen.
- Ein außerirdisches Gerät wird aktiviert.
- Eine Kreatur versucht, den Spieler nach draußen zu locken.

Ereignisse sollen unterschiedliche Reaktionen erfordern.

Nicht jede Situation muss in einen Kampf münden.

---

# 9. ALIEN-SYSTEM UND GEGNER-KI

## 9.1 Grundprinzip

Die Gegner sind außerirdische Lebensformen und Technologien.

Sie sollen sich nicht wie gewöhnliche Videospielmonster verhalten.

Einige sind aggressiv. Andere beobachten den Spieler oder verfolgen eigene Ziele.

Nicht jede Begegnung muss feindlich enden.

## 9.2 Spezies

Geplante Arten:

- Klassische Greys
- Besondere humanoide Grey-Varianten
- Andere, deutlich unterschiedliche außerirdische Spezies
- Biologische Kreaturen
- Organismen und fremdartige Lebensformen
- Technologische Einheiten
- Drohnen und Roboter
- Autonome Systeme und künstliche Lebensformen

Die genaue Anzahl und Ausgestaltung der Spezies ist noch offen.

## 9.3 Verhaltensarchetypen

Die folgenden Archetypen dienen als erste Grundlage.

**Observer – Beobachter**

- Hält sich zunächst auf Distanz.
- Beobachtet den Spieler.
- Verschwindet möglicherweise, wenn er entdeckt wird.
- Kann später näher kommen.
- Greift nicht zwingend an.

**Hunter – Jäger**

- Aggressiv
- Schnell
- Reagiert auf Licht und Geräusche.
- Kann Türen und Barrikaden angreifen.
- Versucht, den Spieler zu verfolgen.

**Manipulator – Manipulator**

- Erzeugt falsche Geräusche.
- Kann menschliche Stimmen imitieren.
- Beeinflusst möglicherweise Kameras.
- Versucht, den Spieler aus der sicheren Basis zu locken.
- Arbeitet mit Täuschung und psychologischem Druck.

Diese Archetypen sind keine endgültigen Spezies. Unterschiedliche Kreaturen können Elemente mehrerer Verhaltensweisen kombinieren.

## 9.4 Wahrnehmung

Kreaturen sollen den Spieler über unterschiedliche Sinne wahrnehmen können.

Mögliche Wahrnehmungssysteme:

- Sicht
- Geräusche
- Licht
- Bewegung
- Gerüche
- Wärme
- Elektrische oder elektromagnetische Signaturen

Nicht jede Spezies muss dieselben Wahrnehmungsfähigkeiten besitzen.

## 9.5 Lernverhalten

Einige Gegner können aus dem Verhalten des Spielers lernen.

Beispiel:

Der Spieler blockiert wiederholt den Haupteingang. Eine intelligente Kreatur beginnt, andere Zugänge zu untersuchen.

Dieses Verhalten muss glaubwürdig und nachvollziehbar bleiben.

Nicht jeder Gegner soll intelligent sein.

## 9.6 Sound als Gameplay-Mechanik

Sound ist ein entscheidender Bestandteil des Gegnersystems.

Der Spieler soll Kreaturen oft hören, bevor er sie sieht.

Beispiele:

- Schritte im Laub
- Knacken von Ästen
- Ungewöhnliche Atemgeräusche
- Kratzen an der Hauswand
- Geräusche auf dem Dach
- Fremdartige Stimmen
- Geräusche aus dem Wald
- Metallische oder elektronische Signale

Sound darf bewusst mehrdeutig sein.

Der Spieler soll nicht immer wissen, ob ein Geräusch tatsächlich eine Bedrohung darstellt.

---

# 10. KAMPF UND KONFLIKTLÖSUNG

## 10.1 Grundprinzip

Der Kampf ist eine Mischung aus direkten und indirekten Verteidigungsmöglichkeiten.

Mögliche Optionen:

- Nahkampfwaffen
- Schusswaffen
- Fallen
- Barrikaden
- Verteidigungsanlagen
- Flucht
- Verstecken
- Täuschung
- Technische Gegenmaßnahmen

Munition und Ressourcen sollen begrenzt sein.

## 10.2 Nicht besiegbare Bedrohungen

Einige Wesen sollen nicht einfach durch genügend Schaden besiegt werden können.

Der Spieler muss möglicherweise:

- Ein bestimmtes Gerät deaktivieren.
- Eine Energiequelle unterbrechen.
- Ein Signal stören.
- Eine bestimmte Frequenz erzeugen.
- Eine Umgebungsvorrichtung manipulieren.
- Sich unbemerkt an einem Wesen vorbeibewegen.

Dadurch bleiben auch spätere Begegnungen spannend.

---

# 11. ANOMALIEN UND NÄCHTLICHE RÄTSEL

## 11.1 Grundprinzip

Ein Teil der nächtlichen Ereignisse soll nicht durch Kampf gelöst werden.

Stattdessen muss der Spieler ungewöhnliche Vorgänge untersuchen und durch Interaktionen oder technische Aufgaben bewältigen.

Diese Situationen sollen aus der Spielwelt heraus entstehen.

Sie dürfen nicht wie beliebige Minispiele wirken.

## 11.2 Beispielereignisse

**Fremdartiges Signal**

Mehrere unbekannte Sender erzeugen ein Signal. Der Spieler muss die Quelle finden und die Sender in der richtigen Reihenfolge deaktivieren.

**Energieanomalie**

Ein fremdes Gerät entzieht der Basis Energie. Der Spieler muss den Stromfluss untersuchen und umleiten.

**Frequenzreaktion**

Eine Kreatur reagiert auf bestimmte Licht- oder Tonfrequenzen. Der Spieler muss herausfinden, welche Frequenz sie vertreibt.

**Gravitationsstörung**

Gegenstände bewegen sich unnatürlich. Der Spieler muss mehrere Generatoren oder Feldgeräte neu ausrichten.

**Drohnenüberwachung**

Eine Drohne scannt das Grundstück. Der Spieler muss Sichtlinien vermeiden, Sensoren täuschen oder die Drohne deaktivieren.

**Biologische Kontamination**

Ein fremdartiger Organismus breitet sich aus. Der Spieler muss die Quelle finden und die Ausbreitung stoppen.

## 11.3 Verbindung mit Forschung

Die Rätsel sollen mit vorherigen Entdeckungen verbunden sein.

Beispiel:

Tagsüber findet der Spieler ein inaktives außerirdisches Gerät. Er untersucht drei Energieanschlüsse, versteht aber noch nicht deren Funktion.

Einige Nächte später wird das Gerät aktiviert.

Durch seine vorherigen Untersuchungen weiß der Spieler bereits, wie er reagieren kann.

Erkundung und Forschung zahlen sich dadurch unmittelbar im Überlebenskampf aus.

---

# 12. FORSCHUNG UND ALIEN-ARCHIV

## 12.1 Bedeutung

Die Forschung ist eine der vier zentralen Säulen des Spiels.

Sie soll ein umfangreiches System darstellen, das in seiner Tiefe an XCOM erinnert.

Der Spieler untersucht außerirdische Gegenstände, biologische Proben, technische Systeme, Spezies und fremdartige Energiephänomene.

Die Forschung ist kein kleiner Zusatz zum Crafting, sondern ein eigenständiger Progressionspfad.

## 12.2 Forschungsbereiche

Geplant sind sechs Hauptbereiche:

**1. Technologie**

- Geräte
- Sensoren
- Energieversorgung
- Kommunikation
- Maschinen
- Elektronik
- Schaltkreise

**2. Biologie**

- Gewebe
- Organismen
- Mutationen
- Außerirdische Pflanzen
- Biologische Waffen
- Fremdartige Lebensformen

**3. Energie und Physik**

- Unbekannte Energiequellen
- Gravitationsanomalien
- Strahlung
- Raumphänomene
- Energiespeicherung

**4. Spezies und Verhalten**

- Anatomie
- Wahrnehmung
- Kommunikation
- Verhaltensweisen
- Schwachstellen
- Beziehungen zwischen Spezies

**5. Raumfahrt und Infrastruktur**

- Schiffsteile
- Antriebssysteme
- Navigation
- Drohnen
- Außerirdische Gebäude
- Technische Infrastruktur

**6. Zusammenhänge**

- Verbindungen zwischen Artefakten
- Gemeinsame Technologien
- Beziehungen zwischen Spezies
- Hinweise auf Ereignisse
- Hypothesen über die außerirdischen Aktivitäten

## 12.3 Forschungsobjekte

Mögliche Fundstücke:

- Metallfragmente
- Energiezellen
- Organisches Gewebe
- Veränderte Pflanzen
- Technische Bauteile
- Kommunikationsgeräte
- Waffen
- Wrackteile
- Flüssigkeiten
- Werkzeuge
- Persönliche Gegenstände
- Unbekannte Materialien
- Abfälle und Überreste

Nicht jedes Objekt muss sofort einen Nutzen haben.

Manche Funde werden erst durch spätere Erkenntnisse verständlich.

## 12.4 Analyse

Der Spieler soll Gegenstände aktiv untersuchen können.

Mögliche Untersuchungsmethoden:

- Materialanalyse
- Energiemessung
- Strahlungsmessung
- Zerlegen
- Vergleichen
- Kombinieren
- Funktionstests
- Untersuchung unter besonderen Bedingungen

Die Forschung soll nicht ausschließlich aus einem Timer bestehen.

Sie soll aus einer Mischung aus passiver Analyse und aktiven Experimenten bestehen.

## 12.5 Forschungsgerät

Da der Spieler ein gewöhnlicher Mensch ist, benötigt er eine glaubwürdige Möglichkeit, außerirdische Funde zu analysieren.

Eine mögliche Lösung ist ein gefundenes außerirdisches Analysegerät.

Dieses Gerät kann:

- Materialien erkennen
- Energie messen
- Strukturen untersuchen
- Symbole vergleichen
- Bauteile kategorisieren
- Erkenntnisse speichern
- Mit bestimmten außerirdischen Geräten kommunizieren

Im weiteren Spielverlauf kann es in die eigene Werkstatt beziehungsweise ein Labor integriert werden.

## 12.6 Alien-Archiv

Das Alien-Archiv ist die zentrale Wissensdatenbank des Spielers.

Es speichert:

- Gefundene Objekte
- Forschungsfortschritte
- Analysen
- Hypothesen
- Spezies
- Technologien
- Fundorte
- Verbindungen zwischen Entdeckungen
- Offene Fragen

Das Archiv soll auch die Möglichkeit bieten, Erkenntnisse miteinander zu verknüpfen.

Beispiel:

Ein beschädigter Drohnenantrieb wird mit einem unbekannten Metallfragment und einem Bauteil aus einem Wrack verglichen.

Die Kombination führt zu einer Erkenntnis über die Energieversorgung der Drohne.

Daraus kann später ein eigener Sensor entwickelt werden.

## 12.7 Forschungsergebnisse

Forschung kann freischalten:

- Baupläne
- Neue Werkzeuge
- Energieversorgung
- Sensoren
- Überwachungstechnik
- Verteidigungsanlagen
- Waffen
- Fallen
- Neue Analysemöglichkeiten
- Interaktionen mit außerirdischen Geräten

Baupläne sollen überwiegend durch außerirdische Funde und deren Untersuchung entstehen.

Weitere Freischaltmöglichkeiten sind denkbar.

Die genaue Verteilung wird später konkretisiert.

---

# 13. STORY UND WELTHINTERGRUND

## 13.1 Erzählweise

Die Geschichte soll sich langsam und indirekt entfalten.

Zu Beginn soll der Spieler nicht wissen, was tatsächlich passiert.

Die Welt zeigt lediglich zunehmende Anzeichen einer ungewöhnlichen Entwicklung.

## 13.2 Hintergrundinformationen

Mögliche Hinweise:

- Zunehmende UFO-Sichtungen
- Vermisste Personen
- Menschen mit verstümmelten Körpern
- Ungewöhnliche politische Entscheidungen
- Verdächtige Veränderungen bei Politikern und anderen öffentlichen Personen
- Militärische Aktivitäten
- Stromausfälle
- Gesellschaftliche Unruhe
- Veränderungen in der Natur
- Ungewöhnliche Lichter am Himmel

Diese Informationen werden über die Spielwelt vermittelt.

Mögliche Medien:

- Radio
- Fernsehen
- Zeitungen
- Internetterminals
- Fundstücke
- Gespräche und Aufzeichnungen
- Militärische Funksprüche
- Sichtbare Ereignisse in der Ferne

## 13.3 Offene Storyfragen

Die folgenden Fragen sind bewusst noch nicht festgelegt:

- Warum sind die Aliens auf der Erde?
- Handelt es sich um eine Invasion, Forschung, Besiedlung oder etwas völlig anderes?
- Gibt es mehrere außerirdische Zivilisationen?
- Welche Beziehungen bestehen zwischen den Spezies?
- Warum wird die Erde verändert?
- Welche Rolle spielt der Spieler langfristig?

Die Antworten sollen erst in einer späteren Story-Konzeption entwickelt werden.

---

# 14. TOD, SPEICHERN UND FORTSCHRITT

## 14.1 Grundidee

Der Tod soll Konsequenzen haben, ohne den Spieler durch unverhältnismäßigen Verlust zu frustrieren.

Als vorläufiges Konzept ist ein Rücksetzen auf den letzten Tagesbeginn vorgesehen.

Beispiel:

Der Spieler beginnt einen Tag, sammelt Ressourcen, baut Verteidigungen und erlebt nachts einen Angriff.

Stirbt er, wird auf den Beginn dieses Tages zurückgesetzt.

Die Basis und Ressourcen entsprechen dann dem Zustand zu diesem Zeitpunkt.

## 14.2 Speicherarchitektur

Das Speichersystem muss unabhängig von den einzelnen Gameplay-Systemen funktionieren.

Es soll mindestens speichern können:

- Spielerposition und Zustand
- Zeit und Tagesphase
- Inventar
- Ressourcen
- Zustand der Basis
- Platzierte Objekte
- Schäden
- Forschungsfortschritt
- Entdeckungen
- Weltzustand
- Bedrohungsniveau
- Fortschritt der aktuellen Episode

Die endgültigen Regeln für Tod, Autosaves und manuelle Speicherstände werden später festgelegt.

## 14.3 Episodenübergreifender Fortschritt

Wenn der Spieler später seine Basis wechselt, soll ein Teil des Fortschritts erhalten bleiben.

Dazu gehören insbesondere:

- Forschungsarchiv
- Entdeckte Baupläne
- Technologien
- Alien-Artefakte
- Wissen
- Langfristige Erkenntnisse

Nicht zwingend erhalten bleiben müssen:

- Möbel
- Wände
- Zäune
- Gebäude
- Alle gesammelten Rohstoffe

Die Verlagerung der Basis soll selbst ein Spielelement werden.

---

# 15. EPISODEN UND BASISWECHSEL

## 15.1 Langfristige Spielstruktur

HOMEBOUND soll langfristig über mehrere größere Gebiete beziehungsweise Episoden erweitert werden können.

Jedes Gebiet bietet neue Umgebungen, Ressourcen, Bedrohungen und Erkenntnisse.

## 15.2 Basiswechsel

Der Spieler kann im Verlauf entscheiden beziehungsweise gezwungen sein, seine bisherige Basis aufzugeben.

Mögliche Gründe:

- Die Umgebung wird zu gefährlich.
- Terraforming macht das Gebiet unbewohnbar.
- Eine neue Region bietet strategische Vorteile.
- Neue Technologien ermöglichen die Erschließung weiterer Gebiete.

## 15.3 Umzug als Gameplay

Der Umzug kann folgende Aufgaben umfassen:

- Vorräte zusammenstellen
- Transport organisieren
- Wichtige Geräte sichern
- Neue Region erkunden
- Standort auswählen
- Neue Basis absichern
- Infrastruktur wiederaufbauen

Der Umzug soll kein bloßer Ladebildschirm sein.

---

# 16. DIE VIER ZENTRALEN SPIELSÄULEN

Das Spiel baut auf vier gleichwertigen Kernbereichen auf.

| Säule | Funktion |
|---|---|
| Base Building | Ein eigenes, ausbaubares Zuhause schaffen und verteidigen |
| Survival Horror | Bedrohungen erkennen, überleben und mit Unsicherheit umgehen |
| Alien Research | Außerirdische Technologien, Spezies und Phänomene erforschen |
| Exploration | Die Umgebung untersuchen, Ressourcen sammeln und neue Gebiete entdecken |

Diese Säulen müssen miteinander verbunden sein.

Beispiel:

Der Spieler entdeckt bei einer Erkundungstour eine außerirdische Energiezelle. Durch Forschung versteht er ihre Funktion. Daraus entwickelt er einen neuen Sensor. Diesen installiert er in seiner Basis und kann dadurch eine bestimmte Bedrohung nachts früher erkennen.

So entsteht ein durchgängiger Gameplay-Kreislauf.

---

# 17. TECHNISCHE GRUNDARCHITEKTUR

## 17.1 Engine und Technologie

Geplant ist Unreal Engine 5.

Die Entwicklung soll modular erfolgen.

Grundsätzlich:

- C++ für grundlegende Systeme und stabile Kernlogik.
- Blueprints für konfigurierbare Gameplay-Elemente und schnelle Iteration.
- Data Assets beziehungsweise Data Tables für konfigurierbare Inhalte.
- Git für Versionskontrolle.
- Claude Code als Entwicklungsassistent.
- Unreal-Editor-Integration über geeignete MCP-Werkzeuge, sofern verfügbar und stabil.

## 17.2 Zentrale Manager

Die Spielarchitektur soll mindestens folgende eigenständige Systeme besitzen:

**Time Manager**
- Spielzeit
- Tag und Nacht
- Schlaf
- Jahreszeiten
- Zeitabhängige Ereignisse

**Threat Director**
- Bedrohungsniveau
- Night Intensity
- Auswahl von Ereignissen
- Koordination von Bedrohungen

**Alien AI**
- Wahrnehmung
- Bewegung
- Verhalten
- Angriffe
- Reaktionen
- Lernverhalten

**World State Manager**
- Terraforming
- Umweltveränderungen
- Weltzustand
- Regionale Veränderungen

**Base Building Manager**
- Platzierung von Objekten
- Bau
- Reparatur
- Zerstörung
- Grundstücksverwaltung

**Research Manager**
- Forschungsobjekte
- Analysen
- Hypothesen
- Forschungsfortschritt
- Freischaltungen

**Inventory Manager**
- Inventar
- Ressourcen
- Gegenstände
- Lagerung

**Episode Manager**
- Regionen
- Episoden
- Basiswechsel
- Langfristiger Fortschritt

**Save Manager**
- Speichern
- Laden
- Autosaves
- Wiederherstellung von Spielzuständen

## 17.3 Architekturregeln

Die Systeme sollen möglichst unabhängig voneinander arbeiten.

Beispielsweise darf der Threat Director nicht selbst die komplette KI einer Kreatur enthalten.

Er entscheidet lediglich, dass ein bestimmtes Ereignis ausgelöst wird.

Die Alien AI entscheidet anschließend, wie sich die Kreatur verhält.

Ebenso soll die Forschungslogik nicht fest in einzelne Gegenstände programmiert werden.

Neue Forschungsobjekte sollen über Datenstrukturen ergänzt werden können.

Neue Spezies, Ereignisse, Bauobjekte und Forschungsinhalte sollen möglichst ohne grundlegende Änderungen an der Systemarchitektur ergänzt werden können.

## 17.4 Datengetriebene Entwicklung

Wichtige Gameplay-Inhalte sollen möglichst über Daten konfigurierbar sein.

Dazu gehören:

- Spezies
- Gegnerverhalten
- Ereignisse
- Forschungsobjekte
- Bauobjekte
- Ressourcen
- Rezepte
- Technologien
- Weltveränderungen

Ziel ist, dass Claude später neue Inhalte ergänzen kann, ohne bestehende Systeme unnötig umzubauen.

---

# 18. ERSTER SPIELBARER PROTOTYP

## 18.1 Ziel

Der erste Prototyp soll nicht das gesamte Spiel enthalten.

Er soll beweisen, dass die zentrale Spielerfahrung funktioniert.

Die entscheidende Frage lautet:

**Kann der Spieler nachts in seinem Wohnzimmer sitzen, draußen etwas hören, auf die Kameras schauen und tatsächlich unsicher sein, ob er nachsehen oder lieber im Haus bleiben sollte?**

Wenn dieses Erlebnis funktioniert, ist das Fundament des Spiels gelegt.

## 18.2 Umfang

Der erste Prototyp enthält:

**Umgebung**
- Eine begehbare kleine Hütte
- Einen Garten
- Einen begrenzten Außenbereich
- Eine einfache Waldkulisse
- Einen Schuppen

**Spieler**
- First-Person-Steuerung
- Bewegung
- Interaktion
- Inventar-Grundlage

**Zeit**
- Tag-Nacht-Zyklus
- Einfache Uhr
- Schlafsystem zunächst in einer vereinfachten Version

**Basis**
- Eine abschließbare Haustür
- Zwei zerstörbare Fenster
- Einfache Barrikaden
- Generator
- Stromversorgung

**Überwachung**
- Drei Kameras
- Zentraler Monitor
- Umschalten zwischen Kameras

**Bedrohung**
- Eine außerirdische Kreatur
- Eigenständige Wahrnehmung
- Bewegung im Außenbereich
- Geräuschreaktion
- Beobachtungs- und Angriffsverhalten

**Verteidigung**
- Eine einfache Verteidigungsmechanik
- Beschädigbare Bauteile
- Reparaturmöglichkeiten

## 18.3 Bewusst nicht im ersten Prototyp

Folgende Inhalte werden zunächst zurückgestellt:

- Mehrere Alien-Spezies
- Umfangreiche Forschung
- Komplexes Crafting
- Fahrzeuge
- Episoden
- Basiswechsel
- Jahreszeiten
- Große Story-Sequenzen
- Umfangreiches Terraforming
- Koop-Modus

Die Architektur muss spätere Erweiterungen berücksichtigen, aber diese Systeme müssen noch nicht vollständig umgesetzt werden.

## 18.4 Erfolgskriterien

Der Prototyp ist erfolgreich, wenn:

1. Der Spieler das Haus und den Außenbereich problemlos erkunden kann.
2. Der Tag-Nacht-Wechsel funktioniert.
3. Der Generator die Stromversorgung beeinflusst.
4. Die Kameras unterschiedliche Bereiche überwachen.
5. Eine Kreatur eigenständig durch den Außenbereich navigiert.
6. Die Kreatur auf den Spieler und Geräusche reagiert.
7. Der Spieler die Kreatur hören und möglicherweise über Kameras entdecken kann.
8. Fenster und Türen beschädigt werden können.
9. Der Spieler auf einen Angriff reagieren kann.
10. Die Situation auch ohne aufwendige Grafik eine glaubwürdige Horroratmosphäre erzeugt.

---

# 19. ENTWICKLUNGSROADMAP

Die Entwicklung erfolgt in klar voneinander abgegrenzten Phasen.

## Phase 1 – Technisches Fundament

- Unreal-Projekt einrichten
- First-Person-Controller
- Interaktionssystem
- Grundlegende Projektstruktur
- Datenarchitektur
- Git einrichten
- Grundlegendes Speichersystem vorbereiten

**Ergebnis:** Ein technisch sauberer Projektstart.

## Phase 2 – Spielwelt und Basis

- Hütte erstellen
- Außenbereich gestalten
- Räume definieren
- Türen und Fenster
- Bau- und Platzierungssystem
- Erste zerstörbare Elemente
- Inventar-Grundlage

**Ergebnis:** Eine begehbare und interaktive Basis.

## Phase 3 – Zeit und Stromversorgung

- Tag-Nacht-Zyklus
- Uhr
- Generator
- Stromverbraucher
- Beleuchtung
- Stromausfälle
- Erste Schlafmechanik

**Ergebnis:** Ein funktionierender Tages- und Nachtablauf.

## Phase 4 – Überwachung und Bedrohung

- Kamerasystem
- Überwachungsmonitor
- Threat Director
- Ereignissystem
- Erste Alien-Kreatur
- Wahrnehmung
- Bewegungsverhalten
- Angriffe
- Geräuschsystem

**Ergebnis:** Eine erste spielbare Survival-Horror-Nacht.

## Phase 5 – Atmosphäre und Horror

- Umgebungsgeräusche
- Kreaturensounds
- Lichtstimmung
- Sichtbarkeit und Schatten
- Unvorhersehbare Ereignisse
- Kamerastörungen
- Psychologische Ereignisse

**Ergebnis:** Das zentrale Horror-Erlebnis funktioniert.

## Phase 6 – Survival und Crafting

- Ressourcen
- Sammeln
- Inventar erweitern
- Werkstatt
- Crafting
- Reparaturen
- Weitere Verteidigungsobjekte

**Ergebnis:** Ein funktionierender Survival- und Basisbau-Kreislauf.

## Phase 7 – Forschung

- Alien-Archiv
- Forschungsobjekte
- Analysesystem
- Forschungsbereiche
- Hypothesen
- Verknüpfungen
- Erste Forschungsfreischaltungen
- Erste außerirdische Baupläne

**Ergebnis:** Die Forschungsmechanik wird zu einem echten Progressionssystem.

## Phase 8 – Weltentwicklung

- Terraforming
- Umweltveränderungen
- Weitere Alien-Spezies
- Neue Ereignisse
- Neue Forschungsinhalte
- Erweiterte Erkundung

**Ergebnis:** Die Welt entwickelt sich dynamisch weiter.

## Phase 9 – Langfristige Spielstruktur

- Weitere Regionen
- Fahrzeuge
- Episoden
- Basiswechsel
- Episodenübergreifender Fortschritt
- Erweiterte Story

**Ergebnis:** Das Fundament für ein vollständiges Spiel.

---

# 20. NICHT-ZIELE UND SCOPE-KONTROLLE

Um das Projekt beherrschbar zu halten, gelten folgende Grundsätze:

- Keine riesige Open World als Selbstzweck.
- Keine permanente Gegnerwellen-Mechanik.
- Keine reine Shooter-Ausrichtung.
- Keine vollständig zufällig generierte Welt als Voraussetzung.
- Keine übermäßig komplexen Hunger- und Durstmechaniken.
- Keine lange Story-Erklärung zu Beginn.
- Keine vollständige Implementierung aller Spezies im Prototyp.
- Keine unnötig komplexen Systeme, bevor der Kern-Gameplay-Loop funktioniert.

Neue Ideen sollen anhand ihrer Bedeutung für die vier zentralen Spielsсäulen bewertet werden.

---

# 21. OFFENE ENTSCHEIDUNGEN

Die folgenden Punkte sind noch nicht abschließend definiert und dürfen bei der technischen Umsetzung nicht eigenmächtig als endgültige Designentscheidungen festgeschrieben werden.

| Bereich | Offene Frage |
|---|---|
| Story | Warum sind die Aliens auf der Erde? |
| Spezies | Wie viele Spezies gibt es insgesamt? |
| Alien-Technologie | Wie genau funktioniert das Forschungsgerät? |
| Forschung | Wie werden Hypothesen und Experimente im Detail umgesetzt? |
| Baupläne | Welche konkreten Fund- und Freischaltmechaniken gibt es? |
| Kampf | Welche Waffen und Munitionstypen gibt es? |
| Tod | Endgültige Regeln für Tod und Wiederherstellung |
| Speicherstände | Autosave, manuelles Speichern und Checkpoints |
| Fahrzeuge | Welche Fahrzeugtypen und Funktionen gibt es? |
| Episoden | Konkrete Regionen und deren Inhalte |
| Terraforming | Welche Veränderungen sind rein atmosphärisch und welche spielmechanisch? |
| Jahreszeiten | Wann und in welchem Umfang werden sie eingeführt? |
| Koop | Ob und wann ein Mehrspielermodus umgesetzt wird |

Diese Punkte werden im weiteren Designprozess konkretisiert.

---

# 22. ZUSAMMENFASSUNG

HOMEBOUND ist ein Survival-Horror-Spiel über das Überleben in einer zunehmend fremdartigen Welt.

Der Spieler beginnt allein in einer abgelegenen Waldhütte. Er baut sich ein Zuhause auf, sammelt Ressourcen und versucht, die außerirdischen Aktivitäten in seiner Umgebung zu verstehen.

Tagsüber erkundet und forscht er. Nachts muss er mit einer Bedrohung umgehen, die er oft nur hört oder über Kameras beobachten kann.

Die eigene Basis gibt Sicherheit, ist aber niemals vollständig geschützt.

Im Laufe des Spiels werden die außerirdischen Aktivitäten intensiver. Die Welt verändert sich. Neue Spezies und Technologien werden entdeckt. Der Spieler entwickelt seine Fähigkeiten weiter und erschließt schließlich neue Regionen.

Die vier zentralen Säulen sind:

1. **Base Building:** Ein eigenes Zuhause aufbauen und verteidigen.
2. **Survival Horror:** Unberechenbare Bedrohungen überleben.
3. **Alien Research:** Außerirdische Lebensformen und Technologien verstehen.
4. **Exploration:** Eine fremdartig werdende Welt erkunden.

Das wichtigste Entwicklungsziel ist zunächst nicht die Größe des Spiels, sondern die Qualität seiner Kernmechanik:

**Ein Spieler sitzt nachts in seinem selbst aufgebauten Zuhause. Draußen bewegt sich etwas. Er hört es, sieht es vielleicht auf einer Kamera und muss entscheiden, was er jetzt tut.**

Wenn dieser Moment funktioniert, hat HOMEBOUND sein Fundament.