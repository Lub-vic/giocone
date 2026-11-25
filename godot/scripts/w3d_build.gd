class_name W3DBuilder
extends RefCounted
## Costruttore di geometria low-poly: tutto e' fatto di triangoli colorati (niente texture).
## Il colore sta nei vertici; la luce usa normali piatte calcolate nello shader.
## Alpha del colore: 1 = normale, <1 = emissivo (finestre, fiamme).

var v := PackedVector3Array()
var c := PackedColorArray()
var rn := RandomNumberGenerator.new()
var reg: Array = []              # oggetti generati [tipo, posizione, rotazione, stato rng, stato rng colori]: l'editor li rende modificabili
var breakables: Array = []
var smokes: Array = []           # camini che fumano (posizione): diventano particelle animate
var sz := 1.0                   # fattore di scala per rock() e shard() (arredi ingranditi)
var gain := 1.0                 # luminosita' aggiuntiva (oggetti di scena)
var sat := 1.0                  # saturazione e contrasto applicati ai colori (oggetti dello scenario piu' leggibili)
var con := 1.0


func shade(col: Color, j: float) -> Color:
	var k := (1.0 + rn.randf_range(-j, j)) * gain
	var r := col.r * k
	var g := col.g * k
	var b := col.b * k
	if sat != 1.0 or con != 1.0:
		var l := r * 0.3 + g * 0.59 + b * 0.11
		r = l + (r - l) * sat
		g = l + (g - l) * sat
		b = l + (b - l) * sat
		r = (r - 0.2) * con + 0.2
		g = (g - 0.2) * con + 0.2
		b = (b - 0.2) * con + 0.2
	return Color(clampf(r, 0.0, 1.0), clampf(g, 0.0, 1.0), clampf(b, 0.0, 1.0), col.a)


func tri(a: Vector3, b: Vector3, d: Vector3, col: Color) -> void:
	v.append(a)
	v.append(b)
	v.append(d)
	c.append(col)
	c.append(col)
	c.append(col)


func tri3(a: Vector3, b: Vector3, d: Vector3, ca: Color, cb: Color, cd: Color) -> void:
	v.append(a)
	v.append(b)
	v.append(d)
	c.append(ca)
	c.append(cb)
	c.append(cd)


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
	var h := size * 0.5 * sz
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
## personaggio a blocchi IN PIEDI: ogni pixel opaco dello sprite frontale diventa un cubo, con spessore; i piedi stanno a quota 0
## e il fronte guarda +Z (si ruota verso chi guarda). Si usa nella prima persona.
func upright(img: Image, vox: float, depth: int) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var maxy := 0
	for y in h:
		for x in w:
			if img.get_pixel(x, y).a > 0.5:
				maxy = maxi(maxy, y)
	var hd := depth * vox * 0.5
	for y in h:
		for x in w:
			var c := img.get_pixel(x, y)
			if c.a < 0.5:
				continue
			c.a = 1.0
			var cx := (x - w * 0.5 + 0.5) * vox
			var cy := (maxy - y + 0.5) * vox
			box(Transform3D(Basis.IDENTITY, Vector3(cx, cy, 0.0)), Vector3(vox * 1.02, vox * 1.02, hd * 2.0), c, 0.0, 8)


