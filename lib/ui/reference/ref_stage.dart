import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/ref_view_queries.dart';
import '../../state/providers.dart';
import '../album/album_image.dart';
import '../common/dismissible_preview.dart';
import '../common/sensitive_gate.dart';
import 'ref_geometry.dart';
import 'ref_image.dart';

typedef RefOverlayBuilder = Widget Function(
  BuildContext context,
  ValueListenable<Matrix4> transform,
);

final _neverDragging = ValueNotifier<bool>(false);

/// 灰階（檢視狀態，不改原檔）。
const _grayFilter = ColorFilter.matrix(<double>[
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0,
  0.2126, 0.7152, 0.0722, 0, 0,
  0, 0, 0, 1, 0,
]);

/// 可縮放、平移的圖片舞台。
///
/// 縮放與位置由 [snapshot] 還原，使用者操作結束（以及拉窗、換圖、離開）時用 [onChanged]
/// 回報新的狀態；父層只要存起來，不必 setState。
/// - 拉窗／轉方向：視窗大小改變時**不重新 fit**。沒鎖定＝保持相對 fit 的倍數與視窗中央對到的位置；
///   鎖定縮放＝保持絕對縮放（只有可視範圍改變），視窗中央仍對到同一個圖片位置。
/// - 翻轉、灰階只是畫面效果。
class RefStage extends ConsumerStatefulWidget {
  const RefStage({
    super.key,
    required this.image,
    required this.snapshot,
    required this.onChanged,
    this.overlayBuilder,
  });

  final RefImage image;

  /// 目前的檢視狀態；旗標（鎖定、翻轉、灰階）變更會即時反映。
  final RefViewSnapshot snapshot;
  final ValueChanged<RefViewSnapshot> onChanged;

  /// 蓋在舞台上的東西（縮放 pill、浮動工具列），拿到即時的矩陣。
  final RefOverlayBuilder? overlayBuilder;

  @override
  ConsumerState<RefStage> createState() => RefStageState();
}

class RefStageState extends ConsumerState<RefStage> {
  TransformationController? _tc;
  RefGeometry? _geom;
  Size? _resolved;
  bool _sizeKnown = false;

  // 在全螢幕預覽頁裡（有 PreviewScope）：不在「剛好 fit、置中」時回報成放大中（不觸發拖曳退出）；
  // 拖曳退出開始時把這次手勢造成的平移還原，並在退出手勢進行中停用平移。
  PreviewController? _preview;
  Matrix4? _gestureStart;
  bool _dragEngaged = false; // 這次手勢被拖曳退出接手過

  Size get _natural {
    final i = widget.image;
    if (i.width > 0 && i.height > 0) {
      return Size(i.width.toDouble(), i.height.toDouble());
    }
    return _resolved ?? Size.zero;
  }

  @override
  void initState() {
    super.initState();
    _sizeKnown = widget.image.width > 0 && widget.image.height > 0;
    if (!_sizeKnown) unawaited(_resolveSize());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final p = PreviewScope.maybeOf(context);
    if (p == _preview) return;
    _preview?.dragging.removeListener(_onPreviewDragging);
    _preview = p;
    _preview?.dragging.addListener(_onPreviewDragging);
  }

  void _onPreviewDragging() {
    if (!_preview!.dragging.value) return;
    _dragEngaged = true;
    final start = _gestureStart;
    if (start != null) _tc?.value = start.clone();
  }

  /// 是否剛好 fit 且置中（zoom≈1、位置≈中央）。
  bool get _atRest {
    final g = _geom;
    final tc = _tc;
    if (g == null || tc == null) return true;
    final s = g.snapshotFrom(tc.value, widget.snapshot);
    return (s.zoom - 1).abs() < 0.02 &&
        (s.centerX - 0.5).abs() < 0.02 &&
        (s.centerY - 0.5).abs() < 0.02;
  }

  void _reportZoomed() {
    _preview?.setZoomed(this, !_atRest);
  }

  /// 資料裡沒有寬高時（舊資料）解碼一次取得。失敗就當成未知尺寸（鋪滿視窗）。
  Future<void> _resolveSize() async {
    Size? size;
    try {
      final store = await ref.read(imageStoreProvider.future);
      final provider = FileImage(store.fileOf(widget.image.file));
      final done = Completer<Size?>();
      final stream = provider.resolve(ImageConfiguration.empty);
      late final ImageStreamListener l;
      l = ImageStreamListener(
        (info, _) {
          if (!done.isCompleted) {
            done.complete(
              Size(info.image.width.toDouble(), info.image.height.toDouble()),
            );
          }
          stream.removeListener(l);
        },
        onError: (_, _) {
          if (!done.isCompleted) done.complete(null);
          stream.removeListener(l);
        },
      );
      stream.addListener(l);
      size = await done.future;
    } catch (_) {
      size = null;
    }
    if (!mounted) return;
    setState(() {
      _resolved = size;
      _sizeKnown = true;
    });
  }

