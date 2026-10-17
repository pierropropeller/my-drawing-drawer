import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show immutable;

import 'database.dart';

/// 參考圖檢視的「每張圖的檢視狀態」（RespSpec：縮放比例與位置要跟著圖存）。
///
/// **只存在本機、不同步**：沒有 SyncColumns、不進 Outbox、不碰同步引擎（和 [SyncDocs] 一樣是
/// 純本機表）。以圖片檔名為鍵，腦洞／草稿／官方圖等各種來源共用，不必認得各表的 id。
///
/// 翻轉、灰階、背景都只是「檢視狀態」，永遠不改原圖檔。
@DataClassName('RefViewState')
class RefViewStates extends Table {
  TextColumn get imageFile => text()();

  /// 相對於「完整顯示（fit）」的縮放倍數；1＝剛好放進視窗。
  RealColumn get zoom => real().withDefault(const Constant(1.0))();

  /// 絕對縮放（每個圖片像素佔幾個邏輯像素）；0＝未知。鎖定縮放時以它為準，
  /// 這樣拉窗只改可視範圍，不會重新 fit。
  RealColumn get scale => real().withDefault(const Constant(0.0))();

  /// 視窗正中央對到的圖片位置（0～1，相對於原圖寬高、未翻轉的座標）。
  RealColumn get centerX => real().withDefault(const Constant(0.5))();
  RealColumn get centerY => real().withDefault(const Constant(0.5))();

  BoolColumn get locked => boolean().withDefault(const Constant(false))();
  BoolColumn get flipped => boolean().withDefault(const Constant(false))();
  BoolColumn get gray => boolean().withDefault(const Constant(false))();

  /// 背景：false＝深色（預設）、true＝淺色。
  BoolColumn get lightBg => boolean().withDefault(const Constant(false))();

  DateTimeColumn get updatedAt => dateTime().clientDefault(DateTime.now)();

  @override
  Set<Column> get primaryKey => {imageFile};
}

/// 一張圖的檢視狀態（純資料，和 drift 的列解耦，方便測試與傳遞）。
@immutable
class RefViewSnapshot {
  const RefViewSnapshot({
    this.zoom = 1,
    this.scale = 0,
    this.centerX = 0.5,
    this.centerY = 0.5,
    this.locked = false,
    this.flipped = false,
    this.gray = false,
    this.lightBg = false,
  });

  static const initial = RefViewSnapshot();

  final double zoom;
  final double scale;
  final double centerX;
  final double centerY;
  final bool locked;
  final bool flipped;
  final bool gray;
  final bool lightBg;

  RefViewSnapshot copyWith({
    double? zoom,
    double? scale,
    double? centerX,
    double? centerY,
    bool? locked,
    bool? flipped,
    bool? gray,
    bool? lightBg,
  }) => RefViewSnapshot(
    zoom: zoom ?? this.zoom,
    scale: scale ?? this.scale,
    centerX: centerX ?? this.centerX,
    centerY: centerY ?? this.centerY,
    locked: locked ?? this.locked,
    flipped: flipped ?? this.flipped,
    gray: gray ?? this.gray,
    lightBg: lightBg ?? this.lightBg,
  );

  @override
  bool operator ==(Object other) =>
      other is RefViewSnapshot &&
      other.zoom == zoom &&
      other.scale == scale &&
      other.centerX == centerX &&
      other.centerY == centerY &&
      other.locked == locked &&
      other.flipped == flipped &&
      other.gray == gray &&
      other.lightBg == lightBg;

  @override
  int get hashCode => Object.hash(
    zoom,
    scale,
    centerX,
    centerY,
    locked,
    flipped,
    gray,
    lightBg,
  );
}

/// 檢視狀態的讀寫（純本機）。
extension RefViewQueries on AppDatabase {
  Future<RefViewSnapshot?> getRefViewState(String imageFile) async {
    final r = await (select(
      refViewStates,
    )..where((t) => t.imageFile.equals(imageFile))).getSingleOrNull();
    return r == null ? null : _toSnapshot(r);
  }

  /// 一次讀多張。
  Future<Map<String, RefViewSnapshot>> getRefViewStates(
    Iterable<String> imageFiles,
  ) async {
    final files = imageFiles.toSet().toList();
    if (files.isEmpty) return {};
    final rows = await (select(
      refViewStates,
    )..where((t) => t.imageFile.isIn(files))).get();
    return {for (final r in rows) r.imageFile: _toSnapshot(r)};
  }

  Future<void> saveRefViewState(String imageFile, RefViewSnapshot s) {
    return into(refViewStates).insertOnConflictUpdate(
      RefViewStatesCompanion.insert(
        imageFile: imageFile,
        zoom: Value(s.zoom),
        scale: Value(s.scale),
        centerX: Value(s.centerX),
        centerY: Value(s.centerY),
        locked: Value(s.locked),
        flipped: Value(s.flipped),
        gray: Value(s.gray),
        lightBg: Value(s.lightBg),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// 圖片刪除後順手清掉它的檢視狀態。
  Future<void> deleteRefViewState(String imageFile) =>
      (delete(refViewStates)..where((t) => t.imageFile.equals(imageFile))).go();

  RefViewSnapshot _toSnapshot(RefViewState r) => RefViewSnapshot(
    zoom: r.zoom,
    scale: r.scale,
    centerX: r.centerX,
    centerY: r.centerY,
    locked: r.locked,
    flipped: r.flipped,
    gray: r.gray,
    lightBg: r.lightBg,
  );
}
