class_name W3DChrono
extends RefCounted
## Modelli 3D di tutto cio' che il Cronotone evoca: oggetti utili, armi, mezzi, alleati e oggetti inutili.
## Unita' = 16 px. Gli oggetti stanno a terra, centrati, lunghi lungo +X. Colore con alpha < 1 = emissivo.

static var cache: Dictionary = {}

const ID := Transform3D.IDENTITY


static func _b(b: W3DBuilder, p: Vector3, s: Vector3, c: Color, yaw := 0.0) -> void:
	b.box(Transform3D(Basis(Vector3.UP, yaw), p), s, c, 0.08, 0)


static func _c(b: W3DBuilder, p: Vector3, rb: float, rt: float, h: float, c: Color, segs := 8, rot := Basis.IDENTITY) -> void:
	b.cyl(Transform3D(rot, p), rb, rt, h, segs, c, 0.08)


static func _cx(b: W3DBuilder, p: Vector3, r: float, ln: float, c: Color, segs := 7) -> void:
	# cilindro orizzontale lungo X, centrato in p
	b.cyl(Transform3D(Basis(Vector3(0, 0, 1), -PI * 0.5), p + Vector3(ln * 0.5, 0, 0)), r, r, ln, segs, c, 0.08)


static func _cz(b: W3DBuilder, p: Vector3, r: float, ln: float, c: Color, segs := 7) -> void:
	b.cyl(Transform3D(Basis(Vector3(1, 0, 0), PI * 0.5), p + Vector3(0, 0, -ln * 0.5)), r, r, ln, segs, c, 0.08)


static func _e(r: float, g: float, bl: float) -> Color:
	return Color(r, g, bl, 0.1)


static func has(id: String) -> bool:
	return MODELS.has(id)


static func mesh(id: String) -> ArrayMesh:
	if cache.has(id):
		return cache[id]
	var b := W3DBuilder.new()
	b.rn.seed = hash(id)
	b.sat = 1.35
	b.con = 1.25
	var fn: Callable = Callable(W3DChrono, "m_" + str(MODELS.get(id, "generic")))
	fn.call(b, id)
	var m := b.mesh()
	cache[id] = m
	return m


# id -> nome della funzione modello (m_<nome>)
const MODELS := {
	"fumo": "grenade", "siringa": "syringe", "greco": "jar", "plasma": "knife", "oplita": "shield", "mina": "mine",
	"catapulta": "catapult", "ariete": "ram", "drone": "drone", "golem": "golem", "carro": "chariot", "tank": "tank", "ufo": "ufo",
	"pistola": "gun", "pompa": "shotgun", "mitra": "smg", "motosega": "chainsaw", "laserpistol": "lasergun", "spadalaser": "saber",
	"bazooka": "bazooka", "fucileplasma": "plasmarifle",
	"tostapane": "toaster", "racchetta": "racket", "ombrello": "umbrella", "pentola": "pot", "mazza": "bat", "frullatore": "blender",
	"batteria": "battery", "cuscino": "pillow", "lampadario": "chandelier", "aspirapolvere": "vacuum", "mattarello": "rolling",
	"padella": "pan", "ferrostiro": "iron", "phon": "dryer", "chitarra": "guitar", "asta_selfie": "selfie", "candeliere": "candle",
	"casco_moto": "helmet", "giubbotto": "jacket", "stivali": "boots", "skateboard": "skate", "secchio": "bucket", "caffe": "cup",
	"energy": "can",
}


static func m_generic(b: W3DBuilder, _id: String) -> void:
	_b(b, Vector3(0, 0.25, 0), Vector3(0.6, 0.5, 0.6), Color(0.4, 0.4, 0.45))


# ------------------------------------------------------------------ utili
static func m_grenade(b: W3DBuilder, _id: String) -> void:
	_c(b, Vector3(0, 0, 0), 0.32, 0.3, 0.6, Color(0.3, 0.34, 0.3))
	_c(b, Vector3(0, 0.6, 0), 0.14, 0.1, 0.16, Color(0.55, 0.55, 0.5))
	b.rock(Vector3(0.22, 0.75, 0), Vector3(0.3, 0.05, 0.05), Color(0.7, 0.7, 0.2), 0.05, 0.05, 0.0)