## personaggio a blocchi COMPLETO, visibile da ogni lato: il fronte e' lo sprite frontale; il volume ha sezione ellittica per ogni riga di pixel
## (corpo tondeggiante, braccia sottili); il retro usa lo sprite posteriore se esiste (nome_b.png), altrimenti il fronte specchiato e scurito;
## i fianchi riprendono i colori del fronte. Piedi a quota 0, il davanti guarda -Z (come i modelli visti dall'alto).
func solid(front: Image, back: Image, vox: float) -> void:
	var w := front.get_width()
	var h := front.get_height()
	var maxy := 0
	for y in h:
		for x in w:
			if front.get_pixel(x, y).a > 0.5:
				maxy = maxi(maxy, y)
	var vs := {}
	var xa_row: Array = []
	var xb_row: Array = []
	for y in h:
		var xa := -1
		var xb := -1
		for x in w:
			if front.get_pixel(x, y).a > 0.5:
				if xa < 0:
					xa = x
				xb = x
		xa_row.append(xa)
		xb_row.append(xb)
		if xa < 0:
			continue
		var cx := (xa + xb + 1) * 0.5
		var rw := (xb - xa + 1) * 0.5
		var dz := clampf(rw * 0.7, 1.5, 5.5)
		for x in range(xa, xb + 1):
			if front.get_pixel(x, y).a < 0.5:
				continue
			var u := ((x + 0.5) - cx) / maxf(rw, 0.5)
			var zd := maxi(1, roundi(dz * sqrt(maxf(0.0, 1.0 - u * u * 0.85))))
			for z in range(-zd, zd):
				vs[Vector3i(x, maxy - y, z)] = true
	var offs: Array = [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]
	for key in vs:
		var k: Vector3i = key
		var py := maxy - k.y
		var fc := front.get_pixel(k.x, py)
		fc.a = 1.0
		var x0 := (w * 0.5 - 1.0 - k.x) * vox       # il fronte guarda -Z: +X appare a sinistra, quindi l'immagine si specchia nel mondo
		var x1 := x0 + vox
		var y0 := k.y * vox
		var y1 := y0 + vox
		var z0 := k.z * vox
		var z1 := z0 + vox
		for d in 5:
			if vs.has(k + (offs[d] as Vector3i)):
				continue
			match d:
				0:      # fianco destro
					quad(Vector3(x1, y0, z0), Vector3(x1, y0, z1), Vector3(x1, y1, z1), Vector3(x1, y1, z0), Color(fc.r * 0.72, fc.g * 0.72, fc.b * 0.74, 1.0))
				1:      # fianco sinistro
					quad(Vector3(x0, y0, z1), Vector3(x0, y0, z0), Vector3(x0, y1, z0), Vector3(x0, y1, z1), Color(fc.r * 0.72, fc.g * 0.72, fc.b * 0.74, 1.0))
				2:      # sopra
					quad(Vector3(x0, y1, z0), Vector3(x1, y1, z0), Vector3(x1, y1, z1), Vector3(x0, y1, z1), Color(minf(fc.r * 1.08, 1.0), minf(fc.g * 1.08, 1.0), minf(fc.b * 1.08, 1.0), 1.0))
				3:      # dietro
					var bc := fc
					var dark := 0.8
					if back != null and k.x < back.get_width() and py < back.get_height() and back.get_pixel(k.x, py).a > 0.5:
						bc = back.get_pixel(k.x, py)
						dark = 1.0
					else:
						var xm: int = int(xa_row[py]) + int(xb_row[py]) - k.x      # il fronte specchiato
						if xm >= 0 and xm < w and front.get_pixel(xm, py).a > 0.5:
							bc = front.get_pixel(xm, py)
					quad(Vector3(x1, y0, z1), Vector3(x0, y0, z1), Vector3(x0, y1, z1), Vector3(x1, y1, z1), Color(bc.r * dark, bc.g * dark, bc.b * dark, 1.0))
				4:      # davanti
					quad(Vector3(x0, y0, z0), Vector3(x1, y0, z0), Vector3(x1, y1, z0), Vector3(x0, y1, z0), fc)


