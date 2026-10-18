#!/usr/bin/env python3
"""D-090：檢查 tool/kaomoji_samples.txt 的每個非 ASCII codepoint 是否在 DrawerSymbols。
用法：python3 tool/check_kaomoji_cmap.py   （需要 pip install fonttools）

額外檢查「cluster」：組合字元（Mn／Mc／Me、半形濁點 ﾞﾟ）前面的底字，也必須在
DrawerSymbols 內（或是 ASCII），否則 Flutter 找不到能同時涵蓋底字＋組合字元的 family，
整個 cluster 會變豆腐。沒覆蓋的列出並以非 0 結束。
CJK／全形字元交給主字型 Noto Sans TC（執行期下載，不在 cmap 檢查內），列為 PRIMARY。
這只是 cmap 檢查；真正的渲染驗證是 test/kaomoji_render_test.dart。
"""
import os
import sys
import unicodedata

from fontTools.ttLib import TTFont

HERE = os.path.dirname(os.path.abspath(__file__))
cmap = TTFont(os.path.join(HERE, '..', 'assets', 'fonts', 'DrawerSymbols-Regular.ttf')).getBestCmap()


def primary(cp):
    # Noto Sans TC 負責：CJK 表意文字、直排形式（FE30–FE4F）、半形／全形形式（FF00–FFEF）、
    # CJK 符號、注音、韓文相容字母。
    return (0x4E00 <= cp <= 0x9FFF or 0x3000 <= cp <= 0x30FF
            or 0x3130 <= cp <= 0x318F or 0xFE30 <= cp <= 0xFE4F or 0xFF00 <= cp <= 0xFFEF)


def is_mark(ch):
    return unicodedata.category(ch) in ('Mn', 'Mc', 'Me') or ord(ch) in (0xFF9E, 0xFF9F)


missing = []
for line in open(os.path.join(HERE, 'kaomoji_samples.txt'), encoding='utf-8'):
    s = line.rstrip('\n')
    print(repr(s))
    for i, ch in enumerate(s):
        cp = ord(ch)
        if cp >= 0x80:
            if cp in cmap:
                hit = 'DrawerSymbols'
            elif primary(cp):
                hit = 'PRIMARY(NotoSansTC)'
            else:
                hit = None
            name = unicodedata.name(ch, '?')
            print(f'  U+{cp:04X} {ch} {name} -> {hit or "MISSING"}')
            if hit is None:
                missing.append(cp)
        if i > 0 and is_mark(ch):
            base = s[i - 1]
            if ord(base) >= 0x80 and ord(base) not in cmap and not is_mark(base):
                print(f'  U+{ord(base):04X} {base} 是 U+{cp:04X} 的底字，但不在 DrawerSymbols -> MISSING-BASE')
                missing.append(ord(base))

if missing:
    print('\nMISSING:', ' '.join(f'U+{c:04X}' for c in sorted(set(missing))))
    sys.exit(1)
print('\nALL COVERED')
