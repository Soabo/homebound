class_name HideSpot
extends Interactable
## Versteck (Christian 24.11.2026: alle Verstecke funktionieren gleich).
## [E] hinein: kurze Bewegung – die Tür/der Vorhang/der Deckel geht auf, man kriecht/steigt hinein, er geht wieder zu.
## [E] heraus: dasselbe rückwärts. Von Haus aus sind Türen geschlossen.
## Drinnen: ein wenig bewegen (WASD im kleinen Raum `move`), lehnen (Y/X), ducken, Uhrlicht an/aus – und man gilt als
## versteckt (`hides_player`), solange nichts aufgerissen ist. Gegner finden einen nicht im ersten Moment
## (Verstecke lernen, HideHunt).
## Arten (style): wardrobe (Kleiderschrank, Sehschlitz) · locker (Spind, Lamellen) · curtain (Dusche, Vorhang)
##   · chest (Truhe, Sehschlitz) · fort (Deckenhöhle in der Ecke) · open (hinter/unter Möbeln, ohne Tür).
## Lage: die Vorderseite (wo man hinein- und herausgeht) zeigt nach +z.

@export var style: String = "wardrobe"
@export var size := Vector3(1.0, 2.1, 0.7)   ## Schrank/Spind/Truhe/Dusche: Breite (x), Höhe, Tiefe (z)
@export var hinge_right: bool = true         ## Scharnier rechts (+x) – die Tür geht zu dieser Seite auf
@export var label: String = "Kleiderschrank"
@export var anchor := Vector3.ZERO           ## Füße im Versteck (lokal)
@export var eye: float = 1.55                ## Augenhöhe im Versteck über den Füßen
@export var crouch_drop: float = 0.35        ## so viel tiefer beim Ducken
@export var move := Vector2(0.18, 0.12)      ## so weit kann man sich drinnen bewegen (± x, ± z, lokal)
@export var face := Vector3(0, 0, 1)         ## Blickrichtung beim Hineingehen (lokal)
@export var exit_dist: float = 0.75          ## so weit vor der Vorderseite steht man nach dem Herauskommen
@export var exit_dir := Vector3.ZERO         ## wohin man hinausgeht (lokal, 0 = Blickrichtung) – z. B. seitlich am Stuhl vorbei
@export var area_size := Vector3.ZERO        ## Zielfläche zum Anvisieren (0 = Vorderseite)
@export var area_center := Vector3.ZERO

var door_open: bool = false
var occupied: bool = false   ## man ist drin (auch während der Bewegung hinein/heraus)
var settled: bool = false    ## ganz drin, die Bewegung ist vorbei
var _door: Node3D
var _curtain: Array[Node3D] = []
var _player: Player
var _busy: Tween

const EYE := 1.6        ## Augenhöhe am Sehschlitz (Schrank/Spind)
const WALL := 0.03
const ENTER_TIME := 0.6
const DOOR_TIME := 0.32


func _ready() -> void:
	add_to_group("hide_spot")
	match style:
		"locker":
			_build_locker()
		"curtain":
			_build_curtain()
			door_open = true   # der Duschvorhang hängt offen; zugezogen wird er beim Hineingehen
		"chest":
			_build_chest()
		"fort":
			_build_fort()
		"open":
			pass
		_:
			_build_wardrobe()
	BuildKit.localize_materials.call_deferred(self)
	var area := Area3D.new()
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	if area_size == Vector3.ZERO:
		sh.size = Vector3(size.x, size.y, 0.3)
		cs.position = Vector3(0, size.y * 0.5, size.z * 0.5)
	else:
		sh.size = area_size
		cs.position = area_center
	cs.shape = sh
	area.add_child(cs)
	add_child(area)


func has_door() -> bool:
	return style in ["wardrobe", "locker", "curtain", "chest", "fort"]


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




## Dusche: Leinenvorhang an zwei Stangen (vorn + Seite). Offen ist er in der Ecke zusammengeschoben.
const CURTAIN_STRIPS := 12
func _build_curtain() -> void:
	var linen := BuildKit.tex_mat("fabric", 0.3, Color(1.35, 1.25, 1.05))
	for k in CURTAIN_STRIPS:
		var strip := Node3D.new()
		add_child(strip)
		BuildKit.box(strip, Vector3(0.23, size.y - 0.55, 0.012), Vector3(0, (size.y - 0.55) * 0.5 + 0.5, 0), linen, false)
		_curtain.append(strip)
	_place_curtain(0.0)


