class_name PlayerHands
extends Node3D
## Die Hände des Spielers im Bild (hängt an der Kamera).
##
## Rechte Hand: was auf dem gewählten Schnellplatz (1–9) liegt – Axt, Blechschere, Flasche, Konserve,
## Diktiergerät, Gießkanne … – oder die Faust, wenn der Platz leer ist. Die Finger legen sich um den
## Gegenstand (HandRig), die Modelle kommen aus HandItems.
## Linksklick = Angriff / Benutzen, Rechtsklick = Blocken (Gießkanne: füllen).
## Linke Hand: Smartwatch mit LED als Taschenlampe (F), Kompassnadel im Display, Bauhammer im Baumodus (B).
## Beide Hände schwingen beim Umsehen verzögert nach; beim Wechsel taucht der alte Gegenstand
## nach unten ab und der neue kommt von unten.

const LEFT_REST := Vector3(-0.2, -0.215, -0.36)
const HIDE_DROP := 0.5
const SWITCH_SPEED := 6.5

## Faust, Axt, Blechschere: Reichweite, Stärke (verscheucht die Kreatur unterschiedlich lange), Abklingzeit,
## Schadensart (blunt = stumpf, chop = Hieb, stab = Stich)
const MELEE := {
	"fist": {"reach": 1.5, "strength": 0.4, "cooldown": 0.45, "anim": "punch", "len": 0.34, "block": 0.5, "damage": "blunt"},
	"axe": {"reach": 2.1, "strength": 1.0, "cooldown": 0.8, "anim": "swing", "len": 0.6, "block": 0.3, "damage": "chop"},
	"tin_snips": {"reach": 1.7, "strength": 0.7, "cooldown": 0.5, "anim": "stab", "len": 0.38, "block": 0.45, "damage": "stab"},
}

## Ruhelage der rechten Hand je Art: Ort und Drehung vor der Kamera, Drehung des Handgelenks
## (z = -90: Daumen oben, Handfläche nach innen – so hält man Stiele, Flaschen und Dosen).
const REST := {
	"fist": {"pos": Vector3(0.265, -0.335, -0.33), "rot": Vector3(14, 16, 0), "wrist": Vector3(0, 0, -72)},
	"axe": {"pos": Vector3(0.265, -0.305, -0.42), "rot": Vector3(4, 12, -5), "wrist": Vector3(0, 0, -90)},
	"tin_snips": {"pos": Vector3(0.245, -0.255, -0.38), "rot": Vector3(-6, 18, -6), "wrist": Vector3(-30, 0, -80)},
	"food": {"pos": Vector3(0.24, -0.225, -0.4), "rot": Vector3(6, 14, 0), "wrist": Vector3(0, 0, -90)},
	"water": {"pos": Vector3(0.24, -0.225, -0.4), "rot": Vector3(6, 14, 0), "wrist": Vector3(0, 0, -90)},
	"dictaphone": {"pos": Vector3(0.22, -0.225, -0.38), "rot": Vector3(10, 16, 0), "wrist": Vector3(0, 0, -90)},
	"watering_can": {"pos": Vector3(0.275, -0.2, -0.4), "rot": Vector3(5, 10, 0), "wrist": Vector3(0, 0, -90)},
}
## Dauer der Benutzen-Animationen in Sekunden
const DRINK_TIME := 1.9
const EAT_TIME := 1.6
const POUR_TIME := 2.0
const FILL_TIME := 2.3

var player: Player
var watch_light: SpotLight3D
var blocking: bool = false

var _skin: StandardMaterial3D
var _sleeve: StandardMaterial3D
var _right: Node3D
var _right_model: Node3D
var _right_kind: String = ""
var _right_id: String = ""
var _right_out: float = 1.0
## Teile des Modells in der rechten Hand: Handgelenk, Hand mit Fingern, der Gegenstand, Grundhaltung der Finger
var _r_wrist: Node3D
var _r_hand: HandRig
var _r_item: Node3D
var _r_pose: Dictionary = {}
var _left: Node3D
var _left_arm: Node3D
var _l_wrist: Node3D
var _l_hand: HandRig
var _hammer: Node3D
var _left_out: float = 1.0
var _led: StandardMaterial3D
var _screen: StandardMaterial3D
var _screen_light: OmniLight3D
## Kompass im Uhr-Display: Nadel (rot = Norden), dreht sich mit der Blickrichtung
var _compass: Node3D
var _needle_mats: Array = []
var _needle_angle: float = 0.0
var _needle_vel: float = 0.0
## Licht-Modus der Uhr: false = LED nach vorn, true = Display leuchtet weiß (schwaches Umgebungslicht)
var screen_mode: bool = false
## Diktiergerät in der Hand und Linksklick gehalten = Aufnahme läuft (Manipulator-Stimme, Funkspruch)
var recording: bool = false
var _rec_led: StandardMaterial3D
var _rec_t: float = 0.0
var _rec_amount: float = 0.0
var _watch_on: bool = false

var _action: String = ""
var _action_t: float = 0.0
var _action_len: float = 0.0
var _action_hit_done: bool = false
var _cooldown: float = 0.0
var _block_amount: float = 0.0
var _time: float = 0.0
## Gießkanne: läuft beim Gießen Wasser (war die Kanne gefüllt)? Wasserstrahl aus der Brause.
var _pour_wet: bool = false
var _flowing: bool = false          # läuft gerade Wasser aus der Kanne?
var _bed_pour: float = 0.0          # wie lange schon Wasser auf das anvisierte Beet läuft
var _bed_pour_target: Node = null
var _pour_fx: CPUParticles3D
var _hint_cooldown: float = 0.0

var _sway := Vector2.ZERO
var _sway_vel := Vector2.ZERO
var _bob_pos := Vector3.ZERO   # Wippen beim Gehen (wird in _avoid_walls mit dem Zurückziehen verrechnet)
var _last_yaw: float = 0.0
var _last_pitch: float = 0.0


func _ready() -> void:
	name = "Hands"
	_skin = BuildKit.color_mat(Color(0.62, 0.46, 0.38), 0.8)
	_sleeve = BuildKit.tex_mat("fabric", 0.15, Color(0.55, 0.65, 0.6))
	_right = Node3D.new()
	_right.name = "Right"
	add_child(_right)
	_left = Node3D.new()
	_left.name = "Left"
	add_child(_left)
	_build_left()
	# schwaches Streulicht, damit die Hände im Dunkeln erkennbar bleiben – es beleuchtet NUR die Hände
	# (eigene Sichtebene), sonst würden nahe Gegenstände im Dunkeln hell (Christians Befund)
	var fill := OmniLight3D.new()
	fill.light_cull_mask = HANDS_LAYER
	fill.position = Vector3(0.0, 0.1, -0.2)
	fill.omni_range = 0.6
	fill.light_energy = 0.25
	fill.light_color = Color(1.0, 0.92, 0.8)
	add_child(fill)
	_tag_layers(self)
	Inventory.hotbar_changed.connect(_on_hotbar_changed)
	Inventory.changed.connect(_on_hotbar_changed)
	if player:
		_last_yaw = player.rotation.y
		_last_pitch = player.head.rotation.x


# --- Modelle ------------------------------------------------------------

