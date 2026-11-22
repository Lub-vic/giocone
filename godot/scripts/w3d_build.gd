class_name W3DBuilder
extends RefCounted
## Costruttore di geometria low-poly: tutto e' fatto di triangoli colorati (niente texture).
## Il colore sta nei vertici; la luce usa normali piatte calcolate nello shader.
## Alpha del colore: 1 = normale, <1 = emissivo (finestre, fiamme).

var v := PackedVector3Array()
var c := PackedColorArray()
var rn := RandomNumberGenerator.new()


func shade(col: Color, j: float) -> Color:
	var k := 1.0 + rn.randf_range(-j, j)
	return Color(clampf(col.r * k, 0.0, 1.0), clampf(col.g * k, 0.0, 1.0), clampf(col.b * k, 0.0, 1.0), col.a)


func tri(a: Vector3, b: Vector3, d: Vector3, col: Color) -> void:
	v.append(a)
	v.append(b)
	v.append(d)
	c.append(col)
	c.append(col)
	c.append(col)


func quad(a: Vector3, b: Vector3, d: Vector3, e: Vector3, col: Color) -> void:
	tri(a, b, d, col)
	tri(a, d, e, col)


const FACES := [[1, 3, 7, 5], [0, 4, 6, 2], [2, 6, 7, 3], [0, 1, 5, 4], [4, 5, 7, 6], [0, 2, 3, 1]]   # +x -x +y -y +z -z


## parallelepipedo orientato; skip = maschera di facce da non disegnare (bit: +x,-x,+y,-y,+z,-z)
func box(t: Transform3D, size: Vector3, col: Color, j := 0.07, skip := 8) -> void:
	var h := size * 0.5
	var p: Array = []
	for i in 8:
		p.append(t * Vector3(h.x if (i & 1) != 0 else -h.x, h.y if (i & 2) != 0 else -h.y, h.z if (i & 4) != 0 else -h.z))
	for f in 6:
		if (skip >> f) & 1 == 1:
			continue
		var q: Array = FACES[f]
		quad(p[q[0]], p[q[1]], p[q[2]], p[q[3]], shade(col, j))


## tronco di cono lungo +Y da 0 a h
func cyl(t: Transform3D, rb: float, rt: float, h: float, segs: int, col: Color, j := 0.07, cap := true) -> void:
	for i in segs:
		var a0 := TAU * i / segs
		var a1 := TAU * (i + 1) / segs
		var b0 := t * Vector3(cos(a0) * rb, 0, sin(a0) * rb)
		var b1 := t * Vector3(cos(a1) * rb, 0, sin(a1) * rb)
		var t0 := t * Vector3(cos(a0) * rt, h, sin(a0) * rt)
		var t1 := t * Vector3(cos(a1) * rt, h, sin(a1) * rt)
		quad(b0, b1, t1, t0, shade(col, j))
		if cap:
			tri(t * Vector3(0, h, 0), t0, t1, shade(col, j))


## sasso: cubo con i vertici sporcati a caso
func rock(center: Vector3, size: Vector3, col: Color, j := 0.1, vj := 0.3, yaw := 0.0) -> void:
	var h := size * 0.5
	var p: Array = []
	var bas := Basis(Vector3.UP, yaw)
	for i in 8:
		var o := Vector3(h.x if (i & 1) != 0 else -h.x, h.y if (i & 2) != 0 else -h.y, h.z if (i & 4) != 0 else -h.z)
		o *= Vector3(1.0 + rn.randf_range(-vj, vj), 1.0 + rn.randf_range(-vj * 0.5, vj * 0.5), 1.0 + rn.randf_range(-vj, vj))
		if (i & 2) != 0:
			o.x *= 0.7
			o.z *= 0.7
		p.append(center + bas * o)
	for f in [0, 1, 2, 4, 5]:
		var q: Array = FACES[f]
		quad(p[q[0]], p[q[1]], p[q[2]], p[q[3]], shade(col, j))


