# 設計變更紀錄

> 給程程：
> - 每一條改動都有編號（`D-001`…），**按編號追蹤，不按日期**。批次只是方便分組。
> - 開工先找**還沒有 ✅ 的編號**，由小到大做。
> - 動手前重新讀該條列出的 artboard `.dc.html`，以 canvas 現況為準。
> - 做完在該條末尾加 `✅ commit xxxxxxx`；只做了一部分就寫 `🟡 未完成：…`。
> - 標了 **〔試稿〕** 的是 Molly 還在考慮的設計，**不要實作**，等她確認。

---

## 批次 5（2026-10-09，APK 第一次試用後）

- **D-052** 主頁同步狀態**收進左上角頭像**，取消頂部同步橫條（取代 D-028 的橫條部分），讓首頁打開時不會上下跳動：
  - **檢查中**（每次打開 App 比對雲端）：頭像外圈一段短弧在轉（不確定狀態），**不可點**。檢查完沒有東西要傳，外圈直接淡出，頁面完全不動。
  - **傳輸中**（有圖片要上傳或下載，包括首次匯入存檔在背景繼續時）：外圈變成**進度環**（底圈淺藍＋進度深藍 `#5B7A99`，按「已完成張數／總張數」）。這時頭像**可點**，打開「同步進度」bottom sheet。
  - **同步進度 sheet**：標題「同步中」＋「已完成 / 總數」＋總進度條；上傳張數、下載張數；下面逐張列出：縮圖、「上傳／下載」標籤、所在位置（坑 · 格）、各自的進度條與百分比；還沒開始的顯示「等待中」，太多就只列前幾張，最後寫「還有 N 張等待中」。傳完自動關閉。
  - **未下載完的圖片**：圖上蓋淡色（35%），右下角 32px 白色圓形角標＋下載箭頭＋進度環（有下載進度用確定值，排隊中用轉圈）。主頁封面與坑內所有圖片格都適用。
  - Artboard：`MainSyncing`（頭像進度環 37%；坑B 下載中 62%、坑D 排隊中）、`SyncSheet`。

- **D-053** 從其他 App 分享進來（例如相簿 App 選圖 → 分享 → 畫匣）：
  - Android 註冊為圖片的分享目標（`image/*`，單張／多張都收），收到後把圖片**複製**進 App 自己的儲存空間（不要只存外部 URI，原相簿刪了也不受影響）。
  - 打開「加入到」bottom sheet：上面是分享進來的圖片縮圖；**坑**（橫向 chips，最後一個「開新坑」）；**位置** 3×2 格：官方圖冊、好看同人圖、草稿、腦洞、成圖、雜物。選官方圖冊時下面展開該坑的分組 chips。
  - 按鈕：官方圖冊／好看同人圖／雜物 →「**加入**」，直接存好，回到原本的 App 前顯示「已加入」提示；草稿／腦洞／成圖 →「**下一步**」，打開該格的新增頁，圖片已預先放好。
  - 預設選上一次用過的坑和位置。
  - iPad 之後要另做 Share Extension，這次只做 Android。
  - Artboard：`ShareImport`（可點選切換）。
- **D-054** 多選「移動到」可以**跨坑**（擴充 D-044）：sheet 頂部加「坑」chips，預設是目前所在的坑；換了坑之後，官方圖冊的分組 chips 改為顯示目標坑的分組。
  - **tag 規則**：tag 按坑獨立，所以跨坑移動時，按名稱對應目標坑已有的 tag；目標坑沒有的，自動在目標坑新增同名 tag。
  - 其他各格獨有欄位的保留／隱藏規則同 D-044。
  - Artboard：`MoveSheet`。

- **D-055** 年度回顧排版：「正方格比例」改名為「**圖片比例**」（選項有 4:3、9:16 等，不一定是正方形）。Artboard：`ReviewEdit`、`ReviewEditBlank`。

- **D-056** 年度回顧：某個月份有**多於一張成圖**時，**長按**該月份格打開 bottom sheet「選擇 N 月的圖片」，列出該月所有成圖（3 欄、圖片圓角 12px、標題在下），選中的是 2px accent 外框＋右上 22px 勾，按「完成」套用。只有一張時長按沒有反應。還沒手動選過的月份，預設用該月**實際互動量最高**的成圖，一樣就用最新的。Artboard：`ReviewPick`。

