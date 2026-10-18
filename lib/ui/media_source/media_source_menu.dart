import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../theme/tokens.dart';
import '../common/svg_icon.dart';
import '../common/window_class.dart';
import 'media_source_icons.dart';
import 'media_source_services.dart';

/// 加圖的來源（MediaMenu 五項）。
enum AddSource { photos, files, materials, camera, paste }

/// 這次選單要顯示哪些項目（依裝置能力）。
class AddSourceOptions {
  const AddSourceOptions({
    this.camera = true,
    this.clipboard = ClipboardProbe.none,
    this.clipboardPreview,
  });

  /// 裝置有相機才顯示「拍照」。
  final bool camera;

  /// 剪貼簿有圖（或不確定）才顯示「貼上」。
  final ClipboardProbe clipboard;

  /// 剪貼簿那張圖（窄視窗 sheet 的 44px 縮圖）；沒有就畫 soft 色塊。
  final Uint8List? clipboardPreview;

  /// 照設計稿的順序；「貼上」在分隔線之後。
  List<AddSource> get sources => [
    AddSource.photos,
    AddSource.files,
    AddSource.materials,
    if (camera) AddSource.camera,
    if (clipboard != ClipboardProbe.none) AddSource.paste,
  ];
}

/// popover 擺哪一側。
enum PopoverSide { right, left, below, above, center }

class PopoverPlacement {
  const PopoverPlacement(this.offset, this.side, this.arrow);

  /// 選單左上角。
  final Offset offset;
  final PopoverSide side;

  /// 箭頭中心：[PopoverSide.right]／[left] 時是螢幕 y，[below]／[above] 時是螢幕 x；center 時無意義。
  final double arrow;
}

/// 算 popover 位置（純函式，方便測試）。優先放在錨點右側（設計稿），放不下依序左、下、上，
/// 都放不下或沒有錨點＝置中。永遠夾在 [margin] 內。
PopoverPlacement computePopoverPlacement({
  required Rect? anchor,
  required Size screen,
  required Size menu,
  double gap = 12,
  double margin = 16,
  double arrowInset = 28,
}) {
  double clampX(double x) =>
      x.clamp(margin, math.max(margin, screen.width - menu.width - margin));
  double clampY(double y) =>
      y.clamp(margin, math.max(margin, screen.height - menu.height - margin));
  final centered = PopoverPlacement(
    Offset(
      clampX((screen.width - menu.width) / 2),
      clampY((screen.height - menu.height) / 2),
    ),
    PopoverSide.center,
    0,
  );
  if (anchor == null) return centered;

  double arrowAlong(double center, double start, double length) =>
      center.clamp(start + arrowInset, start + length - arrowInset);

  final rightX = anchor.right + gap;
  if (rightX + menu.width <= screen.width - margin) {
    final y = clampY(anchor.center.dy - menu.height / 2);
    return PopoverPlacement(
      Offset(rightX, y),
      PopoverSide.right,
      arrowAlong(anchor.center.dy, y, menu.height),
    );
  }
  final leftX = anchor.left - gap - menu.width;
  if (leftX >= margin) {
    final y = clampY(anchor.center.dy - menu.height / 2);
    return PopoverPlacement(
      Offset(leftX, y),
      PopoverSide.left,
      arrowAlong(anchor.center.dy, y, menu.height),
    );
  }
  final belowY = anchor.bottom + gap;
  if (belowY + menu.height <= screen.height - margin) {
    final x = clampX(anchor.center.dx - menu.width / 2);
    return PopoverPlacement(
      Offset(x, belowY),
      PopoverSide.below,
      arrowAlong(anchor.center.dx, x, menu.width),
    );
  }
  final aboveY = anchor.top - gap - menu.height;
  if (aboveY >= margin) {
    final x = clampX(anchor.center.dx - menu.width / 2);
    return PopoverPlacement(
      Offset(x, aboveY),
      PopoverSide.above,
      arrowAlong(anchor.center.dx, x, menu.width),
    );
  }
  return centered;
}

