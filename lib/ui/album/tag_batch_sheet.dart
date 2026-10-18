import '../common/themed_sheet.dart';

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/batch_tag_queries.dart';
import '../../data/database.dart';
import '../../data/junk_queries.dart';
import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../../theme/tokens.dart';
import '../common/app_icons.dart';
import '../common/dashed_box.dart';
import '../common/svg_icon.dart';
import '../entity/entity_widgets.dart';
import 'album_actions.dart';
import 'album_icons.dart';

/// 多選後的「tag」bottom sheet（FanArtTagSheet，D-060）。
///
/// 列出坑內所有 tag，三種狀態：實色＋勾＝選取的圖全部都有；虛線框＋橫線＝部分有；
/// 白底＝都沒有。點一下：部分有／都沒有 → 全部加上；全部有 → 全部移除。
/// 「完成」才寫入資料庫（[AppDatabase.applyBatchTags]）；回傳 true＝有套用。
Future<bool?> showBatchTagSheet(
  BuildContext context, {
  required String pitId,
  required AlbumCell cell,
  required List<String> ids,
}) {
  return showThemedSheet<bool>(
    context: context,
    builder: (_) => BatchTagSheet(pitId: pitId, cell: cell, ids: ids),
  );
}

/// 不是 [AlbumCell] 的對象（推活）用的接法：自己提供三態的來源、套用與張數文字。
class BatchTagBackend {
  const BatchTagBackend({
    required this.watch,
    required this.apply,
    required this.countText,
  });
  final Stream<List<TagCoverageEntry>> Function(
    AppDatabase db,
    List<String> ids,
  )
  watch;
  final Future<void> Function(
    AppDatabase db,
    List<String> ids, {
    required List<String> add,
    required List<String> remove,
    required List<String> newNames,
  })
  apply;
  final String Function(AppLocalizations l, int count) countText;
}

class BatchTagSheet extends ConsumerStatefulWidget {
  const BatchTagSheet({
    super.key,
    required this.pitId,
    this.cell,
    this.backend,
    required this.ids,
  }) : assert(cell != null || backend != null);

  final String pitId;
  final AlbumCell? cell;

  /// 有值就改用它（推活）；否則照 [cell]。
  final BatchTagBackend? backend;
  final List<String> ids;

  @override
  ConsumerState<BatchTagSheet> createState() => _BatchTagSheetState();
}

class _BatchTagSheetState extends ConsumerState<BatchTagSheet> {
  /// 暫存的點擊：tag id → true＝全部加上、false＝全部移除。按「完成」才寫入。
  final Map<String, bool> _ops = {};

  /// 在 sheet 裡新增、還沒建立的 tag 名稱（按「完成」時一起建立並加到每一張）。
  final List<String> _newNames = [];

  bool _busy = false;

  /// [BatchTagBackend] 的即時資料。
  StreamSubscription<List<TagCoverageEntry>>? _sub;
  List<TagCoverageEntry> _backendEntries = const [];

