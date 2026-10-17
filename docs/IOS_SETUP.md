# iOS／iPadOS 安裝與設定（免費 Apple ID 側載）

畫匣的 iOS 版由 GitHub Actions 的 `Build iOS IPA (unsigned)` 工作流程產生**未簽名**的 IPA，
再用 AltStore 或 Sideloadly 以你自己的免費 Apple ID 簽名、安裝到 iPhone／iPad。
不需要付費的 Apple Developer Program，也不需要 Mac（Mac 只在你想自己用 Xcode 建置時才需要）。

- Bundle ID：`io.molly.drawer`
- 顯示名稱：畫匣
- 最低系統：iOS／iPadOS 15
- 裝置：iPhone 與 iPad（含分割檢視、Slide Over）

---

## 一、取得 IPA

1. 把程式碼推到 GitHub，等 Actions 的 `Build iOS IPA (unsigned)` 跑完（約 10–20 分鐘）。
2. 到 Releases，找標題為 `iOS Build N`、tag 為 `ios-build-N` 的版本，下載 `drawer-ios-N.ipa`。
   （iOS 的編號與 Android 的 `debug-build-N` 各自計數，兩者不會對齊。）

---

## 二、（選用）設定 Google 登入，讓雲端同步可用

**不做這一節也能用**：畫匣離線功能完全正常，只是「連結 Google 帳號／雲端同步」會顯示登入失敗，
App 不會當掉。

### 1. 在 Google Cloud 建立 iOS 用戶端 ID

