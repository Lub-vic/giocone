class_name W3DStructs
extends RefCounted
## Strutture e meraviglie naturali del mondo 3D, coerenti con il bioma: mulini, granai, stalle, torri, palafitte, rifugi di ghiaccio,
## fornaci, edicole, archi in rovina, cerchi di pietre, alberi giganti, funghi, stagni, guglie di ghiaccio, bocche di lava...
## Ogni costruttore e' statico: (builder, posizione, rotazione, rng, collisioni, luci). Colori con alfa < 1 = emissivi (finestre, brace, funghi).
## Biomi: 0 villaggio di cenere, 1 cimitero, 2 foresta degli impiccati, 3 palude, 4 cattedrale in rovina, 5 vetta gelata, 6 fonderie.

# tipo: [nome nel catalogo, raggio libero attorno (unita'), biomi in cui compare]
const KINDS := {
	"mill": ["Mulino a vento", 5.5, [0]],
	"barn": ["Granaio", 6.0, [0]],
	"stable": ["Stalla", 5.0, [0, 2]],
	"hay_stacks": ["Covoni di fieno", 3.5, [0]],
	"hunter_lodge": ["Capanna del cacciatore", 4.0, [2]],
	"watchtower": ["Torre di vedetta in legno", 3.0, [2, 4]],
	"swamp_hut": ["Palafitta della palude", 3.8, [3]],
	"ice_cabin": ["Rifugio di ghiaccio", 3.6, [5]],
	"smelter": ["Fornace con ciminiera", 4.5, [6]],
	"shrine": ["Edicola votiva", 1.8, [0, 1, 4]],
	"ruined_arch": ["Arco in rovina", 4.0, [4]],
	"bell_frame": ["Campanile crollato", 3.5, [4]],
	"stone_circle": ["Cerchio di menhir", 5.0, [1, 2, 5]],
	"giant_tree": ["Grande albero morto", 3.5, [0, 1, 2]],
	"mushroom_ring": ["Cerchio di funghi", 3.5, [2, 3]],
	"giant_mushrooms": ["Funghi giganti", 3.5, [3]],
	"bog_pond": ["Stagno di palude", 4.0, [3]],
	"ice_spire": ["Guglie di ghiaccio", 3.0, [5]],
	"lava_vent": ["Bocca di lava", 3.2, [6]],
	"fallen_columns": ["Colonne crollate", 4.0, [4, 6]],
	"cairn": ["Ometto di pietre", 1.6, [1, 4, 5]],
	"rock_arch": ["Arco di roccia", 4.5, [4, 5, 6]],
	"bone_ribs": ["Carcassa gigante", 4.0, [1, 3, 6, 5]],
	# vegetazione e natura tipica di ogni bioma (4o elemento "flora": la piazza il generatore del terreno, non i lotti)
	"pine": ["Pino scuro", 1.8, [2], "flora"],
	"oak": ["Quercia rigogliosa", 2.6, [2], "flora"],
	"cypress": ["Cipresso", 1.2, [2, 4], "flora"],
	"charred_tree": ["Albero carbonizzato", 1.4, [6], "flora"],
	"mangrove": ["Mangrovia", 2.4, [3], "flora"],
	"snow_pine": ["Pino innevato", 1.8, [5], "flora"],
	"willow": ["Salice piangente", 2.0, [3], "flora"],
	"reed_clump": ["Canneto", 1.4, [3], "flora"],
	"mud_pool": ["Pozza di fango", 2.0, [3], "flora"],
	"marble_rubble": ["Rovine di marmo", 2.2, [4], "flora"],
	"basalt_spire": ["Guglia di basalto", 1.6, [6], "flora"],
	"ash_mound": ["Cumulo di cenere", 1.6, [6], "flora"],
	"ice_boulder": ["Blocchi di ghiaccio", 1.8, [5], "flora"],
	# grandi strutture visitabili (4 elementi: l'ultimo le segna come "grandi"; le piazza il pianificatore, non i lotti)
	"castle_ruin": ["Castello in rovina", 40.0, [0, 1, 2, 4, 5], true],
	"monastery_ruin": ["Monastero in rovina", 17.0, [1, 4], true],
	"palisade_fort": ["Forte di palizzata", 16.0, [0, 2], true],
	"arena_ruin": ["Anfiteatro in rovina", 15.0, [4, 6], true],
	"ghost_village": ["Villaggio abbandonato", 19.0, [0, 1, 3], true],
	"mine_entrance": ["Ingresso di miniera", 11.0, [5, 6], true],
	"ice_temple": ["Tempio nel ghiaccio", 12.0, [5], true],
	"bandit_camp": ["Accampamento di banditi", 10.0, [0, 2, 3, 6], true],
}

const WOOD := Color(0.25, 0.17, 0.11)
const WOOD_L := Color(0.36, 0.25, 0.15)
const WOOD_D := Color(0.15, 0.1, 0.07)
const STONE := Color(0.27, 0.265, 0.285)
const STONE_L := Color(0.36, 0.35, 0.37)
const THATCH := Color(0.42, 0.34, 0.16)
const IRON := Color(0.16, 0.16, 0.18)
const BONE := Color(0.72, 0.69, 0.6)


static func catalog() -> Array:
	var out: Array = []
	for k in KINDS:
		out.append([k, str(KINDS[k][0]), true])
	return out


static func radius(k: String) -> float:
	return float(KINDS[k][1]) if KINDS.has(k) else 1.5


## sceglie una struttura adatta al bioma (o "" se il bioma non ne ha)
static func pick(bio: int, r: RandomNumberGenerator) -> String:
	var opts: Array = []
	for k in KINDS:
		if (KINDS[k] as Array).size() == 3 and (KINDS[k][2] as Array).has(bio):
			opts.append(k)
	if opts.is_empty():
		return ""
	return str(opts[r.randi() % opts.size()])


## sceglie una grande struttura adatta al bioma
static func pick_big(bio: int, r: RandomNumberGenerator) -> String:
	var opts: Array = []
	for k in KINDS:
		if (KINDS[k] as Array).size() > 3 and KINDS[k][3] is bool and (KINDS[k][2] as Array).has(bio):
			opts.append(k)
	if opts.is_empty():
		return ""
	return str(opts[r.randi() % opts.size()])


static func build(k: String, o: W3DBuilder, p: Vector2, yaw: float, r: RandomNumberGenerator, cols: Array, lamps: Array) -> bool:
	if not KINDS.has(k):
		return false
	if W3DBig.KINDS.has(k):
		W3DBig.build(k, o, p, yaw, r, cols, lamps)
		return true
	if (KINDS[k] as Array).size() > 3 and str(KINDS[k][3]) == "flora":
		_flora(k, o, Transform3D(Basis(Vector3.UP, yaw), Vector3(p.x, 0.0, p.y)), p, r, cols)
		return true
	var t := Transform3D(Basis(Vector3.UP, yaw), Vector3(p.x, 0.0, p.y))
	match k:
		"mill":
			_mill(o, t, p, yaw, r, cols, lamps)
		"barn":
			_barn(o, t, p, yaw, r, cols, lamps)
		"stable":
			_stable(o, t, p, yaw, r, cols)
		"hay_stacks":
			_hay_stacks(o, t, p, r, cols)
		"hunter_lodge":
			_lodge(o, t, p, yaw, r, cols, lamps)
		"watchtower":
			_tower(o, t, p, r, cols, lamps)
		"swamp_hut":
			_swamp_hut(o, t, p, yaw, r, cols, lamps)
		"ice_cabin":
			_ice_cabin(o, t, p, r, cols, lamps)
		"smelter":
			_smelter(o, t, p, yaw, r, cols, lamps)
		"shrine":
			_shrine(o, t, p, r, cols, lamps)
		"ruined_arch":
			_arch(o, t, p, yaw, r, cols)
		"bell_frame":
			_bell(o, t, p, yaw, r, cols)
		"stone_circle":
			_circle(o, t, p, r, cols, lamps)
		"giant_tree":
			_giant_tree(o, t, p, r, cols)
		"mushroom_ring":
			_mushroom_ring(o, t, r)
		"giant_mushrooms":
			_giant_mushrooms(o, t, p, r, cols, lamps)
		"bog_pond":
			_pond(o, t, r)
		"ice_spire":
			_spires(o, t, p, r, cols)
		"lava_vent":
			_lava(o, t, p, r, cols, lamps)
		"fallen_columns":
			_columns(o, t, p, yaw, r, cols)
		"cairn":
			_cairn(o, t, p, r, cols)
		"rock_arch":
			_rock_arch(o, t, p, yaw, r, cols)
		"bone_ribs":
			_ribs(o, t, p, yaw, r, cols)
	return true