/// 打開加圖來源選單。選了回傳該項；點外面／返回／×／往下拉回傳 null。
/// 視窗 ≥600：[anchor]（加圖格的螢幕範圍，沒有＝置中）旁的 popover（MediaMenu）；
/// 視窗 ＜600（iPad 分屏約 400）：貼底 sheet（MediaMenu400，P-021），沒有獨立的取消鈕。
/// 蓋在根 Navigator 上，不受頁面導覽影響。
Future<AddSource?> showMediaSourceMenu(
  BuildContext context, {
  required AddSourceOptions options,
  Rect? anchor,
}) {
  final sheet = MediaQuery.sizeOf(context).width < WindowClass.mediumMin;
  final dark = Theme.of(context).brightness == Brightness.dark;
  return showGeneralDialog<AddSource>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: true,
    barrierLabel: context.l10n.commonClose,
    // sheet 底下蓋半透明黑：淺色 .38、深色 .55（MediaMenu400／Dark）。
    barrierColor: !sheet
        ? Colors.transparent
        : (dark ? const Color(0x8C000000) : const Color(0x611E1A17)),
    transitionDuration: Duration(milliseconds: sheet ? 320 : 120),
    transitionBuilder: (context, anim, _, child) => sheet
        ? SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
                .animate(
                  CurvedAnimation(
                    parent: anim,
                    curve: const Cubic(.2, .8, .2, 1),
                  ),
                ),
            child: child,
          )
        : FadeTransition(opacity: anim, child: child),
    pageBuilder: (context, _, _) {
      void pick(AddSource s) =>
          Navigator.of(context, rootNavigator: true).pop(s);
      return sheet
          ? MediaSourceActionSheet(options: options, onSelected: pick)
          : MediaSourcePopover(
              options: options,
              anchor: anchor,
              onSelected: pick,
            );
    },
  );
}

/// 窄視窗（＜600）的貼底 sheet（MediaMenu400）：貼齊螢幕底部、頂部圓角 24；
/// 小橫杆＋「加圖」標題＋右上 ×，一排四格來源、說明、剪貼簿一行。
/// 關閉＝×、往下拉、點外面，沒有獨立的取消鈕。
class MediaSourceActionSheet extends StatefulWidget {
  const MediaSourceActionSheet({
    super.key,
    required this.options,
    required this.onSelected,
  });

  final AddSourceOptions options;
  final ValueChanged<AddSource> onSelected;

  @override
  State<MediaSourceActionSheet> createState() => _MediaSourceActionSheetState();
}

class _MediaSourceActionSheetState extends State<MediaSourceActionSheet> {
  /// 往下拉的位移（只往下）。
  double _drag = 0;
  bool _dragging = false;

  void _close() => Navigator.of(context, rootNavigator: true).pop();

