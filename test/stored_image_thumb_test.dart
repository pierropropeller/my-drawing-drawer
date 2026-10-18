import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huakeng/data/image_store.dart';
import 'package:huakeng/l10n/app_localizations.dart';
import 'package:huakeng/state/providers.dart';
import 'package:huakeng/theme/app_theme.dart';
import 'package:huakeng/ui/album/album_image.dart';
import 'package:image/image.dart' as img;

/// D-099：列表／封面的顯示優先順序＝本機縮圖 → 本機原圖 → 占位。
void main() {
  late Directory tmp;
  late ImageStore store;
  late Uint8List jpg;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('stored_thumb');
    store = ImageStore(Directory('${tmp.path}/images'));
    jpg = Uint8List.fromList(img.encodeJpg(img.Image(width: 16, height: 16)));
  });

  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [imageStoreProvider.overrideWith((ref) async => store)],
        child: MaterialApp(
          theme: buildTheme(Brightness.light, useGoogleFonts: false),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: Scaffold(body: SizedBox(width: 100, height: 100, child: child)),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  File? shown(WidgetTester tester) {
    final w = tester.widget<Image>(find.byType(Image).first);
    final p = w.image;
    final inner = p is ResizeImage ? p.imageProvider : p;
    return inner is FileImage ? inner.file : null;
  }

  testWidgets('小尺寸列表：有本機縮圖就讀縮圖；要大圖（沒給 cacheWidth／>480）讀原圖', (tester) async {
    await tester.runAsync(() async {
      await store.save('a.jpg', jpg);
      await store.saveThumb('a.jpg', jpg);
    });
    await pump(tester, const StoredImage('a.jpg', cacheWidth: 300));
    expect(shown(tester)!.path, store.thumbFileOf('a.jpg').path);
    await pump(tester, const StoredImage('a.jpg'));
    expect(shown(tester)!.path, store.fileOf('a.jpg').path);
    await pump(tester, const StoredImage('a.jpg', cacheWidth: 1200));
    expect(shown(tester)!.path, store.fileOf('a.jpg').path);
  });

  testWidgets('沒有縮圖：讀原圖（向後相容）', (tester) async {
    await tester.runAsync(() => store.save('b.jpg', jpg));
    await pump(tester, const StoredImage('b.jpg', cacheWidth: 300));
    expect(shown(tester)!.path, store.fileOf('b.jpg').path);
  });

  testWidgets('原圖還沒下載但縮圖已到：顯示縮圖（蓋層照舊），不是灰色占位', (tester) async {
    await tester.runAsync(() => store.saveThumb('c.jpg', jpg));
    await pump(tester, const StoredImage('c.jpg', cacheWidth: 300));
    expect(shown(tester)!.path, store.thumbFileOf('c.jpg').path);
  });

  testWidgets('原圖沒有、縮圖也沒有：占位', (tester) async {
    await pump(tester, const StoredImage('d.jpg', cacheWidth: 300));
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('不顯示角標的地方（原圖沒有但縮圖有）也用縮圖，不顯示破圖 icon', (tester) async {
    await tester.runAsync(() => store.saveThumb('e.jpg', jpg));
    await pump(
      tester,
      const StoredImage('e.jpg', cacheWidth: 300, showDownloadBadge: false),
    );
    expect(find.byIcon(Icons.broken_image_outlined), findsNothing);
  });
}
