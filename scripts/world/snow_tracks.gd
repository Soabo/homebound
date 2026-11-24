class_name SnowTracks
extends Node3D
## Spuren im Schnee (Etappe 2, Spätherbst): eigene Stiefelabdrücke und die Abdrücke der Wesen
## (Kreatur, Zerfleischer, Sucher, Wechselbalg). Sie verblassen über track_hours und verschwinden unter Neuschnee
## (track_cover_snow) oder wenn der Schnee taut. Werte: WorldConfig track_*.
## Zwei Sammel-Netze (Stiefel, Krallen) mit Ringpuffer – kostet kaum etwas.

const MAX := 500
const CREATURE_GROUPS := {"creature": 1.0, "mauler": 1.35, "seeker": 1.7, "changeling": 0.9}

static var current: SnowTracks

var _boot: Ring
var _claw: Ring
var _last_pos: Dictionary = {}   ## Instanz-ID -> [letzte Spurposition, links/rechts]
var _fade_t: float = 0.0
var _left := false


class Ring:
	extends RefCounted
	var mmi: MultiMeshInstance3D
	var born: PackedFloat32Array = PackedFloat32Array()   ## Spielstunde
	var fallen: PackedFloat32Array = PackedFloat32Array()  ## snowfall_total beim Abdruck
	var alpha: PackedFloat32Array = PackedFloat32Array()   ## aktuelle Deckkraft (auch ohne Grafik lesbar)
	var next: int = 0
	var used: int = 0


func _ready() -> void:
	name = "SnowTracks"
	current = self
	_boot = _make_ring("Boots", _boot_texture(), Vector2(0.15, 0.33))
	_claw = _make_ring("Claws", _claw_texture(), Vector2(0.34, 0.6))
	var pl := get_tree().get_first_node_in_group("player")
	if pl and pl.has_signal("stepped"):
		pl.connect("stepped", _on_player_step)
	else:
		call_deferred("_connect_player")


func _connect_player() -> void:
	var pl := get_tree().get_first_node_in_group("player")
	if pl and pl.has_signal("stepped") and not pl.is_connected("stepped", _on_player_step):
		pl.connect("stepped", _on_player_step)


func _exit_tree() -> void:
	if current == self:
		current = null


func _make_ring(n: String, tex: Texture2D, size: Vector2) -> Ring:
	var r := Ring.new()
	var mesh := PlaneMesh.new()
	mesh.size = size
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	# weich gefiltert mit Mipmaps: kleine Abdrücke verschwinden aus der Ferne nicht einfach zwischen den Pixeln
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.roughness = 1.0
	mesh.material = m
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = MAX
	mm.visible_instance_count = 0
	r.mmi = MultiMeshInstance3D.new()
	r.mmi.name = n
	r.mmi.multimesh = mm
	r.mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Abdrücke liegen überall auf der Karte: feste, große Hülle (sonst wird das Netz falsch weggeschnitten)
	r.mmi.custom_aabb = AABB(Vector3(-1200, -300, -1200), Vector3(2400, 900, 2400))
	add_child(r.mmi)
	r.born.resize(MAX)
	r.fallen.resize(MAX)
	r.alpha.resize(MAX)
	return r


## Liegt hier genug Schnee für einen Abdruck? (draußen, nicht im Wasser, nicht auf Veranda/Haus)
static func can_print(p: Vector3) -> bool:
	if WorldState.snow < WorldState.config.track_min_snow:
		return false
	if Cabin.is_inside(p) or Shed.is_inside(p) or Cabin.blocks_ground(p):
		return false
	var g := Terrain.height_at(p.x, p.z)
	if absf(p.y - g) > 0.6 or Terrain.water_level_at(p.x, p.z) > g - 0.05:
		return false
	return true


func _on_player_step(_gait: String, pos: Vector3) -> void:
	if not can_print(pos):
		return
	var pl := get_tree().get_first_node_in_group("player") as Node3D
	var yaw := pl.global_rotation.y if pl else 0.0
	_left = not _left
	var side := Vector3(cos(yaw), 0, -sin(yaw)) * (0.12 if _left else -0.12)
	add_print(_boot, pos + side, yaw, 1.0)


## Abdruck setzen (auch für Tests): ring = Stiefel oder Krallen, yaw = Blickrichtung (wie Node3D.rotation.y).
func add_print(r: Ring, p: Vector3, yaw: float, scale: float) -> void:
	var i := r.next
	r.next = (r.next + 1) % MAX
	r.used = mini(r.used + 1, MAX)
	var g := Terrain.height_at(p.x, p.z)
	var b := Basis(Vector3.UP, yaw).scaled(Vector3(scale, 1.0, scale))
	r.mmi.multimesh.set_instance_transform(i, Transform3D(b, Vector3(p.x, g + 0.06, p.z)))
	r.mmi.multimesh.set_instance_color(i, Color(0.15, 0.17, 0.24, 0.95))
	r.mmi.multimesh.visible_instance_count = r.used
	r.born[i] = TimeManager.get_total_hours()
	r.fallen[i] = WorldState.snowfall_total
	r.alpha[i] = 0.95


