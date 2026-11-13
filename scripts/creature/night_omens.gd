class_name NightOmens
extends RefCounted
## Kleine nächtliche Vorkommnisse (Christian, 13.11.2026): Hände durch Spalten, Dinge im Haus verändern sich,
## draußen im Wald Lichter, fliehende Tiere, kurze Sichtungen von Sucher und Zerfleischer – und zehn weitere:
## Lampe pendelt von selbst, Klopfen wandert durch die Wände, Spieluhr spielt, Atem auf der Scheibe, Schatten huscht vorbei,
## Wasserhahn läuft, Augen unter dem Bett, Vogel prallt gegen das Fenster, Schranktür geht auf, neue Kinderzeichnung.
## Geplant vom ThreatDirector (Ereignis "omen", Werte in ThreatConfig omen_*), ausgeführt hier.

## Alle Arten. "house" = nur, wenn man zuhause ist; die anderen gehen überall um den Spieler.
const HOUSE_KINDS := ["gap_hand", "deco_move", "lamp_swing", "knock_walk", "music_box", "window_fog", "window_pass",
		"tap_run", "under_bed", "bird_thud", "wardrobe_open", "drawing"]
const FOREST_KINDS := ["lights", "animals", "seeker_glimpse", "mauler_glimpse"]

## Spalten im Haus, durch die Hände greifen: Ort + Richtung ins Zimmer
const GAPS := [
	[Vector3(-3.0, 0.47, 4.36), Vector3(0, 0, -1)],      # unter der Haustür
	[Vector3(-2.0, 0.44, 3.0), Vector3(0, 1, 0)],        # Bodenritze im Wohnzimmer
	[Vector3(-5.2, 0.44, -3.4), Vector3(0, 1, 0)],       # neben dem Bett
	[Vector3(-8.83, 0.6, 0.35), Vector3(1, 0, 0)],       # Kinderzimmer, Ecke
	[Vector3(-1.2, 0.44, -6.6), Vector3(0, 1, 0)],       # Büro, Dielen
	[Vector3(3.75, 3.24, 0.0), Vector3(0, -1, 0)],       # Rand der Dachbodenluke
	[Vector3(5.82, 1.5, 2.6), Vector3(-1, 0, 0)],        # Werkstattfenster, Rahmen
	[Vector3(1.88, 0.9, -3.4), Vector3(-1, 0, 0)],       # Speis, Wandfuge
	[Vector3(-5.88, 1.1, -0.9), Vector3(1, 0, 0)],       # Wohnzimmer, Fuge am Regal
]


static func fire(kind: String, scene: Node, player: Player, cfg: ThreatConfig, rng: RandomNumberGenerator) -> void:
	if scene == null or player == null:
		return
	match kind:
		"gap_hand": _gap_hand(scene, player, cfg, rng)
		"deco_move":
			scene.get_tree().call_group("inside_changes", "night_move", player)
		"drawing":
			scene.get_tree().call_group("inside_changes", "show_drawing")
		"lamp_swing": _lamp_swing(scene, player, rng)
		"knock_walk": _knock_walk(scene, player, rng)
		"music_box": _music_box(scene)
		"window_fog": _window_fog(scene, player, rng)
		"window_pass": _window_pass(scene, player, rng)
		"tap_run": _tap_run(scene)
		"under_bed": _under_bed(scene, player)
		"bird_thud": _bird_thud(scene, player, rng)
		"wardrobe_open": _wardrobe_open(scene, player)
		"lights": _lights(scene, player, rng)
		"animals": _animals(scene, player, rng)
		"seeker_glimpse": _glimpse(scene, player, rng, "seeker")
		"mauler_glimpse": _glimpse(scene, player, rng, "mauler")


# --- Hilfen ------------------------------------------------------------------