  /// 目前的檢視狀態（矩陣讀回，旗標取自 [RefStage.snapshot]）。
  RefViewSnapshot currentSnapshot() {
    final g = _geom;
    final tc = _tc;
    if (g == null || tc == null) return widget.snapshot;
    return g.snapshotFrom(tc.value, widget.snapshot);
  }

  /// 把目前狀態回報給父層（手勢結束、離開、App 切到背景前呼叫）。
  void commit() => widget.onChanged(currentSnapshot());

  /// 換掉矩陣：新建 controller（在 build 期間改 value 會通知 InteractiveViewer 重建而出錯）。
  void _swap(Matrix4 m) {
    final old = _tc;
    _tc = TransformationController(m)..addListener(_reportZoomed);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _reportZoomed();
    });
    if (old != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
    }
  }

  @override
  void didUpdateWidget(RefStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final g = _geom;
    final tc = _tc;
    if (g == null || tc == null) return;
    final a = oldWidget.snapshot;
    final b = widget.snapshot;
    if (a.flipped != b.flipped || a.locked != b.locked) {
      // 以舊旗標讀回目前位置，再用新旗標重算矩陣：翻轉時視窗中央那一點不動。
      final base = g.snapshotFrom(tc.value, a);
      final next = base.copyWith(flipped: b.flipped, locked: b.locked);
      _swap(g.matrixFor(next));
      widget.onChanged(next);
    }
  }

  @override
  void dispose() {
    // 離開前把最後的位置交出去（父層存檔，不 setState）。
    if (_geom != null && _tc != null) {
      widget.onChanged(_geom!.snapshotFrom(_tc!.value, widget.snapshot));
    }
    _preview?.dragging.removeListener(_onPreviewDragging);
    _preview?.setZoomed(this, false);
    _tc?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_sizeKnown) return const SizedBox.expand();
    return LayoutBuilder(
      builder: (context, c) {
        final viewport = Size(
          c.hasBoundedWidth ? c.maxWidth : 0,
          c.hasBoundedHeight ? c.maxHeight : 0,
        );
        if (viewport.isEmpty) return const SizedBox.expand();
        final geom = RefGeometry(viewport: viewport, image: _natural);
        final prev = _geom;
        if (prev == null) {
          _geom = geom;
          _swap(geom.matrixFor(widget.snapshot));
        } else if (prev.viewport != viewport || prev.image != geom.image) {
          // 拉窗／轉方向：用舊的幾何讀回狀態，再套到新的視窗上（鎖定時保持絕對縮放）。
          final snap = prev.snapshotFrom(_tc!.value, widget.snapshot);
          _swap(geom.matrixFor(snap));
          _geom = geom;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) commit();
          });
        }
        final snap = widget.snapshot;
        Widget image = StoredImage(
          widget.image.file,
          fit: BoxFit.fill,
          animate: widget.image.isGif,
          isGif: widget.image.isGif ? true : null,
        );
        if (snap.gray) {
          image = ColorFiltered(colorFilter: _grayFilter, child: image);
        }
        if (snap.flipped) {
          image = Transform(
            alignment: Alignment.center,
            transform: Matrix4.diagonal3Values(-1, 1, 1),
            child: image,
          );
        }
        final margin = math.max(viewport.width, viewport.height) * 0.6;
        return Stack(
          fit: StackFit.expand,
          children: [
            // D-110：安全模式開時已標記的圖模糊＋52px 圓（圓在視窗正中，不跟著縮放）；關閉就是正常的圖。
            SensitiveGate(
              file: widget.image.file,
              circleSize: 52,
              showBadge: false,
              child: PreviewRawTap(
                child: ClipRect(
                  child: ValueListenableBuilder<bool>(
                    valueListenable: _preview?.dragging ?? _neverDragging,
                    builder: (context, dragging, child) => InteractiveViewer(
                      transformationController: _tc,
                      minScale: 0.2,
                      maxScale: 12,
                      // 鎖定縮放：雙指只能平移，不能縮放。拖曳退出進行中也不平移。
                      scaleEnabled: !snap.locked && !dragging,
                      panEnabled: !dragging,
                      boundaryMargin: EdgeInsets.all(margin),
                      onInteractionStart: (_) {
                        _gestureStart = _tc?.value.clone();
                        _dragEngaged = false;
                      },
                      onInteractionEnd: (_) {
                        // 拖曳退出造成的平移不算數：還原，不存檔。
                        // （指標事件先到拖曳退出的 Listener，所以這時 dragging 可能已經放掉。）
                        if (_dragEngaged) {
                          _dragEngaged = false;
                          if (_gestureStart != null) {
                            _tc?.value = _gestureStart!.clone();
                          }
                          return;
                        }
                        commit();
                      },
                      child: child!,
                    ),
                    child: SizedBox(
                      width: viewport.width,
                      height: viewport.height,
                      child: Center(
                        child: SizedBox.fromSize(
                          size: geom.fitted,
                          child: image,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (widget.overlayBuilder != null)
              widget.overlayBuilder!(context, _tc!),
          ],
        );
      },
    );
  }
}
