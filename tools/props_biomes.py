"""Oggetti di scena tipici di ogni bioma, VISTI DALL'ALTO, con gli stessi strumenti di topdown.py
(luce da alto-sinistra, contorno, ombra in basso a destra). Uso: python props_biomes.py <cartella_sprites> [--preview f.png]
"""
import os, sys, random

OUT = sys.argv[1] if len(sys.argv) > 1 else "."
PREV = sys.argv[sys.argv.index("--preview") + 1] if "--preview" in sys.argv else None
here = os.path.dirname(os.path.abspath(__file__))
src = open(os.path.join(here, "topdown.py"), encoding="utf-8").read()
src = src[:src.rindex("\nmain()")]
_argv = sys.argv
sys.argv = [sys.argv[0], os.path.join(os.environ.get("TEMP", "."), "td_tmp")]
ns = {"__file__": os.path.join(here, "topdown.py"), "__name__": "topdown_lib"}
exec(compile(src, "topdown.py", "exec"), ns)
sys.argv = _argv
new, shadowed, outline, C, ImageDraw = ns["new"], ns["shadowed"], ns["outline"], ns["C"], ns["ImageDraw"]


def fin(im, a=85):
    return shadowed(outline(im), 2, 3, a)


# ---------------------------------------------------------------- VILLAGGIO
def woodpile():  # catasta di legna: tronchetti visti di testa
    im = new(18, 12); d = ImageDraw.Draw(im)
    d.rectangle([0, 1, 17, 11], fill=C('#2e2018'))
    for row in range(2):
        for k in range(4):
            x, y = 1 + k * 4 + (2 if row else 0), 2 + row * 5
            if x > 14:
                continue
            d.ellipse([x, y, x + 3, y + 3], fill=C('#7a6244')); d.point((x + 1, y + 1), fill=C('#4a3626'))
    return fin(im)


def signpost():  # palo con due cartelli
    im = new(14, 14); d = ImageDraw.Draw(im)
    d.rectangle([6, 2, 7, 13], fill=C('#3a2a1c'))
    d.rectangle([0, 2, 9, 5], fill=C('#6a5034')); d.line([1, 3, 8, 3], fill=C('#2a1c12'))
    d.rectangle([5, 7, 13, 10], fill=C('#5a4430')); d.line([6, 8, 12, 8], fill=C('#2a1c12'))
    d.point((0, 2), fill=C('#8a7050'))
    return fin(im)


def pumpkins():  # tre zucche con foglie
    im = new(18, 14); d = ImageDraw.Draw(im)
    d.ellipse([7, 0, 17, 9], fill=C('#2e4a24'))
    for (x, y, r) in ((1, 4, 5), (8, 6, 4), (11, 1, 3)):
        d.ellipse([x, y, x + r * 2, y + r * 2 - 1], fill=C('#b0621e'))
        d.line([x + r, y, x + r, y + r * 2 - 2], fill=C('#7a3e12'))
        d.point((x + r, y), fill=C('#3a5a24'))
    return fin(im)


def broken_wheel():  # ruota di carro rotta a terra
    im = new(14, 14); d = ImageDraw.Draw(im)
    d.ellipse([0, 0, 13, 13], outline=C('#5a4430'), width=2)
    d.ellipse([5, 5, 8, 8], fill=C('#3a2a1c'))
    for (a, b) in (((6, 1), (6, 12)), ((1, 6), (12, 6)), ((2, 2), (11, 11))):
        d.line([a, b], fill=C('#6a5034'))
    d.line([9, 1, 13, 4], fill=(0, 0, 0, 0), width=2)   # pezzo mancante
    return fin(im)