# ------------------------------------------------------------------ utilita'
static func _bx(o: W3DBuilder, t: Transform3D, pos: Vector3, size: Vector3, col: Color, j := 0.08) -> void:
	o.box(t * Transform3D(Basis.IDENTITY, pos), size, col, j, 8)


static func _bxr(o: W3DBuilder, t: Transform3D, pos: Vector3, rot: Basis, size: Vector3, col: Color, j := 0.08) -> void:
	o.box(t * Transform3D(rot, pos), size, col, j, 8)


## cilindro in piedi su pos (alla quota y)
static func _cy(o: W3DBuilder, t: Transform3D, pos: Vector3, rb: float, rt: float, h: float, segs: int, col: Color, j := 0.08) -> void:
	o.cyl(t * Transform3D(Basis.IDENTITY, pos), rb, rt, h, segs, col, j)


## trave orizzontale lungo X (o lungo Z con rot) a quota y
static func _beam_x(o: W3DBuilder, t: Transform3D, pos: Vector3, len: float, rad: float, col: Color) -> void:
	o.cyl(t * Transform3D(Basis(Vector3(0, 0, 1), PI * 0.5), pos + Vector3(len * 0.5, 0, 0)), rad, rad, len, 6, col, 0.1)


static func _beam_z(o: W3DBuilder, t: Transform3D, pos: Vector3, len: float, rad: float, col: Color) -> void:
	o.cyl(t * Transform3D(Basis(Vector3(1, 0, 0), PI * 0.5), pos + Vector3(0, 0, -len * 0.5)), rad, rad, len, 6, col, 0.1)


## tetto a due falde: lunghezza lungo X, larghezza lungo Z, colmo a quota y
static func _roof(o: W3DBuilder, t: Transform3D, ctr: Vector3, len: float, wid: float, rise: float, col: Color) -> void:
	var ang := atan2(rise, wid * 0.5)
	var sl := sqrt(rise * rise + wid * wid * 0.25) + 0.25
	for sg in [-1.0, 1.0]:
		o.box(t * Transform3D(Basis(Vector3.RIGHT, sg * ang), ctr + Vector3(0, rise * 0.5, sg * wid * 0.25)), Vector3(len, 0.14, sl), col, 0.1, 8)
	o.box(t * Transform3D(Basis.IDENTITY, ctr + Vector3(0, rise + 0.03, 0)), Vector3(len + 0.1, 0.12, 0.2), _dk(col, 0.7), 0.06, 8)


static func _dk(c: Color, k: float) -> Color:
	return Color(c.r * k, c.g * k, c.b * k, c.a)


static func _bale(o: W3DBuilder, t: Transform3D, pos: Vector3, r: RandomNumberGenerator) -> void:
	var col := Color(0.55, 0.45, 0.2).lerp(Color(0.62, 0.52, 0.26), r.randf())
	o.cyl(t * Transform3D(Basis(Vector3(0, 0, 1), PI * 0.5) * Basis(Vector3.RIGHT, r.randf_range(-0.2, 0.2)), pos + Vector3(0.4, 0.4, 0)), 0.42, 0.42, 0.8, 7, col, 0.1)


static func _cbox(cols: Array, p: Vector2, yaw: float, local: Vector2, half: Vector2) -> void:
	# collisione di una scatola in coordinate locali (x, z) ruotata con la struttura
	var w := Vector3(local.x, 0.0, local.y)
	var rw := Basis(Vector3.UP, yaw) * w
	cols.append(["b", p + Vector2(rw.x, rw.z), half, yaw])


# ------------------------------------------------------------------ strutture
static func _mill(o: W3DBuilder, t: Transform3D, p: Vector2, yaw: float, r: RandomNumberGenerator, cols: Array, lamps: Array) -> void:
	_cy(o, t, Vector3(0, 0, 0), 2.1, 1.55, 5.6, 8, Color(0.34, 0.31, 0.29), 0.1)
	for q in 3:       # fasce di mattoni piu' scuri
		_cy(o, t, Vector3(0, 0.9 + q * 1.7, 0), 2.1 - q * 0.17, 2.1 - q * 0.17 - 0.08, 0.12, 8, Color(0.2, 0.18, 0.17), 0.04)
	_cy(o, t, Vector3(0, 5.6, 0), 1.85, 0.12, 2.6, 8, Color(0.2, 0.13, 0.1), 0.1)
	_bx(o, t, Vector3(0, 1.0, 1.95), Vector3(1.0, 2.0, 0.3), WOOD_D)
	_bx(o, t, Vector3(0, 3.6, 1.55), Vector3(0.5, 0.7, 0.2), Color(1.0, 0.8, 0.45, 0.2))
	# pale: albero e quattro braccia a croce con graticcio
	var hub := Vector3(0, 5.0, 2.0)
	_bx(o, t, hub, Vector3(0.45, 0.45, 0.6), WOOD_D)
	for q in 4:
		var rot := Basis(Vector3(0, 0, 1), PI * 0.25 + q * PI * 0.5)
		_bxr(o, t, hub + Vector3(0, 0, 0.35), rot, Vector3(0.18, 5.6, 0.14), WOOD)
		var along := rot * Vector3(0, 1.85, 0)
		var side := rot * Vector3(0.38, 0, 0)
		_bxr(o, t, hub + Vector3(0, 0, 0.42) + along + side, rot, Vector3(0.7, 3.1, 0.06), Color(0.5, 0.45, 0.36), 0.06)
		_bxr(o, t, hub + Vector3(0, 0, 0.46) + along + side, rot, Vector3(0.06, 3.1, 0.06), WOOD_D, 0.02)
	for sx in 3:
		_bx(o, t, Vector3(-2.4 + sx * 0.5, 0.2, 2.8), Vector3(0.4, 0.4, 0.4), Color(0.5, 0.42, 0.2), 0.1)
	cols.append(["c", p, 2.2])


static func _barn(o: W3DBuilder, t: Transform3D, p: Vector2, yaw: float, r: RandomNumberGenerator, cols: Array, lamps: Array) -> void:
	var red := Color(0.33, 0.14, 0.1)
	_bx(o, t, Vector3(0, 1.7, 0), Vector3(7.2, 3.4, 5.0), red, 0.1)
	_bx(o, t, Vector3(0, 0.15, 0), Vector3(7.5, 0.3, 5.3), STONE, 0.1)
	_roof(o, t, Vector3(0, 3.4, 0), 7.8, 5.6, 2.0, Color(0.2, 0.14, 0.11))
	# portone a due ante con croci di legno
	_bx(o, t, Vector3(0, 1.4, 2.55), Vector3(2.8, 2.8, 0.12), WOOD_L)
	for sg in [-1.0, 1.0]:
		_bxr(o, t, Vector3(sg * 0.7, 1.4, 2.63), Basis(Vector3(0, 0, 1), sg * 0.7), Vector3(0.12, 3.2, 0.06), WOOD_D, 0.02)
		_bxr(o, t, Vector3(sg * 0.7, 1.4, 2.63), Basis(Vector3(0, 0, 1), -sg * 0.7), Vector3(0.12, 3.2, 0.06), WOOD_D, 0.02)
	_bx(o, t, Vector3(0, 4.0, 2.58), Vector3(1.0, 0.8, 0.1), Color(1.0, 0.75, 0.4, 0.15))      # abbaino del fienile
	for q in 3:
		_bale(o, t, Vector3(-3.3 + q * 0.9, 0, 3.6 + (q % 2) * 0.5), r)
	_bale(o, t, Vector3(-2.9, 0.8, 3.7), r)
	_cbox(cols, p, yaw, Vector2.ZERO, Vector2(3.7, 2.6))