static func m_syringe(b: W3DBuilder, _id: String) -> void:
	_cx(b, Vector3(-0.35, 0.2, 0), 0.14, 0.7, Color(0.7, 0.85, 0.85))
	_cx(b, Vector3(-0.35, 0.2, 0), 0.1, 0.66, _e(0.3, 1.0, 0.7))
	_cx(b, Vector3(-0.65, 0.2, 0), 0.05, 0.3, Color(0.4, 0.4, 0.45))
	_cx(b, Vector3(0.35, 0.2, 0), 0.025, 0.4, Color(0.8, 0.8, 0.85))
	_b(b, Vector3(-0.68, 0.2, 0), Vector3(0.05, 0.05, 0.4), Color(0.4, 0.4, 0.45))


static func m_jar(b: W3DBuilder, _id: String) -> void:
	b.blob(Vector3(0, 0.3, 0), Vector3(0.38, 0.34, 0.38), Color(0.4, 0.22, 0.1), 8, 4, 0.08, 0.04)
	_c(b, Vector3(0, 0.6, 0), 0.17, 0.2, 0.12, Color(0.35, 0.18, 0.08))
	b.shard(Vector3(0, 0.6, 0), Vector3(0, 1.2, 0), 0.22, 0.03, _e(0.3, 1.0, 0.4), 0.4, 0.0, 0.1)


static func m_knife(b: W3DBuilder, _id: String) -> void:
	_b(b, Vector3(-0.35, 0.1, 0), Vector3(0.4, 0.12, 0.14), Color(0.1, 0.1, 0.14))
	_b(b, Vector3(0.2, 0.1, 0), Vector3(0.7, 0.05, 0.1), _e(0.4, 0.9, 1.0))
	b.shard(Vector3(0.52, 0.1, 0), Vector3(0.78, 0.1, 0), 0.05, 0.01, _e(0.6, 1.0, 1.0), 0.3, 0.0, 0.0)


static func m_shield(b: W3DBuilder, _id: String) -> void:
	_c(b, Vector3(0, 0, 0), 0.62, 0.62, 0.1, Color(0.5, 0.36, 0.14), 12)
	_c(b, Vector3(0, 0.1, 0), 0.5, 0.42, 0.06, Color(0.36, 0.26, 0.1), 12)
	b.rock(Vector3(0, 0.22, 0), Vector3(0.28, 0.16, 0.28), Color(0.6, 0.55, 0.3), 0.08, 0.1, 0.0)


static func m_mine(b: W3DBuilder, _id: String) -> void:
	_c(b, Vector3(0, 0, 0), 0.55, 0.5, 0.2, Color(0.2, 0.22, 0.26), 12)
	_c(b, Vector3(0, 0.2, 0), 0.3, 0.28, 0.06, Color(0.14, 0.15, 0.2), 10)
	_c(b, Vector3(0, 0.26, 0), 0.12, 0.1, 0.05, _e(0.4, 0.8, 1.0), 8)


static func m_catapult(b: W3DBuilder, _id: String) -> void:
	_b(b, Vector3(0, 0.12, 0.3), Vector3(1.0, 0.15, 0.12), Color(0.3, 0.2, 0.12))
	_b(b, Vector3(0, 0.12, -0.3), Vector3(1.0, 0.15, 0.12), Color(0.3, 0.2, 0.12))
	_b(b, Vector3(-0.1, 0.45, 0), Vector3(0.12, 0.6, 0.8), Color(0.26, 0.17, 0.1))
	b.cyl(Transform3D(Basis(Vector3(0, 0, 1), 0.7), Vector3(-0.1, 0.5, 0)), 0.06, 0.05, 0.9, 6, Color(0.36, 0.25, 0.15), 0.08)
	b.rock(Vector3(0.55, 0.85, 0), Vector3(0.28, 0.24, 0.28), Color(0.4, 0.4, 0.42), 0.12, 0.3, 0.0)


