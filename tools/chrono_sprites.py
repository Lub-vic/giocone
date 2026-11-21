"""Sprite del Cronotone: icone degli oggetti evocati, mezzi (vista dall'alto, rivolti a destra), drone e golem.
Stesso motore delle altre creature (render "B" di gen_sprites + grade di gothic.py), nessuna AI, nessuna GPU.

Uso: python chrono_sprites.py <cartella_sprites> [--preview file.png]
Scrive: ch_<id>.png (oggetti), veh_carro/veh_tank/veh_ufo.png, drone.png, golem.png
"""
import os, sys

OUT = sys.argv[1] if len(sys.argv) > 1 else "."
PREV = sys.argv[sys.argv.index("--preview") + 1] if "--preview" in sys.argv else None
here = os.path.dirname(os.path.abspath(__file__))
src = open(os.path.join(here, "gothic.py"), encoding="utf-8").read()
src = src[:src.rindex("\nmain()")]
tmp = os.path.join(os.environ.get("TEMP", "."), "gothic_tmp")
os.makedirs(tmp, exist_ok=True)
sys.argv = [sys.argv[0], tmp]
ns = {"__file__": os.path.join(here, "gothic.py"), "__name__": "gothic_lib"}
exec(compile(src, "gothic.py", "exec"), ns)
G, S, grade = ns["G"], ns["S"], ns["grade"]

STEEL = dict(m='#a8aebc', s='#6a7080', d='#3a3e4c', k='#1a1c24', w='#e8e8f0')


def P(**kw):
    d = dict(STEEL)
    d.update(kw)
    return d


# ------------------------------------------------------------------ oggetti utili
def fumo():  # granata fumogena: corpo tondo a rombi, leva, anello, fumo
    g = G(16)
    g.e(8, 10, 4.8, 4.8, 'o'); g.r(6, 4, 4, 2, 's'); g.r(7, 3, 2, 1, 's')
    g.l(5, 8, 11, 12, 'h'); g.l(11, 8, 5, 12, 'h'); g.r(5, 10, 6, 1, 'h')       # rombi
    g.l(10, 4, 12, 6, 'm'); g.l(12, 6, 12, 10, 'm'); g.e(5, 3, 1.4, 1.4, 'y'); g.p(5, 3, None)   # leva, anello
    g.e(3, 1.5, 2, 1.4, 'f'); g.e(6.5, 0.8, 1.8, 1.2, 'f'); g.e(11, 1, 2.2, 1.2, 'f')
    return g, P(o='#5a7048', h='#3a4a2c', y='#d8c040', f='#c8ccd4')


def siringa():  # siringa nanotech: liquido azzurro luminoso
    g = G(16)
    g.l(2, 13, 4, 11, 'm'); g.p(1, 14, 'm')                           # ago
    g.r(4, 8, 7, 4, 'w'); g.r(5, 9, 5, 2, 'c'); g.r(11, 9, 1, 2, 'm'); g.r(12, 8, 1, 4, 'm')
    g.r(13, 9, 2, 2, 'm'); g.p(14, 8, 'm'); g.p(14, 11, 'm')           # stantuffo
    g.p(6, 8, 'm'); g.p(8, 8, 'm'); g.p(10, 8, 'm')
    g.p(3, 7, 'c'); g.p(2, 6, 'c'); g.p(4, 6, 'c')                     # scintille
    return g, P(c='#40e8ff')


def greco():  # fuoco greco: anfora con fiamma verde a goccia
    g = G(16)
    g.e(8, 11, 5, 4, 'a'); g.r(7, 6, 3, 2, 'a'); g.r(6, 5, 5, 1, 'b'); g.r(5, 11, 6, 1, 'b'); g.r(6, 14, 4, 1, 'b')
    g.p(3, 8, 'a'); g.p(2, 9, 'a'); g.p(3, 10, 'a'); g.p(12, 8, 'a'); g.p(13, 9, 'a'); g.p(12, 10, 'a')
    g.r(6, 9, 1, 3, 'h')
    g.r(7, 2, 3, 3, 'g'); g.r(8, 1, 1, 1, 'g'); g.p(8, 0, 'g'); g.p(6, 3, 'g'); g.p(10, 3, 'g'); g.r(8, 3, 1, 2, 'y')
    return g, P(a='#a8683a', b='#6a3e22', g='#30d860', y='#e0ffb0', h='#d09060')


