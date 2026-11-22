class_name W3DChars
extends RefCounted
## Personaggi e mostri del motore 3D, secondo stile: COMPATTI e SFACCETTATI.
## Ogni creatura e' un gruppo di "gemme" (solidi a 5-6 lati, teste grosse, corpo tozzo) + qualche scheggia affilata
## (armi, corna, artigli) + una parte fluente (mantello, ali, coda) che ondeggia. Colori e tratti dagli sprite originali.
## Davanti = -Z (su, sullo schermo). Unita' = 16 px. alfa < 1 = emissivo (occhi).

const KINDS := ["hero", "hunter", "necro", "cleric", "skeleton", "skel_archer", "ghoul", "zombie", "spider", "gargoyle", "ooze", "bat",
	"cultist", "wraith", "rat", "imp", "wisp", "toad", "wolf", "goblin", "goblin_archer", "goblin_shaman", "kobold", "orc", "troll", "ogre",
	"harpy", "lizardman", "knight_fallen", "reaper", "summoner", "abomination", "frost_mage", "berserker", "plague_doc", "vampire"]


static func has(kind: String) -> bool:
	return KINDS.has(kind)


static func C(h: String) -> Color:
	return Color.html(h)


static func K(c: Color, k: float) -> Color:
	return Color(c.r * k, c.g * k, c.b * k, 1.0)


static func gem(b: W3DBuilder, x: float, y: float, z: float, rx: float, ry: float, rz: float, col: Color, seg := 6, j := 0.13) -> void:
	b.blob(Vector3(x, y, z), Vector3(rx, ry, rz), col, seg, 3, j, 0.035)


static func wedge(b: W3DBuilder, a: Vector3, c: Vector3, w1: float, w2: float, col: Color, t := 0.4) -> void:
	b.shard(a, c, w1, w2, col, t, 0.12, 0.05)


static func glow(b: W3DBuilder, x: float, y: float, z: float, s: float, col: Color) -> void:
	b.shard(Vector3(x, y, z + 0.05), Vector3(x, y + 0.02, z - 0.12), s, s * 0.55, Color(col.r, col.g, col.b, 0.2), 0.5, 0.0, 0.0)


static func eyes(b: W3DBuilder, y: float, z: float, dx: float, s: float, col: Color) -> void:
	glow(b, -dx, y, z, s, col)
	glow(b, dx, y, z, s * 0.9, col)


static func pair(b: W3DBuilder, x: float, y: float, z: float, rx: float, ry: float, rz: float, col: Color, seg := 5) -> void:
	gem(b, -x, y, z, rx, ry, rz, col, seg)
	gem(b, x, y, z, rx, ry, rz, col, seg)


static func feet(b: W3DBuilder, dx: float, z: float, s: float, col: Color) -> void:
	pair(b, dx, 0.1, z, s, s * 0.6, s * 1.25, col, 5)


## lama dritta con elsa: lungo -Z a partire da z0 fino a z1, a quota y e lateralmente a x
static func sword(b: W3DBuilder, x: float, y: float, z0: float, z1: float, blade: Color, hilt: Color) -> void:
	wedge(b, Vector3(x, y, z0), Vector3(x + 0.1, y, z1), 0.1, 0.035, blade, 0.15)
	wedge(b, Vector3(x - 0.34, y, z0 - 0.05), Vector3(x + 0.34, y, z0 - 0.05), 0.07, 0.04, hilt, 0.5)
	wedge(b, Vector3(x, y, z0 - 0.05), Vector3(x, y, z0 + 0.5), 0.07, 0.07, K(hilt, 0.7), 0.5)


static func bow(b: W3DBuilder, x: float, col: Color) -> void:
	for i in 4:
		var z0 := -1.15 + i * 0.58
		var z1 := z0 + 0.58
		var o0 := (1.0 - pow(z0 / 1.15, 2.0)) * 0.4
		var o1 := (1.0 - pow(z1 / 1.15, 2.0)) * 0.4
		wedge(b, Vector3(x - o0, 0.85, z0), Vector3(x - o1, 0.85, z1), 0.06, 0.06, col, 0.5)
	wedge(b, Vector3(x + 0.02, 0.85, -1.15), Vector3(x + 0.02, 0.85, 1.15), 0.012, 0.012, Color(0.85, 0.82, 0.72, 0.6), 0.5)


static func staff(b: W3DBuilder, x: float, z0: float, z1: float, col: Color) -> void:
	wedge(b, Vector3(x, 0.9, z0), Vector3(x + 0.02, 0.95, z1), 0.07, 0.06, col, 0.5)


# ------------------------------------------------------------------ eroi
static func m_hero(b: W3DBuilder, f: W3DBuilder) -> void:
	var robe := C("#2c2438")
	var hood := C("#6e666e")
	var steel := C("#a0a0a8")
	gem(b, 0, 0.6, 0.05, 0.64, 0.6, 0.58, robe, 6)
	gem(b, 0, 0.5, -0.1, 0.7, 0.07, 0.6, C("#80602c"), 6)
	gem(b, 0, 1.25, -0.02, 0.52, 0.58, 0.5, hood, 5)
	wedge(b, Vector3(0, 1.35, 0.15), Vector3(0.05, 2.2, 0.32), 0.32, 0.3, K(hood, 0.9))
	gem(b, 0, 1.2, -0.36, 0.27, 0.22, 0.14, C("#07050a"), 5)
	eyes(b, 1.24, -0.48, 0.1, 0.07, C("#ffc070"))
	pair(b, 0.64, 0.95, 0.0, 0.3, 0.2, 0.32, K(steel, 0.75))
	sword(b, 0.9, 0.98, 0.35, -1.2, steel, C("#c0a040"))
	wedge(f, Vector3(0, 0.95, 0.3), Vector3(0, 0.3, 1.75), 0.85, 0.05, C("#7a2e38"), 0.3)
	wedge(f, Vector3(-0.35, 0.95, 0.25), Vector3(-1.0, 0.3, 1.4), 0.3, 0.04, C("#5e2430"), 0.35)
	wedge(f, Vector3(0.35, 0.95, 0.25), Vector3(1.0, 0.3, 1.4), 0.3, 0.04, C("#5e2430"), 0.35)


