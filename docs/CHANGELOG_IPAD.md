# iPad 設計變更紀錄

> 給程程：
> - iPad 設計稿在另一個 canvas：https://claude.ai/code/artifact/e6351ef4-61b5-4dd3-be6b-78c5a2c7358c（讀 `project/<名稱>.dc.html`）。手機版仍以 `docs/CHANGELOG.md`（`D-xxx`）為準，兩份各自編號。
> - 每一條改動都有編號（`P-001`…），**按編號追蹤，不按日期**。批次只是方便分組。
> - 開工先找**還沒有 ✅ 的編號**，由小到大做。
> - 動手前重新讀該條列出的 artboard `.dc.html`，以 canvas 現況為準。
> - 做完在該條末尾加 `✅ commit xxxxxxx`；只做了一部分就寫 `🟡 未完成：…`。
> - 標了 **〔試稿〕** 的是 Molly 還在考慮的設計，**不要實作**；標了 **〔待確認〕** 的要先問 Molly。
> - 批次 1、2 已附上 git log 裡看起來對應的 commit，是由 Claude 依 commit 訊息比對的，**請逐條核對一次**：做齊了就保留 ✅，有缺漏改成 🟡 並寫明缺什麼。

---

## 批次 4（2026-10-23，對應手機 D-088、D-100～D-109）
canvas 最底「10/23 更新」五行是這次的新稿；其他改動直接改在原 artboard 上。

- **P-027** **主頁：拿掉田字／瀑布切換，改成「現坑｜淺坑｜封存坑」＋右上搜尋鍵**（D-088、D-105）。現坑固定田字。搜尋鍵 44px、白底圓角方塊，三個分頁都有，深色同樣。
  - 淺坑、封存坑在寬版用**兩欄卡片列表**：64px 封面（沒封面＝坑名第一個字）＋坑名＋一行副標＋右箭頭；淺坑最後一格「開新淺坑」（虛線）。
  - Artboard：`Main`、`MainPortrait`、`MainDark`、`MainSyncing`、`SyncPopover`、`SyncPopoverDark`（改）、`MainShallow`、`MainArchived`（新）。
- **P-028** **搜尋全部坑**（D-105）：sidebar 保留，右邊整區做搜尋頁；頂部寬輸入框＋右邊「取消」（回主頁）。
  - 未輸入：常用 tag 按坑分組，每坑一張白卡（色塊＋坑名＋tag chips＋次數），**兩欄瀑布**；封存坑排最後並加「封存」小標。
  - 輸入後：先列符合的 tag（chip 右邊坑名小標）；再按坑分組：標題列（色塊＋坑名＋筆數＋›，點＝進該坑坑內搜尋）、圖片一排 **6 格**（第 6 格「+N」）、腦洞文字卡兩欄。
  - Artboard：`GlobalSearch`、`GlobalSearchResult`。
- **P-029** **坑內搜尋**（D-107、D-108）：icon rail＋返回＋寬輸入框。
  - `PitSearch`：相冊 pills（全部、成圖、官方圖、同人圖、推活、摸魚、腦洞）＋常用 tag＋「未加 tag」卡（寬 420）。
  - 結果頁在寬版把相冊 pills 改成**左邊 210 寬的直排相冊清單**（只列有結果的，帶數字，選中＝深色底），右邊是分段：圖片一排 6 格＋「+N」、腦洞文字卡兩欄。選某相冊＝右邊變 6 欄九宮格（間距 2px）。
  - 「未加 tag」：搜尋列是灰色 chip「未加 tag ×」；長按進多選，右下工具列「× 已選 N 項｜全選｜加 tag」，補完 tag 的項目即時消失。
  - 入口：坑內頁、各分區標題列的搜尋鍵、預覽面板的 tag（點 tag＝`PitSearchResult`）。
  - Artboard：`PitSearch`、`PitSearchResult`、`PitSearchResultTab`、`PitSearchUntagged`（新）；`Pit`、`PitPortrait`、`FanArt`、`Ideas`、`Drafts`（搜尋鍵改連結）。
