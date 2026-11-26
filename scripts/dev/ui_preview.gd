extends Node
## Schnelle Vorschau der Bildschirmanzeige (Sekunden statt Minuten) über dem Titelbild:
## xvfb-run -a godot --path . --rendering-driver vulkan --resolution 1920x1080 res://scenes/dev/ui_preview.tscn -- --out=BILD.png --what=hud|keys|tutorial|intro
## (Test-Schalter: Hauptmenü wird übersprungen, gilt hier nicht – die Szene startet direkt.)


func _ready() -> void:
	var out := "/tmp/ui.png"
	var what := "hud"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="): out = a.get_slice("=", 1)
		if a.begins_with("--what="): what = a.get_slice("=", 1)
	var bg := TextureRect.new()
	bg.texture = load("res://assets/ui/title.jpg")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var layer := CanvasLayer.new()
	add_child(layer)
	layer.add_child(bg)
	if what.begins_with("intro"):
		layer.queue_free()
		var intro := IntroScene.new()
		IntroScene.preview_step = IntroScene.Step.EPILOGUE if what == "intro_epi" else IntroScene.Step.CALL
		add_child(intro)
		var frames := 260 if what == "intro_epi" else 90
		for i in frames:
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png(out)
		get_tree().quit()
		return
	var hud := Hud.new()
	add_child(hud)
	Survival.thirst = 38.0
	Survival.hunger = 47.0
	Survival.warmth = 22.0
	Survival.stamina = 64.0
	await get_tree().process_frame
	hud._fade.color.a = 0.0
	hud._title.modulate.a = 0.0
	hud.show_notification("Getrunken.", 2.0)
	hud.show_notification("Neue Aufgabe: Holz bereitlegen  (Tablet)", 3.0)
	hud.show_notification("Hier drin ist es eiskalt. Erst mal den Kachelofen anheizen.", 6.0)
	hud._on_prompt("[E] Holz nehmen   ·   [R] Holz hineinlegen")
	if what == "keys":
		hud.toggle_keycard()
	if what == "tutorial":
		var card := TutorialCard.new()
		hud.add_child(card)
		card.show_step({"title": "Ankommen", "thought": "Hier drin ist es eiskalt. Erst mal den Kachelofen anheizen.",
			"keys": [["E", "Holz aus dem Korb nehmen"], ["E", "Am Ofen: Holz nachlegen und anzünden"]],
			"text": "Wärme sinkt draußen und nachts schnell. Feuer, Hütte und Schlafsack halten dich warm."}, 2, 9)
	for i in 50:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(out)
	get_tree().quit()
