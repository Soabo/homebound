class_name Workbench
extends Interactable
## Werkbank in der Werkstatt: öffnet das Herstellungs-Menü (GDD 6, Phase 6).
## Liegt im Ursprung der Hütte; anchor = Mitte der Arbeitsfläche.

@export var anchor: Vector3 = Vector3.ZERO


func _ready() -> void:
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.7, 0.25, 2.2)
	cs.shape = shape
	cs.position = anchor + Vector3(0, 0.1, -0.2)
	body.add_child(cs)
	add_child(body)


func get_prompt(_player: Node) -> String:
	return "[E] Werkbank – herstellen"


func interact(_player: Node) -> void:
	get_tree().call_group("game_menus", "open_crafting")


## Führt ein Rezept aus. Gibt eine Meldung zurück (leer = Erfolg).
static func craft(recipe: Dictionary, scene_tree: SceneTree) -> String:
	var needs: Dictionary = recipe.get("needs", {})
	if not Inventory.has_all(needs):
		return "Dir fehlen Materialien."
	var special: String = recipe.get("special", "")
	if special == "door_upgrade":
		var door := scene_tree.current_scene.get_node_or_null("Cabin/FrontDoor") as Door
		if door == null or door.upgraded:
			return "Die Haustür ist schon verstärkt."
		Inventory.remove_all(needs)
		door.upgrade()
		return ""
	# Passt das Ergebnis noch ins Inventar? Zutaten werden vorher entfernt.
	var gives: Dictionary = recipe.get("gives", {})
	var weight_after := Inventory.total_weight()
	for id in needs:
		weight_after -= Inventory.weight_of(id) * int(needs[id])
	for id in gives:
		weight_after += Inventory.weight_of(id) * int(gives[id])
		if Inventory.count(id) + int(gives[id]) > int(DataDB.item(id).get("stack", 99)):
			return "Davon kannst du nicht mehr tragen."
	if weight_after > Inventory.MAX_WEIGHT:
		return "Zu schwer – leg erst etwas ab."
	Inventory.remove_all(needs)
	for id in gives:
		Inventory.add(id, int(gives[id]))
	return ""
