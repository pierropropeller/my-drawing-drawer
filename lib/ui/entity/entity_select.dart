import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/batch_tag_queries.dart';
import '../../data/database.dart';
import '../../data/entity_queries.dart';
import '../../l10n/l10n.dart';
import '../../theme/tokens.dart';
import '../album/album_actions.dart';
import '../album/album_icons.dart';
import '../album/album_image.dart';
import '../album/tag_batch_sheet.dart';
import '../common/app_icons.dart';
import '../common/svg_icon.dart';
import '../common/themed_sheet.dart';

/// 摸魚、成圖列表的多選共用件（D-095，DraftSelect／MaterialSelect 的標題列與底部動作列）。

/// 多選的標題列：左「×」取消、「已選 N 份／張」、右「全選」。
class EntitySelectHeader extends StatelessWidget {
  const EntitySelectHeader({
    super.key,
    required this.title,
    required this.allSelected,
    required this.onExit,
    required this.onToggleAll,
  });
  final String title;
  final bool allSelected;
  final VoidCallback onExit;
  final VoidCallback onToggleAll;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      child: Row(
        children: [
          Tooltip(
            message: l.albumCancelSelect,
            child: InkResponse(
              key: const ValueKey('entitySelectExit'),
              radius: 24,
              onTap: onExit,
              child: SizedBox(
                width: 40,
                height: 40,
                child: Center(
                  child: SvgIcon(
                    AppIcons.closeX,
                    size: 22,
                    strokeWidth: 2,
                    color: t.ink,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: t.ink,
              ),
            ),
          ),
          TextButton(
            key: const ValueKey('entitySelectAll'),
            onPressed: onToggleAll,
            style: TextButton.styleFrom(
              foregroundColor: t.piece.fg,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              // 不讓 48px 的點擊範圍把標題列撐高（稿：按鈕 padding 8／10，列高 40）。
              minimumSize: const Size(0, 40),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            child: Text(allSelected ? l.commonDeselectAll : l.commonSelectAll),
          ),
        ],
      ),
    );
  }
}

/// 底部四個動作：分享、下載、tag、刪除（沒有「移動」，也沒有導覽列）。
class EntitySelectBar extends StatelessWidget {
  const EntitySelectBar({
    super.key,
    required this.onShare,
    required this.onDownload,
    required this.onTag,
    required this.onDelete,
    this.onSensitive,
  });
  final VoidCallback onShare;
  final VoidCallback onDownload;
  final VoidCallback onTag;
  final VoidCallback onDelete;

  /// 「敏感」動作（D-104）；null＝不顯示（總開關或這個坑的敏感內容沒開）。
  final VoidCallback? onSensitive;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = context.l10n;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      decoration: BoxDecoration(
        color: t.nav,
        border: Border(top: BorderSide(color: t.border)),
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 14),
        child: Row(
          children: [
            Expanded(
              child: _BarAction(
                key: const ValueKey('entitySelectShare'),
                label: l.commonShare,
                svg: AppIcons.share,
                color: t.ink,
                onTap: onShare,
              ),
            ),
            Expanded(
              child: _BarAction(
                key: const ValueKey('entitySelectDownload'),
                label: l.commonDownload,
                svg: AppIcons.download,
                color: t.ink,
                onTap: onDownload,
              ),
            ),
            if (onSensitive != null)
              Expanded(
                child: _BarAction(
                  key: const ValueKey('entitySelectSensitive'),
                  label: l.sensitiveAction,
                  svg: AppIcons.eyeSlash,
                  color: t.ink,
                  strokeWidth: 1.9,
                  onTap: onSensitive!,
                ),
              ),
            Expanded(
              child: _BarAction(
                key: const ValueKey('entitySelectTag'),
                label: l.shareMoveTag,
                svg: AlbumIcons.tag,
                color: t.ink,
                onTap: onTag,
              ),
            ),
            Expanded(
              child: _BarAction(
                key: const ValueKey('entitySelectDelete'),
                label: l.commonDelete,
                svg: AppIcons.trash,
                color: t.danger,
                iconSize: 20,
                strokeWidth: 1.8,
                onTap: onDelete,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BarAction extends StatelessWidget {
  const _BarAction({
    super.key,
    required this.label,
    required this.svg,
    required this.color,
    required this.onTap,
    this.iconSize = 22,
    this.strokeWidth = 1.7,
  });
  final String label;
  final String svg;
  final Color color;
  final VoidCallback onTap;
  final double iconSize;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 52),
      child: Column(
        // 放在 bottomNavigationBar 時高度不受限，要縮到內容大小。
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SvgIcon(svg, size: iconSize, color: color, strokeWidth: strokeWidth),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: color, fontSize: 11.5)),
        ],
      ),
    ),
  );
}

/// 一份摸魚／一張成圖的圖片，轉成分享、下載共用函式吃的 [AlbumImage]（照圖片順序）。
List<AlbumImage> albumImagesOf(Iterable<ImageRef> images) => [
  for (final r in images)
    AlbumImage(
      id: r.file,
      file: r.file,
      width: r.width,
      height: r.height,
      kind: AlbumKind.junk,
      mediaKind: r.kind,
      durationMs: r.durationMs,
      posterFile: r.poster,
    ),
];

/// 多份摸魚／多張成圖的所有圖片：照列表順序，每份內照圖片順序。
List<AlbumImage> albumImagesOfAll(Iterable<List<ImageRef>> groups) => [
  for (final g in groups) ...albumImagesOf(g),
];

/// 一起分享。沒有任何圖（例如成圖沒配圖）就什麼都不做。
Future<void> shareEntityImages(
  WidgetRef ref,
  Iterable<List<ImageRef>> groups,
) async {
  final all = albumImagesOfAll(groups);
  if (all.isEmpty) return;
  await shareImages(ref, all);
}

/// 一起下載到相簿（Pictures/Drawer）。回傳 (成功張數, 總張數)。
Future<({int saved, int total})> downloadEntityImages(
  WidgetRef ref,
  Iterable<List<ImageRef>> groups,
) async {
  final all = albumImagesOfAll(groups);
  if (all.isEmpty) return (saved: 0, total: 0);
  return (saved: await downloadImages(ref, all), total: all.length);
}

/// 摸魚、成圖的批量 tag 接法（`TagTarget.draft`／`piece`，D-095）。
BatchTagBackend entityTagBackend(
  TagTarget target,
  String Function(AppLocalizations l, int count) countText,
) => BatchTagBackend(
  watch: (db, ids) => db.watchTagCoverageFor(target, ids),
  apply: (db, ids, {required add, required remove, required newNames}) =>
      db.applyBatchTagsFor(
        target,
        ids,
        addTagIds: add,
        removeTagIds: remove,
        newTagNames: newNames,
      ),
  countText: countText,
);

/// 多選後的 tag bottom sheet（同官方圖冊、同人圖、推活的 [BatchTagSheet]）。回傳 true＝有套用。
Future<bool?> showEntityTagSheet(
  BuildContext context, {
  required String pitId,
  required BatchTagBackend backend,
  required List<String> ids,
}) => showThemedSheet<bool>(
  context: context,
  builder: (_) => BatchTagSheet(pitId: pitId, backend: backend, ids: ids),
);
