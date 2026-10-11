"""Rochas, minérios e contêineres v0.4 (16x16, mesmos nomes de arquivo).

Rocha facetada: a silhueta é dividida em faces (Voronoi); cada face tem uma normal própria
e é iluminada de cima/esquerda numa rampa com hue shift. Minérios entram como cristais
(prisma com face clara, média e escura) ou pepitas embutidas; os radioativos ganham halo.
"""
import math
import random

from PIL import Image

from gen_assets import new, save, C, mix
from polish import hramp, shade, polish_sprite

S = 16
LX, LY, LZ = -0.55, -0.7, 0.45          # direção da luz (cima/esquerda/frente)


def norm3(x, y, z):
    m = math.sqrt(x * x + y * y + z * z) or 1
    return x / m, y / m, z / m


def contact_shadow(img, cx=8, cy=14.6, rx=7.0, ry=1.8, a=115):
    for y in range(S):
        for x in range(S):
            d = ((x + .5 - cx) / rx) ** 2 + ((y + .5 - cy) / ry) ** 2
            if d <= 1 and img.getpixel((x, y))[3] == 0:
                img.putpixel((x, y), (10, 8, 12, int(a * (1 - d * .5))))


def facet_rock(seed, base, w=13, h=11, facets=6, lumpy=.18, spread=0.62, flat_bottom=True):
    rng = random.Random(seed)
    pal = hramp(base, 6, spread)            # 0 = luz ... 5 = sombra profunda
    img = new(S, S)
    contact_shadow(img)
    cx, cy = 8, S - h / 2 - 1.6
    # silhueta
    mask = [[False] * S for _ in range(S)]
    for y in range(S):
        for x in range(S):
            dx, dy = (x + .5 - cx) / (w / 2), (y + .5 - cy) / (h / 2)
            if flat_bottom and dy > 0:
                dy *= 1.25
            ang = math.atan2(dy, dx)
            wob = 1 + lumpy * (math.sin(ang * 3 + seed) * .6 + math.sin(ang * 5 + seed * 2) * .4)
            if dx * dx + dy * dy <= wob * wob * .98:
                mask[y][x] = True
    # faces
    pts = []
    for _ in range(facets):
        pts.append((rng.uniform(cx - w / 2.6, cx + w / 2.6), rng.uniform(cy - h / 2.4, cy + h / 2.6)))
    normals = []
    for (pxx, pyy) in pts:
        nx = (pxx - cx) / (w / 2) * .9 + rng.uniform(-.25, .25)
        ny = (pyy - cy) / (h / 2) * .9 + rng.uniform(-.25, .25) - .15
        normals.append(norm3(nx, ny, .75))
    cell = [[-1] * S for _ in range(S)]
    for y in range(S):
        for x in range(S):
            if mask[y][x]:
                best = min(range(facets), key=lambda k: (x + .5 - pts[k][0]) ** 2 + (y + .5 - pts[k][1]) ** 2)
                cell[y][x] = best
    lv = []
    for (nx, ny, nz) in normals:
        lv.append(nx * LX + ny * LY + nz * LZ)
    lo, hi = min(lv), max(lv)
    for y in range(S):
        for x in range(S):
            k = cell[y][x]
            if k < 0:
                continue
            t = (lv[k] - lo) / ((hi - lo) or 1)
            # borda inferior da silhueta mais escura (oclusão), topo mais claro
            below = y + 1 >= S or not mask[y + 1][x]
            above = y - 1 < 0 or not mask[y - 1][x]
            i = 1 + int(round((1 - t) * 3.0)) + (1 if below else 0) - (1 if above and t > .5 else 0)
            # aresta entre faces: lado de cima clareia, de baixo escurece
            if y > 0 and cell[y - 1][x] not in (-1, k):
                i -= 1
            if y < S - 1 and cell[y + 1][x] not in (-1, k):
                i += 1
            img.putpixel((x, y), pal[max(0, min(5, i))])
    return img, mask, pal


