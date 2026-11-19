"""Sprite e tile in stile GOTICO per il progetto Godot 4.

Uso: python gothic.py <cartella_assets>
Stile: sprite con contorno selettivo (B), terreni piatti (A), palette gotica:
nero-viola, cremisi sangue, osso, oro annerito, verde malsano, blu lunare.
Scrive:  <out>/sprites/<nome>.png   (uno per sprite, dimensione nativa)
         <out>/tiles/tiles.png      (atlante 16x16, una riga per terreno, 4 varianti)
         <out>/preview.png          (anteprima ingrandita)
"""
import sys, os, random
from PIL import Image, ImageDraw

OUT = sys.argv[1] if len(sys.argv) > 1 else "."
sys.argv = [sys.argv[0], os.path.join(OUT, "_tmp")]  # gen_sprites crea una cartella: la ripuliamo dopo
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_sprites as S
try:
    os.rmdir(sys.argv[1])
except OSError:
    pass

G, hexc = S.G, S.hexc
T = 16


# ------------------------------------------------------------------ personaggi
def hero():  # cavaliere in armatura nera, cappa lacera, elmo alto, spadone
    g = G()
    g.e(10, 15.5, 5, 4.5, 'c')                   # cappa lunga
    g.r(7, 17, 1, 2, 'c'); g.r(12, 17, 1, 2, 'c'); g.p(9, 19, 'c')   # lembi strappati
    g.e(10, 12.5, 3.6, 4.2, 'a')                 # corazza stretta
    g.e(5.5, 10.5, 2.0, 2.2, 'a'); g.e(14.5, 10.5, 2.0, 2.2, 'a')    # spallacci a punta
    g.p(5, 8, 'a'); g.p(15, 8, 'a')
    g.r(8, 13, 4, 1, 'y')
    g.e(10, 7.5, 3.0, 3.6, 'h')                  # elmo alto e stretto
    g.r(8, 8, 4, 1, 'e'); g.p(9, 8, 'g'); g.p(11, 8, 'g')
    g.r(9, 2, 2, 2, 'e'); g.p(10, 1, 'e')        # cresta spenta
    g.r(17, 2, 1, 16, 'm'); g.r(15, 12, 5, 1, 'y'); g.p(17, 18, 'y'); g.p(17, 19, 'y')
    return g, dict(c='#4a0e18', a='#2a2838', h='#34324a', e='#07040b', g='#d0481e', m='#9aa0b4', y='#7a5c20')



def necro():  # negromante: lunga tunica nera, cappuccio profondo, bastone con teschio
    g = G()
    g.e(10, 15, 4.6, 5, 'c')
    g.r(6, 17, 1, 3, 'c'); g.r(13, 17, 1, 3, 'c'); g.r(9, 18, 2, 2, 'c')
    g.r(16, 4, 1, 15, 'w')
    g.e(16.5, 3.5, 2.2, 2.2, 's'); g.p(16, 3, 'e'); g.p(17, 3, 'e'); g.p(16, 5, 's')
    g.e(10, 8.5, 4.2, 5, 'h')
    g.e(10, 8.5, 2.4, 3.0, 'e'); g.p(9, 8, 'g'); g.p(11, 8, 'g')
    g.p(14, 11, 'f'); g.p(14, 12, 'f')
    return g, dict(c='#22123a', h='#1a0e2c', e='#050309', g='#5acc7a', w='#44301f', s='#b8b29c', f='#9a8e76')



def hunter():  # cacciatore: cappello a tese larghe, maschera a becco, lungo cappotto
    g = G()
    g.e(10, 14, 4.2, 5.5, 'c')
    g.r(2, 9, 2, 9, 'w'); g.r(2, 9, 6, 1, 'w'); g.p(1, 9, 'm'); g.p(8, 9, 'm'); g.r(5, 10, 1, 7, 'm')
    g.e(10, 8, 6.4, 3.2, 'h')                    # tese larghe, basse
    g.e(10, 7.5, 2.6, 2.4, 'k')
    g.r(9, 9, 2, 4, 'b'); g.p(10, 13, 'b')       # becco lungo
    g.p(8, 8, 'g'); g.p(12, 8, 'g')
    g.r(16, 7, 2, 5, 'w')
    return g, dict(c='#2a2a32', h='#1c1824', k='#0e0b12', b='#a8a088', g='#d0782a', w='#4a3420', m='#7a8090')



def cultist():  # adepto: lunga veste, cappuccio a punta, volto nell'ombra
    g = G()
    g.e(10, 14.5, 4.4, 5.2, 'c')
    g.r(6, 17, 1, 3, 'c'); g.r(13, 17, 1, 3, 'c')
    g.e(10, 8.5, 3.6, 4.6, 'h')
    g.r(9, 1, 2, 4, 'h'); g.p(10, 0, 'h')
    g.e(10, 9, 2.0, 2.8, 'e'); g.p(9, 8, 'g'); g.p(11, 8, 'g')
    g.r(16, 10, 1, 6, 'm'); g.r(15, 14, 3, 1, 'y')
    g.r(8, 14, 4, 1, 'y')
    return g, dict(c='#4a0c18', h='#600f1e', e='#070306', g='#d8a830', m='#9aa0b4', y='#8a6420')



def skeleton():
    g = G()
    g.r(17, 8, 1, 9, 'm'); g.r(16, 9, 3, 1, 'w'); g.r(16, 16, 3, 1, 'w')
    g.e(10, 13.5, 3.4, 4.6, 's')                 # gabbia toracica stretta
    g.r(8, 12, 4, 1, 'e'); g.r(8, 14, 4, 1, 'e'); g.r(10, 10, 1, 9, 'a')
    g.r(5, 10, 1, 8, 's'); g.r(14, 10, 1, 8, 's')
    g.e(10, 7.5, 3.0, 3.2, 's')
    g.r(8, 7, 2, 2, 'e'); g.r(11, 7, 2, 2, 'e'); g.p(9, 7, 'g'); g.p(12, 7, 'g'); g.r(9, 10, 3, 1, 'a')
    return g, dict(s='#b0a88e', a='#76705c', e='#0a0610', g='#d02a20', m='#555566', w='#3a2c20')



def ghoul():  # ghoul: smunto, curvo, artigli lunghi
    g = G()
    g.e(10, 14, 3.8, 5.5, 'c')
    g.r(3, 9, 2, 5, 'k'); g.r(15, 9, 2, 5, 'k'); g.p(3, 14, 'k'); g.p(5, 14, 'k'); g.p(15, 14, 'k'); g.p(17, 14, 'k')
    g.e(10, 8, 3.2, 3.4, 'c')
    g.r(8, 7, 1, 2, 'g'); g.r(12, 7, 1, 2, 'g'); g.r(8, 10, 5, 1, 'e'); g.p(9, 10, 'k'); g.p(11, 10, 'k')
    g.r(8, 14, 5, 1, 'e')
    return g, dict(c='#667064', k='#a8ae9c', e='#120d14', g='#d0b030')



