class_name Structure
extends Interactable
## Ein vom Spieler gebautes Objekt auf dem Grundstück (GDD 7.2).
##  - fence_panel / stone_wall: Hindernis, die Kreatur muss es zerlegen
##  - spike_barricade: Hindernis, verletzt und verscheucht die Kreatur
##  - can_alarm: klappert laut, wenn etwas durchläuft (Frühwarnung)
##  - motion_light: Batterielampe, springt bei Bewegung an; Licht scheucht auf
##  - resonance_sensor: (Forschung) spürt die Kreatur auf große Entfernung, meldet die Richtung
##  - strobe_light: (Forschung) flackert grell im Takt, vertreibt die Kreatur lange
##  - signal_jammer: (Forschung) stört Drohnen im Umkreis – sie drehen ab
##  - growth_barrier: (Forschung) Myzel-Sperre: hält Wucherungen fern, lässt nahe absterben
## Werte kommen aus data/items/buildables.json.

var uid: int = 0
var camp: TentCamp        ## nur beim Zelt
var fire: Campfire        ## nur beim Lagerfeuer
var type: String = "fence_panel"
var health: float = 50.0
var max_health: float = 50.0
var size: Vector3 = Vector3.ONE
var is_obstacle: bool = false
var preview: bool = false  ## true = nur Bauvorschau, ohne Kollision und Logik

var _alarm_cooldown: float = 0.0
var _light: SpotLight3D
var _light_mat: StandardMaterial3D
var _light_time: float = 0.0
var _scared_at: float = -999.0
var _strobe: OmniLight3D
var _strobe_time: float = 0.0
var _sense_cooldown: float = 0.0
var _t: float = 0.0
var armed: bool = true          ## Bärenfalle gespannt?
var _player_on_trap: bool = false  ## nach dem Spannen: erst auslösen, wenn der Spieler einmal heruntergetreten ist
var _jaws: Array[Node3D] = []
var _bloodied: bool = false     ## Spießbarrikade: grünes Blut an den Spießen
var _spike_mat: StandardMaterial3D


func _ready() -> void:
	var def := DataDB.buildable(type)
	max_health = float(def.get("health", 50))
	if health <= 0.0 or health > max_health:
		health = max_health
	var sz: Array = def.get("size", [1, 1, 1])
	size = Vector3(sz[0], sz[1], sz[2])
	is_obstacle = bool(def.get("obstacle", false)) and not preview
	_build_visual()
	if preview:
		return
	if is_obstacle:
		add_to_group("obstacle")
	add_to_group("structure")
	if type == "signal_jammer":
		add_to_group("jammer")
	elif type == "drone_decoy":
		add_to_group("drone_decoy")
	elif type == "light_lure":
		add_to_group("seeker_lure")
	elif type == "growth_barrier":
		add_to_group("growth_barrier")
		_wither_patches.call_deferred()
	if type == "snare":
		refresh_catch()
	if type == "tent":
		camp = TentCamp.new()
		camp.name = "Camp"
		camp.structure = self
		add_child(camp)
	if type in ["bear_trap", "snare", "campfire"]:
		if type == "campfire":
			fire = Campfire.new()
			fire.name = "Fire"
			fire.structure = self
			add_child(fire)
		if type == "bear_trap":
			armed = bool(Builder.record(uid).get("armed", true))
			_set_jaws(armed, false)
		# kein fester Körper – man soll hineintreten können; Bereich nur fürs Anschauen/Interagieren
		var area := Area3D.new()
		var acs := CollisionShape3D.new()
		var ab := BoxShape3D.new()
		ab.size = Vector3(size.x, 0.2, size.z)
		acs.shape = ab
		acs.position = Vector3(0, 0.1, 0)
		area.add_child(acs)
		add_child(area)
		return
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size if is_obstacle or type in ["motion_light", "strobe_light", "resonance_sensor", "signal_jammer", "growth_barrier", "drone_decoy", "light_lure"] else Vector3(size.x, 0.3, 0.4)
	cs.shape = shape
	cs.position = Vector3(0, shape.size.y * 0.5, 0)
	body.add_child(cs)
	add_child(body)


