import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/settings.dart';
import '../../theme/tokens.dart';
import '../album/album_image.dart';
import '../../l10n/l10n.dart';

/// 使用者頭像：有自訂圖片用圖片，否則顯示暱稱第一個字。
class UserAvatar extends ConsumerWidget {
  const UserAvatar({
    super.key,
    this.size = 40,
    this.background,
    this.foreground,
    this.serif = false,
  });
  final double size;

  /// 沒有自訂圖片時的底色／字色（預設用 piece 分類色）；[serif] 用襯線字（我的頁大頭像）。
  final Color? background;
  final Color? foreground;
  final bool serif;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final s = ref.watch(settingsProvider);
    final initial = s.nickname.isEmpty
        ? context.l10n.meAvatarFallback
        : s.nickname.characters.first;
    return SizedBox(
      width: size,
      height: size,
      child: ClipOval(
        child: s.avatarFile != null
            ? StoredImage(s.avatarFile!, cacheWidth: (size * 3).round())
            : ColoredBox(
                color: background ?? t.piece.bg,
                child: Center(
                  child: Text(
                    initial,
                    style:
                        (serif
                                ? Theme.of(context).textTheme.headlineSmall
                                : null)
                            ?.copyWith(
                              color: foreground ?? t.piece.fg,
                              fontSize: size * 0.45,
                              fontWeight: FontWeight.w700,
                            ) ??
                        TextStyle(
                          color: foreground ?? t.piece.fg,
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
