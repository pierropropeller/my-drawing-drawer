import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../data/goal_queries.dart';
import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../../theme/tokens.dart';
import '../common/app_icons.dart';
import '../common/svg_icon.dart';
import '../common/timeline.dart';
import 'day_add_sheet.dart';
import 'goal_widgets.dart';
import '../entity/draft_detail_page.dart';
import '../entity/draft_form_page.dart';
import '../entity/entity_widgets.dart';
import '../entity/idea_detail_page.dart';
import '../entity/idea_form_page.dart';
import '../entity/piece_detail_page.dart';
import '../entity/piece_form_page.dart';

/// 日（Day）：時間軸分頁，顯示今天。
class DayView extends StatelessWidget {
  const DayView({super.key, this.onYearChanged});
  final ValueChanged<int>? onYearChanged;

  @override
  Widget build(BuildContext context) => DayPage(
    day: DateTime.now(),
    embedded: true,
    onYearChanged: onYearChanged,
  );
}

/// 某天的時間軸：依時間列出腦洞／草稿／成圖；右下 ＋ 開啟 DayAddSheet，建立時間一律是現在。
class DayPage extends ConsumerStatefulWidget {
  const DayPage({
    super.key,
    required this.day,
    this.embedded = false,
    this.onYearChanged,
  });
  final DateTime day;
  final bool embedded;
  final ValueChanged<int>? onYearChanged;

  @override
  ConsumerState<DayPage> createState() => _DayPageState();
}

class _DayPageState extends ConsumerState<DayPage> {
  late DateTime _day = widget.day;

  String get _title => context.l10n.goalsDayTitle(_day.month, _day.day);

  void _shift(int days) {
    final old = _day.year;
    setState(() => _day = DateTime(_day.year, _day.month, _day.day + days));
    if (_day.year != old) widget.onYearChanged?.call(_day.year);
  }

  Future<void> _add() async {
    final pits = ref.read(pitsProvider(false)).value ?? const [];
    if (pits.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.goalsCreatePitFirst)));
      return;
    }
    final picked = await showDayAddSheet(context, pits: pits);
    if (picked == null || !mounted) return;
    // 建立時間一律是「現在」，不能改（D-038）。
    final now = DateTime.now();
    final page = switch (picked.kind) {
      GoalKind.idea => IdeaFormPage(pitId: picked.pitId, initialTime: now),
      GoalKind.draft => DraftFormPage(pitId: picked.pitId, initialTime: now),
      GoalKind.piece => PieceFormPage(pitId: picked.pitId, initialTime: now),
    };
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => page));
  }

  void _open(TimelineItem it) {
    final page = switch (it.kind) {
      GoalKind.idea => IdeaDetailPage(ideaId: it.id, pitId: it.pitId),
      GoalKind.draft => DraftDetailPage(draftId: it.id, pitId: it.pitId),
      GoalKind.piece => PieceDetailPage(pieceId: it.id, pitId: it.pitId),
    };
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  /// 共用時間軸的一筆（D-063）：分類標籤＋時間、標題、內文、tag；成圖多一個紅心互動量。
  TimelineEntry _entryOf(BuildContext context, TimelineItem item) {
    final t = context.tokens;
    final (label, color) = switch (item.kind) {
      GoalKind.idea => (context.l10n.goalsKindIdea, t.idea),
      GoalKind.draft => (context.l10n.goalsKindDraft, t.draft),
      GoalKind.piece => (context.l10n.goalsKindPiece, t.piece),
    };
    final tm = item.time;
    return TimelineEntry(
      id: '${item.kind.name}-${item.id}',
      date: tm,
      onTap: () => _open(item),
      kindLabel: label,
      kindColor: color,
      timeText:
          '${tm.hour.toString().padLeft(2, '0')}:${tm.minute.toString().padLeft(2, '0')}',
      title: item.title.isEmpty ? context.l10n.goalsUntitled : item.title,
      description: item.text,
      imageFile: item.file,
      imageCount: item.files.length,
      tags: item.tagNames,
      extra: item.kind == GoalKind.piece
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SvgIcon(
                  AppIcons.heart,
                  size: 14,
                  strokeWidth: 1.8,
                  color: t.accent,
                ),
                const SizedBox(width: 4),
                Text(
                  '${item.actualLikes}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (item.targetLikes > 0)
                  Text(
                    ' / ${item.targetLikes}',
                    style: TextStyle(fontSize: 12, color: t.text3),
                  ),
              ],
            )
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    ref.watch(pitsProvider(false)); // 讓 ＋ 按下時坑清單已載入
    final items =
        ref
            .watch(timelineProvider(DateTime(_day.year, _day.month, _day.day)))
            .value ??
        const [];
    final body = Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
          child: PeriodNav(
            label: _title,
            prevTooltip: context.l10n.goalsPrevDay,
            nextTooltip: context.l10n.goalsNextDay,
            onPrev: () => _shift(-1),
            onNext: () => _shift(1),
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? Center(
                  child: Text(
                    context.l10n.goalsDayEmpty,
                    style: TextStyle(color: t.text3),
                  ),
                )
              : TimelineView(
                  entries: [for (final it in items) _entryOf(context, it)],
                  countLabel: context.l10n.oshiCountItems,
                ),
        ),
      ],
    );
    final fab = Positioned(
      right: 18,
      bottom: 14,
      child: EntityFab(onPressed: _add, label: context.l10n.commonAdd),
    );
    if (widget.embedded) {
      return Stack(children: [body, fab]);
    }
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Column(
              children: [
                SubPageHeader(title: context.l10n.goalsTimeline),
                Expanded(child: body),
              ],
            ),
            fab,
          ],
        ),
      ),
    );
  }
}
