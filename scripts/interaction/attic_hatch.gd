class_name AtticHatch
extends Interactable
## Dachbodenluke mit Zugleiter in der Werkstattdecke.
## Unten: [E] Leiter herunterziehen, dann [E] hochklettern / [R] Leiter hochschieben.
## Oben: [E] hinunterklettern / [R] Leiter hochziehen (bzw. [E] Leiter herunterlassen, wenn sie oben ist).
## Wer mit heruntergelassener Leiter schläft, lässt einen zweiten Weg ins Haus offen (ThreatDirector "attic").

## Öffnung in der Decke (Draufsicht x/z, Hütten-Koordinaten): x 3.75..4.55, z -0.45..0.65
const HOLE := Rect2(Vector2(3.75, -0.45), Vector2(0.8, 1.1))
## Fuß der Leiter im Raum (Weltkoordinaten) – dort landet auch, was von oben herunterkommt
const FOOT := Vector3(4.15, Cabin.FLOOR_Y, 1.55)
const TOP_STAND := Vector3(3.3, Cabin.WALL_TOP + 0.11, 0.1)

## Ist die Leiter gerade unten? (für Bett und ThreatDirector)
static var down_now: bool = false

var down: bool = false
var _lid: Node3D
var _ladder: Node3D
var _lid_cs: CollisionShape3D
var _rail_cs: CollisionShape3D
var _ladder_cs: CollisionShape3D
var _cord: Node3D


func _ready() -> void:
	add_to_group("persistent")
	add_to_group("attic_hatch")
	var c := HOLE.get_center()
	position = Vector3(c.x, Cabin.WALL_TOP, c.y)
	var hw := HOLE.size.x * 0.5
	var hd := HOLE.size.y * 0.5
	var wood := BuildKit.tex_mat("planks_h", 0.6, Color(0.7, 0.62, 0.55))
	var dark := BuildKit.tex_mat("planks_h", 0.6, Color(0.42, 0.36, 0.32))
	# Rahmen um die Öffnung (unten an der Decke)
	for s: float in [-1.0, 1.0]:
		BuildKit.box(self, Vector3(HOLE.size.x + 0.12, 0.05, 0.06), Vector3(0, -0.02, s * (hd + 0.03)), dark, false)
		BuildKit.box(self, Vector3(0.06, 0.05, HOLE.size.y), Vector3(s * (hw + 0.03), -0.02, 0), dark, false)
	# Deckel am Scharnier (Südkante)
	_lid = Node3D.new()
	_lid.position = Vector3(0, 0, hd)
	add_child(_lid)
	BuildKit.box(_lid, Vector3(HOLE.size.x - 0.02, 0.05, HOLE.size.y - 0.02), Vector3(0, 0.04, -hd), wood, false)
	BuildKit.box(_lid, Vector3(0.12, 0.03, 0.05), Vector3(0, 0.0, -HOLE.size.y + 0.12), BuildKit.color_mat(Color(0.2, 0.2, 0.2), 0.5, 0.6), false)
	# Zugschnur am Deckel
	_cord = Node3D.new()
	_lid.add_child(_cord)
	BuildKit.cylinder(_cord, 0.006, 0.45, Vector3(0, -0.22, -HOLE.size.y + 0.12), BuildKit.color_mat(Color(0.75, 0.7, 0.6)), false, Vector3.ZERO, -1.0, 4)
	BuildKit.sphere(_cord, 0.025, Vector3(0, -0.46, -HOLE.size.y + 0.12), wood, Vector3.ONE, 6)
	# Leiter: schräg von der Südkante zum Boden
	_ladder = Node3D.new()
	_ladder.position = Vector3(0, -0.02, hd - 0.08)
	add_child(_ladder)
	var drop := Cabin.WALL_TOP - Cabin.FLOOR_Y
	var run := FOOT.z - (c.y + hd - 0.08)
	var length := sqrt(drop * drop + run * run)
	_ladder.rotation.x = -atan2(run, drop)
	for s: float in [-1.0, 1.0]:
		BuildKit.box(_ladder, Vector3(0.05, length, 0.08), Vector3(s * 0.21, -length * 0.5, 0), wood, false)
	var k := 0.25
	while k < length - 0.1:
		BuildKit.box(_ladder, Vector3(0.38, 0.03, 0.06), Vector3(0, -k, 0), dark, false)
		k += 0.28
	# Feste Körper: Deckel zu = Fläche; Leiter unten = Geländer oben am Loch + Leiter selbst
	_lid_cs = LadderClimb.guard_box(self, Vector3(HOLE.size.x, 0.1, HOLE.size.y), Vector3(0, 0.05, 0))
	_rail_cs = LadderClimb.guard_box(self, Vector3(HOLE.size.x, 1.0, HOLE.size.y), Vector3(0, 0.6, 0))
	_ladder_cs = LadderClimb.guard_box(_ladder, Vector3(0.5, length, 0.1), Vector3(0, -length * 0.5, 0))
	_apply(false)
	GameState.restore(self)
	# zugenagelt nur für eine Belagerungsnacht
	EventBus.siege_finished.connect(func(_ok: bool) -> void:
		var n := get_node_or_null("Nailed")
		if n:
			n.queue_free())


