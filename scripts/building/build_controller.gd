class_name BuildController
extends Node
## Bauen aus der Hand (Christian 25.11., vorher eigener Baumodus mit B):
## Ein Bauteil (Zaun, Falle, Zelt, Kamera …) auf der Schnellleiste anwählen = Vorschau erscheint.
##  Linksklick   aufstellen / anbringen
##  R (tippen)   drehen (Kamera: schwenken)
##  R (halten)   auf ein Gebautes schauen = abbauen (geht immer, auch ohne Bauteil in der Hand)
##  Bretter in der Hand + Blick auf Fenster/Haustür: Linksklick = verbarrikadieren / reparieren (kostet Nägel)
## Grün = passt, rot = geht hier nicht (Haus, Schuppen, zu steil, belegt). E bleibt fürs Benutzen frei.

const REACH := 6.0
const GRID := 0.25
## So lange R halten, bis ein Bauteil abgebaut ist (Sekunden)
const DISMANTLE_HOLD := 0.9
## R kürzer als das = tippen (drehen)
const TAP_TIME := 0.35

var active: bool = false
var type: String = ""
var _rot: float = 0.0
var _preview: Structure
var _valid: bool = false
## Flächen, auf denen nicht gebaut werden kann: Hütte (mit Wandstärke), Veranda, Treppe
const NO_BUILD := [Rect2(-6.4, -4.9, 12.8, 9.8), Rect2(-5.8, 4.6, 7.2, 2.2), Rect2(-4.2, 6.6, 2.4, 1.0)]
var _pos: Vector3


## Zuletzt angewählter Gegenstand der Schnellleiste (Wechsel startet/beendet das Bauen)
var _last_equipped: String = "-"
## R halten: Zeit, Ziel, schon erledigt
var _r_down: bool = false
var _r_time: float = 0.0
var _r_target: Node = null
var _r_done: bool = false


func _ready() -> void:
	name = "BuildController"
	add_to_group("build_controller")


## Gegenstände, mit denen man aus der Hand baut (Bauteile, Kameras, Bretter zum Verbarrikadieren).
static func is_build_item(id: String) -> bool:
	var d := DataDB.item(id)
	return d.has("build") or d.has("camera") or id == "planks"


func _is_planks() -> bool:
	return type == "planks"


# --- Kameras anbringen ------------------------------------------------------
## Kameras nur außen an Hütte oder Schuppen, zwischen diesen Höhen (über dem Boden der Wand)
var _cam_preview: SecurityCamera
var _cam_key: String = ""
var _cam_pos: Vector3
var _cam_normal: Vector3
var _cam_yaw: float = 0.0


func _is_camera() -> bool:
	return DataDB.item(type).has("camera")


func _camera_update(player: Player) -> void:
	var cam := player.camera.global_transform
	var q := PhysicsRayQueryParameters3D.create(cam.origin, cam.origin - cam.basis.z * REACH)
	q.exclude = [player.get_rid()]
	var hit := player.get_world_3d().direct_space_state.intersect_ray(q)
	_valid = false
	var why := "Ziel auf eine Außenwand von Hütte oder Schuppen."
	if not hit.is_empty():
		var n: Vector3 = hit["normal"]
		var p: Vector3 = hit["position"]
		var owner := ""
		var node := hit["collider"] as Node
		while node:
			if node.name in ["Cabin", "Shed"]:
				owner = node.name
				break
			node = node.get_parent()
		if owner != "" and absf(n.y) < 0.3:
			n.y = 0.0
			n = n.normalized()
			# Außenseite: Wandrichtung zeigt von der Gebäudemitte weg
			var center := Vector3.ZERO if owner == "Cabin" else Shed.ORIGIN
			var outward := (p - center)
			outward.y = 0.0
			var lo := (Cabin.FLOOR_Y + 1.5) if owner == "Cabin" else 1.4
			var hi := (Cabin.WALL_TOP - 0.15) if owner == "Cabin" else 2.15
			# vor der Wand muss draußen sein (nicht an Innenwänden)
			var front := p + n * 0.3
			var inside := Cabin.is_inside(front) if owner == "Cabin" else \
					(absf(front.x - Shed.ORIGIN.x) < Shed.HALF.x and absf(front.z - Shed.ORIGIN.z) < Shed.HALF.y)
			if outward.dot(n) <= 0.0 or inside:
				why = "Nur außen am Gebäude."
			elif p.y < lo:
				why = "Höher anbringen (über Kopfhöhe)."
			elif p.y > hi:
				why = "Hier ist kein Platz mehr unterm Dach."
			else:
				_valid = true
				_cam_pos = p
				_cam_normal = n
	var key := "%s|%.1f|%.1f|%.1f|%.2f|%s" % [type, _cam_pos.x, _cam_pos.y, _cam_pos.z, _cam_yaw, _valid]
	if key != _cam_key:
		_cam_key = key
		if _cam_preview:
			_cam_preview.queue_free()
			_cam_preview = null
		if _valid:
			_cam_preview = SecurityCamera.new()
			_cam_preview.preview = true
			_cam_preview.wall_normal = _cam_normal
			_cam_preview.position = _cam_pos
			_cam_preview.look_target = SecurityCamera.aim_target(_cam_pos, _cam_normal, _cam_yaw)
			get_tree().current_scene.add_child(_cam_preview)
	_prompt("%s  –  [Linksklick] anbringen   [R] schwenken%s" % [Inventory.display_name(type), "" if _valid else "\n" + why], player)


