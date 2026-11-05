class_name TowerLadder
extends Interactable
## Leiter: unten anvisieren und E = hochklettern, oben an der Kante E = hinunter.
## (Kurze Abblende statt Kletter-Animation.)

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
	if p == null:
		return
	var up := not _player_is_up(p)
	p.input_locked = true
	SoundBank.play_at(get_parent(), "step_wood", p.global_position, -4.0, 0.8)
	await get_tree().create_timer(0.35).timeout
	p.global_position = to_global(top if up else bottom)
	p.velocity = Vector3.ZERO
	SoundBank.play_at(get_parent(), "step_wood", p.global_position, -4.0, 0.9)
	await get_tree().create_timer(0.2).timeout
	p.input_locked = false