func _no_shadows(n: Node) -> void:
	for mi in n.find_children("*", "GeometryInstance3D", true, false):
		(mi as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Sichtebene der Hände (zusätzlich zur normalen), nur für das Streulicht der Hände.
const HANDS_LAYER := 1 << 19


func _tag_layers(n: Node) -> void:
	# Hände liegen NUR auf ihrer eigenen Sichtebene: so beleuchtet sie das Streulicht, aber nicht die Uhr-LED,
	# die direkt hinter den Knöcheln sitzt und die Hand sonst grell weiß überstrahlt.
	BuildKit.localize_materials(n)
	for g in n.find_children("*", "GeometryInstance3D", true, false):
		(g as GeometryInstance3D).layers = HANDS_LAYER
	if n is GeometryInstance3D:
		(n as GeometryInstance3D).layers = HANDS_LAYER


## Unterarm im Ärmel: runder Stoffärmel mit Bündchen, läuft nach hinten-unten aus dem Bild.
func _forearm(parent: Node3D) -> void:
	HandKit.loft(parent, PackedVector3Array([Vector3(0, -0.002, 0.052), Vector3(0, -0.012, 0.16), Vector3(0, -0.04, 0.32), Vector3(0, -0.075, 0.5)]),
			PackedVector2Array([Vector2(0.0365, 0.0325), Vector2(0.041, 0.038), Vector2(0.047, 0.044), Vector2(0.052, 0.049)]), _sleeve, 10)
	var cuff := BuildKit.tex_mat("fabric", 0.15, Color(0.42, 0.5, 0.47))
	HandKit.loft(parent, PackedVector3Array([Vector3(0, -0.001, 0.036), Vector3(0, -0.002, 0.044), Vector3(0, -0.003, 0.074), Vector3(0, -0.004, 0.08)]),
			PackedVector2Array([Vector2(0.033, 0.028), Vector2(0.0385, 0.0345), Vector2(0.0385, 0.0345), Vector2(0.037, 0.033)]), cuff, 10)


## Blechschere für die Welt (Werkzeugwand): Backen zeigen nach +y, Drehpunkt etwa im Ursprung.
static func snips_model(parent: Node) -> Node3D:
	var v := Node3D.new()
	parent.add_child(v)
	var it := HandItems.build(v, "tin_snips")
	it.position = Vector3(0, -0.09, 0)
	HandItems.snips_open(it, 0.0)
	return v


## Arm, Hand und Gegenstand für die rechte Hand. kind = Art (Animationen), id = Gegenstand (Modell).
func _make_right(kind: String, id: String = "") -> Node3D:
	var m := Node3D.new()
	_forearm(m)
	_r_wrist = Node3D.new()
	_r_wrist.rotation_degrees = (REST.get(kind, REST["food"]) as Dictionary)["wrist"]
	m.add_child(_r_wrist)
	_r_hand = HandRig.create(_r_wrist, 1.0, _skin)
	_r_item = null
	_rec_led = null
	_r_pose = HandRig.FIST
	if kind != "fist":
		var model := HandItems.model_of(id) if id != "" else kind
		# Der Gegenstand liegt quer in der Faust; Halter so gedreht, dass „oben“ zum Daumen zeigt
		var holder := Node3D.new()
		_r_wrist.add_child(holder)
		holder.rotation_degrees = Vector3(0, 0, 90)
		_r_item = HandItems.build(holder, model)
		var r := float(_r_item.get_meta("grip", 0.02))
		holder.position = HandRig.grip_center(r)
		_r_item.position = Vector3(0, float(_r_item.get_meta("up", 0.0)), 0)
		_r_item.rotation_degrees = _r_item.get_meta("tilt", Vector3.ZERO)
		_r_pose = HandRig.grip(r, float(_r_item.get_meta("tight", 1.0)))
		var parts: Dictionary = _r_item.get_meta("parts", {})
		if parts.has("led"):
			_rec_led = parts["led"]
		if kind == "watering_can":
			HandItems.can_level(_r_item, float(Supplies.can_water) / maxf(Supplies.config.watering_can_charges, 1))
	_r_hand.set_pose(_r_pose)
	_no_shadows(m)
	return m


## Linker Arm mit Smartwatch (rundes dunkles Gehäuse, orangefarbenes Armband, LED vorne, Kompass im Display)
## und dem Bauhammer, der im Baumodus in der Faust liegt.
func _build_left() -> void:
	_left_arm = Node3D.new()
	_left.add_child(_left_arm)
	_forearm(_left_arm)
	_l_wrist = Node3D.new()
	_left_arm.add_child(_l_wrist)
	_l_hand = HandRig.create(_l_wrist, -1.0, _skin)
	var case_mat := BuildKit.tex_mat("metal", 0.1, Color(0.5, 0.5, 0.53), 0.35)
	var dark := BuildKit.color_mat(Color(0.07, 0.07, 0.08), 0.35, 0.5)
	var strap := BuildKit.color_mat(Color(0.88, 0.33, 0.08), 0.7)
	var strap_dark := BuildKit.color_mat(Color(0.5, 0.17, 0.04), 0.8)
	var watch := Node3D.new()
	watch.position = Vector3(0.0, 0.0, 0.03)
	_l_wrist.add_child(watch)
	# Armband: geschlossenes Band ums Handgelenk mit Rillen und Schließe unten
	HandKit.loft(watch, HandKit.arc(Vector3(0, -0.001, 0), 0.0315, 0, 360, 14, Vector3.RIGHT, Vector3.UP, 0.0225),
			PackedVector2Array([Vector2(0.0024, 0.0125)]), strap, 6, Vector3(0, 0, 1), false)
	for a: float in [38.0, 142.0, 180.0, 0.0]:
		var r := deg_to_rad(a)
		BuildKit.box(watch, Vector3(0.004, 0.006, 0.027), Vector3(cos(r) * 0.0325, -0.001 + sin(r) * 0.0232, 0), strap_dark, false, Vector3(0, 0, a - 90.0))
	BuildKit.box(watch, Vector3(0.016, 0.004, 0.028), Vector3(0, -0.0245, 0), case_mat, false)
	# Gehäuse: Bandanstöße, Boden, abgeschrägte Lünette, Drücker an der Seite
	var top := 0.0215
	for sz: float in [-1.0, 1.0]:
		BuildKit.box(watch, Vector3(0.03, 0.007, 0.01), Vector3(0, top + 0.002, sz * 0.022), dark, false, Vector3(sz * 18.0, 0, 0))
	BuildKit.lathe(watch, PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.021, 0.0), Vector2(0.0235, 0.003), Vector2(0.0235, 0.009), Vector2(0.0215, 0.0125), Vector2(0.0185, 0.0125)]),
			Vector3(0, top, 0), case_mat, 16)
	BuildKit.lathe(watch, PackedVector2Array([Vector2(0.0215, 0.0125), Vector2(0.0205, 0.0138), Vector2(0.0182, 0.0138), Vector2(0.0182, 0.012)]), Vector3(0, top, 0), dark, 16)
	for a: float in [-28.0, 28.0]:
		var r := deg_to_rad(a)
		BuildKit.box(watch, Vector3(0.005, 0.005, 0.008), Vector3(-cos(r) * 0.0245, top + 0.0065, sin(r) * 0.0245), dark, false, Vector3(0, a, 0))
	_screen = StandardMaterial3D.new()
	_screen.albedo_color = Color(0.02, 0.02, 0.025)
	_screen.roughness = 0.1
	_screen.emission_enabled = true
	_screen.emission = Color(0.4, 0.7, 0.9)
	_screen.emission_energy_multiplier = 0.0
	var face_y := top + 0.0128
	BuildKit.cylinder(watch, 0.0183, 0.001, Vector3(0, face_y, 0), _screen, false, Vector3.ZERO, -1.0, 16)
	_build_compass(watch, face_y + 0.0008)
	# LED vorne am Gehäuse
	_led = BuildKit.emissive_mat(Color(1.0, 0.97, 0.9), 0.0)
	BuildKit.box(watch, Vector3(0.012, 0.0055, 0.004), Vector3(0, top + 0.006, -0.0235), _led, false)
	BuildKit.box(watch, Vector3(0.016, 0.008, 0.003), Vector3(0, top + 0.006, -0.0222), dark, false)
	watch_light = SpotLight3D.new()
	watch_light.position = Vector3(0, top + 0.006, -0.034)
	watch_light.rotation_degrees = Vector3(2, 10, 0)
	watch_light.light_color = Color(1.0, 0.97, 0.9)
	watch_light.light_energy = 4.5
	watch_light.spot_range = 24.0
	watch_light.spot_angle = 30.0
	watch_light.spot_angle_attenuation = 1.4
	watch_light.spot_attenuation = 1.0
	watch_light.shadow_enabled = true
	watch_light.light_volumetric_fog_energy = 1.2
	watch_light.light_cull_mask = 0xFFFFF & ~HANDS_LAYER
	watch_light.visible = false
	watch.add_child(watch_light)
	# Display-Modus: weißes Uhr-Display als schwaches Umgebungslicht (F gedrückt halten)
	_screen_light = OmniLight3D.new()
	_screen_light.position = Vector3(0, top + 0.045, 0)
	_screen_light.light_color = Color(0.92, 0.95, 1.0)
	_screen_light.light_energy = 0.0
	_screen_light.omni_range = 4.5
	_screen_light.omni_attenuation = 1.6
	_screen_light.shadow_enabled = false
	_screen_light.light_cull_mask = 0xFFFFF & ~HANDS_LAYER
	watch.add_child(_screen_light)
	# Bauhammer in der Faust (nur im Baumodus sichtbar)
	var r_grip := 0.0135
	var holder := Node3D.new()
	holder.position = HandRig.grip_center(r_grip)
	holder.rotation_degrees = Vector3(0, 0, -90)
	_l_wrist.add_child(holder)
	_hammer = HandItems.build(holder, "hammer")
	_hammer.rotation_degrees = _hammer.get_meta("tilt", Vector3.ZERO)
	_hammer.visible = false
	_set_left_mode(false)
	_no_shadows(_left)