func boots() -> Ring:
	return _boot


func claws() -> Ring:
	return _claw


## Wie viele Abdrücke gerade zu sehen sind (Tests)
func visible_count(r: Ring) -> int:
	var n := 0
	for i in r.used:
		if r.alpha[i] > 0.02:
			n += 1
	return n


func _process(delta: float) -> void:
	# Wesen: alle paar Schritte ein Abdruck
	for grp: String in CREATURE_GROUPS:
		var stride: float = 0.85 * float(CREATURE_GROUPS[grp])
		for n in get_tree().get_nodes_in_group(grp):
			var c := n as Node3D
			if c == null or not c.visible:
				continue
			var id := c.get_instance_id()
			var p := c.global_position
			if not _last_pos.has(id):
				_last_pos[id] = [p, false]
				continue
			var e: Array = _last_pos[id]
			var last: Vector3 = e[0]
			var d := Vector2(p.x - last.x, p.z - last.z)
			if d.length() < stride:
				continue
			e[0] = p
			if d.length() > 6.0:
				continue   # Teleporterblitz / versetzt: keine Spur dazwischen
			e[1] = not bool(e[1])
			if can_print(p):
				var yaw := atan2(-d.x, -d.y)
				var side := Vector3(cos(yaw), 0, -sin(yaw)) * (0.2 if bool(e[1]) else -0.2) * float(CREATURE_GROUPS[grp])
				add_print(_claw, p + side, yaw, float(CREATURE_GROUPS[grp]))
	# Verblassen (einmal pro Sekunde): Alter, Neuschnee, Tauwetter
	_fade_t -= delta
	if _fade_t > 0.0:
		return
	_fade_t = 1.0
	var cfg := WorldState.config
	var now := TimeManager.get_total_hours()
	var melt := clampf((WorldState.snow - cfg.track_min_snow * 0.6) / (cfg.track_min_snow * 0.4), 0.0, 1.0)
	for r: Ring in [_boot, _claw]:
		for i in r.used:
			var age := clampf(1.0 - (now - r.born[i]) / cfg.track_hours, 0.0, 1.0)
			var cover := clampf(1.0 - (WorldState.snowfall_total - r.fallen[i]) / cfg.track_cover_snow, 0.0, 1.0)
			var a := 0.95 * age * cover * melt
			if absf(a - r.alpha[i]) > 0.004:
				r.alpha[i] = a
				r.mmi.multimesh.set_instance_color(i, Color(0.15, 0.17, 0.24, a))
	# alte Namen von Wesen, die es nicht mehr gibt, wegräumen
	for id: int in _last_pos.keys():
		if not is_instance_id_valid(id):
			_last_pos.erase(id)


# --- Bilder der Abdrücke (klein, Pixel) ---------------------------------------------------------------

static func _boot_texture() -> Texture2D:
	var img := Image.create(16, 36, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 0))
	for y in 36:
		for x in 16:
			var u := (x + 0.5) / 16.0 * 2.0 - 1.0
			# Sohle (vorn breit) und Absatz, dazwischen eine Lücke
			var sole := y < 23 and u * u / 0.9 + pow((y - 11.0) / 11.5, 2.0) < 1.0
			var heel := y > 25 and u * u / 0.6 + pow((y - 30.5) / 5.0, 2.0) < 1.0
			if sole or heel:
				var groove := 0.75 if (y % 4 == 0 and sole) else 1.0
				img.set_pixel(x, y, Color(groove, groove, groove, 1.0))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


static func _claw_texture() -> Texture2D:
	var img := Image.create(24, 40, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 0))
	# Ballen hinten, drei lange Zehen mit Krallenspitzen nach vorn (oben im Bild)
	for y in 40:
		for x in 24:
			var on := pow((x - 12.0) / 8.0, 2.0) + pow((y - 30.0) / 8.0, 2.0) < 1.0
			for toe: float in [-7.0, 0.0, 7.0]:
				var tx := 12.0 + toe * (1.0 - (y - 4.0) / 60.0)
				if y > 2 and y < 26 and absf(x - tx) < 3.0 - (26.0 - y) * 0.05:
					on = true
			if on:
				img.set_pixel(x, y, Color(1, 1, 1, 1))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)
