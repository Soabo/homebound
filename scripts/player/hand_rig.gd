class_name HandRig
extends Node3D
## Eine Hand mit beweglichen Fingern und Daumen.
##
## Ursprung = Handgelenk, Finger zeigen nach -z, Handrücken nach +y, Handfläche nach -y.
## side = 1 rechte Hand (Daumen bei -x), side = -1 linke Hand.
## Eine Haltung (pose) ist ein Dictionary:
##   "f": je Finger [Knöchel, Mittelgelenk, Endgelenk] in Grad (Zeigefinger … kleiner Finger)
##   "s": je Finger Spreizung in Grad (positiv = zur Daumenseite)
##   "t": Daumen [abwärts, auswärts, Drehung, Gelenk 1, Gelenk 2] in Grad
## grip(R) liefert die Haltung um eine Stange mit Radius R, die quer unter der Handfläche liegt
## (Mitte bei grip_center(R)) – damit passen die Finger an Stiel, Flasche, Dose, Henkel.

const PALM_LEN := 0.090
const PALM_T := 0.026
## Finger von Zeige- bis kleiner Finger: Versatz quer, Knöchel nach hinten, 3 Gliedlängen, Dicke
const FINGERS := [
	{"x": -0.0290, "z": 0.003, "len": [0.040, 0.025, 0.021], "r": 0.0112},
	{"x": -0.0095, "z": 0.000, "len": [0.044, 0.029, 0.022], "r": 0.0116},
	{"x": 0.0100, "z": 0.003, "len": [0.040, 0.027, 0.021], "r": 0.0110},
	{"x": 0.0285, "z": 0.010, "len": [0.031, 0.020, 0.018], "r": 0.0098},
]
const THUMB_LEN := [0.042, 0.032, 0.026]
const THUMB_R := [0.0135, 0.0112, 0.0102]
const THUMB_BASE := Vector3(-0.033, -0.006, -0.022)

const RELAXED := {"f": [[22, 34, 18], [28, 40, 22], [34, 44, 24], [40, 46, 26]], "s": [5, 0, -4, -9], "t": [28, 34, -40, 12, 14]}
const FIST := {"f": [[84, 98, 62], [86, 100, 64], [88, 100, 64], [90, 98, 62]], "s": [1, 0, -1, -3], "t": [62, -6, -62, 26, 48]}
const OPEN := {"f": [[6, 10, 6], [4, 10, 6], [6, 12, 8], [10, 14, 8]], "s": [8, 0, -6, -14], "t": [14, 46, -30, 6, 8]}

var side: float = 1.0
var skin: StandardMaterial3D
var _f: Array = []
var _t: Array = []
var _pose: Dictionary = {}


static func create(parent: Node, hand_side: float, skin_mat: StandardMaterial3D) -> HandRig:
	var h := HandRig.new()
	h.side = hand_side
	h.skin = skin_mat
	parent.add_child(h)
	h._build()
	h.set_pose(RELAXED)
	return h