- **P-030** **推活對齊手機 D-065、D-078**：右邊面板**拿掉搜尋框和「角色 tag」篩選**（只留分組、跳到月份）；標題列加搜尋鍵（→ 坑內搜尋）；第二種版面改成九宮格（6 欄、間距 2px、無圓角、無文字），切換 icon 改 3×3。Artboard：`Oshi`。
- **P-031** **我的 → 個人化**（D-106）：左欄只剩 素材庫、個人化、備份與同步、關於 App。右欄「個人化」列出 主題色、App 圖示、語言、敏感內容四行；點進去時右欄換成該頁，頂部有「‹ 個人化」返回，左欄仍亮「個人化」。主題色順序改回 玫瑰、霧藍、珊瑚、抹茶（舊稿寫成「橄欖」）。Artboard：`Profile`。
- **P-032** **敏感內容設定頁**（D-104 ①②）：放在右欄，敏感內容標記開關＋（開了才出現）安全模式。關總開關彈置中確認框。Artboard：`ProfileSensitive`。
- **P-033** **備份與同步：儲存空間卡＋Drive 已滿**（D-101、D-103），放在 Google Drive 卡下面；滿了＝紅框、「12 張未上傳」＋「管理 Google 儲存空間 ↗」，自動同步小字變紅「上傳暫停　下載正常」，左欄副標變「Drive 已滿」。Artboard：`ProfileBackup`、`BackupFull`。
- **P-034** **iPad 同步 popover 的三種結束狀態**（D-100、D-103、D-109 ①③）：
  - 完成：綠勾＋「同步完成」＋全滿綠條＋上傳／下載張數＋相對時間＋「完成」鍵；不自動關。頭像同步圈消失。
  - 有失敗：琥珀「!」＋「同步完成，N 張失敗」、綠＋琥珀進度條、列出失敗項（縮圖、標籤、位置、「失敗」），底部「重試｜完成」。頭像右下琥珀小點。
  - Drive 已滿：未上傳的行顯示灰字「等待空間」；頭像右下紅點。
  - Artboard：`SyncPopoverDone`、`SyncPopoverPartial`、`SyncPopoverFull`。
- **P-035** **開新坑／編輯坑加類型**（D-088、D-104 ③）：
  - 開新坑頂部「類型：坑｜淺坑」。選淺坑時 form sheet 變兩欄（闊 880）：左＝封面（可選）、坑名、描述；右＝開啟的格子（7 個開關，預設只開官方圖冊、好看同人圖）。拿掉坑名的 placeholder（D-075）。
  - 編輯坑右欄頂部「類型：坑｜淺坑｜封存」；坑／封存＝「雜物」＋「敏感內容」兩個開關；淺坑＝開啟的格子 7 個＋敏感內容。右欄可捲動。「從相簿上載」改為「從相簿選擇」。
  - 「敏感內容」開關只在總開關開了才出現；關掉有內容的格子的確認框沿用手機 `PitEditShallowOff`。
  - Artboard：`NewPit`、`NewPitShallow`、`PitEdit`、`PitEditShallow`、`NewPit400`（加類型）。
- **P-036** **敏感內容在 iPad 的顯示**（D-104）：
  - 列表＋預覽並排時：**左邊列表照安全模式模糊**（縮圖 blur＋中間 34px 眼睛斜線圓）或加左上 22px 小標；**右邊預覽面板一律正常顯示**。
  - 多選時預覽面板收起、列表變 4 欄；底部動作列「下載、敏感、移動、tag、刪除」。
  - form sheet 的圖片格下面一行「全部標為敏感　1 / 2　開關」；已標記的小圖左下角敏感小標，不模糊。
  - Artboard：`FanArtSensitive`（安全模式開）、`FanArtSensitiveOff`（關）、`FanArtSelect`、`NewOfficialSensitive`。其他列表、表單照同一規則。
- **P-037** 沿用手機、iPad 不另畫：容量卡離線處理、表單內圖片預覽（D-102）、確認框、`R18Settings` 的文字（D-109 ④⑤）。深色版照 P-022 的 token 轉換。

---

## 批次 3（2026-10-19，加圖 sheet 改版＋iPad 深色模式）

