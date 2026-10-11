"""Decalques de tensão (v0.4): sinais de que algo deu errado, sem mostrar nada diretamente.

drag_marks   rastro escuro arrastado no chão
stain_dark   mancha escura seca com respingos
suit_torn    traje de proteção vazio, rasgado, largado no chão (com a máscara)
handprints   mãos sujas escorregando pela parede
wall_writing "НЕ ИДИ ВНИЗ" (não desça) riscado a giz na parede
lamp_broken  lanterna de mineiro quebrada, vidro espalhado
"""
import math
import random

from PIL import Image

from gen_assets import new, save, C, mix, text, vnoise
from polish import hramp, shade, polish_sprite

DRIED = C('#2a1512')        # sangue/óleo seco: quase preto, avermelhado
DRIED2 = C('#3d1d17')


def put(img, x, y, c):
    if 0 <= x < img.width and 0 <= y < img.height:
        img.putpixel((x, y), c)


def drag_marks():
    img = new(32, 12)
    rng = random.Random(3)
    for lane, y0 in ((0, 3), (1, 7)):
        for x in range(2, 30):
            w = 1 + (1 if vnoise(x, lane * 9, 3, 4) > .5 else 0)
            fade = min(1, (30 - x) / 10)
            for j in range(w):
                a = int(170 * fade * (0.6 + .4 * vnoise(x, j + lane * 5, 2, 7)))
                if a > 20:
                    put(img, x, y0 + j + (1 if x % 9 > 5 else 0), DRIED[:3] + (a,))
    for _ in range(6):
        put(img, rng.randrange(4, 28), rng.randrange(0, 12), DRIED2[:3] + (120,))
    return img


def stain_dark():
    img = new(20, 14)
    for y in range(14):
        for x in range(20):
            d = ((x - 9.5) / 7.5) ** 2 + ((y - 7) / 4.6) ** 2 + (vnoise(x, y, 3, 11) - .5) * .7
            if d < 1:
                a = 200 if d < .55 else 140
                put(img, x, y, (DRIED if d < .55 else DRIED2)[:3] + (a,))
    for (x, y) in ((1, 3), (18, 11), (16, 1), (3, 12), (19, 6)):
        put(img, x, y, DRIED2[:3] + (150,))
    put(img, 8, 5, C('#4a2a22')[:3] + (200,))      # brilho úmido
    return img


def suit_torn():
    """Traje amarelo achatado no chão, um braço esticado, máscara caída ao lado."""
    img = new(28, 16)
    suit = hramp('#a07c2a', 5, .6)
    # corpo (achatado), pernas e braço
    for y in range(4, 11):
        for x in range(8, 17):
            put(img, x, y, suit[2] if (x + y) % 5 else suit[3])
    for x in range(8, 17):
        put(img, x, 4, suit[1])
    for x in range(17, 25):                       # pernas
        put(img, x, 5, suit[2]); put(img, x, 6, suit[3]); put(img, x, 8, suit[2]); put(img, x, 9, suit[3])
    for (x, y) in ((25, 5), (25, 6), (25, 8), (25, 9)):
        put(img, x, y, C('#2a2620'))               # botas
    for x in range(2, 8):                          # braço esticado
        put(img, x, 6 + (1 if x < 4 else 0), suit[2]); put(img, x, 7 + (1 if x < 4 else 0), suit[3])
    put(img, 1, 7, C('#33302a')); put(img, 1, 8, C('#33302a'))
    # rasgo mostrando o forro escuro
    for (x, y) in ((11, 6), (12, 7), (12, 6), (13, 8), (14, 8)):
        put(img, x, y, C('#1c1914'))
    # máscara caída
    m = hramp('#545b40', 4, .6)
    for y in range(10, 15):
        for x in range(3, 8):
            if (x - 5) ** 2 / 6 + (y - 12) ** 2 / 5 < 1:
                put(img, x, y, m[1] if y < 12 else m[2])
    put(img, 4, 11, C('#9fc9bb')); put(img, 6, 11, C('#2a3a36'))
    put(img, 5, 14, C('#3b4129'))
    # mancha embaixo
    for y in range(11, 16):
        for x in range(10, 20):
            if img.getpixel((x, y))[3] == 0 and vnoise(x, y, 3, 5) > .45:
                put(img, x, y, DRIED[:3] + (130,))
    return img


