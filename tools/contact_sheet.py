"""Gera uma folha de contato ampliada de todos os PNGs (para revisar a arte)."""
import glob, sys
from PIL import Image
out = sys.argv[1] if len(sys.argv) > 1 else 'contact.png'
files = [f for f in sorted(glob.glob('assets/**/*.png', recursive=True)) if 'title_bg' not in f and 'light_' not in f]
S, W = 3, 1400
x = y = rowh = 0; pos = []
for f in files:
    im = Image.open(f); w, h = im.width * S, im.height * S
    if x + w > W: x = 0; y += rowh + 6; rowh = 0
    pos.append((f, x, y, w, h)); x += w + 6; rowh = max(rowh, h)
sheet = Image.new('RGBA', (W, y + rowh + 6), (120, 110, 100, 255))
for f, x, y, w, h in pos:
    sheet.alpha_composite(Image.open(f).convert('RGBA').resize((w, h), Image.NEAREST), (x, y))
sheet.save(out); print(sheet.size)
