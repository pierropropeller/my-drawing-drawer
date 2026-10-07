import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/settings.dart';
import '../../theme/tokens.dart';
import '../album/album_image.dart';

/// 使用者頭像：有自訂圖片用圖片，否則顯示暱稱第一個字。
class UserAvatar extends ConsumerWidget {
  const UserAvatar({super.key, this.size = 40});
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final s = ref.watch(settingsProvider);
    final initial = s.nickname.isEmpty ? '畫' : s.nickname.characters.first;
    return SizedBox(
      width: size,
      height: size,
      child: ClipOval(
        child: s.avatarFile != null
            ? StoredImage(s.avatarFile!, cacheWidth: (size * 3).round())
            : ColoredBox(
                color: t.piece.bg,
                child: Center(
                  child: Text(
                    initial,
                    style: TextStyle(
                      color: t.piece.fg,
                      fontSize: size * 0.45,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
