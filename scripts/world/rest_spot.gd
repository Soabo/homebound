class_name RestSpot
extends Node3D
## Rastplatz an einem langen Weg (map.json rest_spots, Story-Bibel »Rastplätze mit Feuerstelle«):
## Steinring mit Feuerstelle (1 Holz/Torf anzünden), Wanderbank, ein kleiner Holzstapel, Schild.
## Wer sein Zelt hier aufbaut (ThreatConfig camp_rest_radius), hat eine ruhigere Nacht (camp_rest_factor),
## und das Feuer wärmt wie ein Lagerfeuer. Auf der Karte als △ eingezeichnet.

var spot_id: String = ""
var title: String = "Rastplatz"
var face := Vector2(0, 1)


static func near(p: Vector3, radius: float, tree: SceneTree) -> bool:
	for r in tree.get_nodes_in_group("rest_spot"):
		var n := r as Node3D
		if Vector2(n.global_position.x - p.x, n.global_position.z - p.z).length() < radius:
			return true
	return false


func _ready() -> void:
	add_to_group("rest_spot")
	var stone := BuildKit.tex_mat("stone", 0.4)
	var log_mat := BuildKit.tex_mat("logs", 0.6)
	var dark := BuildKit.color_mat(Color(0.2, 0.15, 0.1), 0.8)
	# Feuerstelle in der Mitte
	var fire := RestFire.new()
	fire.name = "RestFire"
	add_child(fire)
	# zwei Sitzstämme
	for k: int in [0, 1]:
		var a := 0.6 + k * 2.2
		var p := Vector3(cos(a) * 1.9, 0.18, sin(a) * 1.9)
		var c := BuildKit.cylinder(self, 0.2, 1.6, p, log_mat, false, Vector3(0, 0, 90), -1.0, 8)
		c.rotation.y = -a + PI * 0.5
		BuildKit.collider_box(self, Vector3(1.6, 0.36, 0.4), p, Vector3(0, rad_to_deg(-a + PI * 0.5), 0))
	# Holzstapel (einmal mitnehmen)
	PlaceKit.loot(self, "Wood", "wood", 3, Vector3(-2.4, 0.06, -1.2), "logs")
	# Schild am Pfosten
	BuildKit.box(self, Vector3(0.1, 1.4, 0.1), Vector3(2.6, 0.7, -1.4), dark, true)
	BuildKit.box(self, Vector3(0.9, 0.35, 0.04), Vector3(2.6, 1.3, -1.36), BuildKit.color_mat(Color(0.82, 0.78, 0.68), 0.8), false)
	var lab := Label3D.new()
	lab.text = title
	lab.font_size = 22
	lab.pixel_size = 0.0021
	lab.modulate = Color(0.08, 0.07, 0.06)
	lab.outline_size = 0
	lab.position = Vector3(2.6, 1.3, -1.335)
	add_child(lab)
	for c in get_children():
		if c is GeometryInstance3D:
			(c as GeometryInstance3D).visibility_range_end = 220.0


## Feuerstelle: E anzünden (1 Holz/Torf) bzw. löschen, R nachlegen. Wärmt (heat_source), leuchtet, lockt aber an.
class RestFire extends Interactable:
	var burn_until: float = 0.0
	var _light: OmniLight3D
	var _flame: MeshInstance3D
	var _t: float = 0.0
	var _cfg: SurvivalConfig

	func _ready() -> void:
		_cfg = SurvivalConfig.get_default()
		add_to_group("heat_source")
		add_to_group("campfire")
		add_to_group("persistent")
		var stone := BuildKit.tex_mat("stone", 0.4)
		for i in 10:
			var a := TAU * i / 10.0
			BuildKit.sphere(self, 0.15, Vector3(cos(a) * 0.55, 0.07, sin(a) * 0.55), stone, Vector3(1.2, 0.7, 1.0), 6)
		BuildKit.cylinder(self, 0.4, 0.02, Vector3(0, 0.01, 0), BuildKit.color_mat(Color(0.05, 0.04, 0.03)), false, Vector3.ZERO, -1.0, 12)
		var logs := BuildKit.tex_mat("bark", 0.4)
		for k in 3:
			BuildKit.cylinder(self, 0.05, 0.6, Vector3(0, 0.1, 0), logs, false, Vector3(70, k * 60.0, 0), 0.04, 6)
		_flame = BuildKit.cylinder(self, 0.2, 0.55, Vector3(0, 0.36, 0), BuildKit.emissive_mat(Color(1.0, 0.55, 0.15), 3.0), false, Vector3.ZERO, 0.0, 8)
		_light = OmniLight3D.new()
		_light.light_color = Color(1.0, 0.62, 0.3)
		_light.omni_range = 9.0
		_light.position = Vector3(0, 0.6, 0)
		add_child(_light)
		var area := Area3D.new()
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = Vector3(1.3, 0.8, 1.3)
		cs.shape = sh
		cs.position = Vector3(0, 0.4, 0)
		area.add_child(cs)
		add_child(area)
		GameState.restore(self)

	func hours_left() -> float:
		return maxf(burn_until - TimeManager.get_total_hours(), 0.0)

	func burning() -> bool:
		return hours_left() > 0.0

	func heat_at(pos: Vector3) -> float:
		if not burning():
			return 0.0
		return clampf(1.0 - global_position.distance_to(pos) / _cfg.campfire_radius, 0.0, 1.0)

	func put_out() -> void:
		burn_until = TimeManager.get_total_hours()

	func get_prompt(_p: Node) -> String:
		if burning():
			return "Feuerstelle (brennt noch ca. %d Min.)  [E] Löschen" % int(hours_left() * 60.0)
		return "Feuerstelle am Rastplatz  [E] Anzünden (1 Holz oder Torf)"

	func get_secondary_prompt(_p: Node) -> String:
		return "[R] Holz nachlegen (%d dabei)" % Inventory.count_fuel() if burning() else ""

	func interact(_p: Node) -> void:
		if burning():
			put_out()
			EventBus.notify("Feuer gelöscht.", 2.0)
			return
		if not Inventory.remove_fuel(1):
			EventBus.notify("Ich brauche Holz oder Torf.", 2.0)
			return
		burn_until = TimeManager.get_total_hours() + _cfg.campfire_hours_per_wood
		Tasks.flag("campfire")
		EventBus.notify("Das Feuer brennt. Hier lässt es sich aushalten.", 2.5)

	func secondary_interact(_p: Node) -> void:
		if not burning() or not Inventory.remove_fuel(1):
			return
		burn_until = maxf(burn_until, TimeManager.get_total_hours()) + _cfg.campfire_hours_per_wood
		EventBus.notify("Holz nachgelegt – brennt noch ca. %d Min." % int(hours_left() * 60.0), 2.0)

	func _process(delta: float) -> void:
		_t += delta
		var s := clampf(hours_left() / 0.4, 0.0, 1.0)
		_flame.visible = s > 0.02
		_flame.scale = Vector3(1.0, 0.6 + 0.4 * s + sin(_t * 9.0) * 0.08, 1.0) * maxf(s, 0.3)
		_light.visible = s > 0.02
		_light.light_energy = s * (1.6 + sin(_t * 11.0) * 0.25)

	func persist_key() -> String:
		return str(get_path())

	func get_state() -> Dictionary:
		return {"burn_until": burn_until}

	func set_state(st: Dictionary) -> void:
		burn_until = float(st.get("burn_until", 0.0))
