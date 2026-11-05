class_name Terraformer
extends Node3D
## Macht den Weltzustand sichtbar (GDD 3.6): je nach Terraforming-Stufe
##  1: Pilze in exakten Kreisen (Stimmung)
##  2: fremde Pflanzen bei Struktur und Krater (aufsammelbar, Forschung), kahle symmetrische Bäume
##  4: schwebende Steine an der Struktur, Adern im Boden am Zaun
## Außerdem die Wucherungen des Organismus (Liste im WorldState).

const RING_SPOTS := [Vector3(-26, 0, -12), Vector3(-30, 0, 22), Vector3(28, 0, -30), Vector3(-55, 0, 8), Vector3(14, 0, -48)]
const PLANT_SPOTS := [Vector3(-70, 0, 34), Vector3(-72, 0, 49), Vector3(-84, 0, 30), Vector3(-66, 0, 42), Vector3(-88, 0, 46),
		Vector3(-36, 0, -36), Vector3(-48, 0, -24), Vector3(-40, 0, -40)]
const PALE_TREES := [Vector3(-64, 0, 30), Vector3(-70, 0, 55), Vector3(-90, 0, 38), Vector3(-82, 0, 56), Vector3(-60, 0, 46), Vector3(-92, 0, 26)]

var _shown_stage: int = -1
var _layers: Dictionary = {}
var _floaters: Array[Node3D] = []
var _t: float = 0.0


func _ready() -> void:
	name = "Terraformer"
	WorldState.changed.connect(_refresh)
	_refresh()


func _layer(n: String) -> Node3D:
	if _layers.has(n):
		return _layers[n]
	var l := Node3D.new()
	l.name = n
	add_child(l)
	_layers[n] = l
	return l


func _at(p: Vector3, lift: float = 0.0) -> Vector3:
	return Vector3(p.x, Terrain.height_at(p.x, p.z) + lift, p.z)


func _refresh() -> void:
	var s := WorldState.stage()
	if s != _shown_stage:
		_shown_stage = s
		for n in _layers:
			var old := _layers[n] as Node3D
			remove_child(old)  # Name sofort frei, damit Pfade (Spielstand) gleich bleiben
			old.queue_free()
		_layers.clear()
		_floaters.clear()
		if s >= 1:
			_build_rings()
		if s >= 2:
			_build_plants()
			_build_pale_trees()
		if s >= 4:
			_build_floaters()
			_build_veins()
	_sync_patches()


func _build_rings() -> void:
	var l := _layer("Rings")
	var cap := BuildKit.emissive_mat(Color(0.75, 0.9, 0.85), 0.6)
	var stem := BuildKit.color_mat(Color(0.82, 0.8, 0.75))
	for c: Vector3 in RING_SPOTS:
		for k in 14:
			var a := TAU * k / 14.0
			var p := _at(c + Vector3(cos(a) * 1.6, 0, sin(a) * 1.6))
			BuildKit.cylinder(l, 0.012, 0.08, p + Vector3(0, 0.04, 0), stem, false, Vector3.ZERO, -1.0, 5)
			BuildKit.sphere(l, 0.04, p + Vector3(0, 0.085, 0), cap, Vector3(1.0, 0.45, 1.0), 6)


func _build_plants() -> void:
	var l := _layer("Plants")
	var stalk := BuildKit.color_mat(Color(0.5, 0.45, 0.55), 0.6)
	var tip := BuildKit.emissive_mat(Color(0.8, 0.5, 1.0), 1.2)
	for i in PLANT_SPOTS.size():
		var at := _at(PLANT_SPOTS[i])
		var p := ItemPickup.new()
		p.name = "AlienPlant_%d" % i
		p.item_id = "alien_plant"
		p.amount = 2
		p.per_take = 1
		p.collider_size = Vector3(0.7, 0.9, 0.7)
		p.collider_offset = at + Vector3(0, 0.45, 0)
		l.add_child(p)
		for k in 2:
			var v := Node3D.new()
			p.add_child(v)
			var base := at + Vector3(k * 0.25 - 0.12, 0, k * 0.15)
			BuildKit.cylinder(v, 0.02, 0.8, base + Vector3(0, 0.4, 0), stalk, false, Vector3.ZERO, 0.01, 5)
			# perfekt symmetrische Blattspirale
			for j in 8:
				var a := TAU * j / 4.0 + j * 0.2
				var h := 0.12 + j * 0.08
				BuildKit.box(v, Vector3(0.22 - j * 0.015, 0.008, 0.06), base + Vector3(cos(a) * 0.1, h, sin(a) * 0.1), stalk, false, Vector3(0, -rad_to_deg(a), 18))
			BuildKit.sphere(v, 0.05, base + Vector3(0, 0.82, 0), tip, Vector3.ONE, 6)
			p.visuals.append(v)


