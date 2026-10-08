import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/album_queries.dart';
import '../../data/database.dart';
import '../../data/goal_queries.dart';
import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../../theme/tokens.dart';
import '../album/album_actions.dart';
import '../entity/entity_widgets.dart';
import '../common/app_icons.dart';
import '../common/app_switch.dart';
import '../common/nav_bar_hidden.dart';
import '../common/responsive.dart';
import 'goal_name.dart';
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
        showSnack(context, context.l10n.goalsEnterLikes);
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
    return goalAutoNameText(
      context.l10n,
      _kind,
      _count,
      (_requireLikes && likes != null) ? likes : null,
    );
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
    final l = context.l10n;
    final title = switch ((widget.goalId == null, widget.period)) {
      (true, GoalPeriod.year) => l.goalsNewYearGoal,
      (true, GoalPeriod.month) => l.goalsNewMonthGoal,
      (false, GoalPeriod.year) => l.goalsEditYearGoal,
      (false, GoalPeriod.month) => l.goalsEditMonthGoal,
    };
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
                      label: l.commonDelete,
                      icon: AppIcons.trash,
                      color: t.danger,
                      onTap: () async {
                        final ok = await confirmDelete(
                          context,
                          title: l.goalsDeleteConfirm,
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
                              l.goalsPreview,
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
                          FormLabel(l.goalsFieldName),
                          TextField(
                            controller: _name,
                            style: fieldStyle,
                            onChanged: (_) => setState(() {}),
                            decoration: entityFieldDecoration(
                              context,
                              l.goalsNameHint,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _requiredLabel(context, l.goalsFieldKind),
                          Row(
                            spacing: 8,
                            children: [
                              for (final (k, label) in [
                                (GoalKind.idea, l.goalsKindIdea),
                                (GoalKind.draft, l.goalsKindDraft),
                                (GoalKind.piece, l.goalsKindPiece),
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
                          _requiredLabel(context, l.goalsFieldCount),
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
                          FormLabel(l.goalsFieldPit),
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
                                semanticLabel: l.goalsPickPit,
                                label: l.commonSelect,
                                onTap: () => _pickPit(allPits),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          FormLabel(l.goalsFieldTag),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(2, 0, 0, 8),
                            child: Text(
                              _pitId == null ? l.goalsTagHintNoPit : l.goalsTagHintPit,
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
                                  semanticLabel: l.goalsAddTag,
                                  onTap: () async {
                                    final name = await promptText(
                                      context,
                                      title: l.goalsAddTag,
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
                                        Text(
                                          l.goalsRequireLikes,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        AppSwitch(
                                          value: _requireLikes,
                                          semanticLabel: l.goalsRequireLikes,
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
                                            l.goalsLikesAtLeast,
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
                                            l.goalsHearts,
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
                            label: widget.goalId == null ? l.goalsCreateGoal : l.commonSave,
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