---

## 批次 4（2026-10-08 晚，tag／移動／商稿）

### Tag 與搜尋
- **D-043** Tag 的顯示規則統一：
  - **列表頂的 chips 只放該格的固定分類**：官方圖冊＝分組，好看同人圖＝出處；草稿、腦洞、成圖不放 chips。成圖列表原本的 tag chips 拿掉。Artboard：`Finished`。
  - **圖片型**（同人圖、草稿、成圖）：列表卡片不顯示 tag；預覽／詳情頁才列出全部 tag。
  - **文字型**（腦洞）：tag 顯示在卡片底。
  - **任何地方的 tag 都可以點**：點了回到該格列表，頂部出現搜尋列＋「#tag ×」的篩選狀態。Artboard：`FanArtFiltered`（範本）。腦洞、草稿、成圖列表一樣：頂部換成同一條篩選列，下面沿用各自列表原本的卡片樣式，只顯示有該 tag 的項目；按「×」回到完整列表。
  - 好看同人圖、腦洞、草稿、成圖的列表右上角加搜尋 icon，進入**坑內搜尋**：輸入框＋分頁＋按使用次數排序的常用 tag；結果按分類分段（分頁順序、分段樣式以 **D-051** 為準）。Artboard：`PitSearch`、`PitSearchResult`、`FanArtList`、`IdeaList`、`Finished`（草稿列表與九宮格同樣加上）。 ✅ commit 076dd90 f968a1d 5ab836a b0921cc 9be9134
- **D-045** 新增**同人圖預覽**（與官方圖冊預覽分開）：作者、出處、tag（可點）、加入日期；底部動作與官方相同。好看同人圖的卡片改連到這頁。Artboard：`FanArtPreview`。 ✅ commit 9be9134

### 移動
- **D-044** 多選的「分組」改名為「**移動**」（取代 D-042）。bottom sheet「移動到」可選：官方圖冊／好看同人圖／雜物；選「官方圖冊」時展開分組 chips（同一格內換分組也在這裡做）。Artboard：`MoveSheet`、`OfficialSelect`、`JunkSelect`。
  - **資料規則**：各格獨有的欄位（官方的分組、同人圖的作者／出處、tag）在移動時**保留但隱藏**，移回原格會恢復，不會遺失。移入的格如果有欄位是空的，就保持空白（例如同人圖作者顯示為空），使用者可之後再編輯。 ✅ commit 076dd90 9be9134

### 成圖：公開發佈與商稿
- **D-046** 成圖不再預設一定公開。新增／編輯成圖改為兩個獨立開關：
  - **已公開發佈**：開啟才出現「發佈日期」「社交媒體連結」「目標互動量」（編輯頁另有「實際互動量」）。
  - **商稿**：開啟才出現「委託人」「金額（幣種＋數字）」「收款狀態」（⛔ 已由 D-050 改為「已收金額」）「交稿日期」。
  - 兩個都關＝私稿。兩個可以同時開。
  - 目標的「需要達成互動量」只計算有開「已公開發佈」的成圖。
  - Artboard：`PieceNew`、`PieceNewLink`、`PieceEdit`、`PieceNewCommission`。 ✅ commit 076dd90 b0921cc
- **D-047** 商稿收入（先做年度）：目標・年度加「商稿收入」卡片；點進去按幣種分開合計（**不做匯率換算**），未收齊的有紅色提示，下面按月份列出每張商稿與收款狀態。Artboard：`GoalYear`、`IncomeYear`。
  - 幣種每張商稿各自選，預設值放在設定（之後再畫）。 ✅ commit 076dd90 9dab47d

