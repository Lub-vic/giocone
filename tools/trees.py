"""Alberi grandi in pixel art gotico (sprite singoli, ombreggiatura volumetrica, contorno selettivo).
Uso: python trees.py <cartella_sprites>
"""
import sys, os, math, random
from PIL import Image, ImageDraw

OUT = sys.argv[1] if len(sys.argv) > 1 else "."
os.makedirs(OUT, exist_ok=True)
BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]


def hexc(h):
    h = h.lstrip('#')
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def outline(im):
    w, h = im.size
    src = im.load()
    out = im.copy()
    px = out.load()
    for y in range(h):
        for x in range(w):
            if src[x, y][3]:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and src[nx, ny][3]:
                    c = src[nx, ny]
                    px[x, y] = (int(c[0] * .28), int(c[1] * .26), int(c[2] * .38), 255)
                    break
    return out


def wood(mask, rnd, pal):
    """Colora una maschera di legno: luce da sinistra/alto, striature di corteccia."""
    w, h = mask.size
    m = mask.load()
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px = im.load()
    for y in range(h):
        for x in range(w):
            if not m[x, y]:
                continue
            left = x > 0 and not m[x - 1, y]
            right = x < w - 1 and not m[x + 1, y]
            up = y > 0 and not m[x, y - 1]
            c = pal[1]
            if left or up:
                c = pal[2]
            elif right:
                c = pal[0]
            elif (x * 7 + y // 3 * 5) % 6 == 0:
                c = pal[0]
            elif (x + y // 4 * 3) % 7 == 0:
                c = pal[2]
            px[x, y] = c + (255,)
    return im


def branch(d, rnd, x, y, ang, ln, wd, depth):
    steps = int(ln)
    for i in range(steps):
        nx = x + math.cos(ang)
        ny = y + math.sin(ang)
        d.line([(x, y), (nx, ny)], fill=255, width=max(1, int(round(wd))))
        x, y = nx, ny
        ang += rnd.uniform(-.22, .22)
        wd = max(1, wd * 0.96)
        if depth > 0 and i > 3 and rnd.random() < 0.13:
            a2 = ang + rnd.choice([-1, 1]) * rnd.uniform(.5, 1.0)
            branch(d, rnd, x, y, a2, ln * rnd.uniform(.35, .6), max(1, wd * .7), depth - 1)


def dead_tree(seed):
    rnd = random.Random(seed)
    W, H = 40, 56
    mask = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(mask)
    cx = W // 2
    # tronco ricurvo e radici
    pts = []
    for i in range(30):
        t = i / 29
        pts.append((cx + math.sin(t * 3 + seed) * 2.2 + rnd.uniform(-.3, .3), H - 3 - i))
    for i, (x, y) in enumerate(pts):
        t = i / 29
        wd = 7 - 4 * t
        d.rectangle([x - wd / 2, y, x + wd / 2, y + 1], fill=255)
    for s in (-1, 1):
        d.polygon([(cx + s * 3, H - 4), (cx + s * 8, H - 1), (cx + s * 3, H - 8)], fill=255)
    top = pts[-1]
    for k in range(rnd.randint(4, 6)):
        a = -math.pi / 2 + rnd.uniform(-1.25, 1.25)
        branch(d, rnd, top[0], top[1] + rnd.randint(0, 5), a, rnd.uniform(10, 17), 3, 2)
    for k in range(2):
        j = rnd.randint(8, 18)
        s = rnd.choice([-1, 1])
        branch(d, rnd, pts[j][0], pts[j][1], -math.pi / 2 + s * rnd.uniform(.9, 1.3), rnd.uniform(7, 12), 2, 1)
    im = wood(mask, rnd, [hexc('#1e1620'), hexc('#34283a'), hexc('#5a4a62')])
    # poco muschio verdastro sul lato in ombra
    px = im.load()
    for y in range(H):
        for x in range(W):
            if px[x, y][3] and y > H - 22 and rnd.random() < .08:
                px[x, y] = hexc('#3a5a3a') + (255,)
    return outline(im)


def canopy_tree(seed, pal):
    rnd = random.Random(seed)
    W, H = 52, 64
    mask = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(mask)
    cx = W // 2
    for i in range(22):
        t = i / 21
        d.rectangle([cx - (4 - 1.2 * t), H - 3 - i, cx + (4 - 1.2 * t), H - 2 - i], fill=255)
    for s in (-1, 1):
        d.polygon([(cx + s * 3, H - 4), (cx + s * 9, H - 1), (cx + s * 3, H - 9)], fill=255)
    trunk = wood(mask, rnd, [hexc('#1e1620'), hexc('#34283a'), hexc('#5a4a62')])
    # chioma: campo di altezza fatto di sfere, illuminato da alto-sinistra
    hf = [[0.0] * W for _ in range(H)]
    blobs = []
    for k in range(rnd.randint(11, 15)):
        bx = cx + rnd.uniform(-15, 15)
        by = 24 + rnd.uniform(-10, 8)
        r = rnd.uniform(5.5, 9.5)
        blobs.append((bx, by, r))
    for y in range(H):
        for x in range(W):
            best = 0.0
            for bx, by, r in blobs:
                dd = ((x - bx) ** 2 + (y - by) ** 2) / (r * r)
                if dd < 1:
                    best = max(best, math.sqrt(1 - dd) * r)
            if best > 0:
                best += 1.6 * (math.sin(x * .9 + seed) * math.cos(y * .8) + rnd.uniform(-.5, .5))
            hf[y][x] = best
    can = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    cp = can.load()
    for y in range(1, H - 1):
        for x in range(1, W - 1):
            if hf[y][x] <= 0.8:
                continue
            lit = (hf[y - 1][x - 1] - hf[y + 1][x + 1]) * 0.55 + (hf[y][x] - 6) * 0.06
            v = lit + (BAYER[y % 4][x % 4] / 16 - .5) * 0.45 + rnd.uniform(-.6, .6)
            idx = 3 if v > 1.2 else (2 if v > .2 else (1 if v > -.9 else 0))
            cp[x, y] = pal[idx] + (255,)
    out = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    out.alpha_composite(trunk)
    out.alpha_composite(can)
    # rami secchi che sbucano e muschio penzolante
    px = out.load()
    for k in range(rnd.randint(5, 9)):
        x = rnd.randint(8, W - 9)
        ys = [y for y in range(H) if cp[x, y][3]]
        if not ys:
            continue
        y0 = max(ys)
        for j in range(rnd.randint(3, 9)):
            if y0 + j < H and not px[x, y0 + j][3]:
                px[x, y0 + j] = (0x4a, 0x5a, 0x48, 255) if j % 2 == 0 else (0x36, 0x44, 0x38, 255)
    return outline(out)


GREEN = [hexc('#0a1410'), hexc('#142418'), hexc('#1f3a28'), hexc('#34583a')]
PURPLE = [hexc('#120e1c'), hexc('#1e1a2e'), hexc('#2e2846'), hexc('#463e66')]
SICK = [hexc('#10160c'), hexc('#1c2a14'), hexc('#2e4220'), hexc('#4a6a30')]

if __name__ == "__main__":
    for i in range(4):
        __import__("decay").weather(dead_tree(i * 7 + 3), f"tree_dead_{i}", 0.6, 0.8, 0.5).save(os.path.join(OUT, f"tree_dead_{i}.png"))
    for i in range(3):
        __import__("decay").weather(canopy_tree(i * 5 + 1, GREEN), f"tree_forest_{i}", 0.6, 0.8, 0.5).save(os.path.join(OUT, f"tree_forest_{i}.png"))
    for i in range(2):
        __import__("decay").weather(canopy_tree(i * 5 + 40, PURPLE), f"tree_gloom_{i}", 0.6, 0.8, 0.5).save(os.path.join(OUT, f"tree_gloom_{i}.png"))
    # anteprima
    names = [f"tree_dead_{i}" for i in range(4)] + [f"tree_forest_{i}" for i in range(3)] + [f"tree_gloom_{i}" for i in range(2)]
    pv = Image.new("RGB", (9 * 60 * 3, 70 * 3), (24, 20, 32))
    for k, n in enumerate(names):
        im = Image.open(os.path.join(OUT, n + ".png"))
        im = im.resize((im.width * 3, im.height * 3), Image.NEAREST)
        pv.paste(im, (k * 180 + 10, 10), im)
    pv.save(os.path.join(OUT, "..", "trees_preview.png"))
    print("ok")