static func m_ram(b: W3DBuilder, _id: String) -> void:
	_cx(b, Vector3(-0.6, 0.35, 0), 0.2, 1.2, Color(0.32, 0.2, 0.12))
	b.cyl(Transform3D(Basis(Vector3(0, 0, 1), -PI * 0.5), Vector3(0.6, 0.35, 0)), 0.26, 0.12, 0.3, 7, Color(0.4, 0.4, 0.44), 0.08)
	_b(b, Vector3(-0.2, 0.12, 0.3), Vector3(0.12, 0.25, 0.1), Color(0.26, 0.17, 0.1))
	_b(b, Vector3(-0.2, 0.12, -0.3), Vector3(0.12, 0.25, 0.1), Color(0.26, 0.17, 0.1))


# ------------------------------------------------------------------ alleati e mezzi
static func m_drone(b: W3DBuilder, _id: String) -> void:
	_b(b, Vector3(0, 0.7, 0), Vector3(0.5, 0.2, 0.5), Color(0.2, 0.22, 0.28))
	b.blob(Vector3(0, 0.7, 0), Vector3(0.22, 0.18, 0.22), Color(0.14, 0.16, 0.2), 6, 3, 0.05, 0.02)
	b.blob(Vector3(0.25, 0.7, 0), Vector3(0.08, 0.08, 0.08), _e(1.0, 0.3, 0.2), 5, 3, 0.0, 0.0)
	for q in 4:
		var a := PI * 0.25 + q * PI * 0.5
		var p := Vector3(cos(a) * 0.55, 0.7, sin(a) * 0.55)
		_b(b, (p * 0.5) + Vector3(0, 0.7, 0) - Vector3(0, 0.7, 0) * 0.0, Vector3(0.6, 0.06, 0.06), Color(0.18, 0.2, 0.25), -a)
		_c(b, p + Vector3(0, 0.06, 0), 0.3, 0.3, 0.03, Color(0.4, 0.45, 0.55), 10)


static func m_golem(b: W3DBuilder, _id: String) -> void:
	var st := Color(0.34, 0.33, 0.36)
	_b(b, Vector3(0, 0.5, 0), Vector3(0.9, 0.5, 1.2), st)
	_b(b, Vector3(0, 0.95, 0), Vector3(0.7, 0.45, 0.9), Color(0.4, 0.39, 0.42))
	b.rock(Vector3(0.12, 1.35, 0), Vector3(0.5, 0.4, 0.5), Color(0.44, 0.43, 0.46), 0.1, 0.2, 0.0)
	b.box(Transform3D(Basis.IDENTITY, Vector3(0.38, 1.35, 0.14)), Vector3(0.05, 0.08, 0.1), _e(1.0, 0.6, 0.2), 0.0, 0)
	b.box(Transform3D(Basis.IDENTITY, Vector3(0.38, 1.35, -0.14)), Vector3(0.05, 0.08, 0.1), _e(1.0, 0.6, 0.2), 0.0, 0)
	for sz in [-1, 1]:
		_b(b, Vector3(0.1, 0.8, sz * 0.8), Vector3(0.5, 0.5, 0.4), st)
		b.rock(Vector3(0.35, 0.3, sz * 0.8), Vector3(0.55, 0.5, 0.5), Color(0.36, 0.35, 0.38), 0.1, 0.25, 0.0)
		_b(b, Vector3(-0.1, 0.2, sz * 0.35), Vector3(0.45, 0.4, 0.45), st)


static func m_chariot(b: W3DBuilder, _id: String) -> void:
	_b(b, Vector3(-0.1, 0.55, 0), Vector3(1.6, 0.18, 1.1), Color(0.34, 0.21, 0.12))
	_b(b, Vector3(-0.8, 0.8, 0), Vector3(0.1, 0.45, 1.1), Color(0.3, 0.19, 0.11))
	for sz in [-1, 1]:
		_b(b, Vector3(-0.1, 0.8, sz * 0.5), Vector3(1.4, 0.35, 0.08), Color(0.3, 0.19, 0.11))
		_c(b, Vector3(-0.1, 0.5, sz * 0.7), 0.5, 0.5, 0.1, Color(0.2, 0.14, 0.1), 10, Basis(Vector3(1, 0, 0), PI * 0.5))
	_b(b, Vector3(0.9, 0.5, 0), Vector3(0.9, 0.08, 0.1), Color(0.3, 0.19, 0.11))
	_b(b, Vector3(0.4, 0.95, 0), Vector3(0.8, 0.1, 0.14), Color(0.36, 0.36, 0.4))
	b.shard(Vector3(0.8, 0.95, 0), Vector3(1.25, 0.95, 0), 0.1, 0.01, Color(0.55, 0.55, 0.6), 0.3, 0.0, 0.0)