### 商稿收入：對齊與已收金額
- **D-049** 商稿收入頁的月份小計（灰字）左右內縮到跟下方卡片內容同一條線（卡片 padding 14px＋邊框 1px＝15px），右邊數字要上下對齊。Artboard：`IncomeYear`。 ✅ commit 9dab47d
- **D-050** 收款改為記**已收金額**（取代 D-046 的「收款狀態」三選一 chips）：
  - 商稿欄位：「金額」＋「已收金額」（同一幣種，不另選）；已收金額旁有「已收齊」按鈕：按下＝把已收金額填成全額，按鈕變實色（同 `.chip.on`）。按鈕狀態跟數字走：已收 ≥ 金額就是實色；手動把數字改小、或之後把金額改大，按鈕自動變回外框。實色時再按一次＝已收金額回到 0。
  - 狀態**自動推算**，不存：已收 = 0 → 未收；0 < 已收 < 金額 → 顯示「已收 ¥ 300」；已收 ≥ 金額 → 已收齊（多收也當已收齊）。
  - 收入頁：每幣種卡片顯示總額＋「已收 ¥ x · n 張」；紅色提示顯示「未收齊 n 張　尚欠 ¥ x」（尚欠＝金額 − 已收的合計）。
  - 分期多次收款不另做紀錄，收到一筆就把已收金額改大。取消／退款之後再說。
  - Artboard：`PieceNewCommission`、`PieceEdit`、`IncomeYear`。 ✅ commit 076dd90 b0921cc 9dab47d

### 坑內搜尋結果
- **D-051** 搜尋結果頁改版（調整 D-043）：
  - **分段順序**按完成度：成圖 → 好看同人圖 → 草稿 → 腦洞。分頁 chips 同一順序（全部／成圖／同人圖／草稿／腦洞），搜尋頁 `PitSearch` 也一樣。
  - 圖片類（成圖、同人圖、草稿）用草稿多圖卡的樣式：一排 3 格正方形、間距 4px、外框圓角 10px；超過 3 張時第 3 格蓋深色層，寫「+N」（N＝總數 − 3）。**段頭不放「全部」**：點「+N」那格就進該格列表並帶著同一個 tag 篩選；點其他格照常開預覽／詳情。
  - 腦洞放最後，**直向列出全部結果，往下捲動時分批載入**（lazy loading）。
  - Artboard：`PitSearchResult`、`PitSearch`。 ✅ commit 076dd90 f968a1d

### 待評估
- **D-048** 〔待評估〕圖片自由排序：多張圖（草稿、成圖、腦洞配圖）可以拖曳調整順序。程程先評估做法與難度，回報給 Molly，**先不要實作**。

---

## 批次 3（2026-10-08 晚，第二次 review）

- **D-034** 雜物正式加入（取代 D-012）：
  - 編輯坑加「雜物」開關；開啟後坑內頁最底才出現「雜物」入口。Artboard：`PitEdit`、`PitJunk`。
  - 雜物列表：3 欄純圖，有新增按鈕，有導覽列。Artboard：`JunkList`。
  - 長按多選：分享、下載、移動、刪除（「分組」已改為「移動」，見 D-044）。Artboard：`JunkSelect`。
  - 雜物不計入目標、不出現在時間軸、不能當封面。 ✅ commit 076dd90 9be9134 d7c6c27
- **D-035** 社交連結不用 bottom sheet（取代 D-021）。按「加社交連結」直接多一行輸入框。兩個版本二選一：
  - 做得到「按網址自動判斷平台」→ 左邊顯示平台簡寫 icon（`PieceNew`）。
  - 做不到 → 左邊一律用鎖鏈 icon（`PieceNewLink`）。
  - **程程自己判斷用哪個，回報時講明選了哪個。** ✅ commit b0921cc（採 PieceNew：依網址自動判斷平台 icon，未知網址用鎖鏈 icon）
- **D-036** 選擇封面拿掉說明小字。Artboard：`CoverPick`。 ✅ commit 9be9134
- **D-037** 詳情頁不能新增關聯：腦洞詳情拿掉「＋」格；沒有關聯成圖時整段不顯示。選擇草稿的 bottom sheet 改為從**編輯頁**打開。Artboard：`IdeaDetail`、`IdeaNew`、`DraftPick`。 ✅ commit 5ab836a
- **D-038** 時間軸 ＋（取代 D-026）：bottom sheet 只有腦洞／草稿／成圖三個選項，時間一律用「現在」，不能改。Artboard：`DayAddSheet`、`Day`。 ✅ commit 9dab47d
- **D-039** 年度回顧排版：預覽外加一圈無圓角白框，代表匯出圖片的留白；新增「月份對齊」選項（靠左／置中／靠右，圖上預設靠左、空白位置預設置中）。Artboard：`ReviewEdit`、`ReviewEditBlank`。 ✅ commit 076dd90 9dab47d
- **D-040** 語言：English 為停用狀態，右邊顯示「即將推出」；「跟隨系統」下面不加小字。Artboard：`LanguagePick`。 ✅ commit 5dff3ac
- **D-041** 取消連結只要一個確認視窗（取代 D-030）：說明後果＋「取消」「確認取消連結」。Artboard：`BackupUnlink`。 ✅ commit 5dff3ac
- **D-042** ⛔ 已作廢，見 D-044。~~官方圖冊多選按「分組」→ bottom sheet「移到分組」：單選分組、可新增分組、完成。Artboard：`OfficialGroupSheet`。~~

