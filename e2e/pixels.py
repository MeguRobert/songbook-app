#!/usr/bin/env python3
"""How many distinct colours are in this screenshot, and how flat is it?

The bug this guards drew a single grey rectangle where the music should be, with
a correct widget tree around it — so the only honest assertion is about pixels.
Reads PNG without a dependency: zlib-inflate the IDAT and undo the per-row
filters.
"""
import collections, json, struct, sys, zlib

def rows(path):
    data = open(path, 'rb').read()
    assert data[:8] == b'\x89PNG\r\n\x1a\n', 'not a png'
    pos, idat, w, h, depth, ctype = 8, b'', 0, 0, 0, 0
    while pos < len(data):
        (length,) = struct.unpack('>I', data[pos:pos + 4])
        kind = data[pos + 4:pos + 8]
        body = data[pos + 8:pos + 8 + length]
        if kind == b'IHDR':
            w, h, depth, ctype = struct.unpack('>IIBB', body[:10])
        elif kind == b'IDAT':
            idat += body
        elif kind == b'IEND':
            break
        pos += 12 + length
    assert depth == 8, f'unexpected bit depth {depth}'
    channels = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}[ctype]
    raw = zlib.decompress(idat)
    stride = w * channels
    out, prev = [], bytearray(stride)
    at = 0
    for _ in range(h):
        f = raw[at]; at += 1
        line = bytearray(raw[at:at + stride]); at += stride
        if f == 1:
            for i in range(channels, stride):
                line[i] = (line[i] + line[i - channels]) & 0xFF
        elif f == 2:
            for i in range(stride):
                line[i] = (line[i] + prev[i]) & 0xFF
        elif f == 3:
            for i in range(stride):
                left = line[i - channels] if i >= channels else 0
                line[i] = (line[i] + ((left + prev[i]) >> 1)) & 0xFF
        elif f == 4:
            for i in range(stride):
                a = line[i - channels] if i >= channels else 0
                b = prev[i]
                c = prev[i - channels] if i >= channels else 0
                pa, pb, pc = abs(b - c), abs(a - c), abs(a + b - 2 * c)
                pred = a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
                line[i] = (line[i] + pred) & 0xFF
        out.append((bytes(line), channels))
        prev = line
    return out

counts = collections.Counter()
for line, ch in rows(sys.argv[1]):
    for i in range(0, len(line), ch):
        counts[line[i:i + 3]] += 1
total = sum(counts.values())
dominant = counts.most_common(1)[0][1]
print(json.dumps({
    'distinct': len(counts),
    'dominantShare': round(dominant * 100 / total, 1),
}))