## Kompass auf dem Display: vier feste Striche am Rand, drehbare Nadel mit roter Nordspitze.
func _build_compass(watch: Node3D, y: float) -> void:
	var tick := _glow_mat(Color(0.75, 0.85, 0.9))
	for i in 4:
		var a := i * PI * 0.5
		BuildKit.box(watch, Vector3(0.0012, 0.0004, 0.0032), Vector3(sin(a) * 0.0152, y, -cos(a) * 0.0152), tick, false, Vector3(0, -rad_to_deg(a), 0))
	_compass = Node3D.new()
	_compass.position = Vector3(0, y + 0.0004, 0)
	watch.add_child(_compass)
	var red := _glow_mat(Color(1.0, 0.16, 0.1))
	var pale := _glow_mat(Color(0.8, 0.86, 0.9))
	# Nordhälfte: roter Pfeil (Schaft + Spitze), Südhälfte: heller Strich
	HandKit.extrude(_compass, PackedVector2Array([Vector2(-0.0016, 0.0), Vector2(0.0016, 0.0), Vector2(0.0012, 0.0075), Vector2(0.0034, 0.0075),
			Vector2(0.0, 0.0138), Vector2(-0.0034, 0.0075), Vector2(-0.0012, 0.0075)]), 0.0003, red).rotation_degrees.x = -90.0
	HandKit.extrude(_compass, PackedVector2Array([Vector2(-0.0014, 0.0), Vector2(0.0014, 0.0), Vector2(0.0006, -0.0115), Vector2(-0.0006, -0.0115)]), 0.0003, pale).rotation_degrees.x = -90.0
	BuildKit.cylinder(_compass, 0.0022, 0.001, Vector3(0, 0.0004, 0), BuildKit.color_mat(Color(0.08, 0.08, 0.09), 0.3, 0.6), false, Vector3.ZERO, -1.0, 8)


## Selbstleuchtende Farbe für die Anzeige (ohne Schattierung, damit sie auf dem Display lesbar bleibt).
func _glow_mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	m.set_meta("on", c)
	_needle_mats.append(m)
	return m


## Hammerschläge mit der linken Hand (Baumodus): hits Schläge hintereinander.
const TAP_TIME := 0.36
var _tap_t: float = -1.0
var _tap_hits: int = 0


func hammer_taps(hits: int = 1) -> void:
	_tap_t = 0.0
	_tap_hits = maxi(hits, 1)


## Linke Hand: Uhr ablesen/leuchten (Handrücken oben) oder Hammer halten (Daumen oben).
func _set_left_mode(build: bool) -> void:
	_hammer.visible = build
	if build:
		_left_arm.rotation_degrees = Vector3(2, -12, 4)
		_l_wrist.rotation_degrees = Vector3(0, 0, 90)
		_l_hand.set_pose(HandRig.grip(0.0135))
	else:
		_left_arm.rotation_degrees = Vector3(6, -16, 0)
		_l_wrist.rotation_degrees = Vector3(0, 0, -24)
		_l_hand.set_pose(HandRig.mix(HandRig.RELAXED, HandRig.FIST, 0.55))


# --- Zustand ------------------------------------------------------------

## Die Kreatur stört die Uhr-Lampe: erst Flackern, dann evtl. kurz ganz aus.
## Die Lampe bleibt dabei "eingeschaltet" – sie leuchtet nur nicht zuverlässig.
var _interfere_id: int = 0
## solange gestört wird, spielt auch die Kompassnadel verrückt
var _compass_jam: float = 0.0


func interfere(seconds: float, blackout: float) -> void:
	_interfere_id += 1
	var id := _interfere_id
	_compass_jam = seconds + blackout
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end and id == _interfere_id and is_inside_tree():
		_set_glow(randf() < 0.45)
		await get_tree().create_timer(randf_range(0.03, 0.16)).timeout
	if blackout > 0.0 and id == _interfere_id and is_inside_tree():
		_set_glow(false)
		await get_tree().create_timer(blackout).timeout
	if id == _interfere_id and is_inside_tree():
		_set_glow(true)


