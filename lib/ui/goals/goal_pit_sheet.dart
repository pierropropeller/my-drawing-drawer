import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../../theme/tokens.dart';
import '../album/album_image.dart';
import '../common/app_icons.dart';
import '../common/svg_icon.dart';
import '../common/themed_sheet.dart';
import '../common/window_class.dart';
import '../pits/pit_rows.dart';

/// 新增目標「目標坑」的選擇面板（GoalPitSheet，D-124）：現坑＋淺坑（不含封存坑），可多選。
/// 回傳選好的坑 id（依列表順序）；點外面關掉＝null（不改）。不選任何坑＝所有坑。
///
/// ≥600（P-047）改開 popover：錨在觸發的「選擇」鈕下方，寬 320，頂端有指向它的小箭頭，
/// 最上面一行小字「不選＝所有坑」；< 600 照舊用 bottom sheet。
Future<List<String>?> showGoalPitSheet(
  BuildContext context, {
  required List<String> selected,
}) {
  if (WindowClass.of(context).isCompact) {
    return showThemedSheet<List<String>>(
      context: context,
      builder: (_) => _GoalPitSheet(selected: selected),
    );
  }
  final box = context.findRenderObject();
  Rect? anchor;
  if (box is RenderBox && box.hasSize) {
    anchor = box.localToGlobal(Offset.zero) & box.size;
  }
  return showGeneralDialog<List<String>>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: true,
    barrierLabel: context.l10n.commonClose,
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 160),
    pageBuilder: (ctx, _, _) =>
        _GoalPitPopover(anchor: anchor, selected: selected),
    transitionBuilder: (_, anim, _, child) =>
        FadeTransition(opacity: anim, child: child),
  );
}

class _GoalPitPopover extends StatelessWidget {
  const _GoalPitPopover({required this.anchor, required this.selected});
  final Rect? anchor;
  final List<String> selected;

  static const double width = 320;
  static const ValueKey<String> cardKey = ValueKey('goalPitPopover');

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final size = MediaQuery.sizeOf(context);
    final a = anchor;
    final left = a == null
        ? (size.width - width) / 2
        : (a.left - 8).clamp(16.0, size.width - width - 16);
    final top = a == null ? size.height * 0.2 : a.bottom + 12;
    final arrowX = a == null
        ? 40.0
        : (a.center.dx - left - 8).clamp(20.0, width - 36);
    return Stack(
      children: [
        Positioned(
          left: left,
          top: top,
          width: width,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: size.height - top - 16),
            child: Material(
              key: cardKey,
              color: t.surface,
              elevation: 12,
              shadowColor: const Color(0x38000000),
              borderRadius: BorderRadius.circular(18),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  if (a != null)
                    Positioned(
                      left: arrowX,
                      top: -7,
                      child: Transform.rotate(
                        angle: 0.7853981633974483,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: t.surface,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ),
                  Material(
                    color: t.surface,
                    borderRadius: BorderRadius.circular(18),
                    child: _GoalPitSheet(selected: selected, popover: true),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _GoalPitSheet extends ConsumerStatefulWidget {
  const _GoalPitSheet({required this.selected, this.popover = false});
  final List<String> selected;
  final bool popover;

  @override
  ConsumerState<_GoalPitSheet> createState() => _GoalPitSheetState();
}

class _GoalPitSheetState extends ConsumerState<_GoalPitSheet> {
  late final Set<String> _sel = {...widget.selected};

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = context.l10n;
    final pits = ref.watch(selectablePitsProvider).value ?? const <Pit>[];
    final tints = pitRowTints(context);
    final pop = widget.popover;
    final maxH = MediaQuery.sizeOf(context).height * 0.8;
    final body = ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxH),
      child: Padding(
        padding: pop
            ? const EdgeInsets.fromLTRB(0, 12, 0, 12)
            : const EdgeInsets.fromLTRB(20, 20, 20, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (pop)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 2, 18, 6),
                child: Text(
                  l.goalsPitAllHint,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: t.text4,
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  l.goalsPickPit,
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
            Flexible(
              child: Container(
                decoration: pop
                    ? const BoxDecoration()
                    : BoxDecoration(
                        color: t.surface,
                        border: Border.all(color: t.borderCard),
                        borderRadius: BorderRadius.circular(Radii.card),
                      ),
                clipBehavior: Clip.antiAlias,
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.symmetric(horizontal: pop ? 18 : 14),
                  itemCount: pits.length,
                  separatorBuilder: (_, _) =>
                      Divider(height: 1, thickness: 1, color: t.chipBg),
                  itemBuilder: (_, i) {
                    final p = pits[i];
                    final on = _sel.contains(p.id);
                    return _PitRow(
                      pit: p,
                      tint: tints[i % tints.length],
                      on: on,
                      onTap: () => setState(
                        () => on ? _sel.remove(p.id) : _sel.add(p.id),
                      ),
                    );
                  },
                ),
              ),
            ),
            SizedBox(height: pop ? 8 : 16),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: pop ? 14 : 0),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: t.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onPressed: () => Navigator.pop(context, [
                    for (final p in pits)
                      if (_sel.contains(p.id)) p.id,
                  ]),
                  child: Text(l.goalsPitSheetDone(_sel.length)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    return pop ? body : SafeArea(child: body);
  }
}

class _PitRow extends ConsumerWidget {
  const _PitRow({
    required this.pit,
    required this.tint,
    required this.on,
    required this.onTap,
  });
  final Pit pit;
  final Color tint;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final cover = ref.watch(coverFileProvider(pit.id)).value;
    final first = pit.name.trim().isEmpty
        ? ''
        : String.fromCharCode(pit.name.trim().runes.first);
    return Semantics(
      button: true,
      selected: on,
      label: pit.name,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            spacing: 12,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: PitCoverImage(
                    file: cover,
                    hasCoverRef: pit.hasCoverRef,
                    cacheWidth: 120,
                    placeholderColor: tint,
                    fallback: ColoredBox(
                      color: tint,
                      child: Center(
                        child: Text(
                          first,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: t.text2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    text: pit.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                    children: [
                      if (pit.status == PitStatus.shallow)
                        WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: t.chipBg,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              context.l10n.shallowName,
                              style: TextStyle(fontSize: 11, color: t.text3),
                            ),
                          ),
                        ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: on ? t.accent : null,
                  border: on ? null : Border.all(color: t.dashed, width: 2),
                ),
                child: on
                    ? const SvgIcon(
                        AppIcons.check,
                        size: 14,
                        strokeWidth: 3,
                        color: Colors.white,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
