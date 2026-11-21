class_name Bestiary
## Schede del bestiario: [tipo, nome, descrizione, dove si incontra]. L'ordine e' quello delle pagine.

const ENTRIES := [
	["rat", "RATTO DI FOGNA", "Grosso come un gatto, affamato come un lupo. Da solo e' poco piu' di un fastidio.", "OVUNQUE"],
	["kobold", "COBOLDO", "Piccolo predone dal muso di rettile. Rapidissimo, attacca a sciami e scappa quando resta solo.", "VILLAGGIO, PALUDE, FONDERIE"],
	["goblin", "GOBLIN", "Ladro e assassino: colpisce col coltellaccio e salta indietro prima che tu possa reagire.", "VILLAGGIO, FORESTA"],
	["goblin_archer", "GOBLIN ARCIERE", "Resta lontano e tira frecce a ventaglio. Va raggiunto in fretta.", "VILLAGGIO, FORESTA"],
	["goblin_shaman", "GOBLIN SCIAMANO", "Dietro la maschera d'osso mormora maledizioni e lancia sfere di fuoco verde.", "FORESTA, CIMITERO"],
	["skeleton", "SCHELETRO", "Un soldato che non ha smesso di combattere. Para, affonda e torna a parare.", "CIMITERO, VILLAGGIO"],
	["skel_archer", "SCHELETRO ARCIERE", "Le dita d'osso non tremano mai: tre frecce alla volta, da lontano.", "CIMITERO, ROVINE"],
	["zombie", "NON MORTO", "Lento e ostinato, assorbe colpi che abbatterebbero un uomo. Alcuni esplodono.", "CIMITERO, PALUDE"],
	["ghoul", "GHOUL", "Divoratore di cadaveri: si acquatta e balza addosso quando abbassi la guardia.", "CIMITERO, PALUDE"],
	["wraith", "SPETTRO", "Svanisce e riappare alle tue spalle. Solo la falce e' reale.", "CIMITERO, ROVINE, VETTA"],
	["bat", "PIPISTRELLO", "Volo spezzato, morsi rapidi. In stormo diventa pericoloso.", "CIMITERO, FORESTA"],
	["crow", "CORVO", "Spazzino del campo di battaglia. Non ha paura dei vivi.", "CIMITERO, FONDERIE"],
	["wolf", "LUPO", "Caccia in branco e ti aggira ai fianchi. Il lupo crudele e' grande il doppio.", "FORESTA, VETTA, VILLAGGIO"],
	["spider", "RAGNO DELLA CRIPTA", "Aspetta immobile nell'ombra, poi scatta. Le covate si moltiplicano.", "FORESTA, PALUDE"],
	["cultist", "ADEPTO", "Servo del Signore della Cripta. Lancia incantesimi e si tiene a distanza.", "FORESTA, ROVINE, FONDERIE"],
	["toad", "ROSPO PUTRIDO", "Pelle ulcerata e lingua lunga: si lancia a balzi improvvisi.", "PALUDE"],
	["ooze", "MELMA", "Sangue rappreso che striscia. Colpita, si divide in melme piu' piccole.", "PALUDE, FONDERIE"],
	["lizardman", "UOMO LUCERTOLA", "Guerriero della palude con lancia e scudo di guscio. Ti gira attorno e colpisce di fianco.", "PALUDE"],
	["harpy", "ARPIA", "Meta' donna, meta' rapace. Piomba dall'alto con gli artigli.", "PALUDE, ROVINE, VETTA, CIMITERO"],
	["orc", "ORCO", "Guerriero brutale con ascia e spallaccio. Il capo orco e' ancora piu' grosso e feroce.", "ROVINE, FONDERIE, FORESTA"],
	["troll", "TROLL", "Muschio sulla schiena e una clava in mano. Se smetti di colpirlo, le ferite si richiudono.", "FORESTA, PALUDE, VETTA"],
	["ogre", "OGRE", "Lentissimo, enorme, affamato. Un solo colpo della sua clava ti stende.", "ROVINE, VETTA, FONDERIE"],
	["gargoyle", "GARGOYLE", "Pietra viva: plana in picchiata e torna a posarsi sui cornicioni.", "ROVINE, FONDERIE"],
	["imp", "DIAVOLETTO", "Ali a membrana e risata stridula. Quelli di brace esplodono morendo.", "FONDERIE"],
	["wisp", "FUOCO FATUO", "Una luce che ti attira lontano dal sentiero. Il suo tocco gela.", "VETTA"],
	["knight_fallen", "CAVALIERE CADUTO", "Campione. Un tempo difendeva la valle: ora carica e schiaccia chiunque.", "CIMITERO, FORESTA"],
	["reaper", "MIETITORE", "Campione. Scompare e ricompare falciando tutto attorno a se'.", "CIMITERO"],
	["summoner", "EVOCATORE", "Campione. Richiama servitori dalla terra e lancia dardi a ventaglio.", "FORESTA"],
	["abomination", "ABOMINIO", "Campione. Carne cucita e rabbia: lento, ma ogni colpo e' un terremoto.", "PALUDE, ROVINE"],
	["frost_mage", "MAGO DEL GELO", "Campione. Rallenta con il ghiaccio e colpisce da lontano.", "VETTA"],
	["berserker", "BERSERKER", "Campione. Furia cieca: piu' e' ferito, piu' e' veloce.", "VETTA, FONDERIE"],
	["plague_doc", "MEDICO DELLA PESTE", "Campione. Nubi velenose e fiale lanciate: non respirare.", "CIMITERO, PALUDE"],
	["boss_jailer", "IL CARCERIERE", "Custode. Guardiano delle Celle del Risveglio, il primo ostacolo verso la liberta'.", "LE CELLE DEL RISVEGLIO"],
	["boss_wraith", "IL FALCIATORE", "Custode. Signore degli spettri della cripta del cimitero.", "CRIPTA DEL CIMITERO"],
	["boss_gargoyle", "GARGOYLE COLOSSALE", "Custode. Veglia sulla cattedrale sommersa da secoli.", "CATTEDRALE SOMMERSA"],
	["boss_hanged", "L'IMPICCATO", "Custode. La corda non l'ha ucciso: l'ha cambiato.", "IL COVO DELL'IMPICCATO"],
	["boss_ooze", "MADRE DELLE MELME", "Custode. Ogni melma della palude nasce da lei.", "LE CAVERNE DELLA MELMA"],
	["boss_yeti", "IL GIGANTE DI GHIACCIO", "Custode. Dorme sul trono gelato della vetta.", "IL TRONO DI GHIACCIO"],
	["boss_forge", "COLOSSO DI BRACE", "Custode. Ossa fuse nel metallo delle forge profonde.", "LE FORGE PROFONDE"],
	["boss_campanaro", "IL CAMPANARO", "Custode colossale. Incatenato al campanile caduto: spezza le catene, poi colpiscilo al volto.", "IL CAMPANILE CADUTO"],
	["vampire", "IL SIGNORE DELLA CRIPTA", "Il padrone della valle. Tutto il male nasce da lui.", "LA CRIPTA DEL SIGNORE"],
]

