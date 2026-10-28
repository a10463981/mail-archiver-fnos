#!/usr/bin/env python3
"""纯 Python PNG 缩放（无 PIL 环境用）：只支持 8-bit RGBA/RGB、非隔行 PNG。
用途：把用户上传的 512x512 图标按整数倍盒式降采样到 256 与 64，保留透明通道。
用法： python3 png_resize.py <src.png> <dst.png> <size>
"""
import struct
import sys
import zlib


def read_png(path):
    data = open(path, 'rb').read()
    assert data[:8] == b'\x89PNG\r\n\x1a\n', 'not png'
    pos, idat, w, h, bit, ctype = 8, b'', 0, 0, 0, 0
    while pos < len(data):
        ln = struct.unpack('>I', data[pos:pos + 4])[0]
        typ = data[pos + 4:pos + 8]
        body = data[pos + 8:pos + 8 + ln]
        if typ == b'IHDR':
            w, h, bit, ctype = struct.unpack('>IIBB', body[:10])
        elif typ == b'IDAT':
            idat += body
        elif typ == b'IEND':
            break
        pos += 12 + ln
    assert bit == 8, f'only 8-bit supported, got {bit}'
    ch = {2: 3, 6: 4}.get(ctype)
    assert ch, f'only RGB/RGBA supported, ctype={ctype}'
    raw = zlib.decompress(idat)
    stride = w * ch
    out = bytearray(h * stride)
    prev = bytearray(stride)
    p = 0
    for y in range(h):
        f = raw[p]
        p += 1
        line = bytearray(raw[p:p + stride])
        p += stride
        if f == 1:      # Sub
            for i in range(ch, stride):
                line[i] = (line[i] + line[i - ch]) & 0xFF
        elif f == 2:    # Up
            for i in range(stride):
                line[i] = (line[i] + prev[i]) & 0xFF
        elif f == 3:    # Average
            for i in range(stride):
                a = line[i - ch] if i >= ch else 0
                line[i] = (line[i] + ((a + prev[i]) >> 1)) & 0xFF
        elif f == 4:    # Paeth
            for i in range(stride):
                a = line[i - ch] if i >= ch else 0
                b = prev[i]
                c = prev[i - ch] if i >= ch else 0
                pa, pb, pc = abs(b - c), abs(a - c), abs(a + b - 2 * c)
                pr = a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
                line[i] = (line[i] + pr) & 0xFF
        out[y * stride:(y + 1) * stride] = line
        prev = line
    return w, h, ch, bytes(out)


def write_png(path, w, h, ch, pixels):
    ctype = 6 if ch == 4 else 2
    raw = bytearray()
    stride = w * ch
    for y in range(h):
        raw.append(0)
        raw += pixels[y * stride:(y + 1) * stride]

    def chunk(typ, body):
        return struct.pack('>I', len(body)) + typ + body + struct.pack('>I', zlib.crc32(typ + body) & 0xFFFFFFFF)

    png = b'\x89PNG\r\n\x1a\n'
    png += chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, ctype, 0, 0, 0))
    png += chunk(b'IDAT', zlib.compress(bytes(raw), 9))
    png += chunk(b'IEND', b'')
    open(path, 'wb').write(png)


def box_downsample(src_w, src_h, ch, px, size):
    """整数倍盒式平均降采样；对 RGBA 的 alpha 做加权平均以避免边缘黑/白晕。"""
    fx, fy = src_w // size, src_h // size
    assert src_w % size == 0 and src_h % size == 0, f'{src_w}x{src_h} not divisible by {size}'
    out = bytearray(size * size * ch)
    for oy in range(size):
        for ox in range(size):
            r = g = b = a = 0
            aw = 0
            n = fx * fy
            for sy in range(oy * fy, (oy + 1) * fy):
                base = (sy * src_w + ox * fx) * ch
                for k in range(fx):
                    i = base + k * ch
                    if ch == 4:
                        al = px[i + 3]
                        r += px[i] * al
                        g += px[i + 1] * al
                        b += px[i + 2] * al
                        a += al
                        aw += al
                    else:
                        r += px[i]
                        g += px[i + 1]
                        b += px[i + 2]
                        a += 255
                        aw += 255
            o = (oy * size + ox) * ch
            if aw:
                out[o] = min(255, round(r / aw))
                out[o + 1] = min(255, round(g / aw))
                out[o + 2] = min(255, round(b / aw))
            if ch == 4:
                out[o + 3] = min(255, round(a / n))
    return bytes(out)


if __name__ == '__main__':
    src, dst, size = sys.argv[1], sys.argv[2], int(sys.argv[3])
    w, h, ch, px = read_png(src)
    print(f'  src {w}x{h} ch={ch}')
    assert w == h, 'square source required'
    out = box_downsample(w, h, ch, px, size)
    write_png(dst, size, size, ch, out)
    w2, h2, ch2, _ = read_png(dst)
    print(f'  dst {dst} {w2}x{h2} ch={ch2}')