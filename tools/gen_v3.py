"""Arte v0.3: personagens 16x32, trevo radioativo correto, placa do HUD, ícones de talento,
cone de lanterna, bancada e itens novos. Roda depois de gen_assets (sobrescreve o que refaz)."""
import math
import random

from PIL import Image

import charart as ca
from gen_assets import (C, new, save, px, rect, hline, vline, line, ellipse, outline, mix, alpha, vnoise, ramp,
                        grime, text, HAZ, REDS, STEEL, WOOD, PAPER, BLACK, RUST, RADG, CYAN, ROCK)

R4 = ca.ramp4


# ======================================================================= trevo
def trefoil_mask(size, ss=8, inner=0.18, hub=0.13, outer=0.5, gap=0.21):
    """Trevo de radiação geometricamente correto (proporções da norma ISO 361:
    raio do centro R, lâminas de 1,5R a 5R, 60° cada), supersampleado."""
    m = Image.new('L', (size, size), 0)
    S = size * ss
    cx = cy = S / 2
    R = S * outer
    acc = [[0] * size for _ in range(size)]
    for y in range(S):
        for x in range(S):
            dx, dy = x + .5 - cx, y + .5 - cy
            r = math.hypot(dx, dy) / R
            on = False
            if r <= hub:
                on = True
            elif gap <= r <= 1.0:
                a = (math.degrees(math.atan2(dy, dx)) + 90) % 120     # lâmina apontando para cima
                if a <= 30 or a >= 90:
                    on = True
            if on:
                acc[y // ss][x // ss] += 1
    for y in range(size):
        for x in range(size):
            m.putpixel((x, y), int(255 * acc[y][x] / (ss * ss)))
    return m


def paint_trefoil(img, x0, y0, size, fg, threshold=110, **kw):
    m = trefoil_mask(size, **kw)
    for y in range(size):
        for x in range(size):
            if m.getpixel((x, y)) >= threshold:
                px(img, x0 + x, y0 + y, fg)


def disc(img, cx, cy, r, c):
    for y in range(int(cy - r) - 1, int(cy + r) + 2):
        for x in range(int(cx - r) - 1, int(cx + r) + 2):
            if (x + .5 - cx) ** 2 + (y + .5 - cy) ** 2 <= r * r:
                px(img, x, y, c)


def build_rad_icons():
    d = 'ui/'
    # ícone do HUD 11x11: disco amarelo + trevo preto, simétrico
    ic = new(11, 11)
    disc(ic, 5.5, 5.5, 5.5, HAZ[1])
    paint_trefoil(ic, 1, 1, 9, BLACK, threshold=100)
    for (x, y) in ((3, 2), (2, 3)):
        if ic.getpixel((x, y)) == HAZ[1]:
            px(ic, x, y, HAZ[0])
    save(ic, d + 'icon_rad.png')
    # ícone do jogo 256 (também vira .ico)
    S = 256
    big = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    rng = random.Random(3)
    for y in range(S):
        for x in range(S):
            dd = math.hypot(x + .5 - S / 2, y + .5 - S / 2)
            if dd <= S * .47:
                v = vnoise(x, y, 18, 41)
                base = mix(HAZ[1], HAZ[2], min(1, max(0, (dd / (S * .47)) ** 3 * .8 + (v - .5) * .35)))
                big.putpixel((x, y), base)
            elif dd <= S * .5:
                big.putpixel((x, y), C('#1a170f'))
    m = trefoil_mask(int(S * .78), ss=3)
    off = int(S * .11)
    for y in range(m.height):
        for x in range(m.width):
            a = m.getpixel((x, y))
            if a > 0:
                c = big.getpixel((x + off, y + off))
                big.putpixel((x + off, y + off), mix(c, C('#16130d'), a / 255))
    # desgaste: arranhões e manchas
    for _ in range(140):
        x, y = rng.randrange(S), rng.randrange(S)
        if math.hypot(x - S / 2, y - S / 2) < S * .45:
            c = big.getpixel((x, y))
            for k in range(rng.randint(2, 7)):
                xx, yy = x + k, y + k // 2
                if 0 <= xx < S and 0 <= yy < S and big.getpixel((xx, yy))[3]:
                    big.putpixel((xx, yy), mix(c, C('#4a3a1c'), .55))
    save(big, d + 'icon_256.png')
    small = big.resize((64, 64), Image.LANCZOS)
    save(small, d + 'icon.png')
    import os
    from gen_assets import ASSETS
    ico_path = os.path.join(os.path.dirname(ASSETS), 'icon.ico')
    big.save(ico_path, sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])