static func _stable(o: W3DBuilder, t: Transform3D, p: Vector2, yaw: float, r: RandomNumberGenerator, cols: Array) -> void:
	_bx(o, t, Vector3(0, 1.1, -1.4), Vector3(6.0, 2.2, 0.2), WOOD, 0.1)
	for sx in [-3.0, 0.0, 3.0]:
		_bx(o, t, Vector3(sx, 1.1, 1.3), Vector3(0.22, 2.3, 0.22), WOOD_D)
		_bx(o, t, Vector3(sx, 1.1, -1.35), Vector3(0.24, 2.3, 0.24), WOOD_D)
	_roof(o, t, Vector3(0, 2.25, 0), 6.6, 3.4, 0.9, Color(0.3, 0.24, 0.13))
	for sx in [-1.5, 1.5]:       # divisori dei box
		_bx(o, t, Vector3(sx, 0.55, 0.0), Vector3(0.12, 1.1, 2.4), WOOD)
	for sx in [-2.25, 0.0, 2.25]:
		_bx(o, t, Vector3(sx, 0.45, -1.0), Vector3(1.3, 0.3, 0.45), WOOD_L)       # mangiatoia
		_bx(o, t, Vector3(sx, 0.62, -1.0), Vector3(1.1, 0.12, 0.3), Color(0.5, 0.42, 0.2))
	for q in 3:
		_bale(o, t, Vector3(-2.7 + q * 0.8, 0, 2.4), r)
	_cbox(cols, p, yaw, Vector2.ZERO, Vector2(3.2, 1.9))


static func _hay_stacks(o: W3DBuilder, t: Transform3D, p: Vector2, r: RandomNumberGenerator, cols: Array) -> void:
	for q in r.randi_range(4, 6):
		var a := q * TAU / 5.0 + r.randf() * 0.5
		var lp := Vector3(cos(a) * 1.7, 0, sin(a) * 1.7) * (0.6 + r.randf() * 0.6)
		var h := r.randf_range(1.4, 2.0)
		_cy(o, t, lp, 0.9, 0.85, h, 8, Color(0.55, 0.45, 0.2), 0.12)
		_cy(o, t, lp + Vector3(0, h, 0), 0.9, 0.05, 0.9, 8, Color(0.5, 0.4, 0.18), 0.12)
		var wp := t * lp
		cols.append(["c", Vector2(wp.x, wp.z), 0.95])


static func _lodge(o: W3DBuilder, t: Transform3D, p: Vector2, yaw: float, r: RandomNumberGenerator, cols: Array, lamps: Array) -> void:
	for q in 7:         # tronchi orizzontali sovrapposti
		var y := 0.25 + q * 0.34
		_beam_x(o, t, Vector3(-2.1, y, -1.4), 4.2, 0.2, WOOD.lerp(WOOD_L, (q % 3) * 0.3))
		_beam_x(o, t, Vector3(-2.1, y, 1.4), 4.2, 0.2, WOOD.lerp(WOOD_L, (q % 2) * 0.4))
		_beam_z(o, t, Vector3(-2.1, y + 0.17, 1.4), 2.8, 0.2, WOOD_D)
		_beam_z(o, t, Vector3(2.1, y + 0.17, 1.4), 2.8, 0.2, WOOD_D)
	_roof(o, t, Vector3(0, 2.4, 0), 5.2, 3.8, 1.3, Color(0.22, 0.16, 0.1))
	_bx(o, t, Vector3(0, 0.95, 1.62), Vector3(0.9, 1.8, 0.1), WOOD_D)
	_bx(o, t, Vector3(1.4, 1.3, 1.62), Vector3(0.5, 0.5, 0.1), Color(1.0, 0.75, 0.4, 0.2))
	# rastrelliera con pelli e palchi
	_bx(o, t, Vector3(-3.4, 0.9, 0.3), Vector3(0.12, 1.8, 0.12), WOOD_D)
	_bx(o, t, Vector3(-3.4, 0.9, 1.5), Vector3(0.12, 1.8, 0.12), WOOD_D)
	_bx(o, t, Vector3(-3.4, 1.7, 0.9), Vector3(0.12, 0.12, 1.4), WOOD_D)
	_bxr(o, t, Vector3(-3.4, 1.1, 0.9), Basis(Vector3(1, 0, 0), 0.1), Vector3(0.06, 1.2, 0.8), Color(0.35, 0.24, 0.16), 0.1)
	for sg in [-1.0, 1.0]:
		o.shard(t * Vector3(sg * 0.5, 2.55, 1.4), t * Vector3(sg * 0.85, 3.05, 1.55), 0.08, 0.02, Color(0.75, 0.7, 0.6), 0.2, 0.0, 0.0)
	for q in 3:
		_cy(o, t, Vector3(2.8 + (q % 2) * 0.3, q * 0.36, -0.2), 0.2, 0.2, 0.34, 6, Color(0.3, 0.2, 0.12), 0.1)
	var lp := t * Vector3(0, 1.2, 2.2)
	lamps.append(Vector4(lp.x, 1.2, lp.z, 1.4))
	_cbox(cols, p, yaw, Vector2.ZERO, Vector2(2.6, 1.9))


static func _tower(o: W3DBuilder, t: Transform3D, p: Vector2, r: RandomNumberGenerator, cols: Array, lamps: Array) -> void:
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			# gambe inclinate verso l'alto
			var base := Vector3(sx * 1.3, 0, sz * 1.3)
			var top := Vector3(sx * 0.85, 5.2, sz * 0.85)
			o.shard(t * base, t * top, 0.2, 0.17, WOOD, 0.6, 0.0, 0.0)
	for lv in [1.3, 2.9, 4.4]:
		var s := lerpf(1.3, 0.85, lv / 5.2)
		_bx(o, t, Vector3(0, lv, s), Vector3(s * 2.0, 0.1, 0.1), WOOD_D)
		_bx(o, t, Vector3(0, lv, -s), Vector3(s * 2.0, 0.1, 0.1), WOOD_D)
		_bx(o, t, Vector3(s, lv, 0), Vector3(0.1, 0.1, s * 2.0), WOOD_D)
		_bx(o, t, Vector3(-s, lv, 0), Vector3(0.1, 0.1, s * 2.0), WOOD_D)
	_bx(o, t, Vector3(0, 5.25, 0), Vector3(2.4, 0.2, 2.4), WOOD_L)
	for sg in [-1.0, 1.0]:       # parapetto
		_bx(o, t, Vector3(sg * 1.15, 5.8, 0), Vector3(0.1, 0.9, 2.4), WOOD)
		_bx(o, t, Vector3(0, 5.8, sg * 1.15), Vector3(2.4, 0.9, 0.1), WOOD)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_bx(o, t, Vector3(sx * 1.1, 6.3, sz * 1.1), Vector3(0.12, 2.0, 0.12), WOOD_D)
	_cy(o, t, Vector3(0, 7.2, 0), 2.0, 0.05, 1.3, 4, Color(0.22, 0.15, 0.1), 0.08)
	_bxr(o, t, Vector3(0.9, 2.6, 1.15), Basis(Vector3(1, 0, 0), -0.2), Vector3(0.5, 5.4, 0.08), WOOD_L, 0.06)       # scala
	var lp := t * Vector3(0, 6.2, 0)
	lamps.append(Vector4(lp.x, 6.0, lp.z, 2.0))
	_bx(o, t, Vector3(0, 6.1, 0), Vector3(0.3, 0.36, 0.3), Color(1.0, 0.8, 0.5, 0.15), 0.0)
	cols.append(["c", p, 1.6])