# ---------------------------------------------------------------- FORESTA
def fern():  # felce: fronde a raggiera
    im = new(16, 16); d = ImageDraw.Draw(im)
    rnd = random.Random(3)
    for k in range(7):
        import math
        a = k * 2 * math.pi / 7 + rnd.uniform(-0.2, 0.2)
        x2, y2 = 8 + math.cos(a) * 7, 8 + math.sin(a) * 7
        d.line([8, 8, x2, y2], fill=C('#2e5a2a'), width=2)
        d.line([8, 8, (8 + x2) / 2, (8 + y2) / 2], fill=C('#4a7a3a'))
    d.point((8, 8), fill=C('#1e3a1a'))
    return fin(im, 70)


def mushroom_ring():  # cerchio di funghi (anello delle fate)
    im = new(26, 26); d = ImageDraw.Draw(im)
    import math
    for k in range(11):
        a = k * 2 * math.pi / 11
        x, y = 13 + math.cos(a) * 10, 13 + math.sin(a) * 10
        d.ellipse([x - 2, y - 2, x + 2, y + 2], fill=C('#c8b8a0')); d.point((x - 1, y - 1), fill=C('#f0e8d8'))
        if k % 3 == 0:
            d.point((x + 1, y), fill=C('#a03020'))
    return fin(im, 60)


def antler_skull():  # teschio di cervo con corna
    im = new(16, 12); d = ImageDraw.Draw(im)
    d.ellipse([5, 5, 10, 11], fill=C('#d0c8b0')); d.point((6, 7), fill=C('#1a1410')); d.point((9, 7), fill=C('#1a1410'))
    for s in (-1, 1):
        x0 = 7.5 + s * 2
        d.line([x0, 5, x0 + s * 5, 1], fill=C('#b8ae94')); d.line([x0 + s * 3, 3, x0 + s * 3, 0], fill=C('#b8ae94'))
        d.line([x0 + s * 5, 1, x0 + s * 7, 2], fill=C('#b8ae94'))
    return fin(im, 70)


def mossy_rock():  # sasso muschioso
    im = new(16, 13); d = ImageDraw.Draw(im)
    d.ellipse([0, 1, 15, 12], fill=C('#4a4a52')); d.ellipse([2, 2, 11, 8], fill=C('#62626c'))
    d.ellipse([5, 0, 14, 6], fill=C('#3a5a2e')); d.point((7, 2), fill=C('#5a7a3e')); d.point((11, 3), fill=C('#5a7a3e'))
    return fin(im)


# ---------------------------------------------------------------- PALUDE
def rowboat():  # barca a remi marcia arenata
    im = new(14, 24); d = ImageDraw.Draw(im)
    d.polygon([(7, 0), (13, 7), (12, 20), (7, 23), (2, 20), (1, 7)], fill=C('#4a3626'))
    d.polygon([(7, 2), (11, 8), (10, 19), (7, 21), (4, 19), (3, 8)], fill=C('#2a1e16'))
    for y in (9, 15):
        d.line([3, y, 11, y], fill=C('#6a5034'))
    d.line([2, 12, 0, 18], fill=C('#5a4430'))   # remo
    d.point((5, 12), fill=C('#3a5a34')); d.point((9, 17), fill=C('#3a5a34'))
    return fin(im)


def lilypond():  # pozza con ninfee
    im = new(22, 16); d = ImageDraw.Draw(im)
    d.ellipse([0, 0, 21, 15], fill=C('#1a2a26')); d.ellipse([2, 2, 19, 13], fill=C('#22363a'))
    for (x, y) in ((4, 4), (11, 8), (14, 3), (6, 10)):
        d.ellipse([x, y, x + 4, y + 3], fill=C('#3a6a34')); d.point((x + 2, y + 1), fill=C('#1a2a26'))
    d.point((12, 9), fill=C('#e0c8d8'))
    return outline(im)


