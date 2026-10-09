import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../l10n/l10n.dart';
import '../../share/share_inbox.dart';
import '../../state/providers.dart';
import '../../theme/tokens.dart';
import '../album/album_image.dart';
import '../common/dashed_box.dart';
import '../common/svg_icon.dart';
import 'share_icons.dart';

/// 「加入到」的六個位置。順序＝設計稿 3×2 格的順序。
enum ShareSection {
  official,
  fan,
  draft,
  idea,
  piece,
  junk;

  /// 草稿／腦洞／成圖要先填表單，按鈕是「下一步」；其餘直接存。
  bool get needsForm =>
      this == ShareSection.draft ||
      this == ShareSection.idea ||
      this == ShareSection.piece;

  static ShareSection? fromKey(String? key) {
    for (final s in values) {
      if (s.name == key) return s;
    }
    return null;
  }

  String label(AppLocalizations l) => switch (this) {
    official => l.pitsOfficial,
    fan => l.pitsFanArt,
    draft => l.goalsKindDraft,
    idea => l.goalsKindIdea,
    piece => l.goalsKindPiece,
    junk => l.junkTitle,
  };

  CategoryColor color(AppTokens t) => switch (this) {
    official => t.official,
    fan => t.fanArt,
    draft => t.draft,
    idea => t.idea,
    piece => t.piece,
    junk => CategoryColor(t.chipBg, t.text3),
  };

  (String, double) get icon => switch (this) {
    official || fan || junk => (ShareIcons.folder, 1.8),
    draft => (ShareIcons.pen, 1.7),
    idea => (ShareIcons.bulb, 1.7),
    piece => (ShareIcons.img, 1.7),
  };
}

enum ShareAction { add, next, newPit }

/// sheet 的結果：按了什麼，以及當時選的坑／位置／分組。
class ShareChoice {
  const ShareChoice(this.action, {this.pitId, this.section, this.groupId});
  final ShareAction action;
  final String? pitId;
  final ShareSection? section;
  final String? groupId;
}

/// 分享進來的「加入到」bottom sheet（ShareImport，D-053）。
Future<ShareChoice?> showShareSheet(
  BuildContext context, {
  required List<String> paths,
  String? pitId,
  ShareSection? section,
  String? groupId,
}) {
  final t = context.tokens;
  return showModalBottomSheet<ShareChoice>(
    context: context,
    // 全域的 sheet：蓋在所有分頁之上。
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: t.ground,
    barrierColor: const Color(0xFF1E1A17).withValues(alpha: 0.42),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (_) => ShareSheet(
      paths: paths,
      initialPitId: pitId,
      initialSection: section,
      initialGroupId: groupId,
    ),
  );
}

class ShareSheet extends ConsumerStatefulWidget {
  const ShareSheet({
    super.key,
    required this.paths,
    this.initialPitId,
    this.initialSection,
    this.initialGroupId,
  });

  final List<String> paths;

  /// 沒指定就用上一次用過的坑／位置。
  final String? initialPitId;
  final ShareSection? initialSection;
  final String? initialGroupId;

