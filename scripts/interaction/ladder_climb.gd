class_name LadderClimb
extends RefCounted
## Klettern über eine Leiter (Dachboden, Keller): der Spieler wird Punkt für Punkt geführt,
## Kopf wippt mit den Griffen, Sprossen knarzen. Während des Kletterns ist die Physik aus,
## so kommt man durch die Deckenöffnung, ohne an Kanten hängen zu bleiben.


## points: Weltpunkte (Füße des Spielers), der erste ist der Einstieg. look: Punkt, zu dem man beim Klettern schaut.
static func climb(owner: Node, p: Player, points: Array, look: Vector3, head_pitch: float = 0.15) -> void:
	if p == null or p.input_locked or points.is_empty():
		return
	p.input_locked = true
	p.set_physics_process(false)
	p.velocity = Vector3.ZERO
	var face := Vector3(look.x, 0, look.z) - Vector3(p.global_position.x, 0, p.global_position.z)
	var yaw := atan2(-face.x, -face.z) if face.length() > 0.05 else p.rotation.y
	var tw := owner.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(p, "rotation:y", p.rotation.y + wrapf(yaw - p.rotation.y, -PI, PI), 0.3)
	tw.parallel().tween_property(p.head, "rotation:x", head_pitch, 0.3)
	tw.tween_property(p, "global_position", points[0], 0.35)
	var total := 0.35
	for i in range(1, points.size()):
		var a: Vector3 = points[i - 1]
		var b: Vector3 = points[i]
		var d := a.distance_to(b)
		var dur := maxf(d / 1.3, 0.3)
		total += dur
		tw.tween_method(func(t: float) -> void:
			p.global_position = a.lerp(b, t)
			p.head.rotation.z = sin(t * d * 8.0) * 0.03, 0.0, 1.0, dur)
	tw.tween_callback(func() -> void:
		p.head.rotation.z = 0.0
		p.head.rotation.x = 0.0
		p.velocity = Vector3.ZERO
		p.set_physics_process(true)
		p.input_locked = false)
	# Sprossen knarzen
	var n := int(total / 0.38)
	for k in n:
		owner.get_tree().create_timer(0.5 + k * 0.38).timeout.connect(func() -> void:
			if is_instance_valid(owner) and owner.is_inside_tree() and is_instance_valid(p):
				SoundBank.play_at(owner.get_parent(), "step_wood", p.global_position + Vector3(0, 0.3, 0), -9.0, randf_range(0.75, 0.9)))


## Ein unsichtbarer, fester Kasten (zum Anvisieren und als Absturzsicherung an der Öffnung).
static func guard_box(parent: Node3D, size: Vector3, pos: Vector3) -> CollisionShape3D:
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	cs.position = pos
	body.add_child(cs)
	parent.add_child(body)
	return cs
