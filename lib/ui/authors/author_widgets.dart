import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/author_link.dart';
import '../../data/author_queries.dart';
import '../../data/database.dart';
import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../../theme/tokens.dart';
import '../album/album_image.dart';
import '../common/app_icons.dart';
import '../common/media_widgets.dart';
import '../common/svg_icon.dart';
import 'author_icons.dart';

/// 沒有頭像時的底色／字色（設計稿七組，依作者 id 固定挑一組）。
const _avatarPalette = [
  (Color(0xFFE9C9D3), Color(0xFF8E4A5E)),
  (Color(0xFFC9D9E6), Color(0xFF3F5F7C)),
  (Color(0xFFEED7B8), Color(0xFF86602E)),
  (Color(0xFFCFE0CB), Color(0xFF4C6E45)),
  (Color(0xFFD9D0E8), Color(0xFF5E4F82)),
  (Color(0xFFF3D3C8), Color(0xFF9A4A33)),
  (Color(0xFFE4DCD0), Color(0xFF6E655B)),
];

/// 沒有封面時的底色（同一組顏色的淡色版）。
const _bannerPalette = [
  Color(0xFFEAD9E0),
  Color(0xFFDCE6EC),
  Color(0xFFF2E2CE),
  Color(0xFFE0E8DD),
  Color(0xFFE6E0EE),
  Color(0xFFF5DED6),
  Color(0xFFEFE7DC),
];

int _paletteIndex(String id) {
  var h = 0;
  for (final c in id.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  return h % _avatarPalette.length;
}

Color authorBannerColor(String id) => _bannerPalette[_paletteIndex(id)];

/// 一個本機檔案是否已經可以顯示（同步還沒下載完的頭像先顯示字）。
bool _fileReady(WidgetRef ref, String? file) {
  if (file == null || file.isEmpty) return false;
  final store = ref.watch(imageStoreProvider).value;
  ref.watch(imageExistsProvider(file));
  ref.watch(thumbVersionProvider(file));
  return store != null && (store.exists(file) || store.hasThumb(file));
}

/// 作者頭像：有圖用圖，否則名字第一個字（襯線、設計稿的七組顏色）。
/// [id] 為 null＝還沒建立的作者（新增頁）：沒圖時顯示人形佔位。
class AuthorAvatar extends ConsumerWidget {
  const AuthorAvatar({
    super.key,
    required this.id,
    required this.name,
    this.file,
    required this.size,
    this.ring,
  });

  final String? id;
  final String name;
  final String? file;
  final double size;

  /// 外圈（詳情頁 4px 底色圈）。
  final double? ring;

  factory AuthorAvatar.of(Author a, {required double size, double? ring}) =>
      AuthorAvatar(
        id: a.id,
        name: a.name,
        file: a.avatarFile,
        size: size,
        ring: ring,
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final ready = _fileReady(ref, file);
    final trimmed = name.trim();
    Widget inner;
    if (ready) {
      inner = StoredImage(
        file!,
        cacheWidth: (size * 3).round(),
        showDownloadBadge: false,
      );
    } else if (id == null || trimmed.isEmpty) {
      inner = ColoredBox(
        color: t.chipBg,
        child: Center(
          child: SvgIcon(
            AuthorIcons.author,
            size: 21 * size / 88 < 14 ? 14 : 21,
            strokeWidth: 1.7,
            color: const Color(0xFFB7ADA0),
          ),
        ),
      );
    } else {
      final (bg, fg) = _avatarPalette[_paletteIndex(id!)];
      inner = ColoredBox(
        color: bg,
        child: Center(
          child: Text(
            trimmed.characters.first.toUpperCase(),
            style: TextStyle(
              fontFamily: Theme.of(context).textTheme.headlineSmall?.fontFamily,
              fontFamilyFallback: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.fontFamilyFallback,
              fontWeight: FontWeight.w700,
              fontSize: size * 0.41,
              height: 1,
              color: fg,
            ),
          ),
        ),
      );
    }
    final circle = SizedBox(
      width: size,
      height: size,
      child: ClipOval(child: inner),
    );
    final r = ring;
    if (r == null) return circle;
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(r),
      decoration: BoxDecoration(color: t.ground, shape: BoxShape.circle),
      child: ClipOval(child: inner),
    );
  }
}

/// 作者封面：有圖用圖，否則依作者 id 的淡色＋圖片 icon。
class AuthorBanner extends ConsumerWidget {
  const AuthorBanner({
    super.key,
    required this.id,
    this.file,
    this.iconSize = 30,
  });
  final String id;
  final String? file;
  final double iconSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (_fileReady(ref, file)) {
      return StoredImage(file!, cacheWidth: 1200, showDownloadBadge: false);
    }
    return ColoredBox(
      color: authorBannerColor(id),
      child: Center(
        child: SvgIcon(
          AuthorIcons.image,
          size: iconSize,
          strokeWidth: 1.5,
          color: const Color(0x2E2B2622),
        ),
      ),
    );
  }
}

