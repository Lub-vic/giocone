"""Nemici fantasy classici nello stesso stile degli altri (render "B" di gen_sprites + grade di gothic.py, nessuna AI).

Uso: python fantasy_enemies.py <cartella_sprites> [--preview file.png]
Scrive: goblin, goblin_archer, goblin_shaman, kobold, orc, troll, ogre, harpy, lizardman (.png)
"""
import os, sys

OUT = sys.argv[1] if len(sys.argv) > 1 else "."
PREV = sys.argv[sys.argv.index("--preview") + 1] if "--preview" in sys.argv else None
here = os.path.dirname(os.path.abspath(__file__))
src = open(os.path.join(here, "gothic.py"), encoding="utf-8").read()
src = src[:src.rindex("\nmain()")]
tmp = os.path.join(os.environ.get("TEMP", "."), "gothic_tmp")
os.makedirs(tmp, exist_ok=True)
sys.argv = [sys.argv[0], tmp]
ns = {"__file__": os.path.join(here, "gothic.py"), "__name__": "gothic_lib"}
exec(compile(src, "gothic.py", "exec"), ns)
G, S, grade = ns["G"], ns["S"], ns["grade"]


def goblin():  # piccolo, verde, orecchie a punta, coltellaccio arrugginito
    g = G()
    g.r(7, 18, 2, 1, 'c'); g.r(11, 18, 2, 1, 'c')                    # piedi nudi
    g.r(8, 15, 2, 3, 'c'); g.r(11, 15, 2, 3, 'c')                    # gambe magre
    g.r(7, 14, 7, 2, 'l'); g.p(7, 16, 'l'); g.p(10, 16, 'l'); g.p(13, 16, 'l')   # perizoma sfrangiato
    g.r(7, 10, 7, 4, 'k'); g.r(9, 10, 3, 4, 'd'); g.r(7, 13, 7, 1, 'b'); g.p(10, 13, 'y')   # gilet, cintura
    g.r(5, 10, 2, 4, 'c'); g.r(14, 10, 2, 4, 'c'); g.p(5, 14, 'c'); g.p(15, 14, 'c')        # braccia, mani
    g.e(10, 6.5, 3.6, 3.2, 'c'); g.r(8, 4, 5, 1, 'n')                 # testa grossa, fronte
    g.l(6, 6, 2, 3, 'c'); g.l(6, 7, 3, 4, 'c'); g.p(4, 4, 'n'); g.p(5, 5, 'n')     # orecchie a punta
    g.l(14, 6, 18, 3, 'c'); g.l(14, 7, 17, 4, 'c'); g.p(16, 4, 'n'); g.p(15, 5, 'n')
    g.r(8, 6, 2, 1, 'e'); g.r(11, 6, 2, 1, 'e'); g.p(8, 6, 'g'); g.p(12, 6, 'g')    # occhi gialli
    g.p(10, 7, 'n'); g.r(8, 9, 5, 1, 'e'); g.p(9, 9, 'w'); g.p(12, 9, 'w')          # naso, ghigno
    g.l(16, 10, 17, 15, 'm'); g.p(17, 11, 'r'); g.p(15, 14, 'h')                     # coltello
    return g, dict(c='#6a8240', n='#46602a', k='#5a3c22', d='#3e2816', l='#4a3a2a', b='#2a1c12', y='#c8a040',
                   e='#140c08', g='#f0c030', w='#e0d8b0', m='#a0a6b4', r='#7a3a20', h='#3a2a1a')


def goblin_archer():  # goblin incappucciato con arco corto e faretra
    g, pal = goblin()
    g.e(10, 5.5, 4.2, 3.0, 'u'); g.r(6, 6, 9, 1, 'u'); g.p(6, 7, 'u'); g.p(14, 7, 'u')   # cappuccio
    g.r(8, 6, 2, 1, 'e'); g.r(11, 6, 2, 1, 'e'); g.p(8, 6, 'g'); g.p(12, 6, 'g')
    for y in range(4, 16):
        g.p(3 if y in (4, 5, 14, 15) else 2, y, 'a')                     # arco
    g.l(3, 4, 3, 15, 'f')
    g.r(14, 9, 2, 4, 'q'); g.p(14, 8, 'f'); g.p(15, 8, 'r')              # faretra con frecce
    pal.update(u='#3c4a2c', a='#7a5430', f='#d0c8a8', q='#5a3a22')
    return g, pal


