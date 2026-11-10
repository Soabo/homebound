class_name AlienDrops
extends Node3D
## Fremdes Zeug, das die Wesen hinterlassen (Forschung 2.0). Morgens nach Nächten mit Aktivität legt
## dieses System Funde ab – Häutungsfetzen im Hof, Speichel am Fenster, Splitter, wo der Sucher war …
## Welche, wann und wo: research.json "drops". Auch ausgebrochene Proben landen hier (lose = sie kratzen nachts).
## Kameraaufnahmen (rec_creature, rec_drone) warten am Monitorplatz, bis man sie abholt.

var entries: Array = []      ## [{n, item, x, y, z, loose}]
var footage: Array = []      ## Aufnahmen, die am Monitor abgeholt werden können
var next_id: int = 0
var _rng := RandomNumberGenerator.new()
var _scratch_t: float = 30.0


func _ready() -> void:
	name = "AlienDrops"
	add_to_group("alien_drops")
	add_to_group("persistent")
	_rng.randomize()
	GameState.restore(self)


static func get_for(tree: SceneTree) -> AlienDrops:
	return tree.get_first_node_in_group("alien_drops") as AlienDrops


func persist_key() -> String:
	return "alien_drops"


func get_state() -> Dictionary:
	# eingesammelte Funde vergessen
	var keep: Array = []
	for e: Dictionary in entries:
		var p := get_node_or_null("Drop_%d" % int(e["n"])) as ItemPickup
		if p and p.amount > 0:
			keep.append(e)
	return {"entries": keep, "footage": footage.duplicate(), "next": next_id}


func set_state(s: Dictionary) -> void:
	for c in get_children():
		c.queue_free()
	entries = []
	footage = (s.get("footage", []) as Array).duplicate()
	next_id = int(s.get("next", 0))
	for e: Dictionary in s.get("entries", []):
		_make(e)


## Legt einen Fund in die Welt.
func spawn(item: String, pos: Vector3, loose: bool = false) -> ItemPickup:
	var e := {"n": next_id, "item": item, "x": pos.x, "y": pos.y, "z": pos.z, "loose": loose}
	next_id += 1
	return _make(e)


func _make(e: Dictionary) -> ItemPickup:
	entries.append(e)
	var p := ItemPickup.new()
	p.name = "Drop_%d" % int(e["n"])
	p.item_id = String(e["item"])
	p.amount = 1
	p.collider_size = Vector3(0.45, 0.3, 0.45)
	p.collider_offset = Vector3(0, 0.15, 0)
	p.position = Vector3(float(e["x"]), float(e["y"]), float(e["z"]))
	p.rotation_degrees.y = float(int(e["n"]) * 47 % 360)
	add_child(p)
	_visual(p, String(e["item"]), bool(e.get("loose", false)))
	return p