static func m_hunter(b: W3DBuilder, f: W3DBuilder) -> void:
	var cloak := C("#3c3c40")
	var leather := C("#5a4a3c")
	gem(b, 0, 0.6, 0.08, 0.66, 0.6, 0.6, cloak, 6)
	gem(b, 0, 1.22, -0.02, 0.5, 0.52, 0.48, C("#585860"), 5)
	gem(b, 0, 1.15, -0.34, 0.26, 0.2, 0.13, C("#08070a"), 5)
	eyes(b, 1.2, -0.46, 0.1, 0.06, C("#ffd070"))
	pair(b, 0.62, 0.92, 0.0, 0.28, 0.2, 0.3, leather)
	bow(b, -0.95, C("#7a5a38"))
	gem(b, 0.55, 0.85, 0.5, 0.2, 0.34, 0.16, C("#4a3a2a"), 5)
	wedge(b, Vector3(0.6, 1.0, 0.5), Vector3(0.66, 1.5, 0.58), 0.06, 0.04, C("#d0c8a8"), 0.5)
	wedge(f, Vector3(0, 1.1, 0.25), Vector3(0, 0.3, 1.8), 0.95, 0.05, C("#2e2e34"), 0.3)
	wedge(f, Vector3(0.3, 1.1, 0.2), Vector3(1.05, 0.3, 1.35), 0.28, 0.04, C("#28282e"), 0.35)


static func m_necro(b: W3DBuilder, f: W3DBuilder) -> void:
	var robe := C("#2a1c34")
	gem(b, 0, 0.6, 0.05, 0.62, 0.6, 0.56, robe, 6)
	gem(b, 0, 1.25, -0.02, 0.5, 0.56, 0.48, C("#4c4850"), 5)
	wedge(b, Vector3(0, 1.35, 0.15), Vector3(0.05, 2.0, 0.3), 0.3, 0.28, C("#403c46"))
	gem(b, 0, 1.2, -0.35, 0.27, 0.22, 0.14, C("#050308"), 5)
	eyes(b, 1.24, -0.47, 0.1, 0.075, C("#60f0a0"))
	pair(b, 0.6, 0.92, 0.0, 0.28, 0.2, 0.3, C("#3a2a4a"))
	staff(b, 0.92, 0.9, -1.55, C("#4a3626"))
	gem(b, 0.94, 1.0, -1.65, 0.3, 0.26, 0.28, C("#d0c8b4"), 5)
	glow(b, 0.84, 1.15, -1.9, 0.07, C("#60f0a0"))
	glow(b, 1.04, 1.15, -1.9, 0.07, C("#60f0a0"))
	wedge(b, Vector3(0.94, 1.0, -1.8), Vector3(0.94, 1.5, -2.25), 0.12, 0.12, Color(0.4, 0.95, 0.6, 0.15), 0.4)
	wedge(f, Vector3(0, 0.95, 0.25), Vector3(0, 0.3, 1.85), 0.85, 0.05, C("#34224a"), 0.3)
	wedge(f, Vector3(-0.3, 0.95, 0.2), Vector3(-1.0, 0.3, 1.4), 0.28, 0.04, C("#28183a"), 0.35)


static func m_cleric(b: W3DBuilder, f: W3DBuilder) -> void:
	gem(b, 0, 0.6, 0.05, 0.66, 0.6, 0.6, C("#7a2c34"), 6)
	gem(b, 0, 1.0, -0.12, 0.78, 0.3, 0.55, C("#c8c8d4"), 6)
	gem(b, 0, 1.28, -0.02, 0.46, 0.5, 0.44, C("#d8d0c4"), 5)
	wedge(b, Vector3(0, 1.4, 0.0), Vector3(0, 1.62, -0.55), 0.22, 0.2, C("#e8e8f0"), 0.5)
	eyes(b, 1.28, -0.4, 0.1, 0.05, C("#403038"))
	wedge(b, Vector3(0, 1.02, -0.5), Vector3(0, 1.02, -0.62), 0.08, 0.14, C("#d8b040"), 0.5)
	pair(b, 0.66, 0.9, 0.0, 0.26, 0.2, 0.28, C("#9090a8"))
	wedge(b, Vector3(0.92, 0.92, 0.55), Vector3(0.94, 0.95, -1.1), 0.09, 0.08, C("#4a3626"), 0.5)
	gem(b, 0.94, 1.0, -1.28, 0.34, 0.26, 0.3, C("#8a8a98"), 5)
	wedge(f, Vector3(0, 0.9, 0.3), Vector3(0, 0.3, 1.5), 0.7, 0.05, C("#e0e0ea"), 0.3)


# ------------------------------------------------------------------ non morti
static func m_skeleton(b: W3DBuilder, f: W3DBuilder, archer: bool) -> void:
	var bone := C("#b4b09a")
	gem(b, 0, 0.6, 0.05, 0.55, 0.55, 0.48, K(bone, 0.78), 6)
	for i in 3:
		gem(b, 0, 0.5 + i * 0.12, 0.0, 0.5, 0.05, 0.42, bone, 6)
	gem(b, 0, 1.22, -0.03, 0.55, 0.52, 0.52, K(bone, 1.1), 6)
	pair(b, 0.22, 1.28, -0.45, 0.17, 0.17, 0.08, C("#0a0608"), 5)
	glow(b, -0.22, 1.3, -0.52, 0.06, C("#ff8070"))
	for i in 4:
		gem(b, -0.18 + i * 0.12, 0.98, -0.5, 0.045, 0.07, 0.05, C("#e8e4d0"), 4)
	pair(b, 0.6, 0.85, 0.0, 0.14, 0.14, 0.3, bone, 5)
	if archer:
		bow(b, -0.95, C("#7a6a52"))
		gem(b, 0.55, 0.85, 0.55, 0.2, 0.34, 0.16, C("#7a2c2c"), 5)
	else:
		gem(b, -0.95, 0.85, -0.1, 0.5, 0.1, 0.5, C("#b0a070"), 7)
		gem(b, -0.95, 0.98, -0.1, 0.14, 0.08, 0.14, C("#8a7a50"), 5)
		sword(b, 0.9, 0.95, 0.3, -1.25, C("#a8a8ae"), C("#6a5a3a"))
	wedge(f, Vector3(0, 0.95, 0.3), Vector3(0, 0.25, 1.4), 0.55, 0.04, C("#33303a"), 0.3)


static func m_ghoul(b: W3DBuilder, f: W3DBuilder) -> void:
	var skin := C("#8c8c90")
	gem(b, 0, 0.7, 0.28, 0.72, 0.62, 0.62, K(skin, 0.8), 6)
	gem(b, 0, 1.0, -0.48, 0.58, 0.5, 0.5, skin, 6)
	pair(b, 0.2, 1.08, -0.86, 0.13, 0.13, 0.07, C("#10101c"), 5)
	eyes(b, 1.12, -0.9, 0.2, 0.075, C("#ffe070"))
	gem(b, 0, 0.84, -0.9, 0.32, 0.1, 0.1, C("#080808"), 5)
	for i in 5:
		wedge(b, Vector3(-0.2 + i * 0.1, 0.9, -0.9), Vector3(-0.2 + i * 0.1, 0.8, -1.02), 0.035, 0.03, C("#e8e4d6"), 0.5)
	for s in [-1.0, 1.0]:
		wedge(b, Vector3(s * 0.55, 0.85, -0.1), Vector3(s * 0.85, 0.5, -1.35), 0.15, 0.1, K(skin, 0.9), 0.4)
		for k in 3:
			wedge(b, Vector3(s * (0.8 + k * 0.08), 0.5, -1.3), Vector3(s * (0.95 + k * 0.12), 0.4, -1.8), 0.04, 0.03, C("#d8d4c4"), 0.4)
	pair(b, 0.28, 0.1, -0.1, 0.17, 0.1, 0.3, K(skin, 0.7), 5)


