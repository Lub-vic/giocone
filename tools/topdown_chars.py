"""Sprite DALL'ALTO di personaggi e mostri, disegnati a codice (niente AI): per ognuno un'immagine a colori e una mappa delle altezze.
Davanti = alto dell'immagine (nord). Il centro dell'immagine e' il punto di terra della creatura.
Uso: python topdown_chars.py <cartella_out> [--preview file.png]
Scrive <kind>.png (RGBA) e <kind>_h.png (altezza in livelli, grigio) per ogni creatura.
"""
import math, os, sys
from PIL import Image, ImageDraw


def C(h, k=1.0):
    h = h.lstrip('#')
    r, g, b = (int(h[i:i + 2], 16) for i in (0, 2, 4))
    return (min(255, int(r * k)), min(255, int(g * k)), min(255, int(b * k)), 255)


def mul(c, k):
    return (max(0, min(255, int(c[0] * k))), max(0, min(255, int(c[1] * k))), max(0, min(255, int(c[2] * k))), c[3])


class Cv:
    def __init__(s, n=24):
        s.n = n
        s.c = [[None] * n for _ in range(n)]
        s.h = [[0] * n for _ in range(n)]

    def put(s, x, y, col, h):
        x, y = int(x), int(y)
        if 0 <= x < s.n and 0 <= y < s.n:
            s.c[y][x] = col
            s.h[y][x] = h

    def ell(s, cx, cy, rx, ry, col, h, dome=2.0, shade=True):
        for y in range(s.n):
            for x in range(s.n):
                nx = (x + .5 - cx) / rx
                ny = (y + .5 - cy) / ry
                d2 = nx * nx + ny * ny
                if d2 <= 1.0:
                    d = math.sqrt(d2)
                    f = 1.0
                    if shade:
                        f = 1.0 + 0.2 * (-(nx * .5 + ny * .7)) - 0.22 * d2
                    s.put(x, y, mul(col, f), h + round(dome * (1 - d)))

    def rect(s, x, y, w, hh, col, h):
        for j in range(int(hh)):
            for i in range(int(w)):
                s.put(x + i, y + j, col, h)

    def poly(s, pts, col, h, shade=0.0):
        for y in range(s.n):
            for x in range(s.n):
                if inside(x + .5, y + .5, pts):
                    s.put(x, y, col, h)

    def line(s, x0, y0, x1, y1, col, h, w=1):
        n = int(max(abs(x1 - x0), abs(y1 - y0)) * 2) + 1
        for i in range(n + 1):
            t = i / n
            x = x0 + (x1 - x0) * t
            y = y0 + (y1 - y0) * t
            for a in range(w):
                for b in range(w):
                    s.put(math.floor(x - (w - 1) / 2 + a), math.floor(y - (w - 1) / 2 + b), col, h)

    def outline(s, col_k=0.28):
        add = []
        for y in range(s.n):
            for x in range(s.n):
                if s.c[y][x] is None:
                    best = None
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        xx, yy = x + dx, y + dy
                        if 0 <= xx < s.n and 0 <= yy < s.n and s.c[yy][xx] is not None:
                            if best is None or s.h[yy][xx] > best[1]:
                                best = (s.c[yy][xx], s.h[yy][xx])
                    if best:
                        add.append((x, y, mul(best[0], col_k), max(1, best[1] - 3)))
        for x, y, col, h in add:
            s.put(x, y, (col[0], col[1], col[2], 255), h)


def inside(x, y, pts):
    ins = False
    j = len(pts) - 1
    for i in range(len(pts)):
        xi, yi = pts[i]
        xj, yj = pts[j]
        if ((yi > y) != (yj > y)) and (x < (xj - xi) * (y - yi) / (yj - yi + 1e-9) + xi):
            ins = not ins
        j = i
    return ins


def eyes(v, x, y, col, dx=1.8, h=11):
    v.put(x - dx, y, col, h)
    v.put(x + dx - 1, y, col, h)


def face_void(v, x, y, rx=2.4, ry=1.5, h=10):
    v.ell(x, y, rx, ry, C('#06040a'), h, 0, False)


def sword(v, x, y0, y1, blade, hilt, h=8, w=1):
    v.line(x, y0, x, y1, blade, h, w)
    v.line(x, y0 - 0.2, x, y0 - 3, mul(blade, 1.25), h + 1, 1)
    v.rect(x - 2, y1 + 0.5 if y1 > y0 else y1, 4, 1, hilt, h)
    v.put(x, y1 + 2, hilt, h)


def bow(v, x, col, y0=3, y1=21):
    n = y1 - y0
    for i in range(n + 1):
        t = i / n
        v.put(x - round(math.sin(t * math.pi) * 3), y0 + i, col, 8)
    v.line(x + 0.5, y0, x + 0.5, y1, C('#d8d0b8'), 7, 1)


def staff(v, x, y0, y1, col, h=8):
    v.line(x, y0, x, y1, col, h, 1)


def feet(v, cx, y, col, h=2, dx=3):
    v.ell(cx - dx, y, 1.8, 2.2, col, h, 1)
    v.ell(cx + dx, y, 1.8, 2.2, col, h, 1)


def pauldrons(v, cx, y, rx, ry, col, h=7, dx=6.8):
    v.ell(cx - dx, y, rx, ry, col, h, 2)
    v.ell(cx + dx, y, rx, ry, col, h, 2)


# ------------------------------------------------------------------ creature
def hero():
    v = Cv()
    v.ell(12, 16, 7, 6, C('#7a2e38'), 3, 1)
    feet(v, 12, 19, C('#2a2430'))
    v.ell(12, 13.5, 6.4, 4.4, C('#2c2438'), 5, 2)
    v.rect(6, 13, 12, 1, C('#c0a040'), 6)
    pauldrons(v, 12, 12.5, 2.8, 3.2, C('#9a9aa6'))
    v.poly([(9, 12), (15, 12), (12, 18)], C('#5a525a'), 8)
    v.ell(12, 10.5, 4.6, 4.5, C('#6e666e'), 8, 3)
    face_void(v, 12, 8.3, 2.7, 1.6, 11)
    eyes(v, 12, 8.3, C('#ffc060'), 1.6, 12)
    sword(v, 20.5, 3, 12, C('#b0b0ba'), C('#c0a040'))
    return v


