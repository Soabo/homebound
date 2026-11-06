class_name Generator
extends Interactable
## Benzin-Generator im Schuppen (GDD 7.4).
## E: starten/abstellen, R: Benzin aus einem Kanister nachfüllen.
## Das Modell baut die Hütte; dieser Knoten liefert Interaktion, Brummen und Statuslampe.

const FUEL_PER_CAN := 40.0

## Mittelpunkt des Generators am Boden (der Knoten selbst liegt im Ursprung der Hütte).
@export var anchor: Vector3 = Vector3.ZERO

var _hum: AudioStreamPlayer3D
var _led_mat: StandardMaterial3D
var _area: StaticBody3D


func _ready() -> void:
	_area = StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.4, 0.9, 0.8)
	cs.shape = shape
	cs.position = anchor + Vector3(0, 0.45, 0)
	_area.add_child(cs)
	add_child(_area)
	_led_mat = BuildKit.emissive_mat(Color(0.2, 1.0, 0.3), 3.0)
	BuildKit.sphere(self, 0.03, anchor + Vector3(-0.3, 0.86, 0.33), _led_mat, Vector3.ONE, 6)
	_hum = AudioStreamPlayer3D.new()
	_hum.stream = SoundBank.get_sound("generator")
	_hum.unit_size = 1.6
	_hum.max_distance = 28.0
	_hum.volume_db = -4.0
	_hum.position = anchor + Vector3(0, 0.5, 0)
	add_child(_hum)
	PowerManager.power_changed.connect(_on_power_changed)
	_update()


func get_prompt(_player: Node) -> String:
	var tank := "Tank %d%%" % int(PowerManager.fuel)
	if PowerManager.generator_running and not PowerManager.outage:
		return "[E] Generator abstellen  (%s)" % tank
	if PowerManager.outage:
		return "[E] Generator neu starten  (%s) – er ist ausgegangen!" % tank
	return "[E] Generator starten  (%s)" % tank


func get_secondary_prompt(_player: Node) -> String:
	var cans := Inventory.count("fuel_can")
	if cans > 0 and PowerManager.fuel < 99.0:
		return "[R] Benzin nachfüllen  (%d Kanister)" % cans
	return ""


func interact(_player: Node) -> void:
	if PowerManager.generator_running and not PowerManager.outage:
		PowerManager.stop_generator()
	else:
		if PowerManager.start_generator():
			SoundBank.play_at(self, "bang", to_global(anchor + Vector3(0, 0.5, 0)), -8.0, 1.6)
			EventBus.noise_made.emit(to_global(anchor), 14.0)
	_update()


func secondary_interact(_player: Node) -> void:
	if Inventory.remove("fuel_can", 1):
		PowerManager.add_fuel(FUEL_PER_CAN)
		SoundBank.play_at(self, "pickup", to_global(anchor), -4.0, 0.5)
		EventBus.notify("Tank aufgefüllt: %d%%" % int(PowerManager.fuel), 2.0)


func _on_power_changed(_p: bool) -> void:
	_update()


func _process(_delta: float) -> void:
	var running := PowerManager.has_power()
	if running != _hum.playing:
		_update()


func _update() -> void:
	var running := PowerManager.has_power()
	if running and not _hum.playing:
		_hum.play()
	elif not running and _hum.playing:
		_hum.stop()
	_led_mat.albedo_color = Color(0.2, 1.0, 0.3) if running else Color(1.0, 0.15, 0.1)
	_led_mat.emission = _led_mat.albedo_color
	_led_mat.emission_energy_multiplier = 3.0 if running else 1.5
