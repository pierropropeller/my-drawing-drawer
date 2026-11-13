import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/author_link.dart';
import '../../data/author_queries.dart';
import '../../data/database.dart';
import '../../data/tables.dart' show uuid;
import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../../theme/tokens.dart';
import '../album/album_actions.dart';
import '../common/svg_icon.dart';
import 'author_icons.dart';
import 'author_widgets.dart';

/// 作者 ID 欄位要顯示的文字：X＝`@帳號`；小紅書＝`小紅書 <小紅書號>`。
String linkedHandleText(BuildContext context, LinkedProfile p) =>
    p.platform == LinkPlatform.x
    ? '@${p.handle}'
    : context.l10n.authorXhsShort(p.handle);

/// 下載平台上的頭像／封面存成本機圖片檔；失敗回傳 null（不擋住其他欄位）。
Future<String?> downloadLinkedImage(WidgetRef ref, String? url) async {
  if (url == null || url.isEmpty) return null;
  try {
    final bytes = await ref.read(authorLinkServiceProvider).download(url);
    final store = await ref.read(imageStoreProvider.future);
    final lower = url.toLowerCase();
    final ext = lower.contains('.png')
        ? 'png'
        : lower.contains('.webp')
        ? 'webp'
        : 'jpg';
    final name = '${uuid.v4()}.$ext';
    await store.save(name, Uint8List.fromList(bytes));
    return name;
  } catch (_) {
    return null;
  }
}

/// 連結欄位的寫入值（X 或小紅書那一組）。
AuthorsCompanion linkFields(LinkedProfile p) => p.platform == LinkPlatform.x
    ? AuthorsCompanion(
        xUserId: Value(p.userId),
        xHandle: Value(p.handle),
        xName: Value(p.name),
      )
    : AuthorsCompanion(
        xhsUserId: Value(p.userId),
        xhsHandle: Value(p.handle),
        xhsName: Value(p.name),
      );

/// 「使用推特上的資料？」（AuthorLinkConfirm）。
Future<bool> confirmUseLinked(BuildContext context, LinkedProfile p) async {
  final l = context.l10n;
  final t = context.tokens;
  final x = p.platform == LinkPlatform.x;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => _AuthorDialog(
      title: x ? l.authorUseXTitle : l.authorUseXhsTitle,
      body: [
        Container(
          margin: const EdgeInsets.only(top: 14),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: t.ground,
            border: Border.all(color: t.borderCard),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              _RemoteAvatar(url: p.avatarUrl, name: p.name, size: 52),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: t.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      linkedHandleText(context, p),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12.5, color: t.text3),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(
            x ? l.authorUseXBody : l.authorUseXhsBody,
            style: TextStyle(fontSize: 14, color: t.text2, height: 1.65),
          ),
        ),
      ],
      cancel: l.authorUseNo,
      confirm: l.authorUseYes,
    ),
  );
  return ok ?? false;
}

/// 平台上的頭像（還沒下載成本機檔，直接讀網址；讀不到就顯示名字第一個字）。
class _RemoteAvatar extends StatelessWidget {
  const _RemoteAvatar({
    required this.url,
    required this.name,
    required this.size,
  });
  final String? url;
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fallback = AuthorAvatar(id: name, name: name, size: size);
    final u = url;
    if (u == null) return fallback;
    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: Image.network(
          u,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => fallback,
        ),
      ),
    );
  }
}

