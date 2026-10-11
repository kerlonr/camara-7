"""Backup do projeto (código, dados, arte, ferramentas) + cópia do save em Documentos\\ChernobylMiner-backup.
Uso: python tools/backup.py      (só LÊ o save real; nunca escreve nele)
"""
import json
import os
import shutil
import time
import zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEST = os.path.join(os.path.expanduser('~'), 'Documents', 'ChernobylMiner-backup')
SKIP = {'.godot', 'dist', '__pycache__', 'installer/build'}


def main():
    os.makedirs(DEST, exist_ok=True)
    version = json.load(open(os.path.join(ROOT, 'data', 'config', 'game.json'), encoding='utf-8'))['version']
    out = os.path.join(DEST, 'chernobyl-miner-v%s-projeto.zip' % version)
    n = 0
    with zipfile.ZipFile(out, 'w', zipfile.ZIP_DEFLATED) as z:
        for dp, dn, fn in os.walk(ROOT):
            rel = os.path.relpath(dp, ROOT).replace('\\', '/')
            rel = '' if rel == '.' else rel
            dn[:] = [d for d in dn if d not in SKIP and (rel + '/' + d).lstrip('/') not in SKIP]
            for f in fn:
                z.write(os.path.join(dp, f), 'chernobyl-miner/' + (rel + '/' if rel else '') + f)
                n += 1
    with zipfile.ZipFile(out) as z:
        bad = z.testzip()
    save = os.path.join(os.environ.get('APPDATA', ''), 'Godot', 'app_userdata', 'Chernobyl Miner — Prototype', 'saves', 'slot_1.json')
    if os.path.exists(save):
        shutil.copy2(save, os.path.join(DEST, 'slot_1-%s-v%s.json' % (time.strftime('%Y-%m-%d'), version)))
    print('backup: %s | %d arquivos | %.1f MB | integridade %s' % (out, n, os.path.getsize(out) / 1e6, 'ok' if bad is None else bad))


if __name__ == '__main__':
    main()
