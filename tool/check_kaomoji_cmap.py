#!/usr/bin/env python3
"""D-090：確認顏文字每個 codepoint 都在打包的 fallback 字型 cmap 內。
用法：python3 tool/check_kaomoji_cmap.py   （需要 pip install fonttools）
有找不到的字元會以非 0 結束。
ㅂ（韓文字母）和 و（阿拉伯文）不在本任務指定的字型範圍：
前者由主字型 Noto Sans TC 負責，後者交給系統字型，這裡只列出、不算失敗。
"""
import os
import sys

from fontTools.ttLib import TTFont

FONT_DIR = os.path.join(os.path.dirname(__file__), '..', 'assets', 'fonts')
ORDER = ['NotoSans', 'NotoSansSymbols', 'NotoSansSymbols2', 'NotoSansMath',
         'NotoSansThai', 'NotoSansKannada', 'NotoSansCanadianAboriginal',
         'NotoSansYi']
SAMPLES = ['(≖ᴗ≖)✧', '(๑•̀ㅂ•́)و✧', 'ಠ_ಠ', 'ᐛ', '꒰ ꒱']
OUT_OF_SCOPE = {'ㅂ': 'primary Noto Sans TC', 'و': 'system font'}

cmaps = {n: TTFont(os.path.join(FONT_DIR, f'{n}-Regular.ttf')).getBestCmap()
         for n in ORDER}
bad = 0
for s in SAMPLES:
    print(repr(s))
    for ch in s:
        cp = ord(ch)
        if cp < 0x80:
            continue
        hit = next((n for n in ORDER if cp in cmaps[n]), None)
        if hit:
            print(f'  U+{cp:04X} {ch} -> {hit}')
        elif ch in OUT_OF_SCOPE:
            print(f'  U+{cp:04X} {ch} -> ({OUT_OF_SCOPE[ch]}, not bundled)')
        else:
            print(f'  U+{cp:04X} {ch} -> MISSING')
            bad += 1
sys.exit(1 if bad else 0)