const AI_TXT := {
	"chase": "INSEGUE", "lunge": "BALZA ADDOSSO", "bat": "VOLO SPEZZATO", "range": "COLPISCE DA LONTANO",
	"archer": "ARCIERE", "duelist": "DUELLANTE", "pouncer": "SI ACQUATTA E BALZA", "ambusher": "IMBOSCATA",
	"diver": "PICCHIATA DALL'ALTO", "caster": "INCANTATORE", "phaser": "SVANISCE E RIAPPARE", "tank": "LENTO E RESISTENTE",
	"skirmish": "COLPISCI E SCAPPA", "flank": "ATTACCA AI FIANCHI", "boss": "CUSTODE", "champ": "CAMPIONE", "part": "COLOSSO",
}


## sprite, vita, danno, velocita', comportamento e anime di un tipo (dai dati dei nemici)
static func stats(kind: String) -> Dictionary:
	if Enemy.CHAMPS.has(kind):
		var c: Dictionary = Enemy.CHAMPS[kind]
		return {"spr": c["spr"], "hp": float(c["hp"]) * 1.6, "dmg": float(c["dmg"]) * 1.2, "spd": float(c["spd"]),
			"ai": "champ", "souls": int(c["souls"])}
	if Enemy.DEFS.has(kind):
		var d: Array = Enemy.DEFS[kind]
		var boss: bool = d.size() > 7
		return {"spr": d[0], "hp": float(d[1]) * 1.2 * (1.5 if boss else 1.0), "dmg": float(d[6]) * 1.3, "spd": float(d[2]),
			"ai": d[3] if not boss or kind == "boss_campanaro" else "boss", "souls": int(d[5])}
	return {}


static func speed_txt(s: float) -> String:
	if s <= 0.0:
		return "IMMOBILE"
	if s < 30.0:
		return "LENTA"
	if s < 50.0:
		return "MEDIA"
	return "RAPIDA"
