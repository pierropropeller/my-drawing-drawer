import 'package:drift/drift.dart';

import 'album_queries.dart';
import 'database.dart';
import 'entity_queries.dart';
import 'junk_queries.dart';
import 'oshi_queries.dart';

/// 淺坑／封存坑（D-088）的資料層：坑的類型轉換、格子開關、格子內容的計數與刪除。
/// 規格與 API 見 docs/DATA_API.md「批次 14」。

/// 要關閉的格子裡還有內容、呼叫端又沒有明確同意刪除（`deleteContent`／`deleteClosedContent`）。
/// UI 應先用 [PitStatusQueries.sectionContentCount] 取得數量、彈確認框，同意後再帶旗標呼叫。
class PitSectionHasContent implements Exception {
  const PitSectionHasContent(this.counts);

  /// 有內容的格子 → 內容數量（只列出數量大於 0 的）。
  final Map<PitSectionKey, int> counts;

  @override
  String toString() => 'PitSectionHasContent($counts)';
}

/// 現坑與封存坑「看得到」的格子：六個固定格，加上雜物開關。
Set<PitSectionKey> _allCells({required bool junk}) => {
  PitSectionKey.official,
  PitSectionKey.fan,
  PitSectionKey.idea,
  PitSectionKey.draft,
  PitSectionKey.piece,
  PitSectionKey.oshi,
  if (junk) PitSectionKey.junk,
};

extension PitX on Pit {
  bool get isActive => status == PitStatus.active;
  bool get isShallow => status == PitStatus.shallow;
  bool get isArchived => status == PitStatus.archived;

  /// 舊欄位 `archived` 的相容讀法（＝封存坑）。
  bool get archived => status == PitStatus.archived;

  /// 這個坑現在「開著」的格子。淺坑＝[enabledSections]；其餘＝六個固定格＋（雜物開關開著時）雜物。
  Set<PitSectionKey> get openSections =>
      isShallow ? enabledSections : _allCells(junk: junkEnabled);

  /// 單一格子是否開著（分享匯入、圖片移動的選擇清單用它過濾格子）。
  bool sectionOpen(PitSectionKey k) => openSections.contains(k);
}

/// 主頁分頁的排序方式（D-132）。資料庫存 [stored]；沒設定＝[updatedDesc]（原本的行為）。
enum PitSortMode {
  manual('manual'),
  createdDesc('created_desc'),
  createdAsc('created_asc'),
  updatedDesc('updated_desc'),
  updatedAsc('updated_asc');

  const PitSortMode(this.stored);
  final String stored;

  static PitSortMode parse(String? raw) => PitSortMode.values.firstWhere(
    (m) => m.stored == raw,
    orElse: () => PitSortMode.updatedDesc,
  );

  bool get isCreated => this == createdDesc || this == createdAsc;
  bool get isUpdated => this == updatedDesc || this == updatedAsc;
  bool get isAscending => this == createdAsc || this == updatedAsc;
}

/// [mode] 下 a、b 兩個坑的先後（[aActivity]／[bActivity]＝最後更新，秒）。
/// 手動：還沒排過的（sortOrder＝null）在最前面，彼此依建立時間新→舊；其餘依 sortOrder。
/// 同分時一律依建立時間新→舊，結果穩定。
int comparePits(PitSortMode mode, Pit a, int aActivity, Pit b, int bActivity) {
  int newerFirst() => b.createdAt.compareTo(a.createdAt);
  int byKey(int c, bool ascending) {
    final r = ascending ? c : -c;
    return r != 0 ? r : newerFirst();
  }

  switch (mode) {
    case PitSortMode.manual:
      final ao = a.sortOrder, bo = b.sortOrder;
      if (ao == null && bo == null) return newerFirst();
      if (ao == null) return -1;
      if (bo == null) return 1;
      return ao != bo ? ao.compareTo(bo) : newerFirst();
    case PitSortMode.createdDesc:
    case PitSortMode.createdAsc:
      return byKey(a.createdAt.compareTo(b.createdAt), mode.isAscending);
    case PitSortMode.updatedDesc:
    case PitSortMode.updatedAsc:
      return byKey(aActivity.compareTo(bActivity), mode.isAscending);
  }
}

extension PitStatusQueries on AppDatabase {
  // ---- 排序（D-132）----

