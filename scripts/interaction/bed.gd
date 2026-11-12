class_name Bed
extends Interactable
## Bett – vereinfachtes Schlafsystem (GDD 4.4 / 18.2).
## Kopfende liegt bei lokalem x=0, das Bett erstreckt sich nach +z.
## Später: Aufwachzeit selbst wählen und Aufwachen durch Störungen.

const LENGTH := 2.1
const WIDTH := 1.5


func _ready() -> void:
	var frame := BuildKit.tex_mat("planks_h", 0.8, Color(0.75, 0.7, 0.68))
	var sheet := BuildKit.tex_mat("fabric", 0.5, Color(1.7, 1.66, 1.55))
	var blanket := BuildKit.tex_mat("blanket", 0.6)
	var pillow := BuildKit.tex_mat("fabric", 0.4, Color(1.9, 1.85, 1.75))
	BuildKit.box_mm(self, Vector3(0, 0.1, 0), Vector3(WIDTH, 0.32, LENGTH), frame, true)
	# Pfosten am Kopf- und Fußende
	for p: Vector2 in [Vector2(0.05, 0.0), Vector2(WIDTH - 0.05, 0.0), Vector2(0.05, LENGTH - 0.05), Vector2(WIDTH - 0.05, LENGTH - 0.05)]:
		var h := 1.1 if p.y < 0.1 else 0.65
		BuildKit.cylinder(self, 0.05, h, Vector3(p.x, h * 0.5, p.y), frame, false, Vector3.ZERO, -1.0, 6)
	BuildKit.box_mm(self, Vector3(0.05, 0.4, -0.03), Vector3(WIDTH - 0.05, 1.0, 0.03), frame, true)
	BuildKit.box_mm(self, Vector3(0.05, 0.3, LENGTH - 0.08), Vector3(WIDTH - 0.05, 0.6, LENGTH - 0.02), frame, false)
	BuildKit.box_mm(self, Vector3(0.05, 0.32, 0.05), Vector3(WIDTH - 0.05, 0.5, LENGTH - 0.05), sheet, false)
	BuildKit.box_mm(self, Vector3(0.03, 0.5, 0.75), Vector3(WIDTH - 0.03, 0.56, LENGTH - 0.02), blanket, false)
	# Ein Kissen benutzt, eines unberührt.
	BuildKit.box(self, Vector3(0.6, 0.13, 0.38), Vector3(0.38, 0.57, 0.3), pillow, false, Vector3(0, 6, 0))
	BuildKit.box(self, Vector3(0.6, 0.15, 0.38), Vector3(1.1, 0.58, 0.28), pillow, false)


func get_prompt(_player: Node) -> String:
	var why := ThreatDirector.sleep_blocker()
	if why != "" and TimeManager.can_sleep():
		return "Bett – " + why
	if TimeManager.can_sleep():
		if AtticHatch.down_now:
			return "[E] Schlafen (bis %02d:00) – die Dachbodenleiter ist noch unten!" % int(TimeManager.config.wake_up_hour)
		return "[E] Schlafen (bis %02d:00)" % int(TimeManager.config.wake_up_hour)
	return "Bett – noch zu früh zum Schlafen"


func interact(_player: Node) -> void:
	if not TimeManager.can_sleep():
		EventBus.notify("Ich bin noch nicht müde.", 2.0)
		return
	var why := ThreatDirector.sleep_blocker()
	if why != "":
		EventBus.notify(why, 2.5)
		return
	if AtticHatch.down_now:
		EventBus.notify("Die Dachbodenleiter ist noch unten … hoffentlich kommt da nichts herunter.", 3.0)
	EventBus.sleep_requested.emit(TimeManager.config.wake_up_hour)
