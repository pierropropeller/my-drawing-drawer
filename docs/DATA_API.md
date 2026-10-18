# 資料層 API 參考（schema v8；批次 6–8、批次 9 見檔案後段）

給 UI 工程師：這份只列「批次 3、4 資料層」新增／變更的公開 API。所有 query 都是 `AppDatabase` 的 extension，
用法與 `album_queries.dart`、`entity_queries.dart` 一致；對應的 Riverpod provider 在 `lib/state/providers.dart`。

命名提醒：drift 產生的 `EntityImage` 在 `entity_queries.dart` 是 `ImageRef`、`PieceLink` 是 `SocialLink`。

## 1. Schema v6 變更一覽

| 表 | 新欄位 |
|---|---|
| `Pits` | `junkEnabled` bool（預設 false） |
| `OfficialImages`、`FanArts` | `imageKey` text、`hidden` bool |
| `JunkImages`（新表） | `SyncColumns`、`pitId`、`imageFile`、`width`、`height`、`imageKey`、`hidden` |
| `Pieces` | `isPublished`、`publishedAt?`、`isCommission`、`client`、`amount?`、`currency`('CNY')、`receivedAmount`(0)、`dueAt?` |
| `ReviewSettings` | `monthAlign?`（'start'/'center'/'end'）、`updatedAt?`（同步用，由 `saveReviewSettings` 自動蓋） |

遷移（`database.dart` 的 `_migrateV6`）：從 v1~v5 都測過（`test/migration_test.dart`）。
`imageKey` 回填成自己的 `id`；既有成圖 `isPublished = true`、`publishedAt = finishedAt`；缺的表整張建立。

## 2. 雜物（D-034）與移動（D-044）— `junk_queries.dart`

```dart
enum AlbumCell { official, fan, junk }

Stream<List<JunkImage>> watchJunk(String pitId);          // 不含隱藏／已刪除，新到舊
Future<void> addJunk(String pitId, List<NewImage> images);
Future<void> deleteJunk(Iterable<String> ids);

Future<void> moveAlbumImages({
  required AlbumCell from,
  required List<String> ids,   // 都必須是 from 格、目前可見的列 id
  required AlbumCell to,
  String? groupId,             // 目標是官方＝官方分組 id；目標是同人圖＝出處分組 id（可 null）
});
```

坑：
- `createPit({name, description, bool junkEnabled = false})`（批次 14 起另有 `status`／`enabledSections`／`coverFile`，見「批次 14」）
- `updatePit(id, {name, description, archived, bool? junkEnabled})` — `junkEnabled` 不傳＝不變。（批次 14：`archived` 只是相容參數，新程式用 `status`，見「批次 14」）
- `PitStats.junk`：雜物數（**只有 `pit.junkEnabled` 時才顯示**）。**不計入** `PitStats.imageCount`。
- `deletePit` 會把坑內雜物一併軟刪除。

`moveAlbumImages` 語意：
- `from == to`：官方→官方／同人圖→同人圖只更新 `groupId`（沒給 `groupId` 就不做事）；雜物→雜物不做事。
- 不同格：目標格若有同 `imageKey` 的**隱藏列**就取消隱藏（恢復它原本的分組／作者／出處／tag；有給 `groupId` 時覆蓋分組），
  否則新建一列（保留 `createdAt`、檔名、寬高、`imageKey`）。來源列 `hidden = true`。
  - 新建官方列：`groupId ?? 該坑第一個官方分組`。
  - 新建同人圖列：`author = ''`、`groupId` = 傳入值（可 null）、沒有 tag。
  - 同人圖的 tag 留在隱藏的同人圖列上，移回時恢復。
- 封面：被移動的圖若是**坑封面**（`coverImageId`）→ 移到官方／同人圖時改指向新列，移到雜物時清成 null；
  若是官方／同人圖**格封面**（`officialCoverId`／`fanArtCoverId`）→ 一律清成 null。
- 刪除（`deleteOfficial`／`deleteFanArts`／`deleteJunk`）會連同同 `imageKey` 的隱藏分身一起軟刪除。
- 全部在 transaction 內；結果透過一般的 `watch*` 即時反映。

所有既有查詢都已排除 `hidden = true`：`watchOfficial`、`watchFanArts`、`watchPitStats`、`watchCellCovers`、
`watchCoverCandidates`、`imageFileOf`、`watchTagUsage`、`watchPitSearch`。雜物不出現在目標、時間軸、封面候選、搜尋。

新增圖片路徑一律設 `imageKey`（`addOfficial`、`addFanArts`、`addJunk`、移動、同步套用舊文件時補 `id`）。

## 3. 成圖欄位（D-046／D-050）— `entity_queries.dart`、`payment.dart`

`savePiece(...)` 新增的具名參數（**全部可省略**）：
`bool? isPublished, DateTime? publishedAt, bool? isCommission, String? client, double? amount, String? currency, double? receivedAmount, DateTime? dueAt`。

兩組欄位各自獨立寫入：
- 傳了 `isPublished`（非 null）→ 寫「公開」組：`isPublished`、`publishedAt`（公開且沒給日期時用 `finishedAt`）。
- 傳了 `isCommission`（非 null）→ 寫「商稿」組：`isCommission`、`client`(trim)、`amount`、`currency`(空→'CNY')、`receivedAmount`(null→0)、`dueAt`。
- 沒傳的組：**編輯時保持原樣**；**新增時**用預設（未公開、非商稿、'CNY'、0）。
- 開關關閉時資料保留（社交連結、金額等都不清），由 UI 決定顯示與否。**表單請整組一起傳**（尤其編輯時要把整組當前值傳回去）。
- `savePiece` 的 `links` 仍是必填，行為不變。

其他：
- `setReceivedAmount(pieceId, double)`：只改已收金額（「已收齊」按鈕、收入頁快速收款）。
- `PieceView.payment` → `PaymentState`。

`payment.dart`（純函式，可直接單元測試）：
```dart
enum PaymentStatus { unpaid, partial, paid }
class PaymentState { PaymentStatus status; double received; bool isPaid/isPartial/isUnpaid; }
PaymentState paymentStateOf({double? amount, required double received});
double outstandingOf({double? amount, required double received});   // max(金額-已收, 0)
bool isFullyReceived({double? amount, required double received});    // 「已收齊」按鈕是否實色（已收 >= 金額 > 0）
```
規則：已收 ≤ 0 → unpaid；已收 ≥ 金額 → paid（多收也算）；其餘 partial。金額沒填（null/≤0）：沒收到錢＝unpaid，收到任何金額＝paid。

目標（D-046）：`requireLikes != null` 的成圖目標只計算 `isPublished` 的成圖；沒有 `requireLikes` 的成圖目標計算全部（含私稿、商稿）。

## 4. 商稿收入（D-047／D-049／D-050）— `income_queries.dart`

```dart
Stream<IncomeYear> watchIncome(int year);      // provider: incomeProvider(year)

class IncomeYear { int year; List<IncomeCurrency> currencies; List<IncomeMonth> months; bool isEmpty; }
class IncomeCurrency {   // 每幣種一張卡片，合計金額大的在前
  String currency; double total; double received; int count;
  double outstanding;    // Σ (金額 - 已收)，只算未收／部分收款的
  int unpaidCount;       // 未收齊張數（紅色提示「未收齊 n 張　尚欠 ¥ x」）
  bool hasOutstanding;
}
class IncomeMonth { int month; List<IncomeEntry> entries; Map<String,double> totals; }  // totals＝該月各幣種金額小計（灰字）
class IncomeEntry { Piece piece; ImageRef? cover; PaymentState payment; currency; amount; received; }
```
- **月份依成圖的「完成日期」`finishedAt` 歸屬**（`IncomeYear.dc.html` 沒指定；交稿日 `dueAt` 是預定日，不用它分月）。
  年度範圍也以 `finishedAt` 為準。
- 只含 `isCommission = true` 且未刪除的成圖。月份由 12 月到 1 月；月內新到舊。
- 沒填金額的商稿只出現在月份清單（`amount == null`），不計入卡片與小計。
- 不做匯率換算；預設幣種見設定 `defaultCurrency`。

## 5. Tag、篩選與坑內搜尋（D-043／D-051）— `album_queries.dart`、`entity_queries.dart`、`search_queries.dart`

- `watchTagUsage(pitId, {bool byUsage = false})`：`byUsage: true` 常用在前（同次數按名稱）。
  次數只算還存在的項目（已刪除、隱藏同人圖不算）。provider：`tagUsageByUsageProvider(pitId)`。
- 單一 tag 篩選（每格列表頂的「#tag ×」狀態）：
  - `watchFanArts(pitId, {groupId, tagId})` — provider `fanArtsFilteredProvider((pitId, groupId, tagId))`
  - `watchDraftViews(pitId, {tagId})` — provider `draftViewsFilteredProvider((pitId, tagId))`
  - `watchIdeaViews(pitId, {tagId})`、`watchPieceViews(pitId, {tagId})`（原本就有）
- `watchPitSearch(pitId, {String text = '', String? tagId, int thumbLimit = 3})` — provider `pitSearchProvider((pitId, text, tagId))`：
```dart
class PitSearchResult { PitSearchGroup<PieceView> pieces; PitSearchGroup<FanArt> fanArts;
                        PitSearchGroup<DraftView> drafts; PitSearchGroup<IdeaView> ideas; int total; bool isEmpty; }
class PitSearchGroup<T> { int total; List<T> items; int more; }  // more = total - items.length，就是「+N」
```
  - 分段順序（也是分頁 chips 順序）：成圖 → 好看同人圖 → 草稿 → 腦洞；`total` 是各段數字，`PitSearchResult.total` 是「全部」。
  - 圖片類 `items` 只含前 `thumbLimit`(3) 筆（新到舊）；腦洞 `items` 是**全部**（UI 自己做 lazy loading）。
  - `text` 以空白分詞，**每個詞**都要命中其中一個欄位（不分大小寫）：成圖／草稿／腦洞＝標題、內文、tag 名稱；同人圖＝作者、tag 名稱。
    `tagId` 要求有該 tag。兩者都沒給 → 空結果。隱藏同人圖、雜物不會出現。
  - 「+N」那格要進該格列表帶同一個 tag 篩選：用上面的 `tagId` 篩選 provider。

