#!/usr/bin/env python3
"""把 ClipboardImage.swift、DropReceiver.swift 加進 Runner target（ios/Runner.xcodeproj/project.pbxproj）。

用法（在 repo 根目錄）：
    python3 tool/add_ios_import_files.py            # 改寫 project.pbxproj（已加過就什麼都不做）
    python3 tool/add_ios_import_files.py --check    # 只驗證目前的 project.pbxproj

作法同 tool/add_share_extension.py：對文字做有錨點的插入（每個錨點必須剛好出現一次，否則中止），
改完用該檔內建的 old-style plist 解析器重新解析並檢查（ID 唯一、引用都有定義、ShareExtension target 沒被動到）。
新檔掛在 Runner group（緊接 ShareHandoff.swift）與 Runner 的 Sources build phase。
"""
import hashlib
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import add_share_extension as base  # noqa: E402

PBX = base.PBX
FILES = ["ClipboardImage.swift", "DropReceiver.swift"]
T = "\t"


def make_ids(text):
    used = set(re.findall(r"\b[0-9A-F]{24}\b", text))
    ids = {}
    for f in FILES:
        for kind in ("ref", "bf"):
            salt = 0
            while True:
                h = hashlib.sha1(f"drawer-import-files/{f}/{kind}/{salt}".encode()).hexdigest().upper()[:24]
                if h not in used:
                    break
                salt += 1
            used.add(h)
            ids[(f, kind)] = h
    return ids


def add_files(text):
    ids = make_ids(text)

    # ShareHandoff.swift 的 file reference／build file ID 從文字取得（必須各剛好一個）。
    ref = re.findall(r"^\t\t([0-9A-F]{24}) /\* ShareHandoff\.swift \*/ = \{isa = PBXFileReference", text, re.M)
    bf = re.findall(r"^\t\t([0-9A-F]{24}) /\* ShareHandoff\.swift in Sources \*/ = \{isa = PBXBuildFile", text, re.M)
    if len(ref) != 1 or len(bf) != 1:
        sys.exit(f"找不到唯一的 ShareHandoff.swift 參照：ref={ref} bf={bf}")
    ref, bf = ref[0], bf[0]

    # --- PBXBuildFile
    text = base.sub_once(
        text,
        "/* End PBXBuildFile section */",
        "".join(
            f"{T}{T}{ids[(f, 'bf')]} /* {f} in Sources */ = {{isa = PBXBuildFile; fileRef = {ids[(f, 'ref')]} /* {f} */; }};\n"
            for f in FILES
        )
        + "/* End PBXBuildFile section */",
    )
    # --- PBXFileReference
    text = base.sub_once(
        text,
        "/* End PBXFileReference section */",
        "".join(
            f"{T}{T}{ids[(f, 'ref')]} /* {f} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {f}; sourceTree = \"<group>\"; }};\n"
            for f in FILES
        )
        + "/* End PBXFileReference section */",
    )
    # --- Runner group：緊接 ShareHandoff.swift
    anchor = f"{T}{T}{T}{T}{ref} /* ShareHandoff.swift */,\n"
    text = base.sub_once(
        text,
        anchor,
        anchor + "".join(f"{T}{T}{T}{T}{ids[(f, 'ref')]} /* {f} */,\n" for f in FILES),
    )
    # --- Runner 的 Sources build phase：緊接 ShareHandoff.swift in Sources
    anchor = f"{T}{T}{T}{T}{bf} /* ShareHandoff.swift in Sources */,\n"
    text = base.sub_once(
        text,
        anchor,
        anchor + "".join(f"{T}{T}{T}{T}{ids[(f, 'bf')]} /* {f} in Sources */,\n" for f in FILES),
    )
    return text, ids


def verify(text):
    n = base.verify(text)  # 既有的全部檢查（含 ShareExtension target 的 sources 只有 ShareViewController.swift）
    root = base.parse_plist(text)
    objs = root["objects"]
    runner = next(o for o in objs.values() if o.get("isa") == "PBXNativeTarget" and o["name"] == "Runner")
    src = next(objs[p] for p in runner["buildPhases"] if objs[p]["isa"] == "PBXSourcesBuildPhase")
    names = [objs[objs[b]["fileRef"]]["path"] for b in src["files"]]
    for f in FILES:
        assert names.count(f) == 1, f"Runner Sources 裡 {f} 出現 {names.count(f)} 次"
    # 新檔掛在 Runner group 底下。
    groups = [o for o in objs.values() if o.get("isa") == "PBXGroup"]
    for f in FILES:
        fid = next(k for k, o in objs.items() if o.get("isa") == "PBXFileReference" and o["path"] == f)
        assert sum(fid in g["children"] for g in groups) == 1, f"{f} 不在恰好一個 group 裡"
    # ShareExtension 的 Sources 仍然只有它自己的檔案。
    ext = next(o for o in objs.values() if o.get("isa") == "PBXNativeTarget" and o["name"] == "ShareExtension")
    esrc = objs[ext["buildPhases"][0]]
    assert [objs[objs[b]["fileRef"]]["path"] for b in esrc["files"]] == ["ShareViewController.swift"]
    # 檔案真的存在。
    for f in FILES:
        assert (PBX.parent.parent / "Runner" / f).exists(), f"缺檔：ios/Runner/{f}"
    return n


def main():
    text = PBX.read_text(encoding="utf-8")
    if "--check" in sys.argv:
        print("OK，objects =", verify(text))
        return
    present = [f for f in FILES if f in text]
    if len(present) == len(FILES):
        print("project.pbxproj 已有這些檔案，略過。")
        print("OK，objects =", verify(text))
        return
    if present:
        sys.exit(f"只有部分檔案已在 project.pbxproj：{present}，請人工檢查。")
    base.verify(text)  # 原檔先確認可解析
    new, ids = add_files(text)
    n = verify(new)
    PBX.write_text(new, encoding="utf-8")
    print("已寫入。objects =", n)
    for (f, kind), v in ids.items():
        print(f"  {f:24} {kind:3} {v}")


if __name__ == "__main__":
    main()
