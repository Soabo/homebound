class_name GardenBed
extends Interactable
## Ein Hochbeet (Versorgungs-Manager, Supplies.beds[index]).
##  leer:       [E] säen (gewählte Samen), [R] andere Samen wählen
##  wächst:     [E] gießen (Gießkanne, einmal am Tag) – ungegossen wächst nichts, nach zwei Tagen vertrocknet es
##  reif:       [E] ernten
##  vertrocknet:[E] abräumen
## Unter fremdem Einfluss werden die Blätter grau – die Ernte ist dann verdorben.

const SEEDS := ["seeds_radish", "seeds_carrot", "seed_potato"]

@export var index: int = 0
@export var size: Vector3 = Vector3(2.4, 0.42, 1.4)

var _seed: int = 0
var _plants: Node3D
var _leaf: StandardMaterial3D
var _leaf_grey: StandardMaterial3D
var _leaf_dry: StandardMaterial3D
var _soil_dry: StandardMaterial3D
var _soil_wet: StandardMaterial3D
var _soil: MeshInstance3D


func _ready() -> void:
	add_to_group("garden_bed")
	var frame := BuildKit.tex_mat("planks_h", 0.6, Color(0.9, 0.85, 0.8))
	BuildKit.box(self, size, Vector3(0, size.y * 0.5, 0), frame, true)
	_soil_dry = BuildKit.tex_mat("grass_ground", 0.5, Color(0.3, 0.22, 0.15))
	_soil_wet = BuildKit.tex_mat("grass_ground", 0.5, Color(0.16, 0.11, 0.08))
	_soil = BuildKit.box(self, Vector3(size.x - 0.1, 0.05, size.z - 0.1), Vector3(0, size.y, 0), _soil_dry, false)
	_leaf = BuildKit.color_mat(Color(0.32, 0.55, 0.22), 0.8)
	_leaf_grey = BuildKit.color_mat(Color(0.5, 0.52, 0.55), 0.35, 0.4)
	_leaf_dry = BuildKit.color_mat(Color(0.45, 0.36, 0.2), 1.0)
	_plants = Node3D.new()
	add_child(_plants)
	var area := Area3D.new()
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(size.x, 0.6, size.z)
	cs.shape = sh
	cs.position = Vector3(0, size.y + 0.25, 0)
	area.add_child(cs)
	add_child(area)
	Supplies.changed.connect(refresh)
	refresh()


func _bed() -> Dictionary:
	return Supplies.beds[index]


func _seed_id() -> String:
	# gewählte Sorte, sonst die erste, die man dabei hat
	for k in SEEDS.size():
		var id: String = SEEDS[(_seed + k) % SEEDS.size()]
		if Inventory.count(id) > 0:
			return id
	return ""


func get_prompt(_p: Node) -> String:
	var st := Supplies.bed_state(index)
	var b := _bed()
	var crop: Dictionary = Supplies.config.crops.get(b["crop"], {})
	match st:
		"empty":
			var sid := _seed_id()
			if sid == "":
				return "Hochbeet – leer (keine Samen dabei)"
			return "Hochbeet  [E] %s säen (%d)" % [Inventory.display_name(sid), Inventory.count(sid)]
		"growing":
			var days := float(crop.get("days", 3))
			var left := int(ceil(days - float(b["growth"])))
			var info := "%s – noch %d Tag%s" % [crop.get("name", ""), left, "" if left == 1 else "e"]
			if b["alien"]:
				info += ", die Blätter sind grau"
			if b["watered"]:
				return "Hochbeet: %s  (heute gegossen)" % info
			if Inventory.count("watering_can") <= 0:
				return "Hochbeet: %s  – braucht Wasser (Gießkanne)" % info
			if Inventory.equipped() != "watering_can":
				return "Hochbeet: %s  – Gießkanne in die Hand nehmen (Schnellplatz)" % info
			if Supplies.can_water <= 0:
				return "Hochbeet: %s  – Gießkanne leer, an Regentonne/Wasserhahn füllen (R)" % info
			return "Hochbeet: %s  [E] gießen  (Kanne %d/%d)" % [info, Supplies.can_water, Supplies.config.watering_can_charges]
		"ripe":
			return "Hochbeet: %s reif  [E] ernten" % crop.get("name", "")
		"withered":
			return "Hochbeet: vertrocknet  [E] abräumen"
	return ""