## 6. 年度回顧月份對齊（D-039）與目標排序（D-022）— `goal_queries.dart`

- `ReviewSetting.monthAlign`：'start'|'center'|'end'|null。`saveReviewSettings(ReviewSetting)` 會自動蓋 `updatedAt`；
  `s.copyWith(monthAlign: const Value('end'))`（清除用 `Value(null)`）。
- `ReviewSetting.effectiveMonthAlign`（extension getter）：null 時回傳 月份在圖上＝'start'、在空白位置＝'center'。
- `sortGoalsByProgress(Iterable<GoalView>) → List<GoalView>`：進度百分比高到低，已達成（done）沉底，同比例保持原順序。
  `watchGoalViews`（年度、月度共用）已套用，`goalViewsProvider` 拿到的就是排好的。

## 7. 同步（D-027／D-028）與設定

`SyncEngine.sync({SyncProgressListener? onProgress})`：
```dart
enum SyncStage { pulling, downloadingImages, uploading }
class SyncProgress { SyncStage stage; int imagesDone; int imagesTotal; }
```
- `pulling`：0/0；`downloadingImages`：total＝本機缺、遠端有的圖數量，每張處理完 done+1（下載失敗也算，下次再試）；
  `uploading`：total＝這次要上傳的、遠端還沒有的圖數量。

`SyncState`（`syncControllerProvider`）新增：
`stage`、`imagesDone`、`imagesTotal`、`isFirstSync`、`needsAppUpdate`，以及 getters `isSyncing`、`hasImageProgress`（同步中且 total > 0）、`imageFraction`（0~1 或 null）。
- `isFirstSync`：正在進行（或剛失敗）的是**這個帳號**的首次同步。判斷依據是本機設定 `syncedAccount != accountEmail`；
  同步成功後 `setSyncedAccount` 記下帳號，所以換帳號（`switchAccount`）會再次是首次同步。
- `firstSyncPendingProvider`（`Provider<bool>`）：已連結帳號但尚未完成首次同步。
- `SyncController.startFirstSync()`：await 到同步結束。`startFirstSyncInBackground()`：立即返回。
  按「先開始使用」只要離開頁面即可——同步由 controller 繼續，狀態都在 `SyncState`，主頁橫條讀同一個 state。
  （`SyncDriver` 在連結帳號後本來就會自動觸發，`isFirstSync` 也會是 true。）
- 本機圖片是否已下載：`ImageStore.exists(file)`、`ImageStore.watchExists(file)`（`Stream<bool>`，下載完成時再送一次 true）、
  `ImageStore.changes`；Riverpod：`imageExistsProvider(file)`（`StreamProvider.family<bool, String>`）。
  封面還沒下載完 → 蓋淡色＋下載 icon。
- `ImageStore.save(name, bytes)`：同步下載寫檔用（會通知 `changes`）。

格式版本：
- `syncFormatVersion = 2`（`sync_engine.dart`）。每份文件新增 `formatVersion`（原 `v: 1` 保留）；遠端另有 `meta__app__format.json`。
- 遠端有更高版本（標記或任一文件）→ 同步丟 `SyncFormatException`（繼承 `SyncAuthException`），
  訊息「此備份由較新版本建立，請先更新 App」，`SyncState.phase == error`、`needsAppUpdate == true`，本機資料不動、不記為已同步。
- 向下相容：舊文件缺的欄位在 `sync_kinds.dart` 的 `withDefaults` 補預設（舊成圖視為已公開；`imageKey` 補 `id`）。
- 新增同步種類：`junk`（雜物）、`reviewsettings`（回顧排版，以前沒同步）。

本機設定（`settings.dart`，不同步）：`defaultCurrency`（預設 'CNY'，`setDefaultCurrency`）、`syncedAccount`（內部用）。

## 8. 刻意的行為改變（既有測試已更新）

- 目標列表順序改為進度百分比排序（D-022）。
- `requireLikes` 目標不再計入未公開的成圖（D-046）。
- `savePiece` 新增的成圖預設**未公開**（DB 預設 false）；舊 UI 沒傳 `isPublished` 時新成圖會是私稿。UI 改版時請明確傳。
- `watchTagUsage` 的次數不再計入已刪除項目、隱藏同人圖。

---

# 批次 5 資料層（D-052／D-054／D-056）

Schema 沒有變動（仍是 v6，不需 migration）。以下 API 全部有測試：`test/sync_transfer_test.dart`、
`test/cross_pit_move_test.dart`、`test/review_month_test.dart`。資料層不回傳任何介面文字，文字由 UI 的 ARB 組。

## 9. 同步傳輸模型（D-052）— `lib/sync/sync_transfer.dart`、`sync_engine.dart`、`sync_controller.dart`

```dart
enum TransferDirection { upload, download }
enum TransferState { waiting, active, done }

class SyncTransfer {            // 值相等（可放心用 select）
  String file;                  // 圖片檔名
  TransferDirection direction;
  TransferState state;
  double? progress;             // 0..1；waiting＝null；active 但不知道總大小＝null；done＝1
  bool isUpload/isDownload/isWaiting/isActive/isDone;
}
```

`SyncState`（`syncControllerProvider`）新增欄位與 getter（舊的 `stage`、`imagesDone`、`imagesTotal`、
`hasImageProgress`、`imageFraction` 保留，橫條已不用）：

| 成員 | 意義 |
|---|---|
| `List<SyncTransfer> transfers` | 這次同步要傳的全部圖片，**先下載後上傳**（實際處理順序）。同步結束或失敗就清空 |
| `bool transfersPlanned` | 清單是否已確定（拉完文件、比對完遠端之後） |
| `isChecking` | 同步中且 `!transfersPlanned`：頭像外圈轉不確定的弧，**不可點** |
| `isTransferring` | 同步中、`transfersPlanned` 且 `transfers` 不空：外圈是進度環，**可點**開「同步進度」 |
| 都不是 | 檢查完沒有東西要傳 → 外圈淡出（`isSyncing` 可能仍短暫為 true，以 `isChecking`／`isTransferring` 為準） |
| `transferTotal` / `transferDone` | 總張數／已完成張數（上傳＋下載） |
| `transferFraction` | `done / total`（0~1）；沒有傳輸為 null。**進度環請用這個** |
| `uploadCount` / `downloadCount` | 上傳／下載的總張數（sheet 的「上傳 N 張・下載 M 張」） |
| `uploadDone` / `downloadDone` | 各自已完成的張數 |
| `activeTransfer` | 正在傳的那一張（可能為 null，見下方「節流」） |

要點：
- 傳輸是**一張接一張**（不併行），同時最多一張 `active`。
- 首次匯入存檔在背景繼續時同樣適用（同一個 controller）。
- **節流**：逐位元組的進度通知最多每 100ms 一次（`SyncEngine.progressInterval`，測試可傳 `Duration.zero`）。
  每張圖「完成」與階段切換一定通知。「開始傳這張」的 active 狀態也是節流的，所以一張剛開始、還沒收到
  位元組時可能還顯示 `waiting`（UI 當成排隊中／轉圈即可）。
- **下載進度**是真的位元組進度（`DriveRemote.download` 串流讀取，依 `Content-Length` 算；伺服器不給長度時
  `progress` 維持 null，UI 轉圈）。
- **上傳進度**：`DriveRemote.upload` 改為串流請求（32KB 一段），每段被 socket 取走就回報
  「已交給網絡層的位元組 / 總位元組」。這會略快於對端實際收到的量（OS 有緩衝），所以接近 100% 時可能停一下才完成；
  完成時一律設成 done／1.0。沒有位元組進度的遠端實作就是開始 0（active、progress 為 null）、完成 1。
- 失敗的下載（遠端回 null）仍標為 done，下次同步再試（同舊行為）。
- 上傳清單只含「遠端還沒有、本機有檔案」的圖片，已去重。

`SyncRemote` 介面變更（自訂實作要跟著改）：
```dart
typedef TransferProgress = void Function(int done, int? total);
Future<Uint8List?> download(String name, {TransferProgress? onProgress});
Future<String> upload(String name, Uint8List bytes, {String contentType, TransferProgress? onProgress});
```
`MemoryRemote({int progressSteps = 0, Duration stepDelay = Duration.zero, Future<void> Function(String name, bool isUpload)? onTransfer})`：
`progressSteps > 0` 時每次傳輸分成這麼多段回報進度，段間等 `stepDelay`；`onTransfer` 在每次傳輸開始前呼叫
（測試用來暫停或製造失敗）。`SyncEngine.sync` 的 `SyncProgress` 多了 `transfers`、`transfersPlanned`。

### 圖片格的下載角標

```dart
class ImageDownloadStatus { bool isMissing; double? progress; static const present; }
final imageTransferProvider = Provider.family<ImageDownloadStatus, String>(...); // 參數＝圖片檔名
```
- 本機已有（或還不知道，`imageExistsProvider` 尚在載入時當作已有，避免閃一下）→ `ImageDownloadStatus.present`，不顯示角標。
- 本機沒有 → `isMissing == true`；`progress` 非 null＝正在下載且知道進度（角標用確定進度環）；
  null＝排隊中、沒有在同步、或不知道大小（角標轉圈）。
- 圖片下載完成時自動變回 `present`（沿用 `ImageStore.changes`）。每張圖只會在自己的狀態變時重建。
- 封面與坑內所有圖片格都用這個（取代只看 `imageExistsProvider` 的 D-028 做法）。

### 圖片所在位置 — `lib/data/image_location.dart`

```dart
enum ImageCell { official, fan, junk, draft, idea, piece }
class ImageLocation { String pitId; String pitName; ImageCell cell; }
Future<ImageLocation?> AppDatabase.imageLocationOf(String file);
final imageLocationProvider = FutureProvider.family<ImageLocation?, String>(...); // providers.dart
```
- 「坑名 · 格」的文字由 UI 依 `cell` 對應 ARB（官方圖冊／好看同人圖／雜物／草稿／腦洞／成圖）。
- 同一檔案在多處時優先順序：官方 → 同人圖 → 雜物 → 成圖 → 草稿 → 腦洞；已刪除、被移動而隱藏的列不算。
  找不到（例如只被年度回顧引用）→ null，UI 可只顯示縮圖。

## 10. 跨坑移動（D-054）— `junk_queries.dart`

