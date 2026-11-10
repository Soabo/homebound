class_name OrganismNode
extends Interactable
## Der Knoten des Organismus in der Höhle – die Quelle der Wucherungen (Phase 8, GDD 11.2).
## Mit der Axt zerschlagen (6 Hiebe): danach wächst nichts mehr nach, und es bleiben Proben zurück.

const MAX_HP := 6

var hp: int = MAX_HP
var _mass: Node3D
var _mat: StandardMaterial3D
var _light: OmniLight3D
var _t: float = 0.0


func _ready() -> void:
	add_to_group("axe_target")
	_mass = Node3D.new()
	add_child(_mass)
	_mat = StandardMaterial3D.new()
	_mat.albedo_texture = TextureFactory.get_texture("alien_skin")
	_mat.albedo_color = Color(0.55, 0.48, 0.6)
	_mat.roughness = 0.25
	_mat.emission_enabled = true
	_mat.emission = Color(0.6, 0.35, 0.9)
	_mat.emission_energy_multiplier = 0.4
	_mat.uv1_triplanar = true
	BuildKit.sphere(_mass, 0.8, Vector3(0, 0.6, 0), _mat, Vector3(1.2, 0.85, 1.0), 14)
	for k in 5:
		var a := TAU * k / 5.0
		BuildKit.sphere(_mass, 0.3, Vector3(cos(a) * 0.75, 0.35 + (k % 2) * 0.3, sin(a) * 0.6), _mat, Vector3(1.0, 0.8, 1.0), 8)
	# Ranken zu Boden und Wänden
	var vein := BuildKit.color_mat(Color(0.32, 0.3, 0.33), 0.35, 0.1)
	for k in 10:
		var a := TAU * k / 10.0
		var mi := BuildKit.cylinder(self, 0.05, 2.4, Vector3(cos(a) * 1.4, 0.15, sin(a) * 1.4), vein, false, Vector3(0, -rad_to_deg(a), 82), 0.02, 6)
		mi.name = "Tendril_%d" % k
	_light = OmniLight3D.new()
	_light.position = Vector3(0, 1.2, 0)
	_light.light_color = Color(0.7, 0.45, 1.0)
	_light.omni_range = 7.0
	_light.light_energy = 1.2
	add_child(_light)
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 1.0
	cs.shape = sh
	cs.position = Vector3(0, 0.6, 0)
	body.add_child(cs)
	add_child(body)
	_apply_alive()
	WorldState.changed.connect(_apply_alive)


func _apply_alive() -> void:
	var alive := WorldState.source_alive
	_mass.scale = Vector3.ONE if alive else Vector3(1.0, 0.25, 1.0)
	_light.visible = alive
	_mat.emission_energy_multiplier = 0.4 if alive else 0.0


func _process(delta: float) -> void:
	if not WorldState.source_alive:
		return
	_t += delta
	var beat := 1.0 + sin(_t * 2.2) * 0.04 + maxf(sin(_t * 4.4), 0.0) * 0.03
	_mass.scale = Vector3(beat, beat * 0.97, beat)
	_light.light_energy = 0.9 + sin(_t * 2.2) * 0.3


func get_prompt(_player: Node) -> String:
	if not WorldState.source_alive:
		return "Der Knoten – zerfallen"
	if Inventory.equipped() == "axe":
		return "[Linksklick] Knoten zerschlagen  (%d/%d)" % [MAX_HP - hp, MAX_HP]
	return "Ein pulsierender Knoten. Mit der Axt in der Hand ließe er sich zerschlagen."


## Von den Händen aufgerufen, wenn mit der Axt zugeschlagen wird.
func axe_hit(_player: Node) -> void:
	if not WorldState.source_alive:
		return
	hp -= 1
	CreatureSounds.play(get_parent(), "pain", global_position + Vector3(0, 0.8, 0), 0.0, randf_range(0.45, 0.6))
	EventBus.screen_shake.emit(0.1)
	_mass.scale *= 0.92
	if hp <= 0:
		WorldState.kill_source()
		_drop_samples()


func _drop_samples() -> void:
	var p := ItemPickup.new()
	p.name = "OrganismSamples"
	p.item_id = "organism_sample"
	p.amount = 2
	p.per_take = 2
	p.collider_size = Vector3(0.6, 0.3, 0.6)
	p.collider_offset = Vector3(-1.2, 0.15, 0.4)
	add_child(p)
	var v := Node3D.new()
	p.add_child(v)
	BuildKit.sphere(v, 0.1, Vector3(-1.2, 0.06, 0.4), _mat, Vector3(1.3, 0.5, 1.0), 8)
	p.visuals.append(v)