static func _swamp_hut(o: W3DBuilder, t: Transform3D, p: Vector2, yaw: float, r: RandomNumberGenerator, cols: Array, lamps: Array) -> void:
	o.quad(t * Vector3(-3.2, 0.03, -3.0), t * Vector3(3.4, 0.03, -2.6), t * Vector3(3.0, 0.03, 3.2), t * Vector3(-3.4, 0.03, 2.8), Color(0.04, 0.09, 0.07))
	for sx in [-1.3, 0.0, 1.3]:
		for sz in [-1.0, 1.0]:
			_cy(o, t, Vector3(sx, 0, sz), 0.16, 0.13, 1.5, 5, WOOD_D)
	_bx(o, t, Vector3(0, 1.55, 0), Vector3(3.6, 0.14, 2.8), WOOD_L)
	_bx(o, t, Vector3(0, 2.4, 0), Vector3(2.8, 1.6, 2.0), WOOD, 0.1)
	_cy(o, t, Vector3(0, 3.1, 0), 2.5, 0.05, 1.7, 6, Color(0.24, 0.27, 0.12), 0.14)
	_bx(o, t, Vector3(0, 2.2, 1.03), Vector3(0.7, 1.2, 0.08), WOOD_D)
	_bx(o, t, Vector3(1.0, 2.6, 1.03), Vector3(0.45, 0.45, 0.08), Color(0.7, 1.0, 0.6, 0.18))
	_bxr(o, t, Vector3(0, 0.8, 2.1), Basis(Vector3(1, 0, 0), 0.55), Vector3(0.7, 2.0, 0.07), WOOD_L, 0.05)       # scaletta
	_bx(o, t, Vector3(1.9, 1.9, 1.3), Vector3(0.04, 0.5, 0.04), IRON)
	_bx(o, t, Vector3(1.9, 1.55, 1.3), Vector3(0.22, 0.3, 0.22), Color(0.6, 1.0, 0.55, 0.15), 0.0)
	var lp := t * Vector3(1.9, 1.6, 1.3)
	lamps.append(Vector4(lp.x, 1.6, lp.z, 1.5))
	for q in 9:        # canne
		var a := r.randf() * TAU
		var d := r.randf_range(2.3, 3.4)
		var b := t * Vector3(cos(a) * d, 0, sin(a) * d)
		o.shard(b, b + Vector3(r.randf_range(-0.2, 0.2), r.randf_range(1.2, 2.0), r.randf_range(-0.2, 0.2)), 0.07, 0.01, Color(0.25, 0.3, 0.12), 0.3, 0.0, 0.0)
	_cbox(cols, p, yaw, Vector2.ZERO, Vector2(1.9, 1.5))


static func _ice_cabin(o: W3DBuilder, t: Transform3D, p: Vector2, r: RandomNumberGenerator, cols: Array, lamps: Array) -> void:
	var ice := Color(0.68, 0.8, 0.9)
	o.blob(t * Vector3(0, 0, 0), Vector3(2.5, 1.9, 2.5), ice, 9, 5, 0.1, 0.04)
	o.blob(t * Vector3(0, 0.2, 2.3), Vector3(1.0, 0.95, 1.4), ice.lerp(Color.WHITE, 0.25), 7, 4, 0.1, 0.04)
	_bx(o, t, Vector3(0, 0.55, 3.35), Vector3(0.85, 1.0, 0.08), Color(0.1, 0.13, 0.2))
	_bx(o, t, Vector3(0.9, 1.1, 1.9), Vector3(0.5, 0.5, 0.08), Color(1.0, 0.85, 0.5, 0.2))
	for q in 6:        # cumuli di neve attorno e blocchi di ghiaccio
		var a := r.randf() * TAU
		var d := r.randf_range(2.6, 3.6)
		o.blob(t * Vector3(cos(a) * d, 0, sin(a) * d), Vector3(r.randf_range(0.6, 1.1), r.randf_range(0.3, 0.55), r.randf_range(0.6, 1.1)), Color(0.85, 0.9, 0.96), 6, 3, 0.1, 0.04)
	var lp := t * Vector3(0.9, 1.1, 2.1)
	lamps.append(Vector4(lp.x, 1.1, lp.z, 1.3))
	cols.append(["c", p, 2.4])


static func _smelter(o: W3DBuilder, t: Transform3D, p: Vector2, yaw: float, r: RandomNumberGenerator, cols: Array, lamps: Array) -> void:
	var brick := Color(0.3, 0.14, 0.1)
	_bx(o, t, Vector3(0, 0.8, 0), Vector3(3.6, 1.6, 3.0), brick, 0.1)
	_cy(o, t, Vector3(0, 1.6, 0), 1.3, 0.95, 3.4, 8, Color(0.26, 0.12, 0.09), 0.1)
	_cy(o, t, Vector3(0, 5.0, 0), 0.7, 0.5, 4.2, 8, Color(0.2, 0.1, 0.08), 0.1)
	_cy(o, t, Vector3(0, 9.2, 0), 0.62, 0.62, 0.35, 8, Color(0.12, 0.08, 0.07), 0.05)
	_cy(o, t, Vector3(0, 9.3, 0), 0.45, 0.4, 0.05, 8, Color(1.0, 0.45, 0.12, 0.1), 0.0)
	_bx(o, t, Vector3(0, 0.7, 1.55), Vector3(1.4, 1.1, 0.15), Color(1.0, 0.5, 0.15, 0.12))         # bocca del forno
	_bx(o, t, Vector3(0, 0.7, 1.5), Vector3(1.8, 1.4, 0.1), Color(0.08, 0.06, 0.06))
	for q in 3:        # lingotti e carrello
		_bx(o, t, Vector3(-2.4 + q * 0.3, 0.12 + (q % 2) * 0.12, 2.2), Vector3(0.5, 0.2, 0.25), Color(0.35, 0.33, 0.36))
	_bx(o, t, Vector3(2.5, 0.45, 2.1), Vector3(0.9, 0.5, 0.6), Color(0.2, 0.18, 0.18))
	for sg in [-1.0, 1.0]:
		_cy(o, t, Vector3(2.5 + sg * 0.3, 0, 2.1 - 0.35), 0.17, 0.17, 0.2, 6, IRON)
	for q in 5:
		var a := r.randf() * TAU
		var d := r.randf_range(2.3, 3.4)
		o.quad(t * Vector3(cos(a) * d - 0.3, 0.03, sin(a) * d), t * Vector3(cos(a) * d + 0.3, 0.03, sin(a) * d - 0.2), t * Vector3(cos(a) * d + 0.4, 0.03, sin(a) * d + 0.3), t * Vector3(cos(a) * d - 0.2, 0.03, sin(a) * d + 0.25), Color(1.0, 0.4, 0.1, 0.1))
	var smk := t * Vector3(0, 9.4, 0)
	o.smokes.append(Vector3(smk.x, 9.4, smk.z))
	var lp := t * Vector3(0, 1.0, 2.0)
	lamps.append(Vector4(lp.x, 1.0, lp.z, 2.4))
	_cbox(cols, p, yaw, Vector2.ZERO, Vector2(1.9, 1.6))
	_cbox(cols, p, yaw, Vector2(0, 0), Vector2(1.5, 1.5))


static func _shrine(o: W3DBuilder, t: Transform3D, p: Vector2, r: RandomNumberGenerator, cols: Array, lamps: Array) -> void:
	_bx(o, t, Vector3(0, 0.2, 0), Vector3(1.3, 0.4, 1.1), STONE, 0.1)
	_bx(o, t, Vector3(0, 1.2, 0), Vector3(0.9, 1.6, 0.7), STONE_L, 0.1)
	_bx(o, t, Vector3(0, 1.4, 0.3), Vector3(0.5, 0.8, 0.18), Color(0.04, 0.035, 0.04))       # nicchia
	_bx(o, t, Vector3(0, 1.25, 0.34), Vector3(0.12, 0.22, 0.1), Color(1.0, 0.85, 0.45, 0.15), 0.0)   # candela
	_cy(o, t, Vector3(0, 2.0, 0), 0.75, 0.08, 0.7, 4, Color(0.2, 0.2, 0.22), 0.08)
	for q in 4:
		_bx(o, t, Vector3(-0.6 + q * 0.4, 0.45, 0.7 + (q % 2) * 0.15), Vector3(0.14, 0.1, 0.14), Color(0.55, 0.15, 0.2).lerp(Color(0.8, 0.7, 0.3), r.randf()), 0.05)
	var lp := t * Vector3(0, 1.3, 0.6)
	lamps.append(Vector4(lp.x, 1.3, lp.z, 1.1))
	cols.append(["c", p, 0.8])


