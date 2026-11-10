class_name Wildlife
extends Node3D
## Lebendige Tierwelt rund um den Spieler. Tiere tauchen außerhalb des Blickfelds auf und verschwinden wieder.
##  Tag:   Hasen, Nattern, Eichhörnchen an den Bäumen, kleine Vögel am Boden, Schmetterlinge, Mückenschwärme,
##         Krähen und Bussarde über dem Tal; Zugvögel in Scharen, sobald die Tiere das Tal verlassen.
##  Nacht: ein, zwei Rehe im Wald (im Dunkeln nur Umriss und Augen), Fuchs, Igel. Rehe fliehen vor der Kreatur.
## Je weiter sich das Tal verwandelt, desto weniger Tiere. Ist etwas Fremdes in der Nähe, verschwinden sie.
## Werte: data/world/wildlife.tres (WildlifeConfig).

const CONFIG_PATH := "res://data/world/wildlife.tres"

var cfg: WildlifeConfig
var _player: Player
var _rng := RandomNumberGenerator.new()
var _ground_timer: float = 5.0
var _air_timer: float = 20.0
var _flock_timer: float = 15.0
var _night_timer: float = 30.0
var _small_timer: float = 2.0
var _silent_until: float = 0.0
var _t: float = 0.0


func _ready() -> void:
	name = "Wildlife"
	add_to_group("nature_ambience")
	_rng.randomize()
	cfg = load(CONFIG_PATH) as WildlifeConfig
	if cfg == null:
		cfg = WildlifeConfig.new()


## Etwas Fremdes ist in der Nähe: Tiere fliehen, eine Weile kommt keins.
func silence_for(seconds: float) -> void:
	_silent_until = maxf(_silent_until, _t + seconds)
	for a in get_children():
		var an := a as Animal
		if an and an.kind in ["hare", "deer", "fox", "snake"]:
			an.call("_flee_from", _player.global_position if _player else an.global_position + Vector3.ONE, 8.0)


func _process(delta: float) -> void:
	_t += delta
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Player
		if _player == null:
			return
	if TimeManager.fast_forward or _t < _silent_until:
		return
	var factor := _stage_factor()
	if factor <= 0.0:
		return
	var night := TimeManager.is_night()
	var hour := TimeManager.hour
	if night:
		_night_timer -= delta
		if _night_timer <= 0.0:
			_night_timer = _rng.randf_range(cfg.night_spawn_interval.x, cfg.night_spawn_interval.y) / factor
			if _count(func(a: Animal) -> bool: return a.is_night_kind()) < cfg.max_night_animals:
				_spawn_night()
		return
	# Bodentiere
	_ground_timer -= delta
	if _ground_timer <= 0.0:
		_ground_timer = _rng.randf_range(cfg.day_spawn_interval.x, cfg.day_spawn_interval.y) / factor
		if _count(func(a: Animal) -> bool: return a.is_ground_kind()) < int(ceil(cfg.max_ground_animals * factor)):
			_spawn_ground()
	# Schmetterlinge und Mücken in der Nähe
	_small_timer -= delta
	if _small_timer <= 0.0:
		_small_timer = _rng.randf_range(3.0, 8.0)
		if hour >= cfg.butterfly_hours.x and hour <= cfg.butterfly_hours.y \
				and _count(func(a: Animal) -> bool: return a.kind == "butterfly") < int(ceil(cfg.max_butterflies * factor)):
			_spawn_small("butterfly")
		elif _count(func(a: Animal) -> bool: return a.kind == "insects") < int(ceil(cfg.max_insect_swarms * factor)):
			_spawn_small("insects")
	# Vögel am Himmel
	_air_timer -= delta
	if _air_timer <= 0.0:
		_air_timer = _rng.randf_range(cfg.flyover_interval.x, cfg.flyover_interval.y) / factor
		_spawn_flyer("flyover")
	var st := WorldState.stage()
	if st >= cfg.migration_from_stage and st <= cfg.migration_until_stage:
		_flock_timer -= delta
		if _flock_timer <= 0.0:
			_flock_timer = _rng.randf_range(cfg.migration_interval.x, cfg.migration_interval.y)
			_spawn_flyer("flock")


func _stage_factor() -> float:
	var st := WorldState.stage()
	if cfg.stage_factor.is_empty():
		return 1.0
	return cfg.stage_factor[clampi(st, 0, cfg.stage_factor.size() - 1)]


func _count(pred: Callable) -> int:
	var n := 0
	for a in get_children():
		if a is Animal and pred.call(a):
			n += 1
	return n


func _pick(weights: Dictionary) -> String:
	var total := 0.0
	for k: String in weights:
		total += float(weights[k])
	var r := _rng.randf() * total
	for k: String in weights:
		r -= float(weights[k])
		if r <= 0.0:
			return k
	return weights.keys()[0]


## Ein Punkt am Boden, außerhalb des Blickfelds (oder weit weg), nicht im Haus.
func _spot(dmin: float, dmax: float, forest: bool) -> Vector3:
	var cam := _player.camera.global_transform
	var fwd := -cam.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	for i in 20:
		var a := _rng.randf() * TAU
		var dir := Vector3(cos(a), 0, sin(a))
		var d := _rng.randf_range(dmin, dmax)
		if fwd.dot(dir) > 0.35 and d < 34.0:
			continue
		var p := _player.global_position + dir * d
		if Animal._blocked(p):
			continue
		if forest and Terrain.yard_distance(p.x, p.z) < 6.0:
			continue
		return Vector3(p.x, Terrain.height_at(p.x, p.z), p.z)
	return Vector3.INF