static func m_zombie(b: W3DBuilder, f: W3DBuilder) -> void:
	var skin := C("#7c8a6c")
	gem(b, 0, 0.62, 0.1, 0.62, 0.62, 0.55, C("#4a4e56"), 6)
	gem(b, 0.0, 1.22, -0.1, 0.5, 0.5, 0.48, skin, 5)
	pair(b, 0.17, 1.26, -0.5, 0.1, 0.1, 0.06, C("#101010"), 4)
	glow(b, -0.17, 1.28, -0.54, 0.05, C("#e0f080"))
	gem(b, 0, 1.0, -0.5, 0.2, 0.07, 0.07, C("#301818"), 4)
	for s in [-1.0, 1.0]:
		wedge(b, Vector3(s * 0.55, 1.0, 0.05), Vector3(s * 0.7, 1.05, -1.3), 0.17, 0.12, skin, 0.4)
		gem(b, s * 0.72, 1.05, -1.4, 0.15, 0.12, 0.17, K(skin, 0.9), 5)
	pair(b, 0.25, 0.1, 0.0, 0.17, 0.1, 0.28, C("#2e3036"), 5)
	wedge(f, Vector3(0, 0.8, 0.4), Vector3(0, 0.25, 1.2), 0.45, 0.04, C("#3a3c42"), 0.3)


static func m_wraith(b: W3DBuilder, f: W3DBuilder) -> void:
	var cl := C("#4a5a78")
	gem(b, 0, 0.75, 0.05, 0.62, 0.7, 0.55, cl, 6)
	gem(b, 0, 1.3, -0.04, 0.5, 0.56, 0.46, C("#2a3048"), 5)
	gem(b, 0, 1.25, -0.34, 0.26, 0.22, 0.13, C("#04040a"), 5)
	eyes(b, 1.28, -0.46, 0.11, 0.085, C("#a0f0ff"))
	wedge(b, Vector3(0.7, 0.95, 0.3), Vector3(0.72, 0.95, -1.6), 0.07, 0.06, C("#6a5a4a"), 0.5)
	wedge(b, Vector3(0.72, 1.0, -1.35), Vector3(0.72, 1.0, -1.95), 0.5, 0.05, C("#d8dce8"), 0.2)
	wedge(f, Vector3(0, 0.95, 0.3), Vector3(0, 0.1, 1.9), 0.9, 0.05, Color(0.3, 0.42, 0.62, 1.0), 0.3)
	wedge(f, Vector3(-0.3, 0.9, 0.2), Vector3(-1.1, 0.1, 1.5), 0.3, 0.04, C("#34445e"), 0.35)
	wedge(f, Vector3(0.3, 0.9, 0.2), Vector3(1.1, 0.1, 1.5), 0.3, 0.04, C("#34445e"), 0.35)


# ------------------------------------------------------------------ animali e bestie
static func m_spider(b: W3DBuilder, f: W3DBuilder) -> void:
	var sk := C("#4a4658")
	gem(b, 0, 0.5, 0.45, 0.62, 0.5, 0.72, sk, 6)
	gem(b, 0, 0.5, -0.4, 0.46, 0.4, 0.42, K(sk, 1.15), 6)
	glow(b, 0, 0.62, 0.58, 0.18, C("#c85060"))
	for i in 4:
		for s in [-1.0, 1.0]:
			var z := -0.55 + i * 0.4
			wedge(b, Vector3(s * 0.35, 0.5, z), Vector3(s * 1.35, 0.55, z - 0.35 + i * 0.2), 0.09, 0.05, C("#2e2a3c"), 0.3)
			wedge(b, Vector3(s * 1.2, 0.55, z - 0.3 + i * 0.2), Vector3(s * 1.5, 0.05, z - 0.1 + i * 0.25), 0.06, 0.03, C("#26222f"), 0.3)
	eyes(b, 0.62, -0.78, 0.14, 0.06, C("#ff5060"))
	for s in [-1.0, 1.0]:
		wedge(b, Vector3(s * 0.15, 0.4, -0.7), Vector3(s * 0.2, 0.3, -1.1), 0.07, 0.03, C("#d8d0c0"), 0.4)


static func m_gargoyle(b: W3DBuilder, f: W3DBuilder) -> void:
	var st := C("#5a5a64")
	gem(b, 0, 0.75, 0.05, 0.62, 0.7, 0.58, st, 6)
	gem(b, 0, 1.3, -0.1, 0.5, 0.5, 0.46, K(st, 1.1), 5)
	eyes(b, 1.34, -0.5, 0.15, 0.08, C("#ffb040"))
	for s in [-1.0, 1.0]:
		wedge(b, Vector3(s * 0.25, 1.55, -0.05), Vector3(s * 0.4, 2.1, 0.0), 0.1, 0.05, C("#3a3a42"), 0.4)
		wedge(b, Vector3(s * 0.5, 0.95, 0.15), Vector3(s * 1.55, 1.0, 0.5), 0.5, 0.06, C("#6a6a58"), 0.35)
		wedge(b, Vector3(s * 0.5, 0.95, 0.15), Vector3(s * 1.2, 1.0, -0.6), 0.3, 0.05, C("#555560"), 0.35)
		wedge(b, Vector3(s * 0.25, 0.2, -0.1), Vector3(s * 0.3, 0.1, -0.7), 0.13, 0.06, C("#303038"), 0.4)
	wedge(f, Vector3(0, 0.5, 0.4), Vector3(0, 0.2, 1.6), 0.15, 0.04, C("#3a3a42"), 0.3)


static func m_ooze(b: W3DBuilder, f: W3DBuilder) -> void:
	var sl := C("#7a4a50")
	gem(b, 0, 0.45, 0, 0.95, 0.5, 0.85, sl, 7)
	gem(b, 0.3, 0.8, -0.1, 0.45, 0.35, 0.42, K(sl, 1.2), 6)
	gem(b, -0.4, 0.7, 0.2, 0.35, 0.3, 0.32, K(sl, 0.9), 5)
	glow(b, -0.2, 0.75, -0.45, 0.09, C("#ffa0a0"))
	glow(b, 0.1, 0.78, -0.45, 0.08, C("#ffa0a0"))


