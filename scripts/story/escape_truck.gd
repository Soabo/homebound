class_name EscapeTruck
extends Interactable
## Christians eigener Pickup auf dem Hof (Ende »Flucht«, Story-Bibel). Steht seit dem Umzug: Batterie tot, Keilriemen
## gerissen, Tank leer. Mit Autoteilen, Batterie und Benzin (endings.json truck.needs) reparieren, dann wegfahren –
## das ist ein Ende (Abfrage vorher). Gespeichert: repariert ja/nein.

var repaired: bool = false
var _flat: MeshInstance3D
var _hood: Node3D

const HOME := Vector3(6.5, 0.0, 13.6)


func _ready() -> void:
	name = "EscapeTruck"
	add_to_group("persistent")
	add_to_group("escape_truck")
	_build()
	GameState.restore(self)
	_update_visuals()


func _build() -> void:
	# Alter Pickup, verblichenes Blau mit Rost; Front zeigt nach +z (zur Zufahrt)
	var paint := BuildKit.color_mat(Color(0.36, 0.48, 0.58), 0.55, 0.25)
	var rust := PlaceKit.mat("rust")
	var dark := BuildKit.color_mat(Color(0.04, 0.045, 0.05), 0.15, 0.4)
	var rubber := BuildKit.color_mat(Color(0.05, 0.05, 0.05), 0.9)
	var chrome := BuildKit.color_mat(Color(0.62, 0.62, 0.64), 0.25, 0.9)
	var under := BuildKit.color_mat(Color(0.08, 0.07, 0.06), 0.9)
	# Unterboden und Rahmen
	BuildKit.box(self, Vector3(1.7, 0.22, 4.9), Vector3(0, 0.42, 0), under, false)
	# Karosserie unten (Türen + Kotflügel), etwas schmaler als die Spur
	BuildKit.box(self, Vector3(1.84, 0.5, 2.5), Vector3(0, 0.78, 0.95), paint, false)
	# Ladefläche: Boden + Bordwände + Heckklappe
	BuildKit.box(self, Vector3(1.84, 0.12, 2.2), Vector3(0, 0.62, -1.35), paint, false)
	for sx: float in [-1.0, 1.0]:
		BuildKit.box(self, Vector3(0.08, 0.5, 2.2), Vector3(sx * 0.88, 0.93, -1.35), paint, false)
		BuildKit.box(self, Vector3(0.1, 0.05, 2.2), Vector3(sx * 0.88, 1.2, -1.35), chrome, false)
		BuildKit.box(self, Vector3(0.02, 0.22, 0.5), Vector3(sx * 0.93, 0.8, -1.8), rust, false)   # Rost am Radkasten
	BuildKit.box(self, Vector3(1.84, 0.5, 0.08), Vector3(0, 0.93, -2.43), paint, false)
	BuildKit.box(self, Vector3(1.6, 0.14, 0.03), Vector3(0, 0.98, -2.48), dark, false)
	BuildKit.box(self, Vector3(1.7, 0.45, 0.04), Vector3(0, 0.95, -0.26), paint, false)        # Stirnwand Ladefläche
	# Kabine: Unterteil, Dach, Scheiben (schräge Front)
	BuildKit.box(self, Vector3(1.8, 0.42, 1.25), Vector3(0, 1.24, 0.42), paint, false)
	BuildKit.box(self, Vector3(1.66, 0.08, 1.05), Vector3(0, 1.88, 0.36), paint, false)
	for sx: float in [-1.0, 1.0]:
		BuildKit.box(self, Vector3(0.04, 0.42, 0.95), Vector3(sx * 0.86, 1.66, 0.36), dark, false)            # Seitenscheibe
		BuildKit.box(self, Vector3(0.06, 0.5, 0.06), Vector3(sx * 0.84, 1.64, 0.95), paint, false, Vector3(-22, 0, 0))   # A-Säule
		BuildKit.box(self, Vector3(0.06, 0.5, 0.06), Vector3(sx * 0.84, 1.64, -0.18), paint, false)           # B-Säule
		BuildKit.box(self, Vector3(0.12, 0.1, 0.05), Vector3(sx * 1.0, 1.5, 1.0), dark, false)                 # Spiegel
		BuildKit.box(self, Vector3(0.02, 0.03, 0.12), Vector3(sx * 0.93, 1.18, 0.15), chrome, false)          # Türgriff
		BuildKit.box(self, Vector3(0.01, 0.5, 0.01), Vector3(sx * 0.925, 0.95, -0.2), dark, false)            # Türfuge
	BuildKit.box(self, Vector3(1.64, 0.46, 0.04), Vector3(0, 1.66, 0.97), dark, false, Vector3(-22, 0, 0))    # Frontscheibe
	BuildKit.box(self, Vector3(1.64, 0.4, 0.04), Vector3(0, 1.66, -0.22), dark, false)                       # Heckscheibe
	# Motorhaube (klappt auf, solange er kaputt ist)
	_hood = Node3D.new()
	_hood.position = Vector3(0, 1.04, 1.05)
	add_child(_hood)
	BuildKit.box(_hood, Vector3(1.78, 0.06, 1.15), Vector3(0, 0, 0.57), paint, false)
	BuildKit.box(_hood, Vector3(0.5, 0.02, 0.4), Vector3(0.3, 0.035, 0.6), rust, false)
	BuildKit.box(self, Vector3(1.6, 0.3, 0.9), Vector3(0, 0.85, 1.7), under, false)       # Motorraum (sichtbar bei offener Haube)
	# Front: Grill, Scheinwerfer, Stoßstange
	BuildKit.box(self, Vector3(1.84, 0.4, 0.06), Vector3(0, 0.84, 2.2), paint, false)
	BuildKit.box(self, Vector3(1.0, 0.24, 0.03), Vector3(0, 0.86, 2.24), dark, false)
	for k in 5:
		BuildKit.box(self, Vector3(0.96, 0.015, 0.02), Vector3(0, 0.77 + k * 0.045, 2.26), chrome, false)
	for sx: float in [-1.0, 1.0]:
		BuildKit.cylinder(self, 0.09, 0.04, Vector3(sx * 0.68, 0.88, 2.24), BuildKit.color_mat(Color(0.8, 0.8, 0.7), 0.15, 0.5), false, Vector3(90, 0, 0), -1.0, 10)
	BuildKit.box(self, Vector3(1.94, 0.16, 0.14), Vector3(0, 0.56, 2.28), chrome, false)
	BuildKit.box(self, Vector3(1.94, 0.16, 0.14), Vector3(0, 0.56, -2.5), chrome, false)
	# Räder mit Radkästen (eins platt)
	var i := 0
	for wz: float in [1.45, -1.6]:
		for sx: float in [-1.0, 1.0]:
			BuildKit.box(self, Vector3(0.12, 0.2, 0.95), Vector3(sx * 0.9, 0.98, wz), under, false)
			var w := BuildKit.cylinder(self, 0.36, 0.26, Vector3(sx * 0.86, 0.36, wz), rubber, false, Vector3(0, 0, 90), -1.0, 16)
			BuildKit.cylinder(self, 0.2, 0.27, Vector3(sx * 0.86, 0.36, wz), chrome, false, Vector3(0, 0, 90), -1.0, 10).reparent(w)
			if i == 1:
				_flat = w
			i += 1
	BuildKit.collider_box(self, Vector3(2.0, 1.9, 5.1), Vector3(0, 0.95, 0))
	var area := Area3D.new()
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.4, 2.2, 5.5)
	cs.shape = shape
	cs.position = Vector3(0, 1.1, 0)
	area.add_child(cs)
	add_child(area)


