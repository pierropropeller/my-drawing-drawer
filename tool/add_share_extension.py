#!/usr/bin/env python3
"""把 Share Extension target 加進 ios/Runner.xcodeproj/project.pbxproj。

用法（在 repo 根目錄）：
    python3 tool/add_share_extension.py            # 改寫 project.pbxproj（已加過就什麼都不做）
    python3 tool/add_share_extension.py --check    # 只驗證目前的 project.pbxproj（語法與引用）

沒有 Xcode 的環境也能跑：直接對文字做有錨點的插入（每個錨點必須剛好出現一次，否則中止），
改完用內建的 old-style plist 解析器重新解析，並檢查：
  - 所有 24 位 ID 唯一、每個被引用的 ID 都有定義；
  - 新 target 的 phases／dependency／product／設定清單彼此對得上。
"""
import hashlib
import re
import sys
from pathlib import Path

PBX = Path(__file__).resolve().parent.parent / "ios/Runner.xcodeproj/project.pbxproj"

RUNNER_TARGET = "97C146ED1CF9000F007C117D"
PROJECT_OBJ = "97C146E61CF9000F007C117D"
MAIN_GROUP = "97C146E51CF9000F007C117D"
PRODUCTS_GROUP = "97C146EF1CF9000F007C117D"
RUNNER_GROUP = "97C146F01CF9000F007C117D"
RUNNER_SOURCES_PHASE = "97C146EA1CF9000F007C117D"
GENERATED_XCCONFIG = "9740EEB31CF90195004384FC"
THIN_BINARY = "3B06AD1E1E4923F5004D2608"
EMBED_FRAMEWORKS = "9705A1C41CF9048500538489"


def make_ids(text):
    names = [
        "ref_vc", "ref_plist", "ref_handoff", "ref_appex",
        "bf_vc", "bf_handoff", "bf_embed",
        "grp", "proxy", "dep", "embed_phase", "target",
        "ph_sources", "ph_frameworks", "ph_resources",
        "cfg_debug", "cfg_release", "cfg_profile", "cfg_list",
    ]
    ids = {}
    used = set(re.findall(r"\b[0-9A-F]{24}\b", text))
    for n in names:
        salt = 0
        while True:
            h = hashlib.sha1(f"drawer-share-ext/{n}/{salt}".encode()).hexdigest().upper()[:24]
            if h not in used:
                break
            salt += 1
        used.add(h)
        ids[n] = h
    return ids


def sub_once(text, old, new):
    n = text.count(old)
    if n != 1:
        sys.exit(f"錨點必須剛好出現一次（實際 {n} 次）：{old[:80]!r}")
    return text.replace(old, new)


