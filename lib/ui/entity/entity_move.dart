import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../data/entity_move_queries.dart';
import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../../theme/tokens.dart';
import '../album/album_actions.dart' show showSnack;
import '../common/app_icons.dart';
import '../common/media_mini.dart';
import '../common/media_source.dart';
import '../common/svg_icon.dart';
import '../common/themed_sheet.dart';

/// 腦洞／摸魚／成圖多選的「移動」（CR 2026-11-09）：
/// ① `EntityMoveSheet` 選坑 → ② 有關聯才出 `MoveUnlinkConfirm` → ③ 目標坑缺 tag 才出
/// `MoveTagConfirm` → 移動、出提示條。回傳 true＝真的移動了（呼叫端退出多選）。
Future<bool> moveEntitiesToOtherPit(
  BuildContext context,
  WidgetRef ref, {
  required OwnerType type,
  required String pitId,
  required List<String> ids,
}) async {
  if (ids.isEmpty) return false;
  final l = context.l10n;
  final target = await showThemedSheet<Pit>(
    context: context,
    builder: (_) => _EntityMoveSheet(
      pitId: pitId,
      countText: switch (type) {
        OwnerType.idea => l.entityMoveCountIdea(ids.length),
        OwnerType.draft => l.entityMoveCountDraft(ids.length),
        _ => l.commonCountImages(ids.length),
      },
    ),
  );
  // 沒換坑＝直接關閉。
  if (target == null || target.id == pitId || !context.mounted) return false;
  final db = ref.read(databaseProvider);

  final links = await db.crossPitLinksOf(type, ids);
  if (!context.mounted) return false;
  if (links.isNotEmpty) {
    final fromName = ref.read(pitProvider(pitId)).value?.name ?? '';
    final ok = await showMoveUnlinkConfirm(
      context,
      targetPit: target.name,
      fromPit: fromName,
      items: links,
    );
    if (!ok || !context.mounted) return false;
  }

  final missing = await db.missingTagNamesForMove(
    tagTargetOf(type),
    ids,
    target.id,
  );
  if (!context.mounted) return false;
  var createTags = true;
  if (missing.isNotEmpty) {
    final choice = await showMoveTagConfirm(
      context,
      pitName: target.name,
      names: missing,
    );
    if (choice == null || !context.mounted) return false;
    createTags = choice;
  }

  await db.moveEntitiesToPit(
    type,
    ids,
    target.id,
    createMissingTags: createTags,
  );
  if (context.mounted) {
    showSnack(
      context,
      context.l10n.entityMovedToPit(ids.length, target.name),
      success: true,
    );
  }
  return true;
}

/// ① 選坑（`EntityMoveSheet`）：標題「移動到」＋數量、「坑」chips（換行排）、「完成」。
/// 預設選目前所在的坑；選它按「完成」＝直接關閉（回傳 null）。
class _EntityMoveSheet extends ConsumerStatefulWidget {
  const _EntityMoveSheet({required this.pitId, required this.countText});
  final String pitId;
  final String countText;

  @override
  ConsumerState<_EntityMoveSheet> createState() => _EntityMoveSheetState();
}

class _EntityMoveSheetState extends ConsumerState<_EntityMoveSheet> {
  late String _pitId = widget.pitId;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = context.l10n;
    final current = ref.watch(pitProvider(widget.pitId)).value;
    // 現坑＋淺坑（封存坑不列，D-088）；目前所在的坑就算已封存也要列出（預設選它）。
    final pits = [...?ref.watch(selectablePitsProvider).value];
    if (current != null && !pits.any((p) => p.id == current.id)) {
      pits.insert(0, current);
    }
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
                    l.albumMoveTo,
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    widget.countText,
                    style: TextStyle(fontSize: 12.5, color: t.text3),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 0, 0, 8),
              child: Text(
                l.moveReviewPitLabel,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: t.text2,
                ),
              ),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final p in pits)
                  _PitChip(
                    key: ValueKey('entityMovePit-${p.id}'),
                    name: p.name,
                    selected: p.id == _pitId,
                    onTap: () => setState(() => _pitId = p.id),
                  ),
              ],
            ),
            const SizedBox(height: 22),
            GestureDetector(
              key: const ValueKey('entityMoveDone'),
              onTap: () {
                final pick = pits.where((p) => p.id == _pitId).firstOrNull;
                Navigator.of(context).pop(_pitId == widget.pitId ? null : pick);
              },
              child: Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(vertical: 15),
                decoration: BoxDecoration(
                  color: t.accent,
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

class _PitChip extends StatelessWidget {
  const _PitChip({
    super.key,
    required this.name,
    required this.selected,
    required this.onTap,
  });
  final String name;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final fg = selected ? Colors.white : t.ink;
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(11, 7, 14, 7),
          decoration: BoxDecoration(
            color: selected ? t.accent : t.surface,
            borderRadius: BorderRadius.circular(Radii.chip),
            border: Border.all(color: selected ? t.accent : t.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgIcon(AppIcons.folder, size: 16, color: fg, strokeWidth: 1.8),
              const SizedBox(width: 6),
              Text(
                name,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 置中確認框的外框（同 `TrashClearConfirm`、`R18SettingsOff`）：白底圓角 20、襯線標題 18、
/// 內文 14、底下一排文字按鈕。iPad 沿用手機的樣子（P-037）。
Future<T?> _showMoveDialog<T>(
  BuildContext context, {
  required Key key,
  required String title,
  required List<Widget> body,
  required List<Widget> Function(BuildContext ctx) buttons,
}) => showDialog<T>(
  context: context,
  barrierColor: const Color(0x6B1E1A17),
  builder: (ctx) {
    final t = ctx.tokens;
    return Dialog(
      key: key,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      constraints: const BoxConstraints(maxWidth: 360),
      backgroundColor: t.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(ctx).textTheme.headlineSmall
                    ?.copyWith(fontSize: 18),
              ),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: body,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(children: buttons(ctx)),
            ],
          ),
        ),
      ),
    );
  },
);

Widget _dialogButton(
  BuildContext ctx, {
  required Key key,
  required String label,
  required VoidCallback onTap,
  bool primary = false,
}) {
  final t = ctx.tokens;
  return TextButton(
    key: key,
    onPressed: onTap,
    style: TextButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      minimumSize: const Size(0, 40),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 14.5,
        fontWeight: primary ? FontWeight.w700 : FontWeight.w600,
        color: primary ? t.piece.fg : t.text2,
      ),
    ),
  );
}