  @override
  ConsumerState<ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends ConsumerState<ShareSheet> {
  late String? _pitId;
  late ShareSection _section;
  String? _groupId;

  @override
  void initState() {
    super.initState();
    final memory = ref.read(shareMemoryProvider);
    _pitId = widget.initialPitId ?? memory.lastPit;
    _section =
        widget.initialSection ??
        ShareSection.fromKey(memory.lastSection) ??
        ShareSection.official;
    _groupId = widget.initialGroupId;
  }

  void _finish(
    ShareAction action,
    String? pitId,
    ShareSection section,
    String? group,
  ) {
    ref.read(shareMemoryProvider).save(pitId: pitId, section: section.name);
    Navigator.of(
      context,
    ).pop(ShareChoice(action, pitId: pitId, section: section, groupId: group));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = context.l10n;
    final pits = ref.watch(pitsProvider(false)).value ?? const <Pit>[];
    // 選中的坑不在列表（已封存、還沒載入）時退回第一個。
    final pit =
        pits.where((p) => p.id == _pitId).firstOrNull ?? pits.firstOrNull;
    // 沒開啟雜物的坑不列雜物（和「移動到」一致）；選到了就退回官方圖冊。
    final junkOk = pit?.junkEnabled == true;
    final sections = [
      for (final s in ShareSection.values)
        if (s != ShareSection.junk || junkOk) s,
    ];
    final section = sections.contains(_section)
        ? _section
        : ShareSection.official;
    final groups = pit == null || section != ShareSection.official
        ? const <OfficialGroup>[]
        : ref.watch(groupsProvider((pit.id, 'official'))).value ?? const [];
    final group =
        groups.where((g) => g.id == _groupId).firstOrNull ?? groups.firstOrNull;
    final canGo =
        pit != null && (section != ShareSection.official || group != null);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(0, 20, 0, 26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l.shareTitle,
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    l.commonCountImages(widget.paths.length),
                    style: TextStyle(fontSize: 12.5, color: t.text3),
                  ),
                ],
              ),
            ),
            _Thumbs(paths: widget.paths),
            const SizedBox(height: 18),
            _Label(l.shareFieldPit),
            SizedBox(
              height: 34,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  for (final p in pits)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _PitChip(
                        pit: p,
                        selected: p.id == pit?.id,
                        onTap: () => setState(() {
                          _pitId = p.id;
                          _groupId = null;
                        }),
                      ),
                    ),
                  _NewPitChip(
                    label: l.pitsNewTitle,
                    onTap: () => _finish(
                      ShareAction.newPit,
                      pit?.id,
                      section,
                      group?.id,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _Label(l.shareFieldPosition),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: LayoutBuilder(
                builder: (_, c) {
                  final w = (c.maxWidth - 16) / 3;
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final s in sections)
                        SizedBox(
                          width: w,
                          child: _SectionCell(
                            section: s,
                            selected: s == section,
                            onTap: () => setState(() => _section = s),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
            if (section == ShareSection.official && groups.isNotEmpty) ...[
              const SizedBox(height: 16),
              _Label(l.albumGroupLabel),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final g in groups)
                      _GroupChip(
                        label: g.name,
                        selected: g.id == group?.id,
                        onTap: () => setState(() => _groupId = g.id),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: GestureDetector(
                onTap: canGo
                    ? () => _finish(
                        section.needsForm ? ShareAction.next : ShareAction.add,
                        pit.id,
                        section,
                        group?.id,
                      )
                    : null,
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  decoration: BoxDecoration(
                    color: canGo ? t.accent : t.accent.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(Radii.button),
                  ),
                  child: Text(
                    section.needsForm ? l.shareNext : l.shareAdd,
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
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(22, 0, 20, 8),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: context.tokens.text2,
      ),
    ),
  );
}

/// 分享進來的縮圖列（60×60，圓角 10，多張可橫向捲動）。
class _Thumbs extends StatelessWidget {
  const _Thumbs({required this.paths});
  final List<String> paths;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return SizedBox(
      height: 60,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: paths.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) => ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: 60,
            height: 60,
            child: Image.file(
              File(paths[i]),
              key: ValueKey('shareThumb$i'),
              fit: BoxFit.cover,
              cacheWidth: 180,
              errorBuilder: (_, _, _) => Container(
                color: t.chipBg,
                alignment: Alignment.center,
                child: SvgIcon(
                  ShareIcons.img,
                  size: 18,
                  color: t.text4,
                  strokeWidth: 1.5,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PitChip extends ConsumerWidget {
  const _PitChip({
    required this.pit,
    required this.selected,
    required this.onTap,
  });
  final Pit pit;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final cover = ref.watch(coverFileProvider(pit.id)).value;
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(4, 4, 14, 4),
          decoration: BoxDecoration(
            color: selected ? t.accent : t.surface,
            borderRadius: BorderRadius.circular(Radii.chip),
            border: Border.all(color: selected ? t.accent : t.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 26,
                height: 26,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: t.official.bg,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: cover == null
                    ? null
                    : StoredImage(cover, cacheWidth: 80),
              ),
              const SizedBox(width: 7),
              Text(
                pit.name,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : t.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NewPitChip extends StatelessWidget {
  const _NewPitChip({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: DashedBox(
          color: t.dashed,
          radius: Radii.chip,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgIcon(
                ShareIcons.plus,
                size: 14,
                color: t.dashedText,
                strokeWidth: 2,
              ),
              const SizedBox(width: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: t.dashedText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionCell extends StatelessWidget {
  const _SectionCell({
    required this.section,
    required this.selected,
    required this.onTap,
  });
  final ShareSection section;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = section.color(t);
    final (icon, stroke) = section.icon;
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(4, 12, 4, 10),
          decoration: BoxDecoration(
            color: selected ? t.accentSoft : t.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? t.accent : t.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: c.bg,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: SvgIcon(
                  icon,
                  size: 19,
                  color: c.fg,
                  strokeWidth: stroke,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                section.label(context.l10n),
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

class _GroupChip extends StatelessWidget {
  const _GroupChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? t.accent : t.surface,
          borderRadius: BorderRadius.circular(Radii.chip),
          border: Border.all(color: selected ? t.accent : t.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : t.text2,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
