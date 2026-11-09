class_name FuelGauge
extends Interactable
## Große analoge Tankanzeige des Generators (Werkstatt-Wand). Zeigt, wie viel Benzin im Schuppen-Generator ist.
## Anvisieren zeigt zusätzlich, wie lange es bei laufendem Generator ungefähr noch reicht.
## Vorderseite = +z (lokal). Zeiger: links E (leer) … rechts F (voll), roter Bereich unten.

const RADIUS := 0.2
const SWEEP := 70.0   ## Grad links/rechts von oben

var _needle: Node3D
var _shown: float = -1.0


func _ready() -> void:
	var wood := BuildKit.tex_mat("planks_h", 0.5, Color(0.55, 0.45, 0.36))
	var iron := BuildKit.color_mat(Color(0.18, 0.18, 0.19), 0.45, 0.7)
	var face := BuildKit.color_mat(Color(0.9, 0.86, 0.74), 0.7)
	var ink := BuildKit.color_mat(Color(0.08, 0.07, 0.06), 0.8)
	var red := BuildKit.color_mat(Color(0.75, 0.12, 0.08), 0.7)
	# Brett, Messinggehäuse, Zifferblatt, Glasscheibe
	BuildKit.box(self, Vector3(0.56, 0.62, 0.025), Vector3(0, -0.04, 0.0125), wood, false)
	BuildKit.cylinder(self, RADIUS + 0.025, 0.06, Vector3(0, 0, 0.045), BuildKit.color_mat(Color(0.62, 0.48, 0.25), 0.35, 0.8), false, Vector3(90, 0, 0), -1.0, 24)
	BuildKit.cylinder(self, RADIUS, 0.005, Vector3(0, 0, 0.077), face, false, Vector3(90, 0, 0), -1.0, 24)
	# Skala: Striche entlang des Bogens, die ersten (fast leer) rot
	for k in 11:
		var a := deg_to_rad(SWEEP - 2.0 * SWEEP * k / 10.0)
		var long := k % 5 == 0
		var l := 0.05 if long else 0.028
		# k = 0 ist ganz links (leer), wie der Zeiger: Drehung um +a gegen den Uhrzeigersinn
		var p := Vector3(-sin(a) * (RADIUS - 0.015 - l * 0.5), cos(a) * (RADIUS - 0.015 - l * 0.5), 0.081)
		BuildKit.box(self, Vector3(0.008 if long else 0.005, l, 0.002), p, red if k < 2 else ink, false, Vector3(0, 0, rad_to_deg(a)))
	for t: Array in [["E", -SWEEP], ["½", 0.0], ["F", SWEEP]]:
		var lab := Label3D.new()
		lab.text = t[0]
		lab.font_size = 48
		lab.pixel_size = 0.0012
		lab.modulate = Color(0.1, 0.08, 0.06)
		lab.outline_size = 0
		lab.position = Vector3(sin(deg_to_rad(float(t[1]))) * (RADIUS - 0.085), cos(deg_to_rad(float(t[1]))) * (RADIUS - 0.085), 0.083)
		add_child(lab)
	var title := Label3D.new()
	title.text = "BENZIN  GENERATOR"
	title.font_size = 32
	title.pixel_size = 0.001
	title.modulate = Color(0.1, 0.08, 0.06)
	title.outline_size = 0
	title.position = Vector3(0, -0.075, 0.083)
	add_child(title)
	# Zeiger mit Nabe
	_needle = Node3D.new()
	_needle.position = Vector3(0, 0, 0.086)
	add_child(_needle)
	BuildKit.box(_needle, Vector3(0.012, RADIUS - 0.03, 0.003), Vector3(0, (RADIUS - 0.03) * 0.5, 0), red, false)
	BuildKit.cylinder(self, 0.018, 0.012, Vector3(0, 0, 0.088), iron, false, Vector3(90, 0, 0), -1.0, 10)
	var glass := BuildKit.box(self, Vector3(RADIUS * 1.9, RADIUS * 1.9, 0.004), Vector3(0, 0, 0.092), BuildKit.glass_mat(), false)
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Kabel zur Wand hinunter (die Leitung vom Schuppen)
	BuildKit.box(self, Vector3(0.02, 0.6, 0.02), Vector3(0.22, -0.6, 0.02), iron, false)
	# zum Anvisieren
	var area := Area3D.new()
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(0.5, 0.55, 0.12)
	cs.shape = sh
	cs.position = Vector3(0, -0.03, 0.06)
	area.add_child(cs)
	add_child(area)


func _process(delta: float) -> void:
	var target := clampf(PowerManager.fuel / 100.0, 0.0, 1.0)
	_shown = target if _shown < 0.0 else lerpf(_shown, target, clampf(delta * 2.0, 0.0, 1.0))
	# leichtes Zittern, solange der Generator läuft
	var jitter := sin(Time.get_ticks_msec() / 90.0) * 0.6 if PowerManager.has_power() else 0.0
	_needle.rotation_degrees.z = SWEEP - 2.0 * SWEEP * _shown + jitter


func get_prompt(_p: Node) -> String:
	var f := PowerManager.fuel
	if f <= 0.0:
		return "Tankanzeige Generator: leer"
	var h := PowerManager.hours_left()
	var run := "reicht noch etwa %d Std." % int(round(h)) if PowerManager.generator_running else "Generator steht"
	return "Tankanzeige Generator: %d %%  –  %s" % [int(round(f)), run]