def bat():
    g = G()
    g.e(4, 10, 4, 3, 'c'); g.e(16, 10, 4, 3, 'c')
    g.e(4, 10, 2.2, 1.5, 'h'); g.e(16, 10, 2.2, 1.5, 'h')
    g.p(1, 8, 'c'); g.p(18, 8, 'c'); g.p(0, 11, 'c'); g.p(19, 11, 'c')
    g.e(10, 11, 2.5, 4, 'c'); g.e(10, 7.5, 2.6, 2.6, 'c')
    g.p(8, 4, 'c'); g.p(12, 4, 'c'); g.p(8, 3, 'c'); g.p(12, 3, 'c')
    g.p(9, 7, 'g'); g.p(11, 7, 'g'); g.p(9, 9, 's'); g.p(11, 9, 's')
    return g, dict(c='#4a2c64', h='#2a1840', g='#ff2a3a', s='#ffffff')


def wraith():  # spettro con falce
    g = G()
    g.l(16, 2, 16, 19, 'w'); g.e(13.5, 3.5, 3.5, 1.8, 'm'); g.p(11, 5, 'm'); g.p(10, 6, 'm')
    g.e(10, 11, 6, 8, 'c')
    g.r(4, 15, 2, 4, 'c'); g.r(8, 17, 2, 3, 'c'); g.r(12, 16, 2, 4, 'c')
    g.e(10, 8, 4.6, 4.6, 'h')
    g.e(10, 9, 2.8, 2.5, 'e'); g.p(9, 9, 'g'); g.p(11, 9, 'g')
    return g, dict(c='#46628a', h='#26365a', e='#04060c', g='#8affff', m='#cfd8e8', w='#4a3a2a')


def gargoyle():  # gargoyle di pietra: ali a membrana, muso aguzzo
    g = G()
    g.l(1, 3, 6, 13, 'd'); g.l(18, 3, 13, 13, 'd'); g.l(0, 8, 6, 13, 'd'); g.l(19, 8, 13, 13, 'd')
    g.e(3.5, 9, 2.6, 4.5, 'w'); g.e(16.5, 9, 2.6, 4.5, 'w')
    g.e(10, 13, 3.8, 5, 'c')
    g.e(10, 7.5, 2.8, 3.2, 'c')
    g.p(7, 3, 'c'); g.p(7, 2, 'c'); g.p(13, 3, 'c'); g.p(13, 2, 'c')
    g.p(8, 7, 'g'); g.p(12, 7, 'g'); g.r(9, 9, 3, 2, 'd'); g.p(9, 11, 'f'); g.p(11, 11, 'f')
    g.r(7, 17, 2, 3, 'c'); g.r(12, 17, 2, 3, 'c')
    return g, dict(c='#5a5a68', w='#40404f', d='#1c1c28', g='#e0501e', f='#c8c4b0')



def spider():  # ragno cripta
    g = G()
    for yy, a in ((5, 1), (8, 0), (12, 0), (15, 1)):
        g.l(8, 10, 1 if a else 0, yy, 'l'); g.l(12, 10, 18 if a else 19, yy, 'l')
    g.e(10, 12.5, 4, 4.4, 'c'); g.e(10, 7.5, 2.6, 2.4, 'c')
    g.p(9, 13, 'r'); g.p(10, 14, 'r'); g.p(11, 13, 'r'); g.p(10, 12, 'r')   # clessidra
    g.p(9, 7, 'g'); g.p(11, 7, 'g'); g.p(10, 6, 'g')
    return g, dict(c='#2a2234', l='#46385a', r='#d8202e', g='#ff4a4a')


def ooze():  # melma di sangue coagulato con frammenti d'osso
    g = G()
    g.e(10, 13, 8, 5, 'c'); g.e(8, 10, 4.5, 3.5, 'c'); g.e(13, 11, 3, 2.5, 'c')
    g.e(7, 9, 1.8, 1.1, 'h'); g.p(14, 15, 'h')
    g.l(5, 12, 7, 14, 's'); g.l(13, 10, 15, 12, 's'); g.p(10, 15, 's'); g.p(11, 15, 's')
    g.p(9, 11, 'g'); g.p(12, 12, 'g')
    return g, dict(c='#5a0e18', h='#a02a34', s='#c8c0a8', g='#ff3030')



def vampire():  # Signore della Cripta (boss, 28x28)
    g = G(28)
    g.e(14, 21, 12, 7, 'c')                      # cappa ampia
    g.e(14, 18, 8, 6, 'k')
    g.e(5, 14, 3.5, 3.5, 'c'); g.e(23, 14, 3.5, 3.5, 'c')
    g.r(2, 14, 3, 6, 'c'); g.r(23, 14, 3, 6, 'c')
    g.r(6, 8, 3, 5, 'c'); g.r(19, 8, 3, 5, 'c')      # colletto alto
    g.e(14, 11, 5, 5.2, 's')
    g.r(9, 5, 10, 2, 'h')                        # capelli
    g.p(12, 11, 'g'); g.p(16, 11, 'g'); g.p(11, 11, 'g'); g.p(17, 11, 'g')
    g.p(12, 14, 'w'); g.p(16, 14, 'w'); g.r(13, 14, 3, 1, 'e')
    g.p(14, 17, 'y'); g.r(12, 18, 5, 1, 'y')
    g.r(24, 6, 1, 14, 'm'); g.r(22, 10, 5, 1, 'y')
    return g, dict(c='#7a0f20', k='#2a0a16', s='#8a8498', h='#0a0610', g='#e02020', w='#ffffff', e='#4a0a14',
                   y='#c8902a', m='#cdd2e4')


def zombie():
    g = G()
    g.e(10, 14, 3.8, 5.4, 'c')
    g.r(4, 7, 2, 6, 's'); g.r(14, 7, 2, 6, 's'); g.r(3, 7, 2, 1, 's'); g.r(15, 7, 2, 1, 's')
    g.e(10, 8, 3.2, 3.4, 's'); g.p(8, 7, 'e'); g.p(8, 8, 'e'); g.p(12, 8, 'e'); g.r(8, 10, 4, 1, 'm')
    g.r(7, 14, 6, 1, 'r'); g.p(6, 13, 'r'); g.r(8, 17, 1, 3, 'c'); g.r(12, 17, 1, 3, 'c')
    return g, dict(c='#4a5448', s='#68785c', e='#120a10', m='#2a1010', r='#3a2c20')



