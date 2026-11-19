"""Strutture grandi viste dall'alto per variare il mondo (nessuna AI): torre in rovina, cerchio di pietre,
stagno, arco crollato, ceppo gigante, fossa di ossa.   Uso: python landmarks.py <cartella_sprites>"""
import sys, os, math, random
from PIL import Image, ImageDraw

OUT = sys.argv[1] if len(sys.argv) > 1 else "."
_argv = sys.argv
sys.argv = [sys.argv[0], os.path.join(OUT, "_tmp_lm")]
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import topdown as TD  # noqa: E402
sys.argv = _argv
try:
    os.rmdir(os.path.join(OUT, "_tmp_lm"))
except OSError:
    pass
C, new, shadowed, outline, hexc, STONE = TD.C, TD.new, TD.shadowed, TD.outline, TD.hexc, TD.STONE


def lit(c, k):
    return tuple(max(0, min(255, int(v * k))) for v in c[:3]) + (255,)


def ring_tower(seed):
    rnd = random.Random(seed)
    s = 64
    im = new(s, s)
    px = im.load()
    gaps = []
    for _ in range(3):
        a = rnd.uniform(0, 2 * math.pi)
        gaps.append((a, rnd.uniform(0.45, 0.95)))
    cx = cy = s / 2 - 0.5
    for y in range(s):
        for x in range(s):
            dx, dy = x - cx, y - cy
            r = math.hypot(dx, dy)
            th = math.atan2(dy, dx)
            in_gap = any(abs((th - a + math.pi) % (2 * math.pi) - math.pi) < w for a, w in gaps)
            if 22 <= r <= 29 and not in_gap:
                k = 1.0 + 0.35 * (-(dx + dy) / (r + 1)) * (1 if r > 25.5 else -0.6)
                c = lit(STONE[3], k * 0.95)
                if ((x // 5) + (y // 4)) % 3 == 0:
                    c = lit(c, 0.78)
                if rnd.random() < 0.05:
                    c = C('#34523a')
                px[x, y] = c
            elif r < 22:
                c = lit(STONE[1], 0.75 + 0.35 * rnd.random())
                if rnd.random() < 0.05:
                    c = C('#2c4630')
                px[x, y] = c
            elif r < 31 and rnd.random() < (0.30 if in_gap else 0.07):
                px[x, y] = lit(STONE[rnd.randint(1, 3)], 1.0)
    d = ImageDraw.Draw(im)
    for _ in range(6):   # blocchi caduti all'interno
        x, y = rnd.randint(14, 44), rnd.randint(14, 44)
        d.rectangle([x, y, x + rnd.randint(4, 7), y + rnd.randint(3, 5)], fill=lit(STONE[2], 1.1), outline=lit(STONE[0], 1.0))
    d.ellipse([28, 28, 36, 35], fill=(4, 3, 8, 255))     # botola nera al centro
    d.ellipse([29, 29, 35, 34], fill=(0, 0, 0, 255))
    return shadowed(outline(im), 3, 4, 90)


def stone_circle(seed):
    rnd = random.Random(seed)
    s = 80
    im = new(s, s)
    d = ImageDraw.Draw(im)
    d.ellipse([28, 28, 51, 51], fill=lit(STONE[1], 1.0))
    d.ellipse([30, 30, 49, 49], fill=lit(STONE[2], 1.0))
    d.ellipse([33, 33, 46, 46], outline=C('#7a46c0'))                    # incisioni rituali
    for k in range(8):
        a = k * math.pi / 4
        d.point((int(39.5 + math.cos(a) * 9), int(39.5 + math.sin(a) * 9)), fill=C('#b890ff'))
    d.rectangle([38, 38, 40, 40], fill=C('#d8c0ff'))
    n = 9
    for k in range(n):                                                    # menhir in cerchio
        a = k * 2 * math.pi / n + 0.2
        cx, cy = 40 + math.cos(a) * 31, 40 + math.sin(a) * 31
        w, h = rnd.randint(8, 10), rnd.randint(10, 13)
        pts = [(cx - w / 2, cy - h / 2 + 2), (cx + w / 2 - 2, cy - h / 2), (cx + w / 2, cy + h / 2 - 2), (cx - w / 2 + 2, cy + h / 2)]
        d.polygon(pts, fill=lit(STONE[2], 1.0))
        d.polygon([pts[0], pts[1], (cx, cy)], fill=lit(STONE[3], 1.05))
        d.polygon([pts[2], pts[3], (cx, cy)], fill=lit(STONE[0], 1.1))
        for q in range(3):
            d.point((int(cx - 1 + q), int(cy - 1)), fill=C('#9a70e0') if rnd.random() < 0.7 else lit(STONE[3], 1.0))
    st = shadowed(outline(im), 3, 4, 85)
    # terra battuta sotto, senza contorno
    full = new(st.width, st.height)
    dd = ImageDraw.Draw(full)
    dd.ellipse([2, 2, s - 3, s - 3], fill=(24, 18, 14, 140))
    dd.ellipse([8, 8, s - 9, s - 9], fill=(30, 23, 18, 120))
    for _ in range(22):
        x, y = rnd.randint(8, 70), rnd.randint(8, 70)
        if math.hypot(x - 40, y - 40) > 14:
            dd.point((x, y), fill=C('#34523a'))
    full.alpha_composite(st)
    return full


def pond(variant, seed):
    rnd = random.Random(seed)
    W, H = 64, 48
    im = new(W, H)
    px = im.load()
    pal = {0: dict(w=['#08141e', '#0f2a3a', '#1c4a5e'], m=['#241c16', '#382c22'], r='#2a4a32'),
           1: dict(w=['#0b1a14', '#16382b', '#27573f'], m=['#2a2418', '#3a3322'], r='#3c5a2a')}[variant]
    a1, a2 = rnd.uniform(0, 6), rnd.uniform(0, 6)
    cx, cy = W / 2 - 0.5, H / 2 - 0.5
    for y in range(H):
        for x in range(W):
            dx, dy = (x - cx) / (W / 2), (y - cy) / (H / 2)
            r = math.hypot(dx, dy)
            th = math.atan2(dy, dx)
            lim = 0.97 + 0.07 * math.sin(3 * th + a1) + 0.05 * math.sin(5 * th + a2)
            if r > lim:
                continue
            if r > lim - 0.17:
                c = hexc(pal['m'][(x + y + int(rnd.random() * 2)) % 2]) + (255,)
                if rnd.random() < 0.08:
                    c = C(pal['r'])
                px[x, y] = c
            else:
                t = r / (lim - 0.17)
                c = hexc(pal['w'][0 if t < 0.5 else 1]) + (255,)
                if t > 0.85:
                    c = hexc(pal['w'][2]) + (255,)
                px[x, y] = c
    d = ImageDraw.Draw(im)
    for _ in range(5):     # riflessi
        x, y = rnd.randint(18, 44), rnd.randint(14, 32)
        d.line([x, y, x + rnd.randint(3, 6), y], fill=hexc(pal['w'][2]) + (255,))
    for _ in range(4):     # ninfee
        x, y = rnd.randint(18, 46), rnd.randint(15, 33)
        d.ellipse([x, y, x + 5, y + 3], fill=C('#2c5a30'))
        d.point((x + 2, y + 1), fill=C('#e8e0d0'))
    for _ in range(14):    # canne sulla riva
        ang = rnd.uniform(0, 2 * math.pi)
        x, y = int(cx + math.cos(ang) * 29), int(cy + math.sin(ang) * 21)
        d.line([x, y, x + rnd.randint(-1, 1), y - rnd.randint(3, 6)], fill=C(pal['r']))
    return shadowed(outline(im), 3, 4, 70)


def broken_arch(seed):
    rnd = random.Random(seed)
    im = new(52, 34)
    d = ImageDraw.Draw(im)
    sd = [C('#6a5e4c'), C('#8a7c66'), C('#b0a088'), C('#3e362c')]     # pietra chiara calda: si stacca dal pavimento
    d.rectangle([2, 10, 14, 27], fill=sd[1])                           # pilastro sinistro
    d.rectangle([2, 10, 14, 13], fill=sd[2]); d.rectangle([2, 24, 14, 27], fill=sd[3])
    d.rectangle([5, 14, 6, 23], fill=sd[0]); d.rectangle([10, 14, 11, 23], fill=sd[0])
    d.rectangle([37, 16, 49, 27], fill=sd[1])                          # pilastro destro spezzato
    d.rectangle([37, 16, 49, 18], fill=sd[2]); d.rectangle([37, 24, 49, 27], fill=sd[3])
    d.polygon([(37, 16), (41, 12), (45, 16)], fill=sd[2])
    d.polygon([(17, 6), (31, 3), (33, 11), (18, 14)], fill=sd[1])      # architrave caduto in due pezzi
    d.polygon([(17, 6), (31, 3), (30, 6), (17, 9)], fill=sd[2])
    d.polygon([(30, 18), (42, 20), (41, 27), (28, 25)], fill=sd[1])
    d.polygon([(30, 18), (42, 20), (41, 22), (30, 20)], fill=sd[2])
    d.line([(26, 5), (25, 12)], fill=sd[3])
    for _ in range(18):
        d.point((rnd.randint(16, 38), rnd.randint(18, 31)), fill=sd[rnd.randint(0, 2)])
    for _ in range(10):
        d.point((rnd.randint(2, 49), rnd.randint(10, 28)), fill=C('#4a6a3a'))
    return shadowed(outline(im), 3, 4, 95)


def giant_stump(seed):
    rnd = random.Random(seed)
    s = 56
    im = new(s, s)
    d = ImageDraw.Draw(im)
    cx = cy = s / 2
    wood_d, wood_m, wood_l = C('#2a1c12'), C('#4a3422'), C('#6e5238')
    for k in range(9):      # radici
        a = k * 2 * math.pi / 9 + rnd.uniform(-0.2, 0.2)
        x1, y1 = cx + math.cos(a) * 26, cy + math.sin(a) * 26
        xs, ys = cx + math.cos(a) * 12, cy + math.sin(a) * 12
        d.line([xs, ys, x1, y1], fill=wood_m, width=4)
        d.line([xs, ys, x1, y1], fill=wood_d, width=1)
    d.ellipse([cx - 19, cy - 19, cx + 19, cy + 19], fill=wood_d)         # corteccia
    d.ellipse([cx - 16, cy - 16, cx + 16, cy + 16], fill=wood_m)         # taglio
    for rr in (13, 10, 7, 4):                                             # anelli di crescita
        d.ellipse([cx - rr, cy - rr, cx + rr, cy + rr], outline=wood_l if rr % 2 else wood_d)
    d.ellipse([cx - 2, cy - 2, cx + 2, cy + 2], fill=wood_d)
    d.arc([cx - 16, cy - 16, cx + 16, cy + 16], 200, 290, fill=C('#9a7a52'))
    for _ in range(3):   # funghi a mensola
        a = rnd.uniform(0, 2 * math.pi)
        x, y = cx + math.cos(a) * 18, cy + math.sin(a) * 18
        d.ellipse([x - 2, y - 2, x + 2, y + 2], fill=C('#a83a30') if rnd.random() < 0.5 else C('#7a4aa8'))
    for _ in range(14):
        x, y = rnd.randint(8, 48), rnd.randint(8, 48)
        if 15 < math.hypot(x - cx, y - cy) < 24:
            d.point((x, y), fill=C('#34523a'))
    return shadowed(outline(im), 3, 4, 85)


def bone_pit(seed):
    rnd = random.Random(seed)
    s = 52
    im = new(s, s)
    d = ImageDraw.Draw(im)
    cx = cy = s / 2
    d.ellipse([cx - 24, cy - 24, cx + 24, cy + 24], fill=C('#2a2018'))          # terra rimossa
    for _ in range(30):
        a, r = rnd.uniform(0, 2 * math.pi), rnd.uniform(15, 23)
        x, y = cx + math.cos(a) * r, cy + math.sin(a) * r
        d.ellipse([x - 1, y - 1, x + 1, y + 1], fill=lit(STONE[rnd.randint(1, 3)], 1.0))
    d.ellipse([cx - 15, cy - 15, cx + 15, cy + 15], fill=C('#0c080c'))          # fossa
    d.ellipse([cx - 13, cy - 13, cx + 13, cy + 13], fill=C('#16101a'))
    bone, shade = C('#d6cdaa'), C('#8c846a')
    for _ in range(9):   # ossa
        x, y = cx + rnd.uniform(-9, 9), cy + rnd.uniform(-9, 9)
        a = rnd.uniform(0, math.pi)
        d.line([x, y, x + math.cos(a) * 6, y + math.sin(a) * 6], fill=bone)
        d.point((int(x), int(y)), fill=shade)
    for _ in range(4):   # teschi
        x, y = cx + rnd.uniform(-8, 8), cy + rnd.uniform(-8, 8)
        d.ellipse([x - 3, y - 3, x + 3, y + 2], fill=bone)
        d.point((int(x) - 1, int(y)), fill=C('#0a0610'))
        d.point((int(x) + 1, int(y)), fill=C('#0a0610'))
    for k in range(10):  # pali di legno acuminati attorno
        a = k * 2 * math.pi / 10 + 0.15
        x, y = cx + math.cos(a) * 21, cy + math.sin(a) * 21
        d.line([x, y, x + math.cos(a) * 3, y + math.sin(a) * 3 - 3], fill=C('#5a4028'), width=2)
        d.point((int(x + math.cos(a) * 3), int(y + math.sin(a) * 3 - 4)), fill=C('#9a7a52'))
    return shadowed(outline(im), 3, 4, 85)


def main():
    os.makedirs(OUT, exist_ok=True)
    jobs = []
    for i in range(3):
        jobs.append(("ruin_tower_%d" % i, ring_tower(11 + i * 5)))
    for i in range(2):
        jobs.append(("circle_top_%d" % i, stone_circle(31 + i * 7)))
    for i in range(3):
        jobs.append(("pond_top_%d" % i, pond(0, 51 + i * 3)))
    for i in range(3):
        jobs.append(("pond_swa_%d" % i, pond(1, 71 + i * 3)))
    for i in range(2):
        jobs.append(("arch_top_%d" % i, broken_arch(91 + i * 4)))
    for i in range(3):
        jobs.append(("stump_big_%d" % i, giant_stump(111 + i * 6)))
    for i in range(2):
        jobs.append(("bone_pit_%d" % i, bone_pit(131 + i * 6)))
    for name, im in jobs:
        im.save(os.path.join(OUT, name + ".png"))
    return jobs


if __name__ == "__main__":
    main()
