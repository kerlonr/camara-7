"""Renderizador de personagens 16x32 (pixel art com volume).

Cada personagem é montado por partes (pernas, botas, tronco, braços, cabeça) desenhadas
com iluminação simples (luz de cima/esquerda) sobre rampas de 4 tons, depois recebe
contorno escuro. Poses: idle, walk (4 quadros), swing (2 quadros), em 3 direções
(down, up, side=direita; esquerda = espelho no jogo).
"""
import math
from PIL import Image

W, H = 16, 32
LIGHT = (-0.55, -0.83)


def C(h, a=255):
    h = h.lstrip('#')
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


def ramp4(base_hex, hi=1.22, sh=0.74, deep=0.52):
    """Rampa de 4 tons com hue shift (sombra fria, luz quente). hi > 1.3 = brilho extra (couro/borracha)."""
    from polish import hramp
    r = hramp(base_hex, 5, 0.55 + max(0.0, hi - 1.22) * 0.5)
    return [r[1], r[2], r[3], r[4]]
    b = C(base_hex)

    def m(f):
        return (max(0, min(255, int(b[0] * f))), max(0, min(255, int(b[1] * f))), max(0, min(255, int(b[2] * f))), 255)
    return [m(hi), b, m(sh), m(deep)]


def shade(ramp, nx, ny, bias=0.0):
    v = -(nx * LIGHT[0] + ny * LIGHT[1]) + bias      # 1 = de frente para a luz
    if v > 0.55:
        return ramp[0]
    if v > -0.05:
        return ramp[1]
    if v > -0.55:
        return ramp[2]
    return ramp[3]


class Canvas:
    def __init__(self):
        self.img = Image.new('RGBA', (W, H), (0, 0, 0, 0))

    def put(self, x, y, c):
        x, y = int(round(x)), int(round(y))
        if 0 <= x < W and 0 <= y < H:
            self.img.putpixel((x, y), c)

    def get(self, x, y):
        if 0 <= x < W and 0 <= y < H:
            return self.img.getpixel((x, y))
        return (0, 0, 0, 0)

    def ellipse(self, cx, cy, rx, ry, ramp, bias=0.0):
        for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
            for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
                dx, dy = (x + .5 - cx) / rx, (y + .5 - cy) / ry
                if dx * dx + dy * dy <= 1.0:
                    self.put(x, y, shade(ramp, dx, dy, bias))

    def rrect(self, x0, y0, w, h, ramp, bias=0.0, round_top=True, round_bottom=False):
        for y in range(y0, y0 + h):
            for x in range(x0, x0 + w):
                if round_top and y == y0 and (x == x0 or x == x0 + w - 1):
                    continue
                if round_bottom and y == y0 + h - 1 and (x == x0 or x == x0 + w - 1):
                    continue
                nx = ((x + .5) - (x0 + w / 2)) / (w / 2)
                ny = -0.35 if y == y0 else (0.35 if y == y0 + h - 1 else 0.0)
                self.put(x, y, shade(ramp, nx, ny, bias))

    def hline(self, x0, x1, y, c):
        for x in range(x0, x1 + 1):
            self.put(x, y, c)

    def vline(self, x, y0, y1, c):
        for y in range(y0, y1 + 1):
            self.put(x, y, c)

    def outline(self, color=(20, 18, 13, 255)):
        src = self.img.copy()
        for y in range(H):
            for x in range(W):
                if src.getpixel((x, y))[3] == 0:
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        xx, yy = x + dx, y + dy
                        if 0 <= xx < W and 0 <= yy < H and src.getpixel((xx, yy))[3] > 0:
                            self.img.putpixel((x, y), color)
                            break


OUT = (20, 18, 13, 255)


