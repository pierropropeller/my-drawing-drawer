import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart' show XFile;

import '../../l10n/l10n.dart';
import '../../media/gallery_repository.dart';
import '../../media/photo_manager_gallery.dart';
import '../../theme/tokens.dart';
import '../common/svg_icon.dart';
import 'picker_controller.dart';
import 'picker_grid.dart';
import 'picker_icons.dart';
import 'thumb_loader.dart';

/// 自家圖片選擇器（D-084），取代系統選圖。
///
/// 兩段式 bottom sheet：先半開（約 60% 高），往上拉過一半彈到全螢幕；全螢幕時列表在最頂再往下拉
/// 縮回半開，半開再往下拉＝關閉。永遠深色（不隨主題），只有選中用的主色跟主題。
///
/// - 回傳按「撳的次序」排好的檔案（`下一步`）；✕／撳外面／返回鍵關閉回傳 `null`。
/// - [single]：單選（頭像）；[imagesOnly]：只列圖片（含 GIF），不列影片。
/// - [repository]：預設用 `photo_manager` 讀手機相簿；測試可傳假的。
Future<List<XFile>?> showAppImagePicker(
  BuildContext context, {
  GalleryRepository? repository,
  bool single = false,
  bool imagesOnly = false,
  DateTime Function()? now,
}) {
  // showModalBottomSheet 會把 sheet 內的 MediaQuery 頂部 padding 清成 0（useSafeArea:false），
  // 所以狀態列高度要在 route 外面（根 Navigator 的 context）先量好再傳進去。
  final outer = Navigator.of(context, rootNavigator: true).context;
  final statusBar = math.max(
    MediaQuery.paddingOf(outer).top,
    MediaQuery.viewPaddingOf(outer).top,
  );
  return showModalBottomSheet<List<XFile>>(
    context: context,
    useRootNavigator: true, // 要蓋住底部導覽列
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x8C000000), // rgba(0,0,0,.55)
    elevation: 0,
    enableDrag: false, // 拉高拉低由 DraggableScrollableSheet 處理
    // 視窗 ≥600（MediaPicker）：置中、最寬 760、6 欄；較窄是全闊 4 欄（MediaPicker400）。
    constraints: MediaQuery.sizeOf(context).width >= 600
        ? const BoxConstraints(maxWidth: 760)
        : null,
    builder: (_) => ImagePickerSheet(
      repository: repository ?? PhotoManagerGallery(),
      single: single,
      imagesOnly: imagesOnly,
      now: now,
      statusBarHeight: statusBar,
    ),
  );
}

/// 選擇器本體（sheet 內容）。一般用 [showAppImagePicker]；獨立成 widget 是為了測試。
class ImagePickerSheet extends StatefulWidget {
  const ImagePickerSheet({
    super.key,
    required this.repository,
    this.single = false,
    this.imagesOnly = false,
    this.now,
    this.statusBarHeight,
  });

  final GalleryRepository repository;
  final bool single;
  final bool imagesOnly;
  final DateTime Function()? now;

  /// 狀態列高度；沒給就讀環境的 MediaQuery（modal route 內會被清掉，所以 [showAppImagePicker] 會傳）。
  final double? statusBarHeight;

  @override
  State<ImagePickerSheet> createState() => _ImagePickerSheetState();
}

