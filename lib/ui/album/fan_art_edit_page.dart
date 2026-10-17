import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/album_queries.dart';
import '../../data/database.dart';
import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../common/adaptive_modal.dart';
import '../common/modal_form_layout.dart';
import '../common/nav_bar_hidden.dart';
import '../pits/pit_form.dart';
import '../tags/tag_picker.dart';
import 'album_actions.dart';
import 'album_form.dart';
import 'group_picker.dart';
import 'image_picker_field.dart';

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

  final _author = TextEditingController();
  String? _groupId;
  List<String>? _tagIds;
  NewImage? _image;
  bool _loaded = false;

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
    if (!mounted) return;
    setState(() {
      _author.text = row.author;
      _groupId = row.groupId;
      _tagIds = ids;
      _image = NewImage(
        file: row.imageFile,
        width: row.width,
        height: row.height,
        kind: row.kind,
        durationMs: row.durationMs,
        posterFile: row.posterFile,
      );
      _loaded = true;
    });
  }

  @override
  void dispose() {
    _author.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await ref
        .read(databaseProvider)
        .updateFanArt(
          widget.imageId,
          author: _author.text.trim(),
          groupId: _groupId,
          tagIds: _tagIds ?? const [],
        );
    if (mounted) Navigator.of(context).pop();
  }

  /// 圖片上的「×」＝刪除這張同人圖（編輯單張沒有別的圖可以換），要確認。
  Future<void> _removeImage() async {
    final ok = await confirmDelete(
      context,
      title: context.l10n.albumDeleteImageTitle,
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
        items: [ImageItem.stored(_image!)],
        onAdd: null,
        onRemove: (_) => _removeImage(),
      ),
    ];
    final rest = [
      AlbumFieldLabel(context.l10n.albumFieldAuthor),
      TextField(controller: _author, decoration: pitInputDecoration(context)),
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
        AlbumSubmitButton(label: context.l10n.commonSave, onTap: _save),
      ],
    );
  }
}
