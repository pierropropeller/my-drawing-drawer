import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../data/junk_queries.dart';
import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../../theme/tokens.dart';
import '../common/app_icons.dart';
import 'album_image.dart';
import '../common/svg_icon.dart';

/// 移動的目的地：哪一坑、哪一格，以及（官方圖冊＝分組／好看同人圖＝出處）。
class MoveTarget {
  const MoveTarget(this.cell, this.groupId, {this.pitId, this.pitName});
  final AlbumCell cell;
  final String? groupId;

  /// 跨坑移動時的目標坑（D-054）；留在原坑＝null，直接當 `moveAlbumImages(targetPitId:)` 用。
  final String? pitId;

  /// 跨坑時的目標坑名（提示用）。
  final String? pitName;

  bool get crossPit => pitId != null;
}

String albumCellLabel(AppLocalizations l, AlbumCell c) => switch (c) {
  AlbumCell.official => l.pitsOfficial,
  AlbumCell.fan => l.pitsFanArt,
  AlbumCell.junk => l.junkTitle,
};

/// 多選「移動」的 bottom sheet「移動到」（MoveSheet，D-044）。
///
/// [from] 是目前所在的格；[initialGroupId] 是目前所選圖共同的分組（沒有共同分組就不傳）。
/// 取消回傳 null。
Future<MoveTarget?> showMoveSheet(
  BuildContext context, {
  required String pitId,
  required AlbumCell from,
  required int count,
  String? initialGroupId,
}) {
  final t = context.tokens;
  return showModalBottomSheet<MoveTarget>(
    context: context,
    isScrollControlled: true,
    backgroundColor: t.ground,
    barrierColor: const Color(0xFF1E1A17).withValues(alpha: 0.42),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (_) => MoveSheet(
      pitId: pitId,
      from: from,
      count: count,
      initialGroupId: initialGroupId,
    ),
  );
}

class MoveSheet extends ConsumerStatefulWidget {
  const MoveSheet({
    super.key,
    required this.pitId,
    required this.from,
    required this.count,
    this.initialGroupId,
  });

  final String pitId;
  final AlbumCell from;
  final int count;
  final String? initialGroupId;

  @override
  ConsumerState<MoveSheet> createState() => _MoveSheetState();
}

class _MoveSheetState extends ConsumerState<MoveSheet> {
  late AlbumCell _cell = widget.from;
  late String _pitId = widget.pitId; // 目標坑，預設是目前所在的坑
  late String? _officialGroup = widget.from == AlbumCell.official
      ? widget.initialGroupId
      : null;
  late String? _fanGroup = widget.from == AlbumCell.fan
      ? widget.initialGroupId
      : null;

  /// 目標格的分組。從別格移進官方圖冊時，沒選就是第一個分組（資料層也是這樣處理）。
  String? _groupFor(List<(String, String)> officialGroups) {
    if (_cell == AlbumCell.fan) return _fanGroup;
    if (_cell != AlbumCell.official) return null;
    return _officialGroup ??
        ((widget.from != AlbumCell.official || _crossPit) &&
                officialGroups.isNotEmpty
            ? officialGroups.first.$1
            : null);
  }

  bool get _crossPit => _pitId != widget.pitId;