class _AuthorDialog extends StatelessWidget {
  const _AuthorDialog({
    required this.title,
    required this.body,
    required this.cancel,
    required this.confirm,
    this.danger = false,
  });
  final String title;
  final List<Widget> body;
  final String cancel;
  final String confirm;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return AlertDialog(
      backgroundColor: t.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      titlePadding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
      contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      actionsPadding: const EdgeInsets.fromLTRB(14, 18, 14, 16),
      title: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge
            ?.copyWith(fontSize: 18, fontWeight: FontWeight.w700),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: body,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          style: TextButton.styleFrom(foregroundColor: t.text2),
          child: Text(
            cancel,
            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: TextButton.styleFrom(
            foregroundColor: danger ? t.danger : t.accentStrong,
          ),
          child: Text(
            confirm,
            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

/// 「更新」：從同步來源重新查詢。有變更＝確認（AuthorRefreshConfirm）後覆寫頭像／名字／ID（X 連封面）；
/// 沒變更＝提示已是最新；失敗＝一般失敗提示條＋重試（AuthorRefreshFail）。
Future<void> refreshAuthor(
  BuildContext context,
  WidgetRef ref,
  Author a,
) async {
  final source = LinkPlatform.parse(a.syncSource);
  if (source == null) return;
  final userId = source == LinkPlatform.x ? a.xUserId : a.xhsUserId;
  if (userId == null) return;
  final db = ref.read(databaseProvider);
  final l = context.l10n;
  void fail() {
    if (!context.mounted) return;
    showSnack(
      context,
      l.authorRefreshFail,
      actionLabel: l.commonRetry,
      onAction: () {
        if (context.mounted) refreshAuthor(context, ref, a);
      },
    );
  }

  final LinkedProfile p;
  try {
    p = await ref
        .read(authorLinkServiceProvider)
        .refresh(
          source,
          userId: userId,
          handle: source == LinkPlatform.x ? a.xHandle : a.xhsHandle,
        );
  } catch (_) {
    fail();
    return;
  }
  if (!context.mounted) return;
  final newHandle = linkedHandleText(context, p);
  // 頭像有沒有變：下載新的跟本機的比對內容。
  List<int>? newAvatar;
  try {
    final url = p.avatarUrl;
    if (url != null) {
      newAvatar = await ref.read(authorLinkServiceProvider).download(url);
    }
  } catch (_) {}
  final store = await ref.read(imageStoreProvider.future);
  var avatarChanged = false;
  if (newAvatar != null) {
    final cur = a.avatarFile;
    final f = cur == null ? null : store.fileOf(cur);
    avatarChanged =
        f == null ||
        !f.existsSync() ||
        !_sameBytes(await f.readAsBytes(), newAvatar);
  }
  final changed = p.name != a.name || newHandle != a.handle || avatarChanged;
  if (!changed) {
    await db.updateAuthor(
      a.id,
      linkFields(p).copyWith(refreshedAt: Value(DateTime.now())),
    );
    if (context.mounted) showSnack(context, l.authorUpToDate, success: true);
    return;
  }
  if (!context.mounted) return;
  final ok = await _confirmRefresh(context, a, p, newHandle);
  if (!ok) return;
  String? avatar;
  if (avatarChanged) {
    final lower = (p.avatarUrl ?? '').toLowerCase();
    avatar = '${uuid.v4()}.${lower.contains('.png') ? 'png' : 'jpg'}';
    await store.save(avatar, Uint8List.fromList(newAvatar!));
  }
  final banner = source == LinkPlatform.x
      ? await downloadLinkedImage(ref, p.bannerUrl)
      : null;
  await db.updateAuthor(
    a.id,
    linkFields(p).copyWith(
      name: Value(p.name),
      handle: Value(newHandle),
      avatarFile: avatar == null ? const Value.absent() : Value(avatar),
      bannerFile: banner == null ? const Value.absent() : Value(banner),
      refreshedAt: Value(DateTime.now()),
    ),
  );
}

bool _sameBytes(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

Future<bool> _confirmRefresh(
  BuildContext context,
  Author a,
  LinkedProfile p,
  String newHandle,
) async {
  final l = context.l10n;
  final t = context.tokens;
  Widget diff(String label, String old, String now) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: 40,
        child: Text(label, style: TextStyle(fontSize: 13.5, color: t.text3)),
      ),
      Expanded(
        child: old == now
            ? Text.rich(
                TextSpan(
                  text: now,
                  children: [
                    TextSpan(
                      text: l.authorUnchanged,
                      style: TextStyle(color: t.text4),
                    ),
                  ],
                ),
                style: TextStyle(fontSize: 13.5, color: t.ink),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    old,
                    style: TextStyle(
                      fontSize: 13.5,
                      color: t.text4,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                  Text(now, style: TextStyle(fontSize: 13.5, color: t.ink)),
                ],
              ),
      ),
    ],
  );
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => _AuthorDialog(
      title: p.platform == LinkPlatform.x
          ? l.authorXChangedTitle
          : l.authorXhsChangedTitle,
      body: [
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AuthorAvatar.of(a, size: 56),
            const SizedBox(width: 14),
            SvgIcon(
              AuthorIcons.arrowRight,
              size: 22,
              strokeWidth: 2,
              color: const Color(0xFFB7ADA0),
            ),
            const SizedBox(width: 14),
            _RemoteAvatar(url: p.avatarUrl, name: p.name, size: 56),
          ],
        ),
        const SizedBox(height: 14),
        diff(l.authorFieldName, a.name, p.name),
        const SizedBox(height: 6),
        diff(l.authorFieldHandle, a.handle, newHandle),
      ],
      cancel: l.commonCancel,
      confirm: l.authorRefresh,
    ),
  );
  return ok ?? false;
}

/// 刪除作者的確認（AuthorDeleteConfirm）。
Future<bool> confirmDeleteAuthor(
  BuildContext context,
  String name,
  int count,
) async {
  final l = context.l10n;
  final t = context.tokens;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => _AuthorDialog(
      title: l.authorDeleteTitle(name),
      body: [
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Text(
            count > 0 ? l.authorDeleteBody(count) : l.authorDeleteBodyNone,
            style: TextStyle(fontSize: 14, color: t.text2, height: 1.65),
          ),
        ),
      ],
      cancel: l.commonCancel,
      confirm: l.commonDelete,
      danger: true,
    ),
  );
  return ok ?? false;
}

/// 多選刪除的確認（同 AuthorDeleteConfirm 的樣式）。
Future<bool> confirmDeleteAuthors(
  BuildContext context,
  int authors,
  int fanArts,
) async {
  final l = context.l10n;
  final t = context.tokens;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => _AuthorDialog(
      title: l.authorDeleteManyTitle(authors),
      body: [
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Text(
            fanArts > 0 ? l.authorDeleteBody(fanArts) : l.authorDeleteBodyNone,
            style: TextStyle(fontSize: 14, color: t.text2, height: 1.65),
          ),
        ),
      ],
      cancel: l.commonCancel,
      confirm: l.commonDelete,
      danger: true,
    ),
  );
  return ok ?? false;
}
