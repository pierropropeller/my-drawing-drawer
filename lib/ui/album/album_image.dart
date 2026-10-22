import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../data/image_store.dart';
import '../../data/media.dart';
import '../../state/providers.dart';
import '../../sync/sync_controller.dart';
import '../../theme/tokens.dart';
import '../common/app_icons.dart';
import '../common/gif_image.dart';
import '../common/media_source.dart';
import '../common/sensitive_gate.dart';
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
      // 占位圖到了要重建（D-099：原圖還沒到＝模糊占位圖，原圖到了才換成清楚的）。
      ref.watch(thumbVersionProvider(file));
      return _MissingImage(
        color: placeholderColor ?? t.chipBg,
        progress: status.progress,
        showBadge: status.showBadge,
        placeholder: store.placeholderFileFor(file),
      );
    }
    Widget broken(BuildContext _, Object _, StackTrace? _) {
      // 原圖讀不到（還沒下載、不顯示角標的地方）：有占位圖就模糊顯示。
      final ph = store.placeholderFileFor(file);
      if (ph != null) return BlurredPlaceholder(ph);
      return ColoredBox(
        color: t.chipBg,
        child: Icon(Icons.broken_image_outlined, color: t.text4),
      );
    }

    if (!showDownloadBadge) {
      // 不顯示角標的地方（頭像等）：原圖不在本機就模糊占位圖；原圖到了自動換。
      ref.watch(imageExistsProvider(file));
      if (!store.exists(file)) {
        ref.watch(thumbVersionProvider(file));
        return broken(context, '', null);
      }
    }

    // 列表用的小尺寸優先讀本機縮圖（約 30KB，比解碼原圖快很多）；GIF 要動時才讀原檔。
    // （thumbFileFor 只回本機產生的列表縮圖，下載來的占位圖不算。）
    if (!animate &&
        cacheWidth != null &&
        cacheWidth! <= ImageStore.thumbMaxEdge) {
      final thumb = store.thumbFileFor(file);
      if (thumb != null) {
        return Image.file(
          thumb,
          fit: fit,
          cacheWidth: cacheWidth,
          errorBuilder: broken,
        );
      }
    }
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

/// 原圖還沒到時的模糊占位圖（D-099）：32px 的小圖放大填滿格子，再套強烈高斯模糊，
/// 裁在格子範圍內（舊版留下的 480 縮圖也照此顯示）。模糊程度依格子大小等比放大。
class BlurredPlaceholder extends StatelessWidget {
  const BlurredPlaceholder(this.file, {super.key});
  final File file;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.hasBoundedWidth ? c.maxWidth : 120.0;
        final h = c.hasBoundedHeight ? c.maxHeight : 120.0;
        final side = w < h ? w : h;
        final sigma = (side / 10).clamp(2.0, 30.0);
        return SizedBox(
          width: w,
          height: h,
          child: ClipRect(
            child: ImageFiltered(
              imageFilter: ui.ImageFilter.blur(
                sigmaX: sigma,
                sigmaY: sigma,
                tileMode: TileMode.clamp,
              ),
              child: Image.file(
                file,
                width: w,
                height: h,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.medium,
                cacheWidth: ImageStore.placeholderCacheWidth,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 還沒下載的圖：底色＋（模糊占位圖，沒有就圖片佔位 icon）＋[DownloadOverlay]。
/// 外層沒有給定大小（無限制）時退回 120 見方，免得 Stack 撐不開。
class _MissingImage extends StatelessWidget {
  const _MissingImage({
    required this.color,
    required this.progress,
    this.showBadge = true,
    this.placeholder,
  });
  final Color color;
  final double? progress;
  final bool showBadge;

  /// 本機已有占位圖時模糊畫它（蓋層照舊），否則畫占位 icon。
  final File? placeholder;

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
                if (placeholder != null)
                  BlurredPlaceholder(placeholder!)
                else if (iconSize > 0)
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
                if (showBadge) DownloadOverlay(progress: progress),
              ],
            ),
          ),
        );
      },
    );
  }
}

extension PitCoverRef on Pit {
  /// 這個坑有指定封面（封面圖本身可能還沒同步進來）。
  bool get hasCoverRef => coverImageId != null || (coverFile ?? '').isNotEmpty;
}

/// 坑封面：[file] 有值＝[StoredImage]；沒有但封面已指定（[hasCoverRef]）且同步中／首次同步未完成
/// ＝封面圖的資料還沒同步進來，畫 [fallback] 底＋排隊中角標；否則畫 [fallback]（沒有封面）。
class PitCoverImage extends ConsumerWidget {
  const PitCoverImage({
    super.key,
    required this.file,
    required this.hasCoverRef,
    required this.fallback,
    required this.placeholderColor,
    this.cacheWidth,
  });
  final String? file;
  final bool hasCoverRef;
  final Widget fallback;
  final Color placeholderColor;
  final int? cacheWidth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (file != null) {
      // 封面不會是敏感的圖（選擇封面不列出、標記時會移除）；萬一是（標記先於開關），列表上照安全模式處理。
      return SensitiveGate(
        file: file!,
        child: StoredImage(
          file!,
          cacheWidth: cacheWidth,
          placeholderColor: placeholderColor,
        ),
      );
    }
    if (hasCoverRef && ref.watch(pitCoverPendingProvider)) {
      return Stack(
        fit: StackFit.expand,
        children: [fallback, const DownloadOverlay(progress: null)],
      );
    }
    return fallback;
  }
}

Future<File?> resolveFile(WidgetRef ref, String name) async {
  final store = await ref.read(imageStoreProvider.future);
  return store.fileOf(name);
}
