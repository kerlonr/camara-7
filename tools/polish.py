"""Polimento de pixel art (v0.4).

Técnicas (ver docs/REFERENCIAS.md → "Arte"):
  * hue shifting — sombras puxam para o frio (azul/violeta), luzes para o quente (âmbar);
  * selective outline (sel-out) — o contorno vira um tom escuro da cor vizinha, quase preto só
    no lado da sombra (baixo/direita); em cima/esquerda fica mais claro, o que "arredonda" a forma;
  * limpeza de pixels órfãos — ruído de 1 px com pouco contraste some (arte mais "lisa");
  * luz de borda — 1 px mais claro no topo das formas (luz vem de cima/esquerda).

Uso:  polish_sprite(img) -> img      hramp('#7a6a50', 5) -> rampa com hue shift
"""
import colorsys

SOLID = 200          # alfa mínimo para contar como parte do sprite (sombras projetadas são < 200)
COOL = 0.66          # matiz para onde as sombras puxam (azul-violeta)
WARM = 0.11          # matiz para onde as luzes puxam (âmbar)


def clamp(v, lo=0.0, hi=1.0):
    return lo if v < lo else hi if v > hi else v


def hsv(c):
    return colorsys.rgb_to_hsv(c[0] / 255, c[1] / 255, c[2] / 255)


def rgb(h, s, v, a=255):
    r, g, b = colorsys.hsv_to_rgb(h % 1.0, clamp(s), clamp(v))
    return (int(r * 255 + .5), int(g * 255 + .5), int(b * 255 + .5), a)


def lum(c):
    return (0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]) / 255


def toward(h, target, amount):
    """Gira o matiz h em direção a target pelo arco mais curto (amount em voltas)."""
    d = ((target - h + 0.5) % 1.0) - 0.5
    step = max(-abs(amount), min(abs(amount), d))
    return (h + step) % 1.0


def shade(c, k):
    """k < 0 escurece (frio), k > 0 clareia (quente). |k| ~ 0..1."""
    h, s, v = hsv(c)
    if s < 0.04:                     # cinzas ganham um matiz leve para não ficarem "mortos"
        h = COOL if k < 0 else WARM
        s = 0.04
    if k < 0:
        h = toward(h, COOL, 0.055 * -k)
        s = s + 0.10 * -k
        v = v * (1 + 0.62 * k)
    else:
        h = toward(h, WARM, 0.04 * k)
        s = s - 0.08 * k
        v = v + (1 - v) * 0.35 * k + 0.10 * k
    return rgb(h, s, v, c[3] if len(c) > 3 else 255)


def hramp(base, n=5, spread=1.0):
    """Rampa clara→escura com hue shift. base: '#rrggbb' ou tupla."""
    if isinstance(base, str):
        b = base.lstrip('#')
        base = (int(b[0:2], 16), int(b[2:4], 16), int(b[4:6], 16), 255)
    out = []
    mid = (n - 1) / 2
    for i in range(n):
        k = (mid - i) / max(1, mid) * spread
        out.append(shade(base, k) if abs(k) > 1e-6 else base)
    return out


# ------------------------------------------------------------------ passes
def _solid(img, x, y):
    if 0 <= x < img.width and 0 <= y < img.height:
        return img.getpixel((x, y))[3] >= SOLID
    return False


def _is_outline(img, x, y, src):
    c = src[y][x]
    if c[3] < SOLID or lum(c) > 0.13:
        return False
    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        xx, yy = x + dx, y + dy
        if not (0 <= xx < img.width and 0 <= yy < img.height) or src[yy][xx][3] < SOLID:
            return True
    return False


def polish_sprite(img, selout=True, denoise=True, hue=True, rim=True, keep_glow=True):
    img = img.convert('RGBA').copy()
    W, H = img.size
    src = [[img.getpixel((x, y)) for x in range(W)] for y in range(H)]
    outline = [[_is_outline(img, x, y, src) for x in range(W)] for y in range(H)]
    interior = [[src[y][x][3] >= SOLID and not outline[y][x] for x in range(W)] for y in range(H)]

    def glow(c):
        h, s, v = hsv(c)
        return keep_glow and s > 0.55 and v > 0.78

    # 1) pixels órfãos de baixo contraste -> cor dominante da vizinhança
    if denoise:
        cur = [row[:] for row in src]
        for y in range(1, H - 1):
            for x in range(1, W - 1):
                if not interior[y][x]:
                    continue
                c = src[y][x]
                neigh = [src[y + dy][x + dx] for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))
                         if interior[y + dy][x + dx]]
                if len(neigh) < 4 or c in neigh:
                    continue
                counts = {}
                for n in neigh:
                    counts[n] = counts.get(n, 0) + 1
                dom, k = max(counts.items(), key=lambda t: t[1])
                if k >= 3 and abs(lum(dom) - lum(c)) < 0.07 and not glow(c):
                    cur[y][x] = dom
        src = cur

    # 2) hue shift relativo à luminância média do sprite
    if hue:
        ls = [lum(src[y][x]) for y in range(H) for x in range(W) if interior[y][x]]
        m = sum(ls) / len(ls) if ls else 0.5
        for y in range(H):
            for x in range(W):
                if not interior[y][x] or glow(src[y][x]):
                    continue
                c = src[y][x]
                d = lum(c) - m
                h, s, v = hsv(c)
                if s < 0.03 and abs(d) < 0.02:
                    continue
                if d < 0:
                    h = toward(h, COOL, min(0.045, -d * 0.16)) if s > 0.03 else COOL
                    s = max(s, 0.05) + min(0.06, -d * 0.2)
                else:
                    h = toward(h, WARM, min(0.035, d * 0.12)) if s > 0.03 else WARM
                    s = max(s, 0.03)
                src[y][x] = rgb(h, s, v, c[3])

    out = [row[:] for row in src]
    # 3) luz de borda: topo das formas
    if rim:
        for y in range(1, H):
            for x in range(W):
                if interior[y][x] and (outline[y - 1][x] or src[y - 1][x][3] < SOLID):
                    c = src[y][x]
                    if lum(c) < 0.75 and not glow(c):
                        out[y][x] = shade(c, 0.28)

    # 4) contorno seletivo
    if selout:
        for y in range(H):
            for x in range(W):
                if not outline[y][x]:
                    continue
                cols, sides = [], []
                for dx, dy in ((0, 1), (1, 0), (-1, 0), (0, -1)):
                    xx, yy = x + dx, y + dy
                    if 0 <= xx < W and 0 <= yy < H and interior[yy][xx]:
                        cols.append(src[yy][xx])
                        sides.append((dx, dy))
                if not cols:
                    continue
                r = sum(c[0] for c in cols) // len(cols)
                g = sum(c[1] for c in cols) // len(cols)
                b = sum(c[2] for c in cols) // len(cols)
                avg = (r, g, b, 255)
                # contorno embaixo/direita da forma = lado da sombra (mais escuro)
                shadow_side = any(s in ((0, -1), (-1, 0)) for s in sides)
                light_side = any(s in ((0, 1), (1, 0)) for s in sides) and not shadow_side
                k = -0.86 if shadow_side else (-0.62 if light_side else -0.74)
                o = shade(avg, k)
                o = (min(o[0], 70), min(o[1], 66), min(o[2], 72), 255)
                out[y][x] = o
    for y in range(H):
        for x in range(W):
            img.putpixel((x, y), out[y][x])
    return img
