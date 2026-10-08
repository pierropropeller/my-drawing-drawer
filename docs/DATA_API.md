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
