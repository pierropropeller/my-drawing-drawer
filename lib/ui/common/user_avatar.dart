import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/providers.dart';
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
    // 頭像檔還沒同步下載到（換了新裝置）：先顯示暱稱第一個字，檔案或縮圖到了再換成圖片。
    final file = s.avatarFile;
    var hasImage = false;
    if (file != null) {
      final store = ref.watch(imageStoreProvider).value;
      ref.watch(imageExistsProvider(file));
      ref.watch(thumbVersionProvider(file));
      hasImage =
          store != null && (store.exists(file) || store.hasThumb(file));
    }
    return SizedBox(
      width: size,
      height: size,
      child: ClipOval(
        child: hasImage
            ? StoredImage(
                file!,
                cacheWidth: (size * 3).round(),
                showDownloadBadge: false,
              )
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