def skel_archer():
    g = G()
    g.l(3, 4, 1, 10, 'w'); g.l(1, 10, 3, 16, 'w'); g.l(3, 4, 3, 16, 'm')
    g.e(10, 13.5, 3.4, 4.6, 's'); g.r(8, 12, 4, 1, 'e'); g.r(8, 14, 4, 1, 'e'); g.r(10, 10, 1, 9, 'a')
    g.r(5, 10, 1, 8, 's'); g.r(14, 10, 1, 8, 's')
    g.e(10, 7.5, 3.0, 3.2, 's'); g.r(8, 7, 2, 2, 'e'); g.r(11, 7, 2, 2, 'e'); g.p(9, 7, 'g'); g.p(12, 7, 'g')
    return g, dict(s='#b0a88e', a='#76705c', e='#0a0610', g='#d08a20', m='#555566', w='#3a2a18')



def rat():
    g = G(14)
    g.e(6, 8, 4.5, 3, 'c'); g.e(10.5, 7, 2.5, 2, 'c'); g.p(11, 6, 'e'); g.p(13, 7, 'n'); g.p(9, 4, 'c'); g.p(11, 4, 'c')
    g.l(1, 9, 0, 12, 't'); g.l(0, 12, 3, 13, 't')
    return g, dict(c='#6a5a52', e='#ff3030', n='#d08a8a', t='#a07a7a')


def imp():  # diavolo scarno, ali a membrana, coda uncinata
    g = G()
    g.l(2, 3, 7, 12, 'w'); g.l(17, 3, 12, 12, 'w'); g.l(0, 8, 6, 13, 'w'); g.l(19, 8, 13, 13, 'w')
    g.e(10, 13, 3.2, 5, 'c'); g.e(10, 7.5, 2.8, 3, 'c')
    g.p(7, 3, 'h'); g.p(7, 2, 'h'); g.p(13, 3, 'h'); g.p(13, 2, 'h')
    g.p(8, 7, 'g'); g.p(12, 7, 'g'); g.r(9, 9, 3, 1, 'e')
    g.l(10, 17, 13, 19, 'c'); g.p(14, 18, 'f'); g.p(14, 19, 'f')
    return g, dict(c='#7a2418', w='#42121a', h='#1c0a0a', g='#e8c040', e='#1c0606', f='#b89040')



def wisp():  # fuoco fatuo: volto cavo, coda di nebbia
    g = G()
    g.e(10, 8, 4, 5, 'c'); g.e(10, 8, 2.4, 3.2, 'h'); g.e(10, 14, 3, 4.5, 'c'); g.e(10, 18, 1.4, 2, 'c')
    g.r(8, 7, 1, 3, 'e'); g.r(12, 7, 1, 3, 'e'); g.r(9, 11, 3, 1, 'e')
    return g, dict(c='#3a7aa8', h='#a8d8f0', e='#06101e')



def toad():  # rospo mostruoso, pelle ulcerata, occhi rossi
    g = G()
    g.e(10, 12.5, 7, 4.6, 'c'); g.e(6, 7.5, 1.9, 1.9, 'c'); g.e(14, 7.5, 1.9, 1.9, 'c')
    g.p(6, 7, 'e'); g.p(14, 7, 'e'); g.r(5, 12, 10, 1, 'm'); g.p(7, 13, 'f'); g.p(12, 13, 'f')
    g.l(2, 16, 4, 18, 'c'); g.l(18, 16, 16, 18, 'c')
    g.p(10, 10, 'w'); g.p(8, 14, 'w'); g.p(13, 13, 'w'); g.p(11, 15, 'w')
    return g, dict(c='#3a4a2c', e='#d8301c', m='#120a08', w='#6a7a3a', f='#c8c0a0')



def wolf():
    g = G()
    g.e(9, 11.5, 6.5, 3.8, 'c'); g.e(16, 9.5, 3, 2.6, 'c'); g.p(17, 7, 'c'); g.p(15, 7, 'c')
    g.p(18, 10, 'e'); g.p(17, 9, 'g'); g.l(3, 10, 0, 7, 'c')
    g.r(5, 14, 1, 3, 'c'); g.r(8, 14, 1, 3, 'c'); g.r(11, 14, 1, 3, 'c'); g.r(14, 13, 1, 3, 'c')
    return g, dict(c='#5a5a68', e='#1a1a22', g='#ff4a2a')


def crow():
    g = G()
    g.e(3.5, 9, 3.6, 2.4, 'c'); g.e(16.5, 9, 3.6, 2.4, 'c'); g.e(10, 10, 2.6, 4.2, 'c'); g.e(10, 6, 2, 2, 'c')
    g.p(10, 3, 'b'); g.p(9, 6, 'g'); g.p(11, 6, 'g'); g.l(9, 14, 8, 17, 'c'); g.l(11, 14, 12, 17, 'c')
    return g, dict(c='#1c1a24', b='#c8a040', g='#ff4040')


def knight_fallen():
    g = G()
    g.e(4.5, 13, 2.6, 4.2, 's'); g.p(4, 12, 'a')
    g.e(10, 15.5, 5, 4.5, 'r'); g.r(7, 18, 1, 2, 'r'); g.r(12, 18, 1, 2, 'r')
    g.e(10, 12.5, 3.6, 4.2, 'c')
    g.e(5.5, 10.5, 2.0, 2.2, 'c'); g.e(14.5, 10.5, 2.0, 2.2, 'c')
    g.e(10, 7.5, 3.0, 3.6, 'h'); g.r(8, 8, 4, 1, 'e'); g.p(9, 8, 'g'); g.p(11, 8, 'g')
    g.r(9, 2, 2, 2, 'e')
    g.r(17, 1, 2, 17, 'm'); g.r(15, 11, 6, 1, 'a')
    return g, dict(c='#22222e', h='#2c2c3a', e='#05030a', g='#d02020', r='#3a0a12', m='#7a8094', a='#6a5020', s='#2c2c3a')



def reaper():
    g = G()
    g.l(16, 1, 16, 19, 'w'); g.e(13, 3.5, 4, 2.2, 'm'); g.p(9, 4, 'm'); g.p(10, 5, 'm')
    g.e(10, 12, 6.5, 8, 'c'); g.r(4, 16, 2, 4, 'c'); g.r(8, 18, 2, 2, 'c'); g.r(13, 17, 2, 3, 'c')
    g.e(10, 8, 4.6, 4.6, 'h'); g.e(10, 9, 2.8, 2.5, 'e'); g.p(9, 9, 'g'); g.p(11, 9, 'g')
    return g, dict(c='#1c1a26', h='#101018', e='#020204', g='#7affd0', m='#cfd8e8', w='#4a3a2a')


