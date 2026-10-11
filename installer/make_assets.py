"""Gera as imagens e textos do instalador (.msi): faixa, painel lateral, licença RTF e LEIA-ME."""
import json
import os

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
OUT = os.path.join(HERE, 'build')
os.makedirs(OUT, exist_ok=True)
VERSION = json.load(open(os.path.join(ROOT, 'data', 'config', 'game.json'), encoding='utf-8'))['version']

_t = os.path.join(ROOT, 'assets', 'ui', 'title5')
bg = Image.open(os.path.join(_t, 'sky.png')).convert('RGBA')
bg.alpha_composite(Image.open(os.path.join(_t, 'beam.png')).convert('RGBA'), (586 - 35, 0))
for _n in ('city', 'plant', 'mid', 'front'):
    bg.alpha_composite(Image.open(os.path.join(_t, _n + '.png')).convert('RGBA'))
bg.alpha_composite(Image.open(os.path.join(_t, 'hero.png')).convert('RGBA').crop((0, 0, 56, 108)), (440, 240))
bg = bg.crop((80, 30, 720, 390)).convert('RGB')
icon = Image.open(os.path.join(ROOT, 'assets', 'ui', 'icon_256.png')).convert('RGBA')

# painel das telas de boas-vindas/fim: 493x312, arte à esquerda (o texto do WiX fica à direita)
dlg = Image.new('RGB', (493, 312), (236, 233, 222))
art = bg.crop((330, 0, 330 + 207, 360)).resize((164, 312), Image.NEAREST)
dlg.paste(art, (0, 0))
ic = icon.resize((96, 96), Image.LANCZOS)
dlg.paste(ic, (34, 40), ic)
d = ImageDraw.Draw(dlg)
d.rectangle((164, 0, 165, 312), fill=(40, 38, 30))
dlg.save(os.path.join(OUT, 'dialog.bmp'))

# faixa superior das telas internas: 493x58, ícone à direita
ban = Image.new('RGB', (493, 58), (246, 244, 238))
ic = icon.resize((44, 44), Image.LANCZOS)
ban.paste(ic, (493 - 52, 7), ic)
ImageDraw.Draw(ban).rectangle((0, 57, 493, 58), fill=(160, 150, 120))
ban.save(os.path.join(OUT, 'banner.bmp'))


def rtf_escape(s):
    out = []
    for ch in s:
        if ch in '\\{}':
            out.append('\\' + ch)
        elif ord(ch) < 128:
            out.append(ch)
        else:
            out.append("\\'%02x" % ch.encode('cp1252')[0])
    return ''.join(out)


TERMS = [
    ('b', 'Câmara 7 — versão %s' % VERSION),
    ('', ''),
    ('', 'Projeto independente, sem fins lucrativos, feito para jogar entre amigos.'),
    ('', ''),
    ('', 'É uma obra de FICÇÃO inspirada na Zona de Exclusão de Chernobyl (1986). '
         'Personagens, a mina, o "Turno C", o Instituto nº 7 e os fenômenos são inventados. '
         'Fatos históricos citados (o acidente de 26/04/1986, a evacuação de Pripyat, o desfile '
         'de 1º de Maio em Kyiv) aparecem parafraseados e marcados como tal dentro do jogo.'),
    ('', ''),
    ('', 'Em memória das pessoas afetadas pelo desastre.'),
    ('', ''),
    ('', 'O jogo é fornecido "como está", sem garantias. Os saves ficam em '
         '%APPDATA%\\Godot\\app_userdata e não são apagados ao desinstalar.'),
    ('', ''),
    ('', 'O jogo procura atualizações em github.com/kerlonr/camara-7 ao abrir (dá para desligar em Opções).'),
    ('', ''),
    ('', 'Feito com o motor Godot (licença MIT, godotengine.org).'),
]
lines = []
for style, text in TERMS:
    t = rtf_escape(text)
    lines.append(('{\\b ' + t + '}' if style == 'b' else t) + '\\par')
rtf = '{\\rtf1\\ansi\\ansicpg1252\\deff0{\\fonttbl{\\f0 Segoe UI;}}\\f0\\fs18 ' + '\n'.join(lines) + '}'
open(os.path.join(OUT, 'license.rtf'), 'w', encoding='ascii').write(rtf)

readme = f"""CÂMARA 7  v{VERSION}
=================

Ficção de mineração e sobrevivência na Zona de Exclusão, abril/maio de 1986.

CONTROLES
  WASD ........ andar            SHIFT ...... correr
  Mouse esq. .. minerar / usar   E .......... interagir
  TAB ......... mochila          K .......... talentos
  J ........... diário           1-9 / roda . barra rápida
  ESC ......... menu             F11 ........ tela cheia
  F ........... lanterna liga/desliga

DICAS
  - Desça pela escada no chão; a escada na parede volta para a base.
  - A radiação acumula. Use o chuveiro de descontaminação na base.
  - Contratos no terminal pagam mais que vender no balcão.
  - Suba de nível e escolha talentos (alguns têm um preço).
  - A lanterna gasta bateria. Leve pilhas extras.

ATUALIZAÇÕES
  O jogo baixa atualizações sozinho ao abrir e aplica quando você fecha
  (ou em "Reiniciar e atualizar" na tela inicial). Dá para desligar em Opções.

SAVES
  %APPDATA%\\Godot\\app_userdata\\Chernobyl Miner — Prototype\\saves
  Desinstalar o jogo NÃO apaga seus saves.
"""
open(os.path.join(OUT, 'LEIA-ME.txt'), 'w', encoding='utf-8-sig').write(readme)
print('assets do instalador ok', VERSION)
