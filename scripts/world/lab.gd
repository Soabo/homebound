class_name Lab
extends Node3D
## Das Labor im Bad (Forschung 2.0). Christian baut den Waschtisch um, sobald die Forschung es verlangt
## (research.json "lab.unlock"). Danach kommen nach und nach Plätze dazu: Arbeitsplatte (mit dem Umbau),
## Mikroskop, Terrarium, Abschirmkasten, Auswertungsplatz und die Ladeschale.
## Zustand liegt in Research (lab_built, lab_stations, charger_built, lab_bloom); hier nur Modelle und Bedienung.
## Koordinaten in Hütten-Koordinaten (Kind von Cabin).

const Y := Cabin.FLOOR_Y
const X1 := Cabin.HALF_X - Cabin.CLAD          ## Ostwand innen
const TOP := Cabin.FLOOR_Y + 0.86             ## Höhe der Arbeitsplatte
const SPOTS := {
	"bench": Vector3(X1 - 0.25, TOP, -3.45),
	"microscope": Vector3(X1 - 0.25, TOP, -2.9),
	"shield": Vector3(X1 - 0.27, TOP, -4.02),
	"terrarium": Vector3(4.98, Y + 0.72, -1.3),
	"screen": Vector3(X1 - 0.3, Y + 0.5, -1.45),
	"charger": Vector3(X1 - 0.16, Y + 1.62, -3.15),
}

var _parts: Dictionary = {}       ## Station -> Node3D (Modell)
var _bloom: Node3D
var _counter: Node3D
var _t: float = 0.0
var _creature_mat: StandardMaterial3D


func _ready() -> void:
	add_to_group("lab")
	var setup := LabControl.new()
	setup.name = "LabSetup"
	setup.station = ""
	setup.anchor = Vector3(X1 - 0.25, Y + 0.4, -2.3)
	setup.size = Vector3(0.5, 0.7, 0.62)
	add_child(setup)
	_build_counter()
	for st: String in SPOTS:
		_build_station(st)
	_build_bloom()
	Research.changed.connect(_refresh)
	_refresh()


func station_point(st: String) -> Vector3:
	return to_global(SPOTS.get(st, Vector3(X1 - 0.25, TOP, -2.3)))


func _refresh() -> void:
	_counter.visible = Research.lab_built
	_set_solid(_counter, Research.lab_built)
	for st: String in _parts:
		var on := Research.charger_built if st == "charger" else Research.station_built(st)
		(_parts[st] as Node3D).visible = on
		_set_solid(_parts[st], on)
	_bloom.visible = Research.lab_bloom
	# Probe im Terrarium sichtbar, solange dort etwas läuft
	var t := _parts.get("terrarium") as Node3D
	if t and t.has_node("Sample"):
		t.get_node("Sample").visible = String(Research.stations.get("terrarium", "")) != ""


func _process(delta: float) -> void:
	_t += delta
	if _creature_mat and _parts["terrarium"].visible:
		_creature_mat.emission_energy_multiplier = 0.6 + sin(_t * 1.7) * 0.4
	if _bloom.visible:
		var l := _bloom.get_node_or_null("Glow") as OmniLight3D
		if l:
			l.light_energy = 0.5 + sin(_t * 0.9) * 0.15


# --- Modelle -------------------------------------------------------------

