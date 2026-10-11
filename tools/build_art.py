"""Gera TODA a arte do jogo na ordem certa (rodar sempre por aqui):

    python tools/build_art.py

1. gen_assets  — base (props, itens, ferramentas, UI, título)
2. tiles_v4    — pisos/paredes redesenhados + sombras de contato
3. rocks_v4    — rochas facetadas, minérios e contêineres
4. gen_v3      — personagens 16x32, trevo, HUD, ícones de talento, itens novos
5. decals_v4   — marcas de tensão (rastros, mãos, traje largado...)
6. polimento   — hue shift + contorno seletivo + limpeza em props/itens/ferramentas
"""
import glob
import os
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
os.chdir(HERE)

import gen_assets            # noqa: E402
import tiles_v4              # noqa: E402
import rocks_v4              # noqa: E402
import gen_v3                # noqa: E402
import decals_v4             # noqa: E402
import title_v5              # noqa: E402
import tools_v5              # noqa: E402
import props_v5              # noqa: E402
import enemies_v5            # noqa: E402
from normalize import normalize   # noqa: E402
from polish import polish_sprite   # noqa: E402
from PIL import Image        # noqa: E402

ASSETS = gen_assets.ASSETS
ALREADY_POLISHED = {'drag_marks', 'stain_dark', 'suit_torn', 'handprints', 'wall_writing', 'lamp_broken', 'miner_sitting'}
NO_SELOUT = {'puddle', 'puddle_rad', 'chalk_marks', 'shadow_figure'}


NO_NORMALIZE = ALREADY_POLISHED | {'puddle', 'puddle_rad', 'chalk_marks', 'candles', 'shadow_figure'}


def process_dir(rel, mode, skip_polish=(), skip_norm=(), polish_kw=None):
    """normaliza (borda/alfa/contorno) e depois pule cada sprite da pasta."""
    n = 0
    for f in sorted(glob.glob(os.path.join(ASSETS, rel, '*.png'))):
        name = os.path.splitext(os.path.basename(f))[0]
        img = Image.open(f).convert('RGBA')
        if name not in skip_norm:
            img = normalize(img, mode)
        if name not in skip_polish:
            img = polish_sprite(img, selout=name not in NO_SELOUT, **(polish_kw or {}))
        img.save(f)
        n += 1
    return n


def main():
    t0 = time.time()
    gen_assets.build_tiles(); gen_assets.build_rocks(); gen_assets.build_tools()
    gen_assets.build_items(); gen_assets.build_props(); gen_assets.build_ui()
    tiles_v4.build()
    rocks_v4.build()
    gen_v3.build_rad_icons(); gen_v3.build_player(); gen_v3.build_npcs()
    gen_v3.build_plate(); gen_v3.perk_icons(); gen_v3.build_light_cone(); gen_v3.build_workbench(); gen_v3.build_new_items()
    decals_v4.build()
    title_v5.build()
    # arte antiga que o jogo não usa mais (substituída pela v0.4)
    import shutil
    shutil.rmtree(os.path.join(ASSETS, 'ui', 'title'), ignore_errors=True)   # tela de título antiga (v0.4)
    for rel in ('ui/title_bg.png', 'ui/icon_money.png', 'items/note.png'):
        for f in (os.path.join(ASSETS, rel), os.path.join(ASSETS, rel) + '.import'):
            if os.path.exists(f):
                os.remove(f)
    tools_v5.build()
    props_v5.build()
    enemies_v5.build()
    cracks = {'cracks_1', 'cracks_2', 'cracks_3'}
    n = process_dir('environment/props', 'pad', ALREADY_POLISHED, NO_NORMALIZE)
    n += process_dir('environment/rocks', 'pad', cracks, cracks, {'denoise': False, 'hue': False})
    n += process_dir('items', 'center')
    n += process_dir('items/tools', 'none', polish_kw={'denoise': False})
    print('arte completa em %.1fs | sprites polidos: %d' % (time.time() - t0, n))


if __name__ == '__main__':
    main()