def plasma():  # coltellino a plasma: manico + lama luminosa
    g = G(16)
    g.r(2, 10, 5, 3, 'd'); g.r(2, 10, 1, 3, 's'); g.p(4, 11, 'p'); g.p(6, 11, 's')
    g.l(7, 11, 13, 4, 'p'); g.l(7, 10, 13, 3, 'p'); g.l(8, 10, 13, 4, 'w')
    g.p(13, 2, 'w'); g.p(14, 3, 'p'); g.p(12, 3, 'p')
    return g, P(p='#ff58e8')


def oplita():  # scudo d'oplita: bronzo con lambda
    g = G(16)
    g.e(8, 8, 7, 7, 'b'); g.e(8, 8, 5.4, 5.4, 'a'); g.e(8, 8, 1.6, 1.6, 'b')
    g.l(8, 4, 5, 12, 'r'); g.l(8, 4, 11, 12, 'r')                      # lambda
    g.p(8, 3, 'r')
    for x, y in ((2, 8), (14, 8), (8, 2), (8, 14)):
        g.p(x, y, 'h')
    return g, P(b='#8a5a2a', a='#c8964a', r='#7a2418', h='#f0d890')


def mina():  # mina: disco con anello rosso, luce centrale e borchie
    g = G(16)
    g.e(8, 8, 7, 7, 'd'); g.e(8, 8, 5.6, 5.6, 'r'); g.e(8, 8, 4.4, 4.4, 's'); g.e(8, 8, 2.4, 2.4, 'k')
    g.p(8, 8, 'l'); g.p(7, 7, 'l'); g.p(8, 7, 'l')
    for x, y in ((8, 1), (8, 14), (1, 8), (14, 8)):
        g.p(x, y, 'w')
    g.p(3, 3, 'w'); g.p(12, 3, 'w'); g.p(3, 12, 'w'); g.p(12, 12, 'w')
    return g, P(r='#d03030', l='#ff7060')


def catapulta():  # catapulta tascabile
    g = G(16)
    g.r(2, 12, 12, 2, 'a'); g.r(3, 14, 2, 1, 'd'); g.r(11, 14, 2, 1, 'd')
    g.l(4, 12, 7, 6, 'a'); g.l(11, 12, 8, 6, 'a'); g.r(6, 6, 4, 1, 'b')
    g.l(8, 6, 12, 2, 'b'); g.l(9, 6, 13, 2, 'b')                       # braccio
    g.e(13, 2, 2, 2, 'x')                                              # masso
    g.e(3.5, 11, 1.5, 1.5, 'x'); g.p(2, 8, 'f')
    return g, P(a='#8a5e34', b='#c89a5a', d='#3a2a1a', x='#8a8a88', f='#6a4a2a')


def ariete():  # ariete d'assedio su ruote: tronco con testa di ferro a punta
    g = G(16)
    g.r(0, 6, 11, 4, 'a'); g.r(0, 6, 11, 1, 'b'); g.r(0, 9, 11, 1, 'e'); g.p(2, 8, 'e'); g.p(5, 7, 'e')
    g.r(7, 5, 1, 6, 'm'); g.r(9, 5, 1, 6, 'm')                                  # fasce di ferro
    g.r(11, 5, 3, 6, 'm'); g.r(11, 5, 3, 1, 'w'); g.r(14, 6, 1, 4, 'm'); g.p(15, 7, 'w'); g.p(15, 8, 'w')
    g.p(12, 8, 'd')
    g.e(3, 12, 2, 2, 'd'); g.p(3, 12, 'b'); g.e(9, 12, 2, 2, 'd'); g.p(9, 12, 'b')
    g.r(1, 3, 10, 1, 'e'); g.p(2, 4, 'e'); g.p(2, 5, 'e'); g.p(9, 4, 'e'); g.p(9, 5, 'e')   # telaio
    return g, P(a='#8a5a30', b='#c08850', e='#5a3a1e', d='#2a1c12')


# ------------------------------------------------------------------ jackpot (icone)
def drone_ic():
    g = G(16)
    g.r(6, 6, 4, 4, 'm'); g.r(7, 7, 2, 2, 'e')
    g.l(2, 3, 6, 6, 'd'); g.l(13, 3, 9, 6, 'd'); g.l(2, 12, 6, 9, 'd'); g.l(13, 12, 9, 9, 'd')
    for x, y in ((1, 3), (14, 3), (1, 12), (14, 12)):
        g.r(x - 1 if x < 8 else x, y - 1, 2, 2, 'w')
    return g, P(e='#ff9040')


