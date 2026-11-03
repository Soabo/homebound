class_name Interactable
extends Node3D
## Basisklasse für alles, was der Spieler mit E (und optional R) benutzen kann.
## Der Spieler findet ein Interactable, indem er vom getroffenen Kollisionskörper
## aus nach oben durch die Elternknoten läuft.

## Text für die Haupt-Aktion (E). Leer = gerade nicht benutzbar.
func get_prompt(_player: Node) -> String:
	return ""


## Text für die Zweit-Aktion (R). Leer = keine.
func get_secondary_prompt(_player: Node) -> String:
	return ""


func interact(_player: Node) -> void:
	pass


func secondary_interact(_player: Node) -> void:
	pass