## Punkt draußen in Blickrichtung des Spielers (für Dinge, die man durchs Fenster sehen soll).
static func _view_spot(player: Player, rng: RandomNumberGenerator, dmin: float, dmax: float) -> Vector3:
	var fwd := -player.camera.global_transform.basis.z
	fwd.y = 0.0
	if fwd.length() < 0.1:
		fwd = Vector3(0, 0, -1)
	fwd = fwd.normalized()
	var best := Vector3.INF
	for attempt in 12:
		var dir := fwd.rotated(Vector3.UP, rng.randf_range(-0.7, 0.7))
		var p := player.global_position + dir * rng.randf_range(dmin, dmax)
		if Cabin.in_footprint(p.x, p.z, 2.0) or Shed.is_inside(p):
			continue
		# nicht im Garten selbst, sondern am Waldrand dahinter
		if absf(p.x) < 20.0 and p.z > -16.0 and p.z < 18.0 and Cabin.is_inside(player.global_position):
			continue
		p.y = Terrain.height_at(p.x, p.z)
		if Terrain.water_level_at(p.x, p.z) > p.y - 0.1:
			continue
		best = p
		break
	return best


static func _sees(player: Player, p: Vector3, cone: float = 0.93) -> bool:
	var cam := player.camera.global_transform
	var to := p - cam.origin
	return (-cam.basis.z).dot(to.normalized()) > cone


# --- Hände durch Spalten -------------------------------------------------------

static func _gap_hand(scene: Node, player: Player, cfg: ThreatConfig, rng: RandomNumberGenerator) -> void:
	if not Cabin.is_inside(player.global_position):
		return
	var options := []
	for g: Array in GAPS:
		var d := (g[0] as Vector3).distance_to(player.global_position)
		if d > 2.5 and d < 9.0:
			options.append(g)
	if options.is_empty():
		return
	var g: Array = options[rng.randi() % options.size()]
	var h := GapHand.new()
	h.damage = cfg.omen_hand_damage
	h.inward = g[1]
	scene.add_child(h)
	h.global_position = g[0]


class GapHand extends Node3D:
	## Graue, lange Hand schiebt sich aus einer Spalte und tastet. Ansehen = zieht sich zurück; zu nah = Kratzer.
	var inward := Vector3.UP
	var damage := 12.0
	var _arm: Node3D
	var _hand_root: Node3D
	var _t := 0.0
	var _seen_t := 0.0
	var _out := 0.0
	var _leaving := false
	var _hurt := false
	var _player: Player

	func _ready() -> void:
		_player = get_tree().get_first_node_in_group("player") as Player
		# Ausrichtung: lokale -y zeigt ins Zimmer
		var y := -inward.normalized()
		var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
		basis = Basis(x, y, x.cross(y).normalized())
		_arm = Node3D.new()
		add_child(_arm)
		_hand_root = Node3D.new()
		_arm.add_child(_hand_root)
		CreatureModel._materials()
		CreatureModel._forearm_and_hand(_hand_root, 1.0)
		_hand_root.scale = Vector3.ONE * 1.7
		_arm.position = Vector3(0, 0.9, 0)   # noch in der Wand
		SoundBank.play_at(get_parent(), "scratch", global_position, -6.0, 1.2)

	func _process(delta: float) -> void:
		_t += delta
		if _leaving:
			_out = maxf(_out - delta * 2.2, 0.0)
		else:
			_out = minf(_out + delta * 0.45, 1.0)
		_arm.position = Vector3(0, 0.9 - _out * 0.95, 0)
		# Finger tasten
		_hand_root.rotation = Vector3(sin(_t * 2.3) * 0.25, sin(_t * 1.7) * 0.4, sin(_t * 3.1) * 0.15)
		if _leaving:
			if _out <= 0.0:
				queue_free()
			return
		if _t > 22.0:
			_leave()
			return
		if _player == null:
			return
		var tip := _hand_root.global_position + global_basis.y * -0.4
		# angesehen (nah genug, im Blick, Licht oder Lampe an egal): nach kurzer Zeit zurück
		var d := _player.camera.global_position.distance_to(tip)
		if d < 9.0 and NightOmens._sees(_player, tip, 0.9):
			_seen_t += delta
			if _seen_t > 0.9:
				_leave()
				return
		# zu nah: kratzt
		if not _hurt and _out > 0.6 and _player.global_position.distance_to(tip) < 1.3:
			_hurt = true
			_player.take_damage(damage, tip)
			EventBus.player_hurt.emit(damage)
			CreatureSounds.play(get_parent(), "recoil", tip, -6.0, 1.2)
			_leave()

	func _leave() -> void:
		if _leaving:
			return
		_leaving = true
		SoundBank.play_at(get_parent(), "floor_creak", global_position, -6.0, 1.3)


