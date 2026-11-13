import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/album_queries.dart';
import '../../data/album_set_queries.dart';
import '../../data/junk_queries.dart' show AlbumCell;
import '../../data/database.dart';
import '../../data/inspo_queries.dart';
import '../../data/sensitive_queries.dart';
import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../common/adaptive_modal.dart';
import '../common/modal_form_layout.dart';
import '../common/nav_bar_hidden.dart';
import '../common/sensitive_dialogs.dart';
import '../authors/author_pick_sheet.dart';
import '../tags/tag_picker.dart';
import 'album_actions.dart';
import 'album_form.dart';
import 'album_set_form.dart';
import 'group_picker.dart';
import 'image_picker_field.dart';
import '../common/reorder_tile.dart';

/// 編輯同人圖的單一入口：視窗 ≥840 開置中 modal，較窄開整頁。回傳 true＝這張圖在編輯時被刪除。
Future<bool?> openFanArtEdit(
  BuildContext context, {
  required String pitId,
  required String imageId,
}) => showAdaptiveModal<bool>(
  context,
  width: 880,
  height: 640,
  builder: (_, asModal) =>
      FanArtEditPage(pitId: pitId, imageId: imageId, asModal: asModal),
);

/// 編輯同人圖：圖片、作者、出處、tag（設計稿沒畫，版型沿用 OfficialNew）。沒有底部導覽列。
class FanArtEditPage extends ConsumerStatefulWidget {
  const FanArtEditPage({
    super.key,
    required this.pitId,
    required this.imageId,
    this.asModal = false,
  });
  final String pitId;
  final String imageId;

  /// 畫成置中 modal 的內容（取消／標題／主動作 標題列，不藏導覽列）。
  final bool asModal;

  @override
  ConsumerState<FanArtEditPage> createState() => _FanArtEditPageState();
}

