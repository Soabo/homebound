class_name MovingBox
extends Interactable
## Christians Umzugskarton aus der alten Arbeit, nie ausgepackt (unten im Funktisch).
## Darin: Helm, Firmenausweis, Einsatzmappe, die alte Einsatzkarte (Karte, Taste M) – und das Bauteil W-17 (Story-Bibel).
## E = auspacken (Notizen lesen, W-17 nehmen). Persistent.

var opened: bool = false
var w17_taken: bool = false
var _lid: Node3D
var _w17_vis: Node3D


func _ready() -> void:
	add_to_group("persistent")
	GameState.restore(self)
	var card := BuildKit.tex_mat("fabric", 0.3, Color(1.45, 1.2, 0.85))
	BuildKit.box(self, Vector3(0.5, 0.012, 0.38), Vector3(0, 0.006, 0), card, false)
	for s: float in [-1.0, 1.0]:
		BuildKit.box(self, Vector3(0.5, 0.3, 0.012), Vector3(0, 0.15, s * 0.19), card, false)
		BuildKit.box(self, Vector3(0.012, 0.3, 0.38), Vector3(s * 0.25, 0.15, 0), card, false)
	var lab := Label3D.new()
	lab.text = "FIRMA –\nnicht wegwerfen!"   # zweizeilig, passt auf die Kartonseite
	lab.font_size = 28
	lab.line_spacing = -4.0
	lab.pixel_size = 0.0018
	lab.modulate = Color(0.1, 0.1, 0.12)
	lab.outline_size = 0
	lab.position = Vector3(0, 0.155, 0.198)
	add_child(lab)
	_lid = Node3D.new()
	_lid.position = Vector3(0, 0.3, -0.19)
	add_child(_lid)
	BuildKit.box(_lid, Vector3(0.5, 0.01, 0.38), Vector3(0, 0, 0.19), card, false)
	BuildKit.box(_lid, Vector3(0.5, 0.004, 0.05), Vector3(0, 0.007, 0.19), BuildKit.color_mat(Color(0.75, 0.7, 0.5)), false)
	# Geöffnet: Deckel aufgerissen – nur zerfetzte Reste mit Klebeband stehen am Rand (Christian 27.11.)
	_torn = Node3D.new()
	add_child(_torn)
	var tape := BuildKit.color_mat(Color(0.75, 0.7, 0.5))
	var rng := RandomNumberGenerator.new()
	rng.seed = 17
	for s: float in [-1.0, 1.0]:
		var x := -0.21
		while x < 0.21:
			var w := rng.randf_range(0.04, 0.09)
			var hgt := rng.randf_range(0.012, 0.045)
			BuildKit.box(_torn, Vector3(w, hgt, 0.01), Vector3(x + w * 0.5, 0.3 + hgt * 0.5, s * 0.19), card, false,
					Vector3(s * rng.randf_range(15.0, 40.0), 0, rng.randf_range(-6.0, 6.0)))
			x += w + rng.randf_range(0.005, 0.02)
		BuildKit.box(_torn, Vector3(0.012, rng.randf_range(0.015, 0.03), rng.randf_range(0.12, 0.3)), Vector3(s * 0.25, 0.31, rng.randf_range(-0.05, 0.05)), card, false,
				Vector3(0, 0, -s * rng.randf_range(15.0, 35.0)))
		BuildKit.box(_torn, Vector3(0.08, 0.003, 0.03), Vector3(rng.randf_range(-0.1, 0.1), 0.303, s * 0.2), tape, false, Vector3(s * 30.0, 0, 0))
	# Inhalt: Helm, Ordner, W-17
	BuildKit.sphere(self, 0.13, Vector3(-0.12, 0.18, 0.0), BuildKit.color_mat(Color(0.95, 0.85, 0.2), 0.5), Vector3(1.0, 0.7, 1.15), 10)
	BuildKit.box(self, Vector3(0.22, 0.04, 0.3), Vector3(0.12, 0.05, 0.0), BuildKit.color_mat(Color(0.2, 0.3, 0.55), 0.7), false)
	_w17_vis = Node3D.new()
	_w17_vis.position = Vector3(0.12, 0.1, 0.02)
	add_child(_w17_vis)
	W17Slot.build_part(_w17_vis)
	var area := Area3D.new()
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(0.55, 0.35, 0.42)
	cs.shape = sh
	cs.position = Vector3(0, 0.17, 0)
	area.add_child(cs)
	add_child(area)
	_apply()


## Der Karton bleibt unter dem Funktisch stehen. Geöffnet ist der Deckel einfach weg (aufgerissen), statt aufzuklappen.
var _torn: Node3D


func _apply() -> void:
	_lid.visible = not opened
	_torn.visible = opened
	_w17_vis.visible = not w17_taken


## Tests dürfen den Karton auch ohne Aufgabe öffnen.
static var bypass_lock := false


## Christian 23.11.: erst öffnen, wenn das Spiel dazu auffordert (Spur „Der Umzugskarton“ oder Aufgabe „Analysegerät“).
func can_open() -> bool:
	if opened or bypass_lock:
		return true
	if Story.steps_active.has("p1_karton") or Story.steps_done.has("p1_karton"):
		return true
	return Tasks.check("got:metal_fragment")


func get_prompt(_p: Node) -> String:
	if not opened and not can_open():
		return "Alter Umzugskarton – Kram aus der alten Arbeit"
	if not opened:
		return "[E] Alten Umzugskarton öffnen"
	if not w17_taken:
		return "[E] Das seltsame Bauteil nehmen (W-17)"
	return "Umzugskarton – Helm, Ausweis, alte Mappe"


func interact(_p: Node) -> void:
	if not opened and not can_open():
		EventBus.notify("Sachen aus der alten Arbeit. Jetzt nicht – ich will das gerade nicht sehen.", 3.0)
		return
	if not opened:
		opened = true
		_apply()
		SoundBank.play_at(self, "backpack", global_position + Vector3(0, 0.2, 0), -4.0, 0.8)
		Research.read_note("karton_ausweis")
		Research.read_note("karton_mappe")
		Inventory.add("work_map", 1)
		EventBus.notify("Mein alter Firmenausweis, der Helm, die Einsatzmappe … und meine alte Einsatzkarte [M]. (Notizen auf dem Tablet)", 4.5)
		return
	if not w17_taken:
		if Inventory.add("w17", 1) <= 0:
			EventBus.notify("Zu schwer – du kannst nicht mehr tragen.", 2.0)
			return
		w17_taken = true
		_apply()
		Research.read_note("w17_info")
		SoundBank.play_at(self, "signal", global_position + Vector3(0, 0.2, 0), -12.0, 0.5)
		EventBus.notify("W-17. Es ist kalt – und das Funkgerät knackt, als ich es in die Hand nehme.", 4.0)
		return
	if Inventory.count("work_map") <= 0 and Inventory.add("work_map", 1) > 0:
		EventBus.notify("Die alte Einsatzkarte nehme ich mit. [M]", 2.5)
		return
	EventBus.notify("Nur noch alte Sachen. Ich mag sie nicht ansehen.", 2.5)


func persist_key() -> String:
	return str(get_path())


func get_state() -> Dictionary:
	return {"opened": opened, "w17": w17_taken}


func set_state(s: Dictionary) -> void:
	opened = bool(s.get("opened", false))
	w17_taken = bool(s.get("w17", false))