func _build_visual() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = uid * 77 + 3
	match type:
		"fence_panel":
			var post := BuildKit.tex_mat("logs", 0.8)
			var board := BuildKit.tex_mat("planks_h", 1.0, Color(1.15, 1.1, 1.0))
			for x: float in [-1.1, 1.1]:
				BuildKit.cylinder(self, 0.07, 1.3, Vector3(x, 0.65, 0), post, false, Vector3.ZERO, 0.06, 7)
			for i in 4:
				BuildKit.box(self, Vector3(2.35, 0.2, 0.04), Vector3(0, 0.25 + i * 0.26, 0.06), board, false, Vector3(0, 0, rng.randf_range(-1.5, 1.5)))
			BuildKit.box(self, Vector3(2.5, 0.12, 0.04), Vector3(0, 0.6, 0.1), board, false, Vector3(0, 0, 24))
		"spike_barricade":
			var stake := BuildKit.tex_mat("logs", 0.5, Color(1.1, 1.0, 0.9))
			_spike_mat = stake
			BuildKit.cylinder(self, 0.08, 1.9, Vector3(0, 0.35, 0), stake, false, Vector3(0, 0, 90), -1.0, 7)
			for i in 6:
				var x := -0.75 + i * 0.3
				for side: float in [-1.0, 1.0]:
					BuildKit.cylinder(self, 0.05, 1.2, Vector3(x, 0.55, side * 0.18), stake, false, Vector3(side * 50.0, 0, rng.randf_range(-8, 8)), 0.0, 6)
		"bear_trap":
			_build_bear_trap()
		"snare":
			_build_snare()
		"tent":
			_build_tent()
		"campfire":
			pass  # baut Campfire selbst
		"stone_wall":
			var stone := BuildKit.tex_mat("stone", 0.6)
			for row in 3:
				for i in 4:
					var w := rng.randf_range(0.35, 0.5)
					BuildKit.box(self, Vector3(w, 0.28, size.z * rng.randf_range(0.85, 1.0)),
							Vector3(-0.6 + i * 0.4 + (row % 2) * 0.12, 0.15 + row * 0.29, 0), stone, false,
							Vector3(rng.randf_range(-4, 4), rng.randf_range(-6, 6), rng.randf_range(-3, 3)))
		"can_alarm":
			var peg := BuildKit.tex_mat("logs", 0.4)
			var wire := BuildKit.color_mat(Color(0.7, 0.7, 0.68), 0.4, 0.6)
			var can := BuildKit.tex_mat("metal", 0.2, Color(1.5, 1.5, 1.5), 0.4)
			for x: float in [-1.5, 1.5]:
				BuildKit.cylinder(self, 0.03, 0.45, Vector3(x, 0.22, 0), peg, false, Vector3.ZERO, 0.02, 5)
			BuildKit.box(self, Vector3(3.0, 0.006, 0.006), Vector3(0, 0.3, 0), wire, false)
			for i in 5:
				BuildKit.cylinder(self, 0.035, 0.1, Vector3(-1.0 + i * 0.5, 0.22, 0), can, false, Vector3(rng.randf_range(-15, 15), 0, 0), -1.0, 8)
		"motion_light":
			var pole := BuildKit.tex_mat("metal", 0.4, Color(0.9, 0.9, 0.9), 0.5)
			BuildKit.cylinder(self, 0.04, 2.1, Vector3(0, 1.05, 0), pole, false, Vector3.ZERO, -1.0, 6)
			BuildKit.box(self, Vector3(0.3, 0.2, 0.15), Vector3(0, 0.25, 0), pole, false)
			var head := BuildKit.box(self, Vector3(0.3, 0.18, 0.18), Vector3(0, 2.1, 0.08), pole, false, Vector3(-30, 0, 0))
			_light_mat = BuildKit.emissive_mat(Color(1.0, 0.95, 0.85), 0.0)
			BuildKit.box(head, Vector3(0.24, 0.12, 0.01), Vector3(0, 0, 0.095), _light_mat, false)
			BuildKit.sphere(self, 0.04, Vector3(0, 1.95, 0.12), BuildKit.color_mat(Color(0.2, 0.2, 0.2), 0.2), Vector3.ONE, 6)
			if not preview:
				_light = SpotLight3D.new()
				_light.position = Vector3(0, 2.05, 0.2)
				_light.rotation_degrees.x = -40.0
				_light.spot_range = 16.0
				_light.spot_angle = 50.0
				_light.light_energy = 6.0
				_light.light_color = Color(1.0, 0.95, 0.85)
				_light.shadow_enabled = true
				_light.visible = false
				add_child(_light)


		"resonance_sensor":
			var hull := CrashSite.hull_material()
			var wood := BuildKit.tex_mat("logs", 0.4)
			BuildKit.cylinder(self, 0.05, 0.9, Vector3(0, 0.45, 0), wood, false, Vector3.ZERO, 0.04, 6)
			BuildKit.box(self, Vector3(0.22, 0.16, 0.16), Vector3(0, 0.95, 0), BuildKit.tex_mat("metal", 0.3, Color(1.1, 1.1, 1.1), 0.5), false)
			# Energiezelle oben in einer Fassung, Antennenstäbe aus fremdem Metall
			_light_mat = BuildKit.emissive_mat(Color(0.4, 0.95, 1.0), 0.6)
			BuildKit.cylinder(self, 0.04, 0.16, Vector3(0, 1.12, 0), _light_mat, false, Vector3.ZERO, -1.0, 8)
			for k in 3:
				var a := TAU * k / 3.0
				BuildKit.box(self, Vector3(0.012, 0.35, 0.012), Vector3(cos(a) * 0.07, 1.25, sin(a) * 0.07), hull, false, Vector3(sin(a) * 15.0, 0, -cos(a) * 15.0))
		"strobe_light":
			var pole := BuildKit.tex_mat("metal", 0.4, Color(0.9, 0.9, 0.9), 0.5)
			BuildKit.cylinder(self, 0.04, 2.1, Vector3(0, 1.05, 0), pole, false, Vector3.ZERO, -1.0, 6)
			BuildKit.box(self, Vector3(0.3, 0.2, 0.15), Vector3(0, 0.25, 0), pole, false)
			# Glaskolben mit Leuchtpilz-Röhre, ringsum strahlend
			BuildKit.cylinder(self, 0.13, 0.05, Vector3(0, 2.08, 0), pole, false, Vector3.ZERO, -1.0, 10)
			_light_mat = BuildKit.emissive_mat(Color(0.75, 1.0, 1.0), 0.3)
			BuildKit.cylinder(self, 0.1, 0.22, Vector3(0, 2.22, 0), _light_mat, false, Vector3.ZERO, -1.0, 10)
			BuildKit.cylinder(self, 0.12, 0.03, Vector3(0, 2.34, 0), pole, false, Vector3.ZERO, -1.0, 10)
			if not preview:
				_strobe = OmniLight3D.new()
				_strobe.position = Vector3(0, 2.2, 0)
				_strobe.omni_range = 13.0
				_strobe.light_energy = 0.0
				_strobe.light_color = Color(0.85, 1.0, 1.0)
				add_child(_strobe)

		"signal_jammer":
			var metal := BuildKit.tex_mat("metal", 0.3, Color(1.1, 1.1, 1.1), 0.5)
			var hull := CrashSite.hull_material()
			BuildKit.box(self, Vector3(0.4, 0.06, 0.4), Vector3(0, 0.03, 0), metal, false)
			BuildKit.cylinder(self, 0.035, 1.3, Vector3(0, 0.68, 0), metal, false, Vector3.ZERO, -1.0, 6)
			BuildKit.box(self, Vector3(0.24, 0.18, 0.14), Vector3(0, 0.5, 0.05), BuildKit.color_mat(Color(0.15, 0.16, 0.15), 0.5), false)
			# Drohnenteil oben als Empfänger, dazu Antennenkreuz
			BuildKit.lathe(self, PackedVector2Array([Vector2(0.0, -0.04), Vector2(0.18, 0.0), Vector2(0.0, 0.05)]), Vector3(0, 1.38, 0), hull, 12)
			for k in 4:
				BuildKit.box(self, Vector3(0.5, 0.01, 0.01), Vector3(0, 1.5 + k * 0.03, 0), metal, false, Vector3(0, k * 45.0, 0))
			_light_mat = BuildKit.emissive_mat(Color(1.0, 0.3, 0.2), 1.0)
			BuildKit.sphere(self, 0.025, Vector3(0, 1.6, 0), _light_mat, Vector3.ONE, 6)
		"drone_decoy":
			# Forschung: Mast mit Drohnenlinse und warmem Kern – die Drohne vermisst lieber ihn als dich
			var metal := BuildKit.tex_mat("metal", 0.3, Color(1.0, 1.0, 1.0), 0.5)
			BuildKit.box(self, Vector3(0.45, 0.05, 0.45), Vector3(0, 0.025, 0), metal, false)
			BuildKit.cylinder(self, 0.03, 1.2, Vector3(0, 0.6, 0), metal, false, Vector3.ZERO, -1.0, 6)
			BuildKit.lathe(self, PackedVector2Array([Vector2(0.0, -0.04), Vector2(0.16, 0.0), Vector2(0.0, 0.05)]), Vector3(0, 1.25, 0), CrashSite.hull_material(), 12)
			_light_mat = BuildKit.emissive_mat(Color(1.0, 0.55, 0.3), 1.6)
			BuildKit.sphere(self, 0.07, Vector3(0, 1.32, 0), _light_mat, Vector3.ONE, 8)
		"light_lure":
			# Forschung: Dose mit Leuchtpilz und Lichtersplitter, glimmt warm
			var tin2 := BuildKit.tex_mat("metal", 0.25, Color(1.2, 1.2, 1.15), 0.4)
			BuildKit.cylinder(self, 0.09, 0.22, Vector3(0, 0.11, 0), tin2, false, Vector3.ZERO, -1.0, 10)
			_light_mat = BuildKit.emissive_mat(Color(0.85, 1.0, 0.75), 2.2)
			BuildKit.sphere(self, 0.1, Vector3(0, 0.3, 0), _light_mat, Vector3(1.0, 1.2, 1.0), 8)
			if not preview:
				var gl := OmniLight3D.new()
				gl.position = Vector3(0, 0.4, 0)
				gl.omni_range = 4.0
				gl.light_energy = 0.8
				gl.light_color = Color(0.8, 1.0, 0.75)
				add_child(gl)
		"growth_barrier":
			var tin := BuildKit.tex_mat("metal", 0.25, Color(1.3, 1.3, 1.25), 0.4)
			# Dosenkranz um einen Kern aus fremden Pflanzen, der schwach violett glimmt
			for k in 6:
				var a := TAU * k / 6.0
				BuildKit.cylinder(self, 0.06, 0.16, Vector3(cos(a) * 0.22, 0.08, sin(a) * 0.22), tin, false, Vector3.ZERO, -1.0, 8)
			BuildKit.box(self, Vector3(0.5, 0.04, 0.5), Vector3(0, 0.02, 0), BuildKit.tex_mat("logs", 0.6), false)
			_light_mat = BuildKit.emissive_mat(Color(0.8, 0.5, 1.0), 1.0)
			BuildKit.cylinder(self, 0.05, 0.45, Vector3(0, 0.3, 0), BuildKit.color_mat(Color(0.5, 0.45, 0.55), 0.6), false, Vector3.ZERO, 0.02, 6)
			BuildKit.sphere(self, 0.07, Vector3(0, 0.55, 0), _light_mat, Vector3.ONE, 8)


