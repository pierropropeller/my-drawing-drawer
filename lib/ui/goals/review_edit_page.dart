import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';

import '../../data/database.dart';
import '../../data/goal_queries.dart';
import '../../state/providers.dart';
import '../../theme/tokens.dart';
import '../album/album_actions.dart';
import '../album/album_image.dart';
import '../album/album_view.dart';
import '../entity/entity_widgets.dart';
import 'review_canvas.dart';

/// 年度回顧排版：格數、比例、月份格式、月份位置；點某月可換圖；儲存並匯出 PNG。
class ReviewEditPage extends ConsumerStatefulWidget {
  const ReviewEditPage({super.key, required this.year});
  final int year;

  @override
  ConsumerState<ReviewEditPage> createState() => _ReviewEditPageState();
}

class _ReviewEditPageState extends ConsumerState<ReviewEditPage> {
  final _boundary = GlobalKey();
  int? _columns;
  String? _ratio;
  String? _format;
  bool? _onImage;
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
                      '${widget.year} 年 $month 月',
                      style: Theme.of(ctx).textTheme.titleLarge,
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, ''),
                    child: const Text('清除'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: options.isEmpty
                  ? Center(
                      child: Text(
                        '這個月沒有成圖',
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
      await Gal.putImageBytes(bytes, name: '畫坑-${widget.year}-回顧', album: '畫坑');
      if (mounted) showSnack(context, '已儲存到相簿');
    } catch (_) {
      if (mounted) showSnack(context, '匯出失敗');
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
    final current = ReviewSetting(
      year: widget.year,
      columns: columns,
      ratio: ratio,
      monthFormat: format,
      monthOnImage: onImage,
    );
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.year} 年度回顧'),
        actions: [
          TextButton(
            onPressed: _exporting ? null : () => _export(current),
            child: const Text('儲存並匯出圖片'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          RepaintBoundary(
            key: _boundary,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(Radii.image),
              child: ReviewCanvas(
                files: _files(chosen),
                columns: columns,
                ratio: ratio,
                monthFormat: format,
                monthOnImage: onImage,
                onTapMonth: (m) => _pickMonth(m, chosen),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text('點選某個月份可更換圖片', style: TextStyle(color: t.text3, fontSize: 12)),
          const SizedBox(height: 20),
          const FormLabel('格數'),
          ChipRow(
            padding: EdgeInsets.zero,
            allLabel: null,
            options: [for (final o in reviewColumnOptions) ('${o.$1}', o.$2)],
            selected: '$columns',
            onSelected: (v) => setState(() => _columns = int.parse(v!)),
          ),
          const SizedBox(height: 16),
          const FormLabel('比例'),
          ChipRow(
            padding: EdgeInsets.zero,
            allLabel: null,
            options: [for (final r in reviewRatioOptions) (r, r)],
            selected: ratio,
            onSelected: (v) => setState(() => _ratio = v),
          ),
          const SizedBox(height: 16),
          const FormLabel('月份格式'),
          ChipRow(
            padding: EdgeInsets.zero,
            allLabel: null,
            options: [for (final f in reviewMonthFormats) (f, f)],
            selected: format,
            onSelected: (v) => setState(() => _format = v),
          ),
          const SizedBox(height: 16),
          const FormLabel('月份位置'),
          ChipRow(
            padding: EdgeInsets.zero,
            allLabel: null,
            options: const [('image', '圖上'), ('blank', '空白位置')],
            selected: onImage ? 'image' : 'blank',
            onSelected: (v) => setState(() => _onImage = v == 'image'),
          ),
          if (_exporting)
            const Padding(
              padding: EdgeInsets.only(top: 20),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
