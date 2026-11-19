"""Compone scene pixel art complete (terreni, sprite, ombre, luci dinamiche).

Uso: python scene.py <cartella_output>
Scelte di stile: sprite B (contorno selettivo), terreni A. Risoluzione nativa 480x272,
poi ingrandita 3x senza interpolazione.
"""
import sys, math, random, os
import numpy as np
from PIL import Image, ImageDraw, ImageEnhance

OUT = sys.argv[1] if len(sys.argv) > 1 else "."
os.makedirs(OUT, exist_ok=True)
sys.argv = [sys.argv[0], os.path.join(OUT, "_tmp")]
import gen_sprites as S

W, H = 480, 272
BAY = np.tile(np.array(S.BAYER) / 16.0, (H // 4 + 1, W // 4 + 1))[:H, :W]
XX, YY = np.meshgrid(np.arange(W), np.arange(H))
hexc = S.hexc

# ------------------------------------------------------------------ sprite
_cache = {}


def sp(fn, rot=0, flip=False, over=None, bright=1.0, key=None):
    k = (key or fn.__name__, rot, flip, bright, tuple(sorted((over or {}).items())))
    if k not in _cache:
        g, pal = fn()
        if over: pal = dict(pal, **over)
        im = S.render(g, pal, "B")
        if flip: im = im.transpose(Image.FLIP_LEFT_RIGHT)
        if rot: im = im.rotate(rot, expand=True, resample=Image.NEAREST)
        if bright != 1.0:
            r, gg, b, a = im.split()
            rgb = ImageEnhance.Brightness(Image.merge("RGB", (r, gg, b))).enhance(bright)
            im = Image.merge("RGBA", (*rgb.split(), a))
        _cache[k] = im
    return _cache[k]


G = S.G


def npc_fn(kind):
    def f():
        g = G()
        if kind == "elder": g.r(15, 4, 1, 15, 'w')
        if kind == "guard": g.r(15, 2, 1, 17, 'w'); g.p(15, 1, 'm'); g.p(15, 2, 'm')
        g.r(3, 10, 2, 5, 'c'); g.r(15, 10, 2, 5, 'c')
        g.e(10, 12.5, 5, 5, 'c')
        if kind in ("merchant", "farmer"): g.r(7, 12, 6, 6, 'b')
        if kind == "farmer":
            g.e(10, 9.5, 7, 6, 'a'); g.e(10, 8.5, 3.3, 3, 'k'); g.e(10, 11.6, 2.2, 1.1, 's')
        else:
            g.e(10, 9, 4.2, 4.2, 'm' if kind == "guard" else ('a' if kind == "merchant" else 'h'))
            g.e(10, 10.8, 2.7, 1.9, 's'); g.p(9, 10, 'e'); g.p(11, 10, 'e')
            if kind == "elder": g.e(10, 12.6, 2.6, 1.8, 'h')
        g.p(4, 15, 's'); g.p(16, 15, 's')
        return g, dict(c='#3a6aa8', h='#e8e8f0', s='#e0b088', e='#1a1020', a='#c8283c', b='#d8c8a0', k='#b08a30',
                       m='#8d97ab', w='#7a5230')
    f.__name__ = "npc_" + kind
    return f


def dog():
    g = G(12)
    g.e(6, 7, 2.6, 3.6, 'c'); g.e(6, 3, 2.1, 2, 'c'); g.p(4, 1, 'd'); g.p(8, 1, 'd'); g.l(6, 10, 8, 11, 'c')
    g.p(5, 3, 'e'); g.p(7, 3, 'e')
    return g, dict(c='#b8844a', d='#7a4a22', e='#1a1020')


def hen():
    g = G(10)
    g.e(5, 5.5, 3, 3, 'c'); g.p(5, 2, 'r'); g.p(5, 8, 'o'); g.p(4, 6, 'd'); g.p(6, 6, 'd')
    return g, dict(c='#f2efe0', r='#e8283c', o='#ffb347', d='#c8c0a8')


def tomb():
    g = G()
    g.r(3, 4, 14, 13, 'm'); g.r(2, 3, 16, 2, 'h'); g.r(7, 8, 6, 5, 's'); g.p(8, 10, 'e'); g.p(11, 10, 'e'); g.r(9, 12, 2, 1, 'e')
    g.p(4, 6, 'g'); g.p(15, 14, 'g'); g.p(5, 15, 'c'); g.p(14, 6, 'c')
    return g, dict(m='#6a6078', h='#8a7da8', s='#e6e0cc', e='#14101a', g='#55ff88', c='#3f7a40')


# ------------------------------------------------------------------ campo
def noise(scale, amp, seed):
    r = np.random.RandomState(seed)
    small = r.rand(H // scale + 3, W // scale + 3)
    im = Image.fromarray((small * 255).astype(np.uint8)).resize(((W // scale + 3) * scale, (H // scale + 3) * scale), Image.BICUBIC)
    a = np.asarray(im, float)[:H, :W] / 255.0
    return (a - .5) * 2 * amp


def build_ground(names, ids, seed):
    r = random.Random(seed)
    out = np.zeros((H, W, 3), np.uint8)
    for i, name in enumerate(names):
        full = Image.new("RGB", (W, H))
        for ty in range(0, H, 16):
            for tx in range(0, W, 16):
                t = S.tile(name, r.randrange(10 ** 6))
                if r.random() < .5: t = t.transpose(Image.FLIP_LEFT_RIGHT)
                if r.random() < .5: t = t.transpose(Image.FLIP_TOP_BOTTOM)
                t = ImageEnhance.Brightness(t).enhance(1 + (r.random() - .5) * .1)
                full.paste(t, (tx, ty))
        a = np.asarray(full)
        out[ids == i] = a[ids == i]
    return Image.fromarray(out)


class Scene:
    def __init__(s, seed):
        s.r = random.Random(seed)
        s.img = None
        s.items = []
        s.emis = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        s.lights = []
        s.shadow = Image.new("L", (W, H), 0)

    def add(s, im, cx, cy, base=None, sh=True, shs=1.0):
        s.items.append((cy + im.height // 2 if base is None else base, im, int(cx - im.width // 2), int(cy - im.height // 2), sh, shs))

    def light(s, x, y, r, col, inten=1.0):
        s.lights.append((x, y, r, col, inten))

    def flush(s):
        sd = ImageDraw.Draw(s.shadow)
        for base, im, x, y, sh, shs in s.items:
            if sh:
                w, h = im.size
                sd.ellipse([x + w * .12 + 3, y + h * .62 + 3, x + w * .88 + 3, y + h * .98 + 3], fill=int(110 * shs))
        a = np.asarray(s.img, float)
        m = np.asarray(s.shadow, float)[..., None] / 255.0
        a = a * (1 - m * .6)
        s.img = Image.fromarray(a.astype(np.uint8))
        for base, im, x, y, sh, shs in sorted(s.items, key=lambda t: t[0]):
            s.img.paste(im, (x, y), im)

    def lit(s, ambient, levels=7, vig=.36, exposure=1.0):
        arr = np.asarray(s.img, float) / 255.0
        Lm = np.zeros((H, W, 3)) + np.array(ambient)
        glow = np.zeros((H, W, 3))
        for (x, y, r, col, inten) in s.lights:
            d = np.sqrt((XX - x) ** 2 + (YY - y) ** 2) / r
            f = np.clip(1 - d, 0, 1) ** 1.7 * inten
            Lm += f[..., None] * np.array(col)
            core = np.clip(1 - d * 3.5, 0, 1) ** 2 * inten
            glow += core[..., None] * np.array(col) * .22
        v = np.clip(1 - vig * (((XX - W / 2) / (W / 2)) ** 2 + ((YY - H / 2) / (H / 2)) ** 2), .35, 1)
        Lm *= v[..., None]
        q = np.floor(Lm * levels + BAY[..., None] * .999) / levels
        out = arr * q * exposure + glow
        img = Image.fromarray(np.clip(out * 255, 0, 255).astype(np.uint8)).convert("RGBA")
        img.alpha_composite(s.emis)
        return img.convert("RGB")


def save(img, name):
    img.save(os.path.join(OUT, name + "_nativo.png"))
    img.resize((W * 3, H * 3), Image.NEAREST).save(os.path.join(OUT, name + ".png"))


def wall_rect(img, x, y, w, h, rnd, tone=(30, 32, 44), mortar=(12, 13, 18)):
    d = ImageDraw.Draw(img)
    d.rectangle([x, y, x + w - 1, y + h - 1], fill=mortar)
    for by in range(y, y + h, 4):
        off = ((by - y) // 4 % 2) * 4
        for bx in range(x - off, x + w, 8):
            k = rnd.randint(-8, 10)
            c = tuple(max(0, min(255, t + k)) for t in tone)
            x0, x1, y1 = max(bx, x), min(bx + 6, x + w - 1), min(by + 2, y + h - 1)
            if x1 >= x0: d.rectangle([x0, by, x1, y1], fill=c)
            if rnd.random() < .12: d.point((x0 + 1, by), fill=tuple(min(255, t + 30) for t in c))


def flame(d, x, y, s, layers=True):
    pts = [(0, 0), (-7, -6), (-5, -16), (-2, -11), (-3, -24), (2, -15), (3, -30), (7, -14), (9, -20), (10, -6), (7, 0)]
    for k, col in ((1.0, (212, 64, 26)), (.78, (255, 138, 32)), (.5, (255, 208, 96)), (.26, (255, 246, 192))):
        d.polygon([(x + px * s * k, y + py * s * k) for px, py in pts], fill=col + (255,))


def big_tree(kind, rnd):
    fn = {"oak": S.tree_oak, "aut": S.tree_autumn, "pine": S.tree_pine}[kind]
    c = Image.new("RGBA", (46, 46), (0, 0, 0, 0))
    for ox, oy in sorted([(13, 13), (1, 6), (25, 6), (6, 25), (23, 24), (13, 1)], key=lambda t: t[1]):
        im = sp(fn, flip=rnd.random() < .5, bright=.85 + rnd.random() * .3, key=fn.__name__ + "t")
        c.alpha_composite(im, (ox, oy))
    return c


def scatter(sc, pts, rnd):
    for x, y, k in pts:
        t = big_tree(k, rnd)
        sc.add(t, x, y, base=y + 18, shs=1.1)


# ================================================================== SCENA 1: mondo aperto
def scene_world():
    sc = Scene(1)
    r = sc.r
    nx, ny = noise(14, 7, 3), noise(14, 7, 4)
    X, Y = XX + nx, YY + ny
    ids = np.zeros((H, W), int)  # 0 Erba
    ids[X < 118] = 1  # sottobosco
    ids[(X >= 142) & (X < 194)] = 2
    ids[(XX >= 194) & (XX < 224) & (YY >= 118) & (YY < 158)] = 2
    ids[(XX >= 216) & (XX < 448) & (YY >= 236)] = 2
    ids[(XX >= 224) & (XX < 440) & (YY >= 16) & (YY < 228)] = 3
    sc.img = build_ground(["Erba", "Sottobosco", "Ciottoli", "Lastre"], ids, 11)
    img = sc.img
    d = ImageDraw.Draw(img)
    # tappeto
    d.rectangle([250, 150, 309, 183], fill=(14, 6, 8)); d.rectangle([251, 151, 308, 182], fill=(90, 26, 36))
    d.rectangle([254, 154, 305, 179], outline=(200, 154, 58)); d.rectangle([268, 162, 291, 171], fill=(122, 36, 52))
    # bruciatura
    scorch = Image.new("L", (W, H), 0); ImageDraw.Draw(scorch).ellipse([254, 80, 372, 144], fill=140)
    a = np.asarray(img, float); m = np.asarray(scorch, float)[..., None] / 255
    img = sc.img = Image.fromarray((a * (1 - m * .65) + np.array([10, 6, 4]) * m * .65).astype(np.uint8))
    d = ImageDraw.Draw(img)
    # muri
    wall_rect(img, 216, 8, 232, 8, r); wall_rect(img, 440, 8, 8, 228, r)
    wall_rect(img, 216, 228, 150, 8, r); wall_rect(img, 396, 228, 52, 8, r)
    wall_rect(img, 216, 8, 8, 110, r); wall_rect(img, 216, 160, 8, 68, r)
    for rect in ([224, 16, 216, 1], [439, 16, 1, 212], [224, 227, 142, 1], [396, 227, 44, 1], [224, 16, 1, 102], [224, 160, 1, 68]):
        d.rectangle([rect[0], rect[1], rect[0] + rect[2] - 1, rect[1] + rect[3] - 1], fill=(118, 126, 138))
    d.rectangle([210, 114, 223, 119], fill=(58, 63, 74)); d.rectangle([210, 158, 223, 163], fill=(58, 63, 74))
    d.rectangle([362, 226, 367, 237], fill=(58, 63, 74)); d.rectangle([394, 226, 399, 237], fill=(58, 63, 74))
    for rx, ry in ((368, 231), (384, 232), (376, 239), (372, 244)):
        d.rectangle([rx, ry, rx + 5, ry + 3], fill=(44, 48, 56))
    # sangue
    for bx, by, bw in ((404, 252, 6), (412, 256, 4), (396, 248, 3), (340, 158, 5), (356, 162, 3)):
        d.rectangle([bx, by, bx + bw, by + 2], fill=(90, 16, 24))
    # lanterne e pietra del viaggio
    for lx, ly in ((136, 60), (200, 60), (136, 190), (200, 190)):
        d.rectangle([lx, ly + 2, lx + 3, ly + 10], fill=(26, 22, 18)); d.rectangle([lx - 1, ly - 2, lx + 4, ly + 3], fill=(26, 22, 18))
        sc.emis.putpixel((lx + 1, ly), (255, 224, 140, 255)); sc.emis.putpixel((lx + 2, ly), (255, 224, 140, 255)); sc.emis.putpixel((lx + 1, ly + 1), (255, 190, 90, 255)); sc.emis.putpixel((lx + 2, ly + 1), (255, 190, 90, 255))
        sc.light(lx + 2, ly, 52, (1, .78, .42), .95)
    d.ellipse([154, 230, 182, 258], outline=(60, 160, 190)); d.ellipse([159, 235, 177, 253], fill=(34, 50, 74), outline=(74, 240, 255))
    d.rectangle([166, 233, 171, 256], fill=(104, 118, 142)); d.rectangle([167, 238, 170, 240], fill=(74, 240, 255)); d.rectangle([167, 246, 170, 248], fill=(74, 240, 255))
    sc.light(168, 244, 46, (.3, .9, 1), 1.0)
    # alberi
    scatter(sc, [(22, 28, "oak"), (66, 14, "oak"), (106, 36, "oak"), (30, 78, "oak"), (118, 72, "aut"), (84, 96, "aut"),
                 (20, 122, "pine"), (60, 148, "aut"), (100, 166, "pine"), (26, 208, "oak"), (78, 232, "oak"), (112, 246, "oak"),
                 (38, 254, "oak"), (462, 44, "oak"), (466, 102, "oak"), (452, 130, "aut"), (458, 164, "oak"), (462, 226, "oak"),
                 (196, 8, "oak"), (190, 252, "oak")], r)
    sc.add(sp(S.tree_dead), 40, 178); sc.add(sp(S.tree_dead), 120, 202)
    # oggetti
    for x, y in ((231, 31), (231, 49), (247, 36), (430, 106), (430, 124), (416, 112), (236, 210), (250, 222)):
        sc.add(sp(S.barrel), x, y)
    for x, y in ((272, 52), (298, 44), (370, 34), (406, 34), (408, 188), (432, 188)):
        sc.add(sp(S.crate), x, y)
    sc.add(sp(S.chest), 238, 196)
    sc.add(sp(S.campfire), 410, 250)
    sc.add(sp(S.gravestone), 108, 226); sc.add(sp(S.gravestone, flip=True), 124, 218)
    for x, y in ((92, 154), (62, 216), (124, 54)):
        sc.add(sp(S.mushrooms, flip=(x % 2 == 0)), x, y, sh=False)
        sc.light(x, y, 30, (.3, .9, 1), .9)
    # personaggi
    sc.add(sp(S.knight, rot=90), 272, 176)
    sc.add(sp(S.mage, rot=90), 252, 206)
    sc.add(sp(S.goblin, rot=270), 378, 92)
    sc.add(sp(S.goblin, rot=270, flip=True), 352, 152)
    sc.add(sp(S.orc, rot=270), 408, 140)
    sc.add(sp(S.skeleton, rot=270), 340, 196)
    sc.add(sp(S.wraith), 180, 140)
    sc.flush()
    # luci
    sc.light(312, 100, 160, (1, .55, .2), 1.35)
    sc.light(272, 176, 42, (1, .8, .5), .45)
    sc.light(262, 206, 44, (.3, .9, 1), .85)
    sc.light(410, 250, 44, (1, .7, .35), .9)
    sc.light(168, 122, 120, (.3, .4, .8), .5)
    sc.light(180, 140, 30, (.4, .8, 1), .5)
    # fuoco
    ed = ImageDraw.Draw(sc.emis)
    for x, y, s in ((268, 56, .7), (296, 52, .6), (310, 76, 1.0), (324, 72, .9), (300, 92, 1.3), (318, 88, 1.5), (332, 90, 1.1),
                    (293, 110, 1.2), (308, 106, 1.8), (324, 104, 2.0), (338, 108, 1.3), (285, 122, 1.1), (300, 126, 1.5),
                    (315, 124, 1.7), (330, 126, 1.4), (344, 120, 1.0)):
        flame(ed, x, y, s)
    for _ in range(46):
        ex, ey = r.randint(262, 372), r.randint(22, 130)
        sc.emis.putpixel((ex, ey), r.choice([(255, 208, 96, 255), (255, 138, 32, 255), (255, 246, 192, 255)]))
    for _ in range(14):
        fx, fy = r.randint(10, 190), r.randint(20, 250)
        sc.emis.putpixel((fx, fy), (255, 246, 160, 255))
    return sc.lit((.26, .30, .46), levels=7, vig=.34)


# ================================================================== SCENA 2: villaggio
def roof(sc, x, y, w, h, col, ridge="h", chimney=False, door=True, windows=2):
    img = sc.img; d = ImageDraw.Draw(img); r = sc.r
    # parete frontale
    d.rectangle([x, y + h, x + w - 1, y + h + 8], fill=(96, 68, 46))
    for yy in range(y + h + 2, y + h + 9, 3): d.line([x, yy, x + w - 1, yy], fill=(70, 48, 32))
    d.rectangle([x, y + h + 8, x + w - 1, y + h + 8], fill=(40, 28, 20))
    if door:
        dx = x + w // 2 - 4
        d.rectangle([dx, y + h + 1, dx + 7, y + h + 8], fill=(36, 22, 12)); d.rectangle([dx + 1, y + h + 2, dx + 6, y + h + 8], fill=(86, 54, 28))
        sc.light(dx + 4, y + h + 10, 40, (1, .66, .28), .9)
    for i in range(windows):
        wx = x + 6 + i * (w - 20) // max(1, windows - 1) if windows > 1 else x + w // 4
        if door and abs(wx + 3 - (x + w // 2)) < 8: continue
        d.rectangle([wx, y + h + 2, wx + 5, y + h + 6], fill=(255, 196, 96)); d.rectangle([wx + 2, y + h + 2, wx + 3, y + h + 6], fill=(120, 80, 30))
        sc.light(wx + 3, y + h + 8, 26, (1, .7, .3), .6)
    # tetto
    d.rectangle([x - 2, y - 1, x + w + 1, y + h], fill=(14, 8, 16))
    rows = 0
    for yy in range(y, y + h, 4):
        shade = .86 + (rows % 2) * .14
        for xx in range(x - 1, x + w + 1, 6):
            k = shade * (.9 + r.random() * .2)
            c = tuple(min(255, int(v * k)) for v in col)
            x0_, x1_ = xx + (rows % 2) * 3, min(x + w, xx + 4 + (rows % 2) * 3)
            if x1_ >= x0_: d.rectangle([x0_, yy, x1_, min(yy + 2, y + h - 1)], fill=c)
        rows += 1
    if ridge == "h":
        d.rectangle([x - 1, y + h // 2 - 1, x + w, y + h // 2], fill=tuple(min(255, int(v * 1.3)) for v in col))
        d.rectangle([x - 1, y + h // 2 + 1, x + w, y + h // 2 + 1], fill=tuple(int(v * .55) for v in col))
    d.rectangle([x - 2, y + h - 2, x + w + 1, y + h - 1], fill=tuple(int(v * .5) for v in col))
    # ombra
    sd = ImageDraw.Draw(sc.shadow); sd.rectangle([x + 6, y + 8, x + w + 8, y + h + 12], fill=120)
    if chimney:
        cx = x + w - 16
        d.rectangle([cx, y + 3, cx + 6, y + 9], fill=(70, 66, 76)); d.rectangle([cx + 1, y + 4, cx + 5, y + 8], fill=(20, 16, 20))
        ed = ImageDraw.Draw(sc.emis)
        for i, (ox, oy, rr) in enumerate(((3, -2, 3), (6, -8, 4), (10, -15, 5), (15, -23, 6))):
            ed.ellipse([cx + ox - rr, y + oy - rr, cx + ox + rr, y + oy + rr], fill=(150, 146, 160, 90 - i * 14))


def fence(img, x0, y0, x1, y1):
    d = ImageDraw.Draw(img)
    if y0 == y1:
        d.line([x0, y0, x1, y0], fill=(90, 62, 36)); d.line([x0, y0 + 1, x1, y0 + 1], fill=(56, 38, 22))
        for x in range(x0, x1 + 1, 8): d.rectangle([x, y0 - 2, x + 1, y0 + 3], fill=(122, 86, 50))
    else:
        d.line([x0, y0, x0, y1], fill=(90, 62, 36)); d.line([x0 + 1, y0, x0 + 1, y1], fill=(56, 38, 22))
        for y in range(y0, y1 + 1, 8): d.rectangle([x0 - 1, y, x0 + 2, y + 1], fill=(122, 86, 50))


def stall(sc, x, y, w, col):
    d = ImageDraw.Draw(sc.img)
    d.rectangle([x, y + 10, x + w - 1, y + 18], fill=(20, 12, 8)); d.rectangle([x + 1, y + 11, x + w - 2, y + 17], fill=(122, 86, 50))
    for i, c in enumerate(((220, 60, 50), (240, 200, 90), (80, 160, 90), (90, 120, 200))):
        d.rectangle([x + 3 + i * 6, y + 12, x + 6 + i * 6, y + 15], fill=c)
    d.rectangle([x - 1, y - 1, x + w, y + 9], fill=(14, 8, 16))
    for i in range(0, w, 4):
        d.rectangle([x + i, y, x + i + 3, y + 8], fill=col if (i // 4) % 2 == 0 else (236, 230, 214))
    d.rectangle([x, y + 8, x + w - 1, y + 8], fill=(60, 40, 40))
    ImageDraw.Draw(sc.shadow).rectangle([x + 4, y + 4, x + w + 4, y + 20], fill=100)


def scene_village():
    sc = Scene(2)
    r = sc.r
    nx, ny = noise(12, 6, 5), noise(12, 6, 6)
    X, Y = XX + nx, YY + ny
    ids = np.zeros((H, W), int)  # 0 Erba 1 Terra 2 Ciottoli 3 Campo
    ids[(Y >= 118) & (Y < 154)] = 1
    ids[(X >= 214) & (X < 266)] = 1
    ids[(Y >= 236) & (Y < 254) & (XX < 290)] = 1
    for dx in (108, 202, 340, 426):  # spur dalle case in alto
        ids[(Y >= 86) & (Y < 120) & (abs(XX - dx) < 6)] = 1
    for dx in (92, 178):
        ids[(Y >= 212) & (Y < 238) & (abs(XX - dx) < 6)] = 1
    ids[((X - 240) ** 2 + (Y - 136) ** 2) < 46 ** 2] = 2
    ids[(XX >= 290) & (YY >= 236)] = 3
    sc.img = build_ground(["Erba", "Terra", "Ciottoli", "Campo"], ids, 21)
    # case alto
    roof(sc, 56, 22, 100, 54, (62, 94, 160), chimney=True, windows=3)
    roof(sc, 170, 30, 64, 44, (170, 52, 58), windows=2)
    roof(sc, 300, 20, 84, 56, (86, 94, 112), chimney=True, windows=2)
    roof(sc, 402, 32, 56, 44, (60, 128, 80), windows=2)
    # case basso
    roof(sc, 56, 166, 76, 42, (204, 164, 82), ridge="h", windows=2)
    roof(sc, 150, 172, 58, 36, (60, 128, 80), windows=2)
    roof(sc, 402, 168, 64, 50, (190, 150, 72), windows=1, door=True)
    # bancarelle
    stall(sc, 292, 170, 30, (220, 60, 50)); stall(sc, 326, 170, 30, (70, 110, 200)); stall(sc, 360, 170, 30, (240, 160, 50))
    # campo con recinto
    fence(sc.img, 288, 236, 478, 236); fence(sc.img, 288, 236, 288, 270)
    # recinti
    fence(sc.img, 50, 214, 138, 214); fence(sc.img, 146, 214, 214, 214)
    # pozzo
    d = ImageDraw.Draw(sc.img)
    d.ellipse([229, 125, 251, 147], fill=(14, 10, 16)); d.ellipse([230, 126, 250, 146], fill=(122, 126, 140)); d.ellipse([233, 129, 247, 143], fill=(86, 90, 104))
    d.ellipse([235, 131, 245, 141], fill=(34, 74, 128)); d.point((238, 134), fill=(150, 210, 255)); d.point((239, 134), fill=(150, 210, 255))
    d.line([240, 127, 240, 145], fill=(90, 62, 36)); d.rectangle([239, 126, 241, 128], fill=(122, 86, 50))
    ImageDraw.Draw(sc.shadow).ellipse([232, 130, 258, 154], fill=90)
    # lampioni piazza
    for lx, ly in ((196, 100), (284, 100), (196, 172), (284, 172)):
        d.rectangle([lx, ly + 2, lx + 3, ly + 9], fill=(30, 24, 20)); d.rectangle([lx - 1, ly - 2, lx + 4, ly + 3], fill=(30, 24, 20))
        for ox in (1, 2):
            sc.emis.putpixel((lx + ox, ly), (255, 224, 140, 255)); sc.emis.putpixel((lx + ox, ly + 1), (255, 190, 90, 255))
        sc.light(lx + 2, ly, 58, (1, .78, .42), 1.0)
    # alberi
    scatter(sc, [(18, 24, "oak"), (22, 120, "aut"), (30, 220, "oak"), (14, 262, "oak"), (456, 120, "oak"), (466, 10, "oak"),
                 (270, 12, "oak"), (160, 252, "aut"), (230, 252, "oak"), (470, 214, "oak"), (130, 110, "oak"), (290, 108, "aut")], r)
    # oggetti
    for x, y in ((392, 188), (384, 200), (214, 190), (286, 228)): sc.add(sp(S.barrel), x, y)
    for x, y in ((40, 198), (47, 208), (156, 224), (150, 232)): sc.add(sp(S.crate), x, y)
    for x, y in ((336, 244), (352, 252), (370, 244), (396, 250), (420, 244)):
        hay = Image.new("RGBA", (12, 12), (0, 0, 0, 0)); hd = ImageDraw.Draw(hay)
        hd.ellipse([0, 0, 11, 11], fill=(14, 8, 16, 255)); hd.ellipse([1, 1, 10, 10], fill=(214, 176, 84, 255)); hd.ellipse([3, 3, 8, 8], fill=(238, 204, 110, 255))
        hd.line([2, 5, 9, 5], fill=(170, 134, 60, 255)); sc.add(hay, x, y)
    # png
    sc.add(sp(npc_fn("elder"), rot=270), 214, 130)
    sc.add(sp(npc_fn("farmer"), key="f1"), 330, 150)
    sc.add(sp(npc_fn("merchant"), over=dict(c='#8a4a8a')), 308, 164)
    sc.add(sp(npc_fn("guard"), rot=90), 168, 156)
    sc.add(sp(npc_fn("farmer"), over=dict(c='#8a6a3a', a='#d8c070'), key="f2"), 318, 226)
    sc.add(sp(dog), 258, 190)
    sc.add(sp(hen), 80, 222); sc.add(sp(hen, flip=True), 92, 228); sc.add(sp(hen), 70, 232)
    sc.add(sp(S.knight), 244, 178)
    sc.flush()
    # marcatore ! sopra anziano (in emissivo)
    ed = ImageDraw.Draw(sc.emis)
    ed.rectangle([212, 108, 215, 118], fill=(10, 6, 16, 255)); ed.rectangle([213, 109, 214, 115], fill=(255, 210, 74, 255)); ed.rectangle([213, 117, 214, 118], fill=(255, 210, 74, 255))
    # fumo e lucciole
    for _ in range(26):
        fx, fy = r.randint(6, 470), r.randint(6, 262)
        sc.emis.putpixel((fx, fy), (255, 236, 150, 255))
    sc.light(240, 136, 90, (1, .8, .5), .45)
    sc.light(240, 136, 150, (.8, .55, .45), .35)
    return sc.lit((.54, .48, .62), levels=8, vig=.4)


# ================================================================== SCENA 3: dungeon
def scene_dungeon():
    sc = Scene(3)
    r = sc.r
    ids = np.zeros((H, W), int)
    sc.img = build_ground(["Cripta"], ids, 31)
    img = sc.img; d = ImageDraw.Draw(img)
    wall_rect(img, 0, 0, W, 40, r, tone=(48, 42, 66), mortar=(18, 14, 26))
    wall_rect(img, 0, 40, 16, H - 40, r, tone=(48, 42, 66), mortar=(18, 14, 26))
    wall_rect(img, W - 16, 40, 16, H - 40, r, tone=(48, 42, 66), mortar=(18, 14, 26))
    wall_rect(img, 16, H - 16, W - 32, 16, r, tone=(48, 42, 66), mortar=(18, 14, 26))
    d.rectangle([16, 40, W - 17, 41], fill=(120, 110, 150)); d.rectangle([16, 42, W - 17, 47], fill=(24, 18, 32))
    d.rectangle([16, 40, 17, H - 17], fill=(100, 92, 128)); d.rectangle([W - 18, 40, W - 17, H - 17], fill=(100, 92, 128))
    ImageDraw.Draw(sc.shadow).rectangle([16, 42, W - 17, 54], fill=120)
    # tappeto
    d.rectangle([222, 42, 257, H - 17], fill=(12, 4, 8))
    for y in range(42, H - 16):
        row = (y // 8) % 2
        d.line([223, y, 256, y], fill=(104, 26, 40) if row == 0 else (96, 22, 36))
    d.rectangle([223, 42, 224, H - 17], fill=(200, 154, 58)); d.rectangle([255, 42, 256, H - 17], fill=(200, 154, 58))
    for y in range(52, H - 20, 24):
        d.polygon([(240, y), (246, y + 6), (240, y + 12), (234, y + 6)], fill=(200, 154, 58)); d.point((240, y + 6), fill=(104, 26, 40))
    # cancello sigillato
    d.rectangle([220, 8, 259, 41], fill=(10, 6, 16)); d.rectangle([222, 10, 257, 41], fill=(68, 60, 92))
    for bx in (226, 234, 242, 250): d.rectangle([bx, 10, bx + 1, 41], fill=(34, 28, 46))
    d.rectangle([222, 24, 257, 26], fill=(138, 138, 154)); d.rectangle([233, 19, 246, 33], fill=(10, 6, 16)); d.rectangle([234, 20, 245, 32], fill=(74, 240, 255)); d.rectangle([239, 24, 240, 29], fill=(10, 6, 16))
    sc.emis.paste(Image.new("RGBA", (12, 12), (74, 240, 255, 255)), (234, 20))
    sc.emis.paste(Image.new("RGBA", (2, 6), (10, 6, 16, 255)), (239, 24))
    sc.light(240, 30, 70, (.3, .9, 1), 1.0)
    # torce sul muro
    ed = ImageDraw.Draw(sc.emis)
    for tx_ in (70, 150, 330, 410):
        d.rectangle([tx_ - 1, 24, tx_ + 2, 36], fill=(90, 58, 26)); d.rectangle([tx_ - 3, 34, tx_ + 4, 37], fill=(106, 106, 122))
        flame(ed, tx_ + .5, 25, .55)
        sc.light(tx_, 28, 90, (1, .62, .26), 1.1)
    for sy in (120, 200):
        for sx in (22, W - 24):
            d.rectangle([sx - 1, sy, sx + 2, sy + 6], fill=(90, 58, 26)); flame(ed, sx + .5, sy + 1, .5)
            sc.light(sx, sy + 2, 64, (1, .62, .26), .9)
    # pilastri
    for px_, py_ in ((90, 100), (390, 100), (90, 200), (390, 200)):
        d.ellipse([px_ - 10, py_ - 10, px_ + 10, py_ + 10], fill=(10, 6, 16)); d.ellipse([px_ - 9, py_ - 9, px_ + 9, py_ + 9], fill=(104, 94, 128))
        d.ellipse([px_ - 7, py_ - 7, px_ + 7, py_ + 7], fill=(86, 76, 108)); d.ellipse([px_ - 5, py_ - 6, px_ + 2, py_ + 1], fill=(136, 124, 160))
        ImageDraw.Draw(sc.shadow).ellipse([px_ - 6, py_ - 3, px_ + 16, py_ + 14], fill=110)
    # sarcofagi
    for sx, sy in ((130, 62), (350, 62)):
        d.rectangle([sx - 20, sy - 10, sx + 20, sy + 10], fill=(10, 6, 16)); d.rectangle([sx - 19, sy - 9, sx + 19, sy + 9], fill=(112, 102, 136))
        d.rectangle([sx - 17, sy - 7, sx + 17, sy + 7], fill=(92, 82, 114)); d.rectangle([sx - 1, sy - 5, sx, sy + 5], fill=(40, 34, 58)); d.rectangle([sx - 4, sy - 2, sx + 3, sy - 1], fill=(40, 34, 58))
        ImageDraw.Draw(sc.shadow).rectangle([sx - 16, sy - 6, sx + 24, sy + 16], fill=100)
    # ossa e sangue
    for bx, by in ((60, 150), (420, 150), (300, 236), (170, 240), (440, 60)):
        d.rectangle([bx, by, bx + 5, by + 1], fill=(220, 214, 190)); d.rectangle([bx + 2, by - 2, bx + 3, by + 3], fill=(200, 194, 170)); d.rectangle([bx - 2, by + 3, bx + 1, by + 5], fill=(236, 230, 208))
    for bx, by, bw in ((206, 160, 7), (214, 166, 4), (290, 126, 6), (260, 150, 3)):
        d.rectangle([bx, by, bx + bw, by + 2], fill=(86, 14, 22))
    # ragnatele
    ed = ImageDraw.Draw(sc.emis)
    for (x0, y0, sx_, sy_) in ((18, 48, 1, 1), (W - 19, 48, -1, 1), (18, H - 18, 1, -1), (W - 19, H - 18, -1, -1)):
        for k in range(3): ed.line([x0, y0, x0 + sx_ * 22, y0 + sy_ * (4 + k * 8)], fill=(210, 210, 230, 70))
        ed.line([x0 + sx_ * 8, y0 + sy_ * 1, x0 + sx_ * 6, y0 + sy_ * 12], fill=(210, 210, 230, 60))
    # oggetti
    for x, y in ((34, 62), (34, 76), (46, 66), (444, 232), (432, 240)): sc.add(sp(S.barrel), x, y)
    for x, y in ((446, 70), (30, 232)): sc.add(sp(S.crate), x, y)
    sc.add(sp(S.chest), 416, 232)
    for x, y in ((170, 142), (320, 150), (180, 216)):
        sc.add(sp(tomb), x, y); sc.light(x, y, 40, (.3, 1, .5), .8)
    # personaggi e nemici
    sc.add(sp(S.knight, rot=180), 240, 196)
    sc.add(sp(S.mage, rot=180), 204, 216)
    sc.add(sp(S.skeleton, bright=2.4, key="skhit"), 222, 148)
    sc.add(sp(S.skeleton), 284, 122)
    sc.add(sp(S.skeleton, flip=True), 150, 190)
    sc.add(sp(S.wraith), 330, 100)
    sc.add(sp(S.bat), 134, 108); sc.add(sp(S.bat, flip=True), 352, 176)
    sc.flush()
    # colpo di spada, proiettili
    ed = ImageDraw.Draw(sc.emis)
    ed.arc([212, 150, 268, 206], 215, 325, fill=(74, 120, 216, 255), width=6)
    ed.arc([212, 150, 268, 206], 215, 325, fill=(159, 216, 255, 255), width=4)
    ed.arc([212, 150, 268, 206], 218, 322, fill=(255, 255, 255, 255), width=2)
    for fx, fy in ((300, 110), (286, 122)):
        ed.ellipse([fx - 4, fy - 4, fx + 4, fy + 4], fill=(10, 6, 16, 255)); ed.ellipse([fx - 3, fy - 3, fx + 3, fy + 3], fill=(255, 138, 32, 255)); ed.ellipse([fx - 1, fy - 1, fx + 1, fy + 1], fill=(255, 246, 192, 255))
        sc.light(fx, fy, 34, (1, .6, .25), .9)
    for ex, ey in ((150, 176), (260, 160), (180, 130)):
        sc.emis.putpixel((ex, ey), (255, 210, 120, 255))
    sc.light(240, 196, 70, (1, .85, .6), .55)
    sc.light(204, 216, 46, (.3, .9, 1), .8)
    sc.light(330, 100, 40, (.4, .8, 1), .6)
    return sc.lit((.12, .10, .22), levels=7, vig=.5)


if __name__ == "__main__":
    save(scene_world(), "scena_mondo")
    save(scene_village(), "scena_villaggio")
    save(scene_dungeon(), "scena_dungeon")
    print("ok")