```dart
Future<void> moveAlbumImages({
  required AlbumCell from, required List<String> ids, required AlbumCell to,
  String? groupId,        // 目標是官方＝官方分組；目標是同人圖＝出處分組（可 null）。必須屬於「目標坑」
  String? targetPitId,    // 新增；null＝留在原坑（舊行為）
});
```
列出目標坑分組給 sheet 用既有的：`watchGroups(pitId, kind: 'official'|'fan')`／`groupsProvider((pitId, kind))`。

語意（在 §2 的基礎上）：
- `ids` 都是 `from` 格目前可見的列；每一列各自決定目標坑＝`targetPitId ?? 該列原本的坑`。
- **同格同坑**才是「只換分組」；`from == to` 但 `targetPitId` 是別的坑＝跨坑移動（官方→官方、同人圖→同人圖、雜物→雜物都可以）。
- 目標坑沒有同 `imageKey` 的列 → 新建一列，`pitId` 是**目標坑**；有隱藏列（之前從那邊移走的）→ 取消隱藏並恢復它原本的欄位／tag，
  有給 `groupId` 時覆蓋分組。來源列 `hidden = true`，**維持在原坑**。所以 A 坑→B 坑→移回 A 坑，A 坑會恢復原本的列（分組、作者、出處、tag 都在）。
- 官方分組：`groupId` 沒給 → 新建列用**目標坑第一個官方分組**。同人圖：沒給 → 沒有出處。
  `groupId` 不屬於目標坑（或已刪除）→ 丟 `ArgumentError`，整個 transaction 回滾（沒有任何變動）。雜物不檢查。
- **tag**：tag 按坑獨立。同人圖→同人圖跨坑新建列時，把來源的 tag 按**名稱**對應目標坑已有 tag（`createTag` 本來就會重用同名），
  目標坑沒有的自動新增同名 tag。作者與舊版出處文字也帶過去（判斷：它仍是同一張同人圖）。
  **取消隱藏**的列保留自己的 tag，不重新對應。目標是官方／雜物時不建立 tag（tag 留在隱藏的同人圖列上）。
- **封面**：被移動列若是來源坑的坑封面（`coverImageId`）：同坑移到官方／同人圖→改指向新列（舊行為）；移到雜物或**跨坑**→清成 null。
  官方／同人圖格封面（`officialCoverId`／`fanArtCoverId`）一律清成 null。移進目標坑**不會**設定任何封面，目標坑原有封面不受影響。
- 刪除（`deleteOfficial`／`deleteFanArts`／`deleteJunk`）現在按 `imageKey` 找隱藏分身，**不限定坑**（跨坑移動後的隱藏分身會一起軟刪除）。
- 隱藏列在所有既有查詢都被排除（§2 的清單），新增的 tag 在 `watchTags(目標坑)`／`watchTagUsage` 立即可見。
- 同步：新列、隱藏列、新 tag 都走既有的 `official`／`fanart`／`junk`／`tags` 文件，沒有新增種類。

## 11. 年度回顧月份挑圖（D-056）— `goal_queries.dart`

```dart
class ReviewMonthPiece { String pieceId, title, file; int width, height, actualLikes; DateTime finishedAt; }
class ReviewMonthSummary { int pieceCount; String? file; bool isManual; bool get canPick /* pieceCount > 1 */; }

Stream<List<ReviewMonthPiece>> watchReviewMonthPieces(int year, int month);   // reviewMonthPiecesProvider((year, month))
Stream<Map<int, ReviewMonthSummary>> watchReviewMonthSummaries(int year);     // reviewMonthSummariesProvider(year)
Future<void> setReviewMonthImage(int year, int month, String? file);           // null＝清回預設
ReviewMonthPiece? defaultReviewPiece(Iterable<ReviewMonthPiece>);              // 純函式
```
- `watchReviewMonthPieces`：完成日期（`finishedAt`）落在該月、未刪除、**至少有一張圖**的成圖，`finishedAt` 新到舊；
  `file` 是成圖的第一張圖（排序最前）。**候選包含私稿與商稿**（判斷：回顧是自己看的年度總結，不分公開與否；
  跟「目標」只算公開不同，與 `pieceImagesByMonth` 一致）。
- **預設代表圖**＝候選裡 `actualLikes` 最高；同分取 `finishedAt` 最新（再同取 id 較大者，結果穩定）；取該成圖的第一張圖。
- `watchReviewMonths(year)`（`reviewMonthsProvider(year)`，簽名不變）現在回傳**已解析**的結果，`year_view`／`review_edit_page`／匯出照舊使用即可：
  1. 手動挑的圖（資料列 `imageFile` 非空）→ 它；
  2. 手動留空（`setReviewMonth(y, m, null)`，既有行為）→ key 存在、值為 null；
  3. 否則 → 預設代表圖。該月沒有候選 → key 不存在。
- `setReviewMonthImage(y, m, file)`：手動指定（存成 `YearReviewMonths.imageFile`，會同步）；`file == null` 清回預設
  （實作上存空字串作為「自動」標記，因為 `YearReviewMonths` 沒有軟刪除，直接刪列無法同步到另一台；
  讀取、同步一律把空字串當作沒有圖片）。
- **按「完成」才套用**：sheet 內的選取狀態由 UI 暫存，按完成時呼叫 `setReviewMonthImage`。
  使用者選到的剛好是預設圖時，UI 想存成手動或清回預設都可以，建議存成手動（之後互動量變動也不會跳走）。
- `watchReviewMonthSummaries` 供年度格決定長按是否有反應：`canPick`（候選多於一張）；`isManual` 可用來顯示標記；`file` 為目前使用的圖。
- 手動挑的是**檔名**，不綁成圖：成圖之後被刪或移到別月，那個月仍顯示該檔名（與既有行為相同）。

---

# 批次 6–8 資料層（D-057～D-070）— schema v7

給 UI 工程師的唯一資料層參考。資料層不回傳任何介面文字（預設分組名稱是資料值）。
測試：`test/oshi_test.dart`、`test/batch678_test.dart`、`test/batch678_sync_test.dart`、`test/migration_test.dart`（v1～v6 → v7）。
（D-071 素材庫已在批次 9 實作，見最後一節。）

## 1. Schema v7 與遷移

| 變更 | 內容 |
|---|---|
| 新表 `OshiRecords` | `SyncColumns`、`pitId`、`date`（當天 00:00）、`groupId?`、`title?`、`description?` |
| `Ideas`、`Drafts` | 新欄位 `date`（DateTime，含時間） |
| `OwnerType.oshi` | 推活的圖片放 `EntityImages`（`ownerType = oshi`） |
| `TagTarget.official`、`TagTarget.oshi` | 官方圖 tag（D-060）、推活 tag |
| `OfficialGroups.kind = 'oshi'` | 推活分組，沿用既有分組表與函式 |

遷移（`database.dart` `_migrateV7`，v1～v6 都測過；缺表會整張建立）：
- `Ideas.date`、`Drafts.date` = 該列的 `createdAt`；`updatedAt` 不動。
- 每個既有坑補 3 個推活分組（線下照片、遊戲截圖、對話記錄）。**id 由坑 id 決定**（`oshi-default-{pitId}-{0..2}`），
  `updatedAt` 設成最小值：兩台裝置各自升級也會得到同一批列，同步後不會重複；別台改過／刪過的版本永遠勝出。
- 新坑（`createPit`）自動建立三個推活分組（一般 uuid）。
- `AppDatabase.defaultOshiGroups`、`seedOshiGroups(pitId, {deterministic})`。
- `ensureOshiGroups(pitId)`：從**舊版 App**同步進來的坑沒有推活分組；進推活頁時呼叫一次即可（可重複呼叫、很便宜）。
  只在這個坑**從沒有過**推活分組（含已刪除的）時才建立，所以使用者刪光後不會補回來。
- 官方圖 tag、草稿↔成圖關係不需要改結構（`TagLinks`、`DraftPieces` 本來就有）。

## 2. 推活（D-057／D-062／D-065）— `oshi_queries.dart`

```dart
class OshiRecordView { OshiRecord record; List<ImageRef> images /* ≥1 */; List<Tag> tags; OfficialGroup? group; DateTime get date; ImageRef get cover; }

Stream<List<OshiRecordView>> watchOshiRecords(String pitId, {String? groupId, String? tagId});
Stream<OshiRecordView?> watchOshiRecord(String id);   Future<OshiRecordView?> getOshiRecord(String id);
Stream<int> watchOshiCount(String pitId);              // PitStats.oshi 也是同一個數字
Stream<Map<String?, int>> watchOshiGroupCounts(String pitId);   // key＝分組 id；null＝沒有分組
Future<String> saveOshiRecord({String? id, required String pitId, required DateTime date, String? groupId,
    String? title, String? description, required List<NewImage> images, List<String> tagIds = const []});
Future<void> deleteOshiRecords(Iterable<String> ids);  // 軟刪除
Future<void> ensureOshiGroups(String pitId);
```
Providers（`lib/state/providers.dart` 最後）：`oshiRecordsProvider((pitId, groupId?, tagId?))`、`oshiRecordProvider(id)`、
`oshiGroupCountsProvider(pitId)`、`groupsProvider((pitId, 'oshi'))`、`tagCoverageProvider((cell, 'id1,id2'))`。

- **排序**：日期新到舊；同日以建立時間新到舊。按月份分段、段首「N 筆」是 UI 的事（資料已排好）。
- `groupId` 與 `tagId` 可並用。**搜尋結果「+N」與詳情頁點 tag 都用 `watchOshiRecords(pitId, tagId: …)`**（D-065）；
  筆數與搜尋的 `oshi.total` 一致。分組 pills 的「全部」＝不傳 `groupId`。
- `saveOshiRecord`：
  - `images` 至少一張，否則丟 `ArgumentError`（整筆回滾）。
  - `date` 只取年月日（存當天 00:00）。預設日期（第一張圖的 EXIF 拍攝時間 → 檔案時間 → 今天）是 UI 的事，傳進來即可。
  - `groupId` 必須是**同一個坑**、未刪除的**推活**分組，否則 `ArgumentError`；`null` ＝不分組。
  - 標題、描述 trim 後空字串存成 `null`。編輯（傳 `id`）會更新 `updatedAt`；整組替換圖片與 tag（相同檔名的圖沿用原列）。