static func _arch(o: W3DBuilder, t: Transform3D, p: Vector2, yaw: float, r: RandomNumberGenerator, cols: Array) -> void:
	for sg in [-1.0, 1.0]:
		var h := 4.2 if sg < 0.0 else r.randf_range(2.2, 3.4)      # un lato crollato
		_bx(o, t, Vector3(sg * 1.9, h * 0.5, 0), Vector3(0.95, h, 0.95), STONE, 0.14)
		_bx(o, t, Vector3(sg * 1.9, 0.18, 0), Vector3(1.2, 0.36, 1.2), STONE_L, 0.1)
	for q in 5:        # conci dell'arco sul lato intatto
		var a := PI + q * PI / 6.0
		_bxr(o, t, Vector3(cos(a) * 1.9 + 0.0, 4.2 + sin(a) * 1.5 * -1.0 + 0.2, 0), Basis(Vector3(0, 0, 1), a + PI * 0.5), Vector3(0.85, 0.5, 0.9), STONE, 0.14)
	for q in 6:        # macerie
		var s := r.randf_range(0.35, 0.8)
		o.rock(t * Vector3(r.randf_range(-3.0, 3.0), s * 0.4, r.randf_range(-1.6, 1.6)), Vector3(s, s * 0.7, s), STONE, 0.16, 0.4, r.randf() * TAU)
	_cbox(cols, p, yaw, Vector2(-1.9, 0), Vector2(0.6, 0.6))
	_cbox(cols, p, yaw, Vector2(1.9, 0), Vector2(0.6, 0.6))


static func _bell(o: W3DBuilder, t: Transform3D, p: Vector2, yaw: float, r: RandomNumberGenerator, cols: Array) -> void:
	for sg in [-1.0, 1.0]:
		_bx(o, t, Vector3(sg * 1.3, 1.9, 0), Vector3(0.45, 3.8, 0.45), STONE, 0.12)
	_bx(o, t, Vector3(0, 3.7, 0), Vector3(3.2, 0.4, 0.5), WOOD, 0.1)
	_cy(o, t, Vector3(0, 2.1, 0), 0.8, 0.45, 1.5, 8, Color(0.5, 0.38, 0.14), 0.08)
	_cy(o, t, Vector3(0, 3.55, 0), 0.07, 0.07, 0.3, 4, IRON, 0.02)
	_bx(o, t, Vector3(0, 2.3, 0.82), Vector3(0.06, 0.5, 0.06), Color(0.04, 0.03, 0.03), 0.0)       # crepa
	for q in 5:
		var s := r.randf_range(0.4, 0.9)
		o.rock(t * Vector3(r.randf_range(-2.5, 2.5), s * 0.4, r.randf_range(-1.8, 1.8)), Vector3(s, s * 0.7, s * 0.9), STONE_L, 0.16, 0.4, r.randf() * TAU)
	_bxr(o, t, Vector3(2.4, 0.2, 1.0), Basis(Vector3.UP, 0.5), Vector3(2.6, 0.3, 0.3), WOOD_D, 0.1)       # trave caduta
	_cbox(cols, p, yaw, Vector2.ZERO, Vector2(1.7, 0.6))


static func _circle(o: W3DBuilder, t: Transform3D, p: Vector2, r: RandomNumberGenerator, cols: Array, lamps: Array) -> void:
	var n := r.randi_range(7, 9)
	for q in n:
		var a := TAU * q / n
		var h := r.randf_range(1.8, 3.1)
		if q == 2 and r.randf() < 0.6:
			h *= 0.4       # un menhir caduto o spezzato
		var wp := t * Vector3(cos(a) * 3.3, 0, sin(a) * 3.3)
		o.rock(Vector3(wp.x, h * 0.5, wp.z), Vector3(0.9, h, 0.7), Color(0.23, 0.23, 0.25), 0.14, 0.3, a + r.randf_range(-0.2, 0.2))
		cols.append(["c", Vector2(wp.x, wp.z), 0.55])
	o.cyl(t * Transform3D(Basis.IDENTITY, Vector3(0, 0, 0)), 1.0, 0.95, 0.18, 8, Color(0.26, 0.25, 0.28), 0.1)
	o.cyl(t * Transform3D(Basis.IDENTITY, Vector3(0, 0.18, 0)), 0.55, 0.5, 0.02, 8, Color(0.45, 0.35, 1.0, 0.2), 0.0)      # runa fioca
	var lp := t * Vector3(0, 0.4, 0)
	lamps.append(Vector4(lp.x, 0.4, lp.z, 1.1))


static func _giant_tree(o: W3DBuilder, t: Transform3D, p: Vector2, r: RandomNumberGenerator, cols: Array) -> void:
	var col := Color(0.15, 0.1, 0.075)
	_cy(o, t, Vector3(0, 0, 0), 1.2, 0.65, 5.0, 7, col, 0.14)
	for q in 6:        # radici
		var a := TAU * q / 6.0 + r.randf() * 0.4
		o.shard(t * Vector3(cos(a) * 0.5, 0.9, sin(a) * 0.5), t * Vector3(cos(a) * 2.3, 0.0, sin(a) * 2.3), 0.4, 0.1, col, 0.4, 0.0, 0.05)
	o.rock(t * Vector3(0.5, 2.4, 0.5), Vector3(0.5, 0.7, 0.4), Color(0.04, 0.03, 0.03), 0.1, 0.2, 1.0)       # cavita' nel tronco
	for q in 5:
		var a2 := TAU * q / 5.0 + r.randf() * 0.5
		var base := Vector3(0, 4.2 + r.randf() * 0.8, 0)
		_limb(o, t, base, Basis(Vector3.UP, a2) * Basis(Vector3.FORWARD, r.randf_range(0.7, 1.15)), r.randf_range(2.6, 3.6), 0.3, 3, r, col)
	cols.append(["c", p, 1.3])


static func _limb(o: W3DBuilder, t: Transform3D, pos: Vector3, rot: Basis, len: float, rad: float, depth: int, r: RandomNumberGenerator, col: Color) -> void:
	var lt := t * Transform3D(rot, pos)
	o.cyl(lt, rad, rad * 0.62, len, 5, col, 0.14)
	if depth <= 0:
		return
	var tip := lt * Vector3(0, len, 0)
	for q in 2:
		var nr := rot * Basis(Vector3.UP, r.randf() * TAU) * Basis(Vector3.RIGHT, r.randf_range(0.5, 1.0))
		_limb(o, Transform3D.IDENTITY, tip, nr, len * 0.66, rad * 0.6, depth - 1, r, col)


static func _mushroom(o: W3DBuilder, t: Transform3D, pos: Vector3, h: float, cap: float, col: Color, glow: Color) -> void:
	_cy(o, t, pos, cap * 0.2, cap * 0.14, h, 6, Color(0.7, 0.68, 0.6), 0.1)
	o.blob(t * (pos + Vector3(0, h, 0)), Vector3(cap, cap * 0.55, cap), col, 8, 4, 0.1, 0.05)
	o.blob(t * (pos + Vector3(0, h + cap * 0.2, 0)), Vector3(cap * 0.5, cap * 0.36, cap * 0.5), glow, 6, 3, 0.1, 0.03)


static func _mushroom_ring(o: W3DBuilder, t: Transform3D, r: RandomNumberGenerator) -> void:
	for q in 10:
		var a := TAU * q / 10.0 + r.randf() * 0.2
		var d := 2.4 + r.randf() * 0.25
		var h := r.randf_range(0.3, 0.6)
		_mushroom(o, t, Vector3(cos(a) * d, 0, sin(a) * d), h, r.randf_range(0.25, 0.4), Color(0.45, 0.2, 0.5), Color(0.7, 1.0, 0.8, 0.2))


