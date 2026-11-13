import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/author_link.dart';
import '../../data/author_queries.dart';
import '../../data/database.dart';
import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../../theme/tokens.dart';
import '../common/app_icons.dart';
import '../common/svg_icon.dart';
import '../common/themed_sheet.dart';
import '../pits/pit_form.dart';
import 'author_form.dart';
import 'author_icons.dart';
import 'author_widgets.dart';

/// 選擇作者的結果：[id] 為 null＝不指定。
class AuthorPick {
  const AuthorPick(this.id);
  final String? id;
}

/// 選擇作者 sheet（AuthorPickSheet）：搜尋、不指定、新增作者（同一個 sheet 換成 AuthorQuickNew）。
/// 取消（拉下、點外面）回傳 null。
Future<AuthorPick?> showAuthorPickSheet(
  BuildContext context, {
  String? selectedId,
}) => showThemedSheet<AuthorPick>(
  context: context,
  useRootNavigator: true,
  builder: (_) => _AuthorPickSheet(selectedId: selectedId),
);

class _AuthorPickSheet extends ConsumerStatefulWidget {
  const _AuthorPickSheet({this.selectedId});
  final String? selectedId;

  @override
  ConsumerState<_AuthorPickSheet> createState() => _AuthorPickSheetState();
}

class _AuthorPickSheetState extends ConsumerState<_AuthorPickSheet> {
  final _query = TextEditingController();
  AuthorDraft? _draft;

  @override
  void dispose() {
    _query.dispose();
    _draft?.dispose();
    super.dispose();
  }

  void _startNew() => setState(() {
    _draft = AuthorDraft()
      ..name.text = _query.text.trim()
      ..addListener(() {
        if (mounted) setState(() {});
      });
  });

