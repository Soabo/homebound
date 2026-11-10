class_name GadgetHud
extends CanvasLayer
## Kleine Anzeigen für die Forschung 2.0 (oben rechts):
##  - Fremde Signatur: wie stark du gerade für sie „leuchtest“ (nur sichtbar, wenn > 0)
##  - Nervenfühler: zuckt, wenn die Kreatur in der Nähe ist (mit grober Richtung)
##  - Geruchstarnung: wie lange sie noch wirkt

var _label: Label
var _player: Player
var _t: float = 0.0
var _twitch: float = 0.0


func _ready() -> void:
	name = "GadgetHud"
	layer = 5
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 15)
	_label.add_theme_color_override("font_color", Color(0.8, 0.9, 0.85))
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_label.add_theme_constant_override("outline_size", 4)
	_label.anchor_left = 1.0
	_label.anchor_right = 1.0
	_label.offset_left = -420
	_label.offset_right = -18
	_label.offset_top = 96
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_label)


func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0:
		return
	_t = 0.25
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Player
		return
	var lines: PackedStringArray = []
	var sig := Research.signature()
	if sig >= 0.1:
		lines.append("Fremde Signatur  " + ResearchMenu.signature_bar(sig))
	if Inventory.count("creature_alarm") > 0:
		var a := alarm_text(_player.global_position, _player.camera.global_transform.basis)
		if a != "":
			lines.append(a)
			_twitch -= 0.25
			if _twitch <= 0.0:
				_twitch = 2.5
				SoundBank.play_ui(self, "static", -18.0, 2.2)
	if Research.buff_active("scent"):
		lines.append("Geruchstarnung  noch %d Std." % int(ceil(float(Research.buffs.get("scent", 0.0)) - Research.now())))
	_label.text = "\n".join(lines)


## Nervenfühler: „zuckt – etwas Großes, links hinten (~30 m)“, oder "" wenn nichts in Reichweite.
static func alarm_text(at: Vector3, view: Basis) -> String:
	var range_m := float(Research.gadget("creature_alarm", "range", 45.0))
	var best: Node3D = null
	var best_d := range_m
	for c: Variant in [ThreatDirector.creature]:
		var n := c as Node3D if is_instance_valid(c) else null
		if n and n.visible:
			var d := n.global_position.distance_to(at)
			if d < best_d:
				best_d = d
				best = n
	if best == null:
		return ""
	var to := best.global_position - at
	to.y = 0.0
	var fwd := -view.z
	fwd.y = 0.0
	var ang := rad_to_deg(fwd.normalized().signed_angle_to(to.normalized(), Vector3.UP))
	var dir := "vorn"
	if absf(ang) > 135.0:
		dir = "hinter dir"
	elif ang > 45.0:
		dir = "links"
	elif ang < -45.0:
		dir = "rechts"
	return "Nervenfühler zuckt – etwas Großes, %s (~%d m)" % [dir, int(round(best_d / 5.0) * 5.0)]
