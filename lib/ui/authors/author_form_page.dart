import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/author_link.dart';
import '../../data/author_queries.dart';
import '../../data/database.dart';
import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../../theme/tokens.dart';
import '../common/app_icons.dart';
import '../common/nav_bar_hidden.dart';
import '../common/svg_icon.dart';
import '../me/me_widgets.dart' show MeSubHeader;
import '../pits/pit_form.dart';
import 'author_detail_page.dart';
import 'author_form.dart';
import 'author_icons.dart';
import 'author_sync.dart';
import 'author_widgets.dart';

/// 新增作者（AuthorNew）／編輯作者（AuthorEdit，[authorId] 有值）。沒有導覽列。
/// 新增完進作者詳情（取代這一頁）；編輯儲存後回上一頁。
class AuthorFormPage extends ConsumerStatefulWidget {
  const AuthorFormPage({super.key, this.authorId});
  final String? authorId;

  @override
  ConsumerState<AuthorFormPage> createState() => _AuthorFormPageState();
}

class _AuthorFormPageState extends ConsumerState<AuthorFormPage>
    with HidesNavBar<AuthorFormPage> {
  AuthorDraft? _draft;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    if (widget.authorId == null) {
      _draft = AuthorDraft()..addListener(_rebuild);
    } else {
      ref.read(databaseProvider).loadAuthor(widget.authorId!).then((a) {
        if (!mounted) return;
        setState(() => _draft = AuthorDraft(a)..addListener(_rebuild));
      });
    }
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _draft?.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final d = _draft!;
    if (!d.canSave) return;
    final db = ref.read(databaseProvider);
    final nav = Navigator.of(context);
    if (d.id == null) {
      final id = await db.addAuthor(d.toCompanion());
      if (!mounted) return;
      nav.pushReplacement(
        MaterialPageRoute<void>(builder: (_) => AuthorDetailPage(authorId: id)),
      );
    } else {
      await db.updateAuthor(d.id!, d.toCompanion());
      if (mounted) nav.maybePop();
    }
  }

  Future<void> _delete() async {
    final d = _draft!;
    final count =
        (await ref.read(databaseProvider).loadAuthorDetail(d.id!))?.count ?? 0;
    if (!mounted) return;
    final ok = await confirmDeleteAuthor(context, d.name.text.trim(), count);
    if (!ok || !mounted) return;
    await ref.read(databaseProvider).deleteAuthors([d.id!]);
    if (mounted) Navigator.of(context).maybePop();
  }

  /// 編輯頁的「更新」：先存目前的連結，再從同步來源更新，更新後的資料填回表單。
  Future<void> _refresh() async {
    final d = _draft!;
    if (_refreshing || d.id == null) return;
    setState(() => _refreshing = true);
    final db = ref.read(databaseProvider);
    try {
      final cur = await db.loadAuthor(d.id!);
      if (cur == null || !mounted) return;
      final c = d.toCompanion();
      await db.updateAuthor(
        d.id!,
        AuthorsCompanion(
          xUserId: c.xUserId,
          xHandle: c.xHandle,
          xName: c.xName,
          xhsUserId: c.xhsUserId,
          xhsHandle: c.xhsHandle,
          xhsName: c.xhsName,
          syncSource: c.syncSource,
        ),
      );
      final a = await db.loadAuthor(d.id!);
      if (a == null || !mounted) return;
      await refreshAuthor(context, ref, a);
      final after = await db.loadAuthor(d.id!);
      if (after == null || !mounted) return;
      d.set(() {
        d.name.text = after.name;
        d.handle.text = after.handle;
        d.avatarFile = after.avatarFile;
        d.bannerFile = after.bannerFile;
      });
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = context.l10n;
    final d = _draft;
    final editing = widget.authorId != null;
    if (d == null) return Scaffold(backgroundColor: t.ground);
    final refreshedAt = editing
        ? ref.watch(authorProvider(d.id!)).value?.refreshedAt
        : null;
    return Scaffold(
      backgroundColor: t.ground,
      body: SafeArea(
        child: Column(
          children: [
            MeSubHeader(editing ? l.authorEditTitle : l.authorAdd, bottom: 4),
            Expanded(
              child: LayoutBuilder(
                builder: (context, box) => SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: box.maxHeight - 32),
                    child: IntrinsicHeight(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(0, 6, 0, 18),
                            child: Center(
                              child: AuthorAvatarPicker(
                                draft: d,
                                size: 88,
                                badge: 28,
                              ),
                            ),
                          ),
                          PitFieldLabel(l.authorFieldName),
                          TextField(
                            key: const ValueKey('authorName'),
                            controller: d.name,
                            autofocus: !editing,
                            textInputAction: TextInputAction.next,
                            decoration: pitInputDecoration(context),
                          ),
                          const SizedBox(height: 16),
                          PitFieldLabel(l.authorFieldHandle),
                          TextField(
                            key: const ValueKey('authorHandle'),
                            controller: d.handle,
                            autocorrect: false,
                            decoration: pitInputDecoration(context),
                          ),
                          SizedBox(height: editing ? 16 : 20),
                          if (editing) ...[
                            PitFieldLabel(l.authorFieldBanner),
                            _BannerField(draft: d),
                            const SizedBox(height: 18),
                          ],
                          PitFieldLabel(l.authorLinkedAccounts),
                          if (editing && d.linked.isNotEmpty)
                            _LinkedPanel(
                              draft: d,
                              refreshedAt: refreshedAt,
                              refreshing: _refreshing,
                              onRefresh: _refresh,
                            ),
                          for (final p in LinkPlatform.values)
                            if (!editing || !d.linked.containsKey(p))
                              AuthorLinkInput(draft: d, platform: p),
                          SizedBox(height: editing ? 12 : 16),
                          PitPrimaryButton(
                            key: const ValueKey('authorSave'),
                            label: editing ? l.commonSave : l.authorCreate,
                            onPressed: d.canSave ? _save : null,
                          ),
                          if (editing) ...[
                            const Spacer(),
                            const SizedBox(height: 24),
                            OutlinedButton.icon(
                              key: const ValueKey('authorDelete'),
                              onPressed: _delete,
                              icon: SvgIcon(
                                AppIcons.trash,
                                size: 20,
                                strokeWidth: 1.8,
                                color: t.danger,
                              ),
                              label: Text(l.authorDelete),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: t.danger,
                                side: BorderSide(
                                  color: t.danger.withValues(alpha: 0.4),
                                  width: 1.5,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 13,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 封面：預覽＋「更換封面」（AuthorEdit）。
class _BannerField extends ConsumerWidget {
  const _BannerField({required this.draft});
  final AuthorDraft draft;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 150,
            height: 60,
            child: AuthorBanner(
              id: draft.id ?? '',
              file: draft.bannerFile,
              iconSize: 20,
            ),
          ),
        ),
        const SizedBox(width: 14),
        OutlinedButton(
          key: const ValueKey('authorChangeBanner'),
          onPressed: () async {
            final f = await pickAuthorImage(context, ref);
            if (f != null) draft.set(() => draft.bannerFile = f);
          },
          style: OutlinedButton.styleFrom(
            foregroundColor: t.text2,
            backgroundColor: t.surface,
            side: BorderSide(color: t.borderCard),
            shape: const StadiumBorder(),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            minimumSize: const Size(0, 32),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            textStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          child: Text(context.l10n.authorChangeBanner),
        ),
      ],
    );
  }
}

/// 已連結的帳號（AuthorEdit）：同步來源那一列「更新」，另一列「改用這個同步」，右邊 ✕ 解除連結。
class _LinkedPanel extends StatelessWidget {
  const _LinkedPanel({
    required this.draft,
    required this.refreshedAt,
    required this.refreshing,
    required this.onRefresh,
  });
  final AuthorDraft draft;
  final DateTime? refreshedAt;
  final bool refreshing;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = context.l10n;
    final entries = [
      for (final p in LinkPlatform.values)
        if (draft.linked[p] != null) draft.linked[p]!,
    ];
    String date(DateTime d) =>
        '${d.year} / ${d.month.toString().padLeft(2, '0')} / ${d.day.toString().padLeft(2, '0')}';

    Widget pillButton({
      required Key key,
      required String icon,
      required double iconSize,
      required String label,
      required String tooltip,
      required VoidCallback? onTap,
      bool busy = false,
    }) => Tooltip(
      message: tooltip,
      child: OutlinedButton(
        key: key,
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: t.text2,
          backgroundColor: t.ground,
          side: BorderSide(color: t.border),
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          minimumSize: const Size(0, 30),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          textStyle: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            busy
                ? SizedBox(
                    width: iconSize - 4,
                    height: iconSize - 4,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: t.accent,
                    ),
                  )
                : SvgIcon(
                    icon,
                    size: iconSize,
                    strokeWidth: 1.9,
                    color: t.text2,
                  ),
            const SizedBox(width: 4),
            Text(label),
          ],
        ),
      ),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      decoration: BoxDecoration(
        color: t.surface,
        border: Border.all(color: t.borderCard),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          for (final (i, p) in entries.indexed)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: BoxDecoration(
                border: i == entries.length - 1
                    ? null
                    : Border(
                        bottom: BorderSide(
                          color: t.border.withValues(alpha: 0.75),
                        ),
                      ),
              ),
              child: Row(
                children: [
                  PlatformBadge(p.platform),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.platform == LinkPlatform.x
                              ? '@${p.handle}'
                              : p.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                            color: t.ink,
                          ),
                        ),
                        Text(
                          draft.syncSource == p.platform
                              ? (refreshedAt == null
                                    ? (p.platform == LinkPlatform.x
                                          ? l.authorPlatformX
                                          : l.authorXhsNumber(p.handle))
                                    : l.authorLastRefreshed(date(refreshedAt!)))
                              : (p.platform == LinkPlatform.x
                                    ? l.authorPlatformX
                                    : l.authorXhsNumber(p.handle)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11.5, color: t.text3),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (draft.syncSource == p.platform)
                    pillButton(
                      key: const ValueKey('authorRefresh'),
                      icon: AuthorIcons.refresh,
                      iconSize: 18,
                      label: l.authorRefresh,
                      tooltip: l.authorRefreshNow,
                      busy: refreshing,
                      onTap: refreshing ? null : onRefresh,
                    )
                  else
                    pillButton(
                      key: ValueKey('authorUseForSync-${p.platform.name}'),
                      icon: AuthorIcons.swap,
                      iconSize: 16,
                      label: l.authorUseForSync,
                      tooltip: l.authorUseForSyncLabel,
                      onTap: () =>
                          draft.set(() => draft.syncSource = p.platform),
                    ),
                  IconButton(
                    key: ValueKey('authorUnlink-${p.platform.name}'),
                    tooltip: l.authorUnlink,
                    onPressed: () => draft.unlink(p.platform),
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(),
                    icon: SvgIcon(
                      AppIcons.closeX,
                      size: 16,
                      strokeWidth: 2,
                      color: const Color(0xFFB7ADA0),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