def hunter():
    v = Cv()
    v.ell(12, 15.5, 7.5, 6.5, C('#2e2e34'), 3, 1)
    v.ell(12, 13.5, 6.6, 4.6, C('#3c3c40'), 5, 2)
    v.rect(14, 15, 3, 5, C('#5a4a3a'), 7)
    for i in range(3):
        v.put(14.5 + i, 14, C('#d8d0b0'), 8)
    pauldrons(v, 12, 12.5, 2.6, 3, C('#5a4a3c'))
    v.ell(12, 10.5, 4.6, 4.5, C('#585860'), 8, 3)
    face_void(v, 12, 8.3, 2.6, 1.5, 11)
    eyes(v, 12, 8.3, C('#ffd070'), 1.6, 12)
    bow(v, 3.5, C('#7a5a38'))
    return v


def necro():
    v = Cv()
    v.ell(12, 16, 7, 6, C('#2a1c34'), 3, 1)
    v.ell(12, 13.5, 6.4, 4.4, C('#34224a'), 5, 2)
    pauldrons(v, 12, 12.5, 2.6, 3, C('#3a2a4a'))
    v.poly([(9, 12), (15, 12), (12, 18.5)], C('#403c46'), 8)
    v.ell(12, 10.5, 4.6, 4.5, C('#4c4850'), 8, 3)
    face_void(v, 12, 8.3, 2.7, 1.6, 11)
    eyes(v, 12, 8.3, C('#60f0a0'), 1.6, 12)
    staff(v, 20.5, 20, 4, C('#4a3626'))
    v.ell(20.5, 3.5, 2.6, 2.6, C('#d8d0bc'), 9, 3)
    v.put(19.5, 3, C('#60f0a0'), 12)
    v.put(21.5, 3, C('#60f0a0'), 12)
    return v


def cleric():
    v = Cv()
    v.ell(12, 15.5, 6.5, 6, C('#7a2c34'), 3, 1)
    v.ell(12, 13, 8.2, 4.4, C('#c8c8d4'), 6, 2)
    v.rect(11, 12, 2, 4, C('#d8b040'), 8)
    v.rect(9.5, 13, 5, 1, C('#d8b040'), 8)
    pauldrons(v, 12, 12.5, 2.4, 3, C('#9090a8'), 8, 7.4)
    v.ell(12, 10.2, 4.1, 4.1, C('#d8d0c4'), 9, 3)
    v.rect(8, 8, 8, 1, C('#e8e8f0'), 12)
    eyes(v, 12, 9, C('#403038'), 1.4, 12)
    staff(v, 20.5, 21, 7, C('#4a3626'))
    v.rect(17.5, 3.5, 6, 4, C('#8a8a98'), 10)
    v.rect(18, 4, 5, 1, C('#b0b0c0'), 11)
    return v


def skeleton(archer=False):
    v = Cv()
    bone = C('#c0bca6')
    feet(v, 12, 20, mul(bone, .8))
    v.ell(12, 14.5, 5.8, 3.0, mul(bone, .8), 5, 1)
    for i in range(3):
        v.rect(8 + i * 0, 13 + i, 8, 1, bone, 6)
    v.line(12, 12, 12, 19, mul(bone, .7), 5, 1)
    v.line(5, 13, 5, 6, bone, 6, 1)
    v.line(19, 13, 19, 7, bone, 6, 1)
    v.ell(12, 10, 4.5, 4.7, mul(bone, 1.1), 9, 3)
    v.put(10, 8, C('#0a0608'), 12)
    v.put(10.5, 8, C('#0a0608'), 12)
    v.put(13, 8, C('#0a0608'), 12)
    v.put(13.5, 8, C('#0a0608'), 12)
    v.put(10, 8, C('#ff8070'), 13)
    v.rect(10, 5, 4, 1, C('#e8e4d0'), 12)
    if archer:
        bow(v, 3.5, C('#7a6a52'))
        v.rect(14, 15, 3, 5, C('#7a2c2c'), 7)
    else:
        v.ell(3.5, 12.5, 3.8, 4.4, C('#b0a070'), 8, 2)
        v.ell(3.5, 12.5, 1.1, 1.3, C('#8a7a50'), 11, 0)
        sword(v, 20.5, 3, 13, C('#a8a8ae'), C('#6a5a3a'))
    return v


def ghoul():
    v = Cv()
    sk = C('#8c8c90')
    v.ell(12, 14.5, 7.4, 6.2, mul(sk, .78), 5, 3)
    v.ell(12, 9.5, 4.4, 3.9, sk, 8, 3)
    eyes(v, 12, 8, C('#ffe070'), 1.7, 12)
    v.rect(10, 11, 4, 1, C('#080808'), 11)
    for i in range(4):
        v.put(10 + i, 11, C('#e8e4d6'), 12)
    for s in (-1, 1):
        v.line(12 + s * 6.5, 12.5, 12 + s * 8.5, 3.5, mul(sk, .9), 6, 2)
        for k in range(3):
            v.put(12 + s * (8 + k * 0.9) - (0 if s > 0 else 0), 2.5 - 0, C('#dcd8c8'), 8)
        v.put(12 + s * 8.4, 2, C('#dcd8c8'), 8)
    feet(v, 12, 20, mul(sk, .7))
    return v


