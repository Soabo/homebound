class_name Babyfon
extends Interactable
## Babyfon-Empfänger auf Stefanies Schreibtisch: drei Leuchtbalken für Kinderzimmer, Dachboden und Keller.
## In der Belagerungsnacht zeigen sie, wie stark es dort drückt (grün → rot), und man hört es leise knistern.
## Braucht Strom. Die Sender stehen in den drei Räumen (nur Deko, `sender()`).

const LABELS := ["Kind", "Dach", "Keller"]

var _bars: Array[MeshInstance3D] = []
var _mats: Array[StandardMaterial3D] = []
var _power_led: StandardMaterial3D
var _hiss: AudioStreamPlayer3D


func _ready() -> void:
	add_to_group("babyfon")
	var shell := BuildKit.color_mat(Color(0.9, 0.88, 0.82), 0.5)
	BuildKit.box(self, Vector3(0.16, 0.1, 0.06), Vector3(0, 0.05, 0), shell, false)
	BuildKit.cylinder(self, 0.006, 0.12, Vector3(0.06, 0.16, -0.01), BuildKit.color_mat(Color(0.2, 0.2, 0.2)), false, Vector3.ZERO, 0.004, 5)
	BuildKit.box(self, Vector3(0.14, 0.08, 0.004), Vector3(0, 0.05, 0.031), BuildKit.color_mat(Color(0.08, 0.09, 0.09), 0.3), false)
	for i in 3:
		var m := BuildKit.emissive_mat(Color(0.2, 0.9, 0.3), 0.0)
		var bar := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.025, 0.06, 0.004)
		bar.mesh = bm
		bar.material_override = m
		bar.position = Vector3(-0.045 + i * 0.045, 0.045, 0.034)
		add_child(bar)
		_bars.append(bar)
		_mats.append(m)
		var lab := Label3D.new()
		lab.text = LABELS[i]
		lab.font_size = 14
		lab.pixel_size = 0.0012
		lab.modulate = Color(0.85, 0.85, 0.8)
		lab.outline_size = 0
		lab.double_sided = false
		lab.position = Vector3(-0.045 + i * 0.045, 0.087, 0.034)
		add_child(lab)
	_power_led = BuildKit.emissive_mat(Color(0.3, 1.0, 0.4), 0.0)
	BuildKit.sphere(self, 0.006, Vector3(0.065, 0.088, 0.032), _power_led, Vector3.ONE, 5)
	var body := Area3D.new()
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(0.25, 0.25, 0.2)
	cs.shape = sh
	cs.position = Vector3(0, 0.08, 0)
	body.add_child(cs)
	add_child(body)
	_hiss = AudioStreamPlayer3D.new()
	_hiss.stream = SoundBank.get_sound("static")
	_hiss.volume_db = -30.0
	_hiss.unit_size = 1.5
	add_child(_hiss)


func _process(_delta: float) -> void:
	var on := PowerManager.has_power()
	_power_led.emission_energy_multiplier = 1.5 if on else 0.0
	var levels: Array = SiegeNight.current.monitor_levels() if SiegeNight.current else [-1.0, -1.0, -1.0]
	var loud := 0.0
	for i in 3:
		var lv: float = levels[i]
		var shown := clampf(lv, 0.05, 1.0) if on and lv >= 0.0 else 0.0
		_bars[i].scale = Vector3(1, maxf(shown, 0.05), 1)
		_bars[i].position.y = 0.015 + 0.03 * maxf(shown, 0.05)
		_mats[i].emission = Color(0.2, 0.9, 0.3).lerp(Color(1.0, 0.15, 0.1), clampf(lv, 0.0, 1.0))
		_mats[i].emission_energy_multiplier = 2.0 if shown > 0.0 else 0.0
		loud = maxf(loud, lv)
	if on and SiegeNight.current and loud > 0.3:
		if not _hiss.playing:
			_hiss.play()
		_hiss.volume_db = lerpf(-28.0, -10.0, loud)
	elif _hiss.playing:
		_hiss.stop()


func get_prompt(_p: Node) -> String:
	if not PowerManager.has_power():
		return "Babyfon – kein Strom"
	if SiegeNight.current == null:
		return "Babyfon (Kinderzimmer · Dachboden · Keller)"
	var l: Array = SiegeNight.current.monitor_levels()
	var parts := []
	for i in 3:
		parts.append("%s %s" % [LABELS[i], "–" if l[i] < 0.0 else "%d %%" % int(l[i] * 100.0)])
	return "Babyfon:  " + "   ".join(parts)


## Kleiner Sender (Deko) für Kinderzimmer, Dachboden und Keller.
static func sender(parent: Node3D, pos: Vector3, rot_y: float) -> void:
	var n := Node3D.new()
	n.position = pos
	n.rotation_degrees.y = rot_y
	parent.add_child(n)
	BuildKit.box(n, Vector3(0.07, 0.11, 0.05), Vector3(0, 0.055, 0), BuildKit.color_mat(Color(0.9, 0.88, 0.82), 0.5), false)
	BuildKit.sphere(n, 0.006, Vector3(0, 0.095, 0.026), BuildKit.emissive_mat(Color(0.3, 1.0, 0.4), 1.2), Vector3.ONE, 5)
	BuildKit.cylinder(n, 0.022, 0.003, Vector3(0, 0.06, 0.026), BuildKit.color_mat(Color(0.2, 0.2, 0.2)), false, Vector3(90, 0, 0), -1.0, 8)