static func m_tank(b: W3DBuilder, _id: String) -> void:
	var hull := Color(0.18, 0.25, 0.14)
	_b(b, Vector3(0, 0.55, 0), Vector3(2.0, 0.5, 1.2), hull)
	for sz in [-1, 1]:
		_b(b, Vector3(0, 0.35, sz * 0.8), Vector3(2.3, 0.6, 0.38), Color(0.06, 0.06, 0.06))
		_b(b, Vector3(0, 0.66, sz * 0.8), Vector3(2.1, 0.08, 0.3), Color(0.1, 0.1, 0.1))
	_c(b, Vector3(-0.1, 0.8, 0), 0.55, 0.45, 0.35, Color(0.3, 0.4, 0.22), 10)
	_cx(b, Vector3(0.3, 1.0, 0), 0.09, 1.3, Color(0.2, 0.22, 0.2))
	_c(b, Vector3(-0.1, 1.15, 0.2), 0.13, 0.13, 0.12, Color(0.18, 0.2, 0.18), 6)


static func m_ufo(b: W3DBuilder, _id: String) -> void:
	b.cyl(Transform3D(Basis.IDENTITY, Vector3(0, 0.5, 0)), 1.3, 0.6, 0.3, 14, Color(0.4, 0.44, 0.5), 0.06)
	b.cyl(Transform3D(Basis.IDENTITY, Vector3(0, 0.8, 0)), 0.6, 0.3, 0.2, 14, Color(0.34, 0.38, 0.44), 0.06)
	b.blob(Vector3(0, 1.0, 0), Vector3(0.5, 0.4, 0.5), _e(0.4, 0.9, 1.0), 10, 4, 0.0, 0.0)
	for i in 8:
		var a := TAU * i / 8.0
		b.blob(Vector3(cos(a) * 1.1, 0.55, sin(a) * 1.1), Vector3(0.1, 0.07, 0.1), _e(1.0, 0.9, 0.4), 4, 3, 0.0, 0.0)


# ------------------------------------------------------------------ armi dal futuro (lunghe lungo +X)
static func _grip(b: W3DBuilder, x: float, col := Color(0.12, 0.12, 0.14)) -> void:
	b.box(Transform3D(Basis(Vector3(0, 0, 1), -0.25), Vector3(x, 0.05, 0)), Vector3(0.14, 0.34, 0.16), col, 0.06, 0)


static func m_gun(b: W3DBuilder, _id: String) -> void:
	_b(b, Vector3(0.05, 0.3, 0), Vector3(0.7, 0.2, 0.16), Color(0.22, 0.23, 0.27))
	_cx(b, Vector3(0.35, 0.31, 0), 0.06, 0.4, Color(0.4, 0.4, 0.45))
	_grip(b, -0.15)


static func m_shotgun(b: W3DBuilder, _id: String) -> void:
	_cx(b, Vector3(-0.1, 0.33, 0), 0.07, 1.1, Color(0.3, 0.3, 0.34))
	_cx(b, Vector3(-0.1, 0.22, 0), 0.06, 0.8, Color(0.28, 0.28, 0.32))
	_b(b, Vector3(-0.6, 0.28, 0), Vector3(0.5, 0.2, 0.15), Color(0.34, 0.2, 0.1))
	_b(b, Vector3(0.1, 0.2, 0), Vector3(0.35, 0.14, 0.16), Color(0.34, 0.2, 0.1))


