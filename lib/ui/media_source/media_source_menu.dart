import 'dart:math' as math;

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
  });

  /// 裝置有相機才顯示「拍照」。
  final bool camera;

  /// 剪貼簿有圖（或不確定）才顯示「貼上」。
  final ClipboardProbe clipboard;

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

/// 打開加圖來源選單。選了回傳該項；點外面／返回／取消回傳 null。
/// 視窗 ≥600：[anchor]（加圖格的螢幕範圍，沒有＝置中）旁的 popover（MediaMenu）；
/// 視窗 ＜600（iPad 分屏約 400）：底部 action sheet，另有獨立的「取消」鈕（MediaMenu400）。
/// 蓋在根 Navigator 上，不受頁面導覽影響。
Future<AddSource?> showMediaSourceMenu(
  BuildContext context, {
  required AddSourceOptions options,
  Rect? anchor,
}) {
  final sheet = MediaQuery.sizeOf(context).width < WindowClass.mediumMin;
  return showGeneralDialog<AddSource>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: true,
    barrierLabel: context.l10n.commonClose,
    barrierColor: sheet ? const Color(0x6B1E1A17) : Colors.transparent,
    transitionDuration: Duration(milliseconds: sheet ? 220 : 120),
    transitionBuilder: (context, anim, _, child) => sheet
        ? SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
                .animate(
                  CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
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

/// 窄視窗（＜600）的底部 action sheet（MediaMenu400）：左右各留 10、貼底留 14，
/// 選單（圓角 18、「加圖來源」小標）下面另有一顆獨立的「取消」。
class MediaSourceActionSheet extends StatelessWidget {
  const MediaSourceActionSheet({
    super.key,
    required this.options,
    required this.onSelected,
  });

  final AddSourceOptions options;
  final ValueChanged<AddSource> onSelected;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final mq = MediaQuery.of(context);
    return Material(
      type: MaterialType.transparency,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 14),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: mq.size.height - 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Flexible(
                    child: MediaSourceMenu(
                      options: options,
                      onSelected: onSelected,
                      sheet: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Semantics(
                    button: true,
                    child: Material(
                      color: t.surface,
                      borderRadius: BorderRadius.circular(18),
                      child: InkWell(
                        key: const Key('media-source-cancel'),
                        borderRadius: BorderRadius.circular(18),
                        onTap: () =>
                            Navigator.of(context, rootNavigator: true).pop(),
                        child: SizedBox(
                          height: 56,
                          child: Center(
                            child: Text(
                              context.l10n.commonCancel,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: t.ink,
                              ),
                            ),
                          ),
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
    this.sheet = false,
  });

  final AddSourceOptions options;
  final ValueChanged<AddSource> onSelected;

  /// true＝底部 action sheet 版（MediaMenu400）：圓角 18、上下內距 6、頂端有「加圖來源」小標。
  final bool sheet;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = context.l10n;
    final sources = options.sources;
    final rows = <Widget>[];
    for (final s in sources) {
      if (s == AddSource.paste && rows.isNotEmpty) {
        // 「貼上」和上面幾項之間有分隔線。
        rows.add(
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            color: t.border,
          ),
        );
      }
      rows.add(
        _MenuItem(
          key: Key('media-source-${s.name}'),
          icon: _iconOf(s),
          iconBg: _bgOf(s, t),
          iconFg: _fgOf(s, t),
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
        padding: EdgeInsets.symmetric(vertical: sheet ? 6 : 8),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(sheet ? 18 : 16),
          boxShadow: sheet
              ? const [
                  BoxShadow(
                    color: Color(0x2E000000),
                    blurRadius: 30,
                    offset: Offset(0, 10),
                  ),
                ]
              : const [
                  BoxShadow(
                    color: Color(0x3D1E1B18),
                    blurRadius: 44,
                    offset: Offset(0, 16),
                  ),
                ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (sheet)
                Padding(
                  padding: const EdgeInsets.fromLTRB(0, 8, 0, 6),
                  child: Text(
                    l.ipadmediaMenuLabel,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12.5, color: t.text3),
                  ),
                ),
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
  static Color _bgOf(AddSource s, AppTokens t) => switch (s) {
    AddSource.photos => t.accentSoft,
    AddSource.files => const Color(0xFFEAF0F5),
    AddSource.materials => t.accentSoft,
    AddSource.camera => const Color(0xFFE7EFE4),
    AddSource.paste => const Color(0xFFEFE7DC),
  };

  static Color _fgOf(AddSource s, AppTokens t) => switch (s) {
    AddSource.photos => t.accentStrong,
    AddSource.files => const Color(0xFF4A6A88),
    AddSource.materials => t.accentStrong,
    AddSource.camera => const Color(0xFF55653D),
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