# --- im Haus -----------------------------------------------------------------

## Eine Hängelampe im Haus beginnt zu pendeln, als hätte jemand sie angestoßen (am liebsten eine, die man sieht).
static func _lamp_swing(scene: Node, player: Player, rng: RandomNumberGenerator) -> void:
	var best: Node3D = null
	var best_d := 9.0
	for l in scene.get_tree().get_nodes_in_group("lamp"):
		var n := l as Node3D
		if n and Cabin.is_inside(n.global_position):
			var d := n.global_position.distance_to(player.global_position)
			if d < best_d:
				best_d = d
				best = n
	if best == null:
		return
	var tw := best.create_tween()
	var amp := rng.randf_range(10.0, 18.0)
	for k in 8:
		var a := amp * (1.0 - k / 8.0)
		tw.tween_property(best, "rotation_degrees:x", a if k % 2 == 0 else -a, 0.55).set_trans(Tween.TRANS_SINE)
	tw.tween_property(best, "rotation_degrees:x", 0.0, 0.5)
	SoundBank.play_at(scene, "floor_creak", best.global_position, -10.0, 1.4)


## Klopfen, das an den Wänden entlang um den Spieler herumwandert.
static func _knock_walk(scene: Node, player: Player, rng: RandomNumberGenerator) -> void:
	if not Cabin.is_inside(player.global_position):
		return
	var a0 := rng.randf() * TAU
	var dir := 1.0 if rng.randf() < 0.5 else -1.0
	for k in 7:
		scene.get_tree().create_timer(k * 0.9 + rng.randf_range(0.0, 0.2)).timeout.connect(func() -> void:
			if not is_instance_valid(player):
				return
			var a := a0 + dir * k * 0.55
			var p := player.global_position + Vector3(cos(a), 0, sin(a)) * 2.6 + Vector3(0, 1.1, 0)
			SoundBank.play_at(scene, "knock", p, -3.0 + k * 0.4, 0.8))


static func _music_box(scene: Node) -> void:
	var p := Vector3(-6.75, 1.1, -2.75)   # Kisten im Kinderzimmer
	SoundBank.play_at(scene, "music_box", p, -6.0, 0.94)


## Atem beschlägt eine Fensterscheibe von außen, drei Fingerstriche darin.
static func _window_fog(scene: Node, player: Player, rng: RandomNumberGenerator) -> void:
	var w := _near_window(scene, player, 7.0)
	if w == null:
		return
	var fog := FogPatch.new()
	scene.add_child(fog)
	fog.global_transform = w.global_transform
	fog.size = Vector2(w.width, w.height)


class FogPatch extends Node3D:
	var size := Vector2(1.0, 0.9)
	var _mat: StandardMaterial3D
	var _t := 0.0

	func _ready() -> void:
		_mat = StandardMaterial3D.new()
		_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mat.albedo_color = Color(0.85, 0.88, 0.9, 0.0)
		_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		var q := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = size * Vector2(0.55, 0.6)
		q.mesh = qm
		q.material_override = _mat
		q.position = Vector3(0.05, size.y * 0.5, 0.2)   # außen vor dem Glas
		q.rotation_degrees.y = 180.0
		add_child(q)
		# drei Fingerstriche (dunkler, schräg)
		var stroke := StandardMaterial3D.new()
		stroke.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		stroke.albedo_color = Color(0.1, 0.1, 0.12, 0.0)
		stroke.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		for i in 3:
			var s := MeshInstance3D.new()
			var sm := QuadMesh.new()
			sm.size = Vector2(0.025, size.y * 0.35)
			s.mesh = sm
			s.material_override = stroke
			s.position = Vector3(-0.08 + i * 0.07, size.y * 0.48, 0.19)
			s.rotation_degrees = Vector3(0, 180, 12)
			add_child(s)
		set_meta("stroke", stroke)
		CreatureSounds.play(get_parent(), "breath", global_position + Vector3(0, 1.0, 0) + global_basis.z * 0.5, -6.0)

	func _process(delta: float) -> void:
		_t += delta
		var a := clampf(_t / 1.5, 0.0, 1.0) * (1.0 - clampf((_t - 25.0) / 15.0, 0.0, 1.0))
		_mat.albedo_color.a = a * 0.55
		var st: StandardMaterial3D = get_meta("stroke")
		st.albedo_color.a = clampf((_t - 2.5) / 1.5, 0.0, 1.0) * a * 0.6
		if _t > 40.0:
			queue_free()