func _camera_place() -> void:
	if not _valid:
		EventBus.notify("Kameras gehen nur außen an Hütte oder Schuppen.", 2.0)
		return
	var idx := int(DataDB.item(type).get("camera", 0))
	if not Inventory.remove(type, 1):
		return
	Supplies.install_camera(idx, _cam_pos, _cam_normal, _cam_yaw)
	SoundBank.hammer_series(get_tree().current_scene, _cam_pos, 3)
	_hammer_taps(3)
	EventBus.notify("%s angebracht. Das Bild siehst du am Monitor im Wohnzimmer." % Inventory.display_name(type), 3.0)
	_cam_yaw = 0.0
	if Inventory.count(type) <= 0:
		stop()


func start(id: String) -> void:
	if Inventory.count(id) <= 0:
		return
	type = id
	active = true
	_cam_key = ""
	if _cam_preview:
		_cam_preview.queue_free()
		_cam_preview = null
	if _is_camera() or _is_planks():
		if _preview:
			_preview.queue_free()
			_preview = null
		return
	_make_preview()


func stop() -> void:
	active = false
	if _preview:
		_preview.queue_free()
		_preview = null
	if _cam_preview:
		_cam_preview.queue_free()
		_cam_preview = null
	EventBus.interaction_prompt_changed.emit("")
	var player := get_tree().get_first_node_in_group("player") as Player if is_inside_tree() else null
	if player:
		player.call("_update_prompt", true)


func _make_preview() -> void:
	if _preview:
		_preview.queue_free()
	_preview = Structure.new()
	_preview.type = type
	_preview.preview = true
	get_tree().current_scene.add_child(_preview)


func _unhandled_input(event: InputEvent) -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	if player == null or get_tree().paused or not active or player.input_locked:
		return
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return   # offenes Menü: nicht hindurch bauen
	if event.is_action_pressed("attack"):
		get_viewport().set_input_as_handled()
		if _is_planks():
			_board_up(player)
		elif _is_camera():
			_camera_place()
		else:
			_place()


## R: kurz tippen = drehen/schwenken (nur beim Bauen), halten auf einem Bauteil = abbauen.
func _process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	if player == null:
		return
	_follow_hotbar(player)
	var held := Input.is_action_pressed("interact_secondary") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED \
			and not player.input_locked and not get_tree().paused
	tick_r(delta, held, player)