def goblin_shaman():  # maschera d'osso, piume, bastone con teschio, tunica
    g, pal = goblin()
    g.r(7, 10, 7, 6, 'v'); g.p(7, 16, 'v'); g.p(9, 17, 'v'); g.p(11, 16, 'v'); g.p(13, 17, 'v')   # tunica lacera
    g.r(7, 12, 7, 1, 'b'); g.p(9, 12, 'w'); g.p(11, 12, 'w')                                     # collana di denti
    g.r(7, 5, 7, 4, 'o'); g.r(8, 6, 2, 1, 'e'); g.r(11, 6, 2, 1, 'e'); g.p(8, 6, 'z'); g.p(12, 6, 'z')   # maschera
    g.r(9, 8, 3, 1, 'e'); g.p(10, 7, 'e')
    g.p(6, 2, 'r'); g.p(8, 1, 'y'); g.p(10, 1, 'r'); g.p(12, 1, 'y'); g.p(14, 2, 'r'); g.r(7, 3, 7, 1, 'r')  # piume
    g.r(17, 4, 1, 14, 'h'); g.e(17.5, 3.5, 1.8, 1.8, 'o'); g.p(17, 3, 'e'); g.p(18, 3, 'e')                 # bastone
    g.p(16, 6, 'z'); g.p(18, 6, 'z')                                                                        # fumo magico
    pal.update(r='#a03020', y='#c8a030', v='#4a2a4a', o='#d8ccaa', z='#70e0b0')
    return g, pal


def kobold():  # piccolo, muso da rettile-cane, lancia, coda
    g = G()
    g.l(12, 16, 17, 18, 'c'); g.p(17, 17, 'n')                       # coda
    g.r(8, 17, 2, 2, 'c'); g.r(11, 17, 2, 2, 'c'); g.p(7, 18, 'h'); g.p(13, 18, 'h')   # zampe con artigli
    g.e(10, 14, 3.0, 3.4, 'c'); g.r(9, 13, 3, 3, 'k')                # ventre chiaro
    g.r(8, 12, 5, 1, 'l'); g.p(8, 13, 'l'); g.p(12, 13, 'l')         # straccio a tracolla
    g.e(10, 8, 3.0, 2.8, 'c'); g.r(9, 10, 3, 2, 'c'); g.r(9, 11, 3, 1, 'e')   # testa e muso
    g.p(7, 5, 'h'); g.p(6, 4, 'h'); g.p(13, 5, 'h'); g.p(14, 4, 'h')  # cornetti
    g.p(8, 8, 'g'); g.p(12, 8, 'g'); g.p(9, 10, 'n'); g.p(11, 10, 'n')
    g.l(3, 7, 13, 17, 'w'); g.p(3, 6, 'm'); g.p(2, 6, 'm'); g.p(3, 5, 'm'); g.p(2, 5, 'm')   # lancia
    g.p(5, 12, 'c'); g.p(13, 13, 'c')
    return g, dict(c='#8a4a2a', n='#5a2e18', k='#c89a6a', l='#4a3a2a', e='#1a0a06', h='#e0d0a8', g='#f0c040',
                   w='#6a4a2a', m='#b0b4c0')


def orc():  # robusto, zanne, spallaccio di ferro, ascia
    g = G(22)
    g.r(7, 20, 3, 1, 'b'); g.r(12, 20, 3, 1, 'b')                    # stivali
    g.r(8, 17, 2, 3, 'p'); g.r(12, 17, 2, 3, 'p')                    # brache
    g.r(6, 10, 10, 7, 'k'); g.r(9, 10, 4, 7, 'd')                    # corazza di cuoio borchiata
    g.p(7, 12, 'm'); g.p(14, 12, 'm'); g.p(7, 15, 'm'); g.p(14, 15, 'm')
    g.r(6, 16, 10, 1, 'b'); g.p(11, 16, 'y')                         # cintura
    g.e(4.5, 12.5, 2.2, 3.0, 'c'); g.e(17.5, 12.5, 2.2, 3.0, 'c')    # braccia grosse
    g.r(3, 15, 3, 2, 'c'); g.r(16, 15, 3, 2, 'c')                    # pugni
    g.e(4.5, 10, 2.8, 1.8, 'm'); g.p(3, 10, 'w'); g.p(5, 9, 'w')     # spallaccio con spuntoni
    g.e(11, 6.5, 4.0, 3.4, 'c'); g.r(7, 4, 8, 2, 'n')                # testa e fronte bassa
    g.r(7, 3, 8, 1, 'h')                                             # cresta di capelli
    g.r(8, 6, 2, 1, 'e'); g.r(12, 6, 2, 1, 'e'); g.p(9, 6, 'g'); g.p(13, 6, 'g')
    g.r(10, 7, 2, 1, 'n'); g.r(8, 9, 6, 1, 'e'); g.p(8, 8, 'w'); g.p(13, 8, 'w')   # naso, zanne
    g.p(14, 5, 'x'); g.p(15, 6, 'x')                                  # cicatrice
    g.r(19, 4, 1, 14, 'h'); g.e(20, 5.5, 1.6, 2.8, 'm'); g.p(21, 4, 'w')          # ascia
    return g, dict(c='#56703e', n='#3a502a', k='#5a4430', d='#4a3424', p='#3a3428', b='#20160e', y='#c8a040',
                   m='#8a8e9e', w='#d0d4dc', e='#120a08', g='#e8c030', h='#2a1c12', x='#8a3a2a')


