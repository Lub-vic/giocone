"""Invecchiamento comune a tutti gli oggetti di scena: colori spenti, crepe, muschio, bordi sbeccati."""
import colorsys, random, zlib


def weather(im, name, sat=0.58, val=0.82, amount=1.0):
    if name.startswith(("relic_", "mat_", "res_", "w_", "page", "coin", "heart", "soul", "flask")) or "glow" in name or "lamp" in name or "campfire" in name or "crystal" in name or "menhir" in name:
        sat, val, amount = 0.85, 0.92, 0.0
    rnd = random.Random(zlib.crc32(name.encode()))
    px = im.load()
    w, h = im.size
    solid = [[px[x, y][3] > 0 for x in range(w)] for y in range(h)]
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            hh, ss, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            if v > 0.82 and ss > 0.55:
                continue
            ss *= sat
            v *= val
            edge = False
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if not (0 <= nx < w and 0 <= ny < h) or not solid[ny][nx]:
                    edge = True
            t = rnd.random() * (1.0 if amount > 0 else 9.0)
            if amount > 0 and v > 0.18:
                if not edge and t < 0.045 * amount:      # crepe e sporco
                    v *= 0.55
                elif not edge and t < 0.075 * amount and hh < 0.30:   # muschio
                    hh, ss, v = 0.27, 0.35, v * 0.9
                elif not edge and t < 0.09 * amount:     # macchia di umidita'
                    v *= 0.72
                    ss *= 0.8
                elif edge and t < 0.07 * amount and w > 14:   # bordo sbeccato
                    px[x, y] = (0, 0, 0, 0)
                    continue
            r2, g2, b2 = colorsys.hsv_to_rgb(hh, min(ss, 1.0), min(v, 1.0))
            px[x, y] = (int(r2 * 255), int(g2 * 255), int(b2 * 255), a)
    return im