- **P-021** **加圖來源：窄視窗（＜600）改用新版底部 sheet**（取代 P-019 裡 `MediaMenu400` 的舊版「浮起清單＋獨立取消鍵」，commit 0efa766 那一版要改掉）。 ✅ commit c482697
  - sheet **貼齊螢幕底部**，頂部圓角 24，不再浮在半空；底下蓋一層半透明黑。
  - 頂部一條小橫杆（36×5）＋左邊標題「加圖」（明體 18/700）＋右邊 32px 圓形 ×。**沒有獨立的「取消」按鈕**；關閉＝撳 ×、往下拉、撳外面暗位。
  - 來源改為**一排四格**（`repeat(4, 1fr)`、間距 10）：照片、檔案、素材庫、拍照。每格高 88、圓角 18、1px 邊框，同一種卡面底色；只有 icon 有顏色，文字 13/600。**不要再用每格不同的 pastel 底色**。
  - 四格下面一行說明（12px、次要字色）：「照片可多選，並保留選取順序；檔案支援 CSP 匯出的 PNG／JPG。」
  - **剪貼簿一行**：卡面底，左邊 44px 縮圖（剪貼簿那張圖），中間「剪貼簿有 1 張圖」＋「剛剛複製的圖片」，右邊膠囊按鈕「貼上」（soft 底＋strong 字）。**剪貼簿沒有圖片時整行不出現**。
  - ≥600 的 popover（`MediaMenu`）不變。
  - Artboard：`MediaMenu400`（淺色）、`MediaMenu400Dark`（深色）。
- **P-022** **iPad 先有的元件全部補上深色模式**。顏色一律用手機版 `ColorSystem` 的深色 token，不要自己調： ✅ commit c482697
  - 底 `#1B1816`、sidebar／icon rail／導覽底 `#211D1A`、卡片 `#26221F`、邊框 `#3A332D`／`#35302B`、chip 底 `#332D28`、主要字 `#F2ECE4`、次要字 `#B3A99C`、淡字 `#8C8378`、虛線 `#5A5047`。
  - accent／strong／soft 跟主題色走深色那組（例如珊瑚：`#E27560`／`#E8876F`／`#3D2A24`）。選中的 sidebar 項目、頭像底用 soft。
  - 分類色塊（坑封面佔位、縮圖佔位）用深色版：`#2B323A`、`#3A2C30`、`#383126`、`#2C3529`、`#312C3A`、`#3A3128`、`#2A3238`。
  - icon 底色一律用 soft 色系（深色版），**不要用淺色 pastel**（實裝的窄視窗加圖選單在深色模式有幾格是淺色底，非常刺眼）。
  - 同步藍：環 `#7F9DBB`、軌道 `#2E3A46`、文字 `#93AECB`。
  - 「現坑／封存坑」這類選中膠囊：選中＝米白底 `#F2ECE4`＋深字 `#1B1816`（同手機版 `MainDark`）。
  - **例外**：系統元件跟系統走。分屏拖放左邊的「照片」App、系統相片選擇器畫的是 iOS 系統深色（`#1C1C1E` 等），只是示意，不用自己做。
  - 參考圖檢視本來就是深色，不用改。
  - 需要逐一確認的元件：sidebar（260）、icon rail（84）、坑內分區 tab bar、列表＋詳情並排、form sheet（所有新增頁）、加圖 popover、同步頭像環＋popover、影片／GIF 預覽面板、拖放接收區（`rgba(61,42,36,.78)` 底＋accent 虛線框）。
  - Artboard：`MainDark`、`IdeasDark`、`SyncPopoverDark`、`MediaMenuDark`、`NewDraftDark`、`MediaDropDark`、`MediaVideoDark`、`MediaPickerDark`、`MediaMenu400Dark`。規則也寫在 `RespSpec` 底部。
- **P-023** **iOS App 圖示補深色／tinted 版本**（iOS 18 起桌面可以選深色或單色圖示）。目前 `AppIcon.appiconset`、`IconHuati.appiconset` 只有一般版本。 ✅ 2026-10-19 圖示已覆蓋（真機驗證待確認）
  - 用 Molly 給的 `appicon-ios.zip`（2026-10-19 版）：先刪掉兩個 appiconset 裡舊的 `Icon-App-*.png`，再把 zip 的 png＋`Contents.json` 覆蓋進去。每套有 `{key}-1024.png`（白底、無 alpha）、`{key}-dark-1024.png`（透明底前景）、`{key}-tinted-1024.png`（單色），`Contents.json` 已寫好 `luminosity` appearances，只用單一 1024 尺寸（Xcode 會自動縮）。
  - zip 內的 set 名稱已對齊專案（`AppIcon`、`IconHuati`），Build Settings 和 Swift 切換程式都不用改。
  - 驗證：iPad 長按桌面 → 編輯 → 自訂 → 深色／著色，兩款圖示都要正常顯示。
