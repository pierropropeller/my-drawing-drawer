import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

/// 主頁：現坑（archived=false）／封存坑（archived=true）。
final pitsProvider = StreamProvider.family<List<Pit>, bool>(
  (ref, archived) => ref.watch(databaseProvider).watchPits(archived: archived),
);

final pitProvider = StreamProvider.family<Pit?, String>(
  (ref, id) => ref.watch(databaseProvider).watchPit(id),
);

final pitStatsProvider = StreamProvider.family<PitStats, String>(
  (ref, id) => ref.watch(databaseProvider).watchPitStats(id),
);