  /// 分頁目前的排序方式。
  Stream<PitSortMode> watchPitSortMode(PitStatus status) =>
      (select(pitSortSettings)..where((t) => t.status.equals(status.name)))
          .watchSingleOrNull()
          .map((r) => PitSortMode.parse(r?.mode));

  /// 換分頁的排序方式（自動排序；或拖動後變手動）。會同步到其他裝置。
  Future<void> setPitSortMode(PitStatus status, PitSortMode mode) =>
      into(pitSortSettings).insertOnConflictUpdate(
        PitSortSettingsCompanion.insert(
          status: status.name,
          mode: mode.stored,
          updatedAt: DateTime.now(),
        ),
      );

  /// 手動排序：[orderedIds] 是這個分頁拖動後的完整順序，排序方式同時變成「手動」。
  /// 只寫入位置有變的坑；只改排序不算「更新」（記下排序前的最後更新，見 [Pits.sortTouchedAt]）。
  Future<void> reorderPits(PitStatus status, List<String> orderedIds) =>
      transaction(() async {
        final now = DateTime.now();
        final rows = {
          for (final p in await (select(
            pits,
          )..where((p) => p.id.isIn(orderedIds))).get())
            p.id: p,
        };
        for (var i = 0; i < orderedIds.length; i++) {
          final p = rows[orderedIds[i]];
          if (p == null || p.sortOrder == i) continue;
          final onlySorted =
              p.sortTouchedAt != null && p.sortTouchedAt == p.updatedAt;
          await (update(pits)..where((t) => t.id.equals(p.id))).write(
            PitsCompanion(
              sortOrder: Value(i),
              activityAt: Value(onlySorted ? p.activityAt : p.updatedAt),
              sortTouchedAt: Value(now),
              updatedAt: Value(now),
            ),
          );
        }
        await setPitSortMode(status, PitSortMode.manual);
      });

  // ---- 清單 ----

  /// 指定類型的坑。只有一種類型時依該分頁的排序方式（[PitSortMode]，D-132）；
  /// 多種類型（選擇清單）一律依「最後更新」新→舊。
  /// 「最後更新」＝坑本身或坑內任何內容有更新；只改排序不算（見 [Pits.sortTouchedAt]）。
  Stream<List<Pit>> watchPitsByStatus(Set<PitStatus> statuses) {
    final list = statuses.toList();
    if (list.isEmpty) return Stream.value(const []);
    final marks = List.filled(list.length, '?').join(',');
    final single = list.length == 1 ? list.single : null;
    return customSelect(
      '''
      SELECT p.*, MAX(
        CASE WHEN p.sort_touched_at IS NOT NULL AND p.sort_touched_at = p.updated_at
          THEN COALESCE(p.activity_at, p.created_at) ELSE p.updated_at END,
        COALESCE((SELECT MAX(updated_at) FROM official_images WHERE pit_id = p.id), 0),
        COALESCE((SELECT MAX(updated_at) FROM fan_arts WHERE pit_id = p.id), 0),
        COALESCE((SELECT MAX(updated_at) FROM junk_images WHERE pit_id = p.id), 0),
        COALESCE((SELECT MAX(updated_at) FROM ideas WHERE pit_id = p.id), 0),
        COALESCE((SELECT MAX(updated_at) FROM drafts WHERE pit_id = p.id), 0),
        COALESCE((SELECT MAX(updated_at) FROM pieces WHERE pit_id = p.id), 0),
        COALESCE((SELECT MAX(updated_at) FROM oshi_records WHERE pit_id = p.id), 0)
      ) AS last_activity,
      (SELECT mode FROM pit_sort_settings WHERE status = ?) AS sort_mode
      FROM pits p
      WHERE p.deleted_at IS NULL AND p.status IN ($marks)
      ''',
      variables: [
        Variable<String>(single?.name ?? ''),
        for (final s in list) Variable<String>(s.name),
      ],
      readsFrom: {
        pits,
        officialImages,
        fanArts,
        junkImages,
        ideas,
        drafts,
        pieces,
        oshiRecords,
        pitSortSettings,
      },
    ).watch().map((rows) {
      final mode = single == null || rows.isEmpty
          ? PitSortMode.updatedDesc
          : PitSortMode.parse(rows.first.readNullable<String>('sort_mode'));
      // 第三項＝查詢原本順序：完全同分時維持穩定（List.sort 不保證穩定）。
      final entries = [
        for (final (i, r) in rows.indexed)
          (pits.map(r.data), r.read<int>('last_activity'), i),
      ];
      entries.sort((a, b) {
        final c = comparePits(mode, a.$1, a.$2, b.$1, b.$2);
        return c != 0 ? c : a.$3.compareTo(b.$3);
      });
      return [for (final e in entries) e.$1];
    });
  }

