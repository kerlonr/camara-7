#!/usr/bin/env python3
"""Gera a pixel art PLACEHOLDER do Chernobyl Miner (versão 2: mais suja, mais detalhada).

Uso:  python tools/gen_assets.py        (áudio: python tools/gen_audio.py)
Substituir um asset = sobrescrever o PNG com o MESMO nome e tamanho.
Determinístico (seeds fixas). Requer: Pillow.

Princípios: paleta limitada e dessaturada; manchas suaves (value noise) em vez de
ruído de pixel; luz de cima/esquerda; contorno escuro único; detalhe onde o olho
pousa (objetos, rostos, placas), pouco detalhe no chão.
"""
import json
import math
import os
import random

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.normpath(os.path.join(HERE, '..'))
ASSETS = os.path.join(PROJECT, 'assets')
R = random.Random(1986)


# =========================================================================== util
def C(h, a=255):
    h = h.lstrip('#')
    if len(h) == 3:
        h = ''.join(ch * 2 for ch in h)
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


def mul(c, f):
    return (max(0, min(255, int(c[0] * f))), max(0, min(255, int(c[1] * f))),
            max(0, min(255, int(c[2] * f))), c[3])


def mix(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(4))


def alpha(c, a):
    return (c[0], c[1], c[2], a)


def new(w, h):
    return Image.new('RGBA', (w, h), (0, 0, 0, 0))


def save(img, rel):
    path = os.path.join(ASSETS, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path)


def blend(dst, src):
    a = src[3] / 255.0
    if dst[3] == 0:
        return src
    return (int(dst[0] * (1 - a) + src[0] * a), int(dst[1] * (1 - a) + src[1] * a),
            int(dst[2] * (1 - a) + src[2] * a), max(dst[3], src[3]))


def px(img, x, y, c):
    x, y = int(x), int(y)
    if 0 <= x < img.width and 0 <= y < img.height:
        if 0 < c[3] < 255:
            img.putpixel((x, y), blend(img.getpixel((x, y)), c))
        else:
            img.putpixel((x, y), c)


def get(img, x, y):
    if 0 <= x < img.width and 0 <= y < img.height:
        return img.getpixel((x, y))
    return (0, 0, 0, 0)


def rect(img, x, y, w, h, c):
    for j in range(h):
        for i in range(w):
            px(img, x + i, y + j, c)


def hline(img, x, y, w, c):
    rect(img, x, y, w, 1, c)


def vline(img, x, y, h, c):
    rect(img, x, y, 1, h, c)


def line(img, x0, y0, x1, y1, c):
    n = int(max(abs(x1 - x0), abs(y1 - y0))) + 1
    for i in range(n):
        t = i / max(1, n - 1)
        px(img, round(x0 + (x1 - x0) * t), round(y0 + (y1 - y0) * t), c)


def ellipse(img, cx, cy, rx, ry, c):
    for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
        for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
            if ((x + .5 - cx) / rx) ** 2 + ((y + .5 - cy) / ry) ** 2 <= 1.0:
                if c[3] == 0:
                    if 0 <= x < img.width and 0 <= y < img.height:
                        img.putpixel((x, y), c)
                else:
                    px(img, x, y, c)


def outline(img, color=None):
    color = color or C('#15130e')
    src = img.copy()
    for y in range(img.height):
        for x in range(img.width):
            if src.getpixel((x, y))[3] < 40:
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    if get(src, x + dx, y + dy)[3] >= 200:
                        img.putpixel((x, y), color)
                        break
    return img


def stamp(img, ox, oy, rows, pal):
    for j, row in enumerate(rows):
        for i, ch in enumerate(row):
            if ch not in '. ':
                px(img, ox + i, oy + j, pal[ch])


def shadow_ellipse(img, cx, cy, rx, ry, a=95):
    for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
        for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
            if ((x + .5 - cx) / rx) ** 2 + ((y + .5 - cy) / ry) ** 2 <= 1.0 and get(img, x, y)[3] == 0:
                if 0 <= x < img.width and 0 <= y < img.height:
                    img.putpixel((x, y), (8, 8, 6, a))


# ---------------------------------------------------------------- value noise
def _hash(ix, iy, seed):
    n = (ix * 374761393 + iy * 668265263 + seed * 1442695041) & 0xffffffff
    n = ((n ^ (n >> 13)) * 1274126177) & 0xffffffff
    return ((n ^ (n >> 16)) & 0xffff) / 65535.0


def vnoise(x, y, scale, seed, period=None):
    """Ruído suave, opcionalmente periódico (para tiles sem emenda)."""
    fx, fy = x / scale, y / scale
    ix, iy = int(math.floor(fx)), int(math.floor(fy))
    tx, ty = fx - ix, fy - iy
    tx, ty = tx * tx * (3 - 2 * tx), ty * ty * (3 - 2 * ty)

    def g(a, b):
        if period:
            a, b = a % period, b % period
        return _hash(a, b, seed)
    a = g(ix, iy) + (g(ix + 1, iy) - g(ix, iy)) * tx
    b = g(ix, iy + 1) + (g(ix + 1, iy + 1) - g(ix, iy + 1)) * tx
    return a + (b - a) * ty