def golem_ic():
    g = G(16)
    g.r(4, 3, 8, 6, 'x'); g.r(5, 9, 6, 4, 'x'); g.r(2, 5, 2, 6, 'z'); g.r(12, 5, 2, 6, 'z')
    g.r(5, 13, 2, 2, 'z'); g.r(9, 13, 2, 2, 'z'); g.r(5, 5, 2, 1, 'e'); g.r(9, 5, 2, 1, 'e')
    g.r(5, 3, 8, 1, 'h'); g.p(7, 8, 'z'); g.p(9, 7, 'z')
    return g, P(x='#8a8878', z='#5e5c52', h='#b4b2a0', e='#ffb040')


def carro_ic():
    g = G(16)
    g.r(2, 6, 10, 4, 'a'); g.r(2, 6, 10, 1, 'b'); g.e(5, 12, 2.4, 2.4, 'd'); g.e(5, 12, 1, 1, 'b')
    g.e(11, 12, 2.4, 2.4, 'd'); g.e(11, 12, 1, 1, 'b'); g.l(8, 5, 14, 3, 'm'); g.p(14, 2, 'w')
    return g, P(a='#8a5a30', b='#c89a5a', d='#2a1c12')


def tank_ic():  # carrarmato di lato: cingoli con ruote, scafo, torretta, cannone
    g = G(16)
    g.r(1, 10, 14, 4, 'd'); g.e(2, 12, 2, 2, 'd'); g.e(14, 12, 2, 2, 'd')
    for x in (3, 6, 9, 12):
        g.e(x + 0.5, 12, 1.4, 1.4, 's'); g.p(x, 12, 'k')
    g.r(2, 7, 12, 3, 'g'); g.r(2, 7, 12, 1, 'h'); g.p(1, 9, 'g'); g.p(14, 9, 'g')
    g.r(5, 4, 6, 3, 'g'); g.r(5, 4, 6, 1, 'h'); g.r(11, 5, 5, 1, 'k'); g.r(11, 5, 5, 1, 's'); g.p(15, 5, 'k')
    g.p(7, 5, 'k')
    return g, P(g='#5a7a48', h='#86a26c', d='#2e322c', s='#8a8e86', k='#1c201a')


def ufo_ic():
    g = G(16)
    g.e(8, 9, 7, 3, 'm'); g.e(8, 8, 3.5, 3, 'c'); g.e(8, 10, 5, 1.5, 's')
    g.p(3, 11, 'y'); g.p(8, 12, 'y'); g.p(13, 11, 'y'); g.l(5, 13, 3, 15, 'c')
    return g, P(c='#60f0ff', y='#ffe060')


# ------------------------------------------------------------------ oggetti inutili
def tostapane():
    g = G(16)
    g.r(2, 6, 12, 7, 'm'); g.r(2, 6, 12, 1, 'w'); g.r(2, 12, 12, 1, 's')
    g.r(4, 4, 3, 2, 'k'); g.r(9, 4, 3, 2, 'k'); g.r(4, 4, 3, 1, 'o'); g.r(9, 4, 3, 1, 'o')   # fessure con fiamma
    g.r(13, 8, 2, 1, 'k'); g.p(15, 8, 'w'); g.r(3, 13, 2, 1, 'k'); g.r(11, 13, 2, 1, 'k')
    g.p(5, 2, 'o'); g.p(10, 1, 'o'); g.p(10, 2, 'y')
    return g, P(o='#ff7a30', y='#ffd060')


def racchetta():
    g = G(16)
    g.e(10, 5, 4.5, 4.5, 'r'); g.e(10, 5, 3.2, 3.2, 'n')
    g.l(7, 8, 3, 12, 'r'); g.r(2, 12, 2, 3, 'd')
    for i in (8, 10, 12): g.p(i, 4, 'r'); g.p(i, 6, 'r')
    g.p(14, 12, 'y'); g.p(13, 13, 'y'); g.p(14, 13, 'y')
    return g, P(r='#c8c8d0', n='#5a7a4a', d='#2a2a30', y='#d8e850')


def ombrello():  # ombrello aperto con manico a gancio
    g = G(16)
    g.e(8, 8, 7.5, 6.5, 'a'); g.r(0, 8, 16, 8, None)
    for x in (0, 3, 6, 9, 12):
        g.e(x + 2, 8.2, 2, 1.6, 'a')                                           # lembi a festone
    g.r(5, 2, 2, 6, 'b'); g.r(10, 3, 1, 5, 'b'); g.l(8, 1, 8, 8, 'b'); g.r(1, 7, 14, 1, 'c')
    g.r(8, 9, 1, 5, 'w'); g.r(8, 14, 1, 1, 'w'); g.r(7, 15, 1, 1, 'w'); g.p(6, 14, 'w')
    g.p(8, 0, 'w')
    return g, P(a='#c83850', b='#f08098', c='#7a1e30', w='#d8b070')