static func _giant_mushrooms(o: W3DBuilder, t: Transform3D, p: Vector2, r: RandomNumberGenerator, cols: Array, lamps: Array) -> void:
	for q in r.randi_range(3, 4):
		var a := TAU * q / 4.0 + r.randf() * 0.6
		var d := r.randf_range(0.6, 2.4)
		var h := r.randf_range(2.0, 3.6)
		var cap := r.randf_range(1.2, 1.9)
		var col := Color(0.15, 0.4, 0.35) if q % 2 == 0 else Color(0.45, 0.22, 0.5)
		_mushroom(o, t, Vector3(cos(a) * d, 0, sin(a) * d), h, cap, col, Color(0.6, 1.0, 0.85, 0.18))
		var wp := t * Vector3(cos(a) * d, 0, sin(a) * d)
		cols.append(["c", Vector2(wp.x, wp.z), 0.45])
	var lp := t * Vector3(0, 2.0, 0)
	lamps.append(Vector4(lp.x, 2.0, lp.z, 1.6))


static func _pond(o: W3DBuilder, t: Transform3D, r: RandomNumberGenerator) -> void:
	var n := 14
	var pts: Array = []
	for q in n:
		var a := TAU * q / n
		var rr := r.randf_range(2.5, 3.6)
		pts.append(t * Vector3(cos(a) * rr, 0.035, sin(a) * rr * 0.8))
	var ctr := t * Vector3(0, 0.035, 0)
	for q in n:
		o.tri(ctr, pts[q], pts[(q + 1) % n], Color(0.04, 0.09, 0.08))
	for q in 4:        # ninfee
		var a2 := r.randf() * TAU
		var d := r.randf_range(0.4, 2.0)
		_cy(o, t, Vector3(cos(a2) * d, 0.04, sin(a2) * d), 0.3, 0.3, 0.02, 6, Color(0.14, 0.3, 0.12), 0.05)
	for q in 12:        # canne ai bordi
		var a3 := r.randf() * TAU
		var b := t * Vector3(cos(a3) * 3.5, 0, sin(a3) * 2.8)
		o.shard(b, b + Vector3(r.randf_range(-0.2, 0.2), r.randf_range(1.0, 1.8), r.randf_range(-0.2, 0.2)), 0.07, 0.01, Color(0.25, 0.3, 0.12), 0.3, 0.0, 0.0)


static func _spires(o: W3DBuilder, t: Transform3D, p: Vector2, r: RandomNumberGenerator, cols: Array) -> void:
	for q in r.randi_range(4, 6):
		var a := TAU * q / 5.0 + r.randf() * 0.6
		var d := r.randf_range(0.2, 1.8)
		var h := r.randf_range(2.0, 5.0)
		var b := t * Vector3(cos(a) * d, 0, sin(a) * d)
		var top := b + Vector3(r.randf_range(-0.4, 0.4), h, r.randf_range(-0.4, 0.4))
		o.shard(b, top, r.randf_range(0.4, 0.7), 0.04, Color(0.62, 0.82, 0.95).lerp(Color.WHITE, r.randf() * 0.3), 0.55, 0.05, 0.0)
	o.blob(t * Vector3(0, 0, 0), Vector3(1.8, 0.45, 1.8), Color(0.85, 0.9, 0.96), 7, 3, 0.1, 0.04)
	cols.append(["c", p, 1.2])


static func _lava(o: W3DBuilder, t: Transform3D, p: Vector2, r: RandomNumberGenerator, cols: Array, lamps: Array) -> void:
	for q in 9:
		var a := TAU * q / 9.0
		var s := r.randf_range(0.6, 1.0)
		o.rock(t * Vector3(cos(a) * 1.6, s * 0.35, sin(a) * 1.6), Vector3(s, s * 0.8, s), Color(0.12, 0.09, 0.09), 0.14, 0.4, a)
	o.cyl(t * Transform3D(Basis.IDENTITY, Vector3(0, 0.02, 0)), 1.35, 1.3, 0.1, 9, Color(1.0, 0.35, 0.08, 0.1), 0.05)
	o.cyl(t * Transform3D(Basis.IDENTITY, Vector3(0, 0.1, 0)), 0.7, 0.5, 0.06, 7, Color(1.0, 0.75, 0.3, 0.05), 0.05)
	o.shard(t * Vector3(0, 0.1, 0), t * Vector3(0.1, 1.7, 0), 0.5, 0.04, Color(1.0, 0.5, 0.12, 0.08), 0.4, 0.0, 0.1)
	for q in 6:        # crepe incandescenti
		var a2 := r.randf() * TAU
		o.quad(t * Vector3(cos(a2) * 1.9, 0.03, sin(a2) * 1.9), t * Vector3(cos(a2) * 2.9 + 0.1, 0.03, sin(a2) * 2.9), t * Vector3(cos(a2) * 2.9 - 0.1, 0.03, sin(a2) * 2.9 + 0.15), t * Vector3(cos(a2) * 1.9 - 0.1, 0.03, sin(a2) * 1.9 + 0.1), Color(1.0, 0.4, 0.1, 0.1))
	var lp := t * Vector3(0, 0.6, 0)
	lamps.append(Vector4(lp.x, 0.7, lp.z, 2.2))
	cols.append(["c", p, 2.0])


static func _columns(o: W3DBuilder, t: Transform3D, p: Vector2, yaw: float, r: RandomNumberGenerator, cols: Array) -> void:
	_bx(o, t, Vector3(-2.0, 0.25, -1.0), Vector3(1.2, 0.5, 1.2), STONE, 0.1)
	_cy(o, t, Vector3(-2.0, 0.5, -1.0), 0.45, 0.4, 1.7, 8, STONE_L, 0.08)       # una colonna ancora in piedi, spezzata
	for q in 3:
		var len := r.randf_range(2.6, 3.6)
		var ang := r.randf_range(-0.5, 0.5)
		var base := Vector3(-0.5 + q * 1.5, 0.45, 0.8 + (q % 2) * 0.9)
		o.cyl(t * Transform3D(Basis(Vector3.UP, ang) * Basis(Vector3(0, 0, 1), PI * 0.5), base + Vector3(len * 0.5, 0, 0)), 0.45, 0.42, len, 8, STONE_L, 0.1)
		_cbox(cols, p, yaw, Vector2(base.x, base.z), Vector2(len * 0.5, 0.5))
	for q in 4:
		var s := r.randf_range(0.3, 0.7)
		o.rock(t * Vector3(r.randf_range(-3.0, 3.0), s * 0.4, r.randf_range(-2.0, 2.0)), Vector3(s, s * 0.7, s), STONE, 0.16, 0.4, r.randf() * TAU)
	_cbox(cols, p, yaw, Vector2(-2.0, -1.0), Vector2(0.65, 0.65))


static func _cairn(o: W3DBuilder, t: Transform3D, p: Vector2, r: RandomNumberGenerator, cols: Array) -> void:
	var y := 0.0
	for q in 6:
		var s := 0.8 - q * 0.11
		o.rock(t * Vector3(r.randf_range(-0.06, 0.06), y + s * 0.3, r.randf_range(-0.06, 0.06)), Vector3(s, s * 0.6, s * 0.9), Color(0.26, 0.26, 0.28).lerp(Color(0.34, 0.33, 0.35), r.randf()), 0.14, 0.3, r.randf() * TAU)
		y += s * 0.5
	cols.append(["c", p, 0.55])


static func _rock_arch(o: W3DBuilder, t: Transform3D, p: Vector2, yaw: float, r: RandomNumberGenerator, cols: Array) -> void:
	var col := Color(0.2, 0.19, 0.22)
	for sg in [-1.0, 1.0]:
		o.rock(t * Vector3(sg * 2.0, 1.7, 0), Vector3(1.9, 3.5, 1.7), col, 0.16, 0.4, sg)
		o.rock(t * Vector3(sg * 2.1, 0.4, 0.4), Vector3(2.4, 0.9, 2.0), col.lerp(Color.BLACK, 0.15), 0.16, 0.4, sg * 2.0)
	o.rock(t * Vector3(0, 3.9, 0), Vector3(5.6, 1.1, 1.5), col.lerp(Color.WHITE, 0.08), 0.16, 0.4, 0.3)
	o.rock(t * Vector3(-1.0, 3.3, 0), Vector3(1.6, 0.9, 1.2), col, 0.16, 0.4, 0.1)
	o.rock(t * Vector3(1.1, 3.35, 0), Vector3(1.5, 0.9, 1.2), col, 0.16, 0.4, 0.6)
	_cbox(cols, p, yaw, Vector2(-2.0, 0), Vector2(1.2, 1.0))
	_cbox(cols, p, yaw, Vector2(2.0, 0), Vector2(1.2, 1.0))


