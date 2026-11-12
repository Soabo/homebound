class_name CellarHatch
extends Interactable
## Bodenluke in Stefanies Büro, darunter eine steile Leiter in den Keller.
## Der Teppich darüber lässt sich erst wegziehen, wenn der Story-Hinweis kam (Tasks-Merker "cellar_hint",
## data/story/story.json "beats"). Dann: [E] Luke öffnen, [E] hinuntersteigen / [R] Luke schließen, unten [E] hinauf.

## Öffnung im Büroboden (Draufsicht x/z): x 0.5..1.3, z -6.1..-5.3
const HOLE := Rect2(Vector2(0.5, -6.1), Vector2(0.8, 0.8))
const HINT_FLAG := "cellar_hint"

var rug_moved: bool = false
var open: bool = false
var _rug: Node3D
var _lid: Node3D
var _rug_cs: CollisionShape3D
var _lid_cs: CollisionShape3D
var _rail_cs: CollisionShape3D


func _ready() -> void:
	add_to_group("persistent")
	add_to_group("cellar_hatch")
	var c := HOLE.get_center()
	position = Vector3(c.x, Cabin.FLOOR_Y, c.y)
	var hw := HOLE.size.x * 0.5
	var wood := BuildKit.tex_mat("planks_h", 0.6, Color(0.62, 0.55, 0.48))
	var dark := BuildKit.tex_mat("planks_h", 0.6, Color(0.38, 0.33, 0.3))
	var iron := BuildKit.color_mat(Color(0.18, 0.17, 0.16), 0.5, 0.7)
	# Rahmen der Öffnung, bündig im Boden
	for s: float in [-1.0, 1.0]:
		BuildKit.box(self, Vector3(HOLE.size.x + 0.1, 0.012, 0.05), Vector3(0, 0.002, s * (hw + 0.025)), dark, false)
		BuildKit.box(self, Vector3(0.05, 0.012, HOLE.size.y), Vector3(s * (hw + 0.025), 0.002, 0), dark, false)
	# Deckel, Scharnier an der Nordkante, mit Eisenring
	_lid = Node3D.new()
	_lid.position = Vector3(0, 0, -hw)
	add_child(_lid)
	BuildKit.box(_lid, Vector3(HOLE.size.x - 0.02, 0.04, HOLE.size.y - 0.02), Vector3(0, -0.02, hw), wood, false)
	BuildKit.cylinder(_lid, 0.05, 0.012, Vector3(0, 0.002, hw * 1.6), iron, false, Vector3.ZERO, -1.0, 10)
	# Leiter in den Keller (leicht schräg)
	var lad := Node3D.new()
	lad.position = Vector3(0, -0.08, hw - 0.05)
	add_child(lad)
	var drop := Cabin.FLOOR_Y - Cabin.CELLAR_FLOOR
	var length := sqrt(drop * drop + 0.45 * 0.45)
	lad.rotation.x = -atan2(0.45, drop)   # Fuß nach Süden
	for s: float in [-1.0, 1.0]:
		BuildKit.box(lad, Vector3(0.05, length, 0.08), Vector3(s * 0.22, -length * 0.5, 0), dark, false)
	var k := 0.2
	while k < length - 0.1:
		BuildKit.box(lad, Vector3(0.4, 0.03, 0.06), Vector3(0, -k, 0), dark, false)
		k += 0.27
	LadderClimb.guard_box(lad, Vector3(0.5, length, 0.1), Vector3(0, -length * 0.5, 0))
	# Teppich über der Luke
	_rug = Node3D.new()
	add_child(_rug)
	BuildKit.box(_rug, Vector3(1.5, 0.014, 1.7), Vector3(0, 0.007, 0.0), BuildKit.tex_mat("rug", 1.4, Color(0.85, 0.75, 0.75)), false)
	_rug_cs = LadderClimb.guard_box(self, Vector3(1.4, 0.03, 1.6), Vector3(0, 0.015, 0))
	_lid_cs = LadderClimb.guard_box(self, Vector3(HOLE.size.x, 0.08, HOLE.size.y), Vector3(0, -0.04, 0))
	_rail_cs = LadderClimb.guard_box(self, Vector3(HOLE.size.x, 1.0, HOLE.size.y), Vector3(0, 0.5, 0))
	_apply(false)
	GameState.restore(self)