## Eine Wucherung im Wald: verlangsamt und verletzt, wer hindurchläuft. Mit der Axt entfernbar.
class Patch extends Interactable:
	var patch_id: int = 0
	var hp: int = 3
	var _player: Player

	func _ready() -> void:
		add_to_group("axe_target")
		add_to_group("organism_patch")
		var vein := BuildKit.color_mat(Color(0.3, 0.28, 0.31), 0.3, 0.1)
		var glow := BuildKit.emissive_mat(Color(0.75, 0.55, 1.0), 1.2)
		var r := RandomNumberGenerator.new()
		r.seed = patch_id * 31 + 7
		# Geflecht aus Fäden mit Knoten, flach am Boden
		for k in 14:
			var a := r.randf() * TAU
			var len := r.randf_range(0.8, 2.2)
			var mid := Vector3(cos(a), 0, sin(a)) * len * 0.45
			var g := Terrain.height_at(global_position.x + mid.x, global_position.z + mid.z) - global_position.y
			BuildKit.box(self, Vector3(len, 0.04, 0.05), mid + Vector3(0, g + 0.03, 0), vein, false, Vector3(0, -rad_to_deg(a), 0))
		for k in 5:
			var p := Vector3(r.randf_range(-1, 1), 0, r.randf_range(-1, 1))
			var g := Terrain.height_at(global_position.x + p.x, global_position.z + p.z) - global_position.y
			BuildKit.sphere(self, r.randf_range(0.08, 0.16), p + Vector3(0, g + 0.05, 0), glow if k % 2 == 0 else vein, Vector3(1.0, 0.6, 1.0), 8)
		# nur für das Anvisieren (Area), man soll hindurchlaufen können
		var sh := BoxShape3D.new()
		sh.size = Vector3(2.2, 0.3, 2.2)
		var area := Area3D.new()
		var acs := CollisionShape3D.new()
		acs.shape = sh
		acs.position = Vector3(0, 0.15, 0)
		area.add_child(acs)
		add_child(area)

	func get_prompt(_p: Node) -> String:
		if Inventory.count("root_salt") > 0:
			return "[E] Wurzelsalz streuen (tötet auch Wucherungen in der Nähe)"
		if Inventory.equipped() == "axe":
			return "[Linksklick] Wucherung weghacken"
		return "Graue Wucherung – mit der Axt entfernen"

	## Wurzelsalz (Forschung): diese und alle Wucherungen im Umkreis sterben ab.
	func interact(_p: Node) -> void:
		if not Inventory.remove("root_salt", 1):
			return
		var r := float(Research.gadget("root_salt", "radius", 5.0))
		var n := 0
		for q in get_tree().get_nodes_in_group("organism_patch"):
			var pp := q as Node3D
			if pp == self or pp.global_position.distance_to(global_position) < r:
				WorldState.remove_patch(int(pp.get("patch_id")))
				pp.queue_free()
				n += 1
		SoundBank.play_at(get_parent(), "static", global_position + Vector3(0, 0.3, 0), -6.0, 0.5)
		EventBus.notify("Das Geflecht zischt, wird schwarz und zerfällt (%d)." % n, 3.0)
		Tasks.flag("root_salt_used")

	func axe_hit(_p: Node) -> void:
		hp -= 1
		SoundBank.play_at(get_parent(), "chop", global_position + Vector3(0, 0.3, 0), -4.0)
		if hp <= 0:
			if Research.seen.find("organism_sample") < 0 or randf() < 0.3:
				Inventory.add("organism_sample", 1)
			elif randf() < 0.25:
				Inventory.add("organism_node", 1)  # Knotenherz (Forschung 2.0)
			WorldState.remove_patch(patch_id)
			queue_free()

	func _physics_process(delta: float) -> void:
		if _player == null:
			_player = get_tree().get_first_node_in_group("player") as Player
			return
		var d := Vector2(_player.global_position.x - global_position.x, _player.global_position.z - global_position.z).length()
		if d < 1.5 and not GameState.dead:
			_player.hazard = 1.0
			if Inventory.count("spore_mask") <= 0:
				_player.health = maxf(_player.health - 3.0 * delta, 1.0)
