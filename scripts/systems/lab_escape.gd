class_name LabEscape
extends RefCounted
## Was passiert, wenn eine lebende Probe ausbricht (Forschung 2.0). Art steht im Projekt (research.json "escape"):
##  - crawl:  Die Probe ist weg und kriecht irgendwo im Haus herum – sie kratzt nachts, man muss sie suchen und einfangen.
##  - spread: Fäden wachsen durch den Abfluss nach draußen – eine neue Wucherung direkt an der Hütte.
##  - call:   Die Probe sendet hell – die Drohne kommt in der nächsten Nacht sicher, die Signatur bleibt einen Tag hoch.
##  - bloom:  Leuchtpilz/Erde wuchert im Bad: Lampen flackern, Strom wird gezogen, bis man es abkratzt (gibt Leuchtpilz).

## Verstecke für entkommene Proben (in der Hütte)
const HIDE_SPOTS := [
	Vector3(-4.8, 0.47, 3.6),   # unter der Couch-Ecke
	Vector3(3.2, 0.47, -1.6),   # Bad, hinter der Tür
	Vector3(5.3, 0.47, 3.9),    # Werkstatt, unter der Werkbank
	Vector3(-0.4, 0.47, -3.9),  # Abstellraum
	Vector3(-4.2, 0.47, -3.7),  # Schlafzimmer, unter dem Bett
	Vector3(0.8, 0.47, 3.8),    # Flur vor der Tür
	Vector3(-2.6, 0.47, 0.2),   # Wohnzimmer, Ecke am Kamin
]


static func happen(tree: SceneTree, project: String, kind: String, at: Vector3) -> void:
	var name := String(Research.analysis(project).get("name", project))
	var scene := tree.current_scene
	match kind:
		"crawl":
			var drops := AlienDrops.get_for(tree)
			var find := String(Research.analysis(project).get("find", ""))
			if drops and find != "":
				var spot: Vector3 = HIDE_SPOTS[randi() % HIDE_SPOTS.size()]
				drops.spawn(find, spot, true)
			if scene:
				SoundBank.play_at(scene, "scratch", at, 0.0, 1.5)
			EventBus.notify("Das Terrarium ist leer. Der Deckel ist von innen aufgedrückt. („%s“ ist irgendwo im Haus.)" % name, 6.0)
		"spread":
			var ok := WorldState.spawn_patch_near(Vector3(4.2, 0, -7.2))
			EventBus.notify("Aus dem Abfluss im Bad ziehen sich graue Fäden nach draußen%s" % (" – hinter der Hütte wächst eine Wucherung." if ok else "."), 6.0)
		"call":
			Research.flare_until = maxf(Research.flare_until, Research.now() + 24.0)
			ThreatDirector.force_event("drone", 3.0 if TimeManager.is_night() else maxf(TimeManager.config.night_start_hour + 24.0 - TimeManager.hour, 1.0) + 1.5)
			if scene:
				SoundBank.play_at(scene, "signal", at, 4.0, 0.5)
			EventBus.notify("„%s“ pulsiert grell. Irgendwo über dem Wald antwortet etwas." % name, 6.0)
		"bloom":
			Research.lab_bloom = true
			PowerManager.set_consumer("lab_bloom", true)
			tree.call_group("lamp", "flicker", 2.5)
			EventBus.notify("Im Bad wuchert es: Leuchtende Flecken an Wänden und Decke, die Lampe flackert. (Abkratzen an der Arbeitsplatte)", 6.0)
	Tasks.flag("lab_escape")
