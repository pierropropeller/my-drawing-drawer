import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

const uuid = Uuid();

/// 所有可同步實體共用欄位（HANDOFF 第 3 節）。
mixin SyncColumns on Table {
  TextColumn get id => text().clientDefault(() => uuid.v4())();
  DateTimeColumn get createdAt => dateTime().clientDefault(DateTime.now)();
  DateTimeColumn get updatedAt => dateTime().clientDefault(DateTime.now)();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  TextColumn get deviceId => text().withDefault(const Constant(''))();

  @override
  Set<Column> get primaryKey => {id};
}

/// 媒體種類（D-080，HANDOFF 3.13）。資料庫存的是名稱（`image`／`gif`／`video`）；新值只能加在最後。
enum MediaKind { image, gif, video }

/// 所有放圖的表共用的媒體欄位（D-080）：官方圖、同人圖、雜物、素材庫、腦洞／草稿／成圖／推活圖。
/// 舊資料一律是 `image`（遷移時副檔名為 .gif 的回填成 `gif`），影片欄位為 null。
mixin MediaColumns on Table {
  TextColumn get kind =>
      textEnum<MediaKind>().withDefault(const Constant('image'))();

  /// 影片長度（毫秒）；只有影片有值，圖片與 GIF 為 null。
  IntColumn get durationMs => integer().nullable()();

  /// 影片第一格的截圖檔名（與 imageFile 同一個圖片資料夾，也同步）；
  /// 影片剛匯入、尚未產生截圖時為 null。圖片與 GIF 不使用。
  TextColumn get posterFile => text().nullable()();
}

enum GoalPeriod { year, month }

enum GoalKind { idea, draft, piece }

/// 圖片附屬於哪種實體。
enum OwnerType { idea, draft, piece, oshi }

/// 標籤掛在哪種實體上（v7 起官方圖也能有 tag，D-060；推活紀錄 D-057）。
/// 新值只能加在最後（資料庫存的是名稱，順序無關，但保持習慣）。
enum TagTarget { fanArt, idea, draft, piece, goal, official, oshi }

/// 坑的類型（D-088）。資料庫存名稱（`active`／`shallow`／`archived`）；新值只能加在最後。
/// 取代舊的 `Pits.archived`（bool）。
enum PitStatus { active, shallow, archived }

/// 坑內可以開關的格子（淺坑的「開啟的格子」，D-088）。資料庫存名稱；
/// 順序＝介面顯示順序（官方圖冊、好看同人圖、我的腦洞、我的摸魚、我的成圖、推活、雜物）。
/// 名稱同 `setCellCover`／`coverCandidatesProvider` 用的格子種類字串。
enum PitSectionKey { official, fan, idea, draft, piece, oshi, junk }

/// `Set<PitSectionKey>` ⇄ 逗號分隔的名稱字串（`official,fan`）。
/// 讀回時略過不認得的名稱（較新版 App 的新格子），輸出固定依宣告順序，方便比較與同步。
class PitSectionSetConverter extends TypeConverter<Set<PitSectionKey>, String>
    with JsonTypeConverter2<Set<PitSectionKey>, String, String> {
  const PitSectionSetConverter();

  @override
  Set<PitSectionKey> fromSql(String fromDb) => {
    for (final n in fromDb.split(','))
      for (final k in PitSectionKey.values)
        if (k.name == n.trim()) k,
  };

  @override
  String toSql(Set<PitSectionKey> value) => [
    for (final k in PitSectionKey.values)
      if (value.contains(k)) k.name,
  ].join(',');

  @override
  Set<PitSectionKey> fromJson(String json) => fromSql(json);

  @override
  String toJson(Set<PitSectionKey> value) => toSql(value);
}

class Pits extends Table with SyncColumns {
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  TextColumn get coverImageId => text().nullable()();

  /// 坑內「官方圖冊」「好看同人圖」兩格各自的封面（預覽頁的「設為封面」設的是這裡）。
  /// 主頁坑卡片的封面是 [coverImageId]，由長按坑內頁的格子選擇。
  TextColumn get officialCoverId => text().nullable()();
  TextColumn get fanArtCoverId => text().nullable()();