func _update_visuals() -> void:
	if _flat:
		_flat.scale = Vector3(1, 1, 1) if repaired else Vector3(1.0, 0.78, 1.0)
		_flat.position.y = 0.36 if repaired else 0.3
	if _hood:
		_hood.rotation_degrees.x = 0.0 if repaired else -38.0


func needs() -> Dictionary:
	return (Story.endings_data().get("truck", {}).get("needs", {}) as Dictionary)


func get_prompt(_player: Node) -> String:
	if repaired:
		return "[E] Einsteigen und wegfahren"
	var parts: PackedStringArray = []
	var n := needs()
	for id: String in n:
		parts.append("%s %d/%d" % [Inventory.display_name(id), Inventory.count(id), int(n[id])])
	return "[E] Pickup reparieren   (braucht: %s)" % ", ".join(parts)


func interact(_player: Node) -> void:
	if not repaired:
		var n := needs()
		if not Inventory.has_all(n):
			EventBus.notify(String(Story.endings_data().get("truck", {}).get("text", "")), 6.0)
			return
		for id: String in n:
			Inventory.remove(id, int(n[id]))
		repaired = true
		Tasks.flag("truck_repaired")
		SoundBank.hammer_series(self, global_position + Vector3(0, 1.0, 1.8), 4)
		EventBus.notify("Neue Batterie, Keilriemen geflickt, Reifen gewechselt, zwei Kanister im Tank. Er würde fahren.", 6.0)
		_update_visuals()
		return
	ChoiceDialog.open(get_tree(), "Wegfahren?",
			"Die Hütte, der Brunnen, alles, was ich über Stefanie herausgefunden habe, bleibt hier.\n" + String(Story.endings_data().get("confirm", "")),
			[{"id": "yes", "label": "Ja – losfahren und nicht zurückschauen", "ok": true}], _confirmed)


func _confirmed(id: String) -> void:
	if id == "yes":
		Story.start_ending("flucht")


func persist_key() -> String:
	return "EscapeTruck"


func get_state() -> Dictionary:
	return {"repaired": repaired}


func set_state(s: Dictionary) -> void:
	repaired = bool(s.get("repaired", false))
	_update_visuals()
