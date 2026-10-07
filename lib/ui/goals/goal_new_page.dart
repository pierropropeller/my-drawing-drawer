import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../data/goal_queries.dart';
import '../../state/providers.dart';
import '../../theme/tokens.dart';
import '../album/album_actions.dart';
import '../entity/entity_widgets.dart';
import '../pits/pit_form.dart';
import '../tags/tag_picker.dart';

/// 新增／編輯目標。可選的 tag 依所選的坑而定；未選坑時不能選 tag。
class GoalNewPage extends ConsumerStatefulWidget {
  const GoalNewPage({
    super.key,
    required this.period,
    required this.year,
    this.month,
    this.goalId,
  });
  final GoalPeriod period;
  final int year;
  final int? month;
  final String? goalId;

  @override
  ConsumerState<GoalNewPage> createState() => _GoalNewPageState();
}

class _GoalNewPageState extends ConsumerState<GoalNewPage> {
  final _name = TextEditingController();
  final _likes = TextEditingController();
  GoalKind _kind = GoalKind.piece;
  int _count = 1;
  String? _pitId;
  List<String> _tagIds = [];
  bool _requireLikes = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final id = widget.goalId;
    if (id != null) {
      final db = ref.read(databaseProvider);
      final g = await db.goalById(id);
      if (g != null) {
        _name.text = g.name ?? '';
        _kind = g.kind;
        _count = g.count;
        _pitId = g.pitId;
        _tagIds = await db.goalTagIds(id);
        _requireLikes = g.requireLikes != null;
        _likes.text = g.requireLikes?.toString() ?? '';
      }
    }
    if (mounted) setState(() => _loaded = true);
  }

  @override
  void dispose() {
    _name.dispose();
    _likes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    int? likes;
    if (_kind == GoalKind.piece && _requireLikes) {
      likes = int.tryParse(_likes.text.trim());
      if (likes == null) {
        showSnack(context, '請輸入需要達成的互動量');
        return;
      }
    }
    await ref
        .read(databaseProvider)
        .saveGoal(
          id: widget.goalId,
          period: widget.period,
          year: widget.year,
          month: widget.month,
          name: _name.text,
          kind: _kind,
          count: _count,
          pitId: _pitId,
          tagIds: _tagIds,
          requireLikes: likes,
        );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final pits = ref.watch(pitsProvider(false)).value ?? const [];
    final archived = ref.watch(pitsProvider(true)).value ?? const [];
    final allPits = [...pits, ...archived];
    final title = widget.goalId == null ? '新增目標' : '編輯目標';
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (widget.goalId != null)
            IconButton(
              tooltip: '刪除',
              icon: Icon(Icons.delete_outline, color: t.danger),
              onPressed: () async {
                final ok = await confirmDelete(context, title: '刪除這個目標？');
                if (!ok || !context.mounted) return;
                await ref.read(databaseProvider).deleteGoal(widget.goalId!);
                if (context.mounted) Navigator.of(context).pop();
              },
            ),
          TextButton(
            onPressed: _loaded ? _save : null,
            child: const Text('儲存'),
          ),
        ],
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                TextField(
                  controller: _name,
                  decoration: pitFieldDecoration(context, '名稱（可留空）'),
                ),
                const SizedBox(height: 20),
                const FormLabel('類型'),
                SegmentedButton<GoalKind>(
                  segments: const [
                    ButtonSegment(value: GoalKind.idea, label: Text('腦洞')),
                    ButtonSegment(value: GoalKind.draft, label: Text('草稿')),
                    ButtonSegment(value: GoalKind.piece, label: Text('成圖')),
                  ],
                  selected: {_kind},
                  onSelectionChanged: (s) => setState(() => _kind = s.first),
                ),
                const SizedBox(height: 20),
                const FormLabel('數量'),
                Row(
                  children: [
                    IconButton.outlined(
                      onPressed: _count > 1
                          ? () => setState(() => _count--)
                          : null,
                      icon: const Icon(Icons.remove),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        '$_count',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton.outlined(
                      onPressed: () => setState(() => _count++),
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const FormLabel('坑'),
                DropdownButtonFormField<String?>(
                  initialValue: allPits.any((p) => p.id == _pitId)
                      ? _pitId
                      : null,
                  decoration: pitFieldDecoration(context, '任意坑'),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('任意坑'),
                    ),
                    for (final p in allPits)
                      DropdownMenuItem<String?>(
                        value: p.id,
                        child: Text(p.name),
                      ),
                  ],
                  onChanged: (v) => setState(() {
                    _pitId = v;
                    _tagIds = []; // 換坑後 tag 不共用
                  }),
                ),
                const SizedBox(height: 20),
                if (_pitId == null)
                  Text('選擇坑之後才能選 tag', style: TextStyle(color: t.text3))
                else
                  TagPicker(
                    pitId: _pitId!,
                    selected: _tagIds,
                    onChanged: (v) => setState(() => _tagIds = v),
                  ),
                if (_kind == GoalKind.piece) ...[
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    activeThumbColor: t.accent,
                    title: const Text('需要達成互動量'),
                    value: _requireLikes,
                    onChanged: (v) => setState(() => _requireLikes = v),
                  ),
                  if (_requireLikes)
                    TextField(
                      controller: _likes,
                      keyboardType: TextInputType.number,
                      decoration: pitFieldDecoration(context, '互動量'),
                    ),
                ],
              ],
            ),
    );
  }
}
