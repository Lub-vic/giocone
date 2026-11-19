"""Genera sprite e tile pixel art (vista dall'alto) in 3 varianti di stile.

Uso: python gen_sprites.py <cartella_output>
Gli sprite sono descritti come forme su griglia di materiali; il motore di stile
applica luce, ombre e contorni, cosi' la stessa forma si puo' rendere in piu' stili.
"""
import math, random, sys, os
from PIL import Image, ImageDraw, ImageFont

N = 20
OUT = sys.argv[1] if len(sys.argv) > 1 else "."
os.makedirs(OUT, exist_ok=True)


def hexc(h):
    h = h.lstrip('#')
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def clamp(v):
    return max(0, min(255, int(round(v))))


def mix(a, b, t):
    return tuple(clamp(a[i] + (b[i] - a[i]) * t) for i in range(3))


def shade(c, k):
    if k == -2: return tuple(clamp(c[i] * m) for i, m in enumerate((.40, .40, .55)))
    if k == -1: return tuple(clamp(c[i] * m) for i, m in enumerate((.66, .64, .80)))
    if k == 1: return mix(c, (255, 232, 185), .28)
    if k == 2: return mix(c, (255, 246, 220), .55)
    return c


class G:
    def __init__(s, n=N):
        s.n = n
        s.m = [[None] * n for _ in range(n)]

    def p(s, x, y, m):
        if 0 <= x < s.n and 0 <= y < s.n: s.m[y][x] = m

    def r(s, x, y, w, h, m):
        for j in range(h):
            for i in range(w): s.p(x + i, y + j, m)

    def e(s, cx, cy, rx, ry, m):
        for y in range(s.n):
            for x in range(s.n):
                if ((x + .5 - cx) / rx) ** 2 + ((y + .5 - cy) / ry) ** 2 <= 1: s.m[y][x] = m

    def l(s, x0, y0, x1, y1, m):
        dx, dy = abs(x1 - x0), -abs(y1 - y0)
        sx, sy = (1 if x0 < x1 else -1), (1 if y0 < y1 else -1)
        err = dx + dy
        while True:
            s.p(x0, y0, m)
            if x0 == x1 and y0 == y1: break
            e2 = 2 * err
            if e2 >= dy: err += dy; x0 += sx
            if e2 <= dx: err += dx; y0 += sy


BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]
OUTLINE = (10, 6, 16)


