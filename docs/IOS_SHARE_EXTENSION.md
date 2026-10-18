# iOS 分享擴充（Share Extension）

在照片、檔案、Safari 等 App 選圖片 → 分享 → 「畫匣」，會打開畫匣並跳出既有的「加入到」sheet
（與 Android 的分享進來是同一套流程，見 `lib/ui/share/*`、`lib/share/*`）。

## 為什麼不用 App Group

Molly 用 Sideloadly 以免費 Apple ID 側載。免費帳號可能拿不到 App Group entitlement，
宣告了可能讓簽名或安裝失敗。所以**整個專案沒有任何 entitlements 檔、沒有 App Group、沒有 Keychain sharing**。
擴充與主程式是兩個獨立的行程，沒有共用資料夾，因此改走「通用剪貼簿 + URL scheme」交接。

## 資料流

```
照片／其他 App ──分享──▶ ShareExtension（io.molly.drawer.ShareExtension）
   1. NSItemProvider 讀出圖片（最多 30 張，一張一張循序處理）
   2. 小的 JPEG／PNG／GIF／WebP 原樣保留；HEIC 等其他格式、或單張 > 6 MB：用 ImageIO 縮到最長邊 2560 px
      （總量快滿時 1280 px），轉 JPEG 品質 0.85；全部加總上限 32 MB（超過的張會被略過）
   3. UIPasteboard.general.setItems：
        item 0：{ "io.molly.drawer.share": JSON {v, count, createdAt} }
        item 1…n：{ "io.molly.drawer.share.image": 圖片 Data }
      選項 localOnly = true、expirationDate = 5 分鐘後
   4. 喚起主程式 drawer://share（見下）
                                   │
主程式 AppDelegate ◀──────────────┘
   - UIApplication.didBecomeActive／application(_:open:)（drawer://share）／Dart 呼叫 getInitialShare 時檢查
   - UIPasteboard.general.contains(pasteboardTypes: ["io.molly.drawer.share"])
       沒有 → 什麼都不做（完全不讀剪貼簿，不會跳「貼上自…」提示）
       有   → 讀出圖片資料 → 清掉剪貼簿 → 寫成 Caches/share_import/share_<時間>_<n>.<副檔名>
   - 經 MethodChannel `io.molly.drawer/share` 交給 Dart（與 Android 同一套）：
       冷啟動：Dart 呼叫 getInitialShare 取得；熱啟動：原生呼叫 Dart 的 onShare
   - Dart：ShareInbox 排隊 → ShareHost 開「加入到」sheet → 使用者確認後才複製進 App 儲存空間（D-053）
```

### 喚起主程式

iOS 沒有給 Share Extension 開啟主程式的官方 API。擴充依序嘗試：

1. `extensionContext.open(_:)`（官方 API，Share Extension 通常回 false，但無害；回 true 就直接關閉擴充）。
2. 沿著 `UIResponder.next` 找到會回應 `openURL:options:completionHandler:` 的物件（`UIApplication`），
   用 `method(for:)` 取得實作後呼叫（不用已被封鎖的舊 `openURL:`）。

兩者都沒有可靠的成功訊號，所以約 1 秒後擴充一律顯示「已儲存，請打開畫匣」＋「完成」鍵。
喚起成功時使用者已經在畫匣裡，不會看到這個畫面；失敗時資料仍在剪貼簿裡（5 分鐘內），
手動打開畫匣（回到前景）就會接手。

### 主程式端的安全措施

- 只處理帶有我們自訂 type 的剪貼簿內容；沒有該 type 時完全不讀取。
- 資料帶有 `createdAt`，超過 10 分鐘（或時鐘異常）就丟棄並清掉。
- 取出後立刻 `items = []` 清掉剪貼簿（此時剪貼簿內容本來就是擴充放的）。
- `Info.plist` 設 `FlutterDeepLinkingEnabled = false`：`drawer://share` 由 AppDelegate 自己吃掉，
  不會被 Flutter 當成路由（開啟時沒設的話，未處理的 URL 還會被丟回系統）。
