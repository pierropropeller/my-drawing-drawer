import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

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
import '../media_source/drop_zone.dart';
import '../picker/inspo_picker_source.dart' show pickedFromInspo;
import '../../theme/tokens.dart';
import 'album_actions.dart';
import 'album_form.dart';
import 'album_set_form.dart';
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
  final _note = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  /// 新增時「合成一組」（D-136，預設關）：開著＝這幾張存成一筆多圖。
  bool _combine = false;

  // 編輯模式：載入的那一組（D-136；第 1 張＝那一列本身）。
  NewImage? _editImage; // 載入時的第 1 張
  final List<ImageItem> _editItems = []; // 持有敏感標記的切換狀態（D-104）

  /// 從靈感廣場放進來的（D-142）：圖是廣場那張，不能加圖／拆開。
  bool _linked = false;
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
    final images = await db.albumSetImages(AlbumCell.official, row.id);
    // 從靈感廣場放進來的圖：說明讀廣場那張（共用一份）。
    final note = await db.watchOfficialNote(row.id).first;
    if (!mounted) return;
    _note.text = note ?? '';
    setState(() {
      _groupId = row.groupId;
      _tagIds = ids;
      _linked = row.materialId != null;
      _editImage = images.first;
      _editItems.addAll(images.map(ImageItem.stored));
      _loaded = true;
    });
  }

  /// 編輯模式圖片上的「×」：一組裡還有別張＝只拿掉這張；只剩這一張＝刪除這筆官方圖，要確認。
  Future<void> _removeImage(int i) async {
    if (_editItems.length > 1) {
      setState(() => _editItems.removeAt(i));
      return;
    }
    final ok = await confirmDelete(
      context,
      title: context.l10n.albumDeleteImageTitle,
      toTrash: true,
    );
    if (!ok || !mounted) return;
    await ref.read(databaseProvider).deleteOfficial([widget.editImageId!]);
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _pick() async {
    final picked = await ref.read(imagePickerProvider)(context);
    if (picked.isNotEmpty) {
      setState(
        () => (_editing ? _editItems : _files).addAll(
          picked.map(ImageItem.picked),
        ),
      );
    }
  }

  /// 編輯模式寫回：整組的圖（次序、增刪）＋分組／tag／第 1 張的敏感標記。取消確認時回傳 false。
  Future<bool> _persistEdit(String groupId) async {
    final db = ref.read(databaseProvider);
    final sensitive = _editItems.first.sensitive;
    // 把現任封面標成敏感：先確認（D-104）。
    if (sensitive &&
        !_editImage!.sensitive &&
        await db.coverCountAmong(SensitiveSource.official, [
              widget.editImageId!,
            ]) >
            0) {
      if (!mounted || !await confirmSensitiveCover(context, 1)) return false;
    }
    setState(() => _saving = true);
    final store = await ref.read(imageStoreProvider.future);
    final images = <NewImage>[
      for (final f in _editItems) await f.resolve(store),
    ];
    await db.setAlbumSetImages(AlbumCell.official, widget.editImageId!, images);
    await db.updateOfficial(
      widget.editImageId!,
      groupId: groupId,
      tagIds: _tagIds,
      sensitive: sensitive,
    );
    await db.setOfficialNote(widget.editImageId!, _note.text);
    return true;
  }

  /// 拆開（D-136）：先存目前的編輯，再把這一組每一張變成獨立一項。
  Future<void> _split(String groupId) async {
    final n = _editItems.length;
    if (!await confirmAlbumSetSplit(context, n) || !mounted) return;
    if (!await _persistEdit(groupId)) return;
    await ref
        .read(databaseProvider)
        .splitAlbumSet(AlbumCell.official, widget.editImageId!);
    // 會跳頁的動作不出提示條（D-114）：回到預覽頁就看得到拆開了。
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _save(String groupId) async {
    if (_editing) {
      if (await _persistEdit(groupId) && mounted) Navigator.of(context).pop();
      return;
    }
    if (_files.isEmpty) {
      return;
    }
    setState(() => _saving = true);
    final store = await ref.read(imageStoreProvider.future);
    final db = ref.read(databaseProvider);
    final imported = <NewImage>[];
    // 從靈感廣場選的圖：放進坑（連結，D-145），不另存一份。
    final linked = <String>[];
    for (final f in _files) {
      final mid = f.picked == null ? null : pickedFromInspo[f.picked!.path];
      if (mid != null) {
        linked.add(mid);
        continue;
      }
      imported.add(await f.resolve(store));
    }
    if (linked.isNotEmpty) {
      await db.placeMaterials(linked, widget.pitId, groupId, tagIds: _tagIds);
      // 說明共用：有填才寫進廣場那張。
      if (_note.text.trim().isNotEmpty) {
        for (final id in linked) {
          await db.setMaterialNote(id, _note.text);
        }
      }
    }
    if (imported.isNotEmpty) {
      if (_combine && imported.length > 1) {
        await db.addOfficialSet(
          widget.pitId,
          groupId,
          imported,
          tagIds: _tagIds,
          note: _note.text,
        );
      } else {
        await db.addOfficial(
          widget.pitId,
          groupId,
          imported,
          tagIds: _tagIds,
          note: _note.text,
        );
      }
    }
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
    // 必填（圖、分組）沒填完：按鈕變灰（D-121 ①）。
    final canSave =
        groupId != null &&
        (_editing ? _editItems.isNotEmpty : _files.isNotEmpty);
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
      if (_editing) ...[
        ImagePickerField(
          pitId: widget.pitId,
          items: _editItems,
          onAdd: _linked ? null : _pick,
          onRemove: _removeImage,
          onReorder: _linked
              ? null
              : (a, b) => setState(() => moveListItem(_editItems, a, b)),
        ),
        if (!_linked && _editItems.length > 1 && groupId != null)
          AlbumSetSplitRow(
            count: _editItems.length,
            onTap: _saving ? null : () => _split(groupId),
          ),
      ] else ...[
        ImagePickerField(
          pitId: widget.pitId,
          items: _files,
          onAdd: _pick,
          onRemove: (i) => setState(() => _files.removeAt(i)),
          onReorder: (a, b) => setState(() => moveListItem(_files, a, b)),
        ),
        if (_files.length > 1)
          AlbumSetCombineRow(
            value: _combine,
            onChanged: (v) => setState(() => _combine = v),
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
        onAction: canSave
            ? () {
                if (!_saving) _save(groupId);
              }
            : null,
        panes: [
          ModalPane(width: 420, children: imageField),
          ModalPane(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
            children: [
              groupField,
              const SizedBox(height: 18),
              tagField,
              const SizedBox(height: 18),
              NoteField(controller: _note),
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
          const SizedBox(height: 16),
          NoteField(controller: _note),
          const SizedBox(height: 24),
          AlbumSubmitButton(
            label: _editing
                ? context.l10n.commonSave
                : context.l10n.albumOfficialAdd,
            busy: _saving,
            onTap: canSave ? () => _save(groupId) : null,
          ),
        ],
      );
    }
    return DropZone(
      title: context.l10n.ipadmediaDropTitle(context.l10n.pitsOfficial),
      subtitleFor: context.l10n.ipadmediaDropCount,
      // 拖進來的圖直接加到圖片格（分組用分組欄選）。
      onFiles: (files) => setState(
        () => (_editing ? _editItems : _files).addAll(
          files.map(ImageItem.picked),
        ),
      ),
      enabled: !_saving && !_linked,
      child: form,
    );
  }
}
