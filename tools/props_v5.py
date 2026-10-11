"""Props v0.5: redesenho dos objetos pequenos que estavam fracos (formas indefinidas, "bolhas").
Cada desenho: luz de cima/esquerda, rampas com hue shift, silhueta clara. Contorno, normalização
e polimento ficam a cargo do build_art.py. Também o mineiro sentado (encontro especial).
"""
import math

from PIL import Image

from gen_assets import new, save, C, mix
from polish import hramp, polish_sprite

D = 'environment/props/'


def put(img, x, y, c):
    x, y = int(round(x)), int(round(y))
    if 0 <= x < img.width and 0 <= y < img.height:
        img.putpixel((x, y), c)


def rect(img, x, y, w, h, c):
    for yy in range(y, y + h):
        for xx in range(x, x + w):
            put(img, xx, yy, c)


def oval(img, cx, cy, rx, ry, pal, light=(-0.6, -0.8)):
    """Elipse sombreada em 4 tons (pal claro→escuro)."""
    for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
        for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
            dx, dy = (x + .5 - cx) / rx, (y + .5 - cy) / ry
            if dx * dx + dy * dy <= 1:
                v = -(dx * light[0] + dy * light[1])
                put(img, x, y, pal[0] if v > .55 else pal[1] if v > -.1 else pal[2] if v > -.6 else pal[3])


def line(img, x0, y0, x1, y1, c):
    n = max(abs(x1 - x0), abs(y1 - y0), 1)
    for i in range(int(n) + 1):
        put(img, x0 + (x1 - x0) * i / n, y0 + (y1 - y0) * i / n, c)


def shadow(img, cx, cy, rx, ry=1.5, a=110):
    for y in range(img.height):
        for x in range(img.width):
            d = ((x + .5 - cx) / rx) ** 2 + ((y + .5 - cy) / ry) ** 2
            if d <= 1 and img.getpixel((x, y))[3] == 0:
                img.putpixel((x, y), (10, 8, 12, int(a * (1 - d * .5))))


# ---------------------------------------------------------------- objetos
def boots():
    img = new(18, 16)
    shadow(img, 9, 14.5, 8)
    rb = hramp('#3a4232', 4, .7)
    for bx in (3, 9):
        rect(img, bx, 3, 5, 9, rb[2])
        for y in range(3, 12):
            put(img, bx, y, rb[1]); put(img, bx + 4, y, rb[3])
        rect(img, bx, 3, 5, 1, rb[0])                     # boca do cano
        put(img, bx + 1, 4, C('#141612')); put(img, bx + 2, 4, C('#141612')); put(img, bx + 3, 4, C('#141612'))
        rect(img, bx, 11, 7, 3, rb[2])                    # pé
        for x in range(bx, bx + 7):
            put(img, x, 13, C('#1a1a16'))                 # sola
        put(img, bx + 6, 11, rb[3]); put(img, bx + 1, 7, rb[0])
        put(img, bx + 2, 9, mix(rb[2], C('#5a4630'), .5))  # lama
    return img


def bush():
    img = new(16, 16)
    shadow(img, 8, 14.5, 6)
    br = hramp('#5a4a34', 3, .6)
    lf = hramp('#5d6136', 4, .7)
    stems = [(8, 14, 3, 5), (8, 14, 6, 3), (8, 14, 9, 2), (8, 14, 12, 4), (8, 14, 14, 8), (8, 14, 2, 9)]
    for (x0, y0, x1, y1) in stems:
        line(img, x0, y0, x1, y1, br[1])
    for (x, y) in ((3, 5), (6, 3), (9, 2), (12, 4), (14, 8), (2, 9), (5, 7), (11, 6)):
        put(img, x, y, lf[1]); put(img, x + 1, y, lf[2]); put(img, x, y + 1, lf[3])
        put(img, x - 1, y, lf[0]) if (x + y) % 3 == 0 else None
    return img


def concrete_blocks():
    img = new(18, 16)
    shadow(img, 9, 14.5, 8)
    cc = hramp('#8a867a', 4, .6)
    for (x, y, w, h) in ((1, 8, 8, 6), (9, 8, 8, 6), (5, 3, 8, 5)):
        rect(img, x, y, w, h, cc[2])
        rect(img, x, y, w, 1, cc[0])
        for yy in range(y, y + h):
            put(img, x + w - 1, yy, cc[3])
        rect(img, x + 2, y + 2, 2, h - 3, C('#2a2824'))  # furos
        rect(img, x + w - 4, y + 2, 2, h - 3, C('#2a2824'))
    put(img, 3, 9, cc[3]); put(img, 4, 10, cc[3])                        # rachadura
    put(img, 12, 13, C('#4e5a36')); put(img, 13, 13, C('#5d6a40'))      # musgo
    return img