## Bärenfalle: rostiger Stahlring aus zwei Bügeln mit Zähnen, Trittplatte in der Mitte,
## Blattfedern links und rechts, Kette mit Erdanker.
func _build_bear_trap() -> void:
	var steel := BuildKit.tex_mat("metal", 0.25, Color(0.78, 0.66, 0.55), 0.6)
	var dark := BuildKit.tex_mat("metal", 0.25, Color(0.45, 0.42, 0.4), 0.5)
	var r := 0.2
	# Grundplatte, Trittplatte
	BuildKit.box(self, Vector3(0.5, 0.015, 0.05), Vector3(0, 0.008, 0), dark, false)
	BuildKit.cylinder(self, 0.075, 0.012, Vector3(0, 0.03, 0), steel, false, Vector3.ZERO, -1.0, 12)
	BuildKit.box(self, Vector3(0.03, 0.02, 0.03), Vector3(0, 0.018, 0), dark, false)
	# Blattfedern: lang gezogene Bügel nach außen
	for sx: float in [-1.0, 1.0]:
		BuildKit.box(self, Vector3(0.3, 0.012, 0.035), Vector3(sx * 0.36, 0.018, 0), steel, false, Vector3(0, 0, sx * 4.0))
		BuildKit.cylinder(self, 0.022, 0.05, Vector3(sx * 0.5, 0.025, 0), dark, false, Vector3(90, 0, 0), -1.0, 8)
	# zwei Bügel, Gelenk entlang der x-Achse; offen liegen sie flach, zu stehen sie senkrecht
	for sz: float in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.position = Vector3(0, 0.02, 0)
		add_child(pivot)
		_jaws.append(pivot)
		var steps := 7
		for k in steps:
			# Halbkreis-Bügel aus kurzen Stücken
			var a0 := PI * k / steps
			var a1 := PI * (k + 1) / steps
			var p0 := Vector3(cos(a0) * r, 0, sz * sin(a0) * r)
			var p1 := Vector3(cos(a1) * r, 0, sz * sin(a1) * r)
			var mid := (p0 + p1) * 0.5
			var seg := BuildKit.box(pivot, Vector3(p0.distance_to(p1) + 0.01, 0.014, 0.014), mid, steel, false)
			seg.rotation.y = -atan2(p1.z - p0.z, p1.x - p0.x)
			# Zähne zeigen nach oben (geschlossen: zur Mitte)
			var tooth := BuildKit.box(pivot, Vector3(0.012, 0.04, 0.008), mid + Vector3(0, 0.022, 0), dark, false)
			tooth.rotation.y = seg.rotation.y
	# Kette mit Erdanker
	for i in 5:
		BuildKit.box(self, Vector3(0.035, 0.01, 0.018), Vector3(-0.56 - i * 0.04, 0.008, 0.05 + i * 0.02), dark, false, Vector3(0, i * 30.0 + 20.0, 90 if i % 2 == 0 else 0))
	BuildKit.cylinder(self, 0.012, 0.18, Vector3(-0.78, 0.05, 0.15), dark, false, Vector3(0, 0, 12), 0.005, 6)