func persist_key() -> String:
	return "cellar_hatch"


func _apply(animate: bool) -> void:
	_rug_cs.disabled = rug_moved
	_lid_cs.disabled = open
	_rail_cs.disabled = not open
	var rug_pos := Vector3(-1.25, 0.0, -0.1) if rug_moved else Vector3.ZERO
	var rug_scale := Vector3(0.45, 3.0, 1.0) if rug_moved else Vector3.ONE   # zur Seite geschoben, zusammengerollt
	var lid_rot := -105.0 if open else 0.0   # klappt nach oben auf
	if animate:
		var tw := create_tween().set_trans(Tween.TRANS_SINE).set_parallel(true)
		tw.tween_property(_rug, "position", rug_pos, 0.6)
		tw.tween_property(_rug, "scale", rug_scale, 0.6)
		tw.tween_property(_lid, "rotation_degrees:x", lid_rot, 0.55)
	else:
		_rug.position = rug_pos
		_rug.scale = rug_scale
		_lid.rotation_degrees.x = lid_rot


func _below(p: Node3D) -> bool:
	return p.global_position.y < Cabin.FLOOR_Y - 0.5


func get_prompt(player: Node) -> String:
	var p := player as Node3D
	if p == null:
		return ""
	if _below(p):
		return "[E] Hinaufsteigen"
	if not rug_moved:
		return "Teppich  [E] zur Seite ziehen" if Tasks.flags.has(HINT_FLAG) else ""
	if not open:
		return "Bodenluke  [E] öffnen"
	return "[E] In den Keller steigen"


func get_secondary_prompt(player: Node) -> String:
	if open and player and not _below(player as Node3D):
		return "[R] Luke schließen"
	return ""


func interact(player: Node) -> void:
	var p := player as Player
	if p == null:
		return
	var c := global_position
	var top_stand := Vector3(c.x + 0.75, Cabin.FLOOR_Y, c.z)
	var hole := Vector3(c.x, Cabin.FLOOR_Y + 0.02, c.z)
	var mid := Vector3(c.x, Cabin.FLOOR_Y - 1.4, c.z + 0.75)
	var low := Vector3(c.x, Cabin.CELLAR_FLOOR + 0.1, c.z + 1.05)
	var bottom := Vector3(c.x, Cabin.CELLAR_FLOOR, c.z + 1.45)
	if _below(p):
		LadderClimb.climb(self, p, [bottom, low, mid, hole, top_stand], Vector3(c.x, 0, c.z - 3.0), 0.25)
		return
	if not rug_moved:
		if not Tasks.flags.has(HINT_FLAG):
			return
		rug_moved = true
		_apply(true)
		SoundBank.play_at(get_parent(), "place", c, -8.0, 0.7)
		EventBus.notify("Unter dem Teppich: eine Bodenluke mit Eisenring.", 3.0)
		Tasks.flag("cellar_found")
		return
	if not open:
		open = true
		_apply(true)
		SoundBank.play_at(get_parent(), "door_open", c, -4.0, 0.7)
		SoundBank.play_at(get_parent(), "floor_creak", c + Vector3(0, -1.0, 0), -6.0, 0.8)
		return
	LadderClimb.climb(self, p, [top_stand, hole, mid, low, bottom], Vector3(c.x, 0, c.z - 3.0), -0.35)
	Tasks.flag("cellar_visited")


func secondary_interact(player: Node) -> void:
	if open and player and not _below(player as Node3D):
		open = false
		_apply(true)
		SoundBank.play_at(get_parent(), "door_close", global_position, -4.0, 0.7)


func get_state() -> Dictionary:
	return {"rug": rug_moved, "open": open}


func set_state(s: Dictionary) -> void:
	rug_moved = bool(s.get("rug", false))
	open = bool(s.get("open", false))
	if _rug:
		_apply(false)