def add_share_extension(text):
    i = make_ids(text)
    T = "\t"

    # --- PBXBuildFile
    text = sub_once(
        text,
        "/* End PBXBuildFile section */",
        f"{T}{T}{i['bf_vc']} /* ShareViewController.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {i['ref_vc']} /* ShareViewController.swift */; }};\n"
        f"{T}{T}{i['bf_handoff']} /* ShareHandoff.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {i['ref_handoff']} /* ShareHandoff.swift */; }};\n"
        f"{T}{T}{i['bf_embed']} /* ShareExtension.appex in Embed Foundation Extensions */ = {{isa = PBXBuildFile; fileRef = {i['ref_appex']} /* ShareExtension.appex */; settings = {{ATTRIBUTES = (RemoveHeadersOnCopy, ); }}; }};\n"
        "/* End PBXBuildFile section */",
    )

    # --- PBXContainerItemProxy
    text = sub_once(
        text,
        "/* End PBXContainerItemProxy section */",
        f"{T}{T}{i['proxy']} /* PBXContainerItemProxy */ = {{\n"
        f"{T}{T}{T}isa = PBXContainerItemProxy;\n"
        f"{T}{T}{T}containerPortal = {PROJECT_OBJ} /* Project object */;\n"
        f"{T}{T}{T}proxyType = 1;\n"
        f"{T}{T}{T}remoteGlobalIDString = {i['target']};\n"
        f"{T}{T}{T}remoteInfo = ShareExtension;\n"
        f"{T}{T}}};\n"
        "/* End PBXContainerItemProxy section */",
    )

    # --- PBXCopyFilesBuildPhase（Embed Foundation Extensions；dstSubfolderSpec 13 = PlugIns）
    text = sub_once(
        text,
        "/* End PBXCopyFilesBuildPhase section */",
        f"{T}{T}{i['embed_phase']} /* Embed Foundation Extensions */ = {{\n"
        f"{T}{T}{T}isa = PBXCopyFilesBuildPhase;\n"
        f"{T}{T}{T}buildActionMask = 2147483647;\n"
        f'{T}{T}{T}dstPath = "";\n'
        f"{T}{T}{T}dstSubfolderSpec = 13;\n"
        f"{T}{T}{T}files = (\n"
        f"{T}{T}{T}{T}{i['bf_embed']} /* ShareExtension.appex in Embed Foundation Extensions */,\n"
        f"{T}{T}{T});\n"
        f'{T}{T}{T}name = "Embed Foundation Extensions";\n'
        f"{T}{T}{T}runOnlyForDeploymentPostprocessing = 0;\n"
        f"{T}{T}}};\n"
        "/* End PBXCopyFilesBuildPhase section */",
    )

    # --- PBXFileReference
    text = sub_once(
        text,
        "/* End PBXFileReference section */",
        f"{T}{T}{i['ref_vc']} /* ShareViewController.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = ShareViewController.swift; sourceTree = \"<group>\"; }};\n"
        f"{T}{T}{i['ref_plist']} /* Info.plist */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = \"<group>\"; }};\n"
        f"{T}{T}{i['ref_handoff']} /* ShareHandoff.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = ShareHandoff.swift; sourceTree = \"<group>\"; }};\n"
        f"{T}{T}{i['ref_appex']} /* ShareExtension.appex */ = {{isa = PBXFileReference; explicitFileType = \"wrapper.app-extension\"; includeInIndex = 0; path = ShareExtension.appex; sourceTree = BUILT_PRODUCTS_DIR; }};\n"
        "/* End PBXFileReference section */",
    )

    # --- PBXFrameworksBuildPhase（擴充：空）
    text = sub_once(
        text,
        "/* End PBXFrameworksBuildPhase section */",
        f"{T}{T}{i['ph_frameworks']} /* Frameworks */ = {{\n"
        f"{T}{T}{T}isa = PBXFrameworksBuildPhase;\n"
        f"{T}{T}{T}buildActionMask = 2147483647;\n"
        f"{T}{T}{T}files = (\n"
        f"{T}{T}{T});\n"
        f"{T}{T}{T}runOnlyForDeploymentPostprocessing = 0;\n"
        f"{T}{T}}};\n"
        "/* End PBXFrameworksBuildPhase section */",
    )

    # --- PBXGroup：新 group、掛到 main group；appex 掛到 Products；ShareHandoff.swift 掛到 Runner group
    text = sub_once(
        text,
        "/* Begin PBXGroup section */\n",
        "/* Begin PBXGroup section */\n"
        f"{T}{T}{i['grp']} /* ShareExtension */ = {{\n"
        f"{T}{T}{T}isa = PBXGroup;\n"
        f"{T}{T}{T}children = (\n"
        f"{T}{T}{T}{T}{i['ref_vc']} /* ShareViewController.swift */,\n"
        f"{T}{T}{T}{T}{i['ref_plist']} /* Info.plist */,\n"
        f"{T}{T}{T});\n"
        f"{T}{T}{T}path = ShareExtension;\n"
        f'{T}{T}{T}sourceTree = "<group>";\n'
        f"{T}{T}}};\n",
    )
    text = sub_once(
        text,
        f"{T}{T}{T}{T}331C8082294A63A400263BE5 /* RunnerTests */,\n{T}{T}{T});\n{T}{T}{T}sourceTree",
        f"{T}{T}{T}{T}331C8082294A63A400263BE5 /* RunnerTests */,\n"
        f"{T}{T}{T}{T}{i['grp']} /* ShareExtension */,\n{T}{T}{T});\n{T}{T}{T}sourceTree",
    )
    text = sub_once(
        text,
        f"{T}{T}{T}{T}331C8081294A63A400263BE5 /* RunnerTests.xctest */,\n",
        f"{T}{T}{T}{T}331C8081294A63A400263BE5 /* RunnerTests.xctest */,\n"
        f"{T}{T}{T}{T}{i['ref_appex']} /* ShareExtension.appex */,\n",
    )
    text = sub_once(
        text,
        f"{T}{T}{T}{T}7884E8672EC3CC0400C636F2 /* SceneDelegate.swift */,\n",
        f"{T}{T}{T}{T}7884E8672EC3CC0400C636F2 /* SceneDelegate.swift */,\n"
        f"{T}{T}{T}{T}{i['ref_handoff']} /* ShareHandoff.swift */,\n",
    )

    # --- PBXNativeTarget：Runner 加 dependency 與 embed phase（放在 Thin Binary 之前，避免 build cycle）
    text = sub_once(
        text,
        f"{T}{T}{T}{T}{EMBED_FRAMEWORKS} /* Embed Frameworks */,\n"
        f"{T}{T}{T}{T}{THIN_BINARY} /* Thin Binary */,\n",
        f"{T}{T}{T}{T}{EMBED_FRAMEWORKS} /* Embed Frameworks */,\n"
        f"{T}{T}{T}{T}{i['embed_phase']} /* Embed Foundation Extensions */,\n"
        f"{T}{T}{T}{T}{THIN_BINARY} /* Thin Binary */,\n",
    )
    text = sub_once(
        text,
        f"{T}{T}{T}buildRules = (\n{T}{T}{T});\n{T}{T}{T}dependencies = (\n{T}{T}{T});\n{T}{T}{T}name = Runner;",
        f"{T}{T}{T}buildRules = (\n{T}{T}{T});\n{T}{T}{T}dependencies = (\n"
        f"{T}{T}{T}{T}{i['dep']} /* PBXTargetDependency */,\n{T}{T}{T});\n{T}{T}{T}name = Runner;",
    )
    text = sub_once(
        text,
        "/* End PBXNativeTarget section */",
        f"{T}{T}{i['target']} /* ShareExtension */ = {{\n"
        f"{T}{T}{T}isa = PBXNativeTarget;\n"
        f'{T}{T}{T}buildConfigurationList = {i["cfg_list"]} /* Build configuration list for PBXNativeTarget "ShareExtension" */;\n'
        f"{T}{T}{T}buildPhases = (\n"
        f"{T}{T}{T}{T}{i['ph_sources']} /* Sources */,\n"
        f"{T}{T}{T}{T}{i['ph_frameworks']} /* Frameworks */,\n"
        f"{T}{T}{T}{T}{i['ph_resources']} /* Resources */,\n"
        f"{T}{T}{T});\n"
        f"{T}{T}{T}buildRules = (\n{T}{T}{T});\n"
        f"{T}{T}{T}dependencies = (\n{T}{T}{T});\n"
        f"{T}{T}{T}name = ShareExtension;\n"
        f"{T}{T}{T}productName = ShareExtension;\n"
        f"{T}{T}{T}productReference = {i['ref_appex']} /* ShareExtension.appex */;\n"
        f'{T}{T}{T}productType = "com.apple.product-type.app-extension";\n'
        f"{T}{T}}};\n"
        "/* End PBXNativeTarget section */",
    )

    # --- PBXProject：TargetAttributes 與 targets
    text = sub_once(
        text,
        f"{T}{T}{T}{T}{T}97C146ED1CF9000F007C117D = {{\n",
        f"{T}{T}{T}{T}{T}{i['target']} = {{\n{T}{T}{T}{T}{T}{T}CreatedOnToolsVersion = 16.0;\n{T}{T}{T}{T}{T}}};\n"
        f"{T}{T}{T}{T}{T}97C146ED1CF9000F007C117D = {{\n",
    )
    text = sub_once(
        text,
        f"{T}{T}{T}{T}331C8080294A63A400263BE5 /* RunnerTests */,\n{T}{T}{T});\n{T}{T}}};\n/* End PBXProject section */",
        f"{T}{T}{T}{T}331C8080294A63A400263BE5 /* RunnerTests */,\n"
        f"{T}{T}{T}{T}{i['target']} /* ShareExtension */,\n{T}{T}{T});\n{T}{T}}};\n/* End PBXProject section */",
    )

    # --- PBXResourcesBuildPhase（擴充：空）
    text = sub_once(
        text,
        "/* End PBXResourcesBuildPhase section */",
        f"{T}{T}{i['ph_resources']} /* Resources */ = {{\n"
        f"{T}{T}{T}isa = PBXResourcesBuildPhase;\n"
        f"{T}{T}{T}buildActionMask = 2147483647;\n"
        f"{T}{T}{T}files = (\n{T}{T}{T});\n"
        f"{T}{T}{T}runOnlyForDeploymentPostprocessing = 0;\n"
        f"{T}{T}}};\n"
        "/* End PBXResourcesBuildPhase section */",
    )

    # --- PBXSourcesBuildPhase：Runner 加 ShareHandoff.swift；擴充自己的 Sources
    text = sub_once(
        text,
        f"{T}{T}{T}{T}7884E8682EC3CC0700C636F2 /* SceneDelegate.swift in Sources */,\n",
        f"{T}{T}{T}{T}7884E8682EC3CC0700C636F2 /* SceneDelegate.swift in Sources */,\n"
        f"{T}{T}{T}{T}{i['bf_handoff']} /* ShareHandoff.swift in Sources */,\n",
    )
    text = sub_once(
        text,
        "/* End PBXSourcesBuildPhase section */",
        f"{T}{T}{i['ph_sources']} /* Sources */ = {{\n"
        f"{T}{T}{T}isa = PBXSourcesBuildPhase;\n"
        f"{T}{T}{T}buildActionMask = 2147483647;\n"
        f"{T}{T}{T}files = (\n"
        f"{T}{T}{T}{T}{i['bf_vc']} /* ShareViewController.swift in Sources */,\n"
        f"{T}{T}{T});\n"
        f"{T}{T}{T}runOnlyForDeploymentPostprocessing = 0;\n"
        f"{T}{T}}};\n"
        "/* End PBXSourcesBuildPhase section */",
    )

    # --- PBXTargetDependency
    text = sub_once(
        text,
        "/* End PBXTargetDependency section */",
        f"{T}{T}{i['dep']} /* PBXTargetDependency */ = {{\n"
        f"{T}{T}{T}isa = PBXTargetDependency;\n"
        f"{T}{T}{T}target = {i['target']} /* ShareExtension */;\n"
        f"{T}{T}{T}targetProxy = {i['proxy']} /* PBXContainerItemProxy */;\n"
        f"{T}{T}}};\n"
        "/* End PBXTargetDependency section */",
    )

    # --- XCBuildConfiguration（Debug／Release／Profile）
    def cfg(key, name, debug):
        opt = f'{T}{T}{T}{T}SWIFT_OPTIMIZATION_LEVEL = "-Onone";\n' if debug else ""
        return (
            f"{T}{T}{i[key]} /* {name} */ = {{\n"
            f"{T}{T}{T}isa = XCBuildConfiguration;\n"
            f"{T}{T}{T}baseConfigurationReference = {GENERATED_XCCONFIG} /* Generated.xcconfig */;\n"
            f"{T}{T}{T}buildSettings = {{\n"
            f"{T}{T}{T}{T}CLANG_ENABLE_MODULES = YES;\n"
            f"{T}{T}{T}{T}CODE_SIGN_STYLE = Automatic;\n"
            f'{T}{T}{T}{T}CURRENT_PROJECT_VERSION = "$(FLUTTER_BUILD_NUMBER)";\n'
            f"{T}{T}{T}{T}INFOPLIST_FILE = ShareExtension/Info.plist;\n"
            f"{T}{T}{T}{T}IPHONEOS_DEPLOYMENT_TARGET = 15.0;\n"
            f"{T}{T}{T}{T}LD_RUNPATH_SEARCH_PATHS = (\n"
            f'{T}{T}{T}{T}{T}"$(inherited)",\n'
            f'{T}{T}{T}{T}{T}"@executable_path/Frameworks",\n'
            f'{T}{T}{T}{T}{T}"@executable_path/../../Frameworks",\n'
            f"{T}{T}{T}{T});\n"
            f'{T}{T}{T}{T}MARKETING_VERSION = "$(FLUTTER_BUILD_NAME)";\n'
            f"{T}{T}{T}{T}PRODUCT_BUNDLE_IDENTIFIER = io.molly.drawer.ShareExtension;\n"
            f'{T}{T}{T}{T}PRODUCT_NAME = "$(TARGET_NAME)";\n'
            f"{T}{T}{T}{T}SKIP_INSTALL = YES;\n"
            f"{opt}"
            f"{T}{T}{T}{T}SWIFT_VERSION = 5.0;\n"
            f'{T}{T}{T}{T}TARGETED_DEVICE_FAMILY = "1,2";\n'
            f"{T}{T}{T}}};\n"
            f"{T}{T}{T}name = {name};\n"
            f"{T}{T}}};\n"
        )

    text = sub_once(
        text,
        "/* End XCBuildConfiguration section */",
        cfg("cfg_debug", "Debug", True)
        + cfg("cfg_release", "Release", False)
        + cfg("cfg_profile", "Profile", False)
        + "/* End XCBuildConfiguration section */",
    )

    # --- XCConfigurationList
    text = sub_once(
        text,
        "/* End XCConfigurationList section */",
        f'{T}{T}{i["cfg_list"]} /* Build configuration list for PBXNativeTarget "ShareExtension" */ = {{\n'
        f"{T}{T}{T}isa = XCConfigurationList;\n"
        f"{T}{T}{T}buildConfigurations = (\n"
        f"{T}{T}{T}{T}{i['cfg_debug']} /* Debug */,\n"
        f"{T}{T}{T}{T}{i['cfg_release']} /* Release */,\n"
        f"{T}{T}{T}{T}{i['cfg_profile']} /* Profile */,\n"
        f"{T}{T}{T});\n"
        f"{T}{T}{T}defaultConfigurationIsVisible = 0;\n"
        f"{T}{T}{T}defaultConfigurationName = Release;\n"
        f"{T}{T}}};\n"
        "/* End XCConfigurationList section */",
    )
    return text, i


