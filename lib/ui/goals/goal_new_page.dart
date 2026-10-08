import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/album_queries.dart';
import '../../data/database.dart';
import '../../data/goal_queries.dart';
import '../../state/providers.dart';
import '../../theme/tokens.dart';
import '../album/album_actions.dart';
import '../entity/entity_widgets.dart';
import '../common/app_icons.dart';
import '../common/app_switch.dart';
import '../common/nav_bar_hidden.dart';
import '../common/responsive.dart';
import 'goal_widgets.dart';
import 'pit_pill.dart';

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

class _GoalNewPageState extends ConsumerState<GoalNewPage> with HidesNavBar {
  final _name = TextEditingController();
  final _likes = TextEditingController();
  final _countCtl = TextEditingController(text: '1');
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
        _countCtl.text = '${g.count}';
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
    _countCtl.dispose();
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

  void _setCount(int v) {
    final n = v < 1 ? 1 : v;
    setState(() => _count = n);
    _countCtl.text = '$n';
  }

  /// 預覽卡的名稱：沒填名稱時依種類／數量／互動量自動命名（同 goalAutoName）。
  String get _previewLabel {
    final n = _name.text.trim();
    if (n.isNotEmpty) return n;
    final likes = int.tryParse(_likes.text.trim());
    return switch (_kind) {
      GoalKind.idea => '生產 $_count 個腦洞',
      GoalKind.draft => '畫 $_count 份草稿',
      GoalKind.piece =>
        (_requireLikes && likes != null)
            ? '互動量過 $likes 的成圖 $_count 張'
            : '完成 $_count 張成圖',
    };
  }

