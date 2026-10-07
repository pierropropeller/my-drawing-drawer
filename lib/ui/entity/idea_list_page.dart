import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/entity_queries.dart';
import '../../state/providers.dart';
import '../../theme/tokens.dart';
import '../album/album_actions.dart';
import '../album/album_image.dart';
import '../album/album_view.dart';
import '../common/empty_state.dart';
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

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tags = ref.watch(tagsProvider(widget.pitId)).value ?? const [];
    final tagId = tags.any((e) => e.id == _tagId) ? _tagId : null;
    final views =
        ref.watch(ideaViewsProvider((widget.pitId, tagId))).value ?? const [];
    return PopScope(
      canPop: !_selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _exit();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: _selecting
              ? IconButton(icon: const Icon(Icons.close), onPressed: _exit)
              : null,
          title: Text(_selecting ? '已選 ${_selected.length} 個' : '我的腦洞'),
        ),
        floatingActionButton: _selecting
            ? null
            : FloatingActionButton(
                backgroundColor: t.accent,
                foregroundColor: Colors.white,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => IdeaFormPage(pitId: widget.pitId),
                  ),
                ),
                child: const Icon(Icons.add),
              ),
        bottomNavigationBar: _selecting
            ? SafeArea(
                child: TextButton.icon(
                  onPressed: _selected.isEmpty ? null : _delete,
                  icon: Icon(Icons.delete_outline, color: t.danger),
                  label: Text('刪除', style: TextStyle(color: t.danger)),
                ),
              )
            : null,
        body: Column(
          children: [
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
                      actionLabel: '新增',
                      onAction: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => IdeaFormPage(pitId: widget.pitId),
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                      itemCount: views.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (_, i) {
                        final v = views[i];
                        final isSel = _selected.contains(v.idea.id);
                        final card = _IdeaCard(view: v, selected: isSel);
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_selecting) ...[
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: 14,
                                  right: 10,
                                ),
                                child: SelectDot(isSel),
                              ),
                            ],
                            Expanded(
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  if (_selecting) {
                                    setState(() {
                                      if (!_selected.remove(v.idea.id)) {
                                        _selected.add(v.idea.id);
                                      }
                                      if (_selected.isEmpty) {
                                        _selecting = false;
                                      }
                                    });
                                  } else {
                                    Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) => IdeaDetailPage(
                                          ideaId: v.idea.id,
                                          pitId: widget.pitId,
                                        ),
                                      ),
                                    );
                                  }
                                },
                                onLongPress: () => setState(() {
                                  _selecting = true;
                                  _selected.add(v.idea.id);
                                }),
                                child: card,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IdeaCard extends StatelessWidget {
  const _IdeaCard({required this.view, required this.selected});
  final IdeaView view;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final idea = view.idea;
    return EntityCard(
      selected: selected,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  idea.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 8),
              IdeaStatusChip(view),
            ],
          ),
          if (idea.body.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              idea.body,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: t.text2, height: 1.4),
            ),
          ],
          if (view.images.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 64,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final im in view.images)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: SizedBox(
                        width: 64,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(Radii.image),
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
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: TagPills(view.tags)),
              Text(
                fmtDate(idea.createdAt),
                style: TextStyle(color: t.text3, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
