"""Eroi senza arma disegnata (corpo) + armi impugnate separate, per mostrare l'arma in uso.

Uso: python heroes_armed.py <cartella_sprites>
Scrive <nome>_b.png (corpo, 20x20) per le 4 classi e hw_<famiglia>.png (24x24, impugnatura in 12,18).
Gli sprite originali con l'arma (hero.png...) restano per i menu.
"""
import os, sys

OUT = sys.argv[1] if len(sys.argv) > 1 else "."
here = os.path.dirname(os.path.abspath(__file__))
src = open(os.path.join(here, "gothic.py"), encoding="utf-8").read()
src = src[:src.rindex("\nmain()")]
tmp = os.path.join(os.environ.get("TEMP", "."), "gothic_tmp")
os.makedirs(tmp, exist_ok=True)
sys.argv = [sys.argv[0], tmp]
ns = {"__file__": os.path.join(here, "gothic.py"), "__name__": "gothic_lib"}
exec(compile(src, "gothic.py", "exec"), ns)
G, S, grade = ns["G"], ns["S"], ns["grade"]


# ------------------------------------------------------------------ corpi (come gothic.py, senza arma)
def hero_b():
    g = G()
    g.e(10, 15.5, 5, 4.5, 'c')
    g.r(7, 17, 1, 2, 'c'); g.r(12, 17, 1, 2, 'c'); g.p(9, 19, 'c')
    g.e(10, 12.5, 3.6, 4.2, 'a')
    g.e(5.5, 10.5, 2.0, 2.2, 'a'); g.e(14.5, 10.5, 2.0, 2.2, 'a')
    g.p(5, 8, 'a'); g.p(15, 8, 'a')
    g.r(8, 13, 4, 1, 'y')
    g.e(10, 7.5, 3.0, 3.6, 'h')
    g.r(8, 8, 4, 1, 'e'); g.p(9, 8, 'g'); g.p(11, 8, 'g')
    g.r(9, 2, 2, 2, 'e'); g.p(10, 1, 'e')
    g.e(15.5, 13, 1.3, 1.3, 'a')                 # mano (guanto) che impugna
    return g, dict(c='#4a0e18', a='#2a2838', h='#34324a', e='#07040b', g='#d0481e', m='#9aa0b4', y='#7a5c20')


def necro_b():
    g = G()
    g.e(10, 15, 4.6, 5, 'c')
    g.r(6, 17, 1, 3, 'c'); g.r(13, 17, 1, 3, 'c'); g.r(9, 18, 2, 2, 'c')
    g.e(10, 8.5, 4.2, 5, 'h')
    g.e(10, 8.5, 2.4, 3.0, 'e'); g.p(9, 8, 'g'); g.p(11, 8, 'g')
    g.p(14, 11, 'f'); g.p(15, 12, 'f'); g.p(15, 13, 'f')   # mano ossuta
    return g, dict(c='#22123a', h='#1a0e2c', e='#050309', g='#5acc7a', w='#44301f', s='#b8b29c', f='#9a8e76')


def hunter_b():
    g = G()
    g.e(10, 14, 4.2, 5.5, 'c')
    g.e(10, 8, 6.4, 3.2, 'h')
    g.e(10, 7.5, 2.6, 2.4, 'k')
    g.r(9, 9, 2, 4, 'b'); g.p(10, 13, 'b')
    g.p(8, 8, 'g'); g.p(12, 8, 'g')
    g.r(4, 7, 2, 5, 'w')                         # faretra sulla schiena
    g.e(15, 13, 1.2, 1.2, 'w')                   # mano guantata
    return g, dict(c='#2a2a32', h='#1c1824', k='#0e0b12', b='#a8a088', g='#d0782a', w='#4a3420', m='#7a8090')


