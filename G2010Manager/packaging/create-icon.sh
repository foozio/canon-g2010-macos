#!/bin/bash
# create-icon.sh — Generate an AppIcon.icns from a rendered PNG
# Usage: create-icon.sh <output.icns>
set -euo pipefail

OUTPUT="${1:-AppIcon.icns}"
ICONSET_DIR="$(mktemp -d)/AppIcon.iconset"
mkdir -p "$ICONSET_DIR"

# Use Python to draw a simple printer icon as PNG
python3 -c "
import struct, zlib

def create_png(width, height, pixels):
    '''Create a minimal PNG file from RGBA pixel data.'''
    def chunk(ctype, data):
        c = ctype + data
        return struct.pack('>I', len(data)) + c + struct.pack('>I', zlib.crc32(c) & 0xffffffff)
    
    raw = b''
    for y in range(height):
        raw += b'\x00'  # filter: none
        for x in range(width):
            raw += bytes(pixels[y][x])
    
    return (b'\x89PNG\r\n\x1a\n' +
            chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, 6, 0, 0, 0)) +
            chunk(b'IDAT', zlib.compress(raw, 9)) +
            chunk(b'IEND', b''))

def draw_icon(size):
    '''Draw a simple printer icon.'''
    pixels = [[(30, 30, 30, 255)] * size for _ in range(size)]
    
    m = size // 16  # unit
    cx, cy = size // 2, size // 2
    
    # Background circle (blue gradient)
    for y in range(size):
        for x in range(size):
            dx, dy = x - cx, y - cy
            dist = (dx*dx + dy*dy) ** 0.5
            r = size * 0.42
            if dist < r:
                t = dist / r
                b = int(60 + 140 * (1 - t * 0.3))
                g = int(120 + 80 * (1 - t * 0.3))
                pixels[y][x] = (30, g, b, 255)
            else:
                # Anti-alias edge
                edge = r + 1.5
                if dist < edge:
                    alpha = int(255 * (edge - dist) / 1.5)
                    t = dist / r
                    b = int(60 + 140 * (1 - t * 0.3))
                    g = int(120 + 80 * (1 - t * 0.3))
                    pixels[y][x] = (30, g, b, alpha)
                else:
                    pixels[y][x] = (0, 0, 0, 0)
    
    # Printer body (white rectangle)
    bx1, bx2 = cx - m * 5, cx + m * 5
    by1, by2 = cy - m * 2, cy + m * 3
    for y in range(max(0, by1), min(size, by2)):
        for x in range(max(0, bx1), min(size, bx2)):
            pixels[y][x] = (240, 240, 240, 255)
    
    # Paper tray top (lighter)
    px1, px2 = cx - m * 4, cx + m * 4
    py1, py2 = cy - m * 5, cy - m * 2
    for y in range(max(0, py1), min(size, py2)):
        for x in range(max(0, px1), min(size, px2)):
            pixels[y][x] = (255, 255, 255, 255)
    
    # Paper output (bottom)
    ox1, ox2 = cx - m * 4, cx + m * 4
    oy1, oy2 = cy + m * 3, cy + m * 6
    for y in range(max(0, oy1), min(size, oy2)):
        for x in range(max(0, ox1), min(size, ox2)):
            pixels[y][x] = (255, 255, 255, 240)
    
    # Lines on paper
    for i in range(3):
        ly = cy + m * 4 + i * m
        lx1, lx2 = cx - m * 3, cx + m * 3
        if ly < size:
            for x in range(max(0, lx1), min(size, lx2)):
                pixels[ly][x] = (180, 180, 180, 255)
    
    return pixels

import sys, os
iconset = sys.argv[1]
sizes = [(16,1),(16,2),(32,1),(32,2),(128,1),(128,2),(256,1),(256,2),(512,1),(512,2)]
for base, scale in sizes:
    actual = base * scale
    suffix = f'{base}x{base}@{scale}x' if scale > 1 else f'{base}x{base}'
    pixels = draw_icon(actual)
    data = create_png(actual, actual, pixels)
    fname = os.path.join(iconset, f'icon_{suffix}.png')
    with open(fname, 'wb') as f:
        f.write(data)
    print(f'  Created {fname} ({actual}x{actual})')
" "$ICONSET_DIR"

# Convert iconset to icns
iconutil -c icns "$ICONSET_DIR" -o "$OUTPUT"
rm -rf "$(dirname "$ICONSET_DIR")"

echo "  Icon created: $OUTPUT"
