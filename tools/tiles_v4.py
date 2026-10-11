"""Tiles v0.4: pisos e paredes redesenhados (sem ruído aleatório; formas com volume).

- Rocha em blocos (Voronoi periódico): cada bloco é iluminado de cima (borda clara)
  e tem fenda escura embaixo/à direita — dá relevo em vez de "chuvisco".
- Pisos com manchas grandes e suaves (2-3 tons), pontilhado só nas transições,
  pedrinhas com luz/sombra, rachaduras com borda clara.
- Rampas com hue shift (tools/polish.py).
- 16 tiles de sombra de contato (shade_0..15) para o chão junto às paredes.
Mantém os nomes do atlas antigo (data/tiles/tiles.json é regravado).
"""
import json
import math
import os
import random

from PIL import Image

from gen_assets import new, save, PROJECT, vnoise, C, mix, alpha
from polish import hramp, shade

T = 16
BAYER2 = [[0, 2], [3, 1]]


def px(img, x, y, c):
    img.putpixel((x % T, y % T), c)


def get(img, x, y):
    return img.getpixel((x % T, y % T))


def field(x, y, seed, scales=(8, 4, 2), weights=(.6, .3, .1)):
    v = 0.0
    for s, w in zip(scales, weights):
        v += vnoise(x, y, s, seed + s, T // s) * w
    return v


def quant(v, pal, x, y, soft=0.10):
    """Quantiza v (0..1) na paleta; perto da fronteira usa xadrez 2x2 (transição suave)."""
    n = len(pal)
    f = max(0.0, min(n - 1e-6, v * n))
    i = int(f)
    frac = f - i
    if frac < soft and i > 0 and BAYER2[y % 2][x % 2] < 2:
        i -= 1
    elif frac > 1 - soft and i < n - 1 and BAYER2[y % 2][x % 2] >= 2:
        i += 1
    return pal[i]


def voronoi(seed, n, wrap_y=True, ystretch=1.35):
    rng = random.Random(seed)
    pts = [(rng.uniform(0, T), rng.uniform(0, T), rng.random()) for _ in range(n)]
    cell = [[0] * T for _ in range(T)]
    edge = [[9.0] * T for _ in range(T)]
    for y in range(T):
        for x in range(T):
            ds = []
            for k, (pxx, pyy, _) in enumerate(pts):
                dx = min(abs(x + .5 - pxx), T - abs(x + .5 - pxx))
                dy = min(abs(y + .5 - pyy), T - abs(y + .5 - pyy)) if wrap_y else abs(y + .5 - pyy)
                ds.append((dx * dx + dy * dy * ystretch, k))
            ds.sort()
            cell[y][x] = ds[0][1]
            edge[y][x] = math.sqrt(ds[1][0]) - math.sqrt(ds[0][0])
    return pts, cell, edge


def pebble(img, x, y, pal, size=2, shadow=None):
    """Pedrinha com luz em cima/esquerda e sombra projetada embaixo/direita."""
    shadow = shadow or shade(get(img, x, y + size), -0.55)
    for j in range(size):
        for i in range(size + (1 if size > 1 else 0)):
            if size > 1 and (i, j) in ((0, size - 1), (size, 0)):
                continue
            px(img, x + i, y + j, pal[1] if j == 0 and i < size else pal[2])
    px(img, x, y, pal[0])
    for i in range(1, size + 1):
        px(img, x + i, y + size, shadow)


def crack(img, rng, x, y, length, dark, light, dirs=((1, 0), (1, 1), (0, 1), (1, -1))):
    dx, dy = rng.choice(dirs)
    for _ in range(length):
        px(img, x, y, dark)
        if get(img, x, y + 1) != dark:
            px(img, x, y + 1, light)
        if rng.random() < .35:
            dx, dy = rng.choice(dirs)
        x, y = x + dx, y + dy


# ======================================================================= MINA
FLOOR_P = hramp('#4a4239', 5, 0.75)        # terra batida, castanho-acinzentado
STONE_P = hramp('#5e564d', 4, 0.6)
ROCK_P = hramp('#5d554c', 6, 1.0)
TOP_P = hramp('#211d1a', 3, 0.5)


def t_mine_floor(seed, gravel=False, tint=None, pal=None):
    rng = random.Random(seed)
    pal = pal or FLOOR_P
    img = new(T, T)
    tones = [pal[3], pal[2], pal[2], pal[1]]
    for y in range(T):
        for x in range(T):
            img.putpixel((x, y), quant(field(x, y, seed), tones, x, y))
    # placas de rocha achatadas no chão (bordas sutis)
    _, cell, edge = voronoi(seed + 5, 5)
    for y in range(T):
        for x in range(T):
            if edge[y][x] < 0.7 and cell[y][x] % 2 == 0:
                img.putpixel((x, y), shade(img.getpixel((x, y)), -0.35))
    for _ in range(rng.randint(2, 3) + (6 if gravel else 0)):
        pebble(img, rng.randrange(T), rng.randrange(T), STONE_P if rng.random() < .7 else hramp('#544c43', 4, .6),
               2 if rng.random() < .5 else 1)
    if rng.random() < .55:
        crack(img, rng, rng.randrange(T), rng.randrange(T), rng.randint(4, 8), pal[4], pal[1])
    if tint:   # veios brilhando (zona quente): núcleo claro + halo
        core, glow = tint
        x, y = rng.randrange(T), rng.randrange(T)
        d = rng.choice(((1, 0), (0, 1), (1, 1), (1, -1)))
        path = []
        for _ in range(rng.randint(7, 11)):
            path.append((x % T, y % T))
            if rng.random() < .4:
                d = rng.choice(((1, 0), (0, 1), (1, 1), (1, -1)))
            x, y = x + d[0], y + d[1]
        for (x, y) in path:
            for gx, gy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
                if ((x + gx) % T, (y + gy) % T) not in path:
                    px(img, x + gx, y + gy, mix(get(img, x + gx, y + gy), glow, .28))
        for i, (x, y) in enumerate(path):
            px(img, x, y, core if i % 3 == 1 else glow)
    return img


def t_mine_wet(seed):
    img = t_mine_floor(seed)
    water = hramp('#2e4446', 4, .8)
    for y in range(T):
        for x in range(T):
            d = ((x - 7.5) / 6) ** 2 + ((y - 8) / 4.2) ** 2 + (vnoise(x, y, 4, seed, 4) - .5) * .5
            if d < 1:
                c = water[2] if d > .55 else water[1]
                if d > .85:
                    c = mix(img.getpixel((x, y)), water[2], .55)
                img.putpixel((x, y), c)
    for x in range(4, 9):
        px(img, x, 6, water[0])          # reflexo da luz
    px(img, 10, 10, water[0])
    return img


def t_rail(seed, vertical):
    rng = random.Random(seed)
    img = t_mine_floor(seed, gravel=True)
    wood = hramp('#6a5038', 4, .8)
    steel = hramp('#7d8589', 4, .9)
    for k in range(0, T, 4):
        for a in range(2, 14):
            for b in range(k + 1, k + 3):
                x, y = (a, b) if vertical else (b, a)
                px(img, x, y, wood[1] if b == k + 1 else wood[2])
        # sombra do dormente
        for a in range(2, 14):
            x, y = (a, k + 3) if vertical else (k + 3, a)
            px(img, x, y, shade(get(img, x, y), -0.5))
        if rng.random() < .5:
            x, y = (rng.randrange(3, 13), k + 1) if vertical else (k + 1, rng.randrange(3, 13))
            px(img, x, y, wood[3])
    for off in (4, 11):
        for t in range(T):
            if vertical:
                px(img, off, t, steel[1]); px(img, off + 1, t, steel[2]); px(img, off + 2, t, shade(get(img, off + 2, t), -.45))
            else:
                px(img, t, off, steel[0]); px(img, t, off + 1, steel[2]); px(img, t, off + 2, shade(get(img, t, off + 2), -.45))
        rs = hramp('#8a4f2c', 3, .7)
        for t in range(T):
            if vnoise(t, off, 3, seed + off) > .62:
                if vertical:
                    px(img, off + 1, t, rs[1])
                else:
                    px(img, t, off + 1, rs[1])
    return img


def t_rock_top(seed, base='#211d1a'):
    pal = hramp(base, 3, .22)
    img = new(T, T)
    for y in range(T):
        for x in range(T):
            img.putpixel((x, y), [pal[2], pal[1]][1 if field(x, y, seed, (8, 4), (.8, .2)) > .45 else 0])
    return img


def rock_blocks(img, seed, pal, n=7, y0=0, y1=T):
    """Face de rocha em blocos iluminados de cima."""
    rng = random.Random(seed)
    pts, cell, edge = voronoi(seed, n, wrap_y=False, ystretch=3.2)
    bright = {k: rng.choice([1, 2, 2, 2, 3]) for k in range(n)}
    for y in range(y0, y1):
        for x in range(T):
            k = cell[y][x]
            i = bright[k]
            above = cell[y - 1][x] if y > y0 else -1
            below = cell[y + 1][x] if y < y1 - 1 else -1
            left = cell[y][(x - 1) % T]
            right = cell[y][(x + 1) % T]
            if below != k and below != -1:
                c = pal[min(5, i + 2)]           # fenda (sombra)
            elif right != k and rng.random() < .7:
                c = pal[min(5, i + 1)]
            elif above != k:
                c = pal[max(0, i - 1)]           # borda iluminada
            else:
                # gradiente interno: mais claro em cima do bloco
                ty = pts[k][1]
                c = pal[i] if y < ty + 1 else pal[min(5, i + 1)]
            img.putpixel((x, y), c)


def t_rock_face(seed, glow=False, pal=None):
    pal = pal or ROCK_P
    img = new(T, T)
    rock_blocks(img, seed, pal, n=5)
    # lábio superior (onde a parede encontra o teto) e contato com o chão
    for x in range(T):
        px(img, x, 0, pal[0] if x % 5 else pal[1])
        px(img, x, 1, shade(get(img, x, 1), .2))
        px(img, x, 14, shade(get(img, x, 14), -.45))
        px(img, x, 15, pal[5])
    if glow:
        rng = random.Random(seed)
        core = C('#c8f4ff'); mid = C('#6fd6ff'); halo = C('#2f8fb8')
        x, y = rng.randrange(3, 13), 3
        path = []
        for _ in range(11):
            path.append((x, y))
            x += rng.choice((-1, 0, 1)); y += 1
            if y > 13:
                break
        for (x, y) in path:
            for gx, gy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
                if (x + gx, y + gy) not in path:
                    px(img, x + gx, y + gy, mix(get(img, x + gx, y + gy), halo, .55))
        for i, (x, y) in enumerate(path):
            px(img, x, y, core if i % 3 == 1 else mid)
    return img


def t_rock_planks(seed):
    rng = random.Random(seed)
    img = t_rock_face(seed)
    wood = hramp('#6e5238', 5, .85)
    for y0 in (2, 7, 11):
        h = 4 if y0 < 11 else 3
        for x in range(T):
            for yy in range(y0, y0 + h):
                g = vnoise(x * .5, yy * 3, 2, seed + y0, 8)
                c = wood[1] if yy == y0 else (wood[3] if yy == y0 + h - 1 else (wood[2] if g < .45 else wood[1]))
                px(img, x, yy, c)
        for x in (3, 12):
            px(img, x, y0 + 1, hramp('#9aa2a4', 3)[0]); px(img, x, y0 + 2, shade(wood[2], -.4))
        if rng.random() < .6:   # tábua quebrada mostrando a rocha atrás
            x = rng.randrange(1, 12)
            for i in range(rng.randint(2, 4)):
                px(img, x + i, y0 + 1, ROCK_P[5]); px(img, x + i, y0 + 2, ROCK_P[4])
    post = hramp('#5d4530', 4, .8)
    for y in range(T - 1):
        px(img, 7, y, post[0]); px(img, 8, y, post[1]); px(img, 9, y, post[3])
    return img


# ================================================================ INDUSTRIAL
def t_ind_floor(seed, stripe=False):
    rng = random.Random(seed)
    pal = hramp('#4e4f48', 5, .55)
    img = new(T, T)
    tones = [pal[3], pal[2], pal[2], pal[1]]
    for y in range(T):
        for x in range(T):
            img.putpixel((x, y), quant(field(x, y, seed, (8, 4), (.75, .25)), tones, x, y, .06))
    for i in range(T):        # junta de dilatação (borda da placa)
        px(img, i, 15, pal[4]); px(img, 15, i, pal[4])
        px(img, i, 0, pal[0]); px(img, 0, i, pal[1])
    if stripe:
        haz = hramp('#c99a2e', 3, .6)
        for x in range(T):
            for y in range(11, 15):
                c = haz[1] if ((x + y) // 3) % 2 == 0 else C('#17161a')
                if vnoise(x, y, 2, seed) > .78:   # tinta gasta
                    c = mix(c, pal[2], .6)
                px(img, x, y, c)
            px(img, x, 10, shade(get(img, x, 10), -.3))
    if seed % 2 == 1 and not stripe:      # mancha de óleo (só numa variação, fora do centro)
        ox, oy = rng.choice((3, 12)), rng.choice((4, 11))
        oil = C('#26241f')
        for y in range(T):
            for x in range(T):
                d = ((x - ox) / 3) ** 2 + ((y - oy) / 2) ** 2 + (vnoise(x, y, 2, seed) - .5) * .6
                if d < 1:
                    px(img, x, y, mix(get(img, x, y), oil, .35 if d > .5 else .5))
    elif rng.random() < .6:
        crack(img, rng, rng.randrange(2, 14), rng.randrange(2, 14), rng.randint(3, 6), pal[4], pal[1])
    return img


def t_ind_face(seed):
    rng = random.Random(seed)
    plaster = hramp('#a29c88', 4, .55)
    paint = hramp('#3f5a4b', 4, .7)
    img = new(T, T)
    for y in range(T):
        for x in range(T):
            if y < 9:
                c = quant(field(x, y, seed, (8, 4), (.7, .3)), [plaster[2], plaster[1], plaster[1]], x, y, .05)
            else:
                c = quant(field(x, y, seed + 9, (8, 4), (.7, .3)), [paint[2], paint[1], paint[1]], x, y, .05)
            img.putpixel((x, y), c)
    for x in range(T):
        px(img, x, 8, paint[0]); px(img, x, 9, paint[3])        # faixa da pintura
        px(img, x, 0, plaster[0]); px(img, x, 15, shade(paint[3], -.5)); px(img, x, 14, paint[3])
    for _ in range(rng.randint(1, 2)):                          # tinta descascada mostrando o reboco
        x, y = rng.randrange(14), rng.randrange(10, 13)
        for i in range(rng.randint(2, 3)):
            px(img, x + i, y, plaster[2]); px(img, x + i, y + 1, plaster[3])
        px(img, x - 1, y, paint[0])
    for _ in range(1 if rng.random() < .45 else 0):            # escorrido de ferrugem/umidade
        x = rng.randrange(T)
        y0 = rng.randrange(0, 4)
        for y in range(y0, y0 + rng.randint(5, 11)):
            if y < 14:
                px(img, x, y, mix(get(img, x, y), C('#6b3c22'), .22 + (y - y0) * .015))
    if rng.random() < .5:
        crack(img, rng, rng.randrange(2, 13), 1, rng.randint(4, 7), plaster[3], plaster[0], ((0, 1), (1, 1), (-1, 1)))
    return img


def t_tile_face(seed):
    rng = random.Random(seed)
    tile = hramp('#b7bcae', 4, .5)
    low = hramp('#6f8c7c', 4, .6)
    grout = C('#5a5c55')
    img = new(T, T)
    for y in range(T):
        for x in range(T):
            pal = tile if y < 10 else low
            gx, gy = x % 4, y % 4
            if gx == 3 or gy == 3:
                c = grout if y < 10 else shade(grout, -.3)
            elif gx == 0 and gy == 0:
                c = pal[0]
            elif gx == 2 or gy == 2:
                c = pal[2]
            else:
                c = pal[1]
            img.putpixel((x, y), c)
    for _ in range(rng.randint(1, 2)):                          # azulejo caído
        tx, ty = rng.randrange(4) * 4, rng.randrange(3) * 4
        for j in range(3):
            for i in range(3):
                px(img, tx + i, ty + j, hramp('#575550', 3)[1 if j else 2])
        px(img, tx, ty + 3, shade(grout, -.5))
    for y in range(9, T):                                        # sujeira subindo do chão
        for x in range(T):
            if vnoise(x, y, 2, seed + 4, 8) > 1.05 - (y - 9) * .08:
                px(img, x, y, mix(get(img, x, y), C('#3b3426'), .4))
    for x in range(T):
        px(img, x, 15, C('#23261f'))
    if rng.random() < .6:
        crack(img, rng, rng.randrange(1, 14), rng.randrange(0, 6), rng.randint(4, 8), C('#4a4b44'), tile[0], ((0, 1), (1, 1), (-1, 1)))
    return img


# ===================================================================== BASE
GRASS_P = hramp('#5f6136', 5, .8)
DIRT_P = hramp('#574735', 5, .7)
CONC_P = hramp('#7a776c', 5, .6)
ASPH_P = hramp('#393a36', 4, .5)


def tuft(img, x, y, pal):
    px(img, x, y, pal[3]); px(img, x, y - 1, pal[1]); px(img, x - 1, y - 1, pal[2]); px(img, x + 1, y - 2, pal[0])
    px(img, x + 1, y, pal[4])


def t_grass(seed):
    rng = random.Random(seed)
    img = new(T, T)
    tones = [GRASS_P[3], GRASS_P[2], GRASS_P[2], GRASS_P[1]]
    for y in range(T):
        for x in range(T):
            img.putpixel((x, y), quant(field(x, y, seed), tones, x, y))
    for _ in range(rng.randint(3, 5)):
        tuft(img, rng.randrange(T), rng.randrange(T), hramp(rng.choice(['#7d7a45', '#6f6c3b', '#857a4a']), 5, .8))
    if rng.random() < .3:
        pebble(img, rng.randrange(T), rng.randrange(T), CONC_P, 1)
    return img


def t_dirt(seed):
    rng = random.Random(seed)
    img = new(T, T)
    tones = [DIRT_P[3], DIRT_P[2], DIRT_P[2], DIRT_P[1]]
    for y in range(T):
        for x in range(T):
            img.putpixel((x, y), quant(field(x, y, seed), tones, x, y))
    for _ in range(rng.randint(1, 3)):
        pebble(img, rng.randrange(T), rng.randrange(T), hramp('#77705f', 4, .7), rng.choice((1, 2)))
    if rng.random() < .5:   # marca de pneu/rastro
        y = rng.randrange(3, 13)
        for x in range(T):
            px(img, x, y, DIRT_P[3]); px(img, x, y + 1, DIRT_P[1])
    return img


def t_asphalt(seed):
    rng = random.Random(seed)
    img = new(T, T)
    tones = [ASPH_P[2], ASPH_P[1], ASPH_P[1], ASPH_P[0]]
    for y in range(T):
        for x in range(T):
            img.putpixel((x, y), quant(field(x, y, seed, (8, 4), (.8, .2)), tones, x, y, .05))
    for _ in range(4):
        px(img, rng.randrange(T), rng.randrange(T), shade(ASPH_P[0], .3))
    x, y = rng.randrange(3, 13), rng.randrange(0, 8)
    for _ in range(rng.randint(0, 9) if rng.random() < .6 else 0):   # rachadura com mato
        px(img, x, y, ASPH_P[3]); px(img, x + 1, y, shade(ASPH_P[0], .2))
        if rng.random() < .22:
            px(img, x - 1, y, GRASS_P[2]); px(img, x - 1, y - 1, GRASS_P[1])
        x += rng.choice((-1, 0, 0, 1)); y += 1
        if y >= T:
            break
    return img


def t_concrete(seed, hexa=False):
    rng = random.Random(seed)
    img = new(T, T)
    tones = [CONC_P[3], CONC_P[2], CONC_P[2], CONC_P[1]]
    for y in range(T):
        for x in range(T):
            img.putpixel((x, y), quant(field(x, y, seed, (8, 4), (.75, .25)), tones, x, y, .06))
    if hexa:
        for y in range(T):
            for x in range(T):
                hx = (x + (4 if (y // 8) % 2 else 0)) % 8
                hy = y % 8
                if hy == 7 or hx == 7:
                    px(img, x, y, shade(get(img, x, y), -.32))
                elif (hy == 0 or hx == 0) and (x + y) % 2 == 0:
                    px(img, x, y, shade(get(img, x, y), .18))
    else:
        for i in range(T):
            px(img, i, 15, CONC_P[4]); px(img, 15, i, CONC_P[4]); px(img, i, 0, CONC_P[0]); px(img, 0, i, CONC_P[1])
    if rng.random() < .55:
        ox, oy = rng.randrange(3, 13), rng.randrange(3, 13)
        for y in range(T):
            for x in range(T):
                d = ((x - ox) / 3.5) ** 2 + ((y - oy) / 2.5) ** 2 + (vnoise(x, y, 2, seed) - .5) * .5
                if d < 1:
                    px(img, x, y, shade(get(img, x, y), -.22))
    if rng.random() < .5:
        crack(img, rng, rng.randrange(2, 14), rng.randrange(2, 14), rng.randint(3, 6), CONC_P[4], CONC_P[0])
    return img


def t_puddle(seed):
    img = t_asphalt(seed)
    water = hramp('#40585a', 4, .8)
    for y in range(T):
        for x in range(T):
            d = ((x - 8) / 6.5) ** 2 + ((y - 9) / 4.3) ** 2 + (vnoise(x, y, 4, seed, 4) - .5) * .4
            if d < 1:
                c = water[2] if d < .7 else water[1]
                if d > .9:
                    c = shade(get(img, x, y), -.4)     # borda molhada escura
                px(img, x, y, c)
    for x in range(5, 9):
        px(img, x, 7, water[0])
    px(img, 10, 11, water[0]); px(img, 11, 11, water[1])
    return img


def t_fence_face(seed):
    """Muro soviético de placas com relevo de losangos."""
    img = new(T, T)
    conc = hramp('#8e8a7d', 5, .6)
    for y in range(T):
        for x in range(T):
            img.putpixel((x, y), quant(field(x, y, seed, (8, 4), (.8, .2)), [conc[2], conc[1], conc[1]], x, y, .05))
    for y in range(T):
        for x in range(T):
            lx, ly = x % 8 - 3.5, y % 8 - 3.5
            d = abs(lx) + abs(ly)
            if 2.3 < d < 3.7:
                lit = (lx < 0 and ly < 0) or (lx < 0 and ly > 0 and abs(lx) > abs(ly))
                px(img, x, y, conc[0] if ly < 0 and lx <= 0 else (conc[3] if ly > 0 and lx >= 0 else conc[2 if lit else 1]))
    for y in range(10, T):
        for x in range(T):
            if vnoise(x, y, 2, seed + 3, 8) > 1.0 - (y - 10) * .1:
                px(img, x, y, mix(get(img, x, y), GRASS_P[3], .55))
    rng = random.Random(seed)
    for _ in range(2):
        x = rng.randrange(T)
        for y in range(rng.randrange(1, 6), rng.randrange(9, 14)):
            px(img, x, y, mix(get(img, x, y), C('#5a4630'), .35))
    for x in range(T):
        px(img, x, 15, conc[4])
    return img


def t_fence_top(seed):
    img = new(T, T)
    ground = hramp('#4a4a3c', 3, .5)
    conc = hramp('#8e8a7d', 4, .6)
    for y in range(T):
        for x in range(T):
            img.putpixel((x, y), quant(field(x, y, seed), [ground[2], ground[1], ground[1]], x, y))
    for x in range(T):
        for y in range(5, 11):
            px(img, x, y, conc[1] if y < 10 else conc[3])
        px(img, x, 5, conc[0]); px(img, x, 11, shade(ground[2], -.5))
    return img


def t_water(seed):
    img = new(T, T)
    water = hramp('#3a5555', 4, .7)
    for y in range(T):
        for x in range(T):
            img.putpixel((x, y), quant(field(x, y, seed, (8, 4), (.8, .2)), [water[2], water[1], water[1]], x, y, .05))
    rng = random.Random(seed)
    for _ in range(3):
        x, y = rng.randrange(T), rng.randrange(T)
        for i in range(3):
            px(img, x + i, y, water[0])
        px(img, x + 1, y + 1, water[3])
    return img


# ======================================================== SOMBRA DE CONTATO
def shade_tile(mask):
    """mask: 1 = parede em cima, 2 = à direita, 4 = embaixo, 8 = à esquerda."""
    img = new(T, T)
    col = (8, 6, 12)
    a = [[0] * T for _ in range(T)]
    bands_top = [175, 140, 105, 70, 40, 18]
    bands_side = [130, 80, 40]
    for y in range(T):
        for x in range(T):
            v = 0
            if mask & 1 and y < len(bands_top):
                v = max(v, bands_top[y])
            if mask & 2 and T - 1 - x < len(bands_side):
                v = max(v, bands_side[T - 1 - x])
            if mask & 8 and x < len(bands_side):
                v = max(v, bands_side[x])
            if mask & 4 and T - 1 - y < 2:
                v = max(v, (70, 30)[T - 1 - y])
            a[y][x] = v
    for y in range(T):
        for x in range(T):
            if a[y][x]:
                img.putpixel((x, y), col + (a[y][x],))
    return img


# ===================================================================== ATLAS
def build():
    tiles = []

    def add(name, img, solid=False, occluder=False, slow=False):
        tiles.append((name, img, {'solid': solid, 'occluder': occluder, 'slow': slow}))

    add('grass', t_grass(1)); add('grass2', t_grass(2)); add('grass3', t_grass(3))
    add('dirt', t_dirt(4)); add('dirt2', t_dirt(5))
    add('asphalt', t_asphalt(6)); add('asphalt2', t_asphalt(7))
    add('concrete', t_concrete(8)); add('concrete2', t_concrete(9, hexa=True))
    add('puddle', t_puddle(10), slow=True)
    add('fence_face', t_fence_face(11), solid=True)
    add('fence_top', t_fence_top(12), solid=True, occluder=True)
    add('mine_floor', t_mine_floor(20)); add('mine_floor2', t_mine_floor(21))
    add('mine_floor3', t_mine_floor(22)); add('mine_gravel', t_mine_floor(39, gravel=True))
    add('mine_wet', t_mine_wet(23), slow=True)
    add('rail_h', t_rail(24, False)); add('rail_v', t_rail(25, True))
    hot = hramp('#41483a', 5, .75)
    add('hot_floor', t_mine_floor(26, tint=(C('#c8ff7a'), C('#55b830')), pal=hot))
    add('hot_floor2', t_mine_floor(27, tint=(C('#8fe854'), C('#2f7a22')), pal=hot))
    add('rock_top', t_rock_top(28), solid=True, occluder=True)
    add('rock_top2', t_rock_top(29), solid=True, occluder=True)
    add('rock_face', t_rock_face(30), solid=True)
    add('rock_face2', t_rock_face(31), solid=True)
    add('rock_face_planks', t_rock_planks(40), solid=True)
    add('rock_face_glow', t_rock_face(41, glow=True), solid=True)
    add('ind_floor', t_ind_floor(32)); add('ind_floor2', t_ind_floor(33))
    add('ind_floor_stripe', t_ind_floor(34, stripe=True))
    add('ind_top', t_rock_top(35, '#1b1b19'), solid=True, occluder=True)
    add('ind_face', t_ind_face(36), solid=True)
    add('ind_face2', t_ind_face(37), solid=True)
    add('tile_face', t_tile_face(42), solid=True)
    add('tile_face2', t_tile_face(43), solid=True)
    add('water', t_water(38), slow=True)
    add('void', new(T, T), solid=True)
    for m in range(16):
        add('shade_%d' % m, shade_tile(m))
    cols = 8
    rows = math.ceil(len(tiles) / cols)
    atlas = new(cols * T, rows * T)
    meta = {}
    for i, (name, img, props) in enumerate(tiles):
        cx, cy = i % cols, i // cols
        atlas.paste(img, (cx * T, cy * T))
        meta[name] = dict(coords=[cx, cy], **props)
    save(atlas, 'environment/tiles/tileset.png')
    out = {'_comment': 'Gerado por tools/tiles_v4.py. coords = coluna/linha no atlas de 16px. shade_N = sombra de contato (N = máscara de paredes: 1 cima, 2 direita, 4 baixo, 8 esquerda).',
           'texture': 'res://assets/environment/tiles/tileset.png', 'tile_size': T, 'tiles': meta}
    with open(os.path.join(PROJECT, 'data', 'tiles', 'tiles.json'), 'w', encoding='utf-8') as f:
        json.dump(out, f, indent=1, ensure_ascii=False)
    return len(tiles)


if __name__ == '__main__':
    print('tiles v4:', build())
