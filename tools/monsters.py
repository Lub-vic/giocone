"""Pipistrello, zombie, ghoul e spettro ridisegnati (stesso motore a griglia di gothic.py, nessuna AI).
Uso: python monsters.py <cartella_sprites>"""
import sys, os
OUT = sys.argv[1] if len(sys.argv) > 1 else "."
sys.argv = [sys.argv[0], os.path.join(OUT, "_tmp_mo")]
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gothic as GO
S = GO.S
G = S.G
try:
    os.rmdir(sys.argv[1])
except OSError:
    pass


def wing(g, side):
    """ala a membrana con dita e bordo a festoni; side=-1 sinistra, +1 destra"""
    def X(x):
        return x if side < 0 else 19 - x
    # membrana: per ogni colonna, da bordo alto a bordo festonato
    top = {7: 9, 6: 8, 5: 7, 4: 6, 3: 5, 2: 5, 1: 4, 0: 4}
    bot = {7: 12, 6: 13, 5: 12, 4: 14, 3: 12, 2: 13, 1: 11, 0: 8}
    for x in range(8):
        for y in range(top[x], bot[x] + 1):
            g.p(X(x), y, 'c')
    # dita
    g.l(X(7), 9, X(0), 4, 'k'); g.l(X(7), 10, X(1), 11, 'k'); g.l(X(7), 10, X(4), 14, 'k'); g.l(X(7), 10, X(3), 12, 'k')
    g.p(X(0), 4, 'k')


def bat():
    g = G()
    wing(g, -1); wing(g, 1)
    g.e(10, 11.5, 2.6, 3.6, 'b')                  # corpo
    g.p(9, 14, 'b'); g.p(10, 15, 'b'); g.p(11, 14, 'b')   # coda
    g.e(10, 7.5, 2.8, 2.6, 'b')                   # testa
    g.p(8, 4, 'b'); g.p(8, 3, 'b'); g.p(12, 4, 'b'); g.p(12, 3, 'b'); g.p(9, 4, 'b'); g.p(11, 4, 'b')   # orecchie
    g.p(9, 7, 'g'); g.p(11, 7, 'g')              # occhi rossi
    g.p(9, 9, 't'); g.p(11, 9, 't'); g.p(10, 9, 'k')   # zanne
    return g, dict(c='#5a3a78', b='#3a2450', k='#1a0e28', g='#ff3040', t='#f4efe2')


def zombie():
    g = G()
    # gambe (una piu' storpia), piedi nudi
    g.r(8, 15, 2, 4, 'p'); g.r(11, 15, 2, 3, 'p'); g.r(7, 19, 3, 1, 's'); g.r(11, 18, 3, 1, 's')
    g.p(8, 17, 'k'); g.p(12, 16, 'k')            # strappi
    # busto con camicia lacera e squarcio
    g.r(7, 9, 7, 6, 'c'); g.p(7, 15, 'c'); g.p(9, 15, 'c'); g.p(13, 14, 'c'); g.p(12, 15, 'c')   # orlo irregolare
    g.r(9, 11, 3, 3, 'm'); g.r(9, 12, 3, 1, 'b'); g.p(10, 13, 'b')   # ferita con costole
    # braccia tese in avanti/alto, con maniche strappate
    g.r(5, 9, 2, 2, 'c'); g.r(14, 9, 2, 2, 'c')
    g.r(4, 4, 2, 6, 's'); g.r(15, 4, 2, 6, 's')
    g.r(3, 3, 3, 2, 's'); g.r(15, 3, 3, 2, 's'); g.p(3, 2, 's'); g.p(17, 2, 's'); g.p(5, 2, 's'); g.p(15, 2, 's')
    # testa piegata, occhi infossati, bocca aperta
    g.e(10, 6, 3.2, 3.3, 's')
    g.r(7, 3, 3, 1, 'h'); g.p(7, 4, 'h')
    g.r(8, 5, 2, 2, 'e'); g.r(11, 5, 2, 2, 'e'); g.p(9, 6, 'y'); g.p(12, 6, 'y')
    g.r(9, 8, 3, 1, 'e'); g.p(9, 8, 't'); g.p(11, 8, 't')
    return g, dict(s='#7f9470', c='#52483a', p='#2e3040', m='#6e1c1c', b='#cfc7ac', e='#100a0e', y='#d8c030', t='#d8d2b8', h='#26201a', k='#14100e')