def troll():  # enorme, curvo, pelle muschiosa, braccia lunghe, clava
    g = G(26)
    g.r(8, 24, 4, 1, 'k'); g.r(15, 24, 4, 1, 'k')                    # piedi larghi
    g.r(9, 20, 3, 4, 'c'); g.r(15, 20, 3, 4, 'c')                    # gambe tozze
    g.e(13, 15, 7.0, 6.5, 'c')                                       # corpo massiccio curvo
    g.e(13, 12, 5.5, 3.2, 'n'); g.p(10, 11, 'v'); g.p(15, 12, 'v'); g.p(13, 10, 'v')   # gobba di muschio
    g.r(9, 18, 9, 2, 'l'); g.p(9, 20, 'l'); g.p(12, 20, 'l'); g.p(16, 20, 'l')        # pelle di bestia
    g.e(4, 15, 2.4, 5.5, 'c'); g.e(22, 15, 2.4, 5.5, 'c')            # braccia lunghe
    g.r(2, 19, 4, 2, 'k'); g.r(20, 19, 4, 2, 'k'); g.p(2, 21, 'w'); g.p(5, 21, 'w')   # mani con unghie
    g.e(13, 7, 3.8, 3.4, 'c'); g.r(12, 8, 3, 3, 'k'); g.p(13, 10, 'n')             # testa, naso a patata
    g.r(10, 5, 2, 1, 'e'); g.r(15, 5, 2, 1, 'e'); g.p(11, 5, 'g'); g.p(15, 5, 'g')
    g.r(10, 11, 7, 1, 'e'); g.p(11, 11, 'w'); g.p(15, 11, 'w')
    g.r(10, 3, 6, 1, 'v'); g.p(9, 4, 'v'); g.p(16, 4, 'v')                          # capelli come erba
    g.l(23, 5, 24, 20, 'h'); g.e(23.5, 5, 2.2, 2.6, 'h'); g.p(22, 4, 'w'); g.p(25, 6, 'w')   # clava con chiodi
    return g, dict(c='#6a7a62', n='#3e5a34', v='#5a7a3a', k='#8a9a7a', l='#5a4632', e='#141210', g='#d8d040',
                   w='#c8c0a0', h='#4a3420')


def ogre():  # grasso, pelle chiara, pancione, clava enorme
    g = G(28)
    g.r(8, 27, 5, 1, 'h'); g.r(15, 27, 5, 1, 'h')                    # piedi
    g.r(9, 23, 3, 4, 'c'); g.r(16, 23, 3, 4, 'c')
    g.e(14, 16, 8.5, 7.5, 'c')                                       # pancia
    g.e(14, 17, 4.5, 3.0, 'k'); g.p(14, 17, 'n')                     # ombelico
    g.r(7, 21, 14, 2, 'l'); g.p(8, 23, 'l'); g.p(12, 23, 'l'); g.p(17, 23, 'l'); g.p(20, 23, 'l')   # perizoma
    g.r(7, 20, 14, 1, 'b'); g.p(14, 20, 'm')                         # corda
    g.e(4, 13, 2.8, 4.5, 'c'); g.e(24, 13, 2.8, 4.5, 'c')            # braccia
    g.r(2, 17, 4, 2, 'n'); g.r(22, 17, 4, 2, 'n')                    # mani
    g.e(14, 7, 4.0, 3.6, 'c'); g.r(10, 4, 8, 1, 'h')                 # testa piccola, capelli radi
    g.r(11, 6, 2, 1, 'e'); g.r(16, 6, 2, 1, 'e'); g.p(12, 6, 'g'); g.p(16, 6, 'g')
    g.r(13, 7, 2, 2, 'n'); g.r(11, 10, 7, 1, 'e'); g.p(12, 9, 'w'); g.p(17, 9, 'w')   # naso, dentoni
    g.p(9, 7, 'n'); g.p(19, 7, 'n')                                  # orecchie
    g.l(1, 3, 3, 18, 'u'); g.e(2, 3.5, 2.6, 3.2, 'u'); g.p(0, 2, 'm'); g.p(4, 3, 'm'); g.p(2, 0, 'm')   # clava chiodata
    return g, dict(c='#b0906a', k='#c8a882', n='#8a6a4a', l='#5a4028', b='#3a2a1a', m='#b0b4c0', e='#1a1008',
                   w='#e8e0c0', g='#d03020', h='#3a2a1a', u='#6a4a2a')