static func m_smg(b: W3DBuilder, _id: String) -> void:
	_b(b, Vector3(0, 0.3, 0), Vector3(0.9, 0.22, 0.16), Color(0.2, 0.21, 0.25))
	_cx(b, Vector3(0.45, 0.32, 0), 0.05, 0.4, Color(0.4, 0.4, 0.45))
	_b(b, Vector3(0.05, 0.05, 0), Vector3(0.12, 0.45, 0.14), Color(0.16, 0.16, 0.2))
	_grip(b, -0.3)


static func m_chainsaw(b: W3DBuilder, _id: String) -> void:
	_b(b, Vector3(-0.35, 0.3, 0), Vector3(0.55, 0.38, 0.32), Color(0.7, 0.3, 0.1))
	_b(b, Vector3(0.45, 0.3, 0), Vector3(0.9, 0.08, 0.14), Color(0.55, 0.57, 0.62))
	for i in 7:
		_b(b, Vector3(0.1 + i * 0.12, 0.38, 0.08), Vector3(0.05, 0.05, 0.05), Color(0.8, 0.8, 0.85))
	_b(b, Vector3(-0.35, 0.58, 0), Vector3(0.4, 0.07, 0.07), Color(0.12, 0.12, 0.14))


static func m_lasergun(b: W3DBuilder, _id: String) -> void:
	_b(b, Vector3(0, 0.3, 0), Vector3(0.7, 0.2, 0.16), Color(0.4, 0.45, 0.55))
	_cx(b, Vector3(0.35, 0.31, 0), 0.07, 0.35, Color(0.3, 0.34, 0.42))
	_b(b, Vector3(0.0, 0.42, 0), Vector3(0.5, 0.05, 0.05), _e(1.0, 0.2, 0.3))
	_grip(b, -0.15, Color(0.2, 0.22, 0.28))


static func m_saber(b: W3DBuilder, _id: String) -> void:
	_cx(b, Vector3(-0.5, 0.2, 0), 0.07, 0.5, Color(0.2, 0.2, 0.24))
	_cx(b, Vector3(-0.05, 0.2, 0), 0.05, 1.1, _e(0.5, 1.0, 1.0))
	_cx(b, Vector3(-0.05, 0.2, 0), 0.09, 1.1, _e(0.2, 0.7, 1.0), 5)


static func m_bazooka(b: W3DBuilder, _id: String) -> void:
	_cx(b, Vector3(-0.8, 0.45, 0), 0.22, 1.6, Color(0.28, 0.34, 0.24), 9)
	_cx(b, Vector3(0.7, 0.45, 0), 0.26, 0.15, Color(0.18, 0.2, 0.18), 9)
	b.cyl(Transform3D(Basis(Vector3(0, 0, 1), -PI * 0.5), Vector3(0.82, 0.45, 0)), 0.2, 0.05, 0.4, 7, Color(0.7, 0.2, 0.1), 0.08)
	_b(b, Vector3(-0.3, 0.2, 0), Vector3(0.12, 0.3, 0.1), Color(0.14, 0.14, 0.16))


static func m_plasmarifle(b: W3DBuilder, _id: String) -> void:
	_b(b, Vector3(-0.2, 0.32, 0), Vector3(1.0, 0.26, 0.2), Color(0.3, 0.2, 0.45))
	_cx(b, Vector3(0.3, 0.33, 0), 0.1, 0.5, Color(0.26, 0.2, 0.38))
	b.blob(Vector3(0.8, 0.33, 0), Vector3(0.12, 0.12, 0.12), _e(0.8, 0.4, 1.0), 6, 3, 0.0, 0.0)
	_b(b, Vector3(-0.25, 0.5, 0), Vector3(0.5, 0.08, 0.08), _e(0.7, 0.3, 1.0))
	_grip(b, -0.4, Color(0.2, 0.15, 0.3))


# ------------------------------------------------------------------ oggetti inutili
static func m_toaster(b: W3DBuilder, _id: String) -> void:
	_b(b, Vector3(0, 0.25, 0), Vector3(0.9, 0.5, 0.55), Color(0.62, 0.62, 0.66))
	_b(b, Vector3(0.1, 0.52, 0.12), Vector3(0.5, 0.03, 0.1), Color(0.05, 0.05, 0.06))
	_b(b, Vector3(0.1, 0.52, -0.12), Vector3(0.5, 0.03, 0.1), Color(0.05, 0.05, 0.06))
	_b(b, Vector3(0.48, 0.3, 0), Vector3(0.06, 0.08, 0.08), Color(0.1, 0.1, 0.12))