def coat_hooks():
    img = new(18, 16)
    wd = hramp('#6a5038', 3, .6)
    rect(img, 1, 2, 16, 2, wd[1]); rect(img, 1, 2, 16, 1, wd[0])
    for x in (4, 9, 14):
        put(img, x, 4, C('#9aa2a4')); put(img, x, 5, C('#5e686d'))
    jk = hramp('#4a5040', 4, .7)                                        # jaqueta pendurada
    for y in range(5, 14):
        w = 3 + min(2, (y - 5) // 2)
        for x in range(9 - w, 9 + w + 1):
            put(img, x, y, jk[1] if x < 9 else jk[2])
    for y in range(6, 14):
        put(img, 9, y, jk[3])
    hm = hramp('#d0a030', 3, .7)                                         # capacete no gancho
    oval(img, 14, 7, 2.6, 2.2, [hm[0], hm[1], hm[2], hm[2]])
    rect(img, 11, 8, 6, 1, hm[2])
    put(img, 4, 6, C('#7a2a20')); put(img, 4, 7, C('#5a1c16')); put(img, 4, 8, C('#7a2a20'))   # cachecol
    return img


def clock():
    """Relógio de parede soviético parado em 1:23 (hora do acidente, 26/04/1986)."""
    img = new(16, 16)
    rim = hramp('#4a4a44', 3, .6)
    face = hramp('#d8d2bc', 3, .5)
    oval(img, 8, 8, 6.5, 6.5, [rim[0], rim[1], rim[2], rim[2]])
    oval(img, 8, 8, 5.2, 5.2, [face[0], face[0], face[1], face[2]])
    for a in range(0, 360, 30):
        r = 4.3
        put(img, 8 + math.cos(math.radians(a)) * r, 8 + math.sin(math.radians(a)) * r, C('#5a5648'))
    hr = math.radians(-90 + (1 + 23 / 60) * 30)
    mn = math.radians(-90 + 23 * 6)
    line(img, 8, 8, 8 + math.cos(hr) * 2.4, 8 + math.sin(hr) * 2.4, C('#1a1814'))
    line(img, 8, 8, 8 + math.cos(mn) * 3.8, 8 + math.sin(mn) * 3.8, C('#1a1814'))
    put(img, 8, 8, C('#a83228'))
    put(img, 5, 5, C('#ffffff')); put(img, 6, 4, C('#f0f0e8'))                # reflexo do vidro
    put(img, 10, 11, C('#9a9480')); put(img, 11, 10, C('#9a9480'))            # vidro trincado
    return img


def helmet_floor():
    img = new(16, 16)
    shadow(img, 8, 13.5, 7)
    hm = hramp('#c99a2c', 4, .7)
    oval(img, 8, 9, 6, 4.5, hm)
    for y in range(9, 14):
        for x in range(1, 15):
            if img.getpixel((x, y))[3] > 200 and y >= 11:
                put(img, x, y, hm[2] if y == 11 else (0, 0, 0, 0))
    rect(img, 1, 11, 14, 1, hm[2]); rect(img, 0, 12, 16, 1, hm[3])               # aba
    rect(img, 6, 6, 4, 3, C('#5e686d')); rect(img, 7, 7, 2, 1, C('#e8e0b0'))   # lanterna (apagada)
    put(img, 4, 7, hm[0]); put(img, 11, 9, hm[3]); put(img, 12, 8, hm[3])      # arranhões
    return img


def samovar():
    img = new(16, 20)
    shadow(img, 8, 18.5, 6)
    br = hramp('#b88a3a', 4, .7)
    oval(img, 8, 11, 5, 5.5, br)
    rect(img, 6, 3, 4, 3, br[2]); rect(img, 6, 3, 4, 1, br[1])                 # chaminé
    rect(img, 7, 1, 2, 2, C('#3a3a34'))
    rect(img, 5, 16, 6, 2, br[3])                                                # base
    put(img, 2, 10, br[2]); put(img, 2, 11, br[3]); put(img, 14, 10, br[2]); put(img, 14, 11, br[3])   # alças
    rect(img, 12, 13, 3, 1, br[2]); put(img, 14, 14, br[3])                     # torneira
    put(img, 5, 8, C('#fff0c0')); put(img, 6, 8, br[0])                         # brilho
    return img


def tire():
    img = new(16, 16)
    rb = hramp('#2c2c2a', 3, .5)
    for y in range(16):
        for x in range(16):
            d = ((x + .5 - 8) / 7.2) ** 2 + ((y + .5 - 9) / 4.6) ** 2
            di = ((x + .5 - 8) / 3.3) ** 2 + ((y + .5 - 9) / 1.9) ** 2
            if d <= 1 and di > 1:
                c = rb[0] if y < 7 else rb[1]
                if (x * 3 + y) % 4 == 0 and d > .6:
                    c = rb[2]                                                   # banda de rodagem
                put(img, x, y, c)
            elif di <= 1:
                put(img, x, y, (10, 8, 12, 150))
    return img


def rubble():
    img = new(16, 16)
    shadow(img, 8, 14.5, 7)
    cc = hramp('#57514a', 4, .6)
    for (cx, cy, rx, ry) in ((5, 11, 3.5, 2.5), (10, 11.5, 3.6, 2.4), (8, 8, 3, 2.2), (12.5, 8.5, 2, 1.6), (3.5, 8, 1.8, 1.4)):
        oval(img, cx, cy, rx, ry, cc)
    line(img, 9, 5, 13, 10, C('#7a4a2c'))                                       # vergalhão torto
    put(img, 9, 4, C('#9a6a40'))
    put(img, 6, 13, cc[3]); put(img, 11, 13, cc[3])
    return img


def fungus():
    img = new(16, 16)
    stem = hramp('#c8c8b0', 3, .5)
    cap = hramp('#4fb8a8', 4, .8)
    for (x, y, h, r) in ((5, 13, 5, 2.6), (10, 13, 7, 3.0), (13, 13, 3, 1.8), (3, 13, 2, 1.5)):
        for k in range(h):
            put(img, x, y - k, stem[1] if k % 2 else stem[0])
        oval(img, x, y - h, r, r * .7, cap)
        put(img, x - 1, y - h - 1, C('#c8fff0'))                                # brilho bioluminescente
    return img


def valve():
    img = new(16, 17)
    pp = hramp('#6e7a80', 3, .7)
    rect(img, 0, 11, 16, 3, pp[1]); rect(img, 0, 11, 16, 1, pp[0]); rect(img, 0, 13, 16, 1, pp[2])   # cano
    rect(img, 7, 6, 2, 6, pp[2])                                               # haste
    rd = hramp('#a83228', 3, .7)
    for a in range(0, 360, 10):                                                 # volante vermelho
        put(img, 8 + math.cos(math.radians(a)) * 4.5, 4.5 + math.sin(math.radians(a)) * 3.2, rd[1] if a < 180 else rd[0])
    for a in (0, 90, 180, 270):
        line(img, 8, 4.5, 8 + math.cos(math.radians(a)) * 4, 4.5 + math.sin(math.radians(a)) * 2.8, rd[2])
    put(img, 8, 4, C('#3a3a34'))
    put(img, 3, 14, C('#5a3a22')); put(img, 3, 15, C('#4a2a18'))              # ferrugem pingando
    return img


def doll():
    img = new(16, 16)
    shadow(img, 8, 14.5, 5)
    sk = hramp('#d8b8a0', 3, .5)
    dr = hramp('#8a2a24', 4, .7)
    oval(img, 8, 4.5, 2.8, 2.8, [sk[0], sk[1], sk[2], sk[2]])
    rect(img, 5, 2, 6, 2, C('#5a3a22'))                                        # cabelo
    put(img, 7, 5, C('#1a1410')); put(img, 9, 5, C('#2a2420'))                 # um olho só (o outro caiu)
    for y in range(7, 13):                                                      # vestido
        w = 2 + (y - 7) // 2
        for x in range(8 - w, 8 + w + 1):
            put(img, x, y, dr[1] if x < 8 else dr[2])
    rect(img, 5, 13, 2, 1, sk[2]); rect(img, 9, 13, 2, 1, sk[2])               # pés
    put(img, 4, 9, sk[1]); put(img, 12, 9, sk[1])                              # braços caídos
    return img


def teddy():
    img = new(16, 16)
    shadow(img, 8, 14.5, 5)
    fu = hramp('#8a6440', 4, .6)
    oval(img, 8, 10.5, 4, 3.5, fu)                                             # corpo
    oval(img, 8, 5, 3, 2.8, fu)                                                # cabeça
    oval(img, 5, 3, 1.2, 1.2, fu); oval(img, 11, 3, 1.2, 1.2, fu)              # orelhas
    put(img, 7, 5, C('#141010')); put(img, 9, 5, C('#141010'))
    put(img, 8, 6, C('#3a2418'))
    oval(img, 4, 13, 1.8, 1.4, fu); oval(img, 12, 13, 1.8, 1.4, fu)            # pés
    rect(img, 8, 9, 1, 3, C('#d8d0b8'))                                        # costura aberta, enchimento
    return img


def gasmask():
    """Máscara GP-5 caída: borracha cinza, dois visores redondos, filtro."""
    img = new(16, 16)
    shadow(img, 8, 14, 6)
    rb = hramp('#5a5e58', 4, .6)
    oval(img, 7, 8, 5, 5, rb)
    for lx in (5, 9):
        oval(img, lx, 7, 1.6, 1.6, [C('#9fc0b8'), C('#3a4a48'), C('#243030'), C('#182020')])
    put(img, 4, 6, C('#e0f0ea'))                                                # reflexo
    oval(img, 12, 12, 2.6, 2.2, hramp('#5d6a40', 4, .7))                       # filtro rosqueado
    rect(img, 9, 11, 2, 1, rb[3])
    return img


def steam_vent():
    img = new(16, 16)
    mt = hramp('#4a4e4c', 3, .6)
    rect(img, 2, 3, 12, 10, mt[1]); rect(img, 2, 3, 12, 1, mt[0]); rect(img, 2, 12, 12, 1, mt[2])
    for y in range(5, 12, 2):
        rect(img, 3, y, 10, 1, C('#141614'))                                    # grade
    put(img, 2, 3, C('#9aa2a4')); put(img, 13, 3, C('#9aa2a4')); put(img, 2, 12, C('#9aa2a4')); put(img, 13, 12, C('#9aa2a4'))
    put(img, 6, 4, mix(mt[1], C('#c8d0c8'), .5)); put(img, 9, 4, mix(mt[1], C('#c8d0c8'), .4))   # condensação
    return img


def miner_sitting():
    """Mineiro sentado contra a parede, cabeça baixa; 2º quadro: cabeça erguida, rosto pálido."""
    out = new(32, 24)
    for f in range(2):
        img = new(16, 24)
        shadow(img, 8, 22.5, 6)
        cl = hramp('#3c4034', 4, .6)
        hm = hramp('#a8862e', 3, .6)
        sk = hramp('#b8b0a0', 3, .5)
        rect(img, 4, 12, 8, 7, cl[2])                    # tronco
        rect(img, 4, 12, 8, 1, cl[1])
        rect(img, 3, 17, 4, 5, cl[1]); rect(img, 9, 17, 4, 5, cl[2])   # joelhos dobrados
        rect(img, 2, 21, 5, 2, C('#1c1c18')); rect(img, 9, 21, 5, 2, C('#1c1c18'))   # botas
        rect(img, 5, 16, 6, 2, cl[3])                    # braços sobre os joelhos
        hy = 9 if f == 0 else 7
        oval(img, 8, hy + 2, 3.2, 2.8, [sk[1], sk[1], sk[2], sk[2]] if f else [cl[1], cl[2], cl[3], cl[3]])
        oval(img, 8, hy, 4.2, 2.4, [hm[0], hm[1], hm[2], hm[2]])        # capacete
        rect(img, 3, hy + 1, 10, 1, hm[2])
        if f == 1:                                       # olhos fundos encarando
            put(img, 7, hy + 2, C('#0c0c0e')); put(img, 9, hy + 2, C('#0c0c0e'))
            put(img, 8, hy + 4, C('#5a5048'))
        out.paste(img, (f * 16, 0))
    return out


def build():
    for name, fn in (('boots', boots), ('bush', bush), ('concrete_blocks', concrete_blocks), ('coat_hooks', coat_hooks),
                     ('clock', clock), ('helmet_floor', helmet_floor), ('samovar', samovar), ('tire', tire),
                     ('rubble', rubble), ('fungus', fungus), ('valve', valve), ('doll', doll), ('teddy', teddy),
                     ('gasmask', gasmask), ('steam_vent', steam_vent)):
        save(fn(), D + name + '.png')
    # mineiro: folha de 2 quadros — polida aqui, quadro a quadro (o build_art não toca nela)
    sheet = miner_sitting()
    out = new(32, 24)
    from normalize import complete_outline
    for f in range(2):
        fr = polish_sprite(complete_outline(sheet.crop((f * 16, 0, f * 16 + 16, 24))), denoise=False)
        out.paste(fr, (f * 16, 0))
    save(out, D + 'miner_sitting.png')


if __name__ == '__main__':
    build()
    print('props v5 ok')