/// 主坑小標（資料夾 icon＋坑名）。
class AuthorPitTag extends StatelessWidget {
  const AuthorPitTag(
    this.name, {
    super.key,
    this.fontSize = 11,
    this.lineHeight = 1.3,
  });
  final String name;
  final double fontSize;
  final double lineHeight;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fg = dark ? t.text2 : const Color(0xFF7A6A5A);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: t.chipBg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgIcon(AuthorIcons.pit, size: 12, strokeWidth: 1.9, color: fg),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w600,
                color: fg,
                height: lineHeight,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 平台小方塊：X／紅。
class PlatformBadge extends StatelessWidget {
  const PlatformBadge(this.platform, {super.key, this.size = 26});
  final LinkPlatform platform;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final x = platform == LinkPlatform.x;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: x ? t.official.bg : t.fanArt.bg,
        borderRadius: BorderRadius.circular(7),
      ),
      alignment: Alignment.center,
      child: Text(
        x ? 'X' : '紅',
        style: TextStyle(
          fontSize: size >= 26 ? 12 : 11,
          fontWeight: FontWeight.w700,
          color: x ? t.ink : const Color(0xFFB23A4C),
          height: 1,
        ),
      ),
    );
  }
}

/// 多選圓圈（未選：2px 框；已選：主色底＋白勾）。
class AuthorSelectMark extends StatelessWidget {
  const AuthorSelectMark({
    super.key,
    required this.selected,
    this.filled = false,
  });
  final bool selected;

  /// 未選時白底（格子卡右上角）。
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? t.accent : (filled ? t.surface : null),
        border: selected ? null : Border.all(color: t.dashed, width: 2),
      ),
      alignment: Alignment.center,
      child: selected
          ? const SvgIcon(
              AppIcons.check,
              size: 13,
              strokeWidth: 3,
              color: Colors.white,
            )
          : null,
    );
  }
}

/// 列表 layout 的一列（AuthorListRows／AuthorSelectRows／AuthorSortRows）。
class AuthorRowTile extends StatelessWidget {
  const AuthorRowTile({
    super.key,
    required this.summary,
    this.selecting = false,
    this.selected = false,
    this.sorting = false,
    this.onTap,
    this.onLongPress,
  });
  final AuthorSummary summary;
  final bool selecting;
  final bool selected;
  final bool sorting;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final a = summary.author;
    final pit = summary.mainPitName;
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        constraints: const BoxConstraints(minHeight: 84),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: t.border.withValues(alpha: 0.75)),
          ),
        ),
        child: Row(
          children: [
            if (selecting) ...[
              AuthorSelectMark(selected: selected),
              const SizedBox(width: 12),
            ],
            AuthorAvatar.of(a, size: 48),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    a.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: t.ink,
                    ),
                  ),
                  if (a.handle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      a.handle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: t.text3),
                    ),
                  ],
                  const SizedBox(height: 4),
                  pit != null
                      ? AuthorPitTag(pit)
                      : Text(
                          context.l10n.authorNoFanArts,
                          style: TextStyle(fontSize: 11, color: t.text4),
                        ),
                ],
              ),
            ),
            if (sorting) ...[
              const SizedBox(width: 12),
              SvgIcon(
                AuthorIcons.handle,
                size: 20,
                strokeWidth: 2,
                color: const Color(0xFF9A8F80),
              ),
            ] else if (summary.latest.isNotEmpty) ...[
              const SizedBox(width: 12),
              for (final (i, f) in summary.latest.indexed) ...[
                if (i > 0) const SizedBox(width: 4),
                _Thumb(f),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb(this.f);
  final FanArt f;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(8),
    child: SizedBox(
      width: 44,
      height: 44,
      child: MediaThumb(
        fanArtAlbumImage(f).media,
        cacheWidth: 132,
        showBadge: false,
        sensitiveBadge: false,
      ),
    ),
  );
}

/// 同人圖列 → 圖冊共用的 [AlbumImage]（不帶作者、出處：作者頁的格子不顯示文字）。
AlbumImage fanArtAlbumImage(FanArt r) => AlbumImage(
  id: r.id,
  file: r.imageFile,
  width: r.width,
  height: r.height,
  kind: AlbumKind.fanArt,
  createdAt: r.createdAt,
  mediaKind: r.kind,
  durationMs: r.durationMs,
  posterFile: r.posterFile,
  imageKey: r.imageKey,
);

/// 格子 layout 的一格（AuthorListGrid／AuthorSelectGrid／AuthorSortGrid）。
class AuthorGridTile extends StatelessWidget {
  const AuthorGridTile({
    super.key,
    required this.summary,
    this.selecting = false,
    this.selected = false,
    this.onTap,
    this.onLongPress,
    this.lifted = false,
  });
  final AuthorSummary summary;
  final bool selecting;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool lifted;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final a = summary.author;
    final pit = summary.mainPitName;
    return Material(
      color: t.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: t.borderCard),
      ),
      clipBehavior: Clip.antiAlias,
      elevation: lifted ? 6 : 0,
      shadowColor: Colors.black26,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: selected ? Border.all(color: t.accent, width: 2) : null,
          ),
          child: Stack(
            children: [
              // Stack 不會撐滿格子寬度：不加這層，名字長短不同時整欄會靠左。
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(6, 14, 6, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AuthorAvatar.of(a, size: 60),
                    const SizedBox(height: 9),
                    Text(
                      a.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: t.ink,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      a.handle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: t.text3,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    pit != null
                        ? AuthorPitTag(pit, fontSize: 10.5, lineHeight: 1.2)
                        : Text(
                            context.l10n.authorNoFanArts,
                            style: TextStyle(fontSize: 10.5, color: t.text4),
                          ),
                  ],
                ),
              ),
              if (selecting)
                Positioned(
                  right: 7,
                  top: 7,
                  child: AuthorSelectMark(selected: selected, filled: true),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
