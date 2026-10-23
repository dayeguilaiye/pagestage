"""Generate Dart lookup data from WHATWG index files supplied as arguments.

Usage: python3 tool/generate_gb18030.py index-gb18030.txt index-gb18030-ranges.txt
Sources: https://encoding.spec.whatwg.org/index-gb18030.txt
         https://encoding.spec.whatwg.org/index-gb18030-ranges.txt
License: packages/core/lib/src/encoding/WHATWG-LICENSE
"""
import json
from pathlib import Path
import sys


def rows(path):
    return [(int(parts[0]), int(parts[1], 16))
            for line in Path(path).read_text().splitlines()
            if line.strip() and not line.startswith('#')
            for parts in [line.split()]]


index = rows(sys.argv[1])
ranges = rows(sys.argv[2])
characters = ''.join(chr(codepoint) for _, codepoint in index)
assert [pointer for pointer, _ in index] == list(range(23940))
# Indexed by Unicode code point, not UTF-16, to support revised mappings.
content = '''// Generated from the WHATWG Encoding Standard indexes (2024-09-18).
// Source URLs and reproducible generator: tool/generate_gb18030.py.
// Copyright WHATWG contributors; see WHATWG-LICENSE in this directory.
// ignore_for_file: lines_longer_than_80_chars

final gb18030Index = (
'''
for offset in range(0, len(characters), 80):
    chunk = json.dumps(characters[offset:offset + 80], ensure_ascii=False)
    content += '  ' + chunk.replace('$', r'\$') + '\n'
content += ').runes.toList(growable: false);\n\nconst gb18030Ranges = <(int, int)>[\n'
for pointer, codepoint in ranges:
    content += f'  ({pointer}, 0x{codepoint:X}),\n'
content += '];\n'
Path('packages/core/lib/src/encoding/gb18030_data.dart').write_text(content)