func _visual(p: ItemPickup, item: String, loose: bool) -> void:
	var v := Node3D.new()
	p.add_child(v)
	p.visuals.append(v)
	var hull := CrashSite.hull_material()
	var glow := CrashSite.glow_material()
	var grey := BuildKit.color_mat(Color(0.42, 0.4, 0.43), 0.6)
	match item:
		"creature_shed":
			for k in 3:
				BuildKit.box(v, Vector3(0.35 - k * 0.08, 0.01, 0.22), Vector3(k * 0.05, 0.01 + k * 0.012, k * 0.03), BuildKit.color_mat(Color(0.55, 0.52, 0.48), 0.8), false, Vector3(0, k * 25.0, 4.0))
		"creature_saliva", "fog_jar", "tainted_sample":
			var c := Color(0.75, 0.8, 0.7, 0.6) if item == "creature_saliva" else (Color(0.85, 0.88, 0.9, 0.5) if item == "fog_jar" else Color(0.5, 0.6, 0.45, 0.6))
			BuildKit.cylinder(v, 0.06, 0.14, Vector3(0, 0.07, 0), _glass(c), false, Vector3.ZERO, -1.0, 10)
			BuildKit.cylinder(v, 0.062, 0.02, Vector3(0, 0.15, 0), BuildKit.color_mat(Color(0.6, 0.55, 0.4), 0.5, 0.6), false, Vector3.ZERO, -1.0, 10)
		"creature_claw":
			BuildKit.box(v, Vector3(0.03, 0.03, 0.16), Vector3(0, 0.02, 0), BuildKit.color_mat(Color(0.2, 0.19, 0.2), 0.3), false, Vector3(0, 0, 0))
			BuildKit.box(v, Vector3(0.025, 0.025, 0.07), Vector3(0, 0.035, 0.1), BuildKit.color_mat(Color(0.2, 0.19, 0.2), 0.3), false, Vector3(-30, 0, 0))
		"foreign_cloth":
			BuildKit.box(v, Vector3(0.4, 0.04, 0.3), Vector3(0, 0.02, 0), BuildKit.tex_mat("fabric", 0.3, Color(0.75, 0.85, 0.75)), false)
		"pillar_chip", "black_soil":
			BuildKit.sphere(v, 0.12, Vector3(0, 0.06, 0), BuildKit.tex_mat("stone", 0.5, Color(0.6, 0.6, 0.62)) if item == "pillar_chip" else BuildKit.color_mat(Color(0.06, 0.05, 0.05), 0.9), Vector3(1.2, 0.6, 1.0), 7)
		"blind_bird":
			BuildKit.sphere(v, 0.06, Vector3(0, 0.05, 0), BuildKit.color_mat(Color(0.55, 0.35, 0.25), 0.8), Vector3(1.4, 0.8, 1.0), 8)
			BuildKit.sphere(v, 0.035, Vector3(0.07, 0.07, 0), BuildKit.color_mat(Color(0.45, 0.32, 0.25), 0.8), Vector3.ONE, 6)
		"infected_antler":
			for k in 3:
				BuildKit.cylinder(v, 0.02, 0.35, Vector3(k * 0.06 - 0.06, 0.04, 0), BuildKit.color_mat(Color(0.6, 0.52, 0.4), 0.7), false, Vector3(80, k * 30.0 - 30.0, 0), 0.01, 6)
			BuildKit.box(v, Vector3(0.3, 0.01, 0.01), Vector3(0, 0.06, 0.05), grey, false, Vector3(0, 20, 0))
		"seeker_thread", "manip_membrane":
			BuildKit.box(v, Vector3(0.3, 0.004, 0.2), Vector3(0, 0.02, 0), _glass(Color(0.8, 0.82, 0.9, 0.4)), false)
			BuildKit.sphere(v, 0.015, Vector3(0.1, 0.03, 0), glow, Vector3.ONE, 5)
		"seeker_lens":
			BuildKit.sphere(v, 0.04, Vector3(0, 0.03, 0), BuildKit.emissive_mat(Color(1.0, 0.85, 0.6), 2.0), Vector3(1.3, 0.5, 1.0), 6)
		"drone_lens", "drone_memory":
			BuildKit.lathe(v, PackedVector2Array([Vector2(0.0, -0.03), Vector2(0.12, 0.0), Vector2(0.0, 0.04)]), Vector3(0, 0.05, 0), hull, 12)
			BuildKit.sphere(v, 0.05, Vector3(0, 0.07, 0), glow, Vector3.ONE, 8)
		_:
			# alles andere: grauer Klumpen mit leuchtenden Adern (Proben aus dem Labor)
			BuildKit.sphere(v, 0.09, Vector3(0, 0.07, 0), grey, Vector3(1.2, 0.8, 1.0), 8)
			BuildKit.sphere(v, 0.03, Vector3(0.05, 0.11, 0.02), glow, Vector3.ONE, 6)
	if loose:
		var l := OmniLight3D.new()
		l.light_color = Color(0.55, 0.9, 0.8)
		l.light_energy = 0.25
		l.omni_range = 1.4
		l.position = Vector3(0, 0.2, 0)
		v.add_child(l)