func _build_counter() -> void:
	_counter = Node3D.new()
	_counter.name = "Counter"
	add_child(_counter)
	var wood := BuildKit.tex_mat("planks_h", 0.5, Color(0.75, 0.6, 0.45))
	var dark := BuildKit.tex_mat("planks_h", 0.5, Color(0.5, 0.38, 0.28))
	# Arbeitsplatte nördlich vom Waschbecken, Beine, Bord darunter, Wandregal darüber
	BuildKit.box_mm(_counter, Vector3(X1 - 0.52, TOP - 0.05, -4.3), Vector3(X1, TOP, -2.62), wood, true, "LabTop")
	for z: float in [-4.25, -2.68]:
		BuildKit.box_mm(_counter, Vector3(X1 - 0.5, Y, z - 0.03), Vector3(X1 - 0.45, TOP - 0.05, z + 0.03), dark, false)
	BuildKit.box_mm(_counter, Vector3(X1 - 0.5, Y + 0.25, -4.28), Vector3(X1, Y + 0.28, -2.64), dark, false)
	BuildKit.box_mm(_counter, Vector3(X1 - 0.24, Y + 1.5, -4.3), Vector3(X1, Y + 1.53, -2.62), dark, false)
	# Gläser, Pipetten, Kanister unter der Platte
	var glass := _glass(Color(0.75, 0.85, 0.85, 0.35))
	for k in 6:
		var h := 0.08 + (k % 3) * 0.04
		BuildKit.cylinder(_counter, 0.035, h, Vector3(X1 - 0.12, Y + 1.53 + h * 0.5, -4.15 + k * 0.22), glass, false, Vector3.ZERO, -1.0, 10)
	BuildKit.box(_counter, Vector3(0.25, 0.3, 0.2), Vector3(X1 - 0.25, Y + 0.43, -3.9), BuildKit.color_mat(Color(0.75, 0.75, 0.7), 0.5), false)
	BuildKit.box(_counter, Vector3(0.3, 0.18, 0.3), Vector3(X1 - 0.25, Y + 0.37, -3.2), BuildKit.tex_mat("fabric", 0.3, Color(1.45, 1.2, 0.85)), false)
	# Schreibzettel mit Skizzen an der Wand
	for k in 3:
		BuildKit.box(_counter, Vector3(0.005, 0.2, 0.15), Vector3(X1 - 0.01, Y + 1.25, -3.9 + k * 0.4), BuildKit.color_mat(Color(0.9, 0.88, 0.8), 0.9), false, Vector3(k * 4.0 - 4.0, 0, 0))