class _ImagePickerSheetState extends State<ImagePickerSheet>
    with WidgetsBindingObserver {
  static const double _half = 0.6;

  late final PickerController _c = PickerController(
    widget.repository,
    single: widget.single,
    imagesOnly: widget.imagesOnly,
    now: widget.now,
  );
  late final ThumbLoader _loader = ThumbLoader(widget.repository);
  final DraggableScrollableController _sheet = DraggableScrollableController();
  final ValueNotifier<double> _extent = ValueNotifier(_half);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _c.init();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 從系統設定回來：權限可能變了。
    if (state == AppLifecycleState.resumed) _c.refreshPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _c.dispose();
    _loader.dispose();
    _sheet.dispose();
    _extent.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    final files = await _c.exportSelected();
    if (mounted) Navigator.of(context).pop(files);
  }

  // 標題列（沒有捲動的部分）也要能拉動 sheet。
  void _headerDrag(DragUpdateDetails d) {
    if (!_sheet.isAttached) return;
    final h = MediaQuery.sizeOf(context).height;
    _sheet.jumpTo((_sheet.size - d.delta.dy / h).clamp(0.2, 1.0));
  }

  void _headerDragEnd(DragEndDetails d) {
    if (!_sheet.isAttached) return;
    final v = d.velocity.pixelsPerSecond.dy;
    final s = _sheet.size;
    double target;
    if (v > 700) {
      target = s > _half + 0.05 ? _half : 0;
    } else if (v < -700) {
      target = 1;
    } else if (s < 0.3) {
      target = 0;
    } else {
      target = s < 0.8 ? _half : 1;
    }
    if (target == 0) {
      Navigator.of(context).maybePop();
    } else {
      _sheet.animateTo(
        target,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = context.tokens.accent;
    return NotificationListener<DraggableScrollableNotification>(
      onNotification: (n) {
        _extent.value = n.extent;
        return false;
      },
      child: DraggableScrollableSheet(
        controller: _sheet,
        expand: false, // 上方空白要讓 barrier 收到點擊
        initialChildSize: _half,
        minChildSize: 0,
        maxChildSize: 1,
        snap: true,
        snapSizes: const [_half, 1],
        builder: (context, scroll) => ValueListenableBuilder<double>(
          valueListenable: _extent,
          builder: (context, extent, _) => _SheetBody(
            controller: _c,
            loader: _loader,
            scroll: scroll,
            accent: accent,
            extent: extent,
            statusBarHeight:
                widget.statusBarHeight ??
                math.max(
                  MediaQuery.paddingOf(context).top,
                  MediaQuery.viewPaddingOf(context).top,
                ),
            onClose: () => Navigator.of(context).maybePop(),
            onNext: _next,
            onHeaderDrag: _headerDrag,
            onHeaderDragEnd: _headerDragEnd,
          ),
        ),
      ),
    );
  }
}

class _SheetBody extends StatelessWidget {
  const _SheetBody({
    required this.controller,
    required this.loader,
    required this.scroll,
    required this.accent,
    required this.extent,
    required this.statusBarHeight,
    required this.onClose,
    required this.onNext,
    required this.onHeaderDrag,
    required this.onHeaderDragEnd,
  });

  final PickerController controller;
  final ThumbLoader loader;
  final ScrollController scroll;
  final Color accent;

  /// sheet 目前高度（佔螢幕比例，0.6～1）。
  final double extent;
  final double statusBarHeight;
  final VoidCallback onClose;
  final VoidCallback onNext;
  final GestureDragUpdateCallback onHeaderDrag;
  final GestureDragEndCallback onHeaderDragEnd;

  bool get full => extent >= 0.85;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: kPickerBg,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(full ? 0 : 22),
        ),
      ),
      child: DefaultTextStyle.merge(
        style: const TextStyle(color: kPickerInk),
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            // 收合動畫最後高度趨近 0：不要畫（避免 Column 溢位）。
            return LayoutBuilder(
              builder: (context, box) => box.maxHeight < 160
                  ? const SizedBox.shrink()
                  : _content(context),
            );
          },
        ),
      ),
    );
  }

  Widget _content(BuildContext context) {
    final denied = controller.isDenied;
    // sheet 上緣若進到狀態列範圍，內容要往下讓出重疊的部分：半開 = 0，
    // 越拉越高越大，全螢幕 = 狀態列高度。背景仍延伸到狀態列後面。
    final screenH = MediaQuery.sizeOf(context).height;
    final topInset = math.max(0.0, statusBarHeight - (1 - extent) * screenH);
    return Column(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onVerticalDragUpdate: onHeaderDrag,
          onVerticalDragEnd: onHeaderDragEnd,
          child: Padding(
            padding: EdgeInsets.only(top: topInset),
            child: full ? _FullHeader(onClose: onClose) : const _HalfHeader(),
          ),
        ),
        if (!denied && controller.albums.isNotEmpty)
          _Pills(controller: controller),
        if (controller.isLimited)
          _LimitedBanner(onManage: controller.manageLimited),
        Expanded(
          child: denied
              ? _DeniedPage(
                  scroll: scroll,
                  onOpenSettings: controller.openSettings,
                )
              : PickerGrid(
                  controller: controller,
                  loader: loader,
                  scroll: scroll,
                  accent: accent,
                ),
        ),
        _BottomBar(
          controller: controller,
          loader: loader,
          accent: accent,
          onNext: onNext,
        ),
      ],
    );
  }
}