static func _ribs(o: W3DBuilder, t: Transform3D, p: Vector2, yaw: float, r: RandomNumberGenerator, cols: Array) -> void:
	for q in 7:
		var x := -2.6 + q * 0.85
		var sc := 1.0 - absf(q - 3) * 0.14
		for sg in [-1.0, 1.0]:
			for seg in 5:       # costola ad arco fatta di segmenti
				var a0 := seg * 0.32
				var a1 := (seg + 1) * 0.32
				var p0 := Vector3(x, sin(a0) * 1.7 * sc, sg * (1.0 - cos(a0)) * 1.4 * sc - sg * 0.2)
				var p1 := Vector3(x, sin(a1) * 1.7 * sc, sg * (1.0 - cos(a1)) * 1.4 * sc - sg * 0.2)
				o.shard(t * p0, t * p1, 0.16, 0.12, BONE, 0.5, 0.0, 0.0)
	o.box(t * Transform3D(Basis.IDENTITY, Vector3(0, 0.08, 0)), Vector3(6.4, 0.16, 0.22), Color(0.6, 0.57, 0.5), 0.08, 8)
	o.rock(t * Vector3(3.6, 0.5, 0.2), Vector3(1.1, 0.8, 0.9), BONE, 0.1, 0.25, 0.4)      # cranio
	o.rock(t * Vector3(4.2, 0.35, 0.2), Vector3(0.7, 0.45, 0.55), BONE.lerp(Color.BLACK, 0.1), 0.1, 0.25, 0.2)
	_cbox(cols, p, yaw, Vector2(0.4, 0), Vector2(3.5, 0.5))


# ------------------------------------------------------------------ vegetazione dei biomi
static func _flora(k: String, o: W3DBuilder, t: Transform3D, p: Vector2, r: RandomNumberGenerator, cols: Array) -> void:
	match k:
		"pine":
			_pine(o, t, p, r, cols, false)
		"oak":
			_oak(o, t, p, r, cols)
		"cypress":
			_cypress(o, t, p, r, cols)
		"charred_tree":
			_charred(o, t, p, r, cols)
		"mangrove":
			_mangrove(o, t, p, r, cols)
		"snow_pine":
			_pine(o, t, p, r, cols, true)
		"willow":
			_willow(o, t, p, r, cols)
		"reed_clump":
			_reeds(o, t, r)
		"mud_pool":
			_mud(o, t, r)
		"marble_rubble":
			_marble(o, t, p, r, cols)
		"basalt_spire":
			_basalt(o, t, p, r, cols)
		"ash_mound":
			_ash(o, t, r)
		"ice_boulder":
			_ice_boulders(o, t, p, r, cols)


static func _pine(o: W3DBuilder, t: Transform3D, p: Vector2, r: RandomNumberGenerator, cols: Array, snow: bool) -> void:
	var h := r.randf_range(0.85, 1.35)
	_cy(o, t, Vector3(0, 0, 0), 0.34 * h, 0.2 * h, 3.4 * h, 6, Color(0.17, 0.11, 0.075), 0.1)
	var lay := 5
	for i in lay:
		var f := float(i) / lay
		var rad := lerpf(2.1, 0.7, f) * h
		var col := Color(0.04, 0.13, 0.065).lerp(Color(0.07, 0.19, 0.09), r.randf())
		if snow:
			col = Color(0.78, 0.86, 0.92).lerp(Color(0.62, 0.74, 0.84), r.randf() * 0.7)
		_cy(o, t, Vector3(0, (1.2 + i * 1.05) * h, 0), rad, rad * 0.2, 1.5 * h, 7, col, 0.14)
		if snow:       # sotto la neve si intravede il verde
			_cy(o, t, Vector3(0, (1.15 + i * 1.05) * h, 0), rad * 0.97, rad * 0.8, 0.2, 7, Color(0.05, 0.14, 0.08), 0.1)
	cols.append(["c", p, 0.5 * h])


static func _oak(o: W3DBuilder, t: Transform3D, p: Vector2, r: RandomNumberGenerator, cols: Array) -> void:
	var bark := Color(0.17, 0.11, 0.075)
	var h := r.randf_range(0.9, 1.3)
	_cy(o, t, Vector3(0, 0, 0), 0.6 * h, 0.36 * h, 2.6 * h, 7, bark, 0.14)
	for q in 3:       # rami maestri verso la chioma
		var a := TAU * q / 3.0 + r.randf()
		var b := t * Vector3(0, 2.2 * h, 0)
		o.shard(b, b + Vector3(cos(a) * 1.1 * h, 1.1 * h, sin(a) * 1.1 * h), 0.28, 0.1, bark, 0.5, 0.05, 0.0)
	var n := r.randi_range(5, 7)
	for q in n:       # chioma larga fatta di masse di foglie, verdi e rigogliose
		var a2 := TAU * q / n + r.randf() * 0.5
		var d := r.randf_range(0.8, 1.9) * h
		var rad := r.randf_range(1.5, 2.3) * h
		var leaf := Color(0.06, 0.2, 0.07).lerp(Color(0.16, 0.32, 0.1), r.randf())
		o.blob(t * Vector3(cos(a2) * d, (3.5 + r.randf() * 1.0) * h, sin(a2) * d), Vector3(rad, rad * 0.78, rad), leaf, 8, 4, 0.12, 0.06)
	o.blob(t * Vector3(0, 4.7 * h, 0), Vector3(1.9 * h, 1.4 * h, 1.9 * h), Color(0.1, 0.26, 0.09), 8, 4, 0.12, 0.06)
	cols.append(["c", p, 0.6 * h])


static func _cypress(o: W3DBuilder, t: Transform3D, p: Vector2, r: RandomNumberGenerator, cols: Array) -> void:
	var h := r.randf_range(0.9, 1.5)
	_cy(o, t, Vector3(0, 0, 0), 0.22, 0.16, 1.4, 5, Color(0.17, 0.11, 0.08), 0.1)
	o.blob(t * Vector3(0, 3.0 * h, 0), Vector3(0.85, 3.0 * h, 0.85), Color(0.04, 0.12, 0.065).lerp(Color(0.07, 0.17, 0.09), r.randf()), 7, 5, 0.1, 0.04)
	cols.append(["c", p, 0.35])


static func _charred(o: W3DBuilder, t: Transform3D, p: Vector2, r: RandomNumberGenerator, cols: Array) -> void:
	var col := Color(0.05, 0.045, 0.05)
	_cy(o, t, Vector3(0, 0, 0), 0.4, 0.2, 3.2, 5, col, 0.16)
	for q in 4:
		var a := TAU * q / 4.0 + r.randf()
		var b := t * Vector3(0, 2.0 + r.randf() * 1.0, 0)
		o.shard(b, b + Vector3(cos(a) * 1.3, r.randf_range(0.6, 1.4), sin(a) * 1.3), 0.14, 0.02, col, 0.5, 0.05, 0.0)
	for q in 3:        # braci ancora accese nel tronco
		o.box(t * Transform3D(Basis.IDENTITY, Vector3(r.randf_range(-0.2, 0.2), 0.6 + q * 0.8, 0.3)), Vector3(0.08, 0.2, 0.08), Color(1.0, 0.4, 0.1, 0.12), 0.0, 8)
	cols.append(["c", p, 0.4])


