import base64 as b64, zlib, re
import sys

def load(path):
    content = open(path).read()
    m = re.search(r'<layer[^>]*name="([^"]+)"[^>]*>(.*?)</layer>', content, re.S)
    name, body = m.group(1), m.group(2)
    dm = re.search(r'<data encoding="base64">\s*([A-Za-z0-9+/=\s]+?)\s*</data>', body, re.S)
    b64str = ''.join(dm.group(1).split())
    raw = b64.b64decode(b64str)
    try:
        dec = zlib.decompress(raw)
    except zlib.error:
        dec = raw
    w, h = 36, 23
    cols = {x: '' for x in range(w)}
    for y in range(h):
        for x in range(w):
            idx = (y * w + x) * 4
            g = int.from_bytes(dec[idx:idx + 4], 'little')
            cols[x] += '#' if ((g & 0x80000000) or g > 0) else '.'
    return cols, w, h

def ladders_from(path):
    content = open(path).read()
    m = re.search(r'<objectgroup[^>]*name="ladder"[^>]*>(.*?)</objectgroup>', content, re.S)
    if not m:
        return []
    body = m.group(1)
    rungs = []
    for om in re.finditer(r'<object\b[^>]*\bid="(\d+)"[^>]*\bx="(\d+(?:\.\d+)?)"[^>]*\by="(\d+(?:\.\d+)?)"', body):
        rungs.append((int(om.group(1)), int(float(om.group(2))), int(float(om.group(3)))))
    # group by column, then split into contiguous runs (gap > 32px breaks the column)
    cols = {}
    for oid, x, y in rungs:
        cols.setdefault(x, []).append(y)
    out = []
    for x in sorted(cols):
        bottoms = sorted(cols[x])  # ascending bottom edges, topmost rung first
        run = [bottoms[0]]
        for y in bottoms[1:]:
            if y - run[-1] > 32:
                top = run[0] - 32
                out.append((x, top, run[-1], len(run) * 32))
                run = []
            run.append(y)
        if run:
            out.append((x, run[0] - 32, run[-1], len(run) * 32))
    return out

def main():
    cols, w, h = load(sys.argv[1])
    # each ladder column: (xpx, top_px, bottom_px, hpx) merged from per-rung objects
    ladders = ladders_from(sys.argv[1])
    for x, top, bottom, h_ in ladders:
        col = x // 32
        r0, r1 = top // 32, bottom // 32
        print('ladder col=%3d rows %2d..%2d (x=%3d top=%3d bottom=%3d h=%3d) colMask=%s' %
              (col, r0, r1, x, top, bottom, h_, cols[col]))
        solid = [r for r in range(h) if cols[col][r] == '#']
        print('   solid rows at that col:', solid)

main()