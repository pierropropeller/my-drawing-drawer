import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/author_link.dart';
import '../../data/database.dart';
import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../../theme/tokens.dart';
import '../album/fan_art_preview_page.dart';
import '../album/image_masonry.dart';
import '../common/app_icons.dart';
import '../common/nav_bar_hidden.dart';
import '../common/svg_icon.dart';
import '../common/swipe_pager.dart';
import 'author_form_page.dart';
import 'author_icons.dart';
import 'author_sync.dart';
import 'author_widgets.dart';

/// 作者詳情（AuthorDetail／AuthorDetailOnePit，D-156）：封面、頭像、名字、ID·張數、連結帳號，
/// 下面是依坑分頁的同人圖瀑布；只有一個坑時不顯示坑分頁。沒有導覽列。
class AuthorDetailPage extends ConsumerStatefulWidget {
  const AuthorDetailPage({super.key, required this.authorId});
  final String authorId;

  @override
  ConsumerState<AuthorDetailPage> createState() => _AuthorDetailPageState();
}

class _AuthorDetailPageState extends ConsumerState<AuthorDetailPage>
    with HidesNavBar<AuthorDetailPage> {
  String? _pit;
  bool _refreshing = false;
  final _progress = ValueNotifier<double>(0);

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  Future<void> _refresh(Author a) async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      await refreshAuthor(context, ref, a);
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = context.l10n;
    final async = ref.watch(authorDetailProvider(widget.authorId));
    final d = async.value;
    if (d == null) {
      // 作者被刪掉（這台或別台）就退回列表。
      if (async.hasValue) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.of(context).maybePop();
        });
      }
      return Scaffold(backgroundColor: t.ground);
    }
    final a = d.author;
    final groups = d.groups;
    final pitIds = [for (final g in groups) g.$1.id];
    if (_pit == null || !pitIds.contains(_pit)) {
      _pit = pitIds.isEmpty ? null : pitIds.first;
      _progress.value = 0;
    }
    final top = MediaQuery.paddingOf(context).top;
    final sub = a.handle.isEmpty
        ? l.commonCountEntries(d.count)
        : l.authorDetailSub(a.handle, d.count);

    Widget circleButton(String tooltip, Widget icon, VoidCallback onTap) =>
        Tooltip(
          message: tooltip,
          child: Material(
            color: t.ground.withValues(alpha: 0.86),
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: SizedBox(
                width: 40,
                height: 40,
                child: Center(child: icon),
              ),
            ),
          ),
        );

    final links = <Widget>[
      if (a.xUserId != null)
        _LinkChip(
          platform: LinkPlatform.x,
          label: '@${a.xHandle ?? ''}',
          refreshTooltip: a.syncSource == 'x' ? l.authorRefreshFromX : null,
          refreshing: _refreshing,
          onRefresh: () => _refresh(a),
        ),
      if (a.xhsUserId != null)
        _LinkChip(
          platform: LinkPlatform.xhs,
          label: a.xhsName ?? a.xhsHandle ?? '',
          refreshTooltip: a.syncSource == 'xhs' ? l.authorRefreshFromXhs : null,
          refreshing: _refreshing,
          onRefresh: () => _refresh(a),
        ),
    ];

    Widget page(String? pitId) {
      final g = groups.where((g) => g.$1.id == pitId).firstOrNull;
      if (g == null) return const SizedBox.shrink();
      final images = [for (final f in g.$2) fanArtAlbumImage(f)];
      return ImageMasonry(
        key: PageStorageKey('authorDetail-$pitId'),
        images: images,
        padding: const EdgeInsets.fromLTRB(20, 2, 20, 40),
        onTap: (im, i) => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => FanArtPreviewPage(
              pitId: g.$1.id,
              images: images,
              initialIndex: i,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: t.ground,
      body: Column(
        children: [
          SizedBox(
            height: top + 150,
            child: Stack(
              fit: StackFit.expand,
              children: [
                AuthorBanner(id: a.id, file: a.bannerFile),
                Positioned(
                  left: 14,
                  right: 14,
                  top: top + 22,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      circleButton(
                        l.commonBack,
                        SvgIcon(AppIcons.back, color: t.ink, strokeWidth: 1.9),
                        () => Navigator.of(context).maybePop(),
                      ),
                      circleButton(
                        l.authorEditTitle,
                        SvgIcon(
                          AuthorIcons.edit,
                          size: 21,
                          color: t.ink,
                          strokeWidth: 1.8,
                        ),
                        () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => AuthorFormPage(authorId: a.id),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Transform.translate(
            offset: const Offset(0, -40),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  AuthorAvatar.of(a, size: 80, ring: 4),
                  const SizedBox(height: 6),
                  Text(
                    a.name,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 1),
                  Text(sub, style: TextStyle(fontSize: 12.5, color: t.text3)),
                  if (links.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: links,
                    ),
                  ],
                ],
              ),
            ),
          ),
          Expanded(
            child: Transform.translate(
              // 頭像往上疊 40，下方內容一起往上補回來。
              offset: const Offset(0, -26),
              child: Column(
                children: [
                  if (groups.length > 1)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.fromLTRB(20, 2, 12, 12),
                      child: Row(
                        children: [
                          for (final (i, g) in groups.indexed)
                            _CountPill(
                              label: g.$1.name,
                              count: g.$2.length,
                              on: g.$1.id == _pit,
                              onTap: () {
                                _progress.value = i.toDouble();
                                setState(() => _pit = g.$1.id);
                              },
                            ),
                        ],
                      ),
                    ),
                  Expanded(
                    child: SwipePager<String?>(
                      enabled: groups.length > 1,
                      order: pitIds,
                      current: _pit,
                      progress: _progress,
                      onChanged: (p) => setState(() => _pit = p),
                      itemBuilder: (context, p) => page(p),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 詳情頁的連結帳號小膠囊；同步來源那一個右邊有更新鍵。
class _LinkChip extends StatelessWidget {
  const _LinkChip({
    required this.platform,
    required this.label,
    required this.refreshTooltip,
    required this.refreshing,
    required this.onRefresh,
  });
  final LinkPlatform platform;
  final String label;
  final String? refreshTooltip;
  final bool refreshing;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tip = refreshTooltip;
    return Container(
      padding: EdgeInsets.fromLTRB(5, 4, tip == null ? 12 : 6, 4),
      decoration: BoxDecoration(
        color: t.surface,
        border: Border.all(color: t.border),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PlatformBadge(platform, size: 22),
          const SizedBox(width: 7),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 160),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12.5, color: t.text2),
            ),
          ),
          if (tip != null) ...[
            const SizedBox(width: 4),
            SizedBox(
              width: 26,
              height: 22,
              child: refreshing
                  ? Center(
                      child: SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: t.accent,
                        ),
                      ),
                    )
                  : IconButton(
                      key: const ValueKey('authorDetailRefresh'),
                      tooltip: tip,
                      padding: EdgeInsets.zero,
                      iconSize: 18,
                      onPressed: onRefresh,
                      icon: SvgIcon(
                        AuthorIcons.refresh,
                        size: 18,
                        strokeWidth: 1.9,
                        color: t.text2,
                      ),
                    ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 詳情頁的坑分頁（坑名＋張數）。
class _CountPill extends StatelessWidget {
  const _CountPill({
    required this.label,
    required this.count,
    required this.on,
    required this.onTap,
  });
  final String label;
  final int count;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final fg = on ? t.ground : t.text2;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Semantics(
        button: true,
        selected: on,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: on ? t.ink : t.surface,
              border: Border.all(color: on ? t.ink : t.border),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text.rich(
              TextSpan(
                text: label,
                children: [
                  TextSpan(
                    text: '  $count',
                    style: TextStyle(color: fg.withValues(alpha: 0.7)),
                  ),
                ],
              ),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: fg,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