## R-Taste auswerten (eigene Funktion, damit Tests sie ohne echte Tastatur aufrufen können).
func tick_r(delta: float, held: bool, player: Player) -> void:
	if held:
		if not _r_down:
			_r_down = true
			_r_time = 0.0
			_r_done = false
			_r_target = player.current_interactable if can_dismantle(player.current_interactable) else null
		_r_time += delta
		if _r_target != null and not _r_done:
			if not is_instance_valid(_r_target) or player.current_interactable != _r_target:
				_r_target = null
			elif _r_time >= TAP_TIME:
				var f := clampf((_r_time - TAP_TIME) / (DISMANTLE_HOLD - TAP_TIME), 0.0, 1.0)
				var n := int(round(f * 10.0))
				EventBus.interaction_prompt_changed.emit("Abbauen  " + "▮".repeat(n) + "▯".repeat(10 - n))
				if f >= 1.0:
					_r_done = true
					_r_target.secondary_interact(player)
					_r_target = null
					player.call("_update_prompt", true)
	elif _r_down:
		_r_down = false
		if active and not _r_done and _r_time < TAP_TIME:
			_rotate()
		_r_target = null


## Kann das Ziel mit gehaltenem R abgebaut werden?
static func can_dismantle(t: Node) -> bool:
	return t != null and is_instance_valid(t) and t.has_method("dismantle_hold") and bool(t.call("dismantle_hold"))


func _rotate() -> void:
	if _is_camera():
		# schwenken: -75° … +75° in 15°-Schritten
		_cam_yaw += deg_to_rad(15.0)
		if _cam_yaw > deg_to_rad(76.0):
			_cam_yaw = deg_to_rad(-75.0)
	elif not _is_planks():
		_rot += PI * 0.25


## Bauen folgt der Schnellleiste: Bauteil anwählen = Vorschau an, etwas anderes = aus.
func _follow_hotbar(player: Player) -> void:
	var eq := Inventory.equipped()
	if eq == _last_equipped:
		return
	_last_equipped = eq
	if eq != "" and is_build_item(eq):
		start(eq)
		_first_hint(eq)
	elif active:
		stop()


## Einmal pro Art erklären, wie Bauen aus der Hand geht.
func _first_hint(id: String) -> void:
	var key := "hint_build_" + ("planks" if id == "planks" else ("camera" if _is_camera() else "part"))
	if Tasks.flags.has(key):
		return
	Tasks.flag(key)
	if id == "planks":
		EventBus.notify("Bretter in der Hand: auf ein Fenster oder die Haustür schauen, Linksklick = zunageln (braucht Nägel).", 5.0)
	elif _is_camera():
		EventBus.notify("Kamera in der Hand: auf eine Außenwand zielen, Linksklick = anbringen, R = schwenken.", 5.0)
	else:
		EventBus.notify("Bauteil in der Hand: Linksklick = aufstellen, R = drehen. Gebautes abbauen: draufschauen und R halten.", 5.0)


## Hinweiszeile beim Bauen; E-Ziele bleiben sichtbar.
func _prompt(text: String, player: Player) -> void:
	if _r_target != null and _r_time >= TAP_TIME:
		return   # Abbau-Balken hat Vorrang
	var t := player.current_interactable
	if t and is_instance_valid(t):
		var line := String(t.get_prompt(player)).get_slice("\n", 0)
		if line != "":
			text += "\n" + line
		if can_dismantle(t):
			text += "   [R halten] abbauen"
	EventBus.interaction_prompt_changed.emit(text)


# --- Bretter: Fenster und Haustür ---------------------------------------

func _board_target(player: Player) -> Node:
	var t := player.current_interactable
	if t and is_instance_valid(t) and t.has_method("board_prompt") and String(t.call("board_prompt")) != "":
		return t
	return null


func _board_up(player: Player) -> void:
	var t := _board_target(player)
	if t == null:
		EventBus.notify("Mit Brettern kannst du Fenster verbarrikadieren und die Haustür reparieren – dazu draufschauen.", 3.0)
		return
	if bool(t.call("board_up")):
		_hammer_taps(3)