# ---------------------------------------------------------------------------
# old-style plist 解析器（只為了驗證，不依賴 pip 套件）

TOKEN = re.compile(
    r'\s*(?:(/\*.*?\*/)|(//[^\n]*)|("(?:\\.|[^"\\])*")|([{}()=;,])|((?:(?!/\*)[^\s{}()=;,"])+))', re.S
)


def parse_plist(text):
    text = text.split("\n", 1)[1] if text.startswith("// !$*UTF8*$!") else text
    pos = 0
    toks = []
    while pos < len(text):
        m = TOKEN.match(text, pos)
        if not m:
            if text[pos:].strip() == "":
                break
            raise ValueError(f"無法解析：位置 {pos}: {text[pos:pos+40]!r}")
        pos = m.end()
        if m.group(1) or m.group(2):
            continue
        if m.group(3) is not None:
            toks.append(("s", m.group(3)[1:-1]))
        elif m.group(4):
            toks.append(("p", m.group(4)))
        else:
            toks.append(("s", m.group(5)))
    idx = 0

    def value():
        nonlocal idx
        kind, v = toks[idx]
        if kind == "p" and v == "{":
            idx += 1
            d = {}
            while not (toks[idx][0] == "p" and toks[idx][1] == "}"):
                k = toks[idx][1]
                idx += 1
                assert toks[idx] == ("p", "="), f"期待 = 在 {k}"
                idx += 1
                d[k] = value()
                assert toks[idx] == ("p", ";"), f"期待 ; 在 {k}"
                idx += 1
            idx += 1
            return d
        if kind == "p" and v == "(":
            idx += 1
            a = []
            while not (toks[idx][0] == "p" and toks[idx][1] == ")"):
                a.append(value())
                if toks[idx] == ("p", ","):
                    idx += 1
            idx += 1
            return a
        idx += 1
        return v

    out = value()
    assert idx == len(toks), "解析後還有多餘內容"
    return out