HAND = [
    ".#.#.#..",
    ".#.#.#.#",
    ".#.#.#.#",
    "########",
    "#######.",
    "######..",
    ".#####..",
    "..####..",
]


def handprints():
    """Duas mãos espalmadas que escorregaram parede abaixo."""
    img = new(18, 26)
    rng = random.Random(8)
    col = C('#2b1713')
    for hx, hy, flip in ((1, 2, False), (9, 6, True)):
        for j, row in enumerate(HAND):
            for i, ch in enumerate(row):
                if ch == '#':
                    x = hx + (7 - i if flip else i)
                    put(img, x, hy + j, col[:3] + (rng.randint(170, 215),))
        for i in range(1, 7):                          # escorrido
            if rng.random() < .7:
                for y in range(hy + 8, hy + 8 + rng.randint(2, 10)):
                    if y < 26:
                        put(img, hx + i, y, col[:3] + (max(35, 170 - (y - hy - 8) * 15),))
    return img


GL57 = {   # 5x7 para a pichação (mais legível que a fonte 3x5)
    'Н': ["#...#", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
    'Е': ["#####", "#....", "#....", "####.", "#....", "#....", "#####"],
    'И': ["#...#", "#...#", "#..##", "#.#.#", "##..#", "#...#", "#...#"],
    'Д': [".###.", ".#.#.", ".#.#.", ".#.#.", ".#.#.", "#####", "#...#"],
    'В': ["####.", "#...#", "#...#", "####.", "#...#", "#...#", "####."],
    'З': [".###.", "#...#", "....#", "..##.", "....#", "#...#", ".###."],
    ' ': ["....."] * 7,
}


def scrawl(img, x, y, s, col, rng):
    for ch in s:
        g = GL57[ch]
        jit = rng.choice((0, 0, 0, 1))
        for j, row in enumerate(g):
            for i, v in enumerate(row):
                if v == '#' and rng.random() > .03:
                    put(img, x + i, y + j + jit, col[:3] + (rng.randint(170, 235),))
        x += 6 if ch != ' ' else 4
    return x


def wall_writing():
    img = new(46, 18)
    rng = random.Random(26)
    chalk = C('#d2cbb6')
    scrawl(img, 1, 1, 'НЕ ИДИ', chalk, rng)
    scrawl(img, 9, 10, 'ВНИЗ', chalk, rng)
    for x in range(8, 34):                                 # sublinhado nervoso
        put(img, x, 17 - (1 if x % 4 == 0 else 0), chalk[:3] + (160,))
    return img


def lamp_broken():
    img = new(16, 10)
    body = hramp('#4a4f52', 4, .7)
    for y in range(3, 8):
        for x in range(4, 10):
            put(img, x, y, body[1] if y < 5 else body[2])
    for x in range(4, 10):
        put(img, x, 3, body[0])
    for (x, y) in ((10, 4), (10, 5), (10, 6)):
        put(img, x, y, C('#7d6a3a'))                       # aro do farol, amassado
    glass = C('#b8d4d0')
    for (x, y) in ((12, 3), (13, 6), (11, 8), (14, 4), (12, 7)):
        put(img, x, y, glass)
    for x in range(0, 4):                                   # cabo
        put(img, x, 6 + (x % 2), C('#1c1c1c'))
    return img


def finish(img, name, outline=False):
    img = polish_sprite(img, denoise=False, selout=outline)
    save(img, 'environment/props/' + name + '.png')


def build():
    finish(drag_marks(), 'drag_marks')
    finish(stain_dark(), 'stain_dark')
    finish(suit_torn(), 'suit_torn')
    finish(handprints(), 'handprints')
    finish(wall_writing(), 'wall_writing')
    finish(lamp_broken(), 'lamp_broken')


if __name__ == '__main__':
    build()
    print('decalques ok')
