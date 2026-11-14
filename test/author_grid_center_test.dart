import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huakeng/data/author_queries.dart';
import 'package:huakeng/data/database.dart';
import 'package:huakeng/l10n/l10n.dart';
import 'package:huakeng/theme/app_theme.dart';
import 'package:huakeng/ui/authors/author_widgets.dart';

/// 格子版作者卡：名字短也要置中，不能整欄靠左。
void main() {
  testWidgets('作者格子：頭像置中', (tester) async {
    final now = DateTime(2026);
    final a = Author(
      id: 'a',
      createdAt: now,
      updatedAt: now,
      deviceId: 'd',
      name: '1',
      handle: '',
      sortOrder: 0,
    );
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        theme: buildTheme(Brightness.light, useGoogleFonts: false),
        home: Center(
          child: SizedBox(
            width: 120,
            height: 150,
            child: AuthorGridTile(
              summary: AuthorSummary(author: a, count: 0, latest: const []),
            ),
          ),
        ),
      ),
    );
    final tile = tester.getCenter(find.byType(AuthorGridTile));
    final avatar = tester.getCenter(find.byType(AuthorAvatar));
    expect((avatar.dx - tile.dx).abs(), lessThan(1));
  });
}