## superficie a griglia (tetti): origine + ux*u + uy*w, vertici sporcati lungo n, qualche buco
func grid(origin: Vector3, ux: Vector3, uy: Vector3, nx: int, ny: int, col: Color, j: float, hj: float, holes: float, n: Vector3) -> void:
	var pts: Array = []
	for jj in ny + 1:
		for ii in nx + 1:
			var o := origin + ux * (float(ii) / nx) + uy * (float(jj) / ny)
			if ii > 0 and jj > 0 and ii < nx and jj < ny:
				o += n * rn.randf_range(-hj, hj)
			pts.append(o)
	for jj in ny:
		for ii in nx:
			if holes > 0.0 and rn.randf() < holes:
				continue
			var a: Vector3 = pts[jj * (nx + 1) + ii]
			var b: Vector3 = pts[jj * (nx + 1) + ii + 1]
			var d: Vector3 = pts[(jj + 1) * (nx + 1) + ii + 1]
			var e: Vector3 = pts[(jj + 1) * (nx + 1) + ii]
			# righe sfalsate come tegole
			var cc := shade(col, j)
			if jj % 2 == 1:
				cc = shade(col, j * 1.4)
			quad(a, b, d, e, cc)


## reticolo di facce triangolari tra quattro angoli (muri e tetti): vertici sporcati, buchi, bordo a sega
func lattice(p00: Vector3, p10: Vector3, p01: Vector3, p11: Vector3, nx: int, ny: int, col: Color, j: float, bulge: float, nrm: Vector3, holes := 0.0, jag := 0.0) -> void:
	var pts: Array = []
	for jj in ny + 1:
		var vv := float(jj) / ny
		for ii in nx + 1:
			var uu := float(ii) / nx
			var p := p00.lerp(p10, uu).lerp(p01.lerp(p11, uu), vv)
			if bulge > 0.0 and ii > 0 and ii < nx and jj > 0 and jj < ny:
				p += nrm * rn.randf_range(-bulge, bulge)
			if jag > 0.0 and jj == 0 and ii > 0 and ii < nx:
				p += (p01 - p00).normalized() * (jag if ii % 2 == 0 else -jag)
			pts.append(p)
	for jj in ny:
		for ii in nx:
			if holes > 0.0 and rn.randf() < holes:
				continue
			var a: Vector3 = pts[jj * (nx + 1) + ii]
			var bb: Vector3 = pts[jj * (nx + 1) + ii + 1]
			var d: Vector3 = pts[(jj + 1) * (nx + 1) + ii + 1]
			var e: Vector3 = pts[(jj + 1) * (nx + 1) + ii]
			if rn.randf() < 0.5:
				tri(a, bb, d, shade(col, j))
				tri(a, d, e, shade(col, j))
			else:
				tri(a, bb, e, shade(col, j))
				tri(bb, d, e, shade(col, j))


## sprite 2D -> pixel-voxel: ogni pixel un cubetto, piu' alto verso il centro (stile 2D, volume 3D)
func voxel(img: Image, vox: float, base_h := 2, extra := 3) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var hh: Array = []
	hh.resize(w * h)
	for y in h:
		for x in w:
			if img.get_pixel(x, y).a < 0.5:
				hh[y * w + x] = 0
				continue
			var dmin := extra
			for dy in range(-extra, extra + 1):
				for dx in range(-extra, extra + 1):
					var nx := x + dx
					var ny := y + dy
					if nx < 0 or ny < 0 or nx >= w or ny >= h or img.get_pixel(nx, ny).a < 0.5:
						dmin = mini(dmin, maxi(absi(dx), absi(dy)) - 1)
			hh[y * w + x] = base_h + clampi(dmin, 0, extra)
	for y in h:
		for x in w:
			var hv: int = hh[y * w + x]
			if hv == 0:
				continue
			var col := img.get_pixel(x, y)
			col.a = 0.82
			var side := Color(col.r * 0.6, col.g * 0.6, col.b * 0.62, 0.9)
			var x0 := (x - w * 0.5) * vox
			var z0 := (y - h * 0.5) * vox
			var top := hv * vox
			quad(Vector3(x0, top, z0), Vector3(x0 + vox, top, z0), Vector3(x0 + vox, top, z0 + vox), Vector3(x0, top, z0 + vox), col)
			for k in 4:
				var nxp: int = [x + 1, x - 1, x, x][k]
				var nyp: int = [y, y, y + 1, y - 1][k]
				var nh := 0
				if nxp >= 0 and nyp >= 0 and nxp < w and nyp < h:
					nh = hh[nyp * w + nxp]
				if nh >= hv:
					continue
				var lo := nh * vox
				match k:
					0:
						quad(Vector3(x0 + vox, lo, z0), Vector3(x0 + vox, lo, z0 + vox), Vector3(x0 + vox, top, z0 + vox), Vector3(x0 + vox, top, z0), side)
					1:
						quad(Vector3(x0, lo, z0), Vector3(x0, lo, z0 + vox), Vector3(x0, top, z0 + vox), Vector3(x0, top, z0), side)
					2:
						quad(Vector3(x0, lo, z0 + vox), Vector3(x0 + vox, lo, z0 + vox), Vector3(x0 + vox, top, z0 + vox), Vector3(x0, top, z0 + vox), side)
					3:
						quad(Vector3(x0, lo, z0), Vector3(x0 + vox, lo, z0), Vector3(x0 + vox, top, z0), Vector3(x0, top, z0), side)


