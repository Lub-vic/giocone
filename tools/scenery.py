"""Scenari in pixel art gotico: erba, cespugli, pietre, ossa, funghi, canneti, rovine, edifici...
Uso: python scenery.py <cartella_sprites>
Scrive molti PNG (nome_variante.png) e <cartella>/../scenery_preview.png
"""
import sys, os, math, random
from PIL import Image, ImageDraw

OUT = sys.argv[1] if len(sys.argv) > 1 else "."
_argv = sys.argv
sys.argv = [sys.argv[0], OUT]
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from trees import outline, hexc, BAYER, wood, branch  # noqa: E402
sys.argv = _argv
os.makedirs(OUT, exist_ok=True)

# palette per regione: erba (4 toni), roccia (4), legno (3), accento
PALS = {
    "vil": dict(grass=['#2e2418', '#4a3c24', '#6a5834', '#8a7648'], rock=['#2a2228', '#3e343c', '#56494f', '#74656a'],
                wood=['#241a14', '#3a2a20', '#5a4432'], acc='#b08a50'),
    "cem": dict(grass=['#142220', '#1e2e2a', '#2e463e', '#4a6a5c'], rock=['#24243a', '#34344c', '#4c4c68', '#6e6e90'],
                wood=['#1e1620', '#34283a', '#5a4a62'], acc='#a8a8c8'),
    "for": dict(grass=['#0e1a12', '#14241a', '#20361f', '#38582d'], rock=['#1c201e', '#2a302c', '#3e463f', '#5a645a'],
                wood=['#1a1210', '#2e2018', '#4e3828'], acc='#4a6a3a'),
    "swa": dict(grass=['#1a2212', '#25301a', '#3a4a22', '#5a6a30'], rock=['#1e2a24', '#2c3c32', '#42584a', '#628068'],
                wood=['#1c1812', '#302a1e', '#504430'], acc='#4aa89a'),
    "cat": dict(grass=['#142014', '#1c2a1c', '#2c4228', '#44603a'], rock=['#28243a', '#3a3650', '#524c6c', '#726c90'],
                wood=['#1e1620', '#34283a', '#5a4a62'], acc='#c8a0e0'),
    "ice": dict(grass=['#4a6486', '#6a88ac', '#a0c0dc', '#dcecf8'], rock=['#4a5a7c', '#6a7ea2', '#9ab0d0', '#e6f0fa'],
                wood=['#2a2a3a', '#444458', '#6a6a80'], acc='#a8e0ff'),
    "frg": dict(grass=['#120c0e', '#201416', '#3a2220', '#5a3228'], rock=['#140f12', '#241a1e', '#3a2c30', '#584248'],
                wood=['#160e0c', '#2a1a16', '#42281e'], acc='#ff7a20'),
}


def P(name, key):
    return [hexc(c) for c in PALS[name][key]]


def hf_new(w, h):
    return [[0.0] * w for _ in range(h)]


def ell(hf, cx, cy, rx, ry, hh, p=2.0):
    H, W = len(hf), len(hf[0])
    for y in range(H):
        for x in range(W):
            d = (abs(x + .5 - cx) / rx) ** p + (abs(y + .5 - cy) / ry) ** p
            if d < 1:
                hf[y][x] = max(hf[y][x], (1 - d) ** (1 / p) * hh)


def shade(hf, pal, rnd, lk=0.55, dither=.4, noise=.5, bias=0.0):
    H, W = len(hf), len(hf[0])
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    px = img.load()
    for y in range(1, H - 1):
        for x in range(1, W - 1):
            if hf[y][x] <= 0.4:
                continue
            lit = (hf[y - 1][x - 1] - hf[y + 1][x + 1]) * lk + (hf[y][x] - 3) * 0.05 + bias
            v = lit + (BAYER[y % 4][x % 4] / 16 - .5) * dither + rnd.uniform(-noise, noise) * .4
            idx = 3 if v > 1.0 else (2 if v > .25 else (1 if v > -.7 else 0))
            px[x, y] = pal[idx] + (255,)
    return img


def save(im, name):
    from decay import weather
    weather(im, name).save(os.path.join(OUT, name + ".png"))
    return name


def shadow(im, a=70):
    """Ombra a terra sotto lo sprite (ellisse scura alla base)."""
    w, h = im.size
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(out)
    d.ellipse([w * .08, h - 7, w * .92, h - 1], fill=(0, 0, 0, a))
    out.alpha_composite(im)
    return out


