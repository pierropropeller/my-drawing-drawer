import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/entity_queries.dart';
import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../../theme/tokens.dart';
import '../album/album_actions.dart';
import '../album/album_image.dart';
import '../common/app_icons.dart';
import '../common/nav_bar_hidden.dart';
import '../common/responsive.dart';
import 'connect_field.dart';
import 'draft_form_page.dart';
import 'entity_widgets.dart';
import 'idea_detail_page.dart';
import 'image_gallery_page.dart';

/// 草稿詳情（沒有導覽列），三種情況（D-017）：
/// - 完整（DraftDetail）：大圖（多張時右上「1 / N」＋縮圖列）、標題、日期、內文、tag、關聯腦洞；
/// - 只有一張圖（DraftDetailOne）：大圖＋日期；
/// - 只有多張圖（DraftDetailMulti）：大圖＋「1 / N」＋縮圖列＋日期。
/// 右上角編輯、刪除；詳情頁不能新增關聯（D-037）。
class DraftDetailPage extends ConsumerStatefulWidget {
  const DraftDetailPage({
    super.key,
    required this.draftId,
    required this.pitId,
    this.onTagTap,
  });
  final String draftId;
  final String pitId;

  /// 點 tag 的回呼（預設不做事，搜尋接導覽）。
  final void Function(String tagId)? onTagTap;

  @override
  ConsumerState<DraftDetailPage> createState() => _DraftDetailPageState();
}

class _DraftDetailPageState extends ConsumerState<DraftDetailPage>
    with HidesNavBar<DraftDetailPage> {
  String get draftId => widget.draftId;
  String get pitId => widget.pitId;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final v = ref.watch(draftViewProvider(draftId)).value;
    if (v == null) return const Scaffold(body: SizedBox.shrink());
    final ideas = ref.watch(ideaViewsProvider((pitId, null))).value ?? const [];
    final mine = ideas.where((i) => v.ideaIds.contains(i.idea.id)).toList();
    final d = v.draft;
    final plain = v.imageOnly;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            SubPageHeader(
              title: context.l10n.draftDetailTitle,
              titleSize: 20,
              gap: 6,
              trailing: [
                HeaderIconButton(
                  icon: AppIcons.edit,
                  label: context.l10n.commonEdit,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          DraftFormPage(pitId: pitId, draftId: draftId),
                    ),
                  ),
                ),
                HeaderIconButton(
                  icon: AppIcons.trash,
                  label: context.l10n.commonDelete,
                  color: t.danger,
                  onTap: () async {
                    final ok = await confirmDelete(
                      context,
                      title: context.l10n.draftDetailDeleteTitle,
                    );
                    if (!ok || !context.mounted) return;
                    await ref.read(databaseProvider).deleteDrafts([draftId]);
                    if (context.mounted) Navigator.of(context).pop();
                  },
                ),
              ],
            ),
            Expanded(
              child: ContentWidth(
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 32),
                  children: [
                    _ImageStage(images: v.images),
                    if (plain)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                        child: Text(
                          fmtSlash(d.createdAt),
                          style: TextStyle(color: t.text4, fontSize: 12.5),
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Expanded(
                                  child: Text(
                                    d.title ?? '',
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall
                                        ?.copyWith(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  fmtSlash(d.createdAt),
                                  style: TextStyle(
                                    color: t.text4,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            if ((d.body ?? '').isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Text(
                                d.body!,
                                style: TextStyle(
                                  color: t.ink.withValues(alpha: 0.82),
                                  fontSize: 14.5,
                                  height: 1.75,
                                ),
                              ),
                            ],
                            if (v.tags.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              TagPills(
                                v.tags,
                                large: true,
                                onTagTap: widget.onTagTap,
                              ),
                            ],
                            if (mine.isNotEmpty) ...[
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: 20,
                                  bottom: 10,
                                ),
                                child: Text(
                                  context.l10n.ideaLinkedHeading,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  for (final i in mine)
                                    RelationChip(
                                      kind: ConnectKind.idea,
                                      title: i.idea.title,
                                      onTap: () => Navigator.of(context).push(
                                        MaterialPageRoute<void>(
                                          builder: (_) => IdeaDetailPage(
                                            ideaId: i.idea.id,
                                            pitId: pitId,
                                            onTagTap: widget.onTagTap,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
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

/// 大圖（3:4，可左右滑；點一下開全屏看圖）。多張時右上「1 / N」，下方縮圖列（目前這張描主色框）。
class _ImageStage extends StatefulWidget {
  const _ImageStage({required this.images});
  final List<ImageRef> images;

  @override
  State<_ImageStage> createState() => _ImageStageState();
}

class _ImageStageState extends State<_ImageStage> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _openGallery() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) =>
          ImageGalleryPage(images: widget.images, initialIndex: _index),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final images = widget.images;
    final multi = images.length > 1;
    // 平板上別讓 3:4 的大圖高過螢幕。
    final maxH = MediaQuery.sizeOf(context).height * 0.62;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (_, c) {
            final h = (c.maxWidth * 4 / 3).clamp(0.0, maxH);
            return SizedBox(
              height: h,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (images.isEmpty)
                    const ImagePlaceholder(iconSize: 44)
                  else
                    PageView.builder(
                      controller: _controller,
                      itemCount: images.length,
                      onPageChanged: (i) => setState(() => _index = i),
                      itemBuilder: (_, i) => GestureDetector(
                        onTap: _openGallery,
                        child: StoredImage(images[i].file, cacheWidth: 1000),
                      ),
                    ),
                  if (multi)
                    Positioned(
                      right: 12,
                      top: 12,
                      child: IgnorePointer(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2B2622)
                                .withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(Radii.chip),
                          ),
                          child: Text(
                            '${_index + 1} / ${images.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
        if (multi)
          SizedBox(
            height: 68,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              itemCount: images.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) => Semantics(
                button: true,
                label: context.l10n.draftDetailImageLabel(i + 1),
                child: GestureDetector(
                  onTap: () => _controller.jumpToPage(i),
                  child: Container(
                    width: 56,
                    height: 56,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: i == _index
                          ? Border.all(color: t.accent, width: 2)
                          : null,
                    ),
                    child: StoredImage(images[i].file, cacheWidth: 200),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