  /// 選擇清單用的坑（分享匯入、圖片移動、新增目標、日頁的新增）：現坑加淺坑；**不含封存坑**。
  /// 淺坑只開放它開啟的格子（見 [PitX.sectionOpen]）。
  Stream<List<Pit>> watchSelectablePits() =>
      watchPitsByStatus({PitStatus.active, PitStatus.shallow});

  /// 封存坑的 id（目標進度、搜尋等要排除它們的資料時用）。
  Future<Set<String>> archivedPitIds() async => {
    for (final p
        in await (select(pits)..where(
              (p) =>
                  p.deletedAt.isNull() &
                  p.status.equals(PitStatus.archived.name),
            ))
            .get())
      p.id,
  };

  /// 「所屬的坑不是封存坑」的條件（D-098：時間軸、月曆不顯示封存坑的內容）。
  /// 用子查詢，不載入 id 集合；轉回現坑／淺坑後立即重新符合（不動資料）。
  Expression<bool> notInArchivedPit(GeneratedColumn<String> pitId) =>
      pitId.isNotInQuery(
        selectOnly(pits)
          ..addColumns([pits.id])
          ..where(pits.status.equals(PitStatus.archived.name)),
      );

  // ---- 封面 ----

  /// 坑自己的封面（從手機相簿直接選的圖檔；null＝清除）。任何類型（坑、淺坑、封存）都可以用（P-041）。
  ///
  /// 封面「最後選的贏」：選了檔案就換掉原本的坑內封面參考（[Pits.coverImageId] 清空）；
  /// 反過來 [setCover]（從坑內選圖）會清掉這個檔。
  Future<void> setPitCoverFile(String pitId, String? file) {
    return (update(pits)..where((p) => p.id.equals(pitId))).write(
      PitsCompanion(
        coverFile: Value(file),
        coverImageId: file == null ? const Value.absent() : const Value(null),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  // ---- 格子內容 ----

  /// 某格目前有幾筆內容（未刪除；被移到別格而隱藏的圖不算）。
  /// official／fan／junk＝圖片張數，idea＝腦洞數，draft＝摸魚數，piece＝成圖數，oshi＝推活筆數。
  /// 關閉格子的確認框用它：「格子入面的 N 張圖（或 N 個腦洞／摸魚…）會一併刪除，無法復原」。
  Future<int> sectionContentCount(String pitId, PitSectionKey section) async {
    final ids = await _sectionContentIds(pitId, section);
    return ids.length;
  }

  /// 所有格子的內容數量（只列出大於 0 的）。
  Future<Map<PitSectionKey, int>> sectionContentCounts(String pitId) async => {
    for (final s in PitSectionKey.values)
      if (await sectionContentCount(pitId, s) case final n when n > 0) s: n,
  };

  Future<List<String>> _sectionContentIds(
    String pitId,
    PitSectionKey section,
  ) async {
    switch (section) {
      case PitSectionKey.official:
        return [
          for (final r
              in await (select(officialImages)..where(
                    (i) =>
                        i.pitId.equals(pitId) &
                        i.deletedAt.isNull() &
                        i.hidden.equals(false),
                  ))
                  .get())
            r.id,
        ];
      case PitSectionKey.fan:
        return [
          for (final r
              in await (select(fanArts)..where(
                    (i) =>
                        i.pitId.equals(pitId) &
                        i.deletedAt.isNull() &
                        i.hidden.equals(false),
                  ))
                  .get())
            r.id,
        ];
      case PitSectionKey.junk:
        return [
          for (final r
              in await (select(junkImages)..where(
                    (i) =>
                        i.pitId.equals(pitId) &
                        i.deletedAt.isNull() &
                        i.hidden.equals(false),
                  ))
                  .get())
            r.id,
        ];
      case PitSectionKey.idea:
        return [
          for (final r in await (select(
            ideas,
          )..where((i) => i.pitId.equals(pitId) & i.deletedAt.isNull())).get())
            r.id,
        ];
      case PitSectionKey.draft:
        return [
          for (final r in await (select(
            drafts,
          )..where((i) => i.pitId.equals(pitId) & i.deletedAt.isNull())).get())
            r.id,
        ];
      case PitSectionKey.piece:
        return [
          for (final r in await (select(
            pieces,
          )..where((i) => i.pitId.equals(pitId) & i.deletedAt.isNull())).get())
            r.id,
        ];
      case PitSectionKey.oshi:
        return [
          for (final r in await (select(
            oshiRecords,
          )..where((i) => i.pitId.equals(pitId) & i.deletedAt.isNull())).get())
            r.id,
        ];
    }
  }

  /// 軟刪除某格的全部內容（沿用各格原本的刪除函式，連帶清掉封面、關係）。
  Future<void> _deleteSectionContent(String pitId, PitSectionKey s) async {
    final ids = await _sectionContentIds(pitId, s);
    if (ids.isEmpty) return;
    switch (s) {
      case PitSectionKey.official:
        await deleteOfficial(ids);
      case PitSectionKey.fan:
        await deleteFanArts(ids);
      case PitSectionKey.junk:
        await deleteJunk(ids);
      case PitSectionKey.idea:
        await deleteIdeas(ids);
      case PitSectionKey.draft:
        await deleteDrafts(ids);
      case PitSectionKey.piece:
        await deletePieces(ids);
      case PitSectionKey.oshi:
        await deleteOshiRecords(ids);
    }
    // 格子封面（草稿／腦洞／成圖／推活存的是檔名）一併清掉。
    final clear = switch (s) {
      PitSectionKey.official => const PitsCompanion(
        officialCoverId: Value(null),
      ),
      PitSectionKey.fan => const PitsCompanion(fanArtCoverId: Value(null)),
      PitSectionKey.draft => const PitsCompanion(draftCoverFile: Value(null)),
      PitSectionKey.idea => const PitsCompanion(ideaCoverFile: Value(null)),
      PitSectionKey.piece => const PitsCompanion(pieceCoverFile: Value(null)),
      PitSectionKey.oshi => const PitsCompanion(oshiCoverFile: Value(null)),
      PitSectionKey.junk => null,
    };
    if (clear != null) {
      await (update(pits)..where((p) => p.id.equals(pitId))).write(clear);
    }
  }

  // ---- 類型轉換與格子開關 ----

  /// 轉換坑的類型（現坑／淺坑／封存），規則（D-088）：
  /// - 淺坑→坑：六格全開，資料保留；雜物開關沿用淺坑的雜物格。
  /// - 坑→淺坑：[enabledSections] 沒給＝有資料的格子為開（雜物開關開著也算開）。
  /// - 任何→封存：資料全保留，淺坑的格子設定也保留；可再轉回。封存→淺坑沿用保留的設定。
  /// - 淺坑裡被關掉、而且有內容的格子，內容會軟刪除；沒有 [deleteClosedContent] 時丟 [PitSectionHasContent]
  ///   （整個操作不生效）。
  Future<void> setPitStatus(
    String pitId,
    PitStatus status, {
    Set<PitSectionKey>? enabledSections,
    bool? junkEnabled,
    bool deleteClosedContent = false,
  }) => transaction(() async {
    final cur = await (select(
      pits,
    )..where((p) => p.id.equals(pitId))).getSingle();
    await _applyPitType(
      cur,
      status,
      enabledSections: enabledSections,
      junkEnabled: junkEnabled,
      deleteClosedContent: deleteClosedContent,
    );
  });

  /// 開關淺坑的單一格子。關掉有內容的格子時，沒有 [deleteContent] 就丟 [PitSectionHasContent]；
  /// 帶 [deleteContent] 會把該格內容軟刪除。
  /// 非淺坑只有「雜物」能開關（等同雜物開關，關掉不刪內容）；其他格子丟 [ArgumentError]。
  Future<void> setPitSectionEnabled(
    String pitId,
    PitSectionKey section,
    bool enabled, {
    bool deleteContent = false,
  }) => transaction(() async {
    final cur = await (select(
      pits,
    )..where((p) => p.id.equals(pitId))).getSingle();
    if (!cur.isShallow) {
      if (section != PitSectionKey.junk) {
        throw ArgumentError('只有淺坑可以開關格子：$section');
      }
      await (update(pits)..where((p) => p.id.equals(pitId))).write(
        PitsCompanion(
          junkEnabled: Value(enabled),
          updatedAt: Value(DateTime.now()),
        ),
      );
      return;
    }
    final next = {...cur.enabledSections};
    if (enabled) {
      next.add(section);
    } else {
      next.remove(section);
    }
    await _applyPitType(
      cur,
      PitStatus.shallow,
      enabledSections: next,
      deleteClosedContent: deleteContent,
    );
  });

  /// 把 [cur] 轉成 [target] 類型（含格子設定與內容刪除），寫回資料庫。**呼叫端要在 transaction 內**。
  /// [extra] 是同一次寫入要一起帶的欄位（名稱、描述）。
  Future<void> _applyPitType(
    Pit cur,
    PitStatus target, {
    Set<PitSectionKey>? enabledSections,
    bool? junkEnabled,
    bool deleteClosedContent = false,
    PitsCompanion extra = const PitsCompanion(),
  }) async {
    final oldOpen = cur.openSections;

    late final Set<PitSectionKey> sections; // 新的 enabledSections（要存的）
    late final bool junk;
    switch (target) {
      case PitStatus.shallow:
        sections =
            enabledSections ??
            (cur.isShallow || (cur.isArchived && cur.enabledSections.isNotEmpty)
                ? cur.enabledSections
                : {
                    ...(await sectionContentCounts(cur.id)).keys,
                    if (junkEnabled ?? cur.junkEnabled) PitSectionKey.junk,
                  });
        junk = sections.contains(PitSectionKey.junk);
      case PitStatus.active:
        sections = const {};
        junk =
            junkEnabled ??
            (cur.isShallow
                ? cur.enabledSections.contains(PitSectionKey.junk)
                : cur.junkEnabled);
      case PitStatus.archived:
        // 淺坑封存時保留格子設定（轉回淺坑時還原）；現坑封存沒有格子設定。
        sections = cur.isShallow || cur.isArchived
            ? cur.enabledSections
            : const {};
        junk =
            junkEnabled ??
            (cur.isShallow
                ? cur.enabledSections.contains(PitSectionKey.junk)
                : cur.junkEnabled);
    }

    // 轉成淺坑時，原本開著、現在關掉的格子：有內容就必須同意刪除。
    if (target == PitStatus.shallow) {
      final closing = oldOpen.difference(sections);
      final counts = <PitSectionKey, int>{};
      for (final s in closing) {
        final n = await sectionContentCount(cur.id, s);
        if (n > 0) counts[s] = n;
      }
      if (counts.isNotEmpty && !deleteClosedContent) {
        throw PitSectionHasContent(counts);
      }
      for (final s in counts.keys) {
        await _deleteSectionContent(cur.id, s);
      }
    }

    await (update(pits)..where((p) => p.id.equals(cur.id))).write(
      extra.copyWith(
        status: Value(target),
        enabledSections: Value(sections),
        junkEnabled: Value(junk),
        // 轉到別的分頁：手動排序時排在最前面（D-132）。
        sortOrder: target == cur.status
            ? const Value.absent()
            : const Value(null),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// 編輯坑一次存檔（名稱、描述、類型、格子、雜物）。規則同 [setPitStatus]；
  /// 欄位為 null＝不變。內部在同一個 transaction 裡，失敗（[PitSectionHasContent]）時全部不生效。
  Future<void> savePit(
    String id, {
    required String name,
    String? description,
    PitStatus? status,
    Set<PitSectionKey>? enabledSections,
    bool? junkEnabled,
    bool? sensitiveEnabled,
    bool deleteClosedContent = false,
  }) => transaction(() async {
    final cur = await (select(pits)..where((p) => p.id.equals(id))).getSingle();
    await _applyPitType(
      cur,
      status ?? cur.status,
      enabledSections: enabledSections,
      junkEnabled: junkEnabled,
      deleteClosedContent: deleteClosedContent,
      extra: PitsCompanion(
        name: Value(name),
        description: Value(description),
        // 敏感內容開關（D-104）：null＝不變；只改開關，標記保留。
        sensitiveEnabled: sensitiveEnabled == null
            ? const Value.absent()
            : Value(sensitiveEnabled),
      ),
    );
  });
}