static func _glass(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.1
	return m


# --- morgens -------------------------------------------------------------

## Von ThreatDirector bei Sonnenaufgang: kinds = was heute Nacht los war (creature, drone, manipulator, seeker, change).
func morning(kinds: Array) -> Array:
	var out: Array = []
	var any := not kinds.is_empty()
	for dd: Dictionary in Research.data().get("drops", []):
		var after := String(dd.get("after", "any"))
		if after == "any":
			if not any:
				continue
		elif not kinds.has(after):
			continue
		if WorldState.stage() < int(dd.get("stage", 0)) or TimeManager.day < int(dd.get("from_day", 0)):
			continue
		var req := String(dd.get("requires", ""))
		if req != "" and not Research.requirement_done(req):
			continue
		if _rng.randf() >= float(dd.get("chance", 0.0)):
			continue
		var pos: Variant = spot(String(dd.get("where", "yard")))
		if pos == null:
			continue
		spawn(String(dd["item"]), pos)
		out.append(String(dd["item"]))
	# Aufnahmen der eigenen Kameras
	if not Supplies.cameras.is_empty():
		if kinds.has("creature") and _rng.randf() < 0.6:
			add_footage("rec_creature")
		if kinds.has("drone") and _rng.randf() < 0.6:
			add_footage("rec_drone")
	return out


## Ein passender Ort für einen Fund (null = keiner).
func spot(where: String) -> Variant:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	for attempt in 12:
		var p := Vector3.ZERO
		match where:
			"window":
				var wins := get_tree().get_nodes_in_group("entry_point").filter(func(e: Node) -> bool: return e is CabinWindow)
				if wins.is_empty():
					return null
				var w: Node = wins[_rng.randi() % wins.size()]
				var out: Vector3 = w.call("outside_point")
				var inner: Vector3 = w.call("inside_point")
				var dir := out - inner
				dir.y = 0.0
				p = out + dir.normalized() * 0.4
			"porch":
				p = Vector3(_rng.randf_range(-4.0, 4.0), 0, _rng.randf_range(5.3, 6.2))
			"garden":
				p = Vector3(_rng.randf_range(-16.0, -9.0), 0, _rng.randf_range(4.0, 14.0))
			"forest":
				var a := _rng.randf() * TAU
				p = Vector3(cos(a), 0, sin(a)) * _rng.randf_range(24.0, 55.0)
			"stream":
				var z := _rng.randf_range(-60.0, 60.0)
				var sx := Terrain.stream_x_at(z)
				p = Vector3(sx + (Terrain.WATER_HALF_WIDTH + 1.2) * (1.0 if _rng.randf() < 0.5 else -1.0), 0, z)
			"patch":
				if WorldState.patches.is_empty():
					return null
				var q: Dictionary = WorldState.patches[_rng.randi() % WorldState.patches.size()]
				p = Vector3(float(q["x"]) + _rng.randf_range(-1.5, 1.5), 0, float(q["z"]) + _rng.randf_range(-1.5, 1.5))
			"player":
				if player == null:
					return null
				var a2 := _rng.randf() * TAU
				p = player.global_position + Vector3(cos(a2), 0, sin(a2)) * _rng.randf_range(4.0, 12.0)
			_:  # yard: rund um die Hütte, auf dem Grundstück
				var a3 := _rng.randf() * TAU
				p = Vector3(cos(a3) * _rng.randf_range(8.0, 16.0), 0, sin(a3) * _rng.randf_range(7.5, 14.0))
		if Cabin.is_inside(p) or Shed.is_inside(p):
			continue
		if where == "porch":
			p.y = Cabin.FLOOR_Y + 0.02 if absf(p.x) < 6.0 else Terrain.height_at(p.x, p.z)
		else:
			p.y = Terrain.height_at(p.x, p.z) + 0.02
		if where == "window":
			p.y = maxf(p.y, Terrain.height_at(p.x, p.z) + 0.02)
		return p
	return null


func add_footage(id: String) -> void:
	if not footage.has(id):
		footage.append(id)


## Am Monitorplatz: wartende Aufnahmen auf Speicherkarte nehmen.
func collect_footage() -> int:
	var n := 0
	for id: String in footage.duplicate():
		if Inventory.add(id, 1) > 0:
			footage.erase(id)
			n += 1
			EventBus.notify("Die Kameras haben etwas aufgezeichnet: %s" % Inventory.display_name(id), 4.0)
	return n


# --- lose Proben kratzen nachts --------------------------------------------

func _process(delta: float) -> void:
	_scratch_t -= delta
	if _scratch_t > 0.0:
		return
	_scratch_t = _rng.randf_range(40.0, 90.0)
	if not TimeManager.is_night():
		return
	for e: Dictionary in entries:
		if not bool(e.get("loose", false)):
			continue
		var p := get_node_or_null("Drop_%d" % int(e["n"])) as ItemPickup
		if p and p.amount > 0:
			SoundBank.play_at(get_parent(), "scratch", p.global_position + Vector3(0, 0.2, 0), -6.0, _rng.randf_range(1.2, 1.6))
			return


func loose_count() -> int:
	var n := 0
	for e: Dictionary in entries:
		var p := get_node_or_null("Drop_%d" % int(e["n"])) as ItemPickup
		if bool(e.get("loose", false)) and p and p.amount > 0:
			n += 1
	return n
