"""Auditoria automática da arte (roda depois de build_art.py).

Para cada PNG em assets/ verifica:
  cortado    pixels opacos encostando na borda da imagem (sprite cortado) — exceto tiles/efeitos/fundos
  órfãos     pixels opacos isolados (nenhum vizinho opaco em 8 direções) — sujeira
  alfa sujo  pixels semitransparentes fora de sombras/efeitos (alfa entre 20 e 199 longe da base)
  vazio      imagem sem nenhum pixel visível
  folha      folhas de animação com tamanho que não divide pelo quadro esperado
Também confere se todo sprite citado em data/*.json existe.
Uso: python tools/audit_art.py   (sai com código 1 se houver erro grave)
"""
import glob
import json
import os
import re
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
A = os.path.join(ROOT, 'assets')

EDGE_OK = ('tiles', 'effects', 'ui' + os.sep + 'title', 'title', 'plate', 'panel', 'crt', 'slot', 'button', 'perk_icons',
           'icon_256', 'icon.png', 'cursor')
ALPHA_OK = ('effects', 'title', 'shadow', 'puddle', 'decal', 'drag_marks', 'stain_dark', 'handprints', 'wall_writing',
            'chalk', 'plate', 'tiles', 'icon_256', 'icon.png', 'suit_torn', 'fog', 'beam', 'glow')
SHEETS = {'characters/player': (16, 32, 7, 3), 'characters/npc': (16, 32, 2, 1), 'characters/enemies': (4, 4, 0, 0)}


def check(path):
    rel = os.path.relpath(path, A).replace('\\', '/')
    img = Image.open(path).convert('RGBA')
    w, h = img.size
    px = img.load()
    issues = []
    solid = [[px[x, y][3] >= 200 for x in range(w)] for y in range(h)]
    if not any(any(r) for r in solid) and not any(px[x, y][3] > 0 for x in range(w) for y in range(h)):
        issues.append(('ERRO', 'vazio'))
        return rel, issues
    if not any(k in rel for k in EDGE_OK):
        def body(x, y):     # pixel opaco que NÃO é contorno (contorno na borda é aceitável)
            c = px[x, y]
            return c[3] >= 200 and (0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]) / 255 > 0.16
        edge = sum(1 for x in range(w) if body(x, 0)) + sum(1 for y in range(h) if body(0, y) or body(w - 1, y))
        if edge > 0 and not rel.startswith('characters'):
            issues.append(('aviso', 'encosta na borda (%d px) — pode estar cortado' % edge))
    orphans = 0
    for y in range(h):
        for x in range(w):
            if solid[y][x]:
                if not any(0 <= x + dx < w and 0 <= y + dy < h and solid[y + dy][x + dx]
                           for dx in (-1, 0, 1) for dy in (-1, 0, 1) if dx or dy):
                    orphans += 1
    if orphans > max(2, w * h // 400) and not any(k in rel for k in ('effects', 'title', 'tiles')):
        issues.append(('aviso', '%d pixels soltos' % orphans))
    if not any(k in rel for k in ALPHA_OK):
        semi = 0
        for y in range(h - 4):                     # as 4 linhas de baixo podem ter sombra projetada
            for x in range(w):
                a = px[x, y][3]
                if 20 < a < 200:
                    semi += 1
        if semi > 6:
            issues.append(('aviso', '%d pixels semitransparentes no corpo' % semi))
    for d, (fw, fh, cols, rows) in SHEETS.items():
        if rel.startswith(d):
            if w % fw or h % fh:
                issues.append(('ERRO', 'folha %dx%d não divide em quadros %dx%d' % (w, h, fw, fh)))
            elif cols and (w // fw != cols or h // fh != rows):
                issues.append(('ERRO', 'folha com %dx%d quadros, esperado %dx%d' % (w // fw, h // fh, cols, rows)))
    return rel, issues


def referenced_sprites():
    missing = []
    for f in glob.glob(os.path.join(ROOT, 'data', '**', '*.json'), recursive=True):
        s = open(f, encoding='utf-8').read()
        for m in re.findall(r'res://(assets/[^"]+?\.png)', s):
            if not os.path.exists(os.path.join(ROOT, m)):
                missing.append((os.path.relpath(f, ROOT), m))
    for f in glob.glob(os.path.join(ROOT, 'scripts', '**', '*.gd'), recursive=True) + \
            glob.glob(os.path.join(ROOT, 'autoload', '*.gd')):
        s = open(f, encoding='utf-8').read()
        for m in re.findall(r'"res://(assets/[^"%]+?\.(?:png|wav))"', s):
            if not os.path.exists(os.path.join(ROOT, m)):
                missing.append((os.path.relpath(f, ROOT), m))
    return missing


def main():
    errors = 0
    warns = 0
    for f in sorted(glob.glob(os.path.join(A, '**', '*.png'), recursive=True)):
        rel, issues = check(f)
        for level, msg in issues:
            print('%-6s %-48s %s' % (level, rel, msg))
            errors += level == 'ERRO'
            warns += level == 'aviso'
    for src, m in referenced_sprites():
        print('ERRO   %-48s citado em %s mas não existe' % (m, src))
        errors += 1
    print('\nauditoria: %d erro(s), %d aviso(s)' % (errors, warns))
    return 1 if errors else 0


if __name__ == '__main__':
    sys.exit(main())
