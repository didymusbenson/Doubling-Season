#!/usr/bin/env python3
"""Verify required tablet glyphs survive Flutter's release font subsetting."""
import struct
import sys
from pathlib import Path


def glyph(data, codepoint):
    count = struct.unpack_from('>H', data, 4)[0]
    cmap = next(
        offset
        for tag, _, offset, _ in (
            struct.unpack_from('>4sIII', data, 12 + i * 16)
            for i in range(count)
        )
        if tag == b'cmap'
    )
    tables = struct.unpack_from('>H', data, cmap + 2)[0]
    for i in range(tables):
        offset = cmap + struct.unpack_from('>I', data, cmap + 4 + i * 8 + 4)[0]
        fmt = struct.unpack_from('>H', data, offset)[0]
        if fmt == 12:
            groups = struct.unpack_from('>I', data, offset + 12)[0]
            for n in range(groups):
                start, end, index = struct.unpack_from('>III', data, offset + 16 + n * 12)
                if start <= codepoint <= end:
                    return index + codepoint - start
        if fmt == 4:
            segments = struct.unpack_from('>H', data, offset + 6)[0] // 2
            ends = offset + 14
            starts = ends + segments * 2 + 2
            deltas = starts + segments * 2
            ranges = deltas + segments * 2
            for n in range(segments):
                end = struct.unpack_from('>H', data, ends + n * 2)[0]
                start = struct.unpack_from('>H', data, starts + n * 2)[0]
                if start <= codepoint <= end:
                    delta = struct.unpack_from('>h', data, deltas + n * 2)[0]
                    distance = struct.unpack_from('>H', data, ranges + n * 2)[0]
                    if distance == 0:
                        return (codepoint + delta) & 0xffff
                    address = ranges + n * 2 + distance + (codepoint - start) * 2
                    index = struct.unpack_from('>H', data, address)[0]
                    return (index + delta) & 0xffff if index else 0
    return 0


paths = [Path(p) for p in sys.argv[1:]] or [
    Path('assets/fonts/mana.ttf'),
    Path('build/web/assets/assets/fonts/mana.ttf'),
]
for path in paths:
    data = path.read_bytes()
    for name, codepoint in {'untap': 0xe61b, 'ascend': 0xe94a}.items():
        assert glyph(data, codepoint), '%s missing %s U+%04X' % (path, name, codepoint)
    print('%s: untap U+E61B and ascend U+E94A present' % path)