def fix_prop_trefoils():
    """Refaz placas/barris que usavam o trevo torto."""
    import gen_assets as g
    pdir = 'environment/props/'
    # placa de perigo 16x14
    sg = new(16, 16)
    rect(sg, 1, 1, 14, 12, HAZ[1]); hline(sg, 1, 1, 14, HAZ[0]); hline(sg, 1, 12, 14, HAZ[2])
    paint_trefoil(sg, 3, 2, 10, BLACK, threshold=100)
    vline(sg, 7, 13, 3, WOOD[2]); vline(sg, 8, 13, 3, WOOD[3])
    grime(sg, .35, 9, rust=True)
    save(outline(sg), pdir + 'sign_rad.png')


# ================================================================ personagens
def suit_look(n):
    pal = {
        1: ('#b98e2c', '#5b6340', '#4f3f2b', '#59613f'),
        2: ('#cfa42b', '#4e5838', '#7f858b', '#525c3a'),
        3: ('#b67c20', '#3c3f3c', '#2c2d2a', '#474c4f'),
        4: ('#d6cfac', '#8a3a20', '#c4532a', '#7a3a24'),
    }[n]
    suit, mask, boots, filt = pal
    look = {
        'hood': R4(suit), 'torso': R4(suit), 'arms': R4(suit, sh=.70), 'legs': R4(suit, sh=.72),
        'mask': R4(mask), 'filter': R4(filt), 'boots': R4(boots, hi=1.35),
        'gloves': R4('#3a3a30' if n != 4 else '#c4532a'),
        'zip': C('#7a776a'), 'belt': C('#2b2a22'), 'buckle': C('#9a9a88'), 'pouch': R4('#4b4a3a'),
        'pack': R4('#4c4f3c' if n != 3 else '#3b3d3a'), 'glint': C('#cfeee2'),
        'badge': C('#8fe854'), 'pocket': True,
    }
    if n >= 3:
        look['collar'] = C('#2c2d2a')
    return look


def tank_extra(color):
    def f(cv, d, bob):
        if d == 'up':
            ca.Canvas.rrect(cv, 6, 14 + bob, 4, 7, R4(color))
            cv.put(7, 13 + bob, R4(color)[0])
    return f


def build_player():
    for n in (1, 2, 3, 4):
        look = suit_look(n)
        if n >= 2:
            look['extras'] = [tank_extra('#6f7a7e' if n == 2 else ('#3a3d3f' if n == 3 else '#c8c3a8'))]
        img = ca.sheet(look)
        img = soil(img, n)
        save(img, f'characters/player/suit_{n}.png')


def soil(img, seed):
    """Sujeira leve nas botas/joelhos e manchas no traje."""
    rng = random.Random(seed * 13)
    out = img.copy()
    for y in range(out.height):
        for x in range(out.width):
            c = out.getpixel((x, y))
            if c[3] == 0 or c[:3] == (20, 18, 13):
                continue
            fy = (y % 32) / 32
            v = vnoise(x, y, 3, seed + 70)
            if (fy > .72 and v > .55) or v > .82:
                out.putpixel((x, y), mix(c, C('#3b3020'), .32 if fy > .72 else .18))
    return out


