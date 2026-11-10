class_name ScrapSpot
extends Interactable
## Eine Metall-Fundstelle im Wald. Nur mit der Blechschere in der Hand abbaubar, danach weg.

@export var spot_id: int = 0
@export var kind: String = "exhaust"
var _busy := false


func _ready() -> void:
	var rust := BuildKit.tex_mat("metal", 0.3, Color(0.75, 0.42, 0.26), 0.5)
	var dark := BuildKit.tex_mat("metal", 0.3, Color(0.4, 0.38, 0.36), 0.5)
	var moss := BuildKit.tex_mat("moss", 0.4)
	var size := Vector3(1.2, 0.6, 0.8)
	match kind:
		"exhaust":
			BuildKit.cylinder(self, 0.05, 1.4, Vector3(0, 0.06, 0), rust, false, Vector3(0, 0, 88), -1.0, 8)
			BuildKit.cylinder(self, 0.13, 0.45, Vector3(0.35, 0.12, 0), rust, false, Vector3(0, 0, 90), -1.0, 10)
			BuildKit.cylinder(self, 0.04, 0.3, Vector3(-0.8, 0.12, 0.05), dark, false, Vector3(0, 30, 70), -1.0, 6)
			size = Vector3(1.6, 0.4, 0.4)
		"engine":
			BuildKit.box(self, Vector3(0.7, 0.5, 0.5), Vector3(0, 0.22, 0), dark, false, Vector3(0, 0, 6))
			for k in 4:
				BuildKit.cylinder(self, 0.06, 0.12, Vector3(-0.24 + k * 0.16, 0.52, 0), rust, false, Vector3.ZERO, -1.0, 8)
			BuildKit.cylinder(self, 0.16, 0.06, Vector3(0.38, 0.2, 0), rust, false, Vector3(0, 0, 90), -1.0, 12)
			size = Vector3(0.9, 0.7, 0.7)
		"silo":
			# gebogenes Stück Silowand, halb im Boden
			for k in 6:
				var a := deg_to_rad(-40.0 + k * 16.0)
				BuildKit.box(self, Vector3(0.36, 1.1, 0.03), Vector3(sin(a) * 1.0, 0.45, cos(a) * 1.0 - 1.0), rust, false, Vector3(0, rad_to_deg(a), 8))
			size = Vector3(1.8, 1.0, 0.8)
		"tractor":
			BuildKit.cylinder(self, 0.45, 0.25, Vector3(0, 0.2, 0), BuildKit.color_mat(Color(0.08, 0.08, 0.08), 0.9), false, Vector3(70, 0, 0), -1.0, 16)
			BuildKit.cylinder(self, 0.25, 0.27, Vector3(0, 0.2, 0), BuildKit.color_mat(Color(0.7, 0.2, 0.1), 0.6, 0.3), false, Vector3(70, 0, 0), -1.0, 12)
			BuildKit.box(self, Vector3(0.9, 0.08, 0.2), Vector3(0.6, 0.08, 0.3), rust, false, Vector3(0, 30, 0))
			size = Vector3(1.4, 0.6, 1.0)
		"barrel":
			BuildKit.cylinder(self, 0.28, 0.85, Vector3(0, 0.28, 0), rust, false, Vector3(85, 0, 0), -1.0, 14)
			BuildKit.box(self, Vector3(0.5, 0.01, 0.4), Vector3(0.1, 0.005, 0.5), BuildKit.color_mat(Color(0.05, 0.05, 0.04), 0.1), false)
			size = Vector3(1.0, 0.6, 1.0)
	# etwas Moos und Laub darauf
	BuildKit.box(self, Vector3(0.3, 0.02, 0.2), Vector3(0.05, size.y * 0.9, 0), moss, false, Vector3(0, 30, 5))
	var area := Area3D.new()
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	cs.position = Vector3(0, size.y * 0.5, 0)
	area.add_child(cs)
	add_child(area)


func _title() -> String:
	return String(Supplies.config.scrap_kinds.get(kind, {}).get("name", "Altmetall"))


func get_prompt(_p: Node) -> String:
	if Inventory.count("tin_snips") <= 0:
		return "%s – mit einer Blechschere ließe sich Metall abtrennen" % _title()
	if Inventory.equipped() != "tin_snips":
		var slot := Inventory.slot_of("tin_snips")
		return "%s – Blechschere in die Hand nehmen%s" % [_title(), (" (Taste %d)" % (slot + 1)) if slot >= 0 else ""]
	return "%s  [Linksklick / E] Metall abschneiden" % _title()


func interact(player: Node) -> void:
	if _busy or Inventory.equipped() != "tin_snips":
		return
	_busy = true
	var p := player as Player
	if p:
		p.input_locked = true
		p.hands.working = true
	for i in 4:
		if p:
			p.hands.tool_swing(0.5)
		await get_tree().create_timer(0.25).timeout
		SoundBank.play_at(self, "collect_metal", global_position + Vector3(0, 0.4, 0), -2.0, randf_range(0.9, 1.15))
		Fx.burst(get_parent(), global_position + Vector3(randf_range(-0.2, 0.2), 0.4, randf_range(-0.2, 0.2)), "metal", Vector3.UP)
		EventBus.noise_made.emit(global_position, 12.0)
		await get_tree().create_timer(0.3).timeout
	if p and is_instance_valid(p):
		p.input_locked = false
		p.hands.working = false
	var msg := Supplies.harvest_spot(spot_id)
	if msg != "":
		EventBus.notify(msg, 3.0)
	_busy = false