- **P-024** **相簿／相機權限說明文字加英文、日文**（目前 `Info.plist` 只有中文）。新增 `ios/Runner/en.lproj/InfoPlist.strings`、`ja.lproj/InfoPlist.strings`、`zh-Hant.lproj/InfoPlist.strings`，並在 Xcode 專案加入這幾個 localization：
  - `NSPhotoLibraryUsageDescription`：繁中沿用現有字句；英「Drawer needs access to your photo library to add images and videos to your collection.」；日「画匣は写真ライブラリにアクセスして、画像や動画を追加します。」
  - `NSPhotoLibraryAddUsageDescription`：英「Drawer saves downloaded images and videos to your photo library.」；日「ダウンロードした画像や動画を写真ライブラリに保存します。」
  - `NSCameraUsageDescription`：英「Drawer uses the camera to take photos for your collection.」；日「カメラで撮影した写真を画匣に追加します。」
- **P-025** 〔待確認〕 **iPad 選圖用自家選擇器還是系統 PHPicker**。設計稿 `MediaPicker` 畫的是系統 PHPicker（不需要讀整個相簿的權限）；目前實裝是手機版的自家選擇器（D-084，`photo_manager`），按 `MediaPicker` 的尺寸排版（commit 682376b）。**先不要改**，等 Molly 決定；若改用 PHPicker，`NSPhotoLibraryUsageDescription` 可以拿掉。
- **P-026** 〔待評估〕 **iOS 背景同步**：「先開始使用／同步會在背景繼續」在 iOS 要靠 background `URLSession`（App 切到背景後系統代為上傳下載）才成立；目前同步只在前台跑（commit 8ff826b 已處理分屏 inactive）。先評估 Flutter 端可行做法（如 `background_downloader`），回報後再決定要不要做。

---

## 批次 2（2026-10-18，雲端同步＋窄視窗彈出頁）

- **P-017** **雲端同步流程 iPad 版**：連結 Google、首次同步、主頁頭像進度環（會動）、同步進度 popover、備份與同步設定、取消連結確認。 ✅ commit 2314c3a de11a37 fadd18b 8ff826b
  - ≥600：撳頭像出 popover（`SyncPopover`）；＜600：底部 sheet（`SyncSheet400`）。
  - 頭像環、封面角標的環、進度條都有動畫；系統開了「減少動態效果」就全部停。
  - 同步中的坑：sidebar 那行右邊換成小轉圈，封面角標＝進度環（傳輸中）或轉圈（排隊中）。
  - 「我的 › 備份與同步」：自動同步開關、前台刷新間隔分段（1／5／15／30 分鐘）、立即同步＋更換帳號並排、取消連結（紅字，彈置中 alert）。
  - Artboard：`Connect`、`SyncFirst`、`MainSyncing`、`SyncPopover`、`Profile`（備份與同步）、`BackupUnlink`、`SyncSheet400`、`BackupUnlink400`。
- **P-018** **開頭頁「用 Google 帳號開始」改去 `Connect`**（不是直接進主頁）；`Connect`「連結並開始」→ `SyncFirst`；「先開始使用」→ 主頁同步中。 ✅ commit fadd18b
- **P-019** **窄視窗（＜600）彈出頁 400 版**：iPad 分屏約 400 寬時，彈出頁怎樣轉，見 `RespSpec`「彈出頁」表。 ✅ commit 90320af 0efa766 2314c3a（`MediaMenu400` 由 P-021 取代）
  - 8 個新增頁：全闊 page sheet，頂部留 12 露出底層，單欄可捲動，主按鈕縮短做「建立」／「加入」。
  - 分享 · 加入到：位置一行 4 格，作者／出處上下排。
  - 相片選擇器：全闊、4 欄。
  - 彈出中拉窗跨過 600 要即時轉樣式，已填的內容和捲動位置不能丟。
  - Artboard：`NewPit400`、`NewOfficial400`、`NewFanArt400`、`NewIdea400`、`NewDraft400`、`NewPiece400`、`NewOshi400`、`NewGoal400`、`MediaPicker400`、`ShareImport400`、`SyncSheet400`、`BackupUnlink400`。
- **P-020** **介面文字全部書面語**：`MediaMenu`、`NewPit`、`NewPiece`、`NewOfficial`、`MediaDrop`、`NewIdea` 的說明字已改成書面語（例如「影相」→「拍照」）。請以 artboard 為準核對 ARB。 ✅ 請核對

---

## 批次 1（2026-10-17，iPad 版面）

