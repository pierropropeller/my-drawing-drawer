# Google 登入與 Drive 同步設定

App 的同步程式（本機優先、Drive App 專用資料夾、衝突以 `updatedAt` 較新者勝）已經寫好並經過測試，
但要真正連上 Google 帳號，需要在 Google Cloud 建立 OAuth 設定。這一步需要你的 Google 帳號，**只能由你自己做**。
沒有設定時，App 其他功能完全正常（離線使用），按「連結 Google 帳號」會顯示連結失敗。

## 步驟

1. 開啟 <https://console.cloud.google.com/>，建立一個專案（例如「畫坑」）。
2. **啟用 API**：「API 和服務」→「程式庫」→ 搜尋 **Google Drive API** → 啟用。
3. **OAuth 同意畫面**：
   - 使用者類型選「外部」。
   - 填 App 名稱（畫坑）與你的 email。
   - 「測試使用者」加入你自己的 Google 帳號（自用的話停在「測試中」狀態即可，不需要送審）。
   - 「範圍」加入 `https://www.googleapis.com/auth/drive.appdata`（只存取 App 專用資料夾，Drive 裡看不到）。
4. **建立兩個 OAuth 用戶端 ID**（「API 和服務」→「憑證」→「建立憑證」→「OAuth 用戶端 ID」）：
   1. 類型 **Android**：
      - 套件名稱：`app.huakeng.huakeng`
      - SHA-1 憑證指紋（repo 內固定的 debug 簽名檔）：
        `24:A9:F0:CA:9A:29:DF:92:EA:A0:F7:7C:54:E5:B7:52:D2:09:1E:41`
   2. 類型 **網頁應用程式**（Web application）：名稱隨意，不需填重新導向 URI。
      建立後複製它的 **用戶端 ID**（`xxxx.apps.googleusercontent.com`）。
5. 把第 4-2 步的 Web 用戶端 ID 設成 GitHub Secret：
   repo →「Settings」→「Secrets and variables」→「Actions」→「New repository secret」，
   名稱 `GOOGLE_SERVER_CLIENT_ID`，值貼上該用戶端 ID。
6. 重新跑一次 build（任何 push，或在 Actions 頁手動執行 workflow）。新的 APK 就會帶有這個設定。

## 驗證

安裝新 APK → 「我的」→「備份與同步」→「連結 Google 帳號」→ 選帳號並允許存取。
連結成功後會立即同步；之後有網絡時自動上傳，前台依設定的間隔（1／5／15／30 分鐘）自動刷新。
第二台裝置（iPad 版之後）用同一個 Google 帳號連結即可拉取同一份資料。

## 同步怎麼運作（給日後維護）

- Drive 的 `appDataFolder`（使用者看不到）裡每筆實體一個 JSON：`meta__{種類}__{id}.json`；圖片是 `images__{檔名}`。
- 腦洞／草稿／成圖的 tag、連接關係、圖片清單、社交媒體連結都內嵌在擁有它的文件裡。
- 上傳：本機 `updatedAt` 比「上次同步的版本」新的實體；圖片先傳、文件後傳。
- 拉取：遠端修改時間有變的文件，若遠端 `updatedAt` 比本機新就套用（last-write-wins）。
- 刪除是軟刪除（`deletedAt`），照樣以文件同步。
- 更換 Google 帳號時清掉同步記錄，本機資料整個上傳到新帳號，舊帳號的備份不會被刪。
- 程式在 `lib/sync/`，測試在 `test/sync_test.dart`（兩台裝置透過同一個遠端同步，含衝突、刪除、換帳號）。