## Kleintierschlinge: Holzpflock, gespannter Draht mit Schlaufe. Hat sie über Nacht etwas gefangen,
## liegt ein Hase daneben.
var _catch: Node3D


## Zelt: grüne Plane als Dach mit zwei Stangen, Eingang vorne (+z), Isomatte und Schlafsack drinnen.
func _build_tent() -> void:
	var canvas := BuildKit.tex_mat("fabric", 0.6, Color(0.55, 0.75, 0.5))
	canvas.cull_mode = BaseMaterial3D.CULL_DISABLED
	var pole := BuildKit.color_mat(Color(0.25, 0.25, 0.27), 0.5, 0.4)
	var w := size.x * 0.5
	var h := size.y
	var l := size.z
	var slope := sqrt(w * w + h * h)
	var ang := rad_to_deg(atan2(h, w))
	for sx: float in [-1.0, 1.0]:
		var side := BuildKit.box(self, Vector3(slope, 0.02, l), Vector3(sx * w * 0.5, h * 0.5, 0), canvas, false, Vector3(0, 0, sx * ang))
		side.name = "CanvasR" if sx > 0.0 else "CanvasL"
	# Rückwand (Dreieck angedeutet durch zwei schräge Stücke)
	for sx: float in [-1.0, 1.0]:
		BuildKit.box(self, Vector3(w, h * 0.72, 0.02), Vector3(sx * w * 0.4, h * 0.36, -l * 0.5), canvas, false, Vector3(0, 0, sx * 12.0))
	for z: float in [-l * 0.5, l * 0.5]:
		BuildKit.cylinder(self, 0.015, h, Vector3(0, h * 0.5, z), pole, false, Vector3.ZERO, -1.0, 6)
	BuildKit.box(self, Vector3(0.6, 0.03, l * 0.85), Vector3(-0.25, 0.015, 0), BuildKit.color_mat(Color(0.2, 0.3, 0.5), 0.8), false)
	BuildKit.box(self, Vector3(0.5, 0.1, l * 0.7), Vector3(-0.25, 0.06, -0.1), BuildKit.tex_mat("blanket", 0.5), false)
	# Heringe und Leinen
	var rope := BuildKit.color_mat(Color(0.75, 0.7, 0.55), 0.9)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			BuildKit.box(self, Vector3(0.01, 0.01, 0.6), Vector3(sx * (w + 0.25), 0.25, sz * l * 0.5), rope, false, Vector3(0, 0, sx * 45.0))