func _set_glow(on: bool) -> void:
	var lit := on and _watch_on
	# Kompass: Anzeige nur bei eingeschalteter Uhr hell
	for m: StandardMaterial3D in _needle_mats:
		var c: Color = m.get_meta("on")
		m.albedo_color = c if lit else (c * 0.35 if _watch_on else c * 0.12)
	if screen_mode:
		watch_light.light_energy = 0.0
		_led.emission_energy_multiplier = 0.0
		_screen_light.light_energy = 0.55 if lit else 0.0
		_screen.emission = Color(1.0, 1.0, 1.0)
		_screen.emission_energy_multiplier = 3.0 if lit else (0.1 if _watch_on else 0.0)
		return
	_screen_light.light_energy = 0.0
	_screen.emission = Color(0.4, 0.7, 0.9)
	watch_light.light_energy = 4.5 if lit else 0.0
	_led.emission_energy_multiplier = 6.0 if lit else 0.0
	_screen.emission_energy_multiplier = 0.6 if lit else (0.08 if _watch_on else 0.0)


## Leuchtet die Lampe gerade wirklich?
func light_shining() -> bool:
	return _watch_on and watch_light.light_energy > 0.5


func set_watch(on: bool) -> void:
	_watch_on = on
	_interfere_id += 1
	watch_light.visible = on
	_set_glow(true)


## Zwischen LED und weißem Display umschalten (nur bei eingeschalteter Uhr).
func toggle_screen_mode() -> void:
	screen_mode = not screen_mode
	_interfere_id += 1
	_set_glow(true)


## true, solange mit dem Werkzeug gearbeitet wird (Holz hacken): das Werkzeug bleibt in der Hand.
var working: bool = false


## Diktiergerät: Linksklick halten = aufnehmen. Ruft der Manipulator währenddessen in Hörweite, oder läuft
## am Radio (in der Nähe) eine Nachricht, wird das mitgeschnitten (Forschung: Stimme / Funkspruch).
func _update_recording(delta: float) -> void:
	var want := _right_kind == "dictaphone" and _right_out < 0.2 and Input.is_action_pressed("attack") \
			and not player.input_locked and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not GameState.dead
	if want != recording:
		recording = want
		SoundBank.play_ui(self, "switch", -14.0, 1.7 if want else 1.3)
		if want:
			_rec_t = 0.0
	_rec_amount = move_toward(_rec_amount, 1.0 if recording else 0.0, delta * 5.0)
	if not recording:
		return
	_rec_t += delta
	capture_recordings()


## Was das laufende Diktiergerät gerade mitschneidet (auch für Tests aufrufbar).
func capture_recordings() -> void:
	var now := Time.get_ticks_msec()
	var range_m := float(Research.gadget("dictaphone", "range", 70.0))
	# Manipulator: Ruf in den letzten Sekunden, in Hörweite
	if now - Manipulator.last_call_msec < 4000 and player.global_position.distance_to(Manipulator.last_call_pos) < range_m \
			and Inventory.count("rec_voice") <= 0 and not Research.done.has("an_voice"):
		if Inventory.add("rec_voice", 1) > 0:
			EventBus.notify("Aufgenommen: eine Stimme, die nicht echt ist.", 3.5)
	# Radio: Nachricht läuft, Radio in der Nähe
	var radio := get_tree().get_first_node_in_group("radio") as Node3D
	if radio and now < Radio.message_until_msec and player.global_position.distance_to(radio.global_position) < 8.0 \
			and TimeManager.day >= int(Research.gadget("dictaphone", "radio_from_day", 5)) \
			and Inventory.count("rec_radio") <= 0 and not Research.done.has("an_radio_cipher"):
		if Inventory.add("rec_radio", 1) > 0:
			EventBus.notify("Mitgeschnitten: Zwischen den Meldungen sind Zahlen zu hören.", 4.0)


func _building() -> bool:
	var bc := get_tree().get_first_node_in_group("build_controller") as BuildController
	return bc != null and bc.active


## Art (für Animationen) und Gegenstand (für das Modell), die in die rechte Hand gehören.
func _wanted_right() -> String:
	if player and ((player.input_locked and not working) or GameState.dead):
		return ""
	var id := Inventory.equipped()
	var kind := "fist"
	if id != "":
		kind = String(DataDB.item(id).get("hand", "fist"))
	return kind


func _wanted_id() -> String:
	if player and ((player.input_locked and not working) or GameState.dead):
		return ""
	return Inventory.equipped()


func _on_hotbar_changed() -> void:
	pass  # der Wechsel passiert weich in _process


func current_kind() -> String:
	return _right_kind


# --- Eingabe ------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if player == null or player.input_locked or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED or get_tree().paused:
		return
	for i in Inventory.SLOTS:
		if event.is_action_pressed("slot_%d" % (i + 1)):
			Inventory.select(i)
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("slot_next"):
		Inventory.select(Inventory.selected + 1)
	elif event.is_action_pressed("slot_prev"):
		Inventory.select(Inventory.selected - 1)
	elif event.is_action_pressed("attack") and not _building():
		_primary()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("block") and not _building() and _right_kind == "watering_can":
		_secondary()
		get_viewport().set_input_as_handled()


func _primary() -> void:
	if _cooldown > 0.0 or _action != "" or _right_out > 0.2 or blocking:
		return
	match _right_kind:
		"axe":
			# Über einem umgestürzten Stamm: fällen statt zuschlagen
			var node := player.current_interactable as ResourceNode
			if node and node.tool == "axe" and node.amount > 0:
				node.interact(player)
				return
			# Wucherung oder Knoten: weghacken
			var target := player.current_interactable
			if target and target.has_method("axe_hit"):
				_start_action("chop", 0.45)
				_cooldown = 0.55
				target.call("axe_hit", player)
				return
			_start_action("swing", MELEE["axe"]["len"])
			_cooldown = MELEE["axe"]["cooldown"]
		"fist":
			_start_action("punch", MELEE["fist"]["len"])
			_cooldown = MELEE["fist"]["cooldown"]
		"tin_snips":
			# Am Autowrack: Blech abschneiden statt zustechen
			var node := player.current_interactable as ResourceNode
			if node and node.tool == "tin_snips" and node.amount > 0:
				node.interact(player)
				return
			if player.current_interactable is ScrapSpot:
				player.current_interactable.interact(player)
				return
			_start_action("stab", MELEE["tin_snips"]["len"])
			_cooldown = MELEE["tin_snips"]["cooldown"]
		"water":
			_start_action("drink", DRINK_TIME)
			_cooldown = DRINK_TIME + 0.1
		"food":
			_start_action("eat", EAT_TIME)
			_cooldown = EAT_TIME + 0.1
		"watering_can":
			# Linksklick gießt. Über einem Beet muss man kurz draufhalten (water_pour_seconds), dann ist es gegossen.
			start_pour()


## Rechtsklick mit der Gießkanne: an Regentonne, Wasserhahn oder Bach füllen.
func _secondary() -> void:
	if _action != "" or _right_out > 0.2:
		return
	var t := player.current_interactable
	if t and String(t.get_secondary_prompt(player)).contains("Gießkanne"):
		player.use_target(true)
		return
	if _hint_cooldown > 0.0:
		return
	_hint_cooldown = 2.5
	if Supplies.can_water >= Supplies.config.watering_can_charges:
		EventBus.notify("Die Gießkanne ist voll.", 2.0)
	else:
		EventBus.notify("Zum Füllen an Regentonne, Wasserhahn oder Bach gehen.", 2.5)


