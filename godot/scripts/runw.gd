class_name RunW
extends RefCounted
## Armi automatiche della partita: partono al livello 1 e crescono a ogni scelta di potenziamento.

const LIST := [
	{"id": "lame", "n": "LAME ORBITANTI", "d": "LAME D'OSSO ROTEANO ATTORNO A TE", "up": "+1 LAMA, PIU' DANNO E RAGGIO", "max": 5},
	{"id": "pugnali", "n": "PUGNALI GOTICI", "d": "LANCIA PUGNALI AL NEMICO PIU' VICINO", "up": "PIU' PUGNALI, PIU' VELOCI", "max": 5},
	{"id": "nova", "n": "ONDA DI CENERE", "d": "UN'ONDA RESPINGE E COLPISCE TUTTI", "up": "ONDA PIU' AMPIA E FREQUENTE", "max": 5},
	{"id": "catena", "n": "FULMINE FUNEBRE", "d": "UNA SCARICA SALTA FRA I NEMICI", "up": "+1 SALTO, PIU' RAPIDA", "max": 5},
]

const START := {"cavaliere": "lame", "cacciatore": "pugnali", "negromante": "catena", "chierico": "nova"}


static func info(id: String) -> Dictionary:
	for w in LIST:
		if w["id"] == id:
			return w
	return {}


static func tick(p: Player, dt: float) -> void:
	if p.run_w.is_empty():
		return
	var main = p.main
	var base: float = p.bd()
	var lv: int
	# ---------------------------------------------------------------- lame orbitanti
	lv = int(p.run_w.get("lame", 0))
	if lv > 0:
		p.blade_ang += (3.0 + 0.25 * lv) * dt
		var n := 1 + lv
		var rad := 28.0 + 3.0 * lv
		if p.blade_hit.size() > 120:
			p.blade_hit.clear()
		var bdmg := base * (0.85 + 0.12 * lv)
		for i in n:
			var a := p.blade_ang + i * TAU / n
			var bp: Vector2 = p.position + Vector2(0, -4) + Vector2.from_angle(a) * rad
			for e in main.enemies:
				if not e.awake:
					continue
				var rr: float = e.radius + 6.0
				if e.position.distance_squared_to(bp) < rr * rr:
					if p.t - float(p.blade_hit.get(e, -1.0)) > 0.35:
						p.blade_hit[e] = p.t
						e.hurt(bdmg, (e.position - p.position).normalized(), 70.0, false)
						p.on_hit(e, bdmg, {})
	# ---------------------------------------------------------------- pugnali
	lv = int(p.run_w.get("pugnali", 0))
	if lv > 0:
		p.knife_t -= dt
		if p.knife_t <= 0.0:
			var tg: Enemy = main.nearest_enemy(p.position, 240.0)
			if tg != null:
				p.knife_t = maxf(0.35, 1.0 - 0.12 * lv)
				var dirv: Vector2 = (tg.position - p.position).normalized()
				var kn := 1 + lv / 2
				for k in kn:
					var off := (k - (kn - 1) * 0.5) * 0.22
					main.spawn_parrow(p.position + Vector2(0, -6), dirv.rotated(off), 250.0, base * (1.0 + 0.1 * lv), 0.9, 1 + lv / 3, Color(0.92, 0.88, 0.62), {}, 0.0, false)
	# ---------------------------------------------------------------- onda di cenere
	lv = int(p.run_w.get("nova", 0))
	if lv > 0:
		var t0: float = float(p.rw_t.get("nova", 2.0)) - dt
		if t0 <= 0.0:
			var rad2 := 40.0 + 10.0 * lv
			var any := false
			for e in main.enemies:
				if e.awake and e.position.distance_squared_to(p.position) < (rad2 + e.radius) * (rad2 + e.radius):
					any = true
					break
			if any:
				t0 = 5.0 - 0.5 * lv
				var nd := base * (1.5 + 0.2 * lv)
				for e in main.enemies.duplicate():
					if e.awake and e.position.distance_squared_to(p.position) < (rad2 + e.radius) * (rad2 + e.radius):
						e.hurt(nd, (e.position - p.position).normalized(), 150.0, false)
						p.on_hit(e, nd, {})
				main.add_ring(p.position, rad2, Color(1.0, 0.6, 0.3))
				main.burst(p.position, Color(0.95, 0.55, 0.25), 30, rad2 * 1.4, 0.45)
				main.burst(p.position, Color(0.5, 0.45, 0.55), 18, rad2 * 1.0, 0.6)
				main.snd("slam")
				main.shake(2.0)
			else:
				t0 = 0.4
		p.rw_t["nova"] = t0
	# ---------------------------------------------------------------- fulmine funebre
	lv = int(p.run_w.get("catena", 0))
	if lv > 0:
		var t1: float = float(p.rw_t.get("catena", 1.5)) - dt
		if t1 <= 0.0:
			var first: Enemy = main.nearest_enemy(p.position, 200.0)
			if first != null:
				t1 = maxf(0.8, 2.4 - 0.25 * lv)
				var hit: Array = [first]
				var cur: Enemy = first
				var jumps := 2 + lv
				var cd := base * (1.2 + 0.15 * lv)
				var src: Vector2 = p.position + Vector2(0, -6)
				for j in jumps:
					if cur == null:
						break
					main.add_bolt(src, cur.position + Vector2(0, -6))
					cur.hurt(cd * pow(0.92, j), (cur.position - src).normalized(), 40.0, false)
					p.on_hit(cur, cd, {})
					src = cur.position + Vector2(0, -6)
					var nxt: Enemy = null
					var bd2 := 6400.0
					for e in main.enemies:
						if e.awake and not hit.has(e):
							var d2: float = e.position.distance_squared_to(cur.position)
							if d2 < bd2:
								bd2 = d2
								nxt = e
					if nxt != null:
						hit.append(nxt)
					cur = nxt
			else:
				t1 = 0.4
		p.rw_t["catena"] = t1
