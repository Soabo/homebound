class_name RootChamber
extends Node3D
## Die Kammer des Wurzelknotens unter dem alten Brunnen (Story-Bibel Phase 5). Liegt tief unter dem Brunnen,
## ganz geschlossen (Fels ringsum), damit Gelände und Himmel keine Rolle spielen. Wurzeln wachsen aus den Wänden
## zur Mitte, dort pulsiert der Knoten. Davor die Fassung (NodeSocket): mit W-17 wählt man das Ende.
## Seil (RopeUp) führt zurück nach oben.

const CENTER := Vector3(13.5, -36.0, -13.0)   ## unter dem Brunnen (map.json brunnen)
const RADIUS := 8.0
const HEIGHT := 7.0

var _node_light: OmniLight3D
var _pulses: Array[MeshInstance3D] = []
var _t: float = 0.0
var _breath: AudioStreamPlayer3D
var _core_mat: StandardMaterial3D


static func is_inside(p: Vector3) -> bool:
	return p.y < CENTER.y + HEIGHT + 1.0 and p.y > CENTER.y - 2.0 and Vector2(p.x - CENTER.x, p.z - CENTER.z).length() < RADIUS + 1.5


func _ready() -> void:
	name = "RootChamber"
	add_to_group("root_chamber")
	position = CENTER
	_build()


func arrival_point() -> Vector3:
	return CENTER + Vector3(-RADIUS + 2.2, 0.05, 0.0)


func arrival_look() -> Vector3:
	return CENTER + Vector3(0, 1.4, 0)


func surface_point() -> Vector3:
	# neben dem Brunnen, auf der Hüttenseite
	var p := Vector3(CENTER.x - 1.8, 0.0, CENTER.z + 1.4)
	p.y = Terrain.height_at(p.x, p.z) + 0.05
	return p