def zombie():
    v = Cv()
    sk = C('#7c8a6c')
    v.ell(12, 14, 6.4, 4.8, C('#4a4e56'), 5, 2)
    for s in (-1, 1):
        v.line(12 + s * 5, 12, 12 + s * 5.5, 3, sk, 6, 2)
        v.ell(12 + s * 5.5, 3, 1.5, 1.6, mul(sk, .92), 7, 1)
    v.ell(12, 10.5, 4.1, 4.0, sk, 8, 3)
    v.put(10, 9, C('#101010'), 12)
    v.put(14, 9, C('#101010'), 12)
    v.put(10, 9, C('#e0f080'), 12)
    v.rect(10, 12, 4, 1, C('#301818'), 11)
    feet(v, 12, 19.5, C('#2e3036'))
    return v


def spider():
    v = Cv()
    sk = C('#4a4658')
    legc = C('#2e2a3c')
    for i in range(4):
        for s in (-1, 1):
            y0 = 10 + i * 2.6
            xj = 12 + s * 8
            yj = 6 + i * 3.3
            v.line(12 + s * 3, y0, xj, yj, legc, 3, 1)
            v.line(xj, yj, 12 + s * 11, y0 + 2 + i, mul(legc, .85), 2, 1)
    v.ell(12, 15.5, 4.6, 5.4, sk, 5, 3)
    v.ell(12, 10, 3.2, 3, mul(sk, 1.15), 6, 2)
    v.put(12, 15, C('#c85060'), 9)
    v.put(11, 16, C('#c85060'), 9)
    v.put(13, 16, C('#c85060'), 9)
    for dx in (-1.4, -0.4, 0.5, 1.4):
        v.put(12 + dx, 8.5, C('#ff5060'), 9)
    v.put(10.5, 7, C('#d8d0c0'), 7)
    v.put(13.5, 7, C('#d8d0c0'), 7)
    return v


def gargoyle():
    v = Cv()
    st = C('#5a5a64')
    for s in (-1, 1):
        v.poly([(12 + s * 4, 12), (12 + s * 11.5, 6), (12 + s * 11, 14), (12 + s * 8, 17), (12 + s * 4, 17)], C('#6a6a58'), 4)
        v.line(12 + s * 4.5, 12, 12 + s * 11, 7, C('#44444c'), 5, 1)
    v.ell(12, 14, 5.4, 5.6, st, 5, 3)
    v.ell(12, 9, 4, 3.6, mul(st, 1.1), 8, 3)
    eyes(v, 12, 8, C('#ffb040'), 1.6, 12)
    for s in (-1, 1):
        v.line(12 + s * 2.6, 7, 12 + s * 3.5, 4, C('#3a3a42'), 10, 1)
        v.put(12 + s * 4, 19, C('#303038'), 2)
    return v


def ooze():
    v = Cv()
    sl = C('#7a4a50')
    v.ell(12, 13, 9.5, 7.6, sl, 4, 4)
    v.ell(9, 10, 4.5, 3.6, mul(sl, 1.2), 7, 2)
    v.ell(15.5, 14.5, 3.6, 3, mul(sl, .9), 7, 2)
    v.ell(10.5, 9, 1.4, 1.1, C('#ffe0e0'), 11, 0, False)
    v.put(12, 11, C('#ffa0a0'), 11)
    v.put(15, 11, C('#ffa0a0'), 11)
    return v


def bat():
    v = Cv()
    bd = C('#4a4458')
    for s in (-1, 1):
        v.poly([(12 + s * 2, 9), (12 + s * 11.5, 6), (12 + s * 10, 11), (12 + s * 8, 10), (12 + s * 7.5, 15), (12 + s * 5, 13), (12 + s * 3.5, 16), (12 + s * 2, 14)], C('#5a4e6c'), 4)
        v.line(12 + s * 2.5, 10, 12 + s * 11, 6.5, C('#2e2840'), 5, 1)
        v.line(12 + s * 2.5, 11, 12 + s * 8, 15, C('#2e2840'), 5, 1)
    v.ell(12, 12.5, 3.2, 4.6, bd, 6, 3)
    v.ell(12, 8.5, 2.8, 2.6, mul(bd, 1.15), 8, 2)
    for s in (-1, 1):
        v.poly([(12 + s * 1, 7), (12 + s * 2.8, 4), (12 + s * 3.2, 7.4)], mul(bd, .8), 9)
    eyes(v, 12, 8, C('#ff5878'), 1.4, 12)
    return v


def rat():
    v = Cv()
    fur = C('#7a6e70')
    v.line(12, 17, 15, 21, C('#b08888'), 2, 1)
    v.line(15, 21, 18, 20, C('#b08888'), 2, 1)
    v.ell(12, 13.5, 3.8, 5.6, fur, 4, 2)
    v.ell(12, 8, 2.5, 2.8, mul(fur, 1.12), 6, 2)
    for s in (-1, 1):
        v.ell(12 + s * 2.2, 6.3, 1.2, 1.2, C('#c09090'), 7, 0)
    v.put(12, 4.6, C('#d0a0a0'), 6)
    v.put(11, 7, C('#ff6070'), 8)
    v.put(13, 7, C('#ff6070'), 8)
    return v


def imp():
    v = Cv()
    sk = C('#8a4a40')
    for s in (-1, 1):
        v.poly([(12 + s * 3, 11), (12 + s * 10.5, 8), (12 + s * 9, 14), (12 + s * 4, 15)], C('#6a3038'), 4)
        v.line(12 + s * 3.5, 11.5, 12 + s * 10, 8.5, C('#3a1a20'), 5, 1)
    v.line(12, 17, 14, 21, mul(sk, .8), 3, 1)
    v.poly([(13, 20.5), (16, 20), (14.5, 23)], C('#b05048'), 3)
    v.ell(12, 14, 4.6, 4.8, mul(sk, .85), 5, 2)
    v.ell(12, 9.5, 3.9, 3.7, sk, 8, 3)
    for s in (-1, 1):
        v.line(12 + s * 2.5, 7, 12 + s * 4.5, 3.5, C('#d8d0b0'), 9, 1)
    eyes(v, 12, 8.5, C('#ffe060'), 1.5, 12)
    v.rect(10.5, 11.5, 3, 1, C('#200808'), 11)
    return v


