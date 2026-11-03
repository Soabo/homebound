class_name Door
extends Interactable
## Drehtür mit Scharnier am linken Rand (lokale x-Achse = Türbreite).
## Optional abschließbar. Später: Schaden, Barrikaden (GDD 7.3).

@export var door_name: String = "Tür"
@export var width: float = 1.0
@export var height: float = 2.05
@export var thickness: float = 0.06
@export var lockable: bool = false
@export var open_angle_deg: float = 100.0
## +1 öffnet in Richtung lokales -z, -1 in Richtung +z.
@export var open_sign: float = 1.0
@export var color: Color = Color(0.36, 0.24, 0.15)

var is_open: bool = false
var is_locked: bool = false
var _hinge: Node3D
var _tween: Tween


func _ready() -> void:
	_build()


func _build() -> void:
	_hinge = Node3D.new()
	_hinge.name = "Hinge"
	add_child(_hinge)
	# StaticBody folgt der Drehung des Scharniers zuverlässig (AnimatableBody tat das mit Jolt nicht).
	var body := StaticBody3D.new()
	body.position = Vector3(width * 0.5, height * 0.5, 0.0)
	_hinge.add_child(body)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(width - 0.02, height, thickness)
	cs.shape = shape
	body.add_child(cs)

	var tint := Color(color.r / 0.42, color.g / 0.28, color.b / 0.17)
	var plank := BuildKit.tex_mat("planks_v", 0.9, tint)
	BuildKit.box(body, Vector3(width - 0.02, height, thickness), Vector3.ZERO, plank, false)
	# Querleisten und Diagonalstrebe (Brettertür)
	var batten := BuildKit.tex_mat("planks_h", 1.2, tint.darkened(0.25))
	var diag := atan2(height * 0.64, width - 0.2)
	BuildKit.box(body, Vector3(sqrt(pow(width - 0.2, 2) + pow(height * 0.64, 2)), 0.1, 0.02),
			Vector3(0, 0, thickness * 0.5 + 0.01), batten, false, Vector3(0, 0, rad_to_deg(diag)))
	for y: float in [-height * 0.32, height * 0.32]:
		BuildKit.box(body, Vector3(width - 0.12, 0.12, 0.02), Vector3(0, y, thickness * 0.5 + 0.01), batten, false)
		BuildKit.box(body, Vector3(width - 0.12, 0.12, 0.02), Vector3(0, y, -thickness * 0.5 - 0.01), batten, false)
	# Griffe
	var metal := BuildKit.color_mat(Color(0.15, 0.14, 0.13), 0.4, 0.8)
	for side: float in [1.0, -1.0]:
		BuildKit.box(body, Vector3(0.03, 0.14, 0.04), Vector3(width * 0.5 - 0.12, -0.05, side * (thickness * 0.5 + 0.03)), metal, false)


func get_prompt(_player: Node) -> String:
	if is_broken():
		return "%s – aufgebrochen!" % door_name
	if is_locked:
		return "[E] %s (abgeschlossen)" % door_name
	var dmg := ""
	if is_entry and health < max_health:
		dmg = "  – beschädigt %d%%" % int(health / max_health * 100.0)
	return "[E] %s %s%s" % [door_name, "schließen" if is_open else "öffnen", dmg]


func get_secondary_prompt(_player: Node) -> String:
	if is_entry and (is_broken() or health < max_health * 0.99):
		return "[R] Tür reparieren  (2 Bretter + 4 Nägel – du hast %d / %d)" % [Inventory.count("planks"), Inventory.count("nails")]
	if not lockable or is_open:
		return ""
	return "[R] %s" % ("Aufschließen" if is_locked else "Abschließen")


func interact(_player: Node) -> void:
	if is_broken():
		return
	if is_locked:
		EventBus.notify("Abgeschlossen.", 1.5)
		return
	set_open(not is_open)
	if not is_open:
		EventBus.noise_made.emit(global_position, 10.0)


func secondary_interact(_player: Node) -> void:
	if is_entry and (is_broken() or health < max_health * 0.99):
		if not Inventory.remove_all({"planks": 2, "nails": 4}):
			EventBus.notify("Du brauchst 2 Bretter und 4 Nägel. Beides gibt es in der Werkstatt.", 3.0)
			return
		health = minf(health + max_health * 0.6, max_health)
		SoundBank.play_at(self, "hammer", global_position + Vector3(width * 0.5, 1.0, 0), -2.0)
		EventBus.noise_made.emit(global_position, 12.0)
		if is_open:
			set_open(false)
		return
	if not lockable or is_open:
		return
	is_locked = not is_locked
	SoundBank.play_at(self, "switch", global_position + Vector3(width * 0.8, 1.0, 0), -4.0, 0.5)
	EventBus.notify("%s %s." % [door_name, "abgeschlossen" if is_locked else "aufgeschlossen"], 1.5)


