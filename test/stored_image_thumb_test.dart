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

/// D-099：原圖在本機＝原圖（小尺寸用本機 480 列表縮圖）；原圖不在＝模糊占位圖；都沒有＝占位。
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

  testWidgets('原圖還沒下載但占位圖已到：模糊顯示占位圖（蓋層照舊），不是灰色占位', (tester) async {
    await tester.runAsync(() => store.savePlaceholder('c.jpg', jpg));
    await pump(tester, const StoredImage('c.jpg', cacheWidth: 300));
    expect(shown(tester)!.path, store.placeholderFileOf('c.jpg').path);
    expect(find.byType(ImageFiltered), findsOneWidget);
  });

  testWidgets('原圖到了：占位圖換成原圖（不卡在模糊圖），占位檔已刪', (tester) async {
    await tester.runAsync(() => store.savePlaceholder('f.jpg', jpg));
    await pump(tester, const StoredImage('f.jpg', cacheWidth: 1200));
    expect(find.byType(ImageFiltered), findsOneWidget);
    await tester.runAsync(() => store.save('f.jpg', jpg));
    expect(store.hasPlaceholder('f.jpg'), isFalse);
    expect(store.placeholderFileOf('f.jpg').existsSync(), isFalse);
    await pump(tester, const StoredImage('f.jpg', cacheWidth: 1200));
    expect(find.byType(ImageFiltered), findsNothing);
    expect(shown(tester)!.path, store.fileOf('f.jpg').path);
  });

  testWidgets('占位圖不會被當成列表縮圖：原圖在本機時小尺寸仍讀原圖', (tester) async {
    await tester.runAsync(() async {
      await store.savePlaceholder('g.jpg', jpg);
      await store.save('g.jpg', jpg);
      await store.savePlaceholder('g.jpg', jpg);
    });
    expect(store.hasRealThumb('g.jpg'), isFalse);
    await pump(tester, const StoredImage('g.jpg', cacheWidth: 300));
    expect(shown(tester)!.path, store.fileOf('g.jpg').path);
  });

  testWidgets('原圖沒有、縮圖也沒有：占位', (tester) async {
    await pump(tester, const StoredImage('d.jpg', cacheWidth: 300));
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('不顯示角標的地方（原圖沒有但縮圖有）也用模糊占位圖，不顯示破圖 icon', (tester) async {
    await tester.runAsync(() => store.savePlaceholder('e.jpg', jpg));
    await pump(
      tester,
      const StoredImage('e.jpg', cacheWidth: 300, showDownloadBadge: false),
    );
    expect(find.byIcon(Icons.broken_image_outlined), findsNothing);
  });
}