func _build_snare() -> void:
	var wood := BuildKit.tex_mat("logs", 0.5, Color(1.0, 0.9, 0.8))
	var wire := BuildKit.color_mat(Color(0.55, 0.55, 0.52), 0.4, 0.7)
	BuildKit.cylinder(self, 0.025, 0.4, Vector3(-0.18, 0.12, 0), wood, false, Vector3(0, 0, 8), 0.012, 6)
	BuildKit.box(self, Vector3(0.3, 0.004, 0.004), Vector3(-0.04, 0.2, 0), wire, false, Vector3(0, 0, -20))
	for k in 10:
		var a := TAU * k / 10.0
		BuildKit.box(self, Vector3(0.035, 0.004, 0.004), Vector3(0.12 + cos(a) * 0.07, 0.12 + sin(a) * 0.07, 0), wire, false, Vector3(0, 0, rad_to_deg(a) + 90))
	# Zweige als Tarnung
	for k in 3:
		BuildKit.box(self, Vector3(0.012, 0.25, 0.012), Vector3(0.05 + k * 0.06, 0.1, 0.08 - k * 0.06), wood, false, Vector3(30 - k * 25, 0, 20))
	_catch = Node3D.new()
	add_child(_catch)
	var fur := BuildKit.color_mat(Color(0.42, 0.33, 0.24), 1.0)
	BuildKit.sphere(_catch, 0.15, Vector3(0.15, 0.08, 0.05), fur, Vector3(1.4, 0.6, 0.8), 8)
	BuildKit.sphere(_catch, 0.07, Vector3(-0.02, 0.07, 0.05), fur, Vector3(1.2, 0.9, 0.9), 8)
	BuildKit.box(_catch, Vector3(0.16, 0.025, 0.04), Vector3(-0.12, 0.06, 0.07), fur, false, Vector3(0, 20, 0))
	_catch.visible = false


func refresh_catch() -> void:
	if type == "snare" and _catch and not preview:
		_catch.visible = bool(Builder.record(uid).get("caught", false))


## Bügel offen (flach) oder zu (senkrecht, Zähne greifen ineinander).
func _set_jaws(open: bool, animate: bool) -> void:
	for i in _jaws.size():
		var sz := -1.0 if i == 0 else 1.0
		var target := Vector3.ZERO if open else Vector3(sz * deg_to_rad(84.0), 0, 0)
		if animate:
			create_tween().tween_property(_jaws[i], "rotation", target, 0.07 if not open else 0.4)
		else:
			_jaws[i].rotation = target