  /// 坑內頁其餘四格（草稿／腦洞／成圖／推活）各自的封面（批次 10）。
  /// 存的是**圖片檔名**而不是圖片列 id：這幾種圖片列的 id 是各裝置自己產生的，不會同步，
  /// 檔名則是跨裝置穩定的。長按該格的「選擇封面」設的是這裡；
  /// 官方圖冊／好看同人圖兩格沿用上面兩個以圖片列 id 為準的欄位。
  TextColumn get draftCoverFile => text().nullable()();
  TextColumn get ideaCoverFile => text().nullable()();
  TextColumn get pieceCoverFile => text().nullable()();
  TextColumn get oshiCoverFile => text().nullable()();

  /// 坑的類型（D-088）：現坑／淺坑／封存坑。v11 起取代 `archived`（遷移：archived＝true → archived，其餘 active）。
  /// 同步文件另外帶一個相容用的 `archived` bool，舊版 App 才看得懂。
  TextColumn get status =>
      textEnum<PitStatus>().withDefault(const Constant('active'))();

  /// 淺坑開啟的格子（只有 [status]＝shallow 時有意義；封存的淺坑保留著，轉回淺坑時還原）。
  /// 逗號分隔的名稱，見 [PitSectionSetConverter]。預設全部關。
  TextColumn get enabledSections => text()
      .map(const PitSectionSetConverter())
      .withDefault(const Constant(''))();

  /// 淺坑自己的封面（從手機相簿直接選的圖，檔名；跟其他圖檔一起同步）。
  /// 有值時優先於 [coverImageId]；現坑的「選擇封面」會把它清掉。
  TextColumn get coverFile => text().nullable()();

  /// 編輯坑的「雜物」開關；開啟後坑內頁最底才出現雜物入口（D-034）。
  /// 淺坑：與 [enabledSections] 是否含 `junk` 保持一致（舊版 App 只看得到這個欄位）。
  BoolColumn get junkEnabled => boolean().withDefault(const Constant(false))();
}

/// 分組：官方圖冊的分組（kind=official）、好看同人圖的分組（kind=fan，預設是各出處）
/// 與推活的分組（kind=oshi，D-057）。
class OfficialGroups extends Table with SyncColumns {
  TextColumn get pitId => text()();
  TextColumn get kind => text().withDefault(const Constant('official'))();
  TextColumn get name => text()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}

class OfficialImages extends Table with SyncColumns, MediaColumns {
  TextColumn get pitId => text()();
  TextColumn get groupId => text()();
  TextColumn get imageFile => text()();
  IntColumn get width => integer().withDefault(const Constant(0))();
  IntColumn get height => integer().withDefault(const Constant(0))();

  /// 同一張圖在官方圖冊／好看同人圖／雜物之間移動時的身分（D-044）；
  /// 同一張圖在各格的列共用同一個 imageKey。舊資料回填成自己的 id。
  TextColumn get imageKey => text().withDefault(const Constant(''))();

  /// 移到別格後，原格的列會被隱藏（保留各格獨有的欄位，移回時恢復）。
  BoolColumn get hidden => boolean().withDefault(const Constant(false))();
}

class FanArts extends Table with SyncColumns, MediaColumns {
  TextColumn get pitId => text()();
  TextColumn get imageFile => text()();
  IntColumn get width => integer().withDefault(const Constant(0))();
  IntColumn get height => integer().withDefault(const Constant(0))();
  TextColumn get author => text().withDefault(const Constant(''))();

  /// 舊版的出處文字（v5 起改用 [groupId]，保留欄位以相容舊資料）。
  TextColumn get source => text().withDefault(const Constant(''))();
  TextColumn get groupId => text().nullable()();

  /// 同一張圖在官方圖冊／好看同人圖／雜物之間移動時的身分（D-044）；
  /// 同一張圖在各格的列共用同一個 imageKey。舊資料回填成自己的 id。
  TextColumn get imageKey => text().withDefault(const Constant(''))();

  /// 移到別格後，原格的列會被隱藏（保留各格獨有的欄位，移回時恢復）。
  BoolColumn get hidden => boolean().withDefault(const Constant(false))();
}

/// 雜物（D-034）：純圖，不計入目標、不出現在時間軸、不能當封面、不參與搜尋。
class JunkImages extends Table with SyncColumns, MediaColumns {
  TextColumn get pitId => text()();
  TextColumn get imageFile => text()();
  IntColumn get width => integer().withDefault(const Constant(0))();
  IntColumn get height => integer().withDefault(const Constant(0))();