def pentola():
    g = G(16)
    g.e(8, 9, 5.5, 4.5, 'm'); g.r(3, 5, 10, 2, 'm'); g.r(2, 5, 12, 1, 'w')
    g.r(0, 8, 3, 2, 'd'); g.r(13, 8, 3, 2, 'd'); g.r(6, 3, 4, 2, 's'); g.p(8, 2, 'd')
    g.r(5, 10, 6, 1, 's'); g.p(5, 8, 'w'); g.p(6, 7, 'w')
    return g, P()


def mazza():
    g = G(16)
    g.l(2, 14, 10, 6, 'a'); g.l(3, 14, 11, 6, 'a'); g.p(1, 15, 'd'); g.p(2, 15, 'd')
    g.l(10, 4, 14, 8, 'b'); g.l(9, 5, 13, 9, 'b'); g.l(10, 5, 14, 9, 'b'); g.l(11, 4, 15, 8, 'w')
    g.p(12, 6, 'r')
    return g, P(a='#b88a50', b='#d8d8d0', d='#3a2a1a', r='#c04040')


def frullatore():  # frullatore: brocca di vetro, coperchio, base con pulsante
    g = G(16)
    g.l(4, 3, 5, 10, 'c'); g.r(5, 3, 7, 7, 'c'); g.l(12, 3, 11, 10, 'c'); g.r(5, 3, 1, 6, 'w')
    g.r(4, 1, 8, 2, 'd'); g.r(7, 0, 2, 1, 'd')
    g.r(7, 5, 2, 5, 'm'); g.l(5, 7, 7, 9, 'm'); g.l(11, 7, 9, 9, 'm')
    g.r(5, 10, 6, 1, 'd'); g.r(4, 11, 8, 4, 'k'); g.r(4, 11, 8, 1, 's'); g.p(8, 13, 'r'); g.p(6, 13, 'r'); g.p(10, 13, 'r')
    return g, P(c='#78c8e8', d='#2a2e3a', r='#e04040', k='#3a3e4c')


def batteria():
    g = G(16)
    g.r(5, 3, 6, 11, 'a'); g.r(5, 3, 6, 3, 'k'); g.r(7, 1, 2, 2, 'm'); g.r(5, 7, 6, 1, 'y')
    g.p(8, 10, 'y'); g.p(7, 11, 'y'); g.p(8, 11, 'y'); g.p(9, 12, 'y')     # fulmine
    g.p(6, 9, 'h'); g.p(6, 10, 'h')
    return g, P(a='#38a850', h='#78e890', y='#ffe060')


def cuscino():  # cuscino con nappe agli angoli e bottone
    g = G(16)
    g.r(3, 4, 10, 8, 'a'); g.r(4, 3, 8, 10, 'a'); g.r(4, 4, 8, 1, 'b'); g.r(4, 4, 1, 8, 'b')
    g.l(8, 5, 8, 11, 'd'); g.l(5, 8, 11, 8, 'd'); g.p(8, 8, 'c')
    for x, y in ((1, 2), (13, 2), (1, 12), (13, 12)):
        g.r(x, y, 2, 2, 'c'); g.p(x if x < 8 else x + 1, y + 2, 'c')
    return g, P(a='#b0508a', b='#e090c0', c='#f0d050', d='#7a3060')


def lampadario():  # lampadario a candele con cristalli
    g = G(16)
    g.r(8, 0, 1, 4, 'm')
    for x in (2, 5, 10, 13):
        g.r(x, 5, 1, 3, 'w'); g.p(x, 4, 'f'); g.p(x, 3, 'y')
    g.r(7, 3, 3, 3, 'o'); g.l(2, 8, 5, 10, 'o'); g.r(5, 10, 6, 1, 'o'); g.l(13, 8, 10, 10, 'o'); g.r(2, 8, 12, 1, 'o')
    g.r(8, 6, 1, 4, 'o')
    for x, y in ((5, 12), (8, 12), (11, 12), (7, 14), (9, 14)):
        g.p(x, y, 'c'); g.p(x, y - 1, 'c')
    return g, P(o='#d8a840', w='#f0f0f0', f='#ff9030', y='#ffe880', c='#a0e8ff')


def aspirapolvere():
    g = G(16)
    g.e(7, 11, 6, 3.4, 'r'); g.e(7, 10, 5, 2.6, 'h'); g.r(10, 4, 2, 6, 'm'); g.r(11, 2, 4, 2, 'm')
    g.r(13, 1, 3, 3, 's'); g.e(4, 13, 1.6, 1.6, 'k'); g.e(10, 13, 1.6, 1.6, 'k'); g.r(5, 9, 3, 1, 'w')
    return g, P(r='#c83a2a', h='#e86a58')



