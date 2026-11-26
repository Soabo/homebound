class_name NeedsHud
extends Control
## Bedürfnisse als kleine Ringe unten links (Christian 26.11.: „Notizbuch und Uhr“).
## Ein Ring erscheint nur, wenn das Bedürfnis Aufmerksamkeit braucht; beim Blick auf die Uhr (J halten)
## stehen alle da, mit Namen. Darunter ein leiser Punkt für ungelesene Einträge auf der Uhr.

const R := 25.0           ## Ringradius
const STEP := 72.0        ## Abstand zwischen zwei Ringen
const ORDER := ["thirst", "hunger", "warmth", "stamina", "health"]
const NAMES := {"thirst": "Durst", "hunger": "Hunger", "warmth": "Wärme", "stamina": "Ausdauer", "health": "Gesundheit"}
const COLORS := {"thirst": Color(0.45, 0.72, 0.95), "hunger": Color(0.9, 0.66, 0.35), "warmth": Color(0.95, 0.6, 0.3),
	"stamina": Color(0.85, 0.85, 0.8), "health": Color(0.86, 0.3, 0.27)}
## ab wann ein Ring von selbst erscheint
const SHOW_BELOW := {"thirst": 55.0, "hunger": 55.0, "warmth": 55.0, "stamina": 97.0, "health": 75.0}

var values := {"thirst": 100.0, "hunger": 100.0, "warmth": 100.0, "stamina": 100.0, "health": 100.0}
var force_all := false    ## Uhr gehoben / Tutorial: alle zeigen
var unread := 0           ## ungelesene Einträge auf der Uhr
var _alpha := {}
var _x := {}
var _font: Font
var _font_small: Font


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_left = 34
	offset_top = -150
	offset_right = 420
	offset_bottom = -20
	_font = UiStyle.font("ui_bold")
	_font_small = UiStyle.font("ui")
	for k in ORDER:
		_alpha[k] = 0.0
		_x[k] = 0.0


func visible_needs() -> Array:
	_read_values()
	var out: Array = []
	for k in ORDER:
		if force_all or float(values[k]) < float(SHOW_BELOW[k]):
			out.append(k)
	return out


func _read_values() -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	values["thirst"] = Survival.thirst
	values["hunger"] = Survival.hunger
	values["warmth"] = Survival.warmth
	values["stamina"] = Survival.stamina
	values["health"] = player.health if player else 100.0


func _process(delta: float) -> void:
	_read_values()
	var player := get_tree().get_first_node_in_group("player") as Player
	var hands_up := player != null and player.hands != null and player.hands.log_raise > 0.4
	var all := force_all or hands_up
	var x := 0.0
	for k in ORDER:
		var want := all or float(values[k]) < float(SHOW_BELOW[k])
		_alpha[k] = move_toward(float(_alpha[k]), 1.0 if want else 0.0, delta * 2.2)
		_x[k] = lerpf(float(_x[k]), x, minf(1.0, delta * 8.0))
		x += STEP * smoothstep(0.0, 1.0, float(_alpha[k]))
	set_meta("labels", all)
	queue_redraw()