  void _onDragEnd(DragEndDetails d) {
    final v = d.velocity.pixelsPerSecond.dy;
    if (_drag > 80 || v > 700) {
      _close();
      return;
    }
    setState(() {
      _drag = 0;
      _dragging = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = context.l10n;
    final mq = MediaQuery.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final o = widget.options;
    final grid = [
      for (final s in o.sources)
        if (s != AddSource.paste) s,
    ];
    return Material(
      type: MaterialType.transparency,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: AnimatedContainer(
          duration: _dragging
              ? Duration.zero
              : const Duration(milliseconds: 180),
          transform: Matrix4.translationValues(0, _drag, 0),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onVerticalDragStart: (_) => setState(() => _dragging = true),
            onVerticalDragUpdate: (d) =>
                setState(() => _drag = math.max(0, _drag + d.delta.dy)),
            onVerticalDragEnd: _onDragEnd,
            child: Semantics(
              container: true,
              scopesRoute: true,
              explicitChildNodes: true,
              namesRoute: true,
              label: l.ipadmediaSheetTitle,
              child: Container(
                key: const Key('media-source-sheet'),
                constraints: BoxConstraints(maxHeight: mq.size.height - 24),
                decoration: BoxDecoration(
                  // 設計稿：淺色＝ground，深色＝導覽底 #211D1A。
                  color: dark ? t.nav : t.ground,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x2E000000),
                      blurRadius: 30,
                      offset: Offset(0, -8),
                    ),
                  ],
                ),
                padding: EdgeInsets.fromLTRB(
                  16,
                  8,
                  16,
                  math.max(30, mq.padding.bottom + 12),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          key: const Key('media-source-grabber'),
                          width: 36,
                          height: 5,
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: dark
                                ? const Color(0xFF4A433D)
                                : const Color(0xFFD8CFC3),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 0, 0, 6),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                l.ipadmediaSheetTitle,
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: t.ink,
                                    ),
                              ),
                            ),
                            // 視覺 32px 圓形，點擊範圍 44。
                            Semantics(
                              button: true,
                              label: l.commonClose,
                              child: InkResponse(
                                key: const Key('media-source-close'),
                                onTap: _close,
                                radius: 22,
                                child: SizedBox(
                                  width: 44,
                                  height: 44,
                                  child: Center(
                                    child: Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: t.chipBg,
                                        shape: BoxShape.circle,
                                      ),
                                      alignment: Alignment.center,
                                      child: SvgIcon(
                                        MediaSourceIcons.close,
                                        size: 14,
                                        color: t.text2,
                                        strokeWidth: 2.6,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Semantics(
                        container: true,
                        label: l.ipadmediaMenuLabel,
                        child: Row(
                          children: [
                            for (var i = 0; i < grid.length; i++) ...[
                              if (i > 0) const SizedBox(width: 10),
                              Expanded(
                                child: _SourceTile(
                                  key: Key('media-source-${grid[i].name}'),
                                  source: grid[i],
                                  onTap: () => widget.onSelected(grid[i]),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
                        child: Text(
                          l.ipadmediaSheetHint,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.5,
                            color: dark ? t.text4 : t.text3,
                          ),
                        ),
                      ),
                      if (o.clipboard != ClipboardProbe.none)
                        Padding(
                          padding: const EdgeInsets.only(top: 14),
                          child: _ClipboardRow(
                            options: o,
                            onPaste: () => widget.onSelected(AddSource.paste),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 卡面邊框（sheet 的四格與剪貼簿行共用）：淺色＝border-card，深色＝border（#3A332D）。
Color _cardBorder(BuildContext context) {
  final t = context.tokens;
  return Theme.of(context).brightness == Brightness.dark
      ? t.border
      : t.borderCard;
}

/// 一格來源：高 88、圓角 18、1px 邊框、卡面底；只有 icon 有顏色，文字 13/600。
class _SourceTile extends StatelessWidget {
  const _SourceTile({super.key, required this.source, required this.onTap});

  final AddSource source;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = context.l10n;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final (String icon, Color fg, String label) = switch (source) {
      AddSource.photos => (
        MediaSourceIcons.photos,
        t.accentStrong,
        l.ipadmediaTilePhotos,
      ),
      AddSource.files => (
        MediaSourceIcons.files,
        dark ? t.official.fg : const Color(0xFF4A6A88),
        l.ipadmediaTileFiles,
      ),
      AddSource.materials => (
        MediaSourceIcons.materials,
        dark ? t.draft.fg : const Color(0xFF8A6A1F),
        l.ipadmediaTileMaterials,
      ),
      AddSource.camera => (
        MediaSourceIcons.cameraSheet,
        dark ? const Color(0xFFADBD8C) : const Color(0xFF55653D),
        l.ipadmediaTileCamera,
      ),
      AddSource.paste => (MediaSourceIcons.paste, t.text2, l.ipadmediaPaste),
    };
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: t.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: _cardBorder(context)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: SizedBox(
            height: 88,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SvgIcon(icon, size: 26, color: fg, strokeWidth: 1.7),
                const SizedBox(height: 8),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: t.ink,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 剪貼簿一行：44px 縮圖＋「剪貼簿有 1 張圖」「剛剛複製的圖片」＋右邊「貼上」膠囊（soft 底＋strong 字）。
class _ClipboardRow extends StatelessWidget {
  const _ClipboardRow({required this.options, required this.onPaste});

  final AddSourceOptions options;
  final VoidCallback onPaste;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = context.l10n;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final known = options.clipboard == ClipboardProbe.image;
    final preview = options.clipboardPreview;
    return Container(
      key: const Key('media-source-clipboard'),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cardBorder(context)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 44,
              height: 44,
              color: t.accentSoft,
              child: preview == null
                  ? null
                  : Image.memory(
                      preview,
                      fit: BoxFit.cover,
                      cacheWidth: 132,
                      gaplessPlayback: true,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  known ? l.ipadmediaPasteHasImage : l.ipadmediaClipboardTitle,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: t.ink,
                  ),
                ),
                if (known)
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Text(
                      l.ipadmediaClipboardSub,
                      style: TextStyle(
                        fontSize: 12,
                        color: dark ? t.text4 : t.text3,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Semantics(
            button: true,
            child: Material(
              color: t.accentSoft,
              shape: const StadiumBorder(),
              child: InkWell(
                key: const Key('media-source-paste'),
                customBorder: const StadiumBorder(),
                onTap: onPaste,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 44),
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  alignment: Alignment.center,
                  child: Text(
                    l.ipadmediaPaste,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: t.accentStrong,
                    ),
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

/// popover 本體：選單＋箭頭，位置由 [computePopoverPlacement] 決定。
class MediaSourcePopover extends StatelessWidget {
  const MediaSourcePopover({
    super.key,
    required this.options,
    required this.anchor,
    required this.onSelected,
  });

  final AddSourceOptions options;
  final Rect? anchor;
  final ValueChanged<AddSource> onSelected;

  /// 設計稿寬 320；窄分屏時縮到不超出視窗。
  static const double width = 320;

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final w = math.min(width, screen.width - 32);
    return Material(
      type: MaterialType.transparency,
      child: CustomMultiChildLayout(
        delegate: _PopoverDelegate(anchor: anchor, width: w),
        children: [
          LayoutId(id: _PopoverSlot.arrow, child: const _PopoverArrow()),
          LayoutId(
            id: _PopoverSlot.menu,
            child: MediaSourceMenu(options: options, onSelected: onSelected),
          ),
        ],
      ),
    );
  }
}

enum _PopoverSlot { menu, arrow }

class _PopoverDelegate extends MultiChildLayoutDelegate {
  _PopoverDelegate({required this.anchor, required this.width});
  final Rect? anchor;
  final double width;

  @override
  void performLayout(Size size) {
    final menu = layoutChild(
      _PopoverSlot.menu,
      BoxConstraints.tightFor(width: width).loosen().copyWith(
        minWidth: width,
        maxWidth: width,
        maxHeight: math.max(0, size.height - 32),
      ),
    );
    final placement = computePopoverPlacement(
      anchor: anchor,
      screen: size,
      menu: menu,
    );
    positionChild(_PopoverSlot.menu, placement.offset);
    layoutChild(_PopoverSlot.arrow, BoxConstraints.tight(const Size(16, 16)));
    // 箭頭是旋轉 45° 的 16px 方塊，一半藏在選單後面。
    final o = placement.offset;
    switch (placement.side) {
      case PopoverSide.right:
        positionChild(
          _PopoverSlot.arrow,
          Offset(o.dx - 8, placement.arrow - 8),
        );
      case PopoverSide.left:
        positionChild(
          _PopoverSlot.arrow,
          Offset(o.dx + menu.width - 8, placement.arrow - 8),
        );
      case PopoverSide.below:
        positionChild(
          _PopoverSlot.arrow,
          Offset(placement.arrow - 8, o.dy - 8),
        );
      case PopoverSide.above:
        positionChild(
          _PopoverSlot.arrow,
          Offset(placement.arrow - 8, o.dy + menu.height - 8),
        );
      case PopoverSide.center:
        // 沒有錨點：箭頭移出畫面外。
        positionChild(_PopoverSlot.arrow, const Offset(-100, -100));
    }
  }

  @override
  bool shouldRelayout(_PopoverDelegate old) =>
      old.anchor != anchor || old.width != width;
}

class _PopoverArrow extends StatelessWidget {
  const _PopoverArrow();

  @override
  Widget build(BuildContext context) => Transform.rotate(
    angle: math.pi / 4,
    child: Container(
      key: const Key('media-source-arrow'),
      decoration: BoxDecoration(
        color: context.tokens.surface,
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F1E1B18),
            blurRadius: 4,
            offset: Offset(-2, 2),
          ),
        ],
      ),
    ),
  );
}

/// 選單內容（MediaMenu）：圓角 16、白底、陰影；每項 ≥56 高，左側 36px 圓角 icon 底。
class MediaSourceMenu extends StatelessWidget {
  const MediaSourceMenu({
    super.key,
    required this.options,
    required this.onSelected,
  });

  final AddSourceOptions options;
  final ValueChanged<AddSource> onSelected;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = context.l10n;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final sources = options.sources;
    final rows = <Widget>[];
    for (final s in sources) {
      if (s == AddSource.paste && rows.isNotEmpty) {
        // 「貼上」和上面幾項之間有分隔線。
        rows.add(
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            color: dark ? t.chipBg : t.border,
          ),
        );
      }
      rows.add(
        _MenuItem(
          key: Key('media-source-${s.name}'),
          icon: _iconOf(s),
          iconBg: _bgOf(s, t, dark),
          iconFg: _fgOf(s, t, dark),
          title: _titleOf(s, l),
          subtitle: _subtitleOf(s, l, options),
          onTap: () => onSelected(s),
        ),
      );
    }
    return Semantics(
      container: true,
      label: l.ipadmediaMenuLabel,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: dark ? const Color(0x80000000) : const Color(0x3D1E1B18),
              blurRadius: 44,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...rows,
            ],
          ),
        ),
      ),
    );
  }

  static String _iconOf(AddSource s) => switch (s) {
    AddSource.photos => MediaSourceIcons.photos,
    AddSource.files => MediaSourceIcons.files,
    AddSource.materials => MediaSourceIcons.materials,
    AddSource.camera => MediaSourceIcons.camera,
    AddSource.paste => MediaSourceIcons.paste,
  };

  // 設計稿畫的是珊瑚色（第 1、3 項）與各自的中性色；珊瑚色跟目前主題色走。
  // 深色：icon 底一律用 soft 色系（MediaMenuDark），不用淺色 pastel。
  static Color _bgOf(AddSource s, AppTokens t, bool dark) => switch (s) {
    AddSource.photos => t.accentSoft,
    AddSource.files => dark ? const Color(0xFF26303A) : const Color(0xFFEAF0F5),
    AddSource.materials => t.accentSoft,
    AddSource.camera =>
      dark ? const Color(0xFF2C3529) : const Color(0xFFE7EFE4),
    AddSource.paste => t.chipBg,
  };

  static Color _fgOf(AddSource s, AppTokens t, bool dark) => switch (s) {
    AddSource.photos => t.accentStrong,
    AddSource.files => dark ? t.official.fg : const Color(0xFF4A6A88),
    AddSource.materials => t.accentStrong,
    AddSource.camera =>
      dark ? const Color(0xFFADBD8C) : const Color(0xFF55653D),
    AddSource.paste => t.text2,
  };

  static String _titleOf(AddSource s, AppLocalizations l) => switch (s) {
    AddSource.photos => l.ipadmediaPhotos,
    AddSource.files => l.ipadmediaFiles,
    AddSource.materials => l.ipadmediaMaterials,
    AddSource.camera => l.ipadmediaCamera,
    AddSource.paste => l.ipadmediaPaste,
  };

  static String? _subtitleOf(
    AddSource s,
    AppLocalizations l,
    AddSourceOptions o,
  ) => switch (s) {
    AddSource.photos => l.ipadmediaPhotosSub,
    AddSource.files => l.ipadmediaFilesSub,
    AddSource.materials => l.ipadmediaMaterialsSub,
    AddSource.camera => null,
    AddSource.paste =>
      o.clipboard == ClipboardProbe.image ? l.ipadmediaPasteHasImage : null,
  };
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    super.key,
    required this.icon,
    required this.iconBg,
    required this.iconFg,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String icon;
  final Color iconBg;
  final Color iconFg;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: SvgIcon(
                    icon,
                    size: 20,
                    color: iconFg,
                    strokeWidth: 1.7,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: t.ink,
                        ),
                      ),
                      if (subtitle != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            subtitle!,
                            style: TextStyle(fontSize: 12, color: t.text3),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
