class_name Stealth
extends RefCounted
## Schleichen (Christian 14.11.2026): Alles läuft über zwei Fragen – wie laut bin ich, wie gut bin ich zu sehen?
##  - Hören: Schritte je Gangart und Untergrund (Laub, Kies, Wasser laut; Teppich, Erde leise), knarrende Dielen
##    im Haus, Äste im Wald. Wind-Böen und Regen übertönen. Atem: Alt hält ihn an (und lässt langsam gehen).
##  - Sehen: Dunkelheit, Mondlicht, Schatten unter Bäumen, eigenes Licht, Lampen/Feuer, beleuchtetes Fenster,
##    geduckt. Lehnen: Hinter einer Kante schaut nur der Kopf hervor.
## Die Gegner sammeln daraus Verdacht in Stufen (`Awareness`). Werte: data/stealth/stealth.tres (`StealthConfig`).

const HOUSE := "res://data/house/house.json"

static var _boards: Array = []
static var _boards_loaded := false


static func cfg() -> StealthConfig:
	return StealthConfig.get_default()


# --- Hören ------------------------------------------------------------------

## Wie viel Wind und Regen an diesem Ort übertönen (0..mask_max).
static func mask_at(p: Vector3) -> float:
	var c := cfg()
	var inside := Cabin.is_inside(p) or Shed.is_inside(p)
	var mw := 0.0
	if Wind.current and not inside:
		mw = smoothstep(c.wind_mask_from, c.wind_mask_full, Wind.current.at(p)) * c.wind_mask_max
	var mr := 0.0
	match WorldState.weather:
		"rain": mr = c.rain_mask
		"storm": mr = c.storm_mask
	if inside:
		mr *= 0.5
	return minf(1.0 - (1.0 - mw) * (1.0 - mr), c.mask_max)


## Hörweite eines Schritts. gait: sneak | slow | walk | run
static func step_radius(p: Vector3, gait: String, surface: String) -> float:
	var c := cfg()
	var r: float = {"sneak": c.step_sneak, "slow": c.step_slow, "walk": c.step_walk, "run": c.step_run}.get(gait, c.step_walk)
	r *= float(c.surface_factor.get(surface, 1.0))
	if Cabin.is_inside(p) or Shed.is_inside(p):
		r *= c.indoor_factor
	return r * (1.0 - mask_at(p))


## Knarrende Diele an dieser Stelle? (data/house/house.json „creaky_boards“: x, z, r, attic)
static func creaky_board(p: Vector3) -> bool:
	if not Cabin.is_inside(p):
		return false
	var attic := p.y > Cabin.WALL_TOP - 0.2
	for b: Dictionary in boards():
		if bool(b.get("attic", false)) != attic:
			continue
		if Vector2(p.x - float(b["x"]), p.z - float(b["z"])).length() < float(b.get("r", 0.45)):
			return true
	return false


static func boards() -> Array:
	if not _boards_loaded:
		_boards_loaded = true
		_boards = DataDB.load_json(HOUSE).get("creaky_boards", [])
	return _boards


## Wie weit hört man den Atem des Spielers (0 = angehalten)?
static func breath_radius(pl: Player) -> float:
	if pl == null or pl.holding_breath:
		return 0.0
	# Große Angst: man atmet so schwer wie nach dem Rennen (Fear)
	var r := cfg().breath_radius_panting if pl.panting() or pl.fear.betrays_breath() else cfg().breath_radius
	return r * pl.fear.breath_factor()


# --- Sehen ------------------------------------------------------------------

## Dichte der Baumkronen über einem Punkt (0..1): Schatten im Mond- und Tageslicht.
static func canopy(p: Vector3) -> float:
	if Terrain.yard_distance(p.x, p.z) < 4.0 or Terrain.road_distance(p.x, p.z) < 3.0:
		return 0.0
	var d := WorldMap.tree_density(p.x, p.z, p.y)
	if Terrain.stream_distance(p.x, p.z) < 3.2:
		d *= 0.3
	return clampf(d, 0.0, 1.0)