- **P-001** **自適應導覽**：Expanded 以上主頁／坑頁用 260 sidebar，分區內用 84 icon rail；Medium 用 icon rail；Compact 用手機版底部 tab。 ✅ commit 9c28cea
- **P-002** **主頁、坑內頁、編輯坑、開新坑**（橫向＋直向）。 ✅ commit 6da4e29
  - Artboard：`Main`、`MainPortrait`、`Pit`、`PitPortrait`、`PitEdit`、`NewPit`。
- **P-003** **坑內分區頂部 tab bar**（≥600），順序：官方圖冊 · 好看同人圖 · 我的腦洞 · 我的摸魚 · 我的成圖 · 推活。 ✅ commit ee6610e
- **P-004** **各分區列表＋預覽／詳情並排**：好看同人圖、官方圖冊（右邊預覽面板）、我的腦洞、我的摸魚、我的成圖（列表＋詳情）、推活（時間軸＋篩選面板）。 ✅ commit dbdb057 3364bab 70ccaeb
  - Artboard：`FanArt`、`Official`、`Ideas`、`Drafts`、`Finished`、`Oshi`。
- **P-005** **目標、我的設定並排版面**；「我的 › App 圖示」選圖示。 ✅ commit e3251eb
  - Artboard：`Goal`、`Profile`。
- **P-006** **開頭頁寬版**（左邊瀑布裝飾、右邊 icon＋按鈕）。 ✅ commit 9c28cea
  - Artboard：`Welcome`。
- **P-007** **參考圖檢視**：分屏（繪圖 App 在左）、全螢幕、窄視窗 400／900 版；縮放位置跟住圖片存，拉窗不重設。 ✅ commit eee7547 c172dc7 e50b022
  - Artboard：`RefSplit`、`RefFull`、`RespRef400`、`RespRef900`。
- **P-008** **參考圖檢視 · 影片**：逐格、慢放（0.25×–2×）、循環、「截取此格」。 ✅ commit eee7547
  - Artboard：`RefVideo`。
- **P-009** **Responsive 規則**：Compact＜600、Medium 600–839、Expanded 840–1199、Large ≥1200；網格欄數＝`max(2, floor(可用闊 ÷ 180))`；用 `LayoutBuilder` 讀窗闊。 ✅ commit bc0fb33（測試）
  - Artboard：`RespSpec`、`RespFan400`、`RespFan700`、`RespFan1000`、`RespFan1366`。
- **P-010** **8 個新增頁 ≥600 改為置中 form sheet**（可兩欄），背景 `#8C8580`。 ✅ commit ee6610e 90320af cc3727b
  - Artboard：`NewPit`、`NewOfficial`、`NewFanArt`、`NewIdea`、`NewDraft`、`NewPiece`、`NewOshi`、`NewGoal`。
- **P-011** **加圖來源選單**（≥600 popover，錨在「加圖」格旁邊）：照片、檔案、素材庫、拍照、貼上。 ✅ commit 5f4b3e3
  - Artboard：`MediaMenu`。
- **P-012** **相片選擇器 ≥600 置中、6 欄，保留選取順序**。 ✅ commit 682376b（選擇器種類見 P-025）
  - Artboard：`MediaPicker`。
- **P-013** **分屏拖放接收**：從「照片」或「檔案」拖圖進官方圖冊等列表，顯示虛線接收區「放開即可加入「官方圖冊」」＋張數；放開後選分組。 ✅ commit 5f4b3e3 eb454bb（請在實機確認拖放可用）
  - Artboard：`MediaDrop`。
- **P-014** **從其他 App 分享 · 加入到**（`ShareImport`）。 🟡 未完成：iPad 版畫面已做（commit ee6610e 0efa766）；iOS 的 Share Extension 需要 App Group，免費 Apple ID 做不到（見 `IOS_SETUP.md` 第五節），等 Molly 有付費開發者帳號再做
- **P-015** **影片／GIF 在 iPad 列表的標記＋預覽面板播放**（沿用 D-080 規則，預覽面板內有播放／暫停列）。 ✅ commit c172dc7（請核對面板內控制列）
  - Artboard：`MediaVideo`。
- **P-016** **iOS 換桌面圖示**：`setAlternateIconName`，切換後 iOS 會自己彈系統提示，**不要再加 toast**。 ✅ commit f3e85d6 767494c（深色／tinted 版本見 P-023）
