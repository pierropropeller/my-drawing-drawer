# iOS／iPadOS 匯入圖片的各條路徑：是否無損、上限、已知限制

Molly 最在意**圖片品質（不要壓縮）**。原則：匯入進畫匣的檔案 = 來源的**原始位元組**（HEIC 就是 HEIC，不轉檔、
不縮圖、不重新編碼）。縮圖（`thumbs/`）只是額外產物，不會覆蓋原圖。

Swift 原生碼在 Linux 沙盒無法編譯或執行，只能靠 GitHub CI 的 `flutter build ios --no-codesign` 驗證建置，
行為要靠下面的真機清單確認。

## 一覽

| 路徑 | 入口 | 無損？ | 上限 | 主要限制 |
|---|---|---|---|---|
| 分享擴充 | 照片／檔案／Safari 的分享選單 → 畫匣 | 是（原始位元組） | 單次累計 64 MB，超過停止收並明講 | 走剪貼簿交接；來源 App 可能先轉檔（見下） |
| 貼上 | 加圖來源選單 →「貼上」 | 是（原始位元組；沒有原始格式時退回 PNG） | 無（沒有 App 端上限） | 點「貼上」時 iOS 16+ 會跳「允許貼上」 |
| 分屏拖放 | 在 Split View／Slide Over 從照片／檔案拖進畫匣 | 是（原樣複製） | 無 | 只有官方圖冊的列表頁與新增官方圖頁收；iCloud 照片要先下載，可能很久 |
| App 內選圖（自家選擇器） | 加圖來源 →「相簿」 | 是（`originFile`） | 無 | 編輯過的照片拿到的是**未編輯的原始檔**（見下） |
| 檔案 | 加圖來源 →「檔案」 | 是（UIDocumentPicker，不壓縮） | 無 | — |
| 相機 | 加圖來源 →「拍照」 | 近乎無損（`UIImageJPEGRepresentation` 品質 1.0 重新編碼） | 無 | 不是 HEIC；是 JPEG 最高品質 |

## 1. 分享擴充（`ios/ShareExtension/ShareViewController.swift` → `ios/Runner/ShareHandoff.swift`）

流程與安全措施見 `docs/IOS_SHARE_EXTENSION.md`。這裡只寫品質相關：

- 每個項目依 `registeredTypeIdentifiers` 挑**原始型別**：GIF／WebP（可能動畫）> HEIC > PNG > JPEG > HEIF >
  其他具體圖片型別（TIFF、BMP、RAW…）；最後才用泛型 `public.image`（來源可能替我們轉檔，但至少不丟圖）。
- `loadFileRepresentation` 取得檔案 → `copyItem`（APFS clone）到擴充 tmp → 最後 `Data(contentsOf:, options: .mappedIfSafe)`
  讀入並放進剪貼簿（自訂 type `io.molly.drawer.share.image`，item 0 的 JSON 記錄每張的 `uti` 與 `ext`）。
  **全程沒有 ImageIO 重新編碼或縮放。**
- 主程式取出後依 `ext` 寫成 `Caches/share_import/share_<時間>_<n>.heic`（沒有 ext 時看檔頭，HEIC 認 `ftyp` brand）。
  使用者在「加入到」sheet 確認後，才由 `ImageStore.import` 位元組原樣複製進 App 儲存空間。
- **上限**：累計 64 MB（`totalBudget`）。超過時停止收更多，畫面顯示「已加入 N 張，其餘 M 張因 iOS 擴充容量限制未加入，
  請改用拖放或 App 內選圖」，並停在畫面上等使用者按「打開畫匣」（不自動跳走，避免說明被略過）。
  單張就超過上限時，一張都不會加入，畫面同樣明講。**絕不為了塞進去而降畫質。**
  64 MB 是保守值（擴充記憶體上限約 120 MB，放進剪貼簿時系統會序列化一份）；真機驗證穩定後可調高。
- **來源 App 可能先轉檔**：從「照片」分享時，分享面板左上的「選項」若選「最相容」，照片 App 會先把 HEIC 轉成 JPEG
  才交給擴充（那一步發生在擴充之前，我們攔不到）。要拿 HEIC 原檔：「選項」→ 格式選「自動」或「原始」
  （iOS 版本不同，字樣略有差異）；或改用拖放／App 內選圖。
- **剪貼簿會被覆蓋**（既有限制）：分享後使用者原本複製的內容會消失。

## 2. 貼上（`ios/Runner/ClipboardImage.swift` ← `lib/ui/media_source/media_source_services.dart`）

- 以前：`pasteboard` 套件的 `Pasteboard.image` → iOS 端 `UIPasteboard.general.image?.pngData()`，
  **解碼後重新編成 PNG**（像素不失真，但檔案變大，原格式／EXIF／色彩描述檔丟失，HEIC 變 PNG）。