def harpy():  # donna-uccello: ali spiegate a strati di piume, artigli
    g = G()
    for k in range(4):
        col = 'f' if k % 2 == 0 else 'd'
        g.l(1, 5 + k * 2, 7, 10 + k, col); g.l(19, 5 + k * 2, 13, 10 + k, col)
    g.p(0, 6, 'd'); g.p(20, 6, 'd'); g.p(1, 12, 'd'); g.p(19, 12, 'd')
    g.e(10, 13, 2.8, 4, 'f'); g.r(9, 10, 3, 2, 's'); g.p(10, 12, 'd')  # petto piumato
    g.r(8, 16, 2, 2, 'y'); g.r(11, 16, 2, 2, 'y'); g.p(7, 18, 'y'); g.p(13, 18, 'y'); g.p(9, 18, 'y'); g.p(11, 18, 'y')   # artigli
    g.e(10, 7, 2.6, 2.8, 's')                                        # viso
    g.r(7, 4, 6, 2, 'h'); g.r(7, 6, 1, 5, 'h'); g.r(13, 6, 1, 5, 'h'); g.p(6, 9, 'h'); g.p(14, 9, 'h')   # capelli arruffati
    g.p(9, 7, 'g'); g.p(11, 7, 'g'); g.r(9, 9, 3, 1, 'e'); g.p(10, 9, 'w')
    return g, dict(f='#6a4a3a', d='#3a2a22', s='#c8b0a0', h='#2a1a1a', g='#e04040', e='#3a1010', w='#e8e0d0', y='#c8a040')


def lizardman():  # squame verdi, cresta, lancia e scudo di guscio, coda
    g = G()
    g.l(13, 15, 18, 18, 'c'); g.p(18, 19, 'n')                       # coda
    g.r(7, 18, 3, 1, 'n'); g.r(11, 18, 3, 1, 'n')                    # zampe
    g.r(8, 15, 2, 3, 'c'); g.r(11, 15, 2, 3, 'c')
    g.e(10, 12.5, 3.4, 4.0, 'c'); g.r(9, 11, 3, 5, 'k')              # ventre chiaro a bande
    g.p(9, 12, 'c'); g.p(11, 14, 'c')
    g.r(7, 14, 7, 1, 'l')                                            # gonnellino di cuoio
    g.e(10, 6.5, 3.0, 3.0, 'c'); g.r(9, 8, 3, 2, 'c'); g.r(9, 9, 3, 1, 'e')   # testa e muso
    g.r(9, 2, 3, 2, 'r'); g.p(10, 1, 'r'); g.p(10, 4, 'r')           # cresta
    g.p(8, 6, 'g'); g.p(12, 6, 'g'); g.p(8, 7, 'n'); g.p(12, 7, 'n')
    g.p(7, 9, 'n'); g.p(13, 9, 'n')                                  # squame scure
    g.l(16, 2, 16, 18, 'w'); g.p(16, 1, 'm'); g.p(15, 2, 'm'); g.p(17, 2, 'm'); g.p(16, 0, 'm')   # lancia
    g.e(4.5, 12, 2.4, 3.2, 'b'); g.e(4.5, 12, 1.2, 1.8, 'u'); g.p(4, 12, 'm')                     # scudo di guscio
    return g, dict(c='#4a7a4a', n='#2e5030', k='#a8b880', l='#5a4030', e='#0a1408', g='#f0d030', r='#b04030',
                   w='#6a4a2a', m='#b0b4c0', b='#6a4a2e', u='#8a6a3e')


ENEMIES = [("goblin", goblin), ("goblin_archer", goblin_archer), ("goblin_shaman", goblin_shaman), ("kobold", kobold),
           ("orc", orc), ("troll", troll), ("ogre", ogre), ("harpy", harpy), ("lizardman", lizardman)]

os.makedirs(OUT, exist_ok=True)
made = []
for name, fn in ENEMIES:
    g, pal = fn()
    im = grade(S.render(g, pal, "B"), 0.62, 0.86)
    im.save(os.path.join(OUT, name + ".png"))
    made.append(im)
if PREV:
    from PIL import Image
    cell = 30 * 6
    pv = Image.new("RGBA", (cell * len(made), cell), (40, 36, 48, 255))
    for i, im in enumerate(made):
        big = im.resize((im.width * 6, im.height * 6), Image.NEAREST)
        pv.alpha_composite(big, (i * cell + (cell - big.width) // 2, (cell - big.height) // 2))
    pv.save(PREV)
print("ok", len(made))