## Gieß-Bewegung starten (auch von außen, z. B. wenn am Beet E gedrückt wird). Wasser läuft nur aus gefüllter Kanne.
func start_pour(wet: bool = false) -> void:
	if _right_kind != "watering_can" or _right_out > 0.2:
		return
	if _action == "pour":
		_pour_wet = _pour_wet or wet
		return
	if _action != "":
		return
	_pour_wet = wet or Supplies.can_water > 0
	_start_action("pour", POUR_TIME)
	if not _pour_wet and _hint_cooldown <= 0.0:
		_hint_cooldown = 2.5
		EventBus.notify("Die Gießkanne ist leer – mit Rechtsklick an Regentonne, Wasserhahn oder Bach füllen.", 3.0)


## Gießen: solange Wasser auf ein durstiges Beet läuft, zählt die Zeit; erst dann ist es gegossen.
func _update_bed_pour(delta: float) -> void:
	var t: Node = player.current_interactable if player else null
	if not is_instance_valid(t):
		t = null
	if not is_instance_valid(_bed_pour_target):
		_bed_pour_target = null
	var thirsty := t is GardenBed and (t as GardenBed).needs_water()
	if not thirsty or t != _bed_pour_target:
		if _bed_pour > 0.15 and _bed_pour_target is GardenBed and (_bed_pour_target as GardenBed).needs_water() and _hint_cooldown <= 0.0:
			_hint_cooldown = 2.5
			EventBus.notify("Etwas länger gießen – Linksklick gedrückt halten.", 2.0)
		_bed_pour = 0.0
		_bed_pour_target = t if thirsty else null
		return
	if not _flowing:
		if _action != "pour" and _bed_pour > 0.15 and _hint_cooldown <= 0.0:
			_hint_cooldown = 2.5
			EventBus.notify("Etwas länger gießen – Linksklick gedrückt halten.", 2.0)
		if _action != "pour":
			_bed_pour = 0.0
		return
	_bed_pour += delta
	if _bed_pour >= Supplies.config.water_pour_seconds:
		_bed_pour = 0.0
		(t as GardenBed).finish_watering()


## Füll-Bewegung: Kanne nach vorn ins Wasser tauchen (wird vom Wasser aufgerufen, wenn gefüllt wurde).
func start_fill() -> void:
	if _right_kind != "watering_can" or _right_out > 0.2:
		return
	_start_action("fill", FILL_TIME)
	_cooldown = FILL_TIME


## Ein einzelner Hieb ohne Treffer-Prüfung (z. B. beim Holzhacken, pro Schlag aufgerufen).
func tool_swing(length: float = 0.55) -> void:
	_start_action("snip" if _right_kind == "tin_snips" else "chop", length)


func _start_action(a: String, length: float) -> void:
	_action = a
	_action_t = 0.0
	_action_len = length
	_action_hit_done = false