NPCS = {
    'kolya': {   # comerciante: boné, jaqueta de couro, bigode
        'skin': R4('#c49778'), 'hair': R4('#3a3a36'), 'head': 'cap', 'cap': R4('#4b5233', hi=1.3),
        'mustache': C('#4a3626'), 'torso': R4('#4a3a2a'), 'arms': R4('#4a3a2a', sh=.7), 'legs': R4('#2f3446'),
        'boots': R4('#2a211a', hi=1.4), 'gloves': R4('#c49778'), 'belt': C('#1e1812'), 'buckle': C('#9a8a60'),
        'zip': C('#2a2018'), 'collar': C('#6a5a44'),
    },
    'oksana': {  # engenheira: macacão azul, cabelo preso, ferramenta
        'skin': R4('#d0a487'), 'hair': R4('#5a3b26'), 'head': 'hair', 'torso': R4('#56604c'),
        'arms': R4('#56604c', sh=.7), 'legs': R4('#454d3d'), 'boots': R4('#25241f', hi=1.6), 'gloves': R4('#3a3a30'),
        'belt': C('#5a4a32'), 'buckle': C('#8a7a50'), 'zip': C('#3a3f33'), 'pouch': R4('#6a5a3a'), 'collar': C('#7a3a2a'),
    },
    'hanna': {   # moradora idosa: lenço florido, saia, xale
        'skin': R4('#cfa58b'), 'hair': R4('#8f8a84'), 'head': 'scarf', 'scarf': R4('#8a2e26'), 'scarf_dot': C('#e0c070'),
        'torso': R4('#3a3530'), 'arms': R4('#3a3530', sh=.7), 'skirt': R4('#4d3a30'), 'boots': R4('#2a211a', hi=1.4),
        'gloves': R4('#cfa58b'), 'coat': R4('#5a4a3a'),
    },
    'abramov': {  # cientista: jaleco, óculos, careca grisalha
        'skin': R4('#d6ae92'), 'hair': R4('#9a978d'), 'head': 'bald', 'glasses': C('#1a1c20'),
        'torso': R4('#c9c7bc', hi=1.12), 'arms': R4('#c9c7bc', sh=.72), 'legs': R4('#3a3f4a'),
        'boots': R4('#1e1e22', hi=1.8), 'gloves': R4('#d6ae92'), 'zip': C('#8a8a80'), 'collar': C('#5a6070'),
        'mustache': C('#8a857a'),
    },
}


def npc_extras(name):
    if name == 'hanna':      # bengala
        def f(cv, d, bob):
            for y in range(17, 30):
                cv.put(13, y, WOOD[1])
            cv.put(12, 17, WOOD[0])
        return [f]
    if name == 'abramov':    # prancheta + dosímetro de lapela
        def f(cv, d, bob):
            ca.Canvas.rrect(cv, 11, 17 + bob, 4, 5, [PAPER[0], PAPER[1], PAPER[2], PAPER[3]], round_top=False)
            cv.put(12, 16 + bob, STEEL[2]); cv.put(13, 16 + bob, STEEL[2])
            cv.put(6, 15 + bob, RADG[2])
        return [f]
    if name == 'oksana':     # chave inglesa
        def f(cv, d, bob):
            for y in range(19, 26):
                cv.put(2, y + bob, STEEL[1])
            cv.put(1, 26 + bob, STEEL[1]); cv.put(3, 26 + bob, STEEL[1])
        return [f]
    if name == 'kolya':      # garrafa no bolso
        def f(cv, d, bob):
            cv.put(10, 18 + bob, C('#5a7a4a')); cv.put(10, 19 + bob, C('#3e5a33')); cv.put(10, 17 + bob, C('#c8c0a0'))
        return [f]
    return []


def build_npcs():
    for name, look in NPCS.items():
        look = dict(look)
        look['extras'] = npc_extras(name)
        save(ca.strip(look), f'characters/npc/{name}.png')


# ======================================================================== HUD
def build_plate():
    """Placa de metal escura 12x12 (9-slice margem 4): borda de aço gasta, rebites, fundo fumê."""
    p = new(12, 12)
    for y in range(12):
        for x in range(12):
            edge = x in (0, 11) or y in (0, 11)
            if edge:
                c = C('#0b0b08', 235)
            elif x in (1, 10) or y in (1, 10):
                c = C('#3a3c33', 235) if (y == 1 or x == 1) else C('#202219', 235)
            else:
                v = vnoise(x, y, 4, 77)
                c = mix(C('#14160f', 215), C('#1b1d15', 215), v)
            p.putpixel((x, y), c)
    for (x, y) in ((2, 2), (9, 2), (2, 9), (9, 9)):
        px(p, x, y, C('#55584a', 235))
    save(p, 'ui/plate.png')