func persist_key() -> String:
	return "attic_hatch"


func _apply(animate: bool) -> void:
	down_now = down
	_lid_cs.disabled = down
	_rail_cs.disabled = not down
	_ladder_cs.disabled = not down
	_cord.visible = not down
	var lid_rot := -100.0 if down else 0.0
	if animate:
		var tw := create_tween().set_trans(Tween.TRANS_SINE)
		tw.tween_property(_lid, "rotation_degrees:x", lid_rot, 0.5)
		if down:
			_ladder.visible = true
			_ladder.scale = Vector3(1, 0.25, 1)
			tw.tween_property(_ladder, "scale", Vector3.ONE, 0.55)
		else:
			tw.parallel().tween_property(_ladder, "scale", Vector3(1, 0.2, 1), 0.4)
			tw.tween_callback(func() -> void: _ladder.visible = false)
		SoundBank.play_at(get_parent(), "door_open" if down else "door_close", global_position, -6.0, 0.75)
		SoundBank.play_at(get_parent(), "floor_creak", global_position + Vector3(0, -1.2, 0.8), -8.0, 1.2)
	else:
		_lid.rotation_degrees.x = lid_rot
		_ladder.visible = down
		_ladder.scale = Vector3.ONE


func _up_there(p: Node3D) -> bool:
	return p.global_position.y > Cabin.WALL_TOP - 0.2


## Belagerungsnacht: etwas drückt von oben gegen die Luke
func _siege_attic() -> bool:
	return SiegeNight.current != null and SiegeNight.current.active("attic") and not SiegeNight.current.nailed


func bump() -> void:
	var tw := create_tween()
	tw.tween_property(_lid, "rotation_degrees:x", -6.0, 0.08)
	tw.tween_property(_lid, "rotation_degrees:x", -100.0 if down else 0.0, 0.2)
	SoundBank.play_at(get_parent(), "thud", global_position, -2.0, 0.7)
	Fx.burst(get_parent(), global_position + Vector3(0, -0.05, 0), "dust", Vector3.DOWN, 0.5)


func show_nailed() -> void:
	if get_node_or_null("Nailed"):
		return
	var n := Node3D.new()
	n.name = "Nailed"
	add_child(n)
	var plank := BuildKit.tex_mat("planks_h", 0.6, Color(0.8, 0.7, 0.55))
	for s: float in [-0.25, 0.25]:
		BuildKit.box(n, Vector3(1.05, 0.03, 0.14), Vector3(0, -0.04, s), plank, false, Vector3(0, 12.0 * signf(s), 0))


func get_prompt(player: Node) -> String:
	var p := player as Node3D
	if p == null:
		return ""
	if _siege_attic() and not _up_there(p) and not down:
		return "Es drückt gegen die Luke (%d %%)  [E] zuhalten" % int(SiegeNight.current.pressure("attic") * 100.0)
	if _up_there(p):
		return "[E] Hinunterklettern" if down else "[E] Leiter herunterlassen"
	return "[E] Auf den Dachboden klettern" if down else "Dachbodenluke  [E] Leiter herunterziehen"


func get_secondary_prompt(player: Node) -> String:
	if _siege_attic() and player and not _up_there(player as Node3D) and not down:
		return "[R] zunageln (2 Bretter)"
	if not down or player == null:
		return ""
	return "[R] Leiter hochziehen" if _up_there(player as Node3D) else "[R] Leiter hochschieben"


func interact(player: Node) -> void:
	var p := player as Player
	if p == null:
		return
	if _siege_attic() and not _up_there(p) and not down:
		SiegeNight.current.attic_hold()
		bump()
		return
	if not down:
		if SiegeNight.current and SiegeNight.current.nailed:
			EventBus.notify("Die Luke ist zugenagelt.", 2.0)
			return
		set_down(true)
		return
	var hole := Vector3(global_position.x, Cabin.WALL_TOP + 0.11, global_position.z + 0.1)
	var high := Vector3(FOOT.x, Cabin.FLOOR_Y + 1.75, FOOT.z - 0.7)
	var low := Vector3(FOOT.x, Cabin.FLOOR_Y + 0.15, FOOT.z - 0.05)
	var stand := Vector3(FOOT.x, Cabin.FLOOR_Y, FOOT.z + 0.4)
	if _up_there(p):
		LadderClimb.climb(self, p, [TOP_STAND + Vector3(0.1, 0, 0), hole, high, low, stand], Vector3(FOOT.x, 0, -2.0), -0.35)
	else:
		LadderClimb.climb(self, p, [stand, low, high, hole, TOP_STAND], Vector3(FOOT.x, 0, -2.0), 0.2)
		Tasks.flag("attic_visited")


func secondary_interact(player: Node) -> void:
	if _siege_attic() and player and not _up_there(player as Node3D) and not down:
		if SiegeNight.current.attic_nail():
			show_nailed()
		else:
			EventBus.notify("Dafür brauchst du 2 Bretter.", 2.0)
		return
	if down:
		set_down(false)


func set_down(v: bool) -> void:
	if v == down:
		return
	down = v
	_apply(true)


func get_state() -> Dictionary:
	return {"down": down}


func set_state(s: Dictionary) -> void:
	down = bool(s.get("down", false))
	if _lid:
		_apply(false)