static func _near_window(scene: Node, player: Player, max_d: float) -> CabinWindow:
	var best: CabinWindow = null
	var best_d := max_d
	for w in scene.get_tree().get_nodes_in_group("entry_point"):
		if w is CabinWindow and (w as CabinWindow).health > 0.0 and (w as CabinWindow).barricade <= 0.0:
			var d := (w as Node3D).global_position.distance_to(player.global_position)
			if d < best_d:
				best_d = d
				best = w
	return best


## Ein dunkler Schatten huscht draußen an einem Fenster vorbei.
static func _window_pass(scene: Node, player: Player, rng: RandomNumberGenerator) -> void:
	var w := _near_window(scene, player, 9.0)
	if w == null:
		return
	var out := w.global_basis.z   # Fenster: lokale +z zeigt nach draußen
	var side := w.global_basis.x
	var base := w.global_position + out * 1.2
	base.y = Terrain.height_at(base.x, base.z)
	var fig := Node3D.new()
	scene.add_child(fig)
	CreatureModel.build(fig)
	fig.global_position = base - side * 2.5
	fig.look_at(fig.global_position + side, Vector3.UP)
	var tw := fig.create_tween()
	tw.tween_property(fig, "global_position", base + side * 2.5, 1.1)
	tw.tween_callback(fig.queue_free)
	CreatureSounds.play(scene, "step", base, -8.0, 0.9)


## Der Küchenwasserhahn läuft plötzlich – man muss ihn zudrehen.
static func _tap_run(scene: Node) -> void:
	if scene.get_tree().get_first_node_in_group("tap_ghost"):
		return
	var t := TapGhost.new()
	scene.add_child(t)
	t.global_position = Vector3(-1.45, 1.3, -0.75)


class TapGhost extends Interactable:
	var _player: AudioStreamPlayer3D
	var _stream: MeshInstance3D
	var _t := 0.0

	func _ready() -> void:
		add_to_group("tap_ghost")
		var body := Area3D.new()
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = Vector3(0.6, 0.5, 0.45)
		cs.shape = sh
		body.add_child(cs)
		add_child(body)
		_stream = MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.008
		cm.bottom_radius = 0.012
		cm.height = 0.3
		_stream.mesh = cm
		var wm := StandardMaterial3D.new()
		wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		wm.albedo_color = Color(0.7, 0.8, 0.9, 0.55)
		wm.roughness = 0.05
		_stream.material_override = wm
		_stream.position = Vector3(0, -0.12, -0.05)
		add_child(_stream)
		_player = AudioStreamPlayer3D.new()
		_player.stream = SoundBank.get_sound("faucet")
		_player.volume_db = -2.0
		_player.unit_size = 4.0
		add_child(_player)
		_player.finished.connect(func() -> void: _player.play())
		_player.play()

	func _process(delta: float) -> void:
		_t += delta
		if _t > 90.0:
			queue_free()

	func get_prompt(_p: Node) -> String:
		return "Das Wasser läuft  [E] zudrehen"

	func interact(_p: Node) -> void:
		SoundBank.play_at(get_parent(), "switch", global_position, -6.0, 0.7)
		queue_free()


