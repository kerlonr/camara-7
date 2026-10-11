"""Tela de título v0.4: cena noturna em camadas (parallax) 640x360.

sky      céu de nuvens baixas com lua velada
plant    silhueta da usina: bloco do reator, unidade 4 danificada, chaminé listrada
glow     brilho do reator (camada separada para pulsar no jogo)
mid      roda-gigante de Pripyat, pinheiros ruivos, postes
front    primeiro plano: cerca com arame farpado, placa de radiação, mato seco
figure   o protagonista de costas, olhando a usina
fog      faixa de neblina horizontal sem emenda (rola no jogo)
beam     feixe de holofote (gira no jogo)
"""
import math
import random

from PIL import Image

from gen_assets import new, save, C, mix, vnoise
from polish import hramp, polish_sprite
import charart as ca

W, H = 640, 360
HORIZON = 250
D = 'ui/title/'


def put(img, x, y, c):
    if 0 <= x < img.width and 0 <= y < img.height:
        img.putpixel((int(x), int(y)), c)


def rect(img, x, y, w, h, c):
    for yy in range(int(y), int(y + h)):
        for xx in range(int(x), int(x + w)):
            put(img, xx, yy, c)


def fbm(x, y, s, seed):
    return vnoise(x, y, s, seed) * .55 + vnoise(x, y, s / 2, seed + 1) * .3 + vnoise(x, y, s / 4, seed + 2) * .15


B2 = [[0, 2], [3, 1]]


def sky():
    img = new(W, H)
    top, mid, low = C('#07090d'), C('#141a22'), C('#3a3530')
    for y in range(H):
        t = y / HORIZON
        base = mix(top, mid, min(1, t * 1.4)) if t < .7 else mix(mid, low, min(1, (t - .7) / .3))
        for x in range(W):
            # nuvens baixas em bandas suaves
            n = fbm(x * .6, y * 2.2, 60, 5)
            c = base
            if n > .55:
                c = mix(base, C('#2a2f36'), min(1, (n - .55) * 3) * (0.5 + t * .5))
            elif n < .35 and y < 150:
                c = mix(base, C('#05070a'), .5)
            img.putpixel((x, y), c)
    # lua velada atrás das nuvens
    mx, my = 470, 70
    for y in range(H):
        for x in range(W):
            d = math.hypot(x - mx, y - my)
            if d < 70:
                a = (1 - d / 70) ** 2.2 * .35
                img.putpixel((x, y), mix(img.getpixel((x, y)), C('#8a8a78'), a))
            if d < 13:
                img.putpixel((x, y), mix(C('#b9b49a'), C('#8d8a76'), d / 13 * (.6 + .4 * vnoise(x, y, 4, 9))))
    for x in range(W):                                    # nuvem passando na frente da lua
        for y in range(62, 74):
            if vnoise(x, y * 3, 20, 3) > .5 and abs(x - mx) < 40:
                img.putpixel((x, y), mix(img.getpixel((x, y)), C('#1c2128'), .7))
    rng = random.Random(4)
    for _ in range(70):                                  # estrelas raras entre as nuvens
        x, y = rng.randrange(W), rng.randrange(120)
        if fbm(x * .6, y * 2.2, 60, 5) < .4:
            img.putpixel((x, y), mix(img.getpixel((x, y)), C('#c8ccd8'), rng.uniform(.25, .6)))
    # brilho do horizonte (cidade morta / incêndio distante)
    for y in range(HORIZON - 60, HORIZON + 10):
        for x in range(W):
            k = max(0, 1 - abs(y - HORIZON) / 60) ** 2 * .35
            img.putpixel((x, y), mix(img.getpixel((x, y)), C('#5a3a28'), k))
    return img


