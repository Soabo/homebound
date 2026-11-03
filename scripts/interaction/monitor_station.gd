class_name MonitorStation
extends Interactable
## Der alte Röhrenmonitor am Schreibtisch: zeigt das aktive Kamerabild
## und öffnet mit E die Monitor-Ansicht (Umschalten mit A/D).
## Der Knoten liegt im Ursprung der Hütte; screen_center/screen_size in Hüttenkoordinaten.

@export var screen_center: Vector3 = Vector3.ZERO
@export var screen_size: Vector2 = Vector2(0.45, 0.3)

var _screen: MeshInstance3D
var _mat: ShaderMaterial
var _black: StandardMaterial3D


func _ready() -> void:
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.5, 0.45, 0.7)
	cs.shape = shape
	cs.position = screen_center + Vector3(0.2, 0, 0)
	body.add_child(cs)
	add_child(body)
	_screen = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = screen_size
	_screen.mesh = q
	_screen.position = screen_center
	_screen.rotation_degrees.y = -90.0
	add_child(_screen)
	_black = BuildKit.color_mat(Color(0.02, 0.03, 0.03), 0.1)
	_screen.material_override = _black


func _process(_delta: float) -> void:
	var sv := get_tree().get_first_node_in_group("surveillance") as Surveillance
	if sv == null:
		return
	if _mat == null:
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_texture = sv.viewport.get_texture()
		m.albedo_color = Color(0.75, 1.0, 0.75)
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		_screen.set_meta("feed", m)
		_mat = ShaderMaterial.new()
	_screen.material_override = _screen.get_meta("feed") if PowerManager.has_power() else _black


func get_prompt(_player: Node) -> String:
	if not PowerManager.has_power():
		return "Überwachungsmonitor – kein Strom"
	return "[E] Überwachungsmonitor ansehen"


func interact(_player: Node) -> void:
	if not PowerManager.has_power():
		EventBus.notify("Kein Strom. Der Generator ist im Technikraum.", 2.5)
		return
	get_tree().call_group("hud", "open_monitor")
