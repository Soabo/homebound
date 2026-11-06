class_name HideSpot
extends Interactable
## Versteck: Kleiderschrank (Schlafzimmer) oder Spind (Schuppen).
## Draußen: [E] Tür öffnen, bei offener Tür [E] hineinstellen, [R] Tür schließen.
## Drinnen: [E] Tür auf/zu, bei offener Tür [R] heraustreten. Umsehen geht, gehen nicht.
## Bei geschlossener Tür ist man versteckt (die Kreatur sieht einen nicht) und blickt durch einen
## Schlitz (Schrank) bzw. Lamellen (Spind) auf Augenhöhe nach draußen.
## Die Tür schwenkt zur Seite mit dem Scharnier auf (style + hinge_right).

@export var style: String = "wardrobe"  ## "wardrobe" | "locker"
@export var size := Vector3(1.0, 2.1, 0.7)  ## Breite (x), Höhe, Tiefe (z); Front zeigt nach +z
@export var hinge_right: bool = true  ## Scharnier rechts (+x) – die Tür geht zu dieser Seite auf
@export var label: String = "Kleiderschrank"

var door_open: bool = false
var occupied: bool = false
var _door: Node3D
var _player: Player
var _stand_pos: Vector3
var _stand_rot: float
var _t: float = 0.0

const EYE := 1.6        ## Augenhöhe über dem Schrankboden
const WALL := 0.03


func _ready() -> void:
	add_to_group("hide_spot")
	match style:
		"locker":
			_build_locker()
		_:
			_build_wardrobe()
	# zum Anvisieren: die ganze Front
	var area := Area3D.new()
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(size.x, size.y, 0.3)
	cs.shape = sh
	cs.position = Vector3(0, size.y * 0.5, size.z * 0.5)
	area.add_child(cs)
	add_child(area)


# --- Modelle ------------------------------------------------------------

func _shell(mat: Material, trim: Material) -> void:
	var w := size.x
	var h := size.y
	var d := size.z
	BuildKit.box_mm(self, Vector3(-w * 0.5, 0.0, -d * 0.5), Vector3(w * 0.5, h, -d * 0.5 + WALL), mat, true)
	BuildKit.box_mm(self, Vector3(-w * 0.5, 0.0, -d * 0.5), Vector3(-w * 0.5 + WALL, h, d * 0.5), mat, true)
	BuildKit.box_mm(self, Vector3(w * 0.5 - WALL, 0.0, -d * 0.5), Vector3(w * 0.5, h, d * 0.5), mat, true)
	BuildKit.box_mm(self, Vector3(-w * 0.5, h - WALL, -d * 0.5), Vector3(w * 0.5, h, d * 0.5), mat, true)
	BuildKit.box_mm(self, Vector3(-w * 0.5, 0.0, -d * 0.5), Vector3(w * 0.5, 0.06, d * 0.5), trim, false)
	# innen ganz dunkel
	BuildKit.box_mm(self, Vector3(-w * 0.5 + WALL, 0.061, -d * 0.5 + WALL), Vector3(w * 0.5 - WALL, 0.07, d * 0.5 - 0.05),
			BuildKit.color_mat(Color(0.06, 0.05, 0.04), 0.9), false)


func _make_door(thick: float) -> Node3D:
	var pivot := Node3D.new()
	var sx := 1.0 if hinge_right else -1.0
	pivot.position = Vector3(sx * (size.x * 0.5 - WALL), 0.0, size.z * 0.5 - thick * 0.5)
	add_child(pivot)
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(size.x - WALL * 2.0, size.y - 0.12, thick)
	cs.shape = sh
	cs.position = Vector3(-sx * (size.x * 0.5 - WALL), size.y * 0.5, 0)
	body.add_child(cs)
	pivot.add_child(body)
	return pivot