## Bäume ohne Rinde, mit exakt gleichmäßigen Astquirlen (GDD 3.6).
func _build_pale_trees() -> void:
	var l := _layer("PaleTrees")
	var bone := BuildKit.color_mat(Color(0.82, 0.8, 0.76), 0.7)
	for c: Vector3 in PALE_TREES:
		var g := _at(c)
		BuildKit.cylinder(l, 0.22, 9.0, g + Vector3(0, 4.5, 0), bone, true, Vector3.ZERO, 0.08, 6)
		for w in 5:
			var h := 3.0 + w * 1.2
			for k in 6:
				var a := TAU * k / 6.0
				BuildKit.cylinder(l, 0.04, 1.6 - w * 0.2, g + Vector3(cos(a) * 0.7, h + 0.25, sin(a) * 0.7), bone, false,
						Vector3(sin(a) * 60.0, 0, -cos(a) * 60.0), 0.01, 4)


func _build_floaters() -> void:
	var l := _layer("Floaters")
	var stone := BuildKit.tex_mat("stone", 0.5)
	var rng := RandomNumberGenerator.new()
	rng.seed = 404
	for k in 9:
		var a := rng.randf() * TAU
		var d := rng.randf_range(4.0, 12.0)
		var p := _at(AlienStructure.SITE + Vector3(cos(a) * d, 0, sin(a) * d), rng.randf_range(0.8, 3.0))
		var rock := BuildKit.sphere(l, rng.randf_range(0.2, 0.55), p, stone, Vector3(1.2, 0.8, 1.0), 7)
		rock.set_meta("base_y", p.y)
		rock.set_meta("phase", rng.randf() * TAU)
		_floaters.append(rock)


func _build_veins() -> void:
	var l := _layer("Veins")
	var vein := BuildKit.color_mat(Color(0.3, 0.27, 0.32), 0.3, 0.1)
	var rng := RandomNumberGenerator.new()
	rng.seed = 505
	for k in 30:
		var x := rng.randf_range(-24.0, 26.0)
		var z := -20.0 if k % 2 == 0 else 22.0
		var p := _at(Vector3(x, 0, z + rng.randf_range(-2.0, 2.0)), 0.03)
		BuildKit.box(l, Vector3(rng.randf_range(1.0, 3.0), 0.03, 0.05), p, vein, false, Vector3(0, rng.randf() * 180.0, 0))


## Wucherungen aus der Liste im WorldState anlegen bzw. entfernen.
func _sync_patches() -> void:
	var l := _layer("Patches")
	var wanted := {}
	for p: Dictionary in WorldState.patches:
		wanted["Patch_%d" % int(p["id"])] = p
	for c in l.get_children():
		if not wanted.has(String(c.name)):
			c.queue_free()
	for n: String in wanted:
		if l.has_node(n):
			continue
		var d: Dictionary = wanted[n]
		var patch := OrganismNode.Patch.new()
		patch.name = n
		patch.patch_id = int(d["id"])
		patch.position = _at(Vector3(float(d["x"]), 0, float(d["z"])))
		l.add_child(patch)


func _process(delta: float) -> void:
	_t += delta
	for f in _floaters:
		if is_instance_valid(f):
			f.position.y = float(f.get_meta("base_y")) + sin(_t * 0.7 + float(f.get_meta("phase"))) * 0.25
			f.rotation.y += delta * 0.2