def summoner():
    g = G()
    g.r(16, 4, 1, 15, 'w'); g.e(16.5, 4, 2, 1.8, 's')
    g.e(10, 15, 4.4, 5, 'c'); g.r(6, 17, 1, 3, 'c'); g.r(13, 17, 1, 3, 'c')
    g.e(10, 8.5, 3.8, 4.6, 'h'); g.e(10, 9, 2.0, 2.8, 'e'); g.p(9, 8, 'g'); g.p(11, 8, 'g')
    g.e(3, 6, 1.4, 1.4, 's'); g.e(18, 16, 1.3, 1.3, 's'); g.p(3, 6, 'e'); g.p(18, 16, 'e')
    return g, dict(c='#3a1040', h='#2a0a30', e='#05020a', g='#c040c0', w='#44301f', s='#b8b29c', a='#8a6420')



def abomination():
    g = G(24)
    g.e(12, 15, 10, 7.5, 'c')
    for ax, ay in ((2, 9), (21, 9), (3, 17), (20, 17)):
        g.e(ax, ay, 2.5, 4, 'k')
    g.e(12, 10, 7, 6, 'c'); g.e(12, 8, 4.5, 4, 'h')
    for ex, ey in ((9, 7), (15, 7), (12, 10)):
        g.p(ex, ey, 'e'); g.p(ex + 1, ey, 'e')
    g.r(8, 13, 8, 1, 'm')
    for tx in (9, 11, 13):
        g.p(tx, 14, 'w')
    g.e(7, 18, 2, 2, 'h'); g.e(17, 19, 2, 2, 'h')
    return g, dict(c='#5a444c', k='#42303a', h='#7a6068', e='#d8b030', m='#2a0a10', w='#e8e0d0')


def frost_mage():
    g = G()
    g.r(16, 4, 1, 15, 'w'); g.e(16.5, 3.5, 1.8, 2.8, 'i'); g.p(16, 2, 'j')
    g.e(10, 15, 4.4, 5, 'c'); g.r(6, 17, 1, 3, 'c'); g.r(13, 17, 1, 3, 'c')
    g.e(10, 8.5, 3.8, 4.6, 'h'); g.e(10, 9, 2.0, 2.8, 'e'); g.p(9, 8, 'g'); g.p(11, 8, 'g')
    for x in (7, 9, 11, 13):
        g.p(x, 3, 'i')
    return g, dict(c='#1c3260', h='#142450', e='#03060f', g='#80c8d8', w='#44342a', i='#98c0d8', j='#d8e8f0')



def berserker():
    g = G()
    g.l(2, 4, 4, 15, 'w'); g.e(2.5, 5, 2.2, 2, 'm'); g.l(18, 4, 16, 15, 'w'); g.e(17.5, 5, 2.2, 2, 'm')
    g.e(10, 13, 4.4, 5, 's'); g.r(4, 10, 2, 6, 's'); g.r(14, 10, 2, 6, 's')
    g.r(7, 15, 6, 2, 'b'); g.r(7, 17, 2, 3, 'b'); g.r(11, 17, 2, 3, 'b')
    g.e(10, 8, 3.2, 3.5, 'h'); g.p(7, 5, 'x'); g.p(6, 4, 'x'); g.p(13, 5, 'x'); g.p(14, 4, 'x')
    g.p(8, 8, 'g'); g.p(12, 8, 'g'); g.r(8, 10, 4, 1, 'e')
    return g, dict(s='#8a3a2c', h='#4a2a20', b='#1c1210', g='#e8c030', e='#1c0808', x='#b8b098', w='#44301a', m='#8a90a0')



def plague_doc():
    g = G()
    g.e(17, 14, 2, 2.4, 'v'); g.p(17, 11, 'k')
    g.e(10, 15, 4.2, 5, 'c'); g.r(6, 17, 1, 3, 'c'); g.r(13, 17, 1, 3, 'c')
    g.e(10, 8, 5.4, 2.6, 'h'); g.e(10, 8.5, 2.6, 2.6, 'e')
    g.r(9, 9, 2, 6, 'b'); g.p(10, 15, 'b'); g.p(8, 8, 'g'); g.p(12, 8, 'g')
    return g, dict(c='#16141a', h='#0c0c10', e='#030308', g='#60c070', b='#a8a088', a='#4a3420', v='#48c048', k='#6a5030')



def cleric():
    g = G()
    g.e(10, 15.5, 5, 4.5, 'c'); g.r(6, 18, 1, 2, 'c'); g.r(13, 18, 1, 2, 'c')
    g.e(10, 12.5, 3.8, 4.4, 'w')
    g.e(5.5, 10.5, 2.0, 2.2, 'w'); g.e(14.5, 10.5, 2.0, 2.2, 'w')
    g.r(9, 11, 2, 4, 'y'); g.r(8, 12, 4, 1, 'y')
    g.e(10, 7.5, 3.0, 3.4, 'h'); g.e(10, 8, 1.8, 2.0, 'e'); g.p(9, 8, 'g'); g.p(11, 8, 'g')
    g.r(17, 4, 1, 14, 'n'); g.r(15, 3, 5, 4, 'm'); g.r(15, 3, 5, 1, 'y')
    return g, dict(c='#5a1220', w='#a8a4b8', y='#9a7420', h='#8a869c', e='#0a0610', g='#c8a850', n='#4a3420', m='#6a6a7c')



def deer():  # cervo: corpo allungato, corna ramificate
    g = G()
    g.e(9, 12, 6.2, 3.3, 'c')
    g.e(15.5, 8.5, 2.3, 2.3, 'c')
    g.p(17, 9, 'n'); g.p(16, 8, 'e')
    g.l(15, 6, 14, 3, 'a'); g.l(16, 6, 18, 3, 'a'); g.p(13, 2, 'a'); g.p(19, 2, 'a'); g.p(14, 4, 'a'); g.p(18, 4, 'a')
    g.r(5, 14, 1, 4, 'd'); g.r(8, 14, 1, 4, 'd'); g.r(11, 14, 1, 4, 'd'); g.r(13, 13, 1, 5, 'd')
    g.p(3, 11, 'w'); g.r(8, 13, 4, 1, 'w')
    return g, dict(c='#7a5a3a', d='#5a4028', a='#cfc0a0', n='#2a1a10', e='#0a0610', w='#d8d0c0')


