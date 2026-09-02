#!/usr/bin/env python3
"""Reverse of embed_editor_tilesets.py: split each res/entities/*.tj template's
embedded tileset back out into an external .tsj file, and replace the inline
`tileset` object in the .tj with a source reference.

For each template whose `tileset` is embedded (has tile data and NO `source`),
the script:
  1. extracts the tileset object,
  2. strips the map-local `firstgid` (it's reference info, not part of the
     tileset definition -- the external form puts it on the .tj's reference),
  3. writes it to a standalone `<basename>.tsj` next to the .tj, ensuring the
     resulting .tsj carries `"type": "tileset"` (Tiled requires it on external
     tilesets; a hand-authored embedded tileset may have omitted it),
  4. rewrites the .tj's `tileset` to `{ "source": "<basename>.tsj", "firstgid": N }`.

The runtime resolves both embedded and external tileset forms
(src/map/tj_template.lua); the template loader reads the .tsj to recover the
sprite's `tilesetImage` the same way it did from the embedded form, so a
template's art is preserved across the round-trip.

Run from the repo root:

    python tools/split_editor_tilesets.py [dir]

The directory defaults to res/entities. Only .tj files with an embedded tileset
(no `source`) are rewritten. The script is idempotent: templates whose tileset
already has a `source` are skipped. An existing <basename>.tsj is never
overwritten unless --force is passed. Standalone shared tilesets that aren't
derived from a .tj (e.g. tileset_generic_platformer_tiles.tsj) are never
touched or deleted.
"""
import argparse
import json
import os
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent


def normalize_tsj(tsj):
    """Fill the metadata fields a standalone Tiled .tsj needs to render.

    The embedded template tilesets were authored minimally and often omit the
    standard fields Tiled expects on an external tileset, which stops the
    editor from rendering the sprite. Fill missing fields with sensible
    defaults: tile dims default to 32, grid-discipline counters to 0.
    """
    tsj = dict(tsj)
    tsj.setdefault('type', 'tileset')
    tiles = tsj.get('tiles')
    if tiles and isinstance(tiles, list) and len(tiles) > 0:
        t = tiles[0]
        tile_w = t.get('width') or t.get('imagewidth')
        tile_h = t.get('height') or t.get('imageheight')
    else:
        tile_w = tile_h = None
    tsj.setdefault('tilewidth', tile_w or 32)
    tsj.setdefault('tileheight', tile_h or 32)
    tsj.setdefault('columns', 0)
    tsj.setdefault('margin', 0)
    tsj.setdefault('spacing', 0)
    tsj.setdefault('version', '1.11')
    tsj.setdefault('tiledversion', '1.12.2')
    return tsj


def split(entities_dir, force=False):
    entities_dir = Path(entities_dir)
    rewritten, written = [], []
    for tj_path in sorted(entities_dir.glob('*.tj')):
        try:
            tj = json.loads(tj_path.read_text())
        except json.JSONDecodeError as e:
            print(f'skip {tj_path.name}: invalid JSON ({e})')
            continue
        if tj.get('type') != 'template' or not isinstance(tj.get('tileset'), dict):
            print(f'skip {tj_path.name}: not a template with a tileset')
            continue
        ts = tj['tileset']
        tsj_path = entities_dir / f'{tj_path.stem}.tsj'

        if ts.get('source'):
            # Already external. Without --force we leave it alone; with
            # --force we re-read the referenced .tsj and re-normalize it so a
            # stale, minimally-authored file can be fixed up in place without
            # needing to re-embed first.
            if not force:
                print(f'skip {tj_path.name}: tileset already external (has source)')
                continue
            if not tsj_path.is_file():
                print(f'!! {tj_path.name}: referenced {tsj_path.name} missing; skipping')
                continue
            try:
                existing = json.loads(tsj_path.read_text())
            except json.JSONDecodeError as e:
                print(f'!! {tsj_path.name}: invalid JSON ({e}); skipping')
                continue
            tsj = normalize_tsj(existing)
            tsj_path.write_text(json.dumps(tsj, indent=2) + '\n')
            written.append(tsj_path.name)
            print(f'normalized {tsj_path.name}')
            continue

        firstgid = ts.get('firstgid', 1)
        if tsj_path.is_file() and not force:
            print(f'!! {tsj_path.name} already exists; leaving {tj_path.name} as-is '
                  f'(pass --force to overwrite)')
            continue
        tsj = normalize_tsj({k: v for k, v in ts.items() if k != 'firstgid'})
        tsj_path.write_text(json.dumps(tsj, indent=2) + '\n')
        tj['tileset'] = {'source': tsj_path.name, 'firstgid': firstgid}
        tj_path.write_text(json.dumps(tj, indent=2) + '\n')
        rewritten.append(tj_path.name)
        written.append(tsj_path.name)
        print(f'split {tj_path.name}: {tsj_path.name}')
    return rewritten, written


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    default_dir = str(REPO_ROOT / 'res/entities')
    parser.add_argument('dir', nargs='?', default=default_dir,
                        help='template directory (default: res/entities)')
    parser.add_argument('--force', action='store_true',
                        help='overwrite an existing <basename>.tsj')
    args = parser.parse_args(argv)
    if not os.path.isdir(args.dir):
        print(f'not a directory: {args.dir}', file=sys.stderr)
        return 1
    rewritten, written = split(args.dir, force=args.force)
    print(f'\n{len(rewritten)} template(s) rewritten, {len(written)} tileset(s) written')
    return 0


if __name__ == '__main__':
    sys.exit(main())