## Treffer: Kreatur vor dem Spieler wird verscheucht; sonst ein dumpfer Schlag gegen Wände.
func _melee_hit(kind: String) -> void:
	var cfg: Dictionary = MELEE[kind]
	var cam := player.camera.global_transform
	var fwd := -cam.basis.z
	var c: Creature = (ThreatDirector.creature as Creature) if is_instance_valid(ThreatDirector.creature) else null
	if c:
		# waagerecht prüfen: Abstand und ob sie vor dem Spieler steht (ganz nah genügt "grob vorne")
		var to := c.global_position - player.global_position
		to.y = 0.0
		var fwd_h := Vector3(fwd.x, 0.0, fwd.z).normalized()
		var d := to.length()
		var facing := fwd_h.dot(to.normalized()) if d > 0.01 else 1.0
		if d < float(cfg["reach"]) + 0.4 and (facing > 0.6 or (d < 1.0 and facing > 0.0)):
			c.on_melee_hit(float(cfg["strength"]), player.global_position, String(cfg["damage"]))
			SoundBank.play_at(get_tree().current_scene, "wood_crack" if kind == "axe" else ("scratch" if kind == "tin_snips" else "thud"), c.global_position + Vector3(0, 1.3, 0), -2.0, 1.3)
			EventBus.screen_shake.emit(0.15)
			return
	var q := PhysicsRayQueryParameters3D.create(cam.origin, cam.origin + fwd * float(cfg["reach"]))
	q.exclude = [player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		_impact_sound(hit["collider"] as Node, hit["position"])
		EventBus.noise_made.emit(hit["position"], 6.0)


## Genau ein Klang beim Treffer – je nach Material wie ein Schritt auf Holz, Kies, Stein …; Metall klingt metallisch.
func _impact_sound(collider: Node, pos: Vector3) -> void:
	var scene := get_tree().current_scene
	var to_cam := (get_parent() as Node3D).global_position - pos
	var fx_dir := to_cam.normalized() + Vector3(0, 0.5, 0)
	var strong := _right_kind in ["axe", "tin_snips"]
	var n := collider
	while n and n != scene:
		var nm := String(n.name)
		if nm in ["CarWreck", "Generator"] or nm.begins_with("Fuel") or n is AlienStructure or n is CrashSite:
			SoundBank.play_at(scene, "collect_metal", pos, -2.0)
			if strong:
				Fx.burst(scene, pos, "metal", fx_dir)
			return
		if n is Terrain:
			if not Footsteps.play_surface(scene, pos, Footsteps.surface_at(pos), "run", 2.0):
				SoundBank.play_at(scene, "thud", pos, -10.0)
			Fx.burst(scene, pos, "dirt", fx_dir, 0.8)
			return
		if nm == "RockColliders" or n is StreamCave:
			Footsteps.play_surface(scene, pos, "stone", "run", 2.0)
			Fx.burst(scene, pos, "stone", fx_dir, 0.8 if strong else 0.4)
			return
		n = n.get_parent()
	# Hütte, Schuppen, Bäume, Stämme, Bauten: Holz
	if not Footsteps.play_surface(scene, pos, "wood", "run", 2.0):
		SoundBank.play_at(scene, "thud", pos, -10.0)
	Fx.burst(scene, pos, "wood" if strong else "dust", fx_dir, 0.8 if strong else 0.5)


## Schadensminderung beim Blocken (1 = kein Block).
func block_factor(from: Vector3) -> float:
	if _block_amount < 0.6 or not MELEE.has(_right_kind):
		return 1.0
	var to := (from - player.global_position)
	to.y = 0.0
	var fwd := -player.global_transform.basis.z
	if fwd.dot(to.normalized()) < 0.2:
		return 1.0
	return float(MELEE[_right_kind]["block"])


# --- Ablauf -------------------------------------------------------------

func _process(delta: float) -> void:
	if player == null:
		return
	_time += delta
	_cooldown = maxf(_cooldown - delta, 0.0)
	_hint_cooldown = maxf(_hint_cooldown - delta, 0.0)
	_compass_jam = maxf(_compass_jam - delta, 0.0)
	blocking = MELEE.has(_right_kind) and Input.is_action_pressed("block") and not player.input_locked \
			and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not _building() and _action == ""
	_block_amount = move_toward(_block_amount, 1.0 if blocking else 0.0, delta * 7.0)

	_update_recording(delta)

	# Rechte Hand: alten Gegenstand wegnehmen, neuen holen
	var want := _wanted_right()
	var want_id := _wanted_id()
	if want != _right_kind or want_id != _right_id:
		_action = ""
		_stop_pour()
		_right_out = move_toward(_right_out, 1.0, delta * SWITCH_SPEED)
		if _right_out >= 1.0:
			if _right_model:
				_right_model.queue_free()
				_right_model = null
			_right_kind = want
			_right_id = want_id
			if want != "":
				_right_model = _make_right(want, want_id)
				_right.add_child(_right_model)
				_tag_layers(_right_model)
	elif _right_kind != "":
		_right_out = move_toward(_right_out, 0.0, delta * SWITCH_SPEED)

	# Linke Hand: sichtbar bei eingeschalteter Uhr-Lampe oder im Baumodus (Hammer)
	var build := _building()
	var left_wanted := (_watch_on or build) and not GameState.dead
	if build != _hammer.visible and _left_out >= 0.99:
		_set_left_mode(build)
	if left_wanted and (build == _hammer.visible):
		_left_out = move_toward(_left_out, 0.0, delta * SWITCH_SPEED)
	else:
		_left_out = move_toward(_left_out, 1.0, delta * SWITCH_SPEED)
	_left.visible = _left_out < 0.99
	_right.visible = _right_out < 0.99 and _right_kind != ""

	_update_sway(delta)
	_pose_right(delta)
	_update_bed_pour(delta)
	_pose_left(delta)
	_avoid_walls(delta)


## Steht man dicht vor einer Wand oder Tür, zieht man Hände und Werkzeug zurück und senkt sie –
## so verschwinden sie nicht in der Wand.
var _wall_push: float = 0.0


func _avoid_walls(delta: float) -> void:
	var cam := get_parent() as Node3D
	if cam == null or not is_inside_tree():
		return
	var space := get_world_3d().direct_space_state
	var origin := cam.global_position
	var b := cam.global_transform.basis
	var nearest := 9.0
	# Mitte und Richtung der beiden Hände prüfen
	for off: Vector3 in [Vector3(0, 0, -1), Vector3(0.35, -0.25, -1).normalized(), Vector3(-0.3, -0.25, -1).normalized(), Vector3(0.3, 0.15, -1).normalized()]:
		var q := PhysicsRayQueryParameters3D.create(origin, origin + b * off * 1.0)
		if player:
			q.exclude = [player.get_rid()]
		var hit := space.intersect_ray(q)
		if not hit.is_empty():
			nearest = minf(nearest, origin.distance_to(hit["position"]))
	var want := clampf((0.8 - nearest) / 0.55, 0.0, 1.0)
	if player and player.hidden_in != null:
		want = minf(want, 0.15)   # im Schrank/Spind: Hände bleiben sichtbar, man kann Licht und Gegenstände benutzen
	_wall_push = move_toward(_wall_push, want, delta * 6.0)
	# zusammen mit Nachschwingen und Wippen (vorher hat das hier beides überschrieben – Hände ohne Verzögerung)
	position = _bob_pos + Vector3(0.0, -0.1 * _wall_push, 0.3 * _wall_push)
	rotation = Vector3(_sway.y + deg_to_rad(-28.0 * _wall_push), _sway.x, _sway.x * 0.6)


## Nachschwingen: die Hände bleiben beim Umsehen etwas zurück und federn nach.
func _update_sway(delta: float) -> void:
	var yaw := player.rotation.y
	var pitch := player.head.rotation.x
	var dyaw := wrapf(yaw - _last_yaw, -PI, PI)
	var dpitch := pitch - _last_pitch
	_last_yaw = yaw
	_last_pitch = pitch
	_sway -= Vector2(dyaw, dpitch) * 0.85
	var k := 140.0
	var damping := 13.0
	# Feder in kleinen festen Schritten rechnen – bei ruckelnden Bildern (lange Frames) schaukelt sie sich sonst auf
	var dt := minf(delta, 0.1)
	var steps := clampi(ceili(dt / 0.004), 1, 25)
	var h := dt / steps
	for i in steps:
		_sway_vel += (-_sway * k - _sway_vel * damping) * h
		_sway += _sway_vel * h
	var lim := Vector2(0.3, 0.25)
	var clamped := _sway.clamp(-lim, lim)
	if clamped.x != _sway.x:
		_sway_vel.x = 0.0
	if clamped.y != _sway.y:
		_sway_vel.y = 0.0
	_sway = clamped
	# Wippen beim Gehen
	var t: float = player._bob_time
	var moving := Vector2(player.velocity.x, player.velocity.z).length() > 0.3 and player.is_on_floor()
	var target := Vector3(sin(t * 0.5) * 0.012, -absf(cos(t * 0.5)) * 0.01, 0.0) if moving else Vector3.ZERO
	_bob_pos = _bob_pos.lerp(target, clampf(delta * 10.0, 0.0, 1.0))


## Für die Vorschau (scenes/dev/hands_preview.tscn): eine Aktion an einem festen Zeitpunkt einfrieren.
func preview_freeze(action: String, p: float, length: float = 1.0) -> void:
	_rec_amount = 0.0
	_block_amount = 0.0
	_action = ""
	match action:
		"record":
			_rec_amount = p
			_rec_t = 0.2
			recording = p > 0.5
		"block":
			_block_amount = p
		"":
			pass
		_:
			_action = action
			_action_len = length
			_action_t = p * length
			_action_hit_done = true
			_pour_wet = true
	_pose_right(0.0)
	_pose_left(0.0)
	if _pour_fx and _pour_fx.emitting:
		_pour_fx.preprocess = 0.6
		_pour_fx.restart()


static func _ease(p: float, from: float, to: float) -> float:
	return smoothstep(from, to, p)


## Glockenkurve: steigt von a bis b auf 1, bleibt bis c, fällt bis d auf 0.
static func _bell(p: float, a: float, b: float, c: float, d: float) -> float:
	return smoothstep(a, b, p) * (1.0 - smoothstep(c, d, p))


func _pose_right(delta: float) -> void:
	var rest: Dictionary = REST.get(_right_kind, REST["food"])
	var pos: Vector3 = rest["pos"]
	var rot: Vector3 = rest["rot"]
	var wrist: Vector3 = rest["wrist"]
	var e := _right_out * _right_out
	pos.y -= HIDE_DROP * e
	rot.x -= 35.0 * e
	# ruhiges Atmen: die Hand hebt und senkt sich ganz leicht
	pos += Vector3(sin(_time * 0.9) * 0.0015, sin(_time * 1.7) * 0.0028, 0.0)
	rot.z += sin(_time * 1.1) * 0.5
	var finger := _r_pose          # Fingerhaltung für dieses Bild
	var snips_open := 1.0
	var cap_open := 0.0
	var lid_open := 0.0
	var level := 1.0
	var pouring := false
	# Blocken: Faust bzw. Werkzeug quer vors Gesicht
	if _block_amount > 0.0:
		var bp := Vector3(0.07, -0.16, -0.3) if _right_kind == "fist" else Vector3(0.1, -0.25, -0.4)
		var br := Vector3(18, 30, 30) if _right_kind == "fist" else Vector3(8, 24, 64)
		var b := smoothstep(0.0, 1.0, _block_amount)
		pos = pos.lerp(bp, b)
		rot = rot.lerp(br, b)
		snips_open = 1.0 - b
	# Diktiergerät: zum Aufnehmen anheben und zum Mund drehen, Daumen drückt die Aufnahmetaste
	if _right_kind == "dictaphone":
		var r := smoothstep(0.0, 1.0, _rec_amount)
		pos = pos.lerp(Vector3(0.13, -0.17, -0.34), r)
		rot = rot.lerp(Vector3(22, 26, 6), r)
		if r > 0.0 and not _r_pose.is_empty():
			var press := _r_pose.duplicate(true)
			press["t"][3] = float(press["t"][3]) + 14.0
			press["t"][4] = float(press["t"][4]) + 22.0
			finger = HandRig.mix(_r_pose, press, r)
		_animate_dictaphone(delta)
	if _action != "":
		_action_t += delta
		var p := clampf(_action_t / _action_len, 0.0, 1.0)
		match _action:
			"punch":
				# kurze Gerade: aus der tiefen Ruhelage hoch und nach vorne, Faust dreht sich dabei ein
				var f := sin(clampf(p * 2.2, 0.0, 1.0) * PI * 0.5) if p < 0.45 else 1.0 - smoothstep(0.45, 1.0, p)
				var back := _bell(p, 0.0, 0.1, 0.12, 0.3) * 0.25
				pos += Vector3(-0.15, 0.2, -0.17) * f + Vector3(0.02, -0.01, 0.06) * back
				rot += Vector3(8, 22, 0) * f
				wrist.z = lerpf(wrist.z, -20.0, f)
				if p >= 0.4 and not _action_hit_done:
					_action_hit_done = true
					_melee_hit("fist")
			"swing", "chop":
				var up := smoothstep(0.0, 0.28, p)
				var down := smoothstep(0.28, 0.5, p)
				var back := smoothstep(0.55, 1.0, p)
				# Drehung um den Ellbogen (hinter der Hand), damit Unterarm und Ärmel
				# nie vor die Kamera klappen; Ausholen nach hinten, Schlag nur bis schräg nach vorne
				var swing := (38.0 * up - 74.0 * down) * (1.0 - back)
				rot.x += swing
				var elbow := Vector3(0.0, -0.06, 0.34)
				pos += elbow - Basis.from_euler(Vector3(deg_to_rad(swing), 0.0, 0.0)) * elbow
				pos += Vector3(-0.05, 0.05 * up, -0.05 * down) * (1.0 - back)
				if _action == "swing":
					# schräger Hieb von rechts oben nach links unten, die Schneide dreht in die Schlagrichtung
					rot.z += (16.0 * up - 30.0 * down) * (1.0 - back)
					rot.y += (-8.0 * up + 18.0 * down) * (1.0 - back)
					pos.x += (0.05 * up - 0.14 * down) * (1.0 - back)
				# Nachfedern nach dem Treffer
				pos.y += sin(clampf((p - 0.5) / 0.2, 0.0, 1.0) * PI) * 0.012
				if _action == "swing" and p >= 0.47 and not _action_hit_done:
					_action_hit_done = true
					_melee_hit("axe")
			"stab":
				# kurzer Stich nach vorne, Spitze voraus, Schere geschlossen
				var f := smoothstep(0.0, 0.4, p) * (1.0 - smoothstep(0.5, 1.0, p))
				pos += Vector3(-0.12, 0.1, -0.2) * f + Vector3(0.0, 0.0, 0.05) * _bell(p, 0.0, 0.08, 0.1, 0.25)
				rot += Vector3(4, 12, 0) * f
				snips_open = 1.0 - smoothstep(0.0, 0.15, p) * (1.0 - smoothstep(0.75, 1.0, p))
				if p >= 0.4 and not _action_hit_done:
					_action_hit_done = true
					_melee_hit("tin_snips")
			"snip":
				# Schneiden: Hand nach vorne, zweimal kräftig zudrücken
				var f := smoothstep(0.0, 0.25, p) * (1.0 - smoothstep(0.75, 1.0, p))
				pos += Vector3(-0.08, 0.07, -0.12) * f
				rot += Vector3(2, 8, 0) * f
				var squeeze := 0.5 - 0.5 * cos(p * TAU * 2.0)
				snips_open = 1.0 - squeeze * f
				pos.z -= 0.012 * squeeze * f
				rot.z -= 3.0 * squeeze * f
			"drink":
				# Deckel aufklappen, Flasche an den Mund, in Schlucken kippen, absetzen
				cap_open = _bell(p, 0.03, 0.16, 0.82, 0.95)
				var f := _bell(p, 0.12, 0.38, 0.74, 0.96)
				var tip := smoothstep(0.3, 0.7, p) * (1.0 - smoothstep(0.76, 0.92, p))
				var gulp := sin(maxf(p - 0.4, 0.0) * TAU * 4.5) * _bell(p, 0.4, 0.46, 0.7, 0.76)
				pos = pos.lerp(Vector3(0.09, -0.24, -0.26), f) + Vector3(0, 0.006, 0.004) * gulp
				rot = rot.lerp(Vector3(36, 26, 14), f) + Vector3(26, 0, 4) * tip + Vector3(3, 0, 0) * gulp
				level = 1.0 - 0.45 * smoothstep(0.42, 0.74, p)
				if p >= 0.6 and not _action_hit_done:
					_action_hit_done = true
					_use_equipped()
			"eat":
				# Deckel aufziehen (Dose), zum Mund führen, zwei Bissen, absetzen
				lid_open = _bell(p, 0.02, 0.2, 0.9, 0.98)
				var f := _bell(p, 0.14, 0.4, 0.74, 0.96)
				var bite := maxf(sin(maxf(p - 0.42, 0.0) * TAU * 3.2), 0.0) * _bell(p, 0.42, 0.46, 0.7, 0.76)
				pos = pos.lerp(Vector3(0.085, -0.225, -0.26), f) + Vector3(-0.004, 0.012, 0.012) * bite
				rot = rot.lerp(Vector3(34, 26, 16), f) + Vector3(10, 0, 4) * bite
				if p >= 0.6 and not _action_hit_done:
					_action_hit_done = true
					_use_equipped()
			"pour":
				# Kanne anheben und nach vorn kippen; solange die Maustaste gehalten wird, läuft es weiter
				if p > 0.6 and p < 0.7 and Input.is_action_pressed("attack") and delta > 0.0 and _pour_wet \
						and not player.input_locked and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
					_action_t = 0.6 * _action_len
				var f := _bell(p, 0.0, 0.22, 0.72, 1.0)
				# gekippt wird im Handgelenk – der Unterarm bleibt unten im Bild
				pos += Vector3(-0.05, 0.08, -0.02) * f + Vector3(0, sin(_time * 5.0) * 0.003, 0) * f
				rot += Vector3(-8, 10, -4) * f + Vector3(sin(_time * 3.1) * 1.2, 0, 0) * f
				wrist.x -= 36.0 * f
				pouring = _pour_wet and p > 0.17 and p < 0.8
			"fill":
				# Kanne nach vorn unten ins Wasser tauchen und auf die Seite legen, volllaufen lassen, herausheben
				var f := _bell(p, 0.0, 0.25, 0.62, 0.9)
				var bob := sin(p * TAU * 5.0) * _bell(p, 0.25, 0.3, 0.6, 0.66)
				pos += Vector3(-0.1, -0.07, -0.1) * f + Vector3(0, 0.006, 0) * bob
				rot += Vector3(-6, 16, 10) * f + Vector3(0, 0, 3) * bob
				wrist.x -= 22.0 * f
				wrist.z += 52.0 * f
				# schwer geworden: sackt beim Herausheben kurz nach
				pos.y -= 0.03 * _bell(p, 0.66, 0.8, 0.84, 1.0)
				if p >= 0.72 and not _action_hit_done:
					_action_hit_done = true
					_drip()
		if p >= 1.0:
			_action = ""
	_right.position = pos
	_right.rotation_degrees = rot
	if _r_wrist:
		_r_wrist.rotation_degrees = wrist
	if _r_item == null:
		if _r_hand:
			_r_hand.set_pose(finger)
		_set_pour(false)
		return
	# bewegliche Teile des Gegenstands
	var parts: Dictionary = _r_item.get_meta("parts", {})
	if parts.has("jaw_a"):
		HandItems.snips_open(_r_item, snips_open)
		# die Finger folgen den Griffen
		finger = HandRig.mix(HandRig.grip(0.0235, 1.0), _r_pose, snips_open)
	if parts.has("cap"):
		(parts["cap"] as Node3D).rotation_degrees.z = 168.0 * cap_open
	if parts.has("water_full"):
		(parts["water"] as Node3D).scale.y = float(parts["water_full"]) * level
	if parts.has("lid"):
		(parts["lid"] as Node3D).rotation_degrees.x = 118.0 * lid_open
	if _right_kind == "watering_can":
		HandItems.can_level(_r_item, float(Supplies.can_water) / maxf(Supplies.config.watering_can_charges, 1))
	_r_hand.set_pose(finger)
	_set_pour(pouring)


## Essen/Trinken wirkt in der Mitte der Bewegung.
func _use_equipped() -> void:
	var id := Inventory.equipped()
	if id != "":
		Inventory.use(id)


## Diktiergerät: Spulen drehen sich, die rote Leuchte blinkt, die Taste ist gedrückt.
func _animate_dictaphone(delta: float) -> void:
	if _r_item == null:
		return
	var parts: Dictionary = _r_item.get_meta("parts", {})
	if _rec_led:
		_rec_led.emission_energy_multiplier = (3.0 if fmod(_rec_t, 1.0) < 0.6 else 0.5) if recording else 0.0
	if parts.has("rec"):
		(parts["rec"] as Node3D).position.x = 0.0339 - 0.002 * _rec_amount
	if recording:
		for k in 2:
			if parts.has("reel_%d" % k):
				(parts["reel_%d" % k] as Node3D).rotation.z -= delta * (2.4 if k == 0 else 3.1)


## Wasserstrahl aus der Brause an- und abstellen. Die Tropfen fallen in der Welt (nicht an der Hand hängend).
func _set_pour(on: bool) -> void:
	_flowing = on
	if not on:
		if _pour_fx:
			_pour_fx.emitting = false
		return
	var parts: Dictionary = _r_item.get_meta("parts", {})
	var rose := parts.get("rose") as Node3D
	if rose == null or not is_inside_tree():
		return
	if _pour_fx == null:
		var p := CPUParticles3D.new()
		p.name = "PourWater"
		p.amount = 170
		p.lifetime = 0.9
		p.local_coords = false
		p.spread = 13.0
		p.initial_velocity_min = 1.1
		p.initial_velocity_max = 1.7
		p.gravity = Vector3(0, -9.0, 0)
		p.scale_amount_min = 0.6
		p.scale_amount_max = 1.2
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.008, 0.03, 0.008)
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.72, 0.86, 0.96, 0.85)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.roughness = 0.1
		m.emission_enabled = true
		m.emission = Color(0.5, 0.65, 0.8)
		m.emission_energy_multiplier = 0.25
		mesh.material = m
		p.mesh = mesh
		p.particle_flag_align_y = true
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		p.emitting = false
		get_tree().current_scene.add_child(p)
		_pour_fx = p
	_pour_fx.global_position = rose.global_position
	_pour_fx.direction = rose.global_transform.basis.y.normalized()
	if not _pour_fx.emitting:
		_pour_fx.emitting = true
		SoundBank.play_at(get_tree().current_scene, "faucet", rose.global_position, -12.0, 1.35)


