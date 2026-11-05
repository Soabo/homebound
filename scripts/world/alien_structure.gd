class_name AlienStructure
extends Node3D
## Fremde Struktur im Westen – einer der drei Vermessungspunkte (GDD 3.6, 11.2, Phase 8).
## Drei gebogene Beine tragen einen schwebenden Kristall, der ins Erdreich sendet und das
## Terraforming antreibt. Ringsum drei Säulen: Sie leuchten in einer festen Reihenfolge nacheinander
## auf. Wer sie in genau dieser Reihenfolge abschaltet, legt die Struktur still (falsch = Schlag).
## Danach bleibt ein Kristallsplitter zurück.

const SITE := Vector3(-78.0, 0.0, 40.0)
const PYLON_RADIUS := 7.0
## Reihenfolge, in der die Säulen aufleuchten und abgeschaltet werden müssen (Index der Säule)
const ORDER := [2, 0, 1]

var _crystal: Node3D
var _crystal_mat: StandardMaterial3D
var _ring_mat: StandardMaterial3D
var _core_light: OmniLight3D
var _pylons: Array[StructurePylon] = []
var _t: float = 0.0
var _hum_timer: float = 2.0


static func is_near(x: float, z: float, radius: float) -> bool:
	return Vector2(x - SITE.x, z - SITE.z).length() < radius


func _ready() -> void:
	name = "AlienStructure"
	position = Vector3(SITE.x, Terrain.height_at(SITE.x, SITE.z), SITE.z)
	var hull := CrashSite.hull_material()
	# Bodenring mit Zeichen
	_ring_mat = StandardMaterial3D.new()
	_ring_mat.albedo_texture = TextureFactory.get_texture("glyphs")
	_ring_mat.emission_enabled = true
	_ring_mat.emission_texture = TextureFactory.get_texture("glyphs")
	_ring_mat.emission = Color(0.5, 1.0, 1.0)
	_ring_mat.emission_energy_multiplier = 1.2
	_ring_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	BuildKit.lathe(self, PackedVector2Array([Vector2(3.0, 0.02), Vector2(3.6, 0.03), Vector2(3.6, 0.0)]), Vector3.ZERO, _ring_mat, 32)
	BuildKit.cylinder(self, 3.0, 0.02, Vector3(0, 0.01, 0), BuildKit.color_mat(Color(0.05, 0.05, 0.06), 0.4, 0.4), false, Vector3.ZERO, -1.0, 32)
	# drei gebogene Beine (je zwei Segmente), oben zusammenlaufend
	for k in 3:
		var a := TAU * k / 3.0
		var foot := Vector3(cos(a) * 3.2, 0.0, sin(a) * 3.2)
		var knee := Vector3(cos(a) * 2.6, 4.5, sin(a) * 2.6)
		var top := Vector3(cos(a) * 0.6, 8.2, sin(a) * 0.6)
		_beam(foot, knee, 0.22, hull)
		_beam(knee, top, 0.16, hull)
		BuildKit.sphere(self, 0.28, knee, hull, Vector3.ONE, 10)
		# leuchtende Naht am Knie
		BuildKit.lathe(self, PackedVector2Array([Vector2(0.29, -0.03), Vector2(0.31, 0.0), Vector2(0.29, 0.03)]), knee, CrashSite.glow_material(), 12)
		var col := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var sh := CylinderShape3D.new()
		sh.radius = 0.3
		sh.height = 4.6
		cs.shape = sh
		cs.position = (foot + knee) * 0.5
		col.add_child(cs)
		add_child(col)
	BuildKit.sphere(self, 0.5, Vector3(0, 8.2, 0), hull, Vector3(1.0, 0.6, 1.0), 12)
	# schwebender Kristall
	_crystal = Node3D.new()
	_crystal.position = Vector3(0, 5.2, 0)
	add_child(_crystal)
	_crystal_mat = BuildKit.emissive_mat(Color(0.55, 1.0, 1.0), 3.0)
	_crystal_mat.metallic = 0.3
	var c := BuildKit.sphere(_crystal, 0.6, Vector3.ZERO, _crystal_mat, Vector3(0.7, 1.4, 0.7), 4)
	c.rotation_degrees.y = 45.0
	_core_light = OmniLight3D.new()
	_core_light.light_color = Color(0.5, 1.0, 1.0)
	_core_light.light_energy = 3.0
	_core_light.omni_range = 16.0
	_crystal.add_child(_core_light)
	# Säulen
	for i in 3:
		var a := TAU * i / 3.0 + PI / 3.0
		var pyl := StructurePylon.new()
		pyl.name = "Pylon_%d" % i
		pyl.index = i
		pyl.structure = self
		pyl.position = Vector3(cos(a) * PYLON_RADIUS, 0.0, sin(a) * PYLON_RADIUS)
		pyl.position.y = Terrain.height_at(SITE.x + pyl.position.x, SITE.z + pyl.position.z) - position.y
		add_child(pyl)
		_pylons.append(pyl)
	# Kristallsplitter, sobald abgeschaltet
	_spawn_shard()
	WorldState.changed.connect(_on_world_changed)
	_on_world_changed()


