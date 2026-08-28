#!/usr/bin/env python3
"""Embed each res/editor/*.tj template's external tileset (.tsj) inline, then
delete the .tsj. Mirrors the manual embed done in key.tj: the template's
`tileset` object keeps its `firstgid` and gains all of the .tsj's tileset
fields so Tiled no longer needs the external file.

Run from the repo root:

    python tools/embed_editor_tilesets.py [dir]

The directory defaults to res/editor. Only .tj files whose tileset references
a matching .tsj (same basename, .tsj extension) are rewritten. A .tsj with no
pairing .tj (e.g. tileset_generic_platformer_tiles.tsj) is left untouched.
The script is idempotent: already-embedded templates (no `source`) are skipped.
"""
import json
import os
import sys
from pathlib import Path


def embed(editor_dir):
    editor_dir = Path(editor_dir)
    rewritten, removed = [], []
    for tj_path in sorted(editor_dir.glob('*.tj')):
        try:
            tj = json.loads(tj_path.read_text())
        except json.JSONDecodeError as e:
            print(f'skip {tj_path.name}: invalid JSON ({e})')
            continue
        if tj.get('type') != 'template' or not isinstance(tj.get('tileset'), dict):
            print(f'skip {tj_path.name}: not a template with a tileset')
            continue
        ts = tj['tileset']
        source = ts.get('source')
        if not source:
            print(f'skip {tj_path.name}: tileset already embedded (no source)')
            continue
        tsj_path = (editor_dir / source).resolve()
        if not tsj_path.is_file():
            print(f'!! {tj_path.name}: referenced {source} not found; leaving as-is')
            continue
        tsj = json.loads(tsj_path.read_text())
        firstgid = ts.get('firstgid', 1)
        embedded = dict(tsj)
        embedded['firstgid'] = firstgid
        tj['tileset'] = embedded
        tj_path.write_text(json.dumps(tj, indent=2) + '\n')
        rewritten.append(tj_path.name)
        tsj_path.unlink()
        removed.append(tsj_path.name)
        print(f'embedded {tsj_path.name} into {tj_path.name}')
    return rewritten, removed


def main():
    editor_dir = sys.argv[1] if len(sys.argv) > 1 else 'res/editor'
    if not os.path.isdir(editor_dir):
        print(f'not a directory: {editor_dir}', file=sys.stderr)
        return 1
    rewritten, removed = embed(editor_dir)
    print(f'\n{len(rewritten)} template(s) rewritten, {len(removed)} tileset(s) removed')
    return 0


if __name__ == '__main__':
    sys.exit(main())