TextStyle _titleStyle(BuildContext context, double size) =>
    (Theme.of(context).textTheme.titleLarge ?? const TextStyle()).copyWith(
      fontSize: size,
      fontWeight: FontWeight.w700,
      color: kPickerInk,
    );

/// 半開：頂部正中一條小橫杆（40×4）＋標題，沒有 ×。
class _HalfHeader extends StatelessWidget {
  const _HalfHeader();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            key: const ValueKey('picker-handle'),
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF4A433D),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        Text(context.l10n.pickerTitle, style: _titleStyle(context, 18)),
      ],
    ),
  );
}

/// 全螢幕：左上角 ×＋標題。
class _FullHeader extends StatelessWidget {
  const _FullHeader({required this.onClose});
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
      child: Row(
        children: [
          GestureDetector(
            key: const ValueKey('picker-close'),
            behavior: HitTestBehavior.opaque,
            onTap: onClose,
            child: Semantics(
              button: true,
              label: context.l10n.commonClose,
              child: const SizedBox(
                width: 40,
                height: 40,
                child: Center(
                  child: SvgIcon(
                    PickerIcons.close,
                    size: 22,
                    strokeWidth: 2,
                    color: kPickerInk,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              context.l10n.pickerTitle,
              style: _titleStyle(context, 19),
            ),
          ),
        ],
      ),
    );
  }
}

/// 相簿 pills：選中＝米白底黑字，未選＝深灰底。
class _Pills extends StatelessWidget {
  const _Pills({required this.controller});
  final PickerController controller;

  String _label(BuildContext context, GalleryAlbum a) {
    final l = context.l10n;
    return switch (a.kind) {
      GalleryAlbumKind.all => l.pickerAlbumAll,
      GalleryAlbumKind.screenshot => l.pickerAlbumScreenshots,
      GalleryAlbumKind.camera => l.pickerAlbumCamera,
      GalleryAlbumKind.other => a.name,
    };
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 12),
      child: Row(
        children: [
          for (final a in controller.albums) ...[
            if (a != controller.albums.first) const SizedBox(width: 8),
            _Pill(
              key: ValueKey('picker-pill-${a.id}'),
              label: _label(context, a),
              selected: a.id == controller.albumId,
              onTap: () => controller.selectAlbum(a.id),
            ),
          ],
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: selected ? kPickerInk : const Color(0xFF1F1C1A),
        border: Border.all(
          color: selected ? kPickerInk : const Color(0xFF3A332D),
        ),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: selected ? kPickerBg : const Color(0xFFB3A99C),
        ),
      ),
    ),
  );
}

/// 部分權限：「只開放了部分相片　管理權限」。
class _LimitedBanner extends StatelessWidget {
  const _LimitedBanner({required this.onManage});
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('picker-limited-banner'),
    margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: const Color(0xFF2A2420),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(
            context.l10n.pickerLimitedNotice,
            style: const TextStyle(fontSize: 13, color: Color(0xFFC9BFB3)),
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          key: const ValueKey('picker-manage'),
          behavior: HitTestBehavior.opaque,
          onTap: onManage,
          child: Text(
            context.l10n.pickerManagePermission,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFFE8876F),
            ),
          ),
        ),
      ],
    ),
  );
}