  @override
  void initState() {
    super.initState();
    final b = widget.backend;
    if (b != null) {
      _sub = b.watch(ref.read(databaseProvider), widget.ids).listen((v) {
        if (mounted) setState(() => _backendEntries = v);
      });
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  TagCoverage _shown(TagCoverageEntry e) => switch (_ops[e.tag.id]) {
    true => TagCoverage.all,
    false => TagCoverage.none,
    null => e.coverage,
  };

  /// 點一下：目前不是「全部有」→ 全部加上；是 → 全部移除。
  void _tap(TagCoverageEntry e) => setState(() {
    _ops[e.tag.id] = _shown(e) != TagCoverage.all;
  });

  Future<void> _addTag(List<TagCoverageEntry> entries) async {
    final raw = await promptText(context, title: context.l10n.tagsAdd);
    if (raw == null || !mounted) return;
    final name = raw.trim().replaceFirst(RegExp(r'^#+'), '').trim();
    if (name.isEmpty) return;
    setState(() {
      final same = entries.where((e) => e.tag.name == name).firstOrNull;
      if (same != null) {
        _ops[same.tag.id] = true;
      } else if (!_newNames.contains(name)) {
        _newNames.add(name);
      }
    });
  }

  Future<void> _done(List<TagCoverageEntry> entries) async {
    if (_busy) return;
    _busy = true;
    final db = ref.read(databaseProvider);
    final add = [
      for (final e in entries)
        if (_ops[e.tag.id] == true) e.tag.id,
    ];
    final remove = [
      for (final e in entries)
        if (_ops[e.tag.id] == false) e.tag.id,
    ];
    final changed = add.isNotEmpty || remove.isNotEmpty || _newNames.isNotEmpty;
    if (changed && widget.backend != null) {
      await widget.backend!.apply(
        db,
        widget.ids,
        add: add,
        remove: remove,
        newNames: _newNames,
      );
    } else if (changed) {
      await db.applyBatchTags(
        widget.cell!,
        widget.ids,
        addTagIds: add,
        removeTagIds: remove,
        newTagNames: _newNames,
      );
    }
    if (mounted) Navigator.of(context).pop(changed);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = context.l10n;
    final media = MediaQuery.of(context);
    final key = ([...widget.ids]..sort()).join(',');
    final entries = widget.backend != null
        ? _backendEntries
        : ref.watch(tagCoverageProvider((widget.cell!, key))).value ?? const [];
    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: math.min(
            media.size.height * 0.88,
            media.size.height - media.viewInsets.bottom - media.padding.top,
          ),
        ),
        child: SafeArea(
          child: Padding(
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
                        l.shareMoveTag,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        widget.backend?.countText(l, widget.ids.length) ??
                            l.commonCountImages(widget.ids.length),
                        style: TextStyle(fontSize: 12.5, color: t.text3),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final e in entries)
                          _TagStateChip(
                            name: e.tag.name,
                            state: _shown(e),
                            onTap: () => _tap(e),
                          ),
                        for (final n in _newNames)
                          _TagStateChip(
                            name: n,
                            state: TagCoverage.all,
                            onTap: () => setState(() => _newNames.remove(n)),
                          ),
                        DashedAddChip(
                          semanticLabel: l.tagsAdd,
                          onTap: () => _addTag(entries),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () => _done(entries),
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
        ),
      ),
    );
  }
}

/// 三態 tag chip：全部有＝主色實底＋勾；部分有＝虛線框＋橫線；都沒有＝白底。
class _TagStateChip extends StatelessWidget {
  const _TagStateChip({
    required this.name,
    required this.state,
    required this.onTap,
  });
  final String name;
  final TagCoverage state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = context.l10n;
    final (Color fg, String? icon) = switch (state) {
      TagCoverage.all => (Colors.white, AppIcons.check),
      TagCoverage.some => (t.accent, AlbumIcons.dash),
      TagCoverage.none => (t.text2, null),
    };
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          SvgIcon(icon, size: 14, color: fg, strokeWidth: 2.4),
          const SizedBox(width: 4),
        ],
        Text(
          '#$name',
          style: TextStyle(
            color: fg,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
    return Semantics(
      button: true,
      label: switch (state) {
        TagCoverage.all => l.shareMoveTagStateAll,
        TagCoverage.some => l.shareMoveTagStateSome,
        TagCoverage.none => l.shareMoveTagStateNone,
      },
      child: GestureDetector(
        key: ValueKey('batchTag-$name-${state.name}'),
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: switch (state) {
          TagCoverage.some => DashedBox(
            color: t.accent,
            radius: Radii.chip,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            child: content,
          ),
          _ => Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: state == TagCoverage.all ? t.accent : t.surface,
              borderRadius: BorderRadius.circular(Radii.chip),
              border: Border.all(
                color: state == TagCoverage.all ? t.accent : t.border,
              ),
            ),
            child: content,
          ),
        },
      ),
    );
  }
}