/// ② 斷開關聯確認（`MoveUnlinkConfirm`）：列出會斷開的關聯（種類標籤＋標題；沒標題用淺色內文；
/// 有圖的右邊放第一張小圖）。回傳 true＝移動。
Future<bool> showMoveUnlinkConfirm(
  BuildContext context, {
  required String targetPit,
  required String fromPit,
  required List<MoveLinkedItem> items,
}) async {
  final l = context.l10n;
  final t = context.tokens;
  final ok = await _showMoveDialog<bool>(
    context,
    key: const ValueKey('moveUnlinkConfirm'),
    title: l.entityMoveUnlinkTitle(targetPit),
    body: [
      const SizedBox(height: 10),
      Text(
        l.entityMoveUnlinkBody(fromPit),
        style: TextStyle(fontSize: 14, height: 1.65, color: t.text2),
      ),
      const SizedBox(height: 10),
      for (final (i, it) in items.indexed) ...[
        if (i > 0) const SizedBox(height: 6),
        _LinkRow(item: it),
      ],
    ],
    buttons: (ctx) => [
      const Spacer(),
      _dialogButton(
        ctx,
        key: const ValueKey('moveUnlinkCancel'),
        label: ctx.l10n.commonCancel,
        onTap: () => Navigator.pop(ctx, false),
      ),
      const SizedBox(width: 4),
      _dialogButton(
        ctx,
        key: const ValueKey('moveUnlinkOk'),
        label: ctx.l10n.commonMove,
        primary: true,
        onTap: () => Navigator.pop(ctx, true),
      ),
    ],
  );
  return ok == true;
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({required this.item});
  final MoveLinkedItem item;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = context.l10n;
    final title = item.title?.trim() ?? '';
    final body = (item.body ?? '').trim().split('\n').first;
    final hasTitle = title.isNotEmpty;
    final text = hasTitle ? title : (body.isNotEmpty ? body : l.commonNoTitle);
    final img = item.firstImage;
    return Container(
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
      decoration: BoxDecoration(
        color: t.ground,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: t.chipBg,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              switch (item.type) {
                OwnerType.idea => l.searchCategoryIdea,
                OwnerType.draft => l.searchCategoryDraft,
                _ => l.searchCategoryPiece,
              },
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: t.text2,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13.5,
                color: hasTitle ? t.ink : t.text3,
              ),
            ),
          ),
          if (img != null) ...[
            const SizedBox(width: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 36,
                height: 36,
                child: MiniMediaThumb(
                  MediaSource.fromImageRef(img),
                  cacheWidth: 120,
                  animate: false,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// ③ 目標坑缺 tag（`MoveTagConfirm`）：「取消」靠左，「不保留 tag」「在「坑B」新增 tag」靠右。
/// 回傳 null＝取消、false＝不保留、true＝新增。圖片跨坑移動也用這個。
Future<bool?> showMoveTagConfirm(
  BuildContext context, {
  required String pitName,
  required List<String> names,
}) {
  final l = context.l10n;
  final t = context.tokens;
  return _showMoveDialog<bool>(
    context,
    key: const ValueKey('moveTagConfirm'),
    title: l.moveTagMissingTitle(pitName),
    body: [
      const SizedBox(height: 10),
      Text(
        l.moveTagMissingBody(names.length, pitName),
        style: TextStyle(fontSize: 14, height: 1.65, color: t.text2),
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final n in names)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
              decoration: BoxDecoration(
                color: t.chipBg,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '#$n',
                style: TextStyle(fontSize: 13, color: t.text2),
              ),
            ),
        ],
      ),
    ],
    buttons: (ctx) => [
      _dialogButton(
        ctx,
        key: const ValueKey('moveTagCancel'),
        label: ctx.l10n.commonCancel,
        onTap: () => Navigator.pop(ctx),
      ),
      const Spacer(),
      _dialogButton(
        ctx,
        key: const ValueKey('moveTagDrop'),
        label: ctx.l10n.moveTagDrop,
        onTap: () => Navigator.pop(ctx, false),
      ),
      const SizedBox(width: 4),
      Flexible(
        child: _dialogButton(
          ctx,
          key: const ValueKey('moveTagCreate'),
          label: ctx.l10n.moveTagCreate(pitName),
          primary: true,
          onTap: () => Navigator.pop(ctx, true),
        ),
      ),
    ],
  );
}
