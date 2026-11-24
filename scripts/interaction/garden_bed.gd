class_name GardenBed
extends Interactable
## Ein Hochbeet (Versorgungs-Manager, Supplies.beds[index]).
##  leer:       [E] säen (gewählte Samen), [R] andere Samen wählen
##  wächst:     [Linksklick] oder [E] gießen (Gießkanne in der Hand, einmal am Tag) – ungegossen wächst nichts, nach zwei Tagen vertrocknet es
##  reif:       [E] ernten
##  vertrocknet:[E] abräumen
## Unter fremdem Einfluss werden die Blätter grau – die Ernte ist dann verdorben.
## Spätherbst (Christian 24.11.): Über jedem Beet steht ein Folientunnel (Metallbögen + Folie, Enden gerafft) – deshalb
## wächst auch bei Frost und Schnee etwas. Säen, gießen und ernten geht durch die hochgeschlagene Seite.

## Folientunnel: Höhe über der Erde, Zahl der Bögen
const TUNNEL_HEIGHT := 0.62
const TUNNEL_HOOPS := 4

const SEEDS := ["seeds_radish", "seeds_carrot", "seed_potato", "alien_seeds"]

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
	_build_tunnel()
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


## Folientunnel: halbrunde Bögen quer über das Beet, eine Folie darüber (durchscheinend, Schnee bleibt oben liegen),
## an den Enden zusammengerafft und an einen Pflock gebunden.
func _build_tunnel() -> void:
	var tunnel := Node3D.new()
	tunnel.name = "Tunnel"
	add_child(tunnel)
	var top := size.y + 0.02
	var half_w := size.z * 0.5 - 0.04
	var half_l := size.x * 0.5 - 0.05
	var metal := BuildKit.color_mat(Color(0.62, 0.64, 0.66), 0.45, 0.6)
	# Bögen (Querschnitt: Halbellipse, Breite = Beet, Höhe TUNNEL_HEIGHT)
	for i in TUNNEL_HOOPS:
		var x := lerpf(-half_l + 0.08, half_l - 0.08, float(i) / (TUNNEL_HOOPS - 1))
		var pts := HandKit.arc(Vector3(x, top, 0), half_w, 180.0, 0.0, 12, Vector3(0, 0, 1), Vector3.UP, TUNNEL_HEIGHT)
		HandKit.tube(tunnel, pts, 0.008, metal, 5)
	# Firstlatte
	HandKit.tube(tunnel, PackedVector3Array([Vector3(-half_l, top + TUNNEL_HEIGHT, 0), Vector3(half_l, top + TUNNEL_HEIGHT, 0)]), 0.006, metal, 4)
	# Folie: Halbellipse entlang x, an der Südseite (+z) unten etwas hochgeschlagen
	var foil := StandardMaterial3D.new()
	foil.albedo_color = Color(0.86, 0.9, 0.93, 0.3)
	foil.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	foil.cull_mode = BaseMaterial3D.CULL_DISABLED
	foil.roughness = 0.15
	foil.metallic_specular = 0.7
	SnowCover.register(foil)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	const SEG := 14
	const ROLL := 3   # unterste Segmente auf der Südseite fehlen (hochgeschlagen)
	for k in SEG:
		if k < ROLL:
			continue
		var a0 := PI * float(k) / SEG
		var a1 := PI * float(k + 1) / SEG
		var p0 := Vector3(0, top + sin(a0) * TUNNEL_HEIGHT, cos(a0) * half_w)
		var p1 := Vector3(0, top + sin(a1) * TUNNEL_HEIGHT, cos(a1) * half_w)
		var n0 := Vector3(0, sin(a0), cos(a0))
		var n1 := Vector3(0, sin(a1), cos(a1))
		for v: Array in [[p0, n0, -1.0], [p1, n1, -1.0], [p1, n1, 1.0], [p0, n0, -1.0], [p1, n1, 1.0], [p0, n0, 1.0]]:
			var pp: Vector3 = v[0]
			st.set_normal(v[1])
			st.add_vertex(Vector3(half_l * float(v[2]), pp.y, pp.z))
	# Enden: gerafft (flache Halbellipse, etwas nach innen gezogen)
	for side: float in [-1.0, 1.0]:
		for k in SEG:
			var a0 := PI * float(k) / SEG
			var a1 := PI * float(k + 1) / SEG
			var c := Vector3(side * (half_l + 0.04), top, 0)
			st.set_normal(Vector3(side, 0, 0))
			st.add_vertex(c)
			st.add_vertex(Vector3(side * half_l, top + sin(a0) * TUNNEL_HEIGHT, cos(a0) * half_w))
			st.add_vertex(Vector3(side * half_l, top + sin(a1) * TUNNEL_HEIGHT, cos(a1) * half_w))
	var mi := MeshInstance3D.new()
	mi.name = "Foil"
	mi.mesh = st.commit()
	mi.material_override = foil
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	tunnel.add_child(mi)
	# hochgeschlagene Rolle auf der Südseite und Pflöcke an den Enden
	var a_roll := PI * float(ROLL) / SEG
	var roll_y := top + sin(a_roll) * TUNNEL_HEIGHT
	var roll_z := cos(a_roll) * half_w
	HandKit.tube(tunnel, PackedVector3Array([Vector3(-half_l, roll_y, roll_z + 0.02), Vector3(half_l, roll_y, roll_z + 0.02)]), 0.03,
			BuildKit.color_mat(Color(0.78, 0.82, 0.84, 0.8), 0.3), 8)
	var peg := BuildKit.tex_mat("bark", 0.6)
	for side: float in [-1.0, 1.0]:
		# Pflock leicht nach Norden versetzt (südlich am Ostbeet steht die Gießkanne)
		BuildKit.box(tunnel, Vector3(0.04, 0.3, 0.04), Vector3(side * (size.x * 0.5 + 0.2), 0.12, -0.35), peg, false)
		HandKit.tube(tunnel, PackedVector3Array([Vector3(side * (half_l + 0.04), top + 0.05, 0), Vector3(side * (size.x * 0.5 + 0.2), 0.24, -0.35)]),
				0.01, BuildKit.color_mat(Color(0.85, 0.88, 0.9, 0.7), 0.4), 4)


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
			if bool(crop.get("no_water", false)):
				return "Hochbeet: %s  (wächst von selbst, braucht kein Wasser)" % info
			if b["watered"]:
				return "Hochbeet: %s  (heute gegossen)" % info
			if Inventory.count("watering_can") <= 0:
				return "Hochbeet: %s  – braucht Wasser (Gießkanne)" % info
			if Inventory.equipped() != "watering_can":
				return "Hochbeet: %s  – Gießkanne in die Hand nehmen (Schnellplatz)" % info
			if Supplies.can_water <= 0:
				return "Hochbeet: %s  – Gießkanne leer, an Regentonne/Wasserhahn füllen (Rechtsklick)" % info
			return "Hochbeet: %s  [Linksklick halten] gießen  (Kanne %d/%d)" % [info, Supplies.can_water, Supplies.config.watering_can_charges]
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
			# gegossen wird mit der Kanne in der Hand per Linksklick halten (PlayerHands._update_bed_pour)
			if needs_water() and Inventory.equipped() == "watering_can":
				EventBus.notify("Zum Gießen Linksklick gedrückt halten.", 2.0)
		"ripe", "withered":
			var msg := Supplies.harvest(index)
			if msg != "":
				Fx.burst(get_parent(), global_position + Vector3(0, size.y + 0.1, 0), "dirt", Vector3.UP)
				SoundBank.play_ui(self, "pickup", -6.0)
				EventBus.notify(msg, 3.0)