def render(g, pal, style):
    n = g.n
    pts = [(x, y) for y in range(n) for x in range(n) if g.m[y][x]]
    cx = sum(p[0] for p in pts) / len(pts)
    cy = sum(p[1] for p in pts) / len(pts)
    img = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    px = img.load()

    def at(x, y):
        return g.m[y][x] if 0 <= x < n and 0 <= y < n else None

    pal = {k: hexc(v) for k, v in pal.items()}
    if style == "B":  # tavolozza piu' morbida
        pal = {k: mix(mix(v, (sum(v) // 3,) * 3, .35), (70, 60, 90), .10) for k, v in pal.items()}
    if style == "C":  # piu' satura
        pal = {k: tuple(clamp(sum(v) / 3 + (v[i] - sum(v) / 3) * 1.18) for i in range(3)) for k, v in pal.items()}
    for (x, y) in pts:
        m = g.m[y][x]
        base = pal[m]
        if m == 'g':
            px[x, y] = shade(base, 1) + (255,)
            continue
        d = ((x - cx) + (y - cy)) / (2 * n * .34)
        if style == "A":
            up, lf = at(x, y - 1) != m, at(x - 1, y) != m
            dn, rt = at(x, y + 1) != m, at(x + 1, y) != m
            if (up or lf) and not (dn or rt): t = 1
            elif (dn or rt) and not (up or lf): t = -1
            elif d < -.32: t = 1
            elif d > .34: t = -1
            else: t = 0
            col = shade(base, t)
        elif style == "B":
            t = 1 if d < -.28 else (-1 if d > .22 else 0)
            col = shade(base, t)
            if t == -1 and (x + y) % 2 == 0 and d > .55: col = shade(base, -2)
        else:
            v = d + (BAYER[y % 4][x % 4] / 16 - .5) * .42
            t = 1 if v < -.28 else (-2 if v > .52 else (-1 if v > .16 else 0))
            col = shade(base, t)
            if at(x + 1, y) is None or at(x, y + 1) is None:
                col = mix(col, (110, 165, 255), .42)
            if at(x - 1, y) is None and at(x, y - 1) is None:
                col = mix(col, (255, 220, 150), .35)
        px[x, y] = col + (255,)
    if style in ("A", "B"):
        for y in range(n):
            for x in range(n):
                if g.m[y][x]: continue
                nb = [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]
                near = [at(a, b) for a, b in nb if at(a, b)]
                if not near: continue
                if style == "A":
                    px[x, y] = OUTLINE + (255,)
                else:
                    c = pal[near[0]]
                    px[x, y] = tuple(clamp(c[i] * m_) for i, m_ in enumerate((.30, .28, .42))) + (255,)
    return img


# ---------------------------------------------------------------- personaggi
def knight():
    g = G()
    g.e(4.5, 13.5, 3, 4, 'w'); g.p(4, 13, 'a')
    g.e(10, 12.5, 6, 5, 'c')
    g.r(15, 10, 2, 5, 'c'); g.r(3, 10, 2, 4, 'c')
    g.r(5, 15, 10, 1, 'a')
    g.e(10, 9, 4.3, 4.3, 'h')
    g.e(10, 11, 2.7, 1.8, 's'); g.p(9, 11, 'e'); g.p(11, 11, 'e')
    g.r(9, 5, 2, 2, 'a')
    g.r(16, 13, 1, 6, 'm'); g.r(15, 13, 3, 1, 'a'); g.p(16, 12, 's')
    return g, dict(c='#b8323f', h='#8d97ab', s='#e0b088', a='#d4a640', m='#d6dfee', w='#7a5230', e='#1a1020')


def mage():
    g = G()
    g.e(10, 14.5, 5, 4, 'c')
    g.r(15, 4, 1, 15, 'w')
    g.e(15.5, 4, 2, 2, 'g')
    g.e(10, 9.5, 7, 6, 'h')
    g.e(10, 8.5, 3.6, 3.4, 'c')
    g.r(7, 10, 6, 1, 'a'); g.p(10, 10, 'g')
    g.p(15, 12, 's'); g.p(14, 13, 's')
    return g, dict(c='#8a52c8', h='#3a2468', a='#ffd24a', w='#7a5230', g='#6af0ff', s='#e0b890')


def ranger():
    g = G()
    g.r(13, 6, 2, 7, 'w'); g.p(13, 5, 'm'); g.p(14, 5, 'a')
    g.e(10, 12.5, 5, 5, 'c')
    g.e(10, 9, 4.3, 4.3, 'h')
    g.e(10, 11, 2.5, 1.7, 's'); g.p(9, 11, 'e'); g.p(11, 11, 'e')
    g.l(4, 5, 2, 10, 'w'); g.l(2, 10, 4, 16, 'w'); g.l(4, 5, 4, 16, 'm')
    g.p(5, 12, 's')
    return g, dict(c='#3f9a50', h='#2a6a3a', s='#e0b088', w='#8a5a2a', a='#d8c070', m='#d0d8e0', e='#101a10')


def goblin():
    g = G()
    g.r(16, 7, 2, 10, 'w'); g.p(15, 8, 'm'); g.p(18, 10, 'm'); g.p(15, 11, 'm')
    g.e(10, 13.5, 4.5, 4, 'c')
    g.r(4, 8, 3, 2, 's'); g.r(13, 8, 3, 2, 's'); g.p(4, 7, 's'); g.p(16, 7, 's')
    g.e(10, 9.5, 4, 3.8, 's')
    g.p(8, 9, 'g'); g.p(12, 9, 'g'); g.r(9, 12, 3, 1, 'e')
    g.p(15, 12, 's')
    return g, dict(s='#74a844', c='#8a5230', w='#9a6a3a', m='#aab0b8', g='#ff3a3a', e='#2a1a10')


def orc():
    g = G()
    g.r(17, 6, 1, 12, 'w'); g.e(18, 7.5, 2, 3, 'm')
    g.e(10, 13.5, 7, 5.5, 'c')
    g.e(4, 11, 2.6, 2.6, 'm'); g.e(16, 11, 2.6, 2.6, 'm')
    g.e(10, 8.5, 4.5, 4.2, 's')
    g.p(8, 11, 'w'); g.p(12, 11, 'w'); g.p(8, 8, 'g'); g.p(12, 8, 'g'); g.r(7, 6, 6, 1, 'e')
    g.p(16, 14, 's')
    return g, dict(s='#62a050', c='#6a3a2a', m='#9a9aaa', w='#9a6a3a', g='#ff3a3a', e='#1a2a14')


def skeleton():
    g = G()
    g.r(17, 12, 1, 7, 'm'); g.r(16, 12, 3, 1, 'w')
    g.e(10, 13.5, 4.6, 4.6, 's')
    g.r(7, 12, 6, 1, 'e'); g.r(7, 14, 6, 1, 'e'); g.r(10, 10, 1, 8, 'a')
    g.r(4, 11, 1, 6, 's'); g.r(16, 11, 1, 6, 's')
    g.e(10, 8.5, 4, 4, 's')
    g.r(8, 8, 2, 2, 'e'); g.r(11, 8, 2, 2, 'e'); g.r(9, 11, 3, 1, 'a')
    return g, dict(s='#ece4cc', a='#b4ac8c', e='#14101a', m='#8a7a6a', w='#6a4a2a')


def slime():
    g = G()
    g.e(10, 12, 8, 6, 'c')
    g.e(7, 9, 2.3, 1.6, 'h'); g.p(13, 15, 'h'); g.p(15, 14, 'h')
    g.r(7, 12, 2, 3, 'e'); g.r(12, 12, 2, 3, 'e')
    return g, dict(c='#4ac86a', h='#bcffc4', e='#0e2a16')


def bat():
    g = G()
    g.e(4, 10, 4, 3, 'c'); g.e(16, 10, 4, 3, 'c')
    g.e(4, 10, 2.2, 1.5, 'h'); g.e(16, 10, 2.2, 1.5, 'h')
    g.p(1, 8, 'c'); g.p(18, 8, 'c')
    g.e(10, 11, 2.5, 4, 'c'); g.e(10, 7.5, 2.6, 2.6, 'c')
    g.p(8, 4, 'c'); g.p(12, 4, 'c')
    g.p(9, 7, 'g'); g.p(11, 7, 'g'); g.p(9, 9, 's')
    return g, dict(c='#8a46c0', h='#4e2478', g='#ffee60', s='#ffffff')


def wraith():
    g = G()
    g.r(16, 4, 1, 15, 'w'); g.e(14.5, 5, 3, 1.5, 'm')
    g.e(10, 11, 6, 8, 'c')
    g.r(5, 15, 2, 4, 'c'); g.r(9, 17, 2, 3, 'c'); g.r(13, 15, 2, 4, 'c')
    g.e(10, 8, 4.6, 4.6, 'h')
    g.e(10, 9, 2.8, 2.5, 'e'); g.p(9, 9, 'g'); g.p(11, 9, 'g')
    return g, dict(c='#5a7cc0', h='#2e3e78', e='#05060c', g='#6af0ff', m='#d6dff0', w='#5a4a3a')


CHARS = [("Cavaliere", knight), ("Maga", mage), ("Ranger", ranger), ("Goblin", goblin), ("Orco", orc),
         ("Scheletro", skeleton), ("Slime", slime), ("Pipistrello", bat), ("Spettro", wraith)]


# ---------------------------------------------------------------- oggetti
def tree_oak():
    g = G()
    g.e(10, 10, 9, 9, 'c'); g.e(14, 13, 3.5, 3.5, 'c'); g.e(8, 8, 6.2, 6.2, 'h'); g.e(6, 6, 3, 3, 'a')
    g.p(12, 5, 'h'); g.p(15, 9, 'h')
    return g, dict(c='#1f5a30', h='#2f8a42', a='#7ac860')


def tree_autumn():
    g = G()
    g.e(10, 10, 9, 9, 'c'); g.e(14, 13, 3.5, 3.5, 'c'); g.e(8, 8, 6.2, 6.2, 'h'); g.e(6, 6, 3, 3, 'a')
    g.p(12, 5, 'h'); g.p(15, 9, 'h')
    return g, dict(c='#8a3a14', h='#d0661e', a='#ffc060')


def tree_pine():
    g = G()
    g.e(10, 10, 8, 8, 'c')
    for a, b in ((10, 1), (19, 10), (10, 19), (1, 10), (3, 3), (17, 3), (3, 17), (17, 17)):
        g.l(10, 10, a, b, 'h')
    g.e(10, 10, 5.2, 5.2, 'h'); g.e(10, 10, 3, 3, 'a'); g.p(10, 10, 's')
    return g, dict(c='#1a4040', h='#2f7060', a='#a8e0d0', s='#f0fff8')


def tree_dead():
    g = G()
    for a, b in ((3, 3), (17, 4), (16, 17), (4, 16), (10, 2)):
        g.l(10, 10, a, b, 'w')
    g.l(6, 6, 6, 2, 'w'); g.l(13, 7, 18, 8, 'w'); g.l(13, 13, 11, 18, 'w'); g.l(7, 13, 2, 14, 'w')
    g.e(10, 10, 2.6, 2.6, 'a')
    return g, dict(w='#6a5648', a='#463a32')


def crate():
    g = G()
    g.r(3, 3, 14, 14, 'w'); g.r(3, 9, 14, 1, 'e'); g.r(3, 3, 2, 14, 'a'); g.r(15, 3, 2, 14, 'a')
    g.p(4, 4, 'm'); g.p(15, 15, 'm'); g.p(4, 15, 'm'); g.p(15, 4, 'm')
    return g, dict(w='#8a5a30', e='#4a2e14', a='#6a4222', m='#cdb890')


def barrel():
    g = G()
    g.e(10, 10, 7, 7, 'w'); g.e(10, 10, 5.2, 5.2, 'a'); g.e(10, 10, 3.6, 3.6, 'w'); g.l(10, 3, 10, 16, 'e')
    return g, dict(w='#8a5a30', a='#5a5a68', e='#3a2410')


def chest():
    g = G()
    g.r(3, 5, 14, 11, 'w'); g.r(3, 5, 14, 4, 'h'); g.r(9, 5, 2, 11, 'm'); g.r(9, 9, 2, 2, 'a')
    return g, dict(w='#7a4a22', h='#a06830', m='#aab0b8', a='#ffd24a')


def campfire():
    g = G()
    g.e(10, 10, 8, 8, 'm'); g.e(10, 10, 6, 6, 'e'); g.l(5, 14, 15, 6, 'w'); g.l(5, 6, 15, 14, 'w')
    g.e(10, 10, 4, 4, 'c'); g.e(10, 10, 2.4, 2.4, 'h'); g.p(10, 10, 'g'); g.p(9, 9, 'g')
    return g, dict(m='#6a6a78', e='#1a1210', w='#6a4222', c='#ff6a20', h='#ffc040', g='#fff2b0')


def gravestone():
    g = G()
    g.e(10, 16, 7, 3, 'w'); g.r(6, 5, 8, 11, 'm'); g.e(10, 6, 4, 2.5, 'm')
    g.r(10, 6, 1, 6, 'e'); g.r(8, 8, 5, 1, 'e'); g.r(6, 14, 8, 2, 'c'); g.p(7, 13, 'c')
    return g, dict(w='#5a4030', m='#9aa0ac', e='#4a505c', c='#3f7a40')


def mushrooms():
    g = G()
    g.e(7, 9, 4, 4, 'c'); g.e(14.5, 12.5, 3.2, 3.2, 'c'); g.e(9, 15.5, 2.6, 2.6, 'c')
    g.p(6, 8, 'h'); g.p(8, 10, 'h'); g.p(14, 12, 'h'); g.p(9, 15, 'h'); g.p(13, 11, 'g'); g.p(5, 10, 'g')
    return g, dict(c='#2aa8c8', h='#c8fbff', g='#ffffff')


PROPS = [("Quercia", tree_oak), ("Albero autunnale", tree_autumn), ("Pino", tree_pine), ("Albero secco", tree_dead),
         ("Cassa", crate), ("Barile", barrel), ("Forziere", chest), ("Falo'", campfire), ("Lapide", gravestone),
         ("Funghi magici", mushrooms)]

# ---------------------------------------------------------------- tile
T = 16


def tile(kind, seed):
    r = random.Random(seed)
    im = Image.new("RGB", (T, T))
    px = im.load()

    def fill(c):
        for y in range(T):
            for x in range(T): px[x, y] = hexc(c)

    def spot(c, n, w=1, h=1):
        for _ in range(n):
            x, y = r.randrange(T), r.randrange(T)
            for j in range(h):
                for i in range(w):
                    if x + i < T and y + j < T: px[x + i, y + j] = hexc(c)

    if kind == "Erba":
        fill(r.choice(['#3f7a3c', '#468646', '#3a7038']))
        spot('#2e6a3a', 8); spot('#2a5c30', 4, 1, 2); spot('#6ab04e', 6); spot('#58a046', 3, 1, 2)
        if r.random() < .35: spot(r.choice(['#ffe070', '#ff9ac0', '#ffffff']), 1)
    elif kind == "Sottobosco":
        fill(r.choice(['#2a4a30', '#26442c']))
        spot('#1a3220', 9); spot('#c8601c', 3); spot('#8a3a14', 2); spot('#3a6a40', 5)
        if r.random() < .5:
            y = r.randrange(3, 13)
            for x in range(T): px[x, y] = hexc('#4a3220') if x % 3 else hexc('#5a4028')
    elif kind == "Ciottoli":
        fill('#23262c')
        y = 0
        while y < T:
            h = r.randint(4, 7); x = 0
            while x < T:
                w = r.randint(4, 8); c = hexc(r.choice(['#5a6068', '#646a72', '#4e545c', '#6a7078']))
                for j in range(1, h):
                    for i in range(1, w):
                        if x + i < T and y + j < T: px[x + i, y + j] = c
                x += w
            y += h
        spot('#7c828a', 6); spot('#2f4a30', 2, 2, 1)
    elif kind == "Lastre":
        fill('#2a231d')
        for ty in range(2):
            for tx in range(2):
                c = hexc(r.choice(['#4a4036', '#544a3e', '#463c33', '#5a4f42']))
                for j in range(1, 8):
                    for i in range(1, 8): px[tx * 8 + i, ty * 8 + j] = c
        spot('#6a5e4e', 4); spot('#2a231d', 3, 3, 1)
    elif kind == "Neve":
        fill(r.choice(['#dfe9f2', '#e6eff7', '#d4e2ee']))
        spot('#b4cbe0', 10); spot('#9fb8d0', 3, 2, 1); spot('#ffffff', 4)
    elif kind == "Sabbia":
        fill(r.choice(['#d8b868', '#dcc070', '#d0b062']))
        for k in range(2):
            y = r.randrange(T)
            for x in range(T): px[x, (y + (x // 5) % 2) % T] = hexc('#bd9c4e')
        spot('#efd488', 5); spot('#a88a40', 3)
    elif kind == "Roccia lavica":
        fill(r.choice(['#2a2224', '#302628', '#262022']))
        spot('#3e3234', 8)
        x, y = r.randrange(T), r.randrange(T)
        for _ in range(14):
            px[x % T, y % T] = hexc('#ff5a1a')
            if r.random() < .4: px[(x + 1) % T, y % T] = hexc('#ffb040')
            x += r.choice([-1, 0, 1, 1]); y += r.choice([-1, 0, 1, 1])
    elif kind == "Terra":
        fill(r.choice(['#8a6a42', '#94724a', '#80623c']))
        spot('#6a4a2a', 8); spot('#b08850', 7); spot('#a07c4c', 3, 2, 1); spot('#5a3c20', 3)
    elif kind == "Campo":
        fill('#5a3e22')
        for y in range(1, T, 4):
            for x in range(T): px[x, y] = hexc('#3e2a14'); px[x, (y + 1) % T] = hexc('#6a4a2a')
        for y in range(2, T, 4):
            for x in range(r.randrange(2), T, 3):
                px[x, y] = hexc(r.choice(['#5aa04a', '#6ab858', '#4a8a3a']))
    elif kind == "Cripta":
        fill('#2a2538')
        for ty in range(2):
            for tx in range(2):
                c = hexc(r.choice(['#3a3548', '#403a52', '#353044', '#443e58']))
                for j in range(1, 8):
                    for i in range(1, 8): px[tx * 8 + i, ty * 8 + j] = c
        spot('#524a6a', 4); spot('#1e1a28', 3, 3, 1)
        if r.random() < .25:
            cx, cy = r.randrange(3, 12), r.randrange(3, 12)
            for dx, dy in ((0, 0), (1, 0), (0, 1), (-1, 1), (1, -1)): px[(cx + dx) % T, (cy + dy) % T] = hexc('#6a50a0')
    elif kind == "Palude":
        fill(r.choice(['#3e4a2c', '#46522f']))
        spot('#2a3420', 6)
        if r.random() < .6:
            cx, cy = r.randrange(4, 12), r.randrange(4, 12)
            for j in range(-3, 4):
                for i in range(-4, 5):
                    if (i / 4) ** 2 + (j / 3) ** 2 <= 1: px[(cx + i) % T, (cy + j) % T] = hexc('#2a5a5a')
            px[cx % T, (cy - 1) % T] = hexc('#8ad8d0')
        spot('#7a8a3a', 3, 1, 3)
    return im


TILES = ["Erba", "Sottobosco", "Ciottoli", "Lastre", "Neve", "Sabbia", "Roccia lavica", "Palude"]


def tile_style(im, style, k):
    if style == "A":
        return im
    if style == "B":
        out = Image.new("RGB", (T, T)); o, s = out.load(), im.load()
        for y in range(T):
            for x in range(T):
                c = s[x, y]; gr = sum(c) // 3
                c = mix(mix(c, (gr,) * 3, .45), (74, 66, 96), .14)
                o[x, y] = tuple(clamp(v * .92) for v in c)
        return out
    out = Image.new("RGB", (T, T)); o, s = out.load(), im.load()
    for y in range(T):
        for x in range(T):
            c = s[x, y]
            v = (x + y) / (2 * T) + (BAYER[y % 4][x % 4] / 16 - .5) * .5
            if v < .30: c = mix(c, (255, 214, 140), .20)
            elif v > .62: c = mix(c, (40, 50, 110), .38)
            o[x, y] = tuple(clamp(round(v_ / 24) * 24) for v_ in c)
    return out


# ---------------------------------------------------------------- fogli
SC = 6
BG = (22, 18, 30)
try:
    F1 = ImageFont.truetype("arialbd.ttf", 15)
    F2 = ImageFont.truetype("arial.ttf", 13)
except Exception:
    F1 = F2 = ImageFont.load_default()
STYLES = [("A", "A · Contorno scuro"), ("B", "B · Contorno selettivo"), ("C", "C · Dithering e luce")]


def sheet(items, fname, builder, cell, label_w=190):
    cols = len(items)
    W = label_w + cols * cell
    H = 34 + len(STYLES) * (cell + 6)
    img = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(img)
    for ci, name in enumerate(items):
        d.text((label_w + ci * cell + 6, 10), name, font=F1, fill=(255, 210, 74))
    for si, (sk, sl) in enumerate(STYLES):
        y0 = 34 + si * (cell + 6)
        d.text((8, y0 + cell // 2 - 18), sl.split(" · ")[0], font=F1, fill=(255, 210, 74))
        d.text((8, y0 + cell // 2), sl.split(" · ")[1], font=F2, fill=(200, 196, 210))
        for ci in range(cols):
            x0 = label_w + ci * cell
            d.rectangle([x0, y0, x0 + cell - 4, y0 + cell - 2], fill=(30, 26, 42))
            tile_img = builder(ci, sk)
            big = tile_img.resize((tile_img.width * SC, tile_img.height * SC), Image.NEAREST)
            ox = x0 + (cell - 4 - big.width) // 2
            oy = y0 + (cell - 2 - big.height) // 2
            if big.mode == "RGBA":
                sh = Image.new("RGBA", big.size, (0, 0, 0, 0))
                sd = ImageDraw.Draw(sh)
                sd.ellipse([big.width * .18, big.height * .72, big.width * .82, big.height * .98], fill=(0, 0, 0, 90))
                img.paste(sh, (ox, oy), sh)
                img.paste(big, (ox, oy), big)
            else:
                img.paste(big, (ox, oy))
    img.save(os.path.join(OUT, fname))


def bch(ci, sk):
    g, pal = CHARS[ci][1]()
    return render(g, pal, sk)


def bpr(ci, sk):
    g, pal = PROPS[ci][1]()
    return render(g, pal, sk)


def btl(ci, sk):
    # mosaico 3x3 di varianti per mostrare la ripetizione
    big = Image.new("RGB", (T * 3, T * 3))
    for j in range(3):
        for i in range(3):
            big.paste(tile_style(tile(TILES[ci], 100 + ci * 10 + j * 3 + i), sk, ci), (i * T, j * T))
    return big


if __name__ == "__main__":
    sheet([c[0] for c in CHARS], "personaggi.png", bch, N * SC + 4)
    sheet([c[0] for c in PROPS], "oggetti.png", bpr, N * SC + 4)
    sheet(TILES, "terreni.png", btl, T * 3 * SC + 4)
    print("ok")