## sprite 2D -> rilievo "gonfiato": i colori restano quelli dello sprite, il volume e' tondo e a pochi poligoni
func inflate(img: Image, vox: float, k := 0.12) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var d := PackedFloat32Array()
	d.resize(w * h)
	for i in w * h:
		d[i] = 1e6 if img.get_pixel(i % w, i / w).a >= 0.5 else 0.0
	for y in h:
		for x in w:
			var i := y * w + x
			if d[i] == 0.0:
				continue
			var m := d[i]
			m = minf(m, (d[i - 1] if x > 0 else 0.0) + 1.0)
			m = minf(m, (d[i - w] if y > 0 else 0.0) + 1.0)
			m = minf(m, (d[i - w - 1] if x > 0 and y > 0 else 0.0) + 1.4)
			m = minf(m, (d[i - w + 1] if x < w - 1 and y > 0 else 0.0) + 1.4)
			d[i] = m
	for y in range(h - 1, -1, -1):
		for x in range(w - 1, -1, -1):
			var i := y * w + x
			if d[i] == 0.0:
				continue
			var m := d[i]
			m = minf(m, (d[i + 1] if x < w - 1 else 0.0) + 1.0)
			m = minf(m, (d[i + w] if y < h - 1 else 0.0) + 1.0)
			m = minf(m, (d[i + w + 1] if x < w - 1 and y < h - 1 else 0.0) + 1.4)
			m = minf(m, (d[i + w - 1] if x > 0 and y < h - 1 else 0.0) + 1.4)
			d[i] = m
	var hp := PackedFloat32Array()
	hp.resize(w * h)
	for i in w * h:
		hp[i] = k * sqrt(d[i]) if d[i] > 0.0 else 0.0
	var cn := PackedFloat32Array()
	cn.resize((w + 1) * (h + 1))
	for cy in h + 1:
		for cx in w + 1:
			var s := 0.0
			for q in 4:
				var px := cx - 1 + (q & 1)
				var py := cy - 1 + (q >> 1)
				if px >= 0 and py >= 0 and px < w and py < h:
					s += hp[py * w + px]
			cn[cy * (w + 1) + cx] = s * 0.25
	for y in h:
		for x in w:
			if d[y * w + x] == 0.0:
				continue
			var col := img.get_pixel(x, y)
			col.a = 0.8
			var x0 := (x - w * 0.5) * vox
			var z0 := (y - h * 0.5) * vox
			var a := Vector3(x0, cn[y * (w + 1) + x] / 0.12 * vox * 1.6, z0)
			var b := Vector3(x0 + vox, cn[y * (w + 1) + x + 1] / 0.12 * vox * 1.6, z0)
			var c2 := Vector3(x0 + vox, cn[(y + 1) * (w + 1) + x + 1] / 0.12 * vox * 1.6, z0 + vox)
			var e := Vector3(x0, cn[(y + 1) * (w + 1) + x] / 0.12 * vox * 1.6, z0 + vox)
			if (x + y) % 2 == 0:
				tri(a, b, c2, col)
				tri(a, c2, e, col)
			else:
				tri(a, b, e, col)
				tri(b, c2, e, col)
			var side := Color(col.r * 0.55, col.g * 0.55, col.b * 0.58, 0.9)
			for kk in 4:
				var nxp: int = [x + 1, x - 1, x, x][kk]
				var nyp: int = [y, y, y + 1, y - 1][kk]
				var empty := nxp < 0 or nyp < 0 or nxp >= w or nyp >= h or d[nyp * w + nxp] == 0.0
				if not empty:
					continue
				match kk:
					0:
						quad(b, c2, Vector3(c2.x, 0, c2.z), Vector3(b.x, 0, b.z), side)
					1:
						quad(a, e, Vector3(e.x, 0, e.z), Vector3(a.x, 0, a.z), side)
					2:
						quad(e, c2, Vector3(c2.x, 0, c2.z), Vector3(e.x, 0, e.z), side)
					3:
						quad(a, b, Vector3(b.x, 0, b.z), Vector3(a.x, 0, a.z), side)