## personaggio a blocchi dal volume vero, ricavato da DUE viste: lo sprite frontale (sagoma e colori davanti) e la vista dall'alto
## (impronta e altezze). Un cubo esiste solo se lo conferma la sagoma frontale E l'impronta E l'altezza dall'alto: ne escono le sagome
## laterali (testa, spalla, braccio, arma) e quella posteriore. Colori: davanti dallo sprite frontale, sopra dalla vista dall'alto,
## dietro lo sprite posteriore (se esiste) o il fronte scurito, ai lati un misto fra fronte e alto.
func hull(front: Image, back: Image, topc: Image, toph: Image, vox: float, side: Image = null) -> void:
	var w := front.get_width()
	var h := front.get_height()
	var fx0 := w
	var fx1 := -1
	var fy0 := h
	var fy1 := -1
	for y in h:
		for x in w:
			if front.get_pixel(x, y).a > 0.5:
				fx0 = mini(fx0, x)
				fx1 = maxi(fx1, x)
				fy0 = mini(fy0, y)
				fy1 = maxi(fy1, y)
	if fx1 < 0:
		return
	var tw := topc.get_width()
	var th := topc.get_height()
	var tx0 := tw
	var tx1 := -1
	var ty0 := th
	var ty1 := -1
	var hmax := 1.0
	for y in th:
		for x in tw:
			if topc.get_pixel(x, y).a > 0.5:
				tx0 = mini(tx0, x)
				tx1 = maxi(tx1, x)
				ty0 = mini(ty0, y)
				ty1 = maxi(ty1, y)
				hmax = maxf(hmax, toph.get_pixel(x, y).r * 255.0)
	if tx1 < 0:
		solid(front, back, vox)
		return
	var fw := fx1 - fx0 + 1
	var fh := fy1 - fy0 + 1
	var s := float(tx1 - tx0 + 1) / float(fw)          # pixel della vista dall'alto per pixel dello sprite frontale
	var hs := float(fh) / hmax
	var fcx := (fx0 + fx1 + 1) * 0.5
	var tcx := (tx0 + tx1 + 1) * 0.5
	var tcy := (ty0 + ty1 + 1) * 0.5
	var nz := mini(int(ceil(float(ty1 - ty0 + 1) / s * 0.5)), int(ceil(fw * 0.34)))      # profondita' massima: un corpo non e' profondo quanto largo
	var imin := -int(ceil(fw * 0.5))
	var imax := int(ceil(fw * 0.5))
	var vs := {}
	for i in range(imin, imax):
		var px := int(floor(fcx - (i + 0.5)))
		if px < fx0 or px > fx1:
			continue
		var u := int(floor(tcx + (i + 0.5) * s))
		if u < 0 or u >= tw:
			continue
		for k in range(-nz, nz):
			var v := int(floor(tcy + (k + 0.5) * s))
			if v < 0 or v >= th:
				continue
			if topc.get_pixel(u, v).a < 0.5:
				continue
			var hh := toph.get_pixel(u, v).r * 255.0 * hs
			for j in fh:
				if float(j) + 0.5 > hh + 0.5:
					break
				if front.get_pixel(px, fy1 - j).a > 0.5:
					vs[Vector3i(i, j, k)] = true
	# sprite di profilo (rivolto a destra): se c'e', scolpisce il volume con la sua sagoma e colora i fianchi
	var use_side := false
	var s_sx0 := 0
	var s_sw := 1
	var s_sy1 := 0
	var s_sh := 1
	var s_zmin := 9999
	var s_zmax := -9999
	if side != null and not vs.is_empty():
		var ax0 := side.get_width()
		var ax1 := -1
		var ay0 := side.get_height()
		var ay1 := -1
		for y in side.get_height():
			for x in side.get_width():
				if side.get_pixel(x, y).a > 0.5:
					ax0 = mini(ax0, x)
					ax1 = maxi(ax1, x)
					ay0 = mini(ay0, y)
					ay1 = maxi(ay1, y)
		if ax1 >= 0:
			use_side = true
			s_sx0 = ax0
			s_sw = ax1 - ax0 + 1
			s_sy1 = ay1
			s_sh = ay1 - ay0 + 1
			for key in vs:
				var vk: Vector3i = key
				s_zmin = mini(s_zmin, vk.z)
				s_zmax = maxi(s_zmax, vk.z)
			var before := vs.size()
			var keep := {}
			for key in vs:
				var vk2: Vector3i = key
				if _side_sample(side, vk2, s_sx0, s_sw, s_sy1, s_sh, s_zmin, s_zmax, fh, false).a > 0.5:
					keep[key] = true
			if keep.size() * 10 >= before * 4:       # se la sagoma laterale non combacia, non si scolpisce
				vs = keep
	# ogni pixel dello sprite frontale deve restare coperto: se la vista dall'alto non lo conferma, si mette una lastra sottile
	for i in range(imin, imax):
		var px2 := int(floor(fcx - (i + 0.5)))
		if px2 < fx0 or px2 > fx1:
			continue
		for j in fh:
			if front.get_pixel(px2, fy1 - j).a < 0.5:
				continue
			var any := false
			for k in range(-nz, nz):
				if vs.has(Vector3i(i, j, k)):
					any = true
					break
			if not any:
				vs[Vector3i(i, j, -1)] = true
				vs[Vector3i(i, j, 0)] = true
	var bw := 0
	var bcx := 0.0
	var by1 := 0
	if back != null:
		var bx0 := back.get_width()
		var bx1 := -1
		var byy := -1
		for y in back.get_height():
			for x in back.get_width():
				if back.get_pixel(x, y).a > 0.5:
					bx0 = mini(bx0, x)
					bx1 = maxi(bx1, x)
					byy = maxi(byy, y)
		if bx1 >= 0:
			bw = bx1 - bx0 + 1
			bcx = (bx0 + bx1 + 1) * 0.5
			by1 = byy
	var offs: Array = [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]
	for key in vs:
		var kk: Vector3i = key
		var fxp := clampi(int(floor(fcx - (kk.x + 0.5))), 0, w - 1)
		var fyp := clampi(fy1 - kk.y, 0, h - 1)
		var fc := front.get_pixel(fxp, fyp)
		fc.a = 1.0
		var uu := clampi(int(floor(tcx + (kk.x + 0.5) * s)), 0, tw - 1)
		var vv := clampi(int(floor(tcy + (kk.z + 0.5) * s)), 0, th - 1)
		var tc := topc.get_pixel(uu, vv)
		tc.a = 1.0
		var x0 := kk.x * vox
		var x1 := x0 + vox
		var y0 := kk.y * vox
		var y1 := y0 + vox
		var z0 := kk.z * vox
		var z1 := z0 + vox
		for d in 5:
			if vs.has(kk + (offs[d] as Vector3i)):
				continue
			match d:
				0, 1:      # fianchi: dallo sprite di profilo se c'e', altrimenti fra i colori del fronte e quelli visti dall'alto
					var sc := fc.lerp(tc, 0.45)
					sc = Color(sc.r * 0.74, sc.g * 0.74, sc.b * 0.76, 1.0)
					if use_side:
						var sp := _side_sample(side, kk, s_sx0, s_sw, s_sy1, s_sh, s_zmin, s_zmax, fh, d == 1)
						if sp.a > 0.5:
							sc = Color(sp.r * 0.92, sp.g * 0.92, sp.b * 0.92, 1.0)
					if d == 0:
						quad(Vector3(x1, y0, z0), Vector3(x1, y0, z1), Vector3(x1, y1, z1), Vector3(x1, y1, z0), sc)
					else:
						quad(Vector3(x0, y0, z1), Vector3(x0, y0, z0), Vector3(x0, y1, z0), Vector3(x0, y1, z1), sc)
				2:        # sopra: i colori della vista dall'alto
					quad(Vector3(x0, y1, z0), Vector3(x1, y1, z0), Vector3(x1, y1, z1), Vector3(x0, y1, z1), Color(minf(tc.r * 1.1, 1.0), minf(tc.g * 1.1, 1.0), minf(tc.b * 1.1, 1.0), 1.0))
				3:        # dietro
					var bc := fc
					var dark := 0.78
					if back != null and bw > 0:
						var bpx := int(floor(bcx + (kk.x + 0.5)))
						var bpy := by1 - kk.y
						if bpx >= 0 and bpx < back.get_width() and bpy >= 0 and bpy < back.get_height() and back.get_pixel(bpx, bpy).a > 0.5:
							bc = back.get_pixel(bpx, bpy)
							dark = 1.0
					quad(Vector3(x1, y0, z1), Vector3(x0, y0, z1), Vector3(x0, y1, z1), Vector3(x1, y1, z1), Color(bc.r * dark, bc.g * dark, bc.b * dark, 1.0))
				4:        # davanti
					quad(Vector3(x0, y0, z0), Vector3(x1, y0, z0), Vector3(x1, y1, z0), Vector3(x0, y1, z0), fc)