- **分組**（沿用 `GroupManage` 的函式，`kind: 'oshi'`）：`watchGroups(pitId, kind: 'oshi')`、`addGroup(pitId, name, kind: 'oshi')`、
  `renameGroup`、`reorderGroups`、`deleteGroup(id)`。
  - **判斷**：推活的分組是選填的，所以 `deleteGroup` 對 oshi 分組**可以刪光**（官方／同人圖仍至少保留一個）；
    組內紀錄的 `groupId` 變成 `null`（「沒有分組」，只顯示日期）並更新紀錄的 `updatedAt`，會同步。
    對 oshi 分組 `deleteGroup` 一律回傳 `true`。
- **不計入**：目標進度、目標時間軸（`watchTimeline`）、坑封面候選（`watchCoverCandidates`）、`PitStats.imageCount`、年度回顧。
- **計入**：`watchTagUsage` 的 tag 使用次數（只算未刪除的）、`deletePit` 連帶軟刪除推活紀錄、主頁坑的「最後更新」排序。
- 推活的圖不在 `imageLocationOf`（同步進度 sheet 的「坑 · 格」）的範圍：回傳 `null`，UI 只顯示縮圖。
  （我沒有加 `ImageCell.oshi`，因為 UI 的 `switch` 是窮舉的；要加的話連同 ARB 一起加。）

## 3. 腦洞／草稿的 `date`（D-070）— `entity_queries.dart`、`goal_queries.dart`

```dart
saveIdea({..., DateTime? date, DateTime? createdAt})
saveDraft({..., List<String>? pieceIds, DateTime? date, DateTime? createdAt})
```
- `Idea.date`、`Draft.date`（含時間）。**列表排序**（`watchIdeaViews`、`watchDraftViews`、搜尋、封面）＝`date` 新到舊，
  同日以建立時間新到舊；**編輯內容不再讓項目跳到最前**（以前依 `updatedAt`）。
  成圖列表仍依 `updatedAt`，成圖的時間仍是 `finishedAt`。
- **目標進度（腦洞、草稿）與目標日頁時間軸（`TimelineItem.time`）改用 `date`**；成圖仍用 `finishedAt`。
- `date` 規則（日期選擇器只選到「日」，但目標日頁的時間軸要顯示時間）：
  - 不傳：新增＝現在；編輯＝不變。
  - 傳「只有日期」（00:00:00）：與原本**同一天**→沿用原本的時間；**今天**→取現在；其他天→維持 00:00。
  - 傳帶時間的值（例如目標日頁 ＋ 的「現在」）→ 原樣儲存。
  所以表單可以一律把日期選擇器的結果（00:00）傳進來，不用自己合併時間。
- 相容：`createdAt` 參數還在——新增且沒傳 `date` 時當作 `date`（`createdAt` 欄位也照寫）。`saveDraft` 以前忽略 `createdAt`，現在會用。
- 卡片上的時間／詳情頁的日期請改讀 `idea.date`／`draft.date`（不要再讀 `createdAt`）。
- 同步：文件多一個 `date` 欄位；舊文件沒有時補成 `createdAt`。

## 4. 草稿↔成圖關聯（D-069）

同一組關係（表 `DraftPieces`），從兩邊都能設定、兩邊都會顯示：
```dart
class LinkedItem { String id; String? title; ImageRef? firstImage; }
DraftView.pieceIds / DraftView.linkedPieces   // 關聯成圖；順序＝完成日期新到舊；略過已刪除的
PieceView.draftIds / PieceView.linkedDrafts   // 關聯草稿；順序＝日期新到舊；略過已刪除的
saveDraft(..., List<String>? pieceIds)        // null＝不動；[]＝清空
savePiece(..., draftIds)                      // 本來就有（必填）
Future<void> setDraftPieces(String draftId, List<String> pieceIds)
```
- 同步擁有者是**成圖**（成圖文件有 `draftIds`）。從草稿側修改（`saveDraft(pieceIds:)`／`setDraftPieces`）會把**受影響成圖
  （原本的與新的）的 `updatedAt` 往前蓋**，另一台才拉得到。副作用：成圖列表（依 `updatedAt`）裡這些成圖會跳到前面。
- 刪除草稿會把成圖／腦洞文件裡對它的記錄一併更新（蓋 `updatedAt`）；刪除成圖會更新關聯的腦洞。
- `DraftView.imageOnly` 仍用 `pieceIds.isEmpty` 判斷（行為不變）。

## 5. 官方圖 tag 與多選批次 tag（D-060）— `album_queries.dart`、`batch_tag_queries.dart`

- 官方圖現在可以有 tag（`TagTarget.official`）；tag 次數（`watchTagUsage`）含官方圖。官方圖文件多一個 `tagIds`。
- `addOfficial(pitId, groupId, images, {List<String> tagIds = const []})` — 一次加圖＋分組＋tag（分享進來用）。
- `setOfficialTags(imageId, tagIds)` — 整組替換並更新 `updatedAt`；讀取用 `watchTagIds(TagTarget.official, id)`。
- **批次 tag**（官方圖冊、好看同人圖的多選 tag sheet）：
```dart
enum TagCoverage { none, some, all }            // 白底／虛線框＋橫線／實色＋勾
class TagCoverageEntry { Tag tag; TagCoverage coverage; int count; int total; bool get tapAdds; }

Future<List<TagCoverageEntry>> tagCoverage(AlbumCell cell, Iterable<String> ids);
Stream<List<TagCoverageEntry>> watchTagCoverage(AlbumCell cell, Iterable<String> ids);   // tagCoverageProvider((cell, 'id1,id2,…'))
Future<List<String>> applyBatchTags(AlbumCell cell, Iterable<String> ids,
    {Iterable<String> addTagIds, Iterable<String> removeTagIds, Iterable<String> newTagNames});  // 回傳新增（或重用）的 tag id
```
  - `cell` 只能是 `AlbumCell.official` 或 `AlbumCell.fan`（雜物沒有 tag → `ArgumentError`）。`ids` 是該格目前可見的圖片列 id，必須同一個坑。
  - `tagCoverage` 回傳**坑內所有 tag**（依名稱排序）在這批圖上的狀態；`tapAdds`＝點一下會「全部加上」（部分有／都沒有），
    否則「全部移除」（全部有）。沒有有效的圖 → 空清單。
  - `applyBatchTags` 一個 transaction：先 `newTagNames`（去掉開頭 `#`、空白略過；同名 tag 重用，不重複建立）→ 這些與 `addTagIds` 加到**每一張**；
    `removeTagIds` 從**每一張**移除（同一個 tag 兩邊都有時以 add 為準）。**只有實際有變動的圖才更新 `updatedAt`**（tag 隨圖片文件同步）。
    tag 不屬於這個坑、混坑選取、雜物 → `ArgumentError`，整個回滾（連新建的 tag 也不留）。
  - 建議用法：sheet 內只暫存點擊，按「完成」時一次呼叫 `applyBatchTags`；sheet 內「新增」tag 若要立刻顯示，可先 `createTag(pitId, name)`
    （同名會重用），再把它放進 `addTagIds`。
  - 副作用：官方圖／同人圖列表依 `updatedAt`，被批次改過 tag 的圖會跳到列表前面。
- **移動規則（D-044／D-054 的延伸，判斷）**：tag 是各格的列的欄位，跟分組／作者／出處一樣「保留但隱藏」：
  - 官方→同人圖（或反向）：新列**沒有 tag**；原列隱藏、tag 留在隱藏列（不計入使用次數）；移回時恢復。
  - 官方→官方**跨坑**：新列的 tag 按名稱對應目標坑（沒有就新增同名 tag），與同人圖→同人圖跨坑一致；取消隱藏的列保留自己的 tag。
  - 雜物沒有 tag（移進雜物後 tag 留在隱藏列）。

## 6. 分享進來（D-059／D-053）

不需要新 API，一次呼叫存一批：
- 官方圖冊：`addOfficial(pitId, groupId, images, tagIds: [...])`
- 好看同人圖：`addFanArts(pitId, images, author: …, groupId: 出處分組 id, tagIds: [...])`（既有）
- 雜物：`addJunk(pitId, images)`
- 開新坑：`createPit(name:)`（會一併建立推活分組）
- 草稿／腦洞／成圖／推活：「下一步」打開各自的新增頁，圖片預先放好；推活用 `saveOshiRecord`。
- **MoveSheet（設計稿）只有 官方圖冊／好看同人圖／雜物三個位置，沒有推活**：`moveAlbumImages` **不支援**移到／移出推活，
  也沒有「相簿圖片轉成推活紀錄」的 API（設計稿沒畫，依規定不做；要做請先問 Molly）。

## 7. 坑內搜尋（D-061／D-065）— `search_queries.dart`

`watchPitSearch(pitId, {text, tagId, thumbLimit})`（簽名不變）；`PitSearchResult` 新增：
```dart
PitSearchGroup<OshiRecordView> oshi;
Map<PitSearchSection, int> get counts;               // 各段實際筆數
List<PitSearchSection> get visibleSections;          // 筆數 > 0 的段，依顯示順序
enum PitSearchSection { pieces, fanArts, oshi, drafts, ideas }
```
- 段與分頁順序：**成圖 → 同人圖 → 推活 → 草稿 → 腦洞**。`total`（「全部」）含推活。
- 推活命中：標題、描述、**分組名稱**、tag 名稱（每個詞都要命中其中一個欄位）；`tagId` 要求有該 tag。圖片類 `items` 只含前 `thumbLimit` 筆。
- D-061：段內筆數直接用 `group.items.length`／`total`——少於 3 筆就照實際張數放、`more == 0` 不顯示「+N」；筆數 0 的段與分頁用 `visibleSections` 略過。
- 「+N」進推活時間軸並帶同一個 tag：`oshiRecordsProvider((pitId, null, tagId))`。

## 8. 坑內六格（D-058）

```dart
PitStats.official / fanArts / drafts / ideas / pieces / oshi   // 新增 oshi（「N 筆」）
CellCovers.official / fanArt / draft / idea / piece              // 沒有 oshi
```
- 設計稿（`Pit`、`PitFilled`）六格：**只有「我的成圖」在有圖時用最新一張成圖當封面**（`PitFilled` 該格是灰色圖片佔位），
  其餘五格（含推活）永遠是淡色底＋icon，所以 `CellCovers` **沒有 oshi 欄位**。
