class_name Bed
extends Interactable
## Bett – vereinfachtes Schlafsystem (GDD 4.4 / 18.2).
## Kopfende liegt bei lokalem x=0, das Bett erstreckt sich nach +z.
## Später: Aufwachzeit selbst wählen und Aufwachen durch Störungen.

const LENGTH := 2.1
const WIDTH := 1.5


func _ready() -> void:
	var frame := BuildKit.wood_mat(Color(0.33, 0.22, 0.14), 0, 0.15, 0.06)
	var sheet := BuildKit.color_mat(Color(0.72, 0.7, 0.64), 0.95)
	var blanket := BuildKit.color_mat(Color(0.25, 0.3, 0.38), 0.95)
	var pillow := BuildKit.color_mat(Color(0.82, 0.8, 0.75), 0.95)
	BuildKit.box_mm(self, Vector3(0, 0, 0), Vector3(WIDTH, 0.32, LENGTH), frame, true)
	BuildKit.box_mm(self, Vector3(0, 0, -0.04), Vector3(WIDTH, 0.95, 0.04), frame, true)
	BuildKit.box_mm(self, Vector3(0.05, 0.32, 0.05), Vector3(WIDTH - 0.05, 0.5, LENGTH - 0.05), sheet, false)
	BuildKit.box_mm(self, Vector3(0.03, 0.5, 0.75), Vector3(WIDTH - 0.03, 0.56, LENGTH - 0.02), blanket, false)
	# Ein Kissen benutzt, eines unberührt.
	BuildKit.box(self, Vector3(0.6, 0.13, 0.38), Vector3(0.38, 0.57, 0.3), pillow, false, Vector3(0, 6, 0))
	BuildKit.box(self, Vector3(0.6, 0.15, 0.38), Vector3(1.1, 0.58, 0.28), pillow, false)


func get_prompt(_player: Node) -> String:
	if TimeManager.can_sleep():
		return "[E] Schlafen (bis %02d:00)" % int(TimeManager.config.wake_up_hour)
	return "Bett – noch zu früh zum Schlafen"


func interact(_player: Node) -> void:
	if not TimeManager.can_sleep():
		EventBus.notify("Ich bin noch nicht müde.", 2.0)
		return
	EventBus.sleep_requested.emit(TimeManager.config.wake_up_hour)