## Mondlicht am Ort (0..1): wie hoch und frei der Mond gerade steht.
static func moonlight() -> float:
	var env := DayNightEnvironment.current
	if env == null or env.moon == null or not env.moon.visible:
		return 0.0
	return clampf(env.moon.light_energy / 0.25, 0.0, 1.0)


## Tageslicht (0 = Nacht, 1 = heller Tag).
static func daylight() -> float:
	return smoothstep(-6.0, 6.0, DayNightEnvironment.sun_altitude_deg(TimeManager.hour))


## Brennt eine Lampe oder ein Feuer in der Nähe?
static func near_light(tree: SceneTree, p: Vector3, radius: float = -1.0) -> bool:
	var r := cfg().near_light_range if radius < 0.0 else radius
	if PowerManager.has_power():
		for sw in tree.get_nodes_in_group("light_switch"):
			if sw.get("is_on") and (sw as Node3D).global_position.distance_to(p) < r:
				return true
	for f in tree.get_nodes_in_group("campfire"):
		if f.has_method("burning") and f.call("burning") and (f as Node3D).global_position.distance_to(p) < r:
			return true
	for f in tree.get_nodes_in_group("heat_source"):
		if f is Fireplace and float(f.call("strength")) > 0.2 and (f as Node3D).global_position.distance_to(p) < r:
			return true
	return false


## Sichtbarkeit des Spielers 0..1 (wird jedes Bild im Player gerechnet: `Player.visibility`).
static func visibility(pl: Player) -> float:
	var c := cfg()
	var p := pl.global_position
	if pl.light_shining():
		return c.vis_own_light
	var lamp := near_light(pl.get_tree(), p)
	var v: float
	if Cabin.is_inside(p) or Shed.is_inside(p):
		v = c.vis_inside_lit if lamp else c.vis_inside_dark
	else:
		var shade := 1.0 - canopy(p) * c.canopy_shade
		var sky := maxf(c.vis_dark + c.vis_moon * moonlight() * shade, c.vis_day * daylight() * shade)
		v = maxf(sky, c.vis_dark)
		if lamp:
			v = maxf(v, c.vis_near_light)
		if AirFx.breath_cloud_until > Time.get_ticks_msec():
			v += c.breath_cloud_bonus
	if pl.crouching():
		v *= c.crouch_factor
	if Vector2(pl.velocity.x, pl.velocity.z).length() > pl.walk_speed + 0.5:
		v += c.run_bonus
	return clampf(v, 0.0, 1.0)


## Wie weit ein Gegner bei dieser Sichtbarkeit sieht (zwischen sight_min und sight_max, mal Faktor).
static func sight_range(vis: float, factor: float = 1.0) -> float:
	return lerpf(cfg().sight_min, cfg().sight_max, vis) * factor


## Freie Sicht zwischen zwei Punkten? Fensterglas lässt durch, Bretter und Wände nicht.
static func line_clear(world: World3D, from: Vector3, to: Vector3, exclude: Array) -> bool:
	var ex: Array = exclude.duplicate()
	for _i in 4:
		var q := PhysicsRayQueryParameters3D.create(from, to)
		q.exclude = ex
		var hit := world.direct_space_state.intersect_ray(q)
		if hit.is_empty():
			return true
		var col := hit["collider"] as CollisionObject3D
		if col and col.is_in_group("see_through"):
			ex.append(col.get_rid())
			continue
		return false
	return false


## Wie viel vom Spieler sieht man von `eye` aus? 1 = Körper frei, peek_* = nur der Kopf schaut hervor, 0 = verdeckt.
static func seen_part(world: World3D, eye: Vector3, pl: Player) -> float:
	var ex := [pl.get_rid()]
	var chest := pl.global_position + Vector3(0, pl.body_height() * 0.6, 0)
	if line_clear(world, eye, chest, ex):
		return 1.0
	if line_clear(world, eye, pl.camera.global_position, ex):
		return cfg().peek_lean if pl.leaning() else cfg().peek_head
	return 0.0
