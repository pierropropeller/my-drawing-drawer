import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../data/inspo_queries.dart';
import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../../theme/tokens.dart';
import '../album/album_actions.dart';
import '../album/move_sheet.dart' show GroupChoiceChips, PitChips;
import '../common/themed_sheet.dart';

/// 「放進坑」：開 [InspoPitSheet]，把選的廣場圖放進那個坑的參考圖（D-142）。
/// 回傳 true＝有放（或全部本來就在那個坑裡）；取消回傳 false。
Future<bool> placeInPit(
  BuildContext context,
  WidgetRef ref,
  List<String> materialIds,
) async {
  final target = await showThemedSheet<(Pit, String)>(
    context: context,
    builder: (_) => InspoPitSheet(count: materialIds.length),
  );
  if (target == null || !context.mounted) return false;
  final (pit, groupId) = target;
  final added = await ref
      .read(databaseProvider)
      .placeMaterials(materialIds, pit.id, groupId);
  if (!context.mounted) return true;
  showSnack(
    context,
    added.isEmpty
        ? context.l10n.inspoAlreadyInPit(pit.name)
        : context.l10n.inspoPlacedToast(pit.name),
    success: added.isNotEmpty,
  );
  return true;
}

/// 放進坑 sheet（InspoPitSheet）：只選一個坑（坑 chips，同「移動到」）＋該坑參考圖的分組。
class InspoPitSheet extends ConsumerStatefulWidget {
  const InspoPitSheet({super.key, required this.count});
  final int count;

  @override
  ConsumerState<InspoPitSheet> createState() => _InspoPitSheetState();
}

class _InspoPitSheetState extends ConsumerState<InspoPitSheet> {
  String? _pitId;
  String? _groupId;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = context.l10n;
    // 現坑＋淺坑（封存坑不列）；淺坑沒開參考圖的不列。
    final pits = [
      for (final p in ref.watch(selectablePitsProvider).value ?? const <Pit>[])
        if (p.sectionOpen(PitSectionKey.official)) p,
    ];
    final pit =
        pits.where((p) => p.id == _pitId).firstOrNull ?? pits.firstOrNull;
    final groups = pit == null
        ? const <OfficialGroup>[]
        : ref.watch(groupsProvider((pit.id, 'official'))).value ?? const [];
    final group = groups.any((g) => g.id == _groupId)
        ? _groupId
        : groups.lastOrNull?.id;
    final ok = pit != null && group != null;
    Widget label(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(2, 0, 0, 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: t.text2,
        ),
      ),
    );
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l.inspoPlaceInPit,
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    l.commonCountImages(widget.count),
                    style: TextStyle(fontSize: 12.5, color: t.text3),
                  ),
                ],
              ),
            ),
            label(l.moveReviewPitLabel),
            PitChips(
              pits: pits,
              selected: pit?.id ?? '',
              onSelected: (p) => setState(() {
                _pitId = p.id;
                _groupId = null;
              }),
            ),
            const SizedBox(height: 14),
            label(l.albumGroupLabel),
            GroupChoiceChips(
              options: [for (final g in groups) (g.id, g.name)],
              selected: group,
              onSelected: (id) => setState(() => _groupId = id),
            ),
            const SizedBox(height: 18),
            GestureDetector(
              key: const ValueKey('inspoPitDone'),
              onTap: ok ? () => Navigator.of(context).pop((pit, group)) : null,
              child: Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(vertical: 15),
                decoration: BoxDecoration(
                  color: ok ? t.accent : t.accent.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(Radii.button),
                ),
                child: Text(
                  l.commonDone,
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
    );
  }
}
