# 給程程的工作守則（每次開 session 都會自動讀到）

這是 Molly 的自用 App（畫匣／Drawer）。設計稿在 Claude Design canvas：
https://claude.ai/code/artifact/c37d0721-7399-4183-b54c-aef4faf8ebc4
（用 Artifact 工具的 `read` 讀 `project/` 底下的檔案；每個畫面是一個 `project/<名稱>.dc.html`）

## 每次開工

1. 打開 `docs/CHANGELOG.md`，找**還沒有 ✅ 的編號**（`D-xxx`），由小到大做。標〔試稿〕的不要做。
2. 規格、資料模型、畫面清單在 `docs/HANDOFF.md`。不用每次全讀，**做到哪一部分就讀哪一節**。
3. **做或改任何畫面之前，先讀該畫面的 artboard `.dc.html`**。設計稿是唯一依據，HANDOFF 只是文字說明。

## 硬性規則

- icon 一律從 artboard 抄 SVG path（`flutter_svg`），不准用 Material Icons 頂替。
- 導覽列只出現在瀏覽用的頁面；新增、編輯、詳情、預覽、多選、管理、設定頁都沒有。以 artboard 有沒有畫 `<nav>` 為準。
- 介面文字全部放 ARB 檔（`lib/l10n/`），不准寫死中文。用詞依 HANDOFF 第 1 節（關聯／連結／帳號／草稿／新增 vs 選擇）。
- 介面文字是書面語繁體中文，不是粵語口語。
- 檔案路徑、資料夾名稱一律英文（例：下載存到 `Pictures/Drawer`）。
- 設計稿沒畫的、或你想改的地方：**先問 Molly，不要做完才告知。**

## 每次完成

- push 後等 GitHub Actions 出 APK，回報時附上 Release 下載連結。
- 在 CHANGELOG 對應編號後面標 `✅ commit xxxxxxx`；只做了一部分就標 `🟡 未完成：…`。
- 回報時列出「這次跟設計稿不一樣的地方」，沒有就寫「無」。
