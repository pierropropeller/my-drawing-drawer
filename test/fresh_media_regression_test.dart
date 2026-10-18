import 'dart:async';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huakeng/data/database.dart';
import 'package:huakeng/data/entity_queries.dart';
import 'package:huakeng/media/photo_manager_gallery.dart';
import 'package:photo_manager/photo_manager.dart' show DateTimeCond;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  group('相簿篩選條件不能凍結在第一次打開選擇器的時刻', () {
    test('每次建出來的上限都晚於「當下」，不是第一次的時間', () {
      var clock = DateTime(2026, 10, 1, 9);
      final first = PhotoManagerGallery.buildFilter(now: () => clock);
      expect(first.createTimeCond.max.isAfter(clock), isTrue);
      expect(first.updateTimeCond.max.isAfter(clock), isTrue);

      // 過了幾天，使用者又存了新圖，再開選擇器：新建的條件要涵蓋新時間。
      clock = DateTime(2026, 10, 5, 18);
      final later = PhotoManagerGallery.buildFilter(now: () => clock);
      expect(later.createTimeCond.max.isAfter(clock), isTrue);
      expect(later.updateTimeCond.max.isAfter(clock), isTrue);
      expect(identical(first, later), isFalse);
      // 舊的那份就是 bug 的樣子：蓋不到後來才存進手機的相片。
      expect(first.createTimeCond.max.isBefore(clock), isTrue);
    });

    test('不設時間下限（最早的相片也列得出來）、依建立時間新到舊', () {
      final f = PhotoManagerGallery.buildFilter();
      expect(f.createTimeCond.min, DateTimeCond.zero);
      expect(f.orders.single.asc, isFalse);
    });
  });

  group('watchAssembled', () {
    test('第一次取資料的期間有寫入：不會漏掉，取完會再取一次', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await db.createPit(name: 'a');
      final gate = Completer<void>();
      var calls = 0;
      final seen = <int>[];
      final sub = watchAssembled<int>(db, {db.pits}, () async {
        final n = (await db.select(db.pits).get()).length;
        if (calls++ == 0) await gate.future; // 模擬慢的第一次取資料
        return n;
      }).listen(seen.add);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await db.createPit(name: 'b'); // 第一次取資料還沒結束時寫入
      gate.complete();
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(seen.last, 2);
      await sub.cancel();
    });

    test('單次取資料失敗只送出錯誤，之後的變動仍會更新', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      var fail = false;
      final seen = <int>[];
      final errors = <Object>[];
      final sub =
          watchAssembled<int>(db, {db.pits}, () async {
            if (fail) throw StateError('boom');
            return (await db.select(db.pits).get()).length;
          }).listen(seen.add, onError: errors.add);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      fail = true;
      await db.createPit(name: 'a');
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(errors, hasLength(1));
      fail = false;
      await db.createPit(name: 'b');
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(seen.last, 2);
      await sub.cancel();
    });
  });
}