# ===================================================================== talentos
PERK_ORDER = ['golpe_certeiro', 'pulmoes', 'maos_rapidas', 'olho_clinico', 'bolso_fundo', 'pele_grossa',
              'faro_sucata', 'barganha', 'passo_leve', 'bateria', 'corpo_fechado', 'ima', 'geologo',
              'olhos_noite', 'folego', 'furia', 'corpo_quente', 'ganancia', 'insone']


def _icon_canvas():
    im = new(16, 16)
    rect(im, 0, 0, 16, 16, C('#1a1c14'))
    hline(im, 0, 0, 16, C('#2c2f24')); vline(im, 0, 0, 16, C('#2c2f24'))
    hline(im, 0, 15, 16, C('#0c0d08')); vline(im, 15, 0, 16, C('#0c0d08'))
    return im


def perk_icons():
    A, a, d = HAZ[0], HAZ[1], HAZ[3]
    G, g = RADG[1], RADG[3]
    R, r = REDS[1], REDS[3]
    S, s = STEEL[0], STEEL[3]
    W = PAPER[0]
    icons = []

    def I(fn):
        im = _icon_canvas(); fn(im); icons.append(im)

    I(lambda im: (line(im, 3, 12, 11, 4, WOOD[0]), line(im, 4, 12, 12, 4, WOOD[2]),
                  line(im, 8, 2, 14, 7, S), line(im, 9, 2, 14, 6, s), px(im, 4, 4, A), px(im, 3, 6, A), px(im, 6, 3, A)))  # golpe certeiro
    I(lambda im: (ellipse(im, 5.5, 8.5, 3, 4.5, R), ellipse(im, 10.5, 8.5, 3, 4.5, R), vline(im, 8, 2, 6, W),
                  px(im, 4, 7, REDS[0]), px(im, 9, 7, REDS[0])))                     # pulmões
    I(lambda im: (ellipse(im, 8, 9, 4, 4.5, PAPER[1]), rect(im, 5, 3, 2, 5, PAPER[1]), rect(im, 7, 2, 2, 5, PAPER[1]),
                  rect(im, 9, 3, 2, 5, PAPER[1]), line(im, 12, 4, 14, 2, A), line(im, 12, 7, 15, 6, A)))   # mãos rápidas
    I(lambda im: (ellipse(im, 8, 8, 6, 3.5, W), ellipse(im, 8, 8, 2.5, 2.5, G), ellipse(im, 8, 8, 1, 1, BLACK)))  # olho clínico
    I(lambda im: (rect(im, 3, 5, 10, 9, WOOD[1]), rect(im, 3, 5, 10, 2, WOOD[0]), rect(im, 6, 3, 4, 2, WOOD[2]),
                  rect(im, 7, 8, 2, 2, A)))                                          # bolso fundo
    I(lambda im: (ellipse(im, 8, 8, 5, 6, s), ellipse(im, 8, 7, 3.5, 4.5, S), hline(im, 5, 8, 6, s)))  # pele grossa (escudo)
    I(lambda im: (line(im, 3, 12, 7, 5, RUST[1]), rect(im, 7, 8, 6, 5, s), px(im, 9, 9, RUST[0]), px(im, 11, 11, RUST[0]),
                  ellipse(im, 4, 5, 2, 2, S)))                                       # faro de sucata
    I(lambda im: (ellipse(im, 8, 7, 5, 4, PAPER[0]), line(im, 5, 10, 3, 13, PAPER[0]), hline(im, 5, 6, 6, BLACK),
                  hline(im, 5, 8, 4, BLACK)))                                        # lábia (balão)
    I(lambda im: (ellipse(im, 5, 11, 2, 3, PAPER[2]), ellipse(im, 11, 6, 2, 3, PAPER[2]),
                  px(im, 4, 7, PAPER[2]), px(im, 10, 2, PAPER[2])))                  # passo leve
    I(lambda im: (rect(im, 5, 4, 6, 10, s), rect(im, 7, 2, 2, 2, s), rect(im, 6, 9, 4, 4, G), rect(im, 6, 6, 4, 2, g)))  # bateria
    I(lambda im: (ellipse(im, 8, 8, 6, 6, a), ellipse(im, 8, 8, 4.5, 4.5, BLACK), line(im, 5, 8, 7, 10, G),
                  line(im, 7, 10, 11, 5, G)))                                        # corpo fechado
    I(lambda im: (rect(im, 3, 4, 3, 8, R), rect(im, 10, 4, 3, 8, R), rect(im, 3, 11, 10, 2, R),
                  rect(im, 3, 3, 3, 2, S), rect(im, 10, 3, 3, 2, S)))                # ímã
    I(lambda im: (line(im, 3, 13, 8, 3, CYAN[2]), line(im, 8, 3, 13, 13, CYAN[2]), line(im, 5, 9, 11, 9, CYAN[1]),
                  px(im, 8, 6, CYAN[0])))                                            # geólogo (cristal)
    I(lambda im: (ellipse(im, 8, 8, 6, 3.5, g), ellipse(im, 8, 8, 2.5, 2.5, G), ellipse(im, 8, 8, 1, 1, BLACK),
                  px(im, 2, 2, W), px(im, 13, 3, W)))                                # olhos da noite
    I(lambda im: (line(im, 3, 6, 12, 6, PAPER[1]), line(im, 3, 9, 13, 9, PAPER[1]), line(im, 4, 12, 10, 12, PAPER[1]),
                  px(im, 12, 5, PAPER[1]), px(im, 13, 8, PAPER[1])))                 # fôlego (vento)
    I(lambda im: (ellipse(im, 8, 9, 4, 5, R), ellipse(im, 8, 10, 2, 3, REDS[0]), px(im, 8, 3, R), px(im, 6, 5, R)))  # fúria (chama)
    I(lambda im: (rect(im, 7, 3, 2, 9, s), ellipse(im, 8, 12, 2.5, 2.5, R), rect(im, 7, 6, 2, 6, R)))  # corpo quente
    I(lambda im: (ellipse(im, 8, 10, 5, 4, A), ellipse(im, 8, 10, 3, 2.5, a), text(im, 7, 8, '1', d),
                  px(im, 8, 4, A), px(im, 6, 5, A), px(im, 10, 5, A)))               # ganância
    I(lambda im: (ellipse(im, 8, 8, 5, 5, W), ellipse(im, 10, 6, 4.5, 4.5, C('#1a1c14')), px(im, 12, 11, W),
                  px(im, 3, 3, W)))                                                  # insone (lua)
    sheet = new(16 * 8, 16 * 3)
    for i, im in enumerate(icons):
        sheet.paste(im, ((i % 8) * 16, (i // 8) * 16))
    save(sheet, 'ui/perk_icons.png')
    return len(icons)


# ======================================================================= luz
def build_light_cone():
    """Cone de lanterna 256x256 com o vértice no centro da imagem apontando para +X (bandas suaves)."""
    S = 256
    im = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    half = math.radians(31)
    for y in range(S):
        for x in range(S):
            dx, dy = x + .5 - S / 2, y + .5 - S / 2
            dist = math.hypot(dx, dy) / (S / 2)
            if dist > 1 or dx <= 0:
                continue
            ang = abs(math.atan2(dy, dx))
            if ang > half:
                continue
            edge = 1 - (ang / half) ** 2.6
            fall = (1 - dist) ** 0.65
            near = min(1, 0.35 + dist * 5)
            v = edge * fall * near
            v = math.ceil(v * 9) / 9 if v > 0.02 else 0
            im.putpixel((x, y), (255, 255, 255, int(255 * min(1, v))))
    save(im, 'effects/light_cone.png')


# ===================================================================== props
def build_workbench():
    w, h = 32, 22
    im = new(w, h)
    # tampo de madeira
    for y in range(4, 9):
        for x in range(0, 32):
            v = vnoise(x * 2, y, 5, 91)
            im.putpixel((x, y), ramp([WOOD[0], WOOD[1], WOOD[2]], v, x, y, .4))
    hline(im, 0, 4, 32, WOOD[0]); hline(im, 0, 8, 32, WOOD[3])
    # pernas e prateleira
    for x in (1, 29):
        rect(im, x, 9, 2, 13, WOOD[2]); vline(im, x, 9, 13, WOOD[1])
    rect(im, 3, 16, 26, 2, WOOD[2]); hline(im, 3, 16, 26, WOOD[1])
    # morsa (torno de bancada)
    rect(im, 23, 0, 7, 4, STEEL[3]); rect(im, 24, 1, 5, 2, STEEL[1]); hline(im, 22, 2, 2, STEEL[2])
    # ferramentas: martelo, chave, latas
    line(im, 3, 3, 9, 3, WOOD[1]); rect(im, 9, 1, 2, 3, STEEL[2])
    line(im, 13, 3, 18, 2, STEEL[1]); px(im, 18, 1, STEEL[1])
    rect(im, 5, 12, 4, 4, RUST[2]); hline(im, 5, 12, 4, RUST[0])
    rect(im, 11, 13, 3, 3, C('#5a6040')); rect(im, 20, 11, 6, 5, C('#3c3f30')); px(im, 22, 13, HAZ[1])
    grime(im, .3, 5, rust=True)
    save(outline(im), 'environment/props/workbench.png')


def build_new_items():
    d = 'items/'
    fl = new(16, 16)     # sinalizador
    rect(fl, 4, 6, 9, 4, REDS[1]); hline(fl, 4, 6, 9, REDS[0]); hline(fl, 4, 9, 9, REDS[3])
    rect(fl, 12, 6, 2, 4, PAPER[1]); rect(fl, 3, 7, 1, 2, BLACK)
    text(fl, 6, 7, '', BLACK)
    px(fl, 14, 5, HAZ[0]); px(fl, 15, 4, REDS[0])
    save(outline(fl), d + 'flare.png')
    dy = new(16, 16)     # dinamite (3 bananas amarradas)
    for i, x in enumerate((4, 7, 10)):
        rect(dy, x, 5, 3, 9, REDS[1]); vline(dy, x, 5, 9, REDS[0]); vline(dy, x + 2, 5, 9, REDS[3])
    hline(dy, 4, 8, 9, C('#2a2620')); hline(dy, 4, 11, 9, C('#2a2620'))
    line(dy, 8, 5, 10, 2, PAPER[2]); px(dy, 11, 1, HAZ[0])
    save(outline(dy), d + 'dynamite.png')
    mf = new(16, 16)     # filtro de máscara (cilindro rosqueável)
    ellipse(mf, 8, 9, 5, 5, C('#59613f')); ellipse(mf, 8, 9, 3.5, 3.5, C('#6c7550'))
    for a in range(0, 360, 45):
        px(mf, 8 + round(math.cos(math.radians(a)) * 2), 9 + round(math.sin(math.radians(a)) * 2), C('#2e3322'))
    rect(mf, 6, 2, 4, 3, STEEL[2]); hline(mf, 6, 2, 4, STEEL[1])
    save(outline(mf), d + 'mask_filter.png')
    bt = new(16, 16)     # bateria (pilha quadrada soviética)
    rect(bt, 3, 4, 10, 10, C('#3a4a5a')); rect(bt, 3, 4, 10, 3, C('#c8b070')); hline(bt, 3, 4, 10, C('#e0cc8a'))
    rect(bt, 5, 2, 2, 2, STEEL[1]); rect(bt, 9, 2, 2, 2, STEEL[2])
    text(bt, 5, 8, '45', C('#c8b070'))
    save(outline(bt), d + 'battery.png')


if __name__ == '__main__':
    build_rad_icons()
    build_player(); build_npcs()
    build_plate(); n = perk_icons(); build_light_cone(); build_workbench(); build_new_items()
    print('v3 ok | ícones de talento:', n)