def outline_selout(img):
    """Contorno de 1px (escuro); o polimento depois transforma em sel-out."""
    src = img.copy()
    for y in range(S):
        for x in range(S):
            if src.getpixel((x, y))[3] >= 200:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                xx, yy = x + dx, y + dy
                if 0 <= xx < S and 0 <= yy < S and src.getpixel((xx, yy))[3] >= 200:
                    img.putpixel((x, y), (16, 14, 14, 255))
                    break
    return img


def crystal(img, x, y, cols, h=3, glow=None):
    """Prisma pequeno: coluna clara à esquerda, escura à direita, ponta brilhante."""
    light, mid, dark = cols
    for j in range(h):
        img.putpixel((x, y + j), light if j < h - 1 else mid)
        if x + 1 < S:
            img.putpixel((x + 1, y + j), mid if j < h - 1 else dark)
    if y - 1 >= 0:
        img.putpixel((x, y - 1), mix(light, C('#ffffff'), .35))
    if glow:
        for (gx, gy) in ((x - 1, y), (x - 1, y + 1), (x + 2, y), (x + 2, y + 1), (x, y + h), (x + 1, y + h)):
            if 0 <= gx < S and 0 <= gy < S:
                c = img.getpixel((gx, gy))
                if c[3] >= 200 and c not in cols:
                    img.putpixel((gx, gy), mix(c, glow, .45))


def nugget(img, x, y, cols):
    light, mid, dark = cols
    for (dx, dy, c) in ((0, 0, mid), (1, 0, mid), (0, 1, dark), (1, 1, mid), (2, 1, dark), (1, -1, light)):
        if 0 <= x + dx < S and 0 <= y + dy < S and img.getpixel((x + dx, y + dy))[3] >= 200:
            img.putpixel((x + dx, y + dy), c)
    img.putpixel((x, y), light)


def spots(mask, rng, n, margin=1):
    cand = [(x, y) for y in range(S) for x in range(S)
            if mask[y][x] and all(0 <= x + dx < S and 0 <= y + dy < S and mask[y + dy][x + dx]
                                  for dx in range(-margin, margin + 2) for dy in range(-margin, margin + 3))]
    rng.shuffle(cand)
    out = []
    for c in cand:
        if all(abs(c[0] - o[0]) + abs(c[1] - o[1]) >= 4 for o in out):
            out.append(c)
        if len(out) >= n:
            break
    return out


def finish(img, name):
    img = outline_selout(img)          # polimento/normalização ficam no build_art.py
    save(img, 'environment/rocks/' + name + '.png')


