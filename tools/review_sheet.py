"""Folhas de revisão visual: cada sprite sobre o chão do jogo, ampliado, com o nome embaixo.
python tools/review_sheet.py <pasta_saida>"""
import glob, json, os, sys
from PIL import Image, ImageDraw
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
out_dir = sys.argv[1]
atlas = Image.open(os.path.join(ROOT, 'assets/environment/tiles/tileset.png')).convert('RGBA')
meta = json.load(open(os.path.join(ROOT, 'data/tiles/tiles.json'), encoding='utf-8'))['tiles']
def tile(n):
    c = meta[n]['coords']; return atlas.crop((c[0]*16, c[1]*16, c[0]*16+16, c[1]*16+16))
def sheet(files, name, floor='mine_floor', S=3, W=1500):
    cells = []
    for f in files:
        im = Image.open(f).convert('RGBA')
        w, h = im.width + 8, im.height + 8
        bg = Image.new('RGBA', (w, h))
        for y in range(0, h, 16):
            for x in range(0, w, 16):
                bg.paste(tile(floor), (x, y))
        bg.alpha_composite(im, (4, 4))
        cells.append((os.path.splitext(os.path.basename(f))[0], bg.resize((w*S, h*S), Image.NEAREST)))
    x = y = rowh = 0; pos = []
    for n, im in cells:
        if x + im.width > W: x = 0; y += rowh + 18; rowh = 0
        pos.append((x, y)); x += im.width + 6; rowh = max(rowh, im.height)
    out = Image.new('RGBA', (W, y + rowh + 18), (30, 28, 26, 255))
    d = ImageDraw.Draw(out)
    for (n, im), (x, y) in zip(cells, pos):
        out.paste(im, (x, y)); d.text((x + 2, y + im.height + 2), n, fill=(220, 210, 180))
    out.save(os.path.join(out_dir, name + '.png'))
if len(sys.argv) > 2:   # nomes específicos de props
    sheet([os.path.join(ROOT, 'assets/environment/props/%s.png' % n) for n in sys.argv[2:]], 'rv_custom', S=5)
    sys.exit(0)
P = sorted(glob.glob(os.path.join(ROOT, 'assets/environment/props/*.png')))
sheet(P[:26], 'rv_props1'); sheet(P[26:52], 'rv_props2'); sheet(P[52:], 'rv_props3', floor='grass')
sheet(sorted(glob.glob(os.path.join(ROOT, 'assets/environment/rocks/*.png'))), 'rv_rocks', S=5)
sheet(sorted(glob.glob(os.path.join(ROOT, 'assets/items/*.png'))) + sorted(glob.glob(os.path.join(ROOT, 'assets/items/tools/*.png'))), 'rv_items', floor='ind_floor', S=5)
print('ok')
