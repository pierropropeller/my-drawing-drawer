import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/entity_queries.dart';
import '../../state/providers.dart';
import '../../theme/tokens.dart';
import '../album/album_actions.dart';
import '../album/album_image.dart';
import '../album/album_view.dart';
import '../common/app_icons.dart';
import '../common/empty_state.dart';
import '../common/svg_icon.dart';
import 'entity_widgets.dart';
import 'idea_detail_page.dart';
import 'idea_form_page.dart';

/// 我的腦洞：卡片顯示標題、狀態、內文兩行、配圖、tag、日期；長按多選（只有刪除）。
class IdeaListPage extends ConsumerStatefulWidget {
  const IdeaListPage({super.key, required this.pitId});
  final String pitId;

  @override
  ConsumerState<IdeaListPage> createState() => _IdeaListPageState();
}

class _IdeaListPageState extends ConsumerState<IdeaListPage> {
  String? _tagId;
  bool _selecting = false;
  final Set<String> _selected = {};

  void _exit() => setState(() {
    _selecting = false;
    _selected.clear();
  });

  Future<void> _delete() async {
    final ok = await confirmDelete(
      context,
      title: '刪除 ${_selected.length} 個腦洞？',
    );
    if (!ok || !mounted) return;
    await ref.read(databaseProvider).deleteIdeas(_selected);
    if (mounted) _exit();
  }

  void _toggle(String id) => setState(() {
    if (!_selected.remove(id)) _selected.add(id);
    if (_selected.isEmpty) _selecting = false;
  });

  void _openNew() => Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => IdeaFormPage(pitId: widget.pitId)),
  );

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final pitName = ref.watch(pitProvider(widget.pitId)).value?.name;
    final tags = ref.watch(tagsProvider(widget.pitId)).value ?? const [];
    final tagId = tags.any((e) => e.id == _tagId) ? _tagId : null;
    final views =
        ref.watch(ideaViewsProvider((widget.pitId, tagId))).value ?? const [];
    final unhatched = views.where((v) => v.status != IdeaStatus.hatched).length;
    final title = pitName == null ? '我的腦洞' : '$pitName · 我的腦洞';
    return PopScope(
      canPop: !_selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _exit();
      },
      child: Scaffold(
        floatingActionButton: _selecting
            ? null
            : EntityFab(label: '新增腦洞', onPressed: _openNew),
        bottomNavigationBar: _selecting
            ? _SelectBar(enabled: _selected.isNotEmpty, onDelete: _delete)
            : null,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              if (_selecting)
                SubPageHeader(
                  title: '已選 ${_selected.length} 個',
                  leadingIcon: AppIcons.closeX,
                  leadingSize: 22,
                  leadingStroke: 2,
                  onBack: _exit,
                  trailing: [
                    TextButton(
                      onPressed: () => setState(() {
                        if (_selected.length == views.length) {
                          _selected.clear();
                          _selecting = false;
                        } else {
                          _selected.addAll(views.map((v) => v.idea.id));
                        }
                      }),
                      style: TextButton.styleFrom(
                        foregroundColor: t.piece.fg,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                      ),
                      child: const Text(
                        '全選',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                )
              else
                SubPageHeader(
                  title: title,
                  trailing: [
                    HeaderCount(
                      unhatched > 0
                          ? '${views.length} 個 · $unhatched 未孵'
                          : '${views.length} 個',
                    ),
                  ],
                ),
              if (tags.isNotEmpty)
                ChipRow(
                  options: [for (final e in tags) (e.id, '#${e.name}')],
                  selected: tagId,
                  onSelected: (v) => setState(() => _tagId = v),
                ),
              Expanded(
                child: views.isEmpty
                    ? EmptyState(
                        icon: Icons.lightbulb_outline,
                        text: '還沒有腦洞',
                        color: t.idea,
                        actionLabel: '記下第一個腦洞',
                        onAction: _openNew,
                      )
                    : ListView.separated(
                        padding: EdgeInsets.fromLTRB(
                          _selecting ? 16 : 20,
                          8,
                          20,
                          96,
                        ),
                        itemCount: views.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (_, i) {
                          final v = views[i];
                          final isSel = _selected.contains(v.idea.id);
                          final card = _IdeaCard(
                            view: v,
                            selected: isSel,
                            selecting: _selecting,
                          );
                          if (!_selecting) {
                            return GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => IdeaDetailPage(
                                    ideaId: v.idea.id,
                                    pitId: widget.pitId,
                                  ),
                                ),
                              ),
                              onLongPress: () => setState(() {
                                _selecting = true;
                                _selected.add(v.idea.id);
                              }),
                              child: card,
                            );
                          }
                          return GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => _toggle(v.idea.id),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(top: 16),
                                  child: SelectDot(isSel),
                                ),
                                const SizedBox(width: 12),
                                Expanded(child: card),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 選取模式底部：只有「刪除」。
class _SelectBar extends StatelessWidget {
  const _SelectBar({required this.enabled, required this.onDelete});
  final bool enabled;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final color = enabled ? t.danger : t.danger.withValues(alpha: 0.4);
    return Container(
      decoration: BoxDecoration(
        color: t.nav,
        border: Border(top: BorderSide(color: t.border)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: SafeArea(
        top: false,
        child: GestureDetector(
          onTap: enabled ? onDelete : null,
          behavior: HitTestBehavior.opaque,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SvgIcon(AppIcons.trash, size: 22, color: color),
                const SizedBox(height: 4),
                Text('刪除', style: TextStyle(color: color, fontSize: 11.5)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IdeaCard extends StatelessWidget {
  const _IdeaCard({
    required this.view,
    required this.selected,
    required this.selecting,
  });
  final IdeaView view;
  final bool selected;
  final bool selecting;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final idea = view.idea;
    return EntityCard(
      selected: selected,
      selecting: selecting,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  idea.title,
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    color: t.ink,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              IdeaStatusChip(view),
            ],
          ),
          if (idea.body.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              idea.body,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: t.text2, fontSize: 13, height: 1.55),
            ),
          ],
          if (view.images.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 54,
              child: ListView(
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  for (final im in view.images)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: SizedBox(
                        width: 54,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(9),
                          child: StoredImage(im.file, cacheWidth: 200),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: TagPills(view.tags)),
              const SizedBox(width: 6),
              Text(
                fmtMd(idea.createdAt),
                style: TextStyle(color: t.text4, fontSize: 11.5),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
