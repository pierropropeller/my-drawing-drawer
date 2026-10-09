import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';

import '../../data/database.dart';
import '../../data/goal_queries.dart';
import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../../theme/tokens.dart';
import '../album/album_actions.dart';
import '../album/album_image.dart';
import '../common/nav_bar_hidden.dart';
import '../common/responsive.dart';
import '../entity/entity_widgets.dart';
import 'review_canvas.dart';

/// 年度回顧匯出圖片存進的相簿名稱（D-007）：固定英文，不隨系統語言（Android：`Pictures/Drawer`）。
const reviewAlbumName = 'Drawer';

/// 年度回顧排版：格數、比例、月份格式、月份位置；點某月可換圖；儲存並匯出 PNG。
class ReviewEditPage extends ConsumerStatefulWidget {
  const ReviewEditPage({super.key, required this.year});
  final int year;

  @override
  ConsumerState<ReviewEditPage> createState() => _ReviewEditPageState();
}

class _ReviewEditPageState extends ConsumerState<ReviewEditPage>
    with HidesNavBar {
  final _boundary = GlobalKey();
  int? _columns;
  String? _ratio;
  String? _format;
  bool? _onImage;
  String? _align; // 使用者明確選過的月份對齊；null＝跟隨預設
  Map<int, List<String>> _byMonth = {};
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    ref.read(databaseProvider).pieceImagesByMonth(widget.year).then((m) {
      if (mounted) setState(() => _byMonth = m);
    });
  }

  Map<int, String?> _files(Map<int, String?> chosen) => {
    for (var m = 1; m <= 12; m++)
      m: chosen.containsKey(m) ? chosen[m] : (_byMonth[m]?.first),
  };

  Future<void> _pickMonth(int month, Map<int, String?> chosen) async {
    final options = _byMonth[month] ?? const [];
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        builder: (_, controller) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      ctx.l10n.goalsReviewMonthSheetTitle(widget.year, month),
                      style: Theme.of(ctx).textTheme.titleLarge,
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, ''),
                    child: Text(ctx.l10n.goalsClear),
                  ),
                ],
              ),
            ),
            Expanded(
              child: options.isEmpty
                  ? Center(
                      child: Text(
                        ctx.l10n.goalsNoPieceThisMonth,
                        style: TextStyle(color: ctx.tokens.text3),
                      ),
                    )
                  : GridView.builder(
                      controller: controller,
                      padding: const EdgeInsets.all(16),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                          ),
                      itemCount: options.length,
                      itemBuilder: (_, i) => GestureDetector(
                        onTap: () => Navigator.pop(ctx, options[i]),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(Radii.image),
                          child: StoredImage(options[i], cacheWidth: 300),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
    if (picked == null) return;
    await ref
        .read(databaseProvider)
        .setReviewMonth(widget.year, month, picked.isEmpty ? null : picked);
  }

  Future<void> _export(ReviewSetting s) async {
    setState(() => _exporting = true);
    final db = ref.read(databaseProvider);
    await db.saveReviewSettings(s);
    try {
      await WidgetsBinding.instance.endOfFrame;
      final boundary =
          _boundary.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3);
      final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!
          .buffer
          .asUint8List();
      if (!await Gal.hasAccess()) {
        await Gal.requestAccess();
      }
      await Gal.putImageBytes(
        bytes,
        name: 'Drawer-${widget.year}-review',
        album: reviewAlbumName,
      );
      if (mounted) showSnack(context, context.l10n.goalsSavedToAlbum);
    } catch (_) {
      if (mounted) showSnack(context, context.l10n.goalsExportFailed);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final saved = ref.watch(reviewSettingsProvider(widget.year)).value;
    final chosen =
        ref.watch(reviewMonthsProvider(widget.year)).value ?? const {};
    if (saved == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final columns = _columns ?? saved.columns;
    final ratio = _ratio ?? saved.ratio;
    final format = _format ?? saved.monthFormat;
    final onImage = _onImage ?? saved.monthOnImage;
    // 沒選過對齊時，預設跟著月份位置走：圖上＝靠左、空白位置＝置中。
    final align = _align ?? saved.monthAlign ?? (onImage ? 'start' : 'center');
    final current = saved.copyWith(
      columns: columns,
      ratio: ratio,
      monthFormat: format,
      monthOnImage: onImage,
      monthAlign: Value(_align ?? saved.monthAlign),
    );
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ContentWidth(
          child: Column(
            children: [
              SubPageHeader(
                title: context.l10n.goalsReviewLayoutTitle,
                titleSize: 20,
                gap: 6,
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
                  children: [
                    _Sec(context.l10n.goalsLayout, top: 0),
                    LayoutBuilder(
                      builder: (context, c) => Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final o in reviewColumnOptions)
                            _LayoutOption(
                              width: ((c.maxWidth - 16) / 3).floorToDouble(),
                              columns: o.$1,
                              label: o.$2,
                              selected: columns == o.$1,
                              dark: dark,
                              onTap: () => setState(() => _columns = o.$1),
                            ),
                        ],
                      ),
                    ),
                    _Sec(context.l10n.goalsRatio),
                    _Choices(
                      options: reviewRatioOptions,
                      selected: ratio,
                      onSelected: (v) => setState(() => _ratio = v),
                    ),
                    _Sec(context.l10n.goalsMonthFormat),
                    _Choices(
                      options: reviewMonthFormats,
                      labelOf: (o) => monthFormatOptionLabel(context.l10n, o),
                      selected: format,
                      onSelected: (v) => setState(() => _format = v),
                    ),
                    _Sec(context.l10n.goalsMonthPosition),
                    Row(
                      spacing: 8,
                      children: [
                        for (final (on, label) in [
                          (true, context.l10n.goalsOnImage),
                          (false, context.l10n.goalsBlankSpace),
                        ])
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _onImage = on),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: onImage == on ? t.ink : t.surface,
                                  border: Border.all(color: t.border),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  label,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: onImage == on ? t.ground : t.text2,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    _Sec(context.l10n.goalsMonthAlign),
                    Row(
                      spacing: 8,
                      children: [
                        for (final (key, label) in [
                          ('start', context.l10n.goalsAlignStart),
                          ('center', context.l10n.goalsAlignCenter),
                          ('end', context.l10n.goalsAlignEnd),
                        ])
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _align = key),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: align == key ? t.ink : t.surface,
                                  border: Border.all(color: t.border),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  label,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: align == key ? t.ground : t.text2,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: t.surface,
                        border: Border.all(color: t.borderCard),
                        borderRadius: BorderRadius.circular(Radii.card),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.l10n.goalsPreview,
                            style: TextStyle(fontSize: 11, color: t.text3),
                          ),
                          const SizedBox(height: 12),
                          // 外框＝匯出圖片的邊界（無圓角）；框內的白邊會一起匯出，框線不會。
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(
                                color: dark
                                    ? t.dashed
                                    : const Color(0xFFD8CFC3),
                              ),
                            ),
                            child: RepaintBoundary(
                              key: _boundary,
                              child: ReviewCanvas(
                                files: _files(chosen),
                                columns: columns,
                                ratio: ratio,
                                monthFormat: format,
                                monthOnImage: onImage,
                                monthAlign: align,
                                onTapMonth: (m) => _pickMonth(m, chosen),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: _exporting ? null : () => _export(current),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _exporting
                              ? t.accent.withValues(alpha: .5)
                              : t.accent,
                          borderRadius: BorderRadius.circular(Radii.button),
                        ),
                        child: Text(
                          context.l10n.goalsSaveExport,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    if (_exporting)
                      const Padding(
                        padding: EdgeInsets.only(top: 20),
                        child: Center(child: CircularProgressIndicator()),
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
}

/// 區塊標題 14/700。
class _Sec extends StatelessWidget {
  const _Sec(this.text, {this.top = 18});
  final String text;
  final double top;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(2, top, 0, 9),
    child: Text(
      text,
      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
    ),
  );
}

/// 排版選項：迷你 12 格示意＋「列 × 欄」標籤；選中＝主色 1.5px 邊＋淡主色底。
class _LayoutOption extends StatelessWidget {
  const _LayoutOption({
    required this.width,
    required this.columns,
    required this.label,
    required this.selected,
    required this.dark,
    required this.onTap,
  });
  final double width;
  final int columns;
  final String label;
  final bool selected;
  final bool dark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final dot = selected
        ? t.accent
        : (dark ? t.dashed : const Color(0xFFD8CFC3));
    final bg = selected
        ? (dark ? t.accent.withValues(alpha: .14) : const Color(0xFFFFF6F2))
        : t.surface;
    final rows = 12 ~/ columns;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: selected ? t.accent : t.border, width: 1.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 34,
              child: Column(
                spacing: 1.5,
                children: [
                  for (var r = 0; r < rows; r++)
                    Expanded(
                      child: Row(
                        spacing: 1.5,
                        // 沒有子元素的 ColoredBox 在寬鬆高度約束下會縮成 0 高，要讓每格在垂直方向撐滿。
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var i = 0; i < columns; i++)
                            Expanded(child: ColoredBox(color: dot)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 7),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? t.ink : t.text3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 膠囊單選列：選中＝墨色底、反色字；12.5/500。
class _Choices extends StatelessWidget {
  const _Choices({
    required this.options,
    required this.selected,
    required this.onSelected,
    this.labelOf,
  });
  final String Function(String)? labelOf;
  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Wrap(
      spacing: 7,
      runSpacing: 7,
      children: [
        for (final o in options)
          GestureDetector(
            onTap: () => onSelected(o),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: o == selected ? t.ink : t.surface,
                border: Border.all(color: t.border),
                borderRadius: BorderRadius.circular(Radii.chip),
              ),
              child: Text(
                labelOf?.call(o) ?? o,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: o == selected ? t.ground : t.text2,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