def wisp():
    v = Cv()
    v.ell(12, 16, 3.2, 6, C('#5a7a98'), 3, 2)
    v.ell(12, 11, 5.4, 7, C('#7a9ab8'), 5, 5)
    v.ell(12, 10, 3.2, 4.6, C('#a8cce0'), 8, 3)
    v.put(10, 9, C('#102030'), 13)
    v.put(14, 9, C('#102030'), 13)
    v.ell(12, 8, 1.2, 1, C('#e8f4ff'), 12, 0, False)
    return v


def toad():
    v = Cv()
    sk = C('#6a7a50')
    for s in (-1, 1):
        v.ell(12 + s * 8, 17.5, 2.6, 3.4, mul(sk, .8), 2, 1)
        v.ell(12 + s * 7.5, 9.5, 2.2, 2.8, mul(sk, .85), 2, 1)
    v.ell(12, 14, 8, 6.4, sk, 4, 4)
    v.ell(12, 8.8, 5.4, 4.2, mul(sk, 1.1), 6, 3)
    for s in (-1, 1):
        v.ell(12 + s * 3.6, 6.2, 1.9, 1.9, mul(sk, 1.25), 9, 1)
        v.put(12 + s * 3.6, 6, C('#ffe060'), 12)
    v.rect(9, 11, 6, 1, C('#2a2418'), 9)
    for i in range(4):
        v.put(8 + i * 3, 13, mul(sk, .7), 8)
    return v


def wolf():
    v = Cv()
    fur = C('#80808c')
    dk = C('#4a4a56')
    v.ell(12, 20.5, 2.6, 3.6, mul(fur, .9), 3, 2)
    v.line(12, 21, 13.5, 23.5, mul(fur, .8), 3, 3)
    for s in (-1, 1):
        v.ell(12 + s * 5.2, 9.5, 1.8, 2.6, dk, 2, 1)
        v.ell(12 + s * 5.4, 18.5, 1.9, 2.8, dk, 2, 1)
    v.ell(12, 14.5, 5.6, 7.4, fur, 5, 3)
    v.ell(12, 14.5, 2.4, 6.2, dk, 8, 1)
    for i in range(5):
        v.put(11.5 + (i % 2), 10 + i * 1.8, mul(dk, .7), 9)
    v.ell(12, 7.2, 4.0, 3.8, mul(fur, 1.1), 7, 3)
    v.ell(12, 3.9, 2.1, 2.6, mul(fur, 1.25), 6, 1)
    v.put(11.5, 1.6, C('#14101a'), 8)
    v.put(12.5, 1.6, C('#14101a'), 8)
    for s in (-1, 1):
        v.poly([(12 + s * 2.4, 6.2), (12 + s * 5.4, 2.6), (12 + s * 5.2, 7.2)], dk, 10)
        v.poly([(12 + s * 2.8, 5.8), (12 + s * 4.6, 3.8), (12 + s * 4.5, 6.4)], C('#c09090'), 11)
    eyes(v, 12, 5.8, C('#ffc060'), 2.0, 12)
    return v


def goblin_base(v, skin):
    for s in (-1, 1):
        v.poly([(12 + s * 3.5, 9.5), (12 + s * 11.5, 7.5), (12 + s * 11, 8.6), (12 + s * 4, 12)], skin, 8)
    v.ell(12, 14.5, 4.6, 4.2, C('#4a3a2c'), 5, 2)
    for s in (-1, 1):
        v.ell(12 + s * 5.4, 13.5, 1.7, 2.4, skin, 5, 1)
    feet(v, 12, 19.5, mul(skin, .7), 2, 2.4)
    v.ell(12, 10, 4.7, 4.0, skin, 8, 3)
    eyes(v, 12, 8.6, C('#ffe030'), 2.2, 12)
    v.put(12, 10.8, mul(skin, .75), 11)
    v.rect(10.5, 11.5, 3, 1, C('#0a0806'), 11)
    v.put(10.8, 11.5, C('#e8e4d0'), 12)
    v.put(13.2, 11.5, C('#e8e4d0'), 12)


def goblin(kind='goblin'):
    v = Cv()
    skin = C('#76905a')
    goblin_base(v, skin)
    if kind == 'goblin':
        v.line(19.5, 13, 19.5, 5, C('#b8bcc4'), 7, 1)
        v.rect(18.5, 13, 3, 1, C('#6a4a2a'), 7)
    elif kind == 'archer':
        bow(v, 3, C('#6a5236'))
        v.rect(14, 15.5, 3, 4, C('#5a4630'), 7)
        v.put(15, 14.5, C('#d8d0b0'), 8)
    else:
        for i in range(7):
            a = -2.6 + i * 0.43
            v.line(12 + math.sin(a) * 4, 10 + math.cos(a) * 3.4, 12 + math.sin(a) * 7.2, 10 + math.cos(a) * 6.2, [C('#c04838'), C('#d8a838'), C('#c04838'), C('#2a8a6a')][i % 4], 9, 1)
        v.rect(9.5, 7, 5, 4, C('#e0d8c0'), 12)
        v.put(10.5, 8, C('#0a0806'), 13)
        v.put(13.5, 8, C('#0a0806'), 13)
        staff(v, 20.5, 20, 4, C('#5a4630'))
        v.ell(20.5, 3.5, 2.2, 2.2, C('#d8d0b8'), 9, 3)
        v.put(20, 3, C('#70f0b0'), 12)
        v.put(21, 3, C('#70f0b0'), 12)
    return v