- `CellCovers.piece` 現在是**完成日期（`finishedAt`）最晚**的成圖的第一張圖（以前是 `updatedAt` 最新）；沒有成圖 → `null`（顯示 icon）。
  草稿／腦洞封面改取 `date` 最新的一筆（六格設計稿不用，但「選擇封面」仍會用到）。
- 計數：官方圖冊「N 張」＝`official`、好看同人圖＝`fanArts`、草稿＝`drafts` 份、腦洞＝`ideas` 個、成圖＝`pieces` 張、推活＝`oshi` 筆。

## 9. 同步

- `syncFormatVersion` **維持 2**：新版寫出的文件舊版 App 仍讀得懂（多的欄位／新種類被忽略），舊文件新版也讀得懂（缺的欄位補預設：
  `date`＝`createdAt`；官方圖文件沒有 `tagIds` 時**不動本機已有的 tag**）。舊版 App 改寫某筆資料時會丟掉它不認識的欄位
  （`date`、官方圖 tag），這是向下相容的代價；Molly 兩台都更新後就沒有問題。
- 新種類 `oshi`（紀錄＋圖片清單＋tagIds；圖片檔隨文件上傳／下載）；推活分組走既有的 `groups`（kind=oshi）。
- **修正（影響所有種類）**：套用遠端文件改成整列覆寫（`FullUpsert.upsertFull`）。drift 的 `insertOnConflictUpdate`
  在更新時會**略過 null 欄位**，所以遠端把欄位清成空（取消推活分組、清掉標題、草稿清掉標題內文、成圖清掉發佈日期…）
  以前傳不到另一台。有測試（`batch678_sync_test.dart`）。
- 受影響的 updatedAt 蓋法：草稿側改關聯成圖→成圖；刪分組→組內推活紀錄；批次 tag→有變動的圖；刪草稿／成圖→擁有關係的腦洞／成圖。

## 10. 刻意的行為改變（既有測試沒有需要更新的）

- 腦洞／草稿列表、封面、搜尋、目標進度、目標日頁時間軸 → 以 `date` 為準，不再是 `updatedAt`／`createdAt`。
- 成圖格封面 → 最新完成日期的成圖。
- `watchTagUsage` 含官方圖與推活。
- `deleteGroup` 對推活分組可刪光，組內紀錄變成無分組。

---

# 批次 9 資料層（D-071 素材庫、D-072 連續日頁時間軸）— schema v8

測試：`test/material_test.dart`、`test/timeline_test.dart`、`test/migration_test.dart`（v1～v7 → v8）。
資料層不回傳任何介面文字：分類只回傳 enum 名稱（英文 id），顯示文字（服裝、姿勢…）由 UI 的 ARB 提供。

## 1. Schema v8 與遷移

| 變更 | 內容 |
|---|---|
| 新表 `MaterialImages`（資料類別 `MaterialImage`） | `SyncColumns`、`imageFile`、`width`、`height`、`category`（`MaterialCategory`，DB 存名稱） |
| 新 enum `MaterialCategory` | `clothing, pose, body, palette, scene, style, sticker`＝服裝、姿勢、人體、色盤、場景、畫風、貼圖。順序＝畫面 pills 順序（「全部」是 UI 的 `null`）；新值只能加在最後 |

- 遷移：`from < 8` → `createTable(materialImages)`，沒有舊資料要回填；v1～v7 都測過。`database.dart` 已 re-export `MaterialCategory`。
- 沒有任何文字欄位、沒有 tag、沒有 pit。**不計入**目標、時間軸、搜尋、封面、坑統計、坑的「最後更新」排序（有測試）。

## 2. 素材庫（D-071）— `lib/data/material_queries.dart`

```dart
Stream<List<MaterialImage>> watchMaterials({MaterialCategory? category}); // null＝全部；新的在前
Future<List<String>> addMaterials(MaterialCategory category, List<NewImage> images); // 回傳新 id（同順序）
Future<void> moveMaterials(Iterable<String> ids, MaterialCategory category);
Future<void> deleteMaterials(Iterable<String> ids);                       // 軟刪除
Stream<MaterialCounts> watchMaterialCounts();

class MaterialCounts { Map<MaterialCategory,int> byCategory; int of(MaterialCategory c); int get total; static final empty; }
```
Providers（`lib/state/providers.dart`）：`materialsProvider(MaterialCategory?)`（family；null＝全部）、`materialCountsProvider`。

- **排序**：`createdAt` 新到舊。`createdAt` 只有**秒**精度，所以同一秒內以寫入順序決定；
  `addMaterials` 一批共用同一個 `createdAt`，且**這批的顯示順序＝傳入 `images` 的順序**（第一張在最上面），整批排在舊的前面。
- `addMaterials`：單一交易；`deviceId` 留空（同其他實體）。空清單回傳空 list 不做事。
  「在『全部』下加圖要先選分類」是 UI 的事：呼叫前就要決定好 `category`（分享進來的「素材庫」段也一樣呼叫它）。
- `moveMaterials`：只更新**不在目標分類且未刪除**的列（`updatedAt` 蓋現在）；已在目標分類的不動，避免無謂同步。
- `deleteMaterials`：設 `deletedAt`/`updatedAt`；圖檔不會從磁碟移除（同其他實體）。已刪除的不會再被移動。
- `watchMaterialCounts`：`MaterialCounts.byCategory` **一定有全部 7 個分類**（沒有圖為 0）。
  Profile 的素材庫卡右邊用 `total`；移動 sheet 每個分類「N 張」用 `of(category)`。
- 下載到 `Pictures/Drawer` 等是 UI／平台層的事，資料層只提供 `imageFile` 檔名（用 `ImageStore` 取路徑，同其他圖片）。

## 3. 素材庫同步

- 新種類 `material`（`MaterialKind`，`allSyncKinds` 已加入）：一張圖一份文件，內容＝整列 JSON；沒有附屬資料。
  圖檔隨文件上傳／下載，與其他圖片完全一樣：進**傳輸清單／進度**（批次 5 的 `SyncProgress.transfers`）、
  斷線中斷後「只缺圖檔」的情況下次同步補下載（`_referencedImages` 已含素材）。
- `syncFormatVersion` **維持 2**，向下相容：舊版 App 看到未知種類 `material` 會忽略（不讀、也不動），新舊並存不出錯；
  代價是素材在舊版 App 上看不到，兩台都更新後就正常。
- 文件缺 `width`／`height` 補 0。**遠端文件的 `category` 本機不認識**（日後新增分類、本機還沒更新）時：整份文件略過
  （不覆蓋、不丟例外、不中斷同步）。
- **`imageLocationOf(file)`（同步進度 sheet 的「坑 · 格」）**：素材的圖**回傳 null**（不在任何坑）。我**沒有**新增
  `ImageCell.material`——`lib/ui/sync/sync_sheet.dart` 的 `cellName` 是窮盡 `switch`，加 enum 值會讓 UI 編譯失敗，
  而且 `ImageLocation` 必須有 `pitId`／`pitName`，素材沒有。現有 UI 對 null 的處理是該行位置文字留空（只看縮圖與方向標籤）。
  想在進度 sheet 顯示「素材庫」：UI 端自己判斷檔名是否屬於素材，或日後把 `ImageLocation` 的坑欄位改成可為空並加
  `ImageCell.material`（需同時改 `sync_sheet.dart` 與 ARB）。

## 4. 連續日頁時間軸（D-072）— `lib/data/timeline_queries.dart`

目標 · 日頁不再逐日查詢，改成一條連續的時間軸：腦洞／草稿（依 `date`）與成圖（依 `finishedAt`）合併，時間**新到舊**；
沒有內容的日子不出現；已刪除的不算。項目沿用 `TimelineItem`（`goal_queries.dart`，欄位與單日查詢相同）。

```dart
class TimelineCursor { DateTime date; String id; factory TimelineCursor.of(TimelineItem item); }
class TimelinePage   { List<TimelineItem> items; bool hasMore; TimelineCursor? get next; static const empty; }

Future<TimelinePage> loadTimelinePage({TimelineCursor? after, int limit = 30});
Future<TimelinePage> loadTimelineUntil(DateTime day, {int limit = 30});
Future<DateTime?>    nearestTimelineDay(DateTime day);
Future<Map<DateTime,int>> timelineMonthCounts(Iterable<DateTime> months);
Stream<int>          watchTimelineRevision();
```
Provider：`timelineRevisionProvider`（`StreamProvider<int>`）。分頁查詢不是 provider——在 notifier／state 裡用
`ref.read(databaseProvider).loadTimelinePage(...)` 呼叫。

- **排序與游標**：全域排序鍵＝`(時間 desc, id desc)`（id 只用來打破同時間的平手，跨種類）。
  `after` 游標＝上一頁最後一筆的 `(time, id)`（`page.next`），**不含**那一筆。因此跨頁不重複、不跳過，
  同一時間（DB 的日期是秒精度，容易撞）的多筆也不會被頁界切壞。`limit` 以**筆**為單位，頁界可能落在某一天中間——
  UI 把相鄰頁接起來後再按日期分組、插月份標題即可（同一天可能被分到兩頁，這是正常的）。
- `hasMore`：這頁之後還有更舊的項目（剛好湊滿一頁且沒有更多時為 false）。空頁 `next == null`。
- **刷新**：`watchTimelineRevision()` 先發 `0`，之後腦洞／草稿／成圖（含其圖片、tag）有任何寫入就遞增，不帶資料。
  UI 在它變動時重新載入「目前已載入的範圍」（例如重載到同樣的筆數：`loadTimelinePage(limit: 已載入筆數)`）。
  它偏寬鬆：與時間軸無關的寫入（例如只改關聯）也會發出，重載很便宜。
- **跳到某天**（月頁點日曆）：
  1. `final target = await db.nearestTimelineDay(day)`＝`day` 當天**或之前**最近一個有內容的日子（當天 00:00）；之前完全沒有內容回 `null`
     （日頁從頂端開始，不捲動）。傳入的 `day` 若帶時間，仍以那一天為準。
  2. `final page = await db.loadTimelineUntil(day)`：從最新的一筆載到**包含 `target` 整天**的所有項目（單次查詢，不分頁），
     至少 `limit` 筆；之後照常用 `loadTimelinePage(after: page.next)` 接下一頁。之前沒內容時等同第一頁。
     UI 再用 `target` 把清單捲到那一天的位置。
  直接點「日」分頁＝一般的 `loadTimelinePage()`（時間軸本來就從最新開始）。
  注意：若有「未來日期」的項目（日期欄可選未來），它們會排在最上面、在今天之前；設計稿沒畫，若 Molly 要「從今天開始」請先問她，目前不另外處理。
