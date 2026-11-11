extends SceneTree
## Ablauf-Prüfung Hauptmenü → Neues Spiel → Speichern → Hauptmenü → Laden (godot --headless --path . -s res://scripts/dev/flow_check.gd)

func _initialize() -> void:
	_run.call_deferred()


func _wait(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	change_scene_to_file("res://scenes/main_menu.tscn")
	await _wait(30)
	var gs := root.get_node("GameState")
	print("FLOW Menü: ", current_scene.name)
	var keep: Variant = gs.call("_read", 1)
	gs.call("new_game", 1)
	await create_timer(4.0).timeout
	print("FLOW Spiel: ", current_scene.name, " Platz ", gs.get("slot"), " gespeichert ", not (gs.call("slot_info", 1) as Dictionary).is_empty())
	root.get_node("Inventory").call("add", "wood", 5)
	gs.call("to_menu")
	await _wait(30)
	print("FLOW zurück im Menü: ", current_scene.name, " neuester Platz ", gs.call("latest_slot"))
	root.get_node("Inventory").call("set_state", {})
	gs.call("load_game", 1)
	await create_timer(3.0).timeout
	print("FLOW geladen: ", current_scene.name, " Holz ", root.get_node("Inventory").call("count", "wood"), " Tag ", root.get_node("TimeManager").get("day"))
	if (keep as Dictionary).is_empty():
		gs.call("delete_slot", 1)
	else:
		var f := FileAccess.open("user://saves/slot_1.save", FileAccess.WRITE)
		f.store_var(keep, false)
	quit()