## Zwei schwache Augen unter Bens Bett – verschwinden, wenn man näherkommt oder hinleuchtet.
static func _under_bed(scene: Node, player: Player) -> void:
	var p := Vector3(-8.35, 0.58, -0.5)
	if player.global_position.distance_to(p) < 4.0:
		return
	var e := UnderBedEyes.new()
	scene.add_child(e)
	e.global_position = p


class UnderBedEyes extends Node3D:
	var _t := 0.0
	var _player: Player

	func _ready() -> void:
		_player = get_tree().get_first_node_in_group("player") as Player
		var m := BuildKit.emissive_mat(Color(0.75, 0.9, 0.6), 1.6)
		for s: float in [-1.0, 1.0]:
			BuildKit.sphere(self, 0.012, Vector3(0, 0, s * 0.045), m, Vector3(1.0, 0.6, 1.0), 6)

	func _process(delta: float) -> void:
		_t += delta
		visible = fmod(_t, 4.0) > 0.15   # blinzeln
		if _t > 60.0:
			queue_free()
			return
		if _player == null:
			return
		var d := _player.global_position.distance_to(global_position)
		if d < 2.3 or (_player.light_shining() and d < 6.0 and NightOmens._sees(_player, global_position, 0.95)):
			SoundBank.play_at(get_parent(), "scratch", global_position, -8.0, 1.5)
			queue_free()


## Ein Vogel prallt gegen ein Fenster: dumpfer Schlag, ein paar Federn.
static func _bird_thud(scene: Node, player: Player, rng: RandomNumberGenerator) -> void:
	var w := _near_window(scene, player, 12.0)
	if w == null:
		return
	var p := w.global_position + Vector3(0, w.height * 0.6, 0) + w.global_basis.z * 0.25
	SoundBank.play_at(scene, "thud", p, 2.0, 1.3)
	SoundBank.play_at(scene, "glass_crack", p, -12.0, 1.4)
	Fx.burst(scene, p, "dust", w.global_basis.z, 0.6)


static func _wardrobe_open(scene: Node, player: Player) -> void:
	for h in scene.get_tree().get_nodes_in_group("hide_spot"):
		if h is HideSpot and not (h as HideSpot).occupied and (h as Node3D).global_position.distance_to(player.global_position) > 3.0 \
				and Cabin.is_inside((h as Node3D).global_position):
			(h as HideSpot).set_door(true)
			SoundBank.play_at(scene, "door_open", (h as Node3D).global_position + Vector3(0, 1.0, 0), -4.0, 0.7)
			return


# --- draußen im Wald ---------------------------------------------------------

## Schwebende, sanfte Lichter am Waldrand, die langsam treiben und erlöschen.
static func _lights(scene: Node, player: Player, rng: RandomNumberGenerator) -> void:
	var c := _view_spot(player, rng, 26.0, 50.0)
	if c == Vector3.INF:
		return
	var n := rng.randi_range(2, 5)
	for i in n:
		var w := Wisp.new()
		w.drift = Vector3(rng.randf_range(-0.6, 0.6), rng.randf_range(-0.05, 0.15), rng.randf_range(-0.6, 0.6))
		w.life = rng.randf_range(10.0, 22.0)
		w.delay = i * rng.randf_range(0.4, 1.5)
		scene.add_child(w)
		w.global_position = c + Vector3(rng.randf_range(-4, 4), rng.randf_range(1.0, 3.0), rng.randf_range(-4, 4))


class Wisp extends Node3D:
	var drift := Vector3.ZERO
	var life := 15.0
	var delay := 0.0
	var _t := 0.0
	var _light: OmniLight3D
	var _mat: StandardMaterial3D

	func _ready() -> void:
		_mat = BuildKit.emissive_mat(Color(0.65, 0.95, 0.85), 0.0)
		BuildKit.sphere(self, 0.11, Vector3.ZERO, _mat, Vector3.ONE, 8)
		_light = OmniLight3D.new()
		_light.light_color = Color(0.6, 0.95, 0.85)
		_light.omni_range = 7.0
		_light.light_energy = 0.0
		add_child(_light)

	func _process(delta: float) -> void:
		_t += delta
		var k := _t - delay
		var a := clampf(k / 2.0, 0.0, 1.0) * clampf((life - k) / 3.0, 0.0, 1.0)
		_mat.emission_energy_multiplier = a * 6.0
		_light.light_energy = a * 1.6 * (0.8 + 0.2 * sin(_t * 5.0))
		global_position += (drift + Vector3(sin(_t * 0.7) * 0.2, sin(_t * 1.3) * 0.08, cos(_t * 0.5) * 0.2)) * delta
		if k > life:
			queue_free()


