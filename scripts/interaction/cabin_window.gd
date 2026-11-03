class_name CabinWindow
extends Node3D
## Fenster mit Rahmen, Sprossen und Glas. Ursprung = Mitte der Unterkante.
## Vorbereitet für GDD 7.3: Später bekommt das Fenster Lebenspunkte,
## Splitter-Zustände und Bretter zum Verbarrikadieren.

@export var width: float = 1.0
@export var height: float = 0.9
@export var wall_thickness: float = 0.25

var health: float = 100.0


func _ready() -> void:
	var frame := BuildKit.tex_mat("planks_h", 0.6, Color(0.6, 0.55, 0.5))
	var f := 0.07
	var d := wall_thickness + 0.04
	BuildKit.box(self, Vector3(width, f, d), Vector3(0, f * 0.5, 0), frame, false)
	BuildKit.box(self, Vector3(width, f, d), Vector3(0, height - f * 0.5, 0), frame, false)
	BuildKit.box(self, Vector3(f, height, d), Vector3(-width * 0.5 + f * 0.5, height * 0.5, 0), frame, false)
	BuildKit.box(self, Vector3(f, height, d), Vector3(width * 0.5 - f * 0.5, height * 0.5, 0), frame, false)
	# Sprossenkreuz
	BuildKit.box(self, Vector3(0.035, height - f * 2.0, 0.05), Vector3(0, height * 0.5, 0), frame, false)
	BuildKit.box(self, Vector3(width - f * 2.0, 0.035, 0.05), Vector3(0, height * 0.5, 0), frame, false)
	# Fensterbank innen
	BuildKit.box(self, Vector3(width + 0.12, 0.04, 0.22), Vector3(0, -0.02, -wall_thickness * 0.5 - 0.06),
			BuildKit.tex_mat("planks_h", 0.8), false)
	# Glas mit Kollision
	var glass := BuildKit.box(self, Vector3(width - f * 2.0, height - f * 2.0, 0.012),
			Vector3(0, height * 0.5, 0), BuildKit.glass_mat(), true)
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