# ------------------------------------------------------------------ vegetazione e pietre piccole
def grass(seed, pal, big=False):
    rnd = random.Random(seed)
    w, h = (18, 16) if big else (12, 10)
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px = im.load()
    cols = P(pal, "grass")
    for b in range(rnd.randint(6, 10) if big else rnd.randint(4, 7)):
        x = w // 2 + rnd.randint(-w // 3, w // 3)
        ln = rnd.randint(h // 2, h - 1)
        lean = rnd.uniform(-.5, .5)
        for j in range(ln):
            xx = int(round(x + lean * j + math.sin(j * .5 + b) * .6))
            yy = h - 1 - j
            if 0 <= xx < w and 0 <= yy < h:
                t = j / ln
                px[xx, yy] = cols[0 if t < .2 else (1 if t < .55 else (2 if t < .85 else 3))] + (255,)
    return im


def shrub(seed, pal, w=22, h=20):
    rnd = random.Random(seed)
    cols = P(pal, "grass")
    wd = P(pal, "wood")
    mask = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(mask)
    for k in range(rnd.randint(4, 6)):
        branch(d, rnd, w // 2 + rnd.randint(-2, 2), h - 2, -math.pi / 2 + rnd.uniform(-1.0, 1.0), rnd.uniform(8, 13), 1, 2)
    im = wood(mask, rnd, wd)
    hf = hf_new(w, h)
    for k in range(rnd.randint(3, 5)):
        ell(hf, w // 2 + rnd.uniform(-6, 6), h * .55 + rnd.uniform(-4, 3), rnd.uniform(3.5, 6), rnd.uniform(3, 5), 5)
    leaves = shade(hf, cols, rnd, dither=.55, noise=.8)
    px = leaves.load()
    for y in range(h):
        for x in range(w):
            if px[x, y][3] and rnd.random() < .22:
                px[x, y] = (0, 0, 0, 0)
    im.alpha_composite(leaves)
    return outline(im)


def rocks(seed, pal, big=False, mossy=False):
    rnd = random.Random(seed)
    w, h = (32, 26) if big else (16, 12)
    hf = hf_new(w, h)
    n = rnd.randint(3, 5) if big else rnd.randint(1, 3)
    for k in range(n):
        r = rnd.uniform(6, 11) if big else rnd.uniform(3, 5)
        ell(hf, w / 2 + rnd.uniform(-w * .22, w * .22), h * .62 + rnd.uniform(-h * .1, h * .1), r, r * rnd.uniform(.6, .85), r * .9, 2.5)
    cols = P(pal, "rock")
    im = shade(hf, cols, rnd, lk=.7, dither=.35)
    px = im.load()
    if mossy or pal in ("swa", "for"):
        for y in range(h):
            for x in range(w):
                if px[x, y][3] and hf[y][x] > 1 and rnd.random() < .12 and y < h * .7:
                    px[x, y] = hexc('#3a5a34') + (255,)
    if pal == "ice":
        for y in range(h):
            for x in range(w):
                if px[x, y][3] and y < h * .45 and rnd.random() < .5:
                    px[x, y] = hexc('#eef6fc') + (255,)
    if pal == "frg":
        for y in range(h):
            for x in range(w):
                if px[x, y][3] and rnd.random() < .05:
                    px[x, y] = hexc('#ff6a1a') + (255,)
    return shadow(outline(im), 60)


def mushrooms(seed, kind):
    rnd = random.Random(seed)
    w, h = 20, 16
    caps = {"glow": ['#0e4a4a', '#1c8a88', '#4ad0c8', '#b8fff0'], "purple": ['#2a1040', '#5a2a80', '#8a4ac0', '#d8a8ff'],
            "red": ['#4a0e18', '#8a1c2c', '#c83a48', '#f0a0a0']}[kind]
    cols = [hexc(c) for c in caps]
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    for k in range(rnd.randint(2, 4)):
        cx = rnd.randint(4, w - 5)
        cy = rnd.randint(5, h - 5)
        r = rnd.uniform(2.5, 4.5)
        hf = hf_new(w, h)
        ell(hf, cx, cy, r, r * .7, r * .9)
        cap = shade(hf, cols, rnd, dither=.3)
        d = ImageDraw.Draw(im)
        d.rectangle([cx - 1, cy, cx, cy + 4], fill=hexc('#d8d0c0') + (255,))
        im.alpha_composite(cap)
        px = im.load()
        if rnd.random() < .7 and 0 <= cx < w:
            px[cx, max(0, cy - 1)] = cols[3] + (255,)
    return outline(im)


def bones(seed, kind):
    rnd = random.Random(seed)
    w, h = (16, 12)
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    b, bs = hexc('#d8d0b4') + (255,), hexc('#9a9278') + (255,)
    if kind == "skull":
        d.ellipse([4, 2, 11, 8], fill=b)
        d.rectangle([6, 8, 9, 10], fill=b)
        for x in (5, 9):
            d.rectangle([x, 4, x + 1, 5], fill=(14, 10, 20, 255))
        d.point((7, 6), fill=bs)
        d.point((8, 6), fill=bs)
    elif kind == "ribs":
        d.rectangle([7, 1, 8, 10], fill=b)
        for y in range(2, 10, 2):
            d.arc([2, y - 2, 8, y + 3], 270, 90, fill=b)
            d.arc([7, y - 2, 13, y + 3], 90, 270, fill=b)
    else:  # ossa sparse
        for k in range(3):
            x0, y0 = rnd.randint(1, 7), rnd.randint(2, 9)
            x1, y1 = x0 + rnd.randint(4, 7), y0 + rnd.randint(-2, 2)
            d.line([x0, y0, x1, y1], fill=b)
            d.point((x0, y0 - 1), fill=b)
            d.point((x1, y1 + 1), fill=b)
    return outline(im)


def flower(seed, col):
    rnd = random.Random(seed)
    w, h = 12, 12
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    c = hexc(col) + (255,)
    for k in range(rnd.randint(2, 4)):
        x = rnd.randint(2, w - 3)
        y = rnd.randint(3, 6)
        d.line([x, h - 1, x, y], fill=hexc('#2a4a2a') + (255,))
        d.point((x - 1, y), fill=c)
        d.point((x + 1, y), fill=c)
        d.point((x, y - 1), fill=c)
        d.point((x, y), fill=hexc('#f0e8c0') + (255,))
    return im


def reeds(seed):
    rnd = random.Random(seed)
    w, h = 18, 30
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px = im.load()
    d = ImageDraw.Draw(im)
    cols = [hexc('#243016'), hexc('#38481f'), hexc('#566a2e')]
    for k in range(rnd.randint(5, 8)):
        x = rnd.randint(3, w - 4)
        ln = rnd.randint(14, 27)
        lean = rnd.uniform(-.25, .25)
        for j in range(ln):
            xx = int(round(x + lean * j))
            yy = h - 1 - j
            if 0 <= xx < w and yy >= 0:
                px[xx, yy] = cols[min(2, j * 3 // ln)] + (255,)
        if rnd.random() < .6:
            xx = int(round(x + lean * ln))
            d.rectangle([xx, h - ln - 4, xx, h - ln], fill=hexc('#5a3a22') + (255,))
    return im


def log_(seed, pal):
    rnd = random.Random(seed)
    w, h = 40, 16
    wd = P(pal, "wood")
    mask = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(mask)
    d.rectangle([3, 4, w - 4, h - 4], fill=255)
    d.ellipse([0, 4, 7, h - 4], fill=255)
    d.ellipse([w - 8, 4, w - 1, h - 4], fill=255)
    im = wood(mask, rnd, wd)
    d2 = ImageDraw.Draw(im)
    d2.ellipse([w - 7, 5, w - 2, h - 5], outline=wd[2] + (255,), fill=hexc('#6a5238') + (255,))
    px = im.load()
    for y in range(h):
        for x in range(w):
            if px[x, y][3] and rnd.random() < .06:
                px[x, y] = hexc('#3a5a34') + (255,)
    return shadow(outline(im), 60)


def stump(seed, pal):
    rnd = random.Random(seed)
    w, h = 26, 24
    wd = P(pal, "wood")
    mask = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(mask)
    d.rectangle([5, 8, w - 6, h - 3], fill=255)
    d.ellipse([3, 3, w - 4, 13], fill=255)
    d.polygon([(3, h - 3), (0, h - 1), (6, h - 6)], fill=255)
    d.polygon([(w - 4, h - 3), (w, h - 1), (w - 7, h - 6)], fill=255)
    im = wood(mask, rnd, wd)
    d2 = ImageDraw.Draw(im)
    d2.ellipse([5, 4, w - 6, 12], fill=hexc('#5a4630') + (255,), outline=wd[0] + (255,))
    d2.ellipse([8, 6, w - 9, 10], outline=hexc('#7a6244') + (255,))
    d2.ellipse([5, 4, w - 6, 12], outline=wd[0] + (255,))
    px = im.load()
    for k in range(5):
        x, y = rnd.randint(6, w - 7), rnd.randint(14, h - 4)
        if px[x, y][3]:
            px[x, y] = hexc('#8aa0c0') + (255,)
    return shadow(outline(im), 60)


# ------------------------------------------------------------------ strutture medie
def menhir(seed, pal, glow):
    rnd = random.Random(seed)
    w, h = 20, 38
    hf = hf_new(w, h)
    ell(hf, w / 2, h * .55, 7.5, 17, 7, 3.2)
    im = shade(hf, P(pal, "rock"), rnd, lk=.7, dither=.3)
    px = im.load()
    g = hexc(glow) + (255,)
    for k in range(rnd.randint(2, 3)):
        x, y = rnd.randint(7, 12), 10 + k * 8
        for dx, dy in ((0, 0), (1, 0), (0, 1), (-1, 1), (1, 2)):
            if 0 <= x + dx < w and px[x + dx, y + dy][3]:
                px[x + dx, y + dy] = g
    return shadow(outline(im), 60)


def column(seed, pal, broken=True):
    rnd = random.Random(seed)
    w, h = 20, 40
    cols = P(pal, "rock")
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px = im.load()
    top = rnd.randint(8, 18) if broken else 4
    for y in range(top, h - 4):
        for x in range(4, w - 4):
            t = (x - 4) / (w - 8)
            c = cols[3] if t < .2 else (cols[2] if t < .55 else (cols[1] if t < .85 else cols[0]))
            if broken and y < top + 3 and (x + y) % 3 == 0:
                continue
            px[x, y] = c + (255,)
    d = ImageDraw.Draw(im)
    d.rectangle([2, h - 6, w - 3, h - 3], fill=cols[2] + (255,))
    d.rectangle([2, h - 3, w - 3, h - 3], fill=cols[0] + (255,))
    if not broken:
        d.rectangle([2, 2, w - 3, 5], fill=cols[2] + (255,))
    # rubble
    for k in range(5):
        x, y = rnd.randint(1, w - 3), rnd.randint(h - 6, h - 2)
        d.rectangle([x, y, x + 2, y + 1], fill=cols[rnd.randint(0, 2)] + (255,))
    return shadow(outline(im), 60)


def ruin_wall(seed, pal, w=40):
    rnd = random.Random(seed)
    h = 32
    cols = P(pal, "rock")
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px = im.load()
    heights = []
    hcur = rnd.randint(14, 24)
    for x in range(w):
        if rnd.random() < .25:
            hcur = max(8, min(26, hcur + rnd.randint(-5, 5)))
        heights.append(hcur)
    for x in range(1, w - 1):
        for y in range(h - 4 - heights[x], h - 4):
            row, off = (y // 4), (4 if (y // 4) % 2 else 0)
            bx = (x + off) // 8
            c = cols[1 + ((bx * 7 + row * 3) % 3 == 0)]
            if y % 4 == 0 or (x + off) % 8 == 0:
                c = cols[0]
            if y == h - 4 - heights[x]:
                c = cols[3]
            if (x + row * 5) % 11 == 0 and y > h - 14:
                c = cols[3] if rnd.random() < .5 else c
            px[x, y] = c + (255,)
    if pal in ("cem", "cat", "for", "swa"):
        for x in range(w):
            for y in range(h - 4 - heights[min(x, w - 1)], h - 4):
                if rnd.random() < .05 and px[x, y][3]:
                    px[x, y] = hexc('#34523a') + (255,)
    return shadow(outline(im), 60)


def crystal(seed, pal):
    rnd = random.Random(seed)
    w, h = 28, 34
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    cols = [hexc('#3a5a8a'), hexc('#6a9ad0'), hexc('#a8d8ff'), hexc('#eaf8ff')] if pal == "ice" else \
        [hexc('#3a1a4a'), hexc('#6a3a9a'), hexc('#a870e0'), hexc('#f0d8ff')]
    for k in range(rnd.randint(3, 5)):
        cx = rnd.randint(7, w - 8)
        bw = rnd.randint(3, 5)
        top = rnd.randint(2, 14)
        d.polygon([(cx - bw, h - 4), (cx - bw + 1, top + 5), (cx, top), (cx + bw - 1, top + 5), (cx + bw, h - 4)], fill=cols[1] + (255,))
        d.polygon([(cx - bw, h - 4), (cx - bw + 1, top + 5), (cx, top), (cx, h - 4)], fill=cols[2] + (255,))
        d.line([cx - 1, top + 3, cx - 1, h - 8], fill=cols[3] + (255,))
        d.line([cx + bw - 1, top + 6, cx + bw - 1, h - 4], fill=cols[0] + (255,))
    return shadow(outline(im), 50)


def spire(seed):
    rnd = random.Random(seed)
    w, h = 24, 40
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    c = [hexc('#120c10'), hexc('#241a1e'), hexc('#3a2c32'), hexc('#5a4650')]
    for k in range(rnd.randint(2, 3)):
        cx = rnd.randint(6, w - 7)
        top = rnd.randint(3, 20)
        bw = rnd.randint(4, 6)
        d.polygon([(cx - bw, h - 3), (cx - 1, top), (cx + 1, top), (cx + bw, h - 3)], fill=c[1] + (255,))
        d.polygon([(cx - bw, h - 3), (cx - 1, top), (cx, top), (cx - 1, h - 3)], fill=c[3] + (255,))
        d.polygon([(cx + 2, top + 8), (cx + bw, h - 3), (cx + 1, h - 3)], fill=c[0] + (255,))
        for j in range(rnd.randint(1, 3)):
            y = rnd.randint(top + 6, h - 6)
            d.line([cx - 2, y, cx + 1, y + 2], fill=hexc('#ff6a1a') + (255,))
    return shadow(outline(im), 60)


def anvil():
    w, h = 24, 20
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    m = [hexc('#14121a'), hexc('#2c2a38'), hexc('#4a4858'), hexc('#78768a')]
    d.polygon([(2, 5), (21, 5), (17, 9), (7, 9)], fill=m[2] + (255,))
    d.rectangle([2, 4, 21, 5], fill=m[3] + (255,))
    d.polygon([(21, 5), (23, 7), (21, 7)], fill=m[2] + (255,))
    d.rectangle([8, 9, 16, 13], fill=m[1] + (255,))
    d.rectangle([5, 13, 19, 16], fill=m[2] + (255,))
    d.rectangle([5, 16, 19, 16], fill=m[0] + (255,))
    d.point((10, 4), fill=hexc('#ff7a20') + (255,))
    return shadow(outline(im), 60)


def cross_grave(seed, pal):
    rnd = random.Random(seed)
    w, h = 20, 34
    cols = P(pal, "rock")
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rectangle([9, 3, 11, 26], fill=cols[2] + (255,))
    d.rectangle([4, 9, 16, 11], fill=cols[2] + (255,))
    d.rectangle([9, 3, 9, 26], fill=cols[3] + (255,))
    d.rectangle([4, 9, 16, 9], fill=cols[3] + (255,))
    d.rectangle([11, 4, 11, 26], fill=cols[0] + (255,))
    d.rectangle([5, 25, 15, 30], fill=cols[1] + (255,))
    d.rectangle([5, 25, 15, 25], fill=cols[3] + (255,))
    d.ellipse([3, 29, 17, 33], fill=cols[0] + (200,))
    for k in range(4):
        x, y = rnd.randint(5, 15), rnd.randint(22, 31)
        d.point((x, y), fill=hexc('#34523a') + (255,))
    return shadow(outline(im), 50)


def angel(seed, pal):
    rnd = random.Random(seed)
    w, h = 26, 42
    cols = P(pal, "rock")
    hf = hf_new(w, h)
    ell(hf, w / 2, 24, 5, 12, 6)                  # corpo
    ell(hf, w / 2, 9, 4, 4.5, 5)                   # testa
    ell(hf, 5.5, 22, 4.5, 12, 4)                   # ali
    ell(hf, 20.5, 22, 4.5, 12, 4)
    ell(hf, w / 2, 37, 9, 3.5, 5)                  # base
    im = shade(hf, cols, rnd, lk=.7, dither=.3)
    px = im.load()
    for x, y in ((11, 9), (15, 9)):
        px[x, y] = hexc('#14101a') + (255,)
    px[11, 12] = hexc('#9ab0d0') + (255,)           # lacrima
    return shadow(outline(im), 60)


def gallows():
    w, h = 40, 52
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    wd = [hexc('#1a1210'), hexc('#2e2018'), hexc('#4e3828')]
    d.rectangle([6, 8, 9, h - 3], fill=wd[1] + (255,))
    d.rectangle([6, 8, 6, h - 3], fill=wd[2] + (255,))
    d.rectangle([9, 8, 9, h - 3], fill=wd[0] + (255,))
    d.rectangle([6, 6, 32, 9], fill=wd[1] + (255,))
    d.rectangle([6, 6, 32, 6], fill=wd[2] + (255,))
    d.line([9, 22, 18, 9], fill=wd[1] + (255,))
    d.line([27, 10, 27, 24], fill=hexc('#6a5a44') + (255,))
    d.ellipse([24, 24, 30, 30], outline=hexc('#6a5a44') + (255,))
    d.rectangle([2, h - 5, 14, h - 3], fill=wd[1] + (255,))
    return shadow(outline(im), 60)


def wagon(seed):
    rnd = random.Random(seed)
    w, h = 44, 30
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    wd = [hexc('#1a1210'), hexc('#2e2018'), hexc('#4e3828'), hexc('#6a4e38')]
    d.rectangle([6, 8, 36, 20], fill=wd[1] + (255,))
    for x in range(8, 36, 5):
        d.line([x, 8, x, 20], fill=wd[0] + (255,))
    d.rectangle([6, 8, 36, 9], fill=wd[3] + (255,))
    d.rectangle([6, 20, 36, 21], fill=wd[0] + (255,))
    d.polygon([(30, 8), (36, 8), (36, 3), (33, 5)], fill=wd[2] + (255,))   # asse rotto
    d.ellipse([2, 16, 14, 28], outline=wd[3] + (255,), fill=wd[0] + (255,))
    d.line([8, 16, 8, 28], fill=wd[3] + (255,))
    d.line([2, 22, 14, 22], fill=wd[3] + (255,))
    d.ellipse([30, 18, 42, 28], outline=wd[2] + (255,))                   # ruota rotta
    d.line([36, 18, 36, 23], fill=wd[2] + (255,))
    d.line([36, 8, 42, 4], fill=wd[2] + (255,))                           # timone
    return shadow(outline(im), 60)


def well(seed, pal):
    w, h = 28, 34
    cols = P(pal, "rock")
    wd = P(pal, "wood")
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rectangle([4, 20, 23, 29], fill=cols[2] + (255,))
    for y in (22, 25, 28):
        d.line([4, y, 23, y], fill=cols[0] + (255,))
    d.rectangle([4, 20, 23, 20], fill=cols[3] + (255,))
    d.ellipse([4, 16, 23, 24], fill=cols[2] + (255,), outline=cols[3] + (255,))
    d.ellipse([7, 18, 20, 23], fill=(8, 6, 14, 255))
    d.rectangle([5, 6, 6, 21], fill=wd[1] + (255,))
    d.rectangle([21, 6, 22, 21], fill=wd[1] + (255,))
    d.polygon([(2, 8), (14, 1), (26, 8)], fill=wd[2] + (255,), outline=wd[0] + (255,))
    d.line([14, 8, 14, 17], fill=hexc('#8a7a5a') + (255,))
    d.rectangle([12, 16, 16, 19], fill=wd[0] + (255,))
    return shadow(outline(im), 60)


def tent(seed, col):
    rnd = random.Random(seed)
    w, h = 40, 32
    c = [hexc(x) for x in col]
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.polygon([(2, h - 3), (w // 2, 3), (w - 2, h - 3)], fill=c[1] + (255,))
    d.polygon([(2, h - 3), (w // 2, 3), (w // 2, h - 3)], fill=c[2] + (255,))
    d.polygon([(w // 2 + 4, h - 3), (w // 2, 3), (w - 2, h - 3)], fill=c[0] + (255,))
    d.polygon([(w // 2 - 4, h - 3), (w // 2, 14), (w // 2 + 4, h - 3)], fill=(10, 6, 14, 255))
    for k in range(3):
        x, y = rnd.randint(8, w - 9), rnd.randint(10, h - 8)
        d.rectangle([x, y, x + 3, y + 2], fill=(10, 6, 14, 255))
    d.line([w // 2, 1, w // 2, 4], fill=hexc('#6a4a2a') + (255,))
    return shadow(outline(im), 60)


def lamppost():
    w, h = 12, 40
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    m = [hexc('#14121a'), hexc('#2c2a38'), hexc('#4a4858')]
    d.rectangle([5, 12, 6, h - 3], fill=m[1] + (255,))
    d.rectangle([5, 12, 5, h - 3], fill=m[2] + (255,))
    d.rectangle([2, 3, 9, 12], fill=m[0] + (255,))
    d.rectangle([3, 4, 8, 11], fill=hexc('#ffb040') + (255,))
    d.rectangle([4, 6, 7, 9], fill=hexc('#fff0b0') + (255,))
    d.polygon([(1, 3), (6, 0), (10, 3)], fill=m[1] + (255,))
    d.rectangle([3, h - 4, 8, h - 3], fill=m[1] + (255,))
    return shadow(outline(im), 60)


def scarecrow():
    w, h = 24, 36
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    wd = [hexc('#1a1210'), hexc('#3a2a20'), hexc('#5a4432')]
    d.rectangle([11, 10, 12, h - 3], fill=wd[1] + (255,))
    d.rectangle([2, 14, w - 3, 15], fill=wd[1] + (255,))
    d.rectangle([5, 14, 18, 24], fill=hexc('#4a3c24') + (255,))
    d.polygon([(5, 24), (18, 24), (16, 28), (7, 28)], fill=hexc('#3a2e1c') + (255,))
    d.ellipse([8, 4, 15, 11], fill=hexc('#6a5a3a') + (255,))
    d.rectangle([6, 3, 17, 4], fill=hexc('#2a2030') + (255,))
    d.rectangle([9, 0, 14, 3], fill=hexc('#2a2030') + (255,))
    for x in (10, 13):
        d.point((x, 7), fill=(10, 6, 14, 255))
    d.point((11, 9), fill=(10, 6, 14, 255))
    d.point((12, 9), fill=(10, 6, 14, 255))
    for k in range(4):
        d.line([2 + k, 15, 1 + k, 20], fill=hexc('#8a7648') + (255,))
        d.line([w - 3 - k, 15, w - 2 - k, 20], fill=hexc('#8a7648') + (255,))
    return shadow(outline(im), 60)


# ------------------------------------------------------------------ edifici
def brick(d, x0, y0, x1, y1, cols, rnd, bw=7, bh=4):
    row = 0
    for y in range(y0, y1, bh):
        off = (bw // 2) if row % 2 else 0
        for x in range(x0 - off, x1, bw):
            c = cols[1 + (rnd.random() < .3)]
            xa, xb = max(x0, x + 1), min(x1 - 1, x + bw - 1)
            ya, yb = y + 1, min(y1 - 1, y + bh - 1)
            if xb < xa or yb < ya:
                continue
            d.rectangle([xa, ya, xb, yb], fill=c + (255,))
            d.line([xa, ya, xb, ya], fill=cols[2] + (255,))
        d.line([x0, y, x1, y], fill=cols[0] + (255,))
        row += 1


def house(seed, pal="vil", roof=None, w=56):
    rnd = random.Random(seed)
    cols = P(pal, "rock")
    wd = P(pal, "wood")
    rc = roof or [hexc('#14101c'), hexc('#241c34'), hexc('#3a2e52'), hexc('#54467a')]
    H = 70
    im = Image.new("RGBA", (w, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    wx0, wx1 = 6, w - 6
    wy0, wy1 = 36, H - 4
    # muro in pietra + travi
    brick(d, wx0, wy0, wx1, wy1, cols, rnd)
    d.rectangle([wx0, wy0, wx1, wy0 + 1], fill=wd[0] + (255,))
    for x in range(wx0, wx1 + 1, 10):
        d.rectangle([x, wy0, x + 1, wy1], fill=wd[1] + (255,))
        d.line([x, wy0, x, wy1], fill=wd[2] + (255,))
    # fuliggine in alto
    px = im.load()
    for y in range(wy0, wy0 + 8):
        for x in range(wx0, wx1):
            if px[x, y][3] and rnd.random() < (8 - (y - wy0)) / 12:
                px[x, y] = tuple(int(v * .5) for v in px[x, y][:3]) + (255,)
    # porta ad arco e finestre luminose
    dx = w // 2 - 5
    d.rectangle([dx, wy1 - 16, dx + 9, wy1], fill=(8, 6, 14, 255))
    d.ellipse([dx, wy1 - 21, dx + 9, wy1 - 11], fill=(8, 6, 14, 255))
    d.rectangle([dx - 1, wy1 - 16, dx - 1, wy1], fill=wd[2] + (255,))
    for wx in (wx0 + 4, wx1 - 12):
        d.rectangle([wx, wy0 + 8, wx + 7, wy0 + 17], fill=(8, 6, 14, 255))
        lit = rnd.random() < .75
        d.rectangle([wx + 1, wy0 + 9, wx + 6, wy0 + 16], fill=(hexc('#ffb040') if lit else (14, 10, 20)) + (255,))
        if lit:
            d.rectangle([wx + 2, wy0 + 10, wx + 5, wy0 + 13], fill=hexc('#fff0b0') + (255,))
        d.line([wx + 3, wy0 + 8, wx + 3, wy0 + 17], fill=(8, 6, 14, 255))
        d.line([wx, wy0 + 12, wx + 7, wy0 + 12], fill=(8, 6, 14, 255))
    # tetto spiovente (visto da davanti), con buchi e travi a vista
    tx0, tx1 = 1, w - 2
    d.polygon([(tx0, wy0 + 2), (tx1, wy0 + 2), (tx1 - 10, 8), (tx0 + 10, 8)], fill=rc[1] + (255,))
    for y in range(8, wy0 + 2, 4):
        inset = int(10 * (y - 8) / (wy0 - 6))
        d.line([tx0 + 10 - inset, y, tx1 - 10 + inset, y], fill=rc[0] + (255,))
        off = 3 if (y // 4) % 2 else 0
        for x in range(tx0 + 10 - inset + off, tx1 - 10 + inset, 6):
            d.line([x, y, x, y + 3], fill=rc[0] + (255,))
            d.point((x + 2, y + 1), fill=rc[2] + (255,))
    d.line([tx0 + 10, 8, tx1 - 10, 8], fill=rc[3] + (255,))
    d.line([tx0, wy0 + 2, tx1, wy0 + 2], fill=rc[0] + (255,))
    d.line([tx0, wy0 + 1, tx0 + 10, 9], fill=rc[3] + (255,))
    for k in range(rnd.randint(2, 4)):
        hx, hy = rnd.randint(tx0 + 14, tx1 - 20), rnd.randint(13, wy0 - 6)
        d.rectangle([hx, hy, hx + rnd.randint(5, 9), hy + rnd.randint(4, 6)], fill=(10, 6, 14, 255))
        d.line([hx, hy, hx + 7, hy], fill=wd[2] + (255,))
    # camino
    cx = rnd.choice([tx0 + 16, tx1 - 22])
    d.rectangle([cx, 2, cx + 7, 18], fill=cols[1] + (255,))
    d.rectangle([cx, 2, cx + 1, 18], fill=cols[3] + (255,))
    d.rectangle([cx + 6, 2, cx + 7, 18], fill=cols[0] + (255,))
    d.rectangle([cx - 1, 1, cx + 8, 3], fill=cols[2] + (255,))
    # edera
    for k in range(rnd.randint(10, 18)):
        x, y = rnd.choice([wx0 + 1, wx1 - 2]) + rnd.randint(-1, 1), rnd.randint(wy0, wy1 - 3)
        d.point((x, y), fill=hexc('#34523a') + (255,))
        d.point((x, y + 1), fill=hexc('#245030') + (255,))
    return shadow(outline(im), 80)


def chapel(seed, pal="cem"):
    rnd = random.Random(seed)
    cols = P(pal, "rock")
    wd = P(pal, "wood")
    rc = [hexc('#14101c'), hexc('#241c34'), hexc('#3a2e52'), hexc('#54467a')]
    w, H = 84, 96
    im = Image.new("RGBA", (w, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    # navata
    brick(d, 22, 52, 78, H - 4, cols, rnd, 8, 4)
    # contrafforti
    for x in (22, 46, 70):
        d.rectangle([x - 2, 44, x + 3, H - 4], fill=cols[2] + (255,))
        d.rectangle([x - 2, 44, x - 2, H - 4], fill=cols[3] + (255,))
        d.rectangle([x + 3, 44, x + 3, H - 4], fill=cols[0] + (255,))
    # finestre ogivali con vetri
    for x in (30, 54):
        d.rectangle([x, 62, x + 8, 82], fill=(8, 6, 14, 255))
        d.ellipse([x, 57, x + 8, 67], fill=(8, 6, 14, 255))
        for j, col in enumerate(['#8a2a4a', '#4a3a9a', '#c8802a']):
            d.rectangle([x + 1 + j * 2 + (1 if j else 0), 60 + j, x + 2 + j * 2 + (1 if j else 0), 80], fill=hexc(col) + (255,))
    # tetto crollato
    d.polygon([(18, 54), (82, 54), (74, 28), (26, 28)], fill=rc[1] + (255,))
    for y in range(28, 54, 4):
        d.line([22, y, 78, y], fill=rc[0] + (255,))
    d.line([26, 28, 74, 28], fill=rc[3] + (255,))
    for k in range(4):
        hx, hy = rnd.randint(30, 66), rnd.randint(32, 46)
        d.rectangle([hx, hy, hx + rnd.randint(6, 12), hy + rnd.randint(5, 8)], fill=(10, 6, 14, 255))
        d.line([hx, hy, hx + 9, hy + 6], fill=wd[2] + (255,))
    # campanile spezzato
    brick(d, 2, 18, 24, H - 4, cols, rnd, 7, 4)
    d.rectangle([2, 18, 3, H - 4], fill=cols[3] + (255,))
    d.rectangle([22, 18, 23, H - 4], fill=cols[0] + (255,))
    for y in range(14, 20):
        for x in range(2, 24):
            if (x // 3 + y) % 2 == 0:
                d.point((x, y), fill=(0, 0, 0, 0))
    d.rectangle([9, 28, 16, 46], fill=(8, 6, 14, 255))
    d.ellipse([9, 23, 16, 33], fill=(8, 6, 14, 255))
    d.rectangle([11, 36, 14, 44], fill=hexc('#6a3a9a') + (255,))
    d.rectangle([7, 62, 18, 66], fill=cols[2] + (255,))
    # portale e rosone
    d.rectangle([44, H - 24, 56, H - 4], fill=(8, 6, 14, 255))
    d.ellipse([44, H - 30, 56, H - 18], fill=(8, 6, 14, 255))
    d.ellipse([42, 38, 58, 54], fill=cols[1] + (255,), outline=cols[3] + (255,))
    for j in range(8):
        a = j * math.pi / 4
        d.line([50, 46, 50 + 7 * math.cos(a), 46 + 7 * math.sin(a)], fill=hexc(['#c8283c', '#6a3aa0', '#d89030', '#2a6aa0'][j % 4]) + (255,))
    d.ellipse([49, 45, 51, 47], fill=hexc('#fff0b0') + (255,))
    # croce spezzata
    d.rectangle([60, 18, 61, 28], fill=cols[3] + (255,))
    d.rectangle([57, 21, 64, 22], fill=cols[3] + (255,))
    return shadow(outline(im), 90)


def mausoleum(seed, pal="cem"):
    rnd = random.Random(seed)
    cols = P(pal, "rock")
    w, H = 60, 60
    im = Image.new("RGBA", (w, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    brick(d, 6, 26, 54, H - 4, cols, rnd, 8, 4)
    d.polygon([(2, 28), (30, 6), (58, 28)], fill=cols[2] + (255,))
    d.polygon([(2, 28), (30, 6), (30, 28)], fill=cols[3] + (255,))
    d.polygon([(30, 6), (58, 28), (50, 28), (30, 12)], fill=cols[1] + (255,))
    d.line([2, 28, 58, 28], fill=cols[0] + (255,))
    for x in (8, 22, 36, 50):
        d.rectangle([x, 28, x + 3, H - 4], fill=cols[3] + (255,))
        d.rectangle([x + 3, 28, x + 3, H - 4], fill=cols[0] + (255,))
    d.rectangle([24, 36, 36, H - 4], fill=(8, 6, 14, 255))
    d.ellipse([24, 31, 36, 41], fill=(8, 6, 14, 255))
    for x in range(26, 36, 2):
        d.line([x, 36, x, H - 5], fill=hexc('#3a3848') + (255,))
    d.rectangle([20, H - 6, 40, H - 4], fill=cols[2] + (255,))
    d.ellipse([27, 14, 33, 20], fill=(8, 6, 14, 255))
    d.line([30, 15, 30, 19], fill=hexc('#a8a8c8') + (255,))
    d.line([28, 16, 32, 16], fill=hexc('#a8a8c8') + (255,))
    return shadow(outline(im), 80)


def tower(seed, pal="cat"):
    rnd = random.Random(seed)
    cols = P(pal, "rock")
    w, H = 40, 84
    im = Image.new("RGBA", (w, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    brick(d, 5, 18, 35, H - 4, cols, rnd, 7, 4)
    d.rectangle([5, 18, 7, H - 4], fill=cols[3] + (255,))
    d.rectangle([33, 18, 35, H - 4], fill=cols[0] + (255,))
    for x in range(5, 36, 6):
        h0 = rnd.randint(8, 14)
        d.rectangle([x, h0, x + 3, 19], fill=cols[2] + (255,), outline=cols[0] + (255,))
    for y in (34, 52):
        d.rectangle([18, y, 21, y + 8], fill=(8, 6, 14, 255))
        d.rectangle([19, y + 2, 20, y + 6], fill=hexc('#ffb040') + (255,))
    d.rectangle([14, H - 20, 25, H - 4], fill=(8, 6, 14, 255))
    d.ellipse([14, H - 26, 25, H - 15], fill=(8, 6, 14, 255))
    for k in range(10):
        x, y = rnd.choice([6, 7, 33, 34]), rnd.randint(30, H - 6)
        d.point((x, y), fill=hexc('#34523a') + (255,))
    return shadow(outline(im), 80)


def stilt_hut(seed):
    rnd = random.Random(seed)
    w, H = 60, 66
    wd = [hexc('#1c1812'), hexc('#302a1e'), hexc('#504430'), hexc('#6a5a40')]
    im = Image.new("RGBA", (w, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    for x in (10, 22, 38, 50):
        d.rectangle([x, 44, x + 2, H - 3], fill=wd[1] + (255,))
        d.line([x, 44, x, H - 3], fill=wd[2] + (255,))
    d.line([10, 56, 50, 52], fill=wd[1] + (255,))
    d.rectangle([6, 28, 54, 44], fill=wd[1] + (255,))
    for x in range(8, 54, 4):
        d.line([x, 28, x, 44], fill=wd[0] + (255,))
    d.rectangle([6, 44, 54, 46], fill=wd[2] + (255,))
    d.rectangle([24, 32, 34, 44], fill=(8, 6, 14, 255))
    d.rectangle([40, 33, 48, 40], fill=(8, 6, 14, 255))
    d.rectangle([41, 34, 47, 39], fill=hexc('#6aff9a') + (255,))
    th = [hexc('#2a2410'), hexc('#4a4018'), hexc('#6a5a28')]
    d.polygon([(2, 30), (58, 30), (46, 6), (14, 6)], fill=th[1] + (255,))
    for y in range(6, 30, 3):
        for x in range(8, 52, 3):
            if rnd.random() < .5:
                d.point((x + rnd.randint(-2, 2), y), fill=th[rnd.randint(0, 2)] + (255,))
    d.line([14, 6, 46, 6], fill=th[2] + (255,))
    d.line([2, 30, 58, 30], fill=th[0] + (255,))
    for k in range(10):
        d.point((rnd.randint(4, 56), rnd.randint(8, 29)), fill=hexc('#34523a') + (255,))
    return shadow(outline(im), 70)


def smithy(seed):
    rnd = random.Random(seed)
    cols = P("frg", "rock")
    w, H = 64, 72
    im = Image.new("RGBA", (w, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    brick(d, 6, 34, 58, H - 4, cols, rnd, 8, 4)
    d.polygon([(2, 36), (62, 36), (54, 18), (10, 18)], fill=hexc('#241a1e') + (255,))
    for y in range(18, 36, 4):
        d.line([10, y, 54, y], fill=hexc('#120c10') + (255,))
    d.line([10, 18, 54, 18], fill=hexc('#5a4650') + (255,))
    d.rectangle([40, 2, 52, 24], fill=cols[1] + (255,))
    d.rectangle([40, 2, 42, 24], fill=cols[3] + (255,))
    d.rectangle([39, 1, 53, 4], fill=cols[2] + (255,))
    d.rectangle([43, 2, 50, 3], fill=hexc('#ff6a1a') + (255,))
    d.rectangle([12, 44, 30, H - 4], fill=(8, 4, 8, 255))
    d.rectangle([14, 52, 28, H - 6], fill=hexc('#c8300e') + (255,))
    d.rectangle([17, 58, 25, H - 7], fill=hexc('#ff9a30') + (255,))
    d.rectangle([20, 62, 22, H - 8], fill=hexc('#fff0a0') + (255,))
    d.rectangle([40, 48, 52, 60], fill=(8, 4, 8, 255))
    for k in range(6):
        d.point((rnd.randint(8, 56), rnd.randint(36, H - 6)), fill=hexc('#ff6a1a') + (255,))
    return shadow(outline(im), 80)


def stall(seed):
    rnd = random.Random(seed)
    w, h = 40, 36
    wd = [hexc('#1a1210'), hexc('#2e2018'), hexc('#4e3828'), hexc('#6a4e38')]
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rectangle([4, 10, 5, h - 3], fill=wd[1] + (255,))
    d.rectangle([34, 10, 35, h - 3], fill=wd[1] + (255,))
    d.rectangle([4, 22, 35, 28], fill=wd[2] + (255,))
    d.rectangle([4, 22, 35, 22], fill=wd[3] + (255,))
    d.polygon([(1, 12), (38, 12), (34, 3), (5, 3)], fill=hexc('#6a1424') + (255,))
    for x in range(3, 38, 6):
        d.polygon([(x, 12), (x + 3, 12), (x + 1, 16)], fill=hexc('#6a1424') + (255,))
        d.rectangle([x, 4, x + 2, 11], fill=hexc('#8a1c30') + (255,))
    for k in range(5):
        x = rnd.randint(7, 30)
        d.rectangle([x, 19, x + 3, 22], fill=rnd.choice([hexc('#8a6a2a'), hexc('#4a6a3a'), hexc('#a89060')]) + (255,))
    return shadow(outline(im), 60)


# ------------------------------------------------------------------ generazione
FAMILY = {}   # nome -> numero varianti (per il preview e per Godot)


def put(name, im):
    save(im, name)
    return name


def main():
    out = []
    for pal in PALS:
        for i in range(10):
            out.append(put(f"grass_{pal}_{i}", grass(i * 3 + sum(map(ord, pal)) % 50, pal)))
        for i in range(8):
            out.append(put(f"tall_{pal}_{i}", grass(i * 5 + 11 + sum(map(ord, pal)) % 40, pal, True)))
        for i in range(8):
            out.append(put(f"shrub_{pal}_{i}", shrub(i * 7 + 2 + sum(map(ord, pal)) % 30, pal)))
        for i in range(10):
            out.append(put(f"pebble_{pal}_{i}", rocks(i * 3 + 5 + sum(map(ord, pal)) % 20, pal)))
        for i in range(8):
            out.append(put(f"boulder_{pal}_{i}", rocks(i * 9 + 1 + sum(map(ord, pal)) % 20, pal, True)))
        for i in range(2):
            out.append(put(f"log_{pal}_{i}", log_(i * 4 + 3, pal)))
            out.append(put(f"stump_{pal}_{i}", stump(i * 6 + 1, pal)))
        for i in range(2):
            out.append(put(f"ruinwall_{pal}_{i}", ruin_wall(i * 8 + 3, pal)))
            out.append(put(f"column_{pal}_{i}", column(i * 5 + 2, pal, True)))
        out.append(put(f"cross_{pal}", cross_grave(3, pal)))
        out.append(put(f"well_{pal}", well(2, pal)))
    for i, k in enumerate(["glow", "purple", "red"]):
        for j in range(6):
            out.append(put(f"mush_{k}_{j}", mushrooms(i * 10 + j, k)))
    for k in ("skull", "ribs", "bones"):
        for j in range(5):
            out.append(put(f"bone_{k}_{j}", bones(j + 1, k)))
    for i, c in enumerate(['#8a4ac0', '#c8283c', '#e0e0f0', '#d8a830']):
        out.append(put(f"flower_{i}", flower(i + 5, c)))
        for j in range(4):
            out.append(put(f"flower_{i}_{j}", flower(i * 7 + j + 20, c)))
    for j in range(6):
        out.append(put(f"reeds_{j}", reeds(j * 3 + 1)))
    for j in range(2):
        out.append(put(f"menhir_cem_{j}", menhir(j * 4 + 1, "cem", '#7aa0ff')))
        out.append(put(f"menhir_ice_{j}", menhir(j * 4 + 9, "ice", '#a8f0ff')))
        out.append(put(f"menhir_cat_{j}", menhir(j * 4 + 5, "cat", '#d890ff')))
        out.append(put(f"crystal_ice_{j}", crystal(j * 3 + 2, "ice")))
        out.append(put(f"crystal_cat_{j}", crystal(j * 3 + 8, "cat")))
        out.append(put(f"spire_{j}", spire(j * 5 + 3)))
        out.append(put(f"angel_{j}", angel(j + 1, "cem" if j == 0 else "cat")))
    out.append(put("anvil", anvil()))
    out.append(put("gallows", gallows()))
    out.append(put("scarecrow", scarecrow()))
    out.append(put("lamppost", lamppost()))
    for j in range(2):
        out.append(put(f"wagon_{j}", wagon(j + 1)))
    out.append(put("tent_0", tent(1, ['#2a2418', '#4a4028', '#6a5c38'])))
    out.append(put("tent_1", tent(2, ['#2a1418', '#4a2028', '#6a3038'])))
    out.append(put("tent_2", tent(3, ['#1c2418', '#2c3a28', '#445a3c'])))
    for j in range(2):
        out.append(put(f"stall_{j}", stall(j + 1)))
    # edifici
    out.append(put("house_0", house(1, "vil")))
    out.append(put("house_1", house(2, "vil", w=48)))
    out.append(put("house_2", house(3, "vil", [hexc('#20100c'), hexc('#3a1c14'), hexc('#5a2c20'), hexc('#7a4030')], w=60)))
    out.append(put("house_ice", house(4, "ice", [hexc('#3a4a6a'), hexc('#6a82a8'), hexc('#a8c0dc'), hexc('#f0f8ff')], w=52)))
    out.append(put("house_swa", house(5, "swa", [hexc('#1c2410'), hexc('#2c3a18'), hexc('#44582a'), hexc('#607a3a')], w=52)))
    out.append(put("chapel_0", chapel(1, "cem")))
    out.append(put("chapel_1", chapel(2, "cat")))
    out.append(put("mausoleum_0", mausoleum(1, "cem")))
    out.append(put("mausoleum_1", mausoleum(2, "cat")))
    out.append(put("tower_0", tower(1, "cat")))
    out.append(put("tower_ice", tower(2, "ice")))
    out.append(put("stilt_hut", stilt_hut(1)))
    out.append(put("smithy", smithy(1)))

    # anteprima a griglia
    ims = [(n, Image.open(os.path.join(OUT, n + ".png"))) for n in out]
    Wd = 1900
    x = y = 4
    rowh = 0
    sheet = Image.new("RGB", (Wd, 3000), (22, 18, 30))
    for n, im in ims:
        im2 = im.resize((im.width * 2, im.height * 2), Image.NEAREST)
        if x + im2.width + 4 > Wd:
            x = 4
            y += rowh + 6
            rowh = 0
        sheet.paste(im2, (x, y), im2)
        x += im2.width + 6
        rowh = max(rowh, im2.height)
    sheet.crop((0, 0, Wd, y + rowh + 6)).save(os.path.join(OUT, "..", "scenery_preview.png"))
    print(len(out), "sprite")


main()