func _beam(a: Vector3, b: Vector3, r: float, mat: Material) -> void:
	var mi := BuildKit.lathe(self, PackedVector2Array([Vector2(0.0, 0.0), Vector2(r, 0.0), Vector2(r * 0.8, a.distance_to(b)), Vector2(0.0, a.distance_to(b))]), a, mat, 10)
	var y := (b - a).normalized()
	var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
	mi.basis = Basis(x, y, x.cross(y))


func _spawn_shard() -> void:
	if not WorldState.structure_off or has_node("CrystalShard"):
		return
	var at := Vector3(0.8, 0.0, 0.5)
	at.y = Terrain.height_at(SITE.x + at.x, SITE.z + at.z) - position.y
	var p := ItemPickup.new()
	p.name = "CrystalShard"
	p.item_id = "crystal_shard"
	p.amount = 2
	p.per_take = 1
	p.collider_size = Vector3(0.6, 0.4, 0.6)
	p.collider_offset = at + Vector3(0, 0.2, 0)
	add_child(p)
	for k in 2:
		var v := Node3D.new()
		p.add_child(v)
		var s := BuildKit.sphere(v, 0.12, at + Vector3(k * 0.2, 0.1, k * 0.1), _crystal_mat, Vector3(0.6, 1.4, 0.6), 4)
		s.rotation_degrees = Vector3(30 + k * 40, 45, 20)
		p.visuals.append(v)


func _on_world_changed() -> void:
	var off := WorldState.structure_off
	_crystal_mat.emission_energy_multiplier = 0.4 if off else 3.0
	_core_light.visible = not off
	_ring_mat.emission_energy_multiplier = 0.15 if off else 1.2
	for p in _pylons:
		p.refresh()
	_spawn_shard()


## Eine Säule wurde berührt: richtige Reihenfolge? Falsch = Schlag und alles von vorn.
func pylon_pressed(index: int, player: Node) -> void:
	if WorldState.structure_off or WorldState.pylons_off.has(index):
		return
	var expected: int = ORDER[WorldState.pylons_off.size()]
	if index != expected:
		WorldState.reset_pylons()
		var p := player as Player
		if p:
			p.health = maxf(p.health - 10.0, 1.0)
			EventBus.player_hurt.emit(10.0)
			EventBus.screen_shake.emit(0.5)
		SoundBank.play_at(get_parent(), "static", global_position + Vector3(0, 2, 0), 4.0, 0.6)
		EventBus.noise_made.emit(global_position, 40.0)
		EventBus.notify("Ein Schlag fährt dir durch den Arm – alle Säulen leuchten wieder. Achte auf die Reihenfolge.", 4.0)
		return
	WorldState.set_pylon_off(index)
	SoundBank.play_at(get_parent(), "switch", _pylons[index].global_position + Vector3(0, 1.2, 0), 0.0, 0.5)
	if WorldState.pylons_off.size() >= 3:
		SoundBank.play_at(get_parent(), "signal", global_position + Vector3(0, 5, 0), 4.0, 0.4)
		WorldState.shut_down_structure()


func _process(delta: float) -> void:
	_t += delta
	if _crystal:
		_crystal.position.y = 5.2 + sin(_t * 0.8) * 0.15
		_crystal.rotation.y += delta * (0.1 if WorldState.structure_off else 0.6)
	# Säulen leuchten nacheinander in der Abschalt-Reihenfolge auf (Hinweis für den Spieler)
	if not WorldState.structure_off:
		var cycle := fmod(_t, 6.0)
		var lit := int(cycle / 1.2)
		for i in 3:
			_pylons[ORDER[i]].pulse(lit == i)
	_hum_timer -= delta
	if _hum_timer <= 0.0 and not WorldState.structure_off:
		_hum_timer = randf_range(5.0, 9.0)
		var pl := get_tree().get_first_node_in_group("player") as Node3D
		if pl and pl.global_position.distance_to(global_position) < 40.0:
			SoundBank.play_at(self, "signal", global_position + Vector3(0, 5, 0), -8.0, randf_range(0.35, 0.45))