def kobold():
    v = Cv()
    sk = C('#8a5a3a')
    v.line(12, 17.5, 15, 22, mul(sk, .85), 2, 2)
    v.line(15, 22, 19, 22, mul(sk, .85), 2, 1)
    v.ell(12, 14.5, 3.9, 4.1, C('#6a4a38'), 5, 2)
    for s in (-1, 1):
        v.ell(12 + s * 4.6, 13.5, 1.5, 2.2, sk, 5, 1)
    feet(v, 12, 19.5, mul(sk, .75), 2, 2)
    v.ell(12, 10.5, 4.3, 3.8, sk, 8, 3)
    v.ell(12, 6.8, 2.3, 2.5, mul(sk, 1.22), 7, 2)
    for s in (-1, 1):
        v.line(12 + s * 3.2, 8, 12 + s * 5, 3.5, C('#e8e0cc'), 9, 1)
    eyes(v, 12, 8.8, C('#ffd840'), 1.9, 12)
    v.put(12, 5.5, C('#100808'), 8)
    v.line(3.5, 21, 3.5, 2, C('#6a4a2a'), 7, 1)
    v.poly([(2.5, 3), (4.5, 3), (3.5, 0.5)], C('#b8bcc4'), 8)
    return v


def orc():
    v = Cv()
    sk = C('#6a8250')
    feet(v, 12, 20.5, C('#2a2622'), 2, 3.4)
    v.ell(12, 14, 8.4, 5.2, C('#4a3a32'), 5, 3)
    v.ell(12, 13.2, 4.2, 2.8, C('#7a7a6a'), 8, 1)
    pauldrons(v, 12, 12.5, 3.2, 3.6, sk, 7, 8.4)
    v.ell(12, 9.8, 4.6, 4.2, sk, 9, 3)
    eyes(v, 12, 8.4, C('#ffe040'), 2, 13)
    for s in (-1, 1):
        v.line(12 + s * 2.3, 11.6, 12 + s * 2.3, 9.8, C('#f0ece0'), 12, 1)
    v.rect(10, 11.6, 4, 1, C('#0a0806'), 11)
    v.ell(2.8, 13.5, 3.4, 4.6, C('#9a9aa4'), 9, 2)
    v.ell(2.8, 13.5, 1.1, 1.3, C('#6a6a74'), 12, 0)
    v.line(21, 22, 21, 6, C('#5a4630'), 8, 1)
    v.ell(21, 4.5, 2.4, 3.2, C('#9a9aa4'), 10, 2)
    return v


def troll():
    v = Cv(32)
    sk = C('#808a68')
    feet(v, 16, 27, mul(sk, .7), 2, 4.6)
    v.ell(16, 19, 11, 7.6, mul(sk, .88), 5, 4)
    for s in (-1, 1):
        v.ell(16 + s * 11.6, 16.5, 4.4, 5.4, sk, 7, 3)
        v.ell(16 + s * 12.6, 9.5, 2.6, 3.2, mul(sk, 1.05), 8, 2)
    v.ell(16, 12.4, 6.2, 5.6, mul(sk, 1.08), 10, 4)
    eyes(v, 16, 10, C('#ffe070'), 2.4, 14)
    for s in (-1, 1):
        v.line(16 + s * 3, 14.6, 16 + s * 3, 12.4, C('#ece8d8'), 13, 1)
    v.rect(12.5, 14.6, 7, 1, C('#0a0806'), 12)
    v.line(27.5, 29, 27.5, 7, C('#5a4630'), 8, 2)
    v.ell(27.5, 5, 3.4, 4, C('#6a5a46'), 10, 3)
    return v


def ogre():
    v = Cv(32)
    sk = C('#b0a08a')
    feet(v, 16, 27, mul(sk, .7), 2, 4.6)
    v.ell(16, 19.5, 12, 8.2, sk, 5, 4)
    v.rect(5, 21, 22, 2, C('#6a5a48'), 8)
    for s in (-1, 1):
        v.ell(16 + s * 12.2, 17, 4.6, 5.4, mul(sk, 1.06), 7, 3)
        v.line(16 + s * 13, 14, 16 + s * 14.4, 6, mul(sk, 1.0), 8, 3)
        v.ell(16 + s * 14.4, 5, 3, 3.2, mul(sk, 1.1), 10, 2)
    v.ell(16, 13.2, 6, 5.2, mul(sk, 1.1), 10, 4)
    eyes(v, 16, 11, C('#704040'), 2.2, 14)
    v.rect(13, 14.6, 6, 1, C('#3a2420'), 12)
    v.ell(16, 13, 1.4, 1.2, mul(sk, .8), 13, 0)
    v.line(29, 22, 29, 5, C('#7a6a56'), 9, 2)
    return v


def harpy():
    v = Cv()
    for s in (-1, 1):
        v.poly([(12 + s * 3, 10), (12 + s * 11.5, 5), (12 + s * 11.2, 9), (12 + s * 9.5, 8.5), (12 + s * 9.2, 13), (12 + s * 7, 12), (12 + s * 6, 16), (12 + s * 3.5, 15)], C('#5a4a5a'), 4)
        for k in range(4):
            v.line(12 + s * 3.5, 11 + k * 0.8, 12 + s * (11 - k * 1.5), 6 + k * 2.6, C('#3a2e40'), 5, 1)
    v.line(10, 17, 10, 21, C('#d0b050'), 2, 1)
    v.line(14, 17, 14, 21, C('#d0b050'), 2, 1)
    v.ell(12, 13.5, 3.8, 5, C('#6a5a50'), 6, 3)
    v.ell(12, 9, 3.5, 3.4, C('#d8d0c8'), 9, 3)
    v.ell(12, 6.8, 2.8, 1.5, C('#3a2a40'), 11, 1)
    eyes(v, 12, 8, C('#ff7088'), 1.5, 13)
    v.put(12, 10.6, C('#d0b050'), 10)
    return v