  /// 同一張圖在官方圖冊／好看同人圖／雜物之間移動時的身分（D-044）；
  /// 同一張圖在各格的列共用同一個 imageKey。舊資料回填成自己的 id。
  TextColumn get imageKey => text().withDefault(const Constant(''))();

  /// 移到別格後，原格的列會被隱藏（保留各格獨有的欄位，移回時恢復）。
  BoolColumn get hidden => boolean().withDefault(const Constant(false))();
}

/// 素材庫的固定分類（D-071）。資料庫存的是名稱（穩定的英文 id），顯示文字由 UI 的 ARB 提供；
/// 新值只能加在最後。順序＝畫面上 pills 的順序（全部 → 服裝 → 姿勢 → 人體 → 色盤 → 場景 → 畫風 → 貼圖）。
enum MaterialCategory { clothing, pose, body, palette, scene, style, sticker }

/// 素材庫（D-071，HANDOFF 3.12）：畫畫參考圖，不屬於任何坑，只有圖與分類，沒有任何文字欄位。
/// 不計入目標、時間軸、搜尋、封面與坑統計。排序依 [createdAt]，新的在前。
class MaterialImages extends Table with SyncColumns, MediaColumns {
  TextColumn get imageFile => text()();
  IntColumn get width => integer().withDefault(const Constant(0))();
  IntColumn get height => integer().withDefault(const Constant(0))();
  TextColumn get category => textEnum<MaterialCategory>()();
}

class Tags extends Table with SyncColumns {
  TextColumn get pitId => text()();
  TextColumn get name => text()();
}

class Ideas extends Table with SyncColumns {
  TextColumn get pitId => text()();
  TextColumn get title => text()();
  TextColumn get body => text().withDefault(const Constant(''))();

  /// 使用者可改的日期（D-070）：列表排序、卡片時間、目標進度、時間軸都用它，不用 createdAt。
  /// 含時間（從目標日頁的 ＋ 新增時是「現在」）；舊資料回填成 createdAt。
  DateTimeColumn get date => dateTime().clientDefault(DateTime.now)();
}

class Drafts extends Table with SyncColumns {
  TextColumn get pitId => text()();
  TextColumn get title => text().nullable()();
  TextColumn get body => text().nullable()();

  /// 同 [Ideas.date]（D-070）。
  DateTimeColumn get date => dateTime().clientDefault(DateTime.now)();
}

class Pieces extends Table with SyncColumns {
  TextColumn get pitId => text()();
  TextColumn get title => text()();
  TextColumn get body => text().withDefault(const Constant(''))();
  IntColumn get targetLikes => integer().withDefault(const Constant(0))();
  IntColumn get actualLikes => integer().withDefault(const Constant(0))();
  DateTimeColumn get finishedAt => dateTime().clientDefault(DateTime.now)();

  /// 已公開發佈（D-046）。關閉時發佈日期、社交連結、互動量在 UI 隱藏（資料保留）。
  BoolColumn get isPublished => boolean().withDefault(const Constant(false))();
  DateTimeColumn get publishedAt => dateTime().nullable()();

  /// 商稿（D-046／D-050）。收款狀態由金額與已收金額推算，不儲存。
  BoolColumn get isCommission => boolean().withDefault(const Constant(false))();
  TextColumn get client => text().withDefault(const Constant(''))();
  RealColumn get amount => real().nullable()();
  TextColumn get currency => text().withDefault(const Constant('CNY'))();
  RealColumn get receivedAmount => real().withDefault(const Constant(0))();
  DateTimeColumn get dueAt => dateTime().nullable()();
}

/// 推活紀錄（D-057／D-062，HANDOFF 3.11）：與角色相處的足跡，不屬於創作線。
/// 圖片放 [EntityImages]（ownerType=oshi），tag 放 [TagLinks]（target=oshi）。
class OshiRecords extends Table with SyncColumns {
  TextColumn get pitId => text()();

  /// 日期（只有年月日，存當天 00:00）。
  DateTimeColumn get date => dateTime()();

  /// 推活分組（[OfficialGroups] kind=oshi）；可不分組。
  TextColumn get groupId => text().nullable()();
  TextColumn get title => text().nullable()();
  TextColumn get description => text().nullable()();
}