  Future<void> _pickPit(List<Pit> pits) async {
    final id = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(16),
          children: [
            for (final p in pits)
              Material(
                type: MaterialType.transparency,
                child: ListTile(
                  title: Text(p.name),
                  onTap: () => Navigator.pop(ctx, p.id),
                ),
              ),
          ],
        ),
      ),
    );
    if (id == null || id == _pitId) return;
    setState(() {
      _pitId = id;
      _tagIds = []; // 換坑後 tag 不共用
    });
  }

  Widget _pill(BuildContext context, String label, bool on, VoidCallback tap) {
    final t = context.tokens;
    return GestureDetector(
      onTap: tap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: on ? t.accent : t.surface,
          border: Border.all(color: on ? t.accent : t.border),
          borderRadius: BorderRadius.circular(Radii.chip),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: on ? Colors.white : t.text2,
          ),
        ),
      ),
    );
  }

  Widget _stepButton(BuildContext context, String label, VoidCallback? tap) {
    final t = context.tokens;
    return GestureDetector(
      onTap: tap,
      child: Container(
        width: 46,
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: t.surface,
          border: Border.all(color: mockLine(context)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(label, style: TextStyle(fontSize: 22, color: t.text2)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final pits = ref.watch(pitsProvider(false)).value ?? const [];
    final archived = ref.watch(pitsProvider(true)).value ?? const [];
    final allPits = [...pits, ...archived];
    Pit? pit;
    for (final p in allPits) {
      if (p.id == _pitId) pit = p;
    }
    final pitTags = _pitId == null
        ? const <Tag>[]
        : (ref.watch(tagsProvider(_pitId!)).value ?? const <Tag>[]);
    final scope = switch (widget.period) {
      GoalPeriod.year => '年度',
      GoalPeriod.month => '月度',
    };
    final title = widget.goalId == null ? '新增$scope目標' : '編輯$scope目標';
    final fieldStyle = const TextStyle(fontSize: 15);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ContentWidth(
          child: Column(
            children: [
              SubPageHeader(
                title: title,
                titleSize: 20,
                gap: 6,
                trailing: [
                  if (widget.goalId != null)
                    HeaderIconButton(
                      label: '刪除',
                      icon: AppIcons.trash,
                      color: t.danger,
                      onTap: () async {
                        final ok = await confirmDelete(
                          context,
                          title: '刪除這個目標？',
                        );
                        if (!ok || !context.mounted) return;
                        await ref
                            .read(databaseProvider)
                            .deleteGoal(widget.goalId!);
                        if (context.mounted) Navigator.of(context).pop();
                      },
                    ),
                ],
              ),
              Expanded(
                child: !_loaded
                    ? const Center(child: CircularProgressIndicator())
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(2, 0, 0, 8),
                            child: Text(
                              '預覽',
                              style: TextStyle(fontSize: 11, color: t.text3),
                            ),
                          ),
                          GoalCardBody(
                            label: _previewLabel,
                            progress: 0,
                            target: _count,
                            pitName: pit?.name,
                            tags: [
                              for (final tag in pitTags)
                                if (_tagIds.contains(tag.id)) '#${tag.name}',
                            ],
                          ),
                          const SizedBox(height: 20),
                          const FormLabel('目標名稱'),
                          TextField(
                            controller: _name,
                            style: fieldStyle,
                            onChanged: (_) => setState(() {}),
                            decoration: entityFieldDecoration(
                              context,
                              '留空將自動命名',
                            ),
                          ),
                          const SizedBox(height: 16),
                          _requiredLabel(context, '目標種類'),
                          Row(
                            spacing: 8,
                            children: [
                              for (final (k, label) in [
                                (GoalKind.idea, '腦洞'),
                                (GoalKind.draft, '草稿'),
                                (GoalKind.piece, '成圖'),
                              ])
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => setState(() => _kind = k),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 11,
                                      ),
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: _kind == k
                                            ? t.accent
                                            : t.surface,
                                        border: Border.all(
                                          color: _kind == k
                                              ? t.accent
                                              : t.border,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        label,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: _kind == k
                                              ? Colors.white
                                              : t.text2,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _requiredLabel(context, '目標數量'),
                          Row(
                            spacing: 10,
                            children: [
                              _stepButton(
                                context,
                                '−',
                                () => _setCount(_count - 1),
                              ),
                              Expanded(
                                child: TextField(
                                  controller: _countCtl,
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.center,
                                  style: fieldStyle,
                                  onChanged: (v) {
                                    final n = int.tryParse(v);
                                    if (n != null && n > 0) {
                                      setState(() => _count = n);
                                    }
                                  },
                                  decoration: entityFieldDecoration(
                                    context,
                                    '',
                                  ),
                                ),
                              ),
                              _stepButton(
                                context,
                                '＋',
                                () => _setCount(_count + 1),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const FormLabel('目標坑'),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if (pit != null)
                                PitPill(
                                  name: pit.name,
                                  large: true,
                                  onRemove: () => setState(() {
                                    _pitId = null;
                                    _tagIds = [];
                                  }),
                                ),
                              DashedAddChip(
                                semanticLabel: '選擇坑',
                                label: '選擇',
                                onTap: () => _pickPit(allPits),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const FormLabel('目標 tag'),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(2, 0, 0, 8),
                            child: Text(
                              _pitId == null ? '選擇坑之後才能選 tag' : '只顯示所選坑內的 tag',
                              style: TextStyle(fontSize: 11.5, color: t.text4),
                            ),
                          ),
                          if (_pitId != null)
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                for (final tag in pitTags)
                                  _pill(
                                    context,
                                    '#${tag.name}',
                                    _tagIds.contains(tag.id),
                                    () => setState(
                                      () => _tagIds.contains(tag.id)
                                          ? _tagIds = _tagIds
                                                .where((e) => e != tag.id)
                                                .toList()
                                          : _tagIds = [..._tagIds, tag.id],
                                    ),
                                  ),
                                DashedAddChip(
                                  semanticLabel: '新增 tag',
                                  onTap: () async {
                                    final name = await promptText(
                                      context,
                                      title: '新增 tag',
                                    );
                                    if (name == null) return;
                                    final id = await ref
                                        .read(databaseProvider)
                                        .createTag(_pitId!, name);
                                    if (mounted && !_tagIds.contains(id)) {
                                      setState(
                                        () => _tagIds = [..._tagIds, id],
                                      );
                                    }
                                  },
                                ),
                              ],
                            ),
                          const SizedBox(height: 16),
                          if (_kind == GoalKind.piece) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: t.surface,
                                border: Border.all(color: t.borderCard),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Column(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          '需要達成互動量',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        AppSwitch(
                                          value: _requireLikes,
                                          semanticLabel: '需要達成互動量',
                                          onChanged: (v) => setState(() {
                                            _requireLikes = v;
                                            // 開啟時門檻預設 100（GoalNewHot）。
                                            if (v &&
                                                _likes.text.trim().isEmpty) {
                                              _likes.text = '100';
                                            }
                                          }),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (_requireLikes)
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        0,
                                        2,
                                        0,
                                        14,
                                      ),
                                      child: Row(
                                        spacing: 10,
                                        children: [
                                          Text(
                                            '互動量 ≥',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: t.text2,
                                            ),
                                          ),
                                          SizedBox(
                                            width: 110,
                                            child: TextField(
                                              controller: _likes,
                                              keyboardType:
                                                  TextInputType.number,
                                              textAlign: TextAlign.center,
                                              style: fieldStyle,
                                              onChanged: (_) => setState(() {}),
                                              decoration: entityFieldDecoration(
                                                context,
                                                '',
                                              ),
                                            ),
                                          ),
                                          Text(
                                            '紅心',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: t.text3,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          FormSubmitButton(
                            label: widget.goalId == null ? '建立目標' : '儲存',
                            onPressed: _loaded ? _save : null,
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _requiredLabel(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.fromLTRB(2, 0, 0, 8),
    child: Text.rich(
      TextSpan(
        text: text,
        children: [
          TextSpan(
            text: ' *',
            style: TextStyle(color: context.tokens.accent),
          ),
        ],
      ),
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: context.tokens.text2,
      ),
    ),
  );
}