def lizardman():
    v = Cv()
    sk = C('#5e8a60')
    v.line(12, 18, 16, 22, mul(sk, .8), 3, 3)
    v.line(16, 22, 21, 22.5, mul(sk, .75), 2, 2)
    v.ell(12, 14.5, 4.8, 5, mul(sk, .85), 5, 3)
    v.ell(12, 10.5, 3.6, 4.6, sk, 8, 3)
    v.ell(12, 7, 2.2, 2.6, mul(sk, 1.1), 8, 2)
    for i in range(4):
        v.put(12, 9 + i * 1.3, C('#a85860'), 11)
    eyes(v, 12, 9, C('#ffe040'), 2.4, 12)
    pauldrons(v, 12, 12.5, 2, 2.6, mul(sk, .9), 7, 6)
    v.ell(3, 13, 3.4, 4, C('#7a5a38'), 8, 2)
    v.line(20.5, 22, 20.5, 3, C('#5a4630'), 8, 1)
    v.poly([(19.5, 4), (21.5, 4), (20.5, 0.5)], C('#b0b4c0'), 9)
    return v


def knight_fallen():
    v = Cv()
    ar = C('#6a6a76')
    v.ell(12, 16, 7.4, 6.2, C('#5a1c28'), 3, 1)
    feet(v, 12, 20, C('#2a2630'))
    v.ell(12, 13.5, 7, 4.8, C('#2e2a3a'), 5, 2)
    pauldrons(v, 12, 12.5, 3.4, 3.8, mul(ar, .85), 8, 7.4)
    v.poly([(9, 12), (15, 12), (12, 18.5)], mul(ar, .8), 9)
    v.ell(12, 10.5, 5, 4.9, ar, 10, 3)
    face_void(v, 12, 8.4, 2.9, 1.7, 12)
    eyes(v, 12, 8.4, C('#ff6040'), 1.7, 13)
    sword(v, 21, 2, 14, C('#9a9aa8'), C('#7a5a30'), 8, 2)
    return v


def reaper():
    v = Cv()
    v.ell(12, 14, 7.6, 7, C('#2a2430'), 4, 3)
    v.ell(12, 10.5, 5, 4.9, C('#3a3440'), 9, 3)
    face_void(v, 12, 8.4, 3, 1.8, 12)
    eyes(v, 12, 8.4, C('#c0f0ff'), 1.6, 13)
    v.line(20, 21, 20, 3, C('#4a3a2c'), 8, 1)
    v.poly([(20, 3), (13.5, 2), (9.5, 4.5), (14.5, 4), (20, 5)], C('#e0e4ec'), 10)
    return v


def summoner(cult=False):
    v = Cv()
    robe = C('#604848') if cult else C('#3a2850')
    dk = C('#301818') if cult else C('#2c2234')
    v.ell(12, 16, 7, 6, dk, 3, 1)
    v.ell(12, 13.5, 6.4, 4.4, robe, 5, 2)
    pauldrons(v, 12, 12.5, 2.6, 3, mul(robe, 1.1))
    v.poly([(9, 11), (15, 11), (12, 18.5)], dk, 8)
    v.ell(12, 10.5, 4.6, 4.5, mul(dk, 1.3), 8, 3)
    face_void(v, 12, 8.3, 2.7, 1.6, 11)
    eyes(v, 12, 8.3, C('#ffd060') if cult else C('#ff80d0'), 1.6, 12)
    if cult:
        v.line(20, 14, 20, 9, C('#c0c0c8'), 8, 1)
    else:
        staff(v, 20.5, 20, 4, C('#5a4630'))
        v.ell(20.5, 3.5, 2.6, 2.6, C('#d8d0e0'), 9, 3)
        for a in range(3):
            v.put(5 + a * 2, 4 + (a % 2) * 2, C('#ff80d0'), 11)
    return v


def abomination():
    v = Cv(32)
    fl = C('#8a6e68')
    v.ell(16, 18, 13, 10, fl, 4, 5)
    v.ell(10.5, 12, 6.4, 5.4, mul(fl, 1.12), 8, 3)
    v.ell(21, 11.5, 5.8, 5, mul(fl, .92), 8, 3)
    v.ell(15, 22, 6, 4, mul(fl, .85), 7, 2)
    for i in range(6):
        v.put(9 + i * 2.4, 23 + (i % 2), C('#e8d8c8'), 10)
    v.rect(9, 22, 14, 1, C('#2a1418'), 8)
    eyes(v, 16, 11, C('#ffd070'), 3.2, 13)
    v.put(10, 9, C('#ffd070'), 12)
    for s in (-1, 1):
        v.line(16 + s * 12, 18, 16 + s * 14.5, 26, mul(fl, .9), 5, 3)
        for k in range(3):
            v.put(16 + s * (14 + k), 27, C('#d8d0c0'), 6)
    return v


def frost_mage():
    v = Cv()
    v.ell(12, 16, 7, 6, C('#26344e'), 3, 1)
    v.ell(12, 13.5, 6.4, 4.4, C('#2c3a58'), 5, 2)
    pauldrons(v, 12, 12.5, 2.6, 3, C('#3a4c70'))
    v.ell(12, 10.5, 4.6, 4.5, C('#3a3e50'), 8, 3)
    for i in range(5):
        a = -1.1 + i * 0.55
        v.line(12 + math.sin(a) * 3.4, 10.5 - math.cos(a) * 3.4, 12 + math.sin(a) * 5.4, 10.5 - math.cos(a) * 5.4, C('#c0e8ff'), 11, 1)
    face_void(v, 12, 8.3, 2.7, 1.6, 12)
    eyes(v, 12, 8.3, C('#80e8ff'), 1.6, 13)
    staff(v, 20.5, 21, 5, C('#4a5666'))
    v.poly([(19.2, 5), (21.8, 5), (21, 0.5), (20, 0.5)], C('#b8e0ff'), 10)
    return v