def verify(text, require_ext=True):
    root = parse_plist(text)
    objs = root["objects"]
    ids = re.findall(r"^\t\t([0-9A-F]{24}) ", text, re.M)
    dup = {x for x in ids if ids.count(x) > 1}
    assert not dup, f"重複的 ID：{dup}"
    assert set(ids) == set(objs), "定義的 ID 與解析出的 objects 不一致"

    # 所有看起來像 ID 的字串值都要指到存在的 object（含 remoteGlobalIDString、rootObject）
    def walk(v, path):
        if isinstance(v, dict):
            for k, x in v.items():
                walk(x, path + [k])
        elif isinstance(v, list):
            for x in v:
                walk(x, path)
        elif isinstance(v, str) and re.fullmatch(r"[0-9A-F]{24}", v):
            assert v in objs, f"未定義的引用 {v}（{'/'.join(path)}）"

    walk(root["objects"], [])
    assert root["rootObject"] in objs

    if not require_ext:
        return len(objs)

    targets = {o["name"]: (k, o) for k, o in objs.items() if o.get("isa") == "PBXNativeTarget"}
    assert "ShareExtension" in targets, "沒有 ShareExtension target"
    tid, t = targets["ShareExtension"]
    rid, r = targets["Runner"]
    assert t["productType"] == "com.apple.product-type.app-extension"
    assert objs[t["productReference"]]["path"] == "ShareExtension.appex"
    assert objs[t["productReference"]]["explicitFileType"] == "wrapper.app-extension"
    assert tid in objs[root["rootObject"]]["targets"]
    assert tid in objs[root["rootObject"]]["attributes"]["TargetAttributes"]

    # 擴充的 phases
    kinds = [objs[p]["isa"] for p in t["buildPhases"]]
    assert kinds == ["PBXSourcesBuildPhase", "PBXFrameworksBuildPhase", "PBXResourcesBuildPhase"], kinds
    src = objs[t["buildPhases"][0]]
    assert [objs[objs[b]["fileRef"]]["path"] for b in src["files"]] == ["ShareViewController.swift"]

    # 設定
    cl = objs[t["buildConfigurationList"]]
    names = sorted(objs[c]["name"] for c in cl["buildConfigurations"])
    assert names == ["Debug", "Profile", "Release"], names
    for c in cl["buildConfigurations"]:
        s = objs[c]["buildSettings"]
        assert s["PRODUCT_BUNDLE_IDENTIFIER"] == "io.molly.drawer.ShareExtension"
        assert s["INFOPLIST_FILE"] == "ShareExtension/Info.plist"
        assert s["SKIP_INSTALL"] == "YES" and s["SWIFT_VERSION"] == "5.0"
        assert s["IPHONEOS_DEPLOYMENT_TARGET"] == "15.0"
        assert s["TARGETED_DEVICE_FAMILY"] == "1,2"
        assert "CODE_SIGN_ENTITLEMENTS" not in s and "DEVELOPMENT_TEAM" not in s

    # Runner：dependency、embed phase 在 Thin Binary 之前，且 phase 內容正確
    deps = [objs[d] for d in r["dependencies"]]
    assert any(objs[d["targetProxy"]]["remoteGlobalIDString"] == tid for d in deps)
    assert any(d["target"] == tid for d in deps)
    names = [objs[p].get("name", objs[p]["isa"]) for p in r["buildPhases"]]
    assert names.index("Embed Foundation Extensions") < names.index("Thin Binary"), names
    emb = next(objs[p] for p in r["buildPhases"] if objs[p].get("name") == "Embed Foundation Extensions")
    assert emb["dstSubfolderSpec"] == "13" and emb["dstPath"] == ""
    assert [objs[objs[b]["fileRef"]]["path"] for b in emb["files"]] == ["ShareExtension.appex"]
    rsrc = next(objs[p] for p in r["buildPhases"] if objs[p]["isa"] == "PBXSourcesBuildPhase")
    assert "ShareHandoff.swift" in [objs[objs[b]["fileRef"]]["path"] for b in rsrc["files"]]

    # 檔案真的存在
    base = PBX.parent.parent
    for rel in ("ShareExtension/ShareViewController.swift", "ShareExtension/Info.plist",
                "Runner/ShareHandoff.swift"):
        assert (base / rel).exists(), f"缺檔：ios/{rel}"
    return len(objs)


def main():
    text = PBX.read_text(encoding="utf-8")
    if "--check" in sys.argv:
        print("OK，objects =", verify(text))
        return
    if "ShareExtension" in text:
        print("project.pbxproj 已有 ShareExtension，略過。")
        print("OK，objects =", verify(text))
        return
    verify(text, require_ext=False)  # 原檔先確認可解析
    new, ids = add_share_extension(text)
    n = verify(new)
    PBX.write_text(new, encoding="utf-8")
    print("已寫入。objects =", n)
    for k, v in ids.items():
        print(f"  {k:14} {v}")


if __name__ == "__main__":
    main()
