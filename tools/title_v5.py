"""Tela de título v0.6 — "26 de abril de 1986, 01:30".

Cena em camadas, desenhada em escala 1 (sem ampliação fracionária: pixel sempre inteiro).
Área da cena 800x420; a tela mostra uma janela dela (640x360 ou 480x270) com parallax.

sky.png      céu de nuvens baixas iluminadas de baixo pelo incêndio; estrelas raras
beam.png     coluna de luz azulada de ar ionizado sobre o reator (relatada por testemunhas)
city.png     Pripyat ao longe: prédios com janelas ainda acesas, roda-gigante
plant.png    usina: salão das turbinas, blocos 3 e 4 (4 destruído), chaminé VT-2 listrada
fire.png     focos de incêndio (3 quadros) no teto do bloco 3 e do salão das turbinas
mid.png      torres de transmissão e Floresta Vermelha
front.png    primeiro plano: terra, mato seco, cerca de arame farpado, placa de radiação, poça com reflexo
hero.png     protagonista em silhueta, de costas, contorno iluminado (2 quadros: respiração)
heli.png     helicóptero Mi-8 em silhueta (2 quadros de rotor)
smoke.png    baforadas de fumaça (4 variações) para partículas
logo.png     logotipo desgastado
"""
import math
import random

from PIL import Image, ImageDraw, ImageFont

from gen_assets import new, save, C, mix, vnoise

W, H = 800, 420
HORIZON = 300
REACTOR = (586, 228)          # topo do bloco 4 (origem da coluna de luz)
D = 'ui/title5/'
B4 = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]


def put(img, x, y, c):
    if 0 <= x < img.width and 0 <= y < img.height:
        img.putpixel((int(x), int(y)), c)


def rect(img, x, y, w, h, c):
    for yy in range(int(y), int(y + h)):
        for xx in range(int(x), int(x + w)):
            put(img, xx, yy, c)


def fbm(x, y, s, seed, oct_=3):
    v, a, t = 0.0, 0.55, 0.0
    for i in range(oct_):
        v += vnoise(x, y, s / (2 ** i), seed + i) * a
        t += a
        a *= 0.5
    return v / t


def dpal(v, pal, x, y):
    """Escolhe na paleta com pontilhado ordenado (gradiente com cara de pixel art)."""
    n = len(pal)
    f = max(0.0, min(n - 1e-6, v * n + (B4[y % 4][x % 4] / 16.0 - 0.5) * 0.9))
    return pal[int(f)]


# ======================================================================= céu
def sky():
    img = new(W, H)
    rng = random.Random(1986)
    base = [C('#04050a'), C('#070a12'), C('#0b0f18'), C('#11141c'), C('#1a1719'), C('#2a1d18'), C('#3d2418')]
    lit = [C('#2a1a14'), C('#4a2616'), C('#6e3518'), C('#93481c')]
    cold = [C('#1c2a33'), C('#2c4250'), C('#45667a')]
    for y in range(H):
        for x in range(W):
            t = y / HORIZON
            v = min(1.0, t ** 1.6)
            c = dpal(v, base, x, y)
            # nuvens baixas em faixas
            n = fbm(x * .55, y * 1.9, 70, 7)
            dx = (x - REACTOR[0]) / 260
            dy = (y - REACTOR[1]) / 170
            glow = max(0.0, 1 - math.sqrt(dx * dx + dy * dy))
            if n > .52 and y < HORIZON:
                k = min(1.0, (n - .52) * 4)
                if glow > .05:
                    c = dpal(min(.999, glow * 1.15 * k), lit, x, y)
                else:
                    c = dpal(.15 + .3 * k * t, base[:4], x, y)
            elif glow > .25 and y < HORIZON:
                c = mix(c, lit[1], (glow - .25) * .6)
            # nuvens tocadas pela coluna de luz (base das nuvens, logo acima do reator)
            bx = abs(x - REACTOR[0]) / 70
            if bx < 1 and y < REACTOR[1]:
                k = (1 - bx) ** 2.2 * max(0.0, 1 - abs(y - 110) / 120)
                if n > .46:
                    k *= 1.0 + (n - .46) * 3
                else:
                    k *= .35
                if k > .08:
                    c = mix(c, dpal(min(.999, k), cold, x, y), min(1.0, k * 1.3))
            img.putpixel((x, y), c)
    # estrelas raras nos vãos do lado esquerdo
    for _ in range(90):
        x, y = rng.randrange(0, 420), rng.randrange(0, 150)
        if fbm(x * .55, y * 1.9, 70, 7) < .45:
            img.putpixel((x, y), mix(img.getpixel((x, y)), C('#c8d0e0'), rng.uniform(.3, .75)))
    return img


