#!/usr/bin/env python3
"""D-090：列出 tool/kaomoji_samples.txt 每個非 ASCII codepoint 由哪個打包字型覆蓋。
用法：python3 tool/check_kaomoji_cmap.py   （需要 pip install fonttools）
依 lib/theme/font_fallback.dart 的次序找第一個含該 codepoint 的字型
（Flutter 逐字元就是這樣挑 fallback）；沒覆蓋的列出並以非 0 結束。
CJK／全形字元（人、ω 以外的 CJK 標點等）交給主字型 Noto Sans TC（執行期下載，
不在 cmap 檢查內），列為 PRIMARY。
"""
import os
import re
import sys
import unicodedata

from fontTools.ttLib import TTFont

HERE = os.path.dirname(os.path.abspath(__file__))
FONT_DIR = os.path.join(HERE, '..', 'assets', 'fonts')
ORDER = re.findall(
    r"'(NotoSans\w*)'",
    open(os.path.join(HERE, '..', 'lib', 'theme', 'font_fallback.dart'),
         encoding='utf-8').read(),
)
ORDER = [n for n in ORDER if n != 'NotoSansTC']

cmaps = {n: TTFont(os.path.join(FONT_DIR, f'{n}-Regular.ttf')).getBestCmap()
         for n in ORDER}


def primary(cp):
    # Noto Sans TC 負責：CJK 表意文字、直排形式（FE30–FE4F）、半形／全形形式（FF00–FFEF）、
    # CJK 符號、注音、韓文相容字母。
    return (0x4E00 <= cp <= 0x9FFF or 0x3000 <= cp <= 0x30FF
            or 0x3100 <= cp <= 0x318F or 0xFE30 <= cp <= 0xFE4F or 0xFF00 <= cp <= 0xFFEF)


missing = []
seen = set()
for line in open(os.path.join(HERE, 'kaomoji_samples.txt'), encoding='utf-8'):
    s = line.rstrip('\n')
    print(repr(s))
    for ch in s:
        cp = ord(ch)
        if cp < 0x80:
            continue
        hit = next((n for n in ORDER if cp in cmaps[n]), None)
        if hit is None and primary(cp):
            hit = 'PRIMARY(NotoSansTC)'
        name = unicodedata.name(ch, '?')
        if hit is None:
            print(f'  U+{cp:04X} {ch} {name} -> MISSING')
            if cp not in seen:
                missing.append(cp)
        else:
            print(f'  U+{cp:04X} {ch} {name} -> {hit}')
        seen.add(cp)

if missing:
    print('\nMISSING:', ' '.join(f'U+{c:04X}' for c in sorted(set(missing))))
    sys.exit(1)
print('\nALL COVERED')