func _add(kind: String, at: Vector3) -> Animal:
	var a := Animal.new()
	a.kind = kind
	a.cfg = cfg
	a.name = "Animal_%s_%d" % [kind, _rng.randi() % 100000]
	a.position = at  # Wildlife liegt im Ursprung
	add_child(a)
	return a


func _spawn_ground() -> void:
	var kind := _pick({"hare": cfg.hare_weight, "snake": cfg.snake_weight, "squirrel": cfg.squirrel_weight, "birds": cfg.ground_birds_weight})
	if kind == "squirrel":
		var t := _tree_spot()
		if t == Vector4.ZERO:
			return
		var a := Animal.new()
		a.kind = "squirrel"
		a.cfg = cfg
		a.tree = t
		a.lifetime = _rng.randf_range(60.0, 120.0)
		a.position = Vector3(t.x, t.y + 1.5, t.z)  # Wildlife liegt im Ursprung
		add_child(a)
		return
	var p := _spot(cfg.spawn_distance.x, cfg.spawn_distance.y, false)
	if p == Vector3.INF:
		return
	var a := _add(kind, p)
	a.lifetime = _rng.randf_range(60.0, 140.0)


func _tree_spot() -> Vector4:
	var best: Array[Vector4] = []
	var pp := _player.global_position
	for t in Forest.trees:
		var d := Vector2(t.x - pp.x, t.z - pp.z).length()
		if d > 14.0 and d < 34.0:
			best.append(t)
			if best.size() > 40:
				break
	if best.is_empty():
		return Vector4.ZERO
	return best[_rng.randi() % best.size()]


func _spawn_small(kind: String) -> void:
	var p := _spot(10.0, 26.0, false)
	if p == Vector3.INF:
		return
	# Mücken lieber am Bach oder Waldrand
	if kind == "insects" and _rng.randf() < 0.6:
		var z := clampf(_player.global_position.z + _rng.randf_range(-20, 20), Terrain.STREAM_START + 10.0, WorldMap.limit() - 5.0)
		var sx := Terrain.stream_x_at(z) + _rng.randf_range(-3.0, 3.0)
		if Vector2(sx - _player.global_position.x, z - _player.global_position.z).length() < 45.0:
			p = Vector3(sx, Terrain.height_at(sx, z), z)
	var a := _add(kind, p + Vector3(0, 0.6 if kind == "butterfly" else 0.0, 0))
	a.lifetime = _rng.randf_range(50.0, 110.0)


func _spawn_flyer(kind: String) -> void:
	var dir: Vector3
	if kind == "flock":
		dir = Vector3(cfg.migration_direction.x, 0, cfg.migration_direction.y).normalized()
	else:
		var a := _rng.randf() * TAU
		dir = Vector3(cos(a), 0, sin(a))
	# Start hinter dem Horizont, Bahn führt am Spieler vorbei
	var side := Vector3(-dir.z, 0, dir.x) * _rng.randf_range(-30.0, 30.0)
	var start := _player.global_position - dir * 160.0 + side
	start.y = Terrain.height_at(start.x, start.z) + (_rng.randf_range(45.0, 70.0) if kind == "flock" else _rng.randf_range(25.0, 40.0))
	var a := Animal.new()
	a.kind = kind
	a.cfg = cfg
	a.fly_dir = dir
	a.flock_size = _rng.randi_range(cfg.migration_flock_size.x, cfg.migration_flock_size.y)
	a.lifetime = 45.0
	a.position = start  # Wildlife liegt im Ursprung
	add_child(a)
	if a.has_meta("circle"):
		# Bussard kreist über einer Lichtung in der Nähe
		var c := _player.global_position + Vector3(_rng.randf_range(-40, 40), 0, _rng.randf_range(-40, 40))
		c.y = Terrain.height_at(c.x, c.z) + 35.0
		a.global_position = c
	a.set_meta("center", a.global_position)


func _spawn_night() -> void:
	var kind := _pick({"deer": cfg.deer_weight, "fox": cfg.fox_weight, "hedgehog": cfg.hedgehog_weight})
	match kind:
		"deer":
			var p := _spot(28.0, 45.0, true)
			if p == Vector3.INF:
				return
			for i in _rng.randi_range(cfg.deer_group.x, cfg.deer_group.y):
				var q := p + Vector3(_rng.randf_range(-3, 3), 0, _rng.randf_range(-3, 3))
				var a := _add("deer", Vector3(q.x, Terrain.height_at(q.x, q.z), q.z))
				a.lifetime = _rng.randf_range(90.0, 160.0)
		"fox":
			var p := _spot(20.0, 35.0, true)
			if p != Vector3.INF:
				_add("fox", p).lifetime = _rng.randf_range(50.0, 90.0)
		"hedgehog":
			# Igel im Garten oder am Zaun
			var p := _spot(8.0, 20.0, false)
			if p != Vector3.INF:
				_add("hedgehog", p).lifetime = _rng.randf_range(80.0, 150.0)


## Für Tests: ein Tier jeder Art direkt erzeugen.
func spawn_test(kind: String, at: Vector3) -> Animal:
	if kind == "squirrel":
		var t := _tree_spot()
		var a := Animal.new()
		a.kind = kind
		a.cfg = cfg
		a.tree = t if t != Vector4.ZERO else Vector4(at.x, at.y, at.z, 0.3)
		add_child(a)
		return a
	if kind in ["flyover", "flock"]:
		var a := Animal.new()
		a.kind = kind
		a.cfg = cfg
		a.position = at + Vector3(0, 30, 0)  # Wildlife liegt im Ursprung
		add_child(a)
		a.set_meta("center", a.global_position)
		return a
	return _add(kind, at)
