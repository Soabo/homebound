class_name GeneratorService
extends Interactable
## Wartungsklappe am Generator: Öl einfüllen, Zündkerze wechseln, Holzvergaser / Zellen-Adapter anbauen.
## Liegt als Kind des Generators; position = Mitte der Klappe (vor dem Gehäuse).
## Der Holzvergaser steht außen an der Schuppen-Nordwand (gasifier_spot, im Schuppen-Raum).

@export var gasifier_spot: Vector3 = Vector3.ZERO
var _gasifier: Node3D
var _adapter: Node3D


func _ready() -> void:
	var area := Area3D.new()
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(0.32, 0.3, 0.16)
	cs.shape = sh
	area.add_child(cs)
	add_child(area)
	var steel := BuildKit.color_mat(Color(0.75, 0.6, 0.15), 0.5, 0.3)
	BuildKit.box(self, Vector3(0.2, 0.16, 0.02), Vector3(0, 0, 0), steel, false)
	BuildKit.cylinder(self, 0.035, 0.04, Vector3(0.05, 0.03, 0.02), BuildKit.color_mat(Color(0.1, 0.1, 0.1)), false, Vector3(90, 0, 0), -1.0, 8)
	var oil := Label3D.new()
	oil.text = "ÖL"
	oil.font_size = 40
	oil.pixel_size = 0.0012
	oil.modulate = Color(0.1, 0.1, 0.1)
	oil.outline_size = 0
	oil.position = Vector3(-0.04, 0.0, 0.012)
	add_child(oil)
	Supplies.changed.connect(_update)
	_update.call_deferred()


func get_prompt(_p: Node) -> String:
	Tasks.flag("generator_checked")
	var head := "Generator-Wartung: Zustand %d %% (%s)" % [int(Supplies.generator_condition), Supplies.condition_text()]
	if Inventory.count("gasifier_kit") > 0 and not Supplies.gasifier:
		return head + "  [E] Holzvergaser anbauen"
	if Inventory.count("cell_adapter") > 0 and not Supplies.cell_adapter:
		return head + "  [E] Zellen-Adapter einbauen"
	if Inventory.count("motor_oil") > 0 and Supplies.generator_condition < 99.0:
		return head + "  [E] Öl nachfüllen (%d)" % Inventory.count("motor_oil")
	if Inventory.count("motor_oil") <= 0 and Inventory.count("spark_plug") <= 0:
		return head + "  – Öl oder Zündkerzen fehlen"
	return head


func get_secondary_prompt(_p: Node) -> String:
	if Inventory.count("spark_plug") > 0 and Supplies.generator_condition < 99.0:
		return "[R] Zündkerze wechseln (%d)" % Inventory.count("spark_plug")
	return ""


func interact(_p: Node) -> void:
	if Inventory.count("gasifier_kit") > 0 and not Supplies.gasifier:
		Inventory.remove("gasifier_kit", 1)
		Supplies.gasifier = true
		Supplies.changed.emit()
		Tasks.flag("gasifier_installed")
		SoundBank.hammer_series(self, global_position, 5)
		EventBus.notify("Holzvergaser angebaut. Jetzt kannst du den Generator auch mit Holz füttern (R am Generator).", 4.0)
		return
	if Inventory.count("cell_adapter") > 0 and not Supplies.cell_adapter:
		Inventory.remove("cell_adapter", 1)
		Supplies.cell_adapter = true
		Supplies.changed.emit()
		SoundBank.play_at(self, "signal", global_position, -8.0, 1.2)
		EventBus.notify("Zellen-Adapter eingebaut. Energiezellen kannst du jetzt im Generator einsetzen.", 4.0)
		return
	var msg := Supplies.service("motor_oil")
	if msg != "":
		SoundBank.play_at(self, "faucet", global_position, -14.0, 0.6)
		EventBus.notify(msg, 2.5)


func secondary_interact(_p: Node) -> void:
	var msg := Supplies.service("spark_plug")
	if msg != "":
		SoundBank.play_at(self, "collect_metal", global_position, -6.0, 1.6)
		EventBus.notify(msg, 2.5)


## Holzvergaser (Fass mit Deckel und Rohr) und Adapter (Kasten mit leuchtender Fassung) zeigen.
func _update() -> void:
	if Supplies.gasifier and _gasifier == null:
		_gasifier = Node3D.new()
		get_parent().add_child(_gasifier)
		_gasifier.global_position = Vector3(gasifier_spot.x, Terrain.height_at(gasifier_spot.x, gasifier_spot.z), gasifier_spot.z)
		var drum := BuildKit.tex_mat("metal", 0.3, Color(0.55, 0.5, 0.45), 0.5)
		var rust := BuildKit.tex_mat("metal", 0.3, Color(0.75, 0.45, 0.3), 0.4)
		BuildKit.cylinder(_gasifier, 0.28, 1.1, Vector3(0, 0.55, 0), drum, true, Vector3.ZERO, -1.0, 14)
		BuildKit.cylinder(_gasifier, 0.3, 0.06, Vector3(0, 1.12, 0), rust, false, Vector3.ZERO, -1.0, 14)
		BuildKit.box(_gasifier, Vector3(0.18, 0.03, 0.03), Vector3(0, 1.17, 0), rust, false)
		BuildKit.cylinder(_gasifier, 0.06, 0.55, Vector3(0, 0.6, 0.45), drum, false, Vector3(90, 0, 0), -1.0, 8)
		BuildKit.cylinder(_gasifier, 0.2, 0.35, Vector3(0.35, 0.18, 0), rust, false, Vector3.ZERO, -1.0, 10)
	if Supplies.cell_adapter and _adapter == null:
		_adapter = Node3D.new()
		add_child(_adapter)
		BuildKit.box(_adapter, Vector3(0.18, 0.12, 0.1), Vector3(0.28, 0.0, 0.03), BuildKit.color_mat(Color(0.2, 0.22, 0.25), 0.4, 0.5), false)
		BuildKit.cylinder(_adapter, 0.04, 0.03, Vector3(0.28, 0.0, 0.09), BuildKit.emissive_mat(Color(0.3, 0.9, 1.0), 2.0), false, Vector3(90, 0, 0), -1.0, 10)