static func m_racket(b: W3DBuilder, _id: String) -> void:
	for i in 14:
		var a := TAU * i / 14.0
		_b(b, Vector3(0.35 + cos(a) * 0.36, 0.08, sin(a) * 0.3), Vector3(0.14, 0.06, 0.1), Color(0.7, 0.3, 0.1), a + PI * 0.5)
	_b(b, Vector3(0.35, 0.05, 0), Vector3(0.5, 0.02, 0.02), Color(0.8, 0.8, 0.8))
	_b(b, Vector3(-0.35, 0.08, 0), Vector3(0.7, 0.07, 0.09), Color(0.1, 0.1, 0.12))


static func m_umbrella(b: W3DBuilder, _id: String) -> void:
	b.cyl(Transform3D(Basis.IDENTITY, Vector3(0, 0.25, 0)), 0.7, 0.05, 0.3, 8, Color(0.12, 0.18, 0.36), 0.1)
	_c(b, Vector3(0, 0.0, 0), 0.03, 0.03, 0.6, Color(0.2, 0.15, 0.1), 5)
	_b(b, Vector3(0.12, 0.0, 0), Vector3(0.25, 0.04, 0.04), Color(0.2, 0.15, 0.1))


static func m_pot(b: W3DBuilder, _id: String) -> void:
	_c(b, Vector3(0, 0, 0), 0.4, 0.45, 0.5, Color(0.3, 0.3, 0.33), 10)
	_c(b, Vector3(0, 0.5, 0), 0.4, 0.4, 0.02, Color(0.05, 0.05, 0.06), 10)
	for sz in [-1, 1]:
		_b(b, Vector3(0, 0.35, sz * 0.5), Vector3(0.18, 0.06, 0.1), Color(0.2, 0.2, 0.22))


static func m_bat(b: W3DBuilder, _id: String) -> void:
	b.cyl(Transform3D(Basis(Vector3(0, 0, 1), -PI * 0.5), Vector3(-0.7, 0.14, 0)), 0.04, 0.14, 1.4, 7, Color(0.5, 0.36, 0.2), 0.08)
	_cx(b, Vector3(-0.7, 0.14, 0), 0.05, 0.25, Color(0.1, 0.1, 0.12))


static func m_blender(b: W3DBuilder, _id: String) -> void:
	_b(b, Vector3(0, 0.12, 0), Vector3(0.6, 0.24, 0.6), Color(0.14, 0.14, 0.16))
	_c(b, Vector3(0, 0.24, 0), 0.25, 0.32, 0.7, Color(0.7, 0.85, 0.9), 8)
	_c(b, Vector3(0, 0.94, 0), 0.3, 0.3, 0.06, Color(0.1, 0.1, 0.12), 8)


static func m_battery(b: W3DBuilder, _id: String) -> void:
	_cx(b, Vector3(-0.3, 0.2, 0), 0.2, 0.6, Color(0.1, 0.1, 0.12), 8)
	_cx(b, Vector3(-0.3, 0.2, 0), 0.21, 0.35, _e(0.2, 1.0, 0.4), 8)
	_cx(b, Vector3(0.3, 0.2, 0), 0.07, 0.1, Color(0.7, 0.7, 0.72), 6)


static func m_pillow(b: W3DBuilder, _id: String) -> void:
	b.blob(Vector3(0, 0.15, 0), Vector3(0.7, 0.18, 0.55), Color(0.55, 0.5, 0.42), 8, 4, 0.06, 0.03)


