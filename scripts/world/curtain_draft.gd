class_name CurtainDraft
extends Node3D
## Vorhang, der im Luftzug weht: ganz leicht immer (die Hütte zieht), stark,
## wenn das Fenster dahinter zerbrochen ist – Böen draußen kommen hier an.

var window_path: NodePath
var panels: Array[Node3D] = []
var _win: CabinWindow
var _t: float = 0.0
var _phase: Array[float] = []


func _ready() -> void:
	_win = get_node_or_null(window_path) as CabinWindow
	pass


func _process(delta: float) -> void:
	_t += delta
	while _phase.size() < panels.size():
		_phase.append(randf() * TAU)
	var draft := 0.06
	var wind := Wind.current
	var outside_wind := 0.25
	if wind:
		outside_wind = wind.at(global_position)
	if _win and _win.is_breached():
		draft = 0.25 + outside_wind * 1.1
	elif _win and _win.health < _win.max_health * 0.5:
		draft = 0.1 + outside_wind * 0.3
	for i in panels.size():
		var p := panels[i]
		var ph := _phase[i]
		# Stoff bläht sich nach innen (-z lokal = in den Raum), flattert dazu
		var a := draft * (0.55 + 0.45 * sin(_t * 1.3 + ph)) + draft * 0.25 * sin(_t * 4.7 + ph * 2.0)
		p.rotation.x = a * 0.9
		p.rotation.z = sin(_t * 0.9 + ph) * draft * 0.15
