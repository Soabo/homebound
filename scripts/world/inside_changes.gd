class_name InsideChanges
extends Node3D
## Dinge im Haus, die sich nachts verändern oder den Ort wechseln (Christian, 13.11.2026):
## Bens Teddy wandert durchs Haus, das Buch liegt woanders aufgeschlagen, der Becher steht woanders.
## Morgens nach Nächten mit Alien-Aktivität (ThreatDirector → morning) und manchmal mitten in der Nacht, wenn man
## gerade nicht hinsieht (NightOmens "deco_move"). Mit E stellt man sie zurück. Dazu taucht ab einer bestimmten Nacht
## eine neue Kinderzeichnung auf dem Esstisch auf ("drawing"). Persistent.

const Y := Cabin.FLOOR_Y

## Orte je Gegenstand: [Position (Boden des Gegenstands), Drehung y, gekippt (Grad um x)]; Index 0 = sein Platz
const SPOTS := {
	"teddy": [
		[Vector3(-8.35, Y + 0.44, -0.15), 90.0, 0.0],     # auf Bens Bett
		[Vector3(-2.5, Y, -0.55), 180.0, 0.0],             # vor der Schlafzimmertür, schaut hinein
		[Vector3(-2.55, Y + 0.45, 1.35), 90.0, 0.0],       # auf der Couch
		[Vector3(4.15, Y, 2.0), 0.0, 0.0],                 # unter der Dachbodenluke
		[Vector3(-0.2, Y + 0.76, 2.05), 90.0, 0.0],        # auf dem Esstisch
		[Vector3(0.5, Y, -1.45), 0.0, 0.0],                # in der Speistür
		[Vector3(-3.0, Y, 3.85), 180.0, 0.0],              # vor der Haustür, schaut hinaus
		[Vector3(-6.4, Y, -0.05), -90.0, 0.0],             # in der Kinderzimmertür
	],
	"book": [
		[Vector3(-4.02, Y + 0.44, 2.03), 20.0, 0.0],       # Couchtisch
		[Vector3(-7.4, Y, -2.0), 70.0, 0.0],               # aufgeschlagen im Kinderzimmer am Boden
		[Vector3(-8.4, Y + 0.48, -3.2), 10.0, 0.0],        # auf Lenas Bett
		[Vector3(4.15, Y, 1.5), -30.0, 0.0],               # unter der Dachbodenluke
		[Vector3(1.0, Y, -6.6), 100.0, 0.0],               # im Büro am Boden
	],
	"mug": [
		[Vector3(-3.8, Y + 0.44, 1.55), 0.0, 0.0],         # Couchtisch
		[Vector3(-1.6, Y, 0.6), 0.0, 90.0],                # umgekippt auf dem Boden
		[Vector3(0.0, Y + 0.76, 2.35), 0.0, 0.0],          # auf dem gegenüber gedeckten Platz
		[Vector3(-5.55, Y + 0.12, -3.9), 0.0, 0.0],        # neben dem Bett
	],
}
const NAMES := {"teddy": "Bens Teddy", "book": "Buch", "mug": "Becher"}

var state := {"teddy": 0, "book": 0, "mug": 0}
var drawing_shown := false
var _props := {}
var _rng := RandomNumberGenerator.new()
var _drawing: Node3D


func _ready() -> void:
	name = "InsideChanges"
	add_to_group("inside_changes")
	add_to_group("persistent")
	_rng.randomize()
	for id: String in SPOTS:
		var p := Prop.new()
		p.id = id
		p.owner_node = self
		p.name = "Prop_" + id
		add_child(p)
		_build(p, id)
		_props[id] = p
	GameState.restore(self)
	_apply_all()


func persist_key() -> String:
	return "inside_changes"