static func m_chandelier(b: W3DBuilder, _id: String) -> void:
	for i in 8:
		var a := TAU * i / 8.0
		_b(b, Vector3(cos(a) * 0.5, 0.08, sin(a) * 0.5), Vector3(0.22, 0.08, 0.08), Color(0.5, 0.4, 0.15), -a)
		_c(b, Vector3(cos(a) * 0.55, 0.12, sin(a) * 0.55), 0.04, 0.04, 0.2, Color(0.8, 0.78, 0.7), 5)
		b.blob(Vector3(cos(a) * 0.55, 0.38, sin(a) * 0.55), Vector3(0.05, 0.08, 0.05), _e(1.0, 0.8, 0.4), 4, 3, 0.0, 0.0)
	_c(b, Vector3(0, 0.0, 0), 0.12, 0.12, 0.18, Color(0.5, 0.4, 0.15), 6)


static func m_vacuum(b: W3DBuilder, _id: String) -> void:
	_c(b, Vector3(-0.1, 0, 0), 0.4, 0.4, 0.4, Color(0.7, 0.2, 0.15), 10)
	_cx(b, Vector3(0.2, 0.2, 0), 0.07, 0.8, Color(0.15, 0.15, 0.17))
	_b(b, Vector3(1.0, 0.1, 0), Vector3(0.3, 0.08, 0.5), Color(0.1, 0.1, 0.12))


static func m_rolling(b: W3DBuilder, _id: String) -> void:
	_cx(b, Vector3(-0.4, 0.15, 0), 0.15, 0.8, Color(0.55, 0.38, 0.2), 8)
	_cx(b, Vector3(-0.7, 0.15, 0), 0.05, 1.4, Color(0.45, 0.3, 0.16), 6)


static func m_pan(b: W3DBuilder, _id: String) -> void:
	_c(b, Vector3(0.3, 0, 0), 0.45, 0.5, 0.1, Color(0.15, 0.15, 0.17), 12)
	_c(b, Vector3(0.3, 0.08, 0), 0.38, 0.38, 0.03, Color(0.07, 0.07, 0.08), 12)
	_b(b, Vector3(-0.5, 0.06, 0), Vector3(0.7, 0.06, 0.1), Color(0.1, 0.1, 0.12))


static func m_iron(b: W3DBuilder, _id: String) -> void:
	b.rock(Vector3(0.05, 0.15, 0), Vector3(0.9, 0.3, 0.5), Color(0.5, 0.5, 0.55), 0.1, 0.15, 0.0)
	b.rock(Vector3(-0.2, 0.32, 0), Vector3(0.4, 0.14, 0.14), Color(0.1, 0.1, 0.12), 0.05, 0.1, 0.0)


static func m_dryer(b: W3DBuilder, _id: String) -> void:
	_cx(b, Vector3(-0.1, 0.25, 0), 0.22, 0.7, Color(0.6, 0.3, 0.5), 9)
	_cx(b, Vector3(0.55, 0.25, 0), 0.15, 0.2, Color(0.2, 0.2, 0.24), 8)
	_grip(b, -0.2, Color(0.5, 0.25, 0.42))


static func m_guitar(b: W3DBuilder, _id: String) -> void:
	b.blob(Vector3(-0.3, 0.1, 0), Vector3(0.4, 0.1, 0.32), Color(0.6, 0.12, 0.1), 8, 3, 0.05, 0.03)
	b.blob(Vector3(0.0, 0.1, 0), Vector3(0.22, 0.1, 0.22), Color(0.6, 0.12, 0.1), 7, 3, 0.05, 0.03)
	_b(b, Vector3(0.65, 0.12, 0), Vector3(0.9, 0.05, 0.1), Color(0.3, 0.2, 0.1))
	_b(b, Vector3(1.15, 0.14, 0), Vector3(0.18, 0.05, 0.16), Color(0.15, 0.1, 0.06))


static func m_selfie(b: W3DBuilder, _id: String) -> void:
	_cx(b, Vector3(-0.7, 0.1, 0), 0.03, 1.4, Color(0.15, 0.15, 0.17), 5)
	_b(b, Vector3(0.8, 0.12, 0), Vector3(0.18, 0.05, 0.3), Color(0.05, 0.05, 0.07))
	_b(b, Vector3(0.8, 0.15, 0), Vector3(0.14, 0.01, 0.24), _e(0.5, 0.7, 1.0))