1. 打開 [Google Cloud 主控台](https://console.cloud.google.com/)，選擇與 Android／Web 用戶端相同的專案。
2. 左側「API 和服務」→「憑證」→「建立憑證」→「OAuth 用戶端 ID」。
3. 應用程式類型選 **iOS**。
4. 名稱隨意（例如 `Drawer iOS`）；**Bundle ID 填 `io.molly.drawer`**。
5. 建立後會得到一組用戶端 ID，格式如 `1234567890-abcdefg.apps.googleusercontent.com`。
6. 確認 Drive API 已啟用，且 OAuth 同意畫面的範圍包含 `drive.appdata`；
   若同意畫面還在「測試中」，要把你的 Google 帳號加入「測試使用者」。

### 2. 把用戶端 ID 填進專案（二選一）

**方式 A（建議）：GitHub Secret，不用改程式碼**

1. GitHub 倉庫 → Settings → Secrets and variables → Actions → New repository secret。
2. 名稱 `GOOGLE_IOS_CLIENT_ID`，值貼上完整的 iOS 用戶端 ID（含 `.apps.googleusercontent.com`）。
3. 重新跑一次 iOS 工作流程。工作流程會在建置前自動把它寫入 `ios/Runner/Info.plist`
   的 `GIDClientID` 與 URL scheme（反轉後的 `com.googleusercontent.apps.<ID 前半>`）。

**方式 B：直接改 `ios/Runner/Info.plist`**

把兩處 `REPLACE_WITH_IOS_CLIENT_ID` 換成你的用戶端 ID：

- `GIDClientID`：`1234567890-abcdefg.apps.googleusercontent.com`
- `CFBundleURLTypes` → `CFBundleURLSchemes`：`com.googleusercontent.apps.1234567890-abcdefg`
  （就是把用戶端 ID 的 `.apps.googleusercontent.com` 去掉，再加上前綴 `com.googleusercontent.apps.`）

### 3. Web 用戶端 ID（與 Android 共用）

`GOOGLE_SERVER_CLIENT_ID` 這個 Secret 與 Android 共用同一個 Web 類型的用戶端 ID，
iOS 工作流程已經用 `--dart-define` 帶入，不用另外設定。

### 4. 側載後 Bundle ID 可能被改掉（重要）

免費 Apple ID 簽名時，部分工具會**改寫 Bundle ID**（例如 AltStore 會變成 `io.molly.drawer.<你的 Team ID>`）。
Google 會檢查登入請求的 Bundle ID 是否與 iOS 用戶端 ID 登記的一致，不一致時登入會失敗。處理方式：

- Sideloadly：在 Advanced Options 裡把 Bundle ID 保持為 `io.molly.drawer`（若免費帳號的該 ID 已被占用，才需要改）。
- 若工具一定要改 ID：到 Google Cloud 把 iOS 用戶端 ID 的 Bundle ID 改成實際安裝後的那一個，
  或另外再建一個。

---

## 三、用 AltStore 或 Sideloadly 安裝

### Sideloadly（較單純）

1. 電腦（Windows 或 Mac）安裝 [Sideloadly](https://sideloadly.io/)；Windows 需要從 Apple 官網版安裝 iTunes 與 iCloud。
2. 用傳輸線連接 iPhone／iPad，並在裝置上選「信任這部電腦」。
3. 把 `drawer-ios-N.ipa` 拖進 Sideloadly，輸入你的 Apple ID，按 Start。
4. iPhone／iPad：設定 → 一般 → VPN 與裝置管理 → 點你的 Apple ID → 信任。
5. iOS 16 以上還需開啟「開發者模式」：設定 → 隱私權與安全性 → 開發者模式 → 開啟並重新啟動。

### AltStore

1. 電腦安裝 [AltServer](https://altstore.io/)，依官網步驟把 AltStore 裝到裝置上。
2. 把 IPA 傳到裝置（AirDrop 或檔案 App），在 AltStore 的「My Apps」按 `+` 選擇該檔案。
3. 一樣需要信任描述檔與開啟開發者模式（步驟同上）。

### 更新版本

直接用新的 IPA 以同一個 Apple ID 覆蓋安裝，**資料會保留**（Bundle ID 不變的前提下）。
若 Bundle ID 被工具改過，新舊版本請用同樣的設定，否則會被當成不同的 App，資料不會互通。

---

## 四、免費 Apple ID 的限制

- **7 天到期**：憑證只有 7 天效期，到期後 App 無法開啟。要在到期前重新簽名：
  AltStore 可在同一個 Wi‑Fi 下由 AltServer 自動刷新；Sideloadly 需再安裝一次（或使用其自動刷新功能）。
  重新簽名**不會清掉資料**。
- 同時最多 3 個側載 App、每週有新增 App ID 的數量上限。
- 不能使用 Share Extension、App Groups、推播通知、iCloud 等需要付費帳號的能力。
- **App 圖示切換可以用**（我的 → App 圖示）；iOS 每次切換都會彈出系統提示，這是系統行為，無法關閉。
- 沒有 TestFlight／App Store 發佈。

## 五、目前 iOS 版「還沒有」的功能

- **從其他 App 分享進畫匣（Share Extension）尚未包含。**
  Android 的「分享到畫匣」在 iOS 沒有對應功能；要加進圖片請在 App 內用「新增」選擇相簿或檔案。
  這項需要 Share Extension＋App Group，免費 Apple ID 做不到，需要付費開發者帳號。
- 其他 iPad 專屬的原生互動（拖放接收等）未在這一步處理。

---

## 六、權限說明（已寫在 `ios/Runner/Info.plist`）

| 權限 | 用途 |
| --- | --- |
| 相簿讀取（`NSPhotoLibraryUsageDescription`） | 從相簿選取圖片、影片 |
| 相簿新增（`NSPhotoLibraryAddUsageDescription`） | 下載圖片、影片到相簿 |
| 相機（`NSCameraUsageDescription`） | 拍照加入作品 |

下載的圖片存在相簿的 `Drawer` 相簿（與 Android 的 `Pictures/Drawer` 對應）。

## 七、給維護者：沒辦法在 Linux 驗證的部分

iOS 的建置、原生 Swift（影片探測、App 圖示切換）、Pod 整合與 Google 登入都**沒有在實機或 Xcode 上測過**。
第一次跑工作流程若失敗，請把 Actions 的錯誤紀錄貼回來，通常是 Xcode／Pod 版本相容問題。
