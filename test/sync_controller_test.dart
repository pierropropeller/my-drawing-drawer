import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huakeng/data/album_queries.dart';
import 'package:huakeng/data/database.dart';
import 'package:huakeng/data/image_store.dart';
import 'package:huakeng/state/providers.dart';
import 'package:huakeng/state/settings.dart';
import 'package:huakeng/sync/remote.dart';
import 'package:huakeng/sync/sync_controller.dart';
import 'package:huakeng/sync/sync_engine.dart';

/// 首次同步的狀態（D-027／D-028）：圖片進度、isFirstSync、背景繼續、較新格式的錯誤。
void main() {
  late AppDatabase db;
  late Directory dir;
  late MemoryRemote remote;
  late ProviderContainer container;

  setUp(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    db = AppDatabase(NativeDatabase.memory());
    dir = await Directory.systemTemp.createTemp('sync_ctl');
    remote = MemoryRemote();
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        imageStoreProvider.overrideWith((ref) async => ImageStore(dir)),
        syncRemoteProvider.overrideWithValue(remote),
        onlineProvider.overrideWith((ref) => Stream.value(true)),
      ],
    );
    container.read(settingsProvider.notifier).setAccount('me@example.com');
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<void> seedImages(int n) async {
    final pitId = await db.createPit(name: 'x');
    final group = (await db.watchGroups(pitId).first).first;
    final images = <NewImage>[];
    for (var i = 0; i < n; i++) {
      File('${dir.path}/$i.png').writeAsBytesSync(Uint8List.fromList([i]));
      images.add(NewImage(file: '$i.png'));
    }
    await db.addOfficial(pitId, group.id, images);
  }

  test('首次同步：isFirstSync、圖片進度，完成後記下帳號', () async {
    await seedImages(3);
    expect(container.read(firstSyncPendingProvider), isTrue);
    final seen = <SyncState>[];
    container.listen(syncControllerProvider, (_, s) => seen.add(s));

    expect(
      await container.read(syncControllerProvider.notifier).startFirstSync(),
      isTrue,
    );

    expect(seen.first.isSyncing, isTrue);
    expect(seen.first.isFirstSync, isTrue);
    final up = seen
        .where((s) => s.stage == SyncStage.uploading && s.isSyncing)
        .toList();
    expect(up.last.imagesDone, 3);
    expect(up.last.imagesTotal, 3);
    expect(up.last.hasImageProgress, isTrue);
    expect(up.last.imageFraction, 1.0);
    final end = container.read(syncControllerProvider);
    expect(end.phase, SyncPhase.idle);
    expect(end.isFirstSync, isFalse);
    expect(end.lastSyncAt, isNotNull);
    expect(container.read(firstSyncPendingProvider), isFalse);
    expect(container.read(settingsProvider).syncedAccount, 'me@example.com');

    // 第二次不再是首次
    seen.clear();
    await container.read(syncControllerProvider.notifier).syncNow();
    expect(seen.first.isFirstSync, isFalse);
  });

  test('背景繼續：startFirstSyncInBackground 立即返回，之後狀態自行走完', () async {
    await seedImages(2);
    final ctl = container.read(syncControllerProvider.notifier);
    ctl.startFirstSyncInBackground();
    expect(container.read(syncControllerProvider).isSyncing, isTrue);
    // 等背景同步結束
    for (var i = 0; i < 200; i++) {
      if (!container.read(syncControllerProvider).isSyncing) break;
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(container.read(syncControllerProvider).phase, SyncPhase.idle);
    expect(container.read(firstSyncPendingProvider), isFalse);
  });

  test('遠端備份格式較新：錯誤訊息與 needsAppUpdate', () async {
    remote.files['meta__app__format.json'] = Uint8List.fromList(
      utf8.encode(jsonEncode({'formatVersion': syncFormatVersion + 1})),
    );
    await container.read(syncControllerProvider.notifier).syncNow();
    final s = container.read(syncControllerProvider);
    expect(s.phase, SyncPhase.error);
    expect(s.needsAppUpdate, isTrue);
    expect(s.message, '此備份由較新版本建立，請先更新 App');
    expect(container.read(firstSyncPendingProvider), isTrue); // 沒完成，不記為已同步
  });

  test('設定：預設幣種 CNY，可改', () {
    expect(container.read(settingsProvider).defaultCurrency, 'CNY');
    container.read(settingsProvider.notifier).setDefaultCurrency('HKD');
    expect(container.read(settingsProvider).defaultCurrency, 'HKD');
  });

  test('imageExistsProvider：下載完成後變 true', () async {
    final store = await container.read(imageStoreProvider.future);
    final values = <bool>[];
    container.listen(
      imageExistsProvider('c.png'),
      (_, v) => v.whenData(values.add),
      fireImmediately: true,
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await store.save('c.png', Uint8List.fromList([1]));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(values.last, isTrue);
    expect(values.first, isFalse);
  });
}
