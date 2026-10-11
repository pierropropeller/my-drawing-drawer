import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../theme/tokens.dart';
import '../album/album_image.dart';
import '../entity/entity_widgets.dart';

/// 共用時間軸元件（D-063）：推活時間軸與目標「日」頁共用。
/// 設計稿：OshiTimeline、Day。

/// 時間軸上的一筆。
class TimelineEntry {
  const TimelineEntry({
    required this.id,
    required this.date,
    required this.onTap,
    this.title,
    this.description = '',
    this.imageFile,
    this.imageCount = 0,
    this.kindLabel,
    this.kindColor,
    this.timeText,
    this.tags = const [],
    this.extra,
  });

  final String id;

  /// 左欄日期與月份分段用（只看年月日）。
  final DateTime date;
  final VoidCallback onTap;

  /// 標題；null 或空字串＝不顯示標題列。
  final String? title;

  /// 描述（最多兩行）。
  final String description;

  /// 首張圖；沒有就顯示佔位格。
  final String? imageFile;

  /// 圖片總數；超過 1 張時首圖右下角顯示圓形數字。
  final int imageCount;

  /// 分類標籤與時間（目標日頁才有）。
  final String? kindLabel;
  final CategoryColor? kindColor;
  final String? timeText;

  /// tag 名稱（不含 #）。
  final List<String> tags;

  /// 接在 tag 後面的內容（目標日頁成圖的紅心）。
  final Widget? extra;
}

/// 一個月份分段（段首「2026 年 10 月」＋數量）。
class TimelineSection {
  const TimelineSection({
    required this.year,
    required this.month,
    required this.entries,
  });
  final int year;
  final int month;
  final List<TimelineEntry> entries;
}

/// 依月份分段；[entries] 要已依日期排好（新到舊），同月份的筆合併成一段（保持原順序）。
List<TimelineSection> groupTimelineByMonth(List<TimelineEntry> entries) {
  final out = <TimelineSection>[];
  for (final e in entries) {
    if (out.isEmpty ||
        out.last.year != e.date.year ||
        out.last.month != e.date.month) {
      out.add(
        TimelineSection(year: e.date.year, month: e.date.month, entries: []),
      );
    }
    out.last.entries.add(e);
  }
  return out;
}

/// 星期的 ARB 字串（週一…週日）。
String weekdayLabel(AppLocalizations l, DateTime d) => switch (d.weekday) {
  DateTime.monday => l.oshiWeekdayMon,
  DateTime.tuesday => l.oshiWeekdayTue,
  DateTime.wednesday => l.oshiWeekdayWed,
  DateTime.thursday => l.oshiWeekdayThu,
  DateTime.friday => l.oshiWeekdayFri,
  DateTime.saturday => l.oshiWeekdaySat,
  _ => l.oshiWeekdaySun,
};

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// 圓形數字（深色半透明底、白字），多張圖的標記。
class RoundCountBadge extends StatelessWidget {
  const RoundCountBadge(this.count, {super.key});
  final int count;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
    padding: const EdgeInsets.symmetric(horizontal: 6),
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: const Color(0xFF2B2622).withValues(alpha: 0.62),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      '$count',
      style: const TextStyle(
        color: Colors.white,
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
        height: 1.1,
      ),
    ),
  );
}

/// 時間軸本體：按月份分段的可捲動清單。
/// [countLabel]：段首右側數量的文字（推活「N 筆」、日頁「N 項」）。
class TimelineView extends StatelessWidget {
  const TimelineView({
    super.key,
    required this.entries,
    required this.countLabel,
    this.padding = const EdgeInsets.fromLTRB(20, 4, 20, 96),
  });

  final List<TimelineEntry> entries;
  final String Function(int count) countLabel;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    // 攤平成「段首」與「一筆」兩種列。
    final rows = <Widget>[];
    for (final s in groupTimelineByMonth(entries)) {
      rows.add(
        _SectionHeader(
          title: context.l10n.oshiMonthHeader(s.year, s.month),
          count: countLabel(s.entries.length),
        ),
      );
      for (var i = 0; i < s.entries.length; i++) {
        final e = s.entries[i];
        rows.add(
          _TimelineRow(
            key: ValueKey('timeline-${e.id}'),
            entry: e,
            // 同一天的第二筆起不顯示日期，改成小灰點。
            showDate: i == 0 || !_sameDay(s.entries[i - 1].date, e.date),
            // 月份最後一筆不畫線。
            line: i < s.entries.length - 1,
          ),
        );
      }
    }
    return ListView(padding: padding, children: rows);
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.count});
  final String title;
  final String count;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 4, 2, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: t.ink,
              ),
            ),
          ),
          Text(count, style: TextStyle(fontSize: 12.5, color: t.text3)),
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    super.key,
    required this.entry,
    required this.showDate,
    required this.line,
  });
  final TimelineEntry entry;
  final bool showDate;
  final bool line;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final lineColor = dark ? t.border : const Color(0xFFE3D8C9);
    final dotColor = dark ? t.dashed : const Color(0xFFD8CFC3);
    final d = entry.date;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 40,
            child: Column(
              children: [
                const SizedBox(height: 6),
                if (showDate) ...[
                  Text(
                    d.day.toString().padLeft(2, '0'),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      height: 1,
                      color: t.ink,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    weekdayLabel(context.l10n, d),
                    style: TextStyle(fontSize: 12, color: t.text3),
                  ),
                ] else
                  Container(
                    key: const ValueKey('timeline-dot'),
                    width: 7,
                    height: 7,
                    margin: const EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(
                      color: dotColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                if (line)
                  Expanded(
                    child: Container(
                      key: const ValueKey('timeline-line'),
                      width: 1.5,
                      margin: const EdgeInsets.only(top: 6),
                      color: lineColor,
                    ),
                  )
                else
                  const Spacer(),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _EntryCard(entry),
            ),
          ),
        ],
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard(this.entry);
  final TimelineEntry entry;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final title = entry.title ?? '';
    final kind = entry.kindLabel;
    return GestureDetector(
      onTap: entry.onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: t.surface,
          border: Border.all(color: t.borderCard),
          borderRadius: BorderRadius.circular(Radii.card),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 76,
              height: 76,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: entry.imageFile == null
                        ? const ImagePlaceholder(iconSize: 22)
                        : StoredImage(entry.imageFile!, cacheWidth: 300),
                  ),
                  if (entry.imageCount > 1)
                    Positioned(
                      right: 5,
                      bottom: 5,
                      child: RoundCountBadge(entry.imageCount),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 5,
                  children: [
                    if (kind != null)
                      Row(
                        spacing: 6,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: entry.kindColor?.bg ?? t.chipBg,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              kind,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: entry.kindColor?.fg ?? t.text2,
                              ),
                            ),
                          ),
                          if (entry.timeText != null)
                            Text(
                              entry.timeText!,
                              style: TextStyle(fontSize: 12.5, color: t.text3),
                            ),
                        ],
                      ),
                    if (title.isNotEmpty)
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          height: 1.4,
                        ),
                      ),
                    if (entry.description.trim().isNotEmpty)
                      Text(
                        entry.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: t.text2,
                          height: 1.5,
                        ),
                      ),
                    if (entry.tags.isNotEmpty || entry.extra != null)
                      Wrap(
                        spacing: 5,
                        runSpacing: 5,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          for (final n in entry.tags)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: t.chipBg,
                                borderRadius: BorderRadius.circular(Radii.chip),
                              ),
                              child: Text(
                                '#$n',
                                style: TextStyle(fontSize: 12, color: t.text2),
                              ),
                            ),
                          ?entry.extra,
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