/// 離開時回傳 true＝這張圖在編輯頁被刪除。
class _FanArtEditPageState extends ConsumerState<FanArtEditPage>
    with HidesNavBar<FanArtEditPage> {
  @override
  bool get hidesNavBarOnOpen => !widget.asModal;

  /// 作者（D-156）：null＝不指定。
  String? _authorId;
  final _note = TextEditingController();
  String? _groupId;
  List<String>? _tagIds;
  NewImage? _image; // 載入時的第 1 張

  /// 表單裡這一組的圖（D-136；持有敏感標記的切換狀態，D-104）。
  final List<ImageItem> _items = [];
  bool _loaded = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = ref.read(databaseProvider);
    final row = await (db.select(
      db.fanArts,
    )..where((f) => f.id.equals(widget.imageId))).getSingle();
    final ids = await db.watchTagIds(TagTarget.fanArt, widget.imageId).first;
    final images = await db.albumSetImages(AlbumCell.fan, widget.imageId);
    if (!mounted) return;
    setState(() {
      _authorId = row.authorId;
      _note.text = row.note ?? '';
      _groupId = row.groupId;
      _tagIds = ids;
      _image = images.first;
      _items.addAll(images.map(ImageItem.stored));
      _loaded = true;
    });
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  /// 寫回：整組的圖（次序、增刪）＋作者／出處／tag／第 1 張的敏感標記。取消確認時回傳 false。
  Future<bool> _persist() async {
    final db = ref.read(databaseProvider);
    final sensitive = _items.first.sensitive;
    // 把現任封面標成敏感：先確認（D-104）。
    if (sensitive &&
        !_image!.sensitive &&
        await db.coverCountAmong(SensitiveSource.fan, [widget.imageId]) > 0) {
      if (!mounted || !await confirmSensitiveCover(context, 1)) return false;
    }
    setState(() => _saving = true);
    final store = await ref.read(imageStoreProvider.future);
    final images = <NewImage>[for (final f in _items) await f.resolve(store)];
    await db.setAlbumSetImages(AlbumCell.fan, widget.imageId, images);
    await db.updateFanArt(
      widget.imageId,
      author: await authorNameFor(db, _authorId),
      authorId: _authorId,
      groupId: _groupId,
      tagIds: _tagIds ?? const [],
      sensitive: sensitive,
    );
    await db.setFanArtNote(widget.imageId, _note.text);
    return true;
  }

  Future<void> _save() async {
    if (_saving || _items.isEmpty) return;
    if (await _persist() && mounted) Navigator.of(context).pop();
  }

  /// 拆開（D-136）：先存目前的編輯，再把這一組每一張變成獨立一項。
  Future<void> _split() async {
    final n = _items.length;
    if (!await confirmAlbumSetSplit(context, n) || !mounted) return;
    if (!await _persist()) return;
    await ref
        .read(databaseProvider)
        .splitAlbumSet(AlbumCell.fan, widget.imageId);
    // 會跳頁的動作不出提示條（D-114）：回到預覽頁就看得到拆開了。
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _pick() async {
    final picked = await ref.read(imagePickerProvider)(context);
    if (picked.isNotEmpty) {
      setState(() => _items.addAll(picked.map(ImageItem.picked)));
    }
  }

  /// 圖片上的「×」：一組裡還有別張＝只拿掉這張；只剩這一張＝刪除這筆同人圖，要確認。
  Future<void> _removeImage(int i) async {
    if (_items.length > 1) {
      setState(() => _items.removeAt(i));
      return;
    }
    final ok = await confirmDelete(
      context,
      title: context.l10n.albumDeleteImageTitle,
      toTrash: true,
    );
    if (!ok || !mounted) return;
    await ref.read(databaseProvider).deleteFanArts([widget.imageId]);
    if (!mounted) return;
    // 回傳 true 讓預覽頁知道這張圖已經刪除。
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final title = context.l10n.albumFanEditTitle;
    if (!_loaded) {
      if (widget.asModal) {
        return ModalFormShell(
          title: title,
          actionLabel: context.l10n.commonSave,
          onAction: () {},
          loaded: false,
          panes: const [],
        );
      }
      return AlbumFormScaffold(
        title: title,
        children: [Center(child: CircularProgressIndicator())],
      );
    }
    final imageField = [
      AlbumFieldLabel(context.l10n.albumFieldImage),
      ImagePickerField(
        pitId: widget.pitId,
        items: _items,
        onAdd: _pick,
        onRemove: _removeImage,
        onReorder: (a, b) => setState(() => moveListItem(_items, a, b)),
      ),
      if (_items.length > 1)
        AlbumSetSplitRow(count: _items.length, onTap: _saving ? null : _split),
    ];
    final rest = [
      AlbumFieldLabel(context.l10n.albumFieldAuthor),
      AuthorField(
        authorId: _authorId,
        onChanged: (id) => setState(() => _authorId = id),
      ),
      const SizedBox(height: 18),
      GroupPicker(
        pitId: widget.pitId,
        kind: 'fan',
        label: context.l10n.albumFieldSource,
        selected: _groupId,
        allowClear: true,
        onSelected: (v) => setState(() => _groupId = v),
      ),
      const SizedBox(height: 18),
      TagPicker(
        pitId: widget.pitId,
        selected: _tagIds!,
        onChanged: (v) => setState(() => _tagIds = v),
      ),
      const SizedBox(height: 18),
      NoteField(controller: _note),
    ];
    if (widget.asModal) {
      return ModalFormShell(
        title: title,
        actionLabel: context.l10n.commonSave,
        onAction: _save,
        panes: [
          ModalPane(width: 420, children: imageField),
          ModalPane(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
            children: rest,
          ),
        ],
      );
    }
    return AlbumFormScaffold(
      title: title,
      children: [
        ...imageField,
        const SizedBox(height: 18),
        ...rest,
        const SizedBox(height: 26),
        AlbumSubmitButton(
          label: context.l10n.commonSave,
          busy: _saving,
          onTap: _save,
        ),
      ],
    );
  }
}
