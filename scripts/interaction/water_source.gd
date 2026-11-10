class_name WaterSource
extends Interactable
## Trinkstelle: Regentonne, Spüle oder Bach (GDD 6.1).
## E: direkt trinken. Liegt im Ursprung des Erbauers; anchor = Position.

@export var label: String = "Regentonne"
@export var anchor: Vector3 = Vector3.ZERO
@export var collider_size: Vector3 = Vector3(0.8, 1.0, 0.8)
@export var thirst_gain: float = 30.0
## Kann durch das Terraforming verunreinigt werden (Bach, Leitungswasser). Regenwasser bleibt sauber.
@export var contaminable: bool = false
## Leitungswasser ist sauber (Flasche = Trinkwasser), Regentonne/Bach geben Rohwasser zum Abkochen
@export var clean: bool = false
## Geräusch beim Trinken (Wasserhahn: echtes Rauschen)
@export var sound: String = "step_grass"


## false = man kann hindurchlaufen (z. B. Trinkstellen im Bach), anvisieren geht trotzdem
@export var solid: bool = true


func _ready() -> void:
	var body: CollisionObject3D = StaticBody3D.new() if solid else Area3D.new()
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = collider_size
	cs.shape = shape
	cs.position = anchor + Vector3(0, collider_size.y * 0.5, 0)
	body.add_child(cs)
	add_child(body)


func _dirty() -> bool:
	return contaminable and WorldState.water_contaminated()


func get_prompt(_player: Node) -> String:
	if _dirty():
		var how := "mit Filter" if Inventory.count("water_filter") > 0 else "VERFÄRBT – ohne Filter gefährlich"
		return "[E] %s – trinken (%s)  (Durst %d%%)" % [label, how, int(Survival.thirst)]
	return "[E] %s – trinken  (Durst %d%%)" % [label, int(Survival.thirst)]


## [R] Gießkanne füllen (wenn nicht voll) oder eine leere Flasche abfüllen.
## Gießkanne zuerst, wenn sie leer ist (oder keine leere Flasche dabei); sonst Flaschen.
func _fill_can_first() -> bool:
	if Inventory.count("watering_can") <= 0 or Supplies.can_water >= Supplies.config.watering_can_charges:
		return false
	return Supplies.can_water <= 0 or Inventory.count("bottle_empty") <= 0


func get_secondary_prompt(_player: Node) -> String:
	if _fill_can_first():
		return "[R] Gießkanne füllen"
	var n := Inventory.count("bottle_empty")
	if n > 0:
		return "[R] Flasche füllen (%d leer)" % n
	return ""


func secondary_interact(_player: Node) -> void:
	if _fill_can_first():
		Supplies.fill_can(_dirty())
		_splash()
		EventBus.notify("Gießkanne gefüllt.", 1.5)
		return
	if not Inventory.remove("bottle_empty", 1):
		return
	var what := "water" if clean else "water_raw"
	if _dirty():
		what = "water_raw" if Inventory.count("water_filter") > 0 else "water_tainted"
	Inventory.add(what, 1)
	_splash()
	EventBus.notify("%s abgefüllt." % Inventory.display_name(what), 2.0)
	Tasks.flag("filled_bottle")


func interact(player: Node) -> void:
	if _dirty() and Inventory.count("water_filter") <= 0:
		# verunreinigt: löscht nur halb den Durst und schadet
		Survival.apply({"thirst": thirst_gain * 0.5})
		var p := player as Player
		if p:
			p.health = maxf(p.health - 12.0, 1.0)
			EventBus.player_hurt.emit(12.0)
		EventBus.notify("Das Wasser schmeckt metallisch und brennt im Hals. Bau dir einen Wasserfilter (Werkbank).", 4.0)
		_splash()
		return
	Survival.apply({"thirst": thirst_gain})
	_splash()


func _splash() -> void:
	if sound == "step_grass":
		SoundBank.play_at(self, "step_grass", to_global(anchor) + Vector3(0, 0.5, 0), -6.0, 1.6)
	else:
		SoundBank.play_at(self, sound, to_global(anchor) + Vector3(0, 0.3, 0), 0.0)