func get_secondary_prompt(_p: Node) -> String:
	if Supplies.bed_state(index) == "empty":
		var have := 0
		for id: String in SEEDS:
			if Inventory.count(id) > 0:
				have += 1
		if have > 1:
			return "[R] andere Samen"
	return ""


func interact(_p: Node) -> void:
	match Supplies.bed_state(index):
		"empty":
			var sid := _seed_id()
			if sid != "" and Supplies.plant(index, sid):
				SoundBank.play_at(self, "step_soil" if SoundBank.has_recording("step_soil") else "pickup", global_position + Vector3(0, 0.5, 0), -6.0, 0.8)
				Fx.burst(get_parent(), global_position + Vector3(0, size.y + 0.05, 0), "dirt", Vector3.UP, 0.6)
				EventBus.notify("Gesät. Jeden Tag gießen!", 2.5)
		"growing":
			if Supplies.water_bed(index):
				SoundBank.play_at(self, "faucet", global_position + Vector3(0, 0.6, 0), -14.0, 1.3)
				Fx.burst(get_parent(), global_position + Vector3(0, size.y + 0.3, 0), "water", Vector3.DOWN, 1.2)
		"ripe", "withered":
			var msg := Supplies.harvest(index)
			if msg != "":
				Fx.burst(get_parent(), global_position + Vector3(0, size.y + 0.1, 0), "dirt", Vector3.UP)
				SoundBank.play_ui(self, "pickup", -6.0)
				EventBus.notify(msg, 3.0)


func secondary_interact(_p: Node) -> void:
	if Supplies.bed_state(index) != "empty":
		return
	for k in range(1, SEEDS.size() + 1):
		var i := (_seed + k) % SEEDS.size()
		if Inventory.count(SEEDS[i]) > 0:
			_seed = i
			EventBus.notify("Samen: %s" % Inventory.display_name(SEEDS[i]), 1.5)
			return


## Pflanzen passend zum Zustand zeigen.
func refresh() -> void:
	if not is_inside_tree():
		return
	for c in _plants.get_children():
		c.queue_free()
	var b := _bed()
	var st := Supplies.bed_state(index)
	_soil.material_override = _soil_wet if b.get("watered", false) else _soil_dry
	if st == "empty":
		return
	var crop: Dictionary = Supplies.config.crops.get(b["crop"], {})
	var t := clampf(float(b["growth"]) / maxf(float(crop.get("days", 3)), 1.0), 0.0, 1.0)
	var mat := _leaf_dry if st == "withered" else (_leaf_grey if b["alien"] else _leaf)
	var rng := RandomNumberGenerator.new()
	rng.seed = index * 97 + 13
	var top := size.y + 0.03
	for i in 5:
		for j in 2:
			var at := Vector3(-0.9 + i * 0.45, top, -0.3 + j * 0.6)
			var h := lerpf(0.06, 0.32, t) * (0.5 if st == "withered" else 1.0)
			var plant := Node3D.new()
			_plants.add_child(plant)
			plant.position = at
			plant.rotation.y = rng.randf() * TAU
			for k in 3:
				var leaf := BuildKit.box(plant, Vector3(0.025, h, 0.08 * (0.5 + t)), Vector3(0, h * 0.5, 0), mat, false,
						Vector3(rng.randf_range(-25, 25) + (40 if st == "withered" else 0), k * 60.0, 0))
				leaf.position.x = (k - 1) * 0.02
			if st == "ripe" and not b["alien"]:
				# reife Früchte schauen aus der Erde
				match String(b["crop"]):
					"radish": BuildKit.sphere(plant, 0.03, Vector3(0, 0.015, 0), BuildKit.color_mat(Color(0.85, 0.15, 0.25), 0.5), Vector3.ONE, 6)
					"carrot": BuildKit.cylinder(plant, 0.025, 0.04, Vector3(0, 0.01, 0), BuildKit.color_mat(Color(0.95, 0.5, 0.1), 0.6), false, Vector3.ZERO, 0.02, 6)
					"potato": BuildKit.sphere(plant, 0.035, Vector3(0.05, 0.01, 0), BuildKit.color_mat(Color(0.6, 0.45, 0.28), 0.9), Vector3(1.2, 0.8, 1.0), 6)