func _build() -> void:
	var crease := BuildKit.color_mat(Color(0.44, 0.31, 0.25), 0.9)
	var nail := BuildKit.color_mat(Color(0.78, 0.63, 0.56), 0.5)
	# Handgelenk und Handfläche: hinten schmal, an den Knöcheln breit und flach
	HandKit.loft(self, PackedVector3Array([Vector3(0, -0.001, 0.03), Vector3(0, -0.001, 0.012), Vector3(0, 0, -0.012),
			Vector3(0, 0, -0.045), Vector3(side * 0.001, 0.0, -0.075), Vector3(side * 0.001, -0.001, -PALM_LEN - 0.003)]),
			PackedVector2Array([Vector2(0.0275, 0.0195), Vector2(0.0285, 0.0195), Vector2(0.034, 0.0165), Vector2(0.041, 0.0155),
			Vector2(0.0425, 0.0138), Vector2(0.040, 0.0112)]), skin, 10)
	# Kugel im Handgelenk: schließt die Lücke zum Ärmel, wenn die Hand abknickt
	BuildKit.sphere(self, 0.0285, Vector3(0, -0.001, 0.034), skin, Vector3(1.0, 0.74, 1.25), 10)
	# Daumenballen und Handkante
	BuildKit.sphere(self, 0.019, Vector3(-side * 0.022, -0.009, -0.03), skin, Vector3(1.0, 0.8, 1.55), 8)
	BuildKit.sphere(self, 0.014, Vector3(side * 0.03, -0.007, -0.045), skin, Vector3(0.9, 0.9, 2.2), 8)
	for i in FINGERS.size():
		var d: Dictionary = FINGERS[i]
		var r: float = d["r"]
		var chain: Array = []
		var parent: Node3D = self
		var at := Vector3(side * float(d["x"]), 0.0, -PALM_LEN + float(d["z"]))
		for k in 3:
			var j := Node3D.new()
			j.position = at
			parent.add_child(j)
			var l: float = d["len"][k]
			var rr := r * (1.0 - 0.07 * k)
			BuildKit.sphere(j, rr * 1.06, Vector3.ZERO, skin, Vector3(1.0, 0.95, 1.0), 6)
			if k < 2:
				HandKit.loft(j, PackedVector3Array([Vector3.ZERO, Vector3(0, 0, -l * 0.5), Vector3(0, 0, -l)]),
						PackedVector2Array([Vector2(rr, rr * 0.93), Vector2(rr * 0.94, rr * 0.88), Vector2(rr * 0.93, rr * 0.87)]), skin, 7)
				if k == 0:
					# Knöchelfalte auf dem Handrücken
					BuildKit.box(j, Vector3(rr * 1.3, 0.0012, 0.0016), Vector3(0, rr * 0.9, -0.004), crease, false)
			else:
				HandKit.loft(j, PackedVector3Array([Vector3.ZERO, Vector3(0, 0, -l * 0.55), Vector3(0, -rr * 0.08, -l * 0.9), Vector3(0, -rr * 0.15, -l)]),
						PackedVector2Array([Vector2(rr, rr * 0.93), Vector2(rr * 0.95, rr * 0.85), Vector2(rr * 0.78, rr * 0.62), Vector2(rr * 0.4, rr * 0.3)]), skin, 7)
				BuildKit.box(j, Vector3(rr * 1.35, 0.0016, l * 0.5), Vector3(0, rr * 0.8, -l * 0.62), nail, false, Vector3(-6, 0, 0))
			chain.append(j)
			parent = j
			at = Vector3(0, 0, -l)
		_f.append(chain)
	# Daumen: Mittelhandknochen, zwei Glieder
	var tp: Node3D = self
	var tat := Vector3(side * THUMB_BASE.x, THUMB_BASE.y, THUMB_BASE.z)
	for k in 3:
		var j := Node3D.new()
		j.position = tat
		tp.add_child(j)
		var l: float = THUMB_LEN[k]
		var rr: float = THUMB_R[k]
		BuildKit.sphere(j, rr * 1.05, Vector3.ZERO, skin, Vector3.ONE, 6)
		if k < 2:
			HandKit.loft(j, PackedVector3Array([Vector3.ZERO, Vector3(0, 0, -l * 0.5), Vector3(0, 0, -l)]),
					PackedVector2Array([Vector2(rr, rr * 0.95), Vector2(rr * 0.92, rr * 0.9), Vector2(rr * 0.86, rr * 0.84)]), skin, 7)
		else:
			HandKit.loft(j, PackedVector3Array([Vector3.ZERO, Vector3(0, 0, -l * 0.55), Vector3(0, -rr * 0.05, -l * 0.9), Vector3(0, -rr * 0.12, -l)]),
					PackedVector2Array([Vector2(rr, rr * 0.9), Vector2(rr * 0.98, rr * 0.82), Vector2(rr * 0.8, rr * 0.6), Vector2(rr * 0.4, rr * 0.3)]), skin, 7)
			BuildKit.box(j, Vector3(rr * 1.45, 0.0016, l * 0.5), Vector3(0, rr * 0.78, -l * 0.6), nail, false, Vector3(-6, 0, 0))
		_t.append(j)
		tp = j
		tat = Vector3(0, 0, -l)


