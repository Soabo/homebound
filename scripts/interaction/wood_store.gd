class_name WoodStore
extends Interactable
## Holzlager in der Werkstatt (Christian 26.11.): Holzregal an der Ostwand statt des Sägebocks.
## Bis zu 20 Scheite, jedes sichtbar (5 nebeneinander, 4 Lagen, Stirnseiten zum Raum).
## [E] ein Scheit nehmen, [R] alles getragene Holz hineinlegen (bis es voll ist). Werte: data/house/house.json „wood_store“.
## Lokale Achsen: +x = zur Wand, z = entlang der Wand, Ursprung = Boden vorne in der Mitte.

const LEN := 1.04    ## Länge entlang der Wand
const DEPTH := 0.46  ## Tiefe
const COLS := 5
const ROWS := 4
const LOG_R := 0.075

var max_wood: int = 20
var count: int = 6
var _logs: Array[Node3D] = []


func _ready() -> void:
	add_to_group("persistent")
	add_to_group("wood_store")
	var cfg: Dictionary = DataDB.load_json("res://data/house/house.json").get("wood_store", {})
	max_wood = clampi(int(cfg.get("max", 20)), 1, COLS * ROWS)
	count = clampi(int(cfg.get("start", 6)), 0, max_wood)
	var wood := BuildKit.tex_mat("planks_h", 1.0, Color(0.85, 0.72, 0.55))
	var dark := BuildKit.color_mat(Color(0.22, 0.15, 0.1), 0.85)
	var h := 0.12 + ROWS * (LOG_R * 2.0 + 0.012) + 0.08
	# Rahmen: zwei Bodenbalken, vier Pfosten, Deckbrett
	for sz: float in [-1.0, 1.0]:
		BuildKit.box_mm(self, Vector3(0, 0, sz * LEN * 0.5 - 0.03), Vector3(DEPTH, 0.1, sz * LEN * 0.5 + 0.03), dark, false)
		for sx: float in [0.03, DEPTH - 0.03]:
			BuildKit.box(self, Vector3(0.05, h, 0.05), Vector3(sx, h * 0.5, sz * LEN * 0.5), dark, false)
	for sx: float in [0.06, DEPTH - 0.06]:
		BuildKit.box(self, Vector3(0.05, 0.05, LEN), Vector3(sx, 0.095, 0), dark, false)
	BuildKit.box(self, Vector3(DEPTH + 0.04, 0.03, LEN + 0.1), Vector3(DEPTH * 0.5, h + 0.015, 0), wood, false)
	# Scheite: Stirnseite zum Raum, leicht unregelmäßig
	var bark := BuildKit.tex_mat("logs", 0.5)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2611
	var step := (LEN - 0.08) / COLS
	for r in ROWS:
		for c in COLS:
			var z := -LEN * 0.5 + 0.04 + step * (c + 0.5)
			var y := 0.12 + LOG_R + r * (LOG_R * 2.0 + 0.012)
			var rr := LOG_R * rng.randf_range(0.88, 1.0)
			var l := BuildKit.cylinder(self, rr, DEPTH - 0.06 - rng.randf_range(0.0, 0.05), Vector3(DEPTH * 0.5 - rng.randf_range(0.0, 0.03), y, z + rng.randf_range(-0.008, 0.008)),
				bark, false, Vector3(rng.randf_range(-6, 6), 0, 90), -1.0, 7)
			_logs.append(l)
	# fest + zum Anvisieren
	var body := StaticBody3D.new()
	var bcs := CollisionShape3D.new()
	var bsh := BoxShape3D.new()
	bsh.size = Vector3(DEPTH, h, LEN)
	bcs.shape = bsh
	bcs.position = Vector3(DEPTH * 0.5, h * 0.5, 0)
	body.add_child(bcs)
	add_child(body)
	var area := Area3D.new()
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(DEPTH + 0.15, h + 0.1, LEN + 0.1)
	cs.shape = sh
	cs.position = Vector3(DEPTH * 0.5 - 0.05, h * 0.5, 0)
	area.add_child(cs)
	add_child(area)
	GameState.restore(self)
	_update()


func _update() -> void:
	for i in _logs.size():
		_logs[i].visible = i < count


func get_prompt(_p: Node) -> String:
	if count > 0:
		return "Holzlager (%d/%d)  [E] Holz nehmen" % [count, max_wood]
	return "Holzlager (leer)"


func get_secondary_prompt(_p: Node) -> String:
	if count < max_wood and Inventory.count("wood") > 0:
		return "[R] Holz einlagern (%d)" % mini(Inventory.count("wood"), max_wood - count)
	return ""


func interact(_p: Node) -> void:
	if count <= 0:
		return
	if Inventory.add("wood", 1) > 0:
		count -= 1
		SoundBank.play_at(self, "pickup", global_position + Vector3(0, 0.5, 0), -4.0, 0.9)
		_update()


## Alles getragene Holz hinein, bis das Lager voll ist.
func secondary_interact(_p: Node) -> void:
	var n := mini(Inventory.count("wood"), max_wood - count)
	if n <= 0:
		return
	if Inventory.remove("wood", n):
		count += n
		SoundBank.play_at(self, "place", global_position + Vector3(0, 0.5, 0), -4.0, 1.0)
		_update()


func persist_key() -> String:
	return str(get_path())


func get_state() -> Dictionary:
	return {"count": count}


func set_state(s: Dictionary) -> void:
	count = clampi(int(s.get("count", 6)), 0, max_wood)
	if is_inside_tree():
		_update()
