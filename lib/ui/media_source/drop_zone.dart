import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../l10n/l10n.dart';
import '../../theme/tokens.dart';
import '../common/dashed_box.dart';
import '../common/svg_icon.dart';
import 'drop_target_service.dart';
import 'media_source_icons.dart';

/// 拖放的落點（MediaDrop）：包住一個畫面，從其他 App 拖圖片／影片進來時顯示提示條，
/// 放開後逐項載入檔案，全部處理完呼叫 [onFiles]。
///
/// - 只有「目前最上層的頁面」會回應（頁面上方還壓著別的頁面時，下面這個不收）。
/// - 拖曳中提示條只在指標落在這個元件範圍內時顯示。
/// - 放開後的載入狀態：底部浮出「正在載入 n／N 張」，單項失敗不影響其他項，最後提示「n 張無法載入」。
/// - 平台不支援（[dropSupportedProvider] 為 false）時什麼都不做，原樣顯示 [child]。
class DropZone extends ConsumerStatefulWidget {
  const DropZone({
    super.key,
    required this.child,
    required this.title,
    required this.subtitleFor,
    required this.onFiles,
    this.enabled = true,
  });

  final Widget child;

  /// 提示條標題，例如「放開即可加入「官方圖冊」」。
  final String title;

  /// 提示條副標，依拖曳中的張數，例如「3 張 · 放開後選擇分組」。
  final String Function(int count) subtitleFor;

  /// 全部載入完成（至少 1 張成功）後呼叫，檔案依放開時的順序。
  final void Function(List<XFile> files) onFiles;
  final bool enabled;

  @override
  ConsumerState<DropZone> createState() => _DropZoneState();
}

class _DropZoneState extends ConsumerState<DropZone> {
  StreamSubscription<DropEvent>? _sub;
  int? _hoverCount;
  ({int done, int total})? _loading;
  DropTargetService? _service;

  @override
  void initState() {
    super.initState();
    _service = ref.read(dropTargetServiceProvider);
    unawaited(_attach());
  }

  Future<void> _attach() async {
    final service = _service!;
    final ok = await service.start();
    if (!ok || !mounted) return;
    _sub = service.events.listen(_onEvent);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  bool get _active =>
      widget.enabled && (ModalRoute.of(context)?.isCurrent ?? true);

  bool _inside(Offset global) {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return false;
    return (Offset.zero & box.size).contains(box.globalToLocal(global));
  }

  int _count = 0;

  void _onEvent(DropEvent e) {
    if (!mounted) return;
    switch (e) {
      case DropEnter():
        _count = e.count;
        _setHover(_active && _inside(e.position) ? e.count : null);
      case DropMove():
        _setHover(_active && _inside(e.position) ? _count : null);
      case DropLeave():
        _setHover(null);
      case DropPerform():
        _setHover(null);
        if (_active && _inside(e.position)) unawaited(_receive(e.items));
    }
  }

  void _setHover(int? count) {
    if (_hoverCount == count) return;
    setState(() => _hoverCount = count);
  }

  Future<void> _receive(List<DropItem> items) async {
    if (items.isEmpty) return;
    final total = items.length;
    var done = 0;
    setState(() => _loading = (done: 0, total: total));
    final results = await Future.wait([
      for (final item in items)
        () async {
          XFile? file;
          try {
            file = await item.load();
          } catch (_) {
            file = null;
          }
          done++;
          if (mounted) setState(() => _loading = (done: done, total: total));
          return file;
        }(),
    ]);
    if (!mounted) return;
    setState(() => _loading = null);
    final files = [for (final f in results) ?f];
    // 載入失敗／不支援的檔案靜默略過（D-121 ⑤）。
    if (files.isNotEmpty) widget.onFiles(files);
  }

  @override
  Widget build(BuildContext context) {
    final hover = _hoverCount;
    final loading = _loading;
    return Stack(
      fit: StackFit.passthrough,
      children: [
        widget.child,
        if (hover != null)
          Positioned.fill(
            child: IgnorePointer(
              child: DropHighlightBanner(
                key: const Key('drop-banner'),
                title: widget.title,
                subtitle: widget.subtitleFor(hover),
              ),
            ),
          ),
        if (loading != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: 24,
            child: IgnorePointer(
              child: Center(
                child: DropLoadingPill(
                  key: const Key('drop-loading'),
                  done: loading.done,
                  total: loading.total,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// 拖曳中的落點提示（MediaDrop）：內縮 14、3px 主色虛線、圓角 22、淡主色底，
/// 中央向下箭頭＋標題 19 粗體＋副標 14。
class DropHighlightBanner extends StatelessWidget {
  const DropHighlightBanner({
    super.key,
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.all(14),
      child: DashedBox(
        color: t.accent,
        radius: 22,
        width: 3,
        fill: t.accentSoft.withValues(alpha: 0.72),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgIcon(
                MediaSourceIcons.dropArrow,
                size: 44,
                color: t.accentStrong,
                strokeWidth: 1.6,
              ),
              const SizedBox(height: 10),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: t.accentStrong,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: t.accentStrong),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 放開後載入中的小膠囊（設計稿沒畫）：轉圈＋「正在載入 n／N 張」。
class DropLoadingPill extends StatelessWidget {
  const DropLoadingPill({super.key, required this.done, required this.total});
  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Material(
      color: t.ink,
      borderRadius: BorderRadius.circular(22),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: t.ground),
            ),
            const SizedBox(width: 10),
            Text(
              context.l10n.ipadmediaDropLoading(done, total),
              style: TextStyle(
                color: t.ground,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 表單裡的拖放提示列（NewOfficial）：「分屏時可直接從「照片」或「檔案」拖曳圖片至此」。
/// 只在平台支援拖放接收時才顯示。
class DropHintRow extends ConsumerWidget {
  const DropHintRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(dropSupportedProvider).value != true) {
      return const SizedBox.shrink();
    }
    final t = context.tokens;
    return Container(
      key: const Key('drop-hint'),
      margin: const EdgeInsets.only(top: 18),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: t.chipBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          SvgIcon(MediaSourceIcons.dropArrow, size: 18, color: t.text2),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              context.l10n.ipadmediaDropHint,
              style: TextStyle(fontSize: 12.5, height: 1.5, color: t.text2),
            ),
          ),
        ],
      ),
    );
  }
}