func _snap(victim: Node3D) -> void:
	armed = false
	_set_jaws(false, true)
	var r := Builder.record(uid)
	if not r.is_empty():
		r["armed"] = false
	SoundBank.play_at(get_parent(), "trap_snap", global_position + Vector3(0, 0.2, 0), 4.0, 1.7)
	SoundBank.play_at(get_parent(), "clatter", global_position + Vector3(0, 0.1, 0), -2.0, 0.7)
	Fx.burst(get_parent(), global_position + Vector3(0, 0.12, 0), "dirt", Vector3.UP, 0.8)
	EventBus.noise_made.emit(global_position, 20.0)
	var def := DataDB.buildable(type)
	if victim is Player:
		var pl := victim as Player
		pl.take_damage(float(def.get("player_damage", 25)), pl.global_position + Vector3(0, 0.05, 0))
		pl.held_time = 1.6
		EventBus.notify("Autsch – du bist in die Bärenfalle getreten!", 3.0)
	else:
		victim.call("on_trap", global_position)
		# Die Kreatur reißt sich los und beschädigt die Falle dabei
		receive_hit(float(def.get("creature_damage", 30)) * 0.5)


func _rearm() -> void:
	armed = true
	var pl := get_tree().get_first_node_in_group("player") as Player
	_player_on_trap = pl != null and _flat_dist(pl.global_position) < 0.6
	_set_jaws(true, true)
	var r := Builder.record(uid)
	if not r.is_empty():
		r["armed"] = true
	SoundBank.play_at(get_parent(), "hammer", global_position + Vector3(0, 0.2, 0), -6.0, 1.4)


## Spießbarrikade: Die Kreatur hat sich verletzt – grünes Blut an den Spießen,
## ein abgebrochener Spieß mit Blut liegt daneben (Blutprobe für die Forschung).
func bloody() -> void:
	if _bloodied or _spike_mat == null:
		return
	_bloodied = true
	_spike_mat.albedo_color = Color(0.55, 0.95, 0.45)
	_spike_mat.emission_enabled = true
	_spike_mat.emission = Color(0.25, 0.8, 0.2)
	_spike_mat.emission_energy_multiplier = 0.4
	var p := ItemPickup.new()
	p.name = "BloodSpike_%d_%d" % [uid, TimeManager.day]
	p.item_id = "alien_blood"
	p.amount = 1
	p.collider_size = Vector3(0.5, 0.2, 0.3)
	p.collider_offset = Vector3(0, 0.08, 0)
	var at := global_position + global_transform.basis.z * 0.9 + global_transform.basis.x * randf_range(-0.5, 0.5)
	p.position = Creature._ground(at)
	get_parent().add_child(p)
	var v := Node3D.new()
	p.add_child(v)
	var wood := BuildKit.tex_mat("logs", 0.5, Color(1.1, 1.0, 0.9))
	var blood := BuildKit.emissive_mat(Color(0.35, 0.9, 0.25), 0.5)
	BuildKit.cylinder(v, 0.04, 0.45, Vector3(0, 0.04, 0), wood, false, Vector3(0, randf_range(0, 180), 88), 0.0, 6)
	BuildKit.sphere(v, 0.035, Vector3(0.2, 0.045, 0), blood, Vector3(1.6, 0.6, 1.0), 6)
	BuildKit.sphere(v, 0.05, Vector3(0.12, 0.005, 0.03), blood, Vector3(1.4, 0.15, 1.0), 6)


## Leuchtet das Bauteil gerade (für Drohnen, die von grellem Licht geblendet werden)?
func is_lit() -> bool:
	if _strobe:
		return _strobe.light_energy > 0.0 or _strobe_time > 0.0
	if _light:
		return _light.visible
	return false


## Myzel-Sperre: Wucherungen im Umkreis sterben ab.
func _wither_patches() -> void:
	for p in get_tree().get_nodes_in_group("organism_patch"):
		var n := p as Node3D
		if Vector2(n.global_position.x - global_position.x, n.global_position.z - global_position.z).length() < 6.0:
			WorldState.remove_patch(int(n.get("patch_id")))


## Bauvorschau einfärben (grün = passt, rot = geht hier nicht).
func set_preview_valid(valid: bool) -> void:
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.3, 1.0, 0.4, 0.45) if valid else Color(1.0, 0.25, 0.2, 0.45)
	for gi in find_children("*", "GeometryInstance3D", true, false):
		var g := gi as GeometryInstance3D
		g.material_override = m
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


# --- Interaktion --------------------------------------------------------