func _build_station(st: String) -> void:
	var n := Node3D.new()
	n.name = "Station_" + st
	add_child(n)
	_parts[st] = n
	var p: Vector3 = SPOTS[st]
	var metal := BuildKit.tex_mat("metal", 0.3, Color(1.0, 1.0, 1.0), 0.5)
	var dark := BuildKit.color_mat(Color(0.13, 0.13, 0.14), 0.5)
	match st:
		"bench":
			# Gaskocher mit Topf, Mörser, Spritzflasche
			BuildKit.box(n, Vector3(0.3, 0.08, 0.22), p + Vector3(0, 0.04, 0), BuildKit.color_mat(Color(0.2, 0.3, 0.55), 0.5), false)
			BuildKit.cylinder(n, 0.06, 0.02, p + Vector3(0, 0.09, 0), dark, false, Vector3.ZERO, -1.0, 10)
			BuildKit.cylinder(n, 0.08, 0.1, p + Vector3(0, 0.15, 0), metal, false, Vector3.ZERO, -1.0, 12)
			BuildKit.cylinder(n, 0.05, 0.06, p + Vector3(0.05, 0.03, 0.22), BuildKit.tex_mat("stone", 0.4), false, Vector3.ZERO, 0.04, 10)
			BuildKit.cylinder(n, 0.03, 0.14, p + Vector3(0.12, 0.07, -0.2), _glass(Color(0.9, 0.95, 1.0, 0.5)), false, Vector3.ZERO, -1.0, 8)
		"microscope":
			BuildKit.box(n, Vector3(0.18, 0.03, 0.2), p + Vector3(0, 0.015, 0), dark, false)
			BuildKit.box(n, Vector3(0.05, 0.25, 0.05), p + Vector3(0.05, 0.14, 0), dark, false)
			BuildKit.cylinder(n, 0.025, 0.18, p + Vector3(0.0, 0.25, 0), metal, false, Vector3(0, 0, 30), -1.0, 10)
			BuildKit.box(n, Vector3(0.12, 0.012, 0.12), p + Vector3(-0.02, 0.1, 0), metal, false)
			BuildKit.cylinder(n, 0.02, 0.05, p + Vector3(-0.05, 0.36, 0), dark, false, Vector3(0, 0, 30), -1.0, 8)
			# Taschenlampe als Lichtquelle
			BuildKit.cylinder(n, 0.02, 0.12, p + Vector3(-0.1, 0.04, 0.08), BuildKit.color_mat(Color(0.7, 0.15, 0.1), 0.4), false, Vector3(0, 0, 90), -1.0, 8)
		"shield":
			BuildKit.box(n, Vector3(0.42, 0.3, 0.4), p + Vector3(0, 0.15, 0), BuildKit.tex_mat("metal", 0.4, Color(0.75, 0.75, 0.7), 0.6), false)
			BuildKit.box(n, Vector3(0.44, 0.02, 0.42), p + Vector3(0, 0.31, 0), metal, false)
			BuildKit.box(n, Vector3(0.01, 0.02, 0.1), p + Vector3(-0.215, 0.22, 0), dark, false)
			var led := BuildKit.emissive_mat(Color(1.0, 0.35, 0.2), 1.5)
			BuildKit.sphere(n, 0.012, p + Vector3(-0.215, 0.27, 0.15), led, Vector3.ONE, 6)
		"terrarium":
			var wood := BuildKit.tex_mat("planks_h", 0.5, Color(0.7, 0.55, 0.4))
			BuildKit.box_mm(n, Vector3(p.x - 0.32, Y, p.z - 0.2), Vector3(p.x + 0.32, Y + 0.7, p.z + 0.2), wood, true, "TerrariumStand")
			BuildKit.box(n, Vector3(0.6, 0.34, 0.36), p + Vector3(0, 0.17, 0), _glass(Color(0.7, 0.85, 0.8, 0.25)), false)
			BuildKit.box(n, Vector3(0.62, 0.02, 0.38), p + Vector3(0, 0.35, 0), BuildKit.tex_mat("metal", 0.3, Color(0.6, 0.6, 0.6), 0.6), false)
			BuildKit.box(n, Vector3(0.58, 0.06, 0.34), p + Vector3(0, 0.03, 0), BuildKit.color_mat(Color(0.2, 0.15, 0.1), 0.9), false)
			var sample := Node3D.new()
			sample.name = "Sample"
			n.add_child(sample)
			_creature_mat = BuildKit.emissive_mat(Color(0.55, 0.9, 0.75), 0.8)
			BuildKit.sphere(sample, 0.07, p + Vector3(-0.08, 0.1, 0.03), BuildKit.color_mat(Color(0.4, 0.38, 0.42), 0.5), Vector3(1.4, 0.7, 1.0), 8)
			for k in 5:
				BuildKit.box(sample, Vector3(0.18, 0.008, 0.008), p + Vector3(-0.02 + k * 0.03, 0.08, -0.05 + k * 0.025), _creature_mat, false, Vector3(0, k * 37.0, 8))
		"screen":
			# der alte Laptop auf dem Wäschekorb
			BuildKit.box(n, Vector3(0.34, 0.02, 0.24), p + Vector3(0, 0.01, 0), dark, false, Vector3(0, 90, 0))
			BuildKit.box(n, Vector3(0.015, 0.22, 0.34), p + Vector3(0.12, 0.12, 0), dark, false, Vector3(0, 0, -12))
			BuildKit.box(n, Vector3(0.005, 0.18, 0.3), p + Vector3(0.11, 0.12, 0), BuildKit.emissive_mat(Color(0.35, 0.6, 0.7), 0.8), false, Vector3(0, 0, -12))
		"charger":
			BuildKit.cylinder(n, 0.1, 0.03, p + Vector3(0, 0.03, 0), metal, false, Vector3.ZERO, 0.07, 14)
			var c := BuildKit.emissive_mat(Color(0.45, 0.9, 1.0), 1.2)
			BuildKit.box(n, Vector3(0.05, 0.09, 0.05), p + Vector3(0, 0.08, 0), c, false, Vector3(10, 30, 5))
	n.visible = false
	if st == "charger":
		return
	var ctl := LabControl.new()
	ctl.name = "Control_" + st
	ctl.station = st
	ctl.anchor = p + (Vector3(0, -0.35, 0) if st == "terrarium" else Vector3(0, 0.15, 0))
	ctl.size = Vector3(0.6, 1.05, 0.45) if st == "terrarium" else Vector3(0.42, 0.34, 0.42)
	n.add_child(ctl)


