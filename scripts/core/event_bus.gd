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


func notify(text: String, duration: float = 3.0) -> void:
	notification_requested.emit(text, duration)