static func m_bat(b: W3DBuilder, f: W3DBuilder) -> void:
	var bd := C("#4a4458")
	gem(b, 0, 0.7, 0.05, 0.42, 0.4, 0.5, bd, 6)
	gem(b, 0, 0.95, -0.3, 0.34, 0.3, 0.3, K(bd, 1.1), 5)
	eyes(b, 0.98, -0.55, 0.12, 0.06, C("#ff5878"))
	for s in [-1.0, 1.0]:
		wedge(b, Vector3(s * 0.2, 1.2, -0.4), Vector3(s * 0.28, 1.5, -0.45), 0.08, 0.04, K(bd, 0.8), 0.4)
		wedge(f, Vector3(s * 0.25, 0.8, 0.0), Vector3(s * 1.7, 0.85, -0.45), 0.4, 0.05, C("#5a4e6c"), 0.35)
		wedge(f, Vector3(s * 0.25, 0.8, 0.1), Vector3(s * 1.45, 0.8, 0.6), 0.3, 0.04, C("#463c58"), 0.35)


static func m_rat(b: W3DBuilder, f: W3DBuilder) -> void:
	var fur := C("#7a6e70")
	gem(b, 0, 0.35, 0.15, 0.38, 0.32, 0.6, fur, 6)
	gem(b, 0, 0.38, -0.5, 0.25, 0.24, 0.3, K(fur, 1.1), 5)
	wedge(b, Vector3(0, 0.35, -0.7), Vector3(0, 0.33, -0.98), 0.1, 0.03, C("#d0a0a0"), 0.5)
	eyes(b, 0.48, -0.62, 0.1, 0.04, C("#ff6070"))
	for s in [-1.0, 1.0]:
		gem(b, s * 0.17, 0.62, -0.42, 0.1, 0.1, 0.06, C("#c09090"), 4)
	wedge(f, Vector3(0, 0.3, 0.6), Vector3(0.3, 0.15, 1.5), 0.07, 0.03, C("#b08888"), 0.4)


static func m_imp(b: W3DBuilder, f: W3DBuilder) -> void:
	var sk := C("#8a4a40")
	gem(b, 0, 0.5, 0.05, 0.5, 0.5, 0.45, K(sk, 0.8), 6)
	gem(b, 0, 1.0, -0.1, 0.52, 0.5, 0.46, sk, 5)
	eyes(b, 1.04, -0.45, 0.13, 0.08, C("#ffe060"))
	gem(b, 0, 0.85, -0.45, 0.2, 0.06, 0.07, C("#200808"), 4)
	for s in [-1.0, 1.0]:
		wedge(b, Vector3(s * 0.25, 1.35, -0.15), Vector3(s * 0.55, 1.95, -0.3), 0.1, 0.04, C("#d8d0b0"), 0.35)
		wedge(b, Vector3(s * 0.4, 0.7, 0.1), Vector3(s * 1.25, 0.9, -0.5), 0.3, 0.05, C("#6a3038"), 0.35)
		wedge(b, Vector3(s * 0.4, 0.7, 0.2), Vector3(s * 1.2, 0.8, 0.5), 0.22, 0.04, C("#582830"), 0.35)
		wedge(b, Vector3(s * 0.45, 0.6, -0.2), Vector3(s * 0.6, 0.4, -0.85), 0.1, 0.04, K(sk, 0.9), 0.4)
	wedge(f, Vector3(0, 0.4, 0.4), Vector3(0.3, 0.2, 1.6), 0.1, 0.12, C("#7a3a38"), 0.4)


static func m_wisp(b: W3DBuilder, f: W3DBuilder) -> void:
	gem(b, 0, 0.9, 0, 0.5, 0.75, 0.46, Color(0.55, 0.72, 0.88, 1.0), 6)
	gem(b, 0, 0.9, 0, 0.3, 0.5, 0.28, Color(0.7, 0.9, 1.0, 0.25), 5)
	eyes(b, 1.0, -0.42, 0.13, 0.08, C("#102030"))
	wedge(f, Vector3(0, 0.55, 0.1), Vector3(0, 0.1, 1.2), 0.3, 0.04, Color(0.5, 0.7, 0.9, 1.0), 0.3)


static func m_toad(b: W3DBuilder, f: W3DBuilder) -> void:
	var sk := C("#6a7a50")
	gem(b, 0, 0.5, 0.15, 0.78, 0.5, 0.7, sk, 7)
	gem(b, 0, 0.6, -0.5, 0.55, 0.42, 0.42, K(sk, 1.1), 6)
	for s in [-1.0, 1.0]:
		gem(b, s * 0.3, 0.95, -0.6, 0.17, 0.17, 0.16, K(sk, 1.2), 5)
		glow(b, s * 0.3, 1.05, -0.74, 0.09, C("#ffe060"))
		gem(b, s * 0.7, 0.2, 0.5, 0.3, 0.2, 0.42, K(sk, 0.8), 5)
		gem(b, s * 0.6, 0.15, -0.4, 0.2, 0.14, 0.26, K(sk, 0.85), 5)
	gem(b, 0, 0.55, -0.85, 0.35, 0.08, 0.1, C("#2a2418"), 4)


static func m_wolf(b: W3DBuilder, f: W3DBuilder) -> void:
	var fur := C("#7e7e8a")
	gem(b, 0, 0.62, 0.35, 0.6, 0.52, 0.85, fur, 6)
	gem(b, 0, 0.68, -0.42, 0.52, 0.48, 0.5, K(fur, 1.1), 6)
	gem(b, 0, 0.62, -1.0, 0.34, 0.3, 0.34, K(fur, 1.2), 5)
	gem(b, 0, 0.6, -1.3, 0.16, 0.13, 0.2, C("#2a2a30"), 4)
	for s in [-1.0, 1.0]:
		wedge(b, Vector3(s * 0.22, 0.95, -0.55), Vector3(s * 0.32, 1.55, -0.45), 0.12, 0.05, K(fur, 0.8), 0.3)
		wedge(b, Vector3(s * 0.3, 0.1, -0.5), Vector3(s * 0.32, 0.5, -0.45), 0.12, 0.08, K(fur, 0.7), 0.5)
		wedge(b, Vector3(s * 0.3, 0.1, 0.7), Vector3(s * 0.32, 0.5, 0.65), 0.12, 0.08, K(fur, 0.7), 0.5)
	eyes(b, 0.82, -1.08, 0.13, 0.06, C("#ffc060"))
	for i in 4:
		wedge(b, Vector3(0, 0.9, 0.7 - i * 0.3), Vector3(0, 1.35, 0.6 - i * 0.3), 0.06, 0.05, K(fur, 0.7), 0.3)
	wedge(f, Vector3(0, 0.8, 0.95), Vector3(0, 1.1, 2.1), 0.2, 0.1, K(fur, 0.9), 0.35)