## Ein Rudel Rehe flieht über die Lichtung am Waldrand – vor etwas, das man nicht sieht.
static func _animals(scene: Node, player: Player, rng: RandomNumberGenerator) -> void:
	var wl: Wildlife = null
	for n in scene.get_children():
		if n is Wildlife:
			wl = n
	if wl == null:
		return
	var c := _view_spot(player, rng, 22.0, 38.0)
	if c == Vector3.INF:
		return
	var src := c + (c - player.global_position).normalized().rotated(Vector3.UP, rng.randf_range(-1.2, 1.2)) * 8.0
	for i in rng.randi_range(2, 3):
		var a := wl.spawn_test("deer", c + Vector3(rng.randf_range(-2.5, 2.5), 0, rng.randf_range(-2.5, 2.5)))
		if a:
			a._flee_from(src, 7.0)
	SoundBank.play_at(scene, "twig", src + Vector3(0, 1, 0), 0.0, 0.8)


## Sucher oder Zerfleischer steht kurz am Waldrand und ist dann weg.
static func _glimpse(scene: Node, player: Player, rng: RandomNumberGenerator, what: String) -> void:
	var p := _view_spot(player, rng, 26.0, 42.0)
	if p == Vector3.INF:
		return
	var g := Glimpse.new()
	g.what = what
	scene.add_child(g)
	g.global_position = p
	g.look_at(Vector3(player.global_position.x, p.y, player.global_position.z), Vector3.UP)


class Glimpse extends Node3D:
	var what := "seeker"
	var _t := 0.0
	var _seen := 0.0
	var _life := 9.0
	var _player: Player

	func _ready() -> void:
		_player = get_tree().get_first_node_in_group("player") as Player
		var body: Node3D = Seeker.new() if what == "seeker" else Mauler.new()
		add_child(body)
		# nur das Aussehen – kein Verhalten, keine Gruppen
		body.set_process(false)
		body.set_physics_process(false)
		for grp in body.get_groups():
			body.remove_from_group(grp)
		if body.has_method("_on_noise") and EventBus.noise_made.is_connected(Callable(body, "_on_noise")):
			EventBus.noise_made.disconnect(Callable(body, "_on_noise"))
		body.position = Vector3.ZERO
		body.rotation = Vector3.ZERO
		# schwaches, kaltes Gegenlicht: man erkennt den Umriss in der Dunkelheit
		var rim := OmniLight3D.new()
		rim.light_color = Color(0.55, 0.65, 0.8)
		rim.light_energy = 1.4
		rim.omni_range = 6.0
		rim.position = Vector3(0, 2.0, 1.6)
		add_child(rim)
		var eyes := BuildKit.emissive_mat(Color(0.9, 0.85, 0.7) if what == "mauler" else Color(0.55, 0.9, 1.0), 2.5)
		if what == "mauler":
			for s: float in [-1.0, 1.0]:
				BuildKit.sphere(self, 0.018, Vector3(s * 0.06, 1.9, -0.55), eyes, Vector3.ONE, 6)
		if what == "seeker" and body.get("_eye_mat") is StandardMaterial3D:
			(body.get("_eye_mat") as StandardMaterial3D).emission_energy_multiplier = 4.0   # Augenlichter gut sichtbar
		_life = randf_range(5.0, 10.0)

	func _process(delta: float) -> void:
		_t += delta
		if _player and NightOmens._sees(_player, global_position + Vector3(0, 1.5, 0), 0.97):
			_seen += delta
		if _t > _life or _seen > 1.6:
			queue_free()
