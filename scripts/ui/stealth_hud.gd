class_name StealthHud
extends Control
## Schleich-Anzeige über dem Schnellplatz (abschaltbar: Einstellungen → „Schleich-Anzeige“).
##  - Auge: öffnet sich, sobald ein Wesen Verdacht schöpft (weiß = stutzt, gelb = sieht nach, rot = entdeckt).
##  - Punkt links: wie gut du gerade zu sehen bist (dunkel = im Schatten, hell = im Licht).
##  - Wellen rechts: dein letztes Geräusch (eine Welle leise, drei laut).
##  - Atem angehalten (Alt): der Punkt bekommt einen Ring, der mit der Puste schrumpft.

const W := 150.0
const H := 34.0

var _player: Player
var _aware: float = 0.0
var _vis: float = 0.0
var _fade: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_left = -W * 0.5
	offset_right = W * 0.5
	offset_top = -64.0 - 92.0 - H - 10.0
	offset_bottom = -64.0 - 92.0 - 10.0


## Höchster Verdacht aller Wesen in der Nähe (0..1).
static func max_awareness(tree: SceneTree) -> float:
	var best := 0.0
	for n in tree.get_nodes_in_group("aware"):
		var a = n.get("awareness")
		if a is Awareness:
			best = maxf(best, (a as Awareness).value)
	return best


func _process(delta: float) -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Player
	var show := Settings.stealth_hud and _player != null and not GameState.dead and not _player.input_locked
	_fade = move_toward(_fade, 1.0 if show else 0.0, delta * 4.0)
	visible = _fade > 0.01
	if not visible:
		return
	_aware = lerpf(_aware, max_awareness(get_tree()), clampf(delta * 6.0, 0.0, 1.0))
	_vis = lerpf(_vis, _player.visibility, clampf(delta * 4.0, 0.0, 1.0))
	queue_redraw()


func _draw() -> void:
	if _player == null:
		return
	var a := _fade
	var cy := H * 0.5
	# --- Sichtbarkeit: Punkt links
	var dot := Vector2(18, cy)
	draw_circle(dot, 8.0, Color(0, 0, 0, 0.45 * a))
	draw_circle(dot, 6.0, Color(1.0, 0.96, 0.82, (0.12 + 0.88 * _vis) * a))
	if _player.holding_breath:
		var left := clampf((Survival.stamina - Stealth.cfg().breath_gasp_at) / 60.0, 0.0, 1.0)
		draw_arc(dot, 11.0, -PI * 0.5, -PI * 0.5 + TAU * left, 32, Color(0.65, 0.85, 1.0, 0.85 * a), 2.0, true)
	# --- Auge in der Mitte
	var c := Vector2(W * 0.5, cy)
	var ew := 24.0
	var open := clampf(_aware, 0.0, 1.0)
	var col := Color(0.85, 0.85, 0.8)
	var sc := Stealth.cfg()
	if _aware >= 1.0:
		col = Color(1.0, 0.25, 0.2)
	elif _aware >= sc.investigate_at:
		col = Color(1.0, 0.7, 0.25)
	elif _aware >= sc.suspect_at:
		col = Color(1.0, 0.95, 0.6)
	var base_a := (0.28 + 0.72 * smoothstep(0.02, 0.3, _aware)) * a
	var lid := 2.0 + 11.0 * open
	var top := PackedVector2Array()
	var bot := PackedVector2Array()
	for i in 17:
		var t := float(i) / 16.0
		var x := lerpf(-ew, ew, t)
		var y := sin(t * PI)
		top.append(c + Vector2(x, -y * lid))
		bot.append(c + Vector2(x, y * lid * 0.8))
	draw_polyline(top, Color(col, base_a), 2.0, true)
	draw_polyline(bot, Color(col, base_a), 2.0, true)
	if open > 0.08:
		draw_circle(c, minf(lid * 0.62, 6.5), Color(col, base_a))
		draw_circle(c, minf(lid * 0.25, 2.5), Color(0, 0, 0, 0.9 * a))
	# --- Geräusch: Wellen rechts
	var age := (Time.get_ticks_msec() - _player.last_noise_msec) / 1000.0
	if age < 0.9:
		var r := _player.last_noise_radius
		var waves := 1 if r < 3.0 else (2 if r < 8.0 else 3)
		var p := Vector2(W - 34, cy)
		var fade := (1.0 - age / 0.9) * a
		for i in waves:
			var rr := 5.0 + i * 5.0 + age * 6.0
			draw_arc(p, rr, -0.7, 0.7, 12, Color(0.9, 0.9, 0.85, fade * (1.0 - i * 0.2)), 2.0, true)