## colore dello sprite di profilo (rivolto a destra) per un cubo: il davanti del personaggio e' a -Z; guardando il fianco +X il davanti sta a destra
func _side_sample(side: Image, k: Vector3i, sx0: int, sw: int, sy1: int, sh: int, zmin: int, zmax: int, fh: int, mirror: bool) -> Color:
	var dd := float(zmax - zmin + 1)
	var fz := (zmax + 1.0 - (k.z + 0.5)) / dd
	if mirror:
		fz = 1.0 - fz
	var px := clampi(sx0 + int(fz * sw), sx0, sx0 + sw - 1)
	var py := clampi(sy1 - int((k.y + 0.5) / float(fh) * sh), sy1 - sh + 1, sy1)
	return side.get_pixel(px, py)


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
func shard(p0: Vector3, p1: Vector3, w1_: float, w2_: float, col: Color, t := 0.4, j := 0.15, wob := 0.12) -> void:
	var w1 := w1_ * sz
	var w2 := w2_ * sz
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


func scale_xz(sx: float, sz2: float) -> void:
	for i in v.size():
		v[i] = Vector3(v[i].x * sx, v[i].y, v[i].z * sz2)


func shift(off: Vector3) -> void:
	for i in v.size():
		v[i] += off


## vista DALL'ALTO di uno sprite frontale: si ricostruisce un solido (profondita' ellittica proporzionale alla larghezza di
## ogni riga di pixel) e lo si legge dall'alto. Ritorna Vector2i(x, z) -> {h: livelli, c: colore}. La parte davanti (-Z)
## scende e prende i colori delle righe piu' basse dello sprite (viso, petto), il dietro e' piu' scuro.
func topcells(img: Image) -> Dictionary:
	var w := img.get_width()
	var h := img.get_height()
	var cells := {}
	for y in h:
		var x := 0
		while x < w:
			if img.get_pixel(x, y).a < 0.5:
				x += 1
				continue
			var x0 := x
			while x < w and img.get_pixel(x, y).a >= 0.5:
				x += 1
			var x1 := x - 1
			var half := (x1 - x0 + 1) * 0.5
			var ctr := (x0 + x1) * 0.5
			var zdm := clampf(half * 0.62, 0.9, 5.5)
			for px in range(x0, x1 + 1):
				var rel := (px - ctr) / maxf(half, 0.5)
				var zd := maxf(0.7, zdm * sqrt(maxf(0.0, 1.0 - rel * rel)))
				var zr := int(floor(zd))
				for zi in range(-zr, zr + 1):
					var key := Vector2i(px, zi)
					if cells.has(key):
						continue
					var front := clampf(-float(zi) / maxf(zd, 1.0), 0.0, 1.0)
					var ys := y
					var lim := mini(h - 1, y + int(round(front * 5.0)))
					for k in range(y, lim + 1):
						if img.get_pixel(px, k).a >= 0.5:
							ys = k
						else:
							break
					var col := img.get_pixel(px, ys)
					if zi > 0:
						col = Color(col.r * 0.78, col.g * 0.78, col.b * 0.8, 1.0)
					var lvl := (h - 1 - y) + 1
					var edge := zr > 0 and absi(zi) >= zr
					cells[key] = {"h": maxi(1, lvl - (1 if edge else 0) - int(round(front * 1.5))), "c": col}
	return cells