func _build_bloom() -> void:
	_bloom = Node3D.new()
	_bloom.name = "Bloom"
	add_child(_bloom)
	var glow := BuildKit.emissive_mat(Color(0.45, 1.0, 0.85), 1.4)
	var grey := BuildKit.color_mat(Color(0.35, 0.34, 0.36), 0.7)
	var r := RandomNumberGenerator.new()
	r.seed = 1717
	for k in 26:
		var on_wall := k % 3 != 0
		var p := Vector3(X1 - 0.02, Y + r.randf_range(0.3, 2.2), r.randf_range(-4.2, -1.3)) if on_wall else \
			Vector3(r.randf_range(2.3, 5.7), Cabin.WALL_TOP - 0.02, r.randf_range(-4.2, -1.3))
		BuildKit.sphere(_bloom, r.randf_range(0.04, 0.11), p, glow if k % 2 == 0 else grey, Vector3(0.4, 1.0, 1.0) if on_wall else Vector3(1.0, 0.4, 1.0), 6)
	var l := OmniLight3D.new()
	l.name = "Glow"
	l.light_color = Color(0.5, 1.0, 0.85)
	l.omni_range = 3.5
	l.light_energy = 0.5
	l.position = Vector3(4.5, Y + 1.8, -2.7)
	_bloom.add_child(l)
	_bloom.visible = false


## Unsichtbare Teile dürfen nicht im Weg stehen (Kollision aus, solange nicht gebaut).
static func _set_solid(n: Node, on: bool) -> void:
	for c in n.get_children():
		if c is CollisionShape3D:
			(c as CollisionShape3D).set_deferred("disabled", not on)
		_set_solid(c, on)


static func _glass(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.08
	m.metallic_specular = 0.8
	return m


## Bedienfeld einer Station (oder, mit station "", der Waschtisch: umbauen bzw. Labor-Übersicht).
class LabControl extends Interactable:
	var station: String = ""
	var anchor: Vector3 = Vector3.ZERO
	var size: Vector3 = Vector3(0.4, 0.3, 0.4)

	func _ready() -> void:
		var body := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = size
		cs.shape = sh
		cs.position = anchor
		body.add_child(cs)
		add_child(body)

	func _usable() -> bool:
		var p := get_parent() as Node3D
		return station == "" or (p and p.visible)

	func get_prompt(_p: Node) -> String:
		if not _usable():
			return ""
		if station == "":
			if Research.lab_built:
				return "[E] Labor einrichten (Plätze einbauen)" + ("   –   Wucherung abkratzen mit R" if Research.lab_bloom else "")
			if Research.lab_offered:
				var needs: Dictionary = Research.lab_def().get("needs", {})
				var parts: PackedStringArray = []
				for it: String in needs:
					parts.append("%s %d/%d" % [Inventory.display_name(it), Inventory.count(it), int(needs[it])])
				return "[E] Waschtisch zum Labor umbauen  (%s)" % ", ".join(parts)
			return ""
		var id := String(Research.stations.get(station, ""))
		var what := ("  –  " + String(Research.analysis(id).get("name", id)) + " %d %%" % int(Research.progress_of(id) * 100.0)) if id != "" else "  –  frei"
		return "[E] %s%s" % [Research.station_name(station), what]

	func get_secondary_prompt(_p: Node) -> String:
		if station == "" and Research.lab_bloom:
			return "[R] Wucherung abkratzen"
		return ""

	func interact(_p: Node) -> void:
		if not _usable():
			return
		var menu := get_tree().get_first_node_in_group("research_menu") as ResearchMenu
		if station == "":
			if not Research.lab_built:
				if not Research.lab_offered:
					return
				var err := Research.build_lab()
				if err != "":
					EventBus.notify(err, 3.0)
				else:
					SoundBank.play_at(self, "hammer", global_position + anchor, -2.0)
				return
			if menu:
				menu.open_lab()
			return
		if menu:
			menu.open_station(station)

	func secondary_interact(_p: Node) -> void:
		if station == "" and Research.lab_bloom:
			Research.clean_bloom()
			SoundBank.play_at(self, "scratch", global_position + anchor, -4.0)
