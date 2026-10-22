import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/album_queries.dart';
import '../../data/database.dart';
import '../../data/sensitive_queries.dart';
import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../common/adaptive_modal.dart';
import '../common/modal_form_layout.dart';
import '../common/nav_bar_hidden.dart';
import '../common/sensitive_dialogs.dart';
import '../media_source/drop_zone.dart';
import '../../theme/tokens.dart';
import 'album_actions.dart';
import 'album_form.dart';
import '../tags/tag_picker.dart';
import 'group_picker.dart';
import 'image_picker_field.dart';
import '../common/reorder_tile.dart';

/// 新增官方圖的單一入口：視窗 ≥840 開置中 modal（NewOfficial，880×640），較窄開整頁。
Future<void> openOfficialNew(
  BuildContext context, {
  required String pitId,
  String? initialGroupId,
  List<XFile> initialImages = const [],
}) => showAdaptiveModal<void>(
  context,
  width: 880,
  height: 640,
  builder: (_, asModal) => OfficialNewPage(
    pitId: pitId,
    initialGroupId: initialGroupId,
    initialImages: initialImages,
    asModal: asModal,
  ),
);

/// 編輯官方圖的單一入口（D-089，預覽頁「編輯」）：沿用 OfficialNew 版型，
/// 視窗 ≥840 開置中 modal，較窄開整頁。回傳 true＝這張圖在編輯時被刪除。
Future<bool?> openOfficialEdit(
  BuildContext context, {
  required String pitId,
  required String imageId,
}) => showAdaptiveModal<bool>(
  context,
  width: 880,
  height: 640,
  builder: (_, asModal) =>
      OfficialNewPage(pitId: pitId, editImageId: imageId, asModal: asModal),
);

/// 新增官方圖（OfficialNew）：一次可加多張，選分組、tag（D-089）；
/// 傳 [editImageId] 就是編輯那一張（同版型，圖片欄只讀，按「×」＝刪除）。沒有底部導覽列。
class OfficialNewPage extends ConsumerStatefulWidget {
  const OfficialNewPage({
    super.key,
    required this.pitId,
    this.initialGroupId,
    this.initialImages = const [],
    this.asModal = false,
    this.editImageId,
  });
  final String pitId;
  final String? initialGroupId;

  /// 非 null＝編輯這張官方圖（離開時回傳 true 代表圖被刪除）。
  final String? editImageId;

  /// 從相簿先選好的圖片（新增流程是先選圖、再進新增頁）。
  final List<XFile> initialImages;

  /// 畫成置中 modal 的內容（取消／標題／主動作 標題列，不藏導覽列）。
  final bool asModal;

  @override
  ConsumerState<OfficialNewPage> createState() => _OfficialNewPageState();
}

