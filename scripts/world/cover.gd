class_name Cover
extends RefCounted
## Dichte Gebüsche, in denen man sich verstecken kann (Christian, 13.11.2026).
## Tal (`Forest`) und großer Wald (`WildForest`, je nahes Stück) tragen ihre großen Büsche hier ein.
## `Player.is_concealed()` fragt `at()`: geduckt (oder im sehr hohen Gebüsch), ohne Licht und fast still = getarnt.
## Gegner wittern einen dann erst aus `cover_sniff_range` (ihre Config).

const CELL := 8.0

static var _cells: Dictionary = {}    ## Vector2i -> Array[[Vector4(x, z, Radius, Höhe), Besitzer]]
static var _owners: Dictionary = {}   ## Besitzer (Stück-Schlüssel) -> Array[Vector2i]


static func add(owner: Variant, x: float, z: float, radius: float, height: float) -> void:
	var c := Vector2i(int(floorf(x / CELL)), int(floorf(z / CELL)))
	if not _cells.has(c):
		_cells[c] = []
	(_cells[c] as Array).append([Vector4(x, z, radius, height), owner])
	if not _owners.has(owner):
		_owners[owner] = []
	(_owners[owner] as Array).append(c)


## Alle Büsche eines Besitzers austragen (Stück wird entladen).
static func remove_owner(owner: Variant) -> void:
	if not _owners.has(owner):
		return
	var touched := {}
	for c: Vector2i in _owners[owner]:
		touched[c] = true
	_owners.erase(owner)
	for c: Vector2i in touched:
		if not _cells.has(c):
			continue
		var keep: Array = []
		for e: Array in _cells[c]:
			if typeof(e[1]) != typeof(owner) or e[1] != owner:
				keep.append(e)
		if keep.is_empty():
			_cells.erase(c)
		else:
			_cells[c] = keep


static func clear() -> void:
	_cells.clear()
	_owners.clear()


## Höhe des dichtesten Gebüschs, in dessen Kern der Punkt liegt (0 = keins).
static func at(pos: Vector3) -> float:
	var best := 0.0
	var cx := int(floorf(pos.x / CELL))
	var cz := int(floorf(pos.z / CELL))
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var c := Vector2i(cx + dx, cz + dz)
			if not _cells.has(c):
				continue
			for e: Array in _cells[c]:
				var b: Vector4 = e[0]
				var d := Vector2(pos.x - b.x, pos.z - b.y).length()
				if d < b.z * 0.85:
					best = maxf(best, b.w)
	return best


static func count() -> int:
	var n := 0
	for c: Vector2i in _cells:
		n += (_cells[c] as Array).size()
	return n


## Nächstes dichtes Gebüsch zu einem Punkt (für Tests): Vector4(x, z, Radius, Höhe) oder Vector4.ZERO.
static func nearest(pos: Vector3) -> Vector4:
	var best := Vector4.ZERO
	var bd := INF
	for c: Vector2i in _cells:
		for e: Array in _cells[c]:
			var b: Vector4 = e[0]
			var d := Vector2(pos.x - b.x, pos.z - b.y).length()
			if d < bd:
				bd = d
				best = b
	return best
