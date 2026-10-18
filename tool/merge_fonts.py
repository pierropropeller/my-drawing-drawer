#!/usr/bin/env python3
"""D-090 修正：把 tool/subset_fonts.py 產出的各 Noto subset 合併成單一字型 DrawerSymbols。

為什麼要合併：Flutter（Minikin）切字型時，「底字＋組合字元」必須有**同一個** family
同時涵蓋兩者，否則整個 cluster 會變豆腐（例：ก̀、(ᯫ᳐、▪͈、੭ﾞ）。
分成十幾個 family 時，底字（例如 "("、空白）和組合字元分屬不同 family，就會壞掉。
合併後每個 family 內都有 ASCII／拉丁＋所有符號＋組合字元，cluster 才能整串用同一個字型。

用法：python3 tool/merge_fonts.py     （需要 pip install fonttools）
流程：python3 tool/subset_fonts.py <原始 ttf 資料夾>   → build/fonts_subset/（不 commit）
      python3 tool/merge_fonts.py                       → assets/fonts/DrawerSymbols-Regular.ttf
"""
import argparse
import os
import sys

from fontTools import merge
from fontTools.ttLib import TTFont
from fontTools.varLib import instancer

ORDER = [
    'NotoSans', 'NotoSansSymbols', 'NotoSansSymbols2', 'NotoSansMath',
    'NotoSansThai', 'NotoSansKannada', 'NotoSansCanadianAboriginal', 'NotoSansYi',
    'NotoSansArabic', 'NotoSansTelugu', 'NotoSansTamil', 'NotoSansGurmukhi',
    'NotoSansKhmer', 'NotoSansBatak', 'NotoSansMono',
]

# 半形標點主字型（Noto Sans TC）有，但組合字元（例如 ･᷄）需要同 family 有底字，
# 所以在合併字型內補一份近似字形（只在 cluster 需要時才會被用到）。
ALIASES = {0xFF65: 0x00B7, 0xFF9E: 0x02DD, 0xFF9F: 0x00B0, 0xFF61: 0x00B0}

ap = argparse.ArgumentParser()
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
ap.add_argument('--src', default=os.path.join(ROOT, 'build', 'fonts_subset'), help='subset_fonts.py 輸出資料夾')
ap.add_argument('--out', default=os.path.join(ROOT, 'assets', 'fonts', 'DrawerSymbols-Regular.ttf'))
a = ap.parse_args()

tmp = []
paths = []
for n in ORDER:
    p = os.path.join(a.src, f'{n}-Regular.ttf')
    f = TTFont(p)
    if 'fvar' in f:  # NotoSansMono 是 variable，合併前固定在預設值。
        f = instancer.instantiateVariableFont(f, {}, inplace=False)
        p = os.path.join(a.src, f'_{n}-static.ttf')
        f.save(p)
        tmp.append(p)
    paths.append(p)

opts = merge.Options(drop_tables=['DSIG', 'vhea', 'vmtx', 'MATH', 'STAT'])
m = merge.Merger(options=opts)
font = m.merge(paths)

cmap = font.getBestCmap()
for t in font['cmap'].tables:
    if t.isUnicode():
        for src, dst in ALIASES.items():
            if src not in t.cmap and dst in t.cmap:
                t.cmap[src] = t.cmap[dst]

font['name'].setName('DrawerSymbols', 1, 3, 1, 0x409)
font['name'].setName('Regular', 2, 3, 1, 0x409)
font['name'].setName('DrawerSymbols-Regular', 4, 3, 1, 0x409)
font['name'].setName('DrawerSymbols-Regular', 6, 3, 1, 0x409)
font.save(a.out)
for p in tmp:
    os.remove(p)
print(a.out, os.path.getsize(a.out), 'glyphs', len(font.getGlyphOrder()), 'cmap', len(cmap))
sys.exit(0)
