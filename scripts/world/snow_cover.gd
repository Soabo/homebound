class_name SnowCover
extends RefCounted
## Schnee und Raureif auf Dingen mit normalem Material (Dächer, Felsen, liegende Stämme, Polter, Blechdächer):
## Diese Materialien melden sich hier an und bekommen einen zweiten Durchgang (shaders/snow_overlay.gdshader).
## Ohne Schnee und Reif ist der Durchgang abgehängt (kostet dann nichts). Boden und Pflanzen machen es selbst im Shader.

static var _mats: Array[BaseMaterial3D] = []
static var _overlay: ShaderMaterial
static var active: bool = false


static func overlay() -> ShaderMaterial:
	if _overlay == null:
		_overlay = ShaderMaterial.new()
		_overlay.shader = load("res://shaders/snow_overlay.gdshader")
	return _overlay


## Material bekommt Schnee, sobald welcher liegt. Gibt das Material zurück (zum Verketten).
static func register(m: BaseMaterial3D) -> BaseMaterial3D:
	if m == null or _mats.has(m):
		return m
	_mats.append(m)
	m.next_pass = overlay() if active else null
	return m


## Vom Wind-Knoten jedes Bild aufgerufen: hängt den Durchgang an oder ab.
static func update(snow: float, frost: float) -> void:
	var want := snow > 0.02 or frost > 0.05
	if want == active:
		return
	active = want
	for m in _mats:
		if is_instance_valid(m):
			m.next_pass = overlay() if active else null


static func count() -> int:
	return _mats.size()
