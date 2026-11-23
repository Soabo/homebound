extends Node
## Zentraler Signal-Bus.
## Systeme sprechen über diese Signale miteinander, statt sich gegenseitig
## direkt zu kennen (GDD 17.3: Systeme möglichst unabhängig).

## Der Spieler schaut auf etwas Benutzbares (leerer Text = nichts).
signal interaction_prompt_changed(text: String)

## Kurze Meldung oben im Bild, z. B. "Die Tür ist abgeschlossen."
signal notification_requested(text: String, duration: float)

## Der Spieler legt sich schlafen und möchte zur angegebenen Uhrzeit aufwachen.
signal sleep_requested(wake_hour: float)

## Schlafsequenz ist vorbei, Steuerung wieder frei.
signal sleep_finished

## Ein Geräusch, das Kreaturen hören können (Position, Reichweite in Metern).
signal noise_made(position: Vector3, radius: float)

## Eine Überwachungskamera wird für einige Sekunden gestört.
signal camera_glitch(camera_index: int, seconds: float)

## Auf einer Kamera erscheint etwas, das in Wirklichkeit nicht da ist (GDD 7.5).
signal camera_phantom(camera_index: int, seconds: float)

## Angst des Spielers 0..1 (für Bildschirmrand, Herzschlag)
signal fear_changed(fear: float)

## Schreckmoment (0..1): die Angst springt hoch und klingt dann ab (Fear.add_spike)
signal fear_spike(amount: float)

## Kamerawackeln (0..1), z. B. bei Schlägen gegen Tür und Fenster.
signal screen_shake(strength: float)

## Der Spieler wurde verletzt (für Bildschirm-Effekte).
signal player_hurt(amount: float)

## Ein Aufgaben-Merker wurde gesetzt (Tasks.flag) – z. B. für Baupläne, die sich durch Ereignisse freischalten.
signal flag_set(name: String)

## Belagerungsnacht vorbei (überlebt oder nicht)
signal siege_finished(survived: bool)


## Läuft gerade eine Schlafsequenz? Dann wird kein zweiter Schlaf ausgelöst – sonst sprang die Uhr
## (bei doppeltem E im Zelt) um einen ganzen Tag weiter (Fehler „nach Tag 11 kommt Tag 13“).
var sleeping: bool = false


## Schlafen anfordern (Bett, Zelt). false = es läuft schon eine Schlafsequenz.
func request_sleep(wake_hour: float) -> bool:
	if sleeping:
		return false
	sleeping = true
	sleep_requested.emit(wake_hour)
	return true


func _ready() -> void:
	sleep_finished.connect(func() -> void: sleeping = false)


func notify(text: String, duration: float = 3.0) -> void:
	notification_requested.emit(text, duration)