# ------------------------------------------------------------------ altri oggetti inutili
def mattarello():
    g = G(16)
    g.r(4, 6, 8, 4, 'a'); g.r(4, 6, 8, 1, 'b'); g.r(4, 9, 8, 1, 'e'); g.r(1, 7, 3, 2, 'a'); g.r(12, 7, 3, 2, 'a')
    g.p(1, 7, 'b'); g.p(14, 7, 'b'); g.p(6, 7, 'e'); g.p(9, 8, 'e'); g.p(1, 6, 'e')
    return g, P(a='#c8a060', b='#e8c888', e='#8a6838')


def padella():
    g = G(16)
    g.e(6, 8, 5.5, 5.5, 'd'); g.e(6, 8, 4.2, 4.2, 'k'); g.e(6, 8, 3.4, 3.4, 'd'); g.r(10, 7, 6, 2, 'h'); g.p(9, 7, 'd'); g.p(9, 8, 'd')
    g.p(4, 6, 's'); g.p(5, 5, 's'); g.p(15, 7, 'w'); g.p(15, 8, 'w')
    return g, P(d='#4a4e5a', k='#262830', h='#7a5030', s='#9aa0b0')


def ferrostiro():
    g = G(16)
    g.r(2, 11, 12, 3, 'm'); g.r(2, 11, 12, 1, 'w'); g.r(4, 6, 8, 5, 'm'); g.r(4, 6, 8, 1, 'w')
    g.r(5, 3, 6, 3, 'h'); g.r(7, 3, 2, 1, 'k'); g.r(12, 12, 2, 2, 'o'); g.p(3, 13, 'o'); g.p(6, 13, 'o'); g.p(9, 13, 'o')
    g.r(2, 14, 12, 1, 'k')
    return g, P(h='#2a2e3a', o='#ff7a30')


def phon():
    g = G(16)
    g.r(3, 4, 9, 5, 'r'); g.r(3, 4, 9, 1, 'h'); g.r(11, 3, 3, 7, 'd'); g.r(12, 4, 1, 5, 'k')
    g.r(5, 9, 3, 6, 'b'); g.p(4, 6, 'w'); g.p(5, 6, 'w')
    g.p(15, 5, 'o'); g.p(15, 7, 'o'); g.p(14, 6, 'y')
    return g, P(r='#b83850', h='#e86880', b='#2a2a32', o='#ff9040', y='#ffe060')


def chitarra():
    g = G(16)
    g.e(5, 11, 4, 3.6, 'r'); g.e(8, 8.5, 3, 2.6, 'r'); g.p(5, 11, 'k'); g.r(6, 10, 3, 1, 'm'); g.r(4, 12, 3, 1, 'm')
    g.l(8, 8, 14, 2, 'w'); g.l(9, 8, 15, 2, 'w'); g.r(13, 0, 3, 3, 'k'); g.p(14, 1, 'm')
    g.p(3, 9, 'h'); g.p(4, 8, 'h')
    return g, P(r='#c83a2a', h='#f08a70', w='#8a5a30', k='#2a2028')


def asta_selfie():
    g = G(16)
    g.l(2, 14, 10, 6, 'm'); g.l(3, 14, 11, 6, 'm'); g.l(10, 6, 13, 3, 'd')
    g.r(11, 0, 4, 6, 'k'); g.r(12, 1, 2, 4, 'c'); g.p(12, 1, 'w')
    g.r(1, 13, 3, 2, 'b')
    return g, P(m='#aab0c0', d='#6a7080', k='#2a2e3a', c='#40a0d0', w='#e0f4ff', b='#3a3a44')


def casco_moto():
    g = G(16)
    g.e(8, 8, 7, 6.5, 'a'); g.r(0, 11, 16, 5, None); g.r(1, 10, 14, 3, 'a'); g.r(9, 5, 7, 5, 'v'); g.r(10, 6, 5, 3, 'k')
    g.p(11, 6, 'w'); g.r(2, 7, 6, 1, 'h'); g.r(1, 13, 14, 1, 'd')
    return g, P(a='#c83a2a', h='#ff7a60', v='#2a2e3a', k='#10141c', w='#9aaac0', d='#7a2018')