static func _mangrove(o: W3DBuilder, t: Transform3D, p: Vector2, r: RandomNumberGenerator, cols: Array) -> void:
	var bark := Color(0.14, 0.11, 0.08)
	for q in 7:        # radici aeree ad arco
		var a := TAU * q / 7.0 + r.randf() * 0.3
		var top := t * Vector3(cos(a) * 0.25, 1.7, sin(a) * 0.25)
		o.shard(top, t * Vector3(cos(a) * 1.7, 0.0, sin(a) * 1.7), 0.2, 0.05, bark, 0.5, 0.05, 0.0)
	_cy(o, t, Vector3(0, 1.6, 0), 0.36, 0.26, 2.0, 6, bark, 0.14)
	var leaf := Color(0.09, 0.21, 0.1).lerp(Color(0.16, 0.28, 0.1), r.randf() * 0.6)
	o.blob(t * Vector3(0, 4.2, 0), Vector3(2.0, 1.1, 2.0), leaf, 8, 3, 0.1, 0.06)
	for q in 10:
		var a2 := TAU * q / 10.0
		var b := t * Vector3(cos(a2) * 1.6, 3.9, sin(a2) * 1.6)
		o.shard(b, b + Vector3(0, -r.randf_range(0.9, 1.7), 0), 0.1, 0.01, Color(0.4, 0.45, 0.28), 0.4, 0.0, 0.0)
	cols.append(["c", p, 0.5])


static func _willow(o: W3DBuilder, t: Transform3D, p: Vector2, r: RandomNumberGenerator, cols: Array) -> void:
	var col := Color(0.16, 0.13, 0.09)
	_cy(o, t, Vector3(0, 0, 0), 0.55, 0.32, 2.2, 6, col, 0.14)
	_cy(o, t, Vector3(0.25, 2.0, 0.1), 0.34, 0.22, 1.6, 6, col, 0.14)
	var leaf := Color(0.12, 0.2, 0.1).lerp(Color(0.2, 0.26, 0.1), r.randf() * 0.6)
	o.blob(t * Vector3(0.3, 3.5, 0.1), Vector3(2.3, 0.8, 2.3), leaf, 8, 3, 0.1, 0.06)
	for q in 18:         # rami cadenti
		var a := TAU * q / 18.0 + r.randf() * 0.2
		var b := t * Vector3(0.3 + cos(a) * 1.9, 3.3, 0.1 + sin(a) * 1.9)
		o.shard(b, b + Vector3(cos(a) * 0.2, -r.randf_range(1.8, 2.8), sin(a) * 0.2), 0.16, 0.02, leaf.lerp(Color(0.3, 0.32, 0.12), r.randf() * 0.5), 0.5, 0.05, 0.0)
	cols.append(["c", p, 0.55])


static func _reeds(o: W3DBuilder, t: Transform3D, r: RandomNumberGenerator) -> void:
	o.cyl(t * Transform3D(Basis.IDENTITY, Vector3(0, 0.02, 0)), 1.2, 1.1, 0.03, 7, Color(0.06, 0.08, 0.05), 0.1)
	for q in 16:
		var a := r.randf() * TAU
		var d := sqrt(r.randf()) * 1.1
		var b := t * Vector3(cos(a) * d, 0, sin(a) * d)
		o.shard(b, b + Vector3(r.randf_range(-0.25, 0.25), r.randf_range(1.1, 2.3), r.randf_range(-0.25, 0.25)), 0.08, 0.01, Color(0.26, 0.32, 0.12).lerp(Color(0.38, 0.34, 0.16), r.randf() * 0.6), 0.3, 0.0, 0.0)
	for q in 3:        # pannocchie
		var a2 := r.randf() * TAU
		var b2 := t * Vector3(cos(a2) * 0.7, 1.4, sin(a2) * 0.7)
		o.box(Transform3D(Basis.IDENTITY, b2), Vector3(0.1, 0.34, 0.1), Color(0.3, 0.2, 0.1), 0.05, 8)


static func _mud(o: W3DBuilder, t: Transform3D, r: RandomNumberGenerator) -> void:
	var n := 10
	var rad := r.randf_range(1.3, 2.0)
	var pts: Array = []
	for q in n:
		var a := TAU * q / n
		var rr := rad * r.randf_range(0.75, 1.15)
		pts.append(t * Vector3(cos(a) * rr, 0.03, sin(a) * rr * 0.8))
	var ctr := t * Vector3(0, 0.03, 0)
	for q in n:
		o.tri(ctr, pts[q], pts[(q + 1) % n], Color(0.03, 0.07, 0.07))
	o.cyl(t * Transform3D(Basis.IDENTITY, Vector3(r.randf_range(-0.4, 0.4), 0.04, r.randf_range(-0.3, 0.3))), 0.3, 0.3, 0.02, 6, Color(0.14, 0.3, 0.12), 0.05)


static func _marble(o: W3DBuilder, t: Transform3D, p: Vector2, r: RandomNumberGenerator, cols: Array) -> void:
	var m := Color(0.34, 0.32, 0.38)
	for q in r.randi_range(3, 5):
		var s := r.randf_range(0.4, 0.9)
		o.box(t * Transform3D(Basis(Vector3.UP, r.randf() * TAU) * Basis(Vector3.RIGHT, r.randf_range(-0.25, 0.25)), Vector3(r.randf_range(-1.1, 1.1), s * 0.45, r.randf_range(-1.1, 1.1))), Vector3(s * 1.4, s * 0.9, s), m.lerp(Color.WHITE, r.randf() * 0.15), 0.12, 8)
	o.cyl(t * Transform3D(Basis(Vector3(0, 0, 1), PI * 0.5) * Basis(Vector3.UP, r.randf()), Vector3(0, 0.45, 0.9)), 0.45, 0.42, 2.2, 8, m.lerp(Color.WHITE, 0.1), 0.1)
	cols.append(["c", p, 1.1])


static func _basalt(o: W3DBuilder, t: Transform3D, p: Vector2, r: RandomNumberGenerator, cols: Array) -> void:
	for q in r.randi_range(3, 5):
		var a := TAU * q / 4.0 + r.randf() * 0.7
		var d := r.randf_range(0.0, 0.9)
		var h := r.randf_range(1.5, 4.2)
		var c := Vector3(cos(a) * d, 0, sin(a) * d)
		_cy(o, t, c, r.randf_range(0.4, 0.65), r.randf_range(0.28, 0.45), h, 6, Color(0.075, 0.065, 0.075).lerp(Color(0.14, 0.09, 0.09), r.randf() * 0.6), 0.1)
		if r.randf() < 0.6:
			_bx(o, t, c + Vector3(0.3, h * 0.5, 0.0), Vector3(0.06, h * 0.8, 0.06), Color(1.0, 0.4, 0.1, 0.12))
	cols.append(["c", p, 1.1])


static func _ash(o: W3DBuilder, t: Transform3D, r: RandomNumberGenerator) -> void:
	o.blob(t * Vector3(0, 0, 0), Vector3(1.7, 0.7, 1.5), Color(0.1, 0.09, 0.1), 7, 3, 0.1, 0.05)
	for q in 4:
		var a := r.randf() * TAU
		o.blob(t * Vector3(cos(a) * 0.8, 0.3, sin(a) * 0.8), Vector3(0.25, 0.12, 0.25), Color(1.0, 0.4, 0.1, 0.1), 5, 2, 0.05, 0.02)


static func _ice_boulders(o: W3DBuilder, t: Transform3D, p: Vector2, r: RandomNumberGenerator, cols: Array) -> void:
	for q in r.randi_range(3, 5):
		var s := r.randf_range(0.7, 1.4)
		var a := r.randf() * TAU
		var d := r.randf_range(0.0, 1.1)
		o.rock(t * Vector3(cos(a) * d, s * 0.4, sin(a) * d), Vector3(s * 1.2, s * 0.9, s), Color(0.6, 0.76, 0.9).lerp(Color.WHITE, r.randf() * 0.35), 0.14, 0.4, a)
	var b := t * Vector3(0, 0, 0)
	o.shard(b, b + Vector3(0.1, r.randf_range(1.6, 2.6), 0), 0.4, 0.03, Color(0.72, 0.88, 0.98), 0.55, 0.05, 0.0)
	cols.append(["c", p, 1.3])