- **月份標題**「2026 年 9 月 · 4 項」：`timelineMonthCounts(months)`。`months` 的每個元素只取年月；回傳 key 是 `DateTime(年, 月)`，
  值＝該月**整個月**的腦洞＋草稿＋成圖筆數（與載入了幾筆無關、不含已刪除，沒有內容為 0）。
  做法：從已載入 items 的 `time` 取出出現過的月份，一次查完；`timelineRevisionProvider` 變動時一起重查。
- **舊的單日查詢保留**：`watchTimeline(day)`（`timelineProvider`）行為不變，仍有測試；內部改成與新查詢共用 `timelineItemsOf(...)`
  （`goal_queries.dart`，把腦洞／草稿／成圖列組成 `TimelineItem`）。

## 5. 刻意的行為改變

- 無（既有測試沒有需要更新的）。`AppDatabase.schemaVersion = 8`。


# 批次 10 資料層（D-079 推活多選、D-080 影片／GIF、坑內格子各自的封面）— schema v9

資料層純 Dart、沒有新增任何 pubspec 套件（影片探測／截圖／播放由 UI 負責，見下方「給 UI 的銜接」）。

## 1. Schema v9 與遷移

`AppDatabase.schemaVersion = 9`。`_migrateV9`（v1～v8 都能升上來，可重複執行）：

- **Pits** 加四個可空欄位：`draftCoverFile`、`ideaCoverFile`、`pieceCoverFile`、`oshiCoverFile`（見第 2 節）。
- **五張放圖的表**（`OfficialImages`、`FanArts`、`JunkImages`、`MaterialImages`、`EntityImages`——後者涵蓋腦洞／草稿／成圖／推活的圖）
  都加了 `MediaColumns`：
  `kind`（`MediaKind`，存名稱 `image`／`gif`／`video`，預設 `'image'`）、`durationMs`（int?，只有影片）、`posterFile`（String?，影片截圖檔名）。
- 既有資料：一律 `image`；**副檔名是 .gif 的回填成 `gif`**（讓升級後 GIF 馬上能播；不動 updatedAt，每台裝置各自升級得到同樣結果，不需同步）。
- 每個欄位加之前先檢查是否已存在（舊版的遷移若是整張建表，已帶新欄位）。
- 測試：`test/migration_test.dart`（v1～v5 fixture 升到 v9、真實 v8 結構拆欄位後升級、重複執行）。
  v6～v8 的 fixture 本身缺少 `junk_enabled` 等欄位（既有測試的舊限制），所以不拿它們讀 `pits`。

## 2. 坑內六格各自的封面 — `album_queries.dart`

**需求**：長按坑內頁的某一格＝選「這一格」在坑內頁顯示的封面；推活格也有封面。
**坑封面（主頁卡片）完全不變**：`Pits.coverImageId`、`setCover(pitId, imageId)`、編輯坑的「更換封面」、`watchCoverCandidates(pitId)`（kind 為 null）都沿用。

```dart
Future<void>    setCellCover(String pitId, String kind, String? imageId);
Future<String?> chosenCellCoverId(String pitId, String kind);   // 目前指定且仍有效的候選圖 id
const cellKinds = ['official','fan','draft','idea','piece','oshi'];

class CellCovers { String? official, fanArt, draft, idea, piece, oshi; }   // 新增 oshi
Stream<CellCovers> watchCellCovers(String pitId);
Stream<List<CoverCandidate>> watchCoverCandidates(String pitId, {String? kind});   // kind 可為 'oshi'
// provider：cellCoversProvider(pitId)、coverCandidatesProvider((pitId, kind))（沿用，kind 'oshi' 直接可用）
```

- **儲存（自行判斷，見回報）**：官方圖冊／好看同人圖沿用既有的 `Pits.officialCoverId`／`fanArtCoverId`（存**圖片列 id**；
  預覽頁的「設為封面」`setOfficialCover`／`setFanArtCover` 設的就是同一份）。草稿／腦洞／成圖／推活是**新欄位存圖片檔名**
  （`draftCoverFile` 等），因為 `EntityImages` 的列 id 是各裝置自己產生的、不會同步，檔名才是跨裝置穩定的。
  欄位跟著**坑的文件**同步（`PitsKind`），setCellCover 會更新坑的 updatedAt。
- `setCellCover`：`imageId` 必須是 `watchCoverCandidates(pitId, kind: kind)` 給的候選圖 id（這個坑、這一格、未刪除、未被移走），
  否則 `ArgumentError`（`kind` 不在 `cellKinds` 也是）；null＝清除（回到自動）。
- **有效性與退回**：`watchCellCovers` 每次都重新驗證——指定的圖不存在／已刪除／被移到別格或別坑／所屬紀錄已刪除／圖片已從紀錄拿掉，
  就**自動退回該格最新一張**（圖又回來就恢復，因為設定值沒被清掉）。
  「最新」：官方／同人圖＝updatedAt 最晚；草稿／腦洞＝最新一筆（date）的第一張；成圖＝最新成圖（finishedAt）的第一張；
  **推活＝最新一筆（date，同日 createdAt）的第一張**。格子沒有可顯示的圖＝null（顯示 icon）。
- 候選圖（`CoverCandidate`）新增 `kind`／`durationMs`／`poster`／`staticFile`；entity 圖現在會排除已軟刪除的列
  （舊版沒排除，屬 bug）。`kind: 'oshi'` ＝坑內每一筆**未刪除**推活紀錄的每一張圖（紀錄日期新到舊，紀錄內依 sortOrder）。
  `kind == null`（坑封面用）**不含推活**。
- 覆蓋範圍外：UI 的 `CoverPickPage` 長按格子目前呼叫的是 `setCover`——要改成 `setCellCover(pitId, kind, id)`，並用
  `chosenCellCoverId` 標出目前封面（UI 工程師的事）。

## 3. 媒體（D-080）— `media.dart`、`image_store.dart`、`media_queries.dart`

```dart
enum MediaKind { image, gif, video }            // tables.dart，經 database.dart 匯出
MediaKind mediaKindFromBytes(List<int> head)?    // magic bytes；認不出 null
MediaKind mediaKindFromExtension(String name)    // 不認得＝image
MediaKind detectMediaKind(String name, List<int> head)   // 內容優先，再看副檔名
extension MediaKindX on MediaKind { isImage/isGif/isVideo/needsPoster; static MediaKind parse(String?) }
String? staticFileOf(MediaKind kind, String file, String? posterFile)  // 靜態圖：影片＝poster（沒有＝null）
```

- 判斷規則：GIF＝`GIF87a`／`GIF89a`；影片＝ISO 基礎媒體檔（`ftyp`，**排除 heic/heix/mif1/avif 等圖片 brand**；涵蓋 mp4／mov／m4v／3gp）、
  舊式 QuickTime（`moov`／`mdat`／`wide`／`free`）、EBML（webm／mkv）；JPEG／PNG／WebP／BMP＝圖片。
  副檔名（影片：mp4 mov m4v webm 3gp 3gpp mkv；gif）只在內容認不出來時才用。`MediaKindX.parse` 對不認得的字串（較新版 App 的新種類）回 `image`。

### NewImage / ImageRef
```dart
NewImage({required file, width=0, height=0, MediaKind kind=image, int? durationMs, String? posterFile});  // + copyWith
ImageRef(file, width, height, {kind=image, durationMs, poster});   // isVideo / isGif / staticFile / toNewImage()
ImageRef entityImageRef(EntityImage r);
```
- 所有 `addOfficial`／`addFanArts`／`addJunk`／`addMaterials`／`saveIdea`／`saveDraft`／`savePiece`／`saveOshiRecord` 的 `NewImage` 都會存 kind／durationMs／posterFile；
  跨格、跨坑移動（`moveAlbumImages`）也會帶過去。
- 腦洞／草稿／成圖／推活的 `ImageRef` 現在帶 kind／durationMs／poster。官方圖／同人圖／雜物／素材庫讀的是 drift 資料列，
  欄位直接是 `row.kind`／`row.durationMs`／`row.posterFile`。
- **`replaceEntityImages`（編輯表單送回舊圖）**：舊圖只帶檔名與寬高時，媒體欄位**不會被洗掉**——只有新資料有資訊
  （`kind != image`、`durationMs`／`posterFile` 非 null）才覆寫。表單也可以直接用 `ref.toNewImage()` 原樣送回。
- **需要靜態圖的地方已改用 `staticFileOf`**（影片用截圖、沒截圖的影片跳過改選下一張）：`watchCellCovers`、`imageFileOf`（坑封面）、
  `watchMonthCovers`（月曆格）、`pieceImagesByMonth`／年度回顧候選（`ReviewMonthPiece.file`）、`TimelineItem.files`／`file`。
  `TimelineItem` 新增 `media: List<ImageRef>`（完整媒體資訊，含影片）。`IncomeEntry.cover` 是 `ImageRef`，請用 `cover.staticFile`。

### ImageStore
```dart
Future<NewImage> import(XFile source);                       // 判斷 kind；原檔照搬不轉檔
Future<NewImage> importMedia(XFile source, {int? width, int? height, int? durationMs, Uint8List? posterBytes, String posterExt = 'jpg'});
Future<String>   savePoster(Uint8List bytes, {String ext = 'jpg'});   // 截圖存成獨立檔，回傳檔名
```
- `import` 先看內容再看副檔名；副檔名保留（無或 >6 字元時：圖片 `.jpg`、GIF `.gif`、影片 `.mp4`）。圖片與 GIF 讀寬高（GIF 取第一格）；
  副檔名是影片的檔案先讀開頭判斷、再以**串流複製**（不整個讀進記憶體；沒有副檔名的影片才會整個讀進記憶體），寬高 0、`durationMs`／`posterFile` null。
- UI 探測影片（寬高、長度、第一格）後可一次用 `importMedia(...)` 帶入；或先 `import`、之後補：

