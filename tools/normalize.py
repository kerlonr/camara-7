"""Normalização de sprites (v0.5) — roda ANTES do polimento.

Corrige os defeitos sistemáticos achados por tools/audit_art.py:
  * desenho encostado na borda da imagem -> contorno cortado   (make_room)
  * pixels semitransparentes dentro do corpo -> "furos"          (fix_alpha)
  * pixels soltos                                                 (remove_orphans)
  * contorno faltando em algum lado                               (complete_outline)
"""
from PIL import Image

SOLID = 200
INK = (20, 18, 16, 255)


def _lum(c):
    return (0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]) / 255


def fix_alpha(img):
    img = img.copy()
    w, h = img.size
    p = img.load()
    src = [[p[x, y] for x in range(w)] for y in range(h)]
    for y in range(h):
        for x in range(w):
            c = src[y][x]
            if not (12 < c[3] < SOLID):
                continue
            neigh = [src[yy][xx] for xx, yy in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1))
                     if 0 <= xx < w and 0 <= yy < h and src[yy][xx][3] >= SOLID]
            if len(neigh) >= 3:
                # pixel de sujeira pintado com alfa dentro do corpo: compõe sobre a cor vizinha
                r = sum(n[0] for n in neigh) / len(neigh)
                g = sum(n[1] for n in neigh) / len(neigh)
                b = sum(n[2] for n in neigh) / len(neigh)
                a = c[3] / 255
                p[x, y] = (int(c[0] * a + r * (1 - a)), int(c[1] * a + g * (1 - a)), int(c[2] * a + b * (1 - a)), 255)
            elif len(neigh) <= 1 and _lum(c) > 0.2:
                p[x, y] = (0, 0, 0, 0)                      # névoa clara solta (não é sombra)
    return img


def remove_orphans(img):
    img = img.copy()
    w, h = img.size
    p = img.load()
    solid = [[p[x, y][3] >= SOLID for x in range(w)] for y in range(h)]
    for y in range(h):
        for x in range(w):
            if solid[y][x] and not any(0 <= x + dx < w and 0 <= y + dy < h and solid[y + dy][x + dx]
                                       for dx in (-1, 0, 1) for dy in (-1, 0, 1) if dx or dy):
                p[x, y] = (0, 0, 0, 0)
    return img


def bbox_solid(img):
    w, h = img.size
    p = img.load()
    xs = [x for y in range(h) for x in range(w) if p[x, y][3] >= SOLID]
    ys = [y for y in range(h) for x in range(w) if p[x, y][3] >= SOLID]
    if not xs:
        return None
    return min(xs), min(ys), max(xs), max(ys)


def make_room(img, mode):
    """mode 'center': recentraliza dentro do mesmo tamanho se couber com 1px de folga.
    mode 'pad': aumenta a imagem 1px nos lados encostados (esq./dir. simétricos, topo).
    A base nunca muda (props e rochas são ancorados pelo pé)."""
    w, h = img.size
    bb = img.getbbox()
    if bb is None:
        return img
    x0, y0, x1, y1 = bb[0], bb[1], bb[2] - 1, bb[3] - 1
    touch_l, touch_r, touch_t = x0 == 0, x1 == w - 1, y0 == 0
    if mode == 'none' or not (touch_l or touch_r or touch_t):
        return img
    if mode == 'center':
        bw, bh = x1 - x0 + 1, y1 - y0 + 1
        if bw <= w - 2 and bh <= h - 2:
            out = Image.new('RGBA', (w, h), (0, 0, 0, 0))
            nx = (w - bw) // 2
            ny = min(max(1, y0), h - 1 - bh)
            out.paste(img.crop((x0, y0, x1 + 1, y1 + 1)), (nx, ny))
            return out
        mode = 'pad'
    side = 1 if (touch_l or touch_r) else 0
    top = 1 if touch_t else 0
    out = Image.new('RGBA', (w + side * 2, h + top), (0, 0, 0, 0))
    out.paste(img, (side, top))
    return out


def complete_outline(img):
    img = img.copy()
    w, h = img.size
    p = img.load()
    src = [[p[x, y] for x in range(w)] for y in range(h)]
    for y in range(h):
        for x in range(w):
            if src[y][x][3] >= SOLID:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                xx, yy = x + dx, y + dy
                if 0 <= xx < w and 0 <= yy < h:
                    n = src[yy][xx]
                    if n[3] >= SOLID and _lum(n) > 0.14:
                        # vizinho claro sem contorno entre ele e o vazio: o contorno faltava
                        p[x, y] = INK
                        break
    return img


def normalize(img, mode='pad', outline=True):
    img = fix_alpha(img.convert('RGBA'))
    img = remove_orphans(img)
    img = make_room(img, mode)
    if outline:
        img = complete_outline(img)
    return img
