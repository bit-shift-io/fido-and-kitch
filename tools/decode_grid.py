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

def main():
    cols, w, h = load(sys.argv[1])
    # ladder list: (id, x, y, wpx, hpx) from ll2.tmx ladder layer
    ladders = [(9,608,256,32,96),(10,352,288,32,224),(12,416,96,32,224),
               (13,64,96,32,96),(14,192,96,32,96),(15,192,320,32,128),
               (16,128,192,32,128),(17,0,192,32,128),(18,96,448,32,128),
               (19,224,448,32,136),(20,608,544,32,168),(21,896,544,32,64),
               (22,1024,608,32,96)]
    for lid, x, y, w_, h_ in ladders:
        col = x // 32
        r0, r1 = y // 32, (y + h_) // 32
        print('ladder id=%2d col=%2d rows %2d..%2d (x=%3d y=%3d h=%3d) colMask=%s' %
              (lid, col, r0, r1, x, y, h_, cols[col]))
        solid = [r for r in range(h) if cols[col][r] == '#']
        print('   solid rows at that col:', solid)

main()