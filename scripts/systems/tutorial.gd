class_name Tutorial
extends Node
## Geführter erster Tag (Christian 26.11.): ruhiger Nachmittag, Schritt für Schritt Kälte, Durst, Hunger, Tablet,
## Uhr, Bauen, Schleichen und Schlafen. Inhalte in data/tutorial/tutorial.json, Fortschritt als Tasks-Merker
## (tutorial_on, tut_<schritt>, tutorial_done) – damit steht er automatisch im Spielstand.
## Solange ein Schritt mit tempo 0 läuft, steht die Uhr: niemand soll in die erste Nacht gehetzt werden.

static var current: Tutorial

var steps: Array = []
var index := -1              ## laufender Schritt
var card: TutorialCard
var _base := {}              ## Ausgangswerte beim Schrittbeginn (Durst, Hunger, Feuer …)
var _used := {}              ## sneak: welche Schleich-Arten schon benutzt
var _slept := false
var _check_t := 0.0
var _wait_t := 0.0           ## kurze Pause zwischen zwei Schritten


static func data() -> Dictionary:
	return DataDB.load_json("res://data/tutorial/tutorial.json")


## Läuft die Einführung gerade? (Für den ThreatDirector: dann keine Zwischenfälle.)
static func active() -> bool:
	return Tasks.flags.has("tutorial_on") and not Tasks.flags.has("tutorial_done")


## Neues Spiel mit Einführung: Merker setzen, Bedürfnisse etwas herunter, damit die Ringe gleich erscheinen.
static func begin() -> void:
	Tasks.flag("tutorial_on")
	var need: Dictionary = data().get("start_needs", {})
	Survival.thirst = float(need.get("thirst", Survival.thirst))
	Survival.hunger = float(need.get("hunger", Survival.hunger))
	Survival.warmth = float(need.get("warmth", Survival.warmth))
	# Ankunft in eine kalte Hütte: Kachelofen aus, auch keine Speicherwärme mehr
	var scene := Engine.get_main_loop() as SceneTree
	var fp := scene.current_scene.get_node_or_null("Cabin/Fireplace") if scene and scene.current_scene else null
	if fp:
		fp.set("burn_until", TimeManager.get_total_hours() - 24.0)


## Überspringen (Pausenmenü): alles als erledigt markieren, Uhr läuft normal.
static func skip() -> void:
	Tasks.flag("tutorial_done")
	TimeManager.tempo = 1.0
	if current and current.card:
		current.card.hide_card()


func _ready() -> void:
	name = "Tutorial"
	current = self
	steps = Array(data().get("steps", []))
	EventBus.sleep_finished.connect(func() -> void: _slept = true)


func _exit_tree() -> void:
	if current == self:
		current = null
	TimeManager.tempo = 1.0


func _process(delta: float) -> void:
	if not active():
		if index >= 0:
			index = -1
			TimeManager.tempo = 1.0
		return
	if card == null:
		var hud := get_tree().get_first_node_in_group("hud")
		if hud == null:
			return
		card = TutorialCard.new()
		hud.add_child(card)
	if index < 0:
		_start(_first_open())
		return
	if index >= steps.size():
		return
	TimeManager.tempo = float(steps[index].get("tempo", 1.0))
	if _wait_t > 0.0:
		_wait_t -= delta
		if _wait_t <= 0.0:
			_start(_first_open())
		return
	_track_input()
	_check_t -= delta
	if _check_t > 0.0:
		return
	_check_t = 0.2
	if is_done(steps[index]):
		Tasks.flag("tut_" + String(steps[index]["id"]))
		card.complete()
		_wait_t = 1.6


func _first_open() -> int:
	for i in steps.size():
		if not Tasks.flags.has("tut_" + String(steps[i]["id"])):
			return i
	return steps.size()


func _start(i: int) -> void:
	index = i
	if i >= steps.size():
		Tasks.flag("tutorial_done")
		TimeManager.tempo = 1.0
		card.hide_card()
		EventBus.notify(String(data().get("finish", "")), 6.0)
		return
	var st: Dictionary = steps[i]
	_base = {"thirst": Survival.thirst, "hunger": Survival.hunger}
	_slept = false
	_used.clear()
	card.show_step(st, i + 1, steps.size())   # der Gedanke steht auf der Karte (kein doppelter Gedanke unten)


func _track_input() -> void:
	if String(steps[index].get("done", "")) != "sneak":
		return
	if Input.is_action_pressed("crouch"):
		_used["crouch"] = true
	if Input.is_action_pressed("walk_slow"):
		_used["slow"] = true
	if Input.is_key_pressed(KEY_Y) or Input.is_key_pressed(KEY_X) or Input.is_key_pressed(KEY_Z):
		_used["lean"] = true


## Ist die Bedingung eines Schritts erfüllt?
func is_done(st: Dictionary) -> bool:
	var cond := String(st.get("done", ""))
	var player := get_tree().get_first_node_in_group("player") as Player
	match cond:
		"inside":
			return player != null and Cabin.is_inside(player.global_position)
		"drink":
			_base["thirst"] = minf(float(_base["thirst"]), Survival.thirst)
			return Survival.thirst > float(_base["thirst"]) + 5.0
		"eat":
			_base["hunger"] = minf(float(_base["hunger"]), Survival.hunger)
			return Survival.hunger > float(_base["hunger"]) + 5.0
		"watch":
			return player != null and player.hands != null and player.hands.log_raise > 0.7
		"light":
			return player != null and player.light_shining()
		"sneak":
			return _used.size() >= 2
		"slept":
			return _slept
	if cond.begins_with("flag:"):
		return Tasks.flags.has(cond.substr(5))
	return Tasks.check(cond)
