"""Alberi grandi (2x) a codice, vista dall'alto: tbig_dead_0-9 (rami a stella) e tbig_sick_0-9 (chioma tonda).
Uso: python bigtrees.py <cartella_uscita>"""
import sys, os
out = sys.argv[1]
os.makedirs(out, exist_ok=True)
here = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, here)
sys.argv = ["topdown.py", out]
src = open(os.path.join(here, "topdown.py"), encoding="utf-8").read().rstrip()
assert src.endswith("main()")
ns = {"__name__": "td", "__file__": os.path.join(here, "topdown.py")}
exec(compile(src[:-6], "topdown.py", "exec"), ns)
canopy, save, SICK, GREEN = ns["canopy"], ns["save"], ns["SICK"], ns["GREEN"]
import random, math
from PIL import Image, ImageDraw
outline, shadowed, new, hexc = ns["outline"], ns["shadowed"], ns["new"], ns["hexc"]
PAL = [hexc(c) for c in ("#100c16", "#201a1c", "#2e2c24", "#3c4632", "#52684a")]


def clump_canopy(seed, W=92):
    rnd = random.Random(seed)
    im = new(W, W)
    px = im.load()
    cx = cy = W / 2
    clumps = []
    for k in range(rnd.randint(16, 22)):
        a = rnd.uniform(0, math.tau)
        rr = rnd.uniform(0, W * .30) ** 1.0
        clumps.append((cx + math.cos(a) * rr, cy + math.sin(a) * rr * .92, rnd.uniform(W * .10, W * .17)))
    clumps.sort(key=lambda c: c[1])
    for bx, by, r in clumps:
        base = rnd.choice([1, 2, 2, 3])
        for y in range(int(by - r) - 1, int(by + r) + 2):
            for x in range(int(bx - r) - 1, int(bx + r) + 2):
                if not (1 <= x < W - 1 and 1 <= y < W - 1):
                    continue
                dx, dy = (x - bx) / r, (y - by) / r
                dd = dx * dx + dy * dy
                if dd > 1:
                    continue
                lit = -(dx * .6 + dy * .8)  # luce dall'alto-sinistra
                v = base + lit * 1.3 + (rnd.random() - .5) * .7 - dd * .5
                px[x, y] = PAL[max(0, min(4, int(round(v))))] + (255,)
    return shadowed(outline(im), 5, 6, 80)


for i in range(10):
    save(canopy(i * 7 + 21, GREEN, 90, dead=True, bw=6), f"tbig_dead_{i}")
    save(clump_canopy(i * 5 + 29), f"tbig_sick_{i}")
print("ok")
