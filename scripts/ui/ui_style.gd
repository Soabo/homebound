class_name UiStyle
extends RefCounted
## Eigene Handschrift des Spiels (Christian 26.11.: „Notizbuch und Uhr“).
## Drei Schriften: Barlow Condensed = Menüs, Anzeigen, Tasten (schmal, ruhig) · Caveat = Christians Gedanken
## (Handschrift) · Special Elite = Schreibmaschine für Notizen, Intro, Überschriften auf Papier.
## Farben: Papier-Weiß statt reinem Weiß, Glut-Orange als Akzent, kaltes Blau für die Uhr.

const INK := Color(0.91, 0.87, 0.78)          ## Papier-Weiß (Haupttext)
const INK_DIM := Color(0.62, 0.6, 0.55)       ## ältere/unwichtige Zeilen
const EMBER := Color(0.9, 0.58, 0.3)          ## Akzent (Glut): Tasten, Markierungen
const WATCH := Color(0.55, 0.82, 0.95)        ## Uhr-Display
const DANGER := Color(0.86, 0.27, 0.2)        ## Gefahr
const PAPER := Color(0.08, 0.07, 0.06, 0.82)  ## dunkles Papier hinter Karten
const SHADOW := Color(0, 0, 0, 0.8)

const FONTS := {
	"ui": "res://assets/fonts/BarlowCondensed-Regular.ttf",
	"ui_bold": "res://assets/fonts/BarlowCondensed-Medium.ttf",
	"thought": "res://assets/fonts/Caveat.ttf",
	"type": "res://assets/fonts/SpecialElite-Regular.ttf",
}

static var _cache := {}


static func font(kind: String) -> Font:
	if _cache.has(kind):
		return _cache[kind]
	var f: Font = load(String(FONTS.get(kind, FONTS["ui"])))
	if kind == "thought":
		# Handschrift etwas kräftiger, sonst wird sie im dunklen Wald unlesbar
		var v := FontVariation.new()
		v.base_font = f
		v.variation_opentype = {"wght": 600}
		f = v
	_cache[kind] = f
	return f


## Beschriftung im Stil des Spiels: Schrift, Größe, Farbe, weicher dunkler Rand statt harter Kontur.
static func style(l: Control, kind: String, size: int, color: Color = INK, outline: int = 6) -> void:
	l.add_theme_font_override("font", font(kind))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if outline > 0:
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
		l.add_theme_constant_override("outline_size", outline)
		l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
		l.add_theme_constant_override("shadow_offset_x", 1)
		l.add_theme_constant_override("shadow_offset_y", 2)


static func label(parent: Node, kind: String, size: int, color: Color = INK, text: String = "") -> Label:
	var l := Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.text = text
	style(l, kind, size, color)
	if parent:
		parent.add_child(l)
	return l


## Dunkles Papier mit weicher Kante (Karten, Uhr-Liste, Tastenbild).
static func paper(alpha: float = 0.82, radius: int = 6, pad: int = 18) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(PAPER.r, PAPER.g, PAPER.b, alpha)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(pad)
	sb.border_color = Color(INK.r, INK.g, INK.b, 0.12)
	sb.set_border_width_all(1)
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 10
	return sb


## Taste als kleines Kästchen („E“, „Shift“, „Linksklick“) – für Tutorial und Tastenbild.
static func keycap(parent: Node, key: String, size: int = 20) -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.16, 0.14, 0.12, 0.95)
	sb.border_color = Color(EMBER.r, EMBER.g, EMBER.b, 0.85)
	sb.set_border_width_all(1)
	sb.border_width_bottom = 3
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 1
	sb.content_margin_bottom = 2
	p.add_theme_stylebox_override("panel", sb)
	var l := label(p, "ui_bold", size, INK, key)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_constant_override("outline_size", 0)
	l.add_theme_constant_override("shadow_offset_y", 0)
	if parent:
		parent.add_child(p)
	return p


## Eine Zeile „[Taste] Erklärung“ (mehrere Tasten mit „/“ getrennt).
static func key_row(parent: Node, keys: String, text: String, size: int = 20) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	for k in keys.split("/"):
		keycap(row, k.strip_edges(), size)
	var l := label(row, "ui", size + 1, INK, text)
	l.add_theme_constant_override("outline_size", 4)
	parent.add_child(row)
	return row


## Weich einblenden (leicht von unten hereinschweben).
static func fade_in(c: CanvasItem, seconds: float = 0.45, rise: float = 8.0) -> Tween:
	c.modulate.a = 0.0
	var tw := c.create_tween()
	tw.tween_property(c, "modulate:a", 1.0, seconds).set_trans(Tween.TRANS_SINE)
	if c is Control and rise != 0.0:
		var ctl := c as Control
		var y := ctl.position.y
		ctl.position.y = y + rise
		tw.parallel().tween_property(ctl, "position:y", y, seconds).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	return tw
