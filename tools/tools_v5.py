"""Ferramentas v0.5 (picaretas e britadeiras), 16x16 com 1px de folga para o contorno.

Empunhadura (ponto de pivô na mão do personagem):
  picaretas  (2, 13)  — ponta do cabo, embaixo à esquerda   (player.gd: offset -2, -13)
  britadeira (8, 2)   — punho em T no topo                  (player.gd: offset -8, -2)
"""
from PIL import Image

from gen_assets import new, save, C
from polish import hramp

S = 16


def put(img, x, y, c):
    if 0 <= x < S and 0 <= y < S:
        img.putpixel((x, y), c)


def pickaxe(handle_hex, head_hex, wrap_hex=None, crude=False, paint=None):
    img = new(S, S)
    hd = hramp(handle_hex, 4, .7)
    st = hramp(head_hex, 5, .9)
    # cabo: diagonal de (2,13) até (10,5), 2px de largura (luz em cima/esquerda)
    for i in range(9):
        x, y = 2 + i, 13 - i
        put(img, x, y, hd[1])
        put(img, x + 1, y, hd[2])
        put(img, x, y - 1, hd[0]) if i % 3 == 0 and i > 0 else None
    put(img, 2, 14, hd[3]); put(img, 1, 13, hd[2])                     # ponta do cabo
    if wrap_hex:                                                         # pano/fita na empunhadura
        wr = hramp(wrap_hex, 3, .6)
        for i in range(1, 4):
            put(img, 2 + i, 13 - i, wr[0] if i % 2 else wr[1]); put(img, 3 + i, 13 - i, wr[2])
    if paint:                                                            # cabo pintado
        pt = hramp(paint, 3, .6)
        for i in range(4, 8):
            put(img, 2 + i, 13 - i, pt[0]); put(img, 3 + i, 13 - i, pt[1])
    # olho/cunha da cabeça
    put(img, 10, 4, st[2]); put(img, 11, 4, st[3]); put(img, 10, 5, st[3]); put(img, 11, 5, st[4])
    # cabeça curva: lâmina para baixo-direita e ponta para cima-esquerda
    blade = [(12, 5), (12, 6), (13, 7), (13, 8), (14, 9), (14, 10)] if not crude else [(12, 5), (12, 6), (13, 7), (13, 8), (13, 9)]
    back = [(9, 3), (8, 2), (7, 2), (6, 1)] if not crude else [(9, 3), (8, 3), (7, 2)]
    for (x, y) in blade:
        put(img, x, y, st[1]); put(img, x - 1, y, st[2])
    put(img, blade[-1][0], blade[-1][1], st[0])                         # gume brilhando
    for (x, y) in back:
        put(img, x, y, st[1]); put(img, x, y + 1, st[3])
    put(img, back[-1][0], back[-1][1], st[0])
    put(img, 11, 3, st[0]); put(img, 12, 4, st[1])                       # topo da cabeça
    if crude:                                                            # ferrugem e amarração
        rs = hramp('#8a4f2c', 3, .6)
        put(img, 12, 6, rs[0]); put(img, 13, 8, rs[1]); put(img, 8, 3, rs[1])
        put(img, 9, 5, C('#6b6a5e')); put(img, 10, 6, C('#4a4940'))
    return img


def drill(body_hex, accent_hex):
    img = new(S, S)
    bd = hramp(body_hex, 5, .8)
    ac = hramp(accent_hex, 3, .7)
    st = hramp('#8e979b', 4, .9)
    for x in range(3, 13):                                               # punho em T
        put(img, x, 1, st[1] if 4 < x < 11 else C('#2a2a26')); put(img, x, 2, st[2] if 4 < x < 11 else C('#1c1c19'))
    put(img, 3, 1, C('#3a3a34')); put(img, 12, 1, C('#3a3a34'))
    for y in range(3, 11):                                               # corpo cilíndrico
        put(img, 5, y, bd[0]); put(img, 6, y, bd[1]); put(img, 7, y, bd[1]); put(img, 8, y, bd[2]); put(img, 9, y, bd[2]); put(img, 10, y, bd[3])
    for x in range(5, 11):
        put(img, x, 6, ac[0] if x < 8 else ac[1]); put(img, x, 7, ac[1] if x < 8 else ac[2])
    put(img, 11, 4, C('#121212')); put(img, 11, 5, C('#2a2a2a'))       # mangueira de ar
    put(img, 12, 5, C('#121212'))
    for y in range(11, 14):                                              # ponteiro (cinzel)
        put(img, 7, y, st[0]); put(img, 8, y, st[2])
    put(img, 7, 14, st[1])
    for x in range(6, 10):
        put(img, x, 10, bd[3])
    return img


def build():
    d = 'items/tools/'
    save(pickaxe('#6f5235', '#a15c35', wrap_hex='#6b6a5e', crude=True), d + 'pickaxe_1.png')
    save(pickaxe('#7a5a38', '#8e979b'), d + 'pickaxe_2.png')
    save(pickaxe('#5e4630', '#6d777c', wrap_hex='#1e1e1e', paint='#9a3428'), d + 'pickaxe_3.png')
    save(drill('#5d676c', '#c9a227'), d + 'drill_1.png')
    save(drill('#c9a227', '#2a2a26'), d + 'drill_2.png')


if __name__ == '__main__':
    build()
    print('ferramentas v5 ok')