static func m_harpy(b: W3DBuilder, f: W3DBuilder) -> void:
	gem(b, 0, 0.6, 0.1, 0.5, 0.55, 0.46, C("#6a5a50"), 6)
	gem(b, 0, 1.12, -0.1, 0.46, 0.46, 0.42, C("#d8d0c8"), 5)
	eyes(b, 1.14, -0.42, 0.11, 0.06, C("#ff7088"))
	wedge(b, Vector3(0, 1.0, -0.38), Vector3(0, 0.95, -0.6), 0.09, 0.03, C("#d0b050"), 0.5)
	gem(b, 0, 1.45, 0.0, 0.4, 0.18, 0.4, C("#3a2a40"), 6)
	for s in [-1.0, 1.0]:
		wedge(b, Vector3(s * 0.4, 0.9, 0.1), Vector3(s * 1.75, 1.0, -0.2), 0.4, 0.06, C("#5a4a5a"), 0.35)
		wedge(b, Vector3(s * 0.4, 0.85, 0.2), Vector3(s * 1.55, 0.9, 0.8), 0.3, 0.05, C("#463a4a"), 0.35)
		wedge(b, Vector3(s * 0.2, 0.2, -0.1), Vector3(s * 0.3, 0.05, -0.7), 0.1, 0.03, C("#d0b050"), 0.4)
	wedge(f, Vector3(0, 0.5, 0.4), Vector3(0, 0.2, 1.5), 0.3, 0.05, C("#4a3a4a"), 0.3)


static func m_lizardman(b: W3DBuilder, f: W3DBuilder) -> void:
	var sk := C("#5e8a60")
	gem(b, 0, 0.6, 0.1, 0.58, 0.56, 0.5, K(sk, 0.85), 6)
	gem(b, 0, 1.15, -0.12, 0.44, 0.44, 0.5, sk, 5)
	gem(b, 0, 1.08, -0.55, 0.22, 0.2, 0.3, K(sk, 1.1), 5)
	eyes(b, 1.22, -0.4, 0.17, 0.07, C("#ffe040"))
	wedge(b, Vector3(0, 1.4, 0.0), Vector3(0, 1.7, 0.1), 0.1, 0.06, C("#a85860"), 0.4)
	pair(b, 0.6, 0.9, 0.0, 0.2, 0.16, 0.26, K(sk, 0.9))
	gem(b, -0.9, 0.85, -0.1, 0.4, 0.1, 0.4, C("#7a5a38"), 7)
	wedge(b, Vector3(0.92, 0.9, 0.5), Vector3(0.95, 0.95, -1.9), 0.06, 0.05, C("#5a4630"), 0.5)
	wedge(b, Vector3(0.95, 0.95, -1.6), Vector3(0.97, 0.95, -2.2), 0.1, 0.03, C("#b0b4c0"), 0.2)
	wedge(f, Vector3(0, 0.4, 0.4), Vector3(0.3, 0.15, 1.9), 0.3, 0.05, K(sk, 0.8), 0.3)


# ------------------------------------------------------------------ goblinoidi e brutti ceffi
static func goblin_base(b: W3DBuilder, f: W3DBuilder) -> void:
	var skin := C("#76905a")
	var lea := C("#4a3a2c")
	gem(b, 0, 0.5, 0.1, 0.48, 0.48, 0.44, lea, 6)
	gem(b, 0, 1.1, -0.04, 0.72, 0.56, 0.6, skin, 6)
	for s in [-1.0, 1.0]:
		wedge(f, Vector3(s * 0.45, 1.2, 0.0), Vector3(s * 1.95, 1.15, 0.3), 0.3, 0.05, skin, 0.35)
	eyes(b, 1.2, -0.52, 0.23, 0.12, C("#ffe030"))
	gem(b, 0, 1.0, -0.6, 0.13, 0.1, 0.1, K(skin, 0.8), 4)
	gem(b, 0, 0.88, -0.52, 0.28, 0.06, 0.08, C("#0a0806"), 4)
	for s in [-1.0, 1.0]:
		wedge(b, Vector3(s * 0.1, 0.92, -0.58), Vector3(s * 0.1, 1.02, -0.66), 0.045, 0.02, C("#e8e4d0"), 0.5)
	pair(b, 0.55, 0.62, -0.1, 0.16, 0.16, 0.22, skin)
	feet(b, 0.22, -0.15, 0.18, K(skin, 0.75))


static func m_goblin(b: W3DBuilder, f: W3DBuilder, archer: bool) -> void:
	goblin_base(b, f)
	if archer:
		bow(b, -0.85, C("#6a5236"))
		gem(b, 0.28, 0.8, 0.5, 0.18, 0.34, 0.15, C("#5a4630"), 5)
		wedge(b, Vector3(0.32, 1.0, 0.52), Vector3(0.36, 1.45, 0.6), 0.05, 0.04, C("#d8d0b0"), 0.5)
	else:
		wedge(b, Vector3(0.68, 0.7, -0.3), Vector3(0.74, 0.74, -1.4), 0.1, 0.03, C("#b8bcc4"), 0.2)
		wedge(b, Vector3(0.68, 0.7, -0.3), Vector3(0.68, 0.7, 0.2), 0.08, 0.08, C("#6a4a2a"), 0.5)


static func m_goblin_shaman(b: W3DBuilder, f: W3DBuilder) -> void:
	goblin_base(b, f)
	gem(b, 0, 1.52, 0.0, 0.46, 0.14, 0.4, C("#c04838"), 6)
	for i in 5:
		var a := -0.9 + i * 0.45
		wedge(b, Vector3(sin(a) * 0.25, 1.5, cos(a) * 0.2), Vector3(sin(a) * 0.45, 1.95, cos(a) * 0.35 + 0.05), 0.07, 0.03, [C("#c04838"), C("#d8a838"), C("#c04838"), C("#d8a838"), C("#c04838")][i], 0.4)
	gem(b, 0, 1.18, -0.5, 0.38, 0.32, 0.12, C("#e0d8c0"), 5)
	staff(b, 0.85, 0.5, -1.45, C("#5a4630"))
	gem(b, 0.87, 1.0, -1.58, 0.26, 0.24, 0.24, C("#d8d0b8"), 5)
	glow(b, 0.8, 1.1, -1.8, 0.06, C("#70f0b0"))
	glow(b, 0.95, 1.1, -1.8, 0.06, C("#70f0b0"))