def rabbit():  # coniglio
    g = G(14)
    g.e(6, 9, 4, 3, 'c'); g.e(10.5, 7, 2.3, 2.1, 'c')
    g.r(10, 2, 1, 4, 'c'); g.r(12, 2, 1, 4, 'c')
    g.p(12, 7, 'e'); g.p(2, 9, 'w'); g.r(4, 11, 2, 1, 'c'); g.r(8, 11, 2, 1, 'c')
    return g, dict(c='#8a7a68', e='#0a0610', w='#e0d8c8')


def villager_a():  # contadino: cappello di paglia, tunica consunta
    g = G()
    g.e(10, 15, 4.2, 5, 'c'); g.r(7, 17, 1, 3, 'c'); g.r(12, 17, 1, 3, 'c')
    g.r(3, 10, 2, 6, 'c'); g.r(15, 10, 2, 6, 'c')
    g.e(10, 8, 3.2, 3.4, 's')
    g.e(10, 5.3, 5.2, 1.7, 'h'); g.r(8, 3, 4, 2, 'h')
    g.p(9, 8, 'e'); g.p(11, 8, 'e')
    return g, dict(c='#5a4430', s='#d0a07a', h='#b8a060', e='#0a0610')


def villager_b():  # donna con scialle e cappuccio
    g = G()
    g.e(10, 15, 4.6, 5, 'c'); g.r(6, 17, 1, 3, 'c'); g.r(13, 17, 1, 3, 'c')
    g.e(10, 12, 4.8, 2.2, 'w')
    g.e(10, 8, 3.6, 4.0, 'h'); g.e(10, 8.7, 2.0, 2.4, 's')
    g.p(9, 8, 'e'); g.p(11, 8, 'e')
    return g, dict(c='#4a3a58', h='#8a7a98', s='#d0a07a', w='#a89888', e='#0a0610')


def villager_c():  # anziano con bastone e barba
    g = G()
    g.e(10, 15, 4.2, 5, 'c'); g.r(7, 17, 1, 3, 'c'); g.r(12, 17, 1, 3, 'c')
    g.r(16, 5, 1, 14, 'n')
    g.e(10, 8, 3.4, 3.6, 's'); g.e(10, 5.5, 3.6, 2.0, 'h')
    g.e(10, 11, 2.4, 2.2, 'w')
    g.p(9, 8, 'e'); g.p(11, 8, 'e')
    return g, dict(c='#58606a', s='#d0a07a', h='#8a8a96', w='#d8d8e0', n='#5a3a1a', e='#0a0610')


def guard():  # guardia del villaggio: elmo, tabarro, lancia
    g = G()
    g.e(10, 15, 4.4, 5, 'c'); g.r(7, 17, 1, 3, 'k'); g.r(12, 17, 1, 3, 'k')
    g.e(10, 12, 4.2, 3.2, 'a')
    g.e(10, 7.5, 3.3, 3.5, 'h'); g.r(8, 8, 4, 1, 'k'); g.p(9, 8, 'e'); g.p(11, 8, 'e')
    g.r(16, 2, 1, 17, 'n'); g.p(16, 1, 'm'); g.p(16, 0, 'm')
    return g, dict(c='#3a4a68', k='#2a2a34', a='#6a6e82', h='#7a7e92', e='#ffd070', n='#5a3a1a', m='#cfd6e6')


def smith():  # fabbro: grembiule, braccia nude, calvo e barbuto, martello
    g = G()
    g.e(10, 15, 4.6, 5, 'a'); g.r(6, 17, 1, 3, 'k'); g.r(13, 17, 1, 3, 'k')
    g.e(10, 13, 3.8, 4.4, 'g')
    g.r(3, 10, 3, 6, 's'); g.r(14, 10, 3, 6, 's')
    g.e(10, 8, 3.3, 3.5, 's'); g.e(10, 10.3, 2.2, 1.5, 'b')
    g.p(9, 7, 'e'); g.p(11, 7, 'e')
    g.r(17, 6, 1, 9, 'n'); g.r(15, 4, 4, 3, 'm')
    return g, dict(a='#4a3a32', g='#2a2018', s='#c89874', b='#3a2418', n='#5a3a1a', m='#7a7a8a', k='#2a2a34', e='#0a0610')


def monk():  # monaco: saio, tonsura, croce di legno
    g = G()
    g.e(10, 15, 4.6, 5.2, 'c'); g.r(6, 18, 1, 2, 'c'); g.r(13, 18, 1, 2, 'c')
    g.e(10, 8, 3.3, 3.5, 's'); g.e(10, 6.4, 3.4, 2.2, 'h'); g.e(10, 6.4, 1.8, 1.2, 's')
    g.p(9, 8, 'e'); g.p(11, 8, 'e')
    g.r(9, 12, 2, 6, 'w')
    g.r(16, 8, 1, 9, 'n'); g.r(15, 10, 3, 1, 'n')
    return g, dict(c='#4a3a2a', s='#d0a07a', h='#3a2a1a', w='#c8b078', n='#5a3a1a', e='#0a0610')


CHARS = [("hero", hero), ("necro", necro), ("hunter", hunter), ("cultist", cultist), ("skeleton", skeleton),
         ("ghoul", ghoul), ("bat", bat), ("wraith", wraith), ("gargoyle", gargoyle), ("spider", spider),
         ("ooze", ooze), ("vampire", vampire),
         ("zombie", zombie), ("skel_archer", skel_archer), ("rat", rat), ("imp", imp), ("wisp", wisp), ("toad", toad),
         ("wolf", wolf), ("crow", crow), ("knight_fallen", knight_fallen), ("reaper", reaper), ("summoner", summoner),
         ("abomination", abomination), ("frost_mage", frost_mage), ("berserker", berserker), ("plague_doc", plague_doc),
         ("cleric", cleric), ("deer", deer), ("rabbit", rabbit), ("villager_a", villager_a), ("villager_b", villager_b), ("villager_c", villager_c), ("guard", guard), ("smith", smith), ("monk", monk)]


# ------------------------------------------------------------------ oggetti
def gravestone():  # lapide con croce
    g = G()
    g.e(10, 16.5, 7, 2.5, 'd'); g.r(5, 5, 10, 12, 'm'); g.e(10, 6, 5, 3, 'm')
    g.r(10, 4, 1, 8, 'e'); g.r(8, 6, 5, 1, 'e'); g.r(5, 15, 10, 2, 'v'); g.p(6, 14, 'v')
    return g, dict(d='#3a2a30', m='#8a8ea0', e='#3a3e50', v='#3a5a3a')


