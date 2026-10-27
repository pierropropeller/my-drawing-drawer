import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/oshi_queries.dart';
import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../../theme/tokens.dart';
import '../album/album_actions.dart';
import '../common/app_icons.dart';
import '../common/detail_carousel.dart';
import '../common/sensitive_safe_button.dart';
import '../common/nav_bar_hidden.dart';
import '../common/responsive.dart';
import '../common/svg_icon.dart';
import '../common/timeline.dart';
import '../entity/entity_widgets.dart';
import '../search/tagged_list.dart';
import '../entity/post_swipe.dart';
import 'oshi_form_page.dart';
import 'oshi_icons.dart';

/// 推活詳情（OshiDetail）：正方形圖片輪播（右下「1 / N」＋圓點，點圖進全屏看圖）、
/// 日期（含星期）＋分組 chip、標題、描述、tag（可點，進坑內搜尋結果頁）。
/// 右上編輯、刪除。沒有導覽列。
class OshiDetailPage extends ConsumerStatefulWidget {
  const OshiDetailPage({
    super.key,
    required this.pitId,
    required this.recordId,
    this.order,
    this.onShown,
  });
  final String pitId;
  final String recordId;

  /// 上／下篇的次序（進來前那個列表的次序，D-122）；null＝只有這一篇。
  final List<String>? order;
  final ValueChanged<String>? onShown;

  @override
  ConsumerState<OshiDetailPage> createState() => _OshiDetailPageState();
}

class _OshiDetailPageState extends ConsumerState<OshiDetailPage>
    with HidesNavBar<OshiDetailPage> {
  Future<void> _delete(String id, VoidCallback afterDelete) async {
    final ok = await confirmDelete(
      context,
      title: context.l10n.oshiDeleteTitle,
      toTrash: true,
    );
    if (!ok || !mounted) return;
    await ref.read(databaseProvider).deleteOshiRecords([id]);
    if (mounted) afterDelete();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      bottom: false,
      child: PostSwipeView(
        initialId: widget.recordId,
        order: widget.order,
        onShown: widget.onShown,
        header: _header,
        body: (context, id) =>
            _OshiDetailBody(pitId: widget.pitId, recordId: id),
      ),
    ),
  );

  Widget _header(BuildContext context, String id, VoidCallback afterDelete) {
    final t = context.tokens;
    final v = ref.watch(oshiRecordProvider(id)).value;
    return SubPageHeader(
      title: '',
      trailing: [
        SensitiveSafeButton(
          files: v == null ? const [] : flaggableFiles(v.images),
        ),
        HeaderIconButton(
          icon: AppIcons.edit,
          label: context.l10n.commonEdit,
          onTap: () =>
              openOshiFormPage(context, pitId: widget.pitId, recordId: id),
        ),
        HeaderIconButton(
          icon: AppIcons.trash,
          label: context.l10n.commonDelete,
          color: t.danger,
          onTap: () => _delete(id, afterDelete),
        ),
      ],
    );
  }
}

/// 一篇推活的內容（換篇時整塊跟手指移動；圖片輪播的頁碼各篇自己記）。
class _OshiDetailBody extends ConsumerStatefulWidget {
  const _OshiDetailBody({required this.pitId, required this.recordId});
  final String pitId;
  final String recordId;

  @override
  ConsumerState<_OshiDetailBody> createState() => _OshiDetailBodyState();
}

class _OshiDetailBodyState extends ConsumerState<_OshiDetailBody> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final v = ref.watch(oshiRecordProvider(widget.recordId)).value;
    if (v == null) return const SizedBox.shrink();
    final n = v.images.length;
    final index = _index.clamp(0, n - 1);
    final desc = v.record.description ?? '';
    final title = v.record.title ?? '';
    return ContentWidth(
      maxWidth: 560,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          DetailCarousel(
            images: v.images,
            controller: _controller,
            onPageChanged: (i) => setState(() => _index = i),
            cacheWidth: 900,
          ),
          if (n > 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 10, 0, 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                spacing: 5,
                children: [
                  for (var i = 0; i < n; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: i == index ? 16 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: i == index
                            ? t.ink
                            : (Theme.of(context).brightness == Brightness.dark
                                  ? t.dashed
                                  : const Color(0xFFD8CFC3)),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      context.l10n.oshiDetailDate(
                        fmtSlash(v.date),
                        weekdayLabel(context.l10n, v.date),
                      ),
                      style: TextStyle(color: t.text2, fontSize: 13.5),
                    ),
                    if (v.group != null)
                      Container(
                        padding: const EdgeInsets.fromLTRB(8, 3, 10, 3),
                        decoration: BoxDecoration(
                          color: t.oshi.bg,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          spacing: 4,
                          children: [
                            SvgIcon(
                              OshiIcons.folder,
                              size: 14,
                              strokeWidth: 1.8,
                              color: t.oshi.fg,
                            ),
                            Text(
                              v.group!.name,
                              style: TextStyle(
                                color: t.oshi.fg,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                if (title.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(fontSize: 21, fontWeight: FontWeight.w700),
                  ),
                ],
                if (desc.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    desc,
                    style: TextStyle(
                      color: t.ink.withValues(alpha: 0.82),
                      fontSize: 14.5,
                      height: 1.7,
                    ),
                  ),
                ],
                if (v.tags.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final tag in v.tags)
                        GestureDetector(
                          onTap: () =>
                              openTagSearch(context, widget.pitId, tag.id),
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: t.chipBg,
                              borderRadius: BorderRadius.circular(Radii.chip),
                            ),
                            child: Text(
                              '#${tag.name}',
                              style: TextStyle(color: t.text2, fontSize: 12.5),
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
    );
  }
}