func topdown(img: Image, vox: float) -> void:
	var cells := topcells(img)
	var w := img.get_width()
	for key in cells:
		var k: Vector2i = key
		var hv: int = cells[key]["h"]
		var col: Color = cells[key]["c"]
		col.a = 0.9
		var side := Color(col.r * 0.62, col.g * 0.62, col.b * 0.64, 0.95)
		var x0 := (k.x - w * 0.5) * vox
		var z0 := k.y * vox - vox * 0.5
		var top := hv * vox
		quad(Vector3(x0, top, z0), Vector3(x0 + vox, top, z0), Vector3(x0 + vox, top, z0 + vox), Vector3(x0, top, z0 + vox), col)
		for d in 4:
			var offs: Array = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
			var nk: Vector2i = k + (offs[d] as Vector2i)
			var nh := 0
			if cells.has(nk):
				nh = int(cells[nk]["h"])
			if nh >= hv:
				continue
			var lo := nh * vox
			match d:
				0:
					quad(Vector3(x0 + vox, lo, z0), Vector3(x0 + vox, lo, z0 + vox), Vector3(x0 + vox, top, z0 + vox), Vector3(x0 + vox, top, z0), side)
				1:
					quad(Vector3(x0, lo, z0), Vector3(x0, lo, z0 + vox), Vector3(x0, top, z0 + vox), Vector3(x0, top, z0), side)
				2:
					quad(Vector3(x0, lo, z0 + vox), Vector3(x0 + vox, lo, z0 + vox), Vector3(x0 + vox, top, z0 + vox), Vector3(x0, top, z0 + vox), side)
				3:
					quad(Vector3(x0, lo, z0), Vector3(x0 + vox, lo, z0), Vector3(x0 + vox, top, z0), Vector3(x0, top, z0), side)