## Holzschrank: Sockel, Kranzleiste, Füllungstür mit Sehschlitz auf Augenhöhe, Knauf, Kleiderstange mit Kleidung.
func _build_wardrobe() -> void:
	var wood := BuildKit.tex_mat("planks_v", 0.5, Color(0.95, 0.78, 0.6))
	var dark := BuildKit.tex_mat("planks_v", 0.5, Color(0.6, 0.45, 0.33))
	var brass := BuildKit.color_mat(Color(0.75, 0.6, 0.3), 0.35, 0.8)
	_shell(wood, dark)
	# Kranzleiste oben, Sockelleiste unten, kleine Füße
	BuildKit.box_mm(self, Vector3(-size.x * 0.5 - 0.03, size.y, -size.z * 0.5), Vector3(size.x * 0.5 + 0.03, size.y + 0.07, size.z * 0.5 + 0.04), dark, false)
	BuildKit.box_mm(self, Vector3(-size.x * 0.5 - 0.015, 0.0, size.z * 0.5 - 0.02), Vector3(size.x * 0.5 + 0.015, 0.1, size.z * 0.5 + 0.02), dark, false)
	# Kleiderstange mit Hemden und einem Mantel (dicht an der Rückwand, man steht davor)
	var rod_z := -size.z * 0.5 + 0.14
	BuildKit.cylinder(self, 0.012, size.x - 0.08, Vector3(0, size.y - 0.22, rod_z), brass, false, Vector3(0, 0, 90), -1.0, 6)
	var cloth := [Color(0.35, 0.4, 0.5), Color(0.55, 0.5, 0.42), Color(0.25, 0.28, 0.25), Color(0.6, 0.35, 0.3)]
	for k in 4:
		var x := -size.x * 0.5 + 0.18 + k * 0.2
		BuildKit.box(self, Vector3(0.05, 0.85 + (k % 2) * 0.3, 0.3), Vector3(x, size.y - 0.7 - (k % 2) * 0.15, rod_z + 0.02),
				BuildKit.tex_mat("fabric", 0.3, cloth[k] * 2.0), false, Vector3(0, 8.0 - k * 5.0, 0))
	# Tür: Rahmen + zwei Füllungen, dazwischen der Sehschlitz auf Augenhöhe
	var t := 0.035
	_door = _make_door(t)
	var sx := 1.0 if hinge_right else -1.0
	var cx := -sx * (size.x * 0.5 - WALL)  # Mitte der Tür relativ zum Scharnier
	var dw := size.x - WALL * 2.0
	var slit_lo := EYE - 0.03
	var slit_hi := EYE + 0.03
	BuildKit.box_mm(_door, Vector3(cx - dw * 0.5, 0.06, -t * 0.5), Vector3(cx + dw * 0.5, slit_lo, t * 0.5), wood, false)
	BuildKit.box_mm(_door, Vector3(cx - dw * 0.5, slit_hi, -t * 0.5), Vector3(cx + dw * 0.5, size.y - 0.06, t * 0.5), wood, false)
	# seitliche Stege am Schlitz (sonst wäre die Tür zweigeteilt)
	for e: float in [-1.0, 1.0]:
		BuildKit.box_mm(_door, Vector3(cx + e * dw * 0.5 - (0.08 if e > 0 else 0.0), slit_lo, -t * 0.5), Vector3(cx + e * dw * 0.5 + (0.0 if e > 0 else 0.08), slit_hi, t * 0.5), wood, false)
	# Füllungen (etwas dunkler, leicht vertieft)
	for r: Vector2 in [Vector2(0.18, slit_lo - 0.12), Vector2(slit_hi + 0.12, size.y - 0.2)]:
		BuildKit.box_mm(_door, Vector3(cx - dw * 0.5 + 0.1, r.x, t * 0.5), Vector3(cx + dw * 0.5 - 0.1, r.y, t * 0.5 + 0.012), dark, false)
	# Knauf auf der Öffnungsseite
	BuildKit.sphere(_door, 0.025, Vector3(cx - sx * (dw * 0.5 - 0.08), 1.05, t * 0.5 + 0.03), brass, Vector3.ONE, 8)
	BuildKit.cylinder(_door, 0.008, 0.03, Vector3(cx - sx * (dw * 0.5 - 0.08), 1.05, t * 0.5 + 0.012), brass, false, Vector3(90, 0, 0), -1.0, 6)