  Future<void> _create() async {
    final d = _draft!;
    if (!d.canSave) return;
    final id = await ref.read(databaseProvider).addAuthor(d.toCompanion());
    if (mounted) Navigator.of(context).pop(AuthorPick(id));
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final height = (_draft == null ? 600.0 : 540.0).clamp(
      0.0,
      mq.size.height * 0.92,
    );
    return Padding(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: SizedBox(
        height: height,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 10, 0, 4),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD8CFC3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Expanded(
              child: _draft == null ? _list(context) : _quickNew(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _list(BuildContext context) {
    final t = context.tokens;
    final l = context.l10n;
    final q = _query.text.trim().toLowerCase();
    final all = ref.watch(authorsProvider).value ?? const <Author>[];
    final list = q.isEmpty
        ? all
        : [
            for (final a in all)
              if (a.name.toLowerCase().contains(q) ||
                  a.handle.toLowerCase().contains(q))
                a,
          ];
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l.authorPick,
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
              TextButton(
                key: const ValueKey('authorPickNone'),
                onPressed: () =>
                    Navigator.of(context).pop(const AuthorPick(null)),
                style: TextButton.styleFrom(
                  foregroundColor: t.text2,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 2,
                    vertical: 6,
                  ),
                  minimumSize: const Size(0, 32),
                  textStyle: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: Text(l.authorPickNone),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: t.surface,
              border: Border.all(color: t.field),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                SvgIcon(
                  AuthorIcons.search,
                  size: 18,
                  strokeWidth: 1.9,
                  color: t.text3,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    key: const ValueKey('authorPickSearch'),
                    controller: _query,
                    onChanged: (_) => setState(() {}),
                    style: TextStyle(fontSize: 14.5, color: t.ink),
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 11),
                      hintText: l.authorSearch,
                      hintStyle: TextStyle(fontSize: 14.5, color: t.text4),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            children: [
              _PickRow(
                key: const ValueKey('authorPickNew'),
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: t.dashed, width: 1.5),
                  ),
                  child: Center(
                    child: SvgIcon(
                      AppIcons.plus,
                      size: 14,
                      strokeWidth: 2,
                      color: t.dashedText,
                    ),
                  ),
                ),
                title: l.authorAdd,
                titleColor: t.accentStrong,
                bold: true,
                onTap: _startNew,
              ),
              for (final a in list)
                _PickRow(
                  key: ValueKey('authorPick-${a.id}'),
                  leading: AuthorAvatar.of(a, size: 40),
                  title: a.name,
                  subtitle: a.handle,
                  bold: a.id == widget.selectedId,
                  selected: a.id == widget.selectedId,
                  onTap: () => Navigator.of(context).pop(AuthorPick(a.id)),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// AuthorQuickNew：返回、頭像在左、名字／ID 浮動標籤、連結帳號、「建立並選擇」。
  Widget _quickNew(BuildContext context) {
    final l = context.l10n;
    final d = _draft!;
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 2, 14, 6),
          child: Row(
            children: [
              IconButton(
                tooltip: l.commonBack,
                onPressed: () => setState(() {
                  _draft?.dispose();
                  _draft = null;
                }),
                icon: SvgIcon(AppIcons.back, color: t.ink, strokeWidth: 1.9),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  l.authorAdd,
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    AuthorAvatarPicker(draft: d, size: 64, badge: 24),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        children: [
                          TextField(
                            key: const ValueKey('authorQuickName'),
                            controller: d.name,
                            autofocus: true,
                            textInputAction: TextInputAction.next,
                            decoration: pitFloatingDecoration(
                              context,
                              l.authorFieldName,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            key: const ValueKey('authorQuickHandle'),
                            controller: d.handle,
                            autocorrect: false,
                            decoration: pitFloatingDecoration(
                              context,
                              l.authorFieldHandle,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                PitFieldLabel(l.authorLinkedAccounts),
                for (final p in LinkPlatform.values)
                  AuthorLinkInput(draft: d, platform: p),
                const SizedBox(height: 4),
                PitPrimaryButton(
                  key: const ValueKey('authorQuickCreate'),
                  label: l.authorCreateAndPick,
                  onPressed: d.canSave ? _create : null,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PickRow extends StatelessWidget {
  const _PickRow({
    super.key,
    required this.leading,
    required this.title,
    this.subtitle,
    this.titleColor,
    this.bold = false,
    this.selected = false,
    required this.onTap,
  });
  final Widget leading;
  final String title;
  final String? subtitle;
  final Color? titleColor;
  final bool bold;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final sub = subtitle;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: t.border.withValues(alpha: 0.75)),
          ),
        ),
        child: Row(
          children: [
            leading,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
                      color: titleColor ?? t.ink,
                    ),
                  ),
                  if (sub != null && sub.isNotEmpty)
                    Text(
                      sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: t.text3),
                    ),
                ],
              ),
            ),
            if (selected)
              SvgIcon(
                AppIcons.check,
                size: 20,
                strokeWidth: 2.4,
                color: t.accent,
              ),
          ],
        ),
      ),
    );
  }
}

/// 新增／編輯同人圖的「作者」欄（FanArtNewAuthor）：選了作者＝頭像＋名字＋ID；沒選＝佔位「選擇作者」。
class AuthorField extends ConsumerWidget {
  const AuthorField({
    super.key,
    required this.authorId,
    required this.onChanged,
  });
  final String? authorId;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final l = context.l10n;
    final id = authorId;
    final a = id == null ? null : ref.watch(authorProvider(id)).value;
    final picked = a != null && a.deletedAt == null;
    return Material(
      color: t.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: t.field),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: const ValueKey('authorField'),
        onTap: () async {
          final r = await showAuthorPickSheet(context, selectedId: authorId);
          if (r != null) onChanged(r.id);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(
            children: [
              picked
                  ? AuthorAvatar.of(a, size: 36)
                  : const AuthorAvatar(id: null, name: '', size: 36),
              const SizedBox(width: 12),
              Expanded(
                child: picked
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            a.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: t.ink,
                            ),
                          ),
                          if (a.handle.isNotEmpty)
                            Text(
                              a.handle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12, color: t.text3),
                            ),
                        ],
                      )
                    : Text(
                        l.authorPick,
                        style: TextStyle(fontSize: 15, color: t.text3),
                      ),
              ),
              SvgIcon(
                AppIcons.chevronRight,
                size: 18,
                strokeWidth: 2,
                color: const Color(0xFFB7ADA0),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 作者 id → 同人圖要存的作者文字（本機快取）。
Future<String> authorNameFor(AppDatabase db, String? id) async =>
    id == null ? '' : (await db.loadAuthor(id))?.name ?? '';