def plant():
    """Silhueta da usina com a unidade 4 destruída (simplificada a partir das fotos de 1986)."""
    img = new(W, H)
    sil = C('#0b0c0e')
    edge = C('#2a2522')
    by = HORIZON + 2
    rect(img, 285, by - 34, 340, 34, sil)                  # salão das turbinas
    for x in range(290, 620, 14):                          # janelas apagadas
        rect(img, x, by - 26, 6, 3, C('#101114'))
    rect(img, 360, by - 96, 92, 96, sil)                   # bloco do reator 3
    rect(img, 452, by - 88, 84, 88, sil)                   # bloco do reator 4
    rng = random.Random(26)
    # unidade 4: o topo foi arrancado -> borda serrilhada e vigas tortas
    prof = []
    for x in range(452, 536):
        prof.append(int(14 + 16 * abs(math.sin(x * .11 + 1)) + 9 * abs(math.sin(x * .37)) + rng.randint(0, 3)))
    for i, x in enumerate(range(452, 536)):
        for y in range(by - 88, by - 88 + prof[i]):
            put(img, x, y, (0, 0, 0, 0))
    for (x0, y0, x1, y1) in ((462, -88, 470, -70), (481, -90, 476, -66), (497, -84, 506, -64), (518, -91, 512, -70)):
        steps = 30
        for k in range(steps + 1):
            t = k / steps
            put(img, x0 + (x1 - x0) * t, by + y0 + (y1 - y0) * t, sil)
            put(img, x0 + (x1 - x0) * t + 1, by + y0 + (y1 - y0) * t, sil)
    # chaminé de ventilação listrada com treliça
    cx = 452
    top = by - 205
    for y in range(top, by - 96):
        wdt = 8 if y > by - 140 else 6
        band = ((y - top) // 14) % 2
        col = C('#24151a') if band == 0 else C('#22232a')
        for x in range(cx - wdt // 2, cx + wdt // 2 + 1):
            put(img, x, y, col)
        put(img, cx - wdt // 2 - 1, y, sil)
    for y in range(top + 6, by - 96, 4):
        put(img, cx - 8, y, sil); put(img, cx + 8, y, sil)
        put(img, cx - 7 + (y // 4) % 15, y + 2, sil)
    # torres de transmissão
    for tx in (60, 190, 255):
        for y in range(by - 70, by):
            put(img, tx - (by - y) // 12, y, sil); put(img, tx + (by - y) // 12, y, sil)
        for i in range(-9, 10):
            put(img, tx + i, by - 62, sil); put(img, tx + i * 2 // 3, by - 50, sil)
    for x in range(0, 285):
        sag = int(7 * math.sin(math.pi * ((x % 65) / 65)))
        put(img, x, by - 62 + sag, C('#15161a'))
    # borda lambida pelo brilho do reator
    for x in range(355, 540):
        for y in range(by - 210, by):
            if img.getpixel((x, y))[3] and not img.getpixel((x, y - 1))[3]:
                put(img, x, y, edge)
                if x > 445:
                    put(img, x, y + 1, C('#3a2a22'))
    return img


def glow():
    img = new(W, H)
    cx, cy = 494, HORIZON - 80
    for y in range(H):
        for x in range(W):
            d = math.hypot((x - cx) / 1.5, (y - cy))
            if d < 110:
                a = (1 - d / 110) ** 1.7
                c = mix(C('#ff8a3a'), C('#6fd04a'), max(0, (cy - y) / 90))
                img.putpixel((x, y), c[:3] + (int(225 * a),))
    return img


def mid():
    img = new(W, H)
    sil = C('#121210')
    gy = HORIZON + 14
    # roda-gigante de Pripyat
    cx, cy, r = 150, gy - 70, 52
    for a in range(0, 3600, 4):
        t = math.radians(a / 10)
        put(img, cx + math.cos(t) * r, cy + math.sin(t) * r, sil)
        put(img, cx + math.cos(t) * (r - 3), cy + math.sin(t) * (r - 3), sil)
    for a in range(0, 360, 20):
        t = math.radians(a)
        for k in range(0, r, 1):
            put(img, cx + math.cos(t) * k, cy + math.sin(t) * k, sil)
        gx, gyy = cx + math.cos(t) * r, cy + math.sin(t) * r
        rect(img, gx - 3, gyy + 1, 7, 6, sil)                     # cabines
        put(img, gx - 1, gyy + 2, C('#2a2a28'))
    for i in range(0, 70):
        put(img, cx - i // 3, cy + i, sil); put(img, cx + i // 3, cy + i, sil)
    # pinheiros ruivos (Floresta Vermelha) e pinheiros mortos
    rng = random.Random(9)
    for x in range(-10, W + 10, 7):
        h = rng.randint(24, 58) + (30 if x < 60 or x > 590 else 0)
        if 280 < x < 590:
            h = rng.randint(5, 16)
        red = max(0, min(1, (x - 300) / 300))
        col = mix(C('#141512'), C('#3a1c12'), red * .9)
        for k in range(h):
            w = max(0, (h - k) // 4)
            for xx in range(x - w, x + w + 1):
                if rng.random() < .93:
                    put(img, xx, gy - k, col)
        for k in range(6):
            put(img, x, gy + k - 5, col)
    rect(img, 0, gy, W, H - gy, C('#0e0d0b'))
    return img


def front():
    img = new(W, H)
    gy = HORIZON + 52
    soil = hramp('#15130f', 4, .35)
    for y in range(gy, H):
        for x in range(W):
            v = fbm(x, y * 2, 16, 31)
            img.putpixel((x, y), soil[1] if v > .58 else soil[2])
    rng = random.Random(12)
    for x in range(W):                                        # mato seco contra o céu
        h = int(4 + fbm(x, 0, 6, 8) * 14)
        for k in range(h):
            if rng.random() < .8:
                put(img, x, gy - k, mix(C('#1a1914'), C('#3a3424'), (k / h) * .5))
    # cerca de concreto + arame farpado
    for px_ in range(14, W, 58):
        for y in range(gy - 64, gy + 4):
            put(img, px_, y, C('#191a18')); put(img, px_ + 1, y, C('#22231f')); put(img, px_ + 2, y, C('#121311'))
        put(img, px_ + 3, gy - 64, C('#191a18')); put(img, px_ + 4, gy - 65, C('#191a18'))
    for wire_y in (gy - 58, gy - 44, gy - 30):
        for x in range(W):
            sag = int(3 * math.sin(math.pi * ((x - 14) % 58) / 58))
            put(img, x, wire_y + sag, C('#2a2b2a'))
            if x % 9 == 0:
                put(img, x, wire_y + sag - 1, C('#2a2b2a')); put(img, x + 1, wire_y + sag + 1, C('#2a2b2a'))
    # placa de radiação pendurada (torta)
    sx, sy = 304, gy - 52
    pal = hramp('#b28a2c', 4, .6)
    for j in range(14):
        for i in range(16):
            put(img, sx + i + j // 5, sy + j, pal[1] if j > 0 else pal[0])
    from gen_assets import trefoil
    trefoil(img, sx + 9.5, sy + 7.5, 5, C('#141210'))
    for j in range(14):
        put(img, sx + 15 + j // 5 + 1, sy + j, pal[3])
    for i in range(3):
        put(img, sx + 3 + i * 4, sy + 13, mix(pal[2], C('#5a2a18'), .5))
    return img


def figure():
    """Protagonista de costas (16x32 ampliado 2x) olhando a usina."""
    look = {
        'hood': ca.ramp4('#a07a26'), 'torso': ca.ramp4('#a07a26'), 'arms': ca.ramp4('#a07a26', sh=.7),
        'legs': ca.ramp4('#a07a26'), 'mask': ca.ramp4('#4b5236'), 'filter': ca.ramp4('#4b5236'),
        'boots': ca.ramp4('#3a3026', hi=1.4), 'gloves': ca.ramp4('#2e2e28'), 'belt': C('#201f1a'),
        'pack': ca.ramp4('#3e4131'), 'polish': True,
    }
    spr = ca.render(look, 'up', 'idle', 0)
    big = spr.resize((32, 64), Image.NEAREST)
    # personagem no escuro: só a silhueta e um contorno laranja do brilho do reator (lado direito)
    out = big.copy()
    for y in range(64):
        for x in range(32):
            c = big.getpixel((x, y))
            if c[3]:
                out.putpixel((x, y), mix(c, C('#0c0b0a'), .62)[:3] + (255,))
    for y in range(64):
        for x in range(31, 0, -1):
            if big.getpixel((x, y))[3]:
                out.putpixel((x, y), mix(big.getpixel((x, y)), C('#ff9a4a'), .35)[:3] + (255,))
                break
    return out


def fog():
    img = new(W, 120)
    for y in range(120):
        for x in range(W):
            v = (vnoise(x, y * 3, 40, 51, W // 40) * .6 + vnoise(x, y * 3, 20, 52, W // 20) * .4)
            band = max(0, 1 - abs(y - 60) / 60)
            a = max(0, v - .35) * band * 230
            if a > 4:
                q = int(a // 18) * 18                         # degraus suaves (cara de pixel art)
                img.putpixel((x, y), (150, 156, 152, q))
    return img


def beam():
    img = new(260, 40)
    for y in range(40):
        for x in range(260):
            spread = 2 + x * .07
            d = abs(y - 20) / spread
            if d < 1:
                a = (1 - d) ** 1.5 * (1 - x / 260) ** .8 * 60
                img.putpixel((x, y), (230, 235, 210, int(a)))
    return img


def crow():
    """Corvo voando, 4 quadros de 9x6 (asas em cima, meio, embaixo, meio)."""
    out = new(36, 6)
    k = C('#08080a')
    frames = [
        ["X.......X", ".X.....X.", "..XXXXX..", "...XXX...", "....X....", "........."],
        [".........", "XX.....XX", "..XXXXX..", "...XXX...", "....X....", "........."],
        [".........", ".........", "XXXXXXXXX", "X..XXX..X", "....X....", "........."],
        [".........", "XX.....XX", "..XXXXX..", "...XXX...", "....X....", "........."],
    ]
    for i, fr in enumerate(frames):
        for y, row in enumerate(fr):
            for x, ch in enumerate(row):
                if ch == 'X':
                    out.putpixel((i * 9 + x, y), k)
    return out


def windows():
    """Janelas acesas no salão das turbinas e no bloco 3 (as unidades 1–3 seguiram operando após 1986)."""
    img = new(W, H)
    by = HORIZON + 2
    rng = random.Random(77)
    warm = C('#f0b45a')
    for x in range(290, 620, 14):
        if rng.random() < .35:
            rect(img, x, by - 26, 6, 3, warm[:3] + (rng.randint(150, 230),))
    for y in range(by - 90, by - 40, 9):
        for x in range(366, 446, 10):
            if rng.random() < .18:
                rect(img, x, y, 3, 4, warm[:3] + (rng.randint(110, 200),))
    return img


def build():
    save(sky(), D + 'sky.png')
    save(plant(), D + 'plant.png')
    save(glow(), D + 'glow.png')
    save(mid(), D + 'mid.png')
    save(front(), D + 'front.png')
    save(figure(), D + 'figure.png')
    save(fog(), D + 'fog.png')
    save(beam(), D + 'beam.png')
    save(crow(), D + 'crow.png')
    save(windows(), D + 'windows.png')


if __name__ == '__main__':
    build()
    print('título v4 ok')
