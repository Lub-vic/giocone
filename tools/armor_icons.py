"""Icone 16x16 dei pezzi d'armatura (grigio neutro: il gioco le tinge col colore del materiale).

Uso: python armor_icons.py <cartella_sprites>   ->  ai_testa.png, ai_torso.png, ai_gambe.png
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
G, S = ns["G"], ns["S"]
PAL = dict(m='#c8c8d0', k='#8a8a96', e='#1a1622', y='#b09040')


def testa():
    g = G(16)
    g.e(8, 8, 5.2, 5.6, 'm')
    g.r(3, 8, 11, 5, 'm')
    g.r(4, 8, 8, 1, 'e'); g.r(7, 9, 2, 3, 'e')
    g.r(8, 2, 1, 4, 'y')
    g.r(3, 12, 11, 1, 'k')
    return g


def torso():
    g = G(16)
    g.e(3.5, 5, 2.5, 2.2, 'k'); g.e(12.5, 5, 2.5, 2.2, 'k')
    g.r(4, 4, 8, 9, 'm'); g.e(8, 12.5, 4, 2.5, 'm')
    g.r(7, 5, 2, 7, 'k')
    g.r(5, 13, 6, 1, 'y')
    return g


def gambe():
    g = G(16)
    g.r(3, 2, 10, 2, 'y')
    g.r(4, 4, 3, 9, 'm'); g.r(9, 4, 3, 9, 'm')
    g.r(3, 12, 5, 2, 'k'); g.r(8, 12, 5, 2, 'k')
    g.r(5, 6, 1, 2, 'k'); g.r(10, 6, 1, 2, 'k')
    return g


for name, fn in (("ai_testa", testa), ("ai_torso", torso), ("ai_gambe", gambe)):
    S.render(fn(), PAL, "A").save(os.path.join(OUT, name + ".png"))
print("ok")
