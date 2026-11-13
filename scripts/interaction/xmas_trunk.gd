class_name XmasTrunk
extends Interactable
## Die alte Truhe auf dem Dachboden mit den Weihnachtssachen (Story-Bibel Phase 4).
## Stefanies Mail: »Ich hab dir was in die Kiste mit den Weihnachtssachen gelegt.« Ihre Mappe liegt im doppelten Boden
## unter der Krippe – man findet sie erst, wenn man weiß, dass sie etwas versteckt hat (Story-Phase 4).

@export var area_size: Vector3 = Vector3(0.9, 0.6, 0.95)


func _ready() -> void:
	var area := Area3D.new()
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = area_size
	cs.shape = sh
	cs.position = Vector3(0, area_size.y * 0.5, 0)
	area.add_child(cs)
	add_child(area)


func get_prompt(_p: Node) -> String:
	if Research.notes.has("stef_mappe"):
		return "Alte Truhe – Weihnachtssachen"
	return "[E] Alte Truhe öffnen"


func interact(_p: Node) -> void:
	SoundBank.play_at(self, "door_open", global_position + Vector3(0, 0.4, 0), -10.0, 0.7)
	if Research.notes.has("stef_mappe"):
		EventBus.notify("Die Krippe liegt wieder obenauf. Die Mappe habe ich bei mir behalten.", 3.0)
		return
	if Story.phase < 4:
		EventBus.notify("Weihnachtssachen. Lichterketten, Kugeln, die Krippe von Bens erstem Weihnachten. Ich mache sie schnell wieder zu.", 4.5)
		return
	Research.read_note("stef_mappe")
	Tasks.flag("mappe_found")
	EventBus.notify("Diesmal hebe ich die Krippe heraus. Darunter klappert ein loses Brett … ein doppelter Boden. Stefanies Mappe. (Notizen auf dem Tablet)", 6.0)
