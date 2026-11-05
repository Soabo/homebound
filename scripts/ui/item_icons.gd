class_name ItemIcons
extends RefCounted
## Bildchen für Gegenstände im Inventar, auf den Schnellplätzen und in der Truhe.
## Ablage: assets/icons/items/<id>.png (oder .jpg / .webp), z. B. assets/icons/items/axe.png.
## Fehlt ein Bild, erscheint ein Platzhalter in der Farbe der Kategorie mit den Anfangsbuchstaben.

const DIR := "res://assets/icons/items/"
const CATEGORY_COLORS := {"Ressource": Color(0.45, 0.36, 0.24), "Nahrung": Color(0.3, 0.45, 0.25),
		"Werkzeug": Color(0.35, 0.38, 0.45), "Fund": Color(0.42, 0.3, 0.5), "Bauteil": Color(0.5, 0.38, 0.2)}

static var _cache: Dictionary = {}


## Das echte Bild, falls vorhanden (sonst null).
static func texture(id: String) -> Texture2D:
	if _cache.has(id):
		return _cache[id]
	var tex: Texture2D = null
	for ext: String in ["png", "jpg", "jpeg", "webp"]:
		var path := DIR + id + "." + ext
		if ResourceLoader.exists(path):
			tex = load(path) as Texture2D
			break
	_cache[id] = tex
	return tex


## Ein fertiges Bildchen (oder Platzhalter) in der gewünschten Größe.
static func make(id: String, size: float) -> Control:
	var tex := texture(id)
	if tex:
		var r := TextureRect.new()
		r.texture = tex
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		r.custom_minimum_size = Vector2(size, size)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return r
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(size, size)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var st := StyleBoxFlat.new()
	st.bg_color = CATEGORY_COLORS.get(String(DataDB.item(id).get("category", "")), Color(0.3, 0.3, 0.3))
	st.set_corner_radius_all(int(size * 0.18))
	st.border_color = st.bg_color.lightened(0.25)
	st.set_border_width_all(1)
	p.add_theme_stylebox_override("panel", st)
	var l := Label.new()
	var title := String(DataDB.item(id).get("name", id))
	var parts := title.split(" ", false)
	l.text = (parts[0].left(1) + (parts[1].left(1) if parts.size() > 1 else parts[0].substr(1, 1))).to_upper() if not parts.is_empty() else "?"
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", int(size * 0.38))
	l.add_theme_color_override("font_color", Color(0.95, 0.92, 0.85, 0.85))
	p.add_child(l)
	return p