def gibbet():  # gabbia appesa a un palo, vista dall'alto
    im = new(14, 16); d = ImageDraw.Draw(im)
    d.rectangle([1, 0, 2, 15], fill=C('#3a2a1c')); d.line([2, 2, 9, 2], fill=C('#3a2a1c'), width=2)
    d.ellipse([5, 5, 13, 13], outline=C('#5a5a68'))
    d.line([9, 5, 9, 13], fill=C('#5a5a68')); d.line([5, 9, 13, 9], fill=C('#5a5a68'))
    d.point((9, 9), fill=C('#d0c8b0')); d.point((8, 10), fill=C('#d0c8b0'))   # ossa dentro
    return fin(im)


# ---------------------------------------------------------------- ROVINE (cattedrale)
def statue_head():  # testa di statua caduta
    im = new(14, 12); d = ImageDraw.Draw(im)
    d.ellipse([1, 1, 12, 11], fill=C('#7a7a8a')); d.ellipse([3, 2, 9, 7], fill=C('#9a9aac'))
    d.point((5, 5), fill=C('#3a3a48')); d.point((8, 5), fill=C('#3a3a48')); d.line([5, 8, 8, 8], fill=C('#3a3a48'))
    d.line([10, 2, 12, 6], fill=C('#4a4a58'))   # crepa
    return fin(im)


def broken_pew():  # panca spezzata
    im = new(22, 9); d = ImageDraw.Draw(im)
    d.rectangle([0, 0, 9, 8], fill=C('#4a3222')); d.rectangle([0, 0, 9, 2], fill=C('#6a4a30'))
    d.polygon([(12, 1), (21, 3), (21, 8), (12, 7)], fill=C('#3e2a1c')); d.line([12, 2, 21, 4], fill=C('#5a3e28'))
    return fin(im)


def rubble_small():  # mucchietto di pietre squadrate
    im = new(18, 13); d = ImageDraw.Draw(im)
    rnd = random.Random(7)
    for k in range(9):
        x, y = rnd.randint(0, 12), rnd.randint(0, 8)
        w, h = rnd.randint(3, 6), rnd.randint(2, 4)
        d.rectangle([x, y, x + w, y + h], fill=C(rnd.choice(['#5a5668', '#6a6678', '#4a4658'])))
        d.line([x, y, x + w, y], fill=C('#7a768a'))
    return fin(im)


# ---------------------------------------------------------------- VETTA GELATA
def ice_spikes():  # punte di ghiaccio che spuntano dal terreno
    im = new(16, 16); d = ImageDraw.Draw(im)
    for (x, y, h) in ((3, 9, 7), (8, 5, 10), (12, 10, 6)):
        d.polygon([(x - 2, y + 4), (x, y - h + 4), (x + 2, y + 4)], fill=C('#a8c8e8'))
        d.line([x - 1, y + 3, x, y - h + 5], fill=C('#e8f4ff'))
    return fin(im, 60)


def frozen_body():  # cadavere congelato nel ghiaccio
    im = new(18, 11); d = ImageDraw.Draw(im)
    d.ellipse([0, 0, 17, 10], fill=C('#8aa8c8')); d.ellipse([2, 2, 15, 8], fill=C('#a8c4e0'))
    d.ellipse([3, 3, 6, 6], fill=C('#6a5a5a')); d.rectangle([6, 4, 13, 6], fill=C('#5a4a4a'))
    d.point((14, 4), fill=C('#e8f4ff')); d.point((4, 2), fill=C('#e8f4ff'))
    return outline(im)


def snowdrift():  # cumulo di neve
    im = new(22, 12); d = ImageDraw.Draw(im)
    d.ellipse([0, 2, 13, 11], fill=C('#c8d8ec')); d.ellipse([7, 0, 21, 10], fill=C('#d8e6f4'))
    d.ellipse([9, 1, 16, 5], fill=C('#f0f6ff'))
    return fin(im, 50)