func _build() -> void:
	var rock := PlaceKit.mat("rock")
	var dark := PlaceKit.mat("stone_dark")
	var alien := PlaceKit.mat("alien")
	var glow := PlaceKit.mat("glow")
	# Wurzeln: fast schwarz mit violettem Schimmer, feucht glänzend
	var root_mat := StandardMaterial3D.new()
	root_mat.albedo_color = Color(0.07, 0.05, 0.09)
	root_mat.roughness = 0.35
	root_mat.metallic = 0.2
	root_mat.emission_enabled = true
	root_mat.emission = Color(0.25, 0.08, 0.4)
	root_mat.emission_energy_multiplier = 0.25
	var rng := RandomNumberGenerator.new()
	rng.seed = 417
	# Boden, Decke
	BuildKit.box(self, Vector3(RADIUS * 2.4, 1.0, RADIUS * 2.4), Vector3(0, -0.5, 0), dark, true)
	BuildKit.box(self, Vector3(RADIUS * 2.4, 1.2, RADIUS * 2.4), Vector3(0, HEIGHT + 0.6, 0), rock, true)
	# Wände: Ring aus schräg gestellten Felsplatten
	var n := 18
	for i in n:
		var a := TAU * i / float(n)
		var r := RADIUS + rng.randf_range(-0.4, 0.6)
		var p := Vector3(cos(a) * r, HEIGHT * 0.5, sin(a) * r)
		BuildKit.box(self, Vector3(3.4, HEIGHT + 1.0, 1.4), p, rock, true, Vector3(rng.randf_range(-8, 8), -rad_to_deg(a) + 90.0, rng.randf_range(-6, 6)))
	# Schachtöffnung oben (dunkles Loch) mit Licht von oben, Seil
	BuildKit.cylinder(self, 0.8, 0.05, Vector3(-RADIUS + 1.6, HEIGHT - 0.02, 0), PlaceKit.mat("dark"), false, Vector3.ZERO, -1.0, 12)
	BuildKit.cylinder(self, 0.025, HEIGHT, Vector3(-RADIUS + 1.6, HEIGHT * 0.5, 0), PlaceKit.mat("fabric"), false, Vector3.ZERO, -1.0, 6)
	var rope := RopeUp.new()
	rope.name = "RopeUp"
	rope.position = Vector3(-RADIUS + 1.6, 0, 0)
	add_child(rope)
	# Wurzeln: aus Wänden und Decke zur Mitte, manche mit glimmenden Knoten
	for i in 46:
		var a := rng.randf_range(0, TAU)
		var from := Vector3(cos(a) * (RADIUS - 0.6), rng.randf_range(0.2, HEIGHT - 0.2), sin(a) * (RADIUS - 0.6))
		var to := Vector3(cos(a) * rng.randf_range(1.2, 3.0), rng.randf_range(0.4, 3.2), sin(a) * rng.randf_range(1.2, 3.0))
		if a > PI * 0.8 and a < PI * 1.2 and from.y < 2.5:
			continue   # Platz am Seil frei halten
		var sag := Vector3(rng.randf_range(-0.8, 0.8), -rng.randf_range(0.3, 1.6), rng.randf_range(-0.8, 0.8))
		_root_curve(from, to, sag, rng.randf_range(0.1, 0.3), root_mat, rng)
		if rng.randf() < 0.35:
			var g := BuildKit.sphere(self, rng.randf_range(0.05, 0.12), _bezier(from, (from + to) * 0.5 + sag, to, rng.randf_range(0.3, 0.8)), glow, Vector3.ONE, 6)
			_pulses.append(g)
	# Der Knoten in der Mitte (fest, nicht begehbar)
	# dunkle, nasse Hülle; das Leuchten kommt von innen durch die Adern
	var skin := StandardMaterial3D.new()
	skin.albedo_color = Color(0.08, 0.05, 0.1)
	skin.roughness = 0.25
	skin.metallic = 0.3
	skin.emission_enabled = true
	skin.emission = Color(0.4, 0.15, 0.7)
	skin.emission_energy_multiplier = 0.35
	_core_mat = skin
	var core := BuildKit.sphere(self, 1.5, Vector3(0, 2.0, 0), skin, Vector3(1.0, 1.25, 1.0), 16)
	core.name = "NodeCore"
	# Adern über die Hülle
	for i in 16:
		var a := rng.randf_range(0, TAU)
		var b := rng.randf_range(-1.2, 1.2)
		var p0 := Vector3(cos(a) * cos(b), sin(b) * 1.25, sin(a) * cos(b)) * 1.5 + Vector3(0, 2.0, 0)
		var a2 := a + rng.randf_range(-0.7, 0.7)
		var b2 := clampf(b + rng.randf_range(-0.8, 0.8), -1.3, 1.3)
		var p1 := Vector3(cos(a2) * cos(b2), sin(b2) * 1.25, sin(a2) * cos(b2)) * 1.52 + Vector3(0, 2.0, 0)
		_root_curve(p0, p1, (p0 + p1 - Vector3(0, 4.0, 0)).normalized() * 0.15, 0.035, glow, rng, 4)
	BuildKit.collider_box(self, Vector3(2.6, 3.8, 2.6), Vector3(0, 1.9, 0))
	# Haltewurzeln vom Knoten in den Boden
	for i in 10:
		var a := TAU * i / 10.0 + rng.randf_range(-0.2, 0.2)
		_root_curve(Vector3(cos(a) * 1.1, 2.9, sin(a) * 1.1), Vector3(cos(a) * 2.4, -0.1, sin(a) * 2.4), Vector3(cos(a), 0.4, sin(a)) * 0.9, 0.22, root_mat, rng)
	for i in 14:
		var g := BuildKit.sphere(self, 0.1, Vector3(rng.randf_range(-1.1, 1.1), rng.randf_range(1.0, 3.2), rng.randf_range(-1.1, 1.1)).normalized() * 1.45 + Vector3(0, 2.0, 0), glow, Vector3.ONE, 6)
		_pulses.append(g)
	_node_light = OmniLight3D.new()
	_node_light.light_color = Color(0.62, 0.38, 1.0)
	_node_light.light_energy = 1.2
	_node_light.omni_range = 13.0
	_node_light.shadow_enabled = true
	_node_light.position = Vector3(0, 2.2, 0)
	add_child(_node_light)
	# Schwaches Licht am Seil, damit man nach der Ankunft etwas sieht
	var shaft_light := OmniLight3D.new()
	shaft_light.light_color = Color(0.5, 0.55, 0.65)
	shaft_light.light_energy = 0.35
	shaft_light.omni_range = 4.0
	shaft_light.position = Vector3(-RADIUS + 1.6, HEIGHT - 0.8, 0)
	add_child(shaft_light)
	# Die Fassung: Sockel mit Industriefassung (ReZort) vor dem Knoten, zur Seilseite hin
	var socket := NodeSocket.new()
	socket.name = "NodeSocket"
	socket.position = Vector3(-2.3, 0, 0)
	socket.rotation_degrees.y = 90.0   # Schild zur Seilseite (Ankunft)
	add_child(socket)
	# Atmen des Knotens
	_breath = AudioStreamPlayer3D.new()
	_breath.stream = SoundBank.get_sound("creature_breath")
	_breath.volume_db = -12.0
	_breath.unit_size = 4.0
	_breath.max_distance = 30.0
	_breath.position = Vector3(0, 2.0, 0)
	add_child(_breath)