def giubbotto():
    g = G(16)
    g.r(4, 3, 8, 11, 'a'); g.r(0, 4, 4, 8, 'a'); g.r(12, 4, 4, 8, 'a'); g.r(7, 3, 2, 11, 'z'); g.r(0, 4, 4, 1, 'h'); g.r(12, 4, 4, 1, 'h')
    g.r(5, 8, 2, 1, 'm'); g.r(9, 8, 2, 1, 'm'); g.p(1, 6, 'm'); g.p(14, 6, 'm'); g.p(1, 9, 'm'); g.p(14, 9, 'm'); g.r(6, 2, 4, 1, 'h')
    return g, P(a='#3a3a44', h='#5a5a68', z='#a0a4b0', m='#d8dce8')


def stivali():
    g = G(16)
    g.r(2, 2, 5, 9, 'a'); g.r(2, 10, 8, 4, 'a'); g.r(9, 2, 5, 9, 'a'); g.r(9, 10, 6, 4, 'a')
    g.r(2, 2, 5, 1, 'h'); g.r(9, 2, 5, 1, 'h'); g.r(2, 13, 8, 2, 'k'); g.r(9, 13, 6, 2, 'k'); g.p(3, 4, 'w'); g.p(10, 4, 'w')
    return g, P(a='#e8c030', h='#fff080', k='#2a2a30', w='#fff8c0')


def skateboard():
    g = G(16)
    g.r(1, 7, 14, 2, 'a'); g.r(0, 6, 2, 2, 'a'); g.r(14, 6, 2, 2, 'a')
    g.r(1, 7, 14, 1, 'h'); g.p(7, 8, 'k'); g.p(8, 8, 'k')
    for x in (3, 11):
        g.r(x, 9, 2, 1, 'm'); g.e(x + 1, 11.5, 1.8, 1.8, 'w'); g.p(x + 1, 11, 'k')
    return g, P(a='#38a8c8', h='#80e0f8', k='#202830', m='#9aa0b0', w='#f0e0b0')


