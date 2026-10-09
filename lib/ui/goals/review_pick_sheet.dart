import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/goal_queries.dart';
import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../../theme/tokens.dart';
import '../album/album_image.dart';
import '../common/app_icons.dart';
import '../common/svg_icon.dart';

/// 年度回顧：選擇某月份要用哪一張成圖的 bottom sheet（ReviewPick，D-056）。
///
/// [current] 是目前年度格顯示的圖（預選它）；按「完成」才呼叫 `setReviewMonthImage`。
/// 套用了回傳 true，取消回傳 null。
Future<bool?> showReviewPickSheet(
  BuildContext context, {
  required int year,
  required int month,
  String? current,
}) {
  final t = context.tokens;
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: t.ground,
    barrierColor: const Color(0xFF1E1A17).withValues(alpha: 0.42),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (_) => ReviewPickSheet(year: year, month: month, current: current),
  );
}

class ReviewPickSheet extends ConsumerStatefulWidget {
  const ReviewPickSheet({
    super.key,
    required this.year,
    required this.month,
    this.current,
  });
  final int year;
  final int month;
  final String? current;

  @override
  ConsumerState<ReviewPickSheet> createState() => _ReviewPickSheetState();
}

class _ReviewPickSheetState extends ConsumerState<ReviewPickSheet> {
  String? _selected; // 使用者點選的圖（檔名）；null＝還沒動，沿用預選

  /// 預選：目前顯示的圖；它不在候選裡（例如手動挑的圖已不屬於這個月）就用預設代表圖。
  String? _effective(List<ReviewMonthPiece> pieces) {
    final s = _selected ?? widget.current;
    if (s != null && pieces.any((p) => p.file == s)) return s;
    return defaultReviewPiece(pieces)?.file;
  }

  Future<void> _done(String file) async {
    await ref
        .read(databaseProvider)
        .setReviewMonthImage(widget.year, widget.month, file);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final pieces =
        ref
            .watch(reviewMonthPiecesProvider((widget.year, widget.month)))
            .value ??
        const <ReviewMonthPiece>[];
    final selected = _effective(pieces);
    final maxH = MediaQuery.sizeOf(context).height * 0.85;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxH),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: t.dashed,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      context.l10n.moveReviewPickTitle(widget.month),
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    Text(
                      context.l10n.moveReviewPieceCount(pieces.length),
                      style: TextStyle(fontSize: 12.5, color: t.text3),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: LayoutBuilder(
                  builder: (context, c) {
                    // 3 欄、間距 10；每格 = 3px 內距 ＋ 方圖 ＋ 6px ＋ 標題一行。
                    final w = (c.maxWidth - 20) / 3;
                    return GridView.builder(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        mainAxisExtent: w + 6 + 6 + 20,
                      ),
                      itemCount: pieces.length,
                      itemBuilder: (_, i) => _PickTile(
                        piece: pieces[i],
                        on: pieces[i].file == selected,
                        onTap: () => setState(() => _selected = pieces[i].file),
                      ),
                    );
                  },
                ),
              ),
              GestureDetector(
                onTap: selected == null ? null : () => _done(selected),
                child: Container(
                  margin: const EdgeInsets.only(top: 18),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  decoration: BoxDecoration(
                    color: selected == null
                        ? t.accent.withValues(alpha: .4)
                        : t.accent,
                    borderRadius: BorderRadius.circular(Radii.button),
                  ),
                  child: Text(
                    context.l10n.commonDone,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
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
}

class _PickTile extends StatelessWidget {
  const _PickTile({required this.piece, required this.on, required this.onTap});
  final ReviewMonthPiece piece;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      button: true,
      selected: on,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: DecoratedBox(
                  // 選中＝2px 主色外框（畫在圖外側，不吃掉圖）。
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(Radii.image),
                    boxShadow: on
                        ? [BoxShadow(color: t.accent, spreadRadius: 2)]
                        : null,
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(Radii.image),
                        child: StoredImage(piece.file, cacheWidth: 300),
                      ),
                      if (on)
                        Positioned(
                          right: 7,
                          top: 7,
                          child: Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: t.accent,
                            ),
                            alignment: Alignment.center,
                            child: const SvgIcon(
                              AppIcons.check,
                              size: 13,
                              strokeWidth: 3,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                piece.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
