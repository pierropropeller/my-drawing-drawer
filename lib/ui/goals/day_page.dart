import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/database.dart';
import '../../data/goal_queries.dart';
import '../../state/providers.dart';
import '../../theme/tokens.dart';
import '../album/album_image.dart';
import '../common/app_icons.dart';
import '../common/svg_icon.dart';
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

/// 某天的時間軸：依時間列出腦洞／草稿／成圖；右下 ＋ 以「此時此刻」新增（時間可改）。
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

  String get _title => '${_day.month} 月 ${_day.day} 日';

  void _shift(int days) {
    final old = _day.year;
    setState(() => _day = DateTime(_day.year, _day.month, _day.day + days));
    if (_day.year != old) widget.onYearChanged?.call(_day.year);
  }

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
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
          child: PeriodNav(
            label: _title,
            prevTooltip: '前一天',
            nextTooltip: '後一天',
            onPrev: () => _shift(-1),
            onNext: () => _shift(1),
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? Center(
                  child: Text('這天沒有紀錄', style: TextStyle(color: t.text3)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 2, 20, 96),
                  itemCount: items.length,
                  itemBuilder: (_, i) => _TimelineRow(
                    item: items[i],
                    onTap: () => _open(items[i]),
                  ),
                ),
        ),
      ],
    );
    final fab = Positioned(
      right: 18,
      bottom: 14,
      child: EntityFab(onPressed: _add, label: '立即發佈新內容'),
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
                const SubPageHeader(title: '時間軸'),
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

/// 時間軸的一筆：左側圓點＋豎線，右側時間、類型徽章、標題、內文、縮圖、tag、互動量。
class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.item, required this.onTap});
  final TimelineItem item;
  final VoidCallback onTap;

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final (label, color) = switch (item.kind) {
      GoalKind.idea => ('腦洞', t.idea),
      GoalKind.draft => ('草稿', t.draft),
      GoalKind.piece => ('成圖', t.piece),
    };
    final tm = item.time;
    final when =
        '${_months[tm.month - 1]} ${tm.day}\u3000${tm.hour.toString().padLeft(2, '0')}:${tm.minute.toString().padLeft(2, '0')}';
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 12,
              child: Column(
                children: [
                  Container(
                    width: 11,
                    height: 11,
                    margin: const EdgeInsets.only(top: 5),
                    decoration: BoxDecoration(
                      color: color.fg,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.only(top: 4),
                      color: t.border,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      spacing: 8,
                      children: [
                        Text(
                          when,
                          style: TextStyle(fontSize: 12, color: t.text3),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: color.bg,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            label,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: color.fg,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        item.title.isEmpty ? '（無標題）' : item.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    if (item.text.trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(
                          item.text,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            height: 1.5,
                            color: t.text2,
                          ),
                        ),
                      ),
                    if (item.files.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final f in item.files)
                              SizedBox(
                                width: 62,
                                height: 62,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: StoredImage(f, cacheWidth: 200),
                                ),
                              ),
                          ],
                        ),
                      ),
                    if (item.tagNames.isNotEmpty || item.kind == GoalKind.piece)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            for (final n in item.tagNames)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: t.chipBg,
                                  borderRadius: BorderRadius.circular(
                                    Radii.chip,
                                  ),
                                ),
                                child: Text(
                                  '#$n',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: t.text2,
                                  ),
                                ),
                              ),
                            if (item.kind == GoalKind.piece)
                              Padding(
                                padding: const EdgeInsets.only(left: 2),
                                child: Row(
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
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    if (item.targetLikes > 0)
                                      Text(
                                        ' / ${item.targetLikes}',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          color: t.text3,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                          ],
                        ),
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
            OutlinedButton(
              onPressed: _pickTime,
              child: Text(
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
