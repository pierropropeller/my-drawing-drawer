import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../data/goal_queries.dart';
import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../../theme/tokens.dart';
import '../common/app_icons.dart';
import '../common/media_source.dart';
import '../common/svg_icon.dart';
import '../common/timeline.dart';
import 'day_add_sheet.dart';
import 'day_timeline.dart';
import '../entity/draft_detail_page.dart';
import '../entity/draft_form_page.dart';
import '../entity/entity_widgets.dart';
import '../entity/idea_detail_page.dart';
import '../entity/idea_form_page.dart';
import '../entity/piece_detail_page.dart';
import '../entity/piece_form_page.dart';

/// 日（Day）：連續時間軸分頁（D-072），從今天開始；[timelineKey] 讓上層（月頁點日曆）捲到指定日子。
class DayView extends StatelessWidget {
  const DayView({super.key, this.onYearChanged, this.timelineKey});
  final ValueChanged<int>? onYearChanged;
  final GlobalKey<DayTimelineState>? timelineKey;

  @override
  Widget build(BuildContext context) => DayPage(
    embedded: true,
    onYearChanged: onYearChanged,
    timelineKey: timelineKey,
  );
}

/// 連續時間軸：依時間列出腦洞／草稿／成圖；右下 ＋ 開啟 DayAddSheet，建立時間一律是現在。
/// [day]：一開始捲到的日子（沒內容就捲到之前最近有內容的一天）；null＝從今天開始。
class DayPage extends ConsumerStatefulWidget {
  const DayPage({
    super.key,
    this.day,
    this.embedded = false,
    this.onYearChanged,
    this.timelineKey,
  });
  final DateTime? day;
  final bool embedded;
  final ValueChanged<int>? onYearChanged;
  final GlobalKey<DayTimelineState>? timelineKey;

  @override
  ConsumerState<DayPage> createState() => _DayPageState();
}

class _DayPageState extends ConsumerState<DayPage> {
  Future<void> _add() async {
    // 現坑＋淺坑（不含封存坑）；淺坑只有開啟的格子能新增。
    final pits = ref.read(selectablePitsProvider).value ?? const <Pit>[];
    final addable = pits.any(
      (p) =>
          p.sectionOpen(PitSectionKey.idea) ||
          p.sectionOpen(PitSectionKey.draft) ||
          p.sectionOpen(PitSectionKey.piece),
    );
    if (!addable) {
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

  /// 時間軸縮圖用的第一張（GIF 循環、影片用 poster＋小標）；影片還沒有 poster 的跳過，與 [TimelineItem.file] 一致。
  MediaSource? _firstMedia(TimelineItem item) {
    for (final m in item.media) {
      if (m.staticFile != null) return MediaSource.fromImageRef(m);
    }
    return null;
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
      media: _firstMedia(item),
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
    ref.watch(selectablePitsProvider); // 讓 ＋ 按下時坑清單已載入
    final body = DayTimeline(
      key: widget.timelineKey,
      initialDay: widget.day,
      onYearChanged: widget.onYearChanged,
      entryOf: _entryOf,
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