func _stop_pour() -> void:
	if _pour_fx:
		_pour_fx.emitting = false


## Ein paar Tropfen von der Kanne, wenn sie aus dem Wasser kommt.
func _drip() -> void:
	if _r_item == null or not is_inside_tree() or get_tree().current_scene == null:
		return
	Fx.burst(get_tree().current_scene, _r_item.global_position + Vector3(0, -0.1, 0), "water", Vector3.DOWN, 0.9)


func _exit_tree() -> void:
	if is_instance_valid(_pour_fx):
		_pour_fx.queue_free()


func _pose_left(delta: float = 0.0) -> void:
	var e := _left_out * _left_out
	_left.position = LEFT_REST + Vector3(0, -HIDE_DROP * e, 0) + Vector3(0, sin(_time * 1.7 + 1.0) * 0.0025, 0)
	_left.rotation_degrees = Vector3(-35.0 * e, 0, sin(_time * 1.1 + 0.6) * 0.5)
	if _hammer.visible:
		# Hammer etwas weiter ins Bild
		_left.position += Vector3(0.02, -0.03, -0.05)
		if _tap_t >= 0.0:
			# Hammerschläge: kurz ausholen, zuschlagen, zurückfedern
			_tap_t += delta
			var ph := fmod(_tap_t, TAP_TIME) / TAP_TIME
			var swing := 26.0 * smoothstep(0.0, 0.35, ph) * (1.0 - smoothstep(0.35, 0.55, ph)) \
					- 34.0 * smoothstep(0.38, 0.58, ph) * (1.0 - smoothstep(0.62, 1.0, ph))
			var elbow := Vector3(0.0, -0.06, 0.34)
			_left.rotation_degrees.x += swing
			_left.position += elbow - Basis.from_euler(Vector3(deg_to_rad(swing), 0.0, 0.0)) * elbow
			if _tap_t >= TAP_TIME * _tap_hits:
				_tap_t = -1.0
	_update_compass(delta)


## Kompassnadel: die rote Spitze zeigt immer nach Norden (in der Welt: -z, die Hütte schaut nach Süden).
## Sie pendelt wie eine echte Nadel nach; stört die Kreatur die Uhr, dreht sie durch.
func _update_compass(delta: float) -> void:
	if _compass == null or not _left.visible or not is_inside_tree():
		return
	var face := _compass.get_parent() as Node3D
	var n := face.global_transform.basis.orthonormalized().inverse() * Vector3(0, 0, -1)
	var target := atan2(-n.x, -n.z)
	if _compass_jam > 0.0:
		target += sin(_time * 9.0) * 2.4 + _time * 6.0
	if delta <= 0.0:
		_needle_angle = target
	else:
		var dt := minf(delta, 0.05)
		_needle_vel += (wrapf(target - _needle_angle, -PI, PI) * 60.0 - _needle_vel * 7.0) * dt
		_needle_angle = wrapf(_needle_angle + _needle_vel * dt, -PI, PI)
	_compass.rotation.y = _needle_angle