- 現在（僅 iOS）：自己的通道 `io.molly.drawer/clipboard` 的 `readImage {dir}`：
  依 GIF > WebP > HEIC > PNG > JPEG 找剪貼簿裡存在的原始型別，`UIPasteboard.general.data(forPasteboardType:)`
  取原始 `Data`，原樣寫成 `dir/paste_<時間>.<heic|png|jpg|gif|webp>`，回傳路徑。
  只有剪貼簿完全沒有上述型別、但有系統轉換過的圖片（例如只有 TIFF／`UIImage`）時，才退回 `image.pngData()`（無損但不是原格式）。
- 保持「按下貼上才讀」：選單打開時 `probe()` 在 iOS 回 `unknown`，不碰剪貼簿；原生端判斷用的 `types`／`hasImages` 也不會跳提示。
- Dart 端：通道不存在或丟錯時退回 `pasteboard`（PNG 重編，至少貼得上）；原生回 `null`＝剪貼簿沒有圖，不會再讀第二次。
- Android／其他平台：不變（`pasteboard`）。
- **已知限制**：剪貼簿裡同時有多種表示（例如來源同時放了 HEIC 與它轉出來的 JPEG）時，依上面的固定順序挑，
  不保證是「來源認為最原始的那一種」。從「照片」複製單張照片通常含 HEIC；從 Safari 複製網頁圖片通常是網站的原格式。

## 3. 分屏拖放（`ios/Runner/DropReceiver.swift` ← `lib/ui/media_source/drop_target_service.dart`）

- 在 Flutter 根 view 加 `UIDropInteraction`，接受 `public.image`／`public.movie`，`UIDropProposal(operation: .copy)`。
  座標用 view 的邏輯 point（和 Flutter 全域座標同一個系統，因為 Flutter view 填滿視窗）。
- 契約：原生→Dart `enter {count,x,y}`／`move {x,y}`／`leave`／`drop {x,y,items:[{id,name}]}`；
  Dart→原生 `start`／`load {id}`／`cancel {id}`。
- UIKit 規定要在 `performDrop` 內開始載入，所以放開的當下就替每個項目 `loadFileRepresentation`
  並**照原樣** `copyItem` 到 `Caches/drop_import/<id>.<原副檔名>`（HEIC 不轉檔、影片不重新編碼）；
  `load {id}` 只是等那份結果（iCloud 照片會先下載，可能很久）。Dart 取走路徑後由既有匯入流程複製進 App 儲存空間；
  暫存檔在下一次放開／下次 `start` 時，超過 2 小時的會被清掉（沒人 `load` 的項目，下一次放開時也會丟掉）。
- 同一個項目有多種格式時的挑選順序與分享擴充相同（GIF／WebP > HEIC > PNG > JPEG…）。
- **已知限制**：
  - 放在沒有 `DropZone` 的頁面（或頁面被別的頁面蓋住）時，檔案其實已經複製了，但沒人取走，之後被清掉（浪費一點時間與空間，不影響使用）。
  - `start` 找不到 Flutter view 時最多重試約 5 秒，之後回 `false`（功能不啟用，且 Dart 端會記住這個結果直到重啟）。
  - Android 端還沒做。

## 4. App 內選圖與其他路徑的檢查結論

逐一檢查程式碼（`lib/media`、`lib/ui/media_source`、`lib/data/image_store.dart`）：

| 路徑 | 結論 | 依據 |
|---|---|---|
| 自家相簿選擇器（`photo_manager`） | **無損** | `PhotoManagerGallery.export` 用 `AssetEntity.originFile ?? file`。iOS 的 `originFile` 走 `fetchOriginImageFile`（`PHAssetResource` 原始資源），HEIC 原樣。`?? file` 只在 `originFile` 失敗（回 null）時才用，那一條可能是系統輸出的版本（見下）。縮圖用 `thumbnailDataWithSize`，只是畫面上的預覽，沒有進入匯入。 |
| 檔案（`file_picker`） | **無損** | `FileType.custom` + 副檔名清單 → UIDocumentPicker，檔案直接複製，沒有 `compressionQuality`（壓縮只存在於 `FileType.image`／`media` 的相簿選擇模式，這裡沒用）。 |
| 相機（`image_picker`） | **近乎無損** | 只呼叫 `pickImage(source: camera, requestFullMetadata: false)`，**沒有**傳 `imageQuality`／`maxWidth`／`maxHeight`。image_picker_ios 對相機的 `UIImage` 以 `UIImageJPEGRepresentation(image, 1)` 編成 JPEG（沒有 `imageQuality` 時品質 1.0）；相機是即時取得像素，沒有「原始檔」，這已經是最高品質。 |
| `ImageStore.import`（所有路徑最後都走這裡） | **無損** | 圖片／GIF 以 `readAsBytes` → `writeAsBytes` 原樣寫入，影片以串流複製；副檔名沿用來源（`.heic` 保留）。解碼（`ImageDescriptor.encoded`）只為了讀寬高，結果不寫回檔案。 |
| 縮圖（`thumbs/`、`ThumbnailMaker`） | 有損但**只是額外產物** | 長邊縮小＋JPEG 品質 80，寫到另一個檔案，不覆蓋原圖，也不取代原圖。 |