static func m_candle(b: W3DBuilder, _id: String) -> void:
	_c(b, Vector3(0, 0, 0), 0.25, 0.1, 0.1, Color(0.5, 0.4, 0.15), 8)
	_c(b, Vector3(0, 0.1, 0), 0.05, 0.05, 0.5, Color(0.5, 0.4, 0.15), 6)
	for q in 3:
		var a := TAU * q / 3.0
		var p := Vector3(cos(a) * 0.3, 0.4, sin(a) * 0.3)
		_c(b, p, 0.05, 0.05, 0.35, Color(0.8, 0.78, 0.7), 5)
		b.blob(p + Vector3(0, 0.45, 0), Vector3(0.05, 0.09, 0.05), _e(1.0, 0.8, 0.4), 4, 3, 0.0, 0.0)


static func m_helmet(b: W3DBuilder, _id: String) -> void:
	b.blob(Vector3(0, 0.3, 0), Vector3(0.5, 0.4, 0.45), Color(0.12, 0.12, 0.15), 9, 5, 0.05, 0.02)
	_b(b, Vector3(0.3, 0.36, 0), Vector3(0.12, 0.18, 0.5), Color(0.35, 0.5, 0.65))


static func m_jacket(b: W3DBuilder, _id: String) -> void:
	_b(b, Vector3(0, 0.1, 0), Vector3(0.7, 0.18, 0.9), Color(0.1, 0.1, 0.12))
	for sz in [-1, 1]:
		_b(b, Vector3(0.1, 0.1, sz * 0.7), Vector3(0.9, 0.16, 0.22), Color(0.12, 0.12, 0.14))
	_b(b, Vector3(0.0, 0.2, 0), Vector3(0.08, 0.02, 0.9), Color(0.6, 0.6, 0.65))


static func m_boots(b: W3DBuilder, _id: String) -> void:
	for sz in [-1, 1]:
		_b(b, Vector3(-0.05, 0.18, sz * 0.3), Vector3(0.3, 0.4, 0.28), Color(0.7, 0.55, 0.1))
		_b(b, Vector3(0.28, 0.1, sz * 0.3), Vector3(0.45, 0.2, 0.3), Color(0.7, 0.55, 0.1))


static func m_skate(b: W3DBuilder, _id: String) -> void:
	b.box(Transform3D(Basis.IDENTITY, Vector3(0, 0.12, 0)), Vector3(1.5, 0.06, 0.45), Color(0.3, 0.2, 0.5), 0.06, 0)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			_c(b, Vector3(sx * 0.5, 0.0, sz * 0.2), 0.08, 0.08, 0.1, Color(0.8, 0.8, 0.8), 6, Basis(Vector3(1, 0, 0), PI * 0.5))


static func m_bucket(b: W3DBuilder, _id: String) -> void:
	_c(b, Vector3(0, 0, 0), 0.32, 0.4, 0.5, Color(0.5, 0.52, 0.56), 9)
	_c(b, Vector3(0, 0.46, 0), 0.34, 0.34, 0.03, Color(0.04, 0.04, 0.05), 9)
	_b(b, Vector3(0, 0.62, 0), Vector3(0.05, 0.05, 0.8), Color(0.3, 0.3, 0.33))


static func m_cup(b: W3DBuilder, _id: String) -> void:
	_c(b, Vector3(0, 0, 0), 0.22, 0.25, 0.35, Color(0.8, 0.8, 0.82), 9)
	_c(b, Vector3(0, 0.32, 0), 0.2, 0.2, 0.03, Color(0.25, 0.14, 0.07), 9)
	_b(b, Vector3(0.3, 0.18, 0), Vector3(0.14, 0.06, 0.18), Color(0.8, 0.8, 0.82))


static func m_can(b: W3DBuilder, _id: String) -> void:
	_c(b, Vector3(0, 0, 0), 0.2, 0.2, 0.55, Color(0.15, 0.4, 0.6), 9)
	_c(b, Vector3(0, 0.2, 0), 0.21, 0.21, 0.12, _e(0.6, 1.0, 0.2), 9)
	_c(b, Vector3(0, 0.55, 0), 0.19, 0.17, 0.04, Color(0.7, 0.7, 0.72), 9)