func _build(p: Prop, id: String) -> void:
	match id:
		"teddy":
			var fur := BuildKit.tex_mat("fabric", 0.4, Color(1.1, 0.8, 0.55))
			BuildKit.sphere(p, 0.1, Vector3(0, 0.1, 0), fur, Vector3(1.0, 1.1, 0.9), 8)
			BuildKit.sphere(p, 0.075, Vector3(0, 0.26, 0), fur, Vector3.ONE, 8)
			for s: float in [-1.0, 1.0]:
				BuildKit.sphere(p, 0.03, Vector3(s * 0.06, 0.33, 0), fur, Vector3.ONE, 6)
				BuildKit.sphere(p, 0.035, Vector3(s * 0.09, 0.12, -0.03), fur, Vector3(1.0, 1.4, 1.0), 6)
				BuildKit.sphere(p, 0.012, Vector3(s * 0.025, 0.28, -0.07), BuildKit.color_mat(Color(0.05, 0.04, 0.04), 0.2), Vector3.ONE, 5)
			p.collider = Vector3(0.25, 0.4, 0.25)
		"book":
			BuildKit.box(p, Vector3(0.22, 0.04, 0.16), Vector3(0, 0.02, 0), BuildKit.color_mat(Color(0.35, 0.18, 0.12)), false)
			BuildKit.box(p, Vector3(0.21, 0.03, 0.15), Vector3(0.004, 0.02, 0), BuildKit.color_mat(Color(0.88, 0.85, 0.78), 0.9), false)
			p.collider = Vector3(0.26, 0.1, 0.2)
		"mug":
			var cer := BuildKit.color_mat(Color(0.75, 0.73, 0.68), 0.6)
			BuildKit.cylinder(p, 0.04, 0.1, Vector3(0, 0.05, 0), cer, false, Vector3.ZERO, -1.0, 8)
			BuildKit.cylinder(p, 0.025, 0.012, Vector3(0.05, 0.055, 0), cer, false, Vector3(90, 0, 0), -1.0, 6)
			p.collider = Vector3(0.14, 0.14, 0.14)
	p.make_body()


func _apply_all() -> void:
	for id: String in state:
		_place(id)
	if drawing_shown:
		_make_drawing()


func _place(id: String) -> void:
	var p: Prop = _props.get(id)
	if p == null:
		return
	var spots: Array = SPOTS[id]
	var s: Array = spots[clampi(int(state[id]), 0, spots.size() - 1)]
	p.position = s[0]
	p.rotation_degrees = Vector3(s[2], s[1], 0.0)


## Morgens nach einer unruhigen Nacht: 1–2 Dinge stehen anders.
func morning(count: int) -> void:
	var ids: Array = state.keys()
	ids.shuffle()
	for i in mini(count, ids.size()):
		_move(ids[i])


## Mitten in der Nacht: ein Ding wechselt den Ort – nur, wenn man es gerade nicht sieht.
func night_move(player: Node3D) -> void:
	var ids: Array = state.keys()
	ids.shuffle()
	for id: String in ids:
		var p: Prop = _props[id]
		if player and (player.global_position.distance_to(p.global_position) < 4.0 or _visible_to(player, p.global_position)):
			continue
		_move(id)
		return


func _visible_to(player: Node3D, pos: Vector3) -> bool:
	var pl := player as Player
	if pl == null:
		return false
	var to := pos - pl.camera.global_position
	return to.length() < 12.0 and (-pl.camera.global_transform.basis.z).dot(to.normalized()) > 0.6


func _move(id: String) -> void:
	var n: int = (SPOTS[id] as Array).size()
	var cur := int(state[id])
	var next := cur
	while next == cur:
		next = _rng.randi_range(1, n - 1) if n > 1 else 0
	state[id] = next
	_place(id)


func put_back(id: String) -> void:
	state[id] = 0
	_place(id)
	SoundBank.play_at(get_parent(), "place", _props[id].global_position, -8.0)


## Neue Kinderzeichnung auf dem Esstisch (einmalig).
func show_drawing() -> void:
	if drawing_shown:
		return
	drawing_shown = true
	_make_drawing()


func _make_drawing() -> void:
	if _drawing:
		return
	var n := ResearchNote.new()
	n.name = "KidsDrawing2"
	n.note_id = "kinder_bild2"
	n.anchor = Vector3(-0.15, Y + 0.765, 2.05)
	add_child(n)
	_drawing = n


func changed_count() -> int:
	var c := 0
	for id: String in state:
		if int(state[id]) != 0:
			c += 1
	return c


func get_state() -> Dictionary:
	return {"state": state.duplicate(), "drawing": drawing_shown}


func set_state(s: Dictionary) -> void:
	var st: Dictionary = s.get("state", {})
	for id: String in state:
		state[id] = int(st.get(id, 0))
	drawing_shown = bool(s.get("drawing", false))
	if not _props.is_empty():
		_apply_all()


class Prop extends Interactable:
	var id := ""
	var owner_node: InsideChanges
	var collider := Vector3(0.2, 0.2, 0.2)

	func make_body() -> void:
		# Bereich statt fester Körper: anvisierbar, aber man läuft nicht dagegen (z. B. Teddy in der Tür)
		var body := Area3D.new()
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = collider
		cs.shape = sh
		cs.position = Vector3(0, collider.y * 0.5, 0)
		body.add_child(cs)
		add_child(body)

	func get_prompt(_p: Node) -> String:
		if int(owner_node.state[id]) == 0:
			return String(InsideChanges.NAMES[id])
		return "%s  [E] zurückstellen" % InsideChanges.NAMES[id]

	func interact(_p: Node) -> void:
		if int(owner_node.state[id]) != 0:
			owner_node.put_back(id)