## sfera/ellisse a poligoni: forme tonde per personaggi e cespugli (poli come punti, anelli sfalsati)
func blob(c: Vector3, r: Vector3, col: Color, seg := 7, rings := 4, j := 0.1, wob := 0.05) -> void:
	var pts: Array = []
	for ri in rings + 1:
		var phi := -PI * 0.5 + PI * ri / rings
		var ring: Array = []
		if ri == 0 or ri == rings:
			ring.append(c + Vector3(0, sin(phi) * r.y, 0))
		else:
			for si in seg:
				var th := TAU * (si + 0.5 * (ri % 2)) / seg
				var p := c + Vector3(cos(phi) * cos(th) * r.x, sin(phi) * r.y, cos(phi) * sin(th) * r.z)
				p += Vector3(rn.randf_range(-wob, wob), rn.randf_range(-wob, wob), rn.randf_range(-wob, wob)) * maxf(r.x, r.z)
				ring.append(p)
		pts.append(ring)
	for si in seg:
		tri(pts[0][0], pts[1][si], pts[1][(si + 1) % seg], shade(col, j))
		tri(pts[rings][0], pts[rings - 1][(si + 1) % seg], pts[rings - 1][si], shade(col, j))
	for ri in range(1, rings - 1):
		for si in seg:
			var a: Vector3 = pts[ri][si]
			var b2: Vector3 = pts[ri][(si + 1) % seg]
			var d: Vector3 = pts[ri + 1][(si + 1) % seg]
			var e: Vector3 = pts[ri + 1][si]
			tri(a, b2, d, shade(col, j))
			tri(a, d, e, shade(col, j))


## scheggia: due piramidi unite per la base (rombo), col vertice sporcato: forma tagliente, 8 facce
func shard(p0: Vector3, p1: Vector3, w1: float, w2: float, col: Color, t := 0.4, j := 0.15, wob := 0.12) -> void:
	var a := p1 - p0
	var ln := maxf(a.length(), 0.001)
	var d := a / ln
	var u := d.cross(Vector3.UP)
	if u.length() < 0.2:
		u = d.cross(Vector3.RIGHT)
	u = u.normalized()
	var v := d.cross(u).normalized()
	var c := p0 + a * t
	var dirs := [u, v, -u, -v]
	var ws := [w1, w2, w1, w2]
	var ring: Array = []
	for i in 4:
		var k := 1.0 + rn.randf_range(-wob, wob)
		ring.append(c + (dirs[i] as Vector3) * float(ws[i]) * k + d * rn.randf_range(-wob, wob) * ln * 0.25)
	var low := Color(col.r * 0.8, col.g * 0.8, col.b * 0.82, col.a)
	for i in 4:
		var n := (i + 1) % 4
		tri(p1, ring[i], ring[n], shade(col, j))
		tri(p0, ring[n], ring[i], shade(low, j))


func shift(off: Vector3) -> void:
	for i in v.size():
		v[i] += off


func mesh() -> ArrayMesh:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_COLOR] = c
	var m := ArrayMesh.new()
	if v.size() > 0:
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m