---

## 批次 2（2026-10-08 晚，Molly 第一次 review 後）

### 用詞與全局規則
- **D-001** 用詞「連接」全面改為「關聯」（只限腦洞／草稿／成圖之間的關係；網址與 Google 帳號仍用「連結」）。Artboard：`IdeaNew`、`IdeaDetail`、`DraftNew`、`PieceNew`、`PieceDetail`。 ✅ commit 5ab836a
- **D-002** 「草圖」統一為「草稿」。Artboard：`Day`。 ✅ commit 5ab836a
- **D-003** 「新增」與「選擇」分開：**新增**＝建立一個新的東西（新增 tag、新增圖片）；**選擇**＝從已有的項目挑（選擇腦洞、選擇草稿、選擇成圖、選擇坑）。Artboard：`IdeaNew`、`DraftNew`、`PieceNew`、`PieceEdit`、`GoalNew`。 ✅ commit 5ab836a
- **D-004** 坑的小 pill 不再放迷你封面方塊，改用導覽列同款的資料夾 icon。所有出現「坑」pill 的地方都要換。Artboard：`GoalYear`、`Month`、`GoalNew`、`TagManage`。 ✅ commit 9dab47d
- **D-005** 導覽列顯示規則：只有瀏覽用的頁面有；新增／編輯／詳情／預覽／多選／管理／設定頁一律沒有。清單見 HANDOFF 第 6 節。 ✅ commit 5dff3ac 9be9134 d7c6c27 5ab836a b0921cc 9dab47d f968a1d
- **D-006** 導覽列 icon 必須用設計稿的 SVG（坑＝資料夾、目標＝雙圓靶心、我的＝人像）。 ✅ commit d7c6c27
- **D-007** 下載存到獨立相簿 `Pictures/Drawer`，不要混入相機膠卷。 ✅ commit 9be9134 9dab47d
- **D-008** 所有介面文字移到 ARB 檔，不准寫死中文。 ✅ commit 611344d d3b1cb1 3281296 d4430ab 289bd34
- **D-009** 主題色四選一（珊瑚／霧藍／玫瑰／抹茶）的完整色值。Artboard：`ColorSystem`；色值表見 HANDOFF 第 7 節。 ✅ commit 5dff3ac

### 坑
- **D-010** 新增 artboard `PitEdit-ntnf`：編輯坑，坑內還沒有任何圖片（不能選封面）。 ✅ commit d7c6c27
- **D-011** 新增 artboard `PitEditNoCover`：坑內有圖但還沒設封面；封面位置是虛線正方框＋號，點了進 `CoverPick`。 ✅ commit d7c6c27
- **D-012** ⛔ 已作廢，見 D-034。~~〔試稿〕雜物：`PitJunk`（坑內頁最底的「雜物」入口）、`JunkList`（3 欄純圖）。**先不要做。**~~

### 官方圖冊
- **D-013** 移除預設分組「自定義」。Artboard：`OfficialList`、`OfficialNew`、`GroupManage`。 ✅ commit 9be9134
- **D-014** 多選底部加「分組」按鈕（下載／分組／刪除）。Artboard：`OfficialSelect`。 ✅ commit 9be9134

