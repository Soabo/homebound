class_name Apparition
extends Node3D
## Kurzer Auftritt der Kreatur, ohne Angriff (Christians Wunsch: unheimlich statt bedrohlich).
## Arten:
##  edge    – steht reglos am Waldrand. Wer direkt hinschaut, sieht sie mit einem Lichtblitz verschwinden.
##  window  – ein Gesicht am Fenster des Zimmers, in dem man ist. Schaut man hin, duckt es sich weg.
##  inside  – nach dem Aufwachen steht sie im Haus. Sobald man sie sieht: Teleporterblitz, weg.
##            Zurück bleiben Schlammspuren auf dem Boden.
##  forest  – tagsüber zwischen den Bäumen, folgt in großem Abstand. Kommt man näher oder schaut direkt hin: weg.

const LOOK_DIRECT := 0.94     ## cos(~20°): direkt angeschaut
const LOOK_SEEN := 0.6        ## cos(~53°): im Blickfeld (auch aus dem Augenwinkel)
## Stellen im Haus, an denen sie nach dem Aufwachen stehen kann (Boden, Blickrichtung zum Schlafzimmer)
const INSIDE_SPOTS := [Vector3(-2.4, 0.45, 0.9), Vector3(0.8, 0.45, 2.7), Vector3(-4.3, 0.45, 2.8), Vector3(4.4, 0.45, 2.2)]
const BEDROOM_DOOR := Vector3(-2.5, 0.45, -1.2)

var kind: String = "edge"
var lifetime: float = 60.0
var _t: float = 0.0
var _player: Player
var _model: Node3D
var _parts: Dictionary
var _direct_time: float = 0.0
var _seen_time: float = 0.0
var _seen_once: bool = false
var _gone: bool = false
var _duck: float = -1.0


## Erzeugt einen Auftritt. Gibt null zurück, wenn gerade kein passender Ort da ist.
static func spawn(scene: Node, what: String) -> Apparition:
	var player := scene.get_tree().get_first_node_in_group("player") as Player
	if player == null:
		return null
	var a := Apparition.new()
	a.kind = what
	a.name = "Apparition"
	var pos := Vector3.ZERO
	var look_at_pos := player.global_position
	match what:
		"edge":
			# Waldrand auf der Seite, auf die der Spieler gerade NICHT schaut – er soll sie erst im Augenwinkel finden
			var fwd := -player.global_transform.basis.z
			var ang := atan2(fwd.z, fwd.x) + randf_range(0.9, 1.6) * (1.0 if randf() < 0.5 else -1.0)
			var d := randf_range(26.0, 34.0)
			pos = Creature._ground(Vector3(cos(ang) * d, 0, sin(ang) * d))
			a.lifetime = 90.0
		"forest":
			var p := player.global_position
			var back := player.global_transform.basis.z
			back.y = 0.0
			var side := back.rotated(Vector3.UP, randf_range(-1.0, 1.0)).normalized()
			pos = Creature._ground(p + side * randf_range(28.0, 36.0))
			if absf(pos.x) > WorldMap.limit() - 5.0 or absf(pos.z) > WorldMap.limit() - 5.0:
				return null
			a.lifetime = 75.0
		"window":
			var w := _window_near(scene, player.global_position)
			if w == null:
				return null
			var out: Vector3 = w.call("outside_point")
			var inner: Vector3 = w.call("inside_point")
			var dir := (out - inner)
			dir.y = 0.0
			dir = dir.normalized()
			# Kopf auf Fensterhöhe, knapp vor der Scheibe
			pos = Vector3(out.x, 0.0, out.z) - dir * 0.25
			pos.y = Terrain.height_at(pos.x, pos.z) - 0.35
			look_at_pos = inner
			a.lifetime = 40.0
		"inside":
			var best: Array = []
			for s: Vector3 in INSIDE_SPOTS:
				if s.distance_to(player.global_position) > 3.0:
					best.append(s)
			if best.is_empty():
				return null
			pos = best[randi() % best.size()]
			look_at_pos = BEDROOM_DOOR
			a.lifetime = 120.0
	scene.add_child(a)
	a.global_position = pos
	var tgt := Vector3(look_at_pos.x, pos.y, look_at_pos.z)
	if tgt.distance_to(pos) > 0.1:
		a.look_at(tgt, Vector3.UP)
		a.rotate_y(PI)
	if what == "inside":
		Traces.mud_trail(scene, pos, BEDROOM_DOOR)
	return a


