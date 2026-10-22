import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart' show XFile;

import '../../media/gallery_repository.dart';

/// 某一天的所有項目（新到舊），按日期分組的一段。
class PickerDay {
  PickerDay(this.day, this.firstIndex) : items = [];

  /// 當天 00:00（本地）。
  final DateTime day;
  final List<GalleryItem> items;

  /// 這一天第一個項目在「整份列表（畫面順序）」的 index。
  final int firstIndex;
}

/// 自家圖片選擇器（D-084）的狀態與選取邏輯；不碰 widget，方便測試。
///
/// - 選取順序＝撳的次序（[selected]）；取消中間某張，後面的編號自動往前補。
/// - 整天選取、拖曳連選都以「畫面順序」（[items] 的 index）為準。
class PickerController extends ChangeNotifier {
  PickerController(
    this.repo, {
    this.single = false,
    this.imagesOnly = false,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;

  final GalleryRepository repo;

  /// 單選（頭像）：撳一張＝取代已選。
  final bool single;
  final bool imagesOnly;
  final DateTime Function() now;

  /// 第一批、之後每批載入的張數（相簿幾萬張也不會卡住第一個畫面）。
  static const firstChunk = 400;
  static const nextChunk = 3000;

  GalleryPermission? permission;
  bool loading = true;
  bool exporting = false;

  /// pills 的相簿（已排序：全部、截圖、相機，其餘按張數多到少）。
  List<GalleryAlbum> albums = const [];
  String? albumId;

  List<GalleryItem> items = const [];
  List<PickerDay> days = const [];

  /// 每次 [days] 重算就 +1，供版面快取判斷。
  int layoutVersion = 0;
  Map<String, int> _indexOfId = const {};

  final List<String> _selected = [];
  Map<String, int> _numbers = const {};
  int _loadToken = 0;
  bool _disposed = false;

  /// 已選的項目 id，依撳的次序。
  List<String> get selected => List.unmodifiable(_selected);
  int get selectedCount => _selected.length;

  /// 項目的編號（1 起）；未選回 null。
  int? numberOf(String id) => _numbers[id];

  bool get isLimited => permission == GalleryPermission.limited;
  bool get isDenied => permission == GalleryPermission.denied;

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  // ───────────── 載入 ─────────────

  /// 第一次打開：要權限、讀相簿。
  Future<void> init() async {
    loading = true;
    notifyListeners();
    permission = await repo.requestPermission();
    await _loadAlbums();
  }

  /// 回到前景時（例如從系統設定回來）重新檢查權限；有變化才重讀。
  Future<void> refreshPermission() async {
    if (permission == null) return; // 第一次要權限的流程還沒結束
    final p = await repo.permission();
    if (p == permission) return;
    permission = p;
    await _loadAlbums();
  }

  /// 「管理權限」：部分權限時重新選擇要開放的相片，回來後重讀。
  Future<void> manageLimited() async {
    await repo.manageLimited();
    permission = await repo.permission();
    await _loadAlbums();
  }

  Future<void> openSettings() => repo.openSettings();

  Future<void> _loadAlbums() async {
    if (permission == GalleryPermission.denied) {
      loading = false;
      albums = const [];
      albumId = null;
      items = const [];
      _regroup();
      notifyListeners();
      return;
    }
    loading = true;
    notifyListeners();
    final list = await repo.albums(imagesOnly: imagesOnly);
    albums = sortAlbums(list.where((a) => a.count > 0).toList());
    final keep = albums.any((a) => a.id == albumId);
    albumId = keep ? albumId : (albums.isEmpty ? null : albums.first.id);
    await _loadItems();
  }

  /// 全部、截圖、相機，其餘按張數多到少。
  static List<GalleryAlbum> sortAlbums(List<GalleryAlbum> list) {
    int rank(GalleryAlbumKind k) => switch (k) {
      GalleryAlbumKind.all => 0,
      GalleryAlbumKind.screenshot => 1,
      GalleryAlbumKind.camera => 2,
      GalleryAlbumKind.other => 3,
    };
    return [...list]..sort((a, b) {
      final r = rank(a.kind).compareTo(rank(b.kind));
      return r != 0 ? r : b.count.compareTo(a.count);
    });
  }

  Future<void> selectAlbum(String id) async {
    if (id == albumId) return;
    albumId = id;
    await _loadItems();
  }

  Future<void> _loadItems() async {
    final token = ++_loadToken;
    final id = albumId;
    items = const [];
    _regroup();
    if (id == null) {
      loading = false;
      notifyListeners();
      return;
    }
    final total = albums.firstWhere((a) => a.id == id).count;
    var start = 0;
    while (start < total) {
      final end = start + (start == 0 ? firstChunk : nextChunk);
      final chunk = await repo.items(
        id,
        start: start,
        end: end,
        imagesOnly: imagesOnly,
      );
      if (token != _loadToken || _disposed) return;
      if (chunk.isEmpty) break;
      items = [...items, ...chunk];
      _regroup();
      loading = false;
      notifyListeners();
      start = end;
      // 讓出一格，畫面先畫第一批。
      await Future<void>.delayed(Duration.zero);
      if (token != _loadToken || _disposed) return;
    }
    loading = false;
    notifyListeners();
  }

  void _regroup() {
    final out = <PickerDay>[];
    for (var i = 0; i < items.length; i++) {
      final t = items[i].createdAt;
      final d = DateTime(t.year, t.month, t.day);
      if (out.isEmpty || out.last.day != d) out.add(PickerDay(d, i));
      out.last.items.add(items[i]);
    }
    days = out;
    _indexOfId = {for (var i = 0; i < items.length; i++) items[i].id: i};
    layoutVersion++;
  }

  // ───────────── 選取 ─────────────

  void _commit(List<String> next) {
    _selected
      ..clear()
      ..addAll(next);
    _numbers = {for (var i = 0; i < _selected.length; i++) _selected[i]: i + 1};
    notifyListeners();
  }

  /// 撳一格：未選＝加到最後；已選＝取消（後面的編號補上）。單選時取代。
  void toggle(String id) {
    if (_numbers.containsKey(id)) {
      _commit(_selected.where((e) => e != id).toList());
    } else if (single) {
      _commit([id]);
    } else {
      _commit([..._selected, id]);
    }
  }

  void deselect(String id) {
    if (_numbers.containsKey(id)) {
      _commit(_selected.where((e) => e != id).toList());
    }
  }

  /// 這一天的項目是否全部已選。
  bool isDayFull(PickerDay d) =>
      d.items.isNotEmpty && d.items.every((e) => _numbers.containsKey(e.id));

  /// 整天選取：未全選＝把當天沒選的按畫面順序接在後面；已全選＝取消當天全部。
  void toggleDay(PickerDay d) {
    if (single) return;
    if (isDayFull(d)) {
      final ids = {for (final e in d.items) e.id};
      _commit(_selected.where((e) => !ids.contains(e)).toList());
    } else {
      _commit([
        ..._selected,
        for (final e in d.items)
          if (!_numbers.containsKey(e.id)) e.id,
      ]);
    }
  }

  // ───────────── 長按拖曳連選（D-081） ─────────────

  int? _dragAnchor;

  bool isIndexSelected(int index) =>
      index >= 0 &&
      index < items.length &&
      _numbers.containsKey(items[index].id);

  /// [DragSelectArea.onChanged]：[indexes]＝拖曳後完整的已選 index 集合（畫面順序）。
  /// 新增的項目依「離起點的距離」接在後面（＝拖過的先後）；移除的直接拿掉。
  void applyDrag(Set<int> indexes, bool finished) {
    if (single) return;
    // 只處理目前列表裡有的項目；別的相簿（pills 切換前）選的不受影響。
    final removed = <String>{
      for (final e in _selected)
        if (_indexOfId[e] case final i? when !indexes.contains(i)) e,
    };
    final added = <int>[
      for (final i in indexes)
        if (i >= 0 && i < items.length && !_numbers.containsKey(items[i].id)) i,
    ];
    if (_dragAnchor == null && added.isNotEmpty) {
      added.sort();
      _dragAnchor = added.first;
    }
    final anchor = _dragAnchor;
    if (anchor != null) {
      added.sort((a, b) {
        final c = (a - anchor).abs().compareTo((b - anchor).abs());
        return c != 0 ? c : a.compareTo(b);
      });
    }
    _commit([
      ..._selected.where((e) => !removed.contains(e)),
      for (final i in added) items[i].id,
    ]);
    if (finished) _dragAnchor = null;
  }

  // ───────────── 匯出 ─────────────

  /// 同時匯出幾張。每張要向系統要原檔（iOS 可能要先從 iCloud 下載、再複製到暫存；
  /// Android 10+ 外掛會複製一份到 cache），大部分時間在等原生端／網路，所以並行；
  /// 但不能全開（幾十張同時下載會互相搶頻寬、爆記憶體）。
  static const exportConcurrency = 4;

  /// 把已選的按編號順序匯出成檔案；匯出失敗（取不到原檔或丟例外）的略過。
  ///
  /// 並行取檔（最多 [exportConcurrency] 張同時），結果仍按撳的次序排好。
  /// debug 模式下會印每張與整體的耗時，方便在真機上判斷慢在哪一步。
  Future<List<XFile>> exportSelected() async {
    exporting = true;
    notifyListeners();
    final total = Stopwatch()..start();
    try {
      final ids = List<String>.of(_selected);
      final results = List<XFile?>.filled(ids.length, null);
      var next = 0;
      Future<void> worker() async {
        while (true) {
          final i = next++;
          if (i >= ids.length) return;
          final sw = Stopwatch()..start();
          try {
            results[i] = await repo.export(ids[i]);
          } catch (e) {
            _log('export #${i + 1} ${ids[i]} failed: $e');
          }
          _log(
            'export #${i + 1}/${ids.length} ${ids[i]} '
            '${results[i] == null ? "null" : "ok"} ${sw.elapsedMilliseconds}ms',
          );
        }
      }

      await Future.wait([
        for (var k = 0; k < exportConcurrency && k < ids.length; k++) worker(),
      ]);
      _log(
        'exportSelected ${ids.length} items, concurrency $exportConcurrency: '
        '${total.elapsedMilliseconds}ms',
      );
      return results.whereType<XFile>().toList();
    } finally {
      exporting = false;
      notifyListeners();
    }
  }

  static void _log(String msg) {
    if (kDebugMode) debugPrint('[picker] $msg');
  }
}
