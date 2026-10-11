"""Inimigos v0.5 — folhas horizontais de 4 quadros: [andar1, andar2, preparo (telegrafa), ataque].
Vista lateral 3/4 olhando para a direita (o jogo espelha). Rampas com hue shift; contorno e polimento no fim.
"""
import math
import random

from PIL import Image

from gen_assets import new, save, C, mix
from polish import hramp, polish_sprite
from normalize import complete_outline


def put(img, x, y, c):
    if 0 <= x < img.width and 0 <= y < img.height:
        img.putpixel((int(x), int(y)), c)


def blob(img, cx, cy, rx, ry, pal, light=(-0.6, -0.8)):
    for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
        for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
            dx, dy = (x + .5 - cx) / rx, (y + .5 - cy) / ry
            if dx * dx + dy * dy <= 1:
                v = -(dx * light[0] + dy * light[1])
                put(img, x, y, pal[0] if v > .55 else pal[1] if v > -.1 else pal[2] if v > -.6 else pal[3])


# ======================================================================= rato
def rat_frame(kind):
    img = new(16, 12)
    fur = hramp('#5e5348', 4, .7)
    dark = fur[3]
    crouch = 1 if kind == 'windup' else 0
    stretch = 2 if kind == 'attack' else 0
    by = 7 + crouch
    blob(img, 7 - stretch * .3, by, 4.6 + stretch * .4, 2.6 - crouch * .3, fur)       # corpo
    blob(img, 11.5 + stretch, by - 1 + crouch, 2.6, 2.0, fur)                          # cabeça
    put(img, 14 + stretch, by - 1 + crouch, C('#b08a80'))                              # focinho
    put(img, 13 + stretch, by - 2 + crouch, C('#d23a2a'))                              # olho vermelho
    put(img, 11 + stretch, by - 3 + crouch, fur[2]); put(img, 11 + stretch, by - 4 + crouch, C('#8a6a62'))  # orelha
    for i in range(6):                                                                 # rabo pelado
        put(img, 2 - i * .7 + (0 if i < 3 else 0), by + (1 if i < 2 else 0) - (i // 3), C('#9a7a72') if i % 2 else C('#7a5e58'))
    step = {'walk1': (0, 1), 'walk2': (1, 0), 'windup': (0, 0), 'attack': (1, 1)}[kind]
    for k, lx in enumerate((5, 9 + stretch)):                                          # patas
        put(img, lx + step[k], by + 3 - crouch, dark); put(img, lx + step[k], by + 2 - crouch, fur[2])
    if kind in ('windup', 'attack'):
        put(img, 14 + stretch, by + crouch, C('#e8e0c8'))                              # dentes
    if kind == 'windup':
        for x in (5, 7, 9):
            put(img, x, by - 3, fur[3])                                                # pelo eriçado
    return img


# ======================================================================= cão
def dog_frame(kind):
    """Cão magro de perfil: peito fundo, barriga recolhida, cabeça baixa e orelhas para trás."""
    img = new(24, 16)
    fur = hramp('#6e5f4a', 5, .7)
    back = hramp('#463c33', 3, .6)
    crouch = 1 if kind == 'windup' else 0
    lunge = 2 if kind == 'attack' else 0
    by = 9 + crouch
    x0, x1 = 5, 17 + lunge
    for x in range(x0, x1):
        t = (x - x0) / max(1, (x1 - x0 - 1))            # 0 = traseira, 1 = peito
        top = by - 3 + (1 if t < .25 else 0)
        bot = by + (1 if t < .45 else 2) + (1 if t > .75 else 0)
        for y in range(top, bot + 1):
            if y == top:
                c = back[0]
            elif y == top + 1:
                c = back[1]
            elif y == bot:
                c = fur[4]
            else:
                c = fur[1] if t > .55 else fur[2]
            put(img, x, y, c)
    for x in range(10, 14, 2):
        put(img, x + lunge // 2, by, fur[3])                 # costelas
    # pernas finas com articulação
    pose = {'walk1': (-1, 1, 1, -1), 'walk2': (1, -1, -1, 1), 'windup': (0, 0, -1, -1), 'attack': (-2, -1, 2, 3)}[kind]
    for i, lx in enumerate((6, 8, 15 + lunge, 16 + lunge)):
        y_top = by + (1 if i < 2 else 2)
        for k, y in enumerate(range(y_top, 15)):
            x = lx + (pose[i] if k > 1 else 0)
            put(img, x, y, fur[3] if i in (0, 2) else fur[2])
        put(img, lx + pose[i] + 1, 14, back[2])                  # pata
    # pescoço e cabeça (baixa, ameaçadora)
    hx, hy = 17 + lunge, by - 4 + crouch * 2
    if kind == 'attack':
        hy -= 1
    for x in range(hx - 1, hx + 4):
        for y in range(hy, hy + 4):
            put(img, x, y, fur[1] if y == hy else (fur[2] if y < hy + 3 else fur[3]))
    for x in range(hx + 4, hx + 7):                              # focinho comprido
        put(img, x, hy + 2, fur[2]); put(img, x, hy + 3, fur[3] if kind != 'attack' else C('#2a1414'))
    put(img, hx + 7, hy + 2, C('#141110'))                       # nariz
    put(img, hx + 2, hy + 1, C('#e0c050'))                       # olho
    put(img, hx - 1, hy - 1, back[1]); put(img, hx - 2, hy - 1, back[2])   # orelhas para trás
    put(img, hx, hy - 1, back[1])
    for x in range(hx - 2, hx + 1):                              # pescoço ligando ao peito
        put(img, x, hy + 3, fur[2]); put(img, x, hy + 4, fur[3])
    # rabo
    tail = [(4, by - 2), (3, by - 1), (2, by), (2, by + 1)] if kind != 'windup' else [(4, by - 1), (3, by + 1), (3, by + 2)]
    for (x, y) in tail:
        put(img, x, y, back[1])
    if kind in ('windup', 'attack'):
        for x in range(hx + 4, hx + 7, 1):
            put(img, x, hy + (4 if kind == 'attack' else 3), C('#efe6d0'))      # dentes
    if kind == 'windup':
        for x in range(7, 16, 2):
            put(img, x, by - 4, back[2])                         # pelo eriçado
    return img


# ===================================================================== Vulto
def vulto_frame(kind, seed):
    rng = random.Random(seed)
    img = new(16, 32)
    core = C('#0a090d')
    edge = C('#1c1824')
    tall = 2 if kind == 'windup' else 0
    for y in range(2 - tall, 31):
        t = (y - 2) / 29
        if y < 9 - tall:                                   # cabeça
            half = 3.0
            cx = 8
        else:                                              # corpo que se desfaz embaixo
            half = 4.2 + t * 1.5
            cx = 8 + math.sin(y * .5 + seed) * .6
        for x in range(16):
            d = abs(x + .5 - cx) / half
            if d < 1:
                frag = rng.random()
                if y > 24 and frag < (y - 24) / 8:          # base vira fumaça
                    continue
                c = core if d < .7 else edge
                a = 255 if d < .85 else 190
                put(img, x, y, c[:3] + (a,))
    # braços
    if kind == 'attack':
        for x in range(9, 16):
            put(img, x, 12, edge); put(img, x, 13, core)
        put(img, 15, 11, edge); put(img, 15, 14, edge)                                 # dedos longos
    elif kind == 'windup':
        for y in range(5, 12):
            put(img, 12, y, edge); put(img, 3, y, edge)                                # braços erguidos
    else:
        for y in range(11, 20 + rng.randint(0, 2)):
            put(img, 4, y, edge); put(img, 12, y, edge)
    # olhos: dois pontos pálidos
    ey = 5 - tall
    put(img, 6, ey, C('#9fb8b0')); put(img, 9, ey, C('#9fb8b0'))
    return img


def sheet(frames, w, h):
    out = Image.new('RGBA', (w * len(frames), h), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        out.paste(f, (i * w, 0))
    return out


def finish(frames, polish=True):
    res = []
    for f in frames:
        f = complete_outline(f)
        if polish:
            f = polish_sprite(f, denoise=False)
        res.append(f)
    return res


def build():
    d = 'characters/enemies/'
    save(sheet(finish([rat_frame(k) for k in ('walk1', 'walk2', 'windup', 'attack')]), 16, 12), d + 'rat.png')
    save(sheet(finish([dog_frame(k) for k in ('walk1', 'walk2', 'windup', 'attack')]), 24, 16), d + 'dog.png')
    save(sheet([vulto_frame(k, i) for i, k in enumerate(('walk1', 'walk2', 'windup', 'attack'))], 16, 32), d + 'vulto.png')


if __name__ == '__main__':
    build()
    print('inimigos ok')