def fbm(x, y, seed, size=16):
    return (vnoise(x, y, 8, seed, size // 8) * 0.55 + vnoise(x, y, 4, seed + 7, size // 4) * 0.3
            + vnoise(x, y, 2, seed + 13, size // 2) * 0.15)


BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]


def ramp(colors, v, x, y, dither=0.5):
    """Escolhe tom numa rampa a partir de v (0..1), com pontilhado leve nas transições."""
    n = len(colors)
    f = v * n + (BAYER[int(y) % 4][int(x) % 4] / 16.0 - 0.5) * dither
    return colors[max(0, min(n - 1, int(f)))]


# ===================================================================== PALETA
INK = C('#14120d')
CONC = [C('#a29e91'), C('#8a877b'), C('#706d63'), C('#57554d'), C('#403e38')]
RUST = [C('#c27a46'), C('#a15c35'), C('#7f4529'), C('#5c301d')]
OLIVE = [C('#6b7148'), C('#565b39'), C('#43472c'), C('#30331f')]
GRASS = [C('#7b7748'), C('#66683c'), C('#545833'), C('#43472a'), C('#343821')]
DIRT = [C('#6a5840'), C('#584936'), C('#483b2c'), C('#382e22')]
ROCK = [C('#6d665e'), C('#59524b'), C('#48423c'), C('#39342f'), C('#2b2723'), C('#1d1a17')]
STEEL = [C('#a9b3b6'), C('#808b90'), C('#5e686d'), C('#434b4f'), C('#2f3538')]
WOOD = [C('#8b6a43'), C('#6f5235'), C('#553e28'), C('#3c2b1c')]
WATER = [C('#6a8a89'), C('#4a6766'), C('#334d4d'), C('#243838')]
HAZ = [C('#ecca5c'), C('#d2a533'), C('#9d7a22'), C('#6f5418')]
RADG = [C('#d2ff96'), C('#8fe854'), C('#55b830'), C('#2f7a22')]
REDS = [C('#ff6a52'), C('#c63f2d'), C('#8c2a20'), C('#5a1c16')]
PAPER = [C('#ddd5bc'), C('#bdb49a'), C('#958c73'), C('#6e6753')]
CYAN = [C('#c8f4ff'), C('#6fd6ff'), C('#2f8fb8'), C('#1d5470')]
BLACK = C('#0e0d0a')
CLEAR = (0, 0, 0, 0)
SOVIET_RED = C('#a8322a')
SOVIET_GOLD = C('#d9b44a')

# ================================================================ FONTE 3x5
GLYPHS = {
    'А': ['.#.', '#.#', '###', '#.#', '#.#'], 'В': ['##.', '#.#', '##.', '#.#', '##.'],
    'Е': ['###', '#..', '##.', '#..', '###'], 'И': ['#.#', '#.#', '###', '##.', '#.#'],
    'Й': ['#.#', '...', '#.#', '###', '#.#'], 'К': ['#.#', '##.', '#..', '##.', '#.#'],
    'М': ['#.#', '###', '###', '#.#', '#.#'], 'Н': ['#.#', '#.#', '###', '#.#', '#.#'],
    'О': ['###', '#.#', '#.#', '#.#', '###'], 'П': ['###', '#.#', '#.#', '#.#', '#.#'],
    'Р': ['##.', '#.#', '##.', '#..', '#..'], 'С': ['###', '#..', '#..', '#..', '###'],
    'Т': ['###', '.#.', '.#.', '.#.', '.#.'], 'Ы': ['#.#', '#.#', '###', '#.#', '###'],
    'Э': ['##.', '..#', '.##', '..#', '##.'], 'Л': ['.##', '#.#', '#.#', '#.#', '#.#'],
    'Д': ['.#.', '#.#', '#.#', '###', '#.#'], 'Ш': ['#.#', '#.#', '###', '###', '###'],
    'Б': ['###', '#..', '##.', '#.#', '##.'], 'Г': ['###', '#..', '#..', '#..', '#..'],
    'З': ['##.', '..#', '.#.', '..#', '##.'], 'Ч': ['#.#', '#.#', '###', '..#', '..#'],
    'Я': ['.##', '#.#', '.##', '#.#', '#.#'],
    '0': ['###', '#.#', '#.#', '#.#', '###'], '1': ['.#.', '##.', '.#.', '.#.', '###'],
    '2': ['##.', '..#', '.#.', '#..', '###'], '3': ['##.', '..#', '.#.', '..#', '##.'],
    '4': ['#.#', '#.#', '###', '..#', '..#'], '5': ['###', '#..', '##.', '..#', '##.'],
    '6': ['.##', '#..', '###', '#.#', '###'], '7': ['###', '..#', '.#.', '.#.', '.#.'],
    '8': ['###', '#.#', '###', '#.#', '###'], '9': ['###', '#.#', '###', '..#', '##.'],
    '-': ['...', '...', '###', '...', '...'], '.': ['...', '...', '...', '...', '.#.'],
    ' ': ['...', '...', '...', '...', '...'],
}


def text(img, x, y, s, c, spacing=1):
    for ch in s:
        g = GLYPHS.get(ch.upper(), GLYPHS[' '])
        for j, row in enumerate(g):
            for i, v in enumerate(row):
                if v == '#':
                    px(img, x + i, y + j, c)
        x += 3 + spacing
    return x


def trefoil(img, cx, cy, r, fg, bg=None, ss=6, cover=0.42):
    """Trevo de radiação simétrico (ISO 361: centro R, lâminas de 1,5R a 5R, 60° cada).
    (cx, cy) em coordenadas contínuas; cada pixel é supersampleado."""
    if bg:
        ellipse(img, cx, cy, r + 1.2, r + 1.2, bg)
    hub, gap = 0.2, 0.3
    for y in range(int(cy - r) - 1, int(cy + r) + 2):
        for x in range(int(cx - r) - 1, int(cx + r) + 2):
            hits = 0
            for j in range(ss):
                for i in range(ss):
                    dx = x + (i + .5) / ss - cx
                    dy = y + (j + .5) / ss - cy
                    d = math.hypot(dx, dy) / r
                    if d <= hub:
                        hits += 1
                    elif gap <= d <= 1.0:
                        a = (math.degrees(math.atan2(dy, dx)) + 90) % 120
                        if a <= 30 or a >= 90:
                            hits += 1
            if hits / (ss * ss) >= cover:
                px(img, x, y, fg)


def grime(img, amount=0.25, seed=1, rust=False):
    """Sujeira: escurece em manchas suaves (mais embaixo) e, opcionalmente, escorridos de ferrugem."""
    rng = random.Random(seed)
    for y in range(img.height):
        for x in range(img.width):
            c = img.getpixel((x, y))
            if c[3] < 200:
                continue
            k = vnoise(x, y, 5, seed) * amount * (0.5 + y / img.height)
            if k > amount * 0.45:
                img.putpixel((x, y), mul(c, 1 - (k - amount * 0.45) * 1.4))
    if rust:
        for _ in range(max(1, img.width // 10)):
            x = rng.randrange(img.width)
            y0 = rng.randrange(max(1, img.height // 2))
            for y in range(y0, min(img.height, y0 + rng.randint(3, 9))):
                c = img.getpixel((x, y))
                if c[3] >= 200:
                    img.putpixel((x, y), mix(c, RUST[2], 0.55))


# ===================================================================== TILES
TILE = 16
tiles = []


def add_tile(name, img, solid=False, occluder=False, slow=False):
    tiles.append((name, img, {'solid': solid, 'occluder': occluder, 'slow': slow}))


def noise_tile(colors, seed, dither=0.6):
    img = new(16, 16)
    for y in range(16):
        for x in range(16):
            img.putpixel((x, y), ramp(colors, fbm(x, y, seed), x, y, dither))
    return img


def t_grass(seed):
    rng = random.Random(seed)
    img = noise_tile([GRASS[3], GRASS[2], GRASS[2], GRASS[1]], seed, 0.7)
    for _ in range(rng.randint(3, 5)):
        x, y = rng.randrange(1, 15), rng.randrange(3, 15)
        c = rng.choice([GRASS[0], C('#8a8250'), GRASS[1]])
        px(img, x, y, c); px(img, x, y - 1, c)
        px(img, x + rng.choice([-1, 1]), y - 2, mul(c, 1.1))
        px(img, x + 1, y, GRASS[4])
    if rng.random() < .3:
        x, y = rng.randrange(2, 14), rng.randrange(2, 14)
        px(img, x, y, CONC[2]); px(img, x + 1, y, CONC[3]); px(img, x, y - 1, CONC[1])
    return img


def t_dirt(seed):
    rng = random.Random(seed)
    img = noise_tile([DIRT[3], DIRT[2], DIRT[2], DIRT[1]], seed, 0.7)
    for _ in range(rng.randint(1, 3)):
        x, y = rng.randrange(1, 14), rng.randrange(2, 14)
        px(img, x, y, CONC[2]); px(img, x + 1, y, CONC[3]); px(img, x, y - 1, CONC[1])
    return img


def t_asphalt(seed):
    rng = random.Random(seed)
    img = noise_tile([C('#2f302d'), C('#383936'), C('#3f403c'), C('#464743')], seed, 0.9)
    x, y = rng.randrange(3, 13), 0
    for _ in range(20):
        px(img, x, y, C('#1c1d1a')); px(img, x + 1, y, C('#4c4d48'))
        if rng.random() < .2:
            px(img, x - 1, y, GRASS[2])
        x = max(0, min(15, x + rng.choice([-1, 0, 0, 1])))
        y += 1
        if y > 15:
            break
    return img


def t_concrete(seed, hexa=False):
    rng = random.Random(seed)
    img = noise_tile([CONC[3], CONC[2], CONC[2], CONC[1]], seed, 0.5)
    if hexa:   # pavimento de placas hexagonais, comum em cidades soviéticas
        for y in range(16):
            for x in range(16):
                hx = (x + (4 if (y // 8) % 2 else 0)) % 8
                hy = y % 8
                if hy == 0 or (hx == 0 and 1 <= hy <= 7):
                    px(img, x, y, CONC[4])
                elif hy == 1 or hx == 1:
                    px(img, x, y, CONC[1])
    else:
        hline(img, 0, 15, 16, CONC[4]); vline(img, 15, 0, 16, CONC[4])
        hline(img, 0, 0, 15, CONC[1]); vline(img, 0, 0, 15, CONC[1])
    if rng.random() < .55:
        cx, cy = rng.randrange(3, 13), rng.randrange(3, 13)
        for y in range(16):
            for x in range(16):
                if (x - cx) ** 2 / 9 + (y - cy) ** 2 / 5 < 1 and vnoise(x, y, 2, seed) > .3:
                    px(img, x, y, mul(img.getpixel((x, y)), .82))
    if rng.random() < .4:
        px(img, 14, 14, CONC[4]); px(img, 13, 14, CONC[3]); px(img, 14, 13, CONC[3])
    return img


def t_puddle(seed):
    img = t_asphalt(seed)
    for y in range(16):
        for x in range(16):
            d = ((x - 8) / 6.5) ** 2 + ((y - 9) / 4.2) ** 2 + vnoise(x, y, 3, seed) * .3
            if d < 1:
                px(img, x, y, WATER[3] if d > .7 else WATER[2])
    hline(img, 5, 7, 4, WATER[1]); px(img, 10, 10, WATER[0]); hline(img, 6, 11, 2, WATER[1])
    return img


def t_fence_face(seed):
    rng = random.Random(seed)
    img = new(16, 16)
    for y in range(16):
        for x in range(16):
            base = ramp([CONC[2], CONC[1], CONC[1]], vnoise(x, y, 4, seed, 4), x, y, .3)
            d = abs((x % 8) - 3.5) + abs((y % 8) - 3.5)
            if 2.6 < d < 3.8:
                base = CONC[0] if (x % 8) < 4 and (y % 8) < 4 else CONC[3]
            img.putpixel((x, y), base)
    for y in range(11, 16):
        for x in range(16):
            if vnoise(x, y, 2, seed + 3) > .55 - (y - 11) * .06:
                px(img, x, y, mix(img.getpixel((x, y)), GRASS[3], .6))
    for _ in range(2):
        x = rng.randrange(16)
        for y in range(rng.randrange(2, 8), 14):
            px(img, x, y, mul(img.getpixel((x, y)), .8))
    hline(img, 0, 15, 16, CONC[4])
    return img


def t_fence_top(seed):
    img = noise_tile([CONC[3], CONC[2], CONC[2]], seed, .4)
    rect(img, 0, 5, 16, 6, CONC[1]); hline(img, 0, 5, 16, CONC[0]); hline(img, 0, 10, 16, CONC[4])
    return img


def t_mine_floor(seed, tint=None, gravel=False):
    rng = random.Random(seed)
    img = noise_tile([ROCK[4], ROCK[3], ROCK[3], ROCK[2]], seed, 0.7)
    for _ in range(rng.randint(2, 4) + (5 if gravel else 0)):
        x, y = rng.randrange(1, 15), rng.randrange(1, 15)
        px(img, x, y, ROCK[1]); px(img, x, y + 1, ROCK[5])
        if gravel and rng.random() < .5:
            px(img, x + 1, y, ROCK[2])
    if tint:
        x, y = rng.randrange(16), 0
        for _ in range(18):
            px(img, x, y, tint)
            if rng.random() < .3:
                px(img, x + 1, y, mul(tint, .6))
            x = max(0, min(15, x + rng.choice([-1, 0, 1]))); y += 1
            if y > 15:
                break
    return img


def t_mine_wet(seed):
    img = t_mine_floor(seed)
    for y in range(16):
        for x in range(16):
            d = ((x - 7) / 5.5) ** 2 + ((y - 8) / 3.6) ** 2 + vnoise(x, y, 3, seed) * .35
            if d < 1:
                px(img, x, y, WATER[3] if d > .6 else WATER[2])
    hline(img, 5, 7, 3, WATER[1])
    return img


def t_rail(seed, vertical):
    img = t_mine_floor(seed, gravel=True)
    for k in range(0, 16, 4):
        if vertical:
            rect(img, 2, k + 1, 12, 2, WOOD[2]); hline(img, 2, k + 1, 12, WOOD[1])
        else:
            rect(img, k + 1, 2, 2, 12, WOOD[2]); vline(img, k + 1, 2, 12, WOOD[1])
    for off in (4, 11):
        if vertical:
            vline(img, off, 0, 16, RUST[2]); vline(img, off + 1, 0, 16, STEEL[2])
        else:
            hline(img, 0, off, 16, STEEL[2]); hline(img, 0, off + 1, 16, RUST[3])
    return img


def t_rock_top(seed, base=None):
    base = base or ROCK[5]
    return noise_tile([mul(base, .8), base, base, mul(base, 1.25)], seed, .5)


def t_rock_face(seed, glow=False):
    rng = random.Random(seed)
    img = new(16, 16)
    for y in range(16):
        for x in range(16):
            v = vnoise(x, y * 2.2, 5, seed, None) * .7 + (1 - y / 16) * .3
            img.putpixel((x, y), ramp([ROCK[4], ROCK[3], ROCK[2], ROCK[1]], v, x, y, .5))
    for yy in (4, 9, 13):
        off = rng.randint(-1, 1)
        for x in range(16):
            if vnoise(x, yy, 3, seed + 2) > .35:
                px(img, x, yy + off + (1 if vnoise(x, yy, 6, seed) > .6 else 0), ROCK[5])
    hline(img, 0, 0, 16, ROCK[0]); hline(img, 0, 1, 16, ROCK[1])
    hline(img, 0, 15, 16, ROCK[5]); hline(img, 0, 14, 16, ROCK[4])
    if glow:
        x, y = rng.randrange(3, 13), 3
        for _ in range(12):
            px(img, x, y, CYAN[2]); px(img, x, y + 1, CYAN[3])
            x += rng.choice([-1, 0, 1]); y += 1
            if y > 13:
                break
        px(img, x, y, CYAN[1])
    return img


def t_rock_planks(seed):
    rng = random.Random(seed)
    img = t_rock_face(seed)
    for y0 in (2, 7, 12):
        for x in range(16):
            for yy in range(y0, y0 + 4):
                if yy < 15:
                    px(img, x, yy, WOOD[2] if (x + yy) % 7 else WOOD[3])
        hline(img, 0, y0, 16, WOOD[1]); hline(img, 0, min(14, y0 + 3), 16, WOOD[3])
        for x in (3, 12):
            px(img, x, y0 + 1, STEEL[1])
        if rng.random() < .5:
            x = rng.randrange(2, 13)
            rect(img, x, y0 + 1, 3, 2, ROCK[5])
    vline(img, 7, 0, 15, WOOD[3]); vline(img, 8, 0, 15, WOOD[1])
    return img


def t_ind_floor(seed, stripe=False):
    rng = random.Random(seed)
    img = noise_tile([C('#454640'), C('#4f504a'), C('#4f504a'), C('#585953')], seed, .5)
    hline(img, 0, 15, 16, C('#34352f')); vline(img, 15, 0, 16, C('#34352f'))
    hline(img, 0, 0, 15, C('#5f605a'))
    if stripe:
        for x in range(16):
            for y in range(12, 16):
                px(img, x, y, HAZ[2] if ((x + y) // 3) % 2 == 0 else BLACK)
    if rng.random() < .4:
        ellipse(img, rng.randrange(4, 12), rng.randrange(4, 10), 2.5, 1.5, alpha(RUST[3], 140))
    return img


def t_ind_face(seed):
    rng = random.Random(seed)
    img = new(16, 16)
    for y in range(16):
        for x in range(16):
            if y < 9:
                c = ramp([C('#9e9986'), C('#aba693'), C('#b5b09c')], vnoise(x, y, 4, seed, 4), x, y, .4)
            else:
                c = ramp([C('#3e5848'), C('#4a6855'), C('#557562')], vnoise(x, y, 4, seed + 1, 4), x, y, .4)
            img.putpixel((x, y), c)
    hline(img, 0, 9, 16, C('#2c3d33'))
    for _ in range(rng.randint(1, 3)):
        x, y = rng.randrange(14), rng.randrange(1, 14)
        for i in range(rng.randint(2, 4)):
            for j in range(rng.randint(1, 2)):
                px(img, x + i, y + j, CONC[2] if j == 0 else CONC[3])
    for _ in range(rng.randint(1, 2)):
        x = rng.randrange(16)
        for y in range(rng.randrange(0, 5), rng.randrange(9, 16)):
            px(img, x, y, alpha(RUST[2], 160))
    hline(img, 0, 0, 16, C('#c4bfaa')); hline(img, 0, 15, 16, C('#202520'))
    return img


def t_tile_face(seed):
    rng = random.Random(seed)
    img = new(16, 16)
    for y in range(16):
        for x in range(16):
            c = C('#b9beb0') if y < 10 else C('#7f9c8c')
            if x % 4 == 0 or y % 4 == 0:
                c = C('#6d6f66') if y < 10 else C('#4d6157')
            img.putpixel((x, y), mul(c, 0.92 + vnoise(x, y, 4, seed, 4) * .12))
    for _ in range(rng.randint(1, 3)):
        tx, ty = rng.randrange(4) * 4, rng.randrange(4) * 4
        rect(img, tx + 1, ty + 1, 3, 3, CONC[3]); px(img, tx + 1, ty + 1, CONC[2])
    for _ in range(2):
        x = rng.randrange(16)
        for y in range(rng.randrange(4), rng.randrange(8, 16)):
            px(img, x, y, alpha(C('#5a4a30'), 90))
    hline(img, 0, 15, 16, C('#2a2f2a'))
    return img


def t_water(seed):
    img = noise_tile([WATER[3], WATER[2], WATER[2], WATER[1]], seed, .4)
    rng = random.Random(seed)
    for _ in range(3):
        hline(img, rng.randrange(13), rng.randrange(16), 3, WATER[0])
    return img


def build_tiles():
    add_tile('grass', t_grass(1)); add_tile('grass2', t_grass(2)); add_tile('grass3', t_grass(3))
    add_tile('dirt', t_dirt(4)); add_tile('dirt2', t_dirt(5))
    add_tile('asphalt', t_asphalt(6)); add_tile('asphalt2', t_asphalt(7))
    add_tile('concrete', t_concrete(8)); add_tile('concrete2', t_concrete(9, hexa=True))
    add_tile('puddle', t_puddle(10), slow=True)
    add_tile('fence_face', t_fence_face(11), solid=True)
    add_tile('fence_top', t_fence_top(12), solid=True, occluder=True)
    add_tile('mine_floor', t_mine_floor(20)); add_tile('mine_floor2', t_mine_floor(21))
    add_tile('mine_floor3', t_mine_floor(22)); add_tile('mine_gravel', t_mine_floor(39, gravel=True))
    add_tile('mine_wet', t_mine_wet(23), slow=True)
    add_tile('rail_h', t_rail(24, False)); add_tile('rail_v', t_rail(25, True))
    add_tile('hot_floor', t_mine_floor(26, tint=RADG[2])); add_tile('hot_floor2', t_mine_floor(27, tint=RADG[3]))
    add_tile('rock_top', t_rock_top(28), solid=True, occluder=True)
    add_tile('rock_top2', t_rock_top(29), solid=True, occluder=True)
    add_tile('rock_face', t_rock_face(30), solid=True)
    add_tile('rock_face2', t_rock_face(31), solid=True)
    add_tile('rock_face_planks', t_rock_planks(40), solid=True)
    add_tile('rock_face_glow', t_rock_face(41, glow=True), solid=True)
    add_tile('ind_floor', t_ind_floor(32)); add_tile('ind_floor2', t_ind_floor(33))
    add_tile('ind_floor_stripe', t_ind_floor(34, stripe=True))
    add_tile('ind_top', t_rock_top(35, C('#1c1c19')), solid=True, occluder=True)
    add_tile('ind_face', t_ind_face(36), solid=True)
    add_tile('ind_face2', t_ind_face(37), solid=True)
    add_tile('tile_face', t_tile_face(42), solid=True)
    add_tile('tile_face2', t_tile_face(43), solid=True)
    add_tile('water', t_water(38), slow=True)
    add_tile('void', new(16, 16), solid=True)
    cols = 8
    rows = math.ceil(len(tiles) / cols)
    atlas = new(cols * TILE, rows * TILE)
    meta = {}
    for i, (name, img, props) in enumerate(tiles):
        cx, cy = i % cols, i // cols
        atlas.paste(img, (cx * TILE, cy * TILE))
        meta[name] = dict(coords=[cx, cy], **props)
    save(atlas, 'environment/tiles/tileset.png')
    out = {'_comment': 'Gerado por tools/gen_assets.py. coords = coluna/linha no atlas de 16px.',
           'texture': 'res://assets/environment/tiles/tileset.png', 'tile_size': TILE, 'tiles': meta}
    path = os.path.join(PROJECT, 'data', 'tiles', 'tiles.json')
    with open(path, 'w', encoding='utf-8') as f:
        json.dump(out, f, indent=1, ensure_ascii=False)


# ===================================================================== ROCHAS
def boulder(seed, tones, w=13, h=11, lumpy=.14):
    """Rocha com 4 tons; tones = [luz, base, sombra, sombra profunda]."""
    rng = random.Random(seed)
    img = new(16, 16)
    cx, cy = 8, 16 - h / 2 - 1.5
    shadow_ellipse(img, 8, 14.6, 7.2, 1.9, 120)
    for y in range(16):
        for x in range(16):
            dx, dy = (x + .5 - cx) / (w / 2), (y + .5 - cy) / (h / 2)
            r = dx * dx + dy * dy + (vnoise(x, y, 3, seed) - .5) * lumpy * 2.5
            if r <= 1:
                lit = -dx * .55 - dy * .85 + (vnoise(x, y, 2, seed + 4) - .5) * .5
                c = tones[0] if lit > .55 else tones[1] if lit > -.05 else tones[2] if lit > -.6 else tones[3]
                img.putpixel((x, y), c)
    for _ in range(2):
        x, y = rng.randrange(4, 12), rng.randrange(6, 12)
        for _k in range(rng.randint(2, 4)):
            if get(img, x, y)[3] == 255:
                img.putpixel((x, y), mul(tones[3], .8))
            x += rng.choice([-1, 1]); y += rng.choice([0, 1])
    return img


def crystals(img, seed, cols, n, size=2, area=(3, 5, 13, 13)):
    rng = random.Random(seed)
    placed = 0
    for _ in range(n * 12):
        if placed >= n:
            break
        x, y = rng.randrange(area[0], area[2]), rng.randrange(area[1], area[3])
        if get(img, x, y)[3] != 255 or get(img, x, y + min(size, 2))[3] != 255:
            continue
        light, mid, dark = cols
        px(img, x, y, light)
        if size >= 2:
            px(img, x + 1, y, mid); px(img, x, y + 1, mid); px(img, x + 1, y + 1, dark)
        if size >= 3:
            px(img, x - 1, y + 1, mid); px(img, x, y + 2, dark)
        placed += 1


def scrap_pile(seed):
    rng = random.Random(seed)
    img = new(16, 16)
    shadow_ellipse(img, 8, 14, 7, 2, 120)
    for _ in range(6):
        x, y = rng.randrange(2, 9), rng.randrange(5, 11)
        w, h = rng.randint(3, 6), rng.randint(2, 3)
        c = rng.choice(RUST[:3] + [STEEL[2], OLIVE[1]])
        rect(img, x, y, w, h, c); hline(img, x, y, w, mul(c, 1.25)); hline(img, x, y + h - 1, w, mul(c, .7))
    line(img, 3, 11, 12, 5, STEEL[1]); line(img, 3, 12, 12, 6, STEEL[3]); px(img, 12, 5, STEEL[0])
    ellipse(img, 10, 10, 1.6, 1.6, RUST[3]); px(img, 10, 10, BLACK)
    return outline(img)


def graphite_block():
    img = new(16, 16)
    shadow_ellipse(img, 8, 14, 7, 2, 120)
    for (x, y) in ((2, 7), (8, 7), (5, 3)):
        rect(img, x, y, 6, 5, C('#2a2a2d')); hline(img, x, y, 6, C('#4a4a50')); vline(img, x + 5, y, 5, C('#18181a'))
        ellipse(img, x + 3, y + 2.5, 1, 1, C('#111113'))
        px(img, x + 1, y + 3, RADG[3])
    return outline(img)


def cracks(stage):
    img = new(16, 16)
    rng = random.Random(77)
    paths = 2 + stage * 2
    for p in range(paths):
        x, y = 8 + rng.randint(-1, 1), 9 + rng.randint(-1, 1)
        ang = p / paths * math.tau + rng.uniform(-.3, .3)
        for s in range(2 + stage * 2):
            px(img, round(x), round(y), (12, 10, 8, 220))
            x += math.cos(ang); y += math.sin(ang) * .8; ang += rng.uniform(-.5, .5)
    return img


def build_rocks():
    d = 'environment/rocks/'
    stone_t = [ROCK[0], ROCK[1], ROCK[3], ROCK[4]]
    save(outline(boulder(1, stone_t)), d + 'stone_1.png')
    save(outline(boulder(2, [C('#7a7063'), C('#61584d'), C('#4a433b'), C('#36302a')], 12, 10)), d + 'stone_2.png')
    save(outline(boulder(3, stone_t, 14, 9, .2)), d + 'stone_3.png')
    dense = [ROCK[1], ROCK[2], ROCK[4], ROCK[5]]
    save(outline(boulder(4, dense, 14, 12)), d + 'stone_dense.png')
    save(outline(boulder(5, dense, 13, 11, .25)), d + 'stone_dense_2.png')
    b = boulder(6, dense)
    crystals(b, 6, (C('#7f8590'), C('#1a1a1d'), C('#0d0d0f')), 6, 2)
    save(outline(b), d + 'coal.png')
    b = boulder(7, stone_t)
    crystals(b, 7, (RUST[0], RUST[1], C('#5c2018')), 6, 2)
    save(outline(b), d + 'iron.png')
    b = boulder(8, stone_t)
    crystals(b, 8, (C('#e09a5a'), C('#b8703c'), C('#7a4422')), 3, 2)
    crystals(b, 18, (C('#8fe0c0'), C('#3fa58a'), C('#2a6e5c')), 4, 2)
    save(outline(b), d + 'copper.png')
    save(scrap_pile(9), d + 'scrap.png')
    save(scrap_pile(19), d + 'scrap_2.png')
    b = boulder(10, [C('#6e737c'), C('#565a62'), C('#41444a'), C('#2f3135')])
    crystals(b, 10, (C('#e1e6ee'), C('#a7adb8'), C('#6c7280')), 5, 2)
    save(outline(b), d + 'lead.png')
    b = boulder(11, [ROCK[2], ROCK[3], ROCK[4], ROCK[5]])
    crystals(b, 11, (C('#efff8a'), RADG[1], RADG[3]), 6, 2)
    save(outline(b), d + 'uranium.png')
    save(graphite_block(), d + 'graphite.png')
    b = boulder(13, [ROCK[2], ROCK[3], ROCK[4], ROCK[5]])
    crystals(b, 13, (CYAN[0], CYAN[1], CYAN[2]), 5, 3)
    save(outline(b), d + 'blue_vein.png')
    b = boulder(14, [C('#857a6c'), C('#6b6156'), C('#524940'), C('#3a332c')], 12, 11)
    ellipse(b, 8.5, 9.5, 3.5, 2.8, C('#2a2236'))
    crystals(b, 14, (C('#f0e0ff'), C('#b9a6d6'), C('#6f5a96')), 5, 2, (6, 8, 11, 11))
    save(outline(b), d + 'geode.png')
    cr = new(16, 16)
    shadow_ellipse(cr, 8, 14.5, 7, 2, 120)
    rect(cr, 2, 4, 12, 10, WOOD[1])
    for y in (4, 7, 10):
        hline(cr, 2, y, 12, WOOD[0]); hline(cr, 2, y + 2, 12, WOOD[2])
    vline(cr, 2, 4, 10, WOOD[3]); vline(cr, 13, 4, 10, WOOD[3])
    line(cr, 3, 13, 12, 5, WOOD[3])
    grime(cr, .3, 15)
    save(outline(cr), d + 'crate.png')
    lk = new(16, 16)
    shadow_ellipse(lk, 8, 14.5, 6, 1.6, 120)
    rect(lk, 3, 1, 10, 13, OLIVE[1]); rect(lk, 3, 1, 10, 2, OLIVE[0])
    vline(lk, 8, 3, 11, OLIVE[3]); px(lk, 7, 8, STEEL[0]); px(lk, 9, 8, STEEL[0])
    for y in (4, 5, 6):
        hline(lk, 4, y, 3, OLIVE[3]); hline(lk, 9, y, 3, OLIVE[3])
    rect(lk, 4, 10, 3, 2, PAPER[1])
    grime(lk, .35, 16, rust=True)
    save(outline(lk), d + 'locker.png')
    mc = new(16, 16)
    shadow_ellipse(mc, 8, 14.5, 6, 1.6, 120)
    rect(mc, 3, 2, 10, 12, C('#c9c6b6')); hline(mc, 3, 2, 10, C('#e0ddcc')); vline(mc, 12, 2, 12, C('#9a9888'))
    vline(mc, 8, 4, 10, C('#9a9888'))
    rect(mc, 5, 5, 6, 2, C('#3f7a45')); rect(mc, 7, 3, 2, 6, C('#3f7a45'))
    grime(mc, .3, 17, rust=True)
    save(outline(mc), d + 'medcab.png')
    sf = new(16, 16)
    shadow_ellipse(sf, 8, 14.5, 7, 1.8, 120)
    rect(sf, 2, 3, 12, 11, C('#4a5246')); hline(sf, 2, 3, 12, C('#66705f')); vline(sf, 13, 3, 11, C('#2f352c'))
    ellipse(sf, 8, 8.5, 2.5, 2.5, C('#8a9488')); ellipse(sf, 8, 8.5, 1.4, 1.4, C('#2f352c')); px(sf, 8, 6, C('#c0c8bc'))
    rect(sf, 11, 7, 1, 3, STEEL[1])
    grime(sf, .3, 18, rust=True)
    save(outline(sf), d + 'safe.png')
    for s in (1, 2, 3):
        save(cracks(s), d + f'cracks_{s}.png')


# ================================================================ PERSONAGEM
FRONT_HEAD = [
    "......KKKK......",
    "....KKLYYYKK....",
    "...KLLYYYYYyK...",
    "..KLYMMMMMMyyK..",
    "..KYMVVmmVVMyK..",
    "..KYMVvmmVvMyK..",
    "..KYMMMmmMMMyK..",
    "..KyYmMFFMmyDK..",
    "...KyYKFfKyDK...",
    "....KyyKKyDK....",
]
FRONT_TORSO = {
    'idle': [
        "...KYLYZYYyDK...",
        "..KYYLYZYYyyDK..",
        ".KYKYLYZYYyyKDK.",
        ".KYKYYYZYYyyKDK.",
        ".KyKSPSZSSSSKDK.",
        ".KBKYYYZYYyyKBK.",
        "..KKYYYYYyyDKK..",
    ],
    'windup': [
        ".KBKYLYZYYyDKBK.",
        ".KYKYLYZYYyyKDK.",
        "..KYLYYZYYyyDK..",
        "..KYYYYZYYyyDK..",
        "..KSPSSZSSSSDK..",
        "..KYYYYZYYyyDK..",
        "..KKYYYYYyyDKK..",
    ],
    'strike': [
        "...KYLYZYYyDK...",
        "..KYYLYZYYyyDK..",
        "..KYYKLZYKyyDK..",
        "..KYYYKZKYyyDK..",
        "..KSPSKBKSSSDK..",
        "..KYYYKBBKyyDK..",
        "..KKYYYKKYyDKK..",
    ],
}
FRONT_LEGS = {
    'stand': [
        "....KYYyKYyDK...",
        "....KYYyKYyDK...",
        "....KYLyKLyDK...",
        "....KYyyKyyDK...",
        "....KBBBKBBBK...",
        "....KBbBKBbBK...",
        "....KKKKKKKKK...",
    ],
    'stepL': [
        "....KYYyKYyDK...",
        "....KYLyKYyDK...",
        "....KYyyKLyDK...",
        "....KBBBKyyDK...",
        "....KBbBKBBBK...",
        "....KKKKKBbBK...",
        "........KKKKK...",
    ],
    'stepR': [
        "....KYYyKYyDK...",
        "....KYYyKLyDK...",
        "....KLyyKyyDK...",
        "....KYyyKBBBK...",
        "....KBBBKBbBK...",
        "....KBbBKKKKK...",
        "....KKKKK.......",
    ],
}
BACK_HEAD = [
    "......KKKK......",
    "....KKLYYYKK....",
    "...KLLYYYYYyK...",
    "..KLYYYYYYyyyK..",
    "..KYYYYYYYyyyK..",
    "..KYYYZZYYyyDK..",
    "..KYYYYYYYyyDK..",
    "..KyYYYYYyyDDK..",
    "...KyyMMMMyDK...",
    "....KyyyyyDK....",
]
BACK_TORSO = {
    'idle': [
        "...KYFFFFFFDK...",
        "..KYFfFFFFfFDK..",
        ".KYKFFZZZZFFKDK.",
        ".KYKFfFFFFfFKDK.",
        ".KyKSFFFFFFSKDK.",
        ".KBKYSSSSSSyKBK.",
        "..KKYYYYYyyDKK..",
    ],
    'windup': [
        ".KBKFFFFFFFDKBK.",
        ".KYKFfFFFFfFKDK.",
        "..KYFFZZZZFFDK..",
        "..KYFfFFFFfFDK..",
        "..KYSFFFFFFSDK..",
        "..KYYSSSSSSyDK..",
        "..KKYYYYYyyDKK..",
    ],
    'strike': [
        "...KYFFFFFFDK...",
        "..KYFfFFFFfFDK..",
        "..KYFFZZZZFFDK..",
        "..KYFfFFFFfFDK..",
        "..KYSFFFFFFSDK..",
        "..KYYSSSSSSyDK..",
        "..KKYYYYYyyDKK..",
    ],
}
SIDE_HEAD = [
    ".....KKKK.......",
    "....KLYYYKK.....",
    "...KLLYYYYyK....",
    "...KLYYYMMMMK...",
    "...KYYYMVVMMK...",
    "...KYYYMVvmMK...",
    "...KYYyMMMMMFK..",
    "...KyYYyymMFFfK.",
    "....KyyDDKKFfK..",
    ".....KyyyDK.KK..",
]
SIDE_TORSO = {
    'idle': [
        "....KYYYYyDK....",
        "...KYYLLYyyDK...",
        "...KYYKLYKyDK...",
        "...KYYKYyKyDK...",
        "...KSPKYyKSSK...",
        "...KYYKBBKyDK...",
        "....KYYKKyDK....",
    ],
    'windup': [
        "....KYYYKBK.....",
        "...KYYYLKYK.....",
        "...KYYLLyyDK....",
        "...KYYYYyyDK....",
        "...KSPSSSSSK....",
        "...KYYYYyyDK....",
        "....KYYKKyDK....",
    ],
    'strike': [
        "....KYYYYyDK....",
        "...KYYYLLYyDK...",
        "...KYYYYLLLKKK..",
        "...KYYYYyyyKBBK.",
        "...KSPSSSSSKKK..",
        "...KYYYYyyDK....",
        "....KYYKKyDK....",
    ],
}
SIDE_LEGS = {
    'stand': [
        ".....KYYyDK.....",
        ".....KYLyDK.....",
        ".....KYyyDK.....",
        ".....KYyyDK.....",
        ".....KBBBBK.....",
        ".....KBbBBBK....",
        ".....KKKKKKK....",
    ],
    'stepL': [
        "....KYYKyDK.....",
        "....KYLKyyDK....",
        "...KYYK.KyDK....",
        "...KYyK..KyDK...",
        "..KBBBK..KBBK...",
        "..KBbBK..KBbBK..",
        "..KKKKK..KKKKK..",
    ],
}
SIDE_LEGS['stepR'] = SIDE_LEGS['stepL']

SUIT_PALETTES = {
    1: {'Y': '#c99d33', 'y': '#94721f', 'D': '#6a5116', 'L': '#e3c25e', 'S': '#4f3f2b', 'P': '#5b6340', 'Z': '#7a776a', 'F': '#59613f', 'f': '#3b4129'},
    2: {'Y': '#dbb02e', 'y': '#a17b1b', 'D': '#725712', 'L': '#f4da78', 'S': '#7f858b', 'P': '#4e5838', 'Z': '#c8cdd2', 'F': '#525c3a', 'f': '#363d25'},
    3: {'Y': '#c48722', 'y': '#895a15', 'D': '#5f3e0f', 'L': '#e6ad4c', 'S': '#2c2d2a', 'P': '#3c3f3c', 'Z': '#5c6064', 'F': '#474c4f', 'f': '#2c2f31'},
    4: {'Y': '#e4dbb4', 'y': '#a69d77', 'D': '#787152', 'L': '#fffbe6', 'S': '#c4532a', 'P': '#8a3a20', 'Z': '#d9692e', 'F': '#c4532a', 'f': '#7d3018'},
}
COMMON_PAL = {'K': '#14120d', 'M': '#4b504a', 'm': '#2f332c', 'V': '#1f2b29', 'v': '#a6cfc0',
              'B': '#25241f', 'b': '#44433b'}


def pal_of(suit):
    p = dict(COMMON_PAL); p.update(SUIT_PALETTES[suit])
    return {k: C(v) for k, v in p.items()}


def char_frame(head, torso, legs, pal, bob=0):
    img = new(16, 24)
    stamp(img, 0, bob, head, pal)
    stamp(img, 0, 10 + bob, torso, pal)
    stamp(img, 0, 17, legs, pal)
    return img


def build_player():
    sets = [(FRONT_HEAD, FRONT_TORSO, FRONT_LEGS), (BACK_HEAD, BACK_TORSO, FRONT_LEGS),
            (SIDE_HEAD, SIDE_TORSO, SIDE_LEGS)]
    for head, torso, legs in sets:
        assert all(len(r) == 16 for r in head), head
        for part in (torso, legs):
            for k, rows in part.items():
                assert all(len(r) == 16 for r in rows), (k, rows)
    for suit in SUIT_PALETTES:
        pal = pal_of(suit)
        sheet = new(16 * 7, 24 * 3)
        for row, (head, torso, legs) in enumerate(sets):
            frames = [
                char_frame(head, torso['idle'], legs['stand'], pal),
                char_frame(head, torso['idle'], legs['stepL'], pal, 1),
                char_frame(head, torso['idle'], legs['stand'], pal),
                char_frame(head, torso['idle'], legs['stepR'], pal, 1),
                char_frame(head, torso['idle'], legs['stand'], pal),
                char_frame(head, torso['windup'], legs['stand'], pal, -1),
                char_frame(head, torso['strike'], legs['stand'], pal, 1),
            ]
            for col, fr in enumerate(frames):
                sheet.paste(fr, (col * 16, row * 24))
        save(sheet, f'characters/player/suit_{suit}.png')


# ======================================================================= NPCs
NPC_HEADS = {
    'kolya': [
        "................",
        ".....KKKKKK.....",
        "....KHHHHHHK....",
        "...KHHhHHHHHK...",
        "...KKKKKKKKKKK..",
        "....KSSSSSSK....",
        "....KSKSSKSK....",
        "....KsSSSSsK....",
        "....KSWWWWSK....",
        ".....KSSSSK.....",
    ],
    'oksana': [
        "................",
        ".....KKKKKK.....",
        "....KHHHHHHK....",
        "...KHHHHHHHHK...",
        "...KHSSSSSSHK...",
        "...KHSKSSKSHK...",
        "....KSSSSSSK....",
        "....KsSSSSsK....",
        ".....KSRRSK.....",
        "......KRRK......",
    ],
    'hanna': [
        "................",
        ".....KKKKKK.....",
        "....KHHhHHHK....",
        "...KHhHHHHhHK...",
        "...KHSSSSSSHK...",
        "...KHSKSSKSHK...",
        "...KHSSSSSSHK...",
        "...KHsSWWSsHK...",
        "....KHSSSSHK....",
        "...KHHKKKKHHK...",
    ],
    'abramov': [
        "................",
        ".....KKKKKK.....",
        "....KhSSSShK....",
        "...KhSSSSSShK...",
        "...KSSSSSSSSK...",
        "...KSGGSSGGSK...",
        "....KSSSSSSK....",
        "....KsSSSSsK....",
        ".....KSWWSK.....",
        "......KSSK......",
    ],
}
NPC_LOOKS = {
    'kolya': {'H': '#3a3a36', 'h': '#55554e', 'S': '#c49778', 's': '#a07a60', 'W': '#5a4632', 'R': '#8c2a20',
              'Y': '#4b5233', 'y': '#373c25', 'D': '#272a1a', 'L': '#5f6741', 'Z': '#26281b', 'P': '#3b2a1b',
              'B': '#2a211a', 'b': '#463a2c', 'G': '#cfe0e0', 'F': '#4b5233', 'f': '#373c25'},
    'oksana': {'H': '#5a3b26', 'h': '#6f4a30', 'S': '#d0a487', 's': '#ad8468', 'W': '#5a3b26', 'R': '#b8402e',
               'Y': '#34557a', 'y': '#26405a', 'D': '#1a2c40', 'L': '#4a7297', 'Z': '#c9a227', 'P': '#5a4a32',
               'B': '#25241f', 'b': '#44433b', 'G': '#cfe0e0', 'F': '#34557a', 'f': '#26405a'},
    'hanna': {'H': '#7a2c26', 'h': '#a8463a', 'S': '#cfa58b', 's': '#a8826a', 'W': '#8f7f74', 'R': '#8c2a20',
              'Y': '#3a3530', 'y': '#2a2622', 'D': '#1c1916', 'L': '#4d4640', 'Z': '#6a5f50', 'P': '#7a6a52',
              'B': '#2a211a', 'b': '#463a2c', 'G': '#cfe0e0', 'F': '#3a3530', 'f': '#2a2622'},
    'abramov': {'H': '#7a7870', 'h': '#9a978d', 'S': '#d6ae92', 's': '#b08a70', 'W': '#8a6a5a', 'R': '#8c2a20',
                'Y': '#c9c7bc', 'y': '#9c9a90', 'D': '#6f6d64', 'L': '#e3e1d6', 'Z': '#3a3f4a', 'P': '#3a3f4a',
                'B': '#1e1e22', 'b': '#3a3a40', 'G': '#d8f0f0', 'F': '#c9c7bc', 'f': '#9c9a90'},
}
NPC_TORSO = FRONT_TORSO['idle']


def build_npcs():
    for name, rows in NPC_HEADS.items():
        assert all(len(r) == 16 for r in rows), name
        p = {'K': C('#14120d')}
        p.update({k: C(v) for k, v in NPC_LOOKS[name].items()})
        legs = [r.replace('Y', 'D').replace('L', 'y') for r in FRONT_LEGS['stand']]
        if name == 'hanna':
            legs = ["....KYYYYYyDK...", "....KYYYYYyDK...", "....KYYYYYyDK...", "...KYYYYYYyyDK..",
                    "....KBBBKBBBK...", "....KBbBKBbBK...", "....KKKKKKKKK..."]
        sheet = new(32, 24)
        for i in range(2):
            img = new(16, 24)
            stamp(img, 0, i, rows, p)
            stamp(img, 0, 10 + i, NPC_TORSO, p)
            stamp(img, 0, 17, legs, p)
            if name == 'hanna':
                vline(img, 14, 12, 12, WOOD[1]); px(img, 13, 12, WOOD[1])
            if name == 'abramov':
                rect(img, 12, 14 + i, 3, 4, PAPER[0]); px(img, 13, 13 + i, STEEL[2])
            if name == 'oksana':
                vline(img, 2, 15 + i, 5, STEEL[1]); px(img, 1, 20 + i, STEEL[1]); px(img, 3, 20 + i, STEEL[1])
            sheet.paste(img, (i * 16, 0))
        save(sheet, f'characters/npc/{name}.png')


# ================================================================ FERRAMENTAS
def pickaxe(head, head_light, handle, handle_dark, crude=False, wrap=None):
    img = new(16, 16)
    for i in range(11):
        px(img, 2 + i, 13 - i, handle); px(img, 3 + i, 13 - i, handle_dark)
    if wrap:
        for i in range(2, 5):
            px(img, 2 + i, 13 - i, wrap); px(img, 3 + i, 13 - i, mul(wrap, .7))
    pts = [(6, 2), (7, 2), (8, 2), (9, 3), (10, 3), (11, 4), (12, 5), (12, 6), (13, 7), (13, 8), (14, 10)]
    if crude:
        pts = [(7, 3), (8, 3), (9, 3), (10, 4), (11, 4), (12, 5), (13, 6), (13, 7), (14, 9)]
    for (x, y) in pts:
        px(img, x, y, head); px(img, x, y + 1, mul(head, .7))
        if y < 5:
            px(img, x, y - 1, head_light)
    px(img, 5, 3, head); px(img, 4, 4, mul(head, .7))
    return outline(img)


def drill(body, light, dark, accent):
    img = new(16, 16)
    hline(img, 2, 1, 12, dark); hline(img, 2, 2, 12, light)
    vline(img, 2, 1, 3, dark); vline(img, 13, 1, 3, dark)
    rect(img, 5, 3, 6, 8, body); vline(img, 5, 3, 8, light); vline(img, 10, 3, 8, dark)
    hline(img, 5, 6, 6, accent); hline(img, 5, 8, 6, mul(accent, .7))
    rect(img, 7, 11, 2, 4, STEEL[1]); px(img, 7, 15, STEEL[0]); px(img, 8, 15, STEEL[2])
    rect(img, 11, 4, 2, 2, BLACK)
    return outline(img)


def build_tools():
    d = 'items/tools/'
    save(pickaxe(RUST[1], RUST[0], WOOD[1], WOOD[2], crude=True, wrap=C('#6b6a5e')), d + 'pickaxe_1.png')
    save(pickaxe(STEEL[2], STEEL[1], WOOD[0], WOOD[2]), d + 'pickaxe_2.png')
    save(pickaxe(STEEL[1], STEEL[0], REDS[1], REDS[2], wrap=BLACK), d + 'pickaxe_3.png')
    save(drill(C('#5d676c'), STEEL[1], STEEL[3], HAZ[1]), d + 'drill_1.png')
    save(drill(HAZ[1], HAZ[0], HAZ[2], BLACK), d + 'drill_2.png')


# ===================================================================== ITENS
def chunk(seed, tones, specks=(), w=10, h=8):
    rng = random.Random(seed)
    img = new(16, 16)
    cx, cy = 8, 9
    for y in range(16):
        for x in range(16):
            dx, dy = (x + .5 - cx) / (w / 2), (y + .5 - cy) / (h / 2)
            r = abs(dx) ** 1.6 + abs(dy) ** 1.6 + (vnoise(x, y, 2, seed) - .5) * .35
            if r <= 1:
                lit = -dx * .5 - dy * .8
                img.putpixel((x, y), tones[0] if lit > .45 else (tones[1] if lit > -.25 else tones[2]))
    for cols, n in specks:
        crystals(img, rng.randrange(999), cols, n, 2, (4, 6, 12, 12))
    return outline(img)


def build_items():
    d = 'items/'
    save(chunk(1, [ROCK[0], ROCK[1], ROCK[3]]), d + 'stone.png')
    save(chunk(2, [C('#3d3f45'), C('#1d1d20'), C('#0f0f11')], [((C('#9aa0aa'), C('#3d3f45'), C('#111111')), 3)]), d + 'coal.png')
    save(chunk(3, [C('#9a6243'), C('#7a4a33'), C('#4f2f22')], [((RUST[0], RUST[1], C('#5c2018')), 3)]), d + 'iron_ore.png')
    save(chunk(4, [C('#d08a4a'), C('#a8653a'), C('#6e3f22')], [((C('#8fe0c0'), C('#3fa58a'), C('#2a6e5c')), 3)]), d + 'copper_ore.png')
    save(chunk(5, [C('#8a909b'), C('#53575e'), C('#34373c')], [((C('#eef2f8'), C('#a7adb8'), C('#6c7280')), 3)], 9, 9), d + 'lead_ore.png')
    save(chunk(6, [C('#44463a'), C('#2c2e25'), C('#1a1b15')], [((C('#efff8a'), RADG[1], RADG[3]), 4)]), d + 'uranium_ore.png')
    save(chunk(7, [C('#3a4650'), C('#26303a'), C('#141a20')], [((CYAN[0], CYAN[1], CYAN[2]), 4)], 9, 10), d + 'blue_crystal.png')
    g = new(16, 16)
    rect(g, 3, 5, 10, 7, C('#2b2b2e')); hline(g, 3, 5, 10, C('#4a4a50')); vline(g, 12, 5, 7, C('#18181a'))
    ellipse(g, 8, 8.5, 1.5, 1.5, C('#111111')); px(g, 5, 10, RADG[2]); px(g, 10, 7, RADG[2])
    save(outline(g), d + 'graphite.png')
    s = new(16, 16)
    rect(s, 3, 6, 9, 5, RUST[1]); hline(s, 3, 6, 9, RUST[0]); rect(s, 3, 10, 9, 1, RUST[3])
    line(s, 5, 12, 13, 4, STEEL[2]); line(s, 6, 12, 14, 4, STEEL[3]); px(s, 13, 4, STEEL[0])
    ellipse(s, 7, 8, 1, 1, RUST[3])
    save(outline(s), d + 'scrap.png')
    gear = new(16, 16)
    ellipse(gear, 8, 8, 5, 5, STEEL[2]); ellipse(gear, 8, 8, 4, 4, STEEL[1])
    for a in range(8):
        ang = a / 8 * math.tau
        px(gear, round(8 + math.cos(ang) * 6), round(8 + math.sin(ang) * 6), STEEL[2])
    ellipse(gear, 8, 8, 1.6, 1.6, C('#1e1e1e')); px(gear, 6, 5, STEEL[0])
    save(outline(gear), d + 'mech_parts.png')
    tube = new(16, 16)
    rect(tube, 5, 11, 6, 3, C('#2a2a26')); hline(tube, 5, 11, 6, C('#4a4a42'))
    ellipse(tube, 8, 7, 3, 5, C('#7d9a96')); ellipse(tube, 8, 7, 2, 4, C('#a9c4bd'))
    vline(tube, 8, 4, 6, C('#c8643a')); px(tube, 8, 5, C('#ffb070')); px(tube, 6, 4, C('#e4f4ef'))
    for x in (6, 8, 10):
        px(tube, x, 14, STEEL[1])
    save(outline(tube), d + 'elec_components.png')
    meter = new(16, 16)
    rect(meter, 2, 3, 12, 10, C('#3d4436')); hline(meter, 2, 3, 12, C('#5a6450'))
    ellipse(meter, 8, 8, 4, 3.5, PAPER[0]); line(meter, 8, 10, 11, 6, REDS[1])
    for (x, y) in ((5, 7), (8, 5), (11, 7)):
        px(meter, x, y, BLACK)
    rect(meter, 4, 12, 2, 1, REDS[1]); rect(meter, 10, 12, 2, 1, HAZ[1])
    save(outline(meter), d + 'soviet_components.png')
    can = new(16, 16)
    rect(can, 4, 4, 8, 9, STEEL[1]); hline(can, 4, 4, 8, STEEL[0]); hline(can, 4, 12, 8, STEEL[3])
    rect(can, 4, 6, 8, 5, C('#9a3a2c')); hline(can, 4, 8, 8, PAPER[0])
    save(outline(can), d + 'canned_food.png')
    med = new(16, 16)
    rect(med, 3, 5, 10, 8, C('#3f7a45')); hline(med, 3, 5, 10, C('#5aa060')); rect(med, 6, 3, 4, 2, C('#2a2a26'))
    rect(med, 7, 6, 2, 6, PAPER[0]); rect(med, 5, 8, 6, 2, PAPER[0])
    save(outline(med), d + 'medkit.png')
    bot = new(16, 16)
    rect(bot, 7, 2, 2, 2, C('#2a2a26')); rect(bot, 5, 4, 6, 10, C('#bfd9dc'))
    rect(bot, 5, 8, 6, 6, C('#3f8fbf')); hline(bot, 5, 8, 6, C('#7fc4e8')); vline(bot, 6, 5, 3, C('#f0fbff'))
    rect(bot, 6, 10, 4, 2, HAZ[1])
    save(outline(bot), d + 'decon_solution.png')
    ki = new(16, 16)
    rect(ki, 3, 5, 10, 7, PAPER[0]); hline(ki, 3, 5, 10, C('#f0ead4')); rect(ki, 3, 9, 10, 3, C('#3f6fa0'))
    text(ki, 4, 4, 'КЙ', C('#2a2a2a'), 1)
    ellipse(ki, 11, 13, 1.2, 1, C('#f4f4f0'))
    save(outline(ki), d + 'potassium_iodide.png')
    sm = new(16, 16)
    rect(sm, 7, 1, 2, 3, WOOD[1]); rect(sm, 6, 4, 4, 2, C('#cfe0dc')); rect(sm, 4, 6, 8, 8, C('#cfe0dc'))
    rect(sm, 5, 9, 6, 5, C('#e8e0c0')); vline(sm, 5, 7, 6, C('#ffffff'))
    rect(sm, 5, 8, 6, 2, PAPER[1])
    save(outline(sm), d + 'samogon.png')
    tp = new(16, 16)
    rect(tp, 1, 4, 14, 9, C('#2a2a2a')); hline(tp, 1, 4, 14, C('#4a4a4a'))
    rect(tp, 3, 5, 10, 4, PAPER[0]); hline(tp, 4, 6, 8, REDS[1])
    ellipse(tp, 5.5, 10.5, 1.5, 1.5, C('#8a8a8a')); ellipse(tp, 10.5, 10.5, 1.5, 1.5, C('#8a8a8a'))
    px(tp, 5, 10, BLACK); px(tp, 10, 10, BLACK)
    save(outline(tp), d + 'tape.png')
    hm = new(16, 16)
    ellipse(hm, 8, 9, 6, 4.5, C('#c9a227')); ellipse(hm, 8, 8, 5, 3, C('#e0bf4a'))
    rect(hm, 2, 11, 12, 2, C('#9d7a22'))
    ellipse(hm, 8, 7, 1.6, 1.6, C('#e8f0d0')); px(hm, 8, 7, C('#ffffff'))
    line(hm, 10, 6, 13, 3, REDS[1]); line(hm, 10, 7, 14, 5, REDS[2])
    grime(hm, .4, 21)
    save(outline(hm), d + 'ivan_helmet.png')
    note = new(16, 16)
    rect(note, 3, 2, 10, 12, PAPER[0]); vline(note, 12, 2, 12, PAPER[2]); hline(note, 3, 13, 10, PAPER[2])
    for y in (4, 6, 8, 10):
        hline(note, 4, y, R.randint(5, 8), C('#4a4a5a'))
    save(outline(note), d + 'note.png')


# ===================================================================== PROPS
def P(img, name, do_outline=True):
    if do_outline:
        outline(img)
    save(img, 'environment/props/' + name + '.png')


def pine(colors, seed, dead=False):
    img = new(32, 48)
    rr = random.Random(seed)
    shadow_ellipse(img, 16, 45, 10, 2.5)
    vline(img, 15, 18, 28, WOOD[2]); vline(img, 16, 18, 28, WOOD[3])
    for (y, w) in ((4, 3), (9, 6), (14, 8), (19, 10), (24, 12), (29, 13)):
        for x in range(16 - w, 16 + w):
            for yy in range(y, y + 6):
                if abs(x - 15.5) < w * (yy - y + 2) / 8 and vnoise(x, yy, 3, seed) > (.45 if dead else .25):
                    v = vnoise(x, yy, 2, seed + 1) * .6 + (1 - (x - 4) / 24) * .4
                    px(img, x, yy, ramp(colors, v, x, yy, .4))
    if dead:
        for _ in range(5):
            y = rr.randrange(10, 34)
            line(img, 16, y, 16 + rr.choice([-8, -6, 6, 8]), y - rr.randint(1, 4), WOOD[2])
    return img


def build_props():
    rng = random.Random(7)
    # trailer (vagão de obra) 64x40
    t = new(64, 40)
    shadow_ellipse(t, 32, 37, 30, 3)
    for y in range(4, 16):
        for x in range(2, 62):
            px(t, x, y, ramp([C('#56625f'), C('#6f7c7b'), C('#7d8c8c')], vnoise(x, y, 6, 2) * .8 + (1 - (y - 4) / 12) * .3, x, y))
    hline(t, 2, 4, 60, C('#98a6a5')); hline(t, 2, 15, 60, C('#46514e'))
    for x in range(6, 60, 8):
        vline(t, x, 5, 10, C('#606c6b'))
    for y in range(16, 34):
        for x in range(2, 62):
            px(t, x, y, C('#5a7682') if x % 3 else C('#4e6874'))
    rect(t, 8, 19, 12, 7, C('#1f282c')); rect(t, 9, 20, 10, 5, C('#4f6b68'))
    vline(t, 14, 20, 5, C('#1f282c')); px(t, 10, 21, C('#c9e0d8')); line(t, 15, 21, 18, 24, C('#2a3638'))
    rect(t, 40, 18, 10, 16, C('#3a4a52')); rect(t, 41, 19, 8, 14, C('#465862'))
    px(t, 47, 26, STEEL[0]); rect(t, 38, 34, 14, 3, CONC[2]); hline(t, 38, 34, 14, CONC[1])
    rect(t, 26, 21, 9, 6, PAPER[1]); rect(t, 27, 22, 7, 2, REDS[1])
    rect(t, 2, 34, 60, 2, C('#22221e')); rect(t, 6, 34, 4, 4, BLACK); rect(t, 54, 34, 4, 4, BLACK)
    grime(t, .35, 3, rust=True)
    P(t, 'trailer')
    # terminal de comércio 20x32
    tm = new(20, 32)
    shadow_ellipse(tm, 10, 30, 9, 2)
    rect(tm, 2, 2, 16, 27, C('#545b46')); hline(tm, 2, 2, 16, C('#6f775c')); vline(tm, 17, 2, 27, C('#383d2e'))
    rect(tm, 4, 5, 12, 9, C('#101610')); rect(tm, 5, 6, 10, 7, C('#1b3322'))
    for y in (7, 9, 11):
        hline(tm, 6, y, R.randint(4, 8), C('#7fe08a'))
    rect(tm, 4, 16, 12, 3, C('#2a2d24'))
    for i, x in enumerate((5, 8, 11, 14)):
        px(tm, x, 17, [REDS[1], HAZ[1], C('#7fe08a'), C('#7fe08a')][i])
    rect(tm, 5, 21, 10, 5, C('#454b3b')); hline(tm, 6, 23, 8, BLACK)
    text(tm, 4, 26, 'ЭВМ', C('#2a2d24'))
    grime(tm, .3, 4, rust=True)
    P(tm, 'terminal')
    # chuveiro de descontaminação 24x40
    sh = new(24, 40)
    shadow_ellipse(sh, 12, 37, 11, 2.5)
    rect(sh, 2, 30, 20, 6, CONC[2]); hline(sh, 2, 30, 20, CONC[1])
    for x in range(4, 21, 2):
        px(sh, x, 33, BLACK)
    for x in (3, 20):
        vline(sh, x, 4, 27, STEEL[2]); vline(sh, x + 1, 4, 27, STEEL[3])
    hline(sh, 3, 4, 19, STEEL[1]); hline(sh, 3, 5, 19, STEEL[3])
    rect(sh, 9, 6, 6, 2, STEEL[1]); hline(sh, 9, 8, 6, STEEL[3])
    for x in range(5, 20):
        for y in range(9, 29):
            if (x + y // 3) % 3 == 0:
                px(sh, x, y, (190, 210, 200, 110))
    rect(sh, 6, 12, 12, 2, HAZ[1])
    for x in range(6, 18):
        if (x // 2) % 2:
            px(sh, x, 12, BLACK); px(sh, x, 13, BLACK)
    trefoil(sh, 12, 20, 3, BLACK, HAZ[1])
    grime(sh, .3, 5, rust=True)
    P(sh, 'decon_shower')
    # castelete da mina 64x72
    hf = new(64, 72)
    shadow_ellipse(hf, 32, 69, 30, 3)
    for side in (14, 48):
        top = 32 + (side - 32) // 3
        sgn = 1 if side < 32 else -1
        line(hf, side, 66, top, 8, STEEL[2]); line(hf, side + sgn, 66, top + sgn, 8, STEEL[3])
    for y in range(14, 46, 8):
        span = (y - 8) / 58
        xl = round(26 + (14 - 26) * span); xr = round(37 + (48 - 37) * span)
        hline(hf, xl, y, xr - xl + 1, STEEL[2]); line(hf, xl, y, xr, y + 8, STEEL[3])
    ellipse(hf, 32, 9, 7, 7, STEEL[3]); ellipse(hf, 32, 9, 5, 5, CLEAR)
    for a in range(6):
        ang = a / 6 * math.tau
        line(hf, 32, 9, 32 + math.cos(ang) * 6, 9 + math.sin(ang) * 6, STEEL[2])
    ellipse(hf, 32, 9, 1.5, 1.5, RUST[1])
    px(hf, 32, 1, REDS[0]); px(hf, 32, 2, REDS[2])
    rect(hf, 8, 44, 48, 6, C('#6e5a44')); hline(hf, 8, 44, 48, C('#8a7357'))
    for y in range(50, 66):
        for x in range(10, 54):
            px(hf, x, y, CONC[3] if vnoise(x, y, 4, 9) > .62 else CONC[2])
    rect(hf, 24, 53, 16, 13, C('#0a0908')); rect(hf, 24, 53, 16, 1, C('#2a2620'))
    vline(hf, 23, 53, 13, WOOD[2]); vline(hf, 40, 53, 13, WOOD[2]); hline(hf, 23, 52, 18, WOOD[1])
    for x in range(24, 40):
        if (x // 2) % 2:
            px(hf, x, 51, HAZ[1])
    rect(hf, 12, 54, 9, 7, PAPER[1]); rect(hf, 12, 54, 9, 2, REDS[1]); text(hf, 13, 56, 'СТО', BLACK, 0)
    trefoil(hf, 48, 57, 3, BLACK, HAZ[1])
    grime(hf, .35, 6, rust=True)
    P(hf, 'mine_entrance')
    # placas
    sg = new(16, 24)
    shadow_ellipse(sg, 8, 22, 4, 1.5)
    vline(sg, 7, 8, 14, WOOD[2]); vline(sg, 8, 8, 14, WOOD[3])
    rect(sg, 2, 1, 12, 11, HAZ[1]); hline(sg, 2, 1, 12, HAZ[0]); hline(sg, 2, 11, 12, HAZ[2])
    trefoil(sg, 8, 6, 4, BLACK)
    grime(sg, .35, 7, rust=True)
    P(sg, 'sign_radiation')
    sd = new(16, 24)
    shadow_ellipse(sd, 8, 22, 4, 1.5)
    vline(sd, 7, 9, 13, STEEL[2]); vline(sd, 8, 9, 13, STEEL[3])
    rect(sd, 0, 2, 16, 8, PAPER[0]); rect(sd, 0, 2, 16, 2, REDS[1])
    text(sd, 0, 4, 'СТОП', REDS[2], 1)
    grime(sd, .35, 8, rust=True)
    P(sd, 'sign_danger')
    # barris
    for name, body, sym in (('barrel', RUST[1], False), ('barrel_rad', HAZ[1], True)):
        b = new(16, 16)
        shadow_ellipse(b, 8, 14.5, 6, 1.6)
        for x in range(3, 13):
            vline(b, x, 2, 12, ramp([mul(body, .65), mul(body, .85), body, mul(body, 1.2)], 1 - abs(x - 6) / 6, x, 0, .2))
        ellipse(b, 8, 2.5, 5, 1.5, mul(body, .6)); hline(b, 3, 5, 10, mul(body, .6)); hline(b, 3, 11, 10, mul(body, .6))
        if sym:
            trefoil(b, 8, 8.5, 3, BLACK)
            ellipse(b, 12, 14, 3, 1, RADG[2])
        grime(b, .45, 9 + sym, rust=True)
        P(b, name)
    fb = new(16, 20)
    shadow_ellipse(fb, 8, 18.5, 6, 1.6)
    for x in range(3, 13):
        vline(fb, x, 6, 12, ramp([RUST[3], RUST[2], RUST[1]], 1 - abs(x - 6) / 6, x, 0, .2))
    ellipse(fb, 8, 6, 5, 1.6, C('#1a0a04')); ellipse(fb, 8, 6, 3.5, 1, C('#ff8a30'))
    for (x, y) in ((5, 10), (9, 12), (7, 14), (11, 9)):
        px(fb, x, y, C('#ffb060')); px(fb, x + 1, y, C('#c04010'))
    grime(fb, .4, 11, rust=True)
    P(fb, 'fire_barrel')
    # lâmpadas
    for name, glass, core in (('lamp', C('#ffe3a0'), C('#fff7dd')), ('lamp_red', REDS[0], C('#ffd0c0'))):
        lp = new(16, 16)
        rect(lp, 6, 1, 4, 2, STEEL[3]); ellipse(lp, 8, 6, 3, 3.5, glass); ellipse(lp, 8, 5.5, 1.5, 1.5, core)
        for x in (5, 8, 11):
            vline(lp, x, 3, 6, STEEL[3])
        hline(lp, 5, 9, 7, STEEL[3]); vline(lp, 8, 10, 6, C('#202020'))
        P(lp, name)
    lps = new(16, 40)
    shadow_ellipse(lps, 5, 38, 3, 1.2)
    vline(lps, 4, 4, 34, CONC[2]); vline(lps, 5, 4, 34, CONC[3])
    hline(lps, 5, 4, 7, CONC[2]); px(lps, 5, 5, CONC[3])
    rect(lps, 9, 4, 5, 2, C('#2b2d28')); hline(lps, 10, 6, 3, C('#ffe0a0'))
    grime(lps, .3, 12, rust=True)
    P(lps, 'lamp_post')
    ts = new(16, 24)
    for x in (2, 12):
        rect(ts, x, 4, 2, 19, WOOD[1]); vline(ts, x, 4, 19, WOOD[0])
    rect(ts, 1, 2, 14, 3, WOOD[1]); hline(ts, 1, 2, 14, WOOD[0]); hline(ts, 1, 4, 14, WOOD[3])
    px(ts, 4, 3, STEEL[1]); px(ts, 11, 3, STEEL[1])
    grime(ts, .3, 13)
    P(ts, 'timber_support')
    bt = new(16, 16)
    line(bt, 1, 12, 13, 8, WOOD[1]); line(bt, 1, 13, 13, 9, WOOD[3])
    line(bt, 4, 14, 12, 13, WOOD[2]); line(bt, 3, 10, 6, 6, WOOD[1]); px(bt, 13, 8, WOOD[0])
    P(bt, 'broken_timber')
    fn = new(32, 32)
    shadow_ellipse(fn, 16, 30, 13, 2)
    rect(fn, 2, 2, 28, 26, C('#454a40')); hline(fn, 2, 2, 28, C('#61685a'))
    ellipse(fn, 16, 15, 11, 11, C('#161714'))
    for a in range(5):
        ang = a / 5 * math.tau
        for r in range(2, 10):
            px(fn, round(16 + math.cos(ang + r * .08) * r), round(15 + math.sin(ang + r * .08) * r), C('#7d8478'))
            px(fn, round(16 + math.cos(ang + .25 + r * .08) * r), round(15 + math.sin(ang + .25 + r * .08) * r), C('#5d6359'))
    ellipse(fn, 16, 15, 2, 2, RUST[1])
    for k in range(4, 28, 4):
        hline(fn, 6, k, 20, (30, 30, 28, 120))
    grime(fn, .35, 14, rust=True)
    P(fn, 'fan')
    pp = new(32, 16)
    for y, c in ((4, STEEL[2]), (9, RUST[1])):
        rect(pp, 0, y, 32, 4, c); hline(pp, 0, y, 32, mul(c, 1.3)); hline(pp, 0, y + 3, 32, mul(c, .6))
        for x in (6, 22):
            rect(pp, x, y - 1, 3, 6, mul(c, .8))
    px(pp, 14, 12, C('#7fb5c8')); px(pp, 14, 14, C('#7fb5c8'))
    grime(pp, .3, 15, rust=True)
    P(pp, 'pipes')
    vv = new(16, 16)
    vline(vv, 8, 6, 10, STEEL[2]); vline(vv, 9, 6, 10, STEEL[3])
    ellipse(vv, 8.5, 5, 5, 4, REDS[2]); ellipse(vv, 8.5, 5, 3.6, 2.6, CLEAR)
    line(vv, 4, 5, 13, 5, REDS[1]); line(vv, 8, 1, 8, 9, REDS[1]); ellipse(vv, 8.5, 5, 1.2, 1.2, STEEL[1])
    P(vv, 'valve')
    pm = new(32, 24)
    shadow_ellipse(pm, 16, 22, 14, 2)
    rect(pm, 3, 8, 26, 12, C('#3e5a48')); hline(pm, 3, 8, 26, C('#557a62')); rect(pm, 3, 18, 26, 2, C('#25362b'))
    ellipse(pm, 10, 13, 4, 4, C('#2e4436')); ellipse(pm, 10, 13, 2, 2, STEEL[2])
    rect(pm, 18, 4, 6, 5, STEEL[2]); hline(pm, 18, 4, 6, STEEL[1]); rect(pm, 24, 11, 6, 3, STEEL[3])
    grime(pm, .4, 16, rust=True)
    P(pm, 'pump')
    sv = new(16, 16)
    rect(sv, 3, 6, 10, 8, C('#2a2b26')); hline(sv, 3, 6, 10, C('#4a4b44'))
    for x in range(4, 13, 2):
        vline(sv, x, 7, 6, C('#121310'))
    grime(sv, .4, 17, rust=True)
    P(sv, 'steam_vent')
    eb = new(16, 16)
    rect(eb, 3, 2, 10, 12, C('#79806f')); hline(eb, 3, 2, 10, C('#959c88')); vline(eb, 12, 2, 12, C('#565d4f'))
    rect(eb, 5, 5, 6, 6, HAZ[1]); line(eb, 9, 6, 7, 8, BLACK); line(eb, 7, 8, 9, 8, BLACK); line(eb, 9, 8, 7, 10, BLACK)
    vline(eb, 8, 14, 2, BLACK)
    grime(eb, .4, 18, rust=True)
    P(eb, 'electric_box')
    # cartazes e objetos de parede (memória de 1986)
    ps = new(16, 16)
    rect(ps, 2, 1, 12, 14, PAPER[1]); rect(ps, 2, 1, 12, 5, SOVIET_RED)
    ellipse(ps, 8, 9, 2.6, 2.6, C('#3a3a3a')); rect(ps, 5, 11, 7, 3, C('#3a3a3a'))
    line(ps, 10, 3, 13, 9, SOVIET_GOLD)
    grime(ps, .4, 19)
    for (x, y) in ((13, 14), (12, 14), (13, 13)):
        px(ps, x, y, CLEAR)
    P(ps, 'poster')
    pa = new(16, 16)                                   # "átomo pacífico" (slogan real da época)
    rect(pa, 1, 1, 14, 14, C('#d8c99a')); rect(pa, 1, 10, 14, 5, SOVIET_RED)
    for k in range(3):
        a = k * math.pi / 3
        for st in range(24):
            tt = st / 24 * math.tau
            x = 8 + math.cos(tt) * 5 * math.cos(a) - math.sin(tt) * 1.6 * math.sin(a)
            y = 5.5 + math.cos(tt) * 5 * math.sin(a) + math.sin(tt) * 1.6 * math.cos(a)
            px(pa, round(x), round(y), C('#3a5a9a'))
    ellipse(pa, 8, 5.5, 1, 1, SOVIET_RED)
    text(pa, 2, 10, 'МИР', SOVIET_GOLD, 1)
    grime(pa, .35, 20)
    P(pa, 'poster_atom')
    bn = new(32, 16)
    rect(bn, 1, 2, 30, 10, SOVIET_RED)
    for x in range(1, 31):
        if vnoise(x, 0, 3, 21) > .5:
            px(bn, x, 12, SOVIET_RED)
    text(bn, 4, 5, 'СЛАВА', SOVIET_GOLD, 1)
    hline(bn, 1, 2, 30, mul(SOVIET_RED, 1.25)); hline(bn, 1, 11, 30, mul(SOVIET_RED, .7))
    grime(bn, .3, 22)
    P(bn, 'banner')
    cal = new(16, 16)                                  # calendário ABRIL 1986, dia 26 marcado
    rect(cal, 2, 1, 12, 14, PAPER[0]); rect(cal, 2, 1, 12, 3, SOVIET_RED)
    text(cal, 2, 5, '1986', C('#333333'), 0)
    for i in range(12):
        px(cal, 3 + (i % 6) * 2, 11 + (i // 6) * 2, C('#555555'))
    for (x, y) in ((8, 11), (9, 11), (10, 11), (8, 13), (10, 13), (8, 12), (10, 12), (9, 13)):
        px(cal, x, y, REDS[1])
    grime(cal, .3, 23)
    P(cal, 'calendar')
    ck = new(16, 16)                                   # relógio parado em 01:23
    ellipse(ck, 8, 8, 6, 6, C('#2a2a26')); ellipse(ck, 8, 8, 5, 5, PAPER[0])
    for a in range(12):
        ang = a / 12 * math.tau
        px(ck, round(7.5 + math.cos(ang) * 4.2), round(7.5 + math.sin(ang) * 4.2), C('#555555'))
    line(ck, 8, 8, 8 + math.cos(math.radians(-48.5)) * 2.5, 8 + math.sin(math.radians(-48.5)) * 2.5, BLACK)
    line(ck, 8, 8, 8 + math.cos(math.radians(48)) * 4, 8 + math.sin(math.radians(48)) * 4, BLACK)
    line(ck, 4, 3, 12, 13, alpha(C('#e8e8e0'), 120))
    P(ck, 'clock')
    ph = new(16, 16)
    rect(ph, 4, 3, 8, 10, C('#2f3a33')); hline(ph, 4, 3, 8, C('#455248'))
    ellipse(ph, 8, 9, 2.6, 2.6, C('#cfcab8')); ellipse(ph, 8, 9, 1, 1, C('#2f3a33'))
    rect(ph, 3, 4, 2, 6, BLACK); line(ph, 3, 10, 2, 14, C('#222222'))
    P(ph, 'phone')
    co = new(16, 16)
    hline(co, 1, 2, 14, WOOD[2])
    for x, c in ((3, OLIVE[1]), (9, C('#3a3f4a'))):
        rect(co, x, 3, 5, 10, c); hline(co, x, 3, 5, mul(c, 1.3)); vline(co, x + 2, 4, 9, mul(c, .7))
    P(co, 'coat_hooks')
    pt = new(16, 16)                                   # fotos pregadas do Turno C
    for (x, y) in ((1, 2), (8, 1), (4, 8), (10, 8)):
        rect(pt, x, y, 6, 6, PAPER[0]); rect(pt, x + 1, y + 1, 4, 3, C('#5a5650'))
        px(pt, x + 2, y + 2, C('#a09a90')); px(pt, x + 3, y + 1, C('#a09a90'))
    px(pt, 4, 2, REDS[1]); px(pt, 11, 1, REDS[1])
    P(pt, 'photos')
    ch = new(16, 16)                                   # marcas de giz: dias contados e o código
    chalk = alpha(C('#d8d8cc'), 200)
    for i in range(4):
        vline(ch, 2 + i * 2, 3, 5, chalk)
    line(ch, 1, 7, 9, 4, chalk)
    for i in range(2):
        vline(ch, 11 + i * 2, 3, 5, chalk)
    text(ch, 0, 10, '2604', alpha(C('#d8d8cc'), 180), 1)
    save(ch, 'environment/props/chalk_marks.png')
    ro = new(16, 16)
    hline(ro, 1, 13, 14, WOOD[1]); hline(ro, 1, 14, 14, WOOD[3])
    rect(ro, 3, 5, 10, 8, WOOD[1]); hline(ro, 3, 5, 10, WOOD[0])
    rect(ro, 4, 7, 5, 4, C('#c9b98a')); hline(ro, 4, 9, 5, C('#8a7a5a'))
    ellipse(ro, 11, 9, 1, 1, PAPER[1]); line(ro, 12, 5, 14, 1, STEEL[1])
    P(ro, 'radio_old')
    smv = new(16, 20)
    shadow_ellipse(smv, 8, 18.5, 5, 1.4)
    ellipse(smv, 8, 11, 5, 5, C('#b08a4a')); ellipse(smv, 7, 9.5, 2, 2, C('#e0c080'))
    rect(smv, 6, 15, 5, 3, C('#7a5a2a')); rect(smv, 6, 3, 4, 3, C('#9a7a3a')); px(smv, 13, 12, C('#7a5a2a'))
    grime(smv, .3, 24)
    P(smv, 'samovar')
    # móveis
    dk = new(32, 20)
    shadow_ellipse(dk, 16, 18, 15, 2)
    rect(dk, 1, 4, 30, 8, WOOD[1]); hline(dk, 1, 4, 30, WOOD[0]); rect(dk, 1, 12, 30, 3, WOOD[2])
    for x in (2, 28):
        rect(dk, x, 15, 2, 4, WOOD[3])
    rect(dk, 4, 5, 7, 5, PAPER[0]); rect(dk, 7, 6, 6, 4, PAPER[1]); hline(dk, 8, 7, 4, C('#555555'))
    rect(dk, 20, 5, 7, 4, C('#2b2b2b')); hline(dk, 20, 5, 7, C('#4a4a4a')); ellipse(dk, 23.5, 7, 1.5, 1.2, PAPER[1])
    px(dk, 16, 8, REDS[1])
    grime(dk, .3, 25)
    P(dk, 'desk')
    tb = new(32, 20)
    shadow_ellipse(tb, 16, 18, 15, 2)
    rect(tb, 3, 5, 26, 7, WOOD[1]); hline(tb, 3, 5, 26, WOOD[0]); rect(tb, 3, 12, 26, 2, WOOD[2])
    for x in (4, 26):
        rect(tb, x, 14, 2, 5, WOOD[3])
    for x in (8, 15, 22):
        ellipse(tb, x, 8, 2, 1.2, PAPER[0]); px(tb, x, 8, PAPER[2])
    rect(tb, 12, 6, 2, 3, C('#7a8a90'))
    grime(tb, .3, 26)
    P(tb, 'table')
    bc = new(32, 12)
    shadow_ellipse(bc, 16, 10.5, 15, 1.5)
    rect(bc, 1, 3, 30, 3, WOOD[1]); hline(bc, 1, 3, 30, WOOD[0])
    for x in (3, 27):
        rect(bc, x, 6, 2, 4, WOOD[3])
    P(bc, 'bench')
    hb = new(16, 24)
    shadow_ellipse(hb, 8, 22, 7, 1.6)
    rect(hb, 2, 4, 12, 16, C('#d8d6cc')); rect(hb, 3, 5, 10, 4, PAPER[0])
    for y in (11, 14, 17):
        hline(hb, 2, y, 12, C('#bab6a8'))
    for x in (1, 14):
        vline(hb, x, 2, 20, STEEL[1])
    hline(hb, 1, 2, 14, STEEL[1]); hline(hb, 1, 21, 14, STEEL[2])
    grime(hb, .35, 27, rust=True)
    P(hb, 'hospital_bed')
    lt = new(32, 20)
    shadow_ellipse(lt, 16, 18, 15, 2)
    rect(lt, 1, 6, 30, 7, C('#3f4a44')); hline(lt, 1, 6, 30, C('#5a6a60')); rect(lt, 1, 13, 30, 2, C('#2a332e'))
    for x in (2, 28):
        rect(lt, x, 15, 2, 4, STEEL[3])
    for (x, c) in ((5, C('#7fd0c8')), (10, RADG[1]), (21, C('#d0d8e0'))):
        rect(lt, x, 2, 3, 5, alpha(C('#c8e0e0'), 150)); rect(lt, x, 4, 3, 3, c)
    rect(lt, 14, 3, 5, 4, C('#2a2a2a')); hline(lt, 14, 3, 5, C('#555555')); px(lt, 16, 5, REDS[0])
    P(lt, 'lab_table')
    gc = new(16, 24)
    shadow_ellipse(gc, 8, 22, 6, 1.5)
    rect(gc, 2, 2, 12, 19, STEEL[3]); rect(gc, 3, 3, 10, 17, alpha(C('#b8d0d0'), 150))
    for y in (8, 13):
        hline(gc, 3, y, 10, STEEL[2])
    for (x, y) in ((4, 5), (8, 5), (5, 10), (10, 10), (6, 15)):
        rect(gc, x, y, 2, 3, R.choice([C('#7fd0c8'), RADG[2], C('#c8a060')]))
    P(gc, 'glass_cabinet')
    tmm = new(20, 28)                                  # computador ЭВМ com bobinas de fita magnética
    shadow_ellipse(tmm, 10, 26, 9, 2)
    rect(tmm, 2, 2, 16, 23, C('#8a8a7a')); hline(tmm, 2, 2, 16, C('#a8a898')); vline(tmm, 17, 2, 23, C('#5a5a4c'))
    for cx in (6, 13):
        ellipse(tmm, cx, 7, 3, 3, C('#2a2a26')); ellipse(tmm, cx, 7, 1, 1, C('#8a8a7a'))
    rect(tmm, 4, 12, 12, 7, C('#101610')); rect(tmm, 5, 13, 10, 5, C('#1b3322'))
    hline(tmm, 6, 14, 6, C('#7fe08a')); hline(tmm, 6, 16, 4, C('#7fe08a'))
    for x in range(4, 16, 2):
        px(tmm, x, 21, R.choice([REDS[0], HAZ[1], C('#7fe08a')]))
    text(tmm, 3, 22, 'ЭВМ7', C('#2a2a26'), 0)
    grime(tmm, .3, 28)
    P(tmm, 'terminal_mine')
    fc = new(16, 24)
    shadow_ellipse(fc, 8, 22, 6, 1.5)
    rect(fc, 2, 2, 12, 19, C('#6f7266')); hline(fc, 2, 2, 12, C('#8a8d80'))
    for y in (4, 10, 16):
        rect(fc, 4, y, 8, 4, C('#5d6055')); hline(fc, 6, y + 1, 4, STEEL[0])
    rect(fc, 4, 11, 8, 2, PAPER[0])
    grime(fc, .35, 29, rust=True)
    P(fc, 'file_cabinet')
    ct = new(16, 16)
    shadow_ellipse(ct, 8, 14.5, 7, 1.6)
    rect(ct, 1, 4, 14, 8, RUST[1]); hline(ct, 1, 4, 14, RUST[0]); rect(ct, 2, 5, 12, 3, C('#2a2522'))
    for (x, y) in ((4, 6), (7, 5), (10, 6)):
        px(ct, x, y, ROCK[1])
    for x in (3, 11):
        ellipse(ct, x + 1, 13, 1.6, 1.6, STEEL[3])
    grime(ct, .4, 30, rust=True)
    P(ct, 'minecart')
    # chão
    rb = new(16, 16)
    for _ in range(8):
        x, y = rng.randrange(2, 12), rng.randrange(6, 13)
        c = rng.choice([CONC[1], CONC[2], ROCK[1], ROCK[2]])
        rect(rb, x, y, rng.randint(2, 4), rng.randint(1, 3), c); px(rb, x, y, mul(c, 1.2))
    vline(rb, 9, 3, 6, RUST[2])
    P(rb, 'rubble')
    ty = new(16, 16)
    ellipse(ty, 8, 10, 6, 4, C('#1e1e1c')); ellipse(ty, 8, 9.5, 5, 3, C('#2d2d2a')); ellipse(ty, 8, 10, 2.5, 1.6, CLEAR)
    P(ty, 'tire')
    gm = new(16, 16)
    ellipse(gm, 8, 9, 5, 4, C('#4b504a')); ellipse(gm, 6, 8, 1.5, 1.5, C('#a6cfc0')); ellipse(gm, 10, 8, 1.5, 1.5, C('#a6cfc0'))
    rect(gm, 7, 11, 3, 3, C('#59613f')); px(gm, 8, 12, C('#3b4129'))
    P(gm, 'gasmask')
    hf2 = new(16, 16)
    ellipse(hf2, 8, 10, 6, 3.8, C('#b89a30')); ellipse(hf2, 8, 9, 4.5, 2.4, C('#d0b040'))
    ellipse(hf2, 8, 8, 1.3, 1.1, C('#d8e0c8'))
    grime(hf2, .5, 31)
    P(hf2, 'helmet_floor')
    bo = new(16, 16)
    for x in (3, 9):
        rect(bo, x, 6, 4, 6, C('#25241f')); rect(bo, x, 11, 6, 2, C('#25241f')); hline(bo, x, 6, 4, C('#44433b'))
    P(bo, 'boots')
    dc = new(16, 16)
    for (x, y, a) in ((3, 7, 0), (7, 5, 1), (5, 9, 2)):
        rect(dc, x, y, 7, 5, PAPER[a % 3]); hline(dc, x + 1, y + 2, 5, C('#555555'))
    P(dc, 'documents')
    pr = new(16, 16)
    for y in range(16):
        for x in range(16):
            d = ((x - 8) / 7) ** 2 + ((y - 9) / 4.5) ** 2 + vnoise(x, y, 3, 32) * .3
            if d < 1:
                px(pr, x, y, (90, 200, 60, 150) if d > .55 else (150, 240, 90, 175))
    hline(pr, 5, 8, 3, (220, 255, 170, 200))
    save(pr, 'environment/props/puddle_rad.png')
    pw = new(16, 16)
    for y in range(16):
        for x in range(16):
            d = ((x - 8) / 7) ** 2 + ((y - 9) / 4.5) ** 2 + vnoise(x, y, 3, 33) * .3
            if d < 1:
                px(pw, x, y, alpha(WATER[2], 200) if d > .55 else alpha(WATER[1], 210))
    hline(pw, 5, 8, 3, alpha(WATER[0], 220))
    save(pw, 'environment/props/puddle.png')
    cd = new(32, 16)
    for f in range(2):
        for (x, h) in ((4, 5), (7, 7), (10, 4), (12, 6)):
            rect(cd, f * 16 + x, 14 - h, 2, h, PAPER[0]); px(cd, f * 16 + x + 1, 14 - h, PAPER[2])
            fl = C('#ffd070') if (x + f) % 2 else C('#ffa040')
            px(cd, f * 16 + x, 13 - h - (f + x) % 2, fl); px(cd, f * 16 + x, 12 - h, alpha(C('#ffe0a0'), 150))
        hline(cd, f * 16 + 3, 14, 11, alpha(PAPER[2], 200))
    save(cd, 'environment/props/candles.png')
    fu = new(16, 16)
    for (x, y, r) in ((5, 11, 2), (9, 10, 2.6), (12, 12, 1.6), (7, 13, 1.4)):
        vline(fu, x, y, 3, C('#a0b8a8'))
        ellipse(fu, x, y, r, r * .6, C('#6fe0d0')); px(fu, x, y - 1, C('#d0fff8'))
    P(fu, 'fungus')
    gcy = new(16, 24)
    shadow_ellipse(gcy, 8, 22, 6, 1.5)
    for x, c in ((3, C('#3f6f8f')), (8, C('#3f6f8f'))):
        rect(gcy, x, 5, 5, 16, c); vline(gcy, x, 5, 16, mul(c, 1.3)); ellipse(gcy, x + 2.5, 5, 2.5, 2, mul(c, .85))
        rect(gcy, x + 2, 1, 1, 3, STEEL[2])
    hline(gcy, 3, 12, 10, PAPER[0])
    grime(gcy, .35, 34, rust=True)
    P(gcy, 'gas_cylinders')
    cs = new(16, 16)
    shadow_ellipse(cs, 8, 14.5, 7, 1.6)
    ellipse(cs, 8, 8, 6, 6, WOOD[1]); ellipse(cs, 8, 8, 4.5, 4.5, C('#2b2b2b')); ellipse(cs, 8, 8, 2, 2, WOOD[2])
    P(cs, 'cable_spool')
    pl = new(16, 56)
    shadow_ellipse(pl, 8, 54, 3, 1.4)
    vline(pl, 7, 4, 50, WOOD[1]); vline(pl, 8, 4, 50, WOOD[2])
    hline(pl, 1, 7, 14, WOOD[1]); hline(pl, 1, 8, 14, WOOD[3])
    for x in (2, 7, 13):
        px(pl, x, 6, C('#6aa3a8')); px(pl, x, 5, C('#9fd1d3'))
    P(pl, 'power_pole')
    # veículos
    car = new(48, 32)
    shadow_ellipse(car, 24, 28, 22, 3)
    body, light, dark = C('#5c7568'), C('#77907f'), C('#425547')
    rect(car, 3, 14, 42, 11, body); hline(car, 3, 14, 42, light); rect(car, 3, 23, 42, 2, dark)
    rect(car, 11, 5, 24, 10, body); hline(car, 11, 5, 24, light)
    rect(car, 13, 7, 9, 7, C('#1f2a28')); rect(car, 24, 7, 9, 7, C('#1f2a28'))
    line(car, 14, 8, 20, 12, C('#8fb0a6'))
    rect(car, 4, 17, 5, 3, C('#c9c3a0')); rect(car, 39, 17, 5, 3, REDS[2])
    rect(car, 6, 24, 7, 3, C('#181816')); rect(car, 35, 24, 7, 3, C('#181816'))
    grime(car, .45, 35, rust=True)
    for _ in range(14):
        x = rng.randrange(3, 45); y = rng.randrange(20, 27)
        px(car, x, y, GRASS[rng.randrange(3)]); px(car, x, y - 1, GRASS[1])
    P(car, 'car_wreck')
    bus = new(80, 36)                                  # ônibus abandonado (memória da evacuação)
    shadow_ellipse(bus, 40, 33, 38, 3)
    cream, cream_d, stripe = C('#c9b98a'), C('#9a8c66'), C('#a8463a')
    rect(bus, 2, 6, 76, 22, cream); hline(bus, 2, 6, 76, C('#ddd0a4'))
    rect(bus, 3, 4, 73, 3, cream_d)
    rect(bus, 2, 19, 76, 3, stripe)
    for x in range(8, 70, 9):
        rect(bus, x, 9, 7, 7, C('#1f2a2a')); hline(bus, x, 9, 7, C('#3a4a48'))
        if rng.random() < .4:
            line(bus, x + 1, 10, x + 5, 14, C('#8fb0a6'))
    rect(bus, 70, 9, 6, 15, C('#2a3433'))
    rect(bus, 2, 26, 76, 2, C('#2a2a24'))
    for x in (10, 60):
        ellipse(bus, x, 28, 4, 3, C('#141412')); ellipse(bus, x, 28, 1.5, 1.2, STEEL[3])
    grime(bus, .5, 36, rust=True)
    for _ in range(25):
        x = rng.randrange(2, 78); y = rng.randrange(22, 30)
        px(bus, x, y, GRASS[rng.randrange(3)]); px(bus, x, y - 1, GRASS[2])
    P(bus, 'bus_wreck')
    uz = new(40, 28)                                   # jipe do Instituto
    shadow_ellipse(uz, 20, 25, 18, 2.5)
    rect(uz, 2, 12, 36, 10, C('#4f5a3a')); hline(uz, 2, 12, 36, C('#66724a'))
    rect(uz, 8, 3, 22, 10, C('#5a5a48')); hline(uz, 8, 3, 22, C('#77776a'))
    rect(uz, 10, 6, 8, 6, C('#1f2a28')); rect(uz, 20, 6, 8, 6, C('#1f2a28'))
    rect(uz, 2, 20, 36, 2, C('#3a4329'))
    for x in (8, 32):
        ellipse(uz, x, 22, 3.5, 3, C('#141412')); ellipse(uz, x, 22, 1.4, 1.2, STEEL[3])
    rect(uz, 33, 14, 4, 3, PAPER[1]); text(uz, 13, 14, '7', PAPER[0])
    grime(uz, .35, 37, rust=True)
    P(uz, 'uaz')
    td = new(16, 16)                                   # urso de pelúcia
    ellipse(td, 8, 10, 4, 3.6, C('#8a6a48')); ellipse(td, 8, 5.5, 3, 2.8, C('#9a7a56'))
    ellipse(td, 5.5, 3.5, 1.2, 1.2, C('#8a6a48')); ellipse(td, 10.5, 3.5, 1.2, 1.2, C('#8a6a48'))
    px(td, 7, 5, BLACK); px(td, 9, 5, BLACK); px(td, 8, 7, C('#3a2a1a'))
    ellipse(td, 8, 10.5, 2, 1.6, C('#b8946e'))
    grime(td, .5, 38)
    P(td, 'teddy')
    dl = new(16, 16)                                   # boneca
    ellipse(dl, 8, 4.5, 2.6, 2.6, C('#e8c8b0')); rect(dl, 6, 2, 5, 2, C('#c89a40'))
    px(dl, 7, 5, BLACK); px(dl, 9, 5, BLACK)
    rect(dl, 5, 7, 6, 6, REDS[1]); hline(dl, 5, 12, 6, mul(REDS[1], .7))
    vline(dl, 6, 13, 2, C('#e8c8b0')); vline(dl, 9, 13, 2, C('#e8c8b0'))
    grime(dl, .55, 39)
    P(dl, 'doll')
    # árvores (os pinheiros ruivos lembram a Floresta Vermelha)
    P(pine([C('#2f3a26'), C('#3d4a30'), C('#4d5a36'), C('#5e5a34')], 40), 'tree_pine')
    P(pine([C('#5a2a18'), C('#7a3a1e'), C('#9a4e26'), C('#b8652e')], 41, dead=True), 'tree_red')
    birch = new(24, 44)
    shadow_ellipse(birch, 12, 41, 8, 2)
    rect(birch, 11, 14, 3, 28, PAPER[0]); vline(birch, 13, 14, 28, PAPER[2])
    for y in range(15, 42, 3):
        px(birch, 11 + rng.randrange(3), y, BLACK)
    line(birch, 12, 20, 5, 12, PAPER[1]); line(birch, 13, 18, 19, 10, PAPER[1])
    for y in range(2, 24):
        for x in range(2, 22):
            if (x - 12) ** 2 / 100 + (y - 11) ** 2 / 81 < 1 and vnoise(x, y, 2, 42) > .45:
                px(birch, x, y, ramp([C('#6b7238'), C('#8a8a3e'), C('#a39540'), C('#b88a3a')], vnoise(x, y, 3, 43), x, y, .4))
    P(birch, 'tree_birch')
    bush = new(16, 16)
    shadow_ellipse(bush, 8, 14, 6, 1.6)
    for y in range(4, 15):
        for x in range(2, 15):
            if (x - 8) ** 2 / 36 + (y - 9) ** 2 / 25 < 1 and vnoise(x, y, 2, 44) > .3:
                px(bush, x, y, ramp([GRASS[3], GRASS[2], GRASS[1], C('#7a6a3a')], vnoise(x, y, 3, 45), x, y, .4))
    P(bush, 'bush')
    cb = new(16, 16)
    shadow_ellipse(cb, 8, 14.5, 7, 1.6)
    rect(cb, 1, 6, 14, 8, CONC[2]); rect(cb, 1, 3, 14, 3, CONC[1]); hline(cb, 1, 3, 14, CONC[0])
    vline(cb, 8, 3, 11, CONC[3])
    grime(cb, .4, 46)
    P(cb, 'concrete_blocks')
    # escadas, elevador, plataforma, máquinas
    ld = new(16, 16)
    rect(ld, 1, 1, 14, 14, WOOD[2]); rect(ld, 2, 2, 12, 12, C('#050505'))
    vline(ld, 4, 2, 12, WOOD[1]); vline(ld, 11, 2, 12, WOOD[1])
    for y in (4, 8, 12):
        hline(ld, 4, y, 8, mul(WOOD[1], 1 - y / 20))
    hline(ld, 1, 1, 14, WOOD[0])
    P(ld, 'ladder_down')
    lu = new(16, 32)
    for y in range(0, 6):
        hline(lu, 2, y, 12, (255, 240, 200, 40 + y * 10))
    for x in (3, 12):
        vline(lu, x, 0, 31, WOOD[1]); vline(lu, x + 1, 0, 31, WOOD[2])
    for y in range(3, 31, 4):
        hline(lu, 4, y, 8, WOOD[0]); hline(lu, 4, y + 1, 8, WOOD[3])
    P(lu, 'ladder_up')
    el = new(32, 40)
    shadow_ellipse(el, 16, 38, 14, 2)
    rect(el, 2, 2, 28, 34, C('#24271f'))
    for x in range(2, 31, 4):
        vline(el, x, 2, 34, STEEL[2])
    for y in (2, 18, 35):
        hline(el, 2, y, 28, STEEL[1])
    rect(el, 24, 20, 5, 7, C('#454b3b')); px(el, 26, 22, REDS[0]); px(el, 26, 25, C('#7fe08a'))
    for x in range(2, 30):
        if (x // 3) % 2:
            px(el, x, 36, HAZ[1])
    grime(el, .35, 47, rust=True)
    P(el, 'elevator')
    pd = new(32, 32)
    for y in range(1, 31):
        for x in range(1, 31):
            px(pd, x, y, ramp([CONC[3], CONC[2], CONC[2], CONC[1]], vnoise(x, y, 5, 48), x, y, .5))
    for (x, y) in ((1, 1), (27, 1), (1, 27), (27, 27)):
        for i in range(4):
            px(pd, x + i, y, HAZ[1]); px(pd, x, y + i, HAZ[1])
    hline(pd, 10, 15, 12, HAZ[2]); vline(pd, 15, 10, 12, HAZ[2])
    save(pd, 'environment/props/pad.png')
    gs = new(64, 32)
    for f in range(2):
        g = new(32, 32)
        shadow_ellipse(g, 16, 29, 14, 2.5)
        rect(g, 2, 10, 28, 17, C('#4b6648')); hline(g, 2, 10, 28, C('#66875f')); rect(g, 2, 25, 28, 2, C('#2c3c2a'))
        for x in range(5, 18, 3):
            vline(g, x, 13, 8, C('#30442d'))
        rect(g, 20, 13, 8, 8, C('#272b26')); ellipse(g, 24, 16.5, 2.5, 2.5, PAPER[0]); line(g, 24, 17, 25 + f, 15, REDS[1])
        px(g, 21, 20, C('#7fe08a') if f else C('#2d4a30')); px(g, 23, 20, REDS[0] if not f else C('#5a2a20'))
        rect(g, 6, 3, 3, 8, STEEL[3]); rect(g, 5, 2, 5, 2, STEEL[2])
        grime(g, .4, 49, rust=True)
        outline(g)
        gs.paste(g, (f * 32, 0))
    save(gs, 'environment/props/generator.png')
    ds = new(64, 48)
    for f in range(2):
        dd = new(32, 48)
        shadow_ellipse(dd, 16, 45, 14, 2.5)
        line(dd, 9, 40, 15, 2, HAZ[2]); line(dd, 23, 40, 17, 2, HAZ[2])
        for y in range(8, 38, 6):
            hline(dd, 10 + (38 - y) // 8, y, 12 - (38 - y) // 5, HAZ[1])
        rect(dd, 14, 2, 4, 3, RUST[1])
        rect(dd, 4, 30, 24, 12, HAZ[1]); hline(dd, 4, 30, 24, HAZ[0]); rect(dd, 4, 40, 24, 2, HAZ[3])
        for x in range(4, 28):
            if (x // 2) % 2:
                px(dd, x, 39, BLACK)
        rect(dd, 15, 20 + f * 2, 2, 12, STEEL[1])
        rect(dd, 6, 32, 7, 5, C('#272b26')); px(dd, 8, 34, C('#7fe08a') if f else REDS[0])
        rect(dd, 19, 32, 8, 6, STEEL[3]); hline(dd, 19, 32, 8, STEEL[2])
        grime(dd, .35, 50, rust=True)
        outline(dd)
        ds.paste(dd, (f * 32, 0))
    save(ds, 'environment/props/drill_rig.png')
    rt = new(20, 20)                                   # rádio na mesa (base)
    shadow_ellipse(rt, 10, 18.5, 9, 1.6)
    rect(rt, 1, 9, 18, 3, WOOD[1]); hline(rt, 1, 9, 18, WOOD[0])
    for x in (2, 16):
        rect(rt, x, 12, 2, 6, WOOD[3])
    rect(rt, 4, 2, 12, 7, WOOD[2]); hline(rt, 4, 2, 12, WOOD[1])
    rect(rt, 5, 4, 6, 4, C('#c9b98a')); hline(rt, 5, 6, 6, C('#8a7a5a')); px(rt, 8, 5, REDS[1])
    ellipse(rt, 13, 5.5, 1.3, 1.3, PAPER[1]); line(rt, 15, 2, 18, 0, STEEL[1])
    P(rt, 'radio_table')
    rec = new(16, 16)                                  # gravador do Petrenko
    shadow_ellipse(rec, 8, 14.5, 7, 1.6)
    rect(rec, 1, 9, 14, 4, WOOD[2]); hline(rec, 1, 9, 14, WOOD[1])
    rect(rec, 3, 4, 10, 6, C('#2f2f2c')); hline(rec, 3, 4, 10, C('#4a4a46'))
    ellipse(rec, 6, 6.5, 1.4, 1.4, C('#8a8a86')); ellipse(rec, 10, 6.5, 1.4, 1.4, C('#8a8a86'))
    px(rec, 12, 5, REDS[0])
    P(rec, 'tape_recorder')
    dr = new(48, 40)                                   # porta hermética da Câmara 7
    for y in range(2, 38):
        for x in range(2, 46):
            px(dr, x, y, C('#2c302d') if vnoise(x, y, 6, 51) > .65 else C('#3a3f3c'))
    ellipse(dr, 24, 20, 15, 15, C('#55605a')); ellipse(dr, 24, 20, 13, 13, C('#47504b'))
    ellipse(dr, 24, 20, 6, 6, STEEL[2]); ellipse(dr, 24, 20, 4.5, 4.5, C('#47504b'))
    for a in range(4):
        ang = a / 4 * math.tau + .4
        line(dr, 24, 20, 24 + math.cos(ang) * 6, 20 + math.sin(ang) * 6, STEEL[1])
    text(dr, 6, 5, '7', HAZ[1], 0)
    rect(dr, 36, 14, 6, 9, C('#1a1d1b')); px(dr, 38, 16, CYAN[1]); px(dr, 40, 16, REDS[0])
    for x in range(2, 46):
        px(dr, x, 2, CYAN[1] if x % 3 else CYAN[2])
    grime(dr, .4, 52, rust=True)
    P(dr, 'door_7')


# ======================================================================== UI
def build_ui():
    d = 'ui/'
    p = new(24, 24)
    rect(p, 0, 0, 24, 24, C('#17190f'))
    for y in range(1, 23):
        for x in range(1, 23):
            px(p, x, y, ramp([C('#2a2d23'), C('#30332a'), C('#363a2e')], vnoise(x, y, 6, 60), x, y, .3))
    hline(p, 1, 1, 22, C('#575c47')); vline(p, 1, 1, 22, C('#4a4f3d'))
    hline(p, 1, 22, 22, C('#1f2219')); vline(p, 22, 1, 22, C('#1f2219'))
    line(p, 7, 18, 11, 16, C('#3d4133')); line(p, 14, 6, 17, 5, C('#3d4133'))
    for (x, y) in ((3, 3), (19, 3), (3, 19), (19, 19)):
        px(p, x, y, C('#7b8066')); px(p, x + 1, y + 1, C('#121409')); px(p, x + 1, y, C('#5a5f4a'))
    save(p, d + 'panel.png')
    c = new(24, 24)
    rect(c, 0, 0, 24, 24, C('#16180f')); rect(c, 1, 1, 22, 22, C('#070c08'))
    for y in range(2, 22, 2):
        hline(c, 2, y, 20, C('#0b140d'))
    hline(c, 1, 22, 22, C('#2b352b'))
    save(c, d + 'crt.png')
    s = new(20, 20)
    rect(s, 0, 0, 20, 20, C('#121309')); rect(s, 1, 1, 18, 18, C('#22241b'))
    hline(s, 1, 1, 18, C('#0f1008')); hline(s, 1, 18, 18, C('#383b2c'))
    save(s, d + 'slot.png')
    ss = s.copy()
    for (x, y, dx, dy) in ((0, 0, 1, 1), (19, 0, -1, 1), (0, 19, 1, -1), (19, 19, -1, -1)):
        for i in range(5):
            px(ss, x + dx * i, y, HAZ[0]); px(ss, x, y + dy * i, HAZ[0])
    save(ss, d + 'slot_selected.png')
    for name, top, mid, bot in (('button', '#585e48', '#434836', '#282b20'),
                                ('button_hover', '#788060', '#5a6148', '#313528'),
                                ('button_pressed', '#282b20', '#383c2e', '#585e48'),
                                ('button_disabled', '#383834', '#2a2a27', '#1d1d1a')):
        b = new(16, 12)
        rect(b, 0, 0, 16, 12, C('#101108')); rect(b, 1, 1, 14, 10, C(mid))
        hline(b, 1, 1, 14, C(top)); hline(b, 1, 10, 14, C(bot))
        save(b, d + name + '.png')
    ico = {
        'icon_hp': ["..KK.KK..", ".KRRKRRK.", "KRrRRRRRK", "KRRRRRRRK", ".KRRRRRK.", "..KRRRK..", "...KRK...", "....K....", "........."],
        'icon_energy': ["....KKK..", "...KYYK..", "..KYYK...", ".KYYYYYK.", "..KKYYK..", "...KYK...", "...KK....", "..KK.....", "........."],
        'icon_money': ["..KKKKK..", ".KYYYYYK.", "KYYKKKYYK", "KYYKYYYYK", "KYYKKKYYK", "KYYYYKYYK", ".KYKKKYK.", "..KKKKK..", "........."],
    }
    pal = {'K': C('#14120d'), 'R': REDS[1], 'r': REDS[0], 'Y': HAZ[1]}
    for name, rows in ico.items():
        im = new(9, 9); stamp(im, 0, 0, rows, pal); save(im, d + name + '.png')
    rad = new(9, 9); ellipse(rad, 4.5, 4.5, 4.5, 4.5, HAZ[1]); trefoil(rad, 4.5, 4.5, 4, BLACK); save(rad, d + 'icon_rad.png')
    ic = new(64, 64)
    rect(ic, 0, 0, 64, 64, C('#1d2018')); ellipse(ic, 32, 32, 26, 26, HAZ[1]); trefoil(ic, 32.5, 32.5, 18, BLACK)
    save(ic, d + 'icon.png')
    cur = new(32, 32)
    rows = ["K.......", "KK......", "KYK.....", "KYYK....", "KYYYK...", "KYYYYK..", "KYYKKK..", "KK.KK...", "K...K..."]
    for j, row in enumerate(rows):
        for i, chx in enumerate(row):
            if chx != '.':
                rect(cur, i * 2, j * 2, 2, 2, C('#14120d') if chx == 'K' else HAZ[0])
    save(cur, d + 'cursor.png')
    for name, bands in (('light_bands', 6), ('light_soft', 0)):
        L = new(128, 128)
        for y in range(128):
            for x in range(128):
                dd = math.hypot(x - 63.5, y - 63.5) / 64
                v = max(0.0, 1 - dd) ** 1.4
                if bands:
                    v = math.ceil(v * bands) / bands if v > 0 else 0
                L.putpixel((x, y), (255, 255, 255, int(255 * v)))
        save(L, 'effects/' + name + '.png')
    dot = new(2, 2); rect(dot, 0, 0, 2, 2, C('#ffffff')); save(dot, 'effects/pixel.png')
    rain = new(1, 6)
    for y in range(6):
        px(rain, 0, y, (255, 255, 255, 60 + y * 30))
    save(rain, 'effects/rain.png')
    puff = new(8, 8)
    for y in range(8):
        for x in range(8):
            dd = math.hypot(x - 3.5, y - 3.5) / 4
            if dd < 1:
                puff.putpixel((x, y), (255, 255, 255, int(255 * (1 - dd) ** 1.5)))
    save(puff, 'effects/puff.png')
    sh = new(16, 28)                                   # silhueta (fenômeno)
    rows = ["......KKKK......", ".....KKKKKK.....", ".....KKKKKK.....", ".....KKeKeK.....", "......KKKK......",
            "....KKKKKKKK....", "...KKKKKKKKKK...", "...KKKKKKKKKK...", "..KK.KKKKKK.KK..", "..KK.KKKKKK.KK..",
            "..KK.KKKKKK.KK..", "..K..KKKKKK..K..", ".....KKKKKK.....", ".....KKKKKK.....", ".....KKK.KKK....",
            ".....KK...KK....", ".....KK...KK....", ".....KK...KK....", ".....KK...KK....", "....KKK...KKK..."]
    stamp(sh, 0, 6, rows, {'K': C('#030303', 255), 'e': C('#3a4a40', 255)})
    save(sh, 'effects/shadow_figure.png')
    # tela de título 640x360: céu morto, usina, chaminé listrada, roda-gigante de Pripyat, floresta ruiva
    W, H = 640, 360
    k = W / 480.0
    tt = new(W, H)
    for y in range(H):
        tv = y / H
        col = mix(C('#0c0f12'), C('#3a332c'), min(1, tv * 1.5)) if tv < .66 else mix(C('#3a332c'), C('#100e0c'), (tv - .66) / .34)
        hline(tt, 0, y, W, col)
    rng2 = random.Random(4)
    for _ in range(60):
        y = rng2.randrange(20, int(170 * k)); x = rng2.randrange(-80, W); w = rng2.randint(80, 290)
        hline(tt, x, y, w, alpha(C('#15181a'), rng2.randint(80, 170)))
    ellipse(tt, 350 * k, 160 * k, 30 * k, 30 * k, alpha(C('#6f5a46'), 70))
    sil = C('#120f0c')
    rect(tt, int(250 * k), int(150 * k), int(175 * k), int(64 * k), sil); rect(tt, int(282 * k), int(118 * k), int(74 * k), int(36 * k), sil)
    for x in range(int(286 * k), int(352 * k), 6):
        vline(tt, x, int(122 * k), 3, C('#1d1914'))
    rect(tt, int(382 * k), int(58 * k), int(14 * k), int(100 * k), sil); rect(tt, int(380 * k), int(56 * k), int(18 * k), 4, sil)
    for y in range(int(64 * k), int(150 * k), 14):
        hline(tt, int(382 * k), y, int(14 * k), C('#1e1a15'))
    px(tt, int(389 * k), int(54 * k), REDS[1]); px(tt, int(389 * k), int(53 * k), REDS[0])
    cx, cy, r = 150 * k, 168 * k, 34 * k
    for a in range(0, 360, 2):
        px(tt, cx + math.cos(math.radians(a)) * r, cy + math.sin(math.radians(a)) * r, sil)
    for a in range(0, 360, 30):
        line(tt, cx, cy, cx + math.cos(math.radians(a)) * r, cy + math.sin(math.radians(a)) * r, sil)
        rect(tt, round(cx + math.cos(math.radians(a)) * r) - 2, round(cy + math.sin(math.radians(a)) * r), 6, 5, sil)
    ground = int(226 * k)
    line(tt, cx, cy, cx - 20, ground - 12, sil); line(tt, cx, cy, cx + 20, ground - 12, sil)
    for x in range(0, W, 3):
        h = rng2.randint(12, 50) + (34 if x < 150 or x > 570 else 0)
        col = mix(C('#120f0c'), C('#3a1a10'), min(1, max(0, (x - 400) / 240)))
        for kk in range(h):
            w = max(0, (h - kk) // 4)
            hline(tt, x - w, ground - kk, 2 * w + 1, col)
    rect(tt, 0, ground, W, H - ground, C('#0f0d0b'))
    for x in range(0, W, 18):
        vline(tt, x, ground - 15, 14, C('#0b0a08'))
    hline(tt, 0, ground - 11, W, C('#0b0a08'))
    for x in range(0, W, 48):
        vline(tt, x + 20, ground - 46, 46, C('#0b0a08'))
        line(tt, x + 20, ground - 44, x + 68, ground - 42, alpha(C('#0b0a08'), 200))
    for _ in range(300):
        px(tt, rng2.randrange(W), rng2.randrange(int(200 * k)), alpha(C('#d8d0b0'), rng2.randint(15, 55)))
    save(tt, d + 'title_bg.png')


if __name__ == '__main__':
    build_tiles(); build_rocks(); build_player(); build_npcs(); build_tools()
    build_items(); build_props(); build_ui()
    print('Arte gerada em', ASSETS, '| tiles:', len(tiles))
