class_name BabyfonHandheld
extends Node3D
## Babyfon 2.0 (Christian 27.11.): In der Belagerungsnacht hält man die Basisstation in der linken Hand.
## Das Display zeigt nur die Aufgaben dieser Nacht – je Zeile Raum + Balken (grün → rot), die dringendste
## Zeile blinkt, und wenn eine Zeile rot wird, piept es leise. Ursprung = Griffstelle, +y oben, Display nach +z.

const ROWS := 5
const W := 0.072      # Breite des Geräts
const H := 0.12       # Höhe des Gehäuses (über der Faust)
const D := 0.026      # Tiefe
const BOTTOM := 0.028   # Unterkante des Gehäuses – darunter der Griff in der Faust
const ALARM_AT := 0.7

var _labels: Array[Label3D] = []
var _bars: Array[MeshInstance3D] = []
var _bar_mats: Array[StandardMaterial3D] = []
var _backs: Array[MeshInstance3D] = []
var _idle: Label3D
var _led: StandardMaterial3D
var _alarmed: Dictionary = {}
var _time: float = 0.0
## Für Tests/Vorschau: feste Zeilen statt SiegeNight.current
var preview_rows: Array = []


func _ready() -> void:
	var shell := BuildKit.color_mat(Color(0.9, 0.88, 0.82), 0.5)
	var dark := BuildKit.color_mat(Color(0.06, 0.07, 0.07), 0.3)
	var cy := BOTTOM + H * 0.5
	BuildKit.box(self, Vector3(W, H, D), Vector3(0, cy, 0), shell, false)
	# Griff (liegt in der Faust)
	BuildKit.box(self, Vector3(0.024, 0.09, D * 0.9), Vector3(0, BOTTOM - 0.04, 0), shell, false)
	# Antenne oben links, Lautsprecherschlitze unten
	BuildKit.cylinder(self, 0.005, 0.07, Vector3(-W * 0.32, BOTTOM + H + 0.035, -0.004), BuildKit.color_mat(Color(0.2, 0.2, 0.2)), false, Vector3.ZERO, 0.0035, 6)
	for i in 3:
		BuildKit.box(self, Vector3(W * 0.5, 0.002, 0.002), Vector3(0, BOTTOM + 0.012 + i * 0.006, D * 0.5 + 0.001), dark, false)
	# Display (dunkel, leuchtet nicht selbst – die Balken leuchten)
	var disp_h := 0.074
	var disp_y := BOTTOM + H - 0.012 - disp_h * 0.5
	BuildKit.box(self, Vector3(W - 0.01, disp_h, 0.002), Vector3(0, disp_y, D * 0.5 + 0.001), dark, false)
	var row_h := disp_h / ROWS
	for i in ROWS:
		var y := disp_y + disp_h * 0.5 - row_h * (i + 0.5)
		var lab := Label3D.new()
		lab.font_size = 22
		lab.pixel_size = 0.00036
		lab.outline_size = 0
		lab.double_sided = false
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		lab.position = Vector3(-W * 0.5 + 0.008, y + row_h * 0.17, D * 0.5 + 0.0025)
		lab.modulate = Color(0.85, 0.9, 0.85)
		add_child(lab)
		_labels.append(lab)
		var back := _bar(Vector3(W - 0.018, row_h * 0.26, 0.001), Vector3(0, y - row_h * 0.22, D * 0.5 + 0.0022), Color(0.15, 0.17, 0.16), 0.0)
		_backs.append(back)
		var bar := _bar(Vector3(W - 0.018, row_h * 0.26, 0.0012), Vector3(0, y - row_h * 0.22, D * 0.5 + 0.0028), Color(0.2, 0.9, 0.3), 2.0)
		_bars.append(bar)
		_bar_mats.append(bar.material_override as StandardMaterial3D)
	_idle = Label3D.new()
	_idle.font_size = 22
	_idle.pixel_size = 0.0004
	_idle.outline_size = 0
	_idle.double_sided = false
	_idle.text = "ruhig"
	_idle.modulate = Color(0.4, 0.8, 0.45)
	_idle.position = Vector3(0, disp_y, D * 0.5 + 0.0025)
	add_child(_idle)
	_led = BuildKit.emissive_mat(Color(0.3, 1.0, 0.4), 1.5)
	BuildKit.sphere(self, 0.0035, Vector3(W * 0.32, BOTTOM + H - 0.006, D * 0.5 + 0.001), _led, Vector3.ONE, 5)


func _bar(size: Vector3, pos: Vector3, col: Color, energy: float) -> MeshInstance3D:
	var m := BuildKit.emissive_mat(col, energy)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m
	mi.position = pos
	add_child(mi)
	return mi


func rows() -> Array:
	if not preview_rows.is_empty():
		return preview_rows
	return SiegeNight.current.monitor_rows() if SiegeNight.current else []


func _process(delta: float) -> void:
	if not is_visible_in_tree() and preview_rows.is_empty():
		return
	_time += delta
	var list := rows()
	var worst := -1
	var worst_lv := 0.0
	for i in list.size():
		if float(list[i]["level"]) > worst_lv:
			worst_lv = float(list[i]["level"])
			worst = i
	_idle.visible = list.is_empty()
	for i in ROWS:
		var on := i < list.size()
		_labels[i].visible = on
		_bars[i].visible = on
		_backs[i].visible = on
		if not on:
			continue
		var r: Dictionary = list[i]
		var lv := clampf(float(r["level"]), 0.0, 1.0)
		_labels[i].text = String(r["label"])
		var shown := maxf(lv, 0.04)
		_bars[i].scale = Vector3(shown, 1, 1)
		_bars[i].position.x = -(W - 0.018) * 0.5 * (1.0 - shown)
		var col := Color(0.2, 0.9, 0.3).lerp(Color(1.0, 0.6, 0.1), clampf(lv * 2.0, 0.0, 1.0)).lerp(Color(1.0, 0.12, 0.08), clampf(lv * 2.0 - 1.0, 0.0, 1.0))
		_bar_mats[i].emission = col
		var blink := i == worst and lv >= ALARM_AT and fmod(_time, 0.5) < 0.25
		_labels[i].modulate = Color(1.0, 0.35, 0.3) if blink else (Color(1.0, 0.75, 0.5) if i == worst and lv >= 0.4 else Color(0.85, 0.9, 0.85))
		# Piepen, wenn eine Zeile rot wird (einmal je Anstieg)
		var id := String(r.get("id", str(i)))
		if lv >= ALARM_AT and not _alarmed.get(id, false):
			_alarmed[id] = true
			if is_inside_tree() and preview_rows.is_empty():
				SoundBank.play_ui(self, "signal", -14.0, 1.6)
		elif lv < ALARM_AT - 0.15:
			_alarmed[id] = false
	_led.emission_energy_multiplier = 1.5 if worst_lv < ALARM_AT or fmod(_time, 0.4) < 0.2 else 0.2