## Braucht das Beet heute noch Wasser (und hat man eine gefüllte Kanne in der Hand)?
func needs_water() -> bool:
	if bool(Supplies.config.crops.get(_bed()["crop"], {}).get("no_water", false)):
		return false
	return Supplies.bed_state(index) == "growing" and not bool(_bed()["watered"]) \
		and Inventory.equipped() == "watering_can" and Supplies.can_water > 0


## Lange genug gegossen: Beet zählt als gegossen.
func finish_watering() -> void:
	if Supplies.water_bed(index):
		Fx.burst(get_parent(), global_position + Vector3(0, size.y + 0.3, 0), "water", Vector3.DOWN, 1.2)
		EventBus.notify("Gegossen.", 1.5)


func _splash_later() -> void:
	await get_tree().create_timer(0.55).timeout
	if is_inside_tree():
		Fx.burst(get_parent(), global_position + Vector3(0, size.y + 0.3, 0), "water", Vector3.DOWN, 1.2)


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
	if String(b["crop"]) == "alien":
		_refresh_alien(t, st == "ripe")
		return
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


## Fremdpflanze: schwarzgrüne, gedrehte Stiele mit glimmenden Knollen; nachts ein schwaches grünes Licht.
func _refresh_alien(t: float, ripe: bool) -> void:
	var stem := BuildKit.color_mat(Color(0.08, 0.14, 0.1), 0.35, 0.3)
	var bulb := BuildKit.emissive_mat(Color(0.45, 0.95, 0.6), 0.6 + t * 1.2)
	var rng := RandomNumberGenerator.new()
	rng.seed = index * 131 + 7
	var top := size.y + 0.03
	for i in 4:
		for j in 2:
			var at := Vector3(-0.8 + i * 0.53 + rng.randf_range(-0.1, 0.1), top, -0.3 + j * 0.6 + rng.randf_range(-0.08, 0.08))
			var h := lerpf(0.08, 0.5, t)
			var plant := Node3D.new()
			_plants.add_child(plant)
			plant.position = at
			plant.rotation.y = rng.randf() * TAU
			for k in 2:
				BuildKit.box(plant, Vector3(0.02, h, 0.02), Vector3((k - 0.5) * 0.04, h * 0.5, 0), stem, false,
						Vector3(rng.randf_range(-14, 14), k * 90.0, rng.randf_range(-14, 14)))
			if t > 0.4:
				BuildKit.sphere(plant, lerpf(0.02, 0.055, t) * (1.3 if ripe else 1.0), Vector3(0, h, 0), bulb, Vector3(1.0, 1.3, 1.0), 6)
	var glow := OmniLight3D.new()
	glow.light_color = Color(0.5, 1.0, 0.65)
	glow.light_energy = 0.15 + t * 0.35
	glow.omni_range = 2.6
	glow.position = Vector3(0, size.y + 0.4, 0)
	_plants.add_child(glow)
