extends Node
## Story-Gerüst (Story-Bibel: 5 Phasen). Welche Phase läuft, entscheidet data/story/story.json:
## Eine Phase beginnt, sobald eine ihrer Bedingungen (begins_any) erfüllt ist. Phasen springen nur vorwärts.
## Andere Systeme fragen Story.phase ab (z. B. der Zerfleischer erst ab Phase 2).

signal phase_changed(phase: int)

var phase: int = 1
var _check_t: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE


func data() -> Dictionary:
	return DataDB.load_json("res://data/story/story.json")


func phase_def(n: int) -> Dictionary:
	for p: Dictionary in data().get("phases", []):
		if int(p.get("id", 0)) == n:
			return p
	return {}


func _process(delta: float) -> void:
	_check_t -= delta
	if _check_t > 0.0:
		return
	_check_t = 2.0
	var next := phase_def(phase + 1)
	if next.is_empty():
		return
	for c: String in next.get("begins_any", []):
		if condition(c):
			set_phase(phase + 1)
			return


## Bedingungen: flag:X (Tasks), link:X (Forschung), day>=N
static func condition(c: String) -> bool:
	if c.begins_with("flag:"):
		return Tasks.flags.has(c.substr(5))
	if c.begins_with("link:"):
		return Research.links_done.has(c.substr(5))
	if c.begins_with("day>="):
		return TimeManager.day >= int(c.substr(5))
	return false


func set_phase(n: int) -> void:
	if n <= phase:
		return
	phase = n
	var text := String(phase_def(n).get("text", ""))
	if text != "":
		EventBus.notify(text, 7.0)
	Tasks.flag("story_phase_%d" % n)
	phase_changed.emit(n)
	print("[Story] Phase ", n, ": ", phase_def(n).get("name", ""))


func get_state() -> Dictionary:
	return {"phase": phase}


func set_state(s: Dictionary) -> void:
	phase = int(s.get("phase", 1))