func get_prompt(_player: Node) -> String:
	var def := DataDB.buildable(type)
	if type == "tent" and camp:
		return camp.get_prompt()
	if type == "campfire" and fire:
		return fire.get_prompt()
	if type == "snare":
		if bool(Builder.record(uid).get("caught", false)):
			return "Schlinge: ein Hase hat sich verfangen  [E] mitnehmen"
		return "Kleintierschlinge – nichts gefangen  [E] nachsehen"
	if type == "bear_trap":
		return "Bärenfalle – gespannt  (%d%%)" % int(health / max_health * 100.0) if armed \
				else "[E] Bärenfalle spannen  (%d%%)" % int(health / max_health * 100.0)
	return "%s  (%d%%)" % [def.get("name", type), int(health / max_health * 100.0)]


func interact(_player: Node) -> void:
	if type == "tent" and camp:
		camp.interact(_player as Player)
		return
	if type == "campfire" and fire:
		fire.interact()
		return
	if type == "bear_trap" and not armed:
		_rearm()
	if type == "snare":
		Tasks.flag("snare_checked")
		var r := Builder.record(uid)
		if bool(r.get("caught", false)):
			var c := Supplies.config.snare_meat
			var got := Inventory.add("meat_raw", randi_range(c.x, c.y))
			r["caught"] = false
			refresh_catch()
			Tasks.flag("snare_caught")
			EventBus.notify("Rohes Hasenfleisch +%d – braten oder kochen!" % got, 3.0)
			SoundBank.play_ui(self, "pickup", -6.0)
		else:
			EventBus.notify("Nichts gefangen. Die Schlinge bleibt gespannt.", 2.0)


func get_secondary_prompt(_player: Node) -> String:
	if type == "campfire" and fire:
		return fire.get_secondary_prompt()
	if type == "tent" and camp and camp.torn:
		return "[R] Zerrissenes Zelt abbauen (nur Reste)"
	return "[R] Abbauen"


func secondary_interact(_player: Node) -> void:
	if type == "campfire" and fire:
		fire.secondary_interact()
		return
	if type == "tent" and camp and camp.torn:
		Inventory.add("planks", 1)
		EventBus.notify("Vom Zelt ist nicht viel übrig.", 2.0)
		_destroy(false)
		return
	# Unbeschädigt gibt es das Bauteil zurück, beschädigt nur einen Teil des Holzes
	if health >= max_health * 0.6:
		if Inventory.add(type, 1) <= 0:
			EventBus.notify("Zu schwer – du kannst nicht mehr tragen.", 2.0)
			return
		EventBus.notify("%s abgebaut." % DataDB.buildable(type).get("name", type), 2.0)
	else:
		EventBus.notify("Zu beschädigt – nur Reste übrig.", 2.0)
	SoundBank.play_at(get_parent(), "wood_crack", global_position + Vector3(0, 0.5, 0), -4.0)
	_destroy(false)


# --- Kreaturen ----------------------------------------------------------

## Liegt ein Punkt (Welt) im Bereich dieses Hindernisses?
func blocks_point(p: Vector3, margin: float = 0.45) -> bool:
	var l := to_local(p)
	return absf(l.x) < size.x * 0.5 + margin and absf(l.z) < size.z * 0.5 + margin


func receive_hit(damage: float) -> void:
	health -= damage
	SoundBank.play_at(get_parent(), "wood_crack" if type != "stone_wall" else "bang", global_position + Vector3(0, 0.6, 0), 0.0, randf_range(0.8, 1.1))
	EventBus.noise_made.emit(global_position, 18.0)
	Builder.update_health(uid, health)
	if health <= 0.0:
		_destroy(true)


func hurts() -> bool:
	return bool(DataDB.buildable(type).get("hurts", false))


func _destroy(loud: bool) -> void:
	if loud:
		SoundBank.play_at(get_parent(), "bang" if type == "stone_wall" else "fence_break", global_position + Vector3(0, 0.5, 0), 2.0)
		var kind := "stone" if type == "stone_wall" else ("metal" if type in ["bear_trap", "can_alarm"] else "wood")
		Fx.burst(get_parent(), global_position + Vector3(0, 0.5, 0), kind, Vector3.UP, 1.6)
	Builder.remove(uid)
	queue_free()