def beam():
    """Coluna de luz (camada aditiva). Mais forte e estreita na base, abrindo e sumindo no alto."""
    bw, bh = 70, REACTOR[1] + 4
    img = new(bw, bh)
    for y in range(bh):
        t = 1 - y / bh                         # 0 na base, 1 no alto
        half = 2.5 + t * 9
        cx = bw / 2 + math.sin(y * .045) * 1.5 * t
        for x in range(bw):
            d = abs(x + .5 - cx) / half
            if d < 1:
                core = (1 - d) ** 1.8
                a = core * (1 - t) ** .6 * 210 + (60 if d < .25 else 0) * (1 - t)
                a = int(min(255, a))
                q = (a // 24) * 24                   # degraus de alfa (pixel art)
                if q > 0:
                    col = (205, 228, 255) if d < .3 else (140, 180, 225)
                    img.putpixel((x, y), col + (q,))
    return img


# ===================================================================== cidade
def city():
    img = new(W, H)
    rng = random.Random(77)
    sil = C('#0a0c12')
    edge = C('#141822')
    win = [C('#d8a85a'), C('#b98642'), C('#e8c47a'), C('#8a6a3a')]
    gy = HORIZON + 2
    blocks = [(150, 70, 34), (192, 52, 46), (238, 64, 30), (270, 40, 58), (316, 58, 40), (356, 30, 26), (390, 46, 36)]
    for (x, h, w) in blocks:
        rect(img, x, gy - h, w, h, sil)
        rect(img, x, gy - h, w, 1, edge)
        for wy in range(gy - h + 4, gy - 4, 4):
            for wx in range(x + 2, x + w - 2, 3):
                if rng.random() < .16:
                    put(img, wx, wy, rng.choice(win))
    # emblema no topo de um prédio (como os prédios altos de Pripyat)
    for i in range(7):
        put(img, 280 + i, gy - 42, C('#3a1412'))
    put(img, 283, gy - 44, C('#4a1814')); put(img, 283, gy - 43, C('#4a1814'))
    # roda-gigante do parque de diversões (nunca chegou a funcionar para o público)
    cx, cy, r = 120, gy - 46, 30
    for a in range(0, 3600, 3):
        t = math.radians(a / 10)
        put(img, cx + math.cos(t) * r, cy + math.sin(t) * r, sil)
    for a in range(0, 360, 24):
        t = math.radians(a)
        for k in range(r):
            if k % 2 == 0:
                put(img, cx + math.cos(t) * k, cy + math.sin(t) * k, sil)
        gx, gy2 = cx + math.cos(t) * r, cy + math.sin(t) * r
        rect(img, gx - 2, gy2 + 1, 4, 3, sil)
    for i in range(48):
        put(img, cx - i // 3, cy + i, sil); put(img, cx + i // 3, cy + i, sil)
    return img


# ===================================================================== usina
def plant():
    img = new(W, H)
    sil = C('#08090c')
    rim_f = C('#5a2a16')       # borda iluminada pelo fogo
    rim_b = C('#2e4656')       # borda iluminada pela coluna de luz
    gy = HORIZON + 2
    rect(img, 410, gy - 34, 370, 34, sil)                      # salão das turbinas
    for x in range(416, 776, 12):
        rect(img, x, gy - 26, 7, 2, C('#0e1014'))
    rect(img, 500, gy - 92, 70, 92, sil)                       # bloco 3
    for x in range(503, 568, 6):                               # nervuras de concreto
        for y in range(gy - 88, gy - 2):
            put(img, x, y, C('#0d0f13'))
    for y in range(gy - 80, gy - 40, 10):                      # janelas de serviço apagadas (uma acesa)
        for x in range(506, 566, 9):
            rect(img, x, y, 3, 2, C('#0f1116'))
    rect(img, 542, gy - 60, 3, 2, C('#6a4a22'))
    rect(img, 506, gy - 98, 14, 6, sil); rect(img, 530, gy - 96, 8, 4, sil)   # casas de máquinas no teto
    rect(img, 410, gy - 38, 370, 4, sil)                       # platibanda do salão das turbinas
    for x in range(420, 776, 22):
        rect(img, x, gy - 42, 6, 4, sil)                       # exaustores
    rect(img, 570, gy - 74, 66, 74, sil)                       # bloco 4 (destruído)
    rng = random.Random(26)
    prof = []
    for x in range(570, 636):
        prof.append(int(8 + 14 * abs(math.sin(x * .13 + .5)) + 7 * abs(math.sin(x * .41)) + rng.randint(0, 3)))
    for i, x in enumerate(range(570, 636)):
        for y in range(gy - 74, gy - 74 + prof[i]):
            put(img, x, y, (0, 0, 0, 0))
    for (x0, y0, x1, y1) in ((578, -76, 584, -60), (596, -80, 590, -58), (613, -77, 620, -57), (628, -79, 624, -64)):
        n = 26
        for k in range(n + 1):
            t = k / n
            put(img, x0 + (x1 - x0) * t, gy + y0 + (y1 - y0) * t, sil)
    # chaminé VT-2 entre os blocos 3 e 4, com faixas e treliça
    cx, top = 572, gy - 200
    for y in range(top, gy - 92):
        w = 4 if y < gy - 160 else 5
        band = ((y - top) // 11) % 2
        col = C('#2a1214') if band == 0 else C('#1c1d22')
        for x in range(cx - w // 2, cx + w // 2 + 1):
            put(img, x, y, col)
    for y in range(top + 6, gy - 92):
        put(img, cx - 6, y, sil); put(img, cx + 6, y, sil)        # montantes da treliça
        if (y - top) % 6 == 0:
            for k in range(-6, 7):
                put(img, cx + k, y, sil)                        # travessas
    for k in range(4):
        rect(img, cx - 9, top + 20 + k * 22, 19, 1, sil)            # plataformas
    # bordas iluminadas: fogo (laranja) à direita/topo, coluna de luz (azul) em cima do bloco 3
    src = img.copy()
    for y in range(1, H):
        for x in range(1, W - 1):
            if src.getpixel((x, y))[3] and not src.getpixel((x, y - 1))[3]:
                d = math.hypot(x - REACTOR[0], y - REACTOR[1])
                if d < 140:
                    put(img, x, y, rim_f if x > REACTOR[0] - 30 else rim_b)
    # brilho do núcleo exposto dentro da unidade 4
    for x in range(574, 632):
        for y in range(gy - 64, gy - 50):
            if src.getpixel((x, y))[3] == 0 and rng.random() < .55:
                put(img, x, y, rng.choice([C('#7a2a10'), C('#a8401a'), C('#d8702a')]))
    return img


def fire_frames():
    out = new(W * 3, H)
    gy = HORIZON + 2
    spots = [(512, gy - 93, 5), (530, gy - 93, 3), (548, gy - 93, 4), (440, gy - 35, 3), (470, gy - 35, 4),
             (604, gy - 66, 6), (590, gy - 62, 4), (622, gy - 64, 5), (700, gy - 35, 3)]
    pal = [C('#fff0a0'), C('#ffc040'), C('#ff7a20'), C('#c03a10'), C('#6a1e0a')]
    for f in range(3):
        rng = random.Random(f * 31 + 5)
        for (x, y, h) in spots:
            hh = h + rng.randint(-1, 2)
            for k in range(hh):
                w = max(1, int((hh - k) / 2))
                for i in range(-w, w + 1):
                    if rng.random() < .85 - k * .05:
                        c = pal[min(4, int(k / hh * 3) + (1 if abs(i) == w else 0))]
                        put(out, f * W + x + i + rng.choice((0, 0, 1, -1)) * (k > 1), y - k, c)
    return out


# ================================================================ meio
def mid():
    img = new(W, H)
    sil = C('#0b0c0d')
    gy = HORIZON + 10
    # torres de transmissão levando energia para o oeste
    for tx in (120, 230, 330):
        top = gy - 70
        for y in range(top, gy):
            spread = (y - top) // 9
            put(img, tx - 1 - spread, y, sil); put(img, tx + 1 + spread, y, sil)
            if (y - top) % 9 == 0:
                for i in range(-spread - 1, spread + 2):
                    put(img, tx + i, y, sil)
        for i in range(-12, 13):
            put(img, tx + i, top + 6, sil); put(img, tx + i * 2 // 3, top + 16, sil)
    for x0, x1 in ((0, 120), (120, 230), (230, 330), (330, 420)):
        for x in range(x0, x1):
            t = (x - x0) / (x1 - x0)
            put(img, x, gy - 64 + int(8 * math.sin(math.pi * t)), C('#14161a'))
    # Floresta Vermelha e pinheiros mortos
    rng = random.Random(9)
    for x in range(-8, W + 8, 5):
        h = rng.randint(14, 40) + (22 if x > 660 else 0)
        if 380 < x < 660:
            if rng.random() < .55:
                continue
            h = rng.randint(2, 9)
        red = max(0.0, min(1.0, (x - 560) / 200))
        col = mix(C('#0c0d0c'), C('#3a160e'), red)
        for k in range(h):
            w = max(0, (h - k) // 5)
            for xx in range(x - w, x + w + 1):
                if rng.random() < .9:
                    put(img, xx, gy - k, col)
    rect(img, 0, gy, W, H - gy, C('#09090a'))
    return img


# ============================================================ primeiro plano
def front():
    img = new(W, H)
    gy = HORIZON + 46
    soil = [C('#0a0909'), C('#100e0d'), C('#161311'), C('#1d1915')]
    for y in range(gy, H):
        for x in range(W):
            v = fbm(x * 1.2, y * 3, 22, 31, 2) * (0.5 + 0.5 * (1 - (y - gy) / (H - gy)))
            img.putpixel((x, y), dpal(v * .9, soil, x, y))
    rng = random.Random(12)
    for x in range(W):                                   # mato seco contra o brilho
        h = int(3 + fbm(x * 1.5, 0, 9, 8, 2) * 15)
        for k in range(h):
            if rng.random() < .78:
                put(img, x + (1 if k > h * .6 and x % 3 == 0 else 0), gy - k, mix(C('#0c0b0a'), C('#2e2418'), (k / h) * .5))
    # poça refletindo a coluna de luz e o fogo
    for y in range(gy + 18, gy + 28):
        for x in range(470, 560):
            d = ((x - 515) / 45) ** 2 + ((y - gy - 23) / 5) ** 2
            if d < 1:
                img.putpixel((x, y), C('#0e1418') if d > .6 else C('#121c22'))
    for x in range(484, 548):                                  # reflexo do brilho do incêndio
        k = 1 - abs(x - 516) / 32
        if k > 0 and (x * 7) % 5 != 0:
            put(img, x, gy + 22, mix(C('#121c22'), C('#7a4420'), k * .7))
    for y in range(gy + 20, gy + 27):                           # reflexo da coluna de luz
        if y % 2 == 0:
            put(img, 516, y, C('#4a6a80')); put(img, 517, y, C('#3a5466'))
    # cerca de concreto + arame farpado (mais perto, à esquerda e ao centro)
    posts = list(range(6, 470, 64))
    for px_ in posts:
        lean = rng.choice((-1, 0, 0, 1))
        for y in range(gy - 58, gy + 4):
            k = (gy - y) // 30 * lean
            put(img, px_ + k, y, C('#121311')); put(img, px_ + 1 + k, y, C('#1a1b18')); put(img, px_ + 2 + k, y, C('#0c0d0b'))
        put(img, px_ + 3, gy - 58, C('#121311'))
    for wy in (gy - 52, gy - 38, gy - 24):
        for x in range(0, 470):
            sag = int(3 * math.sin(math.pi * ((x - 6) % 64) / 64))
            put(img, x, wy + sag, C('#24251f'))
            if x % 8 == 0:
                put(img, x, wy + sag - 1, C('#2e2f28')); put(img, x + 1, wy + sag + 1, C('#2e2f28'))
    # arame arrebentado pendurado depois da última estaca
    for i in range(18):
        put(img, 470 + i, gy - 38 + i // 2, C('#24251f'))
    # placa de radiação torta presa no arame
    sx, sy = 236, gy - 50
    plate = [C('#c9a030'), C('#9a7a22'), C('#6a5418')]
    for j in range(15):
        for i in range(17):
            put(img, sx + i + j // 6, sy + j, plate[0] if j < 2 else (plate[2] if j > 12 else plate[1]))
    from gen_assets import trefoil
    trefoil(img, sx + 10, sy + 8, 5.4, C('#120f0b'))
    for (x, y) in ((sx + 3, sy + 11), (sx + 14, sy + 3), (sx + 8, sy + 13)):
        put(img, x, y, C('#5a2a18'))
    return img


# ===================================================================== herói
def hero():
    """Protagonista 56x108 de costas, olhando a usina: capuz do traje caindo sobre os ombros,
    alça da bolsa da máscara, picareta no ombro direito, lampião na mão esquerda.
    Silhueta escura com volume e contorno de luz (fogo à direita, coluna azul por cima)."""
    hw, hh = 56, 108
    out = new(hw * 2, hh)
    lamp = new(hw * 2, hh)
    for f in range(2):
        b = 1 if f == 1 else 0
        m = Image.new('L', (hw, hh), 0)
        d = ImageDraw.Draw(m)
        # capuz do traje (arredondado, com leve bico da costura) descendo até os ombros
        d.ellipse([19, 5 + b, 37, 25 + b], fill=255)
        d.polygon([(27, 3 + b), (30, 5 + b), (24, 6 + b)], fill=255)
        # capuz descendo em curva até os ombros caídos, tronco e cintura
        d.polygon([(21, 20 + b), (35, 20 + b), (39, 25 + b), (44, 30 + b), (46, 35 + b), (45, 42), (43, 66),
                   (14, 66), (11, 42), (10, 35 + b), (12, 30 + b), (17, 25 + b)], fill=255)
        # braço esquerdo solto ao lado do corpo, com vão de luz entre braço e tronco
        d.polygon([(8, 33 + b), (13, 33 + b), (12, 52), (11, 68), (7, 69), (6, 52)], fill=255)
        # braço direito dobrado para cima segurando o cabo da picareta
        d.polygon([(42, 32 + b), (48, 33 + b), (50, 44), (48, 50), (44, 48), (44, 40)], fill=255)
        d.ellipse([45, 34, 51, 40], fill=255)                                     # mão
        # quadril/casaco e pernas separadas
        d.polygon([(14, 64), (43, 64), (44, 72), (13, 72)], fill=255)
        d.polygon([(15, 71), (27, 71), (26, 100), (16, 100)], fill=255)
        d.polygon([(30, 71), (42, 71), (41, 100), (31, 100)], fill=255)
        d.rectangle([14, 99, 27, 104], fill=255)
        d.rectangle([30, 99, 43, 104], fill=255)
        # lampião pendurado na mão esquerda
        d.line([(9, 69), (9, 72)], fill=255, width=1)
        d.rectangle([6, 72, 12, 81], fill=255)
        # picareta: cabo da mão até acima do ombro; cabeça com duas pontas
        d.line([(48, 38), (40, 4)], fill=255, width=2)
        d.line([(29, 9), (35, 5), (41, 3), (47, 3), (53, 6)], fill=255, width=2)
        # vão de luz entre braço esquerdo e corpo (desenhado depois para garantir o recorte)
        d.line([(13, 42), (13, 62)], fill=0, width=1)
        img = new(hw, hh)
        mp = m.load()
        for y in range(hh):
            for x in range(hw):
                if mp[x, y] <= 128:
                    continue
                # volume: mais claro perto da borda direita (fogo) e do topo (coluna)
                dr = 0
                for k in range(1, 6):
                    if x + k >= hw or mp[x + k, y] <= 128:
                        dr = 6 - k
                        break
                c = mix(C('#08070a'), C('#1e1412'), dr / 6 * .8)
                if y < 30 and (y == 0 or mp[x, y - 1] <= 128 or (y > 1 and mp[x, y - 2] <= 128)):
                    c = mix(c, C('#33475a'), .6)
                img.putpixel((x, y), c)
        # contorno de luz
        for y in range(hh):
            for x in range(hw):
                if mp[x, y] <= 128:
                    continue
                r = x + 1 >= hw or mp[x + 1, y] <= 128
                t = y == 0 or mp[x, y - 1] <= 128
                l = x == 0 or mp[x - 1, y] <= 128
                if r:
                    img.putpixel((x, y), C('#e07a34') if y < 66 else C('#8a4220'))
                elif t:
                    img.putpixel((x, y), C('#7ea6c4') if x > 18 else C('#4a6a82'))
                elif l and 30 < y < 96:
                    img.putpixel((x, y), C('#3a2216'))
        # dobras e detalhes internos
        for (x0, y0, x1, y1) in ((21, 19, 35, 19), (40, 32, 16, 60), (21, 74, 21, 98), (36, 74, 36, 98), (16, 66, 41, 66)):
            n = max(abs(x1 - x0), abs(y1 - y0), 1)
            for i in range(n + 1):
                px, py = x0 + (x1 - x0) * i // n, y0 + (y1 - y0) * i // n
                if img.getpixel((px, py))[3]:
                    img.putpixel((px, py), C('#151216'))          # costura do capuz, alça diagonal, vincos
        for (x, y) in ((22, 38), (23, 39), (24, 40)):
            put(img, x, y + b, C('#1e1a1c'))                     # fivela da alça
        rect(img, 14, 56, 7, 8, C('#0c0b0d')); put(img, 20, 57, C('#4a2a18'))   # bolsa da máscara (GP-5)
        put(img, 53, 6, C('#ffd08a')); put(img, 52, 5, C('#e07a34'))           # brilho na ponta da picareta
        put(img, 33, 66, C('#5adc3a'))                                         # dosímetro no cinto
        # vidro do lampião aceso (separado para piscar no jogo)
        for y in range(74, 80):
            for x in range(7, 11):
                img.putpixel((x, y), C('#ffcf7a') if (x + y) % 3 else C('#ffeab0'))
        out.paste(img, (f * hw, 0))
    return out


def heli():
    out = new(68, 16)
    for f in range(2):
        img = new(34, 16)
        s = C('#060708')
        rect(img, 8, 7, 16, 5, s); rect(img, 6, 8, 3, 3, s)        # cabine
        rect(img, 23, 8, 9, 2, s); rect(img, 31, 5, 2, 5, s)       # cauda
        rect(img, 10, 12, 1, 2, s); rect(img, 20, 12, 1, 2, s); rect(img, 9, 14, 13, 1, s)   # esquis
        rect(img, 15, 5, 3, 2, s)
        if f == 0:
            rect(img, 1, 4, 32, 1, s)
        else:
            rect(img, 6, 4, 22, 1, s); put(img, 3, 3, s); put(img, 30, 5, s)
        put(img, 7, 9, C('#ff3a20'))                                 # luz de navegação
        out.paste(img, (f * 34, 0))
    return out


def smoke():
    out = new(4 * 40, 28)
    for k in range(4):
        rng = random.Random(k + 3)
        for y in range(28):
            for x in range(40):
                d = ((x - 20) / 19) ** 2 + ((y - 14) / 13) ** 2
                n = vnoise(x + k * 50, y, 6, 40 + k)
                if d + (n - .5) * .7 < 1:
                    v = int((1 - d) * 4)
                    a = [70, 110, 150, 185, 200][max(0, min(4, v))]
                    if B4[y % 4][x % 4] / 16 < .25 and v < 2:
                        continue
                    shade = 18 + int((y / 28) * 22)
                    out.putpixel((k * 40 + x, y), (shade + 6, shade + 2, shade, a))
    return out


# ===================================================================== logo
def logo():
    big = ImageFont.truetype('C:/Windows/Fonts/impact.ttf', 50)
    small = ImageFont.truetype('C:/Windows/Fonts/impact.ttf', 15)
    TITLE, TAG = 'CÂMARA 7', 'CHERNOBYL · 1986'
    w, h = 330, 92
    m = Image.new('L', (w, h), 0)
    d = ImageDraw.Draw(m)
    d.fontmode = '1'                                  # sem suavização: pixel puro
    d.text((54, 7), TITLE, font=big, fill=255)
    tw = d.textlength(TITLE, font=big)
    x7 = 54 + d.textlength(TITLE[:-1], font=big)        # o "7" sai em vermelho-ferrugem
    img = new(w, h)
    rng = random.Random(4)
    top, bot = C('#f2c75a'), C('#b5651e')
    mp = m.load()
    bb = m.getbbox()
    for y in range(h):
        for x in range(w):
            if mp[x, y] > 128:
                t = (y - bb[1]) / max(1, bb[3] - bb[1])
                c = mix(top, bot, t) if x < x7 else mix(C('#e8553a'), C('#8a2416'), t)
                if (y - bb[1]) % 3 == 2 and t > .2:
                    c = mix(c, C('#000000'), .12)            # linhas de desgaste
                if vnoise(x, y, 3, 11) > .78 or rng.random() < .015:
                    c = mix(c, C('#2a1a0c'), .7)             # tinta descascada
                img.putpixel((x, y), c)
    # contorno e sombra projetada
    sh = img.copy()
    for y in range(h):
        for x in range(w):
            if mp[x, y] <= 128:
                near = any(0 <= x + dx < w and 0 <= y + dy < h and mp[x + dx, y + dy] > 128 for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
                if near:
                    sh.putpixel((x, y), C('#140a04'))
                elif 0 <= x - 2 < w and 0 <= y - 2 < h and mp[x - 2, y - 2] > 128:
                    sh.putpixel((x, y), (10, 6, 4, 200))
    img = sh
    # faixa de risco com MINER
    by = bb[3] + 4
    bx0, bx1 = 52, int(52 + tw)
    for y in range(by, by + 18):
        for x in range(bx0, bx1):
            stripe = ((x + y) // 6) % 2 == 0
            img.putpixel((x, y), C('#c99a2e') if stripe else C('#16120c'))
    for x in range(bx0, bx1):
        img.putpixel((x, by), C('#0a0806')); img.putpixel((x, by + 17), C('#0a0806'))
    lbl = Image.new('L', (w, h), 0)
    dl = ImageDraw.Draw(lbl)
    dl.fontmode = '1'
    mw = dl.textlength(TAG, font=small)
    plate_x = int((bx0 + bx1) / 2 - mw / 2 - 6)
    for y in range(by + 1, by + 17):
        for x in range(plate_x, int(plate_x + mw + 12)):
            img.putpixel((x, y), C('#0e0b08'))
    tb = dl.textbbox((0, 0), TAG, font=small)
    dl.text((plate_x + 6 - tb[0], by + 9 - (tb[1] + tb[3]) / 2), TAG, font=small, fill=255)
    lp = lbl.load()
    for y in range(h):
        for x in range(w):
            if lp[x, y] > 128:
                img.putpixel((x, y), C('#e8dcc0'))
    # trevo desgastado à esquerda
    from gen_assets import trefoil
    cx, cy = 24, 36
    for y in range(h):
        for x in range(50):
            dd = math.hypot(x + .5 - cx, y + .5 - cy)
            if dd <= 21:
                img.putpixel((x, y), C('#120c06') if dd > 19.6 else mix(C('#d8aa3a'), C('#8a5a18'), dd / 22))
    trefoil(img, cx, cy, 16.5, C('#140e08'))
    for _ in range(40):
        x, y = rng.randrange(6, 44), rng.randrange(10, 50)
        if math.hypot(x - cx, y - cy) < 19 and img.getpixel((x, y))[0] > 100:
            img.putpixel((x, y), mix(img.getpixel((x, y)), C('#3a2410'), .6))
    return img


def build():
    save(sky(), D + 'sky.png')
    save(beam(), D + 'beam.png')
    save(city(), D + 'city.png')
    save(plant(), D + 'plant.png')
    save(fire_frames(), D + 'fire.png')
    save(mid(), D + 'mid.png')
    save(front(), D + 'front.png')
    save(hero(), D + 'hero.png')
    save(heli(), D + 'heli.png')
    save(smoke(), D + 'smoke.png')
    save(logo(), D + 'logo.png')
    from title_v4 import fog
    save(fog(), D + 'fog.png')


if __name__ == '__main__':
    build()
    print('título v5 ok')