def ghoul():
    g = G()
    # gambe corte piegate
    g.r(8, 17, 2, 2, 'c'); g.r(11, 17, 2, 2, 'c'); g.r(7, 19, 3, 1, 'k'); g.r(11, 19, 3, 1, 'k')
    # busto curvo e smunto: costole e colonna
    g.e(10, 13.5, 3.6, 4.4, 'c')
    g.r(10, 10, 1, 7, 'd'); g.r(8, 12, 5, 1, 'd'); g.r(8, 14, 5, 1, 'd'); g.r(9, 16, 3, 1, 'd')
    # braccia lunghissime fino a terra, con artigli
    g.l(6, 10, 3, 17, 'c'); g.l(7, 10, 4, 17, 'c'); g.l(14, 10, 17, 17, 'c'); g.l(13, 10, 16, 17, 'c')
    g.p(2, 18, 'k'); g.p(3, 19, 'k'); g.p(4, 18, 'k'); g.p(15, 18, 'k'); g.p(16, 19, 'k'); g.p(17, 18, 'k'); g.p(3, 18, 'k'); g.p(16, 18, 'k')
    # testa grande, orecchie a punta, occhi gialli, bocca con zanne
    g.e(10, 7.5, 3.7, 3.3, 'c')
    g.p(6, 6, 'c'); g.p(5, 5, 'c'); g.p(14, 6, 'c'); g.p(15, 5, 'c'); g.p(6, 7, 'c'); g.p(14, 7, 'c')
    g.r(8, 6, 2, 2, 'e'); g.r(11, 6, 2, 2, 'e'); g.p(9, 7, 'g'); g.p(12, 7, 'g')
    g.r(8, 9, 5, 2, 'e'); g.p(8, 9, 't'); g.p(10, 9, 't'); g.p(12, 9, 't'); g.p(9, 10, 't'); g.p(11, 10, 't')
    return g, dict(c='#7a8474', d='#4a5248', k='#d4d8c4', e='#0c080e', g='#f0d030', t='#f2eede')


def wraith():
    g = G()
    # falce: asta e lama curva
    g.r(16, 1, 1, 19, 'w')
    g.l(16, 1, 11, 1, 'm'); g.l(11, 1, 8, 4, 'm'); g.l(16, 2, 11, 2, 'm'); g.l(11, 2, 9, 4, 'm'); g.l(8, 4, 8, 6, 'm'); g.p(7, 6, 'm')
    # veste a brandelli che sfuma in volute
    g.e(10, 12, 5.4, 7.0, 'c')
    g.r(5, 15, 2, 4, 'c'); g.r(8, 17, 2, 3, 'c'); g.r(11, 16, 2, 4, 'c'); g.r(13, 15, 2, 3, 'c'); g.p(6, 19, 'f'); g.p(9, 20 if False else 19, 'f'); g.p(12, 19, 'f')
    g.r(9, 10, 3, 8, 'l')                         # piega centrale piu' chiara
    # cappuccio con volto vuoto e occhi luminosi
    g.e(10, 7, 4.4, 4.4, 'h')
    g.e(10, 8, 2.6, 2.7, 'e'); g.p(9, 8, 'g'); g.p(11, 8, 'g'); g.p(9, 9, 'g'); g.p(11, 9, 'g')
    g.p(10, 2, 'h'); g.p(10, 3, 'h')
    # mani scheletriche sull'asta
    g.r(14, 11, 2, 1, 'b'); g.r(14, 13, 2, 1, 'b'); g.p(15, 12, 'b')
    return g, dict(c='#4e6c9c', h='#28386a', l='#6c8cbc', e='#04060c', g='#9affff', m='#d6dcec', w='#4a3a2a', b='#cfc7ac', f='#3a5278')


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for name, fn in (("bat", bat), ("zombie", zombie), ("ghoul", ghoul), ("wraith", wraith)):
        g, pal = fn()
        im = S.render(g, pal, "B")
        im = GO.grade(im, 0.62, 0.86)
        im.save(os.path.join(OUT, name + ".png"))