def tomb():  # sarcofago
    g = G()
    g.r(2, 3, 16, 15, 'm'); g.r(4, 5, 12, 11, 'n'); g.r(9, 6, 2, 9, 'e'); g.r(7, 8, 6, 2, 'e')
    g.p(2, 3, 'e'); g.p(17, 3, 'e'); g.p(2, 17, 'e'); g.p(17, 17, 'e')
    return g, dict(m='#6a6a82', n='#54546a', e='#2a2a3a')


def candelabra():  # candelabro (la fiamma e la luce le aggiunge Godot)
    g = G()
    g.e(10, 17, 5, 2, 'i'); g.r(9, 8, 2, 9, 'i'); g.r(4, 7, 12, 1, 'i'); g.r(4, 5, 1, 3, 'i'); g.r(15, 5, 1, 3, 'i')
    g.r(9, 5, 2, 3, 'i'); g.r(4, 3, 1, 2, 'w'); g.r(15, 3, 1, 2, 'w'); g.r(9, 3, 2, 2, 'w')
    g.p(4, 2, 'f'); g.p(15, 2, 'f'); g.p(9, 2, 'f'); g.p(10, 2, 'f')
    return g, dict(i='#3a3040', w='#e8dcb8', f='#ffd060')


def coffin():  # bara in legno nero
    g = G()
    g.r(7, 1, 6, 3, 'w'); g.r(5, 3, 10, 4, 'w'); g.r(4, 6, 12, 8, 'w'); g.r(5, 13, 10, 4, 'w'); g.r(7, 16, 6, 3, 'w')
    g.r(9, 5, 2, 9, 'a'); g.r(7, 7, 6, 2, 'a')
    return g, dict(w='#4a3226', a='#a8802a')


def deadtree():
    g = G()
    for a, b in ((3, 3), (17, 4), (16, 17), (4, 16), (10, 1), (18, 11)):
        g.l(10, 10, a, b, 'w')
    g.l(6, 6, 6, 2, 'w'); g.l(13, 7, 18, 7, 'w'); g.l(13, 13, 11, 18, 'w'); g.l(7, 13, 1, 14, 'w')
    g.e(10, 10, 2.8, 2.8, 'a')
    return g, dict(w='#4a3a4a', a='#2e222e')


def skullpile():
    g = G()
    g.e(10, 14, 8, 4.5, 'b')
    for cx, cy in ((6, 11), (13, 11), (10, 8)):
        g.e(cx, cy, 3.2, 3, 's'); g.p(cx - 1, cy, 'e'); g.p(cx + 1, cy, 'e'); g.p(cx, cy + 1, 'e')
    g.r(4, 15, 4, 1, 's'); g.r(12, 16, 4, 1, 's'); g.p(3, 14, 's'); g.p(16, 14, 's')
    return g, dict(b='#4a4254', s='#d8d0b4', e='#0e0a14')


def chest():  # forziere ferrato
    g = G()
    g.r(3, 5, 14, 11, 'w'); g.r(3, 5, 14, 4, 'h'); g.r(3, 8, 14, 1, 'm'); g.r(3, 12, 14, 1, 'm')
    g.r(9, 5, 2, 11, 'm'); g.r(9, 9, 2, 2, 'a')
    return g, dict(w='#4a2e22', h='#6a4430', m='#5a5a6c', a='#d8a02a')


def barrel():
    g = G()
    g.e(10, 10, 7, 7, 'w'); g.e(10, 10, 5.2, 5.2, 'a'); g.e(10, 10, 3.6, 3.6, 'w'); g.l(10, 3, 10, 16, 'e')
    return g, dict(w='#5a3a2a', a='#4a4a5c', e='#2a1a14')


def altar():  # altare insanguinato
    g = G()
    g.r(2, 4, 16, 13, 'm'); g.r(4, 6, 12, 9, 'n'); g.r(6, 7, 8, 5, 'r'); g.r(8, 8, 4, 2, 'R')
    g.p(5, 5, 'e'); g.p(14, 5, 'e')
    return g, dict(m='#6a6a82', n='#4a4a60', r='#8a1424', R='#d82a3a', e='#2a2a3a')


def brazier():  # braciere (la luce la aggiunge Godot)
    g = G()
    g.e(10, 12, 7, 6, 'i'); g.e(10, 12, 5, 4.5, 'e'); g.e(10, 12, 3.5, 3, 'f'); g.e(10, 12, 1.8, 1.5, 'g')
    g.p(4, 17, 'i'); g.p(15, 17, 'i')
    return g, dict(i='#3a3040', e='#2a0e08', f='#ff6a20', g='#ffe080')


def statue():  # statua d'angelo piangente
    g = G()
    g.r(4, 14, 12, 4, 'd')
    g.e(3.5, 9, 3, 5, 'w'); g.e(16.5, 9, 3, 5, 'w')
    g.e(10, 11.5, 4, 5, 'm'); g.e(10, 6.5, 3, 3, 'm')
    g.p(9, 6, 'e'); g.p(11, 6, 'e'); g.p(9, 7, 'e')
    g.r(8, 10, 4, 1, 'e')
    return g, dict(d='#4a4a5c', w='#6a6a82', m='#9a9ab0', e='#3a3a4c')


def pillar():  # colonna vista dall'alto
    g = G()
    g.e(10, 10, 7.5, 7.5, 'd'); g.e(10, 10, 6, 6, 'm'); g.e(10, 10, 3.6, 3.6, 'n'); g.e(10, 10, 1.6, 1.6, 'd')
    return g, dict(d='#3a3448', m='#6a6482', n='#544e6c')


