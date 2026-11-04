class_name ResourceNode
extends Interactable
## Eine Stelle zum Sammeln (GDD 5.1/6.2): Holz hacken, Steine sammeln,
## Schrott vom Autowrack abmontieren … Braucht evtl. ein Werkzeug, dauert
## einen Moment und wächst über Nacht teilweise nach.
## Der Knoten kann im Ursprung des Erbauers liegen; anchor = Position der Stelle.

@export var item_id: String = "wood"
@export var per_action: int = 1
@export var amount: int = 5
@export var max_amount: int = 5
@export var regrow_per_day: int = 0
@export var tool: String = ""
@export var action_label: String = "Sammeln"
@export var action_time: float = 1.2
@export var sound: String = "wood_crack"
@export var anchor: Vector3 = Vector3.ZERO
@export var collider_size: Vector3 = Vector3(1, 1, 1)

var _busy: bool = false


func _ready() -> void:
	add_to_group("persistent")
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = collider_size
	cs.shape = shape
	cs.position = anchor + Vector3(0, collider_size.y * 0.5, 0)
	body.add_child(cs)
	add_child(body)
	GameState.restore(self)
	TimeManager.day_changed.connect(_on_day_changed)


func _on_day_changed(_day: int) -> void:
	amount = mini(amount + regrow_per_day, max_amount)


func get_prompt(_player: Node) -> String:
	if amount <= 0:
		return "%s – leer%s" % [Inventory.display_name(item_id), "" if regrow_per_day <= 0 else " (wächst nach)"]
	if tool != "" and Inventory.count(tool) <= 0:
		return "%s – dafür brauchst du: %s" % [action_label, Inventory.display_name(tool)]
	if tool != "" and Inventory.equipped() != tool:
		var slot := Inventory.slot_of(tool)
		var how := ("Taste %d" % (slot + 1)) if slot >= 0 else "Inventar (Tab), auf einen Platz 1–9 ziehen"
		return "%s – %s in die Hand nehmen (%s)" % [action_label, Inventory.display_name(tool), how]
	if tool != "":
		return "[Linksklick / E] %s  (%s, noch %d)" % [action_label, Inventory.display_name(item_id), amount]
	return "[E] %s  (%s, noch %d)" % [action_label, Inventory.display_name(item_id), amount]


func interact(player: Node) -> void:
	if _busy or amount <= 0:
		return
	if tool != "" and Inventory.count(tool) <= 0:
		EventBus.notify("Dafür brauchst du: %s." % Inventory.display_name(tool), 2.5)
		return
	if tool != "" and Inventory.equipped() != tool:
		EventBus.notify("Nimm erst %s in die Hand." % Inventory.display_name(tool), 2.5)
		return
	if Inventory.total_weight() + Inventory.weight_of(item_id) > Inventory.MAX_WEIGHT:
		EventBus.notify("Zu schwer – du kannst nicht mehr tragen.", 2.0)
		return
	_busy = true
	var p := player as Player
	if p:
		p.input_locked = true
	var steps := maxi(1, int(round(action_time / 0.45)))
	for i in steps:
		# mit Werkzeug in der Hand: sichtbarer Hieb pro Schlag
		if tool != "" and p and p.hands:
			p.hands.tool_swing()
		SoundBank.play_at(self, sound, to_global(anchor) + Vector3(0, 0.5, 0), -4.0, randf_range(0.85, 1.15))
		EventBus.noise_made.emit(to_global(anchor), 10.0)
		await get_tree().create_timer(action_time / steps).timeout
	if p and is_instance_valid(p):
		p.input_locked = false
	_busy = false
	var take := mini(per_action, amount)
	var got := Inventory.add(item_id, take)
	amount -= got
	if got > 0:
		EventBus.notify("%s +%d  (jetzt %d)" % [Inventory.display_name(item_id), got, Inventory.count(item_id)], 2.0)
	else:
		EventBus.notify("Zu schwer – du kannst nicht mehr tragen.", 2.0)


func persist_key() -> String:
	return str(get_path())


func get_state() -> Dictionary:
	return {"amount": amount}


func set_state(s: Dictionary) -> void:
	amount = int(s.get("amount", amount))