### 腦洞、草稿、tag
- **D-015** 選擇草稿的 bottom sheet：列出草稿，有標題顯示標題，沒標題顯示「無標題」，多選，底部「完成」。腦洞詳情的虛線＋格會打開它。Artboard：`DraftPick`、`IdeaDetail`。同一個樣式用於選擇腦洞、選擇成圖。 ✅ commit 5ab836a
- **D-016** 管理 tag：點「新增 tag」後，列表最底變成輸入框（前面固定 `#`），右邊「取消」「新增」。Artboard：`TagAdd`。 ✅ commit 5ab836a
- **D-017** 草稿詳情三種情況：完整（圖、標題、日期、內文、tag、關聯腦洞）、只有一張圖、只有多張圖（大圖右上角「1 / N」＋下方縮圖列）。右上角有編輯、刪除。Artboard：`DraftDetail`、`DraftDetailOne`、`DraftDetailMulti`。 ✅ commit 5ab836a
- **D-018** 所有表單已上傳的圖片右上角加「×」移除鍵。Artboard：`PieceNew`、`DraftNew`、`IdeaNew`、`OfficialNew`。 ✅ commit 9be9134 5ab836a b0921cc

### 成圖
- **D-019** 成圖詳情右上角加刪除（垃圾桶），與腦洞詳情一致；編輯按鈕打開 `PieceEdit`。Artboard：`PieceDetail`。 ✅ commit b0921cc
- **D-020** 編輯成圖頁：同新增成圖，但已填好資料、多一欄「實際互動量」、按鈕是「儲存」。Artboard：`PieceEdit`。 ✅ commit b0921cc
- **D-021** ⛔ 已作廢，見 D-035。~~加社交連結的 bottom sheet：貼上網址後**自動判斷平台**（x.com→X、xiaohongshu→小紅書、lofter、pixiv、weibo、instagram），判斷結果顯示為已選中的 chip，判斷錯可手動改，都不是就「其他」。Artboard：`LinkAddSheet`。~~

### 目標
- **D-022** 目標按**進度百分比**由高至低排列（倒序），100%（已達成）的沉到最底；年度、月度都一樣。Artboard：`GoalYear`、`Month`（兩張都有一個已達成的目標放在最底作示範）。 ✅ commit 076dd90 9dab47d
- **D-023** 新增目標「需要達成互動量」開啟後的樣子。Artboard：`GoalNewHot`。 ✅ commit 9dab47d
- **D-024** 年度回顧排版「空白位置」的樣子。Artboard：`ReviewEditBlank`。 ✅ commit 9dab47d
- **D-025** 年度目標空白頁的月份改用中文「1月」。Artboard：`GoalEmpty`。 ✅ commit 9dab47d
- **D-026** ⛔ 已作廢，見 D-038。~~時間軸右下 ＋：打開 bottom sheet，最上面是時間（預設此時此刻，可改），下面選腦洞／草稿／成圖，進入對應新增頁，建立時間用這裡選的時間。Artboard：`DayAddSheet`。~~

### 同步、我的
- **D-027** 首次連結後的同步中畫面（進度條＋「圖片 128 / 342」），可按「先開始使用」，同步在背景繼續。Artboard：`SyncFirst`。 ✅ commit 5dff3ac a00d831
- **D-028** ⛔ 橫條部分已由 D-052 取代。背景同步中的主頁：頂部橫條改為藍色「同步中・圖片 N / M」＋細進度條；還沒下載完的封面蓋一層淡色＋下載 icon。Artboard：`MainSyncing`。
- **D-029** 備份與同步：加「立即同步」（主按鈕）、保留「更換同步的 Google 帳號」、最底紅字「取消連結」。Artboard：`Backup`。 ✅ commit 5dff3ac
- **D-030** ⛔ 已作廢，見 D-041。~~取消連結必須兩次確認：第一次對話框說明後果；第二次要輸入「取消連結」四個字，按鈕才會亮。Artboard：`BackupUnlink1`、`BackupUnlink2`。~~
- **D-031** 我的：加「語言」一列（跟隨系統／繁體中文／English）。Artboard：`Profile`、`LanguagePick`。 ✅ commit 5dff3ac
- **D-032** 編輯個人資料：點頭像更換、暱稱、儲存。Artboard：`ProfileEdit`。 ✅ commit 5dff3ac
- **D-033** 關於 App：圖示、名稱、版本、資料存放說明、開源授權。Artboard：`About`。 ✅ commit 5dff3ac

---

## 批次 1（2026-10-07）

- **D-000** 初版交接（HANDOFF.md）。