static func m_kobold(b: W3DBuilder, f: W3DBuilder) -> void:
	var sk := C("#8a5a3a")
	gem(b, 0, 0.42, 0.1, 0.38, 0.4, 0.36, C("#6a4a38"), 6)
	gem(b, 0, 0.98, -0.05, 0.62, 0.52, 0.54, sk, 6)
	gem(b, 0, 0.9, -0.5, 0.24, 0.2, 0.3, K(sk, 1.25), 5)
	eyes(b, 1.1, -0.42, 0.17, 0.09, C("#ffd840"))
	gem(b, 0, 0.88, -0.78, 0.07, 0.06, 0.06, C("#100808"), 4)
	for s in [-1.0, 1.0]:
		wedge(b, Vector3(s * 0.22, 1.25, -0.05), Vector3(s * 0.55, 1.95, 0.25), 0.09, 0.04, C("#e8e0cc"), 0.3)
		wedge(b, Vector3(s * 0.6, 0.6, -0.1), Vector3(s * 0.55, 0.5, -0.5), 0.09, 0.07, sk, 0.4)
	wedge(b, Vector3(-0.7, 0.75, 0.6), Vector3(-0.78, 0.85, -2.1), 0.05, 0.05, C("#6a4a2a"), 0.5)
	wedge(b, Vector3(-0.78, 0.85, -1.85), Vector3(-0.8, 0.85, -2.5), 0.1, 0.03, C("#b8bcc4"), 0.2)
	wedge(f, Vector3(0, 0.3, 0.3), Vector3(0.45, 0.12, 1.7), 0.12, 0.1, K(sk, 0.85), 0.3)


static func m_orc(b: W3DBuilder, f: W3DBuilder) -> void:
	var sk := C("#6a8250")
	gem(b, 0, 0.85, 0.05, 0.92, 0.72, 0.68, C("#4a3a32"), 6)
	gem(b, 0, 0.95, -0.38, 0.5, 0.4, 0.22, C("#7a7a6a"), 6)
	pair(b, 0.82, 1.15, 0.0, 0.36, 0.3, 0.36, sk)
	gem(b, 0, 1.5, -0.1, 0.58, 0.48, 0.52, sk, 6)
	eyes(b, 1.55, -0.46, 0.18, 0.09, C("#ffe040"))
	for s in [-1.0, 1.0]:
		wedge(b, Vector3(s * 0.17, 1.38, -0.46), Vector3(s * 0.2, 1.82, -0.55), 0.07, 0.04, C("#f0ece0"), 0.3)
	gem(b, 0, 1.3, -0.52, 0.34, 0.07, 0.07, C("#0a0806"), 4)
	gem(b, -1.15, 0.9, -0.15, 0.58, 0.14, 0.58, C("#9a9aa4"), 8)
	gem(b, -1.15, 1.0, -0.15, 0.16, 0.1, 0.16, C("#6a6a74"), 5)
	pair(b, 0.9, 0.7, -0.4, 0.24, 0.22, 0.24, K(sk, 1.05))
	wedge(b, Vector3(1.05, 0.95, 0.5), Vector3(1.08, 0.98, -1.5), 0.1, 0.08, C("#5a4630"), 0.5)
	gem(b, 1.08, 1.0, -1.65, 0.3, 0.22, 0.4, C("#9a9aa4"), 5)
	feet(b, 0.3, -0.1, 0.26, C("#2a2622"))


static func m_troll(b: W3DBuilder, f: W3DBuilder) -> void:
	var sk := C("#808a68")
	gem(b, 0, 0.95, 0.15, 1.15, 0.85, 0.85, K(sk, 0.85), 7)
	gem(b, 0, 1.0, -0.5, 0.65, 0.5, 0.4, K(sk, 1.05), 6)
	pair(b, 1.05, 1.1, 0.0, 0.45, 0.4, 0.45, sk)
	gem(b, 0, 1.55, -0.3, 0.6, 0.5, 0.55, K(sk, 1.1), 6)
	eyes(b, 1.6, -0.72, 0.2, 0.09, C("#ffe070"))
	gem(b, 0, 1.38, -0.8, 0.4, 0.09, 0.09, C("#0a0806"), 4)
	for s in [-1.0, 1.0]:
		wedge(b, Vector3(s * 0.2, 1.45, -0.78), Vector3(s * 0.22, 1.85, -0.9), 0.08, 0.04, C("#ece8d8"), 0.3)
		wedge(b, Vector3(s * 1.1, 0.9, -0.2), Vector3(s * 1.25, 0.5, -1.5), 0.3, 0.2, K(sk, 0.95), 0.4)
		gem(b, s * 1.27, 0.5, -1.65, 0.3, 0.25, 0.3, K(sk, 1.05), 5)
	wedge(b, Vector3(1.4, 0.8, 0.8), Vector3(1.45, 0.85, -1.7), 0.14, 0.12, C("#5a4630"), 0.5)
	gem(b, 1.47, 0.9, -2.0, 0.42, 0.36, 0.42, C("#6a5a46"), 6)


static func m_ogre(b: W3DBuilder, f: W3DBuilder) -> void:
	var sk := C("#b0a08a")
	gem(b, 0, 1.0, 0.1, 1.3, 0.95, 0.95, sk, 7)
	gem(b, 0, 0.7, -0.1, 1.1, 0.45, 0.8, C("#6a5a48"), 7)
	pair(b, 1.2, 1.2, 0.0, 0.5, 0.42, 0.5, K(sk, 1.05))
	gem(b, 0, 1.6, -0.25, 0.62, 0.5, 0.56, K(sk, 1.1), 6)
	eyes(b, 1.62, -0.72, 0.2, 0.08, C("#704040"))
	gem(b, 0, 1.38, -0.78, 0.3, 0.1, 0.09, C("#3a2420"), 4)
	gem(b, 0, 1.55, -0.8, 0.12, 0.1, 0.09, K(sk, 0.85), 4)
	for s in [-1.0, 1.0]:
		wedge(b, Vector3(s * 1.2, 1.0, -0.2), Vector3(s * 1.4, 1.3, -1.6), 0.34, 0.24, K(sk, 1.0), 0.4)
		gem(b, s * 1.45, 1.35, -1.8, 0.34, 0.3, 0.34, K(sk, 1.1), 5)
	gem(b, 1.5, 1.4, -2.3, 0.2, 0.18, 0.5, C("#7a6a56"), 5)