  /// 換坑：分組／出處屬於舊的坑，一律清掉；目標坑沒開雜物就退回官方圖冊。
  void _pickPit(String id, bool junkEnabled) => setState(() {
    if (id == _pitId) return;
    _pitId = id;
    _officialGroup = null;
    _fanGroup = null;
    final junkOk = junkEnabled || (widget.from == AlbumCell.junk && !_crossPit);
    if (_cell == AlbumCell.junk && !junkOk) _cell = AlbumCell.official;
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final pit = ref.watch(pitProvider(_pitId)).value;
    final current = ref.watch(pitProvider(widget.pitId)).value;
    // 未封存的坑；目前所在的坑就算已封存也要列出（預設選它）。
    final pits = [...?ref.watch(pitsProvider(false)).value];
    if (current != null && !pits.any((p) => p.id == current.id)) {
      pits.insert(0, current);
    }
    final official =
        ref.watch(groupsProvider((_pitId, 'official'))).value ?? const [];
    final fan = ref.watch(groupsProvider((_pitId, 'fan'))).value ?? const [];
    final officialOpts = [for (final g in official) (g.id, g.name)];
    final fanOpts = [for (final g in fan) (g.id, g.name)];
    final group = _groupFor(officialOpts);
    // 同一格內只能換分組／出處；沒有選分組就沒事可做。
    // 跨坑時同一格也能移（官方→官方、雜物→雜物），不需要先選分組。
    final canDone =
        _crossPit ||
        _cell != widget.from ||
        (_cell != AlbumCell.junk && group != null);
    // 目標坑沒開雜物時不列出（入口也不會出現），免得圖移進去就找不到；
    // 本來就在雜物裡、且留在原坑時照舊列出。
    final cells = [
      AlbumCell.official,
      AlbumCell.fan,
      if (pit?.junkEnabled == true ||
          (widget.from == AlbumCell.junk && !_crossPit))
        AlbumCell.junk,
    ];
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
                    context.l10n.albumMoveTo,
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    context.l10n.commonCountImages(widget.count),
                    style: TextStyle(fontSize: 12.5, color: t.text3),
                  ),
                ],
              ),
            ),
            const _SectionLabel(bottom: 8),
            _PitChips(
              pits: pits,
              selected: _pitId,
              onSelected: (p) => _pickPit(p.id, p.junkEnabled),
            ),
            const SizedBox(height: 14),
            const _SectionLabel(position: true),
            for (final c in cells)
              _CellRow(
                cell: c,
                selected: _cell == c,
                onTap: () => setState(() => _cell = c),
                chips: _cell != c
                    ? null
                    : switch (c) {
                        AlbumCell.official => _GroupChips(
                          options: officialOpts,
                          selected: group,
                          onSelected: (id) =>
                              setState(() => _officialGroup = id),
                        ),
                        AlbumCell.fan when fanOpts.isNotEmpty => _GroupChips(
                          options: fanOpts,
                          selected: _fanGroup,
                          // 再點一次已選的出處＝取消（同人圖的出處可留空）。
                          onSelected: (id) => setState(
                            () => _fanGroup = id == _fanGroup ? null : id,
                          ),
                        ),
                        _ => null,
                      },
              ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: canDone
                  ? () => Navigator.of(context).pop(
                      MoveTarget(
                        _cell,
                        group,
                        pitId: _crossPit ? _pitId : null,
                        pitName: _crossPit ? pit?.name : null,
                      ),
                    )
                  : null,
              child: Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(vertical: 15),
                decoration: BoxDecoration(
                  color: canDone ? t.accent : t.accent.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(Radii.button),
                ),
                child: Text(
                  context.l10n.commonDone,
                  style: TextStyle(
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

/// 「坑」「位置」小標：13/600、text2。
class _SectionLabel extends StatelessWidget {
  const _SectionLabel({this.position = false, this.bottom = 0});
  final bool position;
  final double bottom;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(2, 0, 0, bottom),
    child: Text(
      position
          ? context.l10n.moveReviewPositionLabel
          : context.l10n.moveReviewPitLabel,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: context.tokens.text2,
      ),
    ),
  );
}

/// 坑 chips（橫向捲動）：26px 圓形封面＋坑名；選中＝主色底。
class _PitChips extends ConsumerWidget {
  const _PitChips({
    required this.pits,
    required this.selected,
    required this.onSelected,
  });
  final List<Pit> pits;
  final String selected;
  final ValueChanged<Pit> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    // 抵銷 sheet 的左右 padding（20），讓捲動時 chips 貼齊螢幕邊。
    return SizedBox(
      height: 36,
      child: LayoutBuilder(
        builder: (_, c) => OverflowBox(
          minWidth: c.maxWidth + 40,
          maxWidth: c.maxWidth + 40,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            itemCount: pits.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final p = pits[i];
              final on = p.id == selected;
              final cover = ref.watch(coverFileProvider(p.id)).value;
              return GestureDetector(
                onTap: () => onSelected(p),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(4, 4, 14, 4),
                  decoration: BoxDecoration(
                    color: on ? t.accent : t.surface,
                    borderRadius: BorderRadius.circular(Radii.chip),
                    border: Border.all(color: on ? t.accent : t.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 7,
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: t.chipBg,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: cover == null
                            ? null
                            : StoredImage(cover, cacheWidth: 80),
                      ),
                      Text(
                        p.name,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: on ? Colors.white : t.ink,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CellRow extends StatelessWidget {
  const _CellRow({
    required this.cell,
    required this.selected,
    required this.onTap,
    this.chips,
  });
  final AlbumCell cell;
  final bool selected;
  final VoidCallback onTap;
  final Widget? chips;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final color = switch (cell) {
      AlbumCell.official => t.official,
      AlbumCell.fan => t.fanArt,
      AlbumCell.junk => CategoryColor(t.chipBg, t.text3),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: t.border.withValues(alpha: .6)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            selected: selected,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: color.bg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: SvgIcon(
                      AppIcons.folder,
                      size: 18,
                      color: color.fg,
                      strokeWidth: 1.8,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      albumCellLabel(context.l10n, cell),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected ? t.accent : t.dashed,
                        width: 2,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: selected
                        ? Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: t.accent,
                            ),
                          )
                        : null,
                  ),
                ],
              ),
            ),
          ),
          if (chips != null)
            Padding(
              padding: const EdgeInsets.only(left: 46, top: 10, bottom: 2),
              child: chips,
            ),
        ],
      ),
    );
  }
}

class _GroupChips extends StatelessWidget {
  const _GroupChips({
    required this.options,
    required this.selected,
    required this.onSelected,
  });
  final List<(String, String)> options;
  final String? selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final o in options)
          GestureDetector(
            onTap: () => onSelected(o.$1),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: selected == o.$1 ? t.accent : t.surface,
                borderRadius: BorderRadius.circular(Radii.chip),
                border: Border.all(
                  color: selected == o.$1 ? t.accent : t.border,
                ),
              ),
              child: Text(
                o.$2,
                style: TextStyle(
                  color: selected == o.$1 ? Colors.white : t.text2,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
