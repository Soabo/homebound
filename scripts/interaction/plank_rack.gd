class_name PlankRack
extends Interactable
## Bretterlager in der Werkstatt (Christian 23.11.): Kragarmregal an der Westwand, jedes Brett liegt sichtbar
## auf den Armen. [E] Bretter nehmen, [R] Bretter aus dem Rucksack zurücklegen (auffüllen bis zum Platz).
## Werte: data/house/house.json "plank_rack" (start, max, per_take). Knoten liegt im Ursprung der Hütte.

@export var wall_x: float = 2.13        ## Wandfläche (Westwand der Werkstatt)
@export var z_from: float = 2.2
@export var z_to: float = 3.8
@export var floor_y: float = 0.45

const ARM_HEIGHTS := [0.14, 0.62, 1.1]   ## Höhe der Kragarme über dem Boden
const ARM_DEPTH := 0.42
const PLANK_W := 0.16
const PLANK_T := 0.028
const PER_ARM_ACROSS := 2
const PER_ARM_LAYERS := 2

var amount: int = 10
var max_amount: int = 12
var per_take: int = 2
var _planks: Array[Node3D] = []


func _ready() -> void:
	var cfg: Dictionary = DataDB.load_json("res://data/house/house.json").get("plank_rack", {})
	max_amount = mini(int(cfg.get("max", 12)), ARM_HEIGHTS.size() * PER_ARM_ACROSS * PER_ARM_LAYERS)
	amount = mini(int(cfg.get("start", 10)), max_amount)
	per_take = int(cfg.get("per_take", 2))
	add_to_group("persistent")
	GameState.restore(self)
	amount = clampi(amount, 0, max_amount)
	_build()
	_update_visuals()


func _build() -> void:
	var frame := BuildKit.tex_mat("planks_h", 0.8, Color(0.55, 0.42, 0.3))
	var iron := BuildKit.color_mat(Color(0.2, 0.2, 0.22), 0.5, 0.6)
	var height: float = ARM_HEIGHTS[ARM_HEIGHTS.size() - 1] + 0.3
	var posts := [z_from + 0.18, z_to - 0.18]
	for z: float in posts:
		# Ständer an der Wand mit Fußstrebe
		BuildKit.box(self, Vector3(0.07, height, 0.07), Vector3(wall_x + 0.035, floor_y + height * 0.5, z), frame, false)
		BuildKit.box(self, Vector3(ARM_DEPTH, 0.05, 0.07), Vector3(wall_x + ARM_DEPTH * 0.5, floor_y + 0.025, z), frame, false)
		for h: float in ARM_HEIGHTS:
			# Kragarm mit kleiner Schrägstütze und Winkel aus Eisen
			BuildKit.box(self, Vector3(ARM_DEPTH, 0.045, 0.06), Vector3(wall_x + ARM_DEPTH * 0.5, floor_y + h - 0.0225, z), frame, false)
			BuildKit.box(self, Vector3(0.05, 0.16, 0.012), Vector3(wall_x + 0.09, floor_y + h - 0.1, z + 0.036), iron, false, Vector3(0, 0, 38))
			BuildKit.box(self, Vector3(0.03, 0.05, 0.065), Vector3(wall_x + ARM_DEPTH - 0.015, floor_y + h + 0.02, z), frame, false)
	# die Bretter: von unten nach oben, je Arm zwei nebeneinander und zwei übereinander
	var rng := RandomNumberGenerator.new()
	rng.seed = 4711
	var length := z_to - z_from
	for arm in ARM_HEIGHTS.size():
		for layer in PER_ARM_LAYERS:
			for slot in PER_ARM_ACROSS:
				var tint := rng.randf_range(0.92, 1.12)
				var mat := BuildKit.tex_mat("planks_h", 1.5, Color(1.25 * tint, 1.18 * tint, 1.02 * tint))
				var x := wall_x + 0.1 + slot * (PLANK_W + 0.03)
				var y := floor_y + float(ARM_HEIGHTS[arm]) + PLANK_T * (layer + 0.5)
				var z := z_from + length * 0.5 + rng.randf_range(-0.05, 0.05)
				var p := BuildKit.box(self, Vector3(PLANK_W, PLANK_T, length - rng.randf_range(0.0, 0.1)), Vector3(x, y, z), mat, false,
						Vector3(0, rng.randf_range(-1.2, 1.2), 0))
				p.name = "Plank_%d" % _planks.size()
				_planks.append(p)
	# ein Körper für das ganze Regal (Anvisieren + man läuft nicht hindurch)
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(ARM_DEPTH, height, length)
	cs.shape = sh
	cs.position = Vector3(wall_x + ARM_DEPTH * 0.5, floor_y + height * 0.5, z_from + length * 0.5)
	body.add_child(cs)
	add_child(body)


func _update_visuals() -> void:
	for i in _planks.size():
		_planks[i].visible = i < amount


func get_prompt(_p: Node) -> String:
	if amount <= 0:
		return "Bretterlager – leer"
	return "[E] Bretter nehmen  (%d im Regal)" % amount


func get_secondary_prompt(_p: Node) -> String:
	var have := Inventory.count("planks")
	if have <= 0 or amount >= max_amount:
		return "" if amount < max_amount or have <= 0 else "Das Regal ist voll."
	return "[R] Bretter ins Regal legen (%d dabei, Platz für %d)" % [have, max_amount - amount]


func interact(_p: Node) -> void:
	if amount <= 0:
		EventBus.notify("Keine Bretter mehr im Regal. An der Werkbank lassen sich aus Holz neue sägen.", 2.5)
		return
	var took := Inventory.add("planks", mini(per_take, amount))
	if took <= 0:
		EventBus.notify("Kein Platz mehr für Bretter.", 2.0)
		return
	amount -= took
	SoundBank.play_at(self, "pickup", to_global(Vector3(wall_x + 0.2, floor_y + 0.6, (z_from + z_to) * 0.5)), -6.0)
	EventBus.notify("Bretter +%d  (jetzt %d)" % [took, Inventory.count("planks")], 2.0)
	_update_visuals()


## Auffüllen: alle getragenen Bretter, bis das Regal voll ist.
func secondary_interact(_p: Node) -> void:
	var n := mini(Inventory.count("planks"), max_amount - amount)
	if n <= 0 or not Inventory.remove("planks", n):
		return
	amount += n
	SoundBank.play_at(self, "place", to_global(Vector3(wall_x + 0.2, floor_y + 0.6, (z_from + z_to) * 0.5)), -6.0)
	EventBus.notify("%d Bretter ins Regal gelegt (%d / %d)." % [n, amount, max_amount], 2.0)
	_update_visuals()


func persist_key() -> String:
	return str(get_path())


func get_state() -> Dictionary:
	return {"amount": amount}


func set_state(s: Dictionary) -> void:
	amount = int(s.get("amount", amount))