要注意的兩點（行為，不是 bug，但請知悉）：

1. **編輯過的照片**：`originFile` 是 `PHAssetResource` 的「原始」資源，在 iOS 上對在「照片」App 裡裁切／調整過的照片，
   拿到的是**編輯前的原始檔**。若要的是編輯後的版本，用拖放或分享（來源會給目前版本）。這是依套件原始碼推斷，真機請驗證（見清單 D）。
2. **`originFile` 失敗時的後備** `e.file`：iOS 的 `file`（非 origin）走 `fetchFullSizeImageFile`，可能是系統輸出的（甚至轉成 JPEG 的）版本。
   只有 `originFile` 失敗（例如 iCloud 下載失敗）才會用到；之後若要「寧可失敗也不要有損」，可以拿掉 `?? e.file`（需要先問 Molly）。

另外，Android 的相簿選擇器、分享、貼上沒有改動；Android 的 HEIC 預覽依系統版本（API 28 以前無法解碼）。

## 真機測試清單

### 準備：一張已知位元組的 20 MB HEIC

1. 在 Mac 上準備一張約 20 MB 的 HEIC（iPhone 拍的 48MP ProRAW 不算；用 48MP HEIC 或把大圖用「預覽程式」匯出成 HEIC 品質最高）。
   記下雜湊：
   ```
   shasum -a 256 ~/Desktop/test20.heic
   ls -l ~/Desktop/test20.heic
   ```
2. 傳到 iPad 的「檔案」App：AirDrop 給 iPad →「儲存到檔案」→「在我的 iPad 上」→ 資料夾 `ImportTest`。
   （AirDrop 檔案不會被改動；這張就是之後所有路徑要比對的基準。）
3. 同一張也放進「照片」：在 Mac 的「照片」App 匯入，或用 AirDrop 傳給 iPad 並選「儲存到照片」。
4. 安裝含這次修改的 IPA（`Build iOS IPA (unsigned)`），用 Sideloadly 簽名安裝。**不要**勾選移除 app extensions。

### 取出畫匣裡的檔案來比對

匯入後，畫匣把原檔存在 App 容器的 `Documents/images/<uuid>.heic`（`ImageStore.dir`；實際資料夾以程式為準）。取法：

- **有 Xcode 的 Mac（較準）**：iPad 接 Mac → Xcode → Window → Devices and Simulators → 選 iPad → Installed Apps →
  畫匣 → ⋯ → Download Container… → 在輸出的 `.xcappdata` 上按右鍵「顯示套件內容」→ `AppData/Documents/images/`
  （或 `Library/Application Support/…`，找副檔名 `.heic` 的檔案）。免費 Apple ID 側載的 App 是開發簽名，
  通常可以下載容器；若灰掉就用下一個方法。
  ```
  shasum -a 256 ~/Desktop/Drawer.xcappdata/AppData/Documents/images/*.heic
  cmp ~/Desktop/test20.heic ~/Desktop/Drawer.xcappdata/AppData/Documents/images/<檔名>.heic && echo 一致
  ```
- **沒有 Xcode（間接）**：在畫匣把該張下載（存到「照片」`Pictures/Drawer`），再從照片 AirDrop 到 Mac
  （選項→「所有照片資料」），確認是 `.heic`、大小與步驟 1 的一致；再算 `shasum`。這一步多經過「存進照片」，
  若雜湊不同要懷疑是下載那一步而不是匯入。

### A. 分享擴充

1. 「檔案」App 選 `test20.heic` → 分享 → 畫匣。預期：「加入到」sheet 跳出，預覽圖正常（預覽失敗會是灰底，檔案仍在）。
2. 確認加入後，取出檔案，**雜湊必須與基準相同**，副檔名 `.heic`。
3. 從「照片」選同一張 → 分享。分享面板左上「選項」：
   - 選「最相容」→ 預期收到 JPEG（照片 App 先轉檔，不是畫匣的問題）；
   - 選「自動」或「原始」（只要能保留 HEIC 的選項）→ 預期收到 HEIC，雜湊與「照片」匯出的未編輯原檔（Mac「照片」→ 檔案 → 輸出 → 輸出未修改的原件）相同。