def cleric_b():
    g = G()
    g.e(10, 15.5, 5, 4.5, 'c'); g.r(6, 18, 1, 2, 'c'); g.r(13, 18, 1, 2, 'c')
    g.e(10, 12.5, 3.8, 4.4, 'w')
    g.e(5.5, 10.5, 2.0, 2.2, 'w'); g.e(14.5, 10.5, 2.0, 2.2, 'w')
    g.r(9, 11, 2, 4, 'y'); g.r(8, 12, 4, 1, 'y')
    g.e(10, 7.5, 3.0, 3.4, 'h'); g.e(10, 8, 1.8, 2.0, 'e'); g.p(9, 8, 'g'); g.p(11, 8, 'g')
    g.e(15.5, 13, 1.3, 1.3, 'w')
    return g, dict(c='#5a1220', w='#a8a4b8', y='#9a7420', h='#8a869c', e='#0a0610', g='#c8a850', n='#4a3420', m='#6a6a7c')


# ------------------------------------------------------------------ armi impugnate (verticali, impugnatura in 12,18)
WP = dict(m='#a8aec2', k='#6a7080', y='#8a6a24', n='#4a3420', w='#d8d0b0', v='#7a3ac8', g='#c080ff', s='#b8b29c', e='#050309')


def hw_sword():
    g = G(24)
    g.r(12, 5, 1, 10, 'm'); g.r(13, 6, 1, 9, 'k'); g.p(12, 4, 'm')
    g.r(10, 15, 5, 1, 'y')
    g.r(12, 16, 1, 3, 'n'); g.p(12, 19, 'y')
    return g


def hw_greatsword():
    g = G(24)
    g.r(11, 2, 2, 13, 'm'); g.r(13, 3, 1, 12, 'k'); g.p(11, 1, 'm'); g.p(12, 1, 'm'); g.p(12, 0, 'm')
    g.r(8, 15, 8, 1, 'y'); g.p(8, 14, 'y'); g.p(15, 14, 'y')
    g.r(12, 16, 1, 4, 'n'); g.p(11, 18, 'n'); g.r(11, 20, 3, 1, 'y')
    return g


def hw_spear():
    g = G(24)
    g.r(12, 4, 1, 19, 'n')
    g.p(12, 0, 'm'); g.r(11, 1, 3, 2, 'm'); g.p(12, 3, 'k'); g.p(13, 2, 'k')
    g.r(11, 4, 3, 1, 'y')
    return g


def hw_hammer():
    g = G(24)
    g.r(12, 7, 1, 14, 'n')
    g.r(9, 2, 7, 5, 'k'); g.r(9, 2, 7, 1, 'm'); g.r(9, 3, 1, 3, 'm')
    g.r(9, 6, 7, 1, 'y')
    g.p(12, 21, 'y')
    return g


def hw_dagger():
    g = G(24)
    g.r(12, 10, 1, 6, 'm'); g.r(13, 11, 1, 5, 'k'); g.p(12, 9, 'm')
    g.r(11, 16, 3, 1, 'y')
    g.r(12, 17, 1, 2, 'n'); g.p(12, 19, 'y')
    return g


def hw_bow():
    g = G(24)
    pts = [(12, 2), (13, 3), (14, 5), (15, 8), (15, 11), (15, 14), (14, 17), (13, 19), (12, 20)]
    for a, b in zip(pts, pts[1:]):
        g.l(a[0], a[1], b[0], b[1], 'n')
    g.l(12, 3, 12, 19, 'w')
    g.r(14, 10, 2, 3, 'y')
    return g


def hw_staff():
    g = G(24)
    g.r(12, 5, 1, 18, 'n')
    g.e(12.5, 3, 2.3, 2.3, 'v'); g.p(12, 2, 'g'); g.p(13, 3, 'g')
    g.r(11, 6, 3, 1, 'y')
    return g


def main():
    for name, fn in (("hero_b", hero_b), ("necro_b", necro_b), ("hunter_b", hunter_b), ("cleric_b", cleric_b)):
        g, pal = fn()
        im = grade(S.render(g, pal, "B"), 0.62, 0.86)
        im.save(os.path.join(OUT, name + ".png"))
    for fam, fn in (("sword", hw_sword), ("greatsword", hw_greatsword), ("spear", hw_spear), ("hammer", hw_hammer),
                    ("dagger", hw_dagger), ("bow", hw_bow), ("staff", hw_staff)):
        im = grade(S.render(fn(), WP, "B"), 0.78, 0.92)
        im.save(os.path.join(OUT, "hw_" + fam + ".png"))
    print("ok")


main()