## Lage der Vorhangbahnen: 0 = offen (zusammengeschoben an der Wand links vorn), 1 = zu (vorn + rechte Seite)
func _place_curtain(t: float) -> void:
	var w := size.x
	var d := size.z
	var path := w + d   # vorn von links nach rechts, dann die rechte Seite nach hinten
	for k in _curtain.size():
		var f := float(k) / float(_curtain.size() - 1)
		var open_s := f * 0.28
		var s := lerpf(open_s, f * path, t)
		var pos: Vector3
		var rot := 0.0
		if s <= w:
			pos = Vector3(-w * 0.5 + s, 0, d * 0.5 + (0.02 if k % 2 == 0 else -0.01))
			rot = (k % 2) * 24.0 - 12.0 if t < 0.5 else (k % 2) * 10.0 - 5.0
		else:
			pos = Vector3(w * 0.5 + (0.02 if k % 2 == 0 else -0.01), 0, d * 0.5 - (s - w))
			rot = 90.0 + ((k % 2) * 10.0 - 5.0)
		_curtain[k].position = pos
		_curtain[k].rotation_degrees.y = rot


## Alte Truhe (Dachboden): Eisenbeschläge, Deckel klappt nach hinten auf, Sehschlitz vorn auf Augenhöhe.
func _build_chest() -> void:
	var wood := BuildKit.tex_mat("planks_h", 0.5, Color(0.62, 0.42, 0.28))
	var iron := BuildKit.color_mat(Color(0.16, 0.15, 0.14), 0.6, 0.6)
	var w := size.x
	var h := size.y
	var d := size.z
	var t := 0.04
	var slit := eye
	# Boden, Rückwand, Seiten; Vorderwand mit Schlitz
	BuildKit.box_mm(self, Vector3(-w * 0.5, 0, -d * 0.5), Vector3(w * 0.5, 0.05, d * 0.5), wood, false)
	BuildKit.box_mm(self, Vector3(-w * 0.5, 0, -d * 0.5), Vector3(w * 0.5, h, -d * 0.5 + t), wood, true)
	for sx: float in [-1.0, 1.0]:
		BuildKit.box_mm(self, Vector3(sx * w * 0.5 - (t if sx > 0 else 0.0), 0, -d * 0.5), Vector3(sx * w * 0.5 + (0.0 if sx > 0 else t), h, d * 0.5), wood, true)
	BuildKit.box_mm(self, Vector3(-w * 0.5, 0, d * 0.5 - t), Vector3(w * 0.5, slit - 0.025, d * 0.5), wood, true)
	BuildKit.box_mm(self, Vector3(-w * 0.5, slit + 0.025, d * 0.5 - t), Vector3(w * 0.5, h, d * 0.5), wood, true)
	for sx: float in [-1.0, 1.0]:
		BuildKit.box_mm(self, Vector3(sx * w * 0.5 - (0.2 if sx > 0 else 0.0), slit - 0.03, d * 0.5 - t), Vector3(sx * w * 0.5 + (0.0 if sx > 0 else 0.2), slit + 0.03, d * 0.5), wood, false)
	# Beschläge
	for sx: float in [-0.42, 0.42]:
		BuildKit.box(self, Vector3(0.05, h, 0.012), Vector3(sx * w, h * 0.5, d * 0.5 + 0.006), iron, false)
	BuildKit.box(self, Vector3(w + 0.01, 0.04, 0.012), Vector3(0, 0.12, d * 0.5 + 0.006), iron, false)
	# Deckel: Scharnier hinten oben, klappt nach hinten auf
	_door = Node3D.new()
	_door.position = Vector3(0, h, -d * 0.5)
	add_child(_door)
	BuildKit.box_mm(_door, Vector3(-w * 0.5 - 0.02, 0, 0), Vector3(w * 0.5 + 0.02, 0.06, d + 0.02), wood, true)
	for sx: float in [-0.42, 0.42]:
		BuildKit.box(_door, Vector3(0.05, 0.012, d + 0.03), Vector3(sx * w, 0.066, (d + 0.02) * 0.5), iron, false)
	BuildKit.box(_door, Vector3(0.1, 0.08, 0.02), Vector3(0, -0.02, d + 0.03), iron, false)


## Deckenhöhle in der Kinderzimmer-Ecke: eine Wolldecke über die Umzugskisten bis zur Wand, vorn eine Klappe.
func _build_fort() -> void:
	var blanket := BuildKit.tex_mat("blanket", 0.6)
	var w := size.x
	var h := size.y
	var d := size.z
	# Dach (leicht durchhängend) und Rückseite
	BuildKit.box(self, Vector3(w + 0.1, 0.02, d + 0.05), Vector3(0, h, 0), blanket, false, Vector3(2.0, 0, 0))
	BuildKit.box(self, Vector3(0.02, h, d), Vector3(-w * 0.5 - 0.04, h * 0.5, 0), blanket, false, Vector3(0, 0, -4.0))
	# Kissen und Taschenlampe drinnen, ein Stofftier
	BuildKit.box(self, Vector3(0.4, 0.1, 0.3), Vector3(-0.1, 0.05, -d * 0.3), BuildKit.tex_mat("fabric", 0.4, Color(1.7, 1.4, 1.5)), false)
	BuildKit.cylinder(self, 0.025, 0.14, Vector3(0.2, 0.03, -d * 0.35), BuildKit.color_mat(Color(0.8, 0.2, 0.15), 0.5), false, Vector3(0, 30, 90), -1.0, 8)
	# Klappe vorn: hängt vom Dach herab, wird beim Hineinkriechen angehoben
	_door = Node3D.new()
	_door.position = Vector3(0, h, d * 0.5)
	add_child(_door)
	BuildKit.box(_door, Vector3(w + 0.1, h - 0.06, 0.02), Vector3(0, -(h - 0.06) * 0.5, 0), blanket, false)


