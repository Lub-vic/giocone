"""Scheletri ridisegnati (stesso motore a griglia di gothic.py, nessuna AI).
Uso: python skeletons.py <cartella_sprites>   (scrive skeleton.png e skel_archer.png)"""
import sys, os
OUT = sys.argv[1] if len(sys.argv) > 1 else "."
sys.argv = [sys.argv[0], os.path.join(OUT, "_tmp_sk")]
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gothic as GO
S = GO.S
G = S.G
try:
    os.rmdir(sys.argv[1])
except OSError:
    pass

PAL = dict(b='#d6cdaa', a='#8c846a', e='#0a0610', g='#ff4a28', m='#7c8296', w='#5a3c24', y='#b0903a', q='#3a2a1a', r='#a83030', k='#2a2432')


def body(g):
    # cranio con orbite, naso e denti
    g.e(10, 5.5, 3.3, 3.4, 'b')
    g.r(8, 4, 2, 3, 'e'); g.r(11, 4, 2, 3, 'e'); g.p(9, 6, 'g'); g.p(12, 6, 'g'); g.p(10, 6, 'e')
    g.r(8, 8, 5, 1, 'b'); g.p(9, 8, 'e'); g.p(11, 8, 'e')
    g.p(10, 9, 'a')
    # gabbia toracica: fondo scuro, clavicole, colonna, costole
    g.e(10, 13, 3.6, 4.0, 'k')
    g.r(6, 10, 9, 1, 'b')
    g.r(10, 10, 1, 7, 'a')
    g.r(7, 11, 7, 1, 'b'); g.r(8, 13, 5, 1, 'b'); g.r(8, 15, 5, 1, 'b')
    g.p(7, 12, 'b'); g.p(13, 12, 'b'); g.p(7, 14, 'a'); g.p(13, 14, 'a')
    # bacino e gambe
    g.r(8, 16, 5, 2, 'a'); g.p(9, 17, 'k'); g.p(11, 17, 'k')
    g.r(8, 18, 1, 2, 'b'); g.r(12, 18, 1, 2, 'b'); g.r(7, 19, 3, 1, 'b'); g.r(11, 19, 3, 1, 'b')


def skeleton():
    g = G()
    body(g)
    # braccio destro con spada
    g.r(15, 10, 1, 4, 'b'); g.r(16, 13, 1, 2, 'b')
    g.r(17, 3, 1, 12, 'm'); g.p(17, 2, 'm'); g.r(16, 15, 3, 1, 'y'); g.r(17, 16, 1, 2, 'w')
    # braccio sinistro con scudo tondo di legno rinforzato
    g.r(5, 10, 1, 3, 'b')
    g.e(3.5, 13.5, 3.5, 3.8, 'y'); g.e(3.5, 13.5, 2.6, 2.9, 'w'); g.r(3, 13, 2, 2, 'y'); g.p(3, 11, 'k'); g.p(4, 16, 'k')
    return g, PAL


def skel_archer():
    g = G()
    body(g)
    # arco a sinistra con corda
    g.l(4, 3, 1, 10, 'w'); g.l(1, 10, 4, 17, 'w'); g.l(4, 3, 4, 17, 'm')
    g.r(5, 10, 1, 3, 'b'); g.r(4, 12, 2, 1, 'b')
    # braccio destro piegato e faretra con frecce
    g.r(15, 10, 1, 3, 'b'); g.r(14, 12, 2, 1, 'b')
    g.r(15, 5, 2, 6, 'q'); g.p(15, 4, 'r'); g.p(16, 4, 'r'); g.p(16, 3, 'r')
    return g, PAL


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for name, fn in (("skeleton", skeleton), ("skel_archer", skel_archer)):
        g, pal = fn()
        im = S.render(g, pal, "B")
        im = GO.grade(im, 0.62, 0.86)
        im.save(os.path.join(OUT, name + ".png"))