# --- Zugang für Kreaturen (nur Türen mit is_entry) ----------------------

var is_entry: bool = false
var health: float = 180.0
var max_health: float = 180.0


var upgraded: bool = false


func make_entry() -> void:
	is_entry = true
	add_to_group("entry_point")
	add_to_group("persistent")
	if ThreatDirector.config:
		max_health = ThreatDirector.config.door_health
	health = max_health
	GameState.restore(self)


## Verstärkte Tür (Werkbank-Rezept): doppelte Lebenspunkte, Eisenbeschläge.
func upgrade() -> void:
	if upgraded:
		return
	upgraded = true
	max_health *= 2.0
	health = max_health
	_add_iron_bands()


func _add_iron_bands() -> void:
	var body := _hinge.get_child(0) as Node3D
	var iron := BuildKit.tex_mat("metal", 0.3, Color(0.8, 0.8, 0.8), 0.5)
	for yy: float in [-height * 0.38, 0.0, height * 0.38]:
		BuildKit.box(body, Vector3(width - 0.06, 0.07, 0.012), Vector3(0, yy, thickness * 0.5 + 0.022), iron, false)
		BuildKit.box(body, Vector3(width - 0.06, 0.07, 0.012), Vector3(0, yy, -thickness * 0.5 - 0.022), iron, false)


func persist_key() -> String:
	return str(get_path())


func get_state() -> Dictionary:
	return {"health": health, "locked": is_locked, "open": is_open, "upgraded": upgraded}


func set_state(s: Dictionary) -> void:
	if bool(s.get("upgraded", false)) and not upgraded:
		upgraded = true
		max_health *= 2.0
		_add_iron_bands.call_deferred()
	health = float(s.get("health", health))
	is_locked = bool(s.get("locked", false))
	if bool(s.get("open", false)) != is_open:
		set_open.call_deferred(bool(s.get("open", false)))


func entry_name() -> String:
	return name


func outside_point() -> Vector3:
	return to_global(Vector3(width * 0.5, 0, 0.8))


func inside_point() -> Vector3:
	return to_global(Vector3(width * 0.5, 0, -1.0))


func is_broken() -> bool:
	return is_entry and health <= 0.0


## Offen = Weg frei. Geschlossen, aber nicht abgeschlossen: Die Kreatur drückt sie einfach auf.
func is_breached() -> bool:
	return is_open or is_broken()


func strength() -> float:
	if is_open:
		return 0.0
	return health if is_locked else health * 0.15


func receive_hit(damage: float) -> void:
	var pl := get_tree().get_first_node_in_group("player") as Node3D
	if pl and pl.global_position.distance_to(global_position) < 7.0:
		EventBus.screen_shake.emit(0.3)
	var pos := global_position + Vector3(width * 0.5, 1.2, 0)
	if not is_locked and not is_open:
		# Unverschlossene Tür: wird aufgestoßen
		SoundBank.play_at(self, "bang", pos, 0.0, 1.2)
		set_open(true)
		return
	health = maxf(health - damage, 0.0)
	SoundBank.play_at(self, "knock", pos, 2.0, randf_range(0.85, 1.05))
	EventBus.noise_made.emit(pos, 20.0)
	if health <= 0.0:
		SoundBank.play_at(self, "wood_crack", pos, 4.0, 0.7)
		is_locked = false
		set_open(true)


func set_open(value: bool) -> void:
	is_open = value
	if _tween:
		_tween.kill()
	_tween = create_tween()
	var target := deg_to_rad(open_angle_deg) * open_sign if is_open else 0.0
	_tween.tween_property(_hinge, "rotation:y", target, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## Jemand rüttelt von außen an der Klinke (auch ohne dass jemand da ist …).
func rattle() -> void:
	SoundBank.play_at(self, "rattle", global_position + Vector3(width * 0.85, 1.0, 0.1), 2.0)
	if is_open or _hinge == null:
		return
	for i in 6:
		_hinge.rotation.y = randf_range(-0.012, 0.012) * open_sign
		await get_tree().create_timer(0.08).timeout
	_hinge.rotation.y = 0.0