func set_pose(p: Dictionary) -> void:
	_pose = p
	var f: Array = p["f"]
	var s: Array = p.get("s", [0, 0, 0, 0])
	for i in 4:
		var c: Array = f[i]
		(_f[i][0] as Node3D).rotation = Vector3(-deg_to_rad(float(c[0])), side * deg_to_rad(float(s[i])), 0.0)
		(_f[i][1] as Node3D).rotation.x = -deg_to_rad(float(c[1]))
		(_f[i][2] as Node3D).rotation.x = -deg_to_rad(float(c[2]))
	var t: Array = p["t"]
	(_t[0] as Node3D).rotation = Vector3(-deg_to_rad(float(t[0])), side * deg_to_rad(float(t[1])), side * deg_to_rad(float(t[2])))
	(_t[1] as Node3D).rotation.x = deg_to_rad(float(t[3]))
	(_t[2] as Node3D).rotation.x = deg_to_rad(float(t[4]))


func pose() -> Dictionary:
	return _pose


## Zwischenhaltung (für Animationen: zudrücken, Knopf drücken …).
static func mix(a: Dictionary, b: Dictionary, w: float) -> Dictionary:
	var f: Array = []
	var s: Array = []
	for i in 4:
		var row: Array = []
		for k in 3:
			row.append(lerpf(float(a["f"][i][k]), float(b["f"][i][k]), w))
		f.append(row)
		s.append(lerpf(float(a.get("s", [0, 0, 0, 0])[i]), float(b.get("s", [0, 0, 0, 0])[i]), w))
	var t: Array = []
	for k in 5:
		t.append(lerpf(float(a["t"][k]), float(b["t"][k]), w))
	return {"f": f, "s": s, "t": t}


## Mitte einer Stange mit Radius r, die quer (entlang x) unter der Handfläche in der Faust liegt.
static func grip_center(r: float) -> Vector3:
	return Vector3(0.0, -(PALM_T * 0.5 + r), -(PALM_LEN - 0.021))


## Haltung, mit der sich Finger und Daumen um eine Stange mit Radius r legen.
## tight < 1 lässt die Finger lockerer (z. B. um weiche Dinge), thumb_out schiebt den Daumen nach außen.
static func grip(r: float, tight: float = 1.0, thumb_yaw: float = 10.0) -> Dictionary:
	var f: Array = []
	for i in 4:
		var d: Dictionary = FINGERS[i]
		var l: Array = d["len"]
		var rho := r + float(d["r"]) * 0.95
		# die Glieder liegen als Tangenten am Kreis: Knick je Gelenk aus den Tangentenlängen
		var s1 := 0.021 + float(d["z"])
		var mcp := 2.0 * atan(s1 / rho)
		var s2 := maxf(float(l[0]) - s1, 0.006)
		var pip := 2.0 * atan(s2 / rho)
		var s3 := maxf(float(l[1]) - s2, 0.004)
		var dip := 2.0 * atan(s3 / rho) + 0.2
		f.append([rad_to_deg(mcp) * tight, minf(rad_to_deg(pip) * tight, 105.0), minf(rad_to_deg(dip) * tight, 75.0)])
	# Daumen: von der Wurzel als Tangente an die Stange, dann darum herum (Gegenrichtung der Finger)
	var c := grip_center(r)
	var b := Vector2(-THUMB_BASE.z, -THUMB_BASE.y)   # (vorwärts, abwärts)
	var cc := Vector2(-c.z, -c.y)
	var rho_t := r + THUMB_R[1]
	var to := cc - b
	var dist := to.length()
	var phi := atan2(to.y, to.x)
	var down := phi + (asin(clampf(rho_t / dist, 0.0, 1.0)) if dist > rho_t else PI * 0.5)
	var tangent := sqrt(maxf(dist * dist - rho_t * rho_t, 0.0))
	var t1 := maxf(THUMB_LEN[0] - tangent, 0.006)
	var c1 := 2.0 * atan(t1 / rho_t)
	var t2 := maxf(THUMB_LEN[1] - t1, 0.005)
	var c2 := 2.0 * atan(t2 / rho_t)
	return {"f": f, "s": [2, 0, -2, -4],
			"t": [rad_to_deg(down), thumb_yaw, 0.0, minf(rad_to_deg(c1), 80.0) * tight, minf(rad_to_deg(c2), 75.0) * tight]}