def build():
    rng = random.Random(7)
    stone = '#5f574e'
    for i, (seed, w, h, f) in enumerate(((1, 13, 11, 6), (2, 12, 10, 5), (3, 14, 9, 6))):
        img, _, _ = facet_rock(seed, stone if i != 1 else '#665b4f', w, h, f)
        finish(img, 'stone_%d' % (i + 1))
    img, _, _ = facet_rock(4, '#46403a', 14, 12, 7, .12)
    finish(img, 'stone_dense')
    img, _, _ = facet_rock(5, '#433d38', 13, 11, 7, .22)
    finish(img, 'stone_dense_2')

    # carvão: rocha escura com lâminas negras brilhantes
    img, mask, _ = facet_rock(6, '#33302d', 13, 11, 6)
    for (x, y) in spots(mask, random.Random(6), 4):
        crystal(img, x, y, (C('#8e95a3'), C('#25252b'), C('#121216')), 2)
    finish(img, 'coal')
    # ferro: pepitas avermelhadas oxidadas
    img, mask, _ = facet_rock(7, stone, 13, 11, 6)
    for (x, y) in spots(mask, random.Random(7), 4):
        nugget(img, x, y, (C('#d98a55'), C('#a3502f'), C('#5e2618')))
    finish(img, 'iron')
    # cobre: pepitas cor de cobre + pátina verde
    img, mask, _ = facet_rock(8, stone, 13, 11, 6)
    sp = spots(mask, random.Random(8), 5)
    for i, (x, y) in enumerate(sp):
        if i % 2 == 0:
            nugget(img, x, y, (C('#f0b070'), C('#c07438'), C('#6e3c1c')))
        else:
            nugget(img, x, y, (C('#a8f0d0'), C('#43a88a'), C('#22604e')))
    finish(img, 'copper')
    # chumbo: rocha azulada com cristais cúbicos prateados
    img, mask, _ = facet_rock(10, '#4b5058', 13, 11, 6)
    for (x, y) in spots(mask, random.Random(10), 4):
        crystal(img, x, y, (C('#f0f4fa'), C('#a5acb8'), C('#5d6370')), 2)
    finish(img, 'lead')
    # urânio: rocha escura com cristais verde-amarelos e halo
    img, mask, _ = facet_rock(11, '#363530', 13, 11, 6)
    for (x, y) in spots(mask, random.Random(11), 4):
        crystal(img, x, y, (C('#f4ffa0'), C('#9fe85a'), C('#3f8a2a')), 3, glow=C('#6fd04a'))
    finish(img, 'uranium')
    # veia azul (ficção): cristais longos ciano com halo
    img, mask, _ = facet_rock(13, '#3c3f48', 13, 12, 6)
    for (x, y) in spots(mask, random.Random(13), 3):
        crystal(img, x, y, (C('#e6fbff'), C('#6fd6ff'), C('#2a7ea6')), 4, glow=C('#3fa6d6'))
    finish(img, 'blue_vein')
    # geodo: casca clara, miolo violeta com cristais
    img, mask, _ = facet_rock(14, '#6e6457', 12, 11, 5)
    for y in range(S):
        for x in range(S):
            d = ((x + .5 - 8.5) / 3.6) ** 2 + ((y + .5 - 9.8) / 2.9) ** 2
            if d < 1 and mask[y][x]:
                img.putpixel((x, y), C('#2a2236') if d > .55 else C('#3b2f50'))
    for (x, y) in ((6, 8), (9, 9), (8, 7)):
        crystal(img, x, y, (C('#f6eaff'), C('#bba6dc'), C('#6f5a96')), 2)
    finish(img, 'geode')

    # grafite: blocos do moderador do reator (prismas empilhados)
    img = new(S, S)
    contact_shadow(img)
    gp = hramp('#3a3a40', 5, .8)
    for (x, y) in ((2, 8), (8, 8), (5, 3)):
        for j in range(5):
            for i in range(6):
                c = gp[1] if j == 0 else (gp[3] if i == 5 else gp[2])
                if j == 4:
                    c = gp[4]
                img.putpixel((x + i, y + j), c)
        img.putpixel((x + 2, y + 2), C('#0c0c0e')); img.putpixel((x + 3, y + 2), C('#0c0c0e'))
        img.putpixel((x + 1, y + 1), gp[0])
    img.putpixel((7, 12), C('#6fd04a'))
    finish(img, 'graphite')

    # sucata: chapa, cano e engrenagem enferrujados
    for name, seed in (('scrap', 9), ('scrap_2', 19)):
        r = random.Random(seed)
        img = new(S, S)
        contact_shadow(img)
        for _ in range(5):
            x, y = r.randrange(2, 9), r.randrange(6, 11)
            w, h = r.randint(3, 6), r.randint(2, 3)
            pal = hramp(r.choice(['#a15c35', '#7f4529', '#5e686d', '#565b39']), 4, .8)
            for j in range(h):
                for i in range(w):
                    img.putpixel((x + i, y + j), pal[0] if j == 0 else (pal[3] if j == h - 1 else pal[1 + (i + j) % 2]))
        st = hramp('#8a949a', 4, .9)
        for t in range(10):
            x, y = 3 + t, 11 - t * 6 // 10
            img.putpixel((x, y), st[1]); img.putpixel((x, y + 1), st[3])
        img.putpixel((12, 5), st[0])
        for a in range(0, 360, 45):
            gx, gy = 10 + round(math.cos(math.radians(a)) * 2), 10 + round(math.sin(math.radians(a)) * 2)
            img.putpixel((gx, gy), hramp('#7f4529', 3)[0 if a < 180 else 2])
        img.putpixel((10, 10), C('#120d0a'))
        finish(img, name)

    # caixote de madeira com fitas
    img = new(S, S)
    contact_shadow(img)
    wd = hramp('#7a5c3c', 5, .85)
    for y in range(4, 14):
        for x in range(2, 14):
            g = (y - 4) % 3
            img.putpixel((x, y), wd[1] if g == 0 else (wd[3] if g == 2 else wd[2]))
    for y in range(4, 14):
        img.putpixel((2, y), wd[0]); img.putpixel((13, y), wd[4])
    for t in range(11):
        x, y = 3 + t, 12 - t * 7 // 10
        img.putpixel((x, y), wd[0]); img.putpixel((x, y + 1), wd[3])
    for x in range(2, 14):
        img.putpixel((x, 4), wd[0])
    for (x, y) in ((3, 5), (12, 5), (3, 12), (12, 12)):
        img.putpixel((x, y), C('#9aa2a4'))
    for x in range(5, 9):   # estêncil
        img.putpixel((x, 8), C('#c9b98a'))
    finish(img, 'crate')

    # armário de vestiário
    img = new(S, S)
    contact_shadow(img, ry=1.6)
    ol = hramp('#5d6644', 5, .8)
    for y in range(1, 14):
        for x in range(3, 13):
            img.putpixel((x, y), ol[2] if x != 8 else ol[4])
    for x in range(3, 13):
        img.putpixel((x, 1), ol[0]); img.putpixel((x, 2), ol[1]); img.putpixel((x, 13), ol[4])
    for y in range(1, 14):
        img.putpixel((3, y), ol[1]); img.putpixel((12, y), ol[3])
    for y in (4, 5, 6):
        for x in (4, 5, 6, 9, 10, 11):
            img.putpixel((x, y), ol[4] if y % 2 == 0 else ol[3])
    img.putpixel((7, 8), C('#c8ccd0')); img.putpixel((9, 8), C('#c8ccd0'))
    for x in range(4, 7):
        img.putpixel((x, 10), C('#d8d0b8')); img.putpixel((x, 11), C('#a89f86'))
    img.putpixel((11, 3), C('#7a3a22')); img.putpixel((11, 4), C('#7a3a22'))
    finish(img, 'locker')

    # armário de primeiros socorros
    img = new(S, S)
    contact_shadow(img, ry=1.6)
    wh = hramp('#c4c1b0', 5, .6)
    for y in range(2, 14):
        for x in range(3, 13):
            img.putpixel((x, y), wh[2] if x < 12 else wh[4])
    for x in range(3, 13):
        img.putpixel((x, 2), wh[0]); img.putpixel((x, 13), wh[4])
    for y in range(4, 11):
        img.putpixel((8, y), wh[3])
    gr = hramp('#3f7a45', 3, .7)
    for (x, y) in [(x, y) for x in range(5, 11) for y in range(6, 8)] + [(x, y) for x in range(7, 9) for y in range(4, 10)]:
        img.putpixel((x, y), gr[1])
    img.putpixel((7, 4), gr[0])
    for y in range(6, 12):
        img.putpixel((12, y), mix(wh[4], C('#6b3c22'), .4))
    finish(img, 'medcab')

    # cofre
    img = new(S, S)
    contact_shadow(img, ry=1.8)
    sp = hramp('#4a5246', 5, .8)
    for y in range(3, 14):
        for x in range(2, 14):
            img.putpixel((x, y), sp[2] if x < 13 else sp[4])
    for x in range(2, 14):
        img.putpixel((x, 3), sp[0]); img.putpixel((x, 13), sp[4])
    for y in range(3, 14):
        img.putpixel((2, y), sp[1])
    for y in range(S):
        for x in range(S):
            d = math.hypot(x + .5 - 8, y + .5 - 8.5)
            if d < 2.8:
                img.putpixel((x, y), C('#9aa49a') if d > 1.6 else C('#2a3028'))
    img.putpixel((7, 6), C('#e0e8dc')); img.putpixel((11, 7), C('#9aa2a4')); img.putpixel((11, 8), C('#5e686d'))
    img.putpixel((11, 9), C('#9aa2a4'))
    finish(img, 'safe')
    return True


if __name__ == '__main__':
    build()
    print('rochas v4 ok')