# ------------------------------------------------------------------ partes
def legs(cv, look, d, phase):
    """phase: 0 parado, 1 passo esq., 2 parado, 3 passo dir."""
    lr = look['legs']
    br = look['boots']
    lift_l = 1 if phase == 1 else 0
    lift_r = 1 if phase == 3 else 0
    if d in ('down', 'up'):
        for (x0, lift) in ((5, lift_l), (8, lift_r)):
            cv.rrect(x0, 21, 3, 6 - lift, lr, round_top=False)
            cv.put(x0 + 1, 24 - lift, lr[2])                      # joelho
            cv.rrect(x0 - (1 if x0 == 5 else 0), 27 - lift, 4, 3, br, round_top=True)
            cv.hline(x0 - (1 if x0 == 5 else 0), x0 + (2 if x0 == 5 else 3), 29 - lift, br[3])
        cv.vline(7, 21, 26, OUT) if False else None
    else:
        stride = {0: 0, 1: 2, 2: 0, 3: -2}[phase]
        # perna de trás (mais escura) e da frente
        cv.rrect(6 - stride // 2, 21, 3, 6, [lr[2], lr[2], lr[3], lr[3]], round_top=False)
        cv.rrect(5 - stride // 2, 27, 5, 3, [br[2], br[2], br[3], br[3]])
        cv.rrect(7 + stride // 2, 21, 3, 6, lr, round_top=False)
        cv.rrect(7 + stride // 2, 27, 5, 3, br)
        cv.put(8 + stride // 2, 24, lr[2])


def torso(cv, look, d, bob):
    tr = look['torso']
    y0 = 13 + bob
    cv.rrect(4, y0, 8, 9, tr)
    if d == 'down':
        cv.vline(8, y0 + 1, y0 + 6, look.get('zip', tr[2]))         # zíper / costura
        if look.get('collar'):
            cv.hline(6, 9, y0, look['collar'])
        if look.get('badge'):                                       # dosímetro de lapela
            cv.put(6, y0 + 2, look['badge']); cv.put(6, y0 + 3, tr[3])
        if look.get('pocket'):
            cv.hline(9, 10, y0 + 3, tr[2]); cv.put(10, y0 + 4, tr[2])
        cv.put(5, y0 + 5, tr[2]); cv.put(10, y0 + 6, tr[2])        # dobras do tecido
    if d == 'up' and look.get('pack'):
        pk = look['pack']
        cv.rrect(5, y0 + 1, 6, 6, pk)
        cv.hline(5, 10, y0 + 3, pk[3])
    if d == 'side':
        cv.rrect(5, y0, 6, 9, tr)
        if look.get('pack'):
            cv.rrect(3, y0 + 1, 3, 6, look['pack'])
    # cinto
    belt = look.get('belt')
    if belt:
        for x in range(4, 12):
            cv.put(x, y0 + 7, belt)
        if d == 'down':
            cv.put(8, y0 + 7, look.get('buckle', belt))
            if look.get('pouch'):
                cv.rrect(9, y0 + 6, 2, 2, look['pouch'], round_top=False)


def arms(cv, look, d, pose, phase, bob):
    ar = look['arms']
    gl = look['gloves']
    y0 = 14 + bob
    swing = {0: 0, 1: 1, 2: 0, 3: -1}.get(phase, 0)
    if pose == 'idle':
        if d in ('down', 'up'):
            for (x0, s) in ((2, swing), (11, -swing)):
                cv.rrect(x0, y0 + s, 3, 7, ar, bias=-0.1)
                cv.rrect(x0, y0 + 7 + s, 3, 2, gl, round_top=False, round_bottom=True)
            # separação braço/tronco
            for y in range(y0 + 1, y0 + 7):
                if cv.get(4, y)[3]:
                    cv.put(4, y, ar[3])
                if cv.get(11, y)[3]:
                    cv.put(11, y, ar[3])
        else:
            cv.rrect(7 + swing, y0, 3, 7, ar)
            cv.rrect(7 + swing, y0 + 7, 3, 2, gl, round_top=False, round_bottom=True)
            cv.vline(6 + swing, y0 + 1, y0 + 6, ar[3])
    elif pose == 'windup':
        if d in ('down', 'up'):
            for x0 in (2, 11):
                cv.rrect(x0, y0 - 5, 3, 6, ar)
                cv.rrect(x0, y0 - 7, 3, 2, gl)
        else:
            cv.rrect(4, y0 - 5, 3, 7, ar)
            cv.rrect(4, y0 - 7, 3, 2, gl)
    else:  # strike
        if d in ('down', 'up'):
            cv.rrect(5, y0 + 1, 2, 6, ar)
            cv.rrect(9, y0 + 1, 2, 6, ar)
            cv.rrect(6, y0 + 7, 4, 2, gl)
        else:
            cv.rrect(8, y0 + 2, 6, 3, ar)
            cv.rrect(13, y0 + 2, 2, 3, gl)


def head_hazmat(cv, look, d, bob):
    hood = look['hood']
    mask = look['mask']
    y = 8 + bob
    if d == 'down':
        cv.ellipse(8, y, 5.2, 5.6, hood)
        cv.ellipse(8, y + 1.2, 3.8, 3.4, mask)
        for lx in (6.2, 9.8):                                       # lentes
            cv.ellipse(lx, y + 0.6, 1.25, 1.25, [C('#2a3a36'), C('#1a2624'), C('#121a19'), C('#0c1110')])
            cv.put(lx - 0.6, y, look.get('glint', C('#a8d8c8')))
        cv.ellipse(8, y + 4.0, 1.7, 1.5, look['filter'])            # filtro
        cv.put(8, y + 3.4, look['filter'][0])
        cv.hline(5, 10, y - 4, hood[0])                             # costura do capuz
    elif d == 'up':
        cv.ellipse(8, y, 5.2, 5.6, hood)
        cv.hline(4, 11, y + 1, mask[2])                             # tira da máscara
        cv.vline(8, y - 4, y + 4, hood[2])
    else:
        cv.ellipse(7.5, y, 5.0, 5.6, hood)
        cv.ellipse(10.4, y + 1.2, 2.6, 3.0, mask)
        cv.ellipse(10.8, y + 0.4, 1.1, 1.1, [C('#2a3a36'), C('#1a2624'), C('#121a19'), C('#0c1110')])
        cv.put(10.5, y, look.get('glint', C('#a8d8c8')))
        cv.ellipse(13.0, y + 3.0, 1.6, 1.6, look['filter'])
        cv.put(13, y + 2.4, look['filter'][0])


def head_person(cv, look, d, bob):
    skin = look['skin']
    hair = look.get('hair')
    y = 9 + bob
    kind = look.get('head', 'hair')
    if d == 'up':
        cv.ellipse(8, y, 4.4, 4.8, hair or skin)
    elif d == 'down':
        cv.ellipse(8, y, 4.2, 4.7, skin)
        if hair and kind in ('hair', 'bald'):
            if kind == 'hair':
                cv.ellipse(8, y - 3.0, 4.4, 2.6, hair)
            else:
                cv.put(4, y - 1, hair[1]); cv.put(4, y, hair[1]); cv.put(11, y - 1, hair[1]); cv.put(11, y, hair[1])
        eye = look.get('eye', C('#1a1410'))
        cv.put(6, y, eye); cv.put(9, y, eye)
        cv.hline(7, 8, y + 3, skin[3])
    else:
        cv.ellipse(8.5, y, 4.0, 4.7, skin)
        if hair and kind == 'hair':
            cv.ellipse(7.5, y - 2.5, 4.0, 2.8, hair)
        cv.put(11, y, look.get('eye', C('#1a1410')))
    # acessórios
    if kind == 'cap':
        cap = look['cap']
        if d == 'side':
            cv.ellipse(8, y - 3.0, 4.6, 2.2, cap)
            cv.hline(10, 13, y - 1, cap[3])
        else:
            cv.ellipse(8, y - 3.2, 4.8, 2.3, cap)
            if d == 'down':
                cv.hline(4, 11, y - 1, cap[3])
    if kind == 'scarf':
        sc = look['scarf']
        if d == 'down':
            cv.ellipse(8, y - 2.2, 4.8, 3.2, sc)
            for x in (4, 11):
                cv.vline(x, y - 1, y + 3, sc[2])
            cv.hline(6, 9, y + 5, sc[1])
            cv.put(6, y - 3, look.get('scarf_dot', sc[0])); cv.put(9, y - 2, look.get('scarf_dot', sc[0]))
        elif d == 'up':
            cv.ellipse(8, y, 4.8, 5.0, sc)
            cv.put(8, y + 5, sc[2])
        else:
            cv.ellipse(7.5, y - 1.5, 4.6, 4.2, sc)
    if look.get('mustache') and d != 'up':
        x0 = 6 if d == 'down' else 10
        cv.hline(x0, x0 + (3 if d == 'down' else 2), y + 2, look['mustache'])
    if look.get('glasses') and d != 'up':
        g = look['glasses']
        if d == 'down':
            for gx in (5, 9):
                cv.put(gx, y, g); cv.put(gx + 1, y, g); cv.put(gx, y - 1, g); cv.put(gx + 1, y - 1, g)
            cv.put(7, y - 1, g); cv.put(8, y - 1, g)
            cv.put(6, y, look.get('eye', C('#1a1410'))); cv.put(9, y, look.get('eye', C('#1a1410')))
        else:
            cv.put(11, y, g); cv.put(12, y, g)


def render(look, d, pose='idle', phase=0):
    cv = Canvas()
    bob = 1 if phase in (1, 3) else 0
    if pose == 'windup':
        bob = -1
    elif pose == 'strike':
        bob = 1
    if look.get('skirt'):
        sk = look['skirt']
        cv.rrect(4, 21, 8, 7, sk, round_top=False)
        cv.rrect(4, 28, 3, 2, look['boots']); cv.rrect(9, 28, 3, 2, look['boots'])
    else:
        legs(cv, look, d, phase if pose == 'idle' else 0)
    if d == 'side' and pose == 'idle':
        torso(cv, look, d, bob)
        arms(cv, look, d, pose, phase, bob)
    elif d == 'up':
        arms(cv, look, d, pose, phase, bob)
        torso(cv, look, d, bob)
    else:
        torso(cv, look, d, bob)
        arms(cv, look, d, pose, phase, bob)
    if look.get('coat') and d != 'up':
        co = look['coat']
        for y in range(13 + bob, 26):
            for x in (4, 11):
                cv.put(x, y, co[2] if x == 11 else co[1])
    if look.get('hood'):
        head_hazmat(cv, look, d, bob)
    else:
        head_person(cv, look, d, bob)
    for extra in look.get('extras', []):
        extra(cv, d, bob)
    cv.outline(OUT)
    if look.get('polish', True):
        from polish import polish_sprite
        return polish_sprite(cv.img, denoise=False, hue=False)
    return cv.img


def sheet(look):
    """Folha 7 colunas × 3 linhas (down, up, side): parado, 4× andar, 2× golpe."""
    out = Image.new('RGBA', (W * 7, H * 3), (0, 0, 0, 0))
    for row, d in enumerate(('down', 'up', 'side')):
        frames = [render(look, d, 'idle', 0), render(look, d, 'idle', 1), render(look, d, 'idle', 2),
                  render(look, d, 'idle', 3), render(look, d, 'idle', 0), render(look, d, 'windup'),
                  render(look, d, 'strike')]
        for col, fr in enumerate(frames):
            out.paste(fr, (col * W, row * H))
    return out


def strip(look, frames=2):
    """NPC: 2 quadros de respiração, de frente."""
    out = Image.new('RGBA', (W * frames, H), (0, 0, 0, 0))
    for i in range(frames):
        img = render(look, 'down', 'idle', 0)
        if i == 1:
            shifted = Image.new('RGBA', (W, H), (0, 0, 0, 0))
            top = img.crop((0, 0, W, 21))
            shifted.paste(img, (0, 0))
            clear = Image.new('RGBA', (W, 21), (0, 0, 0, 0))
            shifted.paste(clear, (0, 0))
            shifted.paste(top, (0, 1), top)
            img = shifted
        out.paste(img, (i * W, 0))
    return out