# ---------------------------------------------------------------- FONDERIE
def slag_heap():  # cumulo di scorie con braci
    im = new(18, 14); d = ImageDraw.Draw(im)
    d.ellipse([0, 1, 17, 13], fill=C('#2a2228')); d.ellipse([3, 2, 13, 9], fill=C('#3a3038'))
    for (x, y) in ((6, 6), (11, 5), (8, 9), (13, 9)):
        d.point((x, y), fill=C('#f08030'))
    d.point((7, 4), fill=C('#ffc060'))
    return fin(im)


def ore_cart():  # carrello da miniera pieno di minerale
    im = new(16, 13); d = ImageDraw.Draw(im)
    d.rectangle([0, 1, 15, 12], fill=C('#3a3a46')); d.rectangle([2, 3, 13, 10], fill=C('#2a2228'))
    rnd = random.Random(2)
    for k in range(8):
        x, y = rnd.randint(3, 11), rnd.randint(4, 8)
        d.rectangle([x, y, x + 1, y + 1], fill=C(rnd.choice(['#8a5a3a', '#a07a4a', '#c0a050'])))
    d.line([0, 1, 15, 1], fill=C('#5a5a68'))
    return fin(im)


def chain_post():  # palo con catene
    im = new(12, 14); d = ImageDraw.Draw(im)
    d.ellipse([3, 3, 9, 9], fill=C('#3a3a46')); d.ellipse([4, 4, 8, 8], fill=C('#5a5a68'))
    for k in range(4):
        d.ellipse([1 + k * 2, 9 + (k % 2), 3 + k * 2, 11 + (k % 2)], outline=C('#7a7a8a'))
    return fin(im)


PROPS = [("woodpile", woodpile), ("signpost", signpost), ("pumpkins", pumpkins), ("broken_wheel", broken_wheel),
         ("fern", fern), ("mushroom_ring", mushroom_ring), ("antler_skull", antler_skull), ("mossy_rock", mossy_rock),
         ("rowboat", rowboat), ("lilypond", lilypond), ("gibbet", gibbet),
         ("statue_head", statue_head), ("broken_pew", broken_pew), ("rubble_small", rubble_small),
         ("ice_spikes", ice_spikes), ("frozen_body", frozen_body), ("snowdrift", snowdrift),
         ("slag_heap", slag_heap), ("ore_cart", ore_cart), ("chain_post", chain_post)]

os.makedirs(OUT, exist_ok=True)
ims = []
def harmonize(im, bright=False):
    """stessa luminosita' e saturazione degli oggetti del gioco (media V~0.25, S~0.23) e ombre verso il viola"""
    import colorsys
    px = im.load()
    kv, ks = (0.78, 0.5) if bright else (0.62, 0.55)
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if a < 200 and r + g + b < 40:
                continue                      # ombra proiettata: resta com'e'
            h, s_, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            s_ *= ks
            v *= kv
            r2, g2, b2 = colorsys.hsv_to_rgb(h, s_, v)
            t = 0.12 * (1.0 - v)              # le zone scure virano verso il viola-blu del gioco
            r2, g2, b2 = r2 * (1 - t) + 0.27 * t, g2 * (1 - t) + 0.23 * t, b2 * (1 - t) + 0.35 * t
            px[x, y] = (int(r2 * 255), int(g2 * 255), int(b2 * 255), a)
    return im


BRIGHT = {"snowdrift", "ice_spikes", "frozen_body"}   # neve e ghiaccio restano chiari come il loro bioma
for n, fn in PROPS:
    im = harmonize(fn(), n in BRIGHT)
    im.save(os.path.join(OUT, n + ".png"))
    ims.append(im)
if PREV:
    from PIL import Image
    pv = Image.new("RGBA", (len(ims) * 34 * 3, 34 * 3), (52, 50, 44, 255))
    for i, im in enumerate(ims):
        b = im.resize((im.width * 3, im.height * 3), Image.NEAREST)
        pv.alpha_composite(b, (i * 102 + (102 - b.width) // 2, (102 - b.height) // 2))
    pv.save(PREV)
print("ok", len(ims))
