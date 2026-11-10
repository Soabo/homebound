class_name W17Slot
extends Interactable
## Fassung für W-17 am umgebauten Funkgerät. Erst nach der Verknüpfung „Dieselbe Handschrift“ (link_w17)
## lässt sich W-17 ausbauen und als Suchgerät mitnehmen; solange es fehlt, liest das Gerät nichts.

var _part: Node3D


## Das Bauteil selbst: matter Kern in einer Industriefassung mit Aufkleber.
static func build_part(parent: Node3D) -> void:
	var metal := BuildKit.tex_mat("metal", 0.2, Color(0.9, 0.9, 0.92), 0.6)
	var core := BuildKit.color_mat(Color(0.12, 0.12, 0.14), 0.3, 0.4)
	BuildKit.box(parent, Vector3(0.1, 0.06, 0.08), Vector3(0, 0.03, 0), metal, false)
	BuildKit.sphere(parent, 0.035, Vector3(0, 0.065, 0), core, Vector3(1.0, 0.7, 1.0), 10)
	BuildKit.sphere(parent, 0.008, Vector3(0.02, 0.085, 0.01), BuildKit.emissive_mat(Color(0.55, 0.85, 1.0), 0.8), Vector3.ONE, 5)
	BuildKit.box(parent, Vector3(0.06, 0.03, 0.002), Vector3(0, 0.03, 0.041), BuildKit.color_mat(Color(0.95, 0.9, 0.3)), false)


func _ready() -> void:
	_part = Node3D.new()
	add_child(_part)
	build_part(_part)
	var area := Area3D.new()
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(0.16, 0.14, 0.14)
	cs.shape = sh
	cs.position = Vector3(0, 0.05, 0)
	area.add_child(cs)
	add_child(area)
	Research.changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	visible = Research.tier >= 1
	_part.visible = Research.w17_in_device


func get_prompt(_p: Node) -> String:
	if Research.tier < 1:
		return ""
	if Research.w17_in_device:
		if Research.links_done.has("link_w17"):
			return "[E] W-17 ausbauen und mitnehmen (Suchgerät)"
		return "W-17 – fest verbaut. Ich verstehe noch zu wenig, um es wieder auszubauen."
	if Inventory.count("w17") > 0:
		return "[E] W-17 wieder einsetzen (dann liest das Gerät wieder)"
	return "Fassung für W-17 – leer"


func interact(_p: Node) -> void:
	if Research.tier < 1:
		return
	if Research.w17_in_device:
		if not Research.links_done.has("link_w17"):
			return
		if Inventory.add("w17", 1) <= 0:
			EventBus.notify("Zu schwer – du kannst nicht mehr tragen.", 2.0)
			return
		Research.w17_in_device = false
		Research.changed.emit()
		Tasks.flag("w17_carried")
		SoundBank.play_at(self, "static", global_position, -10.0, 1.4)
		EventBus.notify("W-17 ausgebaut. Es summt leise in meiner Tasche. Das Analysegerät ist jetzt blind.", 4.0)
	elif Inventory.count("w17") > 0:
		Inventory.remove("w17", 1)
		Research.w17_in_device = true
		Research.changed.emit()
		SoundBank.play_at(self, "signal", global_position, -12.0, 0.7)
		EventBus.notify("W-17 sitzt wieder. Das Gerät liest wieder.", 2.5)
