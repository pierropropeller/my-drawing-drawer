import 'package:flutter_test/flutter_test.dart';
import 'package:huakeng/data/database.dart';
import 'package:huakeng/l10n/l10n.dart';
import 'package:huakeng/ui/entity/entity_name.dart';

void main() {
  final l = l10nStatic;
  final d = DateTime(2026, 9, 10);

  test('D-129 名稱備援：標題 → 內文前 12 字 → 日期＋類型', () {
    expect(
      entityDisplayName(
        l,
        title: ' 月下的約定 ',
        body: 'x',
        date: d,
        kind: GoalKind.piece,
      ),
      '月下的約定',
    );
    expect(
      entityDisplayName(
        l,
        title: '',
        body: '如果他們變成貓，\n會是什麼品種、什麼性格',
        date: d,
        kind: GoalKind.idea,
      ),
      '如果他們變成貓， 會是什',
    );
    expect(
      entityDisplayName(
        l,
        title: null,
        body: '  ',
        date: d,
        kind: GoalKind.piece,
      ),
      '9/10 成圖',
    );
    expect(
      entityDisplayName(l, title: '', body: '', date: d, kind: GoalKind.idea),
      '9/10 腦洞',
    );
    expect(
      entityDisplayName(l, title: '', body: '', date: d, kind: GoalKind.draft),
      '9/10 摸魚',
    );
  });
}
