import 'package:drift/drift.dart';

import 'database.dart';

/// 使用者資料（暱稱、頭像）的單例列 id。
const profileDocId = 'me';

extension ProfileQueries on AppDatabase {
  Future<UserProfile?> getProfile() => (select(
    userProfiles,
  )..where((t) => t.id.equals(profileDocId))).getSingleOrNull();

  /// 儲存使用者資料並把 updatedAt 設成 [at]（預設現在），之後同步會上傳。
  Future<void> saveProfile({
    required String nickname,
    required String? avatarFile,
    DateTime? at,
  }) => into(userProfiles).insert(
    UserProfilesCompanion(
      id: const Value(profileDocId),
      nickname: Value(nickname),
      avatarFile: Value(avatarFile),
      updatedAt: Value(at ?? DateTime.now()),
    ),
    mode: InsertMode.insertOrReplace, // 整列覆寫，頭像清成 null 也要寫進去
  );
}
