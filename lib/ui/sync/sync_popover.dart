import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../sync/sync_controller.dart';
import '../../theme/tokens.dart';
import '../common/themed_sheet.dart';
import '../common/window_class.dart';
import 'sync_sheet.dart';

/// 點頭像開「同步進度」（RespSpec：彈出頁 ≥600 是頭像 popover，＜600 是底部 sheet）。
///
/// [context] 必須是頭像本身的 context（用它的位置錨定 popover）。＜600 直接用手機版的
/// [showSyncSheet]；≥600 開 [SyncPopover]。彈出期間拉窗跨過 600，同一個彈層會即時換樣式。
/// [onOpenSettings]：popover 底下「同步設定」連結的動作（前往我的 › 備份與同步）。
Future<void> showSyncProgress(
  BuildContext context, {
  VoidCallback? onOpenSettings,
}) {
  if (WindowClass.of(context).isCompact) return showSyncSheet(context);
  final box = context.findRenderObject();
  Rect? anchor;
  if (box is RenderBox && box.hasSize) {
    anchor = box.localToGlobal(Offset.zero) & box.size;
  }
  return showGeneralDialog<void>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: true,
    barrierLabel: context.l10n.commonClose,
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 160),
    pageBuilder: (ctx, _, _) =>
        SyncPopover(anchor: anchor, onOpenSettings: onOpenSettings),
    transitionBuilder: (_, anim, _, child) =>
        FadeTransition(opacity: anim, child: child),
  );
}

/// 頭像 popover（SyncPopover 稿）：寬 400（窄視窗縮到放得下）、圓角 20、頂端一個指向頭像的小箭頭；
/// 內容與同步進度 sheet 相同，另有連線種類與「同步設定」連結。傳完自動關閉。
class SyncPopover extends ConsumerStatefulWidget {
  const SyncPopover({super.key, this.anchor, this.onOpenSettings});

  /// 頭像在畫面上的位置；null＝找不到時放在左上。
  final Rect? anchor;
  final VoidCallback? onOpenSettings;

  /// 設計稿寬度與離視窗邊緣的最小留白。
  static const width = 400.0;
  static const margin = 14.0;

  /// 卡片本體（測試用）。
  static const cardKey = ValueKey('syncPopoverCard');

  @override
  ConsumerState<SyncPopover> createState() => _SyncPopoverState();
}

class _SyncPopoverState extends ConsumerState<SyncPopover> {
  bool _closing = false;

  void _close() {
    if (_closing || !mounted) return;
    _closing = true;
    Navigator.of(context).maybePop();
  }

  void _openSettings() {
    final go = widget.onOpenSettings;
    _close();
    go?.call();
  }

  @override
  void initState() {
    super.initState();
    // 打開的瞬間剛好傳完：直接關。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !ref.read(syncControllerProvider).isTransferring) {
        _close();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(syncControllerProvider.select((s) => s.isTransferring), (
      _,
      transferring,
    ) {
      if (!transferring) _close();
    });
    // 拉窗跨過 600：換成底部 sheet 的樣子（內容不重開）。
    if (WindowClass.of(context).isCompact) {
      return Material(
        type: MaterialType.transparency,
        child: Stack(
          children: [
            const Positioned.fill(child: ColoredBox(color: Color(0x6B1E1A17))),
            Align(
              alignment: Alignment.bottomCenter,
              child: ThemedSheetSurface(child: const SyncSheetBody()),
            ),
          ],
        ),
      );
    }
    final t = context.tokens;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final screen = MediaQuery.sizeOf(context);
    final anchor = widget.anchor ?? const Rect.fromLTWH(20, 24, 40, 40);
    final width = (screen.width - SyncPopover.margin * 2).clamp(
      0.0,
      SyncPopover.width,
    );
    // 稿：頭像外圈左緣 20、popover 左緣 14、箭頭中心約在頭像中心；頭像下緣再 14。
    final left = (anchor.left - 6)
        .clamp(SyncPopover.margin, screen.width - width - SyncPopover.margin)
        .toDouble();
    final top = anchor.bottom + 14;
    final arrowCenter = (anchor.center.dx - left).clamp(24.0, width - 24);
    final maxHeight = (screen.height - top - 14).clamp(160.0, 900.0);
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          Positioned(
            left: left,
            top: top,
            width: width,
            child: Semantics(
              scopesRoute: true,
              namesRoute: true,
              explicitChildNodes: true,
              label: context.l10n.syncuiSheetLabel,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // 箭頭：旋轉 45° 的小方塊，露出左上兩邊。
                  Positioned(
                    left: arrowCenter - 9,
                    top: -8,
                    child: Transform.rotate(
                      angle: 0.7853981633974483,
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: t.surface,
                          borderRadius: BorderRadius.circular(3),
                          // 深色（SyncPopoverDark）：描邊改 white .06。
                          boxShadow: [
                            BoxShadow(
                              color: dark
                                  ? const Color(0x0FFFFFFF)
                                  : const Color(0x0D2B2622),
                              offset: const Offset(-1, -1),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Container(
                    key: SyncPopover.cardKey,
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                    decoration: BoxDecoration(
                      color: t.surface,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: dark
                              ? const Color(0x80000000)
                              : const Color(0x381E1B18),
                          blurRadius: 44,
                          offset: const Offset(0, 14),
                        ),
                        BoxShadow(
                          color: dark
                              ? const Color(0x0FFFFFFF)
                              : const Color(0x0D2B2622),
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: maxHeight),
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SyncProgressHeader(popover: true),
                            SyncProgressRows(onOpenSettings: _openSettings),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