func _physics_process(delta: float) -> void:
	if preview:
		return
	_t += delta
	_alarm_cooldown -= delta
	if _light_mat and type == "signal_jammer":
		_light_mat.emission_energy_multiplier = 3.0 if fmod(_t, 0.8) < 0.1 else 0.3
	elif _light_mat and type == "growth_barrier":
		_light_mat.emission_energy_multiplier = 0.8 + sin(_t * 1.5) * 0.4
	if type == "bear_trap":
		_check_trap()
		return
	var c: Node3D = ThreatDirector.creature if is_instance_valid(ThreatDirector.creature) else null
	if not is_instance_valid(c):
		if _strobe:
			_update_strobe(delta)
		if _light and _light.visible:
			_light_time -= delta
			if _light_time <= 0.0:
				_set_light(false)
		return
	var d := global_position.distance_to(c.global_position)
	match type:
		"can_alarm":
			if _alarm_cooldown <= 0.0 and blocks_point(c.global_position, 0.8):
				_alarm_cooldown = 40.0
				for i in 3:
					SoundBank.play_at(get_parent(), "clatter", global_position + Vector3(randf_range(-1, 1), 0.3, 0), 6.0, randf_range(0.8, 1.2))
				EventBus.notify("Dosen klappern – %s!" % _direction_from_player(), 3.0)
		"resonance_sensor":
			# Zelle pulsiert schneller, je näher sie ist; meldet sie alle 30 s mit Richtung
			var near := clampf(1.0 - d / float(DataDB.buildable(type).get("range", 26)), 0.0, 1.0)
			_light_mat.emission_energy_multiplier = 0.6 + near * (2.5 + sin(_t * (3.0 + near * 18.0)) * 2.0)
			_sense_cooldown -= delta
			if near > 0.0 and _sense_cooldown <= 0.0:
				_sense_cooldown = 30.0
				SoundBank.play_ui(self, "signal", -6.0, 1.8)
				EventBus.notify("Resonanz-Sensor schlägt aus – etwas %s des Sensors (%d m)." % [_direction_word(c.global_position), int(d)], 4.0)
		"strobe_light":
			if d < float(DataDB.buildable(type).get("range", 11)):
				_strobe_time = 10.0
				if _t - _scared_at > 45.0:
					_scared_at = _t
					c.call("on_strobe", global_position)
		"motion_light":
			if d < 9.0:
				_light_time = 15.0
				if not _light.visible:
					_set_light(true)
				# Grelles Licht: die Kreatur weicht zurück (höchstens einmal pro Minute)
				if d < 7.0 and _t - _scared_at > 60.0:
					_scared_at = _t
					c.call("on_bright_light", global_position)
	if _strobe:
		_update_strobe(delta)
	if _light and _light.visible:
		_light_time -= delta
		if _light_time <= 0.0:
			_set_light(false)


## Bärenfalle: tritt jemand auf die Trittplatte?
func _check_trap() -> void:
	if not armed:
		return
	var pl := get_tree().get_first_node_in_group("player") as Player
	if pl and not pl.is_hidden() and _flat_dist(pl.global_position) < 0.32 and absf(pl.global_position.y - global_position.y) < 0.6:
		if not _player_on_trap:
			_snap(pl)
			return
	elif pl and _flat_dist(pl.global_position) > 0.6:
		_player_on_trap = false
	var c: Node3D = ThreatDirector.creature if is_instance_valid(ThreatDirector.creature) else null
	if c and _flat_dist(c.global_position) < 0.75 and absf(c.global_position.y - global_position.y) < 1.0:
		_snap(c)


func _flat_dist(p: Vector3) -> float:
	return Vector2(p.x - global_position.x, p.z - global_position.z).length()


func _set_light(on: bool) -> void:
	_light.visible = on
	_light_mat.emission_energy_multiplier = 5.0 if on else 0.0
	if on:
		SoundBank.play_at(get_parent(), "motion_click", global_position + Vector3(0, 2, 0), -2.0)


func _update_strobe(delta: float) -> void:
	_strobe_time = maxf(_strobe_time - delta, 0.0)
	var on := _strobe_time > 0.0 and fmod(_t, 0.12) < 0.05
	_strobe.light_energy = 9.0 if on else 0.0
	_light_mat.emission_energy_multiplier = 8.0 if on else 0.3


## Himmelsrichtung eines Punktes vom Bauteil aus.
func _direction_word(p: Vector3) -> String:
	var v := p - global_position
	var dirs := ["nördlich", "nordöstlich", "östlich", "südöstlich", "südlich", "südwestlich", "westlich", "nordwestlich"]
	var a := fposmod(atan2(v.x, -v.z), TAU)
	return dirs[int(round(a / (TAU / 8.0))) % 8]


func _direction_from_player() -> String:
	var p := get_tree().get_first_node_in_group("player") as Node3D
	if p == null:
		return "draußen"
	var v := global_position - p.global_position
	var dirs := ["im Norden", "im Nordosten", "im Osten", "im Südosten", "im Süden", "im Südwesten", "im Westen", "im Nordwesten"]
	var a := fposmod(atan2(v.x, -v.z), TAU)
	return dirs[int(round(a / (TAU / 8.0))) % 8]