# ------------------------------------------------------------------ campioni e boss
static func m_knight_fallen(b: W3DBuilder, f: W3DBuilder) -> void:
	var ar := C("#6a6a76")
	gem(b, 0, 0.62, 0.05, 0.72, 0.62, 0.6, C("#2e2a3a"), 6)
	gem(b, 0, 1.3, -0.02, 0.56, 0.6, 0.52, ar, 5)
	wedge(b, Vector3(0, 1.55, 0.1), Vector3(0.05, 2.3, 0.28), 0.34, 0.3, K(ar, 0.9))
	gem(b, 0, 1.22, -0.38, 0.3, 0.22, 0.14, C("#06040a"), 5)
	eyes(b, 1.26, -0.5, 0.1, 0.08, C("#ff6040"))
	pair(b, 0.7, 0.98, 0.0, 0.34, 0.24, 0.36, K(ar, 0.85))
	sword(b, 1.0, 1.0, 0.45, -1.5, C("#9a9aa8"), C("#7a5a30"))
	wedge(f, Vector3(0, 0.95, 0.3), Vector3(0, 0.3, 1.8), 0.9, 0.05, C("#5a1c28"), 0.3)


static func m_reaper(b: W3DBuilder, f: W3DBuilder) -> void:
	gem(b, 0, 0.75, 0.05, 0.66, 0.72, 0.58, C("#2a2430"), 6)
	gem(b, 0, 1.32, -0.02, 0.54, 0.6, 0.5, C("#3a3440"), 5)
	gem(b, 0, 1.26, -0.38, 0.28, 0.24, 0.14, C("#030206"), 5)
	eyes(b, 1.3, -0.5, 0.1, 0.07, C("#c0f0ff"))
	wedge(b, Vector3(0.85, 0.9, 0.9), Vector3(0.9, 1.0, -1.8), 0.07, 0.06, C("#4a3a2c"), 0.5)
	wedge(b, Vector3(0.9, 1.05, -1.6), Vector3(0.1, 1.05, -2.3), 0.3, 0.03, C("#e0e4ec"), 0.3)
	wedge(f, Vector3(0, 1.0, 0.3), Vector3(0, 0.1, 2.0), 0.95, 0.05, C("#1e1a26"), 0.3)
	wedge(f, Vector3(-0.3, 0.95, 0.2), Vector3(-1.1, 0.1, 1.6), 0.3, 0.04, C("#17131e"), 0.35)


static func m_summoner(b: W3DBuilder, f: W3DBuilder) -> void:
	gem(b, 0, 0.62, 0.05, 0.62, 0.6, 0.56, C("#3a2850"), 6)
	gem(b, 0, 1.25, -0.02, 0.5, 0.56, 0.46, C("#2c2234"), 5)
	gem(b, 0, 1.2, -0.35, 0.27, 0.22, 0.14, C("#05030a"), 5)
	eyes(b, 1.24, -0.48, 0.1, 0.07, C("#ff80d0"))
	pair(b, 0.6, 0.92, 0.0, 0.28, 0.2, 0.3, C("#4a3260"))
	staff(b, 0.92, 0.9, -1.5, C("#5a4630"))
	gem(b, 0.94, 1.0, -1.65, 0.3, 0.3, 0.3, C("#d8d0e0"), 6)
	wedge(b, Vector3(0.94, 1.1, -1.8), Vector3(0.94, 1.6, -2.3), 0.14, 0.12, Color(0.9, 0.4, 0.85, 0.15), 0.4)
	for i in 3:
		var a := TAU * i / 3.0 + 0.5
		gem(b, cos(a) * 0.8 - 0.6, 1.5, sin(a) * 0.8 - 0.3, 0.13, 0.13, 0.13, Color(0.95, 0.5, 0.9, 0.25), 4)
	wedge(f, Vector3(0, 0.95, 0.3), Vector3(0, 0.3, 1.85), 0.85, 0.05, C("#2a1c40"), 0.3)


static func m_abomination(b: W3DBuilder, f: W3DBuilder) -> void:
	var fl := C("#8a6e68")
	gem(b, 0, 0.95, 0.1, 1.45, 1.0, 1.15, fl, 7)
	gem(b, -0.6, 1.5, -0.2, 0.7, 0.55, 0.65, K(fl, 1.1), 6)
	gem(b, 0.55, 1.45, 0.1, 0.62, 0.5, 0.58, K(fl, 0.9), 6)
	for i in 5:
		glow(b, -0.8 + i * 0.4, 1.0, -1.05, 0.07, C("#e8d8c8"))
	eyes(b, 1.5, -0.62, 0.3, 0.1, C("#ffd070"))
	gem(b, 0, 1.15, -1.0, 0.5, 0.12, 0.1, C("#2a1418"), 5)
	for s in [-1.0, 1.0]:
		wedge(b, Vector3(s * 1.2, 1.1, -0.1), Vector3(s * 1.7, 0.7, -1.2), 0.4, 0.2, K(fl, 0.9), 0.4)
		for k in 3:
			wedge(b, Vector3(s * (1.55 + k * 0.1), 0.7, -1.1), Vector3(s * (1.8 + k * 0.15), 0.5, -1.7), 0.06, 0.03, C("#d8d0c0"), 0.4)


static func m_frost_mage(b: W3DBuilder, f: W3DBuilder) -> void:
	gem(b, 0, 0.62, 0.05, 0.62, 0.6, 0.56, C("#2c3a58"), 6)
	gem(b, 0, 1.25, -0.02, 0.5, 0.56, 0.46, C("#3a3e50"), 5)
	for i in 5:
		wedge(b, Vector3((i - 2) * 0.17, 1.55, 0.0), Vector3((i - 2) * 0.22, 2.05, 0.05), 0.07, 0.03, C("#c0e8ff"), 0.3)
	gem(b, 0, 1.2, -0.35, 0.27, 0.22, 0.14, C("#04060c"), 5)
	eyes(b, 1.24, -0.48, 0.1, 0.075, C("#80e8ff"))
	pair(b, 0.6, 0.92, 0.0, 0.28, 0.2, 0.3, C("#3a4c70"))
	staff(b, 0.92, 0.9, -1.5, C("#4a5666"))
	wedge(b, Vector3(0.94, 1.0, -1.55), Vector3(0.94, 1.1, -2.4), 0.2, 0.05, C("#b8e0ff"), 0.4)
	wedge(f, Vector3(0, 0.95, 0.3), Vector3(0, 0.3, 1.8), 0.85, 0.05, C("#26344e"), 0.3)


