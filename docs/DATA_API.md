# 資料層 API 參考（schema v6）

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
- `createPit({name, description, bool junkEnabled = false})`
- `updatePit(id, {name, description, archived, bool? junkEnabled})` — `junkEnabled` 不傳＝不變。
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
