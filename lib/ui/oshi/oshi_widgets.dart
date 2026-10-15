import 'package:flutter/material.dart';

import '../../data/oshi_queries.dart';
import '../../theme/tokens.dart';
import '../common/timeline.dart';

/// 兩位數月/日（網格圖下的日期，設計稿 `10/05`）。
String oshiMd(DateTime d) =>
    '${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';

/// 時間軸的一筆資料（推活）。標題、描述都是選填。
TimelineEntry oshiTimelineEntry(
  OshiRecordView v, {
  required VoidCallback onTap,
  VoidCallback? onLongPress,
  bool? selected,
  int? dragIndex,
}) => TimelineEntry(
  id: v.record.id,
  date: v.date,
  onTap: onTap,
  title: v.record.title,
  description: v.record.description ?? '',
  imageFile: v.cover.file,
  imageCount: v.images.length,
  tags: [for (final t in v.tags) t.name],
  onLongPress: onLongPress,
  selected: selected,
  dragIndex: dragIndex,
);

/// 分組小標（網格圖下方、詳情頁以外的地方）：淡紫底、紫字 11.5/600。
class OshiGroupTag extends StatelessWidget {
  const OshiGroupTag(this.name, {super.key});
  final String name;

  @override
  Widget build(BuildContext context) {
    final c = context.tokens.oshi;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 110),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: c.bg,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: c.fg,
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