def berserker():
    v = Cv()
    sk = C('#9a7a70')
    feet(v, 12, 20.5, C('#3a2a2a'), 2, 3.4)
    v.ell(12, 14, 8.6, 5.2, C('#7a3a38'), 5, 3)
    pauldrons(v, 12, 12.5, 3.2, 3.6, sk, 7, 8)
    v.ell(12, 9.8, 4.7, 4.3, sk, 9, 3)
    v.ell(12, 8.2, 5, 2.8, C('#2a1c1c'), 12, 1)
    eyes(v, 12, 9.4, C('#ff5030'), 1.8, 13)
    v.rect(10, 11.5, 4, 1, C('#1a0808'), 11)
    for s in (-1, 1):
        v.line(12 + s * 9.5, 13, 12 + s * 10, 5, mul(sk, .95), 7, 2)
        v.line(12 + s * 10, 6.5, 12 + s * 10, 1.5, C('#6a5a46'), 8, 1)
        v.poly([(12 + s * 8.4, 2), (12 + s * 11.6, 2), (12 + s * 11.6, 5), (12 + s * 8.4, 4)], C('#c0c0c8'), 9)
    return v


def plague_doc():
    v = Cv()
    v.ell(12, 16, 7, 6, C('#1e241e'), 3, 1)
    v.ell(12, 13.5, 6.4, 4.4, C('#242a24'), 5, 2)
    pauldrons(v, 12, 12.5, 2.6, 3, C('#3a4a3a'))
    v.ell(12, 10.5, 4.4, 4.3, C('#303030'), 8, 2)
    v.ell(12, 10.2, 7.6, 6.8, C('#1a1a1a'), 11, 2)
    v.poly([(10.4, 8), (13.6, 8), (12, 0.8)], C('#d8d0b8'), 12)
    v.line(12, 8, 12, 2, C('#a8a090'), 13, 1)
    eyes(v, 12, 8.4, C('#7ad0a0'), 2.2, 14)
    staff(v, 20.5, 16, 8, C('#5a4630'))
    v.ell(20.5, 17.5, 2.3, 2.5, C('#4a8a50'), 8, 2)
    v.put(20, 17, C('#80f0a0'), 11)
    return v


def vampire():
    v = Cv(32)
    for s in (-1, 1):
        v.poly([(16 + s * 5, 14), (16 + s * 15, 7), (16 + s * 14, 17), (16 + s * 11, 15), (16 + s * 10, 22), (16 + s * 7, 19), (16 + s * 5, 24)], C('#5a1c28'), 3)
    v.ell(16, 20, 9, 7.6, C('#3a1220'), 3, 3)
    v.ell(16, 18, 9, 5.6, C('#1c1420'), 6, 3)
    pauldrons(v, 16, 14, 3.6, 4, C('#4a2430'), 9, 9)
    v.ell(16, 10.6, 5.2, 4.8, C('#d8d0d4'), 11, 3)
    v.ell(16, 8.4, 5.5, 2.8, C('#1a1018'), 15, 1)
    eyes(v, 16, 10, C('#ff3030'), 2.4, 16)
    v.put(15, 13, C('#f0ece0'), 14)
    v.put(17, 13, C('#f0ece0'), 14)
    sword(v, 28, 3, 20, C('#b0b0bc'), C('#c0a040'), 9, 2)
    return v


def villager(body, cloth, hair, skirt=False, tool=None):
    v = Cv()
    v.ell(12, 16, 6.4 if skirt else 5.6, 5.4, mul(cloth, .8), 3, 1)
    feet(v, 12, 19, C('#2a2020'))
    v.ell(12, 13.5, 6.0, 4.2, cloth, 5, 2)
    v.rect(7, 14, 10, 1, mul(cloth, .6), 6)
    v.ell(5.5, 13.5, 1.8, 2.4, mul(cloth, 1.1), 6, 1)
    v.ell(18.5, 13.5, 1.8, 2.4, mul(cloth, 1.1), 6, 1)
    v.ell(12, 10.3, 4.2, 4.2, hair, 8, 3)
    v.ell(12, 11.2, 3.2, 2.8, body, 9, 2)
    eyes(v, 12, 11.4, C('#201818'), 1.2, 11)
    if tool == 'hammer':
        v.line(20.5, 20, 20.5, 8, C('#5a4030'), 8, 1)
        v.rect(18, 5, 5, 3, C('#707078'), 10)
    elif tool == 'spear':
        v.line(20.5, 21, 20.5, 2, C('#6a5038'), 8, 1)
        v.poly([(20.5, 0.5), (19, 3.5), (22, 3.5)], C('#b0b0ba'), 10)
    elif tool == 'staff':
        v.line(20.5, 21, 20.5, 5, C('#5a4030'), 8, 1)
    return v


def deer():
    v = Cv()
    fur = C('#6a4e38')
    for s in (-1, 1):
        v.ell(12 + s * 4, 9, 1.5, 2.4, mul(fur, .8), 2, 1)
        v.ell(12 + s * 4, 18, 1.6, 2.6, mul(fur, .8), 2, 1)
    v.ell(12, 14, 5, 7.6, fur, 5, 3)
    v.ell(12, 20.6, 1.6, 1.4, C('#d8d0c0'), 4, 1)
    v.ell(12, 7.2, 2.6, 3, mul(fur, 1.1), 7, 2)
    v.ell(12, 4.6, 1.8, 2.2, mul(fur, 1.2), 7, 1)
    for s in (-1, 1):
        v.line(12 + s * 2, 4, 12 + s * 5, 0.5, C('#c8b890'), 9, 1)
        v.line(12 + s * 3.5, 2.2, 12 + s * 6, 3, C('#c8b890'), 9, 1)
    v.put(11, 4, C('#101010'), 9)
    v.put(13, 4, C('#101010'), 9)
    return v


