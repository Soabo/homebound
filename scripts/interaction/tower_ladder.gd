class_name TowerLadder
extends Interactable
## Leiter: unten anvisieren und E = hochklettern, oben an der Kante E = hinunter.
## Mit Kletter-Bewegung (Sprosse für Sprosse, Kopf wippt).

var bottom: Vector3 = Vector3.ZERO
var top: Vector3 = Vector3.ZERO


func _ready() -> void:
	for at: Vector3 in [bottom + Vector3(0, 0.9, -0.6), top + Vector3(0, 0.4, 0.55)]:
		var body := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = Vector3(0.8, 1.4, 0.3)
		cs.shape = sh
		cs.position = at
		body.add_child(cs)
		body.collision_layer = 1
		add_child(body)


func _player_is_up(player: Node3D) -> bool:
	return player.global_position.y > to_global(top).y - 1.0


func get_prompt(player: Node) -> String:
	return "[E] Leiter hinunterklettern" if _player_is_up(player as Node3D) else "[E] Leiter hochklettern"


func interact(player: Node) -> void:
	var p := player as Player
	if p == null or p.input_locked:
		return
	var up := not _player_is_up(p)
	p.input_locked = true
	p.set_physics_process(false)
	p.velocity = Vector3.ZERO
	# Klettern: an die Leiter treten, Sprosse für Sprosse hinauf bzw. hinunter (Kopf wippt mit den Griffen),
	# oben über die Kante steigen. Blick zur Leiter bzw. beim Hinuntersteigen zur Leiter gewandt.
	var lb := to_global(bottom)
	var lt := to_global(top)
	var rung_x := Vector3(lb.x, 0, lb.z).lerp(Vector3(lt.x, 0, lt.z), 0.45)
	var foot_bottom := Vector3(rung_x.x, lb.y, rung_x.z)
	var foot_top := Vector3(rung_x.x, lt.y - 1.0, rung_x.z)
	var face := Vector3(lt.x, 0, lt.z) - Vector3(lb.x, 0, lb.z)
	var yaw := atan2(-face.x, -face.z)
	var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(p, "rotation:y", p.rotation.y + wrapf(yaw - p.rotation.y, -PI, PI), 0.3)
	tw.parallel().tween_property(p.head, "rotation:x", 0.15 if up else -0.35, 0.3)
	var path: Array = [foot_bottom, foot_top, lt] if up else [lt, foot_top, foot_bottom, lb]
	tw.tween_property(p, "global_position", path[0], 0.35)
	for i in range(1, path.size()):
		var a: Vector3 = path[i - 1]
		var b: Vector3 = path[i]
		var d := a.distance_to(b)
		var dur := maxf(d / 1.4, 0.3)
		tw.tween_method(func(t: float) -> void:
			p.global_position = a.lerp(b, t)
			# Griff für Griff: Kopf wippt leicht
			p.head.rotation.z = sin(t * d * 8.0) * 0.03, 0.0, 1.0, dur)
	tw.tween_callback(func() -> void:
		p.head.rotation.z = 0.0
		p.head.rotation.x = 0.0
		p.velocity = Vector3.ZERO
		p.set_physics_process(true)
		p.input_locked = false)
	# Sprossengeräusche während des Kletterns
	var total := 0.0
	for i in range(1, path.size()):
		total += maxf((path[i - 1] as Vector3).distance_to(path[i]) / 1.4, 0.3)
	var n := int(total / 0.35)
	for k in n:
		get_tree().create_timer(0.65 + k * 0.35).timeout.connect(func() -> void:
			if is_inside_tree():
				SoundBank.play_at(get_parent(), "step_wood", p.global_position + Vector3(0, 0.3, 0), -8.0, randf_range(0.8, 0.95)))
