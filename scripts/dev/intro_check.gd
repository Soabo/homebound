extends SceneTree
## Ablauf-Prüfung des Intros im Zeitraffer (godot --headless --path . -s res://scripts/dev/intro_check.gd)
## Ohne feste Typen: bei -s sind die Autoloads beim Übersetzen dieses Skripts noch nicht bekannt.

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	change_scene_to_file("res://scenes/intro.tscn")
	await create_timer(4.0).timeout
	var s = current_scene
	print("INTRO Schritt nach 4 s: ", s.step, " (1 = klingelt)")
	s._set_step(2)
	for i in 20:
		if s._choice_wait:
			s._pick(1)
			print("INTRO Antwort gewählt: ", s._line.text)
		elif s.step == 2:
			s._next_line()
		await process_frame
	print("INTRO nach dem Gespräch: ", s.step, " (3 = danach)")
	await create_timer(12.0).timeout
	print("INTRO nach dem Unfall: ", s.step, " (5 = Polizei ruft an), Uhr ", s._clock3d.text)
	s._set_step(6)
	for i in 6:
		if s.step == 6:
			s._next_line()
		await process_frame
	print("INTRO Nachspann: ", s.step, " (7)")
	Engine.time_scale = 10.0
	for i in 150:
		await create_timer(1.0).timeout
		if current_scene == null or current_scene.name != "Intro":
			break
	Engine.time_scale = 1.0
	await create_timer(2.0).timeout
	print("INTRO Ende: Szene ", current_scene.name if current_scene else "–")
	quit()