static func _bezier(a: Vector3, c: Vector3, b: Vector3, t: float) -> Vector3:
	return a.lerp(c, t).lerp(c.lerp(b, t), t)


## Gekrümmte, sich verjüngende Wurzel aus mehreren Stücken (quadratische Kurve, leicht unruhig)
func _root_curve(a: Vector3, b: Vector3, bend: Vector3, r: float, mat: Material, rng: RandomNumberGenerator, parts: int = 6) -> void:
	var c := (a + b) * 0.5 + bend
	var prev := a
	for k in range(1, parts + 1):
		var t := float(k) / float(parts)
		var q := _bezier(a, c, b, t)
		if k < parts:
			q += Vector3(rng.randf_range(-0.06, 0.06), rng.randf_range(-0.06, 0.06), rng.randf_range(-0.06, 0.06))
		var r0 := lerpf(r, r * 0.25, float(k - 1) / float(parts))
		_root_segment(prev, q, r0, mat, lerpf(r, r * 0.25, t))
		prev = q


func _root_segment(a: Vector3, b: Vector3, r: float, mat: Material, r_end: float = -1.0) -> void:
	var mid := (a + b) * 0.5
	var len := a.distance_to(b)
	# unten (bei a) dick, oben (bei b) dünn; etwas länger, damit die Stücke ohne Lücke ineinander greifen
	var c := BuildKit.cylinder(self, r, len + r * 0.6, mid, mat, false, Vector3.ZERO, r_end if r_end >= 0.0 else r * 0.45, 7)
	var dir := (b - a).normalized()
	var up := Vector3.UP
	var axis := up.cross(dir)
	if axis.length() > 0.001:
		c.transform.basis = Basis(axis.normalized(), up.angle_to(dir))
	c.position = mid


func _process(delta: float) -> void:
	_t += delta
	var saat := Story.saat_progress()
	var pulse := 0.5 + 0.5 * sin(_t * (1.1 + saat * 1.6))
	_node_light.light_energy = 0.8 + pulse * (0.8 + saat)
	if _core_mat:
		_core_mat.emission_energy_multiplier = 0.25 + pulse * (0.4 + saat * 0.6)
	for g in _pulses:
		g.scale = Vector3.ONE * (0.8 + pulse * 0.45)
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var near := player != null and is_inside(player.global_position)
	# Nur zeichnen, wenn man unten ist (sonst kostet die Kammer unter dem Hof Bildrate)
	var show := player != null and player.global_position.y < CENTER.y + HEIGHT + 6.0
	if visible != show:
		visible = show
	if near and not _breath.playing and _breath.stream:
		_breath.play()
	elif not near and _breath.playing:
		_breath.stop()


