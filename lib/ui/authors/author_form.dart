import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/author_link.dart';
import '../../data/database.dart';
import '../../data/media.dart';
import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../../theme/tokens.dart';
import '../common/svg_icon.dart';
import 'author_icons.dart';
import 'author_sync.dart';
import 'author_widgets.dart';

/// 連結輸入框的狀態（AuthorLinkStates）。
enum LinkInputState { idle, loading, failed, linked }

/// 新增／編輯作者的表單內容（新增頁、編輯頁、選擇作者 sheet 裡的新增共用）。
/// 欄位都在按「建立／儲存」時才寫入資料庫。
class AuthorDraft extends ChangeNotifier {
  AuthorDraft([Author? a])
    : id = a?.id,
      name = TextEditingController(text: a?.name ?? ''),
      handle = TextEditingController(text: a?.handle ?? ''),
      avatarFile = a?.avatarFile,
      bannerFile = a?.bannerFile,
      syncSource = LinkPlatform.parse(a?.syncSource) {
    if (a?.xUserId != null) {
      linked[LinkPlatform.x] = LinkedProfile(
        platform: LinkPlatform.x,
        userId: a!.xUserId!,
        handle: a.xHandle ?? '',
        name: a.xName ?? '',
      );
    }
    if (a?.xhsUserId != null) {
      linked[LinkPlatform.xhs] = LinkedProfile(
        platform: LinkPlatform.xhs,
        userId: a!.xhsUserId!,
        handle: a.xhsHandle ?? '',
        name: a.xhsName ?? '',
      );
    }
    name.addListener(notifyListeners);
  }

  /// null＝新增。
  final String? id;
  final TextEditingController name;
  final TextEditingController handle;
  String? avatarFile;
  String? bannerFile;
  LinkPlatform? syncSource;

  /// 已連結（含剛查到、還沒儲存的）帳號。
  final Map<LinkPlatform, LinkedProfile> linked = {};

  /// 還沒連結時的輸入框。
  final Map<LinkPlatform, TextEditingController> inputs = {
    LinkPlatform.x: TextEditingController(),
    LinkPlatform.xhs: TextEditingController(),
  };
  final Map<LinkPlatform, LinkInputState> states = {
    LinkPlatform.x: LinkInputState.idle,
    LinkPlatform.xhs: LinkInputState.idle,
  };

  bool get canSave => name.text.trim().isNotEmpty;

  void set(void Function() f) {
    f();
    notifyListeners();
  }

  void link(LinkedProfile p) => set(() {
    linked[p.platform] = p;
    states[p.platform] = LinkInputState.linked;
    // 只連結一邊時就是那一邊；已經有同步來源就不搶。
    syncSource ??= p.platform;
  });

  void unlink(LinkPlatform p) => set(() {
    linked.remove(p);
    inputs[p]!.clear();
    states[p] = LinkInputState.idle;
    if (syncSource == p) {
      syncSource = linked.keys.isEmpty ? null : linked.keys.first;
    }
  });

  /// 套用平台資料（「使用」）：頭像、名字、ID 換成平台上的。
  void useProfile(
    BuildContext context,
    LinkedProfile p,
    String? avatar,
    String? banner,
  ) => set(() {
    name.text = p.name;
    handle.text = linkedHandleText(context, p);
    if (avatar != null) avatarFile = avatar;
    if (banner != null) bannerFile = banner;
  });

  /// 寫入資料庫的欄位。
  AuthorsCompanion toCompanion() {
    final x = linked[LinkPlatform.x];
    final xhs = linked[LinkPlatform.xhs];
    return AuthorsCompanion(
      name: Value(name.text.trim()),
      handle: Value(handle.text.trim()),
      avatarFile: Value(avatarFile),
      bannerFile: Value(bannerFile),
      xUserId: Value(x?.userId),
      xHandle: Value(x?.handle),
      xName: Value(x?.name),
      xhsUserId: Value(xhs?.userId),
      xhsHandle: Value(xhs?.handle),
      xhsName: Value(xhs?.name),
      syncSource: Value(syncSource?.name),
    );
  }

  @override
  void dispose() {
    name.dispose();
    handle.dispose();
    for (final c in inputs.values) {
      c.dispose();
    }
    super.dispose();
  }
}

/// 從相簿選一張圖（只收圖片與 GIF），存成本機圖片檔。取消或失敗回傳 null。
Future<String?> pickAuthorImage(BuildContext context, WidgetRef ref) async {
  try {
    final picked = (await ref.read(avatarPickerProvider)(context))
        .where((f) => mediaKindFromExtension(f.path) != MediaKind.video)
        .toList();
    if (picked.isEmpty) return null;
    final store = await ref.read(imageStoreProvider.future);
    final im = await store.import(picked.first);
    return im.file;
  } catch (_) {
    return null;
  }
}

