class_name CellarBrace
extends Interactable
## Die zugemauerte Stelle im Keller während der Belagerungsnacht: Wurzeln drücken die Ziegel auf.
## [E] mit einem Brett abstützen (SiegeNight.cellar_brace). Wurzeln wachsen sichtbar mit dem Druck.

var _roots: Array[Node3D] = []
var _braces: Node3D
var _pressure := 0.0


func _ready() -> void:
	add_to_group("cellar_brace")
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(0.06, 1.6, 1.1)
	cs.shape = sh
	cs.position = Vector3(0, 0.8, 0)
	body.add_child(cs)
	add_child(body)
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var root_mat := BuildKit.color_mat(Color(0.45, 0.44, 0.42), 0.6)
	for k in 9:
		var r := Node3D.new()
		r.position = Vector3(-0.05, rng.randf_range(0.2, 1.5), rng.randf_range(-0.45, 0.45))
		r.rotation_degrees = Vector3(rng.randf_range(-40, 40), 0, rng.randf_range(60, 110))
		add_child(r)
		BuildKit.cylinder(r, rng.randf_range(0.015, 0.03), 0.6, Vector3(0, 0.3, 0), root_mat, false, Vector3.ZERO, 0.004, 5)
		r.scale = Vector3(1, 0.01, 1)
		_roots.append(r)
	_braces = Node3D.new()
	add_child(_braces)
	var plank := BuildKit.tex_mat("planks_h", 0.6, Color(0.8, 0.7, 0.55))
	BuildKit.box(_braces, Vector3(0.05, 1.7, 0.18), Vector3(-0.35, 0.8, 0.25), plank, false, Vector3(25, 0, 0))
	BuildKit.box(_braces, Vector3(0.05, 1.7, 0.18), Vector3(-0.35, 0.8, -0.25), plank, false, Vector3(-25, 0, 0))
	_braces.visible = false


func set_pressure(p: float) -> void:
	if p < _pressure - 0.3:
		_braces.visible = true
	_pressure = p
	for r in _roots:
		r.scale = Vector3(1, maxf(p * 1.2, 0.01), 1)


func burst() -> void:
	_braces.visible = false
	Fx.burst(get_parent(), global_position + Vector3(-0.1, 0.9, 0), "stone", Vector3(-1, 0, 0), 1.5)
	SoundBank.play_at(get_parent(), "wood_crack", global_position + Vector3(0, 0.9, 0), 6.0, 0.6)


func get_prompt(_p: Node) -> String:
	if SiegeNight.current == null or not SiegeNight.current.active("cellar"):
		return ""
	return "Die Mauer gibt nach (%d %%)  [E] mit einem Brett abstützen" % int(SiegeNight.current.pressure("cellar") * 100.0)


func interact(_p: Node) -> void:
	if SiegeNight.current == null or not SiegeNight.current.active("cellar"):
		return
	if SiegeNight.current.cellar_brace():
		_braces.visible = true
	else:
		EventBus.notify("Dafür brauchst du ein Brett.", 2.0)