## Seil zurück nach oben
class RopeUp extends Interactable:
	func _ready() -> void:
		var area := Area3D.new()
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(1.2, 2.4, 1.2)
		cs.shape = shape
		cs.position = Vector3(0, 1.2, 0)
		area.add_child(cs)
		add_child(area)

	func get_prompt(_player: Node) -> String:
		return "[E] Am Seil hinaufklettern"

	func interact(player: Node) -> void:
		var ch := get_parent() as RootChamber
		var p := player as Player
		if ch == null or p == null:
			return
		ScreenFade.teleport(p, ch.surface_point(), Vector3(0, 1.0, 0), "")


## Die Fassung vor dem Knoten: hier entscheidet sich das Ende (Story.socket_options).
class NodeSocket extends Interactable:
	func _ready() -> void:
		var metal := PlaceKit.mat("metal")
		BuildKit.box(self, Vector3(0.7, 1.0, 0.7), Vector3(0, 0.5, 0), PlaceKit.mat("concrete"), true)
		BuildKit.box(self, Vector3(0.36, 0.16, 0.36), Vector3(0, 1.08, 0), metal, false)
		BuildKit.box(self, Vector3(0.16, 0.06, 0.16), Vector3(0, 1.17, 0), PlaceKit.mat("dark"), false)
		BuildKit.box(self, Vector3(0.5, 0.12, 0.02), Vector3(0, 0.82, -0.36), PlaceKit.mat("yellow"), false)
		var lab := Label3D.new()
		lab.text = "ReZort Industries\nSteuerglied W-Serie"
		lab.font_size = 14
		lab.pixel_size = 0.0022
		lab.modulate = Color(0.1, 0.1, 0.1)
		lab.outline_size = 0
		lab.position = Vector3(0, 0.82, -0.372)
		lab.rotation_degrees.y = 180.0
		add_child(lab)
		var area := Area3D.new()
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(1.0, 1.4, 1.0)
		cs.shape = shape
		cs.position = Vector3(0, 0.7, 0)
		area.add_child(cs)
		add_child(area)

	func get_prompt(_player: Node) -> String:
		if Inventory.count("w17") <= 0:
			return "[E] Fassung ansehen   (W-17 fehlt)"
		return "[E] W-17 in die Fassung setzen"

	func interact(_player: Node) -> void:
		var opts: Array = Story.socket_options()
		if opts.is_empty():
			EventBus.notify("Eine Fassung, genau so groß wie W-17. Aber ich weiß nicht, was ich hier tun soll. Mir fehlt etwas – die Abschaltfolge, Stefanies Unterlagen, irgendetwas.", 8.0)
			return
		var text := "Der Knoten atmet. Die Fassung ist warm.\nWas ich jetzt tue, entscheidet alles."
		ChoiceDialog.open(get_tree(), "Die Fassung", text, opts, _picked.bind(opts))

	func _picked(id: String, opts: Array) -> void:
		if id == "":
			return
		var ending := ""
		for o: Dictionary in opts:
			if o["id"] == id:
				ending = String(o["ending"])
		if ending == "":
			return
		var confirm := String(Story.endings_data().get("confirm", "Das ist das Ende deiner Geschichte."))
		ChoiceDialog.open(get_tree(), "Bist du sicher?", confirm,
				[{"id": "yes", "label": "Ja – so endet es", "ok": true}], _confirmed.bind(ending))

	func _confirmed(id: String, ending: String) -> void:
		if id == "yes":
			Story.start_ending(ending)