/// 可點的頭像（右下角黑底相機）。
class AuthorAvatarPicker extends ConsumerWidget {
  const AuthorAvatarPicker({
    super.key,
    required this.draft,
    required this.size,
    required this.badge,
  });
  final AuthorDraft draft;
  final double size;
  final double badge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      button: true,
      label: draft.id == null && draft.avatarFile == null
          ? context.l10n.authorPickAvatar
          : context.l10n.authorChangeAvatar,
      child: GestureDetector(
        onTap: () async {
          final f = await pickAuthorImage(context, ref);
          if (f != null) draft.set(() => draft.avatarFile = f);
        },
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              AuthorAvatar(
                id: draft.id,
                name: draft.id == null ? '' : draft.name.text,
                file: draft.avatarFile,
                size: size,
              ),
              Positioned(
                right: size > 70 ? 0 : -2,
                bottom: size > 70 ? 0 : -2,
                child: Container(
                  width: badge,
                  height: badge,
                  decoration: BoxDecoration(
                    color: t.ink,
                    shape: BoxShape.circle,
                    border: Border.all(color: t.ground, width: 2),
                  ),
                  child: Center(
                    child: SvgIcon(
                      AuthorIcons.camera,
                      size: 14,
                      strokeWidth: 2,
                      color: dark ? t.ground : Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 還沒連結的帳號輸入框（AuthorNew／AuthorLinkStates／AuthorLinkConfirm）：
/// 貼上或打完連結就查；查到跳「使用推特上的資料？」；查不到顯示一般失敗＋重試。
class AuthorLinkInput extends ConsumerStatefulWidget {
  const AuthorLinkInput({
    super.key,
    required this.draft,
    required this.platform,
  });
  final AuthorDraft draft;
  final LinkPlatform platform;

  @override
  ConsumerState<AuthorLinkInput> createState() => _AuthorLinkInputState();
}

class _AuthorLinkInputState extends ConsumerState<AuthorLinkInput> {
  Timer? _debounce;
  String _lastQueried = '';

  TextEditingController get _c => widget.draft.inputs[widget.platform]!;
  LinkInputState get _state => widget.draft.states[widget.platform]!;

  void _setState(LinkInputState s) =>
      widget.draft.set(() => widget.draft.states[widget.platform] = s);

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _changed(String _) {
    _debounce?.cancel();
    if (_state == LinkInputState.failed || _state == LinkInputState.linked) {
      _setState(LinkInputState.idle);
      widget.draft.set(() => widget.draft.linked.remove(widget.platform));
    }
    _debounce = Timer(const Duration(milliseconds: 900), _lookup);
  }

  Future<void> _lookup({bool force = false}) async {
    _debounce?.cancel();
    final text = _c.text.trim();
    if (text.isEmpty) {
      _setState(LinkInputState.idle);
      return;
    }
    if (!force && text == _lastQueried) return;
    _lastQueried = text;
    final key = parseLinkInput(widget.platform, text);
    if (key == null) {
      _setState(LinkInputState.failed);
      return;
    }
    _setState(LinkInputState.loading);
    LinkedProfile p;
    try {
      p = await ref
          .read(authorLinkServiceProvider)
          .lookup(widget.platform, key);
    } catch (_) {
      if (mounted && _c.text.trim() == text) _setState(LinkInputState.failed);
      return;
    }
    if (!mounted || _c.text.trim() != text) return;
    // 先問、先下載，最後才標成已連結：編輯頁一連結就把這個輸入框換成已連結那一列，
    // 輸入框不在了就套用不到（按「使用」沒反應）。
    final draft = widget.draft;
    final use = await confirmUseLinked(context, p);
    if (!mounted) return;
    if (!use) {
      draft.link(p);
      return;
    }
    final avatar = await downloadLinkedImage(ref, p.avatarUrl);
    final banner = p.platform == LinkPlatform.x
        ? await downloadLinkedImage(ref, p.bannerUrl)
        : null;
    if (!mounted) return;
    draft.useProfile(context, p, avatar, banner);
    draft.link(p);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = context.l10n;
    final x = widget.platform == LinkPlatform.x;
    final state = _state;
    final failed = state == LinkInputState.failed;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: t.surface,
              border: Border.all(color: failed ? t.accent : t.field),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                PlatformBadge(widget.platform),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    key: ValueKey('authorLink-${widget.platform.name}'),
                    controller: _c,
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    onChanged: _changed,
                    onSubmitted: (_) => _lookup(),
                    style: TextStyle(fontSize: 14, color: t.ink),
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 4),
                      hintText: x ? l.authorXLinkHint : l.authorXhsLinkHint,
                      hintStyle: TextStyle(fontSize: 14, color: t.text4),
                      semanticCounterText: x
                          ? l.authorXLinkLabel
                          : l.authorXhsLinkLabel,
                    ),
                  ),
                ),
                if (state == LinkInputState.loading)
                  Semantics(
                    label: l.authorLookingUp,
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: t.accent,
                        backgroundColor: t.border,
                      ),
                    ),
                  )
                else if (state == LinkInputState.linked)
                  SvgIcon(
                    AuthorIcons.linked,
                    size: 18,
                    strokeWidth: 2,
                    color: const Color(0xFF3E8073),
                  ),
              ],
            ),
          ),
          if (failed)
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 6, 2, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l.authorLinkFail,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: t.danger.withValues(alpha: 0.95),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _lookup(force: true),
                    style: TextButton.styleFrom(
                      foregroundColor: t.accentStrong,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      minimumSize: const Size(0, 28),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      textStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    child: Text(l.commonRetry),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
