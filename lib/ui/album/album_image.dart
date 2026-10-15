import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/media.dart';
import '../../state/providers.dart';
import '../../sync/sync_controller.dart';
import '../../theme/tokens.dart';
import '../common/app_icons.dart';
import '../common/gif_image.dart';
import '../common/media_source.dart';
import '../common/svg_icon.dart';
import '../sync/download_badge.dart';

enum AlbumKind { official, fanArt, junk }

/// 官方圖／同人圖的共同檢視資料。
class AlbumImage {
  const AlbumImage({
    required this.id,
    required this.file,
    required this.width,
    required this.height,
    required this.kind,
    this.author,
    this.groupName,
    this.groupId,
    this.createdAt,
    this.mediaKind = MediaKind.image,
    this.durationMs,
    this.posterFile,
  });

  final String id;
  final String file;
  final int width;
  final int height;
  final AlbumKind kind;

  /// 同人圖列表圖下方顯示的作者與分組（都留空就不顯示那一行）。
  final String? author;
  final String? groupName;

  /// 所屬分組（官方分組／同人圖出處）的 id；移動 sheet 用來預選目前的分組。
  final String? groupId;

  /// 加入時間（預覽頁顯示「2026 / 09 / 21 加入」）。
  final DateTime? createdAt;

  /// 媒體種類與影片資料（D-080，資料列的 `kind`／`durationMs`／`posterFile`）；預設是圖片。
  /// 建構時**一定要帶**，否則影片會被當成圖片（列表、預覽、下載都靠它）。
  final MediaKind mediaKind;
  final int? durationMs;
  final String? posterFile;

  MediaSource get media => MediaSource(
    file: file,
    // 呼叫端漏帶 mediaKind 時，退而依副檔名判斷（.gif／影片副檔名），免得影片被當成圖片。
    kind: mediaKind != MediaKind.image
        ? mediaKind
        : mediaKindFromExtension(file),
    durationMs: durationMs,
    poster: posterFile,
    width: width,
    height: height,
  );

  bool get hasCaption =>
      (author ?? '').isNotEmpty || (groupName ?? '').isNotEmpty;

  double get aspect => (width > 0 && height > 0) ? width / height : 1;
}

/// 顯示 App 內儲存的圖片；[cacheWidth] 用縮圖解碼，列表請務必指定。
///
/// 本機還沒有這張圖（同步還沒下載完，D-052）時：底色佔位＋35% 淡色＋右下角下載角標
/// （有進度＝確定進度環，排隊中＝轉圈）；下載完成自動換成圖片。蓋層不攔截點擊。
/// 頭像這類不該出現角標的地方傳 [showDownloadBadge] = false。
///
/// GIF（D-080，副檔名 `.gif` 或 [isGif]）：預設 [animate] = false，只畫**第一格靜態圖**
/// （封面、年度回顧、月曆格、表單縮圖都是這個）；要動的地方傳 `animate: true`，
/// 此時只在畫面上才播（見 [GifImage]）。影片不要直接傳影片檔，請用 `media_widgets.dart` 的元件。
class StoredImage extends ConsumerWidget {
  const StoredImage(
    this.file, {
    super.key,
    this.cacheWidth,
    this.fit = BoxFit.cover,
    this.placeholderColor,
    this.showDownloadBadge = true,
    this.animate = false,
    this.isGif,
  });

  final String file;

  /// GIF 要不要動（只對 GIF 有意義）。
  final bool animate;

  /// 明確指定是不是 GIF；null＝看副檔名。
  final bool? isGif;
  final int? cacheWidth;
  final BoxFit fit;

  /// 圖片還沒下載時的底色（預設 chipBg）。
  final Color? placeholderColor;
  final bool showDownloadBadge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final store = ref.watch(imageStoreProvider).value;
    if (store == null) return ColoredBox(color: t.chipBg);
    final status = showDownloadBadge
        ? ref.watch(imageTransferProvider(file))
        : ImageDownloadStatus.present;
    if (status.isMissing) {
      return _MissingImage(
        color: placeholderColor ?? t.chipBg,
        progress: status.progress,
      );
    }
    Widget broken(BuildContext _, Object _, StackTrace? _) => ColoredBox(
      color: t.chipBg,
      child: Icon(Icons.broken_image_outlined, color: t.text4),
    );
    final gif = isGif ?? file.toLowerCase().endsWith('.gif');
    if (gif) {
      final f = store.fileOf(file);
      return animate
          ? GifImage(
              file: f,
              fit: fit,
              cacheWidth: cacheWidth,
              errorBuilder: broken,
            )
          : FirstFrameImage(
              provider: ResizeImage.resizeIfNeeded(
                cacheWidth,
                null,
                FileImage(f),
              ),
              fit: fit,
              errorBuilder: broken,
            );
    }
    return Image.file(
      store.fileOf(file),
      fit: fit,
      cacheWidth: cacheWidth,
      errorBuilder: broken,
    );
  }
}

/// 還沒下載的圖：底色＋圖片佔位 icon＋[DownloadOverlay]。
/// 外層沒有給定大小（無限制）時退回 120 見方，免得 Stack 撐不開。
class _MissingImage extends StatelessWidget {
  const _MissingImage({required this.color, required this.progress});
  final Color color;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.hasBoundedWidth ? c.maxWidth : 120.0;
        final h = c.hasBoundedHeight ? c.maxHeight : 120.0;
        final side = w < h ? w : h;
        // 設計稿：大格 30px，sync sheet 的 44px 縮圖 16px，更小就不畫。
        final iconSize = side >= 60 ? 30.0 : (side >= 30 ? 16.0 : 0.0);
        return SizedBox(
          width: w,
          height: h,
          child: ColoredBox(
            color: color,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (iconSize > 0)
                  Center(
                    child: SvgIcon(
                      AppIcons.image,
                      size: iconSize,
                      strokeWidth: 1.6,
                      color: dark
                          ? Colors.white.withValues(alpha: .22)
                          : t.ink.withValues(alpha: .26),
                    ),
                  ),
                DownloadOverlay(progress: progress),
              ],
            ),
          ),
        );
      },
    );
  }
}

Future<File?> resolveFile(WidgetRef ref, String name) async {
  final store = await ref.read(imageStoreProvider.future);
  return store.fileOf(name);
}