## Metallspind: graugrün lackiert, Lüftungslamellen auf Augenhöhe, Griff und Namensschild.
func _build_locker() -> void:
	var paint := BuildKit.tex_mat("metal", 0.4, Color(0.55, 0.65, 0.6), 0.5)
	var dark := BuildKit.color_mat(Color(0.12, 0.13, 0.13), 0.6, 0.5)
	var steel := BuildKit.color_mat(Color(0.7, 0.7, 0.72), 0.3, 0.9)
	_shell(paint, dark)
	# innen leer – keine Fächer, damit man aufrecht drinstehen kann
	var t := 0.025
	_door = _make_door(t)
	var sx := 1.0 if hinge_right else -1.0
	var cx := -sx * (size.x * 0.5 - WALL)
	var dw := size.x - WALL * 2.0
	# Türblech mit Aussparung für die Lamellen
	var lo := EYE - 0.14
	var hi := EYE + 0.1
	BuildKit.box_mm(_door, Vector3(cx - dw * 0.5, 0.06, -t * 0.5), Vector3(cx + dw * 0.5, lo, t * 0.5), paint, false)
	BuildKit.box_mm(_door, Vector3(cx - dw * 0.5, hi, -t * 0.5), Vector3(cx + dw * 0.5, size.y - 0.06, t * 0.5), paint, false)
	for e: float in [-1.0, 1.0]:
		BuildKit.box_mm(_door, Vector3(cx + e * dw * 0.5 - (0.1 if e > 0 else 0.0), lo, -t * 0.5), Vector3(cx + e * dw * 0.5 + (0.0 if e > 0 else 0.1), hi, t * 0.5), paint, false)
	# schräge Lamellen mit Spalten dazwischen
	var n := 6
	for k in n:
		var y := lo + 0.02 + k * (hi - lo - 0.02) / float(n)
		BuildKit.box(_door, Vector3(dw - 0.2, 0.012, 0.035), Vector3(cx, y + 0.012, 0), paint, false, Vector3(-35, 0, 0))
	# Lamellen auch unten (Lüftung) – nur Optik
	for k in 4:
		BuildKit.box(_door, Vector3(dw - 0.24, 0.008, 0.01), Vector3(cx, 0.2 + k * 0.04, t * 0.5 + 0.004), dark, false)
	# Griff, Schloss, Namensschild
	BuildKit.box(_door, Vector3(0.02, 0.14, 0.03), Vector3(cx - sx * (dw * 0.5 - 0.06), 1.05, t * 0.5 + 0.02), steel, false)
	BuildKit.cylinder(_door, 0.012, 0.01, Vector3(cx - sx * (dw * 0.5 - 0.06), 1.2, t * 0.5 + 0.006), steel, false, Vector3(90, 0, 0), -1.0, 8)
	BuildKit.box(_door, Vector3(0.12, 0.04, 0.005), Vector3(cx, size.y - 0.25, t * 0.5 + 0.003), BuildKit.color_mat(Color(0.85, 0.82, 0.7), 0.6), false)


# --- Bedienung ----------------------------------------------------------

func get_prompt(_p: Node) -> String:
	if occupied:
		return ""
	if not door_open:
		return "%s  [E] Tür öffnen" % label
	return "%s  [E] Hineinstellen" % label


func get_secondary_prompt(_p: Node) -> String:
	return "[R] Tür schließen" if door_open and not occupied else ""


func interact(p: Node) -> void:
	if occupied:
		return
	if not door_open:
		set_door(true)
	else:
		_enter(p as Player)


func secondary_interact(_p: Node) -> void:
	if not occupied and door_open:
		set_door(false)


func set_door(open: bool) -> void:
	if open == door_open:
		return
	door_open = open
	var sx := 1.0 if hinge_right else -1.0
	create_tween().tween_property(_door, "rotation_degrees:y", sx * 100.0 if open else 0.0, 0.45).set_trans(Tween.TRANS_SINE)
	var id := "door_open" if open else "door_close"
	if style == "locker":
		# Blechtür: metallischer Klang
		SoundBank.play_at(self, "collect_metal", global_position + Vector3(0, 1.0, size.z * 0.5), -3.0 if open else -1.0, 1.1 if open else 0.95)
	else:
		SoundBank.play_at(self, id, global_position + Vector3(0, 1.0, size.z * 0.5), -4.0)
	EventBus.noise_made.emit(global_position, 4.0)


## Ist der Spieler hier drin UND die Tür zu?
func hides_player() -> bool:
	return occupied and not door_open


func _enter(p: Player) -> void:
	if p == null:
		return
	_player = p
	occupied = true
	_stand_pos = p.global_position
	_stand_rot = p.rotation.y
	p.velocity = Vector3.ZERO
	p.set_physics_process(false)
	p.look_only = true
	p.input_locked = true
	p.global_position = to_global(Vector3(0, 0.07, -size.z * 0.5 + 0.32))
	# Blick zur Tür hinaus
	var fwd := global_transform.basis.z
	p.rotation.y = atan2(fwd.x, fwd.z) + PI
	p.head.position.y = EYE - 0.07 + 0.07
	p.head.rotation.x = 0.0
	p.hidden_in = self
	EventBus.interaction_prompt_changed.emit("[E] Tür schließen    [R] Heraustreten")


func _leave() -> void:
	if _player == null:
		return
	occupied = false
	_player.hidden_in = null
	_player.look_only = false
	_player.input_locked = false
	_player.global_position = to_global(Vector3(0, 0.07, size.z * 0.5 + 0.55))
	_player.set_physics_process(true)
	_player = null


func _unhandled_input(event: InputEvent) -> void:
	if not occupied or _player == null or get_tree().paused:
		return
	if event.is_action_pressed("interact") and not event.is_echo():
		set_door(not door_open)
		EventBus.interaction_prompt_changed.emit("[E] Tür öffnen" if not door_open else "[E] Tür schließen    [R] Heraustreten")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact_secondary") and not event.is_echo():
		if not door_open:
			set_door(true)
		_leave()
		EventBus.interaction_prompt_changed.emit("")
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if occupied and _player and GameState.dead:
		_leave()
	# Im Schrank: Atmen wird hörbar, wenn die Kreatur nah ist (Spannung)
	_t += delta
