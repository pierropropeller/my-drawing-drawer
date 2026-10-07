import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/database.dart';
import '../../data/goal_queries.dart';
import '../../state/providers.dart';
import '../../theme/tokens.dart';
import '../album/album_image.dart';
import 'goal_widgets.dart';
import '../entity/draft_detail_page.dart';
import '../entity/draft_form_page.dart';
import '../entity/entity_widgets.dart';
import '../entity/idea_detail_page.dart';
import '../entity/idea_form_page.dart';
import '../entity/piece_detail_page.dart';
import '../entity/piece_form_page.dart';

/// 時間軸分頁：顯示今天。
class DayView extends StatelessWidget {
  const DayView({super.key});

  @override
  Widget build(BuildContext context) =>
      DayPage(day: DateTime.now(), embedded: true);
}

/// 某天的時間軸：依時間列出腦洞／草稿／成圖；右下 ＋ 以「此時此刻」新增（時間可改）。
class DayPage extends ConsumerStatefulWidget {
  const DayPage({super.key, required this.day, this.embedded = false});
  final DateTime day;
  final bool embedded;

  @override
  ConsumerState<DayPage> createState() => _DayPageState();
}

class _DayPageState extends ConsumerState<DayPage> {
  late DateTime _day = widget.day;

  String get _title =>
      '${_day.year}.${_day.month.toString().padLeft(2, '0')}.${_day.day.toString().padLeft(2, '0')}';

  Future<void> _add() async {
    final pits = ref.read(pitsProvider(false)).value ?? const [];
    if (pits.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('請先建立一個坑')));
      return;
    }
    final picked = await showModalBottomSheet<_AddChoice>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AddSheet(pits: pits, day: _day),
    );
    if (picked == null || !mounted) return;
    // 草稿、成圖一定要有圖：先打開相簿選圖，再進新增頁。
    var images = <XFile>[];
    if (picked.kind != GoalKind.idea) {
      images = await ref.read(imagePickerProvider)();
      if (images.isEmpty || !mounted) return;
    }
    final page = switch (picked.kind) {
      GoalKind.idea => IdeaFormPage(
        pitId: picked.pitId,
        initialTime: picked.time,
      ),
      GoalKind.draft => DraftFormPage(
        pitId: picked.pitId,
        initialTime: picked.time,
        initialImages: images,
      ),
      GoalKind.piece => PieceFormPage(
        pitId: picked.pitId,
        initialTime: picked.time,
        initialImages: images,
      ),
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

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final items =
        ref
            .watch(timelineProvider(DateTime(_day.year, _day.month, _day.day)))
            .value ??
        const [];
    final body = Column(
      children: [
        PeriodHeader(
          label: _title,
          onPrev: () =>
              setState(() => _day = _day.subtract(const Duration(days: 1))),
          onNext: () =>
              setState(() => _day = _day.add(const Duration(days: 1))),
        ),
        Expanded(
          child: items.isEmpty
              ? Center(
                  child: Text('這天沒有紀錄', style: TextStyle(color: t.text3)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                  itemCount: items.length,
                  itemBuilder: (_, i) => _TimelineRow(
                    item: items[i],
                    onTap: () => _open(items[i]),
                  ),
                ),
        ),
      ],
    );
    final fab = FloatingActionButton(
      backgroundColor: t.accent,
      foregroundColor: Colors.white,
      onPressed: _add,
      child: const Icon(Icons.add),
    );
    if (widget.embedded) {
      return Stack(
        children: [
          body,
          Positioned(right: 16, bottom: 16, child: fab),
        ],
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('時間軸')),
      body: body,
      floatingActionButton: fab,
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.item, required this.onTap});
  final TimelineItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final (label, color) = switch (item.kind) {
      GoalKind.idea => ('腦洞', t.idea),
      GoalKind.draft => ('草稿', t.draft),
      GoalKind.piece => ('成圖', t.piece),
    };
    final time =
        '${item.time.hour.toString().padLeft(2, '0')}:${item.time.minute.toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 48,
            child: Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Text(time, style: TextStyle(color: t.text3, fontSize: 12)),
            ),
          ),
          Expanded(
            child: EntityCard(
              onTap: onTap,
              child: Row(
                children: [
                  if (item.file != null) ...[
                    SizedBox(
                      width: 48,
                      height: 48,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(Radii.image),
                        child: StoredImage(item.file!, cacheWidth: 160),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Text(
                      item.title.isEmpty ? '（無標題）' : item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: color.bg,
                      borderRadius: BorderRadius.circular(Radii.chip),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        color: color.fg,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddChoice {
  const _AddChoice(this.kind, this.pitId, this.time);
  final GoalKind kind;
  final String pitId;
  final DateTime time;
}

/// 新增面板：選坑、確認時間（預設此時此刻，可改）、選類型。
class _AddSheet extends StatefulWidget {
  const _AddSheet({required this.pits, required this.day});
  final List<Pit> pits;
  final DateTime day;

  @override
  State<_AddSheet> createState() => _AddSheetState();
}

class _AddSheetState extends State<_AddSheet> {
  late String _pitId = widget.pits.first.id;
  late DateTime _time = () {
    final now = DateTime.now();
    final d = widget.day;
    return DateTime(d.year, d.month, d.day, now.hour, now.minute);
  }();

  Future<void> _pickTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_time),
    );
    if (t != null) {
      setState(
        () => _time = DateTime(
          _time.year,
          _time.month,
          _time.day,
          t.hour,
          t.minute,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('新增', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _pitId,
              decoration: const InputDecoration(labelText: '坑'),
              items: [
                for (final p in widget.pits)
                  DropdownMenuItem(value: p.id, child: Text(p.name)),
              ],
              onChanged: (v) => setState(() => _pitId = v!),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _pickTime,
              icon: const Icon(Icons.schedule, size: 18),
              label: Text(
                '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}',
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                for (final (k, label) in [
                  (GoalKind.idea, '腦洞'),
                  (GoalKind.draft, '草稿'),
                  (GoalKind.piece, '成圖'),
                ])
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilledButton(
                        onPressed: () => Navigator.pop(
                          context,
                          _AddChoice(k, _pitId, _time),
                        ),
                        child: Text(label),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
