class_name WellShaft
extends Interactable
## Der alte Brunnen hinter der Hütte = zugeschütteter Schacht von WURZELWERK (Story-Bibel Phase 5).
## Vor Phase 5: nur ansehen (Flag visit_brunnen). Ab Phase 5 mit der Schachtwinde: Bretter aufbrechen und die Winde
## montieren – vorher warnt das Spiel, dass damit der Endspurt beginnt (Story.open_shaft, Frist in endings.json).
## Danach: am Seil hinab in die Kammer des Wurzelknotens (RootChamber).

var boards: Node3D       ## Bretter-Abdeckung (verschwindet beim Öffnen)
var winch: Node3D        ## Winde + Seil (erscheint beim Öffnen)
var area_size := Vector3(1.8, 1.0, 1.8)
var _open_shown: bool = false
var _t: float = 0.0
var _glow: OmniLight3D

const LOOK_TEXT := "Mit Brettern zugenagelt. Durch die Ritzen kommt kalte Luft herauf – und ein ganz leises Summen."


func _ready() -> void:
	add_to_group("well_shaft")
	var area := Area3D.new()
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = area_size
	cs.shape = shape
	cs.position = Vector3(0, area_size.y * 0.5, 0)
	area.add_child(cs)
	add_child(area)
	_glow = OmniLight3D.new()
	_glow.light_color = Color(0.6, 0.4, 1.0)
	_glow.light_energy = 0.0
	_glow.omni_range = 3.5
	_glow.position = Vector3(0, 0.4, 0)
	add_child(_glow)
	_update_visuals()


func _process(delta: float) -> void:
	_t += delta
	if is_open() != _open_shown:
		_update_visuals()
	if _open_shown:
		_glow.light_energy = 0.5 + 0.35 * sin(_t * 1.3) + Story.saat_progress() * 0.6


func is_open() -> bool:
	return Story.shaft_open_day >= 0


func _update_visuals() -> void:
	_open_shown = is_open()
	if boards:
		boards.visible = not _open_shown
	if winch:
		winch.visible = _open_shown
	if _glow:
		_glow.visible = _open_shown


func get_prompt(_player: Node) -> String:
	if is_open():
		return "[E] Am Seil in den Schacht hinab"
	if Story.phase >= 5:
		if Inventory.count("shaft_winch") > 0:
			return "[E] Bretter aufbrechen und die Schachtwinde montieren"
		return "[E] Alten Brunnen ansehen   (braucht: Schachtwinde)"
	return "[E] Alten Brunnen ansehen"


func interact(player: Node) -> void:
	Tasks.flag("visit_brunnen")
	if is_open():
		descend(player as Player)
		return
	if Story.phase < 5:
		EventBus.notify(LOOK_TEXT, 6.0)
		return
	if Inventory.count("shaft_winch") <= 0:
		EventBus.notify("»MP4 – B« ist in den Rand geritzt. Das ist kein Brunnen, das ist ein Schacht. Ohne eine Schachtwinde komme ich da nicht hinunter.", 7.0)
		return
	var nights := Story.endgame_nights()
	ChoiceDialog.open(get_tree(), "Den Schacht öffnen?",
			"Wenn ich die Bretter aufbreche, merkt es der Knoten. Dann läuft die Zeit: Ich habe etwa %d Nächte, bevor die Saat fertig ist.\nDanach kann ich jederzeit hinunter – und auch wieder herauf." % nights,
			[{"id": "open", "label": "Bretter aufbrechen, Winde montieren", "ok": true}], _on_choice)


func _on_choice(id: String) -> void:
	if id != "open":
		return
	Inventory.remove("shaft_winch", 1)
	SoundBank.play_at(self, "plank_break", global_position + Vector3(0, 0.8, 0), 2.0)
	SoundBank.hammer_series(self, global_position + Vector3(0, 1.2, 0), 3)
	Story.open_shaft()
	_update_visuals()


## Hinab in die Kammer (kurz schwarz, dann unten am Seil)
func descend(p: Player) -> void:
	if p == null:
		return
	Tasks.flag("well_descended")
	var chamber := get_tree().get_first_node_in_group("root_chamber") as RootChamber
	if chamber == null:
		return
	ScreenFade.teleport(p, chamber.arrival_point(), chamber.arrival_look(), "Das Seil gibt nach, dann hält es. Zwanzig Meter, dreißig. Unten ist es warm.")