4. 容量上限：「照片」一次選 5 張各約 20 MB（共 100 MB）→ 分享 → 畫匣。預期：擴充畫面寫「已加入 3 張，其餘 2 張因 iOS 擴充容量限制未加入，請改用拖放或 App 內選圖。」
   並停在畫面等待，按「打開畫匣」才跳過去；sheet 裡是 3 張。**回報：擴充有沒有被系統砍掉（崩潰／畫面直接消失）**。
   若穩定，可試把 `totalBudget` 調高（例如 80 MB）再測；若有崩潰則維持或調低。
5. 張數：選 40 張小圖（各 < 1 MB）→ 分享。預期：全部 40 張都加入（不再有 30 張上限）。
6. 單張超過上限：一張 80 MB 的 PNG／HEIC → 預期擴充畫面寫「1 張圖片因 iOS 擴充容量限制未能加入…」，沒有任何東西被加入。
7. 動畫 GIF／WebP（從 Safari 長按圖片分享）→ 匯入後在畫匣仍會動。
8. Console.app（連 iPad）搜尋 `ShareExtension`，確認沒有 memory 相關的終止紀錄。

### B. 貼上

1. 「檔案」App 長按 `test20.heic` → 拷貝。到畫匣 → 加圖來源 →「貼上」→ iOS 跳「允許貼上」→ 允許。
   預期：1 張加入；取出檔案，雜湊相同、副檔名 `.heic`（**以前會是變大的 PNG**）。
2. 「照片」長按照片 →「拷貝」→ 貼上：取出檔案，看副檔名（預期 `.heic`）；與「照片」匯出的原檔比對雜湊。
3. Safari 長按 JPEG 網頁圖 → 拷貝 → 貼上：預期 `.jpg`，雜湊與網站原檔（`curl -o` 下載）相同。
4. 動畫 GIF 拷貝 → 貼上：預期 `.gif`，仍會動。
5. 剪貼簿是文字時按「貼上」：預期沒有圖可貼（不當機、不匯入東西）。
6. 打開「加圖來源」選單時**不應**跳出「允許貼上」提示（只有按下「貼上」才跳）。

### C. 分屏拖放

1. iPad 開 Split View：左「照片」或「檔案」，右畫匣（進到官方圖冊列表頁）。
2. 從「檔案」把 `test20.heic` 拖到畫匣：進入時出現虛線接收區與張數；放開後選分組；取出檔案，**雜湊相同、副檔名 `.heic`**。
3. 從「照片」拖 1 張、再多選 10 張拖：全部加入；影片也能拖（`.mov`／`.mp4`，位元組一致）。
4. 拖到 iCloud 尚未下載的照片：預期底部「正在載入 n／N 張」膠囊持續到下載完，之後正常加入；中途不當機。
5. 拖曳中移出視窗：提示條消失；拖到沒有 DropZone 的頁面：不加入、不當機。
6. 檢查暫存：`Caches/drop_import/` 的檔案在下一次放開後（或 2 小時後）被清掉（Xcode 下載容器查看）。

### D. App 內選圖（確認無損）

1. 加圖來源 →「相簿」（自家選擇器）選 `test20.heic` 那張：取出檔案，雜湊應與「照片」匯出的未編輯原檔相同，副檔名 `.heic`。
2. 選一張**在照片 App 裡裁切過**的照片：看匯入的是裁切後還是原始（預期是原始，見上面第 1 點注意事項）。把結果告訴我，
   若 Molly 要的是編輯後的版本，需要另外處理（要先決定）。
3. 加圖來源 →「檔案」選 `test20.heic`：雜湊相同。

### 通過標準

- 步驟 A2、A3（原始選項）、B1、C2、D1、D3 的雜湊全部與基準一致。
- A4 沒有崩潰、說明文字正確。
- 沒有任何一條路徑出現「靜默少圖」：少的圖一定有提示（擴充畫面或「n 張無法載入」）。

## Molly 要手動做的事

1. 等 GitHub Actions 的 iOS 建置成功（Swift 只在 CI 編譯；若失敗把 log 給我）。
2. 用 Sideloadly 重裝（**不要**勾移除 app extensions），照上面清單在真機測試，回報 A4（擴充是否被砍、64 MB 上限要不要調）
   與 D2（編輯過的照片要原始還是編輯後）。
3. 決定：相機是否需要改成 HEIC 原始輸出（目前是 JPEG 品質 1.0，要改得換相機實作，設計稿沒畫，所以先不動）。