class _OfficialNewPageState extends ConsumerState<OfficialNewPage>
    with HidesNavBar<OfficialNewPage> {
  @override
  bool get hidesNavBarOnOpen => !widget.asModal;

  late final List<ImageItem> _files = widget.initialImages
      .map(ImageItem.picked)
      .toList();
  String? _groupId;
  List<String> _tagIds = [];
  bool _saving = false;

  // 編輯模式：載入的那一張。
  NewImage? _editImage;
  ImageItem? _editItem; // 持有敏感標記的切換狀態（D-104）
  bool _loaded = false;
  bool get _editing => widget.editImageId != null;

  @override
  void initState() {
    super.initState();
    if (_editing) _load();
  }

  Future<void> _load() async {
    final db = ref.read(databaseProvider);
    final row = await (db.select(
      db.officialImages,
    )..where((f) => f.id.equals(widget.editImageId!))).getSingle();
    final ids = await db.watchTagIds(TagTarget.official, row.id).first;
    if (!mounted) return;
    setState(() {
      _groupId = row.groupId;
      _tagIds = ids;
      _editImage = NewImage(
        file: row.imageFile,
        width: row.width,
        height: row.height,
        kind: row.kind,
        durationMs: row.durationMs,
        posterFile: row.posterFile,
        sensitive: row.sensitive,
      );
      _editItem = ImageItem.stored(_editImage!);
      _loaded = true;
    });
  }

  /// 編輯模式圖片上的「×」＝刪除這張官方圖（編輯單張沒有別的圖可以換），要確認。
  Future<void> _removeImage() async {
    final ok = await confirmDelete(
      context,
      title: context.l10n.albumDeleteImageTitle,
    );
    if (!ok || !mounted) return;
    await ref.read(databaseProvider).deleteOfficial([widget.editImageId!]);
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _pick() async {
    final picked = await ref.read(imagePickerProvider)(context);
    if (picked.isNotEmpty) {
      setState(() => _files.addAll(picked.map(ImageItem.picked)));
    }
  }

  Future<void> _save(String groupId) async {
    if (_editing) {
      final db = ref.read(databaseProvider);
      final sensitive = _editItem!.sensitive;
      // 把現任封面標成敏感：先確認（D-104）。
      if (sensitive &&
          !_editImage!.sensitive &&
          await db.coverCountAmong(SensitiveSource.official, [
                widget.editImageId!,
              ]) >
              0) {
        if (!mounted || !await confirmSensitiveCover(context, 1)) return;
      }
      await db.updateOfficial(
        widget.editImageId!,
        groupId: groupId,
        tagIds: _tagIds,
        sensitive: sensitive,
      );
      if (mounted) Navigator.of(context).pop();
      return;
    }
    if (_files.isEmpty) {
      showSnack(context, context.l10n.albumPickImageFirst);
      return;
    }
    setState(() => _saving = true);
    final store = await ref.read(imageStoreProvider.future);
    final imported = <NewImage>[];
    for (final f in _files) {
      imported.add(await f.resolve(store));
    }
    await ref
        .read(databaseProvider)
        .addOfficial(widget.pitId, groupId, imported, tagIds: _tagIds);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final title = _editing
        ? context.l10n.officialtagEditTitle
        : context.l10n.albumOfficialNewTitle;
    if (_editing && !_loaded) {
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
        children: const [Center(child: CircularProgressIndicator())],
      );
    }
    final groups =
        ref.watch(groupsProvider((widget.pitId, 'official'))).value ?? const [];
    final groupId = groups.any((g) => g.id == _groupId)
        ? _groupId
        : (groups.any((g) => g.id == widget.initialGroupId)
              ? widget.initialGroupId
              : (groups.isEmpty ? null : groups.first.id));
    final imageField = [
      AlbumFieldLabel(
        // 彈出頁（form sheet／page sheet）新增時標題帶張數：「圖片 · 2 張」。
        widget.asModal && !_editing
            ? context.l10n.ipadauditImagesCount(
                context.l10n.albumFieldImage,
                _files.length,
              )
            : context.l10n.albumFieldImage,
      ),
      if (_editing)
        ImagePickerField(
          pitId: widget.pitId,
          items: [_editItem!],
          onAdd: null,
          onRemove: (_) => _removeImage(),
        )
      else ...[
        ImagePickerField(
          pitId: widget.pitId,
          items: _files,
          onAdd: _pick,
          onRemove: (i) => setState(() => _files.removeAt(i)),
          onReorder: (a, b) => setState(() => moveListItem(_files, a, b)),
        ),
        const DropHintRow(),
      ],
    ];
    final groupField = GroupPicker(
      pitId: widget.pitId,
      kind: 'official',
      selected: groupId,
      onSelected: (v) => setState(() => _groupId = v),
    );
    final tagField = TagPicker(
      pitId: widget.pitId,
      selected: _tagIds,
      onChanged: (v) => setState(() => _tagIds = v),
    );
    final Widget form;
    if (widget.asModal) {
      final name = groups.where((g) => g.id == groupId).firstOrNull?.name;
      form = ModalFormShell(
        title: title,
        actionLabel: _editing
            ? context.l10n.commonSave
            : context.l10n.albumOfficialAdd,
        compactActionLabel: _editing ? null : context.l10n.shareAdd,
        onAction: () {
          if (!_saving && groupId != null) _save(groupId);
        },
        panes: [
          ModalPane(width: 420, children: imageField),
          ModalPane(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
            children: [
              groupField,
              const SizedBox(height: 18),
              tagField,
              if (!_editing && name != null && _files.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  context.l10n.ipadformsOfficialGroupNote(_files.length, name),
                  style: TextStyle(fontSize: 12.5, color: context.tokens.text3),
                ),
              ],
            ],
          ),
        ],
      );
    } else {
      form = AlbumFormScaffold(
        title: title,
        children: [
          ...imageField,
          const SizedBox(height: 18),
          groupField,
          const SizedBox(height: 16),
          tagField,
          const SizedBox(height: 26),
          AlbumSubmitButton(
            label: _editing
                ? context.l10n.commonSave
                : context.l10n.albumOfficialAdd,
            busy: _saving,
            onTap: groupId == null ? null : () => _save(groupId),
          ),
        ],
      );
    }
    return DropZone(
      title: context.l10n.ipadmediaDropTitle(context.l10n.pitsOfficial),
      subtitleFor: context.l10n.ipadmediaDropCount,
      // 拖進來的圖直接加到圖片格（分組用分組欄選）。
      onFiles: (files) =>
          setState(() => _files.addAll(files.map(ImageItem.picked))),
      enabled: !_saving && !_editing,
      child: form,
    );
  }
}