/// 完全拒絕：整頁說明＋「去設定」。
class _DeniedPage extends StatelessWidget {
  const _DeniedPage({required this.scroll, required this.onOpenSettings});
  final ScrollController scroll;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return LayoutBuilder(
      builder: (context, box) => SingleChildScrollView(
        controller: scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: box.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l.pickerDeniedMessage,
                    key: const ValueKey('picker-denied'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14.5,
                      height: 1.6,
                      color: kPickerSub,
                    ),
                  ),
                  const SizedBox(height: 20),
                  GestureDetector(
                    key: const ValueKey('picker-open-settings'),
                    behavior: HitTestBehavior.opaque,
                    onTap: onOpenSettings,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: kPickerInk,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        l.pickerOpenSettings,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: kPickerBg,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 底部：已選小縮圖列＋整寬主色「下一步（N）」。一張都沒選時整塊不存在，
/// 選第一張時從下面滑上來（約 200ms），全部取消後再滑走。
class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.controller,
    required this.loader,
    required this.accent,
    required this.onNext,
  });

  final PickerController controller;
  final ThumbLoader loader;
  final Color accent;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final has = controller.selectedCount > 0;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, anim) => ClipRect(
        child: SizeTransition(
          sizeFactor: anim,
          alignment: Alignment.bottomCenter,
          child: child,
        ),
      ),
      child: has
          ? _BarContent(
              key: const ValueKey('picker-bottom-bar'),
              controller: controller,
              loader: loader,
              accent: accent,
              onNext: onNext,
            )
          : const SizedBox(
              key: ValueKey('picker-no-bar'),
              width: double.infinity,
            ),
    );
  }
}

class _BarContent extends StatelessWidget {
  const _BarContent({
    super.key,
    required this.controller,
    required this.loader,
    required this.accent,
    required this.onNext,
  });

  final PickerController controller;
  final ThumbLoader loader;
  final Color accent;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final ids = controller.selected;
    final bottom = math.max(MediaQuery.paddingOf(context).bottom, 18.0);
    final busy = controller.exporting;
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1C1917),
        border: Border(top: BorderSide(color: Color(0xFF2A2522))),
      ),
      padding: EdgeInsets.fromLTRB(16, 12, 16, bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 63,
            child: ListView.separated(
              key: const ValueKey('picker-bar-list'),
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(5, 5, 0, 12),
              itemCount: ids.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, i) => _BarThumb(
                key: ValueKey('picker-bar-thumb-${ids[i]}'),
                id: ids[i],
                number: i + 1,
                loader: loader,
                accent: accent,
                onTap: () => controller.deselect(ids[i]),
              ),
            ),
          ),
          GestureDetector(
            key: const ValueKey('picker-next'),
            behavior: HitTestBehavior.opaque,
            onTap: busy ? null : onNext,
            child: Opacity(
              opacity: busy ? 0.6 : 1,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  context.l10n.pickerNext(ids.length),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 底部列的小縮圖：46px、圓角 9，左上角編號，撳＝取消那張。
class _BarThumb extends StatelessWidget {
  const _BarThumb({
    super.key,
    required this.id,
    required this.number,
    required this.loader,
    required this.accent,
    required this.onTap,
  });

  final String id;
  final int number;
  final ThumbLoader loader;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: context.l10n.pickerUnselectThumb(number),
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 46,
        height: 46,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: PickerThumb(id: id, loader: loader, radius: 9),
            ),
            Positioned(
              left: -5,
              top: -5,
              child: Container(
                width: 18,
                height: 18,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF1C1917), width: 2),
                ),
                child: Text(
                  '$number',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
