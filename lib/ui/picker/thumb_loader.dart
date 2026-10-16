import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../media/gallery_repository.dart';

/// 縮圖載入（D-084）：LRU 記憶體快取＋限制同時載入的數量。
///
/// - 捲動時最新要的先載（後進先出），已經捲出畫面（widget dispose）的請求直接略過，
///   所以快速拖捲動條時不會塞住佇列。
/// - 一個 loader 對應一次選擇器；縮圖邊長固定 [size]（格子 87px×3 倍密度附近）。
class ThumbLoader {
  ThumbLoader(
    this.repo, {
    this.size = 200,
    this.capacity = 800,
    this.maxConcurrent = 6,
  });

  final GalleryRepository repo;
  final int size;
  final int capacity;
  final int maxConcurrent;

  final LinkedHashMap<String, Uint8List> _cache = LinkedHashMap();
  final List<ThumbRequest> _queue = [];
  int _running = 0;
  bool _disposed = false;

  @visibleForTesting
  int get cacheSize => _cache.length;

  /// 快取裡有就回傳（並標成最近使用）。
  Uint8List? peek(String id) {
    final b = _cache.remove(id);
    if (b != null) _cache[id] = b;
    return b;
  }

  void _put(String id, Uint8List b) {
    _cache.remove(id);
    _cache[id] = b;
    while (_cache.length > capacity) {
      _cache.remove(_cache.keys.first);
    }
  }

  ThumbRequest load(String id) {
    final r = ThumbRequest._(id);
    _queue.add(r);
    _pump();
    return r;
  }

  void _pump() {
    while (!_disposed && _running < maxConcurrent && _queue.isNotEmpty) {
      final r = _queue.removeLast();
      if (r.cancelled) continue;
      _running++;
      () async {
        Uint8List? bytes;
        try {
          bytes = await repo.thumbnail(r.id, size);
        } catch (_) {
          bytes = null;
        }
        _running--;
        if (bytes != null) _put(r.id, bytes);
        if (!r.cancelled && !r._done.isCompleted) r._done.complete(bytes);
        _pump();
      }();
    }
  }

  void dispose() {
    _disposed = true;
    for (final r in _queue) {
      r.cancel();
    }
    _queue.clear();
    _cache.clear();
  }
}

class ThumbRequest {
  ThumbRequest._(this.id);
  final String id;
  final Completer<Uint8List?> _done = Completer();
  bool cancelled = false;

  Future<Uint8List?> get future => _done.future;
  void cancel() => cancelled = true;
}

/// 一格縮圖：先看快取，沒有再排隊載；載入前是深灰底。
class PickerThumb extends StatefulWidget {
  const PickerThumb({
    super.key,
    required this.id,
    required this.loader,
    this.radius = 0,
  });

  final String id;
  final ThumbLoader loader;
  final double radius;

  @override
  State<PickerThumb> createState() => _PickerThumbState();
}

class _PickerThumbState extends State<PickerThumb> {
  Uint8List? _bytes;
  ThumbRequest? _req;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(PickerThumb old) {
    super.didUpdateWidget(old);
    if (old.id != widget.id) {
      _req?.cancel();
      _resolve();
    }
  }

  void _resolve() {
    _bytes = widget.loader.peek(widget.id);
    _req = null;
    if (_bytes != null) return;
    final req = widget.loader.load(widget.id);
    _req = req;
    req.future.then((b) {
      if (mounted && identical(_req, req) && b != null) {
        setState(() => _bytes = b);
      }
    });
  }

  @override
  void dispose() {
    _req?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final b = _bytes;
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.radius),
      child: ColoredBox(
        color: const Color(0xFF1F1C1A),
        child: b == null
            ? const SizedBox.expand()
            : Image.memory(
                b,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                filterQuality: FilterQuality.low,
              ),
      ),
    );
  }
}