```dart
Future<void> setMediaMeta(String file, {int? width, int? height, int? durationMs, String? posterFile});   // media_queries.dart
Future<List<String>> videosWithoutPoster();    // 還沒有截圖的影片檔名（未刪除、去重）
```
  `setMediaMeta` 更新**所有**用到該檔名的列，並更新列（或所屬紀錄）的 updatedAt，下次同步才會把新欄位與截圖送出。
  副作用：官方圖／同人圖列的 updatedAt 變新（排序上會浮到「最新」）。

### 同步（向後相容）
- 文件欄位：官方／同人圖／雜物／素材庫文件多 `kind`／`durationMs`／`posterFile`；腦洞／草稿／成圖／推活文件的 `images[]` 每項多這三個鍵；
  坑文件多四個格子封面欄位。**`formatVersion` 沒有提高**。
- 舊版 App：讀不認得的鍵會忽略（drift 的 `fromJson` 本來就是這樣）；它不知道截圖，所以不下載截圖檔——影片在舊版看起來是一個圖片檔。
  注意：舊版重新上傳文件時不帶新欄位（last-write-wins），可能把影片資訊／格子封面清掉；新版收到沒有 `kind` 的文件時
  **依副檔名推**（.gif→gif、影片副檔名→video，其餘 image），不認得的 `kind` 字串同樣處理，所以不丟例外、不會把 GIF 變回靜態圖；
  缺 `posterFile`／`durationMs` 就是 null（`videosWithoutPoster()` 可重新補）。
- 檔案：截圖與原檔一樣是 `images__<檔名>`，進同一份傳輸計畫（`imageFiles(data)` 回傳原檔＋截圖）、進度、缺檔補下載（`_referencedImages` 包含 posterFile）。
  影片上傳目前仍是整檔讀進記憶體再送（沿用圖片的路徑）；大影片的串流上傳與「只在 Wi-Fi 上傳」開關（〔待評估〕）尚未做。
- 測試：`test/batch10_sync_test.dart`。

## 4. 推活多選（D-079）— `oshi_queries.dart`、`batch_tag_queries.dart`

```dart
Future<void> setOshiGroupBatch(Iterable<String> ids, String? groupId);   // null＝不分組
Future<void> deleteOshiBatch(Iterable<String> ids);                      // 軟刪除

// 批量 tag 的通用版（舊的 AlbumCell 版本保留，行為不變，內部改為呼叫這組）
Future<List<TagCoverageEntry>>         tagCoverageFor(TagTarget target, Iterable<String> ids);
Stream<List<TagCoverageEntry>>         watchTagCoverageFor(TagTarget target, Iterable<String> ids);
Future<List<String>>                   applyBatchTagsFor(TagTarget target, Iterable<String> ids,
    {addTagIds, removeTagIds, newTagNames});
```
- `target` 支援 `official`／`fanArt`／`oshi`（推活時 `ids` 是**推活紀錄 id**）；其他丟 `ArgumentError`。語意與 D-060 完全相同
  （none／some／all 三態、`#` 前綴去掉、新 tag 同名重用、同坑檢查、錯誤整批回滾）；有實際變動的推活紀錄更新 updatedAt（tag 隨紀錄文件同步）。
- `setOshiGroupBatch`：`groupId` 必須是**未刪除的推活分組（kind=oshi），且每筆紀錄都屬於同一個坑**，否則 `ArgumentError`、整批不動；
  只有分組真的改變的紀錄更新 updatedAt（已在目標分組的不動）；已刪除／不存在的 id 略過；空清單無事。
- `deleteOshiBatch`：同 `deleteOshiRecords`，但只處理未刪除的（不重複蓋 updatedAt）。圖片與 tag 關聯保留；被刪紀錄的圖若是推活格封面，封面自動退回。
- 多選畫面的資料來源仍是 `watchOshiRecords`；全選／已選 N 筆是 UI 狀態。
- 測試：`test/batch10_test.dart`。

## 5. 刻意的行為改變

- `CellCovers` 多一個 `oshi`（舊程式不受影響，建構子參數都是具名可省略）；`watchCellCovers` 現在也驗證官方／同人圖封面屬於這個坑。
- `watchCoverCandidates`／格子封面不再列出已軟刪除的 entity 圖（舊版會列，屬 bug）。
- `applyBatchTags`／`tagCoverage` 改為薄包裝（`async`，不支援的格子仍以失敗的 Future 丟 `ArgumentError`）。
- 既有測試沒有需要更新的。`AppDatabase.schemaVersion = 9`。

## 6. 給 UI 的銜接

- 影片寬高／長度／第一格截圖需要原生外掛（video_player／影片縮圖）：匯入後呼叫 `importMedia(..., durationMs:, posterBytes:)`，
  或 `import` 後再 `setMediaMeta`；App 啟動／同步後可用 `videosWithoutPoster()` 補產生（另一台匯入、本機還沒有截圖時）。
- 要顯示縮圖／封面一律用 `ImageRef.staticFile`／`CoverCandidate.staticFile`／`staticFileOf`；GIF 的 `staticFile` 是檔案本身（Flutter 解碼出第一格；
  列表要播放才用 `Image.file` 的動畫）。
- 既有 UI 表單用 `NewImage(file:, width:, height:)` 重建舊圖時不會破壞媒體欄位（見 `replaceEntityImages`），但新圖請用 `import`／`importMedia` 的回傳值。

## 7. iPad：參考圖檢視的檢視狀態（schema v10）

純本機、**不同步**的表 `RefViewStates`（`lib/data/ref_view_queries.dart`；沒有 SyncColumns、不進 Outbox，同步引擎不認得它）。
鍵是圖片檔名；存縮放（相對 fit 的倍數 `zoom`、絕對縮放 `scale`）、視窗中央對到的圖片位置（`centerX`/`centerY`，0～1）、
`locked`（鎖定縮放）、`flipped`、`gray`、`lightBg`。翻轉／灰階／背景只是檢視狀態，不改原圖檔。

```dart
Future<RefViewSnapshot?>             getRefViewState(String imageFile);
Future<Map<String, RefViewSnapshot>> getRefViewStates(Iterable<String> imageFiles);
Future<void>                         saveRefViewState(String imageFile, RefViewSnapshot s);  // upsert
Future<void>                         deleteRefViewState(String imageFile);
```
- 遷移 v9 → v10：`createTable(refViewStates)`，無舊資料要回填。`AppDatabase.schemaVersion = 10`。
- UI 端的暫存與 debounce 存檔見 `lib/ui/reference/ref_view_store.dart`；測試 `test/reference/ref_view_db_test.dart`。

## 批次 14：淺坑／封存坑（D-088，schema v11）

檔案：`lib/data/tables.dart`（`PitStatus`、`PitSectionKey`、`Pits` 新欄位）、`lib/data/pit_status_queries.dart`
（`PitX`、`PitStatusQueries`、`PitSectionHasContent`；`database.dart` 已 export）。測試：`test/pit_status_test.dart`、`test/migration_test.dart`（v1～v10 → v11）。

### 資料模型
```dart
enum PitStatus { active, shallow, archived }                               // 資料庫存名稱
enum PitSectionKey { official, fan, idea, draft, piece, oshi, junk }       // 格子；名稱同 setCellCover 的 kind 字串
Pit.status            // PitStatus，預設 active（取代 archived bool）
Pit.enabledSections   // Set<PitSectionKey>，只對淺坑有意義；text 欄位存逗號分隔名稱（'official,fan'），預設空＝全關
Pit.coverFile         // String?  淺坑自己的封面（從相簿直接選的圖檔名）；有值時優先於 coverImageId
```
- `Pit` 擴充（`PitX`）：`isActive`／`isShallow`／`isArchived`、`archived`（相容讀法＝封存）、
  `openSections`（淺坑＝`enabledSections`；現坑／封存坑＝六格＋雜物開關開著時的 `junk`）、`sectionOpen(PitSectionKey)`。
- **`junkEnabled` 與淺坑的 `junk` 格保持一致**（寫入時一起更新；舊版 App 只認得 `junkEnabled`），所以既有的 `pit.junkEnabled` 判斷對淺坑照樣正確。
- `coverFile`：`setPitCoverFile(pitId, file?)` 設定；`setCover`（現坑從坑內挑封面）會把它清掉。`coverFileProvider` 先看 `coverFile` 再看 `coverImageId`。檔案隨坑文件同步（上傳／下載）。

### 遷移 v10 → v11
`status`／`enabled_sections`／`cover_file` 三欄新增；`archived = 1` → `status = 'archived'`，其餘 `'active'`；舊的 `archived` 欄位以重建資料表移除
（其餘欄位原樣搬過去）。任何舊版本（v1～v10）升上來都走同一條路（缺的欄位一律補上），可重複執行。不改 `updated_at`（各裝置各自升級結果相同）。

### 同步（kind `pits`，向下相容）
- 寫出：文件 = `Pit.toJson()`（含 `status`、`enabledSections`、`coverFile`）**另加相容的 `archived`（bool，＝封存坑）**。舊版 App 忽略不認得的欄位，仍讀得到 `archived`。
- 讀入：沒有 `status`（舊版 App 的文件）或 `status` 認不得（未來的新類型）→ 由 `archived` 推（true→封存，false→現坑）。
  例外：本機是淺坑、而文件 `archived == false` 且沒有 `status`（舊版 App 只是改了名稱等）→ **保留淺坑與格子設定**。
- `enabledSections` 缺 key → 空集合。

### 清單與選擇清單
```dart
Stream<List<Pit>> watchPitsByStatus(Set<PitStatus> statuses);   // 依最後更新排序；主頁三個分頁各用一個
Stream<List<Pit>> watchSelectablePits();                        // 現坑＋淺坑，不含封存坑
Future<Set<String>> archivedPitIds();
watchPits({required bool archived})                             // 相容：true＝封存坑，false＝現坑（不含淺坑）
```
Providers：`pitsByStatusProvider(PitStatus)`、`selectablePitsProvider`（分享匯入、圖片移動、新增目標、日頁新增的坑清單用它）、`pitsProvider(bool)`（相容）、
`pitCoverPickerProvider`（淺坑封面的單張選圖，預設同頭像選圖器）。
- 分享匯入／圖片移動：淺坑列出，但只開放它開啟的格子（`pit.sectionOpen(...)`）；封存坑不列。
- 目標：`GoalView.progress` **不計封存坑的內容**（腦洞／摸魚／成圖）；新增目標的坑選擇不列封存坑。淺坑照常計入。

