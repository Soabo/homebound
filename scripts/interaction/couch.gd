class_name Couch
extends Interactable
## Die Couch vor dem Kamin: [E] hinsetzen, das Tablet vom Couchtisch nehmen und Mails/Nachrichten lesen.
## Die Zeit läuft dabei normal weiter – eine ruhige Beschäftigung vor dem Schlafengehen, bis etwas passiert.
## [E] wieder aufstehen. Inhalte: data/tablet/tablet.json. Gelesene Nachrichten sind Teil des Spielstands.

const DATA_PATH := "res://data/tablet/tablet.json"
## Sitzplatz (Hüttenkoordinaten): Füße am Boden, Blick zum Kamin (-x)
const SEAT := Vector3(-2.62, Cabin.FLOOR_Y, 1.75)
const SIT_EYE := 1.02
const TABLET_SPOT := Vector3(-3.78, Cabin.FLOOR_Y + 0.445, 1.88)

var read_ids: Array = []
var sitting: bool = false
var _messages: Array = []
var _tablet: Node3D
var _screen: StandardMaterial3D
var _stand_pos: Vector3
var _stand_rot: float
var _player: Player


func _ready() -> void:
	add_to_group("couch")
	add_to_group("persistent")
	_messages = DataDB.load_json(DATA_PATH).get("messages", [])
	# zum Anvisieren: Sitzfläche der Couch
	var area := Area3D.new()
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(0.9, 0.5, 1.8)
	cs.shape = sh
	cs.position = Vector3(-2.5, Cabin.FLOOR_Y + 0.45, 1.75)
	area.add_child(cs)
	add_child(area)
	# Tablet auf dem Couchtisch
	_tablet = Node3D.new()
	_tablet.position = TABLET_SPOT
	_tablet.rotation_degrees.y = 12.0
	add_child(_tablet)
	BuildKit.box(_tablet, Vector3(0.17, 0.012, 0.25), Vector3.ZERO, BuildKit.color_mat(Color(0.08, 0.08, 0.09), 0.3, 0.4), false)
	_screen = BuildKit.emissive_mat(Color(0.35, 0.55, 0.8), 0.0)
	BuildKit.box(_tablet, Vector3(0.15, 0.002, 0.22), Vector3(0, 0.007, 0), _screen, false)
	# auch das Tablet selbst lässt sich anklicken
	var ta := Area3D.new()
	var tcs := CollisionShape3D.new()
	var tsh := BoxShape3D.new()
	tsh.size = Vector3(0.3, 0.12, 0.36)
	tcs.shape = tsh
	ta.add_child(tcs)
	_tablet.add_child(ta)
	GameState.restore(self)


## Nachrichten, die heute (und bis jetzt) lesbar sind – neueste oben.
func available() -> Array:
	var now := TimeManager.day * 24.0 + TimeManager.hour
	var out: Array = []
	for m: Dictionary in _messages:
		var at := float(m.get("day", 1)) * 24.0 + float(m.get("hour", 0.0))
		if at <= now:
			out.append(m)
	# neuere Tage oben, innerhalb eines Tages in der Reihenfolge der Datei
	var idx := {}
	for i in out.size():
		idx[out[i]["id"]] = i
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var da := int(a.get("day", 1))
		var db := int(b.get("day", 1))
		return da > db if da != db else int(idx[a["id"]]) < int(idx[b["id"]]))
	return out


func unread_count() -> int:
	var n := 0
	for m: Dictionary in available():
		if not read_ids.has(m["id"]):
			n += 1
	return n


func mark_read(id: String) -> void:
	if not read_ids.has(id):
		read_ids.append(id)


func get_prompt(_p: Node) -> String:
	if sitting:
		return ""
	var n := unread_count()
	return "[E] Auf die Couch setzen" + ("  – %d ungelesene Nachricht%s auf dem Tablet" % [n, "" if n == 1 else "en"] if n > 0 else "")


func interact(p: Node) -> void:
	if sitting:
		return
	_player = p as Player
	if _player == null:
		return
	sitting = true
	_stand_pos = _player.global_position
	_stand_rot = _player.rotation.y
	_player.velocity = Vector3.ZERO
	_player.input_locked = true
	_player.set_physics_process(false)
	EventBus.interaction_prompt_changed.emit("")
	# Hinsetzen: zur Couch drehen, absinken, Blick senkt sich aufs Tablet
	var pl := _player
	var target_yaw := pl.rotation.y + wrapf(PI * 0.5 - pl.rotation.y, -PI, PI)
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(pl, "global_position", to_global(SEAT), 0.8)
	tw.tween_property(pl, "rotation:y", target_yaw, 0.6)
	tw.tween_property(pl.head, "position:y", SIT_EYE, 0.8).set_ease(Tween.EASE_OUT)
	tw.tween_property(pl.head, "rotation:x", -0.3, 0.9)
	tw.tween_property(pl.camera, "fov", 75.0, 0.8)
	tw.chain().tween_callback(func() -> void:
		_tablet.visible = false
		get_tree().call_group("tablet_menu", "open", self))
	# Polster: dumpfes Einsinken (bis eine eigene Aufnahme kommt: weiches Rascheln)
	SoundBank.play_at(self, "backpack", to_global(SEAT) + Vector3(0, 0.4, 0), -10.0, 0.8)


## Vom Tablet aus aufgerufen ([E]).
func stand_up() -> void:
	if not sitting or _player == null:
		return
	sitting = false
	_tablet.visible = true
	# Aufstehen: hochdrücken, zurück an den Platz vor der Couch
	var p := _player
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(p, "global_position", _stand_pos, 0.7)
	tw.tween_property(p.head, "rotation:x", 0.0, 0.6)
	tw.tween_property(p.head, "position:y", Player.STAND_HEIGHT - Player.EYE_OFFSET, 0.6)
	tw.chain().tween_callback(func() -> void:
		p.set_physics_process(true)
		p.input_locked = false)


func _process(_delta: float) -> void:
	# ungelesene Nachricht: Tablet-Display leuchtet schwach
	_screen.emission_energy_multiplier = 0.5 if (not sitting and unread_count() > 0 and fmod(TimeManager.hour * 60.0, 2.0) < 1.0) else 0.0


func persist_key() -> String:
	return "couch"


func get_state() -> Dictionary:
	return {"read": read_ids.duplicate()}


func set_state(s: Dictionary) -> void:
	read_ids = (s.get("read", []) as Array).duplicate()