static func m_berserker(b: W3DBuilder, f: W3DBuilder) -> void:
	var sk := C("#9a7a70")
	gem(b, 0, 0.82, 0.05, 0.9, 0.7, 0.62, C("#7a3a38"), 6)
	pair(b, 0.82, 1.1, 0.0, 0.34, 0.28, 0.34, sk)
	gem(b, 0, 1.45, -0.08, 0.5, 0.46, 0.46, sk, 6)
	eyes(b, 1.5, -0.42, 0.14, 0.08, C("#ff5030"))
	gem(b, 0, 1.28, -0.46, 0.26, 0.07, 0.07, C("#1a0808"), 4)
	gem(b, 0, 1.72, 0.0, 0.5, 0.14, 0.44, C("#2a1c1c"), 6)
	for s in [-1.0, 1.0]:
		wedge(b, Vector3(s * 0.85, 1.0, -0.1), Vector3(s * 1.0, 1.1, -1.4), 0.2, 0.16, K(sk, 0.95), 0.4)
		wedge(b, Vector3(s * 1.05, 1.1, -1.2), Vector3(s * 1.3, 1.1, -1.8), 0.5, 0.05, C("#c0c0c8"), 0.4)
		wedge(b, Vector3(s * 1.05, 1.1, -1.3), Vector3(s * 1.05, 1.1, -1.5), 0.2, 0.2, C("#6a5a46"), 0.5)
	wedge(f, Vector3(0, 0.8, 0.4), Vector3(0, 0.3, 1.5), 0.5, 0.05, C("#5a2a2a"), 0.3)


static func m_plague_doc(b: W3DBuilder, f: W3DBuilder) -> void:
	gem(b, 0, 0.62, 0.05, 0.64, 0.6, 0.56, C("#242a24"), 6)
	gem(b, 0, 1.25, -0.02, 0.52, 0.52, 0.48, C("#303030"), 5)
	gem(b, 0, 1.12, -0.5, 0.2, 0.18, 0.6, C("#d8d0b8"), 5)
	wedge(b, Vector3(0, 1.1, -0.9), Vector3(0, 1.0, -1.45), 0.15, 0.04, C("#e0d8c0"), 0.4)
	pair(b, 0.22, 1.32, -0.42, 0.12, 0.12, 0.08, C("#7ad0a0"), 5)
	gem(b, 0, 1.55, 0.0, 0.62, 0.1, 0.6, C("#1a1a1a"), 7)
	pair(b, 0.62, 0.92, 0.0, 0.28, 0.2, 0.3, C("#3a4a3a"))
	wedge(b, Vector3(0.9, 0.9, 0.3), Vector3(0.95, 0.95, -0.9), 0.06, 0.05, C("#5a4630"), 0.5)
	gem(b, 0.98, 0.8, -1.1, 0.25, 0.27, 0.25, C("#4a8a50"), 6)
	glow(b, 0.98, 0.95, -1.1, 0.12, C("#80f0a0"))
	wedge(f, Vector3(0, 0.95, 0.3), Vector3(0, 0.3, 1.75), 0.85, 0.05, C("#1e241e"), 0.3)


static func m_vampire(b: W3DBuilder, f: W3DBuilder) -> void:
	gem(b, 0, 0.8, 0.1, 1.2, 0.9, 0.95, C("#6a2c34"), 7)
	gem(b, 0, 0.95, -0.1, 0.8, 0.5, 0.62, C("#1c1420"), 6)
	pair(b, 1.0, 1.25, 0.0, 0.4, 0.34, 0.4, C("#4a2430"))
	gem(b, 0, 1.55, -0.1, 0.58, 0.52, 0.52, C("#d8d0d4"), 6)
	wedge(b, Vector3(0, 1.8, 0.0), Vector3(0.0, 2.1, 0.25), 0.4, 0.3, C("#1a1018"), 0.4)
	eyes(b, 1.58, -0.46, 0.17, 0.09, C("#ff3030"))
	gem(b, 0, 1.36, -0.5, 0.22, 0.07, 0.07, C("#280808"), 4)
	for s in [-1.0, 1.0]:
		wedge(b, Vector3(s * 0.1, 1.38, -0.5), Vector3(s * 0.1, 1.22, -0.58), 0.045, 0.02, C("#f0ece0"), 0.5)
	sword(b, 1.2, 1.1, 0.5, -1.6, C("#b0b0bc"), C("#c0a040"))
	wedge(f, Vector3(-0.8, 1.2, 0.2), Vector3(-2.2, 0.4, 1.4), 0.7, 0.05, C("#5a1c28"), 0.35)
	wedge(f, Vector3(0.8, 1.2, 0.2), Vector3(2.2, 0.4, 1.4), 0.7, 0.05, C("#5a1c28"), 0.35)
	wedge(f, Vector3(0, 1.0, 0.4), Vector3(0, 0.3, 2.0), 0.9, 0.05, C("#3a1220"), 0.3)


static func pivot(kind: String) -> Vector3:
	return Vector3(0, 0.8, 0.8) if kind == "wolf" else Vector3(0, 1.0, 0.1)


## ritorna [mesh corpo, mesh fluente]
static func build(kind: String) -> Array:
	var b := W3DBuilder.new()
	var f := W3DBuilder.new()
	b.rn.seed = hash(kind)
	f.rn.seed = hash(kind) + 7
	match kind:
		"hero":
			m_hero(b, f)
		"hunter":
			m_hunter(b, f)
		"necro":
			m_necro(b, f)
		"cleric":
			m_cleric(b, f)
		"skeleton":
			m_skeleton(b, f, false)
		"skel_archer":
			m_skeleton(b, f, true)
		"ghoul":
			m_ghoul(b, f)
		"zombie":
			m_zombie(b, f)
		"spider":
			m_spider(b, f)
		"gargoyle":
			m_gargoyle(b, f)
		"ooze":
			m_ooze(b, f)
		"bat":
			m_bat(b, f)
		"cultist":
			m_summoner(b, f)
		"wraith":
			m_wraith(b, f)
		"rat":
			m_rat(b, f)
		"imp":
			m_imp(b, f)
		"wisp":
			m_wisp(b, f)
		"toad":
			m_toad(b, f)
		"wolf":
			m_wolf(b, f)
		"goblin":
			m_goblin(b, f, false)
		"goblin_archer":
			m_goblin(b, f, true)
		"goblin_shaman":
			m_goblin_shaman(b, f)
		"kobold":
			m_kobold(b, f)
		"orc":
			m_orc(b, f)
		"troll":
			m_troll(b, f)
		"ogre":
			m_ogre(b, f)
		"harpy":
			m_harpy(b, f)
		"lizardman":
			m_lizardman(b, f)
		"knight_fallen":
			m_knight_fallen(b, f)
		"reaper":
			m_reaper(b, f)
		"summoner":
			m_summoner(b, f)
		"abomination":
			m_abomination(b, f)
		"frost_mage":
			m_frost_mage(b, f)
		"berserker":
			m_berserker(b, f)
		"plague_doc":
			m_plague_doc(b, f)
		"vampire":
			m_vampire(b, f)
	f.shift(-pivot(kind))
	return [b.mesh(), f.mesh()]
