class_name Radio
extends Interactable
## Altes Batterieradio auf dem Schreibtisch. Läuft auch ohne Strom –
## und schaltet sich manchmal nachts von selbst ein (GDD 13.2, Phase 5).
## Der Knoten liegt im Ursprung der Hütte; anchor = Position des Radios.

@export var anchor: Vector3 = Vector3.ZERO

var is_on: bool = false
var _player3d: AudioStreamPlayer3D
var _dial: StandardMaterial3D


func _ready() -> void:
	add_to_group("radio")
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.4, 0.25, 0.3)
	cs.shape = shape
	cs.position = anchor + Vector3(0, 0.1, 0)
	body.add_child(cs)
	add_child(body)
	_dial = BuildKit.emissive_mat(Color(1.0, 0.7, 0.3), 0.0)
	BuildKit.box(self, Vector3(0.012, 0.05, 0.1), anchor + Vector3(-0.18, 0.11, -0.03), _dial, false)
	_player3d = AudioStreamPlayer3D.new()
	_player3d.stream = SoundBank.get_sound("radio")
	_player3d.position = anchor + Vector3(0, 0.1, 0)
	_player3d.unit_size = 2.5
	_player3d.max_distance = 18.0
	_player3d.volume_db = -6.0
	add_child(_player3d)


func get_prompt(_player: Node) -> String:
	return "[E] Radio %s" % ("ausschalten" if is_on else "einschalten")


func interact(_player: Node) -> void:
	set_on(not is_on)


func set_on(v: bool) -> void:
	is_on = v
	_dial.emission_energy_multiplier = 2.5 if v else 0.0
	if v:
		_player3d.play()
	else:
		_player3d.stop()
	SoundBank.play_at(self, "switch", to_global(anchor), -6.0, 0.7)