# --- Bedienung ----------------------------------------------------------

func get_prompt(_p: Node) -> String:
	if _busy and _busy.is_valid():
		return ""
	if occupied:
		return "[E] Versteck verlassen"
	return "%s  [E] Verstecken" % label


func interact(p: Node) -> void:
	if not (p is Player) or (_busy and _busy.is_valid()) or GameState.dead:
		return
	if occupied:
		exit(p as Player)
	else:
		enter(p as Player)


## Wo die Füße im Versteck stehen (Welt), mit dem kleinen Spielraum drinnen.
func anchor_global(offset: Vector2 = Vector2.ZERO) -> Vector3:
	return to_global(anchor + Vector3(clampf(offset.x, -move.x, move.x), 0, clampf(offset.y, -move.y, move.y)))


func _yaw_out() -> float:
	var f := (global_basis * face).normalized()
	return atan2(-f.x, -f.z)


## Hinein: Tür auf → hineinbewegen (Kopf auf Augenhöhe, Blick nach draußen) → Tür zu.
func enter(p: Player, instant: bool = false) -> void:
	_player = p
	occupied = true
	settled = false
	p.hidden_in = self
	p.hide_offset = Vector2.ZERO
	p.velocity = Vector3.ZERO
	p.input_locked = true
	var yaw := _yaw_out()
	if instant:
		_set_open(false, 0.0)
		p.global_position = anchor_global()
		p.rotation.y = yaw
		p.head.position.y = eye
		_settle(p)
		return
	_busy = create_tween()
	if has_door() and not door_open:
		_busy.tween_callback(func() -> void: _set_open(true, DOOR_TIME))
		_busy.tween_interval(DOOR_TIME * 0.7)
	_busy.tween_property(p, "global_position", anchor_global(), ENTER_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_busy.parallel().tween_property(p, "rotation:y", p.rotation.y + wrapf(yaw - p.rotation.y, -PI, PI), ENTER_TIME * 0.8).set_trans(Tween.TRANS_SINE)
	_busy.parallel().tween_property(p.head, "position:y", eye, ENTER_TIME).set_trans(Tween.TRANS_SINE)
	_busy.parallel().tween_property(p.head, "rotation:x", 0.0, ENTER_TIME * 0.8)
	if has_door():
		_busy.tween_callback(func() -> void: _set_open(false, DOOR_TIME))
		_busy.tween_interval(DOOR_TIME)
	_busy.tween_callback(func() -> void: _settle(p))
	EventBus.noise_made.emit(global_position, 3.0)


func _settle(p: Player) -> void:
	settled = true
	p.input_locked = false
	Tasks.flag("hidden")


## Heraus: Tür auf → herausbewegen (aufstehen) → Tür zu.
func exit(p: Player, instant: bool = false, fast: bool = false) -> void:
	if not occupied:
		return
	settled = false
	p.input_locked = true
	var out := front_point(exit_dist)
	out.y = global_position.y + anchor.y
	var stand := Player.STAND_HEIGHT - Player.EYE_OFFSET
	if instant:
		if p.global_position.distance_to(anchor_global(p.hide_offset)) < 1.5:
			p.global_position = out   # sonst wurde man schon woandershin versetzt – dort bleiben
		p.head.position.y = stand
		_set_open(false, 0.0)
		_release(p)
		return
	if _busy and _busy.is_valid():
		_busy.kill()
	var t := 0.25 if fast else ENTER_TIME
	_busy = create_tween()
	if has_door() and not door_open:
		_busy.tween_callback(func() -> void: _set_open(true, DOOR_TIME))
		_busy.tween_interval(DOOR_TIME * 0.7)
	_busy.tween_property(p, "global_position", out, t).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_busy.parallel().tween_property(p.head, "position:y", stand, t).set_trans(Tween.TRANS_SINE)
	_busy.tween_callback(func() -> void: _release(p))
	if has_door() and not fast and style != "curtain":
		_busy.tween_callback(func() -> void: _set_open(false, DOOR_TIME))
	EventBus.noise_made.emit(global_position, 3.0)


func _release(p: Player) -> void:
	occupied = false
	settled = false
	if p.hidden_in == self:
		p.hidden_in = null
	p.velocity = Vector3.ZERO
	p.input_locked = false


## Tür/Vorhang/Deckel/Klappe öffnen oder schließen (Bild + Klang). secs = 0: sofort.
func _set_open(open: bool, secs: float, flung: bool = false) -> void:
	var was := door_open
	door_open = open
	var sx := 1.0 if hinge_right else -1.0
	var tw: Tween = create_tween().set_trans(Tween.TRANS_BACK if flung else Tween.TRANS_SINE) if secs > 0.0 else null
	# Die Tür ist nur zu fest (sonst schiebt sie beim Zuschwenken den Spieler weg, der gerade herausgekommen ist)
	if open or secs <= 0.0:
		_door_solid(not open)
	elif tw:
		tw.finished.connect(func() -> void: _door_solid(not door_open))
	match style:
		"wardrobe", "locker":
			var a := (sx * (115.0 if flung else 100.0)) if open else 0.0
			if tw: tw.tween_property(_door, "rotation_degrees:y", a, secs)
			else: _door.rotation_degrees.y = a
		"chest":
			var a := (-115.0 if flung else -100.0) if open else 0.0
			if tw: tw.tween_property(_door, "rotation_degrees:x", a, secs)
			else: _door.rotation_degrees.x = a
		"fort":
			var a := -80.0 if open else 0.0
			if tw: tw.tween_property(_door, "rotation_degrees:x", a, secs)
			else: _door.rotation_degrees.x = a
		"curtain":
			var to := 0.0 if open else 1.0
			if tw: tw.tween_method(_place_curtain, 1.0 - to, to, secs)
			else: _place_curtain(to)
		_:
			if tw: tw.kill()
	if secs <= 0.0 or was == open:
		return
	var at := global_position + global_basis * Vector3(0, minf(size.y, 1.0), size.z * 0.5)
	match style:
		"locker":
			SoundBank.play_at(self, "collect_metal", at, -3.0 if open else -1.0, 1.1 if open else 0.95)
		"curtain", "fort":
			SoundBank.play_at(self, "rustle", at, -8.0, 1.3)
		"chest":
			SoundBank.play_at(self, "door_open" if open else "door_close", at, -4.0, 0.75)
		_:
			SoundBank.play_at(self, "door_open" if open else "door_close", at, -4.0)
	EventBus.noise_made.emit(global_position, 4.0)


func _door_solid(on: bool) -> void:
	if _door == null:
		return
	for n in _door.find_children("*", "CollisionShape3D", true, false):
		(n as CollisionShape3D).set_deferred("disabled", not on)


## Für Vorkommnisse (Schranktür geht nachts von selbst auf) und Tests.
func set_door(open: bool) -> void:
	if open == door_open or not has_door():
		return
	_set_open(open, DOOR_TIME)


## Etwas rüttelt von außen (HideHunt)
func rattle() -> void:
	SoundBank.play_at(self, "rattle" if has_door() else "scratch", global_position + global_basis * Vector3(0, 1.0, size.z * 0.5), 3.0, 0.9 if style == "locker" else 1.0)
	EventBus.screen_shake.emit(0.25)
	if door_open or _door == null:
		return
	for i in 7:
		if door_open or not is_inside_tree():
			return
		if style == "chest" or style == "fort":
			_door.rotation_degrees.x = randf_range(-4.0, -0.5)
		else:
			_door.rotation_degrees.y = (1.0 if hinge_right else -1.0) * randf_range(0.5, 4.0)
		await get_tree().create_timer(0.07).timeout
	if not door_open:
		_door.rotation = Vector3.ZERO


## Aufgerissen (HideHunt, Belagerung): die Tür fliegt auf, man wird herausgezerrt – nicht mehr versteckt.
func force_open() -> void:
	if has_door():
		_set_open(true, 0.18, true)
	SoundBank.play_at(self, "bang", global_position + Vector3(0, 1.0, 0), 4.0, 0.8)
	SoundBank.play_at(self, "wood_crack" if SoundBank.has_recording("wood_crack") else "door_open", global_position + Vector3(0, 1.0, 0), 2.0)
	if occupied and _player:
		exit(_player, false, true)


## Vor dem Versteck: wo etwas steht, das hineinsieht (Weltkoordinaten, auf dem Boden)
func front_point(dist: float = 1.0) -> Vector3:
	var f := (exit_dir if exit_dir != Vector3.ZERO else face).normalized()
	var depth := size.z * 0.5 - anchor.z if has_door() and style != "fort" and exit_dir == Vector3.ZERO else 0.35
	return to_global(Vector3(anchor.x, anchor.y, anchor.z) + f * (depth + dist))


## Versteckt: ganz drin und nichts offen.
func hides_player() -> bool:
	return occupied and settled and not door_open