func _draw() -> void:
	var labels := bool(get_meta("labels", false))
	var t := Time.get_ticks_msec() / 1000.0
	for k in ORDER:
		var a := float(_alpha[k])
		if a <= 0.01:
			continue
		var v := clampf(float(values[k]) / 100.0, 0.0, 1.0)
		var c: Color = COLORS[k]
		if k == "warmth":
			c = Color(0.45, 0.72, 1.0).lerp(c, clampf(v / 0.6, 0.0, 1.0))   # kalt = blau
		var low := v < 0.2
		if low:
			c = c.lerp(UiStyle.DANGER, 0.5 + 0.5 * sin(t * 6.0))
		var ctr := Vector2(float(_x[k]) + R + 4.0, R + 6.0)
		# Unterlage, leerer Ring, gefüllter Teil (oben beginnend, im Uhrzeigersinn)
		draw_circle(ctr, R + 5.0, Color(0, 0, 0, 0.42 * a))
		draw_arc(ctr, R, 0.0, TAU, 48, Color(1, 1, 1, 0.13 * a), 3.0, true)
		if v > 0.005:
			draw_arc(ctr, R, -PI * 0.5, -PI * 0.5 + TAU * v, maxi(6, int(48 * v)), Color(c.r, c.g, c.b, a), 3.5, true)
		draw_set_transform(ctr, 0.0, Vector2(1.25, 1.25))
		_glyph(k, Vector2.ZERO, Color(c.r, c.g, c.b, 0.95 * a))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if labels:
			var name: String = NAMES[k]
			var w := _font_small.get_string_size(name, HORIZONTAL_ALIGNMENT_CENTER, -1, 18).x
			draw_string_outline(_font_small, ctr + Vector2(-w * 0.5, R + 26.0), name, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, 4, Color(0, 0, 0, 0.6 * a))
			draw_string(_font_small, ctr + Vector2(-w * 0.5, R + 26.0), name, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(UiStyle.INK.r, UiStyle.INK.g, UiStyle.INK.b, 0.85 * a))
	if unread > 0:
		# leiser Punkt: es steht etwas Neues auf der Uhr
		var x := 6.0
		for k in ORDER:
			x = maxf(x, float(_x[k]) + STEP * float(_alpha[k]) + 6.0)
		var p := Vector2(x + 6.0, R + 6.0)
		var pulse := 0.6 + 0.4 * sin(t * 2.5)
		draw_circle(p, 5.0, Color(UiStyle.EMBER.r, UiStyle.EMBER.g, UiStyle.EMBER.b, pulse))
		var s := "%d neu · J" % unread
		draw_string_outline(_font, p + Vector2(12, 7), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, 4, Color(0, 0, 0, 0.6))
		draw_string(_font, p + Vector2(12, 7), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(UiStyle.INK.r, UiStyle.INK.g, UiStyle.INK.b, 0.8))


## Kleine Zeichen in der Ringmitte (gezeichnet, keine Bilddateien).
func _glyph(k: String, c: Vector2, col: Color) -> void:
	match k:
		"thirst":   # Tropfen
			var pts := PackedVector2Array([c + Vector2(0, -10)])
			for i in 13:
				var a := -0.25 * PI + 1.5 * PI * i / 12.0
				pts.append(c + Vector2(cos(a) * 6.5, 3.0 + sin(a) * 6.5))
			draw_colored_polygon(pts, col)
		"hunger":   # Gabel
			for dx in [-3.5, 0.0, 3.5]:
				draw_line(c + Vector2(dx, -10), c + Vector2(dx, -3), col, 1.8, true)
			draw_arc(c + Vector2(0, -3), 3.5, 0.0, PI, 8, col, 1.8, true)
			draw_line(c + Vector2(0, 0.5), c + Vector2(0, 11), col, 2.4, true)
		"warmth":   # Flamme
			var f := PackedVector2Array([c + Vector2(0, -11), c + Vector2(4, -4), c + Vector2(7, 2), c + Vector2(5, 8),
				c + Vector2(0, 10), c + Vector2(-5, 8), c + Vector2(-7, 2), c + Vector2(-3, -2), c + Vector2(-2, -6)])
			draw_colored_polygon(f, col)
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -1), c + Vector2(3, 4), c + Vector2(0, 8), c + Vector2(-3, 4)]),
				Color(0.05, 0.04, 0.03, col.a * 0.8))
		"stamina":   # Blitz
			draw_colored_polygon(PackedVector2Array([c + Vector2(2, -11), c + Vector2(-6, 2), c + Vector2(-0.5, 2),
				c + Vector2(-2, 11), c + Vector2(6, -2), c + Vector2(0.5, -2)]), col)
		"health":   # Herz
			draw_circle(c + Vector2(-3.6, -2.5), 4.4, col)
			draw_circle(c + Vector2(3.6, -2.5), 4.4, col)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-7.9, -1.2), c + Vector2(7.9, -1.2), c + Vector2(0, 9)]), col)
