class_name HandKit
extends RefCounted
## Formen für alles, was der Spieler in der Hand hält: geschwungene Stiele und Henkel (loft),
## ausgeschnittene Bleche mit Keilform (extrude) und runde Körper mit Rillen (BuildKit.lathe).
## Alle Maße in Metern. Die Außenseite wird immer selbst bestimmt, die Reihenfolge der Punkte ist egal.


## Dreieck mit vorgegebenen Normalen – so gedreht, dass die Außenseite sichtbar ist.
static func tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3, nc: Vector3) -> void:
	# Godot zeigt Flächen, deren Ecken im Uhrzeigersinn laufen
	if (b - a).cross(c - a).dot(na + nb + nc) > 0.0:
		var t := b
		b = c
		c = t
		var tn := nb
		nb = nc
		nc = tn
	st.set_normal(na)
	st.add_vertex(a)
	st.set_normal(nb)
	st.add_vertex(b)
	st.set_normal(nc)
	st.add_vertex(c)


## Ebenes Viereck mit einer Normalen (kantige Flächen).
static func quad_flat(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3) -> void:
	tri(st, a, b, c, n, n, n)
	tri(st, a, c, d, n, n, n)


## Schlauch entlang einer Linie mit ovalem Querschnitt.
## radii[i] = (halbe Breite quer, halbe Höhe in Richtung „up“). Für Stiele, Henkel, Finger, Tüllen.
static func loft(parent: Node, pts: PackedVector3Array, radii: PackedVector2Array, mat: Material,
		sides: int = 8, up: Vector3 = Vector3.UP, caps: bool = true) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := pts.size()
	var rings: Array = []
	var normals: Array = []
	var u := up
	for i in n:
		var t := (pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)]).normalized()
		u = u - t * u.dot(t)
		if u.length() < 0.001:
			u = t.cross(Vector3.RIGHT) if absf(t.x) < 0.9 else t.cross(Vector3.UP)
		u = u.normalized()
		var r := t.cross(u).normalized()
		var rad: Vector2 = radii[mini(i, radii.size() - 1)]
		var ring := PackedVector3Array()
		var nrm := PackedVector3Array()
		for k in sides:
			var a := TAU * k / sides
			ring.append(pts[i] + r * cos(a) * rad.x + u * sin(a) * rad.y)
			nrm.append((r * cos(a) * maxf(rad.y, 0.0001) + u * sin(a) * maxf(rad.x, 0.0001)).normalized())
		rings.append(ring)
		normals.append(nrm)
	for i in n - 1:
		for k in sides:
			var k1 := (k + 1) % sides
			var a: Vector3 = rings[i][k]
			var b: Vector3 = rings[i][k1]
			var c: Vector3 = rings[i + 1][k1]
			var d: Vector3 = rings[i + 1][k]
			tri(st, a, b, c, normals[i][k], normals[i][k1], normals[i + 1][k1])
			tri(st, a, c, d, normals[i][k], normals[i + 1][k1], normals[i + 1][k])
	if caps:
		for e: int in [0, n - 1]:
			var dir := (pts[0] - pts[1]).normalized() if e == 0 else (pts[n - 1] - pts[n - 2]).normalized()
			for k in sides:
				tri(st, pts[e], rings[e][k], rings[e][(k + 1) % sides], dir, dir, dir)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	parent.add_child(mi)
	return mi


## Punkte auf einem Kreisbogen. Ebene: axis_a = Richtung bei 0°, axis_b = Richtung bei 90°.
static func arc(center: Vector3, radius: float, from_deg: float, to_deg: float, steps: int,
		axis_a: Vector3 = Vector3.RIGHT, axis_b: Vector3 = Vector3.UP, radius_b: float = -1.0) -> PackedVector3Array:
	var out := PackedVector3Array()
	var rb := radius if radius_b < 0.0 else radius_b
	for i in steps + 1:
		var a := deg_to_rad(lerpf(from_deg, to_deg, float(i) / steps))
		out.append(center + axis_a * cos(a) * radius + axis_b * sin(a) * rb)
	return out


## Gleich dicker Schlauch (rund).
static func tube(parent: Node, pts: PackedVector3Array, radius: float, mat: Material, sides: int = 6,
		up: Vector3 = Vector3.UP) -> MeshInstance3D:
	return loft(parent, pts, PackedVector2Array([Vector2(radius, radius)]), mat, sides, up)


## Flaches Teil aus einem Umriss (x/y), in z dick. half = halbe Dicke, entweder eine Zahl für alle
## oder je Eckpunkt eine (Keil: Axtblatt, Schneiden). Kantig schattiert.
static func extrude(parent: Node, outline: PackedVector2Array, half, mat: Material) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := outline.size()
	var h := PackedFloat32Array()
	for i in n:
		h.append(float(half[i]) if half is Array or half is PackedFloat32Array else float(half))
	var idx := Geometry2D.triangulate_polygon(outline)
	for side: float in [1.0, -1.0]:
		for t in range(0, idx.size(), 3):
			var p := PackedVector3Array()
			for k in 3:
				var q := outline[idx[t + k]]
				p.append(Vector3(q.x, q.y, side * h[idx[t + k]]))
			var fn := (p[1] - p[0]).cross(p[2] - p[0])
			if fn.z * side < 0.0:
				fn = -fn
			fn = fn.normalized()
			tri(st, p[0], p[1], p[2], fn, fn, fn)
	# Rand: Außenseite über die Umlaufrichtung des Umrisses
	var area := 0.0
	for i in n:
		var a2 := outline[i]
		var b2 := outline[(i + 1) % n]
		area += a2.x * b2.y - b2.x * a2.y
	var sgn := 1.0 if area > 0.0 else -1.0
	for i in n:
		var j := (i + 1) % n
		var e := outline[j] - outline[i]
		var out := Vector3(e.y, -e.x, 0.0).normalized() * sgn
		quad_flat(st, Vector3(outline[i].x, outline[i].y, h[i]), Vector3(outline[j].x, outline[j].y, h[j]),
				Vector3(outline[j].x, outline[j].y, -h[j]), Vector3(outline[i].x, outline[i].y, -h[i]), out)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	parent.add_child(mi)
	return mi


## Runde Scheibe mit Bild (z. B. Zifferblatt), zeigt nach +y.
static func disc(parent: Node, radius: float, pos: Vector3, mat: Material, sides: int = 16) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in sides:
		var a0 := TAU * k / sides
		var a1 := TAU * (k + 1) / sides
		var p0 := Vector3(cos(a0), 0, sin(a0))
		var p1 := Vector3(cos(a1), 0, sin(a1))
		for q: Vector3 in [Vector3.ZERO, p1, p0]:
			st.set_normal(Vector3.UP)
			st.set_uv(Vector2(0.5 + q.x * 0.5, 0.5 + q.z * 0.5))
			st.add_vertex(q * radius)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


## Material mit eigener Farbe, das nicht geteilt wird (für Leuchten, Füllstände …).
static func own_mat(color: Color, roughness: float = 0.6, metallic: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	return m


## Durchsichtiges Material (Flaschen, Gläser).
static func clear_mat(color: Color, roughness: float = 0.15) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = roughness
	m.metallic_specular = 0.6
	m.cull_mode = BaseMaterial3D.CULL_BACK
	return m