def cobweb():
    g = G()
    g.l(0, 0, 14, 14, 'w'); g.l(0, 0, 14, 4, 'w'); g.l(0, 0, 4, 14, 'w')
    for r_ in (4, 8, 12):
        g.l(r_, 0, 0, r_, 'w'); g.l(r_ + 1, 1 + r_ // 3, 1 + r_ // 3, r_ + 1, 'w')
    return g, dict(w='#c8c8d8')


def torch():  # torcia a muro (sostegno non acceso)
    g = G()
    g.r(9, 8, 2, 8, 'w'); g.r(7, 7, 6, 2, 'i'); g.r(8, 15, 4, 2, 'i'); g.r(7, 5, 6, 3, 'b')
    return g, dict(w='#4a3226', i='#3a3040', b='#2a1a14')


def coin():
    g = G(8)
    g.e(4, 4, 3, 3, 'c'); g.p(3, 3, 'h'); g.p(4, 5, 'e')
    return g, dict(c='#e0a82a', h='#fff0a0', e='#8a5a10')


def heart():
    g = G(10)
    g.e(3, 3.5, 2.4, 2.4, 'c'); g.e(7, 3.5, 2.4, 2.4, 'c'); g.r(1, 4, 8, 2, 'c'); g.r(2, 6, 6, 1, 'c'); g.r(3, 7, 4, 1, 'c')
    g.r(4, 8, 2, 1, 'c'); g.p(2, 2, 'h')
    return g, dict(c='#c8202e', h='#ff8a90')


def soul():  # gemma d'anima (xp)
    g = G(10)
    g.r(4, 1, 2, 2, 'c'); g.r(3, 3, 4, 3, 'c'); g.r(4, 6, 2, 2, 'c'); g.p(4, 3, 'h'); g.p(4, 2, 'h')
    return g, dict(c='#5af0b0', h='#e8fff4')


def bonfire():  # falo': anello di pietre, cenere, spada conficcata (fiamma e luce da Godot)
    g = G()
    g.e(10, 12, 8, 6, 'm'); g.e(10, 12, 6.2, 4.6, 'a'); g.e(10, 12, 4, 3, 'k')
    g.r(10, 2, 1, 12, 's'); g.r(8, 5, 5, 1, 'y'); g.p(10, 1, 's')
    return g, dict(m='#5a5670', a='#2a2634', k='#16121c', s='#cdd2e4', y='#a8802a')


def flask():  # fiala d'ambra
    g = G(10)
    g.r(4, 0, 2, 1, 'k'); g.r(4, 1, 2, 2, 'g'); g.e(5, 6, 3.4, 3.2, 'c'); g.r(3, 5, 5, 2, 'h'); g.p(3, 5, 'w')
    return g, dict(k='#6a4a2a', g='#9aa0b0', c='#e08a1a', h='#ffc860', w='#fff0c0')


def portal():  # varco gotico visto dall'alto: cornice di pietra, soglia scura con bagliore
    g = G()
    g.r(1, 4, 18, 13, 'm'); g.r(1, 4, 18, 2, 'M'); g.r(1, 15, 18, 2, 'M')
    g.r(3, 6, 14, 9, 'k'); g.e(10, 10.5, 5, 3.4, 'g'); g.e(10, 10.5, 2.4, 1.6, 'f')
    g.r(1, 4, 3, 13, 'M'); g.r(16, 4, 3, 13, 'M')
    return g, dict(m='#6a6482', M='#46405c', k='#07040c', g='#7a3aa0', f='#e0b0ff')


PROPS = [("portal", portal), ("bonfire", bonfire), ("flask", flask), ("gravestone", gravestone), ("tomb", tomb), ("candelabra", candelabra), ("coffin", coffin),
         ("deadtree", deadtree), ("skullpile", skullpile), ("chest", chest), ("barrel", barrel), ("altar", altar),
         ("brazier", brazier), ("statue", statue), ("pillar", pillar), ("cobweb", cobweb), ("torch", torch),
         ("coin", coin), ("heart", heart), ("soul", soul)]


# ------------------------------------------------------------------ tile (stile A: piatti)
def tile(kind, seed):
    r = random.Random(seed)
    im = Image.new("RGB", (T, T))
    px = im.load()

    def fill(c):
        for y in range(T):
            for x in range(T):
                px[x, y] = hexc(c)

    def spot(c, n, w=1, h=1):
        for _ in range(n):
            x, y = r.randrange(T), r.randrange(T)
            for j in range(h):
                for i in range(w):
                    if x + i < T and y + j < T:
                        px[x + i, y + j] = hexc(c)

    def slabs(cols, mortar, hi):
        fill(mortar)
        for ty in range(2):
            for tx in range(2):
                c = hexc(r.choice(cols))
                for j in range(1, 8):
                    for i in range(1, 8):
                        px[tx * 8 + i, ty * 8 + j] = c
                for i in range(1, 8):
                    px[tx * 8 + i, ty * 8 + 1] = hexc(hi)

    if kind == "cripta":
        slabs(['#2e2a3c', '#34304a', '#2a2638', '#383450'], '#15111e', '#4a4464')
        spot('#46405e', 4); spot('#15111e', 3, 3, 1)
    elif kind == "cripta_rune":
        slabs(['#2a2638', '#2e2a3c'], '#15111e', '#3e385a')
        cx, cy = r.randrange(4, 11), r.randrange(4, 11)
        for dx, dy in ((0, 0), (1, 0), (-1, 0), (0, 1), (0, -1), (2, 2), (-2, -2)):
            px[(cx + dx) % T, (cy + dy) % T] = hexc('#7a2a8a')
    elif kind == "cripta_sangue":
        slabs(['#2e2a3c', '#2a2638'], '#15111e', '#4a4464')
        cx, cy = r.randrange(4, 12), r.randrange(4, 12)
        for j in range(-2, 3):
            for i in range(-3, 4):
                if (i / 3) ** 2 + (j / 2) ** 2 <= 1:
                    px[(cx + i) % T, (cy + j) % T] = hexc(r.choice(['#5a0e1a', '#6a1220']))
        spot('#8a1a2a', 2)
    elif kind == "scacchi":  # pavimento gotico a scacchi
        for y in range(T):
            for x in range(T):
                px[x, y] = hexc('#2e2a3c' if ((x // 8) + (y // 8)) % 2 == 0 else '#1a1626')
        for i in range(T):
            px[i, 0] = hexc('#4a4464'); px[0, i] = hexc('#4a4464')
        spot('#46405e', 3)
    elif kind == "muro":  # muro di mattoni neri
        fill('#12101a')
        for j in range(4):
            off = 0 if j % 2 == 0 else 4
            for bx in range(-1, 3):
                x0 = bx * 8 + off
                c = hexc(r.choice(['#2e2a3c', '#34304a', '#28243a']))
                for yy in range(j * 4, j * 4 + 3):
                    for xx in range(x0 + 1, x0 + 8):
                        if 0 <= xx < T:
                            px[xx, yy] = c
                for xx in range(x0 + 1, x0 + 8):
                    if 0 <= xx < T:
                        px[xx, j * 4] = hexc('#4a4464')
        if r.random() < .35:
            spot('#2a4a34', 3)
    elif kind == "muro_cima":  # sommità del muro (guglie)
        fill('#0e0c14')
        spot('#1a1624', 14); spot('#2a2638', 6)
    elif kind == "tappeto":
        fill('#6a1424')
        for y in range(T):
            px[1, y] = hexc('#c8902a'); px[T - 2, y] = hexc('#c8902a')
            px[2, y] = hexc('#4a0c18'); px[T - 3, y] = hexc('#4a0c18')
        spot('#8a1c30', 8)
        if seed % 2:
            for dx, dy in ((0, -2), (-2, 0), (2, 0), (0, 2), (0, 0)):
                px[8 + dx, 8 + dy] = hexc('#c8902a')
    elif kind == "cimitero":  # erba morta e terra
        fill(r.choice(['#1e2a22', '#222e26', '#1a261e']))
        spot('#2e4034', 8); spot('#12181a', 6); spot('#4a4a3a', 2); spot('#3a4a3a', 4, 1, 2)
        if r.random() < .25:
            spot('#a8a8c0', 1)
    elif kind == "terra":
        fill(r.choice(['#2a2024', '#30262a', '#261c20']))
        spot('#3e3036', 8); spot('#18101a', 6); spot('#4a3a40', 3, 2, 1)
    elif kind == "palude":
        fill(r.choice(['#26301e', '#2c3622']))
        spot('#1a2214', 6); spot('#3e4a2a', 5)
        if r.random() < .6:
            cx, cy = r.randrange(4, 12), r.randrange(4, 12)
            for j in range(-3, 4):
                for i in range(-4, 5):
                    if (i / 4) ** 2 + (j / 3) ** 2 <= 1:
                        px[(cx + i) % T, (cy + j) % T] = hexc('#1a3a3a')
            px[cx % T, (cy - 1) % T] = hexc('#4aa89a')
    elif kind == "neve":
        fill(r.choice(['#aebccc', '#b6c4d2', '#a6b4c6']))
        spot('#8a9cb4', 10); spot('#6a7e9a', 3, 2, 1); spot('#e0ecf6', 4)
    elif kind == "lava":
        fill(r.choice(['#1a1416', '#201618', '#161012']))
        spot('#2e2224', 8)
        x, y = r.randrange(T), r.randrange(T)
        for _ in range(14):
            px[x % T, y % T] = hexc('#d8401a')
            if r.random() < .4:
                px[(x + 1) % T, y % T] = hexc('#ff9a30')
            x += r.choice([-1, 0, 1, 1]); y += r.choice([-1, 0, 1, 1])
    elif kind == "chioma":  # chioma d'alberi morti vista dall'alto
        fill(r.choice(['#0e1612', '#0c1410']))
        spot('#16241c', 14); spot('#1d3226', 8); spot('#070b09', 8, 2, 1); spot('#2a2230', 3, 1, 3)
    elif kind == "acqua":
        fill(r.choice(['#0a1218', '#0c161e']))
        for _ in range(3):
            x, y = r.randrange(T - 4), r.randrange(T)
            for i in range(r.randint(3, 5)):
                px[x + i, y] = hexc('#1a3040')
        spot('#3a6a7a', 2)
    elif kind == "roccia":
        fill(r.choice(['#2a2832', '#2e2c36']))
        spot('#3e3c48', 12, 2, 2); spot('#54525e', 5); spot('#14121a', 7, 3, 1)
    elif kind == "rocciag":
        fill(r.choice(['#7a8aa6', '#8494b0']))
        spot('#b0c0d8', 10, 2, 1); spot('#e6f0fa', 6); spot('#4a5a78', 7, 3, 1)
    elif kind == "magma":
        fill(r.choice(['#b02a0c', '#c8300e']))
        spot('#3a1410', 10, 3, 2); spot('#ff7a20', 14); spot('#ffd060', 4)
    elif kind == "sentiero":
        fill(r.choice(['#4a3a2e', '#44362a']))
        spot('#5a4838', 8); spot('#382a20', 8); spot('#6a5a4a', 3, 2, 1)
    return im


TILES = ["cripta", "cripta_rune", "cripta_sangue", "scacchi", "muro", "muro_cima", "tappeto", "cimitero", "terra",
         "palude", "neve", "lava", "chioma", "acqua", "roccia", "rocciag", "magma", "sentiero"]


# ------------------------------------------------------------------ scrittura
def grade(im, sat=0.62, val=0.86):
    """Desatura e scurisce; i pixel molto luminosi e saturi (occhi, fiamme) restano accesi."""
    import colorsys
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            h, ss, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            if v > 0.82 and ss > 0.55:
                continue
            ss *= sat
            v *= val
            r2, g2, b2 = colorsys.hsv_to_rgb(h, ss, v)
            px[x, y] = (int(r2 * 255), int(g2 * 255), int(b2 * 255), a)
    return im


def main():
    os.makedirs(os.path.join(OUT, "sprites"), exist_ok=True)
    os.makedirs(os.path.join(OUT, "tiles"), exist_ok=True)
    made = []
    for name, fn in CHARS + PROPS:
        g, pal = fn()
        im = S.render(g, pal, "B")
        im = grade(im, 0.62, 0.86) if (name, fn) in CHARS else grade(im, 0.78, 0.9)
        im.save(os.path.join(OUT, "sprites", name + ".png"))
        made.append((name, im))
    atlas = Image.new("RGB", (T * 4, T * len(TILES)))
    for row, k in enumerate(TILES):
        for v in range(4):
            atlas.paste(tile(k, 100 + row * 10 + v), (v * T, row * T))
    atlas.save(os.path.join(OUT, "tiles", "tiles.png"))

    SC = 5
    cell = 28 * SC + 8
    cols = 9
    rows = (len(made) + cols - 1) // cols
    pv = Image.new("RGB", (cols * cell, rows * cell + len(TILES) * 0 + 4 * 16 * SC + 24), (14, 10, 20))
    d = ImageDraw.Draw(pv)
    for i, (name, im) in enumerate(made):
        big = im.resize((im.width * SC, im.height * SC), Image.NEAREST)
        x, y = (i % cols) * cell, (i // cols) * cell
        pv.paste(big, (x + (cell - big.width) // 2, y + (cell - big.height) // 2), big)
        d.text((x + 4, y + 2), name, fill=(200, 170, 120))
    ty = rows * cell + 8
    big = atlas.resize((atlas.width * 2, atlas.height * 2), Image.NEAREST)
    # tile in orizzontale: ogni terreno una colonna da 4 varianti
    for row, k in enumerate(TILES):
        strip = atlas.crop((0, row * T, T * 4, row * T + T)).resize((T * 4 * 2, T * 2), Image.NEAREST)
        pv.paste(strip, ((row % 6) * (T * 4 * 2 + 12), ty + (row // 6) * (T * 2 + 14) + 10))
        d.text(((row % 6) * (T * 4 * 2 + 12), ty + (row // 6) * (T * 2 + 14) - 2), k, fill=(200, 170, 120))
    pv.crop((0, 0, pv.width, ty + 3 * (T * 2 + 14) + 14)).save(os.path.join(OUT, "preview.png"))
    print("sprite:", len(made), "tile:", len(TILES))


main()