/// 腦洞／草稿／成圖／推活的多張圖片。
class EntityImages extends Table with SyncColumns, MediaColumns {
  TextColumn get ownerType => textEnum<OwnerType>()();
  TextColumn get ownerId => text()();
  TextColumn get imageFile => text()();
  IntColumn get width => integer().withDefault(const Constant(0))();
  IntColumn get height => integer().withDefault(const Constant(0))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}

class PieceLinks extends Table with SyncColumns {
  TextColumn get pieceId => text()();
  TextColumn get platform => text()();
  TextColumn get url => text()();
}

/// 多對多：tag 與各實體。
class TagLinks extends Table {
  TextColumn get tagId => text()();
  TextColumn get targetType => textEnum<TagTarget>()();
  TextColumn get targetId => text()();

  @override
  Set<Column> get primaryKey => {tagId, targetType, targetId};
}

/// 多對多連接：腦洞—草稿。
class IdeaDrafts extends Table {
  TextColumn get ideaId => text()();
  TextColumn get draftId => text()();

  @override
  Set<Column> get primaryKey => {ideaId, draftId};
}

/// 多對多連接：腦洞—成圖。
class IdeaPieces extends Table {
  TextColumn get ideaId => text()();
  TextColumn get pieceId => text()();

  @override
  Set<Column> get primaryKey => {ideaId, pieceId};
}

/// 多對多連接：草稿—成圖。
class DraftPieces extends Table {
  TextColumn get draftId => text()();
  TextColumn get pieceId => text()();

  @override
  Set<Column> get primaryKey => {draftId, pieceId};
}

class Goals extends Table with SyncColumns {
  TextColumn get period => textEnum<GoalPeriod>()();
  IntColumn get year => integer()();
  IntColumn get month => integer().nullable()();
  TextColumn get name => text().nullable()();
  TextColumn get kind => textEnum<GoalKind>()();
  IntColumn get count => integer()();
  TextColumn get pitId => text().nullable()();
  IntColumn get requireLikes => integer().nullable()();
}

/// 年度回顧每月精選圖；排版設定以 key/value 存於 [ReviewSettings]。
class YearReviewMonths extends Table {
  IntColumn get year => integer()();
  IntColumn get month => integer()();
  TextColumn get imageFile => text().nullable()();
  DateTimeColumn get updatedAt => dateTime().clientDefault(DateTime.now)();

  @override
  Set<Column> get primaryKey => {year, month};
}

class ReviewSettings extends Table {
  IntColumn get year => integer()();
  IntColumn get columns => integer().withDefault(const Constant(4))();
  TextColumn get ratio => text().withDefault(const Constant('1:1'))();
  TextColumn get monthFormat => text().withDefault(const Constant('Jan'))();
  BoolColumn get monthOnImage => boolean().withDefault(const Constant(true))();

  /// 月份對齊（D-039）：`start`／`center`／`end`；null＝預設（月份在圖上＝靠左，在空白位置＝置中）。
  TextColumn get monthAlign => text().nullable()();

  /// 同步用的版本時間；舊資料為 null。
  DateTimeColumn get updatedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {year};
}

/// 使用者資料（暱稱、頭像；同步）。單例，id 固定為 'me'；以 [updatedAt] 做 last-write-wins。
/// 頭像檔跟其他圖片一樣放在圖片資料夾，檔名記在 [avatarFile]。
class UserProfiles extends Table {
  TextColumn get id => text()();
  TextColumn get nickname => text().withDefault(const Constant(''))();
  TextColumn get avatarFile => text().nullable()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 待上傳到 Google Drive 的變更佇列（第 4 節）。
class Outbox extends Table {
  IntColumn get seq => integer().autoIncrement()();
  TextColumn get entity => text()();
  TextColumn get entityId => text()();
  TextColumn get op => text()(); // upsert / delete
  DateTimeColumn get queuedAt => dateTime().clientDefault(DateTime.now)();
}

/// 已同步到遠端的文件版本（以 updatedAt 比較，last-write-wins）。
class SyncDocs extends Table {
  TextColumn get kind => text()();
  TextColumn get id => text()();
  IntColumn get updatedAtMs => integer()();
  TextColumn get remoteModified => text().withDefault(const Constant(''))();

  @override
  Set<Column> get primaryKey => {kind, id};
}
