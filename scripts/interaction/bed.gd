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
	if ThreatDirector.siege_tonight():
		return "Heute Nacht kann ich nicht schlafen. Sie kommen."
	if TimeManager.can_sleep():
		if AtticHatch.down_now:
			return "[E] Schlafen (bis %02d:00) – die Dachbodenleiter ist noch unten!" % int(TimeManager.config.wake_up_hour)
		return "[E] Schlafen (bis %02d:00)" % int(TimeManager.config.wake_up_hour)
	return "Bett – noch zu früh zum Schlafen"


func interact(_player: Node) -> void:
	if EventBus.sleeping:
		return
	if ThreatDirector.siege_tonight():
		EventBus.notify("Heute Nacht kann ich nicht schlafen. Sie kommen.", 2.5)
		return
	if not TimeManager.can_sleep():
		EventBus.notify("Ich bin noch nicht müde.", 2.0)
		return
	var why := ThreatDirector.sleep_blocker()
	if why != "":
		EventBus.notify(why, 2.5)
		return
	if AtticHatch.down_now:
		EventBus.notify("Die Dachbodenleiter ist noch unten … hoffentlich kommt da nichts herunter.", 3.0)
	var p := _player as Player
	if p == null or _lying:
		EventBus.request_sleep(TimeManager.config.wake_up_hour)
		return
	_lie_down(p)


# --- Hinlegen und Aufstehen (Christian 14.11.: Animation fürs Zubettgehen und Aufwachen) ---------

var _lying := false
var _back_pos := Vector3.ZERO
var _back_yaw := 0.0


## Hinlegen: zur Bettkante, Kopf aufs Kissen, Blick zur Decke – erst dann wird es dunkel.
func _lie_down(p: Player) -> void:
	_lying = true
	_back_pos = p.global_position
	_back_yaw = p.rotation.y
	if p.flashlight.visible:
		p.set_flashlight(false)   # Uhr aus, bevor man einschläft
	var feet := to_global(Vector3(0.38, 0.42, 0.5))
	var foot_dir := (to_global(Vector3(0.38, 0, LENGTH)) - to_global(Vector3(0.38, 0, 0))).normalized()
	var tw := Seat.sit_down(self, p, feet, foot_dir, 0.62, false)
	tw.tween_property(p.head, "position:y", 0.16, 1.1).set_delay(0.5)
	tw.tween_property(p.head, "rotation:x", 1.25, 1.1).set_delay(0.5)
	if p.hands:
		p.hands.visible = false
	SoundBank.play_at(get_parent(), "bed_creak" if SoundBank.has_recording("bed_creak") else "floor_creak", feet, -10.0, 0.8)
	tw.chain().tween_interval(0.4)
	tw.chain().tween_callback(func() -> void:
		if not EventBus.sleep_finished.is_connected(_on_woke):
			EventBus.sleep_finished.connect(_on_woke, CONNECT_ONE_SHOT)
		if not EventBus.request_sleep(TimeManager.config.wake_up_hour):
			if EventBus.sleep_finished.is_connected(_on_woke):
				EventBus.sleep_finished.disconnect(_on_woke)
			_on_woke())


## Aufwachen: Blick von der Decke, aufsetzen, aufstehen und zurück vors Bett.
func _on_woke() -> void:
	var p := get_tree().get_first_node_in_group("player") as Player
	_lying = false
	if p == null or GameState.dead:
		return
	GameState.bed_save()   # Speichern am Bett (Christian 23.11.)
	var startled := ThreatDirector.scared_until > TimeManager.get_total_hours()
	var k := 0.45 if startled else 1.0   # aufgeschreckt: viel schneller hoch
	p.input_locked = true
	p.set_physics_process(false)
	var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_interval(0.3 * k)
	tw.tween_property(p.head, "rotation:x", 0.35, 1.0 * k)
	tw.parallel().tween_property(p.head, "position:y", 0.55, 1.0 * k)
	tw.tween_interval(0.25 * k)
	tw.tween_property(p, "rotation:y", p.rotation.y + wrapf(_back_yaw + PI - p.rotation.y, -PI, PI), 0.6 * k)
	tw.parallel().tween_property(p.head, "rotation:x", -0.05, 0.6 * k)
	tw.tween_callback(func() -> void:
		if p.hands:
			p.hands.visible = true
		Seat.stand_up(self, p, _back_pos))