## celle dall'alto da un'immagine a colori + una di altezze (livelli): Vector2i(x, z) -> {h, c}
func hcells(img: Image, himg: Image, step := 1) -> Dictionary:
	var w := img.get_width()
	var hgt := img.get_height()
	var cells := {}
	for by in range(0, hgt, step):
		for bx in range(0, w, step):
			var r := 0.0
			var g := 0.0
			var bl := 0.0
			var n := 0
			var mh := 0
			for yy in range(by, mini(by + step, hgt)):
				for xx in range(bx, mini(bx + step, w)):
					var c := img.get_pixel(xx, yy)
					if c.a < 0.5:
						continue
					r += c.r
					g += c.g
					bl += c.b
					n += 1
					mh = maxi(mh, int(round(himg.get_pixel(xx, yy).r * 255.0)))
			if n * 2 < step * step:
				continue
			cells[Vector2i(bx / step, by / step - hgt / (2 * step))] = {"h": maxi(1, int(ceil(float(mh) / step))), "c": Color(r / n, g / n, bl / n, 1.0)}
	return cells


func build_cells(cells: Dictionary, w: int, vox: float) -> void:
	for key in cells:
		var k: Vector2i = key
		var hv: int = cells[key]["h"]
		var col: Color = cells[key]["c"]
		var lum := col.r * 0.3 + col.g * 0.55 + col.b * 0.15
		col = Color(lerpf(col.r, lum, 0.3) * 0.68, lerpf(col.g, lum, 0.3) * 0.68, lerpf(col.b, lum, 0.3) * 0.7, 0.92)
		var side := Color(col.r * 0.62, col.g * 0.62, col.b * 0.64, 0.97)
		var x0 := (k.x - w * 0.5) * vox
		var z0 := k.y * vox
		var top := hv * vox
		quad(Vector3(x0, top, z0), Vector3(x0 + vox, top, z0), Vector3(x0 + vox, top, z0 + vox), Vector3(x0, top, z0 + vox), col)
		var offs: Array = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
		for d in 4:
			var nk: Vector2i = k + (offs[d] as Vector2i)
			var nh := 0
			if cells.has(nk):
				nh = int(cells[nk]["h"])
			if nh >= hv:
				continue
			var lo := nh * vox
			match d:
				0:
					quad(Vector3(x0 + vox, lo, z0), Vector3(x0 + vox, lo, z0 + vox), Vector3(x0 + vox, top, z0 + vox), Vector3(x0 + vox, top, z0), side)
				1:
					quad(Vector3(x0, lo, z0), Vector3(x0, lo, z0 + vox), Vector3(x0, top, z0 + vox), Vector3(x0, top, z0), side)
				2:
					quad(Vector3(x0, lo, z0 + vox), Vector3(x0 + vox, lo, z0 + vox), Vector3(x0 + vox, top, z0 + vox), Vector3(x0, top, z0 + vox), side)
				3:
					quad(Vector3(x0, lo, z0), Vector3(x0 + vox, lo, z0), Vector3(x0 + vox, top, z0), Vector3(x0, top, z0), side)


func mesh() -> ArrayMesh:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_COLOR] = c
	var m := ArrayMesh.new()
	if v.size() > 0:
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m
