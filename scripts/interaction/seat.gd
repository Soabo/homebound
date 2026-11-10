class_name Seat
extends Interactable
## Sitzplatz (z. B. Verandabank): [E] hinsetzen, dabei frei umschauen, [E] oder [R] wieder aufstehen.
## Lage in lokalen Koordinaten des Elternknotens (wandert also mit, wenn die Bank versetzt wird).
## Statische Hilfen sit_down/stand_up nutzen auch andere Plätze (Monitorstuhl).

@export var spot: Vector3 = Vector3.ZERO        ## Füße beim Sitzen (lokal)
@export var facing: Vector3 = Vector3(0, 0, 1)  ## Blickrichtung beim Sitzen (lokal)
@export var eye: float = 1.12                   ## Augenhöhe über den Füßen beim Sitzen
@export var area_size: Vector3 = Vector3(1.8, 0.5, 0.45)
@export var area_offset: Vector3 = Vector3.ZERO
@export var label: String = "Bank"

var _player: Player
var _back_pos: Vector3


func _ready() -> void:
	var area := Area3D.new()
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = area_size
	cs.shape = sh
	cs.position = area_offset
	area.add_child(cs)
	add_child(area)


func get_prompt(_p: Node) -> String:
	return "" if _player else "[E] Auf die %s setzen" % label


func interact(p: Node) -> void:
	if _player or not (p is Player):
		return
	_player = p as Player
	_back_pos = _player.global_position
	var fwd := (global_transform.basis * facing).normalized()
	sit_down(self, _player, to_global(spot), fwd, eye, true)
	SoundBank.play_at(self, "floor_creak", to_global(spot) + Vector3(0, 0.4, 0), -14.0, 1.2)
	EventBus.interaction_prompt_changed.emit("[E] Aufstehen")


func _unhandled_input(event: InputEvent) -> void:
	if _player == null or get_tree().paused:
		return
	if (event.is_action_pressed("interact") or event.is_action_pressed("interact_secondary")) and not event.is_echo():
		get_viewport().set_input_as_handled()
		var p := _player
		_player = null
		stand_up(self, p, _back_pos)
		EventBus.interaction_prompt_changed.emit("")


## Spieler setzt sich: dreht sich in Blickrichtung, sinkt ab, Kopf auf Sitzhöhe. look = danach frei umschauen.
static func sit_down(owner: Node, p: Player, feet: Vector3, forward: Vector3, eye_h: float, look: bool) -> Tween:
	p.velocity = Vector3.ZERO
	p.input_locked = true
	p.set_physics_process(false)
	_stop_move(p)
	var yaw := atan2(-forward.x, -forward.z)
	var tw := owner.create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	p.set_meta("seat_tween", tw)
	tw.tween_property(p, "global_position", feet, 0.75)
	tw.tween_property(p, "rotation:y", p.rotation.y + wrapf(yaw - p.rotation.y, -PI, PI), 0.55)
	tw.tween_property(p.head, "position:y", eye_h, 0.75).set_ease(Tween.EASE_OUT)
	tw.tween_property(p.head, "rotation:x", -0.08, 0.6)
	if look:
		tw.chain().tween_callback(func() -> void: p.look_only = true)
	return tw


## Spieler steht auf und tritt zurück an die Stelle, von der er kam.
static func stand_up(owner: Node, p: Player, back: Vector3) -> Tween:
	p.look_only = false
	_stop_move(p)
	var tw := owner.create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	p.set_meta("seat_tween", tw)
	tw.tween_property(p, "global_position", back, 0.6)
	tw.tween_property(p.head, "position:y", Player.STAND_HEIGHT - Player.EYE_OFFSET, 0.55)
	tw.chain().tween_callback(func() -> void:
		p.set_physics_process(true)
		p.input_locked = false)
	return tw


## Wer noch beim Hinsetzen ist und schon wieder aufsteht (E zweimal schnell), würde sonst von zwei
## Bewegungen gleichzeitig gezogen und am Ende im Sitz stecken.
static func _stop_move(p: Player) -> void:
	if not p.has_meta("seat_tween"):
		return
	var old: Variant = p.get_meta("seat_tween")
	if old is Tween and (old as Tween).is_valid():
		(old as Tween).kill()
