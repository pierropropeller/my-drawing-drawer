#!/usr/bin/env python3
"""D-090：把 Noto fallback 字型 subset 成小檔，輸出到 assets/fonts/。

用法：python3 tool/subset_fonts.py <原始 ttf 資料夾>
原始檔來源：notofonts 的 fonts/<Family>/full/ttf/<Family>-Regular.ttf（OFL 1.1）。
需要：pip install fonttools
"""
import os
import sys

from fontTools import subset

SRC = sys.argv[1]
OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'fonts')
os.makedirs(OUT, exist_ok=True)

# 各字型保留的 Unicode 範圍（顏文字常用區塊，其餘丟掉以控制 APK 體積）。
RANGES = {
    # Latin／IPA 擴充／音標擴充／希臘／西里爾／標點／上下標／字母符號
    'NotoSans': '0020-052F,1D00-1DBF,1E00-1EFF,2000-206F,2070-209F,20A0-20CF,2100-214F',
    # 箭頭、技術符號、幾何圖形、雜項符號、裝飾符號
    'NotoSansSymbols': '2190-23FF,2460-27BF,2800-28FF,2900-2BFF,FFF0-FFFF',
    'NotoSansSymbols2': '2190-23FF,2460-27BF,2800-28FF,2900-2BFF,1F000-1F2FF,1FB00-1FBFF',
    # 數學運算子、補充數學、箭頭、幾何、字母式符號
    'NotoSansMath': '2100-214F,2190-22FF,2300-23FF,25A0-25FF,2600-26FF,27C0-27EF,2980-2AFF',
    'NotoSansThai': '0E00-0E7F,200B-200D,00A0,25CC',
    'NotoSansKannada': '0C80-0CFF,200B-200D,00A0,25CC',
    'NotoSansCanadianAboriginal': '1400-167F,18B0-18FF',
    'NotoSansYi': 'A000-A4CF',
}


def parse(spec):
    cps = []
    for part in spec.split(','):
        if '-' in part:
            a, b = part.split('-')
            cps.extend(range(int(a, 16), int(b, 16) + 1))
        else:
            cps.append(int(part, 16))
    return cps


for name, spec in RANGES.items():
    opts = subset.Options()
    opts.layout_features = ['kern', 'mark', 'mkmk', 'ccmp', 'locl', 'liga', 'rlig',
                            'akhn', 'blwf', 'half', 'pstf', 'vatu', 'cjct', 'abvs',
                            'blws', 'pres', 'psts', 'abvf', 'haln', 'rphf', 'nukt',
                            'rkrf', 'dist', 'calt', 'clig']
    opts.name_IDs = ['*']
    opts.notdef_outline = True
    opts.glyph_names = False
    opts.hinting = False
    opts.drop_tables += ['DSIG', 'GDEF_unused']
    font = subset.load_font(os.path.join(SRC, f'{name}.ttf'), opts)
    s = subset.Subsetter(opts)
    s.populate(unicodes=parse(spec))
    s.subset(font)
    dst = os.path.join(OUT, f'{name}-Regular.ttf')
    subset.save_font(font, dst, opts)
    print(name, os.path.getsize(dst))