### 轉換與格子開關
```dart
Future<void> setPitStatus(String pitId, PitStatus status,
    {Set<PitSectionKey>? enabledSections, bool? junkEnabled, bool deleteClosedContent = false});
Future<void> setPitSectionEnabled(String pitId, PitSectionKey section, bool enabled, {bool deleteContent = false});
Future<void> savePit(String id, {required String name, String? description, PitStatus? status,
    Set<PitSectionKey>? enabledSections, bool? junkEnabled, bool deleteClosedContent = false});   // 編輯坑一次存檔
Future<void> updatePit(...)   // 舊簽名保留（archived 相容參數）＋ status／enabledSections／deleteClosedContent，委派給 savePit
Future<String> createPit({..., PitStatus status = active, Set<PitSectionKey> enabledSections = const {}, String? coverFile});
```
轉換規則：
- **淺坑→坑**：六格全開，資料保留；`enabledSections` 清空；雜物沿用淺坑的雜物格（`junkEnabled`）。
- **坑→淺坑**：沒給 `enabledSections` 時，預設 = 有資料的格子（雜物開關開著也算）。
- **任何→封存**：資料全保留（不刪、不隱藏列），只是從選擇清單、目標進度排除；淺坑封存時 `enabledSections` 保留，封存→淺坑還原；現坑封存沒有格子設定（轉淺坑時依資料推）。可再轉回任何類型。
- **關閉有內容的格子**（`setPitSectionEnabled(..., false)`，或轉成淺坑時某個原本開著、現在關掉的格子有內容）：
  內容**軟刪除**（沿用 `deleteOfficial`／`deleteFanArts`／`deleteJunk`／`deleteIdeas`／`deleteDrafts`／`deletePieces`／`deleteOshiRecords`，連帶清格子封面）；
  沒帶 `deleteContent`／`deleteClosedContent: true` 就丟 `PitSectionHasContent(counts)`、**整個操作不生效**。UI 先彈確認框，同意後帶旗標。
  官方圖冊的分組（結構）不刪。
- 非淺坑呼叫 `setPitSectionEnabled`：只有 `junk` 可以（等同雜物開關，**不刪內容**）；其他丟 `ArgumentError`。
- 所有寫入都更新 `updatedAt`，隨坑文件同步；刪除的內容列是軟刪除，會同步出去。

### 計數（確認框文字用）
```dart
Future<int> sectionContentCount(String pitId, PitSectionKey section);        // 未刪除、未隱藏
Future<Map<PitSectionKey, int>> sectionContentCounts(String pitId);          // 只列 > 0 的
```
單位：official／fan／junk＝圖片張數；idea＝腦洞數；draft＝摸魚數；piece＝成圖數；oshi＝推活筆數。
確認框：「格子入面的 N 張圖（或 N 個腦洞／摸魚…）會一併刪除，無法復原」。

## 批次 15：官方圖冊 tag（D-089，不改 schema，維持 v11）

官方圖的 tag 一直存在 `TagLinks`（`TagTarget.official`）、同步文件有 `tagIds`（舊文件沒有該欄＝不動本機 tag），所以**沒有遷移**。本批補齊讀取、編輯、篩選與搜尋：

```dart
Stream<List<OfficialImage>> watchOfficial(String pitId, {String? groupId, String? tagId});   // tagId：只列有該 tag 的
Future<void> updateOfficial(String id, {required String groupId, required List<String> tagIds}); // 編輯一次存分組＋tag，更新 updatedAt
// 既有：addOfficial(..., tagIds:)、setOfficialTags、watchTagIds(TagTarget.official, id)、
//       tagCoverage/applyBatchTags(AlbumCell.official, ...)（OfficialSelect 的批量 tag）
```
- Provider：`officialFilteredProvider((pitId, groupId?, tagId?))`。tag 名稱仍用 `tagIdsProvider((TagTarget.official, id))` + `tagsProvider(pitId)`。
- 搜尋：`PitSearchSection.official`、`PitSearchResult.official`（`PitSearchGroup<OfficialImage>`，缺省＝空）。分段順序：成圖 → **官方圖冊** → 好看同人圖 → 推活 → 草稿 → 腦洞。
  比對欄位＝分組名稱＋tag 名稱；`tagId` 要求有該 tag；已刪除、隱藏（被移走）的不算。`total`、`counts`、`visibleSections` 都含官方圖。
- 常用 tag 計數（`watchTagUsage`）本來就含官方圖（只算未刪除、未隱藏）。
- 測試：`test/batch15_test.dart`。

## 批次 17：縮圖機制與同步進度行（D-099，**不改 schema，維持 v11**）

縮圖是檔案層的快取，不進資料庫：「Drive 上有沒有 `thumbs__…`」本身就是遷移進度，所以不需要新欄位，也沒有 drift migration。

### 遠端命名（扁平命名空間）
- `thumbs__{主檔名}.jpg`：縮圖（長邊 480px、JPEG 品質 80，約 30KB）。主檔名＝圖片檔名去掉副檔名（uuid）；`thumbRemoteName(file)`。
- GIF 用第一格；影片原檔不做縮圖（它的 `poster` 是另一張 jpg，有自己的縮圖）。舊版裝置不產縮圖、舊 meta 不需要新欄位：新版遇到沒有縮圖的圖照常運作。

### 本機（`ImageStore`，`<images>/thumbs/`）
```dart
File thumbFileOf(name)            // <主檔名>.jpg      正式縮圖
File tempThumbFileOf(name)        // <主檔名>.tmp.jpg  暫用縮圖（Drive thumbnailLink 備援）
bool hasRealThumb(name); bool hasTempThumb(name); bool hasThumb(name)
File? thumbFileFor(name)          // 正式優先，其次暫用，沒有 null
bool thumbFailed(name)            // <主檔名>.skip：產生不了縮圖，不再重試
Future<void> saveThumb(name, bytes)       // 寫正式縮圖並刪暫用的
Future<void> saveTempThumb(name, bytes)   // 已有正式的就不寫
Future<void> markThumbFailed(name)
Future<void> loadThumbIndex()     // 啟動時掃一次，之後 hasThumb 等是記憶體查詢（imageStoreProvider 已做）
Stream<int> watchThumb(name)      // 縮圖變動時遞增；providers: thumbVersionProvider(file)
```
顯示優先順序（`StoredImage`）：本機縮圖 → 本機原圖 → 占位。`cacheWidth` ≤ 480 且不是動畫 GIF 時才讀縮圖；詳情／全螢幕預覽（沒給 cacheWidth 或更大）讀原圖。原圖還沒下載但縮圖已到時，格子顯示縮圖並照舊蓋淡色＋下載角標。

### 同步引擎（`SyncEngine`）
順序：拉 meta → 規劃傳輸清單 → **下載全部縮圖**（`syncThumbConcurrency`＝6 並行；階段 `SyncStage.downloadingThumbs`，進度 `thumbsDone/thumbsTotal`，SyncFirst 顯示「縮圖 N / M」）→ 下載原圖（最多 `syncDownloadConcurrency`＝3 張同時）→ 上傳（**每張原圖先傳縮圖再傳原圖**，縮圖失敗只記錄）→ 補縮圖。

- **舊資料補縮圖**（一次性遷移）：本機有原圖、Drive 沒有 `thumbs__` 的，由這台裝置產生並上傳；每次同步最多 `syncThumbBackfillLimit`＝40 張（限速）。以 Drive 上有沒有該檔為準，所以可中斷續傳、不重複上傳；產生不了的（壞檔）標 `.skip` 不再重試。
- **thumbnailLink 備援**：雲端沒有縮圖、本機也沒有原圖的，用 `ThumbnailFallbackRemote.fallbackThumbnail(遠端檔名)`（`DriveRemote`：`files.get?fields=thumbnailLink`，尺寸改 `=s480`，兩個請求都帶登入 token）取得暫用縮圖存成 `.tmp.jpg`。每次同步最多 `syncThumbFallbackLimit`＝150 張；連結過期、失敗一律回 null，只有授權過期（401 刷新失敗）才丟 `SyncAuthException`。正式縮圖到了就取代。
- 縮圖階段連續兩批（各 6 張）全失敗就放棄這個階段（不擋原圖）。
- 引擎參數：`thumbnails`（`ThumbnailMaker`，測試可換）、`downloadConcurrency`、`thumbBackfillLimit`、`thumbFallbackLimit`。
- `SyncResult`：`thumbsDown`／`thumbsFallback`／`thumbsUp`／`thumbFailures`。`SyncState`：`thumbsDone`／`thumbsTotal`／`hasThumbProgress`。

### 縮圖產生（`lib/media/thumbnail_maker.dart`）
`DefaultThumbnailMaker`：引擎解碼並直接縮小（`ImageDescriptor.instantiateCodec(targetWidth/Height)`，不把整張大圖解成 RGBA，也處理 EXIF 方向、GIF 取第一格）→ 純 Dart `image` 套件在 isolate（`compute`）編成 JPEG 80（透明鋪白底）→ 引擎解不了時退回純 Dart 解碼。壞檔回傳 null。新增依賴 `image: ^4.3.0`。

### 同步進度行（`lib/data/sync_row_info.dart`、`lib/state/sync_row_info.dart`）
```dart
Future<Map<String, SyncRowInfo>> AppDatabase.syncRowInfos(Iterable<String> files)
```
一次批次查一批圖片檔名所屬的實體（每張表一個 `IN (...)` 查詢，再各一次批次查標題與坑名，不逐張查）。優先順序：官方圖冊 → 好看同人圖 → 雜物 → 素材庫 → 成圖 → 摸魚 → 腦洞 → 推活 → 坑封面；已刪除、隱藏、擁有者已刪除的不算；影片的 poster 檔對應到同一個實體。`SyncRowInfo`：`kind`、`pitName`、`title`（腦洞／摸魚／成圖／推活，空白不算）、`materialCategory`、`posterFile`。
`syncRowInfoProvider`（Notifier）快取查過的檔名，`ensure(files)` 只批次查還沒查過的。
同步 sheet／popover（共用 `SyncProgressRows`）：`pickSyncRows` 取「傳輸中最多 3 張在前、等待中接著、合計最多 4 行」，其餘寫「還有 N 張等待中」；傳完的行淡出（280ms）後下面補上。