func _physics_process(_delta: float) -> void:
	if not active:
		return
	if Inventory.count(type) <= 0:
		stop()
		return
	var player := get_tree().get_first_node_in_group("player") as Player
	if player == null:
		return
	# Sitzen, Leiter, Menü: Vorschau ausblenden
	var idle := player.input_locked or GameState.dead
	if _preview:
		_preview.visible = not idle
	if _cam_preview:
		_cam_preview.visible = not idle
	if idle:
		return
	if _is_planks():
		var t := _board_target(player)
		if t:
			_prompt("Bretter  –  [Linksklick] " + String(t.call("board_prompt")), player)
		else:
			_prompt("Bretter  –  auf ein Fenster oder die Haustür schauen", player)
		return
	if _is_camera():
		_camera_update(player)
		return
	if _preview == null:
		return
	var cam := player.camera.global_transform
	var from := cam.origin
	var to := from - cam.basis.z * REACH
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.exclude = [player.get_rid()]
	var hit := player.get_world_3d().direct_space_state.intersect_ray(q)
	var p: Vector3 = hit["position"] if not hit.is_empty() else to
	p.x = snappedf(p.x, GRID)
	p.z = snappedf(p.z, GRID)
	p.y = Terrain.height_at(p.x, p.z)
	_pos = p
	_preview.global_position = p
	_preview.rotation.y = _rot
	_valid = _check_valid(p)
	_preview.set_preview_valid(_valid)
	_prompt("%s  –  [Linksklick] aufstellen   [R] drehen%s" % [Inventory.display_name(type), "" if _valid else "\nHier geht es nicht."], player)


func _build_type() -> String:
	return String(DataDB.item(type).get("build", type))


func _check_valid(p: Vector3) -> bool:
	# Nicht im Haus, auf der Veranda/Treppe oder im Schuppen – geprüft wird die ganze Grundfläche des Bauteils
	var size := _preview.size
	var ax := Vector3(cos(_rot), 0, -sin(_rot)) * size.x * 0.5
	var az := Vector3(sin(_rot), 0, cos(_rot)) * maxf(size.z, 0.3) * 0.5
	for c: Vector3 in [p, p + ax + az, p + ax - az, p - ax + az, p - ax - az, p + ax, p - ax]:
		for r: Rect2 in NO_BUILD:
			if r.has_point(Vector2(c.x, c.z)):
				return false
		if absf(c.x - Shed.ORIGIN.x) < Shed.HALF.x + 0.3 and absf(c.z - Shed.ORIGIN.z) < Shed.HALF.y + 0.3:
			return false
	# Zelt, Lagerfeuer, Fallen … dürfen überall stehen (Mehrtagesmärsche), alles andere nur im Tal um die Hütte
	var limit := 1095.0 if bool(DataDB.buildable(_build_type()).get("anywhere", false)) else 100.0
	if absf(p.x) > limit or absf(p.z) > limit:
		return false
	if Terrain.stream_distance(p.x, p.z) < 2.0:
		return false
	if Terrain.water_level_at(p.x, p.z) > p.y - 0.05:
		return false   # nicht im Wasser (Seen, Tümpel)
	# Nicht zu steil
	var dx := Vector3(cos(_rot), 0, -sin(_rot)) * size.x * 0.5
	var h1 := Terrain.height_at(p.x + dx.x, p.z + dx.z)
	var h2 := Terrain.height_at(p.x - dx.x, p.z - dx.z)
	if absf(h1 - h2) > 0.7:
		return false
	# Nicht auf anderen Bauten
	for s in get_tree().get_nodes_in_group("structure"):
		if (s as Node3D).global_position.distance_to(p) < 0.9:
			return false
	return true


func _place() -> void:
	if not _valid:
		EventBus.notify("Hier kannst du das nicht aufstellen.", 2.0)
		return
	if not Inventory.remove(type, 1):
		stop()
		return
	var build_type: String = DataDB.item(type).get("build", type)
	Builder.place(build_type, _pos, _rot)
	SoundBank.play_at(get_tree().current_scene, "place", _pos + Vector3(0, 0.5, 0), 0.0)
	_hammer_taps(1)
	EventBus.noise_made.emit(_pos, 14.0)
	if Inventory.count(type) <= 0:
		stop()


## Die linke Hand schlägt mit dem Bauhammer zu.
func _hammer_taps(hits: int) -> void:
	var p := get_tree().get_first_node_in_group("player") as Player
	if p and p.hands:
		p.hands.hammer_taps(hits)