static func _window_near(scene: Node, p: Vector3) -> Node3D:
	var best: Node3D = null
	var best_d := 1e9
	for w in scene.get_tree().get_nodes_in_group("entry_point"):
		if not w is CabinWindow:
			continue
		var d := (w.call("inside_point") as Vector3).distance_to(p)
		if d < best_d and d > 1.6 and d < 7.0:
			best_d = d
			best = w
	return best


func _ready() -> void:
	add_to_group("apparition")
	_player = get_tree().get_first_node_in_group("player") as Player
	_model = Node3D.new()
	add_child(_model)
	_parts = Creature.build_model(_model)
	get_tree().call_group("nature_ambience", "silence_for", 30.0)


func _process(delta: float) -> void:
	if _gone or _player == null:
		return
	_t += delta
	# kaum Bewegung: leichtes Schwanken, der Kopf neigt sich langsam
	_model.rotation.z = sin(_t * 0.7) * 0.02
	var head := _parts.get("head") as Node3D
	if head:
		head.rotation.z = sin(_t * 0.35) * 0.25
	if _duck >= 0.0:
		_duck += delta
		_model.position.y = -_duck * _duck * 18.0
		if _duck > 0.35:
			queue_free()
		return
	if _t > lifetime:
		_vanish(kind == "inside" and _seen_once)
		return
	var look := _look_amount()
	if look >= LOOK_SEEN:
		_seen_once = true
	if look >= LOOK_DIRECT:
		_direct_time += delta
	else:
		_direct_time = maxf(_direct_time - delta, 0.0)
	var dist := _player.global_position.distance_to(global_position)
	match kind:
		"window":
			if _direct_time > 0.25:
				_duck = 0.0
				SoundBank.play_at(get_parent(), "scratch", global_position + Vector3(0, 1.5, 0), -6.0)
		"inside":
			# einen Augenblick wirklich zu sehen – dann der Blitz
			if look >= LOOK_SEEN:
				_seen_time += delta
			if _direct_time > 0.35 or _seen_time > 0.7:
				_vanish(true)
		"edge":
			if _direct_time > 0.4 or dist < 14.0:
				_vanish(true)
		"forest":
			if _direct_time > 0.6 or dist < 18.0:
				_vanish(true)


## Wie direkt schaut der Spieler her (cos des Winkels; 0 = nicht sichtbar, verdeckt oder zu weit).
func _look_amount() -> float:
	var cam := _player.camera.global_transform
	var head := global_position + Vector3(0, 1.9 if kind != "window" else 2.2, 0)
	var to := head - cam.origin
	if to.length() > 60.0:
		return 0.0
	var c := (-cam.basis.z).dot(to.normalized())
	if c < LOOK_SEEN:
		return c
	var q := PhysicsRayQueryParameters3D.create(cam.origin, head)
	q.exclude = [_player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty() and (hit["position"] as Vector3).distance_to(head) > 0.8:
		# durch eine Fensterscheibe sieht man trotzdem hindurch
		var n := hit["collider"] as Node
		var through_glass := false
		while n:
			if n is CabinWindow:
				through_glass = true
				break
			n = n.get_parent()
		if not through_glass:
			return 0.0
	return c


func _vanish(with_flash: bool) -> void:
	if _gone:
		return
	_gone = true
	if with_flash:
		flash(get_parent(), global_position + Vector3(0, 1.4, 0), kind == "inside")
	queue_free()


## Kurzer Teleporterblitz: grelles, kaltes Licht, ein schrumpfender Leuchtkörper, ein elektrisches Knistern.
static func flash(parent: Node, pos: Vector3, scare: bool = false) -> void:
	var root := Node3D.new()
	parent.add_child(root)
	root.global_position = pos
	var light := OmniLight3D.new()
	light.light_color = Color(0.6, 0.85, 1.0)
	light.omni_range = 9.0
	light.light_energy = 9.0
	root.add_child(light)
	var mat := BuildKit.emissive_mat(Color(0.75, 0.92, 1.0), 6.0)
	var core := BuildKit.sphere(root, 0.6, Vector3.ZERO, mat, Vector3(0.5, 1.6, 0.5), 12)
	var tw := root.create_tween()
	tw.set_parallel(true)
	tw.tween_property(light, "light_energy", 0.0, 0.35).set_ease(Tween.EASE_IN)
	tw.tween_property(core, "scale", Vector3(0.02, 2.6, 0.02), 0.22).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(root.queue_free)
	SoundBank.play_at(parent, "static", pos, 0.0, 2.2)
	SoundBank.play_at(parent, "signal", pos, -4.0, 2.6)
	if scare:
		SoundBank.play_ui(parent, "sting_creature", -4.0)
	EventBus.screen_shake.emit(0.12)