def rabbit():
    v = Cv()
    fur = C('#8a8478')
    v.ell(12, 14, 4.4, 5.2, fur, 4, 3)
    v.ell(12, 19, 1.8, 1.6, C('#e0e0e0'), 5, 1)
    v.ell(12, 9, 2.8, 2.8, mul(fur, 1.1), 6, 2)
    for s in (-1, 1):
        v.ell(12 + s * 1.8, 5.2, 1.0, 3.0, mul(fur, 1.05), 8, 1)
        v.put(12 + s * 1.8, 5.2, C('#c09090'), 9)
    v.put(11, 8.5, C('#101010'), 9)
    v.put(13, 8.5, C('#101010'), 9)
    return v


def crow():
    v = Cv()
    f = C('#22242c')
    for s in (-1, 1):
        v.poly([(12 + s * 2, 11), (12 + s * 10, 13), (12 + s * 8, 18), (12 + s * 2, 16)], mul(f, 1.2), 5)
    v.ell(12, 13.5, 3.2, 5.0, f, 6, 3)
    v.poly([(10.5, 17.5), (13.5, 17.5), (12, 21.5)], mul(f, .9), 4)
    v.ell(12, 8.5, 2.2, 2.2, mul(f, 1.3), 8, 2)
    v.poly([(11, 6.2), (13, 6.2), (12, 4)], C('#8a7a50'), 9)
    v.put(11, 8, C('#d8d8e0'), 10)
    v.put(13, 8, C('#d8d8e0'), 10)
    return v


MAKERS = {
    'hero': hero, 'hunter': hunter, 'necro': necro, 'cleric': cleric,
    'skeleton': lambda: skeleton(False), 'skel_archer': lambda: skeleton(True),
    'ghoul': ghoul, 'zombie': zombie, 'spider': spider, 'gargoyle': gargoyle, 'ooze': ooze, 'bat': bat,
    'cultist': lambda: summoner(True), 'wraith': lambda: reaper_wraith(), 'rat': rat, 'imp': imp, 'wisp': wisp,
    'toad': toad, 'wolf': wolf, 'goblin': lambda: goblin('goblin'), 'goblin_archer': lambda: goblin('archer'),
    'goblin_shaman': lambda: goblin('shaman'), 'kobold': kobold, 'orc': orc, 'troll': troll, 'ogre': ogre,
    'harpy': harpy, 'lizardman': lizardman, 'knight_fallen': knight_fallen, 'reaper': reaper,
    'summoner': lambda: summoner(False), 'abomination': abomination, 'frost_mage': frost_mage,
    'berserker': berserker, 'plague_doc': plague_doc, 'vampire': vampire,
    'villager_a': lambda: villager(C('#d8b090'), C('#6a5a3a'), C('#4a3a28')),
    'villager_b': lambda: villager(C('#e0b898'), C('#7a4a4a'), C('#5a3a24'), True),
    'villager_c': lambda: villager(C('#d0a888'), C('#5a5a64'), C('#c8c8c8'), False, 'staff'),
    'smith': lambda: villager(C('#c89878'), C('#3a3a40'), C('#2a2020'), False, 'hammer'),
    'guard': lambda: villager(C('#d0a888'), C('#6a6a78'), C('#8a8a96'), False, 'spear'),
    'monk': lambda: villager(C('#d8b898'), C('#5a4630'), C('#5a4630'), True, 'staff'),
    'deer': deer, 'rabbit': rabbit, 'crow': crow,
}


def reaper_wraith():
    v = Cv()
    v.ell(12, 15.5, 7.5, 7.4, C('#34445e'), 3, 3)
    for s in (-1, 1):
        v.poly([(12 + s * 4, 14), (12 + s * 9, 20), (12 + s * 5, 22)], C('#2a3850'), 2)
    v.ell(12, 14, 6.2, 5.2, C('#4a5a78'), 5, 3)
    v.ell(12, 10.5, 4.8, 4.7, C('#2a3048'), 8, 3)
    face_void(v, 12, 8.4, 2.8, 1.7, 11)
    eyes(v, 12, 8.4, C('#a0f0ff'), 1.7, 12)
    v.line(20, 21, 20, 3, C('#6a5a4a'), 8, 1)
    v.poly([(20, 3), (14, 2), (10, 5), (15, 4.5), (20, 5.5)], C('#d8dce8'), 10)
    return v


def save(name, v, out):
    n = v.n
    v.outline()
    im = Image.new('RGBA', (n, n), (0, 0, 0, 0))
    hm = Image.new('L', (n, n), 0)
    for y in range(n):
        for x in range(n):
            if v.c[y][x] is not None:
                im.putpixel((x, y), v.c[y][x])
                hm.putpixel((x, y), max(1, min(255, v.h[y][x])))
    im.save(os.path.join(out, name + '.png'))
    hm.save(os.path.join(out, name + '_h.png'))
    return im


if __name__ == '__main__':
    out = sys.argv[1] if len(sys.argv) > 1 else '.'
    os.makedirs(out, exist_ok=True)
    made = []
    for name, fn in MAKERS.items():
        made.append((name, save(name, fn(), out)))
    if '--preview' in sys.argv:
        pf = sys.argv[sys.argv.index('--preview') + 1]
        k = 8
        cols = 9
        rows = (len(made) + cols - 1) // cols
        cell = 34 * k
        pv = Image.new('RGB', (cols * cell, rows * (cell + 14)), (58, 54, 68))
        d = ImageDraw.Draw(pv)
        for i, (n, im) in enumerate(made):
            big = im.resize((im.width * k, im.height * k), Image.NEAREST)
            x = (i % cols) * cell + (cell - big.width) // 2
            y = (i // cols) * (cell + 14) + 14 + (cell - big.height) // 2
            pv.paste(big, (x, y), big)
            d.text(((i % cols) * cell + 4, (i // cols) * (cell + 14)), n, fill=(255, 255, 0))
        pv.save(pf)
    print('ok', len(made))
