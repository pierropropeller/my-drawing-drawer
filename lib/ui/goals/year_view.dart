import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../data/goal_queries.dart';
import '../../state/providers.dart';
import '../../theme/tokens.dart';
import 'goal_widgets.dart';
import 'goals_page.dart';
import 'review_canvas.dart';
import 'review_edit_page.dart';

/// 年度：年度回顧 4×3 預覽（點進排版）＋年度目標列表。
class YearView extends ConsumerStatefulWidget {
  const YearView({super.key});

  @override
  ConsumerState<YearView> createState() => _YearViewState();
}

class _YearViewState extends ConsumerState<YearView> {
  int _year = DateTime.now().year;
  Map<int, List<String>> _byMonth = {};

  @override
  void initState() {
    super.initState();
    _loadMonths();
  }

  Future<void> _loadMonths() async {
    final m = await ref.read(databaseProvider).pieceImagesByMonth(_year);
    if (mounted) setState(() => _byMonth = m);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final chosen = ref.watch(reviewMonthsProvider(_year)).value ?? const {};
    final files = {
      for (var m = 1; m <= 12; m++)
        m: chosen.containsKey(m) ? chosen[m] : _byMonth[m]?.first,
    };
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        PeriodHeader(
          label: '$_year',
          onPrev: () {
            setState(() => _year--);
            _loadMonths();
          },
          onNext: () {
            setState(() => _year++);
            _loadMonths();
          },
        ),
        Row(
          children: [
            Expanded(
              child: Text(
                '年度回顧',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            TextButton(
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ReviewEditPage(year: _year),
                  ),
                );
                _loadMonths();
              },
              child: const Text('編輯排版'),
            ),
          ],
        ),
        GestureDetector(
          onTap: () async {
            await Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ReviewEditPage(year: _year),
              ),
            );
            _loadMonths();
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(Radii.image),
            child: ReviewCanvas(
              files: files,
              columns: 4,
              ratio: '1:1',
              monthFormat: 'Jan',
              monthOnImage: true,
              compact: true,
            ),
          ),
        ),
        const SizedBox(height: 24),
        GoalList(period: GoalPeriod.year, year: _year),
        const SizedBox(height: 0),
        Text('', style: TextStyle(color: t.text3)),
      ],
    );
  }
}
