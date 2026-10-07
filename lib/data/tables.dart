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

enum GoalPeriod { year, month }

enum GoalKind { idea, draft, piece }

/// 圖片附屬於哪種實體。
enum OwnerType { idea, draft, piece }

/// 標籤掛在哪種實體上（官方圖沒有 tag）。
enum TagTarget { fanArt, idea, draft, piece, goal }

class Pits extends Table with SyncColumns {
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  TextColumn get coverImageId => text().nullable()();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
}

class OfficialGroups extends Table with SyncColumns {
  TextColumn get pitId => text()();
  TextColumn get name => text()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}

class OfficialImages extends Table with SyncColumns {
  TextColumn get pitId => text()();
  TextColumn get groupId => text()();
  TextColumn get imageFile => text()();
  IntColumn get width => integer().withDefault(const Constant(0))();
  IntColumn get height => integer().withDefault(const Constant(0))();
}

class FanArts extends Table with SyncColumns {
  TextColumn get pitId => text()();
  TextColumn get imageFile => text()();
  IntColumn get width => integer().withDefault(const Constant(0))();
  IntColumn get height => integer().withDefault(const Constant(0))();
  TextColumn get author => text().withDefault(const Constant(''))();
  TextColumn get source => text().withDefault(const Constant(''))();
}

class Tags extends Table with SyncColumns {
  TextColumn get pitId => text()();
  TextColumn get name => text()();
}

class Ideas extends Table with SyncColumns {
  TextColumn get pitId => text()();
  TextColumn get title => text()();
  TextColumn get body => text().withDefault(const Constant(''))();
}

class Drafts extends Table with SyncColumns {
  TextColumn get pitId => text()();
  TextColumn get title => text().nullable()();
  TextColumn get body => text().nullable()();
}

class Pieces extends Table with SyncColumns {
  TextColumn get pitId => text()();
  TextColumn get title => text()();
  TextColumn get body => text().withDefault(const Constant(''))();
  IntColumn get targetLikes => integer().withDefault(const Constant(0))();
  IntColumn get actualLikes => integer().withDefault(const Constant(0))();
  DateTimeColumn get finishedAt => dateTime().clientDefault(DateTime.now)();
}

/// 腦洞／草稿／成圖的多張圖片。
class EntityImages extends Table with SyncColumns {
  TextColumn get ownerType => textEnum<OwnerType>()();
  TextColumn get ownerId => text()();
  TextColumn get imageFile => text()();
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

  @override
  Set<Column> get primaryKey => {year};
}

/// 待上傳到 Google Drive 的變更佇列（第 4 節）。
class Outbox extends Table {
  IntColumn get seq => integer().autoIncrement()();
  TextColumn get entity => text()();
  TextColumn get entityId => text()();
  TextColumn get op => text()(); // upsert / delete
  DateTimeColumn get queuedAt => dateTime().clientDefault(DateTime.now)();
}
