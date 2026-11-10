class_name PauseMenu
extends CanvasLayer
## Pausenmenü (Esc): Weiter / Beenden.

var _root: Control


func _ready() -> void:
	name = "PauseMenu"
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	center.add_child(box)

	var title := Label.new()
	title.text = "Pause"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	box.add_child(title)

	var resume := _button(box, "Weiter")
	resume.pressed.connect(func() -> void: set_paused(false))
	# TEST – wird später wieder entfernt: zu Tag 10 springen, um die späten Tage anzusehen
	var jump := _button(box, "TEST: zu Tag 10 springen")
	jump.modulate = Color(1.0, 0.8, 0.5)
	jump.pressed.connect(_test_jump_to_day.bind(10))
	var quit := _button(box, "Spiel beenden")
	quit.pressed.connect(func() -> void: get_tree().quit())

	visible = false


func _button(parent: Control, text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(320, 56)
	b.add_theme_font_size_override("font_size", 24)
	parent.add_child(b)
	return b


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_menu"):
		get_viewport().set_input_as_handled()
		# offene Karte: Esc schließt erst die Karte
		var map := get_tree().get_first_node_in_group("map_screen")
		if not get_tree().paused and map and map.call("is_open"):
			map.call("close")
			return
		set_paused(not get_tree().paused)


func set_paused(value: bool) -> void:
	get_tree().paused = value
	visible = value
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if value or _menu_needs_mouse() else Input.MOUSE_MODE_CAPTURED


## Ist hinter der Pause noch ein Menü offen, das den Mauszeiger braucht (Inventar, Forschung, Tablet)?
func _menu_needs_mouse() -> bool:
	for g in ["game_menus", "research_menu", "tablet_menu"]:
		var m := get_tree().get_first_node_in_group(g)
		if m and m.has_method("is_open") and m.call("is_open"):
			return true
	return false


## TEST: Sprung zu einem späteren Tag (7 Uhr morgens). Spannungsbogen, Talverwandlung und Wucherungen
## laufen für die übersprungenen Tage mit; Hunger, Durst, Ausdauer und Gesundheit voll.
## Ressourcen werden nicht mitgenommen/ergänzt. Wird später wieder entfernt.
func _test_jump_to_day(target: int) -> void:
	set_paused(false)
	if TimeManager.day >= target:
		EventBus.notify("TEST: Du bist schon an Tag %d." % TimeManager.day, 3.0)
		return
	for d in range(TimeManager.day, target):
		ThreatDirector.plan_night(d)  # Bogen der übersprungenen Nächte fortschreiben
		TimeManager.set_time(d + 1, 8.0)
		WorldState._on_day_changed(d + 1)
	TimeManager.set_time(target, TimeManager.config.wake_up_hour)
	ThreatDirector._planned_for_day = -1
	ThreatDirector._activity_tonight = true
	ThreatDirector._on_phase_changed(false)  # Morgen: Spuren, Veränderungen draußen, Nacht planen
	Survival.hunger = 100.0
	Survival.thirst = 100.0
	Survival.stamina = Survival.STAMINA_MAX
	var player := get_tree().get_first_node_in_group("player") as Player
	if player:
		player.health = Player.MAX_HEALTH
		player.mind = 0.0
	GameState.take_snapshot()
	EventBus.notify("TEST: Tag %d, %s. Heute Nacht: %s." % [target, TimeManager.get_clock_text(),
			{"quiet": "ruhig", "hints": "Andeutungen", "sighting": "Sichtung", "visit": "Erkundung", "hunt": "Angriff"}.get(ThreatDirector.night_kind, "?")], 6.0)