- 新增的 `drawer` URL scheme 排在 Google 登入那一筆**之後**：`ios.yml` 用 `CFBundleURLTypes:0` 改寫 Google 的 scheme，順序不可對調。

## 檔案

| 檔案 | 用途 |
|---|---|
| `ios/ShareExtension/ShareViewController.swift` | 擴充本體（純 UIKit，不連 Flutter／Pods）。介面文字直接寫在檔內（擴充沒有 ARB）。 |
| `ios/ShareExtension/Info.plist` | `NSExtension`：`com.apple.share-services`、只對圖片啟用（最多 30 張）、`CFBundleDisplayName` = 畫匣。 |
| `ios/Runner/ShareHandoff.swift` | 主程式端：偵測、讀取、寫暫存檔、清剪貼簿。 |
| `ios/Runner/AppDelegate.swift` | `io.molly.drawer/share` channel、`didBecomeActive`、`application(_:open:)`。 |
| `ios/Runner/Info.plist` | `drawer` URL scheme、`FlutterDeepLinkingEnabled`。 |
| `ios/Runner.xcodeproj/project.pbxproj` | 新增 `ShareExtension` target（由 `tool/add_share_extension.py` 產生）。 |
| `test/share_channel_ios_test.dart` | Dart 側（假通道）測試。 |

擴充沒有自己的圖示：App 圖示由主程式的 AppIcon 提供。兩邊的常數（pasteboard type、scheme）
在 `ShareViewController.swift` 與 `ShareHandoff.swift` 各寫一份，改的時候要一起改。

## 已知限制

- **會覆蓋使用者原本的剪貼簿**：擴充用 `setItems` 取代剪貼簿內容，分享後使用者剛複製的東西會消失（iOS 沒有安全的暫存方式）。
- **iOS 16 起可能跳「允許貼上」**：主程式讀取別的行程寫的剪貼簿資料時，系統可能問一次「畫匣想貼上自 畫匣」（同一 App 的擴充是否會問，各版本行為不同）。選「允許貼上」即可；若選「不允許」，這次分享會被丟掉（剪貼簿仍會被清掉）。
- 只支援圖片（影片、PDF 等不會出現在分享清單）。
- 一次最多 30 張；總量上限 32 MB，超過的張會略過；HEIC 一律轉成 JPEG；過大的 PNG 會變成 JPEG（失去透明）。
- 剪貼簿資料 5 分鐘後過期；分享後超過 5 分鐘才打開畫匣，不會有東西。
- 擴充的記憶體上限約 120 MB，所以圖片是一張一張處理。
- Sideloadly：**不要勾選「Remove app extensions」類的選項**；免費帳號每週 App ID 數量有限（主程式 + 擴充各佔一個）。若 Sideloadly 因 App ID 上限失敗，就只能先移除擴充（此時分享清單沒有畫匣，其他功能不受影響）。
- 側載後 Bundle ID 會被改成帶你 Team 的形式（見 `docs/IOS_SETUP.md`），擴充的 Bundle ID 會由 Sideloadly 一併改成「主程式 ID + `.ShareExtension`」；`drawer://` scheme 與 Bundle ID 無關，不受影響。

## 除錯

- Mac 上開 Console.app，連接 iPhone／iPad，搜尋列輸入 `ShareExtension`（行程名稱）或 `io.molly.drawer`，再操作一次分享。
- 看不到「畫匣」在分享清單：確認裝的是含擴充的 IPA（解壓後 `Payload/Runner.app/PlugIns/ShareExtension.appex` 存在）；
  在分享清單最下方「編輯動作」把畫匣打開；重開機一次（系統快取擴充清單）。
- 分享後畫匣沒有跳 sheet：看 Console 是否有 `ShareExtension` 崩潰（記憶體）；
  確認 5 分鐘內打開畫匣；在畫匣裡長按貼上確認剪貼簿是否已被清掉（被清掉＝主程式有取走，問題在 Dart 端）。
- 檢查 pbxproj：`python3 tool/add_share_extension.py --check`（解析並驗證引用）。
  在有 Xcode 的 Mac 上也可以直接打開 `ios/Runner.xcodeproj` 看 `ShareExtension` target。