def secchio():  # secchio: tronco di cono con bordo e manico ad arco
    g = G(16)
    for i, y in enumerate(range(5, 15)):
        g.r(2 + i // 4, y, 12 - 2 * (i // 4), 1, 'm')
    g.r(1, 4, 14, 2, 'w'); g.r(2, 4, 12, 1, 'k')
    g.r(5, 8, 1, 6, 'h'); g.r(3, 9, 10, 1, 'd'); g.r(4, 12, 8, 1, 'd')
    g.l(2, 4, 4, 1, 'a'); g.l(13, 4, 11, 1, 'a'); g.r(5, 0, 6, 1, 'a')
    return g, P(m='#8a929e', w='#d0d6de', d='#4a5060', h='#b0b8c4', k='#2a2e3a', a='#3a3e4c')


def caffe():
    g = G(16)
    g.r(3, 7, 8, 7, 'w'); g.r(3, 7, 8, 1, 'h'); g.r(4, 8, 6, 1, 'c'); g.r(11, 8, 3, 1, 'w'); g.r(13, 9, 1, 3, 'w'); g.r(11, 12, 3, 1, 'w')
    g.r(2, 14, 10, 1, 'w'); g.p(5, 4, 's'); g.p(6, 3, 's'); g.p(5, 2, 's'); g.p(8, 4, 's'); g.p(9, 3, 's'); g.p(8, 2, 's')
    return g, P(w='#f0ece0', h='#fffaf0', c='#5a3a22', s='#c8ccd4')


def energy():
    g = G(16)
    g.r(5, 3, 6, 11, 'a'); g.r(5, 3, 6, 1, 'm'); g.r(5, 13, 6, 1, 'm'); g.r(6, 2, 4, 1, 'm'); g.r(7, 1, 2, 1, 'm')
    g.p(9, 5, 'y'); g.p(8, 6, 'y'); g.p(7, 7, 'y'); g.p(8, 7, 'y'); g.p(9, 8, 'y'); g.p(8, 9, 'y'); g.p(7, 10, 'y')
    g.r(5, 4, 1, 8, 'h')
    return g, P(a='#1a3a8a', h='#4a78d8', m='#b0b8c8', y='#d8ff40')


def candeliere():
    g = G(16)
    g.r(7, 1, 2, 3, 'w'); g.p(7, 0, 'y'); g.p(8, 0, 'o'); g.r(2, 6, 12, 1, 'a'); g.l(7, 4, 2, 6, 'a'); g.l(8, 4, 13, 6, 'a')
    g.r(2, 3, 1, 3, 'w'); g.r(13, 3, 1, 3, 'w'); g.p(2, 2, 'y'); g.p(13, 2, 'y'); g.r(7, 7, 2, 6, 'a'); g.r(4, 13, 8, 2, 'a'); g.r(5, 12, 6, 1, 'b')
    return g, P(a='#c89a40', b='#e8c870', w='#f0e8d0', y='#ffe070', o='#ff8030')


JUNK_ITEMS = [tostapane, racchetta, ombrello, pentola, mazza, frullatore, batteria, cuscino, lampadario, aspirapolvere,
              mattarello, padella, ferrostiro, phon, chitarra, asta_selfie, casco_moto, giubbotto, stivali, skateboard, secchio, caffe, energy, candeliere]
USE_ITEMS = [fumo, siringa, greco, plasma, oplita, mina, catapulta, ariete]
JACK_ITEMS = [("drone", drone_ic), ("golem", golem_ic)]   # i mezzi usano lo sprite dall'alto (veh_*) anche come icona


# ------------------------------------------------------------------ mezzi, vista dall'alto, rivolti a DESTRA
def veh_carro():  # carro da guerra 40px: pianale largo (ci sta un eroe da 20px), ruote sporgenti, balista. nessun pilota visibile
    g = G(40)
    for y in (2, 31):                                                                                # ruote viste dall'alto
        g.r(11, y, 14, 7, 'd'); g.r(12, y + 1, 12, 5, 'c')
        for x in (13, 17, 21): g.r(x, y + 1, 2, 5, 'd')
        g.r(10, y + 3, 16, 1, 'k')
    g.r(8, 8, 24, 24, 'a'); g.r(8, 8, 24, 2, 'b'); g.r(8, 30, 24, 2, 'e')                            # pianale e sponde
    g.r(8, 8, 2, 24, 'b'); g.r(30, 8, 2, 24, 'b')
    for x in range(12, 29, 4): g.l(x, 11, x, 28, 'c')                                                # assi del pianale
    g.r(11, 11, 4, 6, 'f'); g.r(11, 23, 4, 6, 'f'); g.p(12, 13, 'w'); g.p(12, 25, 'w')               # casse
    g.r(1, 18, 7, 4, 'a'); g.r(0, 17, 2, 6, 'f'); g.r(3, 18, 1, 4, 'e')                              # timone
    g.r(32, 17, 3, 6, 'a'); g.r(35, 19, 4, 2, 'm'); g.p(39, 20, 'w'); g.r(36, 17, 1, 2, 'm'); g.r(36, 21, 1, 2, 'm')   # balista
    g.r(30, 17, 2, 6, 'e')
    return g, P(a='#8a5a30', b='#c89a5a', c='#5e3a1e', d='#2a1c12', e='#5a3a1e', f='#6a4a2a', k='#1a1008')


def veh_tank():  # carrarmato 40px: scafo chiuso 26x18, torretta grande, cingoli. nessun pilota visibile
    g = G(40)
    g.r(3, 3, 32, 8, 'd'); g.r(3, 29, 32, 8, 'd'); g.e(4, 7, 4, 4, 'd'); g.e(34, 7, 4, 4, 'd'); g.e(4, 33, 4, 4, 'd'); g.e(34, 33, 4, 4, 'd')
    for x in range(4, 35, 3):
        g.l(x, 4, x, 9, 'k'); g.l(x, 30, x, 35, 'k')
    g.r(4, 5, 30, 1, 's'); g.r(4, 31, 30, 1, 's')
    g.r(6, 11, 28, 18, 'g'); g.r(6, 11, 28, 2, 'h'); g.r(6, 27, 28, 2, 'e'); g.r(30, 14, 4, 12, 'e')   # scafo, prua corazzata
    g.r(9, 14, 4, 3, 'k'); g.r(9, 23, 4, 3, 'k'); g.r(14, 14, 1, 12, 'e')                                # griglie motore
    g.e(19, 20, 8, 8, 'e'); g.e(19, 20, 7, 7, 'h'); g.e(19, 20, 5.5, 5.5, 'g'); g.e(17, 18, 1.8, 1.8, 'h')  # torretta
    g.r(26, 18, 13, 4, 'k'); g.r(27, 18, 11, 1, 's'); g.r(36, 17, 3, 6, 'd')                             # cannone e freno di bocca
    return g, P(g='#5a6e4a', h='#7e9266', e='#3e4c34', d='#2e322c', k='#1c201a', s='#8a8e86')


def veh_ufo():  # mini-ufo 36px: disco con cupola opaca (dentro l'eroe non si vede)
    g = G(36)
    import math
    g.e(18, 18, 17.5, 17.5, 's'); g.e(18, 18, 15.5, 15.5, 'm'); g.e(18, 18, 12, 12, 'h'); g.e(18, 18, 9.5, 9.5, 'm')
    for i in range(12):
        a = i * math.pi / 6
        g.r(int(18 + math.cos(a) * 14) - 1, int(18 + math.sin(a) * 14) - 1, 2, 2, 'y')
    g.e(18, 18, 8, 8, 'd'); g.e(18, 18, 6.6, 6.6, 'c'); g.e(16, 16, 2.4, 2.4, 'w'); g.p(20, 19, 'h')
    g.r(30, 16, 5, 4, 'd'); g.r(34, 17, 2, 2, 'y')
    return g, P(s='#4a5062', m='#8a92a6', h='#b8c0d4', d='#2a3c4a', c='#3898b8', y='#ffe060', w='#d8f8ff')


# ------------------------------------------------------------------ alleati
def drone():  # drone da combattimento, 4 rotori visti dall'alto
    g = G(18)
    for cx, cy in ((3, 3), (14, 3), (3, 14), (14, 14)):
        g.e(cx, cy, 2.6, 2.6, 'r'); g.p(cx, cy, 'd')
    g.l(4, 4, 8, 8, 'd'); g.l(13, 4, 9, 8, 'd'); g.l(4, 13, 8, 9, 'd'); g.l(13, 13, 9, 9, 'd')
    g.r(6, 6, 6, 6, 'm'); g.r(7, 7, 4, 4, 's'); g.r(8, 8, 2, 2, 'e')
    g.r(11, 8, 4, 2, 'k')
    return g, P(r='#6a7488', d='#2a2e3a', e='#ff9040')


def golem():  # golem di pietra: massiccio, occhi accesi, venature
    g = G(22)
    g.r(7, 17, 3, 4, 'z'); g.r(12, 17, 3, 4, 'z'); g.r(6, 20, 5, 1, 'd'); g.r(12, 20, 5, 1, 'd')   # piedi
    g.r(5, 8, 12, 10, 'x'); g.r(5, 8, 12, 2, 'h'); g.r(7, 12, 8, 1, 'z'); g.p(9, 15, 'z'); g.p(13, 14, 'z')
    g.r(1, 8, 4, 10, 'x'); g.r(17, 8, 4, 10, 'x'); g.r(1, 17, 4, 3, 'z'); g.r(17, 17, 4, 3, 'z')     # braccia-pietra
    g.r(1, 8, 4, 1, 'h'); g.r(17, 8, 4, 1, 'h'); g.p(2, 12, 'z'); g.p(18, 11, 'z')
    g.r(7, 2, 8, 6, 'x'); g.r(7, 2, 8, 1, 'h'); g.r(8, 4, 2, 1, 'e'); g.r(12, 4, 2, 1, 'e'); g.r(9, 6, 4, 1, 'd')
    g.p(7, 1, 'm'); g.p(9, 1, 'm'); g.p(14, 1, 'm')                                                  # muschio
    g.p(11, 10, 'e'); g.p(10, 11, 'e')                                                               # cuore di brace
    return g, P(x='#8c8a7c', z='#5a584e', h='#b8b6a2', d='#34322c', e='#ffb040', m='#5a7a3a')


ITEMS = [("ch_" + f.__name__, f) for f in USE_ITEMS + JUNK_ITEMS] + [("ch_" + k, f) for k, f in JACK_ITEMS]
BIG = [("veh_carro", veh_carro), ("veh_tank", veh_tank), ("veh_ufo", veh_ufo), ("drone", drone), ("golem", golem)]

os.makedirs(OUT, exist_ok=True)
made = []
for name, fn in ITEMS + BIG:
    g, pal = fn()
    im = grade(S.render(g, pal, "B"), 0.85, 0.95)
    im.save(os.path.join(OUT, name + ".png"))
    made.append((name, im))
for k in ("carro", "tank", "ufo"):   # icona dei mezzi = sprite visto dall'alto
    im = dict(made)["veh_" + k]
    im.save(os.path.join(OUT, "ch_" + k + ".png"))
    made.append(("ch_" + k, im))
if PREV:
    from PIL import Image
    k = 8
    cols = 9
    cell = 36 * 1
    rows = (len(made) + cols - 1) // cols
    pv = Image.new("RGBA", (cols * cell * k // 2, rows * cell * k // 2), (40, 36, 48, 255))
    cw = cell * k // 2
    for i, (n, im) in enumerate(made):
        big = im.resize((im.width * k // 2 + 0, im.height * k // 2 + 0), Image.NEAREST)
        pv.alpha_composite(big, ((i % cols) * cw + (cw - big.width) // 2, (i // cols) * cw + (cw - big.height) // 2))
    pv.save(PREV)
print("ok", len(made))
