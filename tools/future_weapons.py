"""Armi dal futuro (pistola, mitra, pompa, motosega, pistola laser, spada laser, lanciarazzi, fucile al plasma).
Disegnate in ASCII (di profilo, rivolte a destra) e convertite in:
  w_<fam>.png   icona 17x18 (inventario, bottino) con contorno e ombra
  hw_<fam>.png  arma in mano 24x24, ruotata con la bocca verso l'alto e l'impugnatura in basso (come le altre armi)
  ch_<id>.png   icona dell'evocazione (copia di w_)
Uso: python future_weapons.py <cartella_sprites> [--preview file.png]
"""
import os, sys
from PIL import Image

OUT = sys.argv[1] if len(sys.argv) > 1 else "."
PREV = sys.argv[sys.argv.index("--preview") + 1] if "--preview" in sys.argv else None

PAL = {
    'M': (214, 218, 230), 'm': (150, 156, 172), 'd': (84, 88, 104), 'b': (52, 52, 62),
    'w': (132, 86, 46), 'W': (84, 52, 28), 'r': (190, 58, 46), 'R': (120, 32, 30), 'o': (255, 150, 50),
    'y': (240, 210, 80), 'c': (70, 220, 250), 'C': (205, 252, 255), 'g': (90, 240, 120), 'G': (200, 255, 210),
    'p': (176, 96, 235), 'P': (230, 190, 255),
}
OUTLINE = (24, 18, 30, 255)

ART = {
    "pistol": ["",
               ".MMMMMMMMMMM.",
               ".mmmmmmmmmmmm",
               ".dddddddddddd",
               ".dd.bbd......",
               "...bbb.......",
               "...bbb.......",
               "...bbb......."],
    "smg": ["...........d....",
            ".MMMMMMMMMMMMmmm",
            "dmmmmmmmmmmmmmmm",
            "dddddddddddddd.m",
            "..........dd....",
            ".....bb...dd....",
            ".....bb...dd....",
            ".....bb...dd...."],
    "shotgun": [".......MMMMMMMMMM",
                "wwwwwddmmmmmmmmmm",
                "WWWWdddddddddddd.",
                ".WWW.bb..wwwww...",
                "..W..bb.........."],
    "chainsaw": [".bbbbbb..........",
                 "rrrrrrrr.d.d.d.d.d.d",
                 "rrRRrrrrMMMMMMMMMMMMm",
                 "rrrrrrrrmmmmmmmmmmmmm",
                 "rrrrrrrr.d.d.d.d.d.d",
                 ".bb.....",
                 ".bb....."],
    "laserpistol": ["..MMMMMMMMm.",
                    ".MmmmmmmMMcC",
                    ".mmccccmmmcC",
                    ".ddddddddd..",
                    "..bbb.dd....",
                    "..bbb.......",
                    "..bbb......."],
    "lightsaber": [".....ggggggggggg",
                   "bMMbbGGGGGGGGGGG",
                   ".....ggggggggggg"],
    "rocket": [".......d........",
               "dMMMMMMMMMMMMMrr",
               "dmmmmmmmmmmmmmmr",
               "dddddddddddddddo",
               "..bb..bb........",
               "..bb............"],
    "plasma": [".........pp.....",
               ".MMMMMMMMMMMMMMg",
               "dmmmmpppmmmmmmmg",
               "dddddpppddddddd.",
               ".....pp.bb......",
               "..........bb...."],
}

IDS = {"pistol": "pistola", "smg": "mitra", "shotgun": "pompa", "chainsaw": "motosega", "laserpistol": "laserpistol",
       "lightsaber": "spadalaser", "rocket": "bazooka", "plasma": "fucileplasma"}


def build(rows):
    w = max(len(r) for r in rows)
    h = len(rows)
    im = Image.new("RGBA", (w + 2, h + 2), (0, 0, 0, 0))
    px = im.load()
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            if ch in PAL:
                px[x + 1, y + 1] = PAL[ch] + (255,)
    src = im.copy()
    sp = src.load()
    for y in range(im.height):
        for x in range(im.width):
            if sp[x, y][3]:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < im.width and 0 <= ny < im.height and sp[nx, ny][3]:
                    px[x, y] = OUTLINE
                    break
    return im


def icon(im):
    c = Image.new("RGBA", (17, 18), (0, 0, 0, 0))
    ox, oy = (17 - im.width) // 2, (18 - im.height) // 2
    sh = Image.new("RGBA", im.size, (0, 0, 0, 0))
    a = im.split()[3].point(lambda v: 90 if v else 0)
    sh.putalpha(a)
    c.alpha_composite(sh, (ox + 1, oy + 1))
    c.alpha_composite(im, (ox, oy))
    return c


def held(im):
    r = im.rotate(90, expand=True)           # bocca verso l'alto
    c = Image.new("RGBA", (24, 24), (0, 0, 0, 0))
    c.alpha_composite(r, (12 - r.width // 2 + 1, 22 - r.height))
    # in mano le armi sono scure e sottili: abbassa leggermente la luce
    px = c.load()
    for y in range(24):
        for x in range(24):
            rr, gg, bb, aa = px[x, y]
            if aa and (rr, gg, bb, 255) != OUTLINE and max(rr, gg, bb) < 245:
                px[x, y] = (int(rr * .82), int(gg * .82), int(bb * .88), aa)
    return c


os.makedirs(OUT, exist_ok=True)
made = []
for fam, rows in ART.items():
    base = build(rows)
    ic = icon(base)
    ic.save(os.path.join(OUT, "w_%s.png" % fam))
    ic.save(os.path.join(OUT, "ch_%s.png" % IDS[fam]))
    hd = held(base)
    hd.save(os.path.join(OUT, "hw_%s.png" % fam))
    made += [ic, hd]
# mazza da baseball in mano (arma forgiata dagli oggetti evocati, non e' una vera arma da fuoco)
PAL['t'] = (216, 176, 112)
PAL['T'] = (160, 118, 64)
BAT = ["............tttt.",
       "..........ttttttt",
       "ddTTTTTTTtttttttt",
       "..........TTTTTTT",
       "............TTTT."]
held(build(BAT)).save(os.path.join(OUT, "hw_bat.png"))
if PREV:
    k = 8
    pv = Image.new("RGBA", (len(made) * 26 * k // 2 + 10, 26 * k), (40, 36, 48, 255))
    for i, im in enumerate(made):
        big = im.resize((im.width * k // 2 + 0, im.height * k // 2 + 0), Image.NEAREST)
        pv.alpha_composite(big, (i * 26 * k // 2 + 5, 10))
    pv.save(PREV)
print("ok", len(made))
