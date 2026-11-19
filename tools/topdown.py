"""Kit di strutture VISTE DALL'ALTO (top-down vero): tetti, chiome, tombe, recinti, pozzi, bancarelle, carri...
Luce da alto-sinistra, ombra in basso a destra. Uso: python topdown.py <cartella_sprites>
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
T = 16

ROOFS = {
    "slate": ['#120e1a', '#201a30', '#352c4c', '#52467a'],
    "rust": ['#180c0e', '#2c1618', '#46242a', '#62343a'],
    "moss": ['#0c140e', '#16241a', '#243a24', '#385636'],
    "wood": ['#140e0c', '#241a16', '#3a2c26', '#54443a'],
    "thatch": ['#1c170e', '#32291a', '#4e4128', '#6e5e3c'],
    "ice": ['#2c3a58', '#4a6088', '#7a96c0', '#c8dcf0'],
    "ash": ['#0e0a0c', '#1c1418', '#30242a', '#4a3a42'],
}
STONE = [hexc(c) for c in ['#1c1824', '#2c2838', '#423c54', '#5e5878']]


def C(h):
    return hexc(h) + (255,)


def new(w, h):
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


def shadowed(im, dx=3, dy=4, a=95):
    w, h = im.size
    out = new(w + dx, h + dy)
    sh = new(w, h)
    sp, ip = sh.load(), im.load()
    for y in range(h):
        for x in range(w):
            if ip[x, y][3]:
                sp[x, y] = (0, 0, 0, a)
    out.alpha_composite(sh, (dx, dy))
    out.alpha_composite(im)
    return out


def round_corners(im, r=2):
    w, h = im.size
    px = im.load()
    for k in range(r):
        for (x, y) in ((k, 0), (0, k), (w - 1 - k, 0), (w - 1, k), (k, h - 1), (0, h - 1 - k), (w - 1 - k, h - 1), (w - 1, h - 1 - k)):
            if k + (0 if (x in (0, w - 1) and y in (0, h - 1)) else 1) <= r - 1:
                px[x, y] = (0, 0, 0, 0)
    return im


def roof_rect(d, x0, y0, x1, y1, pal, rnd, horiz=None):
    """Tetto a doppia falda visto dall'alto: colmo al centro, falda illuminata in alto/sinistra."""
    W, H = x1 - x0, y1 - y0
    if horiz is None:
        horiz = W >= H
    p = [hexc(c) for c in pal]
    if horiz:
        mid = y0 + H // 2
        d.rectangle([x0, y0, x1 - 1, mid - 1], fill=p[2] + (255,))
        d.rectangle([x0, mid, x1 - 1, y1 - 1], fill=p[1] + (255,))
        for y in range(y0 + 2, mid, 3):
            d.line([x0, y, x1 - 1, y], fill=p[1] + (255,))
            off = 2 if ((y - y0) // 3) % 2 else 0
            for x in range(x0 + off, x1, 5):
                d.line([x, y, x, y + 1], fill=p[0] + (255,))
        for y in range(mid + 2, y1, 3):
            d.line([x0, y, x1 - 1, y], fill=p[0] + (255,))
            off = 2 if ((y - mid) // 3) % 2 else 0
            for x in range(x0 + off, x1, 5):
                d.point((x, y + 1), fill=p[2] + (255,))
        d.line([x0, mid - 1, x1 - 1, mid - 1], fill=p[3] + (255,))
        d.line([x0, mid, x1 - 1, mid], fill=p[0] + (255,))
        d.line([x0, y0, x1 - 1, y0], fill=p[3] + (255,))
        d.line([x0, y1 - 1, x1 - 1, y1 - 1], fill=p[0] + (255,))
    else:
        mid = x0 + W // 2
        d.rectangle([x0, y0, mid - 1, y1 - 1], fill=p[2] + (255,))
        d.rectangle([mid, y0, x1 - 1, y1 - 1], fill=p[1] + (255,))
        for x in range(x0 + 2, mid, 3):
            d.line([x, y0, x, y1 - 1], fill=p[1] + (255,))
            off = 2 if ((x - x0) // 3) % 2 else 0
            for y in range(y0 + off, y1, 5):
                d.line([x, y, x + 1, y], fill=p[0] + (255,))
        for x in range(mid + 2, x1, 3):
            d.line([x, y0, x, y1 - 1], fill=p[0] + (255,))
            off = 2 if ((x - mid) // 3) % 2 else 0
            for y in range(y0 + off, y1, 5):
                d.point((x + 1, y), fill=p[2] + (255,))
        d.line([mid - 1, y0, mid - 1, y1 - 1], fill=p[3] + (255,))
        d.line([mid, y0, mid, y1 - 1], fill=p[0] + (255,))
        d.line([x0, y0, x0, y1 - 1], fill=p[3] + (255,))
        d.line([x1 - 1, y0, x1 - 1, y1 - 1], fill=p[0] + (255,))
    return horiz


def damage(im, rnd, amount, pal):
    px = im.load()
    d = ImageDraw.Draw(im)
    w, h = im.size
    p = [hexc(c) for c in pal]
    for k in range(int(amount)):
        cx, cy = rnd.randint(4, w - 8), rnd.randint(4, h - 8)
        bw, bh = rnd.randint(4, 8), rnd.randint(3, 6)
        d.rectangle([cx, cy, cx + bw, cy + bh], fill=(10, 6, 14, 255))
        d.line([cx, cy + bh // 2, cx + bw, cy + bh // 2], fill=C('#4a3624'))
        d.line([cx + bw // 2, cy, cx + bw // 2, cy + bh], fill=C('#3a2a1c'))
        d.line([cx - 1, cy - 1, cx + bw + 1, cy - 1], fill=p[3] + (255,))
    for k in range(int(amount * 6)):
        x, y = rnd.randint(1, w - 2), rnd.randint(1, h - 2)
        if px[x, y][3] and px[x, y][:3] != (10, 6, 14):
            px[x, y] = C('#34523a') if rnd.random() < .6 else C('#2a4430')


def chimney(d, x, y, big=False):
    s = 7 if big else 6
    d.rectangle([x, y, x + s, y + s], fill=STONE[2] + (255,))
    d.rectangle([x, y, x + s, y], fill=STONE[3] + (255,))
    d.rectangle([x + s, y, x + s, y + s], fill=STONE[0] + (255,))
    d.rectangle([x + 2, y + 2, x + s - 2, y + s - 2], fill=(8, 6, 12, 255))


def house(wc, hc, roof, seed, dmg=2, chim=True):
    rnd = random.Random(seed)
    W, H = wc * T, hc * T
    im = new(W, H)
    d = ImageDraw.Draw(im)
    horiz = roof_rect(d, 0, 0, W, H, ROOFS[roof], rnd)
    if roof == "thatch":
        px = im.load()
        for y in range(H):
            for x in range(W):
                if rnd.random() < .2:
                    c = hexc(ROOFS[roof][rnd.randint(0, 3)])
                    px[x, y] = c + (255,)
    damage(im, rnd, dmg, ROOFS[roof])
    if chim:
        if horiz:
            chimney(d, rnd.randint(8, W - 16), H // 2 - 8 if rnd.random() < .5 else H // 2 + 1)
        else:
            chimney(d, W // 2 - 8 if rnd.random() < .5 else W // 2 + 1, rnd.randint(6, H - 14))
    im = round_corners(outline(im), 0)
    return shadowed(im)


def chapel(roof="slate", seed=1):
    """Cappella a croce: navata + transetto + torre con guglia piramidale."""
    rnd = random.Random(seed)
    W, H = 5 * T, 8 * T
    im = new(W, H)
    d = ImageDraw.Draw(im)
    pal = ROOFS[roof]
    roof_rect(d, 16, 2 * T, 64, 4 * T, pal, rnd, True)        # transetto
    roof_rect(d, 2 * T, 16, 3 * T + 16, 7 * T, pal, rnd, False)  # navata (verticale)
    # abside
    d.pieslice([2 * T, 0, 3 * T + 16, 40], 180, 360, fill=hexc(pal[2]) + (255,))
    # torre in basso con guglia piramidale
    tx, ty, ts = 2 * T + 4, 6 * T + 12, 24
    p = [hexc(c) for c in pal]
    d.rectangle([tx, ty, tx + ts, ty + ts], fill=STONE[1] + (255,))
    cx, cy = tx + ts // 2, ty + ts // 2
    d.polygon([(tx, ty), (tx + ts, ty), (cx, cy)], fill=p[3] + (255,))
    d.polygon([(tx, ty), (cx, cy), (tx, ty + ts)], fill=p[2] + (255,))
    d.polygon([(tx + ts, ty), (tx + ts, ty + ts), (cx, cy)], fill=p[1] + (255,))
    d.polygon([(tx, ty + ts), (tx + ts, ty + ts), (cx, cy)], fill=p[0] + (255,))
    d.line([cx, cy - 4, cx, cy + 3], fill=C('#c8c8d8'))
    d.line([cx - 3, cy - 1, cx + 3, cy - 1], fill=C('#c8c8d8'))
    damage(im, rnd, 3, pal)
    im = outline(im)
    return shadowed(im, 4, 5)


def tower_top(seed=1, pal=None):
    rnd = random.Random(seed)
    s = 3 * T
    im = new(s, s)
    d = ImageDraw.Draw(im)
    d.ellipse([0, 0, s - 1, s - 1], fill=STONE[2] + (255,))
    d.ellipse([6, 6, s - 7, s - 7], fill=(6, 4, 10, 255))
    d.ellipse([9, 9, s - 10, s - 10], fill=STONE[0] + (255,))
    for k in range(12):
        a = k * math.pi / 6
        x, y = s / 2 + math.cos(a) * 19, s / 2 + math.sin(a) * 19
        d.rectangle([x - 3, y - 3, x + 3, y + 3], fill=STONE[3] + (255,), outline=STONE[0] + (255,))
    for k in range(8):
        d.point((rnd.randint(3, s - 4), rnd.randint(3, s - 4)), fill=C('#34523a'))
    return shadowed(outline(im))


def canopy(seed, pal, size=40, dead=False, bw=3):
    rnd = random.Random(seed)
    W = H = size
    if dead:
        mask = Image.new("L", (W, H), 0)
        d = ImageDraw.Draw(mask)
        cx = cy = W // 2
        d.ellipse([cx - 3, cy - 3, cx + 3, cy + 3], fill=255)
        for k in range(rnd.randint(7, 10)):
            a = rnd.uniform(0, math.tau)
            branch(d, rnd, cx, cy, a, rnd.uniform(W * .28, W * .46), bw, 2)
        im = wood(mask, rnd, [hexc('#1e1620'), hexc('#34283a'), hexc('#5a4a62')])
        return shadowed(outline(im), 5, 6, 80)
    hf = [[0.0] * W for _ in range(H)]
    cx = cy = W / 2
    blobs = []
    for k in range(rnd.randint(9, 13)):
        a = rnd.uniform(0, math.tau)
        rr = rnd.uniform(0, W * .26)
        blobs.append((cx + math.cos(a) * rr, cy + math.sin(a) * rr, rnd.uniform(W * .14, W * .24)))
    for y in range(H):
        for x in range(W):
            best = 0.0
            for bx, by, r in blobs:
                dd = ((x - bx) ** 2 + (y - by) ** 2) / (r * r)
                if dd < 1:
                    best = max(best, math.sqrt(1 - dd) * r)
            if best > 0:
                best += 1.4 * math.sin(x * .9 + seed) * math.cos(y * .8) + rnd.uniform(-.5, .5)
            hf[y][x] = best
    im = new(W, H)
    px = im.load()
    cols = [hexc(c) for c in pal]
    for y in range(1, H - 1):
        for x in range(1, W - 1):
            if hf[y][x] <= 0.8:
                continue
            lit = (hf[y - 1][x - 1] - hf[y + 1][x + 1]) * 0.6 + (hf[y][x] - 5) * 0.07
            v = lit + (BAYER[y % 4][x % 4] / 16 - .5) * 0.5 + rnd.uniform(-.6, .6)
            px[x, y] = cols[3 if v > 1.2 else (2 if v > .2 else (1 if v > -.9 else 0))] + (255,)
    return shadowed(outline(im), 5, 6, 80)


def bush(seed, pal, size=18):
    return canopy(seed, pal, size)


GREEN = ['#0a1410', '#142418', '#1f3a28', '#34583a']
PURPLE = ['#120e1c', '#1e1a2e', '#2e2846', '#463e66']
SICK = ['#0a100a', '#121c10', '#1e2e18', '#32482a']
AUTUMN = ['#2a1008', '#4a2010', '#7a3a18', '#b8641e']
FROST = ['#2a3a5a', '#4a6a98', '#88aad0', '#e0eefa']


def grave(seed, kind):
    rnd = random.Random(seed)
    if kind == "mound":
        im = new(14, 22)
        d = ImageDraw.Draw(im)
        d.ellipse([1, 5, 12, 20], fill=C('#2a2018'))
        d.ellipse([2, 6, 8, 14], fill=C('#3a2e22'))
        d.rectangle([3, 1, 10, 5], fill=STONE[2] + (255,))
        d.rectangle([3, 1, 10, 1], fill=STONE[3] + (255,))
        d.rectangle([10, 1, 10, 5], fill=STONE[0] + (255,))
        d.line([6, 2, 6, 4], fill=STONE[0] + (255,))
        d.line([5, 3, 8, 3], fill=STONE[0] + (255,))
        for k in range(4):
            d.point((rnd.randint(3, 10), rnd.randint(9, 18)), fill=C('#34523a'))
    elif kind == "slab":
        im = new(14, 24)
        d = ImageDraw.Draw(im)
        d.rectangle([1, 1, 12, 22], fill=STONE[2] + (255,))
        d.rectangle([1, 1, 12, 1], fill=STONE[3] + (255,))
        d.rectangle([1, 1, 1, 22], fill=STONE[3] + (255,))
        d.rectangle([12, 1, 12, 22], fill=STONE[0] + (255,))
        d.rectangle([1, 22, 12, 22], fill=STONE[0] + (255,))
        d.line([7, 5, 7, 17], fill=STONE[0] + (255,))
        d.line([4, 8, 10, 8], fill=STONE[0] + (255,))
        for k in range(5):
            d.point((rnd.randint(2, 11), rnd.randint(2, 21)), fill=C('#34523a'))
    elif kind == "cross":
        im = new(16, 20)
        d = ImageDraw.Draw(im)
        d.rectangle([6, 2, 9, 15], fill=STONE[2] + (255,))
        d.rectangle([2, 5, 13, 8], fill=STONE[2] + (255,))
        d.rectangle([6, 2, 6, 15], fill=STONE[3] + (255,))
        d.rectangle([2, 5, 13, 5], fill=STONE[3] + (255,))
        d.rectangle([9, 2, 9, 15], fill=STONE[0] + (255,))
        d.ellipse([3, 15, 12, 19], fill=C('#2a2018'))
    else:  # obelisco
        im = new(12, 12)
        d = ImageDraw.Draw(im)
        d.rectangle([1, 1, 10, 10], fill=STONE[2] + (255,))
        d.polygon([(1, 1), (10, 1), (5, 5)], fill=STONE[3] + (255,))
        d.polygon([(1, 10), (10, 10), (5, 5)], fill=STONE[0] + (255,))
        d.polygon([(1, 1), (5, 5), (1, 10)], fill=STONE[2] + (255,))
    return shadowed(outline(im), 2, 3, 85)


def fence(kind, horizontal=True, iron=True):
    L = T
    if horizontal:
        im = new(L, 8)
        d = ImageDraw.Draw(im)
        col = STONE[1] if iron else hexc('#4a3624')
        hi = STONE[3] if iron else hexc('#6a4e36')
        d.rectangle([0, 3, L - 1, 4], fill=col + (255,))
        d.line([0, 3, L - 1, 3], fill=hi + (255,))
        for x in range(1, L, 4):
            d.rectangle([x, 1, x + 1, 6], fill=col + (255,))
            d.point((x, 1), fill=hi + (255,))
            if iron:
                d.point((x, 0), fill=hi + (255,))
    else:
        im = new(8, L)
        d = ImageDraw.Draw(im)
        col = STONE[1] if iron else hexc('#4a3624')
        hi = STONE[3] if iron else hexc('#6a4e36')
        d.rectangle([3, 0, 4, L - 1], fill=col + (255,))
        d.line([3, 0, 3, L - 1], fill=hi + (255,))
        for y in range(1, L, 4):
            d.rectangle([1, y, 6, y + 1], fill=col + (255,))
            d.point((1, y), fill=hi + (255,))
    return shadowed(im, 2, 2, 80)


def well():
    s = 28
    im = new(s, s)
    d = ImageDraw.Draw(im)
    d.ellipse([0, 0, s - 1, s - 1], fill=STONE[2] + (255,))
    for k in range(14):
        a = k * math.pi / 7
        d.line([s / 2 + math.cos(a) * 9, s / 2 + math.sin(a) * 9, s / 2 + math.cos(a) * 14, s / 2 + math.sin(a) * 14], fill=STONE[0] + (255,))
    d.ellipse([6, 6, s - 7, s - 7], fill=STONE[3] + (255,))
    d.ellipse([8, 8, s - 9, s - 9], fill=C('#0a1218'))
    d.ellipse([10, 10, 14, 13], fill=C('#1a3040'))
    d.rectangle([s // 2 - 1, 2, s // 2, s - 3], fill=C('#4a3624'))
    d.rectangle([s // 2 - 1, 2, s // 2 - 1, s - 3], fill=C('#6a4e36'))
    return shadowed(outline(im))


def stall(seed, colors):
    rnd = random.Random(seed)
    W, H = 36, 22
    im = new(W, H)
    d = ImageDraw.Draw(im)
    c1, c2 = hexc(colors[0]), hexc(colors[1])
    for x in range(0, W, 6):
        d.rectangle([x, 0, x + 2, H - 1], fill=c1 + (255,))
        d.rectangle([x + 3, 0, x + 5, H - 1], fill=c2 + (255,))
    d.line([0, 0, W - 1, 0], fill=C('#d8d0b4'))
    d.line([0, H - 1, W - 1, H - 1], fill=C('#1a1218'))
    for k in range(4):
        d.point((rnd.randint(2, W - 3), rnd.randint(2, H - 3)), fill=C('#2a1018'))
    return shadowed(outline(im))


def barrel():
    im = new(11, 11)
    d = ImageDraw.Draw(im)
    d.ellipse([0, 0, 10, 10], fill=C('#4a3220'))
    d.ellipse([1, 1, 9, 9], outline=C('#5a5a6c'))
    d.ellipse([3, 3, 7, 7], fill=C('#6a4e36'))
    d.line([5, 1, 5, 9], fill=C('#2a1a10'))
    d.point((3, 3), fill=C('#8a6a48'))
    return shadowed(outline(im), 2, 3, 85)


def crate():
    im = new(11, 11)
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, 10, 10], fill=C('#5a4026'))
    d.rectangle([0, 0, 10, 0], fill=C('#7a5a38'))
    d.rectangle([0, 0, 0, 10], fill=C('#7a5a38'))
    d.rectangle([10, 0, 10, 10], fill=C('#3a2616'))
    d.rectangle([0, 10, 10, 10], fill=C('#3a2616'))
    d.line([1, 1, 9, 9], fill=C('#3a2616'))
    d.line([9, 1, 1, 9], fill=C('#3a2616'))
    return shadowed(outline(im), 2, 3, 85)


def hay():
    im = new(14, 14)
    d = ImageDraw.Draw(im)
    d.ellipse([0, 0, 13, 13], fill=C('#8a7648'))
    d.ellipse([2, 2, 11, 11], fill=C('#a89060'))
    rnd = random.Random(4)
    for k in range(14):
        x, y = rnd.randint(2, 11), rnd.randint(2, 11)
        d.line([x, y, x + 2, y + 1], fill=C('#6a5834'))
    return shadowed(outline(im), 2, 3, 85)


def cart(seed):
    W, H = 44, 22
    im = new(W, H)
    d = ImageDraw.Draw(im)
    wd = [hexc('#1a1210'), hexc('#2e2018'), hexc('#4e3828'), hexc('#6a4e38')]
    d.rectangle([6, 3, 38, 17], fill=wd[1] + (255,))
    for x in range(8, 38, 5):
        d.line([x, 3, x, 17], fill=wd[0] + (255,))
    d.line([6, 3, 38, 3], fill=wd[3] + (255,))
    d.line([6, 3, 6, 17], fill=wd[3] + (255,))
    d.rectangle([2, 1, 9, 4], fill=C('#14101a'))
    d.rectangle([2, 16, 9, 19], fill=C('#14101a'))
    d.rectangle([34, 1, 41, 4], fill=C('#14101a'))
    d.rectangle([34, 16, 41, 19], fill=C('#14101a'))
    d.line([38, 10, 43, 10], fill=wd[2] + (255,))
    for k in range(5):
        d.rectangle([10 + k * 5, 6 + (k % 2) * 5, 12 + k * 5, 8 + (k % 2) * 5], fill=C('#8a7648'))
    return shadowed(outline(im))


def tent(seed, cols):
    W, H = 36, 30
    im = new(W, H)
    d = ImageDraw.Draw(im)
    c = [hexc(x) for x in cols]
    d.rectangle([0, 0, W - 1, H // 2 - 1], fill=c[2] + (255,))
    d.rectangle([0, H // 2, W - 1, H - 1], fill=c[0] + (255,))
    d.line([0, H // 2 - 1, W - 1, H // 2 - 1], fill=c[1] + (255,))
    d.line([0, H // 2, W - 1, H // 2], fill=(10, 6, 14, 255))
    rnd = random.Random(seed)
    for k in range(3):
        x, y = rnd.randint(2, W - 9), rnd.randint(2, H - 7)
        d.rectangle([x, y, x + 5, y + 3], fill=(10, 6, 14, 255))
    for x in (1, W - 2):
        d.rectangle([x, 0, x + 1, 1], fill=C('#6a4a2a'))
        d.rectangle([x, H - 2, x + 1, H - 1], fill=C('#6a4a2a'))
    return shadowed(outline(im))


def campfire():
    im = new(18, 18)
    d = ImageDraw.Draw(im)
    d.ellipse([0, 0, 17, 17], fill=C('#4a4858'))
    d.ellipse([2, 2, 15, 15], fill=C('#1a1218'))
    for a in (0, 1, 2):
        ang = a * math.pi / 3 + .4
        d.line([9 - math.cos(ang) * 6, 9 - math.sin(ang) * 6, 9 + math.cos(ang) * 6, 9 + math.sin(ang) * 6], fill=C('#4a3220'), width=2)
    d.ellipse([6, 6, 11, 11], fill=C('#ff6a1a'))
    d.ellipse([7, 7, 10, 10], fill=C('#ffd060'))
    return shadowed(outline(im), 2, 3, 70)


def stump_top(seed):
    rnd = random.Random(seed)
    im = new(16, 16)
    d = ImageDraw.Draw(im)
    d.ellipse([0, 0, 15, 15], fill=C('#2e2018'))
    d.ellipse([2, 2, 13, 13], fill=C('#5a4630'))
    d.ellipse([4, 4, 11, 11], outline=C('#7a6244'))
    d.ellipse([6, 6, 9, 9], outline=C('#3a2a1c'))
    for k in range(3):
        d.point((rnd.randint(3, 12), rnd.randint(3, 12)), fill=C('#8aa0c0'))
    return shadowed(outline(im), 2, 3, 80)


def log_top(seed):
    im = new(34, 12)
    d = ImageDraw.Draw(im)
    d.rectangle([3, 0, 30, 11], fill=C('#3a2a1c'))
    d.ellipse([0, 0, 8, 11], fill=C('#5a4630'))
    d.ellipse([26, 0, 33, 11], fill=C('#2e2018'))
    d.line([3, 3, 30, 3], fill=C('#5a4630'))
    d.line([3, 8, 30, 8], fill=C('#241810'))
    d.ellipse([2, 2, 6, 9], outline=C('#7a6244'))
    rnd = random.Random(seed)
    for k in range(5):
        d.point((rnd.randint(8, 28), rnd.randint(1, 10)), fill=C('#3a5a34'))
    return shadowed(outline(im), 2, 3, 80)


def ruin_wall_top(seed, horiz=True, n=3, pal=0):
    rnd = random.Random(seed)
    L = n * T
    im = new(L, 12) if horiz else new(12, L)
    px = im.load()
    w, h = im.size
    cols = STONE
    for y in range(h):
        for x in range(w):
            u = x if horiz else y
            v = y if horiz else x
            # bordi sbrecciati
            if rnd.random() < .06 and (v < 2 or v > 9):
                continue
            if (u > L - 4 or u < 3) and rnd.random() < .3:
                continue
            c = cols[2]
            if v < 2:
                c = cols[3]
            elif v > 8:
                c = cols[0]
            elif (u + (v // 4) * 5) % 9 == 0 or v % 4 == 0:
                c = cols[1]
            px[x, y] = c + (255,)
    for k in range(L // 4):
        x, y = rnd.randint(0, w - 1), rnd.randint(0, h - 1)
        if px[x, y][3] and rnd.random() < .5:
            px[x, y] = C('#34523a')
    return shadowed(outline(im), 3, 4, 85)


def column_top():
    im = new(14, 14)
    d = ImageDraw.Draw(im)
    d.ellipse([0, 0, 13, 13], fill=STONE[2] + (255,))
    d.ellipse([2, 2, 11, 11], fill=STONE[3] + (255,))
    d.ellipse([4, 4, 9, 9], fill=STONE[1] + (255,))
    d.point((6, 6), fill=STONE[0] + (255,))
    return shadowed(outline(im), 3, 4, 85)


def menhir_top(seed, glow):
    rnd = random.Random(seed)
    im = new(16, 18)
    d = ImageDraw.Draw(im)
    pts = [(3, 1), (12, 2), (15, 9), (11, 16), (4, 16), (1, 8)]
    d.polygon(pts, fill=STONE[2] + (255,))
    d.polygon([(3, 1), (12, 2), (8, 8), (1, 8)], fill=STONE[3] + (255,))
    d.polygon([(15, 9), (11, 16), (4, 16), (8, 9)], fill=STONE[0] + (255,))
    g = hexc(glow) + (255,)
    for dx, dy in ((0, 0), (1, 0), (0, 1), (-1, 1), (1, 2)):
        d.point((7 + dx, 6 + dy), fill=g)
    return shadowed(outline(im), 3, 4, 85)


def crystal_top(seed, cols):
    rnd = random.Random(seed)
    im = new(22, 22)
    d = ImageDraw.Draw(im)
    c = [hexc(x) for x in cols]
    for k in range(rnd.randint(4, 6)):
        cx, cy = rnd.randint(5, 16), rnd.randint(5, 16)
        r = rnd.randint(3, 5)
        pts = [(cx + r * math.cos(a), cy + r * math.sin(a)) for a in [i * math.pi / 3 for i in range(6)]]
        d.polygon(pts, fill=c[1] + (255,))
        d.polygon([pts[0], pts[1], (cx, cy)], fill=c[3] + (255,))
        d.polygon([pts[1], pts[2], (cx, cy)], fill=c[2] + (255,))
        d.polygon([pts[3], pts[4], (cx, cy)], fill=c[0] + (255,))
    return shadowed(outline(im), 3, 4, 80)


def spire_top(seed):
    rnd = random.Random(seed)
    im = new(22, 22)
    d = ImageDraw.Draw(im)
    c = [C('#120c10'), C('#241a1e'), C('#3a2c32'), C('#5a4650')]
    for k in range(rnd.randint(3, 4)):
        cx, cy = rnd.randint(5, 16), rnd.randint(5, 16)
        r = rnd.randint(3, 5)
        d.polygon([(cx, cy - r), (cx + r, cy + r // 2), (cx - r, cy + r // 2)], fill=c[1])
        d.polygon([(cx, cy - r), (cx - r, cy + r // 2), (cx, cy)], fill=c[3])
        d.point((cx, cy), fill=C('#ff6a1a'))
    return shadowed(outline(im), 3, 4, 80)


def statue_top():
    im = new(26, 26)
    d = ImageDraw.Draw(im)
    d.ellipse([9, 3, 17, 11], fill=STONE[3] + (255,))
    d.polygon([(13, 10), (2, 16), (3, 21), (13, 15)], fill=STONE[2] + (255,))
    d.polygon([(13, 10), (24, 16), (23, 21), (13, 15)], fill=STONE[1] + (255,))
    d.rectangle([10, 10, 16, 23], fill=STONE[2] + (255,))
    d.rectangle([10, 10, 10, 23], fill=STONE[3] + (255,))
    d.rectangle([16, 10, 16, 23], fill=STONE[0] + (255,))
    return shadowed(outline(im), 3, 4, 85)


def mausoleum_top(seed):
    rnd = random.Random(seed)
    W, H = 3 * T, 3 * T
    im = new(W, H)
    d = ImageDraw.Draw(im)
    roof_rect(d, 0, 0, W, H, ['#1c1824', '#2c2838', '#423c54', '#5e5878'], rnd, False)
    d.line([0, H // 2, W - 1, H // 2], fill=STONE[0] + (255,))
    d.rectangle([W // 2 - 3, 4, W // 2 + 3, 10], fill=STONE[1] + (255,))
    d.line([W // 2, 5, W // 2, 9], fill=C('#a8a8c8'))
    d.line([W // 2 - 2, 7, W // 2 + 2, 7], fill=C('#a8a8c8'))
    damage(im, rnd, 1, ['#1c1824', '#2c2838', '#423c54', '#5e5878'])
    return shadowed(outline(im), 4, 5, 90)


def smithy_top(seed):
    rnd = random.Random(seed)
    W, H = 4 * T, 3 * T
    im = new(W, H)
    d = ImageDraw.Draw(im)
    roof_rect(d, 0, 0, W, H, ROOFS["ash"], rnd, True)
    chimney(d, W - 18, H // 2 - 10, True)
    d.rectangle([W - 16, H // 2 - 8, W - 14, H // 2 - 6], fill=C('#ff6a1a'))
    damage(im, rnd, 2, ROOFS["ash"])
    return shadowed(outline(im), 4, 5, 90)


def gate_top():  # cancello di ferro che chiude un ponte (vista dall'alto, sbarra N-S)
    im = new(16, 48)
    d = ImageDraw.Draw(im)
    for y0 in (0, 36):
        d.rectangle([2, y0, 13, y0 + 11], fill=STONE[2] + (255,))
        d.rectangle([2, y0, 13, y0 + 1], fill=STONE[3] + (255,))
        d.rectangle([11, y0, 13, y0 + 11], fill=STONE[0] + (255,))
        d.rectangle([5, y0 + 3, 9, y0 + 8], fill=STONE[1] + (255,))
    d.rectangle([7, 12, 8, 35], fill=C('#0c0a10'))
    for y in range(13, 35, 4):
        d.line([3, y, 12, y], fill=C('#2a2834'))
        d.point((3, y), fill=C('#5a566a')); d.point((12, y), fill=C('#5a566a'))
    d.rectangle([5, 22, 10, 25], fill=C('#8a1424'))
    d.point((7, 23), fill=C('#d8c070'))
    return shadowed(outline(im), 2, 3, 80)


def hall(wc, hc, roof, seed, glass, trim):
    """Grande sala con lucernari: archivio (vetri ambra) o sanatorio (vetri pallidi)."""
    rnd = random.Random(seed)
    W, H = wc * T, hc * T
    im = new(W, H)
    d = ImageDraw.Draw(im)
    roof_rect(d, 0, 0, W, H, ROOFS[roof], rnd, True)
    n = wc - 1
    for i in range(n):
        x0 = 10 + i * (W - 20) // n
        d.rectangle([x0, H // 2 - 7, x0 + 9, H // 2 + 6], fill=C(glass[0]))
        d.rectangle([x0 + 1, H // 2 - 6, x0 + 8, H // 2 - 1], fill=C(glass[1]))
        d.line([x0 + 4, H // 2 - 7, x0 + 4, H // 2 + 6], fill=C('#0c0a10'))
        d.line([x0, H // 2 - 1, x0 + 9, H // 2 - 1], fill=C('#0c0a10'))
    d.rectangle([0, 0, W - 1, 1], fill=C(trim))
    d.rectangle([0, H - 2, W - 1, H - 1], fill=C(trim))
    chimney(d, 6, 4)
    chimney(d, W - 14, H - 12)
    damage(im, rnd, 3, ROOFS[roof])
    im = outline(im)
    return shadowed(im, 4, 5)


RELICS = {
    "corvo": ('#c8c8d8', ["....##....", "...###....", "..####....", "..####....", "..###.....", "..###.....", "...##.....", "...##.....", "....#.....", "....#....."]),
    "cenere": ('#d8602a', ["....#.....", "...###....", "..#.#.#...", ".#######..", "..#####...", ".#######..", "..#.#.#...", "...###....", "....#.....", ".........."]),
    "brace": ('#e8a030', ["...#.#....", "..#.#.#...", "...###....", ".########.", ".#......#.", "..#....#..", "..######..", "....##....", "...####...", ".........."]),
    "lanterna": ('#f0c060', ["....##....", "...#..#...", "..######..", "..#.##.#..", "..#.##.#..", "..#.##.#..", "..######..", "...####...", "....##....", ".........."]),
    "nodo": ('#a8283a', [".##....##.", "####..####", "#..####..#", "#...##...#", ".#..##..#.", ".#..##..#.", "#..####..#", "#..#..#..#", ".##....##.", ".........."]),
    "catena": ('#8aa0c0', ["..###.....", ".#...#....", ".#...#.##.", "..###.#..#", "....#.#..#", "...#...##.", "..#..###..", ".#..#...#.", ".#..#...#.", "..##.###.."]),
    "moneta": ('#d8d0a0', ["..######..", ".########.", "##..##..##", "##.####.##", "##..##..##", "##.####.##", "##..##..##", ".########.", "..######..", ".........."]),
    "pietra": ('#7a7a90', [".##....##.", "####..####", "##########", "##########", ".########.", "..######..", "...####...", "....##....", "..........", ".........."]),
}


def relic_icon(rid):
    col, rows = RELICS[rid]
    im = new(12, 12)
    px = im.load()
    base = hexc(col)
    for y, row in enumerate(rows):
        for x, ch in enumerate(row[:10]):
            if ch == '#':
                k = 1.18 if (x + y) % 5 == 0 else (0.82 if y > 6 else 1.0)
                px[x + 1, y + 1] = tuple(min(255, int(v * k)) for v in base) + (255,)
    return shadowed(outline(im), 1, 2, 80)


def shrine_prop():  # altare delle offerte: bacile di pietra con una luce fredda
    im = new(16, 16)
    d = ImageDraw.Draw(im)
    d.ellipse([1, 4, 14, 14], fill=STONE[1] + (255,))
    d.ellipse([1, 4, 14, 8], fill=STONE[3] + (255,))
    d.ellipse([3, 6, 12, 11], fill=C('#0c0a14'))
    d.ellipse([5, 7, 10, 9], fill=C('#78a8e8'))
    d.point((7, 7), fill=C('#e8f4ff'))
    d.rectangle([6, 0, 9, 3], fill=STONE[2] + (255,))
    d.point((7, 1), fill=C('#a8d0ff'))
    return shadowed(outline(im), 2, 2, 80)


def arena_core():  # cerchio rituale inciso nella pietra: segna un luogo di sfida
    im = new(32, 32)
    d = ImageDraw.Draw(im)
    d.ellipse([0, 0, 31, 31], fill=STONE[0] + (255,))
    d.ellipse([2, 2, 29, 29], fill=STONE[1] + (255,))
    d.ellipse([5, 5, 26, 26], outline=C('#8a1424'))
    d.ellipse([9, 9, 22, 22], outline=C('#8a1424'))
    for a in range(0, 360, 45):
        x = 16 + int(math.cos(math.radians(a)) * 12)
        y = 16 + int(math.sin(math.radians(a)) * 12)
        d.rectangle([x - 1, y - 1, x, y], fill=C('#c8b070'))
    d.polygon([(16, 10), (21, 18), (11, 18)], outline=C('#c8b070'))
    d.point((16, 15), fill=C('#ff5030'))
    return shadowed(outline(im), 2, 2, 70)


def bell_prop():  # campana su un telaio di legno
    im = new(16, 22)
    d = ImageDraw.Draw(im)
    d.rectangle([1, 1, 14, 3], fill=C('#4a3420'))
    d.rectangle([1, 1, 2, 21], fill=C('#4a3420'))
    d.rectangle([13, 1, 14, 21], fill=C('#4a3420'))
    d.polygon([(8, 5), (12, 15), (4, 15)], fill=C('#8a6a30'))
    d.rectangle([4, 14, 12, 16], fill=C('#b8903c'))
    d.point((8, 18), fill=C('#d8c070'))
    return shadowed(outline(im), 2, 2, 80)


def qitem_prop():  # fagotto legato con una scintilla dorata (oggetto di missione)
    im = new(14, 14)
    d = ImageDraw.Draw(im)
    d.ellipse([1, 4, 12, 13], fill=C('#6a4a2a'))
    d.ellipse([2, 4, 11, 8], fill=C('#8a6a3a'))
    d.line([3, 9, 10, 9], fill=C('#3a2410'))
    d.line([6, 4, 6, 13], fill=C('#3a2410'))
    d.point((6, 6), fill=C('#ffe080')); d.point((7, 5), fill=C('#fff0b0')); d.point((5, 5), fill=C('#ffd24a'))
    return shadowed(outline(im), 1, 2, 80)


def tent_camp():  # tenda di tela vista dall'alto, con lanterna
    im = new(28, 24)
    d = ImageDraw.Draw(im)
    d.polygon([(2, 20), (14, 2), (26, 20)], fill=C('#6a5a44'))
    d.polygon([(14, 2), (26, 20), (14, 20)], fill=C('#54463a'))
    d.line([14, 2, 14, 20], fill=C('#2a2018'))
    d.line([2, 20, 26, 20], fill=C('#2a2018'))
    d.polygon([(11, 20), (14, 11), (17, 20)], fill=C('#120c08'))
    d.line([14, 2, 8, 20], fill=C('#8a7a5e')); d.line([14, 2, 20, 20], fill=C('#40362a'))
    for x in (1, 27):
        d.point((x, 21), fill=C('#3a2a18')); d.point((x, 22), fill=C('#3a2a18'))
    d.rectangle([20, 17, 22, 19], fill=C('#d8a040')); d.point((21, 18), fill=C('#fff0b0'))
    return shadowed(outline(im), 2, 3, 80)


def hut_camp():  # capanna di tronchi con tetto di assi, per il bosco
    im = new(30, 26)
    d = ImageDraw.Draw(im)
    d.rectangle([2, 4, 27, 22], fill=C('#4a3420'))
    for y in range(5, 22, 3):
        d.line([2, y, 27, y], fill=C('#5e4228')); d.line([2, y + 1, 27, y + 1], fill=C('#2a1a10'))
    d.polygon([(0, 12), (15, 1), (30, 12), (30, 8), (15, 0), (0, 8)], fill=C('#3a2a1c'))
    d.rectangle([0, 2, 29, 12], fill=C('#4a3828'))
    for x in range(1, 29, 4):
        d.line([x, 2, x, 12], fill=C('#2a1c12'))
    d.rectangle([12, 15, 17, 22], fill=C('#0e0806'))
    d.rectangle([3, 15, 6, 18], fill=C('#d8a040')); d.point((4, 16), fill=C('#fff0b0'))
    d.rectangle([22, 2, 25, 5], fill=C('#3a3a46'))
    return shadowed(outline(im), 2, 3, 80)


def bedroll():  # giaciglio con cuscino e lanterna, per i bivacchi sottoterra
    im = new(20, 14)
    d = ImageDraw.Draw(im)
    d.rectangle([1, 3, 15, 11], fill=C('#5a4a3a'))
    d.rectangle([1, 3, 15, 5], fill=C('#7a6a54'))
    d.rectangle([1, 3, 4, 11], fill=C('#8a8a96'))
    d.ellipse([0, 2, 5, 12], outline=C('#2a2018'))
    d.rectangle([16, 6, 18, 10], fill=C('#2a2630')); d.rectangle([16, 7, 18, 9], fill=C('#d8a040')); d.point((17, 8), fill=C('#fff0b0'))
    return shadowed(outline(im), 1, 2, 80)


def mill_top():  # vecchio mulino a vento visto dall'alto: tetto conico e quattro pale
    im = new(88, 88)
    d = ImageDraw.Draw(im)
    cx = cy = 44
    # pale (assi di legno incrociate)
    for dx, dy in ((1, 0), (0, 1), (-1, 0), (0, -1)):
        x2, y2 = cx + dx * 40, cy + dy * 40
        d.line([cx, cy, x2, y2], fill=C('#4a3420'), width=3)
        for k in range(1, 5):
            px, py = cx + dx * (8 + k * 7), cy + dy * (8 + k * 7)
            if dx:
                d.rectangle([px - 3, py - 6, px + 3, py + 6], fill=C('#8a7a5e'), outline=C('#2a1c12'))
            else:
                d.rectangle([px - 6, py - 3, px + 6, py + 3], fill=C('#8a7a5e'), outline=C('#2a1c12'))
    d.ellipse([cx - 16, cy - 16, cx + 16, cy + 16], fill=C('#5a4a3a'))
    d.ellipse([cx - 14, cy - 14, cx + 14, cy + 14], fill=C('#6a5a48'))
    d.pieslice([cx - 14, cy - 14, cx + 14, cy + 14], 180, 360, fill=C('#7a6a54'))
    d.ellipse([cx - 5, cy - 5, cx + 5, cy + 5], fill=C('#2a2018'))
    d.ellipse([cx - 2, cy - 2, cx + 2, cy + 2], fill=C('#8a6a30'))
    return shadowed(outline(im), 4, 5)


def res_erba():  # ciuffo di erbe medicinali con piccoli fiori pallidi
    im = new(16, 16)
    d = ImageDraw.Draw(im)
    for x0, h in ((3, 8), (6, 10), (9, 9), (12, 7), (5, 6), (10, 6)):
        d.line([x0, 14, x0 + (1 if x0 % 2 else -1), 14 - h], fill=C('#4a7a4a'), width=1)
        d.line([x0 + 1, 14, x0 + 1, 13 - h + 2], fill=C('#6aa05a'), width=1)
    for fx, fy in ((4, 5), (8, 3), (11, 4), (7, 7)):
        d.point((fx, fy), fill=C('#d8e8ff')); d.point((fx + 1, fy), fill=C('#a8c0f0'))
    return shadowed(outline(im), 1, 2, 70)


def res_fungo():  # funghi luminosi
    im = new(16, 16)
    d = ImageDraw.Draw(im)
    for cx, cy, r in ((5, 10, 3), (10, 8, 4), (12, 12, 2)):
        d.rectangle([cx - 1, cy, cx, cy + 4], fill=C('#c8c0a8'))
        d.ellipse([cx - r, cy - r, cx + r, cy], fill=C('#7a4a9a'))
        d.point((cx - 1, cy - r + 1), fill=C('#e8c8ff')); d.point((cx + 1, cy - 1), fill=C('#a8f0c8'))
    return shadowed(outline(im), 1, 2, 70)


def res_legna():  # fascina di tronchi
    im = new(16, 16)
    d = ImageDraw.Draw(im)
    for i, y in enumerate((11, 8, 5)):
        d.rectangle([2 + i, y, 13 - i, y + 2], fill=C('#6a4a2a'))
        d.line([2 + i, y, 13 - i, y], fill=C('#8a6a3a'))
        d.ellipse([1 + i, y, 4 + i, y + 3], fill=C('#a88858'))
    d.line([4, 13, 12, 13], fill=C('#2a1a10'))
    return shadowed(outline(im), 1, 2, 70)


def res_minerale():  # roccia con vene di minerale
    im = new(16, 16)
    d = ImageDraw.Draw(im)
    d.polygon([(2, 13), (3, 6), (8, 3), (13, 6), (14, 13)], fill=C('#5a5a6a'))
    d.polygon([(3, 6), (8, 3), (8, 13), (2, 13)], fill=C('#7a7a8a'))
    for fx, fy in ((6, 7), (10, 9), (5, 11)):
        d.rectangle([fx, fy, fx + 1, fy + 1], fill=C('#7ad8e8')); d.point((fx, fy), fill=C('#e8ffff'))
    return shadowed(outline(im), 1, 2, 70)


def mat_icon(kind):
    im = new(12, 12)
    d = ImageDraw.Draw(im)
    if kind == 'pelle':
        d.polygon([(2, 3), (10, 3), (11, 9), (6, 11), (1, 9)], fill=C('#9a7a52')); d.line([3, 5, 9, 5], fill=C('#c8a878'))
    elif kind == 'carne':
        d.ellipse([1, 3, 10, 10], fill=C('#b8454a')); d.ellipse([2, 4, 6, 7], fill=C('#d8808a')); d.rectangle([8, 2, 10, 4], fill=C('#e8e0d0'))
    elif kind == 'osso':
        d.line([2, 9, 9, 2], fill=C('#e8e0d0'), width=2)
        for p in ((1, 8), (3, 10), (8, 1), (10, 3)):
            d.point(p, fill=C('#e8e0d0'))
    return shadowed(outline(im), 1, 1, 60)


def lever_prop():
    im = new(16, 16)
    d = ImageDraw.Draw(im)
    d.rectangle([2, 8, 13, 14], fill=STONE[1] + (255,))
    d.rectangle([2, 8, 13, 9], fill=STONE[3] + (255,))
    d.rectangle([4, 10, 11, 12], fill=C('#0c0a10'))
    d.line([8, 11, 11, 2], fill=C('#6a5a48'), width=2)
    d.ellipse([10, 0, 13, 3], fill=C('#8a1424'))
    return shadowed(outline(im), 2, 2, 80)


def key_prop():
    im = new(12, 12)
    d = ImageDraw.Draw(im)
    d.ellipse([1, 1, 5, 5], outline=C('#d8b040'))
    d.point((3, 3), fill=C('#0c0a10'))
    d.line([5, 5, 10, 10], fill=C('#d8b040'), width=1)
    d.point((8, 10), fill=C('#d8b040')); d.point((10, 8), fill=C('#d8b040'))
    return shadowed(outline(im), 1, 2, 80)


def stairs_top():  # bocca di scala in pietra che scende nel buio (vista dall'alto, 32x32)
    im = new(32, 32)
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, 31, 31], fill=STONE[1] + (255,))
    d.rectangle([0, 0, 31, 2], fill=STONE[3] + (255,))
    d.rectangle([0, 0, 2, 31], fill=STONE[3] + (255,))
    d.rectangle([29, 0, 31, 31], fill=STONE[0] + (255,))
    d.rectangle([0, 29, 31, 31], fill=STONE[0] + (255,))
    for i in range(6):
        c = max(6, 60 - i * 9)
        d.rectangle([5 + i, 5 + i * 3, 26 - i, 8 + i * 3], fill=(c, c - 6, c + 4, 255))
        d.line([5 + i, 5 + i * 3, 26 - i, 5 + i * 3], fill=STONE[2] + (255,))
    d.rectangle([5, 5, 26, 25], outline=C('#0a0610'))
    d.rectangle([2, 2, 4, 4], fill=STONE[2] + (255,)); d.rectangle([27, 2, 29, 4], fill=STONE[2] + (255,))
    return shadowed(outline(im), 2, 3, 80)


def lamp_top():  # lampione a gas visto dall'alto: base in ferro battuto, lanterna a vetri
    im = new(10, 10)
    d = ImageDraw.Draw(im)
    d.ellipse([0, 0, 9, 9], fill=C('#16141c'))
    d.ellipse([1, 1, 8, 8], fill=C('#2a2834'))
    d.rectangle([3, 3, 6, 6], fill=C('#c87820'))
    d.rectangle([4, 4, 5, 5], fill=C('#ffd878'))
    d.line([4, 1, 4, 8], fill=C('#16141c')); d.line([1, 4, 8, 4], fill=C('#16141c'))
    d.point((4, 4), fill=C('#fff4c8')); d.point((5, 5), fill=C('#ffe49a'))
    return shadowed(outline(im), 2, 3, 80)


def bridge(horizontal=True):
    L = 2 * T
    im = new(L, 3 * T) if not horizontal else new(3 * T, 2 * T)
    d = ImageDraw.Draw(im)
    w, h = im.size
    wd = [hexc('#1a1210'), hexc('#2e2018'), hexc('#4e3828'), hexc('#6a4e38')]
    if horizontal:
        for x in range(0, w, 4):
            d.rectangle([x, 4, x + 2, h - 5], fill=wd[2 - (x // 4) % 2] + (255,))
            d.line([x + 3, 4, x + 3, h - 5], fill=wd[0] + (255,))
        d.rectangle([0, 2, w - 1, 4], fill=wd[3] + (255,))
        d.rectangle([0, h - 5, w - 1, h - 3], fill=wd[1] + (255,))
        for x in range(2, w, 12):
            d.rectangle([x, 0, x + 2, 3], fill=wd[3] + (255,))
            d.rectangle([x, h - 4, x + 2, h - 1], fill=wd[1] + (255,))
    else:
        for y in range(0, h, 4):
            d.rectangle([4, y, w - 5, y + 2], fill=wd[2 - (y // 4) % 2] + (255,))
            d.line([4, y + 3, w - 5, y + 3], fill=wd[0] + (255,))
        d.rectangle([2, 0, 4, h - 1], fill=wd[3] + (255,))
        d.rectangle([w - 5, 0, w - 3, h - 1], fill=wd[1] + (255,))
        for y in range(2, h, 12):
            d.rectangle([0, y, 3, y + 2], fill=wd[3] + (255,))
            d.rectangle([w - 4, y, w - 1, y + 2], fill=wd[1] + (255,))
    return shadowed(im, 2, 3, 80)


def page_sprite():
    im = new(12, 14)
    d = ImageDraw.Draw(im)
    d.rectangle([1, 1, 10, 12], fill=C('#d8c890'))
    d.rectangle([1, 1, 10, 1], fill=C('#f0e4b0'))
    d.rectangle([10, 1, 10, 12], fill=C('#a89860'))
    for y in (3, 5, 7, 9):
        d.line([3, y, 8, y], fill=C('#6a5a34'))
    d.polygon([(7, 12), (10, 12), (10, 9)], fill=C('#a89860'))
    return shadowed(outline(im), 2, 2, 85)


def icon(kind):
    im = new(16, 16)
    d = ImageDraw.Draw(im)
    steel, hi, dk = C('#c8cede'), C('#f0f4ff'), C('#6a7088')
    wood, gold = C('#5a3a1a'), C('#d8a02a')
    if kind == "sword":
        d.line([4, 11, 12, 3], fill=steel, width=2); d.line([4, 10, 11, 3], fill=hi)
        d.line([4, 8, 8, 12], fill=gold, width=1); d.line([3, 12, 1, 14], fill=wood, width=2)
    elif kind == "greatsword":
        d.line([4, 12, 13, 2], fill=steel, width=3); d.line([4, 11, 12, 2], fill=hi)
        d.line([3, 8, 8, 13], fill=gold, width=2); d.line([3, 13, 1, 15], fill=wood, width=2)
    elif kind == "spear":
        d.line([2, 14, 11, 5], fill=wood, width=1); d.polygon([(10, 6), (14, 1), (15, 2), (12, 7)], fill=steel)
        d.line([11, 5, 14, 2], fill=hi)
    elif kind == "hammer":
        d.line([3, 13, 10, 6], fill=wood, width=2); d.rectangle([8, 2, 14, 7], fill=dk); d.rectangle([8, 2, 14, 3], fill=steel)
    elif kind == "dagger":
        d.line([5, 10, 10, 5], fill=steel, width=2); d.line([4, 11, 2, 13], fill=wood, width=2); d.line([4, 8, 7, 11], fill=gold)
    elif kind == "bow":
        d.arc([1, 1, 14, 14], 270, 90, fill=wood, width=2); d.line([8, 1, 8, 14], fill=C('#d8d0b0'))
        d.line([3, 7, 14, 7], fill=hi)
    elif kind == "staff":
        d.line([3, 14, 11, 5], fill=wood, width=2); d.ellipse([9, 1, 14, 6], fill=C('#8a4ad0')); d.point((11, 3), fill=C('#e8c8ff'))
    elif kind == "tome":
        d.rectangle([3, 3, 12, 13], fill=C('#6a1424')); d.rectangle([3, 3, 4, 13], fill=C('#4a0c18'))
        d.line([8, 5, 8, 11], fill=gold); d.line([6, 7, 10, 7], fill=gold)
    return shadowed(outline(im), 1, 2, 80)


def door_sprite():
    im = new(16, 16)
    d = ImageDraw.Draw(im)
    d.rectangle([1, 0, 14, 10], fill=C('#4a3220'))
    for x in range(1, 15, 3):
        d.line([x, 0, x, 10], fill=C('#2a1a10'))
    d.rectangle([1, 0, 14, 0], fill=C('#6a4a30'))
    d.rectangle([11, 5, 12, 6], fill=C('#d8a02a'))
    d.rectangle([0, 10, 15, 13], fill=C('#5a5870'))
    d.rectangle([0, 10, 15, 10], fill=C('#8a88a0'))
    return shadowed(outline(im), 1, 2, 70)


def furniture(kind):
    wd = [C('#1a1210'), C('#2e2018'), C('#4e3828'), C('#6a4e38')]
    if kind == "bed":
        im = new(32, 16)
        d = ImageDraw.Draw(im)
        d.rectangle([0, 0, 31, 15], fill=wd[1]); d.rectangle([0, 0, 31, 0], fill=wd[3])
        d.rectangle([2, 2, 29, 13], fill=C('#6a1c30')); d.rectangle([2, 2, 29, 3], fill=C('#8a2c44'))
        d.rectangle([3, 3, 10, 12], fill=C('#d8d4e4')); d.rectangle([3, 3, 10, 4], fill=C('#f0eef8'))
        d.rectangle([22, 6, 29, 13], fill=C('#4a1020'))
    elif kind == "table":
        im = new(32, 16)
        d = ImageDraw.Draw(im)
        d.rectangle([0, 1, 31, 14], fill=wd[2]); d.rectangle([0, 1, 31, 2], fill=wd[3])
        for x in range(4, 31, 6):
            d.line([x, 3, x, 14], fill=wd[1])
        d.ellipse([6, 5, 11, 10], fill=C('#d8d0b4')); d.point((9, 7), fill=C('#a89860'))
        d.rectangle([20, 4, 21, 8], fill=C('#e8dcb8')); d.point((20, 3), fill=C('#ffb040'))
    elif kind == "chair":
        im = new(10, 10)
        d = ImageDraw.Draw(im)
        d.rectangle([1, 2, 8, 8], fill=wd[2]); d.rectangle([1, 1, 8, 2], fill=wd[3]); d.rectangle([1, 7, 8, 8], fill=wd[0])
    elif kind == "shelf":
        im = new(32, 10)
        d = ImageDraw.Draw(im)
        d.rectangle([0, 0, 31, 9], fill=wd[1]); d.rectangle([0, 0, 31, 0], fill=wd[3])
        import random as _r
        rr = _r.Random(3)
        for x in range(2, 30, 3):
            d.rectangle([x, 2, x + 1, 7], fill=rr.choice([C('#8a2c44'), C('#2a5a8a'), C('#4a6a2a'), C('#d8a02a')]))
    elif kind == "hearth":
        im = new(32, 14)
        d = ImageDraw.Draw(im)
        d.rectangle([0, 0, 31, 13], fill=STONE[2] + (255,))
        d.rectangle([0, 0, 31, 1], fill=STONE[3] + (255,))
        d.rectangle([6, 4, 25, 12], fill=(8, 6, 12, 255))
        d.polygon([(10, 12), (14, 5), (18, 12)], fill=C('#c8300e')); d.polygon([(14, 12), (17, 7), (21, 12)], fill=C('#ff9a30'))
        d.polygon([(13, 12), (15, 9), (17, 12)], fill=C('#fff0a0'))
    elif kind == "pew":
        im = new(48, 10)
        d = ImageDraw.Draw(im)
        d.rectangle([0, 0, 47, 9], fill=wd[2]); d.rectangle([0, 0, 47, 1], fill=wd[3]); d.rectangle([0, 8, 47, 9], fill=wd[0])
        d.line([0, 4, 47, 4], fill=wd[1])
    elif kind == "cauldron":
        im = new(16, 16)
        d = ImageDraw.Draw(im)
        d.ellipse([0, 0, 15, 15], fill=C('#2c2a38')); d.ellipse([2, 2, 13, 13], fill=C('#4a4858'))
        d.ellipse([3, 3, 12, 12], fill=C('#3aa84a')); d.ellipse([5, 5, 8, 8], fill=C('#8aff8a'))
    elif kind == "anvil":
        im = new(14, 14)
        d = ImageDraw.Draw(im)
        d.rectangle([2, 3, 11, 10], fill=C('#4a4858')); d.rectangle([2, 3, 11, 4], fill=C('#8a8aa0'))
        d.polygon([(11, 4), (13, 6), (11, 8)], fill=C('#4a4858')); d.rectangle([4, 10, 9, 12], fill=C('#2c2a38'))
    else:  # rack
        im = new(32, 10)
        d = ImageDraw.Draw(im)
        d.rectangle([0, 0, 31, 9], fill=wd[1]); d.rectangle([0, 0, 31, 0], fill=wd[3])
        for x in range(3, 30, 6):
            d.line([x, 2, x + 2, 8], fill=C('#c8cede'), width=1)
            d.point((x, 1), fill=C('#d8a02a'))
    return shadowed(outline(im), 2, 3, 80)


def rug(kind):
    pal = [('#5a1424', '#8a2c44', '#d8a02a'), ('#1c2a4a', '#2c4a7a', '#c8c0a0'), ('#2a3a1c', '#4a6a2c', '#d8b050')][kind]
    base, mid, trim = [C(c) for c in pal]
    im = new(48, 32)
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, 47, 31], fill=base)
    d.rectangle([3, 3, 44, 28], fill=mid)
    d.rectangle([5, 5, 42, 26], outline=trim)
    for x in range(8, 42, 6):
        d.polygon([(x + 3, 9), (x + 6, 16), (x + 3, 23), (x, 16)], fill=base, outline=trim)
    for y in range(0, 32, 3):
        d.point((0, y), fill=trim); d.point((47, y), fill=trim)
    return outline(im)


def wardrobe():
    wd = [C('#1a1210'), C('#2e2018'), C('#4e3828'), C('#6a4e38')]
    im = new(32, 12)
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, 31, 11], fill=wd[1])
    d.rectangle([0, 0, 31, 1], fill=wd[3])
    d.line([15, 2, 15, 11], fill=wd[0])
    d.rectangle([12, 5, 13, 7], fill=C('#d8a02a')); d.rectangle([17, 5, 18, 7], fill=C('#d8a02a'))
    for x in (3, 22):
        d.rectangle([x, 3, x + 6, 9], outline=wd[2])
    return shadowed(outline(im), 2, 3, 80)


def sack():
    im = new(12, 12)
    d = ImageDraw.Draw(im)
    d.ellipse([0, 1, 11, 11], fill=C('#8a7648'))
    d.ellipse([2, 3, 8, 8], fill=C('#a89060'))
    d.rectangle([4, 0, 7, 2], fill=C('#6a5834'))
    d.line([3, 9, 8, 9], fill=C('#6a5834'))
    return shadowed(outline(im), 2, 2, 80)


def save(im, name):
    from decay import weather
    weather(im, name).save(os.path.join(OUT, name + ".png"))
    return name


def main():
    out = []
    # tetti: dimensione (celle) x colore
    kinds = [(2, 2), (3, 2), (2, 3), (3, 3), (4, 3), (3, 4), (4, 4), (5, 3), (3, 5), (4, 2), (2, 4)]
    n = 0
    for wc, hc in kinds:
        for rf in ("slate", "rust", "moss", "wood", "thatch", "ice", "ash"):
            n += 1
            for v in range(3):
                out.append(save(house(wc, hc, rf, n * 7 + wc * 3 + hc + v * 101, dmg=2 if wc * hc > 6 else 1), f"roof_{wc}x{hc}_{rf}_{v}"))
    out.append(save(chapel("slate", 1), "chapel_top_slate"))
    out.append(save(chapel("ice", 2), "chapel_top_ice"))
    out.append(save(chapel("ash", 3), "chapel_top_ash"))
    out.append(save(tower_top(1), "tower_top"))
    out.append(save(gate_top(), "gate_top"))
    out.append(save(stairs_top(), "stairs_top"))
    out.append(save(hall(6, 4, "ash", 77, ('#1c1a22', '#d89030'), '#8a6a20'), "archive_top"))
    out.append(save(hall(7, 4, "ice", 91, ('#2a3448', '#a8c8e0'), '#9aa0b4'), "sanatorium_top"))
    out.append(save(lever_prop(), "lever"))
    out.append(save(res_erba(), "res_erba"))
    out.append(save(res_fungo(), "res_fungo"))
    out.append(save(res_legna(), "res_legna"))
    out.append(save(res_minerale(), "res_minerale"))
    for mk in ("pelle", "carne", "osso"):
        out.append(save(mat_icon(mk), "mat_" + mk))
    out.append(save(mill_top(), "mill_top"))
    out.append(save(tent_camp(), "tent_camp"))
    out.append(save(hut_camp(), "hut_camp"))
    out.append(save(bedroll(), "bedroll"))
    out.append(save(qitem_prop(), "qitem"))
    out.append(save(arena_core(), "arena_core"))
    out.append(save(bell_prop(), "bell"))
    out.append(save(shrine_prop(), "shrine"))
    for rid in RELICS:
        out.append(save(relic_icon(rid), "relic_" + rid))
    out.append(save(key_prop(), "key"))
    for i in range(10):
        out.append(save(canopy(i * 5 + 1, GREEN, 44), f"top_forest_{i}"))
        out.append(save(canopy(i * 5 + 3, PURPLE, 40), f"top_gloom_{i}"))
        out.append(save(canopy(i * 5 + 7, SICK, 42), f"top_sick_{i}"))
        out.append(save(canopy(i * 5 + 11, AUTUMN, 38), f"top_autumn_{i}"))
        out.append(save(canopy(i * 5 + 2, FROST, 38), f"top_frost_{i}"))
        out.append(save(canopy(i * 3 + 4, GREEN, 40, dead=True), f"top_dead_{i}"))
        out.append(save(bush(i + 9, GREEN, 20), f"bush_green_{i}"))
        out.append(save(bush(i + 19, SICK, 18), f"bush_sick_{i}"))
        out.append(save(bush(i + 29, FROST, 18), f"bush_frost_{i}"))
    for k in ("mound", "slab", "cross", "obelisk"):
        for i in range(5):
            out.append(save(grave(i + 1, k), f"grave_{k}_{i}"))
    for h in (True, False):
        for iron in (True, False):
            out.append(save(fence("f", h, iron), f"fence_{'h' if h else 'v'}_{'iron' if iron else 'wood'}"))
    out.append(save(well(), "well_top"))
    out.append(save(stall(1, ['#8a1c30', '#d8d0b4']), "stall_top_0"))
    out.append(save(stall(2, ['#2a5a8a', '#d8d0b4']), "stall_top_1"))
    out.append(save(stall(3, ['#4a6a2a', '#d8c890']), "stall_top_2"))
    out.append(save(barrel(), "barrel_top"))
    out.append(save(crate(), "crate_top"))
    out.append(save(hay(), "hay_top"))
    out.append(save(cart(1), "cart_top"))
    out.append(save(tent(1, ['#2a2418', '#4a4028', '#6a5c38']), "tent_top_0"))
    out.append(save(tent(2, ['#2a1418', '#4a2028', '#6a3038']), "tent_top_1"))
    out.append(save(tent(3, ['#1c2418', '#2c3a28', '#445a3c']), "tent_top_2"))
    out.append(save(campfire(), "campfire_top"))
    out.append(save(stump_top(1), "stump_top"))
    for i in range(4):
        out.append(save(stump_top(i + 1), f"stump_top_{i}"))
    for i in range(5):
        out.append(save(log_top(i + 1), f"log_top_{i}"))
    for horiz in (True, False):
        for nn in (2, 3):
            out.append(save(ruin_wall_top(nn * 3 + 1, horiz, nn), f"wall_top_{'h' if horiz else 'v'}{nn}"))
            for v in range(4):
                out.append(save(ruin_wall_top(nn * 3 + 1 + v * 11, horiz, nn), f"wall_top_{'h' if horiz else 'v'}{nn}_{v}"))
    out.append(save(column_top(), "column_top"))
    out.append(save(menhir_top(1, '#7aa0ff'), "menhir_top_cem"))
    out.append(save(menhir_top(2, '#a8f0ff'), "menhir_top_ice"))
    out.append(save(menhir_top(3, '#d890ff'), "menhir_top_cat"))
    out.append(save(crystal_top(1, ['#3a5a8a', '#6a9ad0', '#a8d8ff', '#eaf8ff']), "crystal_top_ice"))
    out.append(save(crystal_top(2, ['#3a1a4a', '#6a3a9a', '#a870e0', '#f0d8ff']), "crystal_top_cat"))
    out.append(save(spire_top(1), "spire_top_0"))
    out.append(save(spire_top(2), "spire_top_1"))
    out.append(save(statue_top(), "statue_top"))
    out.append(save(mausoleum_top(1), "mausoleum_top"))
    out.append(save(smithy_top(1), "smithy_top"))
    out.append(save(lamp_top(), "lamp_top"))
    out.append(save(page_sprite(), "page_top"))
    for k in ("sword", "greatsword", "spear", "hammer", "dagger", "bow", "staff", "tome"):
        out.append(save(icon(k), "w_" + k))
    out.append(save(door_sprite(), "door_top"))
    for k in range(3):
        out.append(save(rug(k), f"rug_top_{k}"))
    out.append(save(wardrobe(), "wardrobe_top"))
    out.append(save(sack(), "sack_top"))
    for k in ("bed", "table", "chair", "shelf", "hearth", "pew", "cauldron", "anvil", "rack"):
        out.append(save(furniture(k), k + "_top"))
    out.append(save(bridge(True), "bridge_h"))
    out.append(save(bridge(False), "bridge_v"))

    # anteprima (solo una selezione)
    show = [n for n in out if not n.startswith("roof_") or n.endswith(("_slate", "_rust", "_thatch", "_moss")) and n.split("_")[1] in ("3x2", "4x3", "2x2")]
    ims = [(n, Image.open(os.path.join(OUT, n + ".png"))) for n in show]
    Wd = 1900
    x = y = 4
    rowh = 0
    sheet = Image.new("RGB", (Wd, 3000), (36, 44, 30))
    for n, im in ims:
        im2 = im.resize((im.width * 2, im.height * 2), Image.NEAREST)
        if x + im2.width + 4 > Wd:
            x = 4
            y += rowh + 6
            rowh = 0
        sheet.paste(im2, (x, y), im2)
        x += im2.width + 6
        rowh = max(rowh, im2.height)
    sheet.crop((0, 0, Wd, y + rowh + 6)).save(os.path.join(OUT, "..", "topdown_preview.png"))
    print(len(out), "sprite")


main()